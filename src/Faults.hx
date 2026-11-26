package mods.benchmark;

/** Bounded, visible diagnostics: one log line per operation, with repeat counts in reports. */
class Faults {
	public static var logger:String->Void;
	static var rows:Array<Dynamic> = [];

	public static function reset():Void {
		rows = [];
	}

	public static function report(operation:String, error:Dynamic):Void {
		for (row in rows)
			if (row.operation == operation) {
				row.count++;
				return;
			}
		if (rows.length >= 32)
			return;
		var message = Std.string(error).substr(0, 400);
		rows.push({operation: operation, message: message, count: 1});
		if (logger != null)
			logger("Benchmark warning: " + operation + ": " + message);
	}

	public static function snapshot():Array<Dynamic> {
		return [
			for (row in rows)
				{operation: row.operation, message: row.message, count: row.count}
		];
	}
}
