package haxelib;

class Run
{
	public static function main ()
	{
		var args = ["haxelib.n", "--safe"].concat(Sys.args());
		args.pop();
		Sys.exit(Sys.command("neko", args));
	}
}
