{
    Symbol table implementation for the definitions

    Copyright (c) 1998-2005 by Florian Klaempfl, Pierre Muller

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
unit symdef;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
    { common }
       CClasses,WideStr,
       { global }
       GlobType,Globals,Tokens,ConstExp,
       { symtable }
       SymConst,SymBase,SymType,
       { node }
       Node,
       { aasm }
       AAsmTAI,
       CPUInfo,
       CGBase,
       ParaBase
       ;


    type
{************************************************
                    TDef
************************************************}

       TGenericConstraintData=class
         Interfaces : TFPObjectList;
         InterfacesDeref : TFPList;
         Flags : TGenericConstraintFlags;
         { only required while parsing }
         FileInfo : TFilePosInfo;
         constructor Create;
         destructor Destroy;override;
         procedure PPULoad(PPUFile:TCompilerPPUFile);
         procedure PPUWrite(PPUFile:TCompilerPPUFile);
         procedure BuildDeref;
         procedure Deref;
       end;

       { trtti_attribute_list }

       TRTTIAttribute = class
          TypeSym         : TSym;
          TypeSymDeref    : TDeref;
          TypeConstr      : TDef;
          TypeConstrDeref : TDeref;
          { these two are not stored in PPU }
          ConstructorCall : TNode;
          ConstructorPD   : TDef;
          Paras           : array of TNode;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          procedure PPUWrite(PPUFile:TCompilerPPUFile);
          procedure PPULoadSubEntries(PPUFile:TCompilerPPUFile);
          procedure PPUWriteSubEntries(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure BuildDeref;
          procedure Deref;
       end;

       TRTTIAttributeList = class
          RTTIAttributes : TFPObjectList;
          { if the attribute list is bound to a def or symbol }
          IsBound : Boolean;
          class procedure Bind(var Dangling,Owned:TRTTIAttributeList);
          class procedure CopyAndBind(AList :TRTTIAttributeList; var Owned : TRTTIAttributeList);
          procedure AddAttribute(ATypeSym:TSym;TypeConstr:TDef;ConstructorCall:TNode;constref Paras:array of TNode);
          procedure AddAttribute(Attr:TRTTIAttribute);
          destructor Destroy; override;
          function GetAttributeCount:LongInt;
          procedure BuildDeref;
          procedure Deref;

          class function PPULoad(PPUFile:TCompilerPPUFile):TRTTIAttributeList;
          class procedure PPUWrite(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
          class procedure PPULoadSubEntries(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
          class procedure PPUWriteSubEntries(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
       end;

       { tstoreddef }

       TStoredDef = class(TDef)
       private
{$ifdef symansistr}
          FFullOwnerHierarchyName : AnsiString;
{$else symansistr}
          FFullOwnerHierarchyName : PShortString;
{$endif symansistr}
          procedure WriteEntry(PPUFile: TCompilerPPUFile; IBNR: Byte);
       protected
          TypeSymDeref  : TDeref;
          procedure PPUWritePlatform(PPUFile:TCompilerPPUFile);virtual;
          procedure PPULoadPlatform(PPUFile:TCompilerPPUFile);virtual;
          { a (possibly) reusable def is always created on the basis of another
            def, and contains a reference to this other def. If this other
            def is in a non-persistent symboltable, the new def cannot actually
            be safely reused everywhere in the current module. This routine
            abstracts that checking, and also restores the symtable stack
            (which had to be reset before creating the new def, so that the new
             def did not automatically get added to its top) }
          class procedure SetupReusableDef(OrigDef, NewDef: TDef; Res: PHashSetItem; OldSymTableStack: TSymTableStack);
       public
{$ifdef EXTDEBUG}
          FileInfo   : TFilePosInfo;
{$endif}
          { generic support }
          GenericDef      : TStoredDef;
          GenericDefDeref : TDeref;
          GenericTokenBuf : TDynamicArray;
          { this list contains references to the symbols that make up the
            generic parameters; the symbols are not owned by this list
            Note: this list is allocated on demand! }
          GenericParas    : TFPHashObjectList;
          GenericParaDerefs : TFPList;
          { contains additional data if this def is a generic constraint
            Note: this class is allocated on demand! }
          GenConstraintData : TGenericConstraintData;
          { this is Nil if the def has no RTTI attributes }
          RTTIAttributeList : TRTTIAttributeList;
          { original def for "type <name>" declarations }
          OrgDef          : TStoredDef;
          OrgDefDeref     : TDeref;
          constructor Create(DT:TDefTyp;DoRegister:Boolean);
          constructor PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
          destructor  Destroy;override;
          function GetCopy : TStoredDef;virtual;
          procedure PPUWrite(PPUFile:TCompilerPPUFile);virtual;
          { this is called directly after ppuload }
          procedure PPULoadSubEntries(PPUFile:TCompilerPPUFile);virtual;
          { this is called directly after ppuwrite }
          procedure PPUWriteSubEntries(PPUFile:TCompilerPPUFile);virtual;
          procedure BuildDeref;override;
          procedure BuildDerefImpl;override;
          procedure Deref;override;
          procedure DerefImpl;override;
          function  Size:ASizeInt;override;
          function  GetVarDef:LongInt;override;
          function  Alignment:ShortInt;override;
          function  IsPublishable : TPublishProperty;override;
          function  NeedsInitTable : Boolean;override;
          function  HasNonTrivialInitChild(CheckParent:Boolean):Boolean;override;
          function  RTTIMangledName(RT:TRTTIType):TSymStr;override;
          function  OwnerHierarchyName: string; override;
          function  OwnerHierarchyPrettyName: string; override;
          function  FullOwnerHierarchyName(SkipProcParams:Boolean;UsePretty : Boolean):TSymStr;override;

          function  NeedsSeparateInitRTTI:Boolean;override;
          function  In_CurrentUnit: Boolean;
          { regvars }
          function Is_IntRegable : Boolean;
          function Is_FPURegable : Boolean;
          { def can be put into a register if it is const/immutable }
          function Is_Const_IntRegable : Boolean;
          { generics }
          procedure InitGeneric;
          { this function can be used to determine whether a def is really a
            generic declaration or just a normal type declared inside another
            generic }
          function Is_Generic:Boolean;
          { same as above for specializations }
          function Is_Specialization:Boolean;
          { generic utilities }
          function Is_Generic_Param_Const(Index:Integer):Boolean;inline;
          function Get_Generic_Param_Def(Index:Integer):TDef;inline;
          { registers this def in the unit's deflist; no-op if already registered }
          procedure RegisterDef; override;
          { add the def to the top of the symtable stack if it's not yet owned
            by another symtable }
          procedure Maybe_Put_In_SymTable_Stack;
       private
          SaveSize  : ASizeUInt;
       end;

       TFileTyp = (ft_text,ft_typed,ft_untyped);

       TFileDef = class(TStoredDef)
          FileTyp : TFileTyp;
          TypedFileDef : TDef;
          TypedFileDefDeref : TDeref;
          constructor CreateText;virtual;
          constructor CreateUntyped;virtual;
          constructor CreateTyped(Def : TDef);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function  GetTypeName:string;override;
          function  GetMangledParaName:TSymStr;override;
          function  Size:ASizeInt;override;
          procedure SetSize;
          function Alignment: ShortInt; override;
       end;
       TFileDefClass = class of TFileDef;

       TVariantDef = class(TStoredDef)
          VariantType : TVariantType;
          constructor Create(V : TVariantType);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          function GetTypeName:string;override;
          function Alignment : ShortInt;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetVarDef:LongInt;override;
          procedure SetSize;
          function IsPublishable : TPublishProperty;override;
          function NeedsInitTable : Boolean;override;
       end;
       TVariantDefClass = class of TVariantDef;

       TFormalDef = class(TStoredDef)
          Typed:Boolean;
          constructor Create(ATyped:Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
       end;
       TFormalDefClass = class of TFormalDef;

       TForwardDef = class(TStoredDef)
          ToSymName : PShortString;
          ForwardPos : TFilePosInfo;
          constructor Create(const S:string;const Pos:TFilePosInfo);virtual;
          destructor Destroy;override;
          function GetCopy:TStoredDef;override;
          function GetTypeName:string;override;
       end;
       TForwardDefClass = class of TForwardDef;

       TUndefinedDef = class(TStoredDef)
          constructor Create(DoRegister:Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
       end;
       TUndefinedDefClass = class of TUndefinedDef;

       TErrorDef = class(TStoredDef)
          constructor Create;virtual;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
          function  GetMangledParaName : TSymStr;override;
       end;
       TErrorDefClass = class of TErrorDef;

       TAbstractPointerDef = class(TStoredDef)
          PointedDef : TDef;
          PointedDefDeref : TDeref;
          constructor Create(DT:TDefTyp;Def:TDef);
          constructor PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          procedure BuildDeref;override;
          procedure Deref;override;
          function Size:ASizeInt;override;
          function Alignment:ShortInt;override;
       end;

       TPointerDef = class(TAbstractPointerDef)
          HasPointerMath : Boolean;
          constructor Create(Def:TDef);virtual;
          { returns a pointerdef for def, reusing an existing one in case it
            exists in the current module }
          class function GetReusable(Def: TDef): TPointerDef; virtual;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function GetReusable_No_Free(Def: TDef): TPointerDef;
          function Size:ASizeInt;override;
          function GetCopy:TStoredDef;override;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
          {# returns the appropriate int type for pointer arithmetic with the given pointer type.
             When adding or subtracting a number to/from a pointer, this function returns the
             int type to which that number has to be converted, before the operation can be performed.
             Normally, this is sinttype, except on i8086, where it takes into account the
             special i8086 pointer types (near, far, huge). }
          function Pointer_Arithmetic_Int_Type:TDef;virtual;
          {# the unsigned version of pointer_arithmetic_int_type. Used with inc/dec. }
          function Pointer_Arithmetic_UInt_Type:TDef;virtual;
          {# returns the int type produced when subtracting two pointers of the given type.
             Normally, this is sinttype, except on i8086, where it takes into account the
             special i8086 pointer types (near, far, huge). }
          function Pointer_Subtraction_Result_Type:TDef;virtual;
          function Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean; virtual;
          {# the integer index type used to convert the pointer to array (i.e. denotes int_type in: ptr[int_type]) }
          function Converted_Pointer_To_Array_Range_Type:TDef;virtual;
       end;
       TPointerDefClass = class of TPointerDef;

       TProcDef = class;

       TAbstractRecordDef= class(TStoredDef)
       private
          RTTIString     : string;
{$ifdef DEBUG_NODE_XML}
       protected
          procedure XMLPrintDefData(var T: Text; Sym: TSym); override;
{$endif DEBUG_NODE_XML}
       public
          ObjName,
          ObjRealName    : PShortString;
          { for C++ classes: name of the library this class is imported from }
          ImportLib     : PShortString;
          SymTable       : TSymTable;
          ClonedDef      : TAbstractRecordDef;
          ClonedDefDeref : TDeref;
          ObjectOptions  : TObjectOptions;
          RTTI           : TRTTIDirective;
          { for targets that initialise typed constants via explicit assignments
            instead of by generating an initialised data section }
          TCInitCode     : TNode;
          constructor Create(const N:string; DT:TDefTyp;DoRegister:Boolean);
          constructor PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;
          destructor Destroy; override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          procedure Check_Forwards; virtual;
          function Find_ProcDef_ByType(PT:TProcTypeOption): TProcDef;
          function GetSymTable(T:TGetSymTable):TSymTable;override;
          function Is_Packed:Boolean;
          function RTTIName: string;
          { enumerator support }
          function Search_Enumerator_Get: TProcDef; virtual;
          function Search_Enumerator_Move: TProcDef; virtual;
          function Search_Enumerator_Current: TSym; virtual;
          { check if the symtable contains a float field }
          function Contains_Float_Field : Boolean;
          { check if the symtable contains a field that spans an aword boundary }
          function Contains_Cross_AWord_Field: Boolean;
          { extended RTTI }
          procedure Apply_RTTI_Directive(Dir: TRTTIDirective); virtual;
          function Is_Visible_For_RTTI(Option: TRTTIOption; Vis: TVisibility): Boolean; inline;
          function RTTI_Visibilities_For_Option(Option: TRTTIOption): TVisibilities; inline;
          function Has_Extended_RTTI: Boolean; inline;
          { update the name of the object, typically needed after getcopy }
          procedure SetObjRealName(const N: string);
       end;

       PVariantRecDesc = ^TVariantRecDesc;

       TVariantRecBranch = record
         { we store only single values here and no ranges because tvariantrecdesc is only needed in iso mode
           which does not support range expressions in variant record definitions }
         Values : array of TConstExprInt;
         NestedVariant : PVariantRecDesc;
       end;

       PPVariantRecDesc = ^PVariantRecDesc;

       TVariantRecDesc = record
         VariantSelector : TSym;
         VariantSelectorDeref : TDeref;
         Branches : array of TVariantRecBranch;
       end;

       TRecordDef = class(TAbstractRecordDef)
{$ifdef DEBUG_NODE_XML}
       protected
          function XMLPrintType: AnsiString; override;
{$endif DEBUG_NODE_XML}
       public
          VariantRecDesc : PVariantRecDesc;
          IsUnion       : Boolean;
          constructor Create(const N:string; P:TSymTable);virtual;
          constructor Create_Global_Internal(const N: string; PackRecords, RecordAlignMin: ShortInt); virtual;
          constructor Create_Internal(const N: string; PackRecords, RecordAlignMin: ShortInt; Where: TSymTable); virtual;
          function Add_Field_By_Def(const OptionalName: TIDString; Def: TDef): TSym;
          procedure Add_Fields_From_DefList(FieldTypes: TFPList);
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function  Size:ASizeInt;override;
          function  Alignment : ShortInt;override;
          function  PadAlignment: ShortInt;
          function  GetTypeName:string;override;
          { debug }
          function  NeedsInitTable : Boolean;override;
          function  NeedsSeparateInitRTTI:Boolean;override;
          function  HasNonTrivialInitChild(CheckParent:Boolean):Boolean;override;
       end;
       TRecordDefClass = class of TRecordDef;

       TObjectDef = class;

       { TImplementedInterface }

       TImplementedInterface = class
        private
         FIOffset      : LongInt;
         function GetIOffset: LongInt;
        public
         IntfDef      : TObjectDef;
         IntfDefDeref : TDeref;
         IType        : TInterfaceEntryType;
         VtblImplIntf : TImplementedInterface;
         NameMappings : TFPHashList;
         ProcDefs     : TFPObjectList;
         ImplementsGetter :  TSym;
         ImplementsGetterDeref : TDeref;
         ImplementsField : TSym;
         constructor Create(AIntf: TObjectDef);virtual;
         constructor Create_Deref(IntfD,GetterD:TDeref);virtual;
         destructor  Destroy; override;
         function GetCopy:TImplementedInterface;
         procedure BuildDeref;
         procedure Deref;
         procedure AddMapping(const OrigName, NewName: string);
         function  GetMapping(const OrigName: string):string;
         procedure AddImplProc(PD:TProcDef);
         function  IsImplMergePossible(MergingIntf:TImplementedInterface;out Weight: LongInt): Boolean;
         property  IOffset: LongInt read GetIOffset write FIOffset;
       end;
       TImplementedInterfaceClass = class of TImplementedInterface;

       { tvmtentry }
       TVMTEntry = record
         ProcDef      : TProcDef;
         ProcDefDeref : TDeref;
         Visibility   : TVisibility;
       end;
       PVMTEntry = ^TVMTEntry;

       { tobjectdef }

       TVMCallStatic = (vmcs_default, vmcs_yes, vmcs_no, vmcs_unreachable);
       PMVCallStaticInfo = ^TMVCallStaticInfo;
       TMVCallStaticInfo = array[0..1024*1024-1] of TVMCallStatic;
       TObjectDef = class(TAbstractRecordDef)
       private
          FCurrentDispID: LongInt;
{$ifdef DEBUG_NODE_XML}
       protected
          function XMLPrintType: AnsiString; override;
          procedure XMLPrintDefInfo(var T: Text; Sym: TSym); override;
          procedure XMLPrintDefData(var T: Text; Sym: TSym); override;
{$endif DEBUG_NODE_XML}
       public
          ChildOf        : TObjectDef;
          ChildOfDeref   : TDeref;

          { for Object Pascal helpers }
          ExtendedDef   : TDef;
          ExtendedDefDeref: TDeref;
          HelperType : THelperType;
          { for Objective-C: protocols and classes can have the same name there }
          ObjExtName     : PShortString;
          { to be able to have a variable vmt position }
          { and no vmt field for objects without virtuals }
          VMTEntries     : TFPList;
          VMCallStaticInfo : PMVCallStaticInfo;
          VMTField       : TSym;
          VMTFieldDeref  : TDeref;
          IIDGUID        : PGUID;
          IIDStr         : PShortString;
          { store implemented interfaces defs and name mappings }
          ImplementedInterfaces : TFPObjectList;

          { Number of abstract methods, including inherited methods. }
          AbstractCnt    : LongInt;
          WritingClassRecordDbgInfo,
          { a class of this type has been created in this module }
          CreatedInCurrentModule,
          { a loadvmtnode for this class has been created in this
            module, so if a classrefdef variable of this or a parent
            class is used somewhere to instantiate a class, then this
            class may be instantiated
          }
          MaybeCreatedInCurrentModule,
          { a "class of" this particular class has been created in
            this module
          }
          ClassRefCreatedInCurrentModule : Boolean;
          ObjectType     : TObjectTyp;
          { for interfaces that can be invoked using Invoke(),
            this is the definition of the hidden class that is generated by the compiler.
            we need this definition to reference it in the RTTI.
            Since interfaces can inherit, so can these hidden classes,
            so we need to write this to the ppu to be able to reference the parents.
          }
          HiddenClassDef : TObjectDef;
          HiddenClassDefRef : TDeref;
          constructor Create(OT:TObjectTyp;const N:string;C:TObjectDef;DoRegister:Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor  Destroy;override;
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function GetTypeName:string;override;
          procedure BuildDeref;override;
          procedure Deref;override;
          procedure DerefImpl;override;
          procedure CopyVMTEntries(ObjDef:TObjectDef);
          function  GetParentDef:TDef;override;
          function  Size : ASizeInt;override;
          function  Alignment:ShortInt;override;
          function  VMTMethodOffset(Index:LongInt):LongInt;
          function  Members_Need_InitTable : Boolean;
          { this should be called when this class implements an interface }
          procedure PrepareGUID;
          function  IsPublishable : TPublishProperty;override;
          function  NeedsInitTable : Boolean;override;
          function  NeedsSeparateInitRTTI : Boolean;override;
          function  HasNonTrivialInitChild(CheckParent:Boolean):Boolean;override;
          function  RTTIMangledName(RT:TRTTIType):TSymStr;override;
          function  Is_Unique_ObjPasDef: Boolean;
          function  VMT_MangledName : TSymStr;
          function  VMT_Def: TRecordDef;
          procedure Check_Forwards; override;
          procedure InsertVMT;
          function  VMT_Offset: ASizeInt;
          procedure Set_Parent(C : TObjectDef);
          function Find_Destructor: TProcDef;
          function Implements_Any_Interfaces: Boolean;
          function Register_Implemented_Interface(IntfDef:TObjectDef;UseGUID:Boolean):TImplementedInterface;
          { dispinterface support }
          function Get_Next_DispID: LongInt;
          { enumerator support }
          function Search_Enumerator_Get: TProcDef; override;
          function Search_Enumerator_Move: TProcDef; override;
          function Search_Enumerator_Current: TSym; override;
          { WPO }
          procedure RegisterCreatedObjectType;override;
          procedure Register_Maybe_Created_Object_Type;
          procedure RegisterCreatedClassRefType;
          procedure Register_VMT_Call(Index:LongInt);
          { ObjC }
          procedure Finish_ObjC_Data;
          function Check_ObjC_Types: Boolean;
          { C++ }
          procedure Finish_CPP_Data;
          procedure Apply_RTTI_Directive(Dir: TRTTIDirective); override;
       end;
       TObjectDefClass = class of TObjectDef;

       TClassRefDef = class(TAbstractPointerDef)
          constructor Create(Def:TDef);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function GetCopy:TStoredDef;override;
          function GetTypeName:string;override;
          function IsPublishable : TPublishProperty;override;
          function RTTIMangledName(RT:TRTTIType):TSymStr;override;
          procedure RegisterCreatedObjectType;override;
       end;
       TClassRefDefClass = class of TClassRefDef;

       TArrayDef = class(TStoredDef)
          LowRange,
          HighRange     : ASizeInt;
          RangeDef      : TDef;
          RangeDefDeref : TDeref;
          ArrayOptions  : TArrayDefOptions;
          SymTable      : TSymTable;
       protected
          FElementDef      : TDef;
          FElementDefDeref : TDeref;
          procedure SetElementDef(Def:TDef);
          class function GetReusable_Intern(Def: TDef; Elems: ASizeInt; const Options: TArrayDefOptions): TArrayDef;
       public
          function EleSize : ASizeInt;
          function ElePackedBitSize : ASizeInt;
          function EleCount : ASizeUInt;
          constructor Create_From_Pointer(Def: TPointerDef);virtual;
          constructor Create(L, H: ASizeInt; Def: TDef);virtual;
          constructor Create_Vector(L,H:ASizeInt; Def:TDef);
          constructor Create_OpenArray;virtual;
          class function GetReusable(Def: TDef; Elems: ASizeInt): TArrayDef;
          class function GetReusable_Vector(Def: TDef; Elems: ASizeInt): TArrayDef;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function GetReusable_No_Free(Def: TDef; Elems: ASizeInt): TArrayDef;
          class function GetReusable_No_Free_Vector(Def: TDef; Elems: ASizeInt): TArrayDef;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy; override;
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
          function  GetMangledParaName : TSymStr;override;
          procedure BuildDeref;override;
          procedure Deref;override;
          function Size : ASizeInt;override;
          function Alignment : ShortInt;override;
          { returns the label of the range check string }
          function NeedsInitTable : Boolean;override;
          function NeedsSeparateInitRTTI : Boolean;override;
          property ElementDef : TDef read FElementDef write SetElementDef;
          function IsPublishable : TPublishProperty;override;
          function Is_HWVector: Boolean;
       end;
       TArrayDefClass = class of TArrayDef;

       TOrdDef = class(TStoredDef)
          Low,High : TConstExprInt;
          OrdType  : TOrdType;
          constructor Create(T : TOrdType;V,B : TConstExprInt; DoRegister: Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  IsPublishable : TPublishProperty;override;
          function  GetTypeName:string;override;
          function Alignment:ShortInt;override;
          procedure SetSize;
          function  PackedBitSize: ASizeInt; override;
          function GetVarDef : LongInt;override;
       end;
       TOrdDefClass = class of TOrdDef;

       TFloatDef = class(TStoredDef)
          FloatType : TFloatType;
          constructor Create(T: TFloatType; DoRegister: Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function Alignment:ShortInt;override;
          function StructAlignment: ShortInt;override;
          procedure SetSize;
          function  GetVarDef:LongInt;override;
       end;
       TFloatDefClass = class of TFloatDef;

       { tabstractprocdef }

       TProcNameOption = (pno_showhidden, pno_proctypeoption, pno_paranames,
         pno_ownername, pno_noclassmarker, pno_noleadingdollar,
         pno_mangledname, pno_noparams, pno_prettynames);
       TProcNameOptions = set of TProcNameOption;
       TProcCopyTyp = (pc_normal,

                       { creates a procvardef describing only the code pointer
                         of a method/netsted function/... }
                       pc_address_only,
                       { everything except for hidden parameters }
                       pc_normal_no_hidden,
                       { everything except for the parameters (because they
                         might be moved over to the copy) }
                       pc_normal_no_paras,
                       { always creates a top-level function, removes all
                         special parameters (self, vmt, parentfp, ...) }
                       pc_bareproc
                       );
       TCacheableProcCopyType = pc_normal..pc_address_only;

       TAbstractProcDef = class(TStoredDef)
          { saves a definition to the return type }
          ReturnDef       : TDef;
          ReturnDefDeref  : TDeref;
          ParaST          : TSymTable;
          Paras           : TParaList;
          ProcTypeOption  : TProcTypeOption;
          ProcCallOption  : TProcCallOption;
          ProcOptions     : TProcOptions;
          CallerArgAreaSize,
          CalleeArgAreaSize: PInt;
          FuncRetLoc : array[CallerSide..CalleeSide] of TCGPara;
          HasParaLocInfo : TCallerCallee; { paraloc info is available }
          { number of user visible parameters }
          MaxParaCount,
          MinParaCount    : Word;
          constructor Create(DT:TDefTyp;Level:Byte;DoRegister:Boolean);
          constructor PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure  PPUWrite(PPUFile:TCompilerPPUFile);override;
          procedure BuildDeref;override;
          procedure Deref;override;
          procedure CalcParas;
          function MangledProcParaNames(OldLen : LongInt) : string;
          function  TypeName_Paras(PNo: TProcNameOptions): AnsiString;
          function  Is_MethodPointer:Boolean;virtual;
          function  Is_AddressOnly:Boolean;virtual;
          function  No_Self_Node:Boolean;
          { get either a copy as a procdef or procvardef }
          function  GetCopyAs(NewTyp:TDefTyp;CopyTyp:TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef; virtual;
          function  Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean; virtual;
          procedure Check_Mark_As_Nested;
          procedure Init_ParaLoc_Info(Side: TCallerCallee);
          procedure Done_ParaLoc_Info(Side: TCallerCallee);
          function Stack_Tainting_Parameter(Side: TCallerCallee): Boolean;
          function Is_PushLeftRight: Boolean;virtual;
          function Address_Type:TDef;virtual;
          { address type, generated for ofs() }
          function Ofs_Address_Type:TDef;virtual;
          function Generate_SafeCall_Wrapper: Boolean; virtual;
          { returns true if the def is a generic param of the procdef }
          function Is_Generic_Param(Def:TDef): Boolean;

          function WPO_May_Create_Instance(OptionalMethodPointer: TNode): Boolean;
       private
          procedure CountPara(P:TObject;Arg:Pointer);
          procedure InsertPara(P:TObject;Arg:Pointer);
       end;

       TProcVarDef = class(TAbstractProcDef)
          constructor Create(Level:Byte;DoRegister:Boolean);virtual;
          { returns a procvardef that represents the address of a proc(var)def }
          class function GetReusableProcAddr(Def: TAbstractProcDef; CopyTyp: TCacheableProcCopyType): TProcVarDef; virtual;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function GetReusableProcAddr_No_Free(Def: TAbstractProcDef): TProcVarDef;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetSymTable(T:TGetSymTable):TSymTable;override;
          function  Size : ASizeInt;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function  Is_MethodPointer:Boolean;override;
          function  Is_AddressOnly:Boolean;override;
          function  GetMangledParaName:TSymStr;override;
          function GetCopyAs(NewTyp: TDefTyp; CopyTyp: TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef; override;
       end;
       TProcVarDefClass = class of TProcVarDef;

       TMessageInf = record
         case Integer of
           0 : (Str : PShortString);
           1 : (I : LongInt);
       end;

       TInliningInfo = record
          { node tree }
          Code  : TNode;
          Flags : TProcInfoFlags;
       end;
       PInliningInfo = ^TInliningInfo;

       TCapturedSymInfo = record
         Sym : TSym;
         Def : TDef;
         { the location where the symbol was first encountered }
         FileInfo : TFilePosInfo;
       end;
       PCapturedSymInfo = ^TCapturedSymInfo;

       TImplProcDefInfo = record
          ResultName : PShortString;
          ParentFPStruct: TSym;
          ParentFPStructPtrType: TDef;
          ParentFPInitBlock: TNode;
          ProcStartTAI,
          ProcEndTAI   : TAI;
          SKPara: Pointer;
          Personality: TProcDef;
          WasAnonymous,
          HasCapturer,
          ForwardDef,
          InterfaceDef : Boolean;
          HasForward  : Boolean;
          IsImplemented : Boolean;
          CapturedSyms : TFPList;
       end;
       PImplProcDefInfo = ^TImplProcDefInfo;

       { tprocdef }

       TProcDef = class(TAbstractProcDef)
       protected
{$ifdef symansistr}
         FMangledName : AnsiString;
{$else symansistr}
         FMangledName : PShortString;
{$endif}
         FParentFPSym : TSym;
         { information that is only required until the implementation of the
           procdef has been handled }
         ImplProcDefInfo : PImplProcDefInfo;

         function Store_LocalST:Boolean;

         function GetResultName: PShortString;
         procedure SetResultName(AValue: PShortString);
         function GetParentFPStruct: TSym;
         procedure SetParentFPStruct(AValue: TSym);
         function GetParentFPStructPtrType: TDef;
         procedure SetParentFPStructPtrType(AValue: TDef);
         function GetParentFPInitBlock: TNode;
         procedure SetParentFPInitBlock(AValue: TNode);
         function GetProcStartTAI: TAI;
         procedure SetProcStartTAI(AValue: TAI);
         function GetProcEndTAI: TAI;
         procedure SetProcEndTAI(AValue: TAI);
         function GetSKPara: Pointer;
         procedure SetSKPara(AValue: Pointer);
         function GetPersonality: TProcDef;
         procedure SetPersonality(AValue: TProcDef);
         function GetForwardDef: Boolean;
         procedure SetForwardDef(AValue: Boolean);
         function GetInterfaceDef: Boolean;
         procedure SetInterfaceDef(AValue: Boolean);virtual;
         function GetHasForward: Boolean;
         procedure SetHasForward(AValue: Boolean);
         function GetIsEmpty: Boolean;
         procedure SetIsEmpty(AValue: Boolean);
         function GetHasInliningInfo: Boolean;
         procedure SetHasInliningInfo(AValue: Boolean);
         function GetIs_Implemented: Boolean;
         procedure SetIs_Implemented(AValue: Boolean);
         function GetWas_Anonymous:Boolean;
         procedure SetWas_Anonymous(AValue:Boolean);
         function GetHas_Capturer:Boolean;
         procedure SetHas_Capturer(AValue:Boolean);
         function GetCapturedSyms:TFPList;
         function GetParentFPSym: TSym;
       public
          MessageInf : TMessageInf;
          DispID : LongInt;
{$ifndef EXTDEBUG}
          { where is this function defined and what were the symbol
            flags, needed here because there
            is only one symbol for all overloaded functions
            EXTDEBUG has fileinfo in tdef (PFV) }
          FileInfo : TFilePosInfo;
{$endif}
          SymOptions : TSymOptions;
          DeprecatedMsg : PShortString;
          { generic support }
          GenericDeclTokenBuf : TDynamicArray;
          { symbol owning this definition }
          ProcSym : TSym;
          ProcSymDeref : TDeref;
          { alias names }
          AliasNames : TCmdStrList;
          { symtables }
          LocalST : TSymTable;
          FuncRetSym : TSym;
          FuncRetSymDeref : TDeref;
          Struct : TAbstractRecordDef;
          StructDeref : TDeref;
          ImplProcOptions: TImplProcOptions;
          { import info }
          ImportDLL,
          ImportName : PShortString;
          { info for inlining the subroutine, if this pointer is nil,
            the procedure can't be inlined }
          InliningInfo : PInliningInfo;
          ImportNr    : Word;
          ExtNumber    : Word;
          { set to a value different from tsk_none in case this procdef is for
            a routine that has to be internally generated by the compiler }
          SyntheticKind: TSyntheticKind;
          Visibility   : TVisibility;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
          SeenMarker : Pointer; // used for filtering in tcandidate
{$endif}
{$ifdef symansistr}
          Section: AnsiString;
{$else symansistr}
          Section: PShortString;
{$endif}
          { only needed when actually compiling a unit, no need to save/load from ppu }
          InvokeHelper : TProcDef;
          CopiedFrom : TProcDef;
          constructor Create(Level:Byte;DoRegister:Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor  Destroy;override;
          procedure   FreeImplProcDefInfo;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure BuildDerefImpl;override;
          procedure Deref;override;
          procedure DerefImpl;override;
          function  GetSymTable(T:TGetSymTable):TSymTable;override;
          { warnings:
              * the symtablestack top has to be the symtable to which the copy
                should be added
              * getcopy does not create a finished/ready-to-use procdef; it
                needs to be finalised afterwards by calling
                symcreat.finish_copied_procdef() afterwards
          }
          function  GetCopyAs(NewTyp:TDefTyp;CopyTyp:TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef; override;
          function  GetCopy: TStoredDef; override;
          function  GetTypeName : string;override;
          function  MangledName : TSymStr; virtual;
          procedure SetMangledName(const S : TSymStr);
          function  NeedsGlobalAsmSym: Boolean;
          procedure SetCompilerProcName;
          function  FullProcName(ShowHidden:Boolean):AnsiString;
          function  CustomProcName(PNo: TProcNameOptions):AnsiString;
          function  DefaultMangledName: TSymStr;
          function  CPlusPlusMangledName : TSymStr;
          function  ObjCMangledName : TSymStr;
          function  Is_MethodPointer:Boolean;override;
          function  Is_AddressOnly:Boolean;override;
          procedure Make_External;
          procedure Init_GenericDecl;
          procedure Reset_After_Conv;

          function Get_FuncRetSym_Info(out ResSym: TSym; out ResDef: TDef): Boolean; virtual;
          function Get_SafeCall_FuncRetSym_Info(out ResSym: TSym; out ResDef: TDef): Boolean; virtual;

          procedure Add_Captured_Sym(Sym:TSym;Def:TDef;const FilePos:TFilePosInfo);

          { returns whether the mangled name or any of its aliases is equal to
            s }
          function  Has_Alias_Name(const S: TSymStr):Boolean;

          { aliases to fields only required when a function is implemented in
            the current unit }
          property ResultName: PShortString read GetResultName write SetResultName;

          property ParentFPStruct: TSym read GetParentFPStruct write SetParentFPStruct;
          { pointer to parentfpstruct's type (not yet valid during parsing, so
            cannot be used for $parentfp parameter) (no need to save to ppu) }
          property ParentFPStructPtrType: TDef read GetParentFPStructPtrType write SetParentFPStructPtrType;
          { code to copy the parameters accessed from nested routines into the
            parentfpstruct (no need to save to ppu) }
          property ParentFPInitBlock: TNode read GetParentFPInitBlock write SetParentFPInitBlock;
          { First/last assembler symbol/instruction in aasmoutput list.
            Note: initialised after compiling the code for the procdef, but
              not saved to/restored from ppu. Used when inserting debug info }
          property ProcStartTAI: TAI read GetProcStartTAI write SetProcStartTAI;
          property ProcEndTAI: TAI read GetProcEndTAI write SetProcEndTAI;
          { optional parameter for the synthetic routine generation logic }
          property SKPara: Pointer read GetSKPara write SetSKPara;
          { ABI-conformant exception handling personality function }
          property Personality: TProcDef read GetPersonality write SetPersonality;
          { true, if the procedure is only declared
            (forward procedure) }
          property ForwardDef: Boolean read GetForwardDef write SetForwardDef;
          { true if the procedure is declared in the interface }
          property InterfaceDef: Boolean read GetInterfaceDef write SetInterfaceDef;
          { true if the procedure has a forward declaration }
          property HasForward: Boolean read GetHasForward write SetHasForward;
          { true if the routine's body is empty }
          property IsEmpty: Boolean read GetIsEmpty write SetIsEmpty;
          { true if all information required to inline this routine is available }
          property HasInliningInfo: Boolean read GetHasInliningInfo write SetHasInliningInfo;
          { returns the $parentfp parameter for nested routines }
          property ParentFPSym: TSym read GetParentFPSym;
          { true if the implementation part for this procdef has been handled }
          property IsImplemented: Boolean read GetIs_Implemented write SetIs_Implemented;
          { valid if the procdef captures any symbols from outer scopes }
          property CapturedSyms:TFPList read GetCapturedSyms;
          { true if this procdef was originally an anonymous function }
          property WasAnonymous:Boolean read GetWas_Anonymous write SetWas_Anonymous;
          { true if the procdef has a capturer for anonymous functions }
          property HasCapturer:Boolean read GetHas_Capturer write SetHas_Capturer;
       end;
       TProcDefClass = class of TProcDef;

       { single linked list of overloaded procs }
       PProcDefList = ^TProcDefList;
       TProcDefList = record
         Def  : TProcDef;
         DefDeref : TDeref;
         Next : PProcDefList;
       end;

       TStringDef = class(TStoredDef)
          Encoding   : TStringEncoding;
          StringType : TStringType;
          Len        : ASizeInt;
          constructor CreateShort(L: Byte; DoRegister: Boolean);virtual;
          constructor LoadShort(PPUFile:TCompilerPPUFile);
          constructor CreateLong(L: ASizeInt; DoRegister: Boolean);virtual;
          constructor LoadLong(PPUFile:TCompilerPPUFile);
          constructor CreateAnsi(AEncoding: TStringEncoding; DoRegister: Boolean);virtual;
          constructor LoadAnsi(PPUFile:TCompilerPPUFile);
          constructor CreateWide(DoRegister: Boolean);virtual;
          constructor LoadWide(PPUFile:TCompilerPPUFile);
          constructor CreateUnicode(DoRegister: Boolean);virtual;
          constructor LoadUnicode(PPUFile:TCompilerPPUFile);virtual;
          function GetCopy : TStoredDef;override;
          function  StringTypName:string;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          function  GetTypeName:string;override;
          function  GetMangledParaName:TSymStr;override;
          function  IsPublishable : TPublishProperty;override;
          function  Size:ASizeInt;override;
          function Alignment : ShortInt;override;
          function  NeedsInitTable : Boolean;override;
          function  GetVarDef:LongInt;override;
          { returns the default char type def for the string }
          function Get_Default_Char_Type: TDef;
          { returns the default string type }
          function Get_Default_String_Type: TDef;
       end;
       TStringDefClass = class of TStringDef;

       TEnumDef = class(TStoredDef)
          MinVal,
          MaxVal    : ASizeInt;
          BaseDef   : TEnumDef;
          BaseDefDeref : TDeref;
          SymTable  : TSymTable;
          HasJumps : Boolean;
          constructor Create;virtual;
          constructor Create_Subrange(ABaseDef:TEnumDef;AMin,AMax:ASizeInt);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          destructor Destroy;override;
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          procedure CalcSaveSize(PackEnum: ShortInt);
          function  PackedBitSize: ASizeInt; override;
          procedure SetMax(AMax:ASizeInt);
          procedure SetMin(AMin:ASizeInt);
          function  Min:ASizeInt;
          function  Max:ASizeInt;
          function  GetFirstSym:TSym;
          function  Int2EnumSym(L: ASizeInt): TSym;
          { returns basedef if assigned, otherwise self }
          function GetBaseDef: TEnumDef;
       end;
       TEnumDefClass = class of TEnumDef;

       TSetDef = class(TStoredDef)
          ElementDef : TDef;
          ElementDefDeref : TDeref;
          { setbase is the value of the lowest value being representable by the set, this could
            be lower then the lowest value being a valid value from the declaration: a set [3..4] might
            have a setbase of 0 for code generation/alignment reasons }
          SetBase,
          { setlow is the lowest value valid according to the declaration of a set, i.e. for a set [3..4] it is really 3 }
          SetLow,
          SetMax   : ASizeInt;
          constructor Create(Def: TDef; Low, High: ASizeInt; DoRegister: Boolean);virtual;
          constructor PPULoad(PPUFile:TCompilerPPUFile);
          function GetCopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure PPUWrite(PPUFile:TCompilerPPUFile);override;Final;
          procedure BuildDeref;override;
          procedure Deref;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function Alignment: ShortInt; override;
       end;
       TSetDefClass = class of TSetDef;


       TGenericDummyEntry = class
         DummySym : TSym;
         ResolvedSym : TSym;
       end;


       TDefAwareSymTableStack = class(TSymTableStack)
       private
         procedure AddHelpersAndGenerics(ST:TSymTable;AddGenerics:Boolean);
         procedure RemoveHelpersAndGenerics(ST:TSymTable);inline;
         procedure RemoveHelpers(ST:TSymTable);
         procedure RemoveGenerics(ST:TSymTable);
         procedure PushCommon(ST:TSymTable);inline;
       public
         procedure Push(ST: TSymTable); override;
         procedure PushAfter(ST,AfterST:TSymTable); override;
         procedure Pop(ST: TSymTable); override;
       end;


    var
       CurrentStructDef: TAbstractRecordDef; { used for private functions check !! }
       CurrentGenericDef: TStoredDef;        { used to reject declaration of generic class inside generic class }
       CurrentSpecializeDef: TStoredDef;     { used to implement usage of generic class in itself }

       CFileDef: TFileDefClass;
       CVariantDef: TVariantDefClass;
       CFormalDef: TFormalDefClass;
       CForwardDef: TForwardDefClass;
       CUndefinedDef: TUndefinedDefClass;
       CErrorDef: TErrorDefClass;
       CPointerDef: TPointerDefClass;
       CRecordDef: TRecordDefClass;
       CImplementedInterface: TImplementedInterfaceClass;
       CObjectDef: TObjectDefClass;
       CClassRefDef: TClassRefDefClass;
       CArrayDef: TArrayDefClass;
       COrdDef: TOrdDefClass;
       CFloatDef: TFloatDefClass;
       CProcVarDef: TProcVarDefClass;
       CProcDef: TProcDefClass;
       CStringDef: TStringDefClass;
       CEnumDef: TEnumDefClass;
       CSetDef: TSetDefClass;


    { default types }
       GenErrorDef,               { error in definition }
       VoidPointerType,           { pointer for Void-pointeddef }
       CharPointerType,           { pointer for Char-pointeddef }
       WideCharPointerType,       { pointer for WideChar-pointeddef }
       VoidCodePointerType,       { pointer to code; corresponds to System.CodePointer }
       VoidStackPointerType,      { the pointer type used for accessing parameters and local vars on the stack }
       ParentFPVoidPointerType,   { void pointer with the size of the hidden parentfp parameter, passed to nested functions }
{$ifdef x86}
       VoidNearPointerType,
       VoidNearCSPointerType,
       VoidNearDSPointerType,
       VoidNearSSPointerType,
       VoidNearESPointerType,
       VoidNearFSPointerType,
       VoidNearGSPointerType,

{$endif x86}
       CUndefinedType,
       CFormalType,               { unique formal definition }
       CTypedFormalType,          { unique typed formal definition }
       VoidType,                  { Void (procedure) }
       CAnsiCharType,             { Char }
       CWideCharType,             { WideChar }
       CCharType,                 { either cansichartype or cwidechartype. Do not free }
       PasBool1Type,              { boolean type }
       PasBool8Type,
       PasBool16Type,
       PasBool32Type,
       PasBool64Type,
       Bool8Type,
       Bool16Type,
       Bool32Type,
       Bool64Type,                { implement me }

       U8IntType,                 { 8-Bit unsigned integer }
       S8IntType,                 { 8-Bit signed integer }
       U16IntType,                { 16-Bit unsigned integer }
       S16IntType,                { 16-Bit signed integer }
       U24IntType,                { 24-Bit unsigned integer }
       S24IntType,                { 24-Bit signed integer }
       U32IntType,                { 32-Bit unsigned integer }
       S32IntType,                { 32-Bit signed integer }
       U40IntType,                { 40-Bit unsigned integer }
       S40IntType,                { 40-Bit signed integer }
       U48IntType,                { 48-Bit unsigned integer }
       S48IntType,                { 48-Bit signed integer }
       U56IntType,                { 56-Bit unsigned integer }
       S56IntType,                { 56-Bit signed integer }
       U64IntType,                { 64-bit unsigned integer }
       S64IntType,                { 64-bit signed integer }
       U128IntType,               { 128-bit unsigned integer }
       S128IntType,               { 128-bit signed integer }
       S32FloatType,              { 32 bit floating point number }
       S64FloatType,              { 64 bit floating point number }
       S80FloatType,              { 80 bit floating point number }
       SC80FloatType,             { 80 bit floating point number but stored like in C }
       S64CurrencyType,           { pointer to a currency type }
       CShortStringType,          { pointer to type of short string const   }
       CLongStringType,           { pointer to type of long string const   }
       CAnsiStringType,           { pointer to type of ansi string const  }
       CWideStringType,           { pointer to type of wide string const  }
       CUnicodeStringType,
       OpenShortStringType,       { pointer to type of an open shortstring,
                                    needed for readln() }
       OpenCharArrayType,         { pointer to type of an open array of char,
                                    needed for readln() }
       CFileType,                 { get the same definition for all file }
                                  { shared file type }
       MethodPointerType,         { typecasting of methodpointers to extract self }
       NestedProcPointerType,     { typecasting of nestedprocpointers to extract parentfp }
       HResultDef,
       TypeKindType,              { def of TTypeKind for correct handling of GetTypeKind parameters }
       { we use only one variant def for every variant class }
       CVariantType,
       COleVariantType,
       { default integer type, normally s32inttype on 32 bit systems and s64bittype on 64 bit systems }
       SIntType,
       UIntType,
       { integer types corresponding to OS_SINT/OS_INT }
       OSSIntType,
       OSUIntType,
       { integer types corresponding to the ALU size, sizeof(aint) and the ALUSInt/ALUUInt types in the system unit }
       ALUSIntType,
       ALUUIntType,
       { integer types corresponding to SizeInt and SizeUInt for the target platform }
       SizeUIntType,
       SizeSIntType,
       { unsigned and signed ord type with the same size as a pointer }
       PtrUIntType,
       PtrSIntType,
       { unsigned and signed ord type with the same size as a codepointer }
       CodePtrUIntType,
       CodePtrSIntType,
       { several types to simulate more or less C++ objects for GDB }
       VMTType,
       VMTArrayType,
       { type of classrefs used for debug information }
       PVMTType,
       { return type of the setjmp function }
       ExceptionReasonType      : TDef;

       { pointer to the ancestor of all classes }
       Class_TObject : TObjectDef;
       { pointer to the base type for custom attributes }
       Class_TCustomAttribute : TObjectDef;
       { pointer to the ancestor of all COM interfaces }
       Interface_IUnknown : TObjectDef;
       { pointer to the ancestor of all dispinterfaces }
       Interface_IDispatch : TObjectDef;
       { pointer to the TGUID type
         of all interfaces         }
       Rec_TGUID : TRecordDef;

       { jump buffer type, used by setjmp }
       Rec_Jmp_Buf : TRecordDef;

       { system.texceptaddr type, used by fpc_pushexceptaddr }
       Rec_ExceptAddr: TRecordDef;

       { Objective-C base types }
       ObjC_MetaClassType,
       ObjC_SuperClassType,
       ObjC_IDType,
       ObjC_SelType              : TPointerDef;
       ObjC_ObjectType           : TRecordDef;
       { base type of @protocol(protocolname) Objective-C statements }
       ObjC_ProtocolType         : TObjectDef;
       { helper types for for-in "fast enumeration" support in Objective-C 2.0 }
       ObjC_FastEnumeration      : TObjectDef;
       ObjC_FastEnumerationState : TRecordDef;



       { x86 vector types }
       X86_M64Type,
       X86_M128Type,
       X86_M128DType,
       X86_M128IType,
       X86_M256Type,
       X86_M256DType,
       X86_M256IType             : TDef;


    function Make_MangledName(const TypePrefix:TSymStr;ST:TSymTable;const Suffix:TSymStr):TSymStr;
    function Make_DLLMangledName(const DLLName,ImportName:TSymStr;
                                 ImportNr : Word; PCo : TProcCallOption):TSymStr;

    { should be in the types unit, but the types unit uses the node stuff :( }
    function Is_InterfaceCOM(Def: TDef): Boolean;
    function Is_InterfaceCOM_Or_DispInterface(Def: TDef): Boolean;
    function Is_Any_Interface_Kind(Def: TDef): Boolean;
    function Is_InterfaceCORBA(Def: TDef): Boolean;
    function Is_Interface(Def: TDef): Boolean;
    function Is_DispInterface(Def: TDef): Boolean;
    function Is_Object(Def: TDef): Boolean;
    function Is_Class(Def: TDef): Boolean;
    function Is_CPPClass(Def: TDef): Boolean;
    function Is_ObjectPascal_Helper(Def: TDef): Boolean;
    function Is_ObjCClass(Def: TDef): Boolean;
    function Is_ObjCClassRef(Def: TDef): Boolean;
    function Is_ObjCProtocol(Def: TDef): Boolean;
    function Is_ObjCCategory(Def: TDef): Boolean;
    function Is_ObjC_Class_Or_Protocol(Def: TDef): Boolean;
    function Is_ObjC_Protocol_Or_Category(Def: TDef): Boolean;
    function Is_ClassHelper(Def: TDef): Boolean;
    function Is_Class_Or_Interface(Def: TDef): Boolean;
    function Is_Class_Or_Interface_Or_ObjC(Def: TDef): Boolean;
    function Is_Class_Or_Interface_Or_DispInterface_Or_ObjC(Def: TDef): Boolean;
    function Is_Class_Or_Interface_Or_Object(Def: TDef): Boolean;
    function Is_Class_Or_Interface_Or_DispInterface(Def: TDef): Boolean;
    function Is_Implicit_Pointer_Object_Type(Def: TDef): Boolean;
    { returns true, if def is a type which is an implicit pointer to an array (dyn. array or dyn. string) }
    function Is_Implicit_Array_Pointer(Def: TDef): Boolean;
    function Is_Class_Or_Object(Def: TDef): Boolean;
    function Is_Record(Def: TDef): Boolean;

    procedure LoadObjCTypes;
    procedure MaybeLoadCocoaTypes;

    function Use_VectorFPU(Def : TDef) : Boolean;

    function GetAnsiStringCodePage:TStringEncoding; inline;
    function GetAnsiStringDef:TStringDef;
    function GetParaEncoding(Def:TDef):TStringEncoding; inline;

    function Get_RecordDef(Prefix:TInternalTypePrefix;const Fields:array of TDef; PackRecords:ShortInt): TRecordDef;
    { get a table def of the form
        record
          count: countdef;
          elements: array[0..count-1] of elementdef
        end;
      Returns both the outer record and the inner arraydef
    }
    procedure Get_TableDef(Prefix:TInternalTypePrefix;CountDef,ElementDef:TDef;Count:LongInt;PackRecords:ShortInt;out RecDef:TRecordDef;out ArrDef:TArrayDef);

    function FileInfo_Of_TypeSym_In_Def(Def:TDef;Sym:TSym;out FilePos:TFilePosInfo):Boolean;
    procedure Reset_All_Default_Types; {housekeeping for Textmode IDE sanity}

implementation

    uses
      SysUtils,
      CUtils,
      { global }
      Verbose,
      { target }
      Systems,ParaMgr,
      { symtable }
      SymSym,SymTable,DefUtil,ObjCDef,
      { parser }
      PGenUtil,
      { module }
      FModule,PPU,
      { other }
      AAsmBase,
      GenDef,
      FPCHash,
      EntFile
      ;

{****************************************************************************
                                  Helpers
****************************************************************************}


    function FileInfo_Of_TypeSym_In_Def(Def:TDef;Sym:TSym;out FilePos:TFilePosInfo):Boolean;
      var
        GST : TGetSymTable;
        ST : TSymTable;
        I : LongInt;
        SRSym : TSym;
      begin
        Result:=False;
        if Sym.Typ<>TypeSym then
          Exit;
        for GST:=Low(TGetSymTable) to High(TGetSymTable) do
          begin
            ST:=Def.GetSymTable(GST);
            if not Assigned(ST) then
              Continue;
            for I:=0 to ST.SymList.Count-1 do
              begin
                SRSym:=TSym(ST.SymList[I]);
                case SRSym.Typ of
                  FieldVarSym,
                  ParaVarSym:
                    if TAbstractVarSym(SRSym).VarDef.TypeSym=Sym then
                      begin
                        FilePos:=SRSym.FileInfo;
                        Result:=True;
                        Break;
                      end;
                  TypeSym:
                    begin
                      Result:=FileInfo_Of_TypeSym_In_Def(TTypeSym(SRSym).TypeDef,Sym,FilePos);
                      if Result then
                        Break;
                    end
                  else
                    ;
                end;
              end;
            if Result then
              Break;
          end;
        { for this we would need the position of the result declaration :/ }
        {if not result and
            (def.typ in [procdef,procvardef]) and
            assigned(tabstractprocdef(def).returndef) and
            (tabstractprocdef(def).returndef.typesym=sym) then
          begin

            result:=true;
          end;}
      end;


    function GetAnsiStringCodePage:TStringEncoding; inline;
      begin
        if ([cs_explicit_codepage,cs_system_codepage]*CurrentSettings.ModuleSwitches)<>[] then
          Result:=CurrentSettings.SourceCodePage
        else
          Result:=0;
      end;

    function GetAnsiStringDef:TStringDef;
      var
        SymTable:TSymTable;
        OldStack : TSymTableStack;
      begin
        { if a codepage is explicitly defined in this mudule we need to return
          a replacement for ansistring def }
        if ([cs_explicit_codepage,cs_system_codepage]*CurrentSettings.ModuleSwitches)<>[] then
          begin
            if not Assigned(CurrentModule) then
              InternalError(2011101301);
            { codepage can be redeclared only once per unit so we don't need a list of
              redefined ansistring but only one pointer }
            if not Assigned(CurrentModule.AnsiStrDef) then
              begin
                { if we did not create it yet we need to do this now }
                if CurrentModule.InInterface then
                  SymTable:=CurrentModule.GlobalSymTable
                else
                  SymTable:=CurrentModule.LocalSymTable;
                { create a temporary stack as it's not good (TM) to mess around
                  with the order if the unit contains generics or helpers; don't
                  use a def aware symtablestack though }
                OldStack:=SymTableStack;
                SymTableStack:=TSymTableStack.Create;
                SymTableStack.Push(SymTable);
                CurrentModule.AnsiStrDef:=CStringDef.CreateAnsi(CurrentSettings.SourceCodePage,True);
                SymTableStack.Pop(SymTable);
                SymTableStack.Free;
                SymTableStack:=OldStack;
              end;
            Result:=TStringDef(CurrentModule.AnsiStrDef);
          end
        else
          Result:=TStringDef(CAnsiStringType);
      end;

    function GetParaEncoding(Def:TDef):TStringEncoding; inline;
      begin
        { don't pass CP_NONE encoding to internal functions
          they expect 0 encoding instead
          exception: result of string concatenation, because if you pass the
          result of a string concatenation to a rawbytestring, the result of
          that concatenation shouldn't be converted to defaultsystemcodepage
          if all strings have the same type }
        Result:=TStringDef(Def).Encoding;
        if Result=Globals.CP_NONE then
          Result:=0
      end;


    function Get_RecordDef(Prefix:TInternalTypePrefix; const Fields:array of TDef; PackRecords:ShortInt): TRecordDef;
      var
        FieldList: TFPList;
        SRSym: TSym;
        SRSymTable: TSymTable;
        I: LongInt;
        Name : TIDString;
      begin
        Name:=Copy(InternaltypeprefixName[Prefix],2,Length(InternaltypeprefixName[Prefix]));
        if SearchSym_Type(Name,SRSym,SRSymTable) then
          begin
            Result:=TRecordDef(TTypeSym(SRSym).TypeDef);
            Exit
          end;
        { also always search in the current module (symtables are popped for
          RTTI related code already) }
        if SearchSym_In_Module(Pointer(CurrentModule),Name,SRSym,SRSymTable) then
          begin
            Result:=TRecordDef(TTypeSym(SRSym).TypeDef);
            Exit;
          end;
        FieldList:=TFPList.Create;
        for I:=Low(Fields) to High(Fields) do
          FieldList.Add(Fields[I]);
        Result:=CRecordDef.Create_Global_Internal(InternaltypeprefixName[Prefix],PackRecords,
          TargetInfos[Ord(TargetInfo.System)]^.Alignment.RecordAlignMin);
        Result.Add_Fields_From_DefList(FieldList);
        FieldList.Free;
        FieldList := nil;
      end;


    procedure Get_TableDef(Prefix:TInternalTypePrefix;CountDef,ElementDef:TDef;Count:LongInt;PackRecords:ShortInt;out RecDef:TRecordDef;out ArrDef:TArrayDef);
      var
        Fields: TFPList;
        Name: TIDString;
        SRSym: TSym;
        FieldVarSym: TFieldVarSym;
        SRSymTable: TSymTable;
      begin
        { already created a message string table with this number of elements
          in this unit -> reuse the def }
        Name:=InternaltypeprefixName[Prefix]+ToStr(Count);
        if SearchSym_Type(Copy(Name,2,Length(Name)),SRSym,SRSymTable) then
          begin
            RecDef:=TRecordDef(TTypeSym(SRSym).TypeDef);
            FieldVarSym:=TRecordSymTable(RecDef.SymTable).FindFieldByOffset(CountDef.Size);
            if FieldVarSym<>nil then
              ArrDef:=TArrayDef(FieldVarSym.VarDef)
            else
              ArrDef:=nil;
            Exit
          end;
        { also always search in the current module (symtables are popped for
          RTTI related code already) }
        if SearchSym_In_Module(Pointer(CurrentModule),Copy(Name,2,Length(Name)),SRSym,SRSymTable) then
          begin
            RecDef:=TRecordDef(TTypeSym(SRSym).TypeDef);
            FieldVarSym:=TRecordSymTable(RecDef.SymTable).FindFieldByOffset(CountDef.Size);
            if FieldVarSym<>nil then
              ArrDef:=TArrayDef(FieldVarSym.VarDef)
            else
              ArrDef:=nil;
            Exit;
          end;
        RecDef:=CRecordDef.Create_Global_Internal(Name,PackRecords,
          TargetInfos[Ord(TargetInfo.System)]^.Alignment.RecordAlignMin);
        Fields:=TFPList.Create;
        Fields.Add(CountDef);
        if Count>0 then
          begin
            ArrDef:=CArrayDef.Create(0,Count-1,SizeUIntType);
            ArrDef.ElementDef:=ElementDef;
            Fields.Add(ArrDef);
          end
        else
          ArrDef:=nil;
        RecDef.Add_Fields_From_DefList(Fields);
        Fields.Free;
        Fields := nil;
      end;

    function Make_MangledName(const TypePrefix:TSymStr;ST:TSymTable;const Suffix:TSymStr):TSymStr;
      var
        S,
        Prefix : TSymStr;
        Hash : QWord;
      begin
        Prefix:='';
        if not Assigned(ST) then
         InternalError(200204212);
        repeat
          { sub procedures }
          while (ST.SymTableType in [LocalSymTable,ParaSymTable]) do
           begin
             if ST.DefOwner.Typ<>ProcDef then
              InternalError(200204173);
             { Add the full mangledname of the routine to prevent
               conflicts with two overloads both having a local entity
               -- routine (tb0314), class, interface -- with the same name }
             S:=TProcDef(ST.DefOwner).ProcSym.Name;
             S:=S+TProcDef(ST.DefOwner).MangledProcParaNames(Length(S));
             if Prefix<>'' then
               begin
                 if Length(Prefix)>(MaxIDLen-Length(S)-1) then
                   begin
                     Hash:=InitFNV64;
                     Hash:=UpdateFNV64(Hash,Prefix[1],Length(Prefix));
                     Prefix:='$H'+Base64Mangle(Hash);
                   end;
                 Prefix:=S+'_'+Prefix
               end
             else
               Prefix:=S;
             ST:=ST.DefOwner.Owner;
           end;
          { object/classes symtable, nested type definitions in classes require the while loop }
          while ST.SymTableType in [ObjectSymTable,RecordSymTable] do
           begin
             if not (ST.DefOwner.Typ in [ObjectDef,RecordDef]) then
              InternalError(200204174);
             if Length(Prefix)>(MaxIDLen-Length(TAbstractRecordDef(ST.DefOwner).ObjName^)-3) then
               begin
                 Hash:=InitFNV64;
                 Hash:=UpdateFNV64(Hash,Prefix[1],Length(Prefix));
                 Prefix:='$H'+Base64Mangle(Hash);
               end;
             Prefix:=TAbstractRecordDef(ST.DefOwner).ObjName^+'_$_'+Prefix;
             ST:=ST.DefOwner.Owner;
           end;
          { local classes & interfaces are possible (because of closures)
            or parasymtable for this case:
             class function Trace<TResult>(const Func: TFunc<TLogToken, TResult>): TResult;
          }
          if not (ST.SymTableType in [LocalSymTable,ParaSymTable]) then
            Break;
          Prefix:='$'+Prefix;
        until False;
        { symtable must now be static or global }
        if not(ST.SymTableType in [StaticSymTable,GlobalSymTable]) then
          InternalError(200204175);

        { The mangled name is made out of at most 4 parts:
         1) Optional typeprefix given as first parameter
            with '_$' appended if not empty
         2) Unit name or 'P$'+program name (never empty)
         3) optional prefix variable that contains a unique
            name for the local symbol table (prepended with '$_$'
            if not empty)
         4) suffix as given as third parameter,
            also optional (i.e. can be empty)
            prepended by '_$$_' if not empty }
        Result:='';
        if TypePrefix<>'' then
          Result:=Result+TypePrefix+'_$';
        { Add P$ for program, which can have the same name as
          a unit }
        if (TSymTable(Main_Module.LocalSymTable)=ST) and
           (not Main_Module.IsUnit) then
          Result:=Result+'P$'+ST.Name^
        else
          Result:=Result+ST.Name^;
        if Prefix<>'' then
          Result:=Result+'$_$'+Prefix;
        if Suffix<>'' then
          Result:=Result+'_$$_'+Suffix;
        if Length(Result)>(MaxIDLen-1) then
          begin
            Hash:=InitFNV64;
            Hash:=UpdateFNV64(Hash,Result[1],Length(Result));
            Result:=Copy(Result,1,MaxIDLen-(High(Base64OfUInt64String)-Low(Base64OfUInt64String)+1)-2)+'$H'+Base64Mangle(Hash);
          end;
        { the Darwin assembler assumes that all symbols starting with 'L' are local }
        { Further, the Mac OS X 10.5 linker does not consider symbols which do not  }
        { start with '_' as regular symbols (it does not generate N_GSYM entries    }
        { those in the debug map, leading to troubles with dsymutil). So always     }
        { add an underscore on darwin.                                              }
        { LLVM's i386 COFF assembler also treats names beginning with 'L' as
          local; prefix Pascal-mangled names when using Clang for Win32. }
        if (TargetInfo.System in systems_darwin) or
           ((TargetInfo.System=system_i386_win32) and
            (TargetAsm.ID=as_clang_gas)) then
          Result := '_' + Result;
      end;

    function Make_DLLMangledName(const DLLName,ImportName:TSymStr;ImportNr : Word; PCo : TProcCallOption):TSymStr;
       var
         CRC : Cardinal;
         I : LongInt;
         UseCRC : Boolean;
         DLLPrefix : TSymStr;
      begin
        if (TargetInfo.System in systems_all_windows)
            and (DLLName <> '') then
          begin
            DLLPrefix:=Lower(ExtractFileName(DLLName));
            { Remove .dll suffix if present }
            if Copy(DLLPrefix,Length(DLLPrefix)-3,Length(DLLPrefix))='.dll' then
              DLLPrefix:=Copy(DLLPrefix,1,Length(DLLPrefix)-4);
            UseCRC:=False;
            for I:=1 to Length(DLLPrefix) do
              if not (DLLPrefix[I] in ['a'..'z','A'..'Z','_','0'..'9']) then
                begin
                  UseCRC:=True;
                  Break;
                end;
            if UseCRC then
              begin
                CRC:=0;
                CRC:=UpdateCRC32(CRC,DLLPrefix[1],Length(DLLPrefix));
                DLLPrefix:='_$dll$crc$'+HexStr(CRC,8)+'$';
              end
            else
              DLLPrefix:='_$dll$'+DLLPrefix+'$';

            if ImportName<>'' then
              Result:=DLLPrefix+ImportName
            else
              Result:=DLLPrefix+'_index_'+ToStr(ImportNr);
            { Replace ? and @ in import name, since GNU AS does not allow these characters in symbol names. }
            { This allows to import VC++ mangled names from DLLs. }
            { Do not perform replacement, if external symbol is not imported from DLL. }
            if (DLLName<>'') then
              begin
                Replace(Result,'?','__q$$');
             end;
          end
        else
          begin
            if ImportName<>'' then
             begin
               if not(PCo in [pocall_cdecl,pocall_cppdecl]) then
                 Result:=ImportName
               else
                 Result:=TargetInfo.Cprefix+ImportName;
             end
            else
              Result:='_index_'+ToStr(ImportNr);
          end;

      end;

{****************************************************************************
           TDEFAWARESYMTABLESTACK
           (symtablestack descendant that does some special actions on
           the pushed/popped symtables)
****************************************************************************}

    procedure TDefAwareSymTableStack.AddHelpersAndGenerics(ST:TSymTable;AddGenerics:Boolean);
      var
        S: TSymStr;
        List: TFPObjectList;
        Def: TDef;
        Sym : TSym;
        I: Integer;
      begin
        { search the symtable from first to last; the helper to use will be the
          last one in the list }
        for I:=0 to ST.SymList.Count-1 do
          begin
            Sym:=TSym(ST.SymList[I]);
            if not (Sym.Typ in [TypeSym,ProcSym]) then
              Continue;
            if Sym.Typ=TypeSym then
              Def:=TTypeSym(ST.SymList[I]).TypeDef
            else
              Def:=nil;
            if Is_ObjectPascal_Helper(Def) then
              begin
                S:=Generate_ObjectPascal_Helper_Key(TObjectDef(Def).ExtendedDef);
                Message1(sym_d_adding_helper_for,S);
                List:=TFPObjectList(CurrentModule.ExtendedDefs.Find(S));
                if not Assigned(List) then
                  begin
                    List:=TFPObjectList.Create(False);
                    CurrentModule.ExtendedDefs.Add(S,List);
                  end;
                List.Add(Def);
              end
            else
              begin
                if AddGenerics then
                  add_generic_dummysym(Sym,'');
                { add nested helpers as well }
                if Assigned(Def) and
                    (Def.Typ in [RecordDef,ObjectDef]) and
                    (sto_has_helper in TAbstractRecordDef(Def).SymTable.TableOptions) and
                    not Is_Owned_By(Def,TDef(ST.DefOwner)) then
                  AddHelpersAndGenerics(TAbstractRecordDef(Def).SymTable,False);
              end;
          end;
      end;


    procedure TDefAwareSymTableStack.RemoveHelpersAndGenerics(ST:TSymTable);
      begin
        if sto_has_helper in ST.TableOptions then
          RemoveHelpers(ST);
        if sto_has_generic in ST.TableOptions then
          RemoveGenerics(ST);
      end;


    procedure TDefAwareSymTableStack.RemoveHelpers(ST:TSymTable);
      var
        I, J: Integer;
        TmpST: TSymTable;
        List: TFPObjectList;
      begin
        for I:=CurrentModule.ExtendedDefs.Count-1 downto 0 do
          begin
            List:=TFPObjectList(CurrentModule.ExtendedDefs[I]);
            for J:=List.Count-1 downto 0 do
              begin
                if not (List[J] is TObjectDef) then
                  InternalError(2011031501);
                TmpST:=TObjectDef(List[J]).Owner;
                repeat
                  if TmpST=ST then
                    begin
                      List.Delete(J);
                      Break;
                    end
                  else
                    begin
                      if Assigned(TmpST.DefOwner) then
                        TmpST:=TmpST.DefOwner.Owner
                      else
                        TmpST:=nil;
                    end;
                until not Assigned(TmpST) or (TmpST.SymTableType in [GlobalSymTable,StaticSymTable]);
              end;
            if List.Count=0 then
              CurrentModule.ExtendedDefs.Delete(I);
          end;
      end;


    procedure TDefAwareSymTableStack.RemoveGenerics(ST:TSymTable);
      var
        I,J : LongInt;
        Entry : TGenericDummyEntry;
        List : TFPObjectList;
      begin
        for I:=CurrentModule.GenericDummySyms.Count-1 downto 0 do
          begin
            List:=TFPObjectList(CurrentModule.GenericDummySyms[I]);
            if not Assigned(List) then
              Continue;
            for J:=List.Count-1 downto 0 do
              begin
                Entry:=TGenericDummyEntry(List[J]);
                if Entry.DummySym.Owner=ST then
                  List.Delete(J);
              end;
            if List.Count=0 then
              CurrentModule.GenericDummySyms.Delete(I);
          end;
      end;


    procedure TDefAwareSymTableStack.PushCommon(ST:TSymTable);
      begin
        if (sto_has_generic in ST.TableOptions) or
            (
              (ST.SymTableType in [GlobalSymTable,StaticSymTable]) and
              (sto_has_helper in ST.TableOptions)
            ) then
          { nested helpers will be added as well }
          AddHelpersAndGenerics(ST,True);
      end;

    procedure TDefAwareSymTableStack.Push(ST: TSymTable);
      begin
        PushCommon(ST);
        inherited Push(ST);
      end;

    procedure TDefAwareSymTableStack.PushAfter(ST,AfterST:TSymTable);
      begin
        PushCommon(ST);
        inherited PushAfter(ST,AfterST);
      end;

    procedure TDefAwareSymTableStack.Pop(ST: TSymTable);
      begin
        inherited Pop(ST);
        if (sto_has_generic in ST.TableOptions) or
            (
              (ST.SymTableType in [GlobalSymTable,StaticSymTable]) and
              (sto_has_helper in ST.TableOptions)
            ) then
          { nested helpers will be removed as well }
          RemoveHelpersAndGenerics(ST);
      end;


{****************************************************************************
                     TDEF (base class for definitions)
****************************************************************************}

    constructor TGenericConstraintData.Create;
      begin
        Interfaces:=TFPObjectList.Create(False);
        InterfacesDeref:=TFPList.Create;
      end;


    destructor TGenericConstraintData.Destroy;
      begin
        TFPList.FreeAndNilDisposing(InterfacesDeref,TypeInfo(TDeref));
        Interfaces.Free;
        Interfaces := nil;
        inherited Destroy;
      end;

    procedure TGenericConstraintData.PPULoad(PPUFile: TCompilerPPUFile);
      var
        Cnt,I : LongInt;
        IntfDeref : PDeref;
      begin
        PPUFile.GetSet(TPPUSet1(Flags));
        Cnt:=PPUFile.GetLongInt;
        for I:=0 to Cnt-1 do
          begin
            New(IntfDeref);
            PPUFile.GetDeref(IntfDeref^);
            InterfacesDeref.Add(IntfDeref);
          end;
      end;


    procedure TGenericConstraintData.PPUWrite(PPUFile: TCompilerPPUFile);
      var
        I : LongInt;
      begin
        PPUFile.PutSet(TPPUSet1(Flags));
        PPUFile.PutLongInt(InterfacesDeref.Count);
        for I:=0 to InterfacesDeref.Count-1 do
          PPUFile.PutDeref(PDeref(InterfacesDeref[I])^);
      end;

    procedure TGenericConstraintData.BuildDeref;
      var
        IntfDeref : PDeref;
        I : LongInt;
      begin
        InterfacesDeref.Capacity:=InterfacesDeref.Count+Interfaces.Count;
        for I:=0 to Interfaces.Count-1 do
          begin
            New(IntfDeref);
            IntfDeref^.Build(TObjectDef(Interfaces[I]));
            InterfacesDeref.Add(IntfDeref);
          end;
      end;

    procedure TGenericConstraintData.Deref;
      var
        I : LongInt;
      begin
        Interfaces.Capacity:=Interfaces.Count+InterfacesDeref.Count;
        for I:=0 to InterfacesDeref.Count-1 do
          Interfaces.Add(PDeref(InterfacesDeref[I])^.Resolve);
      end;


    procedure TStoredDef.WriteEntry(PPUFile: TCompilerPPUFile; IBNR: Byte);
      begin
        PPUWritePlatform(PPUFile);
        PPUFile.WriteEntry(IBNR);
      end;


    procedure TStoredDef.PPUWritePlatform(PPUFile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    procedure TStoredDef.PPULoadPlatform(PPUFile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    class procedure TStoredDef.SetupReusableDef(OrigDef, NewDef: TDef; Res: PHashSetItem; OldSymTableStack: TSymTableStack);
      var
        ReusableSymTab: TSymTable;
      begin
        { must not yet belong to a symtable }
        if Assigned(NewDef.Owner) then
          InternalError(2015111503);
        ReusableSymTab:=OrigDef.GetReusableSymTab;
        Res^.Data:=NewDef;
        ReusableSymTab.InsertDef(NewDef);
        SymTableStack:=OldSymTableStack;
      end;


    constructor TStoredDef.Create(DT:TDefTyp;DoRegister:Boolean);
      begin
         inherited Create(DT);
         SaveSize := 0;
{$ifdef EXTDEBUG}
         FileInfo := CurrentFilePos;
{$endif}
         GenericTokenBuf:=nil;
         GenericDef:=nil;
         TypeSymDeref.Reset;
         GenericDefDeref.Reset;

         { Don't register forwarddefs, they are disposed at the
           end of an type block }
         if (DT=ForwardDef) then
           Exit;
         { Register in symtable stack }
         if DoRegister then
           begin
             { immediately register interface defs, as they will always be
               written to the ppu, their defid influences the interface crc and
               if we wait, depending on e.g. compiler defines they may get a
               different defid (e.g. when a function is called, its procdef is
               registered, so depending on whether or not, or when, an interface
               procedure is called in the implementation, that may change its
               defid otherwise) }
             if Assigned(CurrentModule) and
                CurrentModule.InInterface then
               RegisterDef
             else
               Maybe_Put_In_SymTable_Stack;
           end;
      end;


    destructor TStoredDef.Destroy;
      begin
        { Direct calls are not allowed, use symtable.deletedef() }
        if Assigned(Owner) then
          InternalError(200612311);
        if Assigned(GenericTokenBuf) then
          begin
            GenericTokenBuf.Free;
            GenericTokenBuf:=nil;
          end;
        RTTIAttributeList.Free;
        RTTIAttributeList := nil;
        GenericParas.Free;
        GenericParas := nil;
        TFPList.FreeAndNilDisposing(GenericParaDerefs,TypeInfo(TDeref));
        GenConstraintData.Free;
        GenConstraintData := nil;
{$ifndef symansistr}
        StringDispose(FFullOwnerHierarchyName);
{$endif not symansistr}
        inherited Destroy;
      end;


    constructor TStoredDef.PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
      var
        SizeLeft,I,Cnt : LongInt;
        Buf  : array[0..255] of Byte;
        SymDeref : PDeref;
      begin
         inherited Create(DT);
         DefID:=PPUFile.GetLongInt;
         CurrentModule.DefList[DefID]:=Self;
{$ifdef EXTDEBUG}
         FillChar(FileInfo,SizeOf(FileInfo),0);
{$endif}
         { load }
         PPUFile.GetDeref(TypeSymDeref);
         PPUFile.GetSet(TPPUSet2(DefOptions));
         PPUFile.GetSet(TPPUSet1(DefStates));
         if df_unique in DefOptions then
           PPUFile.GetDeref(OrgDefDeref);
         if df_genconstraint in DefOptions then
           begin
             GenConstraintData:=TGenericConstraintData.Create;
             GenConstraintData.PPULoad(PPUFile);
           end;
         if [df_generic,df_specialization]*DefOptions<>[] then
           begin
             Cnt:=PPUFile.GetLongInt;
             if Cnt>0 then
               begin
                 GenericParas:=TFPHashObjectList.Create(False);
                 GenericParaDerefs:=TFPList.Create;
                 for I:=0 to Cnt-1 do
                   begin
                     GenericParas.Add(PPUFile.GetString,nil);
                     New(SymDeref);
                     PPUFile.GetDeref(SymDeref^);
                     GenericParaDerefs.Add(SymDeref);
                   end;
               end;
           end;
         if df_generic in DefOptions then
           begin
             SizeLeft:=PPUFile.GetLongInt;
             InitGeneric;
             while SizeLeft>0 do
               begin
                 if SizeLeft>SizeOf(Buf) then
                   I:=SizeOf(Buf)
                 else
                   I:=SizeLeft;
                 PPUFile.GetData(Buf,I);
                 GenericTokenBuf.write(Buf,I);
                 Dec(SizeLeft,I);
               end;
           end;
        if df_specialization in DefOptions then
          PPUFile.GetDeref(GenericDefDeref);
        RTTIAttributeList:=TRTTIAttributeList.PPULoad(PPUFile);
      end;


    function TStoredDef.NeedsSeparateInitRTTI:Boolean;
      begin
        Result:=False;
      end;


    function TStoredDef.RTTIMangledName(RT : TRTTIType) : TSymStr;
      var
        Prefix : string[4];
      begin
        if (RT=FullRTTI) or (not NeedsSeparateInitRTTI) then
          begin
            Prefix:='RTTI';
            Include(DefStates,ds_rtti_table_used);
          end
        else
          begin
            Prefix:='INIT';
            Include(DefStates,ds_init_table_used);
          end;
        if Assigned(TypeSym) and
           (Owner.SymTableType in [StaticSymTable,GlobalSymTable]) then
          Result:=Make_MangledName(Prefix,TypeSym.Owner,TypeSym.Name)
        else
          Result:=Make_MangledName(Prefix,FindUnitSymTable(Owner),'def'+UniqueIDStr)
      end;


    function TStoredDef.OwnerHierarchyName: string;
      var
        Tmp: TDef;
      begin
        Tmp:=Self;
        Result:='';
        repeat
          { can be not assigned in case of a forwarddef }
          if Assigned(Tmp.Owner) and
             (Tmp.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
            Tmp:=TDef(Tmp.Owner.DefOwner)
          else
            Break;
          Result:=TAbstractRecordDef(Tmp).ObjRealName^+'.'+Result;
        until Tmp=nil;
      end;


    function TStoredDef.OwnerHierarchyPrettyName: string;
      var
        Tmp: TDef;
      begin
        Tmp:=Self;
        Result:='';
        repeat
          { can be not assigned in case of a forwarddef }
          if Assigned(Tmp.Owner) and
             (Tmp.Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
            Tmp:=TDef(Tmp.Owner.DefOwner)
          else
            Break;
          Result:=TAbstractRecordDef(Tmp).TypeSymbolPrettyName+'.'+Result;
        until Tmp=nil;
      end;


    function TStoredDef.FullOwnerHierarchyName(SkipProcParams:Boolean; UsePretty : Boolean): TSymStr;
      var
        LastOwner: TSymTable;
        Tmp: TDef;
        PNo: TProcNameOptions;
      begin
{$ifdef symansistr}
        if not SkipProcParams and (FFullOwnerHierarchyName<>'') then
          Exit(FFullOwnerHierarchyName);
{$else symansistr}
        if not SkipProcParams and Assigned(FFullOwnerHierarchyName) then
          Exit(FFullOwnerHierarchyName^);
{$endif symansistr}
        { the def can only reside inside structured types or
          procedures/functions/methods }
        Tmp:=Self;
        Result:='';
        repeat
          LastOwner:=Tmp.Owner;
          { can be not assigned in case of a forwarddef }
          if not Assigned(LastOwner) then
            Break
          else
            Tmp:=TDef(LastOwner.DefOwner);
          if not Assigned(Tmp) then
            Break;
          if Tmp.Typ in [RecordDef,ObjectDef] then
            begin
              if UsePretty then
                Result:=TAbstractRecordDef(Tmp).TypeSymbolPrettyName+'.'+Result
              else
                Result:=TAbstractRecordDef(Tmp).ObjRealName^+'.'+Result;
            end
          else
            if Tmp.Typ=ProcDef then
              begin
                PNo:=[pno_paranames,pno_proctypeoption];
                if SkipProcParams then
                  Include(PNo,pno_noparams);
                Result:=TProcDef(Tmp).CustomProcName(PNo)+'.'+Result;
              end;
        until Tmp=nil;
        { add the unit name }
        if Assigned(LastOwner) and
           Assigned(LastOwner.RealName) then
          Result:=LastOwner.RealName^+'.'+Result;
        if not SkipProcParams then
          { don't store the name in this case }
{$ifdef symansistr}
          FFullOwnerHierarchyName:=Result;
{$else symansistr}
          FFullOwnerHierarchyName:=StringDup(Result);
{$endif symansistr}
      end;


    function TStoredDef.In_CurrentUnit: Boolean;
      var
        ST: TSymTable;
      begin
        ST:=Owner;
        while not(ST.SymTableType in [GlobalSymTable,StaticSymTable]) do
          ST:=ST.DefOwner.Owner;
        Result:=ST.IsCurrentUnit;
      end;


    function TStoredDef.GetCopy : TStoredDef;
      begin
        Message(sym_e_cant_create_unique_type);
        GetCopy:=CErrorDef.Create;
      end;


    procedure TStoredDef.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        SizeLeft,I : LongInt;
        Buf  : array[0..255] of Byte;
        OldIntfCRC : Boolean;
      begin
        if DefID<0 then
          InternalError(2015101401);
        PPUFile.PutLongInt(DefID);
        PPUFile.PutDeref(TypeSymDeref);
        PPUFile.PutSet(TPPUSet2(DefOptions));
        OldIntfCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
        PPUFile.PutSet(TPPUSet1(DefStates));
        if df_unique in DefOptions then
          PPUFile.PutDeref(OrgDefDeref);
        if df_genconstraint in DefOptions then
          GenConstraintData.PPUWrite(PPUFile);
        if [df_generic,df_specialization]*DefOptions<>[] then
          begin
            if not Assigned(GenericParas) then
              PPUFile.PutLongInt(0)
            else
              begin
                if not Assigned(GenericParaDerefs) then
                  InternalError(2014052305);
                PPUFile.PutLongInt(GenericParas.Count);
                for I:=0 to GenericParas.Count-1 do
                  begin
                    PPUFile.PutString(GenericParas.NameOfIndex(I));
                    PPUFile.PutDeref(PDeref(GenericParaDerefs[I])^);
                  end;
              end;
          end;
        if df_generic in DefOptions then
          begin
            { crc generic implementation }
            PPUFile.DoCRC:=True;
            if Assigned(GenericTokenBuf) then
              begin
                SizeLeft:=GenericTokenBuf.Size;
                GenericTokenBuf.Seek(0);
              end
            else
              SizeLeft:=0;
            PPUFile.PutLongInt(SizeLeft);
            while SizeLeft>0 do
              begin
                if SizeLeft>SizeOf(Buf) then
                  I:=SizeOf(Buf)
                else
                  I:=SizeLeft;
                GenericTokenBuf.read(Buf,I);
                PPUFile.PutData(Buf,I);
                Dec(SizeLeft,I);
              end;
          end;
        PPUFile.DoCRC:=OldIntfCRC;
        if df_specialization in DefOptions then
          PPUFile.PutDeref(GenericDefDeref);
        TRTTIAttributeList.PPUWrite(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredDef.PPULoadSubEntries(PPUFile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPULoadSubEntries(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredDef.PPUWriteSubEntries(PPUFile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPUWriteSubEntries(RTTIAttributeList,PPUFile);
      end;


    procedure TStoredDef.BuildDeref;
      var
        I : LongInt;
        Sym : TSym;
        SymDeref : PDeref;
      begin
        if not Registered then
          RegisterDef;
        TypeSymDeref.Build(TypeSym);
        OrgDefDeref.Build(OrgDef);
        GenericDefDeref.Build(GenericDef);
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.BuildDeref;
        if Assigned(GenConstraintData) then
          GenConstraintData.BuildDeref;
        if Assigned(GenericParas) then
          begin
           { buildderef may be called more than once (getppucrc is called at
             end-of-interface and again at end-of-implementation; system units
             also call buildderef a second time from writeppu). Clear any
             previously accumulated entries so that genericparaderefs.count
             stays equal to genericparas.count and does not trigger
             internalerror 2014052303 in deref. }
           if Assigned(GenericParaDerefs) then
             begin
               for I:=0 to GenericParaDerefs.Count-1 do
                 Dispose(PDeref(GenericParaDerefs[I]));
               GenericParaDerefs.Clear;
             end
           else
             GenericParaDerefs:=TFPList.Create;
           GenericParaDerefs.Capacity:=GenericParas.Count;
            for I:=0 to GenericParas.Count-1 do
              begin
                Sym:=TSym(GenericParas.Items[I]);
                New(SymDeref);
                SymDeref^.Build(Sym);
                GenericParaDerefs.Add(SymDeref);
              end;
          end;
      end;


    procedure TStoredDef.BuildDerefImpl;
      begin
      end;


    procedure TStoredDef.Deref;
      var
        SymDeref : PDeref;
        I : LongInt;
      begin
        TypeSym:=TTypeSym(TypeSymDeref.Resolve);
        if df_unique in DefOptions then
          OrgDef:=TStoredDef(OrgDefDeref.Resolve);
        if df_specialization in DefOptions then
          GenericDef:=TStoredDef(GenericDefDeref.Resolve);
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.Deref;
        if Assigned(GenConstraintData) then
          GenConstraintData.Deref;
        if Assigned(GenericParas) then
          begin
            if not Assigned(GenericParaDerefs) then
              InternalError(2014052302);
            if GenericParas.Count<>GenericParaDerefs.Count then
              InternalError(2014052303);
            for I:=0 to GenericParaDerefs.Count-1 do
              begin
                SymDeref:=PDeref(GenericParaDerefs[I]);
                GenericParas.Items[I]:=SymDeref^.Resolve;
              end;
          end;
      end;


    procedure TStoredDef.DerefImpl;
      begin
      end;


    function TStoredDef.Size : ASizeInt;
      begin
         Size:=SaveSize;
      end;


    function TStoredDef.GetVarDef:LongInt;
      begin
        Result:=VarUndefined;
      end;


    function TStoredDef.Alignment : ShortInt;
      begin
         { natural alignment by default }
         Alignment:=Size_2_Align(SaveSize);
         { can happen if savesize = 0, e.g. for voiddef or
           an empty record
         }
         if (Alignment=0) then
           Alignment:=1;
      end;


    { returns true, if the definition can be published }
    function TStoredDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_error;
      end;


    { needs an init table }
    function TStoredDef.NeedsInitTable : Boolean;
      begin
         NeedsInitTable:=False;
      end;


    function TStoredDef.HasNonTrivialInitChild(CheckParent:Boolean):Boolean;
      begin
        Result:=False;
      end;


   function TStoredDef.Is_IntRegable : Boolean;
{$ifndef cpuhighleveltarget}
     var
       RecSize,Temp: LongInt;
{$endif cpuhighleveltarget}
     begin
        case Typ of
          OrdDef,
          PointerDef,
          EnumDef,
          ClassRefDef:
            Is_IntRegable:=True;
          ProcVarDef :
            Is_IntRegable:=TProcVarDef(Self).Is_AddressOnly or (po_methodpointer in TProcVarDef(Self).ProcOptions);
          ObjectDef:
            Is_IntRegable:=(Is_Implicit_Pointer_Object_Type(Self)) and not NeedsInitTable;
          SetDef:
            Is_IntRegable:=is_smallset(Self);
          ArrayDef:
{$ifdef cpuhighleveltarget}
            Is_IntRegable:=False
{$else cpuhighleveltarget}
            Is_IntRegable:=not(is_special_array(Self)) and
              (TArrayDef(Self).Size<=8) and (TArrayDef(Self).Size in [1,2,4,8]) and
              TStoredDef(TArrayDef(Self).ElementDef).Is_IntRegable
{$ifdef SUPPORT_MMX}
              and not((cs_mmx in CurrentSettings.LocalSwitches) and
                 is_mmx_able_array(Self))
{$endif SUPPORT_MMX}
{$endif cpuhighleveltarget}
              ;
          RecordDef:
            begin
{$ifdef cpuhighleveltarget}
              Is_IntRegable:=False;
{$else cpuhighleveltarget}
              RecSize:=Size;
              Is_IntRegable:=
                IsPowerOf2(RecSize,Temp) and
                ((RecSize<=SizeOf(AInt)*2) and
                 not TRecordDef(Self).Contains_Cross_AWord_Field and
                 { records cannot go into registers on 16 bit targets for now }
                 (SizeOf(AInt)>2) and
                 not TRecordDef(Self).Contains_Float_Field
                ) and
                not NeedsInitTable;
{$endif cpuhighleveltarget}
            end;
          else
           Is_IntRegable:=False;
        end;
     end;


   function TStoredDef.Is_FPURegable : Boolean;
     begin
{$ifdef x86}
       Result:=Use_VectorFPU(Self);
{$else x86}
       Result:=(Typ=FloatDef)
         ;
{$endif x86}
     end;


   function TStoredDef.Is_Const_IntRegable : Boolean;
     begin
       case Typ of
         StringDef:
           Result:=TStringDef(Self).StringType in [st_ansistring,st_unicodestring,st_widestring];
         ArrayDef:
           Result:=is_dynamic_array(Self);
         ObjectDef:
           Result:=Is_Interface(Self);
         else
           Result:=False;
       end;
     end;


   procedure TStoredDef.InitGeneric;
     begin
       if Assigned(GenericTokenBuf) then
         InternalError(200512131);
       GenericTokenBuf:=TDynamicArray.Create(256);
     end;


   function TStoredDef.Is_Generic: Boolean;
     var
       Sym: TSym;
       I: LongInt;
     begin
       Result:=Assigned(GenericParas) and
                 (GenericParas.Count>0) and
                 (df_generic in DefOptions);
       if Result then
         { if any of the type parameters does *not* belong to us (meaning it was passed
           in from outside) then we aren't a generic, but a specialization }
         for I:=0 to GenericParas.Count-1 do
           begin
             Sym:=TSym(GenericParas[I]);
             { sym must be either a type or const }
             if not (Sym.Typ in [SymConst.TypeSym,SymConst.ConstSym]) then
               InternalError(2014050903);
             if (Sym.Owner.DefOwner<>Self) or (sp_generic_unnamed_type in Sym.SymOptions) then
               Exit(False);
             if (Sym.Typ=SymConst.ConstSym) and (sp_generic_const in Sym.SymOptions) then
               Exit(False);
           end;
     end;


   function TStoredDef.Is_Generic_Param_Const(Index:Integer):Boolean;
     begin
       Result:=TSym(GenericParas[Index]).Typ=ConstSym;
     end;


   function TStoredDef.Get_Generic_Param_Def(Index:Integer):TDef;
     begin
       if TSym(GenericParas[Index]).Typ=ConstSym then
         Result:=TConstSym(GenericParas[Index]).ConstDef
       else
         Result:=TTypeSym(GenericParas[Index]).TypeDef;
     end;


   function TStoredDef.Is_Specialization: Boolean;
     var
       I : LongInt;
       Sym : TSym;
     begin
       Result:=Assigned(GenericParas) and
                 (GenericParas.Count>0) and
                 (df_specialization in DefOptions);
       if Result then
         begin
           { if at least one of the generic parameters is not owned by us (meaning it was
             passed in from outside) then we have a specialization, otherwise we have a generic }
           for I:=0 to GenericParas.Count-1 do
             begin
               Sym:=TSym(GenericParas[I]);
               { sym must be either a type or const }
               if not (Sym.Typ in [SymConst.TypeSym,SymConst.ConstSym]) then
                 InternalError(2014050904);
               if (Sym.Owner.DefOwner<>Self) or (sp_generic_unnamed_type in Sym.SymOptions) then
                 Exit(True);
               if (Sym.Typ=SymConst.ConstSym) and (sp_generic_const in Sym.SymOptions) then
                 Exit(True);
             end;
           Result:=False;
         end;
     end;


   procedure TStoredDef.RegisterDef;
     var
       GST : TGetSymTable;
       ST : TSymTable;
       TMod : TModule;
     begin
       if Registered then
         Exit;
       if Assigned(Owner) then
         begin
           TMod:=Find_Module_From_SymTable(Owner);
            if Assigned(TMod) and Assigned(CurrentModule) and (TMod<>CurrentModule) then
              begin
                Comment(VError,'Definition '+FullOwnerHierarchyName(False,True)+' from module '+TMod.MainSource+' registered with current module '+CurrentModule.MainSource);
              end;
           if not Assigned(TMod) then
             TMod:=CurrentModule;
         end
       else
         TMod:=CurrentModule;
       { Register in current_module }
       if Assigned(TMod) then
         begin
           Exclude(DefOptions,df_not_registered_no_free);
           for GST:=Low(TGetSymTable) to High(TGetSymTable) do
             begin
               ST:=GetSymTable(GST);
               if Assigned(ST) then
                 TStoredSymTable(ST).Register_Children;
             end;
           if DefID<defid_not_registered then
             DefID:=DefListIndex
           else
             begin
               TMod.DefList.Add(Self);
               DefID:=TMod.DefList.Count-1;
               RegisteredInModule:=TMod;
             end;
           Maybe_Put_In_SymTable_Stack;
         end
       else
         DefID:=defid_registered_nost;
     end;


   procedure TStoredDef.Maybe_Put_In_SymTable_Stack;
     var
       InsertStack: PSymTableStackItem;
     begin
       if Assigned(SymTableStack) and
          not Assigned(Self.Owner) then
         begin
           InsertStack:=SymTableStack.Stack;
           { don't insert defs in exception symtables, as they are freed before
             the module is compiled, so we can get crashes on high level targets
             if they still need it while e.g. writing assembler code }
           while Assigned(InsertStack) and
                 (InsertStack^.SymTable.SymTableType in [ExceptSymTable,WithSymTable]) do
             InsertStack:=InsertStack^.Next;
           if not Assigned(InsertStack) then
             InternalError(200602044);
           if InsertStack^.SymTable.Sealed then
             InternalError(2015022301);
           InsertStack^.SymTable.InsertDef(Self);
         end;
     end;


{****************************************************************************
                               Tstringdef
****************************************************************************}

    constructor TStringDef.CreateShort(L: Byte; DoRegister: Boolean);
      begin
         inherited Create(StringDef,DoRegister);
         StringType:=st_shortstring;
         Encoding:=0;
         Len:=L;
      end;


    constructor TStringDef.LoadShort(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StringDef,PPUFile);
         StringType:=st_shortstring;
         Encoding:=0;
         Len:=PPUFile.GetByte;
         PPULoadPlatform(PPUFile);
      end;


    constructor TStringDef.CreateLong(L: ASizeInt; DoRegister: Boolean);
      begin
         inherited Create(StringDef,DoRegister);
         StringType:=st_longstring;
         Encoding:=0;
         Len:=L;
      end;


    constructor TStringDef.LoadLong(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StringDef,PPUFile);
         StringType:=st_longstring;
         Encoding:=0;
         Len:=PPUFile.GetASizeInt;
         PPULoadPlatform(PPUFile);
      end;


    constructor TStringDef.CreateAnsi(AEncoding: TStringEncoding; DoRegister: Boolean);
      begin
         inherited Create(StringDef,DoRegister);
         StringType:=st_ansistring;
         Encoding:=AEncoding;
         Len:=-1;
      end;


    constructor TStringDef.LoadAnsi(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StringDef,PPUFile);
         StringType:=st_ansistring;
         Len:=PPUFile.GetASizeInt;
         Encoding:=PPUFile.GetWord;
         PPULoadPlatform(PPUFile);
      end;


    constructor TStringDef.CreateWide(DoRegister: Boolean);
      begin
         inherited Create(StringDef,DoRegister);
         StringType:=st_widestring;
         if TargetInfo.Endian=endian_little then
           Encoding:=CP_UTF16LE
         else
           Encoding:=CP_UTF16BE;
         Len:=-1;
      end;


    constructor TStringDef.LoadWide(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StringDef,PPUFile);
         StringType:=st_widestring;
         if TargetInfo.Endian=endian_little then
           Encoding:=CP_UTF16LE
         else
           Encoding:=CP_UTF16BE;
         Len:=PPUFile.GetASizeInt;
         PPULoadPlatform(PPUFile);
      end;


    constructor TStringDef.CreateUnicode(DoRegister: Boolean);
      begin
         inherited Create(StringDef,DoRegister);
         StringType:=st_unicodestring;
         if TargetInfo.Endian=endian_little then
           Encoding:=CP_UTF16LE
         else
           Encoding:=CP_UTF16BE;
         Len:=-1;
      end;


    constructor TStringDef.LoadUnicode(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(StringDef,PPUFile);
         StringType:=st_unicodestring;
         Len:=PPUFile.GetASizeInt;
         Encoding:=PPUFile.GetWord;
         PPULoadPlatform(PPUFile);
      end;


    function TStringDef.GetCopy : TStoredDef;
      begin
        Result:=CStringDef.Create(Typ,True);
        Result.Typ:=StringDef;
        TStringDef(Result).StringType:=StringType;
        TStringDef(Result).Encoding:=Encoding;
        TStringDef(Result).Len:=Len;
      end;


    function TStringDef.StringTypName:string;
      const
        TypName:array[TStringType] of string[10]=(
          'shortstr','longstr','ansistr','widestr','unicodestr'
        );
      begin
        StringTypName:=TypName[StringType];
      end;


    procedure TStringDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         if StringType=st_shortstring then
           begin
{$ifdef extdebug}
            if Len > 255 then InternalError(12122002);
{$endif}
            PPUFile.PutByte(Byte(Len))
           end
         else
           PPUFile.PutASizeInt(Len);
         if StringType in [st_ansistring,st_unicodestring] then
           PPUFile.PutWord(Encoding);
         case StringType of
            st_shortstring : WriteEntry(PPUFile,IBShortStringDef);
            st_longstring : WriteEntry(PPUFile,IBLongStringDef);
            st_ansistring : WriteEntry(PPUFile,IBAnsiStringDef);
            st_widestring : WriteEntry(PPUFile,IBWideStringDef);
            st_unicodestring : WriteEntry(PPUFile,IBUnicodeStringDef);
         end;
      end;


    function TStringDef.NeedsInitTable : Boolean;
      begin
         NeedsInitTable:=StringType in [st_ansistring,st_widestring,st_unicodestring];
      end;


    function TStringDef.GetTypeName : string;
      const
         Names : array[TStringType] of string[15] = (
           'ShortString','LongString','AnsiString','WideString','UnicodeString');
      begin
         GetTypeName:=Names[StringType];
         case StringType of
           st_ansistring,st_unicodestring:
             GetTypeName:=GetTypeName+'('+ToStr(Encoding)+')';
           st_shortstring:
             GetTypeName:=GetTypeName+'['+ToStr(Len)+']';
           else
             ;
         end;
      end;


    function TStringDef.GetVarDef : LongInt;
      const
        VarDef : array[TStringType] of LongInt = (
          VarUndefined,VarUndefined,VarString,VarOleStr,VarUString);
      begin
        Result:=VarDef[StringType];
      end;


    function TStringDef.Get_Default_Char_Type: TDef;
      begin
        case StringType of
          st_shortstring,
          st_longstring,
          st_ansistring:
            Result:=CAnsiCharType;
          st_unicodestring,
          st_widestring:
            Result:=CWideCharType;
        end;
      end;


    function TStringDef.Get_Default_String_Type: TDef;
      begin
        case StringType of
          st_shortstring:
            Result:=CShortStringType;
          { st_longstring is currently not supported but
            when it is this case will need to be supplied }
          st_longstring:
            InternalError(2021040801);
          st_ansistring:
            Result:=CAnsiStringType;
          st_widestring:
            Result:=CWideStringType;
          st_unicodestring:
            Result:=CUnicodeStringType;
        end
      end;


    function TStringDef.Alignment : ShortInt;
      begin
        case StringType of
          st_unicodestring,
          st_widestring,
          st_ansistring:
            Alignment:=VoidPointerType.Alignment;
          st_longstring,
          st_shortstring:
              { char to string accesses byte 0 and 1 with one word access }
            if (tf_requires_proper_alignment in TargetInfo.Flags) or
              { macpas needs an alignment of 2 (MetroWerks compatible) }
               (m_mac in CurrentSettings.ModeSwitches) then
              Alignment:=Size_2_Align(2)
            else
              Alignment:=Size_2_Align(1);
        end;
      end;


    function TStringDef.GetMangledParaName : TSymStr;
      begin
        GetMangledParaName:='STRING';
      end;


    function TStringDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TStringDef.Size: ASizeInt;
      begin
        case StringType of
          st_shortstring:
            Result:=Len+1;
          st_longstring,
          st_ansistring,
          st_widestring,
          st_unicodestring:
            Result:=VoidPointerType.Size;
        end;
      end;


{****************************************************************************
                                 TENUMDEF
****************************************************************************}

    constructor TEnumDef.Create;
      begin
         inherited Create(EnumDef,True);
         MinVal:=0;
         MaxVal:=0;
         CalcSaveSize(CurrentSettings.PackEnum);
         HasJumps:=False;
         BaseDef:=nil;
         BaseDefDeref.Reset;
         SymTable:=TEnumSymTable.Create(Self);
      end;


    constructor TEnumDef.Create_Subrange(ABaseDef:TEnumDef;AMin,AMax:ASizeInt);
      begin
         inherited Create(EnumDef,True);
         MinVal:=AMin;
         MaxVal:=AMax;
         BaseDef:=ABaseDef;
         CalcSaveSize(CurrentSettings.PackEnum);
         HasJumps:=False;
         SymTable:=BaseDef.SymTable.GetCopy;
         Include(DefOptions, df_copied_def);
       end;


    constructor TEnumDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(EnumDef,PPUFile);
         MinVal:=PPUFile.GetAInt;
         MaxVal:=PPUFile.GetAInt;
         SaveSize:=PPUFile.GetAInt;
         HasJumps:=False;
         if df_copied_def in DefOptions then
           begin
             SymTable:=nil;
             PPUFile.GetDeref(BaseDefDeref);
             PPULoadPlatform(PPUFile);
           end
         else
           begin
             PPULoadPlatform(PPUFile);
             // create with nil defowner first to prevent values changes on insert
             SymTable:=TEnumSymTable.Create(nil);
             TEnumSymTable(SymTable).PPULoad(PPUFile);
             SymTable.DefOwner:=Self;
           end;
      end;

    destructor TEnumDef.Destroy;
      begin
        SymTable.Free;
        SymTable:=nil;
        inherited Destroy;
      end;


    function TEnumDef.GetCopy : TStoredDef;
      begin
        if Assigned(BaseDef) then
          Result:=CEnumDef.Create_Subrange(BaseDef,MinVal,MaxVal)
        else
          begin
            Result:=CEnumDef.Create;
            TEnumDef(Result).MinVal:=MinVal;
            TEnumDef(Result).MaxVal:=MaxVal;
            TEnumDef(Result).SymTable.Free;
            TEnumDef(Result).SymTable:=SymTable.GetCopy;
            TEnumDef(Result).BaseDef:=Self;
          end;
        TEnumDef(Result).HasJumps:=HasJumps;
        TEnumDef(Result).BaseDefDeref:=BaseDefDeref;
        Include(TEnumDef(Result).DefOptions,df_copied_def);
      end;


    procedure TEnumDef.CalcSaveSize(PackEnum: ShortInt);
      begin
{$IFNDEF cpu64bitaddr} {$push}{$warnings off} {$ENDIF} //comparison always false warning
        if (PackEnum=8) or (Int64(Min)<Low(LongInt)) or (Int64(Max)>High(Cardinal)) or ((Min<0) and (Max>High(LongInt))) then
         SaveSize:=8
{$IFNDEF cpu64bitaddr} {$pop} {$ENDIF}
        else
 //comparison always false warning
         if (PackEnum=4) or (Min<Low(SmallInt)) or (Max>High(Word)) or ((Min<0) and (Max>High(SmallInt))) then
          SaveSize:=4

        else
         if (PackEnum=2) or (Min<Low(ShortInt)) or (Max>High(Byte)) or ((Min<0) and (Max>High(ShortInt))) then
          SaveSize:=2
        else
         SaveSize:=1;
      end;


    function TEnumDef.PackedBitSize: ASizeInt;
      var
        SizeVal: TConstExprInt;
        Power: LongInt;
      begin
        Result := 0;
        if (MinVal >= 0) and
           (MaxVal <= 1) then
          Result := 1
        else
          begin
            if (MinVal>=0) then
              SizeVal:=MaxVal
            else
             { don't count 0 twice, but take into account that range goes from -n-1..n }
              SizeVal:=(CUtils.Max(-MinVal,MaxVal+1)*2)-1;
            { 256 must become 512 etc. }
            NextPowerOf2(SizeVal+1,Power);
            Result := Power;
          end;
      end;


    procedure TEnumDef.SetMax(AMax:ASizeInt);
      begin
        MaxVal:=AMax;
        CalcSaveSize(CurrentSettings.PackEnum);
      end;


    procedure TEnumDef.SetMin(AMin:ASizeInt);
      begin
        MinVal:=AMin;
        CalcSaveSize(CurrentSettings.PackEnum);
      end;


    function TEnumDef.Min:ASizeInt;
      begin
        Min:=MinVal;
      end;


    function TEnumDef.Max:ASizeInt;
      begin
        Max:=MaxVal;
      end;

    function TEnumDef.GetFirstSym: TSym;
      var
        I:Integer;
      begin
        for I := 0 to SymTable.SymList.Count - 1 do
          begin
            Result:=TSym(SymTable.SymList[I]);
            if TEnumSym(Result).Value=MinVal then
              Exit;
          end;
        Result:=nil;
      end;


    function TEnumDef.Int2EnumSym(L: ASizeInt): TSym;
      var
        I: LongInt;
        Sym: TSym;
        BDef: TEnumDef;
      begin
        Result:=nil;
        if (L<MinVal) or
           (L>MaxVal) then
          Exit;
        BDef:=GetBaseDef;
        for I:=0 to BDef.SymTable.SymList.Count-1 do
          begin
            Sym:=TSym(BDef.SymTable.SymList[I]);
            if (Sym.Typ=EnumSym) and
               (TEnumSym(Sym).Value=L) then
              begin
                Result:=Sym;
                Exit;
              end;
          end;
      end;


    function TEnumDef.GetBaseDef: TEnumDef;
      begin
        if not Assigned(BaseDef) then
          Result:=Self
        else
          Result:=BaseDef;
      end;


    procedure TEnumDef.BuildDeref;
      begin
        inherited BuildDeref;
        if df_copied_def in DefOptions then
          BaseDefDeref.Build(BaseDef)
        else
          TEnumSymTable(SymTable).BuildDeref;
      end;


    procedure TEnumDef.Deref;
      begin
        inherited Deref;
        if df_copied_def in DefOptions then
          begin
            BaseDef:=TEnumDef(BaseDefDeref.Resolve);
            SymTable:=BaseDef.SymTable.GetCopy;
          end
        else
          TEnumSymTable(SymTable).Deref(False);
      end;


    procedure TEnumDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutAInt(Min);
         PPUFile.PutAInt(Max);
         PPUFile.PutAInt(SaveSize);
         if df_copied_def in DefOptions then
           PPUFile.PutDeref(BaseDefDeref);
         WriteEntry(PPUFile,IBEnumDef);
         if not (df_copied_def in DefOptions) then
           TEnumSymTable(SymTable).PPUWrite(PPUFile);
      end;


    function TEnumDef.IsPublishable : TPublishProperty;
      begin
         if not HasJumps then
           IsPublishable:=pp_publish
         else
         if m_delphi in CurrentSettings.ModeSwitches then
           IsPublishable:=pp_ignore
         else
           IsPublishable:=pp_error;
      end;


    function TEnumDef.GetTypeName : string;
      begin
         GetTypeName:='<enumeration type>';
      end;

{****************************************************************************
                             TRTTI_ATTRIBUTE_LIST
****************************************************************************}


    constructor TRTTIAttribute.PPULoad(PPUFile: TCompilerPPUFile);
      begin
        PPUFile.GetDeref(TypeSymDeref);
        PPUFile.GetDeref(TypeConstrDeref);
        SetLength(Paras,PPUFile.GetLongInt);
      end;


    procedure TRTTIAttribute.PPUWrite(PPUFile: TCompilerPPUFile);
      begin
        PPUFile.PutDeref(TypeSymDeref);
        PPUFile.PutDeref(TypeConstrDeref);
        PPUFile.PutLongInt(Length(Paras));
      end;


    procedure TRTTIAttribute.PPULoadSubEntries(PPUFile: TCompilerPPUFile);
      var
        I : SizeInt;
      begin
        for I:=0 to High(Paras) do
          Paras[I]:=PPULoadNodeTree(PPUFile);
      end;


    procedure TRTTIAttribute.PPUWriteSubEntries(PPUFile: TCompilerPPUFile);
      var
        I : SizeInt;
      begin
        for I:=0 to High(Paras) do
          PPUWriteNodeTree(PPUFile,Paras[I]);
      end;


    destructor TRTTIAttribute.Destroy;
      var
        N : TNode;
      begin
        ConstructorCall.Free;
        ConstructorCall := nil;
        for N in Paras do
          N.Free;
          N := nil;
        inherited Destroy;
      end;


    procedure TRTTIAttribute.BuildDeref;
      var
        I : SizeInt;
      begin
        TypeSymDeref.Build(TypeSym);
        TypeConstrDeref.Build(TypeConstr);
        for I:=0 to High(Paras) do
          Paras[I].BuildDerefImpl;
      end;


    procedure TRTTIAttribute.Deref;
      var
        I : SizeInt;
      begin
        TypeSym:=TSym(TypeSymDeref.Resolve);
        TypeConstr:=TDef(TypeConstrDeref.Resolve);
        for I:=0 to High(Paras) do
          Paras[I].DerefImpl;
      end;


    class procedure TRTTIAttributeList.Bind(var Dangling,Owned:TRTTIAttributeList);
      begin
        if Assigned(Owned) then
          InternalError(2019071001);
        if not Assigned(Dangling) then
          Exit;
        if Dangling.IsBound then
          InternalError(2019071002);
        CurrentModule.UsedRTTIAttrs.ConcatListCopy(Dangling.RTTIAttributes);
        Dangling.IsBound:=True;
        Owned:=Dangling;
        Dangling:=nil;
      end;

    class procedure TRTTIAttributeList.CopyAndBind(AList : TRTTIAttributeList; var Owned: TRTTIAttributeList);
    var
      I,J : Integer;
      Attr,NewAttribute : TRTTIAttribute;
    begin
      if Owned=Nil then
        Owned:=TRTTIAttributeList.Create;
      Owned.IsBound:=True;
      for I:=0 to AList.RTTIAttributes.Count-1 do
        begin
        Attr:=TRTTIAttribute(AList.RTTIAttributes[I]);
        NewAttribute:=TRTTIAttribute.Create;
        NewAttribute.TypeSym:=Attr.TypeSym;
        NewAttribute.TypeConstr:=Attr.TypeConstr;
        NewAttribute.ConstructorCall:=Attr.ConstructorCall.GetCopy;
        SetLength(NewAttribute.Paras,Length(Attr.Paras));
        for J:=0 to Length(Attr.Paras)-1 do
          NewAttribute.Paras[J]:=Attr.Paras[J].GetCopy;
        Owned.AddAttribute(NewAttribute);
        end;
      CurrentModule.UsedRTTIAttrs.ConcatListCopy(Owned.RTTIAttributes);
    end;


    procedure TRTTIAttributeList.AddAttribute(ATypeSym:TSym;TypeConstr:TDef;ConstructorCall:TNode;constref Paras:array of TNode);
      var
        NewAttribute : TRTTIAttribute;
        I : SizeInt;
      begin
        if not Assigned(RTTIAttributes) then
          RTTIAttributes:=TFPObjectList.Create(True);
        NewAttribute:=TRTTIAttribute.Create;
        NewAttribute.TypeSym:=ATypeSym;
        NewAttribute.TypeConstr:=TypeConstr;
        NewAttribute.ConstructorCall:=ConstructorCall;
        SetLength(NewAttribute.Paras,Length(Paras));
        for I:=0 to High(Paras) do
          NewAttribute.Paras[I]:=Paras[I];
        RTTIAttributes.Add(NewAttribute);
      end;


    procedure TRTTIAttributeList.AddAttribute(Attr:TRTTIAttribute);
      begin
        if not Assigned(RTTIAttributes) then
          RTTIAttributes:=TFPObjectList.Create(True);
        RTTIAttributes.Add(Attr);
      end;


    destructor TRTTIAttributeList.Destroy;
      begin
        RTTIAttributes.Free;
        RTTIAttributes := nil;
        inherited Destroy;
      end;


    function TRTTIAttributeList.GetAttributeCount:LongInt;
      begin
        if Assigned(RTTIAttributes) then
          Result:=RTTIAttributes.Count
        else
          Result:=0;
      end;


    procedure TRTTIAttributeList.BuildDeref;
      var
        I : SizeInt;
      begin
        if not Assigned(RTTIAttributes) then
          Exit;
        for I:=0 to RTTIAttributes.Count-1 do
          TRTTIAttribute(RTTIAttributes[I]).BuildDeref;
      end;


    procedure TRTTIAttributeList.Deref;
      var
        I : SizeInt;
      begin
        if not Assigned(RTTIAttributes) then
          Exit;
        for I:=0 to RTTIAttributes.Count-1 do
          TRTTIAttribute(RTTIAttributes[I]).Deref;
      end;


    class procedure TRTTIAttributeList.PPULoadSubEntries(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
      var
        I : SizeInt;
      begin
        if Assigned(AttrList) then
          begin
            if not Assigned(AttrList.RTTIAttributes) then
              InternalError(2019071101);
            for I:=0 to AttrList.RTTIAttributes.Count-1 do
              TRTTIAttribute(AttrList.RTTIAttributes[I]).PPULoadSubEntries(PPUFile);
          end;
      end;


    class procedure TRTTIAttributeList.PPUWriteSubEntries(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
      var
        I : SizeInt;
      begin
        if Assigned(AttrList) and Assigned(AttrList.RTTIAttributes) then
          begin
            for I:=0 to AttrList.RTTIAttributes.Count-1 do
              TRTTIAttribute(AttrList.RTTIAttributes[I]).PPUWriteSubEntries(PPUFile);
          end;
      end;


    class function TRTTIAttributeList.PPULoad(PPUFile:TCompilerPPUFile):TRTTIAttributeList;
      var
        Cnt,I : LongInt;
      begin
        Cnt:=PPUFile.GetLongInt;
        if Cnt>0 then
          begin
            Result:=TRTTIAttributeList.Create;
            for I:=0 to Cnt-1 do
              Result.AddAttribute(TRTTIAttribute.PPULoad(PPUFile));
          end
        else
          Result:=nil;
      end;


    class procedure TRTTIAttributeList.PPUWrite(AttrList:TRTTIAttributeList;PPUFile:TCompilerPPUFile);
      var
        I : LongInt;
      begin
        if Assigned(AttrList) and Assigned(AttrList.RTTIAttributes) then
          begin
            PPUFile.PutLongInt(AttrList.RTTIAttributes.Count);
            for I:=0 to AttrList.RTTIAttributes.Count-1 do
              TRTTIAttribute(AttrList.RTTIAttributes[I]).PPUWrite(PPUFile);
          end
        else
          PPUFile.PutLongInt(0);
      end;


{****************************************************************************
                                 TORDDEF
****************************************************************************}

    constructor TOrdDef.Create(T : TOrdType;V,B : TConstExprInt; DoRegister: Boolean);
      begin
         inherited Create(OrdDef,DoRegister);
         Low:=V;
         High:=B;
         OrdType:=T;
         SetSize;
      end;


    constructor TOrdDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(OrdDef,PPUFile);
         OrdType:=TOrdType(PPUFile.GetByte);
         Low:=PPUFile.GetExprInt;
         High:=PPUFile.GetExprInt;
         SetSize;
         PPULoadPlatform(PPUFile);
      end;


    function TOrdDef.GetCopy : TStoredDef;
      begin
         Result:=COrdDef.Create(OrdType,Low,High,True);
         Result.Typ:=OrdDef;
         TOrdDef(Result).Low:=Low;
         TOrdDef(Result).High:=High;
         TOrdDef(Result).OrdType:=OrdType;
         TOrdDef(Result).SaveSize:=SaveSize;
      end;


    function TOrdDef.Alignment:ShortInt;
      begin
        if (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) and
           (OrdType in [S64Bit,U64Bit]) then
          Result := 4
        else
          Result := inherited Alignment;
      end;


    procedure TOrdDef.SetSize;
      const
        SizeTbl : array[TOrdType] of LongInt = (
          0,
          1,2,4,8,16,
          1,2,4,8,16,
          1,1,2,4,8,
          1,2,4,8,
          1,2,8,System.High(LongInt)
        );
      begin
        SaveSize:=SizeTbl[OrdType];
        if SaveSize=System.High(LongInt) then
          SaveSize:=PackedBitSize div 8;
      end;


    function TOrdDef.PackedBitSize: ASizeInt;
      var
        SizeVal: TConstExprInt;
        Power: LongInt;
      begin
        Result := 0;
        if OrdType = UVoid then
          Exit;

{$ifndef cpu64bitalu}
        if (OrdType in [S64Bit,U64Bit]) then
{$else not cpu64bitalu}
        if ((OrdType = U64Bit) and
            (High > System.High(Int64))) or
           ((OrdType = S64Bit) and
            ((Low <= (System.Low(Int64) div 2)) or
             ((Low < 0) and
              (High > (System.High(Int64) div 2))))) then
{$endif cpu64bitalu}
          Result := 64
        else if (
            (Low >= 0) and
            (High <= 1)
           ) or (
             OrdType in [PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit]
           ) then
          Result := 1
        else
          begin
            if (Low>=0) then
              SizeVal:=High
            else
              { don't count 0 twice, but take into account that range goes from -n-1..n }
              SizeVal:=(CUtils.Max(-Low,High+1)*2)-1;
            { 256 must become 512 etc. }
            NextPowerOf2(SizeVal+1,Power);
            Result := Power;
         end;
      end;


    function TOrdDef.GetVarDef : LongInt;
      const
        BaseType2VarDef : array[TOrdType] of LongInt = (
          VarUndefined,
          VarByte,VarWord,VarLongWord,VarQWord,VarUndefined,
          VarShortInt,VarSmallInt,VarInteger,VarInt64,VarUndefined,
          VarBoolean,VarBoolean,VarBoolean,VarBoolean,VarBoolean,
          VarBoolean,VarBoolean,VarUndefined,VarUndefined,
          VarUndefined,VarUndefined,VarCurrency,VarEmpty);
      begin
        Result:=BaseType2VarDef[OrdType];
        if Result=VarEmpty then
          Result:=BaseType2VarDef[range_to_basetype(Low,High)];
      end;


    procedure TOrdDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(OrdType));
         PPUFile.PutExprInt(Low);
         PPUFile.PutExprInt(High);
         WriteEntry(PPUFile,IBOrdDef);
      end;


    function TOrdDef.IsPublishable : TPublishProperty;
      begin
         if OrdType<>UVoid then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TOrdDef.GetTypeName : string;
      const
        Names : array[TOrdType] of string[20] = (
          'untyped',
          'Byte','Word','DWord','QWord','UInt128',
          'ShortInt','SmallInt','LongInt','Int64','Int128',
          'Boolean','Boolean8','Boolean16','Boolean32','Boolean64',
          'ByteBool','WordBool','LongBool','QWordBool',
          'AnsiChar','WideChar','Currency','CustomRange');

      begin
         GetTypeName:=Names[OrdType];
      end;


{****************************************************************************
                                TFLOATDEF
****************************************************************************}

    constructor TFloatDef.Create(T: TFloatType; DoRegister: Boolean);
      begin
         inherited Create(FloatDef,DoRegister);
         FloatType:=T;
         SetSize;
      end;


    constructor TFloatDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(FloatDef,PPUFile);
         FloatType:=TFloatType(PPUFile.GetByte);
         SetSize;
         PPULoadPlatform(PPUFile);
      end;


    function TFloatDef.GetCopy : TStoredDef;
      begin
         Result:=CFloatDef.Create(FloatType,True);
         Result.Typ:=FloatDef;
         TFloatDef(Result).SaveSize:=SaveSize;
      end;


    function TFloatDef.Alignment:ShortInt;
      begin
        if (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) then
          case FloatType of
            SC80Real,
            S80Real: Result:=16;
            S64Real,
            S64Currency,
            S64Comp : Result:=4;
            else
              Result := inherited Alignment;
          end
        else
          Result := inherited Alignment;
      end;


    function TFloatDef.StructAlignment: ShortInt;
      begin
        Result:=Alignment;
      end;


    procedure TFloatDef.SetSize;
      begin
         case FloatType of
           S32Real : SaveSize:=4;
           S80Real : SaveSize:=10;
           SC80Real:
             if TargetInfo.System in [system_i386_darwin,
                  system_i386_iphonesim,system_x86_64_darwin,
                  system_x86_64_iphonesim,
                  system_x86_64_linux] then
               SaveSize:=16
             else
               SaveSize:=12;
           S64Real,
           S64Currency,
           S64Comp : SaveSize:=8;
         end;
      end;


    function TFloatDef.GetVarDef : LongInt;
      const
        FloatType2VarDef : array[TFloatType] of LongInt = (
          VarSingle,VarDouble,VarUndefined,VarUndefined,
          VarUndefined,VarCurrency);
      begin
        if (Upper(TypeName)='TDATETIME') and
          Assigned(Owner) and
          Assigned(Owner.Name) and
          (Owner.Name^='SYSTEM') then
          Result:=VarDate
        else
          Result:=FloatType2VarDef[FloatType];
      end;


    procedure TFloatDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(FloatType));
         WriteEntry(PPUFile,IBFloatDef);
      end;


    function TFloatDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TFloatDef.GetTypeName : string;
      const
        Names : array[TFloatType] of string[20] = (
          'Single','Double','Extended','CExtended','Comp','Currency');
      begin
         GetTypeName:=Names[FloatType];
      end;


{****************************************************************************
                                TFILEDEF
****************************************************************************}

    constructor TFileDef.CreateText;
      begin
         inherited Create(FileDef,True);
         FileTyp:=ft_text;
         TypedFileDef:=nil;
         TypedFileDefDeref.Reset;
      end;


    constructor TFileDef.CreateUntyped;
      begin
         inherited Create(FileDef,True);
         FileTyp:=ft_untyped;
         TypedFileDef:=nil;
      end;


    constructor TFileDef.CreateTyped(Def:TDef);
      begin
         inherited Create(FileDef,True);
         FileTyp:=ft_typed;
         TypedFileDef:=Def;
      end;


    constructor TFileDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(FileDef,PPUFile);
         FileTyp:=TFileTyp(PPUFile.GetByte);
         if FileTyp=ft_typed then
           PPUFile.GetDeref(TypedFileDefDeref)
         else
           TypedFileDef:=nil;
         PPULoadPlatform(PPUFile);
      end;


    function TFileDef.GetCopy : TStoredDef;
      begin
        case FileTyp of
          ft_typed:
            Result:=CFileDef.CreateTyped(TypedFileDef);
          ft_untyped:
            Result:=CFileDef.CreateUntyped;
          ft_text:
            Result:=CFileDef.CreateText;
        end;
      end;


    procedure TFileDef.BuildDeref;
      begin
        inherited BuildDeref;
        if FileTyp=ft_typed then
          TypedFileDefDeref.Build(TypedFileDef);
      end;


    procedure TFileDef.Deref;
      begin
        inherited Deref;
        if FileTyp=ft_typed then
          TypedFileDef:=TDef(TypedFileDefDeref.Resolve);
      end;


    function  TFileDef.Size:ASizeInt;
      begin
        if SaveSize=0 then
          SetSize;
        Size:=SaveSize;
      end;


    procedure TFileDef.SetSize;
      begin
       case FileTyp of
         ft_text:
           SaveSize:=Search_System_Type('TEXTREC').TypeDef.Size;
         ft_typed:
           begin
             SaveSize:=Search_System_Type('FILEREC').TypeDef.Size;
             { allocate put/get buffer in iso mode }
             if m_isolike_io in CurrentSettings.ModeSwitches then
               Inc(SaveSize,TypedFileDef.Size);
           end;
         ft_untyped:
           SaveSize:=Search_System_Type('FILEREC').TypeDef.Size;
         end;
      end;


    function TFileDef.Alignment: ShortInt;
      begin
        case FileTyp of
          ft_text:
            Result:=Search_System_Type('TEXTREC').TypeDef.Alignment;
          ft_typed,
          ft_untyped:
            Result:=Search_System_Type('FILEREC').TypeDef.Alignment;
          end;
      end;


    procedure TFileDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(FileTyp));
         if FileTyp=ft_typed then
           PPUFile.PutDeref(TypedFileDefDeref);
         WriteEntry(PPUFile,IBFileDef);
      end;


    function TFileDef.GetTypeName : string;
      begin
         case FileTyp of
           ft_untyped:
             GetTypeName:='File';
           ft_typed:
             GetTypeName:='File Of '+TypedFileDef.TypeName;
           ft_text:
             GetTypeName:='Text'
         end;
      end;


    function TFileDef.GetMangledParaName : TSymStr;
      begin
         case FileTyp of
           ft_untyped:
             GetMangledParaName:='FILE';
           ft_typed:
             GetMangledParaName:='FILE$OF$'+TypedFileDef.MangledParaName;
           ft_text:
             GetMangledParaName:='TEXT'
         end;
      end;


{****************************************************************************
                               TVARIANTDEF
****************************************************************************}

    constructor TVariantDef.Create(V : TVariantType);
      begin
         inherited Create(VariantDef,True);
         VariantType:=V;
         SetSize;
      end;


    constructor TVariantDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(VariantDef,PPUFile);
         VariantType:=TVariantType(PPUFile.GetByte);
         SetSize;
         PPULoadPlatform(PPUFile);
      end;


    function TVariantDef.GetCopy : TStoredDef;
      begin
        Result:=CVariantDef.Create(VariantType);
      end;


    function TVariantDef.Alignment: ShortInt;
      begin
        Result:=Search_System_Type('TVARDATA').TypeDef.Alignment;
      end;


    procedure TVariantDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(VariantType));
         WriteEntry(PPUFile,IBVariantDef);
      end;


    function TVariantDef.GetVarDef : LongInt;
      begin
        Result:=VarVariant;
      end;


    procedure TVariantDef.SetSize;
      begin
{$ifdef cpu64bitaddr}
        SaveSize:=24;
{$else cpu64bitaddr}
        SaveSize:=16;
{$endif cpu64bitaddr}
      end;


    function TVariantDef.GetTypeName : string;
      begin
         case VariantType of
           vt_normalvariant:
             GetTypeName:='Variant';
           vt_olevariant:
             GetTypeName:='OleVariant';
         end;
      end;


    function TVariantDef.NeedsInitTable : Boolean;
      begin
         NeedsInitTable:=True;
      end;


    function TVariantDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


{****************************************************************************
                            TABSTRACtpointerdef
****************************************************************************}

    constructor TAbstractPointerDef.Create(DT:TDefTyp;Def:TDef);
      begin
        inherited Create(DT,True);
        PointedDef:=Def;
        PointedDefDeref.Reset;
        if df_generic in PointedDef.DefOptions then
          Include(DefOptions,df_generic);
        if df_specialization in PointedDef.DefOptions then
          Include(DefOptions,df_specialization);
      end;


    constructor TAbstractPointerDef.PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(DT,PPUFile);
         PPUFile.GetDeref(PointedDefDeref);
      end;


    procedure TAbstractPointerDef.BuildDeref;
      begin
        inherited BuildDeref;
        PointedDefDeref.Build(PointedDef);
      end;


    procedure TAbstractPointerDef.Deref;
      begin
        inherited Deref;
        PointedDef:=TDef(PointedDefDeref.Resolve);
      end;


    function TAbstractPointerDef.Size: ASizeInt;
      begin
        Result:=VoidPointerType.Size;
      end;


    function TAbstractPointerDef.Alignment: ShortInt;
      begin
        Alignment:=Size_2_Align(VoidPointerType.Size);
      end;


    procedure TAbstractPointerDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(PointedDefDeref);
      end;


{****************************************************************************
                               tpointerdef
****************************************************************************}

    constructor TPointerDef.Create(Def:TDef);
      begin
        inherited Create(PointerDef,Def);
        HasPointerMath:=cs_pointermath in CurrentSettings.LocalSwitches;
        if (df_specialization in TStoredDef(Def).DefOptions)
{$ifndef genericdef_for_nested}
           { currently, nested procdefs of generic routines get df_specialization,
             but no genericdef }
           and Assigned(TStoredDef(Def).GenericDef)
{$endif}
           then
          GenericDef:=CPointerDef.GetReusable(TStoredDef(Def).GenericDef);
      end;


    class function TPointerDef.GetReusable(Def: TDef): TPointerDef;
      var
        Res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
      begin
        if not Assigned(CurrentModule) then
          InternalError(2011071101);
        Res:=CurrentModule.PtrDefs.FindOrAdd(@Def,SizeOf(Def));
        if not Assigned(Res^.Data) then
          begin
            { since these pointerdefs can be reused anywhere in the current
              unit, add them to the global/staticsymtable (or local symtable
              if they're a local def, because otherwise they'll be saved
              to the ppu referencing a local symtable entry that doesn't
              exist in the ppu) }
            OldSymTableStack:=SymTableStack;
            { do not simply push/pop current_module.localsymtable, because
              that can have side-effects (e.g., it removes helpers) }
            SymTableStack:=nil;
            Result:=CPointerDef.Create(Def);
            SetupReusableDef(Def,Result,Res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            Exit;
          end;
        Result:=TPointerDef(Res^.Data);
      end;


    class function TPointerDef.GetReusable_No_Free(Def: TDef): TPointerDef;
      begin
        Result:=GetReusable(Def);
        if not Result.IsRegistered then
          Include(Result.DefOptions,df_not_registered_no_free);
      end;


    function TPointerDef.Size: ASizeInt;
      begin
        Result:=SizeOf(PInt);
      end;


    constructor TPointerDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(PointerDef,PPUFile);
         HasPointerMath:=(PPUFile.GetByte<>0);
         PPULoadPlatform(PPUFile);
      end;


    function TPointerDef.GetCopy : TStoredDef;
      begin
        { don't use direct pointeddef if it is a forwarddef because in other case
          one of them will be destroyed on forward type resolve and the second will
          point to garbage }
        if PointedDef.Typ=ForwardDef then
          Result:=CPointerDef.Create(TForwardDef(PointedDef).GetCopy)
        else
          Result:=CPointerDef.Create(PointedDef);
        TPointerDef(Result).HasPointerMath:=HasPointerMath;
        TPointerDef(Result).SaveSize:=SaveSize;
      end;


    procedure TPointerDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(HasPointerMath));
         WriteEntry(PPUFile,IBPointerDef);
      end;


    function TPointerDef.GetTypeName : string;
      begin
        { parameter types and the resultdef of a procvardef can contain a
          pointer to this procvardef itself, resulting in endless recursion ->
          use the typesym's name instead if it exists (if it doesn't, such as
          for anonymous procedure types in macpas/iso mode, then there cannot
          be any recursive references to it either) }
        if (PointedDef.Typ<>ProcVarDef) or
           not Assigned(PointedDef.TypeSym) then
          GetTypeName:='^'+PointedDef.TypeName
        else
          GetTypeName:='^'+PointedDef.TypeSym.RealName;
      end;


    function TPointerDef.Pointer_Arithmetic_Int_Type:TDef;
      begin
        Result:=PtrSIntType;
      end;


    function TPointerDef.Pointer_Arithmetic_UInt_Type:TDef;
      begin
        Result:=PtrUIntType;
      end;


    function TPointerDef.Pointer_Subtraction_Result_Type:TDef;
      begin
        Result:=PtrSIntType;
      end;


    function TPointerDef.Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean;
      begin
        Result:=True;
      end;


    function TPointerDef.Converted_Pointer_To_Array_Range_Type:TDef;
      begin
        Result:=PtrSIntType;
      end;


{****************************************************************************
                              TCLASSREFDEF
****************************************************************************}

    constructor TClassRefDef.Create(Def:TDef);
      begin
         while (Def.Typ=ObjectDef) and TObjectDef(Def).Is_Unique_ObjPasDef do
           Def:=TObjectDef(Def).ChildOf;
         inherited Create(ClassRefDef,Def);
         if df_specialization in TStoredDef(Def).DefOptions then
           GenericDef:=CClassRefDef.Create(TStoredDef(Def).GenericDef);
      end;


    constructor TClassRefDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ClassRefDef,PPUFile);
         PPULoadPlatform(PPUFile);
      end;


    procedure TClassRefDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         WriteEntry(PPUFile,IBClassRefDef);
      end;


    function TClassRefDef.GetCopy:TStoredDef;
      begin
        if PointedDef.Typ=ForwardDef then
          Result:=CClassRefDef.Create(TForwardDef(PointedDef).GetCopy)
        else
          Result:=CClassRefDef.Create(PointedDef);
      end;


    function TClassRefDef.GetTypeName : string;
      begin
         GetTypeName:='Class Of '+PointedDef.TypeSymbolPrettyName;
      end;


    function TClassRefDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TClassRefDef.RTTIMangledName(RT: TRTTIType): TSymStr;
      begin
        if (TObjectDef(PointedDef).ObjectType<>odt_objcclass) then
          Result:=inherited RTTIMangledName(RT)
        else
          Result:=TObjectDef(PointedDef).RTTIMangledName(ObjCMetaRTTI);
      end;


    procedure TClassRefDef.RegisterCreatedObjectType;
      begin
        TObjectDef(PointedDef).RegisterCreatedClassRefType;
      end;

{***************************************************************************
                                   TSETDEF
***************************************************************************}

    constructor TSetDef.Create(Def: TDef; Low, High: ASizeInt; DoRegister: Boolean);
      var
        SetAllocBits: AInt;
        PackedSaveSize: AInt;
        ActualSetAlloc: ShortInt;
      begin
         inherited Create(SetDef,DoRegister);
         ElementDef:=Def;
         ElementDefDeref.Reset;
         SetMax:=High;
         SetLow:=Low;
         ActualSetAlloc:=CurrentSettings.SetAlloc;

         if (ActualSetAlloc=0) then
           begin
             SetBase:=0;
             if (High<32) then
               SaveSize:=SizeOf(LongInt)
             else if (High<256) then
               SaveSize:=32
             else
               SaveSize:=(High+7) div 8
           end
         else
           begin
             SetAllocBits:=ActualSetAlloc*8;
             SetBase:=Low and not(SetAllocBits-1);
             PackedSaveSize:=ActualSetAlloc*((((High+SetAllocBits)-SetBase)) DIV SetAllocBits);
             SaveSize:=PackedSaveSize;

             if SaveSize=3 then
               SaveSize:=4;

           end;
      end;


    constructor TSetDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(SetDef,PPUFile);
         PPUFile.GetDeref(ElementDefDeref);
         SaveSize:=PPUFile.GetASizeInt;
         SetBase:=PPUFile.GetASizeInt;
         SetLow:=PPUFile.GetASizeInt;
         SetMax:=PPUFile.GetASizeInt;
         PPULoadPlatform(PPUFile);
      end;


    function TSetDef.GetCopy : TStoredDef;
      begin
        Result:=CSetDef.Create(ElementDef,SetBase,SetMax,True);
        { the copy might have been created with a different setalloc setting }
        TSetDef(Result).SaveSize:=SaveSize;
      end;


    procedure TSetDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(ElementDefDeref);
         PPUFile.PutASizeInt(SaveSize);
         PPUFile.PutASizeInt(SetBase);
         PPUFile.PutASizeInt(SetLow);
         PPUFile.PutASizeInt(SetMax);
         WriteEntry(PPUFile,IBSetDef);
      end;


    procedure TSetDef.BuildDeref;
      begin
        inherited BuildDeref;
        ElementDefDeref.Build(ElementDef);
      end;


    procedure TSetDef.Deref;
      begin
        inherited Deref;
        ElementDef:=TDef(ElementDefDeref.Resolve);
      end;


    function TSetDef.IsPublishable : TPublishProperty;
      begin
         if SaveSize in [1,2,4] then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;

    function TSetDef.Alignment: ShortInt;
      begin
        Result:=inherited;
        if Result>SizeOf(AInt) then
          Result:=SizeOf(AInt);
      end;


    function TSetDef.GetTypeName : string;
      begin
         if Assigned(ElementDef) then
          GetTypeName:='Set Of '+ElementDef.TypeName
         else
          GetTypeName:='Empty Set';
      end;


{***************************************************************************
                                 TFORMALDEF
***************************************************************************}

    constructor TFormalDef.Create(ATyped:Boolean);
      begin
         inherited Create(FormalDef,True);
         Typed:=ATyped;
         SaveSize:=0;
      end;


    constructor TFormalDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(FormalDef,PPUFile);
         Typed:=Boolean(PPUFile.GetByte);
         SaveSize:=0;
         PPULoadPlatform(PPUFile);
      end;


    procedure TFormalDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(Typed));
         WriteEntry(PPUFile,IBFormalDef);
      end;


    function TFormalDef.GetTypeName : string;
      begin
         if Typed then
           GetTypeName:='<Typed formal type>'
         else
           GetTypeName:='<Formal type>';
      end;


{***************************************************************************
                           TARRAYDEF
***************************************************************************}

    constructor TArrayDef.Create(L, H: ASizeInt; Def: TDef);
      begin
         inherited Create(ArrayDef,True);
         LowRange:=L;
         HighRange:=H;
         RangeDef:=Def;
         RangeDefDeref.Reset;
         FElementDef:=nil;
         FElementDefDeref.Reset;
         ArrayOptions:=[];
         SymTable:=TArraySymTable.Create(Self);
      end;


    constructor TArrayDef.Create_Vector(L ,H: ASizeInt; Def: TDef);
      begin
        Self.Create(L,H,Def);
        Include(ArrayOptions,ado_IsVector);
      end;


    constructor TArrayDef.Create_OpenArray;
      begin
        Self.Create(0,-1,SizeSIntType);
        Include(ArrayOptions,ado_OpenArray);
      end;


    class function TArrayDef.GetReusable_Intern(Def: TDef; Elems: ASizeInt; const Options: TArrayDefOptions): TArrayDef;
      var
        Res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
        ArrDesc: packed record
          Def: TDef;
          EleCount: ASizeInt;
          Options: TArrayDefOptions
        end;
      begin
        if not Assigned(CurrentModule) then
          InternalError(2011081301);
        ArrDesc.Def:=Def;
        ArrDesc.EleCount:=Elems;
        ArrDesc.Options:=Options;
        Res:=CurrentModule.ArrayDefs.FindOrAdd(@ArrDesc,SizeOf(ArrDesc));
        if not Assigned(Res^.Data) then
          begin
            { since these pointerdefs can be reused anywhere in the current
              unit, add them to the global/staticsymtable (or local symtable
              if they're a local def, because otherwise they'll be saved
              to the ppu referencing a local symtable entry that doesn't
              exist in the ppu) }
            OldSymTableStack:=SymTableStack;
            { do not simply push/pop current_module.localsymtable, because
              that can have side-effects (e.g., it removes helpers) }
            SymTableStack:=nil;
            Result:=CArrayDef.Create(0,Elems-1,SizeSIntType);
            Result.ElementDef:=Def;
            Result.ArrayOptions:=Options;
            SetupReusableDef(Def,Result,Res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            Exit;
          end;
        Result:=TArrayDef(Res^.Data);
      end;


    class function TArrayDef.GetReusable(Def: TDef; Elems: ASizeInt): TArrayDef;
      begin
        Result:=GetReusable_Intern(Def,Elems,[]);
      end;


    class function TArrayDef.GetReusable_Vector(Def: TDef; Elems: ASizeInt): TArrayDef;
      begin
        Result:=GetReusable_Intern(Def,Elems,[ado_IsVector]);
      end;


    class function TArrayDef.GetReusable_No_Free(Def: TDef; Elems: ASizeInt): TArrayDef;
      begin
        Result:=GetReusable(Def,Elems);
        if not Result.IsRegistered then
          Include(Result.DefOptions,df_not_registered_no_free);
      end;

    class function TArrayDef.GetReusable_No_Free_Vector(Def: TDef; Elems: ASizeInt): TArrayDef;
      begin
        Result:=GetReusable_Vector(Def,Elems);
        if not Result.IsRegistered then
          Include(Result.DefOptions,df_not_registered_no_free);
      end;


    destructor TArrayDef.Destroy;
      begin
        SymTable.Free;
        SymTable:=nil;
        inherited;
      end;


    constructor TArrayDef.Create_From_Pointer(Def:TPointerDef);
      begin
         { divide by the element size and do -1 so the array will have a valid size,
           further, the element size might be 0 e.g. for empty records, so use max(...,1)
           to avoid a division by zero }
         Self.Create(0,(High(ASizeInt) div Max(Def.PointedDef.Size,1))-1,
           Def.Converted_Pointer_To_Array_Range_Type);
         ArrayOptions:=[ado_IsConvertedPointer];
         SetElementDef(Def.PointedDef);
      end;


    constructor TArrayDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ArrayDef,PPUFile);
         { the addresses are calculated later }
         PPUFile.GetDeref(FElementDefDeref);
         PPUFile.GetDeref(RangeDefDeref);
         LowRange:=PPUFile.GetASizeInt;
         HighRange:=PPUFile.GetASizeInt;
         PPUFile.GetSet(TPPUSet2(ArrayOptions));
         PPULoadPlatform(PPUFile);
         SymTable:=TArraySymTable.Create(Self);
         TArraySymTable(SymTable).PPULoad(PPUFile)
      end;


    function TArrayDef.GetCopy : TStoredDef;
      begin
        Result:=CArrayDef.Create(LowRange,HighRange,RangeDef);
        TArrayDef(Result).ArrayOptions:=ArrayOptions;
        TArrayDef(Result).FElementDef:=FElementDef;
      end;


    procedure TArrayDef.BuildDeref;
      begin
        inherited BuildDeref;
        TArraySymTable(SymTable).BuildDeref;
        FElementDefDeref.Build(FElementDef);
        RangeDefDeref.Build(RangeDef);
      end;


    procedure TArrayDef.Deref;
      begin
        inherited Deref;
        TArraySymTable(SymTable).Deref(False);
        FElementDef:=TDef(FElementDefDeref.Resolve);
        RangeDef:=TDef(RangeDefDeref.Resolve);
      end;


    procedure TArrayDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(FElementDefDeref);
         PPUFile.PutDeref(RangeDefDeref);
         PPUFile.PutASizeInt(LowRange);
         PPUFile.PutASizeInt(HighRange);
         PPUFile.PutSet(TPPUSet2(ArrayOptions));
         WriteEntry(PPUFile,IBArrayDef);
         TArraySymTable(SymTable).PPUWrite(PPUFile);
      end;


    function TArrayDef.EleSize : ASizeInt;
      begin
        if (ado_IsBitPacked in ArrayOptions) then
          InternalError(2006080101);
        if Assigned(FElementDef) then
          Result:=FElementDef.Size
        else
          Result:=0;
      end;


    function TArrayDef.ElePackedBitSize : ASizeInt;
      begin
        if not(ado_IsBitPacked in ArrayOptions) then
          InternalError(2006080102);
	if Assigned(FElementDef) then
          Result:=FElementDef.PackedBitSize
	else
	  Result:=0;
      end;


    function TArrayDef.EleCount : ASizeUInt;
      var
        QHigh,QLow : QWord;
      begin
        if ado_IsDynamicArray in ArrayOptions then
          begin
            Result:=0;
            Exit;
          end;
        { check whether the range might be larger than high(asizeint). Has
          to include 0..high(sizeint), since that's high(sizeint)+1 elements }
        if (HighRange>=0) and (LowRange<=0) then
          begin
            QHigh:=HighRange;
            if LowRange=Low(ASizeInt) then
              QLow:=High(ASizeInt) + 1
            else
              QLow:=QWord(-LowRange);
            { prevent overflow, return 0 to indicate overflow }
            if QHigh+QLow>QWord(High(ASizeInt)-1) then
              Result:=0
            else
              Result:=QHigh+QLow+1;
          end
        else
          Result:=Int64(HighRange)-LowRange+1;
      end;


    function TArrayDef.Size : ASizeInt;
      var
        CachedEleCount : ASizeUInt;
        CachedEleSize : ASizeInt;
      begin
        if ado_IsDynamicArray in ArrayOptions then
          begin
            Size:=VoidPointerType.Size;
            Exit;
          end;

        { Tarraydef.size may never be called for an open array! }
        if ado_OpenArray in ArrayOptions then
          InternalError(99080501);
        if not (ado_IsBitPacked in ArrayOptions) then
          CachedEleSize:=EleSize
        else
          CachedEleSize := ElePackedBitSize;
        CachedEleCount:=EleCount;

        if (CachedEleSize = 0) then
          begin
            Size := 0;
            Exit;
          end;

        if (CachedEleCount = 0) then
          begin
            if ado_isconststring in ArrayOptions then
              Size := 0
            else
              Size := -1;
            Exit;
          end;

        { prevent overflow, return -1 to indicate overflow }
        { also make sure we don't need 64/128 bit arithmetic to calculate offsets }
        if (CachedEleCount > ASizeUInt(High(ASizeInt))) or
           ((High(ASizeInt) div CachedEleSize) < ASizeInt(CachedEleCount)) or
           { also lowrange*elesize must be < high(asizeint) to prevent overflow when
             accessing the array, see ncgmem (PFV) }
           ((High(ASizeInt) div CachedEleSize) < Abs(LowRange)) then
          begin
            Result:=-1;
            Exit;
          end;

        Result:=CachedEleSize*ASizeInt(CachedEleCount);
        if (ado_IsBitPacked in ArrayOptions) then
          { can't just add 7 and divide by 8, because that may overflow }
          Result:=Result div 8 + Ord((Result mod 8)<>0);

      end;


    procedure TArrayDef.SetElementDef(Def:TDef);
      begin
        FElementDef:=Def;
        if not(
               (ado_IsDynamicArray in ArrayOptions) or
               (ado_IsConvertedPointer in ArrayOptions) or
               (ado_IsConstructor in ArrayOptions) or
               (ado_IsGeneric in ArrayOptions) or
               (HighRange<LowRange)
	      ) and
           (Size=-1) then
          Message(sym_e_segment_too_large);
      end;


    function TArrayDef.Alignment : ShortInt;
      begin
        if ado_IsVector in ArrayOptions then
           Alignment:=Size
         { alignment of dyn. arrays doesn't depend on the element size }
         else if ado_IsDynamicArray in ArrayOptions then
           Alignment:=VoidPointerType.Alignment
         { alignment is the target alignment for the used load size }
         else if (ado_IsBitPacked in ArrayOptions) and
            (ElementDef.Typ in [EnumDef,OrdDef]) then
           Alignment:=cgsize_orddef(int_cgsize(PackedBitsLoadSize(ElePackedBitSize))).Alignment
         { alignment is the alignment of the elements }
         else
           Alignment:=ElementDef.Alignment
      end;


    function TArrayDef.NeedsInitTable : Boolean;
      begin
         NeedsInitTable:=(ado_IsDynamicArray in ArrayOptions) or ElementDef.NeedsInitTable;
      end;

    function TArrayDef.NeedsSeparateInitRTTI : Boolean;
      begin
        if ado_IsBitPacked in ArrayOptions then
          Result:=False
        else
          Result:=ElementDef.NeedsSeparateInitRTTI;
      end;

    function TArrayDef.GetTypeName : string;
      begin
         if (ado_IsConstString in ArrayOptions) then
           Result:='Constant String'
         else if (ado_isarrayofconst in ArrayOptions) or
                 (ado_isConstructor in ArrayOptions) then
           begin
             if (ado_isvariant in ArrayOptions) or ((HighRange=-1) and (LowRange=0)) then
               GetTypeName:='Array Of Const'
             else
               GetTypeName:='{Array Of Const/Constant Open} Array of '+ElementDef.TypeName;
           end
         else if (ado_IsDynamicArray in ArrayOptions) then
           GetTypeName:='{Dynamic} Array Of '+ElementDef.TypeName
         else if (ado_OpenArray in ArrayOptions) then
           GetTypeName:='{Open} Array Of '+ElementDef.TypeName
         else
           begin
              Result := '';
              if (ado_IsBitPacked in ArrayOptions) then
                Result:='BitPacked ';
              if RangeDef.Typ=EnumDef then
                Result:=Result+'Array['+RangeDef.TypeName+'] Of '+ElementDef.TypeName
              else
                Result:=Result+'Array['+ToStr(LowRange)+'..'+
                  ToStr(HighRange)+'] Of '+ElementDef.TypeName
           end;
      end;


    function TArrayDef.GetMangledParaName : TSymStr;
      begin
         if ado_isarrayofconst in ArrayOptions then
          GetMangledParaName:='array_of_const'
         else
          if ((HighRange=-1) and (LowRange=0)) then
           GetMangledParaName:='array_of_'+ElementDef.MangledParaName
         else
          InternalError(200204176);
      end;


    function TArrayDef.IsPublishable : TPublishProperty;
      begin
         if ado_IsDynamicArray in ArrayOptions then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TArrayDef.Is_HWVector: Boolean;
      begin
        Result:=ado_IsVector in ArrayOptions;
      end;

{***************************************************************************
                              tabstractrecorddef
***************************************************************************}

    constructor TAbstractRecordDef.Create(const N:string; DT:TDefTyp;DoRegister:Boolean);
      begin
        inherited Create(DT,DoRegister);
        ObjName:=StringDup(Upper(N));
        ObjRealName:=StringDup(N);
        ObjectOptions:=[];
      end;

    constructor TAbstractRecordDef.PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
      var
        RO: TRTTIOption;
      begin
        inherited PPULoad(DT,PPUFile);
        ObjRealName:=PPUFile.GetPShortString;
        ObjName:=StringDup(Upper(ObjRealName^));
        ImportLib:=PPUFile.GetPShortString;

        if (ImportLib^='') then
          StringDispose(ImportLib);
        PPUFile.GetSet(TPPUSet4(ObjectOptions));
        RTTI.Clause:=TRTTIClause(PPUFile.GetByte);
        for RO in TRTTIOption do
          PPUFile.GetSet(TPPUSet1(RTTI.Options[RO]));
      end;

    procedure TAbstractRecordDef.PPUWrite(PPUFile: TCompilerPPUFile);
      var
        RO: TRTTIOption;
      begin
        inherited PPUWrite(PPUFile);
        PPUFile.PutString(ObjRealName^);
        if Assigned(ImportLib) then
          PPUFile.PutString(ImportLib^)
        else
          PPUFile.PutString('');
        PPUFile.PutSet(TPPUSet4(ObjectOptions));
        PPUFile.PutByte(Byte(RTTI.Clause));
        for RO in TRTTIOption do
          PPUFile.PutSet(TPPUSet1(RTTI.Options[RO]));
      end;

    destructor TAbstractRecordDef.Destroy;
      begin
        StringDispose(ObjName);
        StringDispose(ObjRealName);
        StringDispose(ImportLib);
        TCInitCode.Free;
        TCInitCode := nil;
        inherited Destroy;
      end;


    procedure TAbstractRecordDef.BuildDerefImpl;
      begin
         inherited BuildDerefImpl;
         if not (df_copied_def in DefOptions) then
           TStoredSymTable(SymTable).BuildDerefImpl;
      end;


    procedure TAbstractRecordDef.DerefImpl;
      begin
        inherited DerefImpl;
        if not (df_copied_def in DefOptions) then
          TStoredSymTable(SymTable).DerefImpl(False);
      end;


    procedure TAbstractRecordDef.Check_Forwards;
      begin
        { the defs of a copied def are defined for the original type only }
        if not(df_copied_def in DefOptions) then
          TStoredSymTable(SymTable).Check_Forwards;
      end;

    function TAbstractRecordDef.Find_ProcDef_ByType(PT:TProcTypeOption): TProcDef;
      var
        I: LongInt;
        Sym: TSym;
      begin
        for I:=0 to SymTable.SymList.Count-1 do
          begin
            Sym:=TSym(SymTable.SymList[I]);
            if Sym.Typ=ProcSym then
              begin
                Result:=TProcSym(Sym).Find_ProcDef_ByType(PT);
                if Assigned(Result) then
                  Exit;
              end;
          end;
          Result:=nil;
      end;

    function TAbstractRecordDef.GetSymTable(T:TGetSymTable):TSymTable;
      begin
        if T=gs_record then
          GetSymTable:=SymTable
        else
          GetSymTable:=nil;
      end;


    function TAbstractRecordDef.Is_Packed:Boolean;
      begin
        Result:=TAbstractRecordSymTable(SymTable).Is_Packed;
      end;

    function TAbstractRecordDef.RTTIName: string;

        function GenerateFullParamName(MaxLength:LongInt):string;
          const
            CommaCount : array[Boolean] of LongInt = (0,1);
          var
            FullParas,
            ParamName : AnsiString;
            Module : TModule;
            Sym : TSym;
            Def : TDef;
            I : LongInt;
          begin
            { we want at least enough space for an ellipsis }
            if MaxLength<3 then
              InternalError(2014121203);
            FullParas:='';
            for I:=0 to GenericParas.Count-1 do
              begin
                Sym:=TSym(GenericParas[I]);
                Module:=Find_Module_From_SymTable(Sym.Owner);
                if not Assigned(Module) then
                  InternalError(2014121202);
                if not (Sym.Typ in [ConstSym,SymConst.TypeSym]) then
                  InternalError(2020042501);
                if Sym.Typ=ConstSym then
                  Def:=TConstSym(Sym).ConstDef
                else
                  Def:=TTypeSym(Sym).TypeDef;
                ParamName:=Module.RealModuleName^;
                if Def.Typ in [ObjectDef,RecordDef] then
                  ParamName:=ParamName+'.'+TAbstractRecordDef(Def).RTTIName
                else
                  ParamName:=ParamName+'.'+Def.TypeName;
                if Length(FullParas)+CommaCount[I>0]+Length(ParamName)>MaxLength then
                  begin
                    if I>0 then
                      FullParas:=FullParas+',...'
                    else
                      FullParas:=FullParas+'...';
                    Break;
                  end;
                { could we fit an ellipsis after this parameter if it should be too long? }
                if (MaxLength-(Length(FullParas)+CommaCount[I>0]+Length(ParamName))<4) and (I<GenericParas.Count-1) then
                  begin
                    { then omit already this parameter }
                    if I>0 then
                      FullParas:=FullParas+',...'
                    else
                      FullParas:=FullParas+'...';
                    Break;
                  end;
                if I>0 then
                  FullParas:=FullParas+',';
                FullParas:=FullParas+ParamName;
              end;
            Result:=FullParas;
          end;

      var
        NonGeneric,
        BaseName : string;
        I,
        RemLength,
        ParamCount,
        CRCIdx : LongInt;
      begin
        if RTTIString='' then
          begin
            if Is_Specialization then
              begin
                RTTIString:=OwnerHierarchyName;
                { there should be two $ characters, one before the CRC and one before the count }
                CRCIdx:=-1;
                for I:=Length(ObjRealName^) downto 1 do
                  if ObjRealName^[I]='$' then
                    begin
                      CRCIdx:=I;
                      Break;
                    end;
                if CRCIdx<0 then
                  InternalError(2014121201);
                BaseName:=Copy(ObjRealName^,1,CRCIdx-1);
                split_generic_name(BaseName,NonGeneric,ParamCount);
                RTTIString:=RTTIString+NonGeneric+'<';
                RemLength:=255-Length(RTTIString)-1;
                if RemLength<4 then
                  RTTIString:=RTTIString+'>'
                else
                  RTTIString:=RTTIString+GenerateFullParamName(RemLength)+'>';
              end
            else
              if Is_Generic then
                begin
                  RTTIString:=OwnerHierarchyName;
                  split_generic_name(ObjRealName^,NonGeneric,ParamCount);
                  RTTIString:=RTTIString+NonGeneric+'<';
                  { we don't want any ',' if there is only one parameter }
                  for I:=0 to ParamCount-1 do
                    RTTIString:=RTTIString+',';
                  RTTIString:=RTTIString+'>';
                end
              else
                RTTIString:=OwnerHierarchyName+ObjRealName^;
          end;
        Result:=RTTIString;
      end;

    function TAbstractRecordDef.Search_Enumerator_Get: TProcDef;
      var
        Sym : TSym;
        I : Integer;
        PD : TProcDef;
        HashedID : THashedIDString;
      begin
        Result:=nil;
        HashedID.ID:='GETENUMERATOR';
        Sym:=TSym(SymTable.FindWithHash(HashedID));
        if Assigned(Sym) and (Sym.Typ=ProcSym) then
          begin
            for I := 0 to TProcSym(Sym).ProcDefList.Count - 1 do
            begin
              PD := TProcDef(TProcSym(Sym).ProcDefList[I]);
              if (PD.ProcTypeOption = potype_function) and
                 (Is_Class_Or_Interface_Or_Object(PD.ReturnDef) or Is_Record(PD.ReturnDef)) and
                 (PD.Visibility >= vis_public) then
              begin
                Result:=PD;
                Exit;
              end;
            end;
          end;
      end;

    function TAbstractRecordDef.Search_Enumerator_Move: TProcDef;
      var
        Sym : TSym;
        I : Integer;
        PD : TProcDef;
        HashedID : THashedIDString;
      begin
        Result:=nil;
        // first search for po_enumerator_movenext method modifier
        // then search for public function MoveNext: Boolean
        for I:=0 to SymTable.SymList.Count-1 do
          begin
            Sym:=TSym(SymTable.SymList[I]);
            if (Sym.Typ=ProcSym) then
            begin
              PD:=TProcSym(Sym).Find_ProcDef_ByOptions([po_enumerator_movenext]);
              if Assigned(PD) then
                begin
                  Result:=PD;
                  Exit;
                end;
            end;
          end;
        HashedID.ID:='MOVENEXT';
        Sym:=TSym(SymTable.FindWithHash(HashedID));
        if Assigned(Sym) and (Sym.Typ=ProcSym) then
          begin
            for I:=0 to TProcSym(Sym).ProcDefList.Count-1 do
            begin
              PD := TProcDef(TProcSym(Sym).ProcDefList[I]);
              if (PD.ProcTypeOption = potype_function) and
                 is_boolean(PD.ReturnDef) and
                 (PD.MinParaCount = 0) and
                 (PD.Visibility >= vis_public) then
              begin
                Result:=PD;
                Exit;
              end;
            end;
          end;
      end;

    function TAbstractRecordDef.Search_Enumerator_Current: TSym;
      var
        Sym: TSym;
        I: Integer;
        HashedID : THashedIDString;
      begin
        Result:=nil;
        // first search for ppo_enumerator_current property modifier
        // then search for public property Current
        for I:=0 to SymTable.SymList.Count-1 do
          begin
            Sym:=TSym(SymTable.SymList[I]);
            if (Sym.Typ=PropertySym) and (ppo_enumerator_current in TPropertySym(Sym).PropOptions) then
            begin
              Result:=Sym;
              Exit;
            end;
          end;
        HashedID.ID:='CURRENT';
        Sym:=TSym(SymTable.FindWithHash(HashedID));
        if Assigned(Sym) and (Sym.Typ=PropertySym) and
           (Sym.Visibility >= vis_public) and not TPropertySym(Sym).PropAccessList[palt_read].Empty then
          begin
            Result:=Sym;
            Exit;
          end;
      end;


    function TAbstractRecordDef.Contains_Float_Field: Boolean;
      var
        I : LongInt;
      begin
        Result:=True;
        for I:=0 to SymTable.SymList.Count-1 do
          begin
            if (TSym(SymTable.SymList[I]).Typ<>FieldVarSym) or
               (sp_static in TSym(SymTable.SymList[I]).SymOptions) then
              Continue;
            if Assigned(TFieldVarSym(SymTable.SymList[I]).VarDef) then
              begin
                if TStoredDef(TFieldVarSym(SymTable.SymList[I]).VarDef).Is_FPURegable then
                  Exit;
                { search recursively }
                if (TStoredDef(TFieldVarSym(SymTable.SymList[I]).VarDef).Typ=RecordDef) and
                  (TAbstractRecordDef(TFieldVarSym(SymTable.SymList[I]).VarDef).Contains_Float_Field) then
                  Exit;
              end;
          end;
        Result:=False;
      end;


    function TAbstractRecordDef.Contains_Cross_AWord_Field: Boolean;
      var
        I : LongInt;
        FOffset, FSize: AWord;
      begin
        Result:=True;
        for I:=0 to SymTable.SymList.Count-1 do
          begin
            if (TSym(SymTable.SymList[I]).Typ<>FieldVarSym) or
               (sp_static in TSym(SymTable.SymList[I]).SymOptions) then
              Continue;
            if Assigned(TFieldVarSym(SymTable.SymList[I]).VarDef) then
              begin
                if Is_Packed then
                  begin
                    FOffset:=TFieldVarSym(SymTable.SymList[I]).FieldOffset;
                    FSize:=TFieldVarSym(SymTable.SymList[I]).VarDef.PackedBitSize;
                  end
                else
                  begin
                    FOffset:=TFieldVarSym(SymTable.SymList[I]).FieldOffset*8;
                    FSize:=TFieldVarSym(SymTable.SymList[I]).VarDef.Size*8;
                  end;
                if (FSize>0) and ((FOffset div (SizeOf(AWord)*8)) <> ((FOffset+FSize-1) div (SizeOf(AWord)*8))) then
                  Exit;
                { search recursively }
                if (TStoredDef(TFieldVarSym(SymTable.SymList[I]).VarDef).Typ=RecordDef) and
                  (TAbstractRecordDef(TFieldVarSym(SymTable.SymList[I]).VarDef).Contains_Cross_AWord_Field) then
                  Exit;
              end;
          end;
        Result:=False;
      end;


    procedure TAbstractRecordDef.Apply_RTTI_Directive(Dir: TRTTIDirective);
      begin
        { records don't support the inherit clause but shouldn't
          give an error either if used (for Delphi compatibility),
          so we silently enforce the clause as explicit. }
        RTTI.Clause:=rtc_explicit;
        RTTI.Options:=Dir.Options;
      end;


    function TAbstractRecordDef.Is_Visible_For_RTTI(Option: TRTTIOption; Vis: TVisibility): Boolean;
      begin
        case Vis of
          vis_private,
          vis_strictprivate:   Result:=rv_private in RTTI.Options[Option];
          vis_protected,
          vis_strictprotected: Result:=rv_protected in RTTI.Options[Option];
          vis_public:          Result:=rv_public in RTTI.Options[Option];
          vis_published:       Result:=rv_published in RTTI.Options[Option];
          otherwise
            Result:=False;
        end;
      end;


    function TAbstractRecordDef.RTTI_Visibilities_For_Option(Option: TRTTIOption): TVisibilities;
      begin
        Result:=[];
        if rv_private in RTTI.Options[Option] then
          begin
            Include(Result,vis_private);
            Include(Result,vis_strictprivate);
          end;
        if rv_protected in RTTI.Options[Option] then
          begin
            Include(Result,vis_protected);
            Include(Result,vis_strictprotected);
          end;
        if rv_public in RTTI.Options[Option] then
          Include(Result,vis_public);
        if rv_published in RTTI.Options[Option] then
          Include(Result,vis_published);
      end;


    function TAbstractRecordDef.Has_Extended_RTTI: Boolean;
      begin
        Result := (RTTI.Options[ro_fields]<>[]) or
                  (RTTI.Options[ro_methods]<>[]) or
                  (RTTI.Options[ro_properties]<>[]);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TAbstractRecordDef.XMLPrintDefData(var T: Text; Sym: TSym);

      procedure WriteSymOptions(SourceSym: TSym);
        var
          I: TSymOption;
          First: Boolean;
        begin
          First := True;
          for I := Low(TSymOption) to High(TSymOption) do
            if I in SourceSym.SymOptions then
              begin
                if First then
                  begin
                    Write(T, '" symoptions="', I);
                    First := False;
                  end
                else
                  Write(T, ',', I)
              end;
        end;

      var
        List: TFPHashObjectList;
        I: Integer;
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

        { List the fields }
        List := SymTable.SymList;
        for I := 0 to List.Count - 1 do
          case TSym(List[I]).Typ of
{            staticvarsym,localvarsym,paravarsym,fieldvarsym,
            typesym,procsym,unitsym,}
            ConstSym:
              with TConstSym(List[I]) do
                begin
                  Write(T, PrintNodeIndention, '<const name="', RealName, '" pos="', FileInfo.Line, ',', FileInfo.Column);
                  WriteSymOptions(TSym(List[I]));
                  WriteLn(T, '">');
                  PrintNodeIndent;
                  XMLPrintConstData(T);
                  PrintNodeUnindent;
                  WriteLn(T, PrintNodeIndention, '</const>');
                end;
 {
            errorsym,syssym,labelsym,absolutevarsym,propertysym,
            macrosym,namespacesym,undefinedsym,programparasym
}
            FieldVarSym:
              with TFieldVarSym(List[I]) do
                begin
                  Write(T, PrintNodeIndention, '<field name="', RealName, '" pos="', FileInfo.Line, ',', FileInfo.Column);
                  WriteSymOptions(TSym(List[I]));
                  WriteLn(T, '">');
                  PrintNodeIndent;
                  XMLPrintFieldData(T);
                  PrintNodeUnindent;
                  WriteLn(T, PrintNodeIndention, '</field>');
                end;
            else
              ;
          end;
      end;
{$endif DEBUG_NODE_XML}

    procedure TAbstractRecordDef.SetObjRealName(const N:string);
      begin
        FreeMem(ObjRealName);
        ObjRealName:=StringDup(N);
      end;

{***************************************************************************
                                  trecorddef
***************************************************************************}

    constructor TRecordDef.Create(const N:string; P:TSymTable);
      begin
         inherited Create(N,RecordDef,True);
         SymTable:=P;
         { we can own the symtable only if nobody else owns a copy so far }
         if SymTable.RefCount=1 then
           SymTable.DefOwner:=Self;
         IsUnion:=False;
         ClonedDefDeref.Reset;
      end;


    constructor TRecordDef.Create_Internal(const N: string; PackRecords, RecordAlignMin: ShortInt; Where: TSymTable);
      var
        Name : string;
        OldSymTableStack: TSymTableStack;
        TS: TTypeSym;
      begin
        { construct name }
        if N<>'' then
          Name:=N
        else
          begin
            InitDefID;
            Name:='$InternalRec'+UniqueIDStr;
          end;
        OldSymTableStack:=SymTableStack;
        { do not simply push/pop current_module.localsymtable, because
          that can have side-effects (e.g., it removes helpers) }
        SymTableStack:=nil;

        SymTable:=TRecordSymTable.Create(Name,PackRecords,RecordAlignMin);
        SymTable.DefOwner:=Self;
        IsUnion:=False;
        inherited Create(Name,RecordDef,True);
        Where.InsertDef(Self);
        { if we specified a name, then we'll probably want to look up the
          type again by name too -> create typesym }
        if N<>'' then
          begin
            TS:=CTypeSym.Create(N,Self);
            Include(TS.SymOptions,sp_internal);
            { avoid hints about unused types (these may only be used for
              typed constant data) }
            TS.IncRefCount;
            Where.InsertSym(TS);
          end;
        SymTableStack:=OldSymTableStack;
        { don't create RTTI for internal types, these are not exported }
        DefStates:=DefStates+[ds_rtti_table_written,ds_init_table_written];
        Include(DefOptions,df_internal);
      end;


    constructor TRecordDef.Create_Global_Internal(const N: string; PackRecords, RecordAlignMin: ShortInt);
      var
        Where : TSymTable;
      begin
        Where:=CurrentModule.LocalSymTable;
        if not Assigned(Where) then
          Where:=CurrentModule.GlobalSymTable;
        Create_Internal(N,PackRecords,RecordAlignMin,Where);
      end;


    function TRecordDef.Add_Field_By_Def(const OptionalName: TIDString; Def: TDef): TSym;
      var
        Sym: TFieldVarSym;
        Name: TIDString;
        PName: ^TIDString;
      begin
        if OptionalName='' then
          begin
            Name:='$f'+ToStr(TRecordSymTable(SymTable).SymList.Count);
            PName:=@Name
          end
        else
          PName:=@OptionalName;
        Sym:=CFieldVarSym.Create(PName^,vs_value,Def,[]);
        SymTable.InsertSym(Sym);
        TRecordSymTable(SymTable).AddField(Sym,vis_hidden);
        Result:=Sym;
      end;


    procedure TRecordDef.Add_Fields_From_DefList(FieldTypes: TFPList);
      var
        I: LongInt;
      begin
        for I:=0 to FieldTypes.Count-1 do
          Add_Field_By_Def('',TDef(FieldTypes[I]));
      end;


    constructor TRecordDef.PPULoad(PPUFile:TCompilerPPUFile);

      procedure ReadVariantRecDesc(var VariantRecDesc : PVariantRecDesc);
        var
          I,J : LongInt;
        begin
         if PPUFile.GetByte=1 then
           begin
             New(VariantRecDesc);
             PPUFile.GetDeref(VariantRecDesc^.VariantSelectorDeref);
             SetLength(VariantRecDesc^.Branches,PPUFile.GetASizeInt);
             for I:=0 to High(VariantRecDesc^.Branches) do
               begin
                 SetLength(VariantRecDesc^.Branches[I].Values,PPUFile.GetASizeInt);
                 for J:=0 to High(VariantRecDesc^.Branches[I].Values) do
                   VariantRecDesc^.Branches[I].Values[J]:=PPUFile.GetExprInt;
                 ReadVariantRecDesc(VariantRecDesc^.Branches[I].NestedVariant);
               end;
           end
         else
           VariantRecDesc:=nil;
        end;

      begin
         inherited PPULoad(RecordDef,PPUFile);
         if df_copied_def in DefOptions then
           begin
             PPUFile.GetDeref(ClonedDefDeref);
             PPULoadPlatform(PPUFile);
           end
         else
           begin
             SymTable:=TRecordSymTable.Create(ObjRealName^,0,0);
             TRecordSymTable(SymTable).FieldAlignment:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).RecordAlignment:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).ExplicitRecordAlignment:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).PadAlignment:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).UseFieldAlignment:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).RecordAlignMin:=ShortInt(PPUFile.GetByte);
             TRecordSymTable(SymTable).DataSize:=PPUFile.GetASizeInt;
             TRecordSymTable(SymTable).PaddingSize:=PPUFile.GetWord;
             PPUFile.GetSet(TPPUSet1(TRecordSymTable(SymTable).ManagementOperators));
             { position of ppuload_platform call must correspond
               to position of writeentry in ppuwrite method }
             PPULoadPlatform(PPUFile);
             TRecordSymTable(SymTable).PPULoad(PPUFile);
             { the variantrecdesc is needed only for iso-like new statements new(prec,1,2,3 ...);
               but because iso mode supports no units, there is no need to store the variantrecdesc
               in the ppu
             }
             // readvariantrecdesc(variantrecdesc);
             { requires usefieldalignment to be set }
             SymTable.DefOwner:=Self;
           end;
         IsUnion:=False;
      end;


    destructor TRecordDef.Destroy;

      procedure FreeVariantRecDesc(var VariantRecDesc : PVariantRecDesc);
        var
          I : LongInt;
        begin
         while Assigned(VariantRecDesc) do
           begin
             for I:=0 to High(VariantRecDesc^.Branches) do
               begin
                 FreeVariantRecDesc(VariantRecDesc^.Branches[I].NestedVariant);
                 SetLength(VariantRecDesc^.Branches[I].Values,0);
               end;
             SetLength(VariantRecDesc^.Branches,0);
             Dispose(VariantRecDesc);
             VariantRecDesc:=nil;
           end;
        end;

      begin
         if Assigned(VariantRecDesc) then
           FreeVariantRecDesc(VariantRecDesc);
         if Assigned(SymTable) then
           begin
             SymTable.Free;
             SymTable:=nil;
           end;
         inherited Destroy;
      end;


    function TRecordDef.GetCopy : TStoredDef;
      begin
        Result:=CRecordDef.Create(ObjRealName^,SymTable.GetCopy);
        TRecordDef(Result).IsUnion:=IsUnion;
        Include(TRecordDef(Result).DefOptions,df_copied_def);
        if Assigned(TCInitCode) then
          TRecordDef(Result).TCInitCode:=TCInitCode.GetCopy;
         if Assigned(ImportLib) then
           TRecordDef(Result).ImportLib:=StringDup(ImportLib^);
      end;


    function TRecordDef.NeedsInitTable : Boolean;
      begin
        { each record with managed field or with any management operator needs
          init table }
        NeedsInitTable:=(TRecordSymTable(SymTable).ManagementOperators<>[]) or
          TRecordSymTable(SymTable).Needs_Init_Final
      end;

    function TRecordDef.NeedsSeparateInitRTTI : Boolean;
      begin
        Result:=True;
      end;


    function TRecordDef.HasNonTrivialInitChild(CheckParent:Boolean):Boolean;
      begin
        Result:=TRecordSymTable(SymTable).Has_Non_Trivial_Init;
      end;


    procedure TRecordDef.BuildDeref;
      begin
         inherited BuildDeref;
         if df_copied_def in DefOptions then
           ClonedDefDeref.Build(SymTable.DefOwner)
         else
           TStoredSymTable(SymTable).BuildDeref;
      end;


    procedure TRecordDef.Deref;
      begin
         inherited Deref;
         { now dereference the definitions }
         if df_copied_def in DefOptions then
           begin
             ClonedDef:=TRecordDef(ClonedDefDeref.Resolve);
             SymTable:=ClonedDef.SymTable.GetCopy;
           end
         else
           TStoredSymTable(SymTable).Deref(False);

         { internal types, only load from the system unit }
         if Assigned(Owner) and
            Assigned(Owner.Name) and
            (Owner.Name^='SYSTEM') then
           begin
             { TGUID  }
             if not Assigned(Rec_TGUID) and
                (Upper(TypeName)='TGUID') then
               Rec_TGUID:=Self
             { JMP_BUF }
             else if not Assigned(Rec_Jmp_Buf) and
                (Upper(TypeName)='JMP_BUF') then
               Rec_Jmp_Buf:=Self
             else if not Assigned(Rec_ExceptAddr) and
                (Upper(TypeName)='TEXCEPTADDR') then
               Rec_ExceptAddr:=Self;
           end;
      end;


    procedure TRecordDef.PPUWrite(PPUFile:TCompilerPPUFile);

      procedure WriteVariantRecDesc(VariantRecDesc : PVariantRecDesc);
        var
          I,J : LongInt;
        begin
         if Assigned(VariantRecDesc) then
           begin
             PPUFile.PutByte(1);
             PPUFile.PutDeref(VariantRecDesc^.VariantSelectorDeref);
             PPUFile.PutASizeInt(Length(VariantRecDesc^.Branches));
             for I:=0 to High(VariantRecDesc^.Branches) do
               begin
                 PPUFile.PutASizeInt(Length(VariantRecDesc^.Branches[I].Values));
                 for J:=0 to High(VariantRecDesc^.Branches[I].Values) do
                   PPUFile.PutExprInt(VariantRecDesc^.Branches[I].Values[J]);
                 WriteVariantRecDesc(VariantRecDesc^.Branches[I].NestedVariant);
               end;
           end
         else
           PPUFile.PutByte(0);
        end;

      begin
         inherited PPUWrite(PPUFile);
         if df_copied_def in DefOptions then
           PPUFile.PutDeref(ClonedDefDeref)
         else
           begin
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).FieldAlignment));
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).RecordAlignment));
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).ExplicitRecordAlignment));
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).PadAlignment));
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).UseFieldAlignment));
             PPUFile.PutByte(Byte(TRecordSymTable(SymTable).RecordAlignMin));
             PPUFile.PutASizeInt(TRecordSymTable(SymTable).DataSize);
             PPUFile.PutWord(TRecordSymTable(SymTable).PaddingSize);
             PPUFile.PutSet(TPPUSet1(TRecordSymTable(SymTable).ManagementOperators));
             { the variantrecdesc is needed only for iso-like new statements new(prec,1,2,3 ...);
               but because iso mode supports no units, there is no need to store the variantrecdesc
               in the ppu
             }
             // writevariantrecdesc(variantrecdesc);
           end;

         WriteEntry(PPUFile,IBRecordDef);

         if not(df_copied_def in DefOptions) then
           TRecordSymTable(SymTable).PPUWrite(PPUFile);
      end;


    function TRecordDef.Size:ASizeInt;
      begin
        Result:=TRecordSymTable(SymTable).DataSize;
      end;


    function TRecordDef.Alignment:ShortInt;
      begin
        Alignment:=TRecordSymTable(SymTable).RecordAlignment;
      end;


    function TRecordDef.PadAlignment:ShortInt;
      begin
        PadAlignment := TRecordSymTable(SymTable).PadAlignment;
      end;


    function TRecordDef.GetTypeName : string;
      begin
        if Assigned(TypeSym) then
          GetTypeName:='<record type '+TypeSymbolPrettyName+'>'
        else
          GetTypeName:='<record type>';
      end;

{$ifdef DEBUG_NODE_XML}
    function TRecordDef.XMLPrintType: AnsiString;
      begin
        Result := '&lt;record&gt;';
      end;
{$endif DEBUG_NODE_XML}

{***************************************************************************
                       TABSTRACTPROCDEF
***************************************************************************}

    constructor TAbstractProcDef.Create(DT:TDefTyp;Level:Byte;DoRegister:Boolean);
      begin
         inherited Create(DT,DoRegister);
         ParaST:=TParaSymTable.Create(Self,Level);
         Paras:=nil;
         MinParaCount:=0;
         MaxParaCount:=0;
         ProcTypeOption:=potype_none;
         ProcCallOption:=pocall_none;
         ProcOptions:=[];
         ReturnDef:=VoidType;
         ReturnDefDeref.Reset;
         SaveSize:=SizeOf(PInt);
         CallerArgAreaSize:=0;
         CalleeArgAreaSize:=0;
         HasParaLocInfo:=CallNoSide;
         FuncRetLoc[CallerSide].Init;
         FuncRetLoc[CalleeSide].Init;
         Check_Mark_As_Nested;
      end;


    destructor TAbstractProcDef.Destroy;
      begin
         if Assigned(Paras) then
           begin
{$ifdef MEMDEBUG}
             MemProcPara.Start;
{$endif MEMDEBUG}
             Paras.Free;
             Paras:=nil;
{$ifdef MEMDEBUG}
             MemProcPara.Stop;
{$endif MEMDEBUG}
          end;
         if Assigned(ParaST) then
          begin
{$ifdef MEMDEBUG}
            MemProcParaST.Start;
{$endif MEMDEBUG}
            ParaST.Free;
            ParaST:=nil;
{$ifdef MEMDEBUG}
            MemProcParaST.Stop;
{$endif MEMDEBUG}
          end;
         FuncRetLoc[CallerSide].Done;
         FuncRetLoc[CalleeSide].Done;
         inherited Destroy;
      end;


    procedure TAbstractProcDef.CountPara(P:TObject;Arg:Pointer);
      begin
        if (TSym(P).Typ<>ParaVarSym) then
          Exit;
        Inc(PLongInt(Arg)^);
        if not(vo_is_hidden_para in TParaVarSym(P).VarOptions) then
         begin
           if not Assigned(TParaVarSym(P).DefaultConstSym) then
             Inc(MinParaCount);
           Inc(MaxParaCount);
         end;
      end;


    procedure TAbstractProcDef.InsertPara(P:TObject;Arg:Pointer);
      begin
        if (TSym(P).Typ<>ParaVarSym) then
          Exit;
        Paras.Add(P);
      end;


    procedure TAbstractProcDef.CalcParas;
      var
        ParaCount : LongInt;
      begin
        { This can already be assigned when
          we need to reresolve this unit (PFV) }
        if Assigned(Paras) then
          Paras.Free;
        Paras:=TParaList.Create(False);
        ParaCount:=0;
        MinParaCount:=0;
        MaxParaCount:=0;
        ParaST.SymList.ForEachCall(@CountPara,@ParaCount);
        Paras.Capacity:=ParaCount;
        { Insert parameters in table }
        ParaST.SymList.ForEachCall(@InsertPara,nil);
        { Order parameters }
        Paras.SortParas;
      end;


    function TAbstractProcDef.MangledProcParaNames(OldLen : LongInt) : string;
      var
        Hash  : QWord;
        HP   : TParaVarSym;
        HS   : TSymStr;
        NewLen,
        I    : Integer;
      begin
        Result:='';
        HP:=nil;
        { add parameter types }
        for I:=0 to Paras.Count-1 do
         begin
           HP:=TParaVarSym(Paras[I]);
           if not(vo_is_hidden_para in HP.VarOptions) then
             begin
               if not Assigned(HP.VarDef) then
                 InternalError(2025122401);
               Result:=Result+'$'+HP.VarDef.MangledParaName;
             end;
         end;
        { add resultdef, add $$ as separator to make it unique from a
          parameter separator }
        if not is_void(ReturnDef) then
          Result:=Result+'$$'+ReturnDef.MangledParaName;
        NewLen:=Length(Result)+OldLen;
        { Replace with hash if the parameter line is very long }
        if (NewLen-OldLen>12) and
           ((NewLen>100) or (NewLen-OldLen>64)) then
          begin
            Hash:=InitFNV64;
            for I:=0 to Paras.Count-1 do
              begin
                HP:=TParaVarSym(Paras[I]);
                if not(vo_is_hidden_para in HP.VarOptions) then
                  begin
                    HS:=HP.VarDef.MangledParaName;
                    Hash:=UpdateFNV64(Hash,HS[1],Length(HS));
                  end;
              end;
            if not is_void(ReturnDef) then
              begin
                { add a little prefix so that x(integer; integer) is different from x(integer):integer }
                HS:='$$'+ReturnDef.MangledParaName;
                Hash:=UpdateFNV64(Hash,HS[1],Length(HS));
              end;
            Result:='$h'+Base64Mangle(Hash);
          end;
      end;


    procedure TAbstractProcDef.BuildDeref;
      begin
         { released procdef? }
         if not Assigned(ParaST) then
           Exit;
         inherited BuildDeref;
         ReturnDefDeref.Build(ReturnDef);
         if po_explicitparaloc in ProcOptions then
           FuncRetLoc[CallerSide].BuildDeref;
         { parast }
         TParaSymTable(ParaST).BuildDeref;
      end;


    procedure TAbstractProcDef.Deref;
      begin
         inherited Deref;
         ReturnDef:=TDef(ReturnDefDeref.Resolve);
         if po_explicitparaloc in ProcOptions then
           begin
             FuncRetLoc[CallerSide].Deref;
             HasParaLocInfo:=CallerSide;
            end
         else
           begin
             { deref is called after loading from a ppu, but also after another
               unit has been reloaded/recompiled and all references must be
               re-resolved. Since the funcretloc contains a reference to a tdef,
               reset it so that we won't try to access the stale def }
             FuncRetLoc[CallerSide].Init;
             HasParaLocInfo:=CallNoSide;
           end;
         { parast }
         TParaSymTable(ParaST).Deref(False);
         { recalculated parameters }
         CalcParas;
      end;


    constructor TAbstractProcDef.PPULoad(DT:TDefTyp;PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(DT,PPUFile);
         ParaST:=nil;
         Paras:=nil;
         MinParaCount:=0;
         MaxParaCount:=0;
         PPUFile.GetDeref(ReturnDefDeref);
         ProcTypeOption:=TProcTypeOption(PPUFile.GetByte);
         ProcCallOption:=TProcCallOption(PPUFile.GetByte);
         PPUFile.GetSet(TPPUSet8(ProcOptions));

         FuncRetLoc[CallerSide].Init;
         if po_explicitparaloc in ProcOptions then
           FuncRetLoc[CallerSide].PPULoad(PPUFile);

         SaveSize:=SizeOf(PInt);
         if (po_explicitparaloc in ProcOptions) then
           HasParaLocInfo:=CallerSide;
      end;


    procedure TAbstractProcDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         { released procdef? }
         if not Assigned(ParaST) then
           Exit;
         inherited PPUWrite(PPUFile);
         PPUFile.PutDeref(ReturnDefDeref);
         PPUFile.PutByte(Ord(ProcTypeOption));
         PPUFile.PutByte(Ord(ProcCallOption));
         PPUFile.PutSet(TPPUSet8(ProcOptions));

         if (po_explicitparaloc in ProcOptions) then
           FuncRetLoc[CallerSide].PPUWrite(PPUFile);
      end;


    function TAbstractProcDef.TypeName_Paras(PNo: TProcNameOptions) : AnsiString;
      var
        HS,S  : AnsiString;
        HP    : TParaVarSym;
        HPC   : TConstSym;
        First : Boolean;
        I,J   : Integer;
      begin
        S:='';
        First:=True;
        for I:=0 to Paras.Count-1 do
         begin
           HP:=TParaVarSym(Paras[I]);
           if not(vo_is_hidden_para in HP.VarOptions) or
              (pno_showhidden in PNo) then
            begin
               if First then
                begin
                  S:=S+'(';
                  First:=False;
                end
               else
                S:=S+';';
               if vo_is_hidden_para in HP.VarOptions then
                 S:=S+'<';
               case HP.VarSpez of
                 vs_var :
                   S:=S+'var ';
                 vs_const :
                   S:=S+'const ';
                 vs_out :
                   S:=S+'out ';
                 vs_constref :
                   S:=S+'constref ';
                 else
                   ;
               end;
               if (pno_paranames in PNo) then
                 S:=S+HP.RealName+':';
               if HP.UnivPara then
                 S:=S+'univ ';
               if Assigned(HP.VarDef.TypeSym) then
                 begin
                   HS:=HP.VarDef.TypeSym.RealName;
                   if HS[1]<>'$' then
                     S:=S+HP.VarDef.OwnerHierarchyName+HS
                   else
                     S:=S+HP.VarDef.GetTypeName;
                 end
               else
                 S:=S+HP.VarDef.GetTypeName;
               { default value }
               if Assigned(HP.DefaultConstSym) then
                begin
                  HPC:=TConstSym(HP.DefaultConstSym);
                  HS:='';
                  case HPC.ConstTyp of
                    ConstWResourceString,
                    ConstWString:
                      begin
                        if HPC.Value.ValueWS.Len>0 then
                          begin
                            SetLength(HS,HPC.Value.ValueWS.Len);
                            for J:=0 to HPC.Value.ValueWS.Len-1 do
                             begin
                               if (Ord(HPC.Value.ValueWS.Data[J])<127) and
                                  not(Byte(HPC.Value.ValueWS.Data[J]) in [0,10,13]) then
                                 HS[J+1]:=Char(HPC.Value.ValueWS.Data[J])
                               else
                                 HS[J+1]:='.';
                             end;
                          end;
                      end;
                    ConstString,
                    ConstResourceString :
                      begin
                        if HPC.Value.Len>0 then
                          begin
                            SetLength(HS,HPC.Value.Len);
                            { don't write past the end of hs if the constant
                              is > 255 chars }
                            Move(HPC.Value.ValuePtr^,HS[1],Length(HS));
                            { make sure that constant strings with newline chars
                              don't create a linebreak in the assembler code,
                              since comments are line-based. Also remove nulls
                              because the comments are written as a pchar. }
                            ReplaceCase(HS,#0,'.');
                            ReplaceCase(HS,#10,'.');
                            ReplaceCase(HS,#13,'.');
                          end;
                      end;
                    ConstReal :
                      HS:=RealToStr(PBestReal(HPC.Value.ValuePtr)^);
                    ConstPointer :
                      HS:=ToStr(HPC.Value.ValueOrdPtr);
                    ConstOrd :
                      begin
                        if is_boolean(HPC.ConstDef) then
                          begin
                            if HPC.Value.ValueOrd<>0 then
                             HS:='TRUE'
                            else
                             HS:='FALSE';
                          end
                        else
                          HS:=ToStr(HPC.Value.ValueOrd);
                      end;
                    ConstNil :
                      HS:='nil';
                    ConstSet :
                      HS:='<set>';
                    ConstGUID:
                      HS:=GUID2String(PGUID(HPC.Value.ValuePtr)^);
                    ConstNone:
                      InternalError(2019050704);
                  end;
                  if HS<>'' then
                   S:=S+'=`'+HS+'`';
                end;
               if vo_is_hidden_para in HP.VarOptions then
                 S:=S+'>';
             end;
         end;
        if not First then
         S:=S+')';
        if (po_varargs in ProcOptions) then
         S:=S+';VarArgs';
        TypeName_Paras:=S;
      end;


    function TAbstractProcDef.Is_MethodPointer:Boolean;
      begin
        Result:=False;
      end;


    function TAbstractProcDef.Is_AddressOnly:Boolean;
      begin
        Result:=True;
      end;

    function TAbstractProcDef.No_Self_Node: Boolean;
      begin
        Result:=([po_staticmethod,po_classmethod]<=ProcOptions)or
                (ProcTypeOption in [potype_class_constructor,potype_class_destructor,potype_operator]);
      end;


    function TAbstractProcDef.GetCopyAs(NewTyp:TDefTyp;CopyTyp:TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef;
      var
        J, NestingLevel: LongInt;
        PVS, NPVS: TParaVarSym;
      begin
        NestingLevel:=ParaST.SymTableLevel;
        if NewTyp=ProcDef then
          begin
            if (CopyTyp<>pc_bareproc) then
              Result:=CProcDef.Create(NestingLevel,DoRegister)
            else
              Result:=CProcDef.Create(normal_function_level,DoRegister);
            TProcDef(Result).Visibility:=vis_public;
          end
        else
          begin
            Result:=CProcVarDef.Create(NestingLevel,True);
          end;
        TAbstractProcDef(Result).ReturnDef:=ReturnDef;
        TAbstractProcDef(Result).ReturnDefDeref:=ReturnDefDeref;
        PVS:=nil;
        NPVS:=nil;
        if CopyTyp<>pc_normal_no_paras then
          begin
            for J:=0 to ParaST.SymList.Count-1 do
              begin
                case TSym(ParaST.SymList[J]).Typ of
                  ParaVarSym:
                    begin
                      PVS:=TParaVarSym(ParaST.SymList[J]);
                      { in case of bare proc, don't copy self, vmt or framepointer
                        parameters }
                      if (CopyTyp in [pc_bareproc,pc_normal_no_hidden]) and
                         (([vo_is_self,vo_is_vmt,vo_is_parentfp,vo_is_result,vo_is_funcret,vo_is_high_para]*PVS.VarOptions)<>[]) then
                        Continue;
                      if ParaPrefix='' then
                        NPVS:=CParaVarSym.Create(PVS.RealName,PVS.ParaNr,PVS.VarSpez,
                          PVS.VarDef,PVS.VarOptions)
                      else if not(vo_is_high_para in PVS.VarOptions) then
                        NPVS:=CParaVarSym.Create(ParaPrefix+PVS.RealName,PVS.ParaNr,PVS.VarSpez,
                          PVS.VarDef,PVS.VarOptions)
                      else
                        NPVS:=CParaVarSym.Create('$high'+ParaPrefix+Copy(PVS.Name,5,Length(PVS.Name)),PVS.ParaNr,PVS.VarSpez,
                          PVS.VarDef,PVS.VarOptions);
                      NPVS.DefaultConstSym:=PVS.DefaultConstSym;
                      TAbstractProcDef(Result).ParaST.InsertSym(NPVS);
                    end;
                  ConstSym:
                    begin
                      // ignore, reuse original constym. Should also be duplicated
                      // be safe though
                    end;
                  SymConst.TypeSym:
                    begin
                      // reuse original, part of generic declaration
                    end
                  else
                    InternalError(201160604);
                  end;
              end;
          end;
        TAbstractProcDef(Result).SaveSize:=SaveSize;

        if (Typ<>ProcVarDef) and
           (NewTyp=ProcVarDef) then
          begin
            { procvars can't be (class)constructors/destructors etc }
            if ProcTypeOption=potype_constructor then
              begin
                TAbstractProcDef(Result).ReturnDef:=TDef(Owner.DefOwner);
                if not(Is_Implicit_Pointer_Object_Type(ReturnDef) or
                   (ReturnDef.Typ<>ObjectDef)) then
                  TAbstractProcDef(Result).ReturnDef:=CPointerDef.GetReusable(TAbstractProcDef(Result).ReturnDef);
                TAbstractProcDef(Result).ProcTypeOption:=potype_function;
              end
            else if is_void(ReturnDef) then
              TAbstractProcDef(Result).ProcTypeOption:=potype_procedure
            else
              TAbstractProcDef(Result).ProcTypeOption:=potype_function;
          end
        else
          TAbstractProcDef(Result).ProcTypeOption:=ProcTypeOption;
        TAbstractProcDef(Result).ProcCallOption:=ProcCallOption;
        TAbstractProcDef(Result).ProcOptions:=ProcOptions;
        if (CopyTyp=pc_bareproc) then
          TAbstractProcDef(Result).ProcOptions:=TAbstractProcDef(Result).ProcOptions*[po_explicitparaloc,po_hascallingconvention,po_varargs,po_iocheck,po_has_importname,po_has_importdll];
        if NewTyp=ProcVarDef then
          TAbstractProcDef(Result).ProcOptions:=TAbstractProcDef(Result).ProcOptions-[po_has_importname,po_has_importdll];
        if CopyTyp=pc_address_only then
          Include(TAbstractProcDef(Result).ProcOptions,po_addressonly);

        TAbstractProcDef(Result).CallerArgAreaSize:=CallerArgAreaSize;
        TAbstractProcDef(Result).CalleeArgAreaSize:=CalleeArgAreaSize;
        TAbstractProcDef(Result).MaxParaCount:=MaxParaCount;
        TAbstractProcDef(Result).MinParaCount:=MinParaCount;
        if po_explicitparaloc in ProcOptions then
          TAbstractProcDef(Result).FuncRetLoc[CallerSide]:=FuncRetLoc[CallerSide].GetCopy;
        { recalculate parameter info }
        TAbstractProcDef(Result).HasParaLocInfo:=CallNoSide;
        if (Typ=ProcDef) and
           (NewTyp=ProcVarDef) and
           (Owner.SymTableType in [ObjectSymTable,RecordSymTable]) then
          Include(TProcVarDef(Result).ProcOptions,po_methodpointer);
      end;


    function TAbstractProcDef.Compatible_With_PointerDef_Size(Ptr: TPointerDef): Boolean;
      begin
        Result:=Is_AddressOnly;
      end;


    procedure TAbstractProcDef.Check_Mark_As_Nested;
      begin
         { nested procvars require that nested functions use the Delphi-style
           nested procedure calling convention }
         if (ParaST.SymTableLevel>normal_function_level) and
            (m_nested_procvars in CurrentSettings.ModeSwitches) then
           Include(ProcOptions,po_delphi_nested_cc);
      end;


    procedure TAbstractProcDef.Init_ParaLoc_Info(Side: TCallerCallee);
      begin
        if (Side in [CallerSide,CallBothSides]) and
           not(HasParaLocInfo in [CallerSide,CallBothSides]) then
          begin
            if not is_c_variadic(Self) then
              CallerArgAreaSize:=ParaManager.create_paraloc_info(Self,CallerSide)
            else
              CallerArgAreaSize:=ParaManager.create_varargs_paraloc_info(Self,CallerSide,nil);
            if HasParaLocInfo in [CalleeSide,CallBothSides] then
              HasParaLocInfo:=CallBothSides
            else
              HasParaLocInfo:=CallerSide;
          end;
        if (Side in [CalleeSide,CallBothSides]) and
           not(HasParaLocInfo in [CalleeSide,CallBothSides]) then
          begin
            if not is_c_variadic(Self) then
              CalleeArgAreaSize:=ParaManager.create_paraloc_info(Self,CalleeSide)
            else
              CallerArgAreaSize:=ParaManager.create_varargs_paraloc_info(Self,CalleeSide,nil);
            if HasParaLocInfo in [CallerSide,CallBothSides] then
              HasParaLocInfo:=CallBothSides
            else
              HasParaLocInfo:=CalleeSide;
          end;
      end;


    procedure TAbstractProcDef.Done_ParaLoc_Info(Side: TCallerCallee);
      var
        I: LongInt;
      begin
        if (Side in [CallerSide,CallBothSides]) and
           (HasParaLocInfo in [CallerSide,CallBothSides]) then
          begin
            FuncRetLoc[CallerSide].Done;
            for I:=0 to Paras.Count-1 do
              TParaVarSym(Paras[I]).ParaLoc[CallerSide].Done;
            if HasParaLocInfo=CallerSide then
              HasParaLocInfo:=CallNoSide
            else
              HasParaLocInfo:=CalleeSide;
          end;

        if (Side in [CalleeSide,CallBothSides]) and
           (HasParaLocInfo in [CalleeSide,CallBothSides]) then
          begin
            FuncRetLoc[CalleeSide].Done;
            for I:=0 to Paras.Count-1 do
              TParaVarSym(Paras[I]).ParaLoc[CalleeSide].Done;
            if HasParaLocInfo=CalleeSide then
              HasParaLocInfo:=CallNoSide
            else
              HasParaLocInfo:=CallerSide;
          end;
      end;


    function TAbstractProcDef.Stack_Tainting_Parameter(Side: TCallerCallee): Boolean;
      var
        P: TParaVarSym;
        PLoc: PCGParaLocation;
        I: LongInt;
      begin
        Result:=False;
        Init_ParaLoc_Info(Side);
        for I:=0 to ParaST.SymList.Count-1 do
          if TSym(ParaST.SymList[I]).Typ=ParaVarSym then
            begin
              P:=TParaVarSym(ParaST.SymList[I]);
              if not P.Is_Used then
                Continue;
              { check if no parameter is located on the stack }
              if (is_open_array(P.VarDef) or
                 is_array_of_const(P.VarDef)) and (P.VarSpez=vs_value) then
                begin
                  Result:=True;
                  Exit;
                end;
              PLoc:=P.ParaLoc[Side].Location;
              while Assigned(PLoc) do
                begin
                  if (PLoc^.Loc=LOC_REFERENCE) then
                    begin
                      Result:=True;
                      Exit
                    end;
                  PLoc:=PLoc^.Next;
                end;
            end;
      end;

    function TAbstractProcDef.Is_PushLeftRight: Boolean;
      begin
        Result:=False;
      end;

    function TAbstractProcDef.Address_Type: TDef;
      begin
        Result:=VoidCodePointerType;
      end;


    function TAbstractProcDef.Ofs_Address_Type:TDef;
      begin
        Result:=Address_Type;
      end;


    function TAbstractProcDef.Generate_SafeCall_Wrapper: Boolean;
      begin
{$ifdef SUPPORT_SAFECALL}
        Result:=
          (ProcCallOption=pocall_safecall) and
          not(po_assembler in ProcOptions) and
          (tf_safecall_exceptions in TargetInfo.Flags);
{$else SUPPORT_SAFECALL}
        Result:=False;
{$endif}
      end;


    function TAbstractProcDef.Is_Generic_Param(Def:TDef): Boolean;
      begin
        if Def.Typ=UndefinedDef then
          Result:=Def.Owner=Self.ParaST
        else if Def.Typ=ObjectDef then
          Result:=(Def.Owner=Self.ParaST) and (TStoredDef(Def).GenConstraintData<>nil)
        else
          Result:=False;
      end;

    function TAbstractProcDef.WPO_May_Create_Instance(OptionalMethodPointer: TNode): Boolean;
      begin
        Result:=
          (ProcTypeOption=potype_constructor) or
          ((Typ=ProcDef) and
           ((not Assigned(OptionalMethodPointer) and
             Is_Class(TDef(Owner.DefOwner))) or
            (Assigned(OptionalMethodPointer) and
             ((OptionalMethodPointer.ResultDef.Typ=ClassRefDef) or
              (OptionalMethodPointer.NodeType=TypeN)))) and
           (TProcDef(Self).ProcSym.Name='NEWINSTANCE'))
      end;


{***************************************************************************
                                  TPROCDEF
***************************************************************************}

    function TProcDef.GetParentFPSym: TSym;
      begin
        if not Assigned(FParentFPSym) then
          begin
            FParentFPSym:=TSym(ParaST.Find('parentfp'));
            if not Assigned(FParentFPSym) then
              InternalError(200309281);
          end;
        Result:=FParentFPSym;
      end;


    function TProcDef.GetIs_Implemented: Boolean;
      begin
        Result:=not Assigned(ImplProcDefInfo) or ImplProcDefInfo^.IsImplemented;
      end;


    procedure TProcDef.SetIs_Implemented(AValue: Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2020062101);
        ImplProcDefInfo^.IsImplemented:=AValue;
      end;


    function TProcDef.GetWas_Anonymous:Boolean;
      begin
        Result:=Assigned(ImplProcDefInfo) and ImplProcDefInfo^.WasAnonymous;
      end;


    procedure TProcDef.SetWas_Anonymous(AValue:Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2022020502);
        ImplProcDefInfo^.WasAnonymous:=AValue;
      end;


    function TProcDef.GetHas_Capturer:Boolean;
      begin
        Result:=Assigned(ImplProcDefInfo) and ImplProcDefInfo^.HasCapturer;
      end;


    procedure TProcDef.SetHas_Capturer(AValue:Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2022020503);
        ImplProcDefInfo^.HasCapturer:=AValue;
      end;


    function TProcDef.GetCapturedSyms:TFPList;
      begin
        if not Assigned(ImplProcDefInfo) then
          Result:=nil
        else
          Result:=ImplProcDefInfo^.CapturedSyms;
      end;


    function TProcDef.Store_LocalST: Boolean;
      begin
        Result:=HasInliningInfo or (df_generic in DefOptions);
      end;


    function TProcDef.GetResultName: PShortString;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010301);
        Result:=ImplProcDefInfo^.ResultName;
      end;


    procedure TProcDef.SetResultName(AValue: PShortString);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010302);
        ImplProcDefInfo^.ResultName:=AValue;
      end;


    function TProcDef.GetParentFPInitBlock: TNode;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010303);
        Result:=ImplProcDefInfo^.ParentFPInitBlock;
      end;


    function TProcDef.GetParentFPStruct: TSym;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010304);
        Result:=ImplProcDefInfo^.ParentFPStruct;
      end;


    function TProcDef.GetParentFPStructPtrType: TDef;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010305);
        Result:=ImplProcDefInfo^.ParentFPStructPtrType;
      end;


    procedure TProcDef.SetParentFPInitBlock(AValue: TNode);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010306);
        ImplProcDefInfo^.ParentFPInitBlock:=AValue;
      end;


    function TProcDef.GetProcEndTAI: TAI;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010307);
        Result:=ImplProcDefInfo^.ProcEndTAI;
      end;


    function TProcDef.GetProcStartTAI: TAI;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010308);
        Result:=ImplProcDefInfo^.ProcStartTAI;
      end;


    procedure TProcDef.SetProcEndTAI(AValue: TAI);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010309);
        ImplProcDefInfo^.ProcEndTAI:=AValue;
      end;


    function TProcDef.GetSKPara: Pointer;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010310);
        Result:=ImplProcDefInfo^.SKPara;
      end;


    procedure TProcDef.SetSKPara(AValue: Pointer);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010311);
        ImplProcDefInfo^.SKPara:=AValue;
      end;


    function TProcDef.GetPersonality: TProcDef;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2016121704);
         Result:=ImplProcDefInfo^.Personality;
      end;


    procedure TProcDef.SetPersonality(AValue: TProcDef);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2016121705);
        ImplProcDefInfo^.Personality:=AValue;
      end;


    function TProcDef.GetForwardDef: Boolean;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010312);
        Result:=ImplProcDefInfo^.ForwardDef;
      end;


    function TProcDef.GetHasForward: Boolean;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010313);
        Result:=ImplProcDefInfo^.HasForward;
      end;


    function TProcDef.GetInterfaceDef: Boolean;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010314);
        Result:=ImplProcDefInfo^.InterfaceDef;
      end;


    procedure TProcDef.SetForwardDef(AValue: Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010315);
        ImplProcDefInfo^.ForwardDef:=AValue;
      end;


    procedure TProcDef.SetHasForward(AValue: Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010316);
        ImplProcDefInfo^.HasForward:=AValue;
      end;


    function TProcDef.GetIsEmpty: Boolean;
      begin
        Result:=pio_empty in ImplProcOptions;
      end;


    procedure TProcDef.SetIsEmpty(AValue: Boolean);
      begin
        if AValue then
          Include(ImplProcOptions,pio_empty)
        else
          Exclude(ImplProcOptions,pio_empty);
      end;


    function TProcDef.GetHasInliningInfo: Boolean;
      begin
        Result:=pio_has_inlininginfo in ImplProcOptions;
      end;


    procedure TProcDef.SetHasInliningInfo(AValue: Boolean);
      begin
        if AValue then
          Include(ImplProcOptions,pio_has_inlininginfo)
        else
          Exclude(ImplProcOptions,pio_has_inlininginfo);
      end;


    procedure TProcDef.SetInterfaceDef(AValue: Boolean);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010317);
        ImplProcDefInfo^.InterfaceDef:=AValue;
      end;


    procedure TProcDef.SetProcStartTAI(AValue: TAI);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010318);
        ImplProcDefInfo^.ProcStartTAI:=AValue;
      end;


    procedure TProcDef.SetParentFPStruct(AValue: TSym);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010319);
        ImplProcDefInfo^.ParentFPStruct:=AValue;
      end;


    procedure TProcDef.SetParentFPStructPtrType(AValue: TDef);
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2014010320);
        ImplProcDefInfo^.ParentFPStructPtrType:=AValue;
      end;


    constructor TProcDef.Create(Level:Byte;DoRegister:Boolean);
      begin
         inherited Create(ProcDef,Level,DoRegister);
         ImplProcDefInfo:=AllocMem(SizeOf(ImplProcDefInfo^));
         LocalST:=TLocalSymTable.Create(Self,ParaST.SymTableLevel);
{$ifdef symansistr}
         FMangledName:='';
{$else symansistr}
         FMangledName:=nil;
{$endif symansistr}
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
         SeenMarker := nil;
{$endif}
         FileInfo:=CurrentFilePos;
         ExtNumber:=$ffff;
         AliasNames:=TCmdStrList.Create;
         FuncRetSym:=nil;
         FuncRetSymDeref.Reset;
         ProcSymDeref.Reset;
         ForwardDef:=True;
         InterfaceDef:=False;
         HasForward:=False;
         Struct := nil;
         StructDeref.Reset;
         ImportDLL:=nil;
         ImportName:=nil;
         ImportNr:=0;
         InliningInfo:=nil;
         DeprecatedMsg:=nil;
         GenericDeclTokenBuf:=nil;
         if cs_opt_fastmath in CurrentSettings.OptimizerSwitches then
           Include(ImplProcOptions, pio_fastmath);
      end;


    constructor TProcDef.PPULoad(PPUFile:TCompilerPPUFile);
      var
        I,AliasNamesCount,SizeLeft : LongInt;
        Level : Byte;
        Buf : array[0..255] of Byte;
      begin
         inherited PPULoad(ProcDef,PPUFile);
{$ifdef symansistr}
         if po_has_mangledname in ProcOptions then
           FMangledName:=PPUFile.GetAnsiString
         else
           FMangledName:='';
{$else symansistr}
         if po_has_mangledname in ProcOptions then
          FMangledName:=PPUFile.GetPShortString
         else
          FMangledName:=nil;
{$endif symansistr}
         ExtNumber:=PPUFile.GetWord;
         Level:=PPUFile.GetByte;
         PPUFile.GetDeref(StructDeref);
         PPUFile.GetDeref(ProcSymDeref);
         PPUFile.GetPosInfo(FileInfo);
         Visibility:=TVisibility(PPUFile.GetByte);
         PPUFile.GetSet(TPPUSet2(SymOptions));
         if sp_has_deprecated_msg in SymOptions then
           DeprecatedMsg:=PPUFile.GetPShortString
         else
           DeprecatedMsg:=nil;
         { import stuff }
         if po_has_importdll in ProcOptions then
           ImportDLL:=PPUFile.GetPShortString
         else
           ImportDLL:=nil;
         if po_has_importname in ProcOptions then
           ImportName:=PPUFile.GetPShortString
         else
           ImportName:=nil;
         ImportNr:=PPUFile.GetWord;
         if (po_msgint in ProcOptions) then
           MessageInf.I:=PPUFile.GetLongInt;
         if (po_msgstr in ProcOptions) then
           MessageInf.Str:=PPUFile.GetPShortString;
         if (po_dispid in ProcOptions) then
           DispID:=PPUFile.GetLongInt;
         { inline stuff }
         PPUFile.GetSet(TPPUSet1(ImplProcOptions));
         if HasInliningInfo then
           begin
             PPUFile.GetDeref(FuncRetSymDeref);
             New(InliningInfo);
             PPUFile.GetSet(TPPUSet4(InliningInfo^.Flags));
           end
         else
           begin
             InliningInfo:=nil;
             FuncRetSym:=nil;
           end;

         AliasNames:=TCmdStrList.Create;
         { count alias names }
         AliasNamesCount:=PPUFile.GetByte;
         for I:=1 to AliasNamesCount do
           AliasNames.Insert(PPUFile.GetString);

         { load the token stream containing the declaration }
         SizeLeft:=PPUFile.GetLongInt;
         if SizeLeft>0 then
           begin
             Init_GenericDecl;
             while SizeLeft>0 do
               begin
                 if SizeLeft>SizeOf(Buf) then
                   I:=SizeOf(Buf)
                 else
                   I:=SizeLeft;
                 PPUFile.GetData(Buf,I);
                 GenericDeclTokenBuf.write(Buf,I);
                 Dec(SizeLeft,I);
               end;
           end;

         PPULoadPlatform(PPUFile);

         { load para symtable }
         ParaST:=TParaSymTable.Create(Self,Level);
         TParaSymTable(ParaST).PPULoad(PPUFile);
         { load local symtable }
         if Store_LocalST then
          begin
            LocalST:=TLocalSymTable.Create(Self,Level);
            TLocalSymTable(LocalST).PPULoad(PPUFile);
          end
         else
          LocalST:=nil;
         { inline stuff }
         if HasInliningInfo then
           InliningInfo^.Code:=PPULoadNodeTree(PPUFile);
         { default values for no persistent data }
         if (cs_link_deffile in CurrentSettings.GlobalSwitches) and
            (tf_need_export in TargetInfo.Flags) and
            (po_exports in ProcOptions) then
           DefFile.AddExport(MangledName);
         { Disable po_has_inlining until the derefimpl is done }
         HasInliningInfo:=False;
      end;


    destructor TProcDef.Destroy;
      begin
         AliasNames.Free;
         AliasNames:=nil;
         if Assigned(LocalST) and
           (LocalST.SymTableType<>StaticSymTable) then
          begin
{$ifdef MEMDEBUG}
            MemProcLocalST.Start;
{$endif MEMDEBUG}
            LocalST.Free;
            LocalST:=nil;
{$ifdef MEMDEBUG}
            MemProcLocalST.Start;
{$endif MEMDEBUG}
          end;
         if Assigned(InliningInfo) then
          begin
{$ifdef MEMDEBUG}
            MemProcNodeTree.Start;
{$endif MEMDEBUG}
            FreeAndNil(TNode(InliningInfo^.Code));
{$ifdef MEMDEBUG}
            MemProcNodeTree.Start;
{$endif MEMDEBUG}
            Dispose(InliningInfo);
            InliningInfo:=nil;
          end;
         FreeImplProcDefInfo;
         GenericDeclTokenBuf.Free;
         GenericDeclTokenBuf:=nil;
         StringDispose(ImportDLL);
         StringDispose(ImportName);
         StringDispose(DeprecatedMsg);
         if (po_msgstr in ProcOptions) then
           StringDispose(MessageInf.Str);
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
{$endif symansistr}
         inherited Destroy;
      end;


    procedure TProcDef.FreeImplProcDefInfo;
      begin
        if Assigned(ImplProcDefInfo) then
          begin
            StringDispose(ImplProcDefInfo^.ResultName);
            TFPList.FreeAndNilDisposing(ImplProcDefInfo^.CapturedSyms,TypeInfo(TCapturedSymInfo));
            FreeMem(ImplProcDefInfo);
            ImplProcDefInfo:=nil;
          end;
      end;


    procedure TProcDef.PPUWrite(PPUFile:TCompilerPPUFile);
      var
        OldCRC : Boolean;
        AliasNamesCount,I,SizeLeft : LongInt;
        Item : TCmdStrListItem;
        Buf : array[0..255] of Byte;
      begin
         { released procdef? }
         if not Assigned(ParaST) then
           Exit;

         inherited PPUWrite(PPUFile);
{$ifdef symansistr}
         if po_has_mangledname in ProcOptions then
           PPUFile.PutAnsiString(FMangledName);
{$else symansistr}
         if po_has_mangledname in ProcOptions then
          PPUFile.PutString(FMangledName^);
{$endif symansistr}

         PPUFile.PutWord(ExtNumber);
         PPUFile.PutByte(ParaST.SymTableLevel);
         PPUFile.PutDeref(StructDeref);
         PPUFile.PutDeref(ProcSymDeref);
         PPUFile.PutPosInfo(FileInfo);
         PPUFile.PutByte(Byte(Visibility));
         PPUFile.PutSet(TPPUSet2(SymOptions));
         if sp_has_deprecated_msg in SymOptions then
           PPUFile.PutString(DeprecatedMsg^);
         { import }
         if po_has_importdll in ProcOptions then
           PPUFile.PutString(ImportDLL^);
         if po_has_importname in ProcOptions then
           PPUFile.PutString(ImportName^);
         PPUFile.PutWord(ImportNr);
         if (po_msgint in ProcOptions) then
           PPUFile.PutLongInt(MessageInf.I);
         if (po_msgstr in ProcOptions) then
           PPUFile.PutString(MessageInf.Str^);
         if (po_dispid in ProcOptions) then
           PPUFile.PutLongInt(DispID);
         { inline stuff }
         OldCRC:=PPUFile.DoCRC;
         PPUFile.DoCRC:=False;
         PPUFile.PutSet(TPPUSet1(ImplProcOptions));
         if HasInliningInfo then
           begin
             PPUFile.PutDeref(FuncRetSymDeref);
             PPUFile.PutSet(TPPUSet4(InliningInfo^.Flags));
           end;

         { count alias names }
         AliasNamesCount:=0;
         Item:=TCmdStrListItem(AliasNames.First);
         while Assigned(Item) do
           begin
             Inc(AliasNamesCount);
             Item:=TCmdStrListItem(Item.Next);
           end;
         if AliasNamesCount>255 then
           InternalError(200711021);
         PPUFile.PutByte(AliasNamesCount);
         Item:=TCmdStrListItem(AliasNames.First);
         while Assigned(Item) do
          begin
            PPUFile.PutString(Item.Str);
            Item:=TCmdStrListItem(Item.Next);
          end;

         PPUFile.DoCRC:=OldCRC;

         { generic tokens for the declaration }
         if Assigned(GenericDeclTokenBuf) and (GenericDeclTokenBuf.Size>0) then
           begin
             SizeLeft:=GenericDeclTokenBuf.Size;
             GenericDeclTokenBuf.Seek(0);
             PPUFile.PutLongInt(SizeLeft);
             while SizeLeft>0 do
               begin
                 if SizeLeft>SizeOf(Buf) then
                   I:=SizeOf(Buf)
                 else
                   I:=SizeLeft;
                 GenericDeclTokenBuf.read(Buf,I);
                 PPUFile.PutData(Buf,I);
                 Dec(SizeLeft,I);
               end;
           end
         else
           PPUFile.PutLongInt(0);

         { write this entry }
         WriteEntry(PPUFile,IBProcDef);

         { Save the para symtable, this is taken from the interface }
         TParaSymTable(ParaST).PPUWrite(PPUFile);

         { save localsymtable for inline procedures or when local
           browser info is requested, this has no influence on the crc }
         if Store_LocalST and not PPUFile.CRCOnly then
          begin
            OldCRC:=PPUFile.DoCRC;
            PPUFile.DoCRC:=False;
            TLocalSymTable(LocalST).PPUWrite(PPUFile);
            PPUFile.DoCRC:=OldCRC;
          end;

         { node tree for inlining }

         if HasInliningInfo then
           PPUWriteNodeTree(PPUFile,InliningInfo^.Code);
      end;


    function TProcDef.FullProcName(ShowHidden:Boolean):AnsiString;
      var
        PNo: TProcNameOptions;
      begin
        PNo:=[];
        if ShowHidden then
          Include(PNo,pno_showhidden);
        Result:=CustomProcName(PNo);
      end;


    function TProcDef.CustomProcName(PNo: TProcNameOptions):AnsiString;
      var
        S, HS, RN : AnsiString;
        T : TToken;
	Module : TModule;
        SysSym : TSysSym;
      begin
{$ifdef EXTDEBUG}
        Include(PNo,pno_showhidden);
{$endif EXTDEBUG}
        S:='';
        RN:='';
        if ProcTypeOption=potype_operator then
          begin
            for T:=NoToken to last_overloaded do
              if ProcSym.RealName='$'+Overloaded_Names[T] then
                begin
                  S:='operator ';
                  if (pno_ownername in PNo) and
                     Assigned(Struct) then
                    S:=S+Struct.RTTIName+'.';
                  S:=S+ArrayTokenInfo[T].Str;
                  if not (pno_noparams in PNo) then
                    S:=S+TypeName_Paras(PNo);
                  Break;
                end;
          end
        else
          begin
            if (po_classmethod in ProcOptions) and
               not(pno_noclassmarker in PNo) then
              S:='class ';
            case ProcTypeOption of
              potype_constructor,
              potype_class_constructor:
                S:=S+'constructor ';
              potype_class_destructor,
              potype_destructor:
                S:=S+'destructor ';
              else
                if (pno_proctypeoption in PNo) and not (po_anonymous in ProcOptions) then
                  begin
                   if Assigned(ReturnDef) and
                     not(is_void(ReturnDef)) then
                     S:=S+'function '
                   else
                     S:=S+'procedure ';
                  end;
            end;
            if (pno_ownername in PNo) and
               (Owner.SymTableType in [RecordSymTable,ObjectSymTable]) then
              S:=S+TAbstractRecordDef(Owner.DefOwner).RTTIName+'.';
            if (po_compilerproc in ProcOptions) and (ExtNumber<>$ffff) then
              begin
                SysSym:=TSysSym.Find_By_Number(ExtNumber);
                if not Assigned(SysSym) then
                  InternalError(2016060305);
                RN:=SysSym.RealName;
              end
            else if po_anonymous in ProcOptions then
              begin
                S:=S+'anonymous ';
                if Assigned(ReturnDef) and
                  not(is_void(ReturnDef)) then
                  S:=S+'function'
                else
                  S:=S+'procedure';
              end
            else if pno_prettynames in PNo then
              RN:=ProcSym.PrettyName
            else
              RN:=ProcSym.RealName;
            if (pno_noleadingdollar in PNo) and
               (RN[1]='$') then
              Delete(RN,1,1);
            S:=S+RN;
            if not (pno_noparams in PNo) then
              S:=S+TypeName_Paras(PNo);
          end;
        if not(ProcTypeOption in [potype_constructor,potype_destructor,
             potype_class_constructor,potype_class_destructor]) and
           Assigned(ReturnDef) and
           not(is_void(ReturnDef)) then
          begin
            if Assigned(ReturnDef.TypeSym) then
              begin
                Module:=Find_Module_From_SymTable(ReturnDef.TypeSym.Owner);
		if Module <> CurrentModule then
                  S:=S+':'+Module.RealModuleName^+'.'
                else
	          S:=S+':';
                if pno_prettynames in PNo then
                  HS:=ReturnDef.TypeSym.PrettyName
                else
                  HS:=ReturnDef.TypeSym.RealName;
                if HS[1]<>'$' then
                  S:=S+ReturnDef.OwnerHierarchyName+HS
                else
                  S:=S+ReturnDef.GetTypeName;
              end
            else
              S:=S+':'+ReturnDef.GetTypeName;
	  end;
        if not (po_anonymous in ProcOptions) then
          if Assigned(Owner) and (Owner.SymTableType=LocalSymTable) then
            S:=S+' is nested'
          else if po_is_block in ProcOptions then
            S:=S+' is block';
        S:=S+';';
        { forced calling convention? }
        if (po_hascallingconvention in ProcOptions) then
          S:=S+' '+ProcCallOptionStr[ProcCallOption]+';';
        if (po_staticmethod in ProcOptions) and
           not (ProcTypeOption in [potype_class_constructor,potype_class_destructor]) then
          S:=S+' Static;';
        if pno_mangledname in PNo then
          S:=S+' -- mangled name: '+MangledName;
        CustomProcName:=S;
      end;


    function TProcDef.Is_MethodPointer:Boolean;
      begin
        { don't check assigned(_class), that's also the case for nested
          procedures inside methods }
        Result:=(Owner.SymTableType in [RecordSymTable,ObjectSymTable]) and not No_Self_Node;
      end;


    function TProcDef.Is_AddressOnly:Boolean;
      begin
        Result:=Assigned(Owner) and
                not Is_MethodPointer and
                (not(m_nested_procvars in CurrentSettings.ModeSwitches) or
                 not is_nested_pd(Self)) and
                 (
                   not (po_anonymous in ProcOptions) or
                   not Assigned(CapturedSyms) or
                   (CapturedSyms.Count=0)
                 );
      end;


    procedure TProcDef.Make_External;
      begin
        Include(ProcOptions,po_external);
        ForwardDef:=False;
      end;


    procedure TProcDef.Init_GenericDecl;
      begin
        if Assigned(GenericDeclTokenBuf) then
          InternalError(2015061901);
        GenericDeclTokenBuf:=TDynamicArray.Create(256);
      end;


    procedure TProcDef.Reset_After_Conv;
      begin
        FParentFPSym:=nil;
      end;


    function TProcDef.Get_FuncRetSym_Info(out ResSym: TSym; out ResDef: TDef): Boolean;
      begin
        Result:=False;
        if ProcTypeOption=potype_constructor then
          begin
            Result:=True;
            ResSym:=TSym(ParaST.Find('self'));
            ResDef:=TAbstractNormalVarSym(ResSym).VarDef;
            { and TP-style constructors return a pointer to self }
            if Is_Object(ResDef) then
              ResDef:=CPointerDef.GetReusable(ResDef);
          end
        else if (ProcCallOption=pocall_safecall) and
           (tf_safecall_exceptions in TargetInfo.Flags) then
          begin
            Result:=True;
            ResSym:=TSym(LocalST.Find('safecallresult'));
            ResDef:=TAbstractNormalVarSym(ResSym).VarDef;
          end
        else if not is_void(ReturnDef) then
          begin
            Result:=True;
            ResSym:=FuncRetSym;
            ResDef:=TAbstractNormalVarSym(ResSym).VarDef;
          end;
      end;


    function TProcDef.Get_SafeCall_FuncRetSym_Info(out ResSym: TSym; out ResDef: TDef): Boolean;
      begin
        Result:=False;
        if (ProcTypeOption<>potype_constructor) and
           (ProcCallOption=pocall_safecall) and
           (tf_safecall_exceptions in TargetInfo.Flags) then
          begin
            Result:=True;
            ResSym:=TSym(LocalST.Find('safecallresult'));
            ResDef:=TAbstractNormalVarSym(ResSym).VarDef;
          end
      end;


    procedure TProcDef.Add_Captured_Sym(Sym:TSym;Def:TDef;const FilePos:TFilePosInfo);
      var
        I : LongInt;
        CapturedSym : PCapturedSymInfo;
      begin
        if not Assigned(ImplProcDefInfo) then
          InternalError(2021052601);
        if not Assigned(ImplProcDefInfo^.CapturedSyms) then
          ImplProcDefInfo^.CapturedSyms:=TFPList.Create;
        for I:=0 to ImplProcDefInfo^.CapturedSyms.Count-1 do
          begin
            CapturedSym:=PCapturedSymInfo(ImplProcDefInfo^.CapturedSyms[I]);
            if (CapturedSym^.Sym=Sym) and (CapturedSym^.Def=Def) then
              Exit;
          end;
        New(CapturedSym);
        CapturedSym^.Sym:=Sym;
        CapturedSym^.Def:=Def;
        CapturedSym^.FileInfo:=FilePos;
        ImplProcDefInfo^.CapturedSyms.Add(CapturedSym);
      end;


    function TProcDef.Has_Alias_Name(const S: TSymStr): Boolean;
      var
        Item : TCmdStrListItem;
      begin
        Result:=True;
        if MangledName=S then
          Exit;
        Item:=TCmdStrListItem(AliasNames.First);
        while Assigned(Item) do
          begin
            if Item.Str=S then
              Exit;
            Item:=TCmdStrListItem(Item.Next);
          end;
        Result:=False;
      end;


    function TProcDef.GetSymTable(T:TGetSymTable):TSymTable;
      begin
        case T of
          gs_local :
            GetSymTable:=LocalST;
          gs_para :
            GetSymTable:=ParaST;
          else
            GetSymTable:=nil;
        end;
      end;


    function TProcDef.GetCopyAs(NewTyp: TDefTyp; CopyTyp: TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef;
      var
        J : LongInt;
      begin
        Result:=inherited;
        if NewTyp=ProcVarDef then
          begin
            { create new paralist }
            TProcVarDef(Result).CalcParas;
            Exit;
          end;
        { don't copy mangled name, can be different }
        TProcDef(Result).MessageInf:=MessageInf;
        TProcDef(Result).DispID:=DispID;
        if po_msgstr in ProcOptions then
          TProcDef(Result).MessageInf.Str:=StringDup(MessageInf.Str^);
        TProcDef(Result).SymOptions:=SymOptions;
        if Assigned(DeprecatedMsg) then
          TProcDef(Result).DeprecatedMsg:=StringDup(DeprecatedMsg^);
        { will have to be associated with appropriate procsym }
        TProcDef(Result).ProcSym:=nil;
        { don't create aliases for bare copies, nor copy the funcretsym as
          the function result parameter will be inserted again if necessary
          (e.g. if the calling convention is changed) }
        if not(CopyTyp in [pc_bareproc,pc_normal_no_hidden]) then
          begin
            TProcDef(Result).AliasNames.ConcatListCopy(AliasNames);
            if Assigned(FuncRetSym) then
              begin
                if FuncRetSym.Owner=ParaST then
                  begin
                    J:=ParaST.SymList.IndexOf(FuncRetSym);
                    if J<0 then
                      InternalError(2011040606);
                    TProcDef(Result).FuncRetSym:=TSym(TProcDef(Result).ParaST.SymList[J]);
                  end
                else if FuncRetSym.Owner=LocalST then
                  begin
                    { nothing to do, will be inserted for the new procdef while
                      parsing its body (by pdecsub.insert_funcret_local) }
                  end
                else
                  InternalError(2011040605);
              end;
          end;
        { will have to be associated with a new struct }
        TProcDef(Result).Struct:=nil;
        if Assigned(ImplProcDefInfo) then
          begin
            if Assigned(ResultName) then
              TProcDef(Result).ResultName:=StringDup(ResultName^);
            TProcDef(Result).SyntheticKind:=SyntheticKind;
          end;
        if Assigned(ImportDLL) then
          TProcDef(Result).ImportDLL:=StringDup(ImportDLL^);
        if Assigned(ImportName) then
          TProcDef(Result).ImportName:=StringDup(ImportName^);
        TProcDef(Result).ImportNr:=ImportNr;
        TProcDef(Result).ExtNumber:=$ffff;
        TProcDef(Result).Visibility:=Visibility;
        { we need a separate implementation for the copied def }
        TProcDef(Result).ForwardDef:=True;
        TProcDef(Result).InterfaceDef:=True;

        { create new paralist }
        TProcDef(Result).CalcParas;
      end;


    function TProcDef.GetCopy: TStoredDef;
      begin
        Result:=GetCopyAs(ProcDef,pc_normal,'',True);
      end;


    procedure TProcDef.BuildDeref;
      begin
         inherited BuildDeref;
         StructDeref.Build(Struct);
         { procsym that originally defined this definition, should be in the
           same symtable }
         ProcSymDeref.Build(ProcSym);
      end;


    procedure TProcDef.BuildDerefImpl;
      begin
         inherited BuildDerefImpl;

         { Localst is not available for main/unit init }
         if Store_LocalST and Assigned(LocalST) then
           begin
             TLocalSymTable(LocalST).BuildDeref;
             TLocalSymTable(LocalST).BuildDerefImpl;
           end;

         { inline tree }
         if HasInliningInfo then
           begin
             FuncRetSymDeref.Build(FuncRetSym);
             InliningInfo^.Code.BuildDerefImpl;
           end;
      end;


    procedure TProcDef.Deref;
      begin
         inherited Deref;
         Struct:=TAbstractRecordDef(StructDeref.Resolve);
         { procsym that originally defined this definition, should be in the
           same symtable }
         ProcSym:=TProcSym(ProcSymDeref.Resolve);
      end;


    procedure TProcDef.DerefImpl;
      begin
         { Enable has_inlininginfo when the inlininginfo
           structure is available. The has_inlininginfo was disabled
           after the load, since the data was invalid }
         if Assigned(InliningInfo) then
           HasInliningInfo:=True;

         { Locals }
         if Store_LocalST and Assigned(LocalST) then
           begin
             TLocalSymTable(LocalST).Deref(False);
             TLocalSymTable(LocalST).DerefImpl(False);
           end;

        { Inline }
        if HasInliningInfo then
          begin
            InliningInfo^.Code.DerefImpl;
            { funcretsym, this is always located in the localst }
            FuncRetSym:=TSym(FuncRetSymDeref.Resolve);
          end
        else
          begin
            { safety }
            { Not safe! A unit may be reresolved after its interface has been
              parsed but before its implementation has been parsed, and in that
              case the funcretsym is still required!
            funcretsym:=nil; }
          end;
      end;


    function TProcDef.GetTypeName : string;
      begin
         GetTypeName := FullProcName(False);
      end;


    function TProcDef.MangledName : TSymStr;
      begin
{$ifdef symansistr}
        if FMangledName='' then
          begin
            Result:=DefaultMangledName;
            FMangledName:=Result;
          end
        else
          Result:=FMangledName;
{$else symansistr}
        if not Assigned(FMangledName) then
          begin
            Result:=DefaultMangledName;
            FMangledName:=StringDup(MangledName);
          end
        else
          Result:=FMangledName^;
{$endif symansistr}
      end;


    function TProcDef.DefaultMangledName: TSymStr;
      var
        N : TSymStr;
      begin
        N:=ProcSym.Name;
        { make sure that the mangled names of these overloadable methods types is
          unique even if it's made lowercase (e.g. for section names) }
        if ProcTypeOption in [potype_operator,potype_class_constructor,potype_class_destructor] then
          N:='$'+N;
        { we need to use the symtable where the procsym is inserted,
          because that is visible to the world }
        DefaultMangledName:=Make_MangledName('',ProcSym.Owner,N);
        DefaultMangledName:=DefaultMangledName+MangledProcParaNames(Length(DefaultMangledName))
      end;


    function TProcDef.CPlusPlusMangledName : TSymStr;

      function GetCPPParaName(P : TDef) : TSymStr;

        const
{$ifdef NAMEMANGLING_GCC2}
           OrdType2Str : array[TOrdType] of string[2] = (
             '',
             'Uc','Us','Ui','Us','',
             'Sc','s','i','x','',
             'b','b','b','b','b','b',
             'c','w','x');
{$else NAMEMANGLING_GCC2}
           OrdType2Str : array[TOrdType] of string[1] = (
             'v',
             'h','t','j','y','',
             'a','s','i','x','',
             'b','b','b','b','b',
             'b','b','b','b',
             'c','w','x','C');

           FloatType2Str : array[TFloatType] of string[1] = (
             'f','d','e','e',
             'd','d');
{$endif NAMEMANGLING_GCC2}

        var
           S : TSymStr;

        begin
           case P.Typ of
              OrdDef:
                begin
                  S:=OrdType2Str[TOrdDef(P).OrdType];
                  if S='C' then
                    S:=OrdType2Str[range_to_basetype(TOrdDef(P).Low,TOrdDef(P).High)];
                end;
              PointerDef:
                S:='P'+GetCPPParaName(TPointerDef(P).PointedDef);
{$ifndef NAMEMANGLING_GCC2}
              FloatDef:
                S:=FloatType2Str[TFloatDef(P).FloatType];
{$endif NAMEMANGLING_GCC2}
              else
                InternalError(2103001);
           end;
           GetCPPParaName:=S;
        end;

      var
         S,S2 : TSymStr;
         HP   : TParaVarSym;
         I    : Integer;

      begin
{$ifdef NAMEMANGLING_GCC2}

        { outdated gcc 2.x name mangling scheme }
         S := ProcSym.RealName;
         if ProcSym.Owner.SymTableType=ObjectSymTable then
           begin
              S2:=Upper(TObjectDef(ProcSym.Owner.DefOwner).ObjRealName^);
              case ProcTypeOption of
                 potype_destructor:
                   S:='_$_'+ToStr(Length(S2))+S2;
                 potype_constructor:
                   S:='___'+ToStr(Length(S2))+S2;
                 else
                   S:='_'+S+'__'+ToStr(Length(S2))+S2;
              end;

           end
         else S:=S+'__';

         S:=S+'F';

         { concat modifiers }
         { !!!!! }

         { now we handle the parameters }
         if MaxParaCount>0 then
           begin
             for I:=0 to Paras.Count-1 do
               begin
                 HP:=TParaVarSym(Paras[I]);
                 { no hidden parameters form part of a C++ mangled name:
                     a) self is not included
                     b) there are no "high" or other hidden parameters
                 }
                 if vo_is_hidden_para in HP.VarOptions then
                   Continue;
                 S2:=GetCPPParaName(HP.VarDef);
                 if HP.VarSpez in [vs_var,vs_out] then
                   S2:='R'+S2;
                 S:=S+S2;
               end;
           end
         else
           S:=S+'v';
         CPlusPlusMangledName:=S;
{$else NAMEMANGLING_GCC2}

         { gcc 3.x and 4.x name mangling scheme }
         { see http://www.codesourcery.com/public/cxx-abi/abi.html#mangling }
         if ProcSym.Owner.SymTableType=ObjectSymTable then
           begin
             S:='_ZN';

             S2:=TObjectDef(ProcSym.Owner.DefOwner).ObjExtName^;
             S:=S+ToStr(Length(S2))+S2;
             case ProcTypeOption of
                potype_constructor:
                  S:=S+'C1';
                potype_destructor:
                  S:=S+'D1';
                else
                  S:=S+ToStr(Length(ProcSym.RealName))+ProcSym.RealName;
             end;

             S:=S+'E';
           end
         else
           S:=ProcSym.RealName;

         { now we handle the parameters }
         if MaxParaCount>0 then
           begin
             for I:=0 to Paras.Count-1 do
               begin
                 HP:=TParaVarSym(Paras[I]);
                 { no hidden parameters form part of a C++ mangled name:
                     a) self is not included
                     b) there are no "high" or other hidden parameters
                 }
                 if vo_is_hidden_para in HP.VarOptions then
                   Continue;
                 S2:=GetCPPParaName(HP.VarDef);
                 if HP.VarSpez in [vs_var,vs_out] then
                   S2:='R'+S2;
                 S:=S+S2;
               end;
           end
         else
           S:=S+'v';
         CPlusPlusMangledName:=S;
{$endif NAMEMANGLING_GCC2}
      end;


    function  TProcDef.ObjCMangledName : TSymStr;
      var
        MangledNameLen: LongInt;
        IsCatMethod   : Boolean;
      begin
        if not (po_msgstr in ProcOptions) then
          InternalError(2009030901);
        { we may very well need longer strings to handle these... }
        MangledNameLen:=Length(TObjectDef(ProcSym.Owner.DefOwner).ObjExtName^)+
          Length('+"[ ]"')+Length(MessageInf.Str^);
        IsCatMethod:=oo_is_classhelper in TObjectDef(ProcSym.Owner.DefOwner).ObjectOptions;
        if (IsCatMethod) then
          Inc(MangledNameLen,Length(TObjectDef(ProcSym.Owner.DefOwner).ChildOf.ObjExtName^)+Length('()'));
        if MangledNameLen>255 then
          Message1(parser_e_objc_message_name_too_long,MessageInf.Str^);
        if not(po_classmethod in ProcOptions) then
          Result:='"-['
        else
          Result:='"+[';
        { quotes are necessary because the +/- otherwise confuse the assembler
          into expecting a number
        }
        if IsCatMethod then
          Result:=Result+TObjectDef(ProcSym.Owner.DefOwner).ChildOf.ObjExtName^+'(';
        Result:=Result+TObjectDef(ProcSym.Owner.DefOwner).ObjExtName^;
        if IsCatMethod then
          Result:=Result+')';
        Result:=Result+' '+MessageInf.Str^+']"';
      end;


    procedure TProcDef.SetMangledName(const S : TSymStr);
      begin
        { This is not allowed anymore, the forward declaration
          already needs to create the correct mangledname, no changes
          afterwards are allowed (PFV) }
        { Exception: interface definitions in mode macpas, since in that }
        {   case no reference to the old name can exist yet (JM)         }
{$ifdef symansistr}
        if FMangledName<>'' then
          if ((m_mac in CurrentSettings.ModeSwitches) and
              (InterfaceDef)) then
            FMangledName:=''
          else
            InternalError(200411171);
{$else symansistr}
        if Assigned(FMangledName) then
          if ((m_mac in CurrentSettings.ModeSwitches) and
              (InterfaceDef)) then
            StringDispose(FMangledName)
          else
            InternalError(200411171);
{$endif symansistr}
  {$ifdef symansistr}
        FMangledName:=S;
  {$else symansistr}
        FMangledName:=StringDup(S);
  {$endif symansistr}
        Include(ProcOptions,po_has_mangledname);
      end;

    function TProcDef.NeedsGlobalAsmSym: Boolean;
      begin
        Result:=
          { smart linking using a library requires to promote
            all non-nested procedures to AB_GLOBAL
            otherwise you get undefined symbol error at linking
            for msdos  target with -CX option for instance }
          (create_smartlink_library and not is_nested_pd(Self)) or
          (po_global in ProcOptions);
    end;


    procedure TProcDef.SetCompilerProcName;
      begin
        ProcSym.RealName:='$'+Lower(ProcSym.Name);
      end;


