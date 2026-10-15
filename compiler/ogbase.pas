{
    Copyright (c) 1998-2006 by Peter Vreman

    Contains the base stuff for binary object file writers

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
unit ogbase;

{$i fpcdefs.inc}

interface

    uses
      { common }
      CUtils,
      CClasses,
      { targets }
      Systems,GlobType,
      { outputwriters }
      owbase,
      { assembler }
      aasmbase,
      CPUInfo;

    type
      TObjSection = class;
      TObjData = class;

      TObjRelocationType = (
         { Relocation to absolute address }
         RELOC_ABSOLUTE,
{$ifdef x86_64}
         { 32bit Relocation to absolute address }
         RELOC_ABSOLUTE32,
         { 64 bit coff only }
         RELOC_RELATIVE_1,
         RELOC_RELATIVE_2,
         RELOC_RELATIVE_3,
         RELOC_RELATIVE_4,
         RELOC_RELATIVE_5,
         { PIC }
         RELOC_GOTPCREL,
         RELOC_GOTPCRELX,
         RELOC_REX_GOTPCRELX,
         RELOC_PLT32,
         RELOC_TLSGD,
         RELOC_TPOFF,
{$endif x86_64}
{$ifdef i386}
         { PIC }
         RELOC_GOTPC,
         RELOC_GOT32,
         RELOC_PLT32,
         RELOC_TLSGD,
         RELOC_NTPOFF,
{$endif i386}

{$ifdef aarch64}
         RELOC_ABSOLUTE32,
         RELOC_RELATIVE_26,
         RELOC_RELATIVE_19,
         RELOC_ADR_PREL_LO21,
         RELOC_ADR_PREL_PG_HI21,
         RELOC_ADD_ABS_LO12,
         RELOC_LDST8_ABS_LO12,
{$endif aarch64}

         { Relative relocation }
         RELOC_RELATIVE,
         { PECoff (Windows) RVA relocation }
         RELOC_RVA,
         { PECoff (Windows) section relocation, required by DWARF debug info }
         RELOC_SECREL32,
         { Generate a 0 value at the place of the relocation,
           this is used to remove unused vtable entries }
         RELOC_ZERO,
         { No relocation is needed. It is used in ARM object files. }
         RELOC_NONE,
         { Darwin relocation, using PAIR }
         RELOC_PIC_PAIR,
         { Relative to GOT/gp }
         RELOC_GOTOFF,
         { Untranslated target-specific value }
         RELOC_RAW,
         { offset in TLS block }
         RELOC_DTPOFF
      );

{$if defined(x86_64) or defined(aarch64)}
    { no special aliases for x86_64 }
{$else}
    const
      RELOC_ABSOLUTE32 = RELOC_ABSOLUTE;
{$endif}

    const
      { stab types }
      N_GSYM = $20;
      N_STSYM = 38;     { initialized const }
      N_LCSYM = 40;     { non initialized variable}
      N_Function = $24; { function or const }
      N_TextLine = $44;
      N_DataLine = $46;
      N_BssLine = $48;
      N_RSYM = $40;     { register variable }
      N_LSYM = $80;
      N_tsym = 160;
      N_SourceFile = $64;
      N_IncludeFile = $84;
      N_BINCL = $82;
      N_EINCL = $A2;
      N_LBRAC = $C0;
      N_EXCL  = $C2;
      N_RBRAC = $E0;

      { GNU extensions }
      debuglinkname='.gnu_debuglink';

      { TObjRelocation.flags }
      { 'ftype' field contains platform-specific value }
      rf_raw = 1;
      { relocation must be added to dynamic list }
      rf_dynamic = 2;
      { relocation target is absent/irrelevant (e.g. R_ARM_V4BX) }
      rf_nosymbol = 4;

    type
      TObjSectionOption = (
       { Has Data available in the file }
       oso_Data,
       { Is loaded into memory }
       oso_load,
       { Writable }
       oso_write,
       { Contains executable instructions }
       oso_executable,
       { Never discard section }
       oso_keep,
       { Procedure Linkage Table specific treatment }
       oso_plt,
       { Contains debug info and can be stripped }
       oso_debug,
       { Contains only strings }
       oso_strings,
       { Must be cloned when writing separate debug file }
       oso_debug_copy,
       { Has relocations with explicit addends (ELF-specific) }
       oso_rela_relocs,
       { Supports bss-like allocation of data, even though it is written in file (i.e. also has oso_Data) }
       oso_sparse_data,
       { Section to support the resolution of multiple symbols with the same name }
       oso_comdat,
       { section containing thread variables }
       oso_threadvar,
       { being a notes section }
       oso_note,
       { arm attributes section }
       oso_arm_attributes
     );

     TObjSectionOptions = set of TObjSectionOption;

     TObjSectionComdatSelection = (
       { Section is not a COMDAT section }
       oscs_none,
       { Select any of the symbols }
       oscs_any,
       { Select any symbol, but abort if they differ in size }
       oscs_same_size,
       { Select any symbol, but abort if they differ in size or content }
       oscs_exact_match,
       { Select the symbol only if the associated symbol is linked as well }
       oscs_associative,
       { Select the largest symbol }
       oscs_largest
     );


     TObjSectionOfs = PUint;


     TObjSectionGroup = class;

     TObjSymbol = class(TFPHashObject)
     public
       bind       : TAsmsymbind;
       typ        : TAsmsymtype;
       { Current assemble pass, used to detect duplicate labels }
       pass       : byte;
       { how the symbol is referenced (target-specific bitfield) }
       refs       : byte;
       symidx     : LongInt;
       objsection : TObjSection;
       offset,
       size       : TObjSectionOfs;
       { Darwin asm is using indirect symbols resolving }
       indsymbol  : TObjSymbol;

       { Used by the OMF object format and its complicated relocation records }
       group: TObjSectionGroup;

       constructor create(AList:TFPHashObjectList;const AName:string);virtual;
       function  ToString:AnsiString;override;
       function  address:qword;
       procedure SetAddress(apass:byte;aobjsec:TObjSection;abind:TAsmsymbind;atyp:TAsmsymtype);
       function  ObjData: TObjData;
     end;
     TObjSymbolClass = class of TObjSymbol;

     { Stabs is common for all targets }
     TObjStabEntry=packed record
        strpos  : LongInt;
        ntype   : byte;
        nother  : byte;
        ndesc   : word;
        nvalue  : LongInt;
     end;
     PObjStabEntry=^TObjStabEntry;

     TObjRelocation = class
     private
        function GetType:TObjRelocationType;
        procedure SetType(v:TObjRelocationType);
     public
        DataOffset,
        orgsize    : TObjSectionOfs;  { COFF: original size of the symbol to relocate }
                                      { ELF: explicit addend }
        symbol     : TObjSymbol;
        objsection : TObjSection; { only used if symbol=nil }
        group      : TObjSectionGroup; { only used if symbol=nil and objsection=nil }
        ftype      : byte;
        size       : byte;
        flags      : byte;
        constructor CreateSymbol(ADataOffset:TObjSectionOfs;s:TObjSymbol;Atyp:TObjRelocationType);
        constructor CreateSection(ADataOffset:TObjSectionOfs;aobjsec:TObjSection;Atyp:TObjRelocationType);
        constructor CreateGroup(ADataOffset:TObjSectionOfs;grp:TObjSectionGroup;Atyp:TObjRelocationType);
        constructor CreateRaw(ADataOffset:TObjSectionOfs;s:TObjSymbol;ARawType:byte);
        function TargetName:TSymStr;
        function ToString: AnsiString; override;
        property typ: TObjRelocationType read GetType write SetType;
     end;

     TObjSection = class(TFPHashObject)
     private
       FData       : TDynamicArray;
       FSecOptions : TObjSectionOptions;
       FCachedFullName : PShortString;
       FSizeLimit : TObjSectionOfs;
       procedure SetSecOptions(Aoptions:TObjSectionOptions);
       procedure SectionTooLargeError;
     protected
       function GetAltName: string; virtual;
     public
       ObjData    : TObjData;
       index      : LongWord;  { index of section in section headers }
       SecSymIdx  : LongInt;   { index for the section in symtab }
       SecAlign   : LongInt;   { alignment of the section }
       { section Data }
       Size,
       DataPos    : TObjSectionOfs;
       MemPos     : qword;
       Group      : TObjSectionGroup;
       AssociativeSection : TObjSection;
       ComdatSelection : TObjSectionComdatSelection;
       DataAlignBytes : shortint;
       { Relocations (=references) to other sections }
       ObjRelocations : TFPObjectList;
       USed        : Boolean;
       constructor create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);virtual;
       destructor  Destroy;override;
       function  ToString:AnsiString;override;
       function  write(const d;l:TObjSectionOfs):TObjSectionOfs;
       procedure writeInt8(v: int8);
       procedure writeInt16LE(v: int16);
       procedure writeInt16BE(v: int16);
       procedure writeInt32LE(v: int32);
       procedure writeInt32BE(v: int32);
       procedure writeInt64LE(v: int64);
       procedure writeInt64BE(v: int64);
       procedure writeUInt8(v: uint8);
       procedure writeUInt16LE(v: uint16);
       procedure writeUInt16BE(v: uint16);
       procedure writeUInt32LE(v: uint32);
       procedure writeUInt32BE(v: uint32);
       procedure writeUInt64LE(v: uint64);
       procedure writeUInt64BE(v: uint64);
       { writes string plus zero byte }
       function  WriteStr(const s:string):TObjSectionOfs;
       function  WriteZeros(l:LongWord):TObjSectionOfs;
       { writes content of s without null termination }
       function  WriteBytes(const s:string):TObjSectionOfs;
       procedure writeReloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);virtual;
       function  setmempos(mpos:qword):qword;
       procedure setDatapos(var dpos:TObjSectionOfs);
       procedure alloc(l:TObjSectionOfs);
       procedure addsymReloc(ofs:TObjSectionOfs;p:TObjSymbol;Reloctype:TObjRelocationType);
       procedure addsectionReloc(ofs:TObjSectionOfs;aobjsec:TObjSection;Reloctype:TObjRelocationType);
       procedure addrawReloc(ofs:TObjSectionOfs;p:TObjSymbol;RawReloctype:byte);
       procedure ReleaseData;
       function  FullName:string;
       property  Data:TDynamicArray read FData;
       property  SecOptions:TObjSectionOptions read FSecOptions write SetSecOptions;
       property  SizeLimit:TObjSectionOfs read FSizeLimit write FSizeLimit;
     end;
     TObjSectionClass = class of TObjSection;

     TObjSectionGroup = class(TFPHashObject)
     public
       index: LongWord;  { index of group in group headers }
       members: array of TObjSection;
       iscomdat: boolean;
     end;
     TObjSectionGroupClass = class of TObjSectionGroup;

     TString80 = string[80];

     TObjSymbolList = class(TFPHashObjectList)
     public
       Owner: TObjData;
     end;


     TRelocDataInt = aint;


     TObjData = class(TLinkedListItem)
     private
       FCurrObjSec : TObjSection;
       FObjSectionList  : TFPHashObjectList;
       FCObjSymbol      : TObjSymbolClass;
       FCObjSection     : TObjSectionClass;
       FCObjSectionGroup: TObjSectionGroupClass;
       { Symbols that will be defined in this object file }
       FObjSymbolList    : TObjSymbolList;
       FCachedAsmSymbolList : TFPObjectList;
       { Special info sections that are written to during object generation }
       FStabsObjSec,
       FStabStrObjSec : TObjSection;
       FGroupsList : TFPHashObjectList;
       FCPUType : TCPUType;
       procedure section_reset(p:TObject;arg:pointer);
       procedure section_afteralloc(p:TObject;arg:pointer);
       procedure section_afterwrite(p:TObject;arg:pointer);
     protected
       FName       : TString80;
       property CObjSection:TObjSectionClass read FCObjSection write FCObjSection;
       property CObjSectionGroup: TObjSectionGroupClass read FCObjSectionGroup write FCObjSectionGroup;
     public
       CurrPass  : byte;
       ExecStack : boolean;
       constructor create(const n:string);virtual;
       destructor  Destroy;override;
       { Sections }
       function  sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;virtual;abstract;
       class function sectiontype2options(atype:TAsmSectiontype):TObjSectionOptions;
       function  sectiontype2align(atype:TAsmSectiontype):LongInt;virtual;
       class procedure sectiontype2progbitsandflags(atype:TAsmSectiontype;out progbits:TSectionProgbits;out flags:TSectionFlags);virtual;
       function  createsection(atype:TAsmSectiontype;const aname:string='';aorder:TAsmSectionOrder=secorder_default):TObjSection;virtual;
       function  createsection(atype:TAsmSectiontype;secflags:TSectionFlags;aprogbits:TSectionProgbits;const aname:string='';aorder:TAsmSectionOrder=secorder_default):TObjSection;virtual;
       function  createsection(const aname:string;aalign:LongInt;aoptions:TObjSectionOptions;DiscardDuplicate:boolean=true):TObjSection;virtual;
       function  createsectiongroup(const aname:string):TObjSectionGroup;
       procedure CreateDebugSections;virtual;
       function  findsection(const aname:string):TObjSection;
       procedure setsection(asec:TObjSection);
       { Symbols }
       function  createsymbol(const aname:string):TObjSymbol;
       function  symboldefine(asmsym:TAsmSymbol):TObjSymbol;
       function  symboldefine(const aname:string;abind:TAsmsymbind;atyp:TAsmsymtype):TObjSymbol;
       function  symbolref(asmsym:TAsmSymbol):TObjSymbol;
       function  symbolref(const aname:string):TObjSymbol;
       procedure symbolpairdefine(akind: TSymbolPairKind;const asym, avalue: string);virtual;
       procedure ResetCachedAsmSymbols;
       { Allocation }
       procedure alloc(len:TObjSectionOfs);
       procedure allocalign(len:LongInt);
       procedure writebytes(const Data;len:TObjSectionOfs);
       procedure writebytes(const Data : TByteDynArray;len:TObjSectionOfs);
       procedure writebytes(const Data : TAnsiCharDynArray;len:TObjSectionOfs);
       procedure writeInt8(v: int8);
       procedure writeInt16LE(v: int16);
       procedure writeInt16BE(v: int16);
       procedure writeInt32LE(v: int32);
       procedure writeInt32BE(v: int32);
       procedure writeInt64LE(v: int64);
       procedure writeInt64BE(v: int64);
       procedure writeUInt8(v: uint8);
       procedure writeUInt16LE(v: uint16);
       procedure writeUInt16BE(v: uint16);
       procedure writeUInt32LE(v: uint32);
       procedure writeUInt32BE(v: uint32);
       procedure writeUInt64LE(v: uint64);
       procedure writeUInt64BE(v: uint64);
       procedure writeReloc(Data:TRelocDataInt;len:aword;p:TObjSymbol;Reloctype:TObjRelocationType);virtual;abstract;
       procedure beforealloc;virtual;
       procedure beforewrite;virtual;
       procedure afteralloc;virtual;
       procedure afterwrite;virtual;
       procedure resetsections;
       procedure layoutsections(var datapos:TObjSectionOfs);
       property Name:TString80 read FName;
       property CurrObjSec:TObjSection read FCurrObjSec;
       property ObjSymbolList:TObjSymbolList read FObjSymbolList;
       property ObjSectionList:TFPHashObjectList read FObjSectionList;
       property GroupsList:TFPHashObjectList read FGroupsList;
       property StabsSec:TObjSection read FStabsObjSec write FStabsObjSec;
       property StabStrSec:TObjSection read FStabStrObjSec write FStabStrObjSec;
       property CObjSymbol: TObjSymbolClass read FCObjSymbol write FCObjSymbol;
       { Current CPU type for the internal asm writer.
         Instructions, not supported by the given CPU should produce an error.
         A value of 'cpu_none' means no restrictions (all instructions should be accepted) }
       property CPUType : TCPUType read FCPUType write FCPUType;
     end;
     TObjDataClass = class of TObjData;

     TObjOutput = class
      private
        FCObjData : TObjDataClass;
      protected
        { writer }
        FWriter    : TObjectWriter;
        function  WriteData(Data:TObjData):boolean;virtual;abstract;
        property CObjData : TObjDataClass read FCObjData write FCObjData;
        procedure WriteSectionContent(Data:TObjData);
      public
        constructor create(AWriter:TObjectWriter);virtual;
        destructor  Destroy;override;
        function  newObjData(const n:string):TObjData;
        function  startObjectfile(const fn:string):boolean;
        function  writeobjectfile(Data:TObjData):boolean;
        procedure exportsymbol(p:TObjSymbol);
        property Writer:TObjectWriter read FWriter;
      end;
      TObjOutputClass=class of TObjOutput;

      TObjInput = class
      private
        FCObjData : TObjDataClass;
      protected
        { reader }
        FReader    : TObjectReader;
        InputFileName : string;
        property CObjData : TObjDataClass read FCObjData write FCObjData;
        procedure ReadSectionContent(Data:TObjData);
      public
        constructor create;virtual;
        function  ReadObjData(AReader:TObjectReader;out Data:TObjData):boolean;virtual;abstract;
        class function CanReadObjData(AReader:TObjectReader):boolean;virtual;
        procedure inputerror(const s : string);
      end;
      TObjInputClass=class of TObjInput;

      TImportLibrary = class(TFPHashObject)
      private
        FImportSymbolList : TFPHashObjectList;
      public
        constructor create(AList:TFPHashObjectList;const AName:string);
        destructor  Destroy;override;
        property ImportSymbolList:TFPHashObjectList read FImportSymbolList;
      end;

      TImportSymbol = class(TFPHashObject)
      private
        FOrdNr  : LongInt;
        FIsVar  : boolean;
        FMangledName : string;
      public
        constructor create(AList:TFPHashObjectList;const AName,AMangledName:string;AOrdNr:LongInt;AIsVar:boolean);
        property OrdNr: LongInt read FOrdNr;
        property MangledName: string read FMangledName;
        property IsVar: boolean read FIsVar;
      end;

    const
      SectionDataMaxGrow = 4096;

    function align_aword(v:aword;a:LongWord):aword;
    function align_qword(v:qword;a:LongWord):qword;
    function align_objsecofs(v:TObjSectionOfs;a:LongWord):TObjSectionOfs;
    procedure MaybeSwapStab(var v:TObjStabEntry);

