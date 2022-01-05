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
	// for issue #529
	function testCapitalization():Void {
		final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
		assertSuccess(r);
		final r = haxelib(["path", "Bar"]).result();
		assertSuccess(r);
		final firstOut = r.out;
		// now capitalise differently
		final r = haxelib(["path", "bar"]).result();
		assertSuccess(r);
		assertEquals(firstOut, r.out);
	}
}
