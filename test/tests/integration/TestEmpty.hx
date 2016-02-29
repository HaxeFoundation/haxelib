package tests.integration;

import IntegrationTests.*;
using IntegrationTests;

class TestEmpty extends IntegrationTests {
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

		var removeResult = haxelib(["set", "foo", "0.0"], "y\n").result();
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
}