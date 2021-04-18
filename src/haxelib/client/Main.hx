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

import haxe.Http;
import haxe.Timer;
import haxe.crypto.Md5;
import haxe.io.BytesOutput;
import haxe.zip.*;
import haxe.iterators.ArrayIterator;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

import haxelib.client.Vcs;
import haxelib.client.Util.*;
import haxelib.client.FsUtils.*;
import haxelib.client.Args;
import haxelib.client.Cli.ask;

using StringTools;
using Lambda;
using haxelib.Data;

@:structInit
class ServerInfo {
	public final protocol:String;
	public final host:String;
	public final port:Int;
	public final dir:String;
	public final url:String;
	public final apiVersion:String;
	public final noSsl:Bool;
}

@:structInit
class CommandInfo {
	public final command:()->Void;
	public final maxArgs:Null<Int>;
	public final net:Bool;
	/** Message for deprecated commands**/
	public final useInstead:Null<String>;
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
	static final HAXELIB_LIBNAME = "haxelib";

	static final VERSION:SemVer = SemVer.ofString(getHaxelibVersion());
	static final VERSION_LONG:String = getHaxelibVersionLong();

	final command:Command;
	final mainArgs:Array<String>;
	final argsIterator:ArrayIterator<String>;
	final settings : {
		debug : Bool,
		quiet : Bool,
		flat : Bool,
		global : Bool,
		skipDependencies : Bool,
	};

	final server : ServerInfo;
	final siteUrl : String;
	final site : SiteProxy;

	final alreadyUpdatedVcsDependencies = new Map<String,String>();

	function new(args:ArgsInfo) {
		final always = args.flags.contains(Always);
		final never = args.flags.contains(Never);

		// argument parsing already took care of mutual exclusivity
		Cli.defaultAnswer =
			if (!always && !never) null // neither specified
			else (always && !never); // boolean logic

		updateCwd(args.repeatedOptions.get(Cwd));

		server = getServerInfo(args.flags.contains(NoTimeout), args.options.get(Remote));
		siteUrl = '${server.protocol}://${server.host}:${server.port}/${server.dir}';

		final remotingUrl = '${siteUrl}api/${server.apiVersion}/${server.url}';
		site = new SiteProxy(haxe.remoting.HttpConnection.urlConnect(remotingUrl).resolve("api"));

		command = args.command;
		mainArgs = args.mainArgs;
		argsIterator = mainArgs.iterator();

		settings = {
			debug: args.flags.contains(Debug),
			quiet:args.flags.contains(Quiet),
			flat : args.flags.contains(Flat),
			global : args.flags.contains(Global),
			skipDependencies : args.flags.contains(SkipDependencies)
		};
	}

	static function updateCwd(directories:Null<Array<String>>) {
		if (directories == null)
			return;
		for (dir in directories) {
			try {
				Sys.setCwd(dir);
			} catch (e:haxe.Exception) {
				if (e.toString() == "std@set_cwd")
					throw 'Directory $dir unavailable';
				rethrow(e);
			}
		}
	}

	static function getServerInfo(noTimeout:Bool, remote:Null<String>):ServerInfo {
		if (noTimeout)
			haxe.remoting.HttpConnection.TIMEOUT = 0;

		final noSsl = {
			final envVar = Sys.getEnv("HAXELIB_NO_SSL");
			(envVar == "1" || envVar == "true");
		}

		if (remote == null)
			remote = Sys.getEnv("HAXELIB_REMOTE");

		if (remote != null)
			return getFromRemote(remote, noSsl);

		return {
			protocol: !noSsl ? "https" : "http",
			host: "lib.haxe.org",
			port: 443,
			dir: "",
			url: "index.n",
			apiVersion: "3.0",
			noSsl: noSsl
		};
	}

	static function getFromRemote(remote:String, noSsl:Bool):ServerInfo {
		final r = ~/^(?:(https?):\/\/)?([^:\/]+)(?::([0-9]+))?\/?(.*)$/;
		if (!r.match(remote))
			throw "Invalid repository format '" + remote + "'";

		final protocol = if (r.matched(1) != null) r.matched(1) else !noSsl ? "https" : "http";
		final defaultPorts = [
			"https" => 443,
			"http" => 80
		];

		final port = switch (r.matched(3)) {
			case null if (defaultPorts.exists(protocol)): defaultPorts[protocol];
			case null: throw 'unknown default port for $protocol';
			case portStr:
				Std.parseInt(portStr);
		}
		final dir = {
			final dir = r.matched(4);
			if (dir.length > 0 && !dir.endsWith("/"))
				dir + "/";
			dir;
		}

		return {
			protocol: protocol,
			host: r.matched(2),
			port: port,
			dir: dir,
			url: "index.n",
			apiVersion: "3.0",
			noSsl: noSsl
		};
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
		final latest = try retry(site.getLatestVersion.bind(HAXELIB_LIBNAME)) catch (_:Dynamic) null;
		if (latest != null && latest > VERSION)
			print('\nA new version ($latest) of haxelib is available.\nDo `haxelib --global update $HAXELIB_LIBNAME` to get the latest version.\n');
	}

