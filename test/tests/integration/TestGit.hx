package tests.integration;

import tests.integration.Utils;

class TestGit extends TestVcs {
	function new () {
		super();
		cmd = "git";
	}

	override function setup() {
		super.setup();

		makeGitRepo(vcsLibPath);
		makeGitRepo(vcsLibNoHaxelibJson);
	}

	override function tearDown() {
		resetGitRepo(vcsLibPath);
		resetGitRepo(vcsLibNoHaxelibJson);

		super.tearDown();
	}
}
