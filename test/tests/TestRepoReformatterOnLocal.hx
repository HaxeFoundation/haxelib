package tests;

import sys.io.File;
import sys.FileSystem;

import haxelib.api.RepoManager;
import haxelib.api.Repository;

class TestRepoReformatterOnLocal extends TestRepoReformatter {

	override function get_repoPath():String {
		return '${TestRepoReformatter.dir}/.haxelib';
	}

	override function getRepo():Repository {
		RepoManager.createLocal(TestRepoReformatter.dir);
		return Repository.get(TestRepoReformatter.dir);
	}

	override function cleanUpRepo() { /* nothing needed here*/ }
}
