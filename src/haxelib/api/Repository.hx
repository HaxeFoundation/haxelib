package haxelib.api;

import sys.FileSystem;
import sys.io.File;

import haxelib.Data;
import haxelib.api.RepoManager;
import haxelib.api.LibraryData;

using Lambda;
using StringTools;
using haxe.io.Path;

class CurrentVersionException extends haxe.Exception {}

class Repository {
	static final CURRENT = ".current";

	/**
		Returns the path to the repository.
		Throws an exception if it has been deleted.
	**/
	public var path(get, null):String;

	function get_path() {
		if (!FileSystem.exists(path))
			throw new RepoException('Repository at $path no longer exists.');
		return path;
	}

	function new(path:String) {
		this.path = path;
	}
	/**
		Returns a Repository instance for the local repository
		if one is found, otherwise for the global one.

		If `dir` is omitted, the current working directory is used instead.
	**/
	public static function get(?dir:String):Repository {
		return new Repository(RepoManager.getPath(dir));
	}

	/**
		Returns a Repository instance for the global repository.
	**/
	public static function getGlobal():Repository {
		return new Repository(RepoManager.getGlobalPath());
	}

	/**
		Returns an array of installed project names.

		If `filter` is given, ignores projects that do not
		contain it as a substring.
	**/
	public function getLibraryNames(filter:String = null):Array<ProjectName> {
		if (filter != null)
			filter = filter.toLowerCase();

		inline function isFilteredOut(name:String) {
			if (filter == null)
				return false;
			return !name.toLowerCase().contains(filter);
		}

		final projects = [];
		var libraryName:ProjectName;

		for (dir in FileSystem.readDirectory(path)) {
			// hidden or not a folder
			if (dir.startsWith(".") || !FileSystem.isDirectory(Path.join([path, dir])))
				continue;

			libraryName = try ProjectName.ofString(Data.unsafe(dir)) catch (_:haxe.Exception) continue;

			if (!isFilteredOut(libraryName))
				projects.push(libraryName);
		}
		return projects;
	}

	/** Returns information on currently installed versions for project `name` **/
	public function getProjectInstallationInfo(name:ProjectName):{versions: Array<Version>, devPath:String} {
		final semVers:Array<SemVer> = [];
		final others:Array<Vcs.VcsID> = [];
		final root = getProjectRootPath(name);

		for (sub in FileSystem.readDirectory(root)) {
			// ignore .dev and .current files
			if (sub.startsWith("."))
				continue;

			final version = Data.unsafe(sub);
			try {
				final semVer = SemVer.ofString(version);
				semVers.push(semVer);
			} catch(e:haxe.Exception) {
				if (Vcs.VcsID.isVcs(version))
					others.push(Vcs.VcsID.ofString(version));
			}
		}
		if (semVers.length != 0)
			semVers.sort(SemVer.compare);

		final versions = (semVers:Array<Version>).concat(others);

		return {
			versions: versions,
			devPath: getDevPath(name)
		};
	}

	/** Returns whether project `name` is installed **/
	public function isInstalled(name:ProjectName):Bool {
		return FileSystem.exists(getProjectRootPath(name));
	}

	/** Returns whether `version` of project `name` is installed **/
	public function isVersionInstalled(name:ProjectName, version:Version):Bool {
		return FileSystem.exists(getProjectVersionPath(name, version));
	}

	/** Removes the project `name` from the repository.
		Throws an error if `name` is not installed.
	 **/
	public function removeProject(name:ProjectName) {
		final path = getProjectRootPath(name);

		if (!FileSystem.exists(path))
			throw 'Library $name is not installed';

		FsUtils.deleteRec(path);
	}

	/**
		Removes `version` of project `name`.

		Throws an exception if:
		- `name` or `version` is not installed
		- `version` matches the current version
		- the project's development path is set as the path of `version`
		- the project's development path is set to a subdirectory of it.
	**/
	public function removeProjectVersion(name:ProjectName, version:Version) {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw 'Library $name is not installed';

		final versionPath = getProjectVersionPath(name, version);
		if (!FileSystem.exists(versionPath))
			throw 'Library $name version $version is not installed';

		final current = getCurrentFileContent(name);
		if (current == version)
			throw 'Cannot remove current version of library $name';

		try {
			confirmRemovalAgainstDev(name, versionPath);
		} catch (e) {
			throw 'Cannot remove library `$name` version `$version`: $e\n'
			+ 'Use `haxelib dev $name` to unset the dev path';
		}

		FsUtils.deleteRec(versionPath);
	}

	/** Throws an error if removing `versionPath` conflicts with the dev path of library `name` **/
	function confirmRemovalAgainstDev(name:ProjectName, versionPath:String) {
		final devFilePath = getDevFilePath(name);
		if (!FileSystem.exists(devFilePath))
			return;

		final devPath = filterAndNormalizeDevPath(File.getContent(devFilePath).trim());

		if (devPath.startsWith(versionPath))
			throw 'It holds the `dev` version of `$name`';
	}

