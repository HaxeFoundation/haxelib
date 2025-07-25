package haxelib.api;

import sys.FileSystem;
import sys.io.File;
import haxe.ds.Option;

import haxelib.Data;
import haxelib.VersionData;
import haxelib.api.Repository;
import haxelib.api.Vcs;
import haxelib.api.LibraryData;

using StringTools;
using Lambda;
using haxelib.MetaData;

/** Exception thrown when an error occurs during installation. **/
class InstallationException extends haxe.Exception {}

/** Exception thrown when an update is cancelled. **/
class UpdateCancelled extends InstallationException {}

/** Exception thrown when a `vcs` error interrupts installation. **/
class VcsCommandFailed extends InstallationException {
	public final type:VcsID;
	public final code:Int;
	public final stdout:String;
	public final stderr:String;

	public function new(type, code, stdout, stderr) {
		this.type = type;
		this.code = code;
		this.stdout = stdout;
		this.stderr = stderr;
		super('$type command failed.');
	}
}

/** Enum for indication the importance of a log message. **/
enum LogPriority {
	/** Regular messages **/
	Default;
	/** Messages that can be ignored for cleaner output. **/
	Optional;
	/**
		Messages that are only useful for debugging purposes. Often for
		raw executable output.
	**/
	Debug;
}

