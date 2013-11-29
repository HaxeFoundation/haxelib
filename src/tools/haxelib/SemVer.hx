package tools.haxelib;

using Std;

enum Preview {
	ALPHA;
	BETA;
	RC;
}

enum SemConstraint {
    And(left:SemConstraint, right:SemConstraint);
    Or(left:SemConstraint, right:SemConstraint);
    Gt(ver:SemVer);
    Gte(ver:SemVer);
    Lt(ver:SemVer);
    Lte(ver:SemVer);
    Eq(ver:SemVer);
    Neq(ver:SemVer);
}

class SemVer {
	public var major:Int;
	public var minor:Int;
	public var patch:Int;
	public var preview:Null<Preview>;
	public var previewEnumIndex:Null<Int>;
	public var previewNum:Null<Int>;
	public function new(major, minor, patch, ?preview, ?previewNum) {
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
		var ret = '$major.$minor.$patch';
		if (preview != null) {
			ret += '-' + preview.getName().toLowerCase();
			if (previewNum != null)
				ret += '.' + previewNum;
		}
		return ret;
	}

	private function toConstraint(comparator : String = '') : SemConstraint {
		switch (comparator) {
			case '', '='	: return Eq(this);
			case '!='			: return Neq(this);
			case '>'			: return Gt(this);
			case '>='			: return Gte(this);
			case '<'			: return Lt(this);
			case '<='			: return Lte(this);
			case v: throw 'Invalid operator \'$v\'';
		}
	}

	// Checks to see if one SemVer satisifies the requirememts of another.
	// The first SemVer must be specific (i.e. Not be preceeded by a '>' or '<=')
	public function satisfies(c : SemConstraint) : Bool {
		switch(c) {
			case And(l, r): return satisfies(l) && satisfies(r);
			case Or(l, r) : return satisfies(l) || satisfies(r);
			case Gt(v)		: return compare(v) > 0;
			case Gte(v)		: return compare(v) >= 0;
			case Lt(v)		: return compare(v) < 0;
			case Lte(v)		: return compare(v) <= 0;
			case Eq(v)		: return compare(v) == 0;
			case Neq(v)		: return compare(v) != 0;
		}
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

	static var parse = ~/^([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta|rc)(\.([0-9]+))?)?$/;
	static var parseConstraint = ~/^((?:~)?(?:<|>|!)?=?)(.*?)(\s|$)/;
	static var parseCompound = ~/^(\|\||&&)/;

	static public function constraintOfString(s:String) : SemConstraint {
		var leftConstraint = singleConstraintOfString(s);
		var rightSide = StringTools.trim(parseConstraint.matchedRight());
		if (rightSide != null && rightSide.length > 1) {
			if (parseCompound.match(rightSide)) {
				var compoundOperator = parseCompound.matched(1);
				var compoundRightSide = parseCompound.matchedRight();
				var rightConstraint = constraintOfString(compoundRightSide);
				return
					switch compoundOperator {
						case '&&': And(leftConstraint, rightConstraint);
						case '||': Or(leftConstraint, rightConstraint);
						default: throw "Malformed constraint";
					}
			} else {
				throw "Unbalanced constraints";
			}
		} else {
			return leftConstraint;
		}
	}

	static private function singleConstraintOfString(s:String) : SemConstraint {
		return
			if (s!=null && parseConstraint.match(StringTools.trim(s.toLowerCase()))) {
				SemVer.ofString( parseConstraint.matched(2) ).toConstraint( parseConstraint.matched(1) );
			} else {
				throw '$s is not a constraint';//TODO: include some URL for reference
			}
	}

	static public function ofString(s:String) : SemVer {
		return
			if (s!=null && parse.match(StringTools.trim(s.toLowerCase()))) {
				new SemVer(
					parse.matched(1).parseInt(),
					parse.matched(2).parseInt(),
					parse.matched(3).parseInt(),
					switch parse.matched(5) {
						case 'alpha': ALPHA;
						case 'beta': BETA;
						case 'rc': RC;
						case v if (v == null): null;
						case v: throw 'unrecognized preview tag $v';
					},
					switch parse.matched(7) {
						case v if (v == null): null;
						case v: v.parseInt();
					}
				);
			} else {
				throw '$s is not a valid version string';//TODO: include some URL for reference
			}
	}
}
