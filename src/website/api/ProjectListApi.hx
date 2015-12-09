package website.api;

import ufront.api.UFApi;
import website.model.SiteDb;
using tink.CoreApi;
using Lambda;
using CleverSort;

class ProjectListApi extends UFApi {
	public function all():Outcome<Array<Project>,Error> {
		try {
			var all = Project.manager.search(1 == 1,{ orderBy: [-downloads,name] });
			return Success( all.array() );
		}
		catch ( e:Dynamic ) return Failure( Error.withData("Failed to get list of all projects",e) );
	}

	public function byUser( username:String ):Outcome<Array<Project>,Error> {
		try {
			var user = User.manager.select( $name==username );
			if ( user==null )
				return Failure( new Error(404,'User $username not found') );

			var joins = Developer.manager.search( $user==user.id );
			// TODO: It would be better to do a single query on all IDs, rather than a single query for each project.
			// Unfortunately, the current set up of the "Developer" model doesn't give us access to the ID.
			var theirProjects = [ for (j in joins) j.projectObj ];
			return Success( theirProjects );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get list of projects belong to $username',e) );
	}

	public function getTagList( num:Int ):Outcome<Array<{ tag:String, count: Int }>,Error> {
		try {
			// TODO, see if we can return more useful info, maybe including the most popular projects in this tag etc.
			return Success( Tag.topTags(num).array() );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get list of tags',e) );
	}

	public function byTag( tag:String ):Outcome<Array<Project>,Error> {
		try {
			var tagJoins = Tag.manager.search( $tag==tag );
			// TODO: It would be better to do a single query on all IDs, rather than a single query for each project.
			// Unfortunately, the current set up of the "Tag" model doesn't give us access to the ID.
			var projects = [for (t in tagJoins) t.projectObj];
			projects.cleverSort( -_.downloads );
			return Success( projects );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get list of projects with tag $tag',e) );
	}

	public function search( word:String ):Outcome<Array<Project>,Error> {
		try {
			// TODO: We should match other things too. Tags & users especially. Also release notes, docs, readmes.
			word = '%$word%';
			var searchResults = Project.manager.search($name.like(word) || $description.like(word));
			return Success( searchResults.array() );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to search for projects with "$word" in the name or description',e) );
	}

	public function latest( n:Int ):Outcome<Array<{ v:Version, p:Project }>,Error> {
		try {
			var latestVersions = Version.latest( n );
			var l = new List();
			// TODO: again, we are performing many queries here. Need to access project ID somehow.
			var versionsAndProjects = [for (v in latestVersions) { v:v, p:v.projectObj }];
			return Success( versionsAndProjects  );
		}
		catch ( e:Dynamic ) return Failure( Error.withData('Failed to get most recent $n projects',e) );
	}
}