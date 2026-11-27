package mods.benchmark;

import mods.api.Context;
import mods.api.Subscription;
import mods.api.settings.Flag;
import openfl.events.Event;
import starling.events.Event as RenderEvent;

class Main extends mods.api.Mod {
	var ctx:Context;
	var shown = true;
	var hud:Hud;
	var lite:LiteHud;
	var capacity:AnimationBench;
	var full:Flag;
	var liteFrames = 0;
	var stats:SystemStats;
	/** The mod version written into reports and captions; keep it equal to mod.json. */
	public static inline final VERSION = "0.1.27";

	var showRam:Flag;
	var showCpu:Flag;
	var showVram:Flag;
	var nextStats = 0.0;
	var statCpu:Null<String> = null;
	var statRam:Null<String> = null;
	var statVram:Null<String> = null;
	var liteSince = 0.0;
	var probe = new NativeProbe();
	var session:Session;
	var log:CompactLog;
	var active = false;
	var finalizing = false;
	var lastText:Null<String>;
	var recordingFaults:Array<Dynamic> = [];
	var framePhase = "idle";
	var focused = true;
	var subs:Array<Subscription> = [];
	var start = 0.0;
	var last = 0.0;
	var nextProbe = 0.0;
	var nextWrite = 0.0;
	var nextHud = 0.0;
	var ownMs = 0.0;
	var elapsed = 0;
	var draws = 0;
	var drawSum = 0.0;
	var renders = 0;
	var renderPeak = 0;
	var live = new FrameWindow();
	var liveStart = 0.0;
	var fps = 0.0;
	var process:Dynamic;
	var errors = 0;
	var cpuGauge = new Gauge();
	var gpuGauge = new Gauge();
	var ramGauge = new Gauge();
	var pingGauge = new Gauge();
	var drawGauge = new Gauge();
	var modProfiler = new ModProfiler();
	var frameBudget = 0.0;
	var lastScene = "Unknown";

	override public function init(context:Context):Void {
		ctx = context;
		Faults.reset();
		Faults.logger = function(message:String) ctx.log(message);
		subs.push(ctx.keys.action("toggleHud", "Show / hide Benchmark", "Show or hide the FPS/ping and recording panel without stopping a recording.",
			openfl.ui.Keyboard.F7)
			.onPress(function() {
				shown = !shown;
				if (hud != null)
					hud.visible = shown && full.value;
				if (lite != null)
					lite.visible = shown && !full.value;
			}));
		full = ctx.settings.flag("fullBenchmark", "Full Benchmark", "On: full recording. Off: live FPS and ping.", false);
		showCpu = ctx.settings.flag("showCpu", "Show CPU", "Shows the game's share of your whole CPU next to FPS (where the PC's thread count is unknown: the number of cores the game uses).", false);
		showVram = ctx.settings.flag("showVram", "Show texture memory (VRAM)", "Shows the graphics memory the game's renderer allocated for textures and buffers, by its own count, next to FPS. Not the game's whole VRAM use as Task Manager or the driver counts it, which is often far more.", false);
		showRam = ctx.settings.flag("showRam", "Show Haxe heap (RAM)", "Shows the Haxe heap next to FPS: the memory of the game's code, about half of what Task Manager shows for the game, garbage not yet collected included.", false);
		stats = new SystemStats();
		// Scene boundaries are API events. They are not inferred from native map internals.
		subs.push(ctx.onFloorEnter(function(_) boundary("floor-enter")));
		subs.push(ctx.onFloorExit(function(_) boundary("floor-exit")));
		subs.push(ctx.onTownEnter(function() boundary("town-enter")));
		subs.push(ctx.onTownExit(function() boundary("town-exit")));
	}

