package tests;

import sys.FileSystem;
import haxe.io.Path;

import haxelib.api.RepoManager;
import haxelib.api.Installer;
import haxelib.api.Scope;

class TestRemoveSymlinks extends TestBase
{
	//----------- properties, fields ------------//

	static final REPO = "haxelib-repo";
	final repo:String;
	var lib:String;
	var origRepo:String;

	//--------------- constructor ---------------//
	public function new() {
		super();
		lib = "symlinks";

		repo = Path.join([Sys.getCwd(), "test", REPO]);
	}

	//--------------- initialize ----------------//

	override public function setup():Void {
		origRepo = RepoManager.getGlobalPath();

		final libzip = Path.join([Sys.getCwd(), "test", "libraries", lib + ".zip"]);

		RepoManager.setGlobalPath(repo);

		final installer = new Installer(getScope());
		installer.installLocal(libzip);
	}

	override public function tearDown():Void {
		RepoManager.setGlobalPath(origRepo);

		deleteDirectory(repo);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void {
		final code = runHaxelib(["remove", lib]).exitCode;
		assertEquals(code, 0);
		assertFalse(FileSystem.exists(Path.join([repo, lib])));
	}
}
