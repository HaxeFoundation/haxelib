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

import haxe.Timer;
import haxe.io.Output;
import haxe.io.Input;

import sys.io.FileOutput;

private class ProgressOut extends Output {
	final o:Output;
	final startSize:Int;
	final start:Float;

	var cur:Int;
	var curReadable:Float;
	var max:Null<Int>;
	var maxReadable:Null<Float>;

	public function new(o, currentSize) {
		this.o = o;
		startSize = currentSize;
		cur = currentSize;
		start = Timer.stamp();
	}

	function report(n) {
		cur += n;

		final tag:String = ((max != null ? max : cur) / 1000000) > 1 ? "MB" : "KB";

		curReadable = tag == "MB" ? cur / 1000000 : cur / 1000;
		curReadable = Math.round(curReadable * 100) / 100; // 12.34 precision.

		if (max == null)
			Sys.print('${curReadable} ${tag}\r');
		else {
			maxReadable = tag == "MB" ? max / 1000000 : max / 1000;
			maxReadable = Math.round(maxReadable * 100) / 100; // 12.34 precision.

			Cli.printString('${curReadable}${tag} / ${maxReadable}${tag} (${Std.int((cur * 100.0) / max)}%)\r');
		}
	}

	public override function writeByte(c) {
		o.writeByte(c);
		report(1);
	}

	public override function writeBytes(s, p, l) {
		final r = o.writeBytes(s, p, l);
		report(r);
		return r;
	}

	public override function close() {
		super.close();
		o.close();

		var time = Timer.stamp() - start;
		final downloadedBytes = cur - startSize;
		var speed = (downloadedBytes / time) / 1000;
		time = Std.int(time * 10) / 10;
		speed = Std.int(speed * 10) / 10;

		final tag:String = (downloadedBytes / 1000000) > 1 ? "MB" : "KB";
		var readableBytes:Float = (tag == "MB") ? downloadedBytes / 1000000 : downloadedBytes / 1000;
		readableBytes = Math.round(readableBytes * 100) / 100; // 12.34 precision.

		Cli.print('Download complete: ${readableBytes}${tag} in ${time}s (${speed}KB/s)');
	}

	public override function prepare(m) {
		max = m + startSize;
	}
}

private class ProgressIn extends Input {
	final i:Input;
	final tot:Int;

	var pos:Int;

	public function new(i, tot) {
		this.i = i;
		this.pos = 0;
		this.tot = tot;
	}

	public override function readByte() {
		final c = i.readByte();
		report(1);
		return c;
	}

	public override function readBytes(buf, pos, len) {
		final k = i.readBytes(buf, pos, len);
		report(k);
		return k;
	}

	function report(nbytes:Int) {
		pos += nbytes;
		Cli.printString(Std.int((pos * 100.0) / tot) + "%\r");
	}
}

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

class Cli {
	public static var defaultAnswer(null, default):DefaultAnswer = None;
	public static var mode(null, default):OutputMode = None;

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

	public static function createDownloadOutput(out:FileOutput, currentSize:Int):haxe.io.Output {
		if (mode == Quiet)
			return out;
		return new ProgressOut(out, currentSize);
	}

	public static function createUploadInput(data:haxe.io.Bytes):haxe.io.Input {
		final dataBytes = new haxe.io.BytesInput(data);
		if (mode == Quiet)
			return dataBytes;
		return new ProgressIn(dataBytes, data.length);
	}

	public static function printInstallStatus(current:Int, total:Int) {
		if (mode != Debug)
			return;
		final percent = Std.int((current / total) * 100);
		Sys.print('${current + 1}/$total ($percent%)\r');
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
