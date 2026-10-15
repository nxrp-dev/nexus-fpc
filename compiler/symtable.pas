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
       CUtils,CClasses,GlobType,tokens,
       { symtable }
       symconst,SymBase,symtype,symdef,SymSym;


{****************************************************************************
                             Symtable types
****************************************************************************}

    type

       { tstoredsymtable }

       TStoredSymTable = class(TSymTable)
       private
          init_final_check_done : boolean;
          deref_built : boolean;
          derefimpl_built : boolean;
          procedure _needs_init_final(sym:TObject;arg:pointer);
          procedure do_init_final_check;
          procedure check_forward(sym:TObject;arg:pointer);
          procedure check_block_valid(def: TObject;arg:pointer);
          procedure register_defs(def:tobject;arg:pointer);
          procedure register_syms(sym:tobject;arg:pointer);
          procedure labeldefined(sym:TObject;arg:pointer);
          procedure varsymbolused(sym:TObject;arg:pointer);
          procedure TestPrivate(sym:TObject;arg:pointer);
          procedure objectprivatesymbolused(sym:TObject;arg:pointer);
          procedure loaddefs(ppufile:TCompilerPPUFile);
          procedure loadsyms(ppufile:TCompilerPPUFile);
          procedure writedefs(ppufile:TCompilerPPUFile);
          procedure writesyms(ppufile:TCompilerPPUFile);
       public
          constructor create(const s:string);
          procedure insertsym(sym:TSymEntry;checkdup:boolean=true);override;
          procedure deletesym(sym:TSymEntry);override;
          { load/write }
          procedure ppuload(ppufile:TCompilerPPUFile);virtual;
          procedure ppuwrite(ppufile:TCompilerPPUFile);virtual;
          procedure buildderef;
          procedure buildderefimpl;
          { buildderef but only for (recursively) used symbols/defs }
          procedure buildderef_registered;
          procedure deref(only_registered: boolean);virtual;
          procedure derefimpl(only_registered: boolean);virtual;
          function  checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
          procedure allsymbolsused;
          procedure allprivatesused;
          procedure check_forwards;
          procedure checklabels;
          function  needs_init_final : boolean; virtual;
          function  has_non_trivial_init:boolean;virtual;
          function is_derefimpl_built: boolean;
          function is_deref_built: boolean;
          procedure testfordefaultproperty(sym:TObject;arg:pointer);
          procedure register_children;
       end;



       TManagementOperatorOffsetEntry = record
         pd : TProcDef;
         offset : asizeint;
       end;
       PManagementOperatorOffsetEntry = ^TManagementOperatorOffsetEntry;

       TAbstractRecordSymTable = class(TStoredSymTable)

       public
          usefieldalignment,     { alignment to use for fields (PACKRECORDS value), C_alignment is C style }
          recordalignment,       { alignment desired when inserting this record }
          explicitrecordalignment, { explicit alignment for inserting this record, given by align XX at end of declaration }
          fieldalignment,        { alignment current alignment used when fields are inserted }
          padalignment : shortint;   { size to a multiple of which the symtable has to be rounded up }
          RecordAlignMin: shortint; { local equivalentsof global settings, so that records can be created with custom settings internally }
          has_fields_with_mop : TManagementOperators; { whether any of the fields has the need for a management operator (or one of the field's fields) }
          constructor create(const n:string;usealign,recordminalign:shortint);
          destructor Destroy;override;
          procedure ppuload(ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure alignrecord(fieldoffset:asizeint;varalign:shortint);
          procedure addfield(sym:TFieldVarSym;vis:TVisibility);
          procedure addfieldlist(list: TFPObjectList; maybereorder: boolean);
          { returns the field closest to this offset (may not be exact because
            of padding; internalerrors for variant records, assumes fields are
            ordered by increasing offset) }
          function findfieldbyoffset(offset:asizeint): TFieldVarSym;
          procedure addalignmentpadding;
          procedure insertdef(def:TDefEntry);override;
          function is_packed: boolean;
          function has_single_field(out def:TDef): boolean;
          function has_double_field(out def1,def2:TDef; out offset:integer): integer;
          { collects all management operators of the specified type in list (which
            is not cleared); the entries are copies and thus must be freed by the
            caller }
          procedure get_managementoperator_offset_list(mop:TManagementOperator;list:TFPList);
        protected
          { size in bytes including padding }
          _datasize      : asizeint;
          { size in bits of the data in case of bitpacked record. Only important during construction, }
          { no need to save in/restore from ppu file. datasize is always (databitsize+7) div 8.       }
          databitsize    : asizeint;
          { size in bytes of padding }
          _paddingsize   : word;
          { array of tmanagementoperator_offset_entry lists; only assigned if
            they had been queried once by get_management_operator_list }
          mop_list : array[TManagementOperator] of TFPList;
          procedure setdatasize(val: asizeint);
          function getfieldoffset(sym: TFieldVarSym; base: asizeint; var globalfieldalignment: shortint): asizeint;
          procedure do_get_managementoperator_offset_list(data:tobject;arg:pointer);
        public
          function iscurrentunit: boolean; override;
          property DataSize : asizeint read _datasize write setdatasize;
          property paddingsize: word read _paddingsize write _paddingsize;

       end;

       TRecordSymTable = class(TAbstractRecordSymTable)
       public
          { maybe someday is worth to move managementoperators to              }
          { tabstractrecordsymtable to perform management class operators for  }
          { object/classes. In XE5 and newer is possible to use class operator }
          { for classes (like for Delphi .NET before) only for Delphi NEXTGEN  }
          managementoperators : TManagementOperators;
          constructor create(const n:string;usealign,recordminalign:shortint);
          procedure insertunionst(unionst : TRecordSymTable;offset : asizeint);
          procedure includemanagementoperator(mop:TManagementOperator);
       end;

       TObjectSymTable = class(TAbstractRecordSymTable)
       public
          constructor create(adefowner:TDef;const n:string;usealign,recordminalign:shortint);
          function  checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
       end;



       { tabstractsubsymtable }

       TAbstractSubSymTable = class(TStoredSymTable)
       public
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
       end;

       { tabstractlocalsymtable }

       TAbstractLocalSymTable = class(TAbstractSubSymTable)
       public
          function count_locals:LongInt;
          function iscurrentunit: boolean; override;
       end;

       TLocalSymTable = class(TAbstractLocalSymTable)
       public
          constructor create(adefowner:TDef;level:byte);
          function checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
       end;

       { tparasymtable }

       TParaSymTable = class(TAbstractLocalSymTable)
       public
          constructor create(adefowner:TDef;level:byte);
          function checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
       end;

       TAbstractUnitSymTable = class(TStoredSymTable)
       public
          constructor create(const n : string;id:word);
          function checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
          function findnamespace(const n:string):TSymEntry;virtual;
          function iscurrentunit:boolean;override;
          function needs_init_final: boolean; override;
          procedure insertunit(sym:TSymEntry);
          function has_class_condestructors: boolean;
       end;

       TGlobalSymTable = class(TAbstractUnitSymTable)
       public
          unittypecount : word;
          constructor create(const n : string;id:word);
          procedure ppuload(ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
       end;

       TStaticSymTable = class(TAbstractUnitSymTable)
       public
          constructor create(const n : string;id:word);
          procedure ppuload(ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;override;
          function findnamespace(const n:string):TSymEntry;override;
       end;

       TSpecializeSymTable = class(TGlobalSymTable)
       public
          constructor create(const n : string;id:word);
          function iscurrentunit:boolean;override;
       end;

       TWithSymTable = class(TSymTable)
          withrefnode : tobject; { tnode }
          constructor create(aowner:TDef;ASymList:TFPHashObjectList;refnode:tobject{tnode});
          destructor  Destroy;override;
          procedure clear;override;
          procedure insertdef(def:TDefEntry);override;
        end;

       TSTTExceptSymTable = class(TSymTable)
       public
          constructor create;
       end;

       TMacroSymTable = class(TStoredSymTable)
       public
          constructor create(exported: boolean);
       end;

       { tenumsymtable }

       TEnumSymTable = class(TAbstractSubSymTable)
       public
          procedure insertsym(sym: TSymEntry; checkdup: boolean = true); override;
          constructor create(adefowner:TDef);
       end;

       { tarraysymtable }

       TArraySymTable = class(TAbstractSubSymTable)
       public
          procedure insertdef(def:TDefEntry);override;
          constructor create(adefowner:TDef);
       end;

    var
       systemunit     : TGlobalSymTable; { pointer to the system unit }

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
    function  FullTypeName(def,otherdef:TDef):string;
    function generate_nested_name(SymTable:TSymTable;const delimiter:string):string;
    { def is the extended type of a helper }
    function generate_objectpascal_helper_key(def:TDef):TSymStr;
    procedure incompatibletypes(def1,def2:TDef);
    procedure hidesym(sym:TSymEntry);
    procedure duplicatesym(var hashedid: THashedIDString; dupsym, origsym:TSymEntry; warn: boolean);
    function handle_generic_dummysym(sym:TSymEntry;var symoptions:TSymOptions):boolean;
    { writes all declarations for the specified system unit symbol }
    procedure write_system_parameter_lists(const name:string);

{*** Search ***}
    procedure addsymref(sym:TSym);inline;
    procedure addsymref(sym:TSym;def:TDef);
    function  is_owned_by(nesteddef,ownerdef:TDef):boolean;
    function  sym_is_owned_by(childsym:TSym;SymTable:TSymTable):boolean;
    function  defs_belong_to_same_generic(def1,def2:TDef):boolean;
    function  get_generic_in_hierarchy_by_name(srsym:TSym;def:TDef):TDef;
    function  return_specialization_of_generic(nesteddef,genericdef:TDef;out resultdef:TDef):boolean;
    function  is_visible_for_object(symst:TSymTable;symvisibility:TVisibility;contextobjdef:TAbstractRecordDef):boolean;
    function  is_visible_for_object(pd:TProcDef;contextobjdef:TAbstractRecordDef):boolean;
    function  is_visible_for_object(sym:TSym;contextobjdef:TAbstractRecordDef):boolean;
    function  searchsym(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
    function  searchsym_with_flags(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
    function  searchsym_maybe_with_symoption(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags;option:TSymOption):boolean;
    { searches for a symbol with the given name that has the given option in
      symoptions set }
    function  searchsym_with_symoption(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;option:TSymOption):boolean;
    function  searchsym_type(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
    function  searchsym_in_module(pm:pointer;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
    function  searchsym_in_named_module(const unitname, symname: TIDString; out srsym: TSym; out srsymtable: TSymTable): boolean;
    function  searchsym_in_class(classh: TObjectDef; contextclassh:TAbstractRecordDef;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
    function  searchsym_in_record(recordh:TAbstractRecordDef;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
    function  searchsym_in_class_by_msgint(classh:TObjectDef;msgid:LongInt;out srdef : TDef;out srsym:TSym;out srsymtable:TSymTable):boolean;
    function  searchsym_in_class_by_msgstr(classh:TObjectDef;const s:string;out srsym:TSym;out srsymtable:TSymTable):boolean;
    { searches symbols inside of a helper's implementation }
    function  searchsym_in_helper(classh,contextclassh:TObjectDef;const s: TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
    function  search_system_type(const s: TIDString): TTypeSym;
    function  try_search_system_type(const s: TIDString): TTypeSym;
    function  try_search_current_module_type(const s: TIDString): TTypeSym;
    function  search_system_proc(const s: TIDString): TProcDef;
    function  search_named_unit_globaltype(const unitname, typename: TIDString; throwerror: boolean): TTypeSym;
    function  search_struct_member(pd : TAbstractRecordDef;const s : string):TSym;
    function  search_struct_member_no_helper(pd : TAbstractRecordDef;const s : string):TSym;
    function  search_assignment_operator(from_def,to_def:TDef;explicit:boolean):TProcDef;
    function  search_enumerator_operator(from_def,to_def:TDef):TProcDef;
    function  search_management_operator(mop:TManagementOperator;pd:TDef):TProcDef;
    { searches for the helper definition that's currently active for pd }
    function  search_last_objectpascal_helper(pd : TDef;contextclassh : TAbstractRecordDef;out odef : TObjectDef):boolean;
    { searches whether the symbol s is available in the currently active }
    { helper for pd }
    function  search_objectpascal_helper(pd : TDef;contextclassh : TAbstractRecordDef;const s : string; out srsym: TSym; out srsymtable: TSymTable):boolean;
    function  search_objc_helper(pd : TObjectDef;const s : string; out srsym: TSym; out srsymtable: TSymTable):boolean;
    function  search_objc_method(const s : string; out srsym: TSym; out srsymtable: TSymTable):boolean;
    {Looks for macro s (must be given in upper case) in the macrosymbolstack, }
    {and returns it if found. Returns nil otherwise.}
    function  search_macro(const s : string):TSym;
    { Additionally to searching for a macro, also checks whether it's still }
    { actually defined (could be disable using "undef")                     }
    function  defined_macro(const s : string):boolean;
    { Look for a system procedure (no overloads supported) }
    { returns a list of helpers in the current module for the def }
    function get_objectpascal_helpers(pd : TDef):TFPObjectList;

{*** Object Helpers ***}
    function search_default_property(pd : TAbstractRecordDef) : TPropertySym;
    function maybe_find_real_class_definition(pd: TDef; erroronfailure: boolean): TDef;
    function find_real_class_definition(pd: TObjectDef; erroronfailure: boolean): TObjectDef;

{*** Macro Helpers ***}
    {If called initially, the following procedures manipulate macros in }
    {initialmacrotable, otherwise they manipulate system macros local to a module.}
    {Name can be given in any case (it will be converted to upper case).}
    procedure def_system_macro(const name : string);
    procedure set_system_macro(const name, value : string);
    procedure set_system_compvar(const name, value : string);
    procedure undef_system_macro(const name : string);

{*** symtable stack ***}
{ $ifdef DEBUG
    procedure test_symtablestack;
    procedure list_symtablestack;
 $endif DEBUG}

{$ifdef UNITALIASES}
    type
       PUnitAlias = ^TUnitAlias;
       TUnitAlias = object(TNamedIndexItem)
          newname : PShortString;
          constructor init(const n:string);
          destructor  done;virtual;
       end;
    var
       unitaliases : pdictionary;

    procedure addunitalias(const n:string);
    function getunitalias(const n:string):string;
{$endif UNITALIASES}

{*** Init / Done ***}
    procedure InitSymtable;
    procedure DoneSymtable;

    const
      overloaded_names : array [NOTOKEN..last_overloaded] of string[16] = (
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

      managementoperator2tok:array[TManagementOperator] of TToken = (
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
      symutil,defutil,defcmp,objcdef,
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
      dupnr : LongInt; { unique number for duplicate symbols }

{*****************************************************************************
                             TStoredSymtable
*****************************************************************************}

    constructor TStoredSymTable.create(const s:string);
      begin
        inherited create(s);
        { Note: this happens for the initial macro symtable, so no error here }
        if not Assigned(CurrentModule) then
          comment(VDebug,'Current module not available for module id')
        else
          ModuleID:=CurrentModule.ModuleID;
      end;


    procedure TStoredSymTable.insertsym(sym:TSymEntry;checkdup:boolean=true);
      begin
        inherited insertsym(sym,checkdup);
        init_final_check_done:=false;
      end;


    procedure TStoredSymTable.deletesym(sym:TSymEntry);
      begin
        inherited deletesym(sym);
        init_final_check_done:=false;
      end;


    procedure TStoredSymTable.ppuload(ppufile:TCompilerPPUFile);
      begin
        { load the table's flags }
        if ppufile.ReadEntry<>IBSymTableOptions then
          Message(unit_f_ppu_read_error);
        ppufile.GetSet(TPPUSet1(tableoptions));

        { load definitions }
        loaddefs(ppufile);

        { load symbols }
        loadsyms(ppufile);

        init_final_check_done:=true;
      end;


    procedure TStoredSymTable.ppuwrite(ppufile:TCompilerPPUFile);
      begin
         { ensure that we have the sto_needs_init_final flag set if needed }
         if not init_final_check_done then
           needs_init_final;

         { write the table's flags }
         ppufile.PutSet(TPPUSet1(tableoptions));
         ppufile.WriteEntry(IBSymTableOptions);

         { write definitions }
         writedefs(ppufile);

         { write symbols }
         writesyms(ppufile);
      end;


    procedure TStoredSymTable.loaddefs(ppufile:TCompilerPPUFile);
      var
        def : TDef;
        b   : byte;
      begin
         { load start of definition section, which holds the amount of defs }
         if ppufile.ReadEntry<>IBStartDefs then
           Message(unit_f_ppu_read_error);
         { read definitions }
         repeat
           b:=ppufile.ReadEntry;
           def:=nil;
           case b of
             IBPointerDef : def:=CPointerDef.ppuload(ppufile);
             IBArrayDef : def:=CArrayDef.ppuload(ppufile);
             IBOrdDef : def:=COrdDef.ppuload(ppufile);
             IBFloatDef : def:=CFloatDef.ppuload(ppufile);
             IBProcDef : def:=CProcDef.ppuload(ppufile);
             IBShortStringDef : def:=CStringDef.loadshort(ppufile);
             IBLongStringDef : def:=CStringDef.loadlong(ppufile);
             IBAnsiStringDef : def:=CStringDef.loadansi(ppufile);
             IBWideStringDef : def:=CStringDef.loadwide(ppufile);
             IBUnicodeStringDef : def:=CStringDef.loadunicode(ppufile);
             IBRecordDef : def:=CRecordDef.ppuload(ppufile);
             IBObjectDef : def:=CObjectDef.ppuload(ppufile);
             IBEnumDef : def:=CEnumDef.ppuload(ppufile);
             IBSetDef : def:=CSetDef.ppuload(ppufile);
             IBProcVarDef : def:=CProcVarDef.ppuload(ppufile);
             IBFileDef : def:=CFileDef.ppuload(ppufile);
             IBClassRefDef : def:=CClassRefDef.ppuload(ppufile);
             IBFormalDef : def:=CFormalDef.ppuload(ppufile);
             IBVariantDef : def:=CVariantDef.ppuload(ppufile);
             IBUndefinedDef : def:=CUndefinedDef.ppuload(ppufile);
             IBEndDefs : break;
             IBEnd : Message(unit_f_ppu_read_error);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(b));
           end;
           if Assigned(def) then
             TStoredDef(def).PPULoadSubEntries(ppufile);
           InsertDef(def);
         until false;
      end;


    procedure TStoredSymTable.loadsyms(ppufile:TCompilerPPUFile);
      var
        b   : byte;
        sym : TSym;
      begin
         { load start of definition section, which holds the amount of defs }
         if ppufile.ReadEntry<>IBStartSyms then
          Message(unit_f_ppu_read_error);
         { now read the symbols }
         repeat
           sym:=nil;
           b:=ppufile.ReadEntry;
           case b of
                IBTypeSym : sym:=CTypeSym.ppuload(ppufile);
                IBProcSym : sym:=CProcSym.ppuload(ppufile);
               IBConstSym : sym:=CConstSym.ppuload(ppufile);
           IBStaticVarSym : sym:=CStaticVarSym.ppuload(ppufile);
            IBLocalVarSym : sym:=CLocalVarSym.ppuload(ppufile);
             IBParaVarSym : sym:=CParaVarSym.ppuload(ppufile);
            IBFieldVarSym : sym:=CFieldVarSym.ppuload(ppufile);
         IBAbsoluteVarSym : sym:=CAbsoluteVarSym.ppuload(ppufile);
                IBEnumSym : sym:=CEnumSym.ppuload(ppufile);
            IBPropertySym : sym:=CPropertySym.ppuload(ppufile);
                IBUnitSym : sym:=CUnitSym.ppuload(ppufile);
               IBLabelSym : sym:=CLabelSym.ppuload(ppufile);
                 IBSysSym : sym:=CSysSym.ppuload(ppufile);
               IBMacroSym : sym:=TMacro.ppuload(ppufile);
           IBNamespaceSym : sym:=CNamespaceSym.ppuload(ppufile);
                IBEndSyms : break;
                    IBEnd : Message(unit_f_ppu_read_error);
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(b));
           end;
           if Assigned(sym) then
             TStoredSym(sym).PPULoadSubEntries(ppufile);
           InsertSym(sym,false);
         until false;
      end;


    procedure TStoredSymTable.writedefs(ppufile:TCompilerPPUFile);
      var
        defcount,
        i   : LongInt;
        def : TStoredDef;
      begin
        defcount:=0;
        for i:=0 to DefList.Count-1 do
          if TStoredDef(DefList[i]).IsRegistered then
            inc(defcount);
        { each definition get a number, write then the amount of defs to the
          ibstartdef entry }
        ppufile.PutLongInt(defcount);
        ppufile.WriteEntry(IBStartDefs);
        { now write the definition }
        for i:=0 to DefList.Count-1 do
          begin
            def:=TStoredDef(DefList[i]);
            if def.IsRegistered then
              begin
                def.ppuwrite(ppufile);
                def.PPUWriteSubEntries(ppufile);
              end;
          end;
        { write end of definitions }
        ppufile.WriteEntry(IBEndDefs);
      end;


    procedure TStoredSymTable.writesyms(ppufile:TCompilerPPUFile);
      var
        symcount,
        i   : LongInt;
        sym : TStoredSym;
      begin
        symcount:=0;
        for i:=0 to SymList.Count-1 do
          if TStoredSym(SymList[i]).IsRegistered then
            inc(symcount);
        { each definition get a number, write then the amount of syms and the
          datasize to the ibsymdef entry }
        ppufile.PutLongInt(symcount);
        ppufile.WriteEntry(IBStartSyms);
        { foreach is used to write all symbols }
        for i:=0 to SymList.Count-1 do
          begin
            sym:=TStoredSym(SymList[i]);
            if sym.IsRegistered then
              begin
                sym.ppuwrite(ppufile);
                sym.PPUWriteSubEntries(ppufile);
              end;
          end;
        { end of symbols }
        ppufile.WriteEntry(IBEndSyms);
      end;

    function TStoredSymTable.is_deref_built: boolean;
    begin
      Result:=deref_built;
    end;

    function TStoredSymTable.is_derefimpl_built: boolean;
    begin
      Result:=derefimpl_built;
    end;

    procedure TStoredSymTable.buildderef;
      var
        i   : LongInt;
        def : TStoredDef;
        sym : TStoredSym;
      begin
        { interface definitions }
        for i:=0 to DefList.Count-1 do
          begin
            def:=TStoredDef(DefList[i]);
            def.buildderef;
          end;
        { interface symbols }
        for i:=0 to SymList.Count-1 do
          begin
            sym:=TStoredSym(SymList[i]);
            sym.buildderef;
          end;
        deref_built:=True;
      end;


    procedure TStoredSymTable.buildderefimpl;
      var
        i   : LongInt;
        def : TStoredDef;
      begin
        { implementation definitions }
        for i:=0 to DefList.Count-1 do
          begin
            def:=TStoredDef(DefList[i]);
            def.buildderefimpl;
          end;
        derefimpl_built:=True;
      end;


    procedure TStoredSymTable.buildderef_registered;
      var
        def : TStoredDef;
        sym : TStoredSym;
        i   : LongInt;
        defidmax,
        symidmax: LongInt;
        newbuiltdefderefs,
        builtdefderefs,
        builtsymderefs: array of boolean;
        changed: boolean;
      begin
        newbuiltdefderefs:=nil;
        builtdefderefs:=nil;
        builtsymderefs:=nil;
        { tdefs for which we already built the deref }
        SetLength(builtdefderefs,deflist.count);
        { tdefs for which we built the deref in this iteration }
        SetLength(newbuiltdefderefs,deflist.count);
        { syms for which we already built the deref }
        SetLength(builtsymderefs,symlist.count);
        repeat
          { we only have to store the defs (recursively) referred by wpo info
            or inlined routines in the static symbtable }

          { current number of registered defs/syms }
          defidmax:=CurrentModule.deflist.count;
          symidmax:=CurrentModule.symlist.count;
          changed:=false;

          { build the derefs for the registered defs we haven't processed yet }
          for i:=0 to DefList.Count-1 do
            begin
              if not builtdefderefs[i] then
                begin
                  def:=TStoredDef(DefList[i]);
                  if def.IsRegistered then
                    begin
                      def.buildderef;
                      newbuiltdefderefs[i]:=true;
                      builtdefderefs[i]:=true;
                      changed:=true;
                    end;
                end;
            end;
          { same for the syms }
          for i:=0 to SymList.Count-1 do
            begin
              if not builtsymderefs[i] then
                begin
                  sym:=TStoredSym(SymList[i]);
                  if sym.IsRegistered then
                    begin
                      sym.buildderef;
                      builtsymderefs[i]:=true;
                      changed:=true;
                    end;
                end;
            end;
          { now buildderefimpl for the defs we processed in this iteration }
          for i:=0 to DefList.Count-1 do
            begin
              if newbuiltdefderefs[i] then
                begin
                  newbuiltdefderefs[i]:=false;
                  TStoredDef(DefList[i]).buildderefimpl;
                  changed:=true;
                end;
            end;
        { stop when no new defs or syms have been registered while processing
          the currently registered ones (defs/syms get added to the module's
          deflist/symlist when they are registered) }
        until not changed and
          (defidmax=CurrentModule.deflist.count) and
          (symidmax=CurrentModule.symlist.count);
      end;


    procedure TStoredSymTable.deref(only_registered: boolean);
      var
        i   : LongInt;
        def : TStoredDef;
        sym : TStoredSym;
      begin
        { first deref the interface ttype symbols. This needs
          to be done before the interface defs are derefed, because
          the interface defs can contain references to the type symbols
          which then already need to contain a resolved typedef field (PFV) }
        for i:=0 to SymList.Count-1 do
          begin
            sym:=TStoredSym(SymList[i]);
            if (sym.typ=typesym) and
               (not only_registered or
                sym.IsRegistered) then
              sym.deref;
          end;
        { interface definitions }
        for i:=0 to DefList.Count-1 do
          begin
            def:=TStoredDef(DefList[i]);
            if not only_registered or
               def.IsRegistered then
              def.deref;
          end;
        { interface symbols }
        for i:=0 to SymList.Count-1 do
          begin
            sym:=TStoredSym(SymList[i]);
            if (not only_registered or
                sym.IsRegistered) and
               (sym.typ<>typesym) then
              sym.deref;
          end;
      end;


    procedure TStoredSymTable.derefimpl(only_registered: boolean);
      var
        i   : LongInt;
        def : TStoredDef;
      begin
        { implementation definitions }
        for i:=0 to DefList.Count-1 do
          begin
            def:=TStoredDef(DefList[i]);
            if not only_registered or
               def.IsRegistered then
              def.derefimpl;
          end;
      end;


    function TStoredSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      var
        hsym : TSym;
      begin
        hsym:=TSym(FindWithHash(hashedid));
        if Assigned(hsym) then
          DuplicateSym(hashedid,sym,hsym,false);
        result:=Assigned(hsym);
      end;


{**************************************
             Callbacks
**************************************}

    procedure TStoredSymTable.check_forward(sym:TObject;arg:pointer);
      begin
         if TSym(sym).typ=procsym then
           TProcSym(sym).check_forward
         { check also object method table            }
         { we needn't to test the def list          }
         { because each object has to have a type sym,
           only test objects declarations, not type renamings }
         else
          if (TSym(sym).typ=typesym) and
             Assigned(TTypeSym(sym).typedef) and
             (TTypeSym(sym).typedef.typesym=TTypeSym(sym)) and
             (TTypeSym(sym).typedef.typ in [objectdef,recorddef]) then
           TAbstractRecordDef(TTypeSym(sym).typedef).check_forwards;
      end;


    procedure TStoredSymTable.check_block_valid(def: TObject; arg: pointer);
      var
        founderrordef: TDef;
      begin
        { all parameters passed to a block must be handled by the Objective-C
          runtime }
        if is_block(TDef(def)) and
           not objcchecktype(TDef(def),founderrordef) then
          if Assigned(TDef(def).typesym) then
            MessagePos1(TDef(def).typesym.fileinfo,type_e_objc_type_unsupported,founderrordef.typename)
          else
            Message1(type_e_objc_type_unsupported,TProcVarDef(def).typename)
      end;


    procedure TStoredSymTable.register_syms(sym:tobject;arg:pointer);
      begin
        TSym(sym).RegisterSym;
      end;


    procedure TStoredSymTable.register_defs(def:tobject;arg:pointer);
      begin
        TDef(def).RegisterDef;
      end;


    procedure TStoredSymTable.labeldefined(sym:TObject;arg:pointer);
      begin
        if (TSym(sym).typ=labelsym) and
           not(TLabelSym(sym).defined) then
         begin
           if TLabelSym(sym).used then
            Message1(sym_e_label_used_and_not_defined,TLabelSym(sym).realname)
           else
            Message1(sym_w_label_not_defined,TLabelSym(sym).realname);
         end;
      end;


    procedure TStoredSymTable.varsymbolused(sym:TObject;arg:pointer);
      begin
         if (TSym(sym).typ in [staticvarsym,localvarsym,paravarsym,fieldvarsym]) and
            ((TSym(sym).owner.symtabletype in
             [parasymtable,localsymtable,ObjectSymtable,recordsymtable,staticsymtable])) then
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
               ([vo_is_hidden_para,vo_is_funcret] * TAbstractVarSym(sym).varoptions = [vo_is_hidden_para]) or
               (sp_internal in TSym(sym).symoptions) or
               ((Assigned(TSym(sym).owner.defowner) and
                (TSym(sym).owner.defowner.typ=procdef) and
                ((df_generic in TProcDef(TSym(sym).owner.defowner).defoptions) or
                 (po_abstractmethod in TProcDef(TSym(sym).owner.defowner).procoptions)))) then
              exit;
            if (TStoredSym(sym).refs=0) then
              begin
                 if (vo_is_funcret in TAbstractVarSym(sym).varoptions) then
                   begin
                     { don't warn about the result of constructors }
                     { or the synthetic helper functions for class-attributes }
                     if ((TSym(sym).owner.symtabletype<>localsymtable) or
                        (TProcDef(TSym(sym).owner.defowner).proctypeoption<>potype_constructor)) and
                        not (po_noreturn in TProcDef(TSym(sym).owner.defowner).procoptions) and
                        not(cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) then
                       MessagePos(TSym(sym).fileinfo,sym_w_function_result_not_set)
                   end
                 else if (TSym(sym).owner.symtabletype=parasymtable) then
                   MessagePos1(TSym(sym).fileinfo,sym_h_para_identifier_not_used,TSym(sym).prettyname)
                 else if (TSym(sym).owner.symtabletype in [ObjectSymtable,recordsymtable]) then
                   MessagePos2(TSym(sym).fileinfo,sym_n_private_identifier_not_used,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname)
                 else
                   MessagePos1(TSym(sym).fileinfo,sym_n_local_identifier_not_used,TSym(sym).prettyname);
              end
            else if TAbstractVarSym(sym).varstate in [vs_written,vs_initialised] then
              begin
                 if (TSym(sym).owner.symtabletype=parasymtable) then
                   begin
                     if not(TAbstractVarSym(sym).varspez in [vs_var,vs_out,vs_constref]) and
                        not(vo_is_funcret in TAbstractVarSym(sym).varoptions) then
                       MessagePos1(TSym(sym).fileinfo,sym_h_para_identifier_only_set,TSym(sym).prettyname)
                   end
                 else if (TSym(sym).owner.symtabletype in [ObjectSymtable,recordsymtable]) then
                   MessagePos2(TSym(sym).fileinfo,sym_n_private_identifier_only_set,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname)
                 else if TAbstractVarSym(sym).varoptions*[vo_is_funcret,vo_is_public,vo_is_external]=[] then
                   MessagePos1(TSym(sym).fileinfo,sym_n_local_identifier_only_set,TSym(sym).prettyname);
              end
            else if (TAbstractVarSym(sym).varstate = vs_read_not_warned) and
                    ([vo_is_public,vo_is_external] * TAbstractVarSym(sym).varoptions = []) then
              MessagePos1(TSym(sym).fileinfo,sym_w_identifier_only_read,TSym(sym).prettyname)
          end
        else if ((TSym(sym).owner.symtabletype in
              [ObjectSymtable,parasymtable,localsymtable,staticsymtable,recordsymtable])) then
          begin
           if (ErrorCount<>0) or
              (sp_internal in TSym(sym).symoptions) then
             exit;
           { do not claim for inherited private fields !! }
           if (TSym(sym).refs=0) and (TSym(sym).owner.symtabletype in [ObjectSymtable,recordsymtable]) then
             case TSym(sym).typ of
               typesym:
                 MessagePos2(TSym(sym).fileinfo,sym_n_private_type_not_used,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname);
               constsym:
                 MessagePos2(TSym(sym).fileinfo,sym_n_private_const_not_used,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname);
               propertysym:
                 MessagePos2(TSym(sym).fileinfo,sym_n_private_property_not_used,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname);
             else
               MessagePos2(TSym(sym).fileinfo,sym_n_private_method_not_used,TAbstractRecordDef(TSym(sym).owner.defowner).GetTypeName,TSym(sym).prettyname);
             end
           { units references are problematic }
           else
            begin
              if (TSym(sym).refs=0) and
                 not(TSym(sym).typ in [enumsym,unitsym,namespacesym]) and
                 not(is_funcret_sym(TSym(sym))) and
                 { don't complain about compiler generated syms for specializations, see also #13405 }
                 not((TSym(sym).typ=typesym) and (df_specialization in TTypeSym(sym).typedef.defoptions) and
                    (pos('$',TTypeSym(sym).Realname)<>0)) and
                 (
                  (TSym(sym).typ<>procsym) or
                  ((TSym(sym).owner.symtabletype=staticsymtable) and
                   not CurrentModule.is_unit)
                 ) and
                 { don't complain about alias for hidden _cmd parameter to
                   obj-c methods }
                 not((TSym(sym).typ in [localvarsym,paravarsym,absolutevarsym]) and
                     (vo_is_msgsel in TAbstractVarSym(sym).varoptions)) then
                MessagePos2(TSym(sym).fileinfo,sym_h_local_symbol_not_used,SymTypeName[TSym(sym).typ],TSym(sym).prettyname);
            end;
          end;
      end;


    procedure TStoredSymTable.TestPrivate(sym:TObject;arg:pointer);
      begin
        if TSym(sym).visibility in [vis_private,vis_strictprivate] then
          varsymbolused(sym,arg);
      end;


    procedure TStoredSymTable.objectprivatesymbolused(sym:TObject;arg:pointer);
      begin
         {
           Don't test simple object aliases PM
         }
         if (TSym(sym).typ=typesym) and
            (TTypeSym(sym).typedef.typ in [objectdef,recorddef]) and
            (TTypeSym(sym).typedef.typesym=TSym(sym)) then
           TAbstractRecordDef(TTypeSym(sym).typedef).SymTable.SymList.ForEachCall(@TestPrivate,nil);
      end;


   procedure TStoredSymTable.testfordefaultproperty(sym:TObject;arg:pointer);
     begin
        if (TSym(sym).typ=propertysym) and
           (ppo_defaultproperty in TPropertySym(sym).propoptions) then
          ppointer(arg)^:=sym;
     end;


   procedure TStoredSymTable.register_children;
     begin
       SymList.ForEachCall(@register_syms,nil);
       DefList.ForEachCall(@register_defs,nil);
     end;


{***********************************************
           Process all entries
***********************************************}

    { checks, if all procsyms and methods are defined }
    procedure TStoredSymTable.check_forwards;
      begin
         SymList.ForEachCall(@check_forward,nil);
         { check whether all block definitions contain valid Objective-C types
           (now that all forward definitions have been resolved) }
         DefList.ForEachCall(@check_block_valid,nil);
      end;


    procedure TStoredSymTable.checklabels;
      begin
         SymList.ForEachCall(@labeldefined,nil);
      end;


    procedure TStoredSymTable.allsymbolsused;
      begin
         SymList.ForEachCall(@varsymbolused,nil);
      end;


    procedure TStoredSymTable.allprivatesused;
      begin
         SymList.ForEachCall(@objectprivatesymbolused,nil);
      end;


    procedure TStoredSymTable._needs_init_final(sym:TObject;arg:pointer);
      begin
         if [sto_needs_init_final,sto_has_non_trivial_init] <= tableoptions then
           exit;
         { don't check static symbols - they can be present in structures only and
           always have a reference to a symbol defined on unit level }
         if sp_static in TSym(sym).symoptions then
           exit;
         case TSym(sym).typ of
           fieldvarsym,
           staticvarsym,
           localvarsym,
           paravarsym :
             begin
               if Assigned(TAbstractVarSym(sym).vardef) and
                  is_managed_type(TAbstractVarSym(sym).vardef) then
                 include(tableoptions,sto_needs_init_final);
               if is_record((TAbstractVarSym(sym).vardef)) and
                   (mop_initialize in TRecordSymTable(TRecordDef(TAbstractVarSym(sym).vardef).SymTable).managementoperators) then
                 include(tableoptions,sto_has_non_trivial_init);
             end;
           else
             ;
         end;
      end;


    procedure TStoredSymTable.do_init_final_check;
      begin
         if not init_final_check_done then
           begin
             exclude(tableoptions,sto_needs_init_final);
             exclude(tableoptions,sto_has_non_trivial_init);
             SymList.ForEachCall(@_needs_init_final,nil);
             init_final_check_done:=true;
           end;
      end;

    { returns true, if p contains data which needs init/final code }
    function TStoredSymTable.needs_init_final : boolean;
      begin
         do_init_final_check;
         result:=sto_needs_init_final in tableoptions;
      end;


    function TStoredSymTable.has_non_trivial_init:boolean;
      begin
        do_init_final_check;
        result:=sto_has_non_trivial_init in tableoptions;
      end;


{****************************************************************************
                          TAbstractRecordSymtable
****************************************************************************}



    constructor TAbstractRecordSymTable.create(const n:string;usealign,recordminalign:shortint);
      begin
        inherited create(n);
        _datasize:=0;
        databitsize:=0;
        recordalignment:=1;
        explicitrecordalignment:=0;
        usefieldalignment:=usealign;
        RecordAlignMin:=recordminalign;
        padalignment:=1;
        { recordalign C_alignment means C record packing, that starts
          with an alignment of 1 }
        case usealign of
          C_alignment,
          bit_alignment:
            fieldalignment:=1;
          mac68k_alignment:
            fieldalignment:=2;
          else
            fieldalignment:=usealign;
        end;
      end;


    destructor TAbstractRecordSymTable.Destroy;
      var
        mop : TManagementOperator;
      begin
        if refcount>1 then
          exit;

        for mop:=low(TManagementOperator) to high(TManagementOperator) do
          TFPList.FreeAndNilDisposing(mop_list[mop],TypeInfo(TManagementOperatorOffsetEntry));
        inherited Destroy;
      end;


    procedure TAbstractRecordSymTable.ppuload(ppufile:TCompilerPPUFile);
      begin
        if ppufile.ReadEntry<>IBRecSymTableOptions then
          Message(unit_f_ppu_read_error);
        recordalignment:=shortint(ppufile.GetByte);
        explicitrecordalignment:=shortint(ppufile.GetByte);
        usefieldalignment:=shortint(ppufile.GetByte);
        RecordAlignMin:=shortint(ppufile.GetByte);
        if (usefieldalignment=C_alignment) then
          fieldalignment:=shortint(ppufile.GetByte);
        ppufile.GetSet(TPPUSet1(has_fields_with_mop));
        inherited ppuload(ppufile);
      end;


    procedure TAbstractRecordSymTable.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldtyp : byte;
      begin
         oldtyp:=ppufile.entrytyp;
         ppufile.entrytyp:=SubEntryID;
         { in case of classes using C alignment, the alignment of the parent
           affects the alignment of fields of the childs }
         ppufile.PutByte(byte(recordalignment));
         ppufile.PutByte(byte(explicitrecordalignment));
         ppufile.PutByte(byte(usefieldalignment));
         ppufile.PutByte(byte(RecordAlignMin));
         if (usefieldalignment=C_alignment) then
           ppufile.PutByte(byte(fieldalignment));
         { it's not really a "symtableoption", but loading this from the record
           def requires storing the set in the recorddef at least between
           ppuload and deref/derefimpl }
         ppufile.PutSet(TPPUSet1(has_fields_with_mop));
         ppufile.WriteEntry(IBRecSymTableOptions);

         inherited ppuwrite(ppufile);

         ppufile.entrytyp:=oldtyp;
      end;


    function field2recordalignment(fieldoffs, fieldalign: asizeint): asizeint;
      begin
        { optimal alignment of the record when declaring a variable of this }
        { type is independent of the packrecords setting                    }
        if (fieldoffs mod fieldalign) = 0 then
          result:=fieldalign
        else if (fieldalign >= 16) and
                ((fieldoffs mod 16) = 0) and
                ((fieldalign mod 16) = 0) then
          result:=16
        else if (fieldalign >= 8) and
                ((fieldoffs mod 8) = 0) and
                ((fieldalign mod 8) = 0) then
          result:=8
        else if (fieldalign >= 4) and
                ((fieldoffs mod 4) = 0) and
                ((fieldalign mod 4) = 0) then
          result:=4
        else if (fieldalign >= 2) and
                ((fieldoffs mod 2) = 0) and
                ((fieldalign mod 2) = 0) then
          result:=2
        else
          result:=1;
      end;

    procedure TAbstractRecordSymTable.alignrecord(fieldoffset:asizeint;varalign:shortint);
      var
        varalignrecord: shortint;
      begin
        case usefieldalignment of
          C_alignment:
            varalignrecord:=Used_Align(varalign,RecordAlignMin,CurrentSettings.alignment.MaxCRecordAlign);
          mac68k_alignment:
            varalignrecord:=2;
          else
            varalignrecord:=field2recordalignment(fieldoffset,varalign);
        end;
        recordalignment:=max(recordalignment,varalignrecord);
      end;

    procedure TAbstractRecordSymTable.addfield(sym:TFieldVarSym;vis:TVisibility);
      var
        l      : asizeint;
        varalign : shortint;
        vardef : TDef;
      begin
        if (sym.owner<>self) then
          InternalError(200602031);
        if sym.fieldoffset<>-1 then
          InternalError(200602032);
        { set visibility for the symbol }
        sym.visibility:=vis;
        { this symbol can't be loaded to a register }
        sym.varregable:=vr_none;
        { management operators }
        if sym.vardef.typ in [recorddef,objectdef] then
          has_fields_with_mop:=has_fields_with_mop + TAbstractRecordSymTable(TAbstractRecordDef(sym.vardef).SymTable).has_fields_with_mop;
        if sym.vardef.typ=recorddef then
          has_fields_with_mop:=has_fields_with_mop + TRecordSymTable(TRecordDef(sym.vardef).SymTable).managementoperators;
        { Calculate field offset }
        l:=sym.getsize;
        vardef:=sym.vardef;
        varalign:=vardef.structalignment;
        case usefieldalignment of
          bit_alignment:
            begin
              { bitpacking only happens for ordinals, the rest is aligned at }
              { 1 byte (compatible with GPC/GCC)                             }
              if is_ordinal(vardef) then
                begin
                  sym.fieldoffset:=databitsize;
                  l:=sym.getpackedbitsize;
                end
              else
                begin
                  databitsize:=_datasize*8;
                  sym.fieldoffset:=databitsize;
                  if (l>high(asizeint) div 8) then
                    Message(sym_e_segment_too_large);
                  l:=l*8;
                end;
              if varalign=0 then
                varalign:=Size_2_Align(l);
              recordalignment:=max(recordalignment,field2recordalignment(databitsize mod 8,varalign));
              { bit packed records are limited to high(aint) bits }
              { instead of bytes to avoid double precision        }
              { arithmetic in offset calculations                 }
              if int64(l)>high(asizeint)-sym.fieldoffset then
                begin
                  Message(sym_e_segment_too_large);
                  _datasize:=high(asizeint);
                  databitsize:=high(asizeint);
                end
              else
                begin
                  databitsize:=sym.fieldoffset+l;
                  _datasize:=(databitsize+7) div 8;
                end;
              { rest is not applicable }
              exit;
            end;
          else
            begin
              sym.fieldoffset:=getfieldoffset(sym,_datasize,fieldalignment);
              if l>high(asizeint)-sym.fieldoffset then
                begin
                  Message(sym_e_segment_too_large);
                  _datasize:=high(asizeint);
                end
              else
                _datasize:=sym.fieldoffset+l;
              { Calc alignment needed for this record }
              alignrecord(sym.fieldoffset,varalign);
            end;
        end;
      end;


    function field_alignment_compare(item1, item2: pointer): integer;
      var
        field1: TFieldVarSym absolute item1;
        field2: TFieldVarSym absolute item2;
      begin
        { we don't care about static fields, those become global variables }
        if (sp_static in field1.symoptions) or
           (sp_static in field2.symoptions) then
          exit(0);
        { sort from large to small alignment, and in case of the same alignment
          in declaration order (items declared close together are possibly
          also related and hence possibly used together -> putting them next
          to each other can improve cache behaviour) }
        result:=field2.vardef.alignment-field1.vardef.alignment;
        if result=0 then
          result:=field1.fieldoffset-field2.fieldoffset;
      end;


    procedure TAbstractRecordSymTable.addfieldlist(list: TFPObjectList; maybereorder: boolean);
      var
        fieldvs, insertfieldvs: TFieldVarSym;
        base, fieldoffset, space, insertfieldsize, insertfieldoffset, bestinsertfieldoffset, bestspaceleft: asizeint;
        i, j, bestfieldindex: LongInt;
        globalfieldalignment,
        prevglobalfieldalignment,
        newfieldalignment: shortint;
        changed: boolean;
      begin
        if maybereorder and
           (cs_opt_reorder_fields in CurrentSettings.OptimizerSwitches) and
           (list.count>1) then
          begin
            { assign dummy field offsets so we can know their order in the
              sorting routine }
            for i:=0 to list.count-1 do
              begin
                fieldvs:=TFieldVarSym(list[i]);
                if sp_static in fieldvs.symoptions then
                  continue;
                fieldvs.fieldoffset:=i;
              end;
            { sort the non-class fields to minimise losses due to alignment }
            list.sort(@field_alignment_compare);
            { now fill up gaps caused by alignment skips with smaller fields
              where possible }
            repeat
              i:=0;
              base:=_datasize;
              globalfieldalignment:=fieldalignment;
              changed:=false;
              while i<list.count do
                begin
                  fieldvs:=TFieldVarSym(list[i]);
                  if sp_static in fieldvs.symoptions then
                    begin
                      inc(i);
                      continue;
                    end;
                  prevglobalfieldalignment:=globalfieldalignment;
                  fieldoffset:=getfieldoffset(fieldvs,base,globalfieldalignment);
                  newfieldalignment:=globalfieldalignment;

                  { size of the gap between the end of the previous field and
                    the start of the current one }
                  space:=fieldoffset-base;
                  bestspaceleft:=space;
                  while space>0 do
                    begin
                      bestfieldindex:=-1;
                      bestinsertfieldoffset:=-1;
                      for j:=i+1 to list.count-1 do
                        begin
                          insertfieldvs:=TFieldVarSym(list[j]);
                          if sp_static in insertfieldvs.symoptions then
                            continue;
                          insertfieldsize:=insertfieldvs.getsize;
                          { can the new field fit possibly in the gap? }
                          if insertfieldsize<=space then
                            begin
                             { restore globalfieldalignment to situation before
                               the original field was inserted }
                              globalfieldalignment:=prevglobalfieldalignment;
                              { at what offset would it be inserted? (this new
                                field has its own alignment requirements, which
                                may make it impossible to fit after all) }
                              insertfieldoffset:=getfieldoffset(insertfieldvs,base,globalfieldalignment);
                              globalfieldalignment:=prevglobalfieldalignment;
                              { taking into account the alignment, does it still
                                fit and if so, does it fit better than the
                                previously found best fit? }
                              if (insertfieldoffset+insertfieldsize<=fieldoffset) and
                                 (fieldoffset-insertfieldoffset-insertfieldsize<bestspaceleft) then
                                begin
                                  { new best fit }
                                  bestfieldindex:=j;
                                  bestinsertfieldoffset:=insertfieldoffset;
                                  bestspaceleft:=fieldoffset-insertfieldoffset-insertfieldsize;
                                  if bestspaceleft=0 then
                                    break;
                                end;
                            end;
                        end;
                      { if we didn't find any field to fit, stop trying for this
                        gap }
                      if bestfieldindex=-1 then
                        break;
                      changed:=true;
                      { we found a field to insert -> adjust the new base
                        address }
                      base:=bestinsertfieldoffset+TFieldVarSym(list[bestfieldindex]).getsize;
                      { update globalfieldalignment for this newly inserted
                        field }
                      getfieldoffset(TFieldVarSym(list[bestfieldindex]),base,globalfieldalignment);
                      { move the new field before the current one }
                      list.move(bestfieldindex,i);
                      { and skip the new field (which is now at position i) }
                      inc(i);
                      { there may be more space left -> continue }
                      space:=bestspaceleft;
                    end;
                  if base>fieldoffset then
                    InternalError(2012071302);
                  { check the next field }
                  base:=fieldoffset+fieldvs.getsize;
                  { since the original field had the same or greater alignment
                    than anything we inserted before it, the global field
                    alignment is still the same now as it was originally after
                    inserting that field }
                  globalfieldalignment:=newfieldalignment;
                  inc(i);
                end;
            { there may be small gaps left *before* inserted fields }
          until not changed;
        end;
        { reset the dummy field offsets }
        for i:=0 to list.count-1 do
          begin
            fieldvs:=TFieldVarSym(list[i]);
            if sp_static in fieldvs.symoptions then
              continue;
            fieldvs.fieldoffset:=-1;
          end;
        { finally, set the actual field offsets }
        for i:=0 to list.count-1 do
          begin
            fieldvs:=TFieldVarSym(list[i]);
            { static data fields are already inserted in the globalsymtable }
            if not(sp_static in fieldvs.symoptions) then
              begin
                { read_record_fields already set the visibility of the fields,
                  because a single list can contain symbols with different
                  visibility }
                addfield(fieldvs,fieldvs.visibility);
              end;
          end;
      end;


    function TAbstractRecordSymTable.findfieldbyoffset(offset: asizeint): TFieldVarSym;
      var
        i: LongInt;
        sym: TSym;
      begin
        { there could be multiple fields in case of a variant record }
        if (defowner.typ=recorddef) and
           TRecordDef(defowner).isunion then
          InternalError(2014090403);
        for i:=0 to SymList.count-1 do
          begin
            sym:=TSym(symlist[i]);
            if is_normal_fieldvarsym(sym) and
               (TFieldVarSym(sym).fieldoffset>=offset) then
              begin
                result:=TFieldVarSym(sym);
                exit;
              end;
          end;
        result:=nil;
      end;


    procedure TAbstractRecordSymTable.addalignmentpadding;
      var
        padded_datasize: asizeint;
      begin
        { make the record size aligned correctly so it can be
          used as elements in an array. For C records we
          use the fieldalignment, because that is updated with the
          used alignment. }
        if (padalignment = 1) then
          case usefieldalignment of
            C_alignment:
              padalignment:=fieldalignment;
            { bitpacked }
            bit_alignment:
              padalignment:=1;
            { mac68k: always round to multiple of 2 }
            mac68k_alignment:
              padalignment:=2;
            { default/no packrecords specified }
            0:
              padalignment:=recordalignment
            { specific packrecords setting -> use as upper limit }
            else
              padalignment:=min(recordalignment,usefieldalignment);
          end;
        padded_datasize:=align(_datasize,padalignment);
        _paddingsize:=padded_datasize-_datasize;
        _datasize:=padded_datasize;
      end;


    procedure TAbstractRecordSymTable.insertdef(def:TDefEntry);
      begin
        { Enums must also be available outside the record scope,
          insert in the owner of this symtable }
        if def.typ=enumdef then
          defowner.owner.insertdef(def)
        else
          inherited insertdef(def);
      end;


    function TAbstractRecordSymTable.is_packed: boolean;
      begin
        result:=usefieldalignment=bit_alignment;
      end;


    function TAbstractRecordSymTable.has_double_field(out def1,def2:TDef; out offset:integer): integer;
      var
        i,cnt: LongInt;
        currentsymlist: TFPHashObjectList;
        sym: TFieldVarSym;
      begin
        has_double_field := 0;
        offset := 0;
        if (defowner.typ=recorddef) and
           TRecordDef(defowner).isunion then
          exit;
        currentsymlist:=symlist;
        if currentsymlist = nil then
          exit;
        if currentsymlist.Count <> 2 then
          exit;
        if is_normal_fieldvarsym(TSym(currentsymlist[0])) then
          begin
            sym:=TFieldVarSym(currentsymlist[0]);
            def1 := sym.vardef;
          end
        else
          exit;
        if is_normal_fieldvarsym(TSym(currentsymlist[1])) then
          begin
            sym:=TFieldVarSym(currentsymlist[1]);
            def2 := sym.vardef;
          end
        else
          exit;
        offset := sym.fieldoffset;
        if def2.typ = def1.typ then
          cnt := 2
        else
          cnt := 1;
        if offset = 0 then
          cnt := 0;
        has_double_field := cnt;
      end;


    function TAbstractRecordSymTable.has_single_field(out def:TDef): boolean;
      var
        i: LongInt;
        currentsymlist: TFPHashObjectList;
        currentdef: TDef;
        sym: TFieldVarSym;
      begin
        result:=false;
        def:=generrordef;
        { If a record contains a union, it does not contain a "single
          non-composite field" in the context of certain ABIs requiring
          special treatment for such records }
        if (defowner.typ=recorddef) and
           TRecordDef(defowner).isunion then
          exit;
        { a record/object can contain other things than fields }
        currentsymlist:=symlist;
        { recurse in arrays and records }
        while true do
          begin
            sym:=nil;
            { record has one field? }
            for i:=0 to currentsymlist.Count-1 do
              begin
                if is_normal_fieldvarsym(TSym(currentsymlist[i])) then
                  begin
                    if result then
                      begin
                        result:=false;
                        exit;
                      end;
                    result:=true;
                    sym:=TFieldVarSym(currentsymlist[i]);
                  end;
              end;
            if Assigned(sym) then
              begin
                { if the field is an array, does it contain one element? }
                currentdef:=sym.vardef;
                while (currentdef.typ=arraydef) and
                      not is_special_array(currentdef) do
                  begin
                    if TArrayDef(currentdef).elecount<>1 then
                      begin
                        result:=false;
                        exit;
                      end;
                    currentdef:=TArrayDef(currentdef).elementdef;
                  end;
                { if the array element is again a record, continue descending }
                if currentdef.typ=recorddef then
                  begin
                    { the record might be empty, so reset the result until we've
                      really found something }
                    result:=false;
                    currentsymlist:=TRecordDef(currentdef).SymTable.SymList
                  end
                else
                  begin
                    { otherwise we found the type of the single element }
                    def:=currentdef;
                    exit;
                  end;
              end
            else
              exit
          end;
      end;


    procedure TAbstractRecordSymTable.do_get_managementoperator_offset_list(data:tobject;arg:pointer);
      var
        sym : TSym absolute data;
        fsym : TFieldVarSym absolute data;
        mop : TManagementOperator;
        entry : PManagementOperatorOffsetEntry;
        sublist : TFPList;
        i : LongInt;
      begin
        if not is_normal_fieldvarsym(sym) then
          exit;
        if not is_record(fsym.vardef) and not is_object(fsym.vardef) and not is_cppclass(fsym.vardef) then
          exit;
        mop:=TManagementOperator(ptruint(arg));
        if not Assigned(mop_list[mop]) then
          InternalError(2018082303);

        if is_record(fsym.vardef) then
          begin
            if mop in TRecordSymTable(TRecordDef(fsym.vardef).SymTable).managementoperators then
              begin
                new(entry);
                entry^.pd:=search_management_operator(mop,fsym.vardef);
                if not Assigned(entry^.pd) then
                  InternalError(2018082302);
                entry^.offset:=fsym.fieldoffset;
                mop_list[mop].add(entry);
              end;
          end;

        sublist:=TFPList.create;
        TAbstractRecordSymTable(TAbstractRecordDef(fsym.vardef).SymTable).get_managementoperator_offset_list(mop,sublist);
        mop_list[mop].capacity:=mop_list[mop].count+sublist.count;
        for i:=0 to sublist.count-1 do
          begin
            entry:=PManagementOperatorOffsetEntry(sublist[i]);
            entry^.offset:=entry^.offset+fsym.fieldoffset;
            mop_list[mop].add(entry);
          end;
        { we don't need to remove the entries as they become part of list }
        sublist.free;
        sublist := nil;
      end;

    procedure TAbstractRecordSymTable.get_managementoperator_offset_list(mop:TManagementOperator;list:TFPList);
      var
        i : LongInt;
        entry,entrycopy : PManagementOperatorOffsetEntry;
      begin
        if not Assigned(list) then
          InternalError(2018082301);
        if mop=mop_none then
          exit;
        if not (mop in has_fields_with_mop) then
          { none of the fields or one of the field's fields has the requested operator }
          exit;
        if not Assigned(mop_list[mop]) then
          begin
            mop_list[mop]:=TFPList.create;
            SymList.ForEachCall(@do_get_managementoperator_offset_list,pointer(ptruint(mop)));
          end;
        for i:=0 to mop_list[mop].count-1 do
          begin
            entry:=PManagementOperatorOffsetEntry(mop_list[mop][i]);
            New(entrycopy);
            entrycopy^:=entry^;
            list.add(entrycopy);
          end;
      end;

    procedure TAbstractRecordSymTable.setdatasize(val: asizeint);
      begin
        _datasize:=val;
        if (usefieldalignment=bit_alignment) then
          { can overflow in non bitpacked records }
          databitsize:=val*8;
      end;

    function TAbstractRecordSymTable.getfieldoffset(sym: TFieldVarSym; base: asizeint; var globalfieldalignment: shortint): asizeint;
      var
        l      : asizeint;
        varalignfield,
        varalign : shortint;
        vardef : TDef;
      begin
        { Calculate field offset }
        l:=sym.getsize;
        vardef:=sym.vardef;
        varalign:=vardef.structalignment;
        case usefieldalignment of
          bit_alignment:
            { has to be handled separately }
            InternalError(2012071301);
          C_alignment:
            begin
              { Calc the alignment size for C style records }
              if (varalign>4) and
                ((varalign mod 4)<>0) and
                (vardef.typ=arraydef) then
                Message1(sym_w_wrong_C_pack,vardef.typename);
              if varalign=0 then
                varalign:=l;
              if (globalfieldalignment<CurrentSettings.alignment.MaxCRecordAlign) then
                begin
                  if (varalign>16) and (globalfieldalignment<32) then
                    globalfieldalignment:=32
                  else if (varalign>12) and (globalfieldalignment<16) then
                    globalfieldalignment:=16
                  { 12 is needed for long double }
                  else if (varalign>8) and (globalfieldalignment<12) then
                    globalfieldalignment:=12
                  else if (varalign>4) and (globalfieldalignment<8) then
                    globalfieldalignment:=8
                  else if (varalign>2) and (globalfieldalignment<4) then
                    globalfieldalignment:=4
                  else if (varalign>1) and (globalfieldalignment<2) then
                    globalfieldalignment:=2;
                end;
              globalfieldalignment:=min(globalfieldalignment,CurrentSettings.alignment.MaxCRecordAlign);
            end;
          mac68k_alignment:
            begin
              { mac68k alignment (C description):
                 * char is aligned to 1 byte
                 * everything else (except vector) is aligned to 2 bytes
                 * vector is aligned to 16 bytes
              }
              if l>1 then
                globalfieldalignment:=2
              else
                globalfieldalignment:=1;
              varalign:=2;
            end;
        end;
        if varalign=0 then
          varalign:=Size_2_Align(l);
        varalignfield:=Used_Align(varalign,RecordAlignMin,globalfieldalignment);

        result:=align(base,varalignfield);
      end;

    function TAbstractRecordSymTable.iscurrentunit: boolean;
      begin
        Result:=Assigned(CurrentModule)and(CurrentModule.ModuleID=ModuleID);
      end;

{****************************************************************************
                              TRecordSymtable
****************************************************************************}

    constructor TRecordSymTable.create(const n:string;usealign,recordminalign:shortint);
      begin
        inherited create(n,usealign,recordminalign);
        symtabletype:=recordsymtable;
      end;


   { this procedure is reserved for inserting case variant into
      a record symtable }
    { the offset is the location of the start of the variant
      and datasize and dataalignment corresponds to
      the complete size (see code in pdecl unit) PM }
    procedure TRecordSymTable.insertunionst(unionst : TRecordSymTable;offset : asizeint);
      var
        sym : TSym;
        def : TDef;
        i : integer;
        varalignrecord,varalign,
        storesize,storealign : asizeint;
        bitsize: TCGInt;
      begin
        storesize:=_datasize;
        storealign:=fieldalignment;
        _datasize:=offset;
        if (usefieldalignment=bit_alignment) then
          databitsize:=offset*8;

        { We move the ownership of the defs and symbols to the new recordsymtable.
          The old unionsymtable keeps the references, but doesn't own the
          objects anymore }
        unionst.DefList.OwnsObjects:=false;
        unionst.SymList.OwnsObjects:=false;

        { copy symbols }
        for i:=0 to unionst.SymList.Count-1 do
          begin
            sym:=TSym(unionst.SymList[i]);
            if not is_normal_fieldvarsym(sym) then
              InternalError(200601272);
            if TFieldVarSym(sym).fieldoffset=0 then
              include(TFieldVarSym(sym).varoptions,vo_is_first_field);

            { add to this record symtable, checking for duplicate names }
//            unionst.SymList.List.List^[i].Data:=nil;
            insertsym(sym);
            varalign:=TFieldVarSym(sym).vardef.alignment;
            if varalign=0 then
              varalign:=Size_2_Align(TFieldVarSym(sym).getsize);
            { retrieve size }
            if (usefieldalignment=bit_alignment) then
              begin
                { bit packed records are limited to high(aint) bits }
                { instead of bytes to avoid double precision        }
                { arithmetic in offset calculations                 }
                if is_ordinal(TFieldVarSym(sym).vardef) then
                  bitsize:=TFieldVarSym(sym).getpackedbitsize
                else
                  begin
                    bitsize:=TFieldVarSym(sym).getsize;
                    if (bitsize>high(asizeint) div 8) then
                      Message(sym_e_segment_too_large);
                    bitsize:=bitsize*8;
                  end;
                if bitsize>high(asizeint)-databitsize then
                  begin
                    Message(sym_e_segment_too_large);
                    _datasize:=high(asizeint);
                    databitsize:=high(asizeint);
                  end
                else
                  begin
                    databitsize:=TFieldVarSym(sym).fieldoffset+offset*8;
                    _datasize:=(databitsize+7) div 8;
                  end;
                TFieldVarSym(sym).fieldoffset:=databitsize;
              varalignrecord:=field2recordalignment(TFieldVarSym(sym).fieldoffset div 8,varalign);
              end
            else
              begin
                if TFieldVarSym(sym).getsize>high(asizeint)-_datasize then
                  begin
                    Message(sym_e_segment_too_large);
                    _datasize:=high(asizeint);
                  end
                else
                  _datasize:=TFieldVarSym(sym).fieldoffset+offset;
                { update address }
                TFieldVarSym(sym).fieldoffset:=_datasize;
                varalignrecord:=field2recordalignment(TFieldVarSym(sym).fieldoffset,varalign);
              end;
            { update alignment of this record }
            if (usefieldalignment<>C_alignment) and
               (usefieldalignment<>mac68k_alignment) then
              recordalignment:=max(recordalignment,varalignrecord);
          end;
        { update alignment for C records }
        if (usefieldalignment=C_alignment) and
           (usefieldalignment<>mac68k_alignment) then
          recordalignment:=max(recordalignment,unionst.recordalignment);
        { Register defs in the new record symtable }
        for i:=0 to unionst.DefList.Count-1 do
          begin
            def:=TDef(unionst.DefList[i]);
            def.ChangeOwner(self);
          end;
        _datasize:=storesize;
        fieldalignment:=storealign;
        { If a record contains a union, it does not contain a "single
          non-composite field" in the context of certain ABIs requiring
          special treatment for such records }
        if defowner.typ=recorddef then
          TRecordDef(defowner).isunion:=true;
      end;


    procedure TRecordSymTable.includemanagementoperator(mop:TManagementOperator);
      begin
        if mop in managementoperators then
          exit;
        include(managementoperators,mop);
      end;


{****************************************************************************
                              TObjectSymtable
****************************************************************************}

    constructor TObjectSymTable.create(adefowner:TDef;const n:string;usealign,recordminalign:shortint);
      begin
        inherited create(n,usealign,recordminalign);
        symtabletype:=ObjectSymtable;
        defowner:=adefowner;
      end;


    function TObjectSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      var
         hsym: TSym;
         warn: boolean;
      begin
         result:=false;
         if not Assigned(defowner) then
           InternalError(200602061);

         { procsym and propertysym have special code
           to override values in inherited classes. For other
           symbols check for duplicates (but for internal symbols only in this
           symtable, not the whole hierarchy) }
         if not(sym.typ in [procsym,propertysym]) and
            not (sp_internal in TSym(sym).symoptions) then
           begin
              { but private ids can be reused }
              hsym:=search_struct_member(TObjectDef(defowner),hashedid.id);
              if Assigned(hsym) and
                 (
                  (
                   not(m_delphi in CurrentSettings.ModeSwitches) and
                   is_visible_for_object(hsym,TObjectDef(defowner))
                  ) or
                  (
                   { In Delphi, you can repeat members of a parent class. You can't }
                   { do this for objects however, and you (obviously) can't         }
                   { declare two fields with the same name in a single class        }
                   (m_delphi in CurrentSettings.ModeSwitches) and
                   (
                    is_object(TDef(defowner)) or
                    (hsym.owner = self)
                   )
                  )
                 ) then
                begin
                  { only warn when a parameter/local variable in a method
                    conflicts with a category method, because this can easily
                    happen due to all possible categories being imported via
                    CocoaAll }
                  warn:=
                    (is_objccategory(TDef(hsym.owner.defowner)) or
                     is_classhelper(TDef(hsym.owner.defowner))) and
                    (sym.typ in [paravarsym,localvarsym,fieldvarsym]);
                  DuplicateSym(hashedid,sym,hsym,warn);
                  result:=true;
                end;
           end
         else
           result:=inherited checkduplicate(hashedid,sym);
      end;




{****************************************************************************
                          TAbstractSubSymtable
****************************************************************************}

   procedure TAbstractSubSymTable.ppuwrite(ppufile:TCompilerPPUFile);
      var
        oldtyp : byte;
      begin
         oldtyp:=ppufile.entrytyp;
         ppufile.entrytyp:=SubEntryID;

         inherited ppuwrite(ppufile);

         ppufile.entrytyp:=oldtyp;
      end;


{****************************************************************************
                          TAbstractLocalSymtable
****************************************************************************}

    function TAbstractLocalSymTable.count_locals:LongInt;
      var
        i   : LongInt;
        sym : TSym;
      begin
        result:=0;
        for i:=0 to SymList.Count-1 do
          begin
            sym:=TSym(SymList[i]);
            { Count only varsyms, but ignore the funcretsym }
            if (TSym(sym).typ in [localvarsym,paravarsym]) and
               (TSym(sym)<>CurrentProcInfo.procdef.funcretsym) and
               (not(vo_is_parentfp in TAbstractVarSym(sym).varoptions) or
                (TStoredSym(sym).refs>0)) then
              inc(result);
         end;
      end;

    function TAbstractLocalSymTable.iscurrentunit: boolean;
      begin
        Result:=
          Assigned(defowner) and
          defowner.owner.iscurrentunit;
      end;


{****************************************************************************
                              TLocalSymtable
****************************************************************************}

    constructor TLocalSymTable.create(adefowner:TDef;level:byte);
      begin
        inherited create('');
        defowner:=adefowner;
        symtabletype:=localsymtable;
        symtablelevel:=level;
      end;


    function TLocalSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      var
        hsym : TSym;
      begin
        if not Assigned(defowner) or
           (defowner.typ<>procdef) then
          InternalError(200602042);

        result:=false;
        hsym:=TSym(FindWithHash(hashedid));
        if Assigned(hsym) then
          begin
            { a local and the function can have the same
              name in TP and Delphi, but RESULT not }
            if (m_duplicate_names in CurrentSettings.ModeSwitches) and
               (hsym.typ in [absolutevarsym,localvarsym]) and
               (vo_is_funcret in TAbstractVarSym(hsym).varoptions) and
               not((m_result in CurrentSettings.ModeSwitches) and
                   (vo_is_result in TAbstractVarSym(hsym).varoptions)) then
              HideSym(hsym)
            else
              DuplicateSym(hashedid,sym,hsym,false);
            result:=true;
            exit;
          end;

        { check also parasymtable, this needs to be done here because
          of the special situation with the funcret sym that needs to be
          hidden for tp and delphi modes }
        hsym:=TSym(TAbstractProcDef(defowner).parast.FindWithHash(hashedid));
        if Assigned(hsym) then
          begin
            { a local and the function can have the same
              name in TP and Delphi, but RESULT not }
            if (m_duplicate_names in CurrentSettings.ModeSwitches) and
               (sym.typ in [absolutevarsym,localvarsym]) and
               (vo_is_funcret in TAbstractVarSym(sym).varoptions) and
               not((m_result in CurrentSettings.ModeSwitches) and
                   (vo_is_result in TAbstractVarSym(sym).varoptions)) then
              Hidesym(sym)
            else
              DuplicateSym(hashedid,sym,hsym,false);
            result:=true;
            exit;
          end;

        { check ObjectSymtable, skip this for funcret sym because
          that will always be positive because it has the same name
          as the procsym }
        if not is_funcret_sym(sym) and
           (defowner.typ=procdef) and
           Assigned(TProcDef(defowner).struct) and
           (TProcDef(defowner).owner.defowner=TProcDef(defowner).struct) and
           (
            not(m_duplicate_names in CurrentSettings.ModeSwitches) or
            is_object(TProcDef(defowner).struct)
           ) then
          result:=TProcDef(defowner).struct.SymTable.checkduplicate(hashedid,sym);
      end;


{****************************************************************************
                              TParaSymtable
****************************************************************************}

    constructor TParaSymTable.create(adefowner:TDef;level:byte);
      begin
        inherited create('');
        defowner:=adefowner;
        symtabletype:=parasymtable;
        symtablelevel:=level;
      end;


    function TParaSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      begin
        result:=inherited checkduplicate(hashedid,sym);
        if result then
          exit;
        if not(m_duplicate_names in CurrentSettings.ModeSwitches) and
           Assigned(defowner) and (defowner.typ=procdef) and
           Assigned(TProcDef(defowner).struct) and
           Assigned(TProcDef(defowner).owner) and
           (TProcDef(defowner).owner.defowner=TProcDef(defowner).struct) and
           (
            not(m_delphi in CurrentSettings.ModeSwitches) or
            is_object(TProcDef(defowner).struct)
           ) then
          result:=TProcDef(defowner).struct.SymTable.checkduplicate(hashedid,sym);
      end;


{****************************************************************************
                         TAbstractUniTSymtable
****************************************************************************}

    constructor TAbstractUnitSymTable.create(const n : string;id:word);
      begin
        inherited create(n);
        ModuleID:=id;
      end;


    function TAbstractUnitSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      var
        hsym : TSym;
      begin
        result:=false;
        hsym:=TSym(FindWithHash(hashedid));
        if Assigned(hsym) then
          begin
            if (sym is TStoredSym) and handle_generic_dummysym(hsym,TStoredSym(sym).symoptions) then
              exit;
            if hsym.typ=symconst.namespacesym then
              begin
                case sym.typ of
                  symconst.namespacesym:;
                  symconst.unitsym:
                    begin
                      HideSym(sym); { if we add a unit and there is a namespace with the same name then hide the unit name and not the namespace }
                      TNamespaceSym(hsym).unitsym:=TSym(sym);
                    end
                else
                  HideSym(hsym);
                end;
              end
            else
            { In delphi (contrary to TP) you can have a symbol with the same name as the
              unit, the unit can then not be accessed anymore using
              <unit>.<id>, so we can hide the symbol.
              Do the same if we add a namespace and there is a unit with the same name }
            if (hsym.typ=symconst.unitsym) and
               ((m_delphi in CurrentSettings.ModeSwitches) or (sym.typ=symconst.namespacesym)) then
              begin
                HideSym(hsym);
                if sym.typ=symconst.namespacesym then
                  TNamespaceSym(sym).unitsym:=TSym(hsym);
              end
            { iso mode program parameters: staticvarsyms might have the same name as a program parameters,
              in this case, copy the isoindex and make the original symbol invisible }
            else if (m_isolike_program_para in CurrentSettings.ModeSwitches) and (hsym.typ=programparasym) and (sym.typ=staticvarsym)
              and (TProgramParaSym(hsym).isoindex<>0) then
              begin
                HideSym(hsym);
                TStaticVarSym(sym).isoindex:=TProgramParaSym(hsym).isoindex;
              end
            else if (m_iso in CurrentSettings.ModeSwitches) and (hsym.typ=unitsym) then
              HideSym(hsym)
            else
              DuplicateSym(hashedid,sym,hsym,false);
            result:=true;
            exit;
          end;
      end;

    function TAbstractUnitSymTable.findnamespace(const n:string):TSymEntry;
      begin
        result:=find(n);
        if Assigned(result)and(result.typ<>namespacesym)then
          result:=nil;
      end;

    function TAbstractUnitSymTable.iscurrentunit:boolean;
      begin
        result:=Assigned(CurrentModule) and
                (
                 (CurrentModule.GlobalSymTable=self) or
                 (CurrentModule.localsymtable=self)
                );
      end;


    function TAbstractUnitSymTable.needs_init_final: boolean;
      begin
        if not init_final_check_done then
          begin
            result:=inherited needs_init_final;
            if not result then
              begin
                result:=has_class_condestructors;
                if result then
                  include(tableoptions,sto_needs_init_final);
              end;
          end;
        result:=sto_needs_init_final in tableoptions;
      end;


    procedure TAbstractUnitSymTable.insertunit(sym:TSymEntry);
      var
        p:integer;
        n,ns:string;
        oldsym:TSymEntry;
      begin
        insertsym(sym);
        n:=sym.realname;
        p:=pos('.',n);
        ns:='';
        while p>0 do
          begin
            if ns='' then
              ns:=copy(n,1,p-1)
            else
              ns:=ns+'.'+copy(n,1,p-1);
            system.delete(n,1,p);
            oldsym:=findnamespace(upper(ns));
            if not Assigned(oldsym) then
              insertsym(CNamespaceSym.create(ns));
            p:=pos('.',n);
          end;
      end;


    procedure CheckForClassConDestructors(p:TObject;arg:pointer);
      var
        result: PBoolean absolute arg;
      begin
        if result^ then
          exit;
        if (TDef(p).typ in [objectdef,recorddef]) and
           not (df_generic in TDef(p).defoptions) then
          begin
            { first check the class... }
            if ([oo_has_class_constructor,oo_has_class_destructor] * TAbstractRecordDef(p).objectoptions <> []) then
              result^:=true;
            { ... and then also check all subclasses }
            if not result^ then
              TAbstractRecordDef(p).SymTable.deflist.foreachcall(@CheckForClassConDestructors,arg);
          end;
      end;


    function TAbstractUnitSymTable.has_class_condestructors: boolean;
      begin
        result:=false;
        deflist.foreachcall(@CheckForClassConDestructors,@result);
      end;

{****************************************************************************
                              TStaticSymtable
****************************************************************************}

    constructor TStaticSymTable.create(const n : string;id:word);
      begin
        inherited create(n,id);
        symtabletype:=staticsymtable;
        symtablelevel:=main_program_level;
        currentvisibility:=vis_private;
      end;


    procedure TStaticSymTable.ppuload(ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(ppufile);

        { now we can deref the syms and defs }
        deref(false);
      end;


    procedure TStaticSymTable.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
      end;


    function TStaticSymTable.checkduplicate(var hashedid:THashedIDString;sym:TSymEntry):boolean;
      begin
        result:=inherited checkduplicate(hashedid,sym);

        if not result and
           (CurrentModule.localsymtable=self) and
           Assigned(CurrentModule.GlobalSymTable) then
          result:=TGlobalSymTable(CurrentModule.GlobalSymTable).checkduplicate(hashedid,sym);
      end;

    function TStaticSymTable.findnamespace(const n:string):TSymEntry;
      begin
        result:=inherited findnamespace(n);
        if not Assigned(result) and
           (CurrentModule.localsymtable=self) and
           Assigned(CurrentModule.GlobalSymTable) then
          result:=TGlobalSymTable(CurrentModule.GlobalSymTable).findnamespace(n);
     end;


{****************************************************************************
                              TGlobalSymtable
****************************************************************************}

    constructor TGlobalSymTable.create(const n : string;id:word);
      begin
         inherited create(n,id);
         symtabletype:=GlobalSymTable;
         symtablelevel:=main_program_level;
      end;


    procedure TGlobalSymTable.ppuload(ppufile:TCompilerPPUFile);
      begin
         inherited ppuload(ppufile);

         { now we can deref the syms and defs }
         deref(false);
      end;


    procedure TGlobalSymTable.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        { write the symtable entries }
        inherited ppuwrite(ppufile);
      end;


{*****************************************************************************
                             tspecializesymtable
*****************************************************************************}

    constructor TSpecializeSymTable.create(const n : string;id:word);
      begin
        inherited create(n,id);
        { the specialize symtable does not own the syms and defs as they are all
          moved to a different symtable before the symtable is destroyed; this
          avoids calls to "extract" }
        symlist.ownsobjects:=false;
        deflist.ownsobjects:=false;
      end;

    function TSpecializeSymTable.iscurrentunit: boolean;
      begin
        Result:=true;
      end;


{****************************************************************************
                              TWITHSYMTABLE
****************************************************************************}

    constructor TWithSymTable.create(aowner:TDef;ASymList:TFPHashObjectList;refnode:tobject{tnode});
      begin
         inherited create('');
         symtabletype:=withsymtable;
         withrefnode:=refnode;
         { Replace SymList with the passed symlist }
         SymList.free;
         SymList:=ASymList;
         defowner:=aowner;
      end;


    destructor TWithSymTable.Destroy;
      begin
        if refcount>1 then
          exit;
        withrefnode.free;
        withrefnode := nil;
        { Disable SymList because we don't Own it }
        SymList:=nil;
        inherited Destroy;
      end;


    procedure TWithSymTable.clear;
      begin
         { remove no entry from a withsymtable as it is only a pointer to the
           recorddef  or objectdef symtable }
      end;


    procedure TWithSymTable.insertdef(def:TDefEntry);
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

    constructor TSTTExceptSymTable.create;
      begin
        inherited create('');
        symtabletype:=exceptsymtable;
      end;


{****************************************************************************
                          TMacroSymtable
****************************************************************************}

    constructor TMacroSymTable.create(exported: boolean);
      begin
        inherited create('');
        if exported then
          symtabletype:=exportedmacrosymtable
        else
          symtabletype:=localmacrosymtable;
        symtablelevel:=main_program_level;
      end;

{****************************************************************************
                          TEnumSymtable
****************************************************************************}

    procedure TEnumSymTable.insertsym(sym: TSymEntry; checkdup: boolean);
      var
        value: LongInt;
        def: TEnumDef;
      begin
        // defowner = nil only when we are loading from ppu
        if defowner<>nil then
          begin
            { First entry? Then we need to set the minval }
            value:=TEnumSym(sym).value;
            def:=TEnumDef(defowner);
            if SymList.count=0 then
              begin
                if value>0 then
                  def.has_jumps:=true;
                def.setmin(value);
                def.setmax(value);
              end
            else
              begin
                { check for jumps }
                if value>def.max+1 then
                  def.has_jumps:=true;
                { update low and high }
                if def.min>value then
                  def.setmin(value);
                if def.max<value then
                  def.setmax(value);
              end;
          end;
        inherited insertsym(sym, checkdup);
      end;

    constructor TEnumSymTable.create(adefowner: TDef);
      begin
        inherited Create('');
        symtabletype:=enumsymtable;
        defowner:=adefowner;
      end;

{****************************************************************************
                          TArraySymtable
****************************************************************************}

    procedure TArraySymTable.insertdef(def: TDefEntry);
      begin
        { Enums must also be available outside the record scope,
          insert in the owner of this symtable }
        if def.typ=enumdef then
          defowner.owner.insertdef(def)
        else
          inherited insertdef(def);
      end;

    constructor TArraySymTable.create(adefowner: TDef);
      begin
        inherited Create('');
        symtabletype:=arraysymtable;
        defowner:=adefowner;
      end;

{*****************************************************************************
                             Helper Routines
*****************************************************************************}

    function FullTypeName(def,otherdef:TDef):string;
      var
        s1,s2 : string;
      begin
        if def.typ in [objectdef,recorddef] then
          s1:=TAbstractRecordDef(def).RttiName
        else
          s1:=def.typename;
        { When the names are the same try to include the unit name }
        if Assigned(otherdef) and
           (def.owner.symtabletype in [GlobalSymTable,staticsymtable]) then
          begin
            s2:=otherdef.typename;
            if upper(s1)=upper(s2) then
              s1:=def.owner.realname^+'.'+s1;
          end;
        FullTypeName:=s1;
      end;

    function generate_nested_name(SymTable:TSymTable;const delimiter:string):string;
      begin
        result:='';
        while Assigned(SymTable) and (SymTable.symtabletype in [ObjectSymtable,recordsymtable]) do
          begin
            if (result='') then
              if SymTable.name<>nil then
                result:=SymTable.name^
              else
            else
              if SymTable.name<>nil then
                result:=SymTable.name^+delimiter+result
              else
                result:=delimiter+result;
            SymTable:=SymTable.defowner.owner;
          end;
      end;


    function generate_objectpascal_helper_key(def:TDef):TSymStr;
      begin
        if not Assigned(def) then
          InternalError(2013020501);
        if def.typ in [recorddef,objectdef] then
          result:=make_mangledname('',TAbstractRecordDef(def).SymTable,'')
        else
          result:=make_mangledname('',def.owner,def.typesym.name);
      end;


    procedure incompatibletypes(def1,def2:TDef);
      begin
        { When there is an errordef there is already an error message show }
        if (def2.typ=errordef) or
           (def1.typ=errordef) then
          exit;
        CGMessage2(type_e_incompatible_types,FullTypeName(def1,def2),FullTypeName(def2,def1));
      end;


    procedure hidesym(sym:TSymEntry);
      begin
        sym.realname:='$hidden'+sym.realname;
        TSym(sym).visibility:=vis_hidden;
      end;


    procedure duplicatesym(var hashedid: THashedIDString; dupsym, origsym: TSymEntry; warn: boolean);
      var
        st : TSymTable;
        FileName : TIDString;
      begin
        if not warn then
          Message1(sym_e_duplicate_id,TSym(origsym).realname)
        else
         Message1(sym_w_duplicate_id,TSym(origsym).realname);
        { Write hint where the original symbol was found }
        st:=finduniTSymtable(origsym.owner);
        with TSym(origsym).fileinfo do
          begin
            if Assigned(st) and
               (st.symtabletype=GlobalSymTable) and
               st.iscurrentunit then
              Message2(sym_h_duplicate_id_where,CurrentModule.SourceFiles.Get_File_Name(fileindex),ToStr(line))
            else if Assigned(st.name) then
              begin
                FileName:=find_module_from_symtable(st).SourceFiles.Get_File_Name(fileindex);
                if FileName<>'' then
                  Message2(sym_h_duplicate_id_where,'unit '+st.name^+': '+FileName,ToStr(line))
                else
                  Message2(sym_h_duplicate_id_where,'unit '+st.name^,ToStr(line))
              end;
          end;
        { Rename duplicate sym to an unreachable name, but it can be
          inserted in the symtable without errors }
        inc(dupnr);
        hashedid.id:='dup'+ToStr(dupnr)+hashedid.id;
        if Assigned(dupsym) then
          include(TSym(dupsym).symoptions,sp_implicitrename);
      end;

    function handle_generic_dummysym(sym:TSymEntry;var symoptions:TSymOptions):boolean;
      begin
        result:=false;
        if not Assigned(sym) or not (sym is TStoredSym) then
          InternalError(2011081101);
        { For generics a dummy symbol without the parameter count is created
          if such a symbol not yet exists so that different parts of the
          parser can find that symbol. If that symbol is still a
          undefineddef we replace the generic dummy symbol's
          name with a "dup" name and use the new symbol as the generic dummy
          symbol }
        if (sp_generic_dummy in TStoredSym(sym).symoptions) and
            (sym.typ=typesym) and (TTypeSym(sym).typedef.typ=undefineddef) and
            (m_delphi in CurrentSettings.ModeSwitches) then
          begin
            inc(dupnr);
            sym.Owner.SymList.Rename(upper(sym.realname),'dup_'+ToStr(dupnr)+sym.realname);
            include(TSym(sym).symoptions,sp_implicitrename);
            { we need to find the new symbol now if checking for a dummy }
            include(symoptions,sp_generic_dummy);
            result:=true;
          end;
      end;

    procedure check_systemunit_loaded; inline;
    begin
      if systemunit=nil then
       Message(sym_f_systemunitnotloaded);
    end;

    procedure write_system_parameter_lists(const name:string);
      var
        srsym:TProcSym;
      begin
        check_systemunit_loaded;
        srsym:=TProcSym(systemunit.find(name));
        if not Assigned(srsym) or not (srsym.typ=procsym) then
          InternalError(2016060302);
        srsym.write_parameter_lists(nil);
      end;


{*****************************************************************************
                                  Search
*****************************************************************************}

     procedure addsymref(sym:TSym;def:TDef);
       var
         owner,procowner : TSymTable;
       begin
         { for symbols used in preprocessor expressions, we don't want to
           increase references count (for smaller final binaries) }
         if not Assigned(CurrentScanner) then
           InternalError(2017050601);
         if CurrentScanner.in_preproc_comp_expr then
           exit;
         { symbol uses count }
         sym.IncRefCount;
         owner:=sym.owner;
         while owner.symtabletype in [objectsymtable,recordsymtable,enumsymtable] do
           owner:=TDef(owner.defowner).owner;
         if Assigned(CurrentModule) and
            (owner.symtabletype=GlobalSymTable) then
             begin
               if TGlobalSymTable(owner).ModuleID>=CurrentModule.unitmapsize then
                 InternalError(200501152);
               { unit uses count }
               inc(CurrentModule.unitmap[TGlobalSymTable(owner).ModuleID].refs);
               { Note: don't check the symtable directly as owner might be
                       a specialize symtable which is a globalsymtable as well }
               if (
                     Assigned(CurrentModule.GlobalSymTable) and
                     (CurrentModule.GlobalSymTable.ModuleID<>owner.ModuleID)
                  ) or (
                     Assigned(CurrentModule.localsymtable) and
                     (CurrentModule.localsymtable.ModuleID<>owner.ModuleID)
                  ) then
                 { symbol is imported from another unit }
                 CurrentModule.addimportedsym(sym);
             end;
         { static symbols that are used in public functions must be exported
           for packages as well }
         { A private overload can share its procsym with public overloads.
           Use the selected definition's implementation owner in that case. }
         if (sym.typ=procsym) and Assigned(def) and
            (def.typ=procdef) and (def.owner.symtabletype=staticsymtable) then
           owner:=def.owner;
         if ([tf_supports_packages,tf_supports_hidden_symbols]<=TargetInfo.flags) and
             (owner.symtabletype=staticsymtable) and
             Assigned(CurrentProcInfo) and
             (
               (
                 (sym.typ=staticvarsym) and
                 ([vo_is_public,vo_has_global_ref]*TStaticVarSym(sym).varoptions=[])
               ) or (
                 (sym.typ=localvarsym) and
                 Assigned(TLocalVarSym(sym).defaultconstsym) and
                 ([vo_is_public,vo_has_global_ref]*TStaticVarSym(TLocalVarSym(sym).defaultconstsym).varoptions=[])
               ) or (
                 (sym.typ=procsym) and
                 Assigned(def) and
                 (def.typ=procdef) and
                 not (df_has_global_ref in def.defoptions) and
                 not (po_public in TProcDef(def).procoptions)
               )
             ) then
           begin
             procowner:=CurrentProcInfo.procdef.owner;
             while procowner.symtabletype in [objectsymtable,recordsymtable] do
               procowner:=TDef(procowner.defowner).owner;
             if procowner.symtabletype=GlobalSymTable then
               begin
                 if sym.typ=procsym then
                   CurrentProcInfo.add_local_ref_def(def)
                 else if sym.typ=staticvarsym then
                   CurrentProcInfo.add_local_ref_sym(sym)
                 else
                   CurrentProcInfo.add_local_ref_sym(TLocalVarSym(sym).defaultconstsym);
               end;
           end;
       end;

     procedure addsymref(sym:TSym);
       begin
         addsymref(sym,nil);
       end;

    function is_owned_by(nesteddef,ownerdef:TDef):boolean;
      begin
        result:=nesteddef=ownerdef;
        if not result and
           { types declared locally in a record method are not defined in the
             record itself }
           not(nesteddef.owner.symtabletype in [localsymtable,parasymtable]) and
           Assigned(nesteddef.owner.defowner) then
          result:=is_owned_by(TDef(nesteddef.owner.defowner),ownerdef);
      end;

    function sym_is_owned_by(childsym:TSym;SymTable:TSymTable):boolean;
      begin
        result:=Assigned(childsym) and (childsym.owner=SymTable);
        if not result and Assigned(childsym) and
            (childsym.owner.symtabletype in [objectsymtable,recordsymtable]) then
          result:=sym_is_owned_by(TAbstractRecordDef(childsym.owner.defowner).typesym,SymTable);
      end;

    function defs_belong_to_same_generic(def1, def2: TDef): boolean;
    begin
      result:=false;
      if not Assigned(def1) or not Assigned(def2) then
        exit;
      { for both defs walk to the topmost generic }
      while Assigned(def1.owner.defowner) and (df_generic in TStoredDef(def1.owner.defowner).defoptions) do
        def1:=TDef(def1.owner.defowner);
      while Assigned(def2.owner.defowner) and (df_generic in TStoredDef(def2.owner.defowner).defoptions) do
        def2:=TDef(def2.owner.defowner);
      result:=def1=def2;
    end;

    function get_generic_in_hierarchy_by_name(srsym: TSym; def: TDef): TDef;
      var
        uname : string;
      begin
        { TODO : check regarding arrays and records declared as their type }
        if not (def.typ in [recorddef,objectdef]) then
          InternalError(2012051501);
        uname:=upper(srsym.realname);
        repeat
          if uname=copy(TAbstractRecordDef(def).objname^,1,pos('$',TAbstractRecordDef(def).objname^)-1) then
            begin
              result:=def;
              exit;
            end;
          def:=TDef(def.owner.defowner);
        until not Assigned(def) or not (def.typ in [recorddef,objectdef]);
        result:=nil;
      end;

    function return_specialization_of_generic(nesteddef,genericdef:TDef; out resultdef:TDef):boolean;
      begin
        { TODO : check regarding arrays and records declared as their type }
        if not (nesteddef.typ in [recorddef,objectdef]) then
          InternalError(2012051601);
        repeat
          if TStoredDef(nesteddef).genericdef=genericdef then
            begin
              resultdef:=nesteddef;
              result:=true;
              exit;
            end;
          nesteddef:=TDef(nesteddef.owner.defowner);
        until not Assigned(nesteddef) or not (nesteddef.typ in [recorddef,objectdef]);
        resultdef:=nil;
        result:=false;
      end;

    { symst: symboltable that contains the symbol (-> symowner def: record/objectdef in which the symbol is defined)
      symvisibility: visibility of the symbol
      contextobjdef: via which def the symbol is accessed, e.g.:
        fieldname:=1 -> contextobjdef = current_structdef
        objfield.fieldname:=1 -> contextobjdef = def of objfield
    }
    function is_visible_for_object(symst:TSymTable;symvisibility:TVisibility;contextobjdef:TAbstractRecordDef):boolean;
      var
        curstruct : TAbstractRecordDef;

      function is_current_unit(st:TSymTable):boolean;
        begin
          result :=
            (
              (
                Assigned(curstruct) and
                (st.ModuleID=curstruct.SymTable.ModuleID)
              ) or
              (
                not Assigned(curstruct) and
                st.iscurrentunit
              )
            );
        end;

      var
        orgcontextobjdef,
        orgsymownerdef,
        symownerdef : TAbstractRecordDef;
        nonlocalst : TSymTable;
        isspezproc : boolean;

      function check_strict_private:boolean;
        begin
          result:=Assigned(curstruct) and
                  is_owned_by(curstruct,symownerdef);
        end;

      function check_strict_protected:boolean;
        function is_childof(child, potentialparent: TDef):boolean;
          begin
            result:=true;
            if def_is_related(child, potentialparent) then
              exit;
            if (child.typ=objectdef) and
               (potentialparent.typ=objectdef) and
               (TObjectDef(potentialparent).defoptions*[df_generic,df_specialization]=[df_generic]) then
              begin
                 repeat
                   if TObjectDef(child).genericdef<>nil then
                     begin
                       if TObjectDef(child).genericdef.typ<>objectdef then
                         break;
                       child:=TObjectDef(child).genericdef as TObjectDef
                     end
                   else
                     child:=TObjectDef(child).childof;
                   if (child<>nil) and equal_defs(child, potentialparent) then
                     exit;
                 until child=nil;
              end;

            result:=false;
          end;

        function owner_hierarchy_related(nested,check:TAbstractRecordDef):boolean;
          var
            owner:TAbstractRecordDef;
          begin
            result:=true;
            repeat
              if is_childof(nested,check) then
                exit;
              if nested.owner.symtabletype in [recordsymtable,objectsymtable] then
                nested:=TAbstractRecordDef(nested.owner.defowner)
              else
                break;
            until not Assigned(nested);
            result:=false;
          end;

        begin
          result:=(
                    { access from nested class (specialization case) }
                    Assigned(curstruct) and
                    is_owned_by(curstruct,symownerdef)
                  ) or
                  (
                    { access from nested class (non-specialization case) }
                    (orgsymownerdef<>symownerdef) and
                    Assigned(curstruct) and
                    is_owned_by(curstruct,orgsymownerdef)
                  ) or
                  (
                    { access from child class (specialization case) }
                    Assigned(contextobjdef) and
                    Assigned(curstruct) and
                    owner_hierarchy_related(contextobjdef,symownerdef) and
                    is_childof(curstruct,contextobjdef)
                  ) or
                  (
                    { access from child class (non-specialization case) }
                    Assigned(orgcontextobjdef) and
                    (
                      (orgcontextobjdef<>contextobjdef) or
                      (orgsymownerdef<>symownerdef)
                    ) and
                    Assigned(curstruct) and
                    owner_hierarchy_related(orgcontextobjdef,orgsymownerdef) and
                    is_childof(curstruct,orgcontextobjdef)
                  ) or
                  (
                    { helpers can access strict protected symbols }
                    is_objectpascal_helper(contextobjdef) and
                    is_childof(TObjectDef(contextobjdef).extendeddef,symownerdef)
                  ) or
                  (
                    { same as above, but from context of call node inside
                      helper method }
                    is_objectpascal_helper(curstruct) and
                    is_childof(TObjectDef(curstruct).extendeddef,symownerdef)
                  );
        end;

      begin
        result:=false;

        { Get objdectdef owner of the symtable for the is_related checks }
        if not Assigned(symst) or
           not (symst.symtabletype in [objectsymtable,recordsymtable]) then
          InternalError(200810285);
        symownerdef:=TAbstractRecordDef(symst.defowner);
        orgsymownerdef:=symownerdef;
        orgcontextobjdef:=contextobjdef;
        { for specializations we need to check the visibility of the generic,
          not the specialization (at least when comparing outside of the
          specialization }
        if df_specialization in symownerdef.defoptions then
          begin
            if not Assigned(symownerdef.genericdef) then
              InternalError(2024041201);
            if not (symownerdef.genericdef.typ in [objectdef,recorddef]) then
              InternalError(2024020901);
            orgsymownerdef:=symownerdef;
            symownerdef:=TAbstractRecordDef(symownerdef.genericdef);
          end;
        if Assigned(contextobjdef) and (df_specialization in contextobjdef.defoptions) then
          begin
            if not Assigned(contextobjdef.genericdef) then
              InternalError(2024041202);
            if not (contextobjdef.genericdef.typ in [objectdef,recorddef]) then
              InternalError(2024020902);
            orgcontextobjdef:=contextobjdef;
            contextobjdef:=TAbstractRecordDef(contextobjdef.genericdef);
          end;
        if Assigned(CurrentStructDef) and (df_specialization in CurrentStructDef.defoptions) then
          begin
            if not Assigned(CurrentStructDef.genericdef) then
              InternalError(2024041203);
            if not (CurrentStructDef.genericdef.typ in [objectdef,recorddef]) then
              InternalError(2024030903);
            curstruct:=TAbstractRecordDef(CurrentStructDef.genericdef)
          end
        else
          curstruct:=CurrentStructDef;
        { specializations might belong to a localsymtable or parasymtable }
        nonlocalst:=symownerdef.owner;
        if TStoredDef(symownerdef).is_specialization then
          while nonlocalst.symtabletype in [localsymtable,parasymtable] do
            nonlocalst:=nonlocalst.defowner.owner;
        isspezproc:=false;
        if Assigned(CurrentProcInfo) then
          begin
            if CurrentProcInfo.procdef.is_specialization and
                Assigned(CurrentProcInfo.procdef.struct) then
              isspezproc:=true;
          end;
        case symvisibility of
          vis_private :
            begin
              { private symbols are allowed when we are in the same
                module as they are defined }
              result:=check_strict_private or
                      (
                       (nonlocalst.symtabletype in [GlobalSymTable,staticsymtable]) and
                       is_current_unit(nonlocalst)
                      ) or
                      ( // the case of specialize inside the generic declaration and nested types
                       (nonlocalst.symtabletype in [objectsymtable,recordsymtable]) and
                       (
                         Assigned(curstruct) and
                         (
                           (curstruct=symownerdef) or
                           (curstruct.owner.ModuleID=symownerdef.SymTable.ModuleID)
                         )
                       ) or
                       (
                         not Assigned(curstruct) and
                         (symownerdef.owner.iscurrentunit)
                       ) or
                       { access from a generic method that belongs to the class
                         but that is specialized elsewhere }
                       (
                         isspezproc and
                         (CurrentProcInfo.procdef.struct=curstruct)
                       ) or
                       { specializations may access private symbols that their
                         generics are allowed to access }
                       (
                         Assigned(curstruct) and
                         (df_specialization in curstruct.defoptions) and
                         (symst.ModuleID=curstruct.genericdef.owner.ModuleID)
                       )
                      );
            end;
          vis_strictprivate :
            begin
              result:=check_strict_private;
            end;
          vis_strictprotected :
            begin
              result:=check_strict_protected;
            end;
          vis_protected :
            begin
              { protected symbols are visible in the module that defines them and
                also visible to related objects. The related object must be defined
                in the current module }
              result:=check_strict_protected or
                      (
                       (
                        (nonlocalst.symtabletype in [GlobalSymTable,staticsymtable]) and
                        is_current_unit(nonlocalst)
                       ) or
                       (
                        { context object is inside the current unit and related to
                          the symbol owner (specialization case) }
                        Assigned(contextobjdef) and
                        (contextobjdef.owner.symtabletype in [GlobalSymTable,staticsymtable,ObjectSymtable,recordsymtable,localsymtable]) and
                        is_current_unit(contextobjdef.owner) and
                        def_is_related(contextobjdef,symownerdef)
                       ) or
                       (
                        { context object is inside the current unit and related to
                          the symbol owner (non-specialization case) }
                        Assigned(orgcontextobjdef) and
                        (
                          (orgcontextobjdef<>contextobjdef) or
                          (orgsymownerdef<>symownerdef)
                        ) and
                        (orgcontextobjdef.owner.symtabletype in [GlobalSymTable,staticsymtable,ObjectSymtable,recordsymtable,localsymtable]) and
                        is_current_unit(orgcontextobjdef.owner) and
                        def_is_related(orgcontextobjdef,orgsymownerdef)
                       ) or
                       ( // the case of specialize inside the generic declaration and nested types
                        (nonlocalst.symtabletype in [objectsymtable,recordsymtable]) and
                        (
                          Assigned(curstruct) and
                          (
                            (curstruct=symownerdef) or
                            (curstruct.owner.ModuleID=symownerdef.SymTable.ModuleID)
                          )
                        ) or
                        (
                          not Assigned(curstruct) and
                          (symownerdef.owner.iscurrentunit)
                        )
                       ) or
                       { access from a generic method that belongs to the class
                         but that is specialized elsewhere }
                       (
                         isspezproc and
                         (CurrentProcInfo.procdef.struct=curstruct)
                       ) or
                       { specializations may access private symbols that their
                         generics are allowed to access }
                       (
                         Assigned(curstruct) and
                         (df_specialization in curstruct.defoptions) and
                         (symst.ModuleID=curstruct.genericdef.owner.ModuleID)
                       )
                      );
            end;
          vis_public,
          vis_published :
            result:=true;
          else
            InternalError(2019050702);
        end;

        if not result then
          begin
            { capturers have access to anything as we assume checks were done
              before the procdef was inserted into the capturer }
            result:=Assigned(curstruct) and
                    (curstruct.typ=objectdef) and
                    (oo_is_capturer in TObjectDef(curstruct).objectoptions);
          end;
      end;


    function is_visible_for_object(pd:TProcDef;contextobjdef:TAbstractRecordDef):boolean;
      begin
        result:=is_visible_for_object(pd.owner,pd.visibility,contextobjdef);
      end;


    function is_visible_for_object(sym:TSym;contextobjdef:TAbstractRecordDef):boolean;
      var
        i  : LongInt;
        pd : TProcDef;
      begin
        if sym.typ=procsym then
          begin
            result:=false;
            { A procsym is visible, when there is at least one of the procdefs visible }
            for i:=0 to TProcSym(sym).ProcdefList.Count-1 do
              begin
                pd:=TProcDef(TProcSym(sym).ProcdefList[i]);
                if (pd.owner=sym.owner) and
                   is_visible_for_object(pd,contextobjdef) then
                  begin
                    result:=true;
                    exit;
                  end;
              end;
            { check dummy sym visibility by following associated procsyms }
            if TProcSym(sym).could_be_implicitly_specialized then
              begin
                for i:=0 to TProcSym(sym).genprocsymovlds.count-1 do
                  if is_visible_for_object(TSym(TProcSym(sym).genprocsymovlds[i]),contextobjdef) then
                    begin
                      result:=true;
                      exit;
                    end;
              end;
            if (TProcSym(sym).procdeflist.count=0) and (sp_generic_dummy in TProcSym(sym).symoptions) then
              result:=is_visible_for_object(sym.owner,sym.visibility,contextobjdef);
          end
        else
          result:=is_visible_for_object(sym.owner,sym.visibility,contextobjdef);
      end;


    function  searchsym(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
      begin
        case s[1] of
          internal_macro_escape_unit_namespace_name:
            result:=searchsym_maybe_with_symoption(copy(s,2,length(s)-1),srsym,srsymtable,[ssf_unit_or_namespace_only],sp_none)
          else
            result:=searchsym_maybe_with_symoption(s,srsym,srsymtable,[],sp_none);
        end
      end;


    function  searchsym_with_flags(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
      begin
        result:=searchsym_maybe_with_symoption(s,srsym,srsymtable,flags,sp_none);
      end;


    function  searchsym_maybe_with_symoption(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags;option:TSymOption):boolean;
      var
        hashedid: THashedIDString;
        contextstructdef: TAbstractRecordDef;
        stackitem: PSymTableStackItem;
      begin
        result:=false;
        hashedid.id:=s;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            srsymtable:=stackitem^.SymTable;
            if not(ssf_unit_or_namespace_only in flags) and
               (srsymtable.symtabletype=objectsymtable) then
              begin
                { TODO : implement the search for an option in classes as well }
                if ssf_search_option in flags then
                  begin
                    result:=false;
                    exit;
                  end;
                if searchsym_in_class(TObjectDef(srsymtable.defowner),TObjectDef(srsymtable.defowner),s,srsym,srsymtable,flags+[ssf_search_helper]) then
                  begin
                    result:=true;
                    exit;
                  end;
              end
            else if not((srsymtable.symtabletype=withsymtable) and Assigned(srsymtable.defowner) and
              (srsymtable.defowner.typ=undefineddef)) then
              begin
                srsym:=TSym(srsymtable.FindWithHash(hashedid));
                { First check if it is a unit/namespace symbol.
                  They are visible only if they are from the current unit or
                  unit of generic of currently processed specialization. }
                if Assigned(srsym) and
                   (not(ssf_unit_or_namespace_only in flags) or
                    (srsym.typ in [unitsym,namespacesym])) and
                   (
                     not(srsym.typ in [unitsym,namespacesym]) or
                     srsymtable.iscurrentunit or
                     (Assigned(CurrentSpecializeDef)and(CurrentSpecializeDef.genericdef.owner.ModuleID=srsymtable.ModuleID)) or
                     (
                       Assigned(CurrentProcInfo) and
                       (df_specialization in CurrentProcInfo.procdef.defoptions) and
                       (CurrentProcInfo.procdef.genericdef.owner.ModuleID=srsymtable.ModuleID)
                     )
                   ) and
                   (not (ssf_search_option in flags) or (option in srsym.symoptions))then
                  begin
                    { use the class from withsymtable only when it is
                      defined in this unit }
                    if (srsymtable.symtabletype=withsymtable) and
                       Assigned(srsymtable.defowner) and
                       (srsymtable.defowner.typ in [recorddef,objectdef]) and
                       (srsymtable.defowner.owner.symtabletype in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]) and
                       (srsymtable.defowner.owner.iscurrentunit) then
                      contextstructdef:=TAbstractRecordDef(srsymtable.defowner)
                    else
                      contextstructdef:=CurrentStructDef;
                    if not(srsym.owner.symtabletype in [objectsymtable,recordsymtable]) or
                       is_visible_for_object(srsym,contextstructdef) then
                      begin
                        { we need to know if a procedure references symbols
                          in the static symtable, because then it can't be
                          inlined from outside this unit }
                        if Assigned(CurrentProcInfo) and
                           (srsym.owner.symtabletype=staticsymtable) then
                          include(CurrentProcInfo.flags,pi_uses_static_symtable);
                        if not (ssf_no_addsymref in flags) then
                          addsymref(srsym);
                        result:=true;
                        exit;
                      end;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        srsym:=nil;
        srsymtable:=nil;
      end;

    function searchsym_with_symoption(const s: TIDString;out srsym:TSym;out
      srsymtable:TSymTable;option:TSymOption):boolean;
      begin
        result:=searchsym_maybe_with_symoption(s,srsym,srsymtable,[ssf_search_option],option);
      end;

    function searchsym_type(const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
      var
        hashedid  : THashedIDString;
        stackitem : PSymTableStackItem;
        classh : TObjectDef;
      begin
        result:=false;
        hashedid.id:=s;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            {
              It is not possible to have type symbols in:
                parameters
              Exception are classes, objects, records, generic definitions and specializations
              that have the parameterized types inserted in the symtable.
            }
            srsymtable:=stackitem^.SymTable;
            if (srsymtable.symtabletype=ObjectSymtable) then
              begin
                classh:=TObjectDef(srsymtable.defowner);
                while Assigned(classh) do
                  begin
                    srsymtable:=classh.SymTable;
                    srsym:=TSym(srsymtable.FindWithHash(hashedid));
                     if Assigned(srsym) and
                        not(srsym.typ in [fieldvarsym,paravarsym,propertysym,procsym,labelsym]) and
                        is_visible_for_object(srsym,CurrentStructDef) then
                       begin
                        addsymref(srsym);
                        result:=true;
                        exit;
                      end;
                    classh:=classh.childof;
                  end;
              end
            else
              begin
                srsym:=TSym(srsymtable.FindWithHash(hashedid));
                if Assigned(srsym) and
                   (
                     not(srsym.typ in [unitsym,namespacesym]) or
                     srsymtable.iscurrentunit or
                     (Assigned(CurrentSpecializeDef)and(CurrentSpecializeDef.genericdef.owner.ModuleID=srsymtable.ModuleID))
                   ) and
                   not(srsym.typ in [fieldvarsym,paravarsym,propertysym,procsym,labelsym]) and
                   (not (srsym.owner.symtabletype in [objectsymtable,recordsymtable]) or is_visible_for_object(srsym,CurrentStructDef)) then
                  begin
                    { we need to know if a procedure references symbols
                      in the static symtable, because then it can't be
                      inlined from outside this unit }
                    if Assigned(CurrentProcInfo) and
                       (srsym.owner.symtabletype=staticsymtable) then
                      include(CurrentProcInfo.flags,pi_uses_static_symtable);
                    addsymref(srsym);
                    result:=true;
                    exit;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        result:=false;
        srsym:=nil;
        srsymtable:=nil;
      end;


    function searchsym_in_module(pm:pointer;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
      var
        pmod : TModule;
      begin
        result:=false;
        if not Assigned(pm) then exit;
        pmod:=TModule(pm);
        if Assigned(pmod.GlobalSymTable) then
          begin
            srsym:=TSym(pmod.GlobalSymTable.Find(s));
            if Assigned(srsym) then
              begin
                srsymtable:=pmod.GlobalSymTable;
                addsymref(srsym);
                result:=true;
                exit;
              end;
          end;
        { If the module is the current unit we also need
          to search the local symtable }
        if (pmod=CurrentModule) and
           Assigned(pmod.localsymtable) then
          begin
            srsym:=TSym(pmod.localsymtable.Find(s));
            if Assigned(srsym) then
              begin
                srsymtable:=pmod.localsymtable;
                addsymref(srsym);
                result:=true;
                exit;
              end;
          end;
        srsym:=nil;
        srsymtable:=nil;
      end;


    function searchsym_in_named_module(const unitname, symname: TIDString; out srsym: TSym; out srsymtable: TSymTable): boolean;
      var
        stackitem  : PSymTableStackItem;
      begin
        result:=false;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            srsymtable:=stackitem^.SymTable;
            if (srsymtable.symtabletype=GlobalSymTable) and
               (srsymtable.name^=unitname) then
              begin
                srsym:=TSym(srsymtable.find(symname));
                if not Assigned(srsym) then
                  break;
                result:=true;
                exit;
              end;
            stackitem:=stackitem^.next;
          end;

        { If the module is the current unit we also need
          to search the local symtable }
        if Assigned(CurrentModule.localsymtable) and
           (CurrentModule.localsymtable.name^=unitname) then
          begin
            srsymtable:=CurrentModule.localsymtable;
            srsym:=TSym(srsymtable.find(symname));
            if Assigned(srsym) then
              begin
                result:=true;
                exit;
              end;
          end;
      end;


    function maybe_find_real_class_definition(pd: TDef; erroronfailure: boolean): TDef;
      begin
        result:=pd;
        if pd.typ<>objectdef then
          exit;
        result:=find_real_class_definition(TObjectDef(pd),erroronfailure);
      end;


    function find_real_class_definition(pd: TObjectDef; erroronfailure: boolean): TObjectDef;
      var
        hashedid   : THashedIDString;
        stackitem  : PSymTableStackItem;
        srsymtable : TSymTable;
        srsym      : TSym;
        formalname,
        foundname : shortstring;
        formalnameptr,
        foundnameptr: PShortString;
      begin
        while pd.is_unique_objpasdef do
          begin
            pd:=pd.childof;
          end;
        { not a formal definition -> return it }
        if not(oo_is_formal in pd.objectoptions) then
          begin
            result:=pd;
            exit;
          end;
        hashedid.id:=pd.typesym.name;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            srsymtable:=stackitem^.SymTable;

            if not(srsymtable.symtabletype in [recordsymtable,parasymtable]) then
              begin
                srsym:=TSym(srsymtable.FindWithHash(hashedid));
                if Assigned(srsym) and
                   (srsym.typ=typesym) and
                   (TTypeSym(srsym).typedef.typ=objectdef) and
                   (TObjectDef(TTypeSym(srsym).typedef).objecttype=pd.objecttype) and
                   not(oo_is_formal in TObjectDef(TTypeSym(srsym).typedef).objectoptions) then
                  begin
                    if not(oo_is_forward in TObjectDef(TTypeSym(srsym).typedef).objectoptions) then
                      begin
                        { the external name for the formal and the real
                          definition must match }
                        if Assigned(TObjectDef(TTypeSym(srsym).typedef).import_lib) or
                           Assigned(pd.import_lib) then
                          begin
                            if Assigned(pd.import_lib) then
                              formalname:=pd.import_lib^+'.'
                            else
                              formalname:='';
                            formalname:=formalname+pd.objextname^;
                            if Assigned(TObjectDef(TTypeSym(srsym).typedef).import_lib) then
                              foundname:=TObjectDef(TTypeSym(srsym).typedef).import_lib^+'.'
                            else
                              foundname:='';
                            foundname:=foundname+TObjectDef(TTypeSym(srsym).typedef).objextname^;

                            formalnameptr:=@formalname;
                            foundnameptr:=@foundname;
                          end
                        else
                          begin
                            formalnameptr:=pd.objextname;
                            foundnameptr:=TObjectDef(TTypeSym(srsym).typedef).objextname;
                          end;
                        if foundnameptr^<>formalnameptr^ then
                          begin
                            MessagePos2(pd.typesym.fileinfo,sym_e_external_class_name_mismatch1,formalnameptr^,pd.typename);
                            MessagePos1(srsym.fileinfo,sym_e_external_class_name_mismatch2,foundnameptr^);
                          end;
                      end;
                    result:=TObjectDef(TTypeSym(srsym).typedef);
                    if Assigned(CurrentProcInfo) and
                       (srsym.owner.symtabletype=staticsymtable) then
                      include(CurrentProcInfo.flags,pi_uses_static_symtable);
                    addsymref(srsym);
                    exit;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        { nothing found: optionally give an error and return the original
          (empty) one }
        if erroronfailure then
          Message1(sym_e_formal_class_not_resolved,pd.objrealname^);
        result:=pd;
      end;


    function searchsym_in_class(classh: TObjectDef;contextclassh:TAbstractRecordDef;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
      var
        hashedid : THashedIDString;
        orgclass : TObjectDef;
        i        : LongInt;
      begin
        orgclass:=classh;
        { in case this is a formal class, first find the real definition }
        if Assigned(classh) then
          begin
            if (oo_is_formal in classh.objectoptions) then
              classh:=find_real_class_definition(classh,true);
            { The contextclassh is used for visibility. The classh must be equal to
              or be a parent of contextclassh. E.g. for inherited searches the classh is the
              parent or a class helper. }
            if not (def_is_related(contextclassh,classh) or
                (is_classhelper(contextclassh) and
                 Assigned(TObjectDef(contextclassh).extendeddef) and
                (TObjectDef(contextclassh).extendeddef.typ=objectdef) and
                def_is_related(TObjectDef(contextclassh).extendeddef,classh))) then
              InternalError(200811161);
          end;
        result:=false;
        hashedid.id:=s;

        if is_objcprotocol(classh) then
          begin
            srsymtable:=classh.SymTable;
            srsym:=TSym(srsymtable.FindWithHash(hashedid));
            if Assigned(srsym) and
               is_visible_for_object(srsym,contextclassh) then
              begin
                if not (ssf_no_addsymref in flags) then
                  addsymref(srsym);
                result:=true;
                exit;
              end;
            for i:=0 to classh.ImplementedInterfaces.count-1 do
              begin
                if searchsym_in_class(TImplementedInterface(classh.ImplementedInterfaces[i]).intfdef,contextclassh,s,srsym,srsymtable,flags-[ssf_search_helper]) then
                  begin
                    result:=true;
                    exit;
                  end;
              end;
          end
        else
        if is_objectpascal_helper(classh) then
          begin
            { helpers have their own obscure search logic... }
            result:=searchsym_in_helper(classh,TObjectDef(contextclassh),s,srsym,srsymtable,flags-[ssf_has_inherited]);
            if result then
              exit;
          end
        else
          begin
            while Assigned(classh) do
              begin
                { search for a class helper method first if this is an Object
                  Pascal class and we haven't yet found a helper symbol }
                if (classh.objecttype in objecttypes_with_helpers) and
                    (ssf_search_helper in flags) then
                  begin
                    result:=search_objectpascal_helper(classh,contextclassh,s,srsym,srsymtable);
                    { an eventual overload inside the extended type's hierarchy
                      will be found by tcallcandidates }
                    if result then
                      exit;
                  end;
                srsymtable:=classh.SymTable;
                srsym:=TSym(srsymtable.FindWithHash(hashedid));
                if Assigned(srsym) and
                   is_visible_for_object(srsym,contextclassh) then
                  begin
                    if not (ssf_no_addsymref in flags) then
                      addsymref(srsym);
                    result:=true;
                    exit;
                  end;
                classh:=classh.childof;
              end;
          end;
        if is_objcclass(orgclass) then
          result:=search_objc_helper(orgclass,s,srsym,srsymtable)
        else
          begin
            srsym:=nil;
            srsymtable:=nil;
          end;
      end;

    function  searchsym_in_record(recordh:TAbstractRecordDef;const s : TIDString;out srsym:TSym;out srsymtable:TSymTable):boolean;
      var
        hashedid : THashedIDString;
      begin
        result:=false;
        hashedid.id:=s;
        { search for a record helper method first }
        result:=search_objectpascal_helper(recordh,recordh,s,srsym,srsymtable);
        if result then
          { an eventual overload inside the extended type's hierarchy
            will be found by tcallcandidates }
          exit;
        srsymtable:=recordh.SymTable;
        srsym:=TSym(srsymtable.FindWithHash(hashedid));
        if Assigned(srsym) and is_visible_for_object(srsym,recordh) then
          begin
            addsymref(srsym);
            result:=true;
            exit;
          end;
        srsym:=nil;
        srsymtable:=nil;
      end;

    function searchsym_in_class_by_msgint(classh:TObjectDef;msgid:LongInt;out srdef : TDef;out srsym:TSym;out srsymtable:TSymTable):boolean;
      var
        def : TDef;
        i   : LongInt;
      begin
        { in case this is a formal class, first find the real definition }
        if Assigned(classh) and
           (oo_is_formal in classh.objectoptions) then
          classh:=find_real_class_definition(classh,true);
        result:=false;
        def:=nil;
        while Assigned(classh) do
          begin
            for i:=0 to classh.SymTable.DefList.Count-1 do
              begin
                def:=TStoredDef(classh.SymTable.DefList[i]);
                { Find also all hidden private methods to
                  be compatible with delphi, see tw6203 (PFV) }
                if (def.typ=procdef) and
                   (po_msgint in TProcDef(def).procoptions) and
                   (TProcDef(def).messageinf.i=msgid) then
                  begin
                    srdef:=def;
                    srsym:=TProcDef(def).procsym;
                    srsymtable:=classh.SymTable;
                    addsymref(srsym);
                    result:=true;
                    exit;
                  end;
              end;
            classh:=classh.childof;
          end;
        srdef:=nil;
        srsym:=nil;
        srsymtable:=nil;
      end;


    function searchsym_in_class_by_msgstr(classh:TObjectDef;const s:string;out srsym:TSym;out srsymtable:TSymTable):boolean;
      var
        def : TDef;
        i   : LongInt;
      begin
        { in case this is a formal class, first find the real definition }
        if Assigned(classh) and
           (oo_is_formal in classh.objectoptions) then
          classh:=find_real_class_definition(classh,true);
        result:=false;
        def:=nil;
        while Assigned(classh) do
          begin
            for i:=0 to classh.SymTable.DefList.Count-1 do
              begin
                def:=TStoredDef(classh.SymTable.DefList[i]);
                { Find also all hidden private methods to
                  be compatible with delphi, see tw6203 (PFV) }
                if (def.typ=procdef) and
                   (po_msgstr in TProcDef(def).procoptions) and
                   (TProcDef(def).messageinf.str^=s) then
                  begin
                    srsym:=TProcDef(def).procsym;
                    srsymtable:=classh.SymTable;
                    addsymref(srsym);
                    result:=true;
                    exit;
                  end;
              end;
            classh:=classh.childof;
          end;
        srsym:=nil;
        srsymtable:=nil;
      end;

    function search_best_objectpascal_helper(const name: string;pd : TDef;contextclassh : TAbstractRecordDef;out srsym: TSym;out srsymtable: TSymTable):boolean;forward;

    function searchsym_in_helper(classh,contextclassh:TObjectDef;const s: TIDString;out srsym:TSym;out srsymtable:TSymTable;flags:TSymbolSearchFlags):boolean;
      var
        hashedid      : THashedIDString;
        parentclassh  : TObjectDef;
      begin
        result:=false;
        if not is_objectpascal_helper(classh) then
          InternalError(2011030101);
        hashedid.id:=s;
        { in a helper things are a bit more complex:
          1. search the symbol in the helper (if not "inherited")
          2. search the symbol in the extended type
          3. search the symbol in the parent helpers
          4. only classes: search the symbol in the parents of the extended type
        }
        if not (ssf_has_inherited in flags) then
          begin
            { search in the helper itself }
            srsymtable:=classh.SymTable;
            srsym:=TSym(srsymtable.FindWithHash(hashedid));
            if Assigned(srsym) and
               is_visible_for_object(srsym,contextclassh) then
              begin
                if not (ssf_no_addsymref in flags) then
                  addsymref(srsym);
                result:=true;
                exit;
              end;
          end;
        { now search in the extended type itself }
        { Note: the extendeddef might be Nil if we are currently parsing the
                extended type itself and the identifier was not found }
        if Assigned(classh.extendeddef) and (classh.extendeddef.typ in [recorddef,objectdef]) then
          begin
            srsymtable:=TAbstractRecordDef(classh.extendeddef).SymTable;
            srsym:=TSym(srsymtable.FindWithHash(hashedid));
            if Assigned(srsym) and
               is_visible_for_object(srsym,contextclassh) then
              begin
                if not (ssf_no_addsymref in flags) then
                  addsymref(srsym);
                result:=true;
                exit;
              end;
          end;
        { now search in the parent helpers }
        parentclassh:=classh.childof;
        while Assigned(parentclassh) do
          begin
            srsymtable:=parentclassh.SymTable;
            srsym:=TSym(srsymtable.FindWithHash(hashedid));
            if Assigned(srsym) and
               is_visible_for_object(srsym,contextclassh) then
              begin
                if not (ssf_no_addsymref in flags) then
                  addsymref(srsym);
                result:=true;
                exit;
              end;
            parentclassh:=parentclassh.childof;
          end;
        { now search in the parents of the extended class (with helpers!) }
        if is_class(classh.extendeddef) then
          begin
            result:=searchsym_in_class(TObjectDef(classh.extendeddef).childof,contextclassh,s,srsym,srsymtable,flags+[ssf_search_helper]);
            { addsymref is already called by searchsym_in_class }
            if result then
              exit;
          end;
        { now search all helpers using the extendeddef as the starting point }
        if (m_multi_helpers in CurrentSettings.ModeSwitches) and
            (
              (CurrentStructDef<>classh) or
              Assigned(classh.extendeddef)
            ) then
          begin
            { this is only allowed if classh is currently parsed }
            if not Assigned(classh.extendeddef) then
              InternalError(2019110101);
            result:=search_best_objectpascal_helper(s,classh.extendeddef,contextclassh,srsym,srsymtable);
          end;
      end;

    function search_specific_assignment_operator(assignment_type:TToken;from_def,to_def:TDef):TProcDef;
      var
        sym : TProcSym;
        hashedid : THashedIDString;
        curreq,
        besteq : TEqualType;
        currpd,
        bestpd : TProcDef;
        stackitem : PSymTableStackItem;
        shortstringcount : LongInt;
        isexplicit,
        checkshortstring : boolean;
      begin
        hashedid.id:=overloaded_names[assignment_type];
        besteq:=te_incompatible;
        bestpd:=nil;
        stackitem:=SymTableStack.stack;
        { special handling for assignments to shortstrings with a specific length:
          - if we get an operator to ShortString we use that
          - if we get only a single String[x] operator we use that
          - otherwise it's a nogo }
        isexplicit:=assignment_type=_OP_EXPLICIT;
        shortstringcount:=0;
        checkshortstring:=not isexplicit and is_shortstring(to_def) and (TStringDef(to_def).len<>255);
        while Assigned(stackitem) do
          begin
            sym:=TProcSym(stackitem^.SymTable.FindWithHash(hashedid));
            if sym<>nil then
              begin
                if sym.typ<>procsym then
                  InternalError(200402031);
                { if the source type is an alias then this is only the second choice,
                  if you mess with this code, check tw4093 }
                currpd:=sym.find_procdef_assignment_operator(from_def,to_def,curreq,isexplicit);
                { we found a ShortString overload, use that and be done }
                if checkshortstring and
                    Assigned(currpd) and
                    is_shortstring(currpd.returndef) and
                    (TStringDef(currpd.returndef).len=255) then
                  begin
                    besteq:=curreq;
                    bestpd:=currpd;
                    break;
                  end;
                { independently of the operator being better count if we encountered
                  multiple String[x] operators }
                if checkshortstring and Assigned(currpd) and is_shortstring(currpd.returndef) then
                  inc(shortstringcount);
                if curreq>besteq then
                  begin
                    besteq:=curreq;
                    bestpd:=currpd;
                    { don't stop searching if we have a String[x] operator cause
                      we might find a ShortString one or multiple ones (which
                      leads to no operator use) }
                    if (besteq=te_exact) and not checkshortstring then
                      break;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        if checkshortstring and (shortstringcount>1) then
          bestpd:=nil;
        result:=bestpd;
      end;


    function search_assignment_operator(from_def,to_def:TDef;explicit:boolean):TProcDef;
      begin
        { search record/object symtable first for a suitable operator }
        if from_def.typ in [recorddef,objectdef] then
          SymTableStack.push(TAbstractRecordDef(from_def).SymTable);
        if to_def.typ in [recorddef,objectdef] then
          SymTableStack.push(TAbstractRecordDef(to_def).SymTable);

        { if type conversion is explicit then search first for explicit
          operator overload and if not found then use implicit operator }
        if explicit then
          result:=search_specific_assignment_operator(_OP_EXPLICIT,from_def,to_def)
        else
          result:=nil;
        if result=nil then
          result:=search_specific_assignment_operator(_ASSIGNMENT,from_def,to_def);

        { if we're assigning to a typed pointer, but we did not find a suitable assignment
          operator then we also check for a untyped pointer assignment operator }
        if not Assigned(result) and is_pointer(to_def) and not is_voidpointer(to_def) then
          begin
            if explicit then
              result:=search_specific_assignment_operator(_OP_EXPLICIT,from_def,voidpointertype);
            if not Assigned(result) then
              result:=search_specific_assignment_operator(_ASSIGNMENT,from_def,voidpointertype);
          end;

        { restore symtable stack }
        if to_def.typ in [recorddef,objectdef] then
          SymTableStack.pop(TAbstractRecordDef(to_def).SymTable);
        if from_def.typ in [recorddef,objectdef] then
          SymTableStack.pop(TAbstractRecordDef(from_def).SymTable);
      end;


    function search_enumerator_operator(from_def,to_def:TDef): TProcDef;
      var
        sym : TProcSym;
        hashedid : THashedIDString;
        curreq,
        besteq : TEqualType;
        currpd,
        bestpd : TProcDef;
        stackitem : PSymTableStackItem;
      begin
        hashedid.id:='enumerator';
        besteq:=te_incompatible;
        bestpd:=nil;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            sym:=TProcSym(stackitem^.SymTable.FindWithHash(hashedid));
            if sym<>nil then
              begin
                if sym.typ<>procsym then
                  InternalError(200910241);
                { if the source type is an alias then this is only the second choice,
                  if you mess with this code, check tw4093 }
                currpd:=sym.find_procdef_enumerator_operator(from_def,to_def,curreq);
                if curreq>besteq then
                  begin
                    besteq:=curreq;
                    bestpd:=currpd;
                    if (besteq=te_exact) then
                      break;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        result:=bestpd;
    end;


    function search_management_operator(mop:TManagementOperator;pd:TDef):TProcDef;
      var
        sym : TProcSym;
        hashedid : THashedIDString;
        optoken: TToken;
      begin
        optoken := managementoperator2tok[mop];
        if (optoken<first_managment_operator) or
           (optoken>last_managment_operator) then
          InternalError(201602280);
        hashedid.id:=overloaded_names[optoken];
        if not (pd.typ in [recorddef]) then
          InternalError(201602281);
        sym:=TProcSym(TAbstractRecordDef(pd).SymTable.FindWithHash(hashedid));
        if sym<>nil then
          begin
            if sym.typ<>procsym then
              InternalError(201602282);
            result:=sym.find_procdef_bytype(potype_operator);
          end
        else
          result:=nil;
      end;


    function search_system_type(const s: TIDString): TTypeSym;
      var
        sym : TSym;
      begin
        check_systemunit_loaded;
        sym:=TSym(systemunit.Find(s));
        if not Assigned(sym) or
           (sym.typ<>typesym) then
          message1(cg_f_unknown_system_type,s);
        result:=TTypeSym(sym);
      end;


    function try_search_system_type(const s: TIDString): TTypeSym;
      var
        sym : TSym;
      begin
        check_systemunit_loaded;
        sym:=TSym(systemunit.Find(s));
        if not Assigned(sym) then
          result:=nil
        else
          begin
            if sym.typ<>typesym then
              message1(cg_f_unknown_system_type,s);
            result:=TTypeSym(sym);
          end;
      end;


    function try_search_current_module_type(const s: TIDString): TTypeSym;
      var
        found: boolean;
        srsymtable: TSymTable;
        srsym: TSym;
      begin
        found:=searchsym_in_module(CurrentModule,TSymTable.maybe_adjust_symname(s),srsym,srsymtable);
        if found then
          begin
            if (srsym.typ<>typesym) then
              InternalError(2014091207);
            result:=TTypeSym(srsym);
          end
        else
          result:=nil;
      end;


    function  search_system_proc(const s: TIDString): TProcDef;
      var
        srsym: TSym;
      begin
        check_systemunit_loaded;
        srsym:=TSym(systemunit.find(s));
        if not Assigned(srsym) and
           (cs_compilesystem in CurrentSettings.ModuleSwitches) then
          srsym:=TSym(systemunit.Find(upper(s)));
        if not Assigned(srsym) or
           (srsym.typ<>procsym) then
          message1(cg_f_unknown_compilerproc,s);
        result:=TProcDef(TProcSym(srsym).procdeflist[0]);
    end;


    function search_named_unit_globaltype(const unitname, typename: TIDString; throwerror: boolean): TTypeSym;
      var
        srsymtable: TSymTable;
        sym: TSym;
      begin
        sym:=nil;
        if searchsym_in_named_module(unitname,typename,sym,srsymtable) and
           (sym.typ=typesym) then
          begin
            result:=TTypeSym(sym);
            exit;
          end
        else
          begin
            if throwerror then
              message2(cg_f_unknown_type_in_unit,typename,unitname);
            result:=nil;
          end;
      end;

    function search_sym_in_helperdef(const s: string;classh : TObjectDef;contextclassh : TAbstractRecordDef;out srsym: TSym;out srsymtable: TSymTable): boolean;
      var
        hashedid : THashedIDString;
        pdef : TProcDef;
        i : integer;
      begin
        hashedid.id:=s;
        result:=false;
        repeat
          srsymtable:=classh.SymTable;
          srsym:=TSym(srsymtable.FindWithHash(hashedid));
          if srsym<>nil then
            begin
              case srsym.typ of
                procsym:
                  begin
                    for i:=0 to TProcSym(srsym).procdeflist.count-1 do
                      begin
                        pdef:=TProcDef(TProcSym(srsym).procdeflist[i]);
                        if not is_visible_for_object(pdef.owner,pdef.visibility,contextclassh) then
                          continue;
                        srsym:=TProcDef(TProcSym(srsym).procdeflist[i]).procsym;
                        srsymtable:=srsym.owner;
                        result:=true;
                        exit;
                      end;
                    if (sp_generic_dummy in TProcSym(srsym).symoptions) and
                        (TProcSym(srsym).procdeflist.count=0) and
                        is_visible_for_object(srsym.owner,srsym.visibility,contextclassh) then
                      begin
                        srsymtable:=srsym.owner;
                        result:=true;
                        exit;
                      end;
                  end;
                typesym,
                fieldvarsym,
                constsym,
                enumsym,
                undefinedsym,
                propertysym:
                  begin
                    result:=true;
                    exit;
                  end;
                else
                  InternalError(2014041101);
              end;
            end;

          { try the helper parent if available }
          classh:=classh.childof;
        until classh=nil;
      end;

    function get_objectpascal_helpers(pd : TDef):TFPObjectList;
      var
        s : TSymStr;
        st : TSymTable;
      begin
        result:=nil;
        { when there are no helpers active currently then we don't need to do
          anything }
        if CurrentModule.extendeddefs.count=0 then
          exit;
        if (df_genconstraint in pd.defoptions) then
          begin
            { if we have a constraint for a class type or a single interface we
              use that to resolve helpers at declaration time of the generic,
              otherwise there can't be any helpers as the type isn't known yet }
            if pd.typ=objectdef then
              pd:=TObjectDef(pd).getparentdef
            else
              exit;
          end;
        { no helpers for anonymous types }
        if ((pd.typ in [recorddef,objectdef]) and
            (
              not Assigned(TAbstractRecordDef(pd).objrealname) or
              (TAbstractRecordDef(pd).objrealname^='')
            )
           ) or
           not Assigned(pd.typesym) then
          exit;
        { if pd is defined inside a procedure we must not use make_mangledname
          (as a helper may not be defined in a procedure this is no problem...)}
        st:=pd.owner;
        while st.symtabletype in [objectsymtable,recordsymtable] do
          st:=st.defowner.owner;
        if st.symtabletype=localsymtable then
          exit;
        { the mangled name is used as the key for tmodule.extendeddefs }
        s:=generate_objectpascal_helper_key(pd);
        result:=TFPObjectList(CurrentModule.extendeddefs.Find(s));
      end;

    function search_best_objectpascal_helper(const name: string;pd : TDef;contextclassh : TAbstractRecordDef;out srsym: TSym;out srsymtable: TSymTable):boolean;
      var
        list : TFPObjectList;
        i : integer;
        odef : TObjectDef;
      begin
        result:=false;
        list:=get_objectpascal_helpers(pd);
        if Assigned(list) and (list.count>0) then
          begin
            i:=list.count-1;
            repeat
              odef:=TObjectDef(list[i]);
              result:=(odef.owner.symtabletype in [staticsymtable,GlobalSymTable]) or
                      is_visible_for_object(TObjectDef(list[i]).typesym,contextclassh);
              if result then
                result:=search_sym_in_helperdef(name,odef,contextclassh,srsym,srsymtable);
              dec(i);
            until result or (i<0);
          end;
      end;

    function search_last_objectpascal_helper(pd : TDef;contextclassh : TAbstractRecordDef;out odef : TObjectDef):boolean;
      var
        list : TFPObjectList;
        i : integer;
      begin
        result:=false;
        odef:=nil;
        list:=get_objectpascal_helpers(pd);
        if Assigned(list) and (list.count>0) then
          begin
            i:=list.count-1;
            repeat
              odef:=TObjectDef(list[list.count-1]);
              result:=(odef.owner.symtabletype in [staticsymtable,GlobalSymTable]) or
                      is_visible_for_object(TObjectDef(list[i]).typesym,contextclassh);
              dec(i);
            until result or (i<0);
            if not result then
              { just to be sure that none uses odef }
              odef:=nil;
          end;
      end;

    function search_objectpascal_helper(pd : TDef;contextclassh : TAbstractRecordDef;const s: string; out srsym: TSym; out srsymtable: TSymTable):boolean;
      var
        classh : TObjectDef;
      begin
        result:=false;

        { if there is no class helper for the class then there is no need to
          search further }
        if m_multi_helpers in CurrentSettings.ModeSwitches then
          result:=search_best_objectpascal_helper(s,pd,contextclassh,srsym,srsymtable)
        else
          begin
            if search_last_objectpascal_helper(pd,contextclassh,classh) and
               search_sym_in_helperdef(s,classh,contextclassh,srsym,srsymtable) then
                result:=true;
          end;

        if result then
          begin
            { we need to know if a procedure references symbols
              in the static symtable, because then it can't be
              inlined from outside this unit }
            if (srsym.typ=procsym) and
               Assigned(CurrentProcInfo) and
               (srsym.owner.symtabletype=staticsymtable) then
              include(CurrentProcInfo.flags,pi_uses_static_symtable);
            addsymref(srsym);
          end
        else
          begin
            srsym:=nil;
            srsymtable:=nil;
          end;
      end;

    function search_objc_helper(pd : TObjectDef;const s : string; out srsym: TSym; out srsymtable: TSymTable):boolean;
      var
        searchst   : TSymTable;
        searchsym  : TSym;
        hashedid   : THashedIDString;
        stackitem  : PSymTableStackItem;
        i          : LongInt;
        founddefowner,
        defowner   : TObjectDef;
      begin
        hashedid.id:=class_helper_prefix+s;
        stackitem:=SymTableStack.stack;
        result:=false;
        srsym:=nil;
        srsymtable:=nil;
        founddefowner:=nil;
        while Assigned(stackitem) do
          begin
            searchst:=stackitem^.SymTable;
            searchsym:=TSym(searchst.FindWithHash(hashedid));
            if Assigned(searchsym) then
              begin
                if not(searchst.symtabletype in [GlobalSymTable,staticsymtable]) or
                   not(searchsym.owner.symtabletype in [GlobalSymTable,staticsymtable]) or
                   (searchsym.typ<>procsym) then
                  InternalError(2009111505);
                { check whether this procsym includes a helper for this particular class }
                for i:=0 to TProcSym(searchsym).procdeflist.count-1 do
                  begin
                    { does pd inherit from (or is the same as) the class
                      that this method's category extended?

                      Warning: this list contains both category and objcclass methods
                       (for id.randommethod), so only check category methods here
                    }
                    defowner:=TObjectDef(TProcDef(TProcSym(searchsym).procdeflist[i]).owner.defowner);
                    if is_objccategory(defowner) and
                       def_is_related(pd,defowner.childof) then
                      begin
                        { we need to know if a procedure references symbols
                          in the static symtable, because then it can't be
                          inlined from outside this unit }
                        if Assigned(CurrentProcInfo) and
                           (searchsym.owner.symtabletype=staticsymtable) then
                          include(CurrentProcInfo.flags,pi_uses_static_symtable);
                        { Stop looking if this is a category that extends the specified
                          class itself. There might be other categories that extend this,
                          but that doesn't matter. If it extens a parent, keep looking
                          in case we find the symbol in a category that extends this class
                          (or a closer parent).
                        }
                        if not result or
                           def_is_related(defowner.childof,founddefowner) then
                          begin
                            founddefowner:=defowner.childof;
                            srsym:=TProcDef(TProcSym(searchsym).procdeflist[i]).procsym;
                            srsymtable:=srsym.owner;
                            result:=true;
                            if pd=founddefowner then
                              begin
                                addsymref(srsym);
                                exit;
                              end;
                          end;
                      end;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        if result then
          begin
            addsymref(srsym);
            exit;
          end;
      end;


    function search_objc_method(const s : string; out srsym: TSym; out srsymtable: TSymTable):boolean;
      var
        hashedid   : THashedIDString;
        stackitem  : PSymTableStackItem;
        i          : LongInt;
      begin
        hashedid.id:=class_helper_prefix+s;
        stackitem:=SymTableStack.stack;
        while Assigned(stackitem) do
          begin
            srsymtable:=stackitem^.SymTable;
            srsym:=TSym(srsymtable.FindWithHash(hashedid));
            if Assigned(srsym) then
              begin
                if not(srsymtable.symtabletype in [GlobalSymTable,staticsymtable]) or
                   not(srsym.owner.symtabletype in [GlobalSymTable,staticsymtable]) or
                   (srsym.typ<>procsym) then
                  InternalError(2009112005);
                { check whether this procsym includes a helper for this particular class }
                for i:=0 to TProcSym(srsym).procdeflist.count-1 do
                  begin
                    { we need to know if a procedure references symbols
                      in the static symtable, because then it can't be
                      inlined from outside this unit }
                    if Assigned(CurrentProcInfo) and
                       (srsym.owner.symtabletype=staticsymtable) then
                      include(CurrentProcInfo.flags,pi_uses_static_symtable);
                    { no need to keep looking. There might be other
                      methods with the same name, but that doesn't matter
                      as far as the basic procsym is concerned.
                    }
                    srsym:=TProcDef(TProcSym(srsym).procdeflist[i]).procsym;
                    { We need the symtable in which the classhelper-like sym
                      is located, not the objectdef. The reason is that the
                      callnode will climb the symtablestack until it encounters
                      this symtable to start looking for overloads (and it won't
                      find the objectsymtable in which this method sym is
                      located

                    srsymtable:=srsym.owner;
                    }
                    addsymref(srsym);
                    result:=true;
                    exit;
                  end;
              end;
            stackitem:=stackitem^.next;
          end;
        srsym:=nil;
        srsymtable:=nil;
        result:=false;
      end;


    function search_struct_member(pd : TAbstractRecordDef;const s : string):TSym;
    { searches n in symtable of pd and all anchestors }
      var
        srsymtable : TSymTable;
      begin
        { in case this is a formal class, first find the real definition }
        if (oo_is_formal in pd.objectoptions) then
          pd:=find_real_class_definition(TObjectDef(pd),true);

        if search_objectpascal_helper(pd, pd, s, result, srsymtable) then
          exit;

        result:=search_struct_member_no_helper(pd,s);
        if Assigned(result) then
          exit;

        { not found, now look for class helpers }
        if is_objcclass(pd) then
          search_objc_helper(TObjectDef(pd),s,result,srsymtable)
      end;


    function search_struct_member_no_helper(pd: TAbstractRecordDef; const s: string): TSym;
      var
        hashedid   : THashedIDString;
        srsym      : TSym;
      begin
        hashedid.id:=s;
        while Assigned(pd) do
         begin
            srsym:=TSym(pd.SymTable.FindWithHash(hashedid));
            if Assigned(srsym) then
              begin
                result:=srsym;
                exit;
              end;
            if pd.typ=objectdef then
              pd:=TObjectDef(pd).childof
            else
              pd:=nil;
          end;
        result:=nil;
      end;


    function search_macro(const s : string):TSym;
      var
        stackitem  : PSymTableStackItem;
        hashedid   : THashedIDString;
        srsym      : TSym;
      begin
        hashedid.id:=s;

        { The default text model is selected once for the compiler invocation.
          A unit-local or imported macro must not shadow its define. }
        if upper(s)='FPC_UNICODESTRINGS' then
          begin
            hashedid.id:='FPC_UNICODESTRINGS';
            if Assigned(initialmacrosymtable) then
              result:=TSym(initialmacrosymtable.FindWithHash(hashedid))
            else
              result:=nil;
            exit;
          end;

        { First search the localmacrosymtable before searching the
          global macrosymtables from the units }
        if Assigned(CurrentModule) then
          begin
            srsym:=TSym(CurrentModule.localmacrosymtable.FindWithHash(hashedid));
            if Assigned(srsym) then
              begin
                result:= srsym;
                exit;
              end;
          end;

        stackitem:=MacroSymTableStack.stack;
        while Assigned(stackitem) do
          begin
            srsym:=TSym(stackitem^.SymTable.FindWithHash(hashedid));
            if Assigned(srsym) then
              begin
                result:= srsym;
                exit;
              end;
            stackitem:=stackitem^.next;
          end;
        result:= nil;
      end;


    function defined_macro(const s : string):boolean;
      var
        mac: TMacro;
      begin
        mac:=TMacro(search_macro(s));
        if Assigned(mac) then
          begin
            mac.is_used:=true;
            defined_macro:=mac.defined;
          end
        else
          defined_macro:=false;
      end;


{****************************************************************************
                              Object Helpers
****************************************************************************}

   function search_default_property(pd : TAbstractRecordDef) : TPropertySym;
   { returns the default property of a class, searches also anchestors }
     var
       _defaultprop : TPropertySym;
       helperpd : TObjectDef;
     begin
        _defaultprop:=nil;
        { first search in helper's hierarchy }
        if search_last_objectpascal_helper(pd,nil,helperpd) then
          while Assigned(helperpd) do
            begin
              helperpd.SymTable.SymList.ForEachCall(@TStoredSymTable(helperpd.SymTable).testfordefaultproperty,@_defaultprop);
              if Assigned(_defaultprop) then
                break;
              helperpd:=helperpd.childof;
            end;
        if Assigned(_defaultprop) then
          begin
            search_default_property:=_defaultprop;
            exit;
          end;
        { now search in the type's hierarchy itself }
        while Assigned(pd) do
          begin
             pd.SymTable.SymList.ForEachCall(@TStoredSymTable(pd.SymTable).testfordefaultproperty,@_defaultprop);
             if Assigned(_defaultprop) then
               break;
             if (pd.typ=objectdef) then
               pd:=TObjectDef(pd).childof
             else
               break;
          end;
        search_default_property:=_defaultprop;
     end;


{****************************************************************************
                              Macro Helpers
****************************************************************************}

    procedure def_system_macro(const name : string);
      var
        mac : TMacro;
        s: string;
      begin
         if name = '' then
           InternalError(2004121202);
         s:= upper(name);
         mac:=TMacro(search_macro(s));
         if not Assigned(mac) then
           begin
             mac:=TMacro.create(s);
             if Assigned(CurrentModule) then
               CurrentModule.localmacrosymtable.insertsym(mac)
             else
               initialmacrosymtable.insertsym(mac);
           end;
         Message1(parser_c_macro_defined,mac.name);
         mac.defined:=true;
      end;


    procedure set_system_macro(const name, value : string);
      var
        mac : TMacro;
        s: string;
      begin
        if name = '' then
          InternalError(2004121203);
         s:= upper(name);
         mac:=TMacro(search_macro(s));
         if not Assigned(mac) then
           begin
             mac:=TMacro.create(s);
             if Assigned(CurrentModule) then
               CurrentModule.localmacrosymtable.insertsym(mac)
             else
               initialmacrosymtable.insertsym(mac);
           end
         else
           begin
             mac.is_compiler_var:=false;
             mac.free_buftext;
           end;
           mac.is_c_macro:=true;
         Message2(parser_c_macro_set_to,mac.name,value);
         move(value[1],mac.allocate_buftext(length(value))^,length(value));
         mac.defined:=true;
      end;


    procedure set_system_compvar(const name, value : string);
      var
        mac : TMacro;
        s: string;
      begin
        if name = '' then
          InternalError(2004121204);
         s:= upper(name);
         mac:=TMacro(search_macro(s));
         if not Assigned(mac) then
           begin
             mac:=TMacro.create(s);
             mac.is_compiler_var:=true;
             if Assigned(CurrentModule) then
               CurrentModule.localmacrosymtable.insertsym(mac)
             else
               initialmacrosymtable.insertsym(mac);
           end
         else
           mac.is_compiler_var:=true;
         Message2(parser_c_macro_set_to,mac.name,value);
         move(value[1],mac.allocate_buftext(length(value))^,length(value));
         mac.defined:=true;
      end;


    procedure undef_system_macro(const name : string);
      var
        mac : TMacro;
        s: string;
      begin
         if name = '' then
           InternalError(2004121205);
         s:= upper(name);
         mac:=TMacro(search_macro(s));
         if not Assigned(mac) then
           {If not found, then it's already undefined.}
         else
           begin
             Message1(parser_c_macro_undefined,mac.name);
             mac.defined:=false;
             mac.is_compiler_var:=false;
             { delete old definition }
             mac.free_buftext;
           end;
      end;


{$ifdef UNITALIASES}
{****************************************************************************
                              TUNIT_ALIAS
 ****************************************************************************}

    constructor TUnitAlias.create(const n:string);
      var
        i : LongInt;
      begin
        i:=pos('=',n);
        if i=0 then
         fail;
        inherited createname(Copy(n,1,i-1));
        newname:=StringDup(Copy(n,i+1,255));
      end;


    destructor TUnitAlias.Destroy;
      begin
        StringDispose(newname);
        inherited Destroy;
      end;


    procedure addunitalias(const n:string);
      begin
        unitaliases^.insert(TUnitAlias,init(Upper(n))));
      end;


    function getunitalias(const n:string):string;
      var
        p : PUnitAlias;
      begin
        p:=PUnitAlias(unitaliases^.Find(Upper(n)));
        if Assigned(p) then
         getunitalias:=PUnitAlias(p).newname^
        else
         getunitalias:=n;
      end;
{$endif UNITALIASES}


{****************************************************************************
                           Init/Done Symtable
****************************************************************************}

   procedure InitSymtable;
     var
       textmodemacro: TMacro;
     begin
       { Reset symbolstack }
       SymTableStack:=nil;
       systemunit:=nil;
       { create error syms and def }
       generrorsym:=TErrorSym.create;
       generrordef:=CErrorDef.create;
       { macros }
       initialmacrosymtable:=TMacroSymTable.create(false);
       textmodemacro:=TMacro.create('FPC_UNICODESTRINGS');
       textmodemacro.defined:=false;
       initialmacrosymtable.insertsym(textmodemacro);
       MacroSymTableStack:=TSymTableStack.create;
       MacroSymTableStack.push(initialmacrosymtable);
{$ifdef UNITALIASES}
       { unit aliases }
       unitaliases:=TFPHashObjectList.create;
{$endif}
       dupnr:=0;
     end;


   procedure DoneSymtable;
      begin
        generrorsym.owner:=nil;
        generrorsym.free;
        generrorsym := nil;
        generrordef.owner:=nil;
        generrordef.free;
        generrordef := nil;
        initialmacrosymtable.free;
        initialmacrosymtable := nil;
        MacroSymTableStack.free;
        MacroSymTableStack := nil;
{$ifdef UNITALIASES}
        unitaliases.free;
        unitaliases := nil;
{$endif}
     end;

end.
