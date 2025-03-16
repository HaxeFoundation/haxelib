package tests.integration;

import tests.util.Vcs;

class TestGit extends TestVcs {
	public function new () {
		super("git");
	}

	override function setup() {
		super.setup();

		makeGitRepo(vcsLibPath);
		makeGitRepo(vcsLibNoHaxelibJson);
		makeGitRepo(vcsBrokenDependency);
	}

	override function tearDown() {
		resetGitRepo(vcsLibPath);
		resetGitRepo(vcsLibNoHaxelibJson);
		resetGitRepo(vcsBrokenDependency);

		super.tearDown();
	}
}
