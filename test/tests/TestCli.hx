package tests;

import haxelib.client.Cli;

class TestCli extends haxe.unit.TestCase {
	public function testSetWrongCwd() {
		var cwd = Sys.getCwd();
		try {
			Cli.cwd = "/this/path/dos/not/exists";
			assertTrue(false);
		} catch (error:CliError) {
			assertTrue(true);
		}
		assertEquals(cwd, Sys.getCwd());
	}
}
