package tests.integration;

import sys.FileSystem;
import haxe.ds.Either;

import tests.util.DirectoryState;

using tests.util.MockRepositories;

class TestFixRepo extends IntegrationTests {
	static final fullRepoPath = Path.join([projectRoot, repo]);

	final oldRepoV0 = MockRepositories.generate(fullRepoPath, WorkingV0);

	function runWithEnvironment<T>(f:()->T, env:Map<String, String>):T {
		final oldValues = [for (name in env.keys()) name => Sys.getEnv(name)];

		for (name => value in env) {
			Sys.putEnv(name, value);
		}

		final returned:Either<T, haxe.Exception> = try {
			Left(f());
		} catch (e) {
			Right(e);
		}

		for (name => value in oldValues) {
			Sys.putEnv(name, value);
		}

		return switch (returned) {
			case Left(val): val;
			case Right(e): throw e;
		}
	}

	function getWarning() {
		final r = haxelib(["dev", "somelib", "libraries"]).result();
		assertSuccess(r);
		return r.err.trim();
	}

	function testFixRepoWarning() {
		// no warning for properly initialized repo
		assertEquals("", getWarning());

		// no warning for completely empty repo
		deleteDirectory(fullRepoPath);
		FileSystem.createDirectory(fullRepoPath);
		assertEquals("", getWarning());

		// no warning for newly creating local repo
		final r = haxelib(["newrepo"]).result();
		assertSuccess(r);

		assertEquals("", getWarning());
		final r = haxelib(["deleterepo"]).result();
		assertSuccess(r);

		// no warning when using an empty repository configured using HAXELIB_PATH
		final tmp = "tmp";
		FileSystem.createDirectory(tmp);
		assertEquals("", runWithEnvironment(getWarning, ["HAXELIB_PATH" => tmp]));
		deleteDirectory(tmp);

		// simulate an old repository
		oldRepoV0.build();
		assertEquals("Warning: Repository requires reformatting. To reformat, run `haxelib fixrepo`.", getWarning());

		// check that it suggests `--global` if we use it
		final r = haxelib(["dev", "somelib", "libraries", "--global"]).result();
		assertSuccess(r);
		assertEquals("Warning: Repository requires reformatting. To reformat, run `haxelib fixrepo --global`.", r.err.trim());
	}

	function testIncompatible() {
		MockRepositories.generate(fullRepoPath, Incompatible).build();

		final r = haxelib(["fixrepo"]).result();
		assertFail(r);
		assertTrue(r.err.startsWith("Error:"));
		assertTrue(r.err.trim().endsWith("Reformatting cannot be done."));
	}


	final reformattedRepo = MockRepositories.generate(fullRepoPath, Reformatted);

	function testCurrent() {
		reformattedRepo.build();

		// no change if we run again
		final r = haxelib(["fixrepo"]).result();
		assertSuccess(r);

		this.assertRepoMatchesReality(reformattedRepo);
	}

	function testFixingV0() {
		// valid repository that should cause no issues
		oldRepoV0.build();

		final r = haxelib(["fixrepo"]).result();
		assertSuccess(r);

		this.assertRepoMatchesReality(reformattedRepo);
	}

	function attemptFix(repoState:DirectoryState, expectedError:String) {
		repoState.build();
		final result = haxelib(["fixrepo"]).result();
		if (Sys.systemName() == "Windows") {
			// windows is case insensitive, so the broken repos are already impossible to form
			assertSuccess(result);
			return;
		}
		assertFail(result);
		assertTrue(result.err.contains(expectedError));
		// repo should not change if reformatting fails
		this.assertRepoMatchesReality(repoState);
	}

	function testFixingV0Broken() {
		attemptFix(MockRepositories.generate(fullRepoPath, ConflictingVersions), "There are two conflicting versions in:");
		attemptFix(MockRepositories.generate(fullRepoPath, ConflictingDev), "There are two conflicting dev versions set:");
		attemptFix(MockRepositories.generate(fullRepoPath, ConflictingCurrent), "There are two conflicting current versions set:");
		attemptFix(MockRepositories.generate(fullRepoPath, ConflictingInvalid), "There are two conflicting unrecognized files/folders:");
	}

	function testCustomVersions() {
		MockRepositories.generate(fullRepoPath, CustomVersions).build();
		final result = haxelib(["fixrepo"]).result();
		assertSuccess(result);

		this.assertRepoMatchesReality(MockRepositories.generate(fullRepoPath, CustomVersionsReformatted));
	}
}
