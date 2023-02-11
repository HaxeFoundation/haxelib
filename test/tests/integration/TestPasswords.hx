package tests.integration;

import haxelib.server.Hashing;
import haxelib.server.SiteDb;

class TestPasswords extends IntegrationTests {

	/**
		Simulates an old user account whose md5 hash was rehashed with argon2id.
	**/
	function createOldUserAccount(data:{user:String, email:String, fullname:String, pw:String}) {
		SiteDb.init();
		final user = new User();
		user.name = data.user;
		user.fullname = data.fullname;
		user.email = data.email;
		final salt = Hashing.generateSalt();
		user.pass = Hashing.hash(haxe.crypto.Md5.encode(data.pw), salt);
		user.salt = salt;
		user.hashmethod = Md5;
		user.insert();
		SiteDb.cleanup();
	}

	function getUser(name:String) {
		SiteDb.init();
		final user = User.manager.search($name == name).first();
		SiteDb.cleanup();
		return user;
	}

	public function testHashUpdate() {
		createOldUserAccount(bar);

		// submitting should work with the password
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]),
			bar.pw
		]).result();
		assertSuccess(r);

		// after submission, should have updated to new hash properly
		final user = getUser(bar.user);

		// hash method should be updated, as well as the hash itself
		assertEquals(Argon2id, user.hashmethod);
		assertEquals(Hashing.hash(bar.pw, user.salt), user.pass);

		// submitting should continue to work with the same password
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]),
			bar.pw
		]).result();
		assertSuccess(r);
	}

	public function testFailedSubmit() {
		createOldUserAccount(bar);

		// attempting to submit with incorrect password should make no difference
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]),
		],"incorrect password\nincorrect password\nincorrect password\nincorrect password\nincorrect password\n").result();
		assertFail(r);
		assertEquals("Error: Failed to input correct password", r.err.trim());

		// after failed submission, the account should not have changed
		final user = getUser(bar.user);

		// hash method and hash should remain the same
		assertEquals(Md5, user.hashmethod);
		assertEquals(Hashing.hash(haxe.crypto.Md5.encode(bar.pw), user.salt), user.pass);
	}

}
