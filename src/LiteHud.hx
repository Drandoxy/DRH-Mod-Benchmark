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
	static inline final BASE_W = 294.0;
	static inline final PANEL_H = 52.0;
	/** Left and right inner margin, gap between readings, gap between icon, name and value. */
	static inline final MARGIN = 14.0;
	static inline final GAP = 22.0;
	static inline final INNER = 7.0;

	var fpsText:TextField;
	var pingText:TextField;
	/** Optional CPU, GPU VRAM and RAM readings, each an icon, a name and a value, between FPS and ping. */
	var ramGroup:Sprite;
	var ramText:TextField;
	var cpuGroup:Sprite;
	var cpuText:TextField;
	var vramGroup:Sprite;
	var vramText:TextField;
	var fpsGroup:Sprite;
	var pingGroup:Sprite;
	/** Each reading's value field, to size the reading by the value it shows right now. */
	var values = new haxe.ds.ObjectMap<Sprite, TextField>();
	/** The value widths used for the current layout; a change re-arranges the row. */
	var laidOut = "";
	var panelW = BASE_W;
	var grip:Sprite = null;
	var dragStage:Stage;
	var resizing = false;
	var dx = 0.0;
	var dy = 0.0;
	var savedX:Null<Float>;
	var savedY:Null<Float>;
	var size = 0.55;
	var viewW = 0.0;
	var viewH = 0.0;
	var lastW = 0.0;
	var lastH = 0.0;
	var path:String;

	public function new(path:String) {
		super();
		this.path = path;
		try {
			var saved:Dynamic = sys.FileSystem.exists(path) ? haxe.Json.parse(sys.io.File.getContent(path)) : {};
			savedX = finite(saved.x);
			savedY = finite(saved.y);
			var scale = finite(saved.size);
			if (scale != null)
				size = bound(saved.sizeVersion == 2 ? scale : scale * 0.7, 0.3, 2.5);
		} catch (error:Dynamic) {
			Faults.report("compact layout read", error);
		}
		drawPanel();
		buttonMode = true;
		fpsGroup = new Sprite();
		fpsText = group(fpsGroup, "activity", "FPS", 0x72D5B1);
		pingGroup = new Sprite();
		pingText = group(pingGroup, "network", "Ping", 0xEBC77D);
		ramGroup = new Sprite();
		ramText = group(ramGroup, "memory-stick", "RAM", 0xB9A6F2);
		cpuGroup = new Sprite();
		cpuText = group(cpuGroup, "cpu", "CPU", 0x7FC1F0);
		vramGroup = new Sprite();
		vramText = group(vramGroup, "monitor", "VRAM", 0xF0A3C0);
		addChild(fpsGroup);
		addChild(pingGroup);
		arrange(false, false, false);
		grip = new Sprite();
		addChild(grip);
		grip.x = panelW - 18;
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

	/** One reading: icon, name and value side by side. */
	function group(owner:Sprite, icon:String, name:String, color:Int):TextField {
		Icons.draw(owner, icon, 0, 17, 18);
		var title = label(owner, name, 18 + INNER, 15, 60, 0xA4B7C8);
		title.width = title.textWidth + 4;
		var value = label(owner, "--", title.x + title.width + INNER - 2, 11, 120, color, 21);
		values.set(owner, value);
		return value;
	}

	/** Re-arranges the row only when a value's width really changed (new digit count), not every update. */
	function rearrange():Void {
		var key = "";
		for (item in order())
			if (item.parent != null)
				key += Math.round(values.get(item).textWidth) + ",";
		if (key == laidOut)
			return;
		arrange(ramGroup.parent != null, cpuGroup.parent != null, vramGroup.parent != null);
		viewW = -1;
		layout(lastW, lastH);
	}

	/** Left to right: FPS, CPU, GPU VRAM, RAM, Ping. */
	function order():Array<Sprite> {
		return [fpsGroup, cpuGroup, vramGroup, ramGroup, pingGroup];
	}

	/** Lays the shown readings out left to right with even gaps; the panel is as wide as they need. */
	function arrange(showRam:Bool, showCpu:Bool, showVram:Bool):Void {
		var at = MARGIN;
		laidOut = "";
		var items = order();
		var shownList = [true, showCpu, showVram, showRam, true];
		for (i in 0...items.length) {
			var item = items[i];
			var shown = shownList[i];
			if (!shown) {
				if (item.parent != null)
					removeChild(item);
				continue;
			}
			item.x = at;
			if (item.parent == null)
				addChild(item);
			var value = values.get(item);
			value.width = value.textWidth + 6;
			laidOut += Math.round(value.textWidth) + ",";
			at += value.x + value.textWidth + GAP;
		}
		// The grip sits in the bottom-right corner, under the last value, so it needs no extra room.
		panelW = Math.max(at - GAP + MARGIN + 4, 120);
		drawPanel();
		if (grip != null) {
			grip.x = panelW - 18;
			// Re-adding moves the resize grip back on top of the readings.
			addChild(grip);
		}
	}

	function label(owner:Sprite, value:String, px:Float, py:Float, width:Float, color:Int, font:Int = 14):TextField {
		var t = new TextField();
		t.defaultTextFormat = new TextFormat("_sans", font, color);
		t.text = value;
		t.x = px;
		t.y = py;
		t.width = width;
		t.height = 30;
		t.selectable = false;
		t.mouseEnabled = false;
		owner.addChild(t);
		return t;
	}

	function drawPanel():Void {
		graphics.clear();
		graphics.beginFill(0x182430, 0.95);
		graphics.lineStyle(1, 0x3D5264);
		graphics.drawRoundRect(0, 0, panelW, PANEL_H, 12, 12);
		graphics.endFill();
	}

	public function update(fps:Float, ping:Dynamic):Void {
		var f = fps > 0 ? Std.string(Math.round(fps)) : "--";
		var p = ping != null && ping > 0 ? Std.string(Math.round(ping)) + " ms" : "--";
		if (fpsText.text != f)
			fpsText.text = f;
		if (pingText.text != p)
			pingText.text = p;
		rearrange();
	}

	/** CPU, GPU VRAM and RAM values between FPS and ping; null hides that reading. The panel widens to fit them. */
	public function setStats(ram:Null<String>, cpu:Null<String>, vram:Null<String>):Void {
		if (ram != null && ramText.text != ram)
			ramText.text = ram;
		if (cpu != null && cpuText.text != cpu)
			cpuText.text = cpu;
		if (vram != null && vramText.text != vram)
			vramText.text = vram;
		var showRam = ram != null;
		var showCpu = cpu != null;
		var showVram = vram != null;
		if (showRam == (ramGroup.parent != null) && showCpu == (cpuGroup.parent != null)
			&& showVram == (vramGroup.parent != null)) {
			rearrange();
			return;
		}
		arrange(showRam, showCpu, showVram);
		viewW = -1;
		layout(lastW, lastH);
	}

	public function layout(w:Float, h:Float):Void {
		lastW = w;
		lastH = h;
		if (w == viewW && h == viewH && dragStage == null)
			return;
		viewW = w;
		viewH = h;
		scaleX = scaleY = Math.min(size, Math.max(0.2, Math.min(w / panelW, h / PANEL_H)));
		x = bound(savedX == null ? (w - panelW * scaleX) / 2 : savedX, 0, w - panelW * scaleX);
		y = bound(savedY == null ? 12 : savedY, 0, h - PANEL_H * scaleY);
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
			size = bound(Math.max((at.x - x) / panelW, (at.y - y) / PANEL_H), 0.3, 2.5);
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
		catch (error:Dynamic) {
			Faults.report("compact layout save", error);
		}
	}

	public function dispose():Void {
		end(null);
	}

	static function finite(v:Dynamic):Null<Float>
		return v != null && Std.isOfType(v, Float) && Math.isFinite(v) ? v : null;

	static function bound(v:Float, lo:Float, hi:Float):Float
		return Math.max(lo, Math.min(Math.max(lo, hi), v));
}
