package openfl.events;

class MouseEvent extends Event {
	public static var ROLL_OVER = "rollOver";
	public static var ROLL_OUT = "rollOut";
	public static var MOUSE_DOWN = "mouseDown";

	public var buttonDown = true;
	public var stageX = 0.;
	public var stageY = 0.;

	public static var MOUSE_MOVE = "mouseMove";
	public static var MOUSE_UP = "mouseUp";
	public static var CLICK = "click";

	public function new() {
		super();
	}

	public function stopPropagation() {}
}
