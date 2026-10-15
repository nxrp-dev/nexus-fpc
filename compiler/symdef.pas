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
       GlobType,Globals,tokens,ConstExp,
       { symtable }
       symconst,SymBase,symtype,
       { node }
       node,
       { aasm }
       aasmtai,
       CPUInfo,
       cgbase,
       parabase
       ;


    type
{************************************************
                    TDef
************************************************}

       TGenericConstraintData=class
         interfaces : TFPObjectList;
         interfacesderef : TFPList;
         flags : TGenericConstraintFlags;
         { only required while parsing }
         fileinfo : TFilePosInfo;
         constructor create;
         destructor Destroy;override;
         procedure ppuload(ppufile:TCompilerPPUFile);
         procedure ppuwrite(ppufile:TCompilerPPUFile);
         procedure buildderef;
         procedure deref;
       end;

       { trtti_attribute_list }

       TRTTIAttribute = class
          typesym         : TSym;
          typesymderef    : TDeref;
          typeconstr      : TDef;
          typeconstrderef : TDeref;
          { these two are not stored in PPU }
          constructorcall : TNode;
          constructorpd   : TDef;
          paras           : array of TNode;
          constructor ppuload(ppufile:TCompilerPPUFile);
          procedure ppuwrite(ppufile:TCompilerPPUFile);
          procedure PPULoadSubEntries(ppufile:TCompilerPPUFile);
          procedure PPUWriteSubEntries(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure buildderef;
          procedure deref;
       end;

       TRTTIAttributeList = class
          RTTIAttributes : TFPObjectList;
          { if the attribute list is bound to a def or symbol }
          IsBound : Boolean;
          class procedure bind(var dangling,owned:TRTTIAttributeList);
          class procedure copyandbind(alist :TRTTIAttributeList; var owned : TRTTIAttributeList);
          procedure addattribute(atypesym:TSym;typeconstr:TDef;constructorcall:TNode;constref paras:array of TNode);
          procedure addattribute(attr:TRTTIAttribute);
          destructor Destroy; override;
          function GetAttributeCount:LongInt;
          procedure buildderef;
          procedure deref;

          class function ppuload(ppufile:TCompilerPPUFile):TRTTIAttributeList;
          class procedure ppuwrite(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
          class procedure PPULoadSubEntries(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
          class procedure PPUWriteSubEntries(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
       end;

       { tstoreddef }

       TStoredDef = class(TDef)
       private
{$ifdef symansistr}
          _fullownerhierarchyname : AnsiString;
{$else symansistr}
          _fullownerhierarchyname : PShortString;
{$endif symansistr}
          procedure writeentry(ppufile: TCompilerPPUFile; ibnr: byte);
       protected
          typesymderef  : TDeref;
          procedure PPUWritePlatform(ppufile:TCompilerPPUFile);virtual;
          procedure PPULoadPlatform(ppufile:TCompilerPPUFile);virtual;
          { a (possibly) reusable def is always created on the basis of another
            def, and contains a reference to this other def. If this other
            def is in a non-persistent symboltable, the new def cannot actually
            be safely reused everywhere in the current module. This routine
            abstracts that checking, and also restores the symtable stack
            (which had to be reset before creating the new def, so that the new
             def did not automatically get added to its top) }
          class procedure SetupReusableDef(origdef, newdef: TDef; res: PHashSetItem; OldSymTableStack: TSymTableStack);
       public
{$ifdef EXTDEBUG}
          fileinfo   : TFilePosInfo;
{$endif}
          { generic support }
          genericdef      : TStoredDef;
          genericdefderef : TDeref;
          generictokenbuf : TDynamicArray;
          { this list contains references to the symbols that make up the
            generic parameters; the symbols are not owned by this list
            Note: this list is allocated on demand! }
          genericparas    : TFPHashObjectList;
          genericparaderefs : TFPList;
          { contains additional data if this def is a generic constraint
            Note: this class is allocated on demand! }
          genconstraintdata : TGenericConstraintData;
          { this is Nil if the def has no RTTI attributes }
          RTTIAttributeList : TRTTIAttributeList;
          { original def for "type <name>" declarations }
          orgdef          : TStoredDef;
          orgdefderef     : TDeref;
          constructor create(dt:TDefTyp;doregister:boolean);
          constructor ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
          destructor  Destroy;override;
          function getcopy : TStoredDef;virtual;
          procedure ppuwrite(ppufile:TCompilerPPUFile);virtual;
          { this is called directly after ppuload }
          procedure PPULoadSubEntries(ppufile:TCompilerPPUFile);virtual;
          { this is called directly after ppuwrite }
          procedure PPUWriteSubEntries(ppufile:TCompilerPPUFile);virtual;
          procedure buildderef;override;
          procedure buildderefimpl;override;
          procedure deref;override;
          procedure derefimpl;override;
          function  size:asizeint;override;
          function  getvardef:LongInt;override;
          function  alignment:shortint;override;
          function  IsPublishable : TPublishProperty;override;
          function  NeedsInitTable : boolean;override;
          function  HasNonTrivialInitChild(check_parent:boolean):boolean;override;
          function  RTTIMangledName(rt:TRTTIType):TSymStr;override;
          function  OwnerHierarchyName: string; override;
          function  OwnerHierarchyPrettyName: string; override;
          function  fullownerhierarchyname(skipprocparams:boolean;use_pretty : boolean):TSymStr;override;

          function  NeedsSeparateInitRTTI:boolean;override;
          function  in_currentunit: boolean;
          { regvars }
          function is_intregable : boolean;
          function is_fpuregable : boolean;
          { def can be put into a register if it is const/immutable }
          function is_const_intregable : boolean;
          { generics }
          procedure initgeneric;
          { this function can be used to determine whether a def is really a
            generic declaration or just a normal type declared inside another
            generic }
          function is_generic:boolean;
          { same as above for specializations }
          function is_specialization:boolean;
          { generic utilities }
          function is_generic_param_const(index:integer):boolean;inline;
          function get_generic_param_def(index:integer):TDef;inline;
          { registers this def in the unit's deflist; no-op if already registered }
          procedure RegisterDef; override;
          { add the def to the top of the symtable stack if it's not yet owned
            by another symtable }
          procedure maybe_put_in_symtable_stack;
       private
          savesize  : ASizeUInt;
       end;

       TFileTyp = (ft_text,ft_typed,ft_untyped);

       TFileDef = class(TStoredDef)
          filetyp : TFileTyp;
          typedfiledef : TDef;
          typedfiledefderef : TDeref;
          constructor createtext;virtual;
          constructor createuntyped;virtual;
          constructor createtyped(def : TDef);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function  GetTypeName:string;override;
          function  getmangledparaname:TSymStr;override;
          function  size:asizeint;override;
          procedure setsize;
          function alignment: shortint; override;
       end;
       TFileDefClass = class of TFileDef;

       TVariantDef = class(TStoredDef)
          varianttype : TVariantType;
          constructor create(v : TVariantType);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          function GetTypeName:string;override;
          function alignment : shortint;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  getvardef:LongInt;override;
          procedure setsize;
          function IsPublishable : TPublishProperty;override;
          function NeedsInitTable : boolean;override;
       end;
       TVariantDefClass = class of TVariantDef;

       TFormalDef = class(TStoredDef)
          typed:boolean;
          constructor create(Atyped:boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
       end;
       TFormalDefClass = class of TFormalDef;

       TForwardDef = class(TStoredDef)
          tosymname : PShortString;
          forwardpos : TFilePosInfo;
          constructor create(const s:string;const pos:TFilePosInfo);virtual;
          destructor Destroy;override;
          function getcopy:TStoredDef;override;
          function GetTypeName:string;override;
       end;
       TForwardDefClass = class of TForwardDef;

       TUndefinedDef = class(TStoredDef)
          constructor create(doregister:boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
       end;
       TUndefinedDefClass = class of TUndefinedDef;

       TErrorDef = class(TStoredDef)
          constructor create;virtual;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
          function  getmangledparaname : TSymStr;override;
       end;
       TErrorDefClass = class of TErrorDef;

       TAbstractPointerDef = class(TStoredDef)
          pointeddef : TDef;
          pointeddefderef : TDeref;
          constructor create(dt:TDefTyp;def:TDef);
          constructor ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderef;override;
          procedure deref;override;
          function size:asizeint;override;
          function alignment:shortint;override;
       end;

       TPointerDef = class(TAbstractPointerDef)
          has_pointer_math : boolean;
          constructor create(def:TDef);virtual;
          { returns a pointerdef for def, reusing an existing one in case it
            exists in the current module }
          class function getreusable(def: TDef): TPointerDef; virtual;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function getreusable_no_free(def: TDef): TPointerDef;
          function size:asizeint;override;
          function getcopy:TStoredDef;override;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
          {# returns the appropriate int type for pointer arithmetic with the given pointer type.
             When adding or subtracting a number to/from a pointer, this function returns the
             int type to which that number has to be converted, before the operation can be performed.
             Normally, this is sinttype, except on i8086, where it takes into account the
             special i8086 pointer types (near, far, huge). }
          function pointer_arithmetic_int_type:TDef;virtual;
          {# the unsigned version of pointer_arithmetic_int_type. Used with inc/dec. }
          function pointer_arithmetic_uint_type:TDef;virtual;
          {# returns the int type produced when subtracting two pointers of the given type.
             Normally, this is sinttype, except on i8086, where it takes into account the
             special i8086 pointer types (near, far, huge). }
          function pointer_subtraction_result_type:TDef;virtual;
          function compatible_with_pointerdef_size(ptr: TPointerDef): boolean; virtual;
          {# the integer index type used to convert the pointer to array (i.e. denotes int_type in: ptr[int_type]) }
          function converted_pointer_to_array_range_type:TDef;virtual;
       end;
       TPointerDefClass = class of TPointerDef;

       TProcDef = class;

       TAbstractRecordDef= class(TStoredDef)
       private
          rttistring     : string;
{$ifdef DEBUG_NODE_XML}
       protected
          procedure XMLPrintDefData(var T: Text; Sym: TSym); override;
{$endif DEBUG_NODE_XML}
       public
          objname,
          objrealname    : PShortString;
          { for C++ classes: name of the library this class is imported from }
          { for Java classes/records: package name }
          import_lib     : PShortString;
          SymTable       : TSymTable;
          cloneddef      : TAbstractRecordDef;
          cloneddefderef : TDeref;
          objectoptions  : TObjectOptions;
          rtti           : TRTTIDirective;
          { for targets that initialise typed constants via explicit assignments
            instead of by generating an initialised data section }
          tcinitcode     : TNode;
          constructor create(const n:string; dt:TDefTyp;doregister:boolean);
          constructor ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          destructor Destroy; override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          procedure check_forwards; virtual;
          function find_procdef_bytype(pt:TProcTypeOption): TProcDef;
          function GetSymtable(t:TGetSymTable):TSymTable;override;
          function is_packed:boolean;
          function RttiName: string;
          { enumerator support }
          function search_enumerator_get: TProcDef; virtual;
          function search_enumerator_move: TProcDef; virtual;
          function search_enumerator_current: TSym; virtual;
          { JVM }
          function jvm_full_typename(with_package_name: boolean): string;
          { check if the symtable contains a float field }
          function contains_float_field : boolean;
          { check if the symtable contains a field that spans an aword boundary }
          function contains_cross_aword_field: boolean;
          { extended RTTI }
          procedure apply_rtti_directive(dir: TRTTIDirective); virtual;
          function is_visible_for_rtti(option: TRTTIOption; vis: TVisibility): boolean; inline;
          function rtti_visibilities_for_option(option: TRTTIOption): TVisibilities; inline;
          function has_extended_rtti: boolean; inline;
          { update the name of the object, typically needed after getcopy }
          procedure setobjrealname(const n: string);
       end;

       PVariantRecDesc = ^TVariantRecDesc;

       TVariantRecBranch = record
         { we store only single values here and no ranges because tvariantrecdesc is only needed in iso mode
           which does not support range expressions in variant record definitions }
         values : array of TConstExprInt;
         nestedvariant : PVariantRecDesc;
       end;

       PPVariantRecDesc = ^PVariantRecDesc;

       TVariantRecDesc = record
         variantselector : TSym;
         variantselectorderef : TDeref;
         branches : array of TVariantRecBranch;
       end;

       TRecordDef = class(TAbstractRecordDef)
{$ifdef DEBUG_NODE_XML}
       protected
          function XMLPrintType: AnsiString; override;
{$endif DEBUG_NODE_XML}
       public
          variantrecdesc : PVariantRecDesc;
          isunion       : boolean;
          constructor create(const n:string; p:TSymTable);virtual;
          constructor create_global_internal(const n: string; PackRecords, RecordAlignMin: shortint); virtual;
          constructor create_internal(const n: string; PackRecords, RecordAlignMin: shortint; where: TSymTable); virtual;
          function add_field_by_def(const optionalname: TIDString; def: TDef): TSym;
          procedure add_fields_from_deflist(fieldtypes: TFPList);
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function  size:asizeint;override;
          function  alignment : shortint;override;
          function  padalignment: shortint;
          function  GetTypeName:string;override;
          { debug }
          function  NeedsInitTable : boolean;override;
          function  NeedsSeparateInitRTTI:boolean;override;
          function  HasNonTrivialInitChild(check_parent:boolean):boolean;override;
       end;
       TRecordDefClass = class of TRecordDef;

       TObjectDef = class;

       { TImplementedInterface }

       TImplementedInterface = class
        private
         fIOffset      : LongInt;
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
         constructor create(aintf: TObjectDef);virtual;
         constructor create_deref(intfd,getterd:TDeref);virtual;
         destructor  Destroy; override;
         function getcopy:TImplementedInterface;
         procedure buildderef;
         procedure deref;
         procedure AddMapping(const origname, newname: string);
         function  GetMapping(const origname: string):string;
         procedure AddImplProc(pd:TProcDef);
         function  IsImplMergePossible(MergingIntf:TImplementedInterface;out weight: LongInt): boolean;
         property  IOffset: LongInt read GetIOffset write fIOffset;
       end;
       TImplementedInterfaceClass = class of TImplementedInterface;

       { tvmtentry }
       TVMTEntry = record
         procdef      : TProcDef;
         procdefderef : TDeref;
         visibility   : TVisibility;
       end;
       PVMTEntry = ^TVMTEntry;

       { tobjectdef }

       TVMCallStatic = (vmcs_default, vmcs_yes, vmcs_no, vmcs_unreachable);
       PMVCallStaticInfo = ^TMVCallStaticInfo;
       TMVCallStaticInfo = array[0..1024*1024-1] of TVMCallStatic;
       TObjectDef = class(TAbstractRecordDef)
       private
          fcurrent_dispid: LongInt;
{$ifdef DEBUG_NODE_XML}
       protected
          function XMLPrintType: AnsiString; override;
          procedure XMLPrintDefInfo(var T: Text; Sym: TSym); override;
          procedure XMLPrintDefData(var T: Text; Sym: TSym); override;
{$endif DEBUG_NODE_XML}
       public
          childof        : TObjectDef;
          childofderef   : TDeref;

          { for Object Pascal helpers }
          extendeddef   : TDef;
          extendeddefderef: TDeref;
          helpertype : THelperType;
          { for Objective-C: protocols and classes can have the same name there }
          objextname     : PShortString;
          { to be able to have a variable vmt position }
          { and no vmt field for objects without virtuals }
          vmtentries     : TFPList;
          vmcallstaticinfo : PMVCallStaticInfo;
          vmt_field       : TSym;
          vmt_fieldderef  : TDeref;
          iidguid        : PGUID;
          iidstr         : PShortString;
          { store implemented interfaces defs and name mappings }
          ImplementedInterfaces : TFPObjectList;
          { number of abstract methods (used by JVM target to determine whether
            or not the class should be marked as abstract: must be done if 1 or
            more abstract methods) }
          abstractcnt    : LongInt;
          writing_class_record_dbginfo,
          { a class of this type has been created in this module }
          created_in_current_module,
          { a loadvmtnode for this class has been created in this
            module, so if a classrefdef variable of this or a parent
            class is used somewhere to instantiate a class, then this
            class may be instantiated
          }
          maybe_created_in_current_module,
          { a "class of" this particular class has been created in
            this module
          }
          classref_created_in_current_module : boolean;
          objecttype     : TObjectTyp;
          { for interfaces that can be invoked using Invoke(),
            this is the definition of the hidden class that is generated by the compiler.
            we need this definition to reference it in the RTTI.
            Since interfaces can inherit, so can these hidden classes,
            so we need to write this to the ppu to be able to reference the parents.
          }
          hiddenclassdef : TObjectDef;
          hiddenclassdefref : TDeref;
          constructor create(ot:TObjectTyp;const n:string;c:TObjectDef;doregister:boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor  Destroy;override;
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function GetTypeName:string;override;
          procedure buildderef;override;
          procedure deref;override;
          procedure derefimpl;override;
          procedure copyvmtentries(objdef:TObjectDef);
          function  getparentdef:TDef;override;
          function  size : asizeint;override;
          function  alignment:shortint;override;
          function  vmtmethodoffset(index:LongInt):LongInt;
          function  members_need_inittable : boolean;
          { this should be called when this class implements an interface }
          procedure prepareguid;
          function  IsPublishable : TPublishProperty;override;
          function  NeedsInitTable : boolean;override;
          function  NeedsSeparateInitRTTI : boolean;override;
          function  HasNonTrivialInitChild(check_parent:boolean):boolean;override;
          function  RTTIMangledName(rt:TRTTIType):TSymStr;override;
          function  is_unique_objpasdef: boolean;
          function  vmt_mangledname : TSymStr;
          function  vmt_def: TRecordDef;
          procedure check_forwards; override;
          procedure insertvmt;
          function  vmt_offset: asizeint;
          procedure set_parent(c : TObjectDef);
          function find_destructor: TProcDef;
          function implements_any_interfaces: boolean;
          function register_implemented_interface(intfdef:TObjectDef;useguid:boolean):TImplementedInterface;
          { dispinterface support }
          function get_next_dispid: LongInt;
          { enumerator support }
          function search_enumerator_get: TProcDef; override;
          function search_enumerator_move: TProcDef; override;
          function search_enumerator_current: TSym; override;
          { WPO }
          procedure RegisterCreatedObjectType;override;
          procedure register_maybe_created_object_type;
          procedure RegisterCreatedClassRefType;
          procedure register_vmt_call(index:LongInt);
          { ObjC }
          procedure finish_objc_data;
          function check_objc_types: boolean;
          { C++ }
          procedure finish_cpp_data;
          procedure apply_rtti_directive(dir: TRTTIDirective); override;
       end;
       TObjectDefClass = class of TObjectDef;

       TClassRefDef = class(TAbstractPointerDef)
          constructor create(def:TDef);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function getcopy:TStoredDef;override;
          function GetTypeName:string;override;
          function IsPublishable : TPublishProperty;override;
          function RTTIMangledName(rt:TRTTIType):TSymStr;override;
          procedure RegisterCreatedObjectType;override;
       end;
       TClassRefDefClass = class of TClassRefDef;

       TArrayDef = class(TStoredDef)
          lowrange,
          highrange     : asizeint;
          rangedef      : TDef;
          rangedefderef : TDeref;
          arrayoptions  : TArrayDefOptions;
          SymTable      : TSymTable;
       protected
          _elementdef      : TDef;
          _elementdefderef : TDeref;
          procedure setelementdef(def:TDef);
          class function getreusable_intern(def: TDef; elems: asizeint; const options: TArrayDefOptions): TArrayDef;
       public
          function elesize : asizeint;
          function elepackedbitsize : asizeint;
          function elecount : ASizeUInt;
          constructor create_from_pointer(def: TPointerDef);virtual;
          constructor create(l, h: asizeint; def: TDef);virtual;
          constructor create_vector(l,h:asizeint; def:TDef);
          constructor create_openarray;virtual;
          class function getreusable(def: TDef; elems: asizeint): TArrayDef;
          class function getreusable_vector(def: TDef; elems: asizeint): TArrayDef;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function getreusable_no_free(def: TDef; elems: asizeint): TArrayDef;
          class function getreusable_no_free_vector(def: TDef; elems: asizeint): TArrayDef;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy; override;
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
          function  getmangledparaname : TSymStr;override;
          procedure buildderef;override;
          procedure deref;override;
          function size : asizeint;override;
          function alignment : shortint;override;
          { returns the label of the range check string }
          function NeedsInitTable : boolean;override;
          function NeedsSeparateInitRTTI : boolean;override;
          property elementdef : TDef read _elementdef write setelementdef;
          function IsPublishable : TPublishProperty;override;
          function is_hwvector: boolean;
       end;
       TArrayDefClass = class of TArrayDef;

       TOrdDef = class(TStoredDef)
          low,high : TConstExprInt;
          ordtype  : TOrdType;
          constructor create(t : TOrdType;v,b : TConstExprInt; doregister: boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  IsPublishable : TPublishProperty;override;
          function  GetTypeName:string;override;
          function alignment:shortint;override;
          procedure setsize;
          function  packedbitsize: asizeint; override;
          function getvardef : LongInt;override;
       end;
       TOrdDefClass = class of TOrdDef;

       TFloatDef = class(TStoredDef)
          floattype : TFloatType;
          constructor create(t: TFloatType; doregister: boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function alignment:shortint;override;
          function structalignment: shortint;override;
          procedure setsize;
          function  getvardef:LongInt;override;
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
          returndef       : TDef;
          returndefderef  : TDeref;
          parast          : TSymTable;
          paras           : TParaList;
          proctypeoption  : TProcTypeOption;
          proccalloption  : TProcCallOption;
          procoptions     : TProcOptions;
          callerargareasize,
          calleeargareasize: PInt;
          funcretloc : array[callerside..calleeside] of TCGPara;
          has_paraloc_info : TCallerCallee; { paraloc info is available }
          { number of user visible parameters }
          maxparacount,
          minparacount    : word;
          constructor create(dt:TDefTyp;level:byte;doregister:boolean);
          constructor ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure  ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderef;override;
          procedure deref;override;
          procedure calcparas;
          function mangledprocparanames(oldlen : LongInt) : string;
          function  typename_paras(pno: TProcNameOptions): AnsiString;
          function  is_methodpointer:boolean;virtual;
          function  is_addressonly:boolean;virtual;
          function  no_self_node:boolean;
          { get either a copy as a procdef or procvardef }
          function  getcopyas(newtyp:TDefTyp;copytyp:TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef; virtual;
          function  compatible_with_pointerdef_size(ptr: TPointerDef): boolean; virtual;
          procedure check_mark_as_nested;
          procedure init_paraloc_info(side: TCallerCallee);
          procedure done_paraloc_info(side: TCallerCallee);
          function stack_tainting_parameter(side: TCallerCallee): boolean;
          function is_pushleftright: boolean;virtual;
          function address_type:TDef;virtual;
          { address type, generated for ofs() }
          function ofs_address_type:TDef;virtual;
          function generate_safecall_wrapper: boolean; virtual;
          { returns true if the def is a generic param of the procdef }
          function is_generic_param(def:TDef): boolean;

          function wpo_may_create_instance(optionalmethodpointer: TNode): boolean;
       private
          procedure count_para(p:TObject;arg:pointer);
          procedure insert_para(p:TObject;arg:pointer);
       end;

       TProcVarDef = class(TAbstractProcDef)
          constructor create(level:byte;doregister:boolean);virtual;
          { returns a procvardef that represents the address of a proc(var)def }
          class function getreusableprocaddr(def: TAbstractProcDef; copytyp: TCacheableProcCopyType): TProcVarDef; virtual;
          { same as above, but in case the def must never be freed after the
            current module has been compiled -- even if the def was not written
            to the ppu file (for defs in para locations, as we don't reset them
            so we don't have to recalculate them all the time) }
          class function getreusableprocaddr_no_free(def: TAbstractProcDef): TProcVarDef;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetSymtable(t:TGetSymTable):TSymTable;override;
          function  size : asizeint;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function  is_methodpointer:boolean;override;
          function  is_addressonly:boolean;override;
          function  getmangledparaname:TSymStr;override;
          function getcopyas(newtyp: TDefTyp; copytyp: TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef; override;
       end;
       TProcVarDefClass = class of TProcVarDef;

       TMessageInf = record
         case integer of
           0 : (str : PShortString);
           1 : (i : LongInt);
       end;

       TInliningInfo = record
          { node tree }
          code  : TNode;
          flags : TProcInfoFlags;
       end;
       PInliningInfo = ^TInliningInfo;

       TCapturedSymInfo = record
         sym : TSym;
         def : TDef;
         { the location where the symbol was first encountered }
         fileinfo : TFilePosInfo;
       end;
       PCapturedSymInfo = ^TCapturedSymInfo;

       TImplProcDefInfo = record
          resultname : PShortString;
          parentfpstruct: TSym;
          parentfpstructptrtype: TDef;
          parentfpinitblock: TNode;
          procstarttai,
          procendtai   : TAI;
          skpara: pointer;
          personality: TProcDef;
          was_anonymous,
          has_capturer,
          forwarddef,
          interfacedef : boolean;
          hasforward  : boolean;
          is_implemented : boolean;
          capturedsyms : TFPList;
       end;
       PImplProcDefInfo = ^TImplProcDefInfo;

       { tprocdef }

       TProcDef = class(TAbstractProcDef)
       protected
{$ifdef symansistr}
         _mangledname : AnsiString;
{$else symansistr}
         _mangledname : PShortString;
{$endif}
         _parentfpsym : TSym;
         { information that is only required until the implementation of the
           procdef has been handled }
         implprocdefinfo : PImplProcDefInfo;

         function store_localst:boolean;

         function GetResultName: PShortString;
         procedure SetResultName(AValue: PShortString);
         function GetParentFPStruct: TSym;
         procedure SetParentFPStruct(AValue: TSym);
         function GetParentFPStructPtrType: TDef;
         procedure SetParentFPStructPtrType(AValue: TDef);
         function GetParentFPInitBlock: TNode;
         procedure SetParentFPInitBlock(AValue: TNode);
         function Getprocstarttai: TAI;
         procedure Setprocstarttai(AValue: TAI);
         function Getprocendtai: TAI;
         procedure Setprocendtai(AValue: TAI);
         function Getskpara: pointer;
         procedure Setskpara(AValue: pointer);
         function Getpersonality: TProcDef;
         procedure Setpersonality(AValue: TProcDef);
         function Getforwarddef: boolean;
         procedure Setforwarddef(AValue: boolean);
         function Getinterfacedef: boolean;
         procedure Setinterfacedef(AValue: boolean);virtual;
         function Gethasforward: boolean;
         procedure Sethasforward(AValue: boolean);
         function GetIsEmpty: boolean;
         procedure SetIsEmpty(AValue: boolean);
         function GetHasInliningInfo: boolean;
         procedure SetHasInliningInfo(AValue: boolean);
         function Getis_implemented: boolean;
         procedure Setis_implemented(AValue: boolean);
         function getwas_anonymous:boolean;
         procedure setwas_anonymous(avalue:boolean);
         function gethas_capturer:boolean;
         procedure sethas_capturer(avalue:boolean);
         function Getcapturedsyms:TFPList;
         function getparentfpsym: TSym;
       public
          messageinf : TMessageInf;
          dispid : LongInt;
{$ifndef EXTDEBUG}
          { where is this function defined and what were the symbol
            flags, needed here because there
            is only one symbol for all overloaded functions
            EXTDEBUG has fileinfo in tdef (PFV) }
          fileinfo : TFilePosInfo;
{$endif}
          symoptions : TSymOptions;
          deprecatedmsg : PShortString;
          { generic support }
          genericdecltokenbuf : TDynamicArray;
          { symbol owning this definition }
          procsym : TSym;
          procsymderef : TDeref;
          { alias names }
          aliasnames : TCmdStrList;
          { symtables }
          localst : TSymTable;
          funcretsym : TSym;
          funcretsymderef : TDeref;
          struct : TAbstractRecordDef;
          structderef : TDeref;
          implprocoptions: TImplProcOptions;
          { import info }
          import_dll,
          import_name : PShortString;
          { info for inlining the subroutine, if this pointer is nil,
            the procedure can't be inlined }
          inlininginfo : PInliningInfo;
          import_nr    : word;
          extnumber    : word;
          { set to a value different from tsk_none in case this procdef is for
            a routine that has to be internally generated by the compiler }
          synthetickind: TSyntheticKind;
          visibility   : TVisibility;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
          seenmarker : pointer; // used for filtering in tcandidate
{$endif}
{$ifdef symansistr}
          section: AnsiString;
{$else symansistr}
          section: PShortString;
{$endif}
          { only needed when actually compiling a unit, no need to save/load from ppu }
          invoke_helper : TProcDef;
          copied_from : TProcDef;
          constructor create(level:byte;doregister:boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor  Destroy;override;
          procedure   freeimplprocdefinfo;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure buildderefimpl;override;
          procedure deref;override;
          procedure derefimpl;override;
          function  GetSymtable(t:TGetSymTable):TSymTable;override;
          { warnings:
              * the symtablestack top has to be the symtable to which the copy
                should be added
              * getcopy does not create a finished/ready-to-use procdef; it
                needs to be finalised afterwards by calling
                symcreat.finish_copied_procdef() afterwards
          }
          function  getcopyas(newtyp:TDefTyp;copytyp:TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef; override;
          function  getcopy: TStoredDef; override;
          function  GetTypeName : string;override;
          function  mangledname : TSymStr; virtual;
          procedure setmangledname(const s : TSymStr);
          function  needsglobalasmsym: boolean;
          procedure setcompilerprocname;
          function  fullprocname(showhidden:boolean):AnsiString;
          function  customprocname(pno: TProcNameOptions):AnsiString;
          function  defaultmangledname: TSymStr;
          function  cplusplusmangledname : TSymStr;
          function  objcmangledname : TSymStr;
          function  is_methodpointer:boolean;override;
          function  is_addressonly:boolean;override;
          procedure make_external;
          procedure init_genericdecl;
          procedure reset_after_conv;

          function get_funcretsym_info(out ressym: TSym; out resdef: TDef): boolean; virtual;
          function get_safecall_funcretsym_info(out ressym: TSym; out resdef: TDef): boolean; virtual;

          procedure add_captured_sym(sym:TSym;def:TDef;const filepos:TFilePosInfo);

          { returns whether the mangled name or any of its aliases is equal to
            s }
          function  has_alias_name(const s: TSymStr):boolean;

          { aliases to fields only required when a function is implemented in
            the current unit }
          property resultname: PShortString read GetResultName write SetResultName;
          { temporary reference to structure containing copies of all local
            variables and parameters accessed by nested routines; reference to
            this structure is passed as "parent frame pointer" on targets that
            lack this concept (at least JVM and LLVM); no need to save to/
            restore from ppu, since nested routines are always in the same
            unit }
          property parentfpstruct: TSym read GetParentFPStruct write SetParentFPStruct;
          { pointer to parentfpstruct's type (not yet valid during parsing, so
            cannot be used for $parentfp parameter) (no need to save to ppu) }
          property parentfpstructptrtype: TDef read GetParentFPStructPtrType write SetParentFPStructPtrType;
          { code to copy the parameters accessed from nested routines into the
            parentfpstruct (no need to save to ppu) }
          property parentfpinitblock: TNode read GetParentFPInitBlock write SetParentFPInitBlock;
          { First/last assembler symbol/instruction in aasmoutput list.
            Note: initialised after compiling the code for the procdef, but
              not saved to/restored from ppu. Used when inserting debug info }
          property procstarttai: TAI read Getprocstarttai write Setprocstarttai;
          property procendtai: TAI read Getprocendtai write Setprocendtai;
          { optional parameter for the synthetic routine generation logic }
          property skpara: pointer read Getskpara write Setskpara;
          { ABI-conformant exception handling personality function }
          property personality: TProcDef read Getpersonality write Setpersonality;
          { true, if the procedure is only declared
            (forward procedure) }
          property forwarddef: boolean read Getforwarddef write Setforwarddef;
          { true if the procedure is declared in the interface }
          property interfacedef: boolean read Getinterfacedef write Setinterfacedef;
          { true if the procedure has a forward declaration }
          property hasforward: boolean read Gethasforward write Sethasforward;
          { true if the routine's body is empty }
          property isempty: boolean read GetIsEmpty write SetIsEmpty;
          { true if all information required to inline this routine is available }
          property has_inlininginfo: boolean read GetHasInliningInfo write SetHasInliningInfo;
          { returns the $parentfp parameter for nested routines }
          property parentfpsym: TSym read getparentfpsym;
          { true if the implementation part for this procdef has been handled }
          property is_implemented: boolean read Getis_implemented write Setis_implemented;
          { valid if the procdef captures any symbols from outer scopes }
          property capturedsyms:TFPList read Getcapturedsyms;
          { true if this procdef was originally an anonymous function }
          property was_anonymous:boolean read getwas_anonymous write setwas_anonymous;
          { true if the procdef has a capturer for anonymous functions }
          property has_capturer:boolean read gethas_capturer write sethas_capturer;
       end;
       TProcDefClass = class of TProcDef;

       { single linked list of overloaded procs }
       PProcDefList = ^TProcDefList;
       TProcDefList = record
         def  : TProcDef;
         defderef : TDeref;
         next : PProcDefList;
       end;

       TStringDef = class(TStoredDef)
          encoding   : TStringEncoding;
          stringtype : TStringType;
          len        : asizeint;
          constructor createshort(l: byte; doregister: boolean);virtual;
          constructor loadshort(ppufile:TCompilerPPUFile);
          constructor createlong(l: asizeint; doregister: boolean);virtual;
          constructor loadlong(ppufile:TCompilerPPUFile);
          constructor createansi(aencoding: TStringEncoding; doregister: boolean);virtual;
          constructor loadansi(ppufile:TCompilerPPUFile);
          constructor createwide(doregister: boolean);virtual;
          constructor loadwide(ppufile:TCompilerPPUFile);
          constructor createunicode(doregister: boolean);virtual;
          constructor loadunicode(ppufile:TCompilerPPUFile);virtual;
          function getcopy : TStoredDef;override;
          function  stringtypname:string;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function  GetTypeName:string;override;
          function  getmangledparaname:TSymStr;override;
          function  IsPublishable : TPublishProperty;override;
          function  size:asizeint;override;
          function alignment : shortint;override;
          function  NeedsInitTable : boolean;override;
          function  getvardef:LongInt;override;
          { returns the default char type def for the string }
          function get_default_char_type: TDef;
          { returns the default string type }
          function get_default_string_type: TDef;
       end;
       TStringDefClass = class of TStringDef;

       TEnumDef = class(TStoredDef)
          minval,
          maxval    : asizeint;
          basedef   : TEnumDef;
          basedefderef : TDeref;
          SymTable  : TSymTable;
          has_jumps : boolean;
          constructor create;virtual;
          constructor create_subrange(_basedef:TEnumDef;_min,_max:asizeint);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          procedure calcsavesize(PackEnum: shortint);
          function  packedbitsize: asizeint; override;
          procedure setmax(_max:asizeint);
          procedure setmin(_min:asizeint);
          function  min:asizeint;
          function  max:asizeint;
          function  getfirstsym:TSym;
          function  int2enumsym(l: asizeint): TSym;
          { returns basedef if assigned, otherwise self }
          function getbasedef: TEnumDef;
       end;
       TEnumDefClass = class of TEnumDef;

       TSetDef = class(TStoredDef)
          elementdef : TDef;
          elementdefderef : TDeref;
          { setbase is the value of the lowest value being representable by the set, this could
            be lower then the lowest value being a valid value from the declaration: a set [3..4] might
            have a setbase of 0 for code generation/alignment reasons }
          setbase,
          { setlow is the lowest value valid according to the declaration of a set, i.e. for a set [3..4] it is really 3 }
          setlow,
          setmax   : asizeint;
          constructor create(def: TDef; low, high: asizeint; doregister: boolean);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function getcopy : TStoredDef;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function  GetTypeName:string;override;
          function  IsPublishable : TPublishProperty;override;
          function alignment: shortint; override;
       end;
       TSetDefClass = class of TSetDef;


       TGenericDummyEntry = class
         dummysym : TSym;
         resolvedsym : TSym;
       end;


       TDefAwareSymTableStack = class(TSymTableStack)
       private
         procedure add_helpers_and_generics(st:TSymTable;addgenerics:boolean);
         procedure remove_helpers_and_generics(st:TSymTable);inline;
         procedure remove_helpers(st:TSymTable);
         procedure remove_generics(st:TSymTable);
         procedure pushcommon(st:TSymTable);inline;
       public
         procedure push(st: TSymTable); override;
         procedure pushafter(st,afterst:TSymTable); override;
         procedure pop(st: TSymTable); override;
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
       cimplementedinterface: TImplementedInterfaceClass;
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
       generrordef,               { error in definition }
       voidpointertype,           { pointer for Void-pointeddef }
       charpointertype,           { pointer for Char-pointeddef }
       widecharpointertype,       { pointer for WideChar-pointeddef }
       voidcodepointertype,       { pointer to code; corresponds to System.CodePointer }
       voidstackpointertype,      { the pointer type used for accessing parameters and local vars on the stack }
       parentfpvoidpointertype,   { void pointer with the size of the hidden parentfp parameter, passed to nested functions }
{$ifdef x86}
       voidnearpointertype,
       voidnearcspointertype,
       voidneardspointertype,
       voidnearsspointertype,
       voidnearespointertype,
       voidnearfspointertype,
       voidneargspointertype,

{$endif x86}
       cundefinedtype,
       cformaltype,               { unique formal definition }
       ctypedformaltype,          { unique typed formal definition }
       voidtype,                  { Void (procedure) }
       cansichartype,             { Char }
       cwidechartype,             { WideChar }
       cchartype,                 { either cansichartype or cwidechartype. Do not free }
       pasbool1type,              { boolean type }
       pasbool8type,
       pasbool16type,
       pasbool32type,
       pasbool64type,
       bool8type,
       bool16type,
       bool32type,
       bool64type,                { implement me }

       u8inttype,                 { 8-Bit unsigned integer }
       s8inttype,                 { 8-Bit signed integer }
       u16inttype,                { 16-Bit unsigned integer }
       s16inttype,                { 16-Bit signed integer }
       u24inttype,                { 24-Bit unsigned integer }
       s24inttype,                { 24-Bit signed integer }
       u32inttype,                { 32-Bit unsigned integer }
       s32inttype,                { 32-Bit signed integer }
       u40inttype,                { 40-Bit unsigned integer }
       s40inttype,                { 40-Bit signed integer }
       u48inttype,                { 48-Bit unsigned integer }
       s48inttype,                { 48-Bit signed integer }
       u56inttype,                { 56-Bit unsigned integer }
       s56inttype,                { 56-Bit signed integer }
       u64inttype,                { 64-bit unsigned integer }
       s64inttype,                { 64-bit signed integer }
       u128inttype,               { 128-bit unsigned integer }
       s128inttype,               { 128-bit signed integer }
       s32floattype,              { 32 bit floating point number }
       s64floattype,              { 64 bit floating point number }
       s80floattype,              { 80 bit floating point number }
       sc80floattype,             { 80 bit floating point number but stored like in C }
       s64currencytype,           { pointer to a currency type }
       cshortstringtype,          { pointer to type of short string const   }
       clongstringtype,           { pointer to type of long string const   }
       cansistringtype,           { pointer to type of ansi string const  }
       cwidestringtype,           { pointer to type of wide string const  }
       cunicodestringtype,
       openshortstringtype,       { pointer to type of an open shortstring,
                                    needed for readln() }
       openchararraytype,         { pointer to type of an open array of char,
                                    needed for readln() }
       cfiletype,                 { get the same definition for all file }
                                  { used for stabs }
       methodpointertype,         { typecasting of methodpointers to extract self }
       nestedprocpointertype,     { typecasting of nestedprocpointers to extract parentfp }
       hresultdef,
       typekindtype,              { def of TTypeKind for correct handling of GetTypeKind parameters }
       { we use only one variant def for every variant class }
       CVariantType,
       colevarianttype,
       { default integer type, normally s32inttype on 32 bit systems and s64bittype on 64 bit systems }
       sinttype,
       uinttype,
       { integer types corresponding to OS_SINT/OS_INT }
       ossinttype,
       osuinttype,
       { integer types corresponding to the ALU size, sizeof(aint) and the ALUSInt/ALUUInt types in the system unit }
       alusinttype,
       aluuinttype,
       { integer types corresponding to SizeInt and SizeUInt for the target platform }
       sizeuinttype,
       sizesinttype,
       { unsigned and signed ord type with the same size as a pointer }
       ptruinttype,
       ptrsinttype,
       { unsigned and signed ord type with the same size as a codepointer }
       codeptruinttype,
       codeptrsinttype,
       { several types to simulate more or less C++ objects for GDB }
       vmttype,
       vmtarraytype,
       { type of classrefs, used for stabs }
       pvmttype,
       { return type of the setjmp function }
       exceptionreasontype      : TDef;

       { pointer to the ancestor of all classes }
       class_tobject : TObjectDef;
       { pointer to the base type for custom attributes }
       class_tcustomattribute : TObjectDef;
       { pointer to the ancestor of all COM interfaces }
       interface_iunknown : TObjectDef;
       { pointer to the ancestor of all dispinterfaces }
       interface_idispatch : TObjectDef;
       { pointer to the TGUID type
         of all interfaces         }
       rec_tguid : TRecordDef;

       { jump buffer type, used by setjmp }
       rec_jmp_buf : TRecordDef;

       { system.texceptaddr type, used by fpc_pushexceptaddr }
       rec_exceptaddr: TRecordDef;

       { Objective-C base types }
       objc_metaclasstype,
       objc_superclasstype,
       objc_idtype,
       objc_seltype              : TPointerDef;
       objc_objecttype           : TRecordDef;
       { base type of @protocol(protocolname) Objective-C statements }
       objc_protocoltype         : TObjectDef;
       { helper types for for-in "fast enumeration" support in Objective-C 2.0 }
       objc_fastenumeration      : TObjectDef;
       objc_fastenumerationstate : TRecordDef;



       { Java base types }
       { java.lang.Object }
       java_jlobject             : TObjectDef;
       { java.lang.Throwable }
       java_jlthrowable          : TObjectDef;
       { FPC base type for records }
       java_fpcbaserecordtype    : TObjectDef;
       { java.lang.String }
       java_jlstring             : TObjectDef;
       { java.lang.Enum }
       java_jlenum               : TObjectDef;
       { java.util.EnumSet }
       java_juenumset            : TObjectDef;
       { java.util.BitSet }
       java_jubitset             : TObjectDef;
       { FPC java implementation of ansistrings }
       java_ansistring           : TObjectDef;
       { FPC java implementation of shortstrings }
       java_shortstring          : TObjectDef;
       { FPC java procvar base class }
       java_procvarbase          : TObjectDef;

       { x86 vector types }
       x86_m64type,
       x86_m128type,
       x86_m128dtype,
       x86_m128itype,
       x86_m256type,
       x86_m256dtype,
       x86_m256itype             : TDef;


    function make_mangledname(const typeprefix:TSymStr;st:TSymTable;const suffix:TSymStr):TSymStr;
    function make_dllmangledname(const dllname,importname:TSymStr;
                                 import_nr : word; pco : TProcCallOption):TSymStr;

    { should be in the types unit, but the types unit uses the node stuff :( }
    function is_interfacecom(def: TDef): boolean;
    function is_interfacecom_or_dispinterface(def: TDef): boolean;
    function is_any_interface_kind(def: TDef): boolean;
    function is_interfacecorba(def: TDef): boolean;
    function is_interface(def: TDef): boolean;
    function is_dispinterface(def: TDef): boolean;
    function is_object(def: TDef): boolean;
    function is_class(def: TDef): boolean;
    function is_cppclass(def: TDef): boolean;
    function is_objectpascal_helper(def: TDef): boolean;
    function is_objcclass(def: TDef): boolean;
    function is_objcclassref(def: TDef): boolean;
    function is_objcprotocol(def: TDef): boolean;
    function is_objccategory(def: TDef): boolean;
    function is_objc_class_or_protocol(def: TDef): boolean;
    function is_objc_protocol_or_category(def: TDef): boolean;
    function is_classhelper(def: TDef): boolean;
    function is_class_or_interface(def: TDef): boolean;
    function is_class_or_interface_or_objc(def: TDef): boolean;
    function is_class_or_interface_or_objc_or_java(def: TDef): boolean;
    function is_class_or_interface_or_dispinterface_or_objc_or_java(def: TDef): boolean;
    function is_class_or_interface_or_object(def: TDef): boolean;
    function is_class_or_interface_or_dispinterface(def: TDef): boolean;
    function is_implicit_pointer_object_type(def: TDef): boolean;
    { returns true, if def is a type which is an implicit pointer to an array (dyn. array or dyn. string) }
    function is_implicit_array_pointer(def: TDef): boolean;
    function is_class_or_object(def: TDef): boolean;
    function is_record(def: TDef): boolean;

    function is_javaclass(def: TDef): boolean;
    function is_javaclassref(def: TDef): boolean;
    function is_javainterface(def: TDef): boolean;
    function is_java_class_or_interface(def: TDef): boolean;

    procedure loadobjctypes;
    procedure maybeloadcocoatypes;

    function use_vectorfpu(def : TDef) : boolean;

    function getansistringcodepage:TStringEncoding; inline;
    function getansistringdef:TStringDef;
    function getparaencoding(def:TDef):TStringEncoding; inline;

    function get_recorddef(prefix:TInternalTypePrefix;const fields:array of TDef; PackRecords:shortint): TRecordDef;
    { get a table def of the form
        record
          count: countdef;
          elements: array[0..count-1] of elementdef
        end;
      Returns both the outer record and the inner arraydef
    }
    procedure get_tabledef(prefix:TInternalTypePrefix;countdef,elementdef:TDef;count:LongInt;PackRecords:shortint;out recdef:TRecordDef;out arrdef:TArrayDef);

    function fileinfo_of_typesym_in_def(def:TDef;sym:TSym;out filepos:TFilePosInfo):boolean;
    procedure reset_all_default_types; {housekeeping for Textmode IDE sanity}

implementation

    uses
      SysUtils,
      CUtils,
      { global }
      Verbose,
      { target }
      Systems,paramgr,
      { symtable }
      SymSym,SymTable,defutil,objcdef,
      { parser }
      pgenutil,
      { module }
      FModule,ppu,
      { other }
      aasmbase,
      gendef,
      FPCHash,
      entfile
      ;

{****************************************************************************
                                  Helpers
****************************************************************************}


    function fileinfo_of_typesym_in_def(def:TDef;sym:TSym;out filepos:TFilePosInfo):boolean;
      var
        gst : TGetSymTable;
        st : TSymTable;
        i : LongInt;
        srsym : TSym;
      begin
        result:=false;
        if sym.typ<>typesym then
          exit;
        for gst:=low(TGetSymTable) to high(TGetSymTable) do
          begin
            st:=def.getsymtable(gst);
            if not Assigned(st) then
              continue;
            for i:=0 to st.symlist.count-1 do
              begin
                srsym:=TSym(st.symlist[i]);
                case srsym.typ of
                  fieldvarsym,
                  paravarsym:
                    if TAbstractVarSym(srsym).vardef.typesym=sym then
                      begin
                        filepos:=srsym.fileinfo;
                        result:=true;
                        break;
                      end;
                  typesym:
                    begin
                      result:=fileinfo_of_typesym_in_def(TTypeSym(srsym).typedef,sym,filepos);
                      if result then
                        break;
                    end
                  else
                    ;
                end;
              end;
            if result then
              break;
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


    function getansistringcodepage:TStringEncoding; inline;
      begin
        if ([cs_explicit_codepage,cs_system_codepage]*CurrentSettings.ModuleSwitches)<>[] then
          result:=CurrentSettings.SourceCodePage
        else
          result:=0;
      end;

    function getansistringdef:TStringDef;
      var
        SymTable:TSymTable;
        oldstack : TSymTableStack;
      begin
        { if a codepage is explicitly defined in this mudule we need to return
          a replacement for ansistring def }
        if ([cs_explicit_codepage,cs_system_codepage]*CurrentSettings.ModuleSwitches)<>[] then
          begin
            if not Assigned(CurrentModule) then
              InternalError(2011101301);
            { codepage can be redeclared only once per unit so we don't need a list of
              redefined ansistring but only one pointer }
            if not Assigned(CurrentModule.ansistrdef) then
              begin
                { if we did not create it yet we need to do this now }
                if CurrentModule.in_interface then
                  SymTable:=CurrentModule.GlobalSymTable
                else
                  SymTable:=CurrentModule.localsymtable;
                { create a temporary stack as it's not good (TM) to mess around
                  with the order if the unit contains generics or helpers; don't
                  use a def aware symtablestack though }
                oldstack:=SymTableStack;
                SymTableStack:=TSymTableStack.create;
                SymTableStack.push(SymTable);
                CurrentModule.ansistrdef:=CStringDef.createansi(CurrentSettings.SourceCodePage,true);
                SymTableStack.pop(SymTable);
                SymTableStack.free;
                SymTableStack:=oldstack;
              end;
            result:=TStringDef(CurrentModule.ansistrdef);
          end
        else
          result:=TStringDef(cansistringtype);
      end;

    function getparaencoding(def:TDef):TStringEncoding; inline;
      begin
        { don't pass CP_NONE encoding to internal functions
          they expect 0 encoding instead
          exception: result of string concatenation, because if you pass the
          result of a string concatenation to a rawbytestring, the result of
          that concatenation shouldn't be converted to defaultsystemcodepage
          if all strings have the same type }
        result:=TStringDef(def).encoding;
        if result=Globals.CP_NONE then
          result:=0
      end;


    function get_recorddef(prefix:TInternalTypePrefix; const fields:array of TDef; PackRecords:shortint): TRecordDef;
      var
        fieldlist: TFPList;
        srsym: TSym;
        srsymtable: TSymTable;
        i: LongInt;
        name : TIDString;
      begin
        name:=copy(internaltypeprefixName[prefix],2,length(internaltypeprefixName[prefix]));
        if searchsym_type(name,srsym,srsymtable) then
          begin
            result:=TRecordDef(TTypeSym(srsym).typedef);
            exit
          end;
        { also always search in the current module (symtables are popped for
          RTTI related code already) }
        if searchsym_in_module(pointer(CurrentModule),name,srsym,srsymtable) then
          begin
            result:=TRecordDef(TTypeSym(srsym).typedef);
            exit;
          end;
        fieldlist:=TFPList.create;
        for i:=low(fields) to high(fields) do
          fieldlist.add(fields[i]);
        result:=CRecordDef.create_global_internal(internaltypeprefixName[prefix],PackRecords,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        result.add_fields_from_deflist(fieldlist);
        fieldlist.free;
        fieldlist := nil;
      end;


    procedure get_tabledef(prefix:TInternalTypePrefix;countdef,elementdef:TDef;count:LongInt;PackRecords:shortint;out recdef:TRecordDef;out arrdef:TArrayDef);
      var
        fields: TFPList;
        name: TIDString;
        srsym: TSym;
        fieldvarsym: TFieldVarSym;
        srsymtable: TSymTable;
      begin
        { already created a message string table with this number of elements
          in this unit -> reuse the def }
        name:=internaltypeprefixName[prefix]+ToStr(count);
        if searchsym_type(copy(name,2,length(name)),srsym,srsymtable) then
          begin
            recdef:=TRecordDef(TTypeSym(srsym).typedef);
            fieldvarsym:=TRecordSymTable(recdef.SymTable).findfieldbyoffset(countdef.size);
            if fieldvarsym<>nil then
              arrdef:=TArrayDef(fieldvarsym.vardef)
            else
              arrdef:=nil;
            exit
          end;
        { also always search in the current module (symtables are popped for
          RTTI related code already) }
        if searchsym_in_module(pointer(CurrentModule),copy(name,2,length(name)),srsym,srsymtable) then
          begin
            recdef:=TRecordDef(TTypeSym(srsym).typedef);
            fieldvarsym:=TRecordSymTable(recdef.SymTable).findfieldbyoffset(countdef.size);
            if fieldvarsym<>nil then
              arrdef:=TArrayDef(fieldvarsym.vardef)
            else
              arrdef:=nil;
            exit;
          end;
        recdef:=CRecordDef.create_global_internal(name,PackRecords,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        fields:=TFPList.create;
        fields.add(countdef);
        if count>0 then
          begin
            arrdef:=CArrayDef.create(0,count-1,sizeuinttype);
            arrdef.elementdef:=elementdef;
            fields.add(arrdef);
          end
        else
          arrdef:=nil;
        recdef.add_fields_from_deflist(fields);
        fields.free;
        fields := nil;
      end;

    function make_mangledname(const typeprefix:TSymStr;st:TSymTable;const suffix:TSymStr):TSymStr;
      var
        s,
        prefix : TSymStr;
        hash : qword;
      begin
        prefix:='';
        if not Assigned(st) then
         InternalError(200204212);
        repeat
          { sub procedures }
          while (st.symtabletype in [localsymtable,parasymtable]) do
           begin
             if st.defowner.typ<>procdef then
              InternalError(200204173);
             { Add the full mangledname of the routine to prevent
               conflicts with two overloads both having a local entity
               -- routine (tb0314), class, interface -- with the same name }
             s:=TProcDef(st.defowner).procsym.name;
             s:=s+TProcDef(st.defowner).mangledprocparanames(Length(s));
             if prefix<>'' then
               begin
                 if length(prefix)>(maxidlen-length(s)-1) then
                   begin
                     hash:=InitFNV64;
                     hash:=UpdateFNV64(hash,prefix[1],length(prefix));
                     prefix:='$H'+Base64Mangle(hash);
                   end;
                 prefix:=s+'_'+prefix
               end
             else
               prefix:=s;
             st:=st.defowner.owner;
           end;
          { object/classes symtable, nested type definitions in classes require the while loop }
          while st.symtabletype in [ObjectSymtable,recordsymtable] do
           begin
             if not (st.defowner.typ in [objectdef,recorddef]) then
              InternalError(200204174);
             if length(prefix)>(maxidlen-length(TAbstractRecordDef(st.defowner).objname^)-3) then
               begin
                 hash:=InitFNV64;
                 hash:=UpdateFNV64(hash,prefix[1],length(prefix));
                 prefix:='$H'+Base64Mangle(hash);
               end;
             prefix:=TAbstractRecordDef(st.defowner).objname^+'_$_'+prefix;
             st:=st.defowner.owner;
           end;
          { local classes & interfaces are possible (because of closures)
            or parasymtable for this case:
             class function Trace<TResult>(const Func: TFunc<TLogToken, TResult>): TResult;
          }
          if not (st.symtabletype in [localsymtable,parasymtable]) then
            break;
          prefix:='$'+prefix;
        until false;
        { symtable must now be static or global }
        if not(st.symtabletype in [staticsymtable,GlobalSymTable]) then
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
        result:='';
        if typeprefix<>'' then
          result:=result+typeprefix+'_$';
        { Add P$ for program, which can have the same name as
          a unit }
        if (TSymTable(main_module.localsymtable)=st) and
           (not main_module.is_unit) then
          result:=result+'P$'+st.name^
        else
          result:=result+st.name^;
        if prefix<>'' then
          result:=result+'$_$'+prefix;
        if suffix<>'' then
          result:=result+'_$$_'+suffix;
        if length(result)>(maxidlen-1) then
          begin
            hash:=InitFNV64;
            hash:=UpdateFNV64(hash,result[1],length(result));
            result:=copy(result,1,maxidlen-(high(Base64OfUInt64String)-low(Base64OfUInt64String)+1)-2)+'$H'+Base64Mangle(hash);
          end;
        { the Darwin assembler assumes that all symbols starting with 'L' are local }
        { Further, the Mac OS X 10.5 linker does not consider symbols which do not  }
        { start with '_' as regular symbols (it does not generate N_GSYM entries    }
        { those in the debug map, leading to troubles with dsymutil). So always     }
        { add an underscore on darwin.                                              }
        { LLVM's i386 COFF assembler also treats names beginning with 'L' as
          local; prefix Pascal-mangled names when using Clang for Win32. }
        if (TargetInfo.system in systems_darwin) or
           ((TargetInfo.system=system_i386_win32) and
            (TargetAsm.id=as_clang_gas)) then
          result := '_' + result;
      end;

    function make_dllmangledname(const dllname,importname:TSymStr;import_nr : word; pco : TProcCallOption):TSymStr;
       var
         crc : cardinal;
         i : LongInt;
         use_crc : boolean;
         dllprefix : TSymStr;
      begin
        if (TargetInfo.system in systems_all_windows)
            and (dllname <> '') then
          begin
            dllprefix:=lower(ExtractFileName(dllname));
            { Remove .dll suffix if present }
            if copy(dllprefix,length(dllprefix)-3,length(dllprefix))='.dll' then
              dllprefix:=copy(dllprefix,1,length(dllprefix)-4);
            use_crc:=false;
            for i:=1 to length(dllprefix) do
              if not (dllprefix[i] in ['a'..'z','A'..'Z','_','0'..'9']) then
                begin
                  use_crc:=true;
                  break;
                end;
            if use_crc then
              begin
                crc:=0;
                crc:=UpdateCRC32(crc,dllprefix[1],length(dllprefix));
                dllprefix:='_$dll$crc$'+HexStr(crc,8)+'$';
              end
            else
              dllprefix:='_$dll$'+dllprefix+'$';

            if importname<>'' then
              result:=dllprefix+importname
            else
              result:=dllprefix+'_index_'+ToStr(import_nr);
            { Replace ? and @ in import name, since GNU AS does not allow these characters in symbol names. }
            { This allows to import VC++ mangled names from DLLs. }
            { Do not perform replacement, if external symbol is not imported from DLL. }
            if (dllname<>'') then
              begin
                Replace(result,'?','__q$$');
             end;
          end
        else
          begin
            if importname<>'' then
             begin
               if not(pco in [pocall_cdecl,pocall_cppdecl]) then
                 result:=importname
               else
                 result:=TargetInfo.Cprefix+importname;
             end
            else
              result:='_index_'+ToStr(import_nr);
          end;

      end;

{****************************************************************************
           TDEFAWARESYMTABLESTACK
           (symtablestack descendant that does some special actions on
           the pushed/popped symtables)
****************************************************************************}

    procedure TDefAwareSymTableStack.add_helpers_and_generics(st:TSymTable;addgenerics:boolean);
      var
        s: TSymStr;
        list: TFPObjectList;
        def: TDef;
        sym : TSym;
        i: integer;
      begin
        { search the symtable from first to last; the helper to use will be the
          last one in the list }
        for i:=0 to st.symlist.count-1 do
          begin
            sym:=TSym(st.symlist[i]);
            if not (sym.typ in [typesym,procsym]) then
              continue;
            if sym.typ=typesym then
              def:=TTypeSym(st.SymList[i]).typedef
            else
              def:=nil;
            if is_objectpascal_helper(def) then
              begin
                s:=generate_objectpascal_helper_key(TObjectDef(def).extendeddef);
                Message1(sym_d_adding_helper_for,s);
                list:=TFPObjectList(CurrentModule.extendeddefs.Find(s));
                if not Assigned(list) then
                  begin
                    list:=TFPObjectList.Create(false);
                    CurrentModule.extendeddefs.Add(s,list);
                  end;
                list.Add(def);
              end
            else
              begin
                if addgenerics then
                  add_generic_dummysym(sym,'');
                { add nested helpers as well }
                if Assigned(def) and
                    (def.typ in [recorddef,objectdef]) and
                    (sto_has_helper in TAbstractRecordDef(def).SymTable.tableoptions) and
                    not is_owned_by(def,TDef(st.defowner)) then
                  add_helpers_and_generics(TAbstractRecordDef(def).SymTable,false);
              end;
          end;
      end;


    procedure TDefAwareSymTableStack.remove_helpers_and_generics(st:TSymTable);
      begin
        if sto_has_helper in st.tableoptions then
          remove_helpers(st);
        if sto_has_generic in st.tableoptions then
          remove_generics(st);
      end;


    procedure TDefAwareSymTableStack.remove_helpers(st:TSymTable);
      var
        i, j: integer;
        tmpst: TSymTable;
        list: TFPObjectList;
      begin
        for i:=CurrentModule.extendeddefs.count-1 downto 0 do
          begin
            list:=TFPObjectList(CurrentModule.extendeddefs[i]);
            for j:=list.count-1 downto 0 do
              begin
                if not (list[j] is TObjectDef) then
                  InternalError(2011031501);
                tmpst:=TObjectDef(list[j]).owner;
                repeat
                  if tmpst=st then
                    begin
                      list.delete(j);
                      break;
                    end
                  else
                    begin
                      if Assigned(tmpst.defowner) then
                        tmpst:=tmpst.defowner.owner
                      else
                        tmpst:=nil;
                    end;
                until not Assigned(tmpst) or (tmpst.symtabletype in [GlobalSymTable,staticsymtable]);
              end;
            if list.count=0 then
              CurrentModule.extendeddefs.delete(i);
          end;
      end;


    procedure TDefAwareSymTableStack.remove_generics(st:TSymTable);
      var
        i,j : LongInt;
        entry : TGenericDummyEntry;
        list : TFPObjectList;
      begin
        for i:=CurrentModule.genericdummysyms.count-1 downto 0 do
          begin
            list:=TFPObjectList(CurrentModule.genericdummysyms[i]);
            if not Assigned(list) then
              continue;
            for j:=list.count-1 downto 0 do
              begin
                entry:=TGenericDummyEntry(list[j]);
                if entry.dummysym.owner=st then
                  list.delete(j);
              end;
            if list.count=0 then
              CurrentModule.genericdummysyms.delete(i);
          end;
      end;


    procedure TDefAwareSymTableStack.pushcommon(st:TSymTable);
      begin
        if (sto_has_generic in st.tableoptions) or
            (
              (st.symtabletype in [GlobalSymTable,staticsymtable]) and
              (sto_has_helper in st.tableoptions)
            ) then
          { nested helpers will be added as well }
          add_helpers_and_generics(st,true);
      end;

    procedure TDefAwareSymTableStack.push(st: TSymTable);
      begin
        pushcommon(st);
        inherited push(st);
      end;

    procedure TDefAwareSymTableStack.pushafter(st,afterst:TSymTable);
      begin
        pushcommon(st);
        inherited pushafter(st,afterst);
      end;

    procedure TDefAwareSymTableStack.pop(st: TSymTable);
      begin
        inherited pop(st);
        if (sto_has_generic in st.tableoptions) or
            (
              (st.symtabletype in [GlobalSymTable,staticsymtable]) and
              (sto_has_helper in st.tableoptions)
            ) then
          { nested helpers will be removed as well }
          remove_helpers_and_generics(st);
      end;


{****************************************************************************
                     TDEF (base class for definitions)
****************************************************************************}

    constructor TGenericConstraintData.create;
      begin
        interfaces:=TFPObjectList.create(false);
        interfacesderef:=TFPList.create;
      end;


    destructor TGenericConstraintData.Destroy;
      begin
        TFPList.FreeAndNilDisposing(interfacesderef,typeinfo(TDeref));
        interfaces.free;
        interfaces := nil;
        inherited Destroy;
      end;

    procedure TGenericConstraintData.ppuload(ppufile: TCompilerPPUFile);
      var
        cnt,i : LongInt;
        intfderef : PDeref;
      begin
        ppufile.getset(TPPUSet1(flags));
        cnt:=ppufile.getlongint;
        for i:=0 to cnt-1 do
          begin
            new(intfderef);
            ppufile.getderef(intfderef^);
            interfacesderef.add(intfderef);
          end;
      end;


    procedure TGenericConstraintData.ppuwrite(ppufile: TCompilerPPUFile);
      var
        i : LongInt;
      begin
        ppufile.putset(TPPUSet1(flags));
        ppufile.putlongint(interfacesderef.count);
        for i:=0 to interfacesderef.count-1 do
          ppufile.putderef(PDeref(interfacesderef[i])^);
      end;

    procedure TGenericConstraintData.buildderef;
      var
        intfderef : PDeref;
        i : LongInt;
      begin
        interfacesderef.capacity:=interfacesderef.count+interfaces.count;
        for i:=0 to interfaces.count-1 do
          begin
            new(intfderef);
            intfderef^.build(TObjectDef(interfaces[i]));
            interfacesderef.add(intfderef);
          end;
      end;

    procedure TGenericConstraintData.deref;
      var
        i : LongInt;
      begin
        interfaces.capacity:=interfaces.count+interfacesderef.count;
        for i:=0 to interfacesderef.count-1 do
          interfaces.add(PDeref(interfacesderef[i])^.resolve);
      end;


    procedure TStoredDef.writeentry(ppufile: TCompilerPPUFile; ibnr: byte);
      begin
        PPUWritePlatform(ppufile);
        ppufile.writeentry(ibnr);
      end;


    procedure TStoredDef.PPUWritePlatform(ppufile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    procedure TStoredDef.PPULoadPlatform(ppufile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    class procedure TStoredDef.SetupReusableDef(origdef, newdef: TDef; res: PHashSetItem; OldSymTableStack: TSymTableStack);
      var
        reusablesymtab: TSymTable;
      begin
        { must not yet belong to a symtable }
        if Assigned(newdef.owner) then
          InternalError(2015111503);
        reusablesymtab:=origdef.getreusablesymtab;
        res^.Data:=newdef;
        reusablesymtab.insertdef(newdef);
        SymTableStack:=OldSymTableStack;
      end;


    constructor TStoredDef.create(dt:TDefTyp;doregister:boolean);
      begin
         inherited create(dt);
         savesize := 0;
{$ifdef EXTDEBUG}
         fileinfo := CurrentFilePos;
{$endif}
         generictokenbuf:=nil;
         genericdef:=nil;
         typesymderef.reset;
         genericdefderef.reset;

         { Don't register forwarddefs, they are disposed at the
           end of an type block }
         if (dt=forwarddef) then
           exit;
         { Register in symtable stack }
         if doregister then
           begin
             { immediately register interface defs, as they will always be
               written to the ppu, their defid influences the interface crc and
               if we wait, depending on e.g. compiler defines they may get a
               different defid (e.g. when a function is called, its procdef is
               registered, so depending on whether or not, or when, an interface
               procedure is called in the implementation, that may change its
               defid otherwise) }
             if Assigned(CurrentModule) and
                CurrentModule.in_interface then
               RegisterDef
             else
               maybe_put_in_symtable_stack;
           end;
      end;


    destructor TStoredDef.Destroy;
      begin
        { Direct calls are not allowed, use symtable.deletedef() }
        if Assigned(owner) then
          InternalError(200612311);
        if Assigned(generictokenbuf) then
          begin
            generictokenbuf.free;
            generictokenbuf:=nil;
          end;
        RTTIAttributeList.free;
        RTTIAttributeList := nil;
        genericparas.free;
        genericparas := nil;
        TFPList.FreeAndNilDisposing(genericparaderefs,typeinfo(TDeref));
        genconstraintdata.free;
        genconstraintdata := nil;
{$ifndef symansistr}
        StringDispose(_fullownerhierarchyname);
{$endif not symansistr}
        inherited Destroy;
      end;


    constructor TStoredDef.ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
      var
        sizeleft,i,cnt : LongInt;
        buf  : array[0..255] of byte;
        symderef : PDeref;
      begin
         inherited create(dt);
         DefId:=ppufile.getlongint;
         CurrentModule.deflist[DefId]:=self;
{$ifdef EXTDEBUG}
         fillchar(fileinfo,sizeof(fileinfo),0);
{$endif}
         { load }
         ppufile.getderef(typesymderef);
         ppufile.getset(TPPUSet2(defoptions));
         ppufile.getset(TPPUSet1(defstates));
         if df_unique in defoptions then
           ppufile.getderef(orgdefderef);
         if df_genconstraint in defoptions then
           begin
             genconstraintdata:=TGenericConstraintData.create;
             genconstraintdata.ppuload(ppufile);
           end;
         if [df_generic,df_specialization]*defoptions<>[] then
           begin
             cnt:=ppufile.getlongint;
             if cnt>0 then
               begin
                 genericparas:=TFPHashObjectList.create(false);
                 genericparaderefs:=TFPList.create;
                 for i:=0 to cnt-1 do
                   begin
                     genericparas.add(ppufile.getstring,nil);
                     New(symderef);
                     ppufile.getderef(symderef^);
                     genericparaderefs.add(symderef);
                   end;
               end;
           end;
         if df_generic in defoptions then
           begin
             sizeleft:=ppufile.getlongint;
             initgeneric;
             while sizeleft>0 do
               begin
                 if sizeleft>sizeof(buf) then
                   i:=sizeof(buf)
                 else
                   i:=sizeleft;
                 ppufile.getdata(buf,i);
                 generictokenbuf.write(buf,i);
                 dec(sizeleft,i);
               end;
           end;
        if df_specialization in defoptions then
          ppufile.getderef(genericdefderef);
        RTTIAttributeList:=TRTTIAttributeList.ppuload(ppufile);
      end;


    function TStoredDef.NeedsSeparateInitRTTI:boolean;
      begin
        result:=false;
      end;


    function TStoredDef.RTTIMangledName(rt : TRTTIType) : TSymStr;
      var
        prefix : string[4];
      begin
        if (rt=fullrtti) or (not NeedsSeparateInitRTTI) then
          begin
            prefix:='RTTI';
            include(defstates,ds_rtti_table_used);
          end
        else
          begin
            prefix:='INIT';
            include(defstates,ds_init_table_used);
          end;
        if Assigned(typesym) and
           (owner.symtabletype in [staticsymtable,GlobalSymTable]) then
          result:=make_mangledname(prefix,typesym.owner,typesym.name)
        else
          result:=make_mangledname(prefix,findunitsymtable(owner),'def'+UniqueIDStr)
      end;


    function TStoredDef.OwnerHierarchyName: string;
      var
        tmp: TDef;
      begin
        tmp:=self;
        result:='';
        repeat
          { can be not assigned in case of a forwarddef }
          if Assigned(tmp.owner) and
             (tmp.owner.symtabletype in [ObjectSymtable,recordsymtable]) then
            tmp:=TDef(tmp.owner.defowner)
          else
            break;
          result:=TAbstractRecordDef(tmp).objrealname^+'.'+result;
        until tmp=nil;
      end;


    function TStoredDef.OwnerHierarchyPrettyName: string;
      var
        tmp: TDef;
      begin
        tmp:=self;
        result:='';
        repeat
          { can be not assigned in case of a forwarddef }
          if Assigned(tmp.owner) and
             (tmp.owner.symtabletype in [ObjectSymtable,recordsymtable]) then
            tmp:=TDef(tmp.owner.defowner)
          else
            break;
          result:=TAbstractRecordDef(tmp).typesymbolprettyname+'.'+result;
        until tmp=nil;
      end;


    function TStoredDef.fullownerhierarchyname(skipprocparams:boolean; use_pretty : boolean): TSymStr;
      var
        lastowner: TSymTable;
        tmp: TDef;
        pno: TProcNameOptions;
      begin
{$ifdef symansistr}
        if not skipprocparams and (_fullownerhierarchyname<>'') then
          exit(_fullownerhierarchyname);
{$else symansistr}
        if not skipprocparams and Assigned(_fullownerhierarchyname) then
          exit(_fullownerhierarchyname^);
{$endif symansistr}
        { the def can only reside inside structured types or
          procedures/functions/methods }
        tmp:=self;
        result:='';
        repeat
          lastowner:=tmp.owner;
          { can be not assigned in case of a forwarddef }
          if not Assigned(lastowner) then
            break
          else
            tmp:=TDef(lastowner.defowner);
          if not Assigned(tmp) then
            break;
          if tmp.typ in [recorddef,objectdef] then
            begin
              if use_pretty then
                result:=TAbstractRecordDef(tmp).typesymbolprettyname+'.'+result
              else
                result:=TAbstractRecordDef(tmp).objrealname^+'.'+result;
            end
          else
            if tmp.typ=procdef then
              begin
                pno:=[pno_paranames,pno_proctypeoption];
                if skipprocparams then
                  include(pno,pno_noparams);
                result:=TProcDef(tmp).customprocname(pno)+'.'+result;
              end;
        until tmp=nil;
        { add the unit name }
        if Assigned(lastowner) and
           Assigned(lastowner.realname) then
          result:=lastowner.realname^+'.'+result;
        if not skipprocparams then
          { don't store the name in this case }
{$ifdef symansistr}
          _fullownerhierarchyname:=result;
{$else symansistr}
          _fullownerhierarchyname:=StringDup(result);
{$endif symansistr}
      end;


    function TStoredDef.in_currentunit: boolean;
      var
        st: TSymTable;
      begin
        st:=owner;
        while not(st.symtabletype in [GlobalSymTable,staticsymtable]) do
          st:=st.defowner.owner;
        result:=st.iscurrentunit;
      end;


    function TStoredDef.getcopy : TStoredDef;
      begin
        Message(sym_e_cant_create_unique_type);
        getcopy:=CErrorDef.create;
      end;


    procedure TStoredDef.ppuwrite(ppufile:TCompilerPPUFile);
      var
        sizeleft,i : LongInt;
        buf  : array[0..255] of byte;
        oldintfcrc : boolean;
      begin
        if defid<0 then
          InternalError(2015101401);
        ppufile.putlongint(DefId);
        ppufile.putderef(typesymderef);
        ppufile.putset(TPPUSet2(defoptions));
        oldintfcrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
        ppufile.putset(TPPUSet1(defstates));
        if df_unique in defoptions then
          ppufile.putderef(orgdefderef);
        if df_genconstraint in defoptions then
          genconstraintdata.ppuwrite(ppufile);
        if [df_generic,df_specialization]*defoptions<>[] then
          begin
            if not Assigned(genericparas) then
              ppufile.putlongint(0)
            else
              begin
                if not Assigned(genericparaderefs) then
                  InternalError(2014052305);
                ppufile.putlongint(genericparas.count);
                for i:=0 to genericparas.count-1 do
                  begin
                    ppufile.putstring(genericparas.nameofindex(i));
                    ppufile.putderef(PDeref(genericparaderefs[i])^);
                  end;
              end;
          end;
        if df_generic in defoptions then
          begin
            { crc generic implementation }
            ppufile.DoCRC:=true;
            if Assigned(generictokenbuf) then
              begin
                sizeleft:=generictokenbuf.size;
                generictokenbuf.seek(0);
              end
            else
              sizeleft:=0;
            ppufile.putlongint(sizeleft);
            while sizeleft>0 do
              begin
                if sizeleft>sizeof(buf) then
                  i:=sizeof(buf)
                else
                  i:=sizeleft;
                generictokenbuf.read(buf,i);
                ppufile.putdata(buf,i);
                dec(sizeleft,i);
              end;
          end;
        ppufile.DoCRC:=oldintfcrc;
        if df_specialization in defoptions then
          ppufile.putderef(genericdefderef);
        TRTTIAttributeList.ppuwrite(RTTIAttributeList,ppufile);
      end;


    procedure TStoredDef.PPULoadSubEntries(ppufile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPULoadSubEntries(RTTIAttributeList,ppufile);
      end;


    procedure TStoredDef.PPUWriteSubEntries(ppufile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPUWriteSubEntries(RTTIAttributeList,ppufile);
      end;


    procedure TStoredDef.buildderef;
      var
        i : LongInt;
        sym : TSym;
        symderef : PDeref;
      begin
        if not registered then
          RegisterDef;
        typesymderef.build(typesym);
        orgdefderef.build(orgdef);
        genericdefderef.build(genericdef);
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.buildderef;
        if Assigned(genconstraintdata) then
          genconstraintdata.buildderef;
        if Assigned(genericparas) then
          begin
           { buildderef may be called more than once (getppucrc is called at
             end-of-interface and again at end-of-implementation; system units
             also call buildderef a second time from writeppu). Clear any
             previously accumulated entries so that genericparaderefs.count
             stays equal to genericparas.count and does not trigger
             internalerror 2014052303 in deref. }
           if Assigned(genericparaderefs) then
             begin
               for i:=0 to genericparaderefs.count-1 do
                 dispose(PDeref(genericparaderefs[i]));
               genericparaderefs.clear;
             end
           else
             genericparaderefs:=TFPList.create;
           genericparaderefs.capacity:=genericparas.count;
            for i:=0 to genericparas.count-1 do
              begin
                sym:=TSym(genericparas.items[i]);
                new(symderef);
                symderef^.build(sym);
                genericparaderefs.add(symderef);
              end;
          end;
      end;


    procedure TStoredDef.buildderefimpl;
      begin
      end;


    procedure TStoredDef.deref;
      var
        symderef : PDeref;
        i : LongInt;
      begin
        typesym:=TTypeSym(typesymderef.resolve);
        if df_unique in defoptions then
          orgdef:=TStoredDef(orgdefderef.resolve);
        if df_specialization in defoptions then
          genericdef:=TStoredDef(genericdefderef.resolve);
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.deref;
        if Assigned(genconstraintdata) then
          genconstraintdata.deref;
        if Assigned(genericparas) then
          begin
            if not Assigned(genericparaderefs) then
              InternalError(2014052302);
            if genericparas.count<>genericparaderefs.count then
              InternalError(2014052303);
            for i:=0 to genericparaderefs.count-1 do
              begin
                symderef:=PDeref(genericparaderefs[i]);
                genericparas.items[i]:=symderef^.resolve;
              end;
          end;
      end;


    procedure TStoredDef.derefimpl;
      begin
      end;


    function TStoredDef.size : asizeint;
      begin
         size:=savesize;
      end;


    function TStoredDef.getvardef:LongInt;
      begin
        result:=varUndefined;
      end;


    function TStoredDef.alignment : shortint;
      begin
         { natural alignment by default }
         alignment:=Size_2_Align(savesize);
         { can happen if savesize = 0, e.g. for voiddef or
           an empty record
         }
         if (alignment=0) then
           alignment:=1;
      end;


    { returns true, if the definition can be published }
    function TStoredDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_error;
      end;


    { needs an init table }
    function TStoredDef.NeedsInitTable : boolean;
      begin
         NeedsInitTable:=false;
      end;


    function TStoredDef.HasNonTrivialInitChild(check_parent:boolean):boolean;
      begin
        result:=false;
      end;


   function TStoredDef.is_intregable : boolean;
{$ifndef cpuhighleveltarget}
     var
       recsize,temp: LongInt;
{$endif cpuhighleveltarget}
     begin
        case typ of
          orddef,
          pointerdef,
          enumdef,
          classrefdef:
            is_intregable:=true;
          procvardef :
            is_intregable:=TProcVarDef(self).is_addressonly or (po_methodpointer in TProcVarDef(self).procoptions);
          objectdef:
            is_intregable:=(is_implicit_pointer_object_type(self)) and not NeedsInitTable;
          setdef:
            is_intregable:=is_smallset(self);
          arraydef:
{$ifdef cpuhighleveltarget}
            is_intregable:=false
{$else cpuhighleveltarget}
            is_intregable:=not(is_special_array(self)) and
              (TArrayDef(self).size<=8) and (TArrayDef(self).size in [1,2,4,8]) and
              TStoredDef(TArrayDef(self).elementdef).is_intregable
{$ifdef SUPPORT_MMX}
              and not((cs_mmx in CurrentSettings.LocalSwitches) and
                 is_mmx_able_array(self))
{$endif SUPPORT_MMX}
{$endif cpuhighleveltarget}
              ;
          recorddef:
            begin
{$ifdef cpuhighleveltarget}
              is_intregable:=false;
{$else cpuhighleveltarget}
              recsize:=size;
              is_intregable:=
                IsPowerOf2(recsize,temp) and
                ((recsize<=sizeof(aint)*2) and
                 not TRecordDef(self).contains_cross_aword_field and
                 { records cannot go into registers on 16 bit targets for now }
                 (sizeof(aint)>2) and
                 not TRecordDef(self).contains_float_field
                ) and
                not NeedsInitTable;
{$endif cpuhighleveltarget}
            end;
          else
           is_intregable:=false;
        end;
     end;


   function TStoredDef.is_fpuregable : boolean;
     begin
{$ifdef x86}
       result:=use_vectorfpu(self);
{$else x86}
       result:=(typ=floatdef)
         ;
{$endif x86}
     end;


   function TStoredDef.is_const_intregable : boolean;
     begin
       case typ of
         stringdef:
           result:=TStringDef(self).stringtype in [st_ansistring,st_unicodestring,st_widestring];
         arraydef:
           result:=is_dynamic_array(self);
         objectdef:
           result:=is_interface(self);
         else
           result:=false;
       end;
     end;


   procedure TStoredDef.initgeneric;
     begin
       if Assigned(generictokenbuf) then
         InternalError(200512131);
       generictokenbuf:=TDynamicArray.create(256);
     end;


   function TStoredDef.is_generic: boolean;
     var
       sym: TSym;
       i: LongInt;
     begin
       result:=Assigned(genericparas) and
                 (genericparas.count>0) and
                 (df_generic in defoptions);
       if result then
         { if any of the type parameters does *not* belong to us (meaning it was passed
           in from outside) then we aren't a generic, but a specialization }
         for i:=0 to genericparas.count-1 do
           begin
             sym:=TSym(genericparas[i]);
             { sym must be either a type or const }
             if not (sym.typ in [symconst.typesym,symconst.constsym]) then
               InternalError(2014050903);
             if (sym.owner.defowner<>self) or (sp_generic_unnamed_type in sym.symoptions) then
               exit(false);
             if (sym.typ=symconst.constsym) and (sp_generic_const in sym.symoptions) then
               exit(false);
           end;
     end;


   function TStoredDef.is_generic_param_const(index:integer):boolean;
     begin
       result:=TSym(genericparas[index]).typ=constsym;
     end;


   function TStoredDef.get_generic_param_def(index:integer):TDef;
     begin
       if TSym(genericparas[index]).typ=constsym then
         result:=TConstSym(genericparas[index]).constdef
       else
         result:=TTypeSym(genericparas[index]).typedef;
     end;


   function TStoredDef.is_specialization: boolean;
     var
       i : LongInt;
       sym : TSym;
     begin
       result:=Assigned(genericparas) and
                 (genericparas.count>0) and
                 (df_specialization in defoptions);
       if result then
         begin
           { if at least one of the generic parameters is not owned by us (meaning it was
             passed in from outside) then we have a specialization, otherwise we have a generic }
           for i:=0 to genericparas.count-1 do
             begin
               sym:=TSym(genericparas[i]);
               { sym must be either a type or const }
               if not (sym.typ in [symconst.typesym,symconst.constsym]) then
                 InternalError(2014050904);
               if (sym.owner.defowner<>self) or (sp_generic_unnamed_type in sym.symoptions) then
                 exit(true);
               if (sym.typ=symconst.constsym) and (sp_generic_const in sym.symoptions) then
                 exit(true);
             end;
           result:=false;
         end;
     end;


   procedure TStoredDef.RegisterDef;
     var
       gst : TGetSymTable;
       st : TSymTable;
       tmod : TModule;
     begin
       if registered then
         exit;
       if Assigned(owner) then
         begin
           tmod:=find_module_from_symtable(owner);
            if Assigned(tmod) and Assigned(CurrentModule) and (tmod<>CurrentModule) then
              begin
                comment(VError,'Definition '+fullownerhierarchyname(false,true)+' from module '+tmod.MainSource+' registered with current module '+CurrentModule.MainSource);
              end;
           if not Assigned(tmod) then
             tmod:=CurrentModule;
         end
       else
         tmod:=CurrentModule;
       { Register in current_module }
       if Assigned(tmod) then
         begin
           exclude(defoptions,df_not_registered_no_free);
           for gst:=low(TGetSymTable) to high(TGetSymTable) do
             begin
               st:=getsymtable(gst);
               if Assigned(st) then
                 TStoredSymTable(st).register_children;
             end;
           if defid<defid_not_registered then
             defid:=DefListIndex
           else
             begin
               tmod.deflist.Add(self);
               defid:=tmod.deflist.Count-1;
               registered_in_module:=tmod;
             end;
           maybe_put_in_symtable_stack;
         end
       else
         DefId:=defid_registered_nost;
     end;


   procedure TStoredDef.maybe_put_in_symtable_stack;
     var
       insertstack: PSymTableStackItem;
     begin
       if Assigned(SymTableStack) and
          not Assigned(self.owner) then
         begin
           insertstack:=SymTableStack.stack;
           { don't insert defs in exception symtables, as they are freed before
             the module is compiled, so we can get crashes on high level targets
             if they still need it while e.g. writing assembler code }
           while Assigned(insertstack) and
                 (insertstack^.SymTable.symtabletype in [exceptsymtable,withsymtable]) do
             insertstack:=insertstack^.next;
           if not Assigned(insertstack) then
             InternalError(200602044);
           if insertstack^.SymTable.sealed then
             InternalError(2015022301);
           insertstack^.SymTable.insertdef(self);
         end;
     end;


{****************************************************************************
                               Tstringdef
****************************************************************************}

    constructor TStringDef.createshort(l: byte; doregister: boolean);
      begin
         inherited create(stringdef,doregister);
         stringtype:=st_shortstring;
         encoding:=0;
         len:=l;
      end;


    constructor TStringDef.loadshort(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(stringdef,ppufile);
         stringtype:=st_shortstring;
         encoding:=0;
         len:=ppufile.getbyte;
         PPULoadPlatform(ppufile);
      end;


    constructor TStringDef.createlong(l: asizeint; doregister: boolean);
      begin
         inherited create(stringdef,doregister);
         stringtype:=st_longstring;
         encoding:=0;
         len:=l;
      end;


    constructor TStringDef.loadlong(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(stringdef,ppufile);
         stringtype:=st_longstring;
         encoding:=0;
         len:=ppufile.getasizeint;
         PPULoadPlatform(ppufile);
      end;


    constructor TStringDef.createansi(aencoding: TStringEncoding; doregister: boolean);
      begin
         inherited create(stringdef,doregister);
         stringtype:=st_ansistring;
         encoding:=aencoding;
         len:=-1;
      end;


    constructor TStringDef.loadansi(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(stringdef,ppufile);
         stringtype:=st_ansistring;
         len:=ppufile.getasizeint;
         encoding:=ppufile.getword;
         PPULoadPlatform(ppufile);
      end;


    constructor TStringDef.createwide(doregister: boolean);
      begin
         inherited create(stringdef,doregister);
         stringtype:=st_widestring;
         if TargetInfo.endian=endian_little then
           encoding:=CP_UTF16LE
         else
           encoding:=CP_UTF16BE;
         len:=-1;
      end;


    constructor TStringDef.loadwide(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(stringdef,ppufile);
         stringtype:=st_widestring;
         if TargetInfo.endian=endian_little then
           encoding:=CP_UTF16LE
         else
           encoding:=CP_UTF16BE;
         len:=ppufile.getasizeint;
         PPULoadPlatform(ppufile);
      end;


    constructor TStringDef.createunicode(doregister: boolean);
      begin
         inherited create(stringdef,doregister);
         stringtype:=st_unicodestring;
         if TargetInfo.endian=endian_little then
           encoding:=CP_UTF16LE
         else
           encoding:=CP_UTF16BE;
         len:=-1;
      end;


    constructor TStringDef.loadunicode(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(stringdef,ppufile);
         stringtype:=st_unicodestring;
         len:=ppufile.getasizeint;
         encoding:=ppufile.getword;
         PPULoadPlatform(ppufile);
      end;


    function TStringDef.getcopy : TStoredDef;
      begin
        result:=CStringDef.create(typ,true);
        result.typ:=stringdef;
        TStringDef(result).stringtype:=stringtype;
        TStringDef(result).encoding:=encoding;
        TStringDef(result).len:=len;
      end;


    function TStringDef.stringtypname:string;
      const
        typname:array[TStringType] of string[10]=(
          'shortstr','longstr','ansistr','widestr','unicodestr'
        );
      begin
        stringtypname:=typname[stringtype];
      end;


    procedure TStringDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         if stringtype=st_shortstring then
           begin
{$ifdef extdebug}
            if len > 255 then InternalError(12122002);
{$endif}
            ppufile.putbyte(byte(len))
           end
         else
           ppufile.putasizeint(len);
         if stringtype in [st_ansistring,st_unicodestring] then
           ppufile.putword(encoding);
         case stringtype of
            st_shortstring : writeentry(ppufile,ibshortstringdef);
            st_longstring : writeentry(ppufile,iblongstringdef);
            st_ansistring : writeentry(ppufile,ibansistringdef);
            st_widestring : writeentry(ppufile,ibwidestringdef);
            st_unicodestring : writeentry(ppufile,ibunicodestringdef);
         end;
      end;


    function TStringDef.NeedsInitTable : boolean;
      begin
         NeedsInitTable:=stringtype in [st_ansistring,st_widestring,st_unicodestring];
      end;


    function TStringDef.GetTypeName : string;
      const
         names : array[TStringType] of string[15] = (
           'ShortString','LongString','AnsiString','WideString','UnicodeString');
      begin
         GetTypeName:=names[stringtype];
         case stringtype of
           st_ansistring,st_unicodestring:
             GetTypeName:=GetTypeName+'('+ToStr(encoding)+')';
           st_shortstring:
             GetTypeName:=GetTypeName+'['+ToStr(len)+']';
           else
             ;
         end;
      end;


    function TStringDef.getvardef : LongInt;
      const
        vardef : array[TStringType] of LongInt = (
          varUndefined,varUndefined,varString,varOleStr,varUString);
      begin
        result:=vardef[stringtype];
      end;


    function TStringDef.get_default_char_type: TDef;
      begin
        case stringtype of
          st_shortstring,
          st_longstring,
          st_ansistring:
            result:=cansichartype;
          st_unicodestring,
          st_widestring:
            result:=cwidechartype;
        end;
      end;


    function TStringDef.get_default_string_type: TDef;
      begin
        case stringtype of
          st_shortstring:
            result:=cshortstringtype;
          { st_longstring is currently not supported but
            when it is this case will need to be supplied }
          st_longstring:
            InternalError(2021040801);
          st_ansistring:
            result:=cansistringtype;
          st_widestring:
            result:=cwidestringtype;
          st_unicodestring:
            result:=cunicodestringtype;
        end
      end;


    function TStringDef.alignment : shortint;
      begin
        case stringtype of
          st_unicodestring,
          st_widestring,
          st_ansistring:
            alignment:=voidpointertype.alignment;
          st_longstring,
          st_shortstring:
              { char to string accesses byte 0 and 1 with one word access }
            if (tf_requires_proper_alignment in TargetInfo.flags) or
              { macpas needs an alignment of 2 (MetroWerks compatible) }
               (m_mac in CurrentSettings.ModeSwitches) then
              alignment:=Size_2_Align(2)
            else
              alignment:=Size_2_Align(1);
        end;
      end;


    function TStringDef.getmangledparaname : TSymStr;
      begin
        getmangledparaname:='STRING';
      end;


    function TStringDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TStringDef.size: asizeint;
      begin
        case stringtype of
          st_shortstring:
            Result:=len+1;
          st_longstring,
          st_ansistring,
          st_widestring,
          st_unicodestring:
            Result:=voidpointertype.size;
        end;
      end;


{****************************************************************************
                                 TENUMDEF
****************************************************************************}

    constructor TEnumDef.create;
      begin
         inherited create(enumdef,true);
         minval:=0;
         maxval:=0;
         calcsavesize(CurrentSettings.PackEnum);
         has_jumps:=false;
         basedef:=nil;
         basedefderef.reset;
         SymTable:=TEnumSymTable.create(self);
      end;


    constructor TEnumDef.create_subrange(_basedef:TEnumDef;_min,_max:asizeint);
      begin
         inherited create(enumdef,true);
         minval:=_min;
         maxval:=_max;
         basedef:=_basedef;
         calcsavesize(CurrentSettings.PackEnum);
         has_jumps:=false;
         SymTable:=basedef.SymTable.getcopy;
         include(defoptions, df_copied_def);
       end;


    constructor TEnumDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(enumdef,ppufile);
         minval:=ppufile.getaint;
         maxval:=ppufile.getaint;
         savesize:=ppufile.getaint;
         has_jumps:=false;
         if df_copied_def in defoptions then
           begin
             SymTable:=nil;
             ppufile.getderef(basedefderef);
             PPULoadPlatform(ppufile);
           end
         else
           begin
             PPULoadPlatform(ppufile);
             // create with nil defowner first to prevent values changes on insert
             SymTable:=TEnumSymTable.create(nil);
             TEnumSymTable(SymTable).ppuload(ppufile);
             SymTable.defowner:=self;
           end;
      end;

    destructor TEnumDef.Destroy;
      begin
        SymTable.free;
        SymTable:=nil;
        inherited Destroy;
      end;


    function TEnumDef.getcopy : TStoredDef;
      begin
        if Assigned(basedef) then
          result:=CEnumDef.create_subrange(basedef,minval,maxval)
        else
          begin
            result:=CEnumDef.create;
            TEnumDef(result).minval:=minval;
            TEnumDef(result).maxval:=maxval;
            TEnumDef(result).SymTable.free;
            TEnumDef(result).SymTable:=SymTable.getcopy;
            TEnumDef(result).basedef:=self;
          end;
        TEnumDef(result).has_jumps:=has_jumps;
        TEnumDef(result).basedefderef:=basedefderef;
        include(TEnumDef(result).defoptions,df_copied_def);
      end;


    procedure TEnumDef.calcsavesize(PackEnum: shortint);
      begin
{$IFNDEF cpu64bitaddr} {$push}{$warnings off} {$ENDIF} //comparison always false warning
        if (PackEnum=8) or (int64(min)<low(LongInt)) or (int64(max)>high(cardinal)) or ((min<0) and (max>high(LongInt))) then
         savesize:=8
{$IFNDEF cpu64bitaddr} {$pop} {$ENDIF}
        else
 //comparison always false warning
         if (PackEnum=4) or (min<low(smallint)) or (max>high(word)) or ((min<0) and (max>high(smallint))) then
          savesize:=4

        else
         if (PackEnum=2) or (min<low(shortint)) or (max>high(byte)) or ((min<0) and (max>high(shortint))) then
          savesize:=2
        else
         savesize:=1;
      end;


    function TEnumDef.packedbitsize: asizeint;
      var
        sizeval: TConstExprInt;
        power: LongInt;
      begin
        result := 0;
        if (minval >= 0) and
           (maxval <= 1) then
          result := 1
        else
          begin
            if (minval>=0) then
              sizeval:=maxval
            else
             { don't count 0 twice, but take into account that range goes from -n-1..n }
              sizeval:=(CUtils.max(-minval,maxval+1)*2)-1;
            { 256 must become 512 etc. }
            NextPowerOf2(sizeval+1,power);
            result := power;
          end;
      end;


    procedure TEnumDef.setmax(_max:asizeint);
      begin
        maxval:=_max;
        calcsavesize(CurrentSettings.PackEnum);
      end;


    procedure TEnumDef.setmin(_min:asizeint);
      begin
        minval:=_min;
        calcsavesize(CurrentSettings.PackEnum);
      end;


    function TEnumDef.min:asizeint;
      begin
        min:=minval;
      end;


    function TEnumDef.max:asizeint;
      begin
        max:=maxval;
      end;

    function TEnumDef.getfirstsym: TSym;
      var
        i:integer;
      begin
        for i := 0 to SymTable.SymList.Count - 1 do
          begin
            result:=TSym(SymTable.SymList[i]);
            if TEnumSym(result).value=minval then
              exit;
          end;
        result:=nil;
      end;


    function TEnumDef.int2enumsym(l: asizeint): TSym;
      var
        i: LongInt;
        sym: TSym;
        bdef: TEnumDef;
      begin
        result:=nil;
        if (l<minval) or
           (l>maxval) then
          exit;
        bdef:=getbasedef;
        for i:=0 to bdef.SymTable.symlist.count-1 do
          begin
            sym:=TSym(bdef.SymTable.symlist[i]);
            if (sym.typ=enumsym) and
               (TEnumSym(sym).value=l) then
              begin
                result:=sym;
                exit;
              end;
          end;
      end;


    function TEnumDef.getbasedef: TEnumDef;
      begin
        if not Assigned(basedef) then
          result:=self
        else
          result:=basedef;
      end;


    procedure TEnumDef.buildderef;
      begin
        inherited buildderef;
        if df_copied_def in defoptions then
          basedefderef.build(basedef)
        else
          TEnumSymTable(SymTable).buildderef;
      end;


    procedure TEnumDef.deref;
      begin
        inherited deref;
        if df_copied_def in defoptions then
          begin
            basedef:=TEnumDef(basedefderef.resolve);
            SymTable:=basedef.SymTable.getcopy;
          end
        else
          TEnumSymTable(SymTable).deref(false);
      end;


    procedure TEnumDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putaint(min);
         ppufile.putaint(max);
         ppufile.putaint(savesize);
         if df_copied_def in defoptions then
           ppufile.putderef(basedefderef);
         writeentry(ppufile,ibenumdef);
         if not (df_copied_def in defoptions) then
           TEnumSymTable(SymTable).ppuwrite(ppufile);
      end;


    function TEnumDef.IsPublishable : TPublishProperty;
      begin
         if not has_jumps then
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


    constructor TRTTIAttribute.ppuload(ppufile: TCompilerPPUFile);
      begin
        ppufile.getderef(typesymderef);
        ppufile.getderef(typeconstrderef);
        SetLength(paras,ppufile.getlongint);
      end;


    procedure TRTTIAttribute.ppuwrite(ppufile: TCompilerPPUFile);
      begin
        ppufile.putderef(typesymderef);
        ppufile.putderef(typeconstrderef);
        ppufile.putlongint(length(paras));
      end;


    procedure TRTTIAttribute.PPULoadSubEntries(ppufile: TCompilerPPUFile);
      var
        i : sizeint;
      begin
        for i:=0 to high(paras) do
          paras[i]:=ppuloadnodetree(ppufile);
      end;


    procedure TRTTIAttribute.PPUWriteSubEntries(ppufile: TCompilerPPUFile);
      var
        i : sizeint;
      begin
        for i:=0 to high(paras) do
          ppuwritenodetree(ppufile,paras[i]);
      end;


    destructor TRTTIAttribute.Destroy;
      var
        n : TNode;
      begin
        constructorcall.free;
        constructorcall := nil;
        for n in paras do
          n.free;
          n := nil;
        inherited Destroy;
      end;


    procedure TRTTIAttribute.buildderef;
      var
        i : sizeint;
      begin
        typesymderef.build(typesym);
        typeconstrderef.build(typeconstr);
        for i:=0 to high(paras) do
          paras[i].buildderefimpl;
      end;


    procedure TRTTIAttribute.deref;
      var
        i : sizeint;
      begin
        typesym:=TSym(typesymderef.resolve);
        typeconstr:=TDef(typeconstrderef.resolve);
        for i:=0 to high(paras) do
          paras[i].derefimpl;
      end;


    class procedure TRTTIAttributeList.bind(var dangling,owned:TRTTIAttributeList);
      begin
        if Assigned(owned) then
          InternalError(2019071001);
        if not Assigned(dangling) then
          exit;
        if dangling.IsBound then
          InternalError(2019071002);
        CurrentModule.used_rtti_attrs.ConcatListCopy(dangling.RTTIAttributes);
        dangling.IsBound:=true;
        owned:=dangling;
        dangling:=nil;
      end;

    class procedure TRTTIAttributeList.copyandbind(alist : TRTTIAttributeList; var owned: TRTTIAttributeList);
    var
      i,j : Integer;
      attr,newattribute : TRTTIAttribute;
    begin
      if owned=Nil then
        owned:=TRTTIAttributeList.Create;
      owned.IsBound:=True;
      for i:=0 to aList.RTTIAttributes.Count-1 do
        begin
        attr:=TRTTIAttribute(alist.RTTIAttributes[i]);
        newattribute:=TRTTIAttribute.Create;
        newattribute.typesym:=attr.typesym;
        newattribute.typeconstr:=attr.typeconstr;
        newattribute.constructorcall:=attr.constructorcall.getcopy;
        SetLength(newattribute.paras,length(attr.paras));
        for j:=0 to length(attr.paras)-1 do
          newattribute.paras[j]:=attr.paras[j].getcopy;
        owned.AddAttribute(newattribute);
        end;
      CurrentModule.used_rtti_attrs.ConcatListCopy(owned.RTTIAttributes);
    end;


    procedure TRTTIAttributeList.addattribute(atypesym:TSym;typeconstr:TDef;constructorcall:TNode;constref paras:array of TNode);
      var
        newattribute : TRTTIAttribute;
        i : sizeint;
      begin
        if not Assigned(RTTIAttributes) then
          RTTIAttributes:=TFPObjectList.Create(true);
        newattribute:=TRTTIAttribute.Create;
        newattribute.typesym:=atypesym;
        newattribute.typeconstr:=typeconstr;
        newattribute.constructorcall:=constructorcall;
        SetLength(newattribute.paras,length(paras));
        for i:=0 to high(paras) do
          newattribute.paras[i]:=paras[i];
        RTTIAttributes.Add(newattribute);
      end;


    procedure TRTTIAttributeList.addattribute(attr:TRTTIAttribute);
      begin
        if not Assigned(RTTIAttributes) then
          RTTIAttributes:=TFPObjectList.Create(true);
        RTTIAttributes.add(attr);
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
          result:=RTTIAttributes.Count
        else
          result:=0;
      end;


    procedure TRTTIAttributeList.buildderef;
      var
        i : sizeint;
      begin
        if not Assigned(RTTIAttributes) then
          exit;
        for i:=0 to RTTIAttributes.count-1 do
          TRTTIAttribute(RTTIAttributes[i]).buildderef;
      end;


    procedure TRTTIAttributeList.deref;
      var
        i : sizeint;
      begin
        if not Assigned(RTTIAttributes) then
          exit;
        for i:=0 to RTTIAttributes.count-1 do
          TRTTIAttribute(RTTIAttributes[i]).deref;
      end;


    class procedure TRTTIAttributeList.PPULoadSubEntries(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
      var
        i : sizeint;
      begin
        if Assigned(attrlist) then
          begin
            if not Assigned(attrlist.RTTIAttributes) then
              InternalError(2019071101);
            for i:=0 to attrlist.RTTIAttributes.count-1 do
              TRTTIAttribute(attrlist.RTTIAttributes[i]).PPULoadSubEntries(ppufile);
          end;
      end;


    class procedure TRTTIAttributeList.PPUWriteSubEntries(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
      var
        i : sizeint;
      begin
        if Assigned(attrlist) and Assigned(attrlist.RTTIAttributes) then
          begin
            for i:=0 to attrlist.RTTIAttributes.count-1 do
              TRTTIAttribute(attrlist.RTTIAttributes[i]).PPUWriteSubEntries(ppufile);
          end;
      end;


    class function TRTTIAttributeList.ppuload(ppufile:TCompilerPPUFile):TRTTIAttributeList;
      var
        cnt,i : LongInt;
      begin
        cnt:=ppufile.getlongint;
        if cnt>0 then
          begin
            result:=TRTTIAttributeList.create;
            for i:=0 to cnt-1 do
              result.addattribute(TRTTIAttribute.ppuload(ppufile));
          end
        else
          result:=nil;
      end;


    class procedure TRTTIAttributeList.ppuwrite(attrlist:TRTTIAttributeList;ppufile:TCompilerPPUFile);
      var
        i : LongInt;
      begin
        if Assigned(attrlist) and Assigned(attrlist.RTTIAttributes) then
          begin
            ppufile.putlongint(attrlist.RTTIAttributes.count);
            for i:=0 to attrlist.RTTIAttributes.count-1 do
              TRTTIAttribute(attrlist.RTTIAttributes[i]).ppuwrite(ppufile);
          end
        else
          ppufile.putlongint(0);
      end;


{****************************************************************************
                                 TORDDEF
****************************************************************************}

    constructor TOrdDef.create(t : TOrdType;v,b : TConstExprInt; doregister: boolean);
      begin
         inherited create(orddef,doregister);
         low:=v;
         high:=b;
         ordtype:=t;
         setsize;
      end;


    constructor TOrdDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(orddef,ppufile);
         ordtype:=TOrdType(ppufile.getbyte);
         low:=ppufile.getexprint;
         high:=ppufile.getexprint;
         setsize;
         PPULoadPlatform(ppufile);
      end;


    function TOrdDef.getcopy : TStoredDef;
      begin
         result:=COrdDef.create(ordtype,low,high,true);
         result.typ:=orddef;
         TOrdDef(result).low:=low;
         TOrdDef(result).high:=high;
         TOrdDef(result).ordtype:=ordtype;
         TOrdDef(result).savesize:=savesize;
      end;


    function TOrdDef.alignment:shortint;
      begin
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
           (ordtype in [s64bit,u64bit]) then
          result := 4
        else
          result := inherited alignment;
      end;


    procedure TOrdDef.setsize;
      const
        sizetbl : array[TOrdType] of LongInt = (
          0,
          1,2,4,8,16,
          1,2,4,8,16,
          1,1,2,4,8,
          1,2,4,8,
          1,2,8,system.high(LongInt)
        );
      begin
        savesize:=sizetbl[ordtype];
        if savesize=system.high(LongInt) then
          savesize:=packedbitsize div 8;
      end;


    function TOrdDef.packedbitsize: asizeint;
      var
        sizeval: TConstExprInt;
        power: LongInt;
      begin
        result := 0;
        if ordtype = uvoid then
          exit;

{$ifndef cpu64bitalu}
        if (ordtype in [s64bit,u64bit]) then
{$else not cpu64bitalu}
        if ((ordtype = u64bit) and
            (high > system.high(int64))) or
           ((ordtype = s64bit) and
            ((low <= (system.low(int64) div 2)) or
             ((low < 0) and
              (high > (system.high(int64) div 2))))) then
{$endif cpu64bitalu}
          result := 64
        else if (
            (low >= 0) and
            (high <= 1)
           ) or (
             ordtype in [pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,bool8bit,bool16bit,bool32bit,bool64bit]
           ) then
          result := 1
        else
          begin
            if (low>=0) then
              sizeval:=high
            else
              { don't count 0 twice, but take into account that range goes from -n-1..n }
              sizeval:=(CUtils.max(-low,high+1)*2)-1;
            { 256 must become 512 etc. }
            NextPowerOf2(sizeval+1,power);
            result := power;
         end;
      end;


    function TOrdDef.getvardef : LongInt;
      const
        basetype2vardef : array[TOrdType] of LongInt = (
          varUndefined,
          varbyte,varword,varlongword,varqword,varUndefined,
          varshortint,varsmallint,varinteger,varint64,varUndefined,
          varboolean,varboolean,varboolean,varboolean,varboolean,
          varboolean,varboolean,varUndefined,varUndefined,
          varUndefined,varUndefined,varCurrency,varEmpty);
      begin
        result:=basetype2vardef[ordtype];
        if result=varEmpty then
          result:=basetype2vardef[range_to_basetype(low,high)];
      end;


    procedure TOrdDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(ordtype));
         ppufile.putexprint(low);
         ppufile.putexprint(high);
         writeentry(ppufile,iborddef);
      end;


    function TOrdDef.IsPublishable : TPublishProperty;
      begin
         if ordtype<>uvoid then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TOrdDef.GetTypeName : string;
      const
        names : array[TOrdType] of string[20] = (
          'untyped',
          'Byte','Word','DWord','QWord','UInt128',
          'ShortInt','SmallInt','LongInt','Int64','Int128',
          'Boolean','Boolean8','Boolean16','Boolean32','Boolean64',
          'ByteBool','WordBool','LongBool','QWordBool',
          'AnsiChar','WideChar','Currency','CustomRange');

      begin
         GetTypeName:=names[ordtype];
      end;


{****************************************************************************
                                TFLOATDEF
****************************************************************************}

    constructor TFloatDef.create(t: TFloatType; doregister: boolean);
      begin
         inherited create(floatdef,doregister);
         floattype:=t;
         setsize;
      end;


    constructor TFloatDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(floatdef,ppufile);
         floattype:=TFloatType(ppufile.getbyte);
         setsize;
         PPULoadPlatform(ppufile);
      end;


    function TFloatDef.getcopy : TStoredDef;
      begin
         result:=CFloatDef.create(floattype,true);
         result.typ:=floatdef;
         TFloatDef(result).savesize:=savesize;
      end;


    function TFloatDef.alignment:shortint;
      begin
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
          case floattype of
            sc80real,
            s80real: result:=16;
            S64Real,
            s64currency,
            s64comp : result:=4;
            else
              result := inherited alignment;
          end
        else
          result := inherited alignment;
      end;


    function TFloatDef.structalignment: shortint;
      begin
        result:=alignment;
      end;


    procedure TFloatDef.setsize;
      begin
         case floattype of
           S32Real : savesize:=4;
           s80real : savesize:=10;
           sc80real:
             if TargetInfo.system in [system_i386_darwin,
                  system_i386_iphonesim,system_x86_64_darwin,
                  system_x86_64_iphonesim,
                  system_x86_64_linux] then
               savesize:=16
             else
               savesize:=12;
           S64Real,
           s64currency,
           s64comp : savesize:=8;
         end;
      end;


    function TFloatDef.getvardef : LongInt;
      const
        floattype2vardef : array[TFloatType] of LongInt = (
          varSingle,varDouble,varUndefined,varUndefined,
          varUndefined,varCurrency);
      begin
        if (upper(typename)='TDATETIME') and
          Assigned(owner) and
          Assigned(owner.name) and
          (owner.name^='SYSTEM') then
          result:=varDate
        else
          result:=floattype2vardef[floattype];
      end;


    procedure TFloatDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(floattype));
         writeentry(ppufile,ibfloatdef);
      end;


    function TFloatDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TFloatDef.GetTypeName : string;
      const
        names : array[TFloatType] of string[20] = (
          'Single','Double','Extended','CExtended','Comp','Currency');
      begin
         GetTypeName:=names[floattype];
      end;


{****************************************************************************
                                TFILEDEF
****************************************************************************}

    constructor TFileDef.createtext;
      begin
         inherited create(filedef,true);
         filetyp:=ft_text;
         typedfiledef:=nil;
         typedfiledefderef.reset;
      end;


    constructor TFileDef.createuntyped;
      begin
         inherited create(filedef,true);
         filetyp:=ft_untyped;
         typedfiledef:=nil;
      end;


    constructor TFileDef.createtyped(def:TDef);
      begin
         inherited create(filedef,true);
         filetyp:=ft_typed;
         typedfiledef:=def;
      end;


    constructor TFileDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(filedef,ppufile);
         filetyp:=TFileTyp(ppufile.getbyte);
         if filetyp=ft_typed then
           ppufile.getderef(typedfiledefderef)
         else
           typedfiledef:=nil;
         PPULoadPlatform(ppufile);
      end;


    function TFileDef.getcopy : TStoredDef;
      begin
        case filetyp of
          ft_typed:
            result:=CFileDef.createtyped(typedfiledef);
          ft_untyped:
            result:=CFileDef.createuntyped;
          ft_text:
            result:=CFileDef.createtext;
        end;
      end;


    procedure TFileDef.buildderef;
      begin
        inherited buildderef;
        if filetyp=ft_typed then
          typedfiledefderef.build(typedfiledef);
      end;


    procedure TFileDef.deref;
      begin
        inherited deref;
        if filetyp=ft_typed then
          typedfiledef:=TDef(typedfiledefderef.resolve);
      end;


    function  TFileDef.size:asizeint;
      begin
        if savesize=0 then
          setsize;
        size:=savesize;
      end;


    procedure TFileDef.setsize;
      begin
       case filetyp of
         ft_text:
           savesize:=search_system_type('TEXTREC').typedef.size;
         ft_typed:
           begin
             savesize:=search_system_type('FILEREC').typedef.size;
             { allocate put/get buffer in iso mode }
             if m_isolike_io in CurrentSettings.ModeSwitches then
               inc(savesize,typedfiledef.size);
           end;
         ft_untyped:
           savesize:=search_system_type('FILEREC').typedef.size;
         end;
      end;


    function TFileDef.alignment: shortint;
      begin
        case filetyp of
          ft_text:
            result:=search_system_type('TEXTREC').typedef.alignment;
          ft_typed,
          ft_untyped:
            result:=search_system_type('FILEREC').typedef.alignment;
          end;
      end;


    procedure TFileDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(filetyp));
         if filetyp=ft_typed then
           ppufile.putderef(typedfiledefderef);
         writeentry(ppufile,ibfiledef);
      end;


    function TFileDef.GetTypeName : string;
      begin
         case filetyp of
           ft_untyped:
             GetTypeName:='File';
           ft_typed:
             GetTypeName:='File Of '+typedfiledef.typename;
           ft_text:
             GetTypeName:='Text'
         end;
      end;


    function TFileDef.getmangledparaname : TSymStr;
      begin
         case filetyp of
           ft_untyped:
             getmangledparaname:='FILE';
           ft_typed:
             getmangledparaname:='FILE$OF$'+typedfiledef.mangledparaname;
           ft_text:
             getmangledparaname:='TEXT'
         end;
      end;


{****************************************************************************
                               TVARIANTDEF
****************************************************************************}

    constructor TVariantDef.create(v : TVariantType);
      begin
         inherited create(variantdef,true);
         varianttype:=v;
         setsize;
      end;


    constructor TVariantDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(variantdef,ppufile);
         varianttype:=TVariantType(ppufile.getbyte);
         setsize;
         PPULoadPlatform(ppufile);
      end;


    function TVariantDef.getcopy : TStoredDef;
      begin
        result:=CVariantDef.create(varianttype);
      end;


    function TVariantDef.alignment: shortint;
      begin
        result:=search_system_type('TVARDATA').typedef.alignment;
      end;


    procedure TVariantDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(varianttype));
         writeentry(ppufile,ibvariantdef);
      end;


    function TVariantDef.getvardef : LongInt;
      begin
        Result:=varVariant;
      end;


    procedure TVariantDef.setsize;
      begin
{$ifdef cpu64bitaddr}
        savesize:=24;
{$else cpu64bitaddr}
        savesize:=16;
{$endif cpu64bitaddr}
      end;


    function TVariantDef.GetTypeName : string;
      begin
         case varianttype of
           vt_normalvariant:
             GetTypeName:='Variant';
           vt_olevariant:
             GetTypeName:='OleVariant';
         end;
      end;


    function TVariantDef.NeedsInitTable : boolean;
      begin
         NeedsInitTable:=true;
      end;


    function TVariantDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


{****************************************************************************
                            TABSTRACtpointerdef
****************************************************************************}

    constructor TAbstractPointerDef.create(dt:TDefTyp;def:TDef);
      begin
        inherited create(dt,true);
        pointeddef:=def;
        pointeddefderef.reset;
        if df_generic in pointeddef.defoptions then
          include(defoptions,df_generic);
        if df_specialization in pointeddef.defoptions then
          include(defoptions,df_specialization);
      end;


    constructor TAbstractPointerDef.ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(dt,ppufile);
         ppufile.getderef(pointeddefderef);
      end;


    procedure TAbstractPointerDef.buildderef;
      begin
        inherited buildderef;
        pointeddefderef.build(pointeddef);
      end;


    procedure TAbstractPointerDef.deref;
      begin
        inherited deref;
        pointeddef:=TDef(pointeddefderef.resolve);
      end;


    function TAbstractPointerDef.size: asizeint;
      begin
        Result:=voidpointertype.size;
      end;


    function TAbstractPointerDef.alignment: shortint;
      begin
        alignment:=Size_2_Align(voidpointertype.size);
      end;


    procedure TAbstractPointerDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(pointeddefderef);
      end;


{****************************************************************************
                               tpointerdef
****************************************************************************}

    constructor TPointerDef.create(def:TDef);
      begin
        inherited create(pointerdef,def);
        has_pointer_math:=cs_pointermath in CurrentSettings.LocalSwitches;
        if (df_specialization in TStoredDef(def).defoptions)
{$ifndef genericdef_for_nested}
           { currently, nested procdefs of generic routines get df_specialization,
             but no genericdef }
           and Assigned(TStoredDef(def).genericdef)
{$endif}
           then
          genericdef:=CPointerDef.getreusable(TStoredDef(def).genericdef);
      end;


    class function TPointerDef.getreusable(def: TDef): TPointerDef;
      var
        res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
      begin
        if not Assigned(CurrentModule) then
          InternalError(2011071101);
        res:=CurrentModule.ptrdefs.FindOrAdd(@def,sizeof(def));
        if not Assigned(res^.Data) then
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
            result:=CPointerDef.create(def);
            SetupReusableDef(def,result,res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            exit;
          end;
        result:=TPointerDef(res^.Data);
      end;


    class function TPointerDef.getreusable_no_free(def: TDef): TPointerDef;
      begin
        result:=getreusable(def);
        if not result.IsRegistered then
          include(result.defoptions,df_not_registered_no_free);
      end;


    function TPointerDef.size: asizeint;
      begin
        result:=sizeof(PInt);
      end;


    constructor TPointerDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(pointerdef,ppufile);
         has_pointer_math:=(ppufile.getbyte<>0);
         PPULoadPlatform(ppufile);
      end;


    function TPointerDef.getcopy : TStoredDef;
      begin
        { don't use direct pointeddef if it is a forwarddef because in other case
          one of them will be destroyed on forward type resolve and the second will
          point to garbage }
        if pointeddef.typ=forwarddef then
          result:=CPointerDef.create(TForwardDef(pointeddef).getcopy)
        else
          result:=CPointerDef.create(pointeddef);
        TPointerDef(result).has_pointer_math:=has_pointer_math;
        TPointerDef(result).savesize:=savesize;
      end;


    procedure TPointerDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(has_pointer_math));
         writeentry(ppufile,ibpointerdef);
      end;


    function TPointerDef.GetTypeName : string;
      begin
        { parameter types and the resultdef of a procvardef can contain a
          pointer to this procvardef itself, resulting in endless recursion ->
          use the typesym's name instead if it exists (if it doesn't, such as
          for anonymous procedure types in macpas/iso mode, then there cannot
          be any recursive references to it either) }
        if (pointeddef.typ<>procvardef) or
           not Assigned(pointeddef.typesym) then
          GetTypeName:='^'+pointeddef.typename
        else
          GetTypeName:='^'+pointeddef.typesym.realname;
      end;


    function TPointerDef.pointer_arithmetic_int_type:TDef;
      begin
        result:=ptrsinttype;
      end;


    function TPointerDef.pointer_arithmetic_uint_type:TDef;
      begin
        result:=ptruinttype;
      end;


    function TPointerDef.pointer_subtraction_result_type:TDef;
      begin
        result:=ptrsinttype;
      end;


    function TPointerDef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
      begin
        result:=true;
      end;


    function TPointerDef.converted_pointer_to_array_range_type:TDef;
      begin
        result:=ptrsinttype;
      end;


{****************************************************************************
                              TCLASSREFDEF
****************************************************************************}

    constructor TClassRefDef.create(def:TDef);
      begin
         while (def.typ=objectdef) and TObjectDef(def).is_unique_objpasdef do
           def:=TObjectDef(def).childof;
         inherited create(classrefdef,def);
         if df_specialization in TStoredDef(def).defoptions then
           genericdef:=CClassRefDef.create(TStoredDef(def).genericdef);
      end;


    constructor TClassRefDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(classrefdef,ppufile);
         PPULoadPlatform(ppufile);
      end;


    procedure TClassRefDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         writeentry(ppufile,ibclassrefdef);
      end;


    function TClassRefDef.getcopy:TStoredDef;
      begin
        if pointeddef.typ=forwarddef then
          result:=CClassRefDef.create(TForwardDef(pointeddef).getcopy)
        else
          result:=CClassRefDef.create(pointeddef);
      end;


    function TClassRefDef.GetTypeName : string;
      begin
         GetTypeName:='Class Of '+pointeddef.typesymbolprettyname;
      end;


    function TClassRefDef.IsPublishable : TPublishProperty;
      begin
         IsPublishable:=pp_publish;
      end;


    function TClassRefDef.RTTIMangledName(rt: TRTTIType): TSymStr;
      begin
        if (TObjectDef(pointeddef).objecttype<>odt_objcclass) then
          result:=inherited RTTIMangledName(rt)
        else
          result:=TObjectDef(pointeddef).RTTIMangledName(objcmetartti);
      end;


    procedure TClassRefDef.RegisterCreatedObjectType;
      begin
        TObjectDef(pointeddef).RegisterCreatedClassRefType;
      end;

{***************************************************************************
                                   TSETDEF
***************************************************************************}

    constructor TSetDef.create(def: TDef; low, high: asizeint; doregister: boolean);
      var
        setallocbits: aint;
        packedsavesize: aint;
        actual_setalloc: ShortInt;
      begin
         inherited create(setdef,doregister);
         elementdef:=def;
         elementdefderef.reset;
         setmax:=high;
         setlow:=low;
         actual_setalloc:=CurrentSettings.SetAlloc;

         if (actual_setalloc=0) then
           begin
             setbase:=0;
             if (high<32) then
               savesize:=Sizeof(LongInt)
             else if (high<256) then
               savesize:=32
             else
               savesize:=(high+7) div 8
           end
         else
           begin
             setallocbits:=actual_setalloc*8;
             setbase:=low and not(setallocbits-1);
             packedsavesize:=actual_setalloc*((((high+setallocbits)-setbase)) DIV setallocbits);
             savesize:=packedsavesize;

             if savesize=3 then
               savesize:=4;

           end;
      end;


    constructor TSetDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(setdef,ppufile);
         ppufile.getderef(elementdefderef);
         savesize:=ppufile.getasizeint;
         setbase:=ppufile.getasizeint;
         setlow:=ppufile.getasizeint;
         setmax:=ppufile.getasizeint;
         PPULoadPlatform(ppufile);
      end;


    function TSetDef.getcopy : TStoredDef;
      begin
        result:=CSetDef.create(elementdef,setbase,setmax,true);
        { the copy might have been created with a different setalloc setting }
        TSetDef(result).savesize:=savesize;
      end;


    procedure TSetDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(elementdefderef);
         ppufile.putasizeint(savesize);
         ppufile.putasizeint(setbase);
         ppufile.putasizeint(setlow);
         ppufile.putasizeint(setmax);
         writeentry(ppufile,ibsetdef);
      end;


    procedure TSetDef.buildderef;
      begin
        inherited buildderef;
        elementdefderef.build(elementdef);
      end;


    procedure TSetDef.deref;
      begin
        inherited deref;
        elementdef:=TDef(elementdefderef.resolve);
      end;


    function TSetDef.IsPublishable : TPublishProperty;
      begin
         if savesize in [1,2,4] then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;

    function TSetDef.alignment: shortint;
      begin
        Result:=inherited;
        if result>sizeof(aint) then
          result:=sizeof(aint);
      end;


    function TSetDef.GetTypeName : string;
      begin
         if Assigned(elementdef) then
          GetTypeName:='Set Of '+elementdef.typename
         else
          GetTypeName:='Empty Set';
      end;


{***************************************************************************
                                 TFORMALDEF
***************************************************************************}

    constructor TFormalDef.create(Atyped:boolean);
      begin
         inherited create(formaldef,true);
         typed:=Atyped;
         savesize:=0;
      end;


    constructor TFormalDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(formaldef,ppufile);
         typed:=boolean(ppufile.getbyte);
         savesize:=0;
         PPULoadPlatform(ppufile);
      end;


    procedure TFormalDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(typed));
         writeentry(ppufile,ibformaldef);
      end;


    function TFormalDef.GetTypeName : string;
      begin
         if typed then
           GetTypeName:='<Typed formal type>'
         else
           GetTypeName:='<Formal type>';
      end;


{***************************************************************************
                           TARRAYDEF
***************************************************************************}

    constructor TArrayDef.create(l, h: asizeint; def: TDef);
      begin
         inherited create(arraydef,true);
         lowrange:=l;
         highrange:=h;
         rangedef:=def;
         rangedefderef.reset;
         _elementdef:=nil;
         _elementdefderef.reset;
         arrayoptions:=[];
         SymTable:=TArraySymTable.create(self);
      end;


    constructor TArrayDef.create_vector(l ,h: asizeint; def: TDef);
      begin
        self.create(l,h,def);
        include(arrayoptions,ado_IsVector);
      end;


    constructor TArrayDef.create_openarray;
      begin
        self.create(0,-1,sizesinttype);
        include(arrayoptions,ado_OpenArray);
      end;


    class function TArrayDef.getreusable_intern(def: TDef; elems: asizeint; const options: TArrayDefOptions): TArrayDef;
      var
        res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
        arrdesc: packed record
          def: TDef;
          elecount: asizeint;
          options: TArrayDefOptions
        end;
      begin
        if not Assigned(CurrentModule) then
          InternalError(2011081301);
        arrdesc.def:=def;
        arrdesc.elecount:=elems;
        arrdesc.options:=options;
        res:=CurrentModule.arraydefs.FindOrAdd(@arrdesc,sizeof(arrdesc));
        if not Assigned(res^.Data) then
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
            result:=CArrayDef.create(0,elems-1,sizesinttype);
            result.elementdef:=def;
            result.arrayoptions:=options;
            SetupReusableDef(def,result,res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            exit;
          end;
        result:=TArrayDef(res^.Data);
      end;


    class function TArrayDef.getreusable(def: TDef; elems: asizeint): TArrayDef;
      begin
        result:=getreusable_intern(def,elems,[]);
      end;


    class function TArrayDef.getreusable_vector(def: TDef; elems: asizeint): TArrayDef;
      begin
        result:=getreusable_intern(def,elems,[ado_IsVector]);
      end;


    class function TArrayDef.getreusable_no_free(def: TDef; elems: asizeint): TArrayDef;
      begin
        result:=getreusable(def,elems);
        if not result.IsRegistered then
          include(result.defoptions,df_not_registered_no_free);
      end;

    class function TArrayDef.getreusable_no_free_vector(def: TDef; elems: asizeint): TArrayDef;
      begin
        result:=getreusable_vector(def,elems);
        if not result.IsRegistered then
          include(result.defoptions,df_not_registered_no_free);
      end;


    destructor TArrayDef.Destroy;
      begin
        SymTable.free;
        SymTable:=nil;
        inherited;
      end;


    constructor TArrayDef.create_from_pointer(def:TPointerDef);
      begin
         { divide by the element size and do -1 so the array will have a valid size,
           further, the element size might be 0 e.g. for empty records, so use max(...,1)
           to avoid a division by zero }
         self.create(0,(high(asizeint) div max(def.pointeddef.size,1))-1,
           def.converted_pointer_to_array_range_type);
         arrayoptions:=[ado_IsConvertedPointer];
         setelementdef(def.pointeddef);
      end;


    constructor TArrayDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(arraydef,ppufile);
         { the addresses are calculated later }
         ppufile.getderef(_elementdefderef);
         ppufile.getderef(rangedefderef);
         lowrange:=ppufile.getasizeint;
         highrange:=ppufile.getasizeint;
         ppufile.getset(TPPUSet2(arrayoptions));
         PPULoadPlatform(ppufile);
         SymTable:=TArraySymTable.create(self);
         TArraySymTable(SymTable).ppuload(ppufile)
      end;


    function TArrayDef.getcopy : TStoredDef;
      begin
        result:=CArrayDef.create(lowrange,highrange,rangedef);
        TArrayDef(result).arrayoptions:=arrayoptions;
        TArrayDef(result)._elementdef:=_elementdef;
      end;


    procedure TArrayDef.buildderef;
      begin
        inherited buildderef;
        TArraySymTable(SymTable).buildderef;
        _elementdefderef.build(_elementdef);
        rangedefderef.build(rangedef);
      end;


    procedure TArrayDef.deref;
      begin
        inherited deref;
        TArraySymTable(SymTable).deref(false);
        _elementdef:=TDef(_elementdefderef.resolve);
        rangedef:=TDef(rangedefderef.resolve);
      end;


    procedure TArrayDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(_elementdefderef);
         ppufile.putderef(rangedefderef);
         ppufile.putasizeint(lowrange);
         ppufile.putasizeint(highrange);
         ppufile.putset(TPPUSet2(arrayoptions));
         writeentry(ppufile,ibarraydef);
         TArraySymTable(SymTable).ppuwrite(ppufile);
      end;


    function TArrayDef.elesize : asizeint;
      begin
        if (ado_IsBitPacked in arrayoptions) then
          InternalError(2006080101);
        if Assigned(_elementdef) then
          result:=_elementdef.size
        else
          result:=0;
      end;


    function TArrayDef.elepackedbitsize : asizeint;
      begin
        if not(ado_IsBitPacked in arrayoptions) then
          InternalError(2006080102);
	if Assigned(_elementdef) then
          result:=_elementdef.packedbitsize
	else
	  result:=0;
      end;


    function TArrayDef.elecount : ASizeUInt;
      var
        qhigh,qlow : qword;
      begin
        if ado_IsDynamicArray in arrayoptions then
          begin
            result:=0;
            exit;
          end;
        { check whether the range might be larger than high(asizeint). Has
          to include 0..high(sizeint), since that's high(sizeint)+1 elements }
        if (highrange>=0) and (lowrange<=0) then
          begin
            qhigh:=highrange;
            if lowrange=low(asizeint) then
              qlow:=high(asizeint) + 1
            else
              qlow:=qword(-lowrange);
            { prevent overflow, return 0 to indicate overflow }
            if qhigh+qlow>qword(high(asizeint)-1) then
              result:=0
            else
              result:=qhigh+qlow+1;
          end
        else
          result:=int64(highrange)-lowrange+1;
      end;


    function TArrayDef.size : asizeint;
      var
        cachedelecount : ASizeUInt;
        cachedelesize : asizeint;
      begin
        if ado_IsDynamicArray in arrayoptions then
          begin
            size:=voidpointertype.size;
            exit;
          end;

        { Tarraydef.size may never be called for an open array! }
        if ado_OpenArray in arrayoptions then
          InternalError(99080501);
        if not (ado_IsBitPacked in arrayoptions) then
          cachedelesize:=elesize
        else
          cachedelesize := elepackedbitsize;
        cachedelecount:=elecount;

        if (cachedelesize = 0) then
          begin
            size := 0;
            exit;
          end;

        if (cachedelecount = 0) then
          begin
            if ado_isconststring in arrayoptions then
              size := 0
            else
              size := -1;
            exit;
          end;

        { prevent overflow, return -1 to indicate overflow }
        { also make sure we don't need 64/128 bit arithmetic to calculate offsets }
        if (cachedelecount > ASizeUInt(high(asizeint))) or
           ((high(asizeint) div cachedelesize) < asizeint(cachedelecount)) or
           { also lowrange*elesize must be < high(asizeint) to prevent overflow when
             accessing the array, see ncgmem (PFV) }
           ((high(asizeint) div cachedelesize) < abs(lowrange)) then
          begin
            result:=-1;
            exit;
          end;

        result:=cachedelesize*asizeint(cachedelecount);
        if (ado_IsBitPacked in arrayoptions) then
          { can't just add 7 and divide by 8, because that may overflow }
          result:=result div 8 + ord((result mod 8)<>0);

      end;


    procedure TArrayDef.setelementdef(def:TDef);
      begin
        _elementdef:=def;
        if not(
               (ado_IsDynamicArray in arrayoptions) or
               (ado_IsConvertedPointer in arrayoptions) or
               (ado_IsConstructor in arrayoptions) or
               (ado_IsGeneric in arrayoptions) or
               (highrange<lowrange)
	      ) and
           (size=-1) then
          Message(sym_e_segment_too_large);
      end;


    function TArrayDef.alignment : shortint;
      begin
        if ado_IsVector in arrayoptions then
           alignment:=size
         { alignment of dyn. arrays doesn't depend on the element size }
         else if ado_IsDynamicArray in arrayoptions then
           alignment:=voidpointertype.alignment
         { alignment is the target alignment for the used load size }
         else if (ado_IsBitPacked in arrayoptions) and
            (elementdef.typ in [enumdef,orddef]) then
           alignment:=cgsize_orddef(int_cgsize(PackedBitsLoadSize(elepackedbitsize))).alignment
         { alignment is the alignment of the elements }
         else
           alignment:=elementdef.alignment
      end;


    function TArrayDef.NeedsInitTable : boolean;
      begin
         NeedsInitTable:=(ado_IsDynamicArray in arrayoptions) or elementdef.NeedsInitTable;
      end;

    function TArrayDef.NeedsSeparateInitRTTI : boolean;
      begin
        if ado_IsBitPacked in arrayoptions then
          result:=false
        else
          result:=elementdef.NeedsSeparateInitRTTI;
      end;

    function TArrayDef.GetTypeName : string;
      begin
         if (ado_IsConstString in arrayoptions) then
           result:='Constant String'
         else if (ado_isarrayofconst in arrayoptions) or
                 (ado_isConstructor in arrayoptions) then
           begin
             if (ado_isvariant in arrayoptions) or ((highrange=-1) and (lowrange=0)) then
               GetTypeName:='Array Of Const'
             else
               GetTypeName:='{Array Of Const/Constant Open} Array of '+elementdef.typename;
           end
         else if (ado_IsDynamicArray in arrayoptions) then
           GetTypeName:='{Dynamic} Array Of '+elementdef.typename
         else if (ado_OpenArray in arrayoptions) then
           GetTypeName:='{Open} Array Of '+elementdef.typename
         else
           begin
              result := '';
              if (ado_IsBitPacked in arrayoptions) then
                result:='BitPacked ';
              if rangedef.typ=enumdef then
                result:=result+'Array['+rangedef.typename+'] Of '+elementdef.typename
              else
                result:=result+'Array['+ToStr(lowrange)+'..'+
                  ToStr(highrange)+'] Of '+elementdef.typename
           end;
      end;


    function TArrayDef.getmangledparaname : TSymStr;
      begin
         if ado_isarrayofconst in arrayoptions then
          getmangledparaname:='array_of_const'
         else
          if ((highrange=-1) and (lowrange=0)) then
           getmangledparaname:='array_of_'+elementdef.mangledparaname
         else
          InternalError(200204176);
      end;


    function TArrayDef.IsPublishable : TPublishProperty;
      begin
         if ado_IsDynamicArray in arrayoptions then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TArrayDef.is_hwvector: boolean;
      begin
        result:=ado_IsVector in arrayoptions;
      end;

{***************************************************************************
                              tabstractrecorddef
***************************************************************************}

    constructor TAbstractRecordDef.create(const n:string; dt:TDefTyp;doregister:boolean);
      begin
        inherited create(dt,doregister);
        objname:=StringDup(upper(n));
        objrealname:=StringDup(n);
        objectoptions:=[];
        if Assigned(CurrentModule.namespace) then
          begin
            import_lib:=StringDup(CurrentModule.namespace^);
            replace(import_lib^,'.','/');
          end;
      end;

    constructor TAbstractRecordDef.ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
      var
        ro: TRTTIOption;
      begin
        inherited ppuload(dt,ppufile);
        objrealname:=ppufile.getpshortstring;
        objname:=StringDup(upper(objrealname^));
        import_lib:=ppufile.getpshortstring;
        { only used for external C++ classes and Java classes/records }
        if (import_lib^='') then
          StringDispose(import_lib);
        ppufile.getset(TPPUSet4(objectoptions));
        rtti.clause:=TRTTIClause(ppufile.getbyte);
        for ro in TRTTIOption do
          ppufile.getset(TPPUSet1(rtti.options[ro]));
      end;

    procedure TAbstractRecordDef.ppuwrite(ppufile: TCompilerPPUFile);
      var
        ro: TRTTIOption;
      begin
        inherited ppuwrite(ppufile);
        ppufile.putstring(objrealname^);
        if Assigned(import_lib) then
          ppufile.putstring(import_lib^)
        else
          ppufile.putstring('');
        ppufile.putset(TPPUSet4(objectoptions));
        ppufile.putbyte(byte(rtti.clause));
        for ro in TRTTIOption do
          ppufile.putset(TPPUSet1(rtti.options[ro]));
      end;

    destructor TAbstractRecordDef.Destroy;
      begin
        StringDispose(objname);
        StringDispose(objrealname);
        StringDispose(import_lib);
        tcinitcode.free;
        tcinitcode := nil;
        inherited Destroy;
      end;


    procedure TAbstractRecordDef.buildderefimpl;
      begin
         inherited buildderefimpl;
         if not (df_copied_def in defoptions) then
           TStoredSymTable(SymTable).buildderefimpl;
      end;


    procedure TAbstractRecordDef.derefimpl;
      begin
        inherited derefimpl;
        if not (df_copied_def in defoptions) then
          TStoredSymTable(SymTable).derefimpl(false);
      end;


    procedure TAbstractRecordDef.check_forwards;
      begin
        { the defs of a copied def are defined for the original type only }
        if not(df_copied_def in defoptions) then
          TStoredSymTable(SymTable).check_forwards;
      end;

    function TAbstractRecordDef.find_procdef_bytype(pt:TProcTypeOption): TProcDef;
      var
        i: LongInt;
        sym: TSym;
      begin
        for i:=0 to SymTable.SymList.Count-1 do
          begin
            sym:=TSym(SymTable.SymList[i]);
            if sym.typ=procsym then
              begin
                result:=TProcSym(sym).find_procdef_bytype(pt);
                if Assigned(result) then
                  exit;
              end;
          end;
          result:=nil;
      end;

    function TAbstractRecordDef.GetSymtable(t:TGetSymTable):TSymTable;
      begin
        if t=gs_record then
          GetSymtable:=SymTable
        else
          GetSymtable:=nil;
      end;


    function TAbstractRecordDef.is_packed:boolean;
      begin
        result:=TAbstractRecordSymTable(SymTable).is_packed;
      end;

    function TAbstractRecordDef.RttiName: string;

        function generate_full_paramname(maxlength:LongInt):string;
          const
            commacount : array[boolean] of LongInt = (0,1);
          var
            fullparas,
            paramname : AnsiString;
            module : TModule;
            sym : TSym;
            def : TDef;
            i : LongInt;
          begin
            { we want at least enough space for an ellipsis }
            if maxlength<3 then
              InternalError(2014121203);
            fullparas:='';
            for i:=0 to genericparas.count-1 do
              begin
                sym:=TSym(genericparas[i]);
                module:=find_module_from_symtable(sym.owner);
                if not Assigned(module) then
                  InternalError(2014121202);
                if not (sym.typ in [constsym,symconst.typesym]) then
                  InternalError(2020042501);
                if sym.typ=constsym then
                  def:=TConstSym(sym).constdef
                else
                  def:=TTypeSym(sym).typedef;
                paramname:=module.RealModuleName^;
                if def.typ in [objectdef,recorddef] then
                  paramname:=paramname+'.'+TAbstractRecordDef(def).rttiname
                else
                  paramname:=paramname+'.'+def.typename;
                if length(fullparas)+commacount[i>0]+length(paramname)>maxlength then
                  begin
                    if i>0 then
                      fullparas:=fullparas+',...'
                    else
                      fullparas:=fullparas+'...';
                    break;
                  end;
                { could we fit an ellipsis after this parameter if it should be too long? }
                if (maxlength-(length(fullparas)+commacount[i>0]+length(paramname))<4) and (i<genericparas.count-1) then
                  begin
                    { then omit already this parameter }
                    if i>0 then
                      fullparas:=fullparas+',...'
                    else
                      fullparas:=fullparas+'...';
                    break;
                  end;
                if i>0 then
                  fullparas:=fullparas+',';
                fullparas:=fullparas+paramname;
              end;
            result:=fullparas;
          end;

      var
        nongeneric,
        basename : string;
        i,
        remlength,
        paramcount,
        crcidx : LongInt;
      begin
        if rttistring='' then
          begin
            if is_specialization then
              begin
                rttistring:=OwnerHierarchyName;
                { there should be two $ characters, one before the CRC and one before the count }
                crcidx:=-1;
                for i:=length(objrealname^) downto 1 do
                  if objrealname^[i]='$' then
                    begin
                      crcidx:=i;
                      break;
                    end;
                if crcidx<0 then
                  InternalError(2014121201);
                basename:=copy(objrealname^,1,crcidx-1);
                split_generic_name(basename,nongeneric,paramcount);
                rttistring:=rttistring+nongeneric+'<';
                remlength:=255-length(rttistring)-1;
                if remlength<4 then
                  rttistring:=rttistring+'>'
                else
                  rttistring:=rttistring+generate_full_paramname(remlength)+'>';
              end
            else
              if is_generic then
                begin
                  rttistring:=OwnerHierarchyName;
                  split_generic_name(objrealname^,nongeneric,paramcount);
                  rttistring:=rttistring+nongeneric+'<';
                  { we don't want any ',' if there is only one parameter }
                  for i:=0 to paramcount-1 do
                    rttistring:=rttistring+',';
                  rttistring:=rttistring+'>';
                end
              else
                rttistring:=OwnerHierarchyName+objrealname^;
          end;
        result:=rttistring;
      end;

    function TAbstractRecordDef.search_enumerator_get: TProcDef;
      var
        sym : TSym;
        i : integer;
        pd : TProcDef;
        hashedid : THashedIDString;
      begin
        result:=nil;
        hashedid.id:='GETENUMERATOR';
        sym:=TSym(SymTable.FindWithHash(hashedid));
        if Assigned(sym) and (sym.typ=procsym) then
          begin
            for i := 0 to TProcSym(sym).ProcdefList.Count - 1 do
            begin
              pd := TProcDef(TProcSym(sym).ProcdefList[i]);
              if (pd.proctypeoption = potype_function) and
                 (is_class_or_interface_or_object(pd.returndef) or is_record(pd.returndef)) and
                 (pd.visibility >= vis_public) then
              begin
                result:=pd;
                exit;
              end;
            end;
          end;
      end;

    function TAbstractRecordDef.search_enumerator_move: TProcDef;
      var
        sym : TSym;
        i : integer;
        pd : TProcDef;
        hashedid : THashedIDString;
      begin
        result:=nil;
        // first search for po_enumerator_movenext method modifier
        // then search for public function MoveNext: Boolean
        for i:=0 to SymTable.SymList.Count-1 do
          begin
            sym:=TSym(SymTable.SymList[i]);
            if (sym.typ=procsym) then
            begin
              pd:=TProcSym(sym).find_procdef_byoptions([po_enumerator_movenext]);
              if Assigned(pd) then
                begin
                  result:=pd;
                  exit;
                end;
            end;
          end;
        hashedid.id:='MOVENEXT';
        sym:=TSym(SymTable.FindWithHash(hashedid));
        if Assigned(sym) and (sym.typ=procsym) then
          begin
            for i:=0 to TProcSym(sym).ProcdefList.Count-1 do
            begin
              pd := TProcDef(TProcSym(sym).ProcdefList[i]);
              if (pd.proctypeoption = potype_function) and
                 is_boolean(pd.returndef) and
                 (pd.minparacount = 0) and
                 (pd.visibility >= vis_public) then
              begin
                result:=pd;
                exit;
              end;
            end;
          end;
      end;

    function TAbstractRecordDef.search_enumerator_current: TSym;
      var
        sym: TSym;
        i: integer;
        hashedid : THashedIDString;
      begin
        result:=nil;
        // first search for ppo_enumerator_current property modifier
        // then search for public property Current
        for i:=0 to SymTable.SymList.Count-1 do
          begin
            sym:=TSym(SymTable.SymList[i]);
            if (sym.typ=propertysym) and (ppo_enumerator_current in TPropertySym(sym).propoptions) then
            begin
              result:=sym;
              exit;
            end;
          end;
        hashedid.id:='CURRENT';
        sym:=TSym(SymTable.FindWithHash(hashedid));
        if Assigned(sym) and (sym.typ=propertysym) and
           (sym.visibility >= vis_public) and not TPropertySym(sym).propaccesslist[palt_read].empty then
          begin
            result:=sym;
            exit;
          end;
      end;


    function TAbstractRecordDef.jvm_full_typename(with_package_name: boolean): string;
      var
        st: TSymTable;
        enclosingdef: TDef;
      begin
        if typ=objectdef then
          result:=TObjectDef(self).objextname^
        else if Assigned(typesym) then
          result:=typesym.realname
        { have to generate anonymous nested type in current unit/class/record }
        else
          InternalError(2011032601);

        { in case of specializations, add some extras to prevent name conflicts
          with nested classes }
        if df_specialization in defoptions then
          result:='$'+result+'$specialization$';

        st:=owner;
        while Assigned(st) and
              (st.symtabletype in [objectsymtable,recordsymtable,localsymtable]) do
          begin
            { nested classes are named as "OuterClass$InnerClass" }
            enclosingdef:=TDef(st.defowner);
            if enclosingdef.typ=procdef then
              result:=result+TProcDef(enclosingdef).procsym.realname+'$$'+ToStr(TProcDef(enclosingdef).procsym.symid)+'$'
            else if enclosingdef.typ=objectdef then
              result:=TObjectDef(enclosingdef).objextname^+'$'+result
            else if Assigned(enclosingdef.typesym) then
              result:=enclosingdef.typesym.realname+'$'+result
            else
              InternalError(2011060305);
            st:=enclosingdef.owner;
          end;

        if with_package_name and
           Assigned(import_lib) then
          result:=import_lib^+'/'+result;
      end;


    function TAbstractRecordDef.contains_float_field: boolean;
      var
        i : LongInt;
      begin
        result:=true;
        for i:=0 to SymTable.symlist.count-1 do
          begin
            if (TSym(SymTable.symlist[i]).typ<>fieldvarsym) or
               (sp_static in TSym(SymTable.symlist[i]).symoptions) then
              continue;
            if Assigned(TFieldVarSym(SymTable.symlist[i]).vardef) then
              begin
                if TStoredDef(TFieldVarSym(SymTable.symlist[i]).vardef).is_fpuregable then
                  exit;
                { search recursively }
                if (TStoredDef(TFieldVarSym(SymTable.symlist[i]).vardef).typ=recorddef) and
                  (TAbstractRecordDef(TFieldVarSym(SymTable.symlist[i]).vardef).contains_float_field) then
                  exit;
              end;
          end;
        result:=false;
      end;


    function TAbstractRecordDef.contains_cross_aword_field: boolean;
      var
        i : LongInt;
        foffset, fsize: aword;
      begin
        result:=true;
        for i:=0 to SymTable.symlist.count-1 do
          begin
            if (TSym(SymTable.symlist[i]).typ<>fieldvarsym) or
               (sp_static in TSym(SymTable.symlist[i]).symoptions) then
              continue;
            if Assigned(TFieldVarSym(SymTable.symlist[i]).vardef) then
              begin
                if is_packed then
                  begin
                    foffset:=TFieldVarSym(SymTable.symlist[i]).fieldoffset;
                    fsize:=TFieldVarSym(SymTable.symlist[i]).vardef.packedbitsize;
                  end
                else
                  begin
                    foffset:=TFieldVarSym(SymTable.symlist[i]).fieldoffset*8;
                    fsize:=TFieldVarSym(SymTable.symlist[i]).vardef.size*8;
                  end;
                if (fsize>0) and ((foffset div (sizeof(aword)*8)) <> ((foffset+fsize-1) div (sizeof(aword)*8))) then
                  exit;
                { search recursively }
                if (TStoredDef(TFieldVarSym(SymTable.symlist[i]).vardef).typ=recorddef) and
                  (TAbstractRecordDef(TFieldVarSym(SymTable.symlist[i]).vardef).contains_cross_aword_field) then
                  exit;
              end;
          end;
        result:=false;
      end;


    procedure TAbstractRecordDef.apply_rtti_directive(dir: TRTTIDirective);
      begin
        { records don't support the inherit clause but shouldn't
          give an error either if used (for Delphi compatibility),
          so we silently enforce the clause as explicit. }
        rtti.clause:=rtc_explicit;
        rtti.options:=dir.options;
      end;


    function TAbstractRecordDef.is_visible_for_rtti(option: TRTTIOption; vis: TVisibility): boolean;
      begin
        case vis of
          vis_private,
          vis_strictprivate:   result:=rv_private in rtti.options[option];
          vis_protected,
          vis_strictprotected: result:=rv_protected in rtti.options[option];
          vis_public:          result:=rv_public in rtti.options[option];
          vis_published:       result:=rv_published in rtti.options[option];
          otherwise
            result:=false;
        end;
      end;


    function TAbstractRecordDef.rtti_visibilities_for_option(option: TRTTIOption): TVisibilities;
      begin
        result:=[];
        if rv_private in rtti.options[option] then
          begin
            include(result,vis_private);
            include(result,vis_strictprivate);
          end;
        if rv_protected in rtti.options[option] then
          begin
            include(result,vis_protected);
            include(result,vis_strictprotected);
          end;
        if rv_public in rtti.options[option] then
          include(result,vis_public);
        if rv_published in rtti.options[option] then
          include(result,vis_published);
      end;


    function TAbstractRecordDef.has_extended_rtti: boolean;
      begin
        result := (rtti.options[ro_fields]<>[]) or
                  (rtti.options[ro_methods]<>[]) or
                  (rtti.options[ro_properties]<>[]);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TAbstractRecordDef.XMLPrintDefData(var T: Text; Sym: TSym);

      procedure WriteSymOptions(SourceSym: TSym);
        var
          i: TSymOption;
          first: Boolean;
        begin
          First := True;
          for i := Low(TSymOption) to High(TSymOption) do
            if i in SourceSym.symoptions then
              begin
                if First then
                  begin
                    Write(T, '" symoptions="', i);
                    First := False;
                  end
                else
                  Write(T, ',', i)
              end;
        end;

      var
        List: TFPHashObjectList;
        i: Integer;
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

        { List the fields }
        List := SymTable.SymList;
        for i := 0 to List.Count - 1 do
          case TSym(List[i]).typ of
{            staticvarsym,localvarsym,paravarsym,fieldvarsym,
            typesym,procsym,unitsym,}
            constsym:
              with TConstSym(List[i]) do
                begin
                  Write(T, PrintNodeIndention, '<const name="', RealName, '" pos="', fileinfo.line, ',', fileinfo.column);
                  WriteSymOptions(TSym(List[i]));
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
            fieldvarsym:
              with TFieldVarSym(List[i]) do
                begin
                  Write(T, PrintNodeIndention, '<field name="', RealName, '" pos="', fileinfo.line, ',', fileinfo.column);
                  WriteSymOptions(TSym(List[i]));
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

    procedure TAbstractRecordDef.setobjrealname(const n:string);
      begin
        FreeMem(objrealname);
        objrealname:=StringDup(n);
      end;

{***************************************************************************
                                  trecorddef
***************************************************************************}

    constructor TRecordDef.create(const n:string; p:TSymTable);
      begin
         inherited create(n,recorddef,true);
         SymTable:=p;
         { we can own the symtable only if nobody else owns a copy so far }
         if SymTable.refcount=1 then
           SymTable.defowner:=self;
         isunion:=false;
         cloneddefderef.reset;
      end;


    constructor TRecordDef.create_internal(const n: string; PackRecords, RecordAlignMin: shortint; where: TSymTable);
      var
        name : string;
        OldSymTableStack: TSymTableStack;
        ts: TTypeSym;
      begin
        { construct name }
        if n<>'' then
          name:=n
        else
          begin
            InitDefID;
            name:='$InternalRec'+UniqueIDStr;
          end;
        OldSymTableStack:=SymTableStack;
        { do not simply push/pop current_module.localsymtable, because
          that can have side-effects (e.g., it removes helpers) }
        SymTableStack:=nil;

        SymTable:=TRecordSymTable.create(name,PackRecords,RecordAlignMin);
        SymTable.defowner:=self;
        isunion:=false;
        inherited create(name,recorddef,true);
        where.insertdef(self);
        { if we specified a name, then we'll probably want to look up the
          type again by name too -> create typesym }
        if n<>'' then
          begin
            ts:=CTypeSym.create(n,self);
            include(ts.symoptions,sp_internal);
            { avoid hints about unused types (these may only be used for
              typed constant data) }
            ts.increfcount;
            where.insertsym(ts);
          end;
        SymTableStack:=OldSymTableStack;
        { don't create RTTI for internal types, these are not exported }
        defstates:=defstates+[ds_rtti_table_written,ds_init_table_written];
        include(defoptions,df_internal);
      end;


    constructor TRecordDef.create_global_internal(const n: string; PackRecords, RecordAlignMin: shortint);
      var
        where : TSymTable;
      begin
        where:=CurrentModule.localsymtable;
        if not Assigned(where) then
          where:=CurrentModule.GlobalSymTable;
        create_internal(n,PackRecords,RecordAlignMin,where);
      end;


    function TRecordDef.add_field_by_def(const optionalname: TIDString; def: TDef): TSym;
      var
        sym: TFieldVarSym;
        name: TIDString;
        pname: ^TIDString;
      begin
        if optionalname='' then
          begin
            name:='$f'+ToStr(TRecordSymTable(SymTable).symlist.count);
            pname:=@name
          end
        else
          pname:=@optionalname;
        sym:=CFieldVarSym.create(pname^,vs_value,def,[]);
        SymTable.insertsym(sym);
        TRecordSymTable(SymTable).addfield(sym,vis_hidden);
        result:=sym;
      end;


    procedure TRecordDef.add_fields_from_deflist(fieldtypes: TFPList);
      var
        i: LongInt;
      begin
        for i:=0 to fieldtypes.count-1 do
          add_field_by_def('',TDef(fieldtypes[i]));
      end;


    constructor TRecordDef.ppuload(ppufile:TCompilerPPUFile);

      procedure readvariantrecdesc(var variantrecdesc : PVariantRecDesc);
        var
          i,j : LongInt;
        begin
         if ppufile.getbyte=1 then
           begin
             new(variantrecdesc);
             ppufile.getderef(variantrecdesc^.variantselectorderef);
             SetLength(variantrecdesc^.branches,ppufile.getasizeint);
             for i:=0 to high(variantrecdesc^.branches) do
               begin
                 SetLength(variantrecdesc^.branches[i].values,ppufile.getasizeint);
                 for j:=0 to high(variantrecdesc^.branches[i].values) do
                   variantrecdesc^.branches[i].values[j]:=ppufile.getexprint;
                 readvariantrecdesc(variantrecdesc^.branches[i].nestedvariant);
               end;
           end
         else
           variantrecdesc:=nil;
        end;

      begin
         inherited ppuload(recorddef,ppufile);
         if df_copied_def in defoptions then
           begin
             ppufile.getderef(cloneddefderef);
             PPULoadPlatform(ppufile);
           end
         else
           begin
             SymTable:=TRecordSymTable.create(objrealname^,0,0);
             TRecordSymTable(SymTable).fieldalignment:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).recordalignment:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).explicitrecordalignment:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).padalignment:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).usefieldalignment:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).RecordAlignMin:=shortint(ppufile.getbyte);
             TRecordSymTable(SymTable).DataSize:=ppufile.getasizeint;
             TRecordSymTable(SymTable).paddingsize:=ppufile.getword;
             ppufile.getset(TPPUSet1(TRecordSymTable(SymTable).managementoperators));
             { position of ppuload_platform call must correspond
               to position of writeentry in ppuwrite method }
             PPULoadPlatform(ppufile);
             TRecordSymTable(SymTable).ppuload(ppufile);
             { the variantrecdesc is needed only for iso-like new statements new(prec,1,2,3 ...);
               but because iso mode supports no units, there is no need to store the variantrecdesc
               in the ppu
             }
             // readvariantrecdesc(variantrecdesc);
             { requires usefieldalignment to be set }
             SymTable.defowner:=self;
           end;
         isunion:=false;
      end;


    destructor TRecordDef.Destroy;

      procedure free_variantrecdesc(var variantrecdesc : PVariantRecDesc);
        var
          i : LongInt;
        begin
         while Assigned(variantrecdesc) do
           begin
             for i:=0 to high(variantrecdesc^.branches) do
               begin
                 free_variantrecdesc(variantrecdesc^.branches[i].nestedvariant);
                 SetLength(variantrecdesc^.branches[i].values,0);
               end;
             SetLength(variantrecdesc^.branches,0);
             dispose(variantrecdesc);
             variantrecdesc:=nil;
           end;
        end;

      begin
         if Assigned(variantrecdesc) then
           free_variantrecdesc(variantrecdesc);
         if Assigned(SymTable) then
           begin
             SymTable.free;
             SymTable:=nil;
           end;
         inherited Destroy;
      end;


    function TRecordDef.getcopy : TStoredDef;
      begin
        result:=CRecordDef.create(objrealname^,SymTable.getcopy);
        TRecordDef(result).isunion:=isunion;
        include(TRecordDef(result).defoptions,df_copied_def);
        if Assigned(tcinitcode) then
          TRecordDef(result).tcinitcode:=tcinitcode.getcopy;
         if Assigned(import_lib) then
           TRecordDef(result).import_lib:=StringDup(import_lib^);
      end;


    function TRecordDef.NeedsInitTable : boolean;
      begin
        { each record with managed field or with any management operator needs
          init table }
        NeedsInitTable:=(TRecordSymTable(SymTable).managementoperators<>[]) or
          TRecordSymTable(SymTable).needs_init_final
      end;

    function TRecordDef.NeedsSeparateInitRTTI : boolean;
      begin
        result:=true;
      end;


    function TRecordDef.HasNonTrivialInitChild(check_parent:boolean):boolean;
      begin
        result:=TRecordSymTable(SymTable).has_non_trivial_init;
      end;


    procedure TRecordDef.buildderef;
      begin
         inherited buildderef;
         if df_copied_def in defoptions then
           cloneddefderef.build(SymTable.defowner)
         else
           TStoredSymTable(SymTable).buildderef;
      end;


    procedure TRecordDef.deref;
      begin
         inherited deref;
         { now dereference the definitions }
         if df_copied_def in defoptions then
           begin
             cloneddef:=TRecordDef(cloneddefderef.resolve);
             SymTable:=cloneddef.SymTable.getcopy;
           end
         else
           TStoredSymTable(SymTable).deref(false);

         { internal types, only load from the system unit }
         if Assigned(owner) and
            Assigned(owner.name) and
            (owner.name^='SYSTEM') then
           begin
             { TGUID  }
             if not Assigned(rec_tguid) and
                (upper(typename)='TGUID') then
               rec_tguid:=self
             { JMP_BUF }
             else if not Assigned(rec_jmp_buf) and
                (upper(typename)='JMP_BUF') then
               rec_jmp_buf:=self
             else if not Assigned(rec_exceptaddr) and
                (upper(typename)='TEXCEPTADDR') then
               rec_exceptaddr:=self;
           end;
      end;


    procedure TRecordDef.ppuwrite(ppufile:TCompilerPPUFile);

      procedure writevariantrecdesc(variantrecdesc : PVariantRecDesc);
        var
          i,j : LongInt;
        begin
         if Assigned(variantrecdesc) then
           begin
             ppufile.putbyte(1);
             ppufile.putderef(variantrecdesc^.variantselectorderef);
             ppufile.putasizeint(length(variantrecdesc^.branches));
             for i:=0 to high(variantrecdesc^.branches) do
               begin
                 ppufile.putasizeint(length(variantrecdesc^.branches[i].values));
                 for j:=0 to high(variantrecdesc^.branches[i].values) do
                   ppufile.putexprint(variantrecdesc^.branches[i].values[j]);
                 writevariantrecdesc(variantrecdesc^.branches[i].nestedvariant);
               end;
           end
         else
           ppufile.putbyte(0);
        end;

      begin
         inherited ppuwrite(ppufile);
         if df_copied_def in defoptions then
           ppufile.putderef(cloneddefderef)
         else
           begin
             ppufile.putbyte(byte(TRecordSymTable(SymTable).fieldalignment));
             ppufile.putbyte(byte(TRecordSymTable(SymTable).recordalignment));
             ppufile.putbyte(byte(TRecordSymTable(SymTable).explicitrecordalignment));
             ppufile.putbyte(byte(TRecordSymTable(SymTable).padalignment));
             ppufile.putbyte(byte(TRecordSymTable(SymTable).usefieldalignment));
             ppufile.putbyte(byte(TRecordSymTable(SymTable).RecordAlignMin));
             ppufile.putasizeint(TRecordSymTable(SymTable).DataSize);
             ppufile.putword(TRecordSymTable(SymTable).paddingsize);
             ppufile.putset(TPPUSet1(TRecordSymTable(SymTable).managementoperators));
             { the variantrecdesc is needed only for iso-like new statements new(prec,1,2,3 ...);
               but because iso mode supports no units, there is no need to store the variantrecdesc
               in the ppu
             }
             // writevariantrecdesc(variantrecdesc);
           end;

         writeentry(ppufile,ibrecorddef);

         if not(df_copied_def in defoptions) then
           TRecordSymTable(SymTable).ppuwrite(ppufile);
      end;


    function TRecordDef.size:asizeint;
      begin
        result:=TRecordSymTable(SymTable).DataSize;
      end;


    function TRecordDef.alignment:shortint;
      begin
        alignment:=TRecordSymTable(SymTable).recordalignment;
      end;


    function TRecordDef.padalignment:shortint;
      begin
        padalignment := TRecordSymTable(SymTable).padalignment;
      end;


    function TRecordDef.GetTypeName : string;
      begin
        if Assigned(typesym) then
          GetTypeName:='<record type '+typesymbolprettyname+'>'
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

    constructor TAbstractProcDef.create(dt:TDefTyp;level:byte;doregister:boolean);
      begin
         inherited create(dt,doregister);
         parast:=TParaSymTable.create(self,level);
         paras:=nil;
         minparacount:=0;
         maxparacount:=0;
         proctypeoption:=potype_none;
         proccalloption:=pocall_none;
         procoptions:=[];
         returndef:=voidtype;
         returndefderef.reset;
         savesize:=sizeof(PInt);
         callerargareasize:=0;
         calleeargareasize:=0;
         has_paraloc_info:=callnoside;
         funcretloc[callerside].init;
         funcretloc[calleeside].init;
         check_mark_as_nested;
      end;


    destructor TAbstractProcDef.Destroy;
      begin
         if Assigned(paras) then
           begin
{$ifdef MEMDEBUG}
             memprocpara.start;
{$endif MEMDEBUG}
             paras.free;
             paras:=nil;
{$ifdef MEMDEBUG}
             memprocpara.stop;
{$endif MEMDEBUG}
          end;
         if Assigned(parast) then
          begin
{$ifdef MEMDEBUG}
            memprocparast.start;
{$endif MEMDEBUG}
            parast.free;
            parast:=nil;
{$ifdef MEMDEBUG}
            memprocparast.stop;
{$endif MEMDEBUG}
          end;
         funcretloc[callerside].done;
         funcretloc[calleeside].done;
         inherited Destroy;
      end;


    procedure TAbstractProcDef.count_para(p:TObject;arg:pointer);
      begin
        if (TSym(p).typ<>paravarsym) then
          exit;
        inc(PLongInt(arg)^);
        if not(vo_is_hidden_para in TParaVarSym(p).varoptions) then
         begin
           if not Assigned(TParaVarSym(p).defaultconstsym) then
             inc(minparacount);
           inc(maxparacount);
         end;
      end;


    procedure TAbstractProcDef.insert_para(p:TObject;arg:pointer);
      begin
        if (TSym(p).typ<>paravarsym) then
          exit;
        paras.add(p);
      end;


    procedure TAbstractProcDef.calcparas;
      var
        paracount : LongInt;
      begin
        { This can already be assigned when
          we need to reresolve this unit (PFV) }
        if Assigned(paras) then
          paras.free;
        paras:=TParaList.create(false);
        paracount:=0;
        minparacount:=0;
        maxparacount:=0;
        parast.SymList.ForEachCall(@count_para,@paracount);
        paras.capacity:=paracount;
        { Insert parameters in table }
        parast.SymList.ForEachCall(@insert_para,nil);
        { Order parameters }
        paras.sortparas;
      end;


    function TAbstractProcDef.mangledprocparanames(oldlen : LongInt) : string;
      var
        hash  : qword;
        hp   : TParaVarSym;
        hs   : TSymStr;
        newlen,
        i    : integer;
      begin
        result:='';
        hp:=nil;
        { add parameter types }
        for i:=0 to paras.count-1 do
         begin
           hp:=TParaVarSym(paras[i]);
           if not(vo_is_hidden_para in hp.varoptions) then
             begin
               if not Assigned(hp.vardef) then
                 InternalError(2025122401);
               result:=result+'$'+hp.vardef.mangledparaname;
             end;
         end;
        { add resultdef, add $$ as separator to make it unique from a
          parameter separator }
        if not is_void(returndef) then
          result:=result+'$$'+returndef.mangledparaname;
        newlen:=length(result)+oldlen;
        { Replace with hash if the parameter line is very long }
        if (newlen-oldlen>12) and
           ((newlen>100) or (newlen-oldlen>64)) then
          begin
            hash:=InitFNV64;
            for i:=0 to paras.count-1 do
              begin
                hp:=TParaVarSym(paras[i]);
                if not(vo_is_hidden_para in hp.varoptions) then
                  begin
                    hs:=hp.vardef.mangledparaname;
                    hash:=UpdateFNV64(hash,hs[1],length(hs));
                  end;
              end;
            if not is_void(returndef) then
              begin
                { add a little prefix so that x(integer; integer) is different from x(integer):integer }
                hs:='$$'+returndef.mangledparaname;
                hash:=UpdateFNV64(hash,hs[1],length(hs));
              end;
            result:='$h'+Base64Mangle(hash);
          end;
      end;


    procedure TAbstractProcDef.buildderef;
      begin
         { released procdef? }
         if not Assigned(parast) then
           exit;
         inherited buildderef;
         returndefderef.build(returndef);
         if po_explicitparaloc in procoptions then
           funcretloc[callerside].buildderef;
         { parast }
         TParaSymTable(parast).buildderef;
      end;


    procedure TAbstractProcDef.deref;
      begin
         inherited deref;
         returndef:=TDef(returndefderef.resolve);
         if po_explicitparaloc in procoptions then
           begin
             funcretloc[callerside].deref;
             has_paraloc_info:=callerside;
            end
         else
           begin
             { deref is called after loading from a ppu, but also after another
               unit has been reloaded/recompiled and all references must be
               re-resolved. Since the funcretloc contains a reference to a tdef,
               reset it so that we won't try to access the stale def }
             funcretloc[callerside].init;
             has_paraloc_info:=callnoside;
           end;
         { parast }
         TParaSymTable(parast).deref(false);
         { recalculated parameters }
         calcparas;
      end;


    constructor TAbstractProcDef.ppuload(dt:TDefTyp;ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(dt,ppufile);
         parast:=nil;
         Paras:=nil;
         minparacount:=0;
         maxparacount:=0;
         ppufile.getderef(returndefderef);
         proctypeoption:=TProcTypeOption(ppufile.getbyte);
         proccalloption:=TProcCallOption(ppufile.getbyte);
         ppufile.getset(TPPUSet8(procoptions));

         funcretloc[callerside].init;
         if po_explicitparaloc in procoptions then
           funcretloc[callerside].ppuload(ppufile);

         savesize:=sizeof(PInt);
         if (po_explicitparaloc in procoptions) then
           has_paraloc_info:=callerside;
      end;


    procedure TAbstractProcDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         { released procdef? }
         if not Assigned(parast) then
           exit;
         inherited ppuwrite(ppufile);
         ppufile.putderef(returndefderef);
         ppufile.putbyte(ord(proctypeoption));
         ppufile.putbyte(ord(proccalloption));
         ppufile.putset(TPPUSet8(procoptions));

         if (po_explicitparaloc in procoptions) then
           funcretloc[callerside].ppuwrite(ppufile);
      end;


    function TAbstractProcDef.typename_paras(pno: TProcNameOptions) : AnsiString;
      var
        hs,s  : AnsiString;
        hp    : TParaVarSym;
        hpc   : TConstSym;
        first : boolean;
        i,j   : integer;
      begin
        s:='';
        first:=true;
        for i:=0 to paras.count-1 do
         begin
           hp:=TParaVarSym(paras[i]);
           if not(vo_is_hidden_para in hp.varoptions) or
              (pno_showhidden in pno) then
            begin
               if first then
                begin
                  s:=s+'(';
                  first:=false;
                end
               else
                s:=s+';';
               if vo_is_hidden_para in hp.varoptions then
                 s:=s+'<';
               case hp.varspez of
                 vs_var :
                   s:=s+'var ';
                 vs_const :
                   s:=s+'const ';
                 vs_out :
                   s:=s+'out ';
                 vs_constref :
                   s:=s+'constref ';
                 else
                   ;
               end;
               if (pno_paranames in pno) then
                 s:=s+hp.realname+':';
               if hp.univpara then
                 s:=s+'univ ';
               if Assigned(hp.vardef.typesym) then
                 begin
                   hs:=hp.vardef.typesym.realname;
                   if hs[1]<>'$' then
                     s:=s+hp.vardef.OwnerHierarchyName+hs
                   else
                     s:=s+hp.vardef.GetTypeName;
                 end
               else
                 s:=s+hp.vardef.GetTypeName;
               { default value }
               if Assigned(hp.defaultconstsym) then
                begin
                  hpc:=TConstSym(hp.defaultconstsym);
                  hs:='';
                  case hpc.consttyp of
                    constwresourcestring,
                    constwstring:
                      begin
                        if hpc.value.valuews.len>0 then
                          begin
                            SetLength(hs,hpc.value.valuews.len);
                            for j:=0 to hpc.value.valuews.len-1 do
                             begin
                               if (ord(hpc.value.valuews.data[j])<127) and
                                  not(byte(hpc.value.valuews.data[j]) in [0,10,13]) then
                                 hs[j+1]:=char(hpc.value.valuews.data[j])
                               else
                                 hs[j+1]:='.';
                             end;
                          end;
                      end;
                    conststring,
                    constresourcestring :
                      begin
                        if hpc.value.len>0 then
                          begin
                            SetLength(hs,hpc.value.len);
                            { don't write past the end of hs if the constant
                              is > 255 chars }
                            move(hpc.value.valueptr^,hs[1],length(hs));
                            { make sure that constant strings with newline chars
                              don't create a linebreak in the assembler code,
                              since comments are line-based. Also remove nulls
                              because the comments are written as a pchar. }
                            ReplaceCase(hs,#0,'.');
                            ReplaceCase(hs,#10,'.');
                            ReplaceCase(hs,#13,'.');
                          end;
                      end;
                    constreal :
                      hs:=RealToStr(PBestReal(hpc.value.valueptr)^);
                    constpointer :
                      hs:=ToStr(hpc.value.valueordptr);
                    constord :
                      begin
                        if is_boolean(hpc.constdef) then
                          begin
                            if hpc.value.valueord<>0 then
                             hs:='TRUE'
                            else
                             hs:='FALSE';
                          end
                        else
                          hs:=ToStr(hpc.value.valueord);
                      end;
                    constnil :
                      hs:='nil';
                    constset :
                      hs:='<set>';
                    constguid:
                      hs:=GUID2String(PGUID(hpc.value.valueptr)^);
                    constnone:
                      InternalError(2019050704);
                  end;
                  if hs<>'' then
                   s:=s+'=`'+hs+'`';
                end;
               if vo_is_hidden_para in hp.varoptions then
                 s:=s+'>';
             end;
         end;
        if not first then
         s:=s+')';
        if (po_varargs in procoptions) then
         s:=s+';VarArgs';
        typename_paras:=s;
      end;


    function TAbstractProcDef.is_methodpointer:boolean;
      begin
        result:=false;
      end;


    function TAbstractProcDef.is_addressonly:boolean;
      begin
        result:=true;
      end;

    function TAbstractProcDef.no_self_node: boolean;
      begin
        Result:=([po_staticmethod,po_classmethod]<=procoptions)or
                (proctypeoption in [potype_class_constructor,potype_class_destructor,potype_operator]);
      end;


    function TAbstractProcDef.getcopyas(newtyp:TDefTyp;copytyp:TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef;
      var
        j, nestinglevel: LongInt;
        pvs, npvs: TParaVarSym;
      begin
        nestinglevel:=parast.symtablelevel;
        if newtyp=procdef then
          begin
            if (copytyp<>pc_bareproc) then
              result:=CProcDef.create(nestinglevel,doregister)
            else
              result:=CProcDef.create(normal_function_level,doregister);
            TProcDef(result).visibility:=vis_public;
          end
        else
          begin
            result:=CProcVarDef.create(nestinglevel,true);
          end;
        TAbstractProcDef(result).returndef:=returndef;
        TAbstractProcDef(result).returndefderef:=returndefderef;
        pvs:=nil;
        npvs:=nil;
        if copytyp<>pc_normal_no_paras then
          begin
            for j:=0 to parast.symlist.count-1 do
              begin
                case TSym(parast.symlist[j]).typ of
                  paravarsym:
                    begin
                      pvs:=TParaVarSym(parast.symlist[j]);
                      { in case of bare proc, don't copy self, vmt or framepointer
                        parameters }
                      if (copytyp in [pc_bareproc,pc_normal_no_hidden]) and
                         (([vo_is_self,vo_is_vmt,vo_is_parentfp,vo_is_result,vo_is_funcret,vo_is_high_para]*pvs.varoptions)<>[]) then
                        continue;
                      if paraprefix='' then
                        npvs:=CParaVarSym.create(pvs.realname,pvs.paranr,pvs.varspez,
                          pvs.vardef,pvs.varoptions)
                      else if not(vo_is_high_para in pvs.varoptions) then
                        npvs:=CParaVarSym.create(paraprefix+pvs.realname,pvs.paranr,pvs.varspez,
                          pvs.vardef,pvs.varoptions)
                      else
                        npvs:=CParaVarSym.create('$high'+paraprefix+copy(pvs.name,5,length(pvs.name)),pvs.paranr,pvs.varspez,
                          pvs.vardef,pvs.varoptions);
                      npvs.defaultconstsym:=pvs.defaultconstsym;
                      TAbstractProcDef(result).parast.insertsym(npvs);
                    end;
                  constsym:
                    begin
                      // ignore, reuse original constym. Should also be duplicated
                      // be safe though
                    end;
                  symconst.typesym:
                    begin
                      // reuse original, part of generic declaration
                    end
                  else
                    InternalError(201160604);
                  end;
              end;
          end;
        TAbstractProcDef(result).savesize:=savesize;

        if (typ<>procvardef) and
           (newtyp=procvardef) then
          begin
            { procvars can't be (class)constructors/destructors etc }
            if proctypeoption=potype_constructor then
              begin
                TAbstractProcDef(result).returndef:=TDef(owner.defowner);
                if not(is_implicit_pointer_object_type(returndef) or
                   (returndef.typ<>objectdef)) then
                  TAbstractProcDef(result).returndef:=CPointerDef.getreusable(TAbstractProcDef(result).returndef);
                TAbstractProcDef(result).proctypeoption:=potype_function;
              end
            else if is_void(returndef) then
              TAbstractProcDef(result).proctypeoption:=potype_procedure
            else
              TAbstractProcDef(result).proctypeoption:=potype_function;
          end
        else
          TAbstractProcDef(result).proctypeoption:=proctypeoption;
        TAbstractProcDef(result).proccalloption:=proccalloption;
        TAbstractProcDef(result).procoptions:=procoptions;
        if (copytyp=pc_bareproc) then
          TAbstractProcDef(result).procoptions:=TAbstractProcDef(result).procoptions*[po_explicitparaloc,po_hascallingconvention,po_varargs,po_iocheck,po_has_importname,po_has_importdll];
        if newtyp=procvardef then
          TAbstractProcDef(result).procoptions:=TAbstractProcDef(result).procoptions-[po_has_importname,po_has_importdll];
        if copytyp=pc_address_only then
          include(TAbstractProcDef(result).procoptions,po_addressonly);

        TAbstractProcDef(result).callerargareasize:=callerargareasize;
        TAbstractProcDef(result).calleeargareasize:=calleeargareasize;
        TAbstractProcDef(result).maxparacount:=maxparacount;
        TAbstractProcDef(result).minparacount:=minparacount;
        if po_explicitparaloc in procoptions then
          TAbstractProcDef(result).funcretloc[callerside]:=funcretloc[callerside].getcopy;
        { recalculate parameter info }
        TAbstractProcDef(result).has_paraloc_info:=callnoside;
        if (typ=procdef) and
           (newtyp=procvardef) and
           (owner.symtabletype in [ObjectSymtable,recordsymtable]) then
          include(TProcVarDef(result).procoptions,po_methodpointer);
      end;


    function TAbstractProcDef.compatible_with_pointerdef_size(ptr: TPointerDef): boolean;
      begin
        result:=is_addressonly;
      end;


    procedure TAbstractProcDef.check_mark_as_nested;
      begin
         { nested procvars require that nested functions use the Delphi-style
           nested procedure calling convention }
         if (parast.symtablelevel>normal_function_level) and
            (m_nested_procvars in CurrentSettings.ModeSwitches) then
           include(procoptions,po_delphi_nested_cc);
      end;


    procedure TAbstractProcDef.init_paraloc_info(side: TCallerCallee);
      begin
        if (side in [callerside,callbothsides]) and
           not(has_paraloc_info in [callerside,callbothsides]) then
          begin
            if not is_c_variadic(self) then
              callerargareasize:=paramanager.create_paraloc_info(self,callerside)
            else
              callerargareasize:=paramanager.create_varargs_paraloc_info(self,callerside,nil);
            if has_paraloc_info in [calleeside,callbothsides] then
              has_paraloc_info:=callbothsides
            else
              has_paraloc_info:=callerside;
          end;
        if (side in [calleeside,callbothsides]) and
           not(has_paraloc_info in [calleeside,callbothsides]) then
          begin
            if not is_c_variadic(self) then
              calleeargareasize:=paramanager.create_paraloc_info(self,calleeside)
            else
              callerargareasize:=paramanager.create_varargs_paraloc_info(self,calleeside,nil);
            if has_paraloc_info in [callerside,callbothsides] then
              has_paraloc_info:=callbothsides
            else
              has_paraloc_info:=calleeside;
          end;
      end;


    procedure TAbstractProcDef.done_paraloc_info(side: TCallerCallee);
      var
        i: LongInt;
      begin
        if (side in [callerside,callbothsides]) and
           (has_paraloc_info in [callerside,callbothsides]) then
          begin
            funcretloc[callerside].done;
            for i:=0 to paras.count-1 do
              TParaVarSym(paras[i]).paraloc[callerside].done;
            if has_paraloc_info=callerside then
              has_paraloc_info:=callnoside
            else
              has_paraloc_info:=calleeside;
          end;

        if (side in [calleeside,callbothsides]) and
           (has_paraloc_info in [calleeside,callbothsides]) then
          begin
            funcretloc[calleeside].done;
            for i:=0 to paras.count-1 do
              TParaVarSym(paras[i]).paraloc[calleeside].done;
            if has_paraloc_info=calleeside then
              has_paraloc_info:=callnoside
            else
              has_paraloc_info:=callerside;
          end;
      end;


    function TAbstractProcDef.stack_tainting_parameter(side: TCallerCallee): boolean;
      var
        p: TParaVarSym;
        ploc: PCGParaLocation;
        i: LongInt;
      begin
        result:=false;
        init_paraloc_info(side);
        for i:=0 to parast.SymList.Count-1 do
          if TSym(parast.SymList[i]).typ=paravarsym then
            begin
              p:=TParaVarSym(parast.SymList[i]);
              if not p.is_used then
                continue;
              { check if no parameter is located on the stack }
              if (is_open_array(p.vardef) or
                 is_array_of_const(p.vardef)) and (p.varspez=vs_value) then
                begin
                  result:=true;
                  exit;
                end;
              ploc:=p.paraloc[side].location;
              while Assigned(ploc) do
                begin
                  if (ploc^.loc=LOC_REFERENCE) then
                    begin
                      result:=true;
                      exit
                    end;
                  ploc:=ploc^.next;
                end;
            end;
      end;

    function TAbstractProcDef.is_pushleftright: boolean;
      begin
        result:=false;
      end;

    function TAbstractProcDef.address_type: TDef;
      begin
        result:=voidcodepointertype;
      end;


    function TAbstractProcDef.ofs_address_type:TDef;
      begin
        result:=address_type;
      end;


    function TAbstractProcDef.generate_safecall_wrapper: boolean;
      begin
{$ifdef SUPPORT_SAFECALL}
        result:=
          (proccalloption=pocall_safecall) and
          not(po_assembler in procoptions) and
          (tf_safecall_exceptions in TargetInfo.flags);
{$else SUPPORT_SAFECALL}
        result:=false;
{$endif}
      end;


    function TAbstractProcDef.is_generic_param(def:TDef): boolean;
      begin
        if def.typ=undefineddef then
          result:=def.owner=self.parast
        else if def.typ=objectdef then
          result:=(def.owner=self.parast) and (TStoredDef(def).genconstraintdata<>nil)
        else
          result:=false;
      end;

    function TAbstractProcDef.wpo_may_create_instance(optionalmethodpointer: TNode): boolean;
      begin
        result:=
          (proctypeoption=potype_constructor) or
          ((typ=procdef) and
           ((not Assigned(optionalmethodpointer) and
             is_class(TDef(owner.defowner))) or
            (Assigned(optionalmethodpointer) and
             ((optionalmethodpointer.resultdef.typ=classrefdef) or
              (optionalmethodpointer.nodetype=typen)))) and
           (TProcDef(self).procsym.Name='NEWINSTANCE'))
      end;


{***************************************************************************
                                  TPROCDEF
***************************************************************************}

    function TProcDef.getparentfpsym: TSym;
      begin
        if not Assigned(_parentfpsym) then
          begin
            _parentfpsym:=TSym(parast.Find('parentfp'));
            if not Assigned(_parentfpsym) then
              InternalError(200309281);
          end;
        result:=_parentfpsym;
      end;


    function TProcDef.Getis_implemented: boolean;
      begin
        result:=not Assigned(implprocdefinfo) or implprocdefinfo^.is_implemented;
      end;


    procedure TProcDef.Setis_implemented(AValue: boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2020062101);
        implprocdefinfo^.is_implemented:=AValue;
      end;


    function TProcDef.getwas_anonymous:boolean;
      begin
        result:=Assigned(implprocdefinfo) and implprocdefinfo^.was_anonymous;
      end;


    procedure TProcDef.setwas_anonymous(avalue:boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2022020502);
        implprocdefinfo^.was_anonymous:=avalue;
      end;


    function TProcDef.gethas_capturer:boolean;
      begin
        result:=Assigned(implprocdefinfo) and implprocdefinfo^.has_capturer;
      end;


    procedure TProcDef.sethas_capturer(avalue:boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2022020503);
        implprocdefinfo^.has_capturer:=avalue;
      end;


    function TProcDef.Getcapturedsyms:TFPList;
      begin
        if not Assigned(implprocdefinfo) then
          result:=nil
        else
          result:=implprocdefinfo^.capturedsyms;
      end;


    function TProcDef.store_localst: boolean;
      begin
        result:=has_inlininginfo or (df_generic in defoptions);
      end;


    function TProcDef.GetResultName: PShortString;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010301);
        result:=implprocdefinfo^.resultname;
      end;


    procedure TProcDef.SetResultName(AValue: PShortString);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010302);
        implprocdefinfo^.resultname:=AValue;
      end;


    function TProcDef.GetParentFPInitBlock: TNode;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010303);
        result:=implprocdefinfo^.parentfpinitblock;
      end;


    function TProcDef.GetParentFPStruct: TSym;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010304);
        result:=implprocdefinfo^.parentfpstruct;
      end;


    function TProcDef.GetParentFPStructPtrType: TDef;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010305);
        result:=implprocdefinfo^.parentfpstructptrtype;
      end;


    procedure TProcDef.SetParentFPInitBlock(AValue: TNode);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010306);
        implprocdefinfo^.parentfpinitblock:=AValue;
      end;


    function TProcDef.Getprocendtai: TAI;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010307);
        result:=implprocdefinfo^.procendtai;
      end;


    function TProcDef.Getprocstarttai: TAI;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010308);
        result:=implprocdefinfo^.procstarttai;
      end;


    procedure TProcDef.Setprocendtai(AValue: TAI);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010309);
        implprocdefinfo^.procendtai:=AValue;
      end;


    function TProcDef.Getskpara: pointer;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010310);
        result:=implprocdefinfo^.skpara;
      end;


    procedure TProcDef.Setskpara(AValue: pointer);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010311);
        implprocdefinfo^.skpara:=AValue;
      end;


    function TProcDef.Getpersonality: TProcDef;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2016121704);
         result:=implprocdefinfo^.personality;
      end;


    procedure TProcDef.Setpersonality(AValue: TProcDef);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2016121705);
        implprocdefinfo^.personality:=AValue;
      end;


    function TProcDef.Getforwarddef: boolean;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010312);
        result:=implprocdefinfo^.forwarddef;
      end;


    function TProcDef.Gethasforward: boolean;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010313);
        result:=implprocdefinfo^.hasforward;
      end;


    function TProcDef.Getinterfacedef: boolean;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010314);
        result:=implprocdefinfo^.interfacedef;
      end;


    procedure TProcDef.Setforwarddef(AValue: boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010315);
        implprocdefinfo^.forwarddef:=AValue;
      end;


    procedure TProcDef.Sethasforward(AValue: boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010316);
        implprocdefinfo^.hasforward:=AValue;
      end;


    function TProcDef.GetIsEmpty: boolean;
      begin
        result:=pio_empty in implprocoptions;
      end;


    procedure TProcDef.SetIsEmpty(AValue: boolean);
      begin
        if AValue then
          include(implprocoptions,pio_empty)
        else
          exclude(implprocoptions,pio_empty);
      end;


    function TProcDef.GetHasInliningInfo: boolean;
      begin
        result:=pio_has_inlininginfo in implprocoptions;
      end;


    procedure TProcDef.SetHasInliningInfo(AValue: boolean);
      begin
        if AValue then
          include(implprocoptions,pio_has_inlininginfo)
        else
          exclude(implprocoptions,pio_has_inlininginfo);
      end;


    procedure TProcDef.Setinterfacedef(AValue: boolean);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010317);
        implprocdefinfo^.interfacedef:=AValue;
      end;


    procedure TProcDef.Setprocstarttai(AValue: TAI);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010318);
        implprocdefinfo^.procstarttai:=AValue;
      end;


    procedure TProcDef.SetParentFPStruct(AValue: TSym);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010319);
        implprocdefinfo^.parentfpstruct:=AValue;
      end;


    procedure TProcDef.SetParentFPStructPtrType(AValue: TDef);
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2014010320);
        implprocdefinfo^.parentfpstructptrtype:=AValue;
      end;


    constructor TProcDef.create(level:byte;doregister:boolean);
      begin
         inherited create(procdef,level,doregister);
         implprocdefinfo:=allocmem(sizeof(implprocdefinfo^));
         localst:=TLocalSymTable.create(self,parast.symtablelevel);
{$ifdef symansistr}
         _mangledname:='';
{$else symansistr}
         _mangledname:=nil;
{$endif symansistr}
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
         seenmarker := nil;
{$endif}
         fileinfo:=CurrentFilePos;
         extnumber:=$ffff;
         aliasnames:=TCmdStrList.create;
         funcretsym:=nil;
         funcretsymderef.reset;
         procsymderef.reset;
         forwarddef:=true;
         interfacedef:=false;
         hasforward:=false;
         struct := nil;
         structderef.reset;
         import_dll:=nil;
         import_name:=nil;
         import_nr:=0;
         inlininginfo:=nil;
         deprecatedmsg:=nil;
         genericdecltokenbuf:=nil;
         if cs_opt_fastmath in CurrentSettings.OptimizerSwitches then
           include(implprocoptions, pio_fastmath);
      end;


    constructor TProcDef.ppuload(ppufile:TCompilerPPUFile);
      var
        i,aliasnamescount,sizeleft : LongInt;
        level : byte;
        buf : array[0..255] of byte;
      begin
         inherited ppuload(procdef,ppufile);
{$ifdef symansistr}
         if po_has_mangledname in procoptions then
           _mangledname:=ppufile.getansistring
         else
           _mangledname:='';
{$else symansistr}
         if po_has_mangledname in procoptions then
          _mangledname:=ppufile.getpshortstring
         else
          _mangledname:=nil;
{$endif symansistr}
         extnumber:=ppufile.getword;
         level:=ppufile.getbyte;
         ppufile.getderef(structderef);
         ppufile.getderef(procsymderef);
         ppufile.getposinfo(fileinfo);
         visibility:=TVisibility(ppufile.getbyte);
         ppufile.getset(TPPUSet2(symoptions));
         if sp_has_deprecated_msg in symoptions then
           deprecatedmsg:=ppufile.getpshortstring
         else
           deprecatedmsg:=nil;
         { import stuff }
         if po_has_importdll in procoptions then
           import_dll:=ppufile.getpshortstring
         else
           import_dll:=nil;
         if po_has_importname in procoptions then
           import_name:=ppufile.getpshortstring
         else
           import_name:=nil;
         import_nr:=ppufile.getword;
         if (po_msgint in procoptions) then
           messageinf.i:=ppufile.getlongint;
         if (po_msgstr in procoptions) then
           messageinf.str:=ppufile.getpshortstring;
         if (po_dispid in procoptions) then
           dispid:=ppufile.getlongint;
         { inline stuff }
         ppufile.getset(TPPUSet1(implprocoptions));
         if has_inlininginfo then
           begin
             ppufile.getderef(funcretsymderef);
             new(inlininginfo);
             ppufile.getset(TPPUSet4(inlininginfo^.flags));
           end
         else
           begin
             inlininginfo:=nil;
             funcretsym:=nil;
           end;

         aliasnames:=TCmdStrList.create;
         { count alias names }
         aliasnamescount:=ppufile.getbyte;
         for i:=1 to aliasnamescount do
           aliasnames.insert(ppufile.getstring);

         { load the token stream containing the declaration }
         sizeleft:=ppufile.getlongint;
         if sizeleft>0 then
           begin
             init_genericdecl;
             while sizeleft>0 do
               begin
                 if sizeleft>sizeof(buf) then
                   i:=sizeof(buf)
                 else
                   i:=sizeleft;
                 ppufile.getdata(buf,i);
                 genericdecltokenbuf.write(buf,i);
                 dec(sizeleft,i);
               end;
           end;

         PPULoadPlatform(ppufile);

         { load para symtable }
         parast:=TParaSymTable.create(self,level);
         TParaSymTable(parast).ppuload(ppufile);
         { load local symtable }
         if store_localst then
          begin
            localst:=TLocalSymTable.create(self,level);
            TLocalSymTable(localst).ppuload(ppufile);
          end
         else
          localst:=nil;
         { inline stuff }
         if has_inlininginfo then
           inlininginfo^.code:=ppuloadnodetree(ppufile);
         { default values for no persistent data }
         if (cs_link_deffile in CurrentSettings.GlobalSwitches) and
            (tf_need_export in TargetInfo.flags) and
            (po_exports in procoptions) then
           deffile.AddExport(mangledname);
         { Disable po_has_inlining until the derefimpl is done }
         has_inlininginfo:=false;
      end;


    destructor TProcDef.Destroy;
      begin
         aliasnames.free;
         aliasnames:=nil;
         if Assigned(localst) and
           (localst.symtabletype<>staticsymtable) then
          begin
{$ifdef MEMDEBUG}
            memproclocalst.start;
{$endif MEMDEBUG}
            localst.free;
            localst:=nil;
{$ifdef MEMDEBUG}
            memproclocalst.start;
{$endif MEMDEBUG}
          end;
         if Assigned(inlininginfo) then
          begin
{$ifdef MEMDEBUG}
            memprocnodetree.start;
{$endif MEMDEBUG}
            FreeAndNil(TNode(inlininginfo^.code));
{$ifdef MEMDEBUG}
            memprocnodetree.start;
{$endif MEMDEBUG}
            dispose(inlininginfo);
            inlininginfo:=nil;
          end;
         freeimplprocdefinfo;
         genericdecltokenbuf.free;
         genericdecltokenbuf:=nil;
         StringDispose(import_dll);
         StringDispose(import_name);
         StringDispose(deprecatedmsg);
         if (po_msgstr in procoptions) then
           StringDispose(messageinf.str);
{$ifndef symansistr}
         if Assigned(_mangledname) then
          begin
{$ifdef MEMDEBUG}
            memmanglednames.start;
{$endif MEMDEBUG}
            StringDispose(_mangledname);
{$ifdef MEMDEBUG}
            memmanglednames.stop;
{$endif MEMDEBUG}
          end;
{$endif symansistr}
         inherited Destroy;
      end;


    procedure TProcDef.freeimplprocdefinfo;
      begin
        if Assigned(implprocdefinfo) then
          begin
            StringDispose(implprocdefinfo^.resultname);
            TFPList.FreeAndNilDisposing(implprocdefinfo^.capturedsyms,typeinfo(TCapturedSymInfo));
            FreeMem(implprocdefinfo);
            implprocdefinfo:=nil;
          end;
      end;


    procedure TProcDef.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldcrc : boolean;
        aliasnamescount,i,sizeleft : LongInt;
        item : TCmdStrListItem;
        buf : array[0..255] of byte;
      begin
         { released procdef? }
         if not Assigned(parast) then
           exit;

         inherited ppuwrite(ppufile);
{$ifdef symansistr}
         if po_has_mangledname in procoptions then
           ppufile.putansistring(_mangledname);
{$else symansistr}
         if po_has_mangledname in procoptions then
          ppufile.putstring(_mangledname^);
{$endif symansistr}

         ppufile.putword(extnumber);
         ppufile.putbyte(parast.symtablelevel);
         ppufile.putderef(structderef);
         ppufile.putderef(procsymderef);
         ppufile.putposinfo(fileinfo);
         ppufile.putbyte(byte(visibility));
         ppufile.putset(TPPUSet2(symoptions));
         if sp_has_deprecated_msg in symoptions then
           ppufile.putstring(deprecatedmsg^);
         { import }
         if po_has_importdll in procoptions then
           ppufile.putstring(import_dll^);
         if po_has_importname in procoptions then
           ppufile.putstring(import_name^);
         ppufile.putword(import_nr);
         if (po_msgint in procoptions) then
           ppufile.putlongint(messageinf.i);
         if (po_msgstr in procoptions) then
           ppufile.putstring(messageinf.str^);
         if (po_dispid in procoptions) then
           ppufile.putlongint(dispid);
         { inline stuff }
         oldcrc:=ppufile.DoCRC;
         ppufile.DoCRC:=false;
         ppufile.putset(TPPUSet1(implprocoptions));
         if has_inlininginfo then
           begin
             ppufile.putderef(funcretsymderef);
             ppufile.putset(TPPUSet4(inlininginfo^.flags));
           end;

         { count alias names }
         aliasnamescount:=0;
         item:=TCmdStrListItem(aliasnames.first);
         while Assigned(item) do
           begin
             inc(aliasnamescount);
             item:=TCmdStrListItem(item.next);
           end;
         if aliasnamescount>255 then
           InternalError(200711021);
         ppufile.putbyte(aliasnamescount);
         item:=TCmdStrListItem(aliasnames.first);
         while Assigned(item) do
          begin
            ppufile.putstring(item.str);
            item:=TCmdStrListItem(item.next);
          end;

         ppufile.DoCRC:=oldcrc;

         { generic tokens for the declaration }
         if Assigned(genericdecltokenbuf) and (genericdecltokenbuf.size>0) then
           begin
             sizeleft:=genericdecltokenbuf.size;
             genericdecltokenbuf.seek(0);
             ppufile.putlongint(sizeleft);
             while sizeleft>0 do
               begin
                 if sizeleft>sizeof(buf) then
                   i:=sizeof(buf)
                 else
                   i:=sizeleft;
                 genericdecltokenbuf.read(buf,i);
                 ppufile.putdata(buf,i);
                 dec(sizeleft,i);
               end;
           end
         else
           ppufile.putlongint(0);

         { write this entry }
         writeentry(ppufile,ibprocdef);

         { Save the para symtable, this is taken from the interface }
         TParaSymTable(parast).ppuwrite(ppufile);

         { save localsymtable for inline procedures or when local
           browser info is requested, this has no influence on the crc }
         if store_localst and not ppufile.crc_only then
          begin
            oldcrc:=ppufile.DoCRC;
            ppufile.DoCRC:=false;
            TLocalSymTable(localst).ppuwrite(ppufile);
            ppufile.DoCRC:=oldcrc;
          end;

         { node tree for inlining }

         if has_inlininginfo then
           ppuwritenodetree(ppufile,inlininginfo^.code);
      end;


    function TProcDef.fullprocname(showhidden:boolean):AnsiString;
      var
        pno: TProcNameOptions;
      begin
        pno:=[];
        if showhidden then
          include(pno,pno_showhidden);
        result:=customprocname(pno);
      end;


    function TProcDef.customprocname(pno: TProcNameOptions):AnsiString;
      var
        s, hs, rn : AnsiString;
        t : TToken;
	module : TModule;
        syssym : TSysSym;
      begin
{$ifdef EXTDEBUG}
        include(pno,pno_showhidden);
{$endif EXTDEBUG}
        s:='';
        rn:='';
        if proctypeoption=potype_operator then
          begin
            for t:=NOTOKEN to last_overloaded do
              if procsym.realname='$'+overloaded_names[t] then
                begin
                  s:='operator ';
                  if (pno_ownername in pno) and
                     Assigned(struct) then
                    s:=s+struct.RttiName+'.';
                  s:=s+arraytokeninfo[t].str;
                  if not (pno_noparams in pno) then
                    s:=s+typename_paras(pno);
                  break;
                end;
          end
        else
          begin
            if (po_classmethod in procoptions) and
               not(pno_noclassmarker in pno) then
              s:='class ';
            case proctypeoption of
              potype_constructor,
              potype_class_constructor:
                s:=s+'constructor ';
              potype_class_destructor,
              potype_destructor:
                s:=s+'destructor ';
              else
                if (pno_proctypeoption in pno) and not (po_anonymous in procoptions) then
                  begin
                   if Assigned(returndef) and
                     not(is_void(returndef)) then
                     s:=s+'function '
                   else
                     s:=s+'procedure ';
                  end;
            end;
            if (pno_ownername in pno) and
               (owner.symtabletype in [recordsymtable,objectsymtable]) then
              s:=s+TAbstractRecordDef(owner.defowner).RttiName+'.';
            if (po_compilerproc in procoptions) and (extnumber<>$ffff) then
              begin
                syssym:=TSysSym.find_by_number(extnumber);
                if not Assigned(syssym) then
                  InternalError(2016060305);
                rn:=syssym.realname;
              end
            else if po_anonymous in procoptions then
              begin
                s:=s+'anonymous ';
                if Assigned(returndef) and
                  not(is_void(returndef)) then
                  s:=s+'function'
                else
                  s:=s+'procedure';
              end
            else if pno_prettynames in pno then
              rn:=procsym.prettyname
            else
              rn:=procsym.RealName;
            if (pno_noleadingdollar in pno) and
               (rn[1]='$') then
              delete(rn,1,1);
            s:=s+rn;
            if not (pno_noparams in pno) then
              s:=s+typename_paras(pno);
          end;
        if not(proctypeoption in [potype_constructor,potype_destructor,
             potype_class_constructor,potype_class_destructor]) and
           Assigned(returndef) and
           not(is_void(returndef)) then
          begin
            if Assigned(returndef.typesym) then
              begin
                module:=find_module_from_symtable(returndef.typesym.owner);
		if module <> CurrentModule then
                  s:=s+':'+module.RealModuleName^+'.'
                else
	          s:=s+':';
                if pno_prettynames in pno then
                  hs:=returndef.typesym.prettyname
                else
                  hs:=returndef.typesym.realname;
                if hs[1]<>'$' then
                  s:=s+returndef.OwnerHierarchyName+hs
                else
                  s:=s+returndef.GetTypeName;
              end
            else
              s:=s+':'+returndef.GetTypeName;
	  end;
        if not (po_anonymous in procoptions) then
          if Assigned(owner) and (owner.symtabletype=localsymtable) then
            s:=s+' is nested'
          else if po_is_block in procoptions then
            s:=s+' is block';
        s:=s+';';
        { forced calling convention? }
        if (po_hascallingconvention in procoptions) then
          s:=s+' '+ProcCallOptionStr[proccalloption]+';';
        if (po_staticmethod in procoptions) and
           not (proctypeoption in [potype_class_constructor,potype_class_destructor]) then
          s:=s+' Static;';
        if pno_mangledname in pno then
          s:=s+' -- mangled name: '+mangledname;
        customprocname:=s;
      end;


    function TProcDef.is_methodpointer:boolean;
      begin
        { don't check assigned(_class), that's also the case for nested
          procedures inside methods }
        result:=(owner.symtabletype in [recordsymtable,ObjectSymtable]) and not no_self_node;
      end;


    function TProcDef.is_addressonly:boolean;
      begin
        result:=Assigned(owner) and
                not is_methodpointer and
                (not(m_nested_procvars in CurrentSettings.ModeSwitches) or
                 not is_nested_pd(self)) and
                 (
                   not (po_anonymous in procoptions) or
                   not Assigned(capturedsyms) or
                   (capturedsyms.count=0)
                 );
      end;


    procedure TProcDef.make_external;
      begin
        include(procoptions,po_external);
        forwarddef:=false;
      end;


    procedure TProcDef.init_genericdecl;
      begin
        if Assigned(genericdecltokenbuf) then
          InternalError(2015061901);
        genericdecltokenbuf:=TDynamicArray.create(256);
      end;


    procedure TProcDef.reset_after_conv;
      begin
        _parentfpsym:=nil;
      end;


    function TProcDef.get_funcretsym_info(out ressym: TSym; out resdef: TDef): boolean;
      begin
        result:=false;
        if proctypeoption=potype_constructor then
          begin
            result:=true;
            ressym:=TSym(parast.Find('self'));
            resdef:=TAbstractNormalVarSym(ressym).vardef;
            { and TP-style constructors return a pointer to self }
            if is_object(resdef) then
              resdef:=CPointerDef.getreusable(resdef);
          end
        else if (proccalloption=pocall_safecall) and
           (tf_safecall_exceptions in TargetInfo.flags) then
          begin
            result:=true;
            ressym:=TSym(localst.Find('safecallresult'));
            resdef:=TAbstractNormalVarSym(ressym).vardef;
          end
        else if not is_void(returndef) then
          begin
            result:=true;
            ressym:=funcretsym;
            resdef:=TAbstractNormalVarSym(ressym).vardef;
          end;
      end;


    function TProcDef.get_safecall_funcretsym_info(out ressym: TSym; out resdef: TDef): boolean;
      begin
        result:=false;
        if (proctypeoption<>potype_constructor) and
           (proccalloption=pocall_safecall) and
           (tf_safecall_exceptions in TargetInfo.flags) then
          begin
            result:=true;
            ressym:=TSym(localst.Find('safecallresult'));
            resdef:=TAbstractNormalVarSym(ressym).vardef;
          end
      end;


    procedure TProcDef.add_captured_sym(sym:TSym;def:TDef;const filepos:TFilePosInfo);
      var
        i : LongInt;
        capturedsym : PCapturedSymInfo;
      begin
        if not Assigned(implprocdefinfo) then
          InternalError(2021052601);
        if not Assigned(implprocdefinfo^.capturedsyms) then
          implprocdefinfo^.capturedsyms:=TFPList.create;
        for i:=0 to implprocdefinfo^.capturedsyms.count-1 do
          begin
            capturedsym:=PCapturedSymInfo(implprocdefinfo^.capturedsyms[i]);
            if (capturedsym^.sym=sym) and (capturedsym^.def=def) then
              exit;
          end;
        new(capturedsym);
        capturedsym^.sym:=sym;
        capturedsym^.def:=def;
        capturedsym^.fileinfo:=filepos;
        implprocdefinfo^.capturedsyms.add(capturedsym);
      end;


    function TProcDef.has_alias_name(const s: TSymStr): boolean;
      var
        item : TCmdStrListItem;
      begin
        result:=true;
        if mangledname=s then
          exit;
        item:=TCmdStrListItem(aliasnames.first);
        while Assigned(item) do
          begin
            if item.str=s then
              exit;
            item:=TCmdStrListItem(item.next);
          end;
        result:=false;
      end;


    function TProcDef.GetSymtable(t:TGetSymTable):TSymTable;
      begin
        case t of
          gs_local :
            GetSymtable:=localst;
          gs_para :
            GetSymtable:=parast;
          else
            GetSymtable:=nil;
        end;
      end;


    function TProcDef.getcopyas(newtyp: TDefTyp; copytyp: TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef;
      var
        j : LongInt;
      begin
        result:=inherited;
        if newtyp=procvardef then
          begin
            { create new paralist }
            TProcVarDef(result).calcparas;
            exit;
          end;
        { don't copy mangled name, can be different }
        TProcDef(result).messageinf:=messageinf;
        TProcDef(result).dispid:=dispid;
        if po_msgstr in procoptions then
          TProcDef(result).messageinf.str:=StringDup(messageinf.str^);
        TProcDef(result).symoptions:=symoptions;
        if Assigned(deprecatedmsg) then
          TProcDef(result).deprecatedmsg:=StringDup(deprecatedmsg^);
        { will have to be associated with appropriate procsym }
        TProcDef(result).procsym:=nil;
        { don't create aliases for bare copies, nor copy the funcretsym as
          the function result parameter will be inserted again if necessary
          (e.g. if the calling convention is changed) }
        if not(copytyp in [pc_bareproc,pc_normal_no_hidden]) then
          begin
            TProcDef(result).aliasnames.ConcatListCopy(aliasnames);
            if Assigned(funcretsym) then
              begin
                if funcretsym.owner=parast then
                  begin
                    j:=parast.symlist.indexof(funcretsym);
                    if j<0 then
                      InternalError(2011040606);
                    TProcDef(result).funcretsym:=TSym(TProcDef(result).parast.symlist[j]);
                  end
                else if funcretsym.owner=localst then
                  begin
                    { nothing to do, will be inserted for the new procdef while
                      parsing its body (by pdecsub.insert_funcret_local) }
                  end
                else
                  InternalError(2011040605);
              end;
          end;
        { will have to be associated with a new struct }
        TProcDef(result).struct:=nil;
        if Assigned(implprocdefinfo) then
          begin
            if Assigned(resultname) then
              TProcDef(result).resultname:=StringDup(resultname^);
            TProcDef(result).synthetickind:=synthetickind;
          end;
        if Assigned(import_dll) then
          TProcDef(result).import_dll:=StringDup(import_dll^);
        if Assigned(import_name) then
          TProcDef(result).import_name:=StringDup(import_name^);
        TProcDef(result).import_nr:=import_nr;
        TProcDef(result).extnumber:=$ffff;
        TProcDef(result).visibility:=visibility;
        { we need a separate implementation for the copied def }
        TProcDef(result).forwarddef:=true;
        TProcDef(result).interfacedef:=true;

        { create new paralist }
        TProcDef(result).calcparas;
      end;


    function TProcDef.getcopy: TStoredDef;
      begin
        result:=getcopyas(procdef,pc_normal,'',true);
      end;


    procedure TProcDef.buildderef;
      begin
         inherited buildderef;
         structderef.build(struct);
         { procsym that originally defined this definition, should be in the
           same symtable }
         procsymderef.build(procsym);
      end;


    procedure TProcDef.buildderefimpl;
      begin
         inherited buildderefimpl;

         { Localst is not available for main/unit init }
         if store_localst and Assigned(localst) then
           begin
             TLocalSymTable(localst).buildderef;
             TLocalSymTable(localst).buildderefimpl;
           end;

         { inline tree }
         if has_inlininginfo then
           begin
             funcretsymderef.build(funcretsym);
             inlininginfo^.code.buildderefimpl;
           end;
      end;


    procedure TProcDef.deref;
      begin
         inherited deref;
         struct:=TAbstractRecordDef(structderef.resolve);
         { procsym that originally defined this definition, should be in the
           same symtable }
         procsym:=TProcSym(procsymderef.resolve);
      end;


    procedure TProcDef.derefimpl;
      begin
         { Enable has_inlininginfo when the inlininginfo
           structure is available. The has_inlininginfo was disabled
           after the load, since the data was invalid }
         if Assigned(inlininginfo) then
           has_inlininginfo:=true;

         { Locals }
         if store_localst and Assigned(localst) then
           begin
             TLocalSymTable(localst).deref(false);
             TLocalSymTable(localst).derefimpl(false);
           end;

        { Inline }
        if has_inlininginfo then
          begin
            inlininginfo^.code.derefimpl;
            { funcretsym, this is always located in the localst }
            funcretsym:=TSym(funcretsymderef.resolve);
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
         GetTypeName := FullProcName(false);
      end;


    function TProcDef.mangledname : TSymStr;
      begin
{$ifdef symansistr}
        if _mangledname='' then
          begin
            result:=defaultmangledname;
            _mangledname:=result;
          end
        else
          result:=_mangledname;
{$else symansistr}
        if not Assigned(_mangledname) then
          begin
            result:=defaultmangledname;
            _mangledname:=StringDup(mangledname);
          end
        else
          result:=_mangledname^;
{$endif symansistr}
      end;


    function TProcDef.defaultmangledname: TSymStr;
      var
        n : TSymStr;
      begin
        n:=procsym.name;
        { make sure that the mangled names of these overloadable methods types is
          unique even if it's made lowercase (e.g. for section names) }
        if proctypeoption in [potype_operator,potype_class_constructor,potype_class_destructor] then
          n:='$'+n;
        { we need to use the symtable where the procsym is inserted,
          because that is visible to the world }
        defaultmangledname:=make_mangledname('',procsym.owner,n);
        defaultmangledname:=defaultmangledname+mangledprocparanames(Length(defaultmangledname))
      end;


    function TProcDef.cplusplusmangledname : TSymStr;

      function getcppparaname(p : TDef) : TSymStr;

        const
{$ifdef NAMEMANGLING_GCC2}
           ordtype2str : array[TOrdType] of string[2] = (
             '',
             'Uc','Us','Ui','Us','',
             'Sc','s','i','x','',
             'b','b','b','b','b','b',
             'c','w','x');
{$else NAMEMANGLING_GCC2}
           ordtype2str : array[TOrdType] of string[1] = (
             'v',
             'h','t','j','y','',
             'a','s','i','x','',
             'b','b','b','b','b',
             'b','b','b','b',
             'c','w','x','C');

           floattype2str : array[TFloatType] of string[1] = (
             'f','d','e','e',
             'd','d');
{$endif NAMEMANGLING_GCC2}

        var
           s : TSymStr;

        begin
           case p.typ of
              orddef:
                begin
                  s:=ordtype2str[TOrdDef(p).ordtype];
                  if s='C' then
                    s:=ordtype2str[range_to_basetype(TOrdDef(p).low,TOrdDef(p).high)];
                end;
              pointerdef:
                s:='P'+getcppparaname(TPointerDef(p).pointeddef);
{$ifndef NAMEMANGLING_GCC2}
              floatdef:
                s:=floattype2str[TFloatDef(p).floattype];
{$endif NAMEMANGLING_GCC2}
              else
                InternalError(2103001);
           end;
           getcppparaname:=s;
        end;

      var
         s,s2 : TSymStr;
         hp   : TParaVarSym;
         i    : integer;

      begin
{$ifdef NAMEMANGLING_GCC2}

        { outdated gcc 2.x name mangling scheme }
         s := procsym.realname;
         if procsym.owner.symtabletype=ObjectSymtable then
           begin
              s2:=upper(TObjectDef(procsym.owner.defowner).objrealname^);
              case proctypeoption of
                 potype_destructor:
                   s:='_$_'+ToStr(length(s2))+s2;
                 potype_constructor:
                   s:='___'+ToStr(length(s2))+s2;
                 else
                   s:='_'+s+'__'+ToStr(length(s2))+s2;
              end;

           end
         else s:=s+'__';

         s:=s+'F';

         { concat modifiers }
         { !!!!! }

         { now we handle the parameters }
         if maxparacount>0 then
           begin
             for i:=0 to paras.count-1 do
               begin
                 hp:=TParaVarSym(paras[i]);
                 { no hidden parameters form part of a C++ mangled name:
                     a) self is not included
                     b) there are no "high" or other hidden parameters
                 }
                 if vo_is_hidden_para in hp.varoptions then
                   continue;
                 s2:=getcppparaname(hp.vardef);
                 if hp.varspez in [vs_var,vs_out] then
                   s2:='R'+s2;
                 s:=s+s2;
               end;
           end
         else
           s:=s+'v';
         cplusplusmangledname:=s;
{$else NAMEMANGLING_GCC2}

         { gcc 3.x and 4.x name mangling scheme }
         { see http://www.codesourcery.com/public/cxx-abi/abi.html#mangling }
         if procsym.owner.symtabletype=ObjectSymtable then
           begin
             s:='_ZN';

             s2:=TObjectDef(procsym.owner.defowner).objextname^;
             s:=s+ToStr(length(s2))+s2;
             case proctypeoption of
                potype_constructor:
                  s:=s+'C1';
                potype_destructor:
                  s:=s+'D1';
                else
                  s:=s+ToStr(length(procsym.realname))+procsym.realname;
             end;

             s:=s+'E';
           end
         else
           s:=procsym.realname;

         { now we handle the parameters }
         if maxparacount>0 then
           begin
             for i:=0 to paras.count-1 do
               begin
                 hp:=TParaVarSym(paras[i]);
                 { no hidden parameters form part of a C++ mangled name:
                     a) self is not included
                     b) there are no "high" or other hidden parameters
                 }
                 if vo_is_hidden_para in hp.varoptions then
                   continue;
                 s2:=getcppparaname(hp.vardef);
                 if hp.varspez in [vs_var,vs_out] then
                   s2:='R'+s2;
                 s:=s+s2;
               end;
           end
         else
           s:=s+'v';
         cplusplusmangledname:=s;
{$endif NAMEMANGLING_GCC2}
      end;


    function  TProcDef.objcmangledname : TSymStr;
      var
        manglednamelen: LongInt;
        iscatmethod   : boolean;
      begin
        if not (po_msgstr in procoptions) then
          InternalError(2009030901);
        { we may very well need longer strings to handle these... }
        manglednamelen:=length(TObjectDef(procsym.owner.defowner).objextname^)+
          length('+"[ ]"')+length(messageinf.str^);
        iscatmethod:=oo_is_classhelper in TObjectDef(procsym.owner.defowner).objectoptions;
        if (iscatmethod) then
          inc(manglednamelen,length(TObjectDef(procsym.owner.defowner).childof.objextname^)+length('()'));
        if manglednamelen>255 then
          Message1(parser_e_objc_message_name_too_long,messageinf.str^);
        if not(po_classmethod in procoptions) then
          result:='"-['
        else
          result:='"+[';
        { quotes are necessary because the +/- otherwise confuse the assembler
          into expecting a number
        }
        if iscatmethod then
          result:=result+TObjectDef(procsym.owner.defowner).childof.objextname^+'(';
        result:=result+TObjectDef(procsym.owner.defowner).objextname^;
        if iscatmethod then
          result:=result+')';
        result:=result+' '+messageinf.str^+']"';
      end;


    procedure TProcDef.setmangledname(const s : TSymStr);
      begin
        { This is not allowed anymore, the forward declaration
          already needs to create the correct mangledname, no changes
          afterwards are allowed (PFV) }
        { Exception: interface definitions in mode macpas, since in that }
        {   case no reference to the old name can exist yet (JM)         }
{$ifdef symansistr}
        if _mangledname<>'' then
          if ((m_mac in CurrentSettings.ModeSwitches) and
              (interfacedef)) then
            _mangledname:=''
          else
            InternalError(200411171);
{$else symansistr}
        if Assigned(_mangledname) then
          if ((m_mac in CurrentSettings.ModeSwitches) and
              (interfacedef)) then
            StringDispose(_mangledname)
          else
            InternalError(200411171);
{$endif symansistr}
  {$ifdef symansistr}
        _mangledname:=s;
  {$else symansistr}
        _mangledname:=StringDup(s);
  {$endif symansistr}
        include(procoptions,po_has_mangledname);
      end;

    function TProcDef.needsglobalasmsym: boolean;
      begin
        result:=
          { smart linking using a library requires to promote
            all non-nested procedures to AB_GLOBAL
            otherwise you get undefined symbol error at linking
            for msdos  target with -CX option for instance }
          (create_smartlink_library and not is_nested_pd(self)) or
          (po_global in procoptions);
    end;


    procedure TProcDef.setcompilerprocname;
      begin
        procsym.realname:='$'+lower(procsym.name);
      end;


{***************************************************************************
                                 TPROCVARDEF
***************************************************************************}

    constructor TProcVarDef.create(level:byte;doregister:boolean);
      begin
         inherited create(procvardef,level,doregister);
      end;


    class function TProcVarDef.getreusableprocaddr(def: TAbstractProcDef; copytyp: TCacheableProcCopyType): TProcVarDef;
      var
        res: PHashSetItem;
        OldSymTableStack: TSymTableStack;
        key: packed record
          def: TAbstractProcDef;
          copytyp: TCacheableProcCopyType;
        end;

      begin
        if not Assigned(CurrentModule) then
          InternalError(2011081302);
        key.def:=def;
        key.copytyp:=copytyp;
        res:=CurrentModule.procaddrdefs.FindOrAdd(@key,sizeof(key));
        if not Assigned(res^.Data) then
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
            result:=TProcVarDef(def.getcopyas(procvardef,copytyp,'',true));
            SetupReusableDef(def,result,res,OldSymTableStack);
            { res^.Data may still be nil -> don't overwrite result }
            exit;
          end;
        result:=TProcVarDef(res^.Data);
      end;


    class function TProcVarDef.getreusableprocaddr_no_free(def: TAbstractProcDef): TProcVarDef;
      begin
        result:=getreusableprocaddr(def,pc_address_only);
        if not result.IsRegistered then
          include(result.defoptions,df_not_registered_no_free);
      end;


    constructor TProcVarDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(procvardef,ppufile);
         { load para symtable }
         parast:=TParaSymTable.create(self,ppufile.getbyte);
         PPULoadPlatform(ppufile);
         TParaSymTable(parast).ppuload(ppufile);
      end;


    function TProcVarDef.getcopy : TStoredDef;
      var
        i : TCallerCallee;
        j : LongInt;
      begin
        result:=CProcVarDef.create(parast.symtablelevel,true);
        TProcVarDef(result).returndef:=returndef;
        TProcVarDef(result).returndefderef:=returndefderef;
        TProcVarDef(result).parast:=parast.getcopy;
        TProcVarDef(result).savesize:=savesize;

        { create paralist copy }
        calcparas;
        TProcVarDef(result).paras:=TParaList.create(false);
        TProcVarDef(result).paras.count:=paras.count;
        for j:=0 to paras.count-1 do
          TProcVarDef(result).paras[j]:=paras[j];

        TProcVarDef(result).proctypeoption:=proctypeoption;
        TProcVarDef(result).proccalloption:=proccalloption;
        TProcVarDef(result).procoptions:=procoptions;
        TProcVarDef(result).callerargareasize:=callerargareasize;
        TProcVarDef(result).calleeargareasize:=calleeargareasize;
        TProcVarDef(result).maxparacount:=maxparacount;
        TProcVarDef(result).minparacount:=minparacount;
        for i:=low(funcretloc) to high(funcretloc) do
          TProcVarDef(result).funcretloc[i]:=funcretloc[i].getcopy;
        TProcVarDef(result).has_paraloc_info:=has_paraloc_info;
      end;


    procedure TProcVarDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);

        { Save the para symtable level (necessary to distinguish nested
          procvars) }
        ppufile.putbyte(parast.symtablelevel);

        { Write this entry }
        writeentry(ppufile,ibprocvardef);

        { Save the para symtable, this is taken from the interface }
        TParaSymTable(parast).ppuwrite(ppufile);
      end;


    function TProcVarDef.GetSymtable(t:TGetSymTable):TSymTable;
      begin
        case t of
          gs_para :
            GetSymtable:=parast;
          else
            GetSymtable:=nil;
        end;
      end;


    function TProcVarDef.size : asizeint;
      begin
         { we return false for is_addressonly for a block (because it's not a
           simple pointer to a function), but they are handled as implicit
           pointers to a datastructure that contains everything ->
           voidpointertype.size instead of voidcodepointertype.size }
         if po_is_block in procoptions then
           size:=voidpointertype.size
         else if not is_addressonly then
           begin
             if is_nested_pd(self) then
               size:=voidcodepointertype.size+parentfpvoidpointertype.size
             else
               size:=voidcodepointertype.size+voidpointertype.size;
           end
         else
           size:=voidcodepointertype.size;
      end;


    function TProcVarDef.is_methodpointer:boolean;
      begin
        result:=(po_methodpointer in procoptions);
      end;


    function TProcVarDef.is_addressonly:boolean;
      begin
        result:=((not(po_methodpointer in procoptions) or (po_staticmethod in procoptions)) and
                 not(po_is_block in procoptions) and
                 not is_nested_pd(self)) or
                (po_addressonly in procoptions);
      end;


    function TProcVarDef.getmangledparaname:TSymStr;
      begin
        if not(po_methodpointer in procoptions) then
          if not is_nested_pd(self) then
            result:='procvar'
          else
            { we need the manglednames here, because nestedprocvars can be anonymous, e.g.
              having not a type name or not an unique one, see tbs/tw27515.pas

              Further, use $_ ... _$ delimiters to avoid ambiguous names, see tbs/tw27515.pas }
            result:='$_nestedprovar'+mangledprocparanames(0)+'_$'
        else
          result:='procvarofobj'
      end;


    function TProcVarDef.getcopyas(newtyp: TDefTyp; copytyp: TProcCopyTyp; const paraprefix: string;doregister:boolean): TStoredDef;
      begin
        result:=inherited;
        TAbstractProcDef(result).calcparas;
      end;


    function TProcVarDef.IsPublishable : TPublishProperty;
      begin
         if po_methodpointer in procoptions then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TProcVarDef.GetTypeName : string;
      var
        s: string;
        pno : TProcNameOptions;
      begin
{$ifdef EXTDEBUG}
         pno:=[pno_showhidden];
{$else EXTDEBUG}
         pno:=[];
{$endif EXTDEBUG}
         s:='<';
         if po_is_block in procoptions then
           s := s+'reference to'
         else if po_classmethod in procoptions then
           s := s+'class method type of'
         else
           if po_addressonly in procoptions then
             s := s+'address of'
           else
             s := s+'procedure variable type of';
         if Assigned(returndef) and
            (returndef<>voidtype) then
           s:=s+' function'+typename_paras(pno)+':'+returndef.GetTypeName
         else
           s:=s+' procedure'+typename_paras(pno);
         if po_methodpointer in procoptions then
           s := s+' of object';
         if is_nested_pd(self) then
           s := s+' is nested';
         GetTypeName := s+';'+ProcCallOptionStr[proccalloption]+'>';
      end;


{***************************************************************************
                              TOBJECTDEF
***************************************************************************}

   constructor TObjectDef.create(ot:TObjectTyp;const n:string;c:TObjectDef;doregister:boolean);
     begin
        inherited create(n,objectdef,doregister);
        fcurrent_dispid:=0;
        objecttype:=ot;
        childof:=nil;
        childofderef.reset;
        vmt_fieldderef.reset;
        hiddenclassdefref.reset;

        extendeddefderef.reset;
        cloneddefderef.reset;
        if objecttype=odt_helper then
          owner.includeoption(sto_has_helper);
        SymTable:=TObjectSymTable.create(self,n,CurrentSettings.PackRecords,
          CurrentSettings.alignment.RecordAlignMin);
        { create space for vmt !! }
        vmtentries:=TFPList.Create;
        set_parent(c);
        if objecttype in [odt_interfacecorba,odt_interfacecom,odt_dispinterface] then
          prepareguid;
        { setup implemented interfaces }
        if objecttype in [odt_class,odt_objcclass,odt_objcprotocol,odt_objccategory,odt_javaclass,odt_interfacejava] then
          ImplementedInterfaces:=TFPObjectList.Create(true)
        else
          ImplementedInterfaces:=nil;
        writing_class_record_dbginfo:=false;
     end;


    constructor TObjectDef.ppuload(ppufile:TCompilerPPUFile);
      var
         i,
         implintfcount : LongInt;
         d, getterd : TDeref;
         ImplIntf : TImplementedInterface;
         vmtentry : PVMTEntry;
      begin
         inherited ppuload(objectdef,ppufile);
         objecttype:=TObjectTyp(ppufile.getbyte);
         helpertype:=THelperType(ppufile.getbyte);
         objextname:=ppufile.getpshortstring;
         { only used for external Objective-C classes/protocols }
         if (objextname^='') then
           StringDispose(objextname);
         SymTable:=TObjectSymTable.create(self,objrealname^,0,0);
         TObjectSymTable(SymTable).DataSize:=ppufile.getasizeint;
         TObjectSymTable(SymTable).paddingsize:=ppufile.getword;
         TObjectSymTable(SymTable).fieldalignment:=shortint(ppufile.getbyte);
         TObjectSymTable(SymTable).recordalignment:=shortint(ppufile.getbyte);
         TObjectSymTable(SymTable).RecordAlignMin:=shortint(ppufile.getbyte);
         ppufile.getderef(vmt_fieldderef);
         ppufile.getderef(childofderef);

         { load guid }
         iidstr:=nil;
         if objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           begin
              new(iidguid);
              ppufile.getguid(iidguid^);
              iidstr:=ppufile.getpshortstring;
           end;
         abstractcnt:=ppufile.getlongint;

         if objecttype=odt_helper then
           ppufile.getderef(extendeddefderef);

         vmtentries:=TFPList.Create;
         vmtentries.count:=ppufile.getlongint;
         for i:=0 to vmtentries.count-1 do
           begin
             ppufile.getderef(d);
             new(vmtentry);
             vmtentry^.procdef:=nil;
             vmtentry^.procdefderef:=d;
             vmtentry^.visibility:=TVisibility(ppufile.getbyte);
             vmtentries[i]:=vmtentry;
           end;

         { load implemented interfaces }
         if objecttype in [odt_class,odt_objcclass,odt_objcprotocol,odt_objccategory,odt_javaclass,odt_interfacejava] then
           begin
             ImplementedInterfaces:=TFPObjectList.Create(true);
             implintfcount:=ppufile.getlongint;
             for i:=0 to implintfcount-1 do
               begin
                 ppufile.getderef(d);
                 ppufile.getderef(getterd);
                 ImplIntf:=TImplementedInterface.Create_deref(d,getterd);
                 ImplIntf.IOffset:=ppufile.getlongint;
                 byte(ImplIntf.IType):=ppufile.getbyte;
                 ImplementedInterfaces.Add(ImplIntf);
               end;
           end
         else
           ImplementedInterfaces:=nil;

         if df_copied_def in defoptions then
           begin
             ppufile.getderef(cloneddefderef);
             PPULoadPlatform(ppufile);
           end
         else
           begin
             PPULoadPlatform(ppufile);
             TObjectSymTable(SymTable).ppuload(ppufile);
           end;

         { handles the predefined class tobject  }
         { the last TOBJECT which is loaded gets }
         { it !                                  }
         { but do this only from a unit that's   }
         { marked as system unit to avoid some   }
         { equally named user's type to override }
         { the internal types!                   }
         if mf_system_unit in CurrentModule.moduleflags then
           begin
             if (childof=nil) and
                (objecttype in [odt_class,odt_javaclass]) and
                (objname^='TOBJECT') then
               class_tobject:=self;
             if (childof=nil) and
                (objecttype=odt_interfacecom) then
                if (objname^='IUNKNOWN') then
                  interface_iunknown:=self
                else
                if (objname^='IDISPATCH') then
                  interface_idispatch:=self;
             if (objecttype=odt_javaclass) and
                not(oo_is_formal in objectoptions) then
               begin
                 if (objname^='JLOBJECT') then
                   java_jlobject:=self
                 else if (objname^='JLTHROWABLE') then
                   java_jlthrowable:=self
                 else if (objname^='FPCBASERECORDTYPE') then
                   java_fpcbaserecordtype:=self
                 else if (objname^='JLSTRING') then
                   java_jlstring:=self
                 else if (objname^='ANSISTRINGCLASS') then
                   java_ansistring:=self
                 else if (objname^='SHORTSTRINGCLASS') then
                   java_shortstring:=self
                 else if (objname^='JLENUM') then
                   java_jlenum:=self
                 else if (objname^='JUENUMSET') then
                   java_juenumset:=self
                 else if (objname^='FPCBITSET') then
                   java_jubitset:=self
                 else if (objname^='FPCBASEPROCVARTYPE') then
                   java_procvarbase:=self;
               end;
           end;
         if (childof=nil) and
            (objecttype=odt_objcclass) and
            (objname^='PROTOCOL') then
           objc_protocoltype:=self;

         writing_class_record_dbginfo:=false;
       end;


    destructor TObjectDef.Destroy;
      begin
         if Assigned(SymTable) then
           begin
             SymTable.free;
             SymTable:=nil;
           end;
         StringDispose(objextname);
         StringDispose(iidstr);
         if Assigned(ImplementedInterfaces) then
           begin
             ImplementedInterfaces.free;
             ImplementedInterfaces:=nil;
           end;
         if Assigned(iidguid) then
           begin
             dispose(iidguid);
             iidguid:=nil;
           end;
         TFPList.FreeAndNilDisposing(vmtentries,TypeInfo(TVMTEntry));
         if Assigned(vmcallstaticinfo) then
           begin
             FreeMem(vmcallstaticinfo);
             vmcallstaticinfo:=nil;
           end;
         inherited Destroy;
      end;


    function TObjectDef.getcopy : TStoredDef;
      var
        i : LongInt;
      begin
        result:=CObjectDef.create(objecttype,objrealname^,childof,true);
        { the constructor allocates a symtable which we release to avoid memory leaks }
        TObjectDef(result).SymTable.free;
        TObjectDef(result).SymTable:=SymTable.getcopy;
        if Assigned(objextname) then
          TObjectDef(result).objextname:=StringDup(objextname^);
        if Assigned(import_lib) then
          TObjectDef(result).import_lib:=StringDup(import_lib^);
        TObjectDef(result).objectoptions:=objectoptions;
        include(TObjectDef(result).defoptions,df_copied_def);
        TObjectDef(result).extendeddef:=extendeddef;
        if Assigned(tcinitcode) then
          TObjectDef(result).tcinitcode:=tcinitcode.getcopy;
        TObjectDef(result).vmt_field:=vmt_field;
        if Assigned(iidguid) then
          begin
            new(TObjectDef(result).iidguid);
            move(iidguid^,TObjectDef(result).iidguid^,sizeof(iidguid^));
          end;
        if Assigned(iidstr) then
          TObjectDef(result).iidstr:=StringDup(iidstr^);
        TObjectDef(result).abstractcnt:=abstractcnt;
        if Assigned(ImplementedInterfaces) then
          begin
            TObjectDef(result).ImplementedInterfaces.capacity:=TObjectDef(result).ImplementedInterfaces.count+ImplementedInterfaces.count;
            for i:=0 to ImplementedInterfaces.count-1 do
              TObjectDef(result).ImplementedInterfaces.Add(TImplementedInterface(ImplementedInterfaces[i]).Getcopy);
          end;
        TObjectDef(result).copyvmtentries(self);
      end;


    procedure TObjectDef.ppuwrite(ppufile:TCompilerPPUFile);
      var
         i : LongInt;
         vmtentry : PVMTEntry;
         ImplIntf : TImplementedInterface;
         old_do_indirect_crc: boolean;
      begin
         { if class1 in unit A changes, and class2 in unit B inherits from it
           (so unit B uses unit A), then unit B with class2 will be recompiled.
           However, if there is also a class3 in unit C that only depends on
           unit B, then unit C will not be recompiled because nothing changed
           to the interface of unit B. Nevertheless, unit C can indirectly
           depend on unit A via derefs, and these must be updated -> the
           indirect crc keeps track of such changes. }
         old_do_indirect_crc:=ppufile.do_indirect_crc;
         ppufile.do_indirect_crc:=true;
         inherited ppuwrite(ppufile);
         ppufile.putbyte(byte(objecttype));
         ppufile.putbyte(byte(helpertype));
         if Assigned(objextname) then
           ppufile.putstring(objextname^)
         else
           ppufile.putstring('');
         ppufile.putasizeint(TObjectSymTable(SymTable).DataSize);
         ppufile.putword(TObjectSymTable(SymTable).paddingsize);
         ppufile.putbyte(byte(TObjectSymTable(SymTable).fieldalignment));
         ppufile.putbyte(byte(TObjectSymTable(SymTable).recordalignment));
         ppufile.putbyte(byte(TObjectSymTable(SymTable).RecordAlignMin));
         ppufile.putderef(vmt_fieldderef);
         ppufile.putderef(childofderef);
         if objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           begin
              ppufile.putguid(iidguid^);
              ppufile.putstring(iidstr^);
           end;
         ppufile.putlongint(abstractcnt);
         if objecttype=odt_helper then
           ppufile.putderef(extendeddefderef);

         ppufile.putlongint(vmtentries.count);
         for i:=0 to vmtentries.count-1 do
           begin
             vmtentry:=PVMTEntry(vmtentries[i]);
             ppufile.putderef(vmtentry^.procdefderef);
             ppufile.putbyte(byte(vmtentry^.visibility));
           end;

         if Assigned(ImplementedInterfaces) then
           begin
             ppufile.putlongint(ImplementedInterfaces.Count);
             for i:=0 to ImplementedInterfaces.Count-1 do
               begin
                 ImplIntf:=TImplementedInterface(ImplementedInterfaces[i]);
                 ppufile.putderef(ImplIntf.intfdefderef);
                 ppufile.putderef(ImplIntf.ImplementsGetterDeref);
                 ppufile.putlongint(ImplIntf.Ioffset);
                 ppufile.putbyte(byte(ImplIntf.IType));
               end;
           end;

         if df_copied_def in defoptions then
           ppufile.putderef(cloneddefderef);

         writeentry(ppufile,ibobjectdef);

         if not(df_copied_def in defoptions) then
           TObjectSymTable(SymTable).ppuwrite(ppufile);

         ppufile.do_indirect_crc:=old_do_indirect_crc;
      end;


    function TObjectDef.GetTypeName:string;
      begin
        { in this case we will go in endless recursion, because then  }
        { there is no tsym associated yet with the def. It can occur  }
        { (tests/webtbf/tw4757.pas), so for now give a generic name    }
        { instead of the actual type name                             }
        if not Assigned(typesym) then
          result:='<Currently Parsed Class>'
        else
          result:=typesymbolprettyname;
      end;


    procedure TObjectDef.buildderef;
      var
         i : LongInt;
         vmtentry : PVMTEntry;
      begin
         inherited buildderef;
         vmt_fieldderef.build(vmt_field);
         childofderef.build(childof);

         if df_copied_def in defoptions then
           cloneddefderef.build(SymTable.defowner)
         else
           TStoredSymTable(SymTable).buildderef;

         if objecttype=odt_helper then
           extendeddefderef.build(extendeddef);

         for i:=0 to vmtentries.count-1 do
           begin
             vmtentry:=PVMTEntry(vmtentries[i]);
             vmtentry^.procdefderef.build(vmtentry^.procdef);
           end;

         if Assigned(ImplementedInterfaces) then
           begin
             for i:=0 to ImplementedInterfaces.count-1 do
               TImplementedInterface(ImplementedInterfaces[i]).buildderef;
           end;
      end;


    procedure TObjectDef.deref;
      var
         i : LongInt;
         vmtentry : PVMTEntry;
      begin
         inherited deref;
         vmt_field:=TSym(vmt_fieldderef.resolve);
         childof:=TObjectDef(childofderef.resolve);
         if df_copied_def in defoptions then
           begin
             cloneddef:=TObjectDef(cloneddefderef.resolve);
             SymTable:=cloneddef.SymTable.getcopy;
           end
         else
           TStoredSymTable(SymTable).deref(false);
         if objecttype=odt_helper then
           extendeddef:=TDef(extendeddefderef.resolve);
         for i:=0 to vmtentries.count-1 do
           begin
             vmtentry:=PVMTEntry(vmtentries[i]);
             vmtentry^.procdef:=TProcDef(vmtentry^.procdefderef.resolve);
           end;
         if Assigned(ImplementedInterfaces) then
           begin
             for i:=0 to ImplementedInterfaces.count-1 do
               TImplementedInterface(ImplementedInterfaces[i]).deref;
           end;
      end;


    procedure create_class_helper_for_procdef(def: tobject; arg: pointer);
      var
        pd: TProcDef absolute def;
        st: TSymTable;
        psym: TSym;
        nname: TIDString;
      begin
        if (TDef(def).typ<>procdef) then
          exit;
        { pd.owner = objcclass symtable -> defowner = objcclassdef ->
          owner = symtable in which objcclassdef is defined
        }
        st:=pd.owner.defowner.owner;
        nname:=class_helper_prefix+TProcSym(pd.procsym).name;
        { check for an existing procsym with our special name }
        psym:=TSym(st.find(nname));
        if not Assigned(psym) then
          begin
            psym:=CProcSym.create(nname);
            { avoid warning about this symbol being unused }
            psym.IncRefCount;
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
            st.insertsym(psym,false);
          end
        else if (psym.typ<>procsym) then
          InternalError(2009111501);
        { add ourselves to this special procsym }
        TProcSym(psym).procdeflist.add(def);
      end;


    procedure TObjectDef.derefimpl;
      begin
         inherited derefimpl;
         { the procdefs are not owned by the class helper procsyms, so they
           are not stored/restored either -> re-add them here }
         if (objecttype in [odt_objcclass,odt_objcprotocol]) or
            (oo_is_classhelper in objectoptions) then
           SymTable.DefList.ForEachCall(@create_class_helper_for_procdef,nil);
      end;


    procedure TObjectDef.copyvmtentries(objdef:TObjectDef);
      var
        i : LongInt;
        vmtentry : PVMTEntry;
      begin
        if vmtentries.count<>0 then
          InternalError(2019081401);
        vmtentries.count:=objdef.vmtentries.count;
        for i:=0 to objdef.vmtentries.count-1 do
          begin
            new(vmtentry);
            vmtentry^:=PVMTEntry(objdef.vmtentries[i])^;
            vmtentries[i]:=vmtentry;
          end;
       end;


    function TObjectDef.getparentdef:TDef;
      begin
{ TODO: Remove getparentdef hack}
        { With 2 forward declared classes with the child class before the
          parent class the child class is written earlier to the ppu. Leaving it
          possible to have a reference to the parent class for property overriding,
          but the parent class still has the childof not resolved yet (PFV) }
        if childof=nil then
          childof:=TObjectDef(childofderef.resolve);
        result:=childof;
      end;


    procedure TObjectDef.prepareguid;
      begin
        { set up guid }
        if not Assigned(iidguid) then
         begin
            new(iidguid);
            fillchar(iidguid^,sizeof(iidguid^),0); { default null guid }
         end;
        { setup iidstring }
        if not Assigned(iidstr) then
          iidstr:=StringDup(''); { default is empty string }
      end;


    procedure TObjectDef.set_parent( c : TObjectDef);
      begin
        if Assigned(childof) then
          exit;
        childof:=c;
        if not Assigned(c) then
          exit;
        { inherit options and status }
        objectoptions:=objectoptions+(c.objectoptions*inherited_objectoptions);
        { check if parent is a generic parameter }
        if sp_generic_para in c.typesym.symoptions then
         objectoptions:=objectoptions+[oo_inherits_not_specialized];
        { initially has the same number of abstract methods as the parent }
        abstractcnt:=c.abstractcnt;
        { add the data of the ancestor class/object }
        if (objecttype in [odt_class,odt_object,odt_objcclass,odt_javaclass]) then
          begin
            TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize+TObjectSymTable(c.SymTable).DataSize;
            { inherit recordalignment }
            TObjectSymTable(SymTable).recordalignment:=TObjectSymTable(c.SymTable).recordalignment;
            { if both the parent and this record use C-alignment, also inherit
              the current field alignment }
            if (TObjectSymTable(c.SymTable).usefieldalignment=C_alignment) and
               (TObjectSymTable(SymTable).usefieldalignment=C_alignment) then
              TObjectSymTable(SymTable).fieldalignment:=TObjectSymTable(c.SymTable).fieldalignment;
            { the padding is not inherited for Objective-C classes (maybe not
              for cppclass either?) }
            if objecttype=odt_objcclass then
              TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize-TObjectSymTable(c.SymTable).paddingsize;
            if (oo_has_vmt in objectoptions) and
               (oo_has_vmt in c.objectoptions) then
              TObjectSymTable(SymTable).DataSize:=TObjectSymTable(SymTable).DataSize-sizeof(PInt);
            { if parent has a vmt field then the offset is the same for the child PM }
            if (oo_has_vmt in c.objectoptions) or is_class(self) then
              begin
                vmt_field:=c.vmt_field;
                include(objectoptions,oo_has_vmt);
              end;
          end;
      end;


   procedure TObjectDef.insertvmt;
     begin
        if objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_javaclass,odt_interfacejava] then
          exit;
        if (oo_has_vmt in objectoptions) then
          InternalError(2020100816)
        else
          begin
             TObjectSymTable(SymTable).DataSize:=align(TObjectSymTable(SymTable).DataSize,
                 TObjectSymTable(SymTable).fieldalignment);

             if (tf_requires_proper_alignment in TargetInfo.flags) then
               begin
                 { Align VMT pointer and whole object instance if target CPU requires alignment. }
                 TObjectSymTable(SymTable).DataSize:=align(TObjectSymTable(SymTable).DataSize,sizeof(PInt));
                 TObjectSymTable(SymTable).alignrecord(TObjectSymTable(SymTable).DataSize,sizeof(PInt));
               end;
             vmt_field:=CFieldVarSym.create('_vptr$'+objname^,vs_value,voidpointertype,[]);
             hidesym(vmt_field);
             TObjectSymTable(SymTable).insertsym(vmt_field);
             TObjectSymTable(SymTable).addfield(TFieldVarSym(vmt_field),vis_hidden);
             include(objectoptions,oo_has_vmt);
          end;
     end;


   function TObjectDef.vmt_offset: asizeint;
     begin
        if objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_javaclass,odt_interfacejava] then
          result:=0
        else if (TObjectSymTable(SymTable).usefieldalignment<>bit_alignment) then
          result:=TFieldVarSym(vmt_field).fieldoffset
        else
          result:=TFieldVarSym(vmt_field).fieldoffset div 8;
     end;


   procedure TObjectDef.check_forwards;
     begin
        if not(objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcprotocol,odt_interfacejava]) then
          inherited;
        if (oo_is_forward in objectoptions) then
          begin
             { ok, in future, the forward can be resolved }
             Message1(sym_e_class_forward_not_resolved,objrealname^);
             exclude(objectoptions,oo_is_forward);
          end;
     end;


   function TObjectDef.find_destructor: TProcDef;
     var
       objdef: TObjectDef;
     begin
        objdef:=self;
        while Assigned(objdef) do
          begin
            result:=objdef.find_procdef_bytype(potype_destructor);
            if Assigned(result) then
              exit;
            objdef:=objdef.childof;
          end;
        result:=nil;
     end;

    function TObjectDef.implements_any_interfaces: boolean;
      begin
        result := (ImplementedInterfaces.Count > 0) or
          (Assigned(childof) and childof.implements_any_interfaces);
      end;


    function TObjectDef.register_implemented_interface(intfdef:TObjectDef;useguid:boolean):TImplementedInterface;
      begin
        { allocate the GUID only if the class implements at least one interface }
        if useguid then
          prepareguid;
        result:=TImplementedInterface.create(intfdef);
        ImplementedInterfaces.Add(result);
      end;


    function TObjectDef.size : asizeint;
      begin
        if objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper,odt_javaclass,odt_interfacejava] then
          result:=voidpointertype.size
        else
          result:=TObjectSymTable(SymTable).DataSize;
      end;


    function TObjectDef.alignment:shortint;
      begin
        if objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper,odt_javaclass,odt_interfacejava] then
          alignment:=voidpointertype.alignment
        else
          alignment:=TObjectSymTable(SymTable).recordalignment;
      end;


    function TObjectDef.vmtmethodoffset(index:LongInt):LongInt;
      begin
        { for offset of methods for classes, see rtl/inc/objpash.inc }
        case objecttype of
        odt_class:
          { the +2*sizeof(pint) is size and -size }
          vmtmethodoffset:=index*voidcodepointertype.size+10*voidpointertype.size+2*sizeof(PInt);
        odt_helper,
        odt_objcclass,
        odt_objcprotocol:
          vmtmethodoffset:=0;
        odt_interfacecom,odt_interfacecorba,odt_dispinterface:
          vmtmethodoffset:=index*voidcodepointertype.size;
        odt_javaclass,
        odt_interfacejava:
          { invalid }
          vmtmethodoffset:=-1;
        else
          { the +2*sizeof(pint) is size and -size }
{$ifdef WITHDMT}
          vmtmethodoffset:=index*voidcodepointertype.size+2*voidpointertype.size+2*sizeof(PInt);
{$else WITHDMT}
          vmtmethodoffset:=index*voidcodepointertype.size+1*voidpointertype.size+2*sizeof(PInt);
{$endif WITHDMT}
        end;
      end;


    function TObjectDef.vmt_mangledname : TSymStr;
      begin
        if not(oo_has_vmt in objectoptions) then
          Message1(parser_n_object_has_no_vmt,objrealname^);
        if not is_unique_objpasdef then
          vmt_mangledname:=make_mangledname('VMT',owner,objname^)
        else
          vmt_mangledname:=childof.vmt_mangledname;
      end;


    function TObjectDef.vmt_def: TRecordDef;
      var
        vmttypesym: TSymEntry;
      begin
        if not is_unique_objpasdef then
          begin
            vmttypesym:=SymTable.Find('vmtdef');
            if not Assigned(vmttypesym) or
               (vmttypesym.typ<>symconst.typesym) or
               (TTypeSym(vmttypesym).typedef.typ<>recorddef) then
              InternalError(2015052501);
            result:=TRecordDef(TTypeSym(vmttypesym).typedef);
          end
        else
          result:=childof.vmt_def;
      end;


    function TObjectDef.NeedsInitTable : boolean;
      var
        hp : TObjectDef;
      begin
         case objecttype of
            odt_helper,
            odt_class :
              NeedsInitTable:=false;
            odt_dispinterface,
            odt_interfacecom:
              NeedsInitTable:=true;
            odt_interfacecorba:
              begin
                hp:=childof;
                while Assigned(hp) do
                  begin
                    if hp=interface_iunknown then
                      begin
                        NeedsInitTable:=true;
                        exit;
                      end;
                    hp:=hp.childof;
                  end;
                NeedsInitTable:=false;
              end;
            odt_object:
              NeedsInitTable:=
                TObjectSymTable(SymTable).needs_init_final or
                (Assigned(childof) and
                 childof.NeedsInitTable);
            odt_cppclass,
            odt_objcclass,
            odt_objcprotocol,
            odt_javaclass,
            odt_interfacejava:
              NeedsInitTable:=false;
            else
              InternalError(200108267);
         end;
      end;

    function TObjectDef.NeedsSeparateInitRTTI : boolean;
      begin
        result:=not (objecttype in [odt_interfacecom,odt_interfacecorba,odt_dispinterface]);
      end;


    function TObjectDef.HasNonTrivialInitChild(check_parent:boolean):boolean;
      begin
        if objecttype in [odt_class,odt_object] then
          begin
            result:=TObjectSymTable(SymTable).has_non_trivial_init or
                      (check_parent and Assigned(childof) and childof.HasNonTrivialInitChild(true));
          end
        else
          result:=false;
      end;


    function TObjectDef.RTTIMangledName(rt: TRTTIType): TSymStr;
      begin
        if not(objecttype in [odt_objcclass,odt_objcprotocol]) then
          begin
            if not is_unique_objpasdef then
              result:=inherited RTTIMangledName(rt)
            else
              result:=childof.RTTIMangledName(rt)
          end
        else
          begin
            { necessary in case of a dynamic array of nsobject, or
              if an nsobject field appears in a record that needs
              init/finalisation }
            if rt=initrtti then
              begin
                result:=voidpointertype.RTTIMangledName(rt);
                exit;
              end;

            if not(TargetInfo.system in systems_objc_nfabi) then
              begin
                result:=TargetAsm.labelprefix;
                case objecttype of
                  odt_objcclass:
                    begin
                      case rt of
                        objcclassrtti:
                          if not(oo_is_classhelper in objectoptions) then
                            result:=result+'_OBJC_CLASS_'
                          else
                            result:=result+'_OBJC_CATEGORY_';
                        objcmetartti:
                          if not(oo_is_classhelper in objectoptions) then
                            result:=result+'_OBJC_METACLASS_'
                          else
                            InternalError(2009111511);
                        objcprotocollist:
                          if not(oo_is_classhelper in objectoptions) then
                            result:=result+'_OBJC_CLASS_PROTOCOLS_'
                          else
                            result:=result+'_OBJC_CATEGORY_PROTOCOLS_';
                        objcinstancemethods:
                          result:=result+'_OBJC_INSTANCE_METHODS_';
                        objcclassmethods:
                          result:=result+'_OBJC_CLASS_METHODS_';
                        else
                         InternalError(2009092302);
                      end;
                    end;
                  odt_objcprotocol:
                    begin
                      case rt of
                        objcclassrtti:
                          result:=result+'_OBJC_PROTOCOL_';
                        objcprotocollist:
                          result:=result+'_OBJC_PROTOCOL_REFS_';
                        objcinstancemethods:
                          result:=result+'_OBJC_PROTOCOL_INSTANCE_METHODS_';
                        objcclassmethods:
                          result:=result+'_OBJC_PROTOCOL_CLASS_METHODS_';
                        objcprotinstancemethodsopt:
                          result:=result+'_OBJC_PROTOCOL_INSTANCE_METHODS_OPT_';
                        objcprotclassmethodsopt:
                          result:=result+'_OBJC_PROTOCOL_CLASS_METHODS_OPT_';
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
                case objecttype of
                  odt_objcclass:
                    begin
                      if (oo_is_classhelper in objectoptions) and
                         not(rt in [objcclassrtti,objcprotocollist]) then
                        InternalError(2009111512);
                      case rt of
                        objcclassrtti:
                          if not(oo_is_classhelper in objectoptions) then
                            result:='_OBJC_CLASS_$_'
                          else
                            result:='_OBJC_$_CATEGORY_';
                        objcmetartti:
                          result:='_OBJC_METACLASS_$_';
                        objcclassrortti:
                          result:='__OBJC_CLASS_RO_$_';
                        objcmetarortti:
                          result:='__OBJC_METACLASS_RO_$_';
                        objcprotocollist:
                          if not(oo_is_classhelper in objectoptions) then
                            result:='__OBJC_CLASS_PROTOCOLS_$_'
                          else
                            result:='__OBJC_CATEGORY_PROTOCOLS_$_';
                        objcinstancemethods:
                          result:='__OBJC_$_INSTANCE_METHODS_';
                        objcclassmethods:
                          result:='__OBJC_$_CLASS_METHODS_';
                        else
                         InternalError(2009092303);
                      end;
                    end;
                  odt_objcprotocol:
                    begin
                      result:=lower(TargetAsm.labelprefix);
                      case rt of
                        objcclassrtti:
                          result:=result+'_OBJC_PROTOCOL_$_';
                        objcmetartti:
                          result:=result+'_OBJC_LABEL_PROTOCOL_$_';
                        objcprotocollist:
                          result:='__OBJC_$_PROTOCOL_REFS_';
                        objcprotocolmethodstypelist:
                          result:='__OBJC_$_PROTOCOL_METHOD_TYPES_';
                        objcinstancemethods:
                          result:='__OBJC_$_PROTOCOL_INSTANCE_METHODS_';
                        objcclassmethods:
                          result:='__OBJC_$_PROTOCOL_CLASS_METHODS_';
                        objcprotinstancemethodsopt:
                          result:='__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_';
                        objcprotclassmethodsopt:
                          result:='__OBJC_$_PROTOCOL_CLASS_METHODS_OPT_';
                        else
                          InternalError(2009092501);
                      end;
                    end;
                  else
                    InternalError(2013113005);
                end;
              end;
            result:=result+objextname^;
          end;
      end;

    function TObjectDef.is_unique_objpasdef: boolean;
        begin
          result:=
            (df_unique in defoptions) and
            is_class_or_interface_or_dispinterface(self)
        end;


    function TObjectDef.members_need_inittable : boolean;
      begin
        members_need_inittable:=TObjectSymTable(SymTable).needs_init_final or
                                  HasNonTrivialInitChild(true);
      end;


    function TObjectDef.IsPublishable : TPublishProperty;
      begin
         if objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
           IsPublishable:=pp_publish
         else
           IsPublishable:=pp_error;
      end;


    function TObjectDef.get_next_dispid: LongInt;
      begin
        inc(fcurrent_dispid);
        result:=fcurrent_dispid;
      end;

    function TObjectDef.search_enumerator_get: TProcDef;
      begin
        result:=inherited;
        if not Assigned(result) and Assigned(childof) then
          result:=childof.search_enumerator_get;
      end;

    function TObjectDef.search_enumerator_move: TProcDef;
      begin
        result:=inherited;
        if not Assigned(result) and Assigned(childof) then
          result:=childof.search_enumerator_move;
      end;

    function TObjectDef.search_enumerator_current: TSym;
      begin
        result:=inherited;
        if not Assigned(result) and Assigned(childof) then
          result:=childof.search_enumerator_current;
      end;

    procedure TObjectDef.RegisterCreatedClassRefType;
      begin
        if not classref_created_in_current_module then
          begin
            classref_created_in_current_module:=true;
            if not (owner.symtabletype in [localsymtable]) then
              CurrentModule.wpoinfo.addcreatedobjtypeforclassref(self);
          end;
      end;


    procedure TObjectDef.RegisterCreatedObjectType;
      begin
        if not created_in_current_module then
          begin
            created_in_current_module:=true;
            if not (owner.symtabletype in [localsymtable]) then
              CurrentModule.wpoinfo.addcreatedobjtype(self);
          end;
      end;


    procedure TObjectDef.register_maybe_created_object_type;
      begin
        { if we know it has been created for sure, no need
          to also record that it maybe can be created in
          this module
        }
        if not (created_in_current_module) and
           not (maybe_created_in_current_module) then
          begin
            maybe_created_in_current_module:=true;
            CurrentModule.wpoinfo.addmaybecreatedbyclassref(self);
          end;
      end;


    procedure TObjectDef.register_vmt_call(index: LongInt);
      begin
        if (is_object(self) or is_class(self)) then
          CurrentModule.wpoinfo.addcalledvmtentry(self,index);
      end;


    procedure check_and_finish_msg(data: tobject; arg: pointer);
      var
        def: TDef absolute data;
        pd: TProcDef absolute data;
        i,
        paracount: LongInt;
      begin
        if (def.typ=procdef) then
          begin
            { add all messages also under a dummy name to the symtable in
              which the objcclass/protocol/category is declared, so they can
              be called via id.<name>
            }
            create_class_helper_for_procdef(pd,nil);

            { we have to wait until now to set the mangled name because it
              depends on the (possibly external) class name, which is defined
              at the very end.  }
            if not(po_msgstr in pd.procoptions) then
              begin
                CGMessagePos(pd.fileinfo,parser_e_objc_requires_msgstr);
                { recover to avoid internalerror later on }
                include(pd.procoptions,po_msgstr);
                pd.messageinf.str:=StringDup('MissingDeclaration');
              end;
            { Mangled name is already set in case this is a copy of
              another type.  }
            if not(po_has_mangledname in pd.procoptions) then
              begin
                { check whether the number of formal parameters is correct,
                  and whether they have valid Objective-C types }
                paracount:=0;
                for i:=1 to length(pd.messageinf.str^) do
                  if pd.messageinf.str^[i]=':' then
                    inc(paracount);
                for i:=0 to pd.paras.count-1 do
                  if not(vo_is_hidden_para in TParaVarSym(pd.paras[i]).varoptions) and
                     not is_array_of_const(TParaVarSym(pd.paras[i]).vardef) then
                    dec(paracount);
                if (paracount<>0) then
                  MessagePos(pd.fileinfo,sym_e_objc_para_mismatch);

                pd.setmangledname(pd.objcmangledname);
              end
            else
              { all checks already done }
              exit;
            if not(oo_is_external in pd.struct.objectoptions) then
              begin
                if (po_varargs in pd.procoptions) then
                  MessagePos(pd.fileinfo,parser_e_varargs_need_cdecl_and_external)
                else
                  begin
                    { check for "array of const" parameters }
                    for i:=0 to pd.parast.symlist.count-1 do
                      begin
                        if (TSym(pd.parast.symlist[i]).typ=paravarsym) and
                           is_array_of_const(TParaVarSym(pd.parast.symlist[i]).vardef) then
                          MessagePos(pd.fileinfo,parser_e_varargs_need_cdecl_and_external);
                      end;
                  end;
              end;
          end;
      end;


    procedure mark_private_fields_used(data: tobject; arg: pointer);
      var
        sym: TSym absolute data;
      begin
        if (sym.typ=fieldvarsym) and
           (TFieldVarSym(sym).visibility in [vis_private,vis_strictprivate]) then
          sym.IncRefCount;
      end;


    procedure TObjectDef.finish_objc_data;
      begin
        self.SymTable.DefList.foreachcall(@check_and_finish_msg,nil);
        if (oo_is_external in objectoptions) then
          self.SymTable.SymList.ForEachCall(@mark_private_fields_used,nil);
      end;


    procedure verify_objc_vardef(data: tobject; arg: pointer);
      var
        sym: TAbstractVarSym absolute data;
        res: PBoolean absolute arg;
        founderrordef: TDef;
      begin
        if not(TSym(data).typ in [paravarsym,fieldvarsym]) then
          exit;
        if (sym.typ=paravarsym) and
           ((vo_is_hidden_para in TParaVarSym(sym).varoptions) or
            is_array_of_const(TParaVarSym(sym).vardef)) then
          exit;
        if not objcchecktype(sym.vardef,founderrordef) then
          begin
            MessagePos1(sym.fileinfo,type_e_objc_type_unsupported,founderrordef.typename);
            res^:=false;
          end;
      end;


    procedure verify_objc_procdef_paras(data: tobject; arg: pointer);
      var
        def: TDef absolute data;
        res: PBoolean absolute arg;
        founderrordef: TDef;
      begin
        if (def.typ<>procdef) then
          exit;
        { check parameter types for validity }
        TProcDef(def).paras.foreachcall(@verify_objc_vardef,arg);
        { check the result type for validity }
        if not objcchecktype(TProcDef(def).returndef,founderrordef) then
          begin
            MessagePos1(TProcDef(def).funcretsym.fileinfo,type_e_objc_type_unsupported,founderrordef.typename);
            res^:=false;
          end;
      end;


    function TObjectDef.check_objc_types: boolean;
      begin
        { done in separate step from finish_objc_data, because when
          finish_objc_data is called, not all forwarddefs have been resolved
          yet and we need to know all types here }
        result:=true;
        self.SymTable.symlist.foreachcall(@verify_objc_vardef,@result);
        self.SymTable.deflist.foreachcall(@verify_objc_procdef_paras,@result);
      end;


    procedure do_cpp_import_info(data: tobject; arg: pointer);
      var
        def: TDef absolute data;
        pd: TProcDef absolute data;
      begin
        if (def.typ=procdef) then
          begin
            pd.setmangledname(TargetInfo.Cprefix+pd.cplusplusmangledname);
            if (oo_is_external in pd.struct.objectoptions) then
              begin
                { copied from psub.read_proc }
                if Assigned(TObjectDef(pd.struct).import_lib) then
                   CurrentModule.AddExternalImport(TObjectDef(pd.struct).import_lib^,pd.mangledname,pd.mangledname,0,false,false)
                 else
                   begin
                     { add import name to external list for DLL scanning }
                     if tf_has_dllscanner in TargetInfo.flags then
                       CurrentModule.dllscannerinputlist.Add(pd.mangledname,pd);
                   end;

              end;
          end;
      end;


    procedure TObjectDef.finish_cpp_data;
      begin
        self.SymTable.DefList.ForEachCall(@do_cpp_import_info,nil);
      end;


    procedure TObjectDef.apply_rtti_directive(dir: TRTTIDirective);
      begin
        rtti.clause:=dir.clause;
        rtti.options:=dir.options;
        if (dir.clause=rtc_inherit) and Assigned(childof) and (childof.rtti.clause<>rtc_none) then
          begin
            rtti.options[ro_methods]:=rtti.options[ro_methods]+childof.rtti.options[ro_methods];
            rtti.options[ro_fields]:=rtti.options[ro_fields]+childof.rtti.options[ro_fields];
            rtti.options[ro_properties]:=rtti.options[ro_properties]+childof.rtti.options[ro_properties];
          end;
      end;

{$ifdef DEBUG_NODE_XML}
    function TObjectDef.XMLPrintType: AnsiString;
      begin
        if (oo_is_forward in objectoptions) then
          Result := '&lt;class prototype&gt;'
        else
          Result := '&lt;class&gt;';
      end;


    procedure TObjectDef.XMLPrintDefInfo(var T: Text; Sym: TSym);
      var
        i: TObjectOption;
        first: Boolean;
      begin
        inherited XMLPrintDefInfo(T, Sym);

        First := True;
        for i := Low(TObjectOption) to High(TObjectOption) do
          if i in objectoptions then
            begin
              if First then
                begin
                  Write(T, ' objectoptions="', i);
                  First := False;
                end
              else
                Write(T, ',', i)
            end;

        if not first then
          Write(T, '"');
      end;


    procedure TObjectDef.XMLPrintDefData(var T: Text; Sym: TSym);
      begin
        { There's nothing useful yet if the type is only forward-declared }
        if not (oo_is_forward in objectoptions) then
          begin
            if Assigned(childof) then
              WriteLn(T, PrintNodeIndention, '<ancestor>', SanitiseXMLString(childof.typesym.RealName), '</ancestor>');

            inherited XMLPrintDefData(T, Sym);
          end;
      end;
{$endif DEBUG_NODE_XML}


{****************************************************************************
                             TImplementedInterface
****************************************************************************}

    function TImplementedInterface.GetIOffset: LongInt;
      begin
        if (fIOffset=-1) and
           (IType in [etFieldValue,etFieldValueClass]) then
          result:=TFieldVarSym(ImplementsField).fieldoffset
        else
          result:=fIOffset;
      end;


    constructor TImplementedInterface.create(aintf: TObjectDef);
      begin
        inherited create;
        intfdef:=aintf;
        intfdefderef.reset;
        IOffset:=-1;
        IType:=etStandard;
        NameMappings:=nil;
        procdefs:=nil;
      end;


    constructor TImplementedInterface.create_deref(intfd,getterd:TDeref);
      begin
        inherited create;
        intfdef:=nil;
        intfdefderef:=intfd;
        ImplementsGetterDeref:=getterd;
        IOffset:=-1;
        IType:=etStandard;
        NameMappings:=nil;
        procdefs:=nil;
      end;


    destructor  TImplementedInterface.Destroy;
      var
        i : LongInt;
        mappedname : PShortString;
      begin
        if Assigned(NameMappings) then
          begin
            for i:=0 to NameMappings.Count-1 do
              begin
                mappedname:=PShortString(NameMappings[i]);
                StringDispose(mappedname);
              end;
            NameMappings.free;
            NameMappings:=nil;
          end;
        if Assigned(procdefs) then
          begin
            procdefs.free;
            procdefs:=nil;
          end;
        inherited Destroy;
      end;


    procedure TImplementedInterface.buildderef;
      begin
        intfdefderef.build(intfdef);
        ImplementsGetterDeref.build(ImplementsGetter);
      end;


    procedure TImplementedInterface.deref;
      begin
        intfdef:=TObjectDef(intfdefderef.resolve);
        ImplementsGetter:=TSym(ImplementsGetterDeref.resolve);
      end;


    procedure TImplementedInterface.AddMapping(const origname,newname: string);
      begin
        if not Assigned(NameMappings) then
          NameMappings:=TFPHashList.Create;
        NameMappings.Add(origname,StringDup(newname));
      end;


    function TImplementedInterface.GetMapping(const origname: string):string;
      var
        mappedname : PShortString;
      begin
        result:='';
        if not Assigned(NameMappings) then
          exit;
        mappedname:=PShortString(NameMappings.Find(origname));
        if Assigned(mappedname) then
          result:=mappedname^;
      end;


    procedure TImplementedInterface.AddImplProc(pd:TProcDef);
      begin
        if not Assigned(procdefs) then
          procdefs:=TFPObjectList.Create(false);
        { duplicate entries must be stored, because multiple }
        { interfaces can declare methods with the same name  }
        { and all of these get their own VMT entry           }
        procdefs.Add(pd);
      end;


    function TImplementedInterface.IsImplMergePossible(MergingIntf:TImplementedInterface;out weight: LongInt): boolean;
      var
        i : LongInt;
      begin
        result:=false;
        { interfaces being implemented through delegation are not mergeable (FK) }
        if (IType<>etStandard) or (MergingIntf.IType<>etStandard) or not(Assigned(ProcDefs)) or not(Assigned(MergingIntf.ProcDefs)) then
          exit;
        weight:=0;
        { empty interface is mergeable }
        if ProcDefs.Count=0 then
          begin
            result:=true;
            exit;
          end;
        { The interface to merge must at least the number of
          procedures of this interface }
        if MergingIntf.ProcDefs.Count<ProcDefs.Count then
          exit;
        for i:=0 to ProcDefs.Count-1 do
          begin
            if MergingIntf.ProcDefs[i]<>ProcDefs[i] then
              exit;
          end;
        weight:=ProcDefs.Count;
        result:=true;
      end;


    function TImplementedInterface.getcopy:TImplementedInterface;
      var
        i : LongInt;
      begin
        Result:=TImplementedInterface.Create(nil);
        { 1) the procdefs list will be freed once for each copy
          2) since the procdefs list owns its elements, those will also be freed for each copy
             Nope: procdefs are owned by their symtable, so no copy necessary
          3) idem for the name mappings
        }
        result.fIOffset:=fIOffset;
        result.IntfDef:=IntfDef;
        result.IntfDefDeref.reset;
        result.IType:=IType;
        result.VtblImplIntf:=VtblImplIntf;
        if Assigned(NameMappings) then
          begin
            result.NameMappings:=TFPHashList.create;
            for i:=0 to NameMappings.Count-1 do
              Result.NameMappings.Add(NameMappings.NameOfIndex(i),
                                      StringDup(PShortString(NameMappings.Items[i])^));
          end;
        if Assigned(ProcDefs) then
          begin
            result.ProcDefs:=TFPObjectList.create(false);
            { Note: this is probably wrong, because those procdefs are owned by
              the old objectdef from which we copy, what would be the correct way
              of doing this is to lookup the equivalent copy in the new owner
              and reference this instead... But this is complicated so let's try
              it this way until it blows up ok? }
            for i:=0 to ProcDefs.Count-1 do
              Result.ProcDefs.add(TProcDef(procdefs[i]).getcopy);
          end;
        result.ImplementsGetter:=ImplementsGetter;
        result.ImplementsGetterDeref.reset;
        result.ImplementsField:=ImplementsField;
      end;

{****************************************************************************
                                TFORWARDDEF
****************************************************************************}

   constructor TForwardDef.create(const s:string;const pos:TFilePosInfo);
     begin
        inherited create(forwarddef,true);
        tosymname:=StringDup(s);
        forwardpos:=pos;
     end;


    function TForwardDef.GetTypeName:string;
      begin
        GetTypeName:='unresolved forward to '+tosymname^;
      end;


    destructor TForwardDef.Destroy;
      begin
        StringDispose(tosymname);
        inherited Destroy;
      end;

    function TForwardDef.getcopy:TStoredDef;
      begin
        result:=CForwardDef.create(tosymname^, forwardpos);
      end;

{****************************************************************************
                               TUNDEFINEDDEF
****************************************************************************}

   constructor TUndefinedDef.create(doregister:boolean);
     begin
        inherited create(undefineddef,doregister);
     end;


    constructor TUndefinedDef.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(undefineddef,ppufile);
         PPULoadPlatform(ppufile);
      end;

    function TUndefinedDef.GetTypeName:string;
      begin
        GetTypeName:='<undefined type>';
      end;


    procedure TUndefinedDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         writeentry(ppufile,ibundefineddef);
      end;


{****************************************************************************
                                  TERRORDEF
****************************************************************************}

    constructor TErrorDef.create;
      begin
        inherited create(errordef,true);
        { prevent consecutive faults }
        savesize:=1;
      end;


    procedure TErrorDef.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        { Can't write errordefs to ppu }
        InternalError(200411063);
      end;


    function TErrorDef.GetTypeName:string;
      begin
        GetTypeName:='<erroneous type>';
      end;


    function TErrorDef.getmangledparaname:TSymStr;
      begin
        getmangledparaname:='error';
      end;


{****************************************************************************
                           Definition Helpers
****************************************************************************}

    function is_interfacecom(def: TDef): boolean;
      begin
        is_interfacecom:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_interfacecom);
      end;

    function is_interfacecom_or_dispinterface(def: TDef): boolean;
      begin
        is_interfacecom_or_dispinterface:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_interfacecom,odt_dispinterface]);
      end;

    function is_any_interface_kind(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          ((TObjectDef(def).objecttype in [odt_interfacecom,odt_dispinterface,odt_interfacecorba,odt_interfacejava,odt_objcprotocol]) or
           is_objccategory(def));
      end;

    function is_interfacecorba(def: TDef): boolean;
      begin
        is_interfacecorba:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_interfacecorba);
      end;

    function is_interface(def: TDef): boolean;
      begin
        is_interface:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_interfacecom,odt_interfacecorba]);
      end;


    function is_dispinterface(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_dispinterface);
      end;


    function is_class(def: TDef): boolean;
      begin
        is_class:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_class);
      end;


    function is_object(def: TDef): boolean;
      begin
        is_object:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_object);
      end;


    function is_cppclass(def: TDef): boolean;
      begin
        is_cppclass:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_cppclass);
      end;


    function is_objcclass(def: TDef): boolean;
      begin
        is_objcclass:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_objcclass);
      end;


    function is_objectpascal_helper(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_helper);
      end;


    function is_objcclassref(def: TDef): boolean;
      begin
        is_objcclassref:=
          Assigned(def) and
          (def.typ=classrefdef) and
          is_objcclass(TClassRefDef(def).pointeddef);
      end;


    function is_objcprotocol(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_objcprotocol);
      end;


    function is_objccategory(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          { if used as a forward type }
          ((TObjectDef(def).objecttype=odt_objccategory) or
          { if used as after it has been resolved }
           ((TObjectDef(def).objecttype=odt_objcclass) and
            (oo_is_classhelper in TObjectDef(def).objectoptions)));
      end;

    function is_objc_class_or_protocol(def: TDef): boolean;
      begin
         result:=
           Assigned(def) and
           (def.typ=objectdef) and
           (TObjectDef(def).objecttype in [odt_objcclass,odt_objcprotocol]);
      end;


    function is_objc_protocol_or_category(def: TDef): boolean;
      begin
         result:=
           Assigned(def) and
           (def.typ=objectdef) and
           ((TObjectDef(def).objecttype = odt_objcprotocol) or
            ((TObjectDef(def).objecttype = odt_objcclass) and
             (oo_is_classhelper in TObjectDef(def).objectoptions)));
      end;

    function is_classhelper(def: TDef): boolean;
      begin
         result:=
           is_objectpascal_helper(def) or
           is_objccategory(def);
      end;

    function is_class_or_interface(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba]);
      end;


    function is_class_or_interface_or_objc(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_objcclass,odt_objcprotocol]);
      end;


    function is_class_or_interface_or_objc_or_java(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_objcclass,odt_objcprotocol,odt_javaclass,odt_interfacejava]);
      end;


    function is_class_or_interface_or_dispinterface_or_objc_or_java(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_javaclass,odt_interfacejava]);
      end;


    function is_class_or_interface_or_object(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_object]);
      end;


    function is_class_or_interface_or_dispinterface(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface]);
      end;


    function is_implicit_pointer_object_type(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface,odt_objcclass,odt_objcprotocol,odt_helper,odt_javaclass,odt_interfacejava]);
      end;

    function is_implicit_array_pointer(def: TDef): boolean;
      begin
        result:=is_dynamic_array(def) or is_dynamicstring(def);
      end;

    function is_class_or_object(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_class,odt_object]);
      end;

    function is_record(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=recorddef);
      end;

    function is_javaclass(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_javaclass);
      end;

    function is_javaclassref(def: TDef): boolean;
      begin
        is_javaclassref:=
          Assigned(def) and
          (def.typ=classrefdef) and
          is_javaclass(TClassRefDef(def).pointeddef);
      end;

    function is_javainterface(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype=odt_interfacejava);
      end;

    function is_java_class_or_interface(def: TDef): boolean;
      begin
        result:=
          Assigned(def) and
          (def.typ=objectdef) and
          (TObjectDef(def).objecttype in [odt_javaclass,odt_interfacejava]);
      end;

    procedure loadobjctypes;
      begin
        objc_metaclasstype:=TPointerDef(search_named_unit_globaltype('OBJC','POBJC_CLASS',true).typedef);
        objc_superclasstype:=TPointerDef(search_named_unit_globaltype('OBJC','POBJC_SUPER',true).typedef);
        objc_idtype:=TPointerDef(search_named_unit_globaltype('OBJC','ID',true).typedef);
        objc_seltype:=TPointerDef(search_named_unit_globaltype('OBJC','SEL',true).typedef);
        objc_objecttype:=TRecordDef(search_named_unit_globaltype('OBJC','OBJC_OBJECT',true).typedef);
      end;


    procedure maybeloadcocoatypes;
      var
        TSym: TTypeSym;
        cocoaunit: string[15];
      begin
        if Assigned(objc_fastenumeration) then
          exit;
        if not(TargetInfo.system in [system_i386_iphonesim,system_aarch64_ios,system_x86_64_iphonesim,system_aarch64_iphonesim]) then
          cocoaunit:='COCOAALL'
        else
          cocoaunit:='IPHONEALL';
        TSym:=search_named_unit_globaltype(cocoaunit,'NSFASTENUMERATIONPROTOCOL',false);
        if Assigned(TSym) then
          objc_fastenumeration:=TObjectDef(TSym.typedef)
        else
          objc_fastenumeration:=nil;
        TSym:=search_named_unit_globaltype(cocoaunit,'NSFASTENUMERATIONSTATE',false);
        if Assigned(TSym) then
          objc_fastenumerationstate:=TRecordDef(TSym.typedef)
        else
          objc_fastenumerationstate:=nil;
      end;


    function use_vectorfpu(def : TDef) : boolean;
      begin
{$ifdef x86}
{$define use_vectorfpuimplemented}
        use_vectorfpu:=(is_single(def) and (CurrentSettings.FPUType in sse_singlescalar)) or
          (is_double(def) and (CurrentSettings.FPUType in sse_doublescalar)) or
          { Check vector types }
          (
            is_normal_array(def) and
            (ado_IsVector in TArrayDef(def).arrayoptions) and
            (
              (
                is_single(TArrayDef(def).elementdef) and
                (
                  { SSE or AVX XMM register }
                  ((TArrayDef(def).elecount = 4) and (CurrentSettings.FPUType in sse_singlescalar)) or
                  { AVX YMM register }
                  ((TArrayDef(def).elecount = 8) and (CurrentSettings.FPUType in fpu_avx_instructionsets))

                  or
                  { AVX512 ZMM register }
                  ((TArrayDef(def).elecount = 16) and (CurrentSettings.FPUType in [fpu_avx512f]))

                )
              ) or
              (
                is_double(TArrayDef(def).elementdef) and
                (
                  { SSE or AVX XMM register }
                  ((TArrayDef(def).elecount = 2) and (CurrentSettings.FPUType in sse_doublescalar)) or
                  { AVX YMM register }
                  ((TArrayDef(def).elecount = 4) and (CurrentSettings.FPUType in fpu_avx_instructionsets))

                  { AVX512 ZMM register }
                  or ((TArrayDef(def).elecount = 8) and (CurrentSettings.FPUType in [fpu_avx512f]))

                )
              )
            )
          );
{$endif x86}
{$ifdef aarch64}
{$define use_vectorfpuimplemented}
        use_vectorfpu:=true;
{$endif aarch64}

