package haxelib.api;

import haxe.ds.Either;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import haxelib.ProjectName;
import haxelib.api.LibraryData;

using Lambda;
using StringTools;

/**
	Responsible for checking if a Repository requires reformatting
	as well as carrying out the reformatting.
**/
class RepoReformatter {
	/** To increment whenever the repository format changes. **/
	static final CURRENT_REPO_VERSION = 1;

	static final REPO_VERSION_FILE = ".repo-version";


	/**
		Returns true if the repository version is lower
		than the version supported by the current version of this library.
	**/
	public static function doesRepositoryRequireReformat(repo:Repository):Bool {
		return getRepositoryVersion(repo) < CURRENT_REPO_VERSION;
	}

	/**
		Returns true if the repository version is higher than
		the version supported by the current version of this library.
	**/
	public static function isRepositoryIncompatible(repo:Repository):Bool {
		return getRepositoryVersion(repo) > CURRENT_REPO_VERSION;
	}

	@:allow(haxelib.api.RepoManager)
	static function initRepoVersion(path:String):Void {
		setRepoVersion(path, CURRENT_REPO_VERSION);
	}

	static function setRepoVersion(path:String, version:Int):Void {
		File.saveContent(Path.join([path, REPO_VERSION_FILE]), Std.string(version) + "\n");
	}

	static function getRepositoryVersion(repo:Repository):Int {
		return try {
			Std.parseInt(File.getContent(Path.join([repo.path, REPO_VERSION_FILE])).trim());
		} catch (e) {
			0;
		}
	}

	/**
		Reformats `repo` to the current version supported by this
		version of the library.

		`log` can be passed in for logging information.

		If `repo`'s version is equal to the version supported, then it is
		treated as if we are updating from the first ever version.
		If `repo`'s version is greater than what is supported by
		this version of the library, an exception is thrown.
	**/
	public static function reformat(repo:Repository, ?log:(msg:String)-> Void):Void {
		if (log == null) log = (_)-> {};

		final version =
			switch getRepositoryVersion(repo) {
				case version if (version < CURRENT_REPO_VERSION):
					version;
				case version if (version == CURRENT_REPO_VERSION):
					0;
				case version:
					throw 'Repository has version $version, but this library only supports up to $CURRENT_REPO_VERSION.\n' +
						'Reformatting cannot be done.';
			}

		for (v => update in updaterFunctions.slice(version)){
			log('Updating from version $v to ${v+1}');
			update(repo, log);
			setRepoVersion(repo.path, v + 1);
		}
		log('Repository is now at version: $CURRENT_REPO_VERSION');
	}

	// updater functions should check for issues before making any changes.
	static final updaterFunctions = [
		updateFrom0
	];

	/** Updates from version 0 to 1. **/
	static function updateFrom0(repo:Repository, log:(msg:String)->Void) {
		final path = repo.path;

		final filteredItems = [];

		// map of new paths and the old paths that will be moved to them
		final newPaths:Map<String, Either<String, Array<String>>> = [];

		if (!FsUtils.IS_WINDOWS) log("Checking for conflicts");

		for (subDir in FileSystem.readDirectory(path)) {
			final oldPath = Path.join([path, subDir]);
			final lowerCaseVersion = subDir.toLowerCase();
			if (subDir.startsWith(".") || !FileSystem.isDirectory(oldPath) || lowerCaseVersion == subDir)
				continue;

			filteredItems.push(subDir);

			if (FsUtils.IS_WINDOWS) continue;
			final newPath = Path.join([repo.path, lowerCaseVersion]);
			switch newPaths[newPath] {
				case null if (!FileSystem.exists(newPath)):
					newPaths[newPath] = Left(oldPath);
				case null:
					newPaths[newPath] = Right([newPath, oldPath]);
				case Left(single):
					newPaths[newPath] = Right([single, oldPath]);
				case Right(arr):
					arr.push(oldPath);
			}
		}

		// look for potential conflicts
		for (_ => item in newPaths) {
			final items = switch item {
				case Left(_): continue; // only one folder, so there are no conflicts
				case Right(arr): arr;
			}

			final pathByItem:Map<String, String> = [];

			for (oldPath in items) {
				for (subDir in FileSystem.readDirectory(oldPath)) {
					final lower = subDir.toLowerCase();
					final existing = pathByItem[lower];
					final fullPath = Path.join([oldPath, subDir]);

					if (existing == null) { // no conflict
						pathByItem[lower] = fullPath;
						continue;
					}
					// conflict!!!
					final message = switch (lower) {
						case ".name":
							continue;
						case ".dev":
							'There are two conflicting dev versions set:';
						case ".current":
							'There are two conflicting current versions set:';
						case other if (Version.isValid(Data.unsafe(other))):
							'There are two conflicting versions in:';
						case _:
							'There are two conflicting unrecognized files/folders:';
					};
					throw '$message\n`$existing` and `$fullPath`\nPlease remove one manually and retry.';
				}
			}
		}

		if (!FsUtils.IS_WINDOWS)
			filteredItems.sort(Reflect.compare);

		for (subDir in filteredItems) {
			final fullPath = Path.join([repo.path, subDir]);
			final subDirLower = subDir.toLowerCase();
			final newPath = Path.join([repo.path, subDirLower]);

			try {
				log('Moving `$fullPath` to `$newPath`');
				FileSystem.rename(fullPath, newPath);
			} catch(_){
				for (subItem in FileSystem.readDirectory(fullPath)) {
					final itemPath = '$fullPath/$subItem';
					final newItemPath = '$newPath/$subItem';
					if (FileSystem.exists(newItemPath)){
						FileSystem.deleteFile(itemPath);
						continue; // must have been cleared
					}
					log('Moving `$itemPath` to `$newItemPath`');
					FileSystem.rename(itemPath, newItemPath);
				}
				log('Deleting `$fullPath`');
				FileSystem.deleteDirectory(fullPath);
			}

			final library = ProjectName.ofString(Data.unsafe(subDir));
			final nameFile = Path.join([newPath, @:privateAccess Repository.NAME_FILE]);

			if (!FileSystem.exists(nameFile)) {
				log('Setting name for `$library`');
				File.saveContent(nameFile, subDir);
			}
		}
	}
}
