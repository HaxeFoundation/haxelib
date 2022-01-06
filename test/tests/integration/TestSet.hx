package tests.integration;

import sys.FileSystem;

class TestSet extends IntegrationTests {

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
		Utils.resetGitRepo('libraries/libBar');

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
		final gitPath = '${projectRoot}test/libraries/libBar';

		Utils.makeGitRepo(gitPath);

		final r = haxelib(["git", "Bar", gitPath]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("[git]") >= 0);

		final r = haxelib(["install", "Bar"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("[2.0.0]") >= 0);
		assertTrue(r.out.indexOf("git") >= 0);

		final r = haxelib(["set", "Bar", "git"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("2.0.0") >= 0);
		assertTrue(r.out.indexOf("[git]") >= 0);
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
