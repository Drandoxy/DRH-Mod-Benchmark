package mods.benchmark;

/** Four actors share one clock face, equally spaced, with tangent-facing movement. */
class HeroMotion {
	public static function pose(seconds:Float, index:Int = 0):Dynamic {
		var t = seconds % 4;
		var x = index % 2 == 0 ? -95.0 : 95.0;
		var y = index < 2 ? -75.0 : 75.0;
		var angle = Math.PI / 2;
		var mode = "idle";
		if (t >= 0.5 && t < 0.75) {
			mode = "run";
			y -= 90 * (t - 0.5) * 4;
			angle = -Math.PI / 2;
		} else if (t >= 0.75 && t < 1) {
			mode = "run";
			y += -90 + 90 * (t - 0.75) * 4;
		} else if (t >= 1 && t < 1.25) {
			mode = "run";
			x += 140 * (t - 1) * 4;
			angle = 0;
		} else if (t >= 1.25 && t < 1.5) {
			mode = "run";
			x += 140 - 140 * (t - 1.25) * 4;
			angle = Math.PI;
		} else if (t >= 1.5 && t < 3) {
			mode = "run";
			var phase = (t - 1.5) * Math.PI * 2 / 1.5 + [-3.0, -1.0, 3.0, 1.0][index % 4] * Math.PI / 4;
			x = Math.cos(phase) * 145;
			y = Math.sin(phase) * 110;
			angle = Math.atan2(Math.cos(phase) * 110, -Math.sin(phase) * 145);
		} else if (t >= 3) {
			mode = "run";
			var phase = (t - 3) * Math.PI * 2;
			x += Math.sin(phase) * 70;
			y += Math.sin(phase * 2) * 35;
			angle = Math.atan2(Math.cos(phase * 2) * 70, Math.cos(phase) * 70);
		}
		var heading = angle * 180 / Math.PI;
		var flip = heading > 90 || heading < -90;
		if (heading > 90)
			heading = 180 - heading;
		else if (heading < -90)
			heading = -heading - 180;
		var suffix = heading >= 60 ? "E" : heading >= 30 ? "D" : heading >= -30 ? "C" : heading >= -60 ? "B" : "A";
		return {
			x: x,
			y: y,
			label: mode + "_ang" + suffix,
			flip: flip
		};
	}
}
