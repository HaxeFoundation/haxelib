package tests;

import sys.io.File;
import sys.FileSystem;
import tools.haxelib.Vcs;
import haxe.unit.TestCase;
import tools.haxelib.Main.Cli;
import tools.haxelib.Main.Answer;

class TestVcs extends TestCase
{
	//----------- properties, fields ------------//

	static inline var REPO_ROOT = "testing/libraries";
	static inline var REPO_DIR = "vcs";
	static var CWD:String = null;

	var id:VcsID = null;
	var url:String = null;

	//--------------- constructor ---------------//

	public function new(id:VcsID, url:String)
	{
		super();
		this.id = id;
		this.url = url;
		CWD = Sys.getCwd();
	}


	//--------------- initialize ----------------//

	override public function setup():Void
	{
		Sys.setCwd(CWD + "/" + REPO_ROOT);

		if(!FileSystem.exists(REPO_DIR))
			FileSystem.createDirectory(REPO_DIR);

		Sys.setCwd(REPO_DIR);
	}

	override public function tearDown():Void
	{
		// restore original CWD:
		Sys.setCwd(CWD);


		var path = CWD /*+ "/"*/ + REPO_ROOT + "/" + REPO_DIR;

		if(FileSystem.exists(path))
		{
			Sys.sleep(2);
			HaxelibTests.runCommand("rm", ["-r", path + "/"], true);
			Sys.sleep(1);
		}
	}

	//----------------- tests -------------------//


	public function testGetVcs():Void
	{
		assertTrue(Vcs.get(id) != null);
		assertTrue(Vcs.get(id).name == "Mercurial");
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

		assertEquals(vcs, Vcs.get(id));
	}

	public function testCloneSimple():Void
	{
		var vcs = getVcs();
		vcs.clone(vcs.directory, url);

		assertTrue(FileSystem.exists("hg"));
		assertTrue(FileSystem.isDirectory("hg"));

		assertTrue(FileSystem.exists("hg/.hg"));
		assertTrue(FileSystem.isDirectory("hg/.hg"));
	}

	public function testCloneBranch():Void
	{
		var vcs = getVcs();
		vcs.clone(vcs.directory, url, "develop");

		assertTrue(FileSystem.exists("hg"));
		assertTrue(FileSystem.isDirectory("hg"));

		assertTrue(FileSystem.exists("hg/.hg"));
		assertTrue(FileSystem.isDirectory("hg/.hg"));
	}

	public function testCloneBranchTag_0_9_2():Void
	{
		var vcs = getVcs();
		vcs.clone(vcs.directory, url, "develop", "0.9.2");

		assertTrue(FileSystem.exists("hg"));
		assertTrue(FileSystem.exists("hg/.hg"));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists("hg/README.md"));
	}

	public function testCloneBranchTag_0_9_3():Void
	{
		var vcs = getVcs();
		vcs.clone(vcs.directory, url, "develop", "0.9.3");

		assertTrue(FileSystem.exists("hg"));
		assertTrue(FileSystem.exists("hg/.hg"));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertTrue(FileSystem.exists("hg/README.md"));
	}

	public function testCloneBranchRev():Void
	{
		var vcs = getVcs();
		vcs.clone(vcs.directory, url, "develop", "78edb4b");

		assertTrue(FileSystem.exists("hg"));
		assertTrue(FileSystem.exists("hg/.hg"));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists("hg/README.md"));
	}


	// --------------- update --------------- //

	public function testUpdateBranchTag_0_9_2__toHEAD():Void
	{
		testCloneBranchTag_0_9_2();

		// save CWD:
		var cwd = Sys.getCwd();
		Sys.setCwd(cwd + "hg");


		var hg = getVcs();
		assertFalse(FileSystem.exists("README.md"));

		// in this case `libName` can get any value:
		hg.update("LIBNAME");

		// Now we get actual version (0.9.3 or newer) with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateBranchTag_0_9_2__toHEAD__afterUserChanges_withReset():Void
	{
		testCloneBranchTag_0_9_2();

		// save CWD:
		var cwd = Sys.getCwd();
		Sys.setCwd(cwd + "hg");

		// creating user-changes:
		FileSystem.deleteFile("build.hxml");
		File.saveContent("file", "new file \"file\" with content");

		// update to HEAD:
		var hg = getVcs();
		assertFalse(FileSystem.exists("README.md"));

		//Hack: set the default answer:
		new Cli().defaultAnswer = Answer.Yes;

		// in this case `libName` can get any value:
		hg.update("LIBNAME");

		// Now we get actual version (0.9.3 or newer) with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateBranchTag_0_9_2__toHEAD__afterUserChanges_withoutReset():Void
	{
		testCloneBranchTag_0_9_2();

		// save CWD:
		var cwd = Sys.getCwd();
		trace('CWD: "${Sys.getCwd()}"');
		Sys.setCwd(cwd + "hg");

		// creating user-changes:
		FileSystem.deleteFile("build.hxml");
		File.saveContent("file", "new file \"file\" with content");

		// update to HEAD:
		var hg = getVcs();
		assertFalse(FileSystem.exists("README.md"));

		//Hack: set the default answer:
		new Cli().defaultAnswer = Answer.No;

		// in this case `libName` can get any value:
		hg.update("LIBNAME");

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
		return Vcs.get(id);
	}
}
