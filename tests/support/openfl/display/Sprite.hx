package openfl.display;

class Sprite extends DisplayObjectContainer {
	public var mouseEnabled = true;
	public var mouseChildren = true;
	public var buttonMode = false;
	public var graphics = new Graphics();

	public function new() {
		super();
	}
}
