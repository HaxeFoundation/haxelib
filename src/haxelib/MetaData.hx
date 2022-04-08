package haxelib;
/**
	Contains definitions of meta data about libraries and their versions used in the Haxelib database
**/

/** Information on a `user` in the Haxelib database. **/
typedef UserInfos = {
	/** The user's name. **/
	var name : String;
	/** The user's full name. **/
	var fullname : String;
	/** The user's email address. **/
	var email : String;
	/** An array of projects for which the user is a contributor. **/
	var projects : Array<String>;
}

/** Information on a specific version of a project in the Haxelib database. **/
typedef VersionInfos = {
	/** The release date of the version. **/
	var date : String;
	/** The version "name" in SemVer form. **/
	var name : SemVer;//TODO: this should eventually be called `number`
	/** The number of downloads this version of the library has had. **/
	var downloads : Int;
	/** The release note that came with this release. **/
	var comments : String;
}

/** Information on a project in the Haxelib database. **/
typedef ProjectInfos = {
	/** The project name. **/
	var name : String;
	/** The project's description. **/
	var desc : String;
	/** A link to the project's website. **/
	var website : String;
	/** The username of the owner of the project. **/
	var owner : String;
	/** An array of contributor's user names and full names. **/
	var contributors : Array<{ name:String, fullname:String }>;
	/** The license under which the project is released. **/
	var license : String;
	/** The current version of the project. **/
	var curversion : String;
	/** The total number of downloads the project has. **/
	var downloads : Int;
	/** An array of `VersionInfos` for each release of the library. **/
	var versions : Array<VersionInfos>;
	/** The project's tags. **/
	var tags : List<String>;
}

class MetaData {
	/**
		Returns the latest version from `info`, or `null` if no releases are found.

		By default preview versions are ignored. If `preview` is passed in,
		preview versions will be checked first and will only be skipped
		if calling `preview` with the `Preview` type of the version,
		and it is only skipped if the call returns `false`.
	**/
	public static function getLatest(info:ProjectInfos, ?preview:SemVer.Preview->Bool):Null<SemVer> {
		if (info.versions.length == 0)
			return null;
		if (preview == null)
			preview = function(p) return p == null;

		var versions = info.versions.copy();
		versions.sort(function(a, b) return -SemVer.compare(a.name, b.name));

		for (v in versions)
			if (preview(v.name.preview))
				return v.name;

		return versions[0].name;
	}
}
