package mods.benchmark;

import mods.api.Context;
import openfl.display.Sprite;
import openfl.events.Event;

/** Read-only dispatch-span timing. Does not replace handlers or inspect API internals. */
class ModProfiler {
	var rows:Array<ModDispatch> = [];

	public var enabled(default, null) = false;

	public var error(default, null):String;

	public function new() {}

	public function start(ctx:Context):Void {
		dispose();
		rows = [];
		enabled = true;
		error = null;
		try {
			var mods = haxe.io.Path.normalize(ctx.data + "/../..");
			var config:Dynamic = haxe.Json.parse(sys.io.File.getContent(mods + "/enabled.json"));
			var enabled:Array<Dynamic> = config.mods;
			if (enabled == null)
				return;
			var parent = ctx.overlay.parent;
			for (entry in enabled) {
				var id:String = entry.id;
				if (id == null || !~/^[a-z][a-z0-9_]{1,62}[a-z0-9]$/.match(id))
					continue;
				if (rows.length >= 128) {
					error = "Per-mod list limited to 128 entries.";
					break;
				}
				var row = new ModDispatch(id, this);
				rows.push(row);
				row.active = ctx.isActive(id);
				try {
					var manifest:Dynamic = haxe.Json.parse(sys.io.File.getContent(mods + "/" + id + "/mod.json"));
					row.name = Std.string(manifest.name);
					row.version = Std.string(manifest.version);
				} catch (_:Dynamic) {}
				if (parent != null && row.active) {
					var layer = Std.downcast(parent.getChildByName("mod:" + id), Sprite);
					if (layer != null)
						row.attach(layer);
				}
			}
		} catch (_:Dynamic) {
			error = "Enabled mod list unavailable; per-mod readings unavailable.";
		}
	}

	public function drain():Array<Dynamic> {
		var result:Array<Dynamic> = [];
		for (row in rows) {
			if (row.intervalMs > 0)
				result.push({name: row.name, ms: preciseTime(row.intervalMs)});
			row.intervalMs = 0;
		}
		result.sort(function(a, b) return a.ms > b.ms ? -1 : a.ms < b.ms ? 1 : 0);
		return result;
	}

	static function preciseTime(v:Float):Float
		return Math.round(v * 1000) / 1000;

	public function report(frameBudget:Float):Array<Dynamic> {
		var result:Array<Dynamic> = [];
		for (row in rows)
			result.push(row.report(frameBudget));
		result.sort(function(a, b) {
			var av:Float = a.observedMeanMs == null ? -1 : a.observedMeanMs;
			var bv:Float = b.observedMeanMs == null ? -1 : b.observedMeanMs;
			return av > bv ? -1 : av < bv ? 1 : 0;
		});
		return result;
	}

	public function dispose():Void {
		enabled = false;
		for (row in rows)
			try
				row.detach()
			catch (_:Dynamic) {
				error = "One or more mod observers could not be detached; profiling is disabled.";
			}
	}
}

private class ModDispatch {
	public var id:String;
	public var name:String;
	public var version = "";
	public var active = false;

	var layer:Sprite;
	var owner:ModProfiler;
	var enterStarted = -1.0;
	var exitStarted = -1.0;
	var enterCount = 0;
	var exitCount = 0;
	var enterSum = 0.0;
	var exitSum = 0.0;
	var peak = 0.0;

	public var intervalMs = 0.0;

	var missed = 0;
	var preexistingEnter = false;
	var preexistingExit = false;

	public function new(id:String, owner:ModProfiler) {
		this.owner = owner;
		this.id = id;
		this.name = id;
	}

	public function attach(value:Sprite):Void {
		layer = value;
		preexistingEnter = layer.hasEventListener(Event.ENTER_FRAME);
		preexistingExit = layer.hasEventListener(Event.EXIT_FRAME);
		layer.addEventListener(Event.ENTER_FRAME, beforeEnter, false, 1000000);
		layer.addEventListener(Event.ENTER_FRAME, afterEnter, false, -1000000);
		layer.addEventListener(Event.EXIT_FRAME, beforeExit, false, 1000000);
		layer.addEventListener(Event.EXIT_FRAME, afterExit, false, -1000000);
	}

	function beforeEnter(_:Event):Void {
		if (layer == null || !owner.enabled)
			return;
		if (enterStarted >= 0)
			missed++;
		enterStarted = haxe.Timer.stamp();
	}

	function afterEnter(_:Event):Void {
		if (layer == null || !owner.enabled || enterStarted < 0)
			return;
		var ms = (haxe.Timer.stamp() - enterStarted) * 1000;
		enterStarted = -1;
		enterCount++;
		enterSum += ms;
		peak = Math.max(peak, ms);
		intervalMs += ms;
	}

	function beforeExit(_:Event):Void {
		if (layer == null || !owner.enabled)
			return;
		if (exitStarted >= 0)
			missed++;
		exitStarted = haxe.Timer.stamp();
	}

	function afterExit(_:Event):Void {
		if (layer == null || !owner.enabled || exitStarted < 0)
			return;
		var ms = (haxe.Timer.stamp() - exitStarted) * 1000;
		exitStarted = -1;
		exitCount++;
		exitSum += ms;
		peak = Math.max(peak, ms);
		intervalMs += ms;
	}

	static function precise(value:Float):Float
		return Math.round(value * 1000) / 1000;

	public function report(budget:Float):Dynamic {
		var observed = enterCount + exitCount > 0;
		var mean = (enterCount > 0 ? enterSum / enterCount : 0) + (exitCount > 0 ? exitSum / exitCount : 0);
		return {
			id: id,
			name: name,
			version: version,
			activeAtStart: active,
			coverage: observed ? "overlay frame dispatches only" : "no observed frame dispatches",
			observedMeanMs: observed ? precise(mean) : null,
			peakDispatchMs: observed ? precise(peak) : null,
			frameBudgetPercent: observed && budget > 0 ? precise(100 * mean / budget) : null,
			enterSamples: enterCount,
			exitSamples: exitCount,
			incompleteDispatches: missed,
			hadEnterListenersAtAttach: preexistingEnter,
			hadExitListenersAtAttach: preexistingExit,
			cpuPercent: null,
			gpuPercent: null,
			ramMiB: null
		};
	}

	public function detach():Void {
		if (layer == null)
			return;
		layer.removeEventListener(Event.ENTER_FRAME, beforeEnter);
		layer.removeEventListener(Event.ENTER_FRAME, afterEnter);
		layer.removeEventListener(Event.EXIT_FRAME, beforeExit);
		layer.removeEventListener(Event.EXIT_FRAME, afterExit);
		layer = null;
	}
}
