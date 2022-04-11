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
/**
	Contains definitions and functions for the data held in the haxelib.json file of a project.
**/

import haxe.ds.Option;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;
import haxelib.Validator;
import haxelib.Util;

using StringTools;
using Lambda;

/** The level of strictness with which a `haxelib.json` check is performed. **/
@:enum abstract CheckLevel(Int) {
	/** No check is performed. **/
	var NoCheck = 0;
	/** Only the syntax of the file is checked. **/
	var CheckSyntax = 1;
	/**
		The syntax is checked and data in the file is validated.

		Data must meet the requirements for publishing to the server.
	**/
	var CheckData = 2;

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
			if (this == DEFAULT)
				{ validate: function () return None }
			else if (this == GIT || #if (haxe_ver < 4.1) Std.is(this, String) #else this is String #end && this.startsWith('git:'))
				{validate: function() return Some("Git dependency is not allowed in a library release")}
			else
				@:privateAccess new SemVer(this);

	/** Returns whether `s` constitutes a valid dependency version string. **/
	static public function isValid(s:String):Bool
		return s == DEFAULT || s == GIT || SemVer.isValid(s);

	/**
		Returns whether `s` constitutes dependency version string that can be used locally.

		The requirements for this are not as strict as `isValid()`, as vcs
		dependencies are allowed.
	 **/
	static public function isUsable(s:String):Bool
		return #if (haxe_ver < 4.1) Std.is(s, String) #else (s is String) #end && s.startsWith('git:') || isValid(s);

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
			// TODO: Also do mercurial
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

	/** Returns an array of the names of the dependencies. **/
	public inline function getNames():Array<ProjectName>
		return [for(name in Reflect.fields(this)) ProjectName.ofString(name) ];

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
	@:disallowed
	var Unknown = 'Unknown';
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
	public static function readDataFromZip( zip : List<Entry>, check : CheckLevel ) : Infos
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

	static function cleanDependencies(dependencies:Null<Dependencies>):Void {
		if (dependencies == null)
			return;
		#if haxe4
		for (name => version in dependencies) {
			if (!DependencyVersion.isUsable(version))
				Reflect.setField(dependencies, name, DependencyVersion.DEFAULT); // TODO: this is pure evil
		}
		#else
		for (name in dependencies.getNames()) {
			if (!DependencyVersion.isUsable(Reflect.field(dependencies, name)))
				Reflect.setField(dependencies, name, DependencyVersion.DEFAULT); // TODO: this is pure evil
		}
		#end
	}

	static inline function isStringArray(array:Array<String>) {
		return #if (haxe_ver < 4.1) Std.is(array, Array) && array.foreach(function(item) { return Std.is(item, String);});
		#else (array is Array) && array.foreach((item) -> item is String);
		#end
	}

	/**
		Extracts project information from `jsondata`, validating it according to `check`.

		`defaultName` is the project name to use if it is empty when the check value allows it.
	**/
	public static function readData( jsondata: String, check : CheckLevel, ?defaultName:ProjectName ) : Infos {
		if (defaultName == null)
			defaultName = ProjectName.DEFAULT;

		var doc:Infos =
			try Json.parse(jsondata)
			catch ( e : Dynamic )
				if (check >= CheckLevel.CheckSyntax)
					throw 'JSON parse error: $e';
				else {
					name : defaultName,
					url : '',
					version : SemVer.DEFAULT,
					releasenote: 'No haxelib.json found',
					license: Unknown,
					description: 'No haxelib.json found',
					contributors: [],
				}

		if (check >= CheckLevel.CheckData) {
			Validator.validate(doc);
		} else {
			if (doc.name.validate() != None)
				doc.name = defaultName;
			if (!doc.version.valid)
				doc.version = SemVer.DEFAULT;
			if (doc.license == null || doc.license == '')
				doc.license = Unknown;
			if (!isStringArray(doc.contributors))
				doc.contributors = [];
			if (doc.releasenote == null)
				doc.releasenote = '';
			cleanDependencies(doc.dependencies);
		}

		//TODO: we have really weird ways to go about nullability and defaults

		// these may have been ommitted even in a valid file
		if (doc.dependencies == null)
			doc.dependencies = {};
		if (doc.classPath == null)
			doc.classPath = '';
		if (doc.description == null)
			doc.description = '';
		if (doc.url == null)
			doc.url = '';
		if (!isStringArray(doc.tags))
			doc.tags = [];

		return doc;
	}
}
