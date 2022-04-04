package tests;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import haxelib.Data;

using StringTools;

class TestInstall extends TestBase {

	static final REPO = "haxelib-repo";
	static final PROJECT_FOLDER = "UseGitDep";
	static final REPO_ROOT = "test/libraries";
	static var CWD:String = null;
	static var origRepo:String = null;

	final repo:String;


	//--------------- constructor ---------------//

	public function new() {
		super();
		repo = Path.join([Sys.getCwd(), "test", REPO]);
	}


	//--------------- initialize ----------------//

	override public function setup():Void {
		origRepo = Path.normalize(~/\r?\n/.split(runHaxelib(["config"]).stdout)[0]);

		if (runHaxelib(["setup", repo]).exitCode != 0)
			throw "haxelib setup failed";

		CWD = Sys.getCwd();
		final dir = Path.join([CWD, REPO_ROOT, PROJECT_FOLDER]);
		Sys.setCwd(dir);
	}

	override public function tearDown():Void {
		// restore original CWD:
		Sys.setCwd(CWD);

		if (runHaxelib(["setup", origRepo]).exitCode != 0)
			throw "haxelib setup failed";

		deleteDirectory(repo);

	}

	//----------------- tests -------------------//

	public function testInstallHaxelibParameter():Void {
		final r = runHaxelib(["install", "haxelib.json"]);
		assertTrue(r.exitCode == 0);

		checkLibrary(getLibraryName());
	}

	public function testInstallHaxelibDependencyWithTag():Void {
		final r = runHaxelib(["install", "tag_haxelib.json"]);
		assertTrue(r.exitCode == 0);

		final lib = getLibraryName();
		checkLibrary(lib);

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(Path.join([lib, "git", "README.md"])));
	}

	public function testInstallHxmlWithBackend() {
		// test for issue #511
		final r = runHaxelib(["install", "target-lib.hxml", "--never"]);
		final lines = r.stdout.split("\n");

		// number of times that hxcpp is listed
		var count = 0;

		for (line in lines)
			if (line.ltrim().startsWith("hxcpp"))
				count++;

		assertEquals(1, count);
	}

	public function testReinstallHxml() {
		final r = runHaxelib(["install", "git-deps.hxml", "--always"]);
		assertEquals(0, r.exitCode);
		final r = runHaxelib(["install", "git-deps.hxml", "--always"]);
		assertEquals(0, r.exitCode);
		final r = runHaxelib(["path", "hx.signal"]);
		assertEquals(0, r.exitCode);
	}

	function getLibraryName():String
	{
		final haxelibFile = File.read("haxelib.json", false);
		final details = Data.readData(haxelibFile.readAll().toString(), false );
		haxelibFile.close();
		return details.dependencies.toArray()[0].name;
	}

	function checkLibrary(lib:String):Void {
		// Library folder exists
		final libFolder = Path.join([repo, lib]);
		assertTrue(FileSystem.exists(libFolder));
		assertTrue(FileSystem.isDirectory(libFolder));

		// Library version is set to git
		final current = File.read(Path.join([libFolder, ".current"]), false);
		assertTrue(current.readAll().toString() == "git");
		current.close();
	}

}
