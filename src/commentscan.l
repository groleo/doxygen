/*****************************************************************************
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
%option prefix="commentscanYY"
%option noyywrap
%option reentrant
%option extra-type="struct commentscanYY_state *"


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
  
#include "scanner.h"
#include "entry.h"
#include "doxygen.h"
#include "message.h"
#include "config.h"
#include "util.h"
#include "index.h"
#include "defargs.h"
#include "language.h"
#include "outputlist.h"
#include "membergroup.h"
#include "reflist.h"
#include "debug.h"
#include "parserintf.h"
#include "cite.h"
#include "markdown.h"
#include "condparser.h"
#include "formula.h"
#include "commentscan.h"

#define YY_NO_INPUT 1
#define YY_NO_UNISTD_H 1
#define YY_NEVER_INTERACTIVE 1

// forward declarations
static bool handleBrief(const QCString &,yyscan_t yyscanner);
static bool handleFn(const QCString &,yyscan_t yyscanner);
static bool handleDef(const QCString &,yyscan_t yyscanner);
static bool handleOverload(const QCString &,yyscan_t yyscanner);
static bool handleEnum(const QCString &,yyscan_t yyscanner);
static bool handleDefGroup(const QCString &,yyscan_t yyscanner);
static bool handleAddToGroup(const QCString &,yyscan_t yyscanner);
static bool handleWeakGroup(const QCString &,yyscan_t yyscanner);
static bool handleNamespace(const QCString &,yyscan_t yyscanner);
static bool handlePackage(const QCString &,yyscan_t yyscanner);
static bool handleClass(const QCString &,yyscan_t yyscanner);
static bool handleHeaderFile(const QCString &,yyscan_t yyscanner);
static bool handleProtocol(const QCString &,yyscan_t yyscanner);
static bool handleCategory(const QCString &,yyscan_t yyscanner);
static bool handleUnion(const QCString &,yyscan_t yyscanner);
static bool handleStruct(const QCString &,yyscan_t yyscanner);
static bool handleInterface(const QCString &,yyscan_t yyscanner);
static bool handleIdlException(const QCString &,yyscan_t yyscanner);
static bool handlePage(const QCString &,yyscan_t yyscanner);
static bool handleMainpage(const QCString &,yyscan_t yyscanner);
static bool handleFile(const QCString &,yyscan_t yyscanner);
static bool handleDir(const QCString &,yyscan_t yyscanner);
static bool handleExample(const QCString &,yyscan_t yyscanner);
static bool handleDetails(const QCString &,yyscan_t yyscanner);
static bool handleName(const QCString &,yyscan_t yyscanner);
static bool handleTodo(const QCString &,yyscan_t yyscanner);
static bool handleTest(const QCString &,yyscan_t yyscanner);
static bool handleBug(const QCString &,yyscan_t yyscanner);
static bool handleSubpage(const QCString &s,yyscan_t yyscanner);
static bool handleDeprecated(const QCString &,yyscan_t yyscanner);
static bool handleXRefItem(const QCString &,yyscan_t yyscanner);
static bool handleRelated(const QCString &,yyscan_t yyscanner);
static bool handleRelatedAlso(const QCString &,yyscan_t yyscanner);
static bool handleMemberOf(const QCString &,yyscan_t yyscanner);
static bool handleRefItem(const QCString &,yyscan_t yyscanner);
static bool handleSection(const QCString &,yyscan_t yyscanner);
static bool handleAnchor(const QCString &,yyscan_t yyscanner);
static bool handleCite(const QCString &,yyscan_t yyscanner);
static bool handleFormatBlock(const QCString &,yyscan_t yyscanner);
static bool handleAddIndex(const QCString &,yyscan_t yyscanner);
static bool handleIf(const QCString &,yyscan_t yyscanner);
static bool handleIfNot(const QCString &,yyscan_t yyscanner);
static bool handleElseIf(const QCString &,yyscan_t yyscanner);
static bool handleElse(const QCString &,yyscan_t yyscanner);
static bool handleEndIf(const QCString &,yyscan_t yyscanner);
static bool handleIngroup(const QCString &,yyscan_t yyscanner);
static bool handleNoSubGrouping(const QCString &,yyscan_t yyscanner);
static bool handleShowInitializer(const QCString &,yyscan_t yyscanner);
static bool handleHideInitializer(const QCString &,yyscan_t yyscanner);
static bool handleCallgraph(const QCString &,yyscan_t yyscanner);
static bool handleHideCallgraph(const QCString &,yyscan_t yyscanner);
static bool handleCallergraph(const QCString &,yyscan_t yyscanner);
static bool handleHideCallergraph(const QCString &,yyscan_t yyscanner);
static bool handleInternal(const QCString &,yyscan_t yyscanner);
static bool handleLineBr(const QCString &,yyscan_t yyscanner);
static bool handleStatic(const QCString &,yyscan_t yyscanner);
static bool handlePure(const QCString &,yyscan_t yyscanner);
static bool handlePrivate(const QCString &,yyscan_t yyscanner);
static bool handlePrivateSection(const QCString &,yyscan_t yyscanner);
static bool handleProtected(const QCString &,yyscan_t yyscanner);
static bool handleProtectedSection(const QCString &,yyscan_t yyscanner);
static bool handlePublic(const QCString &s,yyscan_t yyscanner);
static bool handlePublicSection(const QCString &s,yyscan_t yyscanner);
static bool handleToc(const QCString &s,yyscan_t yyscanner);
static bool handleInherit(const QCString &,yyscan_t yyscanner);
static bool handleExtends(const QCString &,yyscan_t yyscanner);
static bool handleCopyDoc(const QCString &,yyscan_t yyscanner);
static bool handleCopyBrief(const QCString &,yyscan_t yyscanner);
static bool handleCopyDetails(const QCString &,yyscan_t yyscanner);
static bool handleParBlock(const QCString &,yyscan_t yyscanner);
static bool handleEndParBlock(const QCString &,yyscan_t yyscanner);
static bool handleParam(const QCString &,yyscan_t yyscanner);
static bool handleRetval(const QCString &,yyscan_t yyscanner);

typedef bool (*DocCmdFunc)(const QCString &name,yyscan_t yyscanner);

struct DocCmdMap
{
  const char *cmdName;
  DocCmdFunc handler;
  bool endsBrief;
};

// map of command to handler function
static DocCmdMap docCmdMap[] =
{
  // command name      handler function         ends brief description
  { "brief",           &handleBrief,            FALSE },
  { "short",           &handleBrief,            FALSE },
  { "fn",              &handleFn,               FALSE },
  { "var",             &handleFn,               FALSE },
  { "typedef",         &handleFn,               FALSE },
  { "property",        &handleFn,               FALSE },
  { "def",             &handleDef,              FALSE },
  { "overload",        &handleOverload,         FALSE },
  { "enum",            &handleEnum,             FALSE },
  { "defgroup",        &handleDefGroup,         FALSE },
  { "addtogroup",      &handleAddToGroup,       FALSE },
  { "weakgroup",       &handleWeakGroup,        FALSE },
  { "namespace",       &handleNamespace,        FALSE },
  { "package",         &handlePackage,          FALSE },
  { "class",           &handleClass,            FALSE },
  { "headerfile",      &handleHeaderFile,       FALSE },
  { "protocol",        &handleProtocol,         FALSE },
  { "category",        &handleCategory,         FALSE },
  { "union",           &handleUnion,            FALSE },
  { "struct",          &handleStruct,           FALSE },
  { "interface",       &handleInterface,        FALSE },
  { "idlexcept",       &handleIdlException,     FALSE },
  { "page",            &handlePage,             FALSE },
  { "mainpage",        &handleMainpage,         FALSE },
  { "file",            &handleFile,             FALSE },
  { "dir",             &handleDir,              FALSE },
  { "example",         &handleExample,          FALSE },
  { "details",         &handleDetails,          TRUE  },
  { "name",            &handleName,             FALSE },
  { "todo",            &handleTodo,             FALSE }, // end brief will be done differently
  { "test",            &handleTest,             FALSE }, // end brief will be done differently
  { "bug",             &handleBug,              FALSE }, // end brief will be done differently
  { "deprecated",      &handleDeprecated,       FALSE }, // end brief will be done differently
  { "xrefitem",        &handleXRefItem,         FALSE }, // end brief will be done differently
  { "related",         &handleRelated,          TRUE  },
  { "relates",         &handleRelated,          TRUE  },
  { "relatedalso",     &handleRelatedAlso,      TRUE  },
  { "relatesalso",     &handleRelatedAlso,      TRUE  },
  { "parblock",        &handleParBlock,         TRUE  },
  { "endparblock",     &handleEndParBlock,      TRUE  },
  { "refitem",         &handleRefItem,          TRUE  },
  { "cite",            &handleCite,             FALSE },
  { "subpage",         &handleSubpage,          TRUE  },
  { "section",         &handleSection,          TRUE  },
  { "subsection",      &handleSection,          TRUE  },
  { "subsubsection",   &handleSection,          TRUE  },
  { "paragraph",       &handleSection,          TRUE  },
  { "anchor",          &handleAnchor,           TRUE  },
  { "verbatim",        &handleFormatBlock,      TRUE  },
  { "latexonly",       &handleFormatBlock,      FALSE },
  { "htmlonly",        &handleFormatBlock,      FALSE },
  { "xmlonly",         &handleFormatBlock,      FALSE },
  { "docbookonly",     &handleFormatBlock,      FALSE },
  { "rtfonly",         &handleFormatBlock,      FALSE },
  { "manonly",         &handleFormatBlock,      FALSE },
  { "dot",             &handleFormatBlock,      TRUE  },
  { "msc",             &handleFormatBlock,      TRUE  },
  { "startuml",        &handleFormatBlock,      TRUE  },
  { "code",            &handleFormatBlock,      TRUE  },
  { "addindex",        &handleAddIndex,         FALSE },
  { "if",              &handleIf,               FALSE },
  { "ifnot",           &handleIfNot,            FALSE },
  { "elseif",          &handleElseIf,           FALSE },
  { "else",            &handleElse,             FALSE },
  { "endif",           &handleEndIf,            FALSE },
  { "ingroup",         &handleIngroup,          FALSE },
  { "nosubgrouping",   &handleNoSubGrouping,    FALSE },
  { "showinitializer", &handleShowInitializer,  FALSE },
  { "hideinitializer", &handleHideInitializer,  FALSE },
  { "callgraph",       &handleCallgraph,        FALSE },
  { "hidecallgraph",   &handleHideCallgraph,    FALSE },
  { "callergraph",     &handleCallergraph,      FALSE },
  { "hidecallergraph", &handleHideCallergraph,  FALSE },
  { "internal",        &handleInternal,         TRUE  },
  { "_linebr",         &handleLineBr,           FALSE },
  { "static",          &handleStatic,           FALSE },
  { "pure",            &handlePure,             FALSE },
  { "private",         &handlePrivate,          FALSE },
  { "privatesection",  &handlePrivateSection,   FALSE },
  { "protected",       &handleProtected,        FALSE },
  { "protectedsection",&handleProtectedSection, FALSE },
  { "public",          &handlePublic,           FALSE },
  { "publicsection",   &handlePublicSection,    FALSE },
  { "tableofcontents", &handleToc,              FALSE },
  { "inherit",         &handleInherit,          TRUE  },
  { "extends",         &handleExtends,          TRUE  },
  { "implements",      &handleExtends,          TRUE  },
  { "memberof",        &handleMemberOf,         TRUE  },
  { "arg",             0,                       TRUE  },
  { "attention",       0,                       TRUE  },
  { "author",          0,                       TRUE  },
  { "authors",         0,                       TRUE  },
  { "copydoc",         &handleCopyDoc,          TRUE  },
  { "copybrief",       &handleCopyBrief,        FALSE },
  { "copydetails",     &handleCopyDetails,      TRUE  },
  { "copyright",       0,                       TRUE  },
  { "date",            0,                       TRUE  },
  { "dotfile",         0,                       TRUE  },
  { "htmlinclude",     0,                       FALSE },
  { "image",           0,                       TRUE  },
  { "include",         0,                       TRUE  },
  { "includelineno",   0,                       TRUE  },
  { "invariant",       0,                       TRUE  },
  { "latexinclude",    0,                       FALSE },
  { "li",              0,                       TRUE  },
  { "line",            0,                       TRUE  },
  { "note",            0,                       TRUE  },
  { "par",             0,                       TRUE  },
  { "param",           &handleParam,            TRUE  },
  { "tparam",          0,                       TRUE  },
  { "post",            0,                       TRUE  },
  { "pre",             0,                       TRUE  },
  { "remark",          0,                       TRUE  },
  { "remarks",         0,                       TRUE  },
  { "result",          0,                       TRUE  },
  { "return",          0,                       TRUE  },
  { "returns",         0,                       TRUE  },
  { "exception",       0,                       TRUE  },
  { "retval",          &handleRetval,           TRUE  },
  { "sa",              0,                       TRUE  },
  { "see",             0,                       TRUE  },
  { "since",           0,                       TRUE  },
  { "throw",           0,                       TRUE  },
  { "throws",          0,                       TRUE  },
  { "until",           0,                       TRUE  },
  { "verbinclude",     0,                       FALSE },
  { "version",         0,                       TRUE  },
  { "warning",         0,                       TRUE  },
  { 0, 0, FALSE }
};

/** @brief Command mapper.
 *
 *  Maps a command name (as found in a comment block) onto a
 *  specific handler function.
 */
class DocCmdMapper
{
  public:
    struct Cmd
    {
      DocCmdFunc func;
      bool endsBrief;
    };

