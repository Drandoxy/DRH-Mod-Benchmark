package openfl.geom;

class Point {
	public function clone():Point {
		return new Point(x, y);
	}

	public var x:Float;
	public var y:Float;

	public function new(x = 0., y = 0.) {
		this.x = x;
		this.y = y;
	}

	public static function distance(a:Point, b:Point):Float {
		var x = a.x - b.x;
		var y = a.y - b.y;
		return Math.sqrt(x * x + y * y);
	}
}
