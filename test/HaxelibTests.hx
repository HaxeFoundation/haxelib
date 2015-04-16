import tools.haxelib.Vcs;
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

	static function prepare():Void {
		runCommand("haxe", ["--run", "Package"]);

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
			switch (Sys.systemName()) {
				case "Linux", "Mac":
					runCommand("zip", ["-r", '../${item}.zip', "."]);
				case "Windows":
					runCommand("7za", ["a", "-tzip", "-r", '../${item}.zip', "."]);
			}
			
			Sys.setCwd('../../..');
		}
	}

	static function main():Void {
		prepare();

		var r = new TestRunner();

		r.add(new TestSemVer());
		r.add(new TestData());
		r.add(new TestRemoveSymlinks("symlinks"));
		r.add(new TestRemoveSymlinks("symlinks-broken"));

		// Testing VCS on two identical repositories:
		// Hg:  https://bitbucket.org/fzzr/hx.signal
		// Git: https://github.com/fzzr-/hx.signal.git

		// Hg impl. suports tags & revs. Here "78edb4b" is a first revision "initial import" at that repo:
		r.add(new TestVcs(tools.haxelib.Vcs.VcsID.Hg, "Mercurial", "https://bitbucket.org/fzzr/hx.signal", "78edb4b"));
		// Git impl. suports only tags. Here "0.9.2" is a first revision too ("initial import"):
		r.add(new TestVcs(tools.haxelib.Vcs.VcsID.Git, "Git", "https://github.com/fzzr-/hx.signal.git", "0.9.2"));
		r.add(new TestVcsNotFound());
		r.add(new TestCli());

		var success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}