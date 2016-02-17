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
	static var repo(default, never) = "repo_integration_tests";

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

	function testEmpty():Void {
		// the initial local and remote repos are empty

		var installResult = haxelib(["install", "foo"]).result();
		assertTrue(installResult.code != 0);

		var upgradeResult = haxelib(["upgrade"]).result();
		assertSuccess(upgradeResult);

		var updateResult = haxelib(["update", "foo"]).result();
		// assertTrue(updateResult.code != 0);

		var removeResult = haxelib(["remove", "foo"]).result();
		assertTrue(removeResult.code != 0);

		var upgradeResult = haxelib(["list"]).result();
		assertSuccess(upgradeResult);

		var removeResult = haxelib(["set", "foo", "0.0", "--always"]).result();
		assertTrue(removeResult.code != 0);

		var searchResult = haxelib(["search", "foo"]).result();
		assertSuccess(searchResult);
		assertTrue(searchResult.out.indexOf("0") >= 0);

		var infoResult = haxelib(["info", "foo"]).result();
		assertTrue(infoResult.code != 0);

		var userResult = haxelib(["user", "foo"]).result();
		assertTrue(userResult.code != 0);

		var configResult = haxelib(["config"]).result();
		assertSuccess(configResult);

		var pathResult = haxelib(["path", "foo"]).result();
		assertTrue(pathResult.code != 0);

		var versionResult = haxelib(["version"]).result();
		assertSuccess(versionResult);

		var helpResult = haxelib(["help"]).result();
		assertSuccess(helpResult);
	}

	function testNormal():Void {
		var bar = {
			user: "Bar",
			email: "bar@haxe.org",
			fullname: "Bar",
			pw: "barpassword",
		};
		var foo = {
			user: "Foo",
			email: "foo@haxe.org",
			fullname: "Foo",
			pw: "foopassword",
		};

		{
			var r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libBar.zip", bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["search", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libFoo.zip", foo.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["search", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}

		{
			var r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["install", "Foo"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}

		{
			var r = haxelib(["list"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["remove", "Foo"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Foo"]).result();
			assertTrue(r.out.indexOf("Foo") < 0);
			assertSuccess(r);
		}

		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") < 0);
		}
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
		runner.add(new IntegrationTests());
		var success = runner.run();

		if (!success) {
			Sys.exit(1);
		}
	}
}