{
    Copyright (c) 1998-2013 by Free Pascal development team

    Routines to read/write entry based files (ppu, pcp)

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
unit entfile;

{$i fpcdefs.inc}

interface

  uses
    TPCompilerReal,
    Systems,GlobType,ConstExp,CStreams,NXEntryBuffer;

const
{ buffer sizes }
  maxentrysize = 1024;
  // Unused, and wrong as there are entries that are larger then 1024 bytes

{$ifdef CHECK_INPUTPOINTER_LIMITS}
  default_entryfilebufsize   = 16384;
{$else not CHECK_INPUTPOINTER_LIMITS}
  entryfilebufsize   = 16384;
{$endif CHECK_INPUTPOINTER_LIMITS}

{ppu entries}
  mainentryid         = 1;
  subentryid          = 2;
  {special}
  iberror             = 0;
  ibextraheader       = 242;
  ibpputable          = 243;
  ibstartrequireds    = 244;
  ibendrequireds      = 245;
  ibstartcontained    = 246;
  ibendcontained      = 247;
  ibstartdefs         = 248;
  ibenddefs           = 249;
  ibstartsyms         = 250;
  ibendsyms           = 251;
  ibendinterface      = 252;
  ibendimplementation = 253;
//  ibendbrowser        = 254;
  ibend               = 255;
  {general}
  ibmodulename           = 1;
  ibsourcefiles          = 2;
  ibloadunit             = 3;
  ibinitunit             = 4;
  iblinkunitofiles       = 5;
  iblinkunitstaticlibs   = 6;
  iblinkunitsharedlibs   = 7;
  iblinkotherofiles      = 8;
  iblinkotherstaticlibs  = 9;
  iblinkothersharedlibs  = 10;
  ibImportSymbols        = 11;
  ibsymref               = 12;
  ibdefref               = 13;
  ibfeatures             = 14;
{$IFDEF MACRO_DIFF_HINT}
  ibusedmacros           = 16;
{$ENDIF}
  ibderefdata            = 17;
  ibexportedmacros       = 18;
  ibderefmap             = 19;

  {syms}
  ibtypesym        = 20;
  ibprocsym        = 21;
  ibstaticvarsym   = 22;
  ibconstsym       = 23;
  ibenumsym        = 24;
//  ibtypedconstsym  = 25;
  ibabsolutevarsym = 26;
  ibpropertysym    = 27;
  ibfieldvarsym    = 28;
  ibunitsym        = 29;
  iblabelsym       = 30;
  ibsyssym         = 31;
  ibnamespacesym   = 32;
  iblocalvarsym    = 33;
  ibparavarsym     = 34;
  ibmacrosym       = 35;
  {definitions}
  iborddef         = 40;
  ibpointerdef     = 41;
  ibarraydef       = 42;
  ibprocdef        = 43;
  ibshortstringdef = 44;
  ibrecorddef      = 45;
  ibfiledef        = 46;
  ibformaldef      = 47;
  ibobjectdef      = 48;
  ibenumdef        = 49;
  ibsetdef         = 50;
  ibprocvardef     = 51;
  ibfloatdef       = 52;
  ibclassrefdef    = 53;
  iblongstringdef  = 54;
  ibansistringdef  = 55;
  ibwidestringdef  = 56;
  ibvariantdef     = 57;
  ibundefineddef   = 58;
  ibunicodestringdef = 59;
  {implementation/ObjData}
  ibnodetree       = 80;
  ibasmsymbols     = 81;
  ibresources      = 82;
  ibcreatedobjtypes = 83;
  ibwpofile         = 84;
  ibmoduleoptions   = 85;
  ibunitimportsyms  = 86;
  iborderedsymbols  = 87;
  ibunitexports    = 88;

  ibmainname       = 90;
  ibsymtableoptions = 91;
  ibpackagefiles   = 92;
  ibpackagename    = 93;
  ibrecsymtableoptions = 94;
  { target-specific things }
  iblinkotherframeworks = 100;
  ibjvmnamespace = 101;

{$ifdef generic_cpu}
{ We need to use the correct size of aint and pint for
  the target CPU }
const
  CpuAddrBitSize : array[0..MaxStoredCPUId] of LongInt =
    (
    {  0 } 32 {'none'},
    {  1 } 32 {'i386'},
    {  2 } 32 {'m68k'},
    {  3 } 32 {'alpha'},
    {  4 } 32 {'powerpc'},
    {  5 } 32 {'sparc'},
    {  6 } 32 {'vis'},
    {  7 } 64 {'ia64'},
    {  8 } 64 {'x86_64'},
    {  9 } 32 {'mipseb'},
    { 10 } 32 {'arm'},
    { 11 } 64 {'powerpc64'},
    { 12 } 16 {'avr'},
    { 13 } 32 {'mipsel'},
    { 14 } 32 {'jvm'},
    { 15 } 16 {'i8086'},
    { 16 } 64 {'aarch64'},
    { 17 } 32 {'wasm32'},
    { 18 } 64 {'sparc64'},
    { 19 } 32 {'riscv32'},
    { 20 } 64 {'riscv64'},
    { 21 } 32 {'xtensa'},
    { 22 } 16 {'z80'},
    { 23 } 64 {'mips64'},
    { 24 } 64 {'mips64el'},
    { 25 } 64 {'loongarch64'}
    );
  CpuAluBitSize : array[0..MaxStoredCPUId] of LongInt =
    (
    {  0 } 32 {'none'},
    {  1 } 32 {'i386'},
    {  2 } 32 {'m68k'},
    {  3 } 32 {'alpha'},
    {  4 } 32 {'powerpc'},
    {  5 } 32 {'sparc'},
    {  6 } 32 {'vis'},
    {  7 } 64 {'ia64'},
    {  8 } 64 {'x86_64'},
    {  9 } 32 {'mipseb'},
    { 10 } 32 {'arm'},
    { 11 } 64 {'powerpc64'},
    { 12 }  8 {'avr'},
    { 13 } 32 {'mipsel'},
    { 14 } 64 {'jvm'},
    { 15 } 16 {'i8086'},
    { 16 } 64 {'aarch64'},
    { 17 } 64 {'wasm32'},
    { 18 } 64 {'sparc64'},
    { 19 } 32 {'riscv32'},
    { 20 } 64 {'riscv64'},
    { 21 } 32 {'xtensa'},
    { 22 }  8 {'z80'},
    { 23 } 64 {'mips64'},
    { 24 } 64 {'mips64el'},
    { 25 } 64 {'loongarch64'}
    );
{$endif generic_cpu}

type
  { Compiler constants retain binary80 precision on every host and target. }

  { common part of the header for all kinds of entry files }
  TEntryHeader=record
    id       : array[1..3] of char;
    ver      : array[1..3] of char;
    compiler : word;
    cpu      : word;
    target   : word;
    flags    : dword;
    size     : dword; { size of the ppufile without header }
  end;
  PEntryHeader=^TEntryHeader;

  TEntry=packed record
    size : LongInt;
    id   : byte;
    nr   : byte;
  end;

  TEntryFile=class
  private
    FBuffer: TNXEntryBuffer;
    function getposition:LongInt;
    procedure setposition(value:LongInt);
  protected
    BufStart : integer;
    entrybufstart,
    entrystart,
    entryidx : integer;
    entry    : TEntry;
    closed,
    tempclosed : boolean;
    closepos : integer;
  protected
    f        : TCStream;
{$ifdef DEBUG_PPU}
    flog     : text;
    flog_open : boolean;
    ppu_log_level : LongInt;
    ppu_log_idx : integer;
{$endif}
{$ifdef CHECK_INPUTPOINTER_LIMITS}
    entryfilebufsize :LongInt;
{$endif CHECK_INPUTPOINTER_LIMITS}
    mode     : byte; {0 - Closed, 1 - Reading, 2 - Writing}
    fisfile  : boolean;
    fname    : string;
    fsize    : integer;
    procedure newheader;virtual;abstract;
    function readheader:LongInt;virtual;abstract;
    function outputallowed:boolean;virtual;
    procedure resetfile;virtual;abstract;
    function getheadersize:LongInt;virtual;abstract;
    function getheaderaddr:PEntryHeader;virtual;abstract;
    procedure RaiseAssertion(Code: LongInt); virtual;
    function BufferedPosition:LongInt;inline;
  public
    entrytyp : byte;
    size             : integer;
    ChangeEndian    : boolean; { Used in ppudump util }
{$ifdef generic_cpu}
    has_more,
{$endif not generic_cpu}
    error         : boolean;
    constructor create(const fn:string
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        ;aentryfilebufsize : LongInt = default_entryfilebufsize
{$endif CHECK_INPUTPOINTER_LIMITS}
	);
    destructor  Destroy;override;
    function getversion:integer;
    procedure flush; {$ifdef USEINLINE}inline;{$endif}
    procedure closefile;virtual;
    procedure newentry;
    property position:LongInt read getposition write setposition;
    { Warning: don't keep the stream open during a tempclose! }
    function substream(ofs,len:LongInt):TCStream;
    { Warning: don't use the put* or write* functions anymore when writing through this }
    property stream:TCStream read f;
{$ifdef DEBUG_PPU}
    procedure ppu_log(st :string);virtual;
    procedure ppu_log_val(st :string);virtual;
    procedure inc_log_level;
    procedure dec_log_level;
{$endif}
  {read}
    function  openfile:boolean;
    function  openstream(strm:TCStream):boolean;
    procedure reloadbuf;
    procedure readdata(out b;len:integer);
    procedure readdata(const b : TByteDynArray);
    procedure readdata(const b : TAnsiCharDynArray);
    procedure skipdata(len:integer);
    function  readentry:byte;
    function  EndOfEntry:boolean; {$ifdef USEINLINE}inline;{$endif}
    function  entrysize:LongInt; {$ifdef USEINLINE}inline;{$endif}
    function  entryleft:LongInt; {$ifdef USEINLINE}inline;{$endif}
    procedure getdatabuf(out b;len:integer;out res:integer);
    procedure getdata(out b;len:integer);
    procedure getdata(b : TByteDynArray);
    procedure getdata(b : TAnsiCharDynArray);
    function  getbyte:byte;
    function  getword:word;
    function  getdword:dword;
    function  getlongint:LongInt;
    function getint64:int64;
    function  getqword:qword;
    function getaint:{$ifdef generic_cpu}int64{$else}aint{$ifdef USEINLINE}; inline{$endif}{$endif};
    function getasizeint:{$ifdef generic_cpu}int64{$else}asizeint{$ifdef USEINLINE}; inline{$endif}{$endif};
    function getpuint:{$ifdef generic_cpu}qword{$else}PUint{$ifdef USEINLINE}; inline{$endif}{$endif};
    function getptruint:{$ifdef generic_cpu}qword{$else}TConstPtrUInt{$ifdef USEINLINE}; inline{$endif}{$endif};
    function getaword:{$ifdef generic_cpu}qword{$else}aword{$ifdef USEINLINE}; inline{$endif}{$endif};
    function  getreal:BestReal;
    function  getrealbytesize:byte;
    function  getboolean:boolean; {$ifdef USEINLINE}inline;{$endif}
    function  getstring:ShortString;
    function  getpshortstring:PShortString;
    function  getansistring:AnsiString;
    procedure getset(out arr: array of byte);
    function  skipuntilentry(untilb:byte):boolean;
  {write}
    function  createfile:boolean;virtual;
    function  createstream(strm:TCStream):boolean;
    procedure writeheader;virtual;abstract;
    procedure writebuf;
    procedure writedata(const b;len:integer);
    procedure writeentry(ibnr:byte);
    procedure putdata(const b;len:integer);virtual;
    procedure putbyte(b:byte); {$ifdef USEINLINE}inline;{$endif}
    procedure putword(w:word); {$ifdef USEINLINE}inline;{$endif}
    procedure putdword(w:dword); {$ifdef USEINLINE}inline;{$endif}
    procedure putlongint(l:LongInt); {$ifdef USEINLINE}inline;{$endif}
    procedure putint64(i:int64); {$ifdef USEINLINE}inline;{$endif}
    procedure putqword(q:qword); {$ifdef USEINLINE}inline;{$endif}
    procedure putaint(i:aint); {$ifdef USEINLINE}inline;{$endif}
    procedure putasizeint(i:asizeint); {$ifdef USEINLINE}inline;{$endif}
    procedure putpuint(i:PUint); {$ifdef USEINLINE}inline;{$endif}
    procedure putptruint(v:TConstPtrUInt); {$ifdef USEINLINE}inline;{$endif}
    procedure putaword(i:aword); {$ifdef USEINLINE}inline;{$endif}
    procedure putreal(d:BestReal);
    procedure putboolean(b:boolean); {$ifdef USEINLINE}inline;{$endif}
    procedure putstring(const s:ShortString); {$ifdef USEINLINE}inline;{$endif}
    procedure putansistring(const s:AnsiString);

    procedure putset(const arr: array of byte);
    procedure TempClose;        // MG: not used, obsolete?
    function  TempOpen:boolean; // MG: not used, obsolete?
  end;

implementation

  uses

    CUtils;


{*****************************************************************************
                              tentryfile
*****************************************************************************}

function TEntryFile.outputallowed: boolean;
begin
  result:=true;
end;


function TEntryFile.BufferedPosition: LongInt;
begin
  result:=BufStart+FBuffer.Position;
end;


constructor TEntryFile.create(const fn:string
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        ;aentryfilebufsize : LongInt = default_entryfilebufsize
{$endif CHECK_INPUTPOINTER_LIMITS}
	);
begin
  fname:=fn;
  fisfile:=false;
  ChangeEndian:=false;
  mode:=0;
  newheader;
  error:=false;
  closed:=true;
  tempclosed:=false;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
  entryfilebufsize:=aentryfilebufsize;
{$endif CHECK_INPUTPOINTER_LIMITS}
  FBuffer:=TNXEntryBuffer.Create(entryfilebufsize);
{$ifdef DEBUG_PPU}
  assign(flog,fn+'.debug-log');
  flog_open:=false;
{$endif DEBUG_PPU}
end;


destructor TEntryFile.Destroy;
begin
  closefile;
{$ifdef DEBUG_PPU}
  if flog_open then
    close(flog);
  flog_open:=false;
{$endif DEBUG_PPU}
  FBuffer.Free;
end;

{$ifdef DEBUG_PPU}

function entryid_name(nr : byte) : string;
begin
  case nr of
  {ppu entries}
  mainentryid: entryid_name:='main_entry_id';
  subentryid: entryid_name:='sub_entry_id';
  else
    entryid_name:='unknown entryid '+ToStr(nr);
  end;
end;

function entry_name(nr : byte) : string;
begin
  case nr of
  {special}
  iberror: entry_name:='iberror';
  ibextraheader: entry_name:='ibextraheader';
  ibpputable: entry_name:='ibpputable';
  ibstartrequireds: entry_name:='ibstartrequireds';
  ibendrequireds: entry_name:='ibendrequireds';
  ibstartcontained: entry_name:='ibstartcontained';
  ibendcontained: entry_name:='ibendcontained';
  ibstartdefs: entry_name:='ibstartdefs';
  ibenddefs: entry_name:='ibenddefs';
  ibstartsyms: entry_name:='ibstartsyms';
  ibendsyms: entry_name:='ibendsyms';
  ibendinterface: entry_name:='ibendinterface';
  ibendimplementation: entry_name:='ibendimplementation';
  // ibendbrowser: entry_name:='ibendbrowser';
  ibend: entry_name:='ibend';
  {general}
  ibmodulename: entry_name:='ibmodulename';
  ibsourcefiles: entry_name:='ibsourcefiles';
  ibloadunit: entry_name:='ibloadunit';
  ibinitunit: entry_name:='ibinitunit';
  iblinkunitofiles: entry_name:='iblinkunitofiles';
  iblinkunitstaticlibs: entry_name:='iblinkunitstaticlibs';
  iblinkunitsharedlibs: entry_name:='iblinkunitsharedlibs';
  iblinkotherofiles: entry_name:='iblinkotherofiles';
  iblinkotherstaticlibs: entry_name:='iblinkotherstaticlibs';
  iblinkothersharedlibs: entry_name:='iblinkothersharedlibs';
  ibImportSymbols: entry_name:='ibImportSymbols';
  ibsymref: entry_name:='ibsymref';
  ibdefref: entry_name:='ibdefref';
  ibfeatures: entry_name:='ibfeatures';
{$IFDEF MACRO_DIFF_HINT}
  ibusedmacros: entry_name:='ibusedmacros';
{$ENDIF}
  ibderefdata: entry_name:='ibderefdata';
  ibexportedmacros: entry_name:='ibexportedmacros';
  ibderefmap: entry_name:='ibderefmap';

  {syms}
  ibtypesym: entry_name:='ibtypesym';
  ibprocsym: entry_name:='ibprocsym';
  ibstaticvarsym: entry_name:='ibstaticvarsym';
  ibconstsym: entry_name:='ibconstsym';
  ibenumsym: entry_name:='ibenumsym';
  // ibtypedconstsym: entry_name:='ibtypedconstsym';
  ibabsolutevarsym: entry_name:='ibabsolutevarsym';
  ibpropertysym: entry_name:='ibpropertysym';
  ibfieldvarsym: entry_name:='ibfieldvarsym';
  ibunitsym: entry_name:='ibunitsym';
  iblabelsym: entry_name:='iblabelsym';
  ibsyssym: entry_name:='ibsyssym';
  ibnamespacesym: entry_name:='ibnamespacesym';
  iblocalvarsym: entry_name:='iblocalvarsym';
  ibparavarsym: entry_name:='ibparavarsym';
  ibmacrosym: entry_name:='ibmacrosym';
  {definitions}
  iborddef: entry_name:='iborddef';
  ibpointerdef: entry_name:='ibpointerdef';
  ibarraydef: entry_name:='ibarraydef';
  ibprocdef: entry_name:='ibprocdef';
  ibshortstringdef: entry_name:='ibshortstringdef';
  ibrecorddef: entry_name:='ibrecorddef';
  ibfiledef: entry_name:='ibfiledef';
  ibformaldef: entry_name:='ibformaldef';
  ibobjectdef: entry_name:='ibobjectdef';
  ibenumdef: entry_name:='ibenumdef';
  ibsetdef: entry_name:='ibsetdef';
  ibprocvardef: entry_name:='ibprocvardef';
  ibfloatdef: entry_name:='ibfloatdef';
  ibclassrefdef: entry_name:='ibclassrefdef';
  iblongstringdef: entry_name:='iblongstringdef';
  ibansistringdef: entry_name:='ibansistringdef';
  ibwidestringdef: entry_name:='ibwidestringdef';
  ibvariantdef: entry_name:='ibvariantdef';
  ibundefineddef: entry_name:='ibundefineddef';
  ibunicodestringdef: entry_name:='ibunicodestringdef';
  {implementation/ObjData}
  ibnodetree: entry_name:='ibnodetree';
  ibasmsymbols: entry_name:='ibasmsymbols';
  ibresources: entry_name:='ibresources';
  ibcreatedobjtypes: entry_name:='ibcreatedobjtypes';
  ibwpofile: entry_name:='ibwpofile';
  ibmoduleoptions: entry_name:='ibmoduleoptions';
  ibunitimportsyms: entry_name:='ibunitimportsyms';
  iborderedsymbols: entry_name:='iborderedsymbols';
  ibunitexports: entry_name:='ibunitexports';

  ibmainname: entry_name:='ibmainname';
  ibsymtableoptions: entry_name:='ibsymtableoptions';
  // ibrecsymtableoptions: entry_name:='ibrecsymtableoptions';
  ibpackagefiles: entry_name:='ibpackagefiles';
  ibpackagename: entry_name:='ibpackagename';
  { target-specific things }
  iblinkotherframeworks: entry_name:='iblinkotherframeworks';
  ibjvmnamespace: entry_name:='ibjvmnamespace';
  else
    entry_name:='unknown entry '+ToStr(nr);
  end;
end;

procedure TEntryFile.ppu_log(st :string);
begin
  if flog_open then
    begin
      WriteLn(flog,BufferedPosition,': ',st);
    end;
{$ifdef IN_PPUDUMP}
  WriteLn(BufferedPosition,': ',st);
{$endif}
end;

procedure TEntryFile.inc_log_level;
begin
  inc(ppu_log_level);
end;

procedure TEntryFile.ppu_log_val(st :string);
begin
  if flog_open then
    begin
      WriteLn(flog,'(',ppu_log_level,') value: ',st);
    end;
{$ifdef IN_PPUDUMP}
  WriteLn('(',ppu_log_level,') value: ',st);
{$endif}
end;

procedure TEntryFile.dec_log_level;
begin
  dec(ppu_log_level);
end;
{$endif}

function TEntryFile.getversion:integer;
  var
    l    : integer;
    code : integer;
    header : PEntryHeader;
  begin
    header:=getheaderaddr;
    Val(header^.ver[1]+header^.ver[2]+header^.ver[3],l,code);
    if code=0 then
     result:=l
    else
     result:=0;
  end;

procedure TEntryFile.flush;
begin
  if mode=2 then
   writebuf;
end;


procedure TEntryFile.RaiseAssertion(Code: LongInt);
begin
  { It's down to descendent classes to raise an internal error as desired. [Kit] }
  error := true;
end;


procedure TEntryFile.closefile;
begin
  if mode<>0 then
   begin
     flush;
{$ifdef DEBUG_PPU}
     if (entry.nr<>0) and (mode=1) then
       ppu_log('writeentry, id='+entryid_name(entry.id)+' nr='+entry_name(entry.nr)+' size='+ToStr(entry.size));
{$endif}
     if fisfile then
       f.Free;
       f := nil;
     mode:=0;
     closed:=true;
   end;
end;


procedure TEntryFile.setposition(value:LongInt);
begin
  if Assigned(f) then
    f.Position:=value
  else
    if tempclosed then
      closepos:=value;
end;


function TEntryFile.getposition:LongInt;
begin
  if Assigned(f) then
    result:=f.Position
  else
    if tempclosed then
      result:=closepos
    else
      result:=0;
end;


function TEntryFile.substream(ofs,len:LongInt):TCStream;
begin
  result:=nil;
  if Assigned(f) then
    result:=TCRangeStream.Create(f,ofs,len);
end;

{*****************************************************************************
                              tentryfile Reading
*****************************************************************************}

function TEntryFile.openfile:boolean;
var
  strm : TCStream;
begin
  openfile:=false;
  try
    strm:=CFileStreamClass.Create(fname,fmOpenRead)
  except
    exit;
  end;
  openfile:=openstream(strm);
  fisfile:=result;
end;


function TEntryFile.openstream(strm:TCStream):boolean;
var
  i : LongInt;
begin
  openstream:=false;
  f:=strm;
  closed:=false;
{$ifdef DEBUG_PPU}
  {$push}
  {$I-}
  assign(flog,fname+'.debug-read-log');
  rewrite(flog);
  if InOutRes=0 then
    flog_open:=true;
  {$pop}
{$endif DEBUG_PPU}
{read ppuheader}
  fsize:=f.Size;
  i:=readheader;
  if i<0 then
    exit;
{reset buffer}
  BufStart:=i;
  FBuffer.Reset;
  mode:=1;
  FillChar(entry,sizeof(TEntry),0);
  entryidx:=0;
  entrystart:=0;
  entrybufstart:=0;
  error:=false;
  openstream:=true;
end;


procedure TEntryFile.reloadbuf;
var
  RemainingSize: LongInt;
begin
  inc(BufStart,FBuffer.Size);
  RemainingSize:=fsize-BufStart;
  if RemainingSize<0 then
    RemainingSize:=0;
  FBuffer.LoadFromStream(f,RemainingSize);
end;


procedure TEntryFile.readdata(out b;len:integer);
var
  p : pchar;
  ReadCount : integer;
{$ifdef DEBUG_PPU}
  i, StartLength : integer;
  StartPointer : pchar;
{$endif DEBUG_PPU}
begin
  p:=pchar(@b);
{$ifdef DEBUG_PPU}
  StartPointer:=p;
  StartLength:=len;
{$endif DEBUG_PPU}
  while len>0 do
    begin
      ReadCount:=FBuffer.Read(p^,len);
      Dec(len,ReadCount);
      Inc(p,ReadCount);
      if len=0 then
        Break;
      ReloadBuf;
      if FBuffer.Size=0 then
        Exit;
    end;
{$ifdef DEBUG_PPU}
  if ppu_log_level <= 0 then
    begin
      ppu_log('readdata, length='+ToStr(StartLength)+' level='+ToStr(ppu_log_level));
      for i:=0 to StartLength-1 do
        ppu_log_val('p['+ToStr(i)+']=$'+HexStr(byte(StartPointer[i]),2));
    end;
{$endif DEBUG_PPU}
end;

procedure TEntryFile.readdata(const b: TByteDynArray);
begin
  ReadData(B[0],Length(B));
end;

procedure TEntryFile.readdata(const b: TAnsiCharDynArray);
begin
  ReadData(B[0],Length(B));
end;


procedure TEntryFile.skipdata(len:integer);
var
  left : integer;
begin
{$ifdef DEBUG_PPU}
  if len>0 then
    ppu_log('explicit skipdata '+ToStr(len));
{$endif}
  while len>0 do
   begin
     left:=FBuffer.Remaining;
     if len>left then
      begin
        dec(len,left);
        reloadbuf;
        if FBuffer.Size=0 then
         exit;
      end
     else
      begin
        FBuffer.Advance(len);
        exit;
      end;
   end;
end;


function TEntryFile.readentry:byte;
begin
  if entryidx<entry.size then
    begin
{$ifdef generic_cpu}
     has_more:=true;
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
     if entry.size-entryidx>0 then
       ppu_log('skipdata '+ToStr(entry.size-entryidx));
{$endif}
     skipdata(entry.size-entryidx);
    end;
{$ifdef DEBUG_PPU}
  if entry.nr<>0 then
    ppu_log('writeentry, id='+entryid_name(entry.id)+' nr='+entry_name(entry.nr)+' size='+ToStr(entry.size));
  ppu_log('entrystart');
{$endif}
  readdata(entry,sizeof(TEntry));
  if ChangeEndian then
    entry.size:=swapendian(entry.size);
  entrystart:=BufferedPosition;
  entryidx:=0;
{$ifdef generic_cpu}
  has_more:=false;
{$endif not generic_cpu}
  if not(entry.id in [mainentryid,subentryid]) then
   begin
     readentry:=iberror;
     error:=true;
     exit;
   end;
  readentry:=entry.nr;
end;


function TEntryFile.endofentry: boolean;
begin
{$ifdef generic_cpu}
  endofentry:=(entryidx=entry.size);
{$else not generic_cpu}
  endofentry:=(entryidx>=entry.size);
{$endif not generic_cpu}
end;


function TEntryFile.entrysize:LongInt;
begin
  entrysize:=entry.size;
end;

function TEntryFile.entryleft:LongInt;
begin
  entryleft:=entry.size-entryidx;
end;


procedure TEntryFile.getdatabuf(out b;len:integer;out res:integer);
begin
  if entryidx+len>entry.size then
   res:=entry.size-entryidx
  else
   res:=len;
  readdata(b,res);
  inc(entryidx,res);
end;


procedure TEntryFile.getdata(out b;len:integer);
begin
  if entryidx+len>entry.size then
   begin
     error:=true;
     exit;
   end;
  readdata(b,len);
  inc(entryidx,len);
end;

procedure TEntryFile.getdata(b: TByteDynArray);
begin
  if entryidx+Length(b)>entry.size then
   begin
     error:=true;
     exit;
   end;
  readdata(b);
  inc(entryidx,length(b));
end;

procedure TEntryFile.getdata(b: TAnsiCharDynArray);
begin
  if entryidx+Length(b)>entry.size then
   begin
     error:=true;
     exit;
   end;
  readdata(b);
  inc(entryidx,length(b));
end;


function TEntryFile.getbyte:byte;
begin
  if entryidx>=entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putbyte');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>0 then
    begin
      result:=PByte(FBuffer.Current)^;
      FBuffer.Advance(1);
    end
  else
    readdata(result,1);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx);
end;


function TEntryFile.getword:word;
begin
  if entryidx+2>entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putword');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>=sizeof(word) then
    begin
      result:=Unaligned(PWord(FBuffer.Current)^);
      FBuffer.Advance(sizeof(word));
    end
  else
    readdata(result,sizeof(word));
  if ChangeEndian then
   result:=swapendian(result);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx,2);
end;


function TEntryFile.getlongint:LongInt;
begin
  if entryidx+4>entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putlongint');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>=sizeof(LongInt) then
    begin
      result:=Unaligned(PLongInt(FBuffer.Current)^);
      FBuffer.Advance(sizeof(LongInt));
    end
  else
    readdata(result,sizeof(LongInt));
  if ChangeEndian then
   result:=swapendian(result);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx,4);
end;


function TEntryFile.getdword:dword;
begin
  if entryidx+4>entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putdword');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>=sizeof(dword) then
    begin
      result:=Unaligned(PDWord(FBuffer.Current)^);
      FBuffer.Advance(sizeof(dword));
    end
  else
    readdata(result,sizeof(dword));
  if ChangeEndian then
   result:=swapendian(result);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx,4);