{$ifndef use_vectorfpuimplemented}
        use_vectorfpu:=false;
{$endif}
      end;

    procedure reset_all_default_types;
    { Those class pointers have to be set to nil manually }
    { after memory they point to have been released.      }
    { Necessary strictly for Textmode IDE.                }
    begin
       voidpointertype:=nil;           { pointer for Void-pointeddef }
       charpointertype:=nil;           { pointer for Char-pointeddef }
       widecharpointertype:=nil;       { pointer for WideChar-pointeddef }
       voidcodepointertype:=nil;       { pointer to code; corresponds to System.CodePointer }
       voidstackpointertype:=nil;      { the pointer type used for accessing parameters and local vars on the stack }
       parentfpvoidpointertype:=nil;   { void pointer with the size of the hidden parentfp parameter, passed to nested functions }
{$ifdef x86}
       voidnearpointertype:=nil;
       voidnearcspointertype:=nil;
       voidneardspointertype:=nil;
       voidnearsspointertype:=nil;
       voidnearespointertype:=nil;
       voidnearfspointertype:=nil;
       voidneargspointertype:=nil;

{$endif x86}
       cundefinedtype:=nil;
       cformaltype:=nil;               { unique formal definition }
       ctypedformaltype:=nil;          { unique typed formal definition }
       voidtype:=nil;                  { Void (procedure) }
       cansichartype:=nil;             { Char }
       cwidechartype:=nil;             { WideChar }
       cchartype:=nil;                 { either cansichartype or cwidechartype. Do not free }
       pasbool1type:=nil;              { boolean type }
       pasbool8type:=nil;
       pasbool16type:=nil;
       pasbool32type:=nil;
       pasbool64type:=nil;
       bool8type:=nil;
       bool16type:=nil;
       bool32type:=nil;
       bool64type:=nil;

       u8inttype:=nil;                 { 8-Bit unsigned integer }
       s8inttype:=nil;                 { 8-Bit signed integer }
       u16inttype:=nil;                { 16-Bit unsigned integer }
       s16inttype:=nil;                { 16-Bit signed integer }
       u24inttype:=nil;                { 24-Bit unsigned integer }
       s24inttype:=nil;                { 24-Bit signed integer }
       u32inttype:=nil;                { 32-Bit unsigned integer }
       s32inttype:=nil;                { 32-Bit signed integer }
       u40inttype:=nil;                { 40-Bit unsigned integer }
       s40inttype:=nil;                { 40-Bit signed integer }
       u48inttype:=nil;                { 48-Bit unsigned integer }
       s48inttype:=nil;                { 48-Bit signed integer }
       u56inttype:=nil;                { 56-Bit unsigned integer }
       s56inttype:=nil;                { 56-Bit signed integer }
       u64inttype:=nil;                { 64-bit unsigned integer }
       s64inttype:=nil;                { 64-bit signed integer }
       u128inttype:=nil;               { 128-bit unsigned integer }
       s128inttype:=nil;               { 128-bit signed integer }
       s32floattype:=nil;              { 32 bit floating point number }
       s64floattype:=nil;              { 64 bit floating point number }
       s80floattype:=nil;              { 80 bit floating point number }
       sc80floattype:=nil;             { 80 bit floating point number but stored like in C }
       s64currencytype:=nil;           { pointer to a currency type }
       cshortstringtype:=nil;          { pointer to type of short string const   }
       clongstringtype:=nil;           { pointer to type of long string const   }
       cansistringtype:=nil;           { pointer to type of ansi string const  }
       cwidestringtype:=nil;           { pointer to type of wide string const  }
       cunicodestringtype:=nil;
       openshortstringtype:=nil;
       openchararraytype:=nil;
       cfiletype:=nil;
       methodpointertype:=nil;         { typecasting of methodpointers to extract self }
       nestedprocpointertype:=nil;     { typecasting of nestedprocpointers to extract parentfp }
       hresultdef:=nil;
       typekindtype:=nil;              { def of TTypeKind for correct handling of GetTypeKind parameters }
       { we use only one variant def for every variant class }
       CVariantType:=nil;
       colevarianttype:=nil;
       { default integer type, normally s32inttype on 32 bit systems and s64bittype on 64 bit systems }
       sinttype:=nil;
       uinttype:=nil;
       { integer types corresponding to OS_SINT/OS_INT }
       ossinttype:=nil;
       osuinttype:=nil;
       { integer types corresponding to the ALU size, sizeof(aint) and the ALUSInt/ALUUInt types in the system unit }
       alusinttype:=nil;
       aluuinttype:=nil;
       { integer types corresponding to SizeInt and SizeUInt for the target platform }
       sizeuinttype:=nil;
       sizesinttype:=nil;
       { unsigned and signed ord type with the same size as a pointer }
       ptruinttype:=nil;
       ptrsinttype:=nil;
       { unsigned and signed ord type with the same size as a codepointer }
       codeptruinttype:=nil;
       codeptrsinttype:=nil;
       { several types to simulate more or less C++ objects for GDB }
       vmttype:=nil;
       vmtarraytype:=nil;
       { type of classrefs, used for stabs }
       pvmttype:=nil;
       { return type of the setjmp function }
       exceptionreasontype:=nil;

       class_tobject:=nil;
       class_tcustomattribute:=nil;
       interface_iunknown:=nil;
       interface_idispatch:=nil;
       rec_tguid:=nil;
       rec_jmp_buf:=nil;
       rec_exceptaddr:=nil;
       objc_metaclasstype:=nil;
       objc_superclasstype:=nil;
       objc_idtype:=nil;
       objc_seltype:=nil;
       objc_objecttype:=nil;
       objc_protocoltype:=nil;
       objc_fastenumeration:=nil;
       objc_fastenumerationstate:=nil;



       { Java base types }
       java_jlobject:=nil;
       java_jlthrowable:=nil;
       java_fpcbaserecordtype:=nil;
       java_jlstring:=nil;
       java_jlenum:=nil;
       java_juenumset:=nil;
       java_jubitset:=nil;
       java_ansistring:=nil;
       java_shortstring:=nil;
       java_procvarbase:=nil;

       { x86 vector types }
       x86_m64type:=nil;
       x86_m128type:=nil;
       x86_m128dtype:=nil;
       x86_m128itype:=nil;
       x86_m256type:=nil;
       x86_m256dtype:=nil;
       x86_m256itype:=nil;
    end;

end.
