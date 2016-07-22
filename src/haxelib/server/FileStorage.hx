/*
 * Copyright (C)2005-2016 Haxe Foundation
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
package haxelib.server;

import sys.FileSystem;
import sys.io.*;
import haxe.io.Path;
import haxelib.server.Paths;
import neko.Web;
using Lambda;

/**
	`FileStorage` is an abstraction to a file system.
	It maps relative paths to absolute paths, effectively hides the actual location of the storage.
*/
class FileStorage {
	/**
		An static instance of `FileStorage` that everyone use.
		One should not create their own instance of `FileStorage` except when testing.

		When both the enviroment variables, HAXELIB_S3BUCKET and AWS_DEFAULT_REGION, are set,
		`instance` will be a `S3FileStorage`. Otherwise, it will be a `LocalFileStorage`.
	*/
	static public var instance(get, null):FileStorage;
	static function get_instance() return instance != null ? instance : instance = {
		var vars = [
			Sys.getEnv("HAXELIB_S3BUCKET"),
			Sys.getEnv("AWS_DEFAULT_REGION")
		];
		switch (vars) {
			case [bucket, region] if (vars.foreach(function(v) return v != null && v != "")):
				Web.logMessage('using S3FileStorage with bucket $bucket in ${region}');
				new S3FileStorage(Paths.CWD, bucket, 'http://${bucket}.s3-website-${region}.amazonaws.com/');
			case _:
				Web.logMessage('using LocalFileStorage');
				new LocalFileStorage(Paths.CWD);
		}
	}

	/**
		Request reading `file` in the function `f`.
		`file` should be the relative path to the required file, e.g. `files/3.0/library.zip`.
		If the file does not exist, an error will be thrown, and `f` will not be called.
		If `file` exist, its abolute path will be given to `f` as input.
		It only guarantees `file` exists and the abolute path to it is valid within the call of `f`.
	*/
	public function readFile<T>(file:RelPath, f:AbsPath->T):T
		throw "should be implemented by subclass";

	/**
		Request writing `file` in the function `f`.
		`file` should be a relative path to the required file, e.g. `files/3.0/library.zip`.
		Any of the parent directories of `file` that doesn't exist will be created.
		The mapped abolute path of `file` will be given to `f` as input.
		The abolute path to `file` may and may not contain previously written file.
	*/
	public function writeFile<T>(file:RelPath, f:AbsPath->T):T
		throw "should be implemented by subclass";

	/**
		Copy existing local `srcFile` to the storage as `dstFile`.
		Existing `dstFile` will be overwritten.
		If `move` is true, `srcFile` will be deleted, unless `dstFile` happens to located
		at the same path of `srcFile`.
	*/
	public function importFile<T>(srcFile:AbsPath, dstFile:RelPath, move:Bool):Void
		throw "should be implemented by subclass";

	/**
		Delete `file` in the storage.
		It will be a no-op if `file` does not exist.
	*/
	public function deleteFile(file:RelPath):Void
		throw "should be implemented by subclass";
}

class LocalFileStorage extends FileStorage {
	/**
		The local directory of the file storage.
	*/
	public var path(default, null):AbsPath;

	/**
		Create a `FileStorage` located at a local directory specified by an absolute `path`.
	*/
	public function new(path:AbsPath):Void {
		if (!Path.isAbsolute(path))
			throw '`path` should be absolute, but $path is not.';
		this.path = path;
	}

	override public function readFile<T>(file:RelPath, f:AbsPath->T):T {
		if (Path.isAbsolute(file))
			throw 'readFile only accepts relative `file`. $file is is absolute.';
		var file:AbsPath = Path.join([path, file]);
		if (!FileSystem.exists(file))
			throw '$file does not exist.';
		return f(file);
	}

	override public function writeFile<T>(file:RelPath, f:AbsPath->T):T {
		if (Path.isAbsolute(file))
			throw 'readFile only accepts relative `file`. $file is is absolute.';
		var file:AbsPath = Path.join([path, file]);
		FileSystem.createDirectory(Path.directory(file));
		return f(file);
	}

