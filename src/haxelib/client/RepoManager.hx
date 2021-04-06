package haxelib.client;

import sys.FileSystem;
import sys.io.File;

import haxelib.client.FsUtils.*;

using StringTools;
using haxe.io.Path;

class RepoException extends haxe.Exception {}

enum InvalidConfigurationType {
	NoneSet;
	NotFound(path:String);
	IsFile(path:String);
}

class InvalidConfiguration extends RepoException {
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

class RepoManager {
	static final REPO_DIR = "lib";
	static final LOCAL_REPO_DIR = ".haxelib";

	static final CONFIG_FILE = ".haxelib";
	static final UNIX_SYSTEM_CONFIG_FILE = "/etc/.haxelib";

	static final VARIABLE_NAME = "HAXELIB_PATH";

	public static function getPath(?dir:String):String {
		final dir = getDirectory(dir);

		final localPath = getLocalPath(dir);
		if (localPath != null)
			return localPath;

		return getValidGlobalPath();
	}

	static function getLocalPath(dir:String):Null<String> {
		if (dir == "")
			return null;
		final repo = Path.join([dir, LOCAL_REPO_DIR]);
		if (FileSystem.exists(repo) && FileSystem.isDirectory(repo))
			return FileSystem.fullPath(repo).addTrailingSlash();
		return getLocalPath(dir.directory());
	}

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
			return defaultPath;
		}
		if (!FileSystem.exists(rep))
			throw new InvalidConfiguration(NotFound(rep));
		else if (!FileSystem.isDirectory(rep))
			throw new InvalidConfiguration(IsFile(rep));
		return rep;
	}

	public static function setGlobalPath(path:String):Void {
		path = FileSystem.absolutePath(path);
		final configFile = getConfigFilePath();

		if (isSamePath(path, configFile))
			throw new RepoException('Cannot use $path because it is reserved for config file');

		safeDir(path);
		File.saveContent(configFile, path);
	}

	public static function unsetGlobalPath():Void {
		final configFile = getConfigFilePath();
		FileSystem.deleteFile(configFile);
	}

	public static function suggestGlobalPath() {
		final configured = readConfiguredGlobalPath();
		if (configured != null)
			return configured;

		return getDefaultGlobalPath();
	}

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

	public static function createLocal(?dir:String) {
		if (! (dir == null || FileSystem.exists(dir)))
			FsUtils.safeDir(dir);
		final dir = getDirectory(dir);
		final path = FileSystem.absolutePath(Path.join([dir, LOCAL_REPO_DIR]));
		final created = FsUtils.safeDir(path, true);
		if(!created)
			throw new RepoException('Local repository already exists ($path)');
	}

	public static function deleteLocal(?dir:String) {
		final dir = getDirectory(dir);
		final path = FileSystem.absolutePath(Path.join([dir, LOCAL_REPO_DIR]));
		final deleted = FsUtils.deleteRec(path);
		if (!deleted)
			throw new RepoException('No local repository found ($path)');
	}

	static function getConfigFilePath():String {
		return Path.join([getHomePath(), CONFIG_FILE]);
	}

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
