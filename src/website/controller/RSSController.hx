package website.controller;

import haxelib.server.SiteDb;
import ufront.web.Controller;
import ufront.web.result.ContentResult;
import website.api.ProjectListApi;
using StringTools;
using DateTools;
using tink.CoreApi;

class RSSController extends Controller {

	@inject public var projectListApi:ProjectListApi;

	@:route("/")
	public function rss( ?args:{ number:Int } ) {
		var number = (args.number!=null) ? args.number : 20;
		var releases = projectListApi.latest( number ).sure();
		var rss = buildRss( releases );
		var content = '<?xml version="1.0" encoding="UTF-8"?>'+rss.toString();
		return new ContentResult( content, "text/xml" );
	}

	function buildRss( releases:Array<{v:Version, p:Project}> ):Xml {
		// Helpers for building the XML
		var createChild = function(root:Xml, name:String){
			var c = Xml.createElement( name );
			root.addChild( c );
			return c;
		}
		var createChildWithContent = function(root:Xml, name:String, content:String){
			var e = Xml.createElement( name );
			var c = Xml.createPCData( if (content != null) content else "" );
			e.addChild( c );
			root.addChild( e );
			return e;
		}
		var createChildWithCdata = function(root:Xml, name:String, content:String){
			var e = Xml.createElement( name );
			var c = Xml.createCData( if (content != null) content else "" );
			e.addChild( c );
			root.addChild( e );
			return e;
		}

		// Set some variables we'll use.
		Sys.setTimeLocale( "en_US.UTF8" );
		var hostName = context.request.hostName;
		var url = "http://"+hostName;
		var num = releases.length;

		// Create the RSS document and headers.
		var rss = Xml.createElement( "rss" );
		rss.set( "version", "2.0" );
		rss.set( "xmlns:atom", "http://www.w3.org/2005/Atom" );
		rss.set( "xmlns:dc", "http://purl.org/dc/elements/1.1/" );
		var channel = createChild( rss, "channel" );
		var link = createChild( channel, "atom:link" );
		link.set( "href", 'http://$hostName/rss/' );
		link.set( "rel", "self" );
		link.set( "type", "application/rss+xml" );
		createChildWithContent( channel, "title", 'Latest Haxelib Releases ($hostName)' );
		createChildWithContent( channel, "link", url );
		createChildWithContent( channel, "description", 'The latest $num haxelib releases on $hostName' );
		createChildWithContent( channel, "generator", "haxe" );
		createChildWithContent( channel, "language", "en" );

		// Create the various RSS entries.
		for ( release in releases ) {
			var version = release.v;
			var project = release.p;
			var item = createChild(channel, "item");
			var title = '${project.name} ${version.toSemver()}';
			var description = '<p>${version.comments.htmlEscape()}</p><hr/><p>${project.description.htmlEscape()}</p>';
			createChildWithContent( item, "title", title.htmlEscape() );
			createChildWithContent( item, "link", url+"/p/"+project.name );
			createChildWithContent( item, "guid", url+"/p/"+project.name+"?v="+version.id );
			var date = Date.fromString( version.date ).format( "%a, %e %b %Y %H:%M:%S %z" );
			createChildWithContent( item, "pubDate", date );
			createChildWithContent( item, "dc:creator", project.ownerObj.name );
			createChildWithContent( item, "description", description );
		}

		return rss;
	}
}
