import sys.*;
import sys.io.*;
import haxe.io.*;
import haxe.unit.*;

class TestBase extends TestCase {
	static var haxelibPath = FileSystem.fullPath("run.n");
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
		if (!FileSystem.exists(dir)) return;
		var exitCode = switch (Sys.systemName()) {
			case "Windows":
				Sys.command("rmdir", ["/S", "/Q", StringTools.replace(FileSystem.fullPath(dir), "/", "\\")]);
			case _:
				Sys.command("rm", ["-rf", dir]);
		}
		if (exitCode != 0) {
			throw 'unable to delete $dir';
		}
	}
}
