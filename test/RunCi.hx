import Sys.*;
import haxe.*;
import haxe.io.*;
import sys.FileSystem.*;
import sys.io.File.*;

class RunCi {
	static function successMsg(msg:String):Void {
		Sys.println('\x1b[32m' + msg + '\x1b[0m');
	}
	static function failMsg(msg:String):Void {
		Sys.println('\x1b[31m' + msg + '\x1b[0m');
	}
	static function infoMsg(msg:String):Void {
		Sys.println('\x1b[36m' + msg + '\x1b[0m');
	}

	/**
		Run a command using `Sys.command()`.
		If the command exits with non-zero code, exit the whole script with the same code.

		If `useRetry` is `true`, the command will be re-run if it exits with non-zero code (3 trials).
		It is useful for running network-dependent commands.
	*/
	static function runCommand(cmd:String, ?args:Array<String>, useRetry:Bool = false):Void {
		var trials = useRetry ? 3 : 1;
		var exitCode:Int = 1;
		var cmdStr = cmd + (args != null ? ' $args' : '');

		while (trials-->0) {
			Sys.println("Command: " + cmdStr);

			var t = Timer.stamp();
			exitCode = Sys.command(cmd, args);
			var dt = Math.round(Timer.stamp() - t);

			if (exitCode == 0)
				successMsg('Command exited with $exitCode in ${dt}s: $cmdStr');
			else
				failMsg('Command exited with $exitCode in ${dt}s: $cmdStr');

			if (exitCode == 0) {
				return;
			} else if (trials > 0) {
				Sys.println('Command will be re-run...');
			}
		}

		Sys.exit(exitCode);
	}

	static function compileServer():Void {
		runCommand("haxelib", ["install", "server.hxml", "--always"]);
		runCommand("haxelib", ["install", "server_each.hxml", "--always"]);
		runCommand("haxelib", ["install", "server_tests.hxml", "--always"]);
		runCommand("haxelib", ["list"]);
		runCommand("haxe", ["server.hxml"]);
	}

	static function compileLegacyServer():Void {
		runCommand("haxelib", ["install", "hx2compat"]);
		runCommand("haxe", ["server_legacy.hxml"]);
	}

	static function compileClient():Void {
		runCommand("haxe", ["client.hxml"]);
	}

	static function compileLegacyClient():Void {
		runCommand("haxe", ["client_legacy.hxml"]);
	}

	static function testClient():Void {
		runCommand("haxe", ["client_tests.hxml"]);
		runCommand("neko", ["bin/test.n"]);
	}

	static function testServer():Void {
		runCommand("haxe", ["server_tests.hxml"]);
	}

	static var dbConfigExamplePath = Path.join(["src", "haxelib", "server", "dbconfig.json.example"]);

	static function setupLocalServer():Void {
		var ndllPath = getEnv("NEKOPATH");
		if (ndllPath == null) ndllPath = "/usr/lib/neko";
		var DocumentRoot = Path.join([getCwd(), "www"]);
		var dbConfig = Json.parse(getContent(dbConfigExamplePath));
		function copyConfigs():Void {
			saveContent(Path.join(["www", "dbconfig.json"]), Json.stringify({
				user: dbConfig.user,
				pass: dbConfig.pass,
				host: "localhost",
				database: dbConfig.database,
			}));
			copy(Path.join(["src", "haxelib", "server", ".htaccess"]), Path.join(["www", ".htaccess"]));
		}
		function writeApacheConf(confPath:String):Void {
			var hasModNeko = {
				var p = new sys.io.Process("apachectl", ["-M"]);
				var out = p.stdout.readAll().toString();
				var has = out.indexOf("neko_module") >= 0;
				p.close();
				has;
			}

			var confContent =
(
	if (hasModNeko)
		""
	else
		'LoadModule neko_module ${Path.join([ndllPath, "mod_neko2.ndll"])}'
) +
'
LoadModule tora_module ${Path.join([ndllPath, "mod_tora2.ndll"])}
AddHandler tora-handler .n
Listen 2000
<VirtualHost *:2000>
	DocumentRoot "$DocumentRoot"
</VirtualHost>
<Directory "$DocumentRoot">
    Options Indexes FollowSymLinks
    AllowOverride All
    Order allow,deny
    Allow from all
</Directory>
';
			var confOut = if (exists(confPath))
				append(confPath);
			else
				write(confPath);
			confOut.writeString(confContent);
			confOut.flush();
			confOut.close();
		}
		function configDb():Void {
			runCommand("mysql", ["-u", "root", "-e", 'create user \'${dbConfig.user}\'@\'localhost\' identified by \'${dbConfig.pass}\';']);
			runCommand("mysql", ["-u", "root", "-e", 'create database ${dbConfig.database};']);
			runCommand("mysql", ["-u", "root", "-e", 'grant all on ${dbConfig.database}.* to \'${dbConfig.user}\'@\'localhost\';']);
		}
		switch (systemName()) {
			case "Mac":
				runCommand("brew", ["install", "homebrew/apache/httpd22", "mysql"]);

				runCommand("mysql.server", ["start"]);
				configDb();

				runCommand("apachectl", ["start"]);
				Sys.sleep(2.5);
				copyConfigs();
				writeApacheConf("/usr/local/etc/apache2/2.2/httpd.conf");
				Sys.sleep(2.5);
				runCommand("apachectl", ["restart"]);
				Sys.sleep(2.5);
			case "Linux":
				configDb();

				runCommand("sudo", ["apt-get", "install", "apache2"]);

				copyConfigs();
				writeApacheConf("haxelib.conf");
				runCommand("sudo", ["ln", "-s", Path.join([Sys.getCwd(), "haxelib.conf"]), "/etc/apache2/conf.d/haxelib.conf"]);
				runCommand("sudo", ["a2enmod", "rewrite"]);
				runCommand("sudo", ["service", "apache2", "restart"]);
				Sys.sleep(2.5);
			case name:
				throw "System not supported: " + name;
		}
		Sys.putEnv("HAXELIB_SERVER", "localhost");
		Sys.putEnv("HAXELIB_SERVER_PORT", "2000");

		runCommand("haxelib", ["install", "tora"]);
	}

