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
  MaxEntrySize = 1024;
  // Unused, and wrong as there are entries that are larger then 1024 bytes

{$ifdef CHECK_INPUTPOINTER_LIMITS}
  DefaultEntryFileBufSize   = 16384;
{$else not CHECK_INPUTPOINTER_LIMITS}
  EntryFileBufSize   = 16384;
{$endif CHECK_INPUTPOINTER_LIMITS}

{ppu entries}
  MainEntryID         = 1;
  SubEntryID          = 2;
  {special}
  IBError             = 0;
  IBExtraHeader       = 242;
  IBPPUTable          = 243;
  IBStartRequireds    = 244;
  IBEndRequireds      = 245;
  IBStartContained    = 246;
  IBEndContained      = 247;
  IBStartDefs         = 248;
  IBEndDefs           = 249;
  IBStartSyms         = 250;
  IBEndSyms           = 251;
  IBEndInterface      = 252;
  IBEndImplementation = 253;
//  ibendbrowser        = 254;
  IBEnd               = 255;
  {general}
  IBModuleName           = 1;
  IBSourceFiles          = 2;
  IBLoadUnit             = 3;
  IBInitUnit             = 4;
  IBLinkUnitOFiles       = 5;
  IBLinkUnitStaticLibs   = 6;
  IBLinkUnitSharedLibs   = 7;
  IBLinkOtherOFiles      = 8;
  IBLinkOtherStaticLibs  = 9;
  IBLinkOtherSharedLibs  = 10;
  IBImportSymbols        = 11;
  IBSymRef               = 12;
  IBDefRef               = 13;
  IBFeatures             = 14;
{$IFDEF MACRO_DIFF_HINT}
  IBUsedMacros           = 16;
{$ENDIF}
  IBDerefData            = 17;
  IBExportedMacros       = 18;
  IBDerefMap             = 19;

  {syms}
  IBTypeSym        = 20;
  IBProcSym        = 21;
  IBStaticVarSym   = 22;
  IBConstSym       = 23;
  IBEnumSym        = 24;
