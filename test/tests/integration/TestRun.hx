package tests.integration;

import haxe.io.Path;
using IntegrationTests;

class TestRun extends IntegrationTests {
	function testMain():Void {
		var r = haxelib(["dev", "Foo", Path.join([IntegrationTests.projectRoot, "libraries/libFoo"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Foo"]).result();
		assertSuccess(r);
		assertEquals('Foo tools.Main script', r.out);
	}

	function testMain_noValueButRunHxExists():Void {
		var r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "libraries/libBar"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}

	function testRunN_preferredOverRunHx():Void {
		var r = haxelib(["dev", "Bar2", Path.join([IntegrationTests.projectRoot, "libraries/libBar2"])]).result();
		assertSuccess(r);
		var r = haxelib(["run", "Bar2"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);
	}

}