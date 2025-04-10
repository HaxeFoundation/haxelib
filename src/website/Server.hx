package website;

import website.cache.DummyCache;
import website.controller.*;
import ufront.mailer.*;
import ufront.MVC;
import sys.*;
import sys.db.*;
import sys.io.*;
import haxe.io.*;

import haxelib.server.*;
import haxelib.server.Paths.*;

class Server {
	static var ufApp:UfrontApplication;

	static function main() {
		// this is a temporary fix from https://github.com/dpeek/haxe-markdown/pull/26
		@:privateAccess markdown.BlockParser.TableSyntax.TABLE_PATTERN = new EReg('^(.+?:?\\|:?)+(.+)$', '');

		ufApp = new UfrontApplication({
			indexController: HomeController,
			templatingEngines: [TemplatingEngines.erazor],
			defaultLayout: "layout.html",
			// logFile: "logs/haxelib.log",
			sessionImplementation: VoidSession,
			authImplementation: NobodyAuthHandler,
			contentDirectory: "../uf-content/",
			requestMiddleware: [],
			responseMiddleware: [],
		});
		ufApp.injector.map( String, "documentationPath" ).toValue( neko.Web.getCwd()+"documentation-files/" );

		ufApp.injector.map( UFCacheConnectionSync ).toClass( DBCacheConnection );
		ufApp.injector.map( UFCacheConnection ).toClass( DBCacheConnection );
		// var cacheMiddleware = new RequestCacheMiddleware();
		// ufApp.addRequestMiddleware( cacheMiddleware, true ).addResponseMiddleware( cacheMiddleware, true );

		// If we're on neko, and using the module cache, next time jump straight to the main request.
		#if (neko && !debug)
			neko.Web.cacheModule(run);
		#end

		// Execute the main request.
		run();
	}

	static function run() {
		var wasUpload = handleHaxelibUpload();
		if ( wasUpload==false ) {
			SiteDb.init();
			ufApp.executeRequest();
			SiteDb.cleanup();
		}
	}

	static function handleHaxelibUpload():Bool {
		var tmpFile = null;
		var tmpFileName = null;
		var tmpFilePath = null;
		var sid = null;
		var bytes = 0;
		neko.Web.parseMultipart(function(p,fileName) {
			if( p == "file" ) {
				sid = Std.parseInt(fileName);
				tmpFilePath = Path.join([TMP_DIR, tmpFileName = sid+".tmp"]);
				FileSystem.createDirectory(Path.directory(tmpFilePath));
				tmpFile = sys.io.File.write(tmpFilePath, true);
			} else
				throw p+" not accepted";
		},function(data,pos,len) {
			bytes += len;
			tmpFile.writeFullBytes(data,pos,len);
		});
		if( tmpFile != null ) {
			tmpFile.close();

			// directly upload the file to bucket with rclone instead of going through s3fs and minio
			// https://github.com/HaxeFoundation/haxelib/issues/589
			var storage = switch [Sys.getEnv("HAXELIB_S3BUCKET"), Sys.getEnv("AWS_DEFAULT_REGION"), Sys.getEnv("HAXELIB_S3BUCKET_ENDPOINT")] {
				case [null, _, _] | [_, null, _] | [_, _, null]:
					neko.Web.logMessage('using FileStorage.instance');
					FileStorage.instance;
				case [bucket, region, endpoint]:
					neko.Web.logMessage('using S3FileStorage with bucket $bucket in ${region} ${endpoint}');
					new haxelib.server.FileStorage.S3FileStorage(Paths.CWD, bucket, region, endpoint);
			}
			storage.importFile(tmpFilePath, Path.join([TMP_DIR_NAME, tmpFileName]), true);

			neko.Lib.print("File #"+sid+" accepted : "+bytes+" bytes written");
			return true;
		}
		return false;
	}
}
