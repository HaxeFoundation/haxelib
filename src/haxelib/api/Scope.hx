package haxelib.api;

import haxelib.VersionData;
import haxelib.api.LibraryData;
import haxelib.api.ScriptRunner;

using StringTools;

/** Information on the installed versions of a library. **/
typedef InstallationInfo = {
	final name:ProjectName;
	final versions:Array<String>;
	final current:String;
	final devPath:Null<String>;
}

/**
	Returns scope for directory `dir`. If `dir` is omitted, uses the current
	working directory.

	The scope will resolve libraries to the local repository if one exists,
	otherwise to the global one.
**/
function getScope(?dir:String):Scope {
	if (dir == null)
		dir = Sys.getCwd();
	@:privateAccess
	return new GlobalScope(Repository.get(dir));
}

/** Returns the global scope. **/
function getGlobalScope(?dir:String):GlobalScope {
	@:privateAccess
	return new GlobalScope(Repository.get(dir));
}

/**
	Returns scope created for directory `dir`, resolving libraries to `repository`

	If `dir` is omitted, uses the current working directory.
**/
function getScopeForRepository(repository:Repository, ?dir:String):Scope {
	if (dir == null)
		dir = Sys.getCwd();
	@:privateAccess
	return new GlobalScope(repository);
}

/**
	This is an abstract class which the GlobalScope (and later on LocalScope)
	inherits from.

	It is responsible for managing current library versions, resolving them,
	giving information on them, or running them.
**/
abstract class Scope {
	/** Whether the scope is local. **/
	public final isLocal:Bool;
	/** The repository which is used to resolve the scope's libraries. **/
	public final repository:Repository;
	final overrides:LockFormat;

	function new(isLocal:Bool, repository:Repository) {
		this.isLocal = isLocal;
		this.repository = repository;

		overrides = loadOverrides();
	}

	/**
		Runs the script for `library` with `callData`.

		If `version` is specified, that version will be used,
		or an error is thrown if that version isn't installed
		in the scope.

		Should the script return a non zero code, a ScriptError
		exception is thrown containing the error code.
	**/
	public abstract function runScript(library:ProjectName, ?callData:CallData, ?version:Version):Void;

	/** Returns the current version of `library`, ignoring overrides and dev directories. **/
	public abstract function getVersion(library:ProjectName):Version;

	/**
		Set `library` to `version`.

		Requires that the library is already installed.
	  **/
	public abstract function setVersion(library:ProjectName, version:SemVer):Void;
	/**
		Set `library` to `vcsVersion`, with `data`.

		If `data` is omitted or incomplete then the required data is obtained manually.

		Requires that the library is already installed.
	**/
	public abstract function setVcsVersion(library:ProjectName, vcsVersion:VcsID, ?data:VcsData):Void;

	/** Returns whether `library` is currently installed in this scope (ignoring overrides). **/
	public abstract function isLibraryInstalled(library:ProjectName):Bool;

	/** Returns whether `library` version is currently overridden. **/
	public abstract function isOverridden(library:ProjectName):Bool;

	/** Returns an array of the libraries in the scope. **/
	public abstract function getLibraryNames():Array<ProjectName>;

	/**
		Returns an array of installation information on libraries in the scope.

		If `filter` is given, ignores libraries that do not contain it as a substring.
	 **/
	public abstract function getArrayOfLibraryInfo(?filter:String):Array<InstallationInfo>;

	/** Returns the path to the source directory of `version` of `library`. **/
	public abstract function getPath(library:ProjectName, ?version:Version):String;

	/** Returns the required build arguments for `version` of `library` as an hxml string. **/
	public abstract function getArgsAsHxml(library:ProjectName, ?version:Version):String;

	/**
		Returns the required build arguments for each library version in `libraries`
		as one combined hxml string.
	**/
	public abstract function getArgsAsHxmlForLibraries(libraries:Array<{library:ProjectName, version:Null<Version>}>):String;

	abstract function resolveCompiler():LibraryData;

	// TODO: placeholders until https://github.com/HaxeFoundation/haxe/wiki/Haxe-haxec-haxelib-plan
	static function loadOverrides():LockFormat {
		return {};
	}

}
