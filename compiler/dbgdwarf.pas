{
    Copyright (c) 2003-2006 by Peter Vreman and Florian Klaempfl

    This units contains support for DWARF debug info generation

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
{
  This units contains support for DWARF debug info generation.

  The easiest way to debug dwarf debug info generation is the usage of
  readelf --debug-dump <executable>
  This works only with elf targets though.

  There is a similar utility called dwarfdump which is not elf-specific and
  which has been ported to most systems.
}
unit dbgdwarf;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      CClasses,GlobType,
      cgbase,
      aasmbase,aasmtai,AAsmData,
      SymBase,symconst,symtype,symdef,SymSym,
      FinPut,
      DbgBase, dbgdwarfconst;

    type

      TDwarfFile = record
        Index: integer;
        Name: PChar;
      end;

      { flags for emitting variables/parameters }
      TDwarfVarSymFlag =
        { force the sym to be emitted as a local variable regardless of its
          type; used for "absolute" local variables referring to parameters.
        }
        (dvf_force_local_var
        );
      TDwarfVarSymFlags = set of TDwarfVarSymFlag;

      PAbbrevSearchTreeItem = ^TAbbrevSearchTreeItem;
      TAbbrevSearchTreeItem = record
        value: QWord;
        Abbrev: LongInt;
        // When this item does not match the abbrev-value, look for it
        // in the next SearchItem
        SearchItem: PAbbrevSearchTreeItem;
        // Next and prior item of the abbrev-section
        NextItem: PAbbrevSearchTreeItem;
        PriorItem: PAbbrevSearchTreeItem;
        bit8: boolean;
      end;

      TDwarfHashSetItem = record
        HashSetItem: THashSetItem;
        lab, ref_lab: TAsmSymbol;
        struct_lab: TAsmSymbol;
      end;
      PDwarfHashSetItem = ^TDwarfHashSetItem;

      TDwarfLabHashSet = class(THashSet)
        class function SizeOfItem: Integer; override;
      end;

      { TDebugInfoDwarf }

      TDebugInfoDwarf = class(TDebugInfo)
      private
        currabbrevnumber : LongInt;

        { use this defs to create info for variants and file handles }
        { unused (MWE)
        filerecdef,
        textrecdef : tdef;
        }

        dirlist: TFPHashObjectList;
        filesequence: Integer;
        loclist: TDynamicArray;
        asmline: TAsmList;

        FWin64CUSectionKey: string;
        FWin64RangesStart: TAsmSymbol;
        FWin64RangeIndex: LongInt;

        { lookup table for def -> DWARF-labels }
        dwarflabels: TDwarfLabHashSet;

        // The current entry in dwarf_info with the link to the abbrev-section
        dwarf_info_abbref_tai: TAIConst;
        // Empty start-item of the abbrev-searchtree
        AbbrevSearchTree: PAbbrevSearchTreeItem;
        // The current abbrev-item
        CurrentSearchTreeItem: PAbbrevSearchTreeItem;
        // Is true when the abbrev-section is newly created
        NewAbbrev: boolean;
        procedure StartAbbrevSearch;
        procedure AddConstToAbbrev(Value: QWord; bit8:boolean=false);
        procedure StartAbbrevSectionFromSearchtree;
        procedure WriteSearchItemToAbbrevSection(SI: PAbbrevSearchTreeItem);
        function FinishAbbrevSearch: LongInt;

        function def_dwarf_lab(def:TDef) : TAsmSymbol;
        function def_dwarf_ref_lab(def:TDef) : TAsmSymbol;
        function def_dwarf_class_struct_lab(def:TObjectDef) : TAsmSymbol;
        function get_file_index(afile: TInputFile): Integer;
        function relative_dwarf_path(const s:TCmdStr):TCmdStr;
        function win64_proc_section(def:TProcDef):TAISection;
        procedure append_win64_proc_range(procsection:TAISection;procentrysym,procendlabel:TAsmSymbol;const sectionsuffix:string);
        procedure append_win64_proc_arange(procsection:TAISection;procentrysym,procendlabel:TAsmSymbol;const sectionsuffix:string);
      protected
        // set if we should use 64bit headers (dwarf3 and up)
        _use_64bit_headers: Boolean;
        // set to ait_const32bit if use_64bit_headers is false, otherwise
        // to ait_const64bit
        offsetreltype,
        offsetabstype : TAIConstType;
        // set if we generated any lineinfo at all. If not, we have to terminate
        // when insertmoduleinfo is called.
        generated_lineinfo: boolean;

        vardatadef: TRecordDef;

        procedure set_use_64bit_headers(state: boolean);
        property use_64bit_headers: Boolean read _use_64bit_headers write set_use_64bit_headers;

        function get_def_dwarf_labs(def:TDef): PDwarfHashSetItem;

        function is_fbreg(reg:TRegister):boolean;

        { Convenience version of the method below, so the compiler creates the
          tvarrec for us (must only pass one element in the last parameter).  }
        procedure append_attribute(attr: TDwarfAttribute; form: TDwarfForm; const values: array of const);
        procedure append_attribute(attr: TDwarfAttribute; form: TDwarfForm; const value: tvarrec);
        procedure append_entry(tag : TDwarfTag;has_children : boolean;const data : array of const);
        procedure append_block1(attr: TDwarfAttribute; size: aint);
        procedure append_labelentry(attr : TDwarfAttribute;sym : TAsmSymbol);
        procedure append_labelentry_addr_ref(sym : TAsmSymbol); virtual;
        procedure append_labelentry_ref(attr : TDwarfAttribute;sym : TAsmSymbol);
        procedure append_labelentry_dataptr_abs(attr : TDwarfAttribute;sym : TAsmSymbol);
        procedure append_labelentry_dataptr_rel(attr : TDwarfAttribute;sym,endsym : TAsmSymbol);
        procedure append_labelentry_dataptr_common(attr : TDwarfAttribute);
        procedure append_pointerclass(list:TAsmList;def:TPointerDef);
        procedure append_proc_frame_base(list:TAsmList;def:TProcDef);


        procedure beforeappenddef(list:TAsmList;def:TDef);override;
        procedure afterappenddef(list:TAsmList;def:TDef);override;
        procedure appenddef_ord(list:TAsmList;def:TOrdDef);override;
        procedure appenddef_float(list:TAsmList;def:TFloatDef);override;
        procedure appenddef_enum(list:TAsmList;def:TEnumDef);override;
        procedure appenddef_array(list:TAsmList;def:TArrayDef);override;
        procedure appenddef_record_named(list:TAsmList;def:TRecordDef;const name: shortstring);
        procedure appenddef_record(list:TAsmList;def:TRecordDef);override;
        procedure appenddef_pointer(list:TAsmList;def:TPointerDef);override;
        procedure appenddef_string(list:TAsmList;def:TStringDef);override;
        procedure appenddef_procvar(list:TAsmList;def:TProcVarDef);override;
        procedure appendprocdef(list:TAsmList;def:TProcDef);override;

        function  get_symlist_sym_offset(SymList: PPropAccessListItem; out sym: TAbstractVarSym; out offset: PInt): boolean;
        procedure appendsym_var(list:TAsmList;sym:TAbstractNormalVarSym);
        procedure appendsym_var_with_name_type_offset(list:TAsmList; sym:TAbstractNormalVarSym; const name: string; def: TDef; offset: PInt; const flags: TDwarfVarSymFlags);
        { used for fields and properties mapped to fields }
        procedure appendsym_fieldvar_with_name_offset(list:TAsmList;sym: TFieldVarSym;const name: string; def: TDef; offset: PInt);
        procedure appendsym_const_member(list:TAsmList;sym:TConstSym;ismember:boolean);

        procedure beforeappendsym(list:TAsmList;sym:TSym);override;
        procedure appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);override;
        procedure appendsym_paravar(list:TAsmList;sym:TParaVarSym);override;
        procedure appendsym_localvar(list:TAsmList;sym:TLocalVarSym);override;
        procedure appendsym_fieldvar(list:TAsmList;sym:TFieldVarSym);override;
        procedure appendsym_const(list:TAsmList;sym:TConstSym);override;
        procedure appendsym_type(list:TAsmList;sym:TTypeSym);override;
        procedure appendsym_label(list:TAsmList;sym:TLabelSym);override;
        procedure appendsym_absolute(list:TAsmList;sym:TAbsoluteVarSym);override;
        procedure appendsym_property(list:TAsmList;sym:TPropertySym);override;

        function symdebugname(sym:TSym): String; virtual;
        function symname(sym: TSym; manglename: boolean): String; virtual;
        procedure append_visibility(vis: TVisibility);

        procedure enum_membersyms_callback(p:TObject;arg:pointer);

        procedure finish_children;
        procedure finish_entry;
        procedure finish_lineinfo;

        procedure insert_cu_header_after_version;virtual;
      public
        constructor Create;override;
        destructor Destroy;override;
        procedure insertmoduleinfo;override;
        procedure inserttypeinfo;override;
        procedure referencesections(list:TAsmList);override;
        procedure insertlineinfo(list:TAsmList);override;
        function  dwarf_version: Word; virtual; abstract;
      end;

      { Shared implementation inherited by the supported DWARF generators.
        The historical class name is kept to minimize divergence from upstream. }

      TDebugInfoDwarf2 = class abstract(TDebugInfoDwarf)
      private
      protected
        procedure appenddef_set_intern(list:TAsmList;def:TSetDef; force_tag_set: boolean);
        procedure append_object_struct(def: TObjectDef; const createlabel: boolean; const objectname: PShortString);

        procedure appenddef_file(list:TAsmList;def:TFileDef); override;
        procedure appenddef_formal(list:TAsmList;def:TFormalDef); override;
        procedure appenddef_object(list:TAsmList;def:TObjectDef); override;
        procedure appenddef_set(list:TAsmList;def:TSetDef); override;
        procedure appenddef_undefined(list:TAsmList;def:TUndefinedDef); override;
        procedure appenddef_variant(list:TAsmList;def:TVariantDef); override;
      end;

      { TDebugInfoDwarf3 }

      TDebugInfoDwarf3 = class(TDebugInfoDwarf2)
      private
      protected
        procedure append_labelentry_addr_ref(sym : TAsmSymbol); override;
        procedure appenddef_array(list:TAsmList;def:TArrayDef); override;
        procedure appenddef_string(list:TAsmList;def:TStringDef);override;
        procedure appenddef_file(list:TAsmList;def:TFileDef); override;
        procedure appenddef_formal(list:TAsmList;def:TFormalDef); override;
        procedure appenddef_object(list:TAsmList;def:TObjectDef); override;
        procedure appenddef_set(list:TAsmList;def: TSetDef); override;
        procedure appenddef_undefined(list:TAsmList;def:TUndefinedDef); override;
        procedure appenddef_variant(list:TAsmList;def:TVariantDef); override;

        function symdebugname(sym:TSym): String; override;
      public
        function  dwarf_version: Word; override;
      end;

      { TDebugInfoDwarf4 }

      TDebugInfoDwarf4 = class(TDebugInfoDwarf3)
      public
        function  dwarf_version: Word; override;
      end;

      { TDebugInfoDwarf5 }

      TDebugInfoDwarf5 = class(TDebugInfoDwarf4)
      protected
        procedure insert_cu_header_after_version; override;
      public
        function  dwarf_version: Word; override;
      end;


implementation

    uses
      SysUtils,CUtils,CFileUtl,ConstExp,
      version,Globals,Verbose,Systems,
      cpubase,CPUInfo,paramgr,
      FModule,
      defutil,SymTable,symcpu,PPU
      ;

    const
      LINE_BASE   = 1;
      LINE_RANGE  = 255;
      OPCODE_BASE = 13;

    const
      DW_TAG_lo_user = $4080;
      DW_TAG_hi_user = $ffff;

      { Flag that tells whether entry has a child or not.   }
      DW_children_no = 0;
      DW_children_yes = 1;

    const
      { Implementation-defined range start.   }
      DW_AT_lo_user = $2000;
      { Implementation-defined range end.   }
      DW_AT_hi_user = $3ff0;

    const
      { Implementation-defined range start.   }
      DW_LANG_lo_user = $8000;

      { Implementation-defined range start.   }
      DW_LANG_hi_user = $ffff;


    type
      { Names and codes for macro information.   }
      TDwarfMacInfoRecordType = (DW_MACINFO_define := 1,DW_MACINFO_undef := 2,
        DW_MACINFO_start_file := 3,DW_MACINFO_end_file := 4,
        DW_MACINFO_vendor_ext := 255);

    const
      DW_ATE_lo_user = $80;
      DW_ATE_hi_user = $ff;


    type
      TDwarfArrayDimOrdering = (DW_ORD_row_major := 0,DW_ORD_col_major := 1
        );

      { Access attribute.   }
      TDwarfAccessAttribute = (DW_ACCESS_public := 1,DW_ACCESS_protected := 2,
        DW_ACCESS_private := 3);

      { Visibility.   }
      TDwarfVisibilityAttribute = (DW_VIS_local := 1,DW_VIS_exported := 2,
        DW_VIS_qualified := 3);

      { Virtuality.   }
      TDwarfVirtualityAttribute = (DW_VIRTUALITY_none := 0,DW_VIRTUALITY_virtual := 1,
        DW_VIRTUALITY_pure_virtual := 2);

      { Case sensitivity.   }
      TDwarfIDCase = (DW_ID_case_sensitive := 0,DW_ID_up_case := 1,
        DW_ID_down_case := 2,DW_ID_case_insensitive := 3
        );

      { Calling convention.   }
      TDwarfCallingConvention = (DW_CC_normal := $1,DW_CC_program := $2,
        DW_CC_nocall := $3,DW_CC_GNU_renesas_sh := $40, DW_CC_GNU_borland_fastcall_i386 := $41
        );
    const
      { Implementation-defined range start.   }
      DW_OP_lo_user = $e0;
      { Implementation-defined range end.   }
      DW_OP_hi_user = $ff;


    const
      DW_LNS_extended_op     = $00;

      { next copied from cfidwarf, need to go to something shared }
      DW_LNS_copy            = $01;
      DW_LNS_advance_pc      = $02;
      DW_LNS_advance_line    = $03;
      DW_LNS_set_file        = $04;
      DW_LNS_set_column      = $05;
      DW_LNS_negate_stmt     = $06;
      DW_LNS_set_basic_block = $07;
      DW_LNS_const_add_pc    = $08;

      DW_LNS_fixed_advance_pc   = $09;
      DW_LNS_set_prologue_end   = $0a;
      DW_LNS_set_epilogue_begin = $0b;
      DW_LNS_set_isa            = $0c;

      DW_LNE_end_sequence = $01;
      DW_LNE_set_address  = $02;
      DW_LNE_define_file  = $03;
      { DW_LNE_set_segment is a non-standard Open Watcom extension. It might
        create conflicts with future versions of the DWARF standard. }
      DW_LNE_set_segment  = $04;
      DW_LNE_lo_user      = $80;
      DW_LNE_hi_user      = $ff;

    type
      { TDirIndexItem }

      TDirIndexItem = class(TFPHashObject)
      private
        FFiles: TFPHashObjectList;
      public
        IndexNr : Integer;
        constructor Create(AList:TFPHashObjectList;const AName: String; AIndex: Integer);
        destructor  Destroy;override;
        property Files: TFPHashObjectList read FFiles;
      end;

      { TFileIndexItem }

      TFileIndexItem = class(TFPHashObject)
      private
        FDirIndex: Integer;
      public
        IndexNr : Integer;
        constructor Create(AList:TFPHashObjectList;const AName: String; ADirIndex, AIndex: Integer);
        property DirIndex: Integer read FDirIndex;
      end;