{***************************************************************************
                                 TPROCVARDEF
***************************************************************************}

    constructor TProcVarDef.Create(Level:Byte;DoRegister:Boolean);
      begin
         inherited Create(ProcVarDef,Level,DoRegister);
      end;


    class function TProcVarDef.GetReusableProcAddr(Def: TAbstractProcDef; CopyTyp: TCacheableProcCopyType): TProcVarDef;
      var
        Res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
        Key: packed record
          Def: TAbstractProcDef;
          CopyTyp: TCacheableProcCopyType;
        end;

      begin
        if not Assigned(CurrentModule) then
          InternalError(2011081302);
        Key.Def:=Def;
        Key.CopyTyp:=CopyTyp;
        Res:=CurrentModule.ProcAddrDefs.FindOrAdd(@Key,SizeOf(Key));
        if not Assigned(Res^.Data) then
          begin
            { since these pointerdefs can be reused anywhere in the current
              unit, add them to the global/staticsymtable (or local symtable
              if they're a local def, because otherwise they'll be saved
              to the ppu referencing a local symtable entry that doesn't
              exist in the ppu) }
            OldSymTableStack:=SymTableStack;
            { do not simply push/pop current_module.localsymtable, because
              that can have side-effects (e.g., it removes helpers) }
            SymTableStack:=nil;
            Result:=TProcVarDef(Def.GetCopyAs(ProcVarDef,CopyTyp,'',True));
            SetupReusableDef(Def,Result,Res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            Exit;
          end;
        Result:=TProcVarDef(Res^.Data);
      end;


    class function TProcVarDef.GetReusableProcAddr_No_Free(Def: TAbstractProcDef): TProcVarDef;
      begin
        Result:=GetReusableProcAddr(Def,pc_address_only);
        if not Result.IsRegistered then
          Include(Result.DefOptions,df_not_registered_no_free);
      end;


    constructor TProcVarDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(ProcVarDef,PPUFile);
         { load para symtable }
         ParaST:=TParaSymTable.Create(Self,PPUFile.GetByte);
         PPULoadPlatform(PPUFile);
         TParaSymTable(ParaST).PPULoad(PPUFile);
      end;


    function TProcVarDef.GetCopy : TStoredDef;
      var
        I : TCallerCallee;
        J : LongInt;
      begin
        Result:=CProcVarDef.Create(ParaST.SymTableLevel,True);
        TProcVarDef(Result).ReturnDef:=ReturnDef;
        TProcVarDef(Result).ReturnDefDeref:=ReturnDefDeref;
        TProcVarDef(Result).ParaST:=ParaST.GetCopy;
        TProcVarDef(Result).SaveSize:=SaveSize;

        { create paralist copy }
        CalcParas;
        TProcVarDef(Result).Paras:=TParaList.Create(False);
        TProcVarDef(Result).Paras.Count:=Paras.Count;
        for J:=0 to Paras.Count-1 do
          TProcVarDef(Result).Paras[J]:=Paras[J];

        TProcVarDef(Result).ProcTypeOption:=ProcTypeOption;
        TProcVarDef(Result).ProcCallOption:=ProcCallOption;
        TProcVarDef(Result).ProcOptions:=ProcOptions;
        TProcVarDef(Result).CallerArgAreaSize:=CallerArgAreaSize;
        TProcVarDef(Result).CalleeArgAreaSize:=CalleeArgAreaSize;
        TProcVarDef(Result).MaxParaCount:=MaxParaCount;
        TProcVarDef(Result).MinParaCount:=MinParaCount;
        for I:=Low(FuncRetLoc) to High(FuncRetLoc) do
          TProcVarDef(Result).FuncRetLoc[I]:=FuncRetLoc[I].GetCopy;
        TProcVarDef(Result).HasParaLocInfo:=HasParaLocInfo;
      end;


    procedure TProcVarDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(PPUFile);

        { Save the para symtable level (necessary to distinguish nested
          procvars) }
        PPUFile.PutByte(ParaST.SymTableLevel);

        { Write this entry }
        WriteEntry(PPUFile,IBProcVarDef);

        { Save the para symtable, this is taken from the interface }
        TParaSymTable(ParaST).PPUWrite(PPUFile);
      end;


    function TProcVarDef.GetSymTable(T:TGetSymTable):TSymTable;
      begin
        case T of
          gs_para :
            GetSymTable:=ParaST;
          else
            GetSymTable:=nil;
        end;
      end;


    function TProcVarDef.Size : ASizeInt;
      begin
         { we return false for is_addressonly for a block (because it's not a
           simple pointer to a function), but they are handled as implicit
           pointers to a datastructure that contains everything ->
           voidpointertype.size instead of voidcodepointertype.size }
         if po_is_block in ProcOptions then
           Size:=VoidPointerType.Size
         else if not Is_AddressOnly then
           begin
             if is_nested_pd(Self) then
               Size:=VoidCodePointerType.Size+ParentFPVoidPointerType.Size
             else
               Size:=VoidCodePointerType.Size+VoidPointerType.Size;
           end
         else
           Size:=VoidCodePointerType.Size;
      end;


    function TProcVarDef.Is_MethodPointer:Boolean;
      begin
        Result:=(po_methodpointer in ProcOptions);
      end;


    function TProcVarDef.Is_AddressOnly:Boolean;
      begin
        Result:=((not(po_methodpointer in ProcOptions) or (po_staticmethod in ProcOptions)) and
                 not(po_is_block in ProcOptions) and
                 not is_nested_pd(Self)) or
                (po_addressonly in ProcOptions);
      end;


    function TProcVarDef.GetMangledParaName:TSymStr;
      begin
        if not(po_methodpointer in ProcOptions) then
          if not is_nested_pd(Self) then
            Result:='procvar'
          else
            { we need the manglednames here, because nestedprocvars can be anonymous, e.g.
              having not a type name or not an unique one, see tbs/tw27515.pas

              Further, use $_ ... _$ delimiters to avoid ambiguous names, see tbs/tw27515.pas }
            Result:='$_nestedprovar'+MangledProcParaNames(0)+'_$'
        else
          Result:='procvarofobj'
      end;


    function TProcVarDef.GetCopyAs(NewTyp: TDefTyp; CopyTyp: TProcCopyTyp; const ParaPrefix: string;DoRegister:Boolean): TStoredDef;
      begin
        Result:=inherited;
        TAbstractProcDef(Result).CalcParas;
      end;


    function TProcVarDef.IsPublishable : TPublishProperty;
      begin
         if po_methodpointer in ProcOptions then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TProcVarDef.GetTypeName : string;
      var
        S: string;
        PNo : TProcNameOptions;
      begin
{$ifdef EXTDEBUG}
         PNo:=[pno_showhidden];
{$else EXTDEBUG}
         PNo:=[];
{$endif EXTDEBUG}
         S:='<';
         if po_is_block in ProcOptions then
           S := S+'reference to'
         else if po_classmethod in ProcOptions then
           S := S+'class method type of'
         else
           if po_addressonly in ProcOptions then
             S := S+'address of'
           else
             S := S+'procedure variable type of';
         if Assigned(ReturnDef) and
            (ReturnDef<>VoidType) then
           S:=S+' function'+TypeName_Paras(PNo)+':'+ReturnDef.GetTypeName
         else
           S:=S+' procedure'+TypeName_Paras(PNo);
         if po_methodpointer in ProcOptions then
           S := S+' of object';
         if is_nested_pd(Self) then
           S := S+' is nested';
         GetTypeName := S+';'+ProcCallOptionStr[ProcCallOption]+'>';
      end;


{***************************************************************************
                              TOBJECTDEF
***************************************************************************}

   constructor TObjectDef.Create(OT:TObjectTyp;const N:string;C:TObjectDef;DoRegister:Boolean);
     begin
        inherited Create(N,ObjectDef,DoRegister);
        FCurrentDispID:=0;
        ObjectType:=OT;
        ChildOf:=nil;
        ChildOfDeref.Reset;
        VMTFieldDeref.Reset;
        HiddenClassDefRef.Reset;

        ExtendedDefDeref.Reset;
        ClonedDefDeref.Reset;
        if ObjectType=odt_helper then
          Owner.IncludeOption(sto_has_helper);
        SymTable:=TObjectSymTable.Create(Self,N,CurrentSettings.PackRecords,
          CurrentSettings.Alignment.RecordAlignMin);
        { create space for vmt !! }
        VMTEntries:=TFPList.Create;
        Set_Parent(C);
        if ObjectType in [odt_interfacecorba,odt_interfacecom,odt_dispinterface] then
          PrepareGUID;
        { setup implemented interfaces }
        if ObjectType in [odt_class,odt_objcclass,odt_objcprotocol,odt_objccategory] then
          ImplementedInterfaces:=TFPObjectList.Create(True)
        else
          ImplementedInterfaces:=nil;
        WritingClassRecordDbgInfo:=False;
     end;


    constructor TObjectDef.PPULoad(PPUFile:TCompilerPPUFile);
      var
         I,
         ImplIntfCount : LongInt;
         D, GetterD : TDeref;
         ImplIntf : TImplementedInterface;
         VMTEntry : PVMTEntry;
      begin
         inherited PPULoad(ObjectDef,PPUFile);
         ObjectType:=TObjectTyp(PPUFile.GetByte);
         HelperType:=THelperType(PPUFile.GetByte);
         ObjExtName:=PPUFile.GetPShortString;
         { only used for external Objective-C classes/protocols }
         if (ObjExtName^='') then
           StringDispose(ObjExtName);
         SymTable:=TObjectSymTable.Create(Self,ObjRealName^,0,0);
         TObjectSymTable(SymTable).DataSize:=PPUFile.GetASizeInt;
         TObjectSymTable(SymTable).PaddingSize:=PPUFile.GetWord;
         TObjectSymTable(SymTable).FieldAlignment:=ShortInt(PPUFile.GetByte);
         TObjectSymTable(SymTable).RecordAlignment:=ShortInt(PPUFile.GetByte);
         TObjectSymTable(SymTable).RecordAlignMin:=ShortInt(PPUFile.GetByte);
         PPUFile.GetDeref(VMTFieldDeref);
         PPUFile.GetDeref(ChildOfDeref);

         { load guid }
         IIDStr:=nil;
         if ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           begin
              New(IIDGUID);
              PPUFile.GetGUID(IIDGUID^);
              IIDStr:=PPUFile.GetPShortString;
           end;
         AbstractCnt:=PPUFile.GetLongInt;

         if ObjectType=odt_helper then
           PPUFile.GetDeref(ExtendedDefDeref);

         VMTEntries:=TFPList.Create;
         VMTEntries.Count:=PPUFile.GetLongInt;
         for I:=0 to VMTEntries.Count-1 do
           begin
             PPUFile.GetDeref(D);
             New(VMTEntry);
             VMTEntry^.ProcDef:=nil;
             VMTEntry^.ProcDefDeref:=D;
             VMTEntry^.Visibility:=TVisibility(PPUFile.GetByte);
             VMTEntries[I]:=VMTEntry;
           end;

         { load implemented interfaces }
         if ObjectType in [odt_class,odt_objcclass,odt_objcprotocol,odt_objccategory] then
           begin
             ImplementedInterfaces:=TFPObjectList.Create(True);
             ImplIntfCount:=PPUFile.GetLongInt;
             for I:=0 to ImplIntfCount-1 do
               begin
                 PPUFile.GetDeref(D);
                 PPUFile.GetDeref(GetterD);
                 ImplIntf:=TImplementedInterface.Create_Deref(D,GetterD);
                 ImplIntf.IOffset:=PPUFile.GetLongInt;
                 Byte(ImplIntf.IType):=PPUFile.GetByte;
                 ImplementedInterfaces.Add(ImplIntf);
               end;
           end
         else
           ImplementedInterfaces:=nil;

         if df_copied_def in DefOptions then
           begin
             PPUFile.GetDeref(ClonedDefDeref);
             PPULoadPlatform(PPUFile);
           end
         else
           begin
             PPULoadPlatform(PPUFile);
             TObjectSymTable(SymTable).PPULoad(PPUFile);
           end;

         { handles the predefined class tobject  }
         { the last TOBJECT which is loaded gets }
         { it !                                  }
         { but do this only from a unit that's   }
         { marked as system unit to avoid some   }
         { equally named user's type to override }
         { the internal types!                   }
         if mf_system_unit in CurrentModule.ModuleFlags then
           begin
             if (ChildOf=nil) and
                (ObjectType in [odt_class]) and
                (ObjName^='TOBJECT') then
               Class_TObject:=Self;
             if (ChildOf=nil) and
                (ObjectType=odt_interfacecom) then
                if (ObjName^='IUNKNOWN') then
                  Interface_IUnknown:=Self
                else
                if (ObjName^='IDISPATCH') then
                  Interface_IDispatch:=Self;
           end;
         if (ChildOf=nil) and
            (ObjectType=odt_objcclass) and
            (ObjName^='PROTOCOL') then
           ObjC_ProtocolType:=Self;

         WritingClassRecordDbgInfo:=False;
       end;


    destructor TObjectDef.Destroy;
      begin
         if Assigned(SymTable) then
           begin
             SymTable.Free;
             SymTable:=nil;
           end;
         StringDispose(ObjExtName);
         StringDispose(IIDStr);
         if Assigned(ImplementedInterfaces) then
           begin
             ImplementedInterfaces.Free;
             ImplementedInterfaces:=nil;
           end;
         if Assigned(IIDGUID) then
           begin
             Dispose(IIDGUID);
             IIDGUID:=nil;
           end;
         TFPList.FreeAndNilDisposing(VMTEntries,TypeInfo(TVMTEntry));
         if Assigned(VMCallStaticInfo) then
           begin
             FreeMem(VMCallStaticInfo);
             VMCallStaticInfo:=nil;
           end;
         inherited Destroy;
      end;


    function TObjectDef.GetCopy : TStoredDef;
      var
        I : LongInt;
      begin
        Result:=CObjectDef.Create(ObjectType,ObjRealName^,ChildOf,True);
        { the constructor allocates a symtable which we release to avoid memory leaks }
        TObjectDef(Result).SymTable.Free;
        TObjectDef(Result).SymTable:=SymTable.GetCopy;
        if Assigned(ObjExtName) then
          TObjectDef(Result).ObjExtName:=StringDup(ObjExtName^);
        if Assigned(ImportLib) then
          TObjectDef(Result).ImportLib:=StringDup(ImportLib^);
        TObjectDef(Result).ObjectOptions:=ObjectOptions;
        Include(TObjectDef(Result).DefOptions,df_copied_def);
        TObjectDef(Result).ExtendedDef:=ExtendedDef;
        if Assigned(TCInitCode) then
          TObjectDef(Result).TCInitCode:=TCInitCode.GetCopy;
        TObjectDef(Result).VMTField:=VMTField;
        if Assigned(IIDGUID) then
          begin
            New(TObjectDef(Result).IIDGUID);
            Move(IIDGUID^,TObjectDef(Result).IIDGUID^,SizeOf(IIDGUID^));
          end;
        if Assigned(IIDStr) then
          TObjectDef(Result).IIDStr:=StringDup(IIDStr^);
        TObjectDef(Result).AbstractCnt:=AbstractCnt;
        if Assigned(ImplementedInterfaces) then
          begin
            TObjectDef(Result).ImplementedInterfaces.Capacity:=TObjectDef(Result).ImplementedInterfaces.Count+ImplementedInterfaces.Count;
            for I:=0 to ImplementedInterfaces.Count-1 do
              TObjectDef(Result).ImplementedInterfaces.Add(TImplementedInterface(ImplementedInterfaces[I]).GetCopy);
          end;
        TObjectDef(Result).CopyVMTEntries(Self);
      end;


    procedure TObjectDef.PPUWrite(PPUFile:TCompilerPPUFile);
      var
         I : LongInt;
         VMTEntry : PVMTEntry;
         ImplIntf : TImplementedInterface;
         OldDoIndirectCRC: Boolean;
      begin
         { if class1 in unit A changes, and class2 in unit B inherits from it
           (so unit B uses unit A), then unit B with class2 will be recompiled.
           However, if there is also a class3 in unit C that only depends on
           unit B, then unit C will not be recompiled because nothing changed
           to the interface of unit B. Nevertheless, unit C can indirectly
           depend on unit A via derefs, and these must be updated -> the
           indirect crc keeps track of such changes. }
         OldDoIndirectCRC:=PPUFile.DoIndirectCRC;
         PPUFile.DoIndirectCRC:=True;
         inherited PPUWrite(PPUFile);
         PPUFile.PutByte(Byte(ObjectType));
         PPUFile.PutByte(Byte(HelperType));
         if Assigned(ObjExtName) then
           PPUFile.PutString(ObjExtName^)
         else
           PPUFile.PutString('');
         PPUFile.PutASizeInt(TObjectSymTable(SymTable).DataSize);
         PPUFile.PutWord(TObjectSymTable(SymTable).PaddingSize);
         PPUFile.PutByte(Byte(TObjectSymTable(SymTable).FieldAlignment));
         PPUFile.PutByte(Byte(TObjectSymTable(SymTable).RecordAlignment));
         PPUFile.PutByte(Byte(TObjectSymTable(SymTable).RecordAlignMin));
         PPUFile.PutDeref(VMTFieldDeref);
         PPUFile.PutDeref(ChildOfDeref);
         if ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           begin
              PPUFile.PutGUID(IIDGUID^);
              PPUFile.PutString(IIDStr^);
           end;
         PPUFile.PutLongInt(AbstractCnt);
         if ObjectType=odt_helper then
           PPUFile.PutDeref(ExtendedDefDeref);

         PPUFile.PutLongInt(VMTEntries.Count);
         for I:=0 to VMTEntries.Count-1 do
           begin
             VMTEntry:=PVMTEntry(VMTEntries[I]);
             PPUFile.PutDeref(VMTEntry^.ProcDefDeref);
             PPUFile.PutByte(Byte(VMTEntry^.Visibility));
           end;

         if Assigned(ImplementedInterfaces) then
           begin
             PPUFile.PutLongInt(ImplementedInterfaces.Count);
             for I:=0 to ImplementedInterfaces.Count-1 do
               begin
                 ImplIntf:=TImplementedInterface(ImplementedInterfaces[I]);
                 PPUFile.PutDeref(ImplIntf.IntfDefDeref);
                 PPUFile.PutDeref(ImplIntf.ImplementsGetterDeref);
                 PPUFile.PutLongInt(ImplIntf.Ioffset);
                 PPUFile.PutByte(Byte(ImplIntf.IType));
               end;
           end;

         if df_copied_def in DefOptions then
           PPUFile.PutDeref(ClonedDefDeref);

         WriteEntry(PPUFile,IBObjectDef);

         if not(df_copied_def in DefOptions) then
           TObjectSymTable(SymTable).PPUWrite(PPUFile);

         PPUFile.DoIndirectCRC:=OldDoIndirectCRC;
      end;


    function TObjectDef.GetTypeName:string;
      begin
        { in this case we will go in endless recursion, because then  }
        { there is no tsym associated yet with the def. It can occur  }
        { (tests/webtbf/tw4757.pas), so for now give a generic name    }
        { instead of the actual type name                             }
        if not Assigned(TypeSym) then
          Result:='<Currently Parsed Class>'
        else
          Result:=TypeSymbolPrettyName;
      end;


    procedure TObjectDef.BuildDeref;
      var
         I : LongInt;
         VMTEntry : PVMTEntry;
      begin
         inherited BuildDeref;
         VMTFieldDeref.Build(VMTField);
         ChildOfDeref.Build(ChildOf);

         if df_copied_def in DefOptions then
           ClonedDefDeref.Build(SymTable.DefOwner)
         else
           TStoredSymTable(SymTable).BuildDeref;

         if ObjectType=odt_helper then
           ExtendedDefDeref.Build(ExtendedDef);

         for I:=0 to VMTEntries.Count-1 do
           begin
             VMTEntry:=PVMTEntry(VMTEntries[I]);
             VMTEntry^.ProcDefDeref.Build(VMTEntry^.ProcDef);
           end;

         if Assigned(ImplementedInterfaces) then
           begin
             for I:=0 to ImplementedInterfaces.Count-1 do
               TImplementedInterface(ImplementedInterfaces[I]).BuildDeref;
           end;
      end;


    procedure TObjectDef.Deref;
      var
         I : LongInt;
         VMTEntry : PVMTEntry;
      begin
         inherited Deref;
         VMTField:=TSym(VMTFieldDeref.Resolve);
         ChildOf:=TObjectDef(ChildOfDeref.Resolve);
         if df_copied_def in DefOptions then
           begin
             ClonedDef:=TObjectDef(ClonedDefDeref.Resolve);
             SymTable:=ClonedDef.SymTable.GetCopy;
           end
         else
           TStoredSymTable(SymTable).Deref(False);
         if ObjectType=odt_helper then
           ExtendedDef:=TDef(ExtendedDefDeref.Resolve);
         for I:=0 to VMTEntries.Count-1 do
           begin
             VMTEntry:=PVMTEntry(VMTEntries[I]);
             VMTEntry^.ProcDef:=TProcDef(VMTEntry^.ProcDefDeref.Resolve);
           end;
         if Assigned(ImplementedInterfaces) then
           begin
             for I:=0 to ImplementedInterfaces.Count-1 do
               TImplementedInterface(ImplementedInterfaces[I]).Deref;
           end;
      end;


    procedure CreateClassHelperForProcDef(Def: TObject; Arg: Pointer);
      var
        PD: TProcDef absolute Def;
        ST: TSymTable;
        PSym: TSym;
        NName: TIDString;
      begin
        if (TDef(Def).Typ<>ProcDef) then
          Exit;
        { pd.owner = objcclass symtable -> defowner = objcclassdef ->
          owner = symtable in which objcclassdef is defined
        }
        ST:=PD.Owner.DefOwner.Owner;
        NName:=class_helper_prefix+TProcSym(PD.ProcSym).Name;
        { check for an existing procsym with our special name }
        PSym:=TSym(ST.Find(NName));
        if not Assigned(PSym) then
          begin
            PSym:=CProcSym.Create(NName);
            { avoid warning about this symbol being unused }
            PSym.IncRefCount;
            { don't check for duplicates:
               a) we checked above
               b) in case we are in the implementation section of a unit, this
                  will also check for this symbol in the interface section
                  (since you normally cannot have symbols with the same name
                   both interface and implementation), and it's possible to
                   have class helpers for the same class in the interface and
                   in the implementation, and they cannot be merged since only
                   the once in the interface must be saved to the ppu/visible
                   from other units }
            ST.InsertSym(PSym,False);
          end
        else if (PSym.Typ<>ProcSym) then
          InternalError(2009111501);
        { add ourselves to this special procsym }
        TProcSym(PSym).ProcDefList.Add(Def);
      end;


    procedure TObjectDef.DerefImpl;
      begin
         inherited DerefImpl;
         { the procdefs are not owned by the class helper procsyms, so they
           are not stored/restored either -> re-add them here }
         if (ObjectType in [odt_objcclass,odt_objcprotocol]) or
            (oo_is_classhelper in ObjectOptions) then
           SymTable.DefList.ForEachCall(@CreateClassHelperForProcDef,nil);
      end;


    procedure TObjectDef.CopyVMTEntries(ObjDef:TObjectDef);
      var
        I : LongInt;
        VMTEntry : PVMTEntry;
      begin
        if VMTEntries.Count<>0 then
          InternalError(2019081401);
        VMTEntries.Count:=ObjDef.VMTEntries.Count;
        for I:=0 to ObjDef.VMTEntries.Count-1 do
          begin
            New(VMTEntry);
            VMTEntry^:=PVMTEntry(ObjDef.VMTEntries[I])^;
            VMTEntries[I]:=VMTEntry;
          end;
       end;


    function TObjectDef.GetParentDef:TDef;
      begin
{ TODO: Remove getparentdef hack}
        { With 2 forward declared classes with the child class before the
          parent class the child class is written earlier to the ppu. Leaving it
          possible to have a reference to the parent class for property overriding,
          but the parent class still has the childof not resolved yet (PFV) }
        if ChildOf=nil then
          ChildOf:=TObjectDef(ChildOfDeref.Resolve);
        Result:=ChildOf;
      end;


    procedure TObjectDef.PrepareGUID;
      begin
        { set up guid }
        if not Assigned(IIDGUID) then
         begin
            New(IIDGUID);
            FillChar(IIDGUID^,SizeOf(IIDGUID^),0); { default null guid }
         end;
        { setup iidstring }
        if not Assigned(IIDStr) then
          IIDStr:=StringDup(''); { default is empty string }
      end;


    procedure TObjectDef.Set_Parent( C : TObjectDef);
      begin
        if Assigned(ChildOf) then
          Exit;
        ChildOf:=C;
        if not Assigned(C) then
          Exit;
        { inherit options and status }
        ObjectOptions:=ObjectOptions+(C.ObjectOptions*inherited_objectoptions);
        { check if parent is a generic parameter }
        if sp_generic_para in C.TypeSym.SymOptions then
         ObjectOptions:=ObjectOptions+[oo_inherits_not_specialized];
        { initially has the same number of abstract methods as the parent }
        AbstractCnt:=C.AbstractCnt;
        { add the data of the ancestor class/object }
        if (ObjectType in [odt_class,odt_object,odt_objcclass]) then
          begin
            TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize+TObjectSymTable(C.SymTable).DataSize;
            { inherit recordalignment }
            TObjectSymTable(SymTable).RecordAlignment:=TObjectSymTable(C.SymTable).RecordAlignment;
            { if both the parent and this record use C-alignment, also inherit
              the current field alignment }
            if (TObjectSymTable(C.SymTable).UseFieldAlignment=C_alignment) and
               (TObjectSymTable(SymTable).UseFieldAlignment=C_alignment) then
              TObjectSymTable(SymTable).FieldAlignment:=TObjectSymTable(C.SymTable).FieldAlignment;
            { the padding is not inherited for Objective-C classes (maybe not
              for cppclass either?) }
            if ObjectType=odt_objcclass then
              TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize-TObjectSymTable(C.SymTable).PaddingSize;
            if (oo_has_vmt in ObjectOptions) and
               (oo_has_vmt in C.ObjectOptions) then
              TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize-SizeOf(PInt);
            { if parent has a vmt field then the offset is the same for the child PM }
            if (oo_has_vmt in C.ObjectOptions) or Is_Class(Self) then
              begin
                VMTField:=C.VMTField;
                Include(ObjectOptions,oo_has_vmt);
              end;
          end;
      end;


   procedure TObjectDef.InsertVMT;
     begin
        if ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol] then
          Exit;
        if (oo_has_vmt in ObjectOptions) then
          InternalError(2020100816)
        else
          begin
             TObjectSymTable(SymTable).DataSize:=Align(TObjectSymTable(SymTable).DataSize,
                 TObjectSymTable(SymTable).FieldAlignment);

             if (tf_requires_proper_alignment in TargetInfo.Flags) then
               begin
                 { Align VMT pointer and whole object instance if target CPU requires alignment. }
                 TObjectSymTable(SymTable).DataSize:=Align(TObjectSymTable(SymTable).DataSize,SizeOf(PInt));
                 TObjectSymTable(SymTable).AlignRecord(TObjectSymTable(SymTable).DataSize,SizeOf(PInt));
               end;
             VMTField:=CFieldVarSym.Create('_vptr$'+ObjName^,vs_value,VoidPointerType,[]);
             HideSym(VMTField);
             TObjectSymTable(SymTable).InsertSym(VMTField);
             TObjectSymTable(SymTable).AddField(TFieldVarSym(VMTField),vis_hidden);
             Include(ObjectOptions,oo_has_vmt);
          end;
     end;


   function TObjectDef.VMT_Offset: ASizeInt;
     begin
        if ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol] then
          Result:=0
        else if (TObjectSymTable(SymTable).UseFieldAlignment<>bit_alignment) then
          Result:=TFieldVarSym(VMTField).FieldOffset
        else
          Result:=TFieldVarSym(VMTField).FieldOffset div 8;
     end;


   procedure TObjectDef.Check_Forwards;
     begin
        if not(ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcprotocol]) then
          inherited;
        if (oo_is_forward in ObjectOptions) then
          begin
             { ok, in future, the forward can be resolved }
             Message1(sym_e_class_forward_not_resolved,ObjRealName^);
             Exclude(ObjectOptions,oo_is_forward);
          end;
     end;


   function TObjectDef.Find_Destructor: TProcDef;
     var
       ObjDef: TObjectDef;
     begin
        ObjDef:=Self;
        while Assigned(ObjDef) do
          begin
            Result:=ObjDef.Find_ProcDef_ByType(potype_destructor);
            if Assigned(Result) then
              Exit;
            ObjDef:=ObjDef.ChildOf;
          end;
        Result:=nil;
     end;

    function TObjectDef.Implements_Any_Interfaces: Boolean;
      begin
        Result := (ImplementedInterfaces.Count > 0) or
          (Assigned(ChildOf) and ChildOf.Implements_Any_Interfaces);
      end;


    function TObjectDef.Register_Implemented_Interface(IntfDef:TObjectDef;UseGUID:Boolean):TImplementedInterface;
      begin
        { allocate the GUID only if the class implements at least one interface }
        if UseGUID then
          PrepareGUID;
        Result:=TImplementedInterface.Create(IntfDef);
        ImplementedInterfaces.Add(Result);
      end;


    function TObjectDef.Size : ASizeInt;
      begin
        if ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper] then
          Result:=VoidPointerType.Size
        else
          Result:=TObjectSymTable(SymTable).DataSize;
      end;


    function TObjectDef.Alignment:ShortInt;
      begin
        if ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper] then
          Alignment:=VoidPointerType.Alignment
        else
          Alignment:=TObjectSymTable(SymTable).RecordAlignment;
      end;


    function TObjectDef.VMTMethodOffset(Index:LongInt):LongInt;
      begin
        { for offset of methods for classes, see rtl/inc/objpash.inc }
        case ObjectType of
        odt_class:
          { the +2*sizeof(pint) is size and -size }
          VMTMethodOffset:=Index*VoidCodePointerType.Size+10*VoidPointerType.Size+2*SizeOf(PInt);
        odt_helper,
        odt_objcclass,
        odt_objcprotocol:
          VMTMethodOffset:=0;
        odt_interfacecom,odt_interfacecorba,odt_dispinterface:
          VMTMethodOffset:=Index*VoidCodePointerType.Size;
        else
          { the +2*sizeof(pint) is size and -size }
{$ifdef WITHDMT}
          VMTMethodOffset:=Index*VoidCodePointerType.Size+2*VoidPointerType.Size+2*SizeOf(PInt);
{$else WITHDMT}
          VMTMethodOffset:=Index*VoidCodePointerType.Size+1*VoidPointerType.Size+2*SizeOf(PInt);
{$endif WITHDMT}
        end;
      end;


    function TObjectDef.VMT_MangledName : TSymStr;
      begin
        if not(oo_has_vmt in ObjectOptions) then
          Message1(parser_n_object_has_no_vmt,ObjRealName^);
        if not Is_Unique_ObjPasDef then
          VMT_MangledName:=Make_MangledName('VMT',Owner,ObjName^)
        else
          VMT_MangledName:=ChildOf.VMT_MangledName;
      end;


    function TObjectDef.VMT_Def: TRecordDef;
      var
        VMTTypeSym: TSymEntry;
      begin
        if not Is_Unique_ObjPasDef then
          begin
            VMTTypeSym:=SymTable.Find('vmtdef');
            if not Assigned(VMTTypeSym) or
               (VMTTypeSym.Typ<>SymConst.TypeSym) or
               (TTypeSym(VMTTypeSym).TypeDef.Typ<>RecordDef) then
              InternalError(2015052501);
            Result:=TRecordDef(TTypeSym(VMTTypeSym).TypeDef);
          end
        else
          Result:=ChildOf.VMT_Def;
      end;


    function TObjectDef.NeedsInitTable : Boolean;
      var
        HP : TObjectDef;
      begin
         case ObjectType of
            odt_helper,
            odt_class :
              NeedsInitTable:=False;
            odt_dispinterface,
            odt_interfacecom:
              NeedsInitTable:=True;
            odt_interfacecorba:
              begin
                HP:=ChildOf;
                while Assigned(HP) do
                  begin
                    if HP=Interface_IUnknown then
                      begin
                        NeedsInitTable:=True;
                        Exit;
                      end;
                    HP:=HP.ChildOf;
                  end;
                NeedsInitTable:=False;
              end;
            odt_object:
              NeedsInitTable:=
                TObjectSymTable(SymTable).Needs_Init_Final or
                (Assigned(ChildOf) and
                 ChildOf.NeedsInitTable);
            odt_cppclass,
            odt_objcclass,
            odt_objcprotocol:
              NeedsInitTable:=False;
            else
              InternalError(200108267);
         end;
      end;

    function TObjectDef.NeedsSeparateInitRTTI : Boolean;
      begin
        Result:=not (ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface]);
      end;


    function TObjectDef.HasNonTrivialInitChild(CheckParent:Boolean):Boolean;
      begin
        if ObjectType in [odt_class,odt_object] then
          begin
            Result:=TObjectSymTable(SymTable).Has_Non_Trivial_Init or
                      (CheckParent and Assigned(ChildOf) and ChildOf.HasNonTrivialInitChild(True));
          end
        else
          Result:=False;
      end;


    function TObjectDef.RTTIMangledName(RT: TRTTIType): TSymStr;
      begin
        if not(ObjectType in [odt_objcclass,odt_objcprotocol]) then
          begin
            if not Is_Unique_ObjPasDef then
              Result:=inherited RTTIMangledName(RT)
            else
              Result:=ChildOf.RTTIMangledName(RT)
          end
        else
          begin
            { necessary in case of a dynamic array of nsobject, or
              if an nsobject field appears in a record that needs
              init/finalisation }
            if RT=InitRTTI then
              begin
                Result:=VoidPointerType.RTTIMangledName(RT);
                Exit;
              end;

            if not(TargetInfo.System in systems_objc_nfabi) then
              begin
                Result:=TargetAsm.LabelPrefix;
                case ObjectType of
                  odt_objcclass:
                    begin
                      case RT of
                        ObjCClassRTTI:
                          if not(oo_is_classhelper in ObjectOptions) then
                            Result:=Result+'_OBJC_CLASS_'
                          else
                            Result:=Result+'_OBJC_CATEGORY_';
                        ObjCMetaRTTI:
                          if not(oo_is_classhelper in ObjectOptions) then
                            Result:=Result+'_OBJC_METACLASS_'
                          else
                            InternalError(2009111511);
                        ObjCProtocolList:
                          if not(oo_is_classhelper in ObjectOptions) then
                            Result:=Result+'_OBJC_CLASS_PROTOCOLS_'
                          else
                            Result:=Result+'_OBJC_CATEGORY_PROTOCOLS_';
                        ObjCInstanceMethods:
                          Result:=Result+'_OBJC_INSTANCE_METHODS_';
                        ObjCClassMethods:
                          Result:=Result+'_OBJC_CLASS_METHODS_';
                        else
                         InternalError(2009092302);
                      end;
                    end;
                  odt_objcprotocol:
                    begin
                      case RT of
                        ObjCClassRTTI:
                          Result:=Result+'_OBJC_PROTOCOL_';
                        ObjCProtocolList:
                          Result:=Result+'_OBJC_PROTOCOL_REFS_';
                        ObjCInstanceMethods:
                          Result:=Result+'_OBJC_PROTOCOL_INSTANCE_METHODS_';
                        ObjCClassMethods:
                          Result:=Result+'_OBJC_PROTOCOL_CLASS_METHODS_';
                        ObjCProtInstanceMethodsOpt:
                          Result:=Result+'_OBJC_PROTOCOL_INSTANCE_METHODS_OPT_';
                        ObjCProtClassMethodsOpt:
                          Result:=Result+'_OBJC_PROTOCOL_CLASS_METHODS_OPT_';
                        else
                         InternalError(2026062801);
                      end
                    end
                  else
                   ;
                end;
              end
            else
              begin
                case ObjectType of
                  odt_objcclass:
                    begin
                      if (oo_is_classhelper in ObjectOptions) and
                         not(RT in [ObjCClassRTTI,ObjCProtocolList]) then
                        InternalError(2009111512);
                      case RT of
                        ObjCClassRTTI:
                          if not(oo_is_classhelper in ObjectOptions) then
                            Result:='_OBJC_CLASS_$_'
                          else
                            Result:='_OBJC_$_CATEGORY_';
                        ObjCMetaRTTI:
                          Result:='_OBJC_METACLASS_$_';
                        ObjCClassRORTTI:
                          Result:='__OBJC_CLASS_RO_$_';
                        ObjCMetaRORTTI:
                          Result:='__OBJC_METACLASS_RO_$_';
                        ObjCProtocolList:
                          if not(oo_is_classhelper in ObjectOptions) then
                            Result:='__OBJC_CLASS_PROTOCOLS_$_'
                          else
                            Result:='__OBJC_CATEGORY_PROTOCOLS_$_';
                        ObjCInstanceMethods:
                          Result:='__OBJC_$_INSTANCE_METHODS_';
                        ObjCClassMethods:
                          Result:='__OBJC_$_CLASS_METHODS_';
                        else
                         InternalError(2009092303);
                      end;
                    end;
                  odt_objcprotocol:
                    begin
                      Result:=Lower(TargetAsm.LabelPrefix);
                      case RT of
                        ObjCClassRTTI:
                          Result:=Result+'_OBJC_PROTOCOL_$_';
                        ObjCMetaRTTI:
                          Result:=Result+'_OBJC_LABEL_PROTOCOL_$_';
                        ObjCProtocolList:
                          Result:='__OBJC_$_PROTOCOL_REFS_';
                        ObjCProtocolMethodsTypeList:
                          Result:='__OBJC_$_PROTOCOL_METHOD_TYPES_';
                        ObjCInstanceMethods:
                          Result:='__OBJC_$_PROTOCOL_INSTANCE_METHODS_';
                        ObjCClassMethods:
                          Result:='__OBJC_$_PROTOCOL_CLASS_METHODS_';
                        ObjCProtInstanceMethodsOpt:
                          Result:='__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_';
                        ObjCProtClassMethodsOpt:
                          Result:='__OBJC_$_PROTOCOL_CLASS_METHODS_OPT_';
                        else
                          InternalError(2009092501);
                      end;
                    end;
                  else
                    InternalError(2013113005);
                end;
              end;
            Result:=Result+ObjExtName^;
          end;
      end;

    function TObjectDef.Is_Unique_ObjPasDef: Boolean;
        begin
          Result:=
            (df_unique in DefOptions) and
            Is_Class_Or_Interface_Or_DispInterface(Self)
        end;


    function TObjectDef.Members_Need_InitTable : Boolean;
      begin
        Members_Need_InitTable:=TObjectSymTable(SymTable).Needs_Init_Final or
                                  HasNonTrivialInitChild(True);
      end;


    function TObjectDef.IsPublishable : TPublishProperty;
      begin
         if ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TObjectDef.Get_Next_DispID: LongInt;
      begin
        Inc(FCurrentDispID);
        Result:=FCurrentDispID;
      end;

    function TObjectDef.Search_Enumerator_Get: TProcDef;
      begin
        Result:=inherited;
        if not Assigned(Result) and Assigned(ChildOf) then
          Result:=ChildOf.Search_Enumerator_Get;
      end;

    function TObjectDef.Search_Enumerator_Move: TProcDef;
      begin
        Result:=inherited;
        if not Assigned(Result) and Assigned(ChildOf) then
          Result:=ChildOf.Search_Enumerator_Move;
      end;

    function TObjectDef.Search_Enumerator_Current: TSym;
      begin
        Result:=inherited;
        if not Assigned(Result) and Assigned(ChildOf) then
          Result:=ChildOf.Search_Enumerator_Current;
      end;

    procedure TObjectDef.RegisterCreatedClassRefType;
      begin
        if not ClassRefCreatedInCurrentModule then
          begin
            ClassRefCreatedInCurrentModule:=True;
            if not (Owner.SymTableType in [LocalSymTable]) then
              CurrentModule.WPOInfo.AddCreatedObjTypeForClassRef(Self);
          end;
      end;


    procedure TObjectDef.RegisterCreatedObjectType;
      begin
        if not CreatedInCurrentModule then
          begin
            CreatedInCurrentModule:=True;
            if not (Owner.SymTableType in [LocalSymTable]) then
              CurrentModule.WPOInfo.AddCreatedObjType(Self);
          end;
      end;


    procedure TObjectDef.Register_Maybe_Created_Object_Type;
      begin
        { if we know it has been created for sure, no need
          to also record that it maybe can be created in
          this module
        }
        if not (CreatedInCurrentModule) and
           not (MaybeCreatedInCurrentModule) then
          begin
            MaybeCreatedInCurrentModule:=True;
            CurrentModule.WPOInfo.AddMaybeCreatedByClassRef(Self);
          end;
      end;


    procedure TObjectDef.Register_VMT_Call(Index: LongInt);
      begin
        if (Is_Object(Self) or Is_Class(Self)) then
          CurrentModule.WPOInfo.AddCalledVMTEntry(Self,Index);
      end;


    procedure CheckAndFinishMsg(Data: TObject; Arg: Pointer);
      var
        Def: TDef absolute Data;
        PD: TProcDef absolute Data;
        I,
        ParaCount: LongInt;
      begin
        if (Def.Typ=ProcDef) then
          begin
            { add all messages also under a dummy name to the symtable in
              which the objcclass/protocol/category is declared, so they can
              be called via id.<name>
            }
            CreateClassHelperForProcDef(PD,nil);

            { we have to wait until now to set the mangled name because it
              depends on the (possibly external) class name, which is defined
              at the very end.  }
            if not(po_msgstr in PD.ProcOptions) then
              begin
                CGMessagePos(PD.FileInfo,parser_e_objc_requires_msgstr);
                { recover to avoid internalerror later on }
                Include(PD.ProcOptions,po_msgstr);
                PD.MessageInf.Str:=StringDup('MissingDeclaration');
              end;
            { Mangled name is already set in case this is a copy of
              another type.  }
            if not(po_has_mangledname in PD.ProcOptions) then
              begin
                { check whether the number of formal parameters is correct,
                  and whether they have valid Objective-C types }
                ParaCount:=0;
                for I:=1 to Length(PD.MessageInf.Str^) do
                  if PD.MessageInf.Str^[I]=':' then
                    Inc(ParaCount);
                for I:=0 to PD.Paras.Count-1 do
                  if not(vo_is_hidden_para in TParaVarSym(PD.Paras[I]).VarOptions) and
                     not is_array_of_const(TParaVarSym(PD.Paras[I]).VarDef) then
                    Dec(ParaCount);
                if (ParaCount<>0) then
                  MessagePos(PD.FileInfo,sym_e_objc_para_mismatch);

                PD.SetMangledName(PD.ObjCMangledName);
              end
            else
              { all checks already done }
              Exit;
            if not(oo_is_external in PD.Struct.ObjectOptions) then
              begin
                if (po_varargs in PD.ProcOptions) then
                  MessagePos(PD.FileInfo,parser_e_varargs_need_cdecl_and_external)
                else
                  begin
                    { check for "array of const" parameters }
                    for I:=0 to PD.ParaST.SymList.Count-1 do
                      begin
                        if (TSym(PD.ParaST.SymList[I]).Typ=ParaVarSym) and
                           is_array_of_const(TParaVarSym(PD.ParaST.SymList[I]).VarDef) then
                          MessagePos(PD.FileInfo,parser_e_varargs_need_cdecl_and_external);
                      end;
                  end;
              end;
          end;
      end;


    procedure MarkPrivateFieldsUsed(Data: TObject; Arg: Pointer);
      var
        Sym: TSym absolute Data;
      begin
        if (Sym.Typ=FieldVarSym) and
           (TFieldVarSym(Sym).Visibility in [vis_private,vis_strictprivate]) then
          Sym.IncRefCount;
      end;


    procedure TObjectDef.Finish_ObjC_Data;
      begin
        Self.SymTable.DefList.ForEachCall(@CheckAndFinishMsg,nil);
        if (oo_is_external in ObjectOptions) then
          Self.SymTable.SymList.ForEachCall(@MarkPrivateFieldsUsed,nil);
      end;


    procedure VerifyObjCVarDef(Data: TObject; Arg: Pointer);
      var
        Sym: TAbstractVarSym absolute Data;
        Res: PBoolean absolute Arg;
        FoundErrorDef: TDef;
      begin
        if not(TSym(Data).Typ in [ParaVarSym,FieldVarSym]) then
          Exit;
        if (Sym.Typ=ParaVarSym) and
           ((vo_is_hidden_para in TParaVarSym(Sym).VarOptions) or
            is_array_of_const(TParaVarSym(Sym).VarDef)) then
          Exit;
        if not ObjCCheckType(Sym.VarDef,FoundErrorDef) then
          begin
            MessagePos1(Sym.FileInfo,type_e_objc_type_unsupported,FoundErrorDef.TypeName);
            Res^:=False;
          end;
      end;


    procedure VerifyObjCProcDefParas(Data: TObject; Arg: Pointer);
      var
        Def: TDef absolute Data;
        Res: PBoolean absolute Arg;
        FoundErrorDef: TDef;
      begin
        if (Def.Typ<>ProcDef) then
          Exit;
        { check parameter types for validity }
        TProcDef(Def).Paras.ForEachCall(@VerifyObjCVarDef,Arg);
        { check the result type for validity }
        if not ObjCCheckType(TProcDef(Def).ReturnDef,FoundErrorDef) then
          begin
            MessagePos1(TProcDef(Def).FuncRetSym.FileInfo,type_e_objc_type_unsupported,FoundErrorDef.TypeName);
            Res^:=False;
          end;
      end;


    function TObjectDef.Check_ObjC_Types: Boolean;
      begin
        { done in separate step from finish_objc_data, because when
          finish_objc_data is called, not all forwarddefs have been resolved
          yet and we need to know all types here }
        Result:=True;
        Self.SymTable.SymList.ForEachCall(@VerifyObjCVarDef,@Result);
        Self.SymTable.DefList.ForEachCall(@VerifyObjCProcDefParas,@Result);
      end;


    procedure DoCPPImportInfo(Data: TObject; Arg: Pointer);
      var
        Def: TDef absolute Data;
        PD: TProcDef absolute Data;
      begin
        if (Def.Typ=ProcDef) then
          begin
            PD.SetMangledName(TargetInfo.Cprefix+PD.CPlusPlusMangledName);
            if (oo_is_external in PD.Struct.ObjectOptions) then
              begin
                { copied from psub.read_proc }
                if Assigned(TObjectDef(PD.Struct).ImportLib) then
                   CurrentModule.AddExternalImport(TObjectDef(PD.Struct).ImportLib^,PD.MangledName,PD.MangledName,0,False,False)
                 else
                   begin
                     { add import name to external list for DLL scanning }
                     if tf_has_dllscanner in TargetInfo.Flags then
                       CurrentModule.DLLScannerInputList.Add(PD.MangledName,PD);
                   end;

              end;
          end;
      end;


    procedure TObjectDef.Finish_CPP_Data;
      begin
        Self.SymTable.DefList.ForEachCall(@DoCPPImportInfo,nil);
      end;


    procedure TObjectDef.Apply_RTTI_Directive(Dir: TRTTIDirective);
      begin
        RTTI.Clause:=Dir.Clause;
        RTTI.Options:=Dir.Options;
        if (Dir.Clause=rtc_inherit) and Assigned(ChildOf) and (ChildOf.RTTI.Clause<>rtc_none) then
          begin
            RTTI.Options[ro_methods]:=RTTI.Options[ro_methods]+ChildOf.RTTI.Options[ro_methods];
            RTTI.Options[ro_fields]:=RTTI.Options[ro_fields]+ChildOf.RTTI.Options[ro_fields];
            RTTI.Options[ro_properties]:=RTTI.Options[ro_properties]+ChildOf.RTTI.Options[ro_properties];
          end;
      end;

