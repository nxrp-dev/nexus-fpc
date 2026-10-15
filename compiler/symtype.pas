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
unit symtype;

{$i fpcdefs.inc}

interface

    uses
      { common }
      CUtils,
      CClasses,
      { global }
      GlobType,Globals,ConstExp,
      { symtable }
      symconst,SymBase,
      { aasm }
      aasmbase,ppu,
      FinPut
      ;

    type
{************************************************
                Required Forwards
************************************************}

      TSym = class;
      TCompilerPPUFile=class;


{************************************************
                     TDef
************************************************}

      TGetSymTable = (gs_none,gs_record,gs_local,gs_para);
      TPublishProperty = (pp_ignore, pp_error, pp_publish);

      TDef = class(TDefEntry)
        protected
         { whether this def is already registered in the unit's def list }
         function registered : boolean;
         { initialize the defid field; only call from a constructor as it threats
           0 as an invalid value! }
         procedure InitDefID;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintDefTree(var T: Text; Sym: TSym); virtual;
         procedure XMLPrintDefInfo(var T: Text; Sym: TSym); dynamic;
         procedure XMLPrintDefData(var T: Text; Sym: TSym); virtual;
         function XMLPrintType: AnsiString; virtual;
{$endif DEBUG_NODE_XML}
        public
         registered_in_module : TModuleBase;
         typesym    : TSym;  { which type the definition was generated this def }
         { stabs debugging }
         stab_number : word;
         dbg_state   : TDefDbgStatus;
         defoptions  : TDefOptions;
         defstates   : TDefStates;
         constructor create(dt:TDefTyp);
         destructor Destroy; override;
         procedure buildderef;virtual;abstract;
         procedure buildderefimpl;virtual;abstract;
         procedure deref;virtual;abstract;
         procedure derefimpl;virtual;abstract;
         function  typename:string;
         function  fulltypename:string;
         function  GetTypeName:string;virtual;
         function  typesymbolprettyname:string;virtual;
         function  mangledparaname:string;
         function  getmangledparaname:TSymStr;virtual;
         function  RTTIMangledName(rt:TRTTIType):TSymStr;virtual;abstract;
         function  OwnerHierarchyName: string; virtual; abstract;
         function  OwnerHierarchyPrettyName: string; virtual; abstract;
         function  fullownerhierarchyname(skipprocparams:boolean;use_pretty : boolean):TSymStr;virtual;abstract;
         function  UniqueIDStr: string;
         function  size:asizeint;virtual;abstract;
         function  packedbitsize:asizeint;virtual;
         function  alignment:shortint;virtual;abstract;
         { alignment when this type appears in a record/class/... }
         function  structalignment:shortint;virtual;
         function  aggregatealignment:shortint;virtual;
         function  getvardef:LongInt;virtual;abstract;
         function  getparentdef:TDef;virtual;
         function  getsymtable(t:TGetSymTable):TSymTable;virtual;
         function  IsPublishable:TPublishProperty;virtual;abstract;
         function  NeedsInitTable:boolean;virtual;abstract;
         { contains a (managed) child that is not initialized to 0/Nil }
         function  HasNonTrivialInitChild(check_parent:boolean):boolean;virtual;abstract;
         function  NeedsSeparateInitRTTI:boolean;virtual;abstract;
         procedure ChangeOwner(st:TSymTable);
         function getreusablesymtab: TSymTable;
         procedure RegisterCreatedObjectType;virtual;
         function  GetTopLevelSymTable(skipprocdefs: boolean): TSymTable;
         { only valid for registered defs and defs for which a unique id string
           has been requested; otherwise, first call register_def }
         function  DefListIndex: LongInt;
         procedure RegisterDef; virtual; abstract;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintDef(Sym: TSym);
{$endif DEBUG_NODE_XML}
         property IsRegistered: boolean read registered;
      end;

{************************************************
                     TSym
************************************************}

      { this object is the base for all symbol objects }
      TSym = class(TSymEntry)
      protected
       function registered : boolean;
      public
         fileinfo   : TFilePosInfo;
         { size of fileinfo is 10 bytes, so if a >word aligned type would follow,
           two bytes of memory would be wasted, so we put two one byte fields over here }
         visibility : TVisibility;
         isdbgwritten : boolean;
         symoptions : TSymOptions;
         refs       : LongInt;
         reflist    : TLinkedList;
         { deprecated optionally can have a message }
         deprecatedmsg: PShortString;
         constructor create(st:TSymTyp;const aname:string);
         destructor  Destroy;override;
         function  mangledname:TSymStr; virtual;
         function  prettyname:string; virtual;
         procedure buildderef;virtual;
         procedure deref;virtual;
         procedure ChangeOwner(st:TSymTable);
         procedure ChangeOwnerAndName(st:TSymTable;const aname:TSymStr);
         procedure IncRefCount;
         procedure IncRefCountBy(AValue : LongInt);
         procedure MaybeCreateRefList;
         procedure AddRef;
         procedure RegisterSym; virtual; abstract;
         property IsRegistered:boolean read registered;
      end;

      TSymArr = array[0..maxlongint div sizeof(pointer)-1] of TSym;
      PSymArr = ^TSymArr;

{************************************************
                   TDeref
************************************************}

      TDeref = record
        dataidx : LongInt;
        procedure reset;
        procedure build(s:TObject);
        function  resolve:TObject;
     end;
     PDeref = ^TDeref;

{************************************************
                   tpropaccesslist
************************************************}

      PPropAccessListItem = ^TPropAccessListItem;
      TPropAccessListItem = record
        sltype : TSLType;
        next   : PPropAccessListItem;
        case byte of
          0 : (sym : TSym; symderef : TDeref);
          1 : (value  : TConstExprInt; valuedef: TDef; valuedefderef:TDeref);
          2 : (def: TDef; defderef:TDeref);
      end;

      TPropAccessList = class
        procdef  : TDef;
        procdefderef : TDeref;
        firstsym,
        lastsym  : PPropAccessListItem;
        constructor create;
        destructor  Destroy;override;
        function  empty:boolean;
        function getcopy: TPropAccessList;
        procedure addsym(slt:TSLType;p:TSym);
        procedure addconst(slt:TSLType;const v:TConstExprInt;d:TDef);
        procedure addtype(slt:TSLType;d:TDef);
        procedure addsymderef(slt:TSLType;d:TDeref);
        procedure addconstderef(slt:TSLType;const v:TConstExprInt;d:TDeref);
        procedure addtypederef(slt:TSLType;d:TDeref);
        procedure clear;
        procedure resolve;
        procedure buildderef;
      end;

{************************************************
                Tcompilerppufile
************************************************}
       TCompilerPPUFile=class(TPPUFile)
       public
         procedure checkerror;
         procedure getguid(var g: TGUID);
         function  getexprint:TConstExprInt;
         procedure getposinfo(var p:TFilePosInfo);
         procedure getderef(var d:TDeref);
         function  getpropaccesslist:TPropAccessList;
         function  getasmsymbol:TAsmSymbol;
         procedure putguid(const g: TGUID);
         procedure putexprint(const v:TConstExprInt);
         procedure putposinfo(const p:TFilePosInfo);
         procedure putderef(const d:TDeref);
         procedure putpropaccesslist(p:TPropAccessList);
         procedure putasmsymbol(s:TAsmSymbol);
       protected
         procedure RaiseAssertion(Code: LongInt); override;
       end;

{$ifdef MEMDEBUG}
    var
      memmanglednames,
      memprocpara,
      memprocparast,
      memproclocalst,
      memprocnodetree : TMemDebug;
{$endif MEMDEBUG}

    function  FindUnitSymtable(st:TSymTable):TSymTable;


implementation

    uses
       crefs,
       Verbose,
       FModule
       ;

{****************************************************************************
                                Utils
****************************************************************************}

    function FindUnitSymtable(st:TSymTable):TSymTable;
      begin
        result:=nil;
        repeat
          if not Assigned(st) then
           InternalError(200602034);
          case st.symtabletype of
            localmacrosymtable,
            exportedmacrosymtable,
            staticsymtable,
            GlobalSymTable :
              begin
                result:=st;
                exit;
              end;
            exceptsymtable,
            recordsymtable,
            enumsymtable,
            arraysymtable,
            localsymtable,
            parasymtable,
            ObjectSymtable :
              st:=st.defowner.owner;
            else
              InternalError(200602035);
          end;
        until false;
      end;


{****************************************************************************
                                Tdef
****************************************************************************}

    function TDef.registered: boolean;
      begin
        result:=defid>defid_not_registered;
      end;


    procedure TDef.InitDefID;
      begin
        if defid=0 then
          defid:=defid_not_registered;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TDef.XMLPrintDefTree(var T: Text; Sym: TSym);
      begin
        Write(T, PrintNodeIndention, '<definition');
        XMLPrintDefInfo(T, Sym);
        WriteLn(T, '>');
        PrintNodeIndent;
        { Printing the type here instead of in XMLPrintDefData ensures it
          always appears first no matter how XMLPrintDefData is overridden }
        WriteLn(T, PrintNodeIndention, '<type>', XMLPrintType, '</type>');
        XMLPrintDefData(T, Sym);
        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</definition>');
        WriteLn(T, PrintNodeIndention);
      end;


    procedure TDef.XMLPrintDefInfo(var T: Text; Sym: TSym);
      var
        i: TSymOption;
        first: Boolean;
      begin
        { Note that if we've declared something like "INT = Integer", the
          INT name gets lost in the system and 'typename' just returns
          Integer, so the correct details can be found via Sym }
        Write(T, ' name="', SanitiseXMLString(Sym.RealName),
          '" pos="', Sym.fileinfo.line, ',', Sym.fileinfo.column);

        First := True;
        for i := Low(TSymOption) to High(TSymOption) do
          if i in Sym.symoptions then
            begin
              if First then
                begin
                  Write(T, '" symoptions="', i);
                  First := False;
                end
              else
                Write(T, ',', i)
            end;

        Write(T, '"');
      end;


    procedure TDef.XMLPrintDefData(var T: Text; Sym: TSym);
      begin
        WriteLn(T, PrintNodeIndention, '<size>', size, '</size>');

        if (alignment = structalignment) and (alignment = aggregatealignment) then
          begin
            { Straightforward and simple }
            WriteLn(T, PrintNodeIndention, '<alignment>', alignment, '</alignment>');
          end
        else
          begin
            WriteLn(T, PrintNodeIndention, '<alignment>');
            PrintNodeIndent;
            WriteLn(T, PrintNodeIndention, '<basic>', alignment, '</basic>');

            if (structalignment <> alignment) then
              WriteLn(T, PrintNodeIndention, '<struct>', structalignment, '</struct>');

            if (aggregatealignment <> alignment) and (aggregatealignment <> structalignment) then
              WriteLn(T, PrintNodeIndention, '<aggregate>', aggregatealignment, '</aggregate>');

            PrintNodeUnindent;
            WriteLn(T, PrintNodeIndention, '</alignment>');
          end;
      end;


    function TDef.XMLPrintType: AnsiString;
      begin
        Result := SanitiseXMLString(GetTypeName);
      end;

{$endif DEBUG_NODE_XML}

    constructor TDef.create(dt:TDefTyp);
      begin
         inherited create;
         typ:=dt;
         owner := nil;
         typesym := nil;
         defoptions:=[];
         dbg_state:=dbg_state_unused;
         stab_number:=0;
         InitDefID;
      end;


    destructor TDef.Destroy;
      begin
        { set self to nil in registered_in_module's deflist, if the def has been
          registered, in order to avoid dangling pointers in registered_in_module.deflist }
        if Assigned(registered_in_module) then
          begin
           if defid>=0 then
             TModule(registered_in_module).deflist[defid]:=nil
           else if defid<defid_not_registered then
             TModule(registered_in_module).deflist[-(defid-defid_not_registered+1)]:=nil
           else
             InternalError(2021060101);
          end;
        inherited;
      end;


    function TDef.typename:string;
      begin
        result:=OwnerHierarchyName;
        if Assigned(typesym) and
           not(typ in [procvardef,procdef]) and
           (typesym.realname[1]<>'$') then
          result:=result+typesym.realname
        else
          result:=result+GetTypeName;
      end;


    function TDef.fulltypename:string;
      begin
        result:=fullownerhierarchyname(false,false);
        if Assigned(typesym) and
           not(typ in [procvardef,procdef]) and
           (typesym.realname[1]<>'$') then
          result:=result+typesym.realname
        else
          result:=result+GetTypeName;
      end;


    function TDef.GetTypeName : string;
      begin
         GetTypeName:='<unknown type>'
      end;


    function TDef.typesymbolprettyname:string;
      begin
        result:=OwnerHierarchyPrettyName;
        if Assigned(typesym) then
          result:=result+typesym.prettyname
        else
          result:=result+'<no type symbol>';
      end;


    function TDef.mangledparaname:string;
      begin
        result:=OwnerHierarchyName;
        if Assigned(typesym) then
          mangledparaname:=result+typesym.name
        else
          mangledparaname:=result+getmangledparaname;
      end;


    function TDef.getmangledparaname:TSymStr;
      begin
         result:='<unknown type>';
      end;


    function TDef.UniqueIDStr: string;
      begin
        if (defid=defid_not_registered) or
           (defid=defid_registered_nost) then
          begin
            if not Assigned(CurrentModule) then
              InternalError(2015102505);
            CurrentModule.deflist.Add(self);
            registered_in_module:=CurrentModule;
            { invert the defid to indicate that it was only set because we
              needed a unique number -- then add defid_not_registered so we
              don't get the values between defid_registered and 0 }
            defid:=-(CurrentModule.deflist.Count-1)+defid_not_registered-1;
          end;
        { use deflist_index so that it will remain the same if def first gets a
          defid just for the unique id (as above) and later it gets registered
          because it must be saved to the ppu }
        result:=HexStr(DefListIndex,sizeof(defid)*2);
      end;


    function TDef.getparentdef:TDef;
      begin
        result:=nil;
      end;


    function TDef.getsymtable(t:TGetSymTable):TSymTable;
      begin
        result:=nil;
      end;


    function TDef.packedbitsize:asizeint;
      begin
        result:=size * 8;
      end;


    function TDef.structalignment: shortint;
      begin
        result:=alignment;
      end;

    function TDef.aggregatealignment: shortint;
      begin
        if Assigned(Owner) and Assigned(Owner.defowner) and (Owner.defowner is TDef) and (Owner.defowner <> Self) then
          Result := max(structalignment, TDef(Owner.defowner).aggregatealignment)
        else
          Result := structalignment;
      end;


    procedure TDef.ChangeOwner(st:TSymTable);
      begin
        if Assigned(Owner) and owner.deflist.OwnsObjects then
          Owner.DefList.extract(self);
        Owner:=st;
        Owner.DefList.Add(self);
      end;


    function TDef.getreusablesymtab: TSymTable;
      var
        origowner: TSymTable;
      begin
        { if the original def was in a localsymtable, don't create a
          reusable copy in the unit's staticsymtable since the localsymtable
          won't be saved to the ppu and as a result we can get unreachable
          defs when reloading the derived ones from the ppu }
        origowner:=owner;
        while not(origowner.symtabletype in [localsymtable,staticsymtable,GlobalSymTable,exceptsymtable]) do
          origowner:=origowner.defowner.owner;
        { if the def is in an exceptionsymtable, we can't create a reusable
          def because the original one will be freed when the (always
          temporary) exceptionsymtable is freed }
        if origowner.symtabletype=exceptsymtable then
          InternalError(2015111701)
        else if origowner.symtabletype=localsymtable then
          result:=origowner
        else if Assigned(CurrentModule.localsymtable) then
          result:=CurrentModule.localsymtable
        else
          result:=CurrentModule.GlobalSymTable;
      end;


    procedure TDef.RegisterCreatedObjectType;
      begin
      end;


    function TDef.GetTopLevelSymTable(skipprocdefs: boolean): TSymTable;
      begin
        result:=owner;
        while Assigned(result) and
              Assigned(result.defowner) and
              (skipprocdefs or (result.symtabletype in [ObjectSymtable,recordsymtable])) do
          result:=TDef(result.defowner).owner;
      end;


    function TDef.DefListIndex: LongInt;
      begin
        if defid<defid_not_registered then
          result:=-(defid-defid_not_registered+1)
        else if defid>=0 then
          result:=defid
        else
          InternalError(2015102502)
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TDef.XMLPrintDef(Sym: TSym);
      var
        T: Text;

      begin
        if CurrentModule.PPXFileFail then
          Exit;

        Assign(T, CurrentModule.PPXFileName);
        {$push} {$I-}
        Append(T);
        if IOResult <> 0 then
          begin
            Message1(exec_e_cant_create_archivefile,CurrentModule.PPXFileName);
            CurrentModule.PPXFileFail := True;
            Exit;
          end;
        {$pop}

        XMLPrintDefTree(T, Sym);
        Close(T);
      end;

{$endif DEBUG_NODE_XML}


{****************************************************************************
                          TSYM (base for all symtypes)
****************************************************************************}

    function TSym.registered: boolean;
      begin
        result:=symid>symid_not_registered;
      end;


    constructor TSym.create(st:TSymTyp;const aname:string);
      begin
         inherited CreateNotOwned;
         realname:=aname;
         typ:=st;
         RefList:=nil;
         symoptions:=[];
         fileinfo:=CurrentTokenPos;
         isdbgwritten := false;
         visibility:=vis_public;
         deprecatedmsg:=nil;
         symid:=symid_not_registered;
      end;

    destructor  TSym.Destroy;
      begin
        StringDispose(deprecatedmsg);
        RefList.Free;
        RefList := nil;
        inherited Destroy;
      end;

    procedure TSym.IncRefCount;
      begin
        inc(refs);
        if cs_browser in CurrentSettings.ModuleSwitches then
          begin
            MaybeCreateRefList;
            AddRef;
          end;
      end;

    procedure TSym.IncRefCountBy(AValue : LongInt);
      begin
        inc(refs,AValue);
      end;

    procedure TSym.MaybeCreateRefList;
      begin
        if not Assigned(reflist) then
          reflist:=TRefLinkedList.create;
      end;

    procedure TSym.AddRef;
      var
        RefItem: TRefItem;
      begin
        RefItem:=TRefItem.Create(CurrentTokenPos);
        RefList.Concat(RefItem);
      end;

    procedure TSym.buildderef;
      begin
      end;


    procedure TSym.deref;
      begin
      end;


    function TSym.mangledname : TSymStr;
      begin
        InternalError(200204171);
        result:='';
      end;


    function TSym.prettyname : string;
      var
       i: SizeInt;
      begin
        result:=realname;
        { strip type parameters in the name separated by '$' }
        i:=pos('$',result);
        if i>0 then
          delete(result,i,MaxInt);
      end;


    procedure TSym.ChangeOwner(st:TSymTable);
      begin
        if Assigned(owner) and owner.SymList.OwnsObjects then
          owner.symlist.extract(self);
        Owner:=st;
        inherited ChangeOwner(Owner.SymList);
      end;


    procedure TSym.ChangeOwnerAndName(st:TSymTable;const aname:TSymStr);
      begin
        if Assigned(owner) and owner.SymList.OwnsObjects then
          owner.symlist.extract(self);
        Owner:=st;
        inherited ChangeOwnerAndName(Owner.SymList,aname);
      end;


{****************************************************************************
                                 tpropaccesslist
****************************************************************************}

    constructor TPropAccessList.create;
      begin
        procdef:=nil; { needed for procedures }
        firstsym:=nil;
        lastsym:=nil;
      end;


    destructor TPropAccessList.Destroy;
      begin
        clear;
      end;


    function TPropAccessList.empty:boolean;
      begin
        empty:=(firstsym=nil);
      end;

    function TPropAccessList.getcopy: TPropAccessList;
      var
        hp, dest : PPropAccessListItem;
      begin
        result:=TPropAccessList.create;
        result.procdef:=procdef;
        hp:=firstsym;
        while Assigned(hp) do
          begin
            new(dest);
            dest^:=hp^;
            dest^.next:=nil;
            if not Assigned(result.firstsym) then
              result.firstsym:=dest;
            if Assigned(result.lastsym) then
              result.lastsym^.next:=dest;
            result.lastsym:=dest;
            hp:=hp^.next;
          end;
      end;


    procedure TPropAccessList.clear;
      var
        hp : PPropAccessListItem;
      begin
        while Assigned(firstsym) do
         begin
           hp:=firstsym;
           firstsym:=firstsym^.next;
           dispose(hp);
         end;
        firstsym:=nil;
        lastsym:=nil;
        procdef:=nil;
      end;


    procedure TPropAccessList.addsym(slt:TSLType;p:TSym);
      var
        hp : PPropAccessListItem;
      begin
        new(hp);
        fillchar(hp^,sizeof(TPropAccessListItem),0);
        hp^.sltype:=slt;
        hp^.sym:=p;
        hp^.symderef.reset;
        if Assigned(lastsym) then
         lastsym^.next:=hp
        else
         firstsym:=hp;
        lastsym:=hp;
      end;


    procedure TPropAccessList.addconst(slt:TSLType;const v:TConstExprInt;d:TDef);
      var
        hp : PPropAccessListItem;
      begin
        new(hp);
        fillchar(hp^,sizeof(TPropAccessListItem),0);
        hp^.sltype:=slt;
        hp^.value:=v;
        hp^.valuedef:=d;
        hp^.valuedefderef.reset;
        if Assigned(lastsym) then
         lastsym^.next:=hp
        else
         firstsym:=hp;
        lastsym:=hp;
      end;


    procedure TPropAccessList.addtype(slt:TSLType;d:TDef);
      var
        hp : PPropAccessListItem;
      begin
        new(hp);
        fillchar(hp^,sizeof(TPropAccessListItem),0);
        hp^.sltype:=slt;
        hp^.def:=d;
        hp^.defderef.reset;
        if Assigned(lastsym) then
         lastsym^.next:=hp
        else
         firstsym:=hp;
        lastsym:=hp;
      end;


    procedure TPropAccessList.addsymderef(slt:TSLType;d:TDeref);
      begin
        addsym(slt,nil);
        lastsym^.symderef:=d;
      end;


    procedure TPropAccessList.addconstderef(slt:TSLType;const v:TConstExprInt;d:TDeref);
      begin
        addconst(slt,v,nil);
        lastsym^.valuedefderef:=d;
      end;


    procedure TPropAccessList.addtypederef(slt:TSLType;d:TDeref);
      begin
        addtype(slt,nil);
        lastsym^.defderef:=d;
      end;


    procedure TPropAccessList.resolve;
      var
        hp : PPropAccessListItem;
      begin
        procdef:=TDef(procdefderef.resolve);
        hp:=firstsym;
        while Assigned(hp) do
         begin
           case hp^.sltype of
             sl_call,
             sl_load,
             sl_subscript :
               hp^.sym:=TSym(hp^.symderef.resolve);
             sl_absolutetype,
             sl_typeconv :
               hp^.def:=TDef(hp^.defderef.resolve);
             sl_vec:
               hp^.valuedef:=TDef(hp^.valuedefderef.resolve);
             else
              InternalError(2001102001);
           end;
           hp:=hp^.next;
         end;
      end;


    procedure TPropAccessList.buildderef;
      var
        hp : PPropAccessListItem;
      begin
        procdefderef.build(procdef);
        hp:=firstsym;
        while Assigned(hp) do
         begin
           case hp^.sltype of
             sl_call,
             sl_load,
             sl_subscript :
               hp^.symderef.build(hp^.sym);
             sl_absolutetype,
             sl_typeconv :
               hp^.defderef.build(hp^.def);
             sl_vec:
               hp^.valuedefderef.build(hp^.valuedef);
             else
              InternalError(2001102002);
           end;
           hp:=hp^.next;
         end;
      end;


{****************************************************************************
                                Tderef
****************************************************************************}


    procedure TDeref.reset;
      begin
        dataidx:=-1;
      end;


    procedure TDeref.build(s:TObject);

       procedure do_internal_error(i : integer);noreturn;
       // local proc so we do not have an implicit try..finally in the build proc.
       var
         msg : AnsiString;
       begin
         if Assigned(s) then
           msg:=S.ToString
         else
           msg:='Nil object';
         InternalError(i,'Cannot build:'+msg);
       end;

      var
        len  : byte;
        st   : TSymTable;
        data : array[0..255] of byte;
        idx : word;

      begin
        { skip length byte }
        len:=1;
        if Assigned(s) then
         begin
{ TODO: ugly hack}
           if s is TSym then
             begin
               { if it has been registered but it wasn't put in a symbol table,
                 this symbol shouldn't be written to a ppu }
               if TSym(s).SymId=symid_registered_nost then
                 do_internal_error(2015102504);
               if not TSym(s).registered then
                 TSym(s).RegisterSym;
               st:=FindUnitSymtable(TSym(s).owner)
             end
           else if s is TDef then
             begin
               { same as above }
               if TDef(s).defid=defid_registered_nost then
                 do_internal_error(2015102501);
               if TDef(s).typ=errordef then
                 do_internal_error(2024011501);
               if not TDef(s).registered then
                 TDef(s).RegisterDef;
               st:=FindUnitSymtable(TDef(s).owner);
             end
           else
             // Unknown object type
             do_internal_error(2016090204);
           if not st.iscurrentunit then
             begin
               { register that the unit is needed for resolving }
               data[len]:=ord(deref_unit);
               idx:=CurrentModule.derefidx_unit(st.ModuleID);
               unaligned(PUint16(@data[len+1{..len+2}])^):=NtoBE(uint16(idx));
               inc(len,3);
             end;
           if s is TSym then
             begin
               data[len]:=ord(deref_symid);
               unaligned(PInt32(@data[len+1{..len+4}])^):=NtoBE(int32(TSym(s).symid));
               inc(len,5);
             end
           else
             begin
               data[len]:=ord(deref_defid);
               unaligned(PInt32(@data[len+1{..len+4}])^):=NtoBE(int32(TDef(s).defid));
               inc(len,5);
             end;
         end
        else
         begin
           { nil pointer }
           data[len]:=ord(deref_nil);
           inc(len);
         end;

        { store data length in first byte }
        data[0]:=len-1;

        { store index and write to derefdata }
        dataidx:=CurrentModule.derefdata.size;
        CurrentModule.derefdata.write(data,len);
      end;


    function TDeref.resolve:TObject;
      var
        pm     : TModule;
        typ    : TDerefType;
        idx    : LongInt;
        i      : aint;
        len    : byte;
        data   : array[0..255] of byte;
      begin
        result:=nil;
        { not initialized or error }
        if dataidx<0 then
          InternalError(200306067);
        { read data }
        CurrentModule.derefdata.seek(dataidx);
        if CurrentModule.derefdata.read(len,1)<>1 then
          InternalError(200310221);
        if len>0 then
          begin
            if CurrentModule.derefdata.read(data,len)<>len then
              InternalError(200310222);
          end;
        { process data }
        pm:=CurrentModule;
        i:=0;
        while (i<len) do
          begin
            typ:=TDerefType(data[i]);
            inc(i);
            case typ of
              deref_unit :
                begin
                  idx:=BEtoN(unaligned(PUint16(@data[i{..i+1}])^));
                  inc(i,2);
                  pm:=CurrentModule.resolve_unit(idx);
                end;
              deref_defid :
                begin
                  idx:=BEtoN(unaligned(PInt32(@data[i{..i+3}])^));
                  inc(i,4);
                  result:=TDef(pm.deflist[idx]);
                end;
              deref_symid :
                begin
                  idx:=BEtoN(unaligned(PInt32(@data[i{..i+3}])^));
                  inc(i,4);
                  result:=TSym(pm.symlist[idx]);
                end;
              deref_nil :
                begin
                  result:=nil;
                  { Only allowed when no other deref is available }
                  if len<>1 then
                    InternalError(200306232);
                end;
            end;
          end;
      end;


{*****************************************************************************
                            TCompilerPPUFile
*****************************************************************************}

    procedure TCompilerPPUFile.checkerror;
      begin
        if error then
         Message(unit_f_ppu_read_error);
      end;

    procedure TCompilerPPUFile.RaiseAssertion(Code: LongInt);
      begin
        InternalError(Code);
      end;

    procedure TCompilerPPUFile.getguid(var g: TGUID);
      begin
        LongInt(g.d1):=getlongint;
        g.d2:=getword;
        g.d3:=getword;
        getdata(g.d4,sizeof(g.d4));
      end;


    function TCompilerPPUFile.getexprint:TConstExprInt;

    begin
      getexprint.overflow:=false;
      getexprint.signed:=getboolean;
      getexprint.svalue:=getint64;
    end;


    procedure TCompilerPPUFile.getposinfo(var p:TFilePosInfo);
      var
        info : byte;
      begin
        {
          info byte layout in bits:
          0-1 - amount of bytes for fileindex
          2-3 - amount of bytes for line
          4-5 - amount of bytes for column
        }
        info:=getbyte;
        case (info and $03) of
         0 : p.fileindex:=getbyte;
         1 : p.fileindex:=getword;
         2 : p.fileindex:=(getbyte shl 16) or getword;
         3 : p.fileindex:=getlongint;
        end;
        case ((info shr 2) and $03) of
         0 : p.line:=getbyte;
         1 : p.line:=getword;
         2 : p.line:=(getbyte shl 16) or getword;
         3 : p.line:=getlongint;
        end;
        case ((info shr 4) and $03) of
         0 : p.column:=getbyte;
         1 : p.column:=getword;
         2 : p.column:=(getbyte shl 16) or getword;
         3 : p.column:=getlongint;
        end;
        p.moduleindex:=CurrentModule.ModuleID;
      end;


    procedure TCompilerPPUFile.getderef(var d:TDeref);
      begin
        d.dataidx:=getlongint;
      end;


    function TCompilerPPUFile.getpropaccesslist:TPropAccessList;
      var
        hderef : TDeref;
        slt : TSLType;
        idx : LongInt;
        p   : TPropAccessList;
      begin
        p:=TPropAccessList.create;
        getderef(p.procdefderef);
        repeat
          slt:=TSLType(getbyte);
          case slt of
            sl_none :
              break;
            sl_call,
            sl_load,
            sl_subscript :
              begin
                getderef(hderef);
                p.addsymderef(slt,hderef);
              end;
            sl_absolutetype,
            sl_typeconv :
              begin
                getderef(hderef);
                p.addtypederef(slt,hderef);
              end;
            sl_vec :
              begin
                idx:=getlongint;
                getderef(hderef);
                p.addconstderef(slt,idx,hderef);
              end;
          end;
        until false;
        getpropaccesslist:=TPropAccessList(p);
      end;


    function  TCompilerPPUFile.getasmsymbol:TAsmSymbol;
      begin
        getlongint;
        getasmsymbol:=nil;
      end;


    procedure TCompilerPPUFile.putposinfo(const p:TFilePosInfo);
      var
        oldcrc : boolean;
        info   : byte;
      begin
        { posinfo is not relevant for changes in PPU }
        oldcrc:=do_crc;
        do_crc:=false;
        {
          info byte layout in bits:
          0-1 - amount of bytes for fileindex
          2-3 - amount of bytes for line
          4-5 - amount of bytes for column
        }
        info:=0;
        { calculate info byte }
        if (p.fileindex>$ff) then
         begin
           info:=info or $1;
           { uncomment this code if tfileposinfo.fileindex type was changed
           if (p.fileindex<=$ffff) then
            info:=info or $1
           else
            if (p.fileindex<=$ffffff) then
             info:=info or $2
           else
            info:=info or $3;
           }
          end;
        if (p.line>$ff) then
         begin
           if (p.line<=$ffff) then
            info:=info or $4
           else
            if (p.line<=$ffffff) then
             info:=info or $8
           else
            info:=info or $c;
          end;
        if (p.column>$ff) then
         begin
           info:=info or $10;
           { uncomment this code if tfileposinfo.column type was changed
           if (p.column<=$ffff) then
            info:=info or $10
           else
            if (p.column<=$ffffff) then
             info:=info or $20
           else
            info:=info or $30;
           }
          end;
        { write data }
        putbyte(info);
        case (info and $03) of
         0 : putbyte(p.fileindex);
         1 : putword(p.fileindex);
         2 : begin
               putbyte(p.fileindex shr 16);
               putword(p.fileindex and $ffff);
             end;
         3 : putlongint(p.fileindex);
        end;
        case ((info shr 2) and $03) of
         0 : putbyte(p.line);
         1 : putword(p.line);
         2 : begin
               putbyte(p.line shr 16);
               putword(p.line and $ffff);
             end;
         3 : putlongint(p.line);
        end;
        case ((info shr 4) and $03) of
         0 : putbyte(p.column);
         1 : putword(p.column);
         2 : begin
               putbyte(p.column shr 16);
               putword(p.column and $ffff);
             end;
         3 : putlongint(p.column);
        end;
        do_crc:=oldcrc;
      end;


    procedure TCompilerPPUFile.putguid(const g: TGUID);
      begin
        putlongint(LongInt(g.d1));
        putword(g.d2);
        putword(g.d3);
        putdata(g.d4,sizeof(g.d4));
      end;


    procedure TCompilerPPUFile.putexprint(const v:TConstExprInt);

    begin
      if v.overflow then
        InternalError(200706102);
      putboolean(v.signed);
      putint64(v.svalue);
    end;


    procedure TCompilerPPUFile.putderef(const d:TDeref);
      var
        oldcrc : boolean;
      begin
        oldcrc:=do_crc;
        do_crc:=false;
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
	{ Accept invalid marker inside getppucrc }
        if writing_interface_ppu then
          putlongint(d.dataidx)
        else
{$endif}
        if (d.dataidx=-1) and not crc_only then
          InternalError(2019022201)
        else
          putlongint(d.dataidx);
        do_crc:=oldcrc;
      end;


    procedure TCompilerPPUFile.putpropaccesslist(p:TPropAccessList);
      var
        hp : PPropAccessListItem;
      begin
        putderef(p.procdefderef);
        hp:=p.firstsym;
        while Assigned(hp) do
         begin
           putbyte(byte(hp^.sltype));
           case hp^.sltype of
             sl_call,
             sl_load,
             sl_subscript :
               putderef(hp^.symderef);
             sl_absolutetype,
             sl_typeconv :
               putderef(hp^.defderef);
             sl_vec :
               begin
                 putlongint(int64(hp^.value));
                 putderef(hp^.valuedefderef);
               end;
             else
              InternalError(2001102003);
           end;
           hp:=hp^.next;
         end;
        putbyte(byte(sl_none));
      end;


    procedure TCompilerPPUFile.putasmsymbol(s:TAsmSymbol);
      begin
        putlongint(0);
      end;

{$ifdef MEMDEBUG}
initialization
  memmanglednames:=TMemDebug.create('Manglednames');
  memmanglednames.stop;
  memprocpara:=TMemDebug.create('ProcPara');
  memprocpara.stop;
  memprocparast:=TMemDebug.create('ProcParaSt');
  memprocparast.stop;
  memproclocalst:=TMemDebug.create('ProcLocalSt');
  memproclocalst.stop;
  memprocnodetree:=TMemDebug.create('ProcNodeTree');
  memprocnodetree.stop;

finalization
  memmanglednames.free;
  memmanglednames := nil;
  memprocpara.free;
  memprocpara := nil;
  memprocparast.free;
  memprocparast := nil;
  memproclocalst.free;
  memproclocalst := nil;
  memprocnodetree.free;
  memprocnodetree := nil;
{$endif MEMDEBUG}

end.

