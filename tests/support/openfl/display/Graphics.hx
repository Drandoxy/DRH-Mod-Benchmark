package openfl.display;

class Graphics {
	public function new() {}

	public function moveTo(x:Float, y:Float):Void {}

	public function lineTo(x:Float, y:Float):Void {}

	public function clear():Void {}

	public function lineStyle(w:Float, c:Int, a:Float = 1):Void {}

	public function beginFill(c:Int, a:Float = 1):Void {}

	public function endFill():Void {}

	public function drawCircle(x:Float, y:Float, r:Float):Void {}

	public function drawRect(x:Float, y:Float, w:Float, h:Float):Void {}

	public function drawRoundRect(x:Float, y:Float, w:Float, h:Float, rx:Float, ry:Float):Void {}
}
