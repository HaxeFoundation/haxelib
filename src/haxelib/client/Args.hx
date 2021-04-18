package haxelib.client;

using StringTools;

class SwitchError extends haxe.Exception {}
class InvalidCommand extends haxe.Exception {}

@:structInit
class ArgsInfo {
	public final command:Command;
	public final mainArgs: Array<String>;
	public final flags: Array<Flag>;
	public final options: Map<Option, String>;
	public final repeatedOptions: Map<RepeatedOption, Array<String>>;
}

enum CommandCategory {
	Basic;
	Information;
	Development;
	Miscellaneous;
	Deprecated(msg:String);
}

enum abstract Command(String) to String {
	final Install = "install";
	final Update = "update";
	final Remove = "remove";
	final List = "list";
	final Set = "set";

	final Search = "search";
	final Info = "info";
	final User = "user";
	final Config = "config";
	final Path = "path";
	final LibPath = "libpath";
	final Version = "version";
	final Help = "help";

	final Submit = "submit";
	final Register = "register";
	final Dev = "dev";
	// TODO: generate command about VCS by Vcs.getAll()
	final Git = "git";
	final Hg = "hg";

	final Setup = "setup";
	final NewRepo  = "newrepo";
	final DeleteRepo = "deleterepo";
	final ConvertXml = "convertxml";
	final Run = "run";
	final Proxy = "proxy";
	// deprecated commands
	final Local = "local";
	final SelfUpdate = "selfupdate";

	static final ALIASES = [
		"upgrade" => Update
	];

	static final COMMANDS = Util.getValues(Command);

	public static function ofString(str:String):Null<Command> {
		// first check aliases
		final alias = ALIASES.get(str);
		if(alias != null)
			return alias;
		// then check the rest
		for (command in COMMANDS) {
			if (cast(command, String) == str)
				return command;
		}
		return null;
	}

}

enum abstract Flag(String) to String {
	final Global = "global";
	final Debug = "debug";
	final Quiet = "quiet";
	final Flat = "flat";
	final Always = "always";
	final Never = "never";
	final System = "system";
	final SkipDependencies = "skip-dependencies";
	// hidden
	final NoTimeout = "no-timeout";

	public static final MUTUALLY_EXCLUSIVE = [[Quiet, Debug], [Always, Never]];

	/**
		Priority flags that need to be accessed prior to
		complete argument parsing.
	**/
	public static final PRIORITY = [System, Debug, Global];

	static final ALIASES = ["notimeout" => NoTimeout];

	static final FLAGS = Util.getValues(Flag);

	public static function ofString(str:String):Null<Flag> {
		// first check aliases
		final alias = ALIASES.get(str);
		if (alias != null)
			return alias;

		for (flag in FLAGS) {
			if (cast(flag, String) == str)
				return flag;
		}
		return null;
	}

}

enum abstract Option(String) to String {
	final Remote = "remote";

	static final ALIASES = ["R" => Remote];

	static final OPTIONS = Util.getValues(Option);

	public static function ofString(str:String):Null<Option> {
		// first check aliases
		final alias = ALIASES.get(str);
		if (alias != null)
			return alias;

		for (option in OPTIONS) {
			if (cast(option, String) == str)
				return option;
		}
		return null;
	}
}

/** Option that can be put in more than once **/
enum abstract RepeatedOption(String) to String {
	final Cwd = "cwd";
	// just because this is how --cwd worked before

	static final REPEATED_OPTIONS = Util.getValues(RepeatedOption);

	public static function ofString(str:String):Null<RepeatedOption> {
		for (rOption in REPEATED_OPTIONS) {
			if (cast(rOption, String) == str)
				return rOption;
		}
		return null;
	}
}

class Args {
	/**
		Returns an array of the priority flags included in the array `args`.

		These are the flags that need to be accessed before deciding whether
		the call is passed onto the haxelib version.
	 **/
	public static function extractPriorityFlags(args:Array<String>):Array<Flag> {
		final flags = [];
		for(arg in args) {
			final switchName = parseSwitch(arg);
			if(switchName == null)
				continue;

			final flag = Flag.ofString(switchName);
			if(flag != null && Flag.PRIORITY.contains(flag))
				flags.push(flag);
		}
		return flags;
	}