end;


function TEntryFile.getint64:int64;
begin
  if entryidx+8>entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putint64');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>=sizeof(int64) then
    begin
      result:=Unaligned(PInt64(FBuffer.Current)^);
      FBuffer.Advance(sizeof(int64));
    end
  else
    readdata(result,sizeof(int64));
  if ChangeEndian then
   result:=swapendian(result);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx,8);
end;


function TEntryFile.getqword:qword;
begin
  if entryidx+8>entry.size then
   begin
     error:=true;
     result:=0;
     exit;
   end;
{$ifdef DEBUG_PPU}
  ppu_log('putqword');
  inc_log_level;
{$endif}
  if FBuffer.Remaining>=sizeof(qword) then
    begin
      result:=Unaligned(PQWord(FBuffer.Current)^);
      FBuffer.Advance(sizeof(qword));
    end
  else
    readdata(result,sizeof(qword));
  if ChangeEndian then
   result:=swapendian(result);
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
  inc(entryidx,8);
end;


function TEntryFile.getaint:{$ifdef generic_cpu}int64{$else}aint{$endif};
{$ifdef generic_cpu}
var
  header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef DEBUG_PPU}
  ppu_log('putaint');
  inc_log_level;
{$endif}
{$ifdef generic_cpu}
  header:=getheaderaddr;
  if CpuAluBitSize[header^.cpu]=64 then
    result:=getint64
  else if CpuAluBitSize[header^.cpu]=32 then
    result:=getlongint
  else if CpuAluBitSize[header^.cpu]=16 then
    result:=smallint(getword)
  else if CpuAluBitSize[header^.cpu]=8 then
    result:=shortint(getbyte)
  else
    begin
      error:=true;
      result:=0;
    end;
{$else not generic_cpu}
  case sizeof(aint) of
    8: result:=getint64;
    4: result:=getlongint;
    2: result:=smallint(getword);
    1: result:=shortint(getbyte);
  else
    begin
      RaiseAssertion(2019041801);
      result:=0;
    end;
  end;
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
end;