implementation

    uses
      SysUtils,
      Globals,Verbose
{$ifdef OMFOBJSUPPORT}
      ,omfbase
{$endif OMFOBJSUPPORT}
      ;

{$ifdef MEMDEBUG}
    var
      memobjsymbols,
      memobjsections : TMemDebug;
{$endif MEMDEBUG}

{*****************************************************************************
                                 Helpers
*****************************************************************************}

    function align_aword(v:aword;a:LongWord):aword;
      begin
        if a>0 then
          a:=a-1;
        result:=(v+a) and aword(not aword(a));
      end;


    function align_qword(v:qword;a:LongWord):qword;
      begin
        if a>0 then
          a:=a-1;
        result:=(v+a) and qword(not qword(a));
      end;


    function align_objsecofs(v:TObjSectionOfs;a:LongWord):TObjSectionOfs;
      begin
        if a>0 then
          a:=a-1;
        result:=(v+a) and TObjSectionOfs(not TObjSectionOfs(a));
      end;


    procedure MaybeSwapStab(var v:TObjStabEntry);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.strpos:=SwapEndian(v.strpos);
            v.nvalue:=SwapEndian(v.nvalue);
            v.ndesc:=SwapEndian(v.ndesc);
          end;
      end;

{*****************************************************************************
                                 TObjSymbol
*****************************************************************************}

    constructor TObjSymbol.create(AList:TFPHashObjectList;const AName:string);
      begin
        inherited create(AList,AName);
        bind:=AB_EXTERNAL;
        typ:=AT_NONE;
        symidx:=-1;
        size:=0;
        offset:=0;
        objsection:=nil;
      end;


    function TObjSymbol.ToString: AnsiString;
      var
        objsectionstr: AnsiString;
      begin
        if Assigned(objsection) then
          objsectionstr:=objsection.ToString
        else
          objsectionstr:='nil';
        WriteStr(Result,'(Name:',Name,';bind:',bind,';typ:',typ,';pass:',pass,
          ';refs:',refs,';symidx:',symidx,';objsection:',objsectionstr,';offset:',
          offset,';size:',size,')');
      end;


    function TObjSymbol.address:qword;
      begin
        if Assigned(objsection) then
          result:=offset+objsection.mempos
        else
          result:=0;
      end;


    procedure TObjSymbol.SetAddress(apass:byte;aobjsec:TObjSection;abind:TAsmsymbind;atyp:TAsmsymtype);
      begin
        if not(abind in [AB_GLOBAL,AB_PRIVATE_EXTERN,AB_LOCAL,AB_COMMON,AB_IMPORT,AB_WEAK]) then
          InternalError(200603016);
        if not Assigned(aobjsec) then
          InternalError(200603017);
        if (bind in [AB_EXTERNAL,AB_LAZY]) or
          { Allow a global definition to replace a common symbol. }
           ((abind=AB_GLOBAL) and (bind=AB_COMMON)) then
          begin
            { Do not change the AB_TYPE of common symbols yet }
            { This will be done in FixupSymbols }
            if (pass<>0) or (bind<>AB_COMMON) then
              bind:=abind;
            typ:=atyp;
          end
        else
          begin
            if pass=apass then
              begin
                Message1(asmw_e_duplicate_label,name);
                exit;
              end;
          end;
        pass:=apass;
        { Code can never grow after a pass }
        if Assigned(objsection) and
           (objsection=aobjsec) and
           (aobjsec.size>offset) then
          InternalError(200603014);
        objsection:=aobjsec;
        offset:=aobjsec.size;
      end;


    function TObjSymbol.ObjData: TObjData;
      begin
        result:=(OwnerList as TObjSymbolList).Owner;
      end;



