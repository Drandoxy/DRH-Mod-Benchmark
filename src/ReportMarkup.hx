package mods.benchmark;

import openfl.text.TextField;
import openfl.text.TextFormat;

/** Plain text preserves line breaks; native text ranges supply color without HTML parsing. */
class ReportMarkup {
	public static function select(content:String, details:Bool):String {
		var split = content.indexOf("TECHNICAL DETAILS");
		return split < 0 ? content : details ? content.substr(split) : content.substr(0, split);
	}

	/** The drop in a scene line ("vs baseline (-45%)"), or -1 when the line has none. */
	public static function dropShare(line:String):Int {
		var pattern = ~/vs baseline \(-([0-9]+)%\)/;
		return pattern.match(line) ? Std.parseInt(pattern.matched(1)) : -1;
	}

	/** Green up to a third slower than the baseline, amber up to two thirds, then red. */
	public static function dropColor(share:Int):Int {
		return share < 34 ? 0x80D5B6 : share < 67 ? 0xEBC77D : 0xF0AA86;
	}

	public static function apply(field:TextField, content:String, details:Bool):Void {
		field.multiline = true;
		field.wordWrap = true;
		field.text = select(content, details);
		var offset = 0;
		for (line in field.text.split("\n")) {
			var clean = StringTools.trim(line);
			var heading = clean.length > 0 && clean == clean.toUpperCase() && ~/^[A-Z ,:_-]+$/.match(StringTools.replace(clean, "/", " "));
			var color = line.indexOf("| Smooth") >= 0 ? 0x80D5B6 : line.indexOf("| Moderate load") >= 0 ? 0xEBC77D : line.indexOf("| Heavy load") >= 0
				|| line.indexOf("| Very heavy load") >= 0 ? 0xF0AA86 : heading ? 0x8FCBEE : clean.indexOf("IMPORTANT") >= 0
					|| clean.indexOf("PARTIAL RECORDING") >= 0 ? 0xF0AA86 : clean.indexOf("Most frames") == 0 ? 0x80D5B6 : clean.indexOf("Below ") == 0
						|| clean.indexOf("Worst recorded") == 0 ? 0xEBC77D : 0xD2DEE8;
			if (line.length > 0)
				field.setTextFormat(new TextFormat("_sans", 14, color, heading), offset, offset + line.length);
			// The FPS label keeps its colour; the drop against the baseline gets its own, so a scene can read
			// "good FPS" and "much slower than the baseline" at once.
			var at = line.indexOf("| -");
			var share = dropShare(line);
			if (at >= 0 && share >= 0)
				field.setTextFormat(new TextFormat("_sans", 14, dropColor(share), false), offset + at, offset + line.length);
			offset += line.length + 1;
		}
	}
}
