{
    Copyright (c) 1998-2006 by Peter Vreman

    Contains the binary coff/PE reader and writer

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
unit ogcoff;

{$i fpcdefs.inc}

interface

    uses
       { common }
       CClasses,GlobType,
       { target }
       Systems,
       { assembler }
       aasmbase,assemble,
       { output }
       ogbase,
       owbase;

    const
       PE_DATADIR_ENTRIES = 16;

    type

       TObjSymbolArray = array of TObjSymbol;
       TObjSectionArray = array of TObjSection;
       TCOFFPEDataDir = packed record
         vaddr : LongWord;
         size  : LongWord;
       end;
       TCOFFHeader = packed record
         mach   : word;
         nsects : word;
         time   : LongWord;
         sympos : LongWord;
         syms   : LongWord;
         opthdr : word;
         flag   : word;
       end;
       TCOFFBigObjHeader = packed record
         Sig1 : word;
         Sig2 : word;
         Version : word;
         Machine : word;
         TimeDateStame : LongWord;
         UUID : array[0..15] of byte;
         unused : array[0..3] of LongWord;
         NumberOfSections : LongWord;
         PointerToSymbolTable : LongWord;
         NumberOfSymbols : LongWord;
       end;
       TCOFFPEOptHeader = packed record
         Magic : word;
         MajorLinkerVersion : byte;
         MinorLinkerVersion : byte;
         tsize : LongWord;
         dsize : LongWord;
         bsize : LongWord;
         entry : LongWord;
         text_start : LongWord;
{$ifndef cpu64bitaddr}
         data_start : LongWord;
{$endif cpu64bitaddr}
         ImageBase : aword;
         SectionAlignment : LongWord;
         FileAlignment : LongWord;
         MajorOperatingSystemVersion : word;
         MinorOperatingSystemVersion : word;
         MajorImageVersion : word;
         MinorImageVersion : word;
         MajorSubsystemVersion : word;
         MinorSubsystemVersion : word;
         Win32Version : LongWord;
         SizeOfImage : LongWord;
         SizeOfHeaders : LongWord;
         CheckSum : LongWord;
         Subsystem : word;
         DllCharacteristics : word;
         SizeOfStackReserve : aword;
         SizeOfStackCommit : aword;
         SizeOfHeapReserve : aword;
         SizeOfHeapCommit : aword;
         LoaderFlags : LongWord;          { This field is obsolete }
         NumberOfRvaAndSizes : LongWord;
         DataDirectory : array[0..PE_DATADIR_ENTRIES-1] of TCOFFPEDataDir;
       end;
       TCOFFSecHdr = packed record
         name     : array[0..7] of char;
         vsize    : LongWord;
         rvaofs   : LongWord;
         DataSize : LongWord;
         datapos  : LongWord;
         relocpos : LongWord;
         lineno1  : LongWord;
         nrelocs  : word;
         lineno2  : word;
         flags    : LongWord;
       end;

       TCoffObjSection = class(TObjSection)
       private
         orgmempos,
         coffrelocs,
         coffrelocpos : aword;
       public
         constructor Create(AList:TFPHashObjectList;const Aname:string;Aalign:LongInt;Aoptions:TObjSectionOptions);override;
         procedure writereloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);override;
       end;

       TCoffObjData = class(TObjData)
       private
         win32      : boolean;
        public
          constructor createcoff(const n:string;awin32:boolean;acObjSection:TObjSectionClass);
          function  sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
          function  createsection(atype:TAsmSectiontype;const aname:string='';aorder:TAsmSectionOrder=secorder_default):TObjSection;override;overload;
          function  createsection(atype:TAsmSectiontype;secflags:TSectionFlags;aprogbits:TSectionProgbits;const aname:string='';aorder:TAsmSectionOrder=secorder_default):TObjSection;override;overload;
          procedure writereloc(data:aint;len:aword;p:TObjSymbol;reloctype:TObjRelocationType);override;
        end;

       TDJCoffObjData = class(TCoffObjData)
         constructor Create(const n:string);override;
       end;

       TPECoffObjData = class(TCoffObjData)
         constructor Create(const n:string);override;
       end;

       TCoffObjOutput = class(TObjOutput)
       private
         win32   : boolean;
         bigobj  : boolean;
         symidx  : LongInt;
         FCoffSyms,
         FCoffStrs : TDynamicArray;
         procedure write_symbol(const name:string;value:aword;section:LongInt;typ,aux:byte);
         procedure section_write_symbol(p:TObject;arg:pointer);
         procedure section_write_relocs(p:TObject;arg:pointer);
         procedure create_symbols(data:TObjData);
         procedure section_set_reloc_datapos(p:TCoffObjSection;var datapos:aword);
         procedure section_write_header(p:TObject;arg:pointer);
       protected
         function WriteData(data:TObjData):boolean;override;
       public
         constructor createcoff(AWriter:TObjectWriter;awin32:boolean);
         destructor Destroy;override;
       end;

       TDJCoffObjOutput = class(TCoffObjOutput)
         constructor Create(AWriter:TObjectWriter);override;
       end;

       TPECoffObjOutput = class(TCoffObjOutput)
         constructor Create(AWriter:TObjectWriter);override;
       end;

       TCoffObjInput = class(TObjInput)
       private
         FCoffsyms : TDynamicArray;
         FCoffStrs : TAnsiCharDynArray;
         FCoffStrSize: LongWord;
         { Convert symidx -> TObjSymbol }
         FSymTbl   : TObjSymbolArray;
         { Convert secidx -> TObjSection }
         FSecCount : LongInt;
         FSecTbl   : TObjSectionArray;
         win32     : boolean;
         bigobj    : boolean;
         function  GetSection(secidx:LongInt):TObjSection;
         function  Read_str(strpos:LongWord):string;
         procedure read_relocs(s:TCoffObjSection);
         procedure read_symbols(objdata:TObjData);
         procedure ObjSections_read_relocs(p:TObject;arg:pointer);
       public
         constructor createcoff(awin32:boolean);
         destructor Destroy;override;
         function  ReadObjData(AReader:TObjectReader;out objdata:TObjData):boolean;override;
       end;

       TDJCoffObjInput = class(TCoffObjInput)
         constructor Create;override;
       end;

       TPECoffObjInput = class(TCoffObjInput)
         constructor Create;override;
       end;

       TDJCoffAssembler = class(TInternalAssembler)
         constructor Create(info: PAsmInfo; smart:boolean);override;
       end;

       TPECoffassembler = class(TInternalAssembler)
         constructor Create(info: PAsmInfo; smart:boolean);override;
       end;


    type
      Treaddllproc = procedure(const dllname,funcname:string) of object;

    const
{$ifdef i386}
       COFF_MAGIC       = $14c;
       COFF_OPT_MAGIC   = $10b;
       TLSDIR_SIZE      = $18;
{$endif i386}
{$ifdef x86_64}
       COFF_MAGIC       = $8664;
       COFF_OPT_MAGIC   = $20b;
       TLSDIR_SIZE      = $28;
{$endif x86_64}
{$ifdef aarch64}
       COFF_MAGIC       = $AA64;
       COFF_OPT_MAGIC   = $20b;
       TLSDIR_SIZE      = $28;
{$endif aarch64}
       COFF_BIG_OBJ_MAGIC: array[0..15] of byte = ($C7, $A1, $BA, $D1, $EE, $BA, $A9, $4B, $AF, $20, $FA, $F6, $6A, $A4, $DC, $B8);
       COFF_BIG_OBJ_VERSION = 2;

    function ReadDLLImports(const dllname:string;readdllproc:Treaddllproc):boolean;
    procedure MaybeSwap(var v : TCOFFSecHdr);
    procedure MaybeSwap(var v : TCOFFHeader);
    procedure MaybeSwap(var v : TCOFFPEOptHeader);

implementation

    uses
{$ifdef win32}
       Windows,
{$endif win32}
       SysUtils,
       CUtils,Verbose,Globals,
       cpubase,CPUInfo,
       FModule,
       owar,
       version
       ;

    const
       COFF_FLAG_NORELOCS = $0001;
       COFF_FLAG_EXE      = $0002;
       COFF_FLAG_NOLINES  = $0004;
       COFF_FLAG_NOLSYMS  = $0008;
       COFF_FLAG_AR16WR   = $0080; { 16bit little endian }
       COFF_FLAG_AR32WR   = $0100; { 32bit little endian }
       COFF_FLAG_AR32W    = $0200; { 32bit big endian }
       COFF_FLAG_DLL      = $2000;

       COFF_SYM_GLOBAL   = 2;
       COFF_SYM_LOCAL    = 3;
       COFF_SYM_LABEL    = 6;
       COFF_SYM_FUNCTION = 101;
       COFF_SYM_FILE     = 103;
       COFF_SYM_SECTION  = 104;

       COFF_STYP_REG    = $0000; { "regular": allocated, relocated, loaded }
       COFF_STYP_DSECT  = $0001; { "dummy":  relocated only }
       COFF_STYP_NOLOAD = $0002; { "noload": allocated, relocated, not loaded }
       COFF_STYP_GROUP  = $0004; { "grouped": formed of input sections }
       COFF_STYP_PAD    = $0008;
       COFF_STYP_COPY   = $0010;
       COFF_STYP_TEXT   = $0020;
       COFF_STYP_DATA   = $0040;
       COFF_STYP_BSS    = $0080;
       COFF_STYP_INFO   = $0200;
       COFF_STYP_OVER   = $0400;
       COFF_STYP_LIB    = $0800;

       PE_SUBSYSTEM_NATIVE         = 1;
       PE_SUBSYSTEM_WINDOWS_GUI    = 2;
       PE_SUBSYSTEM_WINDOWS_CUI    = 3;
       PE_SUBSYSTEM_WINDOWS_CE_GUI = 9;

       PE_FILE_RELOCS_STRIPPED         = $0001;
       PE_FILE_EXECUTABLE_IMAGE        = $0002;
       PE_FILE_LINE_NUMS_STRIPPED      = $0004;
       PE_FILE_LOCAL_SYMS_STRIPPED     = $0008;
       PE_FILE_AGGRESSIVE_WS_TRIM      = $0010;
       PE_FILE_LARGE_ADDRESS_AWARE     = $0020;
       PE_FILE_16BIT_MACHINE           = $0040;
       PE_FILE_BYTES_REVERSED_LO       = $0080;
       PE_FILE_32BIT_MACHINE           = $0100;
       PE_FILE_DEBUG_STRIPPED          = $0200;
       PE_FILE_REMOVABLE_RUN_FROM_SWAP = $0400;
       PE_FILE_NET_RUN_FROM_SWAP       = $0800;
       PE_FILE_SYSTEM                  = $1000;
       PE_FILE_DLL                     = $2000;
       PE_FILE_UP_SYSTEM_ONLY          = $4000;
       PE_FILE_BYTES_REVERSED_HI       = $8000;

       PE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA       = $0020;
       PE_DLLCHARACTERISTICS_DYNAMIC_BASE          = $0040;
       PE_DLLCHARACTERISTICS_FORCE_INTEGRITY       = $0080;
       PE_DLLCHARACTERISTICS_NX_COMPAT             = $0100;
       PE_DLLCHARACTERISTICS_NO_ISOLATION          = $0200;
       PE_DLLCHARACTERISTICS_NO_SEH                = $0400;
       PE_DLLCHARACTERISTICS_NO_BIND               = $0800;
       PE_DLLCHARACTERISTICS_APPCONTAINER          = $1000;
       PE_DLLCHARACTERISTICS_WDM_DRIVER            = $2000;
       PE_DLLCHARACTERISTICS_GUARD_CF              = $4000;
       PE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE = $8000;

       PE_SCN_CNT_CODE               = $00000020; { Section contains code. }
       PE_SCN_CNT_INITIALIZED_DATA   = $00000040; { Section contains initialized data. }
       PE_SCN_CNT_UNINITIALIZED_DATA = $00000080; { Section contains uninitialized data. }
       PE_SCN_LNK_OTHER              = $00000100; { Reserved. }
       PE_SCN_LNK_INFO               = $00000200; { Section contains comments or some other type of information. }
       PE_SCN_LNK_REMOVE             = $00000800; { Section contents will not become part of image. }
       PE_SCN_LNK_COMDAT             = $00001000; { Section contents comdat. }
       PE_SCN_MEM_FARDATA            = $00008000;
       PE_SCN_MEM_PURGEABLE          = $00020000;
       PE_SCN_MEM_16BIT              = $00020000;
       PE_SCN_MEM_LOCKED             = $00040000;
       PE_SCN_MEM_PRELOAD            = $00080000;
       PE_SCN_ALIGN_MASK             = $00f00000;
       PE_SCN_ALIGN_1BYTES           = $00100000;
       PE_SCN_ALIGN_2BYTES           = $00200000;
       PE_SCN_ALIGN_4BYTES           = $00300000;
       PE_SCN_ALIGN_8BYTES           = $00400000;
       PE_SCN_ALIGN_16BYTES          = $00500000; { Default alignment if no others are specified. }
       PE_SCN_ALIGN_32BYTES          = $00600000;
       PE_SCN_ALIGN_64BYTES          = $00700000;
       PE_SCN_ALIGN_128BYTES         = $00800000;
       PE_SCN_ALIGN_256BYTES         = $00900000;
       PE_SCN_ALIGN_512BYTES         = $00A00000;
       PE_SCN_ALIGN_1024BYTES        = $00B00000;
       PE_SCN_ALIGN_2048BYTES        = $00C00000;
       PE_SCN_ALIGN_4096BYTES        = $00D00000;
       PE_SCN_ALIGN_8192BYTES        = $00E00000;
       PE_SCN_LNK_NRELOC_OVFL        = $01000000; { Section contains extended relocations. }
       PE_SCN_MEM_NOT_CACHED         = $04000000; { Section is not cachable.               }
       PE_SCN_MEM_NOT_PAGED          = $08000000; { Section is not pageable.               }
       PE_SCN_MEM_SHARED             = $10000000; { Section is shareable.                  }
       PE_SCN_MEM_DISCARDABLE        = $02000000;
       PE_SCN_MEM_EXECUTE            = $20000000;
       PE_SCN_MEM_READ               = $40000000;
       PE_SCN_MEM_WRITE              = $80000000;

       PE_DATADIR_EDATA = 0;
       PE_DATADIR_IDATA = 1;
       PE_DATADIR_RSRC = 2;
       PE_DATADIR_PDATA = 3;
       PE_DATADIR_SECURITY = 4;
       PE_DATADIR_RELOC = 5;
       PE_DATADIR_DEBUG = 6;
       PE_DATADIR_DESCRIPTION = 7;
       PE_DATADIR_SPECIAL = 8;
       PE_DATADIR_TLS = 9;
       PE_DATADIR_LOADCFG = 10;
       PE_DATADIR_BOUNDIMPORT = 11;
       PE_DATADIR_IMPORTADDRESSTABLE = 12;
       PE_DATADIR_DELAYIMPORT = 13;

