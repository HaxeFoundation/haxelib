package tests;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

import haxelib.ProjectName;
import haxelib.Data;
import haxelib.api.RepoManager;
import haxelib.api.Installer;
import haxelib.api.Scope;

using StringTools;

class TestInstaller extends TestBase {

	static final REPO = "haxelib-repo";
	static final PROJECT_FOLDER = "InstallDeps";
	static final REPO_ROOT = "test/libraries";
	static var CWD:String = null;
	static var origRepo:String = null;

	final repo:String;

	var scope:Scope;
	var installer:Installer;

	//--------------- constructor ---------------//

	public function new() {
		super();
		repo = Path.join([Sys.getCwd(), "test", REPO]);
	}


	//--------------- initialize ----------------//

	override public function setup():Void {
		origRepo = RepoManager.getGlobalPath();

		RepoManager.setGlobalPath(repo);

		CWD = Sys.getCwd();
		final dir = Path.join([CWD, REPO_ROOT, PROJECT_FOLDER]);
		Sys.setCwd(dir);

		scope = getScope();
		installer = new Installer(scope);
	}

	override public function tearDown():Void {
		// restore original CWD:
		Sys.setCwd(CWD);

		RepoManager.setGlobalPath(origRepo);

		deleteDirectory(repo);
	}

	//----------------- tests -------------------//

	public function testInstallHaxelibParameter():Void {
		installer.installFromHaxelibJson("haxelib.json");

		checkLibrary(getLibraryName());
	}

	public function testInstallHaxelibDependencyWithTag():Void {
		installer.installFromHaxelibJson("tag_haxelib.json");

		final lib = getLibraryName();
		checkLibrary(lib);

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(Path.join([lib, "git", "README.md"])));
	}

	public function testReinstallHxml() {
		installer.installFromHxml("git-deps.hxml");

		installer.installFromHxml("git-deps.hxml");

		assertTrue(scope.isLibraryInstalled(ProjectName.ofString("hx.signal")));
	}

	function getLibraryName():String {
		final haxelibFile = File.read("haxelib.json", false);
		final details = Data.readData(haxelibFile.readAll().toString(), NoCheck);
		haxelibFile.close();
		return details.dependencies.getNames()[0];
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
