package haxelib;

/** Abstract enum representing the types of Vcs systems that are supported. **/
#if haxe4 enum #else @:enum #end abstract VcsID(String) to String {
	var Hg = "hg";
	var Git = "git";

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
	var url:String;
	/** Commit hash **/
	@:optional
	var ref:Null<String>;
	/** The git tag or mercurial revision **/
	@:optional
	var tag:Null<String>;
	/** Branch **/
	@:optional
	var branch:Null<String>;
	/**
		Sub directory in which the root of the project is found.

		Relative to project root
	**/
	@:optional
	var subDir:Null<String>;

	public function toString(): String {
		var qualifier =
			if (ref != null) ref
			else if (tag != null) tag
			else if (branch != null) branch
			else null;
		return if (qualifier != null)
			'$url#$qualifier'
		else
			url;
	}
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
		} catch (_:String) {}

		var data = getVcsData(versionInfo);
		if (data == null)
			throw '$versionInfo is not a valid library version';
		return VcsInstall(data.type, data.data);
	}

	static var vcsRegex = ~/^(git|hg)(?::(.+?)(?:#(?:([a-f0-9]{7,40})|(.+)))?)?$/;

	static function getVcsData(s:String):Null<{type:VcsID, data:VcsData}> {
		if (!vcsRegex.match(s))
			return null;
		var type = switch (vcsRegex.matched(1)) {
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

	public static function toString(data: VersionData): String
		return switch data {
			case Haxelib(semver): semver;
			case VcsInstall(vcsId, vcsData): '$vcsId:${vcsData.toString()}';
		}
}
