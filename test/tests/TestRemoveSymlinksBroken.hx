package tests;

class TestRemoveSymlinksBroken extends TestRemoveSymlinks
{
	public function new():Void {
		super();
		this.lib = "symlinks-broken";
	}
}
