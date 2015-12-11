import haxelib.Vcs.VcsID;
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

	static function zipDir(dir:String, outPath:String):Void {
		var entries = new List<haxe.zip.Entry>();

		function add(path:String, target:String) {
			if (!FileSystem.exists(path))
				throw 'Invalid path: $path';

			if (FileSystem.isDirectory(path)) {
				for (item in FileSystem.readDirectory(path))
					add(path + "/" + item, target == "" ? item : target + "/" + item);
			} else {
				var bytes = File.getBytes(path);
				var entry:haxe.zip.Entry = {
					fileName: target,
					fileSize: bytes.length,
					fileTime: FileSystem.stat(path).mtime,
					compressed: false,
					dataSize: 0,
					data: bytes,
					crc32: haxe.crypto.Crc32.make(bytes),
				}
				haxe.zip.Tools.compress(entry, 9);
				entries.add(entry);
			}
		}
		add(dir, "");

		var out = File.write(outPath, true);
		var writer = new haxe.zip.Writer(out);
		writer.write(entries);
		out.close();
	}

	static function prepare():Void {
		runCommand("haxe", ["--run", "Package"]);

		/*
			(re)package the dummy libraries
		*/
		for (item in FileSystem.readDirectory("test/libraries")) {
			if (!item.startsWith("lib") || item.endsWith(".zip"))
				continue;
			zipDir('test/libraries/${item}', 'test/libraries/${item}.zip');
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
		r.add(new TestVcs(VcsID.Hg, "Mercurial", "https://bitbucket.org/fzzr/hx.signal", "78edb4b"));
		// Git impl. suports only tags. Here "0.9.2" is a first revision too ("initial import"):
		r.add(new TestVcs(VcsID.Git, "Git", "https://github.com/fzzr-/hx.signal.git", "0.9.2"));
		r.add(new TestVcsNotFound());
		r.add(new TestCli());

		var success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}