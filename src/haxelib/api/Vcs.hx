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
		Merges remote changes into repository.
	**/
	function mergeRemoteChanges():Void;

	/**
		Checks for possible remote changes, and returns whether there are any available.
	**/
	function checkRemoteChanges():Bool;

	/**
		Returns whether any uncommited local changes exist.
	**/
	function hasLocalChanges():Bool;

	/**
		Resets all local changes present in the working tree.
	**/
	function resetLocalChanges():Void;

	function getRef():String;

	function getOriginUrl():String;

	function getBranchName():Null<String>;
}

/** Enum representing errors that can be thrown during a vcs operation. **/
enum VcsError {
	VcsUnavailable(vcs:Vcs);
	CantCloneRepo(vcs:Vcs, repo:String, ?stderr:String);
	CantCheckout(vcs:Vcs, ref:String, stderr:String);
	CommandFailed(vcs:Vcs, code:Int, stdout:String, stderr:String);
	SubmoduleError(vcs:Vcs, repo:String, stderr:String);
}

/** Base implementation of `IVcs` for `Git` and `Mercurial` to extend. **/
abstract class Vcs implements IVcs {
	/** If set to true, recursive cloning is disabled **/
	public final executable:String;
	public var available(get, null):Bool;

	private var availabilityChecked = false;

	function new(executable:String, ?debugLog:(message:String) -> Void, ?optionalLog:(message:String) -> Void) {
		this.executable = executable;
		if (debugLog != null)
			this.debugLog = debugLog;
		if (optionalLog != null)
			this.optionalLog = optionalLog;
	}

