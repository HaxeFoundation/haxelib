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

	static function setupLocalServer():Void {
		var NEKOPATH = getEnv("NEKOPATH");
		var DocumentRoot = Path.join([getCwd(), "www"]);
		function copyConfigs():Void {
			saveContent(Path.join(["www", "dbconfig.json"]), Json.stringify({
				"user": "travis",
				"pass": "",
				"host": "localhost",
				"database": "haxelib_test"
			}));
			copy(Path.join(["src", "haxelib", "server", ".htaccess"]), Path.join(["www", ".htaccess"]));
		}
		function writeApacheConf(confPath:String):Void {
			var confContent =
'
LoadModule neko_module ${Path.join([NEKOPATH, "mod_neko2.ndll"])}
LoadModule tora_module ${Path.join([NEKOPATH, "mod_tora2.ndll"])}
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
		switch (systemName()) {
			case "Mac":
				runCommand("brew", ["install", "homebrew/apache/httpd22", "mysql"]);

				runCommand("mysql.server", ["start"]);
				runCommand("mysql", ["-u", "root", "-e", "create user if not exists travis@localhost;"]);

				runCommand("apachectl", ["start"]);
				Sys.sleep(2.5);
				copyConfigs();
				writeApacheConf("/usr/local/etc/apache2/2.2/httpd.conf");
				Sys.sleep(2.5);
				runCommand("apachectl", ["restart"]);
				Sys.sleep(2.5);
			case "Linux":
				runCommand("sudo", ["apt-get", "install", "apache2"]);

				copyConfigs();
				writeApacheConf("haxelib_test.conf");
				runCommand("sudo", ["ln", "-s", Path.join([Sys.getCwd(), "haxelib_test.conf"]), "/etc/apache2/conf.d/haxelib_test.conf"]);
				runCommand("sudo", ["ln", "-s", Path.join([NEKOPATH, "libneko.so"]), "/usr/lib/libneko.so"]);
				runCommand("sudo", ["a2enmod", "rewrite"]);
				runCommand("sudo", ["service", "apache2", "restart"]);
				Sys.sleep(2.5);
			case name:
				throw "System not supported: " + name;
		}
	}

	static function integrationTests():Void {
		setupLocalServer();

		runCommand("haxelib", ["install", "tora"]);
		infoMsg("starting tora...");
		var tora = new sys.io.Process("haxelib", ["run", "tora"]);

		runCommand("haxe", ["integration_tests.hxml"]);
		runCommand("haxe", ["integration_tests.hxml", "-D", "system_haxelib"]);

		tora.close();
	}

	static function main():Void {
		// Note that package.zip output is also used by client tests, so it has to be run before that.
		runCommand("haxe", ["package.hxml"]);

		compileLegacyClient();
		compileLegacyServer();
		compileClient();
		testClient();

		// the server can only be compiled with haxe 3.2.x for now...
		#if ((haxe_ver >= 3.2) && (haxe_ver < 3.3))
		compileServer();

		switch (systemName()) {
			case "Windows":
				// skip for now
				// The Neko 2.0 Windows binary archive is missing "msvcr71.dll", which is a dependency of "sqlite.ndll".
				// https://github.com/HaxeFoundation/haxe/issues/2008#issuecomment-176849497
			case "Linux":
				// skip for now
				// Unreleased fix: https://github.com/HaxeFoundation/neko/pull/34
			case "Mac":
				testServer();
				integrationTests();
		}
		#end
	}
}