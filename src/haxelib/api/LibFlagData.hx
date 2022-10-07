package haxelib.api;

import sys.io.File;

import haxe.ds.Option;

import haxelib.Data;

import haxelib.api.Hxml;
import haxelib.VersionData.VersionDataHelper.extractVersion;

using StringTools;

/**
	Enum representing the different possible version information
	that a Haxe `-lib` flag could hold, or a dependency string in a
	`haxelib.json` file.
 **/

private class LibParsingError extends haxe.Exception {}
private final libDataEReg = ~/^(.+?)(?::(.*))?$/;

/**
	Extracts library info from a full flag,
	i.e.: `name:1.2.3` or `name:git:url#hash`
**/
function extractFull(libFlag:String):{name:ProjectName, libFlagData:Option<VersionData>} {
	if (!libDataEReg.match(libFlag))
		throw '$libFlag is not a valid library flag';

	final name = ProjectName.ofString(libDataEReg.matched(1));
	final versionInfo = libDataEReg.matched(2);

	if (versionInfo == null)
		return {name: name, libFlagData: None};

	return {name: name, libFlagData: Some(extractVersion(versionInfo))};
}

function extractFromDependencyString(str:DependencyVersion):Option<VersionData> {
	if (str == "")
		return None;

	return Some(extractVersion(str));
}

private final TARGETS = [
	"java" => ProjectName.ofString('hxjava'),
	"jvm" => ProjectName.ofString('hxjava'),
	"cpp" => ProjectName.ofString('hxcpp'),
	"cs" => ProjectName.ofString('hxcs'),
	"hl" => ProjectName.ofString('hashlink')
];

private final targetFlagEReg = {
	final targetNameGroup = [for (target in TARGETS.keys()) target].join("|");
	new EReg('^--?($targetNameGroup) ', "");
}

private final libraryFlagEReg = ~/^-(lib|L|-library)\b/;

/**
	Extracts the lib information from the hxml file at `path`.

	Does not filter out repeated libs.

	Target libraries (e.g. hxcpp) are also added if they are not explicitly
	included via a -lib flag.
 **/
function fromHxml(path:String):List<{name:ProjectName, data:Option<VersionData>}> {
	final libsData = new List<{name:ProjectName, data:Option<VersionData>}>();
	final targetLibraries:Map<ProjectName, Null<Bool>> = [for (_ => lib in TARGETS) lib => null];

	final lines = [path];

	while (lines.length > 0) {
		final line = lines.shift().trim();
		if (line.endsWith(".hxml")) {
			final newLines = normalizeHxml(File.getContent(line)).split("\n");
			newLines.reverse();
			for (line in newLines)
				lines.unshift(line);
		}

		// check targets
		if (targetFlagEReg.match(line)) {
			final target = targetFlagEReg.matched(1);
			final lib = TARGETS[target];
			if (lib != null && targetLibraries[lib] == null)
				targetLibraries[lib] = true;
		}

		if (libraryFlagEReg.match(line)) {
			final key = libraryFlagEReg.matchedRight().trim();
			if (!libDataEReg.match(key))
				throw '$key is not a valid library flag';

			final name = ProjectName.ofString(libDataEReg.matched(1));

			libsData.add({
				name: name,
				data: switch (libDataEReg.matched(2)) {
					case null: None;
					case v: Some(extractVersion(v));
				}
			});
			final normalizedName = name.toLowerCase();
			if (targetLibraries.exists(normalizedName)) {
				// it is included explicitly, so ignore whether the target flag was used
				targetLibraries[normalizedName] = false;
			}
		}
	}

	// add target libraries required for the hxml that weren't added explicitly
	for (targetLib => shouldInstall in targetLibraries) {
		if (shouldInstall) {
			libsData.add({
				name: targetLib,
				data: None
			});
		}
	}

	return libsData;
}
