package tests.util;

import tests.util.DirectoryState;


enum RepositoryState {
	/** Working repository with version 0. **/
	WorkingV0;
	/** The version 0 repository reformatted. **/
	Reformatted;
	/** Same version installed in multiple places. **/
	ConflictingVersions;
	/** `dev` version for same library set in multiple places. **/
	ConflictingDev;
	/** Current version for same library set in multiple places. **/
	ConflictingCurrent;
	/** Unrecognized folders in multiple places. **/
	ConflictingInvalid;

	/** Version 0 repository with non-conflicting custom versions set **/
	CustomVersions;
	/** Reformatted repository with custom versions set **/
	CustomVersionsReformatted;

	/** A repository with a version higher than what is supported. **/
	Incompatible;
	/** A repository with a version 1 lower than what is supported. **/
	OutOfDate;
	/** A empty repository, but still has a repository version file set to current version. **/
	AlmostEmpty;
	/** A completely empty repository (without repository version file) **/
	CompletelyEmpty;
}

class MockRepositories{
	static final CURRENT_REPO_VERSION = @:privateAccess haxelib.api.RepoReformatter.CURRENT_REPO_VERSION;

	public static function generate(repoPath:String, state:RepositoryState) {
		return switch state {
			case WorkingV0:
				new DirectoryState(repoPath, ['LIBRARY', 'Library/1,0,0', 'GitLib/git'], [
					'LIBRARY/.dev' => "/some/path",
					'Library/.current' => "1.0.0",
					'GitLib/.current' => "git"
				]);
			case Reformatted:
				new DirectoryState(repoPath, ['library/1,0,0', 'gitlib/git'], [
					'.repo-version' => '$CURRENT_REPO_VERSION\n',
					'library/.current' => "1.0.0",
					'library/.dev' => "/some/path",
					'library/.name' => "LIBRARY",
					'gitlib/.current' => "git",
					'gitlib/.name' => "GitLib"
				]);
			case ConflictingVersions:
				new DirectoryState(repoPath, ['gitlib/git', 'GITLIB/git'], []);
			case ConflictingDev:
				new DirectoryState(
					repoPath,
					['Library', 'LIBRARY'],
					[
						'Library/.dev' => "/some/path",
						'LIBRARY/.dev' => "/some/path"
					]
				);
			case ConflictingCurrent:
				new DirectoryState(
					repoPath,
					['Library', 'LIBRARY'],
					[
						'Library/.current' => "1.0.0",
						'LIBRARY/.current' => "1.0.0"
					]
				);
			case ConflictingInvalid:
				new DirectoryState(repoPath, ['library/invalid', 'LIBRARY/invalid'], []);
			case CustomVersions:
				new DirectoryState(repoPath, ['library/invalid', 'OTHER/invalid'], ['library/.current' => 'invalid', 'OTHER/.current' => 'invalid']);
			case CustomVersionsReformatted:
				new DirectoryState(repoPath, ['library/invalid', 'other/invalid'],
					[
						'library/.current' => 'invalid',
						'other/.current' => 'invalid',
						'other/.name' => 'OTHER',
						'.repo-version' => '$CURRENT_REPO_VERSION\n',
					]
				);
			case Incompatible:
				new DirectoryState(repoPath, [], ['.repo-version' => '${CURRENT_REPO_VERSION + 1}\n']);
			case OutOfDate:
				new DirectoryState(repoPath, [], ['.repo-version' => '${CURRENT_REPO_VERSION - 1}\n']);
			case AlmostEmpty:
				new DirectoryState(repoPath, [], ['.repo-version' => '$CURRENT_REPO_VERSION\n']);
			case CompletelyEmpty:
				new DirectoryState(repoPath, [], []);
		}
	}

	public static function assertRepoMatchesReality(test:haxe.unit.TestCase, repo:DirectoryState) {
		final successMsg = "Repository matches expected state";
		test.assertEquals(successMsg, try {
			repo.confirmMatch();
			successMsg;
		} catch (e:String) {
			e;
		});
	}
}
