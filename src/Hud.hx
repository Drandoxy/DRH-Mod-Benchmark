package mods.benchmark;

import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;

/** Compact cards, independently movable results, and clipboard export. */
class Hud extends Sprite {
	static inline final PANEL_W = 330;
	static inline final RESULT_W = 560;
	static inline final RESULT_H = 570;

	var cards:Array<Sprite> = [];
	var metrics:Array<TextField> = [];
	var timer:TextField;
	var status:TextField;
	var startButton:Sprite;
	var stopButton:Sprite;
	var popup:Sprite;
	var popupHeight = 570.0;
	var scroll:TextField;
	var copyLabel:TextField;
	var content = "";
	var showDetails = false;
	var detailLabel:TextField;
	var running = false;
	var panelHeight = 210.;
	var viewW = 1280.;
	var viewH = 720.;
	var panelX:Null<Float>;
	var panelY:Null<Float>;
	var resultX:Null<Float>;
	var resultY:Null<Float>;
	var positionPath:String;
	var dragStage:Stage;
	var dragResult = false;
	var dragDX = 0.;
	var dragDY = 0.;

	public function new(onStart:Void->Void, onStop:Void->Void, onReport:Void->Void, path:String, ?onCapacity:Void->Void, ?onCapacityReport:Void->Void) {
		super();
		positionPath = path;
		loadPosition();
		var header = header(this, "Benchmark", "activity", PANEL_W);
		header.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) beginDrag(e, false));
		Icons.draw(this, "timer", 228, 16, 15);
		timer = text(this, "00:00", 249, 12, 68, 25, 14, 0xA4BCCB);
		startButton = button(this, "Start", "play", 14, 49, 70, onStart);
		stopButton = button(this, "Stop", "square", 94, 49, 70, onStop);
		button(this, "Results", "file", 174, 49, 142, onReport);
		if (onCapacity != null)
			button(this, "Start full benchmark", "activity", 14, 91, 302, onCapacity);
		if (onCapacityReport != null)
			button(this, "Last full result", "file", 14, 133, 302, onCapacityReport);
		for (i in 0...6) {
			var card = new Sprite();
			addChild(card);
			cards.push(card);
			card.graphics.beginFill(0x243544);
			card.graphics.drawRoundRect(0, 0, 146, 65, 6, 6);
			card.graphics.endFill();
			Icons.draw(card, ["activity", "cpu", "monitor", "monitor", "memory-stick", "network"][i], 12, 11, 16);
			text(card, ["FPS", "CPU", "GPU", "GPU VRAM", "RAM", "Ping"][i], 35, 8, 99, 23, 12, 0x91AABC);
			metrics.push(text(card, "--", 11, 30, 126, 29, 19, [0x72D5B1, 0x87BFFF, 0xC4A3EB, 0xF0A3C0, 0xF0AA86, 0xEBC77D][i]));
		}
		status = text(this, "Ready to record", 14, 175, 302, 23, 12, 0x94ABBB);
		update(false, 0, "N/A|N/A|N/A|N/A|N/A|N/A");
	}

	public function update(active:Bool, seconds:Int, values:String):Void {
		running = active;
		startButton.alpha = active ? 0.45 : 1;
		stopButton.alpha = active ? 1 : 0.45;
		timer.text = StringTools.lpad(Std.string(Std.int(seconds / 60)), "0", 2) + ":" + StringTools.lpad(Std.string(seconds % 60), "0", 2);
		if (values.indexOf("Stopped.") == 0) {
			status.text = "Saved locally - open Results to review";
			return;
		}
		var cells = values.split("|");
		var count = 0;
		for (i in 0...cards.length) {
			var value = i < cells.length ? cells[i] : "N/A";
			var available = value != "N/A" && value != "";
			// FPS (first) and Ping (last) always show; the others only when they have a value.
			cards[i].visible = (i == 0 || i == cards.length - 1 || available);
			metrics[i].text = available ? value : "--";
			if (cards[i].visible) {
				cards[i].x = 14 + (count % 2) * 156;
				cards[i].y = 181 + Std.int(count / 2) * 75;
				count++;
			}
		}
		var rows = Std.int(Math.ceil(count / 2));
		status.y = 181 + rows * 75;
		status.text = active ? "Recording locally" : "Ready - Start a recording or open Results";
		if (values.indexOf("Stopped.") == 0)
			status.text = "Saved locally - open Results to review";
		panelHeight = status.y + 34;
		graphics.clear();
		graphics.beginFill(0x182430, 0.98);
		graphics.lineStyle(1, 0x354B5B);
		graphics.drawRoundRect(0, 0, PANEL_W, panelHeight, 8, 8);
		graphics.endFill();
	}

	public function setStatus(value:String):Void {
		status.text = value;
	}

	public function layout(width:Float, height:Float):Void {
		viewW = width;
		viewH = height;
		scaleX = scaleY = Math.min(1, Math.max(0.2, Math.min((width - 16) / PANEL_W, (height - 16) / panelHeight)));
		x = clamp(panelX == null ? (width - PANEL_W * scaleX) / 2 : panelX, 8, width - PANEL_W * scaleX - 8);
		y = clamp(panelY == null ? Math.min(105, height * 0.085) : panelY, 8, height - panelHeight * scaleY - 8);
		if (popup != null) {
			var size = Math.min(1, Math.min((width - 16) / RESULT_W, (height - 16) / popupHeight));
			popup.scaleX = popup.scaleY = size / scaleX;
			var px = clamp(resultX == null ? (width - RESULT_W * size) / 2 : resultX, 8, width - RESULT_W * size - 8);
			var py = clamp(resultY == null ? (height - popupHeight * size) / 2 : resultY, 8, height - popupHeight * size - 8);
			popup.x = (px - x) / scaleX;
			popup.y = (py - y) / scaleY;
		}
	}

	public function report(value:String):Void {
		closeReport();
		popupHeight = RESULT_H;
		content = value;
		popup = new Sprite();
		addChild(popup);
		popup.graphics.beginFill(0x182430, 1);
		popup.graphics.lineStyle(1, 0x3E5669);
		popup.graphics.drawRoundRect(0, 0, RESULT_W, RESULT_H, 8, 8);
		popup.graphics.endFill();
		var bar = header(popup, "Benchmark results", "file", RESULT_W);
		bar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) beginDrag(e, true));
		var copy = button(popup, "Copy", "copy", 390, 5, 112, copyResults);
		copyLabel = cast copy.getChildAt(copy.numChildren - 1);
		button(popup, "", "x", 510, 5, 36, closeReport);
		var guide = text(popup,
			"How to read: higher FPS is better; lower frame time and ping are better. P95/P99 reveal stutters. Animation matches are clues, not proven causes.",
			16, 60, 528, 56, 12, 0xA5BDCD);
		guide.multiline = true;
		guide.wordWrap = true;
		showDetails = false;
		var detailButton = button(popup, "Details", "file", 16, 94, 110, toggleDetails);
		detailLabel = cast detailButton.getChildAt(detailButton.numChildren - 1);
		text(popup, "Green: overview   Amber: slow frames   Blue: sections", 140, 101, 402, 22, 11, 0xA5BDCD);
		scroll = text(popup, "", 16, 142, 528, 384, 14, 0xD2DEE8);
		scroll.multiline = true;
		ReportMarkup.apply(scroll, content, false);
		scroll.wordWrap = true;
		scroll.multiline = true;
		scroll.selectable = true;
		scroll.mouseEnabled = true;
		scroll.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent) {
			scroll.scrollV -= e.delta;
			e.stopPropagation();
		});
		text(popup, "Drag the title to move. Scroll to read. Copy exports the full report.", 16, 542, 528, 21, 11, 0x90A8B9);
		layout(viewW, viewH);
	}

	public function confirmCapacity(onConfirm:Void->Void):Void {
		closeReport();
		popupHeight = 290;
		popup = new Sprite();
		addChild(popup);
		popup.graphics.beginFill(0x182430, 1);
		popup.graphics.lineStyle(1, 0x3E5669);
		popup.graphics.drawRoundRect(0, 0, RESULT_W, popupHeight, 8, 8);
		popup.graphics.endFill();
		var bar = header(popup, "Start full benchmark?", "activity", RESULT_W);
		bar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) beginDrag(e, true));
		button(popup, "", "x", 510, 5, 36, closeReport);
		var warning = text(popup,
			"Heavy animation load can crash the game. Completed rounds are saved automatically. Restart the game to recover the last results.\n\nThe checkpoint records the animation being prepared or the active animation set. It cannot prove which animation caused a crash.",
			20, 62, 520, 144, 16, 0xEBC77D);
		warning.multiline = true;
		warning.wordWrap = true;
		button(popup, "Cancel", "x", 20, 230, 240, closeReport);
		button(popup, "Start benchmark", "play", 300, 230, 240, function() {
			closeReport();
			onConfirm();
		});
		layout(viewW, viewH);
	}

	function toggleDetails():Void {
		showDetails = !showDetails;
		detailLabel.text = showDetails ? "Summary" : "Details";
		ReportMarkup.apply(scroll, content, showDetails);
		scroll.scrollV = 1;
	}

	function copyResults():Void {
		try {
			openfl.system.System.setClipboard(content);
			copyLabel.text = "Copied";
		} catch (_:Dynamic) {
			copyLabel.text = "Select text";
		}
	}

	public function closeReport():Void {
		endDrag(null);
		if (popup != null && popup.parent != null)
			popup.parent.removeChild(popup);
		popup = null;
		scroll = null;
		copyLabel = null;
	}

	function beginDrag(e:MouseEvent, result:Bool):Void {
		endDrag(null);
		if (stage == null || parent == null || (result && popup == null))
			return;
		dragResult = result;
		var at = parent.globalToLocal(new Point(e.stageX, e.stageY));
		dragDX = at.x - (result ? x + popup.x * scaleX : x);
		dragDY = at.y - (result ? y + popup.y * scaleY : y);
		dragStage = stage;
		dragStage.addEventListener(MouseEvent.MOUSE_MOVE, moveDrag);
		dragStage.addEventListener(MouseEvent.MOUSE_UP, endDrag, true);
		dragStage.addEventListener(Event.DEACTIVATE, endDrag);
		dragStage.addEventListener(Event.MOUSE_LEAVE, endDrag);
		e.stopPropagation();
	}

	function moveDrag(e:MouseEvent):Void {
		if (!e.buttonDown) {
			endDrag(e);
			return;
		}
		if (parent == null)
			return;
		var at = parent.globalToLocal(new Point(e.stageX, e.stageY));
		if (dragResult) {
			resultX = at.x - dragDX;
			resultY = at.y - dragDY;
		} else {
			panelX = at.x - dragDX;
			panelY = at.y - dragDY;
		}
		layout(viewW, viewH);
	}

	function endDrag(_:Event):Void {
		if (dragStage == null)
			return;
		dragStage.removeEventListener(MouseEvent.MOUSE_MOVE, moveDrag);
		dragStage.removeEventListener(MouseEvent.MOUSE_UP, endDrag, true);
		dragStage.removeEventListener(Event.DEACTIVATE, endDrag);
		dragStage.removeEventListener(Event.MOUSE_LEAVE, endDrag);
		dragStage = null;
		try
			sys.io.File.saveContent(positionPath, haxe.Json.stringify({
				panelX: panelX,
				panelY: panelY,
				resultX: resultX,
				resultY: resultY
			}))
		catch (error:Dynamic) {
			Faults.report("panel layout save", error);
		}
	}

	function loadPosition():Void {
		try {
			if (!sys.FileSystem.exists(positionPath))
				return;
			var saved:Dynamic = haxe.Json.parse(sys.io.File.getContent(positionPath));
			panelX = coordinate(saved.panelX);
			panelY = coordinate(saved.panelY);
			resultX = coordinate(saved.resultX);
			resultY = coordinate(saved.resultY);
		} catch (error:Dynamic) {
			Faults.report("panel layout read", error);
		}
	}

	static function coordinate(v:Dynamic):Null<Float>
		return v != null && Std.isOfType(v, Float) && Math.isFinite(v) ? v : null;

	static function clamp(v:Float, low:Float, high:Float):Float
		return Math.max(low, Math.min(Math.max(low, high), v));

	public function dispose():Void {
		endDrag(null);
		closeReport();
	}

	function header(owner:Sprite, title:String, glyph:String, width:Float):Sprite {
		var bar = new Sprite();
		owner.addChild(bar);
		bar.mouseChildren = false;
		bar.buttonMode = true;
		bar.graphics.beginFill(0x223442);
		bar.graphics.drawRoundRect(1, 1, width - 2, 44, 7, 7);
		bar.graphics.endFill();
		Icons.draw(bar, glyph, 14, 13, 20);
		text(bar, title, 42, 10, width - 56, 28, 16, 0xE3EDF4);
		return bar;
	}

	function button(owner:Sprite, caption:String, glyph:String, px:Float, py:Float, w:Float, callback:Void->Void):Sprite {
		var b = new Sprite();
		owner.addChild(b);
		b.name = caption;
		b.x = px;
		b.y = py;
		b.buttonMode = true;
		b.mouseChildren = false;
		b.graphics.beginFill(0x345268);
		b.graphics.drawRoundRect(0, 0, w, 36, 6, 6);
		b.graphics.endFill();
		Icons.draw(b, glyph, caption == "" ? (w - 16) / 2 : w <= 80 ? 8 : 12, 10);
		var inset = caption == "" ? 0 : w <= 80 ? 28 : 36;
		var label = text(b, caption, inset, 7, w - inset - 8, 24, 14, 0xE2EDF4);
		var format = label.defaultTextFormat;
		format.align = "center";
		label.defaultTextFormat = format;
		b.addEventListener(MouseEvent.MOUSE_OVER, function(_) b.alpha = 0.8);
		b.addEventListener(MouseEvent.MOUSE_OUT, function(_) b.alpha = 1);
		b.addEventListener(MouseEvent.CLICK, function(_) callback());
		return b;
	}

	static function text(owner:Sprite, value:String, px:Float, py:Float, w:Float, h:Float, size:Int, color:Int):TextField {
		var field = new TextField();
		field.defaultTextFormat = new TextFormat("_sans", size, color);
		field.text = value;
		field.x = px;
		field.y = py;
		field.width = w;
		field.height = h;
		field.selectable = false;
		field.mouseEnabled = false;
		owner.addChild(field);
		return field;
	}
}
