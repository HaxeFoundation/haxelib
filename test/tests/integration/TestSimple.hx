package tests.integration;

import IntegrationTests.*;
using IntegrationTests;

class TestSimple extends IntegrationTests {
	function testNormal():Void {
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
			var r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", "test/libraries/libFoo.zip", foo.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["search", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}

		{
			var r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["install", "Foo"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Foo"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
		}

		{
			var r = haxelib(["list"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Foo") >= 0);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["remove", "Foo"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Foo"]).result();
			assertTrue(r.out.indexOf("Foo") < 0);
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