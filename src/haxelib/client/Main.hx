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

import haxe.crypto.Md5;
import haxe.iterators.ArrayIterator;

import sys.FileSystem;
import sys.io.File;

import haxelib.api.*;
import haxelib.api.Vcs;
import haxelib.api.LibraryData;

import haxelib.client.Args;
import haxelib.Util.rethrow;

using StringTools;
using Lambda;
using haxelib.Data;
using haxelib.api.RepoReformatter;

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

	static final VERSION_LONG:String = haxelib.Util.getHaxelibVersionLong();
	static final VERSION:SemVer = SemVer.ofString(haxelib.Util.getHaxelibVersion());

	final command:Command;
	final mainArgs:Array<String>;
	final argsIterator:ArrayIterator<String>;
	final useGlobalRepo:Bool;

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

		if (args.flags.contains(SkipDependencies))
			Installer.skipDependencies = true;
		Vcs.flat = args.flags.contains(Flat);

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

		useGlobalRepo = args.flags.contains(Global);
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

	static function combineAliases(name:String, aliases:Array<String>):String {
		var line = '';
		for (alias in aliases) {
			// single character alias only has one dash
			line += alias.length > 1 ? '--$alias, ' : '-$alias, ';
		}
		line += '--$name';
		return line;
	}

	static function usage() {
		var maxLength = 0;

		inline function checkLength(line:String)
			if (line.length > maxLength)
				maxLength = line.length;

		function generateLines(data:List<UsageData>, generate:(UsageData -> String)):Array<{usage:String, description:String}>
			return [
				for (item in data) {
					final line = generate(item);
					checkLength(line);
					{usage: line, description: item.description};
				}];

		final switchLines = generateLines(Args.generateSwitchDocs(), (flag) -> '--${flag.name}');
		final optionLines = generateLines(Args.generateOptionDocs(), (flag) -> combineAliases(flag.name, flag.aliases) + ' ${flag.parameter}');

		final categories = new Map<String, Array<{usage:String, description:String}>>();
		for (command in Args.generateCommandDocs()) {
			checkLength(command.name);
			final categoryName = command.category.getName();
			if (!categories.exists(categoryName))
				categories[categoryName] = [];
			categories[categoryName].push({usage: command.name, description: command.description});
		}

		Cli.print('Haxe Library Manager $VERSION - (c)2006-2019 Haxe Foundation');
		Cli.print("  Usage: haxelib [command] [options]");

		inline function display(type:String, lines:Array<{usage:String, description:String}>) {
			Cli.print('  $type');
			for (line in lines) {
				final padded = line.usage.rpad(' ', maxLength);
				Cli.print('    $padded : ${line.description}');
			}
		}

		for (name => commands in categories)
			display(name, commands);

		display("Options", optionLines);
		display("Switches", switchLines);
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
			FixRepo => create(fixRepo, 0),
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
		} catch (e:Installer.VcsCommandFailed) {
			Cli.printDebug(e.stdout);
			Cli.printDebugError(e.stderr);
			Sys.exit(e.code);
		} catch(e:haxe.Exception) {
			final errorMessage = giveErrorString(e.toString());
			if (errorMessage != null)
				throw new haxe.Exception(errorMessage);
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
				"Http connection timeout. Try running 'haxelib --no-timeout <command>' to disable timeout";
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

	#if neko
	function getContributor(contributors:Array<String>): {name:String, password:String} {
		var user:String = contributors[0];

		if (contributors.length > 1)
			do {
				Cli.print('Which of these users are you: $contributors');
				user = getArgument("User");
			} while (contributors.indexOf(user) == -1);

		final password = if (Connection.isNewUser(user)) {
			Cli.print('This is your first submission as \'$user\'');
			Cli.print("Please enter the following information for registration");
			doRegister(user);
		} else {
			readPassword(user);
		}
		return { name: user, password: password };
	}

	function submit() {
		final file = getArgument("Package");

		Connection.submitLibrary(
			file,
			getContributor,
			function(version) return Cli.ask('You\'re about to overwrite existing version \'$version\', please confirm'),
			(Cli.mode == Quiet) ? null : Cli.printUploadStatus
		);
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

	static function confirmHxmlInstall(libs:Array<{name:ProjectName, version:Version}>):Bool {
		// Print a list with all the info
		Cli.print("Haxelib is going to install these libraries:");
		for (library in libs)
			Cli.print('  ${library.name} - ${library.version}');

		return Cli.ask("Continue");
	}

	function setupAndGetInstaller(?scope:Scope) {
		if (scope == null) scope = getScope();
		final userInterface:Installer.UserInterface = {
			log: function(msg, priority) {
				switch priority {
					case Default: Cli.print(msg);
					case Debug: Cli.printDebug(msg);
					case Optional: Cli.printOptional(msg);
				}
			},
			confirm: Cli.ask,
			logInstallationProgress: (Cli.mode == Debug) ? Cli.printInstallStatus: null,
			logDownloadProgress: (Cli.mode != Quiet) ? Cli.printDownloadStatus : null
		}
		return new Installer(scope, userInterface);
	}

	function install() {
		final toInstall = getArgument("Library name or hxml file");
		final scope = getScope();
		final installer = setupAndGetInstaller(scope);

		// No library given, install libraries listed in *.hxml in given directory
		if (toInstall == "all") {
			installFromAllHxml(installer);
			return;
		}

		if (sys.FileSystem.exists(toInstall) && !sys.FileSystem.isDirectory(toInstall)) {
			switch (toInstall) {
				case hxml if (hxml.endsWith(".hxml")):
					// *.hxml provided, install all libraries/versions in this hxml file
					return installer.installFromHxml(hxml, confirmHxmlInstall);
				case zip if (zip.endsWith(".zip")):
					// *.zip provided, install zip as haxe library
					return installer.installLocal(zip);
				case jsonPath if (jsonPath.endsWith("haxelib.json")):
					return installer.installFromHaxelibJson(jsonPath);
			}
		}
		// Name provided that wasn't a local hxml or zip, so try to install it from server
		final info = Connection.getInfo(ProjectName.ofString(toInstall));
		// for display purposes, here we use the corrected project name.
		final library = ProjectName.ofString(info.name);

		final versionGiven = argsIterator.next();
		final version = switch versionGiven {
			case null: info.getLatest();
			case v: SemVer.ofString(v);
		};
		// check if the version exists in scope already
		if (scope.isLibraryInstalled(library) && scope.getVersion(library) == version)
			return Cli.print('$library version $version is already installed and set as current.');

		// otherwise, check if it exists in the repository
		if (getRepository().isVersionInstalled(library, version)) {
			Cli.print('You already have $library version $version installed');
			if (Cli.ask('Set $library to version $version'))
				scope.setVersion(library, version);
			return;
		}
		installer.installFromHaxelib(library, version);
	}

	function installFromAllHxml(installer:Installer) {
		final cwd = Sys.getCwd();
		final hxmlFiles = FileSystem.readDirectory(cwd).filter(function(f) return f.endsWith(".hxml"));
		if (hxmlFiles.length == 0) {
			Cli.print("No hxml files found in the current directory.");
			return;
		}
		for (file in hxmlFiles)
			installer.installFromHxml(file, confirmHxmlInstall);
	}

	function getScope():Scope {
		return Scope.getScopeForRepository(getRepository());
	}

	function getRepository():Repository {
		final repository = if (useGlobalRepo) Repository.getGlobal() else Repository.get();

		if (repository.doesRepositoryRequireReformat()) {
			final cmd = "haxelib fixrepo" + if (useGlobalRepo) " --global" else "";
			Cli.printWarning('Repository requires reformatting. To reformat, run `$cmd`.');
		} else if (repository.isRepositoryIncompatible()) {
			Cli.printWarning('Repository is incompatible with this version of haxelib. Please run `haxelib update haxelib`.');
		}

		return repository;
	}

	function getRepositoryPath():String {
		if (useGlobalRepo)
			return RepoManager.getGlobalPath();
		return RepoManager.getPath();
	}

	function fixRepo() {
		final repository = if (useGlobalRepo) Repository.getGlobal() else Repository.get();

		Cli.printOptional('Fixing repository: ${repository.path}');
		repository.reformat(Cli.printDebug);
		Cli.printOptional('Finished fixing repository: ${repository.path}');
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

	function list() {
		final scope = getScope();

		final libraryInfo = scope.getArrayOfLibraryInfo(argsIterator.next());

		// sort projects alphabetically
		libraryInfo.sort(function(a, b) return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));

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
		final input = argsIterator.next();
		final scope = getScope();
		final installer = setupAndGetInstaller(scope);
		if (input == null)
			return installer.updateAll();

		final library = ProjectName.ofString(input);

		if (!scope.isLibraryInstalled(library)) {
			Cli.print('Library $library is not installed.');
			Sys.exit(1);
			return;
		}
		installer.update(library);
	}

	function remove() {
		final repository = getRepository();
		final project = ProjectName.ofString(getArgument("Library"));
		final versionInput = argsIterator.next();

		if (versionInput == null) {
			if (project == HAXELIB_LIBNAME && (Sys.getEnv("HAXELIB_RUN_NAME") == HAXELIB_LIBNAME))
				throw 'Removing "$HAXELIB_LIBNAME" requires the --system flag';

			repository.removeProject(project);
			Cli.print('Library $project removed');
			return;
		}

		final version = LibraryData.Version.ofString(versionInput);
		repository.removeProjectVersion(project, version);
		Cli.print('Library $project version $version removed');
	}

	function setVersion(library:ProjectName, version:SemVer):Void {
		final repository = getRepository();
		final scope = Scope.getScopeForRepository(repository);

		if (scope.isLibraryInstalled(library) && scope.getVersion(library) == version)
			return Cli.print('Library $library is already set to $version');

		if (!repository.isVersionInstalled(library, version)) {
			Cli.print('Library $library version $version is not installed');
			if (!Cli.ask('Would you like to install it'))
				return;
			final installer = setupAndGetInstaller(scope);
			installer.installFromHaxelib(library, version, true);
		} else {
			scope.setVersion(library, version);
			Cli.print('Library $library current version is now $version');
		}
	}

	function setVcsVersion(library:ProjectName, version:VcsID):Void {
		final repository = getRepository();
		final scope = Scope.getScopeForRepository(repository);

		if (scope.isLibraryInstalled(library) && scope.getVersion(library) == version)
			return Cli.print('Library $library is already set to $version');

		if (!repository.isVersionInstalled(library, version)) {
			Cli.print('Library $library version $version is not installed');
			Sys.exit(1);
			return;
		}

		// in a local scope, we dont have enough information to set it and keep it reproducible
		if (scope.isLocal)
			throw 'Unable to set to $version. Please run a full install command such as:\n'
				+ '`haxelib $version $library <url>`';

		scope.setVcsVersion(library, version);

		Cli.print('Library $library current version is now $version');
	}

	function set() {
		final library = ProjectName.ofString(getArgument("Library"));
		final version = LibraryData.Version.ofString(getArgument("Version"));

		final semVer = try SemVer.ofString(version) catch(_) null;

		if (semVer != null)
			return setVersion(library, semVer);

		final vcsId = try VcsID.ofString(version) catch(_) null;

		if (vcsId != null)
			return setVcsVersion(library, vcsId);
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
							haxelib.api.Version.ofString(versionStr.split(":")[0])
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
		final project = ProjectName.ofString(getArgument("Library"));
		final dir = argsIterator.next();

		final repository = getRepository();

		if (dir == null) {
			repository.removeDevPath(project);
			Cli.print("Development directory disabled");
			return;
		}
		final dir = haxe.io.Path.removeTrailingSlashes(dir);
		if (!FileSystem.exists(dir))
			throw 'Directory $dir does not exist';
		try {
			final dir = FileSystem.fullPath(dir);

			final project = {
				final jsonPath = haxe.io.Path.join([dir, Data.JSON]);
				if (!FileSystem.exists(jsonPath))
					project;
				else {
					final internalName = Data.readData(File.getContent(jsonPath), false).name;
					ProjectName.getCorrectOrAlias(internalName, project);
				}
			}
			repository.setDevPath(project, dir);
			Cli.print('Development directory set to $dir');
		} catch (e) {
			Cli.print('Failed to set development directory to $dir: ' + e.message);
		}
	}

	function vcs(id:VcsID) {
		// Prepare check vcs.available:
		final vcs = Vcs.get(id);
		if (vcs == null || !vcs.available)
			throw 'Could not use $id, please make sure it is installed and available in your PATH.';

		// get args
		final library = ProjectName.ofString(getArgument("Library name"));
		final url = getArgument(vcs.name + " path");
		final ref = argsIterator.next();

		final isRefHash = ref == null || LibraryData.isCommitHash(ref);
		final hash = isRefHash ? ref : null;
		final branch = isRefHash ? null : ref;

		final installer = setupAndGetInstaller();

		installer.installVcsLibrary(library, id, {
			url: url,
			ref: hash,
			branch: branch,
			subDir: argsIterator.next(),
			tag: argsIterator.next()
		});
	}

	final libraryAndVersion = ~/^(.+?)(?::(.*))?$/;
	function run() {
		final scope = getScope();

		libraryAndVersion.match(getArgument("Library[:version]"));

		final project = ProjectName.ofString(libraryAndVersion.matched(1));
		final versionStr = libraryAndVersion.matched(2);
		final version = if (versionStr != null) haxelib.api.Version.ofString(versionStr) else null;

		try {
			scope.runScript(project, {
				args: [for (arg in argsIterator) arg],
				useGlobalRepo: useGlobalRepo
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
		Connection.setProxy({
			host: host,
			port: port,
			auth: authName == "" ? null : {user: authName, pass: authPass}
		});
		Cli.print("Testing proxy...");
		if (!Connection.testConnection() && !Cli.ask("Proxy connection failed. Use it anyway"))
			return;

		File.saveContent(rep + "/.proxy", haxe.Serializer.run(proxy));
		Cli.print("Proxy setup done");
	}

	function loadProxy() {
		final rep = getRepositoryPath();
		final content = try File.getContent(rep + "/.proxy") catch(e) return; // return if no proxy set
		final proxy = haxe.Unserializer.run(content);

		Connection.setProxy(proxy);
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
		final json = haxelib.api.ConvertXml.convert(xmlString);
		final jsonString = haxelib.api.ConvertXml.prettyPrint(json);

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
		final installer = setupAndGetInstaller();
		installer.installLocal(getArgument("Package"));
	}

	function updateSelf() {
		final scope = Scope.getScopeForRepository(Repository.getGlobal());
		final installer = setupAndGetInstaller(scope);
		installer.update(HAXELIB_LIBNAME);
	}
}
