import mods.benchmark.*;

@:access(mods.benchmark.ModProfiler)
@:access(mods.benchmark.Hud)
@:access(mods.benchmark.LiteHud)
@:access(mods.benchmark.AnimationBench)
@:access(mods.benchmark.FrameWindow)
@:access(mods.benchmark.Main)
class Checks {
	static var count = 0;

	static function check(ok:Bool, message:String):Void {
		count++;
		if (!ok)
			throw message;
	}

	static function main():Void {
		var w = new FrameWindow();
		for (_ in 0...99)
			w.add(10);
		w.add(100);
		var r = w.report();
		check(r.frames == 100 && r.p95 == 10 && r.p99 == 10 && r.worst == 100 && r.stalls == 1, "frame statistics");
		w.add(Math.NaN);
		w.add(0);
		check(w.frames == 100, "invalid frame admitted");
		for (_ in 0...5000)
			w.add(12);
		check(w.report().quantileResolutionMs == 1 && w.report().percentileSamples == 5100, "unbounded percentile storage");
		var s = new Session();
		s.snapshot = {
			groups: [{key: "enemy:orc | attack", count: 2}],
			map: "TOWN",
			floor: 0,
			enemies: 2,
			ping: 30,
			partial: false
		};
		s.snapshotTime = 0;
		for (i in 1...21)
			s.frame(10, i * 10, true, 0);
		s.frame(100, 250, true, 0);
		check(s.worst.length == 1 && s.worst[0].groups[0].count == 2, "hitch context missing");
		check(s.ranked().length == 1 && s.ranked()[0].frames == 21, "association count");
		s.frame(100, 300, false, 0);
		s.frame(3000, 3500, true, 0);
		s.frame(100, 3600, true, 8);
		check(s.excluded == 3 && s.total.frames == 21 && s.excludedGaps[0].ms == 3000, "focus/suspend/self-work exclusions");
		s.frame(100, 5000, true, 0);
		check(s.worst.length == 2
			&& (s.worst[0].contextAvailable == false || s.worst[1].contextAvailable == false), "hitch lost when context is stale");
		var paced = new FrameWindow();
		for (ms in [10., 20., 20., 10., 30.])
			paced.add(ms);
		var drops:Array<Dynamic> = paced.report().fpsDrops;
		check(drops[0].threshold == 70 && drops[0].frames == 3 && drops[0].dips == 2, "FPS dip episodes confused with frame counts");
		paced.breakDips();
		paced.add(20);
		check(paced.report().fpsDrops[0].dips == 3, "excluded gap merged independent dips");
		var edge = new FrameWindow();
		edge.add(1000. / 70);
		check(edge.report().fpsDrops[0].frames == 0, "exact threshold counted as below");
		var noContext = new Session();
		noContext.scene = "LoadingScreenState";
		noContext.sceneAfter = "RunState";
		noContext.frame(304, 304, true, 0);
		check(noContext.worst.length == 1 && noContext.worst[0].scene == "LoadingScreenState" && !noContext.worst[0].contextAvailable,
			"scanner failure erased measured hitch");
		var sample:Dynamic = {
			seconds: 104,
			frame: {
				frames: 11434,
				fps: 109.4,
				p95: 11,
				p99: 23,
				worst: 304,
				stalls: 32
			},
			errors: 409,
			ping: {samples: 0},
			mods: [],
			worst: [],
			associations: [],
			excluded: 0,
			maxScanMs: 0,
			logFailed: false
		};
		var explanation = Results.describe(sample);
		sample.modProfilingError = "Per-mod timing unavailable";
		check(Results.describe(sample).indexOf("Per-mod timing unavailable") >= 0, "missing API timing must be visible in report");
		var oldWorst = sample.worst;
		sample.worst = [{at:1000., ms:80., contextAvailable:false, mods:[{name:"Example mod",ms:3.}], groups:[{count:5,key:"enemy:Brute | idle"}]}];
		var separated = Results.describe(sample);
		check(separated.indexOf("Animations / actors observed near this frame") > separated.indexOf("Example mod: 3"), "animation context needs its own heading after mod spans");
		sample.worst[0].mods = [];
		check(Results.describe(sample).indexOf("Largest observed mod spans") < 0, "empty mod spans should not label animation rows");
		sample.worst = oldWorst;

		check(explanation.indexOf("409 adapter errors") >= 0 && explanation.indexOf("32 severe slow frames") >= 0,
			"plain explanation omitted quality or stutters");
		check(explanation.indexOf("No sampled frames reached") < 0 && explanation.indexOf("Record a longer session") < 0,
			"contradictory scanner advice retained");
		var folder = Sys.getCwd() + "/.benchmark-test-" + Std.random(1000000);
		sys.FileSystem.createDirectory(folder);
		var path = folder + "/process.json";
		sys.io.File.saveContent(path, haxe.Json.stringify({
			time: 10000,
			session: "one",
			pid: 55,
			name: "game",
			cpu: 20,
			gpu: 30,
			ram: 500
		}));
		check(ProcessSample.read(path, "two", 10000) == null, "wrong session accepted");
		check(ProcessSample.read(path, "one", 17000) == null, "stale process accepted");
		check(ProcessSample.read(path, "one", 10000).ram == 500, "valid process sample refused");
		sys.io.File.saveContent(path, haxe.Json.stringify({
			time: 10000,
			session: "one",
			pid: 55,
			name: "game",
			cpu: 200,
			gpu: -1,
			ram: 500
		}));
		var ps = ProcessSample.read(path, "one", 10000);
		check(ps.cpu == null && ps.gpu == null, "invalid utilization presented");
		var keys:Array<String> = [];
		check(KeyIndex.find(keys, "m") == -1, "empty key insertion");
		keys.push("m");
		check(KeyIndex.find(keys, "a") == -1 && KeyIndex.find(keys, "z") == -2 && KeyIndex.find(keys, "m") == 0, "sorted key lookup boundaries");
		var keyed = new Session();
		keyed.snapshot = {
			groups: [{key: "z", count: 1}, {key: "a", count: 2}],
			map: "TEST",
			floor: 1,
			enemies: 3,
			ping: null,
			partial: false
		};
		keyed.snapshotTime = 0;
		for (i in 1...21)
			keyed.frame(16, i * 16, true, 0);
		check(keyed.ranked().length == 2 && keyed.ranked()[0].frames == 20 && keyed.ranked()[1].frames == 20, "activity keys mixed after sorted insertion");
		var logger = new CompactLog(folder);
		logger.intern("spark");
		check(logger.intern("spark") == 1, "dictionary duplicate");
		var high = logger.intern("z-last");
		logger.intern("a-first");
		check(logger.intern("z-last") == high && logger.intern("spark") == 1, "dictionary IDs changed after key insertion");
		for (i in 0...4) {
			logger.write({text: StringTools.rpad("x", "x", 230000)});
			logger.reserve();
		}
		check(logger.sequence >= 2 && logger.bytes <= 1048576, "log rotation/cap");
		var ctx = new mods.api.Context();
		ctx.data = folder;
		ctx.state = {inTown: true, floor: null, heroes: []};
		var renderer = new starling.core.Starling();
		var animation = new starling.extensions.animate.Animation();
		renderer.stage.addChild(animation);
		var actor = new actor.ActorGameObject();
		var facade = new facade.DBFacade();
		facade.starlingLayerManager = {starlingInstance: renderer};
		facade.dbAccountInfo = {SocketPingMilsecs: 25};
		facade.gameObjectManager = {
			getReferenceFromId: function(id:UInt) {
				return actor;
			}
		};
		facade.mainStateMachine = {currentStateName: "TownState"};
		ctx.core = {facade: facade};
		var probe = new NativeProbe();
		probe.connect(ctx);
		var snapshot = probe.snapshot(ctx, true);
		check(snapshot.groups[0].metadata.frames == 12, "animation metadata missing");
		check(snapshot.map == "TOWN" && snapshot.animations == 1 && snapshot.ping == 25, "town census or heartbeat");
		ctx.state = {
			inTown: false,
			floor: {
				id: 1,
				number: 2,
				map: "TEST",
				monsters: [{id: 5, name: "orc"}]
			},
			heroes: []
		};
		snapshot = probe.snapshot(ctx, true);
		check(snapshot.enemies == 1 && snapshot.groups.length == 2, "actor/symbol census");
		// Measure an actual priority-ordered dispatch, not a replacement handler.
		var profileCtx = new mods.api.Context();
		profileCtx.data = folder + "/missing-layout/data";
		var profiler = new ModProfiler();
		profiler.start(profileCtx);
		check(!profiler.enabled && profiler.report(16).length == 0 && profiler.drain().length == 0, "unsupported cross-mod timing must stay unavailable");
		check(profiler.error.indexOf("unavailable") >= 0, "unsupported timing needs an explanation");
		profiler.dispose();
		Faults.reset();
		var warningLogs = 0;
		Faults.logger = function(message:String) warningLogs++;
		Faults.report("layout", "broken JSON");
		Faults.report("layout", "broken JSON");
		check(warningLogs == 1 && Faults.snapshot()[0].count == 2, "repeated diagnostics must be counted without log spam");
		Faults.logger = null;

		var ui = new Hud(function() {}, function() {}, function() {}, folder + "/ui.json");
		var uiRoot = new openfl.display.Sprite();
		uiRoot.addChild(ui);
		ui.stage = new openfl.display.Stage();
		ui.layout(1280, 720);
		ui.update(true, 65, "60|N/A|N/A|N/A|N/A|30ms");
		check(!ui.cards[1].visible && !ui.cards[2].visible && !ui.cards[3].visible && !ui.cards[4].visible && ui.timer.text == "01:05", "unavailable cards or timer layout");
		check(ui.cards[5].x - ui.cards[0].x == 156 && ui.panelHeight == 290, "compact spacing changed");
		check(ReportMarkup.select("YOUR RESULTS, EXPLAINED\nMost frames <safe>\nTECHNICAL DETAILS\nraw", false).indexOf("<safe>") >= 0,
			"plain report did not preserve literal content");
		check(ReportMarkup.dropShare("Isolated: X - 140 FPS | Smooth | -659.5 vs baseline (-82%)") == 82, "drop share not read");
		check(ReportMarkup.dropShare("Four-hero room baseline - 799.5 FPS | Smooth") == -1, "baseline line has no drop");
		check(ReportMarkup.dropColor(10) == 0x80D5B6 && ReportMarkup.dropColor(50) == 0xEBC77D && ReportMarkup.dropColor(82) == 0xF0AA86, "drop colours");
		check(ReportMarkup.select("Summary\nTECHNICAL DETAILS\nraw", false).indexOf("raw") < 0, "summary includes technical noise");
		ui.report("Full report text");
		ui.copyResults();
		check(openfl.system.System.copied == "Full report text", "copy did not export full results");
		var down = new openfl.events.MouseEvent();
		down.stageX = 500;
		down.stageY = 200;
		ui.beginDrag(down, true);
		var move = new openfl.events.MouseEvent();
		move.stageX = 540;
		move.stageY = 240;
		ui.moveDrag(move);
		var moved = ui.resultX;
		ui.endDrag(new openfl.events.Event());
		ui.layout(1280, 720);
		check(ui.dragStage == null
			&& ui.resultX == moved
			&& sys.FileSystem.exists(folder + "/ui.json"), "drag release or position save failed");
		var restored = new Hud(function() {}, function() {}, function() {}, folder + "/ui.json");
		check(restored.resultX == moved, "saved position not restored");
		restored.dispose();
		ui.update(false, 65, "Stopped. Results saved locally.");
		check(ui.metrics[0].text == "60", "stop overwrote FPS with clipped status");
		ui.dispose();
		ctx.core.facade.gameObjectManager = {
			getReferenceFromId: function(id:UInt):Dynamic {
				throw "fixture actor adapter failed";
			}
		};
		var degraded = probe.snapshot(ctx, true);
		check(degraded.ping == 25 && degraded.partial && probe.faults[0].stage == "enemy lookup",
			"actor adapter failure discarded independent heartbeat or fault stage");
		ctx.core.facade.gameObjectManager = {
			getReferenceFromId: function(id:UInt) {
				return actor;
			}
		};
		var loader = new openfl.display.MovieClip();
		loader.name = "loading_spinner";
		var nativeStage = new openfl.display.Stage();
		nativeStage.addChild(loader);
		ctx.overlay.stage = nativeStage;
		ctx.state = {inTown: false, floor: null, heroes: []};
		facade.mainStateMachine = {currentStateName: "LoadingScreenState"};
		var loading = probe.snapshot(ctx, true);
		check(loading.flashAnimations == 1 && loading.map == "LOADING" && loading.scene == "LoadingScreenState", "loading-screen timeline context missing");
		check(loading.groups[loading.groups.length - 1].key.indexOf("loading_spinner") >= 0, "timeline identity missing");
		var oldLog = sys.io.File.getContent(folder + "/benchmark.jsonl");
		var app = new Main();
		app.init(ctx);
		app.ready(ctx);
		check(!app.full.value && app.lite.visible && !app.hud.visible, "lightweight mode was not the default");
		ctx.keyHandler();
		app.frame(new openfl.events.Event());
		check(!app.lite.visible && !app.hud.visible && !app.active, "controls toggle did not persist across frame updates");
		ctx.keyHandler();
		check(app.lite.visible, "controls toggle did not restore compact panel");

		app.begin();
		check(!app.active && app.log == null, "lightweight mode started a recorder");
		app.frame(new openfl.events.Event());
		check(app.session == null && renderer.listeners == 0 && !sys.FileSystem.exists(folder + "/attach.json"),
			"display-only mode touched recording pipeline");
		app.liteSince = haxe.Timer.stamp() * 1000 - 600;
		app.frame(new openfl.events.Event());
		check(!sys.FileSystem.exists(folder + "/report.json") && sys.io.File.getContent(folder + "/benchmark.jsonl") == oldLog,
			"live display saved benchmark history");
		app.lite.layout(1280, 720);
		app.lite.size = 2;
		app.lite.viewW = 0;
		app.lite.layout(1280, 720);
		check(app.lite.scaleX == 2 && app.lite.x >= 8, "lite sizing or bounds failed");
		app.lite.update(151, 130);
		check(app.lite.fpsText.text == "151" && app.lite.pingText.text == "130 ms", "lite live values missing");
		app.lite.savedX = 0;
		app.lite.savedY = 0;
		app.lite.viewW = 0;
		app.lite.layout(1280, 720);
		check(app.lite.x == 0 && app.lite.y == 0, "compact panel cannot reach top-left corner");
		app.lite.savedX = 9999;
		app.lite.savedY = 9999;
		app.lite.viewW = 0;
		app.lite.layout(1280, 720);
		check(app.lite.x == 1280 - app.lite.panelW * app.lite.scaleX
			&& app.lite.y == 720 - 52 * app.lite.scaleY, "compact panel cannot reach bottom-right corner");
		app.focused = false;
		app.liteSince = haxe.Timer.stamp() * 1000 - 600;
		app.liteFrames = 71;
		app.frame(new openfl.events.Event());
		check(app.lite.fpsText.text != "--", "background FPS was suppressed");
		app.focused = true;
		app.full.value = true;
		app.begin();
		check(renderer.listeners == 1, "render listener missing");
		app.frame(new openfl.events.Event());
		app.last -= 16;
		app.frame(new openfl.events.Event());
		app.writeWindow(haxe.Timer.stamp() * 1000);
		check(app.recordingFaults.length == 0 && sys.io.File.getContent(folder + "/benchmark.jsonl").indexOf("dictionary") >= 0,
			"nonempty animation recording pipeline failed");
		app.full.value = false;
		app.frame(new openfl.events.Event());
		check(!app.active && app.lite.visible && !app.hud.visible, "disabling full mode did not stop and hide recorder");
		app.full.value = true;
		app.stop(false);
		check(renderer.listeners == 0 && !app.active, "stop cleanup");
		check(sys.FileSystem.exists(folder + "/report.json") && sys.FileSystem.exists(folder + "/report.txt"), "stop did not save report");
		check(sys.io.File.getContent(folder + "/report.txt").indexOf("not proven causes") >= 0, "report attribution misleading");
		check(haxe.Json.parse(sys.io.File.getContent(folder + "/attach.json")).running == false, "stop did not terminate sampler lease");
		app.begin();
		check(app.session.total.frames == 0 && renderer.listeners == 1, "restart did not reset");
		var clicks = new openfl.events.MouseEvent();
		clicks.type = openfl.events.MouseEvent.CLICK;
		app.hud.stopButton.dispatchEvent(clicks);
		var stoppedId = app.log.session;
		app.hud.stopButton.dispatchEvent(clicks);
		check(!app.active && app.log.session == stoppedId, "repeated Stop click restarted recording");
		app.begin();
		app.session.total.add(16);
		app.session.total.bins = null;
		app.stop(false);
		check(!app.active && !app.finalizing && !app.hud.running, "summary failure left Stop controls or recording active");
		var partial = haxe.Json.parse(sys.io.File.getContent(folder + "/report.json"));
		check(partial.frame.frames == 1 && partial.frame.p95 == null && partial.recordingFaults.length > 0, "summary failure discarded recoverable data");
		app.hud.stopButton.dispatchEvent(clicks);
		check(!app.active, "Stop restarted after partial save");
		app.begin();
		var previousReport = sys.io.File.getContent(folder + "/report.json");
		sys.io.File.saveContent(folder + "/blocked", "file");
		ctx.data = folder + "/blocked";
		app.stop(false);
		ctx.data = folder;
		check(!app.active && !app.finalizing && app.lastText.indexOf("WARNING") >= 0, "save failure did not keep recorder stopped with explicit warning");
		check(sys.io.File.getContent(folder + "/report.json") == previousReport, "failed save corrupted previous report");
		app.dispose();
		check(renderer.listeners == 0, "dispose leak");
		var idleApp = new Main();
		idleApp.init(ctx);
		idleApp.ready(ctx);
		idleApp.full.value = true;
		idleApp.liteSince = haxe.Timer.stamp() * 1000 - 600;
		idleApp.liteFrames = 71;
		idleApp.frame(new openfl.events.Event());
		check(!idleApp.active && idleApp.hud.metrics[0].text != "--" && idleApp.hud.metrics[5].text != "--", "idle full panel did not show live FPS/ping");
		idleApp.startCapacity();
		check(!idleApp.capacity.running && idleApp.hud.popupHeight == 290, "capacity starts before crash warning confirmation");
		idleApp.hud.closeReport();
		idleApp.dispose();
		var townUI = new openfl.display.Sprite();
		ctx.core.facade.sceneGraphManager = {
			get_UILayerGroup: function() {
				return townUI;
			}
		};
		ctx.state.inTown = true;
		ctx.core.facade.assetLoadingComponent = new brain.assetRepository.AssetLoadingComponent();
		var capacityLayer = renderer.stage;
		var previousStageChildren = capacityLayer.children.length;
		ctx.core.facade.starlingLayerManager = {starlingInstance: renderer, hudLayer: capacityLayer};
		var capacityText = "";
		var suite = new AnimationBench(ctx, function(t:String) {
			capacityText = t;
		});
		suite.start();
		check(!townUI.visible, "town OpenFL UI still covers the animation surface");
		check(suite.running && new CapacityStore(folder).read().status == "running", "suite did not checkpoint before allocation");
		for (_ in 0...(suite.recipes.length + 1))
			suite.tick(true);
		check(suite.index == 0 && suite.phase == "spawning", "asset loads did not advance to baseline");
		check(suite.scene.heroes.length == 4 && suite.document.protocol == 6, "map baseline did not create four heroes");
		var heroSymbols:Array<String> = [];
		for (hero in (cast suite.document.heroes : Array<Dynamic>)) {
			check(heroSymbols.indexOf(hero.symbol) < 0, "random heroes duplicated");
			heroSymbols.push(hero.symbol);
		}
		suite.tick(true);
		suite.warmUntil = 0;
		suite.phaseTime = 2000;
		suite.root.render(new starling.rendering.Painter());
		suite.root.render(new starling.rendering.Painter());
		suite.tick(true);
		check(suite.phase == "measuring" && suite.instances.length == 0, "empty baseline or warm-up failed");
		suite.phaseTime = 12100;
		suite.phaseAt = haxe.Timer.stamp() * 1000 - 12100;
		suite.last = haxe.Timer.stamp() * 1000 - 16;
		suite.root.render(new starling.rendering.Painter());
		suite.root.render(new starling.rendering.Painter());
		suite.tick(true);
		var checkpoint = new CapacityStore(folder).read();
		check(checkpoint.rounds.length == 1
			&& checkpoint.rounds[0].frame.frames == 1
			&& suite.index == 1, "completed round not durably saved");
		suite.tick(true);
		check(suite.instances.length == 2, "visual instance missing");
		var dragon = suite.instances[0];
		var breath = suite.instances[1];
		check(breath.pivotX == 0
			&& breath.pivotY == 0
			&& breath.scaleX == dragon.scaleX
			&& breath.y == dragon.y - dragon.pivotY * dragon.scaleY - 45 * dragon.scaleY,
			"breath no longer uses native dragon actor-origin attachment");
		var attempted = new CapacityStore(folder).read().operation;
		check(attempted.phase == "warm-up"
			&& attempted.assets[0].symbol == "db_emy_dragon", "active animation set missing from crash checkpoint");
		var interrupted = new AnimationBench(ctx, function(_) {});
		check(interrupted.interrupted() && interrupted.saved().indexOf("INTERRUPTED") >= 0, "restart did not recover incomplete session");
		suite.tick(false);
		check(suite.running && !townUI.visible, "unfocus stopped the controlled suite");
		suite.phaseTime = 2000;
		suite.root.render(new starling.rendering.Painter());
		suite.root.render(new starling.rendering.Painter());
		suite.tick(false);
		suite.root.render(new starling.rendering.Painter());
		suite.root.render(new starling.rendering.Painter());
		suite.phaseTime = 12100;
		suite.last = haxe.Timer.stamp() * 1000 - 16;
		suite.tick(false);
		check(suite.running && suite.document.rounds[1].backgroundFrames > 0, "background round stopped or was not marked in results");
		suite.finish("stopped");
		check(townUI.visible
			&& capacityLayer.children.length == previousStageChildren, "manual stop failed to restore town or clean render surface");
		var assetLoader = ctx.core.facade.assetLoadingComponent;
		assetLoader.failQueue = true;
		var failureSuite = new AnimationBench(ctx, function(t:String) capacityText = t);
		failureSuite.start();
		check(!failureSuite.running && townUI.visible && failureSuite.root == null && capacityText.indexOf("missing asset bundle") >= 0, "synchronous asset failure escaped or left town UI hidden");
		assetLoader.failQueue = false;
		assetLoader.missingTexture = true;
		failureSuite.start();
		for (_ in 0...(failureSuite.recipes.length + 2)) failureSuite.tick(true);
		check(!failureSuite.running && townUI.visible && capacityText.indexOf("Scenery texture unavailable") >= 0, "missing scenery did not fail safely");
		assetLoader.missingTexture = false;
		failureSuite.start();
		starling.display.Sprite.failRender = true;
		failureSuite.root.render(new starling.rendering.Painter());
		starling.display.Sprite.failRender = false;
		failureSuite.tick(true);
		check(!failureSuite.running && townUI.visible && capacityText.indexOf("Animation rendering failed") >= 0, "renderer failure was not contained");
		assetLoader.defer = true;
		failureSuite.start();
		var lateLoad = assetLoader.deferred;
		failureSuite.finish("stopped");
		lateLoad();
		check(!failureSuite.running && failureSuite.root == null && townUI.visible, "late loader callback revived a stopped benchmark");
		assetLoader.defer = false;

		var stable = new CapacityStore(folder);
		var good = stable.read();
		var slot = good.sequence % 2;
		sys.io.File.saveContent(folder + "/capacity-" + slot + ".json", "{broken");
		check(stable.read() != null && stable.read().sequence < good.sequence, "torn checkpoint lost fallback");
		suite.start();
		for (_ in 0...(suite.recipes.length + 1))
			suite.tick(true);
		suite.available[2] = false;
		suite.index = 16;
		suite.nextRound();
		check(suite.phase == "skip" && suite.document.rounds[0].status == "skipped", "missing dragon was silently substituted");
		suite.finish("stopped");
		suite.start();
		for (_ in 0...500) {
			if (!suite.running)
				break;
			suite.root.render(new starling.rendering.Painter());
			suite.root.render(new starling.rendering.Painter());
			if (suite.phase == "warmup") {
				suite.warmUntil = 0;
				suite.phaseTime = 2000;
			}
			if (suite.phase == "measuring") {
				suite.phaseTime = 12100;
				suite.phaseAt = haxe.Timer.stamp() * 1000 - 12100;
				suite.last = haxe.Timer.stamp() * 1000 - 16;
			}
			suite.tick(true);
		}
		var completed = new CapacityStore(folder).read();
		check(!suite.running && completed.status == "complete" && completed.rounds.length == CapacityPlan.rounds().length, "full protocol failed to finish or save every round");
		var extreme:Dynamic = completed.rounds[completed.rounds.length - 1];
		var totalInstances = 0;
		for (asset in (cast extreme.assets : Array<Dynamic>))
			totalInstances += asset.count;
		check(totalInstances == 160
			&& capacityLayer.children.length == previousStageChildren, "mixed counts incorrect or suite layer leaked");
		check(capacityText.indexOf("MOST DEMANDING") >= 0
			&& capacityText.indexOf("attack_breath_angE") >= 0, "full report lacks asset evidence or ranking");
		suite.start();
		for (_ in 0...(suite.recipes.length + 1))
			suite.tick(true);
		suite.tick(true);
		suite.warmUntil = 0;
		suite.phaseTime = 2000;
		suite.tick(true);
		check(!suite.running
			&& capacityText.indexOf("not rendered") >= 0
			&& townUI.visible, "invisible surface accepted a benchmark result or hid town UI");
		suite.start();
		suite.startedAt = haxe.Timer.stamp() * 1000 - CapacityPlan.MAX_MS - 1;
		suite.tick(false);
		check(!suite.running && capacityText.indexOf("time limit") >= 0 && townUI.visible,
			"wall time limit did not stop and restore the test");
		suite.dispose();
		interrupted.dispose();
		check(CapacityPlan.rounds()[CapacityPlan.rounds().length - 1].count == 160
			&& CapacityPlan.rounds()[0].count == 0, "capacity protocol is unbounded or has no baseline");
		for (file in sys.FileSystem.readDirectory(folder))
			sys.FileSystem.deleteFile(folder + "/" + file);
		sys.FileSystem.deleteDirectory(folder);
		var linked = new Session();
		linked.scene = "Dungeon";
		linked.snapshot = {
			map: "Test map",
			floor: 2,
			scene: "Dungeon",
			groups: [],
			enemies: 3,
			ping: 12,
			partial: false
		};
		linked.snapshotTime = 900;
		linked.intervalMods = [{name: "Test mod", ms: 108.0}];
		linked.frame(120, 1000, true, 0);
		check(linked.worst[0].mods[0].ms == 108 && linked.modPeaks[0].map == "Test map", "hitch/mod timing context lost");
		check(linked.modPeaks[0].recentFps == 8.3 && linked.worst[0].recentFps == 8.3, "one-second FPS context missing");
		check(linked.modPeaks[0].fps == 8.3, "peak mod frame pacing incorrect");
		linked.intervalMods = [{name: "Test mod", ms: 1.0}];
		linked.frame(16, 1016, true, 0);
		check(linked.modPeaks[0].ms == 108 && linked.modPeaks[0].at == 1000, "smaller sample replaced peak context");
		var sizing = new starling.extensions.animate.Animation();
		AnimationSizing.fit(sizing, 145);
		check(sizing.scaleX == 1.45 && sizing.pivotX == 0, "sizing used atlas dimensions instead of symbol bounds");
		check(HeroMotion.pose(0).label == "idle_angE"
			&& HeroMotion.pose(0.625).label == "run_angA"
			&& HeroMotion.pose(0.875).label == "run_angE",
			"baseline idle or vertical directions incorrect");
		var reportField = new openfl.text.TextField();
		ReportMarkup.apply(reportField, "TITLE\nFirst line\nSecond line", false);
		check(reportField.text == "TITLE\nFirst line\nSecond line" && reportField.multiline, "colored report collapsed lines");
		check(HeroMotion.pose(1.375).flip && !HeroMotion.pose(1.125).flip, "left/right facing incorrect");
		check(ReportMarkup.select("First line\nSecond line", false).indexOf("\n") >= 0, "report line breaks were lost");
		var clockPoints:Array<Dynamic> = [];
		for (i in 0...4) {
			var point = HeroMotion.pose(2, i);
			clockPoints.push(point);
			check(Math.abs(point.x * point.x / (145 * 145) + point.y * point.y / (110 * 110) - 1) < 0.0001, "heroes are not on one common ellipse");
		}
		check(Math.abs(clockPoints[0].x + clockPoints[3].x) < 0.001 && Math.abs(clockPoints[0].y + clockPoints[3].y) < 0.001,
			"heroes lost opposite clock positions");
		AnimationSizing.fitHeight(sizing, 145, {
			x: 0.,
			y: 0.,
			width: 200.,
			height: 100.
		});
		check(sizing.scaleY == 1.45 && sizing.pivotY == 100, "hero height was normalized by width instead");
		check(CapacityPlan.rounds().length * (CapacityPlan.ROUND_MS + CapacityPlan.WARMUP_MS) < 90000 && CapacityPlan.MAX_MS == 100000,
			"protocol exceeds its time budget");
		AnimationSizing.effect(sizing, {
			x: -85.1,
			y: -236.75,
			width: 170.,
			height: 268.09
		}, 1.2);
		check(Math.abs(sizing.scaleX - 145. / 170 * 1.2) < 0.0001
			&& 268.09 * sizing.scaleY < 300, "native firebomb was enlarged to viewport size");
		var friendly = CapacityStore.describe(completed);
		var visibleSummary = ReportMarkup.select(friendly, false);
		check(visibleSummary.indexOf("FPS BY ANIMATION SCENE") >= 0
			&& visibleSummary.indexOf("Lion Fury / Ally Frenzy") >= 0
			&& visibleSummary.indexOf("Enabled-mod environment") == -1,
			"user summary hides FPS or includes technical metadata");
		check(CapacityPlan.assetIndex(-2, 0) == 17 && CapacityPlan.assetIndex(-2, 1) == 18, "fury round uses wrong animal or flames");
		var isolatedKinds:Array<Int> = [];
		for (row in CapacityPlan.rounds())
			if (row.name.indexOf("Isolated: ") == 0) {
				check(row.count == 16 && isolatedKinds.indexOf(row.kind) < 0, "isolated comparisons differ in count or duplicate an effect");
				isolatedKinds.push(row.kind);
			}
		check(isolatedKinds.length == 11
			&& visibleSummary.indexOf("MATCHED EFFECT COMPARISON") >= 0, "matched effect comparison missing from report");
		trace("PASS: " + count + " benchmark regression checks (offline doubles; native compilation not verified)");
	}
}
