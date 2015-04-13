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
		Sys.command("neko", ["bin/haxelib.n", "install", "nme-dev", "1.3.2", "--always"]);
	}

	//----------------- tests -------------------//

	public function testRemoveLibWithSymlinks():Void
	{
		var result = command("neko", ["bin/haxelib.n", "remove", "nme-dev"]);
		assertEquals(0, result.code);
		assertEquals("library nme-dev removed", StringTools.trim(result.out).toLowerCase());
	}


	//----------------- tools -------------------//

	function command(cmd:String, args:Array<String>)
	{
		var p = new sys.io.Process(cmd, args);
		var code = p.exitCode();
		return {code:code, out:code == 0 ? p.stdout.readAll().toString() : p.stderr.readAll().toString()};
	}
}