	function getArgument(prompt:String){
		final given = argsIterator.next();
		if (given != null)
			return given;
		Sys.print('$prompt : ');
		return Sys.stdin().readLine();
	}

	function getSecretArgument(prompt:String) {
		final given = argsIterator.next();
		if (given != null)
			return given;
		Sys.print('$prompt : ');
		final s = new StringBuf();
		do
			switch Sys.getChar(false) {
				case 10, 13:
					break;
				case 0: // ignore (windows bug)
				case c:
					s.addChar(c);
		} while (true);
		Sys.println("");
		return s.toString();
	}

	function version() {
		final params = argsIterator.next();
		print(VERSION_LONG);
	}

	static function usage() {
		var maxLength = 0;

		final switches = Args.generateSwitchDocs();
		for (option in switches){
			final length = '--${option.name}'.length;
			if(length > maxLength)
				maxLength = length;
		}

		final cats = [];
		for( c in Args.generateCommandDocs() ) {
			if ((c.name : String).length > maxLength)
				maxLength = (c.name : String).length;
			final i = c.cat.getIndex();
			if (cats[i] == null) cats[i] = [c];
			else cats[i].push(c);
		}

		print('Haxe Library Manager $VERSION - (c)2006-2019 Haxe Foundation');
		print("  Usage: haxelib [command] [options]");

		for (cat in cats) {
			print("  " + cat[0].cat.getName());
			for (c in cat) {
				print("    " + c.name.rpad(" ", maxLength) + ": " +c.doc);
			}
		}
		print("  Available switches");
		for (option in switches) {
			print('    --' + option.name.rpad(' ', maxLength-2) + ': ' + option.description);
		}
	}

	function mapCommands():Map<Command, CommandInfo> {
		function create(command:()->Void, maxArgs:Null<Int>, net = false, useInstead:String = null):CommandInfo
			return {command:command, maxArgs:maxArgs, net:net, useInstead:useInstead}

		return [
			Install => create(install, 2, true),
			Update => create(update, 1, true),
			Remove => create(remove, 2),
			List => create(list, 1),
			Set => create(set, 2, true),

			Search => create(search, 1, true),
			Info => create(info, 1, true),
			User => create(user, 1, true),
			Config => create(config, 0),
			Path => create(path, null),
			LibPath => create(libpath, null),
			Version => create(version, 0),
			Help => create(usage, 0),

			Submit => create(submit, 1, true),
			Register => create(register, 5, true),
			Dev => create(dev, 2),
			// TODO: generate command about VCS by Vcs.getAll()
			Git => create(vcs.bind(VcsID.Git), 5, true),
			Hg => create(vcs.bind(VcsID.Hg), 5, true),

			Setup => create(setup, 1),
			NewRepo => create(newRepo, 0),
			DeleteRepo => create(deleteRepo, 0),
			ConvertXml => create(convertXml, 0),
			Run => create(run, null),
			Proxy => create(proxy, 5, true),
			// deprecated commands
			Local => create(local, 1, 'haxelib --global update $HAXELIB_LIBNAME'),
			SelfUpdate => create(updateSelf, 0, true, 'haxelib install <file>' ),
		];
	}

	function process() {
		final commands = mapCommands();

		final commandInfo = commands[command];

		if (commandInfo.useInstead != null)
			Sys.println(
				'Warning: Command `$command` is deprecated and will be removed in future.\n'+
				'Use `${commandInfo.useInstead}` instead.'
			);

		if(commandInfo.maxArgs != null && mainArgs.length > commandInfo.maxArgs) {
			switch(commandInfo.maxArgs){
				case 0:
					final givenVerb = if (mainArgs.length == 1) "was" else "were";
					throw 'No arguments expected, but ${mainArgs.length} $givenVerb given.';
				case 1:
					throw 'A maximum of 1 argument expected, but ${mainArgs.length} were given.';
				case n:
					throw 'A maximum of $n arguments expected, but ${mainArgs.length} were given.';
			}
		}

		try {
			if (commandInfo.net) {
				loadProxy();
				checkUpdate();
			}
			commandInfo.command();
		} catch(e:haxe.Exception) {
			final errorMessage = giveErrorString(e.toString());
			if (errorMessage != null)
				throw errorMessage;
			rethrow(e);
		}
	}

