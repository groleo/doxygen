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
/*  This code is based on the work done by the MoxyPyDoxy team
 *  (Linda Leong, Mike Rivera, Kim Truong, and Gabriel Estrada)
 *  in Spring 2005 as part of CS 179E: Compiler Design Project
 *  at the University of California, Riverside; the course was
 *  taught by Peter H. Froehlich <phf@acm.org>.
 */

%option never-interactive
%option prefix="pyscannerYY"
%option noyywrap
%option reentrant
%option extra-type="struct pyscannerYY_state *"

%{

/*
 *	includes
 */
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>

#include <qarray.h>
#include <qstack.h>
#include <qregexp.h>
#include <qfile.h>
#include <qfileinfo.h>
  
#include "pyscanner.h"
#include "entry.h"
#include "message.h"
#include "config.h"
#include "doxygen.h"
#include "util.h"
#include "defargs.h"
#include "language.h"
#include "commentscan.h"
#include "pycode.h"
#include "arguments.h"

// Toggle for some debugging info
//#define DBG_CTX(x) fprintf x
#define DBG_CTX(x) do { } while(0)

#define YY_NO_INPUT 1
#define YY_NO_UNISTD_H 1

/* -----------------------------------------------------------------
 *
 *	statics
 */

struct pyscannerYY_state
{
  ParserInterface *g_thisParser;
  const char      *inputString;
  int              inputPosition;
  QFile            inputFile;

  Protection       protection;

  Entry           *current_root = 0 ;
  Entry           *current      = 0 ;
  Entry           *previous     = 0 ;
  Entry           *bodyEntry    = 0 ;
  int              yyLineNr     = 1 ;
  QCString         yyFileName;
  MethodTypes      mtype;
  bool             gstat;
  Specifier        virt;

  int              docBlockContext;
  QCString         docBlock;
  bool             docBlockInBody;
  bool             docBlockJavaStyle;
  bool             docBrief;
  bool             docBlockSpecial;

  bool             g_doubleQuote;
  bool             g_specialBlock;
  int              g_stringContext;
  QGString        *g_copyString;
  int              g_indent = 0;
  int              g_curIndent = 0;

  QDict<QCString>  g_packageNameCache;

  char             g_atomStart;
  char             g_atomEnd;
  int              g_atomCount;

//  bool             g_insideConstructor;

  QCString         g_moduleScope;
  QCString         g_packageName;

//  bool             g_hideClassDocs;

  QCString         g_defVal;
  int              g_braceCount;

  bool             g_lexInit = FALSE;
  bool             g_packageCommentAllowed;

  bool             g_start_init = FALSE;
  int              g_search_count = 0;
};

//-----------------------------------------------------------------------------
// forward declarations
static void initParser(yyscan_t yyscanner);
static void initEntry(yyscan_t yyscanner);
static void newEntry(yyscan_t yyscanner);
static void newVariable(yyscan_t yyscanner);
static void newFunction(yyscan_t yyscanner);
static inline int computeIndent(const char *s);
static QCString findPackageScopeFromPath(const QCString &path, yyscan_t yyscanner);
static QCString findPackageScope(const char *fileName, yyscan_t yyscanner);
static void lineCount(yyscan_t yyscanner);
static void incLineNr(yyscan_t yyscanner);
static void startCommentBlock(bool brief, yyscan_t yyscanner);
static void handleCommentBlock(const QCString &doc,bool brief, yyscan_t yyscanner);
static void endOfDef(int correction, yyscan_t yyscanner);
static inline void addToString(const char *s, yyscan_t yyscanner);
static void initTriDoubleQuoteBlock(yyscan_t yyscanner);
static void initTriSingleQuoteBlock(yyscan_t yyscanner);
static void initSpecialBlock(yyscan_t yyscanner);
static void searchFoundDef(yyscan_t yyscanner);
static void searchFoundClass(yyscan_t yyscanner);
static int yyread(char *buf,int max_size,yyscan_t yyscanner);
static void parseCompounds(Entry *rt, yyscan_t yyscanner);
static void parseMain(const char *fileName,const char *fileBuf,Entry *rt, yyscan_t yyscanner);
static void parsePrototype(const QCString &text, yyscan_t yyscanner);

%}

       /* start command character */



BB                [ \t]+
B                 [ \t]*
NEWLINE           \n
BN                [ \t\n]

DIGIT             [0-9]

