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

@:enum abstract DependencyType(String) {
	var Haxelib = null;
	var Git = 'git';
}

typedef Dependency = {
	name : String, 
	?version : String,
	?type: DependencyType, //this should be an @:enum abstract,
	?url: String,
}

typedef Infos = {
	var name : String;
	var url : String;
	var description : String;
	var license : License;
	var version : String;
	@:optional var classPath : String;
	var releasenote : String;
	var contributors : Array<String>;
	@:optional var tags : Array<String>;
	@:optional var dependencies : Array<Dependency>;
	@:optional var main:String;
}

@:enum abstract License(String) to String {
	var Gpl = 'GPL';
	var Lgpl = 'LGPL';
	var Mit = 'MIT';
	var Bsd = 'BSD';
	var Public = 'Public';
}

class Data {

	public static var JSON = "haxelib.json";
	public static var XML = "haxelib.xml";
	public static var DOCXML = "haxedoc.xml";
	public static var REPOSITORY = "files/3.0";
	public static var alphanum = ~/^[A-Za-z0-9_.-]+$/;
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

	/**
		Return the directory that contains *haxelib.json*.
		If it is at the root, `""`.
		If it is in a folder, the path including a trailing slash is returned.
	*/
	public static function locateBasePath( zip : List<Entry> ):String {
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

	static function doCheck(doc:Infos) 
		return Validator.validate(doc);

	public static function readData( jsondata: String, check : Bool ) : Infos {
		var doc:Infos = 
			try Json.parse(jsondata) 
			catch ( e : Dynamic ) 
				if (check)
					throw 'JSON parse error: $e';
				else {
					name : 'unknown',
					url : '',
					version : '0.0.0',
					releasenote: 'No haxelib.json found',
					license: Mit,
					description: 'No haxelib.json found',
					contributors: [],
				}
		
		if (Type.typeof(doc.dependencies) == TObject) 
			if (check) {
				throw 'Dependency format has changed';
			}
			else
				doc.dependencies = [for (f in Reflect.fields(doc.dependencies)) {
					name: f,
					version: Reflect.field(doc.dependencies, f),
				}];
				
		if (check)
			doCheck(doc);
		
		if (doc.dependencies == null)
			doc.dependencies = [];//TODO: since the field is actually @:optional it might be better to handle nullness instead
			
		return doc;	
	}
}