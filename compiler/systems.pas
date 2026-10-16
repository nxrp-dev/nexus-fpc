{
    Copyright (c) 1998-2008 by Florian Klaempfl

    This unit contains information about the target systems supported
    (these are not processor specific)

    This program is free software; you can redistribute it and/or modify
    iu under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge- MA 02139, USA.

 ****************************************************************************
}
unit systems;

{$i fpcdefs.inc}

interface

{$i systems.inc}

{*****************************************************************************
                               Structures
*****************************************************************************}

     type
       TAbstractResourceFile = class
         constructor create(const fn : AnsiString);virtual;abstract;
       end;
       TAbstractResourceFileClass = class of TAbstractResourceFile;


       PAlignmentInfo = ^TAlignmentInfo;
       { this is written to ppus during token recording for generics so it must be packed }
       TAlignmentInfo = packed record
         ProcAlign,
         LoopAlign,
         { alignment for labels after unconditional jumps, this must be a power of two }
         JumpAlign,
         { max. alignment for labels after unconditional jumps:
           the compiler tries to align jumpalign, however, to do so it inserts at maximum jumpalignskipmax bytes or uses
           the next smaller power of two of jumpalign }
         JumpAlignSkipMax,
         { alignment for labels where two flows of the program flow coalesce, this must be a power of two }
         CoalesceAlign,
         { max. alignment for labels where two flows of the program flow coalesce
           the compiler tries to align to coalescealign, however, to do so it inserts at maximum coalescealignskipmax bytes or uses
           the next smaller power of two of coalescealign }
         CoalesceAlignSkipMax,
         ConstAlignMin,
         ConstAlignMax,
         VarAlignMin,
         VarAlignMax,
         LocalAlignMin,
         LocalAlignMax,
         RecordAlignMin,
         RecordAlignMax,
         MaxCRecordAlign : LongInt;
       end;

       TAsmFlags = (af_none
         ,af_outputbinary
         ,af_needar
         ,af_smartlink_sections
         ,af_labelprefix_only_inside_procedure
         ,af_supports_dwarf
         ,af_no_debug
         { assembler is part of the LLVM toolchain }
         ,af_llvm
         ,af_supports_hlcfi
       );

       PAsmInfo = ^TAsmInfo;
       TAsmInfo = record
          id          : TAsm;
          idtxt       : string[17];
          asmbin      : string[16];
          asmcmd      : string[154];
          supported_targets : set of TSystem;
          flags        : set of TAsmFlags;
          labelprefix : string[3];
          labelmaxlen : integer;
          comment     : string[3];
          { set to '$' if that character is allowed in symbol names, otherwise
            to alternate character by which '$' should be replaced }
          dollarsign  : char;
       end;

       PArInfo = ^TArInfo;
       TArInfo = record
          id          : TAr;
          addfilecmd  : string[10];
          arfirstcmd  : string[60];
          arcmd       : string[60];
          arfinishcmd : string[11];
       end;

       PResInfo = ^TResInfo;
       TResInfo = record
          id      : TRes;
          { Compiler for resource (.rc or .res) to obj }
          resbin  : string[10];
          rescmd  : string[50];
          { Optional compiler for resource script (.rc) to binary resource (.res). }
          { If it is not provided resbin and rescmd will be used.                 }
          rcbin   : string[10];
          rccmd   : string[50];
          resourcefileclass : TAbstractResourceFileClass;
          ResFlags : set of TResInfoFlags;
       end;

       PDbgInfo = ^TDbgInfo;
       TDbgInfo = record
          id      : TDbg;
          idtxt   : string[12];
       end;

       TSystemFlags = (tf_none,
            tf_under_development,
            tf_need_export,
            tf_needs_isconsole,
            tf_code_small,
            tf_static_reg_based,
            tf_needs_symbol_size,
            tf_smartlink_sections,
            tf_smartlink_library,
            tf_needs_dwarf_cfi,
            tf_use_8_3,
            tf_pic_uses_got,
            tf_library_needs_pic,
            tf_needs_symbol_type,
            tf_section_threadvars,
            tf_files_case_sensitive,
            tf_files_case_aware,
            tf_p_ext_support,
            tf_has_dllscanner,
            tf_use_function_relative_addresses,
            tf_winlikewidestring,
            tf_dwarf_relative_addresses,         // use offsets where the Dwarf spec requires this instead of absolute addresses (the latter is needed by Linux binutils)
            tf_dwarf_only_local_labels,          // only use local labels inside the Dwarf debug_info section (needed for e.g. Darwin)
            tf_requires_proper_alignment,
            tf_no_pic_supported,
            tf_pic_default,
            { the os does some kind of stack checking and it can be converted into a rte 202 }
            tf_no_generic_stackcheck,
            tf_emit_stklen,                     // Means that the compiler should emit a _stklen variable with the stack size, even if tf_no_generic_stackcheck is specified
            tf_has_winlike_resources,
            tf_safecall_clearstack,             // With this flag set, after safecall calls the caller cleans up the stack
            tf_safecall_exceptions,             // Exceptions in safecall calls are not raised, but passed to the caller as an ordinal (hresult) in the function result.
                                                // The original result (if it exists) is passed as an extra parameter
            tf_no_backquote_support,
            { do not generate an object file when smartlinking is turned on,
              this is useful for architectures which require a small code footprint }
            tf_no_objectfiles_when_smartlinking,
            { indicates that the default value of the ts_cld target switch is 'on' for this target }
            tf_cld,
            { indicates that this target can use dynamic packages otherwise an
              error will be generated if a package file is compiled }
            tf_supports_packages,
            { use PSABI/Dwarf-based "zero cost" exception handling }
            tf_use_psabieh,
            { use high level cfi directives to generate call frame information }
            tf_use_hlcfi,
            { supports symbol order file (to ensure symbols in vectored sections are kept in the correct order) }
            tf_supports_symbolorderfile,
            { supports hidden/private extern symbols: visible across object files, but local/private in exe/library }
            tf_supports_hidden_symbols,
            { units are initialized by direct calls and not table driven,
              in particular for a small amount of units, this results in smaller
              executables }
            tf_init_final_units_by_calls
       );
       PSystemInfo = ^TSystemInfo;
       { using packed causes bus errors on processors which require alignment }
       TSystemInfo = record
          system       : TSystem;
          name         : string[88];
          shortname    : string[14];
          flags        : set of TSystemFlags;
          cpu          : TSystemCPU;
          unit_env     : string[16];
          extradefines : string[40];
          ExeExt,
          defext,
          scriptext,
          smartext,
          unitext,
          unitlibext,
          asmext       : string[5];
          objext       : string[6];
          resext       : string[4];
          resobjext    : string[7];
          sharedlibext : string[10];
          staticlibext,
          staticlibprefix : string[6];
          sharedlibprefix : string[4];
          sharedClibext : string[10];
          staticClibext,
          staticClibprefix : string[6];
          sharedClibprefix : string[4];
          importlibprefix : string[10];
          importlibext : string[6];
          Cprefix      : string[2];
          newline      : string[2];
          dirsep       : char;
          assem        : TAsm;
          assemextern  : TAsm; { external assembler, used by -a and -s }
          linkextern   : TLink;  { external linker }
          ar           : TAr;
          res          : TRes;
          dbg          : TDbg;
          script       : TScriptType;
          endian       : TEndian;
          alignment    : TAlignmentInfo;
          {
            Offset from the argument pointer register to the first
            argument's address. On some machines it may depend on
            the data type of the function.
            (see also FIRST_PARM_OFFSET in GCC source)
          }
          first_parm_offset : LongInt;
          StackSize    : LongInt;
          { stack alignment }
          stackalign   : byte;
          abi          : TABI;
       end;

    TABIInfo = record
      name: string[13];
      supported: boolean;
    end;

