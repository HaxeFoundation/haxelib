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
	@:relation(version) public var version : Version;
	
	static public function containing( word ) : List<{ id : Int, name : String }> {
		//TODO: the cast could be avoided by changing the return type to iterable. Same problem at the next cast
		return cast Manager.cnx.request("SELECT id, name FROM Project WHERE name LIKE " + word + " OR description LIKE " + word).results();
	}

	static public function allByName() {
		//TODO: review. Unless I am mistaken, there is no way to express COLLATE NOCASE yet
		return manager.unsafeObjects("SELECT * FROM Project ORDER BY name COLLATE NOCASE", false);
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
	public var name : String;
	public var date : String; // sqlite does not have a proper 'date' type
	public var comments : String;
	public var downloads : Int;
	public var documentation : Null<String>;
	
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

	public static function create( db : sys.db.Connection ) {
		//TODO: set the exact field types and use TableCreate here
		db.request("DROP TABLE IF EXISTS User");
		db.request("
			CREATE TABLE User (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				name VARCHAR(16) NOT NULL UNIQUE,
				fullname VARCHAR(50) NOT NULL,
				pass VARCHAR(32) NOT NULL,
				email VARCHAR(50) NOT NULL
			)
		");
		db.request("DROP TABLE IF EXISTS Project");
		db.request("
			CREATE TABLE Project (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				owner INTEGER NOT NULL,
				name VARCHAR(32) NOT NULL UNIQUE,
				license VARCHAR(20) NOT NULL,
				description TEXT NOT NULL,
				website VARCHAR(100) NOT NULL,
				version INT,
				downloads INT NOT NULL
			)
		");
		db.request("DROP TABLE IF EXISTS Version");
		db.request("
			CREATE TABLE Version (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				project INTEGER NOT NULL,
				downloads INTEGER NOT NULL,
				date VARCHAR(19) NOT NULL,
				name VARCHAR(32) NOT NULL,
				comments TEXT NOT NULL,
				documentation TEXT NULL
			)
		");
		db.request("DROP TABLE IF EXISTS Developer");
		db.request("
			CREATE TABLE Developer (
				user INTEGER NOT NULL,
				project INTEGER NOT NULL
			)
		");
		db.request("DROP TABLE IF EXISTS Tag");
		db.request("
			CREATE TABLE Tag (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				tag VARCHAR(32) NOT NULL,
				project INTEGER NOT NULL
			)
		");
		db.request("DROP INDEX IF EXISTS TagSearch");
		db.request("CREATE INDEX TagSearch ON Tag(tag)");
	}
}
