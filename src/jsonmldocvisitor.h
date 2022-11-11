/******************************************************************************
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

#ifndef _JSONMLDOCVISITOR_H
#define _JSONMLDOCVISITOR_H

#include "docvisitor.h"
#include "docparser.h"
#include <qcstring.h>
#include <stdint.h>


/*! @brief Concrete visitor implementation for JsonML output. */
class JsonMLDocVisitor : public DocVisitor
{
  public:
    JsonMLDocVisitor(QCString &t);
    //--------------------------------------
    // visitor functions for leaf nodes
    //--------------------------------------
    void visit(DocWord *w );
    void visit(DocWhiteSpace *w);
    void visit(DocAnchor *anc);
    void visit(DocStyleChange *s);
    /////
    void visit(DocLinkedWord *w)  {}
    void visit(DocSymbol *)       {}
    void visit(DocEmoji *)        {}
    void visit(DocURL *u)         {}
    void visit(DocLineBreak *)    {}
    void visit(DocHorRuler *)     {}
    void visit(DocVerbatim *s)    {}
    void visit(DocInclude *)      {}
    void visit(DocIncOperator *)  {}
    void visit(DocFormula *)      {}
    void visit(DocIndexEntry *);
    void visit(DocSimpleSectSep *);
    void visit(DocCite *)         {}
    //--------------------------------------
    // visitor functions for compound nodes
    //--------------------------------------
    void visitPre(DocPara *w);
    void visitPost(DocPara *w);
    void visitPre(DocRef *ref);
    void visitPost(DocRef *);
    void visitPre(DocTitle *w);
    void visitPost(DocTitle *w);
    void visitPre(DocSimpleSect *s);
    void visitPost(DocSimpleSect *);
    void visitPre(DocAutoList *l);
    void visitPost(DocAutoList *l);
    void visitPre(DocAutoListItem *);
    void visitPost(DocAutoListItem *);
    void visitPre(DocSimpleList *);
    void visitPost(DocSimpleList *);
    void visitPre(DocSimpleListItem *);
    void visitPost(DocSimpleListItem *);
    //////////////////////////////////
    void visitPre(DocRoot *) {}
    void visitPost(DocRoot *) {}
    void visitPre(DocSection *) {}
    void visitPost(DocSection *) {}
    void visitPre(DocHtmlList *) {}
    void visitPost(DocHtmlList *)  {}
    void visitPre(DocHtmlListItem *) {}
    void visitPost(DocHtmlListItem *) {}
    void visitPre(DocHtmlDescList *);
    void visitPost(DocHtmlDescList *);
    void visitPre(DocHtmlDescTitle *) {}
    void visitPost(DocHtmlDescTitle *) {}
    void visitPre(DocHtmlDescData *) {}
    void visitPost(DocHtmlDescData *) {}
    void visitPre(DocHtmlTable *) {}
    void visitPost(DocHtmlTable *) {}
    void visitPre(DocHtmlRow *) {}
    void visitPost(DocHtmlRow *)  {}
    void visitPre(DocHtmlCell *) {}
    void visitPost(DocHtmlCell *) {}
    void visitPre(DocHtmlCaption *) {}
    void visitPost(DocHtmlCaption *) {}
    void visitPre(DocInternal *) {}
    void visitPost(DocInternal *) {}
    void visitPre(DocHRef *) {}
    void visitPost(DocHRef *) {}
    void visitPre(DocHtmlHeader *) {}
    void visitPost(DocHtmlHeader *) {}
    void visitPre(DocImage *) {}
    void visitPost(DocImage *) {}
    void visitPre(DocDotFile *) {}
    void visitPost(DocDotFile *) {}

    void visitPre(DocMscFile *) {}
    void visitPost(DocMscFile *) {}
    void visitPre(DocDiaFile *) {}
    void visitPost(DocDiaFile *) {}
    void visitPre(DocLink *) {}
    void visitPost(DocLink *) {}
    void visitPre(DocSecRefItem *) {}
    void visitPost(DocSecRefItem *) {}
    void visitPre(DocSecRefList *) {}
    void visitPost(DocSecRefList *) {}
    void visitPre(DocParamSect *);
    void visitPost(DocParamSect *);
    void visitPre(DocParamList *);
    void visitPost(DocParamList *);
    void visitPre(DocXRefItem *) {}
    void visitPost(DocXRefItem *) {}
    void visitPre(DocInternalRef *) {}
    void visitPost(DocInternalRef *) {}
    void visitPre(DocText *) {}
    void visitPost(DocText *) {}
    void visitPre(DocHtmlBlockQuote *) {}
    void visitPost(DocHtmlBlockQuote *) {}
    void visitPre(DocVhdlFlow *) {}
    void visitPost(DocVhdlFlow *) {}
    void visitPre(DocParBlock *) ;
    void visitPost(DocParBlock *) ;
  protected:
    //--------------------------------------
    // helper functions
    //--------------------------------------
    bool needsComma();
    void beginScope();
    void addComma();
    void endScope();
    void json_string_start();
    void json_string_end();
    void json_string(const char*str);
    void json_object_start();
    void json_object_end();
    void json_array_start();
    void json_array_end();
    //--------------------------------------
    // state variables
    //--------------------------------------
    bool m_insideString;
    int m_lvl;
    uint64_t m_ic;
    QCString &m_t;
    QCString m_tmpstr;
    void filter(const QCString &str);
};

#endif
