package haxelib.api;

import sys.io.File;
import haxe.ds.GenericStack;
import haxe.io.Path;

import haxelib.Data;
import haxelib.VersionData;

import haxelib.api.LibraryData;
import haxelib.api.ScriptRunner;
import haxelib.api.Scope;
import haxelib.api.Hxml;

using StringTools;

/**
	A Global Scope, which resolves libraries using the repository's global configured current
	library versions.
**/
class GlobalScope extends Scope {
	function new(repository:Repository) {
		super(false, repository);
	}

	public function runScript(library:ProjectName, ?callData:CallData, ?version:Version):Void {
		if (callData == null)
			callData = {};
		final resolved = resolveVersionAndPath(library, version);

		final info =
			try Data.readData(File.getContent(resolved.path + Data.JSON), NoCheck)
			catch (e:Dynamic)
				throw 'Failed when trying to parse haxelib.json for $library@${resolved.version}: $e';

		// add dependency versions if given
		final dependencies:Dependencies =
			[for (name => version in info.dependencies)
				Dependency.fromNameAndVersion(name, version)];

		final libraryRunData:LibraryRunData = {
			name: ProjectName.getCorrectOrAlias(info.name, library),
			internalName: info.name,
			version: resolved.version,
			dependencies: dependencies,
			path: resolved.path,
			main: info.main
		};

		ScriptRunner.run(libraryRunData, resolveCompiler(), callData);
	}

	public function getVersion(library:ProjectName):Version {
		return repository.getCurrentVersion(library);
	}

	public function setVersion(library:ProjectName, version:SemVer):Void {
		repository.setCurrentVersion(library, version);
	}

	public function setVcsVersion(library:ProjectName, vcsVersion:VcsID, ?data:VcsData):Void {
		if (data == null) data = {url: "unknown"};

		if (data.subDir != null) {
			final devDir = repository.getValidVersionPath(library, vcsVersion) + data.subDir;
			repository.setDevPath(library, devDir);
		} else {
			repository.setCurrentVersion(library, vcsVersion);
		}
	}

	public function isLibraryInstalled(library:ProjectName):Bool {
		return repository.isCurrentVersionSet(library);
	}

	public function isOverridden(library:ProjectName):Bool {
		if (!repository.isInstalled(library))
			return false;
		return repository.getDevPath(library) != null;
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

	public function getLibraryNames():Array<ProjectName> {
		return repository.getLibraryNames();
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
		final stack = new GenericStack<{library:ProjectName, version:Null<Version>}>();
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
			// turn it to lowercase always (so that `LiBrArY:1.2.0` and `library:1.3.0` clash because
			// they are different versions), and then get the correct name if provided
			final library = repository.getCorrectName(cur.library);
			final version = cur.version;

			// check for duplicates
			if (includedLibraries.exists(library)) {
				final otherVersion = includedLibraries[library];
				// if the current library is part of the original set of inputs, and if the versions don't match
				if (topLevelLibs.contains(cur) && version != null && version != otherVersion)
					throw 'Cannot process `${cur.library}:$version`: '
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
				// `library` (i.e. the .name value) will be used as the name if haxelib.json has no "name" field
				Data.readData(jsonContent, jsonContent != null ? CheckSyntax : NoCheck, library);
			}

			// path and version compiler define
			addLine(
				if (info.classPath != "")
					Path.addTrailingSlash(Path.join([resolved.path, info.classPath]))
				else
					resolved.path
			);
			addLine('-D ${info.name}=${info.version}');

			if (info.documentation != null) {
				var doc = info.documentation;

				// we'll have to change this to "4.3.0" after the release
				if (resolveCompiler().version >= SemVer.ofString("4.3.0-rc.1")) {
					// custom defines if defined
					if (doc.defines != null && doc.defines != "") {
						var path = Path.join([resolved.path, doc.defines]);
						addLine('--macro addDefinesDescriptionFile(\'$path\', \'${info.name}\')');
					}

					// custom metadatas if defined
					if (doc.metadata != null && doc.metadata != "") {
						var path = Path.join([resolved.path, doc.metadata]);
						addLine('--macro addMetadataDescriptionFile(\'$path\', \'${info.name}\')');
					}
				}
			}

			// add dependencies to stack
			final dependencies = info.dependencies.extractDataArray();

			while (dependencies.length > 0) {
				final dependency = dependencies.pop();
				stack.add({
					library: ProjectName.ofString(dependency.name),
					version: // TODO: maybe check the git/hg commit hash here if it's given?
						switch dependency.versionData {
							case None: null;
							case Some(Haxelib(version)): version;
							case Some(VcsInstall(version, _)): version;
						}
				});
			}
		}

		return argsString.trim();
	}

	static var haxeVersion(get, null):SemVer;

	static function get_haxeVersion():SemVer {
		if (haxeVersion != null)
			return haxeVersion;

		function attempt(cmd:String, arg:String, readStdErr = false):SemVer {
			final p = new sys.io.Process(cmd, [arg]);
			final outCode = p.exitCode();
			final err = p.stderr.readAll().toString();
			final versionStr = if (readStdErr) err else p.stdout.readAll().toString();
			p.close();
			if (outCode != 0)
				throw 'Cannot get haxe version: $err';
			return SemVer.ofString(versionStr.split('+')[0]);
		}

		return try {
			// this works on haxe 4.0 and above
			haxeVersion = attempt("haxe", "--version");
		} catch (_) {
			// old haxe versions only understand `-version`
			// they also print the version to stderr for whatever reason...
			haxeVersion = attempt("haxe", "-version", true);
		}
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
			return {path: devPath, version: Dev.Dev};

		final current = repository.getCurrentVersion(library);
		final path = repository.getValidVersionPath(library, current);
		return {path: path, version: current};
	}

}
