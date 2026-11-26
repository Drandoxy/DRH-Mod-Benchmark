package mods.benchmark;

import mods.api.Context;

/** API-only fallback. Never infers paths, reads enabled.json or probes other overlays. */
class ModProfiler {
	public var enabled(default, null) = false;
	public var error(default, null):String;

	public function new() {}

	public function start(ctx:Context):Void {
		enabled = false;
		error = "Per-mod timing unavailable: API 1.5 does not expose cross-mod discovery or timing. Unknown does not mean zero.";
	}

	public function drain():Array<Dynamic> {
		return [];
	}

	public function report(frameBudget:Float):Array<Dynamic> {
		return [];
	}

	public function dispose():Void {
		enabled = false;
	}
}
