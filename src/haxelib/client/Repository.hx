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
package haxelib.client;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
using StringTools;

import haxelib.Data;

@:allow(haxelib.client.Repository)
class Library {
	static inline var CURRENT_FILE = ".current";
	static inline var DEV_FILE = ".dev";

	public var name(default,null):String;
	var path:String;

	function new(repo:String, name:String) {
		this.name = name;
		this.path = repo + Data.safe(name) + "/";
	}

	public inline function isInstalled():Bool {
		return FileSystem.exists(path);
	}

	public inline function isVersionInstalled(version:String):Bool {
		return FileSystem.exists(getVersionPath(version));
	}

	public function getInstalledVersions():Array<String> {
		var result = [];
		for (folder in FileSystem.readDirectory(path)) {
			if (folder.charCodeAt(0) == ".".code)
				continue;
			result.push(Data.unsafe(folder));
		}
		return result;
	}

	public function getCurrentVersion():Null<String> {
		return try File.getContent(path + CURRENT_FILE).trim() catch (_:Dynamic) null;
	}

	public function setCurrentVersion(version:String):Void {
		File.saveContent(path + CURRENT_FILE, version.trim());
	}

	public function setDevPath(devPath:String):Void {
		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);

		while (devPath.endsWith("/") || devPath.endsWith("\\"))
			devPath = devPath.substr(0,-1);

		if (!FileSystem.exists(devPath))
			throw 'Directory $devPath does not exist';

		devPath = FileSystem.fullPath(devPath);

		var devFile = path + DEV_FILE;
		try {
			File.saveContent(devFile, devPath);
		} catch (e:Dynamic) {
			throw 'Could not write to $devFile: $e';
		}
	}

	public function unsetDevPath():Void {
		var devFile = path + DEV_FILE;
		if (!FileSystem.exists(devFile))
			FileSystem.deleteFile(devFile);
	}

	public function getDevPath():Null<String> {
		return try File.getContent(path + DEV_FILE).trim() catch (_:Dynamic) null;
	}

	public function remove():Void {
		if (!isInstalled())
			throw 'Library $name is not installed';
		FsUtils.deleteRec(path);
	}

	public function removeVersion(version:String):Void {
		var versionPath = getVersionPath(version);
		if (!FileSystem.exists(versionPath))
			throw 'Library $name does not have version $version installed';
		if (version == getCurrentVersion())
			throw 'Can\'t remove current version of library $name';
		FsUtils.deleteRec(versionPath);
	}

	inline function getVersionPath(version:String):String {
		return path + Data.safe(version) + "/";
	}

}

class Repository {
	public var root(default,null):String;
	var libs:Map<String,Library>;

	public function new(path:String) {
		root = Path.addTrailingSlash(path);
		libs = new Map();
	}

	public function getInstalledLibraries(?filter:String):Array<Library> {
		var folders = FileSystem.readDirectory(root);
		if (filter != null)
			folders = folders.filter(function(f) return f.toLowerCase().indexOf(filter.toLowerCase()) != -1);
		var result = [];
		for (folder in folders) {
			if (folder.charCodeAt(0) == ".".code)
				continue;
			result.push(getLibrary(Data.unsafe(folder)));
		}
		return result;
	}

	public function getLibrary(name:String):Library {
		var lib = libs[name];
		if (lib == null)
			lib = libs[name] = new Library(root, name);
		return lib;
	}

	public function installLibrary(filePath:String, ?log:String->Void):Infos {
		inline function print(s) if (log != null) log(s);

		// read zip content
		var f = File.read(filePath, true);
		var zip = haxe.zip.Reader.readZip(f);
		f.close();
		var infos = Data.readInfos(zip, false);

		// create directories
		var lib = getLibrary(infos.name);
		var target = lib.getVersionPath(infos.version);
		FsUtils.safeDir(target);

		// locate haxelib.json base path
		var basepath = Data.locateBasePath(zip);

		// unzip content
		for( zipfile in zip ) {
			var n = zipfile.fileName;
			if( !n.startsWith(basepath) )
				continue;

			// remove basepath
			n = n.substr(basepath.length,n.length-basepath.length);

			// check for hacks
			if( n.charAt(0) == "/" || n.charAt(0) == "\\" || n.split("..").length > 1 )
				throw "Invalid filename : "+n;

			var dirs = ~/[\/\\]/g.split(n);
			var path = "";
			var file = dirs.pop();
			for( d in dirs ) {
				path += d;
				FsUtils.safeDir(target+path);
				path += "/";
			}
			if( file == "" ) {
				if( path != "" ) print("  Created "+path);
				continue; // was just a directory
			}
			path += file;
			print("  Install "+path);
			var data = haxe.zip.Reader.unzip(zipfile);
			File.saveBytes(target+path,data);
		}

		return infos;
	}
}
