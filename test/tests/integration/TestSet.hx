package tests.integration;

import sys.FileSystem;

import tests.util.Vcs;

class TestSet extends IntegrationTests {
	final gitLibPath = "libraries/libBar";
	final hgLibPath = "libraries/libBar";

	override function setup() {
		super.setup();

		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
		assertSuccess(r);
	}

	override function tearDown() {
		resetGitRepo(gitLibPath);
		resetHgRepo(hgLibPath);

		super.tearDown();
	}

	function test():Void {
		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		}

		{
			final r = haxelib(["install", "Bar", "1.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			final r = haxelib(["set", "Bar", "1.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
			assertTrue(r.out.indexOf("2.0.0") >= 0);
		}

		{
			final r = haxelib(["set", "Bar", "2.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		}
	}

	// for issue #529
	function testDifferentCapitalization() {
		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "Bar", "1.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			final r = haxelib(["set", "bar", "1.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
			assertTrue(r.out.indexOf("2.0.0") >= 0);
		}

		{
			final r = haxelib(["set", "bar", "2.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		}
	}

	function testMissing() {
		{
			final r = haxelib(["install", "Bar", "2.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["set", "Bar", "1.0.0", "--always"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
			assertTrue(r.out.indexOf("2.0.0") >= 0);
		}
	}

	function testMissing_DifferentCapitalization() {
		{
			final r = haxelib(["install", "Bar", "2.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["set", "bar", "1.0.0", "--always"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
			assertTrue(r.out.indexOf("2.0.0") >= 0);
		}
	}

	function testGit() {
		makeGitRepo(gitLibPath);
		templateVcs("git", gitLibPath);
	}

	function testHg() {
		makeHgRepo(hgLibPath);
		templateVcs("hg", hgLibPath);
	}

	function templateVcs(type:String, repoPath:String) {
		final r = haxelib([type, "Bar", repoPath]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf('[$type]') >= 0);

		final r = haxelib(["install", "Bar"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		assertTrue(r.out.indexOf(type) >= 0);

		final r = haxelib(["set", "Bar", type]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("2.0.0") >= 0);
		assertTrue(r.out.indexOf('[$type]') >= 0);
	}

	function testInvalidVersion() {
		// #526
		final r = haxelib(["install", "Bar"]).result();
		assertSuccess(r);

		FileSystem.createDirectory(Path.join([projectRoot, repo, "bar", "invalid"]));

		final r = haxelib(["set", "Bar", "invalid"]).result();
		assertFail(r);
	}
}
