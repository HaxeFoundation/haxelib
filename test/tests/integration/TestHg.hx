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
	}

	override function tearDown() {
		resetHgRepo(vcsLibPath);
		resetHgRepo(vcsLibNoHaxelibJson);

		super.tearDown();
	}
}
