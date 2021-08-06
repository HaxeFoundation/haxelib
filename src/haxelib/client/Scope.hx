package haxelib.client;

import haxelib.Data;

import haxelib.client.LibraryData;
import haxelib.client.ScriptRunner;
using StringTools;

/** Returns scope for directory `dir`. If `dir` is omitted, uses the current
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

/** Returns the global scope.
**/
function getGlobalScope(?dir:String):GlobalScope {
	@:privateAccess
	return new GlobalScope(Repository.get(dir));
}

/** Returns scope created for directory `dir`, resolving libraries to `repository`

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
	public final isLocal:Bool;
	final repository:Repository;
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

	public abstract function getPath(library:ProjectName, ?version:Version):String;

	public abstract function getArgsAsHxml(library:ProjectName, ?version:Version):String;

	public abstract function getArgsAsHxmlForLibraries(libraries:Array<{library:ProjectName, version:Null<Version>}>):String;

	abstract function resolveCompiler():LibraryData;

	// TODO: placeholders until https://github.com/HaxeFoundation/haxe/wiki/Haxe-haxec-haxelib-plan
	static function loadOverrides():LockFormat {
		return {};
	}

}
