# This module defines
# ICONV_LIBRARIES - libraries to link to in order to use ICONV
# ICONV_FOUND, if false, do not try to link 
# ICONV_INCLUDE_DIR, where to find the headers
#
# $ICONV_DIR is an environment variable that would
# correspond to the ./configure --prefix=$ICONV_DIR

# Created by Ralf Habacker. 
# Modifications by Alexander Neundorf

FIND_PATH(ICONV_INCLUDE_DIR iconv.h
  PATHS
  ${CMAKE_PREFIX_PATH} # Unofficial: We are proposing this.
  ${ICONV_DIR}
  $ENV{ICONV_DIR}
  NO_DEFAULT_PATH
  PATH_SUFFIXES include
)

FIND_LIBRARY(ICONV_LIBRARY 
  NAMES iconv
  PATHS 
  ${CMAKE_PREFIX_PATH} # Unofficial: We are proposing this.
  ${ICONV_DIR}
  $ENV{ICONV_DIR}
  NO_DEFAULT_PATH
  PATH_SUFFIXES lib64 lib
)

# see readme.txt
SET(ICONV_LIBRARIES ${ICONV_LIBRARY})

# handle the QUIETLY and REQUIRED arguments and set ICONV_FOUND to TRUE if 
# all listed variables are TRUE
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(ICONV  "Could NOT find iconv library, please set ICONV_DIR to the installation root of the iconv library" ICONV_LIBRARY  ICONV_INCLUDE_DIR)

MARK_AS_ADVANCED(ICONV_INCLUDE_DIR ICONV_LIBRARY)
