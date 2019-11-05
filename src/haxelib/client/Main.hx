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
package haxelib.client;

import haxelib.client.Util.*;
import haxe.crypto.Md5;
import haxe.*;
import haxe.ds.*;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.*;
import sys.io.File;
import sys.FileSystem;
import sys.io.*;
import haxe.ds.Option;
import haxelib.client.Cli.ask;
import haxelib.client.FsUtils.*;
import haxelib.client.Vcs;

using StringTools;
using Lambda;
using haxelib.Data;

private enum CommandCategory {
	Basic;
	Information;
	Development;
	Miscellaneous;
	Deprecated(msg:String);
}

class SiteProxy extends haxe.remoting.Proxy<haxelib.SiteApi> {
}

class ProgressOut extends haxe.io.Output {

	var o : haxe.io.Output;
	var cur : Int;
	var curReadable : Float;
	var startSize : Int;
	var max : Null<Int>;
	var maxReadable : Null<Float>;
	var start : Float;

	public function new(o, currentSize) {
		this.o = o;
		startSize = currentSize;
		cur = currentSize;
		start = Timer.stamp();
	}

	function report(n) {
		cur += n;

		var tag : String = ((max != null ? max : cur) / 1000000) > 1 ? "MB" : "KB";

		curReadable = tag == "MB" ? cur / 1000000 : cur / 1000;
		curReadable = Math.round( curReadable * 100 ) / 100; // 12.34 precision.

		if( max == null )
			Sys.print('${curReadable} ${tag}\r');
		else {
			maxReadable = tag == "MB" ? max / 1000000 : max / 1000;
			maxReadable = Math.round( maxReadable * 100 ) / 100; // 12.34 precision.

			Sys.print('${curReadable}${tag} / ${maxReadable}${tag} (${Std.int((cur*100.0)/max)}%)\r');
		}
	}

	public override function writeByte(c) {
		o.writeByte(c);
		report(1);
	}

	public override function writeBytes(s,p,l) {
		var r = o.writeBytes(s,p,l);
		report(r);
		return r;
	}

	public override function close() {
		super.close();
		o.close();

		var time = Timer.stamp() - start;
		var downloadedBytes = cur - startSize;
		var speed = (downloadedBytes / time) / 1000;
		time = Std.int(time * 10) / 10;
		speed = Std.int(speed * 10) / 10;

		var tag : String = (downloadedBytes / 1000000) > 1 ? "MB" : "KB";
		var readableBytes : Float = (tag == "MB") ? downloadedBytes / 1000000 : downloadedBytes / 1000;
		readableBytes = Math.round( readableBytes * 100 ) / 100; // 12.34 precision.

		Sys.println('Download complete: ${readableBytes}${tag} in ${time}s (${speed}KB/s)');
	}

	public override function prepare(m) {
		max = m + startSize;
	}

}

class ProgressIn extends haxe.io.Input {

	var i : haxe.io.Input;
	var pos : Int;
	var tot : Int;

	public function new( i, tot ) {
		this.i = i;
		this.pos = 0;
		this.tot = tot;
	}

	public override function readByte() {
		var c = i.readByte();
		report(1);
		return c;
	}

	public override function readBytes(buf,pos,len) {
		var k = i.readBytes(buf,pos,len);
		report(k);
		return k;
	}

	function report( nbytes : Int ) {
		pos += nbytes;
		Sys.print( Std.int((pos * 100.0) / tot) + "%\r" );
	}

}

class Main {
	static inline var HAXELIB_LIBNAME = "haxelib";

	static var VERSION:SemVer = SemVer.ofString(getHaxelibVersion());
	static var VERSION_LONG:String = getHaxelibVersionLong();
	static var REPNAME = "lib";
	static var REPODIR = ".haxelib";
	static var SERVER = {
		protocol : "https",
		host : "lib.haxe.org",
		port : 443,
		dir : "",
		url : "index.n",
		apiVersion : "3.0",
		noSsl : false
	};
	static var IS_WINDOWS = (Sys.systemName() == "Windows");

	var argcur : Int;
	var args : Array<String>;
	var commands : List<{ name : String, doc : String, f : Void -> Void, net : Bool, cat : CommandCategory }>;
	var siteUrl : String;
	var site : SiteProxy;
	var isHaxelibRun : Bool;
	var alreadyUpdatedVcsDependencies:Map<String,String> = new Map<String,String>();

	function new() {
		args = Sys.args();
		isHaxelibRun = (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME);

		if (isHaxelibRun)
			Sys.setCwd(args.pop());

		commands = new List();
		addCommand("install", install, "install a given library, or all libraries from a hxml file", Basic);
		addCommand("update", update, "update a single library (if given) or all installed libraries", Basic);
		addCommand("remove", remove, "remove a given library/version", Basic, false);
		addCommand("list", list, "list all installed libraries", Basic, false);
		addCommand("set", set, "set the current version for a library", Basic, false);

		addCommand("search", search, "list libraries matching a word", Information);
		addCommand("info", info, "list information on a given library", Information);
		addCommand("user", user, "list information on a given user", Information);
		addCommand("config", config, "print the repository path", Information, false);
		addCommand("path", path, "give paths to libraries' sources and necessary build definitions", Information, false);
		addCommand("libpath", libpath, "returns the root path of a library", Information, false);
		addCommand("version", version, "print the currently used haxelib version", Information, false);
		addCommand("help", usage, "display this list of options", Information, false);

		addCommand("submit", submit, "submit or update a library package", Development);
		addCommand("register", register, "register a new user", Development);
		addCommand("dev", dev, "set the development directory for a given library", Development, false);
		//TODO: generate command about VCS by Vcs.getAll()
		addCommand("git", vcs.bind(VcsID.Git), "use Git repository as library", Development);
		addCommand("hg", vcs.bind(VcsID.Hg), "use Mercurial (hg) repository as library", Development);

		addCommand("setup", setup, "set the haxelib repository path", Miscellaneous, false);
		addCommand("newrepo", newRepo, "create a new local repository", Miscellaneous, false);
		addCommand("deleterepo", deleteRepo, "delete the local repository", Miscellaneous, false);
		addCommand("convertxml", convertXml, "convert haxelib.xml file to haxelib.json", Miscellaneous);
		addCommand("run", run, "run the specified library with parameters", Miscellaneous, false);
		addCommand("proxy", proxy, "setup the Http proxy", Miscellaneous);

		// deprecated commands
		addCommand("local", local, "install the specified package locally", Deprecated("Use `haxelib install <file>` instead"), false);
		addCommand("selfupdate", updateSelf, "update haxelib itself", Deprecated('Use `haxelib --global update $HAXELIB_LIBNAME` instead'));

		initSite();
	}

	function retry<R>(func:Void -> R, numTries:Int = 3) {
		var hasRetried = false;

		while (numTries-- > 0) {
			try {
				var result = func();

				if (hasRetried) print("retry sucessful");

				return result;
			} catch (e:Dynamic) {
				if ( e == "Blocked") {
					print("Failed. Triggering retry due to HTTP timeout");
					hasRetried = true;
				}
				else {
					throw 'Failed with error: $e';
				}
			}
		}
		throw 'Failed due to HTTP timeout after multiple retries';
	}