	static function runWithDockerServer(test:Void->Void):Void {
		var server = switch (systemName()) {
			case "Linux":
				"localhost";
			case _:
				var p = new sys.io.Process("docker-machine", ["ip"]);
				var ip = p.stdout.readLine();
				p.close();
				ip;
		}
		var serverPort = 2000;

		var dbConfig = Json.parse(getContent(dbConfigExamplePath));
		copy(dbConfigExamplePath, Path.join(["www", "dbconfig.json"]));
		copy(Path.join(["src", "haxelib", "server", ".htaccess"]), Path.join(["www", ".htaccess"]));

		runCommand("docker-compose", ["-f", "test/docker-compose.yml", "up", "-d"]);

		Sys.putEnv("HAXELIB_SERVER", server);
		Sys.putEnv("HAXELIB_SERVER_PORT", Std.string(serverPort));
		infoMsg("waiting for server to start...");

		var url = 'http://${server}:${serverPort}/';

		var t = Timer.stamp();
		while (true) {
			var isUp = try {
				var response = haxe.Http.requestUrl(url);
				!StringTools.startsWith(response, "Error");
			} catch (e:Dynamic) {
				false;
			}

			if (isUp) {
				break;
			}

			if (Timer.stamp() - t > 120) {
				throw "server is not reachable...";
			}

			Sys.sleep(10.0);
			// Sys.command("curl", ["-s", "-o", "/dev/null", "-w", "%{http_code}", url]);
		}
		infoMsg("server started");

		test();

		runCommand("docker-compose", ["-f", "test/docker-compose.yml", "down"]);
	}

	static function runWithLocalServer(test:Void->Void):Void {
		var tora = new sys.io.Process("haxelib", ["run", "tora"]);
		test();
		tora.close();
	}

	static function integrationTests():Void {
		function test():Void {
			switch (Sys.getEnv("TRAVIS_HAXE_VERSION")) {
				case null, "development":
					runCommand("haxe", ["integration_tests.hxml"]);
				case "3.1.3":
					runCommand("haxe", ["integration_tests.hxml", "-D", "system_haxelib"]);
				case _:
					runCommand("haxe", ["integration_tests.hxml"]);
					runCommand("haxe", ["integration_tests.hxml", "-D", "system_haxelib"]);
			}
		}
		if (Sys.getEnv("CI") != null && Sys.getEnv("USE_DOCKER") == null) {
			setupLocalServer();
			runWithLocalServer(test);
		} else {
			runWithDockerServer(test);
		}
	}

	static function main():Void {
		// Note that package.zip output is also used by client tests, so it has to be run before that.
		runCommand("haxe", ["package.hxml"]);
		runCommand("haxe", ["prepare_tests.hxml"]);

		compileLegacyClient();
		compileLegacyServer();

		// the server can only be compiled with haxe 3.2+
		// haxe 3.1.3 bundles haxelib client 3.1.0-rc.4, which is not upgradable to later haxelib
		// so there is no need to test the client either
		#if (haxe_ver >= 3.2)
			compileClient();
			testClient();
			compileServer();

			switch (systemName()) {
				case "Windows":
					// skip for now
					// The Neko 2.0 Windows binary archive is missing "msvcr71.dll", which is a dependency of "sqlite.ndll".
					// https://github.com/HaxeFoundation/haxe/issues/2008#issuecomment-176849497
				case _:
					testServer();
			}
		#end

		// integration test
		switch (systemName()) {
			case "Linux":
				integrationTests();
			case "Mac":
				#if (haxe_ver >= 3.2)
					integrationTests();
				#end
			case _:
				//pass
		}
	}
}