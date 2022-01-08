package tests;

import sys.io.File;
import sys.FileSystem;

import haxelib.Data;
import haxelib.SemVer;

import haxelib.api.Vcs;
import haxelib.api.LibraryData;
import haxelib.api.Scope;
import haxelib.api.RepoManager;
import haxelib.api.ScriptRunner.ScriptError;

using haxe.io.Path;
using Lambda;

abstract class TestScope extends TestBase {
	static final REPO = "haxelib-repo";
	static final origRepo = RepoManager.getGlobalPath();
	static final repo = Path.join([Sys.getCwd(), "test", REPO]);
	static final lib1Path = '$repo/lib/1,0,0/';
	static final lib2Path = '$repo/lib/2,0,0/';
	static final libGitPath = '$repo/lib/git/';

	static final devlibPath = 'tmp/devlib/';
	static final capitalizedPath = '$repo/capitalized/1,0,0/';

	var scope:Scope;

	override function setup() {
		RepoManager.setGlobalPath(repo);
		initRepo();
		initScope();
		scope = getScope();
		scope.repository.setDevPath(ProjectName.ofString("haxelib"), Sys.getCwd());
	}

	override function tearDown() {
		RepoManager.setGlobalPath(origRepo);
		try {
			RepoManager.deleteLocal();
		} catch (e:RepoException){
			// gone already
		}
	}

	/**
		Sets lib to version 2.0.0, sets an override for `devlib` to `devlibDevPath`, and sets correct name
		for `Capitalized`.
	**/
	abstract private function initScope():Void;

	private function initRepo() {
		FileSystem.createDirectory(lib1Path);
		File.saveContent('$lib1Path/haxelib.json', '{"name": "lib", "version":"1.0.0"}');

		FileSystem.createDirectory(lib2Path);
		File.saveContent('$lib2Path/haxelib.json', '{"name": "lib", "version":"2.0.0"}');
		File.saveContent('$lib2Path/extraParams.hxml', "--macro include('pack')\n# comment");
		File.saveContent('$lib2Path/Run.hx',
'
function main() {
	switch(Sys.args()) {
		case ["env", name, value, _]: Sys.exit(value == Sys.getEnv(name) ? 0 : 1);
		case ["cwd", cwd, actualCwd]: Sys.exit(cwd == actualCwd ? 0 : 1);
		case ["crash", int, _]: Sys.exit(Std.parseInt(int));
		case _: Sys.exit(0);
	}
}
'
		);

		FileSystem.createDirectory(libGitPath);
		File.saveContent('$libGitPath/haxelib.json', '{"name": "LIB", "version":"3.0.0"}');
		File.saveContent('$libGitPath/Run.hx', 'function main() {Sys.exit(Sys.args()[0] == Sys.getEnv("HAXELIB_RUN_NAME") ? 0 : 1);}');

		FileSystem.createDirectory(devlibPath);
		File.saveContent('$devlibPath/haxelib.json', '{"name": "devlib", "version":"1.0.0", "dependencies":{"lib":"1.0.0"}}');

		FileSystem.createDirectory(capitalizedPath);
	}

	static function cleanUpRepo() {
		HaxelibTests.deleteDirectory(repo);
		HaxelibTests.deleteDirectory(devlibPath);
	}

	function testVersion():Void {
		final lib = ProjectName.ofString("lib");
		assertEquals(Version.ofString("2.0.0"), scope.getVersion(lib));

		final one = SemVer.ofString("1.0.0");

		scope.setVersion(lib, one);
		assertEquals((one:Version), scope.getVersion(lib));

		scope.setVcsVersion(lib, VcsID.Git);
		assertEquals((VcsID.Git : Version), scope.getVersion(lib));
	}

	function testGetPath():Void {
		final lib = ProjectName.ofString("lib");
		assertEquals(lib2Path, scope.getPath(lib));

		final one = SemVer.ofString("1.0.0");
		scope.setVersion(lib, one);
		assertEquals(lib1Path, scope.getPath(lib, one));

		scope.setVcsVersion(lib, VcsID.Git);
		assertEquals(libGitPath, scope.getPath(lib, VcsID.Git));

		final devlib = ProjectName.ofString("devlib");
		// test override
		assertEquals(FileSystem.absolutePath(devlibPath).addTrailingSlash(), scope.getPath(devlib));
	}

	function testIsOverridden() {
		assertFalse(scope.isOverridden(ProjectName.ofString("lib")));
		assertTrue(scope.isOverridden(ProjectName.ofString("devlib")));
		assertFalse(scope.isOverridden(ProjectName.ofString("not-installed")));
	}

