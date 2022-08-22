package haxelib.server;

class Hashing {
	/**
		Generates a cryptographically secure random salt.
	**/
	public static function generateSalt():haxe.io.Bytes {
		// currently only works on Linux
		var randomFile = sys.io.File.read("/dev/urandom");
		var salt = randomFile.read(32);
		randomFile.close();
		return salt;
	}

	/**
		Hashes `password` using `salt`
	**/
	public static inline function hash(password:String, salt:haxe.io.Bytes) {
		return argon2.Argon2id.generateHash(password, salt, 2, 1 << 16, 1);
	}

	/**
		Verifies whether `password` matches `hash` after being hashed.
	**/
	public static inline function verify(hash:String, password:String):Bool {
		return argon2.Argon2id.verify(hash, password);
	}
}
