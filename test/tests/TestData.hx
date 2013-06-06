package tests;

import haxe.ds.StringMap;
import haxe.Json;
import tools.haxelib.Data;
using StringTools;

class TestData extends haxe.unit.TestCase {
	
	public function testSafe() {
		assertEquals( "abc", checkSafe("abc") );
		assertEquals( "bean,hx", checkSafe("bean.hx") );
		assertEquals( "1,2,3", checkSafe("1.2.3") );
		assertEquals( "_-,123", checkSafe("_-.123") );
		assertEquals( "invalid", checkSafe("1,2") );
		assertEquals( "invalid", checkSafe("space ") );
		assertEquals( "invalid", checkSafe("\t") );
		assertEquals( "invalid", checkSafe("\n") );
		assertEquals( "invalid", checkSafe("") );
	}

	function checkSafe( str:String ) {
		return try {
			Data.safe( str );
		} catch (e:String) "invalid";
	}
	
	public function testUnsafe() {
		assertEquals( "abc", Data.unsafe("abc") );
		assertEquals( "1.2.3", Data.unsafe("1,2,3") );
		assertEquals( "", Data.unsafe("") );
	}
	
	public function testFileName() {
		assertEquals( "lib-1,2,3.zip", checkFileName("lib","1.2.3") );
		assertEquals( "lib-1,2,3-rc,3.zip", checkFileName("lib","1.2.3-rc.3") );
		assertEquals( "invalid", checkFileName("lib",",") );
		assertEquals( "invalid", checkFileName(",","version") );
		assertEquals( "invalid", checkFileName("","version") );
	}

	function checkFileName( lib, ver ) {
		return try {
			Data.fileName( lib, ver );
		} catch (e:String) "invalid";
	}
	
	public function testLocateBasePath() {
		assertEquals( "", "" );
	}
	
	public function testReadDoc() {
		assertEquals( "", "" );
	}
	
	public function testReadInfos() {
		assertEquals( "", "" );
	}
	
	public function testReadDataWithCheck() {
		assertFalse( readDataOkay("bad json") );

		assertTrue( readDataOkay(getJsonInfos()) );
		
		// Names
		assertFalse( readDataOkay("{}") );
		assertFalse( readDataOkay(getJsonInfos({ name: null })) );
		assertFalse( readDataOkay(getJsonInfos({ name: '' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: 'haxe' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: 'haXe' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: 'all' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: 'something.zip' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: 'something.hxml' })) );
		assertFalse( readDataOkay(getJsonInfos({ name: '12' })) );
		assertTrue( readDataOkay(getJsonInfos({ name: 'mylib' })) );

		// Licence
		assertTrue( readDataOkay(getJsonInfos({ license: 'BSD' })) );
		assertFalse( readDataOkay(getJsonInfos({ license: null })) );
		assertFalse( readDataOkay(getJsonInfos({ license: '' })) );
		assertFalse( readDataOkay(getJsonInfos({ license: 'CustomLicence' })) );

		// Contibutors
		assertFalse( readDataOkay(getJsonInfos({ contributors: [] })) );
		assertFalse( readDataOkay(getJsonInfos({ contributors: null })) );
		assertFalse( readDataOkay(getJsonInfos({ contributors: "jason" })) );
		assertTrue( readDataOkay(getJsonInfos({ contributors: ["jason"] })) );
		assertTrue( readDataOkay(getJsonInfos({ contributors: ["jason","juraj"] })) );

		// Versions
		assertTrue( readDataOkay(getJsonInfos({ version: "0.0.0-rc.0" })) );
		assertFalse( readDataOkay(getJsonInfos({ version: "non-semver" })) );
		assertFalse( readDataOkay(getJsonInfos({ version: null })) );

		// Tags (optional)
		assertTrue( readDataOkay(getJsonInfos({ tags: ["tag1","tag2"] })) );
		assertTrue( readDataOkay(getJsonInfos({ tags: null })) );
		assertFalse( readDataOkay(getJsonInfos({ tags: "mytag" })) );

		// Dependencies (optional)
		assertTrue( readDataOkay(getJsonInfos({ dependencies: null })) );
		assertTrue( readDataOkay(getJsonInfos({ dependencies: { somelib:"somever" } })) );
		assertFalse( readDataOkay(getJsonInfos({ dependencies: "somelib" })) );

		// ReleaseNote
		assertTrue( readDataOkay(getJsonInfos({ releasenote: "release" })) );
		assertFalse( readDataOkay(getJsonInfos({ releasenote: ["some","note"] })) );
		assertFalse( readDataOkay(getJsonInfos({ releasenote: null })) );
	}
	
	public function testReadDataWithoutCheck() {
		assertEquals( "", "" );
	}

	function readDataOkay( json ) {
		try { 
			Data.readData( json,true ); 
			return true; 
		} 
		catch(e:String) return false;
	}

	function getJsonInfos(?change:Dynamic) {
		var infos = {
			name: "mylib",
			license: "MIT",
			contributors: ["jason"],
			version: "0.1.2",
			tags: [],
			dependencies: {},
			releasenote: ""
		};
		if (change != null) {
			for ( name in Reflect.fields(change) ) {
				var value = Reflect.field( change, name );
				Reflect.setField( infos, name, value );
			}
		}
		return Json.stringify(infos);
	}

}