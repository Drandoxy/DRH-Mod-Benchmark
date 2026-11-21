package mods.benchmark;

class Results {
	static function gauge(g:Dynamic, unit:String):String {
		return g == null || g.samples == 0 ? "N/A" : Std.string(g.mean) + unit + " avg / " + g.peak + unit + " peak";
	}

	public static function describe(report:Dynamic):String {
		var frame:Dynamic = report.frame;
		var average:Float = frame.fps;
		var lines:Array<String> = ["Recorded for " + report.seconds + " seconds",
			"Average "
			+ frame.fps
			+ " FPS | p95 "
			+ frame.p95
			+ " ms | p99 "
			+ frame.p99
			+ " ms",
			"Worst frame "
			+ (frame.worst > 0 ? FrameWindow.round(1000 / frame.worst) : 0)
			+ " FPS equivalent | "
			+ frame.stalls
			+ " frames at 20 FPS pacing or worse",
			"Excluded " + report.excluded + " unfocused, suspended or profiler-heavy intervals.",
			"Profiler: peak scan "
			+ report.maxScanMs
			+ " ms; adapter errors "
			+ report.errors
			+ ".",
			report.logFailed ? "WARNING: the detailed log could not be fully written." : "Saved: benchmark.jsonl, report.json and report.txt",
			"",
			"BIGGEST OBSERVED DROPS"
		];
		if (report.process != null) {
			var resources:Array<String> = [];
			if (report.process.cpu != null && report.process.cpu.samples > 0)
				resources.push("CPU " + gauge(report.process.cpu, "%"));
			if (report.process.gpu != null && report.process.gpu.samples > 0)
				resources.push("GPU " + gauge(report.process.gpu, "%"));
			if (report.process.ram != null && report.process.ram.samples > 0)
				resources.push("RAM " + gauge(report.process.ram, " MB"));
			if (resources.length > 0)
				lines.insert(5, resources.join(" | "));
			lines.insert(6, "Heartbeat " + gauge(report.ping, " ms") + " | Draw calls " + gauge(report.draws, ""));
		}
		if (report.excludedGaps != null && report.excludedGaps.length > 0) {
			var gap:Dynamic = report.excludedGaps[0];
			lines.insert(7, "Largest excluded interval: " + gap.ms + " ms (" + gap.reason + "). Not assigned to animations.");
		}
		if (report.process != null && report.process.identity != null)
			lines.insert(5, "Process: " + report.process.identity.name + " / PID " + report.process.identity.pid);
		var worst:Array<Dynamic> = report.worst;
		if (worst.length == 0)
			lines.push(frame.stalls > 0 ? "Slow frames were measured, but this older recording has no saved hitch contexts. Animation attribution is unavailable." : "No accepted frames reached the 50 ms hitch threshold.");
		var shown = 0;
		for (spike in worst) {
			if (shown++ >= 5)
				break;
			lines.push("");
			var equivalent = FrameWindow.round(1000 / spike.ms);
			var deficit = Math.max(0, FrameWindow.round(average - equivalent));
			lines.push("At " + FrameWindow.round(spike.at / 1000) + "s: " + equivalent + " FPS equivalent (" + deficit + " below session average; "
				+ spike.ms + " ms frame).");
			if (spike.recentFps != null)
				lines.push("Measured FPS over the trailing second (or available start interval): " + spike.recentFps + ".");
			if (spike.scene != null)
				lines.push("Screen: " + spike.scene + (spike.sceneAfter != null
					&& spike.sceneAfter != spike.scene ? " -> " + spike.sceneAfter : ""));
			if (spike.contextAvailable != false && spike.contextAgeMs != null) {
				lines.push(spike.map
					+ " / floor "
					+ spike.floor
					+ "; "
					+ (spike.enemies == null ? "enemy count unavailable." : Std.string(spike.enemies) + " known enemies."));
				lines.push("Activity sampled " + spike.contextAgeMs + " ms earlier" + (spike.partial ? " (partial scan)." : "."));
			} else
				lines.push("Animation/enemy context was unavailable; the frame drop itself was still measured.");
			if (spike.mods != null) {
				lines.push("Largest observed mod spans in the preceding frame interval:");
				for (mod in (cast spike.mods : Array<Dynamic>))
					lines.push("  " + mod.name + ": " + mod.ms + " ms");
			}
			var groups:Array<Dynamic> = spike.groups;
			for (i in 0...Std.int(Math.min(3, groups.length)))
				lines.push("  " + groups[i].count + " x " + groups[i].key);
		}
		lines.push("");
		lines.push("ANIMATION / ACTOR CORRELATIONS");
		lines.push("These were present during slow frames. They are candidates to investigate, not proven causes or per-animation CPU/GPU timings.");
		var rows:Array<Dynamic> = report.associations;
		if (rows.length == 0)
			lines.push(report.errors > 0 ? "Animation ranking unavailable because adapter errors occurred." : "Not enough repeated samples to rank activity.");
		for (i in 0...Std.int(Math.min(10, rows.length))) {
			var row = rows[i];
			lines.push(row.key);
			lines.push("  " + row.meanMs + " ms average while present; " + row.aboveSessionMeanMs + " ms versus session mean; " + row.slowFrames + "/"
				+ row.frames + " slow frames; up to " + row.maxInstances + " instances.");
		}
		lines.push("");
		if (report.mods != null) {
			lines.push("PER-MOD OBSERVED FRAME WORK");
			lines.push("ENTER_FRAME + EXIT_FRAME dispatch spans on each mod's overlay. Includes event-dispatch/probe overhead; excludes API callbacks, timers, stage listeners, network handlers and rendering elsewhere. This is wall time, not CPU time.");
			lines.push("Frame-budget share is an average time allowance used, NOT percent FPS lost. A 108 ms span is about a tenth-second delay on that occasion, not a constant cost.");
			if (report.modProfilingError != null)
				lines.push(report.modProfilingError);
			for (row in (cast report.mods : Array<Dynamic>)) {
				lines.push(row.name + " " + row.version + (row.activeAtStart ? "" : " (not active at Start)"));
				if (row.observedMeanMs == null)
					lines.push("  No observed overlay frame work; resource use unknown, not zero.");
				else
					lines.push("  "
						+ row.observedMeanMs
						+ " ms/frame observed; peak dispatch "
						+ row.peakDispatchMs
						+ " ms; "
						+ (row.frameBudgetPercent == null ? "unknown" : Std.string(row.frameBudgetPercent) + "%")
						+ " of configured frame budget.");
				if (report.modPeaks != null)
					for (peak in (cast report.modPeaks : Array<Dynamic>))
						if (peak.name == row.name)
							lines.push("  Busiest observed interval: " + peak.ms + " ms of mod spans at " + FrameWindow.round(peak.at / 1000) + "s; "
								+ peak.fps + " FPS equivalent for that frame, " + peak.scene + ", " + peak.map + " / floor " + peak.floor + ".");
				if (report.modPeaks != null)
					for (peak in (cast report.modPeaks : Array<Dynamic>))
						if (peak.name == row.name && peak.recentFps != null)
							lines.push("  Measured FPS around that peak (trailing second): " + peak.recentFps + ".");
				if (row.incompleteDispatches > 0)
					lines.push("  " + row.incompleteDispatches + " incomplete dispatches; timings may omit work.");
			}
			lines.push("");
		}
		lines.push("Timing alignment: mod spans are collected between Benchmark frame callbacks; event ordering can place work near an interval boundary. These are coincident observations, not proof of FPS caused or recoverable by disabling a mod.\nLIMITS: no GPU fence timing, function profiler or per-animation memory ownership. Actor and symbol rows overlap. Shared atlas dimensions are not per-animation RAM. Other mods, loading, GC and OS scheduling can cause the same drops.");
		lines.push("Unavailable process metrics are hidden. Native heartbeat latency may include local scheduling delays.");
		lines.push("Frame percentiles cover the entire recording with 1 ms histogram resolution.");
		if (report.adapterFaults != null)
			for (fault in (cast report.adapterFaults : Array<Dynamic>))
				lines.push("Adapter " + fault.stage + ": " + fault.message + " (" + fault.count + " failures)");
		return Interpretation.describe(report) + "\n\nTECHNICAL DETAILS\n" + lines.join("\n");
	}
}