{****************************************************************************
                              TObjRelocation
****************************************************************************}

    constructor TObjRelocation.CreateSymbol(ADataOffset:TObjSectionOfs;s:TObjSymbol;Atyp:TObjRelocationType);
      begin
        if not Assigned(s) then
          InternalError(200603034);
        DataOffset:=ADataOffset;
        Symbol:=s;
        OrgSize:=0;
        Group:=nil;
        ObjSection:=nil;
        ftype:=ord(Atyp);
      end;


    constructor TObjRelocation.CreateSection(ADataOffset:TObjSectionOfs;aobjsec:TObjSection;Atyp:TObjRelocationType);
      begin
        if not Assigned(aobjsec) then
          InternalError(200603036);
        DataOffset:=ADataOffset;
        Symbol:=nil;
        OrgSize:=0;
        Group:=nil;
        ObjSection:=aobjsec;
        ftype:=ord(Atyp);
      end;


    constructor TObjRelocation.CreateGroup(ADataOffset:TObjSectionOfs;grp:TObjSectionGroup;Atyp:TObjRelocationType);
      begin
        if not Assigned(grp) then
          InternalError(2015111201);
        DataOffset:=ADataOffset;
        Symbol:=nil;
        ObjSection:=nil;
        OrgSize:=0;
        Group:=grp;
        ftype:=ord(Atyp);
      end;


    constructor TObjRelocation.CreateRaw(ADataOffset:TObjSectionOfs;s:TObjSymbol;ARawType:byte);
      begin
        { nil symbol is allowed here }
        DataOffset:=ADataOffset;
        Symbol:=s;
        ObjSection:=nil;
        Group:=nil;
        orgsize:=0;
        ftype:=ARawType;
        flags:=rf_raw;
      end;


    function TObjRelocation.GetType:TObjRelocationType;
      begin
        if (flags and rf_raw)=0 then
          result:=TObjRelocationType(ftype)
        else
          result:=RELOC_RAW;
      end;


    procedure TObjRelocation.SetType(v:TObjRelocationType);
      begin
        ftype:=ord(v);
        flags:=flags and (not rf_raw);
      end;


    function TObjRelocation.TargetName:TSymStr;
      begin
        if Assigned(symbol) then
          if symbol.typ=AT_SECTION then
            result:=symbol.objsection.name
          else
            result:=symbol.Name
        else
          result:=objsection.Name;
      end;


    function TObjRelocation.ToString: AnsiString;
      var
        typstr,
        symbolstr,
        objsectionstr,
        groupstr: AnsiString;
      begin
        Str(typ,typstr);
        if Assigned(symbol) then
          symbolstr:=symbol.ToString
        else
          symbolstr:='nil';
        if Assigned(objsection) then
          objsectionstr:=objsection.ToString
        else
          objsectionstr:='nil';
        if Assigned(group) then
          groupstr:=group.ToString
        else
          groupstr:='nil';
        Result:='(typ:'+typstr+';DataOffset:'+ToStr(DataOffset)+
          ';orgsize:'+ToStr(orgsize)+';symbol:'+symbolstr+
          ';objsection:'+objsectionstr+';group:'+groupstr+
          ';ftype:'+ToStr(ftype)+';size:'+ToStr(size)+
          ';flags:'+ToStr(flags)+')';
      end;

