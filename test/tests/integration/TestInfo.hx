package tests.integration;

import IntegrationTests.*;
using IntegrationTests;

class TestInfo extends IntegrationTests {
	function test():Void {
		{
			var r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libBar.zip", bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["info", "Bar"]).result();
			assertSuccess(r);

			assertTrue(r.out.indexOf("Bar") >= 0);

			// license
			assertTrue(r.out.indexOf("GPL") >= 0);

			// tags
			assertTrue(r.out.indexOf("bar") >= 0);
			assertTrue(r.out.indexOf("test") >= 0);

			// versions
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			var r = haxelib(["submit", "test/libraries/libBar2.zip", bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["info", "Bar"]).result();
			assertSuccess(r);

			assertTrue(r.out.indexOf("Bar") >= 0);

			// license
			assertTrue(r.out.indexOf("MIT") >= 0);

			// tags
			assertTrue(r.out.indexOf("bar") >= 0);
			assertTrue(r.out.indexOf("test") == -1);
			assertTrue(r.out.indexOf("version2") >= 0);

			// versions
			assertTrue(r.out.indexOf("1.0.0") >= 0);
			assertTrue(r.out.indexOf("2.0.0") >= 0);
		}
	}

	function testNotExist():Void {
		{
			var r = haxelib(["info", "Bar"]).result();
			assertTrue(r.code != 0);
		}
	}
}