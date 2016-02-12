package tests;

import sys.FileSystem;
import sys.io.*;
import haxe.io.Path;
import haxe.unit.TestCase;

class TestRemoveSymlinks extends TestBase
{
	//----------- properties, fields ------------//

	static var REPO = "haxelib-repo";
	var lib:String = "symlinks";
	var repo:String = null;
	var origRepo:String;

	//--------------- constructor ---------------//
	public function new()
	{
		super();
		this.repo = Path.join([Sys.getCwd(), "test", REPO]);
	}

	//--------------- initialize ----------------//

	override public function setup():Void
	{
		origRepo = ~/\r?\n/.split(runHaxelib(["config"]).stdout)[0];
		origRepo = Path.normalize(origRepo);

		var libzip = Path.join([Sys.getCwd(), "test", "libraries", lib + ".zip"]);
		if (runHaxelib(["setup", repo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		if (runHaxelib(["local", libzip]).exitCode != 0) {
			throw "haxelib local failed";
		}
	}

	override public function tearDown():Void {
		if (runHaxelib(["setup", origRepo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		deleteDirectory(repo);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void
	{
		var code = runHaxelib(["remove", lib]).exitCode;
		assertEquals(code, 0);
		assertFalse(FileSystem.exists(Path.join([repo, lib])));
	}
}
