package tests;

import haxelib.SemVer;
import haxelib.VersionData;
import haxelib.VersionData.VersionDataHelper.extractVersion;

class TestVersionData extends TestBase {
	function testHaxelib() {
		assertTrue(extractVersion("1.0.0").equals(Haxelib(SemVer.ofString("1.0.0"))));
		assertTrue(extractVersion("1.0.0-beta").equals(Haxelib(SemVer.ofString("1.0.0-beta"))));
	}

	function assertVersionDataEquals(expected:VersionData, actual:VersionData) {
		assertEquals(Std.string(expected), Std.string(actual));
	}

	function testGit() {
		assertVersionDataEquals(extractVersion("git:https://some.url"), VcsInstall(VcsID.ofString("git"), {
			url: "https://some.url",
			branch: null,
			ref: null,
			tag: null,
			subDir: null
		}));

		assertVersionDataEquals(extractVersion("git:https://some.url#branch"), VcsInstall(VcsID.ofString("git"), {
			url: "https://some.url",
			branch: "branch",
			ref: null,
			tag: null,
			subDir: null
		}));

		assertVersionDataEquals(extractVersion("git:https://some.url#abcdef0"), VcsInstall(VcsID.ofString("git"), {
			url: "https://some.url",
			branch: null,
			ref: "abcdef0",
			tag: null,
			subDir: null
		}));
	}

	function testMercurial() {
		assertVersionDataEquals(extractVersion("hg:https://some.url"), VcsInstall(VcsID.ofString("hg"), {
			url: "https://some.url",
			branch: null,
			ref: null,
			tag: null,
			subDir: null
		}));

		assertVersionDataEquals(extractVersion("hg:https://some.url#branch"), VcsInstall(VcsID.ofString("hg"), {
			url: "https://some.url",
			branch: "branch",
			ref: null,
			tag: null,
			subDir: null
		}));

		assertVersionDataEquals(extractVersion("hg:https://some.url#abcdef0"), VcsInstall(VcsID.ofString("hg"), {
			url: "https://some.url",
			branch: null,
			ref: "abcdef0",
			tag: null,
			subDir: null
		}));
	}
}
