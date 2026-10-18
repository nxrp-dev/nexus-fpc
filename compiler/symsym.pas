{
    Copyright (c) 1998-2002 by Florian Klaempfl, Pierre Muller

    Implementation for the symbols types of the symtable

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
unit symsym;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
    { common }
       SysUtils,CUtils,CompInNr,
       { target }
       GlobType,Globals,WideStr,ConstExp,
       { symtable }
       SymConst,SymBase,SymType,SymDef,DefCmp,
       CClasses,
       { aasm }
       AAsmBase,
       CPUInfo,CGBase,CGUtils,ParaBase
       ;

    type
       { this class is the base for all symbol objects }
       TStoredSym = class(TSym)
       private
          procedure WriteEntry(PPUFile: TCompilerPPUFile; IBNR: Byte);
       protected
          procedure PPUWritePlatform(PPUFile: TCompilerPPUFile);virtual;
          procedure PPULoadPlatform(PPUFile: TCompilerPPUFile);virtual;
       public
          { this is Nil if the symbol has no RTTI attributes }
          RTTIAttributeList : TRTTIAttributeList;
          constructor Create(ST:TSymTyp;const N : TSymStr);
          constructor PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);virtual;
          { this is called directly after ppuload }
          procedure PPULoadSubEntries(PPUFile:TCompilerPPUFile);virtual;
          { this is called directly after ppuwrite }
          procedure PPUWriteSubEntries(PPUFile:TCompilerPPUFile);virtual;
          procedure Deref; override;
          procedure BuildDeref; override;
          procedure RegisterSym; override;
       end;

       TLabelSym = class(TStoredSym)
          Used,
          Defined,
          NonLocal : Boolean;
          { points to the matching node, only valid resultdef pass is run and
            the goto<->label relation in the node tree is created, should
            be a tnode }
          Code : Pointer;

          { points to the jump buffer }
          JumpBuf : TStoredSym;

          { when the label is defined in an asm block, this points to the
            generated asmlabel }
          AsmBlockLabel : TAsmLabel;
          constructor Create(const N : TSymStr);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function MangledName:TSymStr;override;
       end;
       TLabelSymClass = class of TLabelSym;

       TUnitSym = class(TStoredSym)
          Module : TObject; { tmodule }
          constructor Create(const N : TSymStr;AModule : TObject);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
       end;
       TUnitSymClass = class of TUnitSym;

       TProgramParaSym = class(TStoredSym)
          IsoIndex : DWord;
          constructor Create(const N : TSymStr;I : DWord);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
       end;
       TProgramParaSymClass = class of TProgramParaSym;

       TNamespaceSym = class(TStoredSym)
          UnitSym:TSym;
          UnitSymDeref:TDeref;
          constructor Create(const N : TSymStr);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
       end;
       TNamespaceSymClass = class of TNamespaceSym;

       TErrorSym = class(TSym)
          constructor Create;
          procedure RegisterSym; override;
       end;

       { tprocsym }

       TProcSym = class(TStoredSym)
       protected type
          TProcDefComparer = function(pd:TProcDef;arg:TObject):TEqualType;
       protected
          FProcDefList   : TFPObjectList;
          FProcDefDerefList : TFPList;
          FGenProcSymOvlds : TFPObjectList;
          FGenProcSymOvldsDerefs : TFPList;

          function Find_ProcDef_With_Comparer(Comparer:TProcDefComparer;Arg:TObject):TProcDef;
          class function Compare_ProcVarDef(PD:TProcDef;Arg:TObject):TEqualType;static;
          class function Compare_FuncRefDef(PD:TProcDef;Arg:TObject):TEqualType;static;
       public
          constructor Create(const N : TSymStr);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          { writes all declarations except the specified one }
          procedure Write_Parameter_Lists(SkipDef:TProcDef);
          { tests, if all procedures definitions are defined and not }
          { only forward                                             }
          procedure Check_Forward; virtual;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function Find_ProcDef_ByType(PT:TProcTypeOption):TProcDef;
          function Find_ByType_Parameterless(PT:TProcTypeOption):TProcDef;
          function Find_ProcDef_ByPara(Para:TFPObjectList;RetDef:TDef;CPOptions:TCompareParasOptions):TProcDef;
          function Find_ProcDef_ByType_And_Para(PT:TProcTypeOption;Para:TFPObjectList;RetDef:TDef;CPOptions:TCompareParasOptions):TProcDef;
          function Find_ProcDef_ByOptions(Ops:TProcOptions): TProcDef;
          function Find_ProcDef_ByProcVarDef(D:TProcVarDef):TProcDef;
          function Find_ProcDef_ByFuncRefDef(D:TObjectDef):TProcDef;
          function Find_ProcDef_Assignment_Operator(FromDef,ToDef:TDef;var BestEq:TEqualType;IsExplicit:Boolean):TProcDef;
          function Find_ProcDef_Enumerator_Operator(FromDef,ToDef:TDef;var BestEq:TEqualType):TProcDef;
          procedure Add_Generic_Overload(Sym:TProcSym);
          function Could_Be_Implicitly_Specialized:Boolean;inline;
          property ProcdefList:TFPObjectList read FProcDefList;
          { only valid if sp_generic_dummy is set and either an overload was
            added using add_generic_overload or this was loaded from a ppu }
          property GenProcSymOvlds:TFPObjectList read FGenProcSymOvlds;
       end;
       TProcSymClass = class of TProcSym;

       TTypeSym = class(TStoredSym)
       public
          TypeDef      : TDef;
          TypeDefDeref : TDeref;
          FPrettyName : AnsiString;
          constructor Create(const N : TSymStr;Def:TDef);virtual;
          destructor Destroy;override;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function PrettyName : string;override;
       end;
       TTypeSymClass = class of TTypeSym;

       TAbstractVarSym = class(TStoredSym)
          VarOptions    : TVarOptions;
          VarSpez       : TVarSpez;  { sets the type of access }
          VarRegable    : TVarRegable;
          VarState      : TVarState;
          {could also be part of tabstractnormalvarsym, but there's
           one byte left here till the next 4 byte alignment        }
          VarSymAccess  : TVarSymAccessFlags;
          constructor Create(ST:TSymTyp;const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
          constructor PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          procedure BuildDeref;override;
          procedure Deref;override;
          function  GetSize : ASizeInt;
          function  GetPackedBitSize : LongInt;
          function  Is_RegVar(RefPara: Boolean):Boolean;
        private
          FVarDef     : TDef;
          VarDefDeref : TDeref;

          function GetAddrTaken: Boolean;
          function GetDifferentScope: Boolean;
          procedure SetRegable;
          procedure SetVarDef(const Def: TDef);
          procedure SetVarDefAndRegable(Def:TDef);
          procedure SetAddrTaken(AValue: Boolean);
          procedure SetDifferentScope(AValue: Boolean);
        public
          property VarDef: TDef read FVarDef write SetVarDefAndRegable;
          property AddrTaken: Boolean read GetAddrTaken write SetAddrTaken;
          property DifferentScope: Boolean read GetDifferentScope write SetDifferentScope;
      end;

      TFieldVarSym = class(TAbstractVarSym)
          { offset in record/object, for bitpacked fields the offset is
            given in bit, else in bytes }
          FieldOffset   : ASizeInt;

{$ifdef symansistr}
          CachedMangledName: TSymStr;
{$else symansistr}
          CachedMangledName: PShortString;
{$endif symansistr}
          constructor Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function BitOffset: ASizeUInt;
          function MangledName:TSymStr;override;
          destructor Destroy;override;
      end;
      TFieldVarSymClass = class of TFieldVarSym;

      TAbstractNormalVarSym = class(TAbstractVarSym)
          DefaultConstSym : TSym;
          DefaultConstSymDeref : TDeref;
          { register/reference for local var }
          LocAlloc      : TLocation;
          { initial location so it can still be initialized later after the location was changed by SSA }
          InitialLoc    : TLocation;
          { migrated to a parentfpstruct because of nested access (not written to ppu, because not important and would change interface crc) }
          InParentFPStruct : Boolean;
          { the variable is not living at entry of the scope, so it does not need to be initialized if it is a reg. var
            (not written to ppu, because not important and would change interface crc) }
          NoRegVarInitNeeded : Boolean;
          { not stored in PPU! }
          CaptureSym : TSym;
          constructor Create(ST:TSymTyp;const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
          constructor PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
          function GlobalAsmSym: Boolean;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          procedure BuildDeref;override;
          procedure Deref;override;
          function Is_Captured:Boolean;
      end;

      TLocalVarSym = class(TAbstractNormalVarSym)
          constructor Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
      end;
      TLocalVarSymClass = class of TLocalVarSym;

      TParaVarSym = class(TAbstractNormalVarSym)
          ParaLoc       : array[CallerSide..CalleeSide] of TCGPara;
          ParaNr        : Word; { position of this parameter }
          { in MacPas mode, "univ" parameters mean that type checking should
            be disabled, except that the size of the passed parameter must
            match the size of the formal parameter }
          UnivPara      : Boolean;
{$ifdef EXTDEBUG}
          EqVal         : TEqualType;
{$endif EXTDEBUG}
          constructor Create(const N : TSymStr;NR:Word;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function Needs_Finalization: Boolean;
          function Is_Used: Boolean;
      end;
      TParaVarSymClass = class of TParaVarSym;

      TStaticVarSym = class(TAbstractNormalVarSym)
      protected
{$ifdef symansistr}
          FMangledBaseName,
          FMangledName : TSymStr;
{$else symansistr}
          FMangledBaseName,
          FMangledName : PShortString;
{$endif symansistr}
      public
          Section : AnsiString;
          { if a text buffer has been defined as being initialized from command line
            parameters as it is done by iso pascal with the program symbols,
            isoindex contains the parameter number }
          IsoIndex : DWord;
          { if this static variable was created based on a class field variable then this is set
            to the symbol of the corresponding class field }
          FieldVarSym : TFieldVarSym;
          FieldVarSymDeref : TDeref;
          constructor Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);virtual;
          constructor Create_DLL(const N : TSymStr;VSP:TVarSpez;Def:TDef);virtual;
          constructor Create_C(const N: TSymStr; const Mangled : TSymStr;VSP:TVarSpez;Def:TDef);virtual;
          constructor Create_From_FieldVar(const N: TSymStr;FieldVar:TFieldVarSym);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function MangledName:TSymStr;override;
          procedure Set_MangledBaseName(const S: TSymStr);
          function MangledBaseName: TSymStr;
          procedure Set_MangledName(const S:TSymStr);virtual;
          procedure Set_Raw_MangledName(const S:TSymStr);
      end;
      TStaticVarSymClass = class of TStaticVarSym;

      TAbsoluteVarSym = class(TAbstractVarSym)
      public
         AbsTyp  : TAbsoluteTyp;
         AsmName : PShortString;
         AddrOffset : PUint;
         Ref     : TPropAccessList;
         constructor Create(const N : TSymStr;Def:TDef);virtual;
         constructor Create_Ref(const N : TSymStr;Def:TDef;ARef:TPropAccessList);virtual;
	 procedure Adjust_VarRegable;
         destructor  Destroy;override;
         constructor PPULoad(PPUFile:TCompilerPPUFile);
         procedure BuildDeref;override;
         procedure Deref;override;
         function  MangledName : TSymStr;override;
         { do not override this routine in platform-specific subclasses,
           override ppuwrite_platform instead }
         procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
         { returns the symbol type of the local variable or local parameter
           referenced by the absolute symbol }
         function RefTyp : TSymTyp;
      end;
      TAbsoluteVarSymClass = class of TAbsoluteVarSym;

       TPropAccessListTypes=(palt_none,palt_read,palt_write,palt_stored);

       TPropertySym = class(TStoredSym)
         protected
           procedure Finalize_Getter_Or_Setter_For_Sym(GetSet: TPropAccessListTypes; Sym: TSym; FieldDef: TDef; AccessorDef: TProcDef); virtual;
         public
          PropOptions   : TPropertyOptions;
          OverriddenPropSym : TPropertySym;
          OverriddenPropSymDeref : TDeref;
          PropDef       : TDef;
          PropDefDeref  : TDeref;
          IndexDef      : TDef;
          IndexDefDeref : TDeref;
          Index,
          default       : LongInt;
          DispID        : LongInt;
          PropAccessList: array[TPropAccessListTypes] of TPropAccessList;
          ParaST : TSymTable;
          constructor Create(const N : TSymStr);virtual;
          destructor  Destroy;override;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function  GetSize : ASizeInt;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function GetPropAccessList(PAP:TPropAccessListTypes;out PList:TPropAccessList):Boolean;
          { copies the settings of the current propertysym to p; a bit like
            a form of getcopy, but without the name }
          procedure MakeDuplicate(P: TPropertySym; ReadProcDef, WriteProcDef: TProcDef; out ParaNr: Word);
          procedure Add_Accessor_Parameters(ReadProcDef, WriteProcDef: TProcDef);
          procedure Add_Index_Parameter(var ParaNr: Word; ReadProcDef, WriteProcDef: TProcDef);
          { set up the accessors for this property }
          procedure Add_Getter_Or_Setter_For_Sym(GetSet: TPropAccessListTypes; Sym: TSym; FieldDef: TDef; AccessorDef: TProcDef);
          procedure Register_Override(OverriddenProp: TPropertySym);
          { inherit the read/write property }
          procedure Inherit_Accessor(GetSet: TPropAccessListTypes); virtual;
       end;
       TPropertySymClass = class of TPropertySym;

       TConstValue = record
         case Integer of
         0: (ValueOrd : TConstExprInt);
         1: (ValueOrdPtr : TConstPtrUInt);
         2: (ValuePtr : Pointer; Len : LongInt);
         3: (ValueWS : TCompilerWideString);
       end;

       TConstSym = class(TStoredSym)
          ConstDef    : TDef;
          ConstDefDeref : TDeref;
          ConstTyp    : TConstTyp;
          Value       : TConstValue;
          constructor Create_Ord(const N : TSymStr;T : TConstTyp;V : TConstExprInt;Def:TDef);virtual;
          constructor Create_OrdPtr(const N : TSymStr;T : TConstTyp;V : TConstPtrUInt;Def:TDef);virtual;
          constructor Create_Ptr(const N : TSymStr;T : TConstTyp;V : Pointer;Def:TDef);virtual;
          constructor Create_String(const N : TSymStr;T : TConstTyp;Str:PChar;L:LongInt;Def:TDef);virtual;
          constructor Create_WString(const N : TSymStr;T : TConstTyp;PW:TCompilerWideString);virtual;
          constructor Create_Undefined(const N : TSymStr;Def:TDef);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor  Destroy;override;
          procedure BuildDeref;override;
          procedure Deref;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
       end;
       TConstSymClass = class of TConstSym;

       TEnumSym = class(TStoredSym)
          Value      : LongInt;
          Definition : TEnumDef;
          DefinitionDeref : TDeref;
          constructor Create(const N : TSymStr;Def : TEnumDef;V : LongInt);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
       end;
       TEnumSymClass = class of TEnumSym;

       TSysSym = class(TStoredSym)
          Number : TInlineNumber;
          constructor Create(const N : TSymStr;L : TInlineNumber);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor  Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          class function Find_By_Number(L:LongInt):TSysSym;
       end;
       TSysSymClass = class of TSysSym;

    const
       MaxMacroLen=16*1024;

    type
       TMacro = class(TStoredSym)
          {Normally true, but false when a previously defined macro is undef-ed}
          Defined : Boolean;
          {True if this is a mac style compiler variable, in which case no macro
           substitutions shall be done.}
          IsCompilerVar : Boolean;
          { true if the macro is a C macro, i.e used := }
          IsCMacro : Boolean;
          {Whether the macro was used. NOTE: A use of a macro which was never defined}
          {e. g. an IFDEF which returns false, will not be registered as used,}
          {since there is no place to register its use. }
          IsUsed : Boolean;
          BufText : TAnsiCharDynArray;
          BufLen  : LongInt;
          constructor Create(const N : TSymStr);
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          destructor  Destroy;override;
          function Allocate_BufText(Len:LongInt) : PChar;
          procedure Free_BufText;
          function GetCopy:TMacro;
       end;

    var
       GenErrorSym : TSym;

       CLabelSym: TLabelSymClass;
       CUnitSym: TUnitSymClass;
       CProgramParaSym: TProgramParaSymClass;
       CNamespaceSym: TNamespaceSymClass;
       CProcSym: TProcSymClass;
       CTypeSym: TTypeSymClass;
       CFieldVarSym: TFieldVarSymClass;
       CLocalVarSym: TLocalVarSymClass;
       CParaVarSym: TParaVarSymClass;
       CStaticVarSym: TStaticVarSymClass;
       CAbsoluteVarSym: TAbsoluteVarSymClass;
       CPropertySym: TPropertySymClass;
       CConstSym: TConstSymClass;
       CEnumSym: TEnumSymClass;
       CSysSym: TSysSymClass;

    { generate internal static field name based on regular field name }
    function Internal_Static_Field_Name(const FieldName: TSymStr): TSymStr;
    function Get_High_Value_Sym(VS: TParaVarSym):TAbstractVarSym; { marking it as inline causes IE 200311075 during loading from ppu file }

    procedure Check_Hints(const SRSym: TSym; const SymOptions: TSymOptions; const DeprecatedMsg : PShortString);inline;
    procedure Check_Hints(const SRSym: TSym; const SymOptions: TSymOptions; const DeprecatedMsg : PShortString;FilePos:TFilePosInfo);

    function Same_ConstValue(ConstTyp:TConstTyp;const Value1,Value2:TConstValue):Boolean;

implementation

    uses
       { global }
       Verbose,CMsgs,
       { target }
       Systems,
       { symtable }
       DefUtil,SymTable,
       FModule,
       { tree }
       Node,
       { aasm }
       AAsmData,
       { codegen }
       ParaMgr,
       ProcInfo,
       { ppu }
       EntFile,PPU
       ;

{****************************************************************************
                               Helpers
****************************************************************************}

    function Internal_Static_Field_Name(const FieldName: TSymStr): TSymStr;
      begin
        Result:='$_static_'+FieldName;
      end;


    function Get_High_Value_Sym(VS: TParaVarSym):TAbstractVarSym;
      begin
        Result := TAbstractVarSym(VS.Owner.Find('high'+VS.Name));
      end;


    function Same_ConstValue(ConstTyp:TConstTyp;const Value1,Value2:TConstValue):Boolean;
      begin
        Result:=False;
        case ConstTyp of
          ConstNone,
          ConstNil:
            Result:=True;
          ConstOrd:
            Result:=Value1.ValueOrd=Value2.ValueOrd;
          ConstPointer:
            Result:=Value1.ValueOrdPtr=Value2.ValueOrdPtr;
          ConstString,
          ConstReal,
          ConstSet,
          ConstResourceString,
          ConstWResourceString,
          ConstWString,
          ConstGUID: begin
            if Value1.Len<>Value2.Len then
              Exit(False);
            Result:=CompareByte(Value1.ValuePtr^,Value2.ValuePtr^,Value1.Len)=0;
          end;
        end;
      end;


    procedure Check_Hints(const SRSym: TSym; const SymOptions: TSymOptions; const DeprecatedMsg : PShortString);
      begin
        Check_Hints(SRSym,SymOptions,DeprecatedMsg,CurrentFilePos);
      end;


    procedure Check_Hints(const SRSym: TSym; const SymOptions: TSymOptions; const DeprecatedMsg : PShortString;FilePos:TFilePosInfo);
      var
        Def : TDef;
        Name : TMsgStr;
      begin
        if not Assigned(SRSym) then
          InternalError(200602051);
        if SymOptions*[sp_hint_deprecated,sp_hint_experimental,sp_hint_platform,sp_hint_library,sp_hint_unimplemented]<>[] then
          begin
            Name:=SRSym.RealName;
            Def:=TDef(SRSym.Owner.DefOwner);
            if Assigned(Def) then
              Name:=Def.TypeSymbolPrettyName+'.'+Name;
          end
        else
          Name:='';
        if sp_hint_deprecated in SymOptions then
          if (sp_has_deprecated_msg in SymOptions) and (DeprecatedMsg <> nil) then
            MessagePos2(FilePos,sym_w_deprecated_symbol_with_msg,Name,DeprecatedMsg^)
          else
            MessagePos1(FilePos,sym_w_deprecated_symbol,Name);
        if sp_hint_experimental in SymOptions then
          MessagePos1(FilePos,sym_w_experimental_symbol,Name);
        if sp_hint_platform in SymOptions then
          MessagePos1(FilePos,sym_w_non_portable_symbol,Name);
        if sp_hint_library in SymOptions then
          MessagePos1(FilePos,sym_w_library_symbol,Name);
        if sp_hint_unimplemented in SymOptions then
          MessagePos1(FilePos,sym_w_non_implemented_symbol,Name);
      end;

{****************************************************************************
                          TSYM (base for all symtypes)
****************************************************************************}

    constructor TStoredSym.Create(ST:TSymTyp;const N : TSymStr);
      begin
         inherited Create(ST,N);
      end;


    constructor TStoredSym.PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
      begin
{$ifdef symansistr}
         inherited Create(ST,PPUFile.GetAnsiString);
{$else symansistr}
         inherited Create(ST,PPUFile.GetString);
{$endif symansistr}
         SymID:=PPUFile.GetLongInt;
         CurrentModule.SymList[SymID]:=Self;
         PPUFile.GetPosInfo(FileInfo);
         Visibility:=TVisibility(PPUFile.GetByte);
         PPUFile.GetSet(TPPUSet2(SymOptions));
         if sp_has_deprecated_msg in SymOptions then
           DeprecatedMsg:=PPUFile.GetPShortString
         else
           DeprecatedMsg:=nil;
         RTTIAttributeList:=TRTTIAttributeList.PPULoad(PPUFile);
      end;


    procedure TStoredSym.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldCRC : Boolean;
      begin
{$ifdef symansistr}
         PPUFile.PutAnsiString(RealName);
{$else}
         PPUFile.PutString(RealName);
{$endif}
         PPUFile.PutLongInt(SymID);
         PPUFile.PutPosInfo(FileInfo);
         PPUFile.PutByte(Byte(Visibility));
         { symoptions can differ between interface and implementation, except
           for overload (this is checked in pdecsub.proc_add_definition() )

           These differences can lead to compiler crashes, so ignore them.
           This does mean that changing e.g. the "deprecated" state of a symbol
           by itself will not trigger a recompilation of dependent units.
         }
         OldCRC:=PPUFile.DoCRC;
         PPUFile.DoCRC:=False;
         PPUFile.PutSet(TPPUSet2(SymOptions));
         if sp_has_deprecated_msg in SymOptions then
           PPUFile.PutString(DeprecatedMsg^);
         PPUFile.DoCRC:=OldCRC;
         TRTTIAttributeList.PPUWrite(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredSym.PPULoadSubEntries(PPUFile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPULoadSubEntries(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredSym.PPUWriteSubEntries(PPUFile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPUWriteSubEntries(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredSym.Deref;
      begin
        inherited;
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.Deref;
      end;


    procedure TStoredSym.BuildDeref;
      begin
        inherited;
        if not Registered then
          RegisterSym;
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.BuildDeref;
      end;


    procedure TStoredSym.WriteEntry(PPUFile: TCompilerPPUFile; IBNR: Byte);
      begin
        PPUWritePlatform(PPUFile);
        PPUFile.WriteEntry(IBNR);
      end;


    procedure TStoredSym.PPUWritePlatform(PPUFile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;

    procedure TStoredSym.PPULoadPlatform(PPUFile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    destructor TStoredSym.Destroy;
      begin
        RTTIAttributeList.Free;
        RTTIAttributeList := nil;
        inherited Destroy;
      end;


    procedure TStoredSym.RegisterSym;
      var
        TMod : TModule;
      begin
        if Registered then
          Exit;
        if Assigned(Owner) then
          begin
            TMod:=Find_Module_From_SymTable(Owner);
            if Assigned(TMod) and Assigned(CurrentModule) and (TMod<>CurrentModule) then
              begin
                Comment(VError,'Symbol '+RealName+' from module '+TMod.MainSource+' registered with current module '+CurrentModule.MainSource);
              end;
            if not Assigned(TMod) then
              TMod:=CurrentModule;
          end
        else
          TMod:=CurrentModule;
        { Register in current_module }
        if Assigned(TMod) then
          begin
            TMod.SymList.Add(Self);
            SymID:=TMod.SymList.Count-1;
          end
        else
          SymID:=SymIDRegisteredNoST;
      end;

{****************************************************************************
                                 TLABELSYM
****************************************************************************}

    constructor TLabelSym.Create(const N : TSymStr);
      begin
         inherited Create(LabelSym,N);
         Used:=False;
         Defined:=False;
         NonLocal:=False;
         Code:=nil;
      end;


    constructor TLabelSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(LabelSym,PPUFile);
         Code:=nil;
         Used:=False;
         NonLocal:=False;
         Defined:=True;
         PPULoadPlatform(PPUFile);
      end;


    procedure TLabelSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         if Owner.SymTableType=GlobalSymTable then
           Message(sym_e_ill_label_decl)
         else
           begin
              inherited PPUWrite(PPUFile);
              WriteEntry(PPUFile,IBLabelSym);
           end;
      end;


   function TLabelSym.MangledName:TSymStr;
     begin
       if (AsmBlockLabel=nil) then
         begin
           if NonLocal then
             CurrentAsmData.GetGlobalJumpLabel(AsmBlockLabel)
           else
             CurrentAsmData.GetJumpLabel(AsmBlockLabel);
         end;
       Result:=AsmBlockLabel.Name;
     end;

{****************************************************************************
                                  TUNITSYM
****************************************************************************}

    constructor TUnitSym.Create(const N : TSymStr;AModule : TObject);
      begin
         inherited Create(UnitSym,N);
         Module:=AModule;
      end;

    constructor TUnitSym.PPULoad(PPUFile:TCompilerPPUFile);

      begin
         inherited PPULoad(UnitSym,PPUFile);
         Module:=nil;
         PPULoadPlatform(PPUFile);
      end;

    destructor TUnitSym.Destroy;
      begin
         inherited Destroy;
      end;

    procedure TUnitSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         WriteEntry(PPUFile,IBUnitSym);
      end;

{****************************************************************************
                             TPROGRAMPARASYM
****************************************************************************}

    constructor TProgramParaSym.Create(const N : TSymStr; I : DWord);
      begin
         inherited Create(ProgramParaSym,N);
         IsoIndex:=I;
      end;

    constructor TProgramParaSym.PPULoad(PPUFile : TCompilerPPUFile);
      begin
        { program parameter syms (iso pascal style) might be never written to a ppu }
        InternalError(2015050102);
      end;

    destructor TProgramParaSym.Destroy;
      begin
       inherited Destroy;
      end;

    procedure TProgramParaSym.PPUWrite(PPUFile : TCompilerPPUFile);
      begin
        { program parameter syms (iso pascal style) might be never written to a ppu }
        InternalError(2015050101);
      end;


{****************************************************************************
                                TNAMESPACESYM
****************************************************************************}

    constructor TNamespaceSym.Create(const N : TSymStr);
      begin
         inherited Create(NamespaceSym,N);
         UnitSym:=nil;
         UnitSymDeref.Reset;
      end;

    constructor TNamespaceSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(NamespaceSym,PPUFile);
         PPUFile.GetDeref(UnitSymDeref);
         PPULoadPlatform(PPUFile);
      end;

    procedure TNamespaceSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(UnitSymDeref);
         WriteEntry(PPUFile,IBNamespaceSym);
      end;

    procedure TNamespaceSym.BuildDeref;
      begin
        inherited BuildDeref;
        UnitSymDeref.Build(UnitSym);
      end;

    procedure TNamespaceSym.Deref;
      begin
        inherited Deref;
        UnitSym:=TSym(UnitSymDeref.Resolve);
      end;


{****************************************************************************
                                  TPROCSYM
****************************************************************************}

    constructor TProcSym.Create(const N : TSymStr);
      begin
         inherited Create(ProcSym,N);
         FProcDefList:=TFPObjectList.Create(False);
         FProcDefDerefList:=nil;
         { the tprocdef have their own symoptions, make the procsym
           always visible }
         Visibility:=vis_public;
      end;


    constructor TProcSym.PPULoad(PPUFile:TCompilerPPUFile);
      var
         SymDeref,
         PDDeref : TDeref;
         I,
         SymCnt,
         PDCnt : LongInt;
      begin
         inherited PPULoad(ProcSym,PPUFile);
         FProcDefList:=TFPObjectList.Create(False);
         FProcDefDerefList:=TFPList.Create;
         PDCnt:=PPUFile.GetWord;
         for I:=1 to PDCnt do
          begin
            PPUFile.GetDeref(PDDeref);
            FProcDefDerefList.Add(Pointer(PtrInt(PDDeref.DataIdx)));
          end;
         if sp_generic_dummy in SymOptions then
           begin
             FGenProcSymOvlds:=TFPObjectList.Create(False);
             FGenProcSymOvldsDerefs:=TFPList.Create;
             SymCnt:=PPUFile.GetWord;
             for I:=1 to SymCnt do
               begin
                 PPUFile.GetDeref(SymDeref);
                 FGenProcSymOvldsDerefs.Add(Pointer(PtrInt(SymDeref.DataIdx)));
               end;
           end;
         PPULoadPlatform(PPUFile);
      end;


    destructor TProcSym.Destroy;
      begin
        FProcDefList.Free;
        FProcDefList := nil;
        FProcDefDerefList.Free;
        FProcDefDerefList := nil;
        FGenProcSymOvlds.Free;
        FGenProcSymOvlds := nil;
        FGenProcSymOvldsDerefs.Free;
        FGenProcSymOvldsDerefs := nil;
        inherited Destroy;
      end;


    procedure TProcSym.PPUWrite(PPUFile:TCompilerPPUFile);
      var
         I : LongInt;
         D : TDeref;
      begin
         inherited PPUWrite(PPUFile);
         if FProcDefDerefList=nil then
           InternalError(2013121801);
         PPUFile.PutWord(FProcDefDerefList.Count);
         for I:=0 to FProcDefDerefList.Count-1 do
           begin
             D.DataIdx:=PtrInt(FProcDefDerefList[I]);
             PPUFile.PutDeref(D);
           end;
         if sp_generic_dummy in SymOptions then
           begin
             if not Assigned(FGenProcSymOvldsDerefs) then
               InternalError(2021010301);
             PPUFile.PutWord(FGenProcSymOvldsDerefs.Count);
             for I:=0 to FGenProcSymOvldsDerefs.Count-1 do
               begin
                 D.DataIdx:=PtrInt(FGenProcSymOvldsDerefs[I]);
                 PPUFile.PutDeref(D);
               end;
           end;
         WriteEntry(PPUFile,IBProcSym);
      end;


    procedure TProcSym.Write_Parameter_Lists(SkipDef:TProcDef);
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if PD<>SkipDef then
              MessagePos1(PD.FileInfo,sym_e_param_list,PD.FullProcName(False));
           end;
      end;


    procedure TProcSym.Check_Forward;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            { Don't check for is_specialization, but whether it's somehow part
              of a specialization }
            if (PD.Owner=Owner) and (PD.ForwardDef) and not (df_specialization in PD.DefOptions) then
              begin
                { For mode macpas. Make implicit externals (procedures declared in the interface
                  section which do not have a counterpart in the implementation)
                  to be an imported procedure }
                if (m_mac in CurrentSettings.ModeSwitches) and
                   (PD.InterfaceDef) then
                  begin
                    PD.SetMangledName(TargetInfo.CPrefix+TProcDef(PD).ProcSym.RealName);
                    if (not CurrentModule.InterfaceOnly) then
                      MessagePos1(PD.FileInfo,sym_w_forward_not_resolved,PD.FullProcName(False));
                  end
                else
                  begin
                    MessagePos1(PD.FileInfo,sym_e_forward_not_resolved,PD.FullProcName(False));
                  end;
                { Turn further error messages off }
                PD.ForwardDef:=False;
              end;
          end;
      end;


    procedure TProcSym.BuildDeref;
      var
        I  : LongInt;
        PD : TProcDef;
        D  : TDeref;
        Sym : TProcSym;
      begin
        inherited;
        if not Assigned(FProcDefDerefList) then
          FProcDefDerefList:=TFPList.Create
        else
          FProcDefDerefList.Clear;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            { only write the proc definitions that belong
              to this procsym and are in the global symtable }
            if PD.Owner=Owner then
              begin
                D.Build(PD);
                FProcDefDerefList.Add(Pointer(PtrInt(D.DataIdx)));
              end;
          end;
        if sp_generic_dummy in SymOptions then
          begin
            if not Assigned(FGenProcSymOvldsDerefs) then
              FGenProcSymOvldsDerefs:=TFPList.Create
            else
              FGenProcSymOvldsDerefs.Clear;
            { this might happen for procsyms in classes that override symbols
              in a parent class that generic overloads }
            if Assigned(FGenProcSymOvlds) then
              begin
                FGenProcSymOvldsDerefs.Capacity:=FGenProcSymOvldsDerefs.Count+FGenProcSymOvlds.Count;
                for I:=0 to FGenProcSymOvlds.Count-1 do
                  begin
                    Sym:=TProcSym(FGenProcSymOvlds[I]);
                    D.Build(Sym);
                    FGenProcSymOvldsDerefs.Add(Pointer(PtrInt(D.DataIdx)));
                  end;
              end;
          end;
      end;


    procedure TProcSym.Deref;
      var
        I  : LongInt;
        PD : TProcDef;
        D  : TDeref;
        Sym : TSym;
      begin
        { Clear all procdefs }
        ProcdefList.Clear;
        if not Assigned(FProcDefDerefList) then
          InternalError(200611031);
        ProcdefList.Capacity:=FProcDefDerefList.Count;
        for I:=0 to FProcDefDerefList.Count-1 do
          begin
            D.DataIdx:=PtrInt(FProcDefDerefList[I]);
            PD:=TProcDef(D.Resolve);
            ProcdefList.Add(PD);
          end;
        if sp_generic_dummy in SymOptions then
          begin
            {if not assigned(fgenprocsymovlds) then
              internalerror(2021010603);}
            if not Assigned(FGenProcSymOvldsDerefs) then
              InternalError(2021010302);
            if Assigned(FGenProcSymOvlds) then
              begin
                FGenProcSymOvlds.Clear;
                FGenProcSymOvlds.Capacity:=FGenProcSymOvldsDerefs.Count;
                for I:= 0 to FGenProcSymOvldsDerefs.Count-1 do
                  begin
                    D.DataIdx:=PtrInt(FGenProcSymOvldsDerefs[I]);
                    Sym:=TProcSym(D.Resolve);
                    FGenProcSymOvlds.Add(Sym);
                  end;
              end;
          end;
      end;

    function TProcSym.Find_ProcDef_ByType(PT:TProcTypeOption):TProcDef;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        Result:=nil;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if PD.ProcTypeOption=PT then
              begin
                Result:=PD;
                Exit;
              end;
          end;
      end;


    function TProcSym.Find_ByType_Parameterless(PT: TProcTypeOption): TProcDef;
      var
        I,J : LongInt;
        PD  : TProcDef;
        Found : Boolean;
      begin
        Result:=nil;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if (PD.ProcTypeOption=PT) then
              begin
                Found:=True;
                for J:=0 to PD.Paras.Count-1 do
                  begin
                    if not(vo_is_hidden_para in TParaVarSym(PD.Paras[J]).VarOptions) then
                      begin
                        Found:=False;
                        Break;
                      end;
                  end;
                if Found then
                  begin
                    Result:=PD;
                    Exit;
                  end;
              end;
          end;
      end;


    function CheckProcDefParas(PD:TProcDef;Para:TFPObjectList;RetDef:TDef;
                                            CPOptions:TCompareParasOptions): TProcDef;
      var
        EQ: TEqualType;
      begin
        Result:=nil;
        if Assigned(RetDef) then
          EQ:=Compare_Defs(RetDef,PD.ReturnDef,NothingN)
        else
          EQ:=te_equal;
        if (EQ>=te_equal) or
           ((cpo_allowconvert in CPOptions) and (EQ>te_incompatible)) then
          begin
            EQ:=Compare_Paras(Para,PD.Paras,cp_value_equal_const,CPOptions);
            if (EQ>=te_equal) or
               ((cpo_allowconvert in CPOptions) and (EQ>te_incompatible)) then
              begin
                Result:=PD;
                Exit;
              end;
          end;
      end;


    function TProcSym.Find_ProcDef_ByPara(Para:TFPObjectList;RetDef:TDef;
                                            CPOptions:TCompareParasOptions):TProcDef;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        Result:=nil;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            Result:=CheckProcDefParas(PD,Para,RetDef,CPOptions);
            if Assigned(Result) then
              Exit;
          end;
      end;


    function TProcSym.Find_ProcDef_ByType_And_Para(PT:TProcTypeOption;
               Para:TFPObjectList;RetDef:TDef;CPOptions:TCompareParasOptions):TProcDef;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        Result:=nil;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if PD.ProcTypeOption=PT then
              begin
                Result:=CheckProcDefParas(PD,Para,RetDef,CPOptions);
                if Assigned(Result) then
                  Exit;
              end;
          end;
      end;


    function TProcSym.Find_ProcDef_ByOptions(Ops: TProcOptions): TProcDef;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        Result:=nil;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if Ops * PD.ProcOptions = Ops then
              begin
                Result:=PD;
                Exit;
              end;
          end;
      end;

    function TProcSym.Find_ProcDef_With_Comparer(Comparer:TProcDefComparer;Arg:TObject):TProcDef;
      var
        I  : LongInt;
        BestPD,
        PD : TProcDef;
        EQ,BestEq : TEqualType;
        Sym: TSym;
        PS: TProcSym;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for procvardef. When there are multiple
          matches it returns nil.}
        Result:=nil;
        BestPD:=nil;
        BestEq:=te_incompatible;
        PS:=Self;
        repeat
          for I:=0 to PS.ProcdefList.Count-1 do
            begin
              PD:=TProcDef(PS.ProcdefList[I]);
              EQ:=Comparer(PD,Arg);
              if EQ>=te_convert_l1 then
                begin
                  { multiple procvars with the same equal level }
                  if Assigned(BestPD) and
                     (BestEq=EQ) then
                    Exit;
                  if EQ>BestEq then
                    begin
                      BestEq:=EQ;
                      BestPD:=PD;
                    end;
                end;
            end;
          { maybe TODO: also search class helpers? -- this code is similar to
            what happens in htypechk in
            tcallcandidates.collect_overloads_in_struct: keep searching in
            parent types in case the currently found procdef is marked as
            "overload" and we haven't found a proper match yet }
          if Assigned(PS.Owner.DefOwner) and
             (PS.Owner.DefOwner.Typ=ObjectDef) and
             Assigned(TObjectDef(PS.Owner.DefOwner).ChildOf) and
             (not Assigned(BestPD) or
              (po_overload in BestPD.ProcOptions)) then
            begin
              Sym:=TSym(TObjectDef(PS.Owner.DefOwner).ChildOf.SymTable.Find(PS.Name));
              if Assigned(Sym) and
                 (Sym.Typ=ProcSym) then
                PS:=TProcSym(Sym)
              else
                PS:=nil;
            end
          else
            PS:=nil;
        until (BestEq>=te_equal) or
              not Assigned(PS);
        Result:=BestPD;
      end;


    class function TProcSym.Compare_ProcVarDef(PD:TProcDef;Arg:TObject):TEqualType;
      begin
        Result:=Proc_To_ProcVar_Equal(PD,TProcVarDef(Arg),False);
      end;


    class function TProcSym.Compare_FuncRefDef(PD:TProcDef;Arg:TObject):TEqualType;
      begin
        Result:=Proc_To_FuncRef_Equal(PD,TObjectDef(Arg));
      end;


    function TProcSym.Find_ProcDef_ByProcVarDef(D:TProcVarDef):TProcDef;
      begin
        Result:=Find_ProcDef_With_Comparer(@Compare_ProcVarDef,D);
      end;


    function TProcSym.Find_ProcDef_ByFuncRefDef(D:TObjectDef):TProcDef;
      begin
        if not Is_Invokable(D) then
          InternalError(2022033001);
        Result:=Find_ProcDef_With_Comparer(@Compare_FuncRefDef,D);
      end;


    function TProcSym.Find_ProcDef_Assignment_Operator(FromDef,ToDef:TDef;var BestEq:TEqualType;IsExplicit:Boolean):TProcDef;
      var
        ParaIdx, RealParamCount,
        I, J : LongInt;
        BestPD,
        HPD,
        PD : TProcDef;
        ConvTyp : TConvertType;
        EQ      : TEqualType;
        ShortStringCount : LongInt;
        CheckShortString,
        IsGenShortString : Boolean;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for fromdef and todef. }
        Result:=nil;
        BestPD:=nil;
        BestEq:=te_incompatible;
        { special handling for assignment operators overloads to shortstring:
          for implicit assignment we pick the ShortString one if available and
          only pick one with specific length if it is the *only* one }
        ShortStringCount:=0;
        CheckShortString:=not IsExplicit and
                          Is_ShortString(ToDef) and
                          (TStringDef(ToDef).Len<>255);
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if (PD.Owner.SymTableType=StaticSymTable) and not PD.Owner.IsCurrentUnit then
              Continue;
            if (Equal_Defs(ToDef,PD.ReturnDef) or
                { shortstrings of different lengths are ok as result }
                (not IsExplicit and Is_ShortString(ToDef) and Is_ShortString(PD.ReturnDef))) and
               { the result type must be always really equal and not an alias,
                 if you mess with this code, check tw4093 }
               ((ToDef=PD.ReturnDef) or
                (
                  not(df_unique in ToDef.DefOptions) and
                  not(df_unique in PD.ReturnDef.DefOptions)
                )
               ) then
              begin
                ParaIdx:=0;
                { ignore vs_hidden parameters }
                while (ParaIdx<PD.Paras.Count) and
                      Assigned(PD.Paras[ParaIdx]) and
                      (vo_is_hidden_para in TParaVarSym(PD.Paras[ParaIdx]).VarOptions) do
                  Inc(ParaIdx);
                RealParamCount:=0;
                for J := 0 to PD.Paras.Count-1 do
                  if Assigned(PD.Paras[J]) and not (vo_is_hidden_para in TParaVarSym(PD.Paras[J]).VarOptions) then
                    Inc(RealParamCount);
                if (ParaIdx<PD.Paras.Count) and
                   Assigned(PD.Paras[ParaIdx]) and
                   (RealParamCount = 1) then
                  begin
                    EQ:=Compare_Defs_Ext(FromDef,TParaVarSym(PD.Paras[ParaIdx]).VarDef,NothingN,ConvTyp,HPD,[]);

                    { alias? if yes, only l1 choice,
                      if you mess with this code, check tw4093 }
                    if (EQ=te_exact) and
                       (FromDef<>TParaVarSym(PD.Paras[ParaIdx]).VarDef) and
                       ((df_unique in FromDef.DefOptions) or
                       (df_unique in TParaVarSym(PD.Paras[ParaIdx]).VarDef.DefOptions)) then
                      EQ:=te_convert_l1;

                    IsGenShortString:=False;
                    if CheckShortString and Is_ShortString(PD.ReturnDef) then
                      if TStringDef(PD.ReturnDef).Len<>255 then
                        Inc(ShortStringCount)
                      else
                        IsGenShortString:=True;

                    if (EQ=te_exact) and (not CheckShortString or IsGenShortString) then
                      begin
                        BestEq:=EQ;
                        Result:=PD;
                        Exit;
                      end;
                    if EQ>BestEq then
                      begin
                        BestPD:=PD;
                        BestEq:=EQ;
                      end;
                  end;
              end;
          end;
        if CheckShortString and (ShortStringCount>1) then
          begin
            BestEq:=te_incompatible;
            BestPD:=nil;
          end;
        Result:=BestPD;
      end;

      function TProcSym.Find_ProcDef_Enumerator_Operator(FromDef,ToDef:TDef;var BestEq:TEqualType):TProcDef;
      var
        ParaIdx, RealParamCount,
        I, J : LongInt;
        BestPD,
        HPD,
        PD : TProcDef;
        Current : TPropertySym;
        ConvTyp : TConvertType;
        EQ      : TEqualType;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for fromdef and todef. }
        Result:=nil;
        BestPD:=nil;
        BestEq:=te_incompatible;
        for I:=0 to ProcdefList.Count-1 do
          begin
            PD:=TProcDef(ProcdefList[I]);
            if (PD.Owner.SymTableType=StaticSymTable) and not PD.Owner.IsCurrentUnit then
              Continue;
            if not (Is_Class_Or_Interface_Or_Object(PD.ReturnDef) or Is_Record(PD.ReturnDef)) then
              Continue;
            Current := TPropertySym(TAbstractRecordDef(PD.ReturnDef).Search_Enumerator_Current);
            if (Current = nil) then
              Continue;
            // compare current result def with the todef
            if (Equal_Defs(ToDef, Current.PropDef) or
                { shortstrings of different lengths are ok as result }
                (Is_ShortString(ToDef) and Is_ShortString(Current.PropDef))) and
               { the result type must be always really equal and not an alias,
                 if you mess with this code, check tw4093 }
               ((ToDef=Current.PropDef) or
                (
                  not(df_unique in ToDef.DefOptions) and
                  not(df_unique in Current.PropDef.DefOptions)
                )
               ) then
              begin
                ParaIdx:=0;
                { ignore vs_hidden parameters }
                while (ParaIdx<PD.Paras.Count) and
                      Assigned(PD.Paras[ParaIdx]) and
                      (vo_is_hidden_para in TParaVarSym(PD.Paras[ParaIdx]).VarOptions) do
                  Inc(ParaIdx);
                RealParamCount:=0;
                for J := 0 to PD.Paras.Count-1 do
                  if Assigned(PD.Paras[J]) and not (vo_is_hidden_para in TParaVarSym(PD.Paras[J]).VarOptions) then
                    Inc(RealParamCount);
                if (ParaIdx<PD.Paras.Count) and
                   Assigned(PD.Paras[ParaIdx]) and
                   (RealParamCount = 1) then
                  begin
                    EQ:=Compare_Defs_Ext(FromDef,TParaVarSym(PD.Paras[ParaIdx]).VarDef,NothingN,ConvTyp,HPD,[]);

                    { alias? if yes, only l1 choice,
                      if you mess with this code, check tw4093 }
                    if (EQ=te_exact) and
                       (FromDef<>TParaVarSym(PD.Paras[ParaIdx]).VarDef) and
                       ((df_unique in FromDef.DefOptions) or
                       (df_unique in TParaVarSym(PD.Paras[ParaIdx]).VarDef.DefOptions)) then
                      EQ:=te_convert_l1;

                    if EQ=te_exact then
                      begin
                        BestEq:=EQ;
                        Result:=PD;
                        Exit;
                      end;
                    if EQ>BestEq then
                      begin
                        BestPD:=PD;
                        BestEq:=EQ;
                      end;
                  end;
              end;
          end;
        Result:=BestPD;
      end;


    procedure TProcSym.Add_Generic_Overload(Sym:TProcSym);
      var
        I : LongInt;
      begin
        if not (sp_generic_dummy in SymOptions) then
          InternalError(2021010601);
        if not Assigned(FGenProcSymOvlds) then
          FGenProcSymOvlds:=TFPObjectList.Create(False);
        for I:=0 to GenProcSymOvlds.Count-1 do
          if TProcSym(GenProcSymOvlds[I])=Sym then
            Exit;
        GenProcSymOvlds.Add(Sym);
      end;


    function TProcSym.Could_Be_Implicitly_Specialized:Boolean;
      begin
        Result:=(m_implicit_function_specialization in CurrentSettings.ModeSwitches) and
                (sp_generic_dummy in SymOptions) and
                Assigned(GenProcSymOvlds);
      end;

{****************************************************************************
                                  TERRORSYM
****************************************************************************}

    constructor TErrorSym.Create;
      begin
        inherited Create(ErrorSym,'');
      end;


    procedure TErrorSym.RegisterSym;
      begin
        { these should never be written to a ppu file, since they don't
          derive from tstoredsym }
        InternalError(2015101801);
      end;

{****************************************************************************
                                TPROPERTYSYM
****************************************************************************}

    procedure TPropertySym.Finalize_Getter_Or_Setter_For_Sym(GetSet: TPropAccessListTypes; Sym: TSym; FieldDef: TDef; AccessorDef: TProcDef);
      begin
        { do nothing by default }
      end;


    constructor TPropertySym.Create(const N : TSymStr);
      var
        PAP : TPropAccessListTypes;
      begin
         inherited Create(PropertySym,N);
         PropOptions:=[];
         Index:=0;
         default:=0;
         PropDef:=nil;
         PropDefDeref.Reset;
         IndexDef:=nil;
         IndexDefDeref.Reset;
         ParaST:=nil;
         for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
           PropAccessList[PAP]:=TPropAccessList.Create;
      end;


    constructor TPropertySym.PPULoad(PPUFile:TCompilerPPUFile);
      type
         TSmallInterval = 0..31;
         TSmallSet = set of TSmallInterval;
         PSmallSet = ^TSmallSet;
      var
        PAP : TPropAccessListTypes;
        D : BestReal;
        S : Single;
        ASet : TSmallSet;
      begin
         inherited PPULoad(PropertySym,PPUFile);
         PPUFile.GetSet(TPPUSet2(PropOptions));
         if ppo_overrides in PropOptions then
           PPUFile.GetDeref(OverriddenPropSymDeref);
         PPUFile.GetDeref(PropDefDeref);
         Index:=PPUFile.GetLongInt;
         if ppo_default_is_single in PropOptions then
           begin
             D:=PPUFile.GetReal;
	     S:=Single(D);
             default:=PLongInt(@S)^;
           end
         else if ppo_default_is_set in PropOptions then
           begin
             PPUFile.GetSet(TPPUSet4(ASet));
             default:=PLongInt(@ASet)^;
           end
         else
           default:=PPUFile.GetLongInt;
         PPUFile.GetDeref(IndexDefDeref);
         for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
           PropAccessList[PAP]:=PPUFile.GetPropAccessList;
         PPULoadPlatform(PPUFile);
         if [ppo_hasparameters,ppo_overrides]*PropOptions=[ppo_hasparameters] then
           begin
             ParaST:=TParaSymTable.Create(nil,0);
             TParaSymTable(ParaST).PPULoad(PPUFile);
           end
         else
           ParaST:=nil;
      end;


    destructor TPropertySym.Destroy;
      var
        PAP : TPropAccessListTypes;
      begin
         for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
           FreeAndNil(PropAccessList[PAP]);
         ParaST.Free;
         ParaST := nil;
         inherited Destroy;
      end;


    procedure TPropertySym.BuildDeref;
      var
        PAP : TPropAccessListTypes;
      begin
        inherited;
        PropDefDeref.Build(PropDef);
        IndexDefDeref.Build(IndexDef);
        for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
          PropAccessList[PAP].BuildDeref;
        if ppo_overrides in PropOptions then
          OverriddenPropSymDeref.Build(OverriddenPropSym)
        else
        if ppo_hasparameters in PropOptions then
          TParaSymTable(ParaST).BuildDeref;
      end;


    procedure TPropertySym.Deref;
      var
        PAP : TPropAccessListTypes;
      begin
        IndexDef:=TDef(IndexDefDeref.Resolve);
        PropDef:=TDef(PropDefDeref.Resolve);
        for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
          PropAccessList[PAP].Resolve;

        if ppo_overrides in PropOptions then
          begin
            OverriddenPropSym:=TPropertySym(OverriddenPropSymDeref.Resolve);
            if ppo_hasparameters in PropOptions then
              ParaST:=OverriddenPropSym.ParaST.GetCopy;
          end
        else
        if ppo_hasparameters in PropOptions then
          TParaSymTable(ParaST).Deref(False)
      end;


    function TPropertySym.GetPropAccessList(PAP:TPropAccessListTypes;out PList:TPropAccessList):Boolean;
    var
      HPropSym : TPropertySym;
    begin
      Result:=False;
      { find property in the overridden list }
      HPropSym:=Self;
      repeat
        PList:=HPropSym.PropAccessList[PAP];
        if not PList.Empty then
          begin
            Result:=True;
            Exit;
          end;
        HPropSym:=HPropSym.OverriddenPropSym;
      until not Assigned(HPropSym);
    end;


    procedure TPropertySym.Add_Accessor_Parameters(ReadProcDef, WriteProcDef: TProcDef);
      var
        I: Integer;
        Orig, HParaVS: TParaVarSym;
      begin
        for I := 0 to ParaST.SymList.Count - 1 do
          begin
            Orig:=TParaVarSym(ParaST.SymList[I]);
            if Assigned(ReadProcDef) then
              begin
                HParaVS:=CParaVarSym.Create(Orig.RealName,Orig.ParaNr,Orig.VarSpez,Orig.VarDef,[]);
                ReadProcDef.ParaST.InsertSym(HParaVS);
              end;
            if Assigned(WriteProcDef) then
              begin
                HParaVS:=CParaVarSym.Create(Orig.RealName,Orig.ParaNr,Orig.VarSpez,Orig.VarDef,[]);
                WriteProcDef.ParaST.InsertSym(HParaVS);
              end;
          end;
      end;


    procedure TPropertySym.Add_Index_Parameter(var ParaNr: Word; ReadProcDef, WriteProcDef: TProcDef);
      var
        HParaVS: TParaVarSym;
      begin
        Inc(ParaNr);
        if Assigned(ReadProcDef) then
          begin
            HParaVS:=CParaVarSym.Create('$index',10*ParaNr,vs_value,IndexDef,[]);
            ReadProcDef.ParaST.InsertSym(HParaVS);
          end;
        if Assigned(WriteProcDef) then
          begin
            HParaVS:=CParaVarSym.Create('$index',10*ParaNr,vs_value,IndexDef,[]);
            WriteProcDef.ParaST.InsertSym(HParaVS);
          end;
      end;


    procedure TPropertySym.Add_Getter_Or_Setter_For_Sym(GetSet: TPropAccessListTypes; Sym: TSym; FieldDef: TDef; AccessorDef: TProcDef);
      var
        CPO: TCompareParasOptions;
      begin
        case Sym.Typ of
          ProcSym :
            begin
              { search procdefs matching accessordef }
              { we ignore hidden stuff here because the property access symbol might have
                non default calling conventions which might change the hidden stuff;
                see tw3216.pas (FK) }
              CPO:=[cpo_allowdefaults,cpo_ignorehidden];
              { allow var-parameters for setters in case of VARPROPSETTER+ }
              if (GetSet=palt_write) and
                 (cs_varpropsetter in CurrentSettings.LocalSwitches) then
                Include(CPO,cpo_ignorevarspez);
              PropAccessList[GetSet].ProcDef:=TProcSym(Sym).Find_ProcDef_ByPara(AccessorDef.Paras,AccessorDef.ReturnDef,CPO);
              if not Assigned(PropAccessList[GetSet].ProcDef) or
                 { because of cpo_ignorehidden we need to compare if it is a static class method and we have a class property }
                 ((sp_static in SymOptions)<>TProcDef(PropAccessList[GetSet].ProcDef).No_Self_Node) then
                Message(parser_e_ill_property_access_sym)
              else
                Finalize_Getter_Or_Setter_For_Sym(GetSet,Sym,FieldDef,AccessorDef);
            end;
          FieldVarSym :
            begin
              if not Assigned(FieldDef) then
                InternalError(200310071);
              if Compare_Defs(FieldDef,PropDef,NothingN)>=te_equal then
               begin
                 { property parameters are allowed if this is
                   an indexed property, because the index is then
                   the parameter.
                   Note: In the help of Kylix it is written
                   that it isn't allowed, but the compiler accepts it (PFV) }
                 if (ppo_hasparameters in PropOptions) or
                    ((sp_static in SymOptions) <> (sp_static in Sym.SymOptions)) then
                   Message(parser_e_ill_property_access_sym)
                 else
                   Finalize_Getter_Or_Setter_For_Sym(GetSet,Sym,FieldDef,AccessorDef);
               end
              else
               IncompatibleTypes(FieldDef,PropDef);
            end;
          else
            Message(parser_e_ill_property_access_sym);
        end;
      end;


    procedure TPropertySym.Register_Override(OverriddenProp: TPropertySym);
      begin
        OverriddenPropSym:=TPropertySym(OverriddenProp);
        Include(PropOptions,ppo_overrides);
      end;


    procedure TPropertySym.Inherit_Accessor(GetSet: TPropAccessListTypes);
      begin
        { nothing to do by default }
      end;


    procedure TPropertySym.MakeDuplicate(P: TPropertySym; ReadProcDef, WriteProcDef: TProcDef; out ParaNr: Word);
      begin
        { inherit all type related entries }
        P.IndexDef:=IndexDef;
        P.PropDef:=PropDef;
        P.Index:=Index;
        P.default:=default;
        P.PropOptions:=PropOptions;
        ParaNr:=0;
        if ppo_hasparameters in PropOptions then
          begin
            P.ParaST:=ParaST.GetCopy;
            P.Add_Accessor_Parameters(ReadProcDef,WriteProcDef);
            ParaNr:=P.ParaST.SymList.Count;
          end;
        if ppo_indexed in P.PropOptions then
          P.Add_Index_Parameter(ParaNr,ReadProcDef,WriteProcDef);
      end;


    function TPropertySym.GetSize : ASizeInt;
      begin
         GetSize:=0;
      end;


    procedure TPropertySym.PPUWrite(PPUFile:TCompilerPPUFile);
      type
         TSmallInterval = 0..31;
         TSmallSet = set of TSmallInterval;
         PSmallSet = ^TSmallSet;
      var
        PAP : TPropAccessListTypes;
        S : Single;
        ASet : TSmallSet;
      begin
        inherited PPUWrite(PPUFile);
        PPUFile.PutSet(TPPUSet2(PropOptions));
        if ppo_overrides in PropOptions then
          PPUFile.PutDeref(OverriddenPropSymDeref);
        PPUFile.PutDeref(PropDefDeref);
        PPUFile.PutLongInt(Index);
        if ppo_default_is_single in PropOptions then
          begin
            S:=PSingle(@default)^;
            PPUFile.PutReal(S);
          end
        else if ppo_default_is_set in PropOptions then
          begin
            ASet:=PSmallSet(@default)^;
            PPUFile.PutSet(TPPUSet4(ASet));
          end
        else
          PPUFile.PutLongInt(default);
        PPUFile.PutDeref(IndexDefDeref);
        for PAP:=Low(TPropAccessListTypes) to High(TPropAccessListTypes) do
          PPUFile.PutPropAccessList(PropAccessList[PAP]);
        WriteEntry(PPUFile,IBPropertySym);
        if [ppo_hasparameters,ppo_overrides]*PropOptions=[ppo_hasparameters] then
          TParaSymTable(ParaST).PPUWrite(PPUFile);
      end;

{****************************************************************************
                            TABSTRACTVARSYM
****************************************************************************}

    constructor TAbstractVarSym.Create(ST:TSymTyp;const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(ST,N);
         VarDef:=Def;
         VarDefDeref.Reset;
         VarSpez:=VSP;
         VarState:=vs_declared;
         VarOptions:=VOpts;
      end;


    constructor TAbstractVarSym.PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ST,PPUFile);
         VarState:=vs_readwritten;
         VarSpez:=TVarSpez(PPUFile.GetByte);
         VarRegable:=TVarRegable(PPUFile.GetByte);
         PPUFile.GetSet(TPPUSet1(VarSymAccess));
         PPUFile.GetDeref(VarDefDeref);
         PPUFile.GetSet(TPPUSet4(VarOptions));
      end;


    procedure TAbstractVarSym.BuildDeref;
      begin
        inherited;
        VarDefDeref.Build(VarDef);
      end;


    procedure TAbstractVarSym.Deref;
      begin
        { assigning vardef also updates varregable. We just loaded this   }
        { value from a ppu, so it must not be changed (e.g. tw7817a.pas/   }
        { tw7817b.pas: the address is taken of a local variable in an      }
        { inlined procedure -> must remain non-regable when inlining)     }
        SetVarDef(TDef(VarDefDeref.Resolve));
      end;


    procedure TAbstractVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldCRC : Boolean;
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(VarSpez));
         OldCRC:=PPUFile.DoCRC;
         PPUFile.DoCRC:=False;
         PPUFile.PutByte(Byte(VarRegable));
         PPUFile.PutSet(TPPUSet1(VarSymAccess));
         PPUFile.DoCRC:=OldCRC;
         PPUFile.PutDeref(VarDefDeref);
         PPUFile.PutSet(TPPUSet4(VarOptions));
      end;


    function TAbstractVarSym.GetSize : ASizeInt;
      begin
        if Assigned(VarDef) and
           ((VarDef.Typ<>ArrayDef) or
            Is_Dynamic_Array(VarDef) or
            (TArrayDef(VarDef).HighRange>=TArrayDef(VarDef).LowRange)) then
          Result:=VarDef.Size
        else
          Result:=0;
      end;


    function  TAbstractVarSym.GetPackedBitSize : LongInt;
      begin
        { bitpacking is only done for ordinals }
        if not Is_Ordinal(VarDef) then
          InternalError(2006082010);
        Result:=VarDef.PackedBitSize;
      end;


    function TAbstractVarSym.Is_RegVar(RefPara: Boolean):Boolean;
      var
        TempDef : TDef;
      begin
        { Register variables are not allowed in the following cases:
           - regvars are disabled
           - exceptions are used (after an exception is raised the contents of the
               registers is not valid anymore)
           - it has a local copy
           - the value needs to be in memory (i.e. reference counted) }
        Result:=(cs_opt_regvar in CurrentSettings.OptimizerSwitches) and
                not(pi_has_assembler_block in CurrentProcInfo.Flags) and
                not(pi_uses_exceptions in CurrentProcInfo.Flags) and
                not(pi_has_interproclabel in CurrentProcInfo.Flags) and
                ((RefPara and
                  (VarRegable <> vr_none)) or
                 (not RefPara and
                  not(VarRegable in [vr_none,vr_addr])))
                and ((VarDef.Typ <> RecordDef) or
                     (VarRegable = vr_addr) or
                     TAbstractRecordSymTable(TAbstractRecordDef(VarDef).SymTable).Has_Single_Field(TempDef) or
                     not(VarState in [vs_written,vs_readwritten]));
      end;


    procedure TAbstractVarSym.SetVarDefAndRegable(Def:TDef);
      begin
        SetVarDef(Def);
        SetRegable;
      end;


    procedure TAbstractVarSym.SetAddrTaken(AValue: Boolean);
      begin
        if AValue then
          Include(VarSymAccess, vsa_addr_taken)
        else
          Exclude(VarSymAccess, vsa_addr_taken);
      end;


    procedure TAbstractVarSym.SetDifferentScope(AValue: Boolean);
      begin
        if AValue then
          Include(VarSymAccess, vsa_different_scope)
        else
          Exclude(VarSymAccess, vsa_different_scope);
      end;


    procedure TAbstractVarSym.SetRegable;
      begin
        if vo_volatile in VarOptions then
          Exit;
         { can we load the value into a register ? }
        if not Assigned(Owner) or
           (Owner.SymTableType in [LocalSymTable, ParaSymTable]) or
           (
            (Owner.SymTableType=StaticSymTable) and
            not(cs_create_pic in CurrentSettings.ModuleSwitches)
           ) then
          begin
            if (TStoredDef(VarDef).Is_IntRegable and
              { we could keep all aint*2 records in registers, but this causes
                too much spilling for CPUs with 8-16 registers so keep only
                parameters and function results of this type in register because they are normally
                passed by register anyways

                This can be changed, as soon as we have full ssa (FK) }
              ((Typ=ParaVarSym) or
                (vo_is_funcret in VarOptions) or
                (TStoredDef(VarDef).Typ<>RecordDef) or
                (TStoredDef(VarDef).Size<=SizeOf(AInt)))) or

               { const parameters can be put into registers if the def fits into a register }
               (TStoredDef(VarDef).Is_Const_IntRegable and
                (Typ=ParaVarSym) and
                (VarSpez=vs_const)) then
              VarRegable:=vr_intreg
            else if TStoredDef(VarDef).Is_FPURegable then
              begin
                if Use_VectorFPU(VarDef) then
                  VarRegable:=vr_mmreg
                else
                  VarRegable:=vr_fpureg;
              end
            else if Is_Vector(VarDef) and
              Fits_In_MM_Register(VarDef) then
              begin
                VarRegable:=vr_mmreg;
              end;
          end;
      end;


    function TAbstractVarSym.GetAddrTaken: Boolean;
      begin
        Result:=vsa_addr_taken in VarSymAccess;
      end;


    function TAbstractVarSym.GetDifferentScope: Boolean;
      begin
        Result:=vsa_different_scope in VarSymAccess;
      end;


    procedure TAbstractVarSym.SetVarDef(const Def: TDef);
      begin
        FVarDef := Def;
      end;


{****************************************************************************
                               TFIELDVARSYM
****************************************************************************}

    constructor TFieldVarSym.Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(FieldVarSym,N,VSP,Def,VOpts);
         FieldOffset:=-1;
      end;


    constructor TFieldVarSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(FieldVarSym,PPUFile);
         FieldOffset:=PPUFile.GetASizeInt;
         PPULoadPlatform(PPUFile);
      end;


    procedure TFieldVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutASizeInt(FieldOffset);
         WriteEntry(PPUFile,IBFieldVarSym);
      end;


    function TFieldVarSym.BitOffset: ASizeUInt;
      begin
        Result:=FieldOffset;
        if TAbstractRecordSymTable(Owner).FieldAlignment<>BitAlignment then
         Result:=Result*8;
      end;


    function TFieldVarSym.MangledName:TSymStr;
      var
        SRSym : TSym;
        SRSymTable : TSymTable;
      begin
        if sp_static in SymOptions then
          begin
            if SearchSym(Lower(Owner.Name^)+'_'+Name,SRSym,SRSymTable) then
              Result:=SRSym.MangledName
            { when generating the debug info for the module in which the }
            { symbol is defined, the localsymtable of that module is     }
            { already popped from the symtablestack                      }
            else if SearchSym_In_Module(CurrentModule,Lower(Owner.Name^)+'_'+Name,SRSym,SRSymTable) then
              Result:=SRSym.MangledName
            else
              InternalError(2007012501);
          end
        else if Is_ObjCClass(TDef(Owner.DefOwner)) then
          begin
{$ifdef symansistr}
            if CachedMangledName<>'' then
              Result:=CachedMangledName
{$else symansistr}
            if Assigned(CachedMangledName) then
              Result:=CachedMangledName^
{$endif symansistr}
            else
              begin
                Result:=TargetInfo.CPrefix+'OBJC_IVAR_$_'+TObjectDef(Owner.DefOwner).ObjExtName^+'.'+RealName;
{$ifdef symansistr}
                CachedMangledName:=Result;
{$else symansistr}
                CachedMangledName:=StringDup(Result);
{$endif symansistr}
              end;
          end
        else
          Result:=inherited MangledName;
      end;


    destructor TFieldVarSym.Destroy;
      begin
{$ifndef symansistr}
        StringDispose(CachedMangledName);
{$endif symansistr}
        inherited Destroy;
      end;


{****************************************************************************
                        TABSTRACTNORMALVARSYM
****************************************************************************}

    constructor TAbstractNormalVarSym.Create(ST:TSymTyp;const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(ST,N,VSP,Def,VOpts);
         FillChar(LocAlloc,SizeOf(LocAlloc),0);
         FillChar(InitialLoc,SizeOf(InitialLoc),0);
         DefaultConstSym:=nil;
         DefaultConstSymDeref.Reset;
      end;


    constructor TAbstractNormalVarSym.PPULoad(ST:TSymTyp;PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ST,PPUFile);
         FillChar(LocAlloc,SizeOf(LocAlloc),0);
         FillChar(InitialLoc,SizeOf(InitialLoc),0);
         PPUFile.GetDeref(DefaultConstSymDeref);
      end;

    function TAbstractNormalVarSym.GlobalAsmSym: Boolean;
      begin
        Result:=
          (Owner.SymTableType=GlobalSymTable) or
          (create_smartlink and
           not(tf_smartlink_sections in TargetInfo.Flags)) or
          CurrentModule.IsLibrary or
          (Assigned(CurrentProcInfo) and
           ((po_inline in CurrentProcInfo.ProcDef.ProcOptions) or
            { globalasmsym is called normally before the body of a subroutine is parsed
              so we cannot know if it will be auto inlined, so make all symbols of it
              global if asked }
            (not(po_noinline in CurrentProcInfo.ProcDef.ProcOptions) and
             (cs_opt_autoinline in CurrentSettings.OptimizerSwitches)))
          ) or
          (vo_is_public in VarOptions);
      end;


    procedure TAbstractNormalVarSym.BuildDeref;
      begin
        inherited BuildDeref;
        DefaultConstSymDeref.Build(DefaultConstSym);
      end;


    procedure TAbstractNormalVarSym.Deref;
      begin
        inherited Deref;
        DefaultConstSym:=TSym(DefaultConstSymDeref.Resolve);
      end;


    procedure TAbstractNormalVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(DefaultConstSymDeref);
      end;


    function TAbstractNormalVarSym.Is_Captured:Boolean;
      begin
        Result:=Assigned(CaptureSym);
      end;


{****************************************************************************
                             Tstaticvarsym
****************************************************************************}

    constructor TStaticVarSym.Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(StaticVarSym,N,VSP,Def,VOpts);
         FieldVarSymDeref.Reset;
{$ifdef symansistr}
         FMangledName:='';
{$else symansistr}
         FMangledName:=nil;
{$endif symansistr}
      end;


    constructor TStaticVarSym.Create_DLL(const N : TSymStr;VSP:TVarSpez;Def:TDef);
      begin
         TStaticVarSym(Self).Create(N,VSP,Def,[vo_is_dll_var]);
      end;


    constructor TStaticVarSym.Create_C(const N: TSymStr; const Mangled : TSymStr;VSP:TVarSpez;Def:TDef);
      begin
         TStaticVarSym(Self).Create(N,VSP,Def,[]);
         Set_MangledName(Mangled);
      end;


    constructor TStaticVarSym.Create_From_FieldVar(const N: TSymStr;FieldVar:TFieldVarSym);
      begin
        Create(Internal_Static_Field_Name(N),FieldVar.VarSpez,FieldVar.VarDef,[]);
        FieldVarSym:=FieldVar;
      end;


    constructor TStaticVarSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StaticVarSym,PPUFile);
{$ifdef symansistr}
         if vo_has_mangledname in VarOptions then
           FMangledName:=PPUFile.GetAnsiString
         else
           FMangledName:='';
{$else symansistr}
         if vo_has_mangledname in VarOptions then
           FMangledName:=PPUFile.GetPShortString
         else
           FMangledName:=nil;
{$endif symansistr}
         if vo_has_section in VarOptions then
           Section:=PPUFile.GetAnsiString;
         PPUFile.GetDeref(FieldVarSymDeref);
         PPULoadPlatform(PPUFile);
      end;


    destructor TStaticVarSym.Destroy;
      begin
{$ifndef symansistr}
        if Assigned(FMangledName) then
          begin
{$ifdef MEMDEBUG}
            MemMangledNames.Start;
{$endif MEMDEBUG}
            StringDispose(FMangledName);
{$ifdef MEMDEBUG}
            MemMangledNames.Stop;
{$endif MEMDEBUG}
          end;
        StringDispose(FMangledBaseName);
{$endif}
        inherited Destroy;
      end;


    procedure TStaticVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         { write mangledname rather than _mangledname in case the mangledname
           has not been calculated yet (can happen in case only the
           mangledbasename has been set) }
         if vo_has_mangledname in VarOptions then
{$ifdef symansistr}
           PPUFile.PutAnsiString(MangledName);
{$else symansistr}
           PPUFile.PutString(MangledName);
{$endif symansistr}
         if vo_has_section in VarOptions then
           PPUFile.PutAnsiString(Section);
         PPUFile.PutDeref(FieldVarSymDeref);
         WriteEntry(PPUFile,IBStaticVarSym);
      end;


    procedure TStaticVarSym.BuildDeref;
      begin
        inherited BuildDeref;
        FieldVarSymDeref.Build(FieldVarSym);
      end;


    procedure TStaticVarSym.Deref;
      begin
        inherited Deref;
        FieldVarSym:=TFieldVarSym(FieldVarSymDeref.Resolve);
      end;

    function TStaticVarSym.MangledName:TSymStr;
      var
        UseName,
        Prefix : TSymStr;
      begin
{$ifdef symansistr}
        if FMangledName='' then
{$else symansistr}
        if not Assigned(FMangledName) then
{$endif symansistr}
          begin
            if (vo_is_typed_const in VarOptions) then
              Prefix:='TC'
            else
              Prefix:='U';
{$ifdef symansistr}
            if FMangledBaseName='' then
              UseName:=Name
            else
              UseName:=FMangledBaseName;
            FMangledName:=Make_MangledName(Prefix,Owner,UseName);
{$else symansistr}
            if not Assigned(FMangledBaseName) then
              UseName:=Name
            else
              UseName:=FMangledBaseName^;
            FMangledName:=StringDup(Make_MangledName(Prefix,Owner,UseName));
{$endif symansistr}
          end;
{$ifdef symansistr}
        Result:=FMangledName;
{$else symansistr}
        Result:=FMangledName^;
{$endif symansistr}
      end;


    procedure TStaticVarSym.Set_MangledBaseName(const S: TSymStr);
      begin
{$ifdef symansistr}
        FMangledBaseName:=S;
        FMangledName:='';
{$else symansistr}
        StringDispose(FMangledName);
        StringDispose(FMangledBaseName);
        FMangledBaseName:=StringDup(S);
{$endif symansistr}
        Include(VarOptions,vo_has_mangledname);
      end;


    function TStaticVarSym.MangledBaseName: TSymStr;
      begin
{$ifdef symansistr}
        Result:=FMangledBaseName;
{$else symansistr}
        if Assigned(FMangledBaseName) then
          Result:=FMangledBaseName^
        else
          Result:='';
{$endif symansistr}
      end;


    procedure TStaticVarSym.Set_MangledName(const S:TSymStr);
      begin
{$ifdef symansistr}
        FMangledName:=S;
{$else symansistr}
        StringDispose(FMangledName);
        FMangledName:=StringDup(S);
{$endif symansistr}
        Include(VarOptions,vo_has_mangledname);
      end;


    procedure TStaticVarSym.Set_Raw_MangledName(const S: TSymStr);
      begin
{$ifndef symansistr}
        StringDispose(FMangledName);
        FMangledName:=StringDup(S);
{$else}
        FMangledName:=S;
{$endif}
        Include(VarOptions,vo_has_mangledname);
      end;


{****************************************************************************
                               TLOCALVARSYM
****************************************************************************}

    constructor TLocalVarSym.Create(const N : TSymStr;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(LocalVarSym,N,VSP,Def,VOpts);
      end;


    constructor TLocalVarSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(LocalVarSym,PPUFile);
         PPULoadPlatform(PPUFile);
      end;


    procedure TLocalVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         WriteEntry(PPUFile,IBLocalVarSym);
      end;


{****************************************************************************
                              TPARAVARSYM
****************************************************************************}

    constructor TParaVarSym.Create(const N : TSymStr;NR:Word;VSP:TVarSpez;Def:TDef;VOpts:TVarOptions);
      begin
         inherited Create(ParaVarSym,N,VSP,Def,VOpts);
         if (VSP in [vs_var,vs_value,vs_const,vs_constref]) and
            not(vo_is_funcret in VOpts) then
           VarState := vs_initialised;
         ParaNr:=NR;
         ParaLoc[CalleeSide].Init;
         ParaLoc[CallerSide].Init;
      end;


    destructor TParaVarSym.Destroy;
      begin
        ParaLoc[CalleeSide].Done;
        ParaLoc[CallerSide].Done;
        inherited Destroy;
      end;


    constructor TParaVarSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ParaVarSym,PPUFile);
         ParaNr:=PPUFile.GetWord;
         UnivPara:=PPUFile.GetBoolean;

         { The var state of parameter symbols is fixed after writing them so
           we write them to the unit file.
           This enables constant folding for inline procedures loaded from units
         }
         VarState:=TVarState(PPUFile.GetByte);

         { read usage info }
         Refs:=PPUFile.GetByte;

         ParaLoc[CalleeSide].Init;
         ParaLoc[CallerSide].Init;
         if vo_has_explicit_paraloc in VarOptions then
           ParaLoc[CallerSide].PPULoad(PPUFile);

         PPULoadPlatform(PPUFile);
      end;


    procedure TParaVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldCRC : Boolean;
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutWord(ParaNr);
         PPUFile.PutBoolean(UnivPara);

         { The var state of parameter symbols is fixed after writing them so
           we write them to the unit file.
           This enables constant folding for inline procedures loaded from units
         }
         OldCRC:=PPUFile.DoCRC;
         PPUFile.DoCRC:=False;
         PPUFile.PutByte(Ord(VarState));
         { write also info about the usage of parameters,
           the absolute usage does not matter }
         PPUFile.PutByte(Min(1,Refs));
         PPUFile.DoCRC:=OldCRC;

         if vo_has_explicit_paraloc in VarOptions then
           begin
             ParaLoc[CallerSide].Check_Simple_Location;
             ParaLoc[CallerSide].PPUWrite(PPUFile);
           end;
         WriteEntry(PPUFile,IBParaVarSym);
      end;

    function TParaVarSym.Needs_Finalization:Boolean;
      begin
        Result:=(VarSpez=vs_value) and
          (Is_Managed_Type(VarDef) or
            (
              (not (TAbstractProcDef(Owner.DefOwner).ProcCallOption in CDecl_PoCalls)) and
              (not ParaManager.Use_StackAlloc) and
              (Is_Open_Array(VarDef) or Is_Array_Of_Const(VarDef))
            )
          );
      end;


    function TParaVarSym.Is_Used: Boolean;
      begin
        { Only the $parentfp parameter is supported for now }
        Result:=not (vo_is_parentfp in VarOptions) or (VarState>vs_initialised);
      end;

{****************************************************************************
                               TABSOLUTEVARSYM
****************************************************************************}

    constructor TAbsoluteVarSym.Create(const N : TSymStr;Def:TDef);
      begin
        inherited Create(AbsoluteVarSym,N,vs_value,Def,[]);
        Ref:=nil;
      end;


    constructor TAbsoluteVarSym.Create_Ref(const N : TSymStr;Def:TDef;ARef:TPropAccessList);
      begin
        inherited Create(AbsoluteVarSym,N,vs_value,Def,[]);
        Ref:=ARef;
      end;

    procedure TAbsoluteVarSym.Adjust_VarRegable;
      var
        PList : PPropAccessListItem;
      begin
        if Assigned(Ref) and (AbsTyp=ToVar) then
          begin
            PList:=Ref.FirstSym;
            if Assigned(PList) and (PList^.SLType=sl_load) and
               Assigned(PList^.Sym) and (PList^.Sym is TAbstractVarSym) and
               (VarRegable<>TAbstractVarSym(PList^.Sym).VarRegable) then
              begin
                VarRegable:=vr_none;
	        TAbstractVarSym(PList^.Sym).VarRegable:=vr_none;
             end;
          end;
      end;

    destructor TAbsoluteVarSym.Destroy;
      begin
        if Assigned(Ref) then
          Ref.Free;
          Ref := nil;
        inherited Destroy;
      end;


    constructor TAbsoluteVarSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(AbsoluteVarSym,PPUFile);
         Ref:=nil;
         AsmName:=nil;
         AbsTyp:=TAbsoluteTyp(PPUFile.GetByte);
         case AbsTyp of
           ToVar :
             Ref:=PPUFile.GetPropAccessList;
           ToAsm :
             AsmName:=PPUFile.GetPShortString;
           ToAddr :
             AddrOffset:=PPUFile.GetPUInt;
         end;
         PPULoadPlatform(PPUFile);
      end;


    procedure TAbsoluteVarSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(AbsTyp));
         case AbsTyp of
           ToVar :
             PPUFile.PutPropAccessList(Ref);
           ToAsm :
             PPUFile.PutString(AsmName^);
           ToAddr :
             PPUFile.PutPUInt(AddrOffset);
         end;
         WriteEntry(PPUFile,IBAbsoluteVarSym);
      end;


    procedure TAbsoluteVarSym.BuildDeref;
      begin
        inherited BuildDeref;
        if (AbsTyp=ToVar) then
          Ref.BuildDeref;
      end;


    procedure TAbsoluteVarSym.Deref;
      begin
         inherited Deref;
         { own absolute deref }
         if (AbsTyp=ToVar) then
           Ref.Resolve;
      end;


    function TAbsoluteVarSym.MangledName : TSymStr;
      begin
         case AbsTyp of
           ToAsm :
             MangledName:=AsmName^;
           ToAddr :
             MangledName:='$'+ToStr(AddrOffset);
           else
             InternalError(200411062);
         end;
      end;

         { returns the symbol type of the local variable or local parameter
           referenced by the absolute symbol }
    function TAbsoluteVarSym.RefTyp : TSymTyp;
      var
        PList : PPropAccessListItem;
      begin
        RefTyp:=Typ;
        if AbsTyp=ToVar then
          begin
            PList:=Ref.FirstSym;
            if Assigned(PList) and (PList^.SLType=sl_load) and
               Assigned(PList^.Sym) and not(Assigned(PList^.Next)) then
              RefTyp:=PList^.Sym.Typ;
          end;
      end;

{****************************************************************************
                                  TCONSTSYM
****************************************************************************}

    constructor TConstSym.Create_Ord(const N : TSymStr;T : TConstTyp;V : TConstExprInt;Def:TDef);
      begin
         inherited Create(ConstSym,N);
         FillChar(Value, SizeOf(Value), #0);
         ConstTyp:=T;
         Value.ValueOrd:=V;
         ConstDef:=Def;
         ConstDefDeref.Reset;
      end;


    constructor TConstSym.Create_OrdPtr(const N : TSymStr;T : TConstTyp;V : TConstPtrUInt;Def:TDef);
      begin
         inherited Create(ConstSym,N);
         FillChar(Value, SizeOf(Value), #0);
         ConstTyp:=T;
         Value.ValueOrdPtr:=V;
         ConstDef:=Def;
         ConstDefDeref.Reset;
      end;


    constructor TConstSym.Create_Ptr(const N : TSymStr;T : TConstTyp;V : Pointer;Def:TDef);
      begin
         inherited Create(ConstSym,N);
         FillChar(Value, SizeOf(Value), #0);
         ConstTyp:=T;
         Value.ValuePtr:=V;
         ConstDef:=Def;
         ConstDefDeref.Reset;
      end;


    constructor TConstSym.Create_String(const N : TSymStr;T : TConstTyp;Str:PChar;L:LongInt;Def: TDef);
      begin
         inherited Create(ConstSym,N);
         FillChar(Value, SizeOf(Value), #0);
         ConstTyp:=T;
         Value.ValuePtr:=Str;
         if Assigned(Def) then
           ConstDef:=Def
         else
           ConstDef:=CArrayDef.GetReusable(CAnsiCharType,L);
         ConstDefDeref.Reset;
         Value.Len:=L;
      end;


    constructor TConstSym.Create_WString(const N : TSymStr;T : TConstTyp;PW:TCompilerWideString);
      begin
         inherited Create(ConstSym,N);
         FillChar(Value, SizeOf(Value), #0);
         ConstTyp:=T;
         Value.ValueWS:=PW;
         ConstDef:=CArrayDef.GetReusable(CWideCharType,GetLengthWideString(PW));
         ConstDefDeref.Reset;
         Value.Len:=GetLengthWideString(PW);
      end;


    constructor TConstSym.Create_Undefined(const N : TSymStr;Def: TDef);
      begin
        inherited Create(ConstSym,N);
        FillChar(Value,SizeOf(Value),#0);
        ConstTyp:=ConstNone;
        ConstDef:=Def;
      end;


    constructor TConstSym.PPULoad(PPUFile:TCompilerPPUFile);
      var
         PD : PBestReal;
         PS : PNormalSet;
         PC : PChar;
         PW : TCompilerWideString;
         I  : LongInt;

         procedure DoWideStringConst;
         var
            I  : LongInt;
         begin
           InitWideString(PW);
           SetLengthWideString(PW,PPUFile.GetLongInt);
           { don't use getdata, because the compilerwidechars may have to
             be byteswapped
           }
           for I:=0 to PW.Len-1 do
             PW.Data[I]:=PPUFile.GetWord;
           Value.ValueWS:=PW;
         end;

      begin
         inherited PPULoad(ConstSym,PPUFile);
         ConstDef:=nil;
         ConstTyp:=TConstTyp(PPUFile.GetByte);
         FillChar(Value, SizeOf(Value), #0);
         case ConstTyp of
           ConstOrd :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               Value.ValueOrd:=PPUFile.GetExprInt;
             end;
           ConstPointer :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               Value.ValueOrdPtr:=PPUFile.GetPtrUInt;
             end;
           ConstWString :
             begin
               DoWideStringConst;
             end;
           ConstString,
           ConstResourceString :
              begin
              PPUFile.GetDeref(ConstDefDeref);
              Value.Len:=PPUFile.GetLongInt;
              GetMem(PC,Value.Len+1);
              PPUFile.GetData(PC^,Value.Len);
              PC[Value.Len]:=#0;
              Value.ValuePtr:=PC;
              end;
           ConstWResourceString :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               DoWideStringConst;
             end;
           ConstReal :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               New(PD);
               PD^:=PPUFile.GetReal;
               Value.ValuePtr:=PD;
             end;
           ConstSet :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               New(PS);
               PPUFile.GetSet(TPPUSet32(PS^));
               Value.ValuePtr:=PS;
             end;
           ConstGUID :
             begin
               PPUFile.GetDeref(ConstDefDeref);
               New(PGUID(Value.ValuePtr));
               PPUFile.GetData(Value.ValuePtr^,SizeOf(TGUID));
             end;
           ConstNil :
             PPUFile.GetDeref(ConstDefDeref);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(Ord(ConstTyp)));
         end;
         PPULoadPlatform(PPUFile);
      end;


    destructor TConstSym.Destroy;
      begin
        case ConstTyp of
          ConstNone,
          ConstOrd,
          ConstPointer,
          ConstNil:
            ;
          ConstString,
          ConstResourceString :
            FreeMem(PChar(Value.ValuePtr),Value.Len+1);
          ConstWString,
          ConstWResourceString:
            DoneWideString(Value.ValueWS);
          ConstReal :
            Dispose(PBestReal(Value.ValuePtr));
          ConstSet :
            Dispose(PNormalSet(Value.ValuePtr));
          ConstGUID :
            Dispose(PGUID(Value.ValuePtr));
        end;
        inherited Destroy;
      end;


    procedure TConstSym.BuildDeref;
      begin
        inherited;
        case ConstTyp  of
          ConstNil,ConstOrd,ConstReal,ConstPointer,ConstSet,ConstString,ConstResourceString,ConstWResourceString,ConstGUID:
            ConstDefDeref.Build(ConstDef);
          ConstWString:
            ;
          else
            InternalError(2015120802);
        end;
      end;


    procedure TConstSym.Deref;
      begin
        case ConstTyp of
          ConstNil,ConstOrd,ConstReal,ConstPointer,ConstSet,ConstString,ConstResourceString,ConstWResourceString,ConstGUID:
            ConstDef:=TDef(ConstDefDeref.Resolve);
          ConstWString:
            ConstDef:=CArrayDef.GetReusable(CWideCharType,GetLengthWideString(Value.ValueWS));
          else
            InternalError(2015120801);
        end
      end;


    procedure TConstSym.PPUWrite(PPUFile:TCompilerPPUFile);

      procedure DoWideStringConst;

      var
        Len : Integer;
      begin
        Len:=GetLengthWideString(Value.ValueWS);
        PPUFile.PutLongInt(Len);
        if Len>0 then
          PPUFile.PutData(Value.ValueWS.Data[0],Value.ValueWS.Len*SizeOf(TCompilerWideChar));
      end;


      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(ConstTyp));
         case ConstTyp of
           ConstNil :
             PPUFile.PutDeref(ConstDefDeref);
           ConstOrd :
             begin
               PPUFile.PutDeref(ConstDefDeref);
               PPUFile.PutExprInt(Value.ValueOrd);
             end;
           ConstPointer :
             begin
               PPUFile.PutDeref(ConstDefDeref);
               PPUFile.PutPtrUInt(Value.ValueOrdPtr);
             end;
           ConstWString :
             begin
               { no need to store the def, we can reconstruct it }
               DoWideStringConst;
             end;
           ConstString,ConstResourceString:
             begin
             PPUFile.PutDeref(ConstDefDeref);
             PPUFile.PutLongInt(Value.Len);
             PPUFile.PutData(PChar(Value.ValuePtr)^,Value.Len);
             end;
            ConstWResourceString:
             begin
               PPUFile.PutDeref(ConstDefDeref);
               DoWideStringConst
             end;
           ConstReal :
             begin
               PPUFile.PutDeref(ConstDefDeref);
               PPUFile.PutReal(PBestReal(Value.ValuePtr)^);
             end;
           ConstSet :
             begin
               PPUFile.PutDeref(ConstDefDeref);
               PPUFile.PutSet(TPPUSet32(Value.ValuePtr^));
             end;
           ConstGUID :
             begin
               PPUFile.PutDeref(ConstDefDeref);
               PPUFile.PutData(Value.ValuePtr^,SizeOf(TGUID));
             end;
         else
           InternalError(13);
         end;
        WriteEntry(PPUFile,IBConstSym);
      end;


{****************************************************************************
                                  TENUMSYM
****************************************************************************}

    constructor TEnumSym.Create(const N : TSymStr;Def : TEnumDef;V : LongInt);
      begin
         inherited Create(EnumSym,N);
         Definition:=Def;
         DefinitionDeref.Reset;
         Value:=V;
      end;


    constructor TEnumSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(EnumSym,PPUFile);
         PPUFile.GetDeref(DefinitionDeref);
         Value:=PPUFile.GetLongInt;
         PPULoadPlatform(PPUFile);
      end;


    procedure TEnumSym.BuildDeref;
      begin
        inherited;
        DefinitionDeref.Build(Definition);
      end;


    procedure TEnumSym.Deref;
      begin
         Definition:=TEnumDef(DefinitionDeref.Resolve);
      end;

    procedure TEnumSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(DefinitionDeref);
         PPUFile.PutLongInt(Value);
         WriteEntry(PPUFile,IBEnumSym);
      end;


{****************************************************************************
                                  TTYPESYM
****************************************************************************}


    constructor TTypeSym.Create(const N : TSymStr;Def:TDef);

      begin
        inherited Create(TypeSym,N);
        TypeDef:=Def;
        TypeDefDeref.Reset;
        { register the typesym for the definition }
        if Assigned(TypeDef) and
           (TypeDef.Typ<>ErrorDef) and
           not(Assigned(TypeDef.TypeSym)) then
         TypeDef.TypeSym:=Self;
      end;

    destructor TTypeSym.Destroy;
      begin
        inherited Destroy;
      end;


    constructor TTypeSym.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(TypeSym,PPUFile);
         PPUFile.GetDeref(TypeDefDeref);
         FPrettyName:=PPUFile.GetAnsiString;
         PPULoadPlatform(PPUFile);
      end;


    procedure TTypeSym.BuildDeref;
      begin
        inherited;
        TypeDefDeref.Build(TypeDef);
      end;


    procedure TTypeSym.Deref;
      begin
        TypeDef:=TDef(TypeDefDeref.Resolve);
      end;


    procedure TTypeSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(TypeDefDeref);
         PPUFile.PutAnsiString(FPrettyName);
         WriteEntry(PPUFile,IBTypeSym);
      end;


    function TTypeSym.PrettyName : string;
      begin
        if FPrettyName<>'' then
          Result:=FPrettyName
        else
          Result:=inherited PrettyName;
      end;


{****************************************************************************
                                  TSYSSYM
****************************************************************************}


    var
      SysSymList : TFPHashObjectList;


    constructor TSysSym.Create(const N : TSymStr;L : TInlineNumber);
      var
        S : ShortString;
      begin
         inherited Create(SysSym,N);
         Number:=L;
         Str(LongInt(L),S);
         if Assigned(SysSymList.Find(S)) then
           InternalError(2016060303);
         SysSymList.Add(S,Self);
      end;

    constructor TSysSym.PPULoad(PPUFile:TCompilerPPUFile);
      var
        S : ShortString;
      begin
         inherited PPULoad(SysSym,PPUFile);
         Number:=TInlineNumber(PPUFile.GetLongInt);
         PPULoadPlatform(PPUFile);
         Str(LongInt(Number),S);
         if Assigned(SysSymList.Find(S)) then
           InternalError(2016060304);
         SysSymList.Add(S,Self);
      end;

    destructor TSysSym.Destroy;
      begin
        inherited Destroy;
      end;

    procedure TSysSym.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutLongInt(LongInt(Number));
         WriteEntry(PPUFile,IBSysSym);
      end;


    class function TSysSym.Find_By_Number(L:LongInt):TSysSym;
      var
        S : ShortString;
      begin
        Str(L,S);
        Result:=TSysSym(SysSymList.Find(S));
      end;

{*****************************************************************************
                                 TMacro
*****************************************************************************}

    constructor TMacro.Create(const N : TSymStr);
      begin
         inherited Create(MacroSym,N);
         Owner:=nil;
         Defined:=False;
         IsUsed:=False;
         IsCompilerVar:=False;
         BufText:=nil;
         BufLen:=0;
      end;

    constructor TMacro.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(MacroSym,PPUFile);
         Defined:=PPUFile.GetBoolean;
         IsCompilerVar:=PPUFile.GetBoolean;
         IsUsed:=False;
         Allocate_BufText(PPUFile.GetLongInt);
         if BufLen>0 then
           PPUFile.GetData(BufText)
      end;

    destructor TMacro.Destroy;
      begin
         BufText:=nil;
         inherited Destroy;
      end;

    procedure TMacro.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutBoolean(Defined);
         PPUFile.PutBoolean(IsCompilerVar);
         PPUFile.PutLongInt(BufLen);
         if BufLen > 0 then
           PPUFile.PutData(BufText);
         WriteEntry(PPUFile,IBMacroSym);
      end;


    function TMacro.Allocate_BufText(Len:LongInt) : PChar;
      begin
        SetLength(BufText,Len);
        BufLen:=Len;
        Result:=PAnsiChar(BufText);
      end;


    procedure TMacro.Free_BufText;
      begin
        BufText:=nil;
        BufLen:=0;
      end;


    function TMacro.GetCopy:TMacro;
      var
        P : TMacro;
      begin
        P:=TMacro.Create(RealName);
        P.Defined:=Defined;
        P.IsUsed:=IsUsed;
        P.IsCompilerVar:=IsCompilerVar;
        P.IsCMacro:=IsCMacro;
        P.Allocate_BufText(BufLen);
        if BufLen>0 then
          Move(BufText[0],P.BufText[0],BufLen);
        Result:=P;
      end;


    procedure InitSymSym;
      begin
        SysSymList:=TFPHashObjectList.Create(False);
      end;


    procedure DoneSymSym;
      begin
        SysSymList.Free;
        SysSymList := nil;
      end;


initialization
  Register_InitDone_Proc(@InitSymSym,@DoneSymSym);
end.
