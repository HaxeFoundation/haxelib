package haxelib.client;

import sys.io.File;

import haxelib.Data;

import haxelib.client.LibraryData;
import haxelib.client.ScriptRunner;
import haxelib.client.Scope;

using StringTools;

class GlobalScope extends Scope {
	function new(repository:Repository) {
		super(false, repository);
	}

	public function runScript(library:ProjectName, ?callData:CallData, ?version:Version):Void {
		callData = callData != null ? callData : {};
		final resolved = resolveVersionAndPath(library, version);

		final info = try Data.readData(File.getContent(resolved.path + 'haxelib.json'), false) catch (e:Dynamic) {
			throw 'Failed when trying to parse haxelib.json for $library@${resolved.version}: $e';
		};

		// add dependency versions if given
		final dependencies:Dependencies =
			[for (name => version in info.dependencies)
				Dependency.fromNameAndVersion(name, version)];

		final libraryRunData = {
			name: library,
			version: resolved.version,
			dependencies: dependencies,
			path: resolved.path,
			main: info.main
		}

		ScriptRunner.run(libraryRunData, resolveCompiler(), callData);
	}

	static var haxeVersion(get, null):SemVer;

	static function get_haxeVersion():SemVer {
		if (haxeVersion == null) {
			final p = new sys.io.Process('haxe', ['--version']);
			if (p.exitCode() != 0) {
				throw 'Cannot get haxe version: ${p.stderr.readAll().toString()}';
			}
			final str = p.stdout.readAll().toString();
			haxeVersion = SemVer.ofString(str.split('+')[0]);
		}
		return haxeVersion;
	}

	function resolveCompiler():LibraryData {
		return {
			version: haxeVersion,
			dependencies: []
		};
	}

	function resolveVersionAndPath(library:ProjectName, version:Null<Version>):{path:String, version:VersionOrDev} {
		if (version != null) {
			final path = repository.getValidVersionPath(library, version);
			return {path: path, version: version};
		}

		final devPath = repository.getDevPath(library);
		if (devPath != null)
			return {path: devPath, version: VersionOrDev.Dev};

		final current = repository.getCurrentVersion(library);
		final path = repository.getValidVersionPath(library, current);
		return {path: path, version: current};
	}

}
