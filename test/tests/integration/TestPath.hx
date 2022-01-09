package tests.integration;

using Lambda;

class TestPath extends IntegrationTests {
#if !system_haxelib
	function testMain():Void {
		final r = haxelib(["dev", "BadHaxelibJson", Path.join([IntegrationTests.projectRoot, "test/libraries/libBadHaxelibJson"])]).result();
		assertSuccess(r);
		final r = haxelib(["path", "BadHaxelibJson"]).result();
		assertFail(r);
	}
#end
}
