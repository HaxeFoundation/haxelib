package tests.integration;

import tests.util.Vcs;

class TestHg extends TestVcs {
	function new () {
		super("hg");
	}

	override function setup() {
		super.setup();

		makeHgRepo(vcsLibPath);
		makeHgRepo(vcsLibNoHaxelibJson);
		makeHgRepo(vcsBrokenDependency);
	}

	override function tearDown() {
		resetHgRepo(vcsLibPath);
		resetHgRepo(vcsLibNoHaxelibJson);
		resetHgRepo(vcsBrokenDependency);

		super.tearDown();
	}
}
