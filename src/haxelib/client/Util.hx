package haxelib.client;

using StringTools;

class Util {

	macro static public function rethrow(e) {
		return if (haxe.macro.Context.defined("neko"))
			macro neko.Lib.rethrow(e);
		else
			macro throw e;
	}

	#if macro
	static function readVersionFromHaxelibJson() {
		return haxe.Json.parse(sys.io.File.getContent("haxelib.json")).version;
	}
	#end
	
	macro static public function getHaxelibVersion() {
		return macro $v{readVersionFromHaxelibJson()};
	}

	macro static public function getHaxelibVersionLong() {
		var version:String = readVersionFromHaxelibJson();
		var p;
		try {
			//check if the .git folder exist
			//prevent getting the git info of a parent directory
			if (!sys.FileSystem.isDirectory(".git"))
				throw "Not a git repo.";

			//get commit sha
			p = new sys.io.Process("git", ["rev-parse", "HEAD"]);
			var sha = p.stdout.readAll().toString().trim();
			p.close();

			//check to see if there is changes, staged or not
			p = new sys.io.Process("git", ["status", "--porcelain"]);
			var changes = p.stdout.readAll().toString().trim();
			p.close();

			version += switch(changes) {
				case "":
					' ($sha)';
				case _:
					' ($sha - dirty)';
			}
			return macro $v{version};
		} catch(e:Dynamic) {
			if (p != null) p.close();
			return macro $v{version};
		}
	}
}