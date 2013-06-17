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
import haxe.io.Bytes;
import tools.haxelib.Data;
import tools.haxelib.Paths.*;
import tools.haxelib.SiteDb;
import neko.Web;
import tools.haxelib.SemVer;

class Repo implements SiteApi {

	static function run() {
		if( !sys.FileSystem.exists(TMP_DIR) )
			sys.FileSystem.createDirectory(TMP_DIR);
		if( !sys.FileSystem.exists(REP_DIR) )
			sys.FileSystem.createDirectory(REP_DIR);
		
		var ctx = new haxe.remoting.Context();
		ctx.addObject("api", new Repo());
		
		if( haxe.remoting.HttpConnection.handleRequest(ctx) )
			return;
		else 
			throw "Invalid remoting call";
	}
	
	public function new() {}

	public function search( word : String ) : List<{ id : Int, name : String }> {
		return Project.containing(word);
	}

	public function infos( project : String ) : ProjectInfos {
		var p = Project.manager.select($name == project);
		if( p == null )
			throw "No such Project : "+project;
		var vl = Version.manager.search($project == p.id);
		var versions = new Array();
		for( v in vl )
			versions.push({ name : v.toSemver().toString(), comments : v.comments, date : v.date });
		return {
			name : p.name,
			curversion : if( p.version == null ) null else p.version.toSemver().toString(),
			desc : p.description,
			versions : versions,
			owner : p.owner.name,
			website : p.website,
			license : p.license,
			tags : Tag.manager.search($project == p.id).map(function(t) return t.tag),
		};
	}

	public function user( name : String ) : UserInfos {
		var u = User.manager.search($name == name).first();
		if( u == null )
			throw "No such user : "+name;
		var pl = Project.manager.search($owner == u.id);
		var projects = new Array();
		for( p in pl )
			projects.push(p.name);
		return {
			name : u.name,
			fullname : u.fullname,
			email : u.email,
			projects : projects,
		};
	}

	public function register( name : String, pass : String, mail : String, fullname : String ) : Bool {
		if( !Data.alphanum.match(name) )
			throw "Invalid user name, please use alphanumeric characters";
		if( name.length < 3 )
			throw "User name must be at least 3 characters";
		var u = new User();
		u.name = name;
		u.pass = pass;
		u.email = mail;
		u.fullname = fullname;
		u.insert();
		return null;
	}

	public function isNewUser( name : String ) : Bool {
		return User.manager.select($name == name) == null;
	}

	public function checkDeveloper( prj : String, user : String ) : Void {
		var p = Project.manager.search({ name : prj }).first();
		if( p == null )
			return;
		for( d in Developer.manager.search({ project : p.id }) )
			if( d.user.name == user )
				return;
		throw "User '"+user+"' is not a developer of project '"+prj+"'";
	}

	public function checkPassword( user : String, pass : String ) : Bool {
		var u = User.manager.search({ name : user }).first();
		return u != null && u.pass == pass;
	}

	public function getSubmitId() : String {
		return Std.string(Std.random(100000000));
	}
	
