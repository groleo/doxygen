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

/*! \file
 *  This scanner is used to convert a string into a list of function or 
 *  template arguments. Each parsed argument results in a Argument struct,
 *  that is put into an ArgumentList in declaration order.
 *  Comment blocks for arguments can also be included in the string.
 *  The argument string does not contain new-lines (except inside any
 *  comment blocks).
 *  An Argument consists of the string fields: 
 *                 type,name,default value, and documentation
 *  The Argument list as a whole can be pure, constant or volatile.
 *
 *  Examples of input strings are:
 *  \code
 *    "(int a,int b) const"
 *    "(const char *s="hello world",int=5) = 0"
 *    "<class T,class N>"
 *    "(char c,const char)"
 *  \endcode
 *
 *  Note: It is not always possible to distinguish between the name and 
 *        type of an argument. In case of doubt the name is added to the
 *        type, and the matchArgumentList in util.cpp is be used to
 *        further determine the correct separation.
 */
%option never-interactive
%option prefix="defargsYY"
%option noyywrap
%option reentrant
%option extra-type="struct defargsYY_state *"


%{

/*
 *	includes
 */
#include <stdio.h>
//#include <iostream.h>
#include <assert.h>
#include <ctype.h>
#include <qregexp.h>

#include "defargs.h"
#include "entry.h"
#include "util.h"
#include "arguments.h"
#include "message.h"
  
#define YY_NO_INPUT 1
#define YY_NO_UNISTD_H 1
  
/* -----------------------------------------------------------------
 *	state variables
 */
 struct defargsYY_state
 {
     const char      *inputString;
     int              inputPosition;
     ArgumentList    *argList;
     QCString        *copyArgValue;
     QCString         curArgTypeName;
     QCString         curArgDefValue;
     QCString         curArgName;
     QCString         curArgDocs;
     QCString         curArgAttrib;
     QCString         curArgArray;
     QCString         curTypeConstraint;
     QCString         extraTypeChars;
     int              argRoundCount;
     int              argSharpCount;
     int              argCurlyCount;
     int              readArgContext;
     int              lastDocContext;
     int              lastDocChar;
     int              lastExtendsContext;
     QCString         delimiter;
};

static int yyread(char *buf,int max_size,yyscan_t yyscanner);

/* -----------------------------------------------------------------
 */
#undef	YY_INPUT
#define	YY_INPUT(buf,result,max_size) result=yyread(buf,max_size,yyscanner);

%}

B       [ \t]
ID	[a-z_A-Z\x80-\xFF][a-z_A-Z0-9\x80-\xFF]*
RAWBEGIN  (u|U|L|u8)?R\"[^ \t\(\)\\]{0,16}"("
RAWEND    ")"[^ \t\(\)\\]{0,16}\"


%x      Start
%x      CopyArgString
%x      CopyRawString
%x	CopyArgRound
%x	CopyArgRound2
%x	CopyArgSharp
%x	CopyArgCurly
%x	ReadFuncArgType
%x	ReadFuncArgDef
%x	ReadFuncArgPtr
%x	FuncQual
%x	ReadDocBlock
%x	ReadDocLine
%x      ReadTypeConstraint
%x      TrailingReturn


%%

<Start>[<(]				{ BEGIN(ReadFuncArgType); }

<ReadFuncArgType>{B}*			{
  					  yyextra->curArgTypeName+=" ";
  					}
<ReadFuncArgType>"["[^\]]*"]"		{ 
					  if (yyextra->curArgTypeName.stripWhiteSpace().isEmpty())
					  {
					    yyextra->curArgAttrib=yytext; // for M$-IDL
					  }
					  else // array type
					  {
					    yyextra->curArgArray+=yytext;
					  }
					}
<ReadFuncArgDef>"'"\\[0-7]{1,3}"'"	{ yyextra->curArgDefValue+=yytext; }
<ReadFuncArgDef>"'"\\."'"		{ yyextra->curArgDefValue+=yytext; }
<ReadFuncArgDef>"'"."'"			{ yyextra->curArgDefValue+=yytext; }
<ReadFuncArgDef>{RAWBEGIN}              { yyextra->curArgDefValue+=yytext; 
                                          QCString text=yytext;
                                          int i=text.find('"');
                                          yyextra->delimiter = yytext+i+1;
                                          yyextra->delimiter=yyextra->delimiter.left(yyextra->delimiter.length()-1);
                                          BEGIN( CopyRawString );
                                        }
<ReadFuncArgDef>\"			{
  					  yyextra->curArgDefValue+=*yytext;
  					  BEGIN( CopyArgString );
  					}
