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
	/** The results window's size: tall enough for every scene's FPS at once; the bottom-right corner resizes it. */
	static inline final MIN_RESULT_W = 380;
	static inline final MIN_RESULT_H = 240;

	var cards:Array<Sprite> = [];
	var metrics:Array<TextField> = [];
	var titles:Array<TextField> = [];
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
	var resultW = 600.;
	var resultH = 860.;
	var resizing = false;
	var resizeStartX = 0.;
	var resizeStartY = 0.;
	var resizeW = 0.;
	var resizeH = 0.;
	var scrollLine = 1;
	/** The panel's size chosen with its corner grip (1 = normal); it is still shrunk to fit a small window. */
	var panelSize = 1.0;
	var panelGrip:Sprite;
	var panelResizing = false;
	/** Called with the new spot after the player moves the panel, so the compact display opens at the same place. */
	public var onMoved:Float->Float->Void;

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
			titles.push(text(card, ["FPS", "CPU", "GPU", "Textures (VRAM)", "Heap (RAM)", "Ping"][i], 35, 8, 108, 23, 12, 0x91AABC));
			metrics.push(text(card, "--", 11, 30, 126, 29, 19, [0x72D5B1, 0x87BFFF, 0xC4A3EB, 0xF0A3C0, 0xF0AA86, 0xEBC77D][i]));
		}
		status = text(this, "Ready to record", 14, 175, 302, 23, 12, 0x94ABBB);
		panelGrip = new Sprite();
		panelGrip.buttonMode = true;
		panelGrip.graphics.beginFill(0x000000, 0);
		panelGrip.graphics.drawRect(0, 0, 22, 22);
		panelGrip.graphics.endFill();
		panelGrip.graphics.lineStyle(2, 0x6E8BA0);
		for (k in 0...3) {
			panelGrip.graphics.moveTo(20, 6 + k * 5);
			panelGrip.graphics.lineTo(6 + k * 5, 20);
		}
		panelGrip.addEventListener(MouseEvent.MOUSE_DOWN, beginPanelResize);
		update(false, 0, "N/A|N/A|N/A|N/A|N/A|N/A");
	}

	/** The memory card's name: the process sampler's figure is the whole process, the in-game one the Haxe heap. */
	public function setMemoryTitle(processSampler:Bool):Void {
		if (titles.length > 4)
			titles[4].text = processSampler ? "Process RAM" : "Heap (RAM)";
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
		if (panelGrip != null) {
			panelGrip.x = PANEL_W - 22;
			panelGrip.y = panelHeight - 22;
			// Above the cards, but under an open popup.
			addChild(panelGrip);
			if (popup != null && popup.parent == this)
				addChild(popup);
		}
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
		scaleX = scaleY = Math.min(panelSize, Math.max(0.2, Math.min((width - 16) / PANEL_W, (height - 16) / panelHeight)));
		x = clamp(panelX == null ? (width - PANEL_W * scaleX) / 2 : panelX, 8, width - PANEL_W * scaleX - 8);
		y = clamp(panelY == null ? Math.min(105, height * 0.085) : panelY, 8, height - panelHeight * scaleY - 8);
		if (popup != null) {
			var popupW = popupWidth();
			var size = Math.min(1, Math.min((width - 16) / popupW, (height - 16) / popupHeight));
			popup.scaleX = popup.scaleY = size / scaleX;
			var px = clamp(resultX == null ? (width - popupW * size) / 2 : resultX, 8, width - popupW * size - 8);
			var py = clamp(resultY == null ? (height - popupHeight * size) / 2 : resultY, 8, height - popupHeight * size - 8);
			popup.x = (px - x) / scaleX;
			popup.y = (py - y) / scaleY;
		}
	}

	public function report(value:String):Void {
		var keepDetails = popup != null && content == value ? showDetails : false;
		closeReport();
		content = value;
		showDetails = keepDetails;
		buildReport();
	}

	/** The open window's width: the results window can be resized, the other popups keep the fixed width. */
	function popupWidth():Float {
		return scroll != null ? resultW : RESULT_W;
	}

	function buildReport():Void {
		popupHeight = resultH;
		popup = new Sprite();
		addChild(popup);
		popup.graphics.beginFill(0x182430, 1);
		popup.graphics.lineStyle(1, 0x3E5669);
		popup.graphics.drawRoundRect(0, 0, resultW, resultH, 8, 8);
		popup.graphics.endFill();
		var bar = header(popup, "Benchmark results", "file", resultW);
		bar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) beginDrag(e, true));
		var copy = button(popup, "Copy", "copy", resultW - 170, 5, 112, copyResults);
		copyLabel = cast copy.getChildAt(copy.numChildren - 1);
		button(popup, "", "x", resultW - 50, 5, 36, closeReport);
		var detailButton = button(popup, showDetails ? "Summary" : "Details", "file", 16, 54, 110, toggleDetails);
		detailLabel = cast detailButton.getChildAt(detailButton.numChildren - 1);
		text(popup, "Higher FPS is better. Green: smooth  Amber: moderate  Red: heavy", 136, 62, resultW - 152, 22, 11, 0xA5BDCD);
		scroll = text(popup, "", 16, 98, resultW - 32, resultH - 128, 14, 0xD2DEE8);
		scroll.multiline = true;
		ReportMarkup.apply(scroll, content, showDetails);
		scroll.wordWrap = true;
		scroll.multiline = true;
		scroll.selectable = true;
		scroll.mouseEnabled = true;
		scroll.scrollV = scrollLine;
		scroll.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent) {
			scroll.scrollV -= e.delta;
			scrollLine = scroll.scrollV;
			e.stopPropagation();
		});
		text(popup, "Drag the title to move, the corner to resize. Copy exports the full report.", 16, resultH - 26, resultW - 60, 21, 11, 0x90A8B9);
		// Resize grip: three diagonal lines in the bottom-right corner.
		var grip = new Sprite();
		popup.addChild(grip);
		grip.x = resultW - 22;
		grip.y = resultH - 22;
		grip.buttonMode = true;
		grip.graphics.beginFill(0x000000, 0);
		grip.graphics.drawRect(0, 0, 22, 22);
		grip.graphics.endFill();
		grip.graphics.lineStyle(2, 0x6E8BA0);
		for (k in 0...3) {
			grip.graphics.moveTo(20, 6 + k * 5);
			grip.graphics.lineTo(6 + k * 5, 20);
		}
		grip.addEventListener(MouseEvent.MOUSE_DOWN, beginResize);
		layout(viewW, viewH);
	}

	/** The panel's own corner grip: drag to make the whole panel bigger or smaller. */
	function beginPanelResize(e:MouseEvent):Void {
		endDrag(null);
		if (stage == null || parent == null)
			return;
		panelResizing = true;
		dragStage = stage;
		dragStage.addEventListener(MouseEvent.MOUSE_MOVE, movePanelResize);
		dragStage.addEventListener(MouseEvent.MOUSE_UP, endDrag, true);
		dragStage.addEventListener(Event.DEACTIVATE, endDrag);
		dragStage.addEventListener(Event.MOUSE_LEAVE, endDrag);
		e.stopPropagation();
	}

	function movePanelResize(e:MouseEvent):Void {
		if (!e.buttonDown || parent == null) {
			endDrag(e);
			return;
		}
		var at = parent.globalToLocal(new Point(e.stageX, e.stageY));
		panelSize = clamp(Math.max((at.x - x) / PANEL_W, (at.y - y) / panelHeight), 0.4, 2.5);
		layout(viewW, viewH);
	}

	function beginResize(e:MouseEvent):Void {
		endDrag(null);
		if (stage == null)
			return;
		resizing = true;
		resizeStartX = e.stageX;
		resizeStartY = e.stageY;
		resizeW = resultW;
		resizeH = resultH;
		dragStage = stage;
		dragStage.addEventListener(MouseEvent.MOUSE_MOVE, moveResize);
		dragStage.addEventListener(MouseEvent.MOUSE_UP, endDrag, true);
		dragStage.addEventListener(Event.DEACTIVATE, endDrag);
		dragStage.addEventListener(Event.MOUSE_LEAVE, endDrag);
		e.stopPropagation();
	}

	function moveResize(e:MouseEvent):Void {
		if (!e.buttonDown || popup == null) {
			endDrag(e);
			return;
		}
		// Mouse movement in screen pixels, turned into the window's own units (it may be scaled to fit).
		var scale = popup.scaleX * scaleX;
		if (scale <= 0)
			scale = 1;
		var w = Math.round(Math.max(MIN_RESULT_W, Math.min(1600, resizeW + (e.stageX - resizeStartX) / scale)));
		var h = Math.round(Math.max(MIN_RESULT_H, Math.min(1400, resizeH + (e.stageY - resizeStartY) / scale)));
		if (w == resultW && h == resultH)
			return;
		resultW = w;
		resultH = h;
		if (scroll != null)
			scrollLine = scroll.scrollV;
		var keepX = resultX;
		var keepY = resultY;
		if (popup.parent != null)
			popup.parent.removeChild(popup);
		popup = null;
		scroll = null;
		buildReport();
		resultX = keepX;
		resultY = keepY;
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
		scrollLine = 1;
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
		scrollLine = 1;
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
		dragStage.removeEventListener(MouseEvent.MOUSE_MOVE, moveResize);
		dragStage.removeEventListener(MouseEvent.MOUSE_MOVE, movePanelResize);
		var moved = !dragResult && !resizing && !panelResizing;
		resizing = false;
		panelResizing = false;
		dragStage.removeEventListener(MouseEvent.MOUSE_UP, endDrag, true);
		dragStage.removeEventListener(Event.DEACTIVATE, endDrag);
		dragStage.removeEventListener(Event.MOUSE_LEAVE, endDrag);
		dragStage = null;
		save();
		if (moved && onMoved != null && panelX != null && panelY != null)
			onMoved(panelX, panelY);
	}

	/** Puts the panel's top-left corner at this spot (the compact display was moved there) and saves it. */
	public function moveTo(px:Float, py:Float):Void {
		panelX = px;
		panelY = py;
		save();
		layout(viewW, viewH);
	}

	function save():Void {
		try
			sys.io.File.saveContent(positionPath, haxe.Json.stringify({
				panelX: panelX,
				panelY: panelY,
				panelSize: panelSize,
				resultX: resultX,
				resultY: resultY,
				resultW: resultW,
				resultH: resultH
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
			var size = coordinate(saved.panelSize);
			if (size != null)
				panelSize = clamp(size, 0.4, 2.5);
			resultX = coordinate(saved.resultX);
			resultY = coordinate(saved.resultY);
			var w = coordinate(saved.resultW);
			var h = coordinate(saved.resultH);
			if (w != null)
				resultW = Math.max(MIN_RESULT_W, Math.min(1600, w));
			if (h != null)
				resultH = Math.max(MIN_RESULT_H, Math.min(1400, h));
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
