package tests.integration;

import haxelib.SemVer;

class TestDev extends IntegrationTests {
	function testDev():Void {
		{
			final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["path", "Bar"]).result();
			final out = ~/\r?\n/g.split(r.out);
			assertEquals(
				sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])).normalize().addTrailingSlash(),
				out[0].normalize().addTrailingSlash()
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D Bar=1.0.0", out[1]);
			else
				assertEquals("-D Bar", out[1]);
			assertSuccess(r);
		}

		{
			final r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testWrongPath():Void {
		{
			final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar_not_exist"])]).result();
			// assertTrue(r.code != 0); //TODO
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testNoHaxelibJson():Void {
		{
			final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "bin"])]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			final r = haxelib(["path", "Bar"]).result();
			final out = ~/\r?\n/g.split(r.out);
			assertEquals(
				sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "bin"])).normalize().addTrailingSlash(),
				out[0].normalize().addTrailingSlash()
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D Bar=0.0.0", out[1]);
			else
				assertEquals("-D Bar", out[1]);
			assertSuccess(r);
		}

		{
			final r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") == -1);
		}
	}

	function testClassPath():Void {
		{
			final r = haxelib(["dev", "UseCp", Path.join([IntegrationTests.projectRoot, "test/libraries/UseCp"])]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "UseCp"]).result();
			assertTrue(r.out.indexOf("UseCp") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["path", "UseCp"]).result();
			final out = ~/\r?\n/g.split(r.out);
			assertEquals(
				sys.FileSystem.fullPath(Path.join([IntegrationTests.projectRoot, "test/libraries/UseCp/lib/src"])).normalize().addTrailingSlash(),
				out[0].normalize().addTrailingSlash()
			);
			if (clientVer > SemVer.ofString("3.1.0-rc.4"))
				assertEquals("-D UseCp=0.0.1", out[1]);
			else
				assertEquals("-D UseCp", out[1]);
			assertSuccess(r);
		}

		{
			final r = haxelib(["remove", "UseCp"]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "UseCp"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("UseCp") == -1);
		}
	}
}
