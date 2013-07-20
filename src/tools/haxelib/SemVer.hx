package tools.haxelib;

using Std;

enum Preview {
	ALPHA;
	BETA;
	RC;
}


class SemVer {
	public var precedence:String;
	public var major:Int;
	public var minor:Int;
	public var patch:Int;
	public var preview:Null<Preview>;
	public var previewCmpVal:Int=999;
	public var previewNum:Null<Int>;
	public var previewNumCmpVal:Int=~(1<<31);
	public function new(?precedence : String = "", major, minor, patch, ?preview, ?previewNum) {
		this.precedence = precedence;
		this.major = major;
		this.minor = minor;
		this.patch = patch;
		this.preview = preview;
		if ( this.preview != null ) {
			previewCmpVal = Type.enumIndex( this.preview );
		}
		this.previewNum = previewNum;
		if ( this.previewNum != null ) {
			this.previewNumCmpVal = this.previewNum;
		}
	}

	public function toString():String {
		var ret = '$precedence$major.$minor.$patch';
		if (preview != null) {
			ret += '-' + preview.getName().toLowerCase();
			if (previewNum != null)
				ret += '.' + previewNum;
		}
		return ret;
	}

	public function isSpecific():Bool {
		return (precedence == "");
	}

	public function satisfies(v : SemVer):Bool {
		if ( !this.isSpecific() ) { return false; }

		return compareMain(v) || comparePre(v);
	}

	private function compareMain(other : SemVer) : Bool {
		return cmp(major, other.precedence, other.major) || cmp(minor, other.precedence, other.minor) || cmp(patch, other.precedence, other.patch);
	}

	private function comparePre(other : SemVer) : Bool {
		return cmp(previewCmpVal, other.precedence, other.previewCmpVal) || cmp(previewNumCmpVal, other.precedence, other.previewNumCmpVal);
	}

	private function cmp(a, op, b) : Bool {
		var ret;
		switch (op) {
			case '', '=', '==': ret = (a == b);
			case '!=': ret = (a != b);
			case '>': ret = (a > b);
			case '>=': ret = (a >= b);
			case '<': ret = (a < b);
			case '<=': ret = (a <= b);
			default: throw 'Invalid operator: ' + op;
		}
		return ret;
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
