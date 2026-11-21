package mods.benchmark;

import starling.extensions.animate.Animation;

/** Fit visible symbol bounds, never the containing atlas page. */
class AnimationSizing {
	public static function measure(a:Animation):Dynamic {
		var left = Math.POSITIVE_INFINITY;
		var top = Math.POSITIVE_INFINITY;
		var right = Math.NEGATIVE_INFINITY;
		var bottom = Math.NEGATIVE_INFINITY;
		// Prepared once per asset, outside measured rounds. Effects may start with empty frames.
		for (_ in 0...24) {
			var b = a.getBounds(a);
			if (b.width > 0 && b.height > 0) {
				left = Math.min(left, b.x);
				top = Math.min(top, b.y);
				right = Math.max(right, b.x + b.width);
				bottom = Math.max(bottom, b.y + b.height);
			}
			a.advanceTime(1 / 30);
		}
		if (!Math.isFinite(left) || right <= left || bottom <= top)
			throw "Animation has no visible bounds";
		return {
			x: left,
			y: top,
			width: right - left,
			height: bottom - top
		};
	}

	public static function effect(a:Animation, reference:Dynamic, nativeScale:Float):Float {
		a.pivotX = reference.x + reference.width / 2;
		a.pivotY = reference.y + reference.height / 2;
		var scale = (145.0 / 170.0) * nativeScale;
		a.scaleX = a.scaleY = scale;
		return scale;
	}

	public static function fitHeight(a:Animation, pixels:Float, reference:Dynamic):Float {
		if (reference == null || reference.height <= 0)
			throw "Missing hero height reference";
		a.pivotX = reference.x + reference.width / 2;
		a.pivotY = reference.y + reference.height;
		var scale = pixels / reference.height;
		a.scaleX = a.scaleY = scale;
		return scale;
	}

	public static function fit(a:Animation, pixels:Float, ?reference:Dynamic):Float {
		var bounds:Dynamic = reference == null ? a.getBounds(a) : reference;
		var extent = Math.max(bounds.width, bounds.height);
		if (!Math.isFinite(extent) || extent <= 0)
			throw "Animation has no visible bounds";
		a.pivotX = bounds.x + bounds.width / 2;
		a.pivotY = bounds.y + bounds.height / 2;
		var scale = pixels / extent;
		a.scaleX = a.scaleY = scale;
		return scale;
	}
}
