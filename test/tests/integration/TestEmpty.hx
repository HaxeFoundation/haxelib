package tests.integration;

import haxe.Http;
import haxelib.SemVer;

class TestEmpty extends IntegrationTests {
	function testEmpty():Void {
		// the initial local and remote repos are empty

		final installResult = haxelib(["install", "foo"]).result();
		assertTrue(installResult.code != 0);

		final upgradeResult = haxelib(["upgrade"]).result();
		assertSuccess(upgradeResult);

		final updateResult = haxelib(["update", "foo"]).result();
		assertTrue(updateResult.code != 0);

		final removeResult = haxelib(["remove", "foo"]).result();
		assertTrue(removeResult.code != 0);

		final upgradeResult = haxelib(["list"]).result();
		assertSuccess(upgradeResult);

		final removeResult = haxelib(["set", "foo", "0.0"], "y\n").result();
		assertTrue(removeResult.code != 0);

		final searchResult = haxelib(["search", "foo"]).result();
		assertSuccess(searchResult);
		assertTrue(searchResult.out.indexOf("0") >= 0);

		final infoResult = haxelib(["info", "foo"]).result();
		assertTrue(infoResult.code != 0);

		final userResult = haxelib(["user", "foo"]).result();
		assertTrue(userResult.code != 0);

		final configResult = haxelib(["config"]).result();
		assertSuccess(configResult);

		final pathResult = haxelib(["path", "foo"]).result();
		assertTrue(pathResult.code != 0);

		if (clientVer > SemVer.ofString("3.1.0-rc.4")) {
			final versionResult = haxelib(["version"]).result();
			assertSuccess(versionResult);

			final helpResult = haxelib(["help"]).result();
			assertSuccess(helpResult);
		}
	}

	function testWebsite():Void {
		// home page
		assertNoError(function() Http.requestUrl(serverUrl));

		// Haxelib Tags
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "t"])));

		// All Haxelibs
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "all"])));

		// Haxelib Contributors
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "u"])));

		// docs
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "documentation"])));
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "documentation/using-haxelib"])));
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "documentation/creating-a-haxelib-package/"])));
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "documentation/creating-a-haxelib-package/"])));

		// RSS feed
		assertNoError(function() Http.requestUrl(Path.join([serverUrl, "rss"])));
	}
}
