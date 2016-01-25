package tests;

import haxelib.SemVer;

class TestSemVer extends TestBase {
	static function make(major, minor, patch, ?preview, ?previewNum):SemVer {
		return {
			major : major,
			minor : minor,
			patch : patch,
			preview : preview,
			previewNum : previewNum
		};
	}
	public function testToString() {
		assertEquals( "0.1.2", make(0,1,2) );

		// Release Tags
		assertEquals( "0.1.2-alpha", make(0,1,2,ALPHA) );
		assertEquals( "0.1.2-beta", make(0,1,2,BETA) );
		assertEquals( "0.1.2-rc", make(0,1,2,RC) );

		// Release Tag Versions
		assertEquals( "0.1.2-alpha.0", make(0,1,2,ALPHA,0) );
		assertEquals( "0.1.2-beta.0", make(0,1,2,BETA,0) );
		assertEquals( "0.1.2-rc.0", make(0,1,2,RC,0) );

		// Weird input
		assertEquals( "0.1.2", make(0,1,2,null,0) );

		// Multiple characters
		assertEquals( "100.200.300-rc.400", make(100,200,300,RC,400) );
	}

	public function testOfString() {
		// Normal
		assertEquals( "0.1.2", (SemVer.ofString("0.1.2").data : SemVer));
		assertEquals( "100.50.200", (SemVer.ofString("100.50.200").data : SemVer));

		// Release tags
		assertEquals( "0.1.2-alpha", (SemVer.ofString("0.1.2-ALPHA").data : SemVer));
		assertEquals( "0.1.2-alpha", (SemVer.ofString("0.1.2-alpha").data : SemVer));
		assertEquals( "0.1.2-beta", (SemVer.ofString("0.1.2-beta").data : SemVer));
		assertEquals( "0.1.2-rc", (SemVer.ofString("0.1.2-rc").data : SemVer));
		assertEquals( "0.1.2-rc.1", (SemVer.ofString("0.1.2-rc.1").data : SemVer));
	}

	public function testOfStringInvalid() {
		assertEquals( "invalid", parseInvalid(null) );
		assertEquals( "invalid", parseInvalid("") );
		assertEquals( "invalid", parseInvalid("1") );
		assertEquals( "invalid", parseInvalid("1.1") );
		assertEquals( "invalid", parseInvalid("1.2.a") );
		assertEquals( "invalid", parseInvalid("a.b.c") );
		assertEquals( "invalid", parseInvalid("1.2.3-") );
		assertEquals( "invalid", parseInvalid("1.2.3-rc.") );
		assertEquals( "invalid", parseInvalid("1.2.3--rc.1") );
		assertEquals( "invalid", parseInvalid("1.2.3-othertag") );
		assertEquals( "invalid", parseInvalid("1.2.3-othertag.1") );
		assertEquals( "invalid", parseInvalid("10.050.02"));
		assertEquals( "invalid", parseInvalid("10.50.2-rc.01"));
	}

	function parseInvalid( str:String ) {
		return try {
			(SemVer.ofString( str ) : String);
		} catch (e:String) {
			"invalid";
		}
	}

}