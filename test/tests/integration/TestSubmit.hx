package tests.integration;

import tests.util.Vcs;

class TestSubmit extends IntegrationTests {
	final gitLibPath = "libraries/libBar";

	override function tearDown() {
		resetGitRepo(gitLibPath);
		super.tearDown();
	}

	function testNormal():Void {
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
			final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo.zip"]), foo.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["search", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}
	}

	function testLibraryWithGitDep() {
		// git deps should not be allowed in published versions
		// https://github.com/HaxeFoundation/haxelib/pull/344#issuecomment-244006799

		// first prepare the dependency
		makeGitRepo(gitLibPath);

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
			final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libFooGitDep.zip"]), foo.pw]).result();
			assertFail(r);
			assertEquals("Error: Git dependency is not allowed in a library release", r.err.trim());
		}

		{
			final r = haxelib(["search", "Foo"]).result();
			// did not get submitted
			assertFalse(r.out.indexOf("Foo") >= 0);
		}
	}

	function testInvalidLicense() {
		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libInvalidLicense.zip"]), bar.pw]).result();
		assertFail(r);
		assertEquals("Error: Invalid value `Unknown` for License. Allowed values: GPL, LGPL, MIT, BSD, Public, Apache", r.err.trim());

		final r = haxelib(["search", "Bar"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("Bar") >= 0);
	}
}
