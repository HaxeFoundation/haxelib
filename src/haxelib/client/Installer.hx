package haxelib.client;

import sys.FileSystem;
import sys.io.File;

import haxelib.client.Repository;
import haxelib.client.Vcs;
import haxelib.client.LibraryData;
import haxelib.client.LibFlagData;

using StringTools;
using Lambda;
using haxelib.Data;

class InstallationException extends haxe.Exception {}
class NoHaxelibReleases extends InstallationException {
	public function new(lib:String) super('The library $lib has not yet released a version');
}
class HaxelibVersionNotFound extends InstallationException {
	public function new(lib:String, version:SemVer) super('No such version $version for library $lib');
}
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

enum LogPriority {
	/** Regular messages **/
	Default;
	/** Messages that can be ignored for cleaner output.
	 **/
	Optional;
	/** Messages that are only useful for debugging purposes. Often for
		raw executable output. **/
	Debug;
}
/** Like LibFlagData, but None is not an option.

	Always contains enough information to reproducibly
	install the same version of a library.
**/
enum InstallData {
	Haxelib(version:SemVer);
	VcsInstall(version:VcsID, vcsData:VcsData);
}

private class AllInstallData {
	public final name:ProjectName;
	public final version:Version;
	public final isLatest:Bool;
	public final installData:InstallData;

	function new(name:ProjectName, version:Version, installData:InstallData, isLatest:Bool) {
		this.name = name;
		this.version = version;
		this.installData = installData;
		this.isLatest = isLatest;
	}

	public static function create(name:ProjectName, libFlagData:LibFlagData, versionData:Null<Array<SemVer>>):AllInstallData {
		if (versionData != null && versionData.length == 0)
			throw new NoHaxelibReleases(name);

		return switch libFlagData {
			case None:
				final semVer = getLatest(versionData);
				new AllInstallData(name, semVer, Haxelib(semVer), true);
			case Haxelib(version) if (!versionData.contains(version)):
				throw new HaxelibVersionNotFound(name, version);
			case Haxelib(version):
				new AllInstallData(name, version, Haxelib(version), version == getLatest(versionData));
			case VcsInstall(version, vcsData):
				new AllInstallData(name, version, VcsInstall(version, vcsData), false);
		}
	}
}

private class AlreadyUpToDate extends InstallationException {}

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

/** Class for installing libraries into the scope and setting their versions.
**/
class Installer {
	/** If set to `true` library dependencies will not
		be installed.
	**/
	public static var skipDependencies = false;

	/** If this is set to true, dependency versions will be
		reinstalled even if already installed.
	 **/
	public static var forceInstallDependencies = false;

	final scope:Scope;
	final repository:Repository;

	final vcsBranchesByLibraryName = new Map<ProjectName, String>();

	/** Creates a new Installer object that installs projects to `scope`.
	 **/
	public function new(scope:Scope){
		this.scope = scope;
		repository = scope.repository;
	}

	/** Function to pass log information into. **/
	public dynamic function log(msg:String, priority:LogPriority = Default):Void
		if(priority != Debug) Sys.println(msg);

	/**
		Confirmation function when overriding installed git libraries for example.

		If it returns `true`, the operation will take place,
		otherwise it will be cancelled.
	 **/
	public dynamic function confirm(msg:String):Bool {return true;}

	/** Function to execute when a haxelib or local library is being installed. **/
	public var installationProgress:Null<(msg:String, current:Int, total:Int) -> Void> = null;

