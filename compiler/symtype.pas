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
      SymConst,SymBase,
      { aasm }
      AAsmBase,PPU,
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
         function Registered : Boolean;
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
         RegisteredInModule : TModuleBase;
         TypeSym    : TSym;  { which type the definition was generated this def }
         DbgState   : TDefDbgStatus;
         DefOptions  : TDefOptions;
         DefStates   : TDefStates;
         constructor Create(DT:TDefTyp);
         destructor Destroy; override;
         procedure BuildDeref;virtual;abstract;
         procedure BuildDerefImpl;virtual;abstract;
         procedure Deref;virtual;abstract;
         procedure DerefImpl;virtual;abstract;
         function  TypeName:string;
         function  FullTypeName:string;
         function  GetTypeName:string;virtual;
         function  TypeSymbolPrettyName:string;virtual;
         function  MangledParaName:string;
         function  GetMangledParaName:TSymStr;virtual;
         function  RTTIMangledName(RT:TRTTIType):TSymStr;virtual;abstract;
         function  OwnerHierarchyName: string; virtual; abstract;
         function  OwnerHierarchyPrettyName: string; virtual; abstract;
         function  FullOwnerHierarchyName(SkipProcParams:Boolean;UsePretty : Boolean):TSymStr;virtual;abstract;
         function  UniqueIDStr: string;
         function  Size:ASizeInt;virtual;abstract;
         function  PackedBitSize:ASizeInt;virtual;
         function  Alignment:ShortInt;virtual;abstract;
         { alignment when this type appears in a record/class/... }
         function  StructAlignment:ShortInt;virtual;
         function  AggregateAlignment:ShortInt;virtual;
         function  GetVarDef:LongInt;virtual;abstract;
         function  GetParentDef:TDef;virtual;
         function  GetSymTable(T:TGetSymTable):TSymTable;virtual;
         function  IsPublishable:TPublishProperty;virtual;abstract;
         function  NeedsInitTable:Boolean;virtual;abstract;
         { contains a (managed) child that is not initialized to 0/Nil }
         function  HasNonTrivialInitChild(CheckParent:Boolean):Boolean;virtual;abstract;
         function  NeedsSeparateInitRTTI:Boolean;virtual;abstract;
         procedure ChangeOwner(ST:TSymTable);
         function GetReusableSymTab: TSymTable;
         procedure RegisterCreatedObjectType;virtual;
         function  GetTopLevelSymTable(SkipProcDefs: Boolean): TSymTable;
         { only valid for registered defs and defs for which a unique id string
           has been requested; otherwise, first call register_def }
         function  DefListIndex: LongInt;
         procedure RegisterDef; virtual; abstract;
{$ifdef DEBUG_NODE_XML}
         procedure XMLPrintDef(Sym: TSym);
{$endif DEBUG_NODE_XML}
         property IsRegistered: Boolean read Registered;
      end;

{************************************************
                     TSym
************************************************}

      { this object is the base for all symbol objects }
      TSym = class(TSymEntry)
      protected
       function Registered : Boolean;
      public
         FileInfo   : TFilePosInfo;
         { size of fileinfo is 10 bytes, so if a >word aligned type would follow,
           two bytes of memory would be wasted, so we put two one byte fields over here }
         Visibility : TVisibility;
         IsDbgWritten : Boolean;
         SymOptions : TSymOptions;
         Refs       : LongInt;
         RefList    : TLinkedList;
         { deprecated optionally can have a message }
         DeprecatedMsg: PShortString;
         constructor Create(ST:TSymTyp;const AName:string);
         destructor  Destroy;override;
         function  MangledName:TSymStr; virtual;
         function  PrettyName:string; virtual;
         procedure BuildDeref;virtual;
         procedure Deref;virtual;
         procedure ChangeOwner(ST:TSymTable);
         procedure ChangeOwnerAndName(ST:TSymTable;const AName:TSymStr);
         procedure IncRefCount;
         procedure IncRefCountBy(AValue : LongInt);
         procedure MaybeCreateRefList;
         procedure AddRef;
         procedure RegisterSym; virtual; abstract;
         property IsRegistered:Boolean read Registered;
      end;

      TSymArr = array[0..MaxLongInt div SizeOf(Pointer)-1] of TSym;
      PSymArr = ^TSymArr;

{************************************************
                   TDeref
************************************************}

      TDeref = record
        DataIdx : LongInt;
        procedure Reset;
        procedure Build(S:TObject);
        function  Resolve:TObject;
     end;
     PDeref = ^TDeref;