	function assertContainsAll<T>(expected:Array<T>, actual:Array<T>, ?eq:(a:T, b:T)->Bool) {
		if (eq == null) eq = (a:T, b:T)-> {a == b;}
		final expectedLengthMsg = "Lengths match";

		assertEquals(expectedLengthMsg, (expected.length == actual.length) ? expectedLengthMsg : 'The array lengths do not match: $expected $actual');

		final includedMsg = "Item was included";

		for (item in expected) {
			final message = {
				if (Lambda.exists(actual, eq.bind(item)))
					includedMsg;
				else
					'Item `$item` was not included in $actual';
			}
			assertEquals(includedMsg, message);
		}
	}

	function testGetLibraryNames() {
		final libs = scope.getLibraryNames();
		final expectedLibs = [
			ProjectName.ofString("lib"),
			ProjectName.ofString("devlib"),
			ProjectName.ofString("Capitalized"),
			ProjectName.ofString("haxelib")
		];

		assertContainsAll(expectedLibs, libs);
	}

	function testGetArrayOfLibraryInfo() {
		final libs = scope.getArrayOfLibraryInfo();
		final expectedInfo:Array<InstallationInfo> = [
			{
				name: ProjectName.ofString("lib"),
				current: SemVer.ofString("2.0.0"),
				devPath: null,
				versions: [SemVer.ofString("1.0.0"), SemVer.ofString("2.0.0"), VcsID.Git]
			},
			{
				name: ProjectName.ofString("devlib"),
				current: null,
				devPath: FileSystem.absolutePath(devlibPath).normalize().addTrailingSlash(),
				versions: []
			},
			{
				name: ProjectName.ofString("Capitalized"),
				current: SemVer.ofString("1.0.0"),
				devPath: null,
				versions: [SemVer.ofString("1.0.0")]
			},
			{
				name: ProjectName.ofString("haxelib"),
				current: null,
				devPath: Sys.getCwd().normalize().addTrailingSlash(),
				versions: []
			}
		];

		assertContainsAll(expectedInfo, libs, (a, b) -> {
			a.name == b.name
			&& a.current == b.current
			&& a.devPath == b.devPath
			&& a.versions.foreach(b.versions.contains);
		});

		// filtered
		final libs = scope.getArrayOfLibraryInfo("Cap");
		final expectedInfo:Array<InstallationInfo> = [
			{
				name: ProjectName.ofString("Capitalized"),
				current: SemVer.ofString("1.0.0"),
				devPath: null,
				versions: [SemVer.ofString("1.0.0")]
			}
		];

		assertContainsAll(expectedInfo, libs, (a, b) -> {
			a.name == b.name
			&& a.current == b.current
			&& a.devPath == b.devPath
			&& a.versions.foreach(b.versions.contains);
		});

		// filtered (different capitalization)
		final libs = scope.getArrayOfLibraryInfo("cap");
		final expectedInfo:Array<InstallationInfo> = [
			{
				name: ProjectName.ofString("Capitalized"),
				current: SemVer.ofString("1.0.0"),
				devPath: null,
				versions: [SemVer.ofString("1.0.0")]
			}
		];

		assertContainsAll(expectedInfo, libs, (a, b) -> {
			a.name == b.name
			&& a.current == b.current
			&& a.devPath == b.devPath
			&& a.versions.foreach(b.versions.contains);
		});
	}

	function testIsInstalled() {
		assertTrue(scope.isLibraryInstalled(ProjectName.ofString("lib")));
		assertTrue(scope.isLibraryInstalled(ProjectName.ofString("Capitalized")));
		// different capitalization
		assertTrue(scope.isLibraryInstalled(ProjectName.ofString("capitalized")));

		assertFalse(scope.isLibraryInstalled(ProjectName.ofString("not-installed")));

		// override versions are ignored
		assertFalse(scope.isLibraryInstalled(ProjectName.ofString("devlib")));
	}

	function testGetArgsAsHxml() {
		assertEquals('--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0', scope.getArgsAsHxml(ProjectName.ofString("lib")));
		// with extraParams.hxml
		assertEquals('$lib1Path\n-D lib=1.0.0', scope.getArgsAsHxml(ProjectName.ofString("lib"), SemVer.ofString("1.0.0")));
		// this one has LIB in the haxelib.json
		assertEquals('$libGitPath\n-D LIB=3.0.0', scope.getArgsAsHxml(ProjectName.ofString("lib"), VcsID.Git));

		// different capitalization
		assertEquals('--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0', scope.getArgsAsHxml(ProjectName.ofString("LIB")));

		// dev lib (depends on lib 1.0.0)
		final devPath = FileSystem.absolutePath(devlibPath).addTrailingSlash();

		assertEquals('$devPath\n-D devlib=1.0.0\n$lib1Path\n-D lib=1.0.0', scope.getArgsAsHxml(ProjectName.ofString("devlib")));
		assertEquals('$devPath\n-D devlib=1.0.0\n$lib1Path\n-D lib=1.0.0', scope.getArgsAsHxml(ProjectName.ofString("DEVLIB")));

		// capitalized
		// this one has no haxelib.json so the version just shows 0.0.0
		assertEquals('$capitalizedPath\n-D Capitalized=0.0.0', scope.getArgsAsHxml(ProjectName.ofString("Capitalized")));
		assertEquals('$capitalizedPath\n-D Capitalized=0.0.0', scope.getArgsAsHxml(ProjectName.ofString("capitalized")));
	}

