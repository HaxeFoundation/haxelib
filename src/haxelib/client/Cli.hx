/*
 * Copyright (C)2005-2015 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package haxelib.client;

import sys.FileSystem;

enum CliError {
	CwdUnavailable(pwd:String);
	CantSetSwd_DirNotExist(dir:String);
}

class Cli {
	public static var defaultAnswer:Null<Bool>;

	public static function ask(question:String):Bool {
		if (defaultAnswer != null)
			return defaultAnswer;

		while (true) {
			Sys.print(question + " [y/n/a] ? ");
			try {
				switch (Sys.stdin().readLine()) {
					case "n": return false;
					case "y": return true;
					case "a": return defaultAnswer = true;
				}
			} catch (e:haxe.io.Eof) {
				Sys.println("n");
				return false;
			}
		}
		return false;
	}


	public static var cwd(get,set):String;

	static var cwd_cache:String;

	static function get_cwd():String {
		try {
			cwd_cache = Sys.getCwd();
		} catch (error:String) {
			switch(error) {
				case "std@get_cwd" | "std@file_path" | "std@file_full_path":
					var pwd = Sys.getEnv("PWD");
					// This is a magic for issue #196:
					// if we have $PWD then we can re-set it again.
					// Works for case: `$ mkdir temp; cd temp; rm -r ../temp; mkdir ../temp; haxelib upgrade;`
					if (pwd != null) {
						if (FileSystem.exists(pwd) && FileSystem.isDirectory(pwd))
							// Trying fix it: setting cwd to pwd
							Sys.setCwd(cwd_cache = pwd);
						else
							// Can't fix it.
							throw CliError.CwdUnavailable(pwd);
					} else {
						throw CliError.CwdUnavailable(pwd);
					}
				default:
					throw error;
			}
		}
		return cwd_cache;
	}

	static function set_cwd(value:String):String {
		//TODO: For call `FileSystem.isDirectory(value)` we can get an exeption "std@sys_file_type":
		if (value != null && cwd_cache != value && FileSystem.exists(value) && FileSystem.isDirectory(value))
			Sys.setCwd(cwd_cache = value);
		else
			throw CliError.CantSetSwd_DirNotExist(value);
		return cwd_cache;
	}
}
