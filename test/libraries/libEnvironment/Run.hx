class Run {
	static function main() {
		switch Sys.args() {
			case ["get", envVar, _]:
				Sys.print(Sys.getEnv(envVar));
			case ["cwd", cwd]:
				Sys.print(cwd);
			case _:
				Sys.stderr().writeString("Invalid command or arguments\n");
				Sys.exit(1);
		}
	}
}
