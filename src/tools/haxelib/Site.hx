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
import sys.db.*;
import sys.io.File;
import tools.haxelib.SiteDb;
import haxe.rtti.CType;
import haxe.Json;
import tools.haxelib.Paths.*;

using sys.io.File;
using sys.FileSystem;
using Lambda;

class Site {
	static function setup() {}//obsolete

	static function run() {
		
		if( !sys.FileSystem.exists(TMP_DIR) )
			sys.FileSystem.createDirectory(TMP_DIR);
		if( !sys.FileSystem.exists(REP_DIR) )
			sys.FileSystem.createDirectory(REP_DIR);
		
		if( Sys.args()[0] == "setup" ) {
			setup();
			Sys.print("Setup done\n");
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
			Sys.print("File #"+sid+" accepted : "+bytes+" bytes written");
			return;
		}
		display();
	}
	
	static function getTemplate(name:String) {
		var data = File.getContent(TMPL_DIR + name + '.mtt');
		return new Template(data);
	}
	static var macros = {
		download : function( res:String->Dynamic, p, v ) {
			return "/" + Data.REPOSITORY + "/" + Data.fileName(res(p).name, res(v).toSemver().toString());
		},
	};

	static function display() {		

		// required by all templates
		haxe.Template.globals.menuTags = Tag.topTags(10);

		var uri = Web.getURI();
		if (uri == "/index.n") uri = "/";
		var jsonRegex = ~/\/(p|u|t|all)\/?([^\/\.]*)?\.json/;
		if(jsonRegex.match(uri)) {
			var second = jsonRegex.matched(2);
			var hasSecond = second != null && second.length > 0;
			uri = "/"+jsonRegex.matched(1)+"json/"+(hasSecond ? second+"/" : "");
		}
		try {
			Dispatch.run(uri,Web.getParams(), Site);
		}
		catch (e:DispatchError) {
			// TODO: maybe we could give a nicer error message
			error('Page not found:' + uri);
		}

	}
	static function error(msg:String) {
		render('error', {
			error: StringTools.htmlEscape(msg),
			legacyurl: "/legacy"+Web.getURI()
		});
	}
	// render content into layout template
	static function render(page:String, context:Dynamic) {
		var layout = getTemplate('layout');
		var content = getTemplate(page);
		Sys.print(layout.execute({
			content: content.execute(context, macros),
			site: neko.Web.getHostName()
		}));
	}	
	// index page
	static function doDefault() {
		var vl = Version.latest(10);
		for( v in vl ) {
			var p = v.project; // fetch
		}
		return render('index', {
			versions: vl
		});
	}

	// project page
	static function doP(name:String) {
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
	}

	// project JSON page
	static function doPjson(name:String) {
		var p = Project.manager.select({ name : name });
		var obj:Dynamic = null;
		if(p == null)
			obj = {err: "Unknown project '"+name+"'"}
		else
			obj = {
				owner: p.owner,
				version: p.version,
				versions: Lambda.array(Version.byProject(p)),
				tags: Tag.manager.search({ project : p.id })
			};
		printJson(obj);
	}
	// user page
	static function doU(name:String) {
		var u = User.manager.select({ name : name });
		if( u == null )
			return error("Unknown user '"+name+"'");
		return render('user', {
			u: u,
			uprojects: Developer.manager.search({ user : u.id }).map(function(d:Developer) { return d.project; })
		});
	}

	// user JSON page
	static function doUjson(name:String) {
		var u = User.manager.select({ name : name });
		var obj:Dynamic = null;
		if(u == null)
			obj = {err: "Unknown user '"+name+"'"}
		else
			obj = {
				name: name,
				projects: Lambda.array(Developer.manager.search({ user : u.id }).map(function(d:Developer) { return d.project; }))
			};
		printJson(obj);
	}

	// tag page
	static function doT(tagName: String) {
		render('tag', {
			tag: StringTools.htmlEscape(tagName),
			tprojects: Tag.manager.search({ tag : tagName }).map(function(t) return t.project)
		});
	}

	// tag JSON page
	static function doTjson(tagName: String) {
		var obj = {
			tag: tagName,
			projects: Lambda.array(Tag.manager.search({ tag : tagName }).map(function(t) return t.project))
		};
		printJson(obj);
	}

	// list of all projects page
	static function doAll() {
		render('list', {
			projects: Project.allByName()
		});
	}
	// list of all projects JSON page
	static function doAlljson() {
		var obj = {
			projects: Lambda.array(Project.allByName())
		};
		printJson(obj);
	}

	// documenation
	static function doD(name:String, version:Null<String>) {
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
	}

	// search
	static function doSearch() {
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
	}

	// RSS feed
	static function doRss() {
		Web.setHeader("Content-Type", "text/xml; charset=UTF-8");
		Sys.println('<?xml version="1.0" encoding="UTF-8"?>');
		Sys.print(buildRss().toString());
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
		var num = 50;
		rss.set("version","2.0");
		var channel = createChild(rss, "channel");
		createChildWithContent(channel, "title", 'Latest haxelib releases (${neko.Web.getHostName()})');
		createChildWithContent(channel, "link", url);
		createChildWithContent(channel, "description", 'The $num latest haxelib releases on ${neko.Web.getHostName()}');
		createChildWithContent(channel, "generator", "haxe");
		createChildWithContent(channel, "language", "en");
		for (v in Version.latest(num)){
			var project = v.project;
			var item = createChild(channel, "item");
			createChildWithContent(item, "title", StringTools.htmlEscape(project.name + " " + v.toSemver()));
			createChildWithContent(item, "link", url+"/p/"+project.name);
			createChildWithContent(item, "guid", url+"/p/"+project.name+"?v="+v.id);
			var date = DateTools.format(Date.fromString(v.date), "%a, %e %b %Y %H:%M:%S %z");
			createChildWithContent(item, "pubDate", date);
			createChildWithContent(item, "author", project.owner.name);
			createChildWithContent(item, "description", StringTools.htmlEscape(v.comments));
		}
		return rss;
	}
	// print a JSON object and wrap it if there is a callback parameter
	static function printJson(obj:Dynamic) {
		var callback = Web.getParams().get("callback");
		Web.setHeader("Content-Type", callback == null ? "application/json" : "application/javascript");
		if(callback != null)
			Sys.print(callback + "(");
		Sys.print(haxe.Json.stringify(obj));
		if(callback != null)
			Sys.print(")");
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
			Lib.rethrow(error.e);
	}

}
