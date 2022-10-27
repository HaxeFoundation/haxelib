/*
 * Copyright (C)2005-2016 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package haxelib.api;

import sys.FileSystem;
import sys.thread.Thread;
import sys.thread.Lock;
import haxelib.VersionData;
using haxelib.api.Vcs;
using StringTools;

private interface IVcs {
	/** The vcs executable. **/
	final executable:String;
	/** Whether or not the executable can be accessed successfully. **/
	var available(get, null):Bool;

	/**
		Clone repository specified in `data` into `libPath`.

		If `flat` is set to true, recursive cloning is disabled.
	**/
	function clone(libPath:String, data:VcsData, flat:Bool = false):Void;

	/**
		Updates repository.
	**/
	function update():Void;

	/**
		Fetches possible remote changes, and returns whether there are any available.
	**/
	function checkUpdate():Bool;

	/**
		Returns whether any uncommited local changes exist.
	**/
	function hasLocalChanges():Bool;

	/**
		Resets all local changes present in the working tree.
	**/
	function resetLocalChanges():Void;
}

/** Enum representing errors that can be thrown during a vcs operation. **/
enum VcsError {
	VcsUnavailable(vcs:Vcs);
	CantCloneRepo(vcs:Vcs, repo:String, ?stderr:String);
	CantCheckoutBranch(vcs:Vcs, branch:String, stderr:String);
	CantCheckoutVersion(vcs:Vcs, version:String, stderr:String);
	CommandFailed(vcs:Vcs, code:Int, stdout:String, stderr:String);
}

/** Base implementation of `IVcs` for `Git` and `Mercurial` to extend. **/
abstract class Vcs implements IVcs {
	/** If set to true, recursive cloning is disabled **/
	public final executable:String;
	public var available(get, null):Bool;

	function new(executable:String, ?debugLog:(message:String)->Void) {
		this.executable = executable;
		if (debugLog != null)
			this.debugLog = debugLog;
	}

	/**
		Creates and returns a Vcs instance for `id`.

		If `debugLog` is specified, it is used to log debug information
		for executable calls.
	**/
	public static function create(id:VcsID, ?debugLog:(message:String)->Void):Null<Vcs> {
		return switch id {
			case Hg:
				new Mercurial("hg", debugLog);
			case Git:
				new Git("git", debugLog);
		};
	}

	/** Returns the sub directory to use for library versions of `id`. **/
	public static function getDirectoryFor(id:VcsID) {
		return switch id {
			case Git: "git";
			case Hg: "hg";
		}
	}

	dynamic function debugLog(msg:String) {}

	abstract function searchExecutable():Bool;

	function getCheckArgs() {
		return [];
	}

	final function checkExecutable():Bool {
		return (executable != null) && try run(getCheckArgs()).code == 0 catch (_:Dynamic) false;
	}

	final function get_available():Bool {
		if (available == null) {
			available = checkExecutable() || searchExecutable();
		}
		return available;
	}

	final function run(args:Array<String>, strict = false):{
		code:Int,
		out:String,
		err:String,
	} {
		inline function print(msg)
			if (msg != "")
				debugLog(msg);

		print("# Running command: " + executable + " " + args.toString() + "\n");

		final proc = command(executable, args);
		if (strict && proc.code != 0)
			throw CommandFailed(this, proc.code, proc.out, proc.err);

		print(proc.out);
		print(proc.err);
		print('# Exited with code ${proc.code}\n');

		return proc;
	}

	static function command(cmd:String, args:Array<String>):{
		code:Int,
		out:String,
		err:String,
	} {
		final p = try {
			new sys.io.Process(cmd, args);
		} catch (e:Dynamic) {
			return {
				code: -1,
				out: "",
				err: Std.string(e)
			}
		};
		// just in case process hangs waiting for stdin
		p.stdin.close();

		final ret = if (Sys.systemName() == "Windows") {
			final streamsLock = new sys.thread.Lock();
			function readFrom(stream:haxe.io.Input, to:{value:String}) {
				to.value = stream.readAll().toString();
				streamsLock.release();
			}

			final out = {value: ""};
			final err = {value: ""};
			Thread.create(readFrom.bind(p.stdout, out));
			Thread.create(readFrom.bind(p.stderr, err));

			final code = p.exitCode();
			for (_ in 0...2) {
				// wait until we finish reading from both streams
				streamsLock.wait();
			}
			{
				code: code,
				out: out.value,
				err: err.value
			};
		} else {
			final out = p.stdout.readAll().toString();
			final err = p.stderr.readAll().toString();
			final code = p.exitCode();
			{
				code: code,
				out: out,
				err: err
			};
		};

		p.close();
		return ret;
	}

}

/** Class wrapping `git` operations. **/
class Git extends Vcs {