{****************************************************************************
                              TObjSection
****************************************************************************}

    constructor TObjSection.create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);
      begin
        inherited Create(AList,Aname);
        { Data }
        Size:=0;
        Datapos:=0;
        mempos:=0;
        FData:=Nil;

        FSizeLimit:=high(TObjSectionOfs);

        { Setting the secoptions allocates Data if needed }
        secoptions:=Aoptions;
        if (Aalign and (Aalign-1))<>0 then
          InternalError(2022010401); { alignment is not a power of two }
        secalign:=Aalign;
        secsymidx:=0;
        { relocation }
        ObjRelocations:=TFPObjectList.Create(true);
      end;


    destructor TObjSection.Destroy;
      begin
        if Assigned(Data) then
          begin
            FData.Free;
            FData := nil;
          end;
        StringDispose(FCachedFullName);
        ObjRelocations.Free;
        ObjRelocations := nil;
        inherited Destroy;
      end;


    function TObjSection.ToString: AnsiString;
      begin
        System.WriteStr(Result,'(Name:',Name,';index',index,';SecSymIdx:',SecSymIdx,
          ';SecAlign:',SecAlign,';Size:',Size,';DataPos:',DataPos,';MemPos:',
          MemPos,';DataAlignBytes:',DataAlignBytes,';Used:',Used,')');
      end;


    procedure TObjSection.SetSecOptions(Aoptions:TObjSectionOptions);
      begin
        FSecOptions:=FSecOptions+AOptions;
        if (oso_Data in secoptions) and
           not Assigned(FData) then
          FData:=TDynamicArray.Create(SectionDataMaxGrow);
      end;


    procedure TObjSection.SectionTooLargeError;
      begin
        if oso_executable in SecOptions then
          Message(asmw_f_code_segment_too_large)
        else
          Message(asmw_f_data_segment_too_large);
      end;


    function TObjSection.GetAltName: string;
      begin
        result:='';
      end;


    function TObjSection.write(const d;l:TObjSectionOfs):TObjSectionOfs;
      begin
        result:=size;
        if Assigned(Data) then
          begin
            if Size<>Data.size then
              InternalError(200602281);
{$ifndef cpu64bitaddr}
            if (qword(size)+l)>SizeLimit then
              SectionTooLargeError;
{$endif}
            Data.write(d,l);
            inc(Size,l);
          end
        else
          InternalError(200602289);
      end;


    procedure TObjSection.writeInt8(v: int8);
      begin
        write(v,1);
      end;


    procedure TObjSection.writeInt16LE(v: int16);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,2);
      end;


    procedure TObjSection.writeInt16BE(v: int16);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,2);
      end;


    procedure TObjSection.writeInt32LE(v: int32);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,4);
      end;


    procedure TObjSection.writeInt32BE(v: int32);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,4);
      end;


    procedure TObjSection.writeInt64LE(v: int64);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,8);
      end;


    procedure TObjSection.writeInt64BE(v: int64);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,8);
      end;


    procedure TObjSection.writeUInt8(v: uint8);
      begin
        write(v,1);
      end;


    procedure TObjSection.writeUInt16LE(v: uint16);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,2);
      end;


    procedure TObjSection.writeUInt16BE(v: uint16);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,2);
      end;


    procedure TObjSection.writeUInt32LE(v: uint32);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,4);
      end;


    procedure TObjSection.writeUInt32BE(v: uint32);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,4);
      end;


    procedure TObjSection.writeUInt64LE(v: uint64);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        write(v,8);
      end;


    procedure TObjSection.writeUInt64BE(v: uint64);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        write(v,8);
      end;


    function TObjSection.WriteStr(const s:string):TObjSectionOfs;
      var
        b: byte;
      begin
        result:=Write(s[1],length(s));
        b:=0;
        Write(b,1);
      end;


    function TObjSection.WriteBytes(const s:string):TObjSectionOfs;
      begin
        result:=Write(s[1],length(s));
      end;


    function TObjSection.WriteZeros(l:LongWord):TObjSectionOfs;
      var
        empty : array[0..1023] of byte;
      begin
        result:=Size;
        if l>sizeof(empty) then
          begin
            fillchar(empty,sizeof(empty),0);
            while l>sizeof(empty) do
              begin
                Write(empty,sizeof(empty));
                Dec(l,sizeof(empty));
              end;
            if l>0 then
              Write(empty,l);
          end
        else if l>0 then
          begin
            fillchar(empty,l,0);
            Write(empty,l);
          end;
      end;


    { Writes relocation to (section+offset) without need to have a symbol at that location.
      Not an abstract method because not every backend needs this functionality. }
    procedure TObjSection.writeReloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);
      begin
        InternalError(2012081501);
      end;


    procedure TObjSection.setDatapos(var dpos:TObjSectionOfs);
      begin
        if oso_Data in secoptions then
          begin
            { get aligned Datapos }
            Datapos:=align_aword(dpos,secalign);
            Dataalignbytes:=Datapos-dpos;
            { return updated Datapos }
            dpos:=Datapos+size;
          end
        else
          Datapos:=dpos;
      end;


    function TObjSection.setmempos(mpos:qword):qword;
      begin
        mempos:=align_qword(mpos,secalign);
        { return updated mempos }
        result:=mempos+size;
      end;


    procedure TObjSection.alloc(l:TObjSectionOfs);
      begin
{$ifndef cpu64bitaddr}
        if (qword(size)+l)>SizeLimit then
          SectionTooLargeError;
{$endif}
        if oso_sparse_data in SecOptions then
          WriteZeros(l)
        else
          inc(size,l);
      end;


    procedure TObjSection.addsymReloc(ofs:TObjSectionOfs;p:TObjSymbol;Reloctype:TObjRelocationType);
      begin
        ObjRelocations.Add(TObjRelocation.CreateSymbol(ofs,p,reloctype));
      end;


    procedure TObjSection.addsectionReloc(ofs:TObjSectionOfs;aobjsec:TObjSection;Reloctype:TObjRelocationType);
      begin
        ObjRelocations.Add(TObjRelocation.CreateSection(ofs,aobjsec,reloctype));
      end;


    procedure TObjSection.addrawReloc(ofs:TObjSectionOfs;p:TObjSymbol;RawReloctype:byte);
      begin
        ObjRelocations.Add(TObjRelocation.CreateRaw(ofs,p,RawReloctype));
      end;


    procedure TObjSection.ReleaseData;
      begin
        if Assigned(FData) then
          begin
            FData.free;
            FData:=nil;
          end;
        ObjRelocations.free;
        ObjRelocations:=nil;
        if Assigned(FCachedFullName) then
          begin
            StringDispose(FCachedFullName);
            FCachedFullName:=nil;
          end;
      end;


    function  TObjSection.FullName:string;
      var
        s: string;
      begin
        if not Assigned(FCachedFullName) then
          begin
            s:=GetAltName;
            if s<>'' then
              s:=Name+s
            else
              s:=Name;
            if Assigned(ObjData) then
              FCachedFullName:=StringDup(ObjData.Name+'('+s+')')
            else
              FCachedFullName:=StringDup(s);
          end;
        result:=FCachedFullName^;
      end;




