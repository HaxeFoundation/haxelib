package website.controller;

import website.controller.*;
import ufront.web.result.*;
import website.Server;

// These imports are common for our various test-suite tools.
import buddy.*;
import mockatoo.Mockatoo.*;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import utest.Assert;
using buddy.Should;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;

class RSSControllerTest extends BuddySuite {
	public function new() {

		var haxelibSite = WebsiteTests.getTestApp();

		describe("When I try to view the RSS feed", {
			it("Should give me some valid XML with the latest updates", function (done) {
				whenIVisit( "/rss" )
					.onTheApp( haxelibSite )
					.itShouldLoad( RSSController, "rss", [{number:null}] )
					.itShouldReturn( ContentResult, function (result) {
						result.contentType.should.be( "text/xml" );
						var rss = Xml.parse( result.content );
					})
					.andFinishWith( done );
			});
			it("Should let me set the number of entries to include", function (done) {
				whenIVisit( "/rss" )
				.withTheQueryParams([ "number"=>"3" ])
				.onTheApp( haxelibSite )
				.itShouldLoad( RSSController, "rss", [{number:3}] )
				.itShouldReturn( ContentResult, function (result) {
					result.contentType.should.be( "text/xml" );
					var rss = Xml.parse( result.content );
					// TODO: check that 3 results were loaded.
				})
				.andFinishWith( done );
			});
		});
	}
}