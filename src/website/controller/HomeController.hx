package website.controller;

import ufront.MVC;
import ufront.ufadmin.controller.*;
import website.api.*;
import website.model.SiteDb;
import haxelib.server.FileStorage;
import haxe.io.*;
using StringTools;
using tink.CoreApi;
using CleverSort;

class HomeController extends Controller {

	@inject public var projectApi:ProjectApi;
	@inject public var projectListApi:ProjectListApi;
	@inject public var userApi:UserApi;

	// Perform init() after dependency injection has occured.
	@inject public function init( ctx:HttpContext ) {
		// All MVC actions come through HomeController (our index controller) first, so this is a good place to set global template variables.
		var r = ctx.request;
		var url = 'https://'+r.hostName+r.uri;
		if ( r.queryString!="" ) {
			url += '?'+r.queryString;
		}
		ViewResult.globalValues.set( "useWrapper", true );
		ViewResult.globalValues.set( "pageUrl", url );
		ViewResult.globalValues.set( "currentPage", r.uri );
		ViewResult.globalValues.set( "todaysDate", Date.now() );
		ViewResult.globalValues.set( "documentationPages", DocumentationController.getDocumentationPages() );
		ViewResult.globalValues.set( "description", "Haxe is an open source toolkit based on a modern, high level, strictly typed programming language." );
		ViewResult.globalValues.set( "searchTerm", ctx.session.get('searchTerm') );
		ViewResult.globalValues.set( "escape", Util.escape);
		ViewResult.globalValues.set( "formatDate", Util.formatDate);
		ViewResult.globalValues.set( "extension", Path.extension);
		ViewResult.globalValues.set( "min", Math.min);
		ViewResult.globalValues.set( "max", Math.max);
	}

	@:route("/")
	public function homepage() {
		var allProjects =  projectListApi.all().sure();
		
		var latestProjects =  projectListApi.latest( 12 * 3 ).sure() ;
		var popularProjects = prepareProjectList( projectListApi.all().sure() );
		var users = userApi.getUserList().sure();
		var tags = projectListApi.getTagList( 25 ).sure();
		
		var hasRecentProject = new Map<String, Bool>();
		latestProjects = [for (p in latestProjects) {
			if (p.p !=null && !hasRecentProject.exists(p.p.name)) {
				hasRecentProject.set(p.p.name, true);
				p;
			}
		}];
		
		return new ViewResult({
			title: "Haxelib - the Haxe package manager",
			description: "Haxelib is a tool that enables sharing libraries and code in the Haxe ecosystem.",
			pageUrl: context.request.uri,
			latestProjects: function(offset:Int, total:Int) return [for (i in offset...offset+total) latestProjects[i]],
			popularProjects: function(offset:Int, total:Int) return [for (i in offset...offset+total) popularProjects[i]],
			users: function(offset:Int, total:Int) return [for (i in offset...offset+total) users[i]],
			
			tags: tags,
			exampleCode: CompileTime.readFile( "website/homepage-example.txt" ),
			useWrapper: false,
		});
	}

	@:route("/p/*")
	public var projectController:ProjectController;

	@:route("/recent/")
	public function recent() {
		var latestProjects =  projectListApi.latest( 100 ).sure();
		
		latestProjects = [for (p in latestProjects) if (p.p != null ) p];
		
		return new ViewResult({
			title: "Recent updates - the Haxe package manager",
			description: "List of the most recent changes of Haxe libraries.",
			projects: latestProjects,
		});
	}

	@:route("/u/*")
	public var userController:UserController;

	@:route("/rss/")
	public var rssController:RSSController;

	@:route("/documentation/*")
	public var documentationController:DocumentationController;

	/**
		`/files` is backed by a `FileStorage`.
		In production, it should be routed by httpd to S3 using mod_proxy, thus
		this function should never be called.
	*/
	@:route("/files/3.0/$fileName")
	public function downloadFile( fileName:String ) {
		return FileStorage.instance.readFile(
			'files/3.0/$fileName',
			function(path) {
				var r = new FilePathResult(path);
				r.setContentTypeByFilename(Path.withoutDirectory(path));
				return r;
			}
		);
	}