{****************************************************************************
                                TObjData
****************************************************************************}

    constructor TObjData.create(const n:string);
      begin
        inherited create;
        FName:=ExtractFileName(n);
        FObjSectionList:=TFPHashObjectList.Create(true);
        FStabsObjSec:=nil;
        FStabStrObjSec:=nil;
        { symbols }
        FCObjSymbol:=TObjSymbol;
        FObjSymbolList:=TObjSymbolList.Create(true);
        FObjSymbolList.Owner:=Self;
        FCachedAsmSymbolList:=TFPObjectList.Create(false);
        { section class type for creating of new sections }
        FCObjSection:=TObjSection;
        FCObjSectionGroup:=TObjSectionGroup;
      end;


    destructor TObjData.Destroy;
      begin
        { Symbols }
{$ifdef MEMDEBUG}
        MemObjSymbols.Start;
{$endif}
        ResetCachedAsmSymbols;
        FCachedAsmSymbolList.free;
        FCachedAsmSymbolList := nil;
        FObjSymbolList.free;
        FObjSymbolList := nil;
{$ifdef MEMDEBUG}
        MemObjSymbols.Stop;
{$endif}
        FGroupsList.free;
        FGroupsList := nil;

        { Sections }
{$ifdef MEMDEBUG}
        MemObjSections.Start;
{$endif}
        FObjSectionList.free;
        FObjSectionList := nil;
{$ifdef MEMDEBUG}
        MemObjSections.Stop;
{$endif}
        inherited Destroy;
      end;


    class function TObjData.sectiontype2options(atype:TAsmSectiontype):TObjSectionOptions;
      const
        secoptions : array[TAsmSectiontype] of TObjSectionOptions = ([],
          {user} [oso_Data,oso_load,oso_write],
          {code} [oso_Data,oso_load,oso_executable],
          {Data} [oso_Data,oso_load,oso_write],
          { Readonly data with relocations must be initially writable for some targets.
            Moreover, e.g. for ELF it depends on whether the executable is linked statically or
            dynamically. }
{$if defined(support_rodata)}
          {roData} [oso_Data,oso_load],
{$else defined(support_rodata)}
          {roData} [oso_Data,oso_load,oso_write],
{$endif defined(support_rodata)}
          {roData_norel} [oso_Data,oso_load],
          {bss} [oso_load,oso_write],
          {threadvar} [oso_load,oso_write,oso_threadvar],
          {pdata} [oso_data,oso_load],
          {stub} [oso_Data,oso_load,oso_executable],
          {data_nonlazy}  [oso_Data,oso_load,oso_write],
          {data_lazy} [oso_Data,oso_load,oso_write],
          {init_func} [oso_Data,oso_load],
          {term_func} [oso_Data,oso_load],
          {stab} [oso_Data,oso_debug],
          {stabstr} [oso_Data,oso_strings,oso_debug],
          {iData2} [oso_Data,oso_load,oso_write],
          {iData4} [oso_Data,oso_load,oso_write],
          {iData5} [oso_Data,oso_load,oso_write],
          {iData6} [oso_Data,oso_load,oso_write],
          {iData7} [oso_Data,oso_load,oso_write],
          {eData} [oso_Data,oso_load],
          {eh_frame} [oso_Data,oso_load],
          {debug_frame} [oso_Data,oso_debug],
          {debug_info} [oso_Data,oso_debug],
          {debug_line} [oso_Data,oso_debug],
          {debug_abbrev} [oso_Data,oso_debug],
          {debug_aranges} [oso_Data,oso_debug],
          {debug_ranges} [oso_Data,oso_debug],
          {debug_loc} [oso_Data,oso_debug],
          {debug_loclists} [oso_Data,oso_debug],
          {fpc} [oso_Data,oso_load,oso_write],
          {toc} [oso_Data,oso_load],
          {init} [oso_Data,oso_load,oso_executable],
          {fini} [oso_Data,oso_load,oso_executable],
          {objc_class} [oso_data,oso_load],
          {objc_meta_class} [oso_data,oso_load],
          {objc_cat_cls_meth} [oso_data,oso_load],
          {objc_cat_inst_meth} [oso_data,oso_load],
          {objc_protocol} [oso_data,oso_load],
          {objc_string_object} [oso_data,oso_load],
          {objc_cls_meth} [oso_data,oso_load],
          {objc_inst_meth} [oso_data,oso_load],
          {objc_cls_refs} [oso_data,oso_load],
          {objc_message_refs} [oso_data,oso_load],
          {objc_symbols} [oso_data,oso_load],
          {objc_category} [oso_data,oso_load],
          {objc_class_vars} [oso_data,oso_load],
          {objc_instance_vars} [oso_data,oso_load],
          {objc_module_info} [oso_data,oso_load],
          {objc_class_names} [oso_data,oso_load],
          {objc_meth_var_types} [oso_data,oso_load],
          {objc_meth_var_names} [oso_data,oso_load],
          {objc_selector_strs} [oso_data,oso_load],
          {objc_protocol_ext} [oso_data,oso_load],
          {objc_class_ext} [oso_data,oso_load],
          {objc_property} [oso_data,oso_load],
          {objc_image_info} [oso_data,oso_load],
          {objc_cstring_object} [oso_data,oso_load],
          {objc_sel_fixup} [oso_data,oso_load],
          {sec_objc_data} [oso_data,oso_load],
          {sec_objc_const} [oso_data,oso_load],
          {sec_objc_sup_refs} [oso_data,oso_load],
          {sec_data_coalesced} [oso_data,oso_load],
          {sec_objc_classlist} [oso_data,oso_load],
          {sec_objc_nlclasslist} [oso_data,oso_load],
          {sec_objc_catlist} [oso_data,oso_load],
          {sec_objc_nlcatlist} [oso_data,oso_load],
          {sec_objc_protolist'} [oso_data,oso_load],
          {stack} [oso_load,oso_write],
          {heap} [oso_load,oso_write],
          {gcc_except_table} [oso_data,oso_load],
          {arm_attribute} [oso_data],
          {note} [oso_Data,oso_note]
        );
      begin
        if TargetAsm.id in asms_int_coff then
          begin
            if (aType in [sec_rodata,sec_rodata_norel]) then
              begin
                if (TargetInfo.system in systems_all_windows) then
                  aType:=sec_rodata_norel
                else
                  aType:=sec_data;
              end;
          end;
        result:=secoptions[atype];
        if (atype=sec_rodata) and (TargetInfo.system=system_x86_64_linux) and
           (tf_supports_packages in TargetInfo.flags) and
           (cs_create_pic in CurrentSettings.ModuleSwitches) then
          include(result,oso_write);
{$ifdef OMFOBJSUPPORT}
        { in the huge memory model, BSS data is actually written in the regular
          FAR_DATA segment of the module }
        if omf_segclass(atype)='FAR_DATA' then
          Result:=Result+[oso_data,oso_sparse_data];
{$endif OMFOBJSUPPORT}
      end;


    function TObjData.sectiontype2align(atype:TAsmSectiontype):LongInt;
      begin
        case atype of
          sec_stabstr,sec_debug_info,sec_debug_line,sec_debug_abbrev,sec_debug_aranges,sec_debug_ranges,
          sec_arm_attribute:
            result:=1;
          sec_code,
          sec_bss,
          sec_data:
            result:=16;
          { For idata (at least idata2) it must be 4 bytes, because
            an entry is always (also in win64) 20 bytes and aligning
            on 8 bytes will insert 4 bytes between the entries resulting
            in a corrupt idata section.
            Same story with .pdata, it has 4-byte elements which should
            be packed without gaps. }
          sec_idata2,sec_idata4,sec_idata5,sec_idata6,sec_idata7,sec_pdata:
            result:=4;
          else
            result:=sizeof(PInt);
        end;
      end;


    class procedure TObjData.sectiontype2progbitsandflags(atype:TAsmSectiontype;out progbits:TSectionProgbits;out flags:TSectionFlags);
      var
        options : TObjSectionOptions;
      begin
        { this is essentially the inverse of the createsection overload that takes
          both progbits and flags as parameters }
        options:=sectiontype2options(atype);
        flags:=[];
        progbits:=SPB_None;
        if oso_load in options then
          include(flags,SF_A);
        if oso_write in options then
          include(flags,SF_W);
        if oso_executable in options then
          include(flags,SF_X);
        if not (oso_data in options) then
          progbits:=SPB_NOBITS
        else if oso_note in options then
          progbits:=SPB_NOTE
        else if oso_arm_attributes in options then
          progbits:=SPB_ARM_ATTRIBUTES;
      end;


    function TObjData.createsection(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):TObjSection;
      begin
        result:=createsection(sectionname(atype,aname,aorder),sectiontype2align(atype),sectiontype2options(atype));
      end;


    function TObjData.createsection(atype: TAsmSectiontype; secflags: TSectionFlags; aprogbits: TSectionProgbits; const aname: string; aorder: TAsmSectionOrder): TObjSection;
      var
        flags : TObjSectionOptions;
      begin
        flags:=[oso_data];
        if SF_A in secflags then
          Include(flags,oso_load);
        if SF_W in secflags then
          Include(flags,oso_write);
        if SF_X in secflags then
          Include(flags,oso_executable);
        if aprogbits=SPB_NOBITS then
          Exclude(flags,oso_data);
        if aprogbits=SPB_NOTE then
          Include(flags,oso_note);
        if aprogbits=SPB_ARM_ATTRIBUTES then
          Include(flags,oso_arm_attributes);
        result:=createsection(sectionname(atype,aname,aorder),sectiontype2align(atype),flags);
      end;


    function TObjData.createsection(const aname:string;aalign:LongInt;aoptions:TObjSectionOptions;DiscardDuplicate:boolean):TObjSection;
      begin
        if DiscardDuplicate then
          result:=TObjSection(FObjSectionList.Find(aname))
        else
          result:=nil;
        if not Assigned(result) then
          begin
            result:=CObjSection.create(FObjSectionList,aname,aalign,aoptions);
            result.ObjData:=self;
          end;
        FCurrObjSec:=result;
      end;


    function TObjData.CreateSectionGroup(const aname:string):TObjSectionGroup;
      begin
        if FGroupsList=nil then
          FGroupsList:=TFPHashObjectList.Create(true);
        result:=CObjSectionGroup.Create(FGroupsList,aname);
      end;


    procedure TObjData.CreateDebugSections;
      begin
      end;


    function TObjData.Findsection(const aname:string):TObjSection;
      begin
        result:=TObjSection(FObjSectionList.Find(aname));
      end;


    procedure TObjData.setsection(asec:TObjSection);
      begin
        if asec.ObjData<>self then
          InternalError(200403041);
        FCurrObjSec:=asec;
      end;


    function TObjData.createsymbol(const aname:string):TObjSymbol;
      begin
        result:=TObjSymbol(FObjSymbolList.Find(aname));
        if not Assigned(result) then
          result:=CObjSymbol.Create(FObjSymbolList,aname);

      end;


    function TObjData.symboldefine(asmsym:TAsmSymbol):TObjSymbol;
      begin
        if Assigned(asmsym) then
          begin
            if asmsym.typ = AT_NONE then
              InternalError(2018062800);

            if not Assigned(asmsym.cachedObjSymbol) then
              begin
                result:=symboldefine(asmsym.name,asmsym.bind,asmsym.typ);
                asmsym.cachedObjSymbol:=result;
                FCachedAsmSymbolList.add(asmsym);
              end
            else
              begin
                result:=TObjSymbol(asmsym.cachedObjSymbol);
                result.SetAddress(CurrPass,CurrObjSec,asmsym.bind,asmsym.typ);
              end;
          end
        else
          result:=nil;
      end;


    function TObjData.symboldefine(const aname:string;abind:TAsmsymbind;atyp:TAsmsymtype):TObjSymbol;
      begin
        if not Assigned(CurrObjSec) then
          InternalError(2006030504);
        result:=CreateSymbol(aname);
        result.SetAddress(CurrPass,CurrObjSec,abind,atyp);
      end;


    function TObjData.symbolref(asmsym:TAsmSymbol):TObjSymbol;
      var
        s:string;
      begin
        if Assigned(asmsym) then
          begin
            if not Assigned(asmsym.cachedObjSymbol) then
              begin
                s:=asmsym.name;
                result:=TObjSymbol(FObjSymbolList.Find(s));
                if result=nil then
                  begin
                    result:=CObjSymbol.Create(FObjSymbolList,s);
                    if asmsym.bind=AB_WEAK_EXTERNAL then
                      result.bind:=AB_WEAK_EXTERNAL;
                  end;
                asmsym.cachedObjSymbol:=result;
                FCachedAsmSymbolList.add(asmsym);
              end
            else
              result:=TObjSymbol(asmsym.cachedObjSymbol);
            { The weak bit could have been removed from asmsym. }
            if (asmsym.bind=AB_EXTERNAL) and (result.bind=AB_WEAK_EXTERNAL) then
              result.bind:=AB_EXTERNAL;
            { the TLS type needs to be inherited }
            if asmsym.typ=AT_TLS then
              result.typ:=AT_TLS;
          end
        else
          result:=nil;
      end;


    function TObjData.symbolref(const aname:string):TObjSymbol;
      begin
        if not Assigned(CurrObjSec) then
          InternalError(200603052);
        result:=CreateSymbol(aname);
      end;


    procedure TObjData.symbolpairdefine(akind: TSymbolPairKind; const asym, avalue: string);
      begin
      end;


    procedure TObjData.ResetCachedAsmSymbols;
      var
        i  : LongInt;
      begin
        for i:=0 to FCachedAsmSymbolList.Count-1 do
          TAsmSymbol(FCachedAsmSymbolList[i]).cachedObjSymbol:=nil;
        FCachedAsmSymbolList.Clear;
      end;


    procedure TObjData.writebytes(const Data;len:TObjSectionOfs);
      begin
        if not Assigned(CurrObjSec) then
          InternalError(200402251);
        CurrObjSec.write(Data,len);
      end;

    procedure TObjData.writebytes(const Data: TByteDynArray; len: TObjSectionOfs);
    begin
      if len>0 then
        WriteBytes(Data[0],len);
    end;

    procedure TObjData.writebytes(const Data: TAnsiCharDynArray; len: TObjSectionOfs);
    begin
      if len>0 then
        WriteBytes(Data[0],len);
    end;


    procedure TObjData.writeInt8(v: int8);
      begin
        writebytes(v,1);
      end;


    procedure TObjData.writeInt16LE(v: int16);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,2);
      end;


    procedure TObjData.writeInt16BE(v: int16);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,2);
      end;


    procedure TObjData.writeInt32LE(v: int32);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,4);
      end;


    procedure TObjData.writeInt32BE(v: int32);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,4);
      end;


    procedure TObjData.writeInt64LE(v: int64);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,8);
      end;


    procedure TObjData.writeInt64BE(v: int64);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,8);
      end;


    procedure TObjData.writeUInt8(v: uint8);
      begin
        writebytes(v,1);
      end;


    procedure TObjData.writeUInt16LE(v: uint16);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,2);
      end;


    procedure TObjData.writeUInt16BE(v: uint16);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,2);
      end;


    procedure TObjData.writeUInt32LE(v: uint32);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,4);
      end;


    procedure TObjData.writeUInt32BE(v: uint32);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,4);
      end;


    procedure TObjData.writeUInt64LE(v: uint64);
      begin
{$ifdef FPC_BIG_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_BIG_ENDIAN}
        writebytes(v,8);
      end;


    procedure TObjData.writeUInt64BE(v: uint64);
      begin
{$ifdef FPC_LITTLE_ENDIAN}
        v:=SwapEndian(v);
{$endif FPC_LITTLE_ENDIAN}
        writebytes(v,8);
      end;


    procedure TObjData.alloc(len:TObjSectionOfs);
      begin
        if not Assigned(CurrObjSec) then
          InternalError(200402252);
        CurrObjSec.alloc(len);
      end;


    procedure TObjData.allocalign(len:LongInt);
      begin
        if not Assigned(CurrObjSec) then
          InternalError(200402253);
        CurrObjSec.alloc(align_objsecofs(CurrObjSec.size,len)-CurrObjSec.size);
      end;


    procedure TObjData.section_afteralloc(p:TObject;arg:pointer);
      begin
        with TObjSection(p) do
          alloc(align_objsecofs(size,secalign)-size);
      end;


    procedure TObjData.section_afterwrite(p:TObject;arg:pointer);
      begin
        with TObjSection(p) do
          begin
            if Assigned(Data) then
              writezeros(align_objsecofs(size,secalign)-size);
          end;
      end;


    procedure TObjData.section_reset(p:TObject;arg:pointer);
      begin
        with TObjSection(p) do
          begin
            Size:=0;
            Datapos:=0;
            mempos:=0;
            if Assigned(Data) then
              Data.reset;
          end;
      end;


    procedure TObjData.beforealloc;
      begin
        FCPUType:=CurrentSettings.CPUType;
        { create stabs sections if debugging }
        if Assigned(StabsSec) then
          begin
            StabsSec.Alloc(sizeof(TObjStabEntry));
            StabStrSec.Alloc(1);
          end;
      end;


    procedure TObjData.beforewrite;
      begin
        FCPUType:=CurrentSettings.CPUType;
        { create stabs sections if debugging }
        if Assigned(StabsSec) then
         begin
           { Create dummy HdrSym stab, it will be overwritten in AfterWrite }
           StabsSec.WriteZeros(sizeof(TObjStabEntry));
           { start of stabstr }
           StabStrSec.writeZeros(1);
         end;
      end;


    procedure TObjData.afteralloc;
      begin
        FObjSectionList.ForEachCall(@section_afteralloc,nil);
      end;


    procedure TObjData.afterwrite;
      var
        hstab : TObjStabEntry;
      begin
        FObjSectionList.ForEachCall(@section_afterwrite,nil);
        { For the stab section we need an HdrSym which can now be
          calculated more easily }
        if Assigned(StabsSec) then
          begin
            { end of stabstr }
            StabStrSec.writeZeros(1);
            { header stab }
            hstab.strpos:=1;
            hstab.ntype:=0;
            hstab.nother:=0;
{$push}{$R-}
            { for jwawindows.pas, this causes an range check error, it contains too much stab symbols }
            hstab.ndesc:=(StabsSec.Size div sizeof(TObjStabEntry))-1;
{$pop}
            hstab.nvalue:=StabStrSec.Size;
            MaybeSwapStab(hstab);
            StabsSec.Data.seek(0);
            StabsSec.Data.write(hstab,sizeof(hstab));
          end;
      end;


    procedure TObjData.resetsections;
      begin
        FObjSectionList.ForEachCall(@section_reset,nil);
      end;


        procedure TObjData.layoutsections(var datapos: TObjSectionOfs);
      var
        i: LongInt;
      begin
        for i:=0 to FObjSectionList.Count-1 do
          TObjSection(FObjSectionList[i]).setDatapos(DataPos);
      end;