	override public function importFile<T>(srcFile:AbsPath, dstFile:RelPath, move:Bool):Void {
		var localFile:AbsPath = Path.join([path, dstFile]);
		if (
			FileSystem.exists(localFile) &&
			FileSystem.fullPath(localFile) == FileSystem.fullPath(srcFile)
		) {
			// srcFile already located at dstFile
			return;
		}
		File.copy(srcFile, localFile);
		if (move)
			FileSystem.deleteFile(srcFile);
	}

	override public function deleteFile(file:RelPath):Void {
		var localFile:AbsPath = Path.join([path, file]);
		if (FileSystem.exists(localFile))
			FileSystem.deleteFile(localFile);
	}
}

class S3FileStorage extends FileStorage {
	/**
		The local directory for caching.
	*/
	public var localPath(default, null):AbsPath;

	/**
		The S3 bucket name.
	*/
	public var bucketName(default, null):String;

	/**
		The public endpoint of the S3 bucket.
		e.g. 'http://${bucket}.s3-website-${region}.amazonaws.com/'
	*/
	public var bucketEndpoint(default, null):String;

	public function new(localPath:AbsPath, bucketName:String, bucketEndpoint:String):Void {
		if (!Path.isAbsolute(localPath))
			throw '`localPath` should be absolute, but $localPath is not.';
		this.localPath = localPath;
		this.bucketName = bucketName;
		this.bucketEndpoint = bucketEndpoint;
	}

	override public function readFile<T>(file:RelPath, f:AbsPath->T):T {
		if (Path.isAbsolute(file))
			throw 'readFile only accepts relative `file`. $file is is absolute.';
		var localFile:AbsPath = Path.join([localPath, file]);
		if (!FileSystem.exists(localFile)) {
			var remoteUrl = Path.join([bucketEndpoint, file]);

			// write to a tmp location to avoid data race when
			// parallel process write to the target
			var tempPath = Path.join([Paths.TMP_DIR, Std.string(Std.random(1000)), file]);
			FileSystem.createDirectory(Path.directory(tempPath));
			var out = File.write(tempPath);
			var http = new haxe.Http(remoteUrl);
			http.noShutdown = true;
			http.customRequest(false, out);

			// in case there is another parallel process that fetched the file
			if (FileSystem.exists(localFile))
				FileSystem.deleteFile(localFile);

			// copy + delete instead of move to avoid issue when
			// the tmp directory is in a different drive then the target
			File.copy(tempPath, localFile);
			FileSystem.deleteFile(tempPath);
		}
		return f(localFile);
	}

	override public function writeFile<T>(file:RelPath, f:AbsPath->T):T {
		if (Path.isAbsolute(file))
			throw 'readFile only accepts relative `file`. $file is is absolute.';
		var localFile:AbsPath = Path.join([localPath, file]);
		FileSystem.createDirectory(Path.directory(localFile));
		var r = f(localFile);
		var s3Path = Path.join(['s3://${bucketName}', file]);
		if (Sys.command("aws", ["s3", "cp", localFile, s3Path]) != 0) {
			throw 'failed to upload ${localFile} to ${s3Path}';
		}
		return r;
	}

	override public function importFile<T>(srcFile:AbsPath, dstFile:RelPath, move:Bool):Void {
		var localFile:AbsPath = Path.join([localPath, dstFile]);
		function uploadToS3() {
			var s3Path = Path.join(['s3://${bucketName}', dstFile]);
			if (Sys.command("aws", ["s3", "cp", localFile, s3Path]) != 0)
				throw 'failed to upload ${localFile} to ${s3Path}';
		}
		if (
			FileSystem.exists(localFile) &&
			FileSystem.fullPath(localFile) == FileSystem.fullPath(srcFile)
		) {
			// srcFile already located at dstFile
			uploadToS3();
			return;
		}
		File.copy(srcFile, localFile);
		uploadToS3();
		if (move)
			FileSystem.deleteFile(srcFile);
	}

	override public function deleteFile(file:RelPath):Void {
		var localFile:AbsPath = Path.join([localPath, file]);
		if (FileSystem.exists(localFile))
			FileSystem.deleteFile(localFile);
		var s3Path = Path.join(['s3://${bucketName}', file]);
		if (Sys.command("aws", ["s3", "ls", localFile, s3Path]) == 0)
		if (Sys.command("aws", ["s3", "rm", s3Path]) != 0)
			throw 'failed to delete ${s3Path}';
	}
}