	@:allow(haxelib.api.Vcs.create)
	function new(executable:String, ?debugLog:Null<(message:String) -> Void>) {
		super(executable, debugLog);
	}

	override function getCheckArgs() {
		return ["help"];
	}

	function searchExecutable():Bool {
		// if we have already msys git/cmd in our PATH
		final match = ~/(.*)git([\\|\/])cmd$/;
		for (path in Sys.getEnv("PATH").split(";")) {
			if (match.match(path.toLowerCase())) {
				final newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}

		if (checkExecutable())
			return true;

		// look at a few default paths
		for (path in ["C:\\Program Files (x86)\\Git\\bin", "C:\\Progra~1\\Git\\bin"]) {
			if (FileSystem.exists(path)) {
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + path);
				if (checkExecutable())
					return true;
			}
		}
		return false;
	}

	public function checkUpdate():Bool {
		run(["fetch"], true);

		// `git rev-parse @{u}` will fail if detached
		final checkUpstream = run(["rev-parse", "@{u}"]);

		return checkUpstream.out != run(["rev-parse", "HEAD"], true).out;
	}

	public function update() {
		// But if before we pulled specified branch/tag/rev => then possibly currently we haxe "HEAD detached at ..".
		if (run(["rev-parse", "@{u}"]).code != 0) {
			// get parent-branch:
			final branch = {
				final raw = run(["show-branch"]).out;
				final regx = ~/\[([^]]*)\]/;
				if (regx.match(raw))
					regx.matched(1);
				else
					raw;
			}

			run(["checkout", branch, "--force"], true);
		}
		run(["merge"], true);
	}

	public function clone(libPath:String, data:VcsData, flat = false):Void {
		final oldCwd = Sys.getCwd();

		final vcsArgs = ["clone", data.url, libPath];

		if (!flat)
			vcsArgs.push('--recursive');

		if (run(vcsArgs).code != 0)
			throw VcsError.CantCloneRepo(this, data.url/*, ret.out*/);

		Sys.setCwd(libPath);

		final branch = data.commit ?? data.branch;

		if (data.tag != null) {
			final ret = run(["checkout", "tags/" + data.tag]);
			if (ret.code != 0) {
				Sys.setCwd(oldCwd);
				throw VcsError.CantCheckoutVersion(this, data.tag, ret.out);
			}
		} else if (branch != null) {
			final ret = run(["checkout", branch]);
			if (ret.code != 0){
				Sys.setCwd(oldCwd);
				throw VcsError.CantCheckoutBranch(this, branch, ret.out);
			}
		}

		// return prev. cwd:
		Sys.setCwd(oldCwd);
	}

	public function hasLocalChanges():Bool {
		return run(["diff", "--exit-code", "--no-ext-diff"]).code != 0
			|| run(["diff", "--cached", "--exit-code", "--no-ext-diff"]).code != 0;
	}

	public function resetLocalChanges() {
		run(["reset", "--hard"], true);
	}
}

/** Class wrapping `hg` operations. **/
class Mercurial extends Vcs {

	@:allow(haxelib.api.Vcs.create)
	function new(executable:String, ?debugLog:Null<(message:String) -> Void>) {
		super(executable, debugLog);
	}

	function searchExecutable():Bool {
		// if we have already msys git/cmd in our PATH
		final match = ~/(.*)hg([\\|\/])cmd$/;
		for(path in Sys.getEnv("PATH").split(";")) {
			if(match.match(path.toLowerCase())) {
				final newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}
		return checkExecutable();
	}

	public function checkUpdate():Bool {
		run(["pull"]);

		// get new pulled changesets:
		final summary = {
			final out = run(["summary"]).out.rtrim();
			out.substr(out.lastIndexOf("\n") + 1);
		};

		// we don't know any about locale then taking only Digit-exising:s
		return ~/(\d)/.match(summary);
	}

	public function update() {
		run(["update"], true);
	}

	public function clone(libPath:String, data:VcsData, _ = false):Void {
		final vcsArgs = ["clone", data.url, libPath];

		if (data.branch != null) {
			vcsArgs.push("--branch");
			vcsArgs.push(data.branch);
		}

		if (data.commit != null) {
			vcsArgs.push("--rev");
			vcsArgs.push(data.commit);
		}

		if (run(vcsArgs).code != 0)
			throw VcsError.CantCloneRepo(this, data.url/*, ret.out*/);
	}

	public function hasLocalChanges():Bool {
		final diff = run(["diff", "-U", "2", "--git", "--subrepos"]);
		final status = run(["status"]);

		return diff.code + status.code + diff.out.length + status.out.length > 0;
	}

	public function resetLocalChanges() {
		run(["clean"], true);
	}
}
