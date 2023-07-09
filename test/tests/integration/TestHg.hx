package tests.integration;

import haxelib.api.FsUtils;
import haxelib.api.Vcs;
import tests.util.Vcs;

class TestHg extends TestVcs {
	public function new () {
		super("hg");
	}

	override function setup() {
		super.setup();

		makeHgRepo(vcsLibPath, ["haxelib.xml"]);
		createHgTag(vcsLibPath, vcsTag);

		makeHgRepo(vcsLibNoHaxelibJson);
		makeHgRepo(vcsBrokenDependency);
	}

	override function tearDown() {
		resetHgRepo(vcsLibPath);
		resetHgRepo(vcsLibNoHaxelibJson);
		resetHgRepo(vcsBrokenDependency);

		super.tearDown();
	}

	public function updateVcsRepo() {
		addToHgRepo(vcsLibPath, "haxelib.xml");
	}

	public function getVcsCommit():String {
		return FsUtils.runInDirectory(vcsLibPath, Vcs.create(Hg).getRef);
	}
}
