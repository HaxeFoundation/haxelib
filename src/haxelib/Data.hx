/*
 * Copyright (C)2005-2016 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package haxelib;

import haxe.ds.Option;
import haxe.ds.*;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;
import haxelib.Validator;

using StringTools;

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

/** The level of strictness with which a `haxelib.json` check is performed. **/
@:enum abstract CheckLevel(Int) {
	/** No check is performed. **/
	var NoCheck = 0;
	/** Only the syntax of the file is checked. **/
	var CheckSyntax = 1;
	/** The syntax is checked and data in the file is validated. **/
	var CheckData = 2;

	@:from static inline function fromBool(check:Bool):CheckLevel {
		return check ? CheckData : NoCheck;
	}

	@:op(A > B) function gt(b:CheckLevel):Bool;
	@:op(A >= B) function gte(b:CheckLevel):Bool;
	@:op(A == B) function eq(b:CheckLevel):Bool;
	@:op(A <= B) function lte(b:CheckLevel):Bool;
	@:op(A < B) function lt(b:CheckLevel):Bool;
}

/** The version of a dependency specified in a `haxelib.json`. **/
abstract DependencyVersion(String) to String from SemVer {
	inline function new(s:String)
		this = s;

	@:to function toValidatable():Validatable
		return
			if (this == DEFAULT || this == GIT || (#if (haxe_ver < 4.1) Std.is #else Std.isOfType #end(this, String) && this.startsWith('git:')))
				{ validate: function () return None }
			else
				@:privateAccess new SemVer(this);

	/** Returns whether `s` constitutes a valid dependency version string. **/
	static public function isValid(s:String):Bool
		return new DependencyVersion(s).toValidatable().validate() == None;

	/** Default empty dependency version. **/
	static public var DEFAULT(default, null) = new DependencyVersion('');
	/** Git dependency version. **/
	static public var GIT(default, null) = new DependencyVersion('git');
}

/** Dependency names and versions. **/
abstract Dependencies(Dynamic<DependencyVersion>) from Dynamic<DependencyVersion> {
	/** Extracts the dependency data and returns an array of `Dependency` objects. **/
	@:to public function toArray():Array<Dependency> {
		var fields = Reflect.fields(this);
		fields.sort(Reflect.compare);

		var result:Array<Dependency> = new Array<Dependency>();

		for (f in fields) {
			var value:String = Reflect.field(this, f);

			var isGit = value != null && (value + "").startsWith("git:");

			if ( !isGit ){
				result.push ({
					name: f,
					type: (DependencyType.Haxelib : DependencyType),
					version: (cast value : DependencyVersion),
					url: (null : String),
					subDir: (null : String),
					branch: (null : String),
				});
			} else {
				value = value.substr(4);
				var urlParts = value.split("#");
				var url = urlParts[0];
				var branch = urlParts.length > 1 ? urlParts[1] : null;

				result.push ({
					name: f,
					type: (DependencyType.Git : DependencyType),
					version: (DependencyVersion.DEFAULT : DependencyVersion),
					url: (url : String),
					subDir: (null : String),
					branch: (branch : String),
				});
			}
		}

		return result;
	}

	public inline function iterator()
		return toArray().iterator();

	#if (haxe_ver >= 4.0)
	public inline function keyValueIterator():KeyValueIterator<ProjectName, DependencyVersion> {
		final fields = Reflect.fields(this);
		var index = 0;
		return {
			next: function() {
				final name = fields[index++];
				return {key: ProjectName.ofString(name), value: Reflect.field(this, name)};
			},
			hasNext: function() return index < fields.length
		}
	}
	#end
}

/** The type of a dependency version. **/
@:enum abstract DependencyType(String) {
	var Haxelib = null;
	var Git = 'git';
	var Mercurial = 'hg';
}

/** Data on a project dependency. **/
typedef Dependency = {
	name : String,
	?version : DependencyVersion,
	?type: DependencyType,
	?url: String,
	?subDir: String,
	?branch: String,
}

/** Data held in the `haxelib.json` file. **/
typedef Infos = {
	// IMPORTANT: if you change this or its fields types,
	// make sure to update `schema.json` file accordingly,
	// and make an update PR to https://github.com/SchemaStore/schemastore
	var name : ProjectName;
	@:optional var url : String;
	@:optional var description : String;
	var license : License;
	var version : SemVer;
	@:optional var classPath : String;
	var releasenote : String;
	@:requires('Specify at least one contributor' => _.length > 0)
	var contributors : Array<String>;
	@:optional var tags : Array<String>;
	@:optional var dependencies : Dependencies;
	@:optional var main:String;
}

/** An abstract enum representing the different Licenses a project can have. **/
@:enum abstract License(String) to String {
	var Gpl = 'GPL';
	var Lgpl = 'LGPL';
	var Mit = 'MIT';
	var Bsd = 'BSD';
	var Public = 'Public';
	var Apache = 'Apache';
}

/** A valid project name string. **/
abstract ProjectName(String) to String {
	static var RESERVED_NAMES = ["haxe", "all"];
	static var RESERVED_EXTENSIONS = ['.zip', '.hxml'];
	inline function new(s:String)
		this = s;

	@:to function toValidatable():Validatable
		return {
			validate:
				function ():Option<String> {
					for (r in rules)
						if (!r.check(this))
							return Some(r.msg.replace('%VALUE', '`' + Json.stringify(this) + '`'));
						return None;
				}
		}

	static var rules = {//using an array because order might matter
		var a = new Array<{ msg: String, check:String->Bool }>();

		function add(m, r)
			a.push( { msg: m, check: r } );

		add("%VALUE is not a String",
			#if (haxe_ver < 4.1)
				Std.is.bind(_, String)
			#else
				Std.isOfType.bind(_, String)
			#end
		);
		add("%VALUE is too short", function (s) return s.length >= 3);
		add("%VALUE contains invalid characters", Data.alphanum.match);
		add("%VALUE is a reserved name", function(s) return RESERVED_NAMES.indexOf(s.toLowerCase()) == -1);
		add("%VALUE ends with a reserved suffix", function(s) {
			s = s.toLowerCase();
			for (ext in RESERVED_EXTENSIONS)
				if (s.endsWith(ext)) return false;
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

	/**
		Returns `s` as a `ProjectName` if it is valid,
		otherwise throws an error explaining why it is invalid.
	 **/
	static public function ofString(s:String)
		return switch new ProjectName(s) {
			case _.toValidatable().validate() => Some(e): throw e;
			case v: v;
		}

	/** Default project name **/
	static public var DEFAULT(default, null) = new ProjectName('unknown');
}

/** Class providing functions for working with project information. **/
class Data {

	/** The name of the file containing the project information. **/
	public static var JSON(default, null) = "haxelib.json";
	/** The name of the file containing project documentation. **/
	public static var DOCXML(default, null) = "haxedoc.xml";
	/** The location of the repository in the haxelib server. **/
	public static var REPOSITORY(default, null) = "files/3.0";
	/** Regex matching alphanumeric strings, which can also include periods, dashes, or underscores. **/
	public static var alphanum(default, null) = ~/^[A-Za-z0-9_.-]+$/;

	/**
		Convert periods in `name` into commas. Throws an error if `name`
		contains invalid characters.
	 **/
	public static function safe( name : String ) {
		if( !alphanum.match(name) )
			throw "Invalid parameter : "+name;
		return name.split(".").join(",");
	}

	/** Converts commas in `name` into periods. **/
	public static function unsafe( name : String ) {
		return name.split(",").join(".");
	}

	/** Returns the zip file name for version `ver` of `lib`. **/
	public static function fileName( lib : String, ver : String ) {
		return safe(lib)+"-"+safe(ver)+".zip";
	}

	/**
		Returns the latest version from `info`, or `null` if no releases are found.

		By default preview versions are ignored. If `preview` is passed in,
		preview versions will be checked first and will only be skipped
		if calling `preview` with the `Preview` type of the version,
		and it is only skipped if the call returns `false`.
	 **/
	static public function getLatest(info:ProjectInfos, ?preview:SemVer.Preview->Bool):Null<SemVer> {
		if (info.versions.length == 0) return null;
		if (preview == null)
			preview = function (p) return p == null;

		var versions = info.versions.copy();
		versions.sort(function (a, b) return -SemVer.compare(a.name, b.name));

		for (v in versions)
			if (preview(v.name.preview)) return v.name;

		return versions[0].name;
	}

	/**
		Returns the directory that contains *haxelib.json*.
		If it is at the root, `""`.
		If it is in a folder, the path including a trailing slash is returned.
	*/
	public static function locateBasePath( zip : List<Entry> ):String {
		var f = getJson(zip);
		return f.fileName.substr(0, f.fileName.length - JSON.length);
	}

	static function getJson(zip:List<Entry>)
		return switch topmost(zip, fileNamed(JSON)) {
			case Some(f): f;
			default: throw 'No $JSON found';
		}

	static function fileNamed(name:String)
		return function (f:Entry) return f.fileName.endsWith(name);

	static function topmost(zip:List<Entry>, predicate:Entry->Bool):Option<Entry> {
		var best:Entry = null,
			bestDepth = 0xFFFF;

		for (f in zip)
			if (predicate(f)) {
				var depth = f.fileName.replace('\\', '/').split('/').length;//TODO: consider Path.normalize
				if ((depth == bestDepth && f.fileName < best.fileName) || depth < bestDepth) {
					best = f;
					bestDepth = depth;
				}
			}

		return
			if (best == null)
				None;
			else
				Some(best);
	}

	/** Returns the documentation file contents within `zip`, or `null` if it none is found. **/
	public static function readDoc( zip : List<Entry> ) : Null<String>
		return switch topmost(zip, fileNamed(DOCXML)) {
			case Some(f): Reader.unzip(f).toString();
			case None: null;
		}

	/** Retrieves the haxelib.json data from `zip`, validating it according to `check`. **/
	public static function readInfos( zip : List<Entry>, check : CheckLevel ) : Infos
		return readData(Reader.unzip(getJson(zip)).toString(), check);

	/** Throws an exception if the classpath in `infos` does not exist in `zip`. **/
	public static function checkClassPath( zip : List<Entry>, infos : Infos ) {
		if ( infos.classPath != "" ) {
			var basePath = Data.locateBasePath(zip);
			var cp = basePath + infos.classPath;

			for( f in zip ) {
				if( StringTools.startsWith(f.fileName,cp) )
					return;
			}
			throw 'Class path `${infos.classPath}` not found';
		}
	}

	/** Extracts project information from `jsondata`, validating it according to `check`. **/
	public static function readData( jsondata: String, check : CheckLevel ) : Infos {
		var doc:Infos =
			try Json.parse(jsondata)
			catch ( e : Dynamic )
				if (check >= CheckLevel.CheckSyntax)
					throw 'JSON parse error: $e';
				else {
					name : ProjectName.DEFAULT,
					url : '',
					version : SemVer.DEFAULT,
					releasenote: 'No haxelib.json found',
					license: Mit,
					description: 'No haxelib.json found',
					contributors: [],
				}

		if (check >= CheckLevel.CheckData)
			Validator.validate(doc);
		else {
			if (!doc.version.valid)
				doc.version = SemVer.DEFAULT;
		}

		//TODO: we have really weird ways to go about nullability and defaults

		if (doc.dependencies == null)
			doc.dependencies = {};

		for (dep in doc.dependencies)
			if (!DependencyVersion.isValid(dep.version))
				Reflect.setField(doc.dependencies, dep.name, DependencyVersion.DEFAULT);//TODO: this is pure evil

		if (doc.classPath == null)
			doc.classPath = '';

		if (doc.name.validate() != None)
			doc.name = ProjectName.DEFAULT;

		if (doc.description == null)
			doc.description = '';

		if (doc.tags == null)
			doc.tags = [];

		if (doc.url == null)
			doc.url = '';

		return doc;
	}
}
