package haxelib.client;

using StringTools;

private final regex = ~/\r?\n/g;
/** strip comments, trim whitespace from each line and remove empty lines **/
function normalizeHxml(hxmlContents:String) {
	return regex.split(hxmlContents).map(StringTools.trim).filter(function(line) {
		return line != "" && !line.startsWith("#");
	}).join('\n');
}
