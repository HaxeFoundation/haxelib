package tests.integration;

abstract class TestVcs extends IntegrationTests {
	final cmd:String;

	final vcsLibPath = "libraries/libBar";
	final vcsLibNoHaxelibJson = "libraries/libNoHaxelibJson";

	function test() {

		final r = haxelib([cmd, "Bar", vcsLibPath]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertTrue(r.out.indexOf('[$cmd]') >= 0);

		final r = haxelib(["path", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([
				Path.join([projectRoot, repo, "bar", cmd]).addTrailingSlash(),
				'-D Bar=1.0.0'
			],
			r.out.trim()
		);
	}

	function testPreferenceOfHaxelibJsonName() {
		final r = haxelib([cmd, "bar", vcsLibPath]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
		// even though the user used "bar", we show "Bar" as that is what is found in haxelib.json
	}


	function testNameReplacement() {
		// if there is no haxelib.json, we use the last version of the name the user used
		final r = haxelib([cmd, "BAR", vcsLibNoHaxelibJson]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("BAR") >= 0);
		assertSuccess(r);

		final r = haxelib([cmd, "Bar", vcsLibNoHaxelibJson]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
	}

	function testNameCorrection() {
		// #529
		// installing a proper version will change the name set by a vcs version

		final r = haxelib([cmd, "BAR", vcsLibNoHaxelibJson]).result();
		assertSuccess(r);

		final r = haxelib(["list", "Bar"]).result();
		assertTrue(r.out.indexOf("BAR") >= 0);
		assertSuccess(r);

		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);

		// the proper version replaces the name shown in list

		final r = haxelib(["list", "Bar"]).result();
		assertFalse(r.out.indexOf("BAR") >= 0);
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);

		final r = haxelib([cmd, "BAR", vcsLibNoHaxelibJson]).result();
		assertSuccess(r);

		// remains like this even if dev is run again

		final r = haxelib(["list", "Bar"]).result();
		assertFalse(r.out.indexOf("BAR") >= 0);
		assertTrue(r.out.indexOf("Bar") >= 0);
		assertSuccess(r);
	}
}
