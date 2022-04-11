package haxelib;

#if macro
import haxe.macro.Expr;

using haxe.macro.Tools;
#end

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
		// check if the .git folder exist
		// prevent getting the git info of a parent directory
		if (!sys.FileSystem.isDirectory(".git"))
			return macro $v{version};

		var p;
		try {
			//get commit sha
			p = new sys.io.Process("git", ["rev-parse", "HEAD"]);
			var sha = p.stdout.readAll().toString().trim();
			p.close();

			//check to see if there is changes, staged or not
			p = new sys.io.Process("git", ["status", "--porcelain"]);
			var changes = p.stdout.readAll().toString().trim();
			p.close();

			var longVersion = version + switch(changes) {
				case "":
					' ($sha)';
				case _:
					' ($sha - dirty)';
			}
			return macro $v{longVersion};
		} catch(e:Dynamic) {
			if (p != null) p.close();
			return macro $v{version};
		}
	}
}
