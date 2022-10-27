package tests;

import sys.io.*;
import sys.FileSystem;
import haxe.io.*;
import haxe.unit.TestCase;

import haxelib.VersionData.VcsID;
import haxelib.api.Vcs;

class TestVcs extends TestBase
{
	//----------- properties, fields ------------//

	static final REPO_ROOT = "test/libraries";
	static final REPO_DIR = "vcs";
	static var CWD:String = null;

	final id:VcsID = null;
	final vcsExecutable:String = null;
	final url:String = null;
	final branch:String = null;
	final rev:String = null;
	var counter:Int = 0;

	//--------------- constructor ---------------//

	public function new(id:VcsID, vcsExecutable:String, url:String, ?branch:String, ?rev:String) {
		super();
		this.id = id;
		this.url = url;
		this.branch = branch;
		this.rev = rev;
		this.vcsExecutable = vcsExecutable;

		CWD = Sys.getCwd();
		counter = 0;
	}


	//--------------- initialize ----------------//

	override public function setup():Void {
		Sys.setCwd(Path.join([CWD, REPO_ROOT]));

		if(FileSystem.exists(REPO_DIR)) {
			deleteDirectory(REPO_DIR);
		}
		FileSystem.createDirectory(REPO_DIR);

		Sys.setCwd(REPO_DIR);
	}

	override public function tearDown():Void {
		// restore original CWD:
		Sys.setCwd(CWD);

		deleteDirectory(Path.join([CWD, REPO_ROOT, REPO_DIR]));
	}

	//----------------- tests -------------------//


	public function testCreateVcs():Void {
		assertTrue(Vcs.create(id) != null);
		assertTrue(Vcs.create(id).executable == vcsExecutable);
	}

	public function testAvailable():Void {
		assertTrue(createVcs().available);
	}

	// --------------- clone --------------- //

	public function testCloneSimple():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url});

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.isDirectory(dir));

		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));
		assertTrue(FileSystem.isDirectory('$dir/.${Vcs.getDirectoryFor(id)}'));
	}

	public function testCloneBranch():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url, branch: branch});

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.isDirectory(dir));

		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));
		assertTrue(FileSystem.isDirectory('$dir/.${Vcs.getDirectoryFor(id)}'));
	}

	public function testCloneTag_0_9_2():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url, tag: "0.9.2"});
		Sys.sleep(3);
		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(dir + "/README.md"));
	}

	public function testCloneTag_0_9_3():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url, tag: "0.9.3"});

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertTrue(FileSystem.exists(dir + "/README.md"));
	}

	public function testCloneBranchCommit():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url, branch: branch, commit: rev});

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(dir + "/README.md"));
	}

	public function testCloneCommit():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter++;
		vcs.clone(dir, {url: url, commit: rev});

		assertTrue(FileSystem.exists(dir));
		assertTrue(FileSystem.exists('$dir/.${Vcs.getDirectoryFor(id)}'));

		// if that repo "README.md" was added in tag/rev.: "0.9.3"
		assertFalse(FileSystem.exists(dir + "/README.md"));
	}


	// --------------- update --------------- //

	public function testUpdateTag_0_9_2():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter; // increment will do in `testCloneBranchTag_0_9_2`

		testCloneTag_0_9_2();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		final cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);
		assertTrue(FileSystem.exists("." + Vcs.getDirectoryFor(id)));

		assertFalse(vcs.checkRemoteChanges());
		try {
			vcs.mergeRemoteChanges();
			assertFalse(true);
		} catch (e:VcsError) {
			assertTrue(e.match(CommandFailed(_)));
		}

		// Since originally we installed 0.9.2, we are locked down to that so still no README.md.
		assertFalse(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateCommit():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter; // increment will do in `testCloneCommit`

		testCloneCommit();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		final cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);
		assertTrue(FileSystem.exists("." + Vcs.getDirectoryFor(id)));

		assertFalse(vcs.checkRemoteChanges());
		try {
			vcs.mergeRemoteChanges();
			assertFalse(true);
		} catch (e:VcsError) {
			assertTrue(e.match(CommandFailed(_)));
		}

		// Since originally we installed 0.9.2, we are locked down to that so still no README.md.
		assertFalse(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateBranch():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter;
		// clone old commit from branch
		testCloneBranchCommit();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		final cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);
		assertTrue(FileSystem.exists("." + Vcs.getDirectoryFor(id)));

		assertTrue(vcs.checkRemoteChanges());
		vcs.mergeRemoteChanges();

		// Now we have the current version of develop with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	public function testUpdateBranch__afterUserChanges():Void {
		final vcs = createVcs();
		final dir = id.getName() + counter;

		testCloneBranchCommit();
		assertFalse(FileSystem.exists("README.md"));

		// save CWD:
		final cwd = Sys.getCwd();
		Sys.setCwd(cwd + dir);
		assertTrue(FileSystem.exists("." + Vcs.getDirectoryFor(id)));

		// creating user-changes:
		FileSystem.deleteFile("build.hxml");
		File.saveContent("file", "new file \"file\" with content");

		assertTrue(vcs.hasLocalChanges());

		// update to HEAD:
		vcs.resetLocalChanges();
		assertTrue(FileSystem.exists("build.hxml"));

		assertFalse(vcs.hasLocalChanges());
		assertTrue(vcs.checkRemoteChanges());
		vcs.mergeRemoteChanges();

		// Now we have the current version of develop with README.md.
		assertTrue(FileSystem.exists("README.md"));

		// restore CWD:
		Sys.setCwd(cwd);
	}

	//----------------- tools -------------------//

	inline function createVcs():Vcs {
		return Vcs.create(id);
	}
}
