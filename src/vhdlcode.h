#ifndef VHDLCODE_H
#define VHDLCODE_H

class CodeOutputInterface;
class FileDef;
class MemberDef;
#include "location.h"

void parseVhdlCode(CodeOutputInterface &,const char *,const QCString &, 
            bool ,const char *,FileDef *fd,
            Location startLoc,Location endLoc,bool inlineFragment,
            MemberDef *memberDef,bool showLineNumbers,Definition *searchCtx,
            bool collectXRefs);
void resetVhdlCodeParserState();
void codeFreeVhdlScanner();

#endif 
