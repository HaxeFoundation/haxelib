package tests;

import sys.FileSystem;
import sys.io.*;
import haxe.io.Path;
import haxe.unit.TestCase;

class TestRemoveSymlinks extends TestBase
{
	//----------- properties, fields ------------//

	static var REPO = "haxelib-repo";
	var lib:String = null;
	var repo:String = null;
	var origRepo:String;

	//--------------- constructor ---------------//
	public function new(lib:String)
	{
		super();
		this.lib = lib;
		this.repo = Path.join([Sys.getCwd(), "testing", REPO]);
	}

	//--------------- initialize ----------------//

	override public function setup():Void
	{
		origRepo = runHaxelib(["config"]).stdout.split("\n")[0];

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
