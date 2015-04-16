/*
 * Copyright (C)2005-2012 Haxe Foundation
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
package tools.haxelib;

import haxe.crypto.Md5;
import haxe.*;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.*;
import sys.io.File;
import sys.FileSystem;
import sys.io.*;
import haxe.ds.Option;
import tools.haxelib.Vcs;

using StringTools;
using Lambda;
using tools.haxelib.Data;

enum Answer {
	Yes;
	No;
}

private enum CommandCategory {
	Basic;
	Information;
	Development;
	Miscellaneous;
}

class SiteProxy extends haxe.remoting.Proxy<tools.haxelib.SiteApi> {
}

class Progress extends haxe.io.Output {

	var o : haxe.io.Output;
	var cur : Int;
	var max : Int;
	var start : Float;

	public function new(o) {
		this.o = o;
		cur = 0;
		start = Timer.stamp();
	}

	function bytes(n) {
		cur += n;
		if( max == null )
			Sys.print(cur+" bytes\r");
		else
			Sys.print(cur+"/"+max+" ("+Std.int((cur*100.0)/max)+"%)\r");
	}

	public override function writeByte(c) {
		o.writeByte(c);
		bytes(1);
	}

	public override function writeBytes(s,p,l) {
		var r = o.writeBytes(s,p,l);
		bytes(r);
		return r;
	}

	public override function close() {
		super.close();
		o.close();
		var time = Timer.stamp() - start;
		var speed = (cur / time) / 1024;
		time = Std.int(time * 10) / 10;
		speed = Std.int(speed * 10) / 10;
		Sys.print("Download complete : "+cur+" bytes in "+time+"s ("+speed+"KB/s)\n");
	}

	public override function prepare(m) {
		max = m;
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
		doRead(1);
		return c;
	}

	public override function readBytes(buf,pos,len) {
		var k = i.readBytes(buf,pos,len);
		doRead(k);
		return k;
	}

	function doRead( nbytes : Int ) {
		pos += nbytes;
		Sys.print( Std.int((pos * 100.0) / tot) + "%\r" );
	}

}

enum CliError
{
	CwdUnavailable(pwd:String);
	CantSetSwd_DirNotExist(dir:String);
}

class Cli
{
	public var defaultAnswer(get, set):Answer;
	private static var defaultAnswer_global:Answer;

	public var cwd(get_cwd, set_cwd):String;
	private static var cwd_cache:String = null;


	public function new()
		defaultAnswer = null;


	function get_cwd():String
	{
		var result:String = null;

		try
		{
			cwd_cache = Sys.getCwd();
		}
		catch(error:String)
			tryFixGetCwdError(error);

		return cwd_cache;
	}

	function set_cwd(value:String):String
	{
		//TODO: For call `FileSystem.isDirectory(value)` we can get an exeption "std@sys_file_type":
		if(value != null && cwd_cache != value && FileSystem.exists(value) && FileSystem.isDirectory(value))
			Sys.setCwd(cwd_cache = value);
		else
			throw CliError.CantSetSwd_DirNotExist(value);
		return cwd_cache;
	}


	function tryFixGetCwdError(error:String)
	{
		switch(error)
		{
			case "std@get_cwd" | "std@file_path" | "std@file_full_path":
				{
					var pwd = Sys.getEnv("PWD");
					// This is a magic for issue #196:
					// if we have $PWD then we can re-set it again.
					// Works for case: `$ mkdir temp; cd temp; rm -r ../temp; mkdir ../temp; haxelib upgrade;`
					if(pwd != null)
					{
						if(FileSystem.exists(pwd) && FileSystem.isDirectory(pwd))
							// Trying fix it: setting cwd to pwd
							Sys.setCwd(cwd_cache = pwd);
						else
							// Can't fix it.
							throw CliError.CwdUnavailable(pwd);
					}
					else throw CliError.CwdUnavailable(pwd);
				}
			default: throw error;
		}
	}


	function get_defaultAnswer():Answer
	{
		return defaultAnswer_global;
	}

	function set_defaultAnswer(value:Answer):Answer
	{
		defaultAnswer_global = value;
		return defaultAnswer_global;
	}


	public function ask(question):Answer
	{
		if(defaultAnswer != null)
			return defaultAnswer;

		while(true)
		{
			Sys.print(question + " [y/n/a] ? ");
			try{
				switch(Sys.stdin().readLine())
				{
					case "n": return No;
					case "y": return Yes;
					case "a": return defaultAnswer = Yes;
				}
			}
			catch(e:haxe.io.Eof)
			{
				Sys.println("n");
				return No;
			}
		}
		return null;
	}

	public function command(cmd:String, args:Array<String>)
	{
		var p = new sys.io.Process(cmd, args);
		var code = p.exitCode();
		return {code:code, out:(code == 0 ? p.stdout.readAll().toString() : p.stderr.readAll().toString())};
	}

	public function print(str):Void
	{
		Sys.print(str + "\n");
	}
}

class Main {

	static var VERSION = SemVer.ofString('3.2.0-rc.3');
	static var APIVERSION = SemVer.ofString('3.0.0');
	static var REPNAME = "lib";
	static var REPODIR = ".haxelib";
	static var SERVER = {
		host : "lib.haxe.org",
		port : 80,
		dir : "",
		url : "index.n",
		apiVersion : APIVERSION.major+"."+APIVERSION.minor,
	};

	var cli:Cli;
	var argcur : Int;
	var args : Array<String>;
	var commands : List<{ name : String, doc : String, f : Void -> Void, net : Bool, cat : CommandCategory }>;
	var siteUrl : String;
	var site : SiteProxy;


	function new()
	{
		cli = new Cli();
		args = Sys.args();

		commands = new List();
		addCommand("install", install, "install a given library, or all libraries from a hxml file", Basic);
		addCommand("upgrade", upgrade, "upgrade all installed libraries", Basic);
		addCommand("update", update, "update a single library", Basic);
		addCommand("remove", remove, "remove a given library/version", Basic, false);
		addCommand("list", list, "list all installed libraries", Basic, false);
		addCommand("set", set, "set the current version for a library", Basic, false);

		addCommand("search", search, "list libraries matching a word", Information);
		addCommand("info", info, "list information on a given library", Information);
		addCommand("user", user, "list information on a given user", Information);
		addCommand("config", config, "print the repository path", Information, false);
		addCommand("path", path, "give paths to libraries", Information, false);
		addCommand("version", version, "print the currently using haxelib version", Information, false);
		addCommand("help", usage, "display this list of options", Information, false);

		addCommand("submit", submit, "submit or update a library package", Development);
		addCommand("register", register, "register a new user", Development);
		addCommand("local", local, "install the specified package locally", Development, false);
		addCommand("dev", dev, "set the development directory for a given library", Development, false);
		//TODO: generate command about VCS by Vcs.getAll()
		addCommand("git", function()doVcs(VcsID.Git), "use Git repository as library", Development);
		addCommand("hg", function()doVcs(VcsID.Hg), "use Mercurial (hg) repository as library", Development);

		addCommand("setup", setup, "set the haxelib repository path", Miscellaneous, false);
		addCommand("newrepo", newRepo, "[EXPERIMENTAL] create a new local repository", Miscellaneous, false);
		addCommand("deleterepo", deleteRepo, "delete the local repository", Miscellaneous, false);
		addCommand("selfupdate", updateSelf, "update haxelib itself", Miscellaneous);
		addCommand("convertxml", convertXml, "convert haxelib.xml file to haxelib.json", Miscellaneous);
		addCommand("run", run, "run the specified library with parameters", Miscellaneous, false);
		addCommand("proxy", proxy, "setup the Http proxy", Miscellaneous);

		initSite();
	}



	function initSite() {
		siteUrl = "http://" + SERVER.host + ":" + SERVER.port + "/" + SERVER.dir;
		var remotingUrl =  siteUrl + "api/" + SERVER.apiVersion + "/" + SERVER.url;
		site = new SiteProxy(haxe.remoting.HttpConnection.urlConnect(remotingUrl).api);
	}

	function param( name, ?passwd ) {
		if( args.length > argcur )
			return args[argcur++];
		Sys.print(name+" : ");
		if( passwd ) {
			var s = new StringBuf();
			do switch Sys.getChar(false) {
				case 10, 13: break;
				case c: s.addChar(c);
			}
			while (true);
			print("");
			return s.toString();
		}
		return Sys.stdin().readLine();
	}

	inline function ask(question)
		return cli.ask(question);

	function paramOpt() {
		if( args.length > argcur )
			return args[argcur++];
		return null;
	}

	function addCommand( name, f, doc, cat, ?net = true ) {
		commands.add({ name : name, doc : doc, f : f, net : net, cat : cat });
	}

	function version() {
		print(VERSION);
	}

	function usage() {
		var cats = [];
		var maxLength = 0;
		for( c in commands ) {
			if (c.name.length > maxLength) maxLength = c.name.length;
			var i = c.cat.getIndex();
			if (cats[i] == null) cats[i] = [c];
			else cats[i].push(c);
		}

		print("Haxe Library Manager " + VERSION + " - (c)2006-2015 Haxe Foundation");
		print("  Usage: haxelib [command] [options]");

		for (cat in cats) {
			print("  " + cat[0].cat.getName());
			for (c in cat) {
				print("    " + StringTools.rpad(c.name, " ", maxLength) + ": " +c.doc);
			}
		}

		print("  Available switches");
		for (f in Reflect.fields(ABOUT_SETTINGS))
			print('    --' + f.rpad(' ', maxLength-2) + ": " + Reflect.field(ABOUT_SETTINGS, f));
	}
	static var ABOUT_SETTINGS = {
		global : "force global repo if a local one exists",
		debug  : "run in debug mode",
		flat   : "do not use --recursive cloning for git",
		always : "answer all questions with yes",
		never  : "answer all questions with no"
	}

	var settings: {
		debug  : Bool,
		flat   : Bool,
		always : Bool,
		never  : Bool,
		global : Bool,
	};
	function process() {
		argcur = 0;
		var rest = [];
		settings = {
			debug: false,
			always: false,
			never: false,
			flat: false,
			global: false,
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

		while ( argcur < args.length) {
			var a = args[argcur++];
			switch( a ) {
				case '-cwd': cli.cwd = args[argcur++];
				case "-notimeout":
					haxe.remoting.HttpConnection.TIMEOUT = 0;
				case "-R":
					var path = args[argcur++];
					var r = ~/^(http:\/\/)?([^:\/]+)(:[0-9]+)?\/?(.*)$/;
					if( !r.match(path) )
						throw "Invalid repository format '"+path+"'";
					SERVER.host = r.matched(2);
					if( r.matched(3) != null )
						SERVER.port = Std.parseInt(r.matched(3).substr(1));
					SERVER.dir = r.matched(4);
					if (SERVER.dir.length > 0 && !SERVER.dir.endsWith("/")) SERVER.dir += "/";
					initSite();
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

		cli.defaultAnswer =
			switch [settings.always, settings.never] {
				case [true, true]:
					print('--always and --never are mutually exclusive');
					Sys.exit(1);
					null;
				case [true, _]: Yes;
				case [_, true]: No;
				default: null;
			}

		argcur = 0;
		args = rest;

		var cmd = args[argcur++];
		if( cmd == null ) {
			usage();
			Sys.exit(1);
		}
		for( c in commands )
			if( c.name == cmd ) {
				try {
					if( c.net ) loadProxy();
					c.f();
				} catch( e : Dynamic ) {
					if( e == "std@host_resolve" ) {
						print("Host "+SERVER.host+" was not found");
						print("Please ensure that your internet connection is on");
						print("If you don't have an internet connection or if you are behing a proxy");
						print("please download manually the file from http://lib.haxe.org/files/3.0/");
						print("and run 'haxelib local <file>' to install the Library.");
						print("You can also setup the proxy with 'haxelib proxy'.");
						Sys.exit(1);
					}
					if( e == "Blocked" ) {
						print("Http connection timeout. Try running haxelib -notimeout <command> to disable timeout");
						Sys.exit(1);
					}
					if( settings.debug )
						neko.Lib.rethrow(e);
					print(Std.string(e));
					Sys.exit(1);
				}
				return;
			}
		print("Unknown command "+cmd);
		usage();
		Sys.exit(1);
	}

	// ---- COMMANDS --------------------

 	function search() {
		var word = param("Search word");
		var l = site.search(word);
		for( s in l )
			print(s.name);
		print(l.length+" libraries found");
	}

	function info() {
		var prj = param("Library name");
		var inf = site.infos(prj);
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
		var inf = site.user(uname);
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
		site.register(name,pass,email,fullname);
		return pass;
	}

	function submit() {
		var file = param("Package"),
			data = null;
		var zip =
			if (FileSystem.isDirectory(file)) {
				var ret = new List<Entry>(),
					out = new BytesOutput();
				function seek(dir:String) {
					for (name in FileSystem.readDirectory(dir)) if (!name.startsWith('.')) {
						var full = '$dir/$name';
						if (FileSystem.isDirectory(full)) seek(full);
						else {
							var blob = File.getBytes(full);
							ret.push({
								fileName: full.substr(file.length+1),
								fileSize : blob.length,
								fileTime : FileSystem.stat(full).mtime,
								compressed : false,
								dataSize : blob.length,
								data : blob,
								crc32: null,//TODO: consider calculating this one
							});
						}
					}
				}
				seek(file);
				new Writer(out).write(ret);
				data = out.getBytes();
				ret;
			}
			else {
				data = File.getBytes(file);
				Reader.readZip(File.read(file, true));
			}

		var infos = Data.readInfos(zip,true);
		Data.checkClassPath(zip, infos);

		var user:String = infos.contributors[0];

		if (infos.contributors.length > 1)
			do {
				print("Which of these users are you: " + infos.contributors);
				user = param("User");
			} while ( !Lambda.has(infos.contributors, user) );

		var password;
		if( site.isNewUser(user) ) {
			print("This is your first submission as '"+user+"'");
			print("Please enter the following informations for registration");
			password = doRegister(user);
		} else {
			password = Md5.encode(param("Password",true));
			var attempts = 5;
			while ( !site.checkPassword(user, password)) {
				print ("Invalid password for " + user);
				if (--attempts == 0)
					throw 'Failed to input correct password';
				password = Md5.encode(param('Password ($attempts more attempt${attempts == 1 ? "" : "s"})', true));
			}
		}
		site.checkDeveloper(infos.name,user);

		// check dependencies validity
		for( d in infos.dependencies ) {
			var infos = site.infos(d.name);
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

		var sinfos = try site.infos(infos.name) catch( _ : Dynamic ) null;
		if( sinfos != null )
			for( v in sinfos.versions )
				if( v.name == infos.version && ask("You're about to overwrite existing version '"+v.name+"', please confirm") == No )
					throw "Aborted";

		// query a submit id that will identify the file
		var id = site.getSubmitId();

		// directly send the file data over Http
		var h = new Http("http://"+SERVER.host+":"+SERVER.port+"/"+SERVER.url);
		h.onError = function(e) { throw e; };
		h.onData = print;
		h.fileTransfer("file",id,new ProgressIn(new haxe.io.BytesInput(data),data.length),data.length);
		print("Sending data.... ");
		h.request(true);

		// processing might take some time, make sure we wait
		print("Processing file.... ");
		haxe.remoting.HttpConnection.TIMEOUT = 1000;
		// ask the server to register the sent file
		var msg = site.processSubmit(id,user,password);
		print(msg);
	}

	function install() {
		var prj = param("Library name or hxml file:");

		// No library given, install libraries listed in *.hxml in given directory
		if( prj == "all")
		{
			installFromAllHxml();
			return;
		}

		if( sys.FileSystem.exists(prj) && !sys.FileSystem.isDirectory(prj) ) {
			// *.hxml provided, install all libraries/versions in this hxml file
			if( prj.endsWith(".hxml") )
			{
				installFromHxml(prj);
				return;
			}
			// *.zip provided, install zip as haxe library
			if( prj.endsWith(".zip") )
			{
				doInstallFile(prj,true,true);
				return;
			}
		}

		// Name provided that wasn't a local hxml or zip, so try to install it from server
		var inf = site.infos(prj);
		var reqversion = paramOpt();
		var version = getVersion(inf, reqversion);
		doInstall(inf.name,version,version == inf.getLatest());
	}

	function getVersion( inf:ProjectInfos, ?reqversion:String )
	{
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

	function installFromHxml( path )
	{
		var hxml = sys.io.File.getContent(path);
		var lines = hxml.split("\n");
		var targets  = [
			'-java ' => 'hxjava',
			'-cpp ' => 'hxcpp',
			'-cs ' => 'hxcs',
		];
		var libsToInstall = new Map<String, {name:String,version:String}>();
		for (l in lines) {
			l = l.trim();
			for (target in targets.keys())
				if (l.startsWith(target)) {
					var lib = targets[target];
					if (!libsToInstall.exists(lib))
						libsToInstall[lib] = { name: lib, version: null }
				}

			if (l.startsWith("-lib"))
			{
				var key = l.substr(5);
				var parts = key.split(":");
				var libName = parts[0].trim();
				var libVersion = if (parts.length > 1) parts[1].trim() else null;

				switch libsToInstall[key] {
					case null, { version: null } :
						libsToInstall.set(key, { name:libName, version:libVersion } );
					default:
				}
			}
		}
		installMany(libsToInstall);
	}

	function installFromAllHxml()
	{
		var hxmlFiles = sys.FileSystem.readDirectory(cli.cwd).filter(function (f) return f.endsWith(".hxml"));
		if (hxmlFiles.length > 0)
		{
			for (file in hxmlFiles)
			{
				if (file.endsWith(".hxml"))
				{
					print('Installing all libraries from $file:');
					installFromHxml(cli.cwd+file);
				}
			}
		}
		else
		{
			print ("No hxml files found in the current directory.");
		}
	}

	function installMany( libs:Iterable<{name:String,version:String}>, ?setCurrent=true )
	{
		if (Lambda.count(libs) == 0) return;

		// Check the version numbers are all good
		// TODO: can we collapse this into a single API call?  It's getting too slow otherwise.
		print("Loading info about the required libraries");
		for (l in libs)
		{
			var inf = site.infos(l.name);
			l.version = getVersion(inf, l.version);
		}

		// Print a list with all the info
		print("Haxelib is going to install these libraries:");
		for (l in libs)
		{
			var vString = (l.version == null) ? "" : " - " + l.version;
			print("  " + l.name + vString);
		}

		// Install if they confirm
		if (ask("Continue?") != No)
		{
			for (l in libs)
			{
				doInstall(l.name, l.version, setCurrent);
			}
		}
	}

	function doInstall( project, version, setcurrent ) {
		var rep = getRepository();

		// check if exists already
		if( FileSystem.exists(rep+Data.safe(project)+"/"+Data.safe(version)) ) {
			print("You already have "+project+" version "+version+" installed");
			setCurrent(project,version,true);
			return;
		}

		// download to temporary file
		var filename = Data.fileName(project,version);
		var filepath = rep+filename;
		var out = try File.write(filepath,true)
			catch (e:Dynamic) throw 'Failed to write to $filepath: $e';

		var progress = new Progress(out);
		var h = new Http(siteUrl+Data.REPOSITORY+"/"+filename);
		h.onError = function(e) {
			progress.close();
			FileSystem.deleteFile(filepath);
			throw e;
		};
		print("Downloading "+filename+"...");
		h.customRequest(false,progress);

		doInstallFile(filepath, setcurrent);
		try {
			site.postInstall(project, version);
		} catch (e:Dynamic) {}
	}

	function doInstallFile(filepath,setcurrent,?nodelete) {
		// read zip content
		var f = File.read(filepath,true);
		var zip = Reader.readZip(f);
		f.close();
		var infos = Data.readInfos(zip,false);
		// create directories
		var pdir = getRepository() + Data.safe(infos.name);
		safeDir(pdir);
		pdir += "/";
		var target = pdir + Data.safe(infos.version);
		safeDir(target);
		target += "/";

		// locate haxelib.json base path
		var basepath = Data.locateBasePath(zip);

		// unzip content
		for( zipfile in zip ) {
			var n = zipfile.fileName;
			if( n.startsWith(basepath) ) {
				// remove basepath
				n = n.substr(basepath.length,n.length-basepath.length);
				if( n.charAt(0) == "/" || n.charAt(0) == "\\" || n.split("..").length > 1 )
					throw "Invalid filename : "+n;
				var dirs = ~/[\/\\]/g.split(n);
				var path = "";
				var file = dirs.pop();
				for( d in dirs ) {
					path += d;
					safeDir(target+path);
					path += "/";
				}
				if( file == "" ) {
					if( path != "" ) print("  Created "+path);
					continue; // was just a directory
				}
				path += file;
				print("  Install "+path);
				var data = Reader.unzip(zipfile);
				File.saveBytes(target+path,data);
			}
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
		doInstallDependencies(infos.dependencies);

		return infos;
	}

	function doInstallDependencies( dependencies:Array<Dependency> )
	{
		for( d in dependencies ) {
			print("Installing dependency "+d.name+" "+d.version);
			if( d.version == "" )
				d.version = site.infos(d.name).getLatest();

			switch d.type {
				case Haxelib:
					doInstall(d.name, d.version, false);
				case Git:
					doVcs(VcsID.Git, d.name, d.url, d.branch, d.subDir, d.version);
				//TODO: add mercurial-dependency type to schema.json (https://github.com/HaxeFoundation/haxelib/blob/master/schema.json#L38)
				case Mercurial:
					doVcs(VcsID.Hg, d.name, d.url, d.branch, d.subDir, d.version);
			}
		}
	}

	function safeDir( dir ) {
		if( FileSystem.exists(dir) ) {
			if( !FileSystem.isDirectory(dir) )
				throw ("A file is preventing "+dir+" to be created");
		}
		try {
			FileSystem.createDirectory(dir);
		} catch( e : Dynamic ) {
			throw "You don't have enough user rights to create the directory "+dir;
		}
		return true;
	}

	function safeDelete( file ) {
		try {
			FileSystem.deleteFile(file);
			return true;
		} catch (e:Dynamic) {
			if( Sys.systemName() == "Windows") {
				try {
					Sys.command("attrib", ["-R", file]);
					FileSystem.deleteFile(file);
					return true;
				} catch (e:Dynamic) {
				}
			}
			return false;
		}
	}

	function getRepository( ?setup : Bool ) {

		if( !setup && !settings.global && FileSystem.exists(REPODIR) && FileSystem.isDirectory(REPODIR) ) {
			var absolutePath = Path.join([cli.cwd, REPODIR]);//TODO: we actually might want to get the real path here
			return Path.addTrailingSlash(absolutePath);
		}

		var win = Sys.systemName() == "Windows";
		var haxepath = Sys.getEnv("HAXEPATH");
		if( haxepath != null )
			haxepath = Path.addTrailingSlash( haxepath );
		var envPath = Sys.getEnv("HAXELIB_PATH");
		var config_file;
		if( win )
			config_file = Sys.getEnv("HOMEDRIVE") + Sys.getEnv("HOMEPATH");
		else
			config_file = Sys.getEnv("HOME");
		config_file += "/.haxelib";
		var rep = if (envPath != null)
			envPath
		else try
			File.getContent(config_file)
		catch( e : Dynamic ) try
			File.getContent("/etc/.haxelib")
		catch( e : Dynamic ) {
			if( setup ) {
				(if (win)
					haxepath;
				else if (FileSystem.exists("/usr/share/haxe"))
					"/usr/share/haxe";
				else
					"/usr/lib/haxe")+REPNAME;
			} else if( win ) {
				// Windows have a default directory (no need for setup)
				if( haxepath == null )
					throw "HAXEPATH environment variable not defined, please run haxesetup.exe first";
				var rep = haxepath+REPNAME;
				try {
					safeDir(rep);
				} catch( e : String ) {
					throw "Error accessing Haxelib repository: $e";
				}
				return Path.addTrailingSlash( rep );
			} else
				throw "This is the first time you are runing haxelib. Please run `haxelib setup` first";
		}
		rep = rep.trim();
		if( setup ) {
			if( args.length <= argcur ) {
				print("Please enter haxelib repository path with write access");
				print("Hit enter for default (" + rep + ")");
			}
			var line = param("Path");
			if( line != "" )
				rep = line;
			if( !FileSystem.exists(rep) ) {
				try {
					FileSystem.createDirectory(rep);
				} catch( e : Dynamic ) {
					print("Failed to create directory '"+rep+"' ("+Std.string(e)+"), maybe you need appropriate user rights");
					print("Check also that the parent directory exists");
					Sys.exit(1);
				}
			}
			rep = try FileSystem.fullPath(rep) catch( e : Dynamic ) rep;
			File.saveContent(config_file, rep);
		} else if( !FileSystem.exists(rep) ) {
			throw "haxelib Repository "+rep+" does not exist. Please run `haxelib setup` again";
		} else if ( !FileSystem.isDirectory(rep) ) {
			throw "haxelib Repository "+rep+" exists, but was a file, not a directory.  Please remove it and run `haxelib setup` again.";
		}
		return rep+"/";
	}

	function setup() {
		var path = getRepository(true);
		print("haxelib repository is now "+path);
	}

	function config() {
		print(getRepository());
	}

	function getCurrent( dir ) {
		return (FileSystem.exists(dir+"/.dev")) ? "dev" : File.getContent(dir + "/.current").trim();
	}

	function getDev( dir ) {
		return File.getContent(dir + "/.dev").trim();
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
			var versions = new Array();
			var current = try getCurrent(rep + p) catch(e:Dynamic) continue;
			var dev = try File.getContent(rep+p+"/.dev").trim() catch( e : Dynamic ) null;
			for( v in FileSystem.readDirectory(rep+p) ) {
				if( v.charAt(0) == "." )
					continue;
				v = Data.unsafe(v);
				if( dev == null && v == current )
					v = "["+v+"]";
				versions.push(v);
			}
			if( dev != null )
				versions.push("[dev:"+dev+"]");
			all.push(Data.unsafe(p) + ": "+versions.join(" "));
		}
		all.sort(function(s1, s2) return Reflect.compare(s1.toLowerCase(), s2.toLowerCase()));
		for (p in all) {
			print(p);
		}
	}

	function upgrade() {
		var state = { rep : getRepository(), prompt : true, updated : false };
		for( p in FileSystem.readDirectory(state.rep) ) {
			if( p.charAt(0) == "." || !FileSystem.isDirectory(state.rep+"/"+p) )
				continue;
			var p = Data.unsafe(p);
			print("Checking " + p);
			try doUpdate(p, state)
			catch (e:Dynamic)
				if (e != VcsError.VcsUnavailable) neko.Lib.rethrow(e);
		}
		if( state.updated )
			print("Done");
		else
			print("All libraries are up-to-date");
	}

	function doUpdate( p : String, state ) {
		var rep = state.rep;

		//TODO: get content from `.current` and use vcs only if there "dev".

		var vcs:Vcs = Vcs.getVcsForDevLib(rep + "/" + p);
		if(vcs != null)
		{
			if(!vcs.available)
				throw VcsError.VcsUnavailable;

			var oldCwd = cli.cwd;
			cli.cwd = (rep + "/" + p + "/" + vcs.directory);
			var success = vcs.update(p, cast settings);

			state.updated = success;
			cli.cwd = oldCwd;
		}
		else
		{
			var inf = try site.infos(p) catch( e : Dynamic ) { Sys.println(e); return; };
			if( !FileSystem.exists(rep+Data.safe(p)+"/"+Data.safe(inf.getLatest())) ) {
				if( state.prompt )
					switch ask("Update "+p+" to "+inf.getLatest()) {
					case Yes:
					case No:
						return;
					}
				doInstall(p,inf.getLatest(),true);
				state.updated = true;
			} else
				setCurrent(p, inf.getLatest(), true);
		}
	}
	function updateByName(prj:String) {
		var state = { rep : getRepository(), prompt : false, updated : false };
		doUpdate(prj,state);
		return state.updated;
	}
	function update() {
		var prj = param('Library');
		if (!updateByName(prj))
			print(prj + " is up to date");
	}

	//recursively follow symlink
	static function realPath(path:String):String {
		return switch (new Process('readlink', [path.endsWith("\n") ? path.substr(0, path.length-1) : path]).stdout.readAll().toString()) {
			case "": //it is not a symlink
				path;
			case targetPath:
				if (targetPath.startsWith("/")) {
					realPath(targetPath);
				} else {
					realPath(new Path(path).dir + "/" + targetPath);
				}
		}
	}

	function rebuildSelf() {
		var win = Sys.systemName() == "Windows";
		var haxepath =
			if (win) Sys.getEnv("HAXEPATH");
			else new Path(realPath(new Process('which', ['haxelib']).stdout.readAll().toString())).dir + '/';

		cli.cwd = haxepath;
		function tryBuild() {
			var p = new Process('haxe', ['-neko', 'test.n', '-lib', 'haxelib_client', '-main', 'tools.haxelib.Main', '--no-output']);
			return
				if (p.exitCode() == 0) None;
				else Some(p.stderr.readAll().toString());
		}


		switch tryBuild() {
			case None:

				if (haxepath == null)
					throw (win ? 'HAXEPATH environment variable not defined' : 'unable to locate haxelib through `which haxelib`');
				else
					haxepath = Path.addTrailingSlash(haxepath);

				if (win) {
					Sys.command('start', ['haxe', '-lib', 'haxelib_client', '--run', 'tools.haxelib.Rebuild']);
					print('rebuild launched');
				}
				else {
					var p = new Process('haxelib', ['path', 'haxelib_client']);
					if (p.exitCode() == 0) {
						var args = [];
						var classPath = "";
						for (arg in p.stdout.readAll().toString().split('\n')) {
							arg = arg.trim();
							if (arg.charAt(0) == '-')
								args.push(arg);
							else if (arg.length > 0)
								classPath = arg;
						};

						var file = haxepath+'haxelib';
						try File.saveContent(
							file,
							'#!/bin/sh'
							+'\n'+'OLDCWD=`pwd`'
							+'\n'+'cd $classPath'
							+'\n'+'exec haxe '+args.join(' ')+" --run tools.haxelib.Main -cwd $OLDCWD $@"
						)
						catch (e:Dynamic)
							throw 'Error writing file $file. Please ensure you have write permissions. \n  ' + Std.string(e);
					}
					else throw p.stdout.readAll();
				}
			case Some(error):
				throw 'Error compiling haxelib client: $error';
		}

	}

	function updateSelf() {
		settings.global = true;
		if (updateByName('haxelib_client'))
			print("Haxelib successfully updated.");
		else
			print("Haxelib was already up to date...");

		rebuildSelf();
	}

	function deleteRec(dir)
	{
		if(!FileSystem.exists(dir)) return;

		for(p in FileSystem.readDirectory(dir))
		{
			var path = Path.join([dir, p]);

			if(isBrokenSymlink(path))
				safeDelete(path);
			else
			if(FileSystem.isDirectory(path))
			{
				// if isSymLink:
				if(Sys.systemName() != "Windows" && path != FileSystem.fullPath(path))
					safeDelete(path);
				else
					deleteRec(path);
			}
			else
				safeDelete(path);
		}
		FileSystem.deleteDirectory(dir);
	}

	function isBrokenSymlink(path:String):Bool
	{
		var errors:Int = 0;
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

	function remove() {
		var prj = param("Library");
		var version = paramOpt();
		var rep = getRepository();
		var pdir = rep + Data.safe(prj);
		if( version == null ) {
			if( !FileSystem.exists(pdir) )
				throw "Library "+prj+" is not installed";
			deleteRec(pdir);
			print("Library "+prj+" removed");
			return;
		}

		var vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) )
			throw "Library "+prj+" does not have version "+version+" installed";

		var cur = getCurrent(pdir);
		if( cur == version )
			throw "Can't remove current version of library "+prj;
		deleteRec(vdir);
		print("Library "+prj+" version "+version+" removed");
	}

	function set() {
		var prj = param("Library");
		var version = param("Version");
		setCurrent(prj,version,false);
	}

	function setCurrent( prj : String, version : String, doAsk : Bool ) {
		var pdir = getRepository() + Data.safe(prj);
		var vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) ){
			print("Library "+prj+" version "+version+" is not installed");
			if(ask("Would you like to install it?") != No)
				doInstall(prj, version, true);
			return;
		}
		if( getCurrent(pdir) == version )
			return;
		if( doAsk && ask("Set "+prj+" to version "+version) == No )
			return;
		File.saveContent(pdir+"/.current",version);
		print("Library "+prj+" current version is now "+version);
	}

	function checkRec( prj : String, version : String, l : List<{ project : String, version : String, info : Infos }> ) {
		var pdir = getRepository() + Data.safe(prj);
		if( !FileSystem.exists(pdir) )
			throw "Library "+prj+" is not installed : run 'haxelib install "+prj+"'";
		var version = if( version != null ) version else getCurrent(pdir);
		var vdir = pdir + "/" + Data.safe(version);
		if( vdir.endsWith("dev") )
			vdir = getDev(pdir);
		if( !FileSystem.exists(vdir) )
			throw "Library "+prj+" version "+version+" is not installed";
		for( p in l )
			if( p.project == prj ) {
				if( p.version == version )
					return;
				throw "Library "+prj+" has two version included "+version+" and "+p.version;
			}
		var json = try File.getContent(vdir+"/"+Data.JSON) catch( e : Dynamic ) null;
		var inf = Data.readData(json,false);
		l.add({ project : prj, version : version, info: inf });
		for( d in inf.dependencies )
			if( !Lambda.exists(l, function(e) return e.project == d.name) )
				checkRec(d.name,if( d.version == "" ) null else d.version,l);
	}

	function path() {
		var list = new List();
		while( argcur < args.length ) {
			var a = args[argcur++].split(":");
			checkRec(a[0],a[1],list);
		}
		var rep = getRepository();
		for( d in list ) {
			var pdir = Data.safe(d.project)+"/"+Data.safe(d.version)+"/";
			var dir = rep + pdir;
			try {
				dir = getDev(rep+Data.safe(d.project));
				dir = Path.addTrailingSlash(dir);
				pdir = dir;
			} catch( e : Dynamic ) {}
			var ndir = dir + "ndll";
			if( FileSystem.exists(ndir) ) {
				var sysdir = ndir+"/"+Sys.systemName();
				var is64 = neko.Lib.load("std", "sys_is64", 0)();
				if( is64 ) sysdir += "64";
				// if( !FileSystem.exists(sysdir) )
				//	throw "Library "+d.project+" version "+d.version+" does not have a neko dll for your system";
				Sys.println("-L "+pdir+"ndll/");
			}
			try {
				var f = File.getContent(dir + "extraParams.hxml");
				Sys.println(f.trim());
			} catch( e : Dynamic ) {}
			if (d.info.classPath != "") {
				var cp = d.info.classPath;
				dir = Path.addTrailingSlash( dir + cp );
			}
			Sys.println(dir);
			Sys.println("-D " + d.project + "="+d.info.version);
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
			dir = FileSystem.fullPath(dir);
			if (!FileSystem.exists(dir))
				print('Directory $dir does not exist');
			else
				try {
					File.saveContent(devfile, dir);
					print("Development directory set to "+dir);
				}
				catch (e:Dynamic) {
					print('Could not write to $devfile');
				}

		}
	}


	function removeExistingDevLib(proj:String):Void
	{
		//TODO: ask if existing repo have changes.

		// find existing repo:
		var vcs:Vcs = Vcs.getVcsForDevLib(proj);
		// remove existing repos:
		while(vcs != null)
		{
			deleteRec(proj + "/" + vcs.directory);
			vcs = Vcs.getVcsForDevLib(proj);
		}
	}

	function doVcs(id:VcsID, ?libName:String, ?url:String, ?branch:String, ?subDir:String, ?version:String)
	{
		// Prepare check vcs.available:
		var vcs = Vcs.get(id);
		if(vcs == null || !vcs.available)
			return print('Could not use $id, please make sure it is installed and available in your PATH.');

		// if called with known values:
		if(libName != null && url != null)
			doVcsInstall(vcs, libName, url, branch, subDir, version);
		else
			doVcsInstall(vcs,
			             param("Library name"),
			             param(vcs.name + " path"),
			             paramOpt(),
			             paramOpt(),
			             paramOpt()
			);
	}

	function doVcsInstall(vcs:Vcs, libName:String, url:String, ?branch:String, ?subDir:String, ?version:String)
	{
		var rep = getRepository();
		var proj = rep + Data.safe(libName);

		// find & remove all existing repos:
		removeExistingDevLib(proj);
		// currently we already kill all dev-repos for all supported Vcs.


		var libPath = proj + "/" + vcs.directory;

		// prepare for new repo
		if(FileSystem.exists(libPath))
			deleteRec(libPath);


		print("Installing " +libName + " from " +url);

		try
		{
			vcs.clone(libPath, url, branch, version, cast settings);
		}
		catch(error:VcsError)
		{
			var message = switch(error)
			{
				case VcsError.VcsUnavailable(vcs):
					'Could not use ${vcs.executable}, please make sure it is installed and available in your PATH.';
				case VcsError.CantCloneRepo(vcs, repo, stderr):
					'Could not clone ${vcs.name} repository' + (stderr != null ? ":\n" + stderr : ".");
				case VcsError.CantCheckoutBranch(vcs, branch, stderr):
					'Could not checkout branch, tag or path "$branch": ' + stderr;
				case VcsError.CantCheckoutVersion(vcs, version, stderr):
					'Could not checkout tag "$version": ' + stderr;
			}
			print(message);
			deleteRec(libPath);
		}


		// finish it!
		var devPath = libPath + (subDir == null ? "" : "/" + subDir);

		cli.cwd = proj;

		File.saveContent(".dev", devPath);

		print('Library $libName set to use ${vcs.name}.');

		if(branch != null)
			print('  Branch/Tag/Rev: $branch');
		print('  Path: $devPath');

		cli.cwd = libPath;

		if(FileSystem.exists("haxelib.json"))
			doInstallDependencies(
				Data.readData(File.getContent("haxelib.json"), false).dependencies
			);
	}


	function run() {
		var rep = getRepository();
		var project = param("Library");
		var temp = project.split(":");
		project = temp[0];
		var pdir = rep + Data.safe(project);
		if( !FileSystem.exists(pdir) )
			throw "Library "+project+" is not installed";
		pdir += "/";
		var version = temp[1] != null ? temp[1] : getCurrent(pdir);
		var dev = try getDev(pdir) catch ( e : Dynamic ) null;
		var vdir = dev != null ? dev : pdir + Data.safe(version);

		args.push(cli.cwd);
		cli.cwd = vdir;

		var callArgs =
			switch try [Data.readData(File.getContent(vdir + '/haxelib.json'), false), null] catch (e:Dynamic) [null, e] {
				case [null, e]:
					throw 'Error parsing haxelib.json for $project@$version: $e';
				case [{ main: null }, _]:
					if( !FileSystem.exists('$vdir/run.n') )
						throw 'Library $project version $version does not have a run script';
					["neko", "run.n"];
				case [{ main: cls, dependencies: _.toArray() => deps }, _]:
					deps = switch deps { case null: []; default: deps.copy(); };
					deps.push( { name: project, version: DependencyVersion.DEFAULT } );
					var args = [];
					for (d in deps) {
						args.push('-lib');
						args.push(d.name + if (d.version == '') '' else ':${d.version}');
					}
					args.unshift('haxe');
					args.push('--run');
					args.push(cls);
					args;
				default: throw 'assert';
			}

		for (i in argcur...args.length)
			callArgs.push(args[i]);

		Sys.putEnv("HAXELIB_RUN", "1");
		var cmd = callArgs.shift();
 		Sys.exit(Sys.command(cmd, callArgs));
	}

	function local() {
		var file = param("Package");
		if (doInstallFile(file, true, true).name == 'haxelib_client')
			if (ask('You have updated haxelib. Do you wish to rebuild it?') != No) {
				rebuildSelf();
			}
	}

	inline function command(cmd:String, args:Array<String>)
		return cli.command(cmd, args);

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
		try Http.requestUrl("http://www.google.com") catch( e : Dynamic ) {
			print("Proxy connection failed");
			return;
		}
		File.saveContent(rep + "/.proxy", haxe.Serializer.run(proxy));
		print("Proxy setup done");
	}

	function loadProxy() {
		var rep = getRepository();
		try Http.PROXY = haxe.Unserializer.run(File.getContent(rep + "/.proxy")) catch( e : Dynamic ) { };
	}

	function convertXml() {
		var cwd = cli.cwd;
		var xmlFile = cwd + "haxelib.xml";
		var jsonFile = cwd + "haxelib.json";

		if (!FileSystem.exists(xmlFile))
		{
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
		if( FileSystem.exists(REPODIR) ) {
			if( !FileSystem.isDirectory(REPODIR) ) {
				print('$REPODIR exists already but is not a directory, delete it first');
				Sys.exit(1);
			}
			try {
				sys.io.File.saveContent(REPODIR+"/checkWrite.txt","CHECK WRITE");
			} catch( e : Dynamic ) {
				print('$REPODIR exists but is not writeable, chmod it');
				Sys.exit(2);
			}
			FileSystem.deleteFile(REPODIR+"/checkWrite.txt");
		} else {
			try {
				FileSystem.createDirectory(REPODIR);
			} catch( e : Dynamic ) {
				print('Failed to create ./$REPODIR');
				Sys.exit(3);
			}
		}
	}

	function deleteRepo() {
		if( !FileSystem.exists(REPODIR) )
			return;
		function deleteRec(path) {
			if( FileSystem.isDirectory(path) ) {
				for( f in FileSystem.readDirectory(path) )
					deleteRec(Path.join([path, f]));
				FileSystem.deleteDirectory(path);
			} else
				FileSystem.deleteFile(path);
		}
		deleteRec(REPODIR);
	}

	// ----------------------------------

	inline function print(str)
		cli.print(str);

	static function main() {
		new Main().process();
	}

}
