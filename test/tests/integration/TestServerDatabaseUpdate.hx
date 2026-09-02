package tests.integration;

import haxe.crypto.Md5;
import haxelib.server.Update;
import haxelib.server.Hashing;
import haxelib.server.SiteDb;

class TestServerDatabaseUpdate extends IntegrationTests {

	override function setup() {
		super.setup();
		SiteDb.init();
	}

	override function tearDown() {
		SiteDb.cleanup();
		super.tearDown();
	}

	/**
		Simulates an old v0 database (no pass2)
	**/
	function simulateV0Database(users:Array<{
		user:String,
		email:String,
		fullname:String,
		pw:String
	}>) {
		Meta.manager.all().first().delete();

		for (data in users) {
			final user = new User();
			user.name = data.user;
			user.fullname = data.fullname;
			user.email = data.email;
			user.pass = Md5.encode(data.pw);
			// ignore pass2
			user.insert();
		}
		sys.db.Manager.cnx.request("
			ALTER TABLE User
			DROP COLUMN pass2;
		");
	}

	static function refresh() {
		sys.db.Manager.cleanup();
	}

	function testUpdate() {
		simulateV0Database([bar]);
		final wrongPassword = "wrong";

		try {
			// this should fail as expected fields are missing
			User.manager.all();
			assertTrue(false);
		} catch (e) {
			assertTrue(true);
		}

		// request to trigger db migration
		final r = haxelib(["user", "bar"]).result();
		assertSuccess(r);
		refresh();

		final barAccount = User.manager.search($name == bar.user).first();
		// new fields exist, but are empty
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
