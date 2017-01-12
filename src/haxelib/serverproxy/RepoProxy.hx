package haxelib.serverproxy;
import haxe.Http;
import haxe.Log;
import haxe.PosInfos;
import haxe.Utf8;
import haxe.io.*;
import haxe.web.Request;
import neko.Web;
import sys.io.*;
import sys.*;

import haxelib.Data;
import haxelib.SemVer;
import haxelib.server.Paths;
import haxelib.server.Paths.*;
import haxelib.server.SiteDb;
import haxelib.server.Repo;
import haxelib.server.FileStorage;


class SiteProxy extends haxe.remoting.Proxy<haxelib.SiteApi> {
}

class RepoProxy extends Repo
{

	var parentProxy:SiteProxy;

	static function runProxy() 
	{
		var parentServer = Sys.getEnv("PARENT_SERVER");
		var repo = new RepoProxy(parentServer);
		var ctx = new haxe.remoting.Context();
		ctx.addObject("api", repo);

		if ( haxe.remoting.HttpConnection.handleRequest(ctx) ){
			return;
		}
		else
		{
			switch(neko.Web.getURI().split("/").filter(function(s) return !(s == null || s == "")))
			{
				case ['files', '3.0', file]:
					trace("requesting file: " + file);
					
					var tmpFilePath = Path.join([CWD, 'files', '3.0', file]);
					
					if (FileSystem.exists(tmpFilePath))
					{
						var f = File.read(tmpFilePath);
						Sys.print(f.readAll());
						f.close();
						return;
					}
					else if(parentServer != null)
					{
						
						var sid = repo.getSubmitId();
						var tmpFileName = sid + ".tmp";
						tmpFilePath = Path.join([TMP_DIR, tmpFileName]);
						FileSystem.createDirectory(Path.directory(tmpFilePath));
						
						var out = try File.append(tmpFilePath,true) catch (e:Dynamic) throw 'Failed to write to $tmpFilePath: $e';
						out.seek(0, SeekEnd);
						
						var h = new Http(addFinalSlash(parentServer) + Data.REPOSITORY + "/" + file);
						if (haxe.remoting.HttpConnection.TIMEOUT == 0)
							h.cnxTimeout = 0;
						
						var has416Status = false;
						h.onStatus = function(status) {
							// 416 Requested Range Not Satisfiable, which means that we probably have a fully downloaded file already
							if (status == 416) has416Status = true;
						};
						h.onError = function(e) {
							out.close();

							// if we reached onError, because of 416 status code, it's probably okay and we should try unzipping the file
							if (!has416Status) {
								FileSystem.deleteFile(tmpFilePath);
								throw e;
							}
						};
						trace("Downloading "+file+"...");
						h.customRequest(false, out);
						
						var file = try sys.io.File.read(tmpFilePath, true) catch ( e : Dynamic ) throw "Invalid file id #" + sid;
						var bytes = file.readAll();
						file.seek(0, FileSeek.SeekBegin);
						var zip = try haxe.zip.Reader.readZip(file) catch( e : Dynamic ) { file.close(); neko.Lib.rethrow(e); };
						file.close();
						
						FileStorage.instance.importFile(tmpFilePath, Path.join([TMP_DIR_NAME, tmpFileName]), true);
						
						repo.submitHelper = new ProxySubmitHelper();
						repo.processSubmit(sid, null, null);
						
						Sys.print(bytes);
						
					}
				case ['index.n']:
					processFileUpload();
				case _:
					throw "Invalid remoting call";
			}
		}
		
	}
	
