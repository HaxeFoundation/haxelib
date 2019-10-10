package tests.integration;

import haxe.io.Path;
using IntegrationTests;

class TestPath extends IntegrationTests {
#if !system_haxelib
	function testMain():Void {
		var r = haxelib(["dev", "BadHaxelibJson", Path.join([IntegrationTests.projectRoot, "test/libraries/libBadHaxelibJson"])]).result();
		assertSuccess(r);
		var r = haxelib(["path", "BadHaxelibJson"]).result();
		assertFail(r);
	}
#end
}