package haxelib.api;

import haxe.Http;
import haxe.Timer;
import haxe.zip.*;
import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.io.Input;
import haxe.remoting.HttpConnection;
import sys.FileSystem;
import sys.io.File;

import haxelib.Data;
import haxelib.MetaData;

using StringTools;

#if js
import haxe.io.Bytes;
using haxelib.api.Connection.PromiseSynchronizer;

@:jsRequire("promise-synchronizer")
private extern class PromiseSynchronizer {
	@:selfCall
	static public function sync<T>(p:js.lib.Promise<T>):T;
}
#end

private class SiteProxy extends haxe.remoting.Proxy<haxelib.SiteApi> {}

@:structInit
private class ServerInfo {
	public final protocol:String;
	public final host:String;
	public final port:Int;
	public final dir:String;
	public final url:String;
	public final apiVersion:String;
	public final useSsl:Bool;
}

@:structInit
private class ConnectionData {
	public final site:SiteProxy;
	public final server:ServerInfo;
	public final siteUrl:String;

	public static function setup(remote:String = null, useSsl = true):ConnectionData {
		final server = switch remote {
			case null: getDefault(useSsl);
			case remote: getFromRemote(remote, useSsl);
		}
		final siteUrl = '${server.protocol}://${server.host}:${server.port}/${server.dir}';

		final remotingUrl = '${siteUrl}api/${server.apiVersion}/${server.url}';
		final site = new SiteProxy(HttpConnection.urlConnect(remotingUrl).resolve("api"));

		return {
			site: site,
			server: server,
			siteUrl: siteUrl
		}
	}

	static function getDefault(useSsl:Bool):ServerInfo {
		return {
			protocol: useSsl ? "https" : "http",
			host: "lib.haxe.org",
			port: useSsl ? 443 : 80,
			dir: "",
			url: "index.n",
			apiVersion: "3.0",
			useSsl: useSsl
		};
	}

	static function getFromRemote(remote:String, useSsl:Bool):ServerInfo {
		final r = ~/^(?:(https?):\/\/)?([^:\/]+)(?::([0-9]+))?\/?(.*)$/;
		if (!r.match(remote))
			throw 'Invalid repository format \'$remote\'';

		final protocol = r.matched(1) ?? (if (useSsl) "https" else "http");

		final port = switch (r.matched(3)) {
			case null if (protocol == "https"): 443;
			case null if (protocol == "http"): 80;
			case null: throw 'unknown default port for $protocol';
			case Std.parseInt(_) => port if(port != null): port;
			case invalidPortStr: throw '$invalidPortStr is not a valid port';
		}

		return {
			protocol: protocol,
			host: r.matched(2),
			port: port,
			dir: haxe.io.Path.addTrailingSlash(r.matched(4)),
			url: "index.n",
			apiVersion: "3.0",
			useSsl: useSsl
		};
	}
}

