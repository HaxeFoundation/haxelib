package tests;

import sys.FileSystem;
import haxelib.client.Vcs;

class TestGit extends TestVcs {
	static inline var REPO_PATH = 'test/repo/git';

	static public function init() {
		HaxelibTests.deleteDirectory(REPO_PATH);
		HaxelibTests.runCommand('git', ['clone', 'https://github.com/fzzr-/hx.signal.git', REPO_PATH]);
	}

	public function new():Void {
		super(VcsID.Git, "Git", FileSystem.fullPath(REPO_PATH), "0.9.2");
	}
}