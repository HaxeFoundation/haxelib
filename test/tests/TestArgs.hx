package tests;

import haxe.unit.TestCase;
import haxelib.client.Args;

class TestArgs extends TestCase {

	public function testPriorityFlags() {
		final priorityFlags = Args.extractPriorityFlags([
					"--debug", "--global", "--system", "--skip-dependencies", "--no-timeout",
					"--flat", "--always", "version"
			]);
		// priority
		assertTrue(priorityFlags.contains(Debug));
		assertTrue(priorityFlags.contains(Global));
		assertTrue(priorityFlags.contains(System));

		// non priority
		assertFalse(priorityFlags.contains(SkipDependencies));
		assertFalse(priorityFlags.contains(NoTimeout));
		assertFalse(priorityFlags.contains(Flat));
		assertFalse(priorityFlags.contains(Always));

		// should not give any errors, even with other invalid arguments
		try {
			Args.extractPriorityFlags([
				"--system",
				"invalidcommand",
				"--cwd"
			]);
			assertTrue(true);
		} catch(e:haxe.Exception){
			assertTrue(false);
		}
	}

	public function testFlags() {
		final flags = Args.extractAll([
			"--debug", "--global", "--system", "--skip-dependencies", "--no-timeout",
			"--flat", "--always", "version"
		]).flags;
		// given
		assertTrue(flags.contains(Debug));
		assertTrue(flags.contains(Global));
		assertTrue(flags.contains(System));
		assertTrue(flags.contains(SkipDependencies));
		assertTrue(flags.contains(NoTimeout));
		assertTrue(flags.contains(Flat));
		assertTrue(flags.contains(Always));

		// not given
		assertFalse(flags.contains(Quiet));
		assertFalse(flags.contains(Never));
	}

	public function testMutuallyExclusiveFlags() {
		// debug and quiet
		assertFalse(areSwitchesValid(["--debug", "--quiet", "version"]));
		assertFalse(areSwitchesValid(["--quiet", "--debug", "version"]));

		// always and never
		assertFalse(areSwitchesValid(["--always", "--never", "version"]));
		assertFalse(areSwitchesValid(["--never", "--always", "version"]));

		// everything
		assertFalse(areSwitchesValid(["--never", "--always", "--debug", "--quiet", "version"]));
	}

	function areSwitchesValid(args:Array<String>):Bool {
		try {
			Args.extractAll(args);
			return true;
		} catch (e:SwitchError) {
			return false;
		}
	}

	public function testOptions() {
		// one value given
		final remote = Args.extractAll(["--remote", "remotePath", "version"]).options[Remote];
		assertEquals("remotePath", remote);

		// option without value should give error
		assertFalse(areSwitchesValid(["version", "--remote"]));

		// when a normal option is repeated, should just give the last one.
		final remote = Args.extractAll(["--remote", "remotePath", "--remote", "otherPath", "version"]).options[Remote];
		assertEquals("otherPath", remote);

		// not included
		final remote = Args.extractAll(["version"]).options[Remote];
		assertEquals(null, remote);
	}

	public function testRepeatedOptions() {
		// test once
		final dirs = Args.extractAll(["--cwd", "../path", "version"]).repeatedOptions[Cwd];
		assertEquals(1, dirs.length);
		assertEquals("../path", dirs[0]);

		// multiple times
		final dirs = Args.extractAll(["--cwd", "../path", "--cwd", "path2", "version"]).repeatedOptions[Cwd];
		assertEquals(2, dirs.length);
		assertEquals("../path", dirs[0]);
		assertEquals("path2", dirs[1]);

		// no value given is not valid
		assertFalse(areSwitchesValid(["version", "--cwd"]));

		// no value given
		final dirs = Args.extractAll(["version"]).repeatedOptions[Cwd];
		assertEquals(null, dirs);
	}

	public function testSingleDashes() {
		// flags
		final flags = Args.extractAll([
			"-debug", "-skip-dependencies", "version"
		]).flags;

		assertTrue(flags.contains(Debug));
		assertTrue(flags.contains(SkipDependencies));
		// options
		final argsInfo = Args.extractAll(["-cwd", "path", "-remote", "remotePath", "version"]);

		assertEquals("path", argsInfo.repeatedOptions[Cwd][0]);
		assertEquals("remotePath", argsInfo.options[Remote]);

		// mixing single and double
		final directories = Args.extractAll(["-cwd", "path", "--cwd", "otherPath", "version"]).repeatedOptions[Cwd];

		assertEquals("path", directories[0]);
		assertEquals("otherPath", directories[1]);
	}

	public function testAliases() {
		final argsInfo = Args.extractAll(["-R", "remotePath", "--notimeout", "version"]);

		assertEquals("remotePath", argsInfo.options[Remote]);
		assertTrue(argsInfo.flags.contains(NoTimeout));
	}

	public function testCommands() {
		// basic
		assertEquals(Path, Args.extractAll(["path", "libname", "--debug"]).command);
		assertEquals(Help, Args.extractAll(["help"]).command);
		assertEquals(Search, Args.extractAll(["search", "hello"]).command);

		// aliased
		assertEquals(Update, Args.extractAll(["upgrade"]).command);

		// no command
		assertFalse(isCommandValid([]));

		// unknown command
		assertFalse(isCommandValid(["hfiodsahfi"]));
	}

	function isCommandValid(args:Array<String>):Bool {
		try {
			Args.extractAll(args);
			return true;
		} catch (e:InvalidCommand) {
			return false;
		}
	}

	public function testCommandArguments() {
		final args = Args.extractAll(["path", "libname", "--debug"]).mainArgs;

		assertEquals("libname", args[0]);
		// ensure flag IS captured and not given here
		assertEquals(null, args[1]);

		// test retrieving all arguments
		final args = Args.extractAll(["path", "libname", "--debug", "otherlibname", "--always"]).mainArgs;

		final expectedArgs = ["libname", "otherlibname"];

		assertEquals(expectedArgs.length, args.length);

		for(i in 0...expectedArgs.length) {
			assertEquals(expectedArgs[i], args[i]);
		}

	}

	public function testRunCommand() {
		final args = Args.extractAll(["run", "libname", "--debug", "value"]).mainArgs;

		assertEquals("libname", args[0]);
		// ensure flag ISN'T captured and is still given
		assertEquals("--debug", args[1]);
		assertEquals("value", args[2]);
	}

}
