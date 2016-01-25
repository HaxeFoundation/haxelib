package tests;

import haxelib.client.Vcs;

class TestHg extends TestVcs {
	public function new():Void {
		super(VcsID.Hg, "Mercurial", "https://bitbucket.org/fzzr/hx.signal", "78edb4b");
	}
}