function TEntryFile.getasizeint:{$ifdef generic_cpu}int64{$else}asizeint{$endif};
{$ifdef generic_cpu}
var
  header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef DEBUG_PPU}
  ppu_log('putasizeint');
  inc_log_level;
{$endif}
{$ifdef generic_cpu}
  header:=getheaderaddr;
  if CpuAddrBitSize[header^.cpu]=64 then
    result:=getint64
  else if CpuAddrBitSize[header^.cpu]=32 then
    result:=getlongint
  else if CpuAddrBitSize[header^.cpu]=16 then
    begin
      { result:=smallint(getword);
        would have been logical, but it contradicts
	definition of asizeint in globtype unit,
	which uses 32-bit lngint type even for 16-bit
	address size, to be able to cope with
	I8086 seg:ofs huge addresses }
      result:=getlongint;
    end
  else
    begin
      error:=true;
      result:=0;
    end;
{$else not generic_cpu}
  case sizeof(asizeint) of
    8: result:=asizeint(getint64);
    4: result:=asizeint(getlongint);
    2: result:=asizeint(getword);
    1: result:=asizeint(getbyte);
  else
    begin
      RaiseAssertion(2019041802);
      result:=0;
    end;
  end;
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
end;


function TEntryFile.getpuint:{$ifdef generic_cpu}qword{$else}PUint{$endif};
{$ifdef generic_cpu}
var
header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef DEBUG_PPU}
  ppu_log('putpuint');
  inc_log_level;
{$endif}
{$ifdef generic_cpu}
  header:=getheaderaddr;
  if CpuAddrBitSize[header^.cpu]=64 then
    result:=getqword
  else if CpuAddrBitSize[header^.cpu]=32 then
    result:=getdword
  else if CpuAddrBitSize[header^.cpu]=16 then
    result:=getword
  else
    begin
      error:=true;
      result:=0;
    end;
{$else not generic_cpu}
  case sizeof(PUint) of
    8: result:=getqword;
    4: result:=getdword;
    2: result:=getword;
    1: result:=getbyte;
  else
    begin
      RaiseAssertion(2019041803);
      result:=0;
    end;
  end;
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
end;


