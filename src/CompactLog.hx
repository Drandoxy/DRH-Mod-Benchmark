package mods.benchmark;

import sys.io.File;
import sys.FileSystem;

/** Three 1 MiB JSONL chunks maximum; dictionaries repeat after rollover. */
class CompactLog {
	public var failed(default, null) = false;
	public var session(default, null):String;
	public var sequence(default, null) = 0;
	public var bytes(default, null) = 0;

	var path:String;
	var definitions:Array<String> = [];
	var definitionIds:Array<Int> = [];
	var nextId = 1;
	var count = 0;
	var pending = new StringBuf();
	var pendingBytes = 0;

	public function new(folder:String) {
		path = folder + "/benchmark.jsonl";
		session = Std.string(Date.now().getTime()) + "-" + Std.random(1000000);
		rotate();
		write({
			type: "session",
			schema: 1,
			session: session,
			version: "0.1.23",
			startedLocal: Date.now().toString(),
			utcMs: Date.now().getTime(),
			attribution: "correlation only; frame intervals are not per-animation CPU/GPU time",
			units: {
				frame: "ms",
				ram: "MiB",
				cpu: "percent of total logical CPU capacity",
				gpu: "busiest per-process GPU engine percent"
			}
		});
		flush();
	}

	function rotate():Void {
		flush();
		try {
			if (FileSystem.exists(path + ".2"))
				FileSystem.deleteFile(path + ".2");
			if (FileSystem.exists(path + ".1"))
				FileSystem.rename(path + ".1", path + ".2");
			if (FileSystem.exists(path))
				FileSystem.rename(path, path + ".1");
			File.saveContent(path, "");
			bytes = 0;
			sequence++;
			definitions = [];
			definitionIds = [];
			nextId = 1;
			count = 0;
		} catch (_:Dynamic) {
			failed = true;
		}
	}

	public function intern(key:String, ?metadata:Dynamic):Int {
		var index = KeyIndex.find(definitions, key);
		if (index >= 0)
			return definitionIds[index];
		if (count >= 2048 || failed)
			return 0;
		var id = nextId++;
		index = -index - 1;
		definitions.insert(index, key);
		definitionIds.insert(index, id);
		count++;
		write({
			type: "dictionary",
			id: id,
			key: key,
			metadata: metadata
		});
		return id;
	}

	// Reserve before interning a batch, so a rollover never invalidates its IDs.
	public function reserve():Void {
		if (bytes > 900000) {
			rotate();
			write({
				type: "continuation",
				schema: 1,
				session: session,
				sequence: sequence
			});
		}
	}

	public function write(value:Dynamic):Void {
		if (failed)
			return;
		var line = haxe.Json.stringify(value) + "\n";
		var size = haxe.io.Bytes.ofString(line).length;
		if (bytes + size > 1048576)
			return;
		pending.add(line);
		pendingBytes += size;
		bytes += size;
	}

	public function flush():Void {
		if (failed || pendingBytes == 0)
			return;
		var out:sys.io.FileOutput = null;
		try {
			out = File.append(path, false);
			out.writeString(pending.toString());
			out.close();
		} catch (_:Dynamic) {
			if (out != null)
				try
					out.close()
				catch (error:Dynamic) {
					Faults.report("log close after write failure", error);
				}
			failed = true;
		}
		pending = new StringBuf();
		pendingBytes = 0;
	}
}