/**
	A instance of a user interface used by an Installer instance.

	Contains functions that are executed on certain events or for
	logging information.
**/
@:structInit
class UserInterface {
	final _log:Null<(msg:String, priority:LogPriority)-> Void>;
	final _confirm:(msg:String)->Bool;
	final _logDownloadProgress:Null<(filename:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void>;
	final _logInstallationProgress:Null<(msg:String, current:Int, total:Int) -> Void>;

	/**
		`log` function used for logging information.

		`confirm` function used to confirm certain operations before they occur.
		If it returns `true`, the operation will take place,
		otherwise it will be cancelled.

		`downloadProgress` function used to track download progress of libraries from the Haxelib server.

		`installationProgress` function used to track installation progress.
	**/
	public function new(
		?log:Null<(msg:String, priority:LogPriority)-> Void>,
		?confirm:Null<(msg:String)->Bool>,
		?logDownloadProgress:Null<(filename:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void>,
		?logInstallationProgress:Null<(msg:String, current:Int, total:Int) -> Void>
	) {
		_log = log;
		_confirm = confirm != null ? confirm : (_)-> {true;};
		_logDownloadProgress = logDownloadProgress;
		_logInstallationProgress = logInstallationProgress;
	}

	public inline function log(msg:String, priority:LogPriority = Default):Void {
		if (_log != null)
			_log(msg, priority);
	}

	public inline function confirm(msg:String):Bool {
		return _confirm(msg);
	}

	public inline function logInstallationProgress(msg:String, current:Int, total:Int):Void {
		if (_logInstallationProgress != null)
			_logInstallationProgress(msg, current, total);
	}

	public inline function logDownloadProgress(filename:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float):Void {
		if (_logDownloadProgress != null)
			_logDownloadProgress(filename, finished, cur, max, downloaded, time);
	}

	public inline function getDownloadProgressFunction():Null<(filename:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void> {
		return _logDownloadProgress;
	}
}

private class InstallData {
	public final name:ProjectName;
	public final version:Version;
	public final isLatest:Bool;
	public final versionData:VersionData;

	function new(name:ProjectName, version:Version, installData:VersionData, isLatest:Bool) {
		this.name = name;
		this.version = version;
		this.versionData = installData;
		this.isLatest = isLatest;
	}

	public static function create(name:ProjectName, libFlagData:Option<VersionData>, versionData:Null<Array<SemVer>>):InstallData {
		if (versionData != null && versionData.length == 0)
			throw new InstallationException('The library $name has not yet released a version');

		return switch libFlagData {
			case None:
				final semVer = getLatest(versionData);
				new InstallData(name, semVer, Haxelib(semVer), true);
			case Some(Haxelib(version)) if (!versionData.contains(version)):
				throw new InstallationException('No such version $version for library $name');
			case Some(Haxelib(version)):
				new InstallData(name, version, Haxelib(version), version == getLatest(versionData));
			case Some(VcsInstall(version, vcsData)):
				new InstallData(name, version, VcsInstall(version, vcsData), false);
		}
	}
}

private function getLatest(versions:Array<SemVer>):SemVer {
	if (versions.length == 0)
		throw 'Library has not yet released a version';

	final versions = versions.copy();
	versions.sort(function(a, b) return -SemVer.compare(a, b));

	// get most recent non preview version
	for (v in versions)
		if (v.preview == null)
			return v;
	return versions[0]; // otherwise the most recent one
}

/** Class for installing libraries into a scope and setting their versions.
**/
class Installer {
	/** If set to `true` library dependencies will not be installed. **/
	public var skipDependencies = false;

	/**
		If this is set to `true`, dependency versions will be reinstalled
		even if already installed.
	 **/
	public var forceInstallDependencies = false;

	/**
		If set to `true`, submodules will not get cloned or updated when
		installing VCS libraries.

		This setting only works for libraries installed via a VCS that allows
		cloning a repository without its submodules (only `git`).
	**/
	public var noVcsSubmodules = false;

	final scope:Scope;
	final repository:Repository;
	final userInterface:UserInterface;

	final vcsDataByName = new Map<ProjectName, VcsData>();

	/**
		Creates a new Installer object that installs projects to `scope`.

		If `userInterface` is passed in, it will be used as the interface
		for logging information and for operations that require user confirmation.
	 **/
	public function new(scope:Scope, ?userInterface:UserInterface){
		this.scope = scope;
		repository = scope.repository;

		this.userInterface = userInterface != null? userInterface : {};
	}

	/** Installs library from the zip file at `path`. **/
	public function installLocal(path:String) {
		final path = FileSystem.fullPath(path);
		userInterface.log('Installing $path');
		// read zip content
		final zip = FsUtils.unzip(path);

		final info = Data.readDataFromZip(zip, NoCheck);
		final library = info.name;
		final version = info.version;

		installZip(info.name, info.version, zip);

		// set current version
		scope.setVersion(library, version);

		userInterface.log('  Current version is now $version');
		userInterface.log("Done");

		handleDependencies(library, version, info.dependencies);
	}

	/**
		Clears cached data for git or hg libraries.

		An installer instance keeps track of updated vcs dependencies
		to avoid cloning the same version twice.

		This function can be used to clear that memory.
	**/
	public function forgetVcsDataCache():Void {
		vcsDataByName.clear();
	}

	/** Installs libraries from the `haxelib.json` file at `path`. **/
	public function installFromHaxelibJson(path:String) {
		final path = FileSystem.fullPath(path);
		userInterface.log('Installing libraries from $path');

		final dependencies = Data.readData(File.getContent(path), NoCheck).dependencies;

		try
			installFromDependencies(dependencies)
		catch (e)
			throw new InstallationException('Failed installing dependencies from $path:\n$e');
	}

	/**
		Installs the libraries required to build the HXML file at `path`.

		Throws an error when trying to install a library from the haxelib
		server if the library has no versions or if the requested
		version does not exist.

		If `confirmHxmlInstall` is passed in, it will be called with information
		about the libraries to be installed, and the installation only proceeds if
		it returns `true`.
	 **/
	public function installFromHxml(path:String, ?confirmHxmlInstall:(libs:Array<{name:ProjectName, version:Version}>) -> Bool) {
		final path = FileSystem.fullPath(path);
		userInterface.log('Installing all libraries from $path:');
		final libsToInstall = LibFlagData.fromHxml(path);

		if (libsToInstall.empty())
			return;

		// Check the version numbers are all good
		userInterface.log("Loading info about the required libraries");

		final installData = getFilteredInstallData(libsToInstall);

		final libVersions = [
			for (library in installData)
				{name:library.name, version:library.version}
		];
		// Abort if not confirmed
		if (confirmHxmlInstall != null && !confirmHxmlInstall(libVersions))
			return;

		var hasFailures = false;

		for (library in installData) {
			if (library.versionData.match(Haxelib(_)) && repository.isVersionInstalled(library.name, library.version)) {
				final version = SemVer.ofString(library.version);
				if (scope.isLibraryInstalled(library.name) && scope.getVersion(library.name) == version) {
					userInterface.log('Library ${library.name} version $version is already installed and set as current');
				} else {
					userInterface.log('Library ${library.name} version $version is already installed');
					if (scope.isLocal || userInterface.confirm('Set ${library.name} to version $version')) {
						scope.setVersion(library.name, version);
						userInterface.log('Library ${library.name} current version is now $version');
					}
				}
				continue;
			}

			try
				installFromVersionData(library.name, library.versionData)
			catch (e) {
				hasFailures = true;
				userInterface.log(e.toString());
				continue;
			}

			final libraryName = switch library.versionData {
				case VcsInstall(version, vcsData): getVcsLibraryName(library.name, version, vcsData.subDir);
				case _: library.name;
			}

			setVersionAndLog(libraryName, library.versionData);

			userInterface.log("Done");

			handleDependenciesGeneral(libraryName, library.versionData);
		}

		if (hasFailures) throw "Some libraries could not be installed.";
	}

	/**
		Installs `version` of `library` from the haxelib server.

		If `version` is omitted, the latest version is installed.

		If `forceSet` is set to true and the installer is running with
		a global scope, the new version is always set as the current one.

		Otherwise, `version` is set as current if it is the latest version
		of `library` or if no current version is set for `library`.

		If the `version` specified does not exist on the server,
		an `InstallationException` is thrown.
	 **/
	public function installFromHaxelib(library:ProjectName, ?version:SemVer, forceSet:Bool = false) {
		final info = Connection.getInfo(library);
		// get correct name capitalization so that the logged output is correct
		final library = ProjectName.ofString(info.name);

		final versions = [for (v in info.versions) v.name];

		if (versions.length == 0)
			throw new InstallationException('The library $library has not yet released a version');

		final versionSpecified = version != null;
		if (versionSpecified && !versions.contains(version))
			throw new InstallationException('No such version $version for library $library');

		version = version ?? getLatest(versions);

		downloadAndInstall(library, version);

		// if no version was specified, we installed the latest version anyway
		if (scope.isLocal || forceSet || !versionSpecified || version == getLatest(versions) || !scope.isLibraryInstalled(library)) {
			scope.setVersion(library, version);
			userInterface.log('  Current version is now $version');
		}
		userInterface.log("Done");

		handleDependencies(library, version);
	}

	/**
		Installs `library` from a git or hg repository (specified by `id`)

		`vcsData` contains information on the source repository
		and the requested state.
	**/
	public function installVcsLibrary(library:ProjectName, id:VcsID, vcsData:VcsData) {
		installVcs(library, id, vcsData);

		library = getVcsLibraryName(library, id, vcsData.subDir);

		setVcsVersion(library, id, vcsData);

		userInterface.log("Done");

		handleDependenciesVcs(library, id, vcsData.subDir);
	}

	/**
		Updates `library` to the newest version on the haxelib server,
		or pull latest changes with git or hg.
	**/
	public function update(library:ProjectName) {
		final version = scope.resolve(library);
		library = getCorrectName(library, version);
		// check if update is needed
		if (isUpToDate(library, version)) {
			userInterface.log('Library $library is already up to date');
			return;
		}

		try {
			updateResolved(library, version);
		} catch (e:UpdateCancelled) {
			// perhaps we should exit with an error?
			return;
		}
	}

	function getCorrectName(library:ProjectName, versionData:VersionData) {
		return switch versionData {
			case VcsInstall(version, {subDir: subDir}):
				getVcsLibraryName(library, version, subDir);
			case Haxelib(_):
				ProjectName.ofString(Connection.getInfo(library).name);
		};
	}

	function isUpToDate(library:ProjectName, versionData:VersionData):Bool {
		return switch versionData {
			case Haxelib(version):
				version == Connection.getLatestVersion(library);
			case VcsInstall(version, _):
				final vcs = getVcs(version);
				!FsUtils.runInDirectory(repository.getVersionPath(library, version), vcs.checkRemoteChanges);
		};
	}

	function updateResolved(library:ProjectName, versionData:VersionData)
		switch versionData {
			case VcsInstall(version, vcsData):
				final vcs = getVcs(version);
				// with version locking we'll be able to be smarter with this
				final libPath = repository.getVersionPath(library, version);

				FsUtils.runInDirectory(
					libPath,
					function() {
						if (vcs.getRef() != vcsData.commit) {
							throw 'Cannot update ${version.getName()} version of $library. There are local changes.';
						}
				});
				updateVcs(library, version, vcs);

				vcsData.commit = FsUtils.runInDirectory(libPath, vcs.getRef);
				setVcsVersion(library, version, vcsData);

				// TODO: Properly handle sub directories
				handleDependenciesVcs(library, version, null);
			case Haxelib(_):
				final latest = Connection.getLatestVersion(library);
				if (repository.isVersionInstalled(library, latest)) {
					userInterface.log('Latest version $latest of $library is already installed');
					// only ask if running in a global scope
					if (!scope.isLocal && !userInterface.confirm('Set $library to $latest'))
						return;
				} else {
					downloadAndInstall(library, latest);
				}
				scope.setVersion(library, latest);
				userInterface.log('  Current version is now $latest');
				userInterface.log("Done");
				handleDependencies(library, latest);
		}

	/**
		Updates all libraries in the scope.

		If a library update fails, it is skipped.
	**/
	public function updateAll():Void {
		final libraries = scope.getLibraryNames();
		var updated = false;
		var failures = 0;

		for (library in libraries) {
			userInterface.log('Checking $library');

			final version = scope.resolve(library);
			if (isUpToDate(library, version)) {
				continue;
			}

			try {
				updateResolved(library, version);
				updated = true;
			} catch (e:UpdateCancelled) {
				continue;
			} catch (e) {
				++failures;
				userInterface.log("Failed to update: " + e.toString());
				userInterface.log(e.stack.toString(), Debug);
			}
		}

		if (updated) {
			if (failures == 0) {
				userInterface.log("All libraries are now up-to-date");
			} else {
				userInterface.log("All libraries are now up-to-date");
			}
		} else
			userInterface.log("All libraries are already up-to-date");
	}

	function getDependencies(path:String):Dependencies {
		final jsonPath = path + Data.JSON;
		if (!FileSystem.exists(jsonPath))
			return {};

		return switch (Data.readData(File.getContent(jsonPath), NoCheck).dependencies) {
			case null: {};
			case dependencies: dependencies;
		}
	}

	/**
		Get the name found in the `haxelib.json` for a vcs library.

		If `givenName` is an alias (it is completely different from the internal name)
		then `givenName` is returned instead
	 **/
	function getVcsLibraryName(givenName:ProjectName, id:VcsID, subDir:Null<String>):ProjectName {
		final jsonPath = scope.getPath(givenName, id) + (if (subDir != null) subDir else "") + Data.JSON;
		if (!FileSystem.exists(jsonPath))
			return givenName;
		final internalName = Data.readData(File.getContent(jsonPath), NoCheck).name;
		return ProjectName.getCorrectOrAlias(internalName, givenName);
	}

	function handleDependenciesGeneral(library:ProjectName, installData:VersionData) {
		if (skipDependencies)
			return;

		switch installData {
			case Haxelib(version):
				handleDependencies(library, version);
			case VcsInstall(version, {subDir: subDir}):
				handleDependenciesVcs(library, version, subDir);
		}
	}

	function handleDependenciesVcs(library:ProjectName, id:VcsID, subDir:Null<String>) {
		if (skipDependencies)
			return;

		final path = repository.getVersionPath(library, id) + switch subDir {
			case null: '';
			case subDir: subDir;
		}
		final dependencies = getDependencies(path);

		try
			installFromDependencies(dependencies)
		catch (e)
			throw new InstallationException('Failed installing dependencies for $library:\n$e');
	}

	function handleDependencies(library:ProjectName, version:SemVer, dependencies:Dependencies = null) {
		if (skipDependencies)
			return;

		if (dependencies == null)
			dependencies = getDependencies(repository.getVersionPath(library, version));

		try
			installFromDependencies(dependencies)
		catch (e)
			throw new InstallationException('Failed installing dependencies for $library:\n$e');
	}

	function installFromDependencies(dependencies:Dependencies) {
		final libs = getLibFlagDataFromDependencies(dependencies);

		final installData = getInstallData(libs);

		for (lib in installData) {
			final version = lib.version;
			userInterface.log('Installing dependency ${lib.name} $version');

			switch lib.versionData {
				case Haxelib(v) if (!forceInstallDependencies && repository.isVersionInstalled(lib.name, v)):
					userInterface.log('Library ${lib.name} version $v is already installed');
					continue;
				default:
			}

			installFromVersionData(lib.name, lib.versionData);

			final library = switch lib.versionData {
				case VcsInstall(version, vcsData): getVcsLibraryName(lib.name, version, vcsData.subDir);
				case _: lib.name;
			}

			// vcs versions always get set
			if (!scope.isLibraryInstalled(library) || lib.versionData.match(VcsInstall(_))) {
				setVersionAndLog(library, lib.versionData);
			}

			userInterface.log("Done");
			handleDependenciesGeneral(library, lib.versionData);
		}
	}

	function getLibFlagDataFromDependencies(dependencies:Dependencies):List<{name:ProjectName, data:Option<VersionData>}> {
		final list = new List<{name:ProjectName, data:Option<VersionData>}>();
		for (library => versionStr in dependencies)
			// no version specified and dev set, no need to install dependency
			if (forceInstallDependencies || !(versionStr == '' && scope.isOverridden(library)))
				list.push({name: library, data: LibFlagData.extractFromDependencyString(versionStr)});

		return list;
	}

	function setVersionAndLog(library:ProjectName, installData:VersionData) {
		switch installData {
			case VcsInstall(version, vcsData):
				setVcsVersion(library, version, vcsData);
			case Haxelib(version):
				scope.setVersion(library, version);
				userInterface.log('  Current version is now $version');
		}
	}

	function getReproducibleVcsData(library:ProjectName, version:VcsID, data:VcsData):VcsData {
		final vcs = getVcs(version);
		final libPath = repository.getVersionPath(library, version);
		return FsUtils.runInDirectory(libPath, function():VcsData {
			return {
				url: data.url,
				commit: data.commit ?? vcs.getRef(),
				branch: if (data.branch == null && data.tag == null) vcs.getBranchName() else data.branch,
				tag: data.tag,
				subDir: if (data.subDir != null) haxe.io.Path.normalize(data.subDir) else null
			};
		});
	}

	/**
		Retrieves fully reproducible vcs data if necessary,
		and then uses it to lock down the current version.
	**/
	function setVcsVersion(library:ProjectName, version:VcsID, data:VcsData) {
		// save here prior to modification
		vcsDataByName[library] = data;
		if (!data.isReproducible()) {
			// always get reproducible data for local scope
			data = getReproducibleVcsData(library, version, data);
		}

		scope.setVcsVersion(library, version, data);
		if (data.subDir == "" || data.subDir == null) {
			userInterface.log('  Current version is now $version');
		} else {
			final path = scope.getPath(library);
			userInterface.log('  Development directory set to $path');
		}
	}

	static function getInstallData(libs:List<{name:ProjectName, data:Option<VersionData>}>):List<InstallData> {
		final installData = new List<InstallData>();

		final versionsData = getDataForServerLibraries(libs);

		for (lib in libs) {
			final data = versionsData[lib.name];
			if (data == null) {
				installData.add(InstallData.create(lib.name, lib.data, null));
				continue;
			}
			final libName = data.confirmedName;
			installData.add(InstallData.create(libName, lib.data, data.versions));
		}

		return installData;
	}

	/** Returns a list of all required install data for `libs`, and also filters out repeated libs. **/
	static function getFilteredInstallData(libs:List<{name:ProjectName, data:Option<VersionData>}>):List<InstallData> {
		final installDataList = new List<InstallData>();
		final includedLibs = new Map<ProjectName, Array<VersionData>>();

		final serverData = getDataForServerLibraries(libs);

		for (lib in libs) {
			final installData = {
				final data = serverData[lib.name];
				if (data == null) {
					InstallData.create(lib.name, lib.data, null);
				} else {
					final libName = data.confirmedName;
					InstallData.create(libName, lib.data, data.versions);
				}
			}

			final lowerCaseName = ProjectName.ofString(installData.name.toLowerCase());

			final includedVersions = includedLibs[lowerCaseName];
			if (includedVersions == null)
				includedLibs[lowerCaseName] = [];
			else if (isVersionIncluded(installData.versionData, includedVersions))
				continue; // do not include twice
			includedLibs[lowerCaseName].push(installData.versionData);
			installDataList.add(installData);
		}

		return installDataList;
	}

	/**
		Returns a map of name and version information for libraries in `libs` that
		would be installed from the haxelib server.
	**/
	static function getDataForServerLibraries(libs:List<{name:ProjectName, data:Option<VersionData>}>):
		Map<ProjectName, {confirmedName:ProjectName, versions:Array<SemVer>}>
	{
		final toCheck:Array<ProjectName> = [];
		for (lib in libs)
			if (lib.data.match(None | Some(Haxelib(_)))) // Do not check vcs info
				toCheck.push(lib.name);

		return Connection.getLibraryNamesAndVersions(toCheck);
	}

	static function isVersionIncluded(toCheck:VersionData, versions:Array<VersionData>):Bool {
		for (version in versions) {
			switch ([toCheck, version]) {
				case [Haxelib(a), Haxelib(b)] if(a == b): return true;
				case [VcsInstall(a, vcsData1), VcsInstall(b, vcsData2)]
					if ((a == b)
						&& (vcsData1.url == vcsData2.url)
						&& (vcsData1.commit == vcsData2.commit)
						&& (vcsData1.branch == vcsData2.branch)
						&& (vcsData1.tag == vcsData2.tag)
						&& (vcsData1.subDir == vcsData2.subDir)
					// maybe this equality check should be moved to vcsData
					): return true;
				default:
			}
		}
		return false;
	}

	function installFromVersionData(library:ProjectName, data:VersionData) {
		switch data {
			case Haxelib(version):
				downloadAndInstall(library, version);
			case VcsInstall(version, vcsData):
				installVcs(library, version, vcsData);
		}
	}

	function downloadAndInstall(library:ProjectName, version:SemVer) {
		// download to temporary file
		final filename = Data.fileName(library, version);

		userInterface.log('Downloading $filename...');

		final filepath = haxe.io.Path.join([repository.path, filename]);

		final progressFunction = switch userInterface.getDownloadProgressFunction() {
			case null:
				null;
			case fn:
				(f, c, m, d, t) -> {fn('Downloading $filename', f, c, m, d, t);};
		};

		Connection.download(filename, filepath, progressFunction);

		final zip = try FsUtils.unzip(filepath) catch (e) {
			FileSystem.deleteFile(filepath);
			Util.rethrow(e);
		}
		installZip(library, version, zip);
		FileSystem.deleteFile(filepath);

		try
			Connection.postInstall(library, version)
		catch (e:Dynamic) {};
	}

	function installZip(library:ProjectName, version:SemVer, zip:List<haxe.zip.Entry>):Void {
		userInterface.log('Installing $library...');

		final versionPath = repository.getVersionPath(library, version);
		FsUtils.safeDir(versionPath);

		// locate haxelib.json base path
		final basepath = Data.locateBasePath(zip);

		// unzip content
		final entries = [for (entry in zip) if (entry.fileName.startsWith(basepath)) entry];
		final total = entries.length;
		for (i in 0...total) {
			final zipfile = entries[i];
			final fileName = {
				final full = zipfile.fileName;
				// remove basepath
				full.substr(basepath.length, full.length - basepath.length);
			}
			if (fileName.charAt(0) == "/" || fileName.charAt(0) == "\\" || fileName.split("..").length > 1)
				throw new InstallationException("Invalid filename : " + fileName);

			userInterface.logInstallationProgress('Installing $library $version', i, total);

			final dirs = ~/[\/\\]/g.split(fileName);
			final file = dirs.pop();

			var path = "";
			for (d in dirs) {
				path += d;
				FsUtils.safeDir(versionPath + path);
				path += "/";
			}

			if (file == "") {
				if (path != "")
					userInterface.log('  Created $path', Debug);
				continue; // was just a directory
			}
			path += file;
			userInterface.log('  Install $path', Debug);
			File.saveBytes(versionPath + path, haxe.zip.Reader.unzip(zipfile));
		}
		userInterface.logInstallationProgress('Done installing $library $version', total, total);
	}

	function getVcs(id:VcsID):Vcs {
		final vcs = Vcs.create(id, userInterface.log.bind(_, Debug), userInterface.log.bind(_, Optional));
		if (vcs == null || !vcs.available)
			throw 'Could not use $id, please make sure it is installed and available in your PATH.';
		return vcs;
	}

	function installVcs(library:ProjectName, id:VcsID, vcsData:VcsData) {
		final vcs = getVcs(id);

		final libPath = repository.getVersionPath(library, id);

		function doVcsClone() {
			userInterface.log('Installing $library from ${vcsData.url}'
				+ (vcsData.branch != null ? " branch: " + vcsData.branch : "")
				+ (vcsData.tag != null ? " tag: " + vcsData.tag : "")
				+ (vcsData.commit != null ? " commit: " + vcsData.commit : "")
			);
			try {
				vcs.clone(libPath, vcsData, noVcsSubmodules);
			} catch (error:VcsError) {
				FsUtils.deleteRec(libPath);
				switch (error) {
					case VcsUnavailable(vcs):
						throw 'Could not use ${vcs.executable}, please make sure it is installed and available in your PATH.';
					case CantCloneRepo(_, _, stderr):
						throw 'Could not clone ${id.getName()} repository' + (stderr != null ? ":\n" + stderr : ".");
					case CantCheckout(_, ref, stderr):
						throw 'Could not checkout commit or tag "$ref": ' + stderr;
					case SubmoduleError(_, repo, stderr):
						throw 'Could not clone submodule(s) from $repo: ' + stderr;
					case CommandFailed(_, code, stdout, stderr):
						throw new VcsCommandFailed(id, code, stdout, stderr);
				};
			}
		}

		if (repository.isVersionInstalled(library, id)) {
			userInterface.log('You already have $library version $id installed.');

			final wasUpdated = vcsDataByName.exists(library);

			final currentData = vcsDataByName[library] ?? repository.getVcsData(library, id);
			FsUtils.runInDirectory(libPath, function() {
				if (vcs.getRef() != currentData.commit) {
					throw 'Cannot overwrite currently installed $id version of $library. There are local changes.';
				}
			});

			// TODO check different urls as well
			if (vcsData.branch != null && (!wasUpdated || currentData.branch != vcsData.branch)) {
				final currentBranchStr = currentData.branch != null ? currentData.branch : "<unspecified>";
				if (!userInterface.confirm('Overwrite branch: "$currentBranchStr" with "${vcsData.branch}"')) {
					userInterface.log('Library $library $id repository remains at "$currentBranchStr"');
					return;
				}
				FsUtils.deleteRec(libPath);
				doVcsClone();
			} else if (!wasUpdated && FsUtils.runInDirectory(libPath, vcs.checkRemoteChanges)) {
				userInterface.log('Updating $library version $id...');
				updateVcs(library, id, vcs);
			} else {
				userInterface.log('Library $library version $id already up to date');
			}
		} else {
			FsUtils.safeDir(libPath);
			doVcsClone();
		}

		vcsData.commit = FsUtils.runInDirectory(libPath, vcs.getRef);
	}

	function updateVcs(library:ProjectName, id:VcsID, vcs:Vcs)
		FsUtils.runInDirectory(repository.getVersionPath(library, id), function() {
			if (vcs.hasLocalChanges()) {
				if (!userInterface.confirm('Reset changes to $library $id repository in order to update to latest version')) {
					userInterface.log('$library repository has not been modified', Optional);
					throw new UpdateCancelled('${id.getName()} update in ${Sys.getCwd()} was cancelled');
				}
				vcs.resetLocalChanges();
			}

			vcs.mergeRemoteChanges();
			userInterface.log('$library was updated');
		});
}