{****************************************************************************
                                TObjOutput
****************************************************************************}

    constructor TObjOutput.create(AWriter:TObjectWriter);
      begin
        FWriter:=AWriter;
        CObjData:=TObjData;
      end;


    destructor TObjOutput.Destroy;
      begin
        inherited Destroy;
      end;


    function TObjOutput.newObjData(const n:string):TObjData;
      begin
        result:=CObjData.create(n);
        if (cs_use_lineinfo in CurrentSettings.GlobalSwitches) or
           (cs_debuginfo in CurrentSettings.ModuleSwitches) then
          result.CreateDebugSections;
      end;


    function TObjOutput.startObjectfile(const fn:string):boolean;
      begin
        result:=false;
        { start the writer already, so the .a generation can initialize
          the position of the current objectfile }
        if not FWriter.CreateFile(fn) then
         Comment(VFatal,'Can''t create object '+fn);
        result:=true;
      end;


    function TObjOutput.writeobjectfile(Data:TObjData):boolean;
      begin
        if ErrorCount=0 then
         result:=WriteData(Data)
        else
         result:=true;
        { close the writer }
        FWriter.CloseFile;
      end;


    procedure TObjOutput.exportsymbol(p:TObjSymbol);
      begin
        { export globals and common symbols, this is needed
          for .a files }
        if p.bind in [AB_GLOBAL,AB_PRIVATE_EXTERN,AB_COMMON] then
         FWriter.writesym(ApplyAsmSymbolRestrictions(p.name));
      end;

    procedure TObjOutput.WriteSectionContent(Data:TObjData);
      var
        i:LongInt;
        sec:TObjSection;
      begin
        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            sec:=TObjSection(Data.ObjSectionList[i]);
            if (oso_data in sec.SecOptions) then
              begin
                if sec.Data=nil then
                  InternalError(2004030707);
                FWriter.writezeros(sec.dataalignbytes);
                if sec.Datapos<>FWriter.ObjSize then
                  InternalError(200604031);
                FWriter.writearray(sec.data);
              end;
          end;
      end;

    constructor TImportLibrary.create(AList:TFPHashObjectList;const AName:string);
      begin
        inherited create(AList,AName);
        FImportSymbolList:=TFPHashObjectList.Create(true);
      end;


    destructor TImportLibrary.Destroy;
      begin
        FImportSymbolList.Free;
        FImportSymbolList := nil;
        inherited Destroy;
      end;