	/**
		Extracts all the flags, options and arguments in the array `args`,
		and returns these in an `ArgsInfo` object.
	 **/
	public static function extractAll(args:Array<String>):ArgsInfo {
		final flags:Array<Flag> = [];
		final options: Map<Option, String> = [];
		final repeatedOptions: Map<RepeatedOption, Array<String>> = [];
		final mainArgs:Array<String> = [];

		var arg:String;
		var index = 0;

		function requireNext():String {
			final current = args[index - 1];
			final next = args[index++];
			if (next == null)
				throw new SwitchError('$current requires an extra argument');
			return next;
		}

		while (index < args.length) {
			arg = args[index++];
			switch (parseSwitch(arg)) {
				case null:
					mainArgs.push(arg);
					// put all of them into the rest array
					if (arg == "run")
						while (index < args.length)
							mainArgs.push(args[index++]);

				case Flag.ofString(_) => flag if (flag != null):
					flags.push(flag);

				case Option.ofString(_) => option if (option != null):
					options[option] = requireNext();

				case RepeatedOption.ofString(_) => rOption if (rOption != null):
					if (repeatedOptions[rOption] == null)
						repeatedOptions[rOption] = [];
					repeatedOptions[rOption].push(requireNext());
				// case invalid if(invalid != null):
				// 	throw new ParsingFail('unknown switch $arg');
			}
		}

		validate(flags);

		final commandStr = mainArgs.shift();
		if (commandStr == null)
			throw new InvalidCommand("");

		final command = Command.ofString(commandStr);
		if(command == null)
			throw new InvalidCommand('Unknown command $commandStr');

		return {
			command:command,
			mainArgs: mainArgs,
			flags: flags,
			options: options,
			repeatedOptions: repeatedOptions
		}
	}

	static final twoDash = ~/^--(.{2,})$/;
	static final singleDash = ~/^-([^-].*)$/; // ~/^-([^-])$/ to only match single characters
	/** Strips dashes off switch `s`, and gets its alias if one exists **/
	static function parseSwitch(s:String):Null<String> {
		return
			if (twoDash.match(s))
				twoDash.matched(1)
			else if (singleDash.match(s))
				singleDash.matched(1);
			else
				null;
	}

	static final splitDash = ~/-([a-z])/g;
	static inline function dashSplitToCamel(s:String) {
		return splitDash.map(s, (r) -> r.matched(1).toUpperCase());
	}

	static function validate(flags:Array<Flag>) {
		// check if both mutually exclusive flags are present
		for (pair in Flag.MUTUALLY_EXCLUSIVE)
			if (flags.contains(pair[0]) && flags.contains(pair[1]))
				throw new SwitchError('--${pair[0]} and --${pair[1]} are mutually exclusive');
	}

	/**
		Returns a list of objects storing the names and
		descriptions for available switches.
	**/
	public static function generateSwitchDocs(): List<{name:Flag, description:String}>{
		final flags = new List();

		function addSwitch(name:Flag, desc:String)
			flags.add({name:name, description:desc});

		// hidden switches are just not given an entry here
		addSwitch(Global, "force global repo if a local one exists");
		addSwitch(Debug, "run in debug mode, imply not --quiet");
		addSwitch(Quiet, "print fewer messages, imply not --debug");
		addSwitch(Flat, "do not use --recursive cloning for git");
		addSwitch(Always, "answer all questions with yes");
		addSwitch(Never, "answer all questions with no");
		addSwitch(System, "run bundled haxelib version instead of latest update");
		addSwitch(SkipDependencies, "do not install dependencies");

		return flags;
	}

	public static function generateCommandDocs():List<{name:Command, doc:String, cat:CommandCategory}> {
		final commands = new List();
		function addCommand(name, doc, cat)
			commands.add({name: name, doc: doc, cat: cat});

		addCommand(Install, "install a given library, or all libraries from a hxml file", Basic);
		addCommand(Update, "update a single library (if given) or all installed libraries", Basic);
		addCommand(Remove, "remove a given library/version", Basic);
		addCommand(List, "list all installed libraries", Basic);
		addCommand(Set, "set the current version for a library", Basic);

		addCommand(Search, "list libraries matching a word", Information);
		addCommand(Info, "list information on a given library", Information);
		addCommand(User, "list information on a given user", Information);
		addCommand(Config, "print the repository path", Information);
		addCommand(Path, "give paths to libraries' sources and necessary build definitions", Information);
		addCommand(LibPath, "returns the root path of a library", Information);
		addCommand(Version, "print the currently used haxelib version", Information);
		addCommand(Help, "display this list of options", Information);

		addCommand(Submit, "submit or update a library package", Development);
		addCommand(Register, "register a new user", Development);
		addCommand(Dev, "set the development directory for a given library", Development);

		addCommand(Git, "use Git repository as library", Development);
		addCommand(Hg, "use Mercurial (hg) repository as library", Development);

		addCommand(Setup, "set the haxelib repository path", Miscellaneous);
		addCommand(NewRepo, "create a new local repository", Miscellaneous);
		addCommand(DeleteRepo, "delete the local repository", Miscellaneous);
		addCommand(ConvertXml, "convert haxelib.xml file to haxelib.json", Miscellaneous);
		addCommand(Run, "run the specified library with parameters", Miscellaneous);
		addCommand(Proxy, "setup the Http proxy", Miscellaneous);

		return commands;
	}
}