{$ifdef DEBUG_NODE_XML}
    function TObjectDef.XMLPrintType: AnsiString;
      begin
        if (oo_is_forward in ObjectOptions) then
          Result := '&lt;class prototype&gt;'
        else
          Result := '&lt;class&gt;';
      end;


    procedure TObjectDef.XMLPrintDefInfo(var T: Text; Sym: TSym);
      var
        I: TObjectOption;
        First: Boolean;
      begin
        inherited XMLPrintDefInfo(T, Sym);

        First := True;
        for I := Low(TObjectOption) to High(TObjectOption) do
          if I in ObjectOptions then
            begin
              if First then
                begin
                  Write(T, ' objectoptions="', I);
                  First := False;
                end
              else
                Write(T, ',', I)
            end;

        if not First then
          Write(T, '"');
      end;


    procedure TObjectDef.XMLPrintDefData(var T: Text; Sym: TSym);
      begin
        { There's nothing useful yet if the type is only forward-declared }
        if not (oo_is_forward in ObjectOptions) then
          begin
            if Assigned(ChildOf) then
              WriteLn(T, PrintNodeIndention, '<ancestor>', SanitiseXMLString(ChildOf.TypeSym.RealName), '</ancestor>');

            inherited XMLPrintDefData(T, Sym);
          end;
      end;
{$endif DEBUG_NODE_XML}


{****************************************************************************
                             TImplementedInterface
****************************************************************************}

    function TImplementedInterface.GetIOffset: LongInt;
      begin
        if (FIOffset=-1) and
           (IType in [EtFieldValue,EtFieldValueClass]) then
          Result:=TFieldVarSym(ImplementsField).FieldOffset
        else
          Result:=FIOffset;
      end;


    constructor TImplementedInterface.Create(AIntf: TObjectDef);
      begin
        inherited Create;
        IntfDef:=AIntf;
        IntfDefDeref.Reset;
        IOffset:=-1;
        IType:=EtStandard;
        NameMappings:=nil;
        ProcDefs:=nil;
      end;


    constructor TImplementedInterface.Create_Deref(IntfD,GetterD:TDeref);
      begin
        inherited Create;
        IntfDef:=nil;
        IntfDefDeref:=IntfD;
        ImplementsGetterDeref:=GetterD;
        IOffset:=-1;
        IType:=EtStandard;
        NameMappings:=nil;
        ProcDefs:=nil;
      end;


    destructor  TImplementedInterface.Destroy;
      var
        I : LongInt;
        MappedName : PShortString;
      begin
        if Assigned(NameMappings) then
          begin
            for I:=0 to NameMappings.Count-1 do
              begin
                MappedName:=PShortString(NameMappings[I]);
                StringDispose(MappedName);
              end;
            NameMappings.Free;
            NameMappings:=nil;
          end;
        if Assigned(ProcDefs) then
          begin
            ProcDefs.Free;
            ProcDefs:=nil;
          end;
        inherited Destroy;
      end;


    procedure TImplementedInterface.BuildDeref;
      begin
        IntfDefDeref.Build(IntfDef);
        ImplementsGetterDeref.Build(ImplementsGetter);
      end;


    procedure TImplementedInterface.Deref;
      begin
        IntfDef:=TObjectDef(IntfDefDeref.Resolve);
        ImplementsGetter:=TSym(ImplementsGetterDeref.Resolve);
      end;


    procedure TImplementedInterface.AddMapping(const OrigName,NewName: string);
      begin
        if not Assigned(NameMappings) then
          NameMappings:=TFPHashList.Create;
        NameMappings.Add(OrigName,StringDup(NewName));
      end;


    function TImplementedInterface.GetMapping(const OrigName: string):string;
      var
        MappedName : PShortString;
      begin
        Result:='';
        if not Assigned(NameMappings) then
          Exit;
        MappedName:=PShortString(NameMappings.Find(OrigName));
        if Assigned(MappedName) then
          Result:=MappedName^;
      end;


    procedure TImplementedInterface.AddImplProc(PD:TProcDef);
      begin
        if not Assigned(ProcDefs) then
          ProcDefs:=TFPObjectList.Create(False);
        { duplicate entries must be stored, because multiple }
        { interfaces can declare methods with the same name  }
        { and all of these get their own VMT entry           }
        ProcDefs.Add(PD);
      end;


    function TImplementedInterface.IsImplMergePossible(MergingIntf:TImplementedInterface;out Weight: LongInt): Boolean;
      var
        I : LongInt;
      begin
        Result:=False;
        { interfaces being implemented through delegation are not mergeable (FK) }
        if (IType<>EtStandard) or (MergingIntf.IType<>EtStandard) or not(Assigned(ProcDefs)) or not(Assigned(MergingIntf.ProcDefs)) then
          Exit;
        Weight:=0;
        { empty interface is mergeable }
        if ProcDefs.Count=0 then
          begin
            Result:=True;
            Exit;
          end;
        { The interface to merge must at least the number of
          procedures of this interface }
        if MergingIntf.ProcDefs.Count<ProcDefs.Count then
          Exit;
        for I:=0 to ProcDefs.Count-1 do
          begin
            if MergingIntf.ProcDefs[I]<>ProcDefs[I] then
              Exit;
          end;
        Weight:=ProcDefs.Count;
        Result:=True;
      end;


    function TImplementedInterface.GetCopy:TImplementedInterface;
      var
        I : LongInt;
      begin
        Result:=TImplementedInterface.Create(nil);
        { 1) the procdefs list will be freed once for each copy
          2) since the procdefs list owns its elements, those will also be freed for each copy
             Nope: procdefs are owned by their symtable, so no copy necessary
          3) idem for the name mappings
        }
        Result.FIOffset:=FIOffset;
        Result.IntfDef:=IntfDef;
        Result.IntfDefDeref.Reset;
        Result.IType:=IType;
        Result.VtblImplIntf:=VtblImplIntf;
        if Assigned(NameMappings) then
          begin
            Result.NameMappings:=TFPHashList.Create;
            for I:=0 to NameMappings.Count-1 do
              Result.NameMappings.Add(NameMappings.NameOfIndex(I),
                                      StringDup(PShortString(NameMappings.Items[I])^));
          end;
        if Assigned(ProcDefs) then
          begin
            Result.ProcDefs:=TFPObjectList.Create(False);
            { Note: this is probably wrong, because those procdefs are owned by
              the old objectdef from which we copy, what would be the correct way
              of doing this is to lookup the equivalent copy in the new owner
              and reference this instead... But this is complicated so let's try
              it this way until it blows up ok? }
            for I:=0 to ProcDefs.Count-1 do
              Result.ProcDefs.Add(TProcDef(ProcDefs[I]).GetCopy);
          end;
        Result.ImplementsGetter:=ImplementsGetter;
        Result.ImplementsGetterDeref.Reset;
        Result.ImplementsField:=ImplementsField;
      end;