	/**
		Creates and returns a Vcs instance for `id`.

		If `debugLog` is specified, it is used to log debug information
		for executable calls.
	**/
	public static function create(id:VcsID, ?debugLog:(message:String)->Void, ?optionalLog:(message:String)->Void):Null<Vcs> {
		return switch id {
			case Hg:
				new Mercurial("hg", debugLog);
			case Git:
				new Git("git", debugLog, optionalLog);
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

	dynamic function optionalLog(msg:String) {}

	abstract function searchExecutable():Bool;

	function getCheckArgs() {
		return [];
	}

	final function checkExecutable():Bool {
		return (executable != null) && try run(getCheckArgs()).code == 0 catch (_:Dynamic) false;
	}

	final function get_available():Bool {
		if (!availabilityChecked) {
			available = checkExecutable() || searchExecutable();
			availabilityChecked = true;
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
		#if neko
		if (!((untyped __dollar__version()) <= 240 && Sys.systemName() == "Windows"))
		#end
			p.stdin.close();

		final streamsLock = new sys.thread.Lock();
		function readFrom(stream:haxe.io.Input, to: {value: String}) {
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

		final ret = {
			code: code,
			out: out.value,
			err: err.value
		};
		p.close();
		return ret;
	}
}

/** Class wrapping `git` operations. **/
class Git extends Vcs {

	@:allow(haxelib.api.Vcs.create)
	function new(executable:String, ?debugLog:Null<(message:String) -> Void>, ?optionalLog:Null<(message:String) -> Void>) {
		super(executable, debugLog, optionalLog);
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

	public function checkRemoteChanges():Bool {
		run(["fetch", "--depth=1"], true);

		// `git rev-parse @{u}` will fail if detached
		final checkUpstream = run(["rev-parse", "@{u}"]);
		if (checkUpstream.code != 0) {
			return false;
		}
		return checkUpstream.out != run(["rev-parse", "HEAD"], true).out;
	}

	public function mergeRemoteChanges() {
		run(["reset", "--hard", "@{u}"], true);
	}

	public function clone(libPath:String, data:VcsData, flat = false):Void {
		final vcsArgs = ["clone", data.url, libPath];

		optionalLog('Cloning ${VcsID.Git.getName()} from ${data.url}');

		if (data.branch != null) {
			vcsArgs.push('--single-branch');
			vcsArgs.push('--branch');
			vcsArgs.push(data.branch);
		} else if (data.commit == null) {
			vcsArgs.push('--single-branch');
		}

		final cloneDepth1 = data.commit == null || data.commit.length == 40;
		// we cannot clone like this if the commit hash is short,
		// as fetch requires full hash
		if (cloneDepth1) {
			vcsArgs.push('--depth=1');
		}

		if (run(vcsArgs).code != 0)
			throw VcsError.CantCloneRepo(this, data.url/*, ret.out*/);

		if (data.branch != null && data.commit != null) {
			optionalLog('Checking out branch ${data.branch} at commit ${data.commit} of ${libPath}');
			FsUtils.runInDirectory(libPath, () -> {
				if (cloneDepth1) {
					runCheckoutRelatedCommand(data.commit, ["fetch", "--depth=1", "origin", data.commit]);
				}
				run(["reset", "--hard", data.commit], true);
			});
		} else if (data.commit != null) {
			optionalLog('Checking out commit ${data.commit} of ${libPath}');
			FsUtils.runInDirectory(libPath, checkout.bind(data.commit, cloneDepth1));
		} else if (data.tag != null) {
			optionalLog('Checking out tag/version ${data.tag} of ${VcsID.Git.getName()}');
			FsUtils.runInDirectory(libPath, () -> {
				final tagRef = 'tags/${data.tag}';
				runCheckoutRelatedCommand(tagRef, ["fetch", "--depth=1", "origin", '$tagRef:$tagRef']);
				checkout('tags/${data.tag}', false);
			});
		}

		if (!flat) {
			FsUtils.runInDirectory(libPath, () -> {
				optionalLog('Syncing submodules for ${VcsID.Git.getName()}');
				run(["submodule", "sync", "--recursive"]);

				optionalLog('Downloading/updating submodules for ${VcsID.Git.getName()}');
				final ret = run(["submodule", "update", "--init", "--recursive", "--depth=1", "--single-branch"]);
				if (ret.code != 0)
				{
					throw VcsError.SubmoduleError(this, data.url, ret.out);
				}
			});
		}
	}

	inline function runCheckoutRelatedCommand(ref, args:Array<String>) {
		final ret = run(args);
		if (ret.code != 0) {
			throw VcsError.CantCheckout(this, ref, ret.out);
		}
	}

	function checkout(ref:String, fetch:Bool) {
		if (fetch) {
			runCheckoutRelatedCommand(ref, ["fetch", "--depth=1", "origin", ref]);
		}

		runCheckoutRelatedCommand(ref, ["checkout", ref]);

		// clean up excess branch
		run(["branch", "-D", "@{-1}"]);
	}

	public function getRef():String {
		return run(["rev-parse", "--verify", "HEAD"], true).out.trim();
	}

	public function getOriginUrl():String {
		return run(["ls-remote", "--get-url", "origin"], true).out.trim();
	}

	public function getBranchName():Null<String> {
		final ret = run(["symbolic-ref", "--short", "HEAD"]);
		if (ret.code != 0)
			return null;
		return ret.out.trim();
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

	public function checkRemoteChanges():Bool {
		run(["pull"]);

		// get new pulled changesets:
		final summary = {
			final out = run(["summary"]).out.rtrim();
			out.substr(out.lastIndexOf("\n") + 1);
		};

		// we don't know any about locale then taking only Digit-exising:s
		return ~/(\d)/.match(summary);
	}

	public function mergeRemoteChanges() {
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

		if (data.tag != null) {
			vcsArgs.push("--updaterev");
			vcsArgs.push(data.tag);
		}

		if (run(vcsArgs).code != 0)
			throw VcsError.CantCloneRepo(this, data.url/*, ret.out*/);

		if (data.branch == null && !(data.commit == null && data.tag == null)) {
			FsUtils.runInDirectory(libPath, function() {
				final rcFile = '.hg/hgrc';
				sys.io.File.saveContent(rcFile,
					sys.io.File.getContent(rcFile)
					// unlink from upstream so updates stick to specified commit/tag
					.replace("default =", '# default =')
					// still store url in "haxelib_url" so we can retrieve it if needed
					.replace("[paths]", '[paths]\nhaxelib_url = ${data.url}')
					+ "\n[extensions]\nstrip =\n"
				);
				// also strip to get rid of newer changesets we have already cloned
				run(["strip", data.tag]);
			});
		}
	}

	public function getRef():String {
		final out = run(["identify", "-i"], true).out.trim();
		// if the hash ends with +, there are edits
		if (StringTools.endsWith(out, "+"))
			return out.substr(0, out.length - 2);
		return out;
	}

	public function getOriginUrl():String {
		final ret = run(["paths", "default"]);
		if (ret.code == 0)
			return ret.out.trim();
		return run(["paths", "haxelib_url"], true).out.trim();
	}

	public function getBranchName():Null<String> {
		return run(["identify", "-b"], true).out.trim();
	}

	public function hasLocalChanges():Bool {
		final diff = run(["diff", "-U", "2", "--git", "--subrepos"]);
		final status = run(["status", "-q"]);

		return diff.code + status.code + diff.out.length + status.out.length > 0;
	}

	public function resetLocalChanges() {
		run(["revert", "--all"], true);
	}
}
