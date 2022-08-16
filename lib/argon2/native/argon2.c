#include <neko.h>
#include <stdio.h>

#include "argon2.h"

#define HASHLEN 32

static void handle_error(int rc) {
	buffer b = alloc_buffer("Argon2 Error: ");
	buffer_append(b, argon2_error_message(rc));
	buffer_append(b, "\n");
	val_throw(buffer_to_string(b));
}

value generate_argon2id_raw_hash(value time_cost, value memory_cost, value parallelism, value password, value salt) {
	printf("hello\n");
	val_check(time_cost, int);
	val_check(memory_cost, int);
	val_check(parallelism, int);
	val_check(password, string);
	val_check(salt, string);

	value hash = alloc_empty_string(HASHLEN);

	int rc = argon2id_hash_raw(val_int(time_cost), val_int(memory_cost), val_int(parallelism), val_string(password), val_strlen(password), val_string(salt), val_strlen(salt), val_string(hash), HASHLEN);
	if (rc != ARGON2_OK) {
		handle_error(rc);
	}

	return hash;
}

value generate_argon2id_hash(value time_cost, value memory_cost, value parallelism, value password, value salt) {
	val_check(time_cost, int);
	val_check(memory_cost, int);
	val_check(parallelism, int);
	val_check(password, string);
	val_check(salt, string);

	size_t salt_len = val_strlen(salt);
	size_t password_len = val_strlen(password);
	size_t encoded_len = argon2_encodedlen(val_int(time_cost), val_int(memory_cost), val_int(parallelism), salt_len, HASHLEN, Argon2_id);

	value hash_string = alloc_empty_string(encoded_len);

	int rc = argon2id_hash_encoded(val_int(time_cost), val_int(memory_cost), val_int(parallelism), val_string(password), password_len, val_string(salt), salt_len, HASHLEN, val_string(hash_string), encoded_len);
	if (rc != ARGON2_OK) {
		handle_error(rc);
	}

	return hash_string;
}

value verify_argon2id(value hash, value password) {
	val_check(hash, string);
	val_check(password, string);

	int rc = argon2id_verify(val_string(hash), val_string(password), val_strlen(password));
	if (rc == ARGON2_OK)
		return val_true;
	if (rc == ARGON2_VERIFY_MISMATCH)
		return val_false;
	handle_error(rc);
	return val_false;
}

DEFINE_PRIM(generate_argon2id_raw_hash, 5);
DEFINE_PRIM(generate_argon2id_hash, 5);
DEFINE_PRIM(verify_argon2id, 2);
