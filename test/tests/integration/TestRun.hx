package tests.integration;

import haxe.io.Path;
using IntegrationTests;

class TestRun extends IntegrationTests {
	function testMain():Void {
		runHaxelib(["dev", "Foo", Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo"])]);
		var r = haxelib(["run", "Foo"]).result();
		assertSuccess(r);
		assertEquals('Foo tools.Main script', r.out);
	}

	function testMain_noValueButRunHxExists():Void {
		runHaxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]);
		var r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}

	function testRunN_preferredOverRunHx():Void {
		runHaxelib(["dev", "Bar2", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2"])]);
		var r = haxelib(["run", "Bar2"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);
	}

}