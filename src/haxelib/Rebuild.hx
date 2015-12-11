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
package haxelib;

import sys.FileSystem;
import sys.io.Process;

class Rebuild {
	static function run(cmd:String, ?msg:String = '', ?args:Array<String>) {
		if (args == null) args = [];
		var p = new Process(cmd, args);
		if (p.exitCode() != 0) 
			throw 'Error $msg:' + p.stderr.readAll().toString();
	}
	static function main() 
		try {
			Sys.sleep(.5);//wait for calling haxelib to exit
			switch Sys.systemName() {
				case 'Windows':
				case os: throw 'Wrong OS. Expected Windows but detected $os';
			}
			var haxepath = Sys.getEnv("HAXEPATH");
			var file = '$haxepath/haxelib.n';
			
			run('haxe', 'rebuilding haxelib', [
				'-neko', file, 
				'-lib', 'haxelib_client', 
				'-main', 'haxelib.Main', 
			]);
			run('nekotools', 'booting haxe', ['boot', file]);
			FileSystem.deleteFile(file);
			var oldMode = FileSystem.exists('update.hxml');
			if (oldMode)
				FileSystem.deleteFile('update.hxml');
				
			Sys.println('Update successful.');
			
			if (!oldMode) {
				Sys.println('Rebuild will exit in 5 seconds.');
				Sys.sleep(5.0);
			}
		}
		catch (e:Dynamic) {
			Sys.println(Std.string(e));
			Sys.println('Press any key to close');
			Sys.getChar(false);
		}
}