	/** Function to execute when a library is being downloaded from the haxelib server.

		Information on the download progress is passed in.
	 **/
	public var downloadProgress:Null<(filename:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void> = null;

	/** Installs library from the zip file at `path`. **/
	public function installLocal(path:String) {
		final path = FileSystem.fullPath(path);
		log('Installing $path');
		// read zip content
		final zip = FsUtils.unzip(path);

		final info = Data.readInfos(zip, false);
		final library = info.name;
		final version = info.version;

		installZip(info.name, info.version, zip);

		// set current version
		scope.setVersion(library, version);

		log('  Current version is now $version');
		log("Done");

		handleDependencies(library, version, info.dependencies);
	}

	/** Clears memory on git or hg library branches.

		An installer instance keeps track of updated vcs dependencies
		to avoid cloning the same branch twice.

		This function can be used to clear that memory.
	**/
	public function forgetVcsBranches():Void {
		vcsBranchesByLibraryName.clear();
	}

	/** Installs libraries from the `haxelib.json` at `path` **/
	public function installFromHaxelibJson(path:String) {
		final path = FileSystem.fullPath(path);
		log('Installing libraries from $path');

		final dependencies = Data.readData(File.getContent(path), false).dependencies;

		try
			installFromDependencies(dependencies)
		catch (e)
			throw new InstallationException('Failed installing dependencies from $path:\n$e');
	}

	/** Installs the libraries required to build the HXML file at `path`.

		Throws an error when trying to install a library from the haxelib
		server if the library has no versions or if the requested
		version does not exist.

		If `confirmHxmlInstall` is passed in, it will be called with information
		about the libraries to be installed, and the installation only proceeds if
		it returns `true`.
	 **/
	public function installFromHxml(path:String, ?confirmHxmlInstall:(libs:Array<{name:ProjectName, version:Version}>) -> Bool) {
		final path = FileSystem.fullPath(path);
		log('Installing all libraries from $path:');
		final libsToInstall = LibFlagData.fromHxml(path);

		if (libsToInstall.empty())
			return;

		// Check the version numbers are all good
		log("Loading info about the required libraries");

		final installData = getFilteredInstallData(libsToInstall);

		final libVersions = [
			for (library in installData)
				{name:library.name, version:library.version}
		];
		// Abort if not confirmed
		if (confirmHxmlInstall != null && !confirmHxmlInstall(libVersions))
			return;

		for (library in installData) {
			try
				installFromInstallData(library.name, library.installData)
			catch (e) {
				log(e.toString());
				continue;
			}

			if (library.isLatest || !scope.isLibraryInstalled(library.name))
				setVersionAndLog(library.name, library.installData);

			log("Done");

			handleDependenciesGeneral(library.name, library.installData);
		}
	}

	/** Install the latest version of `library` from haxelib. **/
	public function installLatestFromHaxelib(library:ProjectName) {
		final versions = Connection.getVersions(library);
		if (versions.length == 0)
			throw new NoHaxelibReleases(library);

		final version = getLatest(versions);
		downloadAndInstall(library, version);

		scope.setVersion(library, version);

		log('  Current version is now $version');
		log("Done");

		handleDependencies(library, version);
	}

	/** Installs `version` of `library` from the haxelib server.

		If `forceSet` is set to true and running in a global scope,
		the new version is always set as the current one.
	 **/
	public function installFromHaxelib(library:ProjectName, version:SemVer, forceSet:Bool = false) {
		final versions = Connection.getVersions(library);
		if (versions.length == 0)
			throw new NoHaxelibReleases(library);
		if (!versions.contains(version))
			throw new HaxelibVersionNotFound(library, version);

		downloadAndInstall(library, version);

		if (scope.isLocal || version == getLatest(versions) || !scope.isLibraryInstalled(library) || forceSet) {
			scope.setVersion(library, version);
			log('  Current version is now $version');
		}
		log("Done");

		handleDependencies(library, version);
	}

	/**
		Install `library` from a git or hg repository (specified by `id`)

		`vcsData` contains information on the source repository
		and the requested state.
	**/
	public function installVcsLibrary(library:ProjectName, id:VcsID, vcsData:VcsData) {
		installVcs(library, id, vcsData);

		scope.setVcsVersion(library, id, vcsData);

		if (vcsData.subDir != null) {
			final path = scope.getPath(library);
			log('  Development directory set to $path');
		} else {
			log('  Current version is now $id');
		}
		log("Done");

		handleDependenciesVcs(library, id, vcsData.subDir);
	}

	/** Updates `library` to the newest version on the haxelib server,
		or pull latest changes with git or hg.
	**/
	public function update(library:ProjectName) {
		try {
			updateIfNeeded(library);
		} catch (e:AlreadyUpToDate) {
			log(e.toString());
		}
	}

	/**
		Updates all libraries in the scope.

		If a library update fails, it is skipped.
	**/
	public function updateAll():Void {
		final libraries = scope.getLibraryNames();
		var updated = false;

		for (library in libraries) {
			log('Checking $library');
			try {
				updateIfNeeded(library);
				updated = true;
			} catch(e:AlreadyUpToDate) {
				continue;
			} catch(e) {
				log("Failed to update: " + e.toString());
				log(e.stack.toString(), Debug);
			}
		}

		if (updated)
			log("All libraries are now up-to-date");
		else
			log("All libraries are already up-to-date");
	}

	function updateIfNeeded(library:ProjectName) {
		final current = try scope.getVersion(library) catch (_:CurrentVersionException) null;

		final vcsId = try VcsID.ofString(current) catch (_) null;
		if (vcsId != null) {
			final vcs = Vcs.get(vcsId);
			if (vcs == null || !vcs.available)
				throw 'Could not use $vcsId, please make sure it is installed and available in your PATH.';
			// with version locking we'll be able to be smarter with this
			updateVcs(library, vcsId, vcs);

			scope.setVcsVersion(library, vcsId, {url: "UNKNOWN"});

			handleDependenciesVcs(library, vcsId, null);
			// we dont know if a subdirectory was given anymore
			return;
		}

		final semVer = try SemVer.ofString(current) catch (_) null;
		final latest = Connection.getLatestVersion(library);

		if (semVer != null && semVer == latest) {
			throw new AlreadyUpToDate('Library $library is already up to date');
		} else if (repository.isVersionInstalled(library, latest)) {
			log('Latest version $latest of $library is already installed');
			// only ask if running in a global scope
			if (!scope.isLocal && !confirm('Set $library to $latest'))
				return;
		} else {
			downloadAndInstall(library, latest);
		}
		scope.setVersion(library, latest);
		log('  Current version is now $latest');
		log("Done");

		handleDependencies(library, latest);
	}

	function getDependencies(path:String):Dependencies {
		final jsonPath = path + Data.JSON;
		if (!FileSystem.exists(jsonPath))
			return {};

		return switch (Data.readData(File.getContent(jsonPath), false).dependencies) {
			case null: {};
			case dependencies: dependencies;
		}
	}

	function handleDependenciesGeneral(library:ProjectName, installData:InstallData) {
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
			final library = lib.name;
			final version = lib.version;
			log('Installing dependency $library $version');

			switch lib.installData {
				case Haxelib(v) if (!forceInstallDependencies && repository.isVersionInstalled(library, v)):
					log('Library $library version $v is already installed');
					continue;
				default:
			}

			try
				installFromInstallData(library, lib.installData)
			catch (e) {
				log(e.toString());
				continue;
			}
			// vcs versions always get set
			if (!scope.isLibraryInstalled(library) || lib.installData.match(VcsInstall(_))) {
				setVersionAndLog(library, lib.installData);
			}

			log("Done");
			handleDependenciesGeneral(library, lib.installData);
		}
	}