	function giveErrorString(e:String):Null<String> {
		return switch (e) {
			case "std@host_resolve":
				"Host " + server.host + " was not found\n" +
				"Please ensure that your internet connection is on\n" +
				"If you don't have an internet connection or if you are behind a proxy\n" +
				"please download manually the file from https://lib.haxe.org/files/3.0/\n" +
				"and run 'haxelib install <file>' to install the Library." +
				"You can also setup the proxy with 'haxelib proxy'." +
				haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			case "Blocked":
				"Http connection timeout. Try running 'haxelib --no-timeout <command>' to disable timeout";
			case "std@get_cwd":
				"Current working directory is unavailable";
			case _:
				null;
		}
	}

	inline function createHttpRequest(url:String):Http {
		final req = new Http(url);
		req.addHeader("User-Agent", 'haxelib $VERSION_LONG');
		if (haxe.remoting.HttpConnection.TIMEOUT == 0)
			req.cnxTimeout = 0;
		return req;
	}

	// ---- COMMANDS --------------------

 	function search() {
		final word = getArgument("Search word");
		final l = retry(site.search.bind(word));
		for( s in l )
			print(s.name);
		print(l.length+" libraries found");
	}

	function info() {
		final prj = getArgument("Library name");
		final inf = retry(site.infos.bind(prj));
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
		final uname = getArgument("User name");
		final inf = retry(site.user.bind(uname));
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
		doRegister(getArgument("User"));
	}

	function doRegister(name) {
		final email = getArgument("Email");
		final fullname = getArgument("Fullname");
		final pass = getSecretArgument("Password");
		final pass2 = getSecretArgument("Confirm");
		if( pass != pass2 )
			throw "Password does not match";
		final encodedPassword = Md5.encode(pass);
		retry(site.register.bind(name, encodedPassword, email, fullname));
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
		final file = getArgument("Package");

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
				user = getArgument("User");
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
		var h = createHttpRequest(server.protocol+"://"+server.host+":"+server.port+"/"+server.url);
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
		var password = Md5.encode(getSecretArgument(prompt));
		var attempts = 5;
		while (!retry(site.checkPassword.bind(user, password))) {
			print('Invalid password for $user');
			if (--attempts == 0)
				throw 'Failed to input correct password';
			password = Md5.encode(getSecretArgument('$prompt ($attempts more attempt${attempts == 1 ? "" : "s"})'));
		}
		return password;
	}

