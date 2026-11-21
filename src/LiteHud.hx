package mods.benchmark;

import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** Display-only counter. No history, profiler, actor scans or recording I/O. */
class LiteHud extends Sprite {
	var fpsText:TextField;
	var pingText:TextField;
	var grip:Sprite;
	var dragStage:Stage;
	var resizing = false;
	var dx = 0.0;
	var dy = 0.0;
	var savedX:Null<Float>;
	var savedY:Null<Float>;
	var size = 0.55;
	var viewW = 0.0;
	var viewH = 0.0;
	var path:String;

	public function new(path:String) {
		super();
		this.path = path;
		try {
			var saved:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
			savedX = finite(saved.x);
			savedY = finite(saved.y);
			var scale = finite(saved.size);
			if (scale != null)
				size = bound(saved.sizeVersion == 2 ? scale : scale * 0.7, 0.3, 2.5);
		} catch (_:Dynamic) {}
		graphics.beginFill(0x182430, 0.95);
		graphics.lineStyle(1, 0x3D5264);
		graphics.drawRoundRect(0, 0, 294, 52, 12, 12);
		graphics.endFill();
		buttonMode = true;
		Icons.draw(this, "activity", 14, 17, 18);
		label("FPS", 39, 15, 32, 0xA4B7C8);
		fpsText = label("--", 75, 11, 59, 0x72D5B1, 21);
		Icons.draw(this, "network", 143, 17, 18);
		label("Ping", 167, 15, 35, 0xA4B7C8);
		pingText = label("--", 205, 11, 76, 0xEBC77D, 21);
		grip = new Sprite();
		addChild(grip);
		grip.x = 276;
		grip.y = 34;
		grip.graphics.beginFill(0x3D5264, 0.25);
		grip.graphics.drawRoundRect(0, 0, 18, 18, 5, 5);
		grip.graphics.endFill();
		grip.graphics.lineStyle(1, 0x9BB0C3);
		grip.graphics.moveTo(5, 13);
		grip.graphics.lineTo(13, 5);
		grip.graphics.moveTo(10, 13);
		grip.graphics.lineTo(13, 10);
		grip.buttonMode = true;
		grip.addEventListener(MouseEvent.MOUSE_OVER, function(_) grip.alpha = 1);
		grip.addEventListener(MouseEvent.MOUSE_OUT, function(_) grip.alpha = 0.65);
		grip.alpha = 0.65;
		grip.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) begin(e, true));
		addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) begin(e, false));
	}

	function label(value:String, px:Float, py:Float, width:Float, color:Int, font:Int = 14):TextField {
		var t = new TextField();
		t.defaultTextFormat = new TextFormat("_sans", font, color);
		t.text = value;
		t.x = px;
		t.y = py;
		t.width = width;
		t.height = 30;
		t.selectable = false;
		t.mouseEnabled = false;
		addChild(t);
		return t;
	}

	public function update(fps:Float, ping:Dynamic):Void {
		var f = fps > 0 ? Std.string(Math.round(fps)) : "--";
		var p = ping != null && ping > 0 ? Std.string(Math.round(ping)) + " ms" : "--";
		if (fpsText.text != f)
			fpsText.text = f;
		if (pingText.text != p)
			pingText.text = p;
	}

	public function layout(w:Float, h:Float):Void {
		if (w == viewW && h == viewH && dragStage == null)
			return;
		viewW = w;
		viewH = h;
		scaleX = scaleY = Math.min(size, Math.max(0.2, Math.min(w / 294, h / 52)));
		x = bound(savedX == null ? (w - 294 * scaleX) / 2 : savedX, 0, w - 294 * scaleX);
		y = bound(savedY == null ? 12 : savedY, 0, h - 52 * scaleY);
	}

	function begin(e:MouseEvent, resize:Bool):Void {
		e.stopPropagation();
		if (stage == null || parent == null)
			return;
		end(null);
		resizing = resize;
		var at = parent.globalToLocal(new Point(e.stageX, e.stageY));
		dx = at.x - x;
		dy = at.y - y;
		savedX = x;
		savedY = y;
		dragStage = stage;
		dragStage.addEventListener(MouseEvent.MOUSE_MOVE, move);
		dragStage.addEventListener(MouseEvent.MOUSE_UP, end, true);
		dragStage.addEventListener(Event.DEACTIVATE, end);
		dragStage.addEventListener(Event.MOUSE_LEAVE, end);
	}

	function move(e:MouseEvent):Void {
		if (!e.buttonDown || parent == null) {
			end(e);
			return;
		}
		var at = parent.globalToLocal(new Point(e.stageX, e.stageY));
		if (resizing)
			size = bound(Math.max((at.x - x) / 294, (at.y - y) / 52), 0.3, 2.5);
		else {
			savedX = at.x - dx;
			savedY = at.y - dy;
		}
		layout(viewW, viewH);
	}

	function end(_:Event):Void {
		if (dragStage == null)
			return;
		dragStage.removeEventListener(MouseEvent.MOUSE_MOVE, move);
		dragStage.removeEventListener(MouseEvent.MOUSE_UP, end, true);
		dragStage.removeEventListener(Event.DEACTIVATE, end);
		dragStage.removeEventListener(Event.MOUSE_LEAVE, end);
		dragStage = null;
		savedX = x;
		savedY = y;
		try
			sys.io.File.saveContent(path, haxe.Json.stringify({
				x: savedX,
				y: savedY,
				size: size,
				sizeVersion: 2
			}))
		catch (_:Dynamic) {}
	}

	public function dispose():Void {
		end(null);
	}

	static function finite(v:Dynamic):Null<Float>
		return v != null && Std.isOfType(v, Float) && Math.isFinite(v) ? v : null;

	static function bound(v:Float, lo:Float, hi:Float):Float
		return Math.max(lo, Math.min(Math.max(lo, hi), v));
}
