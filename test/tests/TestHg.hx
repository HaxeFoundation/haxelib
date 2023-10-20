package tests;

import sys.FileSystem;
import haxelib.VersionData.VcsID;

class TestHg extends TestVcs {
	static final REPO_PATH = 'test/repo/hg';

	static public function init() {
		HaxelibTests.deleteDirectory(REPO_PATH);
		HaxelibTests.runCommand('hg', ['clone', 'http://hg.code.sf.net/p/hx-signal/mercurial', REPO_PATH]);
	}

	public function new():Void {
		super(VcsID.Hg, "Mercurial", FileSystem.fullPath(REPO_PATH), "default", "b022617bccfb");
	}
}
