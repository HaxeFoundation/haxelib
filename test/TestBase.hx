import sys.*;
import sys.io.*;
import haxe.io.*;
import haxe.unit.*;

class TestBase extends TestCase {
	static var haxelibPath = FileSystem.absolutePath("bin/haxelib.n");
	public function runHaxelib(args:Array<String>) {
		var p = new Process("neko", [haxelibPath].concat(args));
		var stdout = p.stdout.readAll().toString();
		var stderr = p.stderr.readAll().toString();
		var exitCode = p.exitCode();
		p.close();
		return {
			stdout: stdout,
			stderr: stderr,
			exitCode: exitCode
		}
	}

	public function deleteDirectory(dir:String):Void {
		for (item in FileSystem.readDirectory(dir)) {
			item = haxe.io.Path.join([dir, item]);
			if (FileSystem.isDirectory(item)) {
				deleteDirectory(item);
			} else {
				FileSystem.deleteFile(item);
			}
		}
		FileSystem.deleteDirectory(dir);
	}
}