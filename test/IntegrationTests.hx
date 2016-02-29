import haxe.unit.*;
import haxe.io.*;
import sys.*;
import sys.io.*;
using StringTools;
using IntegrationTests;

class IntegrationTests extends TestBase {
	var haxelibBin:String = Path.join([Sys.getCwd(), "bin", "haxelib.n"]);
	var siteUrl:String = "http://localhost:2000/";
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

	function haxelib(args:Array<String>):Process {
		#if system_haxelib
			return new Process("haxelib", ["-R", siteUrl].concat(args));
		#else
			return new Process("neko", [haxelibBin, "-R", siteUrl].concat(args));
		#end
	}

	function assertSuccess(r:{out:String, err:String, code:Int}, ?pos:haxe.PosInfos):Void {
		if (r.code != 0) {
			throw r;
		}
		assertEquals(0, r.code, pos);
	}

	function resetDB():Void {
		Sys.command("mysql", ["-u", "root", "-e", "DROP DATABASE IF EXISTS haxelib_test;"]);
		Sys.command("mysql", ["-u", "root", "-e", "CREATE DATABASE haxelib_test;"]);
		Sys.command("mysql", ["-u", "root", "-e", "grant all on haxelib_test.* to travis@localhost;"]);

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

		resetDB();

		deleteDirectory(repo);
		haxelibSetup(repo);
	}

	override function tearDown():Void {
		haxelibSetup(originalRepo);
		deleteDirectory(repo);

		resetDB();

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
	}

	static function main():Void {
		var prevDir = Sys.getCwd();

		var runner = new TestRunner();
		runner.add(new tests.integration.TestEmpty());
		runner.add(new tests.integration.TestSimple());
		var success = runner.run();

		if (!success) {
			Sys.exit(1);
		}
	}
}