{$ifdef x86_64}
       IMAGE_REL_AMD64_ABSOLUTE    = $0000;  { Reference is absolute, no relocation is necessary }
       IMAGE_REL_AMD64_ADDR64      = $0001;  { 64-bit address (VA). }
       IMAGE_REL_AMD64_ADDR32      = $0002;  { 32-bit address (VA). }
       IMAGE_REL_AMD64_ADDR32NB    = $0003;  { 32-bit address w/o image base (RVA). }
       IMAGE_REL_AMD64_REL32       = $0004;  { 32-bit relative address from byte following reloc }
       IMAGE_REL_AMD64_REL32_1     = $0005;  { 32-bit relative address from byte distance 1 from reloc }
       IMAGE_REL_AMD64_REL32_2     = $0006;  { 32-bit relative address from byte distance 2 from reloc }
       IMAGE_REL_AMD64_REL32_3     = $0007;  { 32-bit relative address from byte distance 3 from reloc }
       IMAGE_REL_AMD64_REL32_4     = $0008;  { 32-bit relative address from byte distance 4 from reloc }
       IMAGE_REL_AMD64_REL32_5     = $0009;  { 32-bit relative address from byte distance 5 from reloc }
       IMAGE_REL_AMD64_SECTION     = $000A;  { Section index }
       IMAGE_REL_AMD64_SECREL      = $000B;  { 32 bit offset from base of section containing target }
       IMAGE_REL_AMD64_SECREL7     = $000C;  { 7 bit unsigned offset from base of section containing target }
       IMAGE_REL_AMD64_TOKEN       = $000D;  { 32 bit metadata token }
       IMAGE_REL_AMD64_SREL32      = $000E;  { 32 bit signed span-dependent value emitted into object }
       IMAGE_REL_AMD64_PAIR        = $000F;
       IMAGE_REL_AMD64_SSPAN32     = $0010;  { 32 bit signed span-dependent value applied at link time }
      { Direct 32 bit sign extended,
        win64 mingw GNU compiler
        also generates this type
        inside coff objects
        We assume they are equivalent to
        IMAGE_REL_AMD64_ADDR32  PM 2010-11-27 }
       R_X86_64_32S =           $11;

{$endif x86_64}


{$ifdef i386}
       IMAGE_REL_I386_DIR32 = 6;
       IMAGE_REL_I386_IMAGEBASE = 7;
       IMAGE_REL_I386_SECREL32 = 11;
       IMAGE_REL_I386_PCRLONG = 20;
{$endif i386}

{$ifdef aarch64}
       IMAGE_REL_ARM64_ABSOLUTE       = $0000;  // No relocation required
       IMAGE_REL_ARM64_ADDR32         = $0001;  // 32 bit address. Review! do we need it?
       IMAGE_REL_ARM64_ADDR32NB       = $0002;  // 32 bit address w/o image base (RVA: for Data/PData/XData)
       IMAGE_REL_ARM64_BRANCH26       = $0003;  // 26 bit offset << 2 & sign ext. for B & BL
       IMAGE_REL_ARM64_PAGEBASE_REL21 = $0004;  // ADRP
       IMAGE_REL_ARM64_REL21          = $0005;  // ADR
       IMAGE_REL_ARM64_PAGEOFFSET_12A = $0006;  // ADD/ADDS (immediate) with zero shift, for page offset
       IMAGE_REL_ARM64_PAGEOFFSET_12L = $0007;  // LDR (indexed, unsigned immediate), for page offset
       IMAGE_REL_ARM64_SECREL         = $0008;  // Offset within section
       IMAGE_REL_ARM64_SECREL_LOW12A  = $0009;  // ADD/ADDS (immediate) with zero shift, for bit 0:11 of section offset
       IMAGE_REL_ARM64_SECREL_HIGH12A = $000A;  // ADD/ADDS (immediate) with zero shift, for bit 12:23 of section offset
       IMAGE_REL_ARM64_SECREL_LOW12L  = $000B;  // LDR (indexed, unsigned immediate), for bit 0:11 of section offset
       IMAGE_REL_ARM64_TOKEN          = $000C;
       IMAGE_REL_ARM64_SECTION        = $000D;  // Section table index
       IMAGE_REL_ARM64_ADDR64         = $000E;  // 64 bit address
       IMAGE_REL_ARM64_BRANCH19       = $000F;  // 19 bit offset << 2 & sign ext. for conditional B
{$endif aarch64}

       { .reloc section fixup types }
       IMAGE_REL_BASED_HIGHLOW     = 3;  { Applies the delta to the 32-bit field at Offset. }
       IMAGE_REL_BASED_DIR64       = 10; { Applies the delta to the 64-bit field at Offset. }

       { values for coffsectionrec.select }
       IMAGE_COMDAT_SELECT_NODUPLICATES = 1;
       IMAGE_COMDAT_SELECT_ANY          = 2;
       IMAGE_COMDAT_SELECT_SAME_SIZE    = 3;
       IMAGE_COMDAT_SELECT_EXACT_MATCH  = 4;
       IMAGE_COMDAT_SELECT_ASSOCIATIVE  = 5;
       IMAGE_COMDAT_SELECT_LARGEST      = 6;

    type
       TCOFFDJOptHeader=packed record
         magic  : word;
         vstamp : word;
         tsize  : LongInt;
         dsize  : LongInt;
         bsize  : LongInt;
         entry  : LongInt;
         text_start : LongInt;
         data_start : LongInt;
       end;
       TCOFFSectionRec=packed record
         len     : LongWord;
         nrelocs : word;
         nlines  : word;
         checksum: LongWord;
         assoc   : word;
         select  : byte;
         reserved: byte;
         assocHigh: word;
       end;
       PCOFFSectionRec=^TCOFFSectionRec;
       TCOFFReloc=packed record
         address  : LongWord;
         sym      : LongWord;
         reloctype : word;
       end;
       TStrTableOffset=packed record
         Zeroes : LongWord;
         Offset : LongWord;
       end;
       TCOFFSymbol=packed record
         name    : array[0..3] of char; { real is [0..7], which overlaps the strpos ! }
         strpos  : LongWord;
         value   : LongWord;
         section : smallint;
         empty   : word;                { actually type, $20: function, 0: not a function }
         typ     : byte;
         aux     : byte;
       end;
       TCOFFBigObjSymbol=packed record
         Name               : record
                                case boolean of
                                  True: (ShortName : array[0..7] of char);
                                  False: (Offset : TStrTableOffset)
                              end;
         Value              : LongWord;
         SectionNumber      : LongWord;
         _Type              : word;
         StorageClass       : byte;
         NumberOfAuxSymbols : byte;
       end;

       { This is defined in rtl/win/sysos.inc source }
       TTLSDirectory=packed record
         data_start, data_end : GlobType.PUint;
         index_pointer, callbacks_pointer : GlobType.PUint;
         zero_fill_size : dword;
         flags : dword;
       end;

       TPECoffExpDir=packed record
         flag,
         stamp      : cardinal;
         Major,
         Minor      : word;
         Name,
         Base,
         NumFuncs,
         NumNames,
         AddrFuncs,
         AddrNames,
         AddrOrds   : cardinal;
       end;
       { MaybeSwap procedures
       tcoffpedatadir = packed record
         vaddr : longword;
         size  : longword;
       end; }
   procedure MaybeSwap(var v : TCOFFPEDataDir);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.vaddr:=SwapEndian(v.vaddr);
            v.Size:=SwapEndian(v.Size);
          end;
      end;
 (*
       tcoffheader = packed record
         mach   : word;
         nsects : word;
         time   : longword;
         sympos : longword;
         syms   : longword;
         opthdr : word;
         flag   : word;
       end; *)
   procedure MaybeSwap(var v : TCOFFHeader);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.mach:=SwapEndian(v.mach);
            v.nsects:=SwapEndian(v.nsects);
            v.time:=SwapEndian(v.time);
            v.sympos:=SwapEndian(v.sympos);
            v.syms:=SwapEndian(v.syms);
            v.opthdr:=SwapEndian(v.opthdr);
            v.flag:=SwapEndian(v.flag);
          end;
      end;
(*
       tcoffbigobjheader = packed record
         Sig1 : word;
         Sig2 : word;
         Version : word;
         Machine : word;
         TimeDateStame : longword;
         UUID : array[0..15] of byte;
         unused : array[0..3] of longword;
         NumberOfSections : longword;
         PointerToSymbolTable : longword;
         NumberOfSymbols : longword;
       end; *)
   procedure MaybeSwap(var v : TCOFFBigObjHeader);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.Sig1:=SwapEndian(v.Sig1);
            v.Sig2:=SwapEndian(v.Sig2);
            v.Version:=SwapEndian(v.Version);
            v.Machine:=SwapEndian(v.Machine);
            v.TimeDateStame:=SwapEndian(v.TimeDateStame);
	    { UUID byte array no swap needed }
	    { Assume unused fields are indeed really unused }
            v.NumberOfSections:=SwapEndian(v.NumberOfSections);
            v.PointerToSymbolTable:=SwapEndian(v.PointerToSymbolTable);
            v.NumberOfSymbols:=SwapEndian(v.NumberOfSymbols);
          end;
      end;

