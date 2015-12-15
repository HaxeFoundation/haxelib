package website;

import haxelib.server.SiteDb;
import mcli.Dispatch;
import ufront.api.UFApi;
import ufront.tasks.UFTaskSet;
import ufront.auth.*;
import ufront.auth.tasks.EasyAuthTasks;
import ufront.auth.EasyAuth;
import ufront.web.session.*;
import website.tasks.*;
using ufront.core.InjectionTools;

class Tasks extends UFTaskSet
{
	/**
		The CLI runner.
	**/
	static function main() {
		// Only access the command line runner from the command line, not the web.
		if ( !neko.Web.isModNeko ) {

			// This is an auth system that lets you do anything regardless of permissions, handy for CLI tools
			var auth = new EasyAuthAdminMode();

			var tasks = new Tasks();
			tasks.injector.map( UFHttpSession ).toValue( new VoidSession() );
			tasks.injector.map( UFAuthHandler ).toValue( auth );
			tasks.injector.map( EasyAuth ).toValue( auth );
			tasks.injector.map( String, "contentDirectory" ).toValue( "../uf-content" );
			tasks.useCLILogging( "log/twl-webapp.log" );

			// Inject our APIs
			for ( api in CompileTime.getAllClasses(UFApi) )
				tasks.injector.mapRuntimeTypeOf( api );

			SiteDb.init();
			tasks.execute( Sys.args() );
			SiteDb.cleanup();
		}
	}

	/**
		Easyauth task set
		@alias a
	**/
	public function auth( d:Dispatch ) {
		executeSubTasks( d, EasyAuthTasks );
	}

	/**
		DBCache task set
		@alias c
	**/
	public function cache( d:Dispatch ) {
		executeSubTasks( d, HaxelibCacheTasks );
	}
}
