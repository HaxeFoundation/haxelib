package tests;

import sys.FileSystem;
import haxelib.client.Vcs;

class TestHg extends TestVcs {
	static inline var REPO_PATH = 'test/repo/hg';

	static public function init() {
		HaxelibTests.deleteDirectory(REPO_PATH);
		HaxelibTests.runCommand('hg', ['clone', 'https://bitbucket.org/fzzr/hx.signal', REPO_PATH]);
	}

	public function new():Void {
		super(VcsID.Hg, "Mercurial", FileSystem.fullPath(REPO_PATH), "78edb4b");
	}
}