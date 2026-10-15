{
    Copyright (c) 1998-2002 by Florian Klaempfl, Pierre Muller

    This unit handles the symbol tables

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ****************************************************************************
}
unit symbase;

{$i fpcdefs.inc}

interface

    uses
       { common }
       CUtils,CClasses,
       { global }
       GlobType,Globals,
       { symtable }
       symconst
       ;

{************************************************
            Needed forward pointers
************************************************}

    type
       TSymTable = class;

       { THashedIDString }

       THashedIDString = record
       private
         FId   : TIDString;
         FHash : LongWord;
         procedure SetId(const s:TIDString);
       public
         property Id:TIDString read FId write SetId;
         property Hash:LongWord read FHash;
       end;


{************************************************
                 TDefEntry
************************************************}

      TDefEntry = class
         typ   : TDefTyp;
         defid : LongInt;
         owner : TSymTable;
      end;


{************************************************
                   TSymEntry
************************************************}

      { this object is the base for all symbol objects }
      TSymEntry = class(TFPHashObject)
      private
         FRealName : {$ifdef symansistr}TSymStr{$else}PShortString{$endif};
         function GetEscapedRealName: TSymStr;
         function  GetRealname: TSymStr;
         procedure SetRealname(const ANewName: TSymStr);
      public
         typ   : TSymTyp;
         SymId : LongInt;
         Owner : TSymTable;
         destructor Destroy;override;
         property RealName: TSymStr read GetRealName write SetRealName;
         property EscapedRealName: TSymStr read GetEscapedRealName;
      end;

