package tests.integration;

import haxe.io.Path;
import IntegrationTests.*;
using IntegrationTests;

import sys.db.*;
import sys.db.Types;
import haxelib.server.Paths.*;


@:id(pid,date)
class Downloads extends Object {
	public var pid : Int;
	public var date : SDate;
	public var num : Int;
}

class TestDownloads extends IntegrationTests {
	function test():Void {
		{
			var db : Connection =
			if (Sys.getEnv("HAXELIB_DB_HOST") != null)
				Mysql.connect({
					"host":     Sys.getEnv("HAXELIB_DB_HOST"),
					"port":     Std.parseInt(Sys.getEnv("HAXELIB_DB_PORT")),
					"database": Sys.getEnv("HAXELIB_DB_NAME"),
					"user":     Sys.getEnv("HAXELIB_DB_USER"),
					"pass":     Sys.getEnv("HAXELIB_DB_PASS"),
					"socket":   null
				});
			else if (sys.FileSystem.exists(DB_CONFIG))
				Mysql.connect(haxe.Json.parse(sys.io.File.getContent(DB_CONFIG)));
			else
				Sqlite.open(DB_FILE);

		Manager.cnx = db;
		Manager.initialize();
		
			if (!TableCreate.exists(Downloads.manager))
				TableCreate.create(Downloads.manager);
		}
		
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
			var pid = 0;
			for( row in projectRequest ) 
			{
				pid = row.id;
			}
			dbCnx.request('INSERT INTO Downloads ( `pid`, `date`, `num`) VALUES (${pid}, CURDATE(), 1 ) ON DUPLICATE KEY UPDATE num = num +1;');
		}

		{
			var db = dbConfig.database;
			dbCnx.request('USE ${db};');
			var projectRequest = dbCnx.request("SELECT id FROM Project WHERE name = 'Bar';");
			var pid = 0;
			for( row in projectRequest ) 
			{
				pid = row.id;
			}
			var rqOne = dbCnx.request('SELECT num FROM Downloads WHERE pid = ${pid} AND `date` = CURDATE();');
			assertTrue(rqOne.length==1);
			for( row in rqOne ) 
			{
				assertTrue(row.num == 1);
			}
		}
		
		{
			var r = haxelib(["remove", "Bar"]).result();
			assertSuccess(r);
		}
	}
}