	override public function ready(context:Context):Void {
		capacity = new AnimationBench(ctx, function(text:String) {
			hud.visible = shown && full.value;
			hud.report(text);
			hud.layout(ctx.viewWidth, ctx.viewHeight);
		});
		hud = new Hud(begin, function() stop(), showReport, ctx.data + "/ui.json", startCapacity, function() {
			hud.report(capacity.saved());
			hud.layout(ctx.viewWidth, ctx.viewHeight);
		});
		ctx.overlay.addChild(hud);
		lite = new LiteHud(ctx.data + "/lite-ui.json");
		// Both panels open at the same spot: moving one moves the other's saved place too (each keeps its own size).
		hud.onMoved = function(px:Float, py:Float) lite.moveTo(px, py);
		lite.onMoved = function(px:Float, py:Float) hud.moveTo(px, py);
		ctx.overlay.addChild(lite);
		hud.visible = shown && full.value;
		lite.visible = shown && !full.value;
		liteSince = haxe.Timer.stamp() * 1000;
		ctx.overlay.addEventListener(Event.ENTER_FRAME, frame);
		if (ctx.overlay.stage != null) {
			ctx.overlay.stage.addEventListener(Event.ACTIVATE, activate);
			ctx.overlay.stage.addEventListener(Event.DEACTIVATE, deactivate);
		}
		hud.update(false, 0, "N/A|N/A|N/A|N/A|N/A|N/A");
		if (capacity.interrupted()) {
			full.value = true;
			shown = true;
			hud.visible = true;
			lite.visible = false;
			hud.report(capacity.saved());
		}
	}

	function startCapacity():Void {
		if (!full.value || capacity.running)
			return;
		hud.confirmCapacity(runCapacity);
	}

	function runCapacity():Void {
		if (!full.value || capacity.running)
			return;
		if (active)
			stop(false);
		hud.closeReport();
		try
			capacity.start()
		catch (e:Dynamic) {
			if (capacity.running)
				capacity.finish("failed: " + Std.string(e));
			else
				hud.report("Controlled benchmark could not start: " + Std.string(e));
		}
	}

	function begin():Void {
		if (capacity != null && capacity.running)
			return;
		if (!full.value || active || finalizing)
			return;
		recordingFaults = [];
		session = new Session();
		probe = new NativeProbe();
		cpuGauge = new Gauge();
		gpuGauge = new Gauge();
		ramGauge = new Gauge();
		pingGauge = new Gauge();
		drawGauge = new Gauge();
		log = new CompactLog(ctx.data);
		frameBudget = ctx.overlay.stage == null || ctx.overlay.stage.frameRate <= 0 ? 0 : 1000 / ctx.overlay.stage.frameRate;
		modProfiler.start(ctx);
		start = haxe.Timer.stamp() * 1000;
		last = start;
		liveStart = start;
		nextProbe = start;
		nextWrite = start + 5000;
		nextHud = start;
		elapsed = 0;
		errors = 0;
		ownMs = 0;
		renders = 0;
		drawSum = 0;
		renderPeak = 0;
		live = new FrameWindow();
		process = null;
		try {
			sys.io.File.saveContent(ctx.data + "/attach.json", haxe.Json.stringify({
				session: log.session,
				running: true,
				output: ctx.data + "/process.json",
				started: Date.now().getTime()
			}));
		} catch (error:Dynamic) {
			Faults.report("process sampler session save", error);
		}
		try {
			probe.connect(ctx);
			if (probe.renderer != null)
				probe.renderer.addEventListener("renderComplete", rendered);
		} catch (_:Dynamic) {
			errors++;
		}
		lastScene = probe.scene(ctx);
		active = true;
	}

	function boundary(kind:String):Void {
		if (!active)
			return;
		session.snapshot = null;
		nextProbe = 0;
		log.reserve();
		log.write({type: "scene", event: kind, at: FrameWindow.round(haxe.Timer.stamp() * 1000 - start)});
	}

