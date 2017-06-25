cmake_minimum_required(VERSION 2.8.7)

include(GNUInstallDirs)
project(Haxelib C)

# put output in ${CMAKE_BINARY_DIR}

set(OUTPUT_DIR ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_DIR})

# avoid the extra "Debug", "Release" directories
# http://stackoverflow.com/questions/7747857/in-cmake-how-do-i-work-around-the-debug-and-release-directories-visual-studio-2
foreach( OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES} )
	string( TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG )
	set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTPUT_DIR} )
	set( CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTPUT_DIR} )
	set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTPUT_DIR} )
endforeach( OUTPUTCONFIG CMAKE_CONFIGURATION_TYPES )

# find Haxe and Neko

find_program(HAXE_COMPILER haxe)

find_path(NEKO_INCLUDE_DIRS neko.h)
find_library(NEKO_LIBRARIES neko)
find_program(NEKO neko)
find_program(NEKOTOOLS nekotools)

message(STATUS "HAXE_COMPILER: ${HAXE_COMPILER}")
message(STATUS "NEKO_INCLUDE_DIRS: ${NEKO_INCLUDE_DIRS}")
message(STATUS "NEKO_LIBRARIES: ${NEKO_LIBRARIES}")
message(STATUS "NEKOTOOLS: ${NEKOTOOLS}")

include_directories(${NEKO_INCLUDE_DIRS})

add_custom_command(OUTPUT ${CMAKE_SOURCE_DIR}/run.n
    COMMAND ${HAXE_COMPILER} client.hxml
    VERBATIM
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

add_custom_command(OUTPUT ${CMAKE_SOURCE_DIR}/run.c
    COMMAND ${NEKOTOOLS} boot -c run.n
    VERBATIM
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    DEPENDS ${CMAKE_SOURCE_DIR}/run.n
)

add_executable(haxelib
    ${CMAKE_SOURCE_DIR}/run.c
)

target_link_libraries(haxelib ${NEKO_LIBRARIES})
