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

	public function getName() {
		return switch cast(this, VcsID) {
			case Git: "Git";
			case Hg: "Mercurial";
		};
	}
}

/** Class containing repoducible git or hg library data. **/
@:structInit @:publicFields
class VcsData {
	/** url from which to install **/
	var url:String;
	/** Commit hash **/
	@:optional
	var commit:Null<String>;
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
			if (commit != null) commit
			else if (tag != null) tag
			else if (branch != null) branch
			else null;
		return if (qualifier != null)
			'$url#$qualifier'
		else
			url;
	}

	/**
		Returns whether this vcs data will always reproduce an identical installation
		(i.e. the commit id is locked down)
	**/
	public function isReproducible() {
		return commit != null;
	}

	/**
		Returns an anonymous object containing only the non-null, non-empty VcsData fields,
		excluding the null/empty ones.
	 **/
	public function getCleaned() {
		var data:{
			url:String,
			?commit:String,
			?tag:String,
			?branch:String,
			?subDir:String
		} = { url : url };

		if (commit != null)
			data.commit = commit;
		if (tag != null)
			data.tag = tag;
		if (!(branch == null || branch == ""))
			data.branch = branch;
		if (!(subDir == null || haxe.io.Path.normalize(subDir) == ""))
			data.subDir = subDir;

		return data;
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
				commit: vcsRegex.matched(3),
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
