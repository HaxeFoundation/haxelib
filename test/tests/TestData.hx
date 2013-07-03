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
		assertFalse( readDataOkay(getJsonInfos([ "name" ])) ); // remove the field altogether

		// Description (optional)
		assertTrue( readDataOkay(getJsonInfos({ description: 'Some Description' })) );
		assertTrue( readDataOkay(getJsonInfos({ description: '' })) );
		assertTrue( readDataOkay(getJsonInfos({ description: null })) );

		// Licence
		assertTrue( readDataOkay(getJsonInfos({ license: 'BSD' })) );
		assertFalse( readDataOkay(getJsonInfos({ license: null })) );
		assertFalse( readDataOkay(getJsonInfos({ license: '' })) );
		assertFalse( readDataOkay(getJsonInfos({ license: 'CustomLicence' })) );
		assertFalse( readDataOkay(getJsonInfos([ "license" ])) ); // remove the field altogether

		// Contibutors
		assertFalse( readDataOkay(getJsonInfos({ contributors: [] })) );
		assertFalse( readDataOkay(getJsonInfos({ contributors: null })) );
		assertFalse( readDataOkay(getJsonInfos({ contributors: "jason" })) );
		assertTrue( readDataOkay(getJsonInfos({ contributors: ["jason"] })) );
		assertTrue( readDataOkay(getJsonInfos({ contributors: ["jason","juraj"] })) );
		assertFalse( readDataOkay(getJsonInfos([ "contributors" ])) ); // remove the field altogether

		// Version
		assertTrue( readDataOkay(getJsonInfos({ version: "0.1.2-rc.0" })) );
		assertFalse( readDataOkay(getJsonInfos({ version: "non-semver" })) );
		assertFalse( readDataOkay(getJsonInfos({ version: 0 })) );
		assertFalse( readDataOkay(getJsonInfos({ version: null })) );
		assertFalse( readDataOkay(getJsonInfos([ "version" ])) ); // remove the field altogether

		// Tags (optional)
		assertTrue( readDataOkay(getJsonInfos({ tags: ["tag1","tag2"] })) );
		assertTrue( readDataOkay(getJsonInfos({ tags: null })) );
		assertFalse( readDataOkay(getJsonInfos({ tags: "mytag" })) );

		// Dependencies (optional)
		assertTrue( readDataOkay(getJsonInfos({ dependencies: null })) );
		assertTrue( readDataOkay(getJsonInfos({ dependencies: { somelib:"" } })) );
		assertTrue( readDataOkay(getJsonInfos({ dependencies: { somelib:"1.3.0" } })) );
		assertFalse( readDataOkay(getJsonInfos({ dependencies: { somelib:"nonsemver" } })) );
		assertFalse( readDataOkay(getJsonInfos({ dependencies: { somelib:null } })) );
		assertFalse( readDataOkay(getJsonInfos({ dependencies: { somelib:0 } })) );
		assertFalse( readDataOkay(getJsonInfos({ dependencies: "somelib" })) );

		// ReleaseNote
		assertTrue( readDataOkay(getJsonInfos({ releasenote: "release" })) );
		assertFalse( readDataOkay(getJsonInfos({ releasenote: ["some","note"] })) );
		assertFalse( readDataOkay(getJsonInfos({ releasenote: null })) );
		assertFalse( readDataOkay(getJsonInfos([ "releasenote" ])) ); // remove the field altogether

		// ClassPath
		assertTrue( readDataOkay(getJsonInfos({ classPath: 'src/' })) );
		assertTrue( readDataOkay(getJsonInfos({ classPath: '' })) );
		assertTrue( readDataOkay(getJsonInfos({ classPath: null })) );
		assertFalse( readDataOkay(getJsonInfos({ classPath: ["src","othersrc"] })) );
	}
	
	public function testReadDataWithoutCheck() {
		assertEquals( "", Data.readData("bad json",false).project );
		assertEquals( "0.0.0", Data.readData("bad json",false).version );

		assertEquals( "mylib", Data.readData(getJsonInfos(),false).project );
		assertEquals( "0.1.2", Data.readData(getJsonInfos(),false).version );
		
		// Names
		assertEquals( "", Data.readData("{}",false).project );
		assertEquals( "", Data.readData(getJsonInfos({ name: null }),false).project );
		assertEquals( "", Data.readData(getJsonInfos({ name: '' }),false).project );
		assertEquals( "mylib", Data.readData(getJsonInfos({ name: 'mylib' }),false).project );
		assertEquals( "", Data.readData(getJsonInfos([ "name" ]),false).project ); // remove the field altogether

		// Description (optional)
		assertEquals( "Some Description", Data.readData(getJsonInfos({ description: 'Some Description' }),false).desc );
		assertEquals( "", Data.readData(getJsonInfos({ description: '' }),false).desc );
		assertEquals( "", Data.readData(getJsonInfos({ description: null }),false).desc );
		assertEquals( "", Data.readData(getJsonInfos([ "description" ]),false).desc ); // remove the field altogether

		// Licence
		assertEquals( "BSD", Data.readData(getJsonInfos({ license: 'BSD' }),false).license );
		assertEquals( "Unknown", Data.readData(getJsonInfos({ license: null }),false).license );
		assertEquals( "Unknown", Data.readData(getJsonInfos({ license: '' }),false).license );
		assertEquals( "CustomLicence", Data.readData(getJsonInfos({ license: 'CustomLicence' }),false).license );
		assertEquals( "Unknown", Data.readData(getJsonInfos([ "license" ]),false).license ); // remove the field altogether

		// Contibutors
		assertEquals( 0, Data.readData(getJsonInfos({ contributors: [] }),false).developers.length );
		assertEquals( 0, Data.readData(getJsonInfos({ contributors: null }),false).developers.length );
		assertEquals( 0, Data.readData(getJsonInfos({ contributors: "jason" }),false).developers.length );
		assertEquals( 1, Data.readData(getJsonInfos({ contributors: ["jason"] }),false).developers.length );
		assertEquals( 2, Data.readData(getJsonInfos({ contributors: ["jason","juraj"] }),false).developers.length );
		assertEquals( 0, Data.readData(getJsonInfos([ "contributors" ]),false).developers.length ); // remove the field altogether

		// Version
		assertEquals( "0.1.2-rc.0", Data.readData(getJsonInfos({ version: "0.1.2-rc.0" }),false).version );
		assertEquals( "0.0.0", Data.readData(getJsonInfos({ version: "non-semver" }),false).version );
		assertEquals( "0.0.0", Data.readData(getJsonInfos({ version: 0 }),false).version );
		assertEquals( "0.0.0", Data.readData(getJsonInfos({ version: null }),false).version );
		assertEquals( "0.0.0", Data.readData(getJsonInfos([ "version" ]),false).version ); // remove the field altogether

		// Tags (optional)
		assertEquals( 2, Data.readData(getJsonInfos({ tags: ["tag1","tag2"] }),false).tags.length );
		assertEquals( 0, Data.readData(getJsonInfos({ tags: null }),false).tags.length );
		assertEquals( 0, Data.readData(getJsonInfos({ tags: "mytag" }),false).tags.length );

		// Dependencies (optional)
		assertEquals( 0, Data.readData(getJsonInfos({ dependencies: null }),false).dependencies.length );
		assertEquals( "somelib", Data.readData(getJsonInfos({ dependencies: { somelib:"" } }),false).dependencies.first().project );
		assertEquals( "", Data.readData(getJsonInfos({ dependencies: { somelib:"" } }),false).dependencies.first().version );
		assertEquals( "1.3.0", Data.readData(getJsonInfos({ dependencies: { somelib:"1.3.0" } }),false).dependencies.first().version );
		assertEquals( "", Data.readData(getJsonInfos({ dependencies: { somelib:"nonsemver" } }),false).dependencies.first().version );
		assertEquals( "", Data.readData(getJsonInfos({ dependencies: { somelib:null } }),false).dependencies.first().version );
		assertEquals( "", Data.readData(getJsonInfos({ dependencies: { somelib:0 } }),false).dependencies.first().version );

		// ReleaseNote
		assertEquals( "release", Data.readData(getJsonInfos({ releasenote: "release" }),false).versionComments );
		assertEquals( "", Data.readData(getJsonInfos({ releasenote: null }),false).versionComments );
		assertEquals( "", Data.readData(getJsonInfos([ "releasenote" ]),false).versionComments ); // remove the field altogether

		// ClassPath
		assertEquals( "src", Data.readData(getJsonInfos({ classPath: 'src' }), false).classPath );
		assertEquals( "", Data.readData(getJsonInfos({ classPath: '' }), false).classPath );
		assertEquals( "", Data.readData(getJsonInfos({ classPath: null }), false).classPath );
	}

	function readDataOkay( json ) {
		try { 
			Data.readData( json,true ); 
			return true; 
		} 
		catch(e:String) return false;
	}

	function getJsonInfos( ?remove:Array<String>, ?change:Dynamic ) {
		var infos = {
			name: "mylib",
			license: "MIT",
			contributors: ["jason"],
			version: "0.1.2",
			releasenote: ""
		};
		if (change != null) {
			for ( name in Reflect.fields(change) ) {
				var value = Reflect.field( change, name );
				Reflect.setField( infos, name, value );
			}
		}
		if (remove != null) {
			for ( f in remove ) 
				Reflect.deleteField( infos, f );
		}
		return Json.stringify(infos);
	}

}