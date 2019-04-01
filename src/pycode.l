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
%option prefix="pycodeYY"
%option noyywrap
%option stack

%option reentrant
%option extra-type="struct pycodeYY_state *"

%{

#include <stdio.h>
#include <qvaluestack.h>

#include "pycode.h"
#include "message.h"

#include "scanner.h"
#include "entry.h"
#include "doxygen.h"
#include "outputlist.h"
#include "util.h"
#include "membername.h"
#include "searchindex.h"
#include "config.h"
#include "groupdef.h"
#include "classlist.h"
#include "filedef.h"
#include "namespacedef.h"
#include "tooltip.h"

// Toggle for some debugging info
//#define DBG_CTX(x) fprintf x
#define DBG_CTX(x) do { } while(0)

#define YY_NO_INPUT 1
#define YY_NO_UNISTD_H 1


/*! Represents a stack of variable to class mappings as found in the
 *  code. Each scope is enclosed in pushScope() and popScope() calls.
 *  Variables are added by calling addVariables() and one can search
 *  for variable using findVariable().
 */
class PyVariableContext 
{
  public:
    class Scope : public SDict<ClassDef> 
    {
      public:
	Scope() : SDict<ClassDef>(17) {}
    };
    
    PyVariableContext() 
    {
      m_scopes.setAutoDelete(TRUE);
    }

    virtual ~PyVariableContext() 
    {
    }
    
    void pushScope() 
    {
      m_scopes.append(new Scope);
    }

    void popScope() 
    {
      if (m_scopes.count()>0) 
      {
	m_scopes.remove(m_scopes.count()-1);
      }
    }

    void clear() 
    {
      m_scopes.clear();
      m_globalScope.clear();
    }

    void clearExceptGlobal() 
    {
      m_scopes.clear();
    }

    void addVariable(const QCString &type,const QCString &name,yyscan_t yyscanner);
    ClassDef *findVariable(const QCString &name);
    
  private:
    Scope        m_globalScope;
    QList<Scope> m_scopes;
};


class PyCallContext
{
  public:
    struct Ctx
    {
      Ctx(QCString _name, QCString _type) : name(_name), type(_type), cd(0) {}
      QCString name;
      QCString type;
      ClassDef *cd;
    };

    PyCallContext()
    {
      m_classList.setAutoDelete(TRUE);
    }

    virtual ~PyCallContext() {}

    void setClass(ClassDef *cd)
    {
      Ctx *ctx = m_classList.getLast();
      if (ctx) 
      {
        ctx->cd=cd;
      }
    }
    void pushScope(QCString _name, QCString _type)
    {
      m_classList.append(new Ctx(_name,_type));
    }

    void popScope(QCString &_name, QCString &_type)
    {
      if (m_classList.count()>1)
      {
	Ctx *ctx = m_classList.getLast();
	if (ctx)
	{
	  _name = ctx->name;
	  _type = ctx->type;
	}
	m_classList.removeLast();
      }
      else
      {
      }
    }
    void clear()
    {
      m_classList.clear();
    }
    ClassDef *getClass() const
    {
      Ctx *ctx = m_classList.getLast();

      if (ctx)
        return ctx->cd;
      else
        return 0;
    }

  private:
    QList<Ctx> m_classList;    
};

struct pycodeYY_state
{
     ClassSDict    codeClassSDict;
     QCString      curClassName;
     QStrList      curClassBases;

     CodeOutputInterface * code;
     const char *  inputString;     //!< the code fragment as text
     int	     inputPosition;   //!< read offset during parsing 
     const char *  currentFontClass;
     bool          needsTermination;
     Definition   *searchCtx;
     bool          collectXRefs;
     int           inputLines;      //!< number of line in the code fragment
     int	     yyLineNr;        //!< current line number
     FileDef *     sourceFileDef;
     Definition *  currentDefinition;
     MemberDef *   currentMemberDef;
     bool          includeCodeFragment;
     QCString      realScope;
     //bool          insideBody;
     int           bodyCurlyCount;
     bool          searchingForBody;
     QCString      classScope;
     int           paramParens;
     //int           anchorCount;

     bool          exampleBlock;
     QCString      exampleName;

     QCString      type;
     QCString      name;

     bool          doubleStringIsDoc;
     bool          doubleQuote;
     bool          noSuiteFound;
     int           stringContext;

     QValueStack<uint> indents;  //!< Tracks indentation levels for scoping in python

     QCString      docBlock;     //!< contents of all lines of a documentation block
     bool          endComment;

     PyVariableContext theVarContext;
     PyCallContext theCallContext;
     const ClassDef *dummyContext = (ClassDef*)0x8;
};

static void endFontClass(yyscan_t yyscanner);
static void endCodeLine(yyscan_t yyscanner);
static void adjustScopesAndSuites(unsigned indentLength, yyscan_t yyscanner);

static void codify(const char* text,yyscan_t yyscanner);
static void codifyLines(char *text,yyscan_t yyscanner);
static void codifyLines(const QCString &str,yyscan_t yyscanner);
static void startFontClass(const char *s,yyscan_t yyscanner);
static void generateClassOrGlobalLink(CodeOutputInterface &ol,char *clName,
                                      bool typeOnly,
                                      yyscan_t yyscanner);
static void generateFunctionLink(CodeOutputInterface &ol,char *funcName,yyscan_t yyscanner);
static bool findMemberLink(CodeOutputInterface &ol,Definition *sym,const char *symName,yyscan_t yyscanner);
static void findMemberLink(CodeOutputInterface &ol,char *symName,yyscan_t yyscanner);


%}


BB                [ \t]+
B                 [ \t]*
NEWLINE           \n

