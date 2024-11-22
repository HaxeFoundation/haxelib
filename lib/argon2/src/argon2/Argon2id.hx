package argon2;

import haxe.io.Bytes;

class Argon2id {
	public static function generateHash(password:String, salt:Bytes, timeCost:Int, memoryCost:Int, parallelism:Int):String {
		return new String(untyped generate_argon2id_hash(timeCost, memoryCost, parallelism, password.__s, salt.getData()));
	}

	public static function generateRawHash(password:String, salt:Bytes, timeCost:Int, memoryCost:Int, parallelism:Int) {
		return new String(untyped generate_argon2id_raw_hash(timeCost, memoryCost, parallelism, password.__s, salt.getData()));
	}

	public static function verify(hash:String, password:String) {
		return untyped verify_argon2id(hash.__s, password.__s);
	}

	static var generate_argon2id_hash = neko.Lib.load("argon2", "generate_argon2id_hash", 5);
	static var generate_argon2id_raw_hash = neko.Lib.load("argon2", "generate_argon2id_raw_hash", 5);
	static var verify_argon2id = neko.Lib.load("argon2", "verify_argon2id", 2);
}