	@cacheRequest
	@:route("/t/")
	public function tagList():ViewResult {
		var tagList = projectListApi.getTagList( 50 ).sure();

		// Build a tag cloud.
		var least = null,
		    most = null,
		    minSize = 10,
		    maxSize = 140;
		for (t in tagList) {
			if ( least==null || t.count<least )
				least = t.count;
			if ( most==null || t.count>most )
				most = t.count;
		}
		function fontSizeForCount( count:Int ) {
			var countRange = most - least;
			var sizeRange = maxSize-minSize;
			var pos = (count - least) / countRange;
			return minSize + pos*sizeRange;
		}
		var tagCloud = [for (t in tagList) { tag:t.tag, size:fontSizeForCount(t.count) }];
		tagCloud.cleverSort( _.tag );

		return new ViewResult({
			title: 'Haxelib Tags',
			description: 'Projects of popular tags on Haxelib',
			tags: tagList,
			tagCloud: tagCloud,
			taggedProjects: function(tagName:String, offset:Int, total:Int) {
				var projects = prepareProjectList( projectListApi.byTag( tagName ).sure() );
				return [for (i in offset...offset + total) projects[i]];
			}
		});
	}

	// TODO: get ufront-mvc to support `/t/$tagName` and `/t/$tagName.json` as different routes.
	@cacheRequest
	@:route("/t/$tagName")
	public function tag( tagName:String ):ActionResult {
		if ( tagName.endsWith(".json") ) {
			return tagJson( tagName.substr(0,tagName.length-5) );
		}
		else {

			var list = prepareProjectList( projectListApi.byTag( tagName ).sure() );
			return new ViewResult({
				title: 'Tag: $tagName',
				icon: 'fa-tag',
				currentTag: tagName,
				tags: projectListApi.getTagList( 50 ).sure(),
				description: 'A list of all projects on Haxelib with the tag "$tagName"',
				projects: list,
			}, "tagProjectList.html");
		}
	}

	@cacheRequest
	@:route("/all")
	public function all() {
		var list = prepareProjectList( projectListApi.all().sure() );
		return new ViewResult({
			title: 'All Haxelibs',
			icon: 'fa-star',
			description: 'A list of every project uploaded on haxelib, sorted by popularity',
			projects: list,
		}, "projectList.html");
	}

	@:route("/search")
	public function search( ?args:{ v:String } ) {
		var result = new ViewResult();
		if ( args.v==null || args.v.length==0 ) {
			result.setVars({
				title: 'Search Haxelib',
				description: 'Search Haxelib project names and descriptions',
				searchTerm: "",
				projects: null
			});
		}
		else {
			context.session.set( 'searchTerm', args.v );
			var list = prepareProjectList( projectListApi.search( args.v ).sure() );
			result.setVars({
				title: 'Search for "${args.v}"',
				description: 'Haxelib projects that match the search word "${args.v}"',
				projects: list,
				searchTerm: args.v,
			});
		}
		return result;
	}

	static function prepareProjectList( list:Array<Project> ):Array<{ name:String, user:User, author:String, description:String, version:Version, downloads:Int }> {
		return [for (p in list) if (p != null && p.ownerObj != null && p.versionObj != null) {
			name: p.name,
			user: p.ownerObj,
			author: p.ownerObj.name,
			description: p.description,
			version: p.versionObj,
			downloads: p.downloads,
		}];
	}

	@:route("/search.json")
	public function searchJson( args:{ v:String } )
		return new JsonResult( projectListApi.search(args.v).sure() );

	@cacheRequest
	@:route("/all.json")
	public function allJson()
		return new JsonResult( projectListApi.all().sure() );

	@:route("/ufadmin/*")
	public function ufadmin() {
		return executeSubController( UFAdminHomeController );
	}

	public function tagJson( tagName:String )
		return new JsonResult( projectListApi.byTag(tagName).sure() );
}
