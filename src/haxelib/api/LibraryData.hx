package haxelib.api;

import haxe.DynamicAccess;

import haxelib.Data.ProjectName;
import haxelib.api.Vcs.VcsID;

/** Exception thrown upon errors regarding library data, such as invalid versions. **/
class LibraryDataException extends haxe.Exception {}

/**
	Library version, which can be used in commands.

	This type of library version has a physical folder in the project root directory
	(i.e. it is not a dev version)
**/
abstract Version(String) to String from SemVer from VcsID {
	inline function new(s:String) {
		this = s;
	}

	public static function ofString(s:String):Version {
		if (!isValid(s))
			throw new LibraryDataException('`$s` is not a valid library version');
		return new Version(s);
	}

	/** Returns whether `s` constitues a valid library version. **/
	public static function isValid(s:String):Bool {
		return s == Git || s == Hg || SemVer.isValid(s);
	}
}

/** A library version which can only be `dev`. **/
@:noDoc
enum abstract Dev(String) to String {
	final Dev = "dev";
}

/** Like `Version`, but also has the possible value of `dev`. **/
abstract VersionOrDev(String) from VcsID from SemVer from Version from Dev to String {}

/** Interface which all types of library data implement. **/
interface ILibraryData {
	final version:VersionOrDev;
	final dependencies:Array<ProjectName>;
}

/** Data for a library installed from the haxelib server. **/
@:structInit
class LibraryData implements ILibraryData {
	public final version:SemVer;
	public final dependencies:Array<ProjectName>;
}

/** Data for a library located in a local development path. **/
@:structInit
class DevLibraryData implements ILibraryData {
	public final version:Dev;
	public final dependencies:Array<ProjectName>;
	public final path:String;
}

/** Data for a library installed via vcs. **/
@:structInit
class VcsLibraryData implements ILibraryData {
	public final version:VcsID;
	public final dependencies:Array<ProjectName>;
	/** Reproducible vcs information **/
	public final vcs:VcsData;
}

private final hashRegex = ~/^([a-f0-9]{7,40})$/;
function isCommitHash(str:String)
	return hashRegex.match(str);

/** Class containing repoducible git or hg library data. **/
@:structInit
class VcsData {
	/** url from which to install **/
	public final url:String;
	/** Commit hash **/
	@:optional
	public final ref:Null<String>;
	/** The git tag or mercurial revision **/
	@:optional
	public final tag:Null<String>;
	/** Branch **/
	@:optional
	public final branch:Null<String>;
	/** Sub directory in which the root of the project is found.

		Relative to project root
	**/
	@:optional
	public final subDir:Null<String>;
}

typedef LockFormat = DynamicAccess<LibraryData>;
