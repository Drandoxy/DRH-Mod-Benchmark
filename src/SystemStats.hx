package mods.benchmark;

/**
 * Cheap in-game readings for the compact display, taken once a second when their switch is on:
 * - RAM: memory the game's own code has in use;
 * - CPU: the game process's CPU time since the last reading, as a share of the whole processor (all its threads),
 *   so 5% means the game used 5% of what the PC has.
 * - GPU VRAM: graphics memory held by the game's textures and buffers (the renderer counts it as it allocates).
 * The GPU load in percent cannot be read from inside the game, so it is not offered.
 */
class SystemStats {
	static inline final MB = 1048576.0;

	var threads:Int;
	var lastCpu = -1.0;
	var lastWall = -1.0;

	public function new() {
		var n = Std.parseInt(Sys.getEnv("NUMBER_OF_PROCESSORS"));
		threads = n == null || n < 1 ? 1 : n;
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
			var share = (time - lastCpu) / (now - lastWall) / threads * 100;
			text = Math.round(Math.max(0, Math.min(100, share))) + "%";
		}
		lastCpu = time;
		lastWall = now;
		return text;
	}

	/** GPU memory in use by the game, from the renderer's own count; "--" before the renderer exists. */
	public function vram(painter:starling.rendering.Painter):String {
		var context:openfl.display3D.Context3D = painter == null ? null : painter.context;
		return context == null ? "--" : Math.round(context.totalGPUMemory / MB) + " MB";
	}

	/** After the CPU reading was switched off, the next one starts a fresh interval. */
	public function resetCpu():Void {
		lastWall = -1;
	}
}
