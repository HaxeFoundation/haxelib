package website.api;

import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxelib.Data;
import haxelib.server.Repo;
import ufront.api.UFApi;
import ufront.cache.UFCache;
import ufront.web.HttpError;
import website.model.SiteDb;
import haxe.ds.Option;
using tink.CoreApi;
using StringTools;
using haxe.io.Path;

class ProjectApi extends UFApi {

	public static var cacheNames = {
		info: 'haxelib_zip_cache_info',
		dirListing: 'haxelib_zip_cache_dir_list',
		fileBytes: 'haxelib_zip_cache_file_content'
	};

	// TODO: inject the repo directory instead.
	@inject("scriptDirectory") public var scriptDir:String;
	@inject public var cacheCnx:UFCacheConnectionSync;

	/** Extensions that should be loaded as a text file. **/
	public static var textExtensions:Array<String> = ["md","txt","hx","hxml","json","xml","htaccess"];
	public static var imgExtensions:Array<String> = ["jpg","jpeg","gif","png"];

	/**
		Load the ProjectInfos for the given project.
		This contains basic metadata and is loaded from the database (though it is set via a haxelib.json file during project upload).
	**/
	public function projectInfo( projectName:String ):Outcome<ProjectInfos,Error> {
		try {
			var info = new Repo().infos(projectName);
			return Success( info );
		}
		catch ( e:Dynamic )  {
			var error =
				if ( Std.is(e,String) && StringTools.startsWith(e,"No such Project") ) HttpError.pageNotFound();
				else Error.withData('Failed to get info for project $projectName',e);
			return Failure( error );
		}
	}

