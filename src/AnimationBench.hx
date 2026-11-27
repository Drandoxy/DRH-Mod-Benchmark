package mods.benchmark;

import mods.api.Context;
import facade.DBFacade;
import brain.assetRepository.AssetLoadingComponent;
import starling.extensions.animate.Animation;
import starling.display.Sprite as VisualSprite;
import starling.display.Quad;
import starling.StatusTintFilter;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** Owns visual-only instances. Never creates distributed/gameplay actors or changes shared atlases. */
class AnimationBench {
	public var running(default, null) = false;

	var ctx:Context;
	var store:CapacityStore;
	var done:String->Void;
	var document:Dynamic;
	var popup:Sprite;
	var caption:TextField;
	var root:BenchSurface;
	var measuredDraws = 0;
	var warmingDraws = 0;
	var instances:Array<Animation> = [];
	var recipes:Array<Dynamic>;
	var plan:Array<Dynamic>;
	var available:Array<Bool> = [];
	var loader:AssetLoadingComponent;
	var coveredUI:openfl.display.DisplayObject;
	var uiWasVisible = false;
	var index = -1;
	var loading = -1;
	var generation = 0;
	var phase = "idle";
	var phaseAt = 0.0;
	var last = 0.0;
	var nextUI = 0.0;
	var warmUntil = 0.0;
	var frames:FrameWindow;
	var advanceSum = 0.0;
	var advancePeak = 0.0;
	var advances = 0;
	var prepareAt = 0.0;
	var loadAt = 0.0;
	var slowMs = 0.0;
	var finished = false;
	var scene:BaselineScene;
	var selectedHeroes:Array<Dynamic> = [];
	var stressCount = 21;
	var lastFury:Animation;
	var lastDragon:Animation;
	var startedAt = 0.0;
	var backgroundFrames = 0;
	var phaseTime = 0.0;
	var pendingBackground = false;
	var previousTick = 0.0;

	public function new(ctx:Context, done:String->Void) {
		this.ctx = ctx;
		this.done = done;
		store = new CapacityStore(ctx.data);
	}

	public function saved():String
		return CapacityStore.describe(store.read());

	public function interrupted():Bool {
		var d = store.read();
		return d != null && d.status == "running";
	}

	public function start():Void {
		try
			startUnsafe()
		catch (error:Dynamic) {
			Faults.report("animation benchmark startup", error);
			if (running)
				finish("ERROR: missing or incompatible game asset/interface: " + Std.string(error));
			else
				showResult("Animation benchmark could not start: " + Std.string(error));
		}
	}

	function startUnsafe():Void {
		if (running)
			return;
		if (!ctx.state.inTown) {
			done("Start the controlled animation benchmark from town. Normal gameplay recording remains available in dungeons.");
			return;
		}
		var facade:DBFacade = ctx.core.facade;
		if (facade == null
			|| facade.assetLoadingComponent == null
			|| facade.starlingLayerManager == null
			|| facade.starlingLayerManager.starlingInstance == null
			|| facade.sceneGraphManager == null) {
			done("Animation renderer is not ready. Try again after town loads.");
			return;
		}
		startedAt = clock();
		loader = facade.assetLoadingComponent;
		recipes = CapacityPlan.assets();
		var pool = CapacityPlan.heroes();
		selectedHeroes = [];
		for (_ in 0...4) {
			var hero = pool.splice(Std.random(pool.length), 1)[0];
			selectedHeroes.push(hero);
			recipes.push(hero);
		}
		plan = CapacityPlan.rounds();
		available = [for (_ in recipes) false];
		document = {
			protocol: 6,
			modVersion: Main.VERSION,
			sequence: 0,
			status: "running",
			stage: "starting",
			started: Date.now().toString(),
			width: ctx.viewWidth,
			height: ctx.viewHeight,
			rounds: [],
			loadMs: 0
		};
		document.mods = null;
		document.modEnvironment = "Enabled-mod enumeration unavailable through the public API; record the enabled set manually for comparisons.";
		document.heroes = selectedHeroes;
		document.scenery = {
			biome: "castle_arena",
			seed: Std.random(100000),
			tiles: 1,
			props: 6
		};
		document.configuredFps = ctx.overlay.stage == null ? null : ctx.overlay.stage.frameRate;
		store.save(document); // Before allocating animation resources.
		running = true;
		finished = false;
		coveredUI = facade.sceneGraphManager.get_UILayerGroup();
		if (coveredUI != null) {
			uiWasVisible = coveredUI.visible;
			coveredUI.visible = false;
		}
		generation++;
		index = -1;
		loading = -1;
		root = new BenchSurface();
		root.touchable = false;
		root.addChild(new Quad(960, 640, 0x101923));
		var clip = new Quad(960, 640, 0xFFFFFF);
		root.addChild(clip);
		root.mask = clip;
		// Direct stage child: the game can hide its shared HUD layer in town.
		// Keep this outside the game root's sorted StarlingLayer children.
		facade.starlingLayerManager.starlingInstance.get_stage().addChild(root);
		makePopup();
		loadAt = previousTick = clock();
		pendingBackground = false;
		nextLoad();
	}

