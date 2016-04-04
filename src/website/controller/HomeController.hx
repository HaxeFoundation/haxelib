package website.controller;

import ufront.MVC;
import ufront.ufadmin.controller.*;
import website.api.ProjectListApi;
import website.model.SiteDb;
using StringTools;
using tink.CoreApi;
using CleverSort;

class HomeController extends Controller {

	@inject public var projectListApi:ProjectListApi;

	// Perform init() after dependency injection has occured.
	@inject public function init( ctx:HttpContext ) {
		// All MVC actions come through HomeController (our index controller) first, so this is a good place to set global template variables.
		var r = ctx.request;
		var url = 'http://'+r.hostName+r.uri;
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
	}

	@:route("/")
	public function homepage() {
		var latestProjects = projectListApi.latest( 10 ).sure();
		var tags = projectListApi.getTagList( 10 ).sure();
		return new ViewResult({
			title: "Haxelib - the Haxe package manager",
			description: "Haxelib is a tool that enables sharing libraries and code in the Haxe ecosystem.",
			pageUrl: context.request.uri,
			latestProjects: latestProjects,
			tags: tags,
			exampleCode: CompileTime.readFile( "website/homepage-example.txt" ),
			useWrapper: false,
		});
	}

	@:route("/p/*")
	public var projectController:ProjectController;

	@:route("/u/*")
	public var userController:UserController;

	@:route("/rss/")
	public var rssController:RSSController;

	@:route("/documentation/*")
	public var documentationController:DocumentationController;

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
			description: 'The 50 most popular tags for projects on Haxelib, sorted by the number of projects',
			tags: tagList,
			tagCloud: tagCloud,
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
				description: 'A list of all projects on Haxelib with the tag "$tagName"',
				projects: list,
			}, "projectList.html");
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

	static function prepareProjectList( list:Array<Project> ):Array<{ name:String, author:String, description:String, version:String, downloads:Int }> {
		return [for (p in list) {
			name: p.name,
			author: p.ownerObj.name,
			description: p.description,
			version: p.versionObj.toSemver(),
			downloads: p.downloads
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
