package website.api;

import haxe.crypto.Md5;
import website.model.SiteDb;
import ufront.web.HttpError;
import ufront.api.UFApi;
import haxe.Utf8;
using tink.CoreApi;
using CleverSort;
using Lambda;

class UserApi extends UFApi {
	@inject("documentationPath") public var docPath:String;

	/**
		Given a username, return that user object and a
	**/
	public function getUserProfile( username:String ):Outcome<Pair<User,Array<Project>>,Error> {
		try {
			var user = User.manager.select( $name==username );
			if ( user==null )
				return Failure( HttpError.pageNotFound() );

			var projectJoins = Developer.manager.search( $user==user.id );
			var projects = [for (j in projectJoins) j.projectObj];
			projects.cleverSort( -_.downloads );

			return Success( new Pair(user,projects) );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to fetch user profile for $username', e) );
	}

	/**
	**/
	public function getUserList():Outcome<Array<{ user:User, emailHash:String, projects:Array<Project>, totalDownloads:Int }>,Error> {
		try {
			// Fetch all the objects we are going to be using:
			var allUsers = User.manager.all();
			var allProjects = Project.manager.all();
			var joins = Developer.manager.all();

			// Collate them into a map, tally the downloads
			var map = new Map();
			for ( u in allUsers ) {
				var hash = Md5.encode( u.email );
				var obj = { user:u, emailHash:hash, projects:[], totalDownloads:0 };
				map.set( u.id, obj );
			}
			for ( j in joins ) {
				var obj = map[j.userObj.id];
				var project = j.projectObj;
				if ( project==null ) throw 'How is it null? ${j}';
				obj.projects.push( project );
				obj.totalDownloads += project.downloads;
			}

			// Sort the projects on each user, and then the users
			var arr = [];
			for ( obj in map ) {
				obj.projects.cleverSort( -_.downloads, _.name );
				arr.push( obj );
			}
			arr.cleverSort( -_.totalDownloads, _.user.fullname );

			return Success( arr );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get list of all users',e) );
	}
}
