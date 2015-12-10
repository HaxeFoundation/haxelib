package haxelib;

import haxe.io.Path;
import sys.FileSystem;

class FsUtils {
    static var IS_WINDOWS = (Sys.systemName() == "Windows");

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
