package tests;

import haxe.ds.StringMap;
import haxe.Json;
import haxe.io.*;
import haxe.zip.*;
import sys.io.*;
import haxelib.Data;
import haxelib.ProjectName;
using StringTools;

class TestData extends TestBase {

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
		var zip = Reader.readZip(new BytesInput(File.getBytes("package.zip")));
		assertEquals( "", Data.locateBasePath(zip) );

		var zip = Reader.readZip(new BytesInput(File.getBytes("test/libraries/libDeep.zip")));
		assertEquals( "libDeep/", Data.locateBasePath(zip) );
	}

	public function testReadDoc() {
		var zip = Reader.readZip(new BytesInput(File.getBytes("package.zip")));
		assertEquals( null, Data.readDoc(zip) );

		//TODO
	}

	public function testReadDataFromZip() {
		var zip = Reader.readZip(new BytesInput(File.getBytes("package.zip")));
		var info = Data.readDataFromZip(zip, CheckData);
		assertEquals( "haxelib", info.name );
		assertEquals( "MIT", info.license );

		var zip = Reader.readZip(new BytesInput(File.getBytes("test/libraries/libDeep.zip")));
		var info = Data.readDataFromZip(zip, CheckData);
		assertEquals( "Deep", info.name );
		assertEquals( "http://example.org", info.url );
		assertEquals( "Public", info.license );
		assertEquals( "deep, test", info.tags.join(", ") );
		assertEquals( "This project's zip contains a folder that holds the lib.", info.description );
		assertEquals( "1.0.0", info.version );
		assertEquals( "N/A", info.releasenote );
		assertEquals( "DeepAuthor, AnotherGuy", info.contributors.join(", ") );
	}

	public function testCheckClassPath() {
		var zip = Reader.readZip(new BytesInput(File.getBytes("package.zip")));
		var info = Data.readDataFromZip(zip, CheckData);
		var ok:Dynamic = try {
			Data.checkClassPath(zip,info);
			true;
		} catch (e:Dynamic) {
			e;
		}
		assertEquals( ok, true );

		var zip = Reader.readZip(new BytesInput(File.getBytes("test/libraries/libDeep.zip")));
		var info = Data.readDataFromZip(zip, CheckData);
		var ok:Dynamic = try {
			Data.checkClassPath(zip,info);
			true;
		} catch (e:Dynamic) {
			e;
		}
		assertEquals( ok, true );
	}

	public function testCheckDocumentation() {
		var results = [
			"DocumentationFiles" => true,
			"BadMetaJson" => false,
			"BadMetaJson2" => false,
			"BadDefineJson" => false
		];

		for (r in results.keys()) {
			var zip = Reader.readZip(new BytesInput(File.getBytes('test/libraries/lib$r.zip')));
			var info = Data.readDataFromZip(zip, CheckData);

			try {
				Data.checkDocumentation(zip,info);
				assertTrue(results.get(r));
			} catch (e:Dynamic) {
				assertFalse(results.get(r));
			}
		}
	}

	public function testCheckDisallowedFiles() {
		final cases = [
			{
				zip: {
					final list = new List();
					list.add({ fileName: ".git/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: "root/.git/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: ".svn/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: "root/.svn/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: ".hg/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: "root/.hg/"});
					list;
				},
				valid: false
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: ".github/"});
					list;
				},
				valid: true
			},
			{
				zip: {
					final list = new List();
					list.add({fileName: "root/.github/"});
					list;
				},
				valid: true
			},
		];

		for (testCase in cases) {
			try {
				Data.checkDisallowedFiles(testCase.zip);
				assertTrue(testCase.valid);
			} catch (e:Dynamic) {
				assertFalse(testCase.valid);
			}
		}
	}

	public function testReadDataWithDataCheck() {
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
		assertFalse(readDataOkay(getJsonInfos({license: 'Unknown'})));
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
		assertTrue( readDataOkay(getJsonInfos({ dependencies: { somelib: "" } })) );

		assertTrue( readDataOkay(getJsonInfos({ dependencies: { somelib:"1.3.0" } }) ));
		assertFalse( readDataOkay(getJsonInfos({ dependencies: { somelib: "nonsemver" }})) );
		assertFalse(readDataOkay(getJsonInfos({dependencies: {somelib: "git"}})));
		assertFalse(readDataOkay(getJsonInfos({dependencies: {somelib: "git:https://some.url"}})));

		assertFalse( readDataOkay(getJsonInfos({ dependencies: { somelib: 0 } })) );
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
		assertEquals(ProjectName.DEFAULT, Data.readData("bad json", NoCheck).name);
		assertEquals("0.0.0", Data.readData("bad json", NoCheck).version);

		assertEquals("mylib", Data.readData(getJsonInfos(), NoCheck).name);
		assertEquals("0.1.2", Data.readData(getJsonInfos(), NoCheck).version);

		// Names
		assertEquals(ProjectName.DEFAULT, Data.readData("{}", NoCheck).name);
		assertEquals(ProjectName.DEFAULT, Data.readData(getJsonInfos({name: null}), NoCheck).name);
		assertEquals(ProjectName.DEFAULT, Data.readData(getJsonInfos({name: ''}), NoCheck).name);
		assertEquals("mylib", Data.readData(getJsonInfos({name: 'mylib'}), NoCheck).name);
		assertEquals(ProjectName.DEFAULT, Data.readData(getJsonInfos(["name"]), NoCheck).name); // remove the field altogether

		// Description (optional)
		assertEquals("Some Description", Data.readData(getJsonInfos({description: 'Some Description'}), NoCheck).description);
		assertEquals("", Data.readData(getJsonInfos({description: ''}), NoCheck).description);
		assertEquals("", Data.readData(getJsonInfos({description: null}), NoCheck).description);
		assertEquals("", Data.readData(getJsonInfos(["description"]), NoCheck).description); // remove the field altogether

		// Licence
		assertEquals("BSD", Data.readData(getJsonInfos({license: 'BSD'}), NoCheck).license);
		assertEquals("Unknown", Data.readData(getJsonInfos({license: null}), NoCheck).license);
		assertEquals("Unknown", Data.readData(getJsonInfos({license: ''}), NoCheck).license);
		assertEquals("CustomLicence", Data.readData(getJsonInfos({license: 'CustomLicence'}), NoCheck).license);
		assertEquals("Unknown", Data.readData(getJsonInfos(["license"]), NoCheck).license); // remove the field altogether

		// Contibutors
		assertEquals(0, Data.readData(getJsonInfos({contributors: []}), NoCheck).contributors.length);
		assertEquals(0, Data.readData(getJsonInfos({contributors: null}), NoCheck).contributors.length);
		assertEquals(0, Data.readData(getJsonInfos({contributors: "jason"}), NoCheck).contributors.length);
		assertEquals(1, Data.readData(getJsonInfos({contributors: ["jason"]}), NoCheck).contributors.length);
		assertEquals(2, Data.readData(getJsonInfos({contributors: ["jason", "juraj"]}), NoCheck).contributors.length);
		assertEquals(0, Data.readData(getJsonInfos(["contributors"]), NoCheck).contributors.length); // remove the field altogether

		// Version
		assertEquals("0.1.2-rc.0", Data.readData(getJsonInfos({version: "0.1.2-rc.0"}), NoCheck).version);
		assertEquals("0.0.0", Data.readData(getJsonInfos({version: "non-semver"}), NoCheck).version);
		assertEquals("0.0.0", Data.readData(getJsonInfos({version: 0}), NoCheck).version);
		assertEquals("0.0.0", Data.readData(getJsonInfos({version: null}), NoCheck).version);
		assertEquals("0.0.0", Data.readData(getJsonInfos(["version"]), NoCheck).version); // remove the field altogether

		// Tags (optional)
		assertEquals(2, Data.readData(getJsonInfos({tags: ["tag1", "tag2"]}), NoCheck).tags.length);
		assertEquals(0, Data.readData(getJsonInfos({tags: null}), NoCheck).tags.length);
		assertEquals(0, Data.readData(getJsonInfos({tags: "mytag"}), NoCheck).tags.length);

		// Dependencies (optional)
		function getFirstDependency(dependencies:Dynamic) {
			final dependencies = Data.readData(getJsonInfos({dependencies: dependencies}), NoCheck).dependencies;
			for (name => version in dependencies)
				return {name: name, version:version};
			return null;
		}

		assertEquals(0, Lambda.count(Data.readData(getJsonInfos({dependencies: null}), NoCheck).dependencies));
		assertEquals("somelib", getFirstDependency({somelib: ""}).name);
		assertEquals("", getFirstDependency({somelib: ""}).version);
		assertEquals("1.3.0", getFirstDependency({somelib: "1.3.0"}).version);
		assertEquals("", getFirstDependency({somelib: "nonsemver"}).version);
		assertEquals("", getFirstDependency({somelib: null}).version);
		assertEquals("", getFirstDependency({somelib: 0}).version);
		assertEquals("git", getFirstDependency({somelib: "git"}).version);
		assertEquals("git:https://some.url#branch", getFirstDependency({somelib: "git:https://some.url#branch"}).version);

		// ReleaseNote
		assertEquals("release", Data.readData(getJsonInfos({releasenote: "release"}), NoCheck).releasenote);
		assertEquals("", Data.readData(getJsonInfos({releasenote: null}), NoCheck).releasenote);
		assertEquals("", Data.readData(getJsonInfos(["releasenote"]), NoCheck).releasenote); // remove the field altogether

		// ClassPath
		assertEquals("src", Data.readData(getJsonInfos({classPath: 'src'}), NoCheck).classPath);
		assertEquals("", Data.readData(getJsonInfos({classPath: ''}), NoCheck).classPath);
		assertEquals("", Data.readData(getJsonInfos({classPath: null}), NoCheck).classPath);
	}

	function testAliasCheck() {
		// same one
		final project = ProjectName.ofString("project");
		assertEquals(project, ProjectName.getCorrectOrAlias(project, project));

		// differently capitalized, original is returned
		final projectA = ProjectName.ofString("project");
		final projectB = ProjectName.ofString("PROJECT");
		assertEquals(projectA, ProjectName.getCorrectOrAlias(projectA, projectB));

		// completely different, alias is returned
		final project = ProjectName.ofString("project");
		final alias = ProjectName.ofString("alias");
		assertEquals(alias, ProjectName.getCorrectOrAlias(project, alias));
	}

	function readDataOkay( json ) {
		try {
			Data.readData(json, CheckData);
			return true;
		}
		catch (e:String) {
			return false;
		}
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