	function install() {
		final rep = getRepository();

		final prj = getArgument("Library name or hxml file");

		// No library given, install libraries listed in *.hxml in given directory
		if( prj == "all") {
			installFromAllHxml(rep);
			return;
		}

		if( sys.FileSystem.exists(prj) && !sys.FileSystem.isDirectory(prj) ) {
			switch(prj){
				case hxml if (hxml.endsWith(".hxml")):
					// *.hxml provided, install all libraries/versions in this hxml file
					installFromHxml(rep, hxml);
					return;
				case zip if (zip.endsWith(".zip")):
					// *.zip provided, install zip as haxe library
					doInstallFile(rep, zip, true, true);
					return;
				case jsonPath if(jsonPath.endsWith("haxelib.json")):
					installFromHaxelibJson(rep, jsonPath);
					return;
			}
		}

		// Name provided that wasn't a local hxml or zip, so try to install it from server
		final inf = retry(site.infos.bind(prj));
		final reqversion = argsIterator.next();
		final version = getVersion(inf, reqversion);
		doInstall(rep, inf.name, version, version == inf.getLatest());
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

	function installFromHaxelibJson( rep:String, path:String ) {
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
		if (FileSystem.exists(haxe.io.Path.join([rep, Data.safe(project), Data.safe(version)])) ) {
			print("You already have "+project+" version "+version+" installed");
			setCurrent(rep,project,version,true);
			return;
		}

		// download to temporary file
		final filename = Data.fileName(project,version);
		final filepath = haxe.io.Path.join([rep, filename]);

		print("Downloading "+filename+"...");

		final maxRetry = 3;
		final fileUrl = haxe.io.Path.join([siteUrl, Data.REPOSITORY, filename]);
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

	function getRepository():String {
		if (settings.global)
			return RepoManager.getGlobalRepository();
		return RepoManager.findRepository(Sys.getCwd());
	}

	function setup() {
		var rep = RepoManager.suggestGlobalRepositoryPath();

		final prompt = 'Please enter haxelib repository path with write access\n'
				+ 'Hit enter for default ($rep)\n'
				+ 'Path';

		var line = getArgument(prompt);
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

		rep = try FileSystem.absolutePath(rep) catch (e:Dynamic) rep;

		RepoManager.saveSetup(rep);

		print("haxelib repository is now " + rep);
	}

	function config() {
		print(getRepository());
	}

	static function getCurrent( proj, dir ) {
		return try { getDev(dir); return "dev"; } catch( e : Dynamic ) try File.getContent(dir + "/.current").trim() catch( e : Dynamic ) throw "Library "+proj+" is not installed : run 'haxelib install "+proj+"'";
	}

	static function getDev( dir ) {
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
		var filter = argsIterator.next();
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

		var prj = argsIterator.next();
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
		var prj = getArgument("Library");
		var version = argsIterator.next();
		var pdir = rep + Data.safe(prj);
		if( version == null ) {
			if( !FileSystem.exists(pdir) )
				throw "Library "+prj+" is not installed";

			if (prj == HAXELIB_LIBNAME && (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME))
				throw 'Removing "$HAXELIB_LIBNAME" requires the --system flag';

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
		setCurrent(getRepository(), getArgument("Library"), getArgument("Version"), false);
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
		l.add({
			project: prj,
			version: version,
			dir: haxe.io.Path.addTrailingSlash(vdir), info: inf }
		);
		if( returnDependencies ) {
			for( d in inf.dependencies )
				if( !Lambda.exists(l, function(e) return e.project == d.name) )
					checkRec(rep,d.name,if( d.version == "" ) null else d.version,l);
		}
	}

	function path() {
		var rep = getRepository();
		var list = new List();
		var libInfo:Array<String>;
		for(arg in argsIterator){
			libInfo = arg.split(":");
			try {
				checkRec(rep, libInfo[0], libInfo[1], list);
			} catch(e:Dynamic) {
				throw 'Cannot process $libInfo: $e';
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
				dir = haxe.io.Path.addTrailingSlash( d.dir + cp );
			}
			Sys.println(dir);

			Sys.println("-D " + d.project + "="+d.info.version);
		}
	}

	function libpath( ) {
		final rep = getRepository();
		var libInfo:Array<String>;
		for(arg in argsIterator ) {
			libInfo = arg.split(":");
			final results = new List();
			checkRec(rep, libInfo[0], libInfo[1], results, false);
			if( !results.isEmpty() ) Sys.println(results.first().dir);
		}
	}

	function dev() {
		final rep = getRepository();
		final project = getArgument("Library");
		var dir = argsIterator.next();
		final proj = rep + Data.safe(project);
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
		// TODO: ask if existing repo have changes.

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
		useVcs(id, function(vcs)
			doVcsInstall(
				rep, vcs, getArgument("Library name"),
				getArgument(vcs.name + " path"), argsIterator.next(),
				argsIterator.next(), argsIterator.next()
			)
		);
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
		final rep = getRepository();
		final project = getArgument("Library");
		final libInfo = project.split(":");
		doRun(rep, libInfo[0], [for (arg in argsIterator) arg], libInfo[1], settings.global);
	}

	static var haxeVersion(get, null):SemVer;
	static function get_haxeVersion():SemVer {
		if(haxeVersion == null) {
			var p = new Process('haxe', ['--version']);
			if(p.exitCode() != 0) {
				throw 'Cannot get haxe version: ${p.stderr.readAll().toString()}';
			}
			var str = p.stdout.readAll().toString();
			haxeVersion = SemVer.ofString(str.split('+')[0]);
		}
		return haxeVersion;
	}

	static function doRun( rep:String, project:String, args:Array<String>, ?version:String, global = false ) {
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

		final scriptArgs =
			if (infos.main != null) {
				runScriptArgs(project, infos.main, infos.dependencies, global);
			} else if(FileSystem.exists('$vdir/run.n')) {
				["neko", vdir + "/run.n"];
			} else if(FileSystem.exists('$vdir/Run.hx')) {
				runScriptArgs(project, 'Run', infos.dependencies, global);
			} else {
				throw 'Library $project version $version does not have a run script';
			}

		final cmd = scriptArgs.shift();
		final callArgs = scriptArgs.concat(args);

		callArgs.push(Sys.getCwd());
		Sys.setCwd(vdir);

		Sys.putEnv("HAXELIB_RUN", "1");
		Sys.putEnv("HAXELIB_RUN_NAME", project);
 		Sys.exit(Sys.command(cmd, callArgs));
	}

	static function runScriptArgs(project:String, main:String, dependencies:Dependencies, global:Bool):Array<String> {
		var deps = dependencies.toArray();
		deps.push( { name: project, version: DependencyVersion.DEFAULT } );
		var args = [];
		// TODO: change comparison to '4.0.0' upon Haxe 4.0 release
		if(global && SemVer.compare(haxeVersion, SemVer.ofString('4.0.0-rc.5')) >= 0) {
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
		final rep = getRepository();
		final host = getArgument("Proxy host");
		if( host == "" ) {
			if( FileSystem.exists(rep + "/.proxy") ) {
				FileSystem.deleteFile(rep + "/.proxy");
				print("Proxy disabled");
			} else
				print("No proxy specified");
			return;
		}
		final port = Std.parseInt(getArgument("Proxy port"));
		final authName = getArgument("Proxy user login");
		final authPass = authName == "" ? "" : getArgument("Proxy user pass");
		final proxy = {
			host : host,
			port : port,
			auth : authName == "" ? null : { user : authName, pass : authPass },
		};
		Http.PROXY = proxy;
		print("Testing proxy...");
		try Http.requestUrl(server.protocol + "://lib.haxe.org") catch( e : Dynamic ) {
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
		final cwd = Sys.getCwd();
		final xmlFile = cwd + "haxelib.xml";
		final jsonFile = cwd + "haxelib.json";

		if (!FileSystem.exists(xmlFile)) {
			print('No `haxelib.xml` file was found in the current directory.');
			return;
		}

		final xmlString = File.getContent(xmlFile);
		final json = haxelib.client.ConvertXml.convert(xmlString);
		final jsonString = haxelib.client.ConvertXml.prettyPrint(json);

		File.saveContent(jsonFile, jsonString);
		print('Saved to $jsonFile');
	}

	function newRepo() {
		final path = RepoManager.newRepo(Sys.getCwd());
		print('Local repository created ($path)');
	}

	function deleteRepo() {
		final path = RepoManager.deleteRepo(Sys.getCwd());
		print('Local repository deleted ($path)');
	}

	// ----------------------------------

	public static inline function print(str)
		Sys.println(str);

	static function main() {
		final args = Sys.args();
		final isHaxelibRun = (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME);
		if (isHaxelibRun)
			Sys.setCwd(args.pop());

		final priorityFlags = Args.extractPriorityFlags(args);

		final repoPath = try RepoManager.getGlobalRepository() catch (_:Dynamic) null;
		// if haxelib hasn't already been run, --system is not specified, and the updated version is installed,
		if (!isHaxelibRun && !priorityFlags.contains(System) && repoPath != null && FileSystem.exists(repoPath + HAXELIB_LIBNAME) ){
			try {
				doRun(repoPath, HAXELIB_LIBNAME, args, priorityFlags.contains(Global));
				return;
			} catch (e:haxe.Exception) {
				Sys.println('Warning: failed to run updated haxelib: $e');
				Sys.println('Warning: resorting to system haxelib...');
			}
		}

		final argsInfo =
			try {
				Args.extractAll(args);
			} catch (e:SwitchError) {
				Sys.stderr().writeString('${e.message}\n');
				Sys.exit(1);
				return;
			} catch (e:InvalidCommand) {
				if (e.message != "")
					Sys.stderr().writeString('${e.message}\n');
				usage();
				Sys.exit(1);
				return;
			}

		try {
			final main = new Main(argsInfo);
			main.process();
		} catch (e:haxe.Exception) {
			if (priorityFlags.contains(Debug))
				rethrow(e);
			Sys.stderr().writeString('Error: ${e.message}\n');
			Sys.exit(1);
			return;
		};

		Sys.exit(0);
	}

	// deprecated commands
	function local() {
		doInstallFile(getRepository(), getArgument("Package"), true, true);
	}

	function updateSelf() {
		updateByName(RepoManager.getGlobalRepository(), HAXELIB_LIBNAME);
	}
}
