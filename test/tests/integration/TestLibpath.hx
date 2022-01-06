package tests.integration;

class TestLibpath extends IntegrationTests {
	static final barDevPath = "libraries/libBar2/";
	static final barPath = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/1,0,0"]).addTrailingSlash();
	static final bar2Path = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/2,0,0"]).addTrailingSlash();

	override function setup() {
		super.setup();

		final r = haxelib(["install", Path.join([projectRoot, "test/libraries/libBar.zip"])]).result();
		assertSuccess(r);

		final r = haxelib(["install", Path.join([projectRoot, "test/libraries/libBar2.zip"])]).result();
		assertSuccess(r);

		final r = haxelib(["install", Path.join([projectRoot, "test/libraries/libFoo.zip"]), "--skip-dependencies"]).result();
		assertSuccess(r);
	}

	function testMain() {
		final r = haxelib(["libpath", "Bar"]).result();
		assertSuccess(r);
		assertEquals(Path.join([projectRoot, repo, "bar/2,0,0"]).addTrailingSlash(), r.out.trim());

		final r = haxelib(["libpath", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals(Path.join([projectRoot, repo, "bar/1,0,0"]).addTrailingSlash(), r.out.trim());

		final r = haxelib(["libpath", "Bar", "Foo"]).result();
		assertSuccess(r);
		assertOutputEquals([
				Path.join([projectRoot, repo, "bar/2,0,0"]).addTrailingSlash(),
				Path.join([projectRoot, repo, "foo/0,1,0-alpha,0"]).addTrailingSlash()
			],
			r.out.trim()
		);
	}

	// #529
	function testDifferentCapitalization() {
		final r = haxelib(["libpath", "bar"]).result();
		assertSuccess(r);
		assertEquals(Path.join([projectRoot, repo, "bar/2,0,0"]).addTrailingSlash(), r.out.trim());

		final r = haxelib(["libpath", "bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals(Path.join([projectRoot, repo, "bar/1,0,0"]).addTrailingSlash(), r.out.trim());

		final r = haxelib(["libpath", "bar", "foo"]).result();
		assertSuccess(r);
		assertOutputEquals([
				Path.join([projectRoot, repo, "bar/2,0,0"]).addTrailingSlash(),
				Path.join([projectRoot, repo, "foo/0,1,0-alpha,0"]).addTrailingSlash()
			],
			r.out.trim()
		);
	}

	function testVersionSpecification():Void {
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);
		final r = haxelib(["install", "libraries/libBar2.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the dev version will be run
		final r = haxelib(["libpath", "Bar"]).result();
		assertSuccess(r);
		assertEquals(bar2Path, r.out.trim());

		// if we specify a version, we want that and not the dev version
		final r = haxelib(["libpath", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals(barPath, r.out.trim());

		// if we specify a missing version, we fail.
		final r = haxelib(["libpath", "Bar:1.1.0"]).result();
		assertFail(r);
		assertEquals("Error: Library Bar version 1.1.0 is not installed", r.err.trim());
	}

	function testVersionOverriding() {
		// # 249
		final r = haxelib(["dev", "Bar", barDevPath]).result();
		assertSuccess(r);

		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the dev version will be run
		final r = haxelib(["libpath", "Bar"]).result();
		assertSuccess(r);
		final devPath = sys.FileSystem.absolutePath(barDevPath).addTrailingSlash();
		assertEquals(devPath, r.out.trim());

		// if we specify a version, we want that and not the dev version
		final r = haxelib(["libpath", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertEquals(barPath, r.out.trim());
	}
}
