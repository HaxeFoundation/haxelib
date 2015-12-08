package website.api;

import sys.FileSystem;
import ufront.web.HttpError;
import ufront.api.UFApi;
import sys.io.File;
using tink.CoreApi;

class DocumentationApi extends UFApi {
	@inject("documentationPath") public var docPath:String;

	public function getDocumentationHTML( page:String ):Outcome<String,Error> {
		if ( page==null )
			page = "index";
		var markdownFile = docPath+page+'.md';
		var markdown =
			try File.getContent( markdownFile )
			catch(e:Dynamic) return Failure( new Error(404,'Documentation page $page not found: $e') );
		var html = Markdown.markdownToHtml( markdown );
		return Success( html );
	}
}