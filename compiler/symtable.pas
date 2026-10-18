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
unit symtable;

{$i fpcdefs.inc}

interface

    uses
       { common }
       CUtils,CClasses,GlobType,Tokens,
       { symtable }
       SymConst,SymBase,SymType,SymDef,SymSym;


{****************************************************************************
                             Symtable types
****************************************************************************}

    type

       { tstoredsymtable }

       TStoredSymTable = class(TSymTable)
       private
          FInitFinalCheckDone : Boolean;
          FDerefBuilt : Boolean;
          FDerefImplBuilt : Boolean;
          procedure NeedsInitFinal(Sym:TObject;Arg:Pointer);
          procedure DoInitFinalCheck;
          procedure CheckForward(Sym:TObject;Arg:Pointer);
          procedure CheckBlockValid(Def: TObject;Arg:Pointer);
          procedure RegisterDefs(Def:TObject;Arg:Pointer);
          procedure RegisterSyms(Sym:TObject;Arg:Pointer);
          procedure LabelDefined(Sym:TObject;Arg:Pointer);
          procedure VarSymbolUsed(Sym:TObject;Arg:Pointer);
          procedure TestPrivate(Sym:TObject;Arg:Pointer);
          procedure ObjectPrivateSymbolUsed(Sym:TObject;Arg:Pointer);
          procedure LoadDefs(PPUFile:TCompilerPPUFile);
          procedure LoadSyms(PPUFile:TCompilerPPUFile);
          procedure WriteDefs(PPUFile:TCompilerPPUFile);
          procedure WriteSyms(PPUFile:TCompilerPPUFile);
       public
          constructor Create(const S:string);
          procedure InsertSym(Sym:TSymEntry;CheckDup:Boolean=True);override;
          procedure DeleteSym(Sym:TSymEntry);override;
          { load/write }
          procedure PPULoad(PPUFile:TCompilerPPUFile);virtual;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);virtual;
          procedure BuildDeref;
          procedure BuildDerefImpl;
          { buildderef but only for (recursively) used symbols/defs }
          procedure BuildDeref_Registered;
          procedure Deref(OnlyRegistered: Boolean);virtual;
          procedure DerefImpl(OnlyRegistered: Boolean);virtual;
          function  CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
          procedure AllSymbolsUsed;
          procedure AllPrivatesUsed;
          procedure Check_Forwards;
          procedure CheckLabels;
          function  Needs_Init_Final : Boolean; virtual;
          function  Has_Non_Trivial_Init:Boolean;virtual;
          function Is_DerefImpl_Built: Boolean;
          function Is_Deref_Built: Boolean;
          procedure TestForDefaultProperty(Sym:TObject;Arg:Pointer);
          procedure Register_Children;
       end;



       TManagementOperatorOffsetEntry = record
         PD : TProcDef;
         Offset : ASizeInt;
       end;
       PManagementOperatorOffsetEntry = ^TManagementOperatorOffsetEntry;

       TAbstractRecordSymTable = class(TStoredSymTable)

       public
          UseFieldAlignment,     { alignment to use for fields (PACKRECORDS value), C_alignment is C style }
          RecordAlignment,       { alignment desired when inserting this record }
          ExplicitRecordAlignment, { explicit alignment for inserting this record, given by align XX at end of declaration }
          FieldAlignment,        { alignment current alignment used when fields are inserted }
          PadAlignment : ShortInt;   { size to a multiple of which the symtable has to be rounded up }
          RecordAlignMin: ShortInt; { local equivalentsof global settings, so that records can be created with custom settings internally }
          HasFieldsWithMOP : TManagementOperators; { whether any of the fields has the need for a management operator (or one of the field's fields) }
          constructor Create(const N:string;UseAlign,RecordMinAlign:ShortInt);
          destructor Destroy;override;
          procedure PPULoad(PPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          procedure AlignRecord(FieldOffset:ASizeInt;VarAlign:ShortInt);
          procedure AddField(Sym:TFieldVarSym;Vis:TVisibility);
          procedure AddFieldList(List: TFPObjectList; MaybeReorder: Boolean);
          { returns the field closest to this offset (may not be exact because
            of padding; internalerrors for variant records, assumes fields are
            ordered by increasing offset) }
          function FindFieldByOffset(Offset:ASizeInt): TFieldVarSym;
          procedure AddAlignmentPadding;
          procedure InsertDef(Def:TDefEntry);override;
          function Is_Packed: Boolean;
          function Has_Single_Field(out Def:TDef): Boolean;
          function Has_Double_Field(out Def1,Def2:TDef; out Offset:Integer): Integer;
          { collects all management operators of the specified type in list (which
            is not cleared); the entries are copies and thus must be freed by the
            caller }
          procedure Get_ManagementOperator_Offset_List(MOP:TManagementOperator;List:TFPList);
        protected
          { size in bytes including padding }
          FDataSize      : ASizeInt;
          { size in bits of the data in case of bitpacked record. Only important during construction, }
          { no need to save in/restore from ppu file. datasize is always (databitsize+7) div 8.       }
          DataBitSize    : ASizeInt;
          { size in bytes of padding }
          FPaddingSize   : Word;
          { array of tmanagementoperator_offset_entry lists; only assigned if
            they had been queried once by get_management_operator_list }
          MOPList : array[TManagementOperator] of TFPList;
          procedure SetDataSize(Val: ASizeInt);
          function GetFieldOffset(Sym: TFieldVarSym; Base: ASizeInt; var GlobalFieldAlignment: ShortInt): ASizeInt;
          procedure Do_Get_ManagementOperator_Offset_List(Data:TObject;Arg:Pointer);
        public
          function IsCurrentUnit: Boolean; override;
          property DataSize : ASizeInt read FDataSize write SetDataSize;
          property PaddingSize: Word read FPaddingSize write FPaddingSize;

       end;

       TRecordSymTable = class(TAbstractRecordSymTable)
       public
          { maybe someday is worth to move managementoperators to              }
          { tabstractrecordsymtable to perform management class operators for  }
          { object/classes. In XE5 and newer is possible to use class operator }
          { for classes (like for Delphi .NET before) only for Delphi NEXTGEN  }
          ManagementOperators : TManagementOperators;
          constructor Create(const N:string;UseAlign,RecordMinAlign:ShortInt);
          procedure InsertUnionST(UnionST : TRecordSymTable;Offset : ASizeInt);
          procedure IncludeManagementOperator(MOP:TManagementOperator);
       end;

       TObjectSymTable = class(TAbstractRecordSymTable)
       public
          constructor Create(ADefOwner:TDef;const N:string;UseAlign,RecordMinAlign:ShortInt);
          function  CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
       end;



       { tabstractsubsymtable }

       TAbstractSubSymTable = class(TStoredSymTable)
       public
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
       end;

       { tabstractlocalsymtable }

       TAbstractLocalSymTable = class(TAbstractSubSymTable)
       public
          function Count_Locals:LongInt;
          function IsCurrentUnit: Boolean; override;
       end;

       TLocalSymTable = class(TAbstractLocalSymTable)
       public
          constructor Create(ADefOwner:TDef;Level:Byte);
          function CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
       end;

       { tparasymtable }

       TParaSymTable = class(TAbstractLocalSymTable)
       public
          constructor Create(ADefOwner:TDef;Level:Byte);
          function CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
       end;

       TAbstractUnitSymTable = class(TStoredSymTable)
       public
          constructor Create(const N : string;ID:Word);
          function CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
          function FindNamespace(const N:string):TSymEntry;virtual;
          function IsCurrentUnit:Boolean;override;
          function Needs_Init_Final: Boolean; override;
          procedure InsertUnit(Sym:TSymEntry);
          function Has_Class_ConDestructors: Boolean;
       end;

       TGlobalSymTable = class(TAbstractUnitSymTable)
       public
          UnitTypeCount : Word;
          constructor Create(const N : string;ID:Word);
          procedure PPULoad(PPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
       end;

       TStaticSymTable = class(TAbstractUnitSymTable)
       public
          constructor Create(const N : string;ID:Word);
          procedure PPULoad(PPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          function CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;override;
          function FindNamespace(const N:string):TSymEntry;override;
       end;

       TSpecializeSymTable = class(TGlobalSymTable)
       public
          constructor Create(const N : string;ID:Word);
          function IsCurrentUnit:Boolean;override;
       end;

       TWithSymTable = class(TSymTable)
          WithRefNode : TObject; { tnode }
          constructor Create(AOwner:TDef;ASymList:TFPHashObjectList;RefNode:TObject{tnode});
          destructor  Destroy;override;
          procedure Clear;override;
          procedure InsertDef(Def:TDefEntry);override;
        end;

       TSTTExceptSymTable = class(TSymTable)
       public
          constructor Create;
       end;

       TMacroSymTable = class(TStoredSymTable)
       public
          constructor Create(Exported: Boolean);
       end;

       { tenumsymtable }

       TEnumSymTable = class(TAbstractSubSymTable)
       public
          procedure InsertSym(Sym: TSymEntry; CheckDup: Boolean = True); override;
          constructor Create(ADefOwner:TDef);
       end;

       { tarraysymtable }

       TArraySymTable = class(TAbstractSubSymTable)
       public
          procedure InsertDef(Def:TDefEntry);override;
          constructor Create(ADefOwner:TDef);
       end;

    var
       SystemUnit     : TGlobalSymTable; { pointer to the system unit }

    type
       TSymbolSearchFlag = (
         ssf_search_option,
         ssf_search_helper,
         ssf_has_inherited,
         ssf_no_addsymref,
         ssf_unit_or_namespace_only
       );
       TSymbolSearchFlags = set of TSymbolSearchFlag;


{****************************************************************************
                             Functions
****************************************************************************}

{*** Misc ***}
    function  FullTypeName(Def,OtherDef:TDef):string;
    function Generate_Nested_Name(SymTable:TSymTable;const Delimiter:string):string;
    { def is the extended type of a helper }
    function Generate_ObjectPascal_Helper_Key(Def:TDef):TSymStr;
    procedure IncompatibleTypes(Def1,Def2:TDef);
    procedure HideSym(Sym:TSymEntry);
    procedure DuplicateSym(var HashedID: THashedIDString; DupSym, OrigSym:TSymEntry; Warn: Boolean);
    function Handle_Generic_DummySym(Sym:TSymEntry;var SymOptions:TSymOptions):Boolean;
    { writes all declarations for the specified system unit symbol }
    procedure Write_System_Parameter_Lists(const Name:string);

{*** Search ***}
    procedure AddSymRef(Sym:TSym);inline;
    procedure AddSymRef(Sym:TSym;Def:TDef);
    function  Is_Owned_By(NestedDef,OwnerDef:TDef):Boolean;
    function  Sym_Is_Owned_By(ChildSym:TSym;SymTable:TSymTable):Boolean;
    function  Defs_Belong_To_Same_Generic(Def1,Def2:TDef):Boolean;
    function  Get_Generic_In_Hierarchy_By_Name(SRSym:TSym;Def:TDef):TDef;
    function  Return_Specialization_Of_Generic(NestedDef,GenericDef:TDef;out ResultDef:TDef):Boolean;
    function  Is_Visible_For_Object(SymST:TSymTable;SymVisibility:TVisibility;ContextObjDef:TAbstractRecordDef):Boolean;
    function  Is_Visible_For_Object(PD:TProcDef;ContextObjDef:TAbstractRecordDef):Boolean;
    function  Is_Visible_For_Object(Sym:TSym;ContextObjDef:TAbstractRecordDef):Boolean;
    function  SearchSym(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    function  SearchSym_With_Flags(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
    function  SearchSym_Maybe_With_SymOption(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags;Option:TSymOption):Boolean;
    { searches for a symbol with the given name that has the given option in
      symoptions set }
    function  SearchSym_With_SymOption(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Option:TSymOption):Boolean;
    function  SearchSym_Type(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    function  SearchSym_In_Module(PM:Pointer;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    function  SearchSym_In_Named_Module(const UnitName, SymName: TIDString; out SRSym: TSym; out SRSymTable: TSymTable): Boolean;
    function  SearchSym_In_Class(ClassH: TObjectDef; ContextClassH:TAbstractRecordDef;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
    function  SearchSym_In_Record(RecordH:TAbstractRecordDef;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    function  SearchSym_In_Class_By_MsgInt(ClassH:TObjectDef;MsgID:LongInt;out SRDef : TDef;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    function  SearchSym_In_Class_By_MsgStr(ClassH:TObjectDef;const S:string;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
    { searches symbols inside of a helper's implementation }
    function  SearchSym_In_Helper(ClassH,ContextClassH:TObjectDef;const S: TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
    function  Search_System_Type(const S: TIDString): TTypeSym;
    function  Try_Search_System_Type(const S: TIDString): TTypeSym;
    function  Try_Search_Current_Module_Type(const S: TIDString): TTypeSym;
    function  Search_System_Proc(const S: TIDString): TProcDef;
    function  Search_Named_Unit_GlobalType(const UnitName, TypeName: TIDString; ThrowError: Boolean): TTypeSym;
    function  Search_Struct_Member(PD : TAbstractRecordDef;const S : string):TSym;
    function  Search_Struct_Member_No_Helper(PD : TAbstractRecordDef;const S : string):TSym;
    function  Search_Assignment_Operator(FromDef,ToDef:TDef;Explicit:Boolean):TProcDef;
    function  Search_Enumerator_Operator(FromDef,ToDef:TDef):TProcDef;
    function  Search_Management_Operator(MOP:TManagementOperator;PD:TDef):TProcDef;
    { searches for the helper definition that's currently active for pd }
    function  Search_Last_ObjectPascal_Helper(PD : TDef;ContextClassH : TAbstractRecordDef;out ODef : TObjectDef):Boolean;
    { searches whether the symbol s is available in the currently active }
    { helper for pd }
    function  Search_ObjectPascal_Helper(PD : TDef;ContextClassH : TAbstractRecordDef;const S : string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
    function  Search_ObjC_Helper(PD : TObjectDef;const S : string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
    function  Search_ObjC_Method(const S : string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
    {Looks for macro s (must be given in upper case) in the macrosymbolstack, }
    {and returns it if found. Returns nil otherwise.}
    function  Search_Macro(const S : string):TSym;
    { Additionally to searching for a macro, also checks whether it's still }
    { actually defined (could be disable using "undef")                     }
    function  Defined_Macro(const S : string):Boolean;
    { Look for a system procedure (no overloads supported) }
    { returns a list of helpers in the current module for the def }
    function Get_ObjectPascal_Helpers(PD : TDef):TFPObjectList;

{*** Object Helpers ***}
    function Search_Default_Property(PD : TAbstractRecordDef) : TPropertySym;
    function Maybe_Find_Real_Class_Definition(PD: TDef; ErrorOnFailure: Boolean): TDef;
    function Find_Real_Class_Definition(PD: TObjectDef; ErrorOnFailure: Boolean): TObjectDef;

{*** Macro Helpers ***}
    {If called initially, the following procedures manipulate macros in }
    {initialmacrotable, otherwise they manipulate system macros local to a module.}
    {Name can be given in any case (it will be converted to upper case).}
    procedure Def_System_Macro(const Name : string);
    procedure Set_System_Macro(const Name, Value : string);
    procedure Set_System_CompVar(const Name, Value : string);
    procedure Undef_System_Macro(const Name : string);

{*** symtable stack ***}
{ $ifdef DEBUG
    procedure test_symtablestack;
    procedure list_symtablestack;
 $endif DEBUG}

{$ifdef UNITALIASES}
    type
       PUnitAlias = ^TUnitAlias;
       TUnitAlias = object(TNamedIndexItem)
          NewName : PShortString;
          constructor Init(const N:string);
          destructor  Done;virtual;
       end;
    var
       UnitAliases : PDictionary;

    procedure AddUnitAlias(const N:string);
    function GetUnitAlias(const N:string):string;
{$endif UNITALIASES}

{*** Init / Done ***}
    procedure InitSymTable;
    procedure DoneSymTable;

    const
      Overloaded_Names : array [NOTOKEN..last_overloaded] of string[16] = (
    { NOTOKEN        }  'error',
    { _PLUS          }  'plus',
    { _MINUS         }  'minus',
    { _STAR          }  'star',
    { _SLASH         }  'slash',
    { _EQ            }  'equal',
    { _GT            }  'greater',
    { _LT            }  'lower',
    { _GTE           }  'greater_or_equal',
    { _LTE           }  'lower_or_equal',
    { _NE            }  'not_equal',
    { _SYMDIF        }  'sym_diff',
    { _STARSTAR      }  'starstar',
    { _OP_AS         }  'as',
    { _OP_IN         }  'in',
    { _OP_IS         }  'is',
    { _OP_OR         }  'or',
    { _OP_AND        }  'and',
    { _OP_DIV        }  'div',
    { _OP_MOD        }  'mod',
    { _OP_NOT        }  'not',
    { _OP_SHL        }  'shl',
    { _OP_SHR        }  'shr',
    { _OP_XOR        }  'xor',
    { _ASSIGNMENT    }  'assign',
    { _OP_EXPLICIT   }  'explicit',
    { _OP_ENUMERATOR }  'enumerator',
    { _OP_INITIALIZE }  'initialize',
    { _OP_FINALIZE   }  'finalize',
    { _OP_ADDREF     }  'addref',
    { _OP_COPY       }  'copy',
    { _OP_INC        }  'inc',
    { _OP_DEC        }  'dec');

      ManagementOperator2Tok:array[TManagementOperator] of TToken = (
    { mop_none       }  NOTOKEN,
    { mop_initialize }  _OP_INITIALIZE,
    { mop_finalize   }  _OP_FINALIZE,
    { mop_addref     }  _OP_ADDREF,
    { mop_copy       }  _OP_COPY
    );



implementation

    uses
      { global }
      Verbose,Globals,Systems,
      { symtable }
      SymUtil,DefUtil,DefCmp,ObjCDef,
      { module }
      FModule,
      { codegen }
      ProcInfo,
      { ppu }
      EntFile,PPU,
      { parser }
      Scanner
      ;


    var
      DupNr : LongInt; { unique number for duplicate symbols }

{*****************************************************************************
                             TStoredSymtable
*****************************************************************************}

    constructor TStoredSymTable.Create(const S:string);
      begin
        inherited Create(S);
        { Note: this happens for the initial macro symtable, so no error here }
        if not Assigned(CurrentModule) then
          Comment(VDebug,'Current module not available for module id')
        else
          ModuleID:=CurrentModule.ModuleID;
      end;


    procedure TStoredSymTable.InsertSym(Sym:TSymEntry;CheckDup:Boolean=True);
      begin
        inherited InsertSym(Sym,CheckDup);
        FInitFinalCheckDone:=False;
      end;


    procedure TStoredSymTable.DeleteSym(Sym:TSymEntry);
      begin
        inherited DeleteSym(Sym);
        FInitFinalCheckDone:=False;
      end;


    procedure TStoredSymTable.PPULoad(PPUFile:TCompilerPPUFile);
      begin
        { load the table's flags }
        if PPUFile.ReadEntry<>IBSymTableOptions then
          Message(unit_f_ppu_read_error);
        PPUFile.GetSet(TPPUSet1(TableOptions));

        { load definitions }
        LoadDefs(PPUFile);

        { load symbols }
        LoadSyms(PPUFile);

        FInitFinalCheckDone:=True;
      end;


    procedure TStoredSymTable.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         { ensure that we have the sto_needs_init_final flag set if needed }
         if not FInitFinalCheckDone then
           Needs_Init_Final;

         { write the table's flags }
         PPUFile.PutSet(TPPUSet1(TableOptions));
         PPUFile.WriteEntry(IBSymTableOptions);

         { write definitions }
         WriteDefs(PPUFile);

         { write symbols }
         WriteSyms(PPUFile);
      end;


    procedure TStoredSymTable.LoadDefs(PPUFile:TCompilerPPUFile);
      var
        Def : TDef;
        B   : Byte;
      begin
         { load start of definition section, which holds the amount of defs }
         if PPUFile.ReadEntry<>IBStartDefs then
           Message(unit_f_ppu_read_error);
         { read definitions }
         repeat
           B:=PPUFile.ReadEntry;
           Def:=nil;
           case B of
             IBPointerDef : Def:=CPointerDef.PPULoad(PPUFile);
             IBArrayDef : Def:=CArrayDef.PPULoad(PPUFile);
             IBOrdDef : Def:=COrdDef.PPULoad(PPUFile);
             IBFloatDef : Def:=CFloatDef.PPULoad(PPUFile);
             IBProcDef : Def:=CProcDef.PPULoad(PPUFile);
             IBShortStringDef : Def:=CStringDef.LoadShort(PPUFile);
             IBLongStringDef : Def:=CStringDef.LoadLong(PPUFile);
             IBAnsiStringDef : Def:=CStringDef.LoadAnsi(PPUFile);
             IBWideStringDef : Def:=CStringDef.LoadWide(PPUFile);
             IBUnicodeStringDef : Def:=CStringDef.LoadUnicode(PPUFile);
             IBRecordDef : Def:=CRecordDef.PPULoad(PPUFile);
             IBObjectDef : Def:=CObjectDef.PPULoad(PPUFile);
             IBEnumDef : Def:=CEnumDef.PPULoad(PPUFile);
             IBSetDef : Def:=CSetDef.PPULoad(PPUFile);
             IBProcVarDef : Def:=CProcVarDef.PPULoad(PPUFile);
             IBFileDef : Def:=CFileDef.PPULoad(PPUFile);
             IBClassRefDef : Def:=CClassRefDef.PPULoad(PPUFile);
             IBFormalDef : Def:=CFormalDef.PPULoad(PPUFile);
             IBVariantDef : Def:=CVariantDef.PPULoad(PPUFile);
             IBUndefinedDef : Def:=CUndefinedDef.PPULoad(PPUFile);
             IBEndDefs : Break;
             IBEnd : Message(unit_f_ppu_read_error);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(B));
           end;
           if Assigned(Def) then
             TStoredDef(Def).PPULoadSubEntries(PPUFile);
           InsertDef(Def);
         until False;
      end;


    procedure TStoredSymTable.LoadSyms(PPUFile:TCompilerPPUFile);
      var
        B   : Byte;
        Sym : TSym;
      begin
         { load start of definition section, which holds the amount of defs }
         if PPUFile.ReadEntry<>IBStartSyms then
          Message(unit_f_ppu_read_error);
         { now read the symbols }
         repeat
           Sym:=nil;
           B:=PPUFile.ReadEntry;
           case B of
                IBTypeSym : Sym:=CTypeSym.PPULoad(PPUFile);
                IBProcSym : Sym:=CProcSym.PPULoad(PPUFile);
               IBConstSym : Sym:=CConstSym.PPULoad(PPUFile);
           IBStaticVarSym : Sym:=CStaticVarSym.PPULoad(PPUFile);
            IBLocalVarSym : Sym:=CLocalVarSym.PPULoad(PPUFile);
             IBParaVarSym : Sym:=CParaVarSym.PPULoad(PPUFile);
            IBFieldVarSym : Sym:=CFieldVarSym.PPULoad(PPUFile);
         IBAbsoluteVarSym : Sym:=CAbsoluteVarSym.PPULoad(PPUFile);
                IBEnumSym : Sym:=CEnumSym.PPULoad(PPUFile);
            IBPropertySym : Sym:=CPropertySym.PPULoad(PPUFile);
                IBUnitSym : Sym:=CUnitSym.PPULoad(PPUFile);
               IBLabelSym : Sym:=CLabelSym.PPULoad(PPUFile);
                 IBSysSym : Sym:=CSysSym.PPULoad(PPUFile);
               IBMacroSym : Sym:=TMacro.PPULoad(PPUFile);
           IBNamespaceSym : Sym:=CNamespaceSym.PPULoad(PPUFile);
                IBEndSyms : Break;
                    IBEnd : Message(unit_f_ppu_read_error);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(B));
           end;
           if Assigned(Sym) then
             TStoredSym(Sym).PPULoadSubEntries(PPUFile);
           InsertSym(Sym,False);
         until False;
      end;


    procedure TStoredSymTable.WriteDefs(PPUFile:TCompilerPPUFile);
      var
        DefCount,
        I   : LongInt;
        Def : TStoredDef;
      begin
        DefCount:=0;
        for I:=0 to DefList.Count-1 do
          if TStoredDef(DefList[I]).IsRegistered then
            Inc(DefCount);
        { each definition get a number, write then the amount of defs to the
          ibstartdef entry }
        PPUFile.PutLongInt(DefCount);
        PPUFile.WriteEntry(IBStartDefs);
        { now write the definition }
        for I:=0 to DefList.Count-1 do
          begin
            Def:=TStoredDef(DefList[I]);
            if Def.IsRegistered then
              begin
                Def.PPUWrite(PPUFile);
                Def.PPUWriteSubEntries(PPUFile);
              end;
          end;
        { write end of definitions }
        PPUFile.WriteEntry(IBEndDefs);
      end;


    procedure TStoredSymTable.WriteSyms(PPUFile:TCompilerPPUFile);
      var
        SymCount,
        I   : LongInt;
        Sym : TStoredSym;
      begin
        SymCount:=0;
        for I:=0 to SymList.Count-1 do
          if TStoredSym(SymList[I]).IsRegistered then
            Inc(SymCount);
        { each definition get a number, write then the amount of syms and the
          datasize to the ibsymdef entry }
        PPUFile.PutLongInt(SymCount);
        PPUFile.WriteEntry(IBStartSyms);
        { foreach is used to write all symbols }
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TStoredSym(SymList[I]);
            if Sym.IsRegistered then
              begin
                Sym.PPUWrite(PPUFile);
                Sym.PPUWriteSubEntries(PPUFile);
              end;
          end;
        { end of symbols }
        PPUFile.WriteEntry(IBEndSyms);
      end;

    function TStoredSymTable.Is_Deref_Built: Boolean;
    begin
      Result:=FDerefBuilt;
    end;

    function TStoredSymTable.Is_DerefImpl_Built: Boolean;
    begin
      Result:=FDerefImplBuilt;
    end;

    procedure TStoredSymTable.BuildDeref;
      var
        I   : LongInt;
        Def : TStoredDef;
        Sym : TStoredSym;
      begin
        { interface definitions }
        for I:=0 to DefList.Count-1 do
          begin
            Def:=TStoredDef(DefList[I]);
            Def.BuildDeref;
          end;
        { interface symbols }
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TStoredSym(SymList[I]);
            Sym.BuildDeref;
          end;
        FDerefBuilt:=True;
      end;


    procedure TStoredSymTable.BuildDerefImpl;
      var
        I   : LongInt;
        Def : TStoredDef;
      begin
        { implementation definitions }
        for I:=0 to DefList.Count-1 do
          begin
            Def:=TStoredDef(DefList[I]);
            Def.BuildDerefImpl;
          end;
        FDerefImplBuilt:=True;
      end;


    procedure TStoredSymTable.BuildDeref_Registered;
      var
        Def : TStoredDef;
        Sym : TStoredSym;
        I   : LongInt;
        DefIDMax,
        SymIDMax: LongInt;
        NewBuiltDefDerefs,
        BuiltDefDerefs,
        BuiltSymDerefs: array of Boolean;
        Changed: Boolean;
      begin
        NewBuiltDefDerefs:=nil;
        BuiltDefDerefs:=nil;
        BuiltSymDerefs:=nil;
        { tdefs for which we already built the deref }
        SetLength(BuiltDefDerefs,DefList.Count);
        { tdefs for which we built the deref in this iteration }
        SetLength(NewBuiltDefDerefs,DefList.Count);
        { syms for which we already built the deref }
        SetLength(BuiltSymDerefs,SymList.Count);
        repeat
          { we only have to store the defs (recursively) referred by wpo info
            or inlined routines in the static symbtable }

          { current number of registered defs/syms }
          DefIDMax:=CurrentModule.DefList.Count;
          SymIDMax:=CurrentModule.SymList.Count;
          Changed:=False;

          { build the derefs for the registered defs we haven't processed yet }
          for I:=0 to DefList.Count-1 do
            begin
              if not BuiltDefDerefs[I] then
                begin
                  Def:=TStoredDef(DefList[I]);
                  if Def.IsRegistered then
                    begin
                      Def.BuildDeref;
                      NewBuiltDefDerefs[I]:=True;
                      BuiltDefDerefs[I]:=True;
                      Changed:=True;
                    end;
                end;
            end;
          { same for the syms }
          for I:=0 to SymList.Count-1 do
            begin
              if not BuiltSymDerefs[I] then
                begin
                  Sym:=TStoredSym(SymList[I]);
                  if Sym.IsRegistered then
                    begin
                      Sym.BuildDeref;
                      BuiltSymDerefs[I]:=True;
                      Changed:=True;
                    end;
                end;
            end;
          { now buildderefimpl for the defs we processed in this iteration }
          for I:=0 to DefList.Count-1 do
            begin
              if NewBuiltDefDerefs[I] then
                begin
                  NewBuiltDefDerefs[I]:=False;
                  TStoredDef(DefList[I]).BuildDerefImpl;
                  Changed:=True;
                end;
            end;
        { stop when no new defs or syms have been registered while processing
          the currently registered ones (defs/syms get added to the module's
          deflist/symlist when they are registered) }
        until not Changed and
          (DefIDMax=CurrentModule.DefList.Count) and
          (SymIDMax=CurrentModule.SymList.Count);
      end;


    procedure TStoredSymTable.Deref(OnlyRegistered: Boolean);
      var
        I   : LongInt;
        Def : TStoredDef;
        Sym : TStoredSym;
      begin
        { first deref the interface ttype symbols. This needs
          to be done before the interface defs are derefed, because
          the interface defs can contain references to the type symbols
          which then already need to contain a resolved typedef field (PFV) }
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TStoredSym(SymList[I]);
            if (Sym.Typ=TypeSym) and
               (not OnlyRegistered or
                Sym.IsRegistered) then
              Sym.Deref;
          end;
        { interface definitions }
        for I:=0 to DefList.Count-1 do
          begin
            Def:=TStoredDef(DefList[I]);
            if not OnlyRegistered or
               Def.IsRegistered then
              Def.Deref;
          end;
        { interface symbols }
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TStoredSym(SymList[I]);
            if (not OnlyRegistered or
                Sym.IsRegistered) and
               (Sym.Typ<>TypeSym) then
              Sym.Deref;
          end;
      end;


    procedure TStoredSymTable.DerefImpl(OnlyRegistered: Boolean);
      var
        I   : LongInt;
        Def : TStoredDef;
      begin
        { implementation definitions }
        for I:=0 to DefList.Count-1 do
          begin
            Def:=TStoredDef(DefList[I]);
            if not OnlyRegistered or
               Def.IsRegistered then
              Def.DerefImpl;
          end;
      end;


    function TStoredSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      var
        HSym : TSym;
      begin
        HSym:=TSym(FindWithHash(HashedID));
        if Assigned(HSym) then
          DuplicateSym(HashedID,Sym,HSym,False);
        Result:=Assigned(HSym);
      end;


{**************************************
             Callbacks
**************************************}

    procedure TStoredSymTable.CheckForward(Sym:TObject;Arg:Pointer);
      begin
         if TSym(Sym).Typ=ProcSym then
           TProcSym(Sym).Check_Forward
         { check also object method table            }
         { we needn't to test the def list          }
         { because each object has to have a type sym,
           only test objects declarations, not type renamings }
         else
          if (TSym(Sym).Typ=TypeSym) and
             Assigned(TTypeSym(Sym).TypeDef) and
             (TTypeSym(Sym).TypeDef.TypeSym=TTypeSym(Sym)) and
             (TTypeSym(Sym).TypeDef.Typ in [ObjectDef,RecordDef]) then
           TAbstractRecordDef(TTypeSym(Sym).TypeDef).Check_Forwards;
      end;


    procedure TStoredSymTable.CheckBlockValid(Def: TObject; Arg: Pointer);
      var
        FoundErrorDef: TDef;
      begin
        { all parameters passed to a block must be handled by the Objective-C
          runtime }
        if Is_Block(TDef(Def)) and
           not ObjCCheckType(TDef(Def),FoundErrorDef) then
          if Assigned(TDef(Def).TypeSym) then
            MessagePos1(TDef(Def).TypeSym.FileInfo,type_e_objc_type_unsupported,FoundErrorDef.TypeName)
          else
            Message1(type_e_objc_type_unsupported,TProcVarDef(Def).TypeName)
      end;


    procedure TStoredSymTable.RegisterSyms(Sym:TObject;Arg:Pointer);
      begin
        TSym(Sym).RegisterSym;
      end;


    procedure TStoredSymTable.RegisterDefs(Def:TObject;Arg:Pointer);
      begin
        TDef(Def).RegisterDef;
      end;


    procedure TStoredSymTable.LabelDefined(Sym:TObject;Arg:Pointer);
      begin
        if (TSym(Sym).Typ=LabelSym) and
           not(TLabelSym(Sym).Defined) then
         begin
           if TLabelSym(Sym).Used then
            Message1(sym_e_label_used_and_not_defined,TLabelSym(Sym).RealName)
           else
            Message1(sym_w_label_not_defined,TLabelSym(Sym).RealName);
         end;
      end;


    procedure TStoredSymTable.VarSymbolUsed(Sym:TObject;Arg:Pointer);
      begin
         if (TSym(Sym).Typ in [StaticVarSym,LocalVarSym,ParaVarSym,FieldVarSym]) and
            ((TSym(Sym).Owner.SymTableType in
             [ParaSymTable,LocalSymTable,ObjectSymTable,RecordSymTable,StaticSymTable])) then
           begin
            { unused symbol should be reported only if no                    }
            { error is reported                                              }
            { if the symbol is in a register it is used                      }
            { also don't count the value parameters which have local copies  }
            { also don't claim for high param of open parameters    (PM)     }
            { also don't complain about unused symbols in generic procedures }
            { and methods                                                    }
            { and neither in abstract methods                                }
            if (ErrorCount<>0) or
               ([vo_is_hidden_para,vo_is_funcret] * TAbstractVarSym(Sym).VarOptions = [vo_is_hidden_para]) or
               (sp_internal in TSym(Sym).SymOptions) or
               ((Assigned(TSym(Sym).Owner.DefOwner) and
                (TSym(Sym).Owner.DefOwner.Typ=ProcDef) and
                ((df_generic in TProcDef(TSym(Sym).Owner.DefOwner).DefOptions) or
                 (po_abstractmethod in TProcDef(TSym(Sym).Owner.DefOwner).ProcOptions)))) then
              Exit;
            if (TStoredSym(Sym).Refs=0) then
              begin
                 if (vo_is_funcret in TAbstractVarSym(Sym).VarOptions) then
                   begin
                     { don't warn about the result of constructors }
                     { or the synthetic helper functions for class-attributes }
                     if ((TSym(Sym).Owner.SymTableType<>LocalSymTable) or
                        (TProcDef(TSym(Sym).Owner.DefOwner).ProcTypeOption<>potype_constructor)) and
                        not (po_noreturn in TProcDef(TSym(Sym).Owner.DefOwner).ProcOptions) and
                        not(cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) then
                       MessagePos(TSym(Sym).FileInfo,sym_w_function_result_not_set)
                   end
                 else if (TSym(Sym).Owner.SymTableType=ParaSymTable) then
                   MessagePos1(TSym(Sym).FileInfo,sym_h_para_identifier_not_used,TSym(Sym).PrettyName)
                 else if (TSym(Sym).Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
                   MessagePos2(TSym(Sym).FileInfo,sym_n_private_identifier_not_used,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName)
                 else
                   MessagePos1(TSym(Sym).FileInfo,sym_n_local_identifier_not_used,TSym(Sym).PrettyName);
              end
            else if TAbstractVarSym(Sym).VarState in [vs_written,vs_initialised] then
              begin
                 if (TSym(Sym).Owner.SymTableType=ParaSymTable) then
                   begin
                     if not(TAbstractVarSym(Sym).VarSpez in [vs_var,vs_out,vs_constref]) and
                        not(vo_is_funcret in TAbstractVarSym(Sym).VarOptions) then
                       MessagePos1(TSym(Sym).FileInfo,sym_h_para_identifier_only_set,TSym(Sym).PrettyName)
                   end
                 else if (TSym(Sym).Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
                   MessagePos2(TSym(Sym).FileInfo,sym_n_private_identifier_only_set,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName)
                 else if TAbstractVarSym(Sym).VarOptions*[vo_is_funcret,vo_is_public,vo_is_external]=[] then
                   MessagePos1(TSym(Sym).FileInfo,sym_n_local_identifier_only_set,TSym(Sym).PrettyName);
              end
            else if (TAbstractVarSym(Sym).VarState = vs_read_not_warned) and
                    ([vo_is_public,vo_is_external] * TAbstractVarSym(Sym).VarOptions = []) then
              MessagePos1(TSym(Sym).FileInfo,sym_w_identifier_only_read,TSym(Sym).PrettyName)
          end
        else if ((TSym(Sym).Owner.SymTableType in
              [ObjectSymTable,ParaSymTable,LocalSymTable,StaticSymTable,RecordSymTable])) then
          begin
           if (ErrorCount<>0) or
              (sp_internal in TSym(Sym).SymOptions) then
             Exit;
           { do not claim for inherited private fields !! }
           if (TSym(Sym).Refs=0) and (TSym(Sym).Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
             case TSym(Sym).Typ of
               TypeSym:
                 MessagePos2(TSym(Sym).FileInfo,sym_n_private_type_not_used,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName);
               ConstSym:
                 MessagePos2(TSym(Sym).FileInfo,sym_n_private_const_not_used,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName);
               PropertySym:
                 MessagePos2(TSym(Sym).FileInfo,sym_n_private_property_not_used,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName);
             else
               MessagePos2(TSym(Sym).FileInfo,sym_n_private_method_not_used,TAbstractRecordDef(TSym(Sym).Owner.DefOwner).GetTypeName,TSym(Sym).PrettyName);
             end
           { units references are problematic }
           else
            begin
              if (TSym(Sym).Refs=0) and
                 not(TSym(Sym).Typ in [EnumSym,UnitSym,NamespaceSym]) and
                 not(Is_FuncRet_Sym(TSym(Sym))) and
                 { don't complain about compiler generated syms for specializations, see also #13405 }
                 not((TSym(Sym).Typ=TypeSym) and (df_specialization in TTypeSym(Sym).TypeDef.DefOptions) and
                    (Pos('$',TTypeSym(Sym).RealName)<>0)) and
                 (
                  (TSym(Sym).Typ<>ProcSym) or
                  ((TSym(Sym).Owner.SymTableType=StaticSymTable) and
                   not CurrentModule.IsUnit)
                 ) and
                 { don't complain about alias for hidden _cmd parameter to
                   obj-c methods }
                 not((TSym(Sym).Typ in [LocalVarSym,ParaVarSym,AbsoluteVarSym]) and
                     (vo_is_msgsel in TAbstractVarSym(Sym).VarOptions)) then
                MessagePos2(TSym(Sym).FileInfo,sym_h_local_symbol_not_used,SymTypeName[TSym(Sym).Typ],TSym(Sym).PrettyName);
            end;
          end;
      end;


    procedure TStoredSymTable.TestPrivate(Sym:TObject;Arg:Pointer);
      begin
        if TSym(Sym).Visibility in [vis_private,vis_strictprivate] then
          VarSymbolUsed(Sym,Arg);
      end;


    procedure TStoredSymTable.ObjectPrivateSymbolUsed(Sym:TObject;Arg:Pointer);
      begin
         {
           Don't test simple object aliases PM
         }
         if (TSym(Sym).Typ=TypeSym) and
            (TTypeSym(Sym).TypeDef.Typ in [ObjectDef,RecordDef]) and
            (TTypeSym(Sym).TypeDef.TypeSym=TSym(Sym)) then
           TAbstractRecordDef(TTypeSym(Sym).TypeDef).SymTable.SymList.ForEachCall(@TestPrivate,nil);
      end;


   procedure TStoredSymTable.TestForDefaultProperty(Sym:TObject;Arg:Pointer);
     begin
        if (TSym(Sym).Typ=PropertySym) and
           (ppo_defaultproperty in TPropertySym(Sym).PropOptions) then
          PPointer(Arg)^:=Sym;
     end;


   procedure TStoredSymTable.Register_Children;
     begin
       SymList.ForEachCall(@RegisterSyms,nil);
       DefList.ForEachCall(@RegisterDefs,nil);
     end;


{***********************************************
           Process all entries
***********************************************}

    { checks, if all procsyms and methods are defined }
    procedure TStoredSymTable.Check_Forwards;
      begin
         SymList.ForEachCall(@CheckForward,nil);
         { check whether all block definitions contain valid Objective-C types
           (now that all forward definitions have been resolved) }
         DefList.ForEachCall(@CheckBlockValid,nil);
      end;


    procedure TStoredSymTable.CheckLabels;
      begin
         SymList.ForEachCall(@LabelDefined,nil);
      end;


    procedure TStoredSymTable.AllSymbolsUsed;
      begin
         SymList.ForEachCall(@VarSymbolUsed,nil);
      end;


    procedure TStoredSymTable.AllPrivatesUsed;
      begin
         SymList.ForEachCall(@ObjectPrivateSymbolUsed,nil);
      end;


    procedure TStoredSymTable.NeedsInitFinal(Sym:TObject;Arg:Pointer);
      begin
         if [sto_needs_init_final,sto_has_non_trivial_init] <= TableOptions then
           Exit;
         { don't check static symbols - they can be present in structures only and
           always have a reference to a symbol defined on unit level }
         if sp_static in TSym(Sym).SymOptions then
           Exit;
         case TSym(Sym).Typ of
           FieldVarSym,
           StaticVarSym,
           LocalVarSym,
           ParaVarSym :
             begin
               if Assigned(TAbstractVarSym(Sym).VarDef) and
                  Is_Managed_Type(TAbstractVarSym(Sym).VarDef) then
                 Include(TableOptions,sto_needs_init_final);
               if Is_Record((TAbstractVarSym(Sym).VarDef)) and
                   (mop_initialize in TRecordSymTable(TRecordDef(TAbstractVarSym(Sym).VarDef).SymTable).ManagementOperators) then
                 Include(TableOptions,sto_has_non_trivial_init);
             end;
           else
             ;
         end;
      end;


    procedure TStoredSymTable.DoInitFinalCheck;
      begin
         if not FInitFinalCheckDone then
           begin
             Exclude(TableOptions,sto_needs_init_final);
             Exclude(TableOptions,sto_has_non_trivial_init);
             SymList.ForEachCall(@NeedsInitFinal,nil);
             FInitFinalCheckDone:=True;
           end;
      end;

    { returns true, if p contains data which needs init/final code }
    function TStoredSymTable.Needs_Init_Final : Boolean;
      begin
         DoInitFinalCheck;
         Result:=sto_needs_init_final in TableOptions;
      end;


    function TStoredSymTable.Has_Non_Trivial_Init:Boolean;
      begin
        DoInitFinalCheck;
        Result:=sto_has_non_trivial_init in TableOptions;
      end;


{****************************************************************************
                          TAbstractRecordSymtable
****************************************************************************}



    constructor TAbstractRecordSymTable.Create(const N:string;UseAlign,RecordMinAlign:ShortInt);
      begin
        inherited Create(N);
        FDataSize:=0;
        DataBitSize:=0;
        RecordAlignment:=1;
        ExplicitRecordAlignment:=0;
        UseFieldAlignment:=UseAlign;
        RecordAlignMin:=RecordMinAlign;
        PadAlignment:=1;
        { recordalign C_alignment means C record packing, that starts
          with an alignment of 1 }
        case UseAlign of
          CAlignment,
          BitAlignment:
            FieldAlignment:=1;
          Mac68KAlignment:
            FieldAlignment:=2;
          else
            FieldAlignment:=UseAlign;
        end;
      end;


    destructor TAbstractRecordSymTable.Destroy;
      var
        MOP : TManagementOperator;
      begin
        if RefCount>1 then
          Exit;

        for MOP:=Low(TManagementOperator) to High(TManagementOperator) do
          TFPList.FreeAndNilDisposing(MOPList[MOP],TypeInfo(TManagementOperatorOffsetEntry));
        inherited Destroy;
      end;


    procedure TAbstractRecordSymTable.PPULoad(PPUFile:TCompilerPPUFile);
      begin
        if PPUFile.ReadEntry<>IBRecSymTableOptions then
          Message(unit_f_ppu_read_error);
        RecordAlignment:=ShortInt(PPUFile.GetByte);
        ExplicitRecordAlignment:=ShortInt(PPUFile.GetByte);
        UseFieldAlignment:=ShortInt(PPUFile.GetByte);
        RecordAlignMin:=ShortInt(PPUFile.GetByte);
        if (UseFieldAlignment=CAlignment) then
          FieldAlignment:=ShortInt(PPUFile.GetByte);
        PPUFile.GetSet(TPPUSet1(HasFieldsWithMOP));
        inherited PPULoad(PPUFile);
      end;


    procedure TAbstractRecordSymTable.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldTyp : Byte;
      begin
         OldTyp:=PPUFile.EntryTyp;
         PPUFile.EntryTyp:=SubEntryID;
         { in case of classes using C alignment, the alignment of the parent
           affects the alignment of fields of the childs }
         PPUFile.PutByte(Byte(RecordAlignment));
         PPUFile.PutByte(Byte(ExplicitRecordAlignment));
         PPUFile.PutByte(Byte(UseFieldAlignment));
         PPUFile.PutByte(Byte(RecordAlignMin));
         if (UseFieldAlignment=CAlignment) then
           PPUFile.PutByte(Byte(FieldAlignment));
         { it's not really a "symtableoption", but loading this from the record
           def requires storing the set in the recorddef at least between
           ppuload and deref/derefimpl }
         PPUFile.PutSet(TPPUSet1(HasFieldsWithMOP));
         PPUFile.WriteEntry(IBRecSymTableOptions);

         inherited PPUWrite(PPUFile);

         PPUFile.EntryTyp:=OldTyp;
      end;


    function Field2RecordAlignment(FieldOffs, FieldAlign: ASizeInt): ASizeInt;
      begin
        { optimal alignment of the record when declaring a variable of this }
        { type is independent of the packrecords setting                    }
        if (FieldOffs mod FieldAlign) = 0 then
          Result:=FieldAlign
        else if (FieldAlign >= 16) and
                ((FieldOffs mod 16) = 0) and
                ((FieldAlign mod 16) = 0) then
          Result:=16
        else if (FieldAlign >= 8) and
                ((FieldOffs mod 8) = 0) and
                ((FieldAlign mod 8) = 0) then
          Result:=8
        else if (FieldAlign >= 4) and
                ((FieldOffs mod 4) = 0) and
                ((FieldAlign mod 4) = 0) then
          Result:=4
        else if (FieldAlign >= 2) and
                ((FieldOffs mod 2) = 0) and
                ((FieldAlign mod 2) = 0) then
          Result:=2
        else
          Result:=1;
      end;

    procedure TAbstractRecordSymTable.AlignRecord(FieldOffset:ASizeInt;VarAlign:ShortInt);
      var
        VarAlignRecord: ShortInt;
      begin
        case UseFieldAlignment of
          CAlignment:
            VarAlignRecord:=Used_Align(VarAlign,RecordAlignMin,CurrentSettings.Alignment.MaxCRecordAlign);
          Mac68KAlignment:
            VarAlignRecord:=2;
          else
            VarAlignRecord:=Field2RecordAlignment(FieldOffset,VarAlign);
        end;
        RecordAlignment:=Max(RecordAlignment,VarAlignRecord);
      end;

    procedure TAbstractRecordSymTable.AddField(Sym:TFieldVarSym;Vis:TVisibility);
      var
        L      : ASizeInt;
        VarAlign : ShortInt;
        VarDef : TDef;
      begin
        if (Sym.Owner<>Self) then
          InternalError(200602031);
        if Sym.FieldOffset<>-1 then
          InternalError(200602032);
        { set visibility for the symbol }
        Sym.Visibility:=Vis;
        { this symbol can't be loaded to a register }
        Sym.VarRegable:=vr_none;
        { management operators }
        if Sym.VarDef.Typ in [RecordDef,ObjectDef] then
          HasFieldsWithMOP:=HasFieldsWithMOP + TAbstractRecordSymTable(TAbstractRecordDef(Sym.VarDef).SymTable).HasFieldsWithMOP;
        if Sym.VarDef.Typ=RecordDef then
          HasFieldsWithMOP:=HasFieldsWithMOP + TRecordSymTable(TRecordDef(Sym.VarDef).SymTable).ManagementOperators;
        { Calculate field offset }
        L:=Sym.GetSize;
        VarDef:=Sym.VarDef;
        VarAlign:=VarDef.StructAlignment;
        case UseFieldAlignment of
          BitAlignment:
            begin
              { bitpacking only happens for ordinals, the rest is aligned at }
              { 1 byte (compatible with GPC/GCC)                             }
              if Is_Ordinal(VarDef) then
                begin
                  Sym.FieldOffset:=DataBitSize;
                  L:=Sym.GetPackedBitSize;
                end
              else
                begin
                  DataBitSize:=FDataSize*8;
                  Sym.FieldOffset:=DataBitSize;
                  if (L>High(ASizeInt) div 8) then
                    Message(sym_e_segment_too_large);
                  L:=L*8;
                end;
              if VarAlign=0 then
                VarAlign:=Size_2_Align(L);
              RecordAlignment:=Max(RecordAlignment,Field2RecordAlignment(DataBitSize mod 8,VarAlign));
              { bit packed records are limited to high(aint) bits }
              { instead of bytes to avoid double precision        }
              { arithmetic in offset calculations                 }
              if Int64(L)>High(ASizeInt)-Sym.FieldOffset then
                begin
                  Message(sym_e_segment_too_large);
                  FDataSize:=High(ASizeInt);
                  DataBitSize:=High(ASizeInt);
                end
              else
                begin
                  DataBitSize:=Sym.FieldOffset+L;
                  FDataSize:=(DataBitSize+7) div 8;
                end;
              { rest is not applicable }
              Exit;
            end;
          else
            begin
              Sym.FieldOffset:=GetFieldOffset(Sym,FDataSize,FieldAlignment);
              if L>High(ASizeInt)-Sym.FieldOffset then
                begin
                  Message(sym_e_segment_too_large);
                  FDataSize:=High(ASizeInt);
                end
              else
                FDataSize:=Sym.FieldOffset+L;
              { Calc alignment needed for this record }
              AlignRecord(Sym.FieldOffset,VarAlign);
            end;
        end;
      end;


    function FieldAlignmentCompare(Item1, Item2: Pointer): Integer;
      var
        Field1: TFieldVarSym absolute Item1;
        Field2: TFieldVarSym absolute Item2;
      begin
        { we don't care about static fields, those become global variables }
        if (sp_static in Field1.SymOptions) or
           (sp_static in Field2.SymOptions) then
          Exit(0);
        { sort from large to small alignment, and in case of the same alignment
          in declaration order (items declared close together are possibly
          also related and hence possibly used together -> putting them next
          to each other can improve cache behaviour) }
        Result:=Field2.VarDef.Alignment-Field1.VarDef.Alignment;
        if Result=0 then
          Result:=Field1.FieldOffset-Field2.FieldOffset;
      end;


    procedure TAbstractRecordSymTable.AddFieldList(List: TFPObjectList; MaybeReorder: Boolean);
      var
        FieldVS, InsertFieldVS: TFieldVarSym;
        Base, FieldOffset, Space, InsertFieldSize, InsertFieldOffset, BestInsertFieldOffset, BestSpaceLeft: ASizeInt;
        I, J, BestFieldIndex: LongInt;
        GlobalFieldAlignment,
        PrevGlobalFieldAlignment,
        NewFieldAlignment: ShortInt;
        Changed: Boolean;
      begin
        if MaybeReorder and
           (cs_opt_reorder_fields in CurrentSettings.OptimizerSwitches) and
           (List.Count>1) then
          begin
            { assign dummy field offsets so we can know their order in the
              sorting routine }
            for I:=0 to List.Count-1 do
              begin
                FieldVS:=TFieldVarSym(List[I]);
                if sp_static in FieldVS.SymOptions then
                  Continue;
                FieldVS.FieldOffset:=I;
              end;
            { sort the non-class fields to minimise losses due to alignment }
            List.Sort(@FieldAlignmentCompare);
            { now fill up gaps caused by alignment skips with smaller fields
              where possible }
            repeat
              I:=0;
              Base:=FDataSize;
              GlobalFieldAlignment:=FieldAlignment;
              Changed:=False;
              while I<List.Count do
                begin
                  FieldVS:=TFieldVarSym(List[I]);
                  if sp_static in FieldVS.SymOptions then
                    begin
                      Inc(I);
                      Continue;
                    end;
                  PrevGlobalFieldAlignment:=GlobalFieldAlignment;
                  FieldOffset:=GetFieldOffset(FieldVS,Base,GlobalFieldAlignment);
                  NewFieldAlignment:=GlobalFieldAlignment;

                  { size of the gap between the end of the previous field and
                    the start of the current one }
                  Space:=FieldOffset-Base;
                  BestSpaceLeft:=Space;
                  while Space>0 do
                    begin
                      BestFieldIndex:=-1;
                      BestInsertFieldOffset:=-1;
                      for J:=I+1 to List.Count-1 do
                        begin
                          InsertFieldVS:=TFieldVarSym(List[J]);
                          if sp_static in InsertFieldVS.SymOptions then
                            Continue;
                          InsertFieldSize:=InsertFieldVS.GetSize;
                          { can the new field fit possibly in the gap? }
                          if InsertFieldSize<=Space then
                            begin
                             { restore globalfieldalignment to situation before
                               the original field was inserted }
                              GlobalFieldAlignment:=PrevGlobalFieldAlignment;
                              { at what offset would it be inserted? (this new
                                field has its own alignment requirements, which
                                may make it impossible to fit after all) }
                              InsertFieldOffset:=GetFieldOffset(InsertFieldVS,Base,GlobalFieldAlignment);
                              GlobalFieldAlignment:=PrevGlobalFieldAlignment;
                              { taking into account the alignment, does it still
                                fit and if so, does it fit better than the
                                previously found best fit? }
                              if (InsertFieldOffset+InsertFieldSize<=FieldOffset) and
                                 (FieldOffset-InsertFieldOffset-InsertFieldSize<BestSpaceLeft) then
                                begin
                                  { new best fit }
                                  BestFieldIndex:=J;
                                  BestInsertFieldOffset:=InsertFieldOffset;
                                  BestSpaceLeft:=FieldOffset-InsertFieldOffset-InsertFieldSize;
                                  if BestSpaceLeft=0 then
                                    Break;
                                end;
                            end;
                        end;
                      { if we didn't find any field to fit, stop trying for this
                        gap }
                      if BestFieldIndex=-1 then
                        Break;
                      Changed:=True;
                      { we found a field to insert -> adjust the new base
                        address }
                      Base:=BestInsertFieldOffset+TFieldVarSym(List[BestFieldIndex]).GetSize;
                      { update globalfieldalignment for this newly inserted
                        field }
                      GetFieldOffset(TFieldVarSym(List[BestFieldIndex]),Base,GlobalFieldAlignment);
                      { move the new field before the current one }
                      List.Move(BestFieldIndex,I);
                      { and skip the new field (which is now at position i) }
                      Inc(I);
                      { there may be more space left -> continue }
                      Space:=BestSpaceLeft;
                    end;
                  if Base>FieldOffset then
                    InternalError(2012071302);
                  { check the next field }
                  Base:=FieldOffset+FieldVS.GetSize;
                  { since the original field had the same or greater alignment
                    than anything we inserted before it, the global field
                    alignment is still the same now as it was originally after
                    inserting that field }
                  GlobalFieldAlignment:=NewFieldAlignment;
                  Inc(I);
                end;
            { there may be small gaps left *before* inserted fields }
          until not Changed;
        end;
        { reset the dummy field offsets }
        for I:=0 to List.Count-1 do
          begin
            FieldVS:=TFieldVarSym(List[I]);
            if sp_static in FieldVS.SymOptions then
              Continue;
            FieldVS.FieldOffset:=-1;
          end;
        { finally, set the actual field offsets }
        for I:=0 to List.Count-1 do
          begin
            FieldVS:=TFieldVarSym(List[I]);
            { static data fields are already inserted in the globalsymtable }
            if not(sp_static in FieldVS.SymOptions) then
              begin
                { read_record_fields already set the visibility of the fields,
                  because a single list can contain symbols with different
                  visibility }
                AddField(FieldVS,FieldVS.Visibility);
              end;
          end;
      end;


    function TAbstractRecordSymTable.FindFieldByOffset(Offset: ASizeInt): TFieldVarSym;
      var
        I: LongInt;
        Sym: TSym;
      begin
        { there could be multiple fields in case of a variant record }
        if (DefOwner.Typ=RecordDef) and
           TRecordDef(DefOwner).IsUnion then
          InternalError(2014090403);
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TSym(SymList[I]);
            if Is_Normal_FieldVarSym(Sym) and
               (TFieldVarSym(Sym).FieldOffset>=Offset) then
              begin
                Result:=TFieldVarSym(Sym);
                Exit;
              end;
          end;
        Result:=nil;
      end;


    procedure TAbstractRecordSymTable.AddAlignmentPadding;
      var
        PaddedDataSize: ASizeInt;
      begin
        { make the record size aligned correctly so it can be
          used as elements in an array. For C records we
          use the fieldalignment, because that is updated with the
          used alignment. }
        if (PadAlignment = 1) then
          case UseFieldAlignment of
            CAlignment:
              PadAlignment:=FieldAlignment;
            { bitpacked }
            BitAlignment:
              PadAlignment:=1;
            { mac68k: always round to multiple of 2 }
            Mac68KAlignment:
              PadAlignment:=2;
            { default/no packrecords specified }
            0:
              PadAlignment:=RecordAlignment
            { specific packrecords setting -> use as upper limit }
            else
              PadAlignment:=Min(RecordAlignment,UseFieldAlignment);
          end;
        PaddedDataSize:=Align(FDataSize,PadAlignment);
        FPaddingSize:=PaddedDataSize-FDataSize;
        FDataSize:=PaddedDataSize;
      end;


    procedure TAbstractRecordSymTable.InsertDef(Def:TDefEntry);
      begin
        { Enums must also be available outside the record scope,
          insert in the owner of this symtable }
        if Def.Typ=EnumDef then
          DefOwner.Owner.InsertDef(Def)
        else
          inherited InsertDef(Def);
      end;


    function TAbstractRecordSymTable.Is_Packed: Boolean;
      begin
        Result:=UseFieldAlignment=BitAlignment;
      end;


    function TAbstractRecordSymTable.Has_Double_Field(out Def1,Def2:TDef; out Offset:Integer): Integer;
      var
        I,Cnt: LongInt;
        CurrentSymList: TFPHashObjectList;
        Sym: TFieldVarSym;
      begin
        Has_Double_Field := 0;
        Offset := 0;
        if (DefOwner.Typ=RecordDef) and
           TRecordDef(DefOwner).IsUnion then
          Exit;
        CurrentSymList:=SymList;
        if CurrentSymList = nil then
          Exit;
        if CurrentSymList.Count <> 2 then
          Exit;
        if Is_Normal_FieldVarSym(TSym(CurrentSymList[0])) then
          begin
            Sym:=TFieldVarSym(CurrentSymList[0]);
            Def1 := Sym.VarDef;
          end
        else
          Exit;
        if Is_Normal_FieldVarSym(TSym(CurrentSymList[1])) then
          begin
            Sym:=TFieldVarSym(CurrentSymList[1]);
            Def2 := Sym.VarDef;
          end
        else
          Exit;
        Offset := Sym.FieldOffset;
        if Def2.Typ = Def1.Typ then
          Cnt := 2
        else
          Cnt := 1;
        if Offset = 0 then
          Cnt := 0;
        Has_Double_Field := Cnt;
      end;


    function TAbstractRecordSymTable.Has_Single_Field(out Def:TDef): Boolean;
      var
        I: LongInt;
        CurrentSymList: TFPHashObjectList;
        CurrentDef: TDef;
        Sym: TFieldVarSym;
      begin
        Result:=False;
        Def:=GenErrorDef;
        { If a record contains a union, it does not contain a "single
          non-composite field" in the context of certain ABIs requiring
          special treatment for such records }
        if (DefOwner.Typ=RecordDef) and
           TRecordDef(DefOwner).IsUnion then
          Exit;
        { a record/object can contain other things than fields }
        CurrentSymList:=SymList;
        { recurse in arrays and records }
        while True do
          begin
            Sym:=nil;
            { record has one field? }
            for I:=0 to CurrentSymList.Count-1 do
              begin
                if Is_Normal_FieldVarSym(TSym(CurrentSymList[I])) then
                  begin
                    if Result then
                      begin
                        Result:=False;
                        Exit;
                      end;
                    Result:=True;
                    Sym:=TFieldVarSym(CurrentSymList[I]);
                  end;
              end;
            if Assigned(Sym) then
              begin
                { if the field is an array, does it contain one element? }
                CurrentDef:=Sym.VarDef;
                while (CurrentDef.Typ=ArrayDef) and
                      not Is_Special_Array(CurrentDef) do
                  begin
                    if TArrayDef(CurrentDef).EleCount<>1 then
                      begin
                        Result:=False;
                        Exit;
                      end;
                    CurrentDef:=TArrayDef(CurrentDef).ElementDef;
                  end;
                { if the array element is again a record, continue descending }
                if CurrentDef.Typ=RecordDef then
                  begin
                    { the record might be empty, so reset the result until we've
                      really found something }
                    Result:=False;
                    CurrentSymList:=TRecordDef(CurrentDef).SymTable.SymList
                  end
                else
                  begin
                    { otherwise we found the type of the single element }
                    Def:=CurrentDef;
                    Exit;
                  end;
              end
            else
              Exit
          end;
      end;


    procedure TAbstractRecordSymTable.Do_Get_ManagementOperator_Offset_List(Data:TObject;Arg:Pointer);
      var
        Sym : TSym absolute Data;
        FSym : TFieldVarSym absolute Data;
        MOP : TManagementOperator;
        Entry : PManagementOperatorOffsetEntry;
        SubList : TFPList;
        I : LongInt;
      begin
        if not Is_Normal_FieldVarSym(Sym) then
          Exit;
        if not Is_Record(FSym.VarDef) and not Is_Object(FSym.VarDef) and not Is_CPPClass(FSym.VarDef) then
          Exit;
        MOP:=TManagementOperator(PtrUInt(Arg));
        if not Assigned(MOPList[MOP]) then
          InternalError(2018082303);

        if Is_Record(FSym.VarDef) then
          begin
            if MOP in TRecordSymTable(TRecordDef(FSym.VarDef).SymTable).ManagementOperators then
              begin
                New(Entry);
                Entry^.PD:=Search_Management_Operator(MOP,FSym.VarDef);
                if not Assigned(Entry^.PD) then
                  InternalError(2018082302);
                Entry^.Offset:=FSym.FieldOffset;
                MOPList[MOP].Add(Entry);
              end;
          end;

        SubList:=TFPList.Create;
        TAbstractRecordSymTable(TAbstractRecordDef(FSym.VarDef).SymTable).Get_ManagementOperator_Offset_List(MOP,SubList);
        MOPList[MOP].Capacity:=MOPList[MOP].Count+SubList.Count;
        for I:=0 to SubList.Count-1 do
          begin
            Entry:=PManagementOperatorOffsetEntry(SubList[I]);
            Entry^.Offset:=Entry^.Offset+FSym.FieldOffset;
            MOPList[MOP].Add(Entry);
          end;
        { we don't need to remove the entries as they become part of list }
        SubList.Free;
        SubList := nil;
      end;

    procedure TAbstractRecordSymTable.Get_ManagementOperator_Offset_List(MOP:TManagementOperator;List:TFPList);
      var
        I : LongInt;
        Entry,EntryCopy : PManagementOperatorOffsetEntry;
      begin
        if not Assigned(List) then
          InternalError(2018082301);
        if MOP=mop_none then
          Exit;
        if not (MOP in HasFieldsWithMOP) then
          { none of the fields or one of the field's fields has the requested operator }
          Exit;
        if not Assigned(MOPList[MOP]) then
          begin
            MOPList[MOP]:=TFPList.Create;
            SymList.ForEachCall(@Do_Get_ManagementOperator_Offset_List,Pointer(PtrUInt(MOP)));
          end;
        for I:=0 to MOPList[MOP].Count-1 do
          begin
            Entry:=PManagementOperatorOffsetEntry(MOPList[MOP][I]);
            New(EntryCopy);
            EntryCopy^:=Entry^;
            List.Add(EntryCopy);
          end;
      end;

    procedure TAbstractRecordSymTable.SetDataSize(Val: ASizeInt);
      begin
        FDataSize:=Val;
        if (UseFieldAlignment=BitAlignment) then
          { can overflow in non bitpacked records }
          DataBitSize:=Val*8;
      end;

    function TAbstractRecordSymTable.GetFieldOffset(Sym: TFieldVarSym; Base: ASizeInt; var GlobalFieldAlignment: ShortInt): ASizeInt;
      var
        L      : ASizeInt;
        VarAlignField,
        VarAlign : ShortInt;
        VarDef : TDef;
      begin
        { Calculate field offset }
        L:=Sym.GetSize;
        VarDef:=Sym.VarDef;
        VarAlign:=VarDef.StructAlignment;
        case UseFieldAlignment of
          BitAlignment:
            { has to be handled separately }
            InternalError(2012071301);
          CAlignment:
            begin
              { Calc the alignment size for C style records }
              if (VarAlign>4) and
                ((VarAlign mod 4)<>0) and
                (VarDef.Typ=ArrayDef) then
                Message1(sym_w_wrong_C_pack,VarDef.TypeName);
              if VarAlign=0 then
                VarAlign:=L;
              if (GlobalFieldAlignment<CurrentSettings.Alignment.MaxCRecordAlign) then
                begin
                  if (VarAlign>16) and (GlobalFieldAlignment<32) then
                    GlobalFieldAlignment:=32
                  else if (VarAlign>12) and (GlobalFieldAlignment<16) then
                    GlobalFieldAlignment:=16
                  { 12 is needed for long double }
                  else if (VarAlign>8) and (GlobalFieldAlignment<12) then
                    GlobalFieldAlignment:=12
                  else if (VarAlign>4) and (GlobalFieldAlignment<8) then
                    GlobalFieldAlignment:=8
                  else if (VarAlign>2) and (GlobalFieldAlignment<4) then
                    GlobalFieldAlignment:=4
                  else if (VarAlign>1) and (GlobalFieldAlignment<2) then
                    GlobalFieldAlignment:=2;
                end;
              GlobalFieldAlignment:=Min(GlobalFieldAlignment,CurrentSettings.Alignment.MaxCRecordAlign);
            end;
          Mac68KAlignment:
            begin
              { mac68k alignment (C description):
                 * char is aligned to 1 byte
                 * everything else (except vector) is aligned to 2 bytes
                 * vector is aligned to 16 bytes
              }
              if L>1 then
                GlobalFieldAlignment:=2
              else
                GlobalFieldAlignment:=1;
              VarAlign:=2;
            end;
        end;
        if VarAlign=0 then
          VarAlign:=Size_2_Align(L);
        VarAlignField:=Used_Align(VarAlign,RecordAlignMin,GlobalFieldAlignment);

        Result:=Align(Base,VarAlignField);
      end;

    function TAbstractRecordSymTable.IsCurrentUnit: Boolean;
      begin
        Result:=Assigned(CurrentModule)and(CurrentModule.ModuleID=ModuleID);
      end;

{****************************************************************************
                              TRecordSymtable
****************************************************************************}

    constructor TRecordSymTable.Create(const N:string;UseAlign,RecordMinAlign:ShortInt);
      begin
        inherited Create(N,UseAlign,RecordMinAlign);
        SymTableType:=RecordSymTable;
      end;


   { this procedure is reserved for inserting case variant into
      a record symtable }
    { the offset is the location of the start of the variant
      and datasize and dataalignment corresponds to
      the complete size (see code in pdecl unit) PM }
    procedure TRecordSymTable.InsertUnionST(UnionST : TRecordSymTable;Offset : ASizeInt);
      var
        Sym : TSym;
        Def : TDef;
        I : Integer;
        VarAlignRecord,VarAlign,
        StoreSize,StoreAlign : ASizeInt;
        BitSize: TCGInt;
      begin
        StoreSize:=FDataSize;
        StoreAlign:=FieldAlignment;
        FDataSize:=Offset;
        if (UseFieldAlignment=BitAlignment) then
          DataBitSize:=Offset*8;

        { We move the ownership of the defs and symbols to the new recordsymtable.
          The old unionsymtable keeps the references, but doesn't own the
          objects anymore }
        UnionST.DefList.OwnsObjects:=False;
        UnionST.SymList.OwnsObjects:=False;

        { copy symbols }
        for I:=0 to UnionST.SymList.Count-1 do
          begin
            Sym:=TSym(UnionST.SymList[I]);
            if not Is_Normal_FieldVarSym(Sym) then
              InternalError(200601272);
            if TFieldVarSym(Sym).FieldOffset=0 then
              Include(TFieldVarSym(Sym).VarOptions,vo_is_first_field);

            { add to this record symtable, checking for duplicate names }
//            unionst.SymList.List.List^[i].Data:=nil;
            InsertSym(Sym);
            VarAlign:=TFieldVarSym(Sym).VarDef.Alignment;
            if VarAlign=0 then
              VarAlign:=Size_2_Align(TFieldVarSym(Sym).GetSize);
            { retrieve size }
            if (UseFieldAlignment=BitAlignment) then
              begin
                { bit packed records are limited to high(aint) bits }
                { instead of bytes to avoid double precision        }
                { arithmetic in offset calculations                 }
                if Is_Ordinal(TFieldVarSym(Sym).VarDef) then
                  BitSize:=TFieldVarSym(Sym).GetPackedBitSize
                else
                  begin
                    BitSize:=TFieldVarSym(Sym).GetSize;
                    if (BitSize>High(ASizeInt) div 8) then
                      Message(sym_e_segment_too_large);
                    BitSize:=BitSize*8;
                  end;
                if BitSize>High(ASizeInt)-DataBitSize then
                  begin
                    Message(sym_e_segment_too_large);
                    FDataSize:=High(ASizeInt);
                    DataBitSize:=High(ASizeInt);
                  end
                else
                  begin
                    DataBitSize:=TFieldVarSym(Sym).FieldOffset+Offset*8;
                    FDataSize:=(DataBitSize+7) div 8;
                  end;
                TFieldVarSym(Sym).FieldOffset:=DataBitSize;
              VarAlignRecord:=Field2RecordAlignment(TFieldVarSym(Sym).FieldOffset div 8,VarAlign);
              end
            else
              begin
                if TFieldVarSym(Sym).GetSize>High(ASizeInt)-FDataSize then
                  begin
                    Message(sym_e_segment_too_large);
                    FDataSize:=High(ASizeInt);
                  end
                else
                  FDataSize:=TFieldVarSym(Sym).FieldOffset+Offset;
                { update address }
                TFieldVarSym(Sym).FieldOffset:=FDataSize;
                VarAlignRecord:=Field2RecordAlignment(TFieldVarSym(Sym).FieldOffset,VarAlign);
              end;
            { update alignment of this record }
            if (UseFieldAlignment<>CAlignment) and
               (UseFieldAlignment<>Mac68KAlignment) then
              RecordAlignment:=Max(RecordAlignment,VarAlignRecord);
          end;
        { update alignment for C records }
        if (UseFieldAlignment=CAlignment) and
           (UseFieldAlignment<>Mac68KAlignment) then
          RecordAlignment:=Max(RecordAlignment,UnionST.RecordAlignment);
        { Register defs in the new record symtable }
        for I:=0 to UnionST.DefList.Count-1 do
          begin
            Def:=TDef(UnionST.DefList[I]);
            Def.ChangeOwner(Self);
          end;
        FDataSize:=StoreSize;
        FieldAlignment:=StoreAlign;
        { If a record contains a union, it does not contain a "single
          non-composite field" in the context of certain ABIs requiring
          special treatment for such records }
        if DefOwner.Typ=RecordDef then
          TRecordDef(DefOwner).IsUnion:=True;
      end;


    procedure TRecordSymTable.IncludeManagementOperator(MOP:TManagementOperator);
      begin
        if MOP in ManagementOperators then
          Exit;
        Include(ManagementOperators,MOP);
      end;


{****************************************************************************
                              TObjectSymtable
****************************************************************************}

    constructor TObjectSymTable.Create(ADefOwner:TDef;const N:string;UseAlign,RecordMinAlign:ShortInt);
      begin
        inherited Create(N,UseAlign,RecordMinAlign);
        SymTableType:=ObjectSymTable;
        DefOwner:=ADefOwner;
      end;


    function TObjectSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      var
         HSym: TSym;
         Warn: Boolean;
      begin
         Result:=False;
         if not Assigned(DefOwner) then
           InternalError(200602061);

         { procsym and propertysym have special code
           to override values in inherited classes. For other
           symbols check for duplicates (but for internal symbols only in this
           symtable, not the whole hierarchy) }
         if not(Sym.Typ in [ProcSym,PropertySym]) and
            not (sp_internal in TSym(Sym).SymOptions) then
           begin
              { but private ids can be reused }
              HSym:=Search_Struct_Member(TObjectDef(DefOwner),HashedID.ID);
              if Assigned(HSym) and
                 (
                  (
                   not(m_delphi in CurrentSettings.ModeSwitches) and
                   Is_Visible_For_Object(HSym,TObjectDef(DefOwner))
                  ) or
                  (
                   { In Delphi, you can repeat members of a parent class. You can't }
                   { do this for objects however, and you (obviously) can't         }
                   { declare two fields with the same name in a single class        }
                   (m_delphi in CurrentSettings.ModeSwitches) and
                   (
                    Is_Object(TDef(DefOwner)) or
                    (HSym.Owner = Self)
                   )
                  )
                 ) then
                begin
                  { only warn when a parameter/local variable in a method
                    conflicts with a category method, because this can easily
                    happen due to all possible categories being imported via
                    CocoaAll }
                  Warn:=
                    (Is_ObjCCategory(TDef(HSym.Owner.DefOwner)) or
                     Is_ClassHelper(TDef(HSym.Owner.DefOwner))) and
                    (Sym.Typ in [ParaVarSym,LocalVarSym,FieldVarSym]);
                  DuplicateSym(HashedID,Sym,HSym,Warn);
                  Result:=True;
                end;
           end
         else
           Result:=inherited CheckDuplicate(HashedID,Sym);
      end;




{****************************************************************************
                          TAbstractSubSymtable
****************************************************************************}

   procedure TAbstractSubSymTable.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldTyp : Byte;
      begin
         OldTyp:=PPUFile.EntryTyp;
         PPUFile.EntryTyp:=SubEntryID;

         inherited PPUWrite(PPUFile);

         PPUFile.EntryTyp:=OldTyp;
      end;


{****************************************************************************
                          TAbstractLocalSymtable
****************************************************************************}

    function TAbstractLocalSymTable.Count_Locals:LongInt;
      var
        I   : LongInt;
        Sym : TSym;
      begin
        Result:=0;
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TSym(SymList[I]);
            { Count only varsyms, but ignore the funcretsym }
            if (TSym(Sym).Typ in [LocalVarSym,ParaVarSym]) and
               (TSym(Sym)<>CurrentProcInfo.ProcDef.FuncRetSym) and
               (not(vo_is_parentfp in TAbstractVarSym(Sym).VarOptions) or
                (TStoredSym(Sym).Refs>0)) then
              Inc(Result);
         end;
      end;

    function TAbstractLocalSymTable.IsCurrentUnit: Boolean;
      begin
        Result:=
          Assigned(DefOwner) and
          DefOwner.Owner.IsCurrentUnit;
      end;


{****************************************************************************
                              TLocalSymtable
****************************************************************************}

    constructor TLocalSymTable.Create(ADefOwner:TDef;Level:Byte);
      begin
        inherited Create('');
        DefOwner:=ADefOwner;
        SymTableType:=LocalSymTable;
        SymTableLevel:=Level;
      end;


    function TLocalSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      var
        HSym : TSym;
      begin
        if not Assigned(DefOwner) or
           (DefOwner.Typ<>ProcDef) then
          InternalError(200602042);

        Result:=False;
        HSym:=TSym(FindWithHash(HashedID));
        if Assigned(HSym) then
          begin
            { a local and the function can have the same
              name in TP and Delphi, but RESULT not }
            if (m_duplicate_names in CurrentSettings.ModeSwitches) and
               (HSym.Typ in [AbsoluteVarSym,LocalVarSym]) and
               (vo_is_funcret in TAbstractVarSym(HSym).VarOptions) and
               not((m_result in CurrentSettings.ModeSwitches) and
                   (vo_is_result in TAbstractVarSym(HSym).VarOptions)) then
              HideSym(HSym)
            else
              DuplicateSym(HashedID,Sym,HSym,False);
            Result:=True;
            Exit;
          end;

        { check also parasymtable, this needs to be done here because
          of the special situation with the funcret sym that needs to be
          hidden for tp and delphi modes }
        HSym:=TSym(TAbstractProcDef(DefOwner).ParaST.FindWithHash(HashedID));
        if Assigned(HSym) then
          begin
            { a local and the function can have the same
              name in TP and Delphi, but RESULT not }
            if (m_duplicate_names in CurrentSettings.ModeSwitches) and
               (Sym.Typ in [AbsoluteVarSym,LocalVarSym]) and
               (vo_is_funcret in TAbstractVarSym(Sym).VarOptions) and
               not((m_result in CurrentSettings.ModeSwitches) and
                   (vo_is_result in TAbstractVarSym(Sym).VarOptions)) then
              HideSym(Sym)
            else
              DuplicateSym(HashedID,Sym,HSym,False);
            Result:=True;
            Exit;
          end;

        { check ObjectSymtable, skip this for funcret sym because
          that will always be positive because it has the same name
          as the procsym }
        if not Is_FuncRet_Sym(Sym) and
           (DefOwner.Typ=ProcDef) and
           Assigned(TProcDef(DefOwner).Struct) and
           (TProcDef(DefOwner).Owner.DefOwner=TProcDef(DefOwner).Struct) and
           (
            not(m_duplicate_names in CurrentSettings.ModeSwitches) or
            Is_Object(TProcDef(DefOwner).Struct)
           ) then
          Result:=TProcDef(DefOwner).Struct.SymTable.CheckDuplicate(HashedID,Sym);
      end;


{****************************************************************************
                              TParaSymtable
****************************************************************************}

    constructor TParaSymTable.Create(ADefOwner:TDef;Level:Byte);
      begin
        inherited Create('');
        DefOwner:=ADefOwner;
        SymTableType:=ParaSymTable;
        SymTableLevel:=Level;
      end;


    function TParaSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      begin
        Result:=inherited CheckDuplicate(HashedID,Sym);
        if Result then
          Exit;
        if not(m_duplicate_names in CurrentSettings.ModeSwitches) and
           Assigned(DefOwner) and (DefOwner.Typ=ProcDef) and
           Assigned(TProcDef(DefOwner).Struct) and
           Assigned(TProcDef(DefOwner).Owner) and
           (TProcDef(DefOwner).Owner.DefOwner=TProcDef(DefOwner).Struct) and
           (
            not(m_delphi in CurrentSettings.ModeSwitches) or
            Is_Object(TProcDef(DefOwner).Struct)
           ) then
          Result:=TProcDef(DefOwner).Struct.SymTable.CheckDuplicate(HashedID,Sym);
      end;


{****************************************************************************
                         TAbstractUniTSymtable
****************************************************************************}

    constructor TAbstractUnitSymTable.Create(const N : string;ID:Word);
      begin
        inherited Create(N);
        ModuleID:=ID;
      end;


    function TAbstractUnitSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      var
        HSym : TSym;
      begin
        Result:=False;
        HSym:=TSym(FindWithHash(HashedID));
        if Assigned(HSym) then
          begin
            if (Sym is TStoredSym) and Handle_Generic_DummySym(HSym,TStoredSym(Sym).SymOptions) then
              Exit;
            if HSym.Typ=SymConst.NamespaceSym then
              begin
                case Sym.Typ of
                  SymConst.NamespaceSym:;
                  SymConst.UnitSym:
                    begin
                      HideSym(Sym); { if we add a unit and there is a namespace with the same name then hide the unit name and not the namespace }
                      TNamespaceSym(HSym).UnitSym:=TSym(Sym);
                    end
                else
                  HideSym(HSym);
                end;
              end
            else
            { In delphi (contrary to TP) you can have a symbol with the same name as the
              unit, the unit can then not be accessed anymore using
              <unit>.<id>, so we can hide the symbol.
              Do the same if we add a namespace and there is a unit with the same name }
            if (HSym.Typ=SymConst.UnitSym) and
               ((m_delphi in CurrentSettings.ModeSwitches) or (Sym.Typ=SymConst.NamespaceSym)) then
              begin
                HideSym(HSym);
                if Sym.Typ=SymConst.NamespaceSym then
                  TNamespaceSym(Sym).UnitSym:=TSym(HSym);
              end
            { iso mode program parameters: staticvarsyms might have the same name as a program parameters,
              in this case, copy the isoindex and make the original symbol invisible }
            else if (m_isolike_program_para in CurrentSettings.ModeSwitches) and (HSym.Typ=ProgramParaSym) and (Sym.Typ=StaticVarSym)
              and (TProgramParaSym(HSym).IsoIndex<>0) then
              begin
                HideSym(HSym);
                TStaticVarSym(Sym).IsoIndex:=TProgramParaSym(HSym).IsoIndex;
              end
            else if (m_iso in CurrentSettings.ModeSwitches) and (HSym.Typ=UnitSym) then
              HideSym(HSym)
            else
              DuplicateSym(HashedID,Sym,HSym,False);
            Result:=True;
            Exit;
          end;
      end;

    function TAbstractUnitSymTable.FindNamespace(const N:string):TSymEntry;
      begin
        Result:=Find(N);
        if Assigned(Result)and(Result.Typ<>NamespaceSym)then
          Result:=nil;
      end;

    function TAbstractUnitSymTable.IsCurrentUnit:Boolean;
      begin
        Result:=Assigned(CurrentModule) and
                (
                 (CurrentModule.GlobalSymTable=Self) or
                 (CurrentModule.LocalSymTable=Self)
                );
      end;


    function TAbstractUnitSymTable.Needs_Init_Final: Boolean;
      begin
        if not FInitFinalCheckDone then
          begin
            Result:=inherited Needs_Init_Final;
            if not Result then
              begin
                Result:=Has_Class_ConDestructors;
                if Result then
                  Include(TableOptions,sto_needs_init_final);
              end;
          end;
        Result:=sto_needs_init_final in TableOptions;
      end;


    procedure TAbstractUnitSymTable.InsertUnit(Sym:TSymEntry);
      var
        P:Integer;
        N,NS:string;
        OldSym:TSymEntry;
      begin
        InsertSym(Sym);
        N:=Sym.RealName;
        P:=Pos('.',N);
        NS:='';
        while P>0 do
          begin
            if NS='' then
              NS:=Copy(N,1,P-1)
            else
              NS:=NS+'.'+Copy(N,1,P-1);
            System.Delete(N,1,P);
            OldSym:=FindNamespace(Upper(NS));
            if not Assigned(OldSym) then
              InsertSym(CNamespaceSym.Create(NS));
            P:=Pos('.',N);
          end;
      end;


    procedure CheckForClassConDestructors(P:TObject;Arg:Pointer);
      var
        Result: PBoolean absolute Arg;
      begin
        if Result^ then
          Exit;
        if (TDef(P).Typ in [ObjectDef,RecordDef]) and
           not (df_generic in TDef(P).DefOptions) then
          begin
            { first check the class... }
            if ([oo_has_class_constructor,oo_has_class_destructor] * TAbstractRecordDef(P).ObjectOptions <> []) then
              Result^:=True;
            { ... and then also check all subclasses }
            if not Result^ then
              TAbstractRecordDef(P).SymTable.DefList.ForEachCall(@CheckForClassConDestructors,Arg);
          end;
      end;


    function TAbstractUnitSymTable.Has_Class_ConDestructors: Boolean;
      begin
        Result:=False;
        DefList.ForEachCall(@CheckForClassConDestructors,@Result);
      end;

{****************************************************************************
                              TStaticSymtable
****************************************************************************}

    constructor TStaticSymTable.Create(const N : string;ID:Word);
      begin
        inherited Create(N,ID);
        SymTableType:=StaticSymTable;
        SymTableLevel:=MainProgramLevel;
        CurrentVisibility:=vis_private;
      end;


    procedure TStaticSymTable.PPULoad(PPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(PPUFile);

        { now we can deref the syms and defs }
        Deref(False);
      end;


    procedure TStaticSymTable.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(PPUFile);
      end;


    function TStaticSymTable.CheckDuplicate(var HashedID:THashedIDString;Sym:TSymEntry):Boolean;
      begin
        Result:=inherited CheckDuplicate(HashedID,Sym);

        if not Result and
           (CurrentModule.LocalSymTable=Self) and
           Assigned(CurrentModule.GlobalSymTable) then
          Result:=TGlobalSymTable(CurrentModule.GlobalSymTable).CheckDuplicate(HashedID,Sym);
      end;

    function TStaticSymTable.FindNamespace(const N:string):TSymEntry;
      begin
        Result:=inherited FindNamespace(N);
        if not Assigned(Result) and
           (CurrentModule.LocalSymTable=Self) and
           Assigned(CurrentModule.GlobalSymTable) then
          Result:=TGlobalSymTable(CurrentModule.GlobalSymTable).FindNamespace(N);
     end;


{****************************************************************************
                              TGlobalSymtable
****************************************************************************}

    constructor TGlobalSymTable.Create(const N : string;ID:Word);
      begin
         inherited Create(N,ID);
         SymTableType:=GlobalSymTable;
         SymTableLevel:=MainProgramLevel;
      end;


    procedure TGlobalSymTable.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(PPUFile);

         { now we can deref the syms and defs }
         Deref(False);
      end;


    procedure TGlobalSymTable.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
        { write the symtable entries }
        inherited PPUWrite(PPUFile);
      end;


{*****************************************************************************
                             tspecializesymtable
*****************************************************************************}

    constructor TSpecializeSymTable.Create(const N : string;ID:Word);
      begin
        inherited Create(N,ID);
        { the specialize symtable does not own the syms and defs as they are all
          moved to a different symtable before the symtable is destroyed; this
          avoids calls to "extract" }
        SymList.OwnsObjects:=False;
        DefList.OwnsObjects:=False;
      end;

    function TSpecializeSymTable.IsCurrentUnit: Boolean;
      begin
        Result:=True;
      end;


{****************************************************************************
                              TWITHSYMTABLE
****************************************************************************}

    constructor TWithSymTable.Create(AOwner:TDef;ASymList:TFPHashObjectList;RefNode:TObject{tnode});
      begin
         inherited Create('');
         SymTableType:=WithSymTable;
         WithRefNode:=RefNode;
         { Replace SymList with the passed symlist }
         SymList.Free;
         SymList:=ASymList;
         DefOwner:=AOwner;
      end;


    destructor TWithSymTable.Destroy;
      begin
        if RefCount>1 then
          Exit;
        WithRefNode.Free;
        WithRefNode := nil;
        { Disable SymList because we don't Own it }
        SymList:=nil;
        inherited Destroy;
      end;


    procedure TWithSymTable.Clear;
      begin
         { remove no entry from a withsymtable as it is only a pointer to the
           recorddef  or objectdef symtable }
      end;


    procedure TWithSymTable.InsertDef(Def:TDefEntry);
      begin
        { Definitions can't be registered in the withsymtable
          because the withsymtable is removed after the with block.
          We can't easily solve it here because the next symtable in the
          stack is not known. }
        InternalError(200602046);
      end;

{****************************************************************************
                          TSTT_ExceptionSymtable
****************************************************************************}

    constructor TSTTExceptSymTable.Create;
      begin
        inherited Create('');
        SymTableType:=ExceptSymTable;
      end;


{****************************************************************************
                          TMacroSymtable
****************************************************************************}

    constructor TMacroSymTable.Create(Exported: Boolean);
      begin
        inherited Create('');
        if Exported then
          SymTableType:=ExportedMacroSymTable
        else
          SymTableType:=LocalMacroSymTable;
        SymTableLevel:=MainProgramLevel;
      end;

{****************************************************************************
                          TEnumSymtable
****************************************************************************}

    procedure TEnumSymTable.InsertSym(Sym: TSymEntry; CheckDup: Boolean);
      var
        Value: LongInt;
        Def: TEnumDef;
      begin
        // defowner = nil only when we are loading from ppu
        if DefOwner<>nil then
          begin
            { First entry? Then we need to set the minval }
            Value:=TEnumSym(Sym).Value;
            Def:=TEnumDef(DefOwner);
            if SymList.Count=0 then
              begin
                if Value>0 then
                  Def.HasJumps:=True;
                Def.SetMin(Value);
                Def.SetMax(Value);
              end
            else
              begin
                { check for jumps }
                if Value>Def.Max+1 then
                  Def.HasJumps:=True;
                { update low and high }
                if Def.Min>Value then
                  Def.SetMin(Value);
                if Def.Max<Value then
                  Def.SetMax(Value);
              end;
          end;
        inherited InsertSym(Sym, CheckDup);
      end;

    constructor TEnumSymTable.Create(ADefOwner: TDef);
      begin
        inherited Create('');
        SymTableType:=EnumSymTable;
        DefOwner:=ADefOwner;
      end;

{****************************************************************************
                          TArraySymtable
****************************************************************************}

    procedure TArraySymTable.InsertDef(Def: TDefEntry);
      begin
        { Enums must also be available outside the record scope,
          insert in the owner of this symtable }
        if Def.Typ=EnumDef then
          DefOwner.Owner.InsertDef(Def)
        else
          inherited InsertDef(Def);
      end;

    constructor TArraySymTable.Create(ADefOwner: TDef);
      begin
        inherited Create('');
        SymTableType:=ArraySymTable;
        DefOwner:=ADefOwner;
      end;

{*****************************************************************************
                             Helper Routines
*****************************************************************************}

    function FullTypeName(Def,OtherDef:TDef):string;
      var
        S1,S2 : string;
      begin
        if Def.Typ in [ObjectDef,RecordDef] then
          S1:=TAbstractRecordDef(Def).RTTIName
        else
          S1:=Def.TypeName;
        { When the names are the same try to include the unit name }
        if Assigned(OtherDef) and
           (Def.Owner.SymTableType in [GlobalSymTable,StaticSymTable]) then
          begin
            S2:=OtherDef.TypeName;
            if Upper(S1)=Upper(S2) then
              S1:=Def.Owner.RealName^+'.'+S1;
          end;
        FullTypeName:=S1;
      end;

    function Generate_Nested_Name(SymTable:TSymTable;const Delimiter:string):string;
      begin
        Result:='';
        while Assigned(SymTable) and (SymTable.SymTableType in [ObjectSymTable,RecordSymTable]) do
          begin
            if (Result='') then
              if SymTable.Name<>nil then
                Result:=SymTable.Name^
              else
            else
              if SymTable.Name<>nil then
                Result:=SymTable.Name^+Delimiter+Result
              else
                Result:=Delimiter+Result;
            SymTable:=SymTable.DefOwner.Owner;
          end;
      end;


    function Generate_ObjectPascal_Helper_Key(Def:TDef):TSymStr;
      begin
        if not Assigned(Def) then
          InternalError(2013020501);
        if Def.Typ in [RecordDef,ObjectDef] then
          Result:=Make_MangledName('',TAbstractRecordDef(Def).SymTable,'')
        else
          Result:=Make_MangledName('',Def.Owner,Def.TypeSym.Name);
      end;


    procedure IncompatibleTypes(Def1,Def2:TDef);
      begin
        { When there is an errordef there is already an error message show }
        if (Def2.Typ=ErrorDef) or
           (Def1.Typ=ErrorDef) then
          Exit;
        CGMessage2(type_e_incompatible_types,FullTypeName(Def1,Def2),FullTypeName(Def2,Def1));
      end;


    procedure HideSym(Sym:TSymEntry);
      begin
        Sym.RealName:='$hidden'+Sym.RealName;
        TSym(Sym).Visibility:=vis_hidden;
      end;


    procedure DuplicateSym(var HashedID: THashedIDString; DupSym, OrigSym: TSymEntry; Warn: Boolean);
      var
        ST : TSymTable;
        FileName : TIDString;
      begin
        if not Warn then
          Message1(sym_e_duplicate_id,TSym(OrigSym).RealName)
        else
         Message1(sym_w_duplicate_id,TSym(OrigSym).RealName);
        { Write hint where the original symbol was found }
        ST:=FindUnitSymTable(OrigSym.Owner);
        with TSym(OrigSym).FileInfo do
          begin
            if Assigned(ST) and
               (ST.SymTableType=GlobalSymTable) and
               ST.IsCurrentUnit then
              Message2(sym_h_duplicate_id_where,CurrentModule.SourceFiles.Get_File_Name(FileIndex),ToStr(Line))
            else if Assigned(ST.Name) then
              begin
                FileName:=Find_Module_From_SymTable(ST).SourceFiles.Get_File_Name(FileIndex);
                if FileName<>'' then
                  Message2(sym_h_duplicate_id_where,'unit '+ST.Name^+': '+FileName,ToStr(Line))
                else
                  Message2(sym_h_duplicate_id_where,'unit '+ST.Name^,ToStr(Line))
              end;
          end;
        { Rename duplicate sym to an unreachable name, but it can be
          inserted in the symtable without errors }
        Inc(DupNr);
        HashedID.ID:='dup'+ToStr(DupNr)+HashedID.ID;
        if Assigned(DupSym) then
          Include(TSym(DupSym).SymOptions,sp_implicitrename);
      end;

    function Handle_Generic_DummySym(Sym:TSymEntry;var SymOptions:TSymOptions):Boolean;
      begin
        Result:=False;
        if not Assigned(Sym) or not (Sym is TStoredSym) then
          InternalError(2011081101);
        { For generics a dummy symbol without the parameter count is created
          if such a symbol not yet exists so that different parts of the
          parser can find that symbol. If that symbol is still a
          undefineddef we replace the generic dummy symbol's
          name with a "dup" name and use the new symbol as the generic dummy
          symbol }
        if (sp_generic_dummy in TStoredSym(Sym).SymOptions) and
            (Sym.Typ=TypeSym) and (TTypeSym(Sym).TypeDef.Typ=UndefinedDef) and
            (m_delphi in CurrentSettings.ModeSwitches) then
          begin
            Inc(DupNr);
            Sym.Owner.SymList.Rename(Upper(Sym.RealName),'dup_'+ToStr(DupNr)+Sym.RealName);
            Include(TSym(Sym).SymOptions,sp_implicitrename);
            { we need to find the new symbol now if checking for a dummy }
            Include(SymOptions,sp_generic_dummy);
            Result:=True;
          end;
      end;

    procedure CheckSystemUnitLoaded; inline;
    begin
      if SystemUnit=nil then
       Message(sym_f_systemunitnotloaded);
    end;

    procedure Write_System_Parameter_Lists(const Name:string);
      var
        SRSym:TProcSym;
      begin
        CheckSystemUnitLoaded;
        SRSym:=TProcSym(SystemUnit.Find(Name));
        if not Assigned(SRSym) or not (SRSym.Typ=ProcSym) then
          InternalError(2016060302);
        SRSym.Write_Parameter_Lists(nil);
      end;


{*****************************************************************************
                                  Search
*****************************************************************************}

     procedure AddSymRef(Sym:TSym;Def:TDef);
       var
         Owner,ProcOwner : TSymTable;
       begin
         { for symbols used in preprocessor expressions, we don't want to
           increase references count (for smaller final binaries) }
         if not Assigned(CurrentScanner) then
           InternalError(2017050601);
         if CurrentScanner.in_preproc_comp_expr then
           Exit;
         { symbol uses count }
         Sym.IncRefCount;
         Owner:=Sym.Owner;
         while Owner.SymTableType in [ObjectSymTable,RecordSymTable,EnumSymTable] do
           Owner:=TDef(Owner.DefOwner).Owner;
         if Assigned(CurrentModule) and
            (Owner.SymTableType=GlobalSymTable) then
             begin
               if TGlobalSymTable(Owner).ModuleID>=CurrentModule.UnitMapSize then
                 InternalError(200501152);
               { unit uses count }
               Inc(CurrentModule.UnitMap[TGlobalSymTable(Owner).ModuleID].Refs);
               { Note: don't check the symtable directly as owner might be
                       a specialize symtable which is a globalsymtable as well }
               if (
                     Assigned(CurrentModule.GlobalSymTable) and
                     (CurrentModule.GlobalSymTable.ModuleID<>Owner.ModuleID)
                  ) or (
                     Assigned(CurrentModule.LocalSymTable) and
                     (CurrentModule.LocalSymTable.ModuleID<>Owner.ModuleID)
                  ) then
                 { symbol is imported from another unit }
                 CurrentModule.AddImportedSym(Sym);
             end;
         { static symbols that are used in public functions must be exported
           for packages as well }
         { A private overload can share its procsym with public overloads.
           Use the selected definition's implementation owner in that case. }
         if (Sym.Typ=ProcSym) and Assigned(Def) and
            (Def.Typ=ProcDef) and (Def.Owner.SymTableType=StaticSymTable) then
           Owner:=Def.Owner;
         if ([tf_supports_packages,tf_supports_hidden_symbols]<=TargetInfo.Flags) and
             (Owner.SymTableType=StaticSymTable) and
             Assigned(CurrentProcInfo) and
             (
               (
                 (Sym.Typ=StaticVarSym) and
                 ([vo_is_public,vo_has_global_ref]*TStaticVarSym(Sym).VarOptions=[])
               ) or (
                 (Sym.Typ=LocalVarSym) and
                 Assigned(TLocalVarSym(Sym).DefaultConstSym) and
                 ([vo_is_public,vo_has_global_ref]*TStaticVarSym(TLocalVarSym(Sym).DefaultConstSym).VarOptions=[])
               ) or (
                 (Sym.Typ=ProcSym) and
                 Assigned(Def) and
                 (Def.Typ=ProcDef) and
                 not (df_has_global_ref in Def.DefOptions) and
                 not (po_public in TProcDef(Def).ProcOptions)
               )
             ) then
           begin
             ProcOwner:=CurrentProcInfo.ProcDef.Owner;
             while ProcOwner.SymTableType in [ObjectSymTable,RecordSymTable] do
               ProcOwner:=TDef(ProcOwner.DefOwner).Owner;
             if ProcOwner.SymTableType=GlobalSymTable then
               begin
                 if Sym.Typ=ProcSym then
                   CurrentProcInfo.Add_Local_Ref_Def(Def)
                 else if Sym.Typ=StaticVarSym then
                   CurrentProcInfo.Add_Local_Ref_Sym(Sym)
                 else
                   CurrentProcInfo.Add_Local_Ref_Sym(TLocalVarSym(Sym).DefaultConstSym);
               end;
           end;
       end;

     procedure AddSymRef(Sym:TSym);
       begin
         AddSymRef(Sym,nil);
       end;

    function Is_Owned_By(NestedDef,OwnerDef:TDef):Boolean;
      begin
        Result:=NestedDef=OwnerDef;
        if not Result and
           { types declared locally in a record method are not defined in the
             record itself }
           not(NestedDef.Owner.SymTableType in [LocalSymTable,ParaSymTable]) and
           Assigned(NestedDef.Owner.DefOwner) then
          Result:=Is_Owned_By(TDef(NestedDef.Owner.DefOwner),OwnerDef);
      end;

    function Sym_Is_Owned_By(ChildSym:TSym;SymTable:TSymTable):Boolean;
      begin
        Result:=Assigned(ChildSym) and (ChildSym.Owner=SymTable);
        if not Result and Assigned(ChildSym) and
            (ChildSym.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
          Result:=Sym_Is_Owned_By(TAbstractRecordDef(ChildSym.Owner.DefOwner).TypeSym,SymTable);
      end;

    function Defs_Belong_To_Same_Generic(Def1, Def2: TDef): Boolean;
    begin
      Result:=False;
      if not Assigned(Def1) or not Assigned(Def2) then
        Exit;
      { for both defs walk to the topmost generic }
      while Assigned(Def1.Owner.DefOwner) and (df_generic in TStoredDef(Def1.Owner.DefOwner).DefOptions) do
        Def1:=TDef(Def1.Owner.DefOwner);
      while Assigned(Def2.Owner.DefOwner) and (df_generic in TStoredDef(Def2.Owner.DefOwner).DefOptions) do
        Def2:=TDef(Def2.Owner.DefOwner);
      Result:=Def1=Def2;
    end;

    function Get_Generic_In_Hierarchy_By_Name(SRSym: TSym; Def: TDef): TDef;
      var
        UName : string;
      begin
        { TODO : check regarding arrays and records declared as their type }
        if not (Def.Typ in [RecordDef,ObjectDef]) then
          InternalError(2012051501);
        UName:=Upper(SRSym.RealName);
        repeat
          if UName=Copy(TAbstractRecordDef(Def).ObjName^,1,Pos('$',TAbstractRecordDef(Def).ObjName^)-1) then
            begin
              Result:=Def;
              Exit;
            end;
          Def:=TDef(Def.Owner.DefOwner);
        until not Assigned(Def) or not (Def.Typ in [RecordDef,ObjectDef]);
        Result:=nil;
      end;

    function Return_Specialization_Of_Generic(NestedDef,GenericDef:TDef; out ResultDef:TDef):Boolean;
      begin
        { TODO : check regarding arrays and records declared as their type }
        if not (NestedDef.Typ in [RecordDef,ObjectDef]) then
          InternalError(2012051601);
        repeat
          if TStoredDef(NestedDef).GenericDef=GenericDef then
            begin
              ResultDef:=NestedDef;
              Result:=True;
              Exit;
            end;
          NestedDef:=TDef(NestedDef.Owner.DefOwner);
        until not Assigned(NestedDef) or not (NestedDef.Typ in [RecordDef,ObjectDef]);
        ResultDef:=nil;
        Result:=False;
      end;

    { symst: symboltable that contains the symbol (-> symowner def: record/objectdef in which the symbol is defined)
      symvisibility: visibility of the symbol
      contextobjdef: via which def the symbol is accessed, e.g.:
        fieldname:=1 -> contextobjdef = current_structdef
        objfield.fieldname:=1 -> contextobjdef = def of objfield
    }
    function Is_Visible_For_Object(SymST:TSymTable;SymVisibility:TVisibility;ContextObjDef:TAbstractRecordDef):Boolean;
      var
        CurStruct : TAbstractRecordDef;

      function IsCurrentUnitForContext(ST:TSymTable):Boolean;
        begin
          Result :=
            (
              (
                Assigned(CurStruct) and
                (ST.ModuleID=CurStruct.SymTable.ModuleID)
              ) or
              (
                not Assigned(CurStruct) and
                ST.IsCurrentUnit
              )
            );
        end;

      var
        OrgContextObjDef,
        OrgSymOwnerDef,
        SymOwnerDef : TAbstractRecordDef;
        NonLocalST : TSymTable;
        IsSpezProc : Boolean;

      function CheckStrictPrivate:Boolean;
        begin
          Result:=Assigned(CurStruct) and
                  Is_Owned_By(CurStruct,SymOwnerDef);
        end;

      function CheckStrictProtected:Boolean;
        function IsChildOf(Child, PotentialParent: TDef):Boolean;
          begin
            Result:=True;
            if Def_Is_Related(Child, PotentialParent) then
              Exit;
            if (Child.Typ=ObjectDef) and
               (PotentialParent.Typ=ObjectDef) and
               (TObjectDef(PotentialParent).DefOptions*[df_generic,df_specialization]=[df_generic]) then
              begin
                 repeat
                   if TObjectDef(Child).GenericDef<>nil then
                     begin
                       if TObjectDef(Child).GenericDef.Typ<>ObjectDef then
                         Break;
                       Child:=TObjectDef(Child).GenericDef as TObjectDef
                     end
                   else
                     Child:=TObjectDef(Child).ChildOf;
                   if (Child<>nil) and Equal_Defs(Child, PotentialParent) then
                     Exit;
                 until Child=nil;
              end;

            Result:=False;
          end;

        function OwnerHierarchyRelated(Nested,Check:TAbstractRecordDef):Boolean;
          var
            Owner:TAbstractRecordDef;
          begin
            Result:=True;
            repeat
              if IsChildOf(Nested,Check) then
                Exit;
              if Nested.Owner.SymTableType in [RecordSymTable,ObjectSymTable] then
                Nested:=TAbstractRecordDef(Nested.Owner.DefOwner)
              else
                Break;
            until not Assigned(Nested);
            Result:=False;
          end;

        begin
          Result:=(
                    { access from nested class (specialization case) }
                    Assigned(CurStruct) and
                    Is_Owned_By(CurStruct,SymOwnerDef)
                  ) or
                  (
                    { access from nested class (non-specialization case) }
                    (OrgSymOwnerDef<>SymOwnerDef) and
                    Assigned(CurStruct) and
                    Is_Owned_By(CurStruct,OrgSymOwnerDef)
                  ) or
                  (
                    { access from child class (specialization case) }
                    Assigned(ContextObjDef) and
                    Assigned(CurStruct) and
                    OwnerHierarchyRelated(ContextObjDef,SymOwnerDef) and
                    IsChildOf(CurStruct,ContextObjDef)
                  ) or
                  (
                    { access from child class (non-specialization case) }
                    Assigned(OrgContextObjDef) and
                    (
                      (OrgContextObjDef<>ContextObjDef) or
                      (OrgSymOwnerDef<>SymOwnerDef)
                    ) and
                    Assigned(CurStruct) and
                    OwnerHierarchyRelated(OrgContextObjDef,OrgSymOwnerDef) and
                    IsChildOf(CurStruct,OrgContextObjDef)
                  ) or
                  (
                    { helpers can access strict protected symbols }
                    Is_ObjectPascal_Helper(ContextObjDef) and
                    IsChildOf(TObjectDef(ContextObjDef).ExtendedDef,SymOwnerDef)
                  ) or
                  (
                    { same as above, but from context of call node inside
                      helper method }
                    Is_ObjectPascal_Helper(CurStruct) and
                    IsChildOf(TObjectDef(CurStruct).ExtendedDef,SymOwnerDef)
                  );
        end;

      begin
        Result:=False;

        { Get objdectdef owner of the symtable for the is_related checks }
        if not Assigned(SymST) or
           not (SymST.SymTableType in [ObjectSymTable,RecordSymTable]) then
          InternalError(200810285);
        SymOwnerDef:=TAbstractRecordDef(SymST.DefOwner);
        OrgSymOwnerDef:=SymOwnerDef;
        OrgContextObjDef:=ContextObjDef;
        { for specializations we need to check the visibility of the generic,
          not the specialization (at least when comparing outside of the
          specialization }
        if df_specialization in SymOwnerDef.DefOptions then
          begin
            if not Assigned(SymOwnerDef.GenericDef) then
              InternalError(2024041201);
            if not (SymOwnerDef.GenericDef.Typ in [ObjectDef,RecordDef]) then
              InternalError(2024020901);
            OrgSymOwnerDef:=SymOwnerDef;
            SymOwnerDef:=TAbstractRecordDef(SymOwnerDef.GenericDef);
          end;
        if Assigned(ContextObjDef) and (df_specialization in ContextObjDef.DefOptions) then
          begin
            if not Assigned(ContextObjDef.GenericDef) then
              InternalError(2024041202);
            if not (ContextObjDef.GenericDef.Typ in [ObjectDef,RecordDef]) then
              InternalError(2024020902);
            OrgContextObjDef:=ContextObjDef;
            ContextObjDef:=TAbstractRecordDef(ContextObjDef.GenericDef);
          end;
        if Assigned(CurrentStructDef) and (df_specialization in CurrentStructDef.DefOptions) then
          begin
            if not Assigned(CurrentStructDef.GenericDef) then
              InternalError(2024041203);
            if not (CurrentStructDef.GenericDef.Typ in [ObjectDef,RecordDef]) then
              InternalError(2024030903);
            CurStruct:=TAbstractRecordDef(CurrentStructDef.GenericDef)
          end
        else
          CurStruct:=CurrentStructDef;
        { specializations might belong to a localsymtable or parasymtable }
        NonLocalST:=SymOwnerDef.Owner;
        if TStoredDef(SymOwnerDef).Is_Specialization then
          while NonLocalST.SymTableType in [LocalSymTable,ParaSymTable] do
            NonLocalST:=NonLocalST.DefOwner.Owner;
        IsSpezProc:=False;
        if Assigned(CurrentProcInfo) then
          begin
            if CurrentProcInfo.ProcDef.Is_Specialization and
                Assigned(CurrentProcInfo.ProcDef.Struct) then
              IsSpezProc:=True;
          end;
        case SymVisibility of
          vis_private :
            begin
              { private symbols are allowed when we are in the same
                module as they are defined }
              Result:=CheckStrictPrivate or
                      (
                       (NonLocalST.SymTableType in [GlobalSymTable,StaticSymTable]) and
                       IsCurrentUnitForContext(NonLocalST)
                      ) or
                      ( // the case of specialize inside the generic declaration and nested types
                       (NonLocalST.SymTableType in [ObjectSymTable,RecordSymTable]) and
                       (
                         Assigned(CurStruct) and
                         (
                           (CurStruct=SymOwnerDef) or
                           (CurStruct.Owner.ModuleID=SymOwnerDef.SymTable.ModuleID)
                         )
                       ) or
                       (
                         not Assigned(CurStruct) and
                         (SymOwnerDef.Owner.IsCurrentUnit)
                       ) or
                       { access from a generic method that belongs to the class
                         but that is specialized elsewhere }
                       (
                         IsSpezProc and
                         (CurrentProcInfo.ProcDef.Struct=CurStruct)
                       ) or
                       { specializations may access private symbols that their
                         generics are allowed to access }
                       (
                         Assigned(CurStruct) and
                         (df_specialization in CurStruct.DefOptions) and
                         (SymST.ModuleID=CurStruct.GenericDef.Owner.ModuleID)
                       )
                      );
            end;
          vis_strictprivate :
            begin
              Result:=CheckStrictPrivate;
            end;
          vis_strictprotected :
            begin
              Result:=CheckStrictProtected;
            end;
          vis_protected :
            begin
              { protected symbols are visible in the module that defines them and
                also visible to related objects. The related object must be defined
                in the current module }
              Result:=CheckStrictProtected or
                      (
                       (
                        (NonLocalST.SymTableType in [GlobalSymTable,StaticSymTable]) and
                        IsCurrentUnitForContext(NonLocalST)
                       ) or
                       (
                        { context object is inside the current unit and related to
                          the symbol owner (specialization case) }
                        Assigned(ContextObjDef) and
                        (ContextObjDef.Owner.SymTableType in [GlobalSymTable,StaticSymTable,ObjectSymTable,RecordSymTable,LocalSymTable]) and
                        IsCurrentUnitForContext(ContextObjDef.Owner) and
                        Def_Is_Related(ContextObjDef,SymOwnerDef)
                       ) or
                       (
                        { context object is inside the current unit and related to
                          the symbol owner (non-specialization case) }
                        Assigned(OrgContextObjDef) and
                        (
                          (OrgContextObjDef<>ContextObjDef) or
                          (OrgSymOwnerDef<>SymOwnerDef)
                        ) and
                        (OrgContextObjDef.Owner.SymTableType in [GlobalSymTable,StaticSymTable,ObjectSymTable,RecordSymTable,LocalSymTable]) and
                        IsCurrentUnitForContext(OrgContextObjDef.Owner) and
                        Def_Is_Related(OrgContextObjDef,OrgSymOwnerDef)
                       ) or
                       ( // the case of specialize inside the generic declaration and nested types
                        (NonLocalST.SymTableType in [ObjectSymTable,RecordSymTable]) and
                        (
                          Assigned(CurStruct) and
                          (
                            (CurStruct=SymOwnerDef) or
                            (CurStruct.Owner.ModuleID=SymOwnerDef.SymTable.ModuleID)
                          )
                        ) or
                        (
                          not Assigned(CurStruct) and
                          (SymOwnerDef.Owner.IsCurrentUnit)
                        )
                       ) or
                       { access from a generic method that belongs to the class
                         but that is specialized elsewhere }
                       (
                         IsSpezProc and
                         (CurrentProcInfo.ProcDef.Struct=CurStruct)
                       ) or
                       { specializations may access private symbols that their
                         generics are allowed to access }
                       (
                         Assigned(CurStruct) and
                         (df_specialization in CurStruct.DefOptions) and
                         (SymST.ModuleID=CurStruct.GenericDef.Owner.ModuleID)
                       )
                      );
            end;
          vis_public,
          vis_published :
            Result:=True;
          else
            InternalError(2019050702);
        end;

        if not Result then
          begin
            { capturers have access to anything as we assume checks were done
              before the procdef was inserted into the capturer }
            Result:=Assigned(CurStruct) and
                    (CurStruct.Typ=ObjectDef) and
                    (oo_is_capturer in TObjectDef(CurStruct).ObjectOptions);
          end;
      end;


    function Is_Visible_For_Object(PD:TProcDef;ContextObjDef:TAbstractRecordDef):Boolean;
      begin
        Result:=Is_Visible_For_Object(PD.Owner,PD.Visibility,ContextObjDef);
      end;


    function Is_Visible_For_Object(Sym:TSym;ContextObjDef:TAbstractRecordDef):Boolean;
      var
        I  : LongInt;
        PD : TProcDef;
      begin
        if Sym.Typ=ProcSym then
          begin
            Result:=False;
            { A procsym is visible, when there is at least one of the procdefs visible }
            for I:=0 to TProcSym(Sym).ProcDefList.Count-1 do
              begin
                PD:=TProcDef(TProcSym(Sym).ProcDefList[I]);
                if (PD.Owner=Sym.Owner) and
                   Is_Visible_For_Object(PD,ContextObjDef) then
                  begin
                    Result:=True;
                    Exit;
                  end;
              end;
            { check dummy sym visibility by following associated procsyms }
            if TProcSym(Sym).Could_Be_Implicitly_Specialized then
              begin
                for I:=0 to TProcSym(Sym).GenProcSymOvlds.Count-1 do
                  if Is_Visible_For_Object(TSym(TProcSym(Sym).GenProcSymOvlds[I]),ContextObjDef) then
                    begin
                      Result:=True;
                      Exit;
                    end;
              end;
            if (TProcSym(Sym).ProcDefList.Count=0) and (sp_generic_dummy in TProcSym(Sym).SymOptions) then
              Result:=Is_Visible_For_Object(Sym.Owner,Sym.Visibility,ContextObjDef);
          end
        else
          Result:=Is_Visible_For_Object(Sym.Owner,Sym.Visibility,ContextObjDef);
      end;


    function  SearchSym(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      begin
        case S[1] of
          internal_macro_escape_unit_namespace_name:
            Result:=SearchSym_Maybe_With_SymOption(Copy(S,2,Length(S)-1),SRSym,SRSymTable,[ssf_unit_or_namespace_only],sp_none)
          else
            Result:=SearchSym_Maybe_With_SymOption(S,SRSym,SRSymTable,[],sp_none);
        end
      end;


    function  SearchSym_With_Flags(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
      begin
        Result:=SearchSym_Maybe_With_SymOption(S,SRSym,SRSymTable,Flags,sp_none);
      end;


    function  SearchSym_Maybe_With_SymOption(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags;Option:TSymOption):Boolean;
      var
        HashedID: THashedIDString;
        ContextStructDef: TAbstractRecordDef;
        StackItem: PSymTableStackItem;
      begin
        Result:=False;
        HashedID.ID:=S;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            SRSymTable:=StackItem^.SymTable;
            if not(ssf_unit_or_namespace_only in Flags) and
               (SRSymTable.SymTableType=ObjectSymTable) then
              begin
                { TODO : implement the search for an option in classes as well }
                if ssf_search_option in Flags then
                  begin
                    Result:=False;
                    Exit;
                  end;
                if SearchSym_In_Class(TObjectDef(SRSymTable.DefOwner),TObjectDef(SRSymTable.DefOwner),S,SRSym,SRSymTable,Flags+[ssf_search_helper]) then
                  begin
                    Result:=True;
                    Exit;
                  end;
              end
            else if not((SRSymTable.SymTableType=WithSymTable) and Assigned(SRSymTable.DefOwner) and
              (SRSymTable.DefOwner.Typ=UndefinedDef)) then
              begin
                SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
                { First check if it is a unit/namespace symbol.
                  They are visible only if they are from the current unit or
                  unit of generic of currently processed specialization. }
                if Assigned(SRSym) and
                   (not(ssf_unit_or_namespace_only in Flags) or
                    (SRSym.Typ in [UnitSym,NamespaceSym])) and
                   (
                     not(SRSym.Typ in [UnitSym,NamespaceSym]) or
                     SRSymTable.IsCurrentUnit or
                     (Assigned(CurrentSpecializeDef)and(CurrentSpecializeDef.GenericDef.Owner.ModuleID=SRSymTable.ModuleID)) or
                     (
                       Assigned(CurrentProcInfo) and
                       (df_specialization in CurrentProcInfo.ProcDef.DefOptions) and
                       (CurrentProcInfo.ProcDef.GenericDef.Owner.ModuleID=SRSymTable.ModuleID)
                     )
                   ) and
                   (not (ssf_search_option in Flags) or (Option in SRSym.SymOptions))then
                  begin
                    { use the class from withsymtable only when it is
                      defined in this unit }
                    if (SRSymTable.SymTableType=WithSymTable) and
                       Assigned(SRSymTable.DefOwner) and
                       (SRSymTable.DefOwner.Typ in [RecordDef,ObjectDef]) and
                       (SRSymTable.DefOwner.Owner.SymTableType in [GlobalSymTable,StaticSymTable,ObjectSymTable,RecordSymTable]) and
                       (SRSymTable.DefOwner.Owner.IsCurrentUnit) then
                      ContextStructDef:=TAbstractRecordDef(SRSymTable.DefOwner)
                    else
                      ContextStructDef:=CurrentStructDef;
                    if not(SRSym.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) or
                       Is_Visible_For_Object(SRSym,ContextStructDef) then
                      begin
                        { we need to know if a procedure references symbols
                          in the static symtable, because then it can't be
                          inlined from outside this unit }
                        if Assigned(CurrentProcInfo) and
                           (SRSym.Owner.SymTableType=StaticSymTable) then
                          Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
                        if not (ssf_no_addsymref in Flags) then
                          AddSymRef(SRSym);
                        Result:=True;
                        Exit;
                      end;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        SRSym:=nil;
        SRSymTable:=nil;
      end;

    function SearchSym_With_SymOption(const S: TIDString;out SRSym:TSym;out
      SRSymTable:TSymTable;Option:TSymOption):Boolean;
      begin
        Result:=SearchSym_Maybe_With_SymOption(S,SRSym,SRSymTable,[ssf_search_option],Option);
      end;

    function SearchSym_Type(const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      var
        HashedID  : THashedIDString;
        StackItem : PSymTableStackItem;
        ClassH : TObjectDef;
      begin
        Result:=False;
        HashedID.ID:=S;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            {
              It is not possible to have type symbols in:
                parameters
              Exception are classes, objects, records, generic definitions and specializations
              that have the parameterized types inserted in the symtable.
            }
            SRSymTable:=StackItem^.SymTable;
            if (SRSymTable.SymTableType=ObjectSymTable) then
              begin
                ClassH:=TObjectDef(SRSymTable.DefOwner);
                while Assigned(ClassH) do
                  begin
                    SRSymTable:=ClassH.SymTable;
                    SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
                     if Assigned(SRSym) and
                        not(SRSym.Typ in [FieldVarSym,ParaVarSym,PropertySym,ProcSym,LabelSym]) and
                        Is_Visible_For_Object(SRSym,CurrentStructDef) then
                       begin
                        AddSymRef(SRSym);
                        Result:=True;
                        Exit;
                      end;
                    ClassH:=ClassH.ChildOf;
                  end;
              end
            else
              begin
                SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
                if Assigned(SRSym) and
                   (
                     not(SRSym.Typ in [UnitSym,NamespaceSym]) or
                     SRSymTable.IsCurrentUnit or
                     (Assigned(CurrentSpecializeDef)and(CurrentSpecializeDef.GenericDef.Owner.ModuleID=SRSymTable.ModuleID))
                   ) and
                   not(SRSym.Typ in [FieldVarSym,ParaVarSym,PropertySym,ProcSym,LabelSym]) and
                   (not (SRSym.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) or Is_Visible_For_Object(SRSym,CurrentStructDef)) then
                  begin
                    { we need to know if a procedure references symbols
                      in the static symtable, because then it can't be
                      inlined from outside this unit }
                    if Assigned(CurrentProcInfo) and
                       (SRSym.Owner.SymTableType=StaticSymTable) then
                      Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
                    AddSymRef(SRSym);
                    Result:=True;
                    Exit;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        Result:=False;
        SRSym:=nil;
        SRSymTable:=nil;
      end;


    function SearchSym_In_Module(PM:Pointer;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      var
        PMod : TModule;
      begin
        Result:=False;
        if not Assigned(PM) then Exit;
        PMod:=TModule(PM);
        if Assigned(PMod.GlobalSymTable) then
          begin
            SRSym:=TSym(PMod.GlobalSymTable.Find(S));
            if Assigned(SRSym) then
              begin
                SRSymTable:=PMod.GlobalSymTable;
                AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
          end;
        { If the module is the current unit we also need
          to search the local symtable }
        if (PMod=CurrentModule) and
           Assigned(PMod.LocalSymTable) then
          begin
            SRSym:=TSym(PMod.LocalSymTable.Find(S));
            if Assigned(SRSym) then
              begin
                SRSymTable:=PMod.LocalSymTable;
                AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
          end;
        SRSym:=nil;
        SRSymTable:=nil;
      end;


    function SearchSym_In_Named_Module(const UnitName, SymName: TIDString; out SRSym: TSym; out SRSymTable: TSymTable): Boolean;
      var
        StackItem  : PSymTableStackItem;
      begin
        Result:=False;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            SRSymTable:=StackItem^.SymTable;
            if (SRSymTable.SymTableType=GlobalSymTable) and
               (SRSymTable.Name^=UnitName) then
              begin
                SRSym:=TSym(SRSymTable.Find(SymName));
                if not Assigned(SRSym) then
                  Break;
                Result:=True;
                Exit;
              end;
            StackItem:=StackItem^.Next;
          end;

        { If the module is the current unit we also need
          to search the local symtable }
        if Assigned(CurrentModule.LocalSymTable) and
           (CurrentModule.LocalSymTable.Name^=UnitName) then
          begin
            SRSymTable:=CurrentModule.LocalSymTable;
            SRSym:=TSym(SRSymTable.Find(SymName));
            if Assigned(SRSym) then
              begin
                Result:=True;
                Exit;
              end;
          end;
      end;


    function Maybe_Find_Real_Class_Definition(PD: TDef; ErrorOnFailure: Boolean): TDef;
      begin
        Result:=PD;
        if PD.Typ<>ObjectDef then
          Exit;
        Result:=Find_Real_Class_Definition(TObjectDef(PD),ErrorOnFailure);
      end;


    function Find_Real_Class_Definition(PD: TObjectDef; ErrorOnFailure: Boolean): TObjectDef;
      var
        HashedID   : THashedIDString;
        StackItem  : PSymTableStackItem;
        SRSymTable : TSymTable;
        SRSym      : TSym;
        FormalName,
        FoundName : ShortString;
        FormalNamePtr,
        FoundNamePtr: PShortString;
      begin
        while PD.Is_Unique_ObjPasDef do
          begin
            PD:=PD.ChildOf;
          end;
        { not a formal definition -> return it }
        if not(oo_is_formal in PD.ObjectOptions) then
          begin
            Result:=PD;
            Exit;
          end;
        HashedID.ID:=PD.TypeSym.Name;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            SRSymTable:=StackItem^.SymTable;

            if not(SRSymTable.SymTableType in [RecordSymTable,ParaSymTable]) then
              begin
                SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
                if Assigned(SRSym) and
                   (SRSym.Typ=TypeSym) and
                   (TTypeSym(SRSym).TypeDef.Typ=ObjectDef) and
                   (TObjectDef(TTypeSym(SRSym).TypeDef).ObjectType=PD.ObjectType) and
                   not(oo_is_formal in TObjectDef(TTypeSym(SRSym).TypeDef).ObjectOptions) then
                  begin
                    if not(oo_is_forward in TObjectDef(TTypeSym(SRSym).TypeDef).ObjectOptions) then
                      begin
                        { the external name for the formal and the real
                          definition must match }
                        if Assigned(TObjectDef(TTypeSym(SRSym).TypeDef).ImportLib) or
                           Assigned(PD.ImportLib) then
                          begin
                            if Assigned(PD.ImportLib) then
                              FormalName:=PD.ImportLib^+'.'
                            else
                              FormalName:='';
                            FormalName:=FormalName+PD.ObjExtName^;
                            if Assigned(TObjectDef(TTypeSym(SRSym).TypeDef).ImportLib) then
                              FoundName:=TObjectDef(TTypeSym(SRSym).TypeDef).ImportLib^+'.'
                            else
                              FoundName:='';
                            FoundName:=FoundName+TObjectDef(TTypeSym(SRSym).TypeDef).ObjExtName^;

                            FormalNamePtr:=@FormalName;
                            FoundNamePtr:=@FoundName;
                          end
                        else
                          begin
                            FormalNamePtr:=PD.ObjExtName;
                            FoundNamePtr:=TObjectDef(TTypeSym(SRSym).TypeDef).ObjExtName;
                          end;
                        if FoundNamePtr^<>FormalNamePtr^ then
                          begin
                            MessagePos2(PD.TypeSym.FileInfo,sym_e_external_class_name_mismatch1,FormalNamePtr^,PD.TypeName);
                            MessagePos1(SRSym.FileInfo,sym_e_external_class_name_mismatch2,FoundNamePtr^);
                          end;
                      end;
                    Result:=TObjectDef(TTypeSym(SRSym).TypeDef);
                    if Assigned(CurrentProcInfo) and
                       (SRSym.Owner.SymTableType=StaticSymTable) then
                      Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
                    AddSymRef(SRSym);
                    Exit;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        { nothing found: optionally give an error and return the original
          (empty) one }
        if ErrorOnFailure then
          Message1(sym_e_formal_class_not_resolved,PD.ObjRealName^);
        Result:=PD;
      end;


    function SearchSym_In_Class(ClassH: TObjectDef;ContextClassH:TAbstractRecordDef;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
      var
        HashedID : THashedIDString;
        OrgClass : TObjectDef;
        I        : LongInt;
      begin
        OrgClass:=ClassH;
        { in case this is a formal class, first find the real definition }
        if Assigned(ClassH) then
          begin
            if (oo_is_formal in ClassH.ObjectOptions) then
              ClassH:=Find_Real_Class_Definition(ClassH,True);
            { The contextclassh is used for visibility. The classh must be equal to
              or be a parent of contextclassh. E.g. for inherited searches the classh is the
              parent or a class helper. }
            if not (Def_Is_Related(ContextClassH,ClassH) or
                (Is_ClassHelper(ContextClassH) and
                 Assigned(TObjectDef(ContextClassH).ExtendedDef) and
                (TObjectDef(ContextClassH).ExtendedDef.Typ=ObjectDef) and
                Def_Is_Related(TObjectDef(ContextClassH).ExtendedDef,ClassH))) then
              InternalError(200811161);
          end;
        Result:=False;
        HashedID.ID:=S;

        if Is_ObjCProtocol(ClassH) then
          begin
            SRSymTable:=ClassH.SymTable;
            SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) and
               Is_Visible_For_Object(SRSym,ContextClassH) then
              begin
                if not (ssf_no_addsymref in Flags) then
                  AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
            for I:=0 to ClassH.ImplementedInterfaces.Count-1 do
              begin
                if SearchSym_In_Class(TImplementedInterface(ClassH.ImplementedInterfaces[I]).IntfDef,ContextClassH,S,SRSym,SRSymTable,Flags-[ssf_search_helper]) then
                  begin
                    Result:=True;
                    Exit;
                  end;
              end;
          end
        else
        if Is_ObjectPascal_Helper(ClassH) then
          begin
            { helpers have their own obscure search logic... }
            Result:=SearchSym_In_Helper(ClassH,TObjectDef(ContextClassH),S,SRSym,SRSymTable,Flags-[ssf_has_inherited]);
            if Result then
              Exit;
          end
        else
          begin
            while Assigned(ClassH) do
              begin
                { search for a class helper method first if this is an Object
                  Pascal class and we haven't yet found a helper symbol }
                if (ClassH.ObjectType in ObjectTypesWithHelpers) and
                    (ssf_search_helper in Flags) then
                  begin
                    Result:=Search_ObjectPascal_Helper(ClassH,ContextClassH,S,SRSym,SRSymTable);
                    { an eventual overload inside the extended type's hierarchy
                      will be found by tcallcandidates }
                    if Result then
                      Exit;
                  end;
                SRSymTable:=ClassH.SymTable;
                SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
                if Assigned(SRSym) and
                   Is_Visible_For_Object(SRSym,ContextClassH) then
                  begin
                    if not (ssf_no_addsymref in Flags) then
                      AddSymRef(SRSym);
                    Result:=True;
                    Exit;
                  end;
                ClassH:=ClassH.ChildOf;
              end;
          end;
        if Is_ObjCClass(OrgClass) then
          Result:=Search_ObjC_Helper(OrgClass,S,SRSym,SRSymTable)
        else
          begin
            SRSym:=nil;
            SRSymTable:=nil;
          end;
      end;

    function  SearchSym_In_Record(RecordH:TAbstractRecordDef;const S : TIDString;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      var
        HashedID : THashedIDString;
      begin
        Result:=False;
        HashedID.ID:=S;
        { search for a record helper method first }
        Result:=Search_ObjectPascal_Helper(RecordH,RecordH,S,SRSym,SRSymTable);
        if Result then
          { an eventual overload inside the extended type's hierarchy
            will be found by tcallcandidates }
          Exit;
        SRSymTable:=RecordH.SymTable;
        SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
        if Assigned(SRSym) and Is_Visible_For_Object(SRSym,RecordH) then
          begin
            AddSymRef(SRSym);
            Result:=True;
            Exit;
          end;
        SRSym:=nil;
        SRSymTable:=nil;
      end;

    function SearchSym_In_Class_By_MsgInt(ClassH:TObjectDef;MsgID:LongInt;out SRDef : TDef;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      var
        Def : TDef;
        I   : LongInt;
      begin
        { in case this is a formal class, first find the real definition }
        if Assigned(ClassH) and
           (oo_is_formal in ClassH.ObjectOptions) then
          ClassH:=Find_Real_Class_Definition(ClassH,True);
        Result:=False;
        Def:=nil;
        while Assigned(ClassH) do
          begin
            for I:=0 to ClassH.SymTable.DefList.Count-1 do
              begin
                Def:=TStoredDef(ClassH.SymTable.DefList[I]);
                { Find also all hidden private methods to
                  be compatible with delphi, see tw6203 (PFV) }
                if (Def.Typ=ProcDef) and
                   (po_msgint in TProcDef(Def).ProcOptions) and
                   (TProcDef(Def).MessageInf.I=MsgID) then
                  begin
                    SRDef:=Def;
                    SRSym:=TProcDef(Def).ProcSym;
                    SRSymTable:=ClassH.SymTable;
                    AddSymRef(SRSym);
                    Result:=True;
                    Exit;
                  end;
              end;
            ClassH:=ClassH.ChildOf;
          end;
        SRDef:=nil;
        SRSym:=nil;
        SRSymTable:=nil;
      end;


    function SearchSym_In_Class_By_MsgStr(ClassH:TObjectDef;const S:string;out SRSym:TSym;out SRSymTable:TSymTable):Boolean;
      var
        Def : TDef;
        I   : LongInt;
      begin
        { in case this is a formal class, first find the real definition }
        if Assigned(ClassH) and
           (oo_is_formal in ClassH.ObjectOptions) then
          ClassH:=Find_Real_Class_Definition(ClassH,True);
        Result:=False;
        Def:=nil;
        while Assigned(ClassH) do
          begin
            for I:=0 to ClassH.SymTable.DefList.Count-1 do
              begin
                Def:=TStoredDef(ClassH.SymTable.DefList[I]);
                { Find also all hidden private methods to
                  be compatible with delphi, see tw6203 (PFV) }
                if (Def.Typ=ProcDef) and
                   (po_msgstr in TProcDef(Def).ProcOptions) and
                   (TProcDef(Def).MessageInf.Str^=S) then
                  begin
                    SRSym:=TProcDef(Def).ProcSym;
                    SRSymTable:=ClassH.SymTable;
                    AddSymRef(SRSym);
                    Result:=True;
                    Exit;
                  end;
              end;
            ClassH:=ClassH.ChildOf;
          end;
        SRSym:=nil;
        SRSymTable:=nil;
      end;

    function SearchBestObjectPascalHelper(const Name: string;PD : TDef;ContextClassH : TAbstractRecordDef;out SRSym: TSym;out SRSymTable: TSymTable):Boolean;forward;

    function SearchSym_In_Helper(ClassH,ContextClassH:TObjectDef;const S: TIDString;out SRSym:TSym;out SRSymTable:TSymTable;Flags:TSymbolSearchFlags):Boolean;
      var
        HashedID      : THashedIDString;
        ParentClassH  : TObjectDef;
      begin
        Result:=False;
        if not Is_ObjectPascal_Helper(ClassH) then
          InternalError(2011030101);
        HashedID.ID:=S;
        { in a helper things are a bit more complex:
          1. search the symbol in the helper (if not "inherited")
          2. search the symbol in the extended type
          3. search the symbol in the parent helpers
          4. only classes: search the symbol in the parents of the extended type
        }
        if not (ssf_has_inherited in Flags) then
          begin
            { search in the helper itself }
            SRSymTable:=ClassH.SymTable;
            SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) and
               Is_Visible_For_Object(SRSym,ContextClassH) then
              begin
                if not (ssf_no_addsymref in Flags) then
                  AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
          end;
        { now search in the extended type itself }
        { Note: the extendeddef might be Nil if we are currently parsing the
                extended type itself and the identifier was not found }
        if Assigned(ClassH.ExtendedDef) and (ClassH.ExtendedDef.Typ in [RecordDef,ObjectDef]) then
          begin
            SRSymTable:=TAbstractRecordDef(ClassH.ExtendedDef).SymTable;
            SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) and
               Is_Visible_For_Object(SRSym,ContextClassH) then
              begin
                if not (ssf_no_addsymref in Flags) then
                  AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
          end;
        { now search in the parent helpers }
        ParentClassH:=ClassH.ChildOf;
        while Assigned(ParentClassH) do
          begin
            SRSymTable:=ParentClassH.SymTable;
            SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) and
               Is_Visible_For_Object(SRSym,ContextClassH) then
              begin
                if not (ssf_no_addsymref in Flags) then
                  AddSymRef(SRSym);
                Result:=True;
                Exit;
              end;
            ParentClassH:=ParentClassH.ChildOf;
          end;
        { now search in the parents of the extended class (with helpers!) }
        if Is_Class(ClassH.ExtendedDef) then
          begin
            Result:=SearchSym_In_Class(TObjectDef(ClassH.ExtendedDef).ChildOf,ContextClassH,S,SRSym,SRSymTable,Flags+[ssf_search_helper]);
            { addsymref is already called by searchsym_in_class }
            if Result then
              Exit;
          end;
        { now search all helpers using the extendeddef as the starting point }
        if (m_multi_helpers in CurrentSettings.ModeSwitches) and
            (
              (CurrentStructDef<>ClassH) or
              Assigned(ClassH.ExtendedDef)
            ) then
          begin
            { this is only allowed if classh is currently parsed }
            if not Assigned(ClassH.ExtendedDef) then
              InternalError(2019110101);
            Result:=SearchBestObjectPascalHelper(S,ClassH.ExtendedDef,ContextClassH,SRSym,SRSymTable);
          end;
      end;

    function SearchSpecificAssignmentOperator(AssignmentType:TToken;FromDef,ToDef:TDef):TProcDef;
      var
        Sym : TProcSym;
        HashedID : THashedIDString;
        CurReq,
        BestEq : TEqualType;
        CurrPD,
        BestPD : TProcDef;
        StackItem : PSymTableStackItem;
        ShortStringCount : LongInt;
        IsExplicit,
        CheckShortString : Boolean;
      begin
        HashedID.ID:=Overloaded_Names[AssignmentType];
        BestEq:=te_incompatible;
        BestPD:=nil;
        StackItem:=SymTableStack.Stack;
        { special handling for assignments to shortstrings with a specific length:
          - if we get an operator to ShortString we use that
          - if we get only a single String[x] operator we use that
          - otherwise it's a nogo }
        IsExplicit:=AssignmentType=_OP_EXPLICIT;
        ShortStringCount:=0;
        CheckShortString:=not IsExplicit and Is_ShortString(ToDef) and (TStringDef(ToDef).Len<>255);
        while Assigned(StackItem) do
          begin
            Sym:=TProcSym(StackItem^.SymTable.FindWithHash(HashedID));
            if Sym<>nil then
              begin
                if Sym.Typ<>ProcSym then
                  InternalError(200402031);
                { if the source type is an alias then this is only the second choice,
                  if you mess with this code, check tw4093 }
                CurrPD:=Sym.Find_ProcDef_Assignment_Operator(FromDef,ToDef,CurReq,IsExplicit);
                { we found a ShortString overload, use that and be done }
                if CheckShortString and
                    Assigned(CurrPD) and
                    Is_ShortString(CurrPD.ReturnDef) and
                    (TStringDef(CurrPD.ReturnDef).Len=255) then
                  begin
                    BestEq:=CurReq;
                    BestPD:=CurrPD;
                    Break;
                  end;
                { independently of the operator being better count if we encountered
                  multiple String[x] operators }
                if CheckShortString and Assigned(CurrPD) and Is_ShortString(CurrPD.ReturnDef) then
                  Inc(ShortStringCount);
                if CurReq>BestEq then
                  begin
                    BestEq:=CurReq;
                    BestPD:=CurrPD;
                    { don't stop searching if we have a String[x] operator cause
                      we might find a ShortString one or multiple ones (which
                      leads to no operator use) }
                    if (BestEq=te_exact) and not CheckShortString then
                      Break;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        if CheckShortString and (ShortStringCount>1) then
          BestPD:=nil;
        Result:=BestPD;
      end;


    function Search_Assignment_Operator(FromDef,ToDef:TDef;Explicit:Boolean):TProcDef;
      begin
        { search record/object symtable first for a suitable operator }
        if FromDef.Typ in [RecordDef,ObjectDef] then
          SymTableStack.Push(TAbstractRecordDef(FromDef).SymTable);
        if ToDef.Typ in [RecordDef,ObjectDef] then
          SymTableStack.Push(TAbstractRecordDef(ToDef).SymTable);

        { if type conversion is explicit then search first for explicit
          operator overload and if not found then use implicit operator }
        if Explicit then
          Result:=SearchSpecificAssignmentOperator(_OP_EXPLICIT,FromDef,ToDef)
        else
          Result:=nil;
        if Result=nil then
          Result:=SearchSpecificAssignmentOperator(_ASSIGNMENT,FromDef,ToDef);

        { if we're assigning to a typed pointer, but we did not find a suitable assignment
          operator then we also check for a untyped pointer assignment operator }
        if not Assigned(Result) and Is_Pointer(ToDef) and not Is_VoidPointer(ToDef) then
          begin
            if Explicit then
              Result:=SearchSpecificAssignmentOperator(_OP_EXPLICIT,FromDef,VoidPointerType);
            if not Assigned(Result) then
              Result:=SearchSpecificAssignmentOperator(_ASSIGNMENT,FromDef,VoidPointerType);
          end;

        { restore symtable stack }
        if ToDef.Typ in [RecordDef,ObjectDef] then
          SymTableStack.Pop(TAbstractRecordDef(ToDef).SymTable);
        if FromDef.Typ in [RecordDef,ObjectDef] then
          SymTableStack.Pop(TAbstractRecordDef(FromDef).SymTable);
      end;


    function Search_Enumerator_Operator(FromDef,ToDef:TDef): TProcDef;
      var
        Sym : TProcSym;
        HashedID : THashedIDString;
        CurReq,
        BestEq : TEqualType;
        CurrPD,
        BestPD : TProcDef;
        StackItem : PSymTableStackItem;
      begin
        HashedID.ID:='enumerator';
        BestEq:=te_incompatible;
        BestPD:=nil;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            Sym:=TProcSym(StackItem^.SymTable.FindWithHash(HashedID));
            if Sym<>nil then
              begin
                if Sym.Typ<>ProcSym then
                  InternalError(200910241);
                { if the source type is an alias then this is only the second choice,
                  if you mess with this code, check tw4093 }
                CurrPD:=Sym.Find_ProcDef_Enumerator_Operator(FromDef,ToDef,CurReq);
                if CurReq>BestEq then
                  begin
                    BestEq:=CurReq;
                    BestPD:=CurrPD;
                    if (BestEq=te_exact) then
                      Break;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        Result:=BestPD;
    end;


    function Search_Management_Operator(MOP:TManagementOperator;PD:TDef):TProcDef;
      var
        Sym : TProcSym;
        HashedID : THashedIDString;
        OpToken: TToken;
      begin
        OpToken := ManagementOperator2Tok[MOP];
        if (OpToken<first_managment_operator) or
           (OpToken>last_managment_operator) then
          InternalError(201602280);
        HashedID.ID:=Overloaded_Names[OpToken];
        if not (PD.Typ in [RecordDef]) then
          InternalError(201602281);
        Sym:=TProcSym(TAbstractRecordDef(PD).SymTable.FindWithHash(HashedID));
        if Sym<>nil then
          begin
            if Sym.Typ<>ProcSym then
              InternalError(201602282);
            Result:=Sym.Find_ProcDef_ByType(potype_operator);
          end
        else
          Result:=nil;
      end;


    function Search_System_Type(const S: TIDString): TTypeSym;
      var
        Sym : TSym;
      begin
        CheckSystemUnitLoaded;
        Sym:=TSym(SystemUnit.Find(S));
        if not Assigned(Sym) or
           (Sym.Typ<>TypeSym) then
          Message1(cg_f_unknown_system_type,S);
        Result:=TTypeSym(Sym);
      end;


    function Try_Search_System_Type(const S: TIDString): TTypeSym;
      var
        Sym : TSym;
      begin
        CheckSystemUnitLoaded;
        Sym:=TSym(SystemUnit.Find(S));
        if not Assigned(Sym) then
          Result:=nil
        else
          begin
            if Sym.Typ<>TypeSym then
              Message1(cg_f_unknown_system_type,S);
            Result:=TTypeSym(Sym);
          end;
      end;


    function Try_Search_Current_Module_Type(const S: TIDString): TTypeSym;
      var
        Found: Boolean;
        SRSymTable: TSymTable;
        SRSym: TSym;
      begin
        Found:=SearchSym_In_Module(CurrentModule,TSymTable.Maybe_Adjust_SymName(S),SRSym,SRSymTable);
        if Found then
          begin
            if (SRSym.Typ<>TypeSym) then
              InternalError(2014091207);
            Result:=TTypeSym(SRSym);
          end
        else
          Result:=nil;
      end;


    function  Search_System_Proc(const S: TIDString): TProcDef;
      var
        SRSym: TSym;
      begin
        CheckSystemUnitLoaded;
        SRSym:=TSym(SystemUnit.Find(S));
        if not Assigned(SRSym) and
           (cs_compilesystem in CurrentSettings.ModuleSwitches) then
          SRSym:=TSym(SystemUnit.Find(Upper(S)));
        if not Assigned(SRSym) or
           (SRSym.Typ<>ProcSym) then
          Message1(cg_f_unknown_compilerproc,S);
        Result:=TProcDef(TProcSym(SRSym).ProcDefList[0]);
    end;


    function Search_Named_Unit_GlobalType(const UnitName, TypeName: TIDString; ThrowError: Boolean): TTypeSym;
      var
        SRSymTable: TSymTable;
        Sym: TSym;
      begin
        Sym:=nil;
        if SearchSym_In_Named_Module(UnitName,TypeName,Sym,SRSymTable) and
           (Sym.Typ=TypeSym) then
          begin
            Result:=TTypeSym(Sym);
            Exit;
          end
        else
          begin
            if ThrowError then
              Message2(cg_f_unknown_type_in_unit,TypeName,UnitName);
            Result:=nil;
          end;
      end;

    function SearchSymInHelperDef(const S: string;ClassH : TObjectDef;ContextClassH : TAbstractRecordDef;out SRSym: TSym;out SRSymTable: TSymTable): Boolean;
      var
        HashedID : THashedIDString;
        PDef : TProcDef;
        I : Integer;
      begin
        HashedID.ID:=S;
        Result:=False;
        repeat
          SRSymTable:=ClassH.SymTable;
          SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
          if SRSym<>nil then
            begin
              case SRSym.Typ of
                ProcSym:
                  begin
                    for I:=0 to TProcSym(SRSym).ProcDefList.Count-1 do
                      begin
                        PDef:=TProcDef(TProcSym(SRSym).ProcDefList[I]);
                        if not Is_Visible_For_Object(PDef.Owner,PDef.Visibility,ContextClassH) then
                          Continue;
                        SRSym:=TProcDef(TProcSym(SRSym).ProcDefList[I]).ProcSym;
                        SRSymTable:=SRSym.Owner;
                        Result:=True;
                        Exit;
                      end;
                    if (sp_generic_dummy in TProcSym(SRSym).SymOptions) and
                        (TProcSym(SRSym).ProcDefList.Count=0) and
                        Is_Visible_For_Object(SRSym.Owner,SRSym.Visibility,ContextClassH) then
                      begin
                        SRSymTable:=SRSym.Owner;
                        Result:=True;
                        Exit;
                      end;
                  end;
                TypeSym,
                FieldVarSym,
                ConstSym,
                EnumSym,
                UndefinedSym,
                PropertySym:
                  begin
                    Result:=True;
                    Exit;
                  end;
                else
                  InternalError(2014041101);
              end;
            end;

          { try the helper parent if available }
          ClassH:=ClassH.ChildOf;
        until ClassH=nil;
      end;

    function Get_ObjectPascal_Helpers(PD : TDef):TFPObjectList;
      var
        S : TSymStr;
        ST : TSymTable;
      begin
        Result:=nil;
        { when there are no helpers active currently then we don't need to do
          anything }
        if CurrentModule.ExtendedDefs.Count=0 then
          Exit;
        if (df_genconstraint in PD.DefOptions) then
          begin
            { if we have a constraint for a class type or a single interface we
              use that to resolve helpers at declaration time of the generic,
              otherwise there can't be any helpers as the type isn't known yet }
            if PD.Typ=ObjectDef then
              PD:=TObjectDef(PD).GetParentDef
            else
              Exit;
          end;
        { no helpers for anonymous types }
        if ((PD.Typ in [RecordDef,ObjectDef]) and
            (
              not Assigned(TAbstractRecordDef(PD).ObjRealName) or
              (TAbstractRecordDef(PD).ObjRealName^='')
            )
           ) or
           not Assigned(PD.TypeSym) then
          Exit;
        { if pd is defined inside a procedure we must not use make_mangledname
          (as a helper may not be defined in a procedure this is no problem...)}
        ST:=PD.Owner;
        while ST.SymTableType in [ObjectSymTable,RecordSymTable] do
          ST:=ST.DefOwner.Owner;
        if ST.SymTableType=LocalSymTable then
          Exit;
        { the mangled name is used as the key for tmodule.extendeddefs }
        S:=Generate_ObjectPascal_Helper_Key(PD);
        Result:=TFPObjectList(CurrentModule.ExtendedDefs.Find(S));
      end;

    function SearchBestObjectPascalHelper(const Name: string;PD : TDef;ContextClassH : TAbstractRecordDef;out SRSym: TSym;out SRSymTable: TSymTable):Boolean;
      var
        List : TFPObjectList;
        I : Integer;
        ODef : TObjectDef;
      begin
        Result:=False;
        List:=Get_ObjectPascal_Helpers(PD);
        if Assigned(List) and (List.Count>0) then
          begin
            I:=List.Count-1;
            repeat
              ODef:=TObjectDef(List[I]);
              Result:=(ODef.Owner.SymTableType in [StaticSymTable,GlobalSymTable]) or
                      Is_Visible_For_Object(TObjectDef(List[I]).TypeSym,ContextClassH);
              if Result then
                Result:=SearchSymInHelperDef(Name,ODef,ContextClassH,SRSym,SRSymTable);
              Dec(I);
            until Result or (I<0);
          end;
      end;

    function Search_Last_ObjectPascal_Helper(PD : TDef;ContextClassH : TAbstractRecordDef;out ODef : TObjectDef):Boolean;
      var
        List : TFPObjectList;
        I : Integer;
      begin
        Result:=False;
        ODef:=nil;
        List:=Get_ObjectPascal_Helpers(PD);
        if Assigned(List) and (List.Count>0) then
          begin
            I:=List.Count-1;
            repeat
              ODef:=TObjectDef(List[List.Count-1]);
              Result:=(ODef.Owner.SymTableType in [StaticSymTable,GlobalSymTable]) or
                      Is_Visible_For_Object(TObjectDef(List[I]).TypeSym,ContextClassH);
              Dec(I);
            until Result or (I<0);
            if not Result then
              { just to be sure that none uses odef }
              ODef:=nil;
          end;
      end;

    function Search_ObjectPascal_Helper(PD : TDef;ContextClassH : TAbstractRecordDef;const S: string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
      var
        ClassH : TObjectDef;
      begin
        Result:=False;

        { if there is no class helper for the class then there is no need to
          search further }
        if m_multi_helpers in CurrentSettings.ModeSwitches then
          Result:=SearchBestObjectPascalHelper(S,PD,ContextClassH,SRSym,SRSymTable)
        else
          begin
            if Search_Last_ObjectPascal_Helper(PD,ContextClassH,ClassH) and
               SearchSymInHelperDef(S,ClassH,ContextClassH,SRSym,SRSymTable) then
                Result:=True;
          end;

        if Result then
          begin
            { we need to know if a procedure references symbols
              in the static symtable, because then it can't be
              inlined from outside this unit }
            if (SRSym.Typ=ProcSym) and
               Assigned(CurrentProcInfo) and
               (SRSym.Owner.SymTableType=StaticSymTable) then
              Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
            AddSymRef(SRSym);
          end
        else
          begin
            SRSym:=nil;
            SRSymTable:=nil;
          end;
      end;

    function Search_ObjC_Helper(PD : TObjectDef;const S : string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
      var
        SearchST   : TSymTable;
        SearchSym  : TSym;
        HashedID   : THashedIDString;
        StackItem  : PSymTableStackItem;
        I          : LongInt;
        FoundDefOwner,
        DefOwner   : TObjectDef;
      begin
        HashedID.ID:=ClassHelperPrefix+S;
        StackItem:=SymTableStack.Stack;
        Result:=False;
        SRSym:=nil;
        SRSymTable:=nil;
        FoundDefOwner:=nil;
        while Assigned(StackItem) do
          begin
            SearchST:=StackItem^.SymTable;
            SearchSym:=TSym(SearchST.FindWithHash(HashedID));
            if Assigned(SearchSym) then
              begin
                if not(SearchST.SymTableType in [GlobalSymTable,StaticSymTable]) or
                   not(SearchSym.Owner.SymTableType in [GlobalSymTable,StaticSymTable]) or
                   (SearchSym.Typ<>ProcSym) then
                  InternalError(2009111505);
                { check whether this procsym includes a helper for this particular class }
                for I:=0 to TProcSym(SearchSym).ProcDefList.Count-1 do
                  begin
                    { does pd inherit from (or is the same as) the class
                      that this method's category extended?

                      Warning: this list contains both category and objcclass methods
                       (for id.randommethod), so only check category methods here
                    }
                    DefOwner:=TObjectDef(TProcDef(TProcSym(SearchSym).ProcDefList[I]).Owner.DefOwner);
                    if Is_ObjCCategory(DefOwner) and
                       Def_Is_Related(PD,DefOwner.ChildOf) then
                      begin
                        { we need to know if a procedure references symbols
                          in the static symtable, because then it can't be
                          inlined from outside this unit }
                        if Assigned(CurrentProcInfo) and
                           (SearchSym.Owner.SymTableType=StaticSymTable) then
                          Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
                        { Stop looking if this is a category that extends the specified
                          class itself. There might be other categories that extend this,
                          but that doesn't matter. If it extens a parent, keep looking
                          in case we find the symbol in a category that extends this class
                          (or a closer parent).
                        }
                        if not Result or
                           Def_Is_Related(DefOwner.ChildOf,FoundDefOwner) then
                          begin
                            FoundDefOwner:=DefOwner.ChildOf;
                            SRSym:=TProcDef(TProcSym(SearchSym).ProcDefList[I]).ProcSym;
                            SRSymTable:=SRSym.Owner;
                            Result:=True;
                            if PD=FoundDefOwner then
                              begin
                                AddSymRef(SRSym);
                                Exit;
                              end;
                          end;
                      end;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        if Result then
          begin
            AddSymRef(SRSym);
            Exit;
          end;
      end;


    function Search_ObjC_Method(const S : string; out SRSym: TSym; out SRSymTable: TSymTable):Boolean;
      var
        HashedID   : THashedIDString;
        StackItem  : PSymTableStackItem;
        I          : LongInt;
      begin
        HashedID.ID:=ClassHelperPrefix+S;
        StackItem:=SymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            SRSymTable:=StackItem^.SymTable;
            SRSym:=TSym(SRSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) then
              begin
                if not(SRSymTable.SymTableType in [GlobalSymTable,StaticSymTable]) or
                   not(SRSym.Owner.SymTableType in [GlobalSymTable,StaticSymTable]) or
                   (SRSym.Typ<>ProcSym) then
                  InternalError(2009112005);
                { check whether this procsym includes a helper for this particular class }
                for I:=0 to TProcSym(SRSym).ProcDefList.Count-1 do
                  begin
                    { we need to know if a procedure references symbols
                      in the static symtable, because then it can't be
                      inlined from outside this unit }
                    if Assigned(CurrentProcInfo) and
                       (SRSym.Owner.SymTableType=StaticSymTable) then
                      Include(CurrentProcInfo.Flags,pi_uses_static_symtable);
                    { no need to keep looking. There might be other
                      methods with the same name, but that doesn't matter
                      as far as the basic procsym is concerned.
                    }
                    SRSym:=TProcDef(TProcSym(SRSym).ProcDefList[I]).ProcSym;
                    { We need the symtable in which the classhelper-like sym
                      is located, not the objectdef. The reason is that the
                      callnode will climb the symtablestack until it encounters
                      this symtable to start looking for overloads (and it won't
                      find the objectsymtable in which this method sym is
                      located

                    srsymtable:=srsym.owner;
                    }
                    AddSymRef(SRSym);
                    Result:=True;
                    Exit;
                  end;
              end;
            StackItem:=StackItem^.Next;
          end;
        SRSym:=nil;
        SRSymTable:=nil;
        Result:=False;
      end;


    function Search_Struct_Member(PD : TAbstractRecordDef;const S : string):TSym;
    { searches n in symtable of pd and all anchestors }
      var
        SRSymTable : TSymTable;
      begin
        { in case this is a formal class, first find the real definition }
        if (oo_is_formal in PD.ObjectOptions) then
          PD:=Find_Real_Class_Definition(TObjectDef(PD),True);

        if Search_ObjectPascal_Helper(PD, PD, S, Result, SRSymTable) then
          Exit;

        Result:=Search_Struct_Member_No_Helper(PD,S);
        if Assigned(Result) then
          Exit;

        { not found, now look for class helpers }
        if Is_ObjCClass(PD) then
          Search_ObjC_Helper(TObjectDef(PD),S,Result,SRSymTable)
      end;


    function Search_Struct_Member_No_Helper(PD: TAbstractRecordDef; const S: string): TSym;
      var
        HashedID   : THashedIDString;
        SRSym      : TSym;
      begin
        HashedID.ID:=S;
        while Assigned(PD) do
         begin
            SRSym:=TSym(PD.SymTable.FindWithHash(HashedID));
            if Assigned(SRSym) then
              begin
                Result:=SRSym;
                Exit;
              end;
            if PD.Typ=ObjectDef then
              PD:=TObjectDef(PD).ChildOf
            else
              PD:=nil;
          end;
        Result:=nil;
      end;


    function Search_Macro(const S : string):TSym;
      var
        StackItem  : PSymTableStackItem;
        HashedID   : THashedIDString;
        SRSym      : TSym;
      begin
        HashedID.ID:=S;

        { The default text model is selected once for the compiler invocation.
          A unit-local or imported macro must not shadow its define. }
        if Upper(S)='FPC_UNICODESTRINGS' then
          begin
            HashedID.ID:='FPC_UNICODESTRINGS';
            if Assigned(InitialMacroSymTable) then
              Result:=TSym(InitialMacroSymTable.FindWithHash(HashedID))
            else
              Result:=nil;
            Exit;
          end;

        { First search the localmacrosymtable before searching the
          global macrosymtables from the units }
        if Assigned(CurrentModule) then
          begin
            SRSym:=TSym(CurrentModule.LocalMacroSymTable.FindWithHash(HashedID));
            if Assigned(SRSym) then
              begin
                Result:= SRSym;
                Exit;
              end;
          end;

        StackItem:=MacroSymTableStack.Stack;
        while Assigned(StackItem) do
          begin
            SRSym:=TSym(StackItem^.SymTable.FindWithHash(HashedID));
            if Assigned(SRSym) then
              begin
                Result:= SRSym;
                Exit;
              end;
            StackItem:=StackItem^.Next;
          end;
        Result:= nil;
      end;


    function Defined_Macro(const S : string):Boolean;
      var
        Mac: TMacro;
      begin
        Mac:=TMacro(Search_Macro(S));
        if Assigned(Mac) then
          begin
            Mac.IsUsed:=True;
            Defined_Macro:=Mac.Defined;
          end
        else
          Defined_Macro:=False;
      end;


{****************************************************************************
                              Object Helpers
****************************************************************************}

   function Search_Default_Property(PD : TAbstractRecordDef) : TPropertySym;
   { returns the default property of a class, searches also anchestors }
     var
       _defaultprop : TPropertySym;
       HelperPD : TObjectDef;
     begin
        _defaultprop:=nil;
        { first search in helper's hierarchy }
        if Search_Last_ObjectPascal_Helper(PD,nil,HelperPD) then
          while Assigned(HelperPD) do
            begin
              HelperPD.SymTable.SymList.ForEachCall(@TStoredSymTable(HelperPD.SymTable).TestForDefaultProperty,@_defaultprop);
              if Assigned(_defaultprop) then
                Break;
              HelperPD:=HelperPD.ChildOf;
            end;
        if Assigned(_defaultprop) then
          begin
            Search_Default_Property:=_defaultprop;
            Exit;
          end;
        { now search in the type's hierarchy itself }
        while Assigned(PD) do
          begin
             PD.SymTable.SymList.ForEachCall(@TStoredSymTable(PD.SymTable).TestForDefaultProperty,@_defaultprop);
             if Assigned(_defaultprop) then
               Break;
             if (PD.Typ=ObjectDef) then
               PD:=TObjectDef(PD).ChildOf
             else
               Break;
          end;
        Search_Default_Property:=_defaultprop;
     end;


{****************************************************************************
                              Macro Helpers
****************************************************************************}

    procedure Def_System_Macro(const Name : string);
      var
        Mac : TMacro;
        S: string;
      begin
         if Name = '' then
           InternalError(2004121202);
         S:= Upper(Name);
         Mac:=TMacro(Search_Macro(S));
         if not Assigned(Mac) then
           begin
             Mac:=TMacro.Create(S);
             if Assigned(CurrentModule) then
               CurrentModule.LocalMacroSymTable.InsertSym(Mac)
             else
               InitialMacroSymTable.InsertSym(Mac);
           end;
         Message1(parser_c_macro_defined,Mac.Name);
         Mac.Defined:=True;
      end;


    procedure Set_System_Macro(const Name, Value : string);
      var
        Mac : TMacro;
        S: string;
      begin
        if Name = '' then
          InternalError(2004121203);
         S:= Upper(Name);
         Mac:=TMacro(Search_Macro(S));
         if not Assigned(Mac) then
           begin
             Mac:=TMacro.Create(S);
             if Assigned(CurrentModule) then
               CurrentModule.LocalMacroSymTable.InsertSym(Mac)
             else
               InitialMacroSymTable.InsertSym(Mac);
           end
         else
           begin
             Mac.IsCompilerVar:=False;
             Mac.Free_BufText;
           end;
           Mac.IsCMacro:=True;
         Message2(parser_c_macro_set_to,Mac.Name,Value);
         Move(Value[1],Mac.Allocate_BufText(Length(Value))^,Length(Value));
         Mac.Defined:=True;
      end;


    procedure Set_System_CompVar(const Name, Value : string);
      var
        Mac : TMacro;
        S: string;
      begin
        if Name = '' then
          InternalError(2004121204);
         S:= Upper(Name);
         Mac:=TMacro(Search_Macro(S));
         if not Assigned(Mac) then
           begin
             Mac:=TMacro.Create(S);
             Mac.IsCompilerVar:=True;
             if Assigned(CurrentModule) then
               CurrentModule.LocalMacroSymTable.InsertSym(Mac)
             else
               InitialMacroSymTable.InsertSym(Mac);
           end
         else
           Mac.IsCompilerVar:=True;
         Message2(parser_c_macro_set_to,Mac.Name,Value);
         Move(Value[1],Mac.Allocate_BufText(Length(Value))^,Length(Value));
         Mac.Defined:=True;
      end;


    procedure Undef_System_Macro(const Name : string);
      var
        Mac : TMacro;
        S: string;
      begin
         if Name = '' then
           InternalError(2004121205);
         S:= Upper(Name);
         Mac:=TMacro(Search_Macro(S));
         if not Assigned(Mac) then
           {If not found, then it's already undefined.}
         else
           begin
             Message1(parser_c_macro_undefined,Mac.Name);
             Mac.Defined:=False;
             Mac.IsCompilerVar:=False;
             { delete old definition }
             Mac.Free_BufText;
           end;
      end;


{$ifdef UNITALIASES}
{****************************************************************************
                              TUNIT_ALIAS
 ****************************************************************************}

    constructor TUnitAlias.Create(const N:string);
      var
        I : LongInt;
      begin
        I:=Pos('=',N);
        if I=0 then
         Fail;
        inherited CreateName(Copy(N,1,I-1));
        NewName:=StringDup(Copy(N,I+1,255));
      end;


    destructor TUnitAlias.Destroy;
      begin
        StringDispose(NewName);
        inherited Destroy;
      end;


    procedure AddUnitAlias(const N:string);
      begin
        UnitAliases^.Insert(TUnitAlias,Init(Upper(N))));
      end;


    function GetUnitAlias(const N:string):string;
      var
        P : PUnitAlias;
      begin
        P:=PUnitAlias(UnitAliases^.Find(Upper(N)));
        if Assigned(P) then
         GetUnitAlias:=PUnitAlias(P).NewName^
        else
         GetUnitAlias:=N;
      end;
{$endif UNITALIASES}


{****************************************************************************
                           Init/Done Symtable
****************************************************************************}

   procedure InitSymTable;
     var
       TextModeMacro: TMacro;
     begin
       { Reset symbolstack }
       SymTableStack:=nil;
       SystemUnit:=nil;
       { create error syms and def }
       GenErrorSym:=TErrorSym.Create;
       GenErrorDef:=CErrorDef.Create;
       { macros }
       InitialMacroSymTable:=TMacroSymTable.Create(False);
       TextModeMacro:=TMacro.Create('FPC_UNICODESTRINGS');
       TextModeMacro.Defined:=False;
       InitialMacroSymTable.InsertSym(TextModeMacro);
       MacroSymTableStack:=TSymTableStack.Create;
       MacroSymTableStack.Push(InitialMacroSymTable);
{$ifdef UNITALIASES}
       { unit aliases }
       UnitAliases:=TFPHashObjectList.Create;
{$endif}
       DupNr:=0;
     end;


   procedure DoneSymTable;
      begin
        GenErrorSym.Owner:=nil;
        GenErrorSym.Free;
        GenErrorSym := nil;
        GenErrorDef.Owner:=nil;
        GenErrorDef.Free;
        GenErrorDef := nil;
        InitialMacroSymTable.Free;
        InitialMacroSymTable := nil;
        MacroSymTableStack.Free;
        MacroSymTableStack := nil;
{$ifdef UNITALIASES}
        UnitAliases.Free;
        UnitAliases := nil;
{$endif}
     end;

end.
