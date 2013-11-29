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
		assertEquals( "5.1.2-beta", SemVer.ofString("5.1.2-bEtA").toString() );
		assertEquals( "0.1.2-beta", SemVer.ofString("0.1.2-beta").toString() );
		assertEquals( "0.1.2-rc", SemVer.ofString("0.1.2-rc").toString() );
		assertEquals( "0.1.2-rc.1", SemVer.ofString("0.1.2-rc.01").toString() );
	}

	public function testComparisons() {
		// Simple constraints
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">0.1.2") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("<1.0.4") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">=0.9.3") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("<=1.0.9") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("1.0.0") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("=1.0.0") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("!=1.0.9") ) );
		assertFalse( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("!=1.0.0") ) );

		// More parts
		assertTrue( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.constraintOfString("<=0.1.2-rc.01") ) );
		assertFalse( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.constraintOfString("<0.1.2-rc.01") ) );
		assertFalse( SemVer.ofString("0.1.2-rc.01").satisfies( SemVer.constraintOfString(">0.1.2-rc.01") ) );
		assertTrue( SemVer.ofString("0.1.2-rc").satisfies( SemVer.constraintOfString(">0.1.2-rc.01") ) );

		// Release tags
		assertTrue( SemVer.ofString("1.0.0-rc").satisfies( SemVer.constraintOfString(">1.0.0-alpha") ) );
		assertTrue( SemVer.ofString("1.0.0-rc").satisfies( SemVer.constraintOfString(">1.0.0-beta") ) );
		assertFalse( SemVer.ofString("1.0.0-rc").satisfies( SemVer.constraintOfString(">1.0.0-rc") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">1.0.0-rc") ) );
		assertFalse( SemVer.ofString("1.0.0-beta").satisfies( SemVer.constraintOfString(">1.0.0-rc") ) );
		assertTrue( SemVer.ofString("1.0.0-beta").satisfies( SemVer.constraintOfString(">1.0.0-alpha") ) );
		assertTrue( SemVer.ofString("0.1.3").satisfies( SemVer.constraintOfString(">0.1.3-alpha") ) );
		assertFalse( SemVer.ofString("0.1.2-alpha.9").satisfies( SemVer.constraintOfString("<=0.1.2-alpha.8") ) );
		assertTrue( SemVer.ofString("0.1.0-beta").satisfies( SemVer.constraintOfString(">0.1.0-alpha") ) );
		assertFalse( SemVer.ofString("0.1.2-beta").satisfies( SemVer.constraintOfString(">0.1.2-rc.1") ) );
		assertTrue( SemVer.ofString("1.0.0-alpha").satisfies( SemVer.constraintOfString("<=1.0.0-alpha") ) );
		assertFalse( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString("<=1.0.0-alpha") ) );
	}

	public function testConstraintCreation() {
		// Simple
		assertEquals( "Gt", Type.enumConstructor( SemVer.constraintOfString(">0.1.0-alpha") ) );
		assertEquals( "Lt", Type.enumConstructor( SemVer.constraintOfString("<0.1.0-alpha") ) );
		assertEquals( "Gte", Type.enumConstructor( SemVer.constraintOfString(">=0.1.0-alpha") ) );
		assertEquals( "Lte", Type.enumConstructor( SemVer.constraintOfString("<=0.1.0-alpha") ) );
		assertEquals( "Eq", Type.enumConstructor( SemVer.constraintOfString("0.1.0-alpha") ) );
		assertEquals( "Eq", Type.enumConstructor( SemVer.constraintOfString("=0.1.0-alpha") ) );

		// Compound
		assertEquals( "And", Type.enumConstructor( SemVer.constraintOfString(">0.1.0-alpha && >2.0.1") ) );
		assertEquals( "Or", Type.enumConstructor( SemVer.constraintOfString(">0.1.0-alpha || >2.0.1") ) );
	}

	public function testCompoundComparisons() {
		// AND
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">0.1.0-alpha") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">0.1.0-alpha && <2.0.1") ) );
		assertFalse( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">0.1.0-alpha && >2.0.1") ) );
		assertTrue( SemVer.ofString("1.0.0").satisfies( SemVer.constraintOfString(">0.1.0-alpha && <=1.0.0") ) );
		assertTrue( SemVer.ofString("2.0.0").satisfies( SemVer.constraintOfString(">0.1.0-alpha && <=2.0.0") ) );
		assertTrue( SemVer.ofString("0.8.4-alpha").satisfies( SemVer.constraintOfString(">0.4.6 && <=0.9.4") ) );
		assertFalse( SemVer.ofString("0.8.4-alpha").satisfies( SemVer.constraintOfString(">=0.8.4 && <=0.9.4") ) );

		// OR
		assertTrue( SemVer.ofString("2.3.4").satisfies( SemVer.constraintOfString("1.2.3 || 2.3.4") ) );
		assertFalse( SemVer.ofString("2.3.5").satisfies( SemVer.constraintOfString("1.2.3 || 2.3.4") ) );
		assertTrue( SemVer.ofString("1.2.3").satisfies( SemVer.constraintOfString("1.2.3 || 2.3.4") ) );
		assertFalse( SemVer.ofString("1.9.12-rc.2").satisfies( SemVer.constraintOfString(">2.1.4 || =2.2.0") ) );
		assertFalse( SemVer.ofString("2.1.3").satisfies( SemVer.constraintOfString(">2.1.4 || =2.2.0") ) );
		assertFalse( SemVer.ofString("2.1.4").satisfies( SemVer.constraintOfString(">2.1.4 || =2.2.0") ) );
		assertTrue( SemVer.ofString("2.1.5").satisfies( SemVer.constraintOfString(">2.1.4 || =2.2.0") ) );

		assertFalse( SemVer.ofString("1.9.8-alpha").satisfies( SemVer.constraintOfString(">2.1.4 || 1.9.8") ) );
		assertTrue( SemVer.ofString("1.9.8").satisfies( SemVer.constraintOfString(">2.1.4 || 1.9.8") ) );
	}

	public function testOfSemVerInvalid() {
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
		assertEquals( "invalid", parseInvalid(">1.2.3") );
		assertEquals( "invalid", parseInvalid("<=1.2.3") );
		assertEquals( "invalid", parseInvalid("1.2.3 || 2.3.4") );
	}

	public function testOfSemConstraintInvalid() {
		assertEquals( "invalid", parseConstraintInvalid("1.2.3 || 2.3") );
		assertEquals( "invalid", parseConstraintInvalid("1.2.3 ||") );
		assertEquals( "invalid", parseConstraintInvalid("1.2.3 & 1.5.4") );
		assertEquals( "invalid", parseConstraintInvalid("1.2.3 &&") );
		assertEquals( "invalid", parseConstraintInvalid("1.2.3 && 1.5") );
		assertEquals( "invalid", parseConstraintInvalid("1.3 && 1.5.2") );
	}

	function parseInvalid( str:String ) {
		return try {
			SemVer.ofString( str ).toString();
		} catch (e:String) {
			"invalid";
		}
	}

	function parseConstraintInvalid( str:String ) {
		return try {
			Type.enumParameters( SemVer.constraintOfString( str ) )[0];
		} catch (e:String) {
			"invalid";
		}
	}
}