{$push}
{$j-}
    const
       { alias for supported_target field in tasminfo }
       system_any = system_none;

       systems_android = [system_aarch64_android, system_x86_64_android];
       systems_linux = [system_i386_linux,system_x86_64_linux,
                       system_aarch64_linux];

       { all supported Windows systems }
       systems_windows = [system_i386_win32,system_x86_64_win64,system_aarch64_win64];

       { all windows systems }
       systems_all_windows = systems_windows;

       { all darwin systems }
       systems_ios = [system_aarch64_ios];
       systems_iphonesim = [system_x86_64_iphonesim,system_aarch64_iphonesim];
       systems_macosx = [system_x86_64_darwin,
                         system_aarch64_darwin];
       systems_darwin = systems_ios + systems_iphonesim + systems_macosx;

       { systems supporting Objective-C }
       systems_objc_supported = systems_darwin;

       { systems using the non-fragile Objective-C ABI }
       systems_objc_nfabi = [system_x86_64_darwin,system_aarch64_ios,system_aarch64_darwin,system_x86_64_iphonesim,system_aarch64_iphonesim];

       { systems supporting "blocks" }
       systems_blocks_supported = systems_darwin;

       { all systems supporting exports from programs or units }
       systems_unit_program_exports = [system_i386_win32,system_x86_64_win64,
                                         system_aarch64_win64]+systems_linux+systems_android;

       { all systems that reference symbols in other binaries using indirect imports }
       systems_indirect_var_imports = systems_all_windows;

       { all systems that support indirect entry information }
       systems_indirect_entry_information = systems_darwin+
                                            [system_i386_win32,system_x86_64_win64,system_x86_64_linux,
                                            system_aarch64_win64];

       { all systems for which weak linking has been tested/is supported }
       systems_weak_linking = systems_darwin + systems_linux + systems_android;

       systems_internal_sysinit = [system_i386_win32,system_x86_64_win64,
                                   system_i386_linux,system_x86_64_linux,
                                   system_aarch64_win64
                                  ]+systems_darwin;

       { all systems that use the PE+ header in the PE/COFF file
         Note: this is here and not in ogcoff, because it's required in other
               units as well }
       systems_peoptplus = [system_x86_64_win64,system_aarch64_win64];

       { all systems where a value parameter passed by reference must be copied
         on the caller side rather than on the callee side }
       systems_caller_copy_addr_value_para = [system_aarch64_ios,system_aarch64_iphonesim,system_aarch64_darwin,system_aarch64_linux,system_aarch64_win64];

       { all PPC ABIs that use a TOC register to address globals }
       abis_ppc_toc = [
         abi_powerpc_aix,abi_powerpc_elfv2
       ];

       { pointer checking (requires special code in FPC_CHECKPOINTER,
         and can never work for libc-based targets or any other program
         linking to an external library)
       }
       systems_support_checkpointer = systems_linux;

       { x86_64 systems that use the Win64 ABI instead of the SysV one }
       systems_win64_abi = [system_x86_64_win64];

       { all internal COFF writers }
       asms_int_coff = [as_i386_pecoff,as_x86_64_pecoff];

       { all internal ELF writers }
       asms_int_elf = [as_i386_elf32,as_x86_64_elf64];

       { all internal writers }
       asms_internals = asms_int_coff + asms_int_elf;

       cpu2str : array[0..MaxStoredCPUId] of string[12] =
            ('','i386','m68k','alpha','powerpc','sparc','vm','ia64','x86_64',
             'mips','arm', 'powerpc64', 'avr', 'mipsel','jvm', 'i8086',
             'aarch64', 'wasm32', 'sparc64', 'riscv32', 'riscv64', 'xtensa',
             'obsolete-z80', 'mips64', 'mips64el', 'loongarch64');

       ABIInfo : array[TABI] of TABIInfo = (
         (name: 'DEFAULT'; supported: true),
         (name: 'SYSV'   ; supported:false),
         (name: 'AIX'    ; supported:false),
         (name: 'DARWIN'    ; supported:false),
         (name: 'ELFV2'  ; supported:false),
         (name: 'EABI'   ; supported:false),
         (name: 'ARMEB'  ; supported:false),
         (name: 'EABIHF' ; supported:false),
         (name: 'OLDWIN32GNU'; supported:{$ifdef I386}true{$else}false{$endif}),
         (name: 'AARCH64IOS'; supported:{$ifdef aarch64}true{$else}false{$endif}),
         (name: 'ILP32'; supported:false),
         (name: 'ILP32F'; supported:false),
         (name: 'ILP32D'; supported:false),
         (name: 'ILP32E'; supported:false),
         (name: 'LP64'; supported:false),
         (name: 'LP64F'; supported:false),
         (name: 'LP64D'; supported:false),
         (name: 'LP64Q'; supported:false),
         (name: 'LINUX386_SYSV'; supported:{$if defined(i386)}true{$else}false{$endif}),
         (name: 'WINDOWED'; supported:false),
         (name: 'CALL0'; supported:false),
         (name: 'O32'; supported:false),
         (name: 'N32'; supported:false),
         (name: 'O64'; supported:false),
         (name: 'N64'; supported:false),
         (name: 'LP64S'; supported:false),
         (name: 'LP64F'; supported:false),
         (name: 'LP64D'; supported:false),
         (name: 'LP32S'; supported:false),
         (name: 'LP32F'; supported:false),
         (name: 'LP32D'; supported:false)
       );

       cgbackend2str: array[TCGBackend] of AnsiString = (
         'FPC'
       );

       { x86 asm modes with an Intel-style syntax }
       asmmodes_x86_intel = [

         asmmode_i8086_intel,
         asmmode_i386_intel,
         asmmode_x86_64_intel
       ];

       { x86 asm modes with an AT&T-style syntax }
       asmmodes_x86_att = [
{$if defined(i386) or defined(x86_64)}
         asmmode_standard,
{$endif}
         asmmode_i8086_att,
         asmmode_i386_att,
         asmmode_x86_64_att,
         asmmode_x86_64_gas
       ];
{$pop}

    var
       targetinfos   : array[0..MaxStoredSystemId] of PSystemInfo;
       arinfos       : array[TAr] of PArInfo;
       resinfos      : array[TRes] of PResInfo;
       asminfos      : array[TAsm] of PAsmInfo;
       dbginfos      : array[TDbg] of PDbgInfo;

       SourceInfo : TSystemInfo;
       TargetCPU  : TSystemCPU;
       TargetInfo : TSystemInfo;
       TargetAsm  : TAsmInfo;
       TargetAr   : TArInfo;
       TargetRes  : TResInfo;
       TargetDbg  : TDbgInfo;
       TargetCPUString,
       TargetOSString   : string[14]; { for rtl/<X>/,fcl/<X>/, etc. }
       TargetFullString : string[28];

    function SetTarget(t:TSystem):boolean;
    function SetTargetAsm(t:TAsm):boolean;
    function SetTargetAr(t:TAr):boolean;
    function SetTargetRes(t:TRes):boolean;
    function SetTargetDbg(t:TDbg):boolean;

    function FindSystemByString(const s : string) : TSystem;
    function FindAsmByString(const s : string) : TAsm;
    function FindDbgByString(const s : string) : TDbg;

    procedure SetSourceInfo(const ti : TSystemInfo);

    function UpdateAlignment(var d:TAlignmentInfo;const s:TAlignmentInfo) : boolean;

    procedure RegisterTarget(const r:TSystemInfo);
    procedure RegisterRes(const r:TResInfo; rcf : TAbstractResourceFileClass);
    procedure RegisterAr(const r:TArInfo);

    procedure InitSystems;

