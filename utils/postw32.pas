{
    Copyright (c) 1998-2000 by Pavel Ozerski

    This program implements support post processing
    for the (i386) Win32 target

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
program PostW32;
uses
{$ifdef fpc}
  Strings
{$else}
  SysUtils
{$endif}
  ;

const
  ExecInfoFCantOpenExecutable='Cannot open file ';
  ExecInfoXCodeSize='Code size: ';
  ExecInfoXInitDataSize='Size of Initialized Data: ';
  ExecInfoXUninitDataSize='Size of Uninitialized Data: ';
  ExecInfoFCantProcessExecutable='Cannot process file ';
  ExecInfoXStackReserve='Size of Stack Reserve: ';
  ExecInfoXStackCommit='Size of Stack Commit: ';

type
  TAppType = (atNone,
    atGUI,atCUI
  );

var
  Verbose:LongBool;
  StackSize,
  II,JJ:LongInt;
  Code:Integer;
  DLLVersion : sTring;
  DLLMajor,DLLMinor : Word;
  AppType : TAppType;

function ToStr(I : LongInt) : string;
{
return string of value i
}
var
  HS : string;
begin
  Str(I,HS);
  ToStr:=HS;
end;

procedure Message1(const Info,Fn:string);
var
  E:LongBool;
begin
  E:=Pos('Cannot',Info)=1;
  if Verbose or E then
   WriteLn(Info,Fn);
  if E then
   Halt(1);
end;


function PostProcessExecutable(const Fn : string;IsDLL:Boolean):Boolean;
type
  TDOSHeader = packed record
     EMagic : Word;
     ECblp : Word;
     ECp : Word;
     ECrlc : Word;
     ECparhdr : Word;
     EMinalloc : Word;
     EMaxalloc : Word;
     ESs : Word;
     ESp : Word;
     ECsum : Word;
     EIp : Word;
     ECs : Word;
     ELfarlc : Word;
     EOvno : Word;
     ERes : array[0..3] of Word;
     EOEMID : Word;
     EOEMInfo : Word;
     ERes2 : array[0..9] of Word;
     ELFANew : LongInt;
  end;
  TPEHeader = packed record
     PEMagic : array[0..3] of Char;
     Machine : Word;
     NumberOfSections : Word;
     TimeDateStamp : LongInt;
     PointerToSymbolTable : LongInt;
     NumberOfSymbols : LongInt;
     SizeOfOptionalHeader : Word;
     Characteristics : Word;
     Magic : Word;
     MajorLinkerVersion : Byte;
     MinorLinkerVersion : Byte;
     SizeOfCode : LongInt;
     SizeOfInitializedData : LongInt;
     SizeOfUninitializedData : LongInt;
     AddressOfEntryPoint : LongInt;
     BaseOfCode : LongInt;
     BaseOfData : LongInt;
     ImageBase : LongInt;
     SectionAlignment : LongInt;
     FileAlignment : LongInt;
     MajorOperatingSystemVersion : Word;
     MinorOperatingSystemVersion : Word;
     MajorImageVersion : Word;
     MinorImageVersion : Word;
     MajorSubsystemVersion : Word;
     MinorSubsystemVersion : Word;
     Reserved1 : LongInt;
     SizeOfImage : LongInt;
     SizeOfHeaders : LongInt;
     CheckSum : LongInt;
     Subsystem : Word;
     DllCharacteristics : Word;
     SizeOfStackReserve : LongInt;
     SizeOfStackCommit : LongInt;
     SizeOfHeapReserve : LongInt;
     SizeOfHeapCommit : LongInt;
     LoaderFlags : LongInt;
     NumberOfRvaAndSizes : LongInt;
     DataDirectory : array[1..$80] of Byte;
  end;
  TCOFFSecHdr=packed record
    Name     : array[0..7] of Char;
    VSize    : LongInt;
    RVAOfs   : LongInt;
    DataLen  : LongInt;
    DataPos  : LongInt;
    RelocPos : LongInt;
    LineNo1  : LongInt;
    NRelocs  : Word;
    LineNo2  : Word;
    Flags    : LongInt;
  end;
  PSecFill=^TSecFill;
  TSecFill=record
    FillPos,
    FillSize : LongInt;
    Next : PSecFill;
  end;
var
  F : file;
  DOSHeader : TDOSHeader;
  PEHeader : TPEHeader;
  FirstSecPos,
  MaxFillSize,
  L,PEHeaderPos : LongInt;
  COFFSec : TCOFFSecHdr;
  SecRoot,HSecRoot : PSecFill;
  ZeroBuf : Pointer;
begin
  PostProcessExecutable:=False;
  { open file }
  Assign(F,Fn);
  {$I-}
   Reset(F,1);
  if IOResult<>0 then
    Message1(ExecInfoFCantOpenExecutable,Fn);
  { read headers }
  BlockRead(F,DOSHeader,SizeOf(TDOSHeader));
  PEHeaderPos:=DOSHeader.ELFANew;
  Seek(F,PEHeaderPos);
  BlockRead(F,PEHeader,SizeOf(TPEHeader));
  { write info }
  Message1(ExecInfoXCodeSize,ToStr(PEHeader.SizeOfCode));
  Message1(ExecInfoXInitDataSize,ToStr(PEHeader.SizeOfInitializedData));
  Message1(ExecInfoXUninitDataSize,ToStr(PEHeader.SizeOfUninitializedData));
  { change stack size (PM) }
  { I am not sure that the default value is adequate !! }
  PEHeader.SizeOfStackReserve:=StackSize;
  { change the header }
  { sub system }
  { gui=2 }
  { cui=3 }
  if AppType=atGUI then
    PEHeader.Subsystem:=2
  else if AppType=atCUI then
    PEHeader.Subsystem:=3;
  if DLLVersion<>'' then
    begin
     PEHeader.MajorImageVersion:=DLLMajor;
     PEHeader.MinorImageVersion:=DLLMinor;
    end;
  { reset timestamp }
  PEHeader.TimeDateStamp:=0;
  { write header back }
  Seek(F,PEHeaderPos);
  BlockWrite(F,PEHeader,SizeOf(TPEHeader));
  if IOResult<>0 then
    Message1(ExecInfoFCantProcessExecutable,Fn);
  Seek(F,PEHeaderPos);
  BlockRead(F,PEHeader,SizeOf(TPEHeader));
  { write the value after the change }
  Message1(ExecInfoXStackReserve,ToStr(PEHeader.SizeOfStackReserve));
  Message1(ExecInfoXStackCommit,ToStr(PEHeader.SizeOfStackCommit));
  { read section info }
  MaxFillSize:=0;
  FirstSecPos:=0;
  SecRoot:=nil;
  for L:=1to PEHeader.NumberOfSections do
   begin
     BlockRead(F,COFFSec,SizeOf(TCOFFSecHdr));
     if COFFSec.DataPos>0 then
      begin
        if SecRoot=nil then
         FirstSecPos:=COFFSec.DataPos;
        New(HSecRoot);
        HSecRoot^.FillPos:=COFFSec.DataPos+COFFSec.VSize;
        HSecRoot^.FillSize:=COFFSec.DataLen-COFFSec.VSize;
        HSecRoot^.Next:=SecRoot;
        SecRoot:=HSecRoot;
        if SecRoot^.FillSize>MaxFillSize then
         MaxFillSize:=SecRoot^.FillSize;
      end;
   end;
  if FirstSecPos>0 then
   begin
     L:=FirstSecPos-FilePos(F);
     if L>MaxFillSize then
      MaxFillSize:=L;
   end
  else
   L:=0;
  { get zero buffer }
  GetMem(ZeroBuf,MaxFillSize);
  FillChar(ZeroBuf^,MaxFillSize,0);
  { zero from sectioninfo until first section }
  BlockWrite(F,ZeroBuf^,L);
  { zero section alignments }
  while Assigned(SecRoot) do
   begin
     Seek(F,SecRoot^.FillPos);
     BlockWrite(F,ZeroBuf^,SecRoot^.FillSize);
     HSecRoot:=SecRoot;
     SecRoot:=SecRoot^.Next;
     Dispose(HSecRoot);
   end;
  FreeMem(ZeroBuf,MaxFillSize);
  Close(F);
  {$I+}
  if IOResult<>0 then;
  PostProcessExecutable:=True;
end;


var
  Fn,S:string;
function GetSwitchValue(const Key,ShortKey,Default:string;const PossibleValues:array of PAnsiChar):AnsiString;
var
  I,J,K:LongInt;
  X:Double;
  S1,S2:AnsiString;
  Code:Integer;

  procedure Error;
  begin
   WriteLn('Error: unrecognized option ',ParamStr(I),' ',S1);
   Halt(1);
  end;

begin
  for I:=1 to ParamCount do
   if(ParamStr(I)=Key)or(ParamStr(I)=ShortKey)then
    begin
     S1:=ParamStr(Succ(I));
     for J:=0 to High(PossibleValues)do
      begin
       S2:=StrPas(PossibleValues[J]);
       if(Length(S2)>1)and(S2[1]='*')then
        case S2[2]of
         'i':
          begin
           Val(S1,K,Code);
           if Code<>0 then
            Error;
           GetSwitchValue:=S1;
           exit;
          end;
         'r':
          begin
           Val(S1,X,Code);
           if Code<>0 then
            Error;
           GetSwitchValue:=S1;
           exit;
          end;
         's':
          begin
           GetSwitchValue:=S1;
           exit;
          end;
        end
       else if S1=S2 then
        begin
         GetSwitchValue:=S1;
         exit;
        end;
      end;
     Error;
    end;
  GetSwitchValue:=Default;
end;

procedure HelpInfo;
begin
  Fn:=ParamStr(0);
  for JJ:=Length(Fn)downto 1 do
   if Fn[JJ] in [':','\','/']then
    begin
     Fn:=Copy(Fn,Succ(JJ),255);
     break;
    end;
  WriteLn('Usage: ',Fn,' [options]');
  WriteLn('Options:');
  WriteLn('-i | --input <file>              - set input file;');
  WriteLn('-m | --subsystem <console | gui> - set Win32 subsystem;');
  WriteLn('-s | --stack <size>              - set stack size;');
  WriteLn('-V | --version <n.n>             - set image version;');
  WriteLn('-v | --verbose                   - show info while processing;');
  WriteLn('-h | --help | -?                 - show this screen');
  Halt;
end;

begin
  Verbose:=False;
  if ParamCount=0 then
    HelpInfo;
  for II:=1 to ParamCount do
    if(ParamStr(II)='-h')or(ParamStr(II)='--help')or(ParamStr(II)='-?')then
     HelpInfo
    else if(ParamStr(II)='-v')or(ParamStr(II)='--verbose')then
     begin
      Verbose:=True;
      break;
     end;
  Fn:=GetSwitchValue('--input','-i','',['*s']);
  Val(GetSwitchValue('--stack','-s','33554432',['*i']),StackSize,Code);
  S:=GetSwitchValue('--subsystem','-m','console',['gui','console']);
  if S='gui' then
    AppType:=atGUI
  else
    AppType:=atCUI;
  DLLVersion:=GetSwitchValue('--version','-V','1.0',['*r']);
  II:=Pos('.',DLLVersion);
  if II=0 then
    begin
     II:=Succ(Length(DLLVersion));
     DLLVersion:=DLLVersion+'.0';
    end
  else if II=1 then
    begin
     II:=2;
     DLLVersion:='0.'+DLLVersion;
    end;
  Val(Copy(DLLVersion,1,Pred(II)),DLLMajor,Code);
  Val(Copy(DLLVersion,Succ(II),Length(DLLVersion)),DLLMinor,Code);
  if Verbose then
    WriteLn('Image Version: ',DLLMajor,'.',DLLMinor);
  PostProcessExecutable(Fn,False);
end.
