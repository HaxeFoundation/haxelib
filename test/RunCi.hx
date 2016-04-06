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

	static function download(url:String, saveAs:String):Void {
		infoMsg('download $url as $saveAs');
		runCommand("curl", ["-fSLk", url, "-o", saveAs, "-A", "Mozilla/4.0"]);
	}

	static function compileServer():Void {
		runCommand("haxe", ["server.hxml"]);
	}

	static function compileLegacyServer():Void {
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
	}

	static function testServer():Void {
		runCommand("haxe", ["server_tests.hxml"]);
	}

	static function setupLocalServer():Void {
		var ndllPath = getEnv("NEKOPATH");
		if (ndllPath == null) ndllPath = "/usr/lib/neko";
		var DocumentRoot = Path.join([getCwd(), "www"]);
		var dbConfigPath = Path.join(["www", "dbconfig.json"]);
		var dbConfig = Json.parse(getContent(dbConfigPath));
		// update dbConfig.host to be "localhost"
		saveContent(dbConfigPath, Json.stringify({
			user: dbConfig.user,
			pass: dbConfig.pass,
			host: "localhost",
			database: dbConfig.database,
		}));
		function writeApacheConf(confPath:String):Void {
			var hasModNeko = switch (systemName()) {
				case "Windows":
					false;
				case _:
					var p = new sys.io.Process("apachectl", ["-M"]);
					var out = p.stdout.readAll().toString();
					var has = out.indexOf("neko_module") >= 0;
					p.close();
					has;
			}

			var confContent =
(
	if (systemName() == "Windows")
		"LoadModule rewrite_module modules/mod_rewrite.so\n"
	else
		""
) +
(
	if (hasModNeko)
		""
	else
		'LoadModule neko_module ${Path.join([ndllPath, "mod_neko2.ndll"])}\n'
) +
'LoadModule tora_module ${Path.join([ndllPath, "mod_tora2.ndll"])}
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
			var isAppVeyor = getEnv("APPVEYOR") != null;
			var user = if (isAppVeyor)
				// https://www.appveyor.com/docs/services-databases#mysql
				{ user: "root", pass: "Password12!" };
			else
				{ user: "root", pass: "" };

			var cnx = sys.db.Mysql.connect({
				user: user.user,
				pass: user.pass,
				host: "localhost",
				port: 3306,
				database: "",
			});
			cnx.request('create user \'${dbConfig.user}\'@\'localhost\' identified by \'${dbConfig.pass}\';');
			cnx.request('create database ${dbConfig.database};');
			cnx.request('grant all on ${dbConfig.database}.* to \'${dbConfig.user}\'@\'localhost\';');
			cnx.close();
		}

		switch (systemName()) {
			case "Windows":
				configDb();

				download("https://www.apachelounge.com/download/win32/binaries/httpd-2.2.31-win32.zip", "bin/httpd.zip");
				runCommand("7z", ["x", "bin\\httpd.zip", "-obin\\httpd"]);
				writeApacheConf("bin\\httpd\\Apache2\\conf\\httpd.conf");
				rename("bin\\httpd\\Apache2", "c:\\Apache2");
				var serviceName = "HaxelibApache";
				var httpd = "c:\\Apache2\\bin\\httpd.exe";
				runCommand(httpd, ["-k", "install", "-n", serviceName]);
				runCommand(httpd, ["-n", serviceName, "-t"]);
				runCommand(httpd, ["-k", "start", "-n", serviceName]);

				var toraPath = {
					var p = new sys.io.Process("haxelib", ["path", "tora"]);
					var path = p.stdout.readLine();
					p.close();
					path;
				}
				runCommand("nssm", ["install", "tora", Path.join([getEnv("NEKOPATH"), "neko.exe"]), Path.join([toraPath, "run.n"])]);
				runCommand("nssm", ["start", "tora"]);

				Sys.sleep(2.5);
			case "Mac":
				runCommand("brew", ["install", "homebrew/apache/httpd22", "mysql"]);

				runCommand("mysql.server", ["start"]);
				configDb();

				runCommand("apachectl", ["start"]);
				Sys.sleep(2.5);
				writeApacheConf("/usr/local/etc/apache2/2.2/httpd.conf");
				Sys.sleep(2.5);
				runCommand("apachectl", ["restart"]);
				Sys.sleep(2.5);
			case "Linux":
				configDb();

				runCommand("sudo", ["apt-get", "install", "apache2"]);

				writeApacheConf("haxelib.conf");
				runCommand("sudo", ["ln", "-s", Path.join([Sys.getCwd(), "haxelib.conf"]), "/etc/apache2/conf.d/haxelib.conf"]);
				runCommand("sudo", ["a2enmod", "rewrite"]);
				runCommand("sudo", ["service", "apache2", "restart"]);
				Sys.sleep(2.5);
			case name:
				throw "System not supported: " + name;
		}

		Sys.setCwd("www");
		runCommand("bower", ["install"]);
		Sys.setCwd("..");

		Sys.putEnv("HAXELIB_SERVER", "localhost");
		Sys.putEnv("HAXELIB_SERVER_PORT", "2000");
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
			test();
		} else {
			runWithDockerServer(test);
		}
	}

	static function installDotNet11():Void {
		// This is a msvcr71.dll in my own dropbox. If you want to obtain one, you probably shouldn't use my file. 
		// Instead, install .Net Framework 1.1 from the link as follows
		// https://www.microsoft.com/en-us/download/details.aspx?id=26
		download("https://dl.dropboxusercontent.com/u/2661116/msvcr71.dll", Path.join([getEnv("NEKOPATH"), "msvcr71.dll"]));
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

			if (systemName() == "Windows") {
				// The Neko 2.0 Windows binary archive is missing "msvcr71.dll", which is a dependency of "sqlite.ndll".
				// https://github.com/HaxeFoundation/haxe/issues/2008#issuecomment-176849497
				installDotNet11();
			}
			testServer();
		#end

		// integration test
		switch (systemName()) {
			case "Windows", "Linux":
				integrationTests();
			case "Mac":
				#if (haxe_ver >= 3.2)
					integrationTests();
				#end
			case _:
				throw "Unknown system";
		}
	}
}