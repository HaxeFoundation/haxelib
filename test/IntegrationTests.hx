
import haxe.Json;
import sys.FileSystem;
import sys.io.Process;
import sys.io.File;

import haxe.unit.TestRunner;

import haxelib.SemVer;

using StringTools;
using haxe.io.Path;
using IntegrationTests;

typedef UserRegistration = {
	final user:String;
	final email:String;
	final fullname:String;
	final pw:String;
}

class IntegrationTests extends TestBase {
	static final projectRoot:String = Sys.getCwd();
	final haxelibBin:String = Path.join([projectRoot, "run.n"]);
	public final server = switch (Sys.getEnv("HAXELIB_SERVER")) {
		case null:
			"localhost";
		case url:
			url;
	};
	public final serverPort = switch (Sys.getEnv("HAXELIB_SERVER_PORT")) {
		case null:
			2000;
		case port:
			Std.parseInt(port);
	};
	public var serverUrl(get, null):String;
	function get_serverUrl() return serverUrl != null ? serverUrl : serverUrl = 'http://${server}:${serverPort}/';

	static final originalRepo = {
		final p = new Process("haxelib", ["config"]);
		final originalRepo = p.stdout.readLine().normalize();
		p.close();
		if (repo == originalRepo) {
			throw "haxelib repo is the same as test repo: " + repo;
		}
		originalRepo;
	};
	static public final repo = "repo_integration_tests";
	static public final bar = {
		user: "Bar",
		email: "bar@haxe.org",
		fullname: "Bar",
		pw: "barpassword",
	};
	static public final foo = {
		user: "Foo",
		email: "foo@haxe.org",
		fullname: "Foo",
		pw: "foopassword",
	};
	static public final deepAuthor = {
		user: "DeepAuthor",
		email: "deep@haxe.org",
		fullname: "Jonny Deep",
		pw: "deep thought"
	}
	static public final anotherGuy = {
		user: "AnotherGuy",
		email: "another@email.com",
		fullname: "Another Guy",
		pw: "some other pw"
	}
	public var clientVer(get, null):SemVer;
	var clientVer_inited = false;
	function get_clientVer() {
		return if (clientVer_inited)
			clientVer;
		else {
			clientVer = {
				final r = haxelib(["version"]).result();
				if (r.code == 0)
					SemVer.ofString(switch(r.out.trim()) {
						case _.split(" ") => parts: parts[0];
						case v: v;
					});
				else if (r.out.indexOf("3.1.0-rc.4") >= 0)
					SemVer.ofString("3.1.0-rc.4");
				else
					throw "unknown version";
			};
			clientVer_inited = true;
			clientVer;
		}
	}

	function haxelib(args:Array<String>, ?input:String):Process {
		final p = #if system_haxelib
			new Process("haxelib", ["-R", serverUrl].concat(args));
		#else
			new Process("neko", [haxelibBin, "-R", serverUrl].concat(args));
		#end

		if (input != null) {
			p.stdin.writeString(input);
			p.stdin.close();
		}

		return p;
	}

	function assertSuccess(r:{out:String, err:String, code:Int}, ?pos:haxe.PosInfos):Void {
		if (r.code != 0) {
			throw r;
		}
		assertEquals(0, r.code, pos);
	}

	function assertFail(r:{out:String, err:String, code:Int}, ?pos:haxe.PosInfos):Void {
		assertTrue(r.code != 0, pos);
	}

	function assertNoError(f:Void->Void):Void {
		f();
		assertTrue(true);
	}

	/** Asserts that multi-line terminal output matches expected.

		Handles newline difference between platforms.
	  **/
	function assertOutputEquals(expectedLines:Array<String>, output:String) {
		final outputLines = output.rtrim().split("\n").map((line) -> {line.rtrim();});

		final lineNumberMsg = "Output has the expected number of lines";
		final notMatchedMsg = '`${output.rtrim()}` does not match expected: `${expectedLines.join("\n")}`';


		assertEquals(lineNumberMsg,
			if (expectedLines.length == outputLines.length)
				lineNumberMsg
			else
				notMatchedMsg
		);

		final allMatchedMsg = "Output matches";

		assertEquals(allMatchedMsg,
			try {
				for (i => line in expectedLines) {
					if (line != outputLines[i])
						throw "NOT MATCHED";
				}
				allMatchedMsg;
			} catch (_) {
				notMatchedMsg;
			}
		);
	}

	final dbConfig:Dynamic = Json.parse(File.getContent("www/dbconfig.json"));
	var dbCnx:sys.db.Connection;
	function resetDB():Void {
		final db = dbConfig.database;
		dbCnx.request('DROP DATABASE IF EXISTS ${db};');
		dbCnx.request('CREATE DATABASE ${db};');

		final filesPath = "www/files/3.0";
		for (item in FileSystem.readDirectory(filesPath)) {
			if (item.endsWith(".zip")) {
				FileSystem.deleteFile(Path.join([filesPath, item]));
			}
		}
		final tmpPath = "tmp";
		for (item in FileSystem.readDirectory(filesPath)) {
			if (item.endsWith(".tmp")) {
				FileSystem.deleteFile(Path.join([tmpPath, item]));
			}
		}
	}

	override function setup():Void {
		super.setup();

		dbCnx = sys.db.Mysql.connect({
			user: dbConfig.user,
			pass: dbConfig.pass,
			host: dbConfig.host,
			port: dbConfig.port,
			database: dbConfig.database,
		});
		resetDB();

		deleteDirectory(repo);
		FileSystem.createDirectory(repo);
		haxelibSetup(repo);

		Sys.setCwd(Path.join([projectRoot, "test"]));
	}

	override function tearDown():Void {
		Sys.setCwd(projectRoot);

		haxelibSetup(originalRepo);
		deleteDirectory(repo);

		resetDB();
		dbCnx.close();

		super.tearDown();
	}

	static public function result(p:Process):{out:String, err:String, code:Int} {
		final out = p.stdout.readAll().toString();
		final err = p.stderr.readAll().toString();
		final code = p.exitCode();
		p.close();
		return {out:out, err:err, code:code};
	}

	static public function haxelibSetup(path:String):Void {
		final p = new Process("haxelib", ["setup", path]);
		final exitCode = p.exitCode();

		if (exitCode != 0)
			Sys.exit(exitCode);
	}

	static function main():Void {
		final prevDir = Sys.getCwd();

		final runner = new TestRunner();
		runner.add(new tests.integration.TestEmpty());
		runner.add(new tests.integration.TestSetup());
		runner.add(new tests.integration.TestSubmit());
		runner.add(new tests.integration.TestInstall());
		runner.add(new tests.integration.TestRemove());
		runner.add(new tests.integration.TestUpgrade());
		runner.add(new tests.integration.TestUpdate());
		runner.add(new tests.integration.TestList());
		runner.add(new tests.integration.TestSet());
		runner.add(new tests.integration.TestInfo());
		runner.add(new tests.integration.TestUser());
		runner.add(new tests.integration.TestOwner());
		runner.add(new tests.integration.TestDev());
		runner.add(new tests.integration.TestRun());
		runner.add(new tests.integration.TestPath());
		runner.add(new tests.integration.TestLibpath());
		runner.add(new tests.integration.TestGit());
		runner.add(new tests.integration.TestHg());
		runner.add(new tests.integration.TestMisc());
		final success = runner.run();

		if (!success) {
			Sys.exit(1);
		}
	}
}
