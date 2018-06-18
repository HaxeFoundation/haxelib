package website;

/**
 * @author Mark Knol
 */
class Util {
	private static var _MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
	
	public static function escape(str:String) return StringTools.htmlEscape(str, true);
	
	/**
	   Outputs to "xx-Jan 2019" (accurate=true) or "xx days/weeks ago" (accurate=false)
	   @param	date should be format "yyyy-mm-dd"
	**/
	public static function formatDate(date:String, accurate:Bool = false) {
		var split = date.split("-");
		var target:Date = new Date(Std.parseInt(split[0]), Std.parseInt(split[1]) - 1, Std.parseInt(split[2]), 0, 0, 0);
		
		if (!accurate) { // loose date format 
			var minuteInMs = 1000 * 60;
			var hourInMs = minuteInMs * 60;
			var dayInMs = hourInMs * 24;
		
			var targetTime = target.getTime();

			var now = Date.now().getTime();
			var remainingMs = now - targetTime;
	 
			var days = Math.floor(remainingMs / dayInMs);
			var years = Std.int(days / 356);
			var months = Std.int(days / 30.4167); // should be accurate enough
			var weeks = Std.int(days / 7); 
			 
			if (years == 0) { 
				if (months < 2) {
					if (weeks < 1) { 
						if (days == 0) return 'today'; 
						if (days == 1) return '$days day ago';
						return '$days days ago'; 
					} else {
						if (weeks == 1) return '$weeks week ago'; 
						else return '$weeks weeks ago';
					}
				} else { 
					return '$months months ago'; 
				}
			} else {
				return years > 1 ? '$years years ago' : '$years year ago';
			}
		} else {
			var month = _MONTHS[target.getMonth()];
			var date = target.getDate();
			var day = if (date < 10) '0$date' else '$date';
			return '$day-$month ${target.getFullYear()}';
		}
	}
	
	public static function syntaxHighlightHTML(code:String):String {
		var html = code;
		html = ~/(("|')(.+?)?\2)/g.replace(html, "<span class=str>$1</span>");
		html = ~/(&lt;\\?)(.+?)(\/|\s|&gt;)/g.replace(html, "$1<span class=kwd>$2</span>$3");
		
		return html;
	}
}