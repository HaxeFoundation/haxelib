package tests;

import haxelib.client.Vcs;

class TestGit extends TestVcs {
	public function new():Void {
		super(VcsID.Git, "Git", "https://github.com/fzzr-/hx.signal.git", "0.9.2");
	}
}