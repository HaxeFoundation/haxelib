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
	/** Runs compiled neko file at `path` **/
	Neko(path:String);
	/**  **/
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

	/**
		Run `library`, with `callData`.

		`compilerData` is used if it is an interpreted script.
	 **/
	public static function run(library:LibraryRunData, compilerData:LibraryData, callData:CallData):Void {
		final type = getType(library);

		final cmd = getCmd(type);
		final args = generateArgs(type, callData, SemVer.ofString(compilerData.version));

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
		if (FileSystem.exists(library.path + 'run.n'))
			return Neko(library.path + 'run.n');
		if (FileSystem.exists(library.path + 'Run.hx'))
			return Script("Run", library.name, library.version, library.dependencies);
		throw 'Library ${library.name} version ${library.version} does not have a run script';
	}

	static function getCmd(runType:RunType):String {
		return switch runType {
			case Neko(_): "neko";
			case Script(_): "haxe";
		}
	}

	static function generateArgs(runType:RunType, callData:CallData, compilerVersion:SemVer):Array<String> {
		switch runType {
			case Neko(path):
				final callArgs = callData.args.copy();
				callArgs.unshift(path);
				callArgs.push(callData.dir);
				return callArgs;
			case Script(main, name, version, dependencies):
				final isHaxe4 = SemVer.compare(compilerVersion, SemVer.ofString('4.0.0')) >= 0;
				final useGlobalRepo = isHaxe4 && callData.useGlobalRepo;

				final callArgs = generateScriptArgs(main, name, version, dependencies, useGlobalRepo);
				for (arg in callData.args)
					callArgs.push(arg);
				callArgs.push(callData.dir);
				return callArgs;
		}
	}

	static function generateScriptArgs(main:String, name:ProjectName, version:VersionOrDev, dependencies:Dependencies, useGlobalRepo:Bool):Array<String> {
		final args = [];

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
