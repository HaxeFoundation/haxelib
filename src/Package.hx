import haxe.crypto.Crc32;
import haxe.zip.Entry;
import haxe.zip.Writer;
import haxe.zip.Tools;

import sys.io.File;
import sys.FileSystem;
import haxelib.client.Main.VERSION;
import haxelib.Data.Infos;

using StringTools;

class Package {
    static var outPath = "package.zip";

    static function main() {
        checkVersion();

        var entries = new List<Entry>();

        function add(path:String, ?target:String) {
            if (!FileSystem.exists(path))
                throw 'Invalid path: $path';

            if (target == null)
                target = path;

            if (FileSystem.isDirectory(path)) {
                for (item in FileSystem.readDirectory(path))
                    add(path + "/" + item, target + "/" + item);
            } else {
                Sys.println("Adding " + target);
                var bytes = File.getBytes(path);
                var entry:Entry = {
                    fileName: target,
                    fileSize: bytes.length,
                    fileTime: FileSystem.stat(path).mtime,
                    compressed: false,
                    dataSize: 0,
                    data: bytes,
                    crc32: Crc32.make(bytes),
                }
                Tools.compress(entry, 9);
                entries.add(entry);
            }
        }

        for (file in FileSystem.readDirectory("src/haxelib"))
            if (file != "server")
                add('src/haxelib/$file');

        add("haxelib.json");
        add("run.n");
        add("README.md");

        Sys.println("Saving to " + outPath);
        var out = File.write(outPath, true);
        var writer = new Writer(out);
        writer.write(entries);
        out.close();
    }

    static function checkVersion() {
        var runVersion = {
            var p = new sys.io.Process("neko", ["run.n", "version"]);
            var v = p.stdout.readAll().toString().trim();
            p.close();
            v;
        }
        var json:Infos = haxe.Json.parse(sys.io.File.getContent("haxelib.json"));
        if (!runVersion.startsWith(json.version + " ")) {
            Sys.println('Error: Version in haxelib.json (${json.version}) does not match `neko run.n version` ($runVersion)');
            Sys.exit(1);
        }
        if (runVersion.indexOf("dirty") >= 0) {
            Sys.println('Error: run.n was compiled with dirty source');
            Sys.exit(1);
        }
    }
}
