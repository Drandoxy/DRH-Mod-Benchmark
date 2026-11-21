package openfl.display;

class DisplayObjectContainer {
	public var stage:Stage;

	public function getBounds(target:Dynamic):Dynamic {
		return {
			x: 0.,
			y: 0.,
			width: width,
			height: height
		};
	}

	public var alpha = 1.;
	public var parent:DisplayObjectContainer;
	public var numChildren(get, never):Int;

	var children:Array<Dynamic> = [];

	function get_numChildren() {
		return children.length;
	}

	public var name:String;
	public var scaleX = 1.;
	public var scaleY = 1.;

	public function globalToLocal(p:openfl.geom.Point) {
		return p;
	}

	public var width = 64.;
	public var height = 64.;
	public var x = 0.;
	public var y = 0.;
	public var visible = true;

	public function new() {}

	public function addChild(v:Dynamic):Dynamic {
		if (v.parent != null)
			v.parent.removeChild(v);
		children.push(v);
		v.parent = this;
		return v;
	}

	public function removeChild(v:Dynamic):Dynamic {
		children.remove(v);
		v.parent = null;
		return v;
	}

	public function getChildIndex(v:Dynamic):Int {
		return children.indexOf(v);
	}

	public function getChildAt(i:Int):Dynamic {
		return children[i];
	}

	public function getChildByName(n:String):Dynamic {
		for (c in children)
			if (c.name == n)
				return c;
		return null;
	}

	var listeners:Map<String, Array<{call:Dynamic, priority:Int}>> = [];

	public function hasEventListener(n:String):Bool {
		return listeners.exists(n) && listeners[n].length > 0;
	}

	public function addEventListener(n:String, f:Dynamic, c:Bool = false, p:Int = 0) {
		if (!listeners.exists(n))
			listeners[n] = [];
		listeners[n].push({call: f, priority: p});
		listeners[n].sort(function(a, b) return b.priority - a.priority);
	}

	public function removeEventListener(n:String, f:Dynamic, c:Bool = false) {
		if (listeners.exists(n))
			for (row in listeners[n].copy())
				if (Reflect.compareMethods(row.call, f))
					listeners[n].remove(row);
	}

	public function dispatchEvent(e:openfl.events.Event):Bool {
		if (listeners.exists(e.type))
			for (row in listeners[e.type].copy())
				row.call(e);
		return true;
	}
}
