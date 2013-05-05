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

import sys.db.*;
import sys.db.Types;
import tools.haxelib.Paths.*;
using sys.io.File;
using sys.FileSystem;

class User extends Object {

	public var id : SId;
	public var name : String;
	public var fullname : String;
	public var email : String;
	public var pass : String;

}

class Project extends Object {

	public var id : SId;
	public var name : String;
	public var description : String;
	public var website : String;
	public var license : String;
	public var downloads : Int = 0;
	@:relation(owner) public var owner : User;
	@:relation(version) public var version : SNull<Version>;
	
	static public function containing( word:String ) : List<{ id: Int, name: String }> {
		var ret = new List();
		word = '%$word%';
		for (project in manager.search($name.like(word) || $description.like(word)))
			ret.push( { id: project.id, name: project.name } );
		return ret;
	}

	static public function allByName() {
		//TODO: Propose SPOD patch to support manager.search(true, { orderBy: name.toLowerCase() } );
		return manager.unsafeObjects('SELECT * FROM Project ORDER BY LOWER(name)', false);
	}

}

class Tag extends Object {

	public var id : SId;
	public var tag : String;
	@:relation(project) public var project : Project;
	
	static public function topTags( n : Int ) : List<{ tag:String, count: Int }> {
		return cast Manager.cnx.request("SELECT tag, COUNT(*) as count FROM Tag GROUP BY tag ORDER BY count DESC LIMIT " + n).results();
	}

}

class Version extends Object {

	public var id : SId;
	@:relation(project) public var project : Project;
	public var major : Int;
	public var minor : Int;
	public var patch : Int;
	@:nullable public var preview : SEnum<SemVer.Preview>;
	public var previewNum : SNull<Int>;
	@:skip public var name(get, never):String;
	function get_name() return toSemver().toString();
	
	public function toSemver():SemVer {
		return new SemVer(
			major,
			minor,
			patch,
			preview,
			previewNum
		);
	}
	public var date : String; // sqlite does not have a proper 'date' type
	public var comments : String;
	public var downloads : Int;
	public var documentation : SNull<String>;
	
	static public function latest( n : Int ) {
		return manager.search(true, { orderBy: -date, limit: n } );
	}

	static public function byProject( p : Project ) {
		return manager.search($project == p.id, { orderBy: -date } );
	}

}

@:id(user,project)
class Developer extends Object {
	
	@:relation(user) public var user : User;
	@:relation(project) public var project : Project;

}

class SiteDb {
	static var db : Connection;
	//TODO: this whole configuration business is rather messy to say the least
	
	static public function init() {
		db = 
			if (DB_CONFIG.exists()) 
				Mysql.connect(haxe.Json.parse(DB_CONFIG.getContent()));
			else 
				Sqlite.open(DB_FILE);
				
		Manager.cnx = db;
		Manager.initialize();
		
		var managers:Array<Manager<Dynamic>> = [
			User.manager,
			Project.manager,
			Tag.manager,
			Version.manager,
			Developer.manager
		];
		for (m in managers)
			if (!TableCreate.exists(m))
				TableCreate.create(m);		
	}
	static public function cleanup() {
		db.close();
		Manager.cleanup();
	}
	public static function create( db : sys.db.Connection ) {
		//now based on TableCreate when establishing the connection
	}
}