	static function clock():Float
		return haxe.Timer.stamp() * 1000;

	function makePopup():Void {
		popup = new Sprite();
		popup.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) e.stopPropagation());
		popup.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent) e.stopPropagation());
		ctx.overlay.addChild(popup);
		popup.graphics.beginFill(0x223442);
		popup.graphics.drawRoundRect(0, 0, 960, 52, 10, 10);
		popup.graphics.endFill();
		// Transparent center leaves the native Starling test surface visible while intercepting clicks.
		var hit = new Sprite();
		popup.addChild(hit);
		hit.graphics.beginFill(0x182430, 0.001);
		hit.graphics.drawRect(0, 52, 960, 640);
		hit.graphics.endFill();
		var footer = new Sprite();
		popup.addChild(footer);
		footer.y = 692;
		footer.graphics.beginFill(0x223442);
		footer.graphics.drawRoundRect(0, 0, 960, 54, 10, 10);
		footer.graphics.endFill();
		caption = label("Loading animation test...", 18, 15, 810);
		var stop = new Sprite();
		popup.addChild(stop);
		stop.x = 860;
		stop.y = 8;
		stop.mouseChildren = false;
		stop.buttonMode = true;
		stop.graphics.beginFill(0x754A52);
		stop.graphics.drawRoundRect(0, 0, 86, 36, 6, 6);
		stop.graphics.endFill();
		Icons.draw(stop, "square", 10, 10);
		var t = new TextField();
		t.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
		t.text = "Stop";
		t.x = 32;
		t.y = 7;
		t.width = 48;
		t.height = 24;
		t.mouseEnabled = false;
		stop.addChild(t);
		stop.addEventListener(MouseEvent.CLICK, function(_) finish("stopped"));
		label("Visual-only test | " + plan.length + " rounds | about 1 minute | light to heavy effects", 18, 706, 930);
		layout();
	}

	function label(text:String, x:Float, y:Float, w:Float):TextField {
		var t = new TextField();
		t.defaultTextFormat = new TextFormat("_sans", 15, 0xD2DEE8);
		t.text = text;
		t.x = x;
		t.y = y;
		t.width = w;
		t.height = 28;
		t.mouseEnabled = false;
		popup.addChild(t);
		return t;
	}

	function layout():Void {
		var scale = Math.min(2.5, Math.min((ctx.viewWidth - 96) / 960, (ctx.viewHeight - 96) / 746));
		popup.scaleX = popup.scaleY = scale;
		popup.x = (ctx.viewWidth - 960 * scale) / 2;
		popup.y = (ctx.viewHeight - 746 * scale) / 2;
		var facade:DBFacade = ctx.core.facade;
		var stage = facade.starlingLayerManager.starlingInstance.get_stage();
		var sx = stage.get_stageWidth() / ctx.viewWidth;
		var sy = stage.get_stageHeight() / ctx.viewHeight;
		root.scaleX = scale * sx;
		root.scaleY = scale * sy;
		root.x = popup.x * sx;
		root.y = (popup.y + 52 * scale) * sy;
		document.surface = {
			x: root.x,
			y: root.y,
			scaleX: root.scaleX,
			scaleY: root.scaleY,
			stageWidth: stage.get_stageWidth(),
			stageHeight: stage.get_stageHeight()
		};
	}

	function nextLoad():Void {
		loading++;
		if (loading >= recipes.length) {
			phase = "sceneryLoading";
			phaseAt = clock();
			document.stage = "loading castle arena tiles and props";
			document.operation = {phase: "scenery load", assets: [], round: null};
			store.save(document);
			var token = generation;
			loader.queueStarlingAssets("castle_arena", function() {
				if (running && generation == token && phase == "sceneryLoading")
					phase = "sceneryReady";
			});
			return;
		}
		phase = "loading";
		phaseAt = clock();
		document.stage = "loading " + recipes[loading].name;
		document.operation = {phase: "load/probe", asset: recipes[loading], round: null};
		store.save(document);
		var token = generation;
		var which = loading;
		loader.queueStarlingAssetsForPath(recipes[which].path, function() {
			if (!running || token != generation || phase != "loading" || loading != which)
				return;
			var probe:Animation = null;
			try {
				probe = loader.createAnimationFromAssetManager(recipes[which].symbol);
				available[which] = probe != null && (recipes[which].label == null || probe.getFrame(recipes[which].label) >= 0);
				if (available[which]) {
					if (recipes[which].label != null)
						probe.gotoLabel(recipes[which].label, true);
					recipes[which].bounds = AnimationSizing.measure(probe);
				}
			} catch (error:Dynamic) {
				available[which] = false;
				Faults.report("animation asset probe " + recipes[which].name, error);
			}
			if (probe != null)
				try
					probe.dispose()
				catch (error:Dynamic) {
					available[which] = false;
					Faults.report("animation probe cleanup", error);
				}
			phase = "loaded"; // Continue on the next tick, outside native loader dispatch.
		});
	}

	function clear(checkpoint:Bool = true):Void {
		lastDragon = null;
		lastFury = null;
		var failure:Dynamic = null;
		while (instances.length > 0) {
			var n = instances.length - 1;
			if (checkpoint && document != null && index >= 0 && index < plan.length) {
				document.operation = {
					phase: "dispose instance",
					asset: recipes[CapacityPlan.assetIndex(plan[index].kind, n)],
					instance: n + 1,
					round: plan[index].name
				};
				store.save(document);
			}
			var a = instances.pop();
			try {
				if (a.parent != null)
					a.parent.removeChild(a);
			} catch (e:Dynamic) {
				failure = e;
			}
			try
				a.dispose()
			catch (e:Dynamic) {
				failure = e;
			}
		}
		if (failure != null) {
			Faults.report("animation instance cleanup", failure);
			if (checkpoint)
				throw failure;
		}
	}

	function nextRound():Void {
		clear();
		index++;
		if (index >= plan.length) {
			var skipped = false;
			for (row in (cast document.rounds : Array<Dynamic>))
				if (row.status == "skipped")
					skipped = true;
			finish(skipped ? "complete with unavailable rounds" : "complete");
			return;
		}
		phase = "spawning";
		phaseAt = prepareAt = clock();
		document.stage = "round " + (index + 1) + ": " + plan[index].name + " (preparing)";
		store.save(document);
		var r = plan[index];
		if (r.count > 0)
			for (i in 0...recipes.length)
				if (i < stressCount && CapacityPlan.requires(r.kind, i) && !available[i]) {
					document.rounds.push({
						name: r.name,
						count: r.count,
						status: "skipped",
						note: "Required animation asset/label unavailable: " + recipes[i].name
					});
					store.save(document);
					phase = "skip";
					return;
				}
	}

	function spawnOne():Void {
		var r = plan[index];
		var n = instances.length;
		var k:Int = CapacityPlan.assetIndex(r.kind, n);
		var asset = recipes[k];
		document.operation = {
			phase: "create instance",
			asset: asset,
			instance: n + 1,
			round: plan[index].name
		};
		store.save(document);
		var a = loader.createAnimationFromAssetManager(asset.symbol);
		if (a == null)
			throw "Required animation disappeared: " + asset.symbol;
		instances.push(a);
		if (asset.label != null && a.getFrame(asset.label) < 0)
			throw "Required animation label disappeared: " + asset.symbol + " / " + asset.label;
		if (asset.label != null)
			a.gotoLabel(asset.label, true);
		a.play();
		try {
			if (asset.nativeScale != null)
				AnimationSizing.effect(a, asset.bounds, asset.nativeScale);
			else if (k == 3 || k >= 12 && k <= 14)
				AnimationSizing.fitHeight(a, 145, asset.bounds);
			else
				AnimationSizing.fit(a, asset.pixels, asset.bounds);
		} catch (e:Dynamic) {
			throw e;
		}
		var groupSize = r.kind == -2 ? 4 : (r.kind == -3 || r.kind == -4) ? 2 : 1;
		var cellCount:Float = r.count / groupSize;
		var cell = Std.int(n / groupSize);
		var columns = Std.int(Math.ceil(Math.sqrt(cellCount * 1.6)));
		var rows = Std.int(Math.ceil(cellCount / columns));
		a.x = 160 + (cell % columns) * 640 / Math.max(1, columns - 1);
		a.y = 160 + Std.int(cell / columns) * 320 / Math.max(1, rows - 1);
		if (cellCount == 1) {
			a.x = 480;
			a.y = 320;
		}
		if (k == 2)
			lastDragon = a;
		if (k == 6 && lastDragon != null) {
			// Match the native breath effect: actor origin plus authored yOffset -45.
			a.pivotX = a.pivotY = 0;
			a.scaleX = lastDragon.scaleX;
			a.scaleY = lastDragon.scaleY;
			a.x = lastDragon.x - lastDragon.pivotX * lastDragon.scaleX;
			a.y = lastDragon.y - lastDragon.pivotY * lastDragon.scaleY - 45 * lastDragon.scaleY;
		}
		if (k == 17) {
			lastFury = a;
			var tint = new StatusTintFilter();
			tint.set(0xFF3300, 0.7);
			a.setColorMatrix(tint.get_matrix());
		}
		if (k >= 18 && k <= 20 && lastFury != null) {
			a.pivotX = a.pivotY = 0;
			a.x = lastFury.x - lastFury.pivotX * lastFury.scaleX;
			a.y = lastFury.y - lastFury.pivotY * lastFury.scaleY;
		}

		root.addChild(a);
	}

	public function focusChanged(focused:Bool):Void {
		if (running && !focused)
			pendingBackground = true;
	}

	public function tick(focused:Bool):Void {
		if (!running)
			return;
		var now = clock();
		var background = !focused || pendingBackground;
		pendingBackground = false;
		if (background)
			phaseAt += Math.max(0, now - previousTick - 250);
		previousTick = now;
		try {
			if (root == null)
				throw "Animation surface unavailable";
			if (root.failure != null)
				throw root.failure;
			root.setRequiresRedraw();
			if (now - startedAt >= CapacityPlan.MAX_MS) {
				if (phase == "measuring" && frames != null && frames.frames > 0)
					saveRound("partial: one-minute time limit");
				finish("finished: one-minute time limit; see completed and partial rounds");
				return;
			}

			if (!ctx.state.inTown) {
				finish("stopped: left town");
				return;
			}
			if (ctx.viewWidth != document.width || ctx.viewHeight != document.height) {
				finish("stopped: viewport changed");
				return;
			}
			if (root.parent == null || !root.parent.visible) {
				finish("stopped: renderer detached");
				return;
			}
			if (now >= nextUI) {
				caption.text = "v" + Main.VERSION + " | "
					+ document.stage
					+ " | "
					+ Math.max(0, Math.ceil((CapacityPlan.MAX_MS - (now - startedAt)) / 1000))
					+ "s left";
				if (phase == "measuring" && frames != null && frames.elapsed > 0)
					caption.text += " | " + Math.round(frames.frames * 1000 / frames.elapsed) + " FPS";
				nextUI = now + 250;
			}
			if (phase == "sceneryLoading") {
				if (now - phaseAt > 30000)
					throw "Castle arena scenery loading timed out";
				return;
			}
			if (phase == "sceneryReady") {
				document.stage = "preparing map and four heroes";
				store.save(document);
				for (i in stressCount...recipes.length)
					if (!available[i])
						throw "Baseline hero unavailable: " + recipes[i].name;
				scene = new BaselineScene(loader, root, selectedHeroes, document.scenery.seed, function(asset:Dynamic) {
					document.operation = {phase: "prepare map baseline", asset: asset, round: "four-hero map baseline"};
					store.save(document);
				});
				document.loadMs = FrameWindow.round(clock() - loadAt);
				nextRound();
				return;
			}
			if (phase == "loaded") {
				nextLoad();
				return;
			}
			if (phase == "loading") {
				if (now - phaseAt > 20000) {
					available[loading] = false;
					Faults.report("animation load timeout", recipes[loading].name);
					phase = "loaded";
				}
				return;
			}
			if (phase == "skip") {
				nextRound();
				return;
			}
			if (phase == "spawning") {
				for (_ in 0...4)
					if (instances.length < plan[index].count)
						spawnOne();
				if (instances.length == plan[index].count) {
					phase = "warmup";
					phaseTime = 0;
					scene.reset();
					warmingDraws = root.draws;
					phaseAt = last = now;
					warmUntil = now + CapacityPlan.WARMUP_MS;
					document.stage = "round " + (index + 1) + ": " + plan[index].name + " (warm-up)";
					document.operation = {phase: "warm-up", assets: roundAssets(), round: plan[index].name};
					store.save(document);
				}
				return;
			}
			var dt = now - last;
			last = now;
			phaseTime += Math.min(250, Math.max(0, dt));
			var advanceAt = clock();
			scene.update(Math.min(0.25, Math.max(0, dt / 1000)));
			for (a in instances)
				a.advanceTime(Math.min(0.25, Math.max(0, dt / 1000)));
			var advance = clock() - advanceAt;
			if (phase == "warmup" && phaseTime >= CapacityPlan.WARMUP_MS) {
				if (root.draws - warmingDraws < 2) {
					if (background) {
						warmUntil = now + 500;
						return;
					}
					finish("invalid: benchmark surface was not rendered during warm-up");
					return;
				}
				measuredDraws = root.draws;
				scene.reset();
				backgroundFrames = 0;
				frames = new FrameWindow();
				advanceSum = advancePeak = 0;
				advances = 0;
				slowMs = 0;
				phase = "measuring";
				phaseTime = 0;
				phaseAt = now;
				document.stage = "round " + (index + 1) + ": " + plan[index].name + " (measuring)";
				document.operation = {phase: "measuring", assets: roundAssets(), round: plan[index].name};
				store.save(document);
				last = clock();
				return;
			}
			if (phase != "measuring")
				return;
			frames.add(dt);
			if (background)
				backgroundFrames++;
			advanceSum += advance;
			advancePeak = Math.max(advancePeak, advance);
			advances++;
			slowMs = dt > 200 ? slowMs + dt : 0;
			if (!background && slowMs >= 2000) {
				saveRound("partial: low-FPS limit");
				finish("stopped: sustained frame pacing below 5 FPS");
				return;
			}
			if (phaseTime >= CapacityPlan.ROUND_MS) {
				if (root.draws - measuredDraws < 2) {
					if (background) {
						phaseAt = now - 11500;
						return;
					}
					finish("invalid: benchmark surface stopped rendering");
					return;
				}
				saveRound("complete");
				nextRound();
			}
		} catch (e:Dynamic) {
			finish("failed: " + Std.string(e));
		}
	}

	function roundAssets():Array<Dynamic> {
		var r = plan[index];
		var assets:Array<Dynamic> = [];
		for (i in 0...recipes.length) {
			var count = 0;
			for (n in 0...Std.int(r.count))
				if (CapacityPlan.assetIndex(r.kind, n) == i)
					count++;
			if (count > 0) {
				var scale = 1.0;
				for (n in 0...instances.length)
					if (CapacityPlan.assetIndex(r.kind, n) == i) {
						scale = Math.abs(instances[n].scaleX);
						break;
					}
				assets.push({
					name: recipes[i].name,
					symbol: recipes[i].symbol,
					label: recipes[i].label,
					count: count,
					pixels: FrameWindow.round(Math.max(recipes[i].bounds.width, recipes[i].bounds.height) * scale),
					nativeEffectScale: recipes[i].nativeScale,
					referenceBounds: recipes[i].bounds
				});
			}
		}
		return assets;
	}

	function saveRound(status:String):Void {
		var r = plan[index];
		var assets = roundAssets();
		document.rounds.push({
			name: r.name,
			count: r.count,
			status: status,
			assets: assets,
			frame: frames.report(),
			backgroundFrames: backgroundFrames,
			baselineHeroes: 4,
			renderedSurfaceFrames: root.draws - measuredDraws,
			renderedSurfaceFps: FrameWindow.round(frames.elapsed > 0 ? (root.draws - measuredDraws) * 1000 / frames.elapsed : 0),
			advanceMeanMs: FrameWindow.round(advances > 0 ? advanceSum / advances : 0),
			advancePeakMs: FrameWindow.round(advancePeak),
			prepareMs: FrameWindow.round(phaseAt - prepareAt)
		});
		store.save(document);
	}

	function cleanup(operation:String, action:Void->Void):Void {
		try
			action()
		catch (error:Dynamic) {
			Faults.report(operation, error);
		}
	}

	function showResult(text:String):Void {
		cleanup("benchmark results display", function() done(text));
	}

	public function finish(status:String):Void {
		if (!running || finished)
			return;
		finished = true;
		running = false;
		generation++; // Invalidate late asynchronous loader callbacks before cleanup.
		document.status = status;
		document.seconds = FrameWindow.round((clock() - startedAt) / 1000);
		document.surfaceDraws = root == null ? 0 : root.draws;
		if (coveredUI != null) {
			cleanup("restore town interface", function() coveredUI.visible = uiWasVisible);
			coveredUI = null;
		}
		cleanup("animation instances cleanup", function() clear(false));
		if (scene != null)
			cleanup("baseline scene cleanup", function() scene.dispose());
		scene = null;
		if (root != null) {
			cleanup("animation surface detach", function() {
				if (root.parent != null)
					root.parent.removeChild(root);
			});
			cleanup("animation surface cleanup", function() root.dispose());
		}
		if (popup != null)
			cleanup("benchmark popup detach", function() {
				if (popup.parent != null)
					popup.parent.removeChild(popup);
			});
		popup = null;
		root = null;
		document.warnings = Faults.snapshot();
		try
			store.save(document)
		catch (error:Dynamic) {
			document.status += "; checkpoint save failed";
			Faults.report("animation final checkpoint", error);
		}
		var text = "Animation benchmark stopped: " + document.status + ". See diagnostic warnings if cleanup was incomplete.";
		try
			text = CapacityStore.describe(document)
		catch (error:Dynamic) {
			Faults.report("animation results formatting", error);
		}
		showResult(text);
	}

	public function dispose():Void {
		if (running)
			finish("stopped: mod unloaded");
		generation++;
	}
}
