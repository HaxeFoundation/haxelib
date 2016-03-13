package website;

import website.controller.*;
import ufront.mailer.*;
import ufront.MVC;
import sys.db.*;

import haxelib.server.SiteDb;
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
			logFile: "logs/haxelib.log",
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
		if( !sys.FileSystem.exists(TMP_DIR) )
			sys.FileSystem.createDirectory(TMP_DIR);
		if( !sys.FileSystem.exists(REP_DIR) )
			sys.FileSystem.createDirectory(REP_DIR);
		var file = null;
		var sid = null;
		var bytes = 0;
		//RAPTORS: the whole handling for nekotools is seriously evil
		if (Sys.executablePath().indexOf('nekotools') == -1)
			neko.Web.parseMultipart(function(p,filename) {
				if( p == "file" ) {
					sid = Std.parseInt(filename);
					file = sys.io.File.write(TMP_DIR+"/"+sid+".tmp",true);
				} else
					throw p+" not accepted";
			},function(data,pos,len) {
				bytes += len;
				file.writeFullBytes(data,pos,len);
			});
		else {
			var post = neko.Web.getPostData();
			if (post != null) {
				var index = post.indexOf('PK');
				if (index == -1)
					throw 'Invalid Zip - or so I claim';

				var start = post.substr(0, index);
				var data = post.substr(index);

				sid = Std.parseInt(start.split('filename="').pop());
				file = sys.io.File.write(TMP_DIR + "/" + sid + ".tmp", true);
				bytes = data.length;//thank got neko does not use utf8
				file.writeString(data);
			}
		}
		if( file != null ) {
			file.close();
			neko.Lib.print("File #"+sid+" accepted : "+bytes+" bytes written");
			return true;
		}
		return false;
	}
}