{****************************************************************************
                                TFORWARDDEF
****************************************************************************}

   constructor TForwardDef.Create(const S:string;const Pos:TFilePosInfo);
     begin
        inherited Create(ForwardDef,True);
        ToSymName:=StringDup(S);
        ForwardPos:=Pos;
     end;


    function TForwardDef.GetTypeName:string;
      begin
        GetTypeName:='unresolved forward to '+ToSymName^;
      end;


    destructor TForwardDef.Destroy;
      begin
        StringDispose(ToSymName);
        inherited Destroy;
      end;

    function TForwardDef.GetCopy:TStoredDef;
      begin
        Result:=CForwardDef.Create(ToSymName^, ForwardPos);
      end;

{****************************************************************************
                               TUNDEFINEDDEF
****************************************************************************}

   constructor TUndefinedDef.Create(DoRegister:Boolean);
     begin
        inherited Create(UndefinedDef,DoRegister);
     end;


    constructor TUndefinedDef.PPULoad(PPUFile:TCompilerPPUFile);
      begin
         inherited PPULoad(UndefinedDef,PPUFile);
         PPULoadPlatform(PPUFile);
      end;

    function TUndefinedDef.GetTypeName:string;
      begin
        GetTypeName:='<undefined type>';
      end;


    procedure TUndefinedDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
         inherited PPUWrite(PPUFile);
         WriteEntry(PPUFile,IBUndefinedDef);
      end;