	function checkUpdate() {
		var latest = try retry(site.getLatestVersion.bind(HAXELIB_LIBNAME)) catch (_:Dynamic) null;
		if (latest != null && latest > VERSION)
			print('\nA new version ($latest) of haxelib is available.\nDo `haxelib --global update $HAXELIB_LIBNAME` to get the latest version.\n');
	}

	function initSite() {
		siteUrl = SERVER.protocol + "://" + SERVER.host + ":" + SERVER.port + "/" + SERVER.dir;
		var remotingUrl =  siteUrl + "api/" + SERVER.apiVersion + "/" + SERVER.url;
		site = new SiteProxy(haxe.remoting.HttpConnection.urlConnect(remotingUrl).resolve("api"));
	}

	function param( name, ?passwd ) {
		if( args.length > argcur )
			return args[argcur++];
		Sys.print(name+" : ");
		if( passwd ) {
			var s = new StringBuf();
			do switch Sys.getChar(false) {
				case 10, 13: break;
				case 0: // ignore (windows bug)
				case c: s.addChar(c);
			}
			while (true);
			print("");
			return s.toString();
		}
		return Sys.stdin().readLine();
	}

	function paramOpt() {
		if( args.length > argcur )
			return args[argcur++];
		return null;
	}

	function addCommand( name, f, doc, cat, ?net = true ) {
		commands.add({ name : name, doc : doc, f : f, net : net, cat : cat });
	}

	function version() {
		var params = paramOpt();
		if ( params == null )
			print(VERSION_LONG);
		else {
			Sys.stderr().writeString('no parameters expected, got: ${params}\n');
			Sys.exit(1);
		}
	}

	function usage() {
		var cats = [];
		var maxLength = Lambda.fold(Reflect.fields(ABOUT_SETTINGS), function(opt, max) {
			var fullOption = '--' + ~/([A-Z])/g.replace(opt, "-$1").toLowerCase();
			var len = fullOption.length;
			return len > max ? len : max;
		}, 0);

		for( c in commands ) {
			if (c.name.length > maxLength) maxLength = c.name.length;
			if (c.cat.match(Deprecated(_))) continue;
			var i = c.cat.getIndex();
			if (cats[i] == null) cats[i] = [c];
			else cats[i].push(c);
		}

		print('Haxe Library Manager $VERSION - (c)2006-2019 Haxe Foundation');
		print("  Usage: haxelib [command] [options]");

		for (cat in cats) {
			print("  " + cat[0].cat.getName());
			for (c in cat) {
				print("    " + StringTools.rpad(c.name, " ", maxLength) + ": " +c.doc);
			}
		}

		print("  Available switches");
		for (f in Reflect.fields(ABOUT_SETTINGS)) {
			var option = ~/([A-Z])/g.replace(f, "-$1").toLowerCase().rpad(' ', maxLength-2);
			print('    --' + option + ": " + Reflect.field(ABOUT_SETTINGS, f));
		}
	}
	static var ABOUT_SETTINGS = {
		global : "force global repo if a local one exists",
		debug  : "run in debug mode, imply not --quiet",
		quiet  : "print less messages, imply not --debug",
		flat   : "do not use --recursive cloning for git",
		always : "answer all questions with yes",
		never  : "answer all questions with no",
		system : "run bundled haxelib version instead of latest update",
		skipDependencies : "do not install dependencies",
	}

