import sys.*;
import sys.io.*;
import haxe.io.*;
using StringTools;

class Prepare {
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

	static function main():Void {
		/*
			(re)package the dummy libraries
		*/
		var libsPath = "test/libraries";
		for (item in FileSystem.readDirectory(libsPath)) {
			var path = Path.join([libsPath, item]);
			if (FileSystem.isDirectory(path)) {
				zipDir(path, 'test/libraries/${item}.zip');
			}
		}
	}
}