<ReadFuncArgType>"("([^:)]+{B}*"::")*{B}*[&*\^]+{B}*/{ID} { 
  					  // function pointer as argument
					  yyextra->curArgTypeName+=yytext;
					  //yyextra->curArgTypeName=yyextra->curArgTypeName.simplifyWhiteSpace();
					  BEGIN( ReadFuncArgPtr );
  					}
<ReadFuncArgPtr>{ID}			{
					  yyextra->curArgName=yytext;
  					}
<ReadFuncArgPtr>")"{B}*"("		{ // function pointer
					  yyextra->curArgTypeName+=yytext;
					  //yyextra->curArgTypeName=yyextra->curArgTypeName.simplifyWhiteSpace();
					  yyextra->readArgContext = ReadFuncArgType;
					  yyextra->copyArgValue=&yyextra->curArgTypeName;
					  yyextra->argRoundCount=0;
					  BEGIN( CopyArgRound2 );
					}
<ReadFuncArgPtr>")"/{B}*"["		{ // pointer to fixed size array
					  yyextra->curArgTypeName+=yytext;
					  yyextra->curArgTypeName+=yyextra->curArgName;
					  //yyextra->curArgTypeName=yyextra->curArgTypeName.simplifyWhiteSpace();
					  BEGIN( ReadFuncArgType );
					}
<ReadFuncArgPtr>")"			{ // redundant braces detected / remove them
					  int i=yyextra->curArgTypeName.findRev('('),l=yyextra->curArgTypeName.length();
					  if (i!=-1)
					    yyextra->curArgTypeName=yyextra->curArgTypeName.left(i)+
					                   yyextra->curArgTypeName.right(l-i-1);
					  yyextra->curArgTypeName+=yyextra->curArgName;
					  BEGIN( ReadFuncArgType );
					}
<ReadFuncArgType>"<="|">="|"->"|">>"|"<<" { // handle operators in defargs
  					  yyextra->curArgTypeName+=yytext;
  					}
<ReadFuncArgType,ReadFuncArgDef>[({<]	{	 
					  if (YY_START==ReadFuncArgType)
					  {
					    yyextra->curArgTypeName+=*yytext;
					    yyextra->copyArgValue=&yyextra->curArgTypeName;
					  }
					  else // YY_START==ReadFuncArgDef
					  {
					    yyextra->curArgDefValue+=*yytext;
					    yyextra->copyArgValue=&yyextra->curArgDefValue;
					  }
					  yyextra->readArgContext = YY_START; 
					  if (*yytext=='(')
					  {
					    yyextra->argRoundCount=0; 
					    BEGIN( CopyArgRound ); 
					  }
					  else if (*yytext=='{')
					  {
					    yyextra->argCurlyCount=0; 
					    BEGIN( CopyArgCurly ); 
					  }
					  else // yytext=='<'
					  {
					    yyextra->argSharpCount=0; 
					    yyextra->argRoundCount=0; 
					    BEGIN( CopyArgSharp ); 
					  }
					}
<CopyArgRound,CopyArgRound2>"("		{
  					  yyextra->argRoundCount++;
					  *yyextra->copyArgValue += *yytext;
  					}
<CopyArgRound,CopyArgRound2>")"({B}*{ID})* {
					  *yyextra->copyArgValue += yytext;
					  if (yyextra->argRoundCount>0) 
					  {
					    yyextra->argRoundCount--;
					  }
					  else 
					  {
					    if (YY_START==CopyArgRound2)
					    {
					      *yyextra->copyArgValue+=" "+yyextra->curArgName;
					    }
					    BEGIN( yyextra->readArgContext );
					  }
  					}
<CopyArgRound>")"/{B}*                  {
					  *yyextra->copyArgValue += *yytext;
					  if (yyextra->argRoundCount>0) yyextra->argRoundCount--;
					  else BEGIN( yyextra->readArgContext );
                                        }
<CopyArgSharp>"<<"                      {
                                          if (yyextra->argRoundCount>0)
                                          {
					    *yyextra->copyArgValue += yytext;
                                          }
                                          else
                                          {
                                            REJECT;
                                          }
                                        }
<CopyArgSharp>">>"                      {
                                          if (yyextra->argRoundCount>0)
                                          {
					    *yyextra->copyArgValue += yytext;
                                          }
                                          else
                                          {
                                            REJECT;
                                          }
                                        }
<CopyArgSharp>"<"			{
  					  yyextra->argSharpCount++;
					  *yyextra->copyArgValue += *yytext;
  					}
<CopyArgSharp>">"			{
					  *yyextra->copyArgValue += *yytext;
					  if (yyextra->argSharpCount>0) yyextra->argSharpCount--;
					  else BEGIN( yyextra->readArgContext );
  					}
<CopyArgSharp>"("                       {
                                          yyextra->argRoundCount++;
					  *yyextra->copyArgValue += *yytext;
                                        }
<CopyArgSharp>")"                       {
                                          yyextra->argRoundCount--;
					  *yyextra->copyArgValue += *yytext;
                                        }
<CopyArgCurly>"{"			{
  					  yyextra->argCurlyCount++;
					  *yyextra->copyArgValue += *yytext;
  					}
<CopyArgCurly>"}"			{
					  *yyextra->copyArgValue += *yytext;
					  if (yyextra->argCurlyCount>0) yyextra->argCurlyCount--;
					  else BEGIN( yyextra->readArgContext );
  					}
<CopyArgString>\\.			{
					  yyextra->curArgDefValue+=yytext;
  					}
<CopyRawString>{RAWEND}                 {
					  yyextra->curArgDefValue+=yytext;
                                          QCString delimiter = yytext+1;
                                          delimiter=delimiter.left(delimiter.length()-1);
                                          if (delimiter==yyextra->delimiter)
                                          {
					    BEGIN( ReadFuncArgDef );
                                          }
                                        }
<CopyArgString>\"			{
					  yyextra->curArgDefValue+=*yytext;
					  BEGIN( ReadFuncArgDef );
  					}
<ReadFuncArgType>"="			{
					  BEGIN( ReadFuncArgDef );
  					}
<ReadFuncArgType,ReadFuncArgDef>[,)>]{B}*("/*"[*!]|"//"[/!])"<" {
					  yyextra->lastDocContext=YY_START;
					  yyextra->lastDocChar=*yytext;  
					  QCString text=yytext;
					  if (text.find("//")!=-1)
					    BEGIN( ReadDocLine );
					  else
					    BEGIN( ReadDocBlock );
  					}
