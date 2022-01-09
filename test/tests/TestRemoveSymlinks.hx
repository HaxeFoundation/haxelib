package tests;

import sys.FileSystem;
import haxe.io.Path;

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
		origRepo = Path.normalize(~/\r?\n/.split(runHaxelib(["config"]).stdout)[0]);

		final libzip = Path.join([Sys.getCwd(), "test", "libraries", lib + ".zip"]);
		if (runHaxelib(["setup", repo]).exitCode != 0)
			throw "haxelib setup failed";

		if (runHaxelib(["local", libzip]).exitCode != 0)
			throw "haxelib local failed";
	}

	override public function tearDown():Void {
		if (runHaxelib(["setup", origRepo]).exitCode != 0)
			throw "haxelib setup failed";

		deleteDirectory(repo);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void {
		final code = runHaxelib(["remove", lib]).exitCode;
		assertEquals(code, 0);
		assertFalse(FileSystem.exists(Path.join([repo, lib])));
	}
}
