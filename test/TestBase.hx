import sys.FileSystem;
import sys.io.Process;
import haxe.io.Eof;
import haxe.unit.TestCase;


class TestBase extends TestCase {
	static final haxelibPath = FileSystem.fullPath("run.n");

	public function runHaxelib(args:Array<String>, printProgress = false) {
		final p = new Process("neko", [haxelibPath].concat(args));
		var stdout = '';
		var stderr = '';
		var eofCount = 0;
		var c:Int;
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
		final exitCode = p.exitCode();
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
