cmake_minimum_required(VERSION 3.16.3)

project(Argon2Ndll C)

include(ExternalProject)

set(ARGON2_LIB ${CMAKE_BINARY_DIR}/libs/src/Argon2/libargon2.a)
set(ARGON2_INCLUDE ${CMAKE_BINARY_DIR}/libs/src/Argon2/include)

ExternalProject_Add(Argon2
	PREFIX ${CMAKE_BINARY_DIR}/libs
	DOWNLOAD_DIR ${CMAKE_BINARY_DIR}/libs/download
	URL https://github.com/P-H-C/phc-winner-argon2/archive/refs/tags/20190702.tar.gz
	URL_HASH SHA256=daf972a89577f8772602bf2eb38b6a3dd3d922bf5724d45e7f9589b5e830442c
	BUILD_COMMAND cd ${CMAKE_BINARY_DIR}/libs/src/Argon2 && CFLAGS=-fPIC make
	CONFIGURE_COMMAND echo skip config
	INSTALL_COMMAND echo skip install
	BYPRODUCTS ${ARGON2_LIB}
)

add_custom_command(
	OUTPUT ${ARGON2_INCLUDE}/argon2.h
	DEPENDS Argon2
)

add_custom_command(
	OUTPUT ${ARGON2_LIB}
	DEPENDS Argon2
)

add_library(argon2.ndll MODULE native/argon2.c)

target_include_directories(argon2.ndll PRIVATE ${ARGON2_INCLUDE})
target_link_libraries(argon2.ndll libneko.so ${ARGON2_LIB})

set_target_properties(argon2.ndll
	PROPERTIES
	PREFIX ""
	OUTPUT_NAME argon2
	SUFFIX .ndll
)

install(
	TARGETS argon2.ndll
	DESTINATION ${CMAKE_SOURCE_DIR}/ndll/Linux64
)
