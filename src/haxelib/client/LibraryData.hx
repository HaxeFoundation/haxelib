package haxelib.client;

import haxe.DynamicAccess;

import haxelib.Data.ProjectName;
import haxelib.client.Vcs.VcsID;

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

enum abstract Dev(String) to String {
	final Dev = "dev";
}

/** Like Version, but also has the possible value of `dev` **/
abstract VersionOrDev(String) from VcsID from SemVer from Version from Dev to String {
	inline public function new(s:String) {
		this = try {
			Version.ofString(s);
		} catch(e:LibraryDataException) {
			if (s == Dev.Dev)
				s;
			else
				throw new LibraryDataException('`$s` is neither a valid library version nor equal to `dev`');
		}
	}
}

interface ILibraryData {
	final version:VersionOrDev;
	final dependencies:Array<ProjectName>;
}

@:structInit
class LibraryData implements ILibraryData {
	public final version:SemVer;
	public final dependencies:Array<ProjectName>;
}

/** Also includes the dev Path **/
@:structInit
class DevLibraryData implements ILibraryData {
	public final version:Dev;
	public final dependencies:Array<ProjectName>;
	public final path:String;
}

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
