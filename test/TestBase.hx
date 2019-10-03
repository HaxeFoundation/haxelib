import sys.*;
import sys.io.*;
import haxe.io.*;
import haxe.unit.*;

class TestBase extends TestCase {
	static var haxelibPath = FileSystem.fullPath("run.n");
	public function runHaxelib(args:Array<String>, echo = false) {
		if(echo) {
			Sys.command('neko', [haxelibPath].concat(args));
		}
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
		HaxelibTests.deleteDirectory(dir);
	}
}
