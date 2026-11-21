package mods.api.dungeon;

typedef Hero = {id:Int, local:Bool, ?classId:UInt, ?x:Float, ?y:Float, ?player:{accountId:Int, isFriend:Bool, ?name:String}};
