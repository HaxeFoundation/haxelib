package tests.integration;

import IntegrationTests.*;
using IntegrationTests;
using StringTools;

class TestUpgrade extends IntegrationTests {
	function test():Void {
		{
			var r = haxelib(["upgrade"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libBar.zip", bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["search", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		}

		{
			var r = haxelib(["upgrade"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libBar2.zip", bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["upgrade"], "y\n").result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("[2.0.0]") >= 0);
			assertTrue(r.out.indexOf("1.0.0") >= 0);
		}

		{
			var r = haxelib(["upgrade"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") < 0);
		}
	}
}