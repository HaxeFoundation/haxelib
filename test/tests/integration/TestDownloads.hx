package tests.integration;

import haxe.io.Path;
import IntegrationTests.*;
using IntegrationTests;

class TestDownloads extends IntegrationTests {
	function test():Void {
		{
			var r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["search", "Bar"]).result();
			assertSuccess(r);
			assertTrue(r.out.indexOf("Bar") >= 0);
		}

		{
			var r = haxelib(["install", "Bar"]).result();
			assertSuccess(r);
		}

		{
			var r = haxelib(["list", "Bar"]).result();
			assertTrue(r.out.indexOf("Bar") >= 0);
			assertSuccess(r);
		}

		{
			var db = dbConfig.database;
			dbCnx.request('USE ${db};');
			var projectRequest = dbCnx.request("SELECT id FROM Project WHERE name = 'Bar';");
			var pid = projectRequest.getIntResult(0);
			var rqOne = dbCnx.request('SELECT num FROM Downloads WHERE pid = ${pid} AND `date` = CURDATE();');
			var num = rqOne.getIntResult(0);
			assertTrue(num == 1);
			var rmv = haxelib(["remove", "Bar"]).result();
			var inst = haxelib(["install", "Bar"]).result();
			var rqTwo = dbCnx.request('SELECT num FROM Downloads WHERE pid = ${pid} AND `date` = CURDATE();');
			num = rqTwo.getIntResult(0);
			assertTrue(num == 2);
		}
		
		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}
	}
}