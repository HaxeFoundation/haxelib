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

import haxe.xml.Check;

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

typedef XmlInfos = {
	var project : String;
	var website : String;
	var desc : String;
	var license : String;
	var version : String;
	var versionComments : String;
	var developers : List<String>;
	var tags : List<String>;
	var dependencies : List<{ project : String, version : String }>;
}

class Data {

	public static var XML = "haxelib.xml";
	public static var DOCXML = "haxedoc.xml";
	public static var REPOSITORY = "files";
	public static var alphanum = ~/^[A-Za-z0-9_.-]+$/;
	static var LICENSES = ["GPL","LGPL","BSD","Public","MIT"];

	static function requiredAttribute( x : Xml, name ) {
		var v = x.get(name);
		if( v == null )
			throw "Missing required attribute '"+name+"' in node "+x.nodeName;
		return v;
	}

	static function requiredNode( x : Xml, name ) {
		var v = x.elementsNamed(name).next();
		if( v == null )
			throw "Missing required node '"+name+"' in node "+x.nodeName;
		return v;
	}

	static function requiredText( x : Xml ) {
		var v = x.firstChild();
		if( v == null || (v.nodeType != Xml.PCData && v.nodeType != Xml.CData) )
			throw "Missing required text in node "+x.nodeName;
		return v.nodeValue;
	}

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

	public static function readDoc( zip : List<Entry> ) : String {
		for( f in zip )
			if( StringTools.endsWith(f.fileName,DOCXML) )
				return Reader.unzip(f).toString();
		return null;
	}

	public static function readInfos( zip : List<Entry>, check : Bool ) : XmlInfos {
		var xmldata = null;
		for( f in zip )
			if( StringTools.endsWith(f.fileName,XML) ) {
				xmldata = Reader.unzip(f).toString();
				break;
			}
		if( xmldata == null )
			throw XML+" not found in package";
		return readData(xmldata,check);
	}

	static function doCheck( doc : Xml ) {
		var sname = Att("name",FReg(alphanum));
		var schema = RNode(
			"project",
			[ sname, Att("url"), Att("license",FEnum(LICENSES)) ],
			RList([
				RMulti( RNode("user",[sname]), true ),
				RMulti( RNode("tag",[Att("v",FReg(alphanum))]) ),
				RNode("description",[],RData()),
				RNode("version",[sname],RData()),
				RMulti(	RNode("depends",[sname,Att("version",FReg(alphanum),"")]) ),
			])
		);
		haxe.xml.Check.checkDocument(doc,schema);
	}

	public static function readData( xmldata : String, check : Bool ) : XmlInfos {
		var doc = Xml.parse(xmldata);
		if( check )
			doCheck(doc);
		var p = new haxe.xml.Fast(doc).node.project;
		var project = p.att.name;
		if( project.length < 3 )
			throw "Project name must contain at least 3 characters";
		var tags = new List();
		for( t in p.nodes.tag )
			tags.add(t.att.v.toLowerCase());
		var devs = new List();
		for( d in p.nodes.user )
			devs.add(d.att.name);
		var deps = new List();
		for( d in p.nodes.depends )
			deps.add({ project : d.att.name, version : if( d.has.version ) d.att.version else "" });
		return {
			project : project,
			website : p.att.url,
			desc : p.node.description.innerData,
			version : p.node.version.att.name,
			versionComments : p.node.version.innerData,
			license : p.att.license,
			tags : tags,
			developers : devs,
			dependencies : deps,
		}
	}

}
