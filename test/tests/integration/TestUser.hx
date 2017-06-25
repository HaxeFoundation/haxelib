package tests.integration;

import haxe.io.*;
import IntegrationTests.*;
using IntegrationTests;

class TestUser extends IntegrationTests {
	function test():Void {
		{
			var r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["user", "Bar"]).result();
			assertSuccess(r);

			assertTrue(r.out.indexOf("Bar") >= 0);

			assertTrue(r.out.indexOf(bar.email) >= 0);
			assertTrue(r.out.indexOf(bar.fullname) >= 0);
			assertTrue(r.out.indexOf(bar.pw) == -1);
		}

		{
			var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/UseCp.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["user", "Bar"]).result();
			assertSuccess(r);

			assertTrue(r.out.indexOf("Bar") >= 0);

			assertTrue(r.out.indexOf(bar.email) >= 0);
			assertTrue(r.out.indexOf(bar.fullname) >= 0);
			assertTrue(r.out.indexOf(bar.pw) == -1);

			assertTrue(r.out.indexOf("UseCp") >= 0);
		}
	}

	function testNotExist():Void {
		{
			var r = haxelib(["user", "Bar"]).result();
			assertTrue(r.code != 0);
		}
	}
}