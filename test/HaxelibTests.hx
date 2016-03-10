import haxelib.client.Vcs.VcsID;
import haxe.unit.TestRunner;
import sys.*;
import sys.io.*;
import tests.*;
using StringTools;

class HaxelibTests {
	public static function runCommand(cmd:String, args:Array<String>):Void
	{
		Sys.println('Command: $cmd $args');

		var exitCode = Sys.command(cmd, args);

		Sys.println('Command exited with $exitCode: $cmd $args');

		if(exitCode != 0)
			Sys.exit(exitCode);
	}

	static function cmdSucceed(cmd:String, ?args:Array<String>):Bool {
		var p = try {
			new Process(cmd, args);
		} catch(e:Dynamic) {
			return false;
		}
		var exitCode = p.exitCode();
		p.close();
		return exitCode == 0;
	}

	static function main():Void {
		var r = new TestRunner();

		r.add(new TestSemVer());
		r.add(new TestData());
		r.add(new TestRemoveSymlinks());
		r.add(new TestRemoveSymlinksBroken());

		var isCI = Sys.getEnv("CI") != null;

		if (isCI || cmdSucceed("hg", ["version"])) {
			// Hg impl. suports tags & revs. Here "78edb4b" is a first revision "initial import" at that repo:
			r.add(new TestHg());
		} else {
			Sys.println("hg not found.");
		}
		if (isCI || cmdSucceed("git", ["version"])) {
			// Git impl. suports only tags. Here "0.9.2" is a first revision too ("initial import"):
			r.add(new TestGit());
		} else {
			Sys.println("git not found.");
		}
		r.add(new TestVcsNotFound());

		var success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}