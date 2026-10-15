{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2008 by Peter Vreman

    Executable file reading functions

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{
  This unit should not be compiled in objfpc mode, since this would make it
  dependent on objpas unit.
}

{ Disable checks of pointers explicitly,
  as we are dealing here with special pointer that
  might be seen as invalid by heaptrc unit CheckPointer function }

{$checkpointer off}
{$modeswitch out}
{$IFNDEF FPC_DOTTEDUNITS}
unit exeinfo;
{$ENDIF FPC_DOTTEDUNITS}
interface

{$S-}

type
  TExeProcessAddress = ptruint;
  TExeOffset = ptruint;
  TExeFile=record
    f : file;
    // cached filesize
    size      : int64;
    isopen    : boolean;
    nsects    : longint;
    sechdrofs,
    secstrofs : TExeOffset;
    processaddress : TExeProcessAddress;

{$ifdef darwin}
    { total size of all headers }
    loadcommandssize: ptruint;
{$endif}
    // Offset of the binary image forming permanent offset to all retrieved values
    ImgOffset: TExeOffset;
    filename  : shortstring;
  end;

function OpenExeFile(var e:TExeFile;const fn:shortstring):boolean;
function FindExeSection(var e:TExeFile;const secname:shortstring;var secofs,seclen:longint):boolean;
function CloseExeFile(var e:TExeFile):boolean;
function ReadDebugLink(var e:TExeFile;var dbgfn:ansistring):boolean; overload;
function ReadDebugLink(var e:TExeFile;var dbgfn:shortstring):boolean; overload;


procedure GetModuleByAddr(addr: pointer; var baseaddr: pointer; var filename: ansistring);


implementation

{$IFDEF FPC_DOTTEDUNITS}
uses
{$ifdef darwin}
  System.CTypes, UnixApi.Base, UnixApi.Dl,
{$endif}
{$ifdef Windows}
  WinApi.Windows,
{$endif Windows}
  System.Strings;
{$ELSE FPC_DOTTEDUNITS}
uses
{$ifdef darwin}
  ctypes, baseunix, dl,
{$endif}
  strings{$ifdef windows},windows{$endif windows};
{$ENDIF FPC_DOTTEDUNITS}

function ReadDebugLink(var e:TExeFile;var dbgfn:shortstring):boolean;

var
  fn : ansistring;

begin
  ReadDebugLink:=ReadDebugLink(e,fn);
  if ReadDebugLink then
    if (length(fn)<256) then
      dbgfn:=fn
    else
      ReadDebugLink:=False;
end;


{$if defined(unix)}

  procedure GetModuleByAddr(addr: pointer; var baseaddr: pointer; var filename: ansistring);
    begin
      if assigned(UnixGetModuleByAddrHook) then
        UnixGetModuleByAddrHook(addr,baseaddr,filename)
      else
        begin
          baseaddr:=nil;
          filename:=ParamStr(0);
        end;
    end;

{$elseif defined(windows)}

  var
    Tmm: TMemoryBasicInformation;
{$ifdef FPC_OS_UNICODE}
    TST: array[0..Max_Path] of WideChar;
{$else}
    TST: array[0..Max_Path] of AnsiChar;
{$endif FPC_OS_UNICODE}
  procedure GetModuleByAddr(addr: pointer; var baseaddr: pointer; var filename: ansistring);
    begin
      baseaddr:=nil;
      if VirtualQuery(addr, @Tmm, SizeOf(Tmm))<>sizeof(Tmm) then
        filename:=ParamStr(0)
      else
        begin
          baseaddr:=Tmm.AllocationBase;
          TST[0]:= #0;
          if baseaddr <> nil then
            begin
{$ifdef FPC_OS_UNICODE}
              GetModuleFileNameW(THandle(Tmm.AllocationBase), TST, Length(TST));
              filename:= String(PWideChar(@TST));
{$else}
              GetModuleFileNameA(THandle(Tmm.AllocationBase), TST, Length(TST));
              filename:= String(PAnsiChar(@TST));
{$endif FPC_OS_UNICODE}
            end;
        end;
    end;

{$else}


  procedure GetModuleByAddr(addr: pointer; var baseaddr: pointer; var filename: ansistring);

    begin
      baseaddr:= nil;
{$ifdef FPC_HAS_FEATURE_COMMANDARGS}
      filename:=ParamStr(0);
{$else FPC_HAS_FEATURE_COMMANDARGS}
      filename:='';
{$endif FPC_HAS_FEATURE_COMMANDARGS}
    end;

{$endif}

{****************************************************************************
                             Executable Loaders
****************************************************************************}

{$if (defined(linux)) or (defined(android))}
  {$ifdef cpu64}
    {$define ELF64}
    {$define FIND_BASEADDR_ELF}
  {$else}
    {$define ELF32}
    {$define FIND_BASEADDR_ELF}
  {$endif}
{$endif}




{$if defined(win32)}
  {$define PE32}
{$endif}

{$if defined(win64)}
  {$define PE32PLUS}
{$endif}




{****************************************************************************
                              DOS Stub
****************************************************************************}

{$if (defined(PE32)) or (defined(PE32PLUS))}
type
  tdosheader = packed record
     e_magic : word;
     e_cblp : word;
     e_cp : word;
     e_crlc : word;
     e_cparhdr : word;
     e_minalloc : word;
     e_maxalloc : word;
     e_ss : word;
     e_sp : word;
     e_csum : word;
     e_ip : word;
     e_cs : word;
     e_lfarlc : word;
     e_ovno : word;
     e_res : array[0..3] of word;
     e_oemid : word;
     e_oeminfo : word;
     e_res2 : array[0..9] of word;
     e_lfanew : longint;
  end;
{$endif EMX or PE32 or PE32PLUS or GO32v2}


{****************************************************************************
                                  NLM
****************************************************************************}



{****************************************************************************
                               COFF
****************************************************************************}

{$if (defined(PE32)) or (defined(PE32PLUS))}
type
  tcoffsechdr=packed record
    name     : array[0..7] of ansichar;
    vsize    : longint;
    rvaofs   : longint;
    datalen  : longint;
    datapos  : longint;
    relocpos : longint;
    lineno1  : longint;
    nrelocs  : word;
    lineno2  : word;
    flags    : longint;
  end;
  coffsymbol=packed record
    name    : array[0..3] of ansichar; { real is [0..7], which overlaps the strofs ! }
    strofs  : longint;
    value   : longint;
    section : smallint;
    empty   : word;
    typ     : byte;
    aux     : byte;
  end;

function FindSectionCoff(var e:TExeFile;const asecname:shortstring;var secofs,seclen:longint):boolean;
var
  i : longint;
  sechdr     : tcoffsechdr;
  secname    : shortstring;
  secnamebuf : array[0..255] of ansichar;
  code,
  oldofs,
  bufsize    : longint;
  strofs     : cardinal;
begin
  FindSectionCoff:=false;
  { read section info }
  seek(e.f,e.sechdrofs);
  for i:=1 to e.nsects do
   begin
     blockread(e.f,sechdr,sizeof(sechdr),bufsize);
     move(sechdr.name,secnamebuf,8);
     secnamebuf[8]:=#0;
     secname:=strpas(secnamebuf);
     if secname[1]='/' then
       begin
         Val(Copy(secname,2,8),strofs,code);
         if code=0 then
           begin
             fillchar(secnamebuf,sizeof(secnamebuf),0);
             oldofs:=filepos(e.f);
             seek(e.f,e.secstrofs+strofs);
             blockread(e.f,secnamebuf,sizeof(secnamebuf),bufsize);
             seek(e.f,oldofs);
             secname:=strpas(secnamebuf);
           end
         else
           secname:='';
       end;
     if asecname=secname then
       begin
         secofs:=cardinal(sechdr.datapos) + E.ImgOffset;
         { In PECOFF, datalen includes file padding up to the next section.
           vsize is the actual payload size if it does not exceed datalen,
           otherwise it is .bss (or alike) section that we should ignore.  }
         if sechdr.vsize<=sechdr.datalen then
           seclen:=sechdr.vsize
         else
           exit;
         FindSectionCoff:=true;
         exit;
       end;
   end;
end;
{$endif PE32 or PE32PLUS or GO32V2}




{$ifdef PE32}
function OpenPeCoff(var e:TExeFile):boolean;
type
  tpeheader = packed record
     PEMagic : longint;
     Machine : word;
     NumberOfSections : word;
     TimeDateStamp : longint;
     PointerToSymbolTable : longint;
     NumberOfSymbols : longint;
     SizeOfOptionalHeader : word;
     Characteristics : word;
     Magic : word;
     MajorLinkerVersion : byte;
     MinorLinkerVersion : byte;
     SizeOfCode : longint;
     SizeOfInitializedData : longint;
     SizeOfUninitializedData : longint;
     AddressOfEntryPoint : longint;
     BaseOfCode : longint;
     BaseOfData : longint;
     ImageBase : longint;
     SectionAlignment : longint;
     FileAlignment : longint;
     MajorOperatingSystemVersion : word;
     MinorOperatingSystemVersion : word;
     MajorImageVersion : word;
     MinorImageVersion : word;
     MajorSubsystemVersion : word;
     MinorSubsystemVersion : word;
     Reserved1 : longint;
     SizeOfImage : longint;
     SizeOfHeaders : longint;
     CheckSum : longint;
     Subsystem : word;
     DllCharacteristics : word;
     SizeOfStackReserve : longint;
     SizeOfStackCommit : longint;
     SizeOfHeapReserve : longint;
     SizeOfHeapCommit : longint;
     LoaderFlags : longint;
     NumberOfRvaAndSizes : longint;
     DataDirectory : array[1..$80] of byte;
  end;
var
  dosheader  : tdosheader;
  peheader   : tpeheader;
begin
  OpenPeCoff:=false;
  { read and check header }
  if e.size<sizeof(dosheader) then
    exit;
  blockread(e.f,dosheader,sizeof(tdosheader));
  seek(e.f,dosheader.e_lfanew);
  blockread(e.f,peheader,sizeof(tpeheader));
  if peheader.pemagic<>$4550 then
    exit;
  e.sechdrofs:=filepos(e.f);
  e.nsects:=peheader.NumberOfSections;
  e.secstrofs:=peheader.PointerToSymbolTable+peheader.NumberOfSymbols*sizeof(coffsymbol);
  if e.secstrofs>e.size then
    exit;
  e.processaddress:=peheader.ImageBase;
  OpenPeCoff:=true;
end;
{$endif PE32}


{$ifdef PE32PLUS}
function OpenPePlusCoff(var e:TExeFile):boolean;
type
  tpeheader = packed record
     PEMagic : longint;
     Machine : word;
     NumberOfSections : word;
     TimeDateStamp : longint;
     PointerToSymbolTable : longint;
     NumberOfSymbols : longint;
     SizeOfOptionalHeader : word;
     Characteristics : word;
     Magic : word;
     MajorLinkerVersion : byte;
     MinorLinkerVersion : byte;
     SizeOfCode : longint;
     SizeOfInitializedData : longint;
     SizeOfUninitializedData : longint;
     AddressOfEntryPoint : longint;
     BaseOfCode : longint;
     ImageBase : qword;
     SectionAlignment : longint;
     FileAlignment : longint;
     MajorOperatingSystemVersion : word;
     MinorOperatingSystemVersion : word;
     MajorImageVersion : word;
     MinorImageVersion : word;
     MajorSubsystemVersion : word;
     MinorSubsystemVersion : word;
     Reserved1 : longint;
     SizeOfImage : longint;
     SizeOfHeaders : longint;
     CheckSum : longint;
     Subsystem : word;
     DllCharacteristics : word;
     SizeOfStackReserve : qword;
     SizeOfStackCommit : qword;
     SizeOfHeapReserve : qword;
     SizeOfHeapCommit : qword;
     LoaderFlags : longint;
     NumberOfRvaAndSizes : longint;
     DataDirectory : array[1..$80] of byte;
  end;
var
  dosheader  : tdosheader;
  peheader   : tpeheader;
begin
  OpenPePlusCoff:=false;
  { read and check header }
  if E.Size<sizeof(dosheader) then
   exit;
  blockread(E.F,dosheader,sizeof(tdosheader));
  seek(E.F,dosheader.e_lfanew);
  blockread(E.F,peheader,sizeof(tpeheader));
  if peheader.pemagic<>$4550 then
   exit;
  e.sechdrofs:=filepos(e.f);
  e.nsects:=peheader.NumberOfSections;
  e.secstrofs:=peheader.PointerToSymbolTable+peheader.NumberOfSymbols*sizeof(coffsymbol);
  if e.secstrofs>e.size then
    exit;
  e.processaddress:=peheader.ImageBase;
  OpenPePlusCoff:=true;
end;
{$endif PE32PLUS}


{****************************************************************************
                                 AOUT
****************************************************************************}



{****************************************************************************
                                 ELF
****************************************************************************}

{$if defined(ELF32)}
type
  telfheader=packed record
      magic0123         : longint;
      file_class        : byte;
      data_encoding     : byte;
      file_version      : byte;
      padding           : array[$07..$0f] of byte;
      e_type            : word;
      e_machine         : word;
      e_version         : longword;
      e_entry           : longword;                  // entrypoint
      e_phoff           : longword;                  // program header offset
      e_shoff           : longword;                  // sections header offset
      e_flags           : longword;
      e_ehsize          : word;             // elf header size in bytes
      e_phentsize       : word;             // size of an entry in the program header array
      e_phnum           : word;             // 0..e_phnum-1 of entrys
      e_shentsize       : word;             // size of an entry in sections header array
      e_shnum           : word;             // 0..e_shnum-1 of entrys
      e_shstrndx        : word;             // index of string section header
  end;
  telfsechdr=packed record
      sh_name           : longword;
      sh_type           : longword;
      sh_flags          : longword;
      sh_addr           : longword;
      sh_offset         : longword;
      sh_size           : longword;
      sh_link           : longword;
      sh_info           : longword;
      sh_addralign      : longword;
      sh_entsize        : longword;
    end;
  telfproghdr=packed record
    p_type            : longword;
    p_offset          : longword;
    p_vaddr           : longword;
    p_paddr           : longword;
    p_filesz          : longword;
    p_memsz           : longword;
    p_flags           : longword;
    p_align           : longword;
  end;
{$endif ELF32}
{$ifdef ELF64}
type
  telfheader=packed record
      magic0123         : longint;
      file_class        : byte;
      data_encoding     : byte;
      file_version      : byte;
      padding           : array[$07..$0f] of byte;
      e_type            : word;
      e_machine         : word;
      e_version         : longword;
      e_entry           : int64;                  // entrypoint
      e_phoff           : int64;                  // program header offset
      e_shoff           : int64;                  // sections header offset
      e_flags           : longword;
      e_ehsize          : word;             // elf header size in bytes
      e_phentsize       : word;             // size of an entry in the program header array
      e_phnum           : word;             // 0..e_phnum-1 of entrys
      e_shentsize       : word;             // size of an entry in sections header array
      e_shnum           : word;             // 0..e_shnum-1 of entrys
      e_shstrndx        : word;             // index of string section header
  end;
type
  telfsechdr=packed record
      sh_name           : longword;
      sh_type           : longword;
      sh_flags          : int64;
      sh_addr           : int64;
      sh_offset         : int64;
      sh_size           : int64;
      sh_link           : longword;
      sh_info           : longword;
      sh_addralign      : int64;
      sh_entsize        : int64;
    end;

  telfproghdr=packed record
    p_type            : longword;
    p_flags           : longword;
    p_offset          : qword;
    p_vaddr           : qword;
    p_paddr           : qword;
    p_filesz          : qword;
    p_memsz           : qword;
    p_align           : qword;
  end;
{$endif ELF64}


{$if defined(ELF32) or defined(ELF64)}

{$ifdef FIND_BASEADDR_ELF}
var
  LocalJmpBuf : Jmp_Buf;
procedure LocalError;
begin
  Longjmp(LocalJmpBuf,1);
end;

procedure GetExeInMemoryBaseAddr(addr : pointer; var BaseAddr : pointer;
                                 var filename : ansistring);
type
  AT_HDR = record
    typ : ptruint;
    value : ptruint;
  end;
  P_AT_HDR = ^AT_HDR;

{ Values taken from /usr/include/linux/auxvec.h }
const
  AT_HDR_COUNT = 5;{ AT_PHNUM }
  AT_HDR_SIZE = 4; { AT_PHENT }
  AT_HDR_Addr = 3; { AT_PHDR }
  AT_HDR_PageSize = 6; {AT_PAGESZ }
  AT_EXE_FN = 31;  {AT_EXECFN }
  max_elf_attempt = 256; { limit the number of pages checked for ELF prefix }
var
  pc : PPAnsiChar;
  pat_hdr : P_AT_HDR;
  i, phdr_count, elf_attempt : ptrint;
  phdr_size : ptruint;
  phdr :  ^telfproghdr;
  found_addr, pagesize : ptruint;
  pelf : pchar;
  is_elf_start : boolean;
  SavedExitProc : pointer;
begin
  filename:=ParamStr(0);
  SavedExitProc:=ExitProc;
  ExitProc:=@LocalError;
  pc:=envp;
  elf_attempt:=0;
  phdr_count:=-1;
  phdr_size:=0;
  phdr:=nil;
  pagesize:=ptruint(-1);
  found_addr:=ptruint(-1);
  pelf:=pchar(-1);
  { Try, avoided in order to remove exception installation }
  if SetJmp(LocalJmpBuf)=0 then
  begin
    while (assigned(pc^)) do
      inc (pointer(pc), sizeof(ptruint));
    inc(pointer(pc), sizeof(ptruint));
    pat_hdr:=P_AT_HDR(pc);
    while assigned(pat_hdr) do
      begin
        if (pat_hdr^.typ=0) and (pat_hdr^.value=0) then
          break;
        if pat_hdr^.typ = AT_HDR_COUNT then
          phdr_count:=pat_hdr^.value;
        if pat_hdr^.typ = AT_HDR_SIZE then
          phdr_size:=pat_hdr^.value;
        if pat_hdr^.typ = AT_HDR_Addr then
          phdr := pointer(pat_hdr^.value);
        if pat_hdr^.typ = AT_HDR_PageSize then
          pagesize := ptruint(pat_hdr^.value);
        if pat_hdr^.typ = AT_EXE_FN then
          filename:=strpas(pansichar(pat_hdr^.value));
        inc (pointer(pat_hdr),sizeof(AT_HDR));
      end;
    if (phdr_count>0) and (phdr_size = sizeof (telfproghdr)) and  assigned(phdr) then
      begin
        for i:=0 to phdr_count -1 do
          begin
            if (phdr^.p_type = 1 {PT_LOAD}) and (ptruint(phdr^.p_vaddr) < ptruint(addr))
               and ((found_addr=ptruint(-1)) or (found_addr<ptruint(phdr^.p_vaddr))) then
              begin
                found_addr:=phdr^.p_vaddr;
                if pagesize=ptruint(-1) then
                  pagesize:=phdr^.p_align;
                if phdr^.p_offset < found_addr then
                  dec(found_addr,phdr^.p_offset);
              end;
            inc(pointer(phdr), phdr_size);
          end;
      end;

    if (found_addr=ptruint(-1)) or ((found_addr < ptruint(phdr)) and (ptruint(phdr)<ptruint(addr))) then
      found_addr:=ptruint(phdr);
    { Set pagesize to a default small value }
    if (pagesize=ptruint(-1)) then
      pagesize:=$100;
    pelf := pchar(found_addr and ptruint(not (pagesize-1)));
    is_elf_start:=false;
    repeat
      if (pelf[0]=#127) and (pelf[1]='E') and
         (pelf[2]='L') and (pelf[3]='F') then
        is_elf_start:=true
      else
        pelf:=pchar(ptruint(pelf) - pagesize);
      inc(elf_attempt);
    until is_elf_start or (elf_attempt > max_elf_attempt);
    if is_elf_start then
      found_addr:=ptruint(pelf);
    if found_addr<>ptruint(-1) then
      begin
        {$ifdef DEBUG_LINEINFO}
        Writeln(stderr,'Found memory base addr = $',hexstr(found_addr,2 * sizeof(ptruint)));
        {$endif}
        BaseAddr:=pointer(found_addr);
     end
    {$ifdef DEBUG_LINEINFO}
    else
      begin
        writeln(stderr,'Error parsing stack');
        if (phdr_count=-1) then
           writeln(stderr,'AUX entry AT_PHNUM not found');
        if (phdr_size=0) then
           writeln(stderr,'AUX entry AT_PHENT not found');
        if (phdr=nil) then
           writeln(stderr,'AUX entry AT_PHDR not found');
      end;
    {$endif DEBUG_LINEINFO}
  end
  else
  begin
  {$ifdef DEBUG_LINEINFO}
    writeln(stderr,'Exception generated while trying to find program base addr');
    writeln(stderr,'elf_attempt=',elf_attempt);
    writeln(stderr,'Found memory base addr = $',hexstr(found_addr,2 * sizeof(ptruint)));
    writeln(stderr,'pelf addr = $',hexstr(ptruint(pelf),2 * sizeof(ptruint)));
  {$endif DEBUG_LINEINFO}
  end;
  ExitProc:=SavedExitProc;
end;
{$endif FIND_BASEADDR_ELF}

function OpenElf(var e:TExeFile):boolean;
var
  elfheader : telfheader;
  elfsec    : telfsechdr;
  phdr      : telfproghdr;
  i         : longint;
begin
  OpenElf:=false;
  { read and check header }
  if e.size<(sizeof(telfheader)+e.ImgOffset) then
   exit;
  seek(e.f,e.ImgOffset);
  blockread(e.f,elfheader,sizeof(telfheader));
 if elfheader.magic0123<>{$ifdef ENDIAN_LITTLE}$464c457f{$else}$7f454c46{$endif} then
   exit;
  if elfheader.e_shentsize<>sizeof(telfsechdr) then
   exit;
  { read section names }
  seek(e.f,e.ImgOffset+elfheader.e_shoff+elfheader.e_shstrndx*cardinal(sizeof(telfsechdr)));
  blockread(e.f,elfsec,sizeof(telfsechdr));
  e.secstrofs:=elfsec.sh_offset;
  e.sechdrofs:=elfheader.e_shoff;
  e.nsects:=elfheader.e_shnum;

  { scan program headers to find the image base address }
  e.processaddress:=High(e.processaddress);
  seek(e.f,e.ImgOffset+elfheader.e_phoff);
  for i:=1 to elfheader.e_phnum do
    begin
      blockread(e.f,phdr,sizeof(phdr));
      if (phdr.p_type = 1 {PT_LOAD}) and (ptruint(phdr.p_vaddr) < e.processaddress) then
        e.processaddress:=phdr.p_vaddr;
    end;

  if e.processaddress = High(e.processaddress) then
    e.processaddress:=0;

  OpenElf:=true;
end;


function FindSectionElf(var e:TExeFile;const asecname:shortstring;var secofs,seclen:longint):boolean;
var
  elfsec     : telfsechdr;
  secname    : string;
  secnamebuf : array[0..255] of ansichar;
  oldofs,
  bufsize,i  : longint;
begin
  FindSectionElf:=false;
  seek(e.f,e.ImgOffset+e.sechdrofs);
  for i:=1 to e.nsects do
   begin
     blockread(e.f,elfsec,sizeof(telfsechdr));
     fillchar(secnamebuf,sizeof(secnamebuf),0);
     oldofs:=filepos(e.f);
     seek(e.f,e.ImgOffset+e.secstrofs+elfsec.sh_name);
     blockread(e.f,secnamebuf,sizeof(secnamebuf)-1,bufsize);
     seek(e.f,oldofs);
     secname:=strpas(secnamebuf);
     if asecname=secname then
       begin
         secofs:=e.ImgOffset+elfsec.sh_offset;
         seclen:=elfsec.sh_size;
         FindSectionElf:=true;
         exit;
       end;
   end;
end;
{$endif ELF32 or ELF64}


{****************************************************************************
                                 MACHO
****************************************************************************}

{$ifdef darwin}
{$push}
{$packrecords c}
type
  tmach_integer = cint;
  tmach_cpu_type = tmach_integer;
  tmach_cpu_subtype = tmach_integer;
  tmach_cpu_threadtype = tmach_integer;


  tmach_fat_header=record
    magic: cuint32;
    nfatarch: cuint32;
  end;

  tmach_fat_arch=record
    cputype: tmach_cpu_type;
    cpusubtype: tmach_cpu_subtype;
    offset: cuint32;
    size: cuint32;
    align: cuint32;
  end;
  pmach_fat_arch = ^tmach_fat_arch;

(* not yet supported (only needed for slices or combined slice size > 4GB; unrelated to 64 bit processes)
  tmach_fat_arch_64=record
    cputype: tmach_cpu_type;
    cpusubtype: tmach_cpu_subtype;
    offset: cuint64;
    size: cuint64;
    align: cuint32;
    reserved: cuint32;
  end;
*)

  { note: always big endian }
  tmach_header=record
    magic: cuint32;
    cputype: tmach_cpu_type;
    cpusubtype: tmach_cpu_subtype;
    filetype: cuint32;
    ncmds: cuint32;
    sizeofcmds: cuint32;
    flags: cuint32;
    {$IFDEF CPU64}
    reserved: cuint32;
    {$ENDIF}
  end;
  pmach_header = ^tmach_header;

  tmach_load_command=record
    cmd: cuint32;
    cmdsize: cuint32;
  end;
  pmach_load_command=^tmach_load_command;

  tmach_vm_prot = cint;

  tmach_segment_command = record
    cmd     : cuint32;
    cmdsize : cuint32;
    segname : array [0..15] of AnsiChar;
    vmaddr  : {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    vmsize  : {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    fileoff : {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    filesize: {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    maxprot : tmach_vm_prot;
    initptot: tmach_vm_prot;
    nsects  : cuint32;
    flags   : cuint32;
  end;
  pmach_segment_command = ^tmach_segment_command;

  tmach_uuid_command = record
    cmd     : cuint32;
    cmdsize : cuint32;
    uuid    : array[0..15] of cuint8;
  end;
  pmach_uuid_command = ^tmach_uuid_command;

  tmach_section = record
    sectname : array [0..15] of AnsiChar;
    segname  : array [0..15] of AnsiChar;
    addr     : {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    size     : {$IFDEF CPU64}cuint64{$ELSE}cuint32{$ENDIF};
    offset   : cuint32;
    align    : cuint32;
    reloff   : cuint32;
    nreloc   : cuint32;
    flags    : cuint32;
    reserved1: cuint32;
    reserved2: cuint32;
    {$IFDEF CPU64}
    reserved3: cuint32;
    {$ENDIF}
  end;
  pmach_section = ^tmach_section;

  tmach_fat_archs = array[1..high(longint) div sizeof(tmach_header)] of tmach_fat_arch;
  tmach_fat_header_archs = record
    header: tmach_fat_header;
    archs: tmach_fat_archs;
  end;
  pmach_fat_header_archs = ^tmach_fat_header_archs;

{$pop}

const
  MACH_MH_EXECUTE = $02;

  MACH_FAT_MAGIC = $cafebabe;
// not yet supported: only for binaries with slices > 4GB, or total size > 4GB
//  MACH_FAT_MAGIC_64 = $cafebabf;
{$ifdef cpu32}
  MACH_MAGIC = $feedface;
{$else}
  MACH_MAGIC = $feedfacf;
{$endif}
  MACH_CPU_ARCH_MASK = cuint32($ff000000);

{$ifdef cpu32}
  MACH_LC_SEGMENT = $01;
{$else}
  MACH_LC_SEGMENT = $19;
{$endif}
  MACH_LC_SYMTAB  = $02;
  MACH_LC_UUID    = $1b;

{ the in-memory mapping of the mach header of the main binary }
function _NSGetMachExecuteHeader: pmach_header; cdecl; external 'c';

function getpagesize: cint; cdecl; external 'c';

function MapMachO(const h: THandle; offset, len: SizeUInt; out addr: pointer; out memoffset, mappedsize: SizeUInt): boolean;
var
  pagesize: cint;
begin
  pagesize:=getpagesize;
  addr:=fpmmap(nil, len+(offset and (pagesize-1)), PROT_READ, MAP_PRIVATE, h, offset and not(pagesize-1));
  if addr=MAP_FAILED then
    begin
      addr:=nil;
      memoffset:=0;
      mappedsize:=0;
    end
  else
    begin
       memoffset:=offset and (pagesize - 1);
       mappedsize:=len+(offset and (pagesize-1));
    end;
end;

procedure UnmapMachO(p: pointer; size: SizeUInt);
begin
  fpmunmap(p,size);
end;

function OpenMachO(var e:TExeFile):boolean;
var
  mh         : tmach_header;
  processmh  : pmach_header;
  cmd: pmach_load_command;
  segmentcmd: pmach_segment_command;
  mappedexe: pointer;
  mappedoffset, mappedsize: SizeUInt;
  i: cuint32;
  foundpagezero: boolean;
begin
  OpenMachO:=false;
  if e.size<sizeof(mh) then
    exit;
  blockread (e.f, mh, sizeof(mh));
  case mh.magic of
    MACH_FAT_MAGIC:
      begin
        { todo }
        exit
      end;
    MACH_MAGIC:
      begin
        // check that at least the architecture matches (we should also check the subarch,
        // but that's harder because of architecture-specific backward compatibility rules)
        processmh:=_NSGetMachExecuteHeader;
        if (mh.cputype and not(MACH_CPU_ARCH_MASK)) <> (processmh^.cputype and not(MACH_CPU_ARCH_MASK)) then
          exit;
      end;
    else
      exit;
  end;
  e.sechdrofs:=filepos(e.f);
  e.nsects:=mh.ncmds;
  e.loadcommandssize:=mh.sizeofcmds;
  if mh.filetype = MACH_MH_EXECUTE then
    begin
      foundpagezero:= false;
      { make sure to unmap again on all exit paths }
      if not MapMachO(filerec(e.f).handle, e.sechdrofs, e.loadcommandssize, mappedexe, mappedoffset, mappedsize) then
        exit;
      cmd:=pmach_load_command(mappedexe+mappedoffset);
      for i:= 1 to e.nsects do
        begin
          case cmd^.cmd of
            MACH_LC_SEGMENT:
              begin
                segmentcmd:=pmach_segment_command(cmd);
                if segmentcmd^.segname='__PAGEZERO' then
                  begin
                    e.processaddress:=segmentcmd^.vmaddr+segmentcmd^.vmsize;
                    OpenMachO:=true;
                    break;
                  end;
              end;
          end;
          cmd:=pmach_load_command(pointer(cmd)+cmd^.cmdsize);
        end;
      UnmapMachO(mappedexe, mappedsize);
    end
  else
    OpenMachO:=true;
end;


function FindSectionMachO(var e:TExeFile;const asecname:shortstring;var secofs,seclen:longint):boolean;
var
   i, j: cuint32;
   cmd: pmach_load_command;
   segmentcmd: pmach_segment_command;
   section: pmach_section;
   mappedexe: pointer;
   mappedoffset, mappedsize: SizeUInt;
   dwarfsecname: shortstring;
begin
  FindSectionMachO:=false;
  { make sure to unmap again on all exit paths }
  if not MapMachO(filerec(e.f).handle, e.sechdrofs, e.loadcommandssize, mappedexe, mappedoffset, mappedsize) then
    exit;
  cmd:=pmach_load_command(mappedexe+mappedoffset);
  for i:= 1 to e.nsects do
    begin
      case cmd^.cmd of
        MACH_LC_SEGMENT:
          begin
            segmentcmd:=pmach_segment_command(cmd);
            if segmentcmd^.segname='__DWARF' then
              begin
                if asecname[1]='.' then
                  dwarfsecname:='__'+copy(asecname,2,length(asecname))
                else
                  dwarfsecname:=asecname;
                section:=pmach_section(pointer(segmentcmd)+sizeof(segmentcmd^));
                for j:=1 to segmentcmd^.nsects do
                  begin
                    if section^.sectname = dwarfsecname then
                      begin
                        secofs:=section^.offset;
                        seclen:=section^.size;
                        FindSectionMachO:=true;
                        UnmapMachO(mappedexe, mappedsize);
                        exit;
                      end;
                    inc(section);
                  end;
              end;
          end;
      end;
      cmd:=pmach_load_command(pointer(cmd)+cmd^.cmdsize);
    end;
  UnmapMachO(mappedexe, mappedsize);
end;
{$endif darwin}


{****************************************************************************
                                   CRC
****************************************************************************}

var
  Crc32Tbl : array[0..255] of cardinal;

procedure MakeCRC32Tbl;
var
  crc : cardinal;
  i,n : integer;
begin
  for i:=0 to 255 do
   begin
     crc:=i;
     for n:=1 to 8 do
      if (crc and 1)<>0 then
       crc:=(crc shr 1) xor cardinal($edb88320)
      else
       crc:=crc shr 1;
     Crc32Tbl[i]:=crc;
   end;
end;


Function UpdateCrc32(InitCrc:cardinal;const InBuf;InLen:LongInt):cardinal;
var
  i : LongInt;
  p : pansichar;
begin
  if Crc32Tbl[1]=0 then
   MakeCrc32Tbl;
  p:=@InBuf;
  UpdateCrc32:=not InitCrc;
  for i:=1 to InLen do
   begin
     UpdateCrc32:=Crc32Tbl[byte(UpdateCrc32) xor byte(p^)] xor (UpdateCrc32 shr 8);
     inc(p);
   end;
  UpdateCrc32:=not UpdateCrc32;
end;


{****************************************************************************
                         Generic Executable Open/Close
****************************************************************************}

type
  TOpenProc=function(var e:TExeFile):boolean;
  TFindSectionProc=function(var e:TExeFile;const asecname:shortstring;var secofs,seclen:longint):boolean;

  TExeProcRec=record
    openproc : TOpenProc;
    findproc : TFindSectionProc;
  end;

const
  ExeProcs : TExeProcRec = (
{$ifdef PE32}
     openproc : @OpenPeCoff;
     findproc : @FindSectionCoff;
{$endif}
{$ifdef PE32PLUS}
     openproc : @OpenPePlusCoff;
     findproc : @FindSectionCoff;
{$endif PE32PLUS}
{$if defined(ELF32) or defined(ELF64)}
     openproc : @OpenElf;
     findproc : @FindSectionElf;
{$endif ELF32 or ELF64}
{$ifdef darwin}
     openproc : @OpenMachO;
     findproc : @FindSectionMachO;
{$endif darwin}
   );

function OpenExeFile(var e:TExeFile;const fn:shortstring):boolean;
var
  ofm : word;
begin
  OpenExeFile:=false;
  fillchar(e,sizeof(e),0);
  e.filename:=fn;
  if fn='' then   // we don't want to read stdin
    exit;
  assign(e.f,fn);
  {$I-}
   ofm:=filemode;
   filemode:=$40;
   reset(e.f,1);
   filemode:=ofm;
  {$I+}
  if ioresult<>0 then
   exit;
  e.isopen:=true;
  // cache filesize
  e.size:=filesize(e.f);

  E.ImgOffset := 0;
  if ExeProcs.OpenProc<>nil then
    OpenExeFile:=ExeProcs.OpenProc(e);
end;


function CloseExeFile(var e:TExeFile):boolean;
begin
  CloseExeFile:=false;
  if not e.isopen then
    exit;
  e.isopen:=false;
  close(e.f);
  CloseExeFile:=true;
end;


function FindExeSection(var e:TExeFile;const secname:shortstring;var secofs,seclen:longint):boolean;
begin
  FindExeSection:=false;
  if not e.isopen then
    exit;
  if ExeProcs.FindProc<>nil then
    FindExeSection:=ExeProcs.FindProc(e,secname,secofs,seclen);
end;




{$ifdef NEED_SMALL_BUFFER_SIZE}
const
  CheckDbgFile_buf_size = 128;
{$else}
const
  CheckDbgFile_buf_size = 4096;
{$endif}

function CheckDbgFile(var e:TExeFile;const fn:shortstring;dbgcrc:cardinal):boolean;
var
  c      : cardinal;
  ofm    : word;
  g      : file;
  buf    : array[0..CheckDbgFile_buf_size-1] of byte;
  bufcnt : longint;
begin
  CheckDbgFile:=false;
  assign(g,fn);
  {$I-}
   ofm:=filemode;
   filemode:=$40;
   reset(g,1);
   filemode:=ofm;
  {$I+}
  if ioresult<>0 then
   exit;
  { We reuse the buffer from e here to prevent too much stack allocation }
  c:=0;
  repeat
    blockread(g,buf,sizeof(buf),bufcnt);
    c:=UpdateCrc32(c,buf,bufcnt);
  until bufcnt<sizeof(buf);
  close(g);
  CheckDbgFile:=(dbgcrc=c);
end;

{$ifndef darwin}
function ReadDebugLink(var e:TExeFile;var dbgfn:ansistring):boolean;
var
  dbglink : array[0..255] of AnsiChar;
  i,
  dbglinklen,
  dbglinkofs : longint;
  dbgcrc     : cardinal;
begin
  ReadDebugLink:=false;
  if not FindExeSection(e,'.gnu_debuglink',dbglinkofs,dbglinklen) then
    exit;
  if dbglinklen>sizeof(dbglink)-1 then
    exit;
  fillchar(dbglink,sizeof(dbglink),0);
  seek(e.f,dbglinkofs);
  blockread(e.f,dbglink,dbglinklen);
  dbgfn:=strpas(dbglink);
  if length(dbgfn)=0 then
    exit;
  i:=align(length(dbgfn)+1,4);
  if (i+4)>dbglinklen then
    exit;
  move(dbglink[i],dbgcrc,4);
  { current dir }
  if CheckDbgFile(e,dbgfn,dbgcrc) then
    begin
      ReadDebugLink:=true;
      exit;
    end;
  { executable dir }
  i:=length(e.filename);
  while (i>0) and not(e.filename[i] in AllowDirectorySeparators) do
    dec(i);
  if i>0 then
    begin
      dbgfn:=copy(e.filename,1,i)+dbgfn;
      if CheckDbgFile(e,dbgfn,dbgcrc) then
        begin
          ReadDebugLink:=true;
          exit;
        end;
    end;
end;
{$else}
function ReadDebugLink(var e:TExeFile;var dbgfn:ansistring):boolean;
var
   dsymexefile: TExeFile;
   execmd, dsymcmd: pmach_load_command;
   exeuuidcmd, dsymuuidcmd: pmach_uuid_command;
   mappedexe, mappeddsym: pointer;
   mappedexeoffset, mappedexesize, mappeddsymoffset, mappeddsymsize: SizeUInt;
   i, j: cuint32;
   filenamestartpos, b: byte;
begin
  ReadDebugLink:=false;
  if not MapMachO(filerec(e.f).handle, e.sechdrofs, e.loadcommandssize, mappedexe, mappedexeoffset, mappedexesize) then
    exit;
  execmd:=pmach_load_command(mappedexe+mappedexeoffset);
  for i:=1 to e.nsects do
    begin
      case execmd^.cmd of
        MACH_LC_UUID:
          begin
            exeuuidcmd:=pmach_uuid_command(execmd);
            filenamestartpos:=1;
            for b:=1 to length(e.filename) do
              begin
                if e.filename[b] = '/' then
                  filenamestartpos:=b+1;
              end;
            if not OpenExeFile(dsymexefile,e.filename+'.dSYM/Contents/Resources/DWARF/'+copy(e.filename,filenamestartpos,length(e.filename))) then
              begin
{$IFDEF DEBUG_LINEINFO}
                writeln(stderr,'OpenExeFile for ',e.filename+'.dSYM/Contents/Resources/DWARF/'+copy(e.filename,filenamestartpos,length(e.filename)),' did not succeed.');
{$endif DEBUG_LINEINFO}
                UnmapMachO(mappedexe, mappedexesize);
                exit;
              end;
            if not MapMachO(filerec(dsymexefile.f).handle, dsymexefile.sechdrofs, dsymexefile.loadcommandssize, mappeddsym, mappeddsymoffset, mappeddsymsize) then
              begin
                CloseExeFile(dsymexefile);
                UnmapMachO(mappedexe, mappedexesize);
                exit;
              end;
            dsymcmd:=pmach_load_command(mappeddsym+mappeddsymoffset);
            for j:=1 to dsymexefile.nsects do
              begin
                case dsymcmd^.cmd of
                  MACH_LC_UUID:
                    begin
                      dsymuuidcmd:=pmach_uuid_command(dsymcmd);
                      if comparebyte(exeuuidcmd^.uuid, dsymuuidcmd^.uuid, sizeof(exeuuidcmd^.uuid)) = 0 then
                        begin
                          dbgfn:=dsymexefile.filename;
                          ReadDebugLink:=true;
                        end;
                      break;
                    end;
                end;
              end;
            UnmapMachO(mappeddsym, mappeddsymsize);
            CloseExeFile(dsymexefile);
            UnmapMachO(mappedexe, mappedexesize);
            exit;
          end;
      end;
      execmd:=pmach_load_command(pointer(execmd)+execmd^.cmdsize);
    end;
  UnmapMachO(mappedexe, mappedexesize);
end;
{$endif}


begin
{$ifdef FIND_BASEADDR_ELF}
  UnixGetModuleByAddrHook:=@GetExeInMemoryBaseAddr;
{$endif FIND_BASEADDR_ELF}
end.
