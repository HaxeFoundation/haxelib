import argon2.Argon2id;
import haxe.io.Bytes;

function main() {
	final hash = Argon2id.generateRawHash("hello", Bytes.ofString("tesfdfdafdafsagfagahraegfaharegh"), 2, 1 << 16, 1);
	trace(hash);

	final hash = Argon2id.generateHash("hello", Bytes.ofString("tesfdfdafdafsagfagahraegfaharegh"), 2, 1 << 16, 1);
	trace(hash);

	trace(Argon2id.verify(hash, "hello"));
	trace(Argon2id.verify(hash, "hi"));
}