function TEntryFile.getptruint:{$ifdef generic_cpu}qword{$else}TConstPtrUInt{$endif};
{$ifdef generic_cpu}
var
header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef DEBUG_PPU}
  ppu_log('putptruint');
  inc_log_level;
{$endif}
{$ifdef generic_cpu}
  header:=getheaderaddr;
  if CpuAddrBitSize[header^.cpu]=64 then
    result:=getqword
  else result:=getdword;
{$else not generic_cpu}
  {$ifdef cpu64bitaddr}
  result:=TConstPtrUInt(getint64);
  {$else}
  result:=TConstPtrUInt(getlongint);
  {$endif}
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
end;


function TEntryFile.getaword:{$ifdef generic_cpu}qword{$else}aword{$endif};
{$ifdef generic_cpu}
var
header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef DEBUG_PPU}
  ppu_log('putaword');
  inc_log_level;
{$endif}
{$ifdef generic_cpu}
  header:=getheaderaddr;
  if CpuAluBitSize[header^.cpu]=64 then
    result:=getqword
  else if CpuAluBitSize[header^.cpu]=32 then
    result:=getdword
  else if CpuAluBitSize[header^.cpu]=16 then
    result:=getword
  else if CpuAluBitSize[header^.cpu]=8 then
    result:=getbyte
  else
    begin
      error:=true;
      result:=0;
    end;
{$else not generic_cpu}
  case sizeof(aword) of
    8: result:=getqword;
    4: result:=getdword;
    2: result:=getword;
    1: result:=getbyte;
  else
    begin
      RaiseAssertion(2019041804);
      result:=0;
    end;
  end;
{$endif not generic_cpu}
{$ifdef DEBUG_PPU}
  ppu_log_val(ToStr(result));
  dec_log_level;
{$endif}
end;



