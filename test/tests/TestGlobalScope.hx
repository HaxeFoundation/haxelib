package tests;

import sys.FileSystem;

import tests.util.DirectoryState;

import haxelib.ProjectName;
import haxelib.SemVer;
import haxelib.api.Vcs;

using haxe.io.Path;

class TestGlobalScope extends TestScope {

	final scopeDir = new DirectoryState(TestScope.repo,
		["devlib"],
		[
			'lib/.current' => "2.0.0",
			'devlib/.dev' => FileSystem.absolutePath(TestScope.devlibPath),
			'capitalized/.name' => "Capitalized",
			'capitalized/.current' => "1.0.0"
		]
	);

	function initScope():Void {
		scopeDir.add();
	}


	override function tearDown() {
		deleteDirectory('${TestScope.repo}/broken/');
		super.tearDown();
	}

	function testGetPathNonCurrent() {
		// global scope can also get path for non-current versions
		final lib = ProjectName.ofString("lib");

		assertEquals('${TestScope.repo}/${TestScope.lib2Path}', scope.getPath(lib));

		assertEquals('${TestScope.repo}/${TestScope.lib1Path}', scope.getPath(lib, SemVer.ofString("1.0.0")));

		assertEquals('${TestScope.repo}/${TestScope.libGitPath}', scope.getPath(lib, VcsID.Git));
	}

	function testIsInstalledBroken() {
		FileSystem.createDirectory('${TestScope.repo}/broken/');
		assertFalse(scope.isLibraryInstalled(ProjectName.ofString("broken")));
	}

	function testRunScriptNonCurrent() {
		// global scope can also run script for non-current versions
		try {
			scope.runScript(ProjectName.ofString("lib"), {args: ["LIB"]}, VcsID.Git);
			assertTrue(true);
		} catch (e) {
			assertTrue(false);
		}
	}
}
