package tests;

import tools.haxelib.Main.Cli;
import tools.haxelib.Main.CliError;
import haxe.unit.TestCase;

class TestCli extends TestCase
{
	//----------- properties, fields ------------//

	var cli:Cli;

	//--------------- constructor ---------------//
	public function new()
	{
		super();
	}


	//--------------- initialize ----------------//

	override public function setup():Void
	{
		cli = new Cli();
	}

	//----------------- tests -------------------//

	public function testSetWrongCwd():Void
	{
		var cwd = Sys.getCwd();

		try
		{
			cli.cwd = "/this/path/dos/not/exists";
			assertTrue(false);
		}
		catch(error:CliError)
			assertTrue(true);

		assertEquals(cwd, Sys.getCwd());
	}


	//----------------- tools -------------------//
}
