package tests.integration;

import haxe.io.Path;
using IntegrationTests;
using StringTools;
using Lambda;

class TestPath extends IntegrationTests {
#if !system_haxelib
	function testMain():Void {
		var r = haxelib(["dev", "BadHaxelibJson", Path.join([IntegrationTests.projectRoot, "test/libraries/libBadHaxelibJson"])]).result();
		assertSuccess(r);
		var r = haxelib(["path", "BadHaxelibJson"]).result();
		assertFail(r);
	}

	// function testGitDep():Void {
	// 	var r = haxelib(["dev", "UseGitDep", Path.join([IntegrationTests.projectRoot, "test/libraries/UseGitDep"])]).result();
	// 	assertSuccess(r);
	// 	var r = haxelib(["path", "UseGitDep"]).result();
	// 	assertSuccess(r);
	// 	var paths = r.out.split('\n')
	// 		.filter(function(line) return !line.startsWith('-'))
	// 		.map(function(p) return new Path(p.trim()));
	// 	assertTrue(paths.exists(function(p) return p.dir.contains('signal') && p.dir.endsWith('git')));
	// }
#end
}