package tests.integration;

class TestMisc extends IntegrationTests {
	function testCwdWhenPassingToUpdatedHaxelib() {
		// so that the call is passed on
		haxelib(["dev", "haxelib", IntegrationTests.projectRoot]);

		final r = haxelib(["install", "empty.hxml", "--cwd", "libraries/InstallDeps"]).result();
		assertSuccess(r);
		assertTrue(r.out.startsWith("Installing all libraries from"));
	}
}
