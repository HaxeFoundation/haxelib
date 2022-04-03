package tests.util;

import sys.io.Process;

/**
	Makes library at `libPath` into a git repo and commits all files.
**/
function makeGitRepo(libPath:String) {
	final oldCwd = Sys.getCwd();

	Sys.setCwd(libPath);

	final cmd = "git";

	runCommand(cmd, ["init"]);
	runCommand(cmd, ["config", "user.email", "you@example.com"]);
	runCommand(cmd, ["config", "user.name", "Your Name"]);

	runCommand(cmd, ["add", "-A"]);
	runCommand(cmd, ["commit", "-m", "Create repo"]);
	// different systems may have different default branch names set
	runCommand(cmd, ["branch", "--move", "main"]);

	Sys.setCwd(oldCwd);
}

private function runCommand(cmd:String, args:Array<String>) {
	final process = new sys.io.Process(cmd, args);
	final code = process.exitCode();
	final output = if (code != 0) {
		final stdout = process.stdout.readAll().toString();
		final stderr = process.stderr.readAll().toString();
		'Stdout:\n$stdout\nStderr:\n$stderr';
	} else '';
	process.close();
	if (code != 0)
		throw 'Process error $code when running: $cmd $args\n$output';
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
