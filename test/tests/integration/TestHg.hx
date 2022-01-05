package tests.integration;

import tests.integration.Utils;

class TestHg extends TestVcs {
	function new () {
		super();
		cmd = "hg";
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
