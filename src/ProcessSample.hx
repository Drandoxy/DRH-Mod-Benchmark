package mods.benchmark;

/** Optional OS sampler. Session token and freshness prevent old-process readings. */
class ProcessSample {
	public static function read(path:String, session:String, now:Float):Dynamic {
		try {
			if (!sys.FileSystem.exists(path) || sys.FileSystem.stat(path).size > 4096)
				return null;
			var value:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
			var age:Float = now - value.time;
			if (value.session != session || !Math.isFinite(age) || age < -1000 || age > 6000 || value.pid == null || value.pid <= 0)
				return null;
			return {
				pid: value.pid,
				name: clean(value.name),
				cpu: percent(value.cpu),
				gpu: percent(value.gpu),
				ram: positive(value.ram),
				ageMs: FrameWindow.round(Math.max(0, age))
			};
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function clean(s:Dynamic):String {
		var name = Std.string(s);
		return name.length > 100 ? name.substr(0, 100) : name;
	}

	static function positive(v:Dynamic):Dynamic {
		return v != null && Std.isOfType(v, Float) && Math.isFinite(v) && v >= 0 ? v : null;
	}

	static function percent(v:Dynamic):Dynamic {
		var n:Dynamic = positive(v);
		return n != null && n <= 100 ? n : null;
	}
}
