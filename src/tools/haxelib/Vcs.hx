package tools.haxelib;

import tools.haxelib.Main;
import sys.FileSystem;

class Vcs
{
	//----------- properties, fields ------------//

	public var name(default, null):String;
	public var directory(default, null):String;
	public var executable(default, null):String;

	public var exists(get_exists, null):Bool;
	private var existingChecked:Bool = false;
	private var executableSearched:Bool = false;

	public static var git(get_git, null):Vcs;
	public static var hg(get_hg, null):Vcs;

	//--------------- constructor ---------------//

	public function new()
	{
		// set defaults:
	}


	//----------------- static ------------------//

	public static function getVcsForDevLib(libPath:String):Null<Vcs>
	{
		return
			if(FileSystem.exists(libPath + "/git") && FileSystem.isDirectory(libPath + "/git"))
				git;
			else if(FileSystem.exists(libPath + "/hg") && FileSystem.isDirectory(libPath + "/hg"))
				hg;
			else
				null;
	}

	static function get_git():Vcs
	{
		return git == null ? (git = new Git()) : git;
	}

	static function get_hg():Vcs
	{
		return hg == null ? (hg = new Mercurial()) : hg;
	}


	//--------------- initialize ----------------//

	private function searchExecutable():Void
	{
		executableSearched = true;
	}

	private function checkExecutable():Bool
	{
		exists =
		executable != null && try
		{
			cmd(executable, []);
			true;
		}
		catch(e:Dynamic) false;
		existingChecked = true;

		if(!exists && !executableSearched)
			searchExecutable();

		return exists;
	}

	@:final function get_exists():Bool
	{
		if(!existingChecked)
			checkExecutable();
		return this.exists;
	}

	//----------------- ctrl -------------------//

	private function cmd(cmd:String, args:Array<String>)
	{
		var p = new sys.io.Process(cmd, args);
		var code = p.exitCode();
		return {code:code, out:code == 0 ? p.stdout.readAll().toString() : p.stderr.readAll().toString()};
	}

	public function cloneToCwd()
	{

	}

	public function updateInCwd(libName:String):Bool
	{
		return false;
	}
}


class Git extends Vcs
{
	public function new()
	{
		super();

		name = "Git";
		directory = "git";
		executable = "git";
	}

	override private function searchExecutable():Void
	{
		super.searchExecutable();

		if(exists)
			return;

		// if we have already msys git/cmd in our PATH
		var match = ~/(.*)git([\\|\/])cmd$/;
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

	override public function updateInCwd(libName:String):Bool
	{
		var doPull = true;

		if(0 != Sys.command(executable, ["diff", "--exit-code"]) || 0 != Sys.command(executable, ["diff", "--cached", "--exit-code"]))
		{
			switch Main.ask("Reset changes to " + libName + " git repo so we can pull latest version?")
			{
				case Yes:
					Sys.command(executable, ["reset", "--hard"]);
				case No:
					doPull = false;
					Main.print("Git repo left untouched");
			}
		}
		if(doPull){
			Sys.command("git", ["pull"]);
		}
		return doPull;
	}
}

class Mercurial extends Vcs
{
	public function new()
	{
		super();

		name = "Mercurial";
		directory = "hg";
		executable = "hg";
	}

	override private function searchExecutable():Void
	{
		super.searchExecutable();

		if(exists)
			return;

		// if we have already msys git/cmd in our PATH
		var match = ~/(.*)hg([\\|\/])cmd$/;
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

	override public function updateInCwd(libName:String):Bool
	{
		var changed = false;
		cmd(executable, ["pull"]);
		var summary = cmd(executable, ["summary"]).out;
		var diff = cmd(executable, ["diff", "-U", "2", "--git", "--subrepos"]);
		var status = cmd(executable, ["status"]);

		// get new pulled changesets:
		// (and search num of sets)
		summary = summary.substr(0, summary.length - 1);
		summary = summary.substr(summary.lastIndexOf("\n") + 1);
		// we don't know any about locale then taking only Digit-exising:s
		changed = ~/(\d)/.match(summary);
		if(changed)
			// print new pulled changesets:
			Main.print(summary);


		if(diff.code + status.code + diff.out.length + status.out.length != 0)
		{
			Main.print(diff.out);
			switch Main.ask("Reset changes to " + libName + " " + name + " repo so we can update to latest version?")
			{
				case Yes:
					Sys.command(executable, ["update", "--clean"]);
				case No:
					changed = false;
					Main.print(name + " repo left untouched");
			}
		}
		else if(changed)
			Sys.command(executable, ["update"]);

		return changed;
	}
}