package haxelib;

/** Abstract enum representing the types of Vcs systems that are supported. **/
@:enum abstract VcsID(String) to String {
	final Hg = "hg";
	final Git = "git";

	/** Returns `true` if `s` constitutes a valid VcsID **/
	public static function isValid(s:String) {
		return s == Hg || s == Git;
	}

	/** Returns `s` as a VcsID if it is valid, otherwise throws an error. **/
	public static function ofString(s:String):VcsID {
		if (s == Git)
			return Git;
		else if (s == Hg)
			return Hg;
		else
			throw 'Invalid VscID $s';
	}
}

/** Class containing repoducible git or hg library data. **/
@:structInit @:publicFields
class VcsData {
	/** url from which to install **/
	final url:String;
	/** Commit hash **/
	@:optional
	final ref:Null<String>;
	/** The git tag or mercurial revision **/
	@:optional
	final tag:Null<String>;
	/** Branch **/
	@:optional
	final branch:Null<String>;
	/**
		Sub directory in which the root of the project is found.

		Relative to project root
	**/
	@:optional
	final subDir:Null<String>;
}

/** Data required to reproduce a library version **/
enum VersionData {
	Haxelib(version:SemVer);
	VcsInstall(version:VcsID, vcsData:VcsData);
}

class VersionDataHelper {
	public static function extractVersion(versionInfo:String):VersionData {
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

	static final vcsRegex = ~/^(git|hg)(?::(.+?)(?:#(?:([a-f0-9]{7,40})|(.+)))?)?$/;

	static function getVcsData(s:String):{type:VcsID, data:VcsData} {
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
}
