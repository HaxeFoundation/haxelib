package tests.integration;

class TestSimple extends IntegrationTests {
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

		{
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "Foo"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}

		{
			final r = haxelib(["list"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["remove", "Foo"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Foo"]).result();
			assertTrue(r.out.indexOf("Foo") < 0);
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
