package tests;

class TestRemoveSymlinksBroken extends TestRemoveSymlinks {
	public function new():Void {
		super();
		lib = "symlinks-broken";
	}
}
