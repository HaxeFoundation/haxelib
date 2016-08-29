package tests;

import sys.io.*;
import sys.FileSystem;
import haxe.io.*;
import haxe.unit.TestCase;
import haxelib.Data;


class TestInstall extends TestBase
{

	static inline var REPO = "haxelib-repo";
	static inline var PROJECT_FOLDER = "UseGitDep";
	static inline var REPO_ROOT = "test/libraries";
	static var CWD:String = null;
	static var origRepo:String = null;
	var repo:String = null;


	//--------------- constructor ---------------//

	public function new() 
	{
		super();
		this.repo = Path.join([Sys.getCwd(), "test", REPO]);
	}


	//--------------- initialize ----------------//

	override public function setup():Void
	{
		origRepo = ~/\r?\n/.split(runHaxelib(["config"]).stdout)[0];
		origRepo = Path.normalize(origRepo);
		
		if (runHaxelib(["setup", repo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		
		CWD = Sys.getCwd();
		var dir = Path.join([CWD, REPO_ROOT, PROJECT_FOLDER]);
		Sys.setCwd(dir);
	}

	override public function tearDown():Void
	{
		// restore original CWD:
		Sys.setCwd(CWD);
		
		if (runHaxelib(["setup", origRepo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		deleteDirectory(repo);
		
	}

	//----------------- tests -------------------//

	public function testInstallHaxelibParameter():Void
	{
		var r = runHaxelib(["install", "haxelib.json"]);
		assertTrue(r.exitCode == 0);
		
		checkLibrary(getLibraryName());
	}
	
	public function testInstallHaxelibDependencyWithTag():Void
	{
		var r = runHaxelib(["install", "tag_haxelib.json"]);
		assertTrue(r.exitCode == 0);
		
		var lib = getLibraryName();
		checkLibrary(lib);
		
		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(Path.join([lib, "git", "README.md"])));
	}
	
	function getLibraryName():String
	{
		var haxelibFile = File.read("haxelib.json", false);
		var details = Data.readData(haxelibFile.readAll().toString(), false );
		haxelibFile.close();
		return details.dependencies.toArray()[0].name;
	}
	
	function checkLibrary(lib:String):Void
	{
		// Library folder exists
		var libFolder = Path.join([repo, lib]);
		assertTrue(FileSystem.exists(libFolder));
		assertTrue(FileSystem.isDirectory(libFolder));
		
		// Library version is set to git
		var current = File.read(Path.join([libFolder, ".current"]), false);
		assertTrue(current.readAll().toString() == "git");
		current.close();
	}

}