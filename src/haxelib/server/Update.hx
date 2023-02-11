package haxelib.server;

import haxelib.server.SiteDb;

/**
	Handles server database updates from old versions of the database.
**/
class Update {
	/** The current version of the database. **/
	static inline var CURRENT_VERSION = 1;

	/**
		Checks which updates are needed and if there are any needed, runs them.
	**/
	public static function runNeededUpdates() {
		var meta = Meta.manager.all().first();

		if (meta == null) {
			// no meta data stored yet, so create it
			meta = new Meta();
			meta.dbVersion = 0;
			meta.insert();
		}

		if (meta.dbVersion == 0) {
			rehashPasswords();
		}

		meta.dbVersion = CURRENT_VERSION;
		meta.update();
	}

	/**
		Sets up a fresh database
	**/
	public static function setupFresh() {
		var meta = new Meta();
		meta.dbVersion = CURRENT_VERSION;
		meta.insert();
	}

	static function rehashPasswords() {
		// add missing columns first
		sys.db.Manager.cnx.request("
			ALTER TABLE User
			ADD COLUMN salt binary(32) NOT NULL,
			ADD COLUMN hashmethod mediumtext NOT NULL;
		");

		// script used to update password hashes from md5 to md5 rehashed with argon2id
		var users = User.manager.all();

		for (user in users) {
			var md5Hash = user.pass;

			user.salt = Hashing.generateSalt();
			user.pass = Hashing.hash(md5Hash, user.salt);
			user.hashmethod = Md5;
			user.update();
		}
	}

}