{************************************************
                   tpropaccesslist
************************************************}

      PPropAccessListItem = ^TPropAccessListItem;
      TPropAccessListItem = record
        SLType : TSLType;
        Next   : PPropAccessListItem;
        case Byte of
          0 : (Sym : TSym; SymDeref : TDeref);
          1 : (Value  : TConstExprInt; ValueDef: TDef; ValueDefDeref:TDeref);
          2 : (Def: TDef; DefDeref:TDeref);
      end;

      TPropAccessList = class
        ProcDef  : TDef;
        ProcDefDeref : TDeref;
        FirstSym,
        LastSym  : PPropAccessListItem;
        constructor Create;
        destructor  Destroy;override;
        function  Empty:Boolean;
        function GetCopy: TPropAccessList;
        procedure AddSym(SLT:TSLType;P:TSym);
        procedure AddConst(SLT:TSLType;const V:TConstExprInt;D:TDef);
        procedure AddType(SLT:TSLType;D:TDef);
        procedure AddSymDeref(SLT:TSLType;D:TDeref);
        procedure AddConstDeref(SLT:TSLType;const V:TConstExprInt;D:TDeref);
        procedure AddTypeDeref(SLT:TSLType;D:TDeref);
        procedure Clear;
        procedure Resolve;
        procedure BuildDeref;
      end;

{************************************************
                Tcompilerppufile
************************************************}
       TCompilerPPUFile=class(TPPUFile)
       public
         procedure CheckError;
         procedure GetGUID(var G: TGUID);
         function  GetExprInt:TConstExprInt;
         procedure GetPosInfo(var P:TFilePosInfo);
         procedure GetDeref(var D:TDeref);
         function  GetPropAccessList:TPropAccessList;
         function  GetAsmSymbol:TAsmSymbol;
         procedure PutGUID(const G: TGUID);
         procedure PutExprInt(const V:TConstExprInt);
         procedure PutPosInfo(const P:TFilePosInfo);
         procedure PutDeref(const D:TDeref);
         procedure PutPropAccessList(P:TPropAccessList);
         procedure PutAsmSymbol(S:TAsmSymbol);
       protected
         procedure RaiseAssertion(Code: LongInt); override;
       end;

{$ifdef MEMDEBUG}
    var
      MemMangledNames,
      MemProcPara,
      MemProcParaST,
      MemProcLocalST,
      MemProcNodeTree : TMemDebug;
{$endif MEMDEBUG}

    function  FindUnitSymTable(ST:TSymTable):TSymTable;


implementation

    uses
       CRefs,
       Verbose,
       FModule
       ;

{****************************************************************************
                                Utils
****************************************************************************}

    function FindUnitSymTable(ST:TSymTable):TSymTable;
      begin
        Result:=nil;
        repeat
          if not Assigned(ST) then
           InternalError(200602034);
          case ST.SymTableType of
            LocalMacroSymTable,
            ExportedMacroSymTable,
            StaticSymTable,
            GlobalSymTable :
              begin
                Result:=ST;
                Exit;
              end;
            ExceptSymTable,
            RecordSymTable,
            EnumSymTable,
            ArraySymTable,
            LocalSymTable,
            ParaSymTable,
            ObjectSymtable :
              ST:=ST.DefOwner.Owner;
            else
              InternalError(200602035);
          end;
        until False;
      end;


{****************************************************************************
                                Tdef
****************************************************************************}

    function TDef.Registered: Boolean;
      begin
        Result:=DefID>DefIDNotRegistered;
      end;


    procedure TDef.InitDefID;
      begin
        if DefID=0 then
          DefID:=DefIDNotRegistered;
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
        I: TSymOption;
        First: Boolean;
      begin
        { Note that if we've declared something like "INT = Integer", the
          INT name gets lost in the system and 'typename' just returns
          Integer, so the correct details can be found via Sym }
        Write(T, ' name="', SanitiseXMLString(Sym.RealName),
          '" pos="', Sym.FileInfo.Line, ',', Sym.FileInfo.Column);

        First := True;
        for I := Low(TSymOption) to High(TSymOption) do
          if I in Sym.SymOptions then
            begin
              if First then
                begin
                  Write(T, '" symoptions="', I);
                  First := False;
                end
              else
                Write(T, ',', I)
            end;

        Write(T, '"');
      end;


    procedure TDef.XMLPrintDefData(var T: Text; Sym: TSym);
      begin
        WriteLn(T, PrintNodeIndention, '<size>', Size, '</size>');

        if (Alignment = StructAlignment) and (Alignment = AggregateAlignment) then
          begin
            { Straightforward and simple }
            WriteLn(T, PrintNodeIndention, '<alignment>', Alignment, '</alignment>');
          end
        else
          begin
            WriteLn(T, PrintNodeIndention, '<alignment>');
            PrintNodeIndent;
            WriteLn(T, PrintNodeIndention, '<basic>', Alignment, '</basic>');

            if (StructAlignment <> Alignment) then
              WriteLn(T, PrintNodeIndention, '<struct>', StructAlignment, '</struct>');

            if (AggregateAlignment <> Alignment) and (AggregateAlignment <> StructAlignment) then
              WriteLn(T, PrintNodeIndention, '<aggregate>', AggregateAlignment, '</aggregate>');

            PrintNodeUnindent;
            WriteLn(T, PrintNodeIndention, '</alignment>');
          end;
      end;


    function TDef.XMLPrintType: AnsiString;
      begin
        Result := SanitiseXMLString(GetTypeName);
      end;

