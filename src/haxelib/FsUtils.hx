/*
 * Copyright (C)2005-2015 Haxe Foundation
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
package haxelib;

import haxe.io.Path;
import sys.FileSystem;
using StringTools;

class FsUtils {
    static var IS_WINDOWS = (Sys.systemName() == "Windows");

    //recursively follow symlink
    public static function realPath(path:String):String {
        var proc = new sys.io.Process('readlink', [path.endsWith("\n") ? path.substr(0, path.length-1) : path]);
        return switch (proc.stdout.readAll().toString()) {
            case "": //it is not a symlink
                path;
            case targetPath:
                if (targetPath.startsWith("/")) {
                    realPath(targetPath);
                } else {
                    realPath(new Path(path).dir + "/" + targetPath);
                }
        }
    }

    public static function safeDir(dir:String):Void {
        if (FileSystem.exists(dir)) {
            if (!FileSystem.isDirectory(dir))
                throw 'A file is preventing $dir to be created';
        }
        try {
            FileSystem.createDirectory(dir);
        } catch( e : Dynamic ) {
            throw 'You don\'t have enough user rights to create the directory $dir';
        }
    }

    public static function deleteRec(dir:String):Void {
        if (!FileSystem.exists(dir))
            return;
        for (p in FileSystem.readDirectory(dir)) {
            var path = Path.join([dir, p]);

            if (isBrokenSymlink(path)) {
                safeDelete(path);
            } else if (FileSystem.isDirectory(path)) {
                // if isSymLink:
                if (!IS_WINDOWS && path != FileSystem.fullPath(path))
                    safeDelete(path);
                else
                    deleteRec(path);
            } else {
                safeDelete(path);
            }
        }
        FileSystem.deleteDirectory(dir);
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
        var errors = 0;
        function isNeeded(error:String):Bool
        {
            return switch(error)
            {
                case "std@sys_file_type" |
                     "std@file_full_path": true;
                default: false;
            }
        }

        try{ FileSystem.isDirectory(path); }
        catch(error:String)
            if(isNeeded(error))
                errors++;

        try{ FileSystem.fullPath(path); }
        catch(error:String)
            if(isNeeded(error))
                errors++;

        return errors == 2;
    }

}
