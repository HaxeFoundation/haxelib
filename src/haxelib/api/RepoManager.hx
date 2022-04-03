package haxelib.api;

import sys.FileSystem;
import sys.io.File;

import haxelib.api.FsUtils.*;

using StringTools;
using haxe.io.Path;

#if (haxe_ver < 4.1)
#error "RepoManager requires Haxe 4.1 or newer"
#end

/** Exception thrown when an error happens when
	changing or retrieving a repository path.
 **/
class RepoException extends haxe.Exception {}

/** Enum representing the different possible causes
	for a misconfigured global repository.
 **/
enum InvalidConfigurationType {
	/** There is no configuration set **/
	NoneSet;
	/** The configured folder does not exist **/
	NotFound(path:String);
	/** The configuration points to a file instead of a directory **/
	IsFile(path:String);
}

/** Exception thrown when a global repository has been misconfigured.
**/
class InvalidConfiguration extends RepoException {
	/** The type of configuration error. **/
	public final type:InvalidConfigurationType;
	public function new(type:InvalidConfigurationType) {
		final message = switch type {
			case NoneSet: "No global repository has been configured";
			case NotFound(path): 'Haxelib repository $path does not exist';
			case IsFile(path): 'Haxelib repository $path exists, but is a file, not a directory';
		}
		super(message);
		this.type = type;
	}
}

/** Manager for the location of the haxelib database. **/
class RepoManager {
	static final REPO_DIR = "lib";
	static final LOCAL_REPO_DIR = ".haxelib";

	static final CONFIG_FILE = ".haxelib";
	static final UNIX_SYSTEM_CONFIG_FILE = "/etc/.haxelib";

	static final VARIABLE_NAME = "HAXELIB_PATH";

	/**
		Returns the path to the repository local to `dir` if one exists,
		otherwise returns global repository path.

		If `dir` is omitted, the current working directory is used instead.
	**/
	public static function getPath(?dir:String):String {
		final dir = getDirectory(dir);

		final localPath = getLocalPath(dir);
		if (localPath != null)
			return localPath;

		return getValidGlobalPath();
	}

	/**
		Searches for the path to local repository, starting in `dir`
		and then going up until root directory is reached.

		Returns the directory path if it is found, otherwise returns null.
	**/
	static function getLocalPath(dir:String):Null<String> {
		if (dir == "")
			return null;
		final repo = Path.join([dir, LOCAL_REPO_DIR]);
		if (FileSystem.exists(repo) && FileSystem.isDirectory(repo))
			return FileSystem.fullPath(repo).addTrailingSlash();
		return getLocalPath(dir.directory());
	}

	/**
		Returns the global repository path, but throws an exception
		if it does not exist or if it is not a directory.

		The `HAXELIB_PATH` environment variable takes precedence over
		the configured global repository path.
	**/
	public static function getGlobalPath():String {
		return getValidGlobalPath();
	}

	static function getValidGlobalPath():String {
		final rep = readConfiguredGlobalPath();
		if (rep == null) {
			if (!IS_WINDOWS)
				throw new InvalidConfiguration(NoneSet);
			// on Windows, we use the default one if none is set
			final defaultPath = getDefaultGlobalPath();
			try
				safeDir(defaultPath)
			catch (e:Dynamic)
				throw new RepoException('Error accessing Haxelib repository: $e');
			// configure the default as the global repository
			File.saveContent(getConfigFilePath(), defaultPath);
			initRepository(defaultPath);
			return defaultPath;
		}
		if (!FileSystem.exists(rep))
			throw new InvalidConfiguration(NotFound(rep));
		else if (!FileSystem.isDirectory(rep))
			throw new InvalidConfiguration(IsFile(rep));

		if (isRepositoryUninitialized(rep))
			initRepository(rep);

		return rep;
	}

	/**
		Sets `path` as the global haxelib repository in the user's haxelib config file.

		If `path` does not exist already, it is created.
	 **/
	public static function setGlobalPath(path:String):Void {
		path = FileSystem.absolutePath(path);
		final configFile = getConfigFilePath();

		if (isSamePath(path, configFile))
			throw new RepoException('Cannot use $path because it is reserved for config file');

		final isNew = safeDir(path);
		if (isNew || FileSystem.readDirectory(path).length == 0) // if we created the path or if it is empty
			initRepository(path);

		File.saveContent(configFile, path);
	}

	/**
		Deletes the user's current haxelib setup,
		resetting their global repository path.
	**/
	public static function unsetGlobalPath():Void {
		final configFile = getConfigFilePath();
		FileSystem.deleteFile(configFile);
	}

