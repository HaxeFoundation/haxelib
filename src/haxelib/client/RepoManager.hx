package haxelib.client;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import haxelib.client.FsUtils.*;

using StringTools;

#if (haxe_ver < 4.1)
#error "RepoManager requires Haxe 4.1 or newer"
#end

class RepoException extends haxe.Exception {}

/** Manager for the location of the haxelib database. **/
class RepoManager {
	static final REPONAME = "lib";
	static final REPODIR = ".haxelib";

	static final VARIABLE_NAME = "HAXELIB_PATH";

	static final UNIX_SYSTEM_CONFIG = "/etc/.haxelib";

	/**
		Returns the path to the repository local to `dir` if one exists,
		otherwise returns global repository path.
	**/
	public static function findRepository(dir:String) {
		return switch getLocalRepository(dir) {
			case null: getGlobalRepository();
			case repo: Path.addTrailingSlash(FileSystem.fullPath(repo));
		}
	}

	/**
		Searches for the path to local repository, starting in `dir`
		and then going up until root directory is reached.

		Returns the directory path if it is found, else returns null.
	**/
	static function getLocalRepository(dir:String):Null<String> {
		var dir = FileSystem.absolutePath(dir);
		while (dir != "") {
			final repo = Path.join([dir, REPODIR]);
			if (FileSystem.exists(repo) && FileSystem.isDirectory(repo))
				return repo;
			dir = Path.directory(dir);
		}
		return null;
	}

	/**
		Returns the global repository path, but throws an exception
		if it does not exist or if it is not a directory.

		The `HAXELIB_PATH` environment variable takes precedence over
		the configured global repository path.
	**/
	public static function getGlobalRepository():String {
		final rep = getGlobalRepositoryPath(true);
		// TODO: Move the "run `haxelib setup`" part of the messages out of here
		if (!FileSystem.exists(rep))
			throw new RepoException('Haxelib Repository $rep does not exist. Please run `haxelib setup` again.');
		else if (!FileSystem.isDirectory(rep))
			throw new RepoException('Haxelib Repository $rep exists, but is a file, not a directory. Please remove it and run `haxelib setup` again.');
		return Path.addTrailingSlash(rep);
	}

	/**
		Sets `path` as the global haxelib repository in the user's haxelib config file.

		If `path` does not exist already, it is created.
	 **/
	public static function saveSetup(path:String):Void {
		final configFile = getConfigFilePath();

		path = FileSystem.absolutePath(path);

		if (isSamePath(path, configFile))
			throw new RepoException('Cannot use $path because it is reserved for config file');

		safeDir(path);
		File.saveContent(configFile, path);
	}

	/**
		Deletes the user's current haxelib setup,
		resetting their global directory path.
	**/
	public static function clearSetup():Void {
		final configFile = getConfigFilePath();
		FileSystem.deleteFile(configFile);
	}

	/**
		Returns the previous global repository path if a valid one had been
		properly set up, otherwise returns the default path for the
		current operating system.
	**/
	public static function suggestGlobalRepositoryPath() {
		return try
			RepoManager.getGlobalRepositoryPath()
		catch (_:RepoException)
			RepoManager.getSuggestedGlobalRepositoryPath();
	}

	/**
		Returns the global Haxelib repository path, without validating
		that it exists.

		First checks `HAXELIB_PATH` environment variable,
		then checks the content of user config file.

		If both are empty:
		- On Unix-like systems, checks `/etc/.haxelib` for system wide configuration,
		and throws an exception if this has not been set.
		- On Windows, returns the default suggested repository path, after
		attempting to create this directory if `create` is set to true.
	 **/
	static function getGlobalRepositoryPath(create = false):String {
		// first check the env var
		final environmentVar = Sys.getEnv(VARIABLE_NAME);
		if (environmentVar != null)
			return environmentVar.trim();

		// try to read from user config
		final userConfig = try File.getContent(getConfigFilePath()).trim() catch (_:Dynamic) null;
		if (userConfig != null)
			return userConfig;

		if (IS_WINDOWS) {
			// on windows, try to use haxe installation path
			final defaultPath = getWindowsDefaultGlobalRepositoryPath();
			if (create)
				try
					safeDir(defaultPath)
				catch (e:Dynamic)
					throw new RepoException('Error accessing Haxelib repository: $e');
			return defaultPath;
		}

		// on unixes, try to read system-wide config
		final systemConfig =
			try
				File.getContent(UNIX_SYSTEM_CONFIG).trim()
			catch (e:haxe.Exception)
				throw new RepoException("This is the first time you are running haxelib. Please run `haxelib setup` first");
		// TODO: Move the "run `haxelib setup`" part of the messages out of here
		return systemConfig;
	}

	/**
		Creates a new local repository in the directory `dir` if one doesn't already exist.

		Returns its full path if successful.

		Throws RepoException if repository already exists.
	**/
	public static function newRepo(dir:String):String {
		final path = FileSystem.absolutePath(Path.join([dir, REPODIR]));
		final created = FsUtils.safeDir(path, true);
		if(!created)
			throw new RepoException('Local repository already exists ($path)');
		return path;
	}

	/**
		Deletes the local repository in the directory `dir`, if it exists.

		Returns the full path of the deleted repository if successful.

		Throws RepoException if no repository found.
	**/
	public static function deleteRepo(dir:String):String {
		final path = FileSystem.absolutePath(Path.join([dir, REPODIR]));
		final deleted = FsUtils.deleteRec(path);
		if (!deleted)
			throw new RepoException('No local repository found ($path)');
		return path;
	}

	static function getConfigFilePath():String {
		return Path.join([getHomePath(), ".haxelib"]);
	}

	/** Returns the default path for the global directory. **/
	static function getSuggestedGlobalRepositoryPath():String {
		if (IS_WINDOWS)
			return getWindowsDefaultGlobalRepositoryPath();

		return if (FileSystem.exists("/usr/share/haxe")) // for Debian
			'/usr/share/haxe/$REPONAME'
		else if (Sys.systemName() == "Mac") // for newer OSX, where /usr/lib is not writable
			'/usr/local/lib/haxe/$REPONAME'
		else '/usr/lib/haxe/$REPONAME'; // for other unixes
	}

	/**
		The Windows haxe installer will setup `%HAXEPATH%`.
		We will default haxelib repo to `%HAXEPATH%/lib.`

		When there is no `%HAXEPATH%`, we will use a `/haxelib`
		directory next to the config file, ".haxelib".
	**/
	static function getWindowsDefaultGlobalRepositoryPath():String {
		final haxepath = Sys.getEnv("HAXEPATH");
		if (haxepath != null)
			return Path.join([haxepath.trim(), REPONAME]);
		return Path.join([Path.directory(getConfigFilePath()), "haxelib"]);
	}

}
