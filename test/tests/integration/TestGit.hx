package tests.integration;

import haxelib.api.FsUtils;
import haxelib.api.Vcs;
import tests.util.Vcs;

class TestGit extends TestVcs {
	public function new () {
		super("git");
	}

	override function setup() {
		super.setup();

		makeGitRepo(vcsLibPath, ["haxelib.xml"]);
		createGitTag(vcsLibPath, vcsTag);

		makeGitRepo(vcsLibNoHaxelibJson);
		makeGitRepo(vcsBrokenDependency);
	}

	override function tearDown() {
		resetGitRepo(vcsLibPath);
		resetGitRepo(vcsLibNoHaxelibJson);
		resetGitRepo(vcsBrokenDependency);

		super.tearDown();
	}

	public function updateVcsRepo() {
		addToGitRepo(vcsLibPath, "haxelib.xml");
	}

	public function getVcsCommit():String {
		return FsUtils.runInDirectory(vcsLibPath, Vcs.create(Git).getRef);
	}

	function testInstallShortcommit() {

		final shortCommitId = getVcsCommit().substr(0, 7);

		updateVcsRepo();

		final r = haxelib([cmd, "Bar", vcsLibPath, shortCommitId]).result();
		assertSuccess(r);

	}
}
