package tests;

import sys.io.*;
import sys.FileSystem;
import haxe.io.*;
import haxe.unit.TestCase;

import haxelib.client.Cli;
import haxelib.client.Vcs;

class TestVcs extends TestBase
{
	//----------- properties, fields ------------//

	static inline var REPO_ROOT = "test/libraries";
	static inline var REPO_DIR = "vcs";
	static var CWD:String = null;

	var id:VcsID = null;
	var vcsName:String = null;
	var url:String = null;
	var rev:String = null;
	var counter:Int = 0;

	//--------------- constructor ---------------//

	public function new(id:VcsID, vcsName:String, url:String, ?rev:String)
	{
		super();
		this.id = id;
		this.url = url;
		this.rev = rev;
		this.vcsName = vcsName;

		CWD = Sys.getCwd();
		counter = 0;
	}


	//--------------- initialize ----------------//

	override public function setup():Void
	{
		Sys.setCwd(Path.join([CWD, REPO_ROOT]));

		if(FileSystem.exists(REPO_DIR)) {
			deleteDirectory(REPO_DIR);
		}
		FileSystem.createDirectory(REPO_DIR);

		Sys.setCwd(REPO_DIR);
	}

	override public function tearDown():Void
	{
		// restore original CWD:
		Sys.setCwd(CWD);

		deleteDirectory(Path.join([CWD, REPO_ROOT, REPO_DIR]));
	}

	//----------------- tests -------------------//


	public function testGetVcs():Void
	{
		assertTrue(Vcs.get(id, {quiet: true}) != null);
		assertTrue(Vcs.get(id, {quiet: true}).name == vcsName);
	}

	public function testAvailable():Void
	{
		assertTrue(getVcs().available);
	}

	// --------------- clone --------------- //

	public function testGetVcsByDir():Void
	{
		var vcs = getVcs();
		testCloneSimple();

		assertEquals(vcs, Vcs.get(id, {quiet: true}));
	}

	public function testCloneSimple():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter++;
		vcs.clone(dir, url);

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.isDirectory(dir));

		assertTrue(FileSystem.exists('$dir/.${vcs.directory}'));
		assertTrue(FileSystem.isDirectory('$dir/.${vcs.directory}'));
	}

	public function testCloneBranch():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter++;
		vcs.clone(dir, url, "develop");

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.isDirectory(dir));

		assertTrue(FileSystem.exists('$dir/.${vcs.directory}'));
		assertTrue(FileSystem.isDirectory('$dir/.${vcs.directory}'));
	}

	public function testCloneBranchTag_0_9_2():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter++;
		vcs.clone(dir, url, "develop", "0.9.2");
		Sys.sleep(3);
		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${vcs.directory}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(dir + "/README.md"));
	}

	public function testCloneBranchTag_0_9_3():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter++;
		vcs.clone(dir, url, "develop", "0.9.3");

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${vcs.directory}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertTrue(FileSystem.exists(dir + "/README.md"));
	}

	public function testCloneBranchRev():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter++;
		vcs.clone(dir, url, "develop", rev);

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${vcs.directory}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(dir + "/README.md"));
	}


	// --------------- update --------------- //

	public function testUpdateBranchTag_0_9_2__toLatest():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter;// increment will do in `testCloneBranchTag_0_9_2`

		testCloneBranchTag_0_9_2();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		var cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);
		assertTrue(FileSystem.exists("." + vcs.directory));

		// in this case `libName` can get any value:
		vcs.update("LIBNAME");

		// Now we get actual version (0.9.3 or newer) with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}


	public function testUpdateBranchTag_0_9_2__toLatest__afterUserChanges_withReset():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter;// increment will do in `testCloneBranchTag_0_9_2`

		testCloneBranchTag_0_9_2();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		var cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);

		// creating user-changes:
		FileSystem.deleteFile("build.hxml");
		File.saveContent("file", "new file \"file\" with content");

		//Hack: set the default answer:
		Cli.defaultAnswer = true;

		// update to HEAD:
		// in this case `libName` can get any value:
		vcs.update("LIBNAME");

		// Now we get actual version (0.9.3 or newer) with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateBranchTag_0_9_2__toLatest__afterUserChanges_withoutReset():Void
	{
		var vcs = getVcs();
		var dir = vcs.directory + counter;// increment will do in `testCloneBranchTag_0_9_2`

		testCloneBranchTag_0_9_2();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		var cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);

		// creating user-changes:
		FileSystem.deleteFile("build.hxml");
		File.saveContent("file", "new file \"file\" with content");

		//Hack: set the default answer:
		Cli.defaultAnswer = false;

		// update to HEAD:
		// in this case `libName` can get any value:
		vcs.update("LIBNAME");

		// We get no reset and update:
		assertTrue(FileSystem.exists("file"));
		assertFalse(FileSystem.exists("build.hxml"));
		assertFalse(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	//----------------- tools -------------------//

	inline function getVcs():Vcs
	{
		return Vcs.get(id, {quiet: true});
	}
}
