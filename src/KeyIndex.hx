package mods.benchmark;

/** Mod-owned bounded arrays avoid native abstract-map method dispatch. */
class KeyIndex {
	public static function find(keys:Array<String>, key:String):Int {
		var low = 0;
		var high = keys.length;
		while (low < high) {
			var middle = (low + high) >> 1;
			var candidate:String = keys[middle];
			if (candidate == key)
				return middle;
			if (candidate < key)
				low = middle + 1;
			else
				high = middle;
		}
		return -low - 1;
	}
}
