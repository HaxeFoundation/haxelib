import Sys.*;
import sys.*;
import sys.io.*;

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

	static function main():Void {
		var folder = "package/src/tools/haxelib";
		if (!FileSystem.exists("package")) {
			FileSystem.createDirectory("folder");
		}
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