(*       tcoffpeoptheader = packed record
         Magic : word;
         MajorLinkerVersion : byte;
         MinorLinkerVersion : byte;
         tsize : longword;
         dsize : longword;
         bsize : longword;
         entry : longword;
         text_start : longword;
{$ifndef cpu64bitaddr}
         data_start : longword;
{$endif cpu64bitaddr}
         ImageBase : aword;
         SectionAlignment : longword;
         FileAlignment : longword;
         MajorOperatingSystemVersion : word;
         MinorOperatingSystemVersion : word;
         MajorImageVersion : word;
         MinorImageVersion : word;
         MajorSubsystemVersion : word;
         MinorSubsystemVersion : word;
         Win32Version : longword;
         SizeOfImage : longword;
         SizeOfHeaders : longword;
         CheckSum : longword;
         Subsystem : word;
         DllCharacteristics : word;
         SizeOfStackReserve : aword;
         SizeOfStackCommit : aword;
         SizeOfHeapReserve : aword;
         SizeOfHeapCommit : aword;
         LoaderFlags : longword;          { This field is obsolete }
         NumberOfRvaAndSizes : longword;
         DataDirectory : array[0..PE_DATADIR_ENTRIES-1] of tcoffpedatadir;
       end; *)
    procedure MaybeSwap(var v : TCOFFPEOptHeader);
      var
        i : LongInt;
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.Magic:=SwapEndian(v.Magic);
            v.tsize:=SwapEndian(v.tsize);
            v.dsize:=SwapEndian(v.dsize);
            v.bsize:=SwapEndian(v.bsize);
            v.entry:=SwapEndian(v.entry);
            v.text_start:=SwapEndian(v.text_start);
{$ifndef cpu64bitaddr}
            v.data_start:=SwapEndian(v.data_start);
{$endif cpu64bitaddr}
            v.ImageBase:=SwapEndian(v.ImageBase);
            v.SectionAlignment:=SwapEndian(v.SectionAlignment);
            v.FileAlignment:=SwapEndian(v.FileAlignment);
            v.MajorOperatingSystemVersion:=SwapEndian(v.MajorOperatingSystemVersion);
            v.MinorOperatingSystemVersion:=SwapEndian(v.MinorOperatingSystemVersion);
            v.MajorImageVersion:=SwapEndian(v.MajorImageVersion);
            v.MinorImageVersion:=SwapEndian(v.MinorImageVersion);
            v.MajorSubsystemVersion:=SwapEndian(v.MajorSubsystemVersion);
            v.MinorSubsystemVersion:=SwapEndian(v.MinorSubsystemVersion);
            v.Win32Version:=SwapEndian(v.Win32Version);
            v.SizeOfImage:=SwapEndian(v.SizeOfImage);
            v.SizeOfHeaders:=SwapEndian(v.SizeOfHeaders);
            v.CheckSum:=SwapEndian(v.CheckSum);
            v.Subsystem:=SwapEndian(v.Subsystem);
            v.DllCharacteristics:=SwapEndian(v.DllCharacteristics);
            v.SizeOfStackReserve:=SwapEndian(v.SizeOfStackReserve);
            v.SizeOfStackCommit:=SwapEndian(v.SizeOfStackCommit);
            v.SizeOfHeapReserve:=SwapEndian(v.SizeOfHeapReserve);
            v.SizeOfHeapCommit:=SwapEndian(v.SizeOfHeapCommit);
            v.LoaderFlags:=SwapEndian(v.LoaderFlags);
            v.NumberOfRvaAndSizes:=SwapEndian(v.NumberOfRvaAndSizes);
	    for i:=0 to PE_DATADIR_ENTRIES-1 do
              MaybeSwap(v.DataDirectory[i]);
          end;
      end;

(*
       tcoffsechdr = packed record
         name     : array[0..7] of char;
         vsize    : longword;
         rvaofs   : longword;
         datasize : longword;
         datapos  : longword;
         relocpos : longword;
         lineno1  : longword;
         nrelocs  : word;
         lineno2  : word;
         flags    : longword;
       end; *)
    procedure MaybeSwap(var v : TCOFFSecHdr);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.vsize:=SwapEndian(v.vsize);
            v.rvaofs:=SwapEndian(v.rvaofs);
            v.DataSize:=SwapEndian(v.DataSize);
            v.datapos:=SwapEndian(v.datapos);
            v.relocpos:=SwapEndian(v.relocpos);
            v.lineno1:=SwapEndian(v.lineno1);
            v.nrelocs:=SwapEndian(v.nrelocs);
            v.lineno2:=SwapEndian(v.lineno2);
            v.flags:=SwapEndian(v.flags);
          end;
      end;
(*
      coffdjoptheader=packed record
         magic  : word;
         vstamp : word;
         tsize  : longint;
         dsize  : longint;
         bsize  : longint;
         entry  : longint;
         text_start : longint;
         data_start : longint;
       end; *)
    procedure MaybeSwap(var v : TCOFFDJOptHeader);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.magic:=SwapEndian(v.magic);
            v.vstamp:=SwapEndian(v.vstamp);
            v.tsize:=SwapEndian(v.tsize);
            v.dsize:=SwapEndian(v.dsize);
            v.bsize:=SwapEndian(v.bsize);
            v.entry:=SwapEndian(v.entry);
            v.text_start:=SwapEndian(v.text_start);
            v.data_start:=SwapEndian(v.data_start);
          end;
      end;
(*
       coffsectionrec=packed record
         len     : longword;
         nrelocs : word;
         nlines  : word;
         checksum: longword;
         assoc   : word;
         select  : byte;
         empty   : array[0..2] of char;
       end; *)
    procedure MaybeSwap(var v : TCOFFSectionRec);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.len:=SwapEndian(v.len);
            v.nrelocs:=SwapEndian(v.nrelocs);
            v.nlines:=SwapEndian(v.nlines);
            v.checksum:=SwapEndian(v.checksum);
            v.assoc:=SwapEndian(v.assoc);
            v.assocHigh:=SwapEndian(v.assocHigh);
          end;
      end;
(*
       coffreloc=packed record
         address  : longword;
         sym      : longword;
         reloctype : word;
       end; *)
    procedure MaybeSwap(var v : TCOFFReloc);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.address:=SwapEndian(v.address);
            v.sym:=SwapEndian(v.sym);
            v.reloctype:=SwapEndian(v.reloctype);
          end;
      end;
(*
       strtableoffset=packed record
         Zeroes : longword;
         Offset : longword;
       end;*)
    procedure MaybeSwap(var v : TStrTableOffset);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.Zeroes:=SwapEndian(v.Zeroes);
            v.Offset:=SwapEndian(v.Offset);
          end;
      end;
(*
       coffsymbol=packed record
         name    : array[0..3] of char; { real is [0..7], which overlaps the strpos ! }
         strpos  : longword;
         value   : longword;
         section : smallint;
         empty   : word;                { actually type, $20: function, 0: not a function }
         typ     : byte;
         aux     : byte;
       end; *)
    procedure MaybeSwap(var v : TCOFFSymbol);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            if v.name[0]=#0 then
              v.strpos:=SwapEndian(v.strpos);
            v.Value:=SwapEndian(v.Value);
            v.section:=SwapEndian(v.section);
            v.empty:=SwapEndian(v.empty);
          end;
      end;
(*
       coffbigobjsymbol=packed record
         Name               : record
                                case boolean of
                                  True: (ShortName : array[0..7] of char);
                                  False: (Offset : strtableoffset)
                              end;
         Value              : longword;
         SectionNumber      : longword;
         _Type              : word;
         StorageClass       : byte;
         NumberOfAuxSymbols : byte;
       end; *)

    procedure MaybeSwap(var v : TCOFFBigObjSymbol);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            if (true) then
              MaybeSwap(v.Name.Offset);
            v.Value:=SwapEndian(v.Value);
            v.SectionNumber:=SwapEndian(v.SectionNumber);
            v._Type:=SwapEndian(v._Type);
          end;
      end;
(*
       { This is defined in rtl/win/sysos.inc source }
       tlsdirectory=packed record
         data_start, data_end : PUInt;
         index_pointer, callbacks_pointer : PUInt;
         zero_fill_size : dword;
         flags : dword;
       end;
     *)
    procedure MaybeSwap(var v : TTLSDirectory);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.data_start:=SwapEndian(v.data_start);
            v.data_end:=SwapEndian(v.data_end);
            v.index_pointer:=SwapEndian(v.index_pointer);
            v.callbacks_pointer:=SwapEndian(v.callbacks_pointer);
            v.zero_fill_size:=SwapEndian(v.zero_fill_size);
            v.flags:=SwapEndian(v.flags);
          end;
      end;
(*
      TPECoffExpDir=packed record
         flag,
         stamp      : cardinal;
         Major,
         Minor      : word;
         Name,
         Base,
         NumFuncs,
         NumNames,
         AddrFuncs,
         AddrNames,
         AddrOrds   : cardinal;
       end;
     *)
    procedure MaybeSwap(var v : TPECoffExpDir);
      begin
        if SourceInfo.endian<>TargetInfo.endian then
          begin
            v.flag:=SwapEndian(v.flag);
            v.stamp:=SwapEndian(v.stamp);
            v.Major:=SwapEndian(v.Major);
            v.Minor:=SwapEndian(v.Minor);
            v.Name:=SwapEndian(v.Name);
            v.Base:=SwapEndian(v.Base);
            v.NumFuncs:=SwapEndian(v.NumFuncs);
            v.NumNames:=SwapEndian(v.NumNames);
            v.AddrFuncs:=SwapEndian(v.AddrFuncs);
            v.AddrNames:=SwapEndian(v.AddrNames);
            v.AddrOrds:=SwapEndian(v.AddrOrds);
          end;
     end;

     const
       SymbolMaxGrow = 200*sizeof(TCOFFSymbol);
       StrsMaxGrow   = 8192;

       coffsecnames : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text','.data','.rdata','.rdata','.bss','.tls',
          '.pdata',{pdata}
          '.text', {stub}
          '.data',
          '.data',
          '.data',
          '.data',
          '.idata$2','.idata$4','.idata$5','.idata$6','.idata$7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges','.debug_loc','.debug_loclists',
          '.fpc',
          '',
          '.init',
          '.fini',
          '.objc_class',
          '.objc_meta_class',
          '.objc_cat_cls_meth',
          '.objc_cat_inst_meth',
          '.objc_protocol',
          '.objc_string_object',
          '.objc_cls_meth',
          '.objc_inst_meth',
          '.objc_cls_refs',
          '.objc_message_refs',
          '.objc_symbols',
          '.objc_category',
          '.objc_class_vars',
          '.objc_instance_vars',
          '.objc_module_info',
          '.objc_class_names',
          '.objc_meth_var_types',
          '.objc_meth_var_names',
          '.objc_selector_strs',
          '.objc_protocol_ext',
          '.objc_class_ext',
          '.objc_property',
          '.objc_image_info',
          '.objc_cstring_object',
          '.objc_sel_fixup',
          '__DATA,__objc_data',
          '__DATA,__objc_const',
          '.objc_superrefs',
          '__DATA, __datacoal_nt,coalesced',
          '.objc_classlist',
          '.objc_nlclasslist',
          '.objc_catlist',
          '.obcj_nlcatlist',
          '.objc_protolist',
          '.stack',
          '.heap',
          '.gcc_except_table',
          '.ARM.attributes',
          '.note'
        );

const win32stub : array[0..127] of byte=(
  $4D,$5A,$90,$00,$03,$00,$00,$00,$04,$00,$00,$00,$FF,$FF,$00,$00,
  $B8,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00,$00,$00,
  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,
  $0E,$1F,$BA,$0E,$00,$B4,$09,$CD,$21,$B8,$01,$4C,$CD,$21,$54,$68,
  $69,$73,$20,$70,$72,$6F,$67,$72,$61,$6D,$20,$63,$61,$6E,$6E,$6F,
  $74,$20,$62,$65,$20,$72,$75,$6E,$20,$69,$6E,$20,$44,$4F,$53,$20,
  $6D,$6F,$64,$65,$2E,$0D,$0D,$0A,$24,$00,$00,$00,$00,$00,$00,$00);

