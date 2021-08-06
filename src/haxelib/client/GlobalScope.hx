package haxelib.client;

import sys.io.File;
import haxe.ds.GenericStack;
import haxe.ds.Option;
import haxe.io.Path;

import haxelib.Data;

import haxelib.client.LibraryData;
import haxelib.client.ScriptRunner;
import haxelib.client.Scope;
import haxelib.client.Hxml;

using StringTools;

class GlobalScope extends Scope {
	function new(repository:Repository) {
		super(false, repository);
	}

	public function runScript(library:ProjectName, ?callData:CallData, ?version:Version):Void {
		callData = callData != null ? callData : {};
		final resolved = resolveVersionAndPath(library, version);

		final info =
			try Data.readData(File.getContent(resolved.path + Data.JSON), false)
			catch (e:Dynamic)
				throw 'Failed when trying to parse haxelib.json for $library@${resolved.version}: $e';

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

	public function getPath(library:ProjectName, ?version:Version):String {
		if (version != null)
			return repository.getValidVersionPath(library, version);

		final devPath = repository.getDevPath(library);
		if (devPath != null)
			return devPath;

		final current = repository.getCurrentVersion(library);
		return repository.getValidVersionPath(library, current);
	}

	public function getArrayOfLibraryInfo(?filter:String):Array<InstallationInfo> {
		final names = repository.getLibraryNames(filter);

		final projects = new Array<InstallationInfo>();

		for (name in names) {
			final info = repository.getProjectInstallationInfo(name);

			projects.push({
				name: name,
				current: try repository.getCurrentVersion(name) catch(e) null,
				devPath: info.devPath,
				versions: info.versions
			});
		}

		return projects;
	}

	public function getArgsAsHxml(library:ProjectName, ?version:Version):String {
		final stack = new GenericStack();
		stack.add({library: library, version: version});

		return getArgsAsHxmlWithDependencies(stack);
	}

	public function getArgsAsHxmlForLibraries(libraries:Array<{library:ProjectName, version:Null<Version>}>):String {
		final stack = new GenericStack<{library:ProjectName, version:Null<Version>}>();

		for (i in 1...libraries.length + 1)
			stack.add(libraries[libraries.length - i]);

		return getArgsAsHxmlWithDependencies(stack);
	}

	function getArgsAsHxmlWithDependencies(stack:GenericStack<{library:ProjectName, version:Null<Version>}>){
		var argsString = "";
		function addLine(s:String)
			argsString += '$s\n';

		// the original set of inputs
		final topLevelLibs = [for (lib in stack) lib];

		final includedLibraries:Map<ProjectName, VersionOrDev> = [];

		while (!stack.isEmpty()) {
			final cur = stack.pop();
			final library = cur.library;
			final version = cur.version;

			// check for duplicates
			if (includedLibraries.exists(library)) {
				final otherVersion = includedLibraries[library];
				// if the current library is part of the original set of inputs, and if the versions don't match
				if (topLevelLibs.contains(cur) && version != null && version != otherVersion)
					throw 'Cannot process `$library:$version`:'
						+ 'Library $library has two versions included : $otherVersion and $version';
				continue;
			}

			final resolved = resolveVersionAndPath(library, version);
			includedLibraries[library] = resolved.version;

			// neko libraries
			final ndllDir = resolved.path + "ndll/";
			if (sys.FileSystem.exists(ndllDir))
				addLine('-L $ndllDir');

			// extra parameters
			try {
				addLine(normalizeHxml(File.getContent(resolved.path + "extraParams.hxml")));
			} catch (_:Dynamic) {}

			final info = {
				final jsonContent = try File.getContent(resolved.path + Data.JSON) catch (_) null;
				Data.readData(jsonContent, jsonContent != null ? CheckSyntax : NoCheck);
			}

			// path and version compiler define
			addLine(
				if (info.classPath != "")
					Path.addTrailingSlash(Path.join([resolved.path, info.classPath]))
				else
					resolved.path
			);
			addLine('-D $library=${info.version}');

			// add dependencies to stack
			final dependencies = info.dependencies.toArray();

			while (dependencies.length > 0) {
				final dependency = dependencies.pop();
				stack.add({
					library: ProjectName.ofString(dependency.name),
					version: // TODO: maybe check the git/hg commit hash here if it's given?
						if (dependency.version == DependencyVersion.DEFAULT) null
						else Version.ofString(dependency.version)
				});
			}
		}

		return argsString.trim();
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
