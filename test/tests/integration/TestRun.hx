package tests.integration;

class TestRun extends IntegrationTests {

#if !system_haxelib
	override function setup() {
		super.setup();
		haxelib(["dev", "haxelib", IntegrationTests.projectRoot]);
		// haxelib calls in `haxelib run` have to redirect to the new version
	}
#end

	function testRunN_preferredOverRunHx():Void {
		final r = haxelib(["dev", "Bar2", "libraries/libBar2"]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Bar2"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);
	}

#if (haxe_ver >= 4.0)
	static final libEnvironment = "libraries/libEnvironment/";
	static final barDevPath = "libraries/libBar2/";
	static final barPath = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/1,0,0"]).addTrailingSlash();
	static final bar2Path = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/2,0,0"]).addTrailingSlash();

	override function tearDown() {
		Utils.resetGitRepo(libEnvironment);
		Utils.resetHgRepo(libEnvironment);

		super.tearDown();
	}

	function testMain():Void {
		final r = haxelib(["dev", "Baz", "libraries/libBaz"]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Baz"]).result();
		assertSuccess(r);
		assertEquals('Baz tools.Main script', r.out);
	}

	function testDifferentCapitalization():Void {
		// #529
		final r = haxelib(["dev", "Baz", "libraries/libBaz"]).result();
		assertSuccess(r);
		final r = haxelib(["run", "baz"]).result();
		assertSuccess(r);
		assertEquals('Baz tools.Main script', r.out);
	}

	function testMain_noValueButRunHxExists():Void {
		final r = haxelib(["dev", "Bar", "libraries/libBar"]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}

	function testEnvironment():Void {
		final r = haxelib(["dev", "Environment", libEnvironment]).result();
		assertSuccess(r);

		final r = haxelib(["run", "Environment", "cwd"]).result();
		assertSuccess(r);
		assertEquals(Sys.getCwd(), r.out);

		final r = haxelib(["run", "Environment", "get", "HAXELIB_RUN"]).result();
		assertSuccess(r);
		assertEquals("1", r.out);

		final r = haxelib(["run", "Environment", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);

		// environment should not change based on capitalization of lib given by user
		// #529
		final r = haxelib(["run", "environment", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);
	}

	function testAliasLibrary() {
		final r = haxelib(["dev", "alias", libEnvironment]).result();
		assertSuccess(r);

		// HAXELIB_RUN_NAME should always be set to the entry in `haxelib.json`, not the name input by the user
		final r = haxelib(["run", "alias", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);

		final r = haxelib(["run", "Alias", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);

		// unset alias
		final r = haxelib(["remove", "alias"]).result();
		assertSuccess(r);

		Utils.makeGitRepo(libEnvironment);

		final r = haxelib(["git", "alias", libEnvironment]).result();
		assertSuccess(r);

		// HAXELIB_RUN_NAME should always be set to the entry in `haxelib.json`, not the name input by the user
		final r = haxelib(["run", "alias", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);

		// unset alias
		final r = haxelib(["remove", "alias"]).result();
		assertSuccess(r);

		Utils.resetGitRepo(libEnvironment);
		Utils.makeHgRepo(libEnvironment);

		final r = haxelib(["hg", "alias", libEnvironment]).result();
		assertSuccess(r);

		// HAXELIB_RUN_NAME should always be set to the entry in `haxelib.json`, not the name input by the user
		final r = haxelib(["run", "alias", "get", "HAXELIB_RUN_NAME"]).result();
		assertSuccess(r);
		assertEquals("Environment", r.out);
	}

	function testVersionSpecification():Void {
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);
		final r = haxelib(["install", "libraries/libBar2.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the set version will be run
		final r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);

		// if we specify a version, we run that
		final r = haxelib(["run", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);

		// if we specify a missing version, we fail.
		final r = haxelib(["run", "Bar:1.1.0"]).result();
		assertFail(r);
		assertEquals("Error: Library Bar version 1.1.0 is not installed", r.err.trim());
	}

	function testVersionOverriding():Void {
		final bazPath = "libraries/libBaz";

		// # 249
		final r = haxelib(["dev", "Bar", bazPath]).result();
		assertSuccess(r);

		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the dev version will be run
		final r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Baz tools.Main script', r.out);

		// if we specify a version, we want that and not the dev version
		final r = haxelib(["run", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}
#end
}