	function getLibFlagDataFromDependencies(dependencies:Dependencies):List<{name:ProjectName, data:LibFlagData}> {
		final list = new List<{name:ProjectName, data:LibFlagData}>();
		for (library => versionStr in dependencies)
			// no version specified and dev set, no need to install dependency
			if (forceInstallDependencies || !(versionStr == '' && scope.isOverridden(library)))
				list.push({name: library, data: LibFlagData.extractFromDependencyString(versionStr)});

		return list;
	}

	function setVersionAndLog(library:ProjectName, installData:InstallData) {
		switch installData {
			case VcsInstall(version, vcsData):
				scope.setVcsVersion(library, version, vcsData);
				if (vcsData.subDir == null){
					log('  Current version is now $version');
				} else {
					final path = scope.getPath(library);
					log('  Development directory set to $path');
				}
			case Haxelib(version):
				scope.setVersion(library, version);
				log('  Current version is now $version');
		}
	}

	static function getInstallData(libs:List<{name:ProjectName, data:LibFlagData}>):List<AllInstallData> {
		final installData = new List<AllInstallData>();

		final versionsData = getVersionsForEmptyLibs(libs);

		for (lib in libs)
			installData.add(AllInstallData.create(lib.name, lib.data, versionsData[lib.name]));

		return installData;
	}

	/** Returns a list of all require install data for the `libs`, and also filters out repeated libs. **/
	static function getFilteredInstallData(libs:List<{name:ProjectName, data:LibFlagData, isTargetLib:Bool}>):List<AllInstallData> {
		final installData = new List<AllInstallData>();
		final includedLibs = new Map<ProjectName, Array<InstallData>>();

		final versionsData = getVersionsForEmptyLibs(libs);

		for (lib in libs) {
			final allInstallData = AllInstallData.create(lib.name, lib.data, versionsData[lib.name]);

			final lowerCaseName = ProjectName.ofString((allInstallData.name : String).toLowerCase());

			final includedVersions = includedLibs[lowerCaseName];
			if (includedVersions != null && (lib.isTargetLib || isVersionIncluded(allInstallData.installData, includedVersions)))
				continue; // do not include twice
			if (includedVersions == null)
				includedLibs[lowerCaseName] = [];
			includedLibs[lowerCaseName].push(allInstallData.installData);
			installData.add(allInstallData);
		}

		return installData;
	}

	/** Returns a map of version information for libraries in `libs` that have empty version information.
	**/
	static function getVersionsForEmptyLibs(libs:List<{name:ProjectName, data:LibFlagData}>):
		Map<ProjectName, Array<SemVer>>
	{
		final toCheck:Array<ProjectName> = [];
		for (lib in libs)
			if (lib.data.match(None | Haxelib(_))) // Do not check vcs info
				toCheck.push(lib.name);

		return Connection.getVersionsForLibraries(toCheck);
	}

