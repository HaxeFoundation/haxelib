package website.controller;

import ufront.web.Controller;
import ufront.web.result.*;
import website.api.DocumentationApi;
import ufront.core.OrderedStringMap;
using tink.CoreApi;

@cacheRequest
class DocumentationController extends Controller {

	@inject public var api:DocumentationApi;

	@:route("/$page")
	public function documentationPage( ?page:String ) {
		var html = api.getDocumentationHTML( page ).sure();
		var documentationPages = getDocumentationPages();
		var docTitle =
			if ( page==null ) documentationPages.get('/documentation/');
			else documentationPages.get('/documentation/$page/');
		return new ViewResult({
			title: '$docTitle - Haxelib Documentation',
			content: html,
		});
	}

	public static function getDocumentationPages():OrderedStringMap<String> {
		var pages = new OrderedStringMap();
		pages.set( "/documentation/", "Getting Started" );
		pages.set( "/documentation/using-haxelib/", "Using Haxelib" );
		pages.set( "/documentation/creating-a-haxelib-package/", "Creating a Haxelib" );
		// pages.set( "/documentation/faq/", "FAQ" );
		// pages.set( "/documentation/api/", "API" );
		return pages;
	}
}