	/**
		Returns the previous global repository path if a valid one had been
		set up, otherwise returns the default path for the current operating
		system.
	**/
	public static function suggestGlobalPath() {
		final configured = readConfiguredGlobalPath();
		if (configured != null)
			return configured;

		return getDefaultGlobalPath();
	}

	/**
		Returns the global Haxelib repository path, without validating
		that it exists. If it is not configured anywhere, returns `null`.

		First checks `HAXELIB_PATH` environment variable,
		then checks the content of user config file.

		On Unix-like systems also checks `/etc/.haxelib` for system wide
		configuration.
	 **/
	static function readConfiguredGlobalPath():Null<String> {
		// first check the env var
		final environmentVar = Sys.getEnv(VARIABLE_NAME);
		if (environmentVar != null)
			return environmentVar.trim().addTrailingSlash();

		// try to read from user config
		try {
			return getTrimmedContent(getConfigFilePath()).addTrailingSlash();
		} catch (_) {
			// the code below could go in here instead, but that
			// results in extra nesting...
		}

		if (!IS_WINDOWS) {
			// on unixes, try to read system-wide config
			/* TODO the system wide config has never been configured in haxelib code.
				Either configure it somewhere or remove this bit of code? */
			try {
				return getTrimmedContent(UNIX_SYSTEM_CONFIG_FILE).addTrailingSlash();
			} catch (_) {}
		}
		return null;
	}

	/**
		Creates a new local repository in the directory `dir` if one doesn't already exist.

		If `dir` is ommited, the current working directory is used.

		Throws RepoException if repository already exists.
	**/
	public static function createLocal(?dir:String) {
		if (! (dir == null || FileSystem.exists(dir)))
			FsUtils.safeDir(dir);
		final dir = getDirectory(dir);
		final path = FileSystem.absolutePath(Path.join([dir, LOCAL_REPO_DIR]));
		final created = FsUtils.safeDir(path, true);
		if(!created)
			throw new RepoException('Local repository already exists ($path)');
		initRepository(path);
	}

	/**
		Deletes the local repository in the directory `dir`, if it exists.

		If `dir` is ommited, the current working directory is used.

		Throws RepoException if no repository is found.
	**/
	public static function deleteLocal(?dir:String) {
		final dir = getDirectory(dir);
		final path = FileSystem.absolutePath(Path.join([dir, LOCAL_REPO_DIR]));
		final deleted = FsUtils.deleteRec(path);
		if (!deleted)
			throw new RepoException('No local repository found ($path)');
	}

	static function isRepositoryUninitialized(path:String) {
		return FileSystem.readDirectory(path).length == 0;
	}

	static function initRepository(path:String) {
		RepoReformatter.initRepoVersion(path);
	}

	static function getConfigFilePath():String {
		return Path.join([getHomePath(), CONFIG_FILE]);
	}

	/** Returns the default path for the global directory. **/
	static function getDefaultGlobalPath():String {
		if (IS_WINDOWS)
			return getWindowsDefaultGlobalPath();

		// TODO `lib/` is for binaries, see if we can move all of these to `share/`
		return if (FileSystem.exists("/usr/share/haxe/")) // for Debian
			'/usr/share/haxe/$REPO_DIR/'
		else if (Sys.systemName() == "Mac") // for newer OSX, where /usr/lib is not writable
			'/usr/local/lib/haxe/$REPO_DIR/'
		else '/usr/lib/haxe/$REPO_DIR/'; // for other unixes
	}

	/**
		The Windows haxe installer will setup `%HAXEPATH%`.
		We will default haxelib repo to `%HAXEPATH%/lib.`

		When there is no `%HAXEPATH%`, we will use a `/haxelib`
		directory next to the config file, ".haxelib".
	**/
	static function getWindowsDefaultGlobalPath():String {
		final haxepath = Sys.getEnv("HAXEPATH");
		if (haxepath != null)
			return Path.join([haxepath.trim(), REPO_DIR]).addTrailingSlash();
		return Path.join([getConfigFilePath().directory(), "haxelib"]).addTrailingSlash();
	}

	static function getTrimmedContent(filePath:String):String {
		return File.getContent(filePath).trim();
	}

	static function getDirectory(dir:Null<String>):String {
		if (dir == null)
			return Sys.getCwd();
		return Path.addTrailingSlash(
			try {
				FileSystem.fullPath(dir);
			} catch (e) {
				throw '$dir does not exist';
			}
		);
	}
}
