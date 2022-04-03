package tests.integration;

import tests.util.Vcs;

class TestGit extends TestVcs {
	function new () {
		super("git");
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
