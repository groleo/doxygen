set(doxygen_version_major    "1" CACHE STRING "Major")
set(doxygen_version_minor    "8" CACHE STRING "Minor")
set(doxygen_version_revision "8" CACHE STRING "Revision")
#set(doxygen_version_mmn      "5" CACHE STRING "Mmn")

set(sqlite3  "0" CACHE INTERNAL "used in settings.h")
set(clang    "0" CACHE INTERNAL "used in settings.h")
if (use_sqlite3)
	set(sqlite3  "1" CACHE INTERNAL "used in settings.h")
endif()
if (use_libclang)
	set(clang    "1" CACHE INTERNAL "used in settings.h")
endif()

