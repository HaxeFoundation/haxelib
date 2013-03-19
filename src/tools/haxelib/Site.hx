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

import haxe.web.Dispatch;
import neko.Lib;
import neko.Web;
import sys.db.RecordMacros;
import sys.io.File;
import tools.haxelib.SiteDb;
import haxe.rtti.CType;

class Site {

	static var db : sys.db.Connection;

	static var CWD = Web.getCwd();
	static var DB_FILE = CWD+"haxelib.db";
	public static var TMP_DIR = CWD+"tmp";
	public static var TMPL_DIR = CWD+"tmpl/";
	public static var REP_DIR = CWD+Data.REPOSITORY;

	static function setup() {
		SiteDb.create(db);
	}

	static function initDatabase() {
		db = sys.db.Sqlite.open(DB_FILE);
		sys.db.Manager.cnx = db;
		sys.db.Manager.initialize();
	}

	static function run() {
		
		if( !sys.FileSystem.exists(TMP_DIR) )
			sys.FileSystem.createDirectory(TMP_DIR);
		if( !sys.FileSystem.exists(REP_DIR) )
			sys.FileSystem.createDirectory(REP_DIR);
		
		
		var ctx = new haxe.remoting.Context();
		ctx.addObject("api", new SiteApi(db));
		
		if( haxe.remoting.HttpConnection.handleRequest(ctx) )
			return;
		
		if( Sys.args()[0] == "setup" ) {
			setup();
			neko.Lib.print("Setup done\n");
			return;
		}
		var file = null;
		var sid = null;
		var bytes = 0;
		
		//RAPTORS: the whole handling for nekotools is seriously evil
		if (Sys.executablePath().indexOf('nekotools') == -1)
			Web.parseMultipart(function(p,filename) {
				if( p == "file" ) {
					sid = Std.parseInt(filename);
					file = sys.io.File.write(TMP_DIR + "/" + sid + ".tmp", true);
				} else 
					throw p+" not accepted";
			},function(data,pos,len) {
				bytes += len;
				file.writeFullBytes(data,pos,len);
			});
		else {
			var post = Web.getPostData();
			if (post != null) {
				var index = post.indexOf('PK');
				if (index == -1)
					throw 'Invalid Zip - or so I claim';
					
				var start = post.substr(0, index);
				var data = post.substr(index);
				
				sid = Std.parseInt(start.split('filename="').pop());
				file = sys.io.File.write(TMP_DIR + "/" + sid + ".tmp", true);
				bytes = data.length;//thank got neko does not use utf8
				file.writeString(data);
			}
		}
		
		if( file != null ) {
			file.close();
			neko.Lib.print("File #"+sid+" accepted : "+bytes+" bytes written");
			return;
		}
		display();
	}

	static function getTemplate(name:String) {
		var data = File.getContent(TMPL_DIR + name + '.mtt');
		return new haxe.Template(data);
	}