    /** maps a command name to a handler function */
    static Cmd *map(const char *name)
    {
      return instance()->find(name);
    }

    /** release the singleton */
    static void freeInstance()
    {
      delete s_instance; s_instance=0;
    }

  private:
    static DocCmdMapper *instance()
    {
      if (s_instance==0) s_instance = new DocCmdMapper;
      return s_instance;
    }

    DocCmdMapper() : m_map(113)
    {
      m_map.setAutoDelete(TRUE);
      DocCmdMap *p = docCmdMap;
      while (p->cmdName)
      {
	if (m_map.find(p->cmdName)!=0)
	{
	  err("DocCmdMapper: command %s already added\n",p->cmdName);
	  exit(1);
	}
	Cmd *cmd = new Cmd;
	cmd->func = p->handler;
	cmd->endsBrief = p->endsBrief;
	m_map.insert(p->cmdName,cmd);
	p++;
      }
    }

    Cmd *find(const char *name)
    {
      return m_map.find(name);
    }
    QDict<Cmd> m_map;
    static DocCmdMapper *s_instance;
};

enum XRefKind
{
  XRef_Item,
  XRef_Todo,
  XRef_Test,
  XRef_Bug,
  XRef_Deprecated,
  XRef_None
};

enum OutputContext
{
  OutputDoc,
  OutputBrief,
  OutputXRef,
  OutputInbody
};

enum GuardType
{
  Guard_If,
  Guard_IfNot,
  Guard_Skip
};

class GuardedSection
{
  public:
    GuardedSection(bool enabled,bool parentVisible) 
      : m_enabled(enabled),m_parentVisible(parentVisible) {}
    bool isEnabled() const { return m_enabled; }
    bool parentVisible() const { return m_parentVisible; }
  
  private:
    bool m_enabled;
    bool m_parentVisible;
};

static void groupAddDocs(Entry *e,yyscan_t yyscanner);
static void initParser(yyscan_t yyscanner);
static bool getDocSectionName(int s);
static bool makeStructuralIndicator(Entry::Sections s,yyscan_t yyscanner);
static void lineCount(yyscan_t yyscanner);
static QCString stripQuotes(const char *s);
static void addXRefItem(const char *listName,const char *itemTitle,
                        const char *listTitle,bool append,yyscan_t yyscanner);
static QCString addFormula(yyscan_t yyscanner);
static void checkFormula(yyscan_t yyscanner);
static SectionInfo::SectionType sectionLevelToType(int level);
static void addSection(yyscan_t yyscanner);
static void addCite(yyscan_t yyscanner);
static void stripTrailingWhiteSpace(QCString &s);
static inline void setOutput(OutputContext ctx,yyscan_t yyscanner);
static void addAnchor(const char *anchor,yyscan_t yyscanner);
static inline void addOutput(const char *s,yyscan_t yyscanner);
static inline void addOutput(char c,yyscan_t yyscanner);
static void endBrief(bool addToOutput,yyscan_t yyscanner);
static void handleGuard(const QCString &expr,yyscan_t yyscanner);
static int yyread(char *buf,int max_size,yyscan_t yyscanner);

/* -----------------------------------------------------------------
 *
 *	statics
 */
struct commentscanYY_state
{
  ParserInterface *langParser;          // the language parser that is calling us
  QCString         inputString;         // input string
  int              inputPosition;       // read pointer
  QCString         yyFileName;          // file name that is read from
  int              yyLineNr;            // line number in the input
  bool             inBody;              // was the comment found inside the body of a function?
  OutputContext    inContext;           // are we inside the brief, details or xref part
  bool             briefEndsAtDot;      // does the brief description stop at a dot?
  QCString         formulaText;         // Running text of a formula
  QCString         formulaEnv;          // environment name
  int              formulaNewLines;     // amount of new lines in the formula
  QCString        *pOutputString;       // pointer to string to which the output is appended.
  QCString         outputXRef;          // temp argument of todo/test/../xrefitem commands
  QCString         blockName;           // preformatted block name (e.g. verbatim, latexonly,...)
  XRefKind         xrefKind;            // kind of cross-reference command
  XRefKind         newXRefKind;         // 
  GuardType        guardType;           // kind of guard for conditional section
  bool             enabledSectionFound;
  QCString         functionProto;       // function prototype
  QStack<GuardedSection> guards;        // tracks nested conditional sections (if,ifnot,..)
  Entry           *current;             // working entry
  //Entry           *current_root = 0 ;   // parent of working entry


  //Entry           *previous     = 0 ;   // TODO: remove need for this
  bool             needNewEntry;

  QCString         sectionLabel;
  QCString         sectionTitle;
  int              sectionLevel;
  QCString         xrefItemKey;
  QCString         newXRefItemKey;
  QCString         xrefItemTitle;
  QCString         xrefListTitle;
  Protection       protection;

  bool             xrefAppendFlag;
  bool             inGroupParamFound;
  int              braceCount;
  bool             insidePre;
  bool             parseMore;
  int              condCount;

  int              commentCount;
  QCString         spaceBeforeCmd;
  QCString         spaceBeforeIf;
  QCString         copyDocArg;

  QCString         guardExpr;
  int              roundCount;

  bool             insideParBlock;

  QStack<Grouping> autoGroupStack;
  int              memberGroupId;
  QCString         memberGroupHeader;
  QCString         memberGroupDocs;
  QCString         memberGroupRelates;
  QCString         compoundName;

  int              prevPosition;
  bool             inInternalDocs;
};

#undef	YY_INPUT
#define	YY_INPUT(buf,result,max_size) result=yyread(buf,max_size,yyscanner);


%}

       /* start command character */
