package;

import sys.FileSystem;

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
		var output = sys.io.File.write(path + '.zip', true);
		var writer = new haxe.zip.Writer(output);
		var entries = new List<haxe.zip.Entry>();
		for (file in files) {
			var data = sys.io.File.getBytes(path + '/' + file);
			entries.add({
				fileTime: Date.now(),
				compressed: false,
				data: data,
				crc32: haxe.crypto.Crc32.make(data),
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
		deleteFolderContent(serverPath+ 'files');
		deleteFolderContent(serverPath+ 'tmp');
		
		Sys.println("Cleaning DB");
		var sqlFile = serverPath + 'haxelib.db';
		var con = sys.db.Sqlite.open(sqlFile);
		tools.haxelib.SiteDb.create(con);

		Sys.println("Package testing libraries");
		var libraries = new List<String>();
		var testFolder = Sys.getCwd() + 'testing/';
		for (file in FileSystem.readDirectory(testFolder + 'libraries')) {
			if (FileSystem.isDirectory(testFolder + 'libraries/' + file) && StringTools.startsWith(file, 'lib')) {
				packageLibrary(testFolder + 'libraries/' + file);
				Sys.println("Packaged libray: " + file.substr(3));
				libraries.push(file.substr(3));
			}
		}

		Sys.println("Submitting test libraries");
		var site = new SiteProxy(haxe.remoting.HttpConnection.urlConnect('http://localhost:2000/').api);
		for (library in libraries) {
			Sys.println("Submitting library: " + library);
			site.register(library, library, library+'@example.org', library + ' Developer');
			// TODO: This is not how haxelib usually behave, do we need dependencies checks and all the other stuff?
			site.checkDeveloper(library,library);
			var data = sys.io.File.getBytes(testFolder + 'libraries/lib' + library + '.zip');
			var id = site.getSubmitId();
			var h = new haxe.Http('http://localhost:2000/');
			h.fileTransfert("file",id,new haxe.io.BytesInput(data),data.length);
			h.request(true);
			site.processSubmit(id,library,library);
		}

	}
}