implementation

    uses
      CUtils;


{****************************************************************************
                              Target setting
****************************************************************************}

function SetTarget(t:TSystem):boolean;
begin
  SetTarget:=false;
  if Assigned(targetinfos[Ord(t)]) then
   begin
     TargetInfo:=targetinfos[Ord(t)]^;
     SetTargetAsm(TargetInfo.assem);
     SetTargetAr(TargetInfo.ar);
     SetTargetRes(TargetInfo.res);
     SetTargetDbg(TargetInfo.dbg);
     TargetCPU:=TargetInfo.cpu;
     TargetOSString:=lower(TargetInfo.shortname);
     TargetCPUString:=cpu2str[Ord(TargetCPU)];
     TargetFullString:=TargetCPUString+'-'+TargetOSString;
     SetTarget:=true;
     exit;
   end;
end;


function SetTargetAsm(t:TAsm):boolean;
begin
  SetTargetAsm:=false;
  if Assigned(asminfos[t]) and
    ((TargetInfo.system in asminfos[t]^.supported_targets) or
     (system_any in asminfos[t]^.supported_targets)) then
   begin
     TargetAsm:=asminfos[t]^;
     SetTargetAsm:=true;
     exit;
   end;
end;


function SetTargetAr(t:TAr):boolean;
begin
  result:=false;
  if Assigned(arinfos[t]) then
   begin
     TargetAr:=arinfos[t]^;
     result:=true;
     exit;
   end;
