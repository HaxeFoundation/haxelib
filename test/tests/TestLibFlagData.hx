package tests;

import haxe.io.Path;
import haxelib.api.LibFlagData;

using Lambda;

class TestLibFlagData extends TestBase {

	static var CWD:String = null;

	override function setup() {
		CWD = Sys.getCwd();

		final dir = Path.join([CWD, "test/libraries/InstallDeps"]);
		Sys.setCwd(dir);
	}

	override function tearDown() {
		Sys.setCwd(CWD);
	}

	function testTargetFlag() {
		final libraries = fromHxml("cpp.hxml");

		assertEquals(1, libraries.count(f -> f.name == "hxcpp"));

		final libraries = fromHxml("cpp-single.hxml");

		assertEquals(1, libraries.count(f -> f.name == "hxcpp"));
	}

	// test for issue #511
	function testBackendExplicit() {
		final libraries = fromHxml("target-lib.hxml");

		assertEquals(1, libraries.count(f -> f.name == "hxcpp"));
	}

	// specified explicitly with non-standard capitalisation
	function testBackendExplicitUppercase() {
		final libraries = fromHxml("target-lib-uppercase.hxml");

		assertEquals(1, libraries.count(f -> f.name == "HXCPP"));
		assertEquals(0, libraries.count(f -> f.name == "hxcpp"));
	}

}
