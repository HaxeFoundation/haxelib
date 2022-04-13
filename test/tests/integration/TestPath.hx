package tests.integration;

using Lambda;

class TestPath extends IntegrationTests {
	static final barDevPath = "libraries/libBar2/";
	static final barPath = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/1,0,0"]).addTrailingSlash();
	static final bar2Path = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "bar/2,0,0"]).addTrailingSlash();
	static final bazPath = Path.join([IntegrationTests.projectRoot, IntegrationTests.repo, "baz/0,1,0-alpha,0"]).addTrailingSlash();

#if !system_haxelib
	function testBadHaxelibJson():Void {
		final r = haxelib(["dev", "BadHaxelibJson", Path.join([IntegrationTests.projectRoot, "test/libraries/libBadHaxelibJson"])]).result();
		assertSuccess(r);
		final r = haxelib(["path", "BadHaxelibJson"]).result();
		assertFail(r);
	}
#end
	function testInvalidLicense() {
		// invalid license should not prevent usage
		final r = haxelib(["dev", "InvalidLicense", "libraries/libInvalidLicense"]).result();
		assertSuccess(r);
		final r = haxelib(["path", "InvalidLicense"]).result();
		assertSuccess(r);
		assertOutputEquals([
			Path.join([IntegrationTests.projectRoot, "test/libraries/libInvalidLicense"]).addTrailingSlash(),
			"-D Bar=1.0.0"
		], r.out);
	}

	function testMultipleLibraries():Void {
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);
		final r = haxelib(["install", "libraries/libBaz.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["path", "Bar", "Baz"]).result();
		assertSuccess(r);
		assertOutputEquals([barPath, '-D Bar=1.0.0', bazPath, '-D Baz=0.1.0-alpha.0'], r.out.trim());

		final r = haxelib(["path", "Baz", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([bazPath, '-D Baz=0.1.0-alpha.0', barPath, '-D Bar=1.0.0'], r.out.trim());
	}

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

	function testVersionSpecification():Void {
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);
		final r = haxelib(["install", "libraries/libBar2.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the set version will be run
		final r = haxelib(["path", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([bar2Path, '-D Bar=2.0.0'], r.out.trim());

		// if we specify a version, we want that
		final r = haxelib(["path", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertOutputEquals([barPath, '-D Bar=1.0.0'], r.out.trim());

		// if we specify a missing version, we fail.
		final r = haxelib(["path", "Bar:1.1.0"]).result();
		assertFail(r);
		assertEquals("Error: Library Bar version 1.1.0 is not installed", r.err.trim());
	}

	function testVersionOverriding():Void {
		// # 249
		final r = haxelib(["dev", "Bar", barDevPath]).result();
		assertSuccess(r);

		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);

		// if no version is specified, the dev version will be run
		final r = haxelib(["path", "Bar"]).result();
		assertSuccess(r);
		final devPath = sys.FileSystem.absolutePath(barDevPath).addTrailingSlash();
		assertOutputEquals([devPath, '-D Bar=2.0.0'], r.out.trim());

		// if we specify a version, we want that and not the dev version
		final r = haxelib(["path", "Bar:1.0.0"]).result();
		assertSuccess(r);
		assertOutputEquals([barPath, '-D Bar=1.0.0'], r.out.trim());
	}

	function testMultipleLibraryVersions():Void {
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);
		final r = haxelib(["install", "libraries/libBar2.zip"]).result();
		assertSuccess(r);

		final r = haxelib(["path", "Bar:2.0.0", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([bar2Path, '-D Bar=2.0.0'], r.out.trim());

		final r = haxelib(["path", "Bar:1.0.0", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([barPath, '-D Bar=1.0.0'], r.out.trim());

		final r = haxelib(["path", "Bar:2.0.0", "Bar:1.0.0"]).result();
		assertFail(r);
		assertEquals('Error: Cannot process `Bar:1.0.0`: Library Bar has two versions included : 2.0.0 and 1.0.0', r.err.trim());

		// differently capitalized
		final r = haxelib(["path", "Bar:2.0.0", "bar:1.0.0"]).result();
		assertFail(r);
		assertEquals('Error: Cannot process `bar:1.0.0`: Library Bar has two versions included : 2.0.0 and 1.0.0', r.err.trim());
	}

	function testInvalidCurrentVersion():Void {
		// for now, Shiro Games needs this to work
		final r = haxelib(["install", "libraries/libBar.zip"]).result();
		assertSuccess(r);

		final customVersion = "custom";
		final projectPath = barPath.directory().directory();
		final customPath = Path.join([projectPath, customVersion]).addTrailingSlash();

		sys.FileSystem.rename(barPath, customPath);
		sys.io.File.saveContent(Path.join([projectPath, ".current"]), customVersion);

		final r = haxelib(["path", "Bar"]).result();
		assertSuccess(r);
		assertOutputEquals([customPath, '-D Bar=1.0.0'], r.out.trim());
	}
}