end;


function SetTargetRes(t:TRes):boolean;
begin
  result:=false;
  if Assigned(resinfos[t]) then
   begin
     TargetRes:=resinfos[t]^;
     result:=true;
     exit;
   end
  else
   FillByte(TargetRes,sizeof(TargetRes),0);
end;


function SetTargetDbg(t:TDbg):boolean;
begin
  result:=false;
{ no debugging support for llvm yet }
  if Assigned(dbginfos[t]) then
   begin
     TargetDbg:=dbginfos[t]^;
     result:=true;
     exit;
   end;
end;


function FindSystemByString(const s : string) : TSystem;
var
  hs : string;
  t  : TSystem;
begin
  result:=system_none;
  hs:=upper(s);
  for t:=low(TSystem) to high(TSystem) do
   if Assigned(targetinfos[Ord(t)]) and
      (upper(targetinfos[Ord(t)]^.shortname)=hs) then
    begin
      result:=t;
      exit;
    end;
end;


function FindAsmByString(const s : string) : TAsm;
var
  hs : string;
  t  : TAsm;
begin
  result:=as_none;
  hs:=upper(s);
  for t:=low(TAsm) to high(TAsm) do
   if Assigned(asminfos[t]) and
      (asminfos[t]^.idtxt=hs) then
    begin
      result:=t;
      exit;
    end;
