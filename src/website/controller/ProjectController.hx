package website.controller;

import ufront.MVC;
import website.api.ProjectApi;
import haxe.ds.Option;
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
		// TODO: create semver.sort, and use that instead.
		info.versions.cleverSort( _.name );
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
			case Success(Some(readme)): Markdown.markdownToHtml(readme);
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
