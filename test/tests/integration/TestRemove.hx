package tests.integration;

class TestRemove extends IntegrationTests {

	override function setup() {
		super.setup();
		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);

		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]),
			bar.pw
		]).result();
		assertSuccess(r);

		final r = haxelib(["install", "Bar"]).result();
		assertSuccess(r);
	}


	function testNormal():Void {
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

	// for issue #529
	function testDifferentCapitalization() {
		{
			final r = haxelib(["remove", "bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") < 0);
		}
	}
}
