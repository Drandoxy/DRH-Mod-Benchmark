package mods.benchmark;

import brain.assetRepository.AssetLoadingComponent;
import starling.display.Sprite;
import starling.display.Image;
import starling.extensions.animate.Animation;

/** Procedurally arranged arena using installed game tiles and props; no game-state objects. */
class BaselineScene {
	public var seed(default, null):Int;
	public var heroes(default, null):Array<Animation> = [];

	var group:Sprite;
	var scales:Array<Float> = [];
	var labels:Array<String> = [];
	var time = 0.0;
	var onAsset:Dynamic->Void;

	public function new(loader:AssetLoadingComponent, parent:Sprite, recipes:Array<Dynamic>, seed:Int, onAsset:Dynamic->Void) {
		this.seed = seed;
		this.onAsset = onAsset;
		group = new Sprite();
		group.touchable = false;
		parent.addChild(group);
		try {
			// A complete authored room floor, rather than random transition tiles.
			image(loader, "db_grd_castle_arena_exitroom_floor", 0, 0, 960, 640);
			for (i in 0...6)
				image(loader, i % 2 == 0 ? "db_prop_castle_arena_barrel" : "db_prop_castle_arena_box", 60 + (i % 3) * 385, i < 3 ? 28 : 540, 64, 64);
			for (recipe in recipes) {
				onAsset(recipe);
				var a = loader.createAnimationFromAssetManager(recipe.symbol);
				if (a == null)
					throw "Hero animation unavailable: " + recipe.symbol;
				heroes.push(a);
				for (label in ["idle_angE", "run_angA", "run_angB", "run_angC", "run_angD", "run_angE"])
					if (a.getFrame(label) < 0)
						throw "Hero label unavailable: " + recipe.symbol + " / " + label;
				a.gotoLabel("idle_angE", true);
				a.play();
				scales.push(AnimationSizing.fitHeight(a, recipe.pixels, recipe.bounds));
				labels.push("idle_angE");
				group.addChild(a);
			}
			update(0);
		} catch (e:Dynamic) {
			dispose();
			throw e;
		}
	}

	function image(loader:AssetLoadingComponent, name:String, x:Float, y:Float, w:Float, h:Float):Void {
		onAsset({
			name: name,
			path: "castle_arena native map textures",
			symbol: name,
			label: null,
			pixels: w
		});
		var texture = loader.getTextureFromAssetManager(name, "castle_arena");
		if (texture == null)
			throw "Scenery texture unavailable: " + name;
		var image = new Image(texture);
		image.x = x;
		image.y = y;
		image.width = w;
		image.height = h;
		group.addChild(image);
	}

	public function reset():Void {
		time = 0;
		update(0);
	}

	public function update(dt:Float):Void {
		time += dt;

		for (i in 0...heroes.length) {
			var a = heroes[i];
			var pose = HeroMotion.pose(time, i);
			if (labels[i] != pose.label) {
				a.gotoLabel(pose.label, true);
				labels[i] = pose.label;
			}
			a.scaleX = pose.flip ? -scales[i] : scales[i];
			a.scaleY = scales[i];
			a.x = 480 + pose.x;
			a.y = 360 + pose.y;
			a.advanceTime(dt);
		}
	}

	public function dispose():Void {
		if (group != null) {
			if (group.parent != null)
				group.parent.removeChild(group);
			group.dispose();
			group = null;
		}
		heroes = [];
		scales = [];
		labels = [];
	}
}