const pemagic : array[0..3] of byte = (
  $50,$45,$00,$00);

{****************************************************************************
                                 Helpers
****************************************************************************}

    function djencodesechdrflags(aoptions:TObjSectionOptions):LongWord;
      begin
        if (oso_load in aoptions) then
          begin
            if oso_executable in aoptions then
              result:=COFF_STYP_TEXT
            else if not(oso_data in aoptions) then
              result:=COFF_STYP_BSS
            else
              result:=COFF_STYP_DATA;
          end
        else if oso_debug in aoptions then
          result:=COFF_STYP_INFO
        else
          result:=COFF_STYP_REG;
      end;


    function djdecodesechdrflags(const aname:string;flags:LongWord):TObjSectionOptions;
      begin
        result:=[];
        if flags and COFF_STYP_TEXT<>0 then
          result:=[oso_data,oso_load,oso_executable]
        else if flags and COFF_STYP_BSS<>0 then
          result:=[oso_load]
        else if flags and COFF_STYP_DATA<>0 then
          result:=[oso_data,oso_load]
        else if flags and COFF_STYP_INFO<>0 then
          result:=[oso_data,oso_debug]
        else
          result:=[oso_data]
      end;


    function peencodesechdrflags(aoptions:TObjSectionOptions;aalign:LongInt):LongWord;
      begin
        if oso_executable in aoptions then
          result:=PE_SCN_CNT_CODE or PE_SCN_MEM_EXECUTE
        else
          begin
            if (oso_data in aoptions) then
              result:=PE_SCN_CNT_INITIALIZED_DATA
            else
              result:=PE_SCN_CNT_UNINITIALIZED_DATA;
          end;
        if oso_write in aoptions then
          result:=result or PE_SCN_MEM_WRITE or PE_SCN_MEM_READ
        else
          result:=result or PE_SCN_MEM_READ;
        if not (oso_load in aoptions) then
          result:=result or PE_SCN_MEM_DISCARDABLE;
        if oso_comdat in aoptions then
          result:=result or PE_SCN_LNK_COMDAT;
        case aalign of
           1 : result:=result or PE_SCN_ALIGN_1BYTES;
           2 : result:=result or PE_SCN_ALIGN_2BYTES;
           4 : result:=result or PE_SCN_ALIGN_4BYTES;
           8 : result:=result or PE_SCN_ALIGN_8BYTES;
          16 : result:=result or PE_SCN_ALIGN_16BYTES;
          32 : result:=result or PE_SCN_ALIGN_32BYTES;
          64 : result:=result or PE_SCN_ALIGN_64BYTES;
         128 : result:=result or PE_SCN_ALIGN_128BYTES;
         256 : result:=result or PE_SCN_ALIGN_256BYTES;
         512 : result:=result or PE_SCN_ALIGN_512BYTES;
        1024 : result:=result or PE_SCN_ALIGN_1024BYTES;
        2048 : result:=result or PE_SCN_ALIGN_2048BYTES;
        4096 : result:=result or PE_SCN_ALIGN_4096BYTES;
        8192 : result:=result or PE_SCN_ALIGN_8192BYTES;
          else result:=result or PE_SCN_ALIGN_16BYTES;
        end;
      end;


    procedure pedecodesechdrflags(const aname:string;flags:LongWord;out aoptions:TObjSectionOptions;out aalign:LongInt);
      var
        alignflag : LongWord;
      begin
        aoptions:=[];
        if flags and PE_SCN_CNT_CODE<>0 then
          include(aoptions,oso_executable);
        if flags and PE_SCN_MEM_DISCARDABLE<>0 then
          include(aoptions,oso_debug);
        if flags and PE_SCN_CNT_UNINITIALIZED_DATA=0 then
          include(aoptions,oso_data);
        if (flags and (PE_SCN_LNK_REMOVE or PE_SCN_MEM_DISCARDABLE)=0) then
          include(aoptions,oso_load);
        if flags and PE_SCN_LNK_COMDAT<>0 then
          include(aoptions,oso_comdat);
        { read/write }
        if flags and PE_SCN_MEM_WRITE<>0 then
          include(aoptions,oso_write);
        { alignment }
        alignflag:=flags and PE_SCN_ALIGN_MASK;
        if alignflag=PE_SCN_ALIGN_8192BYTES then
          aalign:=8192
        else if alignflag=PE_SCN_ALIGN_4096BYTES then
          aalign:=4096
        else if alignflag=PE_SCN_ALIGN_2048BYTES then
          aalign:=2048
        else if alignflag=PE_SCN_ALIGN_1024BYTES then
          aalign:=1024
        else if alignflag=PE_SCN_ALIGN_512BYTES then
          aalign:=512
        else if alignflag=PE_SCN_ALIGN_256BYTES then
          aalign:=256
        else if alignflag=PE_SCN_ALIGN_128BYTES then
          aalign:=128
        else if alignflag=PE_SCN_ALIGN_64BYTES then
          aalign:=64
        else if alignflag=PE_SCN_ALIGN_32BYTES then
          aalign:=32
        else if alignflag=PE_SCN_ALIGN_16BYTES then
          aalign:=16
        else if alignflag=PE_SCN_ALIGN_8BYTES then
          aalign:=8
        else if alignflag=PE_SCN_ALIGN_4BYTES then
          aalign:=4
        else if alignflag=PE_SCN_ALIGN_2BYTES then
          aalign:=2
        else if alignflag=PE_SCN_ALIGN_1BYTES then
          aalign:=1
        else if alignflag=0 then
          aalign:=0
        else
          InternalError(2009050401);
      end;


    function encodeBase64(p:aword):string;
      const
        alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
                   'abcdefghijklmnopqrstuvwxyz' +
                   '0123456789+/';
      var
        i,
        idx,
        rem : LongInt;
      begin
        SetLength(result,6);

        idx := 6;
        for i:=0 to 5 do
          begin
            rem:=p mod 64;
            p:=p div 64;
            result[idx]:=alphabet[rem+1];
            dec(idx);
          end;

        if p<>0 then
          InternalError(2020091601);
      end;


    function decodeBase64(const s:string;out p:LongInt):boolean;
      var
        i : LongInt;
        v : aword;
      begin
        if length(s)>6 then
          exit(false);

        p:=0;
        for i:=1 to length(s) do
          begin
            v:=0;
            if (s[i]>='A') and (s[i]<='Z') then // 0..25
              v:=Ord(s[i])-Ord('A')
            else if (s[i]>='a') and (s[i]<='z') then // 26..51
              v:=Ord(s[i])-Ord('a')+26
            else if (s[i]>='0') and (s[i]<='9') then // 52..61
              v:=Ord(s[i])-Ord('0')+52
            else if s[i]='+' then // 62
              v:=62
            else if s[i]='/' then // 63
              v:=63
            else
              exit(false);

            p:=(p*64)+v;
          end;

        result:=true;
      end;


{****************************************************************************
                               TCoffObjSection
****************************************************************************}

    constructor TCoffObjSection.Create(AList:TFPHashObjectList;const aname:string;aalign:LongInt;aoptions:TObjSectionOptions);
      begin
        inherited Create(AList,aname,aalign,aoptions);
      end;


    procedure TCoffObjSection.writereloc_internal(aTarget:TObjSection;offset:aword;len:byte;reltype:TObjRelocationType);
      begin
        AddSectionReloc(size,aTarget,reltype);
        write(offset,len);
      end;

