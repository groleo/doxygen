/*****************************************************************************
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
%option never-interactive
%option prefix="commentcnvYY"
%option noyywrap
%option reentrant
%option extra-type="struct commentcnvYY_state *"

%{

  
#include <stdio.h>
#include <stdlib.h>

#include <qstack.h>
#include <qregexp.h>
#include <qtextstream.h>
#include <qglobal.h>

#include "bufstr.h"
#include "debug.h"
#include "message.h"
#include "config.h"
#include "doxygen.h"
#include "util.h"
#include "condparser.h"

#include <assert.h>

#define YY_NO_INPUT 1
#define YY_NO_UNISTD_H 1

#define ADDCHAR(c)    yyextra->outBuf->addChar(c)
#define ADDARRAY(a,s) yyextra->outBuf->addArray(a,s)
  
struct CondCtx
{
  CondCtx(int line,QCString id,bool b) 
    : lineNr(line),sectionId(id), skip(b) {}
  int lineNr;
  QCString sectionId;
  bool skip;
};
  
struct CommentCtx
{
  CommentCtx(int line) 
    : lineNr(line) {}
  int lineNr;
};
struct commentcnvYY_state
{
     BufStr            *inBuf;
     BufStr            *outBuf;
     int                inBufPos;
     int                col;
     int                blockHeadCol;
     bool               mlBrief;
     int                readLineCtx;
     bool               skip;
     QCString           fileName;
     int                lineNr;
     int                condCtx;
     QStack<CondCtx>    condStack;
     QStack<CommentCtx> commentStack;
     QCString           blockName;
     int                lastCommentContext;
     bool               inSpecialComment;
     bool               inRoseComment;
     int                stringContext;
     int                charContext;
     int                javaBlock;
     bool               specialComment;

     QCString           aliasString;
     int                blockCount;
     bool               lastEscaped;
     int                lastBlockContext;
     bool               pythonDocString;
     int                nestingCount;

     bool               vhdl; // for VHDL old style --! comment

     SrcLangExt         lang;
     bool               isFixedForm; // For Fortran
};

//-----------------------------------------------------------------------------
static void replaceCommentMarker(const char *s,int len,yyscan_t yyscanner);
static inline int computeIndent(const char *s);
static inline void copyToOutput(const char *s,int len,yyscan_t yyscanner);
static void startCondSection(const char *sectId,yyscan_t yyscanner);
static void endCondSection(yyscan_t yyscanner);
static void replaceAliases(const char *s,yyscan_t yyscanner);
static int yyread(char *buf,int max_size,yyscan_t yyscanner);
static void replaceComment(int offseti,yyscan_t yyscanner);

#undef  YY_INPUT
#define YY_INPUT(buf,result,max_size) result=yyread(buf,max_size,yyscanner);

%}


%x Scan
%x SkipString
%x SkipChar
%x SComment
%x CComment
%x Verbatim
%x VerbatimCode
%x ReadLine
%x CondLine
%x ReadAliasArgs

%%

<Scan>[^"'!\/\n\\#,\-]*             { /* eat anything that is not " / , or \n */
                                       copyToOutput(yytext,(int)yyleng,yyscanner);
                                    }
<Scan>[,]                           { /* eat , so we have a nice separator in long initialization lines */ 
                                       copyToOutput(yytext,(int)yyleng,yyscanner);
                                    }
<Scan>"\"\"\""!                     { /* start of python long comment */
                                     if (yyextra->lang!=SrcLangExt_Python)
				     {
				       REJECT;
				     }
				     else
				     {
                                       yyextra->pythonDocString = TRUE;
                                       yyextra->nestingCount=0;
                                       yyextra->commentStack.clear(); /*  to be on the save side */
                                       copyToOutput(yytext,(int)yyleng,yyscanner);
				       BEGIN(CComment);
                                       yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				     }
                                   }
<Scan>![><!]/.*\n	   {
                                     if (yyextra->lang!=SrcLangExt_Fortran)
				     {
				       REJECT;
				     }
				     else
				     {
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
                                       yyextra->nestingCount=0;
                                       yyextra->commentStack.clear(); /*  to be on the save side */
				       BEGIN(CComment);
                                       yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				     }
  				   }
<Scan>[Cc\*][><!]/.*\n	   {
                                     if (yyextra->lang!=SrcLangExt_Fortran)
				     {
				       REJECT;
				     }
				     else
				     {
                                       /* check for fixed format; we might have some conditional as part of multilene if like C<5 .and. & */
                                       if (yyextra->isFixedForm && (yyextra->col == 0))
                                       {
                                         copyToOutput(yytext,(int)yyleng,yyscanner); 
                                         yyextra->nestingCount=0;
                                         yyextra->commentStack.clear(); /*  to be on the save side */
				         BEGIN(CComment);
                                         yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				       }
				       else
				       {
				         REJECT;
				       }
				     }
  				   }
