package haxelib;

import haxe.Json;
import haxe.ds.Option;

import haxelib.Validator;

using StringTools;

/** A valid project name string. **/
abstract ProjectName(String) to String {
	static var RESERVED_NAMES = ["haxe", "all"];
	static var RESERVED_EXTENSIONS = ['.zip', '.hxml'];

	inline function new(s:String)
		this = s;

	@:to function toValidatable():Validatable
		return {
			validate: function():Option<String> {
				for (r in rules)
					if (!r.check(this))
						return Some(r.msg.replace('%VALUE', '`' + Json.stringify(this) + '`'));
				return None;
			}
		}

	static var rules = { // using an array because order might matter
		var a = new Array<{msg:String, check:String->Bool}>();
		function add(m, r)
			a.push({msg: m, check: r});
		add("%VALUE is not a String", #if (haxe_ver < 4.1) Std.is .bind(_, String) #else Std.isOfType.bind(_, String) #end
		);
		add("%VALUE is too short", function(s) return s.length >= 3);
		add("%VALUE contains invalid characters", Data.alphanum.match);
		add("%VALUE is a reserved name", function(s) return RESERVED_NAMES.indexOf(s.toLowerCase()) == -1);
		add("%VALUE ends with a reserved suffix", function(s) {
			s = s.toLowerCase();
			for (ext in RESERVED_EXTENSIONS)
				if (s.endsWith(ext))
					return false;
			return true;
		});
		a;
	}

	/**
		Validates that the project name is valid.

		If it is invalid, returns `Some(e)` where e is an error
		detailing why the project name is invalid.

		If it is valid, returns `None`.
	**/
	public function validate()
		return toValidatable().validate();

	public function toLowerCase():ProjectName
		return new ProjectName(this.toLowerCase());

	/**
		Returns `s` as a `ProjectName` if it is valid,
		otherwise throws an error explaining why it is invalid.
	**/
	static public function ofString(s:String)
		return switch new ProjectName(s) {
			case _.toValidatable().validate() => Some(e): throw e;
			case v: v;
		}

	/**
		If `alias` is just a different capitalization of `correct`, returns `correct`.

		If `alias` is completely different, returns `alias` instead.
	**/
	static public function getCorrectOrAlias(correct:ProjectName, alias:ProjectName) {
		return if (correct.toLowerCase() == alias.toLowerCase()) correct else alias;
	}

	/** Default project name **/
	static public var DEFAULT(default, null) = new ProjectName('unknown');
}