//  ibtypedconstsym  = 25;
  IBAbsoluteVarSym = 26;
  IBPropertySym    = 27;
  IBFieldVarSym    = 28;
  IBUnitSym        = 29;
  IBLabelSym       = 30;
  IBSysSym         = 31;
  IBNamespaceSym   = 32;
  IBLocalVarSym    = 33;
  IBParaVarSym     = 34;
  IBMacroSym       = 35;
  {definitions}
  IBOrdDef         = 40;
  IBPointerDef     = 41;
  IBArrayDef       = 42;
  IBProcDef        = 43;
  IBShortStringDef = 44;
  IBRecordDef      = 45;
  IBFileDef        = 46;
  IBFormalDef      = 47;
  IBObjectDef      = 48;
  IBEnumDef        = 49;
  IBSetDef         = 50;
  IBProcVarDef     = 51;
  IBFloatDef       = 52;
  IBClassRefDef    = 53;
  IBLongStringDef  = 54;
  IBAnsiStringDef  = 55;
  IBWideStringDef  = 56;
  IBVariantDef     = 57;
  IBUndefinedDef   = 58;
  IBUnicodeStringDef = 59;
  {implementation/ObjData}
  IBNodeTree       = 80;
  IBAsmSymbols     = 81;
  IBResources      = 82;
  IBCreatedObjTypes = 83;
  IBWPOFile         = 84;
  IBModuleOptions   = 85;
  IBUnitImportSyms  = 86;
  IBOrderedSymbols  = 87;
  IBUnitExports    = 88;

  IBMainName       = 90;
  IBSymTableOptions = 91;
  IBPackageFiles   = 92;
  IBPackageName    = 93;
  IBRecSymTableOptions = 94;
  { target-specific things }
  IBLinkOtherFrameworks = 100;

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
    ID       : array[1..3] of Char;
    Ver      : array[1..3] of Char;
    Compiler : Word;
    CPU      : Word;
    Target   : Word;
    Flags    : DWord;
    Size     : DWord; { size of the ppufile without header }
  end;
  PEntryHeader=^TEntryHeader;

  TEntry=packed record
    Size : LongInt;
    ID   : Byte;
    NR   : Byte;
  end;

  TEntryFile=class
  private
    FBuffer: TNXEntryBuffer;
    function GetPosition:LongInt;
    procedure SetPosition(AValue:LongInt);
  protected
    BufStart : Integer;
    EntryBufStart,
    EntryStart,
    EntryIdx : Integer;
    Entry    : TEntry;
  protected
    F        : TCStream;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
    EntryFileBufSize :LongInt;
{$endif CHECK_INPUTPOINTER_LIMITS}
    Mode     : Byte; {0 - Closed, 1 - Reading, 2 - Writing}
    FIsFile  : Boolean;
    FName    : string;
    FSize    : Integer;
    procedure NewHeader;virtual;abstract;
    function ReadHeader:LongInt;virtual;abstract;
    function OutputAllowed:Boolean;virtual;
    procedure ResetFile;virtual;abstract;
    function GetHeaderSize:LongInt;virtual;abstract;
    function GetHeaderAddr:PEntryHeader;virtual;abstract;
    procedure RaiseAssertion(Code: LongInt); virtual;
    function BufferedPosition:LongInt;inline;
  public
    EntryTyp : Byte;
    Size             : Integer;
{$ifdef generic_cpu}
    HasMore,
{$endif not generic_cpu}
    Error         : Boolean;
    constructor Create(const FN:string
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        ;AEntryFileBufSize : LongInt = DefaultEntryFileBufSize
{$endif CHECK_INPUTPOINTER_LIMITS}
	);
    destructor  Destroy;override;
    function GetVersion:Integer;
    procedure Flush; {$ifdef USEINLINE}inline;{$endif}
    procedure CloseFile;virtual;
    procedure NewEntry;
    property Position:LongInt read GetPosition write SetPosition;
    function SubStream(Ofs,Len:LongInt):TCStream;
    { Warning: don't use the put* or write* functions anymore when writing through this }
    property Stream:TCStream read F;
  {read}
    function  OpenFile:Boolean;
    function  OpenStream(Strm:TCStream):Boolean;
    procedure ReloadBuf;
    procedure ReadData(out B;Len:Integer);
    procedure ReadData(const B : TByteDynArray);
    procedure ReadData(const B : TAnsiCharDynArray);
    procedure SkipData(Len:Integer);
    function  ReadEntry:Byte;
    function  EndOfEntry:Boolean; {$ifdef USEINLINE}inline;{$endif}
    function  EntrySize:LongInt; {$ifdef USEINLINE}inline;{$endif}
    function  EntryLeft:LongInt; {$ifdef USEINLINE}inline;{$endif}
    procedure GetDataBuf(out B;Len:Integer;out Res:Integer);
    procedure GetData(out B;Len:Integer);
    procedure GetData(B : TByteDynArray);
    procedure GetData(B : TAnsiCharDynArray);
    function  GetByte:Byte;
    function  GetWord:Word;
    function  GetDWord:DWord;
    function  GetLongInt:LongInt;
    function GetInt64:Int64;
    function  GetQWord:QWord;
    function GetAInt:{$ifdef generic_cpu}Int64{$else}AInt{$ifdef USEINLINE}; inline{$endif}{$endif};
    function GetASizeInt:{$ifdef generic_cpu}Int64{$else}ASizeInt{$ifdef USEINLINE}; inline{$endif}{$endif};
    function GetPUInt:{$ifdef generic_cpu}QWord{$else}PUint{$ifdef USEINLINE}; inline{$endif}{$endif};
    function GetPtrUInt:{$ifdef generic_cpu}QWord{$else}TConstPtrUInt{$ifdef USEINLINE}; inline{$endif}{$endif};
    function GetAWord:{$ifdef generic_cpu}QWord{$else}AWord{$ifdef USEINLINE}; inline{$endif}{$endif};
    function  GetReal:BestReal;
    function  GetRealByteSize:Byte;
    function  GetBoolean:Boolean; {$ifdef USEINLINE}inline;{$endif}
    function  GetString:ShortString;
    function  GetPShortString:PShortString;
    function  GetAnsiString:AnsiString;
    procedure GetSet(out Arr: array of Byte);
    function  SkipUntilEntry(UntilB:Byte):Boolean;
  {write}
    function  CreateFile:Boolean;virtual;
    function  CreateStream(Strm:TCStream):Boolean;
    procedure WriteHeader;virtual;abstract;
    procedure WriteBuf;
    procedure WriteData(const B;Len:Integer);
    procedure WriteEntry(IBNR:Byte);
    procedure PutData(const B;Len:Integer);virtual;
    procedure PutByte(B:Byte); {$ifdef USEINLINE}inline;{$endif}
    procedure PutWord(W:Word); {$ifdef USEINLINE}inline;{$endif}
    procedure PutDWord(W:DWord); {$ifdef USEINLINE}inline;{$endif}
    procedure PutLongInt(L:LongInt); {$ifdef USEINLINE}inline;{$endif}
    procedure PutInt64(I:Int64); {$ifdef USEINLINE}inline;{$endif}
    procedure PutQWord(Q:QWord); {$ifdef USEINLINE}inline;{$endif}
    procedure PutAInt(I:AInt); {$ifdef USEINLINE}inline;{$endif}
    procedure PutASizeInt(I:ASizeInt); {$ifdef USEINLINE}inline;{$endif}
    procedure PutPUInt(I:PUint); {$ifdef USEINLINE}inline;{$endif}
    procedure PutPtrUInt(V:TConstPtrUInt); {$ifdef USEINLINE}inline;{$endif}
    procedure PutAWord(I:AWord); {$ifdef USEINLINE}inline;{$endif}
    procedure PutReal(D:BestReal);
    procedure PutBoolean(B:Boolean); {$ifdef USEINLINE}inline;{$endif}
    procedure PutString(const S:ShortString); {$ifdef USEINLINE}inline;{$endif}
    procedure PutAnsiString(const S:AnsiString);

    procedure PutSet(const Arr: array of Byte);
  end;

implementation

  uses

    CUtils;


{*****************************************************************************
                              tentryfile
*****************************************************************************}

function TEntryFile.OutputAllowed: Boolean;
begin
  Result:=True;
end;


function TEntryFile.BufferedPosition: LongInt;
begin
  Result:=BufStart+FBuffer.Position;
end;


constructor TEntryFile.Create(const FN:string
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        ;AEntryFileBufSize : LongInt = DefaultEntryFileBufSize
{$endif CHECK_INPUTPOINTER_LIMITS}
	);
begin
  FName:=FN;
  FIsFile:=False;
  Mode:=0;
  NewHeader;
  Error:=False;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
  EntryFileBufSize:=AEntryFileBufSize;
{$endif CHECK_INPUTPOINTER_LIMITS}
  FBuffer:=TNXEntryBuffer.Create(EntryFileBufSize);
end;


destructor TEntryFile.Destroy;
begin
  CloseFile;
  FBuffer.Free;
end;


function TEntryFile.GetVersion:Integer;
  var
    L    : Integer;
    Code : Integer;
    Header : PEntryHeader;
  begin
    Header:=GetHeaderAddr;
    Val(Header^.Ver[1]+Header^.Ver[2]+Header^.Ver[3],L,Code);
    if Code=0 then
     Result:=L
    else
     Result:=0;
  end;

procedure TEntryFile.Flush;
begin
  if Mode=2 then
   WriteBuf;
end;


procedure TEntryFile.RaiseAssertion(Code: LongInt);
begin
  { It's down to descendent classes to raise an internal error as desired. [Kit] }
  Error := True;
end;


procedure TEntryFile.CloseFile;
begin
  if Mode<>0 then
   begin
     Flush;
     if FIsFile then
       F.Free;
       F := nil;
     Mode:=0;
   end;
end;


procedure TEntryFile.SetPosition(AValue:LongInt);
begin
  if Assigned(F) then
    F.Position:=AValue;
end;


function TEntryFile.GetPosition:LongInt;
begin
  if Assigned(F) then
    Result:=F.Position
  else
    Result:=0;
end;


function TEntryFile.SubStream(Ofs,Len:LongInt):TCStream;
begin
  Result:=nil;
  if Assigned(F) then
    Result:=TCRangeStream.Create(F,Ofs,Len);
end;

{*****************************************************************************
                              tentryfile Reading
*****************************************************************************}

function TEntryFile.OpenFile:Boolean;
var
  Strm : TCStream;
begin
  OpenFile:=False;
  try
    Strm:=CFileStreamClass.Create(FName,fmOpenRead)
  except
    Exit;
  end;
  OpenFile:=OpenStream(Strm);
  FIsFile:=Result;
end;


function TEntryFile.OpenStream(Strm:TCStream):Boolean;
var
  I : LongInt;
begin
  OpenStream:=False;
  F:=Strm;
{read ppuheader}
  FSize:=F.Size;
  I:=ReadHeader;
  if I<0 then
    Exit;
{reset buffer}
  BufStart:=I;
  FBuffer.Reset;
  Mode:=1;
  FillChar(Entry,SizeOf(TEntry),0);
  EntryIdx:=0;
  EntryStart:=0;
  EntryBufStart:=0;
  Error:=False;
  OpenStream:=True;
end;


procedure TEntryFile.ReloadBuf;
var
  RemainingSize: LongInt;
begin
  Inc(BufStart,FBuffer.Size);
  RemainingSize:=FSize-BufStart;
  if RemainingSize<0 then
    RemainingSize:=0;
  FBuffer.LoadFromStream(F,RemainingSize);
end;


procedure TEntryFile.ReadData(out B;Len:Integer);
var
  P : PChar;
  ReadCount : Integer;
begin
  P:=PChar(@B);
  while Len>0 do
    begin
      ReadCount:=FBuffer.Read(P^,Len);
      Dec(Len,ReadCount);
      Inc(P,ReadCount);
      if Len=0 then
        Break;
      ReloadBuf;
      if FBuffer.Size=0 then
        Exit;
    end;
end;

procedure TEntryFile.ReadData(const B: TByteDynArray);
begin
  ReadData(B[0],Length(B));
end;

procedure TEntryFile.ReadData(const B: TAnsiCharDynArray);
begin
  ReadData(B[0],Length(B));
end;


procedure TEntryFile.SkipData(Len:Integer);
var
  Left : Integer;
begin
  while Len>0 do
   begin
     Left:=FBuffer.Remaining;
     if Len>Left then
      begin
        Dec(Len,Left);
        ReloadBuf;
        if FBuffer.Size=0 then
         Exit;
      end
     else
      begin
        FBuffer.Advance(Len);
        Exit;
      end;
   end;
end;


function TEntryFile.ReadEntry:Byte;
begin
  if EntryIdx<Entry.Size then
    begin
{$ifdef generic_cpu}
     HasMore:=True;
{$endif not generic_cpu}
     SkipData(Entry.Size-EntryIdx);
    end;
  ReadData(Entry,SizeOf(TEntry));
  EntryStart:=BufferedPosition;
  EntryIdx:=0;
{$ifdef generic_cpu}
  HasMore:=False;
{$endif not generic_cpu}
  if not(Entry.ID in [MainEntryID,SubEntryID]) then
   begin
     ReadEntry:=IBError;
     Error:=True;
     Exit;
   end;
  ReadEntry:=Entry.NR;
end;


function TEntryFile.EndOfEntry: Boolean;
begin
{$ifdef generic_cpu}
  EndOfEntry:=(EntryIdx=Entry.Size);
{$else not generic_cpu}
  EndOfEntry:=(EntryIdx>=Entry.Size);
{$endif not generic_cpu}
end;


function TEntryFile.EntrySize:LongInt;
begin
  EntrySize:=Entry.Size;
end;

function TEntryFile.EntryLeft:LongInt;
begin
  EntryLeft:=Entry.Size-EntryIdx;
end;


procedure TEntryFile.GetDataBuf(out B;Len:Integer;out Res:Integer);
begin
  if EntryIdx+Len>Entry.Size then
   Res:=Entry.Size-EntryIdx
  else
   Res:=Len;
  ReadData(B,Res);
  Inc(EntryIdx,Res);
end;


procedure TEntryFile.GetData(out B;Len:Integer);
begin
  if EntryIdx+Len>Entry.Size then
   begin
     Error:=True;
     Exit;
   end;
  ReadData(B,Len);
  Inc(EntryIdx,Len);
end;

procedure TEntryFile.GetData(B: TByteDynArray);
begin
  if EntryIdx+Length(B)>Entry.Size then
   begin
     Error:=True;
     Exit;
   end;
  ReadData(B);
  Inc(EntryIdx,Length(B));
end;

procedure TEntryFile.GetData(B: TAnsiCharDynArray);
begin
  if EntryIdx+Length(B)>Entry.Size then
   begin
     Error:=True;
     Exit;
   end;
  ReadData(B);
  Inc(EntryIdx,Length(B));
end;


function TEntryFile.GetByte:Byte;
begin
  if EntryIdx>=Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>0 then
    begin
      Result:=PByte(FBuffer.Current)^;
      FBuffer.Advance(1);
    end
  else
    ReadData(Result,1);
  Inc(EntryIdx);
end;


function TEntryFile.GetWord:Word;
begin
  if EntryIdx+2>Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>=SizeOf(Word) then
    begin
      Result:=Unaligned(PWord(FBuffer.Current)^);
      FBuffer.Advance(SizeOf(Word));
    end
  else
    ReadData(Result,SizeOf(Word));
  Inc(EntryIdx,2);
end;


function TEntryFile.GetLongInt:LongInt;
begin
  if EntryIdx+4>Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>=SizeOf(LongInt) then
    begin
      Result:=Unaligned(PLongInt(FBuffer.Current)^);
      FBuffer.Advance(SizeOf(LongInt));
    end
  else
    ReadData(Result,SizeOf(LongInt));
  Inc(EntryIdx,4);
end;


function TEntryFile.GetDWord:DWord;
begin
  if EntryIdx+4>Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>=SizeOf(DWord) then
    begin
      Result:=Unaligned(PDWord(FBuffer.Current)^);
      FBuffer.Advance(SizeOf(DWord));
    end
  else
    ReadData(Result,SizeOf(DWord));
  Inc(EntryIdx,4);
end;


function TEntryFile.GetInt64:Int64;
begin
  if EntryIdx+8>Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>=SizeOf(Int64) then
    begin
      Result:=Unaligned(PInt64(FBuffer.Current)^);
      FBuffer.Advance(SizeOf(Int64));
    end
  else
    ReadData(Result,SizeOf(Int64));
  Inc(EntryIdx,8);
end;


function TEntryFile.GetQWord:QWord;
begin
  if EntryIdx+8>Entry.Size then
   begin
     Error:=True;
     Result:=0;
     Exit;
   end;
  if FBuffer.Remaining>=SizeOf(QWord) then
    begin
      Result:=Unaligned(PQWord(FBuffer.Current)^);
      FBuffer.Advance(SizeOf(QWord));
    end
  else
    ReadData(Result,SizeOf(QWord));
  Inc(EntryIdx,8);
end;


function TEntryFile.GetAInt:{$ifdef generic_cpu}Int64{$else}AInt{$endif};
{$ifdef generic_cpu}
var
  Header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef generic_cpu}
  Header:=GetHeaderAddr;
  if CpuAluBitSize[Header^.CPU]=64 then
    Result:=GetInt64
  else if CpuAluBitSize[Header^.CPU]=32 then
    Result:=GetLongInt
  else if CpuAluBitSize[Header^.CPU]=16 then
    Result:=SmallInt(GetWord)
  else if CpuAluBitSize[Header^.CPU]=8 then
    Result:=ShortInt(GetByte)
  else
    begin
      Error:=True;
      Result:=0;
    end;
{$else not generic_cpu}
  case SizeOf(AInt) of
    8: Result:=GetInt64;
    4: Result:=GetLongInt;
    2: Result:=SmallInt(GetWord);
    1: Result:=ShortInt(GetByte);
  else
    begin
      RaiseAssertion(2019041801);
      Result:=0;
    end;
  end;
{$endif not generic_cpu}
end;


function TEntryFile.GetASizeInt:{$ifdef generic_cpu}Int64{$else}ASizeInt{$endif};
{$ifdef generic_cpu}
var
  Header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef generic_cpu}
  Header:=GetHeaderAddr;
  if CpuAddrBitSize[Header^.CPU]=64 then
    Result:=GetInt64
  else if CpuAddrBitSize[Header^.CPU]=32 then
    Result:=GetLongInt
  else if CpuAddrBitSize[Header^.CPU]=16 then
    begin
      { result:=smallint(getword);
        would have been logical, but it contradicts
	definition of asizeint in globtype unit,
	which uses 32-bit lngint type even for 16-bit
	address size, to be able to cope with
	I8086 seg:ofs huge addresses }
      Result:=GetLongInt;
    end
  else
    begin
      Error:=True;
      Result:=0;
    end;
{$else not generic_cpu}
  case SizeOf(ASizeInt) of
    8: Result:=ASizeInt(GetInt64);
    4: Result:=ASizeInt(GetLongInt);
    2: Result:=ASizeInt(GetWord);
    1: Result:=ASizeInt(GetByte);
  else
    begin
      RaiseAssertion(2019041802);
      Result:=0;
    end;
  end;
{$endif not generic_cpu}
end;