HEXNUMBER         "0"[xX][0-9a-fA-F]+[lL]?
OCTNUMBER         "0"[0-7]+[lL]?
NUMBER            {DIGIT}+[lLjJ]?
INTNUMBER         {HEXNUMBER}|{OCTNUMBER}|{NUMBER}
FLOATNUMBER       {DIGIT}+"."{DIGIT}+([eE][+\-]?{DIGIT}+)?[jJ]?
BOOL              ("True"|"False")
LETTER            [A-Za-z\x80-\xFF]
NONEMPTY          [A-Za-z0-9_\x80-\xFF]
EXPCHAR           [#(){}\[\],:.%/\\=`*~|&<>!;+-]
NONEMPTYEXP       [^ \t\n:]
PARAMNONEMPTY     [^ \t\n():]
IDENTIFIER        ({LETTER}|"_")({LETTER}|{DIGIT}|"_")*  
SCOPE             {IDENTIFIER}("."{IDENTIFIER})*
BORDER            ([^A-Za-z0-9])

TRISINGLEQUOTE    {STRINGPREFIX}?"'''"(!)?
TRIDOUBLEQUOTE    {STRINGPREFIX}?"\"\"\""(!)?
ENDTRISINGLEQUOTE "'''"
ENDTRIDOUBLEQUOTE "\"\"\""
LONGSTRINGCHAR    [^\\"']
ESCAPESEQ         ("\\")(.)
LONGSTRINGITEM    ({LONGSTRINGCHAR}|{ESCAPESEQ})
SMALLQUOTE        ("\"\""|"\""|"'"|"''")
LONGSTRINGBLOCK   ({LONGSTRINGITEM}+|{SMALLQUOTE})

SHORTSTRING       ("'"{SHORTSTRINGITEM}*"'"|'"'{SHORTSTRINGITEM}*'"')
SHORTSTRINGITEM   ({SHORTSTRINGCHAR}|{ESCAPESEQ})
SHORTSTRINGCHAR   [^\\\n"]
STRINGLITERAL     {STRINGPREFIX}?( {SHORTSTRING} | {LONGSTRING})  
STRINGPREFIX      ("r"|"u"|"ur"|"R"|"U"|"UR"|"Ur"|"uR")
KEYWORD           ("lambda"|"import"|"class"|"assert"|"as"|"from"|"global"|"def"|"True"|"False")
FLOWKW            ("or"|"and"|"is"|"not"|"print"|"for"|"in"|"if"|"try"|"except"|"yield"|"raise"|"break"|"continue"|"pass"|"if"|"return"|"while"|"elif"|"else"|"finally")
POUNDCOMMENT      "#"[^#\n][^\n]* 
SCRIPTCOMMENT      "#!".* 

STARTDOCSYMS      "##"


  /* Main start state */

%x Search
%x SearchMemVars

  /* Mid-comment states */

  /* %x FuncDoubleComment */
  /* %x ClassDoubleComment */
%x TryClassDocString
%x TripleComment
%x SpecialComment

  /* Function states */

%x FunctionDec
%x FunctionParams
%x FunctionBody
%x FunctionParamDefVal

  /* Class states */

%x ClassDec
%x ClassInheritance
%x ClassCaptureIndent
%x ClassBody

  /* Variable states */
%x VariableDec
%x VariableEnd
%x VariableAtom

  /* String states */

%x SingleQuoteString
%x DoubleQuoteString
%x TripleString

  /* import */
%x FromMod
%x FromModItem
%x Import

%%

  /* ------------ Function recognition rules -------------- */

<Search>{

    ^{B}"def"{BB}       { // start of a function/method definition with indent
      			  DBG_CTX((stderr,"Found def at %d\n",yyextra->yyLineNr));
      			  yyextra->g_indent=computeIndent(yytext);
			  searchFoundDef(yyscanner);
			  BEGIN( FunctionDec );
      			}
    "def"{BB}           { // start of a function/method definition
			  searchFoundDef(yyscanner);
			  BEGIN( FunctionDec );
                        }

     ^{B}"class"{BB}	{ // start of a class definition with indent
       			  DBG_CTX((stderr,"Found class at %d\n",yyextra->yyLineNr));
      			  yyextra->g_indent=computeIndent(yytext);
			  searchFoundClass(yyscanner);
			  BEGIN( ClassDec ) ;
       			}
     "class"{BB}        {  // start of a class definition
			  searchFoundClass(yyscanner);
			  BEGIN( ClassDec ) ;
                       }
     ^{B}"from"{BB}    |
     "from"{BB}	       { // start of an from import
			  yyextra->g_packageCommentAllowed = FALSE;
                          BEGIN( FromMod );
                       }

     ^{B}"import"{BB}  |
     "import"{BB}      { // start of an import statement
			  yyextra->g_packageCommentAllowed = FALSE;
                          BEGIN( Import );
                       }
     ^{B}{IDENTIFIER}/{B}"="{B}"property" { // property
      			yyextra->current->section   = Entry::VARIABLE_SEC;
  			yyextra->current->mtype     = Property;
			yyextra->current->name      = QCString(yytext).stripWhiteSpace();
			yyextra->current->fileName  = yyextra->yyFileName;
			yyextra->current->startLine = yyextra->yyLineNr;
			yyextra->current->bodyLine  = yyextra->yyLineNr;
			yyextra->g_packageCommentAllowed = FALSE;
			BEGIN(VariableDec);
       	              }
     ^{B}{IDENTIFIER}/{B}"="[^=] { // variable
                        if (yyextra->g_search_count) REJECT;
      			yyextra->g_indent=computeIndent(yytext);
      			yyextra->current->section   = Entry::VARIABLE_SEC;
			yyextra->current->name      = QCString(yytext).stripWhiteSpace();
			yyextra->current->fileName  = yyextra->yyFileName;
			yyextra->current->startLine = yyextra->yyLineNr;
			yyextra->current->bodyLine  = yyextra->yyLineNr;
			yyextra->g_packageCommentAllowed = FALSE;
			BEGIN(VariableDec);
      		      }
     {B}{IDENTIFIER}/({B},{B}{IDENTIFIER})*{B}")"*{B}"="[^=] { // list of variables, we cannot place the default value
                                                               // so we will skip it later on in a general rule
                                                               // Also note ")" this is to catch also (a,b). the "("
                                                               // is caught in the rule: [(], the ")" will be handled in [)]
                        if (yyextra->g_search_count > 1) REJECT;
      			yyextra->g_indent=computeIndent(yytext);
      			yyextra->current->section   = Entry::VARIABLE_SEC;
			yyextra->current->name      = QCString(yytext).stripWhiteSpace();
			yyextra->current->fileName  = yyextra->yyFileName;
			yyextra->current->startLine = yyextra->yyLineNr;
			yyextra->current->bodyLine  = yyextra->yyLineNr;
			yyextra->g_packageCommentAllowed = FALSE;
			newVariable(yyscanner);
      		      }
     "'"	      { // start of a single quoted string
       		        yyextra->g_stringContext=YY_START;
		        yyextra->g_copyString=0;
			yyextra->g_packageCommentAllowed = FALSE;
                        BEGIN( SingleQuoteString );
                      }
     "\""	      { // start of a double quoted string
       	                yyextra->g_stringContext=YY_START;
			yyextra->g_copyString=0;
			yyextra->g_packageCommentAllowed = FALSE;
                        BEGIN( DoubleQuoteString );
                      }
    "@staticmethod"  {
       			yyextra->gstat=TRUE;
      		      }
    {SCRIPTCOMMENT}   { // Unix type script comment
                        if (yyextra->yyLineNr != 1) REJECT;
      		      }
    {POUNDCOMMENT}    { // normal comment 
			yyextra->g_packageCommentAllowed = FALSE;
      		      }
    {IDENTIFIER}      { // some other identifier
			yyextra->g_packageCommentAllowed = FALSE;
		      }
    ^{BB}	      {
      			yyextra->g_curIndent=computeIndent(yytext);
                      }

    {NEWLINE}+        { // new line
                        lineCount(yyscanner);
                      }

    {TRIDOUBLEQUOTE}  { // start of a comment block
			initTriDoubleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {TRISINGLEQUOTE}  { // start of a comment block
			initTriSingleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {STARTDOCSYMS}/[^#]    {  // start of a special comment
      			yyextra->g_curIndent=computeIndent(yytext);
			yyextra->g_packageCommentAllowed = FALSE;
			initSpecialBlock(yyscanner);
			BEGIN(SpecialComment);
                      }
    [(]               { // we have to do something with (
                        yyextra->g_search_count += 1;
                      }
    [)]               { // we have to do something with )
                        yyextra->g_search_count -= 1;
                      }
    [^\n]             { // any other character...
                        // This is the major default
                        // that should catch everything
                        // else in Body.
                      }
}

<FromMod>{
  "."                 { // python3 style imports
                      }
  {IDENTIFIER}({B}"."{B}{IDENTIFIER})* { // from package import 
                        yyextra->g_packageName=yytext;
		      }
  "import"{B}	      {
    			BEGIN(FromModItem);
    		      }
  \n		      {
                        incLineNr(yyscanner);
                        BEGIN(Search);
                      }
  {B}		      {
		      }
  .                   {
                        unput(*yytext);
                        BEGIN(Search);
                      }
}

<FromModItem>{
  "*"		{ // import all
                  QCString item=yyextra->g_packageName;
		  yyextra->current->name=removeRedundantWhiteSpace(substitute(item,".","::"));
		  yyextra->current->fileName = yyextra->yyFileName; 
		  //printf("Adding using directive: found:%s:%d name=%s\n",yyextra->yyFileName.data(),yyextra->yyLineNr,yyextra->current->name.data());
		  yyextra->current->section=Entry::USINGDIR_SEC;
		  yyextra->current_root->addSubEntry(yyextra->current);
		  yyextra->current = new Entry ;
		  initEntry(yyscanner);
                  BEGIN(Search);
    		}
  {IDENTIFIER}/{B}","{B} {
                  QCString item=yyextra->g_packageName+"."+yytext;
		  yyextra->current->name=removeRedundantWhiteSpace(substitute(item,".","::"));
		  yyextra->current->fileName = yyextra->yyFileName; 
		  //printf("Adding using declaration: found:%s:%d name=%s\n",yyextra->yyFileName.data(),yyextra->yyLineNr,yyextra->current->name.data());
		  yyextra->current->section=Entry::USINGDECL_SEC;
		  yyextra->current_root->addSubEntry(yyextra->current);
		  yyextra->current = new Entry ;
		  initEntry(yyscanner);
		}
  {IDENTIFIER}  {
                  QCString item=yyextra->g_packageName+"."+yytext;
		  yyextra->current->name=removeRedundantWhiteSpace(substitute(item,".","::"));
		  yyextra->current->fileName = yyextra->yyFileName; 
		  //printf("Adding using declaration: found:%s:%d name=%s\n",yyextra->yyFileName.data(),yyextra->yyLineNr,yyextra->current->name.data());
		  yyextra->current->section=Entry::USINGDECL_SEC;
		  yyextra->current_root->addSubEntry(yyextra->current);
		  yyextra->current = new Entry ;
		  initEntry(yyscanner);
                  BEGIN(Search);
		}
  \n		{
                  incLineNr(yyscanner);
                  BEGIN(Search);
                }
  {B}		{
		}
  ","		{ 
  		}
  .             {
                  unput(*yytext);
                  BEGIN(Search);
                }
}

<Import>{
  {IDENTIFIER}({B}"."{B}{IDENTIFIER})* {
			yyextra->current->name=removeRedundantWhiteSpace(substitute(yytext,".","::"));
			yyextra->current->fileName = yyextra->yyFileName; 
			//printf("Adding using declaration: found:%s:%d name=%s\n",yyextra->yyFileName.data(),yyextra->yyLineNr,yyextra->current->name.data());
			yyextra->current->section=Entry::USINGDECL_SEC;
			yyextra->current_root->addSubEntry(yyextra->current);
			yyextra->current = new Entry ;
			initEntry(yyscanner);
			BEGIN(Search);
                      }
  \n		{
                  incLineNr(yyscanner);
                  BEGIN(Search);
                }
  {B}		{
		}
  .             {
                  unput(*yytext);
                  BEGIN(Search);
                }
}

<SearchMemVars>{
    "self."{IDENTIFIER}/{B}"=" {
                        DBG_CTX((stderr,"Found instance method variable %s in %s at %d\n",&yytext[5],yyextra->current_root->name.data(),yyextra->yyLineNr));
			yyextra->current->name=&yytext[5];
			yyextra->current->section=Entry::VARIABLE_SEC;
			yyextra->current->fileName  = yyextra->yyFileName;
			yyextra->current->startLine = yyextra->yyLineNr;
			yyextra->current->bodyLine  = yyextra->yyLineNr;
			yyextra->current->type.resize(0);
			if (yyextra->current->name.at(0)=='_') // mark as private
			{
			  yyextra->current->protection=Private;
			}
			newEntry(yyscanner);
                      }
    "cls."{IDENTIFIER}/{B}"=" {
                        DBG_CTX((stderr,"Found class method variable %s in %s at %d\n",&yytext[4],yyextra->current_root->name.data(),yyextra->yyLineNr));
			yyextra->current->name=&yytext[4];
			yyextra->current->section=Entry::VARIABLE_SEC;
			yyextra->current->fileName  = yyextra->yyFileName;
			yyextra->current->startLine = yyextra->yyLineNr;
			yyextra->current->bodyLine  = yyextra->yyLineNr;
			yyextra->current->type.resize(0);
			if (yyextra->current->name.at(0)=='_') // mark as private
			{
			  yyextra->current->protection=Private;
			}
			newEntry(yyscanner);
                      }
    {TRIDOUBLEQUOTE}  { // start of a comment block
			initTriDoubleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {TRISINGLEQUOTE}  { // start of a comment block
			initTriSingleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {STARTDOCSYMS}/[^#]    {  // start of a special comment
			initSpecialBlock(yyscanner);
			BEGIN(SpecialComment);
                      }
    {POUNDCOMMENT}    { // #
	              }
    "'"	              { // start of a single quoted string
       			yyextra->g_stringContext=YY_START;
			yyextra->g_copyString=0;
                        BEGIN( SingleQuoteString );
                      }
    "\""              { // start of a double quoted string
       			yyextra->g_stringContext=YY_START;
			yyextra->g_copyString=0;
                        BEGIN( DoubleQuoteString );
                      }
    \n		      { incLineNr(yyscanner); }
    {IDENTIFIER}      // identifiers
    [^'"\.#a-z_A-Z\n]+  // other uninteresting stuff
    .                 // anything else
}

<FunctionBody>{
    \n{B}/{IDENTIFIER}{BB}  {
                        DBG_CTX((stderr,"indent %d<=%d\n",computeIndent(&yytext[1]),yyextra->g_indent));
                        if (computeIndent(&yytext[1])<=yyextra->g_indent) 
			{
			  int i;
			  for (i=(int)yyleng-1;i>=0;i--)
			  {
			    unput(yytext[i]);
			  }
			  endOfDef(0,yyscanner);
			  //YY_CURRENT_BUFFER->yy_at_bol=TRUE;
                          BEGIN(Search);
			}
			else
			{
                          incLineNr(yyscanner);
      		          yyextra->current->program+=yytext;
			}
                      }
    \n{B}/"##"	      {
                        if (computeIndent(&yytext[1])<=yyextra->g_indent)
			{
			  int i;
			  for (i=(int)yyleng-1;i>=0;i--)
			  {
			    unput(yytext[i]);
			  }
			  endOfDef(0,yyscanner);
			  //YY_CURRENT_BUFFER->yy_at_bol=TRUE;
                          BEGIN(Search);
			}
			else
			{
			  incLineNr(yyscanner);
      		          yyextra->current->program+=yytext;
			}
      		      }
    <<EOF>>	      {
			endOfDef(0,yyscanner);
			yyterminate();
      		      }
    ^{BB}/\n	      { // skip empty line
      		        yyextra->current->program+=yytext;
      	              }
    ^{BB}	      { // something at indent >0
      		        yyextra->current->program+=yytext;
			yyextra->g_curIndent = computeIndent(yytext);
                        if (yyextra->g_curIndent<=yyextra->g_indent) 
			  // jumped out of the function
			{
			  endOfDef(1,yyscanner);
                          BEGIN(Search);
			}
      		      }
    "'"	              { // start of a single quoted string
      		        yyextra->current->program+=yytext;
       			yyextra->g_stringContext=YY_START;
		        yyextra->g_specialBlock = FALSE; 
			yyextra->g_copyString=&yyextra->current->program;
                        BEGIN( SingleQuoteString );
                      }
    "\""              { // start of a double quoted string
      		        yyextra->current->program+=yytext;
       			yyextra->g_stringContext=YY_START;
		        yyextra->g_specialBlock = FALSE; 
			yyextra->g_copyString=&yyextra->current->program;
                        BEGIN( DoubleQuoteString );
                      }
    [^ \t\n#'".]+     { // non-special stuff
      		        yyextra->current->program+=yytext;
		        yyextra->g_specialBlock = FALSE; 
                      }
    ^{POUNDCOMMENT}   { // normal comment 
      		        yyextra->current->program+=yytext;
      		      }
    "#".*             { // comment half way
      		        yyextra->current->program+=yytext;
                      }
    {NEWLINE}	      { 
			incLineNr(yyscanner); 
      		        yyextra->current->program+=yytext;
		      }
    .                 { // any character
      		        yyextra->current->program+=*yytext;
		        yyextra->g_specialBlock = FALSE; 
                      }

    {TRIDOUBLEQUOTE}  { // start of a comment block
			yyextra->current->program+=yytext;
			initTriDoubleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {TRISINGLEQUOTE}  { // start of a comment block
			yyextra->current->program+=yytext;
			initTriSingleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {STARTDOCSYMS}/[^#]  {  // start of a special comment
			initSpecialBlock(yyscanner);
			BEGIN(SpecialComment);
                      }
    
}

<FunctionDec>{

    {IDENTIFIER}            {
			      //found function name
			      if (yyextra->current->type.isEmpty()) 
			      {
				  yyextra->current->type = "def";
			      }
			      yyextra->current->name = yytext;
			      yyextra->current->name = yyextra->current->name.stripWhiteSpace();
			      newFunction(yyscanner);
                            }
    {B}":"		    { // function without arguments
			      yyextra->g_specialBlock = TRUE; // expecting a docstring
			      yyextra->bodyEntry = yyextra->current;
                              yyextra->current->bodyLine  = yyextra->yyLineNr;
                              BEGIN( FunctionBody );
			    }

    {B}"("                  {
			       BEGIN( FunctionParams );
		            }
}

<FunctionParams>{
    ({BB}|",")          {
                        }

    {IDENTIFIER}        { // Name of parameter
			  lineCount(yyscanner);
			  Argument *a = new Argument;
			  yyextra->current->argList->append(a);
			  yyextra->current->argList->getLast()->name = QCString(yytext).stripWhiteSpace();
			  yyextra->current->argList->getLast()->type = "";
                        }
    "="		        { // default value
                          // TODO: this rule is too simple, need to be able to
                          // match things like =")" as well!
			  yyextra->g_defVal.resize(0);
			  yyextra->g_braceCount=0;
			  BEGIN(FunctionParamDefVal);
      			}

     ")"                { // end of parameter list
        		  yyextra->current->args = argListToString(yyextra->current->argList);
                        }

     ":"{B}             {
			  yyextra->g_specialBlock = TRUE; // expecting a docstring
			  yyextra->bodyEntry = yyextra->current;
                          yyextra->current->bodyLine  = yyextra->yyLineNr;
                          BEGIN( FunctionBody );
                        }
    {POUNDCOMMENT}	{ // a comment
			}
    {PARAMNONEMPTY}     { // Default rule inside arguments.
                        }

}

<FunctionParamDefVal>{
     "("		{ // internal opening brace
       			  yyextra->g_braceCount++;
			  yyextra->g_defVal+=*yytext;
       			}
     ","		| 
     ")"		{
       			  if (yyextra->g_braceCount==0)  // end of default argument
			  {
			    if (yyextra->current->argList->getLast())
			    {
			      yyextra->current->argList->getLast()->defval=yyextra->g_defVal.stripWhiteSpace();
			    }
			    if (*yytext == ')')
			      yyextra->current->args = argListToString(yyextra->current->argList);
			    BEGIN(FunctionParams);
			  }
			  else // continue
			  {
			    if (*yytext == ')')yyextra->g_braceCount--;
			    yyextra->g_defVal+=*yytext;
			  }
       			}
     .			{
			    yyextra->g_defVal+=*yytext;
       			}
     \n                 {
       			    yyextra->g_defVal+=*yytext;
			    incLineNr(yyscanner);
       			}
}


<ClassBody>{
    \n/{IDENTIFIER}{BB}  { // new def at indent 0
                        incLineNr(yyscanner);
			endOfDef(0,yyscanner);
			//g_hideClassDocs = FALSE;
			//YY_CURRENT_BUFFER->yy_at_bol=TRUE;
                        BEGIN(Search);
                      }
    \n/"##"[^#]       {  // start of a special comment at indent 0
                        incLineNr(yyscanner);
			endOfDef(0,yyscanner);
			//g_hideClassDocs = FALSE;
			//YY_CURRENT_BUFFER->yy_at_bol=TRUE;
                        BEGIN(Search);
                      }
    ^{BB}/\n	      { // skip empty line
      		        yyextra->current->program+=yytext;
      	              }
    <<EOF>>	      {
			endOfDef(0,yyscanner);
			yyterminate();
      		      }
    ^{BB}	      { // something at indent >0
                        yyextra->g_curIndent=computeIndent(yytext);
			DBG_CTX((stderr,"yyextra->g_curIndent=%d yyextra->g_indent=%d\n",yyextra->g_curIndent,yyextra->g_indent));
                        if (yyextra->g_curIndent<=yyextra->g_indent) 
			  // jumped out of the class/method
			{
			  endOfDef(1,yyscanner);
			  yyextra->g_indent=yyextra->g_curIndent;
			  // make sure the next rule matches ^...
			  //YY_CURRENT_BUFFER->yy_at_bol=TRUE;
			  //g_hideClassDocs = FALSE;
                          BEGIN(Search);
			}
			else
			{
      		          yyextra->current->program+=yytext;
			}
      		      }
    "'"	              { // start of a single quoted string
      		        yyextra->current->program+=*yytext;
       			yyextra->g_stringContext=YY_START;
		        yyextra->g_specialBlock = FALSE; 
			yyextra->g_copyString=&yyextra->current->program;
                        BEGIN( SingleQuoteString );
                      }
    "\""              { // start of a double quoted string
      		        yyextra->current->program+=*yytext;
       			yyextra->g_stringContext=YY_START;
		        yyextra->g_specialBlock = FALSE; 
			yyextra->g_copyString=&yyextra->current->program;
                        BEGIN( DoubleQuoteString );
                      }
    [^ \t\n#'"]+      { // non-special stuff
      		        yyextra->current->program+=yytext;
		        yyextra->g_specialBlock = FALSE; 
			//g_hideClassDocs = FALSE;
                      }
    {NEWLINE}	      { 
      		        yyextra->current->program+=*yytext;
			incLineNr(yyscanner); 
		      }
    {POUNDCOMMENT}    { // normal comment
      		        yyextra->current->program+=yytext;
                      }
    .                 { // any character
		        yyextra->g_specialBlock = FALSE; 
      		        yyextra->current->program+=*yytext;
                      }
    {TRIDOUBLEQUOTE}  { // start of a comment block
      		        //if (!g_hideClassDocs) 
			yyextra->current->program+=yytext;
			initTriDoubleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {TRISINGLEQUOTE}  { // start of a comment block
      		        //if (!g_hideClassDocs) 
			yyextra->current->program+=yytext;
			initTriSingleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }
}

<ClassDec>{IDENTIFIER} {
			  if (yyextra->current->type.isEmpty()) 
			  {
			      yyextra->current->type = "class";
			  }

			  yyextra->current->section = Entry::CLASS_SEC;
			  yyextra->current->name = yytext;

			  // prepend scope in case of nested classes
			  if (yyextra->current_root->section&Entry::SCOPE_MASK)
			  {
			    //printf("*** Prepending scope %s to class %s\n",yyextra->current_root->name.data(),yyextra->current->name.data());
			    yyextra->current->name.prepend(yyextra->current_root->name+"::");
			  }
			  
			  yyextra->current->name = yyextra->current->name.stripWhiteSpace();
			  yyextra->current->fileName = yyextra->yyFileName;        
			  yyextra->docBlockContext   = YY_START;
			  yyextra->docBlockInBody    = FALSE;
			  yyextra->docBlockJavaStyle = FALSE;
			  yyextra->docBlock.resize(0);

			  BEGIN(ClassInheritance);                 
                        }

<ClassInheritance>{
   ({BB}|[\(,\)])      { // syntactic sugar for the list
                       }

    ":"                { // begin of the class definition
			 yyextra->g_specialBlock = TRUE; // expecting a docstring
                         yyextra->current->bodyLine  = yyextra->yyLineNr;
			 yyextra->current->program.resize(0);
      			 BEGIN(ClassCaptureIndent);
                       }

    {SCOPE}            {
                         yyextra->current->extends->append(
					      new BaseInfo(substitute(yytext,".","::"),Public,Normal)
					    );
                         //Has base class-do stuff
                       }
}


<ClassCaptureIndent>{
    "\n"|({BB}"\n")            {
                                 // Blankline - ignore, keep looking for indentation.
				 lineCount(yyscanner);
      				 yyextra->current->program+=yytext;
                               }

    {TRIDOUBLEQUOTE}           { // start of a comment block
				 initTriDoubleQuoteBlock(yyscanner);
      				 yyextra->current->program+=yytext;
			 	 BEGIN(TripleComment);
                      	       }

    {TRISINGLEQUOTE}           { // start of a comment block
			         initTriSingleQuoteBlock(yyscanner);
      				 yyextra->current->program+=yytext;
			         BEGIN(TripleComment);
                               }

    ^{BB} 		       {
      				 yyextra->current->program+=yytext;
			         //yyextra->current->startLine = yyextra->yyLineNr;
				 yyextra->g_curIndent=computeIndent(yytext);
				 yyextra->bodyEntry = yyextra->current;
				 DBG_CTX((stderr,"setting indent %d\n",yyextra->g_curIndent));
				 //printf("yyextra->current->program=[%s]\n",yyextra->current->program.data());
				 //g_hideClassDocs = TRUE;
			         BEGIN(ClassBody);
                               }

    ""/({NONEMPTY}|{EXPCHAR})  {
				 
				 // Just pushback an empty class, and
				 // resume parsing the body.
                                 newEntry(yyscanner);
      				 yyextra->current->program+=yytext;

				 // printf("Failed to find indent - skipping!");
				 BEGIN( Search );
                               }
}


<VariableDec>{
   "="                { // the assignment operator
                        //printf("====== VariableDec at line %d\n",yyextra->yyLineNr);
                        yyextra->g_start_init = TRUE;
			yyextra->current->initializer = yytext;
			yyextra->current->initializer += " ";
                      }
   {B}                { // spaces
			yyextra->current->initializer += yytext;
	              }
   {INTNUMBER}	      { // integer value
			if (yyextra->current-> type.isEmpty()) yyextra->current->type = "int";
			yyextra->current->initializer += yytext;
		      }
   {FLOATNUMBER}      { // floating point value
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "float";
			yyextra->current->initializer += yytext;
		      }
   {BOOL}             { // boolean value
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "bool";
			yyextra->current->initializer += yytext;
		      }
   {STRINGPREFIX}?"'" { // string
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "string";
			yyextra->current->initializer += yytext;
			yyextra->g_copyString=&yyextra->current->initializer;
       			yyextra->g_stringContext=VariableDec;
                        BEGIN( SingleQuoteString );
     		      }
   {STRINGPREFIX}?"\"" { // string
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "string";
			yyextra->current->initializer += yytext;
			yyextra->g_copyString=&yyextra->current->initializer;
       			yyextra->g_stringContext=VariableDec;
                        BEGIN( DoubleQuoteString );
     		      }
   {TRIDOUBLEQUOTE}   { // start of a comment block
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "string";
			yyextra->current->initializer += yytext;
			yyextra->g_doubleQuote=TRUE;
			yyextra->g_copyString=&yyextra->current->initializer;
       			yyextra->g_stringContext=VariableDec;
			BEGIN(TripleString);
                      }

   {TRISINGLEQUOTE}   { // start of a comment block
			if (yyextra->current->type.isEmpty()) yyextra->current->type = "string";
			yyextra->current->initializer += yytext;
			yyextra->g_doubleQuote=FALSE;
			yyextra->g_copyString=&yyextra->current->initializer;
       			yyextra->g_stringContext=VariableDec;
			BEGIN(TripleString);
                      }
   "("		      { // tuple, only when direct after =
                        if (yyextra->current->mtype!=Property && yyextra->g_start_init)
			{
			  yyextra->current->type = "tuple";
			}
      		        yyextra->current->initializer+=*yytext;
                        yyextra->g_atomStart='(';
			yyextra->g_atomEnd=')';
			yyextra->g_atomCount=1;
			BEGIN( VariableAtom );
                      }
   "["                { // list
                        if (yyextra->g_start_init) yyextra->current->type = "list";
      		        yyextra->current->initializer+=*yytext;
                        yyextra->g_atomStart='[';
			yyextra->g_atomEnd=']';
			yyextra->g_atomCount=1;
			BEGIN( VariableAtom );
                      }
   "{"		      { // dictionary
                        if (yyextra->g_start_init) yyextra->current->type = "dictionary";
      		        yyextra->current->initializer+=*yytext;
                        yyextra->g_atomStart='{';
			yyextra->g_atomEnd='}';
			yyextra->g_atomCount=1;
			BEGIN( VariableAtom );
                      }
   "#".*              { // comment
                        BEGIN( VariableEnd ); 
                      }
   {IDENTIFIER}	      {
			// do something based on the type of the IDENTIFIER
			if (yyextra->current->type.isEmpty())
                        {
                          QListIterator<Entry> eli(*(yyextra->current_root->children()));
                          Entry *child;
                          for (eli.toFirst();(child=eli.current());++eli)
                          {
                            if (child->name == QCString(yytext))
                            {
                               yyextra->current->type = child->type;
                               break;
                            }
                          }
                        }
                        yyextra->g_start_init = FALSE;
      		        yyextra->current->initializer+=yytext;
	              }
   .		      {
                        yyextra->g_start_init = FALSE;
      		        yyextra->current->initializer+=*yytext;
                      }
   \n		      {
     		        unput('\n');
     			BEGIN( VariableEnd );
     		      }
}

<VariableAtom>{
    [\(\[\{]	      {
      		        yyextra->current->initializer+=*yytext;
                        if (yyextra->g_atomStart==*yytext)
			{
			  yyextra->g_atomCount++;
			}
                      }
    [\)\]\}]	      {
      		        yyextra->current->initializer+=*yytext;
                        if (yyextra->g_atomEnd==*yytext)
			{
			  yyextra->g_atomCount--;
			}
			if (yyextra->g_atomCount==0)
			{
                          yyextra->g_start_init = FALSE;
			  BEGIN(VariableDec);
			}
                      }
    {TRIDOUBLEQUOTE}  { // start of a comment block
                        yyextra->g_specialBlock = FALSE;
			yyextra->current->program+=yytext;
			initTriDoubleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }

    {TRISINGLEQUOTE}  { // start of a comment block
                        yyextra->g_specialBlock = FALSE;
			yyextra->current->program+=yytext;
			initTriSingleQuoteBlock(yyscanner);
			BEGIN(TripleComment);
                      }
   "'"	              {
       			yyextra->g_stringContext=YY_START;
			yyextra->current->initializer+="'";
			yyextra->g_copyString=&yyextra->current->initializer;
                        BEGIN( SingleQuoteString );
                      }
   "\""	              {
       			yyextra->g_stringContext=YY_START;
			yyextra->current->initializer+="\"";
			yyextra->g_copyString=&yyextra->current->initializer;
                        BEGIN( DoubleQuoteString );
                      }
   {IDENTIFIER}       {
      		        yyextra->current->initializer+=yytext;
	              }
   .		      {
      		        yyextra->current->initializer+=*yytext;
                      }
   \n		      {
      		        yyextra->current->initializer+=*yytext;
     			incLineNr(yyscanner);
     		      }

}

<VariableEnd>{
    \n                {
                        incLineNr(yyscanner);
			newVariable(yyscanner);
                        BEGIN(Search);
                      }
    .		      { 
                        unput(*yytext);
			newVariable(yyscanner);
                        BEGIN(Search);
      		      }
    <<EOF>>           { yyterminate();
                        newEntry(yyscanner);
                      }
}

<TripleComment>{
    {ENDTRIDOUBLEQUOTE}   | 
    {ENDTRISINGLEQUOTE}   {
			  // printf("Expected module block %d special=%d\n",g_expectModuleDocs,yyextra->g_specialBlock);
			  if (yyextra->g_doubleQuote==(yytext[0]=='"')) 
			  {
			    if (yyextra->g_specialBlock) // expecting a docstring
			    {
			      QCString actualDoc=yyextra->docBlock;
			      if (!yyextra->docBlockSpecial) // legacy unformatted docstring
			      {
			        actualDoc.prepend("\\verbatim ");
			        actualDoc.append("\\endverbatim ");
			      }
			      //printf("-------> yyextra->current=%p yyextra->bodyEntry=%p\n",yyextra->current,yyextra->bodyEntry);
			      handleCommentBlock(actualDoc, FALSE, yyscanner);
			    }
			    else if (yyextra->g_packageCommentAllowed) // expecting module docs
			    {
			      QCString actualDoc=yyextra->docBlock;
			      if (!yyextra->docBlockSpecial) // legacy unformatted docstring
			      {
			        actualDoc.prepend("\\verbatim ");
			        actualDoc.append("\\endverbatim ");
			      }
			      actualDoc.prepend("\\namespace "+yyextra->g_moduleScope+"\\_linebr ");
			      handleCommentBlock(actualDoc, FALSE, yyscanner);
			    }
			    if ((yyextra->docBlockContext==ClassBody /*&& !g_hideClassDocs*/) ||
				yyextra->docBlockContext==FunctionBody)
			    {
			      yyextra->current->program+=yyextra->docBlock;
			      yyextra->current->program+=yytext;
			    }
                            //if (g_hideClassDocs)
			    //{
                            //  yyextra->current->startLine = yyextra->yyLineNr;
			    //}
			    //g_hideClassDocs=FALSE;
			    BEGIN(yyextra->docBlockContext);
			  }
                          else 
			  {
                            yyextra->docBlock += yytext;
                          }
			  yyextra->g_packageCommentAllowed = FALSE;
                        }


    ^{BB}		{ // leading whitespace
      			  int indent = computeIndent(yytext);
			  if (indent>=yyextra->g_curIndent)
			  { // strip yyextra->g_curIndent amount of whitespace
			    int i;
			    for (i=0;i<indent-yyextra->g_curIndent;i++) yyextra->docBlock+=' ';
			    DBG_CTX((stderr,"stripping indent %d\n",yyextra->g_curIndent));
			  }
			  else
			  {
			    DBG_CTX((stderr,"not stripping: %d<%d\n",indent,yyextra->g_curIndent));
			    yyextra->docBlock += yytext;
			  }
      			}
    [^"'\n \t\\]+       {
			  yyextra->docBlock += yytext;
                        }
    \n			{
      			  incLineNr(yyscanner);
			  yyextra->docBlock += yytext;
      			}
    \\.		        { // espaced char
			  yyextra->docBlock += yytext;
      			}
    .			{
			  yyextra->docBlock += yytext;
      			}
}

<SpecialComment>{
    ^{B}"#"("#")*	{ // skip leading hashes
      			}
    \n/{B}"#"		{ // continuation of the comment on the next line
      			  yyextra->docBlock+='\n';
			  yyextra->docBrief = FALSE;
                          startCommentBlock(FALSE, yyscanner);
			  incLineNr(yyscanner);
      			}
    [^#\n]+             { // any other stuff
      			  yyextra->docBlock+=yytext;
      			}
    \n			{ // new line that ends the comment
			  handleCommentBlock(yyextra->docBlock, yyextra->docBrief, yyscanner);
      			  incLineNr(yyscanner);
			  BEGIN(yyextra->docBlockContext);
      			}
    .			{ // anything we missed
      			  yyextra->docBlock+=*yytext;
      			}
}

<SingleQuoteString>{
    \\{B}\n                    { // line continuation
      			         addToString(yytext, yyscanner);
      				 incLineNr(yyscanner);
                               }
    \\.			       { // espaced char
      			         addToString(yytext, yyscanner);
                               }
    "\"\"\""		       { // tripple double quotes
      			         addToString(yytext, yyscanner);
      			       }
    "'"			       { // end of the string
      			         addToString(yytext, yyscanner);
      		                 BEGIN(yyextra->g_stringContext);
                               }
    [^"'\n\\]+	               { // normal chars
      			         addToString(yytext, yyscanner);
                               }
    .			       { // normal char
      			         addToString(yytext, yyscanner);
                               }
}

<DoubleQuoteString>{
    \\{B}\n                    { // line continuation
      			         addToString(yytext, yyscanner);
      				 incLineNr(yyscanner);
                               }
    \\.			       { // espaced char
      			         addToString(yytext, yyscanner);
                               }
    "'''"		       { // tripple single quotes
      			         addToString(yytext, yyscanner);
      			       }
    "\""		       { // end of the string
      			         addToString(yytext, yyscanner);
      		                 BEGIN(yyextra->g_stringContext);
                               }
    [^"'\n\\]+	               { // normal chars
      			         addToString(yytext, yyscanner);
                               }
    .			       { // normal char
      			         addToString(yytext, yyscanner);
                               }
}

<TripleString>{
    {ENDTRIDOUBLEQUOTE}    | 
    {ENDTRISINGLEQUOTE}    {
                          *yyextra->g_copyString += yytext;
			  if (yyextra->g_doubleQuote==(yytext[0]=='"')) 
			  {
			    BEGIN(yyextra->g_stringContext);
			  }
                        }


    ({LONGSTRINGBLOCK}) {
			  lineCount(yyscanner);
                          *yyextra->g_copyString += yytext;
                        }
    \n			{
      			  incLineNr(yyscanner);
                          *yyextra->g_copyString += yytext;
      			}
    .			{
                          *yyextra->g_copyString += *yytext;
      			}
}

  /* ------------ End rules -------------- */

  /*
<*>({NONEMPTY}|{EXPCHAR}|{BB})           { // This should go one character at a time.
				 // printf("[pyscanner] '%s' [ state %d ]  [line %d] no match\n",
				 //       yytext, YY_START, yyextra->yyLineNr);

                               }
  */

<*>{NEWLINE}                   {
				 //printf("[pyscanner] %d NEWLINE [line %d] no match\n",
				 //       YY_START, yyextra->yyLineNr);

                                 lineCount(yyscanner);
                               }

<*>.                           {
				 //printf("[pyscanner] '%s' [ state %d ]  [line %d] no match\n",
				 //       yytext, YY_START, yyextra->yyLineNr);

                               }


%%

//----------------------------------------------------------------------------
static void initParser(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->protection = Public;
  yyextra->mtype = Method;
  yyextra->gstat = FALSE;
  yyextra->virt = Normal;
  yyextra->previous = 0;
  yyextra->g_packageCommentAllowed = TRUE;
  yyextra->g_packageNameCache.setAutoDelete(TRUE);
}

static void initEntry(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //yyextra->current->python = TRUE;
  yyextra->current->protection = yyextra->protection ;
  yyextra->current->mtype      = yyextra->mtype;
  yyextra->current->virt       = yyextra->virt;
  yyextra->current->stat       = yyextra->gstat;
  yyextra->current->lang       = SrcLangExt_Python; 
  yyextra->current->setParent(yyextra->current_root);
  initGroupInfo(yyextra->current);
  yyextra->gstat = FALSE;
}

static void newEntry(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->previous = yyextra->current;
  yyextra->current_root->addSubEntry(yyextra->current);
  yyextra->current = new Entry ;
  initEntry(yyscanner);
}

static void newVariable(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (!yyextra->current->name.isEmpty() && yyextra->current->name.at(0)=='_') // mark as private
  {
    yyextra->current->protection=Private;
  }
  if (yyextra->current_root->section&Entry::COMPOUND_MASK) // mark as class variable
  {
    yyextra->current->stat = TRUE;
  }
  newEntry(yyscanner);
}

static void newFunction(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (yyextra->current->name.left(2)=="__" && yyextra->current->name.right(2)=="__")
  {
    // special method name, see
    // http://docs.python.org/ref/specialnames.html
    yyextra->current->protection=Public;
  }
  else if (yyextra->current->name.at(0)=='_')
  {
    yyextra->current->protection=Private;
  }
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

static QCString findPackageScopeFromPath(const QCString &path, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  QCString *pScope = yyextra->g_packageNameCache.find(path);
  if (pScope)
  {
    return *pScope;
  }
  QFileInfo pf(path+"/__init__.py"); // found package initialization file
  if (pf.exists())
  {
    int i=path.findRev('/');
    if (i!=-1)
    {
      QCString scope = findPackageScopeFromPath(path.left(i), yyscanner);
      if (!scope.isEmpty())
      {
	scope+="::";
      }
      scope+=path.mid(i+1);
      yyextra->g_packageNameCache.insert(path,new QCString(scope));
      return scope;
    }
  }
  return "";
}
  
static QCString findPackageScope(const char *fileName, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (fileName==0) return "";
  QFileInfo fi(fileName);
  return findPackageScopeFromPath(fi.dirPath(TRUE).data(), yyscanner);
}

//-----------------------------------------------------------------------------

static void lineCount(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  DBG_CTX((stderr,"yyextra->yyLineNr=%d\n",yyextra->yyLineNr));
  for (const char *p = yytext; *p; ++p)
  {
    yyextra->yyLineNr += (*p == '\n') ;
  }
}

static void incLineNr(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  DBG_CTX((stderr,"yyextra->yyLineNr=%d\n",yyextra->yyLineNr));
  yyextra->yyLineNr++;
}

#if 0
// Appends the yyextra->current-name to yyextra->current-type;
// Destroys yyextra->current-name.
// Destroys yyextra->current->args and yyextra->current->argList
static void addType( Entry* yyextra->current )
{
    uint tl=yyextra->current->type.length();
    if ( tl>0 && !yyextra->current->name.isEmpty() && yyextra->current->type.at(tl-1)!='.') 
    {
      yyextra->current->type += ' ' ;
    }
    yyextra->current->type += yyextra->current->name ;
    yyextra->current->name.resize(0) ;
    tl=yyextra->current->type.length();
    if ( tl>0 && !yyextra->current->args.isEmpty() && yyextra->current->type.at(tl-1)!='.') 
    {
      yyextra->current->type += ' ' ;
    }
    yyextra->current->type += yyextra->current->args ;
    yyextra->current->args.resize(0) ;
    yyextra->current->argList->clear();
}

static QCString stripQuotes(const char *s)
{
  QCString name;
  if (s==0 || *s==0) return name;
  name=s;
  if (name.at(0)=='"' && name.at(name.length()-1)=='"')
  {
    name=name.mid(1,name.length()-2);
  }
  return name;
}
#endif
//-----------------------------------------------------------------

//-----------------------------------------------------------------
static void startCommentBlock(bool brief, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (brief)
  {
    yyextra->current->briefFile = yyextra->yyFileName;
    yyextra->current->briefLine = yyextra->yyLineNr;
  }
  else
  {
    yyextra->current->docFile = yyextra->yyFileName;
    yyextra->current->docLine = yyextra->yyLineNr;
  }
}

/*
static void appendDocBlock() {
  yyextra->previous = yyextra->current;
  yyextra->current_root->addSubEntry(yyextra->current);
  yyextra->current = new Entry;
  initEntry(yyscanner);
}
*/

static void handleCommentBlock(const QCString &doc,bool brief, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("handleCommentBlock(doc=[%s] brief=%d yyextra->docBlockInBody=%d yyextra->docBlockJavaStyle=%d\n",
  //    doc.data(),brief,yyextra->docBlockInBody,yyextra->docBlockJavaStyle);

  // TODO: Fix me
  yyextra->docBlockInBody=FALSE;
  
  if (yyextra->docBlockInBody && yyextra->previous && !yyextra->previous->doc.isEmpty())
  {
    yyextra->previous->doc=yyextra->previous->doc.stripWhiteSpace()+"\n\n";
  }

  int position = 0;
  bool needsEntry;
  int lineNr = brief ? yyextra->current->briefLine : yyextra->current->docLine;
  while (parseCommentBlock(
	yyextra->g_thisParser,
	(yyextra->docBlockInBody && yyextra->previous) ? yyextra->previous : yyextra->current,
	doc,     // text
	yyextra->yyFileName, // file
	lineNr,
	yyextra->docBlockInBody ? FALSE : brief, 
    yyextra->docBlockJavaStyle, // javadoc style // or FALSE,
	yyextra->docBlockInBody,
	yyextra->protection,
        position,
        needsEntry)
     ) // need to start a new entry
  {
    if (needsEntry)
    {
      newEntry(yyscanner);
    }
  }
  if (needsEntry)
  {
    newEntry(yyscanner);
  }

}

static void endOfDef(int correction, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("endOfDef at=%d\n",yyextra->yyLineNr);
  if (yyextra->bodyEntry)
  {
    yyextra->bodyEntry->endBodyLine  = yyextra->yyLineNr-correction;
    yyextra->bodyEntry = 0;
  }
  newEntry(yyscanner);
  //g_insideConstructor = FALSE;
}

static inline void addToString(const char *s, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (yyextra->g_copyString) (*yyextra->g_copyString)+=s;
}

static void initTriDoubleQuoteBlock(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->docBlockContext   = YY_START;
  yyextra->docBlockInBody    = FALSE;
  yyextra->docBlockJavaStyle = TRUE;
  yyextra->docBlockSpecial   = yytext[strlen(yytext) - 1]=='!';
  yyextra->docBlock.resize(0);
  yyextra->g_doubleQuote = TRUE;
  startCommentBlock(FALSE, yyscanner);
}

static void initTriSingleQuoteBlock(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->docBlockContext   = YY_START;
  yyextra->docBlockInBody    = FALSE;
  yyextra->docBlockJavaStyle = TRUE;
  yyextra->docBlockSpecial   = yytext[strlen(yytext) - 1]=='!';
  yyextra->docBlock.resize(0);
  yyextra->g_doubleQuote = FALSE;
  startCommentBlock(FALSE, yyscanner);
}

static void initSpecialBlock(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->docBlockContext   = YY_START;
  yyextra->docBlockInBody    = FALSE;
  yyextra->docBlockJavaStyle = TRUE;
  yyextra->docBrief = TRUE;
  yyextra->docBlock.resize(0);
  startCommentBlock(TRUE, yyscanner);
}

static void searchFoundDef(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->current->fileName  = yyextra->yyFileName;
  yyextra->current->startLine = yyextra->yyLineNr;
  yyextra->current->bodyLine  = yyextra->yyLineNr;
  yyextra->current->section = Entry::FUNCTION_SEC;
  yyextra->current->lang = SrcLangExt_Python;
  yyextra->current->virt = Normal;
  yyextra->current->stat = yyextra->gstat;
  yyextra->current->mtype = yyextra->mtype = Method;
  yyextra->current->type.resize(0);
  yyextra->current->name.resize(0);
  yyextra->current->args.resize(0);
  yyextra->current->argList->clear();
  yyextra->g_packageCommentAllowed = FALSE;
  yyextra->gstat=FALSE;
  //printf("searchFoundDef at=%d\n",yyextra->yyLineNr);
}

static void searchFoundClass(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->current->section = Entry::CLASS_SEC;
  yyextra->current->argList->clear();
  yyextra->current->type += "class" ;
  yyextra->current->fileName  = yyextra->yyFileName;
  yyextra->current->startLine  = yyextra->yyLineNr;
  yyextra->current->bodyLine  = yyextra->yyLineNr;
  yyextra->g_packageCommentAllowed = FALSE;
}

//-----------------------------------------------------------------------------
/* ----------------------------------------------------------------- */
#undef	YY_INPUT
#define	YY_INPUT(buf,result,max_size) result=yyread(buf,max_size,yyscanner);

static int yyread(char *buf,int max_size, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  int c=0;
  while ( c < max_size && yyextra->inputString[yyextra->inputPosition] )
  {
    *buf = yyextra->inputString[yyextra->inputPosition++] ;
    //printf("%d (%c)\n",*buf,*buf);
    c++; buf++;
  }
  return c;
}




static void parseCompounds(Entry *rt, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("parseCompounds(%s)\n",rt->name.data());
  EntryListIterator eli(*rt->children());
  Entry *ce;
  for (;(ce=eli.current());++eli)
  {
    if (!ce->program.isEmpty())
    {
      //printf("-- %s ---------\n%s\n---------------\n",
      //  ce->name.data(),ce->program.data());
      // init scanner state
      yyextra->inputString = ce->program;
      yyextra->inputPosition = 0;
      pyscannerYYrestart( yyin, yyscanner ) ;
      if (ce->section&Entry::COMPOUND_MASK)
      {
        yyextra->current_root = ce ;
        BEGIN( Search );
      }
      else if (ce->parent())
      {
        yyextra->current_root = ce->parent();
	//printf("Searching for member variables in %s parent=%s\n",
	//    ce->name.data(),ce->parent->name.data());
	BEGIN( SearchMemVars );
      }
      yyextra->yyFileName = ce->fileName;
      yyextra->yyLineNr   = ce->bodyLine ;
      if (yyextra->current) delete yyextra->current;
      yyextra->current = new Entry;
      initEntry(yyscanner);

      groupEnterCompound(yyextra->yyFileName,yyextra->yyLineNr,ce->name);
      
      pyscannerYYlex(yyscanner) ;
      yyextra->g_lexInit=TRUE;
      delete yyextra->current; yyextra->current=0;
      ce->program.resize(0);

      groupLeaveCompound(yyextra->yyFileName,yyextra->yyLineNr,ce->name);

    }
    parseCompounds(ce, yyscanner);
  }
}

//----------------------------------------------------------------------------


static void parseMain(const char *fileName,const char *fileBuf,Entry *rt, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  initParser(yyscanner);

  yyextra->inputString = fileBuf;
  yyextra->inputPosition = 0;

  yyextra->protection    = Public;
  yyextra->mtype         = Method;
  yyextra->gstat         = FALSE;
  yyextra->virt          = Normal;
  yyextra->current_root  = rt;
  yyextra->g_specialBlock = FALSE;


  yyextra->inputFile.setName(fileName);
  if (yyextra->inputFile.open(IO_ReadOnly))
  {
    yyextra->yyLineNr= 1 ; 
    yyextra->yyFileName = fileName;
    //setContext();
    msg("Parsing file %s...\n",yyextra->yyFileName.data());

    QFileInfo fi(fileName);
    yyextra->g_moduleScope = findPackageScope(fileName, yyscanner);
    QCString baseName=fi.baseName().utf8();
    if (baseName!="__init__") // package initializer file is not a package itself
    {
      if (!yyextra->g_moduleScope.isEmpty())
      {
	yyextra->g_moduleScope+="::";
      }
      yyextra->g_moduleScope+=baseName;
    }

    yyextra->current            = new Entry;
    initEntry(yyscanner);
    yyextra->current->name      = yyextra->g_moduleScope;
    yyextra->current->section   = Entry::NAMESPACE_SEC;
    yyextra->current->type      = "namespace";
    yyextra->current->fileName  = yyextra->yyFileName;
    yyextra->current->startLine = yyextra->yyLineNr;
    yyextra->current->bodyLine  = yyextra->yyLineNr;

    rt->addSubEntry(yyextra->current);

    yyextra->current_root  = yyextra->current ;
    initParser(yyscanner);
    yyextra->current       = new Entry;

    groupEnterFile(yyextra->yyFileName,yyextra->yyLineNr);
    
    yyextra->current->reset();
    initEntry(yyscanner);
    pyscannerYYrestart( yyin, yyscanner );
    BEGIN( Search );
    pyscannerYYlex(yyscanner);
    yyextra->g_lexInit=TRUE;

    groupLeaveFile(yyextra->yyFileName,yyextra->yyLineNr);

    yyextra->current_root->program.resize(0);
    delete yyextra->current; yyextra->current=0;

    parseCompounds(yyextra->current_root, yyscanner);

    yyextra->inputFile.close();
  }
  
}

//----------------------------------------------------------------------------

static void parsePrototype(const QCString &text, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("**** parsePrototype(%s) begin\n",text.data());
  if (text.isEmpty()) 
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,"Empty prototype found!");
    return;
  }

  yyextra->g_specialBlock = FALSE;
  yyextra->g_packageCommentAllowed = FALSE;

  const char *orgInputString;
  int orgInputPosition;
  YY_BUFFER_STATE orgState;
  
  // save scanner state
  orgState = YY_CURRENT_BUFFER;
  yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE, yyscanner), yyscanner);
  orgInputString = yyextra->inputString; 
  orgInputPosition = yyextra->inputPosition;

  // set new string
  yyextra->inputString = text;
  yyextra->inputPosition = 0;
  pyscannerYYrestart( yyin, yyscanner );

  BEGIN( FunctionDec );

  pyscannerYYlex(yyscanner);
  yyextra->g_lexInit=TRUE;

  yyextra->current->name = yyextra->current->name.stripWhiteSpace();
  if (yyextra->current->section == Entry::MEMBERDOC_SEC && yyextra->current->args.isEmpty())
    yyextra->current->section = Entry::VARIABLEDOC_SEC;

  // restore original scanner state

  YY_BUFFER_STATE tmpBuf = YY_CURRENT_BUFFER;
  yy_switch_to_buffer(orgState, yyscanner);
  yy_delete_buffer(tmpBuf, yyscanner);

  yyextra->inputString = orgInputString; 
  yyextra->inputPosition = orgInputPosition;

  //printf("**** parsePrototype end\n");
}

// public interface -----------------------------------------------------------

static yyscan_t yyscanner;
static struct pyscannerYY_state pyscanner_extra;

void pyscanFreeScanner()
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
#if defined(YY_FLEX_SUBMINOR_VERSION) 
  if (yyextra->g_lexInit)
  {
    #warning pyscannerYYlex_destroy(yyscanner);
  }
#endif
}


void PythonLanguageScanner::parseInput(const char *fileName,
                                       const char *fileBuf,
                                       Entry *root,
                                       bool /*sameTranslationUnit*/,
                                       QStrList & /*filesInSameTranslationUnit*/)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->g_thisParser = this;
  printlex(yy_flex_debug, TRUE, __FILE__, fileName);
  ::parseMain(fileName,fileBuf,root, yyscanner);
  printlex(yy_flex_debug, FALSE, __FILE__, fileName);

  // May print the AST for debugging purposes
  // printAST(global_root);
}

bool PythonLanguageScanner::needsPreprocessing(const QCString &)
{
  return FALSE;
}

void PythonLanguageScanner::parseCode(CodeOutputInterface &codeOutIntf,
    const char *scopeName,
    const QCString &input,
    SrcLangExt /*lang*/,
    bool isExampleBlock,
    const char *exampleName,
    FileDef *fileDef,
    int startLine,
    int endLine,
    bool inlineFragment,
    MemberDef *memberDef,
    bool showLineNumbers,
    Definition *searchCtx,
    bool collectXRefs
    )
{
  ::parsePythonCode(codeOutIntf,scopeName,input,isExampleBlock,exampleName,
                    fileDef,startLine,endLine,inlineFragment,memberDef,
                    showLineNumbers,searchCtx,collectXRefs);
}

void PythonLanguageScanner::parsePrototype(const char *text)
{
  ::parsePrototype(text, yyscanner);

}

void PythonLanguageScanner::resetCodeParserState()
{
  ::resetPythonCodeParserState();
}

//----------------------------------------------------------------------------

#if !defined(YY_FLEX_SUBMINOR_VERSION) 
//----------------------------------------------------------------------------
extern "C" { // some bogus code to keep the compiler happy
  void pyscannerYYdummy() { yy_flex_realloc(0,0); } 
}
#endif