/** Signature of function used to log the progress of a download. **/
@:noDoc
typedef DownloadProgress = (finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void;

private class ProgressOut extends Output {
	final o:Output;
	final startSize:Int;
	final start:Float;

	var cur:Int;
	var max:Null<Int>;

	public function new(o, currentSize, progress) {
		start = Timer.stamp();
		this.o = o;
		startSize = currentSize;
		cur = currentSize;
		this.progress = progress;
	}

	dynamic function progress(finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float):Void {}

	function report(n) {
		cur += n;

		progress(false, cur, max, cur - startSize, Timer.stamp() - start);
	}

	public override function writeByte(c) {
		o.writeByte(c);
		report(1);
	}

	public override function writeBytes(s, p, l) {
		final r = o.writeBytes(s, p, l);
		report(r);
		return r;
	}

	public override function close() {
		super.close();
		o.close();

		progress(true, cur, max, cur - startSize, Timer.stamp() - start);
	}

	public override function prepare(m) {
		max = m + startSize;
	}
}

private class ProgressIn extends Input {
	final i:Input;
	final tot:Int;

	var pos:Int;

	public function new(i, tot, progress) {
		this.i = i;
		this.pos = 0;
		this.tot = tot;
		this.progress = progress;
	}

	dynamic function progress(pos:Int, total:Int):Void {}

	public override function readByte() {
		final c = i.readByte();
		report(1);
		return c;
	}

	public override function readBytes(buf, pos, len) {
		final k = i.readBytes(buf, pos, len);
		report(k);
		return k;
	}

	function report(nbytes:Int) {
		pos += nbytes;
		progress(pos,tot);
	}
}

/** Class that provides functions for interactions with the Haxelib server. **/
class Connection {
	/** The number of times a server interaction will be attempted. Defaults to 3. **/
	public static var retries = 3;

	/** If set to `false`, the connection timeout time is unlimited. **/
	public static var hasTimeout(default, set) = true;

	static function set_hasTimeout(value:Bool) {
		if (value)
			haxe.remoting.HttpConnection.TIMEOUT = 10;
		else
			haxe.remoting.HttpConnection.TIMEOUT = 0;
		return hasTimeout = value;
	}
	/** Whether to use SSL when connecting. Set to `true` by default. **/
	public static var useSsl(default, set) = true;
	static function set_useSsl(value:Bool):Bool {
		if (useSsl != value)
			data = null;
		return useSsl = value;
	}

	/** The server url to be used as the Haxelib database.  **/
	public static var remote(default, set):Null<String> = null;
	static function set_remote(value:String):String {
		if (remote != value)
			data = null;
		return remote = value;
	}

	/** Function to which connection information will be logged. **/
	public static dynamic function log(msg:String) {}

	/** Returns the domain of the Haxelib server. **/
	public static function getHost():String {
		return data.server.host;
	}

	static var data(get, null):ConnectionData;
	static function get_data():ConnectionData {
		if (data == null)
			return data = ConnectionData.setup(remote, useSsl);
		return data;
	}

	/**
		Downloads the file from `fileUrl` into `outpath`.

		`downloadProgress` is the function used to log download information.
	 **/
	#if js
	public static function download(fileUrl:String, outPath:String, downloadProgress = null):Void {
		node_fetch.Fetch.call(fileUrl, {
			headers: {
				"User-Agent": 'haxelib ${Util.getHaxelibVersionLong()}',
			}
		})
			.then(r -> r.ok ? r.arrayBuffer() : throw 'Request to $fileUrl responded with ${r.statusText}')
			.then(buf -> File.saveBytes(outPath, Bytes.ofData(buf)))
			.sync();
	}
	#else
	public static function download(filename:String, outPath:String, downloadProgress:DownloadProgress = null) {
		final maxRetry = 3;
		final fileUrl = haxe.io.Path.join([data.siteUrl, Data.REPOSITORY, filename]);
		var lastError = new haxe.Exception("");

		for (i in 0...maxRetry) {
			try {
				downloadFromUrl(fileUrl, outPath, downloadProgress);
				return;
			} catch (e:Dynamic) {
				log('Failed to download ${fileUrl}. (${i + 1}/${maxRetry})\n${e}');
				lastError = e;
				Sys.sleep(1);
			}
		}
		FileSystem.deleteFile(outPath);
		throw lastError;
	}

	// maxRedirect set to 20, which is most browsers' default value according to https://stackoverflow.com/a/36041063/267998
	static function downloadFromUrl(fileUrl:String, outPath:String, downloadProgress:Null<DownloadProgress>, maxRedirect = 20):Void {
		final out = try File.append(outPath, true) catch (e:Dynamic) throw 'Failed to write to $outPath: $e';
		out.seek(0, SeekEnd);

		final h = createHttpRequest(fileUrl);

		final currentSize = out.tell();
		if (currentSize > 0)
			h.addHeader("range", 'bytes=$currentSize-');

		final progress = if (downloadProgress == null) out
			else new ProgressOut(out, currentSize, downloadProgress);

		var httpStatus = -1;
		var redirectedLocation = null;
		h.onStatus = function(status) {
			httpStatus = status;
			switch (httpStatus) {
				case 301, 302, 307, 308:
					switch (h.responseHeaders.get("Location")) {
						case null:
							throw 'Request to $fileUrl responded with $httpStatus, ${h.responseHeaders}';
						case location:
							redirectedLocation = location;
					}
				default:
					// TODO?
			}
		};
		h.onError = function(e) {
			progress.close();

			switch (httpStatus) {
				case 416:
				// 416 Requested Range Not Satisfiable, which means that we probably have a fully downloaded file already
				// if we reached onError, because of 416 status code, it's probably okay and we should try unzipping the file
				default:
					FileSystem.deleteFile(outPath);
					throw e;
			}
		};
		h.customRequest(false, progress);

		if (redirectedLocation == null)
			return;

		FileSystem.deleteFile(outPath);

		if (maxRedirect == 0)
			throw "Too many redirects.";

		downloadFromUrl(redirectedLocation, outPath, downloadProgress, maxRedirect - 1);
	}
	#end

	static function retry<R>(func:Void->R) {
		var hasRetried = false;
		var numTries = retries;

		while (numTries-- > 0) {
			try {
				final result = func();

				if (hasRetried)
					log("Retry successful");

				return result;
			} catch (e:Dynamic) {
				if (e == "std@host_resolve")
					Util.rethrow(e);
				if (e != "Blocked")
					throw 'Failed with error: $e';
				log("Failed. Triggering retry due to HTTP timeout");
				hasRetried = true;
			}
		}
		throw 'Failed due to HTTP timeout after multiple retries';
	}

	/** Returns the array of available versions for `library`. **/
	static function getVersions(library:ProjectName):Array<SemVer> {
		final versionsData = retry(data.site.infos.bind(library)).versions;
		return [for (data in versionsData) data.name];
	}

	/**
		Returns a map of the library names in `libraries` with their correctly
		capitalized names and available versions.
	**/
	public static function getLibraryNamesAndVersions(libraries:Array<ProjectName>):
		Map<ProjectName,{confirmedName:ProjectName, versions:Array<SemVer>}>
	{
		// TODO: can we collapse this into a single API call?  It's getting too slow otherwise.
		final map = new Map<ProjectName, {confirmedName:ProjectName, versions:Array<SemVer>}>();

		for (lib in libraries) {
			final info = retry(data.site.infos.bind(lib));
			final versionsData = info.versions;
			map[lib] = {confirmedName: ProjectName.ofString(info.name), versions: [for (data in versionsData) data.name]};
		}
		return map;
	}

	#if !js
	/**
		Submits the library at `path` and uploads it.

		`login` is called with the project's contributors and expects one of them
		to be returned along with the password.

		If the library version being submitted already exists, `overwrite` is called
		with the library version, and the version is overwritten only if it returns `true`,
		otherwise the operation is aborted. If `overwrite` is not passed in, the
		operation is aborted by default.

		`logUploadStatus` can be passed in optionally to show progress during upload.
	**/
	public static function submitLibrary(path:String, login:(Array<String>)->{name:String, password:String},
		?overwrite:(version:SemVer)->Bool,
		?logUploadStatus:(current:Int, total:Int) -> Void
	) {
		var data:haxe.io.Bytes, zip:List<Entry>;
		if (FileSystem.isDirectory(path)) {
			zip = FsUtils.zipDirectory(path);
			final out = new BytesOutput();
			new Writer(out).write(zip);
			data = out.getBytes();
		} else {
			data = File.getBytes(path);
			zip = Reader.readZip(new haxe.io.BytesInput(data));
		}

		final infos = Data.readDataFromZip(zip, CheckData);
		Data.checkClassPath(zip, infos);
		Data.checkDocumentation(zip, infos);

		// ask user which contributor they are
		final user = login(infos.contributors);
		// ensure they are already a contributor for the latest release
		checkDeveloper(infos.name, user.name);

		checkDependencies(infos.dependencies);

		// check if this version already exists
		if (doesVersionExist(infos.name, infos.version) && !(overwrite == null || overwrite(infos.version)))
			throw "Aborted";

		uploadAndSubmit(user, data, logUploadStatus);
	}

	static function checkDependencies(dependencies:Dependencies) {
		for (name => versionString in dependencies) {
			final versions:Array<String> = getVersions(ProjectName.ofString(name));
			if (versionString == "")
				continue;
			if (!versions.contains(versionString))
				throw "Library " + name + " does not have version " + versionString;
		}
	}

	static function doesVersionExist(library:ProjectName, version:SemVer):Bool {
		final versions = try getVersions(library) catch (_:Dynamic) return false;
		return versions.contains(version);
	}

	static function uploadAndSubmit(user, data, uploadProgress:Null<(pos:Int, total:Int) -> Void>) {
		// query a submit id that will identify the file
		final id = getSubmitId();

		upload(data, id, uploadProgress);

		log("Processing file...");

		// processing might take some time, make sure we wait
		final oldTimeout = HttpConnection.TIMEOUT;
		if (hasTimeout) // don't ignore `hasTimeout` being false
			HttpConnection.TIMEOUT = 1000;

		// ask the server to register the sent file
		final msg = processSubmit(id, user.name, user.password);
		log(msg);

		HttpConnection.TIMEOUT = oldTimeout;
	}

	static function upload(data:haxe.io.Bytes, id:String, logUploadStatus:Null<(pos:Int, total:Int) -> Void>) {
		// directly send the file data over Http
		final h = createRequest();
		h.onError = function(e) throw e;
		h.onData = log;

		final inp = {
			final dataBytes = new haxe.io.BytesInput(data);
			if (logUploadStatus == null)
				dataBytes;
			new ProgressIn(dataBytes, data.length, logUploadStatus);
		}

		h.fileTransfer("file", id, inp, data.length);
		log("Sending data...");
		h.request(true);
	}

	static inline function createRequest():Http {
		return createHttpRequest('${data.server.protocol}://${data.server.host}:${data.server.port}/${data.server.url}');
	}

	static inline function createHttpRequest(url:String):Http {
		final req = new Http(url);
		req.addHeader("User-Agent", "haxelib " + Util.getHaxelibVersionLong());
		if (!hasTimeout)
			req.cnxTimeout = 0;
		return req;
	}

	/** Sets the proxy that will be used for http requests **/
	public static function setProxy(proxy:{host:String, port:Null<Int>, auth:Null<{user:String, pass:String}>}):Void {
		Http.PROXY = proxy;
	}

	/**
		Makes a connection attempt across the internet, and returns `true`
		if connection is successful, or `false` if it fails.
	**/
	public static function testConnection():Bool {
		try {
			Http.requestUrl(data.server.protocol + "://lib.haxe.org");
			return true;
		} catch (e:Dynamic) {
			return false;
		}
	}
	#end

	// Could maybe be done with a macro ??

	/** Returns the latest version of `library`. **/
	public static function getLatestVersion(library:ProjectName):SemVer
		return retry(data.site.getLatestVersion.bind(library));

	/** Returns the project information of `library` **/
	public static function getInfo(library:ProjectName):ProjectInfos
		return retry(data.site.infos.bind(library));

	/** Searches libraries with `word` as the search term. **/
	public static function search(word:String)
		return retry(data.site.search.bind(word));

	/** Informs the server of a successful installation of `version` of `library` **/
	public static function postInstall(library:ProjectName, version:SemVer)
		return retry(data.site.postInstall.bind(library, version));

	/** Returns user information for `userName` **/
	public static function getUserData(userName:String)
		return retry(data.site.user.bind(userName));

	/** Registers user with `name`, `encodedPassword`, `email`, and `fullname`. **/
	public static function register(name:String, encodedPassword:String, email:String, fullname:String)
		return retry(data.site.register.bind(name, encodedPassword, email, fullname));

	/** Returns `true` if no user with `userName` exists yet. **/
	public static function isNewUser(userName:String)
		return retry(data.site.isNewUser.bind(userName));

	/** Checks that `password` is the correct password for `userName`. **/
	public static function checkPassword(userName:String, password:String)
		return retry(data.site.checkPassword.bind(userName, password));

	static function checkDeveloper(library:ProjectName, userName:String)
		return retry(data.site.checkDeveloper.bind(library, userName));

	static function getSubmitId()
		return retry(data.site.getSubmitId.bind());

	static function processSubmit(id:String, userName:String, password:String)
		return retry(data.site.processSubmit.bind(id, userName, password));
}
