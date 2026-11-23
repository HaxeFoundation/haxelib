package tests.integration;

import haxe.crypto.Md5;
import haxelib.server.Hashing;
import haxelib.server.SiteDb;

class TestPasswordHashing extends IntegrationTests {

	override function setup() {
		super.setup();
		SiteDb.init();
	}

	override function tearDown() {
		SiteDb.cleanup();
		super.tearDown();
	}

	/**
		Inserts users that only have the legacy md5 `pass` field set
	**/
	function insertLegacyUsers(users:Array<{
		user:String,
		email:String,
		fullname:String,
		pw:String
	}>) {
		for (data in users) {
			final user = new User();
			user.name = data.user;
			user.fullname = data.fullname;
			user.email = data.email;
			user.pass = Md5.encode(data.pw);
			user.pass2 = null;
			user.insert();
		}
	}

	static function refresh() {
		sys.db.Manager.cleanup();
	}

	function testRegisterKeepsLegacyPassword() {
		final r = haxelib(["register", bar.user, bar.email, bar.fullname, bar.pw, bar.pw]).result();
		assertSuccess(r);
		refresh();

		final barAccount = User.manager.search($name == bar.user).first();
		assertTrue(Hashing.verify(barAccount.pass2, Md5.encode(bar.pw)));
		// legacy field must be set so servers that only check `pass` don't accept an empty password
		assertEquals(Md5.encode(bar.pw), barAccount.pass);
	}

	function testRehashLegacyPassword() {
		insertLegacyUsers([bar]);
		refresh();
		final wrongPassword = "wrong";

		final barAccount = User.manager.search($name == bar.user).first();
		// not yet rehashed
		assertEquals(null, barAccount.pass2);
		// md5 entry still exists
		assertEquals(Md5.encode(bar.pw), barAccount.pass);
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]),
			wrongPassword,
			wrongPassword,
			wrongPassword]).result();
		assertFail(r);
		refresh();

		final barAccount = User.manager.search($name == bar.user).first();
		// user still unmigrated after failed login
		assertEquals(null, barAccount.pass2);
		// md5 entry still exists
		assertEquals(Md5.encode(bar.pw), barAccount.pass);

		final r = haxelib(["submit", Path.join([IntegrationTests.projectRoot, "test/libraries/libBar.zip"]), bar.pw]).result();
		assertSuccess(r);
		refresh();

		// successful login should have migrated the user
		final barAccount = User.manager.search($name == bar.user).first();
		assertTrue(Hashing.verify(barAccount.pass2, Md5.encode(bar.pw)));
		// md5 entry still exists
		assertEquals(Md5.encode(bar.pw), barAccount.pass);

		// subsequent invalid login still fails
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]),
			wrongPassword,
			wrongPassword,
			wrongPassword]).result();
		assertFail(r);
		refresh();

		// subsequent valid login succeeds
		final r = haxelib([
			"submit",
			Path.join([IntegrationTests.projectRoot, "test/libraries/libBar2.zip"]),
			bar.pw]).result();
		assertSuccess(r);
		refresh();

		final barAccount = User.manager.search($name == bar.user).first();
		// md5 entry still exists
		assertEquals(Md5.encode(bar.pw), barAccount.pass);
	}
}
