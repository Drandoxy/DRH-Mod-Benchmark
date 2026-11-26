package openfl.text;

class TextField extends openfl.display.DisplayObjectContainer {
	public var type:String;
	public var restrict:String;
	public var maxChars:Int;
	public var wordWrap = false;
	public var multiline = false;
	public var textColor:Int;
	public var text = "";
	public var textWidth = 40.0;
	public var defaultTextFormat:TextFormat;
	public var selectable = false;
	public var mouseEnabled = true;

	public function new() {
		super();
	}
}