CMD	  ("\\"|"@")
DCMD1     ("arg"|"attention"|"author"|"cite"|"code")
DCMD2     ("date"|"dot"|"msc"|"dotfile"|"example"|"startuml")
DCMD3     ("htmlinclude"|"htmlonly"|"image"|"include")
DCMD4     ("includelineno"|"internal"|"invariant")
DCMD5     ("latexinclude"|"latexonly"|"li"|"line"|"manonly"|"name")
DCMD6     ("note"|"par"|"paragraph"|"param"|"post")
DCMD7     ("pre"|"remarks"|(("relate"[sd])("also")?))
DCMD8     ("remarks"|("return"[s]?)|"retval"|"sa"|"section")
DCMD9     ("see"|"since"|"subsection"|"subsubsection")
DCMD10    ("throw"|"until"|"verbatim")
DCMD11    ("verbinclude"|"version"|"warning")
DETAILEDCMD {CMD}({DCMD1}|{DCMD2}|{DCMD3}|{DCMD4}|{DCMD5}|{DCMD6}|{DCMD7}|{DCMD8}|{DCMD9}|{DCMD10}|{DCMD11})
XREFCMD   {CMD}("bug"|"deprecated"|"test"|"todo"|"xrefitem")  
PRE       [pP][rR][eE]
TABLE	  [tT][aA][bB][lL][eE]
P	  [pP]
UL        [uU][lL]
OL	  [oO][lL]
DL	  [dD][lL]
IMG       [iI][mM][gG]
HR        [hH][rR]
PARA      [pP][aA][rR][aA]
CODE      [cC][oO][dD][eE]
CAPTION   [cC][aA][pP][tT][iI][oO][nN]
DETAILEDHTML {PRE}|{UL}|{TABLE}|{OL}|{DL}|{P}|[Hh][1-6]|{IMG}|{HR}|{PARA}
DETAILEDHTMLOPT {CODE}
BN        [ \t\n\r]
BL        [ \t\r]*"\n" 
B         [ \t]
BS        ^(({B}*"//")?)(({B}*"*"+)?){B}*
ATTR      ({B}+[^>\n]*)?
DOCNL     "\n"|"\\_linebr"
LC        "\\"{B}*"\n"
NW	  [^a-z_A-Z0-9]
FILESCHAR [a-z_A-Z0-9\x80-\xFF\\:\\\/\-\+@&#]
FILEECHAR [a-z_A-Z0-9\x80-\xFF\-\+@&#]
FILE      ({FILESCHAR}*{FILEECHAR}+("."{FILESCHAR}*{FILEECHAR}+)*)|("\""[^\n\"]*"\"")
ID        "$"?[a-z_A-Z\x80-\xFF][a-z_A-Z0-9\x80-\xFF]*
LABELID   [a-z_A-Z\x80-\xFF][a-z_A-Z0-9\x80-\xFF\-]*
CITESCHAR [a-z_A-Z0-9\x80-\xFF]
CITEECHAR [a-z_A-Z0-9\x80-\xFF\-\+:\/]*
CITEID    {CITESCHAR}{CITEECHAR}*("."{CITESCHAR}{CITEECHAR}*)*
SCOPEID   {ID}({ID}*{BN}*"::"{BN}*)*({ID}?)
SCOPENAME "$"?(({ID}?{BN}*("::"|"."){BN}*)*)((~{BN}*)?{ID})
TMPLSPEC  "<"{BN}*[^>]+{BN}*">"
MAILADDR   [a-z_A-Z0-9.+\-]+"@"[a-z_A-Z0-9\-]+("."[a-z_A-Z0-9\-]+)+[a-z_A-Z0-9\-]+ 
RCSTAG    "$"{ID}":"[^\n$]+"$"


  /* comment parsing states. */
%x      Comment
%x      PageDocArg1
%x      PageDocArg2
%x      RelatesParam1
%x      ClassDocArg1
%x      ClassDocArg2
%x      ClassDocArg3
%x      CategoryDocArg1
%x      XRefItemParam1
%x      XRefItemParam2
%x      XRefItemParam3
%x      FileDocArg1
%x      ParamArg1
%x	EnumDocArg1
%x	NameSpaceDocArg1
%x	PackageDocArg1
%x	GroupDocArg1
%x	GroupDocArg2
%x	SectionLabel
%x	SectionTitle
%x	SubpageLabel
%x	SubpageTitle
%x	FormatBlock
%x	LineParam
%x	GuardParam
%x	GuardParamEnd
%x	SkipGuardedSection
%x	SkipInternal
%x      NameParam
%x	InGroupParam
%x	FnParam
%x	OverloadParam
%x	InheritParam
%x	ExtendsParam
%x      ReadFormulaShort
%x	ReadFormulaLong
%x	AnchorLabel
%x      HtmlComment
%x      SkipLang
%x	CiteLabel
%x	CopyDoc
%x      GuardExpr

%%

  /* What can happen in while parsing a comment block:
   *   commands (e.g. @page, or \page)
   *   escaped commands (e.g. @@page or \\page).
   *   formulas (e.g. \f$ \f[ \f{..)
   *   directories (e.g. \doxygen\src\)
   *   autolist end. (e.g. a dot on an otherwise empty line)
   *   newlines.
   *   end of brief description due to blank line.
   *   end of brief description due to some command (@command, or <command>).
   *   words and whitespace and other characters (#,?!, etc).
   *   grouping commands (e.g. @{ and @})
   *   language switch (e.g. \~english or \~).
   *   mail address (e.g. dimitri@stack.nl).
   *   quoted text, such as "foo@bar"
   *   XML commands, <summary></summary><remarks></remarks>
   */

<Comment>{CMD}{CMD}[a-z_A-Z]+{B}*	{ // escaped command
  					  addOutput(yytext,yyscanner);
  					}
<Comment>{CMD}{CMD}"~"[a-z_A-Z]*	{ // escaped command
  					  addOutput(yytext,yyscanner);
  					}
<Comment>{MAILADDR}			{ // mail address
  					  addOutput(yytext,yyscanner);
  					}
<Comment>"\""[^"\n]*"\""		{ // quoted text
                                          addOutput(yytext,yyscanner);
  					}
<Comment>("\\"[a-z_A-Z]+)+"\\"		{ // directory (or chain of commands!)
  					  addOutput(yytext,yyscanner);
  					}
<Comment>"<"{DETAILEDHTML}{ATTR}">"	{ // HTML command that ends a brief description
					  setOutput(OutputDoc,yyscanner);
					  // continue with the same input
                                          REJECT;
					}
<Comment>"<"{DETAILEDHTMLOPT}{ATTR}">"	{ // HTML command that ends a brief description
					  if (yyextra->current->lang==SrcLangExt_CSharp)
                                          {
                                            setOutput(OutputDoc,yyscanner);
                                          }
					  // continue with the same input
                                          REJECT;
					}
<Comment>"<summary>"			{ // start of a .NET XML style brief description
					  setOutput(OutputBrief,yyscanner);
                                          addOutput(yytext,yyscanner);
  					}
<Comment>"<remarks>"            	{ // start of a .NET XML style detailed description
					  setOutput(OutputDoc,yyscanner);
                                          addOutput(yytext,yyscanner);
  					}
<Comment>"</summary>"	                { // start of a .NET XML style detailed description
                                          addOutput(yytext,yyscanner);
					  setOutput(OutputDoc,yyscanner);
  					}
<Comment>"</remarks>"			{ // end of a brief or detailed description
                                          addOutput(yytext,yyscanner);
  					}
<Comment>"<"{CAPTION}{ATTR}">"          {
                                          QCString tag=yytext;
                                          int s=tag.find("id=");
                                          if (s!=-1) // command has id attribute
                                          {
                                            char c=tag[s+3];
                                            if (c=='\'' || c=='"') // valid start
                                            {
                                              int e=tag.find(c,s+4);
                                              if (e!=-1) // found matching end
                                              {
                                                QCString id=tag.mid(s+4,e-s-4); // extract id
                                                addAnchor(id,yyscanner);
                                              }
                                            }
                                          }
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>"<"{PRE}{ATTR}">"              {
                                          yyextra->insidePre=TRUE;
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>"</"{PRE}">"                   {
                                          yyextra->insidePre=FALSE;
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>{RCSTAG}			{ // RCS tag which end a brief description
  					  setOutput(OutputDoc,yyscanner);
					  REJECT;
  					}
<Comment>"<!--"				{ 
  					  BEGIN(HtmlComment);
					}
<Comment>{B}*{CMD}"endinternal"{B}*	{
                                          addOutput("\\endinternal ",yyscanner); 
                                          if (!yyextra->inInternalDocs)
  					    warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "found \\endinternal without matching \\internal"
                                              );
                                          yyextra->inInternalDocs = FALSE;
  					}
<Comment>{B}*{CMD}[a-z_A-Z]+{B}*	{ // potentially interesting command
                                          // the {B}* in the front was added for bug620924
  					  QCString cmdName = QCString(yytext).stripWhiteSpace().data()+1;
					  DocCmdMapper::Cmd *cmdPtr = DocCmdMapper::map(cmdName);
					  if (cmdPtr) // special action is required
					  {
                                            int i=0;
                                            while (yytext[i]==' ' || yytext[i]=='\t') i++;
					    yyextra->spaceBeforeCmd = QCString(yytext).left(i);
					    if (cmdPtr->endsBrief && !(yyextra->inContext==OutputXRef && cmdName=="parblock"))
					    {
					      yyextra->briefEndsAtDot=FALSE;
					      // this command forces the end of brief description
					      setOutput(OutputDoc,yyscanner);
					    }
                                            //if (i>0) addOutput(QCString(yytext).left(i)); // removed for bug 689341
					    if (cmdPtr->func && cmdPtr->func(cmdName,yyscanner))
					    {
					      // implicit split of the comment block into two
					      // entries. Restart the next block at the start
					      // of this command.
					      yyextra->parseMore=TRUE;

					      // yuk, this is probably not very portable across lex implementations, 
					      // but we need to know the position in the input buffer where this 
					      // rule matched.
					      // for flex 2.5.33+ we should use YY_CURRENT_BUFFER_LVALUE
#if YY_FLEX_MAJOR_VERSION>=2 && (YY_FLEX_MINOR_VERSION>5 || (YY_FLEX_MINOR_VERSION==5 && YY_FLEX_SUBMINOR_VERSION>=33))
					      yyextra->inputPosition=yyextra->prevPosition + (int)(yy_bp - YY_CURRENT_BUFFER_LVALUE->yy_ch_buf);
#else
					      yyextra->inputPosition=yyextra->prevPosition + (int)(yy_bp - yy_current_buffer->yy_ch_buf);
#endif
					      yyterminate();
					    }
					    else if (cmdPtr->func==0)
					    {
					      // command without handler, to be processed
					      // later by parsedoc.cpp
					      addOutput(yytext,yyscanner);
					    }
					  }
					  else // command not relevant
					  {
					    addOutput(yytext,yyscanner);
					  }
  					}
<Comment>{B}*("\\\\"|"@@")"f"[$\[{]	{ // escaped formula command
  					  addOutput(yytext,yyscanner);
  					}
<Comment>{B}*{CMD}"~"[a-z_A-Z-]*		{ // language switch command
                                          QCString langId = QString(yytext).stripWhiteSpace().data()+2;
			       	          if (!langId.isEmpty() &&
					      qstricmp(Config_getEnum(OUTPUT_LANGUAGE),langId)!=0)
				          { // enable language specific section
				            BEGIN(SkipLang);
				          }
  					}
<Comment>{B}*{CMD}"f{"[^}\n]+"}"("{"?)  { // start of a formula with custom environment
					  yyextra->formulaText="\\begin";
					  yyextra->formulaEnv=QString(yytext).stripWhiteSpace().data()+2;
					  if (yyextra->formulaEnv.at(yyextra->formulaEnv.length()-1)=='{')
					  {
					    // remove trailing open brace
					    yyextra->formulaEnv=yyextra->formulaEnv.left(yyextra->formulaEnv.length()-1);
					  }
					  yyextra->formulaText+=yyextra->formulaEnv;
					  yyextra->formulaNewLines=0;
					  BEGIN(ReadFormulaLong);
  					}
<Comment>{B}*{CMD}"f$"			{ // start of a inline formula
					  yyextra->formulaText="$";
					  yyextra->formulaNewLines=0;
					  BEGIN(ReadFormulaShort);
  					}
<Comment>{B}*{CMD}"f["			{ // start of a block formula
					  yyextra->formulaText="\\[";
					  yyextra->formulaNewLines=0;
					  BEGIN(ReadFormulaLong);
  					}
<Comment>{B}*{CMD}"{"                   { // begin of a group
                                          //yyextra->langParser->handleGroupStartCommand(yyextra->memberGroupHeader);
                                          openGroup(yyextra->current,yyextra->yyFileName,yyextra->yyLineNr);
                                        }
<Comment>{B}*{CMD}"}"                   { // end of a group
                                          //yyextra->langParser->handleGroupEndCommand();
                                          closeGroup(yyextra->current,yyextra->yyFileName,yyextra->yyLineNr,TRUE);
                                          yyextra->memberGroupHeader.resize(0);
					  yyextra->parseMore=TRUE;
                                          yyextra->needNewEntry = TRUE;
#if YY_FLEX_MAJOR_VERSION>=2 && (YY_FLEX_MINOR_VERSION>5 || (YY_FLEX_MINOR_VERSION==5 && YY_FLEX_SUBMINOR_VERSION>=33))
				          yyextra->inputPosition=yyextra->prevPosition + (int)(yy_bp - YY_CURRENT_BUFFER_LVALUE->yy_ch_buf) + strlen(yytext);
#else
				          yyextra->inputPosition=yyextra->prevPosition + (int)(yy_bp - yy_current_buffer->yy_ch_buf) + strlen(yytext);
#endif
					  yyterminate();
                                        }
<Comment>{B}*{CMD}[$@\\&~<>#%]		{ // escaped character
  					  addOutput(yytext,yyscanner);
  					}
<Comment>[a-z_A-Z]+			{ // normal word
					  addOutput(yytext,yyscanner);
  					}
<Comment>^{B}*"."{B}*/\n                { // explicit end autolist: e.g "  ."
  				          addOutput(yytext,yyscanner);
					}
<Comment>^{B}*[1-9][0-9]*"."{B}+        |
<Comment>^{B}*[*+]{B}+			{ // start of autolist
                                          if (!Doxygen::markdownSupport)
                                          {
                                            REJECT;
                                          }
                                          else
                                          {
                                            if (yyextra->inContext!=OutputXRef) 
                                            {
                                              yyextra->briefEndsAtDot=FALSE;
                                              setOutput(OutputDoc,yyscanner);
                                            }
                                            addOutput(yytext,yyscanner);
                                          }
  					}
<Comment>^{B}*"-"{B}+			{ // start of autolist
					  if (yyextra->inContext!=OutputXRef) 
					  {
					    yyextra->briefEndsAtDot=FALSE;
					    setOutput(OutputDoc,yyscanner);
					  }
  				          addOutput(yytext,yyscanner);
  					}
<Comment>^{B}*([\-:|]{B}*)*("--"|"---")({B}*[\-:|])*{B}*/\n { // horizontal line (dashed)
  				          addOutput(yytext,yyscanner);
                                        }
<Comment>{CMD}"---"                     { // escaped mdash
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>{CMD}"--"                      { // escaped mdash
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>"---"                          { // mdash
                                          addOutput(yyextra->insidePre || Doxygen::markdownSupport ? yytext : "&mdash;",yyscanner);
                                        }
<Comment>"--"                           { // ndash
                                          addOutput(yyextra->insidePre || Doxygen::markdownSupport ? yytext : "&ndash;",yyscanner);
                                        }
<Comment>"-#"{B}+                       { // numbered item
                                          addOutput(yytext,yyscanner);
                                        }
<Comment>("."+)[a-z_A-Z0-9\)]		{ // . at start or in the middle of a word, or ellipsis
  					  addOutput(yytext,yyscanner);
  					}
<Comment>".\\"[ \t]			{ // . with escaped space.
  					  addOutput(yytext[0],yyscanner);
  					  addOutput(yytext[2],yyscanner);
  					}
<Comment>".,"				{ // . with comma such as "e.g.," 
  					  addOutput(yytext,yyscanner);
  					}
<Comment>"...\\"[ \t]			{ // ellipsis with escaped space.
  					  addOutput("... ",yyscanner);
  					}
<Comment>".."[\.]?/[^ \t\n] 		{ // internal ellipsis 
  					  addOutput(yytext,yyscanner);
  					}
<Comment>(\n|\\_linebr)({B}*(\n|\\_linebr))+	{ // at least one blank line (or blank line command)
					  if (yyextra->inContext==OutputXRef)
					  {
					    // see bug 613024, we need to put the newlines after ending the XRef section.
					    if (!yyextra->insideParBlock) setOutput(OutputDoc,yyscanner);
                                            int i;
                                            for (i=0;i<yyleng;)
                                            {
                                              if (yytext[i]=='\n') addOutput('\n',yyscanner),i++;
                                              else if (strcmp(yytext+i,"\\_linebr")==0) addOutput('\n',yyscanner),i+=8;
                                              else i++;
                                            }
					  }
					  else if (yyextra->inContext!=OutputBrief)
					  {
                                            int i;
                                            for (i=0;i<yyleng;)
                                            {
                                              if (yytext[i]=='\n') addOutput('\n',yyscanner),i++;
                                              else if (strcmp(yytext+i,"\\_linebr")==0) addOutput('\n',yyscanner),i+=8;
                                              else i++;
                                            }
					    setOutput(OutputDoc,yyscanner);
					  }
					  else // yyextra->inContext==OutputBrief
					  { // only go to the detailed description if we have
					    // found some brief description and not just whitespace
					    endBrief(FALSE,yyscanner);
					  }
  					  lineCount(yyscanner);
  					}
<Comment>"."				{ // potential end of a JavaDoc style comment
  					  addOutput(*yytext,yyscanner);
  					  if (yyextra->briefEndsAtDot)
					  {
					    setOutput(OutputDoc,yyscanner);
					    yyextra->briefEndsAtDot=FALSE;
					  }
  					}
<Comment>\n				{ // newline
  					  addOutput(*yytext,yyscanner);
  					  yyextra->yyLineNr++;
  					}
<Comment>.				{ // catch-all for anything else
  					  addOutput(*yytext,yyscanner);
  					}


 /* --------------   Rules for handling HTML comments ----------- */

<HtmlComment>"--"[!]?">"{B}*		{ BEGIN( Comment ); }
<HtmlComment>{DOCNL}			{ 
  					  if (*yytext=='\n') yyextra->yyLineNr++;
  					}
<HtmlComment>[^\\\n\-]+			{ // ignore unimportant characters
  					}
<HtmlComment>.				{ // ignore every else
  					}

 /* --------------   Rules for handling formulas ---------------- */
 
<ReadFormulaShort>{CMD}"f$"		{ // end of inline formula
  					  yyextra->formulaText+="$";
					  addOutput(" "+addFormula(yyscanner),yyscanner);
					  BEGIN(Comment);
  					}
<ReadFormulaLong>{CMD}"f]"		{ // end of block formula
					  yyextra->formulaText+="\\]";
					  addOutput(" "+addFormula(yyscanner),yyscanner);
					  BEGIN(Comment);
  					}
<ReadFormulaLong>{CMD}"f}"		{ // end of custom env formula
					  yyextra->formulaText+="\\end";
					  yyextra->formulaText+=yyextra->formulaEnv;
					  addOutput(" "+addFormula(yyscanner),yyscanner);
					  BEGIN(Comment);
  					}
<ReadFormulaLong,ReadFormulaShort>[^\\@\n]+ { // any non-special character
                                          yyextra->formulaText+=yytext; 
 					} 
<ReadFormulaLong,ReadFormulaShort>\n	{ // new line
                                          yyextra->formulaNewLines++;
                                          yyextra->formulaText+=*yytext; 
					  yyextra->yyLineNr++; 
					}
<ReadFormulaLong,ReadFormulaShort>.     { // any othe character
                                          yyextra->formulaText+=*yytext; 
					}

  /* ------------ handle argument of enum command --------------- */

<EnumDocArg1>{SCOPEID}			{ // handle argument
  					  yyextra->current->name = yytext;
					  BEGIN( Comment );
  					}
<EnumDocArg1>{LC}			{ // line continuation
  					  yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
                                        }
<EnumDocArg1>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing argument after \\enum."
                                              );
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
  					}
<EnumDocArg1>.				{ // ignore other stuff
  					}

  /* ------------ handle argument of namespace command --------------- */

<NameSpaceDocArg1>{SCOPENAME}		{ // handle argument
  					  yyextra->current->name = substitute(yytext,".","::");
					  BEGIN( Comment );
  					}
<NameSpaceDocArg1>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<NameSpaceDocArg1>{DOCNL}		{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing argument after "
					       "\\namespace."
                                              );
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
  					}
<NameSpaceDocArg1>.			{ // ignore other stuff
  					}

  /* ------------ handle argument of package command --------------- */

<PackageDocArg1>{ID}("."{ID})*		{ // handle argument
  					  yyextra->current->name = yytext;
					  BEGIN( Comment );
  					}
<PackageDocArg1>{LC}			{ // line continuation 
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<PackageDocArg1>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing argument after "
					       "\\package."
                                              );
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
  					}
<PackageDocArg1>.			{ // ignore other stuff
  					}

  /* ------ handle argument of class/struct/union command --------------- */

<ClassDocArg1>{SCOPENAME}{TMPLSPEC}     { 
  					  yyextra->current->name = substitute(removeRedundantWhiteSpace(yytext),".","::");
					  BEGIN( ClassDocArg2 );
                                        }
<ClassDocArg1>{SCOPENAME}		{ // first argument
  					  yyextra->current->name = substitute(yytext,".","::");
					  if (yyextra->current->section==Entry::PROTOCOLDOC_SEC)
					  {
					    yyextra->current->name+="-p";
					  }
					  // prepend outer scope name 
					  BEGIN( ClassDocArg2 );
					}
<CategoryDocArg1>{SCOPENAME}{B}*"("[^\)]+")" {
  					  yyextra->current->name = substitute(yytext,".","::");
					  BEGIN( ClassDocArg2 );
   					}
<ClassDocArg1,CategoryDocArg1>{LC}      { // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<ClassDocArg1,CategoryDocArg1>{DOCNL}	{
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing argument after "
					       "\\%s.",YY_START==ClassDocArg1?"class":"category"
                                              );
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
  					}
<ClassDocArg1,CategoryDocArg1>.		{ // ignore other stuff
  					}

<ClassDocArg2>{FILE}|"<>"		{ // second argument; include file
					  yyextra->current->includeFile = yytext;
					  BEGIN( ClassDocArg3 );
					}
<ClassDocArg2>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<ClassDocArg2>{DOCNL}			{ 
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
					}
<ClassDocArg2>.				{ // ignore other stuff
  					}

<ClassDocArg3>[<"]?{FILE}?[">]?		{ // third argument; include file name
 					  yyextra->current->includeName = yytext;
					  BEGIN( Comment );
					}
<ClassDocArg3>{LC}			{ // line continuation
                                          yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
                                        }
<ClassDocArg3>{DOCNL}			{ 
  					  if (*yytext=='\n') yyextra->yyLineNr++;
  					  BEGIN( Comment );
					}
<ClassDocArg3>.				{ // ignore other stuff
  					}

  /* --------- handle arguments of {def,add,weak}group commands --------- */

<GroupDocArg1>{LABELID}(".html"?)	{ // group name
  					  yyextra->current->name = yytext;
					  //lastDefGroup.groupname = yytext;
					  //lastDefGroup.pri = yyextra->current->groupingPri();
  					  // the .html stuff is for Qt compatibility
					  if (yyextra->current->name.right(5)==".html") 
					  {
					    yyextra->current->name=yyextra->current->name.left(yyextra->current->name.length()-5);
					  }
					  yyextra->current->type.resize(0);
					  BEGIN(GroupDocArg2);
  					}
<GroupDocArg1>"\\"{B}*"\n"		{ // line continuation
  					  yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<GroupDocArg1>{DOCNL}			{ // missing argument!
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing group name after %s",
					       yyextra->current->groupDocCmd()
                                              );
					  addOutput('\n',yyscanner);
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  BEGIN( Comment );
  					}
<GroupDocArg2>"\\"{B}*"\n"		{ // line continuation
  					  yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<GroupDocArg2>[^\n\\\*]+		{ // title (stored in type)
					  yyextra->current->type += yytext;
					  yyextra->current->type = yyextra->current->type.stripWhiteSpace();
  					}
<GroupDocArg2>{DOCNL}			{
                                          if ( yyextra->current->groupDocType==Entry::GROUPDOC_NORMAL &&
                                               yyextra->current->type.isEmpty() 
					     ) // defgroup requires second argument
					  {
  					    warn(yyextra->yyFileName,yyextra->yyLineNr,
                                                 "missing title after "
					         "\\defgroup %s", yyextra->current->name.data()
                                                );
					  }
  					  if (*yytext=='\n') yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}

  /* --------- handle arguments of page/mainpage command ------------------- */

<PageDocArg1>{FILE}			{ // first argument; page name
					  yyextra->current->name = stripQuotes(yytext);
					  BEGIN( PageDocArg2 ); 
					}
<PageDocArg1>{LC}			{ yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<PageDocArg1>{DOCNL}			{
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
                                               "missing argument after "
					       "\\page."
                                              );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<PageDocArg1>.				{ // ignore other stuff
  					}
<PageDocArg2>.*"\n"			{ // second argument; page title
  				          yyextra->yyLineNr++;
					  yyextra->current->args = yytext;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
					}

  /* --------- handle arguments of the param command ------------ */
<ParamArg1>{ID}/{B}*","                 {
                                          if (yytext[0]=='_' && Config_getBool(MARKDOWN_SUPPORT))
                                          {
                                            addOutput('\\',yyscanner);
                                          }
                                          addOutput(yytext,yyscanner);
                                        }
<ParamArg1>","                          {
                                          addOutput(" , ",yyscanner);
                                        }
<ParamArg1>{ID}                         {
                                          if (yytext[0]=='_' && Config_getBool(MARKDOWN_SUPPORT))
                                          {
                                            addOutput('\\',yyscanner);
                                          }
                                          addOutput(yytext,yyscanner);
                                          BEGIN( Comment );
                                        }
<ParamArg1>.                            {
                                          unput(yytext[0]);
                                          BEGIN( Comment );
                                        }

  /* --------- handle arguments of the file/dir/example command ------------ */

<FileDocArg1>{DOCNL}			{ // no file name specfied
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
					}
<FileDocArg1>{FILE}			{ // first argument; name
  					  yyextra->current->name = stripQuotes(yytext);
					  BEGIN( Comment );
  				        }
<FileDocArg1>{LC}			{ yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<FileDocArg1>.				{ // ignore other stuff
  					}

  /* --------- handle arguments of the xrefitem command ------------ */

<XRefItemParam1>{LABELID}		{ // first argument
  					  yyextra->newXRefItemKey=yytext;
                                          setOutput(OutputXRef,yyscanner);
					  BEGIN(XRefItemParam2);
					}
<XRefItemParam1>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
                                        }
<XRefItemParam1>{DOCNL}			{ // missing arguments
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					       "Missing first argument of \\xrefitem"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  yyextra->inContext = OutputDoc;
					  BEGIN( Comment );
  					}
<XRefItemParam1>.			{ // ignore other stuff 
  					}

<XRefItemParam2>"\""[^\n\"]*"\""	{ // second argument
  					  yyextra->xrefItemTitle = stripQuotes(yytext);
					  BEGIN(XRefItemParam3);
  					}
<XRefItemParam2>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<XRefItemParam2>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Missing second argument of \\xrefitem"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  yyextra->inContext = OutputDoc;
					  BEGIN( Comment );
  					}
<XRefItemParam2>.			{ // ignore other stuff
  					}

<XRefItemParam3>"\""[^\n\"]*"\""	{ // third argument
  					  yyextra->xrefListTitle = stripQuotes(yytext);
                                          yyextra->xrefKind = XRef_Item;
					  BEGIN( Comment );
  					}
<XRefItemParam2,XRefItemParam3>{LC}	{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<XRefItemParam3>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Missing third argument of \\xrefitem"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  yyextra->inContext = OutputDoc;
					  BEGIN( Comment );
  					}
<XRefItemParam3>.			{ // ignore other stuff
  					}


  /* ----- handle arguments of the relates(also)/memberof command ------- */

<RelatesParam1>({ID}("::"|"."))*{ID}	{ // argument
  					  yyextra->current->relates = yytext;
                                          //if (yyextra->current->mGrpId!=DOX_NOGROUP) 
                                          //{
                                          //  memberGroupRelates = yytext;
                                          //}
					  BEGIN( Comment );
					}
<RelatesParam1>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<RelatesParam1>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Missing argument of \\relates or \\memberof command"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<RelatesParam1>.			{ // ignore other stuff
  					}


  /* ----- handle arguments of the relates(also)/addindex commands ----- */

<LineParam>{DOCNL}			{ // end of argument
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<LineParam>{LC}				{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<LineParam>.				{ // ignore other stuff
  					  addOutput(*yytext,yyscanner);
  					}

  /* ----- handle arguments of the section/subsection/.. commands ------- */

<SectionLabel>{LABELID}			{ // first argyment
  					  yyextra->sectionLabel=yytext;
                                          addOutput(yytext,yyscanner);
					  yyextra->sectionTitle.resize(0);
					  BEGIN(SectionTitle);
  					}
<SectionLabel>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\section command has no label"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<SectionLabel>.				{ // invalid character for section label
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Invalid or missing section label"
					      );
					  BEGIN(Comment);
  					}
<SectionTitle>[^\n@\\*]*/"\n"           { // end of section title
  					  addSection(yyextra);
                                          addOutput(yytext,yyscanner);
					  BEGIN( Comment );
  					}
<SectionTitle>[^\n@\\]*/"\\_linebr"     { // end of section title
  					  addSection(yyextra);
                                          addOutput(yytext,yyscanner);
					  BEGIN( Comment );
  					}
<SectionTitle>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<SectionTitle>[^\n@\\]*			{ // any character without special meaning
  					  yyextra->sectionTitle+=yytext;
					  addOutput(yytext,yyscanner);
  					}
<SectionTitle>("\\\\"|"@@"){ID}		{ // unescape escaped command
  					  yyextra->sectionTitle+=&yytext[1];
					  addOutput(yytext,yyscanner);
  					}
<SectionTitle>{CMD}[$@\\&~<>#%]		{ // unescape escaped character
  					  yyextra->sectionTitle+=yytext[1];
  					  addOutput(yytext,yyscanner);
  					}
<SectionTitle>.				{ // anything else
  					  yyextra->sectionTitle+=yytext;
					  addOutput(*yytext,yyscanner);
  					}

  /* ----- handle arguments of the subpage command ------- */

<SubpageLabel>{LABELID}			{ // first argument
                                          addOutput(yytext,yyscanner);
					  // we add subpage labels as a kind of "inheritance" relation to prevent
					  // needing to add another list to the Entry class.
					  yyextra->current->extends->append(new BaseInfo(yytext,Public,Normal));
					  BEGIN(SubpageTitle);
  					}
<SubpageLabel>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\subpage command has no label"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<SubpageTitle>{DOCNL}			{ // no title, end command
  					  addOutput(yytext,yyscanner);
					  BEGIN( Comment );
  					}
<SubpageTitle>[ \t]*"\""[^\"\n]*"\""	{ // add title, end of command
  					  addOutput(yytext,yyscanner);
					  BEGIN( Comment );
  					}
<SubpageTitle>.				{ // no title, end of command
  					  unput(*yytext);
					  BEGIN( Comment );
  					}

  /* ----- handle arguments of the anchor command ------- */

<AnchorLabel>{LABELID}			{ // found argument
                                          addAnchor(yytext,yyscanner);
					  addOutput(yytext,yyscanner);
					  BEGIN( Comment );
  					}
<AnchorLabel>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\anchor command has no label"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<AnchorLabel>.				{ // invalid character for anchor label
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Invalid or missing anchor label"
					      );
					  BEGIN(Comment);
  					}


  /* ----- handle arguments of the preformatted block commands ------- */

<FormatBlock>{CMD}("endverbatim"|"endlatexonly"|"endhtmlonly"|"endxmlonly"|"enddocbookonly"|"endrtfonly"|"endmanonly"|"enddot"|"endcode"|"endmsc"|"endvhdlflow")/{NW} { // possible ends
  					  addOutput(yytext,yyscanner);
					  if (&yytext[4]==yyextra->blockName) // found end of the block
					  {
  					    BEGIN(Comment);
					  }
  					}
<FormatBlock>{CMD}"enduml"              {
  					  addOutput(yytext,yyscanner);
					  if (yyextra->blockName=="startuml") // found end of the block
					  {
  					    BEGIN(Comment);
					  }
                                        }
<FormatBlock>[^ \@\*\/\\\n]*		{ // some word
  					  addOutput(yytext,yyscanner);
  					}
<FormatBlock>{DOCNL}			{ // new line
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
  					}
<FormatBlock>"/*"			{ // start of a C-comment
  					  yyextra->commentCount++;
  					  addOutput(yytext,yyscanner);
  					}
<FormatBlock>"*/"			{ // end of a C-comment
  					  addOutput(yytext,yyscanner);
  					  yyextra->commentCount--;
					  if (yyextra->commentCount<0 && yyextra->blockName!="verbatim")
					  {
					    warn(yyextra->yyFileName,yyextra->yyLineNr,
					         "found */ without matching /* while inside a \\%s block! Perhaps a missing \\end%s?\n",yyextra->blockName.data(),yyextra->blockName.data());
					  }
  					}
<FormatBlock>.				{
  					  addOutput(*yytext,yyscanner);
  					}
<FormatBlock><<EOF>>			{
                                          QCString endTag = "@end"+yyextra->blockName;
                                          if (yyextra->blockName=="startuml") endTag="enduml";
                                          warn(yyextra->yyFileName,yyextra->yyLineNr,
	                                    "reached end of comment while inside a @%s block; check for missing @%s tag!",
	                                    yyextra->blockName.data(),endTag.data()
	                                  );				
					  yyterminate();
    					}

  /* ----- handle arguments of if/ifnot commands ------- */

<GuardParam>{B}*"("                         {
                                          yyextra->guardExpr=yytext;
                                          yyextra->roundCount=1;
                                          BEGIN(GuardExpr);
                                        }
<GuardExpr>[^()]*                       {
                                          yyextra->guardExpr+=yytext;
                                        }
<GuardExpr>"("                          {
                                          yyextra->guardExpr+=yytext;
                                          yyextra->roundCount++;
                                        }
<GuardExpr>")"                          {
                                          yyextra->guardExpr+=yytext;
                                          yyextra->roundCount--;
                                          if (yyextra->roundCount==0)
                                          {
                                            handleGuard(yyextra->guardExpr,yyscanner);
                                          }
                                        }
<GuardExpr>\n                           {
					  warn(yyextra->yyFileName,yyextra->yyLineNr,
						"invalid expression '%s' for guard",yyextra->guardExpr.data());
                                          unput(*yytext);
                                          BEGIN(GuardParam);
                                        }
<GuardParam>{B}*[a-z_A-Z0-9.\-]+            { // parameter of if/ifnot guard
                                          handleGuard(yytext,yyscanner);
  					}
<GuardParam>{DOCNL}			{ // end of argument
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  //next line is commented out due to bug620924
					  //addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<GuardParam>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<GuardParam>.				{ // ignore other stuff
  					  addOutput(*yytext,yyscanner);
  					}
<GuardParamEnd>{B}*{DOCNL}		{
  					  yyextra->spaceBeforeIf.resize(0);
  					  BEGIN(Comment);
  					}
<GuardParamEnd>{B}*			{
  					  if (!yyextra->spaceBeforeIf.isEmpty()) // needed for 665313 in combation with bug620924
					  {
					    addOutput(yyextra->spaceBeforeIf,yyscanner);
					  }
  					  yyextra->spaceBeforeIf.resize(0);
  					  BEGIN(Comment);
  					}
<GuardParamEnd>.			{
  					  unput(*yytext);
  					  BEGIN(Comment);
  					}

  /* ----- handle skipping of conditional sections ------- */

<SkipGuardedSection>{CMD}"ifnot"/{NW}	{
                                          yyextra->guardType = Guard_IfNot;
  					  BEGIN( GuardParam );
  					}
<SkipGuardedSection>{CMD}"if"/{NW}	{
                                          yyextra->guardType = Guard_If;
  					  BEGIN( GuardParam );
  					}
<SkipGuardedSection>{CMD}"endif"/{NW}	{
  					  if (yyextra->guards.isEmpty())
					  {
					    warn(yyextra->yyFileName,yyextra->yyLineNr,
						"found @endif without matching start command");
					  }
					  else
					  {
					    GuardedSection *s = yyextra->guards.pop();
                                            bool parentVisible = s->parentVisible();
                                            delete s;
                                            if (parentVisible)
                                            {
					      yyextra->enabledSectionFound=TRUE;
					      BEGIN( GuardParamEnd );
                                            }
					  }
  					}
<SkipGuardedSection>{CMD}"else"/{NW}	{
  					  if (yyextra->guards.isEmpty())
					  {
					    warn(yyextra->yyFileName,yyextra->yyLineNr,
						"found @else without matching start command");
					  }
					  else
					  {
					    if (!yyextra->enabledSectionFound && yyextra->guards.top()->parentVisible())
					    {
					      delete yyextra->guards.pop();
					      yyextra->guards.push(new GuardedSection(TRUE,TRUE));
					      yyextra->enabledSectionFound=TRUE;
					      BEGIN( GuardParamEnd );
					    }
					  }
  					}
<SkipGuardedSection>{CMD}"elseif"/{NW}  {
  					  if (yyextra->guards.isEmpty())
					  {
					    warn(yyextra->yyFileName,yyextra->yyLineNr,
						"found @elseif without matching start command");
					  }
					  else
					  {
					    if (!yyextra->enabledSectionFound && yyextra->guards.top()->parentVisible())
					    {
                                              yyextra->guardType=Guard_If;
					      delete yyextra->guards.pop();
					      BEGIN( GuardParam );
					    }
					  }
  					}
<SkipGuardedSection>{DOCNL}		{ // skip line
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  //addOutput('\n',yyscanner);
  					}
<SkipGuardedSection>[^ \\@\n]+		{ // skip non-special characters
  					}
<SkipGuardedSection>.			{ // any other character
  					}


  /* ----- handle skipping of internal section ------- */

<SkipInternal>{DOCNL}			{ // skip line
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
  					}
<SkipInternal>[@\\]"if"/[ \t]		{
                                          yyextra->condCount++;
  					}
<SkipInternal>[@\\]"ifnot"/[ \t]	{
                                          yyextra->condCount++;
  					}
<SkipInternal>[@\\]/"endif"		{
                                          yyextra->condCount--;
					  if (yyextra->condCount<0) // handle conditional section around of \internal, see bug607743  
					  {
					    unput('\\');
					    BEGIN(Comment);
					  }
  					}
<SkipInternal>[@\\]/"section"[ \t]	{
  					  if (yyextra->sectionLevel>0)
					  {
					    unput('\\');
					    BEGIN(Comment);
					  }
  					}
<SkipInternal>[@\\]/"subsection"[ \t]	{
  					  if (yyextra->sectionLevel>1)
					  {
					    unput('\\');
					    BEGIN(Comment);
					  }
  					}
<SkipInternal>[@\\]/"subsubsection"[ \t]	{
  					  if (yyextra->sectionLevel>2)
					  {
					    unput('\\');
					    BEGIN(Comment);
					  }
  					}
<SkipInternal>[@\\]/"paragraph"[ \t]	{
  					  if (yyextra->sectionLevel>3)
					  {
					    unput('\\');
					    BEGIN(Comment);
					  }
  					}
<SkipInternal>[@\\]"endinternal"[ \t]*  {
                                          addOutput("\\endinternal ",yyscanner); 
					  BEGIN(Comment);
					}
<SkipInternal>[^ \\@\n]+		{ // skip non-special characters
  					}
<SkipInternal>.				{ // any other character
  					}


  /* ----- handle argument of name command ------- */

<NameParam>{DOCNL}			{ // end of argument
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<NameParam>{LC}				{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
					  yyextra->memberGroupHeader+=' ';
  					}
<NameParam>.				{ // ignore other stuff
					  yyextra->memberGroupHeader+=*yytext;
					  yyextra->current->name+=*yytext;
  					}

  /* ----- handle argument of ingroup command ------- */

<InGroupParam>{LABELID}			{ // group id
  					  yyextra->current->groups->append(
					    new Grouping(yytext, Grouping::GROUPING_INGROUP)
					  );
					  yyextra->inGroupParamFound=TRUE;
  					}
<InGroupParam>{DOCNL}			{ // missing argument
  					  if (!yyextra->inGroupParamFound)
					  {
  					    warn(yyextra->yyFileName,yyextra->yyLineNr,
					        "Missing group name for \\ingroup command"
					        );
					  }
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<InGroupParam>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  addOutput('\n',yyscanner);
  					}
<InGroupParam>.				{ // ignore other stuff
  					  addOutput(*yytext,yyscanner);
  					}

  /* ----- handle argument of fn command ------- */

<FnParam>{DOCNL}			{ // end of argument
  					  if (yyextra->braceCount==0)
					  {
					    if (*yytext=='\n') yyextra->yyLineNr++;
					    addOutput('\n',yyscanner);
					    yyextra->langParser->parsePrototype(yyextra->functionProto);
					    BEGIN( Comment );
					  }
  					}
<FnParam>{LC}				{ // line continuation
                                          yyextra->yyLineNr++; 
					  yyextra->functionProto+=' ';
  					}
<FnParam>[^@\\\n()]+			{ // non-special characters
                                          yyextra->functionProto+=yytext;
  					}
<FnParam>"("				{
                                          yyextra->functionProto+=yytext;
					  yyextra->braceCount++;
					}
<FnParam>")"				{
                                          yyextra->functionProto+=yytext;
					  yyextra->braceCount--;
					}
<FnParam>.				{ // add other stuff
                                          yyextra->functionProto+=*yytext;
  					}


  /* ----- handle argument of overload command ------- */


<OverloadParam>{DOCNL}			{ // end of argument
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  if (yyextra->functionProto.stripWhiteSpace().isEmpty())
					  { // plain overload command
					    addOutput(getOverloadDocs(),yyscanner);
					    addOutput('\n',yyscanner);
					  }
					  else // overload declaration
					  {
                                            makeStructuralIndicator(Entry::OVERLOADDOC_SEC,yyscanner);
					    yyextra->langParser->parsePrototype(yyextra->functionProto);
					  }
					  BEGIN( Comment );
  					}
<OverloadParam>{LC}			{ // line continuation
                                          yyextra->yyLineNr++; 
					  yyextra->functionProto+=' ';
  					}
<OverloadParam>.			{ // add other stuff
                                          yyextra->functionProto+=*yytext;
  					}

  /* ----- handle argument of inherit command ------- */

<InheritParam>({ID}("::"|"."))*{ID}	{ // found argument
					  yyextra->current->extends->append(
					    new BaseInfo(removeRedundantWhiteSpace(yytext),Public,Normal)
					  );
					  BEGIN( Comment );
  					}
<InheritParam>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\inherit command has no argument"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<InheritParam>.				{ // invalid character for anchor label
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Invalid or missing name for \\inherit command"
					      );
					  BEGIN(Comment);
  					}

  /* ----- handle argument of extends and implements commands ------- */

<ExtendsParam>({ID}("::"|"."))*{ID}	{ // found argument
					  yyextra->current->extends->append(
					    new BaseInfo(removeRedundantWhiteSpace(yytext),Public,Normal)
					  );
					  BEGIN( Comment );
  					}
<ExtendsParam>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\extends or \\implements command has no argument"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<ExtendsParam>.				{ // ignore other stuff
  					}

  /* ----- handle language specific sections ------- */

