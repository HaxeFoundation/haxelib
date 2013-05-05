package;

import haxe.crypto.Crc32;
import haxe.io.BytesInput;
import haxe.remoting.HttpConnection;
import haxe.zip.Entry;
import haxe.zip.Writer;
import sys.db.Sqlite;
import sys.FileSystem;
import sys.io.File;
import tools.haxelib.SiteDb;

using StringTools;

class SiteProxy extends haxe.remoting.Proxy<tools.haxelib.SiteApi> {
}

class PrepareServer {


	static function deleteFolderContent(path:String) {
		for (file in FileSystem.readDirectory(path)) {
			var fullPath = path + '/' + file;
			if (FileSystem.isDirectory(fullPath)) {
				deleteFolderContent(fullPath);
				FileSystem.deleteDirectory(fullPath);
			}
			else {
				FileSystem.deleteFile(fullPath);
			}
		}
	}

	static function getFileList(path:String):List<String> {
		var list = new List<String>();
		for (file in FileSystem.readDirectory(path)) {
			if (FileSystem.isDirectory(path + '/' + file)) {
				for (sFile in getFileList(path + '/' + file)) {
					list.add(file + '/' + sFile);
				}
			}
			else {
				list.add(file);
			}
		}
		return list;
	}

	static function packageLibrary(path:String) {
		var files = getFileList(path);
		var fileName = path + '.zip';
		if (FileSystem.exists(fileName))
			FileSystem.deleteFile(fileName);
		var output = File.write(path + '.zip', true);
		var writer = new Writer(output);
		var entries = new List<Entry>();
		for (file in files) {
			var data = File.getBytes(path + '/' + file);
			entries.add({
				fileTime: Date.now(),
				compressed: false,
				data: data,
				crc32: Crc32.make(data),
				dataSize: data.length,
				fileName: file,
				fileSize: 0
			});
		}
		writer.write(entries);
		output.flush();
		output.close();

	}

	static function main() {
		Sys.println("Cleaning up folders");
		var serverPath = Sys.getCwd() + 'server/';
		if (FileSystem.exists(serverPath + 'files') && FileSystem.isDirectory(serverPath + 'files'))
			deleteFolderContent(serverPath + 'files');
		if (FileSystem.exists(serverPath + 'tmp') && FileSystem.isDirectory(serverPath + 'tmp'))
		deleteFolderContent(serverPath + 'tmp');
		
		Sys.println("Cleaning legacy DB");
		var sqlFile = serverPath + 'legacy/haxelib.db';
		var con = Sqlite.open(sqlFile);
		tools.legacyhaxelib.SiteDb.create(con);

		Sys.println("Package testing libraries");
		var libraries = new List<String>();
		var testFolder = Sys.getCwd() + 'testing/';
		for (file in FileSystem.readDirectory(testFolder + 'libraries')) {
			if (FileSystem.isDirectory(testFolder + 'libraries/' + file) && file.startsWith('lib')) {
				packageLibrary(testFolder + 'libraries/' + file);
				Sys.println("Packaged libray: " + file.substr(3));
				libraries.push(file.substr(3));
			}
		}

		Sys.println("Submitting test libraries");
		try {
			var sites = [
				'legacy' => 'http://localhost:2000/',
				'2.0.0-rc' => 'http://localhost:2000/api/2.0.0-rc/',
			];
			for (siteName in sites.keys()) {
				trace('Test $siteName on ' + sites.get(siteName));
				var site = new SiteProxy(HttpConnection.urlConnect(sites.get(siteName)).api);
				for (library in libraries) {
					Sys.println("Submitting library: " + library);
					site.register(library, library, library+'@example.org', library + ' Developer');
					// TODO: This is not how haxelib usually behave, do we need dependencies checks and all the other stuff?
					site.checkDeveloper(library, library);
					var libraryFile = testFolder + 'libraries/lib' + library + '.zip';
					var data = File.getBytes(libraryFile);
					var id = site.getSubmitId();
					var h = new haxe.Http('http://localhost:2000/');
					h.fileTransfert("file", id, new BytesInput(data), data.length);
					h.request(true);
					site.processSubmit(id, library, library);
					//FileSystem.deleteFile(libraryFile);
				}				
			}
		}
		catch (e:Dynamic) {
			Sys.println("There was a problem submitting test libraries to the local haxelib server. Make sure it is running.");
			Sys.println(e);
			Sys.exit(1);
		}

	}
}