package haxelib.api;

import sys.FileSystem;
import sys.io.File;

import haxelib.VersionData.VcsID;
import haxelib.api.RepoManager;
import haxelib.api.LibraryData;

using Lambda;
using StringTools;
using haxe.io.Path;

/**
	Exception thrown when there is an error with the configured
	current version of a library.
 **/
class CurrentVersionException extends haxe.Exception {}

/**
	Instance of a repository which can be used to get information on
	library versions installed in the repository, as well as
	directly modifying them.
 **/
class Repository {
	/** Name of file used to keep track of current version. **/
	static final CURRENT_FILE = ".current";

	/** Name of file used to keep track of capitalization. **/
	static final NAME_FILE = ".name";

	/**
		The path to the repository.

		If this field is being accessed and the repository path
		is missing, an exception is thrown.
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
			return !name.contains(filter);
		}

		final projects = [];

		for (dir in FileSystem.readDirectory(path)) {
			// hidden, not a folder, or has upper case letters
			if (dir.startsWith(".") || dir.toLowerCase() != dir || !FileSystem.isDirectory(Path.join([path, dir])))
				continue;

			final allLower = try ProjectName.ofString(Data.unsafe(dir)) catch (_) continue;
			final libraryName = getCapitalization(allLower);

			if (!isFilteredOut(allLower))
				projects.push(libraryName);
		}
		return projects;
	}

	/** Returns information on currently installed versions for project `name` **/
	public function getProjectInstallationInfo(name:ProjectName):{versions: Array<Version>, devPath:String} {
		final semVers:Array<SemVer> = [];
		final others:Array<VcsID> = [];
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
				if (VcsID.isValid(version))
					others.push(VcsID.ofString(version));
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

	/**
		Removes the project `name` from the repository.
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

		`name` may also be used as the official version of the library name
		if installing a proper semver release
	 **/
	public function setCurrentVersion(name:ProjectName, version:Version):Void {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw 'Library $name is not installed';

		if (!FileSystem.exists(getProjectVersionPath(name, version)))
			throw 'Library $name version $version is not installed';

		final currentFilePath = getCurrentFilePath(name);
		final isNewLibrary = !FileSystem.exists(currentFilePath);

		File.saveContent(currentFilePath, version);

		// if the library is being installed for the first time, or this is a proper version
		// or it is a git/hg/dev version but there are no proper versions installed
		// proper semver releases replace names given by git/hg/dev versions
		if (isNewLibrary || SemVer.isValid(version) || !doesLibraryHaveOfficialVersion(name))
			setCapitalization(name);
	}

	/**
		Returns the current version of project `name`.
	**/
	public function getCurrentVersion(name:ProjectName):Version {
		if (!FileSystem.exists(getProjectRootPath(name)))
			throw new CurrentVersionException('Library $name is not installed');

		final content = getCurrentFileContent(name);
		// return try
		// 		Version.ofString(content)
		// 	catch (e:LibraryDataException)
		// 		throw new CurrentVersionException('Current set version of $name is invalid.');
		return @:privateAccess Version.ofStringUnsafe(content);
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

	/**
		Returns the correctly capitalized name for library `name`.

		`name` can be any possible capitalization variation of the library name.
	**/
	public function getCorrectName(name:ProjectName):ProjectName {
		final rootPath = getProjectRootPath(name);
		if (!FileSystem.exists(rootPath))
			throw 'Library $name is not installed';

		return getCapitalization(name);
	}

	static inline function doesNameHaveCapitals(name:ProjectName):Bool {
		return name != name.toLowerCase();
	}

	function setCapitalization(name:ProjectName):Void {
		// if it is not all lowercase then we save the actual capitalisation in the `.name` file
		final filePath = addToRepoPath(name, NAME_FILE);

		if (doesNameHaveCapitals(name)) {
			File.saveContent(filePath, name);
			return;
		}

		if (FileSystem.exists(filePath))
			FileSystem.deleteFile(filePath);
	}

	function getCapitalization(name:ProjectName):ProjectName {
		final filePath = addToRepoPath(name, NAME_FILE);
		if (!FileSystem.exists(filePath))
			return name.toLowerCase();

		final content = try {
			File.getContent(filePath);
		} catch (e) {
			throw 'Failed when checking the name for library \'$name\': $e';
		}

		return ProjectName.ofString(content.trim());
	}

	// returns whether or not `name` has any versions installed which are not dev/git/hg
	function doesLibraryHaveOfficialVersion(name:ProjectName):Bool {
		final root = getProjectRootPath(name);

		for (sub in FileSystem.readDirectory(root)) {
			// ignore .dev and .current files
			if (sub.startsWith("."))
				continue;

			final version = Data.unsafe(sub);
			if (SemVer.isValid(version))
				return true;
		}
		return false;
	}

	inline function getCurrentFilePath(name:ProjectName):String {
		return addToRepoPath(name, CURRENT_FILE);
	}

	inline function getCurrentFileContent(name:ProjectName):String {
		final currentFile = getCurrentFilePath(name);
		if (!FileSystem.exists(currentFile))
			throw new CurrentVersionException('No current version set for library \'$name\'');

		try
			return File.getContent(currentFile).trim()
		catch (e)
			throw new CurrentVersionException('Failed when reading the current version for library \'$name\': $e');
	}

	inline function getProjectRootPath(name:ProjectName):String {
		return addToRepoPath(name).addTrailingSlash();
	}

	inline function getProjectVersionPath(name:ProjectName, version:Version):String {
		final versionDir:String =
			switch version {
				case v if (SemVer.isValid(v)): v;
				case (try VcsID.ofString(_) catch(_) null) => vcs if (vcs != null):
					Vcs.getDirectoryFor(vcs);
				//case _: throw 'Unknown library version: $version'; // we shouldn't get here
				case custom: custom;
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

	static final DEV_FILE = ".dev";
	/**
		Sets the dev path for project `name` to `path`.
	**/
	public function setDevPath(name:ProjectName, path:String) {
		final root = getProjectRootPath(name);

		final isNew = !FileSystem.exists(root);

		FileSystem.createDirectory(root);

		if (isNew || !doesLibraryHaveOfficialVersion(name)) {
			setCapitalization(name);
		}

		final devFile = Path.join([root, DEV_FILE]);

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
		return addToRepoPath(name, DEV_FILE);
	}
}