	function rendered(event:RenderEvent):Void {
		if (!active || probe.renderer == null)
			return;
		try {
			draws = probe.renderer.painter_instance.drawCount;
			drawSum += draws;
			drawGauge.add(draws);
			renders++;
			renderPeak = Std.int(Math.max(renderPeak, draws));
		} catch (_:Dynamic) {
			errors++;
		}
	}

	function frame(event:Event):Void {
		try
			sampleFrame(event)
		catch (error:Dynamic)
			recordingFault(framePhase, error);
	}

	function sampleFrame(event:Event):Void {
		if (hud == null)
			return;
		hud.visible = shown && full.value;
		lite.visible = shown && !full.value;
		if (capacity != null && capacity.running) {
			if (!full.value)
				capacity.finish("stopped: Full Benchmark disabled");
			else {
				hud.visible = false;
				capacity.tick(focused);
			}
			return;
		}
		if (!full.value) {
			if (active)
				stop(false);
			lite.layout(ctx.viewWidth, ctx.viewHeight);
			updateIdle(true);
			return;
		}
		hud.layout(ctx.viewWidth, ctx.viewHeight);
		if (!active) {
			updateIdle(false);
			return;
		}
		var entered = haxe.Timer.stamp() * 1000;
		var dt = entered - last;
		last = entered;
		framePhase = "frame measurements";
		var currentScene = probe.scene(ctx);
		session.scene = lastScene;
		session.sceneAfter = currentScene;
		lastScene = currentScene;
		session.intervalMods = modProfiler.drain();
		session.frame(dt, entered - start, focused, ownMs);
		if (dt > 0 && dt <= 2000)
			live.add(dt);
		elapsed = Std.int((entered - start) / 1000);
		framePhase = "native snapshot";
		if (entered >= nextProbe) {
			nextProbe = entered + 250;
			var priorFailures = probe.failures;
			try {
				session.snapshot = probe.snapshot(ctx, true);
				session.snapshotTime = entered - start;
				session.lastProbeMs = session.snapshot.scanMs;
				session.maxProbeMs = Math.max(session.maxProbeMs, session.lastProbeMs);
			} catch (error:Dynamic) {
				session.snapshot = null;
				probe.failure(probe.stage, error);
			}
			errors += probe.failures - priorFailures;
		}
		framePhase = "live metrics";
		if (entered >= nextHud) {
			nextHud = entered + 1000;
			fps = live.elapsed > 0 ? live.frames * 1000 / live.elapsed : 0;
			live = new FrameWindow();
			process = ProcessSample.read(ctx.data + "/process.json", log.session, Date.now().getTime());
			var ping:Dynamic = session.snapshot == null ? null : session.snapshot.ping;
			pingGauge.add(ping);
			if (process != null) {
				cpuGauge.add(process.cpu);
				gpuGauge.add(process.gpu);
				ramGauge.add(process.ram);
			}
			refreshStats(entered);
			hud.update(true, elapsed, fullCells(fps, ping, process));
		}
		framePhase = "window summary";
		if (entered >= nextWrite) {
			nextWrite = entered + 5000;
			writeWindow(entered);
		}
		ownMs = haxe.Timer.stamp() * 1000 - entered;
	}

	/** RAM, CPU and GPU lines for the compact display: read once a second, and only those switched on. */
	/** The game's renderer, for the GPU memory reading. */
	function painter():starling.rendering.Painter {
		var facade = ctx.core.facade;
		var manager = facade == null ? null : facade.starlingLayerManager;
		var engine:starling.core.Starling = manager == null ? null : manager.starlingInstance;
		if (engine == null)
			engine = starling.core.Starling.current;
		return engine == null ? null : engine.painter_instance;
	}