end;


function FindDbgByString(const s : string) : TDbg;
var
  hs : string;
  t  : TDbg;
begin
  result:=dbg_none;
  hs:=upper(s);
  for t:=low(TDbg) to high(TDbg) do
   if Assigned(dbginfos[t]) and
      (dbginfos[t]^.idtxt=hs) then
    begin
      result:=t;
      exit;
    end;
end;


function UpdateAlignment(var d:TAlignmentInfo;const s:TAlignmentInfo) : boolean;
begin
  result:=true;
  with d do
   begin
     if (s.ProcAlign in [1,2,4,8,16,32,64,128]) or (s.ProcAlign=256) then
       ProcAlign:=s.ProcAlign
     else if s.ProcAlign<>0 then
       result:=false;
     if (s.LoopAlign in [1,2,4,8,16,32,64,128]) or (s.LoopAlign=256) then
       LoopAlign:=s.LoopAlign
     else if s.LoopAlign<>0 then
       result:=false;
     if (s.JumpAlign in [1,2,4,8,16,32,64,128]) or (s.JumpAlign=256) then
       JumpAlign:=s.JumpAlign
     else if s.JumpAlign<>0 then
       result:=false;
     if (s.CoalesceAlign in [1,2,4,8,16,32,64,128]) or (s.CoalesceAlign=256) then
       CoalesceAlign:=s.CoalesceAlign
     else if s.CoalesceAlign<>0 then
       result:=false;
     if s.JumpAlignSkipMax>0 then
       JumpAlignSkipMax:=s.JumpAlignSkipMax;
     if s.CoalesceAlign>0 then
       CoalesceAlignSkipMax:=s.CoalesceAlignSkipMax;
     { general update rules:
       minimum: if higher then update
       maximum: if lower then update or if undefined then update }
     if s.ConstAlignMin>ConstAlignMin then
      ConstAlignMin:=s.ConstAlignMin;
     if (ConstAlignMax=0) or
        ((s.ConstAlignMax>0) and (s.ConstAlignMax<ConstAlignMax)) then
      ConstAlignMax:=s.ConstAlignMax;
     if s.VarAlignMin>VarAlignMin then
      VarAlignMin:=s.VarAlignMin;
     if (VarAlignMax=0) or
        ((s.VarAlignMax>0) and (s.VarAlignMax<VarAlignMax)) then
      VarAlignMax:=s.VarAlignMax;
     if s.LocalAlignMin>LocalAlignMin then
      LocalAlignMin:=s.LocalAlignMin;
     if (LocalAlignMax=0) or
        ((s.LocalAlignMax>0) and (s.LocalAlignMax<LocalAlignMax)) then
      LocalAlignMax:=s.LocalAlignMax;
     if s.RecordAlignMin>RecordAlignMin then
      RecordAlignMin:=s.RecordAlignMin;
     if (RecordAlignMax=0) or
        ((s.RecordAlignMax>0) and (s.RecordAlignMax<RecordAlignMax)) then
      RecordAlignMax:=s.RecordAlignMax;
     if (MaxCRecordAlign=0) or
        ((s.MaxCRecordAlign>0) and (s.MaxCRecordAlign<MaxCRecordAlign)) then
      MaxCRecordAlign:=s.MaxCRecordAlign;
   end;
end;


{****************************************************************************
                              Target registration
****************************************************************************}

procedure RegisterTarget(const r:TSystemInfo);
var
  t : TSystem;
begin
  t:=r.system;
  if Assigned(targetinfos[Ord(t)]) then
   WriteLn('Warning: Target is already registered!')
  else
   new(targetinfos[Ord(t)]);
  targetinfos[Ord(t)]^:=r;
end;


procedure RegisterRes(const r:TResInfo; rcf : TAbstractResourceFileClass);
var
  t : TRes;
begin
  t:=r.id;
  if not Assigned(resinfos[t]) then
    new(resinfos[t]);
  resinfos[t]^:=r;
  resinfos[t]^.resourcefileclass:=rcf;
