package tests.integration;

import tests.util.Vcs;

class TestInstall extends IntegrationTests {

	final gitLibPath = "libraries/libBar";
	final hgLibPath = "libraries/libBar";

	var fileServerProcess:sys.io.Process;

	override function setup(){
		super.setup();

		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);
		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
		assertSuccess(r);
		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
		assertSuccess(r);

		final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
		assertSuccess(r);
		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo.zip"]), foo.pw]).result();
		assertSuccess(r);

		fileServerProcess = new sys.io.Process("nekotools", [
			"server",
			"-d", Path.join([IntegrationTests.projectRoot, "test/libraries"
		])]);
	}

	override function tearDown() {
		resetGitRepo(gitLibPath);
		resetHgRepo(hgLibPath);

		fileServerProcess.kill();

		super.tearDown();
	}

	function testNormal():Void {
		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

	}

	// for issue #529
	function testDifferentCapitalization() {
		{
			final r = haxelib(["install", "bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "bar"]).result();
			assertEquals("Bar version 2.0.0 is already installed and set as current.", r.out.trim());
			// recognises that we already have the newest version
		}

		{
			final r = haxelib(["install", "Bar"]).result();
			assertEquals("Bar version 2.0.0 is already installed and set as current.", r.out.trim());
			// recognises that we already have the newest version
		}
	}

	function testFromHaxelibJson() {
		final haxelibJson = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/haxelib.json"]);

		{
			final r = haxelib(["install", haxelibJson]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}
	}
	// for issue #529
	function testFromHaxelibJson_DifferentCapitalization() {
		final haxelibJson = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/other_haxelib.json"]);

		{
			final r = haxelib(["install", haxelibJson]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}
	}

	function testFromHaxelibJsonWithSkipDependencies() {
		final haxelibJson = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/other_foo_haxelib.json"]);

		{
			final r = haxelib(["install", haxelibJson, "--skip-dependencies"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list"]).result();
			assertSuccess(r);
			// Foo was still installed
			assertTrue(r.out.indexOf("Foo") >= 0);
			// but bar wasn't
			assertTrue(r.out.indexOf("Bar") < 0);
		}
	}

	function testFromHxml() {
		final hxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/build.hxml"]);

		{
			final r = haxelib(["install", hxml, "--always"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}
	}

	public function testFromHxmlUpgrade() {
		final newHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/build.hxml"]);
		final oldHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/old_build.hxml"]);

		final r = haxelib(["install", newHxml, "--always"]).result();
		assertSuccess(r);

		final r = haxelib(["install", oldHxml, "--always"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertTrue(r.out.contains("[1.0.0]"));
		assertTrue(r.out.contains("2.0.0"));
		assertFalse(r.out.contains("[2.0.0]"));
		assertSuccess(r);
	}

	public function testFromHxmlDowngrade() {
		final newHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/build.hxml"]);
		final oldHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/old_build.hxml"]);

		final r = haxelib(["install", oldHxml, "--always"]).result();
		assertSuccess(r);

		final r = haxelib(["install", newHxml, "--always"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertTrue(r.out.contains("[2.0.0]"));
		assertTrue(r.out.contains("1.0.0"));
		assertFalse(r.out.contains("[1.0.0]"));
		assertSuccess(r);
	}

	public function testFromHxmlExistingLibraries() {
		final newHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/build.hxml"]);
		final oldHxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/old_build.hxml"]);

		// install all versions so they are available
		final r = haxelib(["install", oldHxml, "--always"]).result();
		assertSuccess(r);
		final r = haxelib(["install", newHxml, "--always"]).result();
		assertSuccess(r);

		final r = haxelib(["install", oldHxml, "--always"]).result();
		// no downloads should have taken place as all libs are already available
		assertFalse(r.out.contains("Download complete: "));
		assertTrue(r.out.contains("Library Bar current version is now 1.0.0"));
		assertSuccess(r);
	}

	// for issue #529 and #503
	function testFromHxml_DifferentCapitalization() {
		final hxml = Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo/other_build.hxml"]);

		{
			final r = haxelib(["install", hxml, "--always"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}
	}

	function testLocalWithInvalidLicense() {
		// unknown license should not prevent install
		final r = haxelib(["install", "libraries/libInvalidLicense.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
	}

	function testLocalWithGitDependency() {
		// prepare git dependency
		makeGitRepo(gitLibPath);

		final r = haxelib(["install", "libraries/libFooGitDep.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Foo"]).result();
		assertTrue(r.out.indexOf("Foo") >= 0);
		assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertTrue(r.out.indexOf("[git]") >= 0);
		assertSuccess(r);
	}

	function testLocalWithHgDependency() {
		// prepare hg dependency
		makeHgRepo(hgLibPath);

		final r = haxelib(["install", "libraries/libFooHgDep.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Foo"]).result();
		assertTrue(r.out.indexOf("Foo") >= 0);
		assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertTrue(r.out.indexOf("[hg]") >= 0);
		assertSuccess(r);
	}

	function testLocalWithBrokenDependency() {

		final r = haxelib(["install", "libraries/libBrokenDep.zip"]).result();
		assertFail(r);
		assertOutputEquals(["Error: Failed installing dependencies for Foo:", "Could not clone Git repository."], r.err.trim());

	}

	function testZipFromHttp() {
		final r = haxelib(["install", "http://localhost:2000/libBar.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
	}
}
