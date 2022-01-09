package tests.integration;

import haxelib.client.Main;

class TestSetup extends IntegrationTests {
	function testCleanEnv():Void {
		// remove .haxelib to simulate an enviroment that haven't `haxelib setup` yet
        final config = Main.getConfigFile();
        sys.FileSystem.deleteFile(config);

		final installResult = haxelib(["setup", originalRepo]).result();
		assertEquals(0, installResult.code);
	}
}