	var settings: {
		debug  : Bool,
		quiet  : Bool,
		flat   : Bool,
		always : Bool,
		never  : Bool,
		global : Bool,
		system : Bool,
		skipDependencies : Bool,
	};
	function process() {
		argcur = 0;
		var rest = [];
		settings = {
			debug: false,
			quiet: false,
			always: false,
			never: false,
			flat: false,
			global: false,
			system: false,
			skipDependencies: false,
		};

		function parseSwitch(s:String) {
			return
				if (s.startsWith('--'))
					Some(s.substr(2));
				else if (s.startsWith('-'))
					Some(s.substr(1));
				else
					None;
		}

		var remoteIsSet = false;
		function setupRemote(path:String) {
			var r = ~/^(?:(https?):\/\/)?([^:\/]+)(?::([0-9]+))?\/?(.*)$/;
			if( !r.match(path) )
				throw "Invalid repository format '"+path+"'";
			SERVER.protocol = switch (r.matched(1)) {
				case null:
					SERVER.noSsl ? "http" : "https";
				case protocol:
					protocol;
			}
			SERVER.host = r.matched(2);
			SERVER.port = switch (r.matched(3)) {
				case null:
					switch (SERVER.protocol) {
						case "https": 443;
						case "http": 80;
						case protocol: throw 'unknown default port for $protocol';
					}
				case portStr:
					Std.parseInt(portStr);
			}
			SERVER.dir = r.matched(4);
			if (SERVER.dir.length > 0 && !SERVER.dir.endsWith("/")) SERVER.dir += "/";
			initSite();
			remoteIsSet = true;
		}

		while ( argcur < args.length) {
			var a = args[argcur++];
			switch( a ) {
				case '-cwd':
					var dir = args[argcur++];
					if (dir == null) {
						print("Missing directory argument for -cwd");
						Sys.exit(1);
					}
					try {
						Sys.setCwd(dir);
					} catch (e:String) {
						if (e == "std@set_cwd") {
							print("Directory " + dir + " unavailable");
							Sys.exit(1);
						}
						rethrow(e);
					}
				case "-notimeout":
					haxe.remoting.HttpConnection.TIMEOUT = 0;
				case "-R":
					setupRemote(args[argcur++]);
				case "--debug":
					settings.debug = true;
					settings.quiet = false;
				case "--quiet":
					settings.debug = false;
					settings.quiet = true;
				case "--skip-dependencies":
					settings.skipDependencies = true;
				case parseSwitch(_) => Some(s) if (Reflect.hasField(settings, s)):
					//if (!Reflect.hasField(settings, s)) {
						//print('unknown switch $a');
						//Sys.exit(1);
					//}
					Reflect.setField(settings, s, true);
				case 'run':
					rest = rest.concat(args.slice(argcur - 1));
					break;
				default:
					rest.push(a);
			}
		}
		if(!remoteIsSet) {
			switch(Sys.getEnv("HAXELIB_REMOTE")) {
				case null:
				case path: setupRemote(path);
			}
		}

		if (!isHaxelibRun && !settings.system) {
			var rep = try getGlobalRepository() catch (_:Dynamic) null;
			if (rep != null && FileSystem.exists(rep + HAXELIB_LIBNAME)) {
				argcur = 0; // send all arguments
				try {
					doRun(rep, HAXELIB_LIBNAME, null);
					return;
				} catch(e:Dynamic) {
					Sys.println('Warning: failed to run updated haxelib: $e');
					Sys.println('Warning: resorting to system haxelib...');
				}
			}
		}

		Cli.defaultAnswer =
			switch [settings.always, settings.never] {
				case [true, true]:
					print('--always and --never are mutually exclusive');
					Sys.exit(1);
					null;
				case [true, _]: true;
				case [_, true]: false;
				default: null;
			}

		argcur = 0;
		args = rest;

		var cmd = args[argcur++];
		if( cmd == null ) {
			usage();
			Sys.exit(1);
		}
		if (cmd == "upgrade") cmd = "update"; // TODO: maybe we should have some alias system
		for( c in commands )
			if( c.name == cmd ) {
				switch (c.cat) {
					case Deprecated(message):
						Sys.println('Warning: Command `$cmd` is deprecated and will be removed in future. $message.');
					default:
				}
				try {
					if( c.net ) {
						loadProxy();
						checkUpdate();
					}
					c.f();
				} catch( e : Dynamic ) {
					if( e == "std@host_resolve" ) {
						print("Host "+SERVER.host+" was not found");
						print("Please ensure that your internet connection is on");
						print("If you don't have an internet connection or if you are behing a proxy");
						print("please download manually the file from https://lib.haxe.org/files/3.0/");
						print("and run 'haxelib local <file>' to install the Library.");
						print("You can also setup the proxy with 'haxelib proxy'.");
						print(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
						Sys.exit(1);
					}
					if( e == "Blocked" ) {
						print("Http connection timeout. Try running haxelib -notimeout <command> to disable timeout");
						Sys.exit(1);
					}
					if( e == "std@get_cwd" ) {
						print("Error: Current working directory is unavailable");
						Sys.exit(1);
					}
					if( settings.debug )
						rethrow(e);
					print("Error: " + Std.string(e));
					Sys.exit(1);
				}
				return;
			}
		print("Unknown command "+cmd);
		usage();
		Sys.exit(1);
	}

	inline function createHttpRequest(url:String):Http {
		var req = new Http(url);
		req.addHeader("User-Agent", 'haxelib $VERSION_LONG');
		if (haxe.remoting.HttpConnection.TIMEOUT == 0)
			req.cnxTimeout = 0;
		return req;
	}

	// ---- COMMANDS --------------------

 	function search() {
		var word = param("Search word");
		var l = retry(site.search.bind(word));
		for( s in l )
			print(s.name);
		print(l.length+" libraries found");
	}

	function info() {
		var prj = param("Library name");
		var inf = retry(site.infos.bind(prj));
		print("Name: "+inf.name);
		print("Tags: "+inf.tags.join(", "));
		print("Desc: "+inf.desc);
		print("Website: "+inf.website);
		print("License: "+inf.license);
		print("Owner: "+inf.owner);
		print("Version: "+inf.getLatest());
		print("Releases: ");
		if( inf.versions.length == 0 )
			print("  (no version released yet)");
		for( v in inf.versions )
			print("   "+v.date+" "+v.name+" : "+v.comments);
	}

	function user() {
		var uname = param("User name");
		var inf = retry(site.user.bind(uname));
		print("Id: "+inf.name);
		print("Name: "+inf.fullname);
		print("Mail: "+inf.email);
		print("Libraries: ");
		if( inf.projects.length == 0 )
			print("  (no libraries)");
		for( p in inf.projects )
			print("  "+p);
	}

	function register() {
		doRegister(param("User"));
		print("Registration successful");
	}

	function doRegister(name) {
		var email = param("Email");
		var fullname = param("Fullname");
		var pass = param("Password",true);
		var pass2 = param("Confirm",true);
		if( pass != pass2 )
			throw "Password does not match";
		pass = Md5.encode(pass);
		retry(site.register.bind(name,pass,email,fullname));
		return pass;
	}

	function zipDirectory(root:String):List<Entry> {
		var ret = new List<Entry>();
		function seek(dir:String) {
			for (name in FileSystem.readDirectory(dir)) if (!name.startsWith('.')) {
				var full = '$dir/$name';
				if (FileSystem.isDirectory(full)) seek(full);
				else {
					var blob = File.getBytes(full);
					var entry:Entry = {
						fileName: full.substr(root.length+1),
						fileSize : blob.length,
						fileTime : FileSystem.stat(full).mtime,
						compressed : false,
						dataSize : blob.length,
						data : blob,
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

	function submit() {
		var file = param("Package");

		var data, zip;
		if (FileSystem.isDirectory(file)) {
			zip = zipDirectory(file);
			var out = new BytesOutput();
			new Writer(out).write(zip);
			data = out.getBytes();
		} else {
			data = File.getBytes(file);
			zip = Reader.readZip(new haxe.io.BytesInput(data));
		}

		var infos = Data.readInfos(zip,true);
		Data.checkClassPath(zip, infos);

		var user:String = infos.contributors[0];

		if (infos.contributors.length > 1)
			do {
				print("Which of these users are you: " + infos.contributors);
				user = param("User");
			} while ( infos.contributors.indexOf(user) == -1 );

		var password;
		if( retry(site.isNewUser.bind(user)) ) {
			print("This is your first submission as '"+user+"'");
			print("Please enter the following information for registration");
			password = doRegister(user);
		} else {
			password = readPassword(user);
		}
		retry(site.checkDeveloper.bind(infos.name,user));

		// check dependencies validity
		for( d in infos.dependencies ) {
			var infos = retry(site.infos.bind(d.name));
			if( d.version == "" )
				continue;
			var found = false;
			for( v in infos.versions )
				if( v.name == d.version ) {
					found = true;
					break;
				}
			if( !found )
				throw "Library " + d.name + " does not have version " + d.version;
		}

		// check if this version already exists

		var sinfos = try retry(site.infos.bind(infos.name)) catch( _ : Dynamic ) null;
		if( sinfos != null )
			for( v in sinfos.versions )
				if( v.name == infos.version && !ask("You're about to overwrite existing version '"+v.name+"', please confirm") )
					throw "Aborted";

		// query a submit id that will identify the file
		var id = retry(site.getSubmitId.bind());

		// directly send the file data over Http
		var h = createHttpRequest(SERVER.protocol+"://"+SERVER.host+":"+SERVER.port+"/"+SERVER.url);
		h.onError = function(e) throw e;
		h.onData = print;

		var inp = if ( settings.quiet == false )
			new ProgressIn(new haxe.io.BytesInput(data),data.length);
		else
			new haxe.io.BytesInput(data);

		h.fileTransfer("file", id, inp, data.length);
		print("Sending data.... ");
		h.request(true);

		// processing might take some time, make sure we wait
		print("Processing file.... ");
		if (haxe.remoting.HttpConnection.TIMEOUT != 0) // don't ignore -notimeout
			haxe.remoting.HttpConnection.TIMEOUT = 1000;
		// ask the server to register the sent file
		var msg = retry(site.processSubmit.bind(id,user,password));
		print(msg);
	}

	function readPassword(user:String, prompt = "Password"):String {
		var password = Md5.encode(param(prompt,true));
		var attempts = 5;
		while (!retry(site.checkPassword.bind(user, password))) {
			print('Invalid password for $user');
			if (--attempts == 0)
				throw 'Failed to input correct password';
			password = Md5.encode(param('$prompt ($attempts more attempt${attempts == 1 ? "" : "s"})', true));
		}
		return password;
	}

	function install() {
		var rep = getRepository();

		var prj = param("Library name or hxml file:");

		// No library given, install libraries listed in *.hxml in given directory
		if( prj == "all") {
			installFromAllHxml(rep);
			return;
		}

		if( sys.FileSystem.exists(prj) && !sys.FileSystem.isDirectory(prj) ) {
			// *.hxml provided, install all libraries/versions in this hxml file
			if( prj.endsWith(".hxml") ) {
				installFromHxml(rep, prj);
				return;
			}
			// *.zip provided, install zip as haxe library
			if (prj.endsWith(".zip")) {
				doInstallFile(rep, prj, true, true);
				return;
			}

			if ( prj.endsWith("haxelib.json") )
			{
				installFromHaxelibJson( rep, prj);
				return;
			}
		}

		// Name provided that wasn't a local hxml or zip, so try to install it from server
		var inf = retry(site.infos.bind(prj));
		var reqversion = paramOpt();
		var version = getVersion(inf, reqversion);
		doInstall(rep,inf.name,version,version == inf.getLatest());
	}

	function getVersion( inf:ProjectInfos, ?reqversion:String ) {
		if( inf.versions.length == 0 )
			throw "The library "+inf.name+" has not yet released a version";
		var version = if( reqversion != null ) reqversion else inf.getLatest();
		var found = false;
		for( v in inf.versions )
			if( v.name == version ) {
				found = true;
				break;
			}
		if( !found )
			throw "No such version "+version+" for library "+inf.name;

		return version;
	}

	function installFromHxml( rep:String, path:String ) {
		var targets  = [
			'-java ' => 'hxjava',
			'-cpp ' => 'hxcpp',
			'-cs ' => 'hxcs',
		];
		var libsToInstall = new Map<String, {name:String,version:String,type:String,url:String,branch:String,subDir:String}>();

		function processHxml(path) {
			var hxml = normalizeHxml(sys.io.File.getContent(path));
			var lines = hxml.split("\n");
			for (l in lines) {
				l = l.trim();

				for (target in targets.keys())
					if (l.startsWith(target)) {
						var lib = targets[target];
						if (!libsToInstall.exists(lib))
							libsToInstall[lib] = { name: lib, version: null, type:"haxelib", url: null, branch: null, subDir: null }
					}

				var libraryFlagEReg = ~/^(-lib|-L|--library)\b/;
				if (libraryFlagEReg.match(l))
				{
					var key = libraryFlagEReg.matchedRight().trim();
					var parts = ~/:/.split(key);
					var libName = parts[0];
					var libVersion:String = null;
					var branch:String = null;
					var url:String = null;
					var subDir:String = null;
					var type:String;

					if ( parts.length > 1 )
					{
						if ( parts[1].startsWith("git:") )
						{

							type = "git";
							var urlParts = parts[1].substr(4).split("#");
							url = urlParts[0];
							branch = urlParts.length > 1 ? urlParts[1] : null;
						}
						else
						{
							type = "haxelib";
							libVersion = parts[1];
						}
					}
					else
					{
						type = "haxelib";
					}

					switch libsToInstall[key] {
						case null, { version: null } :
							libsToInstall.set(key, { name:libName, version:libVersion, type: type, url: url, subDir: subDir, branch: branch } );
						default:
					}
				}

				if (l.endsWith(".hxml"))
					processHxml(l);
			}
		}
		processHxml(path);

		if (Lambda.empty(libsToInstall))
			return;

		// Check the version numbers are all good
		// TODO: can we collapse this into a single API call?  It's getting too slow otherwise.
		print("Loading info about the required libraries");
		for (l in libsToInstall)
		{
			if ( l.type == "git" )
			{
				// Do not check git repository infos
				continue;
			}
			var inf = retry(site.infos.bind(l.name));
			l.version = getVersion(inf, l.version);
		}

		// Print a list with all the info
		print("Haxelib is going to install these libraries:");
		for (l in libsToInstall) {
			var vString = (l.version == null) ? "" : " - " + l.version;
			print("  " + l.name + vString);
		}

		// Install if they confirm
		if (ask("Continue?")) {
			for (l in libsToInstall) {
				if ( l.type == "haxelib" )
					doInstall(rep, l.name, l.version, true);
				else if ( l.type == "git" )
					useVcs(VcsID.Git, function(vcs) doVcsInstall(rep, vcs, l.name, l.url, l.branch, l.subDir, l.version));
				else if ( l.type == "hg" )
					useVcs(VcsID.Hg, function(vcs) doVcsInstall(rep, vcs, l.name, l.url, l.branch, l.subDir, l.version));
			}
		}
	}

	function installFromHaxelibJson( rep:String, path:String )
	{
		doInstallDependencies(rep, Data.readData(File.getContent(path), false).dependencies);
	}

	function installFromAllHxml(rep:String) {
		var cwd = Sys.getCwd();
		var hxmlFiles = sys.FileSystem.readDirectory(cwd).filter(function (f) return f.endsWith(".hxml"));
		if (hxmlFiles.length > 0) {
			for (file in hxmlFiles) {
				print('Installing all libraries from $file:');
				installFromHxml(rep, cwd + file);
			}
		} else {
			print("No hxml files found in the current directory.");
		}
	}

	// strip comments, trim whitespace from each line and remove empty lines
	function normalizeHxml(hxmlContents: String) {
		return ~/\r?\n/g.split(hxmlContents).map(StringTools.trim).filter(function(line) {
			return line != "" && !line.startsWith("#");
		}).join('\n');
	}

	// maxRedirect set to 20, which is most browsers' default value according to https://stackoverflow.com/a/36041063/267998
	function download(fileUrl:String, outPath:String, maxRedirect = 20):Void {
		var out = try File.append(outPath,true) catch (e:Dynamic) throw 'Failed to write to $outPath: $e';
		out.seek(0, SeekEnd);

		var h = createHttpRequest(fileUrl);

		var currentSize = out.tell();
		if (currentSize > 0)
			h.addHeader("range", "bytes="+currentSize + "-");

		var progress = if (settings != null && settings.quiet == false )
			new ProgressOut(out, currentSize);
		else
			out;

		var httpStatus = -1;
		var redirectedLocation = null;
		h.onStatus = function(status) {
			httpStatus = status;
			switch (httpStatus) {
				case 301, 302, 307, 308:
					switch (h.responseHeaders.get("Location")) {
						case null:
							throw 'Request to $fileUrl responded with $httpStatus, ${h.responseHeaders}';
						case location:
							redirectedLocation = location;
					}
				default:
					// TODO?
			}
		};
		h.onError = function(e) {
			progress.close();

			switch(httpStatus) {
				case 416:
					// 416 Requested Range Not Satisfiable, which means that we probably have a fully downloaded file already
					// if we reached onError, because of 416 status code, it's probably okay and we should try unzipping the file
				default:
					FileSystem.deleteFile(outPath);
					throw e;
			}
		};
		h.customRequest(false, progress);

		if (redirectedLocation != null) {
			FileSystem.deleteFile(outPath);

			if (maxRedirect > 0) {
				download(redirectedLocation, outPath, maxRedirect - 1);
			} else {
				throw "Too many redirects.";
			}
		}
	}

	function doInstall( rep, project, version, setcurrent ) {
		// check if exists already
		if( FileSystem.exists(Path.join([rep, Data.safe(project), Data.safe(version)])) ) {
			print("You already have "+project+" version "+version+" installed");
			setCurrent(rep,project,version,true);
			return;
		}

		// download to temporary file
		var filename = Data.fileName(project,version);
		var filepath = Path.join([rep, filename]);

		print("Downloading "+filename+"...");

		var maxRetry = 3;
		var fileUrl = Path.join([siteUrl, Data.REPOSITORY, filename]);
		for (i in 0...maxRetry) {
			try {
				download(fileUrl, filepath);
				break;
			} catch (e:Dynamic) {
				print('Failed to download ${fileUrl}. (${i+1}/${maxRetry})\n${e}');
				Sys.sleep(1);
			}
		}

		doInstallFile(rep, filepath, setcurrent);
		try {
			retry(site.postInstall.bind(project, version));
		} catch (e:Dynamic) {}
	}

	function doInstallFile(rep,filepath,setcurrent,nodelete = false) {
		// read zip content
		var f = File.read(filepath,true);
		var zip = try {
			Reader.readZip(f);
		} catch (e:Dynamic) {
			f.close();
			// file is corrupted, remove it
			if (!nodelete)
				FileSystem.deleteFile(filepath);
			rethrow(e);
		}
		f.close();
		var infos = Data.readInfos(zip,false);
		print('Installing ${infos.name}...');
		// create directories
		var pdir = rep + Data.safe(infos.name);
		safeDir(pdir);
		pdir += "/";
		var target = pdir + Data.safe(infos.version);
		safeDir(target);
		target += "/";

		// locate haxelib.json base path
		var basepath = Data.locateBasePath(zip);

		// unzip content
		var entries = [for (entry in zip) if (entry.fileName.startsWith(basepath)) entry];
		var total = entries.length;
		for (i in 0...total) {
			var zipfile = entries[i];
			var n = zipfile.fileName;
			// remove basepath
			n = n.substr(basepath.length,n.length-basepath.length);
			if( n.charAt(0) == "/" || n.charAt(0) == "\\" || n.split("..").length > 1 )
				throw "Invalid filename : "+n;

			if (settings.debug) {
				var percent = Std.int((i / total) * 100);
				Sys.print('${i + 1}/$total ($percent%)\r');
			}

			var dirs = ~/[\/\\]/g.split(n);
			var path = "";
			var file = dirs.pop();
			for( d in dirs ) {
				path += d;
				safeDir(target+path);
				path += "/";
			}
			if( file == "" ) {
				if( path != "" && settings.debug ) print("  Created "+path);
				continue; // was just a directory
			}
			path += file;
			if (settings.debug)
				print("  Install "+path);
			var data = Reader.unzip(zipfile);
			File.saveBytes(target+path,data);
		}

		// set current version
		if( setcurrent || !FileSystem.exists(pdir+".current") ) {
			File.saveContent(pdir + ".current", infos.version);
			print("  Current version is now "+infos.version);
		}

		// end
		if( !nodelete )
			FileSystem.deleteFile(filepath);
		print("Done");

		// process dependencies
		doInstallDependencies(rep, infos.dependencies);

		return infos;
	}

	function doInstallDependencies( rep:String, dependencies:Array<Dependency> ) {
		if( settings.skipDependencies ) return;

		for( d in dependencies ) {
			if( d.version == "" ) {
				var pdir = rep + Data.safe(d.name);
				var dev = try getDev(pdir) catch (_:Dynamic) null;

				if (dev != null) { // no version specified and dev set, no need to install dependency
					continue;
				}
			}

			if( d.version == "" && d.type == DependencyType.Haxelib )
				d.version = retry(site.getLatestVersion.bind(d.name));
			print("Installing dependency "+d.name+" "+d.version);

			switch d.type {
				case Haxelib:
					var info = retry(site.infos.bind(d.name));
					doInstall(rep, info.name, d.version, false);
				case Git:
					useVcs(VcsID.Git, function(vcs) doVcsInstall(rep, vcs, d.name, d.url, d.branch, d.subDir, d.version));
				case Mercurial:
					useVcs(VcsID.Hg, function(vcs) doVcsInstall(rep, vcs, d.name, d.url, d.branch, d.subDir, d.version));
			}
		}
	}

	static public function getHomePath():String{
		var home:String = null;
		if (IS_WINDOWS) {
			home = Sys.getEnv("USERPROFILE");
			if (home == null) {
				var drive = Sys.getEnv("HOMEDRIVE");
				var path = Sys.getEnv("HOMEPATH");
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

	static public function getConfigFile():String {
		return Path.addTrailingSlash( getHomePath() ) + ".haxelib";
	}

	function getGlobalRepositoryPath(create = false):String {
		// first check the env var
		var rep = Sys.getEnv("HAXELIB_PATH");
		if (rep != null)
			return rep.trim();

		// try to read from user config
		rep = try File.getContent(getConfigFile()).trim() catch (_:Dynamic) null;
		if (rep != null)
			return rep;

		if (!IS_WINDOWS) {
			// on unixes, try to read system-wide config
			rep = try File.getContent("/etc/.haxelib").trim() catch (_:Dynamic) null;
			if (rep == null)
				throw "This is the first time you are running haxelib. Please run `haxelib setup` first";
		} else {
			// on windows, try to use haxe installation path
			rep = getWindowsDefaultGlobalRepositoryPath();
			if (create)
				try safeDir(rep) catch(e:Dynamic) throw 'Error accessing Haxelib repository: $e';
		}

		return rep;
	}

	// The Windows haxe installer will setup %HAXEPATH%. We will default haxelib repo to %HAXEPATH%/lib.
	// When there is no %HAXEPATH%, we will use a "haxelib" directory next to the config file, ".haxelib".
	function getWindowsDefaultGlobalRepositoryPath():String {
		var haxepath = Sys.getEnv("HAXEPATH");
		if (haxepath != null)
			return Path.addTrailingSlash(haxepath.trim()) + REPNAME;
		else
			return Path.join([Path.directory(getConfigFile()), "haxelib"]);
	}

	function getSuggestedGlobalRepositoryPath():String {
		if (IS_WINDOWS)
			return getWindowsDefaultGlobalRepositoryPath();

		return if (FileSystem.exists("/usr/share/haxe")) // for Debian
			'/usr/share/haxe/$REPNAME'
		else if (Sys.systemName() == "Mac") // for newer OSX, where /usr/lib is not writable
			'/usr/local/lib/haxe/$REPNAME'
		else
			'/usr/lib/haxe/$REPNAME'; // for other unixes
	}

	function getRepository():String {
		if (!settings.global)
			return switch getLocalRepository() {
				case null: getGlobalRepository();
				case repo: Path.addTrailingSlash(FileSystem.fullPath(repo));
			}
		else
			return getGlobalRepository();
	}

	function getLocalRepository():Null<String> {
		var dir = Path.removeTrailingSlashes(Sys.getCwd());
		while (dir != null) {
			var repo = Path.addTrailingSlash(dir) + REPODIR;
			if(FileSystem.exists(repo) && FileSystem.isDirectory(repo)) {
				return repo;
			} else {
				dir = new Path(dir).dir;
			}
		}
		return null;
	}

	function getGlobalRepository():String {
		var rep = getGlobalRepositoryPath(true);
		if (!FileSystem.exists(rep))
			throw "haxelib Repository " + rep + " does not exist. Please run `haxelib setup` again.";
		else if (!FileSystem.isDirectory(rep))
			throw "haxelib Repository " + rep + " exists, but is a file, not a directory. Please remove it and run `haxelib setup` again.";
		return Path.addTrailingSlash(rep);
	}

	function setup() {
		var rep = try getGlobalRepositoryPath() catch (_:Dynamic) null;

		var configFile = getConfigFile();

		if (args.length <= argcur) {
			if (rep == null)
				rep = getSuggestedGlobalRepositoryPath();
			print("Please enter haxelib repository path with write access");
			print("Hit enter for default (" + rep + ")");
		}

		var line = param("Path");
		if (line != "") {
			var splitLine = line.split("/");
			if(splitLine[0] == "~") {
				var home = getHomePath();

				for(i in 1...splitLine.length) {
					home += "/" + splitLine[i];
				}
				line = home;
			}

			rep = line;
		}


		rep = try absolutePath(rep) catch (e:Dynamic) rep;

		if (isSamePath(rep, configFile))
			throw "Can't use "+rep+" because it is reserved for config file";

		safeDir(rep);
		File.saveContent(configFile, rep);

		print("haxelib repository is now " + rep);
	}

	function config() {
		print(getRepository());
	}

	function getCurrent( proj, dir ) {
		return try { getDev(dir); return "dev"; } catch( e : Dynamic ) try File.getContent(dir + "/.current").trim() catch( e : Dynamic ) throw "Library "+proj+" is not installed : run 'haxelib install "+proj+"'";
	}

	function getDev( dir ) {
		var path = File.getContent(dir + "/.dev").trim();
		path = ~/%([A-Za-z0-9_]+)%/g.map(path,function(r) {
			var env = Sys.getEnv(r.matched(1));
			return env == null ? "" : env;
		});
		var filters = try Sys.getEnv("HAXELIB_DEV_FILTER").split(";") catch( e : Dynamic ) null;
		if( filters != null && !filters.exists(function(flt) return StringTools.startsWith(path.toLowerCase().split("\\").join("/"),flt.toLowerCase().split("\\").join("/"))) )
			throw "This .dev is filtered";
		return path;
	}

	function list() {
		var rep = getRepository();
		var folders = FileSystem.readDirectory(rep);
		var filter = paramOpt();
		if ( filter != null )
			folders = folders.filter( function (f) return f.toLowerCase().indexOf(filter.toLowerCase()) > -1 );
		var all = [];
		for( p in folders ) {
			if( p.charAt(0) == "." )
				continue;

			var current = try getCurrent("", rep + p) catch(e:Dynamic) continue;
			var dev = try getDev(rep + p) catch( e : Dynamic ) null;

			var semvers = [];
			var others = [];
			for( v in FileSystem.readDirectory(rep+p) ) {
				if( v.charAt(0) == "." )
					continue;
				v = Data.unsafe(v);
				var semver = try SemVer.ofString(v) catch (_:Dynamic) null;
				if (semver != null)
					semvers.push(semver);
				else
					others.push(v);
			}

			if (semvers.length > 0)
				semvers.sort(SemVer.compare);

			var versions = [];
			for (v in semvers)
				versions.push((v : String));
			for (v in others)
				versions.push(v);

			if (dev == null) {
				for (i in 0...versions.length) {
					var v = versions[i];
					if (v == current)
						versions[i] = '[$v]';
				}
			} else {
				versions.push("[dev:"+dev+"]");
			}

			all.push(Data.unsafe(p) + ": "+versions.join(" "));
		}
		all.sort(function(s1, s2) return Reflect.compare(s1.toLowerCase(), s2.toLowerCase()));
		for (p in all) {
			print(p);
		}
	}

	function update() {
		var rep = getRepository();

		var prj = paramOpt();
		if (prj != null) {
			prj = projectNameToDir(rep, prj); // get project name in proper case
			if (!updateByName(rep, prj))
				print(prj + " is up to date");
			return;
		}

		var state = { rep : rep, prompt : true, updated : false };
		for( p in FileSystem.readDirectory(state.rep) ) {
			if( p.charAt(0) == "." || !FileSystem.isDirectory(state.rep+"/"+p) )
				continue;
			var p = Data.unsafe(p);
			print("Checking " + p);
			try {
				doUpdate(p, state);
			} catch (e:VcsError) {
				if (!e.match(VcsUnavailable(_)))
					rethrow(e);
			}
		}
		if( state.updated )
			print("Done");
		else
			print("All libraries are up-to-date");
	}

	function projectNameToDir( rep:String, project:String ) {
		var p = project.toLowerCase();
		var l = FileSystem.readDirectory(rep).filter(function (dir) return dir.toLowerCase() == p);

		switch (l) {
			case []: return project;
			case [dir]: return Data.unsafe(dir);
			case _: throw "Several name case for library " + project;
		}
	}

	function updateByName(rep:String, prj:String) {
		var state = { rep : rep, prompt : false, updated : false };
		doUpdate(prj,state);
		return state.updated;
	}

	function doUpdate( p : String, state : { updated : Bool, rep : String, prompt : Bool } ) {
		var pdir = state.rep + Data.safe(p);

		var vcs = Vcs.getVcsForDevLib(pdir, settings);
		if(vcs != null) {
			if(!vcs.available)
				throw VcsError.VcsUnavailable(vcs);

			var oldCwd = Sys.getCwd();
			Sys.setCwd(pdir + "/" + vcs.directory);
			var success = vcs.update(p);

			state.updated = success;
			if(success)
				print(p + " was updated");
			Sys.setCwd(oldCwd);
		} else {
			var latest = try retry(site.getLatestVersion.bind(p)) catch( e : Dynamic ) { Sys.println(e); return; };

			if( !FileSystem.exists(pdir+"/"+Data.safe(latest)) ) {
				if( state.prompt ) {
					if (!ask("Update "+p+" to "+latest))
						return;
				}
				var info = retry(site.infos.bind(p));
				doInstall(state.rep, info.name, latest,true);
				state.updated = true;
			} else
				setCurrent(state.rep, p, latest, true);
		}
	}

	function remove() {
		var rep = getRepository();
		var prj = param("Library");
		var version = paramOpt();
		var pdir = rep + Data.safe(prj);
		if( version == null ) {
			if( !FileSystem.exists(pdir) )
				throw "Library "+prj+" is not installed";

			if (prj == HAXELIB_LIBNAME && isHaxelibRun) {
				print('Error: Removing "$HAXELIB_LIBNAME" requires the --system flag');
				Sys.exit(1);
			}

			deleteRec(pdir);
			print("Library "+prj+" removed");
			return;
		}

		var vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) )
			throw "Library "+prj+" does not have version "+version+" installed";

		var cur = File.getContent(pdir + "/.current").trim(); // set version regardless of dev
		if( cur == version )
			throw "Can't remove current version of library "+prj;
		var dev = try getDev(pdir) catch (_:Dynamic) null; // dev is checked here
		if( dev == vdir )
			throw "Can't remove dev version of library "+prj;
		deleteRec(vdir);
		print("Library "+prj+" version "+version+" removed");
	}

	function set() {
		setCurrent(getRepository(), param("Library"), param("Version"), false);
	}

	function setCurrent( rep : String, prj : String, version : String, doAsk : Bool ) {
		var pdir = rep + Data.safe(prj);
		var vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) ){
			print("Library "+prj+" version "+version+" is not installed");
			if(ask("Would you like to install it?")) {
				var info = retry(site.infos.bind(prj));
				doInstall(rep, info.name, version, true);
			}
			return;
		}
		if( File.getContent(pdir + "/.current").trim() == version )
			return;
		if( doAsk && !ask("Set "+prj+" to version "+version) )
			return;
		File.saveContent(pdir+"/.current",version);
		print("Library "+prj+" current version is now "+version);
	}

	function checkRec( rep : String, prj : String, version : String, l : List<{ project : String, version : String, dir : String, info : Infos }>, ?returnDependencies : Bool = true ) {
		var pdir = rep + Data.safe(prj);
		var explicitVersion = version != null;
		var version = if( version != null ) version else getCurrent(prj, pdir);

		var dev = try getDev(pdir) catch (_:Dynamic) null;
		var vdir = pdir + "/" + Data.safe(version);

		if( dev != null && (!explicitVersion || !FileSystem.exists(vdir)) )
			vdir = dev;

		if( !FileSystem.exists(vdir) )
			throw "Library "+prj+" version "+version+" is not installed";

		for( p in l )
			if( p.project == prj ) {
				if( p.version == version )
					return;
				throw "Library "+prj+" has two versions included : "+version+" and "+p.version;
			}
		var json = try File.getContent(vdir+"/"+Data.JSON) catch( e : Dynamic ) null;
		var inf = Data.readData(json, json != null ? CheckSyntax : NoCheck);
		l.add({ project : prj, version : version, dir : Path.addTrailingSlash(vdir), info: inf });
		if( returnDependencies ) {
			for( d in inf.dependencies )
				if( !Lambda.exists(l, function(e) return e.project == d.name) )
					checkRec(rep,d.name,if( d.version == "" ) null else d.version,l);
		}
	}

	function path() {
		var rep = getRepository();
		var list = new List();
		while( argcur < args.length ) {
			var a = args[argcur++].split(":");
			try {
				checkRec(rep, a[0], a[1], list);
			} catch(e:Dynamic) {
				throw 'Cannot process $a: $e';
			}
		}
		for( d in list ) {
			var ndir = d.dir + "ndll";
			if (FileSystem.exists(ndir))
				Sys.println('-L $ndir/');

			try {
				Sys.println(normalizeHxml(File.getContent(d.dir + "extraParams.hxml")));
			} catch(_:Dynamic) {}

			var dir = d.dir;
			if (d.info.classPath != "") {
				var cp = d.info.classPath;
				dir = Path.addTrailingSlash( d.dir + cp );
			}
			Sys.println(dir);

			Sys.println("-D " + d.project + "="+d.info.version);
		}
	}

	function libpath( ) {
		var rep = getRepository();
		while( argcur < args.length ) {
			var a = args[argcur++].split(":");
			var results = new List();
			checkRec(rep, a[0], a[1], results, false);
			if( !results.isEmpty() ) Sys.println(results.first().dir);
		}
	}

	function dev() {
		var rep = getRepository();
		var project = param("Library");
		var dir = paramOpt();
		var proj = rep + Data.safe(project);
		if( !FileSystem.exists(proj) ) {
			FileSystem.createDirectory(proj);
		}
		var devfile = proj+"/.dev";
		if( dir == null ) {
			if( FileSystem.exists(devfile) )
				FileSystem.deleteFile(devfile);
			print("Development directory disabled");
		}
		else {
			while ( dir.endsWith("/") || dir.endsWith("\\") ) {
				dir = dir.substr(0,-1);
			}
			if (!FileSystem.exists(dir)) {
				print('Directory $dir does not exist');
			} else {
				dir = FileSystem.fullPath(dir);
				try {
					File.saveContent(devfile, dir);
					print("Development directory set to "+dir);
				}
				catch (e:Dynamic) {
					print('Could not write to $devfile');
				}
			}

		}
	}


	function removeExistingDevLib(proj:String):Void {
		//TODO: ask if existing repo have changes.

		// find existing repo:
		var vcs = Vcs.getVcsForDevLib(proj, settings);
		// remove existing repos:
		while(vcs != null) {
			deleteRec(proj + "/" + vcs.directory);
			vcs = Vcs.getVcsForDevLib(proj, settings);
		}
	}

	inline function useVcs(id:VcsID, fn:Vcs->Void):Void {
		// Prepare check vcs.available:
		var vcs = Vcs.get(id, settings);
		if(vcs == null || !vcs.available)
			throw 'Could not use $id, please make sure it is installed and available in your PATH.';
		return fn(vcs);
	}

	function vcs(id:VcsID) {
		var rep = getRepository();
		useVcs(id, function(vcs) doVcsInstall(rep, vcs, param("Library name"), param(vcs.name + " path"), paramOpt(), paramOpt(), paramOpt()));
	}

	function doVcsInstall(rep:String, vcs:Vcs, libName:String, url:String, branch:String, subDir:String, version:String) {

		var proj = rep + Data.safe(libName);

		var libPath = proj + "/" + vcs.directory;

		function doVcsClone() {
			print("Installing " +libName + " from " +url + ( branch != null ? " branch: " + branch : "" ));
			try {
				vcs.clone(libPath, url, branch, version);
			} catch(error:VcsError) {
				deleteRec(libPath);
				var message = switch(error) {
					case VcsUnavailable(vcs):
						'Could not use ${vcs.executable}, please make sure it is installed and available in your PATH.';
					case CantCloneRepo(vcs, repo, stderr):
						'Could not clone ${vcs.name} repository' + (stderr != null ? ":\n" + stderr : ".");
					case CantCheckoutBranch(vcs, branch, stderr):
						'Could not checkout branch, tag or path "$branch": ' + stderr;
					case CantCheckoutVersion(vcs, version, stderr):
						'Could not checkout tag "$version": ' + stderr;
				};
				throw message;
			}
		}

		if ( FileSystem.exists(proj + "/" + Data.safe(vcs.directory)) ) {
			print("You already have "+libName+" version "+vcs.directory+" installed.");

			var wasUpdated = this.alreadyUpdatedVcsDependencies.exists(libName);
			var currentBranch = if (wasUpdated) this.alreadyUpdatedVcsDependencies.get(libName) else null;

			if (branch != null && (!wasUpdated || (wasUpdated && currentBranch != branch))
				&& ask("Overwrite branch: " + (currentBranch == null?"<unspecified>":"\"" + currentBranch + "\"") + " with \"" + branch + "\""))
			{
				deleteRec(libPath);
				doVcsClone();
			}
			else if (!wasUpdated)
			{
				print("Updating " + libName+" version " + vcs.directory + " ...");
				updateByName(rep, libName);
			}
		} else {
			doVcsClone();
		}

		// finish it!
		if (subDir != null) {
			libPath += "/" + subDir;
			File.saveContent(proj + "/.dev", libPath);
			print("Development directory set to "+libPath);
		} else {
			File.saveContent(proj + "/.current", vcs.directory);
			print("Library "+libName+" current version is now "+vcs.directory);
		}

		this.alreadyUpdatedVcsDependencies.set(libName, branch);

		var jsonPath = libPath + "/haxelib.json";
		if(FileSystem.exists(jsonPath))
			doInstallDependencies(rep, Data.readData(File.getContent(jsonPath), false).dependencies);
	}


	function run() {
		var rep = getRepository();
		var project = param("Library");
		var temp = project.split(":");
		doRun(rep, temp[0], temp[1]);
	}

	function haxeVersion():SemVer {
		if(__haxeVersion == null) {
			var p = new Process('haxe', ['--version']);
			if(p.exitCode() != 0) {
				throw 'Cannot get haxe version: ${p.stderr.readAll().toString()}';
			}
			var str = p.stdout.readAll().toString();
			__haxeVersion = SemVer.ofString(str.split('+')[0]);
		}
		return __haxeVersion;
	}
	static var __haxeVersion:SemVer;

	function doRun( rep:String, project:String, version:String ) {
		var pdir = rep + Data.safe(project);
		if( !FileSystem.exists(pdir) )
			throw "Library "+project+" is not installed";
		pdir += "/";
		if (version == null)
			version = getCurrent(project, pdir);
		var dev = try getDev(pdir) catch ( e : Dynamic ) null;
		var vdir = dev != null ? dev : pdir + Data.safe(version);

		var infos =
			try
				Data.readData(File.getContent(vdir + '/haxelib.json'), false)
			catch (e:Dynamic)
				throw 'Error parsing haxelib.json for $project@$version: $e';

		args.push(Sys.getCwd());
		Sys.setCwd(vdir);

		var callArgs =
			if (infos.main != null) {
				runScriptArgs(project, infos.main, infos.dependencies);
			} else if(FileSystem.exists('$vdir/run.n')) {
				["neko", vdir + "/run.n"];
			} else if(FileSystem.exists('$vdir/Run.hx')) {
				runScriptArgs(project, 'Run', infos.dependencies);
			} else {
				throw 'Library $project version $version does not have a run script';
			}
		for (i in argcur...args.length)
			callArgs.push(args[i]);

		Sys.putEnv("HAXELIB_RUN", "1");
		Sys.putEnv("HAXELIB_RUN_NAME", project);
		var cmd = callArgs.shift();
 		Sys.exit(Sys.command(cmd, callArgs));
	}

	function runScriptArgs(project:String, main:String, dependencies:Dependencies):Array<String> {
		var deps = dependencies.toArray();
		deps.push( { name: project, version: DependencyVersion.DEFAULT } );
		var args = [];
		// TODO: change comparison to '4.0.0' upon Haxe 4.0 release
		if(settings.global && SemVer.compare(haxeVersion(), SemVer.ofString('4.0.0-rc.5')) >= 0) {
			args.push('--haxelib-global');
		}
		for (d in deps) {
			args.push('-lib');
			args.push(d.name + if (d.version == '') '' else ':${d.version}');
		}
		args.unshift('haxe');
		args.push('--run');
		args.push(main);
		return args;
	}

	function proxy() {
		var rep = getRepository();
		var host = param("Proxy host");
		if( host == "" ) {
			if( FileSystem.exists(rep + "/.proxy") ) {
				FileSystem.deleteFile(rep + "/.proxy");
				print("Proxy disabled");
			} else
				print("No proxy specified");
			return;
		}
		var port = Std.parseInt(param("Proxy port"));
		var authName = param("Proxy user login");
		var authPass = authName == "" ? "" : param("Proxy user pass");
		var proxy = {
			host : host,
			port : port,
			auth : authName == "" ? null : { user : authName, pass : authPass },
		};
		Http.PROXY = proxy;
		print("Testing proxy...");
		try Http.requestUrl(SERVER.protocol + "://lib.haxe.org") catch( e : Dynamic ) {
			if(!ask("Proxy connection failed. Use it anyway")) {
				return;
			}
		}
		File.saveContent(rep + "/.proxy", haxe.Serializer.run(proxy));
		print("Proxy setup done");
	}

	function loadProxy() {
		var rep = getRepository();
		try Http.PROXY = haxe.Unserializer.run(File.getContent(rep + "/.proxy")) catch( e : Dynamic ) { };
	}

	function convertXml() {
		var cwd = Sys.getCwd();
		var xmlFile = cwd + "haxelib.xml";
		var jsonFile = cwd + "haxelib.json";

		if (!FileSystem.exists(xmlFile)) {
			print('No `haxelib.xml` file was found in the current directory.');
			Sys.exit(0);
		}

		var xmlString = File.getContent(xmlFile);
		var json = ConvertXml.convert(xmlString);
		var jsonString = ConvertXml.prettyPrint(json);

		File.saveContent(jsonFile, jsonString);
		print('Saved to $jsonFile');
	}

	function newRepo() {
		var path = absolutePath(REPODIR);
		var created = FsUtils.safeDir(path, true);
		if (created)
			print('Local repository created ($path)');
		else
			print('Local repository already exists ($path)');
	}

	function deleteRepo() {
		var path = absolutePath(REPODIR);
		var deleted = FsUtils.deleteRec(path);
		if (deleted)
			print('Local repository deleted ($path)');
		else
			print('No local repository found ($path)');
	}

	// ----------------------------------

	inline function print(str)
		Sys.println(str);

	static function main() {
		switch(Sys.getEnv("HAXELIB_NO_SSL")) {
			case "1", "true":
				SERVER.noSsl = true;
				SERVER.protocol = "http";
			case _:
		}
		try {
			new Main().process();
		} catch(e:Dynamic) {
			for(arg in Sys.args()) {
				if(arg == '--debug') {
					Util.rethrow(e);
				}
			}
			Sys.stderr().writeString(Std.string(e) + '\n');
		}
	}

	// haxe 3.1.3 doesn't have FileSystem.absolutePath()
	static function absolutePath(path:String) {
		if (StringTools.startsWith(path, '/') || path.charAt(1) == ':' || StringTools.startsWith(path, '\\\\')) {
			return path;
		}
		return haxe.io.Path.join([Sys.getCwd(), path]);
	}

	// deprecated commands
	function local() {
		doInstallFile(getRepository(), param("Package"), true, true);
	}

	function updateSelf() {
		updateByName(getGlobalRepository(), HAXELIB_LIBNAME);
	}
}
