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

/** Like Version, but also has the possible value of `dev` **/
abstract VersionOrDev(String) from VcsID from SemVer from Version to String {
	public static final Dev = cast("dev", VersionOrDev);

	inline public function new(s:String) {
		this = try {
			Version.ofString(s);
		} catch(e:LibraryDataException) {
			if (s == Dev)
				s;
			else
				throw new LibraryDataException('`$s` is neither a valid library version nor equal to `dev`');
		}
	}
}

@:structInit
class LibraryData {
	public final version:VersionOrDev;
	public final dependencies:Array<ProjectName>;
}

@:structInit
class DevLibraryData extends LibraryData {
	/** Also includes the dev Path **/
	public final path:String;
}

@:structInit
class VcsLibraryData extends LibraryData {
	public final url:String;
	/** Reference to current commmit **/
	public final ref:String;
	/** branch from which to download future updates **/
	public final branch:Null<String>;
}

typedef LockFormat = DynamicAccess<LibraryData>;