{$endif DEBUG_NODE_XML}

    constructor TDef.Create(DT:TDefTyp);
      begin
         inherited Create;
         Typ:=DT;
         Owner := nil;
         TypeSym := nil;
         DefOptions:=[];
         DbgState:=dbg_state_unused;
         InitDefID;
      end;


    destructor TDef.Destroy;
      begin
        { set self to nil in registered_in_module's deflist, if the def has been
          registered, in order to avoid dangling pointers in registered_in_module.deflist }
        if Assigned(RegisteredInModule) then
          begin
           if DefID>=0 then
             TModule(RegisteredInModule).DefList[DefID]:=nil
           else if DefID<DefIDNotRegistered then
             TModule(RegisteredInModule).DefList[-(DefID-DefIDNotRegistered+1)]:=nil
           else
             InternalError(2021060101);
          end;
        inherited;
      end;


    function TDef.TypeName:string;
      begin
        Result:=OwnerHierarchyName;
        if Assigned(TypeSym) and
           not(Typ in [ProcVarDef,ProcDef]) and
           (TypeSym.RealName[1]<>'$') then
          Result:=Result+TypeSym.RealName
        else
          Result:=Result+GetTypeName;
      end;


    function TDef.FullTypeName:string;
      begin
        Result:=FullOwnerHierarchyName(False,False);
        if Assigned(TypeSym) and
           not(Typ in [ProcVarDef,ProcDef]) and
           (TypeSym.RealName[1]<>'$') then
          Result:=Result+TypeSym.RealName
        else
          Result:=Result+GetTypeName;
      end;


    function TDef.GetTypeName : string;
      begin
         GetTypeName:='<unknown type>'
      end;


    function TDef.TypeSymbolPrettyName:string;
      begin
        Result:=OwnerHierarchyPrettyName;
        if Assigned(TypeSym) then
          Result:=Result+TypeSym.PrettyName
        else
          Result:=Result+'<no type symbol>';
      end;


    function TDef.MangledParaName:string;
      begin
        Result:=OwnerHierarchyName;
        if Assigned(TypeSym) then
          MangledParaName:=Result+TypeSym.Name
        else
          MangledParaName:=Result+GetMangledParaName;
      end;


    function TDef.GetMangledParaName:TSymStr;
      begin
         Result:='<unknown type>';
      end;


    function TDef.UniqueIDStr: string;
      begin
        if (DefID=DefIDNotRegistered) or
           (DefID=DefIDRegisteredNoST) then
          begin
            if not Assigned(CurrentModule) then
              InternalError(2015102505);
            CurrentModule.DefList.Add(Self);
            RegisteredInModule:=CurrentModule;
            { invert the defid to indicate that it was only set because we
              needed a unique number -- then add defid_not_registered so we
              don't get the values between defid_registered and 0 }
            DefID:=-(CurrentModule.DefList.Count-1)+DefIDNotRegistered-1;
          end;
        { use deflist_index so that it will remain the same if def first gets a
          defid just for the unique id (as above) and later it gets registered
          because it must be saved to the ppu }
        Result:=HexStr(DefListIndex,SizeOf(DefID)*2);
      end;


    function TDef.GetParentDef:TDef;
      begin
        Result:=nil;
      end;


    function TDef.GetSymTable(T:TGetSymTable):TSymTable;
      begin
        Result:=nil;
      end;


    function TDef.PackedBitSize:ASizeInt;
      begin
        Result:=Size * 8;
      end;


    function TDef.StructAlignment: ShortInt;
      begin
        Result:=Alignment;
      end;

    function TDef.AggregateAlignment: ShortInt;
      begin
        if Assigned(Owner) and Assigned(Owner.DefOwner) and (Owner.DefOwner is TDef) and (Owner.DefOwner <> Self) then
          Result := Max(StructAlignment, TDef(Owner.DefOwner).AggregateAlignment)
        else
          Result := StructAlignment;
      end;


    procedure TDef.ChangeOwner(ST:TSymTable);
      begin
        if Assigned(Owner) and Owner.DefList.OwnsObjects then
          Owner.DefList.Extract(Self);
        Owner:=ST;
        Owner.DefList.Add(Self);
      end;


    function TDef.GetReusableSymTab: TSymTable;
      var
        OrigOwner: TSymTable;
      begin
        { if the original def was in a localsymtable, don't create a
          reusable copy in the unit's staticsymtable since the localsymtable
          won't be saved to the ppu and as a result we can get unreachable
          defs when reloading the derived ones from the ppu }
        OrigOwner:=Owner;
        while not(OrigOwner.SymTableType in [LocalSymTable,StaticSymTable,GlobalSymTable,ExceptSymTable]) do
          OrigOwner:=OrigOwner.DefOwner.Owner;
        { if the def is in an exceptionsymtable, we can't create a reusable
          def because the original one will be freed when the (always
          temporary) exceptionsymtable is freed }
        if OrigOwner.SymTableType=ExceptSymTable then
          InternalError(2015111701)
        else if OrigOwner.SymTableType=LocalSymTable then
          Result:=OrigOwner
        else if Assigned(CurrentModule.LocalSymTable) then
          Result:=CurrentModule.LocalSymTable
        else
          Result:=CurrentModule.GlobalSymTable;
      end;


    procedure TDef.RegisterCreatedObjectType;
      begin
      end;


    function TDef.GetTopLevelSymTable(SkipProcDefs: Boolean): TSymTable;
      begin
        Result:=Owner;
        while Assigned(Result) and
              Assigned(Result.DefOwner) and
              (SkipProcDefs or (Result.SymTableType in [ObjectSymtable,RecordSymTable])) do
          Result:=TDef(Result.DefOwner).Owner;
      end;


    function TDef.DefListIndex: LongInt;
      begin
        if DefID<DefIDNotRegistered then
          Result:=-(DefID-DefIDNotRegistered+1)
        else if DefID>=0 then
          Result:=DefID
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

    function TSym.Registered: Boolean;
      begin
        Result:=SymID>SymIDNotRegistered;
      end;


    constructor TSym.Create(ST:TSymTyp;const AName:string);
      begin
         inherited CreateNotOwned;
         RealName:=AName;
         Typ:=ST;
         RefList:=nil;
         SymOptions:=[];
         FileInfo:=CurrentTokenPos;
         IsDbgWritten := False;
         Visibility:=vis_public;
         DeprecatedMsg:=nil;
         SymID:=SymIDNotRegistered;
      end;

    destructor  TSym.Destroy;
      begin
        StringDispose(DeprecatedMsg);
        RefList.Free;
        RefList := nil;
        inherited Destroy;
      end;

    procedure TSym.IncRefCount;
      begin
        Inc(Refs);
        if cs_browser in CurrentSettings.ModuleSwitches then
          begin
            MaybeCreateRefList;
            AddRef;
          end;
      end;

    procedure TSym.IncRefCountBy(AValue : LongInt);
      begin
        Inc(Refs,AValue);
      end;

    procedure TSym.MaybeCreateRefList;
      begin
        if not Assigned(RefList) then
          RefList:=TRefLinkedList.Create;
      end;

    procedure TSym.AddRef;
      var
        RefItem: TRefItem;
      begin
        RefItem:=TRefItem.Create(CurrentTokenPos);
        RefList.Concat(RefItem);
      end;

    procedure TSym.BuildDeref;
      begin
      end;


    procedure TSym.Deref;
      begin
      end;


    function TSym.MangledName : TSymStr;
      begin
        InternalError(200204171);
        Result:='';
      end;


    function TSym.PrettyName : string;
      var
       I: SizeInt;
      begin
        Result:=RealName;
        { strip type parameters in the name separated by '$' }
        I:=Pos('$',Result);
        if I>0 then
          Delete(Result,I,MaxInt);
      end;


    procedure TSym.ChangeOwner(ST:TSymTable);
      begin
        if Assigned(Owner) and Owner.SymList.OwnsObjects then
          Owner.SymList.Extract(Self);
        Owner:=ST;
        inherited ChangeOwner(Owner.SymList);
      end;


    procedure TSym.ChangeOwnerAndName(ST:TSymTable;const AName:TSymStr);
      begin
        if Assigned(Owner) and Owner.SymList.OwnsObjects then
          Owner.SymList.Extract(Self);
        Owner:=ST;
        inherited ChangeOwnerAndName(Owner.SymList,AName);
      end;


{****************************************************************************
                                 tpropaccesslist
****************************************************************************}

    constructor TPropAccessList.Create;
      begin
        ProcDef:=nil; { needed for procedures }
        FirstSym:=nil;
        LastSym:=nil;
      end;


    destructor TPropAccessList.Destroy;
      begin
        Clear;
      end;


    function TPropAccessList.Empty:Boolean;
      begin
        Empty:=(FirstSym=nil);
      end;

    function TPropAccessList.GetCopy: TPropAccessList;
      var
        HP, Dest : PPropAccessListItem;
      begin
        Result:=TPropAccessList.Create;
        Result.ProcDef:=ProcDef;
        HP:=FirstSym;
        while Assigned(HP) do
          begin
            New(Dest);
            Dest^:=HP^;
            Dest^.Next:=nil;
            if not Assigned(Result.FirstSym) then
              Result.FirstSym:=Dest;
            if Assigned(Result.LastSym) then
              Result.LastSym^.Next:=Dest;
            Result.LastSym:=Dest;
            HP:=HP^.Next;
          end;
      end;


    procedure TPropAccessList.Clear;
      var
        HP : PPropAccessListItem;
      begin
        while Assigned(FirstSym) do
         begin
           HP:=FirstSym;
           FirstSym:=FirstSym^.Next;
           Dispose(HP);
         end;
        FirstSym:=nil;
        LastSym:=nil;
        ProcDef:=nil;
      end;


    procedure TPropAccessList.AddSym(SLT:TSLType;P:TSym);
      var
        HP : PPropAccessListItem;
      begin
        New(HP);
        FillChar(HP^,SizeOf(TPropAccessListItem),0);
        HP^.SLType:=SLT;
        HP^.Sym:=P;
        HP^.SymDeref.Reset;
        if Assigned(LastSym) then
         LastSym^.Next:=HP
        else
         FirstSym:=HP;
        LastSym:=HP;
      end;


    procedure TPropAccessList.AddConst(SLT:TSLType;const V:TConstExprInt;D:TDef);
      var
        HP : PPropAccessListItem;
      begin
        New(HP);
        FillChar(HP^,SizeOf(TPropAccessListItem),0);
        HP^.SLType:=SLT;
        HP^.Value:=V;
        HP^.ValueDef:=D;
        HP^.ValueDefDeref.Reset;
        if Assigned(LastSym) then
         LastSym^.Next:=HP
        else
         FirstSym:=HP;
        LastSym:=HP;
      end;


    procedure TPropAccessList.AddType(SLT:TSLType;D:TDef);
      var
        HP : PPropAccessListItem;
      begin
        New(HP);
        FillChar(HP^,SizeOf(TPropAccessListItem),0);
        HP^.SLType:=SLT;
        HP^.Def:=D;
        HP^.DefDeref.Reset;
        if Assigned(LastSym) then
         LastSym^.Next:=HP
        else
         FirstSym:=HP;
        LastSym:=HP;
      end;


    procedure TPropAccessList.AddSymDeref(SLT:TSLType;D:TDeref);
      begin
        AddSym(SLT,nil);
        LastSym^.SymDeref:=D;
      end;


    procedure TPropAccessList.AddConstDeref(SLT:TSLType;const V:TConstExprInt;D:TDeref);
      begin
        AddConst(SLT,V,nil);
        LastSym^.ValueDefDeref:=D;
      end;


    procedure TPropAccessList.AddTypeDeref(SLT:TSLType;D:TDeref);
      begin
        AddType(SLT,nil);
        LastSym^.DefDeref:=D;
      end;


    procedure TPropAccessList.Resolve;
      var
        HP : PPropAccessListItem;
      begin
        ProcDef:=TDef(ProcDefDeref.Resolve);
        HP:=FirstSym;
        while Assigned(HP) do
         begin
           case HP^.SLType of
             sl_call,
             sl_load,
             sl_subscript :
               HP^.Sym:=TSym(HP^.SymDeref.Resolve);
             sl_absolutetype,
             sl_typeconv :
               HP^.Def:=TDef(HP^.DefDeref.Resolve);
             sl_vec:
               HP^.ValueDef:=TDef(HP^.ValueDefDeref.Resolve);
             else
              InternalError(2001102001);
           end;
           HP:=HP^.Next;
         end;
      end;


    procedure TPropAccessList.BuildDeref;
      var
        HP : PPropAccessListItem;
      begin
        ProcDefDeref.Build(ProcDef);
        HP:=FirstSym;
        while Assigned(HP) do
         begin
           case HP^.SLType of
             sl_call,
             sl_load,
             sl_subscript :
               HP^.SymDeref.Build(HP^.Sym);
             sl_absolutetype,
             sl_typeconv :
               HP^.DefDeref.Build(HP^.Def);
             sl_vec:
               HP^.ValueDefDeref.Build(HP^.ValueDef);
             else
              InternalError(2001102002);
           end;
           HP:=HP^.Next;
         end;
      end;


{****************************************************************************
                                Tderef
****************************************************************************}


    procedure TDeref.Reset;
      begin
        DataIdx:=-1;
      end;


    procedure TDeref.Build(S:TObject);

       procedure DoInternalError(I : Integer);NoReturn;
       // local proc so we do not have an implicit try..finally in the build proc.
       var
         Msg : AnsiString;
       begin
         if Assigned(S) then
           Msg:=S.ToString
         else
           Msg:='Nil object';
         InternalError(I,'Cannot build:'+Msg);
       end;

      var
        Len  : Byte;
        ST   : TSymTable;
        Data : array[0..255] of Byte;
        Idx : Word;

      begin
        { skip length byte }
        Len:=1;
        if Assigned(S) then
         begin
{ TODO: ugly hack}
           if S is TSym then
             begin
               { if it has been registered but it wasn't put in a symbol table,
                 this symbol shouldn't be written to a ppu }
               if TSym(S).SymID=SymIDRegisteredNoST then
                 DoInternalError(2015102504);
               if not TSym(S).Registered then
                 TSym(S).RegisterSym;
               ST:=FindUnitSymTable(TSym(S).Owner)
             end
           else if S is TDef then
             begin
               { same as above }
               if TDef(S).DefID=DefIDRegisteredNoST then
                 DoInternalError(2015102501);
               if TDef(S).Typ=ErrorDef then
                 DoInternalError(2024011501);
               if not TDef(S).Registered then
                 TDef(S).RegisterDef;
               ST:=FindUnitSymTable(TDef(S).Owner);
             end
           else
             // Unknown object type
             DoInternalError(2016090204);
           if not ST.IsCurrentUnit then
             begin
               { register that the unit is needed for resolving }
               Data[Len]:=Ord(deref_unit);
               Idx:=CurrentModule.DerefIdx_Unit(ST.ModuleID);
               Unaligned(PUint16(@Data[Len+1{..len+2}])^):=NtoBE(UInt16(Idx));
               Inc(Len,3);
             end;
           if S is TSym then
             begin
               Data[Len]:=Ord(deref_symid);
               Unaligned(PInt32(@Data[Len+1{..len+4}])^):=NtoBE(Int32(TSym(S).SymID));
               Inc(Len,5);
             end
           else
             begin
               Data[Len]:=Ord(deref_defid);
               Unaligned(PInt32(@Data[Len+1{..len+4}])^):=NtoBE(Int32(TDef(S).DefID));
               Inc(Len,5);
             end;
         end
        else
         begin
           { nil pointer }
           Data[Len]:=Ord(deref_nil);
           Inc(Len);
         end;

        { store data length in first byte }
        Data[0]:=Len-1;

        { store index and write to derefdata }
        DataIdx:=CurrentModule.DerefData.Size;
        CurrentModule.DerefData.write(Data,Len);
      end;


    function TDeref.Resolve:TObject;
      var
        PM     : TModule;
        Typ    : TDerefType;
        Idx    : LongInt;
        I      : AInt;
        Len    : Byte;
        Data   : array[0..255] of Byte;
      begin
        Result:=nil;
        { not initialized or error }
        if DataIdx<0 then
          InternalError(200306067);
        { read data }
        CurrentModule.DerefData.Seek(DataIdx);
        if CurrentModule.DerefData.read(Len,1)<>1 then
          InternalError(200310221);
        if Len>0 then
          begin
            if CurrentModule.DerefData.read(Data,Len)<>Len then
              InternalError(200310222);
          end;
        { process data }
        PM:=CurrentModule;
        I:=0;
        while (I<Len) do
          begin
            Typ:=TDerefType(Data[I]);
            Inc(I);
            case Typ of
              deref_unit :
                begin
                  Idx:=BEtoN(Unaligned(PUint16(@Data[I{..i+1}])^));
                  Inc(I,2);
                  PM:=CurrentModule.Resolve_Unit(Idx);
                end;
              deref_defid :
                begin
                  Idx:=BEtoN(Unaligned(PInt32(@Data[I{..i+3}])^));
                  Inc(I,4);
                  Result:=TDef(PM.DefList[Idx]);
                end;
              deref_symid :
                begin
                  Idx:=BEtoN(Unaligned(PInt32(@Data[I{..i+3}])^));
                  Inc(I,4);
                  Result:=TSym(PM.SymList[Idx]);
                end;
              deref_nil :
                begin
                  Result:=nil;
                  { Only allowed when no other deref is available }
                  if Len<>1 then
                    InternalError(200306232);
                end;
            end;
          end;
      end;


{*****************************************************************************
                            TCompilerPPUFile
*****************************************************************************}

    procedure TCompilerPPUFile.CheckError;
      begin
        if Error then
         Message(unit_f_ppu_read_error);
      end;

    procedure TCompilerPPUFile.RaiseAssertion(Code: LongInt);
      begin
        InternalError(Code);
      end;

    procedure TCompilerPPUFile.GetGUID(var G: TGUID);
      begin
        LongInt(G.D1):=GetLongInt;
        G.D2:=GetWord;
        G.D3:=GetWord;
        GetData(G.D4,SizeOf(G.D4));
      end;


    function TCompilerPPUFile.GetExprInt:TConstExprInt;

    begin
      GetExprInt.Overflow:=False;
      GetExprInt.Signed:=GetBoolean;
      GetExprInt.SValue:=GetInt64;
    end;


    procedure TCompilerPPUFile.GetPosInfo(var P:TFilePosInfo);
      var
        Info : Byte;
      begin
        {
          info byte layout in bits:
          0-1 - amount of bytes for fileindex
          2-3 - amount of bytes for line
          4-5 - amount of bytes for column
        }
        Info:=GetByte;
        case (Info and $03) of
         0 : P.FileIndex:=GetByte;
         1 : P.FileIndex:=GetWord;
         2 : P.FileIndex:=(GetByte shl 16) or GetWord;
         3 : P.FileIndex:=GetLongInt;
        end;
        case ((Info shr 2) and $03) of
         0 : P.Line:=GetByte;
         1 : P.Line:=GetWord;
         2 : P.Line:=(GetByte shl 16) or GetWord;
         3 : P.Line:=GetLongInt;
        end;
        case ((Info shr 4) and $03) of
         0 : P.Column:=GetByte;
         1 : P.Column:=GetWord;
         2 : P.Column:=(GetByte shl 16) or GetWord;
         3 : P.Column:=GetLongInt;
        end;
        P.ModuleIndex:=CurrentModule.ModuleID;
      end;


    procedure TCompilerPPUFile.GetDeref(var D:TDeref);
      begin
        D.DataIdx:=GetLongInt;
      end;


    function TCompilerPPUFile.GetPropAccessList:TPropAccessList;
      var
        HDeref : TDeref;
        SLT : TSLType;
        Idx : LongInt;
        P   : TPropAccessList;
      begin
        P:=TPropAccessList.Create;
        GetDeref(P.ProcDefDeref);
        repeat
          SLT:=TSLType(GetByte);
          case SLT of
            sl_none :
              Break;
            sl_call,
            sl_load,
            sl_subscript :
              begin
                GetDeref(HDeref);
                P.AddSymDeref(SLT,HDeref);
              end;
            sl_absolutetype,
            sl_typeconv :
              begin
                GetDeref(HDeref);
                P.AddTypeDeref(SLT,HDeref);
              end;
            sl_vec :
              begin
                Idx:=GetLongInt;
                GetDeref(HDeref);
                P.AddConstDeref(SLT,Idx,HDeref);
              end;
          end;
        until False;
        GetPropAccessList:=TPropAccessList(P);
      end;


    function  TCompilerPPUFile.GetAsmSymbol:TAsmSymbol;
      begin
        GetLongInt;
        GetAsmSymbol:=nil;
      end;


    procedure TCompilerPPUFile.PutPosInfo(const P:TFilePosInfo);
      var
        OldCRC : Boolean;
        Info   : Byte;
      begin
        { posinfo is not relevant for changes in PPU }
        OldCRC:=DoCRC;
        DoCRC:=False;
        {
          info byte layout in bits:
          0-1 - amount of bytes for fileindex
          2-3 - amount of bytes for line
          4-5 - amount of bytes for column
        }
        Info:=0;
        { calculate info byte }
        if (P.FileIndex>$ff) then
         begin
           Info:=Info or $1;
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
        if (P.Line>$ff) then
         begin
           if (P.Line<=$ffff) then
            Info:=Info or $4
           else
            if (P.Line<=$ffffff) then
             Info:=Info or $8
           else
            Info:=Info or $c;
          end;
        if (P.Column>$ff) then
         begin
           Info:=Info or $10;
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
        PutByte(Info);
        case (Info and $03) of
         0 : PutByte(P.FileIndex);
         1 : PutWord(P.FileIndex);
         2 : begin
               PutByte(P.FileIndex shr 16);
               PutWord(P.FileIndex and $ffff);
             end;
         3 : PutLongInt(P.FileIndex);
        end;
        case ((Info shr 2) and $03) of
         0 : PutByte(P.Line);
         1 : PutWord(P.Line);
         2 : begin
               PutByte(P.Line shr 16);
               PutWord(P.Line and $ffff);
             end;
         3 : PutLongInt(P.Line);
        end;
        case ((Info shr 4) and $03) of
         0 : PutByte(P.Column);
         1 : PutWord(P.Column);
         2 : begin
               PutByte(P.Column shr 16);
               PutWord(P.Column and $ffff);
             end;
         3 : PutLongInt(P.Column);
        end;
        DoCRC:=OldCRC;
      end;


    procedure TCompilerPPUFile.PutGUID(const G: TGUID);
      begin
        PutLongInt(LongInt(G.D1));
        PutWord(G.D2);
        PutWord(G.D3);
        PutData(G.D4,SizeOf(G.D4));
      end;


    procedure TCompilerPPUFile.PutExprInt(const V:TConstExprInt);

    begin
      if V.Overflow then
        InternalError(200706102);
      PutBoolean(V.Signed);
      PutInt64(V.SValue);
    end;


    procedure TCompilerPPUFile.PutDeref(const D:TDeref);
      var
        OldCRC : Boolean;
      begin
        OldCRC:=DoCRC;
        DoCRC:=False;
{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
	{ Accept invalid marker inside getppucrc }
        if WritingInterfacePPU then
          PutLongInt(D.DataIdx)
        else
{$endif}
        if (D.DataIdx=-1) and not CRCOnly then
          InternalError(2019022201)
        else
          PutLongInt(D.DataIdx);
        DoCRC:=OldCRC;
      end;


    procedure TCompilerPPUFile.PutPropAccessList(P:TPropAccessList);
      var
        HP : PPropAccessListItem;
      begin
        PutDeref(P.ProcDefDeref);
        HP:=P.FirstSym;
        while Assigned(HP) do
         begin
           PutByte(Byte(HP^.SLType));
           case HP^.SLType of
             sl_call,
             sl_load,
             sl_subscript :
               PutDeref(HP^.SymDeref);
             sl_absolutetype,
             sl_typeconv :
               PutDeref(HP^.DefDeref);
             sl_vec :
               begin
                 PutLongInt(Int64(HP^.Value));
                 PutDeref(HP^.ValueDefDeref);
               end;
             else
              InternalError(2001102003);
           end;
           HP:=HP^.Next;
         end;
        PutByte(Byte(sl_none));
      end;


    procedure TCompilerPPUFile.PutAsmSymbol(S:TAsmSymbol);
      begin
        PutLongInt(0);
      end;

{$ifdef MEMDEBUG}
initialization
  MemMangledNames:=TMemDebug.Create('Manglednames');
  MemMangledNames.Stop;
  MemProcPara:=TMemDebug.Create('ProcPara');
  MemProcPara.Stop;
  MemProcParaST:=TMemDebug.Create('ProcParaSt');
  MemProcParaST.Stop;
  MemProcLocalST:=TMemDebug.Create('ProcLocalSt');
  MemProcLocalST.Stop;
  MemProcNodeTree:=TMemDebug.Create('ProcNodeTree');
  MemProcNodeTree.Stop;

finalization
  MemMangledNames.Free;
  MemMangledNames := nil;
  MemProcPara.Free;
  MemProcPara := nil;
  MemProcParaST.Free;
  MemProcParaST := nil;
  MemProcLocalST.Free;
  MemProcLocalST := nil;
  MemProcNodeTree.Free;
  MemProcNodeTree := nil;
{$endif MEMDEBUG}

end.