{****************************************************************************
                                  TERRORDEF
****************************************************************************}

    constructor TErrorDef.Create;
      begin
        inherited Create(ErrorDef,True);
        { prevent consecutive faults }
        SaveSize:=1;
      end;


    procedure TErrorDef.PPUWrite(PPUFile:TCompilerPPUFile);
      begin
        { Can't write errordefs to ppu }
        InternalError(200411063);
      end;


    function TErrorDef.GetTypeName:string;
      begin
        GetTypeName:='<erroneous type>';
      end;


    function TErrorDef.GetMangledParaName:TSymStr;
      begin
        GetMangledParaName:='error';
      end;


{****************************************************************************
                           Definition Helpers
****************************************************************************}

    function Is_InterfaceCOM(Def: TDef): Boolean;
      begin
        Is_InterfaceCOM:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_interfacecom);
      end;

    function Is_InterfaceCOM_Or_DispInterface(Def: TDef): Boolean;
      begin
        Is_InterfaceCOM_Or_DispInterface:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_interfacecom,odt_dispinterface]);
      end;

    function Is_Any_Interface_Kind(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          ((TObjectDef(Def).ObjectType in [odt_interfacecom,odt_dispinterface,odt_interfacecorba,odt_objcprotocol]) or
           Is_ObjCCategory(Def));
      end;

    function Is_InterfaceCORBA(Def: TDef): Boolean;
      begin
        Is_InterfaceCORBA:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_interfacecorba);
      end;

    function Is_Interface(Def: TDef): Boolean;
      begin
        Is_Interface:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_interfacecom,odt_interfacecorba]);
      end;


    function Is_DispInterface(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_dispinterface);
      end;


    function Is_Class(Def: TDef): Boolean;
      begin
        Is_Class:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_class);
      end;


    function Is_Object(Def: TDef): Boolean;
      begin
        Is_Object:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_object);
      end;


    function Is_CPPClass(Def: TDef): Boolean;
      begin
        Is_CPPClass:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_cppclass);
      end;


    function Is_ObjCClass(Def: TDef): Boolean;
      begin
        Is_ObjCClass:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_objcclass);
      end;


    function Is_ObjectPascal_Helper(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_helper);
      end;


    function Is_ObjCClassRef(Def: TDef): Boolean;
      begin
        Is_ObjCClassRef:=
          Assigned(Def) and
          (Def.Typ=ClassRefDef) and
          Is_ObjCClass(TClassRefDef(Def).PointedDef);
      end;


    function Is_ObjCProtocol(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType=odt_objcprotocol);
      end;


    function Is_ObjCCategory(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          { if used as a forward type }
          ((TObjectDef(Def).ObjectType=odt_objccategory) or
          { if used as after it has been resolved }
           ((TObjectDef(Def).ObjectType=odt_objcclass) and
            (oo_is_classhelper in TObjectDef(Def).ObjectOptions)));
      end;

    function Is_ObjC_Class_Or_Protocol(Def: TDef): Boolean;
      begin
         Result:=
           Assigned(Def) and
           (Def.Typ=ObjectDef) and
           (TObjectDef(Def).ObjectType in [odt_objcclass,odt_objcprotocol]);
      end;


    function Is_ObjC_Protocol_Or_Category(Def: TDef): Boolean;
      begin
         Result:=
           Assigned(Def) and
           (Def.Typ=ObjectDef) and
           ((TObjectDef(Def).ObjectType = odt_objcprotocol) or
            ((TObjectDef(Def).ObjectType = odt_objcclass) and
             (oo_is_classhelper in TObjectDef(Def).ObjectOptions)));
      end;

    function Is_ClassHelper(Def: TDef): Boolean;
      begin
         Result:=
           Is_ObjectPascal_Helper(Def) or
           Is_ObjCCategory(Def);
      end;

    function Is_Class_Or_Interface(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba]);
      end;


    function Is_Class_Or_Interface_Or_ObjC(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_objcclass,odt_objcprotocol]);
      end;


    function Is_Class_Or_Interface_Or_DispInterface_Or_ObjC(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol]);
      end;


    function Is_Class_Or_Interface_Or_Object(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_object]);
      end;


    function Is_Class_Or_Interface_Or_DispInterface(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface]);
      end;


    function Is_Implicit_Pointer_Object_Type(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper]);
      end;

    function Is_Implicit_Array_Pointer(Def: TDef): Boolean;
      begin
        Result:=is_dynamic_array(Def) or is_dynamicstring(Def);
      end;

    function Is_Class_Or_Object(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=ObjectDef) and
          (TObjectDef(Def).ObjectType in [odt_class,odt_object]);
      end;

    function Is_Record(Def: TDef): Boolean;
      begin
        Result:=
          Assigned(Def) and
          (Def.Typ=RecordDef);
      end;

    procedure LoadObjCTypes;
      begin
        ObjC_MetaClassType:=TPointerDef(Search_Named_Unit_GlobalType('OBJC','POBJC_CLASS',True).TypeDef);
        ObjC_SuperClassType:=TPointerDef(Search_Named_Unit_GlobalType('OBJC','POBJC_SUPER',True).TypeDef);
        ObjC_IDType:=TPointerDef(Search_Named_Unit_GlobalType('OBJC','ID',True).TypeDef);
        ObjC_SelType:=TPointerDef(Search_Named_Unit_GlobalType('OBJC','SEL',True).TypeDef);
        ObjC_ObjectType:=TRecordDef(Search_Named_Unit_GlobalType('OBJC','OBJC_OBJECT',True).TypeDef);
      end;


    procedure MaybeLoadCocoaTypes;
      var
        TSym: TTypeSym;
        CocoaUnit: string[15];
      begin
        if Assigned(ObjC_FastEnumeration) then
          Exit;
        if not(TargetInfo.System in [system_i386_iphonesim,system_aarch64_ios,system_x86_64_iphonesim,system_aarch64_iphonesim]) then
          CocoaUnit:='COCOAALL'
        else
          CocoaUnit:='IPHONEALL';
        TSym:=Search_Named_Unit_GlobalType(CocoaUnit,'NSFASTENUMERATIONPROTOCOL',False);
        if Assigned(TSym) then
          ObjC_FastEnumeration:=TObjectDef(TSym.TypeDef)
        else
          ObjC_FastEnumeration:=nil;
        TSym:=Search_Named_Unit_GlobalType(CocoaUnit,'NSFASTENUMERATIONSTATE',False);
        if Assigned(TSym) then
          ObjC_FastEnumerationState:=TRecordDef(TSym.TypeDef)
        else
          ObjC_FastEnumerationState:=nil;
      end;


    function Use_VectorFPU(Def : TDef) : Boolean;
      begin
{$ifdef x86}
{$define use_vectorfpuimplemented}
        Use_VectorFPU:=(is_single(Def) and (CurrentSettings.FPUType in sse_singlescalar)) or
          (is_double(Def) and (CurrentSettings.FPUType in sse_doublescalar)) or
          { Check vector types }
          (
            is_normal_array(Def) and
            (ado_IsVector in TArrayDef(Def).ArrayOptions) and
            (
              (
                is_single(TArrayDef(Def).ElementDef) and
                (
                  { SSE or AVX XMM register }
                  ((TArrayDef(Def).EleCount = 4) and (CurrentSettings.FPUType in sse_singlescalar)) or
                  { AVX YMM register }
                  ((TArrayDef(Def).EleCount = 8) and (CurrentSettings.FPUType in fpu_avx_instructionsets))

                  or
                  { AVX512 ZMM register }
                  ((TArrayDef(Def).EleCount = 16) and (CurrentSettings.FPUType in [fpu_avx512f]))

                )
              ) or
              (
                is_double(TArrayDef(Def).ElementDef) and
                (
                  { SSE or AVX XMM register }
                  ((TArrayDef(Def).EleCount = 2) and (CurrentSettings.FPUType in sse_doublescalar)) or
                  { AVX YMM register }
                  ((TArrayDef(Def).EleCount = 4) and (CurrentSettings.FPUType in fpu_avx_instructionsets))

                  { AVX512 ZMM register }
                  or ((TArrayDef(Def).EleCount = 8) and (CurrentSettings.FPUType in [fpu_avx512f]))

                )
              )
            )
          );
{$endif x86}
{$ifdef aarch64}
{$define use_vectorfpuimplemented}
        Use_VectorFPU:=True;
{$endif aarch64}

