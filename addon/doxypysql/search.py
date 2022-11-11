#!/usr/bin/python3

# python script to search through doxygen_sqlite3.db
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby
# granted. No representations are made about the suitability of this software
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.


import sqlite3
import sys
import os
import argparse
import json
import re


class MemberType:
  Define="macro definition"
  Function="function"
  Variable="variable"
  Typedef="typedef"
  Union="union"
  Enumeration="enumeration"
  EnumValue="enumvalue"
  Signal="signal"
  Struct="struct"
  Slot="slot"
  Friend="friend"
  DCOP="dcop"
  Property="property"
  Event="event"
  File="file"


class Finder:
    def __init__(self,cn,name,use_regexp,row_type=str):
        self.cn=cn
        self.name=None
        if name:
          self.name=name[0]
        self.use_regexp = use_regexp
        self.row_type=row_type

    def __match(self,row):
        if self.row_type is int:
            return " rowid=?"
        else:
            if self.use_regexp == True:
                return " REGEXP (?,%s)" %row
            else:
                return " %s=?" %row

    def __file_name(self,deffile_id):
        if self.cn.execute("SELECT COUNT(*) FROM path WHERE rowid=?",[deffile_id]).fetchone()[0] > 1:
            sys.stderr.write("WARNING: non-uniq fileid [%s]. Considering only the first match." % deffile_id)

        for r in self.cn.execute("SELECT name FROM path WHERE rowid=?",[deffile_id]).fetchall():
                return r['name']

        return ""

    def __file_id(self,name):
        if self.cn.execute("SELECT COUNT(*) FROM path WHERE"+self.__match("name"),[name]).fetchone()[0] > 1:
            sys.stderr.write("WARNING: non-uniq file name [%s]. Considering only the first match." % name)

        for r in self.cn.execute("SELECT rowid FROM path WHERE"+self.__match("name"),[name]).fetchall():
                return r[0]

        return -1

    def base_class(self,fname):
        o=[]
        c=self.cn.execute('SELECT compounddef.name FROM compounddef JOIN compoundref ON compounddef.rowid=compoundref.base_rowid WHERE compoundref.derived_rowid IN (SELECT rowid FROM compounddef WHERE'+self.__match("name")+')',[self.name])
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            o.append(item)
        return o

    def compound_members(self,fname):
        o=[]
        c=self.cn.execute('SELECT * FROM memberdef WHERE'+self.__match("scope"),[self.name])
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            item['kind'] = r['kind']
            item['definition'] = r['definition']
            item['argsstring'] = r['argsstring']
            item['detaileddescription'] = r['detaileddescription']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            o.append(item)
        return o

    def file(self, fname):
        o=[]
        for r in self.cn.execute("SELECT rowid,name FROM local_file WHERE"+self.__match("name"),[self.name]).fetchall():
            item={}
            item['name'] = r['name']
            item['id'] =   r['rowid']
            o.append(item)
        return o

    def file_members(self, fname):
        o=[]
        fid=self.__file_id(self.name)
        c=self.cn.execute('SELECT * FROM memberdef WHERE deffile_id=?',[fid])
        for r in c.fetchall():
            item={}
            item['kind'] = r['kind']
            item['name'] = r['name']
            item['argsstring'] = r['argsstring']
            item['detaileddescription'] = r['detaileddescription']
            item['briefdescription'] = r['briefdescription']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            o.append(item)
        return o

    def function(self, fname):
        o=[]
        ph='SELECT * FROM memberdef WHERE kind=? '
        ar=[MemberType.Function]
        if self.name:
            ph = ph + ' AND ' + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))

        c=self.cn.execute(ph, ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            item['type'] = r['type']
            item['definition'] = r['definition']
            item['argsstring'] = r['argsstring']
            item['detaileddescription'] = r['detaileddescription']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            o.append(item)
        return o

    def includees(self, fname):
        o=[]
        fid = self.__file_id(self.name)
        c=self.cn.execute('SELECT * FROM includes WHERE src_id=?',[fid])
        for r in c.fetchall():
            item={}
            item['name'] = self.__file_name(r['dst_id'])
            o.append(item)
        return o

    def includers(self, fname):
        o=[]
        fid = self.__file_id(self.name)
        c=self.cn.execute('SELECT * FROM includes WHERE dst_id=?',[fid])
        for r in c.fetchall():
            item={}
            item['name'] = self.__file_name(r['src_id'])
            o.append(item)
        return o

    def references(self, fname):
        o=[]
        cur = self.cn.cursor()
        cur.execute("SELECT rowid FROM memberdef WHERE"+self.__match("name"),[self.name])
        rowids = cur.fetchall()

        if len(rowids) == 0:
            return o

        rowid = rowids[0]['rowid']
        cur = self.cn.cursor()

        #TODO:SELECT rowid from refid where refid=refid
        for info in cur.execute("SELECT * FROM xrefs WHERE dst_rowid=?", [rowid]):
            item={}
            cur = self.cn.cursor()
            for i2 in cur.execute("SELECT * FROM memberdef WHERE rowid=?",[info['src_rowid']]):
                item['file']=self.__file_name(i2['bodyfile_id'])
                item['name']=i2['name']
                item['bodystart']=i2['bodystart']
                item['bodyend']=i2['bodyend']

            o.append(item)

        #for info in cur.execute("SELECT * FROM memberdef_param WHERE dst_rowid=?", [rowid]):
        #    item={}
        #    cur = self.cn.cursor()
        #    for i2 in cur.execute("SELECT * FROM memberdef WHERE rowid=?",[info['src_rowid']]):
        #        item['name'] = i2['name']
        #        item['src'] = info['src_rowid']

            o.append(item)
        return o

    def macro_definition(self, fname):
        o=[]
        ph='SELECT * FROM memberdef WHERE kind=? '
        ar=[MemberType.Define]
        if self.name:
            ph = ph + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            if r['argsstring']:
                item['argsstring'] = r['argsstring']
            item['definition'] = r['initializer']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            o.append(item)
        return o

    def referenced_by(self, fname):
        o=[]
        cur = self.cn.cursor()
        cur.execute("SELECT rowid FROM memberdef WHERE"+self.__match("name"),[self.name])
        rowids = cur.fetchall()

        if len(rowids) == 0:
            return o

        rowid = rowids[0]['rowid']
        cur = self.cn.cursor()

        #TODO:SELECT rowid from refid where refid=refid
        for info in cur.execute("SELECT * FROM xrefs WHERE src_rowid=?", [rowid]):
            item={}
            cur = self.cn.cursor()
            for i2 in cur.execute("SELECT * FROM memberdef WHERE rowid=?",[info['dst_rowid']]):
                item['file']=self.__file_name(i2['bodyfile_id'])
                item['name']=i2['name']
                item['bodystart']=i2['bodystart']
                item['bodyend']=i2['bodyend']

            o.append(item)

        #for info in cur.execute("SELECT * FROM memberdef_param WHERE dst_rowid=?", [rowid]):
        #    item={}
        #    cur = self.cn.cursor()
        #    for i2 in cur.execute("SELECT * FROM memberdef WHERE rowid=?",[info['src_rowid']]):
        #        item['name'] = i2['name']
        #        item['src'] = info['src_rowid']

            o.append(item)
        return o

    def sub_class(self, fname):
        o=[]
        c=self.cn.execute('SELECT compounddef.name FROM compounddef JOIN compoundref ON compounddef.rowid=compoundref.derived_rowid WHERE compoundref.base_rowid IN (SELECT rowid FROM compounddef WHERE'+self.__match("name")+')',[self.name])
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            o.append(item)
        return o

    def typedef(self, fname):
        o=[]
        ph='SELECT * FROM memberdef WHERE kind=? '
        ar=[MemberType.Typedef]
        if self.name:
            ph = ph + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            item['definition'] = r['definition']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            item['briefdescription'] = r['briefdescription']
            item['detaileddescription'] = r['detaileddescription']
            o.append(item)
        return o

    def variable(self, fname):
        o=[]
        ph='SELECT * FROM memberdef WHERE kind=? '
        ar=[MemberType.Variable]
        if self.name:
            ph = ph + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            item['definition'] = r['definition']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            item['rowid'] = r['rowid']
            o.append(item)
        return o

    def params(self, fname):
        o=[]
        ph='SELECT rowid FROM memberdef WHERE'+self.__match("name")
        ar=[self.name]
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            #a=("SELECT * FROM param where id=(SELECT param_id FROM memberdef_param where memberdef_id=?",[memberdef_id])
            item={}
            item['id'] = r['id']
            o.append(item)
        return o

    def union(self, fname):
        o=[]
        ph='SELECT * FROM compounddef WHERE kind=? '
        ar=[MemberType.Union]
        if self.name:
            ph = ph + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            #item['definition'] = r['definition']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            item['briefdescription'] = r['briefdescription']
            item['detaileddescription'] = r['detaileddescription']
            o.append(item)
        return o

    def struct(self, fname):
        o=[]
        ph='SELECT * FROM compounddef WHERE kind=?'
        ar=[MemberType.Struct]
        if self.name:
            ph = ph + ' AND ' + self.__match("name")
            ar.append(self.name)
        if fname:
            ph = ph + ' AND deffile_id=?'
            ar.append(self.__file_id(fname))
        print(f"{ph} ---- {ar}")
        c=self.cn.execute(ph,ar)
        for r in c.fetchall():
            item={}
            item['name'] = r['name']
            item['deffile'] = self.__file_name(r['deffile_id'])
            item['defline'] = r['defline']
            item['rowid'] = r['rowid']
            item['briefdescription'] = r['briefdescription']
            item['detaileddescription'] = r['detaileddescription']
            o.append(item)
        return o

    def any(self, fname):
      o=[]

      # is it in memberdef ?
      if self.cn.execute('SELECT count(*) from memberdef WHERE'+self.__match("name"), [self.name]).fetchone()[0] > 0:
          c = self.cn.execute('SELECT * FROM memberdef WHERE'+self.__match("name"),[self.name])
          for r in c.fetchall():
              item={}
              item['kind'] = r['kind']
              item['type'] = r['type']
              item['name'] = r['name']
              item['definition'] = r['definition']
              item['argsstring'] = r['argsstring']
              item['deffile'] = self.__file_name(r['deffile_id'])
              item['defline'] = r['defline']
              item['briefdescription'] = r['briefdescription']
              item['detaileddescription'] = r['detaileddescription']
              o.append(item)
          return o

      # is it in compounddef ?
      if self.cn.execute('SELECT count(*) from compounddef WHERE'+self.__match("name"), [self.name]).fetchone()[0] > 0:
          c = self.cn.execute('SELECT * FROM compounddef WHERE'+self.__match("name"),[self.name])
          for r in c.fetchall():
              print(">>>>> %s" % r)
              item={}
              item['name'] = r['name']
              item['kind'] = r['kind']
              item['deffile'] = self.__file_name(r['deffile_id'])
              item['defline'] = r['defline']
              item['briefdescription'] = r['briefdescription']
              item['detaileddescription'] = r['detaileddescription']
              o.append(item)
          return o

      return o


    def find(self,str_kind, file=None):
        request_processors = {
            "base-class":       self.base_class,
            "compound-members": self.compound_members,
            "file":             self.file,
            "file-members":     self.file_members,
            "function":         self.function,
            "includees":        self.includees,
            "includers":        self.includers,
            "references":       self.references,
            "macro-definition": self.macro_definition,
            "referenced-by":    self.referenced_by,
            "sub-class":        self.sub_class,
            "typedef":          self.typedef,
            "union":            self.union,
            "variable":         self.variable,
            "params":           self.params,
            "struct":           self.struct,
            "any":              self.any,
        }
        return request_processors[str_kind](file)


def find_href(cn,ref):
    j={}

    # is it in memberdef ?
    table="memberdef"
    if ( cn.execute("SELECT count(*) from %s WHERE rowid=?"%table,[ref] ).fetchone()[0] > 0 ):
        for r in cn.execute("SELECT kind,rowid FROM %s WHERE rowid=?" % table,[ref]).fetchall():
            f=Finder(cn,r['rowid'],int)
            j=f.find(r['kind'])

    # is it in compounddef ?
    table="compounddef"
    if ( cn.execute("SELECT count(*) from %s WHERE rowid=?"%table,[ref]).fetchone()[0] > 0 ):
        for r in cn.execute("SELECT rowid FROM %s WHERE rowid=?"%table,[ref] ).fetchall():
            f=Finder(cn,r[0],int)
            j=f.find('struct')

    return j


def open_db(dbname=None):
    # case-insensitive sqlite regexp function
    def re_fn(expr, item):
      if item is None:
        return None
      reg = re.compile(expr, re.I)
      return reg.search(item) is not None

    if dbname == None:
        dbname = os.path.dirname(os.path.realpath(__file__)) + '/doxygen_sqlite3.db'

    if not os.path.isfile(dbname):
        print("failed to open %s" % dbname, file=sys.stderr)
        return None

    conn = sqlite3.connect(dbname)
    conn.execute('PRAGMA temp_store = MEMORY;')
    conn.row_factory = sqlite3.Row
    # I've used this because bitfield column was wrong
    #conn.text_factory = lambda b: b.decode(errors = 'ignore')
    conn.create_function("REGEXP", 2, re_fn)
    return conn


def serve_cgi():
    import cgi

    print('Content-Type: application/json\n')

    fieldStorage = cgi.FieldStorage()
    form = dict((key, fieldStorage.getvalue(key)) for key in fieldStorage.keys())

    if 'href' in form:
        ref = form['href']
    else:
        print('{"result": null, "error": "no refid given"}')
        sys.exit(0)

    dbname = os.path.dirname(os.path.realpath(__file__)) + '/doxygen_sqlite3.db'
    cn=open_db(dbname)
    if not cn:
        print(json.dumps({"result":None,"error":"failed to open doxygen_sqlite3.db"}))
        return


    j = find_href(cn,ref)

    print(json.dumps({"result":j,"error":None}))


def serve_cli():
    identifier=None
    j={}

    parser = argparse.ArgumentParser()
    parser.add_argument('-d'
                        , '--dbname'
                        , action='store'
                        , help='Use database <D> for queries.'
                       )
    parser.add_argument('-f'
                        , '--fname'
                        , action='store'
                        , help='Process only this file.'
                       )
    parser.add_argument('-H'
                       , '--href'
                       , action='store'
                       , help='Show info about this href.'
                       )
    parser.add_argument('-r'
                       , '--regex'
                       , action='store_true'
                       , help='Treat <identifier> as a regular expression.'
                       )
    parser.add_argument('-k'
                       , '--kind'
                       , choices=[
                                   'base-class'
                                  ,'compound-members'
                                  ,'file'
                                  ,'file-members'
                                  ,'function'
                                  ,'includees'
                                  ,'includers'
                                  ,'references'
                                  ,'macro-definition'
                                  ,'referenced-by'
                                  ,'sub-class'
                                  ,'typedef'
                                  ,'union'
                                  ,'variable'
                                  ,'params'
                                  ,'struct'
                                  ,'any'
                                 ]
                       , action='store'
                       , default='any'
                       , help='Do a search for this kind of <indentifier>.'
                       )
    (args,identifier) = parser.parse_known_args()

    cn=open_db(args.dbname)
    if not cn:
      return

    if args.href != None:
      j=find_href(cn,args.href)
    elif args.kind:
      j=Finder(cn,identifier,args.regex).find(args.kind, args.fname)
    else:
      parser.print_help()

    print(json.dumps(j,indent=4))


def main():
    if 'REQUEST_METHOD' in os.environ:
        serve_cgi()
    else:
        serve_cli()


if __name__ == '__main__':
    main()
