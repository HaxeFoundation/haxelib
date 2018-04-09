package website;

/**
 * @author Mark Knol
 */
class Util {
	
	public static function escape(str:String) return StringTools.htmlEscape(str, true);
	
	/**
	   @param	date should be format "yyyy-mm-dd"
	**/
	public static function formatDate(date:String) {
		var split = date.split("-");
		var target = new Date(Std.parseInt(split[0]), Std.parseInt(split[1]) - 1, Std.parseInt(split[2]), 0, 0, 0);

		var minuteInMs = 1000 * 60;
		var hourInMs = minuteInMs * 60;
		var dayInMs = hourInMs * 24;
    
		var targetTime = target.getTime();

		var now = Date.now().getTime();
		var remainingMs = now - targetTime;
 
		var days = Math.floor(remainingMs / dayInMs);
		var years = Std.int(days / 356);
		var months = Std.int(days / 30); // nope, it doesnt work like that eh
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
	}
}