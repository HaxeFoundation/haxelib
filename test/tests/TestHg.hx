package tests;

import sys.FileSystem;
import haxelib.VersionData.VcsID;

class TestHg extends TestVcs {
	static final REPO_PATH = 'test/repo/hg';

	static public function init() {
		HaxelibTests.deleteDirectory(REPO_PATH);
		HaxelibTests.runCommand('hg', ['clone', 'https://github.com/fzzr-/hx.signal.git', REPO_PATH]);
	}

	public function new():Void {
		super(VcsID.Hg, "hg", FileSystem.fullPath(REPO_PATH), "78edb4b");
	}
}
