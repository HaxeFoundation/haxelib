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

		// only use it for Neko 2.2
		// var nekotoolsBootC = switch [Sys.getEnv("TRAVIS_HAXE_VERSION"), Sys.systemName()] {
		// 	case [null | "development", "Linux"]:
		// 		true;
		// 	case _:
		// 		false;
		// }
		// if (nekotoolsBootC) {
		// 	runCommand("cmake", ["."]);
		// 	runCommand("cmake", ["--build", "."]);
		// }
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

	static function runWithLocalServer(test:Void->Void):Void {
		var HAXELIB_SERVER = "localhost";
		var HAXELIB_SERVER_PORT = "2000";
		var ndllPath = switch (getEnv("NEKOPATH")) {
			case null:
				if (exists("/usr/lib/x86_64-linux-gnu/neko"))
					"/usr/lib/x86_64-linux-gnu/neko";
				else if (exists("/usr/local/lib/neko"))
					"/usr/local/lib/neko";
				else if (exists("/usr/lib/neko"))
					"/usr/lib/neko";
				else
					throw "no idea where the ndll files are";
			case nekopath:
				nekopath;
		}
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
	switch (systemName()) {
		case "Windows":
			"LoadModule rewrite_module modules/mod_rewrite.so\n" +
			"LoadModule filter_module modules/mod_filter.so\n" +
			"LoadModule deflate_module modules/mod_deflate.so\n";
		case "Mac":
			"LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so\n" +
			"LoadModule deflate_module lib/httpd/modules/mod_deflate.so\n";
		case _:
			"";
	}
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
' + (switch (systemName()) {
	case "Windows": '';
	case _: '
    Order allow,deny
    Allow from all';
}) + '
    Require all granted
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

			for (i in 0...5) try {
				var cnx = sys.db.Mysql.connect({
					user: user.user,
					pass: user.pass,
					host: "localhost",
					port: 3306,
					#if (haxe_ver < 4.0) database: "mysql", #end
				});
				cnx.request('create user if not exists \'${dbConfig.user}\'@\'localhost\' identified by \'${dbConfig.pass}\';');
				cnx.request('create database if not exists ${dbConfig.database};');
				cnx.request('grant all on ${dbConfig.database}.* to \'${dbConfig.user}\'@\'localhost\';');
				cnx.close();
				return;
			} catch (e:Dynamic) {
				trace(e);
				Sys.sleep(5.0);
			}
			throw "cannot config database";
		}

		switch (systemName()) {
			case "Windows":
				configDb();

				download("https://home.apache.org/~steffenal/VC15/binaries/httpd-2.4.41-win32-VC15.zip", "bin/httpd.zip");
				runCommand("7z", ["x", "bin\\httpd.zip", "-obin\\httpd"]);
				writeApacheConf("bin\\httpd\\Apache24\\conf\\httpd.conf");

				var apachePath = "c:\\Apache24";
				rename("bin\\httpd\\Apache24", apachePath);
				var serviceName = "HaxelibApache";
				var httpd = Path.join([apachePath, "bin", "httpd.exe"]);
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

				try {
					haxe.Http.requestUrl('http://${HAXELIB_SERVER}:${HAXELIB_SERVER_PORT}/');
				} catch (e:Dynamic) {
					println("Cannot open webpage.");
					println("====================");
					println("apache error log:");
					println(sys.io.File.getContent(Path.join([apachePath, "logs", "error.log"])));
					println("====================");
					println("apache config:");
					println(sys.io.File.getContent(Path.join([apachePath, "conf", "httpd.conf"])));
					println("====================");
				}
			case "Mac":
				runCommand("brew", ["install", "httpd", "mysql@5.7"]);

				runCommand("brew", ["services", "start", "mysql@5.7"]);

				configDb();

				runCommand("apachectl", ["start"]);
				Sys.sleep(2.5);
				writeApacheConf("/usr/local/etc/httpd/httpd.conf");
				Sys.sleep(2.5);
				runCommand("apachectl", ["restart"]);
				Sys.sleep(2.5);

				try {
					haxe.Http.requestUrl('http://${HAXELIB_SERVER}:${HAXELIB_SERVER_PORT}/');
				} catch (e:Dynamic) {
					println("Cannot open webpage.");
					println("====================");
					println("apache config:");
					println(sys.io.File.getContent("/usr/local/etc/httpd/httpd.conf"));
					println("====================");
					println("apache error log:");
					println(sys.io.File.getContent("/usr/local/var/log/httpd/error_log"));
					println("====================");
				}
			case "Linux":
				configDb();

				runCommand("sudo", ["apt-get", "install", "-y", "apache2"]);

				runCommand("sudo", ["a2enmod", "rewrite"]);
				runCommand("sudo", ["a2enmod", "deflate"]);

				writeApacheConf("haxelib.conf");
				runCommand("sudo", ["ln", "-s", Path.join([Sys.getCwd(), "haxelib.conf"]), "/etc/apache2/conf-enabled/haxelib.conf"]);

				runCommand("sudo", ["service", "apache2", "restart"]);
				Sys.sleep(2.5);

				try {
					haxe.Http.requestUrl('http://${HAXELIB_SERVER}:${HAXELIB_SERVER_PORT}/');
				} catch (e:Dynamic) {
					println("Cannot open webpage.");
					println("====================");
					println("apachectl -V:");
					command("sudo", ["apachectl", "-V"]);
					println("====================");
					println("apachectl -M:");
					command("sudo", ["apachectl", "-M"]);
					println("====================");
					println("cat /var/log/apache2/error.log");
					command("sudo", ["cat", "/var/log/apache2/error.log"]);
					println("====================");
				}
			case name:
				throw "System not supported: " + name;
		}

		Sys.setCwd("www");
		runCommand("npm", ["install"]);
		Sys.setCwd("..");

		Sys.putEnv("HAXELIB_SERVER", HAXELIB_SERVER);
		Sys.putEnv("HAXELIB_SERVER_PORT", HAXELIB_SERVER_PORT);

		test();

		switch (systemName()) {
			case "Mac":
				runCommand("apachectl", ["stop"]);
				runCommand("brew", ["services", "stop", "mysql@5.7"]);
			case _:
				//pass
		}
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

			if (Timer.stamp() - t > 9 * 60) {
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
					runCommand("neko", ["bin/integration_tests.n"]);
					runCommand("haxe", ["integration_tests.hxml", "-D", "system_haxelib"]);
			}
			runCommand("neko", ["bin/integration_tests.n"]);
		}
		if (Sys.getEnv("CI") != null && Sys.getEnv("USE_DOCKER") == null) {
			runWithLocalServer(test);
		} else {
			runWithDockerServer(test);
		}
	}

	static function deploy():Void {
		switch (Sys.getEnv("DEPLOY")) {
			case null:
				Sys.println("DEPLOY is not set to 1, skip deploy");
				Sys.exit(0);
			case "1":
				//pass
			case _:
				Sys.println("DEPLOY is not set to 1, skip deploy");
				Sys.exit(0);
		}

		switch (Sys.getEnv("TRAVIS_BRANCH")) {
			case null:
				throw "unknown branch";
			case "master", "development":
				//pass
			case _:
				Sys.println("branch is not master or development, skip deploy");
				Sys.exit(0);
		}

		switch (Sys.getEnv("TRAVIS_PULL_REQUEST")) {
			case "false":
				// pass
			case _:
				Sys.println("it is a pull request build, skip deploy");
				Sys.exit(0);
		}

		switch ([
			Sys.getEnv("DOCKER_USERNAME"),
			Sys.getEnv("DOCKER_PASSWORD"),
		]) {
			case [null, _] | [_, null]:
				Sys.println('missing a docker env var, skip deploy');
				Sys.exit(0);
			case [
				docker_username,
				docker_password
			]:
				if (Sys.command("docker", ["login", '-u=$docker_username', '-p=$docker_password']) != 0)
					throw "docker login failed";
		}

		var commit = Sys.getEnv("TRAVIS_COMMIT");
		var target = 'haxe/lib.haxe.org:${commit}';
		runCommand("docker", ["tag", "haxelib_web", target]);
		runCommand("docker", ["push", target]);

		sys.io.File.saveContent("Dockerrun.aws.json", Json.stringify({
			"AWSEBDockerrunVersion": "1",
			"Image": {
				"Name": target,
				"Update": "true"
			},
			"Ports": [
				{
					"ContainerPort": "80"
				}
			],
			"Volumes": [
				{
					"HostDirectory": "/media/docker_files",
					"ContainerDirectory": "/var/www/html/files"
				},
				{
					"HostDirectory": "/media/docker_tmp",
					"ContainerDirectory": "/var/www/html/tmp"
				}
			]
		}));

		runCommand("zip", ["-r", "eb.zip", "Dockerrun.aws.json", ".ebextensions"]);
	}

	static function main():Void {
		// Note that package.zip output is also used by client tests, so it has to be run before that.
		runCommand("haxe", ["package.hxml"]);
		runCommand("haxe", ["prepare_tests.hxml"]);

		compileLegacyClient();
		compileLegacyServer();

		// the server can only be compiled with haxe 3.4+
		// haxe 3.1.3 bundles haxelib client 3.1.0-rc.4, which is not upgradable to later haxelib
		// so there is no need to test the client either
		#if (haxe_ver >= 3.2)
			compileClient();
			testClient();
		#end
		#if ((haxe_ver >= 3.4) && (haxe_ver < 4))
			compileServer();
			testServer();
		#end

		// integration test
		switch (systemName()) {
			case "Windows", "Linux":
				integrationTests();
			case "Mac":
				#if ((haxe_ver >= 3.4) && (haxe_ver < 4))
					integrationTests();
				#end
			case _:
				throw "Unknown system";
		}

		deploy();
	}
}