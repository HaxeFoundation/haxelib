package tests.integration;

import haxe.*;
import haxe.io.*;
import haxelib.*;
import haxelib.client.*;
import IntegrationTests.*;
using IntegrationTests;

class TestSetup extends IntegrationTests {
	function testCleanEnv():Void {
		// remove .haxelib to simulate an enviroment that haven't `haxelib setup` yet
        var config = Main.getConfigFile();
        sys.FileSystem.deleteFile(config);

		var installResult = haxelib(["setup", originalRepo]).result();
		assertEquals(0, installResult.code);
	}
}