package mods.benchmark;

/**
 * Cheap in-game readings for the compact display, taken once a second when their switch is on:
 * - Heap: the Haxe heap (Gc MEM_INFO_USAGE), the memory of the game's code: about half of what the process holds
 *   (Task Manager counts the engine, graphics driver and libraries too), and it includes garbage not yet collected;
 * - CPU: the game process's CPU time since the last reading, as a share of the whole processor (all its threads),
 *   so 5% means the game used 5% of what the PC has. The thread count comes from NUMBER_OF_PROCESSORS on Windows
 *   and /proc/cpuinfo on Linux; where it is unknown the reading is the number of cores used, unclamped ("1.3 cores").
 * - Textures: the renderer's own count of the graphics memory it allocated for textures and buffers. Not the game's
 *   whole VRAM use as the driver counts it (that is often far more, and it moves with what is on screen).
 * The GPU load in percent cannot be read from inside the game, so it is not offered.
 */
class SystemStats {
	static inline final MB = 1048576.0;

	var threads:Int;
	var lastCpu = -1.0;
	var lastWall = -1.0;

	public function new() {
		threads = countThreads();
	}

	/** Hardware threads of the PC, 0 when unknown. */
	static function countThreads():Int {
		var n = Std.parseInt(Sys.getEnv("NUMBER_OF_PROCESSORS"));
		if (n != null && n > 0)
			return n;
		try {
			if (sys.FileSystem.exists("/proc/cpuinfo")) {
				var count = 0;
				for (line in sys.io.File.getContent("/proc/cpuinfo").split("\n"))
					if (StringTools.startsWith(line, "processor"))
						count++;
				if (count > 0)
					return count;
			}
		} catch (error:Dynamic) {
			// Unreadable: the CPU reading falls back to cores used.
			Faults.report("thread count read", error);
		}
		return 0;
	}

	public function ram():String {
		#if cpp
		return Math.round(cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE) / MB) + " MB";
		#else
		return "--";
		#end
	}

	public function cpu():String {
		var now = haxe.Timer.stamp();
		var time = Sys.cpuTime();
		var text = "--";
		if (lastWall >= 0 && now > lastWall) {
			var cores = Math.max(0, (time - lastCpu) / (now - lastWall));
			if (threads > 0)
				text = Math.round(Math.min(100, cores / threads * 100)) + "%";
			else
				text = (Math.round(cores * 10) / 10) + (cores >= 0.95 && cores < 1.05 ? " core" : " cores");
		}
		lastCpu = time;
		lastWall = now;
		return text;
	}

	/** Texture and buffer memory the renderer allocated, by its own count; "--" before the renderer exists. */
	public function vram(painter:starling.rendering.Painter):String {
		var context:openfl.display3D.Context3D = painter == null ? null : painter.context;
		if (context == null)
			return "--";
		// The renderer counts bytes in a 32-bit Int: above 2 GB it wraps to a negative number.
		var bytes:Float = context.totalGPUMemory;
		if (bytes < 0)
			bytes += 4294967296.0;
		return Math.round(bytes / MB) + " MB";
	}

	/** After the CPU reading was switched off, the next one starts a fresh interval. */
	public function resetCpu():Void {
		lastWall = -1;
	}
}