	/**
	 * In-game CPU, texture memory (VRAM) and Haxe heap (RAM) readings, refreshed once a second for the switches that are on (a switch turned
	 * off clears its reading at once). Both the compact display and the full window show them.
	 */
	function refreshStats(now:Float):Void {
		if (!showCpu.value) {
			statCpu = null;
			stats.resetCpu();
		}
		if (!showRam.value)
			statRam = null;
		if (!showVram.value)
			statVram = null;
		if (!showRam.value && !showCpu.value && !showVram.value)
			return;
		if (now < nextStats)
			return;
		nextStats = now + 1000;
		try {
			if (showCpu.value)
				statCpu = stats.cpu();
			if (showRam.value)
				statRam = stats.ram();
			if (showVram.value)
				statVram = stats.vram(painter());
		} catch (error:Dynamic) {
			Faults.report("system readings", error);
		}
	}

	/**
	 * The full window's cards, in display order: FPS, CPU, GPU load, Textures (VRAM), Heap (RAM), Ping. CPU and the
	 * memory card come from the optional process sampler when it runs (then the memory card is named Process RAM: the
	 * whole process), else from the in-game readings that are switched on; GPU load only exists with the sampler.
	 * Unavailable cards are hidden.
	 */
	function fullCells(fps:Float, ping:Dynamic, process:Dynamic):String {
		var cpu = process != null && process.cpu != null ? metric(process.cpu, "%") : statCpu;
		var processRam = process != null && process.ram != null;
		var ram = processRam ? memory(process.ram) : statRam;
		if (hud != null)
			hud.setMemoryTitle(processRam);
		return [
			Std.string(FrameWindow.round(fps)),
			cpu == null ? "N/A" : cpu,
			metric(process == null ? null : process.gpu, "%"),
			statVram == null ? "N/A" : statVram,
			ram == null ? "N/A" : ram,
			metric(ping, "ms")
		].join("|");
	}

	function updateIdle(compact:Bool):Void {
		liteFrames++;
		var now = haxe.Timer.stamp() * 1000;
		refreshStats(now);
		if (compact)
			lite.setStats(statRam, statCpu, statVram);
		if (now - liteSince < 500)
			return;
		var ping:Dynamic = null;
		try {
			var facade = ctx.core.facade;
			if (facade != null && facade.dbAccountInfo != null)
				ping = facade.dbAccountInfo.SocketPingMilsecs;
		} catch (error:Dynamic) {
			Faults.report("compact heartbeat read", error);
		}
		var current = liteFrames * 1000 / (now - liteSince);
		if (compact)
			lite.update(current, ping);
		else
			hud.update(false, elapsed, fullCells(current, ping, null));
		liteFrames = 0;
		liteSince = now;
	}

	function writeWindow(now:Float):Void {
		try
			writeWindowData(now)
		catch (error:Dynamic)
			recordingFault("window summary", error);
	}

	function writeWindowData(now:Float):Void {
		log.reserve();
		var groups:Array<Dynamic> = [];
		var snap = session.snapshot;
		if (snap != null)
			for (group in (cast snap.groups : Array<Dynamic>))
				groups.push([log.intern(group.key, group.metadata), group.count]);
		log.write({
			type: "window",
			at: FrameWindow.round(now - start),
			frame: session.takeWindow(),
			rendered: renders,
			drawMean: FrameWindow.round(renders > 0 ? drawSum / renders : 0),
			drawPeak: renderPeak,
			process: process,
			map: snap == null ? "unknown" : snap.map,
			floor: snap == null ? 0 : snap.floor,
			enemies: snap == null ? 0 : snap.enemies,
			ping: snap == null ? null : snap.ping,
			partial: snap == null ? true : snap.partial,
			sceneNodes: snap == null ? 0 : snap.sceneNodes,
			sceneAnimations: snap == null ? 0 : snap.animations,
			sceneFilters: snap == null ? 0 : snap.filters,
			mainScene: lastScene,
			flashNodes: snap == null ? 0 : snap.flashNodes,
			flashAnimations: snap == null ? 0 : snap.flashAnimations,
			groups: groups,
			snapshotAgeMs: snap == null ? null : FrameWindow.round(now - start - session.snapshotTime),
			profilerPreviousFrameMs: FrameWindow.round(ownMs),
			scanPeakMs: session.maxProbeMs,
			errors: errors,
			adapterFaults: probe.faults,
			mods: modProfiler.report(frameBudget),
			modProfilingError: modProfiler.error
		});
		log.flush();
		renders = 0;
		drawSum = 0;
		renderPeak = 0;
	}