	static function processFileUpload()
	{
		var boundary = Web.getClientHeaders()
			.filter(function(h:{value:String, header:String}) return (h.header == "Content-Type"))
			.first().value.split("boundary=")[1];
			
		var data = Web.getPostData().split(boundary);
		data = data.filter(function(s) return (s != null && s != "" && s != "--"));
		
		var fileContent = data[0];
		
		var sid = null;
		var lines = ~/\r?\n/.split(fileContent).map(function (line){
			if (line.indexOf("Content-Disposition") >= 0)
			{
				line.split(" ").map(function (s){
					if (s.indexOf("filename") == 0) sid = s.split("\"")[1];
				});
			}
		});
		
		if (sid == null || Std.string(Std.parseInt(sid)) != sid) throw "Invalid filename";
		
		var zipHeader = new Utf8();
		zipHeader.addChar(0x50);
		zipHeader.addChar(0x4b);
		zipHeader.addChar(0x03);
		zipHeader.addChar(0x04);
		
		var beginning = fileContent.indexOf(zipHeader.toString());
		if (beginning == -1) throw "Invalid zip file";
		
		var bytes = Bytes.ofString(fileContent.substr(beginning));
		if (bytes == null || bytes.length == 0) throw "Invalid file";
		
		var tmpFileName = sid + ".tmp";
		var tmpFilePath = Path.join([TMP_DIR, tmpFileName]);
		FileSystem.createDirectory(Path.directory(tmpFilePath));
		var tmpFile = sys.io.File.write(tmpFilePath, true);
		tmpFile.writeBytes(bytes, 0, bytes.length);
		tmpFile.close();
		
		FileStorage.instance.importFile(tmpFilePath, Path.join([TMP_DIR_NAME, tmpFileName]), true);
		trace("File #"+sid+" accepted : "+bytes.length+" bytes written");
	}
	
	static inline function addFinalSlash(url:String):String
	{
		if (url.charAt(url.length - 1) != "/") url = url + "/";
		return url;
	}
	
	public function new(?parentServer:String) {
		super();
		if (parentServer != null)
		{
			parentServer = addFinalSlash(parentServer);
			var parentApiUrl = parentServer + "api/3.0/index.n";
			parentProxy = new SiteProxy(haxe.remoting.HttpConnection.urlConnect(parentApiUrl).api);
		}
	}
	
	override public function search(word:String):List<{id:Int, name:String}> 
	{
		var result = super.search(word);
		if ((result == null || result.length == 0) && parentProxy != null)
		{
			result = parentProxy.search(word);
		}
		return result;
	}
	
	override public function infos(project:String):ProjectInfos 
	{
		var infos = null;
		try
		{
			infos = super.infos(project);
		}
		catch (e:Dynamic)
		{
			if (parentProxy != null)
			{
				infos = parentProxy.infos(project);
			}
			else
			{
				neko.Lib.rethrow(e);
			}
		}
		return infos;
	}
	
	override public function getLatestVersion(project:String):SemVer 
	{
		var result = null;
		try
		{
			result = super.getLatestVersion(project);
		}
		catch (e:Dynamic)
		{
			if (parentProxy != null)
			{
				result = parentProxy.getLatestVersion(project);
			}
			else
			{
				neko.Lib.rethrow(e);
			}
		}
		return result;
	}
	
	
	
	static function main() {
		Log.trace = function (m:Dynamic, ?i:PosInfos) {
			Web.logMessage(Std.string(m));
		}
		var error = null;
		SiteDb.init();
		try {
			runProxy();
		} catch( e : Dynamic ) {
			error = { e : e };
		}
		SiteDb.cleanup();
		if( error != null )
			neko.Lib.rethrow(error.e);
	}
	
}


class ProxySubmitHelper implements ISubmitHelper
{
	public function new (){};
	
	public function checkSubmitRights(user:User, pass:String):Bool 
	{
		return true;
	}
	
	public function getContributors(ids:Array<String>):Array<User> 
	{
		return ids.map(function(user) {
			var u = User.manager.search({ name : user }).first();
			if (u == null)
				u = makeUser(user);
			return u;
		});
	}
	
	public function getUser(infos:Infos, user:String):User
	{
		var u = User.manager.search({ name : infos.contributors[0] }).first();
		if (u == null)
			u = makeUser(infos.contributors[0]);
		return u;
	}
	
	function makeUser(user:String):User
	{
		var u = new User();
		u.name = user;
		u.fullname = user;
		u.email = '$user@dummy.com';
		u.pass = user;
		u.insert();
		return u;
	}
}