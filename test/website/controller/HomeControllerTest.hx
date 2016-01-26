package website.controller;

import website.api.ProjectListApi;
import website.controller.*;
import ufront.web.result.*;
import ufront.web.result.ViewResult;
import website.Server;
using tink.CoreApi;
import haxelib.server.SiteDb;

// These imports are common for our various test-suite tools.
import buddy.*;
import mockatoo.Mockatoo.*;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import utest.Assert;
using buddy.Should;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;

class HomeControllerTest extends BuddySuite {
	public function new() {

		var haxelibSite = WebsiteTests.getTestApp();
		var mockApi = mock( ProjectListApi );
		haxelibSite.injector.map( ProjectListApi ).toValue( mockApi );
		mockApi.all().returns( Success(new List()) );
		mockApi.byUser(cast anyString).returns( Success(new List()) );
		mockApi.byTag(cast anyString).returns( Success(new List()) );
		mockApi.search(cast anyString).returns( Success(new List()) );
		mockApi.latest(cast anyInt).returns( Success(new List()) );
		mockApi.getTagList(cast anyInt).returns( Success(new List()) );

		describe("When I go to the homepage", {
			it("Should show our homepage view", function (done) {


				whenIVisit( "/" )
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "homepage", [] )
					.itShouldReturn( ViewResult, function (result) {
						var title:String = result.data['title'];
						(result.data['title']:String).should.be("Haxelib - the Haxe package manager");
						Assert.same( result.templateSource, TFromEngine("home/homepage") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
						// TODO: check we have a list of popular projects
						// TODO: check we have a list of recent projects
					})
					.andFinishWith( done );
			});
			// TODO: it("Show me my projects if I am logged in");
		});

		describe("When I load the tags page", {
			it("Should show me a list of the most popular tags, sorted by popularity", function (done) {
				whenIVisit( "/t/")
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "tagList", [] )
					.itShouldReturn( ViewResult, function(result) {
						Assert.same( result.templateSource, TFromEngine("home/tagList") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
						// TODO: check that the tags are listed...
					})
					.andFinishWith( done );
			});
		});

		describe("When I load a tag page", {
			it("Should show the list of projects with that tag", function (done) {
				whenIVisit( "/t/games")
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "tag", ["games"] )
					.itShouldReturn( ViewResult, function(result) {
						Assert.same( result.templateSource, TFromEngine("home/projectList.html") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
						// TODO: check that the matching projects are correct
					})
					.andFinishWith( done );
			});
		});

		describe("When I load the 'all projects' page", {
			it("Should show them all", function (done) {
				whenIVisit( "/all")
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "all", [] )
					.itShouldReturn( ViewResult, function(result) {
						Assert.same( result.templateSource, TFromEngine("home/projectList.html") );
						Assert.same( result.layoutSource, TFromEngine("layout.html") );
						// TODO: check that all projects are loaded
					})
					.andFinishWith( done );
		});
		});

		describe("When I search", {
			// TODO: ask Nicolas, should we just use Google?
//			it("Should show me the search form if there is no search term entered");
//			it("Should show projects matching the name");
//			it("Should show projects matching the description");
//			it("Redirect straight to the project page if there's only 1 search result");
		});

		describe("When I want to access the data through a JSON API", {
			it("Should give me search via JSON", function (done) {
				whenIVisit( "/search.json" )
					.withTheQueryParams([ "v"=>"web" ])
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "searchJson", [{ v: "web" }] )
					.itShouldReturn( JsonResult, function (result) {
						// TODO: check the data is good.
						// TODO: check the JSON is valid.
					})
					.andFinishWith( done );
			});
			it("Should give me tags via JSON", function (done) {
				whenIVisit( "/t/games.json" )
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "tag", ["games.json"] )
					.itShouldReturn( JsonResult, function (result) {
						// TODO: check the data is good.
						// TODO: check the JSON is valid.
					})
					.andFinishWith( done );
			});
			it("Should give me all via JSON", function (done) {
				whenIVisit( "/all.json" )
					.onTheApp( haxelibSite )
					.itShouldLoad( HomeController, "allJson", [] )
					.itShouldReturn( JsonResult, function (result) {
						// TODO: check the data is good.
						// TODO: check the JSON is valid.
					})
					.andFinishWith( done );
			});
		});
	}
}
