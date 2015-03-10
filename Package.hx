import Sys.*;
import sys.*;
import sys.io.*;
import haxe.io.*;

class Package {
	static function cp(srcFile:String, destFile:String):Void {
		File.saveBytes(destFile, File.getBytes(srcFile));
	}

	static function zip(srcFolder:String, destFile:String):Void {
		switch (Sys.systemName()) {
			case "Linux", "Mac":
				command("zip", ["-r", destFile, srcFolder]);
			case "Windows":
				command("7za", ["a", "-tzip", "-r", destFile, srcFolder]);
		}
	}

	/**
		Make directory recursively.
		It is needed for Haxe 3.1.3, which FileSystem.createDirectory is not recursive.
	*/
	static function mkdir(path:String):Void {
		#if (haxe_ver < 3.2)
		path = Path.normalize(path);

		if (FileSystem.exists(path)) {
			return;
		}

		var parent = path.substring(0, path.lastIndexOf("/"));
		if (parent != "")
			mkdir(parent);
		#end
		
		FileSystem.createDirectory(path);
	}

	static function main():Void {
		mkdir("package/src/tools/haxelib");

		for (file in [
			"Data.hx",
			"Main.hx",
			"Rebuild.hx",
			"SemVer.hx",
			"SiteApi.hx",
			"ConvertXml.hx",
		]) {
			cp('src/tools/haxelib/$file', 'package/src/tools/haxelib/$file');
		}
		cp("haxelib.json", "package/haxelib.json");

		setCwd("package");

		var zipFile = "package.zip";
		if (FileSystem.exists(zipFile)) {
			FileSystem.deleteFile(zipFile);
		}
		zip(".", zipFile);
	}
}