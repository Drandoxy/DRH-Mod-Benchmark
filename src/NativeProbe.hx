package mods.benchmark;

import mods.api.Context;
import mods.api.dungeon.Floor;
import actor.ActorGameObject;
import actor.ActorView;
import actor.ActorRenderer;
import facade.DBFacade;
import starling.core.Starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.extensions.animate.Animation;

/** Native getters are explicit; one failed feature never discards the other readings. */
class NativeProbe {
	public var renderer(default, null):Starling;
	public var stage(default, null) = "idle";
	public var failures(default, null) = 0;
	public var faults(default, null):Array<Dynamic> = [];

	public function new() {}

	public function connect(ctx:Context):Void {
		var facade:DBFacade = ctx.core.facade;
		renderer = facade == null || facade.starlingLayerManager == null ? null : facade.starlingLayerManager.starlingInstance;
	}

	public function scene(ctx:Context):String {
		try {
			var facade:DBFacade = ctx.core.facade;
			return facade == null || facade.mainStateMachine == null ? "Unknown" : facade.mainStateMachine.currentStateName;
		} catch (_:Dynamic) {
			return "Unknown";
		}
	}

	public function snapshot(ctx:Context, detailed:Bool):Dynamic {
		var started = haxe.Timer.stamp();
		var before = failures;
		var groups:Array<Dynamic> = [];
		var enemies:Dynamic = null;
		var sampled = 0;
		var map = "UNKNOWN";
		var number = 0;
		var partial = false;
		var nodes = 0;
		var animations = 0;
		var filters = 0;
		var flashNodes = 0;
		var flashAnimations = 0;
		var ping:Dynamic = null;
		stage = "scene identity";
		try {
			var floor:Floor = ctx.state.floor;
			map = floor == null ? (ctx.state.inTown ? "TOWN" : "LOADING") : floor.map;
			number = floor == null ? 0 : floor.number;
		} catch (error:Dynamic) {
			failure(stage, error);
			partial = true;
		}
		stage = "heartbeat";
		try {
			var facade:DBFacade = ctx.core.facade;
			if (facade != null && facade.dbAccountInfo != null && facade.dbAccountInfo.SocketPingMilsecs > 0)
				ping = facade.dbAccountInfo.SocketPingMilsecs;
		} catch (error:Dynamic)
			failure(stage, error);
		stage = "API actors";
		try {
			var floor:Floor = ctx.state.floor;
			if (floor != null) {
				var monsters:Array<mods.api.dungeon.Monster> = floor.monsters;
				enemies = monsters.length;
				for (monster in monsters) {
					if (sampled >= 128 || haxe.Timer.stamp() - started > 0.001) {
						partial = true;
						break;
					}
					stage = "enemy lookup";
					try
						actor(ctx, monster.id, "enemy:" + monster.name, groups)
					catch (error:Dynamic)
						failure(stage, error);
					sampled++;
				}
				for (hero in ctx.state.heroes) {
					if (sampled >= 144 || haxe.Timer.stamp() - started > 0.001) {
						partial = true;
						break;
					}
					stage = "hero lookup";
					try
						actor(ctx, hero.id, "hero:" + hero.classId, groups)
					catch (error:Dynamic)
						failure(stage, error);
					sampled++;
				}
			}
		} catch (error:Dynamic) {
			failure(stage, error);
			partial = true;
		}
		if (detailed && renderer != null) {
			var treeStart = haxe.Timer.stamp();
			stage = "Starling stage getter";
			try {
				var stack:Array<DisplayObject> = [renderer.get_stage()];
				while (stack.length > 0) {
					if (nodes >= 2048 || haxe.Timer.stamp() - treeStart > 0.0015) {
						partial = true;
						break;
					}
					var node:DisplayObject = stack.pop();
					if (node == null)
						continue;
					nodes++;
					stage = "Starling filter getter";
					try {
						if (node.get_filter() != null)
							filters++;
					} catch (error:Dynamic)
						failure(stage, error);
					stage = "Starling animation identification";
					if (Std.isOfType(node, Animation)) {
						var animation:Animation = cast node;
						try {
							stage = "Starling symbol/label getters";
							var key = "symbol:" + animation.get_symbolName() + " | " + animation.get_currentLabel() + " | "
								+ (animation.get_isPlaying() ? "playing" : "paused");
							stage = "Starling animation metadata getters";
							add(groups, key, {
								frames: animation.get_numFrames(),
								nestedFrames: animation.get_deepestFrames(),
								fps: animation.get_frameRate(),
								atlasWidth: animation.get_sourceWidth(),
								atlasHeight: animation.get_sourceHeight()
							});
							animations++;
						} catch (error:Dynamic)
							failure(stage, error);
					}
					stage = "Starling container traversal";
					if (Std.isOfType(node, DisplayObjectContainer)) {
						var container:DisplayObjectContainer = cast node;
						var take = Std.int(Math.min(container.get_numChildren(), 2048 - stack.length));
						if (take < container.get_numChildren())
							partial = true;
						for (i in 0...take)
							stack.push(container.getChildAt(i));
					}
				}
			} catch (error:Dynamic) {
				failure(stage, error);
				partial = true;
			}
		}
		// Loading screens and legacy UI use OpenFL timelines, outside the Starling tree.
		if (detailed && ctx.overlay.stage != null) {
			var flashStart = haxe.Timer.stamp();
			stage = "OpenFL scene traversal";
			try {
				var stack:Array<openfl.display.DisplayObject> = [ctx.overlay.stage];
				while (stack.length > 0) {
					if (flashNodes >= 512 || haxe.Timer.stamp() - flashStart > 0.001) {
						partial = true;
						break;
					}
					var node:openfl.display.DisplayObject = stack.pop();
					if (node == null || node.name == "ModOverlay")
						continue;
					flashNodes++;
					if (Std.isOfType(node, openfl.display.MovieClip)) {
						var clip:openfl.display.MovieClip = cast node;
						try {
							stage = "OpenFL timeline getters";
							if (clip.totalFrames > 1) {
								var kind = Type.getClassName(Type.getClass(clip));
								add(groups, "timeline:" + kind + " | " + clip.name + " | " + clip.currentLabel,
									{frames: clip.totalFrames, currentFrame: clip.currentFrame});
								flashAnimations++;
							}
						} catch (error:Dynamic)
							failure(stage, error);
					}
					stage = "OpenFL container traversal";
					if (Std.isOfType(node, openfl.display.DisplayObjectContainer)) {
						var container:openfl.display.DisplayObjectContainer = cast node;
						var take = Std.int(Math.min(container.numChildren, 512 - stack.length));
						if (take < container.numChildren)
							partial = true;
						for (i in 0...take)
							stack.push(container.getChildAt(i));
					}
				}
			} catch (error:Dynamic) {
				failure(stage, error);
				partial = true;
			}
		}
		stage = "snapshot return";
		return {
			map: map,
			floor: number,
			scene: scene(ctx),
			enemies: enemies,
			sampledActors: sampled,
			sceneNodes: nodes,
			animations: animations,
			filters: filters,
			flashNodes: flashNodes,
			flashAnimations: flashAnimations,
			partial: partial || groups.length >= 256 || failures > before,
			ping: ping,
			groups: groups,
			scanMs: FrameWindow.round((haxe.Timer.stamp() - started) * 1000)
		};
	}