{************************************************
                 TSymtable
************************************************}

       TSymTable = class
       public
          name      : PShortString;
          realname  : PShortString;
          DefList   : TFPObjectList;
          SymList   : TFPHashObjectList;
          defowner  : TDefEntry; { for records and objects }
          ModuleID  : LongInt;
          refcount  : smallint;
          currentvisibility : TVisibility;
          currentlyoptional : boolean;
          tableoptions : TSymTableOptions;
          { level of symtable, used for nested procedures }
          symtablelevel : byte;
          { do not allow to add new definitions, can be extended to symbols probably }
          sealed : boolean;
          symtabletype  : TSymTableType;
          constructor Create(const s:string);
          { attention: only execute the a child's destructor if refcount is 1! }
          destructor  Destroy;override;
          procedure freeinstance;override;
          function  getcopy:TSymTable;
          procedure clear;virtual;
          function  checkduplicate(var s:THashedIDString;sym:TSymEntry):boolean;virtual;
          procedure insertsym(sym:TSymEntry;checkdup:boolean=true);virtual;
          procedure Deletesym(sym:TSymEntry);virtual;
          function  Find(const s:TIDString) : TSymEntry;
          function  FindWithHash(const s:THashedIDString) : TSymEntry;virtual;
          procedure insertdef(def:TDefEntry);virtual;
          procedure deletedef(def:TDefEntry);
          function  iscurrentunit:boolean;virtual;
          { includes the flag in this symtable and all parent symtables; if
            it's already set the flag is not set again }
          procedure includeoption(option:TSymTableOption);
          class function maybe_adjust_symname(const s:TSymStr):TSymStr;
       end;

       PSymTableStackItem = ^TSymTableStackItem;
       TSymTableStackItem = record
         SymTable : TSymTable;
         Saved_ModuleID : LongInt;
         next     : PSymTableStackItem;
       end;

       TSymTableStack = class
         stack : PSymTableStackItem;
         constructor create;
         destructor Destroy;override;
         procedure clear;
         function finditem(st:TSymTable):PSymTableStackItem;
         procedure push(st:TSymTable); virtual;
         procedure pushafter(st,afterst:TSymTable); virtual;
         procedure pop(st:TSymTable); virtual;
         { Remove st from anywhere in the stack without raising an error if
           it is not present.  Used by the CTask PPU-cycle fix to excise a
           symtable that is about to be freed (via tmodule.reset) from a
           suspended module's saved symtablestack before RestoreState runs. }
         procedure remove(st:TSymTable);
         function  top:TSymTable;
         function getcopyuntil(finalst: TSymTable): TSymTableStack;
       end;


    var
       initialmacrosymtable: TSymTable;   { macros initially defined by the compiler or
                                            given on the command line. Is common
                                            for all files compiled and do not change. }
       MacroSymTableStack,
       SymTableStack        : TSymTableStack;

{$ifdef MEMDEBUG}
    var
      memrealnames : TMemDebug;
{$endif MEMDEBUG}


implementation

    uses
       Verbose;

{****************************************************************************
                              THashedIDString
****************************************************************************}

    procedure THashedIDString.SetId(const s:TIDString);
      begin
        FId:=s;
{$ifdef symansistr}
        if length(FId)>maxidlen then
          SetLength(FId,maxidlen);
{$endif}
        FHash:=FPHash(FId);
      end;


{****************************************************************************
                                TSymEntry
****************************************************************************}

    destructor TSymEntry.Destroy;
      begin
{$ifdef MEMDEBUG}
        memrealnames.start;
{$endif MEMDEBUG}
{$ifndef symansistr}
        StringDispose(Frealname);
{$endif}
{$ifdef MEMDEBUG}
        memrealnames.stop;
{$endif MEMDEBUG}
        inherited Destroy;
      end;


    function TSymEntry.GetRealname:TSymStr;
      begin
{$ifndef symansistr}
        if not Assigned(FRealname) then
          InternalError(200611011);
        result:=FRealname^;
{$else}
       if FRealName='' then
         InternalError(200611011);
       result:=FRealName;
{$endif}
      end;


    function TSymEntry.GetEscapedRealName: TSymStr;
      begin
        result:=GetRealname;
        if result=Name then
          result:='$'+result;
      end;


    procedure TSymEntry.SetRealname(const ANewName:TSymStr);
      begin
{$ifndef symansistr}
        StringDispose(FRealname);
        FRealname:=StringDup(ANewName);
{$else}
        FRealname:=ANewName;
{$endif}
        if Hash<>$ffffffff then
          begin
            if ANewName[1]='$' then
              Rename(Copy(ANewName,2,length(ANewName)))
            else
              Rename(Upper(ANewName));
          end;
      end;


{****************************************************************************
                                TSymtable
****************************************************************************}

    constructor TSymTable.Create(const s:string);
      begin
         if s<>'' then
           begin
             name:=StringDup(upper(s));
             realname:=StringDup(s);
           end
         else
           begin
             name:=nil;
             realname:=nil;
           end;
         symtabletype:=abstractsymtable;
         symtablelevel:=0;
         defowner:=nil;
         DefList:=TFPObjectList.Create(true);
         SymList:=TFPHashObjectList.Create(true);
         refcount:=1;
         currentvisibility:=vis_public;
         currentlyoptional:=false;
      end;


    destructor TSymTable.Destroy;
      begin
        { freeinstance decreases refcount }
        if refcount>1 then
          exit;
        Clear;
        DefList.Free;
        DefList := nil;
        { SymList can already be disposed or set to nil for withsymtable, }
        { but in that case Free does nothing                              }
        SymList.Free;
        SymList := nil;
        StringDispose(name);
        StringDispose(realname);
      end;


    procedure TSymTable.freeinstance;
      begin
        dec(refcount);
        if refcount=0 then
          inherited freeinstance;
      end;


    function TSymTable.getcopy:TSymTable;
      begin
        inc(refcount);
        result:=self;
      end;


    function TSymTable.iscurrentunit:boolean;
      begin
        result:=false;
      end;

    procedure TSymTable.includeoption(option: TSymTableOption);
      var
        st: TSymTable;
      begin
        if option in tableoptions then
          exit;
        include(tableoptions,option);
        { iterative approach should be faster than recursion based on calls }
        st:=self;
        while Assigned(st.defowner) do
          begin
            st:=st.defowner.owner;
            { this can happen for specializations of routines that are not yet
              owned cause they might be thrown away again }
            if not Assigned(st) then
              break;
            { the flag is already set, so by definition it is set in the
              owning symtables as well }
            if option in st.tableoptions then
              break;
            include(st.tableoptions,option);
          end;
      end;


    procedure TSymTable.clear;
      var
        i : integer;
      begin
         SymList.Clear;
         { Prevent recursive calls between TDef.destroy and TSymtable.Remove }
         if DefList.OwnsObjects then
           begin
             for i := 0 to DefList.Count-1 do
               TDefEntry(DefList[i]).Owner:=nil;
           end;
         DefList.Clear;
      end;


    function TSymTable.checkduplicate(var s:THashedIDString;sym:TSymEntry):boolean;
      begin
        result:=(FindWithHash(s)<>nil);
      end;


    procedure TSymTable.insertsym(sym:TSymEntry;checkdup:boolean=true);
      var
        hashedid : THashedIDString;
        s : TSymStr;
      begin
         s:=maybe_adjust_symname(sym.realname);
         if checkdup then
           begin
             hashedid.id:=s;
             { First check for duplicates, this can change the symbol name
               in case of a duplicate entry }
             if checkduplicate(hashedid,sym) then
               s:=maybe_adjust_symname(sym.realname);
           end;
         { Now we can insert the symbol, any duplicate entries
           are renamed to an unique (and for users inaccessible) name }
         if checkdup then
           begin
             if hashedid.id<>s then
               hashedid.id:=s;
             sym.ChangeOwnerAndNameWithHash(SymList,s,hashedid.hash);
           end
         else
           sym.ChangeOwnerAndName(SymList,s);
         sym.Owner:=self;
      end;


    procedure TSymTable.Deletesym(sym:TSymEntry);
      begin
        if sym.Owner<>self then
          InternalError(200611121);
        SymList.Remove(sym);
      end;


    procedure TSymTable.insertdef(def:TDefEntry);
      begin
         DefList.Add(def);
         def.owner:=self;
      end;


    procedure TSymTable.deletedef(def:TDefEntry);
      begin
        if def.Owner<>self then
          InternalError(200611122);
        def.Owner:=nil;
        DefList.Remove(def);
      end;


    function TSymTable.Find(const s : TIDString) : TSymEntry;
      begin
        result:=TSymEntry(SymList.Find(s));
      end;


    function TSymTable.FindWithHash(const s:THashedIDString) : TSymEntry;
      begin
        result:=TSymEntry(SymList.FindWithHash(s.id,s.hash));
      end;


    class function TSymTable.maybe_adjust_symname(const s:TSymStr):TSymStr;
      begin
        if s[1]='$' then
          result:=copy(s,2,maxidlen+1)
        else if length(s)>maxidlen then
          result:=upper(copy(s,1,maxidlen))
        else
          result:=upper(s);
      end;


{****************************************************************************
                            Symtable Stack
****************************************************************************}

    constructor TSymTableStack.create;
      begin
        stack:=nil;
      end;


    destructor TSymTableStack.Destroy;
      begin
        clear;
      end;


    procedure TSymTableStack.clear;
      var
        hp : PSymTableStackItem;
      begin
        while Assigned(stack) do
          begin
            hp:=stack;
            stack:=hp^.next;
            dispose(hp);
          end;
      end;

    function TSymTableStack.finditem(st: TSymTable): PSymTableStackItem;
      begin
        if not Assigned(stack) then
          InternalError(200601233);
        result:=stack;
        while Assigned(result)and(result^.SymTable<>st) do
          result:=result^.next;
      end;

    procedure TSymTableStack.push(st:TSymTable);
      var
        hp : PSymTableStackItem;
      begin
        new(hp);
        hp^.SymTable:=st;
        hp^.next:=stack;
        stack:=hp;
      end;

    procedure TSymTableStack.pushafter(st,afterst:TSymTable);
      var
        hp,afteritem: PSymTableStackItem;
      begin
        afteritem:=finditem(afterst);
        if Assigned(afteritem) then
          begin
            new(hp);
            hp^.SymTable:=st;
            hp^.next:=afteritem^.next;
            afteritem^.next:=hp;
          end
        else
          InternalError(201309171);
      end;

    procedure TSymTableStack.pop(st:TSymTable);
      var
        hp : PSymTableStackItem;
      begin
        if not Assigned(stack) then
          InternalError(200601231);
        if stack^.SymTable<>st then
          InternalError(200601232);
        hp:=stack;
        stack:=hp^.next;
        dispose(hp);
      end;


    procedure TSymTableStack.remove(st: TSymTable);
      { Remove st from anywhere in the stack.  If st appears more than once
        (which should not happen in normal operation) all occurrences are
        removed.  A missing st is silently ignored. }
      var
        prev, cur, nxt: PSymTableStackItem;
      begin
        prev:=nil;
        cur:=stack;
        while Assigned(cur) do
          begin
            nxt:=cur^.next;
            if cur^.SymTable=st then
              begin
                if Assigned(prev) then
                  prev^.next:=nxt
                else
                  stack:=nxt;
                dispose(cur);
                { do NOT update prev ? the item at prev is still valid }
              end
            else
              prev:=cur;
            cur:=nxt;
          end;
      end;


    function TSymTableStack.top:TSymTable;
      begin
        if not Assigned(stack) then
          InternalError(2006012304);
        result:=stack^.SymTable;
      end;


  function addstitemreverse(st: TSymTableStack; finalst: TSymTable; curitem: PSymTableStackItem): boolean;
    begin
      if not Assigned(curitem) then
        begin
          result:=true;
          exit;
        end;
      if addstitemreverse(st,finalst,curitem^.next) then
        begin
          st.push(curitem^.SymTable);
          result:=curitem^.SymTable<>finalst
        end
      else
        result:=false
    end;


  function TSymTableStack.getcopyuntil(finalst: TSymTable): TSymTableStack;
    begin
      result:=TSymTableStack.create;
      addstitemreverse(result,finalst,stack);
    end;


{$ifdef MEMDEBUG}
initialization
  memrealnames:=TMemDebug.create('Realnames');
  memrealnames.stop;

finalization
  memrealnames.free;
  memrealnames := nil;
{$endif MEMDEBUG}
end.
