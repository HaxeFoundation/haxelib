import haxe.unit.*;
import haxe.io.*;
import sys.io.*;

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

	override function setup():Void {
		super.setup();

		deleteDirectory(repo);
		haxelibSetup(repo);
	}

	override function tearDown():Void {
		haxelibSetup(originalRepo);
		deleteDirectory(repo);

		super.tearDown();
	}

	function testEmpty():Void {
		// the initial local and remote repos are empty

		var installResult = haxelib(["install", "foo"]).result();
		assertTrue(installResult.code != 0);

		var upgradeResult = haxelib(["upgrade"]).result();
		assertEquals(0, upgradeResult.code);

		var updateResult = haxelib(["update", "foo"]).result();
		// assertTrue(updateResult.code != 0);

		var removeResult = haxelib(["remove", "foo"]).result();
		assertTrue(removeResult.code != 0);

		var upgradeResult = haxelib(["list"]).result();
		assertEquals(0, upgradeResult.code);

		var removeResult = haxelib(["set", "foo", "0.0", "--always"]).result();
		assertTrue(removeResult.code != 0);

		var searchResult = haxelib(["search", "foo"]).result();
		assertTrue(searchResult.out.indexOf("0") >= 0);
		assertEquals(0, searchResult.code);

		var infoResult = haxelib(["info", "foo"]).result();
		assertTrue(infoResult.code != 0);

		var userResult = haxelib(["user", "foo"]).result();
		assertTrue(userResult.code != 0);

		var configResult = haxelib(["config"]).result();
		assertEquals(0, configResult.code);

		var pathResult = haxelib(["path", "foo"]).result();
		assertTrue(pathResult.code != 0);

		var versionResult = haxelib(["version"]).result();
		assertEquals(0, versionResult.code);

		var helpResult = haxelib(["help"]).result();
		assertEquals(0, helpResult.code);
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