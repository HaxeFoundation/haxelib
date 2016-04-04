import haxe.unit.*;
import haxe.*;
import haxe.io.*;
import sys.*;
import sys.io.*;
import haxelib.*;
using StringTools;
using IntegrationTests;

class IntegrationTests extends TestBase {
	var haxelibBin:String = Path.join([Sys.getCwd(), "run.n"]);
	public var server(default, null):String = switch (Sys.getEnv("HAXELIB_SERVER")) {
		case null:
			"localhost";
		case url:
			url;
	};
	public var serverPort(default, null) = switch (Sys.getEnv("HAXELIB_SERVER_PORT")) {
		case null:
			2000;
		case port:
			Std.parseInt(port);
	};
	public var serverUrl(get, null):String;
	function get_serverUrl() return serverUrl != null ? serverUrl : serverUrl = 'http://${server}:${serverPort}/';

	static var originalRepo(default, never) = {
		var p = new Process("haxelib", ["config"]);
		var repo = Path.normalize(p.stdout.readLine());
		p.close();
		repo;
	};
	static public var repo(default, never) = "repo_integration_tests";
	static public var bar(default, never) = {
		user: "Bar",
		email: "bar@haxe.org",
		fullname: "Bar",
		pw: "barpassword",
	};
	static public var foo(default, never) = {
		user: "Foo",
		email: "foo@haxe.org",
		fullname: "Foo",
		pw: "foopassword",
	};
	public var clientVer(get, null):SemVer;
	var clientVer_inited = false;
	function get_clientVer() {
		return if (clientVer_inited)
			clientVer;
		else {
			clientVer = {
				var r = haxelib(["version"]).result();
				if (r.code == 0)
					SemVer.ofString(r.out.trim());
				else if (r.out.indexOf("3.1.0-rc.4") >= 0)
					SemVer.ofString("3.1.0-rc.4");
				else
					throw "unknown version";
			};
			clientVer_inited = true;
			clientVer;
		}
	}

	function haxelib(args:Array<String>, ?input:String):Process {
		var p = #if system_haxelib
			new Process("haxelib", ["-R", serverUrl].concat(args));
		#else
			new Process("neko", [haxelibBin, "-R", serverUrl].concat(args));
		#end

		if (input != null) {
			p.stdin.writeString(input);
			p.stdin.close();
		}

		return p;
	}

	function assertSuccess(r:{out:String, err:String, code:Int}, ?pos:haxe.PosInfos):Void {
		if (r.code != 0) {
			throw r;
		}
		assertEquals(0, r.code, pos);
	}

	function assertNoError(f:Void->Void):Void {
		f();
		assertTrue(true);
	}

	var dbConfig:Dynamic = Json.parse(File.getContent("www/dbconfig.json"));
	var dbCnx:sys.db.Connection;
	function resetDB():Void {
		var db = dbConfig.database;
		dbCnx.request('DROP DATABASE IF EXISTS ${db};');
		dbCnx.request('CREATE DATABASE ${db};');

		var filesPath = "www/files/3.0";
		for (item in FileSystem.readDirectory(filesPath)) {
			if (item.endsWith(".zip")) {
				FileSystem.deleteFile(Path.join([filesPath, item]));
			}
		}
		var tmpPath = "tmp";
		for (item in FileSystem.readDirectory(filesPath)) {
			if (item.endsWith(".tmp")) {
				FileSystem.deleteFile(Path.join([tmpPath, item]));
			}
		}
	}

	override function setup():Void {
		super.setup();

		dbCnx = sys.db.Mysql.connect({
			user: dbConfig.user,
			pass: dbConfig.pass,
			host: server,
			port: dbConfig.port,
			database: dbConfig.database,
		});
		resetDB();

		deleteDirectory(repo);
		haxelibSetup(repo);
	}

	override function tearDown():Void {
		haxelibSetup(originalRepo);
		deleteDirectory(repo);

		resetDB();
		dbCnx.close();

		super.tearDown();
	}

	static public function result(p:Process):{out:String, err:String, code:Int} {
		var out = p.stdout.readAll().toString();
		var err = p.stderr.readAll().toString();
		var code = p.exitCode();
		p.close();
		return {out:out, err:err, code:code};
	}

	static public function haxelibSetup(path:String):Void {
		var p = new Process("haxelib", ["setup", path]);
		if (p.exitCode() != 0)
			throw "unable to set haxelib repo to " + path;
		p.close();
	}

	static function main():Void {
		var prevDir = Sys.getCwd();

		var runner = new TestRunner();
		runner.add(new tests.integration.TestEmpty());
		runner.add(new tests.integration.TestSimple());
		runner.add(new tests.integration.TestUpgrade());
		runner.add(new tests.integration.TestUpdate());
		runner.add(new tests.integration.TestList());
		runner.add(new tests.integration.TestSet());
		runner.add(new tests.integration.TestInfo());
		runner.add(new tests.integration.TestUser());
		runner.add(new tests.integration.TestDev());
		var success = runner.run();

		if (!success) {
			Sys.exit(1);
		}
	}
}
