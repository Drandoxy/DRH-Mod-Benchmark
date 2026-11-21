package mods.benchmark;

/** Fixed-size aggregate for sparse optional measurements. */
class Gauge {
	var samples = 0;
	var sum = 0.;
	var peak = 0.;

	public function new() {}

	public function add(value:Dynamic):Void {
		if (value == null || !Math.isFinite(value) || value < 0)
			return;
		samples++;
		sum += value;
		peak = Math.max(peak, value);
	}

	public function report():Dynamic {
		return {samples: samples, mean: samples == 0 ? null : FrameWindow.round(sum / samples), peak: samples == 0 ? null : FrameWindow.round(peak)};
	}
}
