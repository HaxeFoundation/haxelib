package website.controller;

import haxe.DynamicAccess;
import haxe.Json;
import haxelib.SemVer;
import ufront.MVC;
import website.api.ProjectApi;
import highlighter.Highlighter;
import haxe.ds.Option;
import markdown.AST;
import Markdown;
using tink.CoreApi;
using haxe.io.Path;
using CleverSort;
using Lambda;
using DateTools;
using StringTools;

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
			description: info.desc,
			project: projectName,
			escape: function(str:String) return StringTools.htmlEscape(str, true),
			allVersions: info.versions,
			info: info,
		});
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
			
			var html = Markdown.renderHtml(blocks);
			
			// prefix relative image urls in generated html (for plain <img>-tags)
			var regexp  = ~/<img src=(["'])(?!(https?:\/)?\/)(.+?)\1/ig;
			while(regexp.match(html)) {
				var url = prefix + regexp.matched(3);
				html = '<img src="${url}"${regexp.matchedRight()}';
			}
			
			return html;
		} catch (e:Dynamic) {
			return '<pre>$e</pre>';
		}
	}

	@:route("/$projectName/$semver/download/")
	public function download( projectName:String, semver:String ) {
		var zipFile = projectApi.getZipFilePath( projectName, semver );
		return new RedirectResult( "/" + zipFile, true );
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
		
		if ( semver==null )
			semver = info.curversion;
		var currentVersion = info.versions.find( function(v) return v.name==semver );
		if ( currentVersion==null )
			throw HttpError.pageNotFound();
			
		var data:TemplateData = {
			title: 'Viewing $filePath on $projectName:$semver',
			project: projectName,
			description: info.desc,
			info: info,
			allVersions: info.versions,
			versionDate: Date.fromString(currentVersion.date).format('%F'),
			version: semver,
			size: null,
			fileParts: rest,
			filePath: filePath,
			fileExt: Path.extension(filePath),
			downloadLink: downloadLink,
			icon: function(file:String) {
				return switch Path.extension(file) {
					case "zip"|"rar"|"tar.gx": "file-archive-o";
					case "pdf": "file-pdf-o";
					case "hx"|"hxml": "file-code-o";
					case "jpg"|"jpeg"|"gif"|"png"|"svg"|"ico": "file-image-o";
					case "txt"|"md"|"mdown"|"markdown": "file-text-o";
					case other: "file-o";
				}
			},
			type: "download",
		};
		
		switch projectApi.getInfoForPath( projectName, semver, filePath ).sure() {
			case Directory(dirs,files):
				data["type"] = "directory";
				data["dirListing"] = dirs;
				data["fileListing"] = files;
				data["currentDir"] = baseUri+'$projectName/$semver/files/$filePath'.removeTrailingSlashes();
			case Text(str,ext,size):
				if ( ["md","mdown","markdown"].indexOf(ext)>-1 ) {
					str = markdownToHtml( str, '/p/$projectName/$semver/raw-files/' );
					str = str.replace("<script", "&lt;script"); // disallow scripts
					data["type"] = "markdown";
				}
				else {
					data["type"] = "text";
					
					// make sure tags are rendered correctly
					str = str.replace("<", "&lt;").replace(">", "&gt;");
					
					try {
						str = switch (ext) {
							case "xml","html","htm","mtt":
								Util.syntaxHighlightHTML(str);
							case "hx":
								Highlighter.syntaxHighlightHaxe(str);
							case "hxml":
								Highlighter.syntaxHighlightHXML(str);
							default:
								str;
						};
					} catch(e:Dynamic) {
						// don't throw error when there is highlighting issue
						// just don't highlight it
					}
				}
				
				data["fileContent"] = str;
				data["size"] = getSize(size);
				data["highlightLanguage"] = ext;
				
			case Image(bytes,ext,size):
				data["filename"] = rest[rest.length-1];
				data["type"] = "img";
				data["size"] = getSize(size);
				
			case Binary(size):
				data["filename"] = rest[rest.length-1];
				data["size"] = getSize(size);
		}

		var vr = new ViewResult( data );
		vr.helpers["extensionAllowed"] = function(file:String) return ProjectApi.textExtensions.has(file.extension().toLowerCase());
		return vr;
	}
	
	static function getSize(size:Int) {
		if (size == null) return null;
		var kb = Math.round(size / 1024 * 10) / 10;
		if (kb > 1000) {
			return (Math.round(kb / 100) / 10) + "mb";
		} else {
			return kb + "kb";
		}
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
	
	@:route("/$projectName/$semver/readme/")
	public function readme( projectName:String, semver:String ) {
		return getVersion(projectName, semver, "readme");
	}
	
	@:route("/$projectName/$semver/license/")
	public function license( projectName:String, semver:String ) {
		return getVersion(projectName, semver, "license");
	}
	
	@:route("/$projectName/$semver/releasenotes/")
	public function releasenotes( projectName:String, semver:String ) {
		return getVersion(projectName, semver, "releasenotes");
	}
	
	@:route("/$projectName/$semver/changelog/")
	public function changelog( projectName:String, semver:String ) {
		return getVersion(projectName, semver, "changelog");
	}
	
	@:route("/$projectName/$semver/")
	public function version( projectName:String, ?semver:String ) {
		return getVersion(projectName, semver);
	}
	
	private function getVersion( projectName:String, ?semver:String, ?type:String ) {
		var info = projectApi.projectInfo( projectName ).sure();
		if ( semver==null )
			semver = info.curversion;
		var currentVersion = info.versions.find( function(v) return v.name==semver );
		if ( currentVersion==null )
			throw HttpError.pageNotFound();

		var downloadUrl = '/p/$projectName/$semver/download/';
		
		function getHTML(files:Array<String>) {
			for(file in files) { 
				switch projectApi.readContentFromZip( projectName, semver, file, false ) {
					case Success(Some(readme)): return markdownToHtml(readme, '/p/$projectName/$semver/raw-files/');
					case Success(None): // No file found.
					case Failure(err):
						// ufError( err.message );
						// ufError( err.toString() );
				};
			}
			return null;
		}
		
		// TODO: would be nice to have this data in database instead of from the zip
		var haxeLibJson:Any = switch (projectApi.readContentFromZip(projectName, semver, "haxelib.json", false)) {
			case Success(Some(haxelibJson)): Json.parse(haxelibJson); // it 
			case _: null;
		}
		var dependencies:DynamicAccess<String> = haxeLibJson != null && Reflect.hasField(haxeLibJson, "dependencies") ? Reflect.field(haxeLibJson, "dependencies") : { };
		var dependencies = [for (dep in dependencies.keys()) {
			name: dep, 
			version: if (dependencies.get(dep).length > 0) dependencies.get(dep) else null,
		}];
		
		var semverCommas = semver.replace(".", ",");
		
		var changelog = getHTML([
			for (changelog in ["releases", "changelog"]) 
				for (extension in [".md", ".txt", ""]) 
					for (p in ['$changelog$extension', '$projectName/$changelog$extension', '$semverCommas/$changelog$extension'])
						p
			]);
			
		var readme = getHTML([for (extension in [".md", ".txt", ""])
				for (p in ['README$extension', '$projectName/README$extension', '$semverCommas/README$extension'])
					p
			]);
			
		var license = getHTML([
			for (extension in [".md", ".txt", ""]) 
				for (p in ['LICENSE$extension', '$projectName/LICENSE$extension', '$semverCommas/LICENSE$extension'])
					p
			]);
			
		var releaseNotes = currentVersion.comments;
		
		// whitelist type, fall back to readme. unless there is no readme, then go to releasenotes tab
		if (!(type == 'license' || type == 'changelog' || type == 'releasenotes' || type == 'changelog' || type == 'readme')) {
			type = "readme";
			if (readme == null) type = "releasenotes";
		} 
		
		return new ViewResult({
			title: '$projectName ($semver)',
			project: projectName,
			description: '${currentVersion.comments} - ${info.desc}',
			allVersions: info.versions,
			version: semver,
			versionDate: Date.fromString(currentVersion.date).format('%F'),
			info: info,
			downloadUrl: downloadUrl,
			type: type,
			changelog:changelog,
			readme:readme,
			license:license,
			releaseNotes:releaseNotes,
			hasReleaseNotes: currentVersion.comments != null && currentVersion.comments.length > 0,
			hasReadme: readme != null,
			hasChangelog: changelog != null,
			hasLicense: license != null,
			dependencies: dependencies,
		}, "version.html");
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

