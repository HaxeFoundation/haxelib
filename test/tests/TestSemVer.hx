package tests;

import tools.haxelib.SemVer;

class TestSemVer extends haxe.unit.TestCase {

	public function testToString() {
		assertEquals( "0.1.2", new SemVer(0,1,2).toString() );

		// Release Tags
		assertEquals( "0.1.2-alpha", new SemVer(0,1,2,ALPHA).toString() );
		assertEquals( "0.1.2-beta", new SemVer(0,1,2,BETA).toString() );
		assertEquals( "0.1.2-rc", new SemVer(0,1,2,RC).toString() );

		// Release Tag Versions
		assertEquals( "0.1.2-alpha.0", new SemVer(0,1,2,ALPHA,0).toString() );
		assertEquals( "0.1.2-beta.0", new SemVer(0,1,2,BETA,0).toString() );
		assertEquals( "0.1.2-rc.0", new SemVer(0,1,2,RC,0).toString() );

		// Weird input
		assertEquals( "0.1.2", new SemVer(0,1,2,null,0).toString() );

		// Multiple characters
		assertEquals( "100.200.300-rc.400", new SemVer(0100,0200,0300,RC,0400).toString() );
	}

	public function testOfString() {
		// Normal
		assertEquals( "0.1.2", SemVer.ofString("0.1.2").toString() );
		assertEquals( "100.50.200", SemVer.ofString("0100.050.0200").toString() );

		// Release tags
		assertEquals( "0.1.2-alpha", SemVer.ofString("0.1.2-ALPHA").toString() );
		assertEquals( "0.1.2-alpha", SemVer.ofString("0.1.2-alpha").toString() );
		assertEquals( "0.1.2-beta", SemVer.ofString("0.1.2-beta").toString() );
		assertEquals( "0.1.2-rc", SemVer.ofString("0.1.2-rc").toString() );
		assertEquals( "0.1.2-rc.1", SemVer.ofString("0.1.2-rc.01").toString() );
		assertEquals( "<0.1.2-rc.1", SemVer.ofString("<0.1.2-rc.01").toString() );
		assertEquals( ">0.1.2-rc.1", SemVer.ofString(">0.1.2-rc.01").toString() );
		assertEquals( "<=0.1.2-rc.1", SemVer.ofString("<=0.1.2-rc.01").toString() );
	}

	public function testSpecificity() {
		assertTrue(SemVer.ofString("0.1.2-rc.01").isSpecific());
		assertFalse(SemVer.ofString(">0.1.2-rc.01").isSpecific());
	}

	public function testComparisons() {
		assertTrue( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.ofString("<=0.1.2-rc.01") ) );
		assertFalse( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.ofString("<0.1.2-rc.01") ) );
		assertFalse( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.ofString(">0.1.2-rc.01") ) );
		assertTrue( SemVer.ofString("0.1.2-rc").satisfies( SemVer.ofString(">0.1.2-rc.01") ) );

		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.ofString(">0.1.2") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.ofString("<1.0.4") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.ofString(">=0.9.3") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.ofString("<=1.0.9") ) );

		assertTrue( SemVer.ofString("1.0.0-rc").satisfies( SemVer.ofString(">1.0.0-alpha") ) );
		assertTrue( SemVer.ofString("1.0.0-rc").satisfies( SemVer.ofString(">1.0.0-beta") ) );
		assertFalse( SemVer.ofString("1.0.0-rc").satisfies( SemVer.ofString(">1.0.0-rc") ) );

		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.ofString(">1.0.0-rc") ) );
		assertFalse( SemVer.ofString("1.0.0-beta").satisfies( SemVer.ofString(">1.0.0-rc") ) );
		assertTrue( SemVer.ofString("1.0.0-beta").satisfies( SemVer.ofString(">1.0.0-alpha") ) );

		assertTrue( SemVer.ofString("0.1.3").satisfies( SemVer.ofString(">0.1.3-alpha") ) );
		assertFalse( SemVer.ofString("0.1.2-alpha.9").satisfies( SemVer.ofString("<=0.1.2-alpha.8") ) );

		assertTrue( SemVer.ofString("0.1.0-beta").satisfies( SemVer.ofString(">0.1.0-alpha") ) );
		assertFalse( SemVer.ofString("0.1.2-beta").satisfies( SemVer.ofString(">0.1.2-rc.1") ) );

		assertTrue( SemVer.ofString("1.0.0-alpha").satisfies( SemVer.ofString("<=1.0.0-alpha") ) );
		assertFalse( SemVer.ofString("1.0.0").satisfies( SemVer.ofString("<=1.0.0-alpha") ) );
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
	}

	function parseInvalid( str:String ) {
		return try {
			SemVer.ofString( str ).toString();
		} catch (e:String) {
			"invalid";
		}
	}

}
