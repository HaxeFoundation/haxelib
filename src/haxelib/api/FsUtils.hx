/*
 * Copyright (C)2005-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package haxelib.api;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.zip.Tools;

using StringTools;

/** Class containing useful FileSystem utility functions. **/
@:noDoc
class FsUtils {
	public static final IS_WINDOWS = (Sys.systemName() == "Windows");
    /**
        Recursively follow symlink

        TODO: this method does not (yet) work on Windows
    */
    public static function realPath(path:String):String {
        final proc = new sys.io.Process('readlink', [path.endsWith("\n") ? path.substr(0, path.length-1) : path]);
        final ret = switch (proc.stdout.readAll().toString()) {
            case "": //it is not a symlink
                path;
            case targetPath:
                if (targetPath.startsWith("/")) {
                    realPath(targetPath);
                } else {
                    realPath(new Path(path).dir + "/" + targetPath);
                }
        }
        proc.close();
        return ret;
    }

    public static function isSamePath(a:String, b:String):Bool {
        a = Path.normalize(a);
        b = Path.normalize(b);
        if (IS_WINDOWS) { // paths are case-insensitive on Windows
            a = a.toLowerCase();
            b = b.toLowerCase();
        }
        return a == b;
    }

    public static function safeDir(dir:String, checkWritable = false):Bool {
        if (FileSystem.exists(dir)) {
            if (!FileSystem.isDirectory(dir)) {
                try {
                    // if this call is successful then 'dir' it is not a file but a symlink to a directory
                    FileSystem.readDirectory(dir);
                } catch (ex:Dynamic) {
                    throw 'A file is preventing the required directory $dir to be created';
                }
            }
            if (checkWritable) {
                final checkFile = dir + "/haxelib_writecheck.txt";
                try {
                    sys.io.File.saveContent(checkFile, "This is a temporary file created by Haxelib to check if directory is writable. You can safely delete it!");
                } catch (_:Dynamic) {
                    throw '$dir exists but is not writeable, chmod it';
                }
                FileSystem.deleteFile(checkFile);
            }
            return false;
        } else {
            try {
                FileSystem.createDirectory(dir);
                return true;
            } catch (_:Dynamic) {
                throw 'You don\'t have enough user rights to create the directory $dir';
            }
        }
    }

    public static function deleteRec(dir:String):Bool {
        if (!FileSystem.exists(dir))
            return false;
        for (p in FileSystem.readDirectory(dir)) {
            final path = Path.join([dir, p]);

            if (isBrokenSymlink(path)) {
                safeDelete(path);
            } else if (FileSystem.isDirectory(path)) {
                if (!IS_WINDOWS) {
                    // try to delete it as a file first - in case of path
                    // being a symlink, it will success
                    if (!safeDelete(path))
                        deleteRec(path);
                } else {
                    deleteRec(path);
                }
            } else {
                safeDelete(path);
            }
        }
        FileSystem.deleteDirectory(dir);
        return true;
    }

    static function safeDelete(file:String):Bool {
        try {
            FileSystem.deleteFile(file);
            return true;
        } catch (e:Dynamic) {
            if (IS_WINDOWS) {
                try {
                    Sys.command("attrib", ["-R", file]);
                    FileSystem.deleteFile(file);
                    return true;
                } catch (_:Dynamic) {
                }
            }
            return false;
        }
    }

    static function isBrokenSymlink(path:String):Bool {
        // TODO: figure out what this method actually does :)
        var errors = 0;
        try FileSystem.isDirectory(path) catch (error:String) if (error == "std@sys_file_type") errors++;
        try FileSystem.fullPath(path) catch (error:String) if (error == "std@file_full_path") errors++;
        return errors == 2;
    }

	public static function getHomePath():String {
		var home:String = null;
		if (IS_WINDOWS) {
			home = Sys.getEnv("USERPROFILE");
			if (home == null) {
				final drive = Sys.getEnv("HOMEDRIVE");
				final path = Sys.getEnv("HOMEPATH");
				if (drive != null && path != null)
					home = drive + path;
			}
			if (home == null)
				throw "Could not determine home path. Please ensure that USERPROFILE or HOMEDRIVE+HOMEPATH environment variables are set.";
		} else {
			home = Sys.getEnv("HOME");
			if (home == null)
				throw "Could not determine home path. Please ensure that HOME environment variable is set.";
		}
		return home;
	}

	/** Unzips the file at `filePath`, but if an error is thrown, it will safely close the file before rethrowing. **/
	public static function unzip(filePath:String):List<Entry> {
		final file = sys.io.File.read(filePath, true);
		try {
			final zip = Reader.readZip(file);
			file.close();
			return zip;
		} catch (e:Dynamic) {
			file.close();
			Util.rethrow(e);
		}
		throw '';
	}

	/** Returns absolute path, replacing `~` with homepath **/
	public static function getFullPath(path:String):String {
		final splitPath = path.split("/");
		if (splitPath.length != 0 && splitPath.shift() == "~") {
			return getHomePath() + "/" + splitPath.join("/");
		}

		return FileSystem.absolutePath(path);
	}

	public static function zipDirectory(root:String):List<Entry> {
		final ret = new List<Entry>();
		function seek(dir:String) {
			for (name in FileSystem.readDirectory(dir))
				if (!name.startsWith('.')) {
					final full = '$dir/$name';
					if (FileSystem.isDirectory(full))
						seek(full);
					else {
						final blob = File.getBytes(full);
						final entry:Entry = {
							fileName: full.substr(root.length + 1),
							fileSize: blob.length,
							fileTime: FileSystem.stat(full).mtime,
							compressed: false,
							dataSize: blob.length,
							data: blob,
							crc32: haxe.crypto.Crc32.make(blob),
						};
						Tools.compress(entry, 9);
						ret.push(entry);
					}
				}
		}
		seek(root);
		return ret;
	}
}
