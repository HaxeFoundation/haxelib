package tests.integration;

import haxe.io.Path;
using IntegrationTests;

class TestRun extends IntegrationTests {
#if (haxe_ver >= 4.0)
	function testMain():Void {
		var r = haxelib(["dev", "Baz", Path.join([IntegrationTests.projectRoot, "test/libraries/libBaz"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Baz"]).result();
		assertSuccess(r);
		assertEquals('Baz tools.Main script', r.out);
	}

	function testMain_noValueButRunHxExists():Void {
		var r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}
#end
	function testRunN_preferredOverRunHx():Void {
		var r = haxelib(["dev", "Bar2", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Bar2"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);
	}
}