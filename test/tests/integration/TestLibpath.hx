package tests.integration;

class TestLibpath extends IntegrationTests {
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
}
