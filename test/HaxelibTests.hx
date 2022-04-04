import haxe.unit.TestRunner;
import sys.FileSystem;
import sys.io.Process;

import tests.*;

using StringTools;

class HaxelibTests {
	public static function runCommand(cmd:String, args:Array<String>):Void {
		Sys.println('Command: $cmd $args');

		final exitCode = Sys.command(cmd, args);

		Sys.println('Command exited with $exitCode: $cmd $args');

		if(exitCode != 0)
			Sys.exit(exitCode);
	}

	static function cmdSucceed(cmd:String, ?args:Array<String>):Bool {
		final p = try {
			new Process(cmd, args);
		} catch(e:Dynamic) {
			return false;
		}
		final exitCode = p.exitCode();
		p.close();
		return exitCode == 0;
	}

	static public function deleteDirectory(dir:String) {
		if (!FileSystem.exists(dir)) return;
		final exitCode = switch (Sys.systemName()) {
			case "Windows":
				Sys.command("rmdir", ["/S", "/Q", StringTools.replace(FileSystem.fullPath(dir), "/", "\\")]);
			case _:
				Sys.command("rm", ["-rf", dir]);
		}
		if (exitCode != 0) {
			throw 'unable to delete $dir';
		}
	}

	static function main():Void {
		final r = new TestRunner();

		r.add(new TestSemVer());
		r.add(new TestData());
		r.add(new TestRemoveSymlinks());
		r.add(new TestRemoveSymlinksBroken());

		final isCI = Sys.getEnv("CI") != null;

		// The test repo https://bitbucket.org/fzzr/hx.signal is gone.
		// if (isCI || cmdSucceed("hg", ["version"])) {
		// 	// Hg impl. suports tags & revs. Here "78edb4b" is a first revision "initial import" at that repo:
		// 	TestHg.init();
		// 	r.add(new TestHg());
		// } else {
		// 	Sys.println("hg not found.");
		// }
		if (isCI || cmdSucceed("git", ["version"])) {
			// Git impl. suports only tags. Here "0.9.2" is a first revision too ("initial import"):
			TestGit.init();
			r.add(new TestGit());
		} else {
			Sys.println("git not found.");
		}
		r.add(new TestVcsNotFound());

		r.add(new TestInstall());
		r.add(new TestRepoManager());
		r.add(new TestArgs());

		final success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}
