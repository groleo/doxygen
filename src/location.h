/******************************************************************************
 *
 *
 *
 * Copyright (C) 1997-2015 by Dimitri van Heesch.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation under the terms of the GNU General Public License is hereby
 * granted. No representations are made about the suitability of this software
 * for any purpose. It is provided "as is" without express or implied warranty.
 * See the GNU General Public License for more details.
 *
 * Documents produced by Doxygen are derivative works derived from the
 * input used in their production; they are not affected by this license.
 *
 */

#ifndef LOCATION_H
#define LOCATION_H


#include <qintdict.h>

//template<class T> class QIntDict<T*>;
class Location
{
public:
  int line;
  int column;
  Location()
  {
  }
  Location(int line, int col)
    : line(line)
    , column(col)
  {
  }
  Location(int line)
    : line(line)
    , column(0)
  {
  }
  Location& operator =(const Location& rhs)
  {
    line = rhs.line;
    column = rhs.column;
  }
  bool operator ==(const Location& rhs) const
  {
    return line==rhs.line
           && column==rhs.column;
  }
  bool operator !=(const Location& rhs) const
  {
    return line!=rhs.line
           || column!=rhs.column;
  }
  bool operator >(const Location& rhs) const
  {
    return line>rhs.line
           || (line==rhs.line && column>rhs.column);
  }
  QCString str() const {}
  friend class FileDef;
protected:
  operator int () const
  {
    return column<<20 | line;
  }
};

#endif

#if 0
  // used for default parameters
  Location& operator=( const int& rhs );
  Location& operator=( int& rhs );
  Location& operator=( int rhs );
  const Location& operator=( const int& rhs );
  const Location& operator=( int& rhs );
  const Location& operator=( int rhs );
  Location operator=( const int& rhs );
  Location operator=( int& rhs );
  Location operator=( int rhs );
#endif