{$ifndef use_vectorfpuimplemented}
        Use_VectorFPU:=False;
{$endif}
      end;

    procedure Reset_All_Default_Types;
    { Those class pointers have to be set to nil manually }
    { after memory they point to have been released.      }
    { Necessary strictly for Textmode IDE.                }
    begin
       VoidPointerType:=nil;           { pointer for Void-pointeddef }
       CharPointerType:=nil;           { pointer for Char-pointeddef }
       WideCharPointerType:=nil;       { pointer for WideChar-pointeddef }
       VoidCodePointerType:=nil;       { pointer to code; corresponds to System.CodePointer }
       VoidStackPointerType:=nil;      { the pointer type used for accessing parameters and local vars on the stack }
       ParentFPVoidPointerType:=nil;   { void pointer with the size of the hidden parentfp parameter, passed to nested functions }
{$ifdef x86}
       VoidNearPointerType:=nil;
       VoidNearCSPointerType:=nil;
       VoidNearDSPointerType:=nil;
       VoidNearSSPointerType:=nil;
       VoidNearESPointerType:=nil;
       VoidNearFSPointerType:=nil;
       VoidNearGSPointerType:=nil;

{$endif x86}
       CUndefinedType:=nil;
       CFormalType:=nil;               { unique formal definition }
       CTypedFormalType:=nil;          { unique typed formal definition }
       VoidType:=nil;                  { Void (procedure) }
       CAnsiCharType:=nil;             { Char }
       CWideCharType:=nil;             { WideChar }
       CCharType:=nil;                 { either cansichartype or cwidechartype. Do not free }
       PasBool1Type:=nil;              { boolean type }
       PasBool8Type:=nil;
       PasBool16Type:=nil;
       PasBool32Type:=nil;
       PasBool64Type:=nil;
       Bool8Type:=nil;
       Bool16Type:=nil;
       Bool32Type:=nil;
       Bool64Type:=nil;

       U8IntType:=nil;                 { 8-Bit unsigned integer }
       S8IntType:=nil;                 { 8-Bit signed integer }
       U16IntType:=nil;                { 16-Bit unsigned integer }
       S16IntType:=nil;                { 16-Bit signed integer }
       U24IntType:=nil;                { 24-Bit unsigned integer }
       S24IntType:=nil;                { 24-Bit signed integer }
       U32IntType:=nil;                { 32-Bit unsigned integer }
       S32IntType:=nil;                { 32-Bit signed integer }
       U40IntType:=nil;                { 40-Bit unsigned integer }
       S40IntType:=nil;                { 40-Bit signed integer }
       U48IntType:=nil;                { 48-Bit unsigned integer }
       S48IntType:=nil;                { 48-Bit signed integer }
       U56IntType:=nil;                { 56-Bit unsigned integer }
       S56IntType:=nil;                { 56-Bit signed integer }
       U64IntType:=nil;                { 64-bit unsigned integer }
       S64IntType:=nil;                { 64-bit signed integer }
       U128IntType:=nil;               { 128-bit unsigned integer }
       S128IntType:=nil;               { 128-bit signed integer }
       S32FloatType:=nil;              { 32 bit floating point number }
       S64FloatType:=nil;              { 64 bit floating point number }
       S80FloatType:=nil;              { 80 bit floating point number }
       SC80FloatType:=nil;             { 80 bit floating point number but stored like in C }
       S64CurrencyType:=nil;           { pointer to a currency type }
       CShortStringType:=nil;          { pointer to type of short string const   }
       CLongStringType:=nil;           { pointer to type of long string const   }
       CAnsiStringType:=nil;           { pointer to type of ansi string const  }
       CWideStringType:=nil;           { pointer to type of wide string const  }
       CUnicodeStringType:=nil;
       OpenShortStringType:=nil;
       OpenCharArrayType:=nil;
       CFileType:=nil;
       MethodPointerType:=nil;         { typecasting of methodpointers to extract self }
       NestedProcPointerType:=nil;     { typecasting of nestedprocpointers to extract parentfp }
       HResultDef:=nil;
       TypeKindType:=nil;              { def of TTypeKind for correct handling of GetTypeKind parameters }
       { we use only one variant def for every variant class }
       CVariantType:=nil;
       COleVariantType:=nil;
       { default integer type, normally s32inttype on 32 bit systems and s64bittype on 64 bit systems }
       SIntType:=nil;
       UIntType:=nil;
       { integer types corresponding to OS_SINT/OS_INT }
       OSSIntType:=nil;
       OSUIntType:=nil;
       { integer types corresponding to the ALU size, sizeof(aint) and the ALUSInt/ALUUInt types in the system unit }
       ALUSIntType:=nil;
       ALUUIntType:=nil;
       { integer types corresponding to SizeInt and SizeUInt for the target platform }
       SizeUIntType:=nil;
       SizeSIntType:=nil;
       { unsigned and signed ord type with the same size as a pointer }
       PtrUIntType:=nil;
       PtrSIntType:=nil;
       { unsigned and signed ord type with the same size as a codepointer }
       CodePtrUIntType:=nil;
       CodePtrSIntType:=nil;
       { several types to simulate more or less C++ objects for GDB }
       VMTType:=nil;
       VMTArrayType:=nil;
       { type of classrefs used for debug information }
       PVMTType:=nil;
       { return type of the setjmp function }
       ExceptionReasonType:=nil;

       Class_TObject:=nil;
       Class_TCustomAttribute:=nil;
       Interface_IUnknown:=nil;
       Interface_IDispatch:=nil;
       Rec_TGUID:=nil;
       Rec_Jmp_Buf:=nil;
       Rec_ExceptAddr:=nil;
       ObjC_MetaClassType:=nil;
       ObjC_SuperClassType:=nil;
       ObjC_IDType:=nil;
       ObjC_SelType:=nil;
       ObjC_ObjectType:=nil;
       ObjC_ProtocolType:=nil;
       ObjC_FastEnumeration:=nil;
       ObjC_FastEnumerationState:=nil;



       { x86 vector types }
       X86_M64Type:=nil;
       X86_M128Type:=nil;
       X86_M128DType:=nil;
       X86_M128IType:=nil;
       X86_M256Type:=nil;
       X86_M256DType:=nil;
       X86_M256IType:=nil;
    end;

end.
