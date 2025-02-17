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
package legacyhaxelib;

class User extends sys.db.Object {

	public static var manager = new sys.db.Manager<User>(User);

	public var id : Int;
	public var name : String;
	public var fullname : String;
	public var email : String;
	public var pass : String;

}

class Project extends sys.db.Object {

	public static var manager = new ProjectManager(Project);

	public var id : Int;
	public var name : String;
	public var description : String;
	public var website : String;
	public var license : String;
	public var downloads : Int;
	@:relation(owner) public var ownerObj:User;
	@:relation(version) public var versionObj:Version;

}

class Tag extends sys.db.Object {

	public static var manager = new TagManager(Tag);

	public var id : Int;
	public var tag : String;
	@:relation(project) public var projectObj : Project;

}

class Version extends sys.db.Object {

	public static var manager = new VersionManager(Version);

	public var id : Int;
	@:relation(project) public var projectObj : Project;
	public var name : String;
	public var date : String; // sqlite does not have a proper 'date' type
	public var comments : String;
	public var downloads : Int;
	public var documentation : Null<String>;

}

@:id(user, project)
class Developer extends sys.db.Object {

	public static var manager = new sys.db.Manager<Developer>(Developer);

	@:relation(user) public var userObj : User;
	@:relation(project) public var projectObj : Project;

}

class ProjectManager extends sys.db.Manager<Project> {

	public function containing( word ) : List<{ id : Int, name : String }> {
		word = quote("%"+word+"%");
		return cast sys.db.Manager.cnx.request("SELECT id, name FROM Project WHERE name LIKE "+word+" OR description LIKE "+word).results();
	}

	public function allByName() {
		return unsafeObjects("SELECT * FROM Project ORDER BY name COLLATE NOCASE",false);
	}

}

class VersionManager extends sys.db.Manager<Version> {

	public function latest( n : Int ) {
		return unsafeObjects("SELECT * FROM Version ORDER BY date DESC LIMIT "+n,false);
	}

	public function byProject( p : Project ) {
		return unsafeObjects("SELECT * FROM Version WHERE project = "+p.id+" ORDER BY date DESC",false);
	}

}

class TagManager extends sys.db.Manager<Tag> {

	public function topTags( n : Int ) {
		return cast sys.db.Manager.cnx.request("SELECT tag, COUNT(*) as count FROM Tag GROUP BY tag ORDER BY count DESC LIMIT "+n).results();
	}

}

class SiteDb {

	public static function dropAll( db : sys.db.Connection ) {
		db.request("DROP TABLE IF EXISTS User");
		db.request("DROP TABLE IF EXISTS Project");
		db.request("DROP TABLE IF EXISTS Version");
		db.request("DROP TABLE IF EXISTS Developer");
		db.request("DROP TABLE IF EXISTS Tag");
		db.request("DROP INDEX IF EXISTS TagSearch");
	}

	public static function create( db : sys.db.Connection ) {
		db.request("
			CREATE TABLE User (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				name VARCHAR(16) NOT NULL UNIQUE,
				fullname VARCHAR(50) NOT NULL,
				pass VARCHAR(32) NOT NULL,
				email VARCHAR(50) NOT NULL
			)
		");
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
		db.request("
			CREATE TABLE Developer (
				user INTEGER NOT NULL,
				project INTEGER NOT NULL
			)
		");
		db.request("
			CREATE TABLE Tag (
				id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
				tag VARCHAR(32) NOT NULL,
				project INTEGER NOT NULL
			)
		");
		db.request("CREATE INDEX TagSearch ON Tag(tag)");
	}
}
