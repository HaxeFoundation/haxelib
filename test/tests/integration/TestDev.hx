package tests.integration;

import haxelib.SemVer;

class TestDev extends IntegrationTests {
	final libNoHaxelibJson = "libraries/libNoHaxelibJson";

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

	function testPreferenceOfHaxelibJsonName() {
		final r = haxelib(["dev", "bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar", "--quiet"]).result();
		assertTrue(r.out.startsWith("Bar"));
		assertSuccess(r);
		// even though the user used "bar", we show "Bar" as that is what is found in haxelib.json
	}

	function testWrongPath():Void {
		{
			final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar_not_exist"])]).result();
			assertFalse(r.code == 0);
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
			final r = haxelib(["dev", "Bar", libNoHaxelibJson]).result();
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
				sys.FileSystem.fullPath(libNoHaxelibJson).normalize().addTrailingSlash(),
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

	function testNameReplacement() {
		// if there is no haxelib.json, we use the last version of the name the user used

		final r = haxelib(["dev", "BAR", libNoHaxelibJson]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("BAR") >= 0);
		assertSuccess(r);

		final r = haxelib(["dev", "Bar", libNoHaxelibJson]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
	}

	function testNameCorrection() {
		// when a proper version is installed, the capitalization of the library is overwritten
		// #529
		{
			final r = haxelib(["dev", "BAR", libNoHaxelibJson]).result();
			assertSuccess(r);
		}

		{
			final r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("BAR") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["install", "libraries/libBar.zip"]).result();
			assertSuccess(r);
		}

		// the proper version replaces the name shown in list
		{
			final r = haxelib(["list", "Bar"]).result();
			assertFalse(r.out.indexOf("BAR") >= 0);
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			final r = haxelib(["dev", "BAR", libNoHaxelibJson]).result();
			assertSuccess(r);
		}

		// remains like this even if dev is run again
		{
			final r = haxelib(["list", "Bar"]).result();
			assertFalse(r.out.indexOf("BAR") >= 0);
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}
	}

	function testAliasing() {
		// allowed to set dev name to something other than the name found in haxelib.json
		final r = haxelib(["dev", "bar-alias", "libraries/libBar"]).result();
		assertSuccess(r);

		final r = haxelib(["list", "bar-alias"]).result();
		assertTrue(r.out.indexOf("bar-alias") >= 0);
		assertSuccess(r);

		// however, the define given by path (-D ...) still uses the actual name
		final r = haxelib(["path", "bar-alias"]).result();
		assertSuccess(r);
		assertTrue(r.out.trim().endsWith('-D Bar=1.0.0'));
	}

	function testInvalidAliasing() {
		// #357
		final r = haxelib(["dev", "lib#", "libraries/libBar"]).result();
		assertFail(r);

		final r = haxelib(["list", "lib#"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("lib#") < 0);

		final r = haxelib(["dev", "lib//", "libraries/libBar"]).result();
		assertFail(r);

		final r = haxelib(["list", "lib//"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("lib//") < 0);
	}
}