function TEntryFile.GetPUInt:{$ifdef generic_cpu}QWord{$else}PUint{$endif};
{$ifdef generic_cpu}
var
Header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef generic_cpu}
  Header:=GetHeaderAddr;
  if CpuAddrBitSize[Header^.CPU]=64 then
    Result:=GetQWord
  else if CpuAddrBitSize[Header^.CPU]=32 then
    Result:=GetDWord
  else if CpuAddrBitSize[Header^.CPU]=16 then
    Result:=GetWord
  else
    begin
      Error:=True;
      Result:=0;
    end;
{$else not generic_cpu}
  case SizeOf(PUint) of
    8: Result:=GetQWord;
    4: Result:=GetDWord;
    2: Result:=GetWord;
    1: Result:=GetByte;
  else
    begin
      RaiseAssertion(2019041803);
      Result:=0;
    end;
  end;
{$endif not generic_cpu}
end;


function TEntryFile.GetPtrUInt:{$ifdef generic_cpu}QWord{$else}TConstPtrUInt{$endif};
{$ifdef generic_cpu}
var
Header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef generic_cpu}
  Header:=GetHeaderAddr;
  if CpuAddrBitSize[Header^.CPU]=64 then
    Result:=GetQWord
  else Result:=GetDWord;
{$else not generic_cpu}
  {$ifdef cpu64bitaddr}
  Result:=TConstPtrUInt(GetInt64);
  {$else}
  Result:=TConstPtrUInt(GetLongInt);
  {$endif}
{$endif not generic_cpu}
end;