<SkipLang>[\\@]"~"[a-zA-Z-]*        { /* language switch */
                                     QCString langId = &yytext[2];
				     if (langId.isEmpty() ||
					 qstricmp(Config_getEnum(OUTPUT_LANGUAGE),langId)==0)
				     { // enable language specific section
				       BEGIN(Comment);
				     }
                                   }
<SkipLang>[^*@\\\n]*		   { /* any character not a *, @, backslash or new line */
                                   }
<SkipLang>{DOCNL}		   { /* new line in verbatim block */
  		                     if (*yytext=='\n') yyextra->yyLineNr++;
                                   }
<SkipLang>.			   { /* any other character */
                                   }

  /* ----- handle arguments of the cite command ------- */

<CiteLabel>{CITEID}			{ // found argyment
  					  addCite(yyextra);
                                          addOutput(yytext,yyscanner);
					  BEGIN(Comment);
  					}
<CiteLabel>{DOCNL}			{ // missing argument
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "\\cite command has no label"
					      );
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  BEGIN( Comment );
  					}
<CiteLabel>.				{ // invalid character for cite label
  					  warn(yyextra->yyFileName,yyextra->yyLineNr,
					      "Invalid or missing cite label"
					      );
					  BEGIN(Comment);
  					}

  /* ----- handle argument of the copydoc command ------- */

