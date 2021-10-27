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
            var r = haxelib(["why", "Bar", "Foo"]).result();
            assertSuccess(r);
            assertTrue(r.out.indexOf("This is directly required by your project") != -1);
        }
    }
}