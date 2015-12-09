package website.controller;

import haxe.io.Bytes;
import website.api.ProjectApi;
import website.controller.*;
import ufront.web.result.*;
import ufront.web.result.ViewResult;
import website.Server;
import haxe.ds.Option;
using tink.CoreApi;

// These imports are common for our various test-suite tools.
import buddy.*;
import mockatoo.Mockatoo.*;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import utest.Assert;
using buddy.Should;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;

class ProjectControllerTest extends BuddySuite {
	public function new() {

		var haxelibSite = WebsiteTests.getTestApp();
		var mockApi = mock( ProjectApi );
		haxelibSite.injector.map( ProjectApi ).toValue( mockApi );
		mockApi.projectInfo(cast anyString).returns( Success({
			name: "detox",
			desc: "Detox Description",
			website: "https://github.com/jasononeil/detox",
			owner: "jason",
			license: "MIT",
			curversion: "1.0.0-rc.8",
			versions: [{ date: "2010-01-01 34:56:12", name:"1.0.0-rc.8", downloads:150, comments:"Breaking changes everywhere." }],
			tags: new List(),
		}) );
		mockApi.readContentFromZip(cast anyString, cast anyString, cast anyString).returns( Success(Some("content")) );
		mockApi.readBytesFromZip(cast anyString, cast anyString, cast anyString).returns( Success(Some(Bytes.ofString(""))) );
		mockApi.getInfoForPath(cast anyString, cast anyString, cast anyString).returns( Success(Binary(12)) );

		describe("When I view a project", {
			it("Should show the project view for the latest version", function (done) {
				whenIVisit( "/p/detox" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "project", ["detox"] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check we got the latest version.
						// TODO: Check we got the correct project.
						Assert.same( TFromEngine("project/version.html"), result.templateSource );
						Assert.same( TFromEngine("layout.html"), result.layoutSource );
					})
					.andFinishWith( done );
			});
		});

		describe("When I view a project version", {

			var whenILoadAProjectVersion = whenIVisit( "/p/detox/1.0.0-rc.8/" ).onTheApp( haxelibSite );
			it("Should load the correct layout / view", function (done) {
				whenILoadAProjectVersion
				.itShouldLoad( ProjectController, "version", ["detox","1.0.0-rc.8"] )
				.itShouldReturn( ViewResult, function(result) {
					Assert.same( TFromEngine("project/version.html"), result.templateSource );
					Assert.same( TFromEngine("layout.html"), result.layoutSource );
				}).andFinishWith( done );
			});
			it("Should show me the README for the current version", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should show me the file list for the current version", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should show me a list of all versions", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should show me the haxelibs this depends on", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should show me the haxelibs that depend on this", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should let me know if there is a more recent version", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
			it("Should let me know if this version is not considered stable", function (done) {
				whenILoadAProjectVersion.itShouldReturn( ViewResult, function(result) {
					// TODO: add appropriate tests here...
				}).andFinishWith( done );
			});
		});

		describe("When I view a project's versions", {
			it("Should show me a list of all the versions of that project, with the ability to show stable releases only.", function(done) {
				whenIVisit( "/p/detox/versions" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "versionList", ["detox"] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check it shows the list of versions.
					})
					.andFinishWith( done );
			});
		});

		describe("When I view a project's files", {
			it("Should show me that file's source code in line", function (done) {
				whenIVisit( "/p/detox/1.0.0-rc.8/files/src/Detox.hx" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "file", ["detox","1.0.0-rc.8",["src","Detox.hx"]] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check it shows the source code for the file.
					})
					.andFinishWith( done );
			});
			it("Should render markdown files as HTML", function (done) {
				whenIVisit( "/p/detox/1.0.0-rc.8/files/README.md" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "file", ["detox","1.0.0-rc.8",["README.md"]] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check it shows the rendered markdown.
					})
					.andFinishWith( done );
			});
			it("Should show binary files size and a link to download it", function (done) {
				whenIVisit( "/p/hxssl/3.0.0-alpha/files/ndll/Linux64/hxssl.ndll" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "file", ["hxssl","3.0.0-alpha",["ndll","Linux64","hxssl.ndll"]] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check it shows the file name and download size.
					})
					.andFinishWith( done );
			});
		});

		describe("When I view a projects docs", {
			it("Should show the correct documentation for this version", function(done) {
				whenIVisit( "/p/detox/1.0.0-rc.8/doc/dtx.widget.Widget" )
					.onTheApp( haxelibSite )
					.itShouldLoad( ProjectController, "docs", ["detox","1.0.0-rc.8","dtx.widget.Widget"] )
					.itShouldReturn( ViewResult, function (result) {
						// TODO: Check it loads the correct view, documentation is rendered, etc.
					})
					.andFinishWith( done );
			});
		});
	}
}