	function actor(ctx:Context, id:UInt, name:String, groups:Array<Dynamic>):Void {
		var facade:DBFacade = ctx.core.facade;
		var object = facade.gameObjectManager.getReferenceFromId(id);
		if (!Std.isOfType(object, ActorGameObject))
			return;
		var actor:ActorGameObject = cast object;
		stage = "actor view getter";
		var view:ActorView = actor.get_actorView();
		if (view == null)
			return;
		stage = "actor renderer getter";
		var render:ActorRenderer = view.get_bodyAnimRenderer();
		if (render == null)
			return;
		stage = "actor animation name getter";
		var animation = render.get_currentAnimName();
		// Renderer backend getters can be unavailable while art is loading; name remains useful.
		add(groups, name + " | " + animation, null);
	}

	function add(groups:Array<Dynamic>, key:String, metadata:Dynamic):Void {
		if (key.length > 250)
			key = key.substr(0, 250);
		for (row in groups)
			if (row.key == key) {
				row.count++;
				return;
			}
		if (groups.length < 256)
			groups.push({key: key, count: 1, metadata: metadata});
	}

	public function failure(where:String, error:Dynamic):Void {
		failures++;
		var message = Std.string(error);
		if (message.length > 240)
			message = message.substr(0, 240);
		for (row in faults)
			if (row.stage == where && row.message == message) {
				row.count++;
				return;
			}
		if (faults.length < 12)
			faults.push({stage: where, message: message, count: 1});
	}
}
