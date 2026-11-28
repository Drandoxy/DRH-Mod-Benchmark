package mods.benchmark;

/** Alternating complete checkpoints preserve the preceding valid file on a failed write. */
class CapacityStore {
	var path:String;
	var sequence = 0;

	public function new(path:String) {
		this.path = path;
		var old = read();
		if (old != null)
			sequence = old.sequence;
	}

	public function save(document:Dynamic):Void {
		sequence++;
		document.sequence = sequence;
		var file = path + "/capacity-" + (sequence % 2) + ".json";
		sys.io.File.saveContent(file, haxe.Json.stringify(document));
		var verified:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
		if (verified.sequence != sequence)
			throw "Checkpoint verification failed";
	}

	public function read():Dynamic {
		var newest:Dynamic = null;
		for (i in 0...2)
			try {
				var file = path + "/capacity-" + i + ".json";
				if (!sys.FileSystem.exists(file))
					continue;
				var d:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
				if ((d.protocol == 1 || d.protocol == 2 || d.protocol == 3 || d.protocol == 4 || d.protocol == 5 || d.protocol == 6)
					&& Std.isOfType(d.sequence, Int)
					&& d.sequence >= 0
					&& Std.isOfType(d.rounds, Array)
					&& (newest == null || d.sequence > newest.sequence))
					newest = d;
			} catch (error:Dynamic) {
				Faults.report("checkpoint read", error);
			}
		return newest;
	}

	static function summary(d:Dynamic):String {
		var lines:Array<String> = [
			"YOUR ANIMATION RESULTS",
			d.status == "complete" ? "Benchmark completed" : "Status: " + d.status
		];
		if (d.seconds != null)
			lines.push("Finished in " + d.seconds + " seconds.");
		if (d.status == "running")
			lines.push("INTERRUPTED: completed stages were recovered. The last saved operation is under Details.");
		lines.push("");
		lines.push("FPS BY ANIMATION SCENE");
		var base:Dynamic = null;
		var slowest:Dynamic = null;
		var fury = false;
		for (row in (cast d.rounds : Array<Dynamic>)) {
			if (row.name.indexOf("Fury") >= 0 || row.name.indexOf("Frenzy") >= 0)
				fury = true;
			if (row.frame == null) {
				lines.push(row.name + ": " + row.status);
				continue;
			}
			if (row.count == 0)
				base = row.frame;
			// One line per scene, so every result fits on one screen; scene sizes and timings are under Details.
			var label = row.frame.fps >= 100 ? "Smooth" : row.frame.fps >= 60 ? "Moderate load" : row.frame.fps >= 30 ? "Heavy load" : "Very heavy load";
			// The drop also as a share of the baseline: the report colours it apart from the FPS label.
			var drop = base == null ? 0. : Math.max(0, base.fps - row.frame.fps);
			var share = base == null || base.fps <= 0 ? 0 : Math.round(drop / base.fps * 100);
			var below = base != null && row.count > 0 ? " | -" + FrameWindow.round(drop) + " vs baseline (-" + share + "%)" : "";
			lines.push(row.name + " - " + row.frame.fps + " FPS | " + label + below + (row.status == "complete" ? "" : " | " + row.status));
			if (row.count > 0 && row.status == "complete" && (slowest == null || row.frame.fps < slowest.frame.fps))
				slowest = row;
		}
		if (!fury)
			lines.push("Lion Fury: not tested in this saved run.");
		lines.push("");
		if (d.protocol >= 6) {
			lines.push("MATCHED EFFECT COMPARISON");
			var isolated:Array<Dynamic> = [];
			for (row in (cast d.rounds : Array<Dynamic>))
				if (row.name.indexOf("Isolated: ") == 0 && row.status == "complete" && row.frame != null && row.count == 16)
					isolated.push(row);
			isolated.sort(function(a, b) return a.frame.fps < b.frame.fps ? -1 : a.frame.fps > b.frame.fps ? 1 : 0);
			for (row in isolated)
				lines.push(row.name.substr(10) + " - " + row.frame.fps + " FPS with 16 copies");
			if (isolated.length == 6 && base != null && base.fps - isolated[0].frame.fps >= 3)
				lines.push("First candidate to simplify: " + isolated[0].name.substr(10) + " (repeat to confirm).");
			lines.push("");
		}
		if (slowest != null)
			lines.push("Heaviest scene: " + slowest.name + " at " + slowest.frame.fps + " FPS. Higher is better; Details has timings and asset names.");
		return lines.join("\n");
	}