	static function display() {
		
		var macros = {
			download : function( res, p, v ) {
				return "/"+Data.REPOSITORY+"/"+Data.fileName(res(p).name,res(v).name);
			}
		};

		// required by all templates
		haxe.Template.globals.menuTags = Tag.topTags(10);

		// render content into layout template
		var render = function(page:String, context:Dynamic) {
			var layout = getTemplate('layout');
			var content = getTemplate(page);
			Lib.print(layout.execute({
				content: content.execute(context, macros)
			}));
		}

		var error = function(msg:String) {
			render('error', {
				error: StringTools.htmlEscape(msg)
			});
		}

		var api = {

			// index page
			doDefault: function() {
				var vl = Version.latest(10);
				for( v in vl ) {
					var p = v.project; // fetch
				}
				return render('index', {
					versions: vl
				});
			},

			// project page
			doP: function(name:String) {
				var p = Project.manager.select({ name : name });
				if( p == null )
					return error("Unknown project '"+name+"'");
				return render('project', {
					p: p,
					owner: p.owner,
					version: p.version,
					versions: Version.byProject(p),
					tags: Tag.manager.search({ project : p.id })
				});
			},

			// user page
			doU: function(name:String) {
				var u = User.manager.select({ name : name });
				if( u == null )
					return error("Unknown user '"+name+"'");
				return render('user', {
					u: u,
					uprojects: Developer.manager.search({ user : u.id }).map(function(d:Developer) { return d.project; })
				});
			},

			// tag page
			doT: function(tagName: String) {
				render('tag', {
					tag: StringTools.htmlEscape(tagName),
					tprojects: Tag.manager.search({ tag : tagName }).map(function(t) return t.project)
				});
			},

			// list of all projects page
			doAll: function() {
				render('list', {
					projects: Project.allByName()
				});
			},

			// documenation
			doD: function(name:String, version:Null<String>) {
				return error('Library documenation display is currently not implemented');
				/*
				// TODO: the current project does not allow uploads with documenation, this ported, but not tested
				var ctx:Dynamic = {};
				var p = Project.manager.select({ name : name });
				if( p == null )
					return error("Unknown project '"+name+"'");
				var v;
				if( version == null ) {
					v = p.version;
					version = v.name;
				} else {
					v = Version.manager.select( { project : p.id, name : version } );
					if( v == null ) return error("Unknown version '"+version+"'");
				}
				if( v.documentation == null )
					return error("Project "+p.name+" version "+version+" has no documentation");
				var root : TypeRoot = haxe.Unserializer.run(v.documentation);
				var buf = new StringBuf();
				var html = new tools.haxedoc.HtmlPrinter("/d/"+p.name+"/"+version+"/","","");
				html.output = function(str) buf.add(str);
				var path = uri.join(".").toLowerCase().split(".");
				if( path.length == 1 && path[0] == "" )
					path = [];
				if( path.length == 0 ) {
					ctx.index = true;
					html.process(TPackage("root","root",root));
				} else {
					var cl = html.find(root,path,0);
					if( cl == null ) {
						// we most likely clicked on a class which is part of the haxe core documentation
						Web.redirect("http://haxe.org/api/"+path.join("/"));
						return false;
					}
					html.process(cl);
				}
				ctx.p = p;
				ctx.v = v;
				ctx.content = buf.toString();
				return render('documentation', {});
				*/
			},

			// search
			doSearch: function() {
				var v = Web.getParams().get("v");
				var p = Project.manager.select({ name : v });
				if( p != null ) {
					return Web.redirect("/p/"+p.name);
				}
				if( Tag.manager.count({ tag : v }) > 0 ) {
					return Web.redirect("/t/"+v);
				}
				return render('list', {
					search: StringTools.htmlEscape(v),
					projects: Project.containing(v).map(function(p) return Project.manager.get(p.id))
				});
			},

			// RSS feed
			doRss: function() {
				Web.setHeader("Content-Type", "text/xml; charset=UTF-8");
				Lib.println('<?xml version="1.0" encoding="UTF-8"?>');
				Lib.print(buildRss().toString());
			}
		};
		try {
			Dispatch.run(Web.getURI(),Web.getParams(), api);
		}
		catch (e:DispatchError) {
			// TODO: maybe we could give a nicer error message
			error('Invalid URL');
		}

	}
	static function buildRss() : Xml {
		var createChild = function(root:Xml, name:String){
			var c = Xml.createElement(name);
			root.addChild(c);
			return c;
		}
		var createChildWithContent = function(root:Xml, name:String, content:String){
			var e = Xml.createElement(name);
			var c = Xml.createPCData(if (content != null) content else "");
			e.addChild(c);
			root.addChild(e);
			return e;
		}
		var createChildWithCdata = function(root:Xml, name:String, content:String){
			var e = Xml.createElement(name);
			var c = Xml.createCData(if (content != null) content else "");
			e.addChild(c);
			root.addChild(e);
			return e;
		}
		Sys.setTimeLocale("en_US.UTF8");
		var url = "http://"+Web.getClientHeader("Host");
		var rss = Xml.createElement("rss");
		rss.set("version","2.0");
		var channel = createChild(rss, "channel");
		createChildWithContent(channel, "title", "haxe-libs");
		createChildWithContent(channel, "link", url);
		createChildWithContent(channel, "description", "lib.haxe.org RSS");
		createChildWithContent(channel, "generator", "haxe");
		createChildWithContent(channel, "language", "en");
		for (v in Version.latest(10)){
			var project = v.project;
			var item = createChild(channel, "item");
			createChildWithContent(item, "title", StringTools.htmlEscape(project.name+" "+v.name));
			createChildWithContent(item, "link", url+"/p/"+project.name);
			createChildWithContent(item, "guid", url+"/p/"+project.name+"?v="+v.id);
			var date = DateTools.format(Date.fromString(v.date), "%a, %e %b %Y %H:%M:%S %z");
			createChildWithContent(item, "pubDate", date);
			createChildWithContent(item, "author", project.owner.name);
			createChildWithContent(item, "description", StringTools.htmlEscape(v.comments));
		}
		return rss;
	}

	static function main() {
		var error = null;
		initDatabase();
		try {
			run();
		} catch( e : Dynamic ) {
			error = { e : e };
		}
		db.close();
		sys.db.Manager.cleanup();
		if( error != null )
			neko.Lib.rethrow(error.e);
	}

}
