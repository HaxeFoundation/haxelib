package tests;

import haxe.unit.TestCase;

class TestRemoveSymlinks extends TestCase
{
	//----------- properties, fields ------------//

	//--------------- constructor ---------------//
	public function new()
	{
		super();
	}


	//--------------- initialize ----------------//

	override public function setup():Void
	{
		Sys.command("neko", ["./bin/haxelib.n", "setup", Sys.getCwd() + "haxelib-repo"]);
		Sys.command("neko", ["./bin/haxelib.n", "install", "nme-dev", "1.3.2", "--always"]);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void
	{
		var code = Sys.command("neko", ["./bin/haxelib.n", "remove", "nme-dev"]);
		assertEquals(code, 0);
	}


	//----------------- tools -------------------//

	function command(cmd:String, args:Array<String>)
	{
		var p = new sys.io.Process(cmd, args);
		var code = p.exitCode();
		return {code:code, out:code == 0 ? p.stdout.readAll().toString() : p.stderr.readAll().toString()};
	}
}