	function testGetArgsAsHxmlForLibraries() {
		// same lib repeated
		assertEquals(
			'--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0',
			scope.getArgsAsHxmlForLibraries([
				{
					library: ProjectName.ofString("lib"),
					version: null
				},
				{
					library: ProjectName.ofString("lib"),
					version: SemVer.ofString("2.0.0")
				}
			])
		);

		// two libs
		assertEquals(
			'--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0\n$capitalizedPath\n-D Capitalized=0.0.0',
			scope.getArgsAsHxmlForLibraries([
				{
					library: ProjectName.ofString("lib"),
					version: null
				},
				{
					library: ProjectName.ofString("capitalized"),
					version: null
				}
			])
		);
		// different order
		assertEquals(
			'$capitalizedPath\n-D Capitalized=0.0.0\n--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0',
			scope.getArgsAsHxmlForLibraries([
				{
					library: ProjectName.ofString("capitalized"),
					version: null
				},
				{
					library: ProjectName.ofString("lib"),
					version: null
				}
			])
		);

		// two libs, one depends on the other
		final devPath = FileSystem.absolutePath(devlibPath).addTrailingSlash();

		assertEquals(
			'--macro include(\'pack\')\n$lib2Path\n-D lib=2.0.0\n$devPath\n-D devlib=1.0.0',
			scope.getArgsAsHxmlForLibraries([
				{
					library: ProjectName.ofString("lib"),
					version: SemVer.ofString("2.0.0")
				},
				{
					library: ProjectName.ofString("devlib"),
					version: null
				}
			])
		);
	}

	function testRunScript() {
		final lib = ProjectName.ofString("lib");

		final oldRunName = Sys.getEnv("HAXELIB_RUN_NAME");
		final oldRun = Sys.getEnv("HAXELIB_RUN");
		final oldCwd = Sys.getCwd();
		try {
			scope.runScript(lib);
			assertTrue(true);
		} catch (e) {
			assertTrue(false);
		}

		// environment was cleaned up after running
		assertEquals(oldRunName, Sys.getEnv("HAXELIB_RUN_NAME"));
		assertEquals(oldRun, Sys.getEnv("HAXELIB_RUN"));
		assertEquals(oldCwd, Sys.getCwd());

		try {
			final dir = FileSystem.absolutePath(repo);
			scope.runScript(lib, {
				dir: dir,
				args: ["cwd", dir]
			});
			assertTrue(true);
		} catch (e) {
			assertTrue(false);
		}

		try {
			scope.runScript(lib, {
				args: ["crash", "10"]
			});
			assertTrue(false);
		} catch (e:ScriptError) {
			assertEquals(10, e.code);
		}

		try {
			scope.runScript(lib, {
				args: ["env", "HAXELIB_RUN", "1"]
			});
			assertTrue(true);
		} catch (e:ScriptError) {
			assertTrue(false);
		}

		try {
			scope.runScript(lib, {
				args: ["env", "HAXELIB_RUN_NAME", "lib"]
			});
			assertTrue(true);
		} catch (e:ScriptError) {
			assertTrue(false);
		}

		RepoManager.createLocal();
		// the script will now fail as the library doesn't exist in the new local repo

		// TODO: Get rid of the process output here
		Sys.print("\n");
		try {
			scope.runScript(lib);
			assertTrue(false);
		} catch (e) {
			assertTrue(true);
		}

		// but with `useGlobalRepo` it works!
		try {
			scope.runScript(lib, {
				useGlobalRepo: true
			});
			assertTrue(true);
		} catch (e) {
			assertTrue(false);
		}

		RepoManager.deleteLocal();

		// this version has "LIB" set as the name
		scope.setVcsVersion(lib, VcsID.Git);
		try {
			scope.runScript(lib, {
				args: ["LIB"]
			});
			// exits with error only if "LIB" does not match HAXELIB_RUN_NAME
			assertTrue(true);
		} catch (e:ScriptError) {
			assertTrue(false);
		}
	}
}
