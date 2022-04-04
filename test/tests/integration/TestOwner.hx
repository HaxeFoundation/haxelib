package tests.integration;

class TestOwner extends IntegrationTests {
    function test():Void {
        {
            final r = haxelib(["register", deepAuthor.user, deepAuthor.email, deepAuthor.fullname, deepAuthor.pw, deepAuthor.pw]).result();
            assertSuccess(r);
        }
        {
            final r = haxelib(["register", anotherGuy.user, anotherGuy.email, anotherGuy.fullname, anotherGuy.pw, anotherGuy.pw]).result();
            assertSuccess(r);
        }
        {
            final r = haxelib(["register", foo.user, foo.email, foo.fullname, foo.pw, foo.pw]).result();
            assertSuccess(r);
        }


        /*
            Only the owner can submit the first version.
         */

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertFail(r);
        }

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep.zip"]), deepAuthor.user, deepAuthor.pw]).result();
            assertSuccess(r);
        }

        /*
            Only the owner can change ownership.
        */

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep2.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertFail(r);
        }

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep2.zip"]), deepAuthor.user, deepAuthor.pw]).result();
            assertSuccess(r);
        }

        /*
            Only the owner can change contributors.
        */

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep3.zip"]), foo.user, foo.pw]).result();
            assertFail(r);
        }

        {
            final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libDeep3.zip"]), anotherGuy.user, anotherGuy.pw]).result();
            assertSuccess(r);
        }
    }
}
