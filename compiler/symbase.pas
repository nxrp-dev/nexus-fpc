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
       SymConst
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
         procedure SetId(const S:TIDString);
       public
         property Id:TIDString read FId write SetId;
         property Hash:LongWord read FHash;
       end;


{************************************************
                 TDefEntry
************************************************}

      TDefEntry = class
         Typ   : TDefTyp;
         DefID : LongInt;
         Owner : TSymTable;
      end;


{************************************************
                   TSymEntry
************************************************}

      { this object is the base for all symbol objects }
      TSymEntry = class(TFPHashObject)
      private
         FRealName : {$ifdef symansistr}TSymStr{$else}PShortString{$endif};
         function GetEscapedRealName: TSymStr;
         function  GetRealName: TSymStr;
         procedure SetRealName(const ANewName: TSymStr);
      public
         Typ   : TSymTyp;
         SymID : LongInt;
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
          Name      : PShortString;
          RealName  : PShortString;
          DefList   : TFPObjectList;
          SymList   : TFPHashObjectList;
          DefOwner  : TDefEntry; { for records and objects }
          ModuleID  : LongInt;
          RefCount  : SmallInt;
          CurrentVisibility : TVisibility;
          CurrentlyOptional : Boolean;
          TableOptions : TSymTableOptions;
          { level of symtable, used for nested procedures }
          SymTableLevel : Byte;
          { do not allow to add new definitions, can be extended to symbols probably }
          Sealed : Boolean;
          SymTableType  : TSymTableType;
          constructor Create(const S:string);
          { attention: only execute the a child's destructor if refcount is 1! }
          destructor  Destroy;override;
          procedure FreeInstance;override;
          function  GetCopy:TSymTable;
          procedure Clear;virtual;
          function  CheckDuplicate(var S:THashedIDString;Sym:TSymEntry):Boolean;virtual;
          procedure InsertSym(Sym:TSymEntry;CheckDup:Boolean=True);virtual;
          procedure DeleteSym(Sym:TSymEntry);virtual;
          function  Find(const S:TIDString) : TSymEntry;
          function  FindWithHash(const S:THashedIDString) : TSymEntry;virtual;
          procedure InsertDef(Def:TDefEntry);virtual;
          procedure DeleteDef(Def:TDefEntry);
          function  IsCurrentUnit:Boolean;virtual;
          { includes the flag in this symtable and all parent symtables; if
            it's already set the flag is not set again }
          procedure IncludeOption(Option:TSymTableOption);
          class function Maybe_Adjust_SymName(const S:TSymStr):TSymStr;
       end;

       PSymTableStackItem = ^TSymTableStackItem;
       TSymTableStackItem = record
         SymTable : TSymTable;
         SavedModuleID : LongInt;
         Next     : PSymTableStackItem;
       end;

       TSymTableStack = class
         Stack : PSymTableStackItem;
         constructor Create;
         destructor Destroy;override;
         procedure Clear;
         function FindItem(ST:TSymTable):PSymTableStackItem;
         procedure Push(ST:TSymTable); virtual;
         procedure PushAfter(ST,AfterST:TSymTable); virtual;
         procedure Pop(ST:TSymTable); virtual;
         { Remove st from anywhere in the stack without raising an error if
           it is not present.  Used by the CTask PPU-cycle fix to excise a
           symtable that is about to be freed (via tmodule.reset) from a
           suspended module's saved symtablestack before RestoreState runs. }
         procedure Remove(ST:TSymTable);
         function  Top:TSymTable;
         function GetCopyUntil(FinalST: TSymTable): TSymTableStack;
       end;


    var
       InitialMacroSymTable: TSymTable;   { macros initially defined by the compiler or
                                            given on the command line. Is common
                                            for all files compiled and do not change. }
       MacroSymTableStack,
       SymTableStack        : TSymTableStack;

{$ifdef MEMDEBUG}
    var
      MemRealNames : TMemDebug;
{$endif MEMDEBUG}


implementation

    uses
       Verbose;

{****************************************************************************
                              THashedIDString
****************************************************************************}

    procedure THashedIDString.SetId(const S:TIDString);
      begin
        FId:=S;
{$ifdef symansistr}
        if Length(FId)>MaxIDLen then
          SetLength(FId,MaxIDLen);
{$endif}
        FHash:=FPHash(FId);
      end;


{****************************************************************************
                                TSymEntry
****************************************************************************}

    destructor TSymEntry.Destroy;
      begin
{$ifdef MEMDEBUG}
        MemRealNames.Start;
{$endif MEMDEBUG}
{$ifndef symansistr}
        StringDispose(FRealName);
{$endif}
{$ifdef MEMDEBUG}
        MemRealNames.Stop;
{$endif MEMDEBUG}
        inherited Destroy;
      end;


    function TSymEntry.GetRealName:TSymStr;
      begin
{$ifndef symansistr}
        if not Assigned(FRealName) then
          InternalError(200611011);
        Result:=FRealName^;
{$else}
       if FRealName='' then
         InternalError(200611011);
       Result:=FRealName;
{$endif}
      end;


    function TSymEntry.GetEscapedRealName: TSymStr;
      begin
        Result:=GetRealName;
        if Result=Name then
          Result:='$'+Result;
      end;


    procedure TSymEntry.SetRealName(const ANewName:TSymStr);
      begin
{$ifndef symansistr}
        StringDispose(FRealName);
        FRealName:=StringDup(ANewName);
{$else}
        FRealName:=ANewName;
{$endif}
        if Hash<>$ffffffff then
          begin
            if ANewName[1]='$' then
              Rename(Copy(ANewName,2,Length(ANewName)))
            else
              Rename(Upper(ANewName));
          end;
      end;


{****************************************************************************
                                TSymtable
****************************************************************************}

    constructor TSymTable.Create(const S:string);
      begin
         if S<>'' then
           begin
             Name:=StringDup(Upper(S));
             RealName:=StringDup(S);
           end
         else
           begin
             Name:=nil;
             RealName:=nil;
           end;
         SymTableType:=AbstractSymTable;
         SymTableLevel:=0;
         DefOwner:=nil;
         DefList:=TFPObjectList.Create(True);
         SymList:=TFPHashObjectList.Create(True);
         RefCount:=1;
         CurrentVisibility:=vis_public;
         CurrentlyOptional:=False;
      end;


    destructor TSymTable.Destroy;
      begin
        { freeinstance decreases refcount }
        if RefCount>1 then
          Exit;
        Clear;
        DefList.Free;
        DefList := nil;
        { SymList can already be disposed or set to nil for withsymtable, }
        { but in that case Free does nothing                              }
        SymList.Free;
        SymList := nil;
        StringDispose(Name);
        StringDispose(RealName);
      end;


    procedure TSymTable.FreeInstance;
      begin
        Dec(RefCount);
        if RefCount=0 then
          inherited FreeInstance;
      end;


    function TSymTable.GetCopy:TSymTable;
      begin
        Inc(RefCount);
        Result:=Self;
      end;


    function TSymTable.IsCurrentUnit:Boolean;
      begin
        Result:=False;
      end;

    procedure TSymTable.IncludeOption(Option: TSymTableOption);
      var
        ST: TSymTable;
      begin
        if Option in TableOptions then
          Exit;
        Include(TableOptions,Option);
        { iterative approach should be faster than recursion based on calls }
        ST:=Self;
        while Assigned(ST.DefOwner) do
          begin
            ST:=ST.DefOwner.Owner;
            { this can happen for specializations of routines that are not yet
              owned cause they might be thrown away again }
            if not Assigned(ST) then
              Break;
            { the flag is already set, so by definition it is set in the
              owning symtables as well }
            if Option in ST.TableOptions then
              Break;
            Include(ST.TableOptions,Option);
          end;
      end;


    procedure TSymTable.Clear;
      var
        I : Integer;
      begin
         SymList.Clear;
         { Prevent recursive calls between TDef.destroy and TSymtable.Remove }
         if DefList.OwnsObjects then
           begin
             for I := 0 to DefList.Count-1 do
               TDefEntry(DefList[I]).Owner:=nil;
           end;
         DefList.Clear;
      end;


    function TSymTable.CheckDuplicate(var S:THashedIDString;Sym:TSymEntry):Boolean;
      begin
        Result:=(FindWithHash(S)<>nil);
      end;


    procedure TSymTable.InsertSym(Sym:TSymEntry;CheckDup:Boolean=True);
      var
        HashedID : THashedIDString;
        S : TSymStr;
      begin
         S:=Maybe_Adjust_SymName(Sym.RealName);
         if CheckDup then
           begin
             HashedID.Id:=S;
             { First check for duplicates, this can change the symbol name
               in case of a duplicate entry }
             if CheckDuplicate(HashedID,Sym) then
               S:=Maybe_Adjust_SymName(Sym.RealName);
           end;
         { Now we can insert the symbol, any duplicate entries
           are renamed to an unique (and for users inaccessible) name }
         if CheckDup then
           begin
             if HashedID.Id<>S then
               HashedID.Id:=S;
             Sym.ChangeOwnerAndNameWithHash(SymList,S,HashedID.Hash);
           end
         else
           Sym.ChangeOwnerAndName(SymList,S);
         Sym.Owner:=Self;
      end;


    procedure TSymTable.DeleteSym(Sym:TSymEntry);
      begin
        if Sym.Owner<>Self then
          InternalError(200611121);
        SymList.Remove(Sym);
      end;


    procedure TSymTable.InsertDef(Def:TDefEntry);
      begin
         DefList.Add(Def);
         Def.Owner:=Self;
      end;


    procedure TSymTable.DeleteDef(Def:TDefEntry);
      begin
        if Def.Owner<>Self then
          InternalError(200611122);
        Def.Owner:=nil;
        DefList.Remove(Def);
      end;


    function TSymTable.Find(const S : TIDString) : TSymEntry;
      begin
        Result:=TSymEntry(SymList.Find(S));
      end;


    function TSymTable.FindWithHash(const S:THashedIDString) : TSymEntry;
      begin
        Result:=TSymEntry(SymList.FindWithHash(S.Id,S.Hash));
      end;


    class function TSymTable.Maybe_Adjust_SymName(const S:TSymStr):TSymStr;
      begin
        if S[1]='$' then
          Result:=Copy(S,2,MaxIDLen+1)
        else if Length(S)>MaxIDLen then
          Result:=Upper(Copy(S,1,MaxIDLen))
        else
          Result:=Upper(S);
      end;


{****************************************************************************
                            Symtable Stack
****************************************************************************}

    constructor TSymTableStack.Create;
      begin
        Stack:=nil;
      end;


    destructor TSymTableStack.Destroy;
      begin
        Clear;
      end;


    procedure TSymTableStack.Clear;
      var
        HP : PSymTableStackItem;
      begin
        while Assigned(Stack) do
          begin
            HP:=Stack;
            Stack:=HP^.Next;
            Dispose(HP);
          end;
      end;

    function TSymTableStack.FindItem(ST: TSymTable): PSymTableStackItem;
      begin
        if not Assigned(Stack) then
          InternalError(200601233);
        Result:=Stack;
        while Assigned(Result)and(Result^.SymTable<>ST) do
          Result:=Result^.Next;
      end;

    procedure TSymTableStack.Push(ST:TSymTable);
      var
        HP : PSymTableStackItem;
      begin
        New(HP);
        HP^.SymTable:=ST;
        HP^.Next:=Stack;
        Stack:=HP;
      end;

    procedure TSymTableStack.PushAfter(ST,AfterST:TSymTable);
      var
        HP,AfterItem: PSymTableStackItem;
      begin
        AfterItem:=FindItem(AfterST);
        if Assigned(AfterItem) then
          begin
            New(HP);
            HP^.SymTable:=ST;
            HP^.Next:=AfterItem^.Next;
            AfterItem^.Next:=HP;
          end
        else
          InternalError(201309171);
      end;

    procedure TSymTableStack.Pop(ST:TSymTable);
      var
        HP : PSymTableStackItem;
      begin
        if not Assigned(Stack) then
          InternalError(200601231);
        if Stack^.SymTable<>ST then
          InternalError(200601232);
        HP:=Stack;
        Stack:=HP^.Next;
        Dispose(HP);
      end;


    procedure TSymTableStack.Remove(ST: TSymTable);
      { Remove st from anywhere in the stack.  If st appears more than once
        (which should not happen in normal operation) all occurrences are
        removed.  A missing st is silently ignored. }
      var
        Prev, Cur, Nxt: PSymTableStackItem;
      begin
        Prev:=nil;
        Cur:=Stack;
        while Assigned(Cur) do
          begin
            Nxt:=Cur^.Next;
            if Cur^.SymTable=ST then
              begin
                if Assigned(Prev) then
                  Prev^.Next:=Nxt
                else
                  Stack:=Nxt;
                Dispose(Cur);
                { do NOT update prev ? the item at prev is still valid }
              end
            else
              Prev:=Cur;
            Cur:=Nxt;
          end;
      end;


    function TSymTableStack.Top:TSymTable;
      begin
        if not Assigned(Stack) then
          InternalError(2006012304);
        Result:=Stack^.SymTable;
      end;


  function AddSTItemReverse(ST: TSymTableStack; FinalST: TSymTable; CurItem: PSymTableStackItem): Boolean;
    begin
      if not Assigned(CurItem) then
        begin
          Result:=True;
          Exit;
        end;
      if AddSTItemReverse(ST,FinalST,CurItem^.Next) then
        begin
          ST.Push(CurItem^.SymTable);
          Result:=CurItem^.SymTable<>FinalST
        end
      else
        Result:=False
    end;


  function TSymTableStack.GetCopyUntil(FinalST: TSymTable): TSymTableStack;
    begin
      Result:=TSymTableStack.Create;
      AddSTItemReverse(Result,FinalST,Stack);
    end;


{$ifdef MEMDEBUG}
initialization
  MemRealNames:=TMemDebug.Create('Realnames');
  MemRealNames.Stop;

finalization
  MemRealNames.Free;
  MemRealNames := nil;
{$endif MEMDEBUG}
end.
