package mods.benchmark;

import starling.rendering.Painter;

/** Counts actual native render traversal, rather than merely counting update callbacks. */
class BenchSurface extends starling.display.Sprite {
	public var draws(default, null) = 0;

	public function new() {
		super();
	}

	override public function render(painter:Painter):Void {
		super.render(painter);
		draws++;
	}
}
