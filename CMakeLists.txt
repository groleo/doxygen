cmake_minimum_required(VERSION 3.0)
project(doxygen)

option(build_wizard    "Build the GUI frontend for doxygen." OFF)
option(build_app       "Example showing how to embed doxygen in an application." OFF)
option(build_xmlparser "Example showing how to parse doxygen's XML output." OFF)
option(build_search    "Build external search tools (doxysearch and doxyindexer)" OFF)
option(use_sqlite3     "Add support for sqlite3 output [experimental]." OFF)
option(use_libclang    "Add support for libclang parsing." OFF)

include(set.cmake)


list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# TODO: Dot
find_package(PythonInterp REQUIRED)
find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)
find_package(Threads)
if (sqlite3)
	find_package(SQLite3 REQUIRED)
endif(sqlite3)

if (WIN32)
	set(ICONV_DIR "${CMAKE_SOURCE_DIR}/winbuild")
	add_definitions(-DLIBICONV_STATIC -D_CRT_SECURE_NO_WARNINGS)
endif()
find_package(Iconv REQUIRED)
include_directories(${ICONV_INCLUDE_DIR})

set(GENERATED_SRC "${CMAKE_BINARY_DIR}/generated_src" CACHE INTERNAL "Stores generated files")
set(LIBRARY_OUTPUT_PATH ${PROJECT_BINARY_DIR}/lib/)
set(EXECUTABLE_OUTPUT_PATH ${PROJECT_BINARY_DIR}/bin/)
list(APPEND CMAKE_CXX_FLAGS "-std=c++0x ${CMAKE_CXX_FLAGS}")

add_subdirectory(libmd5)
add_subdirectory(qtools)
add_subdirectory(vhdlparser)
add_subdirectory(src)

add_subdirectory(addon/doxmlparser)
add_subdirectory(addon/doxyapp)
add_subdirectory(addon/doxysearch)
add_subdirectory(addon/doxywizard)

enable_testing()
add_subdirectory(testing)