	public static function describe(d:Dynamic):String {
		if (d == null)
			return "No controlled benchmark saved yet.";
		var lines:Array<String> = ["CONTROLLED ANIMATION BENCHMARK",
			"Status: " + d.status,
			d.seconds == null ? "" : "Total duration: " + d.seconds + " seconds",
			"Last checkpoint: " + d.stage,
			"Build "
			+ d.modVersion
			+ " | Protocol "
			+ d.protocol
			+ " | viewport "
			+ d.width
			+ " x "
			+ d.height
			+ " | "
			+ d.started,
			"Visual animation load only. No enemy AI, physics or server combat. Town UI is hidden; other mods remain active.",
			"Each measured round follows warm-up; preparation/loading are excluded and saved separately.",
			""
		];
		if (d.modVersion == null)
			lines.push("LEGACY RESULT: this run did not verify that the controlled surface was rendered. Do not use it for animation performance conclusions.");
		if (d.surfaceDraws != null)
			lines.push("Successful native surface traversals: " + d.surfaceDraws + ".");
		if (d.status == "running")
			lines.push("INTERRUPTED: the previous session did not finish cleanly. Completed rounds below are retained; the unfinished round is not a measured result.");
		if (d.operation != null) {
			var op = d.operation;
			lines.push("LAST SAVED OPERATION");
			lines.push(op.phase + (op.round == null ? "" : " / " + op.round));
			if (op.asset != null)
				lines.push(op.asset.name + " | " + op.asset.path + " | " + op.asset.symbol + " / "
					+ (op.asset.label == null ? "whole clip" : op.asset.label) + (op.instance == null ? "" : " | instance " + op.instance));
			if (op.assets != null)
				for (asset in (cast op.assets : Array<Dynamic>))
					lines.push(asset.count + " x " + asset.name + " | " + asset.symbol + " / " + (asset.label == null ? "whole clip" : asset.label));
			lines.push("This is the last durable checkpoint, not a proven crash cause. Mixed rounds identify the active set, not a single culprit.");
			lines.push("");
		}
		if (d.modEnvironment != null)
			lines.push(Std.string(d.modEnvironment));
		if (d.mods != null) {
			lines.push("Enabled-mod environment:");
			for (mod in (cast d.mods : Array<Dynamic>))
				lines.push("  " + mod.id + " " + mod.version + (mod.active ? "" : " (not active)"));
			lines.push("");
		}
		var ranked:Array<Dynamic> = [];
		for (row in (cast d.rounds : Array<Dynamic>))
			if (row.status == "complete" && row.frame != null && row.count > 0)
				ranked.push(row);
		ranked.sort(function(a, b) return a.frame.fps < b.frame.fps ? -1 : a.frame.fps > b.frame.fps ? 1 : 0);
		if (ranked.length > 0) {
			lines.push("MOST DEMANDING COMPLETED ROUNDS");
			for (i in 0...Std.int(Math.min(3, ranked.length)))
				lines.push(ranked[i].name + ": " + ranked[i].count + " animations, " + ranked[i].frame.fps + " FPS average.");
			lines.push("");
		}
		lines.push("ROUND DETAILS");
		if (d.heroes != null) {
			lines.push("FOUR-HERO MAP BASELINE");
			for (hero in (cast d.heroes : Array<Dynamic>))
				lines.push(hero.name + " | " + hero.symbol);
			lines.push("Idle facing front, up/down/right/left runs, synchronized circle and running dance repeat in every round.");
		}
		var singles:Array<Dynamic> = [];
		for (row in (cast d.rounds : Array<Dynamic>))
			if (row.count == 1 && row.frame != null && row.status == "complete")
				singles.push(row);
		singles.sort(function(a, b) return a.frame.fps < b.frame.fps ? -1 : a.frame.fps > b.frame.fps ? 1 : 0);
		if (singles.length > 0) {
			lines.push("SINGLE-EFFECT COMPARISON");
			for (row in singles)
				lines.push(row.name
					+ ": "
					+ row.frame.fps
					+ " FPS; "
					+ row.assets[0].symbol + " at " + row.assets[0].pixels + " px reference size.");
			if (singles.length > 1 && Math.abs(singles[0].frame.fps - singles[singles.length - 1].frame.fps) < 1)
				lines.push("The isolated effects are effectively tied at the measured FPS. Do not infer a meaningful winner from tiny differences near the frame cap.");
			lines.push("These compare one added effect with the same room and four heroes, not exact per-effect GPU time.");
		}
		var baseline:Dynamic = null;
		for (row in (cast d.rounds : Array<Dynamic>)) {
			lines.push(row.name + " | " + row.count + " added stress animations | " + row.status);
			if (row.frame != null) {
				if (row.count == 0)
					baseline = row.frame;
				lines.push("  " + row.frame.fps + " FPS average; p95 " + row.frame.p95 + " ms; p99 " + row.frame.p99 + " ms; worst " + row.frame.worst +
					" ms.");
				if (baseline != null && row.count > 0)
					lines.push("  Mean frame time above "
						+ (d.protocol >= 2 ? "four-hero map baseline: " : "empty baseline: ")
						+ FrameWindow.round(row.frame.ms / row.frame.frames - baseline.ms / baseline.frames)
						+ " ms. This is a controlled scene comparison, not an exact per-animation cost.");
				lines.push("  Animation advance: "
					+ row.advanceMeanMs
					+ " ms/frame average, "
					+ row.advancePeakMs
					+ " ms peak (excludes GPU rendering).");
			}
			if (row.backgroundFrames != null && row.backgroundFrames > 0)
				lines.push("  " + row.backgroundFrames + " measured frames ran unfocused; background throttling may affect comparisons.");
			if (row.renderedSurfaceFrames != null)
				lines.push("  Confirmed native surface draws: "
					+ row.renderedSurfaceFrames
					+ (row.renderedSurfaceFps == null ? "" : " / " + row.renderedSurfaceFps + " draws per second")
					+ ".");
			if (row.note != null)
				lines.push("  " + row.note);
			if (row.assets != null)
				for (asset in (cast row.assets : Array<Dynamic>))
					lines.push("  " + asset.name + ": " + asset.count + " x " + asset.symbol + " / " + asset.label + "; reference extent " + asset.pixels
						+ " px.");
			lines.push("");
		}
		lines.push("Compare the same protocol, viewport and enabled mods. Mixed crowds demonstrate capacity; single-family rounds narrow suspects. Special animation labels do not automatically spawn gameplay-driven spell particles or weapons. No exact per-animation GPU or RAM attribution.");
		return summary(d) + "\n\nTECHNICAL DETAILS\n" + lines.join("\n");
	}
}