<ReadFuncArgType,ReadFuncArgDef>[,)>]	{
  					  if (*yytext==')' && yyextra->curArgTypeName.stripWhiteSpace().isEmpty())
					  {
					    yyextra->curArgTypeName+=*yytext;
					    BEGIN(FuncQual);
					  }
					  else
					  {
					    yyextra->curArgTypeName=removeRedundantWhiteSpace(yyextra->curArgTypeName);
					    yyextra->curArgDefValue=yyextra->curArgDefValue.stripWhiteSpace();
					    //printf("curArgType=`%s' curArgDefVal=`%s'\n",yyextra->curArgTypeName.data(),yyextra->curArgDefValue.data());
					    int l=yyextra->curArgTypeName.length();
					    if (l>0)
					    {
					      int i=l-1;
					      while (i>=0 && (isspace((uchar)yyextra->curArgTypeName.at(i)) || yyextra->curArgTypeName.at(i)=='.')) i--;
					      while (i>=0 && (isId(yyextra->curArgTypeName.at(i)) || yyextra->curArgTypeName.at(i)=='$')) i--;
					      Argument *a = new Argument;
					      a->attrib  = yyextra->curArgAttrib.copy();
                                              a->typeConstraint = yyextra->curTypeConstraint.stripWhiteSpace();
					      //printf("a->type=%s a->name=%s i=%d l=%d\n",
					      //        a->type.data(),a->name.data(),i,l);
					      a->array.resize(0);
					      if (i==l-1 && yyextra->curArgTypeName.at(i)==')') // function argument
					      {
						int bi=yyextra->curArgTypeName.find('(');
						int fi=bi-1;
						//printf("func arg fi=%d\n",fi);
						while (fi>=0 && (isId(yyextra->curArgTypeName.at(fi)) || yyextra->curArgTypeName.at(fi)==':')) fi--;
						if (fi>=0)
						{
						  a->type  = yyextra->curArgTypeName.left(fi+1);
						  a->name  = yyextra->curArgTypeName.mid(fi+1,bi-fi-1).stripWhiteSpace();
						  a->array = yyextra->curArgTypeName.right(l-bi);
						}
						else
						{
						  a->type = yyextra->curArgTypeName;
						}
					      }
					      else if (i>=0 && yyextra->curArgTypeName.at(i)!=':')
					      { // type contains a name
						a->type = removeRedundantWhiteSpace(yyextra->curArgTypeName.left(i+1)).stripWhiteSpace();
						a->name = yyextra->curArgTypeName.right(l-i-1).stripWhiteSpace();

						// if the type becomes a type specifier only then we make a mistake
						// and need to correct it to avoid seeing a nameless parameter
						// "struct A" as a parameter with type "struct" and name "A".
						int sv=0;
						if      (a->type.left(6)=="const ")    sv=6;
						else if (a->type.left(9)=="volatile ") sv=9;

						if (a->type.mid(sv)=="struct"    ||
						    a->type.mid(sv)=="union"     ||
						    a->type.mid(sv)=="class"     ||
						    a->type.mid(sv)=="typename"  ||
						    a->type=="const"               ||
						    a->type=="volatile"
						   )
						{ 
						  a->type = a->type + " " + a->name;
						  a->name.resize(0);
						}
						//printf(" --> a->type='%s' a->name='%s'\n",a->type.data(),a->name.data());
					      }
					      else // assume only the type was specified, try to determine name later 
					      {
						a->type = removeRedundantWhiteSpace(yyextra->curArgTypeName);  
					      }
                                              if (!a->type.isEmpty() && a->type.at(0)=='$') // typeless PHP name?
                                              {
                                                a->name = a->type;
                                                a->type = "";
                                              }
					      a->array  += removeRedundantWhiteSpace(yyextra->curArgArray);
					      //printf("array=%s\n",a->array.data());
					      int alen = a->array.length();
					      if (alen>2 && a->array.at(0)=='(' && 
						            a->array.at(alen-1)==')') // fix-up for int *(a[10])
					      {
						int i=a->array.find('[')-1;
						a->array = a->array.mid(1,alen-2);
						if (i>0 && a->name.isEmpty())
						{
						  a->name  = a->array.left(i).stripWhiteSpace();
						  a->array = a->array.mid(i);
						}
					      }
					      a->defval = yyextra->curArgDefValue.copy();
					      //printf("a->type=%s a->name=%s a->defval=\"%s\"\n",a->type.data(),a->name.data(),a->defval.data());
					      a->docs   = yyextra->curArgDocs.stripWhiteSpace();
					      //printf("Argument `%s' `%s' adding docs=`%s'\n",a->type.data(),a->name.data(),a->docs.data());
					      yyextra->argList->append(a);
					    }
					    yyextra->curArgAttrib.resize(0);
					    yyextra->curArgTypeName.resize(0);
					    yyextra->curArgDefValue.resize(0);
					    yyextra->curArgArray.resize(0);
					    yyextra->curArgDocs.resize(0);
                                            yyextra->curTypeConstraint.resize(0);
					    if (*yytext==')')
					    {
					      BEGIN(FuncQual);
					      //printf(">>> end of argument list\n");
					    }
					    else
					    {
					      BEGIN( ReadFuncArgType );
					    }
					  }
  					}