{****************************************************************************
                              procs
****************************************************************************}

    function DirListSortCompare(AItem1, AItem2: Pointer): Integer;
      begin
        Result := TDirIndexItem(AItem1).IndexNr - TDirIndexItem(AItem2).IndexNr;
      end;


    function FileListSortCompare(AItem1, AItem2: Pointer): Integer;
      begin
        Result := TFileIndexItem(AItem1).IndexNr - TFileIndexItem(AItem2).IndexNr;
      end;


    function AllocateNewAiSearchItem: PAbbrevSearchTreeItem;
      begin
        new(result);
        FillChar(result^,sizeof(result^),#0);
      end;

    procedure FreeSearchItem(SI: PAbbrevSearchTreeItem);
      begin
        if Assigned(SI^.NextItem) then
          FreeSearchItem(SI^.NextItem);
        if Assigned(SI^.SearchItem) then
          FreeSearchItem(SI^.SearchItem);
        Dispose(SI);
      end;


{****************************************************************************
                              TDwarfLabHashSet
****************************************************************************}

    class function TDwarfLabHashSet.SizeOfItem: Integer;
      begin
        Result:=sizeof(TDwarfHashSetItem);
      end;

{****************************************************************************
                              TDirIndexItem
****************************************************************************}

    constructor TDirIndexItem.Create(AList:TFPHashObjectList;const AName: String; AIndex: Integer);
      begin
        inherited Create(AList,AName);
        FFiles := TFPHashObjectList.Create;
        IndexNr := AIndex;
      end;


    destructor TDirIndexItem.Destroy;
      begin
        FFiles.Free;
        FFiles := nil;
        inherited Destroy;
      end;


{****************************************************************************
                              TFileIndexItem
****************************************************************************}

    constructor TFileIndexItem.Create(AList:TFPHashObjectList;const AName: String; ADirIndex, AIndex: Integer);
    begin
      inherited Create(AList,Aname);
      FDirIndex := ADirIndex;
      IndexNr := AIndex;
    end;


{****************************************************************************
                              TDebugInfoDwarf
****************************************************************************}

    procedure TDebugInfoDwarf.StartAbbrevSearch;
      begin
        CurrentSearchTreeItem:=AbbrevSearchTree;
      end;


    procedure TDebugInfoDwarf.WriteSearchItemToAbbrevSection(SI: PAbbrevSearchTreeItem);
      begin
        if SI^.bit8 then
          CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.Create_8bit(SI^.Value))
        else
          CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.Create_uleb128bit(SI^.Value));
      end;


    procedure TDebugInfoDwarf.StartAbbrevSectionFromSearchtree;

      procedure AddCurrentAndPriorItemsToAbrev(SI: PAbbrevSearchTreeItem);
        begin
          if Assigned(SI^.PriorItem) then
            AddCurrentAndPriorItemsToAbrev(SI^.PriorItem);
          WriteSearchItemToAbbrevSection(SI);
        end;

      begin
        NewAbbrev:=true;
        inc(currabbrevnumber);
        CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIComment.Create(StrPNew('Abbrev '+ToStr(currabbrevnumber))));
        CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.create_uleb128bit(currabbrevnumber));

        if CurrentSearchTreeItem<>AbbrevSearchTree then
          AddCurrentAndPriorItemsToAbrev(CurrentSearchTreeItem);
      end;


    function TDebugInfoDwarf.FinishAbbrevSearch: LongInt;

      procedure FinalizeAbbrevSection;
        begin
          CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.create_8bit(0));
          CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.create_8bit(0));
          CurrentSearchTreeItem^.Abbrev:=currabbrevnumber;
          NewAbbrev := false;
        end;

      begin
        if NewAbbrev then
          FinalizeAbbrevSection;
        result := CurrentSearchTreeItem^.Abbrev;
        if result=0 then
          begin
            // In this case the abbrev-section equals an existing longer abbrev section.
            // So a new abbrev-section has to be made which ends on the current
            // searchtree item
            StartAbbrevSectionFromSearchtree;
            FinalizeAbbrevSection;
            result := CurrentSearchTreeItem^.Abbrev;
          end;
      end;


    procedure TDebugInfoDwarf.AddConstToAbbrev(Value: QWord; bit8:boolean);

        procedure AddCurrentItemToAbbrev;
          begin
            CurrentSearchTreeItem^.Value:=value;
            CurrentSearchTreeItem^.bit8:=bit8;
            WriteSearchItemToAbbrevSection(CurrentSearchTreeItem);
          end;

      var si: PAbbrevSearchTreeItem;
      begin
        // Instead of adding this value directly to the ai-tree, search if an
        // abbrev section with the same values already exist, and use the existing
        // one or create one.
        if NewAbbrev then
          begin
          // The current abbrev-section is new, so add the value to the abbrev-section
          // and add it to the search-list.
          CurrentSearchTreeItem^.NextItem:=AllocateNewAiSearchItem;
          CurrentSearchTreeItem^.NextItem^.PriorItem:=CurrentSearchTreeItem;
          CurrentSearchTreeItem := CurrentSearchTreeItem^.NextItem;
          AddCurrentItemToAbbrev;
          end
        else
          begin
          // Search for the value which is added in the next sections of the
          // searchtree for a match
          si := CurrentSearchTreeItem^.NextItem;
          while Assigned(si) do
            begin
              if (SI^.Value=Value) and (si^.bit8=bit8) then
                begin
                // If a match is found, set the current searchtree item to the next item
                CurrentSearchTreeItem:=SI;
                Exit;
                end
              else if si^.SearchItem=nil then
                begin
                // If no match is found, add a new item to the searchtree and write
                // a new abbrev-section.
                StartAbbrevSectionFromSearchtree;

                si^.SearchItem:=AllocateNewAiSearchItem;
                if currentsearchtreeitem<>AbbrevSearchTree then
                  si^.SearchItem^.PriorItem:=CurrentSearchTreeItem;
                CurrentSearchTreeItem := si^.SearchItem;

                AddCurrentItemToAbbrev;
                Exit;
                end;
              Si := SI^.SearchItem;
            end;
          // The abbrev section we are looking for is longer than the one
          // which is already in the search-tree. So expand the searchtree with
          // the new value and write a new abbrev section
          StartAbbrevSectionFromSearchtree;

          CurrentSearchTreeItem^.NextItem:=AllocateNewAiSearchItem;
          if currentsearchtreeitem^.PriorItem<>AbbrevSearchTree then
            CurrentSearchTreeItem^.NextItem^.PriorItem:=CurrentSearchTreeItem;
          CurrentSearchTreeItem := CurrentSearchTreeItem^.NextItem;

          AddCurrentItemToAbbrev;
          end;
      end;


    function TDebugInfoDwarf.relative_dwarf_path(const s:TCmdStr):TCmdStr;
      begin
        { Make a clean path for gdb. Remove trailing / and ./ prefixes and
	      use always a / }
         result:=BSToSlash(ExcludeTrailingPathDelimiter(ExtractRelativePath(GetCurrentDir,FixFileName(ExpandFileName(s)))));
      end;


    procedure TDebugInfoDwarf.set_use_64bit_headers(state: boolean);
      begin
         _use_64bit_headers:=state;
         if not(state) then
           begin
             if (TargetInfo.system in systems_windows) then
               offsetabstype:=aitconst_secrel32_symbol
             else
               offsetabstype:=aitconst_32bit_unaligned;
             if (TargetInfo.system in systems_darwin) then
                offsetreltype:=aitconst_darwin_dwarf_delta32
              else
                offsetreltype:=aitconst_32bit_unaligned;
           end
         else
           begin
             if (TargetInfo.system in systems_darwin) then
                offsetreltype:=aitconst_darwin_dwarf_delta64
             else
               offsetreltype:=aitconst_64bit_unaligned;
             offsetabstype:=aitconst_64bit_unaligned;
           end;
      end;


    function TDebugInfoDwarf.get_def_dwarf_labs(def:TDef): PDwarfHashSetItem;
      var
        needstructdeflab: boolean;
      begin
        { Keep track of used dwarf entries, this info is only useful for dwarf entries
          referenced by the symbols. Definitions will always include all
          required debug entries }
        if def.DbgState=dbg_state_unused then
          def.DbgState:=dbg_state_used;
        { Need a new label? }
        result:=PDwarfHashSetItem(dwarflabels.FindOrAdd(@def,sizeof(def)));
        { the other fields besides  Data are not initialised }
        if not Assigned(result^.HashSetItem.Data) then
          begin
            { Mark as initialised }
            result^.HashSetItem.Data:=self;
            needstructdeflab:=Is_Implicit_Pointer_Object_Type(def);
            if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
              begin
                if (ds_dwarf_dbg_info_written in def.DefStates) then
                  begin
                    if not Assigned(def.TypeSym) then
                      InternalError(200610011);
                    result^.lab:=CurrentAsmData.RefAsmSymbol(Make_MangledName('DBG',def.TypeSym.owner,symname(def.TypeSym, true)),AT_METADATA);
                    result^.ref_lab:=CurrentAsmData.RefAsmSymbol(Make_MangledName('DBGREF',def.TypeSym.owner,symname(def.TypeSym, true)),AT_METADATA);
                    if needstructdeflab then
                      result^.struct_lab:=CurrentAsmData.RefAsmSymbol(Make_MangledName('DBG2',def.TypeSym.owner,symname(def.TypeSym, true)),AT_METADATA);
                    def.DbgState:=dbg_state_written;
                  end
                else
                  begin
                    { Create an exported DBG symbol if we are generating a def defined in the
                      globalsymtable of the current unit }
                    if Assigned(def.TypeSym) and
                       (def.owner.SymTableType=GlobalSymTable) and
                       (def.owner.IsCurrentUnit) then
                      begin
                        result^.lab:=CurrentAsmData.DefineAsmSymbol(Make_MangledName('DBG',def.TypeSym.owner,symname(def.TypeSym, true)),AB_GLOBAL,AT_METADATA,VoidPointerType);
                        result^.ref_lab:=CurrentAsmData.DefineAsmSymbol(Make_MangledName('DBGREF',def.TypeSym.owner,symname(def.TypeSym, true)),AB_GLOBAL,AT_METADATA,VoidPointerType);
                        if needstructdeflab then
                          result^.struct_lab:=CurrentAsmData.DefineAsmSymbol(Make_MangledName('DBG2',def.TypeSym.owner,symname(def.TypeSym, true)),AB_GLOBAL,AT_METADATA,VoidPointerType);
                        include(def.DefStates,ds_dwarf_dbg_info_written);
                      end
                    else
                      begin
                        { The pointer typecast is needed to prevent a problem with range checking
                          on when the typecast is changed to 'as' }
                        CurrentAsmData.getglobaldatalabel(TAsmLabel(pointer(result^.lab)));
                        CurrentAsmData.getglobaldatalabel(TAsmLabel(pointer(result^.ref_lab)));
                        if needstructdeflab then
                          CurrentAsmData.getglobaldatalabel(TAsmLabel(pointer(result^.struct_lab)));
                      end;
                  end;
              end
            else
              begin
                { The pointer typecast is needed to prevent a problem with range checking
                  on when the typecast is changed to 'as' }
                { addrlabel instead of datalabel because it must be a local one }
                CurrentAsmData.getaddrlabel(TAsmLabel(pointer(result^.lab)));
                CurrentAsmData.getaddrlabel(TAsmLabel(pointer(result^.ref_lab)));
                if needstructdeflab then
                  CurrentAsmData.getaddrlabel(TAsmLabel(pointer(result^.struct_lab)));
              end;
            if def.DbgState=dbg_state_used then
              deftowritelist.Add(def);
            defnumberlist.Add(def);
          end;
      end;

    function TDebugInfoDwarf.is_fbreg(reg: TRegister): boolean;
      begin
        { always return false, because we don't emit DW_AT_frame_base attributes yet }
        result:=false;
      end;

    function TDebugInfoDwarf.def_dwarf_lab(def: TDef): TAsmSymbol;
      begin
        result:=get_def_dwarf_labs(def)^.lab;
      end;

    function TDebugInfoDwarf.def_dwarf_class_struct_lab(def: TObjectDef): TAsmSymbol;
      begin
        result:=get_def_dwarf_labs(def)^.struct_lab;
      end;

    function TDebugInfoDwarf.def_dwarf_ref_lab(def: TDef): TAsmSymbol;
      begin
        result:=get_def_dwarf_labs(def)^.ref_lab;
      end;

    constructor TDebugInfoDwarf.Create;
      begin
        inherited Create;
        { 64bit headers are only supported for dwarf3 and up, so default off }
        use_64bit_headers := false;
        { we haven't generated any lineinfo yet }
        generated_lineinfo := false;

        dirlist := TFPHashObjectList.Create;
        { add current dir as first item (index=0) }
        TDirIndexItem.Create(dirlist,'.', 0);
        asmline := TAsmList.Create;
        loclist := TDynamicArray.Create(4096);

        AbbrevSearchTree:=AllocateNewAiSearchItem;

        vardatadef := nil;
        FWin64CUSectionKey:='';
        FWin64RangesStart:=nil;
        FWin64RangeIndex:=0;
      end;


    destructor TDebugInfoDwarf.Destroy;
      begin
        dirlist.Free;
        if Assigned(AbbrevSearchTree) then
          FreeSearchItem(AbbrevSearchTree);
        dirlist := nil;
        asmline.free;
        asmline:=nil;
        loclist.Free;
        loclist := nil;
        inherited Destroy;
      end;


    procedure TDebugInfoDwarf.enum_membersyms_callback(p:TObject; arg: pointer);
      begin
        case TSym(p).typ of
          FieldVarSym:
            appendsym_fieldvar(TAsmList(arg),TFieldVarSym(p));
          propertysym:
            appendsym_property(TAsmList(arg),TPropertySym(p));
          constsym:
            appendsym_const_member(TAsmList(arg),TConstSym(p),true);
          else
            ;
        end;
      end;


    function TDebugInfoDwarf.win64_proc_section(def:TProcDef):TAISection;
      var
        hp : TAI;
      begin
        hp:=def.ProcStartTAI;
        while Assigned(hp) do
          begin
            if hp.typ=ait_section then
              exit(TAISection(hp));
            hp:=TAI(hp.previous);
          end;
        InternalError(2026092302);
        result:=nil;
      end;


    procedure TDebugInfoDwarf.append_win64_proc_range(procsection:TAISection;
      procentrysym,procendlabel:TAsmSymbol;const sectionsuffix:string);
      var
        rangesection : TAISection;
      begin
        rangesection:=new_section(CurrentAsmData.asmlists[al_dwarf_ranges],
          sec_debug_ranges,FWin64CUSectionKey+'$'+sectionsuffix,0);
        rangesection.AssociativeSection:=procsection;
        CurrentAsmData.asmlists[al_dwarf_ranges].concat(
          TAIConst.create_type_sym(aitconst_ptr_unaligned,procentrysym));
        CurrentAsmData.asmlists[al_dwarf_ranges].concat(
          TAIConst.create_type_sym(aitconst_ptr_unaligned,procendlabel));
      end;


    procedure TDebugInfoDwarf.append_win64_proc_arange(procsection:TAISection;
      procentrysym,procendlabel:TAsmSymbol;const sectionsuffix:string);
      var
        arangelenstart,
        arangeend : TAsmLabel;
        arangesection : TAISection;
      begin
        arangesection:=new_section(CurrentAsmData.asmlists[al_dwarf_aranges],
          sec_debug_aranges,FWin64CUSectionKey+'$'+sectionsuffix,0);
        arangesection.AssociativeSection:=procsection;

        CurrentAsmData.getlabel(arangelenstart,alt_dbgfile);
        CurrentAsmData.getlabel(arangeend,alt_dbgfile);
        if use_64bit_headers then
          CurrentAsmData.asmlists[al_dwarf_aranges].concat(
            TAIConst.create_32bit_unaligned(LongInt($FFFFFFFF)));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(
          TAIConst.create_rel_sym(offsetreltype,arangelenstart,arangeend));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAILabel.Create(arangelenstart));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_16bit_unaligned(2));

        if not(tf_dwarf_relative_addresses in TargetInfo.flags) then
          CurrentAsmData.asmlists[al_dwarf_aranges].concat(
            TAIConst.create_type_sym(offsetabstype,
              CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_info0',AB_LOCAL,AT_METADATA,VoidPointerType)))
        else
          CurrentAsmData.asmlists[al_dwarf_aranges].concat(
            TAIConst.create_rel_sym(offsetreltype,
              CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_infosection0',AB_LOCAL,AT_METADATA,VoidPointerType),
              CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_info0',AB_LOCAL,AT_METADATA,VoidPointerType)));

        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_8bit(sizeof(PInt)));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_8bit(0));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_32bit_unaligned(0));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(
          TAIConst.create_type_sym(aitconst_ptr_unaligned,procentrysym));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(
          TAIConst.create_rel_sym(aitconst_ptr_unaligned,procentrysym,procendlabel));
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.Create_nil_codeptr_unaligned);
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.Create_nil_codeptr_unaligned);
        CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAILabel.Create(arangeend));
      end;


    function TDebugInfoDwarf.get_file_index(afile: TInputFile): Integer;
      var
        dirname: String;
        diritem: TDirIndexItem;
        diridx: Integer;
        fileitem: TFileIndexItem;
      begin
        if afile.path = '' then
          dirname := '.'
        else
          begin
            { add the canonical form here already to avoid problems with }
            { paths such as './' etc                                     }
            dirname := relative_dwarf_path(afile.path);
            if dirname = '' then
              dirname := '.';
          end;
        diritem := TDirIndexItem(dirlist.Find(dirname));
        if diritem = nil then
          diritem := TDirIndexItem.Create(dirlist,dirname, dirlist.Count);
        diridx := diritem.IndexNr;

        fileitem := TFileIndexItem(diritem.files.Find(afile.name));
        if fileitem = nil then
          begin
            Inc(filesequence);
            fileitem := TFileIndexItem.Create(diritem.files,afile.name, diridx, filesequence);
          end;
        Result := fileitem.IndexNr;
      end;


    procedure TDebugInfoDwarf.append_attribute(attr: TDwarfAttribute; form: TDwarfForm; const values: array of const);
      begin
        if length(values)<>1 then
          InternalError(2009040402);
        append_attribute(attr,form,values[0]);
      end;


    procedure TDebugInfoDwarf.append_attribute(attr: TDwarfAttribute; form: TDwarfForm; const value: tvarrec);
      begin
        { attribute }
        AddConstToAbbrev(cardinal(attr));

        { form }
        AddConstToAbbrev(cardinal(form));

        { info itself }
        case form of
          DW_FORM_string:
            case value.VType of
              vtChar:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIString.Create(value.VChar));
              vtString:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIString.Create(value.VString^));
              vtAnsistring:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIString.Create(AnsiString(value.VAnsiString)));
              else
                InternalError(200601264);
            end;

          DW_FORM_flag:
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(byte(value.VBoolean)));

          DW_FORM_data1:
             case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VQWord^));
              else
                InternalError(200602143);
            end;

          DW_FORM_data2:
             case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(value.VQWord^));
              else
                InternalError(200602144);
            end;

          DW_FORM_data4:
             case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(value.VQWord^));
              else
                InternalError(200602145);
            end;

          DW_FORM_data8:
             case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(value.VQWord^));
              else
                InternalError(200602146);
            end;

          DW_FORM_sdata:
            case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_sleb128bit(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_sleb128bit(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_sleb128bit(value.VQWord^));
              else
                InternalError(200601285);
            end;

          DW_FORM_udata:
            case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(value.VQWord^));
              else
                InternalError(200601284);
            end;

          { block gets only the size, the rest is appended manually by the caller }
          DW_FORM_block1:
             case value.VType of
              vtInteger:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VInteger));
              vtInt64:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VInt64^));
              vtQWord:
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(value.VQWord^));
              else
                InternalError(200602141);
            end;
          else
            InternalError(200601263);
        end;
      end;


    { writing the data through a few simply procedures allows to create easily extra information
      for debugging of debug info }
    procedure TDebugInfoDwarf.append_entry(tag : TDwarfTag;has_children : boolean;const data : array of const);
      var
        i : LongInt;
      begin
        { abbrev number }
        // Store the ai with the reference to the abbrev number and start a search
        // to find the right abbrev-section. (Or create one)
        dwarf_info_abbref_tai := TAIConst.create_uleb128bit(currabbrevnumber);
        CurrentAsmData.asmlists[al_dwarf_info].concat(dwarf_info_abbref_tai);
        StartAbbrevSearch;

        { tag }
        AddConstToAbbrev(ord(tag));

        { children? }
        AddConstToAbbrev(ord(has_children),true);

        i:=0;
        while i<=high(data) do
          begin
            if (i+2 > high(data)) then
              InternalError(2009040401);
            if data[i].VType<>vtInteger then
              InternalError(200601261);
            if data[i+1].VType<>vtInteger then
              InternalError(2006012602);
            append_attribute(TDwarfAttribute(data[i].VInteger),TDwarfForm(data[i+1].VInteger),data[i+2]);
            inc(i,3);
          end;
      end;


    procedure TDebugInfoDwarf.append_block1(attr: TDwarfAttribute; size: aint);
      begin
        AddConstToAbbrev(ord(attr));
        AddConstToAbbrev(ord(DW_FORM_block1));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(size));
      end;


    procedure TDebugInfoDwarf.append_labelentry(attr : TDwarfAttribute;sym : TAsmSymbol);
      begin
        AddConstToAbbrev(ord(attr));
        AddConstToAbbrev(ord(DW_FORM_addr));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_type_sym(aitconst_ptr_unaligned,sym));
      end;

    procedure TDebugInfoDwarf.append_labelentry_addr_ref(sym : TAsmSymbol);
      begin
        AddConstToAbbrev(ord(DW_FORM_ref_addr));

        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_type_sym(aitconst_ptr_unaligned,sym));

      end;

    procedure TDebugInfoDwarf.append_labelentry_ref(attr : TDwarfAttribute;sym : TAsmSymbol);
      begin
        AddConstToAbbrev(ord(attr));
        if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
          append_labelentry_addr_ref(sym)
        else
          begin
            if use_64bit_headers then
              AddConstToAbbrev(ord(DW_FORM_ref8))
            else
              AddConstToAbbrev(ord(DW_FORM_ref4));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_rel_sym(offsetreltype,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_info0',AB_LOCAL,AT_METADATA,VoidPointerType),sym));
          end;
      end;


    procedure TDebugInfoDwarf.append_labelentry_dataptr_common(attr : TDwarfAttribute);
      begin
        AddConstToAbbrev(ord(attr));
        if use_64bit_headers then
          AddConstToAbbrev(ord(DW_FORM_data8))
        else
          AddConstToAbbrev(ord(DW_FORM_data4));
      end;

    procedure TDebugInfoDwarf.append_pointerclass(list: TAsmList;
      def: TPointerDef);
      begin

        { Theoretically, we could do this, but it might upset some debuggers, }
        { even though it's part of the DWARF standard. }
        { append_attribute(DW_AT_address_class,DW_FORM_data1,[DW_ADDR_none]); }

      end;

    procedure TDebugInfoDwarf.append_proc_frame_base(list: TAsmList;
      def: TProcDef);
      begin
        { problem: base reg isn't known here
          DW_AT_frame_base,DW_FORM_block1,1
        }
      end;





    procedure TDebugInfoDwarf.append_labelentry_dataptr_abs(attr : TDwarfAttribute;sym : TAsmSymbol);
      begin
        {
          used for writing dwarf lineptr, loclistptr, macptr and rangelistptr classes as FORM_dataN
          The size of these depend on the header format
          Must be relative to another symbol on tf_dwarf_relative_addresses
          targets
        }
        if (tf_dwarf_relative_addresses in TargetInfo.flags) then
          { use append_labelentry_dataptr_rel instead }
          InternalError(2007020210);
        append_labelentry_dataptr_common(attr);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_type_sym(offsetabstype,sym))
      end;


    procedure TDebugInfoDwarf.append_labelentry_dataptr_rel(attr : TDwarfAttribute;sym,endsym : TAsmSymbol);
      begin
        {
          used for writing dwarf lineptr, loclistptr, macptr and rangelistptr classes as FORM_dataN
          The size of these depend on the header format
          Must be relative to another symbol on tf_dwarf_relative_addresses
          targets
        }
        append_labelentry_dataptr_common(attr);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_rel_sym(offsetreltype,sym,endsym));
      end;


    procedure TDebugInfoDwarf.finish_entry;
      begin
        dwarf_info_abbref_tai.Value:=FinishAbbrevSearch;
      end;


    procedure TDebugInfoDwarf.finish_children;
      begin
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(0));
      end;

    procedure TDebugInfoDwarf.appenddef_ord(list:TAsmList;def:TOrdDef);
      var
        BaseDef      : TDef;
        sign         : TDwarfType;
        signform     : TDwarfForm;
        fullbytesize : byte;
        OrdType      : TOrdType;
      begin
        OrdType:=def.OrdType;
        if OrdType=customint then
          OrdType:=Range_To_BaseType(def.low,def.high);
        case OrdType of
          s8bit,
          s16bit,
          s32bit,
          u8bit,
          u16bit,
          u32bit :
            begin
              { generate proper signed/unsigned info for types like 0..3 }
              { these are s8bit, but should be identified as unsigned    }
              { because otherwise they are interpreted wrongly when used }
              { in a bitpacked record                                    }
              if (def.low<0) then
                begin
                  sign:=DW_ATE_signed;
                  signform:=DW_FORM_sdata
                end
              else
                begin
                  sign:=DW_ATE_unsigned;
                  signform:=DW_FORM_udata
                end;
              fullbytesize:=def.Size;
              case fullbytesize of
                1:
                  if (sign=DW_ATE_signed) then
                    BaseDef:=S8IntType
                  else
                    BaseDef:=U8IntType;
                2:
                  if (sign=DW_ATE_signed) then
                    BaseDef:=S16IntType
                  else
                    BaseDef:=U16IntType;
                3,4:
                  if (sign=DW_ATE_signed) then
                    BaseDef:=S32IntType
                  else
                    BaseDef:=U32IntType;
                else
                  InternalError(2008032201);
              end;

              if (def.low=TOrdDef(BaseDef).low) and
                 (def.high=TOrdDef(BaseDef).high) then
                { base type such as byte/shortint/word/... }
                if Assigned(def.TypeSym) then
                  append_entry(DW_TAG_base_type,false,[
                    DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                    DW_AT_encoding,DW_FORM_data1,sign,
                    DW_AT_byte_size,DW_FORM_data1,fullbytesize])
                else
                  append_entry(DW_TAG_base_type,false,[
                    DW_AT_encoding,DW_FORM_data1,sign,
                    DW_AT_byte_size,DW_FORM_data1,fullbytesize])
              else
                begin
                  { subrange type }
                  { note: don't do this 64 bit int types, they appear    }
                  {       to be always clipped to s32bit for some reason }
                  if Assigned(def.TypeSym) then
                    append_entry(DW_TAG_subrange_type,false,[
                      DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                      DW_AT_lower_bound,signform,int64(def.low),
                      DW_AT_upper_bound,signform,int64(def.high)
                      ])
                  else
                    append_entry(DW_TAG_subrange_type,false,[
                      DW_AT_lower_bound,signform,int64(def.low),
                      DW_AT_upper_bound,signform,int64(def.high)
                      ]);
                  append_labelentry_ref(DW_AT_type,def_dwarf_lab(BaseDef));
                end;

              finish_entry;
            end;
          uvoid :
            begin
              { gdb 6.4 doesn't support DW_TAG_unspecified_type so we
                replace it with a unsigned type with size 0 (FK)
              }
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Void'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
                DW_AT_byte_size,DW_FORM_data1,0
              ]);
              finish_entry;
            end;
          uchar :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Char'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned_char,
                DW_AT_byte_size,DW_FORM_data1,1
                ]);
              finish_entry;
            end;
          uwidechar :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'WideChar'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned_char,
                DW_AT_byte_size,DW_FORM_data1,2
                ]);
              finish_entry;
            end;
          pasbool1 :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Boolean'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,1
                ]);
              finish_entry;
            end;
          pasbool8 :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Boolean8'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,1
                ]);
              finish_entry;
            end;
          bool8bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'ByteBool'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,1
                ]);
              finish_entry;
            end;
          pasbool16 :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Boolean16'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,2
                ]);
              finish_entry;
            end;
          bool16bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'WordBool'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,2
                ]);
              finish_entry;
            end;
          pasbool32 :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Boolean32'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,4
                ]);
              finish_entry;
            end;
          bool32bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'LongBool'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,4
                ]);
              finish_entry;
            end;
          pasbool64 :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Boolean64'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
              finish_entry;
            end;
          bool64bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'QWordBool'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_boolean,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
              finish_entry;
            end;
          u64bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'QWord'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
              finish_entry;
            end;
          scurrency :
            begin
              { we should use DW_ATE_signed_fixed, however it isn't supported yet by GDB (FK) }
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Currency'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
              finish_entry;
            end;
          s64bit :
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Int64'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
              finish_entry;
            end;
          u128bit:
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Int128'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
                DW_AT_byte_size,DW_FORM_data1,16
                ]);
              finish_entry;
            end;
          s128bit:
            begin
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,'Int128'#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,16
                ]);
              finish_entry;
            end;
          else
            InternalError(200601287);
        end;
      end;

    procedure TDebugInfoDwarf.appenddef_float(list:TAsmList;def:TFloatDef);
      begin
        case def.FloatType of
          S32Real,
          S64Real,
          s80real,
          sc80real:
            if Assigned(def.TypeSym) then
              begin
                append_entry(DW_TAG_base_type,false,[
                  DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                  DW_AT_encoding,DW_FORM_data1,DW_ATE_float,
                  DW_AT_byte_size,DW_FORM_data1,def.Size
                  ]);
                if (def.FloatType in [s80real,sc80real]) and
                   (def.Size<>10) then
                  begin
                    append_attribute(DW_AT_bit_size,DW_FORM_data1,[10*8]);
                    { "The bit offset attribute describes the offset in bits
                        of the high order bit of a value of the given type
                        from the high order bit of the storage unit used to
                        contain that value." }
                    append_attribute(DW_AT_bit_offset,DW_FORM_data1,[(def.Size-10)*8]);
                  end;
              end
            else
              append_entry(DW_TAG_base_type,false,[
                DW_AT_encoding,DW_FORM_data1,DW_ATE_float,
                DW_AT_byte_size,DW_FORM_data1,def.Size
                ]);
          s64currency:
            { we should use DW_ATE_signed_fixed, however it isn't supported yet by GDB (FK) }
            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ])
            else
              append_entry(DW_TAG_base_type,false,[
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
          s64comp:
            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ])
            else
              append_entry(DW_TAG_base_type,false,[
                DW_AT_encoding,DW_FORM_data1,DW_ATE_signed,
                DW_AT_byte_size,DW_FORM_data1,8
                ]);
        end;
        finish_entry;
      end;


    procedure TDebugInfoDwarf.appenddef_enum(list:TAsmList;def:TEnumDef);
      var
        hp : TEnumSym;
        i  : integer;
        entryform,
        valueform : TDwarfForm;
      begin
        if Assigned(def.TypeSym) then
          append_entry(DW_TAG_enumeration_type,true,[
            DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
            DW_AT_byte_size,DW_FORM_data1,def.Size
            ])
        else
          append_entry(DW_TAG_enumeration_type,true,[
            DW_AT_byte_size,DW_FORM_data1,def.Size
            ]);
        if Assigned(def.BaseDef) then
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.BaseDef))
        else
          case def.Size of
            1:
               if def.min<0 then
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(S8IntType))
               else
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(U8IntType));
            2:
               if def.min<0 then
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(S16IntType))
               else
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(U16IntType));
            4:
               if def.min<0 then
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(S32IntType))
               else
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(U32IntType));
            8:
               if def.min<0 then
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(S64IntType))
               else
                 append_labelentry_ref(DW_AT_type,def_dwarf_lab(U64IntType));
            else
              InternalError(2025041701);
          end;

        finish_entry;

        case def.Size of
          1:
             entryform:=DW_FORM_data1;
          2:
             entryform:=DW_FORM_data2;
          4:
             entryform:=DW_FORM_data4;
          8:
             entryform:=DW_FORM_data8;
        else
          InternalError(2025041601);
        end;

        { write enum symbols }
        for i := 0 to def.SymTable.SymList.Count - 1 do
          begin
            hp:=TEnumSym(def.SymTable.SymList[i]);
            if hp.Value<def.MinVal then
              continue
            else
            if hp.Value>def.MaxVal then
              break;
            if hp.Value<0 then
              valueform:=DW_FORM_sdata
            else
              valueform:=entryform;
            append_entry(DW_TAG_enumerator,false,[
              DW_AT_name,DW_FORM_string,symname(hp, false)+#0,
              DW_AT_const_value,valueform,hp.Value
            ]);
            finish_entry;
          end;

        finish_children;
      end;


    procedure TDebugInfoDwarf.appenddef_array(list:TAsmList;def:TArrayDef);
      var
        size : PInt;
        EleSize : PInt;
        elestrideattr : TDwarfAttribute;
        LabSym: TAsmLabel;
      begin
        if Is_Dynamic_Array(def) then
          begin
            { It's a pointer to the actual array }
            CurrentAsmData.getaddrlabel(LabSym);
            append_entry(DW_TAG_pointer_type,false,[]);
            append_labelentry_ref(DW_AT_type,LabSym);
            finish_entry;
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(LabSym,0));
          end;

        if not Is_Packed_Array(def) then
          begin
            elestrideattr:=DW_AT_byte_stride;
            EleSize:=def.EleSize;
          end
        else
          begin
            elestrideattr:=DW_AT_stride_size;
            EleSize:=def.ElePackedBitSize;
          end;

        if Is_Special_Array(def) then
          begin
            { no known size, no known upper bound }
            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_array_type,true,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                elestrideattr,DW_FORM_udata,EleSize
                ])
            else
              append_entry(DW_TAG_array_type,true,[
              elestrideattr,DW_FORM_udata,EleSize
              ]);
            append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ElementDef));
            finish_entry;
            { a missing upper bound means "unknown"/default }
            append_entry(DW_TAG_subrange_type,false,[
              DW_AT_lower_bound,DW_FORM_sdata,def.LowRange
              ]);
          end
        else
          begin
            size:=def.Size;
            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_array_type,true,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                DW_AT_byte_size,DW_FORM_udata,size,
                elestrideattr,DW_FORM_udata,EleSize
                ])
            else
              append_entry(DW_TAG_array_type,true,[
                DW_AT_byte_size,DW_FORM_udata,size,
                elestrideattr,DW_FORM_udata,EleSize
                ]);
            append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ElementDef));
            finish_entry;
            { to simplify things, we don't write a multidimensional array here }
            append_entry(DW_TAG_subrange_type,false,[
              DW_AT_lower_bound,DW_FORM_sdata,def.LowRange,
              DW_AT_upper_bound,DW_FORM_sdata,def.HighRange
              ]);
          end;
        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.RangeDef));
        finish_entry;
        finish_children;
      end;


    procedure TDebugInfoDwarf.appenddef_record(list:TAsmList;def:TRecordDef);
      begin
        if Assigned(def.ObjName) then
          appenddef_record_named(list,def,def.ObjName^)
        else
          appenddef_record_named(list,def,'');
      end;


    procedure TDebugInfoDwarf.appenddef_record_named(list:TAsmList;def:TRecordDef;const name: shortstring);
      begin
        if (name<>'') then
          append_entry(DW_TAG_structure_type,true,[
            DW_AT_name,DW_FORM_string,name+#0,
            DW_AT_byte_size,DW_FORM_udata,def.Size
            ])
        else
          append_entry(DW_TAG_structure_type,true,[
            DW_AT_byte_size,DW_FORM_udata,def.Size
            ]);
        finish_entry;
        def.SymTable.SymList.ForEachCall(@enum_membersyms_callback,nil);
        { don't know whether external record declaration is allow but if it so then
          do the same as we do for other object types - skip procdef info generation
          for external defs (Paul Ishenin) }
        if not(oo_is_external in def.ObjectOptions) then
          write_symtable_procdefs(CurrentAsmData.asmlists[al_dwarf_info],def.SymTable);
        finish_children;
      end;


    procedure TDebugInfoDwarf.appenddef_pointer(list:TAsmList;def:TPointerDef);
      begin
        append_entry(DW_TAG_pointer_type,false,[]);
        append_pointerclass(list,def);
        if not(Is_VoidPointer(def)) then
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.PointedDef));
        finish_entry;
      end;


    procedure TDebugInfoDwarf.appenddef_string(list:TAsmList;def:TStringDef);

      procedure addnormalstringdef(const name: shortstring; lendef: TDef; maxlen: ASizeUInt);
        var
          { maxlen can be > high(int64) }
          slen : ASizeUInt;
          arr : TAsmLabel;
        begin
{$push}
{$R-}{$Q-}
          { fix length of openshortstring }
          slen:=aword(def.len);
          if (slen=0) or
             (slen>maxlen) then
            slen:=maxlen;
{$pop}
          { create a structure with two elements }
          if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
            CurrentAsmData.getglobaldatalabel(arr)
          else
            CurrentAsmData.getaddrlabel(arr);
          append_entry(DW_TAG_structure_type,true,[
            DW_AT_name,DW_FORM_string,name+#0,
            DW_AT_byte_size,DW_FORM_udata,qword(lendef.Size)+slen
            ]);
          finish_entry;

          { length entry }
          append_entry(DW_TAG_member,false,[
            DW_AT_name,DW_FORM_string,'length'#0,
            DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(0)
            ]);
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(0));
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(lendef));
          finish_entry;

          { string data entry }
          append_entry(DW_TAG_member,false,[
            DW_AT_name,DW_FORM_string,'st'#0,
            DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(1)
            ]);
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(lendef.Size));
          append_labelentry_ref(DW_AT_type,arr);
          finish_entry;

          finish_children;

          { now the data array }
          if arr.bind=AB_GLOBAL then
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(arr,0))
          else
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(arr,0));
          append_entry(DW_TAG_array_type,true,[
            DW_AT_byte_size,DW_FORM_udata,def.Size,
            DW_AT_byte_stride,DW_FORM_udata,1
            ]);
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(CAnsiCharType));
          finish_entry;
          append_entry(DW_TAG_subrange_type,false,[
            DW_AT_lower_bound,DW_FORM_udata,1,
            DW_AT_upper_bound,DW_FORM_udata,qword(slen)
            ]);
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(lendef));
          finish_entry;
          finish_children;
        end;

      begin
        case def.StringType of
          st_shortstring:
            begin
              addnormalstringdef('ShortString',U8IntType,255);
            end;
          st_longstring:
            begin
              { a) we don't actually support variables of this type currently
                b) this type is only used as the type for constant strings
                   > 255 characters
                c) in such a case, gdb will allocate and initialise enough
                   memory to hold the maximum size for such a string
                -> don't use high(qword)/high(cardinal) as maximum, since that
                 will cause exhausting the VM space, but some "reasonably high"
                 number that should be enough for most constant strings
              }
{$ifdef cpu64bitaddr}
              addnormalstringdef('LongString',U64IntType,qword(1024*1024));
{$endif cpu64bitaddr}
{$ifdef cpu32bitaddr}
              addnormalstringdef('LongString',U32IntType,cardinal(1024*1024));
{$endif cpu32bitaddr}

           end;
         st_ansistring:
           begin
             { looks like a pchar }
             append_entry(DW_TAG_pointer_type,false,[]);
             append_labelentry_ref(DW_AT_type,def_dwarf_lab(CAnsiCharType));
             finish_entry;
           end;
         st_unicodestring,
         st_widestring:
           begin
             { looks like a pwidechar }
             append_entry(DW_TAG_pointer_type,false,[]);
             append_labelentry_ref(DW_AT_type,def_dwarf_lab(CWideCharType));
             finish_entry;
           end;
        end;
      end;

    procedure TDebugInfoDwarf.appenddef_procvar(list:TAsmList;def:TProcVarDef);

      procedure doappend;
        var
          i : LongInt;
        begin
          if Assigned(def.TypeSym) then
            append_entry(DW_TAG_subroutine_type,true,[
              DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
              DW_AT_prototyped,DW_FORM_flag,true
            ])
          else
            append_entry(DW_TAG_subroutine_type,true,[
              DW_AT_prototyped,DW_FORM_flag,true
            ]);
          if not(Is_Void(TProcVarDef(def).ReturnDef)) then
            append_labelentry_ref(DW_AT_type,def_dwarf_lab(TProcVarDef(def).ReturnDef));
          finish_entry;

          { write parameters }
          for i:=0 to def.paras.count-1 do
            begin
              append_entry(DW_TAG_formal_parameter,false,[
                DW_AT_name,DW_FORM_string,symname(TSym(def.paras[i]), false)+#0
              ]);
              append_labelentry_ref(DW_AT_type,def_dwarf_lab(TParaVarSym(def.paras[i]).vardef));
              finish_entry;
            end;

          finish_children;
        end;

      var
        proc : TAsmLabel;

      begin
        if not def.Is_AddressOnly then
          begin
            { create a structure with two elements }
            if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
              CurrentAsmData.getglobaldatalabel(proc)
            else
              CurrentAsmData.getaddrlabel(proc);
            append_entry(DW_TAG_structure_type,true,[
              DW_AT_byte_size,DW_FORM_data1,2*sizeof(PInt)
            ]);
            finish_entry;

            { proc entry }
            append_entry(DW_TAG_member,false,[
              DW_AT_name,DW_FORM_string,'Proc'#0,
              DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(0)
              ]);
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(0));
            append_labelentry_ref(DW_AT_type,proc);
            finish_entry;

            { self entry }
            append_entry(DW_TAG_member,false,[
              DW_AT_name,DW_FORM_string,'Self'#0,
              DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(sizeof(PInt))
              ]);
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(sizeof(PInt)));
            append_labelentry_ref(DW_AT_type,def_dwarf_lab(Class_TObject));
            finish_entry;

            finish_children;

            if proc.bind=AB_GLOBAL then
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(proc,0))
            else
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(proc,0));
            doappend;
          end
        else
          doappend;
      end;


    procedure TDebugInfoDwarf.beforeappenddef(list:TAsmList;def:TDef);
      var
        LabSym : TAsmSymbol;
      begin
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIComment.Create(StrPNew('Definition '+def.TypeName)));

        LabSym:=def_dwarf_lab(def);
        case LabSym.bind of
          AB_GLOBAL:
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(LabSym,0));
          AB_LOCAL:
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(LabSym,0));
          else
            InternalError(2013082001);
        end;

        { On Darwin, dwarf info is not linked in the final binary,
          but kept in the individual object files. This allows for
          faster linking, but means that you have to keep the object
          files for debugging and also that gdb only loads in the
          debug info of a particular object file once you step into
          or over a procedure in it.

          To solve this, there is a tool called dsymutil which can
          extract all the dwarf info from a program's object files.
          This utility however performs "smart linking" on the dwarf
          info and throws away all unreferenced dwarf entries. Since
          variables' types always point to the dwarfinfo for a tdef
          and never to that for a typesym, this means all debug
          entries generated for typesyms are thrown away.

          The problem with that is that we translate typesyms into
          DW_TAG_typedef, and gdb's dwarf-2 reader only makes types
          globally visibly if they are defined using a DW_TAG_typedef.
          So as a result, before running dsymutil types only become
          available once you stepped into/over a function in the object
          file where they are declared, and after running dsymutil they
          are all gone (printing variables still works because the
          tdef dwarf info is still available, but you cannot typecast
          anything outside the declaring units because the type names
          are not known there).

          The solution: if a tdef has an associated typesym, let the
          debug label for the tdef point to a DW_TAG_typedef instead
          of directly to the tdef itself. And don't write anything
          special for the typesym itself.

          Update: we now also do this for other platforms, because
          otherwise if you compile unit A without debug info and
          use one of its types in unit B, then no typedef will be
          generated and hence gdb will not be able to give a definition
          of the type.
        }

        if Is_ObjC_Class_Or_Protocol(def) then
          begin
            { for Objective-C classes, the typedef must refer to the
              struct itself, not to the pointer of the struct; Objective-C
              classes are not implicit pointers in Objective-C itself, only
              in FPC. So make the def label point to a pointer to the
              typedef, which in turn refers to the actual struct (for Delphi-
              style classes, the def points to the typedef, which refers to
              a pointer to the actual struct) }

            { implicit pointer }
            CurrentAsmData.getaddrlabel(TAsmLabel(pointer(LabSym)));
            append_entry(DW_TAG_pointer_type,false,[]);
            append_labelentry_ref(DW_AT_type,LabSym);
            finish_entry;
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(LabSym,0));
          end;

        if Assigned(def.TypeSym) and
           not(df_generic in def.DefOptions) then
          begin
            CurrentAsmData.getaddrlabel(TAsmLabel(pointer(LabSym)));
            append_entry(DW_TAG_typedef,false,[
              DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0
            ]);
            { if def.typesym.Owner.symtabletype=globalsymtable then
              append_attribute(DW_AT_external,DW_FORM_flag,[true]); }
            append_labelentry_ref(DW_AT_type,LabSym);
            finish_entry;
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(LabSym,0));
          end
      end;


    procedure TDebugInfoDwarf.afterappenddef(list:TAsmList;def:TDef);
      var
        LabSym : TAsmSymbol;
      begin
        { end of the symbol }
        LabSym:=def_dwarf_lab(def);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbolEnd.Create(LabSym));
        { create a derived reference type for pass-by-reference parameters }
        { (gdb doesn't support DW_AT_variable_parameter yet)               }
        LabSym:=def_dwarf_ref_lab(def);
        case LabSym.bind of
          AB_GLOBAL:
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(LabSym,0));
          AB_LOCAL:
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(LabSym,0));
          else
            InternalError(2013082002);
        end;
        append_entry(DW_TAG_reference_type,false,[]);
        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def));
        finish_entry;
      end;


    procedure TDebugInfoDwarf.appendprocdef(list:TAsmList; def:TProcDef);

      function dwarf_calling_convention(def: TProcDef): TDwarfCallingConvention;
        begin
          case def.ProcCallOption of
{$ifdef i386}
            pocall_register:
              result:=DW_CC_GNU_borland_fastcall_i386;
{$else i386}
            pocall_register,
{$endif i386}
            pocall_cdecl,
            pocall_stdcall,
            pocall_cppdecl,
            pocall_mwpascal:
              result:=DW_CC_normal;
            else
              result:=DW_CC_nocall;
          end
        end;

      var
        procendlabel   : TAsmLabel;
        procentrysym   : TAsmSymbol;
        procsection    : TAISection;
        procentry,s    : string;
        sectionsuffix  : string;
        cc             : TDwarfCallingConvention;
        st             : TSymTable;
        vmtoffset      : PInt;
        In_CurrentUnit : boolean;
      begin
        { only write debug info for procedures defined in the current module,
          except in case of methods (gcc-compatible)
        }
        In_CurrentUnit:=def.In_CurrentUnit;

        if not In_CurrentUnit and
          not (def.owner.SymTableType in [objectsymtable,recordsymtable]) then
          exit;

        { happens for init procdef of units without init section }
        if In_CurrentUnit and
           not Assigned(def.ProcStartTAI) then
          exit;

        if df_generic in def.DefOptions then
          exit;

        { Procdefs are not handled by the regular def writing code, so
          dbg_state is not set/checked for them. Do it here.  }
        if (def.DbgState in [dbg_state_writing,dbg_state_written]) then
          exit;
        defnumberlist.Add(def);

        { Write methods and only in the scope of their parent objectdefs.  }
        if (def.owner.SymTableType in [objectsymtable,recordsymtable]) then
          begin
            { this code can also work for nested procdefs, but is not yet
              activated for those because there is no clear advantage yet to
              limiting the scope of nested procedures to that of their parent,
              and it makes it impossible to set breakpoints in them by
              referring to their name.  }
            st:=def.owner;
            while Assigned(st.DefOwner) and
                  (TDef(st.DefOwner).typ = procdef) do
              st:=TProcDef(st.DefOwner).owner;
            if Assigned(st) and
               (TDef(st.DefOwner).DbgState<>dbg_state_writing) then
              exit;
         end;

        def.DbgState:=dbg_state_writing;

        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIComment.Create(StrPNew('Procdef '+def.FullProcName(true))));
        if not Is_ObjC_Class_Or_Protocol(def.struct) then
          append_entry(DW_TAG_subprogram,true,
            [DW_AT_name,DW_FORM_string,symname(def.ProcSym, false)+#0])
        else
          append_entry(DW_TAG_subprogram,true,
            [DW_AT_name,DW_FORM_string,def.MangledName+#0]);

        if (ds_dwarf_cpp in CurrentSettings.DebugSwitches) and (def.owner.SymTableType in [objectsymtable,recordsymtable]) then
          begin
            { If C++ emulation is enabled, add DW_AT_linkage_name attribute for methods.
              LLDB uses it to display fully qualified method names.
              Add a simple C++ mangled name without params to achieve at least "Class::Method()"
              instead of just "Method" in LLDB. }
            s:=TAbstractRecordDef(def.owner.DefOwner).ObjRealName^;
            procentry:=Format('_ZN%d%s', [Length(s), s]);
            s:=symname(def.ProcSym, false);
            procentry:=Format('%s%d%sEv'#0, [procentry, Length(s), s]);
            append_attribute(DW_AT_linkage_name,DW_FORM_string, [procentry]);
          end;

        append_proc_frame_base(list,def);

        { Append optional flags. }

        { All Pascal procedures are prototyped }
        append_attribute(DW_AT_prototyped,DW_FORM_flag,[true]);
        { Calling convention.  }
        cc:=dwarf_calling_convention(def);
        if (cc<>DW_CC_normal) then
          append_attribute(DW_AT_calling_convention,DW_FORM_data1,[ord(cc)]);

        { Externally visible.  }
        if (po_global in def.ProcOptions) and
           (def.ParaST.SymTableLevel<=NormalFunctionLevel) then
          append_attribute(DW_AT_external,DW_FORM_flag,[true]);
        { Abstract or virtual/overriding method.  }
        if (([po_abstractmethod, po_virtualmethod, po_overridingmethod] * def.ProcOptions) <> []) and
           not Is_ObjC_Class_Or_Protocol(def.struct) and
           not Is_ObjectPascal_Helper(def.struct) then
          begin
            if not(po_abstractmethod in def.ProcOptions) then
              append_attribute(DW_AT_virtuality,DW_FORM_data1,[ord(DW_VIRTUALITY_virtual)])
            else
              append_attribute(DW_AT_virtuality,DW_FORM_data1,[ord(DW_VIRTUALITY_pure_virtual)]);
            { Element number in the vmt (needs to skip stuff coming before the
              actual method addresses in the vmt, so we use vmtmethodoffset()
              and then divide by sizeof(pint)).  }
            vmtoffset:=TObjectDef(def.owner.DefOwner).VMTMethodOffset(def.ExtNumber);
            append_attribute(DW_AT_vtable_elem_location,DW_FORM_block1,[3+LengthULEB128(vmtoffset)]);
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_constu)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.Create_uleb128bit(vmtoffset));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus)));
          end;

        { accessibility: public/private/protected }
        if (def.owner.SymTableType in [objectsymtable,recordsymtable]) then
          append_visibility(def.visibility);

        { Return type.  }
        if not(Is_Void(TProcDef(def).ReturnDef)) then
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(TProcDef(def).ReturnDef));

        { we can only write the start/end if this procedure is implemented in
          this module
        }
        if In_CurrentUnit then
          begin
            { mark end of procedure }
            CurrentAsmData.getlabel(procendlabel,alt_dbgtype);
            CurrentAsmData.asmlists[al_procedures].insertbefore(TAILabel.Create(procendlabel),def.ProcEndTAI);

            procentry := def.MangledName;


            procentrysym:=CurrentAsmData.RefAsmSymbol(procentry,AT_FUNCTION);
            append_labelentry(DW_AT_low_pc,procentrysym);
            append_labelentry(DW_AT_high_pc,procendlabel);

            if TargetInfo.system in systems_windows then
              begin
                procsection:=win64_proc_section(def);
                inc(FWin64RangeIndex);
                sectionsuffix:='M_'+HexStr(FWin64RangeIndex,8);
                append_win64_proc_range(procsection,procentrysym,procendlabel,sectionsuffix);
                append_win64_proc_arange(procsection,procentrysym,procendlabel,sectionsuffix);
              end
            else if not(TargetInfo.system in systems_darwin) then
              begin
                CurrentAsmData.asmlists[al_dwarf_aranges].Concat(
                  TAIConst.create_type_sym(aitconst_ptr_unaligned,procentrysym));

                CurrentAsmData.asmlists[al_dwarf_aranges].Concat(
                  TAIConst.Create_rel_sym(aitconst_ptr_unaligned,procentrysym,procendlabel));

              end;
          end;

        { Don't write the funcretsym explicitly, it's also in the
          localsymtable and/or parasymtable.
        }
        finish_entry;

        if Assigned(def.ParaST) then
          begin
            { First insert self, because gdb uses the fact whether or not the
              first parameter of a method is artificial to distinguish static
              from regular methods.  }

            { fortunately, self is the always the first parameter in the
              paralist, since it has the lowest paranr. Note that this is not
              true for Objective-C, but those methods are detected in
              another way (by reading the ObjC run time information)  }
            write_symtable_parasyms(CurrentAsmData.asmlists[al_dwarf_info],def.paras);
          end;
        { local type defs and vars should not be written
          inside the main proc }
        if In_CurrentUnit and
           Assigned(def.LocalST) and
           (def.LocalST.SymTableType=LocalSymTable) then
          write_symtable_syms(CurrentAsmData.asmlists[al_dwarf_info],def.LocalST);

        { last write the types from this procdef }
        if Assigned(def.ParaST) then
          write_symtable_defs(CurrentAsmData.asmlists[al_dwarf_info],def.ParaST);
        { only try to write the localst if the routine is implemented here }
        if In_CurrentUnit and
           Assigned(def.LocalST) and
           (def.LocalST.SymTableType=LocalSymTable) then
          begin
            write_symtable_defs(CurrentAsmData.asmlists[al_dwarf_info],def.LocalST);
            { Write nested procedures -- disabled, see scope check at the
              beginning; currently, these are still written in the global
              scope.  }
            // write_symtable_procdefs(current_asmdata.asmlists[al_dwarf_info],def.localst);
          end;

        finish_children;
      end;


    function TDebugInfoDwarf.get_symlist_sym_offset(SymList: PPropAccessListItem; out sym: TAbstractVarSym; out offset: PInt): boolean;
      var
        EleSize : PInt;
        currdef : TDef;
        indirection: boolean;
      begin
        result:=false;
        if not Assigned(SymList) then
          exit;
        sym:=nil;
        offset:=0;
        currdef:=nil;
        indirection:=false;
        repeat
          case SymList^.SLType of
            sl_load:
              begin
                if Assigned(sym) then
                  InternalError(2009031203);
                if not(SymList^.sym.typ in [paravarsym,localvarsym,staticvarsym,FieldVarSym]) then
                  { can't handle... }
                  exit;
                sym:=TAbstractVarSym(SymList^.sym);
                currdef:=TAbstractVarSym(sym).vardef;
                if ((sym.typ=paravarsym) and
                    ParaManager.Push_Addr_Param(TParaVarSym(sym).VarSpez,sym.vardef,TProcDef(sym.owner.DefOwner).ProcCallOption)) then
                  indirection:=true;
              end;
            sl_subscript:
              begin
                if not Assigned(currdef) then
                  InternalError(2009031301);
                if (SymList^.sym.typ<>FieldVarSym) then
                  InternalError(2009031202);
                { can't handle offsets with indirections yet }
                if indirection then
                  exit;
                if Is_Packed_Record_Or_Object(currdef) then
                  begin
                    { can't calculate the address of a non-byte aligned field }
                    if (TFieldVarSym(SymList^.sym).FieldOffset mod 8) <> 0 then
                      exit;
                    inc(offset,TFieldVarSym(SymList^.sym).FieldOffset div 8)
                  end
                else
                  inc(offset,TFieldVarSym(SymList^.sym).FieldOffset);
                currdef:=TFieldVarSym(SymList^.sym).vardef;
              end;
            sl_absolutetype,
            sl_typeconv:
              begin
                currdef:=SymList^.def;
                { ignore, these don't change the address }
              end;
            sl_vec:
              begin
                if not Assigned(currdef) then
                  InternalError(2009031201);
                { can't handle offsets with indirections yet }
                if indirection then
                  exit;
                case currdef.typ of
                  arraydef:
                    begin
                      if not Is_Packed_Array(currdef) then
                        EleSize:=TArrayDef(currdef).EleSize
                      else
                        begin
                          EleSize:=TArrayDef(currdef).ElePackedBitSize;
                          { can't calculate the address of a non-byte aligned element }
                          if (EleSize mod 8)<>0 then
                            exit;
                          EleSize:=EleSize div 8;
                        end;
                      inc(offset,(SymList^.Value.svalue-TArrayDef(currdef).LowRange)*EleSize);
                      currdef:=TArrayDef(currdef).ElementDef;
                    end;
                  stringdef:
                    begin
                      case TStringDef(currdef).StringType of
                        st_widestring,st_unicodestring:
                          begin
                            inc(offset,(SymList^.Value.svalue-1)*2);
                            currdef:=CWideCharType;
                          end;
                        st_shortstring:
                          begin
                            inc(offset,SymList^.Value.svalue);
                            currdef:=CAnsiCharType;
                          end;
                        st_ansistring:
                          begin
                            inc(offset,SymList^.Value.svalue-1);
                            currdef:=CAnsiCharType;
                          end;
                        else
                          InternalError(2022070502);
                      end;
                    end;
                  else
                    InternalError(2022070501);
                end;
              end;
            else
              InternalError(2009031403);
          end;
          SymList:=SymList^.next;
        until not Assigned(SymList);
        if not Assigned(sym) then
          InternalError(2009031205);
        result:=true;
      end;


    procedure TDebugInfoDwarf.appendsym_var(list:TAsmList;sym:TAbstractNormalVarSym);
      begin
        appendsym_var_with_name_type_offset(list,sym,symname(sym, false),sym.vardef,0,[]);
      end;


    procedure TDebugInfoDwarf.appendsym_var_with_name_type_offset(list:TAsmList; sym:TAbstractNormalVarSym; const name: string; def: TDef; offset: PInt; const flags: TDwarfVarSymFlags);
      var
        TempList : TAsmList;
        blocksize,size_of_int : LongInt;
        tag : TDwarfTag;
        has_high_reg : boolean;
        dreg,dreghigh : shortint;

      begin
        blocksize:=0;
        dreghigh:=0;
        { external symbols can't be resolved at link time, so we
          omit their debug locations
        }
        if vo_is_external in sym.VarOptions then
          exit;

        { There is no space allocated for not referenced locals }
        if (sym.owner.SymTableType=LocalSymTable) and (sym.refs=0) then
          exit;

        TempList:=TAsmList.Create;

        case sym.LocAlloc.Loc of
          LOC_REGISTER,
          LOC_CREGISTER,
          LOC_MMREGISTER,
          LOC_CMMREGISTER,
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER :
            begin
              { dwarf_reg_no_error might return -1
                in case the register variable has been optimized out }
              dreg:=dwarf_reg_no_error(sym.LocAlloc.Register);
              has_high_reg:=(sym.LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER]) and (sym.LocAlloc.RegisterHi<>NR_NO);
              if has_high_reg then
                dreghigh:=dwarf_reg_no_error(sym.LocAlloc.RegisterHi);
              if dreghigh=-1 then
                has_high_reg:=false;
              if (sym.LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
                 (sym.typ=paravarsym) and
                  ParaManager.Push_Addr_Param(sym.VarSpez,sym.vardef,TProcDef(sym.owner.DefOwner).ProcCallOption) and
                  not(vo_has_local_copy in sym.VarOptions) and
                  not Is_Open_String(sym.vardef) and (dreg>=0) then
                begin
                  TempList.concat(TAIConst.create_8bit(ord(DW_OP_bregx)));
                  TempList.concat(TAIConst.create_uleb128bit(dreg));
                  TempList.concat(TAIConst.create_sleb128bit(0));
                  blocksize:=1+LengthULEB128(dreg)+LengthSLEB128(0);
                end
              else
                begin
                  if has_high_reg then
                    begin
                      TempList.concat(TAIComment.Create(StrPNew('high:low reg pair variable')));
                      size_of_int:=sizeof(aint);
                      TempList.concat(TAIConst.create_8bit(ord(DW_OP_regx)));
                      TempList.concat(TAIConst.create_uleb128bit(dreg));
                      blocksize:=1+LengthULEB128(dreg);
                      TempList.concat(TAIConst.create_8bit(ord(DW_OP_piece)));
                      TempList.concat(TAIConst.create_uleb128bit(size_of_int));
                      blocksize:=blocksize+1+LengthULEB128(size_of_int);
                      TempList.concat(TAIConst.create_8bit(ord(DW_OP_regx)));
                      TempList.concat(TAIConst.create_uleb128bit(dreghigh));
                      blocksize:=blocksize+1+LengthULEB128(dreghigh);
                      TempList.concat(TAIConst.create_8bit(ord(DW_OP_piece)));
                      TempList.concat(TAIConst.create_uleb128bit(size_of_int));
                      blocksize:=blocksize+1+LengthULEB128(size_of_int);
                    end
                  else if (dreg>=0) then
                    begin
                      TempList.concat(TAIConst.create_8bit(ord(DW_OP_regx)));
                      TempList.concat(TAIConst.create_uleb128bit(dreg));
                      blocksize:=1+LengthULEB128(dreg);
                    end;
                 end;
            end;
          else
            begin
              case sym.typ of
                staticvarsym:
                  begin
                    if (vo_is_thread_var in sym.VarOptions) then
                      begin
                        if tf_section_threadvars in TargetInfo.flags then
                          begin
                            case sizeof(PUint) of
                              2:
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_const2u)));
                              4:
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_const4u)));
                              8:
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_const8u)));
                              else
                                InternalError(2019100501);
                            end;
{$push}
{$warn 6018 off}            { Unreachable code due to compile time evaluation }
                            TempList.concat(TAIConst.Create_type_name(aitconst_dtpoff,sym.MangledName,0));
                            { so far, aitconst_dtpoff is solely 32 bit }
                            if sizeof ( PUint ) = 8 then
                              TempList.concat(TAIConst.create_32bit(0));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_GNU_push_tls_address)));
{$pop}

                            blocksize:=2+sizeof(PUint);
                          end
                        else
                          begin
                            { The existing debugger contract exposes the main
                              context. Resolve it through the image descriptor,
                              rather than describing the metadata as a value. }
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_addr)));
                            TempList.concat(TAIConst.Create_type_name(aitconst_ptr_unaligned,sym.MangledName,0));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_dup)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_deref)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
                            TempList.concat(TAIConst.create_uleb128bit(4*sizeof(PUint)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_deref)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_swap)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
                            TempList.concat(TAIConst.create_uleb128bit(sizeof(PUint)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_deref)));
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_plus)));
                            blocksize:=9+sizeof(PUint)+LengthULEB128(4*sizeof(PUint))+LengthULEB128(sizeof(PUint));
                            if offset<>0 then
                              begin
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_consts)));
                                TempList.concat(TAIConst.create_sleb128bit(offset));
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_plus)));
                                inc(blocksize,2+LengthSLEB128(offset));
                              end;
                          end;
                      end
                    else
                      begin
                        TempList.concat(TAIConst.create_8bit(ord(DW_OP_addr)));
                        TempList.concat(TAIConst.Create_type_name(aitconst_ptr_unaligned,sym.MangledName,offset));
                        blocksize:=1+sizeof(PUint);

                      end;
                  end;
                paravarsym,
                localvarsym:
                  begin
                    { Happens when writing debug info for paras of procdefs not
                      implemented in the current module. Can't add a general check
                      for LOC_INVALID above, because staticvarsyms may also have it.
                    }
                    if sym.LocAlloc.Loc<> LOC_INVALID then
                      begin
                        if is_fbreg(sym.LocAlloc.Reference.Base) then
                          begin
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_fbreg)));
                            TempList.concat(TAIConst.create_sleb128bit(sym.LocAlloc.Reference.Offset+offset));
                            blocksize:=1+LengthSLEB128(sym.LocAlloc.Reference.Offset+offset);
                          end
                        else
                          begin
                            dreg:=dwarf_reg(sym.LocAlloc.Reference.Base);
                            if dreg<=31 then
                              begin
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_breg0)+dreg));
                                TempList.concat(TAIConst.create_sleb128bit(sym.LocAlloc.Reference.Offset+offset));
                                blocksize:=1+LengthSLEB128(sym.LocAlloc.Reference.Offset+offset);
                              end
                            else
                              begin
                                TempList.concat(TAIConst.create_8bit(ord(DW_OP_bregx)));
                                TempList.concat(TAIConst.create_uleb128bit(dreg));
                                TempList.concat(TAIConst.create_sleb128bit(sym.LocAlloc.Reference.Offset+offset));
                                blocksize:=1+LengthULEB128(dreg)+LengthSLEB128(sym.LocAlloc.Reference.Offset+offset);
                              end;
                          end;