	/**
		Set current version of project `name` to `version`.

		Throws an error if `name` or `version` of `name` is not installed.
	 **/
	public function setCurrentVersion(name:ProjectName, version:Version):Void {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw 'Library $name is not installed';

		if (!FileSystem.exists(getProjectVersionPath(name, version)))
			throw 'Library $name version $version is not installed';

		final currentFilePath = getCurrentFilePath(name);

		File.saveContent(currentFilePath, version);
	}

	/**
		Returns the current version of project `name`.
	**/
	public function getCurrentVersion(name:ProjectName):Version {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw new CurrentVersionException('Library $name is not installed');

		final content = getCurrentFileContent(name);
		return try
				Version.ofString(content)
			catch (e:LibraryDataException)
				throw new CurrentVersionException('Current set version of $name is invalid.');
	}

	/**
		Returns whether project `name` has a valid current version set.
	**/
	public function isCurrentVersionSet(name:ProjectName):Bool {
		if (!FileSystem.exists(getProjectRootPath(name)))
			return false;

		final content = try
			getCurrentFileContent(name)
		catch(_:CurrentVersionException)
			return false;

		return Version.isValid(content);
	}

	/**
		Returns the path for `version` of project `name`,
		throwing an error if the project or version is not installed.
	**/
	public function getValidVersionPath(name:ProjectName, version:Version):String {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw 'Library $name is not installed';

		final path = getProjectVersionPath(name, version);
		if (!FileSystem.exists(path))
			throw 'Library $name version $version is not installed';

		return path;
	}

	/**
		Returns the root path project `name`,
		without confirming that it is installed.
	**/
	public function getProjectPath(name:ProjectName):String {
		return getProjectRootPath(name);
	}

	/**
		Returns the path for `version` of project `name`,
		without confirming that the project or version are installed.
	**/
	public function getVersionPath(name:ProjectName, version:Version):String {
		return getProjectVersionPath(name, version);
	}

	inline function getCurrentFilePath(name:ProjectName):String {
		return addToRepoPath(name, CURRENT);
	}

	inline function getCurrentFileContent(name:ProjectName):String {
		return try
				File.getContent(getCurrentFilePath(name)).trim()
			catch(e:haxe.Exception)
				throw new CurrentVersionException('No current version set for library \'$name\'');
	}

	inline function getProjectRootPath(name:ProjectName):String {
		return addToRepoPath(name).addTrailingSlash();
	}

	inline function getProjectVersionPath(name:ProjectName, version:Version):String {
		final versionDir:String = try {
			Vcs.getDirectoryFor(Vcs.VcsID.ofString(version));
		} catch (_) {
			if (!SemVer.isValid(version)) throw 'Unknown library version $version';
			version;
		}
		return addToRepoPath(name, Data.safe(versionDir).toLowerCase()).addTrailingSlash();
	}

	inline function addToRepoPath(name:ProjectName, ?sub:String):String {
		return Path.join([
			path,
			Data.safe(name).toLowerCase(),
			if (sub != null)
				sub
			else
				""
		]);
	}

	// Not sure about these:
	// https://github.com/HaxeFoundation/haxe/wiki/Haxe-haxec-haxelib-plan#legacy-haxelib-features

	static final DEV = ".dev";
	/**
		Sets the dev path for project `name` to `path`.
	**/
	public function setDevPath(name:ProjectName, path:String) {
		final root = getProjectRootPath(name);

		if (!FileSystem.exists(root))
			FileSystem.createDirectory(root);

		final devFile = Path.join([root, DEV]);

		File.saveContent(devFile, normalizeDevPath(path));
	}

	/**
		Removes the development directory for `name`, if one was set.
	**/
	public function removeDevPath(name:ProjectName) {
		final devFile = getDevFilePath(name);
		if (FileSystem.exists(devFile))
			FileSystem.deleteFile(devFile);
	}

	/**
		Returns the development path for `name`.
		If no development path is set, or it is filtered out,
		returns null.
	**/
	public function getDevPath(name:ProjectName):Null<String> {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw 'Library $name is not installed';

		final devFile = getDevFilePath(name);
		if (!FileSystem.exists(devFile))
			return null;

		return filterAndNormalizeDevPath(File.getContent(devFile).trim());
	}

	function filterAndNormalizeDevPath(devPath:String):Null<String> {
		final path = normalizeDevPath(devPath);

		if (isDevPathExcluded(path))
			return null;

		return path;
	}

	static function normalizeDevPath(devPath:String):Null<String> {
		// windows environment variables
		final expanded = ~/%([A-Za-z0-9_]+)%/g.map(
			devPath,
			function(r) {
				final env = Sys.getEnv(r.matched(1));
				return env == null ? "" : env;
		});

		return Path.normalize(expanded).addTrailingSlash();
	}

	static function isDevPathExcluded(normalizedPath:String):Bool {
		final filters = switch (Sys.getEnv("HAXELIB_DEV_FILTER")) {
			case null: // no filters set
				return false;
			case filterStr:
				filterStr.split(";");
		}

		// check that `path` does not start with any of the filtered paths
		return !filters.exists(function(flt) {
			final normalizedFilter = Path.normalize(flt).toLowerCase();
			return normalizedPath.toLowerCase().startsWith(normalizedFilter);
		});
	}

	function getDevFilePath(name:ProjectName):String {
		return addToRepoPath(name, DEV);
	}
}
