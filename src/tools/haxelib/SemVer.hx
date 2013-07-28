package tools.haxelib;

using Std;

enum Preview {
	ALPHA;
	BETA;
	RC;
}


class SemVer {
	public var comparator:String;
	public var major:Int;
	public var minor:Int;
	public var patch:Int;
	public var preview:Null<Preview>;
	public var previewEnumIndex:Null<Int>;
	public var previewNum:Null<Int>;
	public function new(?comparator : String = "", major, minor, patch, ?preview, ?previewNum) {
		this.comparator = comparator;
		this.major = major;
		this.minor = minor;
		this.patch = patch;
		this.preview = preview;
		if ( this.preview != null ) {
			previewEnumIndex = Type.enumIndex( this.preview );
		}
		this.previewNum = previewNum;
	}

	public function toString():String {
		var ret = '$comparator$major.$minor.$patch';
		if (preview != null) {
			ret += '-' + preview.getName().toLowerCase();
			if (previewNum != null)
				ret += '.' + previewNum;
		}
		return ret;
	}

	// Returns true if the SemVer is specific (i.e. is not preceeded by '>', '>=', '<' or '<=')
	public function isSpecific() : Bool {
		return (comparator == '' || comparator == '=');
	}
	}

	// Checks to see if one SemVer satisifies the requirememts of another.
	// The first SemVer must be specific (i.e. Not be preceeded by a '>' or '<=')
	public function satisfies(v : SemVer) : Bool {
		if ( !this.isSpecific() ) { return false; }
		var ret;
		switch (v.comparator) {
			case '', '=', '==': ret = (compare(v) == 0);
			case '!=': ret = (compare(v) != 0);
			case '>': ret = (compare(v) > 0);
			case '>=': ret = (compare(v) >= 0);
			case '<': ret = (compare(v) < 0);
			case '<=': ret = (compare(v) <= 0);
			default: throw 'Invalid operator: ' + v.comparator;
		}
		return ret;
	}

	// Will return 0, 1 or -1 if equal to, greater than or less than.
	private function compare(other : SemVer) : Int {
		var resultMain = compareMain(other);
		var resultPre = comparePre(other);
		return resultMain != 0 ? resultMain : resultPre;
	}

	// Compares the main Major.Minor.Patch parts of the SemVer
	// Will return 0, 1 or -1 if equal to, greater than or less than.
	private function compareMain(other : SemVer) : Int {
		var majorResult = compareIdentifiers(major, other.major);
		var minorResult = compareIdentifiers(minor, other.minor);
		var patchResult = compareIdentifiers(patch, other.patch);
		return 	majorResult != 0 ? majorResult :
				minorResult != 0 ? minorResult :
				patchResult;
	}

	// Compares the secondary preview/release parts of the SemVer
	// Will return 0, 1 or -1 if equal to, greater than or less than.
	private function comparePre(other : SemVer) : Int {
		if ( preview == null && other.preview == null) {
			return 0;
		}
		var previewCmp : Int = compareIdentifiers(previewEnumIndex, other.previewEnumIndex);
		return previewCmp != 0 ? previewCmp : compareIdentifiers(previewNum, other.previewNum);
	}

	function compareIdentifiers(a : Null<Int>, b : Null<Int>) : Int {
		return (a != null && b == null) ? -1:
			(b != null && a == null) ? 1 :
			a < b ? -1 :
			a > b ? 1 :
			0;
	}

	static var parse = ~/^((?:<|>)?=?)([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta|rc)(\.([0-9]+))?)?$/;

	static public function ofString(s:String):SemVer
		return
			if (s!=null && parse.match(s.toLowerCase()))
				new SemVer(
					parse.matched(1),
					parse.matched(2).parseInt(),
					parse.matched(3).parseInt(),
					parse.matched(4).parseInt(),
					switch parse.matched(6) {
						case 'alpha': ALPHA;
						case 'beta': BETA;
						case 'rc': RC;
						case v if (v == null): null;
						case v: throw 'unrecognized preview tag $v';
					},
					switch parse.matched(8) {
						case v if (v == null): null;
						case v: v.parseInt();
					}
				)
			else
				throw '$s is not a valid version string';//TODO: include some URL for reference
}
