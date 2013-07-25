/*
 * Copyright (C)2005-2012 Haxe Foundation
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
package tools.haxelib;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;
using StringTools;

typedef UserInfos = {
	var name : String;
	var fullname : String;
	var email : String;
	var projects : Array<String>;
}

typedef VersionInfos = {
	var date : String;
	var name : String;
	var comments : String;
}

typedef ProjectInfos = {
	var name : String;
	var desc : String;
	var website : String;
	var owner : String;
	var license : String;
	var curversion : String;
	var versions : Array<VersionInfos>;
	var tags : List<String>;
}

typedef Infos = {
	var project : String;
	var website : String;
	var desc : String;
	var license : String;
	var version : String;
	var classPath : String;
	var versionComments : String;
	var developers : List<String>;
	var tags : List<String>;
	var dependencies : List<{ project : String, version : String }>;
}

class Data {

	public static var JSON = "haxelib.json";
	public static var XML = "haxelib.xml";
	public static var DOCXML = "haxedoc.xml";
	public static var REPOSITORY = "files/3.0";
	public static var alphanum = ~/^[A-Za-z0-9_.-]+$/;
	static var LICENSES = ["GPL","LGPL","BSD","Public","MIT"];
	static var RESERVED_NAMES = ["haxe","all"];

	public static function safe( name : String ) {
		if( !alphanum.match(name) )
			throw "Invalid parameter : "+name;
		return name.split(".").join(",");
	}

	public static function unsafe( name : String ) {
		return name.split(",").join(".");
	}

	public static function fileName( lib : String, ver : String ) {
		return safe(lib)+"-"+safe(ver)+".zip";
	}

	public static function locateBasePath( zip : List<Entry> ) {
		for( f in zip ) {
			if( StringTools.endsWith(f.fileName,JSON) ) {
				return f.fileName.substr(0,f.fileName.length - JSON.length);
			}
		}
		throw "No "+JSON+" found";
	}

	public static function readDoc( zip : List<Entry> ) : String {
		for( f in zip )
			if( StringTools.endsWith(f.fileName,DOCXML) )
				return Reader.unzip(f).toString();
		return null;
	}

	public static function readInfos( zip : List<Entry>, check : Bool ) : Infos {
		var infodata = null;
		for( f in zip )
			if( StringTools.endsWith(f.fileName,JSON) ) {
				infodata = Reader.unzip(f).toString();
				break;
			}
		if( infodata == null )
			throw JSON + " not found in package";
		
		return readData(infodata,check);
	}

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

	static function doCheck( doc : Dynamic ) {
		if ( doc.name == null )
			throw 'Error: Library has no field `name` defined in JSON file.';
		var libName = doc.name.toLowerCase();
		if ( Lambda.indexOf(RESERVED_NAMES, libName) > -1 )
			throw 'Library name "${doc.name}" is reserved.  Please choose another name';
		if ( libName.endsWith(".zip") )
			throw 'Library name cannot end in ".zip".  Please choose another name';
		if ( libName.endsWith(".hxml") )
			throw 'Library name cannot end in ".hxml".  Please choose another name';
		if ( !alphanum.match(libName) )
			throw 'Library name can only contain the following characters: [A-Za-z0-9_.-]';
		if( libName.length < 3 )
			throw "Project name must contain at least 3 characters";
		if( Lambda.indexOf(LICENSES, doc.license) == -1 )
			throw "License must be one of the following: " + LICENSES;
		switch Type.typeof(doc.contributors) {
			case TNull: throw "At least one contributor must be included";
			//case TClass(String): doc.contributors = [doc.contributors];
			case TClass(Array): if (doc.contributors.length < 1) throw "At least one contributor must be included";
			default: throw 'invalid type for contributors';
		}
		switch Type.typeof(doc.version) {
			case TClass(String):
				SemVer.ofString(doc.version);
			default: throw 'version must be defined as string';
		}
		switch Type.typeof(doc.tags) {
			case TClass(Array):
				var tags:Array<Dynamic> = doc.tags;
				for (tag in tags) {
					switch Type.typeof(tag) {
						case TClass(String):
							if ( !alphanum.match(tag) )
								throw 'Invalid tag "$tag". Tags can only contain the following characters: [A-Za-z0-9_.-]';
							if ( tag.length < 2)
								throw 'Invalid tag "$tag". Tags must contain at least 2 characters';
						default: throw 'Invalid tag "$tag" Tags must be a String.';
					}
				}
			case TNull:
			default: throw 'tags must be defined as array';
		}
		switch Type.typeof(doc.classPath) {
			case TClass(String), TNull:
			default: throw 'classPath must be defined as string';
		}
		switch Type.typeof(doc.dependencies) {
			case TObject:
				for ( field in Reflect.fields(doc.dependencies) ) {
					var val = Reflect.field(doc.dependencies, field);
					switch Type.typeof(val) {
						case TClass(String):
							if ( val != "" ) {
								try {
									SemVer.ofString(val);
								} catch(e:String) {
									throw 'Dependency $field has an invalid version `$val`. Please use an empty string or a semver compliant string.';
								}
							}
						default: throw 'Dependency $field has an invalid version `$val`. Please use an empty string or a semver compliant string.';
					}
				}
			case TNull:
			default: throw 'dependencies must be defined as object';
		}
		switch Type.typeof(doc.releasenote) {
			case TClass(String):
			case TNull: throw 'no releasenote specified';
			default: throw 'releasenote should be string';
		}
	}

	public static function readData( jsondata: String, check : Bool ) : Infos {
		var doc = try Json.parse(jsondata) catch( e : Dynamic ) {};
		
		if( check )
			doCheck(doc);

		// The only time `doc.name` here is read, when it hasn't been validated by check, is 
		// when installing from a local zip file.  In this scenario, leaving an empty string 
		// will cause an error when the name gets passed to Data.safe(), preventing them from 
		// continuing.  If we're just reading it to grab dependencies, it doesn't matter if it 
		// is blank
		var project:String = (doc.name!=null) ? Std.string(doc.name) : "";

		var tags = new List();
		try {
			var tagsArray:Array<String> = doc.tags;
			for( t in tagsArray )
				tags.add( Std.string(t) );
		} catch(e:Dynamic) {}
		
		var devs = new List();
		try {
			var contributors:Array<String> = doc.contributors;
			for( c in contributors )
				devs.add( Std.string(c) );
		} catch(e:Dynamic) {}

		var deps = new List();
		try {
			for( d in Reflect.fields(doc.dependencies) ) {
				var version = try { 
					SemVer.ofString( Std.string(Reflect.field(doc.dependencies,d)) ).toString(); 
				} catch (e:Dynamic) "";
				deps.add({ project: d, version: version });
			}
		} catch(e:Dynamic) {}

		var website = ( doc.url!=null ) ? Std.string(doc.url) : "";
		var desc = ( doc.description!=null ) ? Std.string(doc.description) : "";
		var version = try SemVer.ofString(Std.string(doc.version)).toString() catch (e:Dynamic) "0.0.0";
		var versionComments = ( doc.releasenote!=null ) ? Std.string(doc.releasenote) : "";
		var license = ( doc.license!=null && doc.license!="" ) ? Std.string(doc.license) : "Unknown";
		var classPath = ( doc.classPath!=null ) ? Std.string(doc.classPath) : "";
		
		return {
			project : project,
			website : website,
			desc : desc,
			version : version,
			versionComments : versionComments,
			license : license,
			classPath : classPath,
			tags : tags,
			developers : devs,
			dependencies : deps
		};
	}

}