DIGIT             [0-9]
LETTER            [A-Za-z\x80-\xFF]
NONEMPTY          [A-Za-z0-9_\x80-\xFF]
EXPCHAR           [#(){}\[\],:.%/\\=`*~|&<>!;+-]
NONEMPTYEXP       [^ \t\n:]
PARAMNONEMPTY     [^ \t\n():]
IDENTIFIER        ({LETTER}|"_")({LETTER}|{DIGIT}|"_")*  
BORDER            ([^A-Za-z0-9])

POUNDCOMMENT      "##"

TRISINGLEQUOTE    "'''"
TRIDOUBLEQUOTE    "\"\"\""
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
KEYWORD ("lambda"|"import"|"class"|"assert"|"as"|"from"|"global"|"def"|"True"|"False")
FLOWKW  ("or"|"and"|"is"|"not"|"print"|"for"|"in"|"if"|"try"|"except"|"yield"|"raise"|"break"|"continue"|"pass"|"if"|"return"|"while"|"elif"|"else"|"finally")
QUOTES            ("\""[^"]*"\"")
SINGLEQUOTES      ("'"[^']*"'")

LONGINTEGER       {INTEGER}("l"|"L")
INTEGER           ({DECIMALINTEGER}|{OCTINTEGER}|{HEXINTEGER})
DECIMALINTEGER    ({NONZERODIGIT}{DIGIT}*|"0")
OCTINTEGER        "0"{OCTDIGIT}+
HEXINTEGER        "0"("x"|"X"){HEXDIGIT}+  
NONZERODIGIT      [1-9]  
OCTDIGIT          [0-7]  
HEXDIGIT          ({DIGIT}|[a-f]|[A-F])
FLOATNUMBER       ({POINTFLOAT}|{EXPONENTFLOAT})
POINTFLOAT        ({INTPART}?{FRACTION}|{INTPART}".")  
EXPONENTFLOAT     ({INTPART}|{POINTFLOAT}){EXPONENT}
INTPART             {DIGIT}+  
FRACTION             "."{DIGIT}+  
EXPONENT             ("e"|"E")("+"|"-")?{DIGIT}+
IMAGNUMBER ({FLOATNUMBER}|{INTPART})("j"|"J")
ATOM              ({IDENTIFIER}|{LITERAL}|{ENCLOSURE})
ENCLOSURE             ({PARENTH_FORM}|{LIST_DISPLAY}|{DICT_DISPLAY}|{STRING_CONVERSION})
LITERAL             ({STRINGLITERAL}|{INTEGER}|{LONGINTEGER}|{FLOATNUMBER}|{IMAGNUMBER})
PARENTH_FORM       "("{EXPRESSION_LIST}?")"
TEST             ({AND_TEST}("or"{AND_TEST})*|{LAMBDA_FORM})
TESTLIST             {TEST}( ","{TEST})*","?
LIST_DISPLAY        "["{LISTMAKER}?"]"  
LISTMAKER             {EXPRESSION}({LIST_FOR}|(","{EXPRESSION})*","?)  
LIST_ITER             ({LIST_FOR}|{LIST_IF})  
LIST_FOR             "for"{EXPRESSION_LIST}"in"{TESTLIST}{LIST_ITER}?
LIST_IF             "if"{TEST}{LIST_ITER}?
DICT_DISPLAY             "\{"{KEY_DATUM_LIST}?"\}"
KEY_DATUM_LIST       {KEY_DATUM}(","{KEY_DATUM})*","? 
KEY_DATUM              {EXPRESSION}":"{EXPRESSION}
STRING_CONVERSION        "`"{EXPRESSION_LIST}"`"
PRIMARY             ({ATOM}|{ATTRIBUTEREF}|{SUBSCRIPTION}|{SLICING}|{CALL})
ATTRIBUTEREF             {PRIMARY}"."{IDENTIFIER}
SUBSCRIPTION             {PRIMARY}"["{EXPRESSION_LIST}"]"
SLICING            ({SIMPLE_SLICING}|{EXTENDED_SLICING})
SIMPLE_SLICING             {PRIMARY}"["{SHORT_SLICE}"]"  
EXTENDED_SLICING           {PRIMARY}"["{SLICE_LIST}"]" 
SLICE_LIST          {SLICE_ITEM}(","{SLICE_ITEM})*","?
SLICE_ITEM           ({EXPRESSION}|{PROPER_SLICE}|{ELLIPSIS})
PROPER_SLICE           ({SHORT_SLICE}|{LONG_SLICE})
SHORT_SLICE              {LOWER_BOUND}?":"{UPPER_BOUND}?  
LONG_SLICE             {SHORT_SLICE}":"{STRIDE}?
LOWER_BOUND             {EXPRESSION}  
UPPER_BOUND             {EXPRESSION}
STRIDE             {EXPRESSION}
ELLIPSIS             "..."
CALL             {PRIMARY}"("({ARGUMENT_LIST}","?)?")"
ARGUMENT_LIST       ({POSITIONAL_ARGUMENTS}(","{KEYWORD_ARGUMENTS})?(",""*"{EXPRESSION})?(",""**"{EXPRESSION})?|{KEYWORD_ARGUMENTS}(",""*"{EXPRESSION})?(",""**"{EXPRESSION})?|"*"{EXPRESSION}(",""**"{EXPRESSION})?|"**"{EXPRESSION})
POSITIONAL_ARGUMENTS             {EXPRESSION}(","{EXPRESSION})*
KEYWORD_ARGUMENTS              {KEYWORD_ITEM}(","{KEYWORD_ITEM})*
KEYWORD_ITEM           {IDENTIFIER}"="{EXPRESSION}
POWER             {PRIMARY}("**"{U_EXPR})?
U_EXPR            ({POWER}|"-"{U_EXPR}|"+"{U_EXPR}|"\~"{U_EXPR})
M_EXPR            ({U_EXPR}|{M_EXPR}"*"{U_EXPR}|{M_EXPR}"//"{U_EXPR}|{M_EXPR}"/"{U_EXPR}|{M_EXPR}"\%"{U_EXPR})
A_EXPR         ({M_EXPR}|{A_EXPR}"+"{M_EXPR}|{A_EXPR}"-"{M_EXPR}
SHIFT_EXPR            ({A_EXPR}|{SHIFT_EXPR}("<<"|">>"){A_EXPR})
AND_EXPR            ({SHIFT_EXPR}|{AND_EXPR}"\;SPMamp;"{SHIFT_EXPR}
XOR_EXPR            ({AND_EXPR}|{XOR_EXPR}"\textasciicircum"{AND_EXPR})
OR_EXPR            ({XOR_EXPR}|{OR_EXPR}"|"{ XOR_EXPR})

COMPARISON             {OR_EXPR}({COMP_OPERATOR}{OR_EXPR})*
COMP_OPERATOR         ("<"|">"|"=="|">="|"<="|"<>"|"!="|"is""not"?|"not"?"in")
EXPRESSION            ({OR_TEST}|{LAMBDA_FORM})
OR_TEST             ({AND_TEST}|{OR_TEST}"or"{AND_TEST})
AND_TEST          ({NOT_TEST}|{AND_TEST}"and"{NOT_TEST})
NOT_TEST           ({COMPARISON}|"not"{NOT_TEST})
LAMBDA_FORM       "lambda"{PARAMETER_LIST}?":"{EXPRESSION}
EXPRESSION_LIST      {EXPRESSION}(","{EXPRESSION})*","?
SIMPLE_STMT       ({EXPRESSION_STMT}|{ASSERT_STMT}|{ASSIGNMENT_STMT}|{AUGMENTED_ASSIGNMENT_STMT}|{PASS_STMT}|{DEL_STMT}|{PRINT_STMT}|{RETURN_STMT}|{YIELD_STMT}|{RAISE_STMT}|{BREAK_STMT}|{CONTINUE_STMT}|{IMPORT_STMT}|{GLOBAL_STMT}|{EXEC_STMT})
EXPRESSION_STMT     {EXPRESSION_LIST}
ASSERT_STMT             "assert"{EXPRESSION}(","{EXPRESSION})?
ASSIGNMENT_STMT     ({TARGET_LIST}"=")+{EXPRESSION_LIST}
TARGET_LIST             {TARGET}(","{TARGET})*","?
TARGET           ({IDENTIFIER}|"("{TARGET_LIST}")"|"["{TARGET_LIST}"]"|{ATTRIBUTEREF}|{SUBSCRIPTION}|{SLICING})


%x Body

%x FunctionDec
%x FunctionParams

%x ClassDec
%x ClassInheritance

%x Suite
%x SuiteCaptureIndent
%x SuiteStart
%x SuiteMaintain
%x SuiteContinuing

%x LongString

%x SingleQuoteString
%x DoubleQuoteString
%x TripleString

%x DocBlock
%%

<Body,Suite>{
      "def"{BB}                     {
				        startFontClass("keyword",yyscanner);
					codify(yytext,yyscanner);
					endFontClass(yyscanner);
					BEGIN( FunctionDec );
		                    }

      "class"{BB}                   {
				        startFontClass("keyword",yyscanner);
					codify(yytext,yyscanner);
					endFontClass(yyscanner);
					BEGIN( ClassDec );
		                    }
      "None"                        {
				        startFontClass("keywordtype",yyscanner);
					codify(yytext,yyscanner);
					endFontClass(yyscanner);
				    }
      "self."{IDENTIFIER}/"."({IDENTIFIER}".")*{IDENTIFIER}"(" {
				        codify("self.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[5],yyscanner);
	                            }
      "self."{IDENTIFIER}/"("       {
				        codify("self.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[5],yyscanner);
	                            }
      "self."{IDENTIFIER}/"."({IDENTIFIER}".")*{IDENTIFIER} {
				        codify("self.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[5],yyscanner);
	                            }
      "self."{IDENTIFIER}           {
				        codify("self.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[5],yyscanner);
	                            }
      "cls."{IDENTIFIER}/"."({IDENTIFIER}".")*{IDENTIFIER}"(" {
				        codify("cls.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[4],yyscanner);
	                            }
      "cls."{IDENTIFIER}/"("       {
				        codify("cls.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[4],yyscanner);
	                            }
      "cls."{IDENTIFIER}/"."({IDENTIFIER}".")*{IDENTIFIER} {
				        codify("cls.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[4],yyscanner);
	                            }
      "cls."{IDENTIFIER}           {
				        codify("cls.",yyscanner);
				        findMemberLink(*yyextra->code,&yytext[4],yyscanner);
	                            }
}

<ClassDec>{IDENTIFIER}              {

					generateClassOrGlobalLink(*yyextra->code,yytext,FALSE,yyscanner);
					// codify(yytext,yyscanner);
					yyextra->curClassName = yytext;
					yyextra->curClassBases.clear();
					BEGIN( ClassInheritance );
		                    }

<ClassInheritance>{
   ({BB}|[(,)])                     {
					codify(yytext,yyscanner);
                                    }

   ({IDENTIFIER}".")*{IDENTIFIER}   {
                                        // The parser
					// is assuming
					// that ALL identifiers
					// in this state
					// are base classes;
					// it doesn't check to see
					// that the first parenthesis
					// has been seen.

					// This is bad - it should
					// probably be more strict
					// about what to accept.

                                        yyextra->curClassBases.inSort(yytext);
					generateClassOrGlobalLink(*yyextra->code,yytext,FALSE,yyscanner);
					// codify(yytext,yyscanner);
                                    }

    ":"                             {
				      codify(yytext,yyscanner);

				      // Assume this will
				      // be a one-line suite;
				      // found counter-example
				      // in SuiteStart.

                                      // Push a class scope

                                      ClassDef *classDefToAdd = new ClassDef("<code>",1,1,yyextra->curClassName,ClassDef::Class,0,0,FALSE);
                                      yyextra->codeClassSDict.append(yyextra->curClassName,classDefToAdd);
                                      char *s=yyextra->curClassBases.first();
                                      while (s) 
				      {
                                        ClassDef *baseDefToAdd;
                                        baseDefToAdd=yyextra->codeClassSDict[s];

					// Try to find class in global
					// scope
					if (baseDefToAdd==0) 
					{
					  baseDefToAdd=getResolvedClass(yyextra->currentDefinition,yyextra->sourceFileDef,s);
					}

					if (baseDefToAdd && baseDefToAdd!=classDefToAdd) 
					{
				          classDefToAdd->insertBaseClass(baseDefToAdd,s,Public,Normal);
					}

                                        s=yyextra->curClassBases.next();
			              }

				      // Reset class-parsing variables.
				      yyextra->curClassName.resize(0);
				      yyextra->curClassBases.clear();
				      
				      yyextra->noSuiteFound = TRUE;
				      BEGIN( SuiteStart );
                                    }
}


<FunctionDec>{
    {IDENTIFIER}                    {
                                        generateFunctionLink(*yyextra->code,yytext,yyscanner);
                                    }

    {B}"("                          {
				        codify(yytext,yyscanner);
					BEGIN( FunctionParams );
		                    }
}

<FunctionParams>{
    ({BB}|",")                      {
                                         // Parses delimiters
				         codify(yytext,yyscanner);
                                    }

    ({IDENTIFIER}|{PARAMNONEMPTY}+) {
				         codify(yytext,yyscanner);
                                    }

    ")"                             {
                                         codify(yytext,yyscanner);
                                    }

    "\n"                            {
				         codifyLines(yytext,yyscanner);
                                    }

    ":"                             {
				      codify(yytext,yyscanner);

				      // Assume this will
				      // be a one-line suite;
				      // found counter-example
				      // in SuiteStart.
				      yyextra->noSuiteFound = TRUE;
				      BEGIN( SuiteStart );
                                    }
}

<Body,Suite>{

    {KEYWORD}                  {
                                 // Position-sensitive rules!
                                 // Must come AFTER keyword-triggered rules
                                 // Must come BEFORE identifier NONEMPTY-like rules
                                 //   to syntax highlight.

  		                 startFontClass("keyword",yyscanner);
  		                 codify(yytext,yyscanner);
		                 endFontClass(yyscanner);
                               }

    {FLOWKW}                   {
  		                 startFontClass("keywordflow",yyscanner);
  		                 codify(yytext,yyscanner);
		                 endFontClass(yyscanner);
                               }
    ({IDENTIFIER}".")*{IDENTIFIER}/"("  {
				 generateClassOrGlobalLink(*yyextra->code,yytext,FALSE,yyscanner);
      			       }
    ({IDENTIFIER}".")+{IDENTIFIER} {
				 generateClassOrGlobalLink(*yyextra->code,yytext,TRUE,yyscanner);
			       }
    {IDENTIFIER}               { codify(yytext,yyscanner); }
		   	
}



<SuiteStart>{

    {BB}                               {
                                         codify(yytext,yyscanner);
                                       }
    "pass"			       {
                                          startFontClass("keyword",yyscanner);
					  codifyLines(yytext,yyscanner);
		                          endFontClass(yyscanner);
					  BEGIN(Body);
      				       }
    {KEYWORD}                          {
                                          startFontClass("keyword",yyscanner);
					  codifyLines(yytext,yyscanner);
		                          endFontClass(yyscanner);

					  // No indentation necessary
					  yyextra->noSuiteFound = FALSE;
                                       }

    {FLOWKW}                           {
                                          startFontClass("keywordflow",yyscanner);
					  codifyLines(yytext,yyscanner);
		                          endFontClass(yyscanner);

					  // No indentation necessary
					  yyextra->noSuiteFound = FALSE;
                                       }
    {IDENTIFIER}                       {
                                         codify(yytext,yyscanner);
				       } 


    {POUNDCOMMENT}                     {
  				         if (YY_START==SingleQuoteString || 
				             YY_START==DoubleQuoteString || 
				             YY_START==TripleString
				            )
				         {
				           REJECT;
				         }
                                         yy_push_state(YY_START, yyscanner);
				         BEGIN(DocBlock);
				         yyextra->docBlock=yytext;
                                       }

    {NEWLINE}                          {
					  codifyLines(yytext,yyscanner);
					  if ( yyextra->noSuiteFound ) 
					  {
                                            // printf("New suite to capture! [%d]\n", yyextra->yyLineNr);
					    BEGIN ( SuiteCaptureIndent );
					  }
                                       }
}

<SuiteCaptureIndent>{
    "\n"|({BB}"\n")            {
                                 // Blankline - ignore, keep looking for indentation.
				 codifyLines(yytext,yyscanner);
                               }

    {BB}                       {
                                 // This state lasts momentarily,
                                 // to check the indentation
                                 // level that is about to be
                                 // used.
				 codifyLines(yytext,yyscanner);
				 yyextra->indents.push(yyleng);
                                 // printf("Captured indent of %d [line %d]\n", yyleng, yyextra->yyLineNr);
				 BEGIN( Suite );
                               }
}

<SuiteMaintain>{

    {BB}/({NONEMPTY}|{EXPCHAR}) {
                                 // This implements poor
				 // indendation-tracking;
                                 // should be improved.
				 // (translate tabs to space, etc)
  		                 codifyLines(yytext,yyscanner);
                                 adjustScopesAndSuites((int)yyleng, yyscanner);
                               }

    "\n"|({BB}"\n")            {
                                 // If this ever succeeds,
				 // it means that this is
				 // a blank line, and
				 // can be ignored.
  		                 codifyLines(yytext,yyscanner);
                               }

    ""/({NONEMPTY}|{EXPCHAR})  {
                                 // Default rule; matches
				 // the empty string, assuming
				 // real text starts here.
				 // Just go straight to Body.
                                 adjustScopesAndSuites(0, yyscanner);
                               }
}


<Suite>{NEWLINE}               {
                                 codifyLines(yytext,yyscanner);
			         BEGIN( SuiteMaintain );
		               }
<Body>{IDENTIFIER}	       {
  			         codify(yytext,yyscanner);
                               }
<Body>{NEWLINE}                {
  		                 codifyLines(yytext,yyscanner);
                               }

<SingleQuoteString>{ // Single quoted string like 'That\'s a """nice""" string!'
    \\{B}\n                    { // line continuation
  		                 codifyLines(yytext,yyscanner);
                               }
    \\.			       { // espaced char
  		                 codify(yytext,yyscanner);
                               }
    {STRINGPREFIX}?{TRIDOUBLEQUOTE} { // tripple double quotes
  		                 codify(yytext,yyscanner);
      			       }
    "'"			       { // end of the string
  		                 codify(yytext,yyscanner);
				 endFontClass(yyscanner);
      		                 BEGIN(yyextra->stringContext);
                               }
    [^"'\n\\]+	               { // normal chars
  		                 codify(yytext,yyscanner);
                               }
    .			       { // normal char
  		                 codify(yytext,yyscanner);
                               }
}

<DoubleQuoteString>{ // Double quoted string like "That's \"a '''nice'''\" string!"
    \\{B}\n                    { // line continuation
  		                 codifyLines(yytext,yyscanner);
                               }
    \\.			       { // espaced char
  		                 codify(yytext,yyscanner);
                               }
    {STRINGPREFIX}?{TRISINGLEQUOTE} { // tripple single quotes
  		                 codify(yytext,yyscanner);
      			       }
    "\""		       { // end of the string
  		                 codify(yytext,yyscanner);
				 endFontClass(yyscanner);
      		                 BEGIN(yyextra->stringContext);
                               }
    [^"'\n\\]+	               { // normal chars
  		                 codify(yytext,yyscanner);
                               }
    .			       { // normal char
  		                 codify(yytext,yyscanner);
                               }
}

<TripleString>{
    {TRIDOUBLEQUOTE}   | 
    {TRISINGLEQUOTE}   {
  		          codify(yytext,yyscanner);
			  if (yyextra->doubleQuote==(yytext[0]=='"')) 
			  {
			    endFontClass(yyscanner);
			    BEGIN(yyextra->stringContext);
			  }
		       }
    {LONGSTRINGBLOCK}  {
			 codifyLines(yytext,yyscanner);
		       }
    \n		       {
			 codifyLines(yytext,yyscanner);
                       }
    .		       {
                         codify(yytext,yyscanner);
                       }
}

  /*
<*>({NONEMPTY}|{EXPCHAR}|{BB})           { // This should go one character at a time.
  		                 codify(yytext,yyscanner);
				 // printf("[pycode] '%s' [ state %d ]  [line %d] no match\n",
				 //       yytext, YY_START, yyextra->yyLineNr);

				 //endFontClass(yyscanner);
				 BEGIN(Body);					
                               }
   */

<*>{STRINGPREFIX}?{TRISINGLEQUOTE} |
<*>{STRINGPREFIX}?{TRIDOUBLEQUOTE} {
  				 startFontClass("stringliteral",yyscanner);
				 yyextra->stringContext=YY_START;
				 yyextra->doubleQuote=yytext[yyleng-1]=='"';
  		                 codify(yytext,yyscanner);
				 BEGIN(TripleString);
                               }
<*>{STRINGPREFIX}?"'"	       { // single quoted string
  				 startFontClass("stringliteral",yyscanner);
				 yyextra->stringContext=YY_START;
  		                 codify(yytext,yyscanner);
				 BEGIN(SingleQuoteString);
  			       }
<*>{STRINGPREFIX}?"\""         { // double quoted string
  				 startFontClass("stringliteral",yyscanner);
				 yyextra->stringContext=YY_START;
  		                 codify(yytext,yyscanner);
				 BEGIN(DoubleQuoteString);
                               }
<DocBlock>.*    	       { // contents of current comment line
                                 yyextra->docBlock+=yytext;
  			       }
<DocBlock>"\n"{B}("#")         { // comment block (next line is also comment line)
				 yyextra->docBlock+=yytext; 
   			       }
<DocBlock>{NEWLINE}            { // comment block ends at the end of this line
                                 // remove special comment (default config)
				 if (Config_getBool(STRIP_CODE_COMMENTS))
				 {
				    yyextra->yyLineNr+=((QCString)yyextra->docBlock).contains('\n');
				    yyextra->endComment=TRUE;
				  }
				  else // do not remove comment
				  {
				    startFontClass("comment",yyscanner);
				    codifyLines(yyextra->docBlock,yyscanner);
				    endFontClass(yyscanner);
				  }
				  unput(*yytext);
				  yy_pop_state(yyscanner);
			       }
<*>{POUNDCOMMENT}.*            {
  				 if (YY_START==SingleQuoteString || 
				     YY_START==DoubleQuoteString || 
				     YY_START==TripleString
				    )
				 {
				   REJECT;
				 }
                                 yy_push_state(YY_START, yyscanner);
				 BEGIN(DocBlock);
				 yyextra->docBlock=yytext;
                               }
<*>"#".*                       { // normal comment
  				 if (YY_START==SingleQuoteString || 
				     YY_START==DoubleQuoteString || 
				     YY_START==TripleString
				    )
				 {
				   REJECT;
				 }
                                 startFontClass("comment",yyscanner);
                                 codifyLines(yytext,yyscanner);
                                 endFontClass(yyscanner);
                               }
<*>{NEWLINE}                   {
				  if (yyextra->endComment)
				  {
				    yyextra->endComment=FALSE;
				  }
				  else
				  {
				    codifyLines(yytext,yyscanner);
				  }
				 //printf("[pycode] %d NEWLINE [line %d] no match\n",
				 //       YY_START, yyextra->yyLineNr);

				 //endFontClass(yyscanner);
				 BEGIN(Body);
                               }

<*>[ \t]+                      {
  		                 codify(yytext,yyscanner);
				 BEGIN(Body);					
  			       }
<*>.                           {
  		                 codify(yytext,yyscanner);
				 // printf("[pycode] '%s' [ state %d ]  [line %d] no match\n",
				 //        yytext, YY_START, yyextra->yyLineNr);

				 //endFontClass(yyscanner);
				 BEGIN(Body);					
                               }

<*><<EOF>>                     {
                                 if (YY_START == DocBlock) {
                                   if (!Config_getBool(STRIP_CODE_COMMENTS))
                                   {
                                     startFontClass("comment",yyscanner);
                                     codifyLines(yyextra->docBlock,yyscanner);
                                     endFontClass(yyscanner);
                                   }
                                 }
                                 yyterminate();
                               }
%%

/*@ ----------------------------------------------------------------------------
 */
void PyVariableContext::addVariable(const QCString &type,const QCString &name,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("PyVariableContext::addVariable(%s,%s)\n",type.data(),name.data());
  QCString ltype = type.simplifyWhiteSpace();
  QCString lname = name.simplifyWhiteSpace();

  Scope *scope = m_scopes.count()==0 ? &m_globalScope : m_scopes.getLast();
  ClassDef *varType;
  if (
      (varType=yyextra->codeClassSDict[ltype]) ||  // look for class definitions inside the code block
      (varType=getResolvedClass(yyextra->currentDefinition,yyextra->sourceFileDef,ltype)) // look for global class definitions
     ) 
  {
    scope->append(lname,varType); // add it to a list
  }
  else 
  {
    if (m_scopes.count()>0) // for local variables add a dummy entry so the name 
                            // is hidden to avoid FALSE links to global variables with the same name
                            // TODO: make this work for namespaces as well!
    {
      scope->append(lname,yyextra->dummyContext);
    }
  }
}

ClassDef *PyVariableContext::findVariable(const QCString &name)
{
  if (name.isEmpty()) return 0;
  ClassDef *result = 0;
  QListIterator<Scope> sli(m_scopes);
  Scope *scope;
  // search from inner to outer scope
  for (sli.toLast();(scope=sli.current());--sli)
  {
    result = scope->find(name);
    if (result) 
    {
      return result;
    }
  }
  // nothing found -> also try the global scope
  result=m_globalScope.find(name);
  return result;
}
/*! counts the number of lines in the input */
static int countLines(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  const char *p=yyextra->inputString;
  char c;
  int count=1;
  while ((c=*p)) 
  { 
    p++ ; 
    if (c=='\n') count++;  
  }
  if (p>yyextra->inputString && *(p-1)!='\n') 
  { // last line does not end with a \n, so we add an extra
    // line and explicitly terminate the line after parsing.
    count++, 
    yyextra->needsTermination=TRUE; 
  } 
  return count;
}

static void setCurrentDoc(const QCString &anchor,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (Doxygen::searchIndex)
  {
    if (yyextra->searchCtx)
    {
      Doxygen::searchIndex->setCurrentDoc(yyextra->searchCtx,yyextra->searchCtx->anchor(),FALSE);
    }
    else
    {
      Doxygen::searchIndex->setCurrentDoc(yyextra->sourceFileDef,anchor,TRUE);
    }
  }
}

static void addToSearchIndex(const char *text, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (Doxygen::searchIndex)
  {
    Doxygen::searchIndex->addWord(text,FALSE);
  }
}


static ClassDef *stripClassName(const char *s,Definition *d,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  int pos=0;
  QCString type = s;
  QCString className;
  QCString templSpec;
  while (extractClassNameFromType(type,pos,className,templSpec)!=-1)
  {
    QCString clName=className+templSpec;

    ClassDef *cd=0;
    if (!yyextra->classScope.isEmpty())
    {
      cd=getResolvedClass(d,yyextra->sourceFileDef,yyextra->classScope+"::"+clName);
    }
    if (cd==0)
    {
      cd=getResolvedClass(d,yyextra->sourceFileDef,clName);
    }
    if (cd)
    {
      return cd;
    }
  }

  return 0;
}



/*! start a new line of code, inserting a line number if yyextra->sourceFileDef
 * is TRUE. If a definition starts at the current line, then the line
 * number is linked to the documentation of that definition.
 */
static void startCodeLine(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //if (yyextra->currentFontClass) { yyextra->code->endFontClass(yyscanner); }
  if (yyextra->sourceFileDef)
  {
    //QCString lineNumber,lineAnchor;
    //lineNumber.sprintf("%05d",yyextra->yyLineNr);
    //lineAnchor.sprintf("l%05d",yyextra->yyLineNr);
   
    Definition *d   = yyextra->sourceFileDef->getSourceDefinition(yyextra->yyLineNr);
    //printf("startCodeLine %d d=%p\n",yyextra->yyLineNr,d);
    //yyextra->code->startLineNumber();

    if (!yyextra->includeCodeFragment && d && d->isLinkableInProject())
    {
      yyextra->currentDefinition = d;
      yyextra->currentMemberDef = yyextra->sourceFileDef->getSourceMember(yyextra->yyLineNr);
      //yyextra->insideBody = FALSE;
      yyextra->endComment = FALSE;
      yyextra->searchingForBody = TRUE;
      yyextra->realScope = d->name().copy();
      yyextra->classScope = d->name().copy();
      //printf("Real scope: `%s'\n",yyextra->realScope.data());
      yyextra->bodyCurlyCount = 0;
      QCString lineAnchor;
      lineAnchor.sprintf("l%05d",yyextra->yyLineNr);
      if (yyextra->currentMemberDef)
      {
        yyextra->code->writeLineNumber(yyextra->currentMemberDef->getReference(),
	                        yyextra->currentMemberDef->getOutputFileBase(),
	                        yyextra->currentMemberDef->anchor(),yyextra->yyLineNr);
        setCurrentDoc(lineAnchor, yyscanner);
      }
      else
      {
        yyextra->code->writeLineNumber(d->getReference(),
	                        d->getOutputFileBase(),
	                        0,yyextra->yyLineNr);
        setCurrentDoc(lineAnchor,yyscanner);
      }
    }
    else
    {
      //yyextra->code->codify(lineNumber);
      yyextra->code->writeLineNumber(0,0,0,yyextra->yyLineNr);
    }
    //yyextra->code->endLineNumber();
  }
  yyextra->code->startCodeLine(yyextra->sourceFileDef); 
  if (yyextra->currentFontClass)
  {
    yyextra->code->startFontClass(yyextra->currentFontClass);
  }
}

static void codify(const char* text,yyscan_t yyscanner) 
{ 
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->code->codify(text);
}

static void endCodeLine(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  endFontClass(yyscanner);
  yyextra->code->endCodeLine();
}

static void nextCodeLine(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  const char *fc = yyextra->currentFontClass;
  endCodeLine(yyscanner);
  if (yyextra->yyLineNr<yyextra->inputLines) 
  {
    yyextra->currentFontClass = fc;
    startCodeLine(yyscanner);
  }
}


/*! writes a link to a fragment \a text that may span multiple lines, inserting
 * line numbers for each line. If \a text contains newlines, the link will be 
 * split into multiple links with the same destination, one for each line.
 */
static void writeMultiLineCodeLink(CodeOutputInterface &ol,
                  Definition *d,
                  const char *text,
                  yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  static bool sourceTooltips = Config_getBool(SOURCE_TOOLTIPS);
  TooltipManager::instance()->addTooltip(d);
  QCString ref  = d->getReference();
  QCString file = d->getOutputFileBase();
  QCString anchor = d->anchor();
  QCString tooltip; 
  if (!sourceTooltips) // fall back to simple "title" tooltips
  {
    tooltip = d->briefDescriptionAsTooltip();
  }
  bool done=FALSE;
  char *p=(char *)text;
  while (!done)
  {
    char *sp=p;
    char c;
    while ((c=*p++) && c!='\n') { }
    if (c=='\n')
    {
      yyextra->yyLineNr++;
      *(p-1)='\0';
      //printf("writeCodeLink(%s,%s,%s,%s)\n",ref,file,anchor,sp);
      ol.writeCodeLink(ref,file,anchor,sp,tooltip);
      nextCodeLine(yyscanner);
    }
    else
    {
      //printf("writeCodeLink(%s,%s,%s,%s)\n",ref,file,anchor,sp);
      ol.writeCodeLink(ref,file,anchor,sp,tooltip);
      done=TRUE;
    }
  }
}

static void startFontClass(const char *s,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  // if font class is already set don't stop and start it.
  // strcmp does not like null pointers as input.
  if (!yyextra->currentFontClass || !s || strcmp(yyextra->currentFontClass,s))
  {
    endFontClass(yyscanner);
    yyextra->code->startFontClass(s);
    yyextra->currentFontClass=s;
  }
}

static void endFontClass(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (yyextra->currentFontClass)
  {
    yyextra->code->endFontClass();
    yyextra->currentFontClass=0;
  }
}

static void codifyLines(char *text,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("codifyLines(%d,\"%s\")\n",yyextra->yyLineNr,text);
  char *p=text,*sp=p;
  char c;
  bool done=FALSE;
  const char *  tmp_currentFontClass = yyextra->currentFontClass;
  while (!done)
  {
    sp=p;
    while ((c=*p++) && c!='\n') { }
    if (c=='\n')
    {
      yyextra->yyLineNr++;
      *(p-1)='\0';
      yyextra->code->codify(sp);
      endCodeLine(yyscanner);
      if (yyextra->yyLineNr<yyextra->inputLines)
      {
        startCodeLine(yyscanner);
      }
      if (tmp_currentFontClass)
      {
        startFontClass(tmp_currentFontClass,yyscanner);
      }
    }
    else
    {
      yyextra->code->codify(sp);
      done=TRUE;
    }
  }
}

static void codifyLines(const QCString &str,yyscan_t yyscanner)
{
  char *tmp= (char *)malloc(str.length()+1);
  qstrcpy(tmp, str);
  codifyLines(tmp,yyscanner);
  free(tmp);
}

static bool getLinkInScope(const QCString &c,  // scope
                           const QCString &m,  // member
			   const char *memberText, // exact text
			   CodeOutputInterface &ol,
			   const char *text,
			   yyscan_t yyscanner
			  )
{
  MemberDef    *md;
  ClassDef     *cd;
  FileDef      *fd;
  NamespaceDef *nd;
  GroupDef     *gd;
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("Trying `%s'::`%s'\n",c.data(),m.data());
  if (getDefs(c,m,"()",md,cd,fd,nd,gd,FALSE,yyextra->sourceFileDef) && 
      md->isLinkable())
  {
    //Definition *d=0;
    //if (cd) d=cd; else if (nd) d=nd; else if (fd) d=fd; else d=gd;

    Definition *d = md->getOuterScope()==Doxygen::globalScope ?
	            md->getBodyDef() : md->getOuterScope();
    //printf("Found! d=%s\n",d?d->name().data():"<none>");
    if (md->getGroupDef()) d = md->getGroupDef();
    if (d && d->isLinkable())
    {
      yyextra->theCallContext.setClass(stripClassName(md->typeString(),md->getOuterScope(),yyscanner));
      //printf("yyextra->currentDefinition=%p yyextra->currentMemberDef=%p\n",
      //        yyextra->currentDefinition,yyextra->currentMemberDef);

      if (yyextra->currentDefinition && yyextra->currentMemberDef &&
	  md!=yyextra->currentMemberDef && yyextra->collectXRefs)
      {
	addDocCrossReference(yyextra->currentMemberDef,md);
      }
      //printf("d->getReference()=`%s' d->getOutputBase()=`%s' name=`%s' member name=`%s'\n",d->getReference().data(),d->getOutputFileBase().data(),d->name().data(),md->name().data());
     
      writeMultiLineCodeLink(ol,md, text ? text : memberText,yyscanner);
      addToSearchIndex(text ? text : memberText, yyscanner);
      return TRUE;
    } 
  }
  return FALSE;
}

static bool getLink(const char *className,
                    const char *memberName,
		    CodeOutputInterface &ol,
		    const char *text,
		    yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  QCString m=removeRedundantWhiteSpace(memberName);
  QCString c=className;
  if (!getLinkInScope(c,m,memberName,ol,text,yyscanner))
  {
    if (!yyextra->curClassName.isEmpty())
    {
      if (!c.isEmpty()) c.prepend("::");
      c.prepend(yyextra->curClassName);
      return getLinkInScope(c,m,memberName,ol,text,yyscanner);
    }
    return FALSE;
  }
  return TRUE;
}


/*
  For a given string in the source code,
  finds its class or global id and links to it.
*/
static void generateClassOrGlobalLink(CodeOutputInterface &ol,char *clName,
                                      bool typeOnly,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  QCString className=clName;

  // Don't do anything for empty text
  if (className.isEmpty()) return;

  DBG_CTX((stderr,"generateClassOrGlobalLink(className=%s)\n",className.data()));

  ClassDef *cd=0,*lcd=0;  /** Class def that we may find */
  MemberDef *md=0;        /** Member def that we may find */
  //bool isLocal=FALSE;

  if ((lcd=yyextra->theVarContext.findVariable(className))==0) // not a local variable
  {
    Definition *d = yyextra->currentDefinition;
    QCString scope = substitute(className,".","::");

    cd = getResolvedClass(d,yyextra->sourceFileDef,substitute(className,".","::"),&md);

    DBG_CTX((stderr,"d=%s yyextra->sourceFileDef=%s\n",
        d?d->displayName().data():"<null>",
        yyextra->currentDefinition?yyextra->currentDefinition->displayName().data():"<null>"));
    DBG_CTX((stderr,"is found as a type %s\n",cd?cd->name().data():"<null>"));

    if (cd==0 && md==0) // also see if it is variable or enum or enum value
    {
      NamespaceDef *nd = getResolvedNamespace(scope);
      if (nd)
      {
        writeMultiLineCodeLink(ol,nd,clName,yyscanner);
        addToSearchIndex(className, yyscanner);
        return;
      }
      else if (getLink(yyextra->classScope,clName,ol,clName,yyscanner))
      {
	return;
      }
    }
  }
  else
  {
    if (lcd!=yyextra->dummyContext) 
    {
      yyextra->theCallContext.setClass(lcd);
    }
    //isLocal=TRUE;
    DBG_CTX((stderr,"is a local variable cd=%p!\n",cd));
  }

  if (cd && cd->isLinkable()) // is it a linkable class
  {
    writeMultiLineCodeLink(ol,cd,clName,yyscanner);
    addToSearchIndex(className, yyscanner);
    if (md)
    {
      Definition *d = md->getOuterScope()==Doxygen::globalScope ?
                      md->getBodyDef() : md->getOuterScope();
      if (md->getGroupDef()) d = md->getGroupDef();
      if (d && d->isLinkable() && md->isLinkable() && 
          yyextra->currentMemberDef && yyextra->collectXRefs)
      {
        addDocCrossReference(yyextra->currentMemberDef,md);
      }
    }
  }
  else // not a class, maybe a global member
  {
    int scopeEnd = className.findRev(".");
    if (scopeEnd!=-1 && !typeOnly) // name with explicit scope
    {
      QCString scope = substitute(className.left(scopeEnd),".","::");
      QCString locName = className.right(className.length()-scopeEnd-1);
      ClassDef *mcd = getClass(scope);
      DBG_CTX((stderr,"scope=%s locName=%s mcd=%p\n",scope.data(),locName.data(),mcd));
      if (mcd)
      {
	MemberDef *md = mcd->getMemberByName(locName);
	if (md)
	{
          yyextra->theCallContext.setClass(stripClassName(md->typeString(),md->getOuterScope(),yyscanner));
          writeMultiLineCodeLink(ol,md,clName,yyscanner);
          addToSearchIndex(className, yyscanner);
	  Definition *d = md->getOuterScope()==Doxygen::globalScope ?
	                  md->getBodyDef() : md->getOuterScope();
	  if (md->getGroupDef()) d = md->getGroupDef();
	  if (d && d->isLinkable() && md->isLinkable() && 
              yyextra->currentMemberDef && yyextra->collectXRefs)
	  {
	    addDocCrossReference(yyextra->currentMemberDef,md);
	  }
	  return;
	}
      }
      else // check namespace as well
      {
        NamespaceDef *mnd = getResolvedNamespace(scope);
        if (mnd)
        {
  	  MemberDef *md=mnd->getMemberByName(locName);
	  if (md)
          {
	    //printf("name=%s scope=%s\n",locName.data(),scope.data());
	    yyextra->theCallContext.setClass(stripClassName(md->typeString(),md->getOuterScope(),yyscanner));
            writeMultiLineCodeLink(ol,md,clName,yyscanner);
            addToSearchIndex(className, yyscanner);
	    Definition *d = md->getOuterScope()==Doxygen::globalScope ?
	                    md->getBodyDef() : md->getOuterScope();
	    if (md->getGroupDef()) d = md->getGroupDef();
	    if (d && d->isLinkable() && md->isLinkable() && 
                yyextra->currentMemberDef && yyextra->collectXRefs)
	    {
	      addDocCrossReference(yyextra->currentMemberDef,md);
	    }
	    return;
          }
        }
      }
    }
    
    // nothing found, just write out the word
    codifyLines(clName,yyscanner);
    addToSearchIndex(clName, yyscanner);
  }
}

/*
   As of June 1, this function seems to work
   for file members, but scopes are not
   being correctly tracked for classes
   so it doesn't work for classes yet.

*/
static void generateFunctionLink(CodeOutputInterface &ol,char *funcName,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //CodeClassDef *ccd=0;
  ClassDef *ccd=0;
  QCString locScope=yyextra->classScope.copy();
  QCString locFunc=removeRedundantWhiteSpace(funcName);
  DBG_CTX((stdout,"*** locScope=%s locFunc=%s\n",locScope.data(),locFunc.data()));
  int i=locFunc.findRev("::");
  if (i>0)
  {
    locScope=locFunc.left(i);
    locFunc=locFunc.right(locFunc.length()-i-2).stripWhiteSpace();
  }
  //printf("generateFunctionLink(%s) classScope=`%s'\n",locFunc.data(),locScope.data());
  if (!locScope.isEmpty() && (ccd=yyextra->codeClassSDict[locScope]))
  {
    //printf("using classScope %s\n",yyextra->classScope.data());
    if (ccd->baseClasses())
    {
      BaseClassListIterator bcli(*ccd->baseClasses());
      for ( ; bcli.current() ; ++bcli)
      {
	if (getLink(bcli.current()->classDef->name(),locFunc,ol,funcName,yyscanner)) 
	{
	  return;
	}
      }
    }
  }
  if (!getLink(locScope,locFunc,ol,funcName,yyscanner))
  {
    generateClassOrGlobalLink(ol,funcName,FALSE,yyscanner);
  }
  return;
}

static bool findMemberLink(CodeOutputInterface &ol,Definition *sym,const char *symName,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("sym %s outerScope=%s equal=%d\n",
  //    sym->name().data(),sym->getOuterScope()->name().data(),
  //    sym->getOuterScope()==yyextra->currentDefinition);

  if (sym->getOuterScope() &&
      sym->getOuterScope()->definitionType()==Definition::TypeClass &&
      yyextra->currentDefinition->definitionType()==Definition::TypeClass)
  {
    ClassDef *cd = (ClassDef*)sym->getOuterScope();
    ClassDef *thisCd = (ClassDef *)yyextra->currentDefinition;
    if (sym->definitionType()==Definition::TypeMember)
    {
      if (yyextra->currentMemberDef && yyextra->collectXRefs)
      {
	addDocCrossReference(yyextra->currentMemberDef,(MemberDef*)sym);
      }
    }
    DBG_CTX((stderr,"cd=%s thisCd=%s\n",cd?cd->name().data():"<none>",thisCd?thisCd->name().data():"<none>"));

    // TODO: find the nearest base class in case cd is a base class of
    // thisCd 
    if (cd==thisCd || (thisCd && thisCd->isBaseClass(cd,TRUE)))
    {
      writeMultiLineCodeLink(ol,sym,symName,yyscanner);
      return TRUE;
    }
  }
  return FALSE;
}

static void findMemberLink(CodeOutputInterface &ol,char *symName,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("Member reference: %s scope=%s member=%s\n",
  //    yytext,
  //    yyextra->currentDefinition?yyextra->currentDefinition->name().data():"<none>",
  //    yyextra->currentMemberDef?yyextra->currentMemberDef->name().data():"<none>"
  //    );
  if (yyextra->currentDefinition)
  {
    DefinitionIntf *di = Doxygen::symbolMap->find(symName);
    if (di)
    {
      if (di->definitionType()==DefinitionIntf::TypeSymbolList) // multiple symbols
      {
	DefinitionListIterator dli(*(DefinitionList*)di);
	Definition *sym;
	for (dli.toFirst();(sym=dli.current());++dli)
	{
	  if (findMemberLink(ol,sym,symName,yyscanner)) return;
	}
      }
      else // single symbol
      {
	if (findMemberLink(ol,(Definition*)di,symName,yyscanner)) return;
      }
    }
  }
  //printf("sym %s not found\n",&yytext[5]);
  codify(symName,yyscanner);
}

#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) result=yyread(buf,max_size);

static int yyread(char *buf,int max_size, yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  int c=0;
  while( c < max_size && yyextra->inputString[yyextra->inputPosition] )
  {
    *buf = yyextra->inputString[yyextra->inputPosition++] ;
    c++; buf++;
  }
  return c;
}


/*!
  Examines current stack of white-space indentations;
  re-syncs the parser with the correct scope.
*/
static void adjustScopesAndSuites(unsigned indentLength, yyscan_t yyscanner) 
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  // States to pop
  if (!yyextra->indents.isEmpty() && indentLength < yyextra->indents.top()) 
  {
    while (!yyextra->indents.isEmpty() && indentLength < yyextra->indents.top()) 
    {
      // printf("Exited scope indent of [%d]\n", yyextra->indents.top());
      yyextra->indents.pop(); // Pop the old suite's indentation

      yyextra->currentMemberDef=0;
      if (yyextra->currentDefinition) 
	yyextra->currentDefinition=yyextra->currentDefinition->getOuterScope();
    }
  }

  // Are there any remaining indentation levels for suites?
  if (!yyextra->indents.isEmpty()) 
  {
    BEGIN( Suite );
  }
  else 
  {
    BEGIN( Body );
  }
}

// public interface -----------------------------------------------------------
static yyscan_t yyscanner;
static struct pycodeYY_state pycode_extra;

void resetPythonCodeParserState() 
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  yyextra->currentDefinition = 0;
  yyextra->currentMemberDef = 0;
  yyextra->doubleStringIsDoc = FALSE;
  yyextra->paramParens = 0;
  yyextra->indents.clear();
  BEGIN( Body );
}


void parsePythonCode(CodeOutputInterface &od,const char * /*className*/,
                 const QCString &s,bool exBlock, const char *exName,
                 FileDef *fd,int startLine,int endLine,bool inlineFragment,
                 MemberDef *,bool,Definition *searchCtx,bool collectXRefs) 
{
  pycodeYYlex_init_extra(&pycode_extra, &yyscanner);
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  //printf("***parseCode()\n");
  
  //--------------------------------------
  if (s.isEmpty()) return;
  printlex(yy_flex_debug, TRUE, __FILE__, fd ? fd->fileName().data(): NULL);
  TooltipManager::instance()->clearTooltips();
  yyextra->code = &od;
  yyextra->inputString   = s;
  yyextra->inputPosition = 0;
  yyextra->currentFontClass = 0;
  yyextra->needsTermination = FALSE;
  yyextra->searchCtx=searchCtx;
  yyextra->collectXRefs=collectXRefs;

  if (startLine!=-1)
    yyextra->yyLineNr    = startLine;
  else
    yyextra->yyLineNr    = 1;
  if (endLine!=-1)
    yyextra->inputLines  = endLine+1;
  else
    yyextra->inputLines  = yyextra->yyLineNr + countLines(yyscanner) - 1;
  
  
  yyextra->exampleBlock  = exBlock; 
  yyextra->exampleName   = exName;
  yyextra->sourceFileDef = fd;

  bool cleanupSourceDef = FALSE;
  if (exBlock && fd==0)
  {
    // create a dummy filedef for the example
    yyextra->sourceFileDef = new FileDef("",(exName?exName:"generated"));
    cleanupSourceDef = TRUE;
  }
  if (yyextra->sourceFileDef) 
  {
    setCurrentDoc("l00001",yyscanner);
  }

  yyextra->includeCodeFragment = inlineFragment;
  // Starts line 1 on the output  
  startCodeLine(yyscanner);

  pycodeYYrestart( yyin, yyscanner );

  pycodeYYlex(yyscanner);

  if (!yyextra->indents.isEmpty()) 
  {
    // printf("Exited pysourceparser in inconsistent state!\n");
  }

  if (yyextra->needsTermination)
  {
    endCodeLine(yyscanner);
  }
  if (fd)
  {
    TooltipManager::instance()->writeTooltips(*yyextra->code);
  }
  if (cleanupSourceDef)
  {
    // delete the temporary file definition used for this example
    delete yyextra->sourceFileDef;
    yyextra->sourceFileDef=0;
  }
  printlex(yy_flex_debug, FALSE, __FILE__, fd ? fd->fileName().data(): NULL);
  return;
}


#if !defined(YY_FLEX_SUBMINOR_VERSION) 
extern "C" { // some bogus code to keep the compiler happy
  void pycodeYYdummy() { yy_flex_realloc(0,0); } 
}
#elif YY_FLEX_MAJOR_VERSION<=2 && YY_FLEX_MINOR_VERSION<=5 && YY_FLEX_SUBMINOR_VERSION<33
#error "You seem to be using a version of flex newer than 2.5.4. These are currently incompatible with 2.5.4, and do NOT work with doxygen! Please use version 2.5.4 or expect things to be parsed wrongly! A bug report has been submitted (#732132)."
#endif

