package tests;

import sys.io.File;
import sys.FileSystem;

import haxelib.client.RepoManager;

using haxe.io.Path;

class TestRepoManager extends TestBase {
	static final REPO = "haxelib-repo";
	static final LOCAL_REPO = ".haxelib/";

	var origRepo:String = null;
	var repo:String = null;
	var cwd:String = null;

	// Constructor

	public function new() {
		super();

		repo = Path.join([Sys.getCwd(), "test", REPO]).addTrailingSlash();
	}

	// Setup and teardown

	override public function setup():Void {
		cwd = Sys.getCwd();
		Sys.setCwd("test");

		origRepo = ~/\r?\n/.split(runHaxelib(["config"]).stdout)[0];
		origRepo = Path.normalize(origRepo);

		if (runHaxelib(["setup", repo]).exitCode != 0)
			throw "haxelib setup failed";
	}

	override public function tearDown():Void {
		if (runHaxelib(["setup", origRepo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		if (FileSystem.exists(LOCAL_REPO))
			deleteDirectory(LOCAL_REPO);

		deleteDirectory(repo);
		Sys.setCwd(cwd);
	}

	// Tests

	public function testNewRepo() {
		RepoManager.newRepo(Sys.getCwd());
		assertTrue(FileSystem.exists(LOCAL_REPO));

		// throws error if one already exists
		try {
			RepoManager.newRepo(Sys.getCwd());
			assertFalse(true);
		} catch(e:RepoException) {
			assertTrue(true);
		}

		deleteDirectory(LOCAL_REPO);
	}

	public function testDeleteRepo() {
		FileSystem.createDirectory(Path.join([Sys.getCwd(), LOCAL_REPO]));

		RepoManager.deleteRepo(Sys.getCwd());
		assertFalse(FileSystem.exists(Path.join([Sys.getCwd(), LOCAL_REPO])));

		// throws error if no repository exists
		try {
			RepoManager.deleteRepo(Sys.getCwd());
			assertFalse(true);
		} catch (e:RepoException) {
			assertTrue(true);
		}
	}

	public function testFindRepository() {
		// local repo exists
		FileSystem.createDirectory(LOCAL_REPO);
		assertEquals(
			FileSystem.absolutePath(LOCAL_REPO),
			RepoManager.findRepository(Sys.getCwd()).normalize()
		);

		deleteDirectory(LOCAL_REPO);

		// no local repo exists, should go to global
		assertEquals(repo, RepoManager.findRepository(Sys.getCwd()));
	}

	public function testGlobalRepository() {
		// test current setup
		assertEquals(repo, RepoManager.getGlobalRepository());

		// test enrivonment variable
		final cwd = Sys.getCwd();
		Sys.putEnv("HAXELIB_PATH", cwd);
		assertEquals(cwd, RepoManager.getGlobalRepository());
		// empty it
		Sys.putEnv("HAXELIB_PATH", "");
	}

	public function testInvalidGlobalRepositories(){
		function isInvalid() {
			return try {
				RepoManager.getGlobalRepository();
				false;
			} catch (e:RepoException) {
				true;
			}
		}

		/* to non existant folder */

		RepoManager.saveSetup("toDelete");
		FileSystem.deleteDirectory("toDelete");
		assertTrue(isInvalid());

		/* to a file */

		RepoManager.saveSetup("toDelete");
		FileSystem.deleteDirectory("toDelete");

		// create the file
		File.saveContent("toDelete", "");
		assertTrue(isInvalid());

		// clean up
		FileSystem.deleteFile("toDelete");

		/* no global repository set */

		RepoManager.clearSetup();

		if (Sys.systemName() == "Windows") {
			// on windows, should provide the default value instead of the old set one
			final newValue = RepoManager.getGlobalRepository();
			assertFalse(repo == newValue);
		} else {
			// on unix throw an error if no path is set
			// TODO: unless /etc/.haxelib/ is set
			try {
				RepoManager.getGlobalRepository();
				assertFalse(true);
			} catch (e:RepoException) {
				assertTrue(true);
			}
		}

		RepoManager.saveSetup(repo);
	}

	public function testSuggestGlobalRepositoryPath() {
		// if one is set already, suggest it
		assertEquals(repo, RepoManager.suggestGlobalRepositoryPath());

		// if none is set, give platform specific default
		// TODO: Test each individual platform??
		RepoManager.clearSetup();

		// should not give the one that was set
		assertFalse(repo == RepoManager.suggestGlobalRepositoryPath());


		RepoManager.saveSetup(repo);
	}

	public function testSetup() {
		// clearing it
		RepoManager.clearSetup();
		final newValue = try RepoManager.getGlobalRepository() catch(e:RepoException) null;

		assertFalse(repo == newValue);

		// setting it
		RepoManager.saveSetup(repo);
		assertEquals(repo, RepoManager.getGlobalRepository());
	}

}
