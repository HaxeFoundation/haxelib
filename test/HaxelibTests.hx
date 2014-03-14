import haxe.unit.TestRunner;
import sys.*;
import sys.io.*;
import tests.*;
using StringTools;

class HaxelibTests {
	static function runCommand(cmd:String, args:Array<String>):Void {
		Sys.println('Command: $cmd $args');
		var exitCode = Sys.command(cmd, args);
		Sys.println('Command exited with $exitCode: $cmd $args');
		if (exitCode != 0) {
			Sys.exit(exitCode);
		}
	}

	static function prepare():Void {
		runCommand("./package.sh", []);

		/*
			(re)package the dummy libraries
		*/
		for (item in FileSystem.readDirectory("test/libraries")) {
			if (
				!item.startsWith("lib") ||
				item.endsWith(".zip")
			)
				continue;

			var zipUri = 'test/libraries/${item}.zip';
			if (FileSystem.exists(zipUri)) {
				FileSystem.deleteFile(zipUri);
			}
			Sys.setCwd('test/libraries/${item}');
			runCommand("zip", ["-r", '../${item}.zip', "*"]);
			Sys.setCwd('../../..');
		}
	}

	static function main():Void {
		prepare();

		var r = new TestRunner();

		r.add(new TestSemVer());
		r.add(new TestData());
		
		var success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}