<ReadFuncArgType,ReadFuncArgPtr>"extends" {
                                          yyextra->curTypeConstraint.resize(0);
                                          yyextra->lastExtendsContext=YY_START;
                                          BEGIN(ReadTypeConstraint);
                                        }
<ReadFuncArgType,ReadFuncArgPtr>"$"?{ID} { 
  					  QCString name=yytext; //resolveDefines(yytext);
					  if (YY_START==ReadFuncArgType && yyextra->curArgArray=="[]") // Java style array
					  {
					    yyextra->curArgTypeName+=" []";
					    yyextra->curArgArray.resize(0);
					  }
					  //printf("resolveName `%s'->`%s'\n",yytext,name.data());
  					  yyextra->curArgTypeName+=name;
					}
<ReadFuncArgType,ReadFuncArgPtr>.	{ 
  					  yyextra->curArgTypeName+=*yytext;
					}

<ReadFuncArgDef,CopyArgString>"<="|"->"|">="|">>"|"<<"	{
  					  yyextra->curArgDefValue+=yytext;
  					}
<ReadFuncArgDef,CopyArgString,CopyRawString>.		{
					  yyextra->curArgDefValue+=*yytext;
  					}
<CopyArgRound,CopyArgRound2,CopyArgSharp,CopyArgCurly>{ID}  {
  					  QCString name=yytext; //resolveDefines(yytext);
					  *yyextra->copyArgValue+=name;
					}
<CopyArgRound,CopyArgRound2,CopyArgSharp,CopyArgCurly>.  {
					  *yyextra->copyArgValue += *yytext;
					}
<ReadTypeConstraint>[,)>]               {
                                          unput(*yytext);
                                          BEGIN(yyextra->lastExtendsContext);
                                        }
<ReadTypeConstraint>.                   {
                                          yyextra->curTypeConstraint+=yytext;
                                        }
<ReadTypeConstraint>\n                  {
                                          yyextra->curTypeConstraint+=' ';
                                        }
<FuncQual>"const"		       	{
					  yyextra->argList->constSpecifier=TRUE;
					}
