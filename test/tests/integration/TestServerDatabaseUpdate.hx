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
		Simulates an old database still containing md5 hashes
	**/
	function simulateOldDatabase(users:Array<{
		user:String,
		email:String,
		fullname:String,
		pw:String
	}>) {
		final meta = Meta.manager.all().first();
		meta.dbVersion = 0;
		meta.update();

		for (data in users) {
			final user = new User();
			user.name = data.user;
			user.fullname = data.fullname;
			user.email = data.email;
			user.pass = Md5.encode(data.pw);
			// ignore salt
			user.insert();
		}
		sys.db.Manager.cnx.request("
			ALTER TABLE User
			DROP COLUMN salt;
		");
	}

	function testUpdate() {
		simulateOldDatabase([foo, bar]);

		Update.runNeededUpdates();

		final fooAccount = User.manager.search($name == foo.user).first();

		assertEquals(fooAccount.pass, Hashing.hash(Md5.encode(foo.pw), fooAccount.salt));
		assertTrue(Hashing.verify(fooAccount.pass, Md5.encode(foo.pw)));
		assertEquals(fooAccount.salt.length, 32);

		final barAccount = User.manager.search($name == bar.user).first();

		assertEquals(barAccount.pass, Hashing.hash(Md5.encode(bar.pw), barAccount.salt));
		assertTrue(Hashing.verify(barAccount.pass, Md5.encode(bar.pw)));
		assertEquals(barAccount.salt.length, 32);
	}

	function createNewUserAccount(data:{
		user:String,
		email:String,
		fullname:String,
		pw:String
	}) {
		final user = new User();
		user.name = data.user;
		user.fullname = data.fullname;
		user.email = data.email;
		final salt = Hashing.generateSalt();
		user.pass = Hashing.hash(Md5.encode(data.pw), salt);
		user.salt = salt;
		user.insert();
	}

	function testReUpdate() {
		simulateOldDatabase([foo]);

		// should fix foo account
		Update.runNeededUpdates();

		createNewUserAccount(bar);
		createNewUserAccount(deepAuthor);

		// re-update should not change anything
		Update.runNeededUpdates();

		final fooAccount = User.manager.search($name == foo.user).first();

		assertEquals(fooAccount.pass, Hashing.hash(Md5.encode(foo.pw), fooAccount.salt));
		assertTrue(Hashing.verify(fooAccount.pass, Md5.encode(foo.pw)));
		assertEquals(fooAccount.salt.length, 32);

		// accounts added after first update

		final barAccount = User.manager.search($name == bar.user).first();

		assertEquals(barAccount.pass, Hashing.hash(Md5.encode(bar.pw), barAccount.salt));
		assertTrue(Hashing.verify(barAccount.pass, Md5.encode(bar.pw)));
		assertEquals(barAccount.salt.length, 32);

		final deepAccount = User.manager.search($name == deepAuthor.user).first();

		assertEquals(deepAccount.pass, Hashing.hash(Md5.encode(deepAuthor.pw), deepAccount.salt));
		assertTrue(Hashing.verify(deepAccount.pass, Md5.encode(deepAuthor.pw)));
		assertEquals(deepAccount.salt.length, 32);
	}

}
