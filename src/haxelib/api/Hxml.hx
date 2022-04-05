package haxelib.api;

using StringTools;

private final regex = ~/\r?\n/g;

/**
	Normalizes `hxmlContents` by stripping comments, trimming whitespace
	from each line and removing empty lines
**/
function normalizeHxml(hxmlContents:String):String {
	return regex.split(hxmlContents).map(StringTools.trim).filter(function(line) {
		return line != "" && !line.startsWith("#");
	}).join('\n');
}
