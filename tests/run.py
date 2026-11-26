"""Offline contract/regression fixtures. Does not compile against the native game."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--haxe', default='haxe')
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
for module in ['Session.hx','CompactLog.hx','NativeProbe.hx']:
    assert 'Map<' not in (root / 'src' / module).read_text(), 'Abstract-map dispatch reintroduced: '+module
main_source = (root / 'src/Main.hx').read_text()
assert 'root.mask = clip' in (root / 'src/AnimationBench.hx').read_text(), 'Surface clipping removed'
assert '1152' not in (root / 'src/AnimationBench.hx').read_text(), 'Forced effect enlargement reintroduced'
assert main_source.count('ctx.settings.flag(') == 4 and 'ctx.settings.button(' not in main_source, 'Extra settings controls reintroduced'
assert 'openfl.system.System.totalMemory' not in (root / 'src/Main.hx').read_text(), 'Unsupported V18 static binding reintroduced'
stubs = {
    'starling/StatusTintFilter.hx':'package starling;class StatusTintFilter {public function new(){}public function set(c:UInt,a:Float){}public function get_matrix():Dynamic{return null;}}',
    'starling/textures/Texture.hx':'package starling.textures;class Texture {public function new(){}}',
    'starling/display/Image.hx':'package starling.display;class Image extends DisplayObject {public var width=0.;public var height=0.;public function new(t:starling.textures.Texture){super();}}',

    'openfl/display3D/Context3D.hx':'package openfl.display3D;class Context3D {public var totalGPUMemory=0;public function new(){}}',
    'starling/rendering/Painter.hx':'package starling.rendering;class Painter {public var drawCount=5;public var context:openfl.display3D.Context3D=null;public function new(){}}',
    'starling/display/Sprite.hx':'package starling.display;class Sprite extends DisplayObjectContainer {public static var failRender=false;public var touchable=true;public function new(){super();}public function dispose(){}public function setRequiresRedraw(){}public function render(painter:starling.rendering.Painter):Void{if(failRender)throw "missing render texture";} }',
    'starling/display/Quad.hx':'package starling.display;class Quad extends DisplayObject {public function new(w:Float,h:Float,c:Int){super();}}',
    'brain/assetRepository/AssetLoadingComponent.hx':'''package brain.assetRepository;class AssetLoadingComponent {public var failQueue=false;public var missingTexture=false;public var missingSymbol="";public var defer=false;public var deferred:Void->Void;public function new(){}public function queueStarlingAssetsForPath(path:String,done:Void->Void){if(failQueue)throw "missing asset bundle";if(defer)deferred=done;else done();}public function queueStarlingAssets(key:String,done:Void->Void){done();}public function getTextureFromAssetManager(name:String,key:String):starling.textures.Texture{if(missingTexture)return null;return new starling.textures.Texture();}public function createAnimationFromAssetManager(name:String):starling.extensions.animate.Animation{if(name==missingSymbol)return null;return new starling.extensions.animate.Animation();}}''',

    'facade/DBFacade.hx':'package facade;class DBFacade {public var sceneGraphManager:Dynamic;public var assetLoadingComponent:brain.assetRepository.AssetLoadingComponent;public var gameObjectManager:Dynamic;public var dbAccountInfo:Dynamic;public var starlingLayerManager:Dynamic;public var mainStateMachine:Dynamic;public function new(){}}',
    'mods/api/dungeon/Floor.hx':'package mods.api.dungeon;typedef Floor=mods.api.Context.Floor;',
    'mods/api/dungeon/Monster.hx':'package mods.api.dungeon;typedef Monster={id:UInt,name:String};',
    'openfl/display/MovieClip.hx':'package openfl.display;class MovieClip extends Sprite {public var totalFrames=12;public var currentFrame=1;public var currentLabel="loading";public function new(){super();}}',

    'mods/api/Subscription.hx': '''package mods.api; class Subscription {public var active=true;public function new(){} public function cancel(){active=false;}}''',
    'mods/api/Context.hx': '''package mods.api;
class Context {
public var data:String;public var viewWidth=1280.;public var viewHeight=720.;public var overlay=new openfl.display.Sprite();
public var keyHandler:Void->Void;public var keys:Dynamic;public var core:Dynamic;public var settings:Dynamic;public var state:{inTown:Bool,floor:Null<Floor>,heroes:Array<mods.api.dungeon.Hero>};
public function new(){keys={action:function(id:String,label:String,description:String,key:Int){return {onPress:function(f:Void->Void){keyHandler=f;return new Subscription();}};}};settings={flag:function(a:String,b:String,c:String,d:Bool){return new mods.api.settings.Flag(d);},button:function(a:String,b:String,c:String){return {onPress:function(f:Void->Void){return new Subscription();}};}};}
public function log(message:String):Void{}
public var activeMods:Array<String>=[];public function isActive(id:String):Bool{return activeMods.indexOf(id)>=0;}
public function onFloorEnter(f:Dynamic->Void):Subscription{return new Subscription();}
public function onFloorExit(f:Dynamic->Void):Subscription{return new Subscription();}
public function onTownEnter(f:Void->Void):Subscription{return new Subscription();}
public function onTownExit(f:Void->Void):Subscription{return new Subscription();}
}
typedef Floor={id:Int,number:Int,map:String,monsters:Array<mods.api.dungeon.Monster>};''',
    'openfl/ui/Keyboard.hx':'package openfl.ui;class Keyboard {public static inline var F7=118;}',
    'openfl/system/System.hx':'package openfl.system;class System {public static var copied="";public static function setClipboard(s:String){copied=s;}}',
    'flash/system/System.hx':'package flash.system;class System {public static var copied="";public static function setClipboard(s:String){copied=s;}}',
    'starling/events/Event.hx': 'package starling.events;class Event {public function new(){}}',
    'starling/display/DisplayObject.hx': '''package starling.display;class DisplayObject {public var mask:DisplayObject;public var filter:Dynamic;public var parent:DisplayObjectContainer;public var visible=true;public var alpha=1.;public var name:String;public function get_filter():Dynamic{return filter;}public function new(){}}''',
    'starling/display/DisplayObjectContainer.hx': '''package starling.display;class DisplayObjectContainer extends DisplayObject {public var children:Array<DisplayObject>=[];public var numChildren(get,never):Int;public function get_numChildren(){return children.length;}public function new(){super();}public function getChildAt(i:Int):DisplayObject{return children[i];}public function addChild(c:DisplayObject){children.push(c);c.parent=this;}}''',
    'starling/extensions/animate/Animation.hx': '''package starling.extensions.animate;class Animation extends starling.display.DisplayObjectContainer {public var numFrames=12;public var deepestFrames=24;public var frameRate=30.;public var sourceWidth=512.;public var sourceHeight=512.;public var symbolName="spark";public var currentLabel="loop";public var isPlaying=true;public var composing=true;public function new(){super();}}''',
    'starling/core/Starling.hx': '''package starling.core;class Starling {public var stage=new starling.display.DisplayObjectContainer();public function get_stage():starling.display.DisplayObjectContainer{return stage;}public static var current:Starling=null;public var painter_instance=new starling.rendering.Painter();public var listeners=0;public function new(){}public function addEventListener(n:String,f:starling.events.Event->Void){listeners++;}public function removeEventListener(n:String,f:starling.events.Event->Void){listeners--;}}''',
    'actor/ActorGameObject.hx': '''package actor;class ActorGameObject {public var actorView:ActorView;public function get_actorView():ActorView{return actorView;}public function new(){actorView=new ActorView();}}''',
    'actor/ActorView.hx': '''package actor;class ActorView {public var bodyAnimRenderer:ActorRenderer;public function get_bodyAnimRenderer():ActorRenderer{return bodyAnimRenderer;}public function new(){bodyAnimRenderer=new ActorRenderer();}}''',
    'actor/ActorRenderer.hx': '''package actor;class ActorRenderer {public var currentAnimName="attack";public function get_currentAnimName():String{return currentAnimName;}public var rendererType="StarlingActorRenderer";public var isCulled=false;public function new(){}}''',
}
with tempfile.TemporaryDirectory(prefix='benchmark-checks-') as folder:
    target = Path(folder)
    shutil.copytree(root / 'tests/support', target, dirs_exist_ok=True)
    for name, text in stubs.items():
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')
    animation = target / 'starling/extensions/animate/Animation.hx'
    source = animation.read_text()
    for name, kind in [('symbolName','String'),('currentLabel','String'),('isPlaying','Bool'),('numFrames','Int'),('deepestFrames','Int'),('frameRate','Float'),('sourceWidth','Float'),('sourceHeight','Float')]:
        source = source.replace('public function new()', 'public function get_'+name+'():'+kind+'{return '+name+';}public function new()', 1)
    source=source.replace('public function new()', 'public function setColorMatrix(matrix:Dynamic):Void{}public function getBounds(target:starling.display.DisplayObject):Dynamic{return {x:-50.,y:-50.,width:100.,height:100.};}public function getFrame(label:String):Int{return 0;}public function gotoLabel(label:String,loop:Bool=true):Void{}public function play():Void{}public function advanceTime(dt:Float):Void{}public function dispose():Void{}public function new()')
    animation.write_text(source)
    path=target/'starling/display/DisplayObject.hx'
    path.write_text(path.read_text().replace('public var filter:', 'public var pivotX=0.;public var pivotY=0.;public var x=0.;public var y=0.;public var scaleX=1.;public var scaleY=1.;public var filter:'))
    path=target/'starling/display/DisplayObjectContainer.hx'
    path.write_text(path.read_text().replace('public function new()', 'public function get_stageWidth():Int{return 1280;}public function get_stageHeight():Int{return 720;}public function removeChild(child:DisplayObject):Void{children.remove(child);child.parent=null;}public function new()'))
    # Augment OpenFL doubles with native public event/UI contracts used by this mod.
    path = target / 'openfl/events/Event.hx'
    path.write_text(path.read_text().replace('public static var DEACTIVATE', 'public static var EXIT_FRAME="exitFrame";public static var ACTIVATE="activate";public static var DEACTIVATE'))
    path = target / 'openfl/events/MouseEvent.hx'
    path.write_text(path.read_text().replace('public var buttonDown', 'public static var MOUSE_OVER="mouseOver";public static var MOUSE_OUT="mouseOut";public static var MOUSE_WHEEL="mouseWheel";public var delta=0;public var buttonDown'))
    path = target / 'openfl/display/DisplayObjectContainer.hx'
    path.write_text(path.read_text().replace('public function getChildIndex', 'public function removeChildren(){for(c in children.copy())removeChild(c);}public function getChildIndex'))
    path = target / 'openfl/text/TextField.hx'
    path.write_text(path.read_text().replace('public var textColor:Int;', 'public var textColor:Int;public var htmlText:String;public function setTextFormat(format:TextFormat,start:Int=-1,end:Int=-1):Void{}'))
    path.write_text(path.read_text().replace('public var type:', 'public var scrollV=1;public var type:'))
    shutil.copytree(root / 'src', target / 'mods/benchmark')
    shutil.copy2(root / 'tests/Checks.hx', target / 'Checks.hx')
    subprocess.run([args.haxe, '-cp', str(target), '-main', 'Checks', '--interp'], check=True)