<FuncQual>"volatile"		    	{
					  yyextra->argList->volatileSpecifier=TRUE;
					}
<FuncQual>"&"		    	        {
                                          yyextra->argList->refQualifier=RefQualifierLValue;
					}
<FuncQual>"&&"		    	        {
                                          yyextra->argList->refQualifier=RefQualifierRValue;
					}
<FuncQual,TrailingReturn>"="{B}*"0"  	{
					  yyextra->argList->pureSpecifier=TRUE;
                                          BEGIN(FuncQual);
					}
<FuncQual>"->"                          { // C++11 trailing return type
                                          yyextra->argList->trailingReturnType=" -> ";
                                          BEGIN(TrailingReturn);
                                        }
<TrailingReturn>{B}/("final"|"override"){B}*  {
                                          unput(*yytext);
                                          BEGIN(FuncQual);
                                        }
<TrailingReturn>.                       {
                                          yyextra->argList->trailingReturnType+=yytext;
                                        }
<TrailingReturn>\n                      {
                                          yyextra->argList->trailingReturnType+=yytext;
                                        }
<FuncQual>")"{B}*"["[^]]*"]"		{ // for functions returning a pointer to an array, 
                                          // i.e. ")[]" in "int (*f(int))[4]" with argsString="(int))[4]"
  					  yyextra->extraTypeChars=yytext;
  					}
<ReadDocBlock>[^\*\n]+			{
  					  yyextra->curArgDocs+=yytext;
  					}
<ReadDocLine>[^\n]+			{
  					  yyextra->curArgDocs+=yytext;
  					}
<ReadDocBlock>"*/"			{ 
  					  if (yyextra->lastDocChar!=0)
					    unput(yyextra->lastDocChar);
  					  BEGIN(yyextra->lastDocContext); 
					}
<ReadDocLine>\n				{
  					  if (yyextra->lastDocChar!=0)
					    unput(yyextra->lastDocChar);
					  BEGIN(yyextra->lastDocContext);
  					}
<ReadDocBlock>\n			{
  					  yyextra->curArgDocs+=*yytext;
  					}
<ReadDocBlock>.				{
  					  yyextra->curArgDocs+=*yytext;
  					}
<*>("/*"[*!]|"//"[/!])("<"?)		{
  					  yyextra->lastDocContext=YY_START;
					  yyextra->lastDocChar=0;  
					  if (yytext[1]=='/')
					    BEGIN( ReadDocLine );
					  else
  					    BEGIN( ReadDocBlock );
  					}
<*>\n
<*>.

%%

static int yyread(char *buf,int max_size,yyscan_t yyscanner)
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

/* public interface------------------------------------------------------------
 */
static yyscan_t yyscanner;
static struct defargsYY_state defargs_extra;

/*! Converts an argument string into an ArgumentList.
 *  \param[in] argsString the list of Arguments.
 *  \param[out] al a reference to resulting argument list pointer.
 *  \param[out] extraTypeChars point to string to which trailing characters 
 *              for complex types are written to
 */
 
void stringToArgumentList(const char *argsString,ArgumentList* al,QCString *extraTypeChars)
{
  defargsYYlex_init_extra(&defargs_extra, &yyscanner);
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;
  if (al==0) return; 
  if (argsString==0) return;
  printlex(yy_flex_debug, TRUE, __FILE__, NULL);

  yyextra->copyArgValue=0;
  yyextra->curArgDocs.resize(0);
  yyextra->curArgAttrib.resize(0);
  yyextra->curArgArray.resize(0);
  yyextra->curTypeConstraint.resize(0);
  yyextra->extraTypeChars.resize(0);
  yyextra->argRoundCount = 0;
  yyextra->argSharpCount = 0;
  yyextra->argCurlyCount = 0;
  yyextra->lastDocChar = 0;

  yyextra->inputString   = argsString;
  yyextra->inputPosition = 0;
  yyextra->curArgTypeName.resize(0);
  yyextra->curArgDefValue.resize(0);
  yyextra->curArgName.resize(0);
  yyextra->argList = al;
  defargsYYrestart( yyin, yyscanner );
  BEGIN( Start );
  defargsYYlex(yyscanner);
  if (extraTypeChars) *extraTypeChars=yyextra->extraTypeChars;
  //printf("stringToArgumentList(%s) result=%s\n",argsString,argListToString(al).data());
  printlex(yy_flex_debug, FALSE, __FILE__, NULL);
}

#if !defined(YY_FLEX_SUBMINOR_VERSION) 
extern "C" { // some bogus code to keep the compiler happy
  void defargsYYdummy() { yy_flex_realloc(0,0); } 
}
#endif

