package haxelib.server;

@:enum abstract HashMethod(String) {
	/** Represents argon2id hashing. **/
	var Argon2id = "argon2id";
	/** Represents rehashing an md5 hash with argon2id. **/
	var Md5 = "md5";
}

class Hashing {
	/**
		Generates a cryptographically secure random salt.
	**/
	public static function generateSalt():haxe.io.Bytes {
		// currently only works on Linux
		var randomFile = sys.io.File.read("/dev/random");
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
		Verifies whether `password` matches `hash` after being put through the
		hashing method specified by `method`.
	**/
	public static inline function verify(hash:String, password:String, method:HashMethod):Bool {
		// work out md5 hash regardless, to prevent time based attacks
		var md5 = haxe.crypto.Md5.encode(password);
		return switch method {
			case Md5:
				argon2.Argon2id.verify(hash, md5);
			case Argon2id:
				argon2.Argon2id.verify(hash, password);
		};
	}
}
