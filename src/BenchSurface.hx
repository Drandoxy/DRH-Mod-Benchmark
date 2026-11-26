package mods.benchmark;

import starling.rendering.Painter;

/** Counts actual native render traversal, rather than merely counting update callbacks. */
class BenchSurface extends starling.display.Sprite {
	public var draws(default, null) = 0;
	public var failure(default, null):Null<String>;

	public function new() {
		super();
	}

	override public function render(painter:Painter):Void {
		if (failure != null)
			return;
		try {
			super.render(painter);
			draws++;
		} catch (error:Dynamic) {
			failure = "Animation rendering failed: " + Std.string(error);
			Faults.report("benchmark rendering", error);
		}
	}
}
