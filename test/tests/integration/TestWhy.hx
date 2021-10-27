package tests.integration;

import haxe.io.*;
import haxelib.*;
import IntegrationTests.*;
using IntegrationTests;

class TestWhy extends IntegrationTests {
    function test():Void {
        {
            var r = haxelib(["dev", "Foo", Path.join([IntegrationTests.projectRoot, "test/libraries/libFoo"])]).result();
            assertSuccess(r);
        }
        {
            var r = haxelib(["dev", "Dep2", Path.join([IntegrationTests.projectRoot, "test/libraries/libDep2"])]).result();
            assertSuccess(r);
        }

        {
            var r = haxelib(["dev", "Dep", Path.join([IntegrationTests.projectRoot, "test/libraries/libDep"])]).result();
            assertSuccess(r);
        }

        {
            var r = haxelib(["why", "Bar", "Foo"]).result();
            assertSuccess(r);
            assertTrue(r.out.indexOf("This is directly required by your project") != -1);
        }
        {
            var r = haxelib(["why", "Foo", "Dep2"]).result();
            assertSuccess(r);
            assertTrue(r.out.indexOf("Dependency Structure") != -1);
            assertTrue(r.out.indexOf("Dep") != -1);
        }
    }
}