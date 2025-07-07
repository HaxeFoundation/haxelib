package tests.integration;

abstract class TestVcs extends IntegrationTests {
	final cmd:String;

	final vcsLibPath = "libraries/libBar";
	final vcsLibNoHaxelibJson = "libraries/libNoHaxelibJson";
	final vcsBrokenDependency = "libraries/libBrokenDep";
	final vcsTag = "v1.0.0";

	function new(cmd:String) {
		super();
		this.cmd = cmd;
	}

	abstract function updateVcsRepo():Void;

	abstract function getVcsCommit():String;

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

	function testAliasing() {
		// allowed to set dev name to something other than the name found in haxelib.json
		final r = haxelib([cmd, "bar-alias", vcsLibPath]).result();
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
		// #357 alias still has to be a valid project name
		final r = haxelib([cmd, "lib#", vcsLibPath]).result();
		assertFail(r);

		final r = haxelib(["list", "lib#"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("lib#") < 0);

		final r = haxelib([cmd, "lib//", vcsLibPath]).result();
		assertFail(r);

		final r = haxelib(["list", "lib//"]).result();
		assertSuccess(r);
		assertTrue(r.out.indexOf("lib//") < 0);
	}

	function testBrokenDependency() {

		final r = haxelib([cmd, "Foo", vcsBrokenDependency]).result();
		assertFail(r);
		assertOutputEquals([
			"Error: Failed installing dependencies for Foo:",
			"Could not clone Git repository."
		], r.err.trim());

	}


	function testVcsUpdateBranch() {

		final r = haxelib([cmd, "Bar", vcsLibPath, "main"]).result();
		assertSuccess(r);

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals(["Library Bar is already up to date"], r.out.trim());

		updateVcsRepo();

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([
			"Bar was updated",
  			'  Current version is now $cmd'
		], r.out.trim());

	}

	function testVcsUpdateCommit() {

		final r = haxelib([cmd, "Bar", vcsLibPath, getVcsCommit()]).result();
		assertSuccess(r);

		updateVcsRepo();

		// TODO: Doesn't work with hg
		if (cmd == "hg")
			return;

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals(["Library Bar is already up to date"], r.out.trim());

	}

	function testVcsUpdateTag() {

		final r = haxelib([cmd, "Bar", vcsLibPath, "main", "", "v1.0.0"]).result();
		assertSuccess(r);

		updateVcsRepo();

		// TODO: Doesn't work with hg
		if (cmd == "hg")
			return;

		final r = haxelib(["update", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals(["Library Bar is already up to date"], r.out.trim());

	}

}