end;


procedure RegisterAr(const r:TArInfo);
var
  t : TAr;
begin
  t:=r.id;
  if Assigned(arinfos[t]) then
    WriteLn('Warning: ar is already registered!')
  else
    new(arinfos[t]);
  arinfos[t]^:=r;
end;



procedure DeregisterInfos;
var
  assem   : TAsm;
  target  : TSystem;
  ar      : TAr;
  res     : TRes;
  dbg     : TDbg;
begin
  for target:=low(TSystem) to high(TSystem) do
   if Assigned(targetinfos[Ord(target)]) then
    begin
      FreeMem(targetinfos[Ord(target)],sizeof(TSystemInfo));
      targetinfos[Ord(target)]:=nil;
    end;
  for assem:=low(TAsm) to high(TAsm) do
   if Assigned(asminfos[assem]) then
    begin
      FreeMem(asminfos[assem],sizeof(TAsmInfo));
      asminfos[assem]:=nil;
    end;
  for ar:=low(TAr) to high(TAr) do
   if Assigned(arinfos[ar]) then
    begin
      FreeMem(arinfos[ar],sizeof(TArInfo));
      arinfos[ar]:=nil;
    end;
  for res:=low(TRes) to high(TRes) do
   if Assigned(resinfos[res]) then
    begin
      FreeMem(resinfos[res],sizeof(TResInfo));
      resinfos[res]:=nil;
    end;
  for dbg:=low(TDbg) to high(TDbg) do
   if Assigned(dbginfos[dbg]) then
    begin
      FreeMem(dbginfos[dbg],sizeof(TDbgInfo));
      dbginfos[dbg]:=nil;
    end;
end;


{****************************************************************************
                      Initialization of default target
****************************************************************************}

procedure default_target(t:TSystem);
begin
  SetTarget(t);
  if SourceInfo.name='' then
    SourceInfo:=TargetInfo;
end;


procedure SetSourceInfo(const ti : TSystemInfo);
begin
{ can't use message() here (PFV) }
  if SourceInfo.name<>'' then
    WriteLn('Warning: Source OS Redefined!');
  SourceInfo:=ti;
end;


procedure InitSystems;
begin
{ Now default target, this is dependent on the target cpu define,
  when the define is the same as the source cpu then we use the source
  os, else we pick a default }

{$ifdef i386}
  {$ifdef cpui386}
    default_target(SourceInfo.system);
    {$define default_target_set}
  {$else cpui386}
    {$ifdef MSWindows}
      default_target(system_i386_win32);
      {$define default_target_set}
    {$endif}
    {$ifdef linux}
      default_target(system_i386_linux);
      {$define default_target_set}
    {$endif}
  {$endif cpui386}
  {$ifndef default_target_set}
    default_target(system_i386_linux);
  {$endif default_target_set}
{$endif i386}


{$ifdef x86_64}
  {$ifdef cpux86_64}
    default_target(SourceInfo.system);
    {$define default_target_set}
  {$else cpux86_64}
   {$ifdef MSWindows}
    default_target(system_x86_64_win64);
    {$define default_target_set}
   {$endif}
   {$ifdef linux}
    default_target(system_x86_64_linux);
    {$define default_target_set}
   {$endif}
   {$ifdef darwin}
    default_target(system_x86_64_darwin);
    {$define default_target_set}
   {$endif}
  {$endif cpux86_64}
  { default is linux }
  {$ifndef default_target_set}
   default_target(system_x86_64_linux);
  {$endif default_target_set}
{$endif x86_64}











{$ifdef aarch64}
  {$ifdef cpuaarch64}
    default_target(SourceInfo.system);
  {$else cpuaarch64}
    {$if defined(ios)}
      {$define default_target_set}
      default_target(system_aarch64_ios);
    {$elseif defined(darwin)}
      {$define default_target_set}
      default_target(system_aarch64_darwin);
    {$endif}
    {$ifdef android}
      {$define default_target_set}
      default_target(system_aarch64_android);
    {$endif android}
    {$ifdef windows}
      {$define default_target_set}
      default_target(system_aarch64_win64);
    {$endif}
    {$ifndef default_target_set}
      default_target(system_aarch64_linux);
      {$define default_target_set}
    {$endif}
  {$endif cpuaarch64}
{$endif aarch64}








end;


initialization
   SourceInfo.name:='';
finalization
  DeregisterInfos;
end.
