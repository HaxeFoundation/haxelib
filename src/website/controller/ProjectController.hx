package website.controller;

import haxelib.SemVer;
import ufront.MVC;
import website.api.ProjectApi;
import haxe.ds.Option;
import markdown.AST;
import Markdown;
using tink.CoreApi;
using haxe.io.Path;
using CleverSort;
using Lambda;
using DateTools;

class ProjectController extends Controller {

	@inject public var projectApi:ProjectApi;

	@:route("/$projectName")
	public function project( projectName:String ) {
		var info = projectApi.projectInfo( projectName ).sure();
		return version( projectName );
	}

	@:route("/$projectName/versions/")
	public function versionList( projectName:String ) {
		var info = projectApi.projectInfo( projectName ).sure();
		info.versions.sort(function(v1, v2) return SemVer.compare(v2.name, v1.name));
		return new ViewResult({
			title: 'All versions of $projectName',
			project: projectName,
			allVersions: info.versions,
			info: info,
		});
	}

	@:route("/$projectName/$semver")
	public function version( projectName:String, ?semver:String ) {
		var info = projectApi.projectInfo( projectName ).sure();
		if ( semver==null )
			semver = info.curversion;
		var currentVersion = info.versions.find( function(v) return v.name==semver );
		if ( currentVersion==null )
			throw HttpError.pageNotFound();

		var downloadUrl = '/p/$projectName/$semver/download/';

		var readmeHTML = switch projectApi.readContentFromZip( projectName, semver, "README.md" ) {
			case Success(Some(readme)): markdownToHtml(readme, '/p/$projectName/$semver/raw-files/');
			case Success(None): ""; // No README.
			case Failure(err):
				ufError( err.message );
				ufError( err.toString() );
				"";
		}

		return new ViewResult({
			title: '$projectName ($semver)',
			project: projectName,
			allVersions: info.versions,
			version: semver,
			versionDate: Date.fromString(currentVersion.date).format('%F'),
			info: info,
			downloadUrl: downloadUrl,
			readme: readmeHTML,
		}, "version.html");
	}

	function markdownToHtml(markdown:String, prefix:String) {
		// this function is basically a copy of Markdown.markdownToHtml
		// default md->html rendering function, but it adds a filter that
		// fixes relative URLs in IMG tags
		try {
			var imgSrcfixer = new MarkdownImgRelativeSrcFixer(prefix);
			var document = new Document();
			var lines = ~/(\r\n|\r)/g.replace(markdown, '\n').split("\n");
			document.parseRefLinks(lines);
			var blocks = document.parseLines(lines);
			for (block in blocks) block.accept(imgSrcfixer); // fix relative image links
			return Markdown.renderHtml(blocks);
		} catch (e:Dynamic) {
			return '<pre>$e</pre>';
		}
	}

	@:route("/$projectName/$semver/download/")
	public function download( projectName:String, semver:String ) {
		var zipFile = projectApi.getZipFilePath( projectName, semver );
		return new DirectFilePathResult( context.request.scriptDirectory+zipFile );
	}

	@cacheRequest
	@:route("/$projectName/$semver/doc/$typePath")
	public function docs( projectName:String, semver:String, ?typePath:String ) {
		return new ViewResult({
			title: 'View project $projectName docs for $typePath',
		});
	}

	@cacheRequest
	@:route("/$projectName/$semver/files/*")
	public function file( projectName:String, semver:String, rest:Array<String> ) {
		var filePath = rest.join("/");
		var downloadLink = baseUri+'$projectName/$semver/raw-files/$filePath';
		var info = projectApi.projectInfo( projectName ).sure();
		var data:TemplateData = {
			title: 'Viewing $filePath on $projectName:$semver',
			project: projectName,
			info: info,
			version: semver,
			fileParts: rest,
			filePath: filePath,
			downloadLink: downloadLink,
			type: "download",
		};

		switch projectApi.getInfoForPath( projectName, semver, filePath ).sure() {
			case Directory(dirs,files):
				data["type"] = "directory";
				data["dirListing"] = dirs;
				data["fileListing"] = files;
				data["currentDir"] = baseUri+'$projectName/$semver/files/$filePath'.removeTrailingSlashes();
			case Text(str,ext):
				if ( ["md","mdown","markdown"].indexOf(ext)>-1 ) {
					str = Markdown.markdownToHtml( str );
					data["type"] = "markdown";
				}
				else {
					data["type"] = "text";
				}
				data["fileContent"] = str;
				data["extension"] = ext;
				data["highlightLanguage"] = ext;
			case Image(bytes,ext):
				data["filename"] = rest[rest.length-1];
				data["type"] = "img";
			case Binary(size):
				data["filename"] = rest[rest.length-1];
				var sizeInKb = Math.round(size/1024*10) / 10;
				data["size"] = sizeInKb + "kb";
		}

		var vr = new ViewResult( data );
		vr.helpers["extensionAllowed"] = function(file:String) return ProjectApi.textExtensions.has(file.extension().toLowerCase());
		return vr;
	}

	// TODO: write some tests...
	@:route("/$projectName/$semver/raw-files/*")
	public function downloadFile( projectName:String, semver:String, rest:Array<String> ) {
		var filename = rest[ rest.length-1 ];
		var filePath = rest.join("/");
		switch projectApi.readBytesFromZip( projectName, semver, filePath, true ).sure() {
			case Some(bytes):
				return new BytesResult( bytes, null, filename );
			case None:
				throw HttpError.pageNotFound();
		}
	}
}

private class MarkdownImgRelativeSrcFixer implements NodeVisitor {
    static var ABSOLUTE_URL_RE = ~/^(https?:\/)?\//;

    var prefix:String;

    public function new(prefix:String) {
        this.prefix = prefix;
    }

    public function visitElementBefore(element:ElementNode):Bool {
        if (element.tag == "img") {
            var url = element.attributes["src"];
            if (!ABSOLUTE_URL_RE.match(url))
                element.attributes["src"] = prefix + url;
        }
        return element.children != null;
    }

    public function visitText(text:TextNode):Void {}
    public function visitElementAfter(element:ElementNode):Void {}
}