	/**
		Given a path, load either the file or the directory listing, and take a guess at the content type.

		This will use `this.cacheCnx` to cache results, to prevent us having to load the zip file each time.
	**/
	public function getInfoForPath( projectName:String, version:String, path:String ):Outcome<FileInformation,Error> {
		try {
			var pathWithSlash = path.addTrailingSlash();
			var cache = cacheCnx.getNamespaceSync( cacheNames.info );
			var fileInfo = cache.getOrSetSync( '$projectName:$version:$pathWithSlash', function() {
				var extension = path.extension();
				var zip = getZipEntries(projectName,version);
				var fileInfo = null;
				for ( entry in zip ) {
					if ( entry.fileName==path ) {
						// Exact match! It's a file, not a directory. Now, check the type and load it.
						fileInfo =
							if ( textExtensions.indexOf(extension)>-1 )
								Text( Reader.unzip(entry).toString(), extension );
							else if ( imgExtensions.indexOf(extension)>-1 )
								Image( Reader.unzip(entry), extension );
							else
								Binary( entry.fileSize );
						break;
					}
					else if ( entry.fileName==pathWithSlash || pathWithSlash=="/" ) {
						// It's a directory, so get the listing of files and sub directories.
						var dirListing = getDirListing( zip, path );
						fileInfo = Directory( dirListing.dirs, dirListing.files );
						break;
					}
				}
				if (fileInfo == null) {
					// If it's still null, handle one more case: there's no zip entry for the requested directory,
					// but there are entries for files in it. Get listing of that directory and if it's not empty,
					// return it.
					var dirListing = getDirListing( zip, path );
					if (dirListing.dirs.length > 0 || dirListing.files.length > 0)
						fileInfo = Directory( dirListing.dirs, dirListing.files );
				}
				return fileInfo;
			}).sure();
			return
				if ( fileInfo!=null ) Success( fileInfo );
				else Failure( HttpError.pageNotFound() );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get file information for $path in $projectName ($version)',e) );
	}

	/**
		Fetch a list of files in a directory in the zip file.

		This will use `this.cacheCnx` to cache results, to prevent us having to load the zip file each time.

		Returns a Success with two arrays, containing a) sub directories, and b) files. Names are relative to the dirPath, not absolute to the zip.
		Returns a Failure with an error if one is encountered.
	**/
	public function getDirListingFromZip( projectName:String, version:String, dirPath:String ):Outcome<{ dirs:Array<String>, files:Array<String> },Error> {
		try {
			var cache = cacheCnx.getNamespaceSync( cacheNames.dirListing );
			var listing = cache.getOrSetSync( '$projectName:$version:$dirPath', function() {
				var zip = getZipEntries(projectName,version);
				return getDirListing(zip,dirPath);
			}).sure();
			return Success( listing );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to read directory $dirPath from $projectName ($version) zip',e) );
	}

	/**
		Read text content from a file in a project's zip file.
		Returns Success(Some(contents)) if the file was read successfully.
		Returns Success(None) if the file was not found in the zip file.
		Returns Failure if an error was encountered.
	**/
	public function readContentFromZip( projectName:String, version:String, filename:String, ?caseSensitive:Bool=true ):Outcome<Option<String>,Error> {
		// This is the same as readBytesFromZip, but we transform the result to turn Bytes into a String.
		return readBytesFromZip( projectName, version, filename, caseSensitive ).map(function (outcome) return switch outcome {
			case Some(bytes): Some( bytes.toString() );
			case None: None;
		});
	}

	/**
		Read the raw bytes from a file in a project's zip file.
		Returns Success(Some(bytes)) if the file was read successfully.
		Returns Success(None) if the file was not found in the zip file.
		Returns Failure if an error was encountered.
	**/
	public function readBytesFromZip( projectName:String, version:String, filename:String, ?caseSensitive:Bool=true ):Outcome<Option<Bytes>,Error> {
		try {
			var cache = cacheCnx.getNamespaceSync( cacheNames.fileBytes );
			var bytes = cache.getOrSetSync( '$projectName:$version:$filename:$caseSensitive', function() {
				var zip = getZipEntries( projectName, version );
				return getBytesFromFile( zip, filename, caseSensitive );
			}).sure();
			return
				if ( bytes!=null ) Success( Some(bytes) );
				else Success( None );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to read $filename from $projectName ($version) zip: $e',e) );
	}

	/**
		Get the path to the zip file (relative to the script directory).
	**/
	public function getZipFilePath( project:String, version:String ):String {
		var fileName = Data.fileName(project, version);
		#if deploy
			// On the haxe.org server, we want to access the repo from the old website.
			// When we change the websites over we should probably move these over too.
			return '../www/files/3.0/$fileName';
		#else
			return 'files/3.0/$fileName';
		#end
	}

	//
	// Private API
	//

	/** Get a list of entries in a zip file. **/
	function getZipEntries( projectName:String, version:String ):List<Entry> {
		var path = scriptDir+getZipFilePath( projectName, version );
		var file = try sys.io.File.read(path,true) catch( e : Dynamic ) throw 'Invalid zip file $path: $e';
		var zip = try haxe.zip.Reader.readZip(file) catch( e : Dynamic ) { file.close(); neko.Lib.rethrow(e); };
		file.close();
		return zip;
	}

	/** Attempt to extract the bytes of a file within a zip file. Will return null if the file was not found. **/
	function getBytesFromFile( zip:List<Entry>, filename:String, caseSensitive:Bool ):Null<Bytes> {
		var file = null;
		for( f in zip ) {
			var sameName = f.fileName==filename || (caseSensitive==false && f.fileName.toLowerCase()==filename.toLowerCase());
			if ( sameName )
				return Reader.unzip( f );
		}
		return null;
	}

	/** Get a directory listing from the zip entries. If the directory doesn't exist the file listings will just be empty. **/
	function getDirListing( zip:List<Entry>, dirPath:String ):{ dirs:Array<String>, files:Array<String> } {
		dirPath = dirPath.addTrailingSlash();
		var subdirectories = [];
		var files = [];
		for( f in zip ) {
			var fileInsideDirectory = (f.fileName.startsWith(dirPath) && f.fileName.length>dirPath.length) || dirPath=="/";
			if ( fileInsideDirectory ) {
				var remainingName =
					if ( dirPath=="/" ) f.fileName;
					else f.fileName.substr( dirPath.length );
				if ( remainingName.indexOf('/')==-1 ) {
					// This is a file in this directory. Add it if we don't have it already.
					if ( files.indexOf(remainingName)==-1 )
						files.push( remainingName );
				}
				else {
					// This is a file in a subdirectory. Add it if we don't have it already.
					var subdirName = remainingName.substr( 0, remainingName.indexOf('/') );
					if ( subdirectories.indexOf(subdirName)==-1 )
						subdirectories.push( subdirName );
				}
			}
		}
		return { dirs:subdirectories, files:files };
	}
}

/**
	A description of a file found in a Haxelib zip file.
**/
enum FileInformation {
	/** A text file, with it's String content and extension. **/
	Text( content:String, extension:String );
	/** A text file, with it's Bytes content and extension. **/
	Image( content:Bytes, extension:String );
	/** A binary file that we can't display, together with it's size. **/
	Binary( size:Int );
	/** A directory listing, with separate arrays for subdirs and files. **/
	Directory( subdirs:Array<String>, files:Array<String> );
}
