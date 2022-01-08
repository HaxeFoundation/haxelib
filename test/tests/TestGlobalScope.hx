package tests;

import sys.FileSystem;

import haxelib.Data;
import haxelib.SemVer;
import haxelib.api.Vcs;

using haxe.io.Path;

class TestGlobalScope extends TestScope {
	function initScope():Void {
		File.saveContent('${TestScope.repo}/lib/.current', "2.0.0");
		FileSystem.createDirectory('${TestScope.repo}/devlib');
		File.saveContent('${TestScope.repo}/devlib/.dev', FileSystem.absolutePath(TestScope.devlibPath));
		File.saveContent('${TestScope.repo}/capitalized/.name', "Capitalized");
		File.saveContent('${TestScope.repo}/capitalized/.current', "1.0.0");
	}


	override function tearDown() {
		deleteDirectory('${TestScope.repo}/broken/');
		super.tearDown();
	}

	function testGetPathNonCurrent() {
		// global scope can also get path for non-current versions
		final lib = ProjectName.ofString("lib");

		assertEquals(TestScope.lib2Path, scope.getPath(lib));

		assertEquals(TestScope.lib1Path, scope.getPath(lib, SemVer.ofString("1.0.0")));

		assertEquals(TestScope.libGitPath, scope.getPath(lib, VcsID.Git));
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
