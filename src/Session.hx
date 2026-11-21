package mods.benchmark;

/** Associates preceding sampled activity with subsequent frame intervals. Never claims causation. */
class Session {
	public var total(default, null) = new FrameWindow();
	public var window(default, null) = new FrameWindow();
	public var worst(default, null):Array<Dynamic> = [];
	public var associations(default, null):Array<Dynamic> = [];

	var associationKeys:Array<String> = [];

	public var measured(default, null) = 0;
	public var excluded(default, null) = 0;
	public var excludedGaps(default, null):Array<Dynamic> = [];
	public var snapshot:Dynamic;
	public var scene = "Unknown";
	public var sceneAfter = "Unknown";
	public var snapshotTime = 0.0;
	public var lastProbeMs = 0.0;
	public var maxProbeMs = 0.0;

	public var intervalMods:Array<Dynamic> = [];
	public var modPeaks:Array<Dynamic> = [];

	var recentTimes:Array<Float> = [];
	var recentDurations:Array<Float> = [];
	var recentMs = 0.0;
	var recentFps = 0.0;
	var associationCount = 0;

	public function new() {}

	public function frame(ms:Float, now:Float, focused:Bool, selfWork:Float):Void {
		// Unfocused, suspend/resume, or heavy profiler work is retained as exclusions, not blamed on art.
		if (!focused || ms > 2000 || ms <= 0 || selfWork > 5) {
			excluded++;
			recentTimes = [];
			recentDurations = [];
			recentMs = 0;
			total.breakDips();
			window.breakDips();
			if (Math.isFinite(ms) && ms > 0) {
				excludedGaps.push({
					at: FrameWindow.round(now),
					ms: FrameWindow.round(ms),
					reason: !focused ? "unfocused" : ms > 2000 ? "long gap / suspend or freeze" : "profiler overhead"
				});
				excludedGaps.sort(function(a, b) return a.ms > b.ms ? -1 : a.ms < b.ms ? 1 : 0);
				if (excludedGaps.length > 8)
					excludedGaps.resize(8);
			}
			return;
		}
		total.add(ms);
		window.add(ms);
		measured++;
		recentTimes.push(now);
		recentDurations.push(ms);
		recentMs += ms;
		while (recentTimes.length > 1 && (recentTimes[0] < now - 1000 || recentTimes.length > 1024)) {
			recentTimes.shift();
			recentMs -= recentDurations.shift();
		}
		recentFps = recentMs > 0 ? FrameWindow.round(recentTimes.length * 1000 / recentMs) : 0;
		for (mod in intervalMods) {
			var previous:Dynamic = null;
			for (peak in modPeaks)
				if (peak.name == mod.name) {
					previous = peak;
					break;
				}
			if (previous == null) {
				previous = {name: mod.name, ms: 0.0};
				modPeaks.push(previous);
			}
			if (mod.ms > previous.ms) {
				previous.ms = mod.ms;
				previous.at = FrameWindow.round(now);
				previous.frameMs = FrameWindow.round(ms);
				previous.fps = FrameWindow.round(1000 / ms);
				previous.recentFps = recentFps;
				previous.scene = scene;
				previous.map = snapshot != null && now - snapshotTime <= 1250 ? snapshot.map : "Unknown";
				previous.floor = snapshot != null && now - snapshotTime <= 1250 ? snapshot.floor : null;
			}
		}
		var usable = snapshot != null && now - snapshotTime <= 1250 && (snapshot.scene == null || snapshot.scene == scene);
		if (ms >= 50)
			recordHitch(ms, now, usable);
		if (!usable)
			return;
		for (group in (cast snapshot.groups : Array<Dynamic>)) {
			var key:String = group.key;
			var index = KeyIndex.find(associationKeys, key);
			var row:Dynamic = index >= 0 ? associations[index] : null;
			if (row == null) {
				if (associationCount >= 1024)
					continue;
				row = {
					key: key,
					frames: 0,
					sumMs: 0.0,
					worstMs: 0.0,
					slowFrames: 0,
					maxInstances: 0
				};
				index = -index - 1;
				associationKeys.insert(index, key);
				associations.insert(index, row);
				associationCount++;
			}
			row.frames++;
			row.sumMs += ms;
			row.worstMs = Math.max(row.worstMs, ms);
			if (ms >= 50)
				row.slowFrames++;
			row.maxInstances = Std.int(Math.max(row.maxInstances, group.count));
		}
	}

	function recordHitch(ms:Float, now:Float, usable:Bool):Void {
		var context:Array<Dynamic> = [];
		if (usable)
			for (group in (cast snapshot.groups : Array<Dynamic>)) {
				if (context.length == 8)
					break;
				context.push({key: group.key, count: group.count, metadata: group.metadata});
			}
		worst.push({
			at: FrameWindow.round(now),
			recentFps: recentFps,
			ms: FrameWindow.round(ms),
			map: usable ? snapshot.map : "Context unavailable",
			floor: usable ? snapshot.floor : 0,
			enemies: usable ? snapshot.enemies : null,
			ping: usable ? snapshot.ping : null,
			partial: !usable || snapshot.partial,
			contextAgeMs: usable ? FrameWindow.round(now - snapshotTime) : null,
			contextAvailable: usable,
			scene: scene,
			sceneAfter: sceneAfter,
			mods: intervalMods.slice(0, 5),
			groups: context
		});
		worst.sort(function(a, b) return a.ms > b.ms ? -1 : a.ms < b.ms ? 1 : 0);
		if (worst.length > 12)
			worst.resize(12);
	}

	public function ranked():Array<Dynamic> {
		var result:Array<Dynamic> = [];
		var base = total.frames > 0 ? total.elapsed / total.frames : 0;
		for (row in associations) {
			if (row.frames < 10)
				continue;
			result.push({
				key: row.key,
				frames: row.frames,
				meanMs: FrameWindow.round(row.sumMs / row.frames),
				aboveSessionMeanMs: FrameWindow.round(row.sumMs / row.frames - base),
				worstMs: FrameWindow.round(row.worstMs),
				slowFrames: row.slowFrames,
				maxInstances: row.maxInstances
			});
		}
		result.sort(function(a, b) return a.aboveSessionMeanMs > b.aboveSessionMeanMs ? -1 : a.aboveSessionMeanMs < b.aboveSessionMeanMs ? 1 : 0);
		if (result.length > 20)
			result.resize(20);
		return result;
	}

	public function takeWindow():Dynamic {
		var result = window.report();
		window = new FrameWindow();
		return result;
	}
}
