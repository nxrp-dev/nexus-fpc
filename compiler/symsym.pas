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
       SysUtils,CUtils,compinnr,
       { target }
       GlobType,Globals,WideStr,ConstExp,
       { symtable }
       symconst,SymBase,symtype,symdef,defcmp,
       CClasses,
       { aasm }
       aasmbase,
       CPUInfo,cgbase,cgutils,parabase
       ;

    type
       { this class is the base for all symbol objects }
       TStoredSym = class(TSym)
       private
          procedure WriteEntry(ppufile: TCompilerPPUFile; ibnr: byte);
       protected
          procedure PPUWritePlatform(ppufile: TCompilerPPUFile);virtual;
          procedure PPULoadPlatform(ppufile: TCompilerPPUFile);virtual;
       public
          { this is Nil if the symbol has no RTTI attributes }
          RTTIAttributeList : TRTTIAttributeList;
          constructor create(st:TSymTyp;const n : TSymStr);
          constructor ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);virtual;
          { this is called directly after ppuload }
          procedure PPULoadSubEntries(ppufile:TCompilerPPUFile);virtual;
          { this is called directly after ppuwrite }
          procedure PPUWriteSubEntries(ppufile:TCompilerPPUFile);virtual;
          procedure deref; override;
          procedure buildderef; override;
          procedure RegisterSym; override;
       end;

       TLabelSym = class(TStoredSym)
          used,
          defined,
          nonlocal : boolean;
          { points to the matching node, only valid resultdef pass is run and
            the goto<->label relation in the node tree is created, should
            be a tnode }
          code : pointer;

          { points to the jump buffer }
          jumpbuf : TStoredSym;

          { when the label is defined in an asm block, this points to the
            generated asmlabel }
          asmblocklabel : TAsmLabel;
          constructor create(const n : TSymStr);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function mangledname:TSymStr;override;
       end;
       TLabelSymClass = class of TLabelSym;

       TUnitSym = class(TStoredSym)
          module : tobject; { tmodule }
          constructor create(const n : TSymStr;amodule : tobject);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
       end;
       TUnitSymClass = class of TUnitSym;

       TProgramParaSym = class(TStoredSym)
          isoindex : dword;
          constructor create(const n : TSymStr;i : dword);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
       end;
       TProgramParaSymClass = class of TProgramParaSym;

       TNamespaceSym = class(TStoredSym)
          unitsym:TSym;
          unitsymderef:TDeref;
          constructor create(const n : TSymStr);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
       end;
       TNamespaceSymClass = class of TNamespaceSym;

       TErrorSym = class(TSym)
          constructor create;
          procedure RegisterSym; override;
       end;

       { tprocsym }

       TProcSym = class(TStoredSym)
       protected type
          TProcDefComparer = function(pd:TProcDef;arg:tobject):TEqualType;
       protected
          FProcdefList   : TFPObjectList;
          FProcdefDerefList : TFPList;
          fgenprocsymovlds : TFPObjectList;
          fgenprocsymovldsderefs : TFPList;

          function find_procdef_with_comparer(comparer:TProcDefComparer;arg:tobject):TProcDef;
          class function compare_procvardef(pd:TProcDef;arg:tobject):TEqualType;static;
          class function compare_funcrefdef(pd:TProcDef;arg:tobject):TEqualType;static;
       public
          constructor create(const n : TSymStr);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          { writes all declarations except the specified one }
          procedure write_parameter_lists(skipdef:TProcDef);
          { tests, if all procedures definitions are defined and not }
          { only forward                                             }
          procedure check_forward; virtual;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function find_procdef_bytype(pt:TProcTypeOption):TProcDef;
          function find_bytype_parameterless(pt:TProcTypeOption):TProcDef;
          function find_procdef_bypara(para:TFPObjectList;retdef:TDef;cpoptions:TCompareParasOptions):TProcDef;
          function find_procdef_bytype_and_para(pt:TProcTypeOption;para:TFPObjectList;retdef:TDef;cpoptions:TCompareParasOptions):TProcDef;
          function find_procdef_byoptions(ops:TProcOptions): TProcDef;
          function find_procdef_byprocvardef(d:TProcVarDef):TProcDef;
          function find_procdef_byfuncrefdef(d:TObjectDef):TProcDef;
          function find_procdef_assignment_operator(fromdef,todef:TDef;var besteq:TEqualType;isexplicit:boolean):TProcDef;
          function find_procdef_enumerator_operator(fromdef,todef:TDef;var besteq:TEqualType):TProcDef;
          procedure add_generic_overload(sym:TProcSym);
          function could_be_implicitly_specialized:boolean;inline;
          property ProcdefList:TFPObjectList read FProcdefList;
          { only valid if sp_generic_dummy is set and either an overload was
            added using add_generic_overload or this was loaded from a ppu }
          property genprocsymovlds:TFPObjectList read fgenprocsymovlds;
       end;
       TProcSymClass = class of TProcSym;

       TTypeSym = class(TStoredSym)
       public
          typedef      : TDef;
          typedefderef : TDeref;
          fprettyname : AnsiString;
          constructor create(const n : TSymStr;def:TDef);virtual;
          destructor Destroy;override;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function prettyname : string;override;
       end;
       TTypeSymClass = class of TTypeSym;

       TAbstractVarSym = class(TStoredSym)
          varoptions    : TVarOptions;
          varspez       : TVarSpez;  { sets the type of access }
          varregable    : TVarRegable;
          varstate      : TVarState;
          {could also be part of tabstractnormalvarsym, but there's
           one byte left here till the next 4 byte alignment        }
          varsymaccess  : TVarSymAccessFlags;
          constructor create(st:TSymTyp;const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
          constructor ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderef;override;
          procedure deref;override;
          function  getsize : asizeint;
          function  getpackedbitsize : LongInt;
          function  is_regvar(refpara: boolean):boolean;
        private
          _vardef     : TDef;
          vardefderef : TDeref;

          function get_addr_taken: boolean;
          function get_different_scope: boolean;
          procedure setregable;
          procedure setvardef(const def: TDef);
          procedure setvardef_and_regable(def:TDef);
          procedure set_addr_taken(AValue: boolean);
          procedure set_different_scope(AValue: boolean);
        public
          property vardef: TDef read _vardef write setvardef_and_regable;
          property addr_taken: boolean read get_addr_taken write set_addr_taken;
          property different_scope: boolean read get_different_scope write set_different_scope;
      end;

      TFieldVarSym = class(TAbstractVarSym)
          { offset in record/object, for bitpacked fields the offset is
            given in bit, else in bytes }
          fieldoffset   : asizeint;

          externalname  : PShortString;
{$ifdef symansistr}
          cachedmangledname: TSymStr; { mangled name for ObjC or Java }
{$else symansistr}
          cachedmangledname: PShortString; { mangled name for ObjC or Java }
{$endif symansistr}
          constructor create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure set_externalname(const s:string);virtual;
          function bitoffset: ASizeUInt;
          function mangledname:TSymStr;override;
          destructor Destroy;override;
{$ifdef DEBUG_NODE_XML}
        public
          procedure XMLPrintFieldData(var T: Text);
{$endif DEBUG_NODE_XML}
      end;
      TFieldVarSymClass = class of TFieldVarSym;

      TAbstractNormalVarSym = class(TAbstractVarSym)
          defaultconstsym : TSym;
          defaultconstsymderef : TDeref;
          { register/reference for local var }
          localloc      : TLocation;
          { initial location so it can still be initialized later after the location was changed by SSA }
          initialloc    : TLocation;
          { migrated to a parentfpstruct because of nested access (not written to ppu, because not important and would change interface crc) }
          inparentfpstruct : boolean;
          { the variable is not living at entry of the scope, so it does not need to be initialized if it is a reg. var
            (not written to ppu, because not important and would change interface crc) }
          noregvarinitneeded : boolean;
          { not stored in PPU! }
          capture_sym : TSym;
          constructor create(st:TSymTyp;const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
          constructor ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
          function globalasmsym: boolean;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderef;override;
          procedure deref;override;
          function is_captured:boolean;
      end;

      TLocalVarSym = class(TAbstractNormalVarSym)
          constructor create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
      end;
      TLocalVarSymClass = class of TLocalVarSym;

      TParaVarSym = class(TAbstractNormalVarSym)
          paraloc       : array[callerside..calleeside] of TCGPara;
          paranr        : word; { position of this parameter }
          { in MacPas mode, "univ" parameters mean that type checking should
            be disabled, except that the size of the passed parameter must
            match the size of the formal parameter }
          univpara      : boolean;
{$ifdef EXTDEBUG}
          eqval         : TEqualType;
{$endif EXTDEBUG}
          constructor create(const n : TSymStr;nr:word;vsp:TVarSpez;def:TDef;vopts:TVarOptions);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          function needs_finalization: boolean;
          function is_used: boolean;
      end;
      TParaVarSymClass = class of TParaVarSym;

      TStaticVarSym = class(TAbstractNormalVarSym)
      protected
{$ifdef symansistr}
          _mangledbasename,
          _mangledname : TSymStr;
{$else symansistr}
          _mangledbasename,
          _mangledname : PShortString;
{$endif symansistr}
      public
          section : AnsiString;
          { if a text buffer has been defined as being initialized from command line
            parameters as it is done by iso pascal with the program symbols,
            isoindex contains the parameter number }
          isoindex : dword;
          { if this static variable was created based on a class field variable then this is set
            to the symbol of the corresponding class field }
          fieldvarsym : TFieldVarSym;
          fieldvarsymderef : TDeref;
          constructor create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);virtual;
          constructor create_dll(const n : TSymStr;vsp:TVarSpez;def:TDef);virtual;
          constructor create_C(const n: TSymStr; const mangled : TSymStr;vsp:TVarSpez;def:TDef);virtual;
          constructor create_from_fieldvar(const n: TSymStr;fieldvar:TFieldVarSym);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function mangledname:TSymStr;override;
          procedure set_mangledbasename(const s: TSymStr);
          function mangledbasename: TSymStr;
          procedure set_mangledname(const s:TSymStr);virtual;
          procedure set_raw_mangledname(const s:TSymStr);
      end;
      TStaticVarSymClass = class of TStaticVarSym;

      TAbsoluteVarSym = class(TAbstractVarSym)
      public
         abstyp  : TAbsoluteTyp;
         asmname : PShortString;
         addroffset : PUint;
         ref     : TPropAccessList;
         constructor create(const n : TSymStr;def:TDef);virtual;
         constructor create_ref(const n : TSymStr;def:TDef;_ref:TPropAccessList);virtual;
	 procedure adjust_varregable;
         destructor  Destroy;override;
         constructor ppuload(ppufile:TCompilerPPUFile);
         procedure buildderef;override;
         procedure deref;override;
         function  mangledname : TSymStr;override;
         { do not override this routine in platform-specific subclasses,
           override ppuwrite_platform instead }
         procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
         { returns the symbol type of the local variable or local parameter
           referenced by the absolute symbol }
         function reftyp : TSymTyp;
      end;
      TAbsoluteVarSymClass = class of TAbsoluteVarSym;

       TPropAccessListTypes=(palt_none,palt_read,palt_write,palt_stored);

       TPropertySym = class(TStoredSym)
         protected
           procedure finalize_getter_or_setter_for_sym(GetSet: TPropAccessListTypes; sym: TSym; fielddef: TDef; accessordef: TProcDef); virtual;
         public
          propoptions   : TPropertyOptions;
          overriddenpropsym : TPropertySym;
          overriddenpropsymderef : TDeref;
          propdef       : TDef;
          propdefderef  : TDeref;
          indexdef      : TDef;
          indexdefderef : TDeref;
          index,
          default       : LongInt;
          dispid        : LongInt;
          propaccesslist: array[TPropAccessListTypes] of TPropAccessList;
          parast : TSymTable;
          constructor create(const n : TSymStr);virtual;
          destructor  Destroy;override;
          constructor ppuload(ppufile:TCompilerPPUFile);
          function  getsize : asizeint;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
          function getpropaccesslist(pap:TPropAccessListTypes;out plist:TPropAccessList):boolean;
          { copies the settings of the current propertysym to p; a bit like
            a form of getcopy, but without the name }
          procedure makeduplicate(p: TPropertySym; readprocdef, writeprocdef: TProcDef; out paranr: word);
          procedure add_accessor_parameters(readprocdef, writeprocdef: TProcDef);
          procedure add_index_parameter(var paranr: word; readprocdef, writeprocdef: TProcDef);
          { set up the accessors for this property }
          procedure add_getter_or_setter_for_sym(GetSet: TPropAccessListTypes; sym: TSym; fielddef: TDef; accessordef: TProcDef);
          procedure register_override(overriddenprop: TPropertySym);
          { inherit the read/write property }
          procedure inherit_accessor(GetSet: TPropAccessListTypes); virtual;
       end;
       TPropertySymClass = class of TPropertySym;

       TConstValue = record
         case integer of
         0: (valueord : TConstExprInt);
         1: (valueordptr : TConstPtrUInt);
         2: (valueptr : pointer; len : LongInt);
         3: (valuews : TCompilerWideString);
       end;

       TConstSym = class(TStoredSym)
          constdef    : TDef;
          constdefderef : TDeref;
          consttyp    : TConstTyp;
          value       : TConstValue;
          constructor create_ord(const n : TSymStr;t : TConstTyp;v : TConstExprInt;def:TDef);virtual;
          constructor create_ordptr(const n : TSymStr;t : TConstTyp;v : TConstPtrUInt;def:TDef);virtual;
          constructor create_ptr(const n : TSymStr;t : TConstTyp;v : pointer;def:TDef);virtual;
          constructor create_string(const n : TSymStr;t : TConstTyp;str:pchar;l:LongInt;def:TDef);virtual;
          constructor create_wstring(const n : TSymStr;t : TConstTyp;pw:TCompilerWideString);virtual;
          constructor create_undefined(const n : TSymStr;def:TDef);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor  Destroy;override;
          procedure buildderef;override;
          procedure deref;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
{$ifdef DEBUG_NODE_XML}
        public
          procedure XMLPrintConstData(var T: Text);
{$endif DEBUG_NODE_XML}
       end;
       TConstSymClass = class of TConstSym;

       TEnumSym = class(TStoredSym)
          value      : LongInt;
          definition : TEnumDef;
          definitionderef : TDeref;
          constructor create(const n : TSymStr;def : TEnumDef;v : LongInt);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          procedure buildderef;override;
          procedure deref;override;
       end;
       TEnumSymClass = class of TEnumSym;

       TSysSym = class(TStoredSym)
          number : TInlineNumber;
          constructor create(const n : TSymStr;l : TInlineNumber);virtual;
          constructor ppuload(ppufile:TCompilerPPUFile);
          destructor  Destroy;override;
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          class function find_by_number(l:LongInt):TSysSym;
       end;
       TSysSymClass = class of TSysSym;

    const
       maxmacrolen=16*1024;

    type
       TMacro = class(TStoredSym)
          {Normally true, but false when a previously defined macro is undef-ed}
          defined : boolean;
          {True if this is a mac style compiler variable, in which case no macro
           substitutions shall be done.}
          is_compiler_var : boolean;
          { true if the macro is a C macro, i.e used := }
          is_c_macro : boolean;
          {Whether the macro was used. NOTE: A use of a macro which was never defined}
          {e. g. an IFDEF which returns false, will not be registered as used,}
          {since there is no place to register its use. }
          is_used : boolean;
          buftext : TAnsiCharDynArray;
          buflen  : LongInt;
          constructor create(const n : TSymStr);
          constructor ppuload(ppufile:TCompilerPPUFile);
          { do not override this routine in platform-specific subclasses,
            override ppuwrite_platform instead }
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;final;
          destructor  Destroy;override;
          function allocate_buftext(len:LongInt) : pchar;
          procedure free_buftext;
          function GetCopy:TMacro;
       end;

    var
       generrorsym : TSym;

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
    function internal_static_field_name(const fieldname: TSymStr): TSymStr;
    function get_high_value_sym(vs: TParaVarSym):TAbstractVarSym; { marking it as inline causes IE 200311075 during loading from ppu file }

    procedure check_hints(const srsym: TSym; const symoptions: TSymOptions; const deprecatedmsg : PShortString);inline;
    procedure check_hints(const srsym: TSym; const symoptions: TSymOptions; const deprecatedmsg : PShortString;filepos:TFilePosInfo);

    function same_constvalue(consttyp:TConstTyp;const value1,value2:TConstValue):boolean;

implementation

    uses
       { global }
       Verbose,CMsgs,
       { target }
       Systems,
       { symtable }
       defutil,SymTable,
       FModule,
       { tree }
       node,
       { aasm }
       AAsmData,
       { codegen }
       paramgr,
       ProcInfo,
       { ppu }
       EntFile,PPU
       ;

{****************************************************************************
                               Helpers
****************************************************************************}

    function internal_static_field_name(const fieldname: TSymStr): TSymStr;
      begin
        result:='$_static_'+fieldname;
      end;


    function get_high_value_sym(vs: TParaVarSym):TAbstractVarSym;
      begin
        result := TAbstractVarSym(vs.owner.Find('high'+vs.name));
      end;


    function same_constvalue(consttyp:TConstTyp;const value1,value2:TConstValue):boolean;
      begin
        result:=false;
        case consttyp of
          constnone,
          constnil:
            result:=true;
          constord:
            result:=value1.valueord=value2.valueord;
          constpointer:
            result:=value1.valueordptr=value2.valueordptr;
          conststring,
          constreal,
          constset,
          constresourcestring,
          constwresourcestring,
          constwstring,
          constguid: begin
            if value1.len<>value2.len then
              exit(false);
            result:=CompareByte(value1.valueptr^,value2.valueptr^,value1.len)=0;
          end;
        end;
      end;


    procedure check_hints(const srsym: TSym; const symoptions: TSymOptions; const deprecatedmsg : PShortString);
      begin
        check_hints(srsym,symoptions,deprecatedmsg,CurrentFilePos);
      end;


    procedure check_hints(const srsym: TSym; const symoptions: TSymOptions; const deprecatedmsg : PShortString;filepos:TFilePosInfo);
      var
        def : TDef;
        name : TMsgStr;
      begin
        if not Assigned(srsym) then
          InternalError(200602051);
        if symoptions*[sp_hint_deprecated,sp_hint_experimental,sp_hint_platform,sp_hint_library,sp_hint_unimplemented]<>[] then
          begin
            name:=srsym.realname;
            def:=TDef(srsym.owner.defowner);
            if Assigned(def) then
              name:=def.typesymbolprettyname+'.'+name;
          end
        else
          name:='';
        if sp_hint_deprecated in symoptions then
          if (sp_has_deprecated_msg in symoptions) and (deprecatedmsg <> nil) then
            MessagePos2(filepos,sym_w_deprecated_symbol_with_msg,name,deprecatedmsg^)
          else
            MessagePos1(filepos,sym_w_deprecated_symbol,name);
        if sp_hint_experimental in symoptions then
          MessagePos1(filepos,sym_w_experimental_symbol,name);
        if sp_hint_platform in symoptions then
          MessagePos1(filepos,sym_w_non_portable_symbol,name);
        if sp_hint_library in symoptions then
          MessagePos1(filepos,sym_w_library_symbol,name);
        if sp_hint_unimplemented in symoptions then
          MessagePos1(filepos,sym_w_non_implemented_symbol,name);
      end;

{****************************************************************************
                          TSYM (base for all symtypes)
****************************************************************************}

    constructor TStoredSym.create(st:TSymTyp;const n : TSymStr);
      begin
         inherited create(st,n);
      end;


    constructor TStoredSym.ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
      begin
{$ifdef symansistr}
         inherited Create(st,ppufile.GetAnsiString);
{$else symansistr}
         inherited Create(st,ppufile.GetString);
{$endif symansistr}
         SymId:=ppufile.GetLongInt;
         CurrentModule.symlist[SymId]:=self;
         ppufile.getposinfo(fileinfo);
         visibility:=TVisibility(ppufile.GetByte);
         ppufile.GetSet(TPPUSet2(symoptions));
         if sp_has_deprecated_msg in symoptions then
           deprecatedmsg:=ppufile.GetPShortString
         else
           deprecatedmsg:=nil;
         RTTIAttributeList:=TRTTIAttributeList.ppuload(ppufile);
      end;


    procedure TStoredSym.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldcrc : boolean;
      begin
{$ifdef symansistr}
         ppufile.PutAnsiString(realname);
{$else}
         ppufile.PutString(realname);
{$endif}
         ppufile.PutLongInt(SymId);
         ppufile.putposinfo(fileinfo);
         ppufile.PutByte(byte(visibility));
         { symoptions can differ between interface and implementation, except
           for overload (this is checked in pdecsub.proc_add_definition() )

           These differences can lead to compiler crashes, so ignore them.
           This does mean that changing e.g. the "deprecated" state of a symbol
           by itself will not trigger a recompilation of dependent units.
         }
         oldcrc:=ppufile.DoCRC;
         ppufile.DoCRC:=false;
         ppufile.PutSet(TPPUSet2(symoptions));
         if sp_has_deprecated_msg in symoptions then
           ppufile.PutString(deprecatedmsg^);
         ppufile.DoCRC:=oldcrc;
         TRTTIAttributeList.ppuwrite(RTTIAttributeList,ppufile);
      end;


    procedure TStoredSym.PPULoadSubEntries(ppufile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPULoadSubEntries(RTTIAttributeList,ppufile);
      end;


    procedure TStoredSym.PPUWriteSubEntries(ppufile: TCompilerPPUFile);
      begin
        TRTTIAttributeList.PPUWriteSubEntries(RTTIAttributeList,ppufile);
      end;


    procedure TStoredSym.deref;
      begin
        inherited;
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.deref;
      end;


    procedure TStoredSym.buildderef;
      begin
        inherited;
        if not registered then
          RegisterSym;
        if Assigned(RTTIAttributeList) then
          RTTIAttributeList.buildderef;
      end;


    procedure TStoredSym.WriteEntry(ppufile: TCompilerPPUFile; ibnr: byte);
      begin
        PPUWritePlatform(ppufile);
        ppufile.WriteEntry(ibnr);
      end;


    procedure TStoredSym.PPUWritePlatform(ppufile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;

    procedure TStoredSym.PPULoadPlatform(ppufile: TCompilerPPUFile);
      begin
        { by default: do nothing }
      end;


    destructor TStoredSym.Destroy;
      begin
        RTTIAttributeList.free;
        RTTIAttributeList := nil;
        inherited Destroy;
      end;


    procedure TStoredSym.RegisterSym;
      var
        tmod : TModule;
      begin
        if registered then
          exit;
        if Assigned(owner) then
          begin
            tmod:=find_module_from_symtable(owner);
            if Assigned(tmod) and Assigned(CurrentModule) and (tmod<>CurrentModule) then
              begin
                comment(VError,'Symbol '+realname+' from module '+tmod.MainSource+' registered with current module '+CurrentModule.MainSource);
              end;
            if not Assigned(tmod) then
              tmod:=CurrentModule;
          end
        else
          tmod:=CurrentModule;
        { Register in current_module }
        if Assigned(tmod) then
          begin
            tmod.symlist.Add(self);
            SymId:=tmod.symlist.Count-1;
          end
        else
          SymId:=symid_registered_nost;
      end;

{****************************************************************************
                                 TLABELSYM
****************************************************************************}

    constructor TLabelSym.create(const n : TSymStr);
      begin
         inherited create(labelsym,n);
         used:=false;
         defined:=false;
         nonlocal:=false;
         code:=nil;
      end;


    constructor TLabelSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(labelsym,ppufile);
         code:=nil;
         used:=false;
         nonlocal:=false;
         defined:=true;
         PPULoadPlatform(ppufile);
      end;


    procedure TLabelSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         if owner.symtabletype=GlobalSymTable then
           Message(sym_e_ill_label_decl)
         else
           begin
              inherited ppuwrite(ppufile);
              WriteEntry(ppufile,IBLabelSym);
           end;
      end;


   function TLabelSym.mangledname:TSymStr;
     begin
       if (asmblocklabel=nil) then
         begin
           if nonlocal then
             CurrentAsmData.getglobaljumplabel(asmblocklabel)
           else
             CurrentAsmData.getjumplabel(asmblocklabel);
         end;
       result:=asmblocklabel.name;
     end;

{****************************************************************************
                                  TUNITSYM
****************************************************************************}

    constructor TUnitSym.create(const n : TSymStr;amodule : tobject);
      begin
         inherited create(unitsym,n);
         module:=amodule;
      end;

    constructor TUnitSym.ppuload(ppufile:TCompilerPPUFile);

      begin
         inherited ppuload(unitsym,ppufile);
         module:=nil;
         PPULoadPlatform(ppufile);
      end;

    destructor TUnitSym.Destroy;
      begin
         inherited Destroy;
      end;

    procedure TUnitSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         WriteEntry(ppufile,IBUnitSym);
      end;

{****************************************************************************
                             TPROGRAMPARASYM
****************************************************************************}

    constructor TProgramParaSym.create(const n : TSymStr; i : dword);
      begin
         inherited create(programparasym,n);
         isoindex:=i;
      end;

    constructor TProgramParaSym.ppuload(ppufile : TCompilerPPUFile);
      begin
        { program parameter syms (iso pascal style) might be never written to a ppu }
        InternalError(2015050102);
      end;

    destructor TProgramParaSym.Destroy;
      begin
       inherited Destroy;
      end;

    procedure TProgramParaSym.ppuwrite(ppufile : TCompilerPPUFile);
      begin
        { program parameter syms (iso pascal style) might be never written to a ppu }
        InternalError(2015050101);
      end;


{****************************************************************************
                                TNAMESPACESYM
****************************************************************************}

    constructor TNamespaceSym.create(const n : TSymStr);
      begin
         inherited create(namespacesym,n);
         unitsym:=nil;
         unitsymderef.reset;
      end;

    constructor TNamespaceSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(namespacesym,ppufile);
         ppufile.getderef(unitsymderef);
         PPULoadPlatform(ppufile);
      end;

    procedure TNamespaceSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(unitsymderef);
         WriteEntry(ppufile,IBNamespaceSym);
      end;

    procedure TNamespaceSym.buildderef;
      begin
        inherited buildderef;
        unitsymderef.build(unitsym);
      end;

    procedure TNamespaceSym.deref;
      begin
        inherited deref;
        unitsym:=TSym(unitsymderef.resolve);
      end;


{****************************************************************************
                                  TPROCSYM
****************************************************************************}

    constructor TProcSym.create(const n : TSymStr);
      var
        i: LongInt;
      begin
         if not(ts_lowercase_proc_start in CurrentSettings.TargetSwitches) or
            (n='') then
           inherited create(procsym,n)
         else
           begin
             { YToX -> yToX
               RC64Encode -> rc64Encode
               Test -> test
             }
             i:=2;
             while i<=length(n) do
               begin
                 if not(n[i] in ['A'..'Z']) then
                   begin
                     if (i>2) and
                        (n[i] in ['a'..'z']) then
                       dec(i);
                     break;
                   end;
                 inc(i);
               end;
             inherited create(procsym,lower(copy(n,1,i-1))+copy(n,i,length(n)));
           end;
         FProcdefList:=TFPObjectList.Create(false);
         FProcdefderefList:=nil;
         { the tprocdef have their own symoptions, make the procsym
           always visible }
         visibility:=vis_public;
      end;


    constructor TProcSym.ppuload(ppufile:TCompilerPPUFile);
      var
         symderef,
         pdderef : TDeref;
         i,
         symcnt,
         pdcnt : LongInt;
      begin
         inherited ppuload(procsym,ppufile);
         FProcdefList:=TFPObjectList.Create(false);
         FProcdefDerefList:=TFPList.Create;
         pdcnt:=ppufile.GetWord;
         for i:=1 to pdcnt do
          begin
            ppufile.getderef(pdderef);
            FProcdefDerefList.Add(Pointer(PtrInt(pdderef.dataidx)));
          end;
         if sp_generic_dummy in symoptions then
           begin
             fgenprocsymovlds:=TFPObjectList.create(false);
             fgenprocsymovldsderefs:=TFPList.create;
             symcnt:=ppufile.GetWord;
             for i:=1 to symcnt do
               begin
                 ppufile.getderef(symderef);
                 fgenprocsymovldsderefs.add(pointer(ptrint(symderef.dataidx)));
               end;
           end;
         PPULoadPlatform(ppufile);
      end;


    destructor TProcSym.Destroy;
      begin
        FProcdefList.Free;
        FProcdefList := nil;
        FProcdefDerefList.Free;
        FProcdefDerefList := nil;
        fgenprocsymovlds.free;
        fgenprocsymovlds := nil;
        fgenprocsymovldsderefs.free;
        fgenprocsymovldsderefs := nil;
        inherited Destroy;
      end;


    procedure TProcSym.ppuwrite(ppufile:TCompilerPPUFile);
      var
         i : LongInt;
         d : TDeref;
      begin
         inherited ppuwrite(ppufile);
         if fprocdefdereflist=nil then
           InternalError(2013121801);
         ppufile.PutWord(FProcdefDerefList.Count);
         for i:=0 to FProcdefDerefList.Count-1 do
           begin
             d.dataidx:=PtrInt(FProcdefDerefList[i]);
             ppufile.putderef(d);
           end;
         if sp_generic_dummy in symoptions then
           begin
             if not Assigned(fgenprocsymovldsderefs) then
               InternalError(2021010301);
             ppufile.PutWord(fgenprocsymovldsderefs.count);
             for i:=0 to fgenprocsymovldsderefs.count-1 do
               begin
                 d.dataidx:=ptrint(fgenprocsymovldsderefs[i]);
                 ppufile.putderef(d);
               end;
           end;
         WriteEntry(ppufile,IBProcSym);
      end;


    procedure TProcSym.write_parameter_lists(skipdef:TProcDef);
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if pd<>skipdef then
              MessagePos1(pd.fileinfo,sym_e_param_list,pd.fullprocname(false));
           end;
      end;


    procedure TProcSym.check_forward;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            { Don't check for is_specialization, but whether it's somehow part
              of a specialization }
            if (pd.owner=owner) and (pd.forwarddef) and not (df_specialization in pd.defoptions) then
              begin
                { For mode macpas. Make implicit externals (procedures declared in the interface
                  section which do not have a counterpart in the implementation)
                  to be an imported procedure }
                if (m_mac in CurrentSettings.ModeSwitches) and
                   (pd.interfacedef) then
                  begin
                    pd.setmangledname(TargetInfo.CPrefix+TProcDef(pd).procsym.realname);
                    if (not CurrentModule.interface_only) then
                      MessagePos1(pd.fileinfo,sym_w_forward_not_resolved,pd.fullprocname(false));
                  end
                else
                  begin
                    MessagePos1(pd.fileinfo,sym_e_forward_not_resolved,pd.fullprocname(false));
                  end;
                { Turn further error messages off }
                pd.forwarddef:=false;
              end;
          end;
      end;


    procedure TProcSym.buildderef;
      var
        i  : LongInt;
        pd : TProcDef;
        d  : TDeref;
        sym : TProcSym;
      begin
        inherited;
        if not Assigned(FProcdefDerefList) then
          FProcdefDerefList:=TFPList.Create
        else
          FProcdefDerefList.Clear;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            { only write the proc definitions that belong
              to this procsym and are in the global symtable }
            if pd.owner=owner then
              begin
                d.build(pd);
                FProcdefDerefList.Add(Pointer(PtrInt(d.dataidx)));
              end;
          end;
        if sp_generic_dummy in symoptions then
          begin
            if not Assigned(fgenprocsymovldsderefs) then
              fgenprocsymovldsderefs:=TFPList.create
            else
              fgenprocsymovldsderefs.clear;
            { this might happen for procsyms in classes that override symbols
              in a parent class that generic overloads }
            if Assigned(fgenprocsymovlds) then
              begin
                fgenprocsymovldsderefs.capacity:=fgenprocsymovldsderefs.count+fgenprocsymovlds.count;
                for i:=0 to fgenprocsymovlds.count-1 do
                  begin
                    sym:=TProcSym(fgenprocsymovlds[i]);
                    d.build(sym);
                    fgenprocsymovldsderefs.add(pointer(ptrint(d.dataidx)));
                  end;
              end;
          end;
      end;


    procedure TProcSym.deref;
      var
        i  : LongInt;
        pd : TProcDef;
        d  : TDeref;
        sym : TSym;
      begin
        { Clear all procdefs }
        ProcdefList.Clear;
        if not Assigned(FProcdefDerefList) then
          InternalError(200611031);
        ProcdefList.capacity:=FProcdefDerefList.count;
        for i:=0 to FProcdefDerefList.Count-1 do
          begin
            d.dataidx:=PtrInt(FProcdefDerefList[i]);
            pd:=TProcDef(d.resolve);
            ProcdefList.Add(pd);
          end;
        if sp_generic_dummy in symoptions then
          begin
            {if not assigned(fgenprocsymovlds) then
              internalerror(2021010603);}
            if not Assigned(fgenprocsymovldsderefs) then
              InternalError(2021010302);
            if Assigned(fgenprocsymovlds) then
              begin
                fgenprocsymovlds.clear;
                fgenprocsymovlds.capacity:=fgenprocsymovldsderefs.count;
                for i:= 0 to fgenprocsymovldsderefs.count-1 do
                  begin
                    d.dataidx:=ptrint(fgenprocsymovldsderefs[i]);
                    sym:=TProcSym(d.resolve);
                    fgenprocsymovlds.add(sym);
                  end;
              end;
          end;
      end;

    function TProcSym.Find_procdef_bytype(pt:TProcTypeOption):TProcDef;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        result:=nil;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if pd.proctypeoption=pt then
              begin
                result:=pd;
                exit;
              end;
          end;
      end;


    function TProcSym.find_bytype_parameterless(pt: TProcTypeOption): TProcDef;
      var
        i,j : LongInt;
        pd  : TProcDef;
        found : boolean;
      begin
        result:=nil;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if (pd.proctypeoption=pt) then
              begin
                found:=true;
                for j:=0 to pd.paras.count-1 do
                  begin
                    if not(vo_is_hidden_para in TParaVarSym(pd.paras[j]).varoptions) then
                      begin
                        found:=false;
                        break;
                      end;
                  end;
                if found then
                  begin
                    result:=pd;
                    exit;
                  end;
              end;
          end;
      end;


    function check_procdef_paras(pd:TProcDef;para:TFPObjectList;retdef:TDef;
                                            cpoptions:TCompareParasOptions): TProcDef;
      var
        eq: TEqualType;
      begin
        result:=nil;
        if Assigned(retdef) then
          eq:=compare_defs(retdef,pd.returndef,nothingn)
        else
          eq:=te_equal;
        if (eq>=te_equal) or
           ((cpo_allowconvert in cpoptions) and (eq>te_incompatible)) then
          begin
            eq:=compare_paras(para,pd.paras,cp_value_equal_const,cpoptions);
            if (eq>=te_equal) or
               ((cpo_allowconvert in cpoptions) and (eq>te_incompatible)) then
              begin
                result:=pd;
                exit;
              end;
          end;
      end;


    function TProcSym.Find_procdef_bypara(para:TFPObjectList;retdef:TDef;
                                            cpoptions:TCompareParasOptions):TProcDef;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        result:=nil;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            result:=check_procdef_paras(pd,para,retdef,cpoptions);
            if Assigned(result) then
              exit;
          end;
      end;


    function TProcSym.find_procdef_bytype_and_para(pt:TProcTypeOption;
               para:TFPObjectList;retdef:TDef;cpoptions:TCompareParasOptions):TProcDef;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        result:=nil;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if pd.proctypeoption=pt then
              begin
                result:=check_procdef_paras(pd,para,retdef,cpoptions);
                if Assigned(result) then
                  exit;
              end;
          end;
      end;


    function TProcSym.find_procdef_byoptions(ops: TProcOptions): TProcDef;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        result:=nil;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if ops * pd.procoptions = ops then
              begin
                result:=pd;
                exit;
              end;
          end;
      end;

    function TProcSym.find_procdef_with_comparer(comparer:TProcDefComparer;arg:tobject):TProcDef;
      var
        i  : LongInt;
        bestpd,
        pd : TProcDef;
        eq,besteq : TEqualType;
        sym: TSym;
        ps: TProcSym;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for procvardef. When there are multiple
          matches it returns nil.}
        result:=nil;
        bestpd:=nil;
        besteq:=te_incompatible;
        ps:=self;
        repeat
          for i:=0 to ps.ProcdefList.Count-1 do
            begin
              pd:=TProcDef(ps.ProcdefList[i]);
              eq:=comparer(pd,arg);
              if eq>=te_convert_l1 then
                begin
                  { multiple procvars with the same equal level }
                  if Assigned(bestpd) and
                     (besteq=eq) then
                    exit;
                  if eq>besteq then
                    begin
                      besteq:=eq;
                      bestpd:=pd;
                    end;
                end;
            end;
          { maybe TODO: also search class helpers? -- this code is similar to
            what happens in htypechk in
            tcallcandidates.collect_overloads_in_struct: keep searching in
            parent types in case the currently found procdef is marked as
            "overload" and we haven't found a proper match yet }
          if Assigned(ps.owner.defowner) and
             (ps.owner.defowner.typ=objectdef) and
             Assigned(TObjectDef(ps.owner.defowner).childof) and
             (not Assigned(bestpd) or
              (po_overload in bestpd.procoptions)) then
            begin
              sym:=TSym(TObjectDef(ps.owner.defowner).childof.SymTable.find(ps.name));
              if Assigned(sym) and
                 (sym.typ=procsym) then
                ps:=TProcSym(sym)
              else
                ps:=nil;
            end
          else
            ps:=nil;
        until (besteq>=te_equal) or
              not Assigned(ps);
        result:=bestpd;
      end;


    class function TProcSym.compare_procvardef(pd:TProcDef;arg:tobject):TEqualType;
      begin
        result:=proc_to_procvar_equal(pd,TProcVarDef(arg),false);
      end;


    class function TProcSym.compare_funcrefdef(pd:TProcDef;arg:tobject):TEqualType;
      begin
        result:=proc_to_funcref_equal(pd,TObjectDef(arg));
      end;


    function TProcSym.Find_procdef_byprocvardef(d:TProcVarDef):TProcDef;
      begin
        result:=find_procdef_with_comparer(@compare_procvardef,d);
      end;


    function TProcSym.Find_procdef_byfuncrefdef(d:TObjectDef):TProcDef;
      begin
        if not is_invokable(d) then
          InternalError(2022033001);
        result:=find_procdef_with_comparer(@compare_funcrefdef,d);
      end;


    function TProcSym.Find_procdef_assignment_operator(fromdef,todef:TDef;var besteq:TEqualType;isexplicit:boolean):TProcDef;
      var
        paraidx, realparamcount,
        i, j : LongInt;
        bestpd,
        hpd,
        pd : TProcDef;
        convtyp : TConvertType;
        eq      : TEqualType;
        shortstringcount : LongInt;
        checkshortstring,
        isgenshortstring : boolean;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for fromdef and todef. }
        result:=nil;
        bestpd:=nil;
        besteq:=te_incompatible;
        { special handling for assignment operators overloads to shortstring:
          for implicit assignment we pick the ShortString one if available and
          only pick one with specific length if it is the *only* one }
        shortstringcount:=0;
        checkshortstring:=not isexplicit and
                          is_shortstring(todef) and
                          (TStringDef(todef).len<>255);
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if (pd.owner.symtabletype=staticsymtable) and not pd.owner.iscurrentunit then
              continue;
            if (equal_defs(todef,pd.returndef) or
                { shortstrings of different lengths are ok as result }
                (not isexplicit and is_shortstring(todef) and is_shortstring(pd.returndef))) and
               { the result type must be always really equal and not an alias,
                 if you mess with this code, check tw4093 }
               ((todef=pd.returndef) or
                (
                  not(df_unique in todef.defoptions) and
                  not(df_unique in pd.returndef.defoptions)
                )
               ) then
              begin
                paraidx:=0;
                { ignore vs_hidden parameters }
                while (paraidx<pd.paras.count) and
                      Assigned(pd.paras[paraidx]) and
                      (vo_is_hidden_para in TParaVarSym(pd.paras[paraidx]).varoptions) do
                  inc(paraidx);
                realparamcount:=0;
                for j := 0 to pd.paras.Count-1 do
                  if Assigned(pd.paras[j]) and not (vo_is_hidden_para in TParaVarSym(pd.paras[j]).varoptions) then
                    inc(realparamcount);
                if (paraidx<pd.paras.count) and
                   Assigned(pd.paras[paraidx]) and
                   (realparamcount = 1) then
                  begin
                    eq:=compare_defs_ext(fromdef,TParaVarSym(pd.paras[paraidx]).vardef,nothingn,convtyp,hpd,[]);

                    { alias? if yes, only l1 choice,
                      if you mess with this code, check tw4093 }
                    if (eq=te_exact) and
                       (fromdef<>TParaVarSym(pd.paras[paraidx]).vardef) and
                       ((df_unique in fromdef.defoptions) or
                       (df_unique in TParaVarSym(pd.paras[paraidx]).vardef.defoptions)) then
                      eq:=te_convert_l1;

                    isgenshortstring:=false;
                    if checkshortstring and is_shortstring(pd.returndef) then
                      if TStringDef(pd.returndef).len<>255 then
                        inc(shortstringcount)
                      else
                        isgenshortstring:=true;

                    if (eq=te_exact) and (not checkshortstring or isgenshortstring) then
                      begin
                        besteq:=eq;
                        result:=pd;
                        exit;
                      end;
                    if eq>besteq then
                      begin
                        bestpd:=pd;
                        besteq:=eq;
                      end;
                  end;
              end;
          end;
        if checkshortstring and (shortstringcount>1) then
          begin
            besteq:=te_incompatible;
            bestpd:=nil;
          end;
        result:=bestpd;
      end;

      function TProcSym.find_procdef_enumerator_operator(fromdef,todef:TDef;var besteq:TEqualType):TProcDef;
      var
        paraidx, realparamcount,
        i, j : LongInt;
        bestpd,
        hpd,
        pd : TProcDef;
        current : TPropertySym;
        convtyp : TConvertType;
        eq      : TEqualType;
      begin
        { This function will return the pprocdef of pprocsym that
          is the best match for fromdef and todef. }
        result:=nil;
        bestpd:=nil;
        besteq:=te_incompatible;
        for i:=0 to ProcdefList.Count-1 do
          begin
            pd:=TProcDef(ProcdefList[i]);
            if (pd.owner.symtabletype=staticsymtable) and not pd.owner.iscurrentunit then
              continue;
            if not (is_class_or_interface_or_object(pd.returndef) or is_record(pd.returndef)) then
              continue;
            current := TPropertySym(TAbstractRecordDef(pd.returndef).search_enumerator_current);
            if (current = nil) then
              continue;
            // compare current result def with the todef
            if (equal_defs(todef, current.propdef) or
                { shortstrings of different lengths are ok as result }
                (is_shortstring(todef) and is_shortstring(current.propdef))) and
               { the result type must be always really equal and not an alias,
                 if you mess with this code, check tw4093 }
               ((todef=current.propdef) or
                (
                  not(df_unique in todef.defoptions) and
                  not(df_unique in current.propdef.defoptions)
                )
               ) then
              begin
                paraidx:=0;
                { ignore vs_hidden parameters }
                while (paraidx<pd.paras.count) and
                      Assigned(pd.paras[paraidx]) and
                      (vo_is_hidden_para in TParaVarSym(pd.paras[paraidx]).varoptions) do
                  inc(paraidx);
                realparamcount:=0;
                for j := 0 to pd.paras.Count-1 do
                  if Assigned(pd.paras[j]) and not (vo_is_hidden_para in TParaVarSym(pd.paras[j]).varoptions) then
                    inc(realparamcount);
                if (paraidx<pd.paras.count) and
                   Assigned(pd.paras[paraidx]) and
                   (realparamcount = 1) then
                  begin
                    eq:=compare_defs_ext(fromdef,TParaVarSym(pd.paras[paraidx]).vardef,nothingn,convtyp,hpd,[]);

                    { alias? if yes, only l1 choice,
                      if you mess with this code, check tw4093 }
                    if (eq=te_exact) and
                       (fromdef<>TParaVarSym(pd.paras[paraidx]).vardef) and
                       ((df_unique in fromdef.defoptions) or
                       (df_unique in TParaVarSym(pd.paras[paraidx]).vardef.defoptions)) then
                      eq:=te_convert_l1;

                    if eq=te_exact then
                      begin
                        besteq:=eq;
                        result:=pd;
                        exit;
                      end;
                    if eq>besteq then
                      begin
                        bestpd:=pd;
                        besteq:=eq;
                      end;
                  end;
              end;
          end;
        result:=bestpd;
      end;


    procedure TProcSym.add_generic_overload(sym:TProcSym);
      var
        i : LongInt;
      begin
        if not (sp_generic_dummy in symoptions) then
          InternalError(2021010601);
        if not Assigned(fgenprocsymovlds) then
          fgenprocsymovlds:=TFPObjectList.create(false);
        for i:=0 to genprocsymovlds.count-1 do
          if TProcSym(genprocsymovlds[i])=sym then
            exit;
        genprocsymovlds.add(sym);
      end;


    function TProcSym.could_be_implicitly_specialized:boolean;
      begin
        result:=(m_implicit_function_specialization in CurrentSettings.ModeSwitches) and
                (sp_generic_dummy in symoptions) and
                Assigned(genprocsymovlds);
      end;

{****************************************************************************
                                  TERRORSYM
****************************************************************************}

    constructor TErrorSym.create;
      begin
        inherited create(errorsym,'');
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

    procedure TPropertySym.finalize_getter_or_setter_for_sym(GetSet: TPropAccessListTypes; sym: TSym; fielddef: TDef; accessordef: TProcDef);
      begin
        { do nothing by default }
      end;


    constructor TPropertySym.create(const n : TSymStr);
      var
        pap : TPropAccessListTypes;
      begin
         inherited create(propertysym,n);
         propoptions:=[];
         index:=0;
         default:=0;
         propdef:=nil;
         propdefderef.reset;
         indexdef:=nil;
         indexdefderef.reset;
         parast:=nil;
         for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
           propaccesslist[pap]:=TPropAccessList.create;
      end;


    constructor TPropertySym.ppuload(ppufile:TCompilerPPUFile);
      type
         TSmallInterval = 0..31;
         TSmallSet = set of TSmallInterval;
         PSmallSet = ^TSmallSet;
      var
        pap : TPropAccessListTypes;
        d : BestReal;
        s : single;
        aset : TSmallSet;
      begin
         inherited ppuload(propertysym,ppufile);
         ppufile.GetSet(TPPUSet2(propoptions));
         if ppo_overrides in propoptions then
           ppufile.getderef(overriddenpropsymderef);
         ppufile.getderef(propdefderef);
         index:=ppufile.GetLongInt;
         if ppo_default_is_single in propoptions then
           begin
             d:=ppufile.GetReal;
	     s:=Single(d);
             default:=PLongInt(@s)^;
           end
         else if ppo_default_is_set in propoptions then
           begin
             ppufile.GetSet(TPPUSet4(aset));
             default:=PLongInt(@aset)^;
           end
         else
           default:=ppufile.GetLongInt;
         ppufile.getderef(indexdefderef);
         for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
           propaccesslist[pap]:=ppufile.getpropaccesslist;
         PPULoadPlatform(ppufile);
         if [ppo_hasparameters,ppo_overrides]*propoptions=[ppo_hasparameters] then
           begin
             parast:=TParaSymTable.create(nil,0);
             TParaSymTable(parast).ppuload(ppufile);
           end
         else
           parast:=nil;
      end;


    destructor TPropertySym.Destroy;
      var
        pap : TPropAccessListTypes;
      begin
         for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
           FreeAndNil(propaccesslist[pap]);
         parast.free;
         parast := nil;
         inherited Destroy;
      end;


    procedure TPropertySym.buildderef;
      var
        pap : TPropAccessListTypes;
      begin
        inherited;
        propdefderef.build(propdef);
        indexdefderef.build(indexdef);
        for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
          propaccesslist[pap].buildderef;
        if ppo_overrides in propoptions then
          overriddenpropsymderef.build(overriddenpropsym)
        else
        if ppo_hasparameters in propoptions then
          TParaSymTable(parast).buildderef;
      end;


    procedure TPropertySym.deref;
      var
        pap : TPropAccessListTypes;
      begin
        indexdef:=TDef(indexdefderef.resolve);
        propdef:=TDef(propdefderef.resolve);
        for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
          propaccesslist[pap].resolve;

        if ppo_overrides in propoptions then
          begin
            overriddenpropsym:=TPropertySym(overriddenpropsymderef.resolve);
            if ppo_hasparameters in propoptions then
              parast:=overriddenpropsym.parast.getcopy;
          end
        else
        if ppo_hasparameters in propoptions then
          TParaSymTable(parast).deref(false)
      end;


    function TPropertySym.getpropaccesslist(pap:TPropAccessListTypes;out plist:TPropAccessList):boolean;
    var
      hpropsym : TPropertySym;
    begin
      result:=false;
      { find property in the overridden list }
      hpropsym:=self;
      repeat
        plist:=hpropsym.propaccesslist[pap];
        if not plist.empty then
          begin
            result:=true;
            exit;
          end;
        hpropsym:=hpropsym.overriddenpropsym;
      until not Assigned(hpropsym);
    end;


    procedure TPropertySym.add_accessor_parameters(readprocdef, writeprocdef: TProcDef);
      var
        i: integer;
        orig, hparavs: TParaVarSym;
      begin
        for i := 0 to parast.SymList.Count - 1 do
          begin
            orig:=TParaVarSym(parast.SymList[i]);
            if Assigned(readprocdef) then
              begin
                hparavs:=CParaVarSym.create(orig.RealName,orig.paranr,orig.varspez,orig.vardef,[]);
                readprocdef.parast.insertsym(hparavs);
              end;
            if Assigned(writeprocdef) then
              begin
                hparavs:=CParaVarSym.create(orig.RealName,orig.paranr,orig.varspez,orig.vardef,[]);
                writeprocdef.parast.insertsym(hparavs);
              end;
          end;
      end;


    procedure TPropertySym.add_index_parameter(var paranr: word; readprocdef, writeprocdef: TProcDef);
      var
        hparavs: TParaVarSym;
      begin
        inc(paranr);
        if Assigned(readprocdef) then
          begin
            hparavs:=CParaVarSym.create('$index',10*paranr,vs_value,indexdef,[]);
            readprocdef.parast.insertsym(hparavs);
          end;
        if Assigned(writeprocdef) then
          begin
            hparavs:=CParaVarSym.create('$index',10*paranr,vs_value,indexdef,[]);
            writeprocdef.parast.insertsym(hparavs);
          end;
      end;


    procedure TPropertySym.add_getter_or_setter_for_sym(GetSet: TPropAccessListTypes; sym: TSym; fielddef: TDef; accessordef: TProcDef);
      var
        cpo: TCompareParasOptions;
      begin
        case sym.typ of
          procsym :
            begin
              { search procdefs matching accessordef }
              { we ignore hidden stuff here because the property access symbol might have
                non default calling conventions which might change the hidden stuff;
                see tw3216.pas (FK) }
              cpo:=[cpo_allowdefaults,cpo_ignorehidden];
              { allow var-parameters for setters in case of VARPROPSETTER+ }
              if (GetSet=palt_write) and
                 (cs_varpropsetter in CurrentSettings.LocalSwitches) then
                include(cpo,cpo_ignorevarspez);
              propaccesslist[GetSet].procdef:=TProcSym(sym).find_procdef_bypara(accessordef.paras,accessordef.returndef,cpo);
              if not Assigned(propaccesslist[GetSet].procdef) or
                 { because of cpo_ignorehidden we need to compare if it is a static class method and we have a class property }
                 ((sp_static in symoptions)<>TProcDef(propaccesslist[GetSet].procdef).no_self_node) then
                Message(parser_e_ill_property_access_sym)
              else
                finalize_getter_or_setter_for_sym(GetSet,sym,fielddef,accessordef);
            end;
          fieldvarsym :
            begin
              if not Assigned(fielddef) then
                InternalError(200310071);
              if compare_defs(fielddef,propdef,nothingn)>=te_equal then
               begin
                 { property parameters are allowed if this is
                   an indexed property, because the index is then
                   the parameter.
                   Note: In the help of Kylix it is written
                   that it isn't allowed, but the compiler accepts it (PFV) }
                 if (ppo_hasparameters in propoptions) or
                    ((sp_static in symoptions) <> (sp_static in sym.symoptions)) then
                   Message(parser_e_ill_property_access_sym)
                 else
                   finalize_getter_or_setter_for_sym(GetSet,sym,fielddef,accessordef);
               end
              else
               IncompatibleTypes(fielddef,propdef);
            end;
          else
            Message(parser_e_ill_property_access_sym);
        end;
      end;


    procedure TPropertySym.register_override(overriddenprop: TPropertySym);
      begin
        overriddenpropsym:=TPropertySym(overriddenprop);
        include(propoptions,ppo_overrides);
      end;


    procedure TPropertySym.inherit_accessor(GetSet: TPropAccessListTypes);
      begin
        { nothing to do by default }
      end;


    procedure TPropertySym.makeduplicate(p: TPropertySym; readprocdef, writeprocdef: TProcDef; out paranr: word);
      begin
        { inherit all type related entries }
        p.indexdef:=indexdef;
        p.propdef:=propdef;
        p.index:=index;
        p.default:=default;
        p.propoptions:=propoptions;
        paranr:=0;
        if ppo_hasparameters in propoptions then
          begin
            p.parast:=parast.getcopy;
            p.add_accessor_parameters(readprocdef,writeprocdef);
            paranr:=p.parast.SymList.Count;
          end;
        if ppo_indexed in p.propoptions then
          p.add_index_parameter(paranr,readprocdef,writeprocdef);
      end;


    function TPropertySym.getsize : asizeint;
      begin
         getsize:=0;
      end;


    procedure TPropertySym.ppuwrite(ppufile:TCompilerPPUFile);
      type
         TSmallInterval = 0..31;
         TSmallSet = set of TSmallInterval;
         PSmallSet = ^TSmallSet;
      var
        pap : TPropAccessListTypes;
        s : single;
        aset : TSmallSet;
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet2(propoptions));
        if ppo_overrides in propoptions then
          ppufile.putderef(overriddenpropsymderef);
        ppufile.putderef(propdefderef);
        ppufile.PutLongInt(index);
        if ppo_default_is_single in propoptions then
          begin
            s:=psingle(@default)^;
            ppufile.PutReal(s);
          end
        else if ppo_default_is_set in propoptions then
          begin
            aset:=PSmallSet(@default)^;
            ppufile.PutSet(TPPUSet4(aset));
          end
        else
          ppufile.PutLongInt(default);
        ppufile.putderef(indexdefderef);
        for pap:=low(TPropAccessListTypes) to high(TPropAccessListTypes) do
          ppufile.putpropaccesslist(propaccesslist[pap]);
        WriteEntry(ppufile,IBPropertySym);
        if [ppo_hasparameters,ppo_overrides]*propoptions=[ppo_hasparameters] then
          TParaSymTable(parast).ppuwrite(ppufile);
      end;

{****************************************************************************
                            TABSTRACTVARSYM
****************************************************************************}

    constructor TAbstractVarSym.create(st:TSymTyp;const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(st,n);
         vardef:=def;
         vardefderef.reset;
         varspez:=vsp;
         varstate:=vs_declared;
         varoptions:=vopts;
      end;


    constructor TAbstractVarSym.ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(st,ppufile);
         varstate:=vs_readwritten;
         varspez:=TVarSpez(ppufile.GetByte);
         varregable:=TVarRegable(ppufile.GetByte);
         ppufile.GetSet(TPPUSet1(varsymaccess));
         ppufile.getderef(vardefderef);
         ppufile.GetSet(TPPUSet4(varoptions));
      end;


    procedure TAbstractVarSym.buildderef;
      begin
        inherited;
        vardefderef.build(vardef);
      end;


    procedure TAbstractVarSym.deref;
      begin
        { assigning vardef also updates varregable. We just loaded this   }
        { value from a ppu, so it must not be changed (e.g. tw7817a.pas/   }
        { tw7817b.pas: the address is taken of a local variable in an      }
        { inlined procedure -> must remain non-regable when inlining)     }
        setvardef(TDef(vardefderef.resolve));
      end;


    procedure TAbstractVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldcrc : boolean;
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutByte(byte(varspez));
         oldcrc:=ppufile.DoCRC;
         ppufile.DoCRC:=false;
         ppufile.PutByte(byte(varregable));
         ppufile.PutSet(TPPUSet1(varsymaccess));
         ppufile.DoCRC:=oldcrc;
         ppufile.putderef(vardefderef);
         ppufile.PutSet(TPPUSet4(varoptions));
      end;


    function TAbstractVarSym.getsize : asizeint;
      begin
        if Assigned(vardef) and
           ((vardef.typ<>arraydef) or
            is_dynamic_array(vardef) or
            (TArrayDef(vardef).highrange>=TArrayDef(vardef).lowrange)) then
          result:=vardef.size
        else
          result:=0;
      end;


    function  TAbstractVarSym.getpackedbitsize : LongInt;
      begin
        { bitpacking is only done for ordinals }
        if not is_ordinal(vardef) then
          InternalError(2006082010);
        result:=vardef.packedbitsize;
      end;


    function TAbstractVarSym.is_regvar(refpara: boolean):boolean;
      var
        tempdef : TDef;
      begin
        { Register variables are not allowed in the following cases:
           - regvars are disabled
           - exceptions are used (after an exception is raised the contents of the
               registers is not valid anymore)
           - it has a local copy
           - the value needs to be in memory (i.e. reference counted) }
        result:=(cs_opt_regvar in CurrentSettings.OptimizerSwitches) and
                not(pi_has_assembler_block in CurrentProcInfo.flags) and
                not(pi_uses_exceptions in CurrentProcInfo.flags) and
                not(pi_has_interproclabel in CurrentProcInfo.flags) and
                ((refpara and
                  (varregable <> vr_none)) or
                 (not refpara and
                  not(varregable in [vr_none,vr_addr])))
                and ((vardef.typ <> recorddef) or
                     (varregable = vr_addr) or
                     TAbstractRecordSymTable(TAbstractRecordDef(vardef).SymTable).has_single_field(tempdef) or
                     not(varstate in [vs_written,vs_readwritten]));
      end;


    procedure TAbstractVarSym.setvardef_and_regable(def:TDef);
      begin
        setvardef(def);
        setregable;
      end;


    procedure TAbstractVarSym.set_addr_taken(AValue: boolean);
      begin
        if AValue then
          include(varsymaccess, vsa_addr_taken)
        else
          exclude(varsymaccess, vsa_addr_taken);
      end;


    procedure TAbstractVarSym.set_different_scope(AValue: boolean);
      begin
        if AValue then
          include(varsymaccess, vsa_different_scope)
        else
          exclude(varsymaccess, vsa_different_scope);
      end;


    procedure TAbstractVarSym.setregable;
      begin
        if vo_volatile in varoptions then
          exit;
         { can we load the value into a register ? }
        if not Assigned(owner) or
           (owner.symtabletype in [localsymtable, parasymtable]) or
           (
            (owner.symtabletype=staticsymtable) and
            not(cs_create_pic in CurrentSettings.ModuleSwitches)
           ) then
          begin
            if (TStoredDef(vardef).is_intregable and
              { we could keep all aint*2 records in registers, but this causes
                too much spilling for CPUs with 8-16 registers so keep only
                parameters and function results of this type in register because they are normally
                passed by register anyways

                This can be changed, as soon as we have full ssa (FK) }
              ((typ=paravarsym) or
                (vo_is_funcret in varoptions) or
                (TStoredDef(vardef).typ<>recorddef) or
                (TStoredDef(vardef).size<=sizeof(aint)))) or

               { const parameters can be put into registers if the def fits into a register }
               (TStoredDef(vardef).is_const_intregable and
                (typ=paravarsym) and
                (varspez=vs_const)) then
              varregable:=vr_intreg
            else if TStoredDef(vardef).is_fpuregable then
              begin
                if use_vectorfpu(vardef) then
                  varregable:=vr_mmreg
                else
                  varregable:=vr_fpureg;
              end
            else if is_vector(vardef) and
              fits_in_mm_register(vardef) then
              begin
                varregable:=vr_mmreg;
              end;
          end;
      end;


    function TAbstractVarSym.get_addr_taken: boolean;
      begin
        result:=vsa_addr_taken in varsymaccess;
      end;


    function TAbstractVarSym.get_different_scope: boolean;
      begin
        result:=vsa_different_scope in varsymaccess;
      end;


    procedure TAbstractVarSym.setvardef(const def: TDef);
      begin
        _vardef := def;
      end;


{****************************************************************************
                               TFIELDVARSYM
****************************************************************************}

    constructor TFieldVarSym.create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(fieldvarsym,n,vsp,def,vopts);
         fieldoffset:=-1;
      end;


    constructor TFieldVarSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(fieldvarsym,ppufile);
         fieldoffset:=ppufile.GetASizeInt;
         if (vo_has_mangledname in varoptions) then
           externalname:=ppufile.GetPShortString
         else
           externalname:=nil;
         PPULoadPlatform(ppufile);
      end;


    procedure TFieldVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutASizeInt(fieldoffset);
         if (vo_has_mangledname in varoptions) then
           ppufile.PutString(externalname^);
         WriteEntry(ppufile,IBFieldVarSym);
      end;


    procedure TFieldVarSym.set_externalname(const s: string);
      begin
        InternalError(2014033001);
      end;


    function TFieldVarSym.bitoffset: ASizeUInt;
      begin
        result:=fieldoffset;
        if TAbstractRecordSymTable(owner).fieldalignment<>bit_alignment then
         result:=result*8;
      end;


    function TFieldVarSym.mangledname:TSymStr;
      var
        srsym : TSym;
        srsymtable : TSymTable;
      begin
        if sp_static in symoptions then
          begin
            if searchsym(lower(owner.name^)+'_'+name,srsym,srsymtable) then
              result:=srsym.mangledname
            { when generating the debug info for the module in which the }
            { symbol is defined, the localsymtable of that module is     }
            { already popped from the symtablestack                      }
            else if searchsym_in_module(CurrentModule,lower(owner.name^)+'_'+name,srsym,srsymtable) then
              result:=srsym.mangledname
            else
              InternalError(2007012501);
          end
        else if is_objcclass(TDef(owner.defowner)) then
          begin
{$ifdef symansistr}
            if cachedmangledname<>'' then
              result:=cachedmangledname
{$else symansistr}
            if Assigned(cachedmangledname) then
              result:=cachedmangledname^
{$endif symansistr}
            else
              begin
                result:=TargetInfo.cprefix+'OBJC_IVAR_$_'+TObjectDef(owner.defowner).objextname^+'.'+RealName;
{$ifdef symansistr}
                cachedmangledname:=result;
{$else symansistr}
                cachedmangledname:=StringDup(result);
{$endif symansistr}
              end;
          end
        else
          result:=inherited mangledname;
      end;


    destructor TFieldVarSym.Destroy;
      begin
{$ifndef symansistr}
        StringDispose(cachedmangledname);
{$endif symansistr}
        StringDispose(externalname);
        inherited Destroy;
      end;

{$ifdef DEBUG_NODE_XML}
      procedure TFieldVarSym.XMLPrintFieldData(var T: Text);
        begin
          WriteLn(T, PrintNodeIndention, '<type>', SanitiseXMLString(vardef.GetTypeName), '</type>');
          WriteLn(T, PrintNodeIndention, '<visibility>', visibility, '</visibility>');
          WriteLn(T, PrintNodeIndention, '<offset>', fieldoffset, '</offset>');
          WriteLn(T, PrintNodeIndention, '<size>', vardef.size, '</size>');
        end;
{$endif DEBUG_NODE_XML}

{****************************************************************************
                        TABSTRACTNORMALVARSYM
****************************************************************************}

    constructor TAbstractNormalVarSym.create(st:TSymTyp;const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(st,n,vsp,def,vopts);
         fillchar(localloc,sizeof(localloc),0);
         fillchar(initialloc,sizeof(initialloc),0);
         defaultconstsym:=nil;
         defaultconstsymderef.reset;
      end;


    constructor TAbstractNormalVarSym.ppuload(st:TSymTyp;ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(st,ppufile);
         fillchar(localloc,sizeof(localloc),0);
         fillchar(initialloc,sizeof(initialloc),0);
         ppufile.getderef(defaultconstsymderef);
      end;

    function TAbstractNormalVarSym.globalasmsym: boolean;
      begin
        result:=
          (owner.symtabletype=GlobalSymTable) or
          (create_smartlink and
           not(tf_smartlink_sections in TargetInfo.flags)) or
          CurrentModule.IsLibrary or
          (Assigned(CurrentProcInfo) and
           ((po_inline in CurrentProcInfo.procdef.procoptions) or
            { globalasmsym is called normally before the body of a subroutine is parsed
              so we cannot know if it will be auto inlined, so make all symbols of it
              global if asked }
            (not(po_noinline in CurrentProcInfo.procdef.procoptions) and
             (cs_opt_autoinline in CurrentSettings.OptimizerSwitches)))
          ) or
          (vo_is_public in varoptions);
      end;


    procedure TAbstractNormalVarSym.buildderef;
      begin
        inherited buildderef;
        defaultconstsymderef.build(defaultconstsym);
      end;


    procedure TAbstractNormalVarSym.deref;
      begin
        inherited deref;
        defaultconstsym:=TSym(defaultconstsymderef.resolve);
      end;


    procedure TAbstractNormalVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(defaultconstsymderef);
      end;


    function TAbstractNormalVarSym.is_captured:boolean;
      begin
        result:=Assigned(capture_sym);
      end;


{****************************************************************************
                             Tstaticvarsym
****************************************************************************}

    constructor TStaticVarSym.create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(staticvarsym,n,vsp,def,vopts);
         fieldvarsymderef.reset;
{$ifdef symansistr}
         _mangledname:='';
{$else symansistr}
         _mangledname:=nil;
{$endif symansistr}
      end;


    constructor TStaticVarSym.create_dll(const n : TSymStr;vsp:TVarSpez;def:TDef);
      begin
         TStaticVarSym(self).create(n,vsp,def,[vo_is_dll_var]);
      end;


    constructor TStaticVarSym.create_C(const n: TSymStr; const mangled : TSymStr;vsp:TVarSpez;def:TDef);
      begin
         TStaticVarSym(self).create(n,vsp,def,[]);
         set_mangledname(mangled);
      end;


    constructor TStaticVarSym.create_from_fieldvar(const n: TSymStr;fieldvar:TFieldVarSym);
      begin
        create(internal_static_field_name(n),fieldvar.varspez,fieldvar.vardef,[]);
        fieldvarsym:=fieldvar;
      end;


    constructor TStaticVarSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(staticvarsym,ppufile);
{$ifdef symansistr}
         if vo_has_mangledname in varoptions then
           _mangledname:=ppufile.GetAnsiString
         else
           _mangledname:='';
{$else symansistr}
         if vo_has_mangledname in varoptions then
           _mangledname:=ppufile.GetPShortString
         else
           _mangledname:=nil;
{$endif symansistr}
         if vo_has_section in varoptions then
           section:=ppufile.GetAnsiString;
         ppufile.getderef(fieldvarsymderef);
         PPULoadPlatform(ppufile);
      end;


    destructor TStaticVarSym.Destroy;
      begin
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
        StringDispose(_mangledbasename);
{$endif}
        inherited Destroy;
      end;


    procedure TStaticVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         { write mangledname rather than _mangledname in case the mangledname
           has not been calculated yet (can happen in case only the
           mangledbasename has been set) }
         if vo_has_mangledname in varoptions then
{$ifdef symansistr}
           ppufile.PutAnsiString(mangledname);
{$else symansistr}
           ppufile.PutString(mangledname);
{$endif symansistr}
         if vo_has_section in varoptions then
           ppufile.PutAnsiString(section);
         ppufile.putderef(fieldvarsymderef);
         WriteEntry(ppufile,IBStaticVarSym);
      end;


    procedure TStaticVarSym.buildderef;
      begin
        inherited buildderef;
        fieldvarsymderef.build(fieldvarsym);
      end;


    procedure TStaticVarSym.deref;
      begin
        inherited deref;
        fieldvarsym:=TFieldVarSym(fieldvarsymderef.resolve);
      end;

    function TStaticVarSym.mangledname:TSymStr;
      var
        usename,
        prefix : TSymStr;
      begin
{$ifdef symansistr}
        if _mangledname='' then
{$else symansistr}
        if not Assigned(_mangledname) then
{$endif symansistr}
          begin
            if (vo_is_typed_const in varoptions) then
              prefix:='TC'
            else
              prefix:='U';
{$ifdef symansistr}
            if _mangledbasename='' then
              usename:=name
            else
              usename:=_mangledbasename;
            _mangledname:=make_mangledname(prefix,owner,usename);
{$else symansistr}
            if not Assigned(_mangledbasename) then
              usename:=name
            else
              usename:=_mangledbasename^;
            _mangledname:=StringDup(make_mangledname(prefix,owner,usename));
{$endif symansistr}
          end;
{$ifdef symansistr}
        result:=_mangledname;
{$else symansistr}
        result:=_mangledname^;
{$endif symansistr}
      end;


    procedure TStaticVarSym.set_mangledbasename(const s: TSymStr);
      begin
{$ifdef symansistr}
        _mangledbasename:=s;
        _mangledname:='';
{$else symansistr}
        StringDispose(_mangledname);
        StringDispose(_mangledbasename);
        _mangledbasename:=StringDup(s);
{$endif symansistr}
        include(varoptions,vo_has_mangledname);
      end;


    function TStaticVarSym.mangledbasename: TSymStr;
      begin
{$ifdef symansistr}
        result:=_mangledbasename;
{$else symansistr}
        if Assigned(_mangledbasename) then
          result:=_mangledbasename^
        else
          result:='';
{$endif symansistr}
      end;


    procedure TStaticVarSym.set_mangledname(const s:TSymStr);
      begin
{$ifdef symansistr}
        _mangledname:=s;
{$else symansistr}
        StringDispose(_mangledname);
        _mangledname:=StringDup(s);
{$endif symansistr}
        include(varoptions,vo_has_mangledname);
      end;


    procedure TStaticVarSym.set_raw_mangledname(const s: TSymStr);
      begin
{$ifndef symansistr}
        StringDispose(_mangledname);
        _mangledname:=StringDup(s);
{$else}
        _mangledname:=s;
{$endif}
        include(varoptions,vo_has_mangledname);
      end;


{****************************************************************************
                               TLOCALVARSYM
****************************************************************************}

    constructor TLocalVarSym.create(const n : TSymStr;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(localvarsym,n,vsp,def,vopts);
      end;


    constructor TLocalVarSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(localvarsym,ppufile);
         PPULoadPlatform(ppufile);
      end;


    procedure TLocalVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         WriteEntry(ppufile,IBLocalVarSym);
      end;


{****************************************************************************
                              TPARAVARSYM
****************************************************************************}

    constructor TParaVarSym.create(const n : TSymStr;nr:word;vsp:TVarSpez;def:TDef;vopts:TVarOptions);
      begin
         inherited create(paravarsym,n,vsp,def,vopts);
         if (vsp in [vs_var,vs_value,vs_const,vs_constref]) and
            not(vo_is_funcret in vopts) then
           varstate := vs_initialised;
         paranr:=nr;
         paraloc[calleeside].init;
         paraloc[callerside].init;
      end;


    destructor TParaVarSym.Destroy;
      begin
        paraloc[calleeside].done;
        paraloc[callerside].done;
        inherited Destroy;
      end;


    constructor TParaVarSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(paravarsym,ppufile);
         paranr:=ppufile.GetWord;
         univpara:=ppufile.GetBoolean;

         { The var state of parameter symbols is fixed after writing them so
           we write them to the unit file.
           This enables constant folding for inline procedures loaded from units
         }
         varstate:=TVarState(ppufile.GetByte);

         { read usage info }
         refs:=ppufile.GetByte;

         paraloc[calleeside].init;
         paraloc[callerside].init;
         if vo_has_explicit_paraloc in varoptions then
           paraloc[callerside].ppuload(ppufile);

         PPULoadPlatform(ppufile);
      end;


    procedure TParaVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldcrc : boolean;
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutWord(paranr);
         ppufile.PutBoolean(univpara);

         { The var state of parameter symbols is fixed after writing them so
           we write them to the unit file.
           This enables constant folding for inline procedures loaded from units
         }
         oldcrc:=ppufile.DoCRC;
         ppufile.DoCRC:=false;
         ppufile.PutByte(ord(varstate));
         { write also info about the usage of parameters,
           the absolute usage does not matter }
         ppufile.PutByte(min(1,refs));
         ppufile.DoCRC:=oldcrc;

         if vo_has_explicit_paraloc in varoptions then
           begin
             paraloc[callerside].check_simple_location;
             paraloc[callerside].ppuwrite(ppufile);
           end;
         WriteEntry(ppufile,IBParaVarSym);
      end;

    function TParaVarSym.needs_finalization:boolean;
      begin
        result:=(varspez=vs_value) and
          (is_managed_type(vardef) or
            (
              (not (TAbstractProcDef(owner.defowner).proccalloption in cdecl_pocalls)) and
              (not paramanager.use_stackalloc) and
              (is_open_array(vardef) or is_array_of_const(vardef))
            )
          );
      end;


    function TParaVarSym.is_used: boolean;
      begin
        { Only the $parentfp parameter is supported for now }
        result:=not (vo_is_parentfp in varoptions) or (varstate>vs_initialised);
      end;

{****************************************************************************
                               TABSOLUTEVARSYM
****************************************************************************}

    constructor TAbsoluteVarSym.create(const n : TSymStr;def:TDef);
      begin
        inherited create(absolutevarsym,n,vs_value,def,[]);
        ref:=nil;
      end;


    constructor TAbsoluteVarSym.create_ref(const n : TSymStr;def:TDef;_ref:TPropAccessList);
      begin
        inherited create(absolutevarsym,n,vs_value,def,[]);
        ref:=_ref;
      end;

    procedure TAbsoluteVarSym.adjust_varregable;
      var
        plist : PPropAccessListItem;
      begin
        if Assigned(ref) and (abstyp=tovar) then
          begin
            plist:=ref.firstsym;
            if Assigned(plist) and (plist^.sltype=sl_load) and
               Assigned(plist^.sym) and (plist^.sym is TAbstractVarSym) and
               (varregable<>TAbstractVarSym(plist^.sym).varregable) then
              begin
                varregable:=vr_none;
	        TAbstractVarSym(plist^.sym).varregable:=vr_none;
             end;
          end;
      end;

    destructor TAbsoluteVarSym.Destroy;
      begin
        if Assigned(ref) then
          ref.free;
          ref := nil;
        inherited Destroy;
      end;


    constructor TAbsoluteVarSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(absolutevarsym,ppufile);
         ref:=nil;
         asmname:=nil;
         abstyp:=TAbsoluteTyp(ppufile.GetByte);
         case abstyp of
           tovar :
             ref:=ppufile.getpropaccesslist;
           toasm :
             asmname:=ppufile.GetPShortString;
           toaddr :
             addroffset:=ppufile.GetPUInt;
         end;
         PPULoadPlatform(ppufile);
      end;


    procedure TAbsoluteVarSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutByte(byte(abstyp));
         case abstyp of
           tovar :
             ppufile.putpropaccesslist(ref);
           toasm :
             ppufile.PutString(asmname^);
           toaddr :
             ppufile.PutPUInt(addroffset);
         end;
         WriteEntry(ppufile,IBAbsoluteVarSym);
      end;


    procedure TAbsoluteVarSym.buildderef;
      begin
        inherited buildderef;
        if (abstyp=tovar) then
          ref.buildderef;
      end;


    procedure TAbsoluteVarSym.deref;
      begin
         inherited deref;
         { own absolute deref }
         if (abstyp=tovar) then
           ref.resolve;
      end;


    function TAbsoluteVarSym.mangledname : TSymStr;
      begin
         case abstyp of
           toasm :
             mangledname:=asmname^;
           toaddr :
             mangledname:='$'+ToStr(addroffset);
           else
             InternalError(200411062);
         end;
      end;

         { returns the symbol type of the local variable or local parameter
           referenced by the absolute symbol }
    function TAbsoluteVarSym.reftyp : TSymTyp;
      var
        plist : PPropAccessListItem;
      begin
        reftyp:=typ;
        if abstyp=tovar then
          begin
            plist:=ref.firstsym;
            if Assigned(plist) and (plist^.sltype=sl_load) and
               Assigned(plist^.sym) and not(Assigned(plist^.next)) then
              reftyp:=plist^.sym.typ;
          end;
      end;

{****************************************************************************
                                  TCONSTSYM
****************************************************************************}

    constructor TConstSym.create_ord(const n : TSymStr;t : TConstTyp;v : TConstExprInt;def:TDef);
      begin
         inherited create(constsym,n);
         fillchar(value, sizeof(value), #0);
         consttyp:=t;
         value.valueord:=v;
         constdef:=def;
         constdefderef.reset;
      end;


    constructor TConstSym.create_ordptr(const n : TSymStr;t : TConstTyp;v : TConstPtrUInt;def:TDef);
      begin
         inherited create(constsym,n);
         fillchar(value, sizeof(value), #0);
         consttyp:=t;
         value.valueordptr:=v;
         constdef:=def;
         constdefderef.reset;
      end;


    constructor TConstSym.create_ptr(const n : TSymStr;t : TConstTyp;v : pointer;def:TDef);
      begin
         inherited create(constsym,n);
         fillchar(value, sizeof(value), #0);
         consttyp:=t;
         value.valueptr:=v;
         constdef:=def;
         constdefderef.reset;
      end;


    constructor TConstSym.create_string(const n : TSymStr;t : TConstTyp;str:pchar;l:LongInt;def: TDef);
      begin
         inherited create(constsym,n);
         fillchar(value, sizeof(value), #0);
         consttyp:=t;
         value.valueptr:=str;
         if Assigned(def) then
           constdef:=def
         else
           constdef:=CArrayDef.getreusable(cansichartype,l);
         constdefderef.reset;
         value.len:=l;
      end;


    constructor TConstSym.create_wstring(const n : TSymStr;t : TConstTyp;pw:TCompilerWideString);
      begin
         inherited create(constsym,n);
         fillchar(value, sizeof(value), #0);
         consttyp:=t;
         value.valuews:=pw;
         constdef:=CArrayDef.getreusable(cwidechartype,GetLengthWideString(pw));
         constdefderef.reset;
         value.len:=GetLengthWideString(pw);
      end;


    constructor TConstSym.create_undefined(const n : TSymStr;def: TDef);
      begin
        inherited create(constsym,n);
        fillchar(value,sizeof(value),#0);
        consttyp:=constnone;
        constdef:=def;
      end;


    constructor TConstSym.ppuload(ppufile:TCompilerPPUFile);
      var
         pd : PBestReal;
         ps : PNormalSet;
         pc : pchar;
         pw : TCompilerWideString;
         i  : LongInt;

         procedure do_widestring_const;
         var
            i  : LongInt;
         begin
           InitWideString(pw);
           SetLengthWideString(pw,ppufile.GetLongInt);
           { don't use getdata, because the compilerwidechars may have to
             be byteswapped
           }
           for i:=0 to pw.len-1 do
             pw.data[i]:=ppufile.GetWord;
           value.valuews:=pw;
         end;

      begin
         inherited ppuload(constsym,ppufile);
         constdef:=nil;
         consttyp:=TConstTyp(ppufile.GetByte);
         fillchar(value, sizeof(value), #0);
         case consttyp of
           constord :
             begin
               ppufile.getderef(constdefderef);
               value.valueord:=ppufile.getexprint;
             end;
           constpointer :
             begin
               ppufile.getderef(constdefderef);
               value.valueordptr:=ppufile.GetPtrUInt;
             end;
           constwstring :
             begin
               do_widestring_const;
             end;
           conststring,
           constresourcestring :
              begin
              ppufile.getderef(constdefderef);
              value.len:=ppufile.GetLongInt;
              GetMem(pc,value.len+1);
              ppufile.GetData(pc^,value.len);
              pc[value.len]:=#0;
              value.valueptr:=pc;
              end;
           constwresourcestring :
             begin
               ppufile.getderef(constdefderef);
               do_widestring_const;
             end;
           constreal :
             begin
               ppufile.getderef(constdefderef);
               new(pd);
               pd^:=ppufile.GetReal;
               value.valueptr:=pd;
             end;
           constset :
             begin
               ppufile.getderef(constdefderef);
               new(ps);
               ppufile.GetSet(TPPUSet32(ps^));
               value.valueptr:=ps;
             end;
           constguid :
             begin
               ppufile.getderef(constdefderef);
               new(PGUID(value.valueptr));
               ppufile.GetData(value.valueptr^,sizeof(TGUID));
             end;
           constnil :
             ppufile.getderef(constdefderef);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(ord(consttyp)));
         end;
         PPULoadPlatform(ppufile);
      end;


    destructor TConstSym.Destroy;
      begin
        case consttyp of
          constnone,
          constord,
          constpointer,
          constnil:
            ;
          conststring,
          constresourcestring :
            FreeMem(pchar(value.valueptr),value.len+1);
          constwstring,
          constwresourcestring:
            DoneWideString(value.valuews);
          constreal :
            dispose(PBestReal(value.valueptr));
          constset :
            dispose(PNormalSet(value.valueptr));
          constguid :
            dispose(PGUID(value.valueptr));
        end;
        inherited Destroy;
      end;


    procedure TConstSym.buildderef;
      begin
        inherited;
        case consttyp  of
          constnil,constord,constreal,constpointer,constset,conststring,constresourcestring,constwresourcestring,constguid:
            constdefderef.build(constdef);
          constwstring:
            ;
          else
            InternalError(2015120802);
        end;
      end;


    procedure TConstSym.deref;
      begin
        case consttyp of
          constnil,constord,constreal,constpointer,constset,conststring,constresourcestring,constwresourcestring,constguid:
            constdef:=TDef(constdefderef.resolve);
          constwstring:
            constdef:=CArrayDef.getreusable(cwidechartype,GetLengthWideString(value.valuews));
          else
            InternalError(2015120801);
        end
      end;


    procedure TConstSym.ppuwrite(ppufile:TCompilerPPUFile);

      procedure do_widestring_const;

      var
        len : integer;
      begin
        len:=GetLengthWideString(value.valuews);
        ppufile.PutLongInt(len);
        if len>0 then
          ppufile.PutData(value.valuews.data[0],value.valuews.len*sizeof(TCompilerWideChar));
      end;


      begin
         inherited ppuwrite(ppufile);
         ppufile.PutByte(byte(consttyp));
         case consttyp of
           constnil :
             ppufile.putderef(constdefderef);
           constord :
             begin
               ppufile.putderef(constdefderef);
               ppufile.putexprint(value.valueord);
             end;
           constpointer :
             begin
               ppufile.putderef(constdefderef);
               ppufile.PutPtrUInt(value.valueordptr);
             end;
           constwstring :
             begin
               { no need to store the def, we can reconstruct it }
               do_widestring_const;
             end;
           conststring,constresourcestring:
             begin
             ppufile.putderef(constdefderef);
             ppufile.PutLongInt(value.len);
             ppufile.PutData(pchar(value.valueptr)^,value.len);
             end;
            constwresourcestring:
             begin
               ppufile.putderef(constdefderef);
               do_widestring_const
             end;
           constreal :
             begin
               ppufile.putderef(constdefderef);
               ppufile.PutReal(PBestReal(value.valueptr)^);
             end;
           constset :
             begin
               ppufile.putderef(constdefderef);
               ppufile.PutSet(TPPUSet32(value.valueptr^));
             end;
           constguid :
             begin
               ppufile.putderef(constdefderef);
               ppufile.PutData(value.valueptr^,sizeof(TGUID));
             end;
         else
           InternalError(13);
         end;
        WriteEntry(ppufile,IBConstSym);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TConstSym.XMLPrintConstData(var T: Text);
      begin
        WriteLn(T, PrintNodeIndention, '<type>', SanitiseXMLString(constdef.GetTypeName), '</type>');

        case consttyp of
          constnone:
            ;
          conststring,
          constresourcestring,
          constwresourcestring,
          constwstring:
            begin
              WriteLn(T, PrintNodeIndention, '<length>', value.len, '</length>');
              if value.len = 0 then
                WriteLn(T, PrintNodeIndention, '<value />')
              else
                WriteLn(T, PrintNodeIndention, '<value>', SanitiseXMLString(PChar(value.valueptr)), '</value>');
            end;
          constord,
          constset:
            WriteLn(T, PrintNodeIndention, '<value>', ToStr(value.valueord), '</value>');
          constpointer:
            WriteLn(T, PrintNodeIndention, '<value>', WriteConstPUInt(value.valueordptr), '</value>');
          constreal:
            WriteLn(T, PrintNodeIndention, '<value>', PBestReal(value.valueptr)^, '</value>');
          constnil:
            WriteLn(T, PrintNodeIndention, '<value>nil</value>');
          constguid:
            WriteLn(T, PrintNodeIndention, '<value>', WriteGUID(PGUID(value.valueptr)^), '</value>');
        end;

        WriteLn(T, PrintNodeIndention, '<visibility>', visibility, '</visibility>');

        if not (consttyp in [conststring, constresourcestring, constwresourcestring, constwstring]) then
          { constdef.size will return an internal error for string
            constants because constdef is an open array internally }
          WriteLn(T, PrintNodeIndention, '<size>', constdef.size, '</size>');

//        WriteLn(T, PrintNodeIndention, '<const_type>', consttyp, '</const_type>');
      end;
{$endif DEBUG_NODE_XML}

{****************************************************************************
                                  TENUMSYM
****************************************************************************}

    constructor TEnumSym.create(const n : TSymStr;def : TEnumDef;v : LongInt);
      begin
         inherited create(enumsym,n);
         definition:=def;
         definitionderef.reset;
         value:=v;
      end;


    constructor TEnumSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(enumsym,ppufile);
         ppufile.getderef(definitionderef);
         value:=ppufile.GetLongInt;
         PPULoadPlatform(ppufile);
      end;


    procedure TEnumSym.buildderef;
      begin
        inherited;
        definitionderef.build(definition);
      end;


    procedure TEnumSym.deref;
      begin
         definition:=TEnumDef(definitionderef.resolve);
      end;

    procedure TEnumSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(definitionderef);
         ppufile.PutLongInt(value);
         WriteEntry(ppufile,IBEnumSym);
      end;


{****************************************************************************
                                  TTYPESYM
****************************************************************************}


    constructor TTypeSym.create(const n : TSymStr;def:TDef);

      begin
        inherited create(typesym,n);
        typedef:=def;
        typedefderef.reset;
        { register the typesym for the definition }
        if Assigned(typedef) and
           (typedef.typ<>errordef) and
           not(Assigned(typedef.typesym)) then
         typedef.typesym:=self;
      end;

    destructor TTypeSym.Destroy;
      begin
        inherited Destroy;
      end;


    constructor TTypeSym.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(typesym,ppufile);
         ppufile.getderef(typedefderef);
         fprettyname:=ppufile.GetAnsiString;
         PPULoadPlatform(ppufile);
      end;


    procedure TTypeSym.buildderef;
      begin
        inherited;
        typedefderef.build(typedef);
      end;


    procedure TTypeSym.deref;
      begin
        typedef:=TDef(typedefderef.resolve);
      end;


    procedure TTypeSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.putderef(typedefderef);
         ppufile.PutAnsiString(fprettyname);
         WriteEntry(ppufile,IBTypeSym);
      end;


    function TTypeSym.prettyname : string;
      begin
        if fprettyname<>'' then
          result:=fprettyname
        else
          result:=inherited prettyname;
      end;


{****************************************************************************
                                  TSYSSYM
****************************************************************************}


    var
      syssym_list : TFPHashObjectList;


    constructor TSysSym.create(const n : TSymStr;l : TInlineNumber);
      var
        s : shortstring;
      begin
         inherited create(syssym,n);
         number:=l;
         str(LongInt(l),s);
         if Assigned(syssym_list.find(s)) then
           InternalError(2016060303);
         syssym_list.add(s,self);
      end;

    constructor TSysSym.ppuload(ppufile:TCompilerPPUFile);
      var
        s : shortstring;
      begin
         inherited ppuload(syssym,ppufile);
         number:=TInlineNumber(ppufile.GetLongInt);
         PPULoadPlatform(ppufile);
         str(LongInt(number),s);
         if Assigned(syssym_list.find(s)) then
           InternalError(2016060304);
         syssym_list.add(s,self);
      end;

    destructor TSysSym.Destroy;
      begin
        inherited Destroy;
      end;

    procedure TSysSym.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutLongInt(LongInt(number));
         WriteEntry(ppufile,IBSysSym);
      end;


    class function TSysSym.find_by_number(l:LongInt):TSysSym;
      var
        s : shortstring;
      begin
        str(l,s);
        result:=TSysSym(syssym_list.find(s));
      end;

{*****************************************************************************
                                 TMacro
*****************************************************************************}

    constructor TMacro.create(const n : TSymStr);
      begin
         inherited create(macrosym,n);
         owner:=nil;
         defined:=false;
         is_used:=false;
         is_compiler_var:=false;
         buftext:=nil;
         buflen:=0;
      end;

    constructor TMacro.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(macrosym,ppufile);
         defined:=ppufile.GetBoolean;
         is_compiler_var:=ppufile.GetBoolean;
         is_used:=false;
         allocate_buftext(ppufile.GetLongInt);
         if buflen>0 then
           ppufile.GetData(buftext)
      end;

    destructor TMacro.Destroy;
      begin
         buftext:=nil;
         inherited Destroy;
      end;

    procedure TMacro.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         inherited ppuwrite(ppufile);
         ppufile.PutBoolean(defined);
         ppufile.PutBoolean(is_compiler_var);
         ppufile.PutLongInt(buflen);
         if buflen > 0 then
           ppufile.PutData(buftext);
         WriteEntry(ppufile,IBMacroSym);
      end;


    function TMacro.allocate_buftext(len:LongInt) : pchar;
      begin
        SetLength(buftext,len);
        buflen:=len;
        result:=PAnsiChar(buftext);
      end;


    procedure TMacro.free_buftext;
      begin
        buftext:=nil;
        buflen:=0;
      end;


    function TMacro.GetCopy:TMacro;
      var
        p : TMacro;
      begin
        p:=TMacro.create(realname);
        p.defined:=defined;
        p.is_used:=is_used;
        p.is_compiler_var:=is_compiler_var;
        p.is_c_macro:=is_c_macro;
        p.allocate_buftext(buflen);
        if buflen>0 then
          move(buftext[0],p.buftext[0],buflen);
        Result:=p;
      end;


    procedure init_symsym;
      begin
        syssym_list:=TFPHashObjectList.create(false);
      end;


    procedure done_symsym;
      begin
        syssym_list.free;
        syssym_list := nil;
      end;


initialization
  Register_InitDone_Proc(@init_symsym,@done_symsym);
end.
