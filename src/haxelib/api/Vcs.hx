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
import haxelib.VersionData.VcsID;
using haxelib.api.Vcs;

interface IVcs {
	/** The name of the vcs system. **/
	final name:String;
	/** The directory used to install vcs library versions to. **/
	final directory:String;
	/** The vcs executable. **/
	final executable:String;
	/** Whether or not the executable can be accessed successfully. **/
	var available(get, null):Bool;

	/**
		Clone repository at `vcsPath` into `libPath`.

		If `branch` is specified, the repository is checked out to that branch.

		`version` can also be specified for tags in git or revisions in mercurial.

		`debugLog` will be used to log executable output.
	**/
	function clone(libPath:String, vcsPath:String, ?branch:String, ?version:String, ?debugLog:(msg:String)->Void):Void;

	/**
		Updates repository in CWD or CWD/`Vcs.directory` to HEAD.
		For git CWD must be in the format "...haxelib-repo/lib/git".

		By default, uncommitted changes prevent updating.
		If `confirm` is passed in, the changes may occur
		if `confirm` returns true.

		`debugLog` will be used to log executable output.

		`summaryLog` may be used to log summaries of changes.

		Returns `true` if update successful.
	**/
	function update(?confirm:()->Bool, ?debugLog:(msg:String)->Void, ?summaryLog:(msg:String)->Void):Bool;
}

/** Enum representing errors that can be thrown during a vcs operation. **/
enum VcsError {
	VcsUnavailable(vcs:Vcs);
	CantCloneRepo(vcs:Vcs, repo:String, ?stderr:String);
	CantCheckoutBranch(vcs:Vcs, branch:String, stderr:String);
	CantCheckoutVersion(vcs:Vcs, version:String, stderr:String);
	CommandFailed(vcs:Vcs, code:Int, stdout:String, stderr:String);
}

/** Exception thrown when a vcs update is cancelled. **/
class VcsUpdateCancelled extends haxe.Exception {}

/** Base implementation of `IVcs` for `Git` and `Mercurial` to extend. **/
abstract class Vcs implements IVcs {
	/** If set to true, recursive cloning is disabled **/
	public static var flat = false;

	public final name:String;
	public final directory:String;
	public final executable:String;
	public var available(get, null):Bool;

	var availabilityChecked = false;
	var executableSearched = false;

	function new(executable:String, directory:String, name:String) {
		this.name = name;
		this.directory = directory;
		this.executable = executable;
	}

	static var reg:Map<VcsID, Vcs>;

	/** Returns the Vcs instance for `id`. **/
	public static function get(id:VcsID):Null<Vcs> {
		if (reg == null)
			reg = [
				VcsID.Git => new Git("git", "git", "Git"),
				VcsID.Hg => new Mercurial("hg", "hg", "Mercurial")
			];

		return reg.get(id);
	}

	/** Returns the sub directory to use for library versions of `id`. **/
	public static function getDirectoryFor(id:VcsID):String {
		return switch (get(id)) {
			case null: throw 'Unable to get directory for $id';
			case vcs: vcs.directory;
		}
	}

	static function set(id:VcsID, vcs:Vcs, ?rewrite:Bool):Void {
		final existing = reg.get(id) != null;
		if (!existing || rewrite)
			reg.set(id, vcs);
	}

	/** Returns the relevant Vcs if a vcs version is installed at `libPath`. **/
	public static function getVcsForDevLib(libPath:String):Null<Vcs> {
		for (k in reg.keys()) {
			if (FileSystem.exists(libPath + "/" + k) && FileSystem.isDirectory(libPath + "/" + k))
				return reg.get(k);
		}
		return null;
	}

	function searchExecutable():Void {
		executableSearched = true;
	}

	function checkExecutable():Bool {
		available = (executable != null) && try run([]).code == 0 catch(_:Dynamic) false;
		availabilityChecked = true;

		if (!available && !executableSearched)
			searchExecutable();

		return available;
	}

	final function get_available():Bool {
		if (!availabilityChecked)
			checkExecutable();
		return available;
	}

	final function run(args:Array<String>, ?debugLog:(msg:String) -> Void, strict = false):{
		code:Int,
		out:String,
		err:String,
	} {
		inline function print(msg)
			if (debugLog != null && msg != "")
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
		}
		final out = p.stdout.readAll().toString();
		final err = p.stderr.readAll().toString();
		final code = p.exitCode();
		final ret = {
			code: code,
			out: out,
			err: err
		};
		p.close();
		return ret;
	}

	public abstract function clone(libPath:String, vcsPath:String, ?branch:String, ?version:String, ?debugLog:(msg:String)->Void):Void;

	public abstract function update(?confirm:() -> Bool, ?debugLog:(msg:String) -> Void, ?summaryLog:(msg:String) -> Void):Bool;
}

/** Class wrapping `git` operations. **/
class Git extends Vcs {

	@:allow(haxelib.api.Vcs.get)
	function new(executable:String, directory:String, name:String) {
		super(executable, directory, name);
	}

	override function checkExecutable():Bool {
		// with `help` cmd because without any cmd `git` can return exit-code = 1.
		available = (executable != null) && try run(["help"]).code == 0 catch(_:Dynamic) false;
		availabilityChecked = true;

		if (!available && !executableSearched)
			searchExecutable();

		return available;
	}

