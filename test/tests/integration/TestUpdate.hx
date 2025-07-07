package tests.integration;

import tests.util.Vcs;

class TestUpdate extends IntegrationTests {

	final gitLibPath = 'libraries/libBar';
	final hgLibPath = 'libraries/libBar';

	override function tearDown() {
		resetGitRepo(gitLibPath);
		resetHgRepo(hgLibPath);
		super.tearDown();
	}

	function test():Void {
		{
			final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["search", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["update", "Bar"]).result();
			assertSuccess(r);
			assertEquals("Library Bar is already up to date", r.out.trim());
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["update", "Bar"]).result();
			assertSuccess(r);
			assertFalse("Library Bar is already up to date\n" == r.out);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			final r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") < 0);
		}
	}

	// #529
	function testDifferentCapitalization():Void {
		{
			final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["search", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["update", "bar"]).result();
			assertSuccess(r);
			assertEquals("Library Bar is already up to date", r.out.trim());
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["update", "bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.contains("Current version is now 2.0.0"));
			assertFalse("Library Bar is already up to date" == r.out.trim());
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			final r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") < 0);
		}
	}

	function testUpdatingWithGitVersion():Void {
		makeGitRepo(gitLibPath);
		templateTestWithVcsVersion("git", gitLibPath);
	}

	function testUpdatingWithHgVersion():Void {
		makeHgRepo(hgLibPath);
		templateTestWithVcsVersion("hg", hgLibPath);
	}

	function templateTestWithVcsVersion(type:String, repoPath:String) {
		// #364
		final r = haxelib([type, "Bar", repoPath]).result();
		assertSuccess(r);

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf('Library Bar is already up to date') >= 0);

		// Don't show update message if vcs lib was already up to date
		assertTrue(r.out.indexOf("Bar was updated") < 0);

		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["install", "Bar"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		assertTrue(r.out.indexOf(type) >= 0);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf('Library Bar $type repository is already up to date') < 0);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		assertTrue(r.out.indexOf("1.0.0") >= 0);
		assertTrue(r.out.indexOf(type) >= 0);
	}
}
