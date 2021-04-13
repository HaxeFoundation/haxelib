package haxelib.client;

import haxe.Http;
import haxe.Timer;
import haxe.io.Output;
import haxe.remoting.HttpConnection;
import sys.FileSystem;
import sys.io.File;

import haxelib.Data;

using StringTools;

#if js
import haxe.io.Bytes;
using haxelib.client.Connection.PromiseSynchronizer;

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
			case portStr: Std.parseInt(portStr);
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

typedef DownloadProgress = (finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) -> Void;

private class ProgressOut extends Output {
	final o:Output;
	final startSize:Int;
	final start:Float;
	final _progress:Null<DownloadProgress>;

	var cur:Int;
	var max:Null<Int>;

	public function new(o, currentSize, ?_progress) {
		start = Timer.stamp();
		this.o = o;
		startSize = currentSize;
		cur = currentSize;
		this._progress = _progress;
	}

	inline function progress(finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float):Void {
		if (_progress != null)
			_progress(finished, cur, max, downloaded, time);
	}

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

/** Wraps interactions with the server so that they are attempted three times **/
class Connection {
	/** The number of times a server interaction will be attempted. Defaults to 3. **/
	public static var retries = 3;

	/** If set to false, the connection timeout time is unlimited. **/
	public static var hasTimeout(null, set):Bool;

	static function set_hasTimeout(value:Bool) {
		if (value)
			haxe.remoting.HttpConnection.TIMEOUT = 10;
		else
			haxe.remoting.HttpConnection.TIMEOUT = 0;
		return value;
	}

	public static var useSsl(default, set) = true;
	public static function set_useSsl(value:Bool):Bool {
		if (useSsl != value)
			data = null;
		return useSsl = value;
	}

	public static var remote(default, set):Null<String> = null;
	public static function set_remote(value:String):String {
		if (remote != value)
			data = null;
		return remote = value;
	}

	/** Function to which connection information will be logged. **/
	public static dynamic function log(msg:String) {}

	/** Returns the name of the host**/
	public static function getHost():String {
		return data.server.host;
	}

	static var data(get, null):ConnectionData;
	static function get_data():ConnectionData {
		if (data == null)
			return data = ConnectionData.setup(remote, useSsl);
		return data;
	}

	#if js
	public static function download(fileUrl:String, outPath:String, ?_):Void {
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

	public static function getVersions(library:ProjectName):Array<SemVer> {
		final versionsData = retry(data.site.infos.bind(library)).versions;
		return [for (data in versionsData) data.name];
	}

	public static function getVersionsForLibraries(libraries:Array<ProjectName>):Map<ProjectName, Array<SemVer>> {
		// TODO: can we collapse this into a single API call?  It's getting too slow otherwise.
		final map = new Map<ProjectName, Array<SemVer>>();

		for (lib in libraries) {
			final versionsData = retry(data.site.infos.bind(lib)).versions;
			map[lib] = [for(data in versionsData) data.name];
		}
		return map;
	}

	#if !js
	public static inline function createRequest():Http {
		return createHttpRequest('${data.server.protocol}://${data.server.host}:${data.server.port}/${data.server.url}');
	}

	static inline function createHttpRequest(url:String):Http {
		final req = new Http(url);
		req.addHeader("User-Agent", "haxelib " + Util.getHaxelibVersionLong());
		if (haxe.remoting.HttpConnection.TIMEOUT == 0)
			req.cnxTimeout = 0;
		return req;
	}

	/** Returns `true` if connection is successful, or `false` if it fails **/
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

	public static function getLatestVersion(library:ProjectName):SemVer
		return retry(data.site.getLatestVersion.bind(library));

	public static function getInfo(library:ProjectName):ProjectInfos
		return retry(data.site.infos.bind(library));

	public static function search(word:String)
		return retry(data.site.search.bind(word));

	public static function postInstall(library:ProjectName, version:SemVer)
		return retry(data.site.postInstall.bind(library, version));

	public static function getUserData(userName:String)
		return retry(data.site.user.bind(userName));

	public static function register(name:String, encodedPassword:String, email:String, fullname:String)
		return retry(data.site.register.bind(name, encodedPassword, email, fullname));

	public static function isNewUser(userName:String)
		return retry(data.site.isNewUser.bind(userName));

	public static function checkDeveloper(library:ProjectName, userName:String)
		return retry(data.site.checkDeveloper.bind(library, userName));

	public static function getSubmitId()
		return retry(data.site.getSubmitId.bind());

	public static function processSubmit(id:String, userName:String, password:String)
		return retry(data.site.processSubmit.bind(id, userName, password));

	public static function checkPassword(userName:String, password:String)
		return retry(data.site.checkPassword.bind(userName, password));
}
