package tests.integration;

import haxe.io.*;
import IntegrationTests.*;
using IntegrationTests;

class TestOwner extends IntegrationTests {
    function test():Void {
        {
            var r = haxelib(["register", deepAuthor.user, deepAuthor.email, deepAuthor.fullname, deepAuthor.pw, deepAuthor.pw]).result();
            assertSuccess(r);
        }
        {
            var r = haxelib(["register", anotherGuy.user, anotherGuy.email, anotherGuy.fullname, anotherGuy.pw, anotherGuy.pw]).result();
            assertSuccess(r);
        }
        {
            var r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
            assertSuccess(r);
        }


        /*
            Only the owner can submit the first version.
         */

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertFail(r);
        }

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep.zip"]), deepAuthor.user, deepAuthor.pw]).result();
            assertSuccess(r);
        }

        /*
            Only the owner can change ownership.
        */

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep2.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertFail(r);
        }

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep2.zip"]), deepAuthor.user, deepAuthor.pw]).result();
            assertSuccess(r);
        }

        /*
            Only the owner can change contributors.
        */

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep3.zip"]), foo.user, foo.pw]).result();
            assertFail(r);
        }

        {
            var r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep3.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertSuccess(r);
        }
    }
}