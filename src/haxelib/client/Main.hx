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
import haxe.crypto.Md5;
import haxe.io.BytesOutput;
import haxe.zip.*;
import haxe.iterators.ArrayIterator;

import sys.FileSystem;
import sys.io.File;

import haxelib.client.Vcs;
import haxelib.client.Args;
import haxelib.client.Hxml;
import haxelib.client.LibraryData;
import haxelib.client.Util.*;
import haxelib.client.FsUtils.*;

using StringTools;
using Lambda;
using haxelib.Data;

@:structInit
class CommandInfo {
	public final command:()->Void;
	public final maxArgs:Null<Int>;
	public final net:Bool;
	/** Message for deprecated commands**/
	public final useInstead:Null<String>;
}

class Main {
	static final HAXELIB_LIBNAME:ProjectName = ProjectName.ofString("haxelib");

	static final VERSION_LONG:String = getHaxelibVersionLong();
	static final VERSION:SemVer = SemVer.ofString(getHaxelibVersion());

	final command:Command;
	final mainArgs:Array<String>;
	final argsIterator:ArrayIterator<String>;
	final settings : {
		global : Bool,
		skipDependencies : Bool,
	};

	final alreadyUpdatedVcsDependencies = new Map<String,String>();

	function new(args:ArgsInfo) {
		// argument parsing already took care of mutual exclusivity
		if (args.flags.contains(Always))
			Cli.defaultAnswer = Always;
		else if (args.flags.contains(Never))
			Cli.defaultAnswer = Never;

		if (args.flags.contains(Quiet))
			Cli.mode = Quiet;
		else if (args.flags.contains(Debug))
			Cli.mode = Debug;

		Vcs.setFlat(args.flags.contains(Flat));


		// connection setup
		if (args.flags.contains(NoTimeout))
			Connection.hasTimeout = false;

		final noSsl = Sys.getEnv("HAXELIB_NO_SSL");
		if (noSsl == "1" || noSsl == "true") Connection.useSsl = false;

		final remote = switch args.options.get(Remote) {
			case null: Sys.getEnv("HAXELIB_REMOTE");
			case remote: remote;
		}
		if (remote != null) Connection.remote = remote;
		Connection.log = Cli.print;

		// misc
		updateCwd(args.repeatedOptions.get(Cwd));

		command = args.command;
		mainArgs = args.mainArgs;
		argsIterator = mainArgs.iterator();

		settings = {
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

	function checkUpdate() {
		final latest = try Connection.getLatestVersion(HAXELIB_LIBNAME) catch (_:Dynamic) null;
		if (latest != null && latest > VERSION)
			Cli.print('\nA new version ($latest) of haxelib is available.\nDo `haxelib --global update $HAXELIB_LIBNAME` to get the latest version.\n');
	}

	function getArgument(prompt:String){
		final given = argsIterator.next();
		if (given != null)
			return given;
		return Cli.getInput(prompt);
	}

	function getSecretArgument(prompt:String) {
		final given = argsIterator.next();
		if (given != null)
			return given;
		return Cli.getSecretInput(prompt);
	}

	function version() {
		Cli.print(VERSION_LONG);
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

		Cli.print('Haxe Library Manager $VERSION - (c)2006-2019 Haxe Foundation');
		Cli.print("  Usage: haxelib [command] [options]");

		for (cat in cats) {
			Cli.print("  " + cat[0].cat.getName());
			for (cmd in cat) {
				final paddedCmd = cmd.name.rpad(" ", maxLength);
				Cli.print('    $paddedCmd: ${cmd.doc}');
			}
		}
		Cli.print("  Available switches");
		for (option in switches) {
			final paddedOption = "--" + option.name.rpad(' ', maxLength - 2);
			Cli.print('    $paddedOption: ${option.description}');
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

			#if neko
			Submit => create(submit, 3, true),
			#end
			Register => create(register, 5, true),
			Dev => create(dev, 2),
			Git => create(vcs.bind(VcsID.Git), 5, true),
			Hg => create(vcs.bind(VcsID.Hg), 5, true),

			Setup => create(setup, 1),
			NewRepo => create(newRepo, 0),
			DeleteRepo => create(deleteRepo, 0),
			ConvertXml => create(convertXml, 0),
			Run => create(run, null),
			#if neko
			Proxy => create(proxy, 5, true),
			#end
			// deprecated commands
			Local => create(local, 1, 'haxelib install <file>'),
			SelfUpdate => create(updateSelf, 0, true, 'haxelib --global update $HAXELIB_LIBNAME'),
		];
	}

	function process() {
		final commands = mapCommands();

		final commandInfo = commands[command];

		if (commandInfo.useInstead != null)
			Cli.printWarning(
				'Command `$command` is deprecated and will be removed in future.\n'+
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
				#if neko
				loadProxy();
				#end
				checkUpdate();
			}
			commandInfo.command();
		} catch (e:RepoManager.InvalidConfiguration) {
			switch e.type {
				case NoneSet:
					Cli.printError('Error: This is the first time you are running haxelib. Please run `haxelib setup` first.');
				case NotFound(_):
					Cli.printError('Error: ${e.message}. Please run `haxelib setup` again.');
				case IsFile(_):
					Cli.printError('Error: ${e.message}. Please remove it and run `haxelib setup` again.');
			}
			Sys.exit(1);
		} catch(e:haxe.Exception) {
			final errorMessage = giveErrorString(e.toString());
			if (errorMessage != null)
				throw errorMessage;
			rethrow(e);
		}
	}

	static function giveErrorString(e:String):Null<String> {
		return switch (e) {
			case "std@host_resolve":
				'Host ${Connection.getHost()} was not found\n'
				+ "Please ensure that your internet connection is on\n"
				+ "If you don't have an internet connection or if you are behind a proxy\n"
				+ "please manually download the file from https://lib.haxe.org/files/3.0/\n"
				+ "and run 'haxelib install <file>' to install the Library.\n"
				+ "You can also setup the proxy with 'haxelib proxy'.\n"
				+ haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			case "Blocked":
				"Http connection timeout. Try running 'haxelib --notimeout <command>' to disable timeout";
			case "std@get_cwd":
				"Current working directory is unavailable";
			case _:
				null;
		}
	}

	// ---- COMMANDS --------------------

 	function search() {
		final word = getArgument("Search word");
		final l = Connection.search(word);
		for( s in l )
			Cli.print(s.name);
		Cli.print('${l.length} libraries found');
	}

	function info() {
		final prj = ProjectName.ofString(getArgument("Library name"));
		final inf = Connection.getInfo(prj);
		Cli.print('Name: ${inf.name}');
		Cli.print('Tags: ${inf.tags.join(", ")}');
		Cli.print('Desc: ${inf.desc}');
		Cli.print('Website: ${inf.website}');
		Cli.print('License: ${inf.license}');
		Cli.print('Owner: ${inf.owner}');
		Cli.print('Version: ${inf.getLatest()}');
		Cli.print('Releases: ');
		if( inf.versions.length == 0 )
			Cli.print("  (no version released yet)");
		for( v in inf.versions )
			Cli.print('   ${v.date} ${v.name} : ${v.comments}');
	}

	function user() {
		final uname = getArgument("User name");
		final inf = Connection.getUserData(uname);
		Cli.print('Id: ${inf.name}');
		Cli.print('Name: ${inf.fullname}');
		Cli.print('Mail: ${inf.email}');
		Cli.print('Libraries: ');
		if( inf.projects.length == 0 )
			Cli.print("  (no libraries)");
		for( p in inf.projects )
			Cli.print("  "+p);
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
		Connection.register(name, encodedPassword, email, fullname);
		return encodedPassword;
	}

	function zipDirectory(root:String):List<Entry> {
		final ret = new List<Entry>();
		function seek(dir:String) {
			for (name in FileSystem.readDirectory(dir)) if (!name.startsWith('.')) {
				final full = '$dir/$name';
				if (FileSystem.isDirectory(full)) seek(full);
				else {
					final blob = File.getBytes(full);
					final entry:Entry = {
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

	#if neko
	function submit() {
		final file = getArgument("Package");

		var data:haxe.io.Bytes, zip:List<Entry>;
		if (FileSystem.isDirectory(file)) {
			zip = zipDirectory(file);
			final out = new BytesOutput();
			new Writer(out).write(zip);
			data = out.getBytes();
		} else {
			data = File.getBytes(file);
			zip = Reader.readZip(new haxe.io.BytesInput(data));
		}

		final infos = Data.readInfos(zip,true);
		Data.checkClassPath(zip, infos);

		var user:String = infos.contributors[0];

		if (infos.contributors.length > 1)
			do {
				Cli.print('Which of these users are you: ${infos.contributors}');
				user = getArgument("User");
			} while ( infos.contributors.indexOf(user) == -1 );

		final password = if( Connection.isNewUser(user) ) {
			Cli.print('This is your first submission as \'$user\'');
			Cli.print("Please enter the following information for registration");
			doRegister(user);
		} else {
			readPassword(user);
		}

		Connection.checkDeveloper(infos.name,user);

		// check dependencies validity
		for( d in infos.dependencies ) {
			final infos = Connection.getInfo(ProjectName.ofString(d.name));
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

		final versions = try Connection.getVersions(infos.name) catch( _ : Dynamic ) null;
		if( versions != null )
			for( v in versions )
				if( v == infos.version && !Cli.ask('You\'re about to overwrite existing version \'${v}\', please confirm') )
					throw "Aborted";

		// query a submit id that will identify the file
		final id = Connection.getSubmitId();

		// directly send the file data over Http
		final h = Connection.createRequest();
		h.onError = function(e) throw e;
		h.onData = Cli.print;

		final inp = Cli.createUploadInput(data);

		h.fileTransfer("file", id, inp, data.length);
		Cli.print("Sending data.... ");
		h.request(true);

		// processing might take some time, make sure we wait
		Cli.print("Processing file.... ");
		if (haxe.remoting.HttpConnection.TIMEOUT != 0) // don't ignore -notimeout
			haxe.remoting.HttpConnection.TIMEOUT = 1000;
		// ask the server to register the sent file
		final msg = Connection.processSubmit(id,user,password);
		Cli.print(msg);
	}
	#end

	function readPassword(user:String, prompt = "Password"):String {
		var password = Md5.encode(getSecretArgument(prompt));
		var attempts = 5;
		while (!Connection.checkPassword(user, password)) {
			Cli.print('Invalid password for $user');
			if (--attempts == 0)
				throw 'Failed to input correct password';
			password = Md5.encode(getSecretArgument('$prompt ($attempts more attempt${attempts == 1 ? "" : "s"})'));
		}
		return password;
	}

	function install() {
		final rep = getRepositoryPath();

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
					installFromHxml(rep, prj);
					return;
				case zip if (zip.endsWith(".zip")):
					// *.zip provided, install zip as haxe library
					doInstallFile(rep, prj, true, true);
					return;
				case jsonPath if(jsonPath.endsWith("haxelib.json")):
					installFromHaxelibJson(rep, jsonPath);
					return;
			}
		}

		// Name provided that wasn't a local hxml or zip, so try to install it from server
		final inf = Connection.getInfo(ProjectName.ofString(prj));
		final reqversion = argsIterator.next();
		final version = getVersion(inf, reqversion);
		doInstall(rep, inf.name, version, version == inf.getLatest());
	}

	function getVersion( inf:ProjectInfos, ?reqversion:String ) {
		if( inf.versions.length == 0 )
			throw 'The library ${inf.name} has not yet released a version';
		final version = if( reqversion != null ) reqversion else inf.getLatest();
		var found = false;
		for( v in inf.versions )
			if( v.name == version ) {
				found = true;
				break;
			}
		if( !found )
			throw 'No such version $version for library ${inf.name}';

		return version;
	}

	function installFromHxml( rep:String, path:String ) {
		final targets  = [
			~/^(-{1,2})java / => 'hxjava',
			~/^(-{1,2})cpp / => 'hxcpp',
			~/^(-{1,2})cs / => 'hxcs',
		];
		final libsToInstall = new Map<String, {name:String,version:String,type:String,url:String,branch:String,subDir:String}>();
		final autoLibsToInstall = [];

		function processHxml(path) {
			final hxml = normalizeHxml(sys.io.File.getContent(path));
			final lines = hxml.split("\n");
			for (l in lines) {
				l = l.trim();

				for (target in targets.keys())
					if (target.match(l))
						autoLibsToInstall.push(targets[target]);

				final libraryFlagEReg = ~/^(-lib|-L|--library)\b/;
				if (libraryFlagEReg.match(l))
				{
					final key = libraryFlagEReg.matchedRight().trim();
					final parts = ~/:/.split(key);
					final libName = parts[0];

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
							final urlParts = parts[1].substr(4).split("#");
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

		for(name in autoLibsToInstall) {
			if(!Lambda.exists(libsToInstall, lib -> lib.name == name))
				libsToInstall[name] = { name: name, version: null, type:"haxelib", url: null, branch: null, subDir: null }
		}

		if (Lambda.empty(libsToInstall))
			return;

		// Check the version numbers are all good
		// TODO: can we collapse this into a single API call?  It's getting too slow otherwise.
		Cli.print("Loading info about the required libraries");
		for (l in libsToInstall)
		{
			if (l.type == "git")
			{
				// Do not check git repository infos
				continue;
			}
			final inf = Connection.getInfo(ProjectName.ofString(l.name));
			l.version = getVersion(inf, l.version);
		}

		// Print a list with all the info
		Cli.print("Haxelib is going to install these libraries:");
		for (l in libsToInstall) {
			final vString = (l.version == null) ? "" : " - " + l.version;
			Cli.print("  " + l.name + vString);
		}

		// Install if they confirm
		if (Cli.ask("Continue?")) {
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
		final cwd = Sys.getCwd();
		final hxmlFiles = sys.FileSystem.readDirectory(cwd).filter(function (f) return f.endsWith(".hxml"));
		if (hxmlFiles.length > 0) {
			for (file in hxmlFiles) {
				Cli.print('Installing all libraries from $file:');
				installFromHxml(rep, cwd + file);
			}
		} else {
			Cli.print("No hxml files found in the current directory.");
		}
	}

	function doInstall( rep, project, version, setcurrent ) {
		// check if exists already
		if (FileSystem.exists(haxe.io.Path.join([rep, Data.safe(project), Data.safe(version)])) ) {
			Cli.print('You already have $project version $version installed');
			setCurrent(rep,project,version,true);
			return;
		}

		// download to temporary file
		final filename = Data.fileName(project,version);
		final filepath = haxe.io.Path.join([rep, filename]);

		Cli.print('Downloading $filename...');

		final maxRetry = 3;
		final fileUrl = haxe.io.Path.join([Connection.siteUrl, Data.REPOSITORY, filename]);
		for (i in 0...maxRetry) {
			try {
				Connection.download(fileUrl, filepath);
				break;
			} catch (e:Dynamic) {
				Cli.print('Failed to download ${fileUrl}. (${i+1}/${maxRetry})\n${e}');
				Sys.sleep(1);
			}
		}

		doInstallFile(rep, filepath, setcurrent);
		try {
			Connection.postInstall(ProjectName.ofString(project), SemVer.ofString(version));
		} catch (e:Dynamic) {}
	}

	function doInstallFile(rep,filepath,setcurrent,nodelete = false) {
		// read zip content
		final f = File.read(filepath,true);
		final zip = try {
			Reader.readZip(f);
		} catch (e:Dynamic) {
			f.close();
			// file is corrupted, remove it
			if (!nodelete)
				FileSystem.deleteFile(filepath);
			rethrow(e);
		}
		f.close();
		final infos = Data.readInfos(zip,false);
		Cli.print('Installing ${infos.name}...');
		// create directories
		var pdir = rep + Data.safe(infos.name);
		safeDir(pdir);
		pdir += "/";
		var target = pdir + Data.safe(infos.version);
		safeDir(target);
		target += "/";

		// locate haxelib.json base path
		final basepath = Data.locateBasePath(zip);

		// unzip content
		final entries = [for (entry in zip) if (entry.fileName.startsWith(basepath)) entry];
		final total = entries.length;
		for (i in 0...total) {
			final zipfile = entries[i];
			final n = {
				final tmp = zipfile.fileName;
				// remove basepath
				tmp.substr(basepath.length, tmp.length - basepath.length);
			}
			if( n.charAt(0) == "/" || n.charAt(0) == "\\" || n.split("..").length > 1 )
				throw "Invalid filename : "+n;

			Cli.printInstallStatus(i, total);

			final dirs = ~/[\/\\]/g.split(n);
			var path = "";
			final file = dirs.pop();
			for( d in dirs ) {
				path += d;
				safeDir(target+path);
				path += "/";
			}
			if( file == "" ) {
				if( path != "") Cli.printDebug('  Created $path');
				continue; // was just a directory
			}
			path += file;
			Cli.printDebug('  Install $path');
			final data = Reader.unzip(zipfile);
			File.saveBytes(target+path,data);
		}

		// set current version
		if( setcurrent || !FileSystem.exists(pdir+".current") ) {
			File.saveContent(pdir + ".current", infos.version);
			Cli.print('  Current version is now ${infos.version}');
		}

		// end
		if( !nodelete )
			FileSystem.deleteFile(filepath);
		Cli.print("Done");

		// process dependencies
		doInstallDependencies(rep, infos.dependencies);

		return infos;
	}

	function doInstallDependencies( rep:String, dependencies:Array<Dependency> ) {
		if( settings.skipDependencies ) return;

		for( d in dependencies ) {
			if( d.version == "" ) {
				final pdir = rep + Data.safe(d.name);
				final dev = try getDev(pdir) catch (_:Dynamic) null;

				if (dev != null) { // no version specified and dev set, no need to install dependency
					continue;
				}
			}
			final name = ProjectName.ofString(d.name);

			if (d.version == "" && d.type == DependencyType.Haxelib)
				d.version = Connection.getLatestVersion(name);
			Cli.print('Installing dependency ${d.name} ${d.version}');

			switch d.type {
				case Haxelib:
					final info = Connection.getInfo(name);
					doInstall(rep, info.name, d.version, false);
				case Git:
					useVcs(VcsID.Git, function(vcs) doVcsInstall(rep, vcs, d.name, d.url, d.branch, d.subDir, d.version));
				case Mercurial:
					useVcs(VcsID.Hg, function(vcs) doVcsInstall(rep, vcs, d.name, d.url, d.branch, d.subDir, d.version));
			}
		}
	}

	function getScope():Scope {
		if (settings.global)
			return Scope.getScopeForRepository(Repository.getGlobal());
		return Scope.getScope();
	}

	function getRepository():Repository {
		if (settings.global)
			return Repository.getGlobal();
		return Repository.get();
	}

	function getRepositoryPath():String {
		if (settings.global)
			return RepoManager.getGlobalPath();
		return RepoManager.getPath();
	}

	function setup() {
		final suggested = RepoManager.suggestGlobalPath();

		final prompt = 'Please enter haxelib repository path with write access\n'
						+ 'Hit enter for default ($suggested)\n'
						+ 'Path';

		final input = getArgument(prompt);

		final path = if (input != "") FsUtils.getFullPath(input) else suggested;

		RepoManager.setGlobalPath(path);

		Cli.print('haxelib repository is now $path');
	}

	function config() {
		Cli.print(getRepositoryPath());
	}

	static function getCurrent( proj, dir ) {
		return try { getDev(dir); return "dev"; } catch( e : Dynamic ) try File.getContent(dir + "/.current").trim() catch( e : Dynamic ) throw "Library "+proj+" is not installed : run 'haxelib install "+proj+"'";
	}

	static function getDev( dir ) {
		var path = File.getContent(dir + "/.dev").trim();
		path = ~/%([A-Za-z0-9_]+)%/g.map(path,function(r) {
			final env = Sys.getEnv(r.matched(1));
			return env == null ? "" : env;
		});
		final filters = try Sys.getEnv("HAXELIB_DEV_FILTER").split(";") catch( e : Dynamic ) null;
		if( filters != null && !filters.exists(function(flt) return StringTools.startsWith(path.toLowerCase().split("\\").join("/"),flt.toLowerCase().split("\\").join("/"))) )
			throw "This .dev is filtered";
		return path;
	}

	function list() {
		final scope = getScope();

		final libraryInfo = scope.getArrayOfLibraryInfo(argsIterator.next());

		// sort projects alphabetically
		libraryInfo.sort(function(a, b) return Reflect.compare((a.name:String).toLowerCase(), (b.name:String).toLowerCase()));

		for (library in libraryInfo) {
			var line = '${library.name}:';
			for (version in library.versions)
				line +=
					if (library.devPath == null && version == library.current)
						' [$version]'
					else
						' $version';

			if (library.devPath != null)
				line += ' [dev:${library.devPath}]';

			Cli.print(line);
		}
	}

	function update() {
		final rep = getRepositoryPath();

		var prj = argsIterator.next();
		if (prj != null) {
			prj = projectNameToDir(rep, prj); // get project name in proper case
			if (!updateByName(rep, prj))
				Cli.print('$prj is up to date');
			return;
		}

		final state = { rep : rep, prompt : true, updated : false };
		for( p in FileSystem.readDirectory(state.rep) ) {
			if( p.charAt(0) == "." || !FileSystem.isDirectory(state.rep+"/"+p) )
				continue;
			final p = Data.unsafe(p);
			Cli.print('Checking $p');
			try {
				doUpdate(p, state);
			} catch (e:VcsError) {
				if (!e.match(VcsUnavailable(_)))
					rethrow(e);
			}
		}
		if( state.updated )
			Cli.print("Done");
		else
			Cli.print("All libraries are up-to-date");
	}

	function projectNameToDir( rep:String, project:String ) {
		final p = project.toLowerCase();
		final l = FileSystem.readDirectory(rep).filter(function (dir) return dir.toLowerCase() == p);

		switch (l) {
			case []: return project;
			case [dir]: return Data.unsafe(dir);
			case _: throw 'Several name case for library $project';
		}
	}

	function updateByName(rep:String, prj:String) {
		final state = { rep : rep, prompt : false, updated : false };
		doUpdate(prj,state);
		return state.updated;
	}

	function doUpdate( p : String, state : { updated : Bool, rep : String, prompt : Bool } ) {
		final pdir = state.rep + Data.safe(p);

		final vcs = Vcs.getVcsForDevLib(pdir);
		if(vcs != null) {
			if(!vcs.available)
				throw VcsError.VcsUnavailable(vcs);

			final oldCwd = Sys.getCwd();
			Sys.setCwd(pdir + "/" + vcs.directory);
			final success = vcs.update(p);

			state.updated = success;
			if(success)
				Cli.print('$p was updated');
			Sys.setCwd(oldCwd);
		} else {
			final p = ProjectName.ofString(p);
			final latest =
				try Connection.getLatestVersion(p)
				catch (e:Dynamic) { Cli.print(e); return; };

			if( !FileSystem.exists(pdir+"/"+Data.safe(latest)) ) {
				if( state.prompt ) {
					if (!Cli.ask('Update $p to $latest'))
						return;
				}
				final info = Connection.getInfo(p);
				doInstall(state.rep, info.name, latest,true);
				state.updated = true;
			} else
				setCurrent(state.rep, p, latest, true);
		}
	}

	function remove() {
		final rep = getRepositoryPath();
		final prj = getArgument("Library");
		final version = argsIterator.next();
		final pdir = rep + Data.safe(prj);
		if( version == null ) {
			if( !FileSystem.exists(pdir) )
				throw 'Library $prj is not installed';

			if (prj == HAXELIB_LIBNAME && (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME))
				throw 'Removing "$HAXELIB_LIBNAME" requires the --system flag';

			deleteRec(pdir);
			Cli.print('Library $prj removed');
			return;
		}

		final vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) )
			throw 'Library $prj does not have version $version installed';

		final cur = File.getContent(pdir + "/.current").trim(); // set version regardless of dev
		if( cur == version )
			throw 'Cannot remove current version of library $prj';
		deleteRec(vdir);
		Cli.print('Library $prj version $version removed');
	}

	function set() {
		setCurrent(getRepositoryPath(), getArgument("Library"), getArgument("Version"), false);
	}

	function setCurrent( rep : String, prj : String, version : String, doAsk : Bool ) {
		final pdir = rep + Data.safe(prj);
		final vdir = pdir + "/" + Data.safe(version);
		if( !FileSystem.exists(vdir) ){
			Cli.print('Library $prj version $version is not installed');
			if(Cli.ask("Would you like to install it?")) {
				final info = Connection.getInfo(ProjectName.ofString(prj));
				doInstall(rep, info.name, version, true);
			}
			return;
		}
		if( File.getContent(pdir + "/.current").trim() == version )
			return;
		if( doAsk && !Cli.ask('Set $prj to version $version') )
			return;
		File.saveContent(pdir+"/.current",version);
		Cli.print('Library $prj current version is now $version');
	}

	function extractLibArgs():Array<{library:ProjectName, version:Null<Version>}> {
		return [
			for (arg in argsIterator) {
				libraryAndVersion.match(arg);

				{
					library: ProjectName.ofString(libraryAndVersion.matched(1)),
					version: {
						final versionStr = libraryAndVersion.matched(2);
						if (versionStr != null)
							haxelib.client.Version.ofString(versionStr.split(":")[0])
						else
							null;
					}
				}
			}
		];
	}

	function path() {
		final scope = getScope();

		final libraries = extractLibArgs();
		if (libraries.length == 0)
			return;

		Cli.print(scope.getArgsAsHxmlForLibraries(libraries));
	}

	function libpath() {
		final scope = getScope();

		final libraries = extractLibArgs();

		for (library in libraries)
			Cli.print(scope.getPath(library.library, library.version));
	}

	function dev() {
		final rep = getRepositoryPath();
		final project = getArgument("Library");
		var dir = argsIterator.next();
		final proj = rep + Data.safe(project);
		if( !FileSystem.exists(proj) ) {
			FileSystem.createDirectory(proj);
		}
		final devfile = proj+"/.dev";
		if( dir == null ) {
			if( FileSystem.exists(devfile) )
				FileSystem.deleteFile(devfile);
			Cli.print("Development directory disabled");
		}
		else {
			while ( dir.endsWith("/") || dir.endsWith("\\") ) {
				dir = dir.substr(0,-1);
			}
			if (!FileSystem.exists(dir)) {
				Cli.print('Directory $dir does not exist');
			} else {
				dir = FileSystem.fullPath(dir);
				try {
					File.saveContent(devfile, dir);
					Cli.print('Development directory set to $dir');
				}
				catch (e:Dynamic) {
					Cli.print('Could not write to $devfile');
				}
			}

		}
	}

	function removeExistingDevLib(proj:String):Void {
		// TODO: ask if existing repo have changes.

		// find existing repo:
		var vcs = Vcs.getVcsForDevLib(proj);
		// remove existing repos:
		while(vcs != null) {
			deleteRec(proj + "/" + vcs.directory);
			vcs = Vcs.getVcsForDevLib(proj);
		}
	}

	inline function useVcs(id:VcsID, fn:Vcs->Void):Void {
		// Prepare check vcs.available:
		final vcs = Vcs.get(id);
		if(vcs == null || !vcs.available)
			throw 'Could not use $id, please make sure it is installed and available in your PATH.';
		return fn(vcs);
	}

	function vcs(id:VcsID) {
		final rep = getRepositoryPath();
		useVcs(id, function(vcs)
			doVcsInstall(
				rep, vcs, getArgument("Library name"),
				getArgument(vcs.name + " path"), argsIterator.next(),
				argsIterator.next(), argsIterator.next()
			)
		);
	}

	function doVcsInstall(rep:String, vcs:Vcs, libName:String, url:String, branch:String, subDir:String, version:String) {

		final proj = rep + Data.safe(libName);

		var libPath = proj + "/" + vcs.directory;

		function doVcsClone() {
			Cli.print('Installing $libName from $url' + ( branch != null ? " branch: " + branch : "" ));
			try {
				vcs.clone(libPath, url, branch, version);
			} catch(error:VcsError) {
				deleteRec(libPath);
				final message = switch(error) {
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
			Cli.print('You already have $libName version ${vcs.directory} installed.');

			final wasUpdated = alreadyUpdatedVcsDependencies.exists(libName);
			final currentBranch = if (wasUpdated) alreadyUpdatedVcsDependencies.get(libName) else null;
			final currentBranchStr = currentBranch != null ? currentBranch : "<unspecified>";

			if (branch != null && (!wasUpdated || (wasUpdated && currentBranch != branch))
				&& Cli.ask('Overwrite branch: "$currentBranchStr" with "$branch"'))
			{
				deleteRec(libPath);
				doVcsClone();
			}
			else if (!wasUpdated)
			{
				Cli.print('Updating $libName version ${vcs.directory} ...');
				updateByName(rep, libName);
			}
		} else {
			doVcsClone();
		}

		// finish it!
		if (subDir != null) {
			libPath += "/" + subDir;
			File.saveContent(proj + "/.dev", libPath);
			Cli.print('Development directory set to $libPath');
		} else {
			File.saveContent(proj + "/.current", vcs.directory);
			Cli.print('Library $libName current version is now ${vcs.directory}');
		}

		this.alreadyUpdatedVcsDependencies.set(libName, branch);

		final jsonPath = libPath + "/haxelib.json";
		if(FileSystem.exists(jsonPath))
			doInstallDependencies(rep, Data.readData(File.getContent(jsonPath), false).dependencies);
	}

	final libraryAndVersion = ~/^(.+?)(?::(.*))?$/;
	function run() {
		final scope = getScope();

		libraryAndVersion.match(getArgument("Library[:version]"));

		final project = ProjectName.ofString(libraryAndVersion.matched(1));
		final versionStr = libraryAndVersion.matched(2);
		final version = if (versionStr != null) haxelib.client.Version.ofString(versionStr) else null;

		try {
			scope.runScript(project, {
				args: [for (arg in argsIterator) arg],
				useGlobalRepo: settings.global
			}, version);
		} catch (e:ScriptRunner.ScriptError) {
			Sys.exit(e.code);
		}
	}

	#if neko
	function proxy() {
		final rep = getRepositoryPath();
		final host = getArgument("Proxy host");
		if( host == "" ) {
			if( FileSystem.exists(rep + "/.proxy") ) {
				FileSystem.deleteFile(rep + "/.proxy");
				Cli.print("Proxy disabled");
			} else
				Cli.print("No proxy specified");
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
		Cli.print("Testing proxy...");
		if (!Connection.testConnection() && !Cli.ask("Proxy connection failed. Use it anyway"))
			return;

		File.saveContent(rep + "/.proxy", haxe.Serializer.run(proxy));
		Cli.print("Proxy setup done");
	}

	function loadProxy() {
		final rep = getRepositoryPath();
		try Http.PROXY = haxe.Unserializer.run(File.getContent(rep + "/.proxy")) catch( e : Dynamic ) { };
	}
	#end

	function convertXml() {
		final cwd = Sys.getCwd();
		final xmlFile = cwd + "haxelib.xml";
		final jsonFile = cwd + "haxelib.json";

		if (!FileSystem.exists(xmlFile)) {
			Cli.print('No `haxelib.xml` file was found in the current directory.');
			return;
		}

		final xmlString = File.getContent(xmlFile);
		final json = haxelib.client.ConvertXml.convert(xmlString);
		final jsonString = haxelib.client.ConvertXml.prettyPrint(json);

		File.saveContent(jsonFile, jsonString);
		Cli.print('Saved to $jsonFile');
	}

	function newRepo() {
		RepoManager.createLocal();
		final path = RepoManager.getPath();
		Cli.print('Local repository created ($path)');
	}

	function deleteRepo() {
		final path = RepoManager.getPath();
		RepoManager.deleteLocal();
		Cli.print('Local repository deleted ($path)');
	}

	// ----------------------------------

	static function main() {
		final args = Sys.args();
		final isHaxelibRun = (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME);
		if (isHaxelibRun)
			Sys.setCwd(args.pop());

		final priorityFlags = Args.extractPriorityFlags(args);

		final repository = try Repository.getGlobal() catch (_:Dynamic) null;
		// if haxelib hasn't already been run, --system is not specified, and the updated version is installed,
		if (repository != null && !isHaxelibRun && !priorityFlags.contains(System) && repository.isInstalled(HAXELIB_LIBNAME) ){
			try {
				final scope = Scope.getScopeForRepository(repository);
				scope.runScript(HAXELIB_LIBNAME, {
					args: args,
					useGlobalRepo: priorityFlags.contains(Global)
				});
				return;
			} catch (e:ScriptRunner.ScriptError) {
				Sys.exit(e.code);
			} catch (e:haxe.Exception) {
				Cli.printWarning('Failed to run updated haxelib: $e');
				Cli.printWarning('Resorting to system haxelib...');
			}
		}

		final argsInfo =
			try {
				Args.extractAll(args);
			} catch (e:SwitchError) {
				Cli.printError(e.message);
				Cli.print("Run 'haxelib help' for detailed help.");
				Sys.exit(1);
				return;
			} catch (e:InvalidCommand) {
				Cli.printError(e.message);
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
			Cli.printError('Error: ${e.message}');
			Sys.exit(1);
			return;
		};

		Sys.exit(0);
	}

	// deprecated commands
	function local() {
		doInstallFile(getRepositoryPath(), getArgument("Package"), true, true);
	}

	function updateSelf() {
		updateByName(RepoManager.getGlobalPath(), HAXELIB_LIBNAME);
	}
}
