package tests;

import sys.io.File;
import sys.FileSystem;

import haxelib.api.RepoManager;

using haxe.io.Path;

class TestRepoManager extends TestBase {
	static final REPO = "haxelib-repo";
	static final LOCAL_REPO = ".haxelib/";

	final repo = Path.join([Sys.getCwd(), "test", REPO]).addTrailingSlash();
	var origRepo:String = null;
	var cwd:String = null;

	// Setup and teardown

	override public function setup():Void {
		cwd = Sys.getCwd();
		Sys.setCwd("test");

		origRepo = ~/\r?\n/.split(runHaxelib(["config"]).stdout)[0].normalize();

		if (runHaxelib(["setup", repo]).exitCode != 0)
			throw "haxelib setup failed";
	}

	override public function tearDown():Void {
		if (runHaxelib(["setup", origRepo]).exitCode != 0) {
			throw "haxelib setup failed";
		}
		if (FileSystem.exists(LOCAL_REPO))
			deleteDirectory(LOCAL_REPO);
		if (FileSystem.exists("tmp"))
			deleteDirectory("tmp");

		deleteDirectory(repo);
		Sys.setCwd(cwd);
	}

	// Tests

	public function testNewRepo() {
		RepoManager.createLocal();
		assertTrue(FileSystem.exists(LOCAL_REPO));

		// throws error if one already exists
		try {
			RepoManager.createLocal();
			assertFalse(true);
		} catch(e:RepoException) {
			assertTrue(true);
		}

		deleteDirectory(LOCAL_REPO);

		// relative path
		final tmp = "tmp/";

		RepoManager.createLocal(tmp);
		assertTrue(FileSystem.exists(tmp + LOCAL_REPO));
		deleteDirectory(tmp + LOCAL_REPO);

		// absolute path
		final tmp = Sys.getCwd() + "tmp/";

		RepoManager.createLocal(tmp);
		assertTrue(FileSystem.exists(tmp + LOCAL_REPO));
		deleteDirectory(tmp + LOCAL_REPO);
	}

	public function testDeleteRepo() {
		FileSystem.createDirectory(LOCAL_REPO);

		RepoManager.deleteLocal();
		assertFalse(FileSystem.exists(LOCAL_REPO));

		// throws error if no repository exists
		try {
			RepoManager.deleteLocal();
			assertFalse(true);
		} catch (e:RepoException) {
			assertTrue(true);
		}

		// relative path
		final tmp = "tmp/";

		FileSystem.createDirectory(tmp + LOCAL_REPO);
		RepoManager.deleteLocal(tmp);
		assertFalse(FileSystem.exists(tmp + LOCAL_REPO));

		// absolute path
		final tmp = Sys.getCwd() + "tmp/";

		FileSystem.createDirectory(tmp + LOCAL_REPO);
		RepoManager.deleteLocal(tmp);
		assertFalse(FileSystem.exists(tmp + LOCAL_REPO));
	}

	public function testFindRepository() {
		// local repo exists
		RepoManager.createLocal();

		assertEquals(
			FileSystem.absolutePath(LOCAL_REPO),
			RepoManager.getPath().normalize()
		);

		final tmp = "tmp/";
		FileSystem.createDirectory(tmp);

		// relative path
		FileSystem.createDirectory(LOCAL_REPO);
		assertEquals(
			FileSystem.absolutePath(LOCAL_REPO),
			RepoManager.getPath(tmp).normalize()
		);

		// absolute path
		assertEquals(
			FileSystem.absolutePath(LOCAL_REPO),
			RepoManager.getPath(Sys.getCwd() + tmp).normalize()
		);


		// no local repo exists, should go to global
		RepoManager.deleteLocal();

		assertEquals(repo, RepoManager.getPath());

		// relative path
		assertEquals(repo, RepoManager.getPath(tmp));

		// absolute path
		assertEquals(repo, RepoManager.getPath(Sys.getCwd() + tmp));
	}

	public function testGlobalRepository() {
		// test current setup
		assertEquals(repo, RepoManager.getGlobalPath());

		// test enrivonment variable
		final cwd = Sys.getCwd();
		Sys.putEnv("HAXELIB_PATH", cwd);
		assertEquals(cwd, RepoManager.getGlobalPath());
		// empty it
		Sys.putEnv("HAXELIB_PATH", null);
	}

	public function testInvalidGlobalRepositories(){
		function isInvalid() {
			return try {
				RepoManager.getGlobalPath();
				false;
			} catch (e:RepoException) {
				true;
			}
		}

		/* to non existent folder */

		RepoManager.setGlobalPath("toDelete");
		FileSystem.deleteDirectory("toDelete");
		assertTrue(isInvalid());

		/* to a file */

		RepoManager.setGlobalPath("toDelete");
		FileSystem.deleteDirectory("toDelete");

		// create the file
		File.saveContent("toDelete", "");
		assertTrue(isInvalid());

		// clean up
		FileSystem.deleteFile("toDelete");

		/* no global repository set */

		RepoManager.unsetGlobalPath();

		if (Sys.systemName() == "Windows") {
			// on windows, should provide the default value instead of the old set one
			final newValue = RepoManager.getGlobalPath();
			assertFalse(repo == newValue);
		} else {
			// on unix throw an error if no path is set
			// TODO: unless /etc/.haxelib/ is set
			try {
				RepoManager.getGlobalPath();
				assertFalse(true);
			} catch (e:RepoException) {
				assertTrue(true);
			}
		}

		RepoManager.setGlobalPath(repo);
	}

	public function testSuggestGlobalRepositoryPath() {
		// if one is set already, suggest it
		assertEquals(repo, RepoManager.suggestGlobalPath());

		// if none is set, give platform specific default
		// TODO: Test each individual platform??
		RepoManager.unsetGlobalPath();

		// should not give the one that was set
		assertFalse(repo == RepoManager.suggestGlobalPath());


		RepoManager.setGlobalPath(repo);
	}

	public function testSetup() {
		// clearing it
		RepoManager.unsetGlobalPath();
		final newValue = try RepoManager.getGlobalPath() catch(e:RepoException) null;

		assertFalse(repo == newValue);

		// setting it
		RepoManager.setGlobalPath(repo);
		assertEquals(repo, RepoManager.getGlobalPath());

		// setting it to relative path
		final tmp = "tmp";

		RepoManager.setGlobalPath(tmp);
		assertEquals(FileSystem.absolutePath(tmp).addTrailingSlash(), RepoManager.getGlobalPath());
	}

}
