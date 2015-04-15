package tests;

import sys.FileSystem;
import haxe.io.Path;
import haxe.unit.TestCase;

class TestRemoveSymlinks extends TestCase
{
	//----------- properties, fields ------------//

	static var REPO = "haxelib-repo";
	var lib:String = null;
	var repo:String = null;

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
		var libzip = Path.join([Sys.getCwd(), "test", "libraries", lib + ".zip"]);
		Sys.command("neko", ["./bin/haxelib.n", "setup", repo]);
		Sys.command("neko", ["./bin/haxelib.n", "local", libzip]);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void
	{
		var code = Sys.command("neko", ["./bin/haxelib.n", "remove", lib]);
		assertEquals(code, 0);
		assertFalse(FileSystem.exists(Path.join([repo, lib])));
	}


	//----------------- tools -------------------//

	function command(cmd:String, args:Array<String>)
	{
		var p = new sys.io.Process(cmd, args);
		var code = p.exitCode();
		return {code:code, out:code == 0 ? p.stdout.readAll().toString() : p.stderr.readAll().toString()};
	}
}