	static function isVersionIncluded(toCheck:InstallData, versions:Array<InstallData>):Bool {
		for (version in versions) {
			switch ([toCheck, version]) {
				case [Haxelib(a), Haxelib(b)] if(a == b): return true;
				case [VcsInstall(a, vcsData1), VcsInstall(b, vcsData2)]
					if ((a == b)
						&& (vcsData1.url == vcsData2.url)
						&& (vcsData1.ref == vcsData2.ref)
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

	function installFromInstallData(library:ProjectName, data:InstallData) {
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

		log('Downloading $filename...');

		final filepath = haxe.io.Path.join([repository.path, filename]);

		final progress =
			if (downloadProgress == null) null
			else (f, c, m, d, t)-> {downloadProgress('Downloading $filename', f, c, m, d, t);};

		Connection.download(filename, filepath, progress);

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
		log('Installing $library...');
		final rootPath = repository.getProjectPath(library);
		FsUtils.safeDir(rootPath);
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

			if (installationProgress != null)
				installationProgress('Installing $library $version', i, total);

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
					log('  Created $path', Debug);
				continue; // was just a directory
			}
			path += file;
			log('  Install $path', Debug);
			File.saveBytes(versionPath + path, haxe.zip.Reader.unzip(zipfile));
		}
		if (installationProgress != null)
			installationProgress('Done installing $library $version', total, total);
	}

	function installVcs(library:ProjectName, id:VcsID, vcsData:VcsData) {
		final vcs = Vcs.get(id);
		if (vcs == null || !vcs.available)
			throw 'Could not use $id, please make sure it is installed and available in your PATH.';

		final libPath = repository.getVersionPath(library, id);

		final branch = vcsData.ref != null ? vcsData.ref : vcsData.branch;
		final url:String = vcsData.url;

		function doVcsClone() {
			log('Installing $library from $url' + (branch != null ? " branch: " + branch : ""));
			final tag = vcsData.tag;
			try {
				vcs.clone(libPath, url, branch, tag, log.bind(_, Debug));
			} catch (error:VcsError) {
				FsUtils.deleteRec(libPath);
				switch (error) {
					case VcsUnavailable(vcs):
						throw 'Could not use ${vcs.executable}, please make sure it is installed and available in your PATH.';
					case CantCloneRepo(vcs, _, stderr):
						throw 'Could not clone ${vcs.name} repository' + (stderr != null ? ":\n" + stderr : ".");
					case CantCheckoutBranch(_, branch, stderr):
						throw 'Could not checkout branch, tag or path "$branch": ' + stderr;
					case CantCheckoutVersion(_, version, stderr):
						throw 'Could not checkout tag "$version": ' + stderr;
					case CommandFailed(vcs, code, stdout, stderr):
						throw new VcsCommandFailed(id, code, stdout, stderr);
				};
			}
		}

		if (repository.isVersionInstalled(library, id)) {
			log('You already have $library version ${vcs.directory} installed.');

			final wasUpdated = vcsBranchesByLibraryName.exists(library);
			// difference between a key not having a value and the value being null

			final currentBranch = vcsBranchesByLibraryName[library];

			// TODO check different urls as well
			if (branch != null && (!wasUpdated || currentBranch != branch)) {
				final currentBranchStr = currentBranch != null ? currentBranch : "<unspecified>";
				if (!confirm('Overwrite branch: "$currentBranchStr" with "$branch"')) {
					log('Library $library $id repository remains at "$currentBranchStr"');
					return;
				}
				FsUtils.deleteRec(libPath);
				doVcsClone();
			} else if (wasUpdated) {
				log('Library $library version ${vcs.directory} already up to date.');
				return;
			} else {
				log('Updating $library version ${vcs.directory}...');
				try {
					updateVcs(library, id, vcs);
				} catch (e:AlreadyUpToDate){
					log(e.toString());
				}
			}
		} else {
			doVcsClone();
		}

		vcsBranchesByLibraryName[library] = branch;
	}

	function updateVcs(library:ProjectName, id:VcsID, vcs:Vcs) {
		final dir = repository.getVersionPath(library, id);

		final oldCwd = Sys.getCwd();
		Sys.setCwd(dir);

		final success = try {
			vcs.update(
				function() {
					if (confirm('Reset changes to $library $id repository in order to update to latest version'))
						return true;
					log('$library repository has not been modified', Optional);
					return false;
				},
				log.bind(_, Debug),
				log.bind(_, Optional)
			);
		} catch (e:VcsError) {
			Sys.setCwd(oldCwd);
			switch e {
				case CommandFailed(vcs, code, stdout, stderr):
					throw new VcsCommandFailed(id, code, stdout, stderr);
				default: throw e; // other errors aren't expected here
			}
		}
		Sys.setCwd(oldCwd);
		if (!success)
			throw new AlreadyUpToDate('Library $library $id repository is already up to date');
		log('$library was updated');
	}
}