<CopyDoc><<EOF>>			|
<CopyDoc>{DOCNL}			{
  					  if (*yytext=='\n') yyextra->yyLineNr++;
					  addOutput('\n',yyscanner);
					  setOutput(OutputDoc,yyscanner);
                                          addOutput("\\copydetails ",yyscanner);
					  addOutput(yyextra->copyDocArg,yyscanner);
					  addOutput("\n",yyscanner);
					  BEGIN(Comment);
  					}
<CopyDoc>[^\n\\]+			{
  					  yyextra->copyDocArg+=yytext;
					  addOutput(yytext,yyscanner);
  					}
<CopyDoc>.				{
  					  yyextra->copyDocArg+=yytext;
					  addOutput(yytext,yyscanner);
  					}


%%


//-----------------------------------------------------------------------------
static void initParser(yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;

  yyextra->sectionLabel.resize(0);
  yyextra->sectionTitle.resize(0);
  yyextra->memberGroupHeader.resize(0);
  yyextra->insideParBlock = FALSE;
}


static bool getDocSectionName(int s)
{
  switch(s)
  {
    case Entry::CLASSDOC_SEC:
    case Entry::STRUCTDOC_SEC:
    case Entry::UNIONDOC_SEC:
    case Entry::EXCEPTIONDOC_SEC:
    case Entry::NAMESPACEDOC_SEC:
    case Entry::PROTOCOLDOC_SEC:
    case Entry::CATEGORYDOC_SEC:
    case Entry::ENUMDOC_SEC:
    case Entry::PAGEDOC_SEC:
    case Entry::VARIABLEDOC_SEC:
    case Entry::MEMBERDOC_SEC:
    case Entry::OVERLOADDOC_SEC:
    case Entry::FILEDOC_SEC:
    case Entry::DEFINEDOC_SEC:
    case Entry::GROUPDOC_SEC:
    case Entry::MAINPAGEDOC_SEC:
    case Entry::PACKAGEDOC_SEC:
    case Entry::DIRDOC_SEC:
    case Entry::EXAMPLE_SEC:
    case Entry::MEMBERGRP_SEC:
      return TRUE;
    default: 
      return FALSE;
  }
}

//-----------------------------------------------------------------------------

static bool makeStructuralIndicator(Entry::Sections s,yyscan_t yyscanner)
{
  struct yyguts_t *yyg = (struct yyguts_t*)yyscanner;

  //printf("yyextra->current->section=%x\n",yyextra->current->section);
  if (getDocSectionName(yyextra->current->section))
  {
    return TRUE;
  }
  else
  {
    yyextra->needNewEntry = TRUE;
    yyextra->current->section = s;
    yyextra->current->fileName = yyextra->yyFileName;
    yyextra->current->startLine = yyextra->yyLineNr;
    return FALSE;
  }
}