function TEntryFile.GetAWord:{$ifdef generic_cpu}QWord{$else}AWord{$endif};
{$ifdef generic_cpu}
var
Header : PEntryHeader;
{$endif generic_cpu}
begin
{$ifdef generic_cpu}
  Header:=GetHeaderAddr;
  if CpuAluBitSize[Header^.CPU]=64 then
    Result:=GetQWord
  else if CpuAluBitSize[Header^.CPU]=32 then
    Result:=GetDWord
  else if CpuAluBitSize[Header^.CPU]=16 then
    Result:=GetWord
  else if CpuAluBitSize[Header^.CPU]=8 then
    Result:=GetByte
  else
    begin
      Error:=True;
      Result:=0;
    end;
{$else not generic_cpu}
  case SizeOf(AWord) of
    8: Result:=GetQWord;
    4: Result:=GetDWord;
    2: Result:=GetWord;
    1: Result:=GetByte;
  else
    begin
      RaiseAssertion(2019041804);
      Result:=0;
    end;
  end;
{$endif not generic_cpu}
end;



function TEntryFile.GetReal:BestReal;
var
  LDouble: TDoubleRec;
{$ifdef FPC_HAS_TYPE_EXTENDED}
  LExtended: TExtended80Rec;
{$endif}
begin
  if GetRealByteSize=8 then
    begin
      LDouble:=TDoubleRec(GetQWord);
      Result:=LDouble.Value;
    end
  else
    begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
      LExtended.Frac:=GetQWord;
      LExtended._Exp:=GetWord;
      Result:=LExtended.Value;
{$else}
      { An ARM host cannot consume an x86 unit's real constants. }
      Error:=True;
      Result:=0;
{$endif}
    end;
end;

function TEntryFile.GetRealByteSize:Byte;
begin
  if TargetInfo.CPU in [cpu_i386,cpu_x86_64] then
    Result:=10
  else
    Result:=8;
end;

function TEntryFile.GetBoolean:Boolean;
begin
  Result:=Boolean(GetByte);
end;


function TEntryFile.GetString:ShortString;
begin
  Result[0]:=Chr(GetByte);
  if EntryIdx+Length(Result)>Entry.Size then
   begin
     Error:=True;
     Exit;
   end;
  ReadData(Result[1],Length(Result));
  Inc(EntryIdx,Length(Result));
end;

function TEntryFile.GetPShortString:PShortString;
var
  Len: Char;
begin
  Result:=nil;
  Len:=Chr(GetByte);
  if EntryIdx+Ord(Len)>Entry.Size then
   begin
     Error:=True;
     Exit;
   end;
  GetMem(Result,Ord(Len)+1);
  Result^[0]:=Len;
  ReadData(Result^[1],Ord(Len));
  Inc(EntryIdx,Ord(Len));
end;

function TEntryFile.GetAnsiString:AnsiString;
var
  Len: LongInt;
begin
  Len:=GetLongInt;
  if EntryIdx+Len>Entry.Size then
   begin
     Error:=True;
     Result:='';
     Exit;
   end;
  SetLength(Result,Len);
  if Len>0 then
    GetData(Result[1],Len);
end;


procedure TEntryFile.GetSet(out Arr: array of Byte);
begin
  GetData(Arr,SizeOf(Arr));
end;


function TEntryFile.SkipUntilEntry(UntilB:Byte):Boolean;
var
  B : Byte;
begin
  repeat
    B:=ReadEntry;
  until (B in [IBEnd,IBError]) or ((B=UntilB) and (Entry.ID=MainEntryID));
  SkipUntilEntry:=(B=UntilB);
end;


{*****************************************************************************
                              tentryfile Writing
*****************************************************************************}

function TEntryFile.CreateFile:Boolean;
var
  Ok: Boolean;
  Strm : TCStream;
begin
  CreateFile:=False;
  Strm:=nil;
  if OutputAllowed then
    begin
      Ok:=False;
      try
        Strm:=CFileStreamClass.Create(FName,fmCreate);
        Ok:=True;
      except
      end;
      if not Ok then
       Exit;
    end;
  CreateFile:=CreateStream(Strm);
  FIsFile:=Result;
end;

function TEntryFile.CreateStream(Strm:TCStream):Boolean;
begin
  CreateStream:=False;
  if OutputAllowed then
    begin
      F:=Strm;
      Mode:=2;
      {write header for sure}
      F.Write(GetHeaderAddr^,GetHeaderSize);
    end;
  BufStart:=GetHeaderSize;
  FBuffer.Reset;
{reset}
  ResetFile;
  Error:=False;
  Size:=0;
  EntryTyp:=MainEntryID;
{start}
  NewEntry;
  CreateStream:=True;
end;


procedure TEntryFile.WriteBuf;
begin
  if OutputAllowed and
     (FBuffer.Size <> 0) then
    FBuffer.SaveToStream(F);
  Inc(BufStart,FBuffer.Size);
  FBuffer.Reset;
end;


procedure TEntryFile.WriteData(const B;Len:Integer);
begin
  if not OutputAllowed then
    Exit;
  FBuffer.Write(B,Len);
end;


procedure TEntryFile.NewEntry;
begin
  with Entry do
   begin
     ID:=EntryTyp;
     NR:=IBEnd;
     Size:=0;
   end;
{Reset Entry State}
  EntryIdx:=0;
  EntryBufStart:=BufStart;
  EntryStart:=BufferedPosition;
{Alloc in buffer}
  WriteData(Entry,SizeOf(TEntry));
end;


procedure TEntryFile.WriteEntry(IBNR:Byte);
var
  OPos : Integer;
begin
{create entry}
  Entry.ID:=EntryTyp;
  Entry.NR:=IBNR;
  Entry.Size:=EntryIdx;
{it's already been sent to disk ?}
  if EntryBufStart<>BufStart then
   begin
    if OutputAllowed then
      begin
      {flush to be sure}
        WriteBuf;
      {write entry}
        OPos:=F.Position;
        F.Position:=EntryStart;
        F.Write(Entry,SizeOf(TEntry));
        F.Position:=OPos;
      end;
     EntryBufStart:=BufStart;
   end
  else
   FBuffer.Patch(EntryStart-BufStart,Entry,SizeOf(Entry));
{Add New Entry, which is ibend by default}
  EntryStart:=BufferedPosition; {next entry position}
  NewEntry;
end;


procedure TEntryFile.PutData(const B;Len:Integer);
begin
  if OutputAllowed then
    FBuffer.Write(B,Len);
  Inc(EntryIdx,Len);
end;


procedure TEntryFile.PutByte(B:Byte);
begin
  PutData(B,1);
end;


procedure TEntryFile.PutWord(W:Word);
begin
  PutData(W,2);
end;


procedure TEntryFile.PutDWord(W:DWord);
begin
  PutData(W,4);
end;


procedure TEntryFile.PutLongInt(L:LongInt);
begin
  PutData(L,4);
end;


procedure TEntryFile.PutInt64(I:Int64);
begin
  PutData(I,8);
end;


procedure TEntryFile.PutQWord(Q:QWord);
begin
  PutData(Q,SizeOf(QWord));
end;


procedure TEntryFile.PutAInt(I:AInt);
begin
  PutData(I,SizeOf(AInt));
end;


procedure TEntryFile.PutASizeInt(I: ASizeInt);
begin
  PutData(I,SizeOf(ASizeInt));
end;


procedure TEntryFile.PutPUInt(I : PUint);
begin
  PutData(I,SizeOf(PUint));
end;

procedure TEntryFile.PutPtrUInt(V:TConstPtrUInt);
begin
  {$ifdef cpu64bitaddr}
  PutInt64(Int64(V));
  {$else}
  PutLongInt(LongInt(V));
  {$endif}
end;




procedure TEntryFile.PutAWord(I:AWord);
begin
  PutData(I,SizeOf(AWord));
end;


procedure TEntryFile.PutReal(D:BestReal);
var
  LDouble: TDoubleRec;
begin
  if GetRealByteSize=8 then
    begin
      LDouble.Value:=D;
      PutQWord(QWord(LDouble));
    end
  else
    begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
      PutQWord(TExtended80Rec(D).Frac);
      PutWord(TExtended80Rec(D)._Exp);
{$else}
      InternalErrorProc(2026101101);
{$endif}
    end;
end;

procedure TEntryFile.PutBoolean(B:Boolean);
begin
  PutByte(Byte(B));
end;


procedure TEntryFile.PutString(const S:ShortString);
begin
  PutData(S,Length(S)+1);
end;


procedure TEntryFile.PutAnsiString(const S:AnsiString);
  var
    Len: LongInt;
  begin
    Len:=Length(S);
    PutLongInt(Len);
    if Len>0 then
      PutData(S[1],Len);
  end;


procedure TEntryFile.PutSet(const Arr: array of Byte);
  begin
    PutData(Arr,SizeOf(Arr));
  end;


end.
