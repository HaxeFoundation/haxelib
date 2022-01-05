package tests.integration;

import sys.io.Process;
import haxe.io.Path;

/**
	Makes library at `libPath` into a git repo and commits all files.
**/
function makeGitRepo(libPath:String) {
	final oldCwd = Sys.getCwd();

	Sys.setCwd(libPath);

	final cmd = "git";

	runCommand(cmd, ["init"]);
	runCommand(cmd, ["add", "-A"]);
	runCommand(cmd, ["commit", "-m", "Create repo"]);

	Sys.setCwd(oldCwd);
}

private function runCommand(cmd:String, args:Array<String>) {
	final process = new sys.io.Process(cmd, args);
	final code = process.exitCode();
	process.close();
	if (code != 0)
		throw 'Process error $code when running: $cmd $args';
}

function resetGitRepo(libPath:String) {
	final gitDirectory = '$libPath/.git/';
	HaxelibTests.deleteDirectory(gitDirectory);
}

function makeHgRepo(libPath:String) {
	final oldCwd = Sys.getCwd();

	Sys.setCwd(libPath);

	final cmd = "hg";

	runCommand(cmd, ["init"]);
	runCommand(cmd, ["add"]);
	runCommand(cmd, ["commit", "-m", "Create repo"]);

	Sys.setCwd(oldCwd);
}

function resetHgRepo(libPath:String) {
	final hgDirectory = '$libPath/.hg/';
	HaxelibTests.deleteDirectory(hgDirectory);
}