	override function searchExecutable():Void {
		super.searchExecutable();

		if (available)
			return;

		// if we have already msys git/cmd in our PATH
		final match = ~/(.*)git([\\|\/])cmd$/;
		for (path in Sys.getEnv("PATH").split(";")) {
			if (match.match(path.toLowerCase())) {
				final newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}

		if (checkExecutable())
			return;

		// look at a few default paths
		for (path in ["C:\\Program Files (x86)\\Git\\bin", "C:\\Progra~1\\Git\\bin"]) {
			if (FileSystem.exists(path)) {
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + path);
				if (checkExecutable())
					return;
			}
		}
	}

	public function update(?confirm:()->Bool, ?debugLog:(msg:String)->Void, ?_):Bool {
		if (
			run(["diff", "--exit-code", "--no-ext-diff"], debugLog).code != 0
			|| run(["diff", "--cached", "--exit-code", "--no-ext-diff"], debugLog).code != 0
		) {
			if (confirm == null || !confirm())
				throw new VcsUpdateCancelled('$name update in ${Sys.getCwd()} was cancelled');
			run(["reset", "--hard"], debugLog, true);
		}

		run(["fetch"], debugLog, true);

		// `git rev-parse @{u}` will fail if detached
		final checkUpstream = run(["rev-parse", "@{u}"], debugLog);

		if (checkUpstream.out == run(["rev-parse", "HEAD"], debugLog, true).out)
			return false; // already up to date

		// But if before we pulled specified branch/tag/rev => then possibly currently we haxe "HEAD detached at ..".
		if (checkUpstream.code != 0) {
			// get parent-branch:
			final branch = {
				final raw = run(["show-branch"], debugLog).out;
				final regx = ~/\[([^]]*)\]/;
				if (regx.match(raw))
					regx.matched(1);
				else
					raw;
			}

			run(["checkout", branch, "--force"], debugLog, true);
		}
		run(["merge"], debugLog, true);
		return true;
	}

	public function clone(libPath:String, url:String, ?branch:String, ?version:String, ?debugLog:(msg:String)->Void):Void {
		final oldCwd = Sys.getCwd();

		final vcsArgs = ["clone", url, libPath];

		if (!Vcs.flat)
			vcsArgs.push('--recursive');

		if (run(vcsArgs, debugLog).code != 0)
			throw VcsError.CantCloneRepo(this, url/*, ret.out*/);

		Sys.setCwd(libPath);

		if (version != null && version != "") {
			final ret = run(["checkout", "tags/" + version], debugLog);
			if (ret.code != 0) {
				Sys.setCwd(oldCwd);
				throw VcsError.CantCheckoutVersion(this, version, ret.out);
			}
		} else if (branch != null) {
			final ret = run(["checkout", branch], debugLog);
			if (ret.code != 0){
				Sys.setCwd(oldCwd);
				throw VcsError.CantCheckoutBranch(this, branch, ret.out);
			}
		}

		// return prev. cwd:
		Sys.setCwd(oldCwd);
	}
}

/** Class wrapping `hg` operations. **/
class Mercurial extends Vcs {

	@:allow(haxelib.api.Vcs.get)
	function new(executable:String, directory:String, name:String) {
		super(executable, directory, name);
	}

	override function searchExecutable():Void {
		super.searchExecutable();

		if (available)
			return;

		// if we have already msys git/cmd in our PATH
		final match = ~/(.*)hg([\\|\/])cmd$/;
		for(path in Sys.getEnv("PATH").split(";")) {
			if(match.match(path.toLowerCase())) {
				final newPath = match.matched(1) + executable + match.matched(2) + "bin";
				Sys.putEnv("PATH", Sys.getEnv("PATH") + ";" + newPath);
			}
		}
		checkExecutable();
	}

	public function update(?confirm:()->Bool, ?debugLog:(msg:String)->Void, ?summaryLog:(msg:String)->Void):Bool {
		inline function log(msg:String) if(summaryLog != null) summaryLog(msg);

		run(["pull"], debugLog);
		var summary = run(["summary"], debugLog).out;
		final diff = run(["diff", "-U", "2", "--git", "--subrepos"], debugLog);
		final status = run(["status"], debugLog);

		// get new pulled changesets:
		// (and search num of sets)
		summary = summary.substr(0, summary.length - 1);
		summary = summary.substr(summary.lastIndexOf("\n") + 1);
		// we don't know any about locale then taking only Digit-exising:s
		final changed = ~/(\d)/.match(summary);
		if (changed)
			// print new pulled changesets:
			log(summary);

		if (diff.code + status.code + diff.out.length + status.out.length != 0) {
			log(diff.out);
			if (confirm == null || !confirm())
				throw new VcsUpdateCancelled('$name update in ${Sys.getCwd()} was cancelled');
			run(["update", "--clean"], debugLog, true);
		} else if (changed) {
			run(["update"], debugLog, true);
		}

		return changed;
	}

	public function clone(libPath:String, url:String, ?branch:String, ?version:String, ?debugLog:(msg:String)->Void):Void {
		final vcsArgs = ["clone", url, libPath];

		if (branch != null) {
			vcsArgs.push("--branch");
			vcsArgs.push(branch);
		}

		if (version != null) {
			vcsArgs.push("--rev");
			vcsArgs.push(version);
		}

		if (run(vcsArgs, debugLog).code != 0)
			throw VcsError.CantCloneRepo(this, url/*, ret.out*/);
	}
}
