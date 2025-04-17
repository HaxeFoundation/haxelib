package tests.integration;

import haxelib.api.Connection;

import tests.util.Vcs;

class TestSubmit extends IntegrationTests {
	final gitLibPath = "libraries/libBar";
	final hgLibPath = "libraries/libBar";

	override function tearDown() {
		resetGitRepo(gitLibPath);
		resetHgRepo(gitLibPath);
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

	function testLibraryWithMissingDep() {
		final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libMissingDep.zip"]), foo.pw]).result();
		assertFail(r);
		assertEquals("Error: Library MissingDep does not exist", r.err.trim());

		final r = haxelib(["search", "Foo"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("Foo") >= 0);
	}

	function testLibraryWithMissingDepVersion() {
		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libMissingDepVersion.zip"]), foo.pw]).result();
		assertFail(r);
		assertEquals("Error: Library Bar does not have version 2.0.0", r.err.trim());

		trace("hello");

		final r = haxelib(["search", "Foo"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("Foo") >= 0);
	}

	function testLibraryWithGitDep() {
		// git deps should not be allowed in published versions
		// https://github.com/HaxeFoundation/haxelib/pull/344#issuecomment-244006799

		// first prepare the dependency
		makeGitRepo(gitLibPath);

		final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
		assertSuccess(r);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libFooGitDep.zip"]), foo.pw]).result();
		assertFail(r);
		assertEquals("Error: git dependency is not allowed in a library release", r.err.trim());

		final r = haxelib(["search", "Foo"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("Foo") >= 0);
	}

	function testLibraryWithHgDep() {
		// hg deps should not be allowed either
		makeHgRepo(hgLibPath);

		final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
		assertSuccess(r);

		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libFooHgDep.zip"]),
			foo.pw
		]).result();
		assertFail(r);
		assertEquals("Error: hg dependency is not allowed in a library release", r.err.trim());

		final r = haxelib(["search", "Foo"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("Foo") >= 0);
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

	function testGitFolder() {
		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libWithGitFolder.zip"]),
			bar.pw
		]).result();
		assertFail(r);
		assertEquals("Submission must not contain .git folder", r.err.trim().split(": ").pop());

		// also test submission with client side checks disabled
		try {
			Connection.submitLibrary(Path.join([IntegrationTests.projectRoot, "test/libraries/libWithGitFolder.zip"]), _ -> {
				password: bar.pw,
				name: bar.user
			}, false);
			assertTrue(false);
		} catch (e:String) {
			assertEquals("Submission must not contain .git folder", e.split(": ").pop());
		}

		final r = haxelib(["search", "libWithGitFolder"]).result();
		// did not get submitted
		assertFalse(r.out.indexOf("libWithGitFolder") >= 0);
	}
}