	function recordingFault(phase:String, error:Dynamic):Void {
		var message = Std.string(error);
		if (message.length > 240)
			message = message.substr(0, 240);
		for (row in recordingFaults)
			if (row.phase == phase && row.message == message) {
				row.count++;
				return;
			}
		if (recordingFaults.length < 12)
			recordingFaults.push({phase: phase, message: message, count: 1});
	}

	function stop(?show:Bool = true):Void {
		if (!active || finalizing)
			return;
		active = false;
		finalizing = true;
		liteFrames = 0;
		liteSince = haxe.Timer.stamp() * 1000;
		var now = haxe.Timer.stamp() * 1000;
		elapsed = Std.int((now - start) / 1000);
		// Update controls before native cleanup, summaries or disk I/O can throw.
		try {
			hud.update(false, elapsed, "Stopped.");
			hud.setStatus("Recording stopped - saving results");
		} catch (error:Dynamic)
			recordingFault("stop controls", error);
		try
			sys.io.File.saveContent(ctx.data + "/attach.json", haxe.Json.stringify({session: log.session, running: false}))
		catch (error:Dynamic)
			recordingFault("sampler stop", error);
		try {
			if (probe.renderer != null)
				probe.renderer.removeEventListener("renderComplete", rendered);
		} catch (error:Dynamic)
			recordingFault("render cleanup", error);
		var modReport:Array<Dynamic> = [];
		try
			modReport = modProfiler.report(frameBudget)
		catch (error:Dynamic)
			recordingFault("mod summary", error);
		try
			modProfiler.dispose()
		catch (error:Dynamic)
			recordingFault("mod observer cleanup", error);
		writeWindow(now);
		var f:Dynamic;
		try
			f = session.total.report()
		catch (error:Dynamic) {
			recordingFault("frame summary", error);
			var total = session.total;
			f = {
				frames: total.frames,
				fps: total.elapsed > 0 ? FrameWindow.round(total.frames * 1000 / total.elapsed) : 0,
				ms: total.elapsed,
				worst: total.worst,
				stalls: total.stalls,
				p95: null,
				p99: null,
				fpsDrops: null
			};
		}
		var report:Dynamic = {
			schema: 1,
			version: Main.VERSION,
			session: log.session,
			seconds: elapsed,
			frame: f,
			excluded: session.excluded,
			excludedGaps: session.excludedGaps,
			worst: session.worst,
			modPeaks: session.modPeaks,
			associations: [],
			mods: modReport,
			modProfilingError: modProfiler.error,
			configuredFrameBudgetMs: frameBudget,
			errors: errors,
			adapterFaults: probe.faults,
			maxScanMs: session.maxProbeMs,
			logFailed: log.failed,
			recordingFaults: recordingFaults,
			warnings: Faults.snapshot()
		};
		try
			report.associations = session.ranked()
		catch (error:Dynamic)
			recordingFault("activity summary", error);
		try {
			report.process = {
				identity: process == null ? null : {pid: process.pid, name: process.name},
				cpu: cpuGauge.report(),
				gpu: gpuGauge.report(),
				ram: ramGauge.report()
			};
			report.ping = pingGauge.report();
			report.draws = drawGauge.report();
		} catch (error:Dynamic)
			recordingFault("resource summary", error);
		try {
			log.write({
				type: "stop",
				seconds: elapsed,
				recordingFaults: recordingFaults,
				warnings: Faults.snapshot()
			});
			log.flush();
		} catch (error:Dynamic)
			recordingFault("log finalization", error);
		report.logFailed = log.failed;
		var saved = false;
		try {
			sys.io.File.saveContent(ctx.data + "/report.json", haxe.Json.stringify(report));
			saved = true;
		} catch (error:Dynamic)
			recordingFault("report save", error);
		try
			lastText = Results.describe(report)
		catch (error:Dynamic) {
			recordingFault("readable summary", error);
			lastText = "Recording stopped after "
				+ elapsed
				+ " seconds. The readable summary could not be generated. "
				+ (saved ? "Fresh raw data was saved to report.json." : "The new report could not be saved; the previous file is older data.");
		}
		if (!saved)
			lastText = "WARNING: saving this recording failed. This is the current in-memory result, not the older saved report.\n\n" + lastText;
		try
			sys.io.File.saveContent(ctx.data + "/report.txt", lastText)
		catch (error:Dynamic)
			recordingFault("text save", error);
		if (recordingFaults.length > 0)
			try
				sys.io.File.saveContent(ctx.data + "/recording-errors.json", haxe.Json.stringify(recordingFaults))
			catch (error:Dynamic) {
				Faults.report("recording error report save", error);
			}
		finalizing = false;
		try {
			hud.setStatus(saved ? "Stopped - results saved" : "Stopped - report save failed");
			if (show) {
				hud.report(lastText);
				hud.layout(ctx.viewWidth, ctx.viewHeight);
			}
		} catch (error:Dynamic)
			recordingFault("results display", error);
	}

