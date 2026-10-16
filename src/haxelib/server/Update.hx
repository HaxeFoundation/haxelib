package haxelib.server;

import haxelib.server.SiteDb;

/**
	Handles server database updates from old versions of the database.
**/
class Update {
	/** The current version of the database. **/
	static final CURRENT_VERSION = 1;

	/**
		Checks which updates are needed and if there are any needed, runs them.
	**/
	public static function runNeededUpdates() {
		sys.db.Manager.cnx.startTransaction();

		var meta = Meta.manager.all().first();

		if (meta == null) {
			// no meta data stored yet, so create it
			meta = new Meta();
			meta.dbVersion = 0;
			meta.insert();
		}

		if (meta.dbVersion == 0) {
			updateFromV0();
		}

		meta.dbVersion = CURRENT_VERSION;
		meta.update();

		sys.db.Manager.cnx.commit();
	}

	/**
		Sets up a fresh database
	**/
	public static function setupFresh() {
		sys.db.Manager.cnx.startTransaction();

		final meta = new Meta();
		meta.dbVersion = CURRENT_VERSION;
		meta.insert();

		sys.db.Manager.cnx.commit();
	}

	static function updateFromV0() {
		sys.db.Manager.cnx.request("
			ALTER TABLE User
			ADD COLUMN pass2 mediumtext;
		");
	}

}
