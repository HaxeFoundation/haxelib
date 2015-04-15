package tests;

import sys.FileSystem;
import tools.haxelib.Vcs;
import haxe.unit.TestCase;


class TestVcsNotFound extends TestCase
{
	//----------- properties, fields ------------//

	static inline var REPO_ROOT = "testing/libraries";
	static inline var REPO_DIR = "vcs-no";
	static var CWD:String = null;

	//--------------- constructor ---------------//
	public function new()
	{
		super();
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
		// restore original CWD & PATH:
		Sys.setCwd(CWD);
	}

	//----------------- tests -------------------//


	public function testAvailableHg():Void
	{
		assertFalse(getHg().available);
	}

	public function testAvailableGit():Void
	{
		assertFalse(getGit().available);
	}


	public function testCloneHg():Void
	{
		var vcs = getHg();
		try
		{
			vcs.clone(vcs.directory, "https://bitbucket.org/fzzr/hx.signal");
			assertFalse(true);
		}
		catch(error:Dynamic)
		{
			assertTrue(Reflect.isEnumValue(error));
			switch(error)
			{
				case VcsError.CantCloneRepo(_, repo, stderr): assertTrue(true);
				default: assertFalse(true);
			}
		}
	}

	public function testCloneGit():Void
	{
		var vcs = getGit();
		try
		{
			vcs.clone(vcs.directory, "https://github.com/fzzr-/hx.signal.git");
			assertFalse(true);
		}
		catch(error:Dynamic)
		{
			assertTrue(Reflect.isEnumValue(error));
			switch(error)
			{
				case VcsError.CantCloneRepo(_, repo, stderr): assertTrue(true);
				default: assertFalse(true);
			}
		}
	}


	//----------------- tools -------------------//

	inline function getHg():Vcs
	{
		return new WrongHg();
	}

	inline function getGit():Vcs
	{
		return new WrongGit();
	}
}



class WrongHg extends Mercurial
{
	public function new()
	{
		super();
		this.directory = "no-hg";
		this.executable = "no-hg";
		this.name = "Mercurial-not-found";
	}

	// copy of Mercurial.searchExecutablebut have a one change - regexp.
	override private function searchExecutable():Void
	{
		super.searchExecutable();

		if(available)
			return;

		// if we have already msys git/cmd in our PATH
		var match = ~/(.*)no-hg-no([\\|\/])cmd$/;
		for(path in Sys.getEnv("PATH").split(";"))
		{
			if(match.match(path.toLowerCase()))
			{
				var newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}
		checkExecutable();
	}
}

class WrongGit extends Git
{
	public function new()
	{
		super();
		this.directory = "no-git";
		this.executable = "no-git";
		this.name = "Git-not-found";
	}

	// copy of Mercurial.searchExecutablebut have a one change - regexp.
	override private function searchExecutable():Void
	{
		super.searchExecutable();

		if(available)
			return;

		// if we have already msys git/cmd in our PATH
		var match = ~/(.*)no-git-no([\\|\/])cmd$/;
		for(path in Sys.getEnv("PATH").split(";"))
		{
			if(match.match(path.toLowerCase()))
			{
				var newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}
		if(checkExecutable())
			return;
		// look at a few default paths
		for(path in ["C:\\Program Files (x86)\\Git\\bin", "C:\\Progra~1\\Git\\bin"])
			if(FileSystem.exists(path))
			{
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + path);
				if(checkExecutable())
					return;
			}
	}
}