	function showReport():Void {
		if (!full.value)
			return;
		if (active) {
			stop();
			return;
		}
		if (lastText != null) {
			hud.report(lastText);
			hud.layout(ctx.viewWidth, ctx.viewHeight);
			return;
		}
		var path = ctx.data + "/report.json";
		try {
			if (!sys.FileSystem.exists(path)) {
				hud.report("No saved benchmark yet. Press Start, play normally in town or a dungeon, then press Stop.");
				return;
			}
			hud.report(Results.describe(haxe.Json.parse(sys.io.File.getContent(path))));
			hud.layout(ctx.viewWidth, ctx.viewHeight);
		} catch (_:Dynamic) {
			hud.report("The saved benchmark report could not be read.");
		}
	}

	function activate(_:Event):Void {
		if (capacity != null)
			capacity.focusChanged(true);
		liteFrames = 0;
		liteSince = haxe.Timer.stamp() * 1000;
		focused = true;
		boundary("focus-gained");
		last = haxe.Timer.stamp() * 1000;
	}

	function deactivate(_:Event):Void {
		if (capacity != null)
			capacity.focusChanged(false);
		liteFrames = 0;
		liteSince = haxe.Timer.stamp() * 1000;
		focused = false;
		boundary("focus-lost");
	}

	static function memory(value:Dynamic):String {
		return value == null ? "N/A" : value >= 1024 ? Std.string(FrameWindow.round(value / 1024)) + "GB" : Std.string(FrameWindow.round(value)) + "MB";
	}

	static function metric(value:Dynamic, suffix:String):String
		return value == null ? "N/A" : Std.string(FrameWindow.round(value)) + suffix;

	override public function dispose():Void {
		if (capacity != null)
			capacity.dispose();
		if (active)
			stop(false);
		modProfiler.dispose();
		for (sub in subs)
			sub.cancel();
		if (ctx != null) {
			ctx.overlay.removeEventListener(Event.ENTER_FRAME, frame);
			if (ctx.overlay.stage != null) {
				ctx.overlay.stage.removeEventListener(Event.ACTIVATE, activate);
				ctx.overlay.stage.removeEventListener(Event.DEACTIVATE, deactivate);
			}
		}
		if (lite != null) {
			lite.dispose();
			if (lite.parent != null)
				lite.parent.removeChild(lite);
			lite = null;
		}
		if (hud != null)
			hud.dispose();
		if (hud != null && hud.parent != null)
			hud.parent.removeChild(hud);
		hud = null;
		Faults.logger = null;
	}
}
