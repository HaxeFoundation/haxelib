package tests.integration;

class TestUpgrade extends IntegrationTests {
	function test():Void {
		{
			final r = haxelib(["upgrade"]).result();
			assertSuccess(r);
		}

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
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		}

		{
			final r = haxelib(["upgrade"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["upgrade"], "y\n").result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			final r = haxelib(["upgrade"]).result();
			assertSuccess(r);
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
}