<Scan>!.*\n		   {
  			             if (yyextra->lang!=SrcLangExt_Fortran)
				     {
				       REJECT;
				     }
				     else
				     {
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
				     }
                                   }
<Scan>[Cc\*].*\n		   {
  			             if (yyextra->lang!=SrcLangExt_Fortran)
				     {
				       REJECT;
				     }
				     else
				     {
                                       if (yyextra->col == 0)
                                       {
                                         copyToOutput(yytext,(int)yyleng,yyscanner); 
				       }
				       else
				       {
				         REJECT;
				       }
				     }
                                   }
<Scan>"\""                         { /* start of a string */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->stringContext = YY_START;
				     BEGIN(SkipString); 
                                   }
<Scan>'				   {
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->charContext = YY_START;
                                     if (yyextra->lang!=SrcLangExt_VHDL)
                                     {
				       BEGIN(SkipChar);
                                     }
  				   }
<Scan>\n                           { /* new line */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<Scan>"//!"/.*\n[ \t]*"//"[\/!][^\/] | /* start C++ style special comment block */
<Scan>("///"[/]*)/[^/].*\n[ \t]*"//"[\/!][^\/] { /* start C++ style special comment block */
  				     if (yyextra->mlBrief) 
				     {
				       REJECT; // bail out if we do not need to convert
				     }
				     else
				     {
				       int i=3;
				       if (yytext[2]=='/')
				       {
					 while (i<(int)yyleng && yytext[i]=='/') i++;
				       }
				       yyextra->blockHeadCol=yyextra->col;
				       copyToOutput("/**",3,yyscanner); 
				       replaceAliases(yytext+i,yyscanner);
				       yyextra->inSpecialComment=TRUE;
				       //BEGIN(SComment); 
				       yyextra->readLineCtx=SComment;
				       BEGIN(ReadLine);
				     }
                                   }
<Scan>"//##Documentation".*/\n	   { /* Start of Rational Rose ANSI C++ comment block */
                                     if (yyextra->mlBrief) REJECT;
                                     int i=17; //=strlen("//##Documentation");
				     yyextra->blockHeadCol=yyextra->col;
				     copyToOutput("/**",3,yyscanner);
				     replaceAliases(yytext+i,yyscanner);
				     yyextra->inRoseComment=TRUE;
				     BEGIN(SComment);
  				   }
<Scan>"//"[!\/]/.*\n[ \t]*"//"[|\/][ \t]*[@\\]"}" { // next line contains an end marker, see bug 752712
				     yyextra->inSpecialComment=yytext[2]=='/' || yytext[2]=='!';
  				     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
                                   }
<Scan>"//"/.*\n	                   { /* one line C++ comment */ 
				     yyextra->inSpecialComment=yytext[2]=='/' || yytext[2]=='!';
  				     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
				   }
<Scan>"/**/"                       { /* avoid matching next rule for empty C comment, see bug 711723 */
                                     copyToOutput(yytext,(int)yyleng,yyscanner);
                                   }
<Scan>"/*"[*!]?			   { /* start of a C comment */
  			             yyextra->specialComment=(int)yyleng==3;
                                     yyextra->nestingCount=0;
                                     yyextra->commentStack.clear(); /*  to be on the save side */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     BEGIN(CComment); 
                                     yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
                                   }
<Scan>"#"("#")?		           {
                                     if (yyextra->lang!=SrcLangExt_Python)
				     {
				       REJECT;
				     }
				     else
				     {
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
                                       yyextra->nestingCount=0;
                                       yyextra->commentStack.clear(); /*  to be on the save side */
				       BEGIN(CComment);
                                       yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				     }
  				   }
<Scan>"--!"		           {
                                     if (yyextra->lang!=SrcLangExt_VHDL)
				     {
				       REJECT;
				     }
				     else
				     {
                                       yyextra->vhdl = TRUE;
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
                                       yyextra->nestingCount=0;
                                       yyextra->commentStack.clear(); /*  to be on the save side */
				       BEGIN(CComment);
                                       yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				     }
  				   }
<Scan>![><!]		           {
                                     if (yyextra->lang!=SrcLangExt_Fortran)
				     {
				       REJECT;
				     }
				     else
				     {
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
                                       yyextra->nestingCount=0;
                                       yyextra->commentStack.clear(); /*  to be on the save side */
				       BEGIN(CComment);
                                       yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
				     }
  				   }
<CComment>"{@code"/[ \t\n]	   {
                                     copyToOutput("@code",5,yyscanner); 
				     yyextra->lastCommentContext = YY_START;
				     yyextra->javaBlock=1;
				     yyextra->blockName=&yytext[1];
                                     BEGIN(VerbatimCode);
  				   }
<CComment,ReadLine>[\\@]("dot"|"code"|"msc"|"startuml")/[^a-z_A-Z0-9] { /* start of a verbatim block */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->lastCommentContext = YY_START;
				     yyextra->javaBlock=0;
                                     if (qstrcmp(&yytext[1],"startuml")==0)
                                     {
                                       yyextra->blockName="uml";
                                     }
                                     else
                                     {
				       yyextra->blockName=&yytext[1];
                                     }
                                     BEGIN(VerbatimCode);
  				   }
<CComment,ReadLine>[\\@]("f$"|"f["|"f{") {
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->blockName=&yytext[1];
				     if (yyextra->blockName.at(1)=='[')
				     {
				       yyextra->blockName.at(1)=']';
				     }
				     else if (yyextra->blockName.at(1)=='{')
				     {
				       yyextra->blockName.at(1)='}';
				     }
				     yyextra->lastCommentContext = YY_START;
				     BEGIN(Verbatim);
  			           }
<CComment,ReadLine>[\\@]("verbatim"|"latexonly"|"htmlonly"|"xmlonly"|"docbookonly"|"rtfonly"|"manonly")/[^a-z_A-Z0-9] { /* start of a verbatim block */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->blockName=&yytext[1];
				     yyextra->lastCommentContext = YY_START;
                                     BEGIN(Verbatim);
                                   }
<Scan>.                            { /* any ather character */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<Verbatim>[\\@]("endverbatim"|"endlatexonly"|"endhtmlonly"|"endxmlonly"|"enddocbookonly"|"endrtfonly"|"endmanonly"|"f$"|"f]"|"f}") { /* end of verbatim block */
                                     copyToOutput(yytext,(int)yyleng,yyscanner);
				     if (&yytext[1]==yyextra->blockName) // end of formula
				     {
				       BEGIN(yyextra->lastCommentContext);
				     }
				     else if (&yytext[4]==yyextra->blockName)
				     {
				       BEGIN(yyextra->lastCommentContext);
				     }
                                   }
<VerbatimCode>"{"		   {
                                     if (yyextra->javaBlock==0)
				     {
				       REJECT;
				     }
				     else
				     {
				       yyextra->javaBlock++;
                                       copyToOutput(yytext,(int)yyleng,yyscanner);
				     }
                                   }
<VerbatimCode>"}"		   {
                                     if (yyextra->javaBlock==0)
				     {
				       REJECT;
				     }
				     else
				     {
				       yyextra->javaBlock--;
				       if (yyextra->javaBlock==0)
				       {
                                         copyToOutput(" @endcode ",10,yyscanner);
				         BEGIN(yyextra->lastCommentContext);
				       }
				       else
				       {
                                         copyToOutput(yytext,(int)yyleng,yyscanner);
				       }
				     }
  				   }
<VerbatimCode>[\\@]("enddot"|"endcode"|"endmsc"|"enduml") { /* end of verbatim block */
                                     copyToOutput(yytext,(int)yyleng,yyscanner);
				     if (&yytext[4]==yyextra->blockName)
				     {
				       BEGIN(yyextra->lastCommentContext);
				     }
                                   }
<VerbatimCode>^[ \t]*"//"[\!\/]?   { /* skip leading comments */
  				     if (!yyextra->inSpecialComment)
				     {
                                       copyToOutput(yytext,(int)yyleng,yyscanner); 
				     }
                                     else
                                     {
                                       int l=0;
                                       while (yytext[l]==' ' || yytext[l]=='\t')
                                       {
                                         l++;
                                       }
                                       copyToOutput(yytext,l,yyscanner);
                                       if (yyleng-l==3) // ends with //! or ///
                                       {
                                         copyToOutput(" * ",3,yyscanner);
                                       }
                                       else // ends with //
                                       {
                                         copyToOutput("//",2,yyscanner);
                                       }
                                     }
  				   }
<Verbatim,VerbatimCode>[^@\/\\\n{}]* { /* any character not a backslash or new line or } */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<Verbatim,VerbatimCode>\n	   { /* new line in verbatim block */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<Verbatim>^[ \t]*"///"             {
  				     if (yyextra->blockName=="dot" || yyextra->blockName=="msc" || yyextra->blockName=="uml" || yyextra->blockName.at(0)=='f')
				     {
				       // see bug 487871, strip /// from dot images and formulas.
                                       int l=0;
                                       while (yytext[l]==' ' || yytext[l]=='\t')
                                       {
                                         l++;
                                       }
                                       copyToOutput(yytext,l,yyscanner);
				       copyToOutput("   ",3,yyscanner);
				     }
				     else // even slashes are verbatim (e.g. \verbatim, \code)
				     {
				       REJECT;
				     }
  				   }
<Verbatim,VerbatimCode>.	   { /* any other character */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipString>\\.                    { /* escaped character in string */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipString>"\""       	           { /* end of string */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     BEGIN(yyextra->stringContext); 
                                   }
<SkipString>.                      { /* any other string character */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipString>\n                     { /* new line inside string (illegal for some compilers) */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipChar>\\.		           { /* escaped character */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipChar>'                        { /* end of character literal */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                     BEGIN(yyextra->charContext);
                                   }
<SkipChar>.                        { /* any other string character */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<SkipChar>\n                       { /* new line character */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }

<CComment>[^\\!@*\n{\"\/]*           { /* anything that is not a '*' or command */ 
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<CComment>"*"+[^*/\\@\n{\"]*       { /* stars without slashes */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<CComment>"\"\"\""                 { /* end of Python docstring */
                                     if (yyextra->lang!=SrcLangExt_Python)
				     {
				       REJECT;
				     }
				     else
				     {
                                       yyextra->pythonDocString = FALSE;
				       copyToOutput(yytext,(int)yyleng,yyscanner);
				       BEGIN(Scan);
				     }
  				   }
<CComment>\n                       { /* new line in comment */
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                     /* in case of Fortran always end of comment */
  				     if (yyextra->lang==SrcLangExt_Fortran)
				     {
				       BEGIN(Scan);
				     }
                                   }
<CComment>"/"+"*"                  { /* nested C comment */
                                     yyextra->nestingCount++;
                                     yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
                                   }
<CComment>"*"+"/"                  { /* end of C comment */
                                     if (yyextra->lang==SrcLangExt_Python)
				     {
				       REJECT;
				     }
				     else
				     {
				       copyToOutput(yytext,(int)yyleng,yyscanner);
                                       if (yyextra->nestingCount<=0)
                                       {
				         BEGIN(Scan);
                                       }
                                       else
                                       {
                                         yyextra->nestingCount--;
                                         delete yyextra->commentStack.pop();
                                       }
				     }
                                   }
  /* Python an VHDL share CComment, so special attention for ending commments is required */
<CComment>"\n"/[ \t]*"#" 	   {
                                     if (yyextra->lang!=SrcLangExt_VHDL)
                                     {
                                       REJECT;
                                     }
                                     else
                                     {
                                       if (yyextra->vhdl) // inside --! comment
                                       {
                                         yyextra->vhdl = FALSE;
				         copyToOutput(yytext,(int)yyleng,yyscanner);
				         BEGIN(Scan);
                                       }
                                       else // C-type comment
                                       {
                                         REJECT;
                                       }
                                     }
                                   }
<CComment>"\n"/[ \t]*"-" 	   {
                                     if (yyextra->lang!=SrcLangExt_Python || yyextra->pythonDocString)
				     {
				       REJECT;
				     }
				     else
				     {
				       copyToOutput(yytext,(int)yyleng,yyscanner);
				       BEGIN(Scan);
				     }
                                   }
<CComment>"\n"/[ \t]*[^ \t#\-] 	   {
                                     if (yyextra->lang==SrcLangExt_Python)
                                     {
                                       if (yyextra->pythonDocString)
                                       {
                                         REJECT;
                                       }
                                       else
                                       {
				         copyToOutput(yytext,(int)yyleng,yyscanner);
				         BEGIN(Scan);
                                       }
                                     }
                                     else if (yyextra->lang==SrcLangExt_VHDL)
                                     {
                                       if (yyextra->vhdl) // inside --! comment
                                       {
                                         yyextra->vhdl = FALSE;
				         copyToOutput(yytext,(int)yyleng,yyscanner);
				         BEGIN(Scan);
                                       }
                                       else // C-type comment
                                       {
                                         REJECT;
                                       }
                                     }
                                     else
                                     {
				       REJECT;
                                     }
                                   }
   /* removed for bug 674842 (bug was introduced in rev 768)
<CComment>"'"			   {
  			             yyextra->charContext = YY_START;
				     copyToOutput(yytext,(int)yyleng,yyscanner);
				     BEGIN(SkipChar);
  				   }
<CComment>"\""			   {
  			             yyextra->stringContext = YY_START;
				     copyToOutput(yytext,(int)yyleng,yyscanner);
				     BEGIN(SkipString);
  				   }
   */
<CComment>.			   {
                                     copyToOutput(yytext,(int)yyleng,yyscanner); 
  				   }
<SComment>^[ \t]*"///"[\/]*/\n     {
  				     replaceComment(0,yyscanner);
  				   }
<SComment>\n[ \t]*"///"[\/]*/\n    {
                                     replaceComment(1,yyscanner); 
                                   }
<SComment>^[ \t]*"///"[^\/\n]/.*\n { 
  				     replaceComment(0,yyscanner);
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
  				   }
<SComment>\n[ \t]*"//"[\/!]("<")?[ \t]*[\\@]"}".*\n {   
                                     /* See Bug 752712: end the multiline comment when finding a @} or \} command */
                                     copyToOutput(" */",3,yyscanner); 
				     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->inSpecialComment=FALSE;
				     yyextra->inRoseComment=FALSE;
				     BEGIN(Scan); 
                                   }
<SComment>\n[ \t]*"///"[^\/\n]/.*\n  { 
                                     replaceComment(1,yyscanner); 
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
  				   }
<SComment>^[ \t]*"//!"             |    // just //!
<SComment>^[ \t]*"//!<"/.*\n       |    // or   //!< something
<SComment>^[ \t]*"//!"[^<]/.*\n    {    // or   //!something
  				     replaceComment(0,yyscanner);
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
                                   }
<SComment>\n[ \t]*"//!"            |
<SComment>\n[ \t]*"//!<"/.*\n      |
<SComment>\n[ \t]*"//!"[^<\n]/.*\n { 
                                     replaceComment(1,yyscanner); 
				     yyextra->readLineCtx=YY_START;
				     BEGIN(ReadLine);
                                   }
<SComment>^[ \t]*"//##"/.*\n       {
                                     if (!yyextra->inRoseComment)
				     {
				       REJECT;
				     }
				     else
				     {
  				       replaceComment(0,yyscanner);
				       yyextra->readLineCtx=YY_START;
				       BEGIN(ReadLine);
				     }
                                   }
<SComment>\n[ \t]*"//##"/.*\n      {
                                     if (!yyextra->inRoseComment)
				     {
				       REJECT;
				     }
				     else
				     {
                                       replaceComment(1,yyscanner); 
				       yyextra->readLineCtx=YY_START;
				       BEGIN(ReadLine);
				     }
                                   }
<SComment>\n			   { /* end of special comment */
                                     copyToOutput(" */",3,yyscanner); 
				     copyToOutput(yytext,(int)yyleng,yyscanner); 
				     yyextra->inSpecialComment=FALSE;
				     yyextra->inRoseComment=FALSE;
				     BEGIN(Scan); 
                                   }
<ReadLine>[^\\@\n]*/\n		   {
  				     copyToOutput(yytext,(int)yyleng,yyscanner);
                                     BEGIN(yyextra->readLineCtx);
  				   }
<CComment,ReadLine>[\\@][\\@][~a-z_A-Z][a-z_A-Z0-9]*[ \t]* { // escaped command
				     copyToOutput(yytext,(int)yyleng,yyscanner);
  				   }
<CComment,ReadLine>[\\@]"cond"/[^a-z_A-Z0-9]	   { // conditional section
  				     yyextra->condCtx = YY_START; 
  				     BEGIN(CondLine);
  				   }
<CComment,ReadLine>[\\@]"endcond"/[^a-z_A-Z0-9] { // end of conditional section
  				     bool oldSkip=yyextra->skip;
  				     endCondSection(yyscanner);
				     if (YY_START==CComment && oldSkip && !yyextra->skip) 
    			             {
				       //printf("** Adding start of comment!\n");
				       if (yyextra->lang!=SrcLangExt_Python &&
					   yyextra->lang!=SrcLangExt_VHDL &&
					   yyextra->lang!=SrcLangExt_Markdown &&
					   yyextra->lang!=SrcLangExt_Fortran)
				       {
 				         ADDCHAR('/');
     				         ADDCHAR('*');
					 if (yyextra->specialComment)
					 {
					   ADDCHAR('*');
					 }
				       }
    				     }
				    }
<CondLine>[!()&| \ta-z_A-Z0-9.\-]+ {
  				     bool oldSkip=yyextra->skip;
                                     startCondSection(yytext,yyscanner);
				     if ((yyextra->condCtx==CComment || yyextra->readLineCtx==SComment) && 
                                         !oldSkip && yyextra->skip) 
    			             {
				       if (yyextra->lang!=SrcLangExt_Python &&
					   yyextra->lang!=SrcLangExt_VHDL &&
					   yyextra->lang!=SrcLangExt_Markdown &&
					   yyextra->lang!=SrcLangExt_Fortran)
				       {
 				         ADDCHAR('*');
     				         ADDCHAR('/');
				       }
    				     }
                                     if (yyextra->readLineCtx==SComment)
                                     {
                                       BEGIN(SComment);
                                     }
                                     else
                                     {
  				       BEGIN(yyextra->condCtx);
                                     }
  				   }
<CondLine>[ \t]*
<CComment,ReadLine>[\\@]"cond"[ \t\r]*/\n |
<CondLine>.			   { // forgot section id?
  				     if (YY_START!=CondLine) yyextra->condCtx=YY_START;
  				     bool oldSkip=yyextra->skip;
  				     startCondSection(" ",yyscanner); // fake section id causing the section to be hidden unconditionally
				     if ((yyextra->condCtx==CComment || yyextra->readLineCtx==SComment) && 
                                         !oldSkip && yyextra->skip) 
    			             {
				       //printf("** Adding terminator for comment!\n");
				       if (yyextra->lang!=SrcLangExt_Python &&
					   yyextra->lang!=SrcLangExt_VHDL)
				       {
 				         ADDCHAR('*');
     				         ADDCHAR('/');
				       }
    				     }
				     if (*yytext=='\n') yyextra->lineNr++;
                                     if (yyextra->readLineCtx==SComment)
                                     {
                                       BEGIN(SComment);
                                     }
                                     else
                                     {
  				       BEGIN(yyextra->condCtx);
                                     }
  				   }
<CComment,ReadLine>[\\@][a-z_A-Z][a-z_A-Z0-9]*  { // expand alias without arguments
				     replaceAliases(yytext,yyscanner);
  				   }
<CComment,ReadLine>[\\@][a-z_A-Z][a-z_A-Z0-9]*"{" { // expand alias with arguments
                                     yyextra->lastBlockContext=YY_START;
				     yyextra->blockCount=1;
				     yyextra->aliasString=yytext;
				     yyextra->lastEscaped=0;
				     BEGIN( ReadAliasArgs );
  				   }
<ReadAliasArgs>^[ \t]*"//"[/!]/[^\n]+   { // skip leading special comments (see bug 618079)
  				   }
<ReadAliasArgs>"*/"		   { // oops, end of comment in the middle of an alias?
                                     if (yyextra->lang==SrcLangExt_Python)
				     {
				       REJECT;
				     }
				     else // abort the alias, restart scanning
				     {
				       copyToOutput(yyextra->aliasString,yyextra->aliasString.length(),yyscanner);
				       copyToOutput(yytext,(int)yyleng,yyscanner);
				       BEGIN(Scan);
				     }
  				   }
<ReadAliasArgs>[^{}\n\\\*]+	   {
                                     yyextra->aliasString+=yytext;
				     yyextra->lastEscaped=FALSE;
  				   }
<ReadAliasArgs>"\\"		   {
                                     if (yyextra->lastEscaped)  yyextra->lastEscaped=FALSE;
                                     else                yyextra->lastEscaped=TRUE;
                                     yyextra->aliasString+=yytext;
                                   }
<ReadAliasArgs>\n		   {
                                     yyextra->aliasString+=yytext;
                                     yyextra->lineNr++;
				     yyextra->lastEscaped=FALSE;
  				   }
<ReadAliasArgs>"{"		   {
                                     yyextra->aliasString+=yytext;
                                     if (!yyextra->lastEscaped) yyextra->blockCount++;
				     yyextra->lastEscaped=FALSE;
                                   }
<ReadAliasArgs>"}"		   {
                                     yyextra->aliasString+=yytext;
				     if (!yyextra->lastEscaped) yyextra->blockCount--;
				     if (yyextra->blockCount==0)
				     {
				       replaceAliases(yyextra->aliasString,yyscanner);
				       BEGIN( yyextra->lastBlockContext );
				     }
				     yyextra->lastEscaped=FALSE;
  			           }
<ReadAliasArgs>.		   {
                                     yyextra->aliasString+=yytext;
				     yyextra->lastEscaped=FALSE;
  				   }
<ReadLine>.			   {
  				     copyToOutput(yytext,(int)yyleng,yyscanner);
  				   }

%%

static void replaceCommentMarker(const char *s,int len,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  const char *p=s;
  char c;
  // copy leading blanks
  while ((c=*p) && (c==' ' || c=='\t' || c=='\n')) 
  {
    ADDCHAR(c);
    yyextra->lineNr += c=='\n';
    p++;
  }
  // replace start of comment marker by blanks and the last character by a *
  int blanks=0;
  while ((c=*p) && (c=='/' || c=='!' || c=='#')) 
  {
    blanks++;
    p++;
    if (*p=='<') // comment-after-item marker 
    { 
      blanks++;
      p++; 
    }
    if (c=='!') // end after first !
    {
      break;
    }
  }
  if (blanks>0)
  {
    while (blanks>2)
    {
      ADDCHAR(' ');
      blanks--;
    }
    if (blanks>1) ADDCHAR('*');
    ADDCHAR(' ');
  }
  // copy comment line to output
  ADDARRAY(p,len-(int)(p-s));
}

static inline int computeIndent(const char *s)
{
  int col=0;
  static int tabSize=Config_getInt(TAB_SIZE);
  const char *p=s;
  char c;
  while ((c=*p++))
  {
    if (c==' ') col++;
    else if (c=='\t') col+=tabSize-(col%tabSize); 
    else break;
  }
  return col;
}

static inline void copyToOutput(const char *s,int len,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  int i;
  if (yyextra->skip) // only add newlines.
  {
    for (i=0;i<len;i++) 
    {
      if (s[i]=='\n') 
      {
	ADDCHAR('\n');
	//fprintf(stderr,"---> skip %d\n",yyextra->lineNr);
	yyextra->lineNr++;
      }
    }
  }
  else if (len>0)
  {
    ADDARRAY(s,len);
    static int tabSize=Config_getInt(TAB_SIZE);
    for (i=0;i<len;i++) 
    {
      switch (s[i])
      {
	case '\n': yyextra->col=0; 
	           //fprintf(stderr,"---> copy %d\n",yyextra->lineNr);
		   yyextra->lineNr++; break;
	case '\t': yyextra->col+=tabSize-(yyextra->col%tabSize); break;
	default:   yyextra->col++; break;
      }
    }
  }
}

static void startCondSection(const char *sectId,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("startCondSection: skip=%d stack=%d\n",yyextra->skip,yyextra->condStack.count());
  CondParser prs;
  bool expResult = prs.parse(yyextra->fileName,yyextra->lineNr,sectId);
  yyextra->condStack.push(new CondCtx(yyextra->lineNr,sectId,yyextra->skip));
  if (!expResult) // not enabled
  {
    yyextra->skip=TRUE;
  }
}

static void endCondSection(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (yyextra->condStack.isEmpty())
  {
    warn(yyextra->fileName,yyextra->lineNr,"Found \\endcond command without matching \\cond");
    yyextra->skip=FALSE;
  }
  else
  {
    CondCtx *ctx = yyextra->condStack.pop();
    yyextra->skip=ctx->skip;
  }
  //printf("endCondSection: skip=%d stack=%d\n",yyextra->skip,yyextra->condStack.count());
}

/** copies string \a s with length \a len to the output, while 
 *  replacing any alias commands found in the string.
 */
static void replaceAliases(const char *s,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  QCString result = resolveAliasCmd(s);
  //printf("replaceAliases(%s)->'%s'\n",s,result.data());
  copyToOutput(result,result.length(),yyscanner);
}

static int yyread(char *buf,int max_size,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  int bytesInBuf = yyextra->inBuf->curPos()-yyextra->inBufPos;
  int bytesToCopy = QMIN(max_size,bytesInBuf);
  memcpy(buf,yyextra->inBuf->data()+yyextra->inBufPos,bytesToCopy);
  yyextra->inBufPos+=bytesToCopy;
  return bytesToCopy;
}

static void replaceComment(int offset,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (yyextra->mlBrief || yyextra->skip)
  {
    copyToOutput(yytext,(int)yyleng,yyscanner);
  }
  else
  {
    //printf("replaceComment(%s)\n",yytext);
    int i=computeIndent(&yytext[offset]);
    if (i==yyextra->blockHeadCol)
    {
      replaceCommentMarker(yytext,(int)yyleng,yyscanner);
    }
    else
    {
      copyToOutput(" */",3,yyscanner);
      int i;for (i=(int)yyleng-1;i>=0;i--) unput(yytext[i]);
      yyextra->inSpecialComment=FALSE;
      BEGIN(Scan);                                            
    }                                                         
  }
}

// simplified way to know if this is fixed form
// duplicate in fortrancode.l
static bool recognizeFixedForm(const char* contents)
{
  int column=0;
  bool skipLine=FALSE;

  for(int i=0;;i++) {
    column++;

    switch(contents[i]) {
      case '\n':
        column=0;
        skipLine=FALSE;
        break;
      case ' ':
        break;
      case '\000':
        return FALSE;
      case 'C':
      case 'c':
      case '*':
        if(column==1) return TRUE;
        if(skipLine) break;
        return FALSE;
      case '!':
        if(column>1 && column<7) return FALSE;
        skipLine=TRUE;
        break;
      default:
        if(skipLine) break;
        if(column==7) return TRUE;
        return FALSE;
    }
  }
  return FALSE;
}


// public interface -----------------------------------------------------------
static yyscan_t yyscanner;
static struct commentcnvYY_state commentcnv_extra;

/*! This function does three things:
 *  -# It converts multi-line C++ style comment blocks (that are aligned)
 *     to C style comment blocks (if MULTILINE_CPP_IS_BRIEF is set to NO).
 *  -# It replaces aliases with their definition (see ALIASES)
 *  -# It handles conditional sections (cond...endcond blocks)
 */
void convertCppComments(BufStr *inBuf,BufStr *outBuf,const char *fileName)
{
  commentcnvYYlex_init_extra(&commentcnv_extra, &yyscanner);
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;

  //printf("convertCppComments(%s)\n",fileName);
  yyextra->inBuf    = inBuf;
  yyextra->outBuf   = outBuf;
  yyextra->inBufPos = 0;
  yyextra->col      = 0;
  yyextra->mlBrief = Config_getBool(MULTILINE_CPP_IS_BRIEF);
  yyextra->skip     = FALSE;
  yyextra->fileName = fileName;
  yyextra->lang = getLanguageFromFileName(fileName);
  yyextra->pythonDocString = FALSE;
  yyextra->lineNr   = 1;
  yyextra->condStack.clear();
  yyextra->condStack.setAutoDelete(TRUE);
  yyextra->commentStack.clear();
  yyextra->commentStack.setAutoDelete(TRUE);
  yyextra->vhdl = FALSE;

  printlex(yy_flex_debug, TRUE, __FILE__, fileName);
  yyextra->isFixedForm = FALSE;
  if (yyextra->lang==SrcLangExt_Fortran)
  {
    yyextra->isFixedForm = recognizeFixedForm(inBuf->data());
  }

  if (yyextra->lang==SrcLangExt_Markdown)
  {
    yyextra->nestingCount=0;
    BEGIN(CComment);
    yyextra->commentStack.push(new CommentCtx(yyextra->lineNr));
  }
  else
  {
    BEGIN(Scan);
  }

  yylex(yyscanner);

  while (!yyextra->condStack.isEmpty())
  {
    CondCtx *ctx = yyextra->condStack.pop();
    QCString sectionInfo = " ";
    if (ctx->sectionId!=" ") sectionInfo.sprintf(" with label %s ",ctx->sectionId.data()); 
    warn(yyextra->fileName,ctx->lineNr,"Conditional section%sdoes not have "
	"a corresponding \\endcond command within this file.",sectionInfo.data());
  }
  if (yyextra->nestingCount>0 && yyextra->lang!=SrcLangExt_Markdown)
  {
    QCString tmp= "(probable line reference: ";
    bool first = TRUE;
    while (!yyextra->commentStack.isEmpty())
    {
      CommentCtx *ctx = yyextra->commentStack.pop();
      if (!first) tmp += ", ";
      tmp += QCString().setNum(ctx->lineNr);
      first = FALSE;
      delete ctx;
    }
    tmp += ")";
    warn(yyextra->fileName,yyextra->lineNr,"Reached end of file while still inside a (nested) comment. "
        "Nesting level %d %s",yyextra->nestingCount+1,tmp.data()); // add one for "normal" expected end of comment
  }
  yyextra->commentStack.clear();
  yyextra->nestingCount = 0;
  if (Debug::isFlagSet(Debug::CommentCnv))
  {
    yyextra->outBuf->at(yyextra->outBuf->curPos())='\0';
    msg("-------------\n%s\n-------------\n",yyextra->outBuf->data());
  }
  printlex(yy_flex_debug, FALSE, __FILE__, fileName);
}


//----------------------------------------------------------------------------
#if !defined(YY_FLEX_SUBMINOR_VERSION) 
extern "C" { // some bogus code to keep the compiler happy
    void commentcnvYYdummy() { yy_flex_realloc(0,0); } 
}
#endif

