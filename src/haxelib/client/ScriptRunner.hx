package haxelib.client;

import sys.FileSystem;

import haxelib.Data.ProjectName;
import haxelib.Data.DependencyVersion;
import haxelib.client.LibraryData;

@:structInit
class CallData {
	/** Directory in which the script will start. Defaults to current working directory. **/
	public final dir = Sys.getCwd();
	/** Array of arguments to be passed on to the library call. **/
	public final args:Array<String> = [];
	/**
		Whether to pass `--haxelib-global` to the haxe compiler when running.
		(only works with haxe 4.0.0 and above)
	**/
	public final useGlobalRepo:Bool = false;
}

// either the project `name` or `name:version`
abstract Dependency(String) from ProjectName to String {
	inline function new(d) this = d;
	public static function fromNameAndVersion(name:ProjectName, version:DependencyVersion):Dependency
		return new Dependency(switch cast(version, String) {
			case '': name;
			case version: '$name:$version';
		});
}

typedef Dependencies = Array<Dependency>;

/** Library data needed in order to run it **/
typedef LibraryRunData = {
	name:ProjectName,
	version:VersionOrDev,
	dependencies:Dependencies,
	main:String,
	path:String
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

class ScriptError extends haxe.Exception {
	public final code:Int;
	public function new(name:ProjectName, code:Int) {
		super('Script for library "$name" exited with error code: $code');
		this.code = code;
	}
}

class ScriptRunner {
	static final HAXELIB_RUN = "HAXELIB_RUN";
	static final HAXELIB_RUN_NAME = "HAXELIB_RUN_NAME";

	public static function run(library:LibraryRunData, compilerData:LibraryData, callData:CallData):Void {
		final type = getType(library);

		final cmd = getCmd(type);
		final args = generateArgs(type, callData, SemVer.ofString(compilerData.version));

		final oldState = getState();

		// call setup
		setState({
			dir: library.path,
			run: "1",
			runName: library.name
		});

		final output = Sys.command(cmd, args);

		// return to previous state
		setState(oldState);

		if (output != 0)
			throw new ScriptError(library.name, output);
	}

	static function getType(library:LibraryRunData) {
		final type = switch (library.main) {
			case main if (main != null):
				Script(main, library.name, library.version, library.dependencies);
			case null if (FileSystem.exists(library.path + 'run.n')):
				Neko(library.path + 'run.n');
			case null if (FileSystem.exists(library.path + 'Run.hx')):
				Script("Run", library.name, library.version, library.dependencies);
			case _:
				throw 'Library ${library.name} version ${library.version} does not have a run script';
		}
		return type;
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
		Sys.putEnv(HAXELIB_RUN, state.run);
		Sys.putEnv(HAXELIB_RUN_NAME, state.runName);
	}

}
