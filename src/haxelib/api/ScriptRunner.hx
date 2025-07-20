package haxelib.api;

import sys.FileSystem;

import haxelib.Data.DependencyVersion;
import haxelib.api.LibraryData;

/** Contains data with which a library script is executed. **/
@:structInit
class CallData {
	/** Directory in which the script will start. Defaults to current working directory. **/
	public final dir = Sys.getCwd();
	/** Array of arguments to be passed on to the library call. **/
	public final args:Array<String> = [];
	/**
		Whether to pass `--haxelib-global` to the haxe compiler when running
		(only works with haxe 4.0.0 and above).
	**/
	public final useGlobalRepo:Bool = false;
}

@:noDoc
/** either the project `name` or `name:version` **/
abstract Dependency(String) from ProjectName to String {
	inline function new(d) this = d;
	public static function fromNameAndVersion(name:ProjectName, version:DependencyVersion):Dependency
		return new Dependency(switch cast(version, String) {
			case '': name;
			case version: '$name:$version';
		});
}

@:noDoc
typedef Dependencies = Array<Dependency>;

@:noDoc
/** Library data needed in order to run it **/
typedef LibraryRunData = {
	/** This may be an alias. **/
	final name:ProjectName;
	/** This is the actual name found in the `haxelib.json`. **/
	final internalName:ProjectName;
	final version:VersionOrDev;
	final dependencies:Dependencies;
	final main:Null<String>;
	final path:String;
}

private enum RunType {
	/** Runs compiled neko file **/
	Neko;
	/** Compiles and runs script using haxe's eval target **/
	Script(main:String, name:ProjectName, version:VersionOrDev, dependencies:Dependencies);
}

private typedef State = {
	final dir:String;
	final run:Null<String>;
	final runName:Null<String>;
}

/** Exception which is thrown if running a library script returns a non-zero code. **/
@:noDoc
class ScriptError extends haxe.Exception {
	/** The error code returned by the library script call. **/
	public final code:Int;
	public function new(name:ProjectName, code:Int) {
		super('Script for library "$name" exited with error code: $code');
		this.code = code;
	}
}

/** Class containing function for running a library's script. **/
@:noDoc
class ScriptRunner {
	static final HAXELIB_RUN = "HAXELIB_RUN";
	static final HAXELIB_RUN_NAME = "HAXELIB_RUN_NAME";
	static final RUN_HXB_CACHE = "run.hxb";
	static final RUN_NEKO_SCRIPT = "run.n";

	/**
		Run `library`, with `callData`.

		`getCompilerVersion` is used if it is an interpreted script.
	 **/
	public static function run(library:LibraryRunData, callData:CallData, getCompilerVersion:()->SemVer):Void {
		final type = getType(library);

		final cmd = getCmd(type);
		final args = generateArgs(library.path, type, callData, getCompilerVersion);

		final oldState = getState();

		// call setup
		setState({
			dir: library.path,
			run: "1",
			runName: library.internalName
		});

		final output = Sys.command(cmd, args);

		// return to previous state
		setState(oldState);

		if (output != 0)
			throw new ScriptError(library.name, output);
	}

	static function getType(library:LibraryRunData) {
		if (library.main != null)
			return Script(library.main, library.name, library.version, library.dependencies);
		if (FileSystem.exists(library.path + RUN_NEKO_SCRIPT))
			return Neko;
		if (FileSystem.exists(library.path + 'Run.hx'))
			return Script("Run", library.name, library.version, library.dependencies);
		throw 'Library ${library.name} version ${library.version} does not have a run script';
	}

	static function getCmd(runType:RunType):String {
		return switch runType {
			case Neko: "neko";
			case Script(_): "haxe";
		};
	}

	static function generateArgs(path:String, runType:RunType, callData:CallData, getCompilerVersion:() -> SemVer):Array<String> {
		switch runType {
			case Neko:
				final callArgs = callData.args.copy();
				callArgs.unshift(path + RUN_NEKO_SCRIPT);
				callArgs.push(callData.dir);
				return callArgs;
			case Script(main, name, version, dependencies):
				final compilerVersion = getCompilerVersion();
				final isHaxe4 = compilerVersion >= SemVer.ofString('4.0.0');
				final useCache = compilerVersion >= SemVer.ofString('5.0.0-preview.1');
				final useGlobalRepo = isHaxe4 && callData.useGlobalRepo;

				final callArgs = generateScriptArgs(main, name, version, dependencies, path, useGlobalRepo, useCache);
				for (arg in callData.args)
					callArgs.push(arg);
				callArgs.push(callData.dir);
				return callArgs;
		}
	}

	static function generateScriptArgs(main:String, name:ProjectName, version:VersionOrDev, dependencies:Dependencies, path:String, useGlobalRepo:Bool, useCache:Bool):Array<String> {
		final args = [];

		final cachePath = path + RUN_HXB_CACHE;

		if (useCache && FileSystem.exists(cachePath)) {
			args.push("--hxb-lib");
			args.push(cachePath);
		} else {
			function addLib(data:String):Void {
				args.push("--library");
				args.push(data);
			}
			if (useGlobalRepo)
				args.push('--haxelib-global');

			// add the project itself first
			addLib(if (version != Dev.Dev) '$name:$version' else '$name');

			for (d in dependencies)
				addLib(d);

			if (useCache) {
				args.push("--hxb");
				args.push(cachePath);
			}
		}

		args.push('--run');
		args.push(main);
		return args;
	}

	static function getState():State {
		return {
			dir: Sys.getCwd(),
			run: Sys.getEnv(HAXELIB_RUN),
			runName: Sys.getEnv(HAXELIB_RUN_NAME)
		};
	}

	static function setState(state:State):Void {
		Sys.setCwd(state.dir);
		putEnv(HAXELIB_RUN, state.run);
		putEnv(HAXELIB_RUN_NAME, state.runName);
	}

	static inline function putEnv(name:String, value:Null<String>) {
		// Std.putEnv(_, null) causes a crash on neko 2.3.0 and earlier
		#if neko if (value != null || (untyped __dollar__version()) > 230) #end
		{
			Sys.putEnv(name, value);
		}
	}

}
