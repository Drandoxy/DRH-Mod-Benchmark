package openfl.display;

class Stage extends DisplayObjectContainer {
	public var frameRate = 60.;
	public var focus:Dynamic;
	public var captures:Array<Bool> = [];
	public var adds = 0;
	public var removes = 0;

	public function new() {
		super();
	}

	override public function addEventListener(n:String, f:Dynamic, c:Bool = false, p:Int = 0) {
		adds++;
		captures.push(c);
	}

	override public function removeEventListener(n:String, f:Dynamic, c:Bool = false) {
		removes++;
	}
}
