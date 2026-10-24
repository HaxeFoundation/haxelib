package haxelib.server;

class Hashing {
	public static final DUMMY_HASH = "$argon2id$v=19$m=65536,t=2,p=1$opHNOVOoS7uVZ25jmFs6i6xMYWMfx6JBlnKrg2upCd8$aIYaq20WUg7yAWKnLiLoUMZTCUgDenAUmSptIMp9l9A";

	/**
		Generates a cryptographically secure random salt.
	**/
	public static function generateSalt():haxe.io.Bytes {
		// currently only works on Linux
		final randomFile = sys.io.File.read("/dev/urandom");
		final salt = randomFile.read(32);
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
