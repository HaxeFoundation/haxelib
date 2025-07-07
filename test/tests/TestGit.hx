package tests;

import sys.FileSystem;
import haxelib.VersionData.VcsID;

class TestGit extends TestVcs {
	static final REPO_PATH = 'test/repo/git';

	static public function init() {
		HaxelibTests.deleteDirectory(REPO_PATH);
		HaxelibTests.runCommand('git', ['clone', 'https://github.com/fzzr-/hx.signal.git', REPO_PATH]);
	}

	public function new():Void {
		super(VcsID.Git, "git", FileSystem.fullPath(REPO_PATH), "develop", "2feb1476dadd66ee0aa20587b1ee30a6b4faac0f");
	}
}