{****************************************************************************
                                TImportSymbol
****************************************************************************}

    constructor TImportSymbol.create(AList:TFPHashObjectList;
            const AName,AMangledName:string;AOrdNr:LongInt;AIsVar:boolean);
      begin
        inherited Create(AList, AName);
        FOrdNr:=AOrdNr;
        FIsVar:=AIsVar;
        FMangledName:=AMangledName;
        { Replace ? and @ in import name, since GNU AS does not allow these characters in symbol names. }
        { This allows to import VC++ mangled names from DLLs. }
        if TargetInfo.system in systems_all_windows then
          begin
            Replace(FMangledName,'?','__q$$');
          end;
      end;


    constructor TObjInput.create;
      begin
      end;


    procedure TObjInput.inputerror(const s : string);
      begin
        Comment(VError,s+' while reading '+InputFileName);
      end;


    class function TObjInput.CanReadObjData(AReader:TObjectReader):boolean;
      begin
        result:=false;
      end;


    procedure TObjInput.ReadSectionContent(Data:TObjData);
      var
        i: LongInt;
        sec: TObjSection;
      begin
        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            sec:=TObjSection(Data.ObjSectionList[i]);
            { Skip debug sections }
            if (oso_debug in sec.SecOptions) and
               (cs_link_strip in CurrentSettings.GlobalSwitches) and
               not(cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
              continue;

            if Assigned(sec.Data) then
              begin
                FReader.Seek(sec.datapos);
                if not FReader.ReadArray(sec.data,sec.Size) then
                  begin
                    InputError('Can''t read object data');
                    exit;
                  end;
              end;
          end;
      end;


{$ifdef MEMDEBUG}
initialization
  memobjsymbols:=TMemDebug.create('ObjSymbols');
  memobjsymbols.stop;
  memobjsections:=TMemDebug.create('ObjSections');
  memobjsections.stop;

finalization
  memobjsymbols.free;
  memobjsymbols := nil;
  memobjsections.free;
  memobjsections := nil;
{$endif MEMDEBUG}
end.
