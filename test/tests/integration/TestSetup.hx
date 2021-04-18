package tests.integration;

import haxelib.client.RepoManager;

class TestSetup extends IntegrationTests {
	function testCleanEnv():Void {
		// remove .haxelib to simulate an enviroment that haven't `haxelib setup` yet
		RepoManager.unsetGlobalPath();

		final installResult = haxelib(["setup", originalRepo]).result();
		assertEquals(0, installResult.code);
	}
}
