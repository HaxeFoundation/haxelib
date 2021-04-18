package haxelib.api;

import sys.io.File;

import haxelib.Data;

import haxelib.api.Hxml;
import haxelib.api.Vcs.VcsID;
import haxelib.api.LibraryData.VcsData;

using StringTools;

enum LibFlagData {
	None;
	Haxelib(version:SemVer);
	VcsInstall(version:VcsID, vcsData:VcsData);
}

private class LibParsingError extends haxe.Exception {}
private final libDataEReg = ~/^(.+?)(?::(.*))?$/;

/** Extracts library info from a full flag,
	i.e.: `name:1.2.3` or `name:git:url#hash`
**/
function extractFull(libFlag:String):{name:ProjectName, libFlagData:LibFlagData} {
	if (!libDataEReg.match(libFlag))
		throw '$libFlag is not a valid library flag';

	final name = ProjectName.ofString(libDataEReg.matched(1));
	final versionInfo = libDataEReg.matched(2);

	if (versionInfo == null)
		return {name: name, libFlagData: None};

	return {name: name, libFlagData: extractVersion(versionInfo)};
}

function extractFromDependencyString(str:DependencyVersion):LibFlagData {
	if (str == "")
		return None;

	return extractVersion(str);
}

private function extractVersion(versionInfo:String):LibFlagData {
	try {
		return Haxelib(SemVer.ofString(versionInfo));
	} catch (_) {}

	try {
		final data = getVcsData(versionInfo);
		return VcsInstall(data.type, data.data);
	} catch (e) {
		throw '$versionInfo is not a valid library version';
	}
}

private final vcsRegex = ~/^(git|hg)(?::(.+?)(?:#(?:([a-f0-9]{7,40})|(.+)))?)?$/;

private function getVcsData(s:String):{type:VcsID, data:VcsData} {
	if (!vcsRegex.match(s))
		throw '$s is not valid';
	final type = switch (vcsRegex.matched(1)) {
		case Git:
			Git;
		case _:
			Hg;
	}
	return {
		type: type,
		data: {
			url: vcsRegex.matched(2),
			ref: vcsRegex.matched(3),
			branch: vcsRegex.matched(4),
			subDir: null,
			tag: null
		}
	}
}

private final TARGETS = [
	"java" => ProjectName.ofString('hxjava'),
	"cpp" => ProjectName.ofString('hxcpp'),
	"cs" => ProjectName.ofString('hxcs'),
	"hl" => ProjectName.ofString('hashlink')
];
private final targetFlagEReg = ~/^--?(java|cpp|cs|hl) /;

private final libraryFlagEReg = ~/^-(lib|L|-library)\b/;

/** Extracts the lib information from the hxml file at `path`.

	Does not filter out repeated libs.
 **/
function fromHxml(path:String):List<{name:ProjectName, data:LibFlagData, isTargetLib:Bool}> {
	final libsData = new List<{name:ProjectName, data:LibFlagData, isTargetLib:Bool}>();

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
			if (lib != null && (target != "hl" || line.endsWith(".c")))
				libsData.add({name: lib, data: None, isTargetLib: true});
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
					case v: extractVersion(v);
				},
				isTargetLib: false
			});
		}
	}
	return libsData;
}