{ We don't want overflow nor range checks here,
  wrapping is accepted in the address computation below }
{$r-}
{$q-}

    constructor TCoffObjData.createcoff(const n:string;awin32:boolean;acObjSection:TObjSectionClass);
      begin
        inherited Create(n);
        CObjSection:=ACObjSection;
        win32:=awin32;
      end;


    function TCoffObjData.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      var
        sep     : string[3];
        secname : string;
      begin
        { section type user gives the user full control on the section name }
        if atype=sec_user then
          result:=aname
        else
          begin
            { non-PECOFF targets lack rodata support }
            if (atype in [sec_rodata,sec_rodata_norel]) and
               not (TargetInfo.system in systems_all_windows) then
              atype:=sec_data;
            secname:=coffsecnames[atype];
            if create_smartlink_sections and
               (aname<>'') then
              begin
                case aorder of
                  secorder_begin :
                    if TargetInfo.system=system_x86_64_win64 then
                      sep:='$B_'
                    else
                      sep:='.b_';
                  secorder_end :
                    if TargetInfo.system=system_x86_64_win64 then
                      sep:='$Y_'
                    else
                      sep:='.z_';
                  else
                    if TargetInfo.system=system_x86_64_win64 then
                      sep:='$N_'
                    else
                      sep:='.n_';
                end;
                result:=secname+sep+aname
              end
            else
              result:=secname;
          end;
      end;


    function TCoffObjData.createsection(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):TObjSection;
      begin
        result:=inherited createsection(atype,aname,aorder);
        if (TargetInfo.system=system_x86_64_win64) and
           create_smartlink_sections and
           (aname<>'') and
           not (atype in [sec_user,sec_fpc,sec_pdata]) then
          begin
            result.SecOptions:=result.SecOptions+[oso_comdat];
            result.ComdatSelection:=oscs_none;
          end;
      end;


    function TCoffObjData.createsection(atype:TAsmSectiontype;secflags:TSectionFlags;aprogbits:TSectionProgbits;const aname:string;aorder:TAsmSectionOrder):TObjSection;
      begin
        result:=inherited createsection(atype,secflags,aprogbits,aname,aorder);
        if (TargetInfo.system=system_x86_64_win64) and
           create_smartlink_sections and
           (aname<>'') and
           not (atype in [sec_user,sec_fpc,sec_pdata]) then
          begin
            result.SecOptions:=result.SecOptions+[oso_comdat];
            result.ComdatSelection:=oscs_none;
          end;
      end;


    procedure TCoffObjData.writereloc(data:aint;len:aword;p:TObjSymbol;reloctype:TObjRelocationType);
      type
        TRelocData = record
          case integer of
          0 : (ba : array[0..sizeof(aint)-1] of byte);
          1 : (b : byte);
          2 : (w : word);
          4 : (d : dword);
          8 : (q : qword);
        end;

      var
        ba : TRelocData;
        curraddr,
        symaddr : aword;
      begin
        if CurrObjSec=nil then
          InternalError(2004030701);
        if Assigned(p) then
          begin
            { current address }
            curraddr:=CurrObjSec.mempos+CurrObjSec.Size;
            { external/common symbols don't have a fixed memory position yet }
            if (p.bind=AB_COMMON) then
              begin
                { For go32v2 we need to use the size as address }
                if not win32 then
                  symaddr:=p.Size
                else
                  symaddr:=0;
              end
            else
              symaddr:=p.address;
            { no symbol relocation need inside a section }
            if (p.objsection=CurrObjSec) and
               (p.bind<>AB_COMMON) then
              begin
                case reloctype of
                  RELOC_ABSOLUTE :
                    begin
                      CurrObjSec.addsectionreloc(curraddr,CurrObjSec,RELOC_ABSOLUTE);
                      inc(data,symaddr);
                    end;
{$ifdef cpu64bitaddr}
                  RELOC_ABSOLUTE32 :
                    begin
                      CurrObjSec.addsectionreloc(curraddr,CurrObjSec,RELOC_ABSOLUTE32);
                      inc(data,symaddr);
                    end;
{$endif cpu64bitaddr}
                  RELOC_RELATIVE :
                    begin
                      //inc(data,symaddr-len-CurrObjSec.Size);
                      data:=data+symaddr-len-CurrObjSec.Size;
                    end;
                  RELOC_RVA,
                  RELOC_SECREL32 :
                    begin
                      CurrObjSec.addsectionreloc(curraddr,CurrObjSec,reloctype);
                      inc(data,symaddr);
                    end;
                  else
                    InternalError(200604013);
                end;
              end
            else
              begin
                if (p.objsection<>nil) and
                   (p.bind<>AB_COMMON) then
                  CurrObjSec.addsectionreloc(curraddr,p.objsection,reloctype)
                else
                  CurrObjSec.addsymreloc(curraddr,p,reloctype);
                if (not win32) or
                   (p.objsection<>nil) then
                  inc(data,symaddr);
                if reloctype=RELOC_RELATIVE then
                  begin
                    if win32 then
                      dec(data,len-4)
                    else
                      dec(data,len+CurrObjSec.Size);
                  end;
              end;
          end
        else
          begin
            if reloctype=RELOC_RVA then
              InternalError(200603033);
          end;
        if TargetInfo.endian<>SourceInfo.endian then
          begin
            ba.q:=0;
            if (len<=sizeof(data)) then
              case len of
                1 : ba.b:=byte(data);
                2 : begin
                      ba.w:=word(data);
                      ba.w:=swapendian(ba.w);
                    end;
                4 : begin
                      ba.d:=dword(data);
                      ba.d:=swapendian(ba.d);
                    end;
                8 : begin
                      ba.q:=qword(data);
                      ba.q:=swapendian(ba.q);
                    end;
              else
                InternalError(2024012501);
              end;
            CurrObjSec.write(ba,len);
          end
        else
          CurrObjSec.write(data,len);
      end;


{****************************************************************************
                                TDJCoffObjData
****************************************************************************}

    constructor TDJCoffObjData.Create(const n:string);
      begin
        inherited createcoff(n,false,TCoffObjSection);
      end;


{****************************************************************************
                                TPECoffObjData
****************************************************************************}

    constructor TPECoffObjData.Create(const n:string);
      begin
        inherited createcoff(n,true,TCoffObjSection);
      end;


{****************************************************************************
                                TCoffObjOutput
****************************************************************************}

    constructor TCoffObjOutput.createcoff(AWriter:TObjectWriter;awin32:boolean);
      begin
        inherited Create(AWriter);
        win32:=awin32;
      end;


    destructor TCoffObjOutput.Destroy;
      begin
        FCoffSyms.free;
        FCoffSyms := nil;
        FCoffStrs.free;
        FCoffStrs := nil;
        inherited Destroy;
      end;


    procedure TCoffObjOutput.write_symbol(const name:string;value:aword;section:LongInt;typ,aux:byte);
      var
        sym : TCOFFSymbol;
        bosym : TCOFFBigObjSymbol;
        strpos : LongWord;
      begin
        { symbolname }
        if length(name)>8 then
          begin
            strpos:=FCoffStrs.Size+4;
            FCoffStrs.WriteStr(name);
            FCoffStrs.WriteStr(#0);
          end
        else
          strpos:=0;

        if bigobj then
          begin
            fillchar(bosym,sizeof(bosym),0);
            if length(name)>8 then
              bosym.name.Offset.Offset:=strpos
            else
              move(name[1],bosym.name.shortname,length(name));
            bosym.Value:=value;
            bosym.SectionNumber:=LongWord(section);
            bosym.StorageClass:=typ;
            bosym.NumberOfAuxSymbols:=aux;
            inc(symidx);
	    MaybeSwap(bosym);
            FCoffSyms.write(bosym,sizeof(bosym));
          end
        else
          begin
            if section>$7fff then
              InternalError(2017020302);
            FillChar(sym,sizeof(sym),0);
            if length(name)>8 then
              sym.strpos:=strpos
            else
              move(name[1],sym.name,length(name));
            sym.Value:=value;
            sym.section:=section;
            sym.typ:=typ;
            sym.aux:=aux;
            inc(symidx);
	    MaybeSwap(sym);
            FCoffSyms.write(sym,sizeof(sym));
          end;
      end;


    procedure TCoffObjOutput.section_write_symbol(p:TObject;arg:pointer);
      var
        secrec : TCOFFSectionRec;
        comdatkey : string;
        padding : word;
      begin
        with TCoffObjSection(p) do
          begin
            Inc(plongword(arg)^);
            index:=plongword(arg)^;

            secsymidx:=symidx;
            { Both GNU and Microsoft toolchains write section symbols using
              storage class 3 (STATIC).
              No reason to use COFF_SYM_SECTION, it is silently converted to 3 by
              PE binutils and causes warnings with DJGPP binutils. }
            write_symbol(name,mempos,index,COFF_SYM_LOCAL,1);
            { AUX }
            fillchar(secrec,sizeof(secrec),0);
            secrec.len:=Size;
            if ObjRelocations.count<65535 then
              secrec.nrelocs:=ObjRelocations.count
            else
              secrec.nrelocs:=65535;
            if oso_comdat in SecOptions then
              begin
                case ComdatSelection of
                  oscs_none:
                    secrec.select:=IMAGE_COMDAT_SELECT_NODUPLICATES;
                  oscs_any:
                    secrec.select:=IMAGE_COMDAT_SELECT_ANY;
                  oscs_same_size:
                    secrec.select:=IMAGE_COMDAT_SELECT_SAME_SIZE;
                  oscs_exact_match:
                    secrec.select:=IMAGE_COMDAT_SELECT_EXACT_MATCH;
                  oscs_associative:
                    begin
                      secrec.select:=IMAGE_COMDAT_SELECT_ASSOCIATIVE;
                      if not Assigned(AssociativeSection) then
                        InternalError(2026092201);
                      secrec.assoc:=word(AssociativeSection.Index and $ffff);
                      secrec.assocHigh:=word(AssociativeSection.Index shr 16);
                    end;
                  oscs_largest:
                    secrec.select:=IMAGE_COMDAT_SELECT_LARGEST;
                end;
              end;
            inc(symidx);
	    MaybeSwap(secrec);
            FCoffSyms.write(secrec,sizeof(secrec));
            { aux recs have the same size as symbols, so we need to add two
              Byte of padding in case of a Big Obj Coff }
            padding:=0;
            if bigobj then
              FCoffSyms.write(padding,sizeof(padding));
            { A non-associative COMDAT needs a public key symbol. }
            if (oso_comdat in SecOptions) and
               (ComdatSelection<>oscs_associative) then
              begin
                if ComdatSelection=oscs_none then
                  { NODUPLICATES smartlink sections need a unique key. }
                  comdatkey:='$fpc$comdat$'+lower(CurrentModule.ModuleName^)+'$'+ToStr(index)
                else
                  { Other selection modes coalesce sections with the same
                    stable section-based key. }
                  comdatkey:='$fpc$comdat$'+name;
                write_symbol(comdatkey,0,index,COFF_SYM_GLOBAL,0);
              end;
          end;
      end;


    procedure TCoffObjOutput.section_write_relocs(p:TObject;arg:pointer);
      var
        i    : LongInt;
        rel  : TCOFFReloc;
        objreloc : TObjRelocation;
      begin
        if (TObjSection(p).ObjRelocations.Count>65535) then
          begin
            rel.address:=TObjSection(p).ObjRelocations.Count+1;
            rel.sym:=0;
            rel.reloctype:=0;
	    MaybeSwap(rel);
            FWriter.Write(rel,sizeof(rel));
          end;
        for i:=0 to TObjSection(p).ObjRelocations.Count-1 do
          begin
            objreloc:=TObjRelocation(TObjSection(p).ObjRelocations[i]);
            rel.address:=objreloc.dataoffset;
            if Assigned(objreloc.Symbol) then
              begin
                if (objreloc.Symbol.bind=AB_LOCAL) then
                  rel.sym:=objreloc.Symbol.objsection.secsymidx
                else
                  begin
                    if objreloc.Symbol.symidx=-1 then
                      InternalError(200602233);
                    rel.sym:=objreloc.Symbol.symidx;
                  end;
              end
            else
              begin
                if objreloc.objsection<>nil then
                  rel.sym:=objreloc.objsection.secsymidx
                else
                  rel.sym:=0;
              end;
            case objreloc.typ of
{$ifdef i386}
              RELOC_RELATIVE :
                rel.reloctype:=IMAGE_REL_I386_PCRLONG;
              RELOC_ABSOLUTE :
                rel.reloctype:=IMAGE_REL_I386_DIR32;
              RELOC_RVA :
                rel.reloctype:=IMAGE_REL_I386_IMAGEBASE;
              RELOC_SECREL32 :
                rel.reloctype:=IMAGE_REL_I386_SECREL32;
{$endif i386}
{$ifdef x86_64}
              RELOC_NONE :
                rel.reloctype:=IMAGE_REL_AMD64_ABSOLUTE;
              RELOC_RELATIVE :
                rel.reloctype:=IMAGE_REL_AMD64_REL32;
              RELOC_ABSOLUTE32 :
                rel.reloctype:=IMAGE_REL_AMD64_ADDR32;
              RELOC_ABSOLUTE :
                rel.reloctype:=IMAGE_REL_AMD64_ADDR64;
              RELOC_RVA :
                rel.reloctype:=IMAGE_REL_AMD64_ADDR32NB;
              RELOC_RELATIVE_1 :
                rel.reloctype:=IMAGE_REL_AMD64_REL32_1;
              RELOC_RELATIVE_2 :
                rel.reloctype:=IMAGE_REL_AMD64_REL32_2;
              RELOC_RELATIVE_3 :
                rel.reloctype:=IMAGE_REL_AMD64_REL32_3;
              RELOC_RELATIVE_4 :
                rel.reloctype:=IMAGE_REL_AMD64_REL32_4;
              RELOC_RELATIVE_5 :
                rel.reloctype:=IMAGE_REL_AMD64_REL32_5;
              RELOC_SECREL32 :
                rel.reloctype:=IMAGE_REL_AMD64_SECREL;
{$endif x86_64}
{$ifdef aarch64}
              RELOC_NONE :
                rel.reloctype:=IMAGE_REL_ARM64_ABSOLUTE;
              RELOC_ABSOLUTE32 :
                rel.reloctype:=IMAGE_REL_ARM64_ADDR32;
              RELOC_RVA :
                rel.reloctype:=IMAGE_REL_ARM64_ADDR32NB;
              RELOC_RELATIVE_26 :
                rel.reloctype:=IMAGE_REL_ARM64_BRANCH26;
              RELOC_ADR_PREL_PG_HI21 :
                rel.reloctype:=IMAGE_REL_ARM64_PAGEBASE_REL21;
              RELOC_ADR_PREL_LO21 :
                rel.reloctype:=IMAGE_REL_ARM64_REL21;
              RELOC_ADD_ABS_LO12:
                rel.reloctype:=IMAGE_REL_ARM64_PAGEOFFSET_12A;
              RELOC_LDST8_ABS_LO12:
                rel.reloctype:=IMAGE_REL_ARM64_PAGEOFFSET_12L;
              RELOC_SECREL32:
                rel.reloctype:=IMAGE_REL_ARM64_SECREL;
              {IMAGE_REL_ARM64_SECREL_LOW12A
              IMAGE_REL_ARM64_SECREL_HIGH12A
              IMAGE_REL_ARM64_SECREL_LOW12L
              IMAGE_REL_ARM64_TOKEN
              IMAGE_REL_ARM64_SECTION}
              RELOC_ABSOLUTE:
                rel.reloctype:=IMAGE_REL_ARM64_ADDR64;
              RELOC_RELATIVE_19:
                rel.reloctype:=IMAGE_REL_ARM64_BRANCH19;
{$endif aarch64}
              else
                InternalError(200905071);
            end;
	    MaybeSwap(rel);
            FWriter.write(rel,sizeof(rel));
          end;
      end;


    procedure TCoffObjOutput.create_symbols(data:TObjData);
      var
        FileName   : string[20];
        filenamelen : LongInt;
        sectionval : word;
        globalval  : byte;
        i          : LongInt;
        value      : aword;
        objsym     : TObjSymbol;
        secidx     : LongWord;
      begin
        with TCoffObjData(data) do
         begin
           symidx:=0;
           { The `.file' record, and the file name auxiliary record }
           write_symbol('.file', 0, -2, COFF_SYM_FILE, 1);
           fillchar(FileName,sizeof(FileName),0);
           FileName:=ExtractFileName(CurrentModule.MainSource);
           inc(symidx);
           if bigobj then
             filenamelen:=sizeof(TCOFFBigObjSymbol)
           else
             filenamelen:=sizeof(TCOFFSymbol);
           FCoffSyms.write(FileName[1],filenamelen);
           { Sections }
            for i:=0 to ObjSectionList.Count-1 do
              TObjSection(ObjSectionList[i]).Index:=i+1;
            secidx:=0;
           ObjSectionList.ForEachCall(@section_write_symbol,@secidx);
           { ObjSymbols }
           for i:=0 to ObjSymbolList.Count-1 do
             begin
               objsym:=TObjSymbol(ObjSymbolList[i]);
               if (objsym.bind=AB_LOCAL) then
                 continue;
               case objsym.bind of
                 AB_GLOBAL,
                 AB_PRIVATE_EXTERN:
                   begin
                     globalval:=COFF_SYM_GLOBAL;
                     sectionval:=objsym.objsection.Index;
                     value:=objsym.address;
                   end;
                 AB_LOCAL :
                   begin
                     globalval:=COFF_SYM_LOCAL;
                     sectionval:=objsym.objsection.Index;
                     value:=objsym.address;
                   end;
                 else
                   begin
                     globalval:=COFF_SYM_GLOBAL;
                     sectionval:=0;
                     value:=objsym.Size;
                   end;
               end;
               { symbolname }
               objsym.symidx:=symidx;
               write_symbol(objsym.name,value,sectionval,globalval,0);
             end;
         end;
      end;


    procedure TCoffObjOutput.section_set_reloc_datapos(p:TCoffObjSection;var datapos:aword);
      begin
        p.coffrelocpos:=datapos;
        inc(datapos,sizeof(TCOFFReloc)*p.ObjRelocations.count);
        if p.ObjRelocations.count>65535 then
          begin
            if win32 then
              inc(datapos,sizeof(TCOFFReloc))
            else
              Message1(asmw_f_too_many_relocations,p.fullname);
          end;
      end;


    procedure TCoffObjOutput.section_write_header(p:TObject;arg:pointer);
      var
        sechdr   : TCOFFSecHdr;
        s        : string;
        strpos   : aword;
      begin
        with TCoffObjSection(p) do
          begin
            fillchar(sechdr,sizeof(sechdr),0);
            s:=name;
            if length(s)>8 then
             begin
               strpos:=FCoffStrs.Size+4;
               FCoffStrs.WriteStr(s);
               FCoffStrs.WriteStr(#0);
               if strpos>=10000000 then
                 s:='//'+encodeBase64(strpos)
               else
                 s:='/'+ToStr(strpos);
               if length(s)>8 then
                 InternalError(2020091501);
             end;
            move(s[1],sechdr.name,length(s));
            if not win32 then
              begin
                sechdr.rvaofs:=mempos;
                sechdr.vsize:=mempos;
              end
            else
              begin
                if not(oso_data in secoptions) then
                  sechdr.vsize:=Size;
              end;
            sechdr.DataSize:=size;
            if (Size>0) and
               (oso_data in secoptions) then
              sechdr.datapos:=datapos;
            if ObjRelocations.count<65535 then
              sechdr.nrelocs:=ObjRelocations.count
            else
              sechdr.nrelocs:=65535;
            sechdr.relocpos:=coffrelocpos;
            if win32 then
              begin
                sechdr.flags:=peencodesechdrflags(secoptions,secalign);
                if ObjRelocations.count>65535 then
                  sechdr.flags:=sechdr.flags or PE_SCN_LNK_NRELOC_OVFL;
              end
            else
              sechdr.flags:=djencodesechdrflags(secoptions);
            MaybeSwap(sechdr);
            FWriter.write(sechdr,sizeof(sechdr));
          end;
      end;


    function TCoffObjOutput.WriteData(data:TObjData):boolean;
      var
        datapos,
        sympos   : aword;
        i        : LongInt;
        header   : TCOFFHeader;
        boheader : TCOFFBigObjHeader;
      begin
        result:=false;
        FCoffSyms:=TDynamicArray.Create(SymbolMaxGrow);
        FCoffStrs:=TDynamicArray.Create(StrsMaxGrow);
        with TCoffObjData(data) do
         begin
           bigobj:=(ObjSectionList.Count>$7fff) and win32;

           { Create Symbol Table }
           create_symbols(data);

           { Calculate the filepositions }
           if bigobj then
             datapos:=sizeof(TCOFFBigObjHeader)
           else
             datapos:=sizeof(TCOFFHeader);
           datapos:=datapos+sizeof(TCOFFSecHdr)*ObjSectionList.Count;
           { Sections first }
           layoutsections(datapos);
           { relocs }
           for i:=0 to ObjSectionList.Count-1 do
             section_set_reloc_datapos(TCoffObjSection(ObjSectionList[i]),datapos);
           { Symbols }
           sympos:=datapos;

           { Generate COFF header }
           if bigobj then
             begin
               fillchar(boheader,sizeof(boheader),0);
               boheader.Sig1:=0;
               boheader.Sig2:=$ffff;
               boheader.Machine:=COFF_MAGIC;
               boheader.Version:=COFF_BIG_OBJ_VERSION;
               boheader.NumberOfSections:=LongWord(ObjSectionList.Count);
               boheader.NumberOfSymbols:=LongWord(symidx);
               boheader.PointerToSymbolTable:=sympos;
               Move(COFF_BIG_OBJ_MAGIC,boheader.UUID,length(boheader.UUID));
	       MaybeSwap(boheader);
               FWriter.write(boheader,sizeof(boheader));
             end
           else
             begin
               fillchar(header,sizeof(TCOFFHeader),0);
               header.mach:=COFF_MAGIC;
               header.nsects:=ObjSectionList.Count;
               header.sympos:=sympos;
               header.syms:=symidx;
               if win32 then
                 begin
{$ifndef cpu64bitaddr}
                   header.flag:=PE_FILE_32BIT_MACHINE or
                                PE_FILE_LINE_NUMS_STRIPPED or PE_FILE_LOCAL_SYMS_STRIPPED;
{$else cpu64bitaddr}
                   header.flag:=PE_FILE_LINE_NUMS_STRIPPED or PE_FILE_LOCAL_SYMS_STRIPPED;
{$endif cpu64bitaddr}
                 end
               else
                 header.flag:=COFF_FLAG_AR32WR or COFF_FLAG_NOLINES or COFF_FLAG_NOLSYMS;
	       MaybeSwap(header);
               FWriter.write(header,sizeof(header));
             end;
           { Section headers }
           ObjSectionList.ForEachCall(@section_write_header,nil);
           { ObjSections }
           WriteSectionContent(data);
           { Relocs }
           ObjSectionList.ForEachCall(@section_write_relocs,nil);
           { ObjSymbols }
           if Sympos<>FWriter.ObjSize then
             InternalError(200603051);
           FWriter.writearray(FCoffSyms);
           { Strings }
           i:=FCoffStrs.Size+4;
           if SourceInfo.endian<>TargetInfo.endian then
             i:=SwapEndian(i);
           FWriter.write(i,4);
           FWriter.writearray(FCoffStrs);
         end;
        FCoffStrs.Free;
        FCoffStrs:=nil;
        FCoffSyms.Free;
        FCoffSyms:=nil;
      end;


    constructor TDJCoffObjOutput.Create(AWriter:TObjectWriter);
      begin
        inherited createcoff(AWriter,false);
        cobjdata:=TDJCoffObjData;
      end;


    constructor TPECoffObjOutput.Create(AWriter:TObjectWriter);
      begin
        inherited createcoff(AWriter,true);
        cobjdata:=TPECoffObjData;
      end;


{****************************************************************************
                                TCoffObjInput
****************************************************************************}

    constructor TCoffObjInput.createcoff(awin32:boolean);
      begin
        inherited Create;
        win32:=awin32;
        bigobj:=false;
        FSymTbl:=nil;
      end;


    destructor TCoffObjInput.Destroy;
      begin
        FCoffSyms.free;
        FCoffSyms := nil;
        FCoffStrs:=nil;
        FSymTbl:=nil;
        FSecTbl:=nil;
        inherited Destroy;
      end;


    function TCoffObjInput.GetSection(secidx:LongInt):TObjSection;
      begin
        result:=nil;
        if (secidx<1) or (secidx>FSecCount) then
          begin
            InputError('Failed reading coff file, invalid section index');
            exit;
          end;
        result:=FSecTbl[secidx];
      end;


    function TCoffObjInput.Read_str(strpos:LongWord):string;
      begin
        if (FCoffStrs=nil) or (strpos>=FCoffStrSize) or (FCoffStrs[strpos]=#0) then
          InternalError(200205172);
        result:=string(PChar(@FCoffStrs[strpos]));
      end;


    procedure TCoffObjInput.read_relocs(s:TCoffObjSection);
      var
        rel       : TCOFFReloc;
        rel_type  : TObjRelocationType;
        i         : LongInt;
        p         : TObjSymbol;
      begin
        if s.coffrelocs=high(aword) then
          begin
            { If number of relocations exceeds 65535, it is stored in address field
              of the first record, and includes this first fake relocation. }
            FReader.read(rel,sizeof(rel));
	    MaybeSwap(rel);
            s.coffrelocs:=rel.address-1;
            if s.coffrelocs<=65535 then
              InternalError(2013012503);
          end;
        for i:=1 to s.coffrelocs do
         begin
           FReader.read(rel,sizeof(rel));
	   MaybeSwap(rel);
           case rel.reloctype of
{$ifdef i386}
             IMAGE_REL_I386_PCRLONG :
               rel_type:=RELOC_RELATIVE;
             IMAGE_REL_I386_DIR32 :
               rel_type:=RELOC_ABSOLUTE;
             IMAGE_REL_I386_IMAGEBASE :
               rel_type:=RELOC_RVA;
             IMAGE_REL_I386_SECREL32 :
               rel_type:=RELOC_SECREL32;
{$endif i386}
{$ifdef x86_64}
             IMAGE_REL_AMD64_ABSOLUTE:
               rel_type:=RELOC_NONE;
             IMAGE_REL_AMD64_REL32:
               rel_type:=RELOC_RELATIVE;
             IMAGE_REL_AMD64_ADDR32,
             R_X86_64_32S:
               rel_type:=RELOC_ABSOLUTE32;
             IMAGE_REL_AMD64_ADDR64:
               rel_type:=RELOC_ABSOLUTE;
             IMAGE_REL_AMD64_ADDR32NB:
               rel_type:=RELOC_RVA;
             IMAGE_REL_AMD64_REL32_1:
               rel_type:=RELOC_RELATIVE_1;
             IMAGE_REL_AMD64_REL32_2:
               rel_type:=RELOC_RELATIVE_2;
             IMAGE_REL_AMD64_REL32_3:
               rel_type:=RELOC_RELATIVE_3;
             IMAGE_REL_AMD64_REL32_4:
               rel_type:=RELOC_RELATIVE_4;
             IMAGE_REL_AMD64_REL32_5:
               rel_type:=RELOC_RELATIVE_5;
             IMAGE_REL_AMD64_SECREL:
               rel_type:=RELOC_SECREL32;
{$endif x86_64}
{$ifdef aarch64}
             IMAGE_REL_ARM64_ABSOLUTE:
               rel_type:=RELOC_NONE;
             IMAGE_REL_ARM64_ADDR32:
               rel_type:=RELOC_ABSOLUTE32;
             IMAGE_REL_ARM64_ADDR32NB:
               rel_type:=RELOC_RVA;
             IMAGE_REL_ARM64_BRANCH26:
               rel_type:=RELOC_RELATIVE_26;
             IMAGE_REL_ARM64_PAGEBASE_REL21:
               rel_type:=RELOC_ADR_PREL_PG_HI21;
             IMAGE_REL_ARM64_REL21:
               rel_type:=RELOC_ADR_PREL_LO21;
             IMAGE_REL_ARM64_PAGEOFFSET_12A:
               rel_type:=RELOC_ADD_ABS_LO12;
             IMAGE_REL_ARM64_PAGEOFFSET_12L:
               rel_type:=RELOC_LDST8_ABS_LO12;
             IMAGE_REL_ARM64_SECREL:
               rel_type:=RELOC_SECREL32;
             //IMAGE_REL_ARM64_SECREL_LOW12A
             //IMAGE_REL_ARM64_SECREL_HIGH12A
             //IMAGE_REL_ARM64_SECREL_LOW12L
             //IMAGE_REL_ARM64_TOKEN
             //IMAGE_REL_ARM64_SECTION
             IMAGE_REL_ARM64_ADDR64:
               rel_type:=RELOC_ABSOLUTE;
             //IMAGE_REL_ARM64_BRANCH19
{$endif aarch64}
           else
             begin
               InputError('Failed reading coff file, illegal reloctype $'+system.HexStr(rel.reloctype,4));
               exit;
             end;
           end;

           p:=FSymTbl[rel.sym];
           if Assigned(p) then
             s.addsymreloc(rel.address-s.mempos,p,rel_type)
           else
            begin
              InputError('Failed reading coff file, can''t resolve symbol of relocation');
              exit;
            end;
         end;
      end;


    procedure TCoffObjInput.read_symbols(objdata:TObjData);
      var
        size,
        address,
        nsyms,
        symidx    : aint;
        i         : LongInt;
        sym       : TCOFFSymbol;
        bosym     : TCOFFBigObjSymbol;
        objsym    : TObjSymbol;
        bind      : TAsmsymbind;
        strname   : ShortString;
        auxrec    : array[0..sizeof(TCOFFSymbol)-1] of byte;
        boauxrec  : array[0..sizeof(TCOFFBigObjSymbol)-1] of byte;
        psecrec   : PCOFFSectionRec;
        secrec    : TCOFFSectionRec;
        objsec    : TObjSection;
        secidx    : LongInt;
        symvalue  : LongWord;
        auxcount  : byte;
        symcls    : byte;
        comdatsel : TObjSectionComdatSelection;

        { keeps string manipulations out of main routine }
        procedure UnsupportedSymbolType;
          begin
            Comment(VFatal,'Unsupported COFF symbol type '+ToStr(symcls)+' at index '+ToStr(symidx)+' while reading '+InputFileName);
          end;

      begin
        with TCoffObjData(objdata) do
         begin
           if bigobj then
             nsyms:=FCoffSyms.Size div sizeof(TCOFFBigObjSymbol)
           else
             nsyms:=FCoffSyms.Size div sizeof(TCOFFSymbol);
           { Allocate memory for symidx -> TObjSymbol table }
           SetLength(FSymTbl,nsyms);
           { Load the Symbols }
           FCoffSyms.Seek(0);
           symidx:=0;
           while (symidx<nsyms) do
            begin
              if bigobj then
                begin
                  FCoffSyms.Read(bosym,sizeof(bosym));
		  MaybeSwap(bosym);
                  if bosym.Name.Offset.Zeroes<>0 then
                    begin
                      { Added for sake of global data analysis }
                      strname[0]:=#0;
                      move(bosym.Name.ShortName,strname[1],8);
                      strname[9]:=#0;
                      strname[0]:=chr(StrLen(@strname[1]));
                      if strname='' then
                        InternalError(2017020301);
                    end
                  else
                    strname:=Read_str(bosym.Name.Offset.Offset);
                  secidx:=LongInt(bosym.SectionNumber);
                  symvalue:=bosym.Value;
                  auxcount:=bosym.NumberOfAuxSymbols;
                  symcls:=bosym.StorageClass;
                end
              else
                begin
                  FCoffSyms.Read(sym,sizeof(sym));
		  MaybeSwap(sym);
                  if PLongInt(@sym.name)^<>0 then
                    begin
                      { Added for sake of global data analysis }
                      strname[0]:=#0;
                      move(sym.name,strname[1],8);
                      strname[9]:=#0;
                      strname[0]:=chr(StrLen(@strname[1]));
                      if strname='' then
                        InternalError(200205171);
                    end
                  else
                    strname:=Read_str(sym.strpos);
                  secidx:=sym.section;
                  symvalue:=sym.Value;
                  auxcount:=sym.aux;
                  symcls:=sym.typ;
                end;
              bind:=AB_EXTERNAL;
              size:=0;
              address:=0;
              objsym:=nil;
              objsec:=nil;
              case symcls of
                COFF_SYM_GLOBAL :
                  begin
                    if secidx=0 then
                     begin
                       if symvalue=0 then
                        bind:=AB_EXTERNAL
                       else
                        begin
                          bind:=AB_COMMON;
                          size:=symvalue;
                        end;
                     end
                    else
                     begin
                       bind:=AB_GLOBAL;
                       objsec:=GetSection(secidx);
                       if symvalue>=objsec.mempos then
                         address:=symvalue-objsec.mempos;
                     end;
                    objsym:=CreateSymbol(strname);
                    objsym.bind:=bind;
                    objsym.typ:=AT_FUNCTION;
                    objsym.objsection:=objsec;
                    objsym.Offset:=address;
                    objsym.Size:=size;
                  end;
                COFF_SYM_LABEL,
                COFF_SYM_LOCAL :
                  begin
                    { do not add constants (section=-1) }
                    if secidx<>-1 then
                     begin
                       objsec:=GetSection(secidx);
                       if symvalue>=objsec.mempos then
                         address:=symvalue-objsec.mempos;
                       objsym:=CreateSymbol(strname);
                       objsym.bind:=AB_LOCAL;
                       objsym.typ:=AT_FUNCTION;
                       objsym.objsection:=objsec;
                       objsym.Offset:=address;
                       objsym.Size:=size;
                     end;
                  end;
                COFF_SYM_SECTION :
                  begin
                    { GetSection checks that index is in range }
                    objsec:=GetSection(secidx);
                    if Assigned(objsec) then
                      begin
                        if symvalue>=objsec.mempos then
                          address:=symvalue-objsec.mempos;
                        objsym:=CreateSymbol(strname);
                        objsym.bind:=AB_LOCAL;
                        objsym.typ:=AT_FUNCTION;
                        objsym.objsection:=objsec;
                        objsym.Offset:=address;
                        objsym.Size:=size;
                      end;
                  end;
                COFF_SYM_FUNCTION,
                COFF_SYM_FILE :
                  ;
                else
                  UnsupportedSymbolType;
              end;
              FSymTbl[symidx]:=objsym;
              { read aux records }

              { handle COMDAT symbols }
              if (symcls=COFF_SYM_LOCAL) and (auxcount=1) and (symvalue=0) and (oso_comdat in objsym.objsection.SecOptions) then
                begin
                  if bigobj then
                    begin
                      FCoffSyms.Read(boauxrec,sizeof(boauxrec));
                      psecrec:=PCOFFSectionRec(@boauxrec[0]);
                    end
                  else
                    begin
                      FCoffSyms.Read(auxrec,sizeof(auxrec));
                      psecrec:=PCOFFSectionRec(@auxrec);
                    end;
                  secrec:=psecrec^;
                  MaybeSwap(secrec);

                  case secrec.select of
                    IMAGE_COMDAT_SELECT_NODUPLICATES:
                      comdatsel:=oscs_none;
                    IMAGE_COMDAT_SELECT_ANY:
                      comdatsel:=oscs_any;
                    IMAGE_COMDAT_SELECT_SAME_SIZE:
                      comdatsel:=oscs_same_size;
                    IMAGE_COMDAT_SELECT_EXACT_MATCH:
                      comdatsel:=oscs_exact_match;
                    IMAGE_COMDAT_SELECT_ASSOCIATIVE:
                      comdatsel:=oscs_associative;
                    IMAGE_COMDAT_SELECT_LARGEST:
                      comdatsel:=oscs_largest;
                    else begin
                      comdatsel:=oscs_none;
                      { there are object files out here that have comdat symbols
                        including an associative section, but with a comdat selection
                        of 0; it seems that other linkers just ignore those... }
                      if secrec.select<>0 then
                        Message2(link_e_comdat_select_unsupported,IntToStr(secrec.select),objsym.objsection.name);
                    end;
                  end;

                  if comdatsel in [oscs_associative] then
                    { only temporary }
                    Comment(VError,'Associative COMDAT sections are not yet supported (symbol: '+objsym.objsection.Name+')')
                  else if (comdatsel=oscs_associative) and (secrec.assoc=0) then
                    Message1(link_e_comdat_associative_section_expected,objsym.objsection.name)
                  else if (objsym.objsection.ComdatSelection<>oscs_none) and (comdatsel<>oscs_none) and (objsym.objsection.ComdatSelection<>comdatsel) then
                    Message2(link_e_comdat_not_matching,objsym.objsection.Name,objsym.Name)
                  else
                    begin
                      objsym.objsection.ComdatSelection:=comdatsel;

                      if (secrec.assoc<>0) and not Assigned(objsym.objsection.AssociativeSection) then
                        begin
                          objsym.objsection.AssociativeSection:=GetSection(secrec.assoc-1);
                          if not Assigned(objsym.objsection.AssociativeSection) then
                            Message1(link_e_comdat_associative_section_not_found,objsym.objsection.Name);
                        end;
                    end;

                  dec(auxcount);
                  inc(symidx);
                end;

              for i:=1 to auxcount do
               begin
                 if bigobj then
                   FCoffSyms.Read(boauxrec,sizeof(boauxrec))
                 else
                   FCoffSyms.Read(auxrec,sizeof(auxrec));
                 inc(symidx);
               end;
              inc(symidx);
            end;
         end;
      end;


    procedure TCoffObjInput.ObjSections_read_relocs(p:TObject;arg:pointer);
      begin
        with TCoffObjSection(p) do
          begin
            { Skip debug sections }
            if (oso_debug in secoptions)  and
               (cs_link_strip in CurrentSettings.GlobalSwitches) and
               not(cs_link_separate_dbg_file in CurrentSettings.GlobalSwitches) then
              exit;

            if coffrelocs>0 then
              begin
                FReader.Seek(coffrelocpos);
                read_relocs(TCoffObjSection(p));
              end;
          end;
      end;


    function  TCoffObjInput.ReadObjData(AReader:TObjectReader;out objdata:TObjData):boolean;
      var
        secalign : LongInt;
        secofs,
        strpos,
        i        : LongInt;
        sympos,
        symcount,
        symsize,
        code     : LongInt;
        objsec   : TCoffObjSection;
        secoptions : TObjSectionOptions;
        header   : TCOFFHeader;
        boheader : TCOFFBigObjHeader;
        sechdr   : TCOFFSecHdr;
        secname  : string;
        secnamebuf : array[0..15] of char;
      begin
        FReader:=AReader;
        InputFileName:=AReader.FileName;
        objdata:=CObjData.Create(InputFileName);
        result:=false;
        boheader:=default(TCOFFBigObjHeader);
        FCoffSyms:=TDynamicArray.Create(SymbolMaxGrow);
        with TCoffObjData(objdata) do
         begin
           { Read COFF header }
           if not AReader.read(header,sizeof(TCOFFHeader)) then
             begin
               InputError('Can''t read COFF Header');
               exit;
             end;
           MaybeSwap(header);
           if (header.mach=0) and (header.nsects=$ffff) then
             begin
               { either a library or big obj COFF }
               AReader.seek(0);
               if not AReader.read(boheader,sizeof(boheader)) then
                 begin
                   InputError('Can''t read Big Obj COFF Header');
                   exit;
                 end;
               MaybeSwap(boheader);
               if CompareByte(boheader.UUID,COFF_BIG_OBJ_MAGIC,length(boheader.uuid))<>0 then
                 begin
                   { ToDo: this should be treated as a library }
                   InputError('Illegal Big Obj COFF Magic');
                   exit;
                 end;
               if boheader.Version<>COFF_BIG_OBJ_VERSION then
                 begin
                   InputError('Illegal Big Obj COFF Version');
                   exit;
                 end;
               if boheader.Machine<>COFF_MAGIC then
                 begin
                   InputError('Illegal COFF Machine type');
                   exit;
                 end;
               bigobj:=true;
             end
           else if header.mach<>COFF_MAGIC then
             begin
               InputError('Illegal COFF Magic');
               exit;
             end;
           { ObjSymbols }
           if bigobj then
             begin
               sympos:=LongInt(boheader.PointerToSymbolTable);
               symcount:=LongInt(boheader.NumberOfSymbols);
               symsize:=sizeof(TCOFFBigObjSymbol);
             end
           else
             begin
               sympos:=LongInt(header.sympos);
               symcount:=LongInt(header.syms);
               symsize:=sizeof(TCOFFSymbol);
             end;
           AReader.Seek(sympos);
           if not AReader.ReadArray(FCoffSyms,symcount*symsize) then
             begin
               InputError('Error reading coff symbol table');
               exit;
           end;
           { Strings }
           if not AReader.Read(FCoffStrSize,4) then
             begin
               InputError('Error reading COFF string table');
               exit;
             end;
           if (FCoffStrSize>4) then
             begin
               { allocate an extra byte and null-terminate }
               SetLength(FCoffStrs,FCoffStrSize+1);
               FCoffStrs[FCoffStrSize]:=#0;
               for i:=0 to 3 do
                 FCoffStrs[i]:=#0;
               if not AReader.Read(FCoffStrs[4],FCoffStrSize-4) then
                 begin
                   InputError('Error reading COFF string table');
                   exit;
                 end;
             end;
           { Section headers }
           { Allocate SecIdx -> TObjSection table, secidx is 1-based }
           if bigobj then
             FSecCount:=LongInt(boheader.NumberOfSections)
           else
             FSecCount:=header.nsects;
           SetLength(FSecTbl,(FSecCount+1));
           if bigobj then
             secofs:=sizeof(TCOFFBigObjHeader)
           else
             secofs:=sizeof(TCOFFHeader)+header.opthdr;
           AReader.Seek(secofs);
           for i:=1 to FSecCount do
             begin
               if not AReader.read(sechdr,sizeof(sechdr)) then
                begin
                  InputError('Error reading COFF Section Headers');
                  exit;
                end;
               MaybeSwap(sechdr);
               move(sechdr.name,secnamebuf,8);
               secnamebuf[8]:=#0;
               secname:=StrPas(secnamebuf);
               if secname[1]='/' then
                 begin
                   if secname[2]='/' then
                     begin
                       if not decodeBase64(copy(secname,3,8),strpos) then
                         begin
                           InputError('Error reading COFF Section Headers');
                           secname:='error';
                         end
                       else
                         secname:=Read_str(strpos);
                     end
                   else
                     begin
                       Val(Copy(secname,2,8),strpos,code);
                       if code=0 then
                         secname:=Read_str(strpos)
                       else
                         begin
                           InputError('Error reading COFF Section Headers');
                           secname:='error';
                         end;
                     end;
                 end;
               if win32 then
                 pedecodesechdrflags(secname,sechdr.flags,secoptions,secalign)
               else
                 begin
                   secoptions:=djdecodesechdrflags(secname,sechdr.flags);
                   secalign:=sizeof(PInt);
                 end;
               if (Length(secname)>3) and (secname[2] in ['e','f','i','p','r']) then
                 begin
                   if (Pos('.edata',secname)=1) or
                      (Pos('.rsrc',secname)=1) or
                      (Pos('.fpc',secname)=1) then
                     include(secoptions,oso_keep);
                   if (Pos('.idata',secname)=1) then
                     begin
  { TODO: idata keep can maybe replaced with grouping of text and idata}
                       include(secoptions,oso_keep);
                       secname:=secname + '.' + ExtractFileName(InputFileName);
                     end;
                 end;
               objsec:=TCoffObjSection(createsection(secname,secalign,secoptions,false));
               FSecTbl[i]:=objsec;
               if not win32 then
                 objsec.mempos:=sechdr.rvaofs;
               objsec.orgmempos:=sechdr.rvaofs;
               objsec.coffrelocs:=sechdr.nrelocs;
               if win32 then
                 begin
                   if (sechdr.flags and PE_SCN_LNK_NRELOC_OVFL)<>0 then
                     objsec.coffrelocs:=high(aword);
                 end;
               objsec.coffrelocpos:=sechdr.relocpos;
               objsec.datapos:=sechdr.datapos;
               objsec.Size:=sechdr.DataSize;
             end;
           { Insert all ObjSymbols }
           read_symbols(objdata);
           { Section Data }
           ReadSectionContent(objdata);
           { Relocs }
           ObjSectionList.ForEachCall(@objsections_read_relocs,nil);
         end;
        FCoffStrs:=nil;
        FCoffSyms.Free;
        FCoffSyms:=nil;
        result:=true;
      end;


    constructor TDJCoffObjInput.Create;
      begin
        inherited createcoff(false);
        cobjdata:=TDJCoffObjData;
      end;


    constructor TPECoffObjInput.Create;
      begin
        inherited createcoff(true);
        cobjdata:=TPECoffObjData;
      end;


{****************************************************************************
                              COFF assemblers
****************************************************************************}

    constructor TDJCoffAssembler.Create(info: PAsmInfo; smart:boolean);
      begin
        inherited;
        CObjOutput:=TDJCoffObjOutput;
        CInternalAr:=TArObjectWriter;
      end;


{****************************************************************************
                               TPECoffAssembler
****************************************************************************}

    constructor TPECoffassembler.Create(info: PAsmInfo; smart:boolean);
      begin
        inherited;
        CObjOutput:=TPECoffObjOutput;
        CInternalAr:=TArObjectWriter;
      end;


{*****************************************************************************
                                   DLLReader
*****************************************************************************}

{$ifdef win32}
    var
      Wow64DisableWow64FsRedirection : function (var OldValue : pointer) : boolean;stdcall;
      Wow64RevertWow64FsRedirection : function (OldValue : pointer) : boolean;stdcall;
{$endif win32}

    function ReadDLLImports(const dllname:string;readdllproc:Treaddllproc):boolean;
      var
        DLLReader : TObjectReader;
        DosHeader : array[0..$7f] of byte;
        PEMagic   : array[0..3] of byte;
        Header    : TCOFFHeader;
        peheader  : TCOFFPEOptHeader;
        NameOfs,
        newheaderofs : LongWord;
        FuncName  : ShortString;
        expdir    : TPECoffExpDir;
        i         : LongInt;
        found     : boolean;
	header_ok : boolean;
        sechdr    : TCOFFSecHdr;
{$ifdef win32}
        p : pointer;
{$endif win32}
      begin
        result:=false;
        fillchar(sechdr,sizeof(sechdr),0);
{$ifdef win32}
        if (TargetInfo.system=system_x86_64_win64) and
          Assigned(Wow64DisableWow64FsRedirection) then
          Wow64DisableWow64FsRedirection(p);
{$endif win32}
        DLLReader:=TObjectReader.Create;
        DLLReader.OpenFile(dllname);
{$ifdef win32}
        if (TargetInfo.system=system_x86_64_win64) and
          Assigned(Wow64RevertWow64FsRedirection) then
          Wow64RevertWow64FsRedirection(p);
{$endif win32}
        if not DLLReader.Read(DosHeader,sizeof(DosHeader)) or
           (DosHeader[0]<>$4d) or (DosHeader[1]<>$5a) then
          begin
            Comment(VError,'Invalid DLL '+dllname+', Dos Header invalid');
            exit;
          end;
        newheaderofs:=cardinal(DosHeader[$3c]) or (DosHeader[$3d] shl 8) or (DosHeader[$3e] shl 16) or (DosHeader[$3f] shl 24);
        DLLReader.Seek(newheaderofs);
        if not DLLReader.Read(PEMagic,sizeof(PEMagic)) or
           (PEMagic[0]<>$50) or (PEMagic[1]<>$45) or (PEMagic[2]<>$00) or (PEMagic[3]<>$00) then
          begin
            Comment(VError,'Invalid DLL '+dllname+': invalid magic code');
            exit;
          end;
	header_ok:=DLLReader.Read(Header,sizeof(TCOFFHeader));
	MaybeSwap(Header);
        if not header_ok or
           (Header.mach<>COFF_MAGIC) or
           (Header.opthdr<>sizeof(TCOFFPEOptHeader)) then
          begin
            Comment(VError,'Invalid DLL '+dllname+', invalid header size');
            exit;
          end;
        { Read optheader }
        DLLreader.Read(peheader,sizeof(TCOFFPEOptHeader));
	MaybeSwap(peheader);
        { Section headers }
        found:=false;
        for i:=1 to header.nsects do
          begin
            if not DLLreader.read(sechdr,sizeof(sechdr)) then
              begin
                Comment(VError,'Error reading coff file '+DLLName);
                exit;
              end;
            MaybeSwap(sechdr);
            if (sechdr.rvaofs<=peheader.DataDirectory[PE_DATADIR_EDATA].vaddr) and
               (peheader.DataDirectory[PE_DATADIR_EDATA].vaddr<sechdr.rvaofs+sechdr.vsize) then
              begin
                found:=true;
                break;
              end;
          end;
        if not found then
          begin
            Comment(VWarning,'DLL '+DLLName+' does not contain any exports');
            exit;
          end;
        { Process edata }
        DLLReader.Seek(sechdr.datapos+peheader.DataDirectory[PE_DATADIR_EDATA].vaddr-sechdr.rvaofs);
        DLLReader.Read(expdir,sizeof(expdir));
	MaybeSwap(expdir);
        for i:=0 to expdir.NumNames-1 do
          begin
            DLLReader.Seek(sechdr.datapos+expdir.AddrNames-sechdr.rvaofs+i*4);
            DLLReader.Read(NameOfs,4);
            Dec(NameOfs,sechdr.rvaofs);
            if {(NameOfs<0) or}
               (NameOfs>sechdr.vsize) then
              begin
                Comment(VError,'DLL does contains invalid exports');
                break;
              end;
            { Read Function name from DLL, prepend _ and terminate with #0 }
            DLLReader.Seek(sechdr.datapos+NameOfs);
            DLLReader.Read((@FuncName[1])^,sizeof(FuncName)-3);
            FuncName[sizeof(FuncName)-1]:=#0;
            FuncName[0]:=chr(StrLen(@FuncName[1]));
            readdllproc(DLLName,FuncName);
          end;
        DLLReader.Free;
        DLLReader := nil;
      end;


{*****************************************************************************
                                  Initialize
*****************************************************************************}

{$ifdef i386}
    const
       as_i386_pecoff_info : TAsmInfo =
          (
            id     : as_i386_pecoff;
            idtxt  : 'PECOFF';
            asmbin : '';
            asmcmd : '';
            supported_targets : [system_i386_win32,system_i386_nativent];
            flags : [af_outputbinary,af_smartlink_sections];
            labelprefix : '.L';
            labelmaxlen : -1;
            comment : '';
            dollarsign: '$';
          );

{$endif i386}
{$ifdef x86_64}
    const
       as_x86_64_pecoff_info : TAsmInfo =
          (
            id     : as_x86_64_pecoff;
            idtxt  : 'PECOFF';
            asmbin : '';
            asmcmd : '';
            supported_targets : [system_x86_64_win64];
            flags : [af_outputbinary,af_smartlink_sections];
            labelprefix : '.L';
            labelmaxlen : -1;
            comment : '';
            dollarsign: '$';
          );
{$endif x86_64}


{$ifdef win32}
  procedure SetupProcVars;
    var
      hinstLib : THandle;
    begin
      Wow64DisableWow64FsRedirection:=nil;
      Wow64RevertWow64FsRedirection:=nil;
      hinstLib:=LoadLibrary('kernel32.dll');
      if hinstLib<>0 then
        begin
          pointer(Wow64DisableWow64FsRedirection):=GetProcAddress(hinstLib,'Wow64DisableWow64FsRedirection');
          pointer(Wow64RevertWow64FsRedirection):=GetProcAddress(hinstLib,'Wow64RevertWow64FsRedirection');
          FreeLibrary(hinstLib);
        end;
    end;
{$endif win32}


initialization
{$ifdef i386}
  RegisterAssembler(as_i386_pecoff_info,TPECoffassembler);
{$endif i386}
{$ifdef x86_64}
  RegisterAssembler(as_x86_64_pecoff_info,TPECoffassembler);
{$endif x86_64}
{$ifdef win32}
  SetupProcVars;
{$endif win32}
end.