	public function processSubmit( id : String, user : String, pass : String ) : String {
		var path = TMP_DIR+"/"+Std.parseInt(id)+".tmp";
		
		var file = try sys.io.File.read(path,true) catch( e : Dynamic ) throw "Invalid file id #"+id;
		var zip = try haxe.zip.Reader.readZip(file) catch( e : Dynamic ) { file.close(); neko.Lib.rethrow(e); };
		file.close();

		var infos = Data.readInfos(zip,true);
		var u = User.manager.search({ name : user }).first();
		if( u == null || u.pass != pass )
			throw "Invalid username or password";

		var devs = infos.developers.map(function(user) {
			var u = User.manager.search({ name : user }).first();
			if( u == null )
				throw "Unknown user '"+user+"'";
			return u;
		});

		var tags = Lambda.array(infos.tags);
		tags.sort(Reflect.compare);

		var p = Project.manager.search({ name : infos.project }).first();

		// create project if needed
		if( p == null ) {
			p = new Project();
			p.name = infos.project;
			p.description = infos.desc;
			p.website = infos.website;
			p.license = infos.license;
			p.owner = u;
			p.insert();
			for( u in devs ) {
				var d = new Developer();
				d.user = u;
				d.project = p;
				d.insert();
			}
			for( tag in tags ) {
				var t = new Tag();
				t.tag = tag;
				t.project = p;
				t.insert();
			}
		}

		// check submit rights
		var pdevs = Developer.manager.search({ project : p.id });
		var isdev = false;
		for( d in pdevs )
			if( d.user.id == u.id ) {
				isdev = true;
				break;
			}
		if( !isdev )
			throw "You are not a developer of this project";

		var otags = Tag.manager.search({ project : p.id });
		var curtags = otags.map(function(t) return t.tag).join(":");

		// update public infos
		if( infos.desc != p.description || p.website != infos.website || p.license != infos.license || pdevs.length != devs.length || tags.join(":") != curtags ) {
			if( u.id != p.owner.id )
				throw "Only project owner can modify project infos";
			p.description = infos.desc;
			p.website = infos.website;
			p.license = infos.license;
			p.update();
			if( pdevs.length != devs.length ) {
				for( d in pdevs )
					d.delete();
				for( u in devs ) {
					var d = new Developer();
					d.user = u;
					d.project = p;
					d.insert();
				}
			}
			if( tags.join(":") != curtags ) {
				for( t in otags )
					t.delete();
				for( tag in tags ) {
					var t = new Tag();
					t.tag = tag;
					t.project = p;
					t.insert();
				}
			}
		}
		
		// look for current version
		var current = null;
		for( v in Version.manager.search({ project : p.id }) )
			if( v.name == infos.version ) {
				current = v;
				break;
			}		

		// update documentation
		var doc = null;
		var docXML = Data.readDoc(zip);
		if( docXML != null ) {
			try {
				var p = new haxe.rtti.XmlParser();
				p.process(Xml.parse(docXML).firstElement(),null);
				p.sort();
				var roots = new Array();
				for( x in p.root )
					switch( x ) {
					case TPackage(name,_,_):
						switch( name ) {
						case "flash","flash8","sys","cs","java","flash9","haxe","js","neko","cpp","php","tools": // don't include haXe core types
						default: roots.push(x);
						}
					default:
						// don't include haXe root types
					}
				var s = new haxe.Serializer();
				s.useEnumIndex = true;
				s.useCache = true;
				s.serialize(roots);
				doc = s.toString();
			} catch ( e:Dynamic ) {
				// If documentation can't be generated, ignore it.
			}
		}

		// update file
		var target = REP_DIR + "/" + Data.fileName(p.name, infos.version);
		sys.FileSystem.rename(path,target);
		var semVer = SemVer.ofString(infos.version);
		
		// update existing version
		if( current != null ) {
			current.documentation = doc;
			current.comments = infos.versionComments;
			current.update();
			return "Version "+current.name+" (id#"+current.id+") updated";
		}
		
		// add new version
		var v = new Version();
		v.project = p;
		v.major = semVer.major;
		v.minor = semVer.minor;
		v.patch = semVer.patch;
		v.preview = semVer.preview;
		v.previewNum = semVer.previewNum;
		
		v.comments = infos.versionComments;
		v.downloads = 0;
		v.date = Date.now().toString();
		v.documentation = doc;
		v.insert();

		p.version = v;
		p.update();
		return "Version " + v.toSemver().toString() + " (id#" + v.id + ") added";
	}

	public function postInstall( project : String, version : String ) {
		var p = Project.manager.select($name == project);
		if( p == null )
			throw "No such Project : " + project;
			
		var version = SemVer.ofString(version);
		var v = Version.manager.select(
			$project == p.id && 
			$major == version.major && 
			$minor == version.minor && 
			$patch == version.patch && 
			$preview == version.preview && 
			$previewNum == version.previewNum
		);
		if( v == null )
			throw "No such Version : " + version;
		v.downloads++;
		v.update();
		p.downloads++;
		p.update();
	}

	static function main() {
		var error = null;
		SiteDb.init();
		try {
			run();
		} catch( e : Dynamic ) {
			error = { e : e };
		}
		SiteDb.cleanup();
		if( error != null )
			neko.Lib.rethrow(error.e);
	}

}