static void lineCount(yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  for( const char* c = yytext ; *c ; ++c )
    yyextra->yyLineNr += (*c == '\n') ;
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

//-----------------------------------------------------------------

static void addXRefItem(const char *listName,const char *itemTitle,
                        const char *listTitle,bool append,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  Entry *docEntry = yyextra->current; // yyextra->inBody && previous ? previous : current;
  if (listName==0) return;
  //printf("addXRefItem(%s,%s,%s,%d)\n",listName,itemTitle,listTitle,append);

  ListItemInfo *lii=0;
  RefList *refList = Doxygen::xrefLists->find(listName);
  if (refList==0) // new list
  {
    refList = new RefList(listName,listTitle,itemTitle);
    Doxygen::xrefLists->insert(listName,refList);
    //printf("new list!\n");
  }
  if (docEntry->sli)
  {
    QListIterator<ListItemInfo> slii(*docEntry->sli);
    for (slii.toFirst();(lii=slii.current());++slii)
    {
      if (qstrcmp(lii->type,listName)==0) 
      {
        //printf("found %s lii->type=%s\n",listName,lii->type);
        break;
      }
    }
  }
  if (lii && append) // already found item of same type just before this one
  {
    //printf("listName=%s item id = %d existing\n",listName,lii->itemId);
    RefItem *item = refList->getRefItem(lii->itemId);
    ASSERT(item!=0);
    item->text += " <p>";
    if (Doxygen::markdownSupport)
    {
      item->text += processMarkdown(yyextra->yyFileName,yyextra->yyLineNr,yyextra->current,yyextra->outputXRef);
    }
    else
    {
      item->text += yyextra->outputXRef;
    }
    //printf("%s: text +=%s\n",listName,item->text.data());
  }
  else // new item
  {
    int itemId  = refList->addRefItem();
    //printf("listName=%s item id = %d new current=%p\n",listName,itemId,current);

    // if we have already an item from the same list type (e.g. a second @todo)
    // in the same Entry (i.e. lii!=0) then we reuse its link anchor.
    char anchorLabel[1024];
    //sprintf(anchorLabel,"_%s%06d",listName,lii ? lii->itemId : itemId);
    sprintf(anchorLabel,"_%s%06d",listName,itemId);
    RefItem *item = refList->getRefItem(itemId);
    ASSERT(item!=0);
    if (Doxygen::markdownSupport)
    {
      item->text = processMarkdown(yyextra->yyFileName,yyextra->yyLineNr,yyextra->current,yyextra->outputXRef);
    }
    else
    {
      item->text = yyextra->outputXRef;
    }
    item->listAnchor = anchorLabel;
    docEntry->addSpecialListItem(listName,itemId);
    QCString cmdString;
    cmdString.sprintf("\\xrefitem %s %d.",listName,itemId);
    if (yyextra->inBody)
    {
      docEntry->inbodyDocs += cmdString;
    }
    else
    {
      docEntry->doc += cmdString;
    }
    SectionInfo *si = Doxygen::sectionDict->find(anchorLabel);
    if (si)
    {
      if (si->lineNr != -1)
      {
        warn(listName,yyextra->yyLineNr,"multiple use of section label '%s', (first occurrence: %s, line %d)",anchorLabel,si->fileName.data(),si->lineNr);
      }
      else
      {
        warn(listName,yyextra->yyLineNr,"multiple use of section label '%s', (first occurrence: %s)",anchorLabel,si->fileName.data());
      }
    }
    else
    {
      si=new SectionInfo(listName,yyextra->yyLineNr,anchorLabel,
                         yyextra->sectionTitle,SectionInfo::Anchor,
                         yyextra->sectionLevel);
      Doxygen::sectionDict->append(anchorLabel,si);
      docEntry->anchors->append(si);
    }
  }
  yyextra->outputXRef.resize(0);
}

//-----------------------------------------------------------------------------

// Adds a formula text to the list/dictionary of formulas if it was
// not already added. Returns the label of the formula.
static QCString addFormula(yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  QCString formLabel;
  QCString fText=yyextra->formulaText.simplifyWhiteSpace();
  Formula *f=0;
  if ((f=Doxygen::formulaDict->find(fText))==0)
  {
    f = new Formula(fText);
    Doxygen::formulaList->append(f);
    Doxygen::formulaDict->insert(fText,f);
    formLabel.sprintf("\\form#%d",f->getId());
    Doxygen::formulaNameDict->insert(formLabel,f);
  }
  else
  {
    formLabel.sprintf("\\form#%d",f->getId());
  }
  int i;
  for (i=0;i<yyextra->formulaNewLines;i++) formLabel+="@_fakenl"; // add fake newlines to
                                                         // keep the warnings 
                                                         // correctly aligned.
  return formLabel;
}



static SectionInfo::SectionType sectionLevelToType(int level)
{
  if (level>=0 && level<5) return (SectionInfo::SectionType)level;
  return SectionInfo::Anchor;
}

static void addSection(yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  SectionInfo *si = Doxygen::sectionDict->find(yyextra->sectionLabel);
  if (si)
  {
    if (si->lineNr != -1)
    {
      warn(yyextra->yyFileName,yyextra->yyLineNr,"multiple use of section label '%s' while adding section, (first occurrence: %s, line %d)",yyextra->sectionLabel.data(),si->fileName.data(),si->lineNr);
    }
    else
    {
      warn(yyextra->yyFileName,yyextra->yyLineNr,"multiple use of section label '%s' while adding section, (first occurrence: %s)",yyextra->sectionLabel.data(),si->fileName.data());
    }
  }
  else
  {
    // create a new section element
    yyextra->sectionTitle+=yytext;
    yyextra->sectionTitle=yyextra->sectionTitle.stripWhiteSpace();
    si = new SectionInfo(yyextra->yyFileName,yyextra->yyLineNr,yyextra->sectionLabel,
                          yyextra->sectionTitle,sectionLevelToType(yyextra->sectionLevel),yyextra->sectionLevel);

    // add section to this entry
    yyextra->current->anchors->append(si);

    // add section to the global dictionary
    Doxygen::sectionDict->append(yyextra->sectionLabel,si);
  }
}

//-----------------------------------------------------------------------------

static void addCite(yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  Doxygen::citeDict->insert(yytext);
}

//-----------------------------------------------------------------------------

// strip trailing whitespace (excluding newlines) from string s
static void stripTrailingWhiteSpace(QCString &s)
{
  uint len = s.length();
  int i = (int)len-1;
  char c;
  while (i>=0 && ((c = s.at(i))==' ' || c=='\t' || c=='\r')) i--;
  if (i!=(int)len-1) 
  {
    s.resize(i+2); // string up to and including char at pos i and \0 terminator
  }
}

// selects the output to write to
static inline void setOutput(OutputContext ctx,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool xrefAppendToPrev = yyextra->xrefAppendFlag;
  // determine append flag for the next item (i.e. the end of this item)
  yyextra->xrefAppendFlag = !yyextra->inBody &&
                   yyextra->inContext==OutputXRef && ctx==OutputXRef && // two consecutive xref items
                   yyextra->newXRefKind==yyextra->xrefKind &&                    // of the same kind
                   (yyextra->xrefKind!=XRef_Item || 
		    yyextra->newXRefItemKey==yyextra->xrefItemKey);              // with the same key if \xrefitem
  //printf("%d && %d && %d && (%d || %d)\n",
  //                 yyextra->inContext==OutputXRef,
  //                 ctx==OutputXRef,
  //                 yyextra->newXRefKind==yyextra->xrefKind,
  //                 yyextra->xrefKind!=XRef_Item,
  //	  	     yyextra->newXRefItemKey==yyextra->xrefItemKey);
      
  //printf("refKind=%d yyextra->newXRefKind=%d xrefAppendToPrev=%d yyextra->xrefAppendFlag=%d\n",
  //   	  yyextra->xrefKind,yyextra->newXRefKind,xrefAppendToPrev,yyextra->xrefAppendFlag);

  //printf("setOutput(yyextra->inContext=%d ctx=%d)\n",yyextra->inContext,ctx);
  if (yyextra->inContext==OutputXRef) // end of XRef section => add the item 
  {
    // See if we can append this new xref item to the previous one.
    // We know this at the start of the next item of the same
    // type and need to remember this until the end of that item.
    switch(yyextra->xrefKind)
    {
      case XRef_Todo:
	addXRefItem("todo",
	            theTranslator->trTodo(),
	            theTranslator->trTodoList(),
		    xrefAppendToPrev,
		    yyscanner
		   );
	break;
      case XRef_Test:
	addXRefItem("test",
	            theTranslator->trTest(),
		    theTranslator->trTestList(),
		    xrefAppendToPrev,
		    yyscanner
		   );
	break;
      case XRef_Bug:
	addXRefItem("bug",
	            theTranslator->trBug(),
		    theTranslator->trBugList(),
		    xrefAppendToPrev,
		    yyscanner
		   );
	break;
      case XRef_Deprecated:
	addXRefItem("deprecated",
	            theTranslator->trDeprecated(),
		    theTranslator->trDeprecatedList(),
		    xrefAppendToPrev,
		    yyscanner
		   );
	break;
      case XRef_Item:  // user defined list
	addXRefItem(yyextra->xrefItemKey,
	            yyextra->xrefItemTitle,
		    yyextra->xrefListTitle,
		    xrefAppendToPrev,
		    yyscanner
		   );
	break;
      case XRef_None:
	ASSERT(0);
	break;
    }
  }
  yyextra->xrefItemKey = yyextra->newXRefItemKey;

  int oldContext = yyextra->inContext;
  yyextra->inContext = ctx;
  if (yyextra->inContext!=OutputXRef && yyextra->inBody) yyextra->inContext=OutputInbody;
  switch(yyextra->inContext)
  {
    case OutputDoc:
      if (oldContext!=yyextra->inContext)
      {
        stripTrailingWhiteSpace(yyextra->current->doc);
        if (yyextra->current->docFile.isEmpty())
        {
          yyextra->current->docFile = yyextra->yyFileName;
          yyextra->current->docLine = yyextra->yyLineNr;
        }
      }
      yyextra->pOutputString = &yyextra->current->doc;
      break;
    case OutputBrief:
      if (oldContext!=yyextra->inContext)
      {
	if (yyextra->current->briefFile.isEmpty())
	{
	  yyextra->current->briefFile = yyextra->yyFileName;
	  yyextra->current->briefLine = yyextra->yyLineNr;
	}
      }
      if (yyextra->current->brief.stripWhiteSpace().isEmpty()) // we only want one brief
	                                              // description even if multiple
	                                              // are given...
      {
        yyextra->pOutputString = &yyextra->current->brief;
      }
      else
      {
        yyextra->pOutputString = &yyextra->current->doc;
	yyextra->inContext = OutputDoc; // need to switch to detailed docs, see bug 631380
      }
      break;
    case OutputXRef:
      yyextra->pOutputString = &yyextra->outputXRef;
      // first item found, so can't append to previous
      //yyextra->xrefAppendFlag = FALSE;
      break;
    case OutputInbody:
      yyextra->pOutputString = &yyextra->current->inbodyDocs;
      break;
  }
}


static void addAnchor(const char *anchor,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  SectionInfo *si = Doxygen::sectionDict->find(anchor);
  if (si)
  {
    if (si->lineNr != -1)
    {
      warn(yyextra->yyFileName,yyextra->yyLineNr,"multiple use of section label '%s' while adding anchor, (first occurrence: %s, line %d)",anchor,si->fileName.data(),si->lineNr);
    }
    else
    {
      warn(yyextra->yyFileName,yyextra->yyLineNr,"multiple use of section label '%s' while adding anchor, (first occurrence: %s)",anchor,si->fileName.data());
    }
  }
  else
  {
    si = new SectionInfo(yyextra->yyFileName,yyextra->yyLineNr,anchor,0,SectionInfo::Anchor,0);
    Doxygen::sectionDict->append(anchor,si);
    yyextra->current->anchors->append(si);
  }
}

// add a string to the output
static inline void addOutput(const char *s,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  //printf("addOutput(%s)\n",s);
  *yyextra->pOutputString+=s;
}

// add a character to the output
static inline void addOutput(char c,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  *yyextra->pOutputString+=c;
}

static void endBrief(bool addToOutput,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (!yyextra->current->brief.stripWhiteSpace().isEmpty())
  { // only go to the detailed description if we have
    // found some brief description and not just whitespace
    yyextra->briefEndsAtDot=FALSE;
    setOutput(OutputDoc,yyscanner);
    if (addToOutput) addOutput(yytext,yyscanner);
  }
}

static int yyread(char *buf,int max_size,yyscan_t yyscanner)
{
    struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

    yyextra->prevPosition=yyextra->inputPosition;
    int c=0;
    while( c < max_size && yyextra->inputString[yyextra->inputPosition] )
    {
	*buf = yyextra->inputString[yyextra->inputPosition++] ;
	//printf("%d (%c)\n",*buf,*buf);
	c++; buf++;
    }
    return c;
}

//----------------------------------------------------------------------------

static bool handleBrief(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  //printf("handleBrief\n");
  setOutput(OutputBrief,yyscanner);
  return FALSE;
}

static bool handleFn(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::MEMBERDOC_SEC,yyscanner);
  yyextra->functionProto.resize(0);
  yyextra->braceCount=0;
  BEGIN(FnParam);
  return stop;
}

static bool handleDef(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::DEFINEDOC_SEC,yyscanner);
  yyextra->functionProto.resize(0);
  BEGIN(FnParam);
  return stop;
}

static bool handleOverload(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->functionProto.resize(0);
  BEGIN(OverloadParam);
  return FALSE;
}

static bool handleEnum(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::ENUMDOC_SEC,yyscanner);
  BEGIN(EnumDocArg1);
  return stop;
}

