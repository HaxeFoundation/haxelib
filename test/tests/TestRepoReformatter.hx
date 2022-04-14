package tests;

import sys.FileSystem;

import haxelib.api.RepoManager;
import haxelib.api.Repository;

import tests.util.DirectoryState;

using StringTools;
using Lambda;
using haxelib.api.RepoReformatter;
using tests.util.MockRepositories;

class TestRepoReformatter extends TestBase {
	static final dir = "tmp";

	static final CURRENT_VERSION = @:privateAccess RepoReformatter.CURRENT_REPO_VERSION;

	static var origRepo:String;
	var repo:Repository;

	private var repoPath(get, never):String;
	private function get_repoPath() {
		return '$dir/haxelib-repo';
	}

	private function getRepo():Repository {
		FileSystem.createDirectory(repoPath);
		origRepo = RepoManager.getGlobalPath();
		RepoManager.setGlobalPath(repoPath);
		return Repository.getGlobal();
	}

	private function cleanUpRepo():Void {
		RepoManager.setGlobalPath(origRepo);
	}

	override function setup() {
		// handle cwd
		FileSystem.createDirectory("tmp");

		// init repo
		repo = getRepo();
	}

	override function tearDown() {
		deleteDirectory("tmp");
		cleanUpRepo();
	}

	function assertSuccess(f:() -> Void) {
		final successMsg = "Function ran successfully";
		assertEquals(successMsg, try {
			f();
			successMsg;
		} catch (e:String) {
			'Function threw an unexpected excpetion $e';
		});
	}

	function assertErrorContains(msg:String, f:() -> Void) {
		assertTrue((try {
			f();
			"";
		} catch (e:String) {
			e;
		}).contains(msg));
	}

	function testDoesRepositoryRequireReformat():Void {
		// fresh repo doesn't require reformat
		assertFalse(repo.isRepositoryIncompatible());

		// no file
		MockRepositories.generate(repoPath, CompletelyEmpty).build();
		assertTrue(repo.doesRepositoryRequireReformat());

		// after reformatting
		repo.reformat();
		assertFalse(repo.doesRepositoryRequireReformat());

		// version lower than current
		MockRepositories.generate(repoPath, OutOfDate).build();
		assertTrue(repo.doesRepositoryRequireReformat());

		// version equal to current
		MockRepositories.generate(repoPath, AlmostEmpty).build();
		assertFalse(repo.doesRepositoryRequireReformat());

		// version higher than current
		MockRepositories.generate(repoPath, Incompatible).build();
		assertFalse(repo.doesRepositoryRequireReformat());
	}

	function testIsRepositoryIncompatible():Void {
		// fresh repo is always compatible
		assertFalse(repo.doesRepositoryRequireReformat());

		// no file
		MockRepositories.generate(repoPath, CompletelyEmpty).build();
		assertFalse(repo.isRepositoryIncompatible());

		// after reformatting
		repo.reformat();
		assertFalse(repo.isRepositoryIncompatible());

		// version lower than current
		MockRepositories.generate(repoPath, OutOfDate).build();
		assertFalse(repo.isRepositoryIncompatible());

		// version equal to current
		MockRepositories.generate(repoPath, AlmostEmpty).build();
		assertFalse(repo.isRepositoryIncompatible());

		// version higher than current
		MockRepositories.generate(repoPath, Incompatible).build();
		assertTrue(repo.isRepositoryIncompatible());
	}

	function testReformatIncompatible():Void {
		// version higher than current should fail
		MockRepositories.generate(repoPath, Incompatible).build();
		assertErrorContains('Repository has version ${CURRENT_VERSION + 1}, but this library only supports up to $CURRENT_VERSION.\n'
			+ 'Reformatting cannot be done.',
			repo.reformat.bind(null));
	}

	/** Nothing should happen if we try to reformat an already up to date repository **/
	function testReformatCurrent():Void {
		final reformattedRepo = MockRepositories.generate(repoPath, Reformatted);
		reformattedRepo.build();

		// no change if we run again
		assertSuccess(repo.reformat.bind(null));
		this.assertRepoMatchesReality(reformattedRepo);
	}

	// test reformatting from version 0
	function testReformatV0():Void {
		// valid repository that should cause no issues
		MockRepositories.generate(repoPath, WorkingV0).build();
		assertSuccess(repo.reformat.bind(null));

		final reformattedRepo = MockRepositories.generate(repoPath, Reformatted);
		this.assertRepoMatchesReality(reformattedRepo);
	}

	private function attemptReformat(repoState:DirectoryState, expectedError:String) {
		repoState.build();
		if (Sys.systemName() == "Windows") {
			// windows is case insensitive, so the broken repos are already impossible to form
			assertSuccess(repo.reformat.bind(null));
			return;
		}
		assertErrorContains(expectedError, repo.reformat.bind(null));
		// repo should not change if reformatting fails
		this.assertRepoMatchesReality(repoState);
	}

	function testReformatV0Broken() {
		attemptReformat(MockRepositories.generate(repoPath, ConflictingVersions), "There are two conflicting versions in:");
		attemptReformat(MockRepositories.generate(repoPath, ConflictingDev), "There are two conflicting dev versions set:");
		attemptReformat(MockRepositories.generate(repoPath, ConflictingCurrent), "There are two conflicting current versions set:");
		attemptReformat(MockRepositories.generate(repoPath, ConflictingInvalid), "There are two conflicting unrecognized files/folders:");
	}

	function testCustomVersions() {
		MockRepositories.generate(repoPath, CustomVersions).build();
		assertSuccess(repo.reformat.bind(null));

		this.assertRepoMatchesReality(MockRepositories.generate(repoPath, CustomVersionsReformatted));
	}
}
