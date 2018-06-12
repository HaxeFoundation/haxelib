package tests.integration;

import haxelib.*;
import IntegrationTests.*;
using IntegrationTests;
import haxe.io.*;

class TestDev extends IntegrationTests {
	function testDev():Void {
		{
			var r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			var r = haxelib(["path", "Bar"]).result();
			var out = ~/\r?\n/g.split(r.out);
			assertEquals(
				Path.addTrailingSlash(Path.normalize(sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])))),
				Path.addTrailingSlash(Path.normalize(out[0]))
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D Bar=1.0.0", out[1]);
			else
				assertEquals("-D Bar", out[1]);
			assertSuccess(r);
		}

		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testWrongPath():Void {
		{
			var r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar_not_exist"])]).result();
			// assertTrue(r.code != 0); //TODO
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testNoHaxelibJson():Void {
		{
			var r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "bin"])]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["path", "Bar"]).result();
			var out = ~/\r?\n/g.split(r.out);
			assertEquals(
				Path.addTrailingSlash(Path.normalize(sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "bin"])))),
				Path.addTrailingSlash(Path.normalize(out[0]))
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D Bar=0.0.0", out[1]);
			else
				assertEquals("-D Bar", out[1]);
			assertSuccess(r);
		}

		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testClassPath():Void {
		{
			var r = haxelib(["dev", "UseCp", Path.join([IntegrationTests.projectRoot, "test/libraries/UseCp"])]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "UseCp"]).result();
			assertTrue(r.out.indexOf("UseCp") >= 0);
			assertSuccess(r);
		}

		{
			var r = haxelib(["path", "UseCp"]).result();
			var out = ~/\r?\n/g.split(r.out);
			assertEquals(
				Path.addTrailingSlash(Path.normalize(sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "test/libraries/UseCp/lib/src"])))),
				Path.addTrailingSlash(Path.normalize(out[0]))
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D UseCp=0.0.1", out[1]);
			else
				assertEquals("-D UseCp", out[1]);
			assertSuccess(r);
		}

		{
			var r = haxelib(["remove", "UseCp"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "UseCp"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("UseCp") == -1);
		}
	}
}