static bool handleDefGroup(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::GROUPDOC_SEC,yyscanner);
  yyextra->current->groupDocType = Entry::GROUPDOC_NORMAL;
  BEGIN( GroupDocArg1 );
  return stop;
}

static bool handleAddToGroup(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::GROUPDOC_SEC,yyscanner);
  yyextra->current->groupDocType = Entry::GROUPDOC_ADD;
  BEGIN( GroupDocArg1 );
  return stop;
}

static bool handleWeakGroup(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::GROUPDOC_SEC,yyscanner);
  yyextra->current->groupDocType = Entry::GROUPDOC_WEAK;
  BEGIN( GroupDocArg1 );
  return stop;
}

static bool handleNamespace(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::NAMESPACEDOC_SEC,yyscanner);
  BEGIN( NameSpaceDocArg1 );
  return stop;
}

static bool handlePackage(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::PACKAGEDOC_SEC,yyscanner);
  BEGIN( PackageDocArg1 );
  return stop;
}

static bool handleClass(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::CLASSDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handleHeaderFile(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  BEGIN( ClassDocArg2 );
  return FALSE;
}

static bool handleProtocol(const QCString &,yyscan_t yyscanner)
{ // Obj-C protocol
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::PROTOCOLDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handleCategory(const QCString &,yyscan_t yyscanner)
{ // Obj-C category
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::CATEGORYDOC_SEC,yyscanner);
  BEGIN( CategoryDocArg1 ); 
  return stop;
}

static bool handleUnion(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::UNIONDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handleStruct(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::STRUCTDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handleInterface(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::INTERFACEDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handleIdlException(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::EXCEPTIONDOC_SEC,yyscanner);
  BEGIN( ClassDocArg1 ); 
  return stop;
}

static bool handlePage(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::PAGEDOC_SEC,yyscanner);
  BEGIN( PageDocArg1 );
  return stop;
}

static bool handleMainpage(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::MAINPAGEDOC_SEC,yyscanner);
  if (!stop) 
  {
    yyextra->current->name = "mainpage";
  }
  BEGIN( PageDocArg2 );
  return stop;
}

static bool handleFile(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::FILEDOC_SEC,yyscanner);
  if (!stop) 
  {
    yyextra->current->name = yyextra->yyFileName;
  }
  BEGIN( FileDocArg1 );
  return stop;
}

static bool handleParam(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  // we need process param and retval arguments to escape leading underscores in case of
  // markdown processing, see bug775493
  addOutput("@param ",yyscanner);
  BEGIN( ParamArg1 );
  return FALSE;
}

static bool handleRetval(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput("@retval ",yyscanner);
  BEGIN( ParamArg1 );
  return FALSE;
}

static bool handleDir(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::DIRDOC_SEC,yyscanner);
  if (!stop) yyextra->current->name = yyextra->yyFileName;
  BEGIN( FileDocArg1 );
  return stop;
}

static bool handleExample(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::EXAMPLE_SEC,yyscanner);
  if (!stop) yyextra->current->name = yyextra->yyFileName;
  BEGIN( FileDocArg1 );
  return stop;
}

static bool handleDetails(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->inContext!=OutputBrief)
  {
    addOutput("\n\n",yyscanner); // treat @details outside brief description
                       // as a new paragraph
  }
  setOutput(OutputDoc,yyscanner);
  return FALSE;
}

static bool handleName(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  bool stop=makeStructuralIndicator(Entry::MEMBERGRP_SEC,yyscanner);
  if (!stop)
  {
    yyextra->memberGroupHeader.resize(0);
    BEGIN( NameParam );
    if (yyextra->memberGroupId!=DOX_NOGROUP) // end of previous member group
    {
      closeGroup(yyextra->current,yyextra->yyFileName,yyextra->yyLineNr,TRUE);
    }
  }
  return stop;
}

static bool handleTodo(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->newXRefKind = XRef_Todo;
  setOutput(OutputXRef,yyscanner);
  yyextra->xrefKind = XRef_Todo;
  return FALSE;
}

static bool handleTest(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->newXRefKind = XRef_Test;
  setOutput(OutputXRef,yyscanner);
  yyextra->xrefKind = XRef_Test;
  return FALSE;
}

static bool handleBug(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->newXRefKind = XRef_Bug;
  setOutput(OutputXRef,yyscanner);
  yyextra->xrefKind = XRef_Bug;
  return FALSE;
}

static bool handleDeprecated(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->newXRefKind = XRef_Deprecated;
  setOutput(OutputXRef,yyscanner);
  yyextra->xrefKind = XRef_Deprecated;
  return FALSE;
}

static bool handleXRefItem(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->newXRefKind = XRef_Item;
  BEGIN(XRefItemParam1);
  return FALSE;
}

static bool handleParBlock(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->insideParBlock)
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\parblock command while already in a parblock!");
  }
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("@parblock ",yyscanner);
  yyextra->insideParBlock = TRUE;
  return FALSE;
}

static bool handleEndParBlock(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (!yyextra->insideParBlock)
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\endparblock command without matching \\parblock!");
  }
  addOutput("@endparblock",yyscanner);
  setOutput(OutputDoc,yyscanner); // to end a parblock inside a xrefitem like context
  yyextra->insideParBlock = FALSE;
  return FALSE;
}

static bool handleRelated(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  BEGIN(RelatesParam1);
  return FALSE;
}

static bool handleRelatedAlso(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->relatesType = Duplicate;
  BEGIN(RelatesParam1);
  return FALSE;
}

static bool handleMemberOf(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->relatesType = MemberOf;
  BEGIN(RelatesParam1);
  return FALSE;
}

static bool handleRefItem(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput("@refitem ",yyscanner);
  BEGIN(LineParam);
  return FALSE;
}

static bool handleSection(const QCString &s,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  setOutput(OutputDoc,yyscanner);
  addOutput("@"+s+" ",yyscanner);
  BEGIN(SectionLabel);
  if      (s=="section")       yyextra->sectionLevel=1;
  else if (s=="subsection")    yyextra->sectionLevel=2;
  else if (s=="subsubsection") yyextra->sectionLevel=3;
  else if (s=="paragraph")     yyextra->sectionLevel=4;
  return FALSE;
}

static bool handleSubpage(const QCString &s,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->current->section!=Entry::EMPTY_SEC && 
      yyextra->current->section!=Entry::PAGEDOC_SEC &&
      yyextra->current->section!=Entry::MAINPAGEDOC_SEC
     )
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\subpage command in a comment block that is not marked as a page!");
  }
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("@"+s+" ",yyscanner);
  BEGIN(SubpageLabel);
  return FALSE;
}

static bool handleAnchor(const QCString &s, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput("@"+s+" ",yyscanner);
  BEGIN(AnchorLabel);
  return FALSE;
}

static bool handleCite(const QCString &s, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("@"+s+" ",yyscanner);
  BEGIN(CiteLabel);
  return FALSE;
}

static bool handleFormatBlock(const QCString &s, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput("@"+s+" ",yyscanner);
  //printf("handleFormatBlock(%s)\n",s.data());
  yyextra->blockName=s;
  yyextra->commentCount=0;
  BEGIN(FormatBlock);
  return FALSE;
}

static bool handleAddIndex(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput("@addindex ",yyscanner);
  BEGIN(LineParam);
  return FALSE;
}

static bool handleIf(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->enabledSectionFound=FALSE;
  yyextra->guardType = Guard_If;
  yyextra->spaceBeforeIf = yyextra->spaceBeforeCmd;
  BEGIN(GuardParam);
  return FALSE;
}

static bool handleIfNot(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->enabledSectionFound=FALSE;
  yyextra->guardType = Guard_IfNot;
  yyextra->spaceBeforeIf = yyextra->spaceBeforeCmd;
  BEGIN(GuardParam);
  return FALSE;
}

static bool handleElseIf(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->guards.isEmpty())
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\else without matching start command");
  }
  else
  {
    yyextra->guardType = yyextra->enabledSectionFound ? Guard_Skip : Guard_If;
    BEGIN(GuardParam);
  }
  return FALSE;
}

static bool handleElse(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->guards.isEmpty())
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\else without matching start command");
  }
  else
  {
    BEGIN( SkipGuardedSection );
  }
  return FALSE;
}

static bool handleEndIf(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->guards.isEmpty())
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"found \\endif without matching start command");
  }
  else
  {
    delete yyextra->guards.pop();
  }
  yyextra->enabledSectionFound=FALSE;
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  BEGIN( GuardParamEnd );
  return FALSE;
}

static bool handleIngroup(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->inGroupParamFound=FALSE;
  BEGIN( InGroupParam );
  return FALSE;
}

static bool handleNoSubGrouping(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->subGrouping = FALSE; 
  return FALSE;
}

static bool handleShowInitializer(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->initLines = 100000; // ON
  return FALSE;
}

static bool handleHideInitializer(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->initLines = 0; // OFF
  return FALSE;
}

static bool handleCallgraph(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->callGraph = TRUE; // ON
  return FALSE;
}

static bool handleHideCallgraph(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->callGraph = FALSE; // OFF
  return FALSE;
}

static bool handleCallergraph(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->callerGraph = TRUE; // ON
  return FALSE;
}

static bool handleHideCallergraph(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->callerGraph = FALSE; // OFF
  return FALSE;
}

static bool handleInternal(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (!Config_getBool(INTERNAL_DOCS))
  {
    // make sure some whitespace before a \internal command
    // is not treated as "documentation"
    if (yyextra->current->doc.stripWhiteSpace().isEmpty())
    { 
      yyextra->current->doc.resize(0);
    }
    yyextra->condCount=0;
    BEGIN( SkipInternal );
  }
  else
  {
    // re-enabled for bug640828
    addOutput("\\internal ",yyscanner); 
    yyextra->inInternalDocs = TRUE;
  }
  return FALSE;
}

static bool handleLineBr(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  addOutput('\n',yyscanner);
  return FALSE;
}

static bool handleStatic(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  endBrief(TRUE,yyscanner);
  yyextra->current->stat = TRUE; 
  return FALSE;
}

static bool handlePure(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  endBrief(TRUE,yyscanner);
  yyextra->current->virt = Pure; 
  return FALSE;
}

static bool handlePrivate(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = Private;
  return FALSE;
}

static bool handlePrivateSection(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = yyextra->protection = Private;
  return FALSE;
}

static bool handleProtected(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = Protected;
  return FALSE;
}

static bool handleProtectedSection(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = yyextra->protection = Protected ;
  return FALSE;
}

static bool handlePublic(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = Public;
  return FALSE;
}

static bool handlePublicSection(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  yyextra->current->protection = yyextra->protection = Public;
  return FALSE;
}

static bool handleToc(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->current->section==Entry::PAGEDOC_SEC || 
      yyextra->current->section==Entry::MAINPAGEDOC_SEC)
  {
    yyextra->current->stat=TRUE;  // we 'abuse' stat to pass whether or the TOC is enabled
  }
  return FALSE;
}

static bool handleInherit(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  BEGIN(InheritParam);
  return FALSE;
}

static bool handleExtends(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  BEGIN(ExtendsParam);
  return FALSE;
}

static bool handleCopyBrief(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (yyextra->current->brief.isEmpty() && yyextra->current->doc.isEmpty())
  { // if we don't have a brief or detailed description yet,
    // then the @copybrief should end up in the brief description.
    // otherwise it will be copied inline (see bug691315 & bug700788)
    setOutput(OutputBrief,yyscanner);
  }
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("\\copybrief ",yyscanner);
  return FALSE;
}

static bool handleCopyDetails(const QCString &,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  setOutput(OutputDoc,yyscanner);
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("\\copydetails ",yyscanner);
  return FALSE;
}

static bool handleCopyDoc(const QCString &, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  setOutput(OutputBrief,yyscanner);
  if (!yyextra->spaceBeforeCmd.isEmpty()) 
  {
    addOutput(yyextra->spaceBeforeCmd,yyscanner);
    yyextra->spaceBeforeCmd.resize(0);
  }
  addOutput("\\copybrief ",yyscanner);
  yyextra->copyDocArg.resize(0);
  BEGIN(CopyDoc);
  return FALSE;
}

//----------------------------------------------------------------------------

static void checkFormula(yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (YY_START==ReadFormulaShort || YY_START==ReadFormulaLong)
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,"End of comment block while inside formula.");
  }
}


//---------------------------------------------------------------------------

static int findExistingGroup(int &groupId,const MemberGroupInfo *info,yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  //printf("findExistingGroup %s:%s\n",info->header.data(),info->compoundName.data());
  QIntDictIterator<MemberGroupInfo> di(Doxygen::memGrpInfoDict);
  MemberGroupInfo *mi;
  for (di.toFirst();(mi=di.current());++di)
  {
    if (yyextra->compoundName==mi->compoundName &&  // same file or scope
	!mi->header.isEmpty() &&             // not a nameless group
	qstricmp(mi->header,info->header)==0  // same header name
       )
    {
      //printf("Found it!\n");
      return (int)di.currentKey(); // put the item in this group
    }
  }
  groupId++; // start new group
  return groupId;
}

static void groupAddDocs(Entry *e, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  if (e->section==Entry::MEMBERGRP_SEC)
  {
    yyextra->memberGroupDocs=e->brief.stripWhiteSpace();
    e->doc = stripLeadingAndTrailingEmptyLines(e->doc,e->docLine);
    if (!yyextra->memberGroupDocs.isEmpty() && !e->doc.isEmpty())
    {
      yyextra->memberGroupDocs+="\n\n";
    }
    yyextra->memberGroupDocs+=e->doc;
    MemberGroupInfo *info=Doxygen::memGrpInfoDict.find(yyextra->memberGroupId);
    if (info) 
    {
      info->doc = yyextra->memberGroupDocs;
      info->docFile = e->docFile;
      info->docLine = e->docLine;
      info->setRefItems(e->sli);
    }
    e->doc.resize(0);
    e->brief.resize(0);
  }
}

static void handleGuard(const QCString &expr, yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;

  CondParser prs;
  bool sectionEnabled=prs.parse(yyextra->yyFileName,yyextra->yyLineNr,expr.stripWhiteSpace());
  bool parentEnabled = TRUE;
  if (!yyextra->guards.isEmpty()) parentEnabled = yyextra->guards.top()->isEnabled();
  if (parentEnabled)
  {
    if (
        (sectionEnabled && yyextra->guardType==Guard_If) ||  
        (!sectionEnabled && yyextra->guardType==Guard_IfNot)
       ) // section is visible
    {
      yyextra->guards.push(new GuardedSection(TRUE,TRUE));
      yyextra->enabledSectionFound=TRUE;
      BEGIN( GuardParamEnd );
    }
    else // section is invisible
    {
      if (yyextra->guardType!=Guard_Skip)
      {
        yyextra->guards.push(new GuardedSection(FALSE,TRUE));
      }
      BEGIN( SkipGuardedSection );
    }
  }
  else // invisible because of parent
  {
    yyextra->guards.push(new GuardedSection(FALSE,FALSE));
    BEGIN( SkipGuardedSection );
  }
}


// public interface -----------------------------------------------------------
DocCmdMapper    *DocCmdMapper::s_instance=0;
static yyscan_t g_yyscanner;
static struct commentscanYY_state g_commentscan_extra;

bool parseCommentBlock(/* in */     ParserInterface *parser,
                       /* in */     Entry *curEntry,
                       /* in */     const QCString &comment,
		       /* in */     const QCString &fileName,
		       /* in,out */ int  &lineNr,
		       /* in */     bool isBrief,
		       /* in */     bool isAutoBriefOn,
		       /* in */     bool isInbody,
		       /* in,out */ Protection &prot,
		       /* in,out */ int &position,
		       /* out */    bool &newEntryNeeded
		      )
{
  commentscanYYlex_init_extra(&g_commentscan_extra, &g_yyscanner);
  struct yyguts_t *yyg = (struct yyguts_t*)g_yyscanner;

  //printf("parseCommentBlock() isBrief=%d isAutoBriefOn=%d lineNr=%d\n",
  //    isBrief,isAutoBriefOn,lineNr);

  initParser(g_yyscanner);
  yyextra->guards.setAutoDelete(TRUE);
  yyextra->guards.clear();
  yyextra->langParser     = parser;
  yyextra->current        = curEntry;
  yyextra->memberGroupId = DOX_NOGROUP;
  yyextra->prevPosition = 0;
  yyextra->inInternalDocs = FALSE;
  if (comment.isEmpty()) return FALSE; // avoid empty strings
  yyextra->inputString    = comment;
  yyextra->inputString.append(" ");
  yyextra->inputPosition  = position;
  yyextra->yyLineNr       = lineNr;
  yyextra->yyFileName     = fileName;
  yyextra->protection     = prot;
  yyextra->needNewEntry   = FALSE;
  yyextra->xrefKind       = XRef_None;
  yyextra->xrefAppendFlag = FALSE;
  yyextra->insidePre      = FALSE;
  yyextra->parseMore      = FALSE;
  yyextra->inBody         = isInbody;
  yyextra->outputXRef.resize(0);
  setOutput( isBrief || isAutoBriefOn ? OutputBrief : OutputDoc, g_yyscanner);
  yyextra->briefEndsAtDot = isAutoBriefOn;
  yyextra->condCount    = 0;
  yyextra->sectionLevel = 0;
  yyextra->spaceBeforeCmd.resize(0);
  yyextra->spaceBeforeIf.resize(0);

  printlex(yy_flex_debug, TRUE, __FILE__, fileName ? fileName.data(): NULL);
  if (!yyextra->current->inbodyDocs.isEmpty() && isInbody) // separate in body fragments
  {
    yyextra->current->inbodyDocs+="\n\n";
  }

  Debug::print(Debug::CommentScan,0,"-----------\nCommentScanner: %s:%d\n"
               "input=[\n%s]\n",qPrint(fileName),lineNr,qPrint(comment)
              );

  commentscanYYrestart( yyin, g_yyscanner);
  BEGIN( Comment );
  commentscanYYlex(g_yyscanner);
  setOutput( OutputDoc,g_yyscanner);

  if (YY_START==OverloadParam) // comment ended with \overload
  {
    addOutput(getOverloadDocs(),g_yyscanner);
  }

  if (!yyextra->guards.isEmpty())
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,"Documentation block ended in the middle of a conditional section!");
  }

  if (yyextra->insideParBlock)
  {
    warn(yyextra->yyFileName,yyextra->yyLineNr,
	"Documentation block ended while inside a \\parblock. Missing \\endparblock");
  }

  yyextra->current->doc=stripLeadingAndTrailingEmptyLines(yyextra->current->doc,yyextra->current->docLine);

  if (yyextra->current->section==Entry::FILEDOC_SEC && yyextra->current->doc.isEmpty())
  {
    // to allow a comment block with just a @file command.
    yyextra->current->doc="\n\n";
  }

  if (yyextra->current->section==Entry::MEMBERGRP_SEC &&
      yyextra->memberGroupId==DOX_NOGROUP) // @name section but no group started yet
  {
    openGroup(yyextra->current,yyextra->yyFileName,yyextra->yyLineNr);
  }

  if (Doxygen::markdownSupport)
  {
    yyextra->current->brief      = processMarkdown(fileName,lineNr,yyextra->current,yyextra->current->brief);
    yyextra->current->doc        = processMarkdown(fileName,lineNr,yyextra->current,yyextra->current->doc);
    yyextra->current->inbodyDocs = processMarkdown(fileName,lineNr,yyextra->current,yyextra->current->inbodyDocs);
  }

  Debug::print(Debug::CommentScan,0,
               "brief=[line=%d\n%s]\ndocs=[line=%d\n%s]\ninbody=[line=%d\n%s]\n===========\n",
	       yyextra->current->briefLine,qPrint(yyextra->current->brief),
               yyextra->current->docLine,qPrint(yyextra->current->doc),
               yyextra->current->inbodyLine,qPrint(yyextra->current->inbodyDocs)
              );

  checkFormula(yyextra);
  prot = yyextra->protection;

  groupAddDocs(curEntry,g_yyscanner);

  newEntryNeeded = yyextra->needNewEntry;

  // if we did not proceed during this call, it does not make
  // sense to continue, since we get stuck. See bug 567346 for situations
  // were this happens
  if (yyextra->parseMore && position==yyextra->inputPosition) yyextra->parseMore=FALSE;

  if (yyextra->parseMore) position=yyextra->inputPosition; else position=0;

  lineNr = yyextra->yyLineNr;
  //printf("position=%d yyextra->parseMore=%d newEntryNeeded=%d\n",
  //  position,yyextra->parseMore,newEntryNeeded);

  printlex(yy_flex_debug, FALSE, __FILE__, fileName ? fileName.data(): NULL);
  return yyextra->parseMore;
}


void groupEnterFile(const char *fileName,int)
{
  commentscanYYlex_init_extra(&g_commentscan_extra, &g_yyscanner);
  struct yyguts_t *yyg = (struct yyguts_t*)g_yyscanner;

  yyextra->autoGroupStack.setAutoDelete(TRUE);
  yyextra->autoGroupStack.clear();
  yyextra->memberGroupId = DOX_NOGROUP;
  yyextra->memberGroupDocs.resize(0);
  yyextra->memberGroupRelates.resize(0);
  yyextra->compoundName=fileName;
}

void groupLeaveFile(const char *fileName,int line)
{
  struct yyguts_t * yyg = (struct yyguts_t*)g_yyscanner;

  //if (yyextra->memberGroupId!=DOX_NOGROUP)
  //{
  //  warn(fileName,line,"end of file while inside a member group\n");
  //}
  yyextra->memberGroupId=DOX_NOGROUP;
  yyextra->memberGroupRelates.resize(0);
  yyextra->memberGroupDocs.resize(0);
  if (!yyextra->autoGroupStack.isEmpty())
  {
    warn(fileName,line,"end of file while inside a group\n");
  }
}


void groupLeaveCompound(const char *,int,const char * /*name*/)
{
  struct yyguts_t * yyg = (struct yyguts_t*)g_yyscanner;

  //printf("groupLeaveCompound(%s)\n",name);
  //if (yyextra->memberGroupId!=DOX_NOGROUP)
  //{
  //  warn(fileName,line,"end of compound %s while inside a member group\n",name);
  //}
  yyextra->memberGroupId=DOX_NOGROUP;
  yyextra->memberGroupRelates.resize(0);
  yyextra->memberGroupDocs.resize(0);
  yyextra->compoundName.resize(0);
}

void groupEnterCompound(const char *fileName,int line,const char *name)
{
  struct yyguts_t * yyg = (struct yyguts_t*)g_yyscanner;

  if (yyextra->memberGroupId!=DOX_NOGROUP)
  {
    warn(fileName,line,"try to put compound %s inside a member group\n",name);
  }
  yyextra->memberGroupId=DOX_NOGROUP;
  yyextra->memberGroupRelates.resize(0);
  yyextra->memberGroupDocs.resize(0);
  yyextra->compoundName = name;
  int i = yyextra->compoundName.find('(');
  if (i!=-1) 
  {
    yyextra->compoundName=yyextra->compoundName.left(i); // strip category (Obj-C)
  }
  if (yyextra->compoundName.isEmpty())
  {
    yyextra->compoundName=fileName;
  }
  //printf("groupEnterCompound(%s)\n",name);
}

void openGroup(Entry *e,const char *,int)
{
  struct yyguts_t *yyg = (struct yyguts_t*)g_yyscanner;

  //printf("==> openGroup(name=%s,sec=%x) yyextra->autoGroupStack=%d\n",
  //  	e->name.data(),e->section,yyextra->autoGroupStack.count());
  if (e->section==Entry::GROUPDOC_SEC) // auto group
  {
    yyextra->autoGroupStack.push(new Grouping(e->name,e->groupingPri()));
  }
  else // start of a member group
  {
    //printf("    membergroup id=%d %s\n",yyextra->memberGroupId,yyextra->memberGroupHeader.data());
    if (yyextra->memberGroupId==DOX_NOGROUP) // no group started yet
    {
      static int curGroupId=0;

      MemberGroupInfo *info = new MemberGroupInfo;
      info->header = yyextra->memberGroupHeader.stripWhiteSpace();
      info->compoundName = yyextra->compoundName;
      yyextra->memberGroupId = findExistingGroup(curGroupId,info,g_yyscanner);
      //printf("    use membergroup %d\n",yyextra->memberGroupId);
      Doxygen::memGrpInfoDict.insert(yyextra->memberGroupId,info);

      yyextra->memberGroupRelates = e->relates;
      e->mGrpId = yyextra->memberGroupId;
    }
  }
}

void closeGroup(Entry *e,const char *fileName,int line,bool foundInline)
{
  struct yyguts_t *yyg = (struct yyguts_t*)g_yyscanner;

  //printf("==> closeGroup(name=%s,sec=%x,file=%s,line=%d) yyextra->autoGroupStack=%d\n",
  //    e->name.data(),e->section,fileName,line,yyextra->autoGroupStack.count());
  if (yyextra->memberGroupId!=DOX_NOGROUP) // end of member group
  {
    MemberGroupInfo *info=Doxygen::memGrpInfoDict.find(yyextra->memberGroupId);
    if (info) // known group
    {
      info->doc = yyextra->memberGroupDocs;
      info->docFile = fileName;
      info->docLine = line;
    }
    yyextra->memberGroupId=DOX_NOGROUP;
    yyextra->memberGroupRelates.resize(0);
    yyextra->memberGroupDocs.resize(0);
    if (!foundInline) e->mGrpId=DOX_NOGROUP;
    //printf("new group id=%d\n",yyextra->memberGroupId);
  }
  else if (!yyextra->autoGroupStack.isEmpty()) // end of auto group
  {
    Grouping *grp = yyextra->autoGroupStack.pop();
    // see bug577005: we should not remove the last group for e
    if (!foundInline) e->groups->removeLast();
    //printf("Removing %s e=%p\n",grp->groupname.data(),e);
    delete grp;
    if (!foundInline) initGroupInfo(e);
  }
}

void initGroupInfo(Entry *e)
{
  struct yyguts_t * yyg = (struct yyguts_t*)g_yyscanner;

  //printf("==> initGroup(id=%d,related=%s,e=%p)\n",yyextra->memberGroupId,
  //       yyextra->memberGroupRelates.data(),e);
  e->mGrpId     = yyextra->memberGroupId;
  e->relates    = yyextra->memberGroupRelates;
  if (!yyextra->autoGroupStack.isEmpty())
  {
    //printf("Appending group %s to %s: count=%d entry=%p\n",
    //	yyextra->autoGroupStack.top()->groupname.data(),
    //	e->name.data(),e->groups->count(),e);
    e->groups->append(new Grouping(*yyextra->autoGroupStack.top()));
  }
}


#if !defined(YY_FLEX_SUBMINOR_VERSION) 
//----------------------------------------------------------------------------
extern "C" { // some bogus code to keep the compiler happy
  void commentscanYYdummy() { yy_flex_realloc(0,0); } 
}
#endif

