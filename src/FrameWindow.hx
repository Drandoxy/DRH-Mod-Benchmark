package mods.benchmark;

/** Frame intervals, not GPU execution times. Bounded 1 ms histogram. */
class FrameWindow {
	public var frames(default, null) = 0;
	public var elapsed(default, null) = 0.0;
	public var worst(default, null) = 0.0;
	public var stalls(default, null) = 0;

	var levels:Array<Int> = [70, 60, 30, 20];
	var below:Array<Int> = [0, 0, 0, 0];
	var dips:Array<Int> = [0, 0, 0, 0];
	var wasBelow:Array<Bool> = [false, false, false, false];
	var bins:Array<Int> = [for (_ in 0...2001) 0];

	public function new() {}

	public function add(ms:Float):Void {
		if (!Math.isFinite(ms) || ms <= 0 || ms > 2000)
			return;
		frames++;
		elapsed += ms;
		worst = Math.max(worst, ms);
		if (ms >= 50)
			stalls++;
		bins[Std.int(Math.ceil(ms))]++;
		for (i in 0...levels.length) {
			var slow = ms > 1000.0 / levels[i];
			if (slow) {
				below[i]++;
				if (!wasBelow[i])
					dips[i]++;
			}
			wasBelow[i] = slow;
		}
	}

	public function report():Dynamic {
		var thresholds:Array<Dynamic> = [];
		for (i in 0...levels.length) {
			var threshold:Int = levels[i];
			var affected:Int = below[i];
			var episodes:Int = dips[i];
			thresholds.push({threshold: threshold, frames: affected, dips: episodes});
		}
		return {
			frames: frames,
			ms: round(elapsed),
			fps: round(elapsed > 0 ? frames * 1000 / elapsed : 0),
			p95: percentile(0.95),
			p99: percentile(0.99),
			worst: round(worst),
			stalls: stalls,
			percentileSamples: frames,
			quantileResolutionMs: 1,
			fpsDrops: thresholds
		};
	}

	public function breakDips():Void {
		for (i in 0...wasBelow.length)
			wasBelow[i] = false;
	}

	function percentile(p:Float):Float {
		if (frames == 0)
			return 0;
		var target = Math.ceil(frames * p);
		var seen = 0;
		for (i in 0...bins.length) {
			seen += bins[i];
			if (seen >= target)
				return i;
		}
		return 0;
	}

	public static function round(n:Float):Float
		return Math.round(n * 10) / 10;
}
