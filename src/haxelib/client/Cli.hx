/*
 * Copyright (C)2005-2016 Haxe Foundation
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

enum OutputMode {
	Quiet;
	Debug;
	None;
}

enum abstract DefaultAnswer(Null<Bool>) to Null<Bool> {
	final Always = true;
	final Never = false;
	final None = null;
}

private enum abstract Unit(String) to String {
	final MB = "MB";
	final KB = "KB";

	public static function convertFromBytes(value:Int, unit:Unit):Float{
		final by = switch unit {
			case MB: 1000000;
			case KB: 1000;
			default: 1;
		}
		// 12.34 precision.
		return Math.round((value/by) * 100) / 100;
	}

	public static function getUnitFor(value:Int):Unit {
		if ((value / 1000000) > 1)
			return MB;
		return KB;
	}
}

class Cli {
	public static var defaultAnswer(null, default):DefaultAnswer = None;
	public static var mode:OutputMode = None;

	public static function ask(question:String):Bool {
		if (defaultAnswer != None)
			return defaultAnswer;

		while (true) {
			Sys.print(question + " [y/n/a] ? ");
			try {
				switch (Sys.stdin().readLine()) {
					case "n": return false;
					case "y": return true;
					case "a": return defaultAnswer = Always;
				}
			} catch (e:haxe.io.Eof) {
				Sys.println("n");
				return false;
			}
		}
		return false;
	}

	public static function getSecretInput(prompt:String):String {
		Sys.print('$prompt : ');
		final s = new StringBuf();
		do
			switch Sys.getChar(false) {
				case 10, 13:
					break;
				case 0: // ignore (windows bug)
				case c:
					s.addChar(c);
			} while (true);
		Sys.println("");
		return s.toString();
	}

	public static function printInstallStatus(_, current:Int, total:Int) {
		Sys.stdout().writeString("\033[2K\r");
		if (current != total) {
			final percent = Std.int((current / total) * 100);
			Sys.print('${current + 1}/$total ($percent%)');
		}
	}

	public static function printUploadStatus(pos:Int, total:Int) {
		Sys.print("\033[2K\r" + Std.int((pos * 100.0) / total) + "%");
	}

	public static function printDownloadStatus(_:String, finished:Bool, cur:Int, max:Null<Int>, downloaded:Int, time:Float) {
		Sys.stdout().writeString("\033[2K\r");
		// clear line and return to beginning
		if (finished) {
			final rawSpeed = (downloaded / time) / 1000;
			final speed = Std.int(rawSpeed * 10) / 10;
			final time = Std.int(time * 10) / 10;
			final unit = Unit.getUnitFor(downloaded);

			final readableBytes = Unit.convertFromBytes(downloaded, unit);

			Sys.println('Download complete: ${readableBytes}${unit} in ${time}s (${speed}KB/s)');
		} else if (max == null) {
			final unit = Unit.getUnitFor(cur);
			final curReadable = Unit.convertFromBytes(cur, unit);

			Sys.print('${curReadable} $unit');
		} else {
			final unit = Unit.getUnitFor(max);
			final curReadable = Unit.convertFromBytes(cur, unit);

			final maxReadable = Unit.convertFromBytes(max, unit);
			final percentage = Std.int((cur * 100.0) / max);

			Sys.print('${curReadable} $unit / ${maxReadable} $unit ($percentage%)');
		}
	}

	public static function getInput(prompt:String): String {
		Sys.print('$prompt : ');
		return Sys.stdin().readLine();
	}

	public static inline function print(str:String)
		Sys.println(str);

	public static inline function printString(str:String)
		Sys.print(str);

	public static inline function printWarning(message:String)
		if (mode != Quiet)
			Sys.stderr().writeString('Warning: $message\n');

	public static inline function printError(message:String)
		Sys.stderr().writeString('${message}\n');

	/** Prints `message` to stdout only if in Debug mode **/
	public static function printDebug(message:String)
		if (mode == Debug)
			Sys.println(message);

	/** Prints `message` to stderr only if in Debug mode **/
	public static function printDebugError(message:String)
		if (mode == Debug)
			Sys.stderr().writeString('${message}\n');

	/** Prints `message` to stdout, unless in Quiet mode **/
	public static function printOptional(message:String)
		if (mode != Quiet)
			Sys.println(message);

	/** Prints `message` to stderr, unless in Quiet mode **/
	public static function printOptionalError(message:String)
		if (mode != Quiet)
			Sys.stderr().writeString('${message}\n');

}
