package tests.integration;

class TestRun extends IntegrationTests {
#if (haxe_ver >= 4.0)
	function testMain():Void {
		final r = haxelib(["dev", "Baz", Path.join([IntegrationTests.projectRoot, "test/libraries/libBaz"])]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Baz"]).result();
		assertSuccess(r);
		assertEquals('Baz tools.Main script', r.out);
	}

	function testMain_noValueButRunHxExists():Void {
		final r = haxelib(["dev", "Bar", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar"])]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Bar"]).result();
		assertSuccess(r);
		assertEquals('Bar Run.hx script', r.out);
	}
#end
	function testRunN_preferredOverRunHx():Void {
		final r = haxelib(["dev", "Bar2", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2"])]).result();
		assertSuccess(r);
		final r = haxelib(["run", "Bar2"]).result();
		assertSuccess(r);
		assertEquals('Bar2 run.n script', r.out);
	}
}
