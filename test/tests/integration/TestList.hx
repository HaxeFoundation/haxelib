package tests.integration;

import haxelib.SemVer;

class TestList extends IntegrationTests {
	function test():Void {
		{
			final r = haxelib(["list"]).result();
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
			final r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertTrue(r.out.indexOf("[1.0.0]") >= 0);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["update", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
			final pos1 = r.out.indexOf("1.0.0");
			final pos2 = r.out.indexOf("2.0.0");
			assertTrue(pos1 >= 0);
			assertTrue(pos2 >= 0);

			if (SemVer.compare(clientVer, SemVer.ofString("3.3.0")) >= 0) {
				assertTrue(pos2 >= pos1);
			}
		}
	}

	/**
		Make sure the version list is in ascending order, independent of the installation order.
	**/
	function testInstallNewThenOld():Void {
		{
			final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "Bar", "2.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "Bar", "1.0.0"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
			final pos1 = r.out.indexOf("1.0.0");
			final pos2 = r.out.indexOf("2.0.0");
			assertTrue(pos1 >= 0);
			assertTrue(pos2 >= 0);

			if (SemVer.compare(clientVer, SemVer.ofString("3.3.0")) >= 0) {
				assertTrue(pos2 >= pos1);
			}
		}
	}
}