function TEntryFile.getreal:BestReal;
var
  lDouble: TDoubleRec;
{$ifdef FPC_HAS_TYPE_EXTENDED}
  lExtended: TExtended80Rec;
{$endif}
begin
  if getrealbytesize=8 then
    begin
      lDouble:=TDoubleRec(getqword);
      Result:=lDouble.Value;
    end
  else
    begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
      lExtended.Frac:=getqword;
      lExtended._Exp:=getword;
      Result:=lExtended.Value;
{$else}
      { An ARM host cannot consume an x86 unit's real constants. }
      error:=true;
      Result:=0;
{$endif}
    end;
end;

function TEntryFile.getrealbytesize:byte;
begin
  if TargetInfo.cpu in [cpu_i386,cpu_x86_64] then
    Result:=10
  else
    Result:=8;
end;

function TEntryFile.getboolean:boolean;
begin
{$ifdef DEBUG_PPU}
  ppu_log('putboolean');
{$endif}
  result:=boolean(getbyte);
end;


function TEntryFile.getstring:ShortString;
begin
  result[0]:=chr(getbyte);
{$ifdef DEBUG_PPU}
  ppu_log('putstring,size='+ToStr(length(result)+1));
  inc_log_level;
{$endif}
  if entryidx+length(result)>entry.size then
   begin
     error:=true;
     exit;
   end;
  ReadData(result[1],length(result));
{$ifdef DEBUG_PPU}
  ppu_log_val(result);
  dec_log_level;
{$endif}
  inc(entryidx,length(result));
end;

function TEntryFile.getpshortstring:PShortString;
var
  len: char;
begin
  result:=nil;
  len:=chr(getbyte);
{$ifdef DEBUG_PPU}
  ppu_log('putstring,size='+ToStr(ord(len)+1));
  inc_log_level;
{$endif}
  if entryidx+ord(len)>entry.size then
   begin
     error:=true;
     exit;
   end;
  GetMem(result,ord(len)+1);
  result^[0]:=len;
  ReadData(result^[1],ord(len));
  inc(entryidx,ord(len));
{$ifdef DEBUG_PPU}
  ppu_log_val(result^);
  dec_log_level;
{$endif}
end;

function TEntryFile.getansistring:AnsiString;
var
  len: LongInt;
begin
{$ifdef DEBUG_PPU}
  ppu_log('putansistring');
  inc_log_level;
{$endif}
  len:=getlongint;
  if entryidx+len>entry.size then
   begin
     error:=true;
     result:='';
     exit;
   end;
  SetLength(result,len);
  if len>0 then
    getdata(result[1],len);
{$ifdef DEBUG_PPU}
  ppu_log_val(result);
  dec_log_level;
{$endif}
end;


procedure TEntryFile.getset(out arr: array of byte);
var
  i : LongInt;
begin
{$ifdef DEBUG_PPU}
  ppu_log('putset');
  inc_log_level;
{$endif}
  getdata(arr,sizeof(arr));
  if ChangeEndian then
    for i:=low(arr) to high(arr) do
      arr[i]:=Reverse_Byte(arr[i]);
{$ifdef DEBUG_PPU}
  for i:=low(arr) to high(arr) do
    ppu_log_val('byte['+ToStr(i)+']=$'+HexStr(arr[i],2));
  dec_log_level;
{$endif}
end;


function TEntryFile.skipuntilentry(untilb:byte):boolean;
var
  b : byte;
begin
{$ifdef DEBUG_PPU}
  ppu_log('skipuntilentry '+ToStr(untilb));
{$endif}
  repeat
    b:=readentry;
  until (b in [ibend,iberror]) or ((b=untilb) and (entry.id=mainentryid));
  skipuntilentry:=(b=untilb);
end;


{*****************************************************************************
                              tentryfile Writing
*****************************************************************************}

function TEntryFile.createfile:boolean;
var
  ok: boolean;
  strm : TCStream;
begin
  createfile:=false;
  strm:=nil;
  if outputallowed then
    begin
      ok:=false;
      try
        strm:=CFileStreamClass.Create(fname,fmCreate);
        ok:=true;
      except
      end;
      if not ok then
       exit;
    end;
  createfile:=createstream(strm);
  fisfile:=result;
end;

function TEntryFile.createstream(strm:TCStream):boolean;
begin
  createstream:=false;
  if outputallowed then
    begin
      f:=strm;
      mode:=2;
      {write header for sure}
      f.Write(getheaderaddr^,getheadersize);
    end;
  BufStart:=getheadersize;
  FBuffer.Reset;
{reset}
  resetfile;
  error:=false;
  size:=0;
  entrytyp:=mainentryid;
{$ifdef DEBUG_PPU}
  {$push}
  {$I-}
  assign(flog,fname+'.debug-write-log');
  rewrite(flog);
  if InOutRes=0 then
    flog_open:=true;
  {$pop}
{$endif DEBUG_PPU}
{start}
  newentry;
  createstream:=true;
end;


procedure TEntryFile.writebuf;
begin
  if outputallowed and
     (FBuffer.Size <> 0) then
    FBuffer.SaveToStream(f);
  inc(BufStart,FBuffer.Size);
  FBuffer.Reset;
end;


procedure TEntryFile.writedata(const b;len:integer);
{$ifdef DEBUG_PPU}
var
  idx : integer;
{$endif}
begin
  if not outputallowed then
    exit;
  FBuffer.Write(b,len);
{$ifdef DEBUG_PPU}
  if (len > 0) and (ppu_log_level <= 0) then
    begin
      ppu_log('writedata, length='+ToStr(len)+' level='+ToStr(ppu_log_level));
      for idx:=0 to len-1 do
        ppu_log_val('p['+ToStr(idx)+']=$'+HexStr(PByte(PtrUInt(@b)+PtrUInt(idx))^,2));
    end;
{$endif DEBUG_PPU}
end;


procedure TEntryFile.newentry;
begin
  with entry do
   begin
     id:=entrytyp;
     nr:=ibend;
     size:=0;
   end;
{Reset Entry State}
  entryidx:=0;
  entrybufstart:=BufStart;
  entrystart:=BufferedPosition;
{$ifdef DEBUG_PPU}
  ppu_log('entrystart');
{$endif}
{Alloc in buffer}
  writedata(entry,sizeof(TEntry));
end;


procedure TEntryFile.writeentry(ibnr:byte);
var
  opos : integer;
begin
{create entry}
  entry.id:=entrytyp;
  entry.nr:=ibnr;
  entry.size:=entryidx;
{it's already been sent to disk ?}
  if entrybufstart<>BufStart then
   begin
    if outputallowed then
      begin
      {flush to be sure}
        WriteBuf;
      {write entry}
        opos:=f.Position;
        f.Position:=entrystart;
        f.write(entry,sizeof(TEntry));
        f.Position:=opos;
      end;
     entrybufstart:=BufStart;
   end
  else
   FBuffer.Patch(entrystart-BufStart,entry,sizeof(entry));
{$ifdef DEBUG_PPU}
  ppu_log('writeentry, id='+entryid_name(entry.id)+' nr='+entry_name(entry.nr)+' size='+ToStr(entry.size));
{$endif}
{Add New Entry, which is ibend by default}
  entrystart:=BufferedPosition; {next entry position}
  newentry;
end;


procedure TEntryFile.putdata(const b;len:integer);
begin
  if outputallowed then
    FBuffer.Write(b,len);
  inc(entryidx,len);
end;


procedure TEntryFile.putbyte(b:byte);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putbyte');
  inc_log_level;
  ppu_log_val(ToStr(b));
{$endif}
  putdata(b,1);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putword(w:word);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putword');
  inc_log_level;
  ppu_log_val(ToStr(w));
{$endif}
  putdata(w,2);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putdword(w:dword);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putdword');
  inc_log_level;
  ppu_log_val(ToStr(w));
{$endif}
  putdata(w,4);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putlongint(l:LongInt);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putlongint');
  inc_log_level;
  ppu_log_val(ToStr(l));
{$endif}
  putdata(l,4);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putint64(i:int64);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putint64');
  inc_log_level;
  ppu_log_val(ToStr(i));
{$endif}
  putdata(i,8);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putqword(q:qword);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putqword');
  inc_log_level;
  ppu_log_val(ToStr(q));
{$endif}
  putdata(q,sizeof(qword));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putaint(i:aint);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putaint');
  inc_log_level;
  case sizeof(aint) of
    8: ppu_log('putint64');
    4: ppu_log('putlongint');
    2: ppu_log('putword');
    1: ppu_log('putbyte');
  end;
  ppu_log_val(ToStr(i));
{$endif}
  putdata(i,sizeof(aint));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putasizeint(i: asizeint);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putasizeint');
  inc_log_level;
  case sizeof(asizeint) of
    8: ppu_log('putint64');
    4: ppu_log('putlongint');
    2: ppu_log('putword');
    1: ppu_log('putbyte');
  end;
  ppu_log_val(ToStr(i));
{$endif}
  putdata(i,sizeof(asizeint));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putpuint(i : PUint);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putpuint');
  inc_log_level;
  ppu_log_val(ToStr(i));
{$endif}
  putdata(i,sizeof(PUint));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;

procedure TEntryFile.putptruint(v:TConstPtrUInt);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putptruint');
  inc_log_level;
{$endif}
  {$ifdef cpu64bitaddr}
  putint64(int64(v));
  {$else}
  putlongint(LongInt(v));
  {$endif}
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;




procedure TEntryFile.putaword(i:aword);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putaword');
  inc_log_level;
  ppu_log_val(ToStr(i));
{$endif}
  putdata(i,sizeof(aword));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putreal(d:BestReal);
var
  lDouble: TDoubleRec;
begin
  if getrealbytesize=8 then
    begin
      lDouble.Value:=d;
      putqword(QWord(lDouble));
    end
  else
    begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
      putqword(TExtended80Rec(d).Frac);
      putword(TExtended80Rec(d)._Exp);
{$else}
      InternalErrorProc(2026101101);
{$endif}
    end;
end;

procedure TEntryFile.putboolean(b:boolean);
begin
{$ifdef DEBUG_PPU}
  ppu_log('putboolean');
  inc_log_level;
{$endif}
  putbyte(byte(b));
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putstring(const s:ShortString);
begin
{$ifdef DEBUG_PPU}
  { The reading method uses getbyte, so fake it here }
  ppu_log('putbyte');
  inc_log_level;
  FBuffer.Advance(1);
  ppu_log('putstring,size='+ToStr(length(s)+1));
  FBuffer.Retreat(1);
  ppu_log_val(s);
{$endif}
  putdata(s,length(s)+1);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
end;


procedure TEntryFile.putansistring(const s:AnsiString);
  var
    len: LongInt;
  begin
    len:=length(s);
{$ifdef DEBUG_PPU}
  ppu_log('putansistring');
  inc_log_level;
  ppu_log_val(s);
{$endif}
    putlongint(len);
    if len>0 then
      putdata(s[1],len);
{$ifdef DEBUG_PPU}
  dec_log_level;
{$endif}
  end;


procedure TEntryFile.putset(const arr: array of byte);
{$ifdef DEBUG_PPU}
  var
    i : byte;
{$endif}
  begin
{$ifdef DEBUG_PPU}
  ppu_log('putset');
  inc_log_level;
{$endif}
    putdata(arr,sizeof(arr));
{$ifdef DEBUG_PPU}
  for i:=0 to sizeof(arr)-1 do
    ppu_log_val('byte['+ToStr(i)+']=$'+HexStr(arr[i],2));
  dec_log_level;
{$endif}
  end;


procedure TEntryFile.TempClose;
  begin
    if not closed then
     begin
       closepos:=f.Position;
       f.Free;
       f:=nil;
       closed:=true;
       tempclosed:=true;
     end;
  end;


function TEntryFile.TempOpen:boolean;
  begin
    TempOpen:=false;
    if not closed or not tempclosed then
     exit;
   { MG: not sure, if this is correct
     f.position:=0;
       No, f was freed in tempclose above, we need to
       recreate it.  PM 2011/06/06 }
    try
      f:=CFileStreamClass.Create(fname,fmOpenRead);
    except
      exit;
    end;
    closed:=false;
    tempclosed:=false;

  { restore state }
    f.Position:=closepos;
    TempOpen:=true;
  end;

end.
