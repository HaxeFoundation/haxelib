import sys.*;
import sys.io.*;
import haxe.io.*;
import haxe.unit.*;

class TestBase extends TestCase {
	static var haxelibPath = FileSystem.fullPath("run.n");
	public function runHaxelib(args:Array<String>, printProgress = false) {
		var p = new Process("neko", [haxelibPath].concat(args));
		var stdout = '';
		var stderr = '';
		var eofCount = 0;
		var c;
		while (eofCount < 2) {
			eofCount = 0;
			try {
				c = p.stdout.readByte();
				if (printProgress) Sys.stdout().writeByte(c);
				stdout += String.fromCharCode(c);
			} catch(e:Eof) {
				eofCount++;
			}
			try {
				c = p.stderr.readByte();
				if (printProgress) Sys.stderr().writeByte(c);
				stderr += String.fromCharCode(c);
			} catch(e:Eof) {
				eofCount++;
			}
		}
		if (printProgress) {
			Sys.stdout().flush();
			Sys.stderr().flush();
		}
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
