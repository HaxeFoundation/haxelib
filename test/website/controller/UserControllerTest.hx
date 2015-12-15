package website.controller;

import haxe.crypto.Md5;
import haxelib.server.SiteDb;
import website.controller.*;
import website.api.UserApi;
import ufront.web.result.*;
import ufront.web.result.ViewResult;
import website.Server;
using tink.CoreApi;

// These imports are common for our various test-suite tools.
import buddy.*;
import mockatoo.Mockatoo.*;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import utest.Assert;
using buddy.Should;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;

class UserControllerTest extends BuddySuite {
	public function new() {

		var haxelibSite = WebsiteTests.getTestApp();
		var mockApi = mock( UserApi );
		haxelibSite.injector.map( UserApi ).toValue( mockApi );

		function mockUser(user,name,email) {
			var u = new User();
			u.name = user;
			u.fullname = name;
			u.email = email;
			var hash = Md5.encode( email );
			return { user:u, emailHash:hash, projects:[], totalDownloads:[] };
		}
		var user1 = mockUser( "jason", "Jason O'Neil", "jason@example.org" );
		var user2 = mockUser( "ncanasse", "Nicolas Canasse", "nc@example.org" );
		var projects = [];

		mockApi.getUserProfile(cast anyString).returns( Success(new Pair(user1.user,[])) );
		mockApi.getUserList().returns( Success([user1, user2]) );

		describe("When I look at the profile of a user", {
			it("Should show me that users profile and their projects", function (done) {
				whenIVisit( "/u/jason" )
					.onTheApp( haxelibSite )
					.itShouldLoad( UserController, "profile", ["jason"] )
					.itShouldReturn( ViewResult, function (result) {
						var title:String = result.data['title'];
						(result.data['title']:String).should.be("jason (Jason O'Neil) on Haxelib");
						Assert.same( result.templateSource, TFromEngine("user/profile") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
					})
					.andFinishWith( done );
			});
		});

		describe("When I want to see a list of users", {
			it("Should show me that list, sorted by number of projects", function (done) {
				whenIVisit( "/u" )
					.onTheApp( haxelibSite )
					.itShouldLoad( UserController, "list", [] )
					.itShouldReturn( ViewResult, function (result) {
						var title:String = result.data['title'];
						(result.data['title']:String).should.be("Haxelib Contributors");
						Assert.same( result.templateSource, TFromEngine("user/list") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
					})
					.andFinishWith( done );
			});
		});
	}
}
