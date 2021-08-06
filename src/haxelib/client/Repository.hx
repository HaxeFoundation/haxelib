package haxelib.client;

import sys.FileSystem;
import sys.io.File;

import haxelib.Data;
import haxelib.client.RepoManager;
import haxelib.client.LibraryData;

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
	var path(get, null):String;

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

	inline function getCurrentFilePath(name:ProjectName):String {
		return addToRepoPath(Data.safe(name), CURRENT);
	}

	inline function getCurrentFileContent(name:ProjectName):String {
		return try
				File.getContent(getCurrentFilePath(name)).trim()
			catch(e:haxe.Exception)
				throw new CurrentVersionException('No current version set for library \'$name\'');
	}

	inline function getProjectRootPath(name:ProjectName):String {
		return addToRepoPath(Data.safe(name)).addTrailingSlash();
	}

	inline function getProjectVersionPath(name:ProjectName, version:Version):String {
		final versionDir:String = try {
			Vcs.getDirectoryFor(Vcs.VcsID.ofString(version));
		} catch (_) {
			if (!SemVer.isValid(version)) throw 'Unknown library version $version';
			version;
		}
		return addToRepoPath(Data.safe(name), Data.safe(versionDir)).addTrailingSlash();
	}

	inline function addToRepoPath(name:String, ?sub:String):String {
		return Path.join([
			path,
			name,
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
		Returns the development path for `name`.
		If no development path is set, or it is filtered out,
		returns null.
	**/
	public function getDevPath(name:ProjectName):Null<String> {
		final devFile = getDevFilePath(name);
		if (!FileSystem.exists(devFile))
			return null;

		final path = {
			final path = File.getContent(devFile).trim();
			// windows environment variables
			~/%([A-Za-z0-9_]+)%/g.map(path, function(r) {
				final env = Sys.getEnv(r.matched(1));
				return env == null ? "" : env;
			});
		}

		if (isDevPathExcluded(path))
			return null;

		return path;
	}

	static function isDevPathExcluded(path:String):Bool {
		final filters = switch (Sys.getEnv("HAXELIB_DEV_FILTER")) {
			case null: // no filters set
				return false;
			case filterStr:
				filterStr.split(";");
		}

		function normalize(path:String)
			return Path.normalize(path).toLowerCase();
		// check that `path` does not start with any of the filtered paths
		return !filters.exists(function(flt) return normalize(path).startsWith(normalize(flt)));
	}

	function getDevFilePath(name:String):String {
		return addToRepoPath(Data.safe(name), DEV);
	}
}