{$ifndef gdb_supports_DW_AT_variable_parameter}
                        { Parameters which are passed by reference. (var and the like)
                          Hide the reference-pointer and dereference the pointer
                          in the DW_AT_location block.
                        }
                        if (sym.typ=paravarsym) and
                            ParaManager.Push_Addr_Param(sym.VarSpez,sym.vardef,TProcDef(sym.owner.DefOwner).ProcCallOption) and
                            not(vo_has_local_copy in sym.VarOptions) and
                            not Is_Open_String(sym.vardef) then
                          begin
                            TempList.concat(TAIConst.create_8bit(ord(DW_OP_deref)));
                            inc(blocksize);
                          end
{$endif not gdb_supports_DW_AT_variable_parameter}
                      end;
                  end
                else
                  InternalError(200601288);
              end;
            end;
        end;

        { function results must not be added to the parameter list,
          as they are not part of the signature of the function
          (gdb automatically adds them according to the ABI specifications
           when calling the function)
        }
        if (sym.typ=paravarsym) and
           not(dvf_force_local_var in flags) and
           not(vo_is_funcret in sym.VarOptions) then
          tag:=DW_TAG_formal_parameter
        else
          tag:=DW_TAG_variable;

        { must be parasym of externally implemented procdef, but
          the parasymtable can con also contain e.g. absolutevarsyms
          -> check symtabletype}
        if (sym.owner.SymTableType=parasymtable) and
           (sym.LocAlloc.Loc=LOC_INVALID) then
          begin
            if (sym.owner.SymTableType<>parasymtable) then
              InternalError(2009101001);
            append_entry(tag,false,[
              DW_AT_name,DW_FORM_string,name+#0
              {
              DW_AT_decl_file,DW_FORM_data1,0,
              DW_AT_decl_line,DW_FORM_data1,
              }
              ])
          end
        else if not(sym.LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_MMREGISTER,
                                 LOC_CMMREGISTER,LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
           ((sym.owner.SymTableType = GlobalSymTable) or
            (sp_static in sym.SymOptions) or
            (vo_is_public in sym.VarOptions)) then
          append_entry(tag,false,[
            DW_AT_name,DW_FORM_string,name+#0,
            {
            DW_AT_decl_file,DW_FORM_data1,0,
            DW_AT_decl_line,DW_FORM_data1,
            }
            DW_AT_external,DW_FORM_flag,true,
            { data continues below }
            DW_AT_location,DW_FORM_block1,blocksize
            ])
{$ifdef gdb_supports_DW_AT_variable_parameter}
        else if (sym.typ=paravarsym) and
            ParaManager.Push_Addr_Param(sym.VarSpez,sym.vardef,TProcDef(sym.owner.DefOwner).ProcCallOption) and
            not(vo_has_local_copy in sym.VarOptions) and
            not Is_Open_String(sym.vardef) then
          append_entry(tag,false,[
            DW_AT_name,DW_FORM_string,name+#0,
            DW_AT_variable_parameter,DW_FORM_flag,true,
            {
            DW_AT_decl_file,DW_FORM_data1,0,
            DW_AT_decl_line,DW_FORM_data1,
            }
            { data continues below }
            DW_AT_location,DW_FORM_block1,blocksize
            ])
{$endif gdb_supports_DW_AT_variable_parameter}
        else
          append_entry(tag,false,[
            DW_AT_name,DW_FORM_string,name+#0,
            {
            DW_AT_decl_file,DW_FORM_data1,0,
            DW_AT_decl_line,DW_FORM_data1,
            }
            { data continues below }
            DW_AT_location,DW_FORM_block1,blocksize
            ]);
        { append block data }
        CurrentAsmData.asmlists[al_dwarf_info].ConcatList(TempList);
        { Mark self as artificial for methods, because gdb uses the fact
          whether or not the first parameter of a method is artificial to
          distinguish regular from static methods (since there are no
          no vo_is_self parameters for static methods, we don't have to check
          that).  }
        if (vo_is_self in sym.VarOptions) then
          append_attribute(DW_AT_artificial,DW_FORM_flag,[true]);
        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def));


        TempList.free;
        TempList := nil;

        finish_entry;
      end;


    procedure TDebugInfoDwarf.appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);
      begin
        appendsym_var(list,sym);
      end;


    procedure TDebugInfoDwarf.appendsym_localvar(list:TAsmList;sym:TLocalVarSym);
      begin
        appendsym_var(list,sym);
      end;


    procedure TDebugInfoDwarf.appendsym_paravar(list:TAsmList;sym:TParaVarSym);
      begin
        appendsym_var(list,sym);
      end;


    procedure TDebugInfoDwarf.appendsym_fieldvar(list:TAsmList;sym: TFieldVarSym);
      begin
        appendsym_fieldvar_with_name_offset(list,sym,symname(sym, false),sym.vardef,0);
      end;


    procedure TDebugInfoDwarf.appendsym_fieldvar_with_name_offset(list:TAsmList;sym: TFieldVarSym;const name: string; def: TDef; offset: PInt);
      var
        BitOffset,
        FieldOffset,
        fieldnatsize: asizeint;
      begin
        if (sp_static in sym.SymOptions) or
           (sym.visibility=vis_hidden) then
          exit;

        if (TAbstractRecordSymTable(sym.owner).UseFieldAlignment<>BitAlignment) or
           { only ordinals are bitpacked }
           not Is_Ordinal(sym.vardef) then
          begin
            { other kinds of fields can however also appear in a bitpacked   }
            { record, and then their offset is also specified in bits rather }
            { than in bytes                                                  }
            if (TAbstractRecordSymTable(sym.owner).UseFieldAlignment<>BitAlignment) then
              FieldOffset:=sym.FieldOffset
            else
              FieldOffset:=sym.FieldOffset div 8;
            inc(FieldOffset,offset);
            append_entry(DW_TAG_member,false,[
              DW_AT_name,DW_FORM_string,name+#0,
              DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(FieldOffset)
              ]);
          end
        else
          begin
            if (sym.vardef.PackedBitSize > 255) then
              InternalError(2007061201);

            { we don't bitpack according to the ABI, but as close as }
            { possible, i.e., equivalent to gcc's                    }
            { __attribute__((__packed__)), which is also what gpc    }
            { does.                                                  }
            fieldnatsize:=max(sizeof(PInt),sym.vardef.Size);
            FieldOffset:=(sym.FieldOffset div (fieldnatsize*8)) * fieldnatsize;
            inc(FieldOffset,offset);
            BitOffset:=sym.FieldOffset mod (fieldnatsize*8);
            BitOffset:=(fieldnatsize*8)-BitOffset-sym.vardef.PackedBitSize;
            append_entry(DW_TAG_member,false,[
              DW_AT_name,DW_FORM_string,symname(sym, false)+#0,
              { gcc also generates both a bit and byte size attribute }
              { we don't support ordinals >= 256 bits }
              DW_AT_byte_size,DW_FORM_data1,fieldnatsize,
              { nor >= 256 bits (not yet, anyway, see IE above) }
              DW_AT_bit_size,DW_FORM_data1,sym.vardef.PackedBitSize,
              { data1 and data2 are unsigned, bitoffset can also be negative }
              DW_AT_bit_offset,DW_FORM_data4,BitOffset,
              DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(FieldOffset)
              ]);
          end;
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(FieldOffset));
        if (sym.owner.SymTableType in [objectsymtable,recordsymtable]) then
          append_visibility(sym.visibility);

        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def));
        finish_entry;
      end;

    procedure TDebugInfoDwarf.appendsym_const(list:TAsmList;sym:TConstSym);
    begin
      appendsym_const_member(list,sym,false);
    end;

    procedure TDebugInfoDwarf.appendsym_const_member(list:TAsmList;sym:TConstSym;ismember:boolean);
      var
        i,
        size: aint;
        usedef: TDef;
	b : byte;
      begin
        { These are default values of parameters. These should be encoded
          via DW_AT_default_value, not as a separate sym. Moreover, their
          type is not available when writing the debug info for external
          procedures.
        }
        if (sym.owner.SymTableType=parasymtable) then
          exit;

        if ismember and (sym.owner.SymTableType=objectsymtable) then
          exit;

        if ismember then
          append_entry(DW_TAG_member,false,[
            DW_AT_name,DW_FORM_string,symname(sym, false)+#0,
          { The DW_AT_declaration tag is invalid according to the DWARF specifications.
            But gcc adds this to static const members and gdb checks
            for this flag. So we have to set it also.
          }
            DW_AT_declaration,DW_FORM_flag,true,
            DW_AT_external,DW_FORM_flag,true
            ])
        else
          append_entry(DW_TAG_variable,false,[
            DW_AT_name,DW_FORM_string,symname(sym, false)+#0
            ]);
        { for string constants, constdef isn't set because they have no real type }
        case sym.ConstTyp of
          conststring:
            begin
              { if DW_FORM_string is used below one day, this usedef should
                probably become nil }
              { note: < 255 instead of <= 255 because we have to store the
                entire length of the string as well, and 256 does not fit in
                a byte }
              if (sym.Value.len<255) then
                usedef:=CShortStringType
              else
                usedef:=CLongStringType;
            end;
          constresourcestring,
          constwresourcestring,
          constwstring:
            usedef:=nil;
          else
            usedef:=sym.ConstDef;
          end;
        if Assigned(usedef) then
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(usedef));
        AddConstToAbbrev(ord(DW_AT_const_value));
        case sym.ConstTyp of
          conststring:
            begin
              { DW_FORM_string isn't supported yet by the Pascal value printer
                -> create a string using raw bytes }
              if (sym.Value.len<255) then
                begin
                  AddConstToAbbrev(ord(DW_FORM_block1));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(sym.Value.len+1));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(sym.Value.len));
                end
              else
                begin
                  AddConstToAbbrev(ord(DW_FORM_block));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(sym.Value.len+SizeSIntType.Size));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.Create_sizeint_unaligned(sym.Value.len));
                end;
              i:=0;
              size:=sym.Value.len;
              while(i<size) do
                begin
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit((PByte(sym.Value.ValuePtr+i)^)));
                  inc(i);
                end;
            end;
          constguid,
          constset:
            begin
              AddConstToAbbrev(ord(DW_FORM_block1));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(usedef.Size));
              i:=0;
              size:=sym.ConstDef.Size;
              while (i<size) do
                begin
                  b:=PByte(sym.Value.ValuePtr+i)^;
		  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(b));
                  inc(i);
                end;
            end;
          constwstring,
          constwresourcestring,
          constresourcestring:
            begin
              { write dummy for now }
              AddConstToAbbrev(ord(DW_FORM_string));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIString.Create(''));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(0));
            end;
          constord:
            begin
              if (sym.Value.ValueOrd<0) then
                begin
                  AddConstToAbbrev(ord(DW_FORM_sdata));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_sleb128bit(sym.Value.ValueOrd.svalue));
                end
              else
                begin
                  AddConstToAbbrev(ord(DW_FORM_udata));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(sym.Value.ValueOrd.uvalue));
                end;
            end;
          constnil:
            begin
{$ifdef cpu64bitaddr}
              AddConstToAbbrev(ord(DW_FORM_data8));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(0));
{$else cpu64bitaddr}
              AddConstToAbbrev(ord(DW_FORM_data4));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(0));
{$endif cpu64bitaddr}
            end;
          constpointer:
            begin
{$ifdef cpu64bitaddr}
              AddConstToAbbrev(ord(DW_FORM_data8));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(int64(sym.Value.ValueOrdPtr)));
{$else cpu64bitaddr}
              AddConstToAbbrev(ord(DW_FORM_data4));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(LongInt(sym.Value.ValueOrdPtr)));
{$endif cpu64bitaddr}
            end;
          constreal:
            begin
              AddConstToAbbrev(ord(DW_FORM_block1));
              case TFloatDef(sym.ConstDef).FloatType of
                S32Real:
                  begin
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(4));
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIRealConst.create_s32real(Single(PBestReal(sym.Value.ValuePtr)^)));
                  end;
                S64Real:
                  begin
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(8));
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIRealConst.create_s64real(Double(PBestReal(sym.Value.ValuePtr)^)));
                  end;
                s64comp,
                s64currency:
                  begin
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(8));
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_64bit_unaligned(Trunc(PBestReal(sym.Value.ValuePtr)^)));
                  end;
                s80real,
                sc80real:
                  begin
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(sym.ConstDef.Size));
                    CurrentAsmData.asmlists[al_dwarf_info].concat(TAIRealConst.create_s80real(pextended(sym.Value.ValuePtr)^,sym.ConstDef.Size));
                  end;
              end;
            end;
          else
            InternalError(200601292);
        end;
        finish_entry;
      end;


    procedure TDebugInfoDwarf.appendsym_label(list:TAsmList;sym: TLabelSym);
      begin
        { ignore label syms for now, the problem is that a label sym
          can have more than one label associated e.g. in case of
          an inline procedure expansion }
      end;


    procedure TDebugInfoDwarf.appendsym_property(list:TAsmList;sym: TPropertySym);
      var
        SymList: PPropAccessListItem;
        tosym: TAbstractVarSym;
        offset: PInt;
      begin
        if Assigned(sym.PropAccessList[palt_read]) and
           not Assigned(sym.PropAccessList[palt_read].procdef) then
          SymList:=sym.PropAccessList[palt_read].FirstSym
        else
          { can't handle }
          exit;

        if not get_symlist_sym_offset(SymList,tosym,offset) then
          exit;

        if not (tosym.owner.SymTableType in [objectsymtable,recordsymtable]) then
          begin
            if (tosym.typ=FieldVarSym) then
              InternalError(2009031404);
            appendsym_var_with_name_type_offset(list,TAbstractNormalVarSym(tosym),symname(sym, false),sym.PropDef,offset,[])
          end
        else
          appendsym_fieldvar_with_name_offset(list,TFieldVarSym(tosym),symname(sym, false),sym.PropDef,offset)
      end;


    function TDebugInfoDwarf.symdebugname(sym: TSym): String;
    begin
      result := sym.name;
    end;


    procedure TDebugInfoDwarf.appendsym_type(list:TAsmList;sym: TTypeSym);
      begin
        { just queue the def if needed, beforeappenddef will
          emit the typedef if necessary }
        def_dwarf_lab(sym.TypeDef);
      end;


    procedure TDebugInfoDwarf.appendsym_absolute(list:TAsmList;sym:TAbsoluteVarSym);
      var
        TempList : TAsmList;
        blocksize : LongInt;
        SymList : PPropAccessListItem;
        tosym: TAbstractVarSym;
        offset: PInt;
        flags: TDwarfVarSymFlags;
      begin
        TempList:=TAsmList.Create;
        case TAbsoluteVarSym(sym).AbsTyp of
          toaddr :
            begin
               { MWE: replaced ifdef i368 }
               (*
               if target_cpu = cpu_i386 then
                 begin
                  { in theory, we could write a DW_AT_segment entry here for sym.absseg,
                    however I doubt that gdb supports this (FK) }
                 end;
               *)
               TempList.concat(TAIConst.create_8bit(3));
               TempList.concat(TAIConst.create_int_dataptr_unaligned(sym.AddrOffset));
               blocksize:=1+sizeof(PUint);
            end;
          toasm :
            begin
              TempList.concat(TAIConst.create_8bit(3));
              TempList.concat(TAIConst.create_type_name(aitconst_ptr_unaligned,sym.MangledName,0));
              blocksize:=1+sizeof(PUint);
            end;
          tovar:
            begin
              SymList:=TAbsoluteVarSym(sym).Ref.FirstSym;
              if get_symlist_sym_offset(SymList,tosym,offset) then
                begin
                  if (tosym.typ=FieldVarSym) then
                    InternalError(2009031402);
                  flags:=[];
                  if (sym.owner.SymTableType=LocalSymTable) then
                    include(flags,dvf_force_local_var);
                  appendsym_var_with_name_type_offset(list,TAbstractNormalVarSym(tosym),symname(sym, false),TAbstractVarSym(sym).vardef,offset,flags);
                end;
              TempList.free;
              TempList := nil;
              exit;
            end;
        end;

        append_entry(DW_TAG_variable,false,[
          DW_AT_name,DW_FORM_string,symname(sym, false)+#0,
          {
          DW_AT_decl_file,DW_FORM_data1,0,
          DW_AT_decl_line,DW_FORM_data1,
          }
          DW_AT_external,DW_FORM_flag,true,
          { data continues below }
          DW_AT_location,DW_FORM_block1,blocksize
          ]);
        { append block data }
        CurrentAsmData.asmlists[al_dwarf_info].ConcatList(TempList);
        append_labelentry_ref(DW_AT_type,def_dwarf_lab(sym.vardef));

        TempList.free;
        TempList := nil;

        finish_entry;
      end;


    procedure TDebugInfoDwarf.beforeappendsym(list:TAsmList;sym:TSym);
      begin
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIComment.Create(StrPNew('Symbol '+symname(sym, true))));
      end;


    procedure TDebugInfoDwarf.insertmoduleinfo;
      var
        TempList: TAsmList;
        linelist: TAsmList;
        lbl   : TAsmLabel;
        n,m,found_dot_dir: Integer;
        ditem : TDirIndexItem;
        fitem : TFileIndexItem;
        flist : TFPList;
        dbgname : TSymStr;
      begin
        if not (TargetInfo.system in systems_windows) then
          begin
            { insert DEBUGSTART and DEBUGEND labels }
            dbgname:=Make_MangledName('DEBUGSTART',CurrentModule.LocalSymTable,'');
            { Darwin's linker does not like two global labels both pointing to the
              end of a section, which can happen in case of units without code ->
              make them local; we don't need the debugtable stuff there either,
              so it doesn't matter that they are not global.
            }
            if (TargetInfo.system in systems_darwin) then
              dbgname:='L'+dbgname;
            new_section(CurrentAsmData.asmlists[al_start],sec_code,dbgname,0,secorder_begin);
            if not(TargetInfo.system in systems_darwin) then
              CurrentAsmData.asmlists[al_start].concat(TAISymbol.Createname_global(dbgname,AT_METADATA,0,VoidPointerType))
            else
              CurrentAsmData.asmlists[al_start].concat(TAISymbol.Createname(dbgname,AT_METADATA,0,VoidPointerType));

            dbgname:=Make_MangledName('DEBUGEND',CurrentModule.LocalSymTable,'');
            { See above. }
            if (TargetInfo.system in systems_darwin) then
              dbgname:='L'+dbgname;
            new_section(CurrentAsmData.asmlists[al_end],sec_code,dbgname,0,secorder_end);
            if not(TargetInfo.system in systems_darwin) then
              CurrentAsmData.asmlists[al_end].concat(TAISymbol.Createname_global(dbgname,AT_METADATA,0,VoidPointerType))
            else
              CurrentAsmData.asmlists[al_end].concat(TAISymbol.Createname(dbgname,AT_METADATA,0,VoidPointerType));
          end;

        { insert .Ldebug_abbrev0 label }
        TempList:=TAsmList.Create;
        new_section(TempList,sec_debug_abbrev,'',0);
        TempList.concat(TAISymbol.createname(TargetAsm.labelprefix+'debug_abbrevsection0',AT_METADATA,0,VoidPointerType));
        { add any extra stuff which needs to be in the abbrev section, but before    }
        { the actual abbreviations, in between the symbol above and below, i.e. here }
        TempList.concat(TAISymbol.createname(TargetAsm.labelprefix+'debug_abbrev0',AT_METADATA,0,VoidPointerType));
        CurrentAsmData.asmlists[al_start].InsertList(TempList);
        TempList.free;

        { insert .Ldebug_line0 label }
        TempList:=TAsmList.Create;
        new_section(TempList,sec_debug_line,'',0);
        TempList.concat(TAISymbol.createname(TargetAsm.labelprefix+'debug_linesection0',AT_METADATA,0,VoidPointerType));
        { add any extra stuff which needs to be in the line section, but before  }
        { the actual line info, in between the symbol above and below, i.e. here }
        TempList.concat(TAISymbol.createname(TargetAsm.labelprefix+'debug_line0',AT_METADATA,0,VoidPointerType));
        CurrentAsmData.asmlists[al_start].InsertList(TempList);
        TempList.free;
        TempList := nil;

        { finalize line info if the unit doesn't contain any function/ }
        { procedure/init/final code                                    }
        finish_lineinfo;

        { debug line header }
        linelist := CurrentAsmData.asmlists[al_dwarf_line];
        new_section(linelist,sec_debug_line,'',0);
        linelist.concat(TAIComment.Create(StrPNew('=== header start ===')));

        { size }
        CurrentAsmData.getlabel(lbl,alt_dbgfile);
        if use_64bit_headers then
          linelist.concat(TAIConst.create_32bit_unaligned(LongInt($FFFFFFFF)));
        linelist.concat(TAIConst.create_rel_sym(offsetreltype,
          lbl,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'edebug_line0',AB_LOCAL,AT_METADATA,VoidPointerType)));
        linelist.concat(TAILabel.Create(lbl));

        { version }
        linelist.concat(TAIConst.create_16bit_unaligned(dwarf_version));

        if dwarf_version >= 5 then
          begin
            { address size }
            linelist.concat(TAIConst.create_8bit(sizeof(PInt)));
            { segment size }
            linelist.concat(TAIConst.create_8bit(0));
          end;

        { header length }
        CurrentAsmData.getlabel(lbl,alt_dbgfile);
        linelist.concat(TAIConst.create_rel_sym(offsetreltype,
          lbl,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'ehdebug_line0',AB_LOCAL,AT_METADATA,VoidPointerType)));
        linelist.concat(TAILabel.Create(lbl));

        { minimum_instruction_length }
        linelist.concat(TAIConst.create_8bit(1));

        { maximum ops per instruction }
        if dwarf_version>=4 then
          linelist.concat(TAIConst.create_8bit(1));

        { default_is_stmt }
        linelist.concat(TAIConst.create_8bit(1));

        { line_base }
        linelist.concat(TAIConst.create_8bit(LINE_BASE));

        { line_range }
        { only line increase, no adress }
        linelist.concat(TAIConst.create_8bit(LINE_RANGE));

        { opcode_base }
        linelist.concat(TAIConst.create_8bit(OPCODE_BASE));

        { standard_opcode_lengths }
        { MWE: sigh... why adding the default lengths (and make those sizes sense with LEB encoding) }
          { DW_LNS_copy }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_advance_pc }
        linelist.concat(TAIConst.create_8bit(1));
          { DW_LNS_advance_line }
        linelist.concat(TAIConst.create_8bit(1));
          { DW_LNS_set_file }
        linelist.concat(TAIConst.create_8bit(1));
          { DW_LNS_set_column }
        linelist.concat(TAIConst.create_8bit(1));
          { DW_LNS_negate_stmt }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_set_basic_block }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_const_add_pc }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_fixed_advance_pc }
        linelist.concat(TAIConst.create_8bit(1));
          { DW_LNS_set_prologue_end }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_set_epilogue_begin }
        linelist.concat(TAIConst.create_8bit(0));
          { DW_LNS_set_isa }
        linelist.concat(TAIConst.create_8bit(1));

        { Create single list of filenames sorted in IndexNr }
        found_dot_dir := 0;
        flist:=TFPList.Create;
        for n := 0 to dirlist.Count - 1 do
          begin
            ditem := TDirIndexItem(dirlist[n]);
            if ditem.Name = '.' then
              found_dot_dir := 1;
            for m := 0 to ditem.Files.Count - 1 do
              flist.Add(ditem.Files[m]);
          end;
        flist.Sort(@FileListSortCompare);

        if dwarf_version >= 5 then
          begin
            { directory_entry_format count }
            linelist.concat(TAIConst.create_8bit(1));
            { directory_entry_format }
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_LNCT_path)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_FORM_string)));
            { directory_entry count }
            linelist.concat(TAIConst.create_8bit(dirlist.Count - found_dot_dir + 1));
            { directory_entry 0 / DWARF-5 needs current dir FIRST }
            linelist.concat(TAIString.Create(BSToSlash(FixPath(GetCurrentDir,false))+#0));
          end;

        { include_directories }
        linelist.concat(TAIComment.Create(StrPNew('include_directories')));
        for n := 0 to dirlist.Count - 1 do
          begin
            ditem := TDirIndexItem(dirlist[n]);
            if ditem.Name = '.' then
              Continue;
            { Write without trailing path delimiter and also don't prefix with ./ for current dir (already done while adding to dirlist }

            linelist.concat(TAIString.Create(ditem.Name+#0));
          end;
        if dwarf_version < 5 then
          linelist.concat(TAIConst.create_8bit(0));

        { file_names count }
        if dwarf_version >= 5 then
          begin
            { file_entry_format count }
            linelist.concat(TAIConst.create_8bit(4));
            { file_entry_format }
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_LNCT_path)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_FORM_string)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_LNCT_directory_index)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_FORM_udata)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_LNCT_timestamp)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_FORM_udata)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_LNCT_size)));
            linelist.concat(TAIConst.create_uleb128bit(ord(DW_FORM_udata)));

            { file count }
            linelist.concat(TAIConst.create_8bit(flist.Count+1));
            { file name }
            linelist.concat(TAIString.Create(CurrentModule.SourceFiles.Get_File(1).name+#0));
            { directory index }
            linelist.concat(TAIConst.create_uleb128bit(0));
            { last modification }
            linelist.concat(TAIConst.create_uleb128bit(0));
            { file length }
            linelist.concat(TAIConst.create_uleb128bit(0));
          end;
        { file_names }
        linelist.concat(TAIComment.Create(StrPNew('file_names')));
        for n := 0 to flist.Count - 1 do
          begin
            fitem := TFileIndexItem(flist[n]);
            { file name }
            linelist.concat(TAIString.Create(fitem.Name+#0));
            { directory index }
            linelist.concat(TAIConst.create_uleb128bit(fitem.DirIndex));
            { last modification }
            linelist.concat(TAIConst.create_uleb128bit(0));
            { file length }
            linelist.concat(TAIConst.create_uleb128bit(0));
          end;
        if dwarf_version < 5 then
          linelist.concat(TAIConst.create_8bit(0));

        { end of debug line header }
        linelist.concat(TAISymbol.createname(TargetAsm.labelprefix+'ehdebug_line0',AT_METADATA,0,VoidPointerType));
        linelist.concat(TAIComment.Create(StrPNew('=== header end ===')));

        { add line program }
        linelist.ConcatList(asmline);

        { end of debug line table }
        linelist.concat(TAISymbol.createname(TargetAsm.labelprefix+'edebug_line0',AT_METADATA,0,VoidPointerType));

        flist.free;
        flist := nil;
      end;


    procedure TDebugInfoDwarf.inserttypeinfo;
      var
        storefilepos  : TFilePosInfo;
        lenstartlabel,arangestartlabel: TAsmLabel;
        i : LongInt;
        def: TDef;
        dbgname: string;
        vardatatype: TTypeSym;
        bind: TAsmsymbind;
        lang: TDwarfSourceLanguage;
      begin
        include(CurrentModule.ModuleFlags,mf_has_dwarf_debuginfo);
        storefilepos:=CurrentFilePos;
        CurrentFilePos:=CurrentModule.MainFilePos;

        if Assigned(dwarflabels) then
          InternalError(2015100301);
        { one item per def, plus some extra space in case of nested types,
          externally used types etc (it will grow further if necessary) }
        i:=CurrentModule.LocalSymTable.DefList.count*4;
        if Assigned(CurrentModule.GlobalSymTable) then
          inc(i,CurrentModule.GlobalSymTable.DefList.count*2);
        dwarflabels:=TDwarfLabHashSet.Create(i,true,false);

        currabbrevnumber:=0;

        defnumberlist:=TFPObjectList.Create(false);
        deftowritelist:=TFPObjectList.Create(false);

        { not exported (FK)
            FILEREC
            TEXTREC
        }
        vardatatype:=Try_Search_System_Type('TVARDATA');
        if Assigned(vardatatype) then
          vardatadef:=TRecordDef(vardatatype.TypeDef);

        if TargetInfo.system in systems_windows then
          begin
            FWin64CUSectionKey:=lower(Make_MangledName('DWARFCU',CurrentModule.LocalSymTable,''));
            FWin64RangesStart:=nil;
            FWin64RangeIndex:=0;
          end;

        { write start labels }
        new_section(CurrentAsmData.asmlists[al_dwarf_info],sec_debug_info,'',0);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.createname(TargetAsm.labelprefix+'debug_info0',AT_METADATA,0,VoidPointerType));

        { start abbrev section }
        new_section(CurrentAsmData.asmlists[al_dwarf_abbrev],sec_debug_abbrev,'',0);

        if TargetInfo.system in systems_windows then
          begin
            { Keep the CU framing alive while each function range follows its
              associated function COMDAT. }
            new_section(CurrentAsmData.asmlists[al_dwarf_ranges],
              sec_debug_ranges,FWin64CUSectionKey+'$A',0);
            FWin64RangesStart:=CurrentAsmData.DefineAsmSymbol(
              TargetAsm.labelprefix+'debug_ranges0',AB_LOCAL,AT_METADATA,VoidPointerType);
            CurrentAsmData.asmlists[al_dwarf_ranges].concat(TAISymbol.Create(FWin64RangesStart,0));
            { Base-address selection entry with an explicit zero base. }
            CurrentAsmData.asmlists[al_dwarf_ranges].concat(TAIConst.Create_int_codeptr_unaligned(-1));
            CurrentAsmData.asmlists[al_dwarf_ranges].concat(TAIConst.Create_nil_codeptr_unaligned);
          end;

        if not(TargetInfo.system in (systems_darwin+systems_windows)) then
          begin
            { start aranges section }
            new_section(CurrentAsmData.asmlists[al_dwarf_aranges],sec_debug_aranges,'',0);

            CurrentAsmData.getlabel(arangestartlabel,alt_dbgfile);

            if use_64bit_headers then
              CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_32bit_unaligned(LongInt($FFFFFFFF)));
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_rel_sym(offsetreltype,
              arangestartlabel,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'earanges0',AB_LOCAL,AT_METADATA,VoidPointerType)));

            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAILabel.Create(arangestartlabel));

            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_16bit_unaligned(2));

            if not(tf_dwarf_relative_addresses in TargetInfo.flags) then
              CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_type_sym(offsetabstype,
                CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_info0',AB_LOCAL,AT_METADATA,VoidPointerType)))
            else
              CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_rel_sym(offsetreltype,
                CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_infosection0',AB_LOCAL,AT_METADATA,VoidPointerType),
                CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_info0',AB_LOCAL,AT_METADATA,VoidPointerType)));


            { address_size }
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_8bit(sizeof(PInt)));
            { segment_size }
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_8bit(0));
            { alignment }
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.create_32bit_unaligned(0));


            { start ranges section }
            new_section(CurrentAsmData.asmlists[al_dwarf_ranges],sec_debug_ranges,'',0);
          end;

        { debug info header }
        CurrentAsmData.getlabel(lenstartlabel,alt_dbgfile);
        { size }
        if use_64bit_headers then
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_32bit_unaligned(LongInt($FFFFFFFF)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_rel_sym(offsetreltype,
          lenstartlabel,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'edebug_info0',AB_LOCAL,AT_METADATA,VoidPointerType)));

        CurrentAsmData.asmlists[al_dwarf_info].concat(TAILabel.Create(lenstartlabel));
        { version }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(dwarf_version));
        insert_cu_header_after_version;

        if (ds_dwarf_cpp in CurrentSettings.DebugSwitches) then
          lang:=DW_LANG_C_plus_plus
        else
          lang:=DW_LANG_Pascal83;
        { first manadatory compilation unit TAG }
        append_entry(DW_TAG_compile_unit,true,[
          DW_AT_name,DW_FORM_string,relative_dwarf_path(CurrentModule.SourceFiles.Get_File(1).path+CurrentModule.SourceFiles.Get_File(1).name)+#0,
          DW_AT_producer,DW_FORM_string,'NXPC '+Full_Version_String+' '+DateString+#0,
          DW_AT_comp_dir,DW_FORM_string,BSToSlash(FixPath(GetCurrentDir,false))+#0,
          DW_AT_language,DW_FORM_data1,lang,
          DW_AT_identifier_case,DW_FORM_data1,DW_ID_case_insensitive]);



        { reference to line info section }
        if not(tf_dwarf_relative_addresses in TargetInfo.flags) then
          append_labelentry_dataptr_abs(DW_AT_stmt_list,CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_line0',AB_LOCAL,AT_METADATA,VoidPointerType))
        else
          append_labelentry_dataptr_rel(DW_AT_stmt_list,
            CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_linesection0',AB_LOCAL,AT_METADATA,VoidPointerType),
            CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_line0',AB_LOCAL,AT_METADATA,VoidPointerType));

        if (m_objectivec1 in CurrentSettings.ModeSwitches) then
          append_attribute(DW_AT_APPLE_major_runtime_vers,DW_FORM_data1,[1]);

        if TargetInfo.system in systems_windows then
          begin
            append_labelentry_dataptr_abs(DW_AT_ranges,FWin64RangesStart);
          end
        else
          begin
            dbgname:=Make_MangledName('DEBUGSTART',CurrentModule.LocalSymTable,'');
            if (TargetInfo.system in systems_darwin) then
              begin
                bind:=AB_LOCAL;
                dbgname:='L'+dbgname;
              end
            else
              bind:=AB_GLOBAL;
            append_labelentry(DW_AT_low_pc,CurrentAsmData.DefineAsmSymbol(dbgname,bind,AT_METADATA,VoidPointerType));
            dbgname:=Make_MangledName('DEBUGEND',CurrentModule.LocalSymTable,'');
            if (TargetInfo.system in systems_darwin) then
              dbgname:='L'+dbgname;
            append_labelentry(DW_AT_high_pc,CurrentAsmData.DefineAsmSymbol(dbgname,bind,AT_METADATA,VoidPointerType));
          end;

        finish_entry;

        { write all global/local variables. This will flag all required tdefs  }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_syms(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.LocalSymTable) then
          write_symtable_syms(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.LocalSymTable);

        { write all procedures and methods. This will flag all required tdefs }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_procdefs(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.LocalSymTable) then
          write_symtable_procdefs(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.LocalSymTable);

        { reset unit type info flag }
        reset_unit_type_info;

        { write used types from the used units }
        write_used_unit_type_info(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule);

        { last write the types from this unit }
        if Assigned(CurrentModule.GlobalSymTable) then
          write_symtable_defs(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.GlobalSymTable);
        if Assigned(CurrentModule.LocalSymTable) then
          write_symtable_defs(CurrentAsmData.asmlists[al_dwarf_info],CurrentModule.LocalSymTable);

        { write defs not written yet }
        write_remaining_defs_to_write(CurrentAsmData.asmlists[al_dwarf_info]);

        { close compilation unit entry }
        finish_children;

        if TargetInfo.system in systems_windows then
          begin
            new_section(CurrentAsmData.asmlists[al_dwarf_ranges],
              sec_debug_ranges,FWin64CUSectionKey+'$Z',0);
            CurrentAsmData.asmlists[al_dwarf_ranges].concat(TAIConst.Create_nil_codeptr_unaligned);
            CurrentAsmData.asmlists[al_dwarf_ranges].concat(TAIConst.Create_nil_codeptr_unaligned);
          end;

        { end of debug info table }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.createname(TargetAsm.labelprefix+'edebug_info0',AT_METADATA,0,VoidPointerType));

        { end of abbrev table }
        CurrentAsmData.asmlists[al_dwarf_abbrev].concat(TAIConst.create_8bit(0));

        if not(TargetInfo.system in (systems_darwin+systems_windows)) then
          begin
            { end of aranges table }

            { offset }
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.Create_nil_codeptr);
            { length }
            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAIConst.Create_nil_codeptr);

            CurrentAsmData.asmlists[al_dwarf_aranges].concat(TAISymbol.createname(TargetAsm.labelprefix+'earanges0',AT_METADATA,0,VoidPointerType));
          end;

        { reset all def debug states }
        for i:=0 to defnumberlist.count-1 do
          begin
            def := TDef(defnumberlist[i]);
            if Assigned(def) then
              def.DbgState:=dbg_state_unused;
          end;
        dwarflabels.free;
        dwarflabels:=nil;

        defnumberlist.free;
        defnumberlist:=nil;
        deftowritelist.free;
        deftowritelist:=nil;

        CurrentFilePos:=storefilepos;
      end;


    procedure TDebugInfoDwarf.referencesections(list:TAsmList);
      var
        hp : TModule;
      begin
        { Reference all DEBUGINFO sections from the main .fpc section }
        { to prevent eliminating them by smartlinking                 }
        if (TargetInfo.system in (systems_darwin+systems_windows)) then
          exit;
        new_section(list,sec_fpc,'links',0);

        { include reference to all debuginfo sections of used units }
        hp:=TModule(Loaded_Units.first);
        while Assigned(hp) do
          begin
            If (mf_has_dwarf_debuginfo in hp.ModuleFlags) and not Assigned(hp.package) then
              begin
                list.concat(TAIConst.Createname(Make_MangledName('DEBUGSTART',hp.LocalSymTable,''),0));
                list.concat(TAIConst.Createname(Make_MangledName('DEBUGEND',hp.LocalSymTable,''),0));
              end;
            hp:=TModule(hp.next);
          end;
      end;


    function TDebugInfoDwarf.symname(sym: TSym; manglename: boolean): String;
      begin
        if (sym.typ=paravarsym) and
           (vo_is_self in TParaVarSym(sym).VarOptions) then
          { We use 'this' for regular methods because that's what gdb triggers
            on to automatically search fields. Don't do this for class methods,
            because search class fields is not supported, and gdb 7.0+ fails
            in this case because "this" is not a record in that case (it's a
            pointer to a vmt) }
          if not Is_ObjC_Class_Or_Protocol(TDef(sym.owner.DefOwner.owner.DefOwner)) and
             not(po_classmethod in TAbstractProcDef(sym.owner.DefOwner).ProcOptions) then
            result:='this'
          else
            result:='self'
        else if (sym.typ=TypeSym) and
                Is_ObjC_Class_Or_Protocol(TTypeSym(sym).TypeDef) then
          result:=TObjectDef(TTypeSym(sym).TypeDef).ObjExtName^
        else if (ds_dwarf_method_class_prefix in CurrentSettings.DebugSwitches) and
                (sym.typ=ProcSym) and
                (TProcSym(sym).owner.SymTableType in [objectsymtable,recordsymtable]) then
          begin
            result:=TProcSym(sym).owner.name^+'__';
            if manglename then
              result := result + sym.name
            else
              result := result + symdebugname(sym);
          end
        else
          begin
            if manglename then
              result := sym.name
            else
              result := symdebugname(sym);
          end;
      end;


    procedure TDebugInfoDwarf.append_visibility(vis: TVisibility);
      begin
        case vis of
          vis_hidden,
          vis_private,
          vis_strictprivate:
            append_attribute(DW_AT_accessibility,DW_FORM_data1,[ord(DW_ACCESS_private)]);
          vis_protected,
          vis_strictprotected:
            append_attribute(DW_AT_accessibility,DW_FORM_data1,[ord(DW_ACCESS_protected)]);
          vis_published,
          vis_public:
            { default };
          vis_none:
            InternalError(2019050720);
        end;
      end;


    procedure TDebugInfoDwarf.insertlineinfo(list:TAsmList);
      var
        currfileinfo,
        lastfileinfo : TFilePosInfo;
        currfuncname : PShortString;
        currstatement: boolean;
        currsectype  : TAsmSectiontype;
        hp, hpend : TAI;
        infile : TInputFile;
        prevcolumn,
        diffline,
        prevline,
        prevfileidx,
        currfileidx,
        nolineinfolevel : Integer;
        prevlabel,
        currlabel     : TAsmLabel;
      begin
        { this function will always terminate the lineinfo block }
        generated_lineinfo := true;
        { if this unit only contains code without debug info (implicit init
          or final etc), make sure the file table contains at least one entry
          (the main source of the unit), because normally this table gets
          populated via calls to get_file_index and that won't happen in this
          case }
        get_file_index(CurrentModule.SourceFiles.Get_File(1));
        FillChar(lastfileinfo,sizeof(lastfileinfo),0);
        currfuncname:=nil;
        currsectype:=sec_code;
        hp:=TAI(list.first);
        currstatement:=true;
        prevcolumn := 0;
        prevline := 1;
        prevfileidx := 1;
        prevlabel := nil;
        nolineinfolevel := 0;
        hpend := nil;
        while Assigned(hp) do
          begin
            case hp.typ of
              ait_section :
                currsectype:=TAISection(hp).sectype;
              ait_function_name :
                begin
                  currfuncname:=TAIFunctionName(hp).funcname;
                  asmline.concat(TAIComment.Create(StrPNew('function: '+currfuncname^)));
                end;
              ait_force_line :
                begin
                  lastfileinfo.line:=-1;
                end;
              ait_marker :
                begin
                  case TAIMarker(hp).kind of
                    mark_NoLineInfoStart:
                      inc(nolineinfolevel);
                    mark_NoLineInfoEnd:
                      dec(nolineinfolevel);
                    else
                      ;
                  end;
                end;
              else
                ;
            end;

            if (currsectype=sec_code) and
               (hp.typ=ait_instruction) then
              begin
                currfileinfo:=TAILineInfo(hp).fileinfo;
                { file changed ? (must be before line info) }
                if (currfileinfo.fileindex<>0) and
                   ((lastfileinfo.fileindex<>currfileinfo.fileindex) or
                    (lastfileinfo.moduleindex<>currfileinfo.moduleindex)) then
                  begin
                    infile:=Get_Module(currfileinfo.moduleindex).SourceFiles.Get_File(currfileinfo.fileindex);
                    if Assigned(infile) then
                      begin
                        currfileidx := get_file_index(infile);
                        if prevfileidx <> currfileidx then
                          begin
                            list.insertbefore(TAIComment.Create(StrPNew('path: '+infile.path)), hp);
                            list.insertbefore(TAIComment.Create(StrPNew('file: '+infile.name)), hp);
                            list.insertbefore(TAIComment.Create(StrPNew('indx: '+ToStr(currfileidx))), hp);

                            { set file }
                            asmline.concat(TAIComment.Create(StrPNew('path: '+infile.path)));
                            asmline.concat(TAIComment.Create(StrPNew('file: '+infile.name)));
                            asmline.concat(TAIConst.create_8bit(DW_LNS_set_file));
                            asmline.concat(TAIConst.create_uleb128bit(currfileidx));

                            prevfileidx := currfileidx;
                          end;
                        { force new line info }
                        lastfileinfo.line:=-1;
                      end;
                  end;

                { Set the line-nr to 0 if the code does not corresponds to a particular line  }
                if nolineinfolevel>0 then
                  currfileinfo.line := 0;

                { line changed ? }
                if (lastfileinfo.line<>currfileinfo.line) and ((currfileinfo.line<>0) or (nolineinfolevel>0)) then
                  begin
                    { set address }
                    CurrentAsmData.getlabel(currlabel, alt_dbgline);
                    list.insertbefore(TAILabel.Create(currlabel), hp);

                    asmline.concat(TAIComment.Create(StrPNew('['+ToStr(currfileinfo.line)+':'+ToStr(currfileinfo.column)+']')));

                    if (prevlabel = nil) or
                       { Darwin's assembler cannot create an uleb128 of the difference
                         between two symbols. }
                       (TargetInfo.system in systems_darwin) then
                      begin
                        asmline.concat(TAIConst.create_8bit(DW_LNS_extended_op));
                        asmline.concat(TAIConst.create_uleb128bit(1+sizeof(PInt)));
                        asmline.concat(TAIConst.create_8bit(DW_LNE_set_address));
                        asmline.concat(TAIConst.create_type_sym(aitconst_ptr_unaligned,currlabel));

                      end
                    else
                      begin
                        asmline.concat(TAIConst.create_8bit(DW_LNS_advance_pc));
                        asmline.concat(TAIConst.create_rel_sym(aitconst_uleb128bit, prevlabel, currlabel));
                      end;
                    prevlabel := currlabel;

                    { set column }
                    if prevcolumn <> currfileinfo.column then
                      begin
                        asmline.concat(TAIConst.create_8bit(DW_LNS_set_column));
                        asmline.concat(TAIConst.create_uleb128bit(currfileinfo.column));
                        prevcolumn := currfileinfo.column;
                      end;

                    { set statement }
                    if (currfileinfo.line=0) and currstatement then
                      begin
                        currstatement := false;
                        asmline.concat(TAIConst.create_8bit(DW_LNS_negate_stmt));
                      end;

                    if not currstatement and (currfileinfo.line>0) then
                      begin
                        currstatement := true;
                        asmline.concat(TAIConst.create_8bit(DW_LNS_negate_stmt));
                      end;

                    { set line }
                    diffline := currfileinfo.line - prevline;
                    if (diffline >= LINE_BASE) and (diffline <= (LINE_BASE + LINE_RANGE - 1)) and
                       (OPCODE_BASE + diffline - LINE_BASE <= 255) then
                      begin
                        { use special opcode, this also adds a row }
                        asmline.concat(TAIConst.create_8bit(OPCODE_BASE + diffline - LINE_BASE));
                      end
                    else
                      begin
                        if diffline <> 0 then
                          begin
                            asmline.concat(TAIConst.create_8bit(DW_LNS_advance_line));
                            asmline.concat(TAIConst.create_sleb128bit(diffline));
                          end;
                        { no row added yet, do it manually }
                        asmline.concat(TAIConst.create_8bit(DW_LNS_copy));
                      end;
                    prevline := currfileinfo.line;
                  end;

                lastfileinfo:=currfileinfo;
              end;

            hpend:=hp;
            hp:=TAI(hp.next);
          end;

        if Assigned(hpend) then
          begin
           { set address for end (see appendix 3 of dwarf 2 specs) }
            CurrentAsmData.getlabel(currlabel, alt_dbgline);
            list.insertafter(TAILabel.Create(currlabel), hpend);
            asmline.concat(TAIConst.create_8bit(DW_LNS_extended_op));
            asmline.concat(TAIConst.create_uleb128bit(1+sizeof(PInt)));
            asmline.concat(TAIConst.create_8bit(DW_LNE_set_address));
            asmline.concat(TAIConst.create_type_sym(aitconst_ptr_unaligned,currlabel));
          end;

        { end sequence }
        asmline.concat(TAIConst.Create_8bit(DW_LNS_extended_op));
        asmline.concat(TAIConst.Create_8bit(1));
        asmline.concat(TAIConst.Create_8bit(DW_LNE_end_sequence));
        asmline.concat(TAIComment.Create(StrPNew('###################')));
      end;


    procedure TDebugInfoDwarf.finish_lineinfo;
      var
        infile: TInputFile;
      begin
        { only needed if no line info at all has been generated }
        if generated_lineinfo then
          begin
            { reset for next module compilation }
            generated_lineinfo:=false;
            exit;
          end;
        { at least the Darwin linker is annoyed if you do not }
        { finish the lineinfo section, or if it doesn't       }
        { contain at least one file name and set_address      }
        infile:=CurrentModule.SourceFiles.Get_File(1);
        if not Assigned(infile) then
          InternalError(2006020211);
        asmline.concat(TAIConst.create_8bit(DW_LNS_set_file));
        asmline.concat(TAIConst.create_uleb128bit(get_file_index(infile)));

        asmline.concat(TAIConst.create_8bit(DW_LNS_extended_op));
        asmline.concat(TAIConst.create_uleb128bit(1+sizeof(PInt)));
        asmline.concat(TAIConst.create_8bit(DW_LNE_set_address));
        asmline.concat(TAIConst.create_type_sym(aitconst_ptr_unaligned,nil));
        asmline.concat(TAIConst.create_8bit(DW_LNS_extended_op));
        asmline.concat(TAIConst.Create_8bit(1));
        asmline.concat(TAIConst.Create_8bit(DW_LNE_end_sequence));
        asmline.concat(TAIComment.Create(StrPNew('###################')));
      end;

    procedure TDebugInfoDwarf.insert_cu_header_after_version;
    begin
      { abbrev table (=relative from section start)}
      if not(tf_dwarf_relative_addresses in TargetInfo.flags) then
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_type_sym(offsetabstype,
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrev0',AB_LOCAL,AT_METADATA,VoidPointerType)))
      else
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_rel_sym(offsetreltype,
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrevsection0',AB_LOCAL,AT_METADATA,VoidPointerType),
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrev0',AB_LOCAL,AT_METADATA,VoidPointerType)));

      { address size }
      CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(sizeof(PInt)));
    end;

{****************************************************************************
                              TDebugInfoDwarf2
****************************************************************************}

    procedure TDebugInfoDwarf2.appenddef_file(list:TAsmList;def: TFileDef);
      begin
        { gdb 6.4 doesn't support files so far so we use some fake recorddef
          file recs. are less than 1k so using data2 is enough }
        if Assigned(def.TypeSym) then
          append_entry(DW_TAG_structure_type,false,[
           DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
           DW_AT_byte_size,DW_FORM_udata,def.Size
          ])
        else
          append_entry(DW_TAG_structure_type,false,[
           DW_AT_byte_size,DW_FORM_udata,def.Size
          ]);
        finish_entry;
      end;

    procedure TDebugInfoDwarf2.appenddef_formal(list:TAsmList;def: TFormalDef);
      begin
        { gdb 6.4 doesn't support DW_TAG_unspecified_type so we
          replace it with a unsigned type with size 0 (FK)
        }
        append_entry(DW_TAG_base_type,false,[
          DW_AT_name,DW_FORM_string,'FormalDef'#0,
          DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
          DW_AT_byte_size,DW_FORM_data1,0
        ]);
        finish_entry;
      end;

    procedure TDebugInfoDwarf2.append_object_struct(def: TObjectDef; const createlabel: boolean; const objectname: PShortString);
      begin
        if createlabel then
          begin
            if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(def_dwarf_class_struct_lab(def),0))
            else
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(def_dwarf_class_struct_lab(def),0));
          end;
        if Assigned(objectname) then
          append_entry(DW_TAG_class_type,true,[
            DW_AT_name,DW_FORM_string,objectname^+#0,
            DW_AT_byte_size,DW_FORM_udata,TObjectSymTable(def.SymTable).DataSize
            ])
        else
          append_entry(DW_TAG_class_type,true,[
            DW_AT_byte_size,DW_FORM_udata,TObjectSymTable(def.SymTable).DataSize
            ]);
        { Apple-specific tag that identifies it as an Objective-C class }
        if (def.ObjectType=odt_objcclass) then
          append_attribute(DW_AT_APPLE_runtime_class,DW_FORM_data1,[DW_LANG_ObjC]);

        finish_entry;
        if Assigned(def.ChildOf) then
          begin
            append_entry(DW_TAG_inheritance,false,[
              DW_AT_accessibility,DW_FORM_data1,DW_ACCESS_public,
              DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(0)
            ]);
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(0));
            if (def.ChildOf.DbgState=dbg_state_unused) then
              def.ChildOf.DbgState:=dbg_state_used;
            if Is_Implicit_Pointer_Object_Type(def) then
              append_labelentry_ref(DW_AT_type,def_dwarf_class_struct_lab(def.ChildOf))
            else
              append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ChildOf));
            finish_entry;
          end;
        if (oo_has_vmt in def.ObjectOptions) and
           (not Assigned(def.ChildOf) or
            not(oo_has_vmt in def.ChildOf.ObjectOptions)) then
          begin
            { vmt field }
            append_entry(DW_TAG_member,false,[
                DW_AT_artificial,DW_FORM_flag,true,
                DW_AT_name,DW_FORM_string,'_vptr$'+def.ObjName^+#0,
                DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(def.VMT_Offset)
            ]);
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
            CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(def.VMT_Offset));
            { should be changed into a pointer to a function returning an }
            { int and with TAG_unspecified_parameters                     }
            if (VoidPointerType.DbgState=dbg_state_unused) then
              VoidPointerType.DbgState:=dbg_state_used;
            append_labelentry_ref(DW_AT_type,def_dwarf_lab(VoidPointerType));
            finish_entry;
          end;

        def.SymTable.SymList.ForEachCall(@enum_membersyms_callback,nil);
        { Write the methods in the scope of the class/object, except for Objective-C.  }
        if Is_ObjC_Class_Or_Protocol(def) then
          finish_children;
        { don't write procdefs of externally defined classes, gcc doesn't
          either (info is probably gotten from ObjC runtime)  }
        if not(oo_is_external in def.ObjectOptions) then
          write_symtable_procdefs(CurrentAsmData.asmlists[al_dwarf_info],def.SymTable);
        if not Is_ObjC_Class_Or_Protocol(def) then
          finish_children;
      end;


    procedure TDebugInfoDwarf2.appenddef_object(list:TAsmList;def: TObjectDef);

      begin
        case def.ObjectType of
          odt_cppclass,
          odt_object:
            append_object_struct(def,false,def.ObjName);
          odt_interfacecom,
          odt_interfacecorba,
          odt_dispinterface,
          odt_helper,
          odt_class:
            begin
              { implicit pointer }
              append_entry(DW_TAG_pointer_type,false,[]);
              append_labelentry_ref(DW_AT_type,def_dwarf_class_struct_lab(def));
              finish_entry;

              append_object_struct(def,true,def.ObjName);
            end;
          odt_objcclass:
            { Objective-C class: same as regular class, except for
                a) Apple-specific tag that identifies it as an Objective-C class
                b) use extname^ instead of objname
            }
            append_object_struct(def,true,def.ObjExtName);
          odt_objcprotocol:
            begin
              append_entry(DW_TAG_pointer_type,false,[]);
              append_labelentry_ref(DW_AT_type,def_dwarf_lab(VoidPointerType));
              finish_entry;
            end;
          else
            InternalError(200602041);
        end;
      end;

    procedure TDebugInfoDwarf2.appenddef_set_intern(list:TAsmList;def: TSetDef; force_tag_set: boolean);
      var
        lab: TAsmLabel;
      begin
        if force_tag_set or
           (ds_dwarf_sets in CurrentSettings.DebugSwitches) then
          begin
            { current (20070704 -- patch was committed on 20060513) gdb cvs supports set types }

            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_set_type,false,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                DW_AT_byte_size,DW_FORM_data2,def.Size
                ])
            else
              append_entry(DW_TAG_set_type,false,[
                DW_AT_byte_size,DW_FORM_data2,def.Size
                ]);
            if Assigned(def.ElementDef) then
              begin
                if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
                  CurrentAsmData.getglobaldatalabel(lab)
                else
                  CurrentAsmData.getaddrlabel(lab);
                append_labelentry_ref(DW_AT_type,lab);
                finish_entry;
                if lab.bind=AB_GLOBAL then
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.create_global(lab,0))
                else
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(lab,0));
                { Sets of e.g. [1..5] are actually stored as a set of [0..7],
                  so write the exact boundaries of the set here. Let's hope no
                  debugger ever rejects this because this "subrange" type can
                  actually have a larger range than the original one.  }
                append_entry(DW_TAG_subrange_type,false,[
                  DW_AT_lower_bound,DW_FORM_sdata,def.SetBase,
                  DW_AT_upper_bound,DW_FORM_sdata,Get_Max_Value(def.ElementDef).svalue
                  ]);
                append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ElementDef))
              end
          end
        else
          begin
            { gdb versions which don't support sets refuse to load the debug }
            { info of modules that contain set tags                          }
            if Assigned(def.TypeSym) then
              append_entry(DW_TAG_base_type,false,[
                DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
                DW_AT_byte_size,DW_FORM_data2,def.Size
                ])
            else
              append_entry(DW_TAG_base_type,false,[
                DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
                DW_AT_byte_size,DW_FORM_data2,def.Size
                ]);
          end;
        finish_entry;
      end;

    procedure TDebugInfoDwarf2.appenddef_set(list:TAsmList;def: TSetDef);
      begin
        appenddef_set_intern(list,def,false);
      end;

    procedure TDebugInfoDwarf2.appenddef_undefined(list:TAsmList;def: TUndefinedDef);
      begin
        { gdb 6.4 doesn't support DW_TAG_unspecified_type so we
          replace it with a unsigned type with size 0 (FK)
        }
        append_entry(DW_TAG_base_type,false,[
          DW_AT_name,DW_FORM_string,'FormalDef'#0,
          DW_AT_encoding,DW_FORM_data1,DW_ATE_unsigned,
          DW_AT_byte_size,DW_FORM_data1,0
        ]);
        finish_entry;
      end;

    procedure TDebugInfoDwarf2.appenddef_variant(list:TAsmList;def: TVariantDef);
      begin
        { Variants are not represented here, but writing tvardata should be enough. }
        if Assigned(vardatadef) then
          appenddef_record_named(list,TRecordDef(vardatadef),'Variant');
      end;

{****************************************************************************
                              TDebugInfoDwarf3
****************************************************************************}

    procedure TDebugInfoDwarf3.append_labelentry_addr_ref(sym : TAsmSymbol);
      begin
        AddConstToAbbrev(ord(DW_FORM_ref_addr));
        { Since Dwarf 3 the length of a DW_FORM_ref_addr entry is not dependent on the pointer size of the
          target platform, but on the used Dwarf-format (32 bit or 64 bit) for the current compilation section. }
        if use_64bit_headers then
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.Create_type_sym(aitconst_64bit_unaligned,sym))
        else
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.Create_type_sym(aitconst_32bit_unaligned,sym));
      end;

    procedure TDebugInfoDwarf3.appenddef_array(list: TAsmList; def: TArrayDef);
      begin
        if not Is_Dynamic_Array(def) then
          begin
            inherited appenddef_array(list,def);
            exit;
          end;

        if Assigned(def.TypeSym) then
          append_entry(DW_TAG_array_type,true,[
            DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
            DW_AT_byte_stride,DW_FORM_udata,def.EleSize,
            DW_AT_data_location,DW_FORM_block1,2
            ])
        else
          append_entry(DW_TAG_array_type,true,[
            DW_AT_byte_stride,DW_FORM_udata,def.EleSize,
            DW_AT_data_location,DW_FORM_block1,2
            ]);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));

        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ElementDef));
        finish_entry;
        { to simplify things, we don't write a multidimensional array here }
        append_entry(DW_TAG_subrange_type,false,[
          DW_AT_lower_bound,DW_FORM_udata,0,
          DW_AT_upper_bound,DW_FORM_block1,15
          ]);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_dup)));
        { pointer = nil? }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_bra)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(5));
        { yes -> length = 0 }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_const1s)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(byte(-1)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_skip)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(3));
        { no -> load length }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit0)+SizeSIntType.Size));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_minus)));
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
        { skip to past end is not allowed, thus use a nop here }
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_nop)));
        append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.RangeDef));
        finish_entry;

        finish_children;
      end;


    procedure TDebugInfoDwarf3.appenddef_string(list: TAsmList; def: TStringDef);

      procedure addstringdef(const name: shortstring; chardef: TDef; deref: boolean; lensize: aint);
        var
          upperopcodes: LongInt;
        begin
          { deref=true -> ansi/unicode/widestring; deref = false -> short/longstring }
          if Assigned(def.TypeSym) then
            append_entry(DW_TAG_array_type,true,[
              DW_AT_name,DW_FORM_string,name+#0,
              DW_AT_data_location,DW_FORM_block1,2+ord(not(deref))
              ])
          else
            append_entry(DW_TAG_array_type,true,[
              DW_AT_data_location,DW_FORM_block1,2+ord(not(deref))
              ]);

          { in all cases we start with the address of the string }
          CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
          if deref then
            begin
              { ansi/unicode/widestring -> dereference the address of the string, and then
                we point to address of the string
              }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
            end
          else
            begin
              { shortstring characters begin at string[1], so add one to the string's address }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit0)+lensize));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus)))
            end;

          { reference to the element type of the string }
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(chardef));
          finish_entry;

          { now the information about the length of the string }
          if deref then
            begin
              if not (Is_WideString(def) and (tf_winlikewidestring in TargetInfo.flags)) then
                upperopcodes:=14
              else
                upperopcodes:=17;
              { lower bound is always 1, upper bound (length) needs to be calculated }
              append_entry(DW_TAG_subrange_type,false,[
                DW_AT_lower_bound,DW_FORM_udata,1,
                DW_AT_upper_bound,DW_FORM_block1,upperopcodes
                ]);

              { high(string) is stored sizeof(sizeint) bytes before the string data }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_dup)));
              { pointer = nil? }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_bra)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(4));
              { yes -> length = 0 }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit0)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_skip)));
              if upperopcodes=17 then
                { skip the extra deref_size argument and the division by two of the length }
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(6))
              else
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_16bit_unaligned(3));
              { no -> load length }
              if upperopcodes=17 then
                { for Windows WideString the size is always a DWORD }
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit4)))
              else
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit0)+SizeSIntType.Size));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_minus)));
              if upperopcodes=17 then
                begin
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref_size)));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(4));
                end
              else
                CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));

              { for widestrings, the length is specified in bytes, so divide by two }
              if (upperopcodes=17) then
                begin
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_lit1)));
                  CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_shr)));
                end;
              { skip to past end is not allowed, thus use a nop here }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_nop)));
            end
          else
            begin
              append_entry(DW_TAG_subrange_type,false,[
                DW_AT_lower_bound,DW_FORM_udata,1,
                DW_AT_upper_bound,DW_FORM_block1,3
                ]);
              { for shortstrings, the length is the first byte of the string }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
              { load 1 byte }
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref_size)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(lensize));
            end;
          finish_entry;

          finish_children;
        end;

      begin
        if (ds_dwarf_cpp in CurrentSettings.DebugSwitches) then
          begin
            // At least LLDB 6.0.0 does not like this implementation of string types.
            // Call the inherited base implementation, which works fine.
            inherited;
            exit;
          end;
        case def.StringType of
          st_shortstring:
            begin
              addstringdef('ShortString',CAnsiCharType,false,1);
            end;
          st_longstring:
            begin
{$ifdef cpu64bitaddr}
              addstringdef('LongString',CAnsiCharType,false,8);
{$else cpu64bitaddr}
              addstringdef('LongString',CAnsiCharType,false,4);
{$endif cpu64bitaddr}
           end;
         st_ansistring:
           begin
             addstringdef('AnsiString',CAnsiCharType,true,-1);
           end;
         st_unicodestring:
           begin
             addstringdef('UnicodeString',CWideCharType,true,-1);
           end;
         st_widestring:
           begin
             addstringdef('WideString',CWideCharType,true,-1)
           end;
        end;
      end;

    procedure TDebugInfoDwarf3.appenddef_file(list:TAsmList;def: TFileDef);
      begin
        if Assigned(def.TypeSym) then
          append_entry(DW_TAG_file_type,false,[
            DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0,
            DW_AT_byte_size,DW_FORM_data2,def.Size
            ])
        else
          append_entry(DW_TAG_file_type,false,[
            DW_AT_byte_size,DW_FORM_data2,def.Size
            ]);
        if TFileDef(def).FileTyp=ft_typed then
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(TFileDef(def).TypedFileDef));
        finish_entry;
      end;

    procedure TDebugInfoDwarf3.appenddef_formal(list:TAsmList;def: TFormalDef);
      begin
        if (ds_dwarf_cpp in CurrentSettings.DebugSwitches) then
          begin
            // Do not use DW_TAG_unspecified_type for C++ simulation.
            // At least LLDB 3.9.0 crashes in such case.
            // Call the inherited base implementation, which works fine.
            inherited;
            exit;
          end;

        append_entry(DW_TAG_unspecified_type,false,[]);
        finish_entry;
      end;

    procedure TDebugInfoDwarf3.appenddef_object(list:TAsmList;def: TObjectDef);

      procedure dostruct(tag: TDwarfTag; has_children: boolean=true);
        begin
          if Assigned(def.ObjName) then
            append_entry(tag,has_children,[
              DW_AT_name,DW_FORM_string,def.ObjRealName^+#0
              ])
          else
            append_entry(DW_TAG_structure_type,has_children,[]);
          append_attribute(DW_AT_byte_size,DW_FORM_udata,[TObjectSymTable(def.SymTable).DataSize]);
          { an old style object and a cpp class are accessed directly, so we do not need DW_AT_allocated and DW_AT_data_location tags,
            see issue #36017 }
          if not(Is_Object(def) or Is_CPPClass(def)) then
            begin
              { The pointer to the class-structure is hidden. The debug-information
                does not contain an implicit pointer, but the data-adress is dereferenced here.
                In case of a nil-pointer, report the class as being unallocated.
              }
              append_block1(DW_AT_allocated,2);
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
              append_block1(DW_AT_data_location,2);
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_push_object_address)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_deref)));
            end;
          finish_entry;
        end;

      procedure doimplicitpointer;
        var
          obj : TAsmLabel;
        begin
          if not(tf_dwarf_only_local_labels in TargetInfo.flags) then
            CurrentAsmData.getglobaldatalabel(obj)
          else
            CurrentAsmData.getaddrlabel(obj);
          { implicit pointer }
          append_entry(DW_TAG_pointer_type,false,[]);
          append_labelentry_ref(DW_AT_type,obj);
          finish_entry;

          CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(obj,0));
        end;

      procedure doparent(isinterface: boolean);
        begin
          if not Assigned(def.ChildOf) then
            exit;

          if isinterface then
            begin
              append_entry(DW_TAG_inheritance,false,[]);
            end
          else
            begin
              append_entry(DW_TAG_inheritance,false,[
                DW_AT_accessibility,DW_FORM_data1,DW_ACCESS_public,
                DW_AT_data_member_location,DW_FORM_block1,1+LengthULEB128(0)
              ]);
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_OP_plus_uconst)));
              CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_uleb128bit(0));
            end;
          append_labelentry_ref(DW_AT_type,def_dwarf_lab(def.ChildOf));
          finish_entry;
        end;

      var
        n: integer;

      begin
        case def.ObjectType of
          odt_objcclass,
          odt_objcprotocol:
            begin
              inherited;
              exit
            end;
          odt_cppclass,
          odt_object:
            begin
              append_object_struct(def,false,def.ObjName);
              exit;
            end;
          odt_interfacecom,
          odt_interfacecorba,
          odt_dispinterface:
            begin
              if (not Assigned(def.ChildOf)) and
                 ((not Assigned(def.ImplementedInterfaces)) or (def.ImplementedInterfaces.count = 0)) and
                (def.SymTable.SymList.count = 0)
              then
                begin
                dostruct(DW_TAG_interface_type, False);
                exit;
                end
              else
                dostruct(DW_TAG_interface_type);
              doparent(true);
            end;
          odt_helper,
          odt_class:
            begin
              append_entry(DW_TAG_pointer_type,false,[]);
              append_labelentry_ref(DW_AT_type,def_dwarf_class_struct_lab(def));
              finish_entry;

              append_object_struct(def,true,def.ObjRealName);
              Exit;
            end;
        else
          InternalError(200609171);
        end;

        { add implemented interfaces }
        if Assigned(def.ImplementedInterfaces) then
          for n := 0 to def.ImplementedInterfaces.count-1 do
            begin
              append_entry(DW_TAG_inheritance,false,[]);
              append_labelentry_ref(DW_AT_type,def_dwarf_lab(TImplementedInterface(def.ImplementedInterfaces[n]).IntfDef));
              finish_entry;
            end;

        { add members }
        def.SymTable.SymList.ForEachCall(@enum_membersyms_callback,nil);
        finish_children;
      end;

    procedure TDebugInfoDwarf3.appenddef_set(list:TAsmList;def: TSetDef);
      begin
        appenddef_set_intern(list,def,true);
      end;

    procedure TDebugInfoDwarf3.appenddef_undefined(list:TAsmList;def: TUndefinedDef);
      begin
        { ??? can a undefined def have a typename ? }
        if Assigned(def.TypeSym) then
          append_entry(DW_TAG_unspecified_type,false,[
            DW_AT_name,DW_FORM_string,symname(def.TypeSym, false)+#0
            ])
        else
          append_entry(DW_TAG_unspecified_type,false,[
            ]);
        finish_entry;
      end;

    procedure TDebugInfoDwarf3.appenddef_variant(list:TAsmList;def: TVariantDef);
      const
        VARIANTS: array[1..27] of record
          Value: Word;
          Name: String;
          { some fields are only supported by some features }
          Features : TFeatures
        end = (
          (value:0;     name:'';Features: []),
          (value:1;     name:'';Features: []),
          (value:2;     name:'VSMALLINT';Features: []),
          (value:3;     name:'VINTEGER';Features: []),
          (value:4;     name:'VSINGLE';Features: [f_softfpu]),
          (value:5;     name:'VDOUBLE';Features: [f_softfpu]),
          (value:6;     name:'VCURRENCY';Features: [f_softfpu]),
          (value:7;     name:'VDATE';Features: [f_softfpu]),
          (value:8;     name:'VOLESTR';Features: []),
          (value:9;     name:'VDISPATCH';Features: []),
          (value:10;    name:'VERROR';Features: []),
          (value:11;    name:'VBOOLEAN';Features: []),
          (value:12;    name:'';Features: []),
          (value:13;    name:'VUNKNOWN';Features: []),
          (value:14;    name:'';Features: []),
          (value:16;    name:'VSHORTINT';Features: []),
          (value:17;    name:'VBYTE';Features: []),
          (value:18;    name:'VWORD';Features: []),
          (value:19;    name:'VLONGWORD';Features: []),
          (value:20;    name:'VINT64';Features: []),
          (value:21;    name:'VQWORD';Features: []),
          (value:36;    name:'VRECORD';Features: []),
          (value:$48;   name:'';Features: []),
          (value:$100;  name:'VSTRING';Features: []),
          (value:$101;  name:'VANY';Features: []),
          (value:$2000; name:'VARRAY';Features: []),
          (value:$4000; name:'VPOINTER';Features: [])
        );
      var
        fs: TFieldVarSym;
        lbl: TAsmLabel;
        idx: integer;
      begin
        { it could be done with DW_TAG_variant for the union part (if that info was available)
          now we do it manually for variants (MWE) }

        { struct }
        append_entry(DW_TAG_structure_type,true,[
          DW_AT_name,DW_FORM_string,'Variant'#0,
          DW_AT_byte_size,DW_FORM_udata,vardatadef.Size
          ]);
        finish_entry;

        append_entry(DW_TAG_variant_part,true,[
          ]);
        CurrentAsmData.getaddrlabel(lbl);
        append_labelentry_ref(DW_AT_discr,lbl);
        finish_entry;

        { discriminant }
        fs := TFieldVarSym(vardatadef.SymTable.Find('VTYPE'));
        if (fs = nil) or (fs.typ <> FieldVarSym) then
          InternalError(200609271);
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAISymbol.Create(lbl,0));
        appendsym_fieldvar(list,fs);

        { variants }
        for idx := Low(VARIANTS) to High(VARIANTS) do
          begin
            if (Features*VARIANTS[idx].Features)=VARIANTS[idx].Features then
              begin
                if VARIANTS[idx].name <> '' then
                  begin
                    append_entry(DW_TAG_variant,true,[
                      DW_AT_discr_value,DW_FORM_udata,VARIANTS[idx].Value
                      ]);
                    finish_entry;
                    fs := TFieldVarSym(vardatadef.SymTable.Find(VARIANTS[idx].name));
                    if (fs = nil) or (fs.typ <> FieldVarSym) then
                      InternalError(2006092702+idx);
                    appendsym_fieldvar(list,fs);
                    finish_children; { variant }
                  end
                else
                  begin
                    append_entry(DW_TAG_variant,false,[
                      DW_AT_discr_value,DW_FORM_udata,VARIANTS[idx].Value
                      ]);
                    finish_entry;
                  end;

              end;
          end;


        finish_children; { variant part }

        finish_children; { struct }
      end;

    function TDebugInfoDwarf3.dwarf_version: Word;
      begin
        Result:=3;
      end;

    function TDebugInfoDwarf3.symdebugname(sym: TSym): String;
      begin
        Result:=sym.realname;
      end;


    { TDebugInfoDwarf4 }

    function TDebugInfoDwarf4.dwarf_version: Word;
    begin
      Result:=4;
    end;

    procedure TDebugInfoDwarf5.insert_cu_header_after_version;
    begin
      { DWARF-5 has a different order of fields in the header }
      { unit type }
      CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(ord(DW_UT_compile))); // DW_UT_compile = 0x01
      { address size }
      CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_8bit(sizeof(PInt)));

      { abbrev table (=relative from section start)}
      if not(tf_dwarf_relative_addresses in TargetInfo.flags) then
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_type_sym(offsetabstype,
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrev0',AB_LOCAL,AT_METADATA,VoidPointerType)))
      else
        CurrentAsmData.asmlists[al_dwarf_info].concat(TAIConst.create_rel_sym(offsetreltype,
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrevsection0',AB_LOCAL,AT_METADATA,VoidPointerType),
          CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'debug_abbrev0',AB_LOCAL,AT_METADATA,VoidPointerType)));
    end;

    function TDebugInfoDwarf5.dwarf_version: Word;
    begin
      Result:=5;
    end;


{****************************************************************************
****************************************************************************}
    const
      dbg_dwarf3_info : TDbgInfo =
         (
           id     : dbg_dwarf3;
           idtxt  : 'DWARF3';
         );

      dbg_dwarf4_info : TDbgInfo =
         (
           id     : dbg_dwarf4;
           idtxt  : 'DWARF4';
         );

      dbg_dwarf5_info : TDbgInfo =
         (
           id     : dbg_dwarf5;
           idtxt  : 'DWARF5';
         );


initialization
  RegisterDebugInfo(dbg_dwarf3_info,TDebugInfoDwarf3);
  RegisterDebugInfo(dbg_dwarf4_info,TDebugInfoDwarf4);
  RegisterDebugInfo(dbg_dwarf5_info,TDebugInfoDwarf5);

end.
