package mods.benchmark;

/** Plain-language conclusions from saved measurements, with explicit evidence limits. */
class Interpretation {
	public static function describe(report:Dynamic):String {
		var f:Dynamic = report.frame;
		var fps:Float = f.fps;
		var seconds:Float = report.seconds;
		var lines:Array<String> = ["YOUR RESULTS, EXPLAINED", ""];
		var incomplete = report.recordingFaults != null && report.recordingFaults.length > 0;
		if (report.recordingFaults != null && report.recordingFaults.length > 0) {
			lines.push("PARTIAL RECORDING: a benchmark operation failed. Recording is stopped and recoverable data is retained.");
			for (fault in (cast report.recordingFaults : Array<Dynamic>))
				lines.push(fault.phase + ": " + fault.message + " (" + fault.count + " times)");
			lines.push("");
		}
		if (f.frames == 0) {
			lines.push("There are no accepted frame measurements. Record a focused gameplay session before drawing conclusions.");
			return lines.join("\n");
		}
		lines.push("Most frames were "
			+ (fps >= 90 ? "fast" : fps >= 55 ? "generally smooth" : fps >= 30 ? "moderately paced" : "slow")
			+ ": the average was "
			+ f.fps
			+ " FPS over "
			+ report.seconds
			+ " seconds. An average alone can hide short freezes.");
		if (f.p95 != null && f.p95 > 0 && f.p99 != null && f.p99 > 0)
			lines.push("95% of accepted frames met about " + FrameWindow.round(1000 / f.p95) + " FPS pacing or better; 99% met about "
				+ FrameWindow.round(1000 / f.p99) + " FPS pacing or better.");
		else
			lines.push("Percentiles were unavailable; basic frame totals are retained.");
		if (f.fpsDrops != null) {
			for (drop in (cast f.fpsDrops : Array<Dynamic>))
				if (drop.threshold >= 30)
					lines.push("Below " + drop.threshold + " FPS pacing: " + drop.dips + " separate dips (" + drop.frames + " affected frames).");
			lines.push("A dip groups consecutive slow frames. FPS pacing is the inverse of individual frame duration, not a one-second FPS average.");
			if (report.configuredFrameBudgetMs != null && report.configuredFrameBudgetMs > 1000 / 70)
				lines.push("Your configured frame-rate target is below 70 FPS, so being below that threshold can be expected.");
		} else
			lines.push("FPS threshold counts are unavailable in this older recording. A new recording is needed for exact dip counts.");
		if (f.stalls > 0) {
			var percent = Math.round(10000 * f.stalls / f.frames) / 100;
			lines.push("There were "
				+ f.stalls
				+ " severe slow frames (20 FPS pacing or worse), "
				+ percent
				+ "% of accepted frames"
				+ (seconds > 0 ? ", roughly one every " + FrameWindow.round(seconds / f.stalls) + " seconds on average" : "")
				+ ".");
			lines.push("Worst recorded frame: about "
				+ FrameWindow.round(1000 / f.worst)
				+ " FPS equivalent (a "
				+ FrameWindow.round(f.worst / 1000)
				+ " second pause). This was an individual frame, not the sustained frame rate.");
		} else
			lines.push("No accepted frame reached 20 FPS pacing or worse. Smaller stutters can still occur.");
		if (report.errors > 0) {
			lines.push("");
			lines.push("IMPORTANT: SOME DIAGNOSTICS FAILED");
			lines.push(report.errors
				+
				" adapter errors were recorded. FPS and frame times were still collected, but animation/enemy attribution may be incomplete or unavailable. A zero scan time is not proof that scanning was free.");
			lines.push("The report cannot identify which animation caused a drop. Repeated scanner errors need investigation; simply recording longer will not fix them.");
		}
		if (report.ping == null || report.ping.samples == 0)
			lines.push("Network latency was not measured. This session cannot establish whether network lag contributed.");
		else
			lines.push("Heartbeat latency averaged "
				+ report.ping.mean
				+ " ms and peaked at "
				+ report.ping.peak
				+ " ms. This includes local scheduling delay and is not an isolated network test.");
		if (report.mods != null) {
			var mods:Array<Dynamic> = report.mods;
			var peak = mods.copy();
			peak.sort(function(a, b) {
				var av:Float = a.peakDispatchMs == null ? -1 : a.peakDispatchMs;
				var bv:Float = b.peakDispatchMs == null ? -1 : b.peakDispatchMs;
				return av > bv ? -1 : av < bv ? 1 : 0;
			});
			lines.push("");
			lines.push("MODS TO INVESTIGATE FIRST");
			var shown = 0;
			for (row in peak) {
				if (row.peakDispatchMs == null || row.peakDispatchMs < 50 || shown >= 3)
					continue;
				lines.push(row.name + ": an observed frame-callback dispatch reached " + row.peakDispatchMs + " ms, while its observed average was "
					+ row.observedMeanMs + " ms/frame.");
				shown++;
			}
			if (shown == 0)
				lines.push("No observed mod dispatch reached 50 ms. This does not rule out work outside the measured callbacks.");
			lines.push("These peaks are investigation leads, not proof of the cause of the worst game frame. Garbage collection, loading and OS pauses may occur inside a measured span. Small averages can coexist with rare large pauses.");
			lines.push("The mod percentage is a share of the configured frame-time budget, not a CPU or GPU percentage. Values rounded to zero do not mean the mod uses no resources.");
		}
		lines.push("");
		lines.push("WHAT TO DO NEXT");
		lines.push(report.errors > 0
			|| incomplete ? "Resolve the recorder/adapter errors before trusting animation rankings or mod comparisons. Then compare repeat recordings of the same map and actions, changing one optional mod at a time." : "Compare repeat recordings of the same map and actions, changing one optional mod at a time. Look for repeatable changes in p99, worst frames and hitch count.");
		lines.push("This report does not establish a CPU or GPU bottleneck or assign memory ownership to individual mods.");
		return lines.join("\n");
	}
}
