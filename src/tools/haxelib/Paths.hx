package tools.haxelib;

class Paths {
	static var RELATIVE_ROOT = 
		#if haxelib_api
			'../../';
		#else
			'';
		#end
	//TODO: these should be inline or read-only or whatever
	static public var CWD = neko.Web.getCwd() + RELATIVE_ROOT;
	static public var DB_CONFIG = CWD + "dbconfig.json";
	static public var DB_FILE = CWD + "haxelib.db";
	
	static public var TMP_DIR = CWD + "tmp";
	static public var TMPL_DIR = CWD + "tmpl/";
	static public var REP_DIR = CWD + Data.REPOSITORY;
	
}