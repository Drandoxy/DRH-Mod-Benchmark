package openfl.events;

class Event {
	public static var REMOVED_FROM_STAGE = "removedFromStage";
	public static var MOUSE_LEAVE = "mouseLeave";
	public static var DEACTIVATE = "deactivate";
	public static var ENTER_FRAME = "enterFrame";

	public var type:String;

	public function new(type:String = "") {
		this.type = type;
	}
}
