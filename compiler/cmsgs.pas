{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit implements the message object

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
unit cmsgs;

{$i fpcdefs.inc}

interface

uses
  GlobType;

const
  MaxMsgIdxParts = 20;

type
  PPChar=^PChar;
  TMsgStr = AnsiString;

  TArrayOfPChar = array of PChar;
  TArrayOfState = array of TMsgState;

  TMsgIdx = array[1..MaxMsgIdxParts] of TArrayOfPChar;
  TMsgIdxMax = array[1..MaxMsgIdxParts] of LongInt;
  TMsgStates = array[1..MaxMsgIdxParts] of TArrayOfState;

  PMessage=^TMessage;
  TMessage=object
    MsgFileName : string;
    MsgIntern   : Boolean;
    MsgAllocSize,
    MsgSize,
    MsgParts,
    Msgs        : LongInt;
    MsgTxt      : PChar;
    MsgIdx      : TMsgIdx;
    MsgIdxMax   : TMsgIdxMax;
    MsgStates   : TMsgStates;
    MsgCodePage : TSystemCodePage;
    { set if changes with $WARN need to be cleared at next module change }
    HasLocalChanges : Boolean;
    constructor Init(N:LongInt;const IdxMax:array of LongInt);
    destructor  Done;
    function  LoadIntern(P:Pointer;N:LongInt;CP:TSystemCodePage):Boolean;
    function  LoadExtern(const FN:string):Boolean;
    procedure ClearIdx;
    procedure ResetStates;
    procedure CreateIdx;
    { function  ClearVerbosity(nr:longint):boolean; not used anymore }
    function  SetVerbosity(Nr:LongInt;NewState:TMsgState):Boolean;
    function  Get(Nr:LongInt;const Args:array of TMsgStr):TMsgStr;
    function  Valid(Nr:LongInt):Boolean;
  end;

{ this will read a line until #10 or #0 and also increase p }
function GetMsgLine(var P:PChar):ShortString;


implementation

uses
  SysUtils,
  CUtils;


function MsgReplace(const S:TMsgStr;const Args:array of TMsgStr):TMsgStr;
var
  Last,
  I  : LongInt;
  HS : TMsgStr;

begin
  if S='' then
    begin
      MsgReplace:='';
      Exit;
    end;
  HS:='';
  I:=0;
  Last:=0;
  while (I<Length(S)-1) do
    begin
      Inc(I);
      if (S[I]='$') and (S[I+1] in ['1'..'9']) then
        begin
          HS:=HS+Copy(S,Last+1,I-Last-1)+Args[Byte(S[I+1])-Byte('1')];
          Inc(I);
          Last:=I;
        end;
    end;
  MsgReplace:=HS+Copy(S,Last+1,Length(S)-Last);
end;



constructor TMessage.Init(N:LongInt;const IdxMax:array of LongInt);
var
  I,J : LongInt;
begin
  MsgTxt:=nil;
  HasLocalChanges:=False;
  MsgSize:=0;
  MsgParts:=N;
  MsgCodePage:=CP_ACP;
  if N<>High(IdxMax)+1 then
   Fail;
  FillChar(MsgIdx,SizeOf(TMsgIdx),0);
  FillChar(MsgIdxMax,SizeOf(TMsgIdxMax),0);
  FillChar(MsgStates,SizeOf(TMsgStates),0);
  for I:=1 to N do
   begin
     MsgIdxMax[I]:=IdxMax[I-1];
     { create array of msgidx }
     SetLength(MsgIdx[I],MsgIdxMax[I]);
     { create array of states }
     SetLength(MsgStates[I],MsgIdxMax[I]);
     { default value for msgstate is ms_on_global }
     for J:=0 to MsgIdxMax[I]-1 do
       MsgStates[I][J]:=ms_on_global;
   end;
end;


destructor TMessage.Done;
var
  I : LongInt;
begin
  for I:=1 to MsgParts do
  begin
   MsgIdx[I]:=nil;
   MsgStates[I]:=nil;
  end;
  if MsgAllocSize>0 then
   begin
     FreeMem(MsgTxt,MsgSize);
     MsgAllocSize:=0;
   end;
  MsgTxt:=nil;
  MsgSize:=0;
  MsgParts:=0;
end;


function TMessage.LoadIntern(P:Pointer;N:LongInt;CP:TSystemCodePage):Boolean;
begin
  MsgCodePage:=CP;
  MsgTxt:=PChar(P);
  MsgSize:=N;
  MsgAllocSize:=0;
  MsgIntern:=True;
  ClearIdx;
  CreateIdx;
  LoadIntern:=True;
end;


function TMessage.LoadExtern(const FN:string):Boolean;
const
  BufSize=8192;
var
  F       : Text;
  Error,Multiline : Boolean;
  Line,I,J : LongInt;
  PTxt    : PChar;
  S,S1    : string;
  Buf     : Pointer;

  procedure Err(const MsgStr:TMsgStr);
  begin
    WriteLn('*** PPC, file ',FN,', error in line ',Line,': ',MsgStr);
    Error:=True;
  end;

begin
  LoadExtern:=False;
  MsgCodePage:=CP_ACP;
  GetMem(Buf,BufSize);
  { Read the message file }
  Assign(F,FN);
  {$push}{$I-}
   Reset(F);
  {$pop}
  if IOResult<>0 then
   begin
     WriteLn('*** PPC, can not open message file ',FN);
     Exit;
   end;
  SetTextBuf(F,Buf^,BufSize);
  { First parse the file and count bytes needed }
  Error:=False;
  Line:=0;
  Multiline:=False;
  MsgSize:=0;
  while not EOF(F) do
   begin
     ReadLn(F,S);
     Inc(Line);
     if Multiline then
      begin
        if S=']' then
         Multiline:=False
        else
         Inc(MsgSize,Length(S)+1); { +1 for linebreak }
      end
     else
      begin
        if (S<>'') and not(S[1] in ['#',';','%']) then
         begin
           I:=Pos('=',S);
           if I>0 then
            begin
              J:=I+1;
              if not(S[J] in ['0'..'9']) then
               Err('no number found')
              else
               begin
                 while (S[J] in ['0'..'9']) do
                  Inc(J);
               end;
              if J-I-1<>5 then
               Err('number length is not 5');
              if S[J+1]='[' then
               begin
                 Inc(MsgSize,J-I);
                 Multiline:=True
               end
              else
               Inc(MsgSize,Length(S)-I+1);
            end
           else
            Err('no = found');
         end
        else if (Length(S)>11) and (Copy(S,1,11)='# CodePage ') then
         begin
           MsgCodePage:=StrToInt(Copy(S,12,Length(S)-11));
         end;
      end;
   end;
  if Multiline then
   Err('still in multiline mode');
  if Error then
   begin
     FreeMem(Buf,BufSize);
     Close(F);
     Exit;
   end;
  { now read the buffer in mem }
  MsgAllocSize:=MsgSize;
  GetMem(MsgTxt,MsgAllocSize);
  PTxt:=MsgTxt;
  Reset(F);
  while not EOF(F) do
   begin
     ReadLn(F,S);
     if Multiline then
      begin
        if S=']' then
         begin
           Multiline:=False;
           { overwrite last eol }
           Dec(PTxt);
           PTxt^:=#0;
           Inc(PTxt);
         end
        else
         begin
           Move(S[1],PTxt^,Length(S));
           Inc(PTxt,Length(S));
           PTxt^:=#10;
           Inc(PTxt);
         end;
      end
     else
      begin
        if (S<>'') and not(S[1] in ['#',';','%']) then
         begin
           I:=Pos('=',S);
           if I>0 then
            begin
              J:=I+1;
              while (S[J] in ['0'..'9']) do
               Inc(J);
              { multiline start then no txt }
              if S[J+1]='[' then
               begin
                 S1:=Copy(S,I+1,J-I);
                 Move(S1[1],PTxt^,Length(S1));
                 Inc(PTxt,Length(S1));
                 Multiline:=True;
               end
              else
               begin
                 { txt including number }
                 S1:=Copy(S,I+1,255);
                 Move(S1[1],PTxt^,Length(S1));
                 Inc(PTxt,Length(S1));
                 PTxt^:=#0;
                 Inc(PTxt);
               end;
            end;
         end;
      end;
   end;
  Close(F);
  FreeMem(Buf,BufSize);
{ now we can create the index, clear if the previous load was also
  an external file, because those can't be reused }
  if not MsgIntern then
   ClearIdx;
  CreateIdx;
{ set that we've loaded an external file }
  MsgIntern:=False;
  LoadExtern:=True;
end;


procedure TMessage.ClearIdx;
var
  I : LongInt;
begin
  { clear }
  for I:=1 to MsgParts do
    FillChar(MsgIdx[I][0],MsgIdxMax[I]*SizeOf(Pointer),0);
end;


procedure TMessage.CreateIdx;
var
  HP1,
  HP,HPEnd : PChar;
  Code : Integer;
  Num  : LongInt;
  Number : string[5];
  I   : LongInt;
  NumPart,NumIdx : LongInt;
begin
  { process msgtxt buffer }
  Number:='00000';
  HP:=MsgTxt;
  HPEnd:=@MsgTxt[MsgSize];
  while (HP<HPEnd) do
   begin
     HP1:=HP;
     for I:=1 to 5 do
      begin
        Number[I]:=HP1^;
        Inc(HP1);
      end;
     Val(Number,Num,Code);
     NumPart:=Num div 1000;
     NumIdx:=Num mod 1000;
     { check range }
     if (NumPart <= MsgParts) and (NumIdx < MsgIdxMax[NumPart]) then
      begin
        { skip _ }
        Inc(HP1);
        { set default verbosity to off is '-' is found just after the '_' }
        if HP1^='-' then
         begin
           MsgStates[NumPart][NumIdx]:=ms_off_global;
           Inc(HP1);
         end;
        { put the address in the idx, the numbers are already checked }
        MsgIdx[NumPart][NumIdx]:=HP1;
      end;
     { next string }
     HP:=PChar(@HP[StrLen(HP)+1]);
   end;
end;


function GetMsgLine(var P:PChar):ShortString;
var
  I  : LongInt;
begin
  I:=0;
  while not(P^ in [#0,#10]) and (I<256) do
   begin
     Inc(I);
     GetMsgLine[I]:=P^;
     Inc(P);
   end;
  { skip #10 }
  if P^=#10 then
   Inc(P);
  { if #0 then set p to nil }
  if P^=#0 then
   P:=nil;
  { return string }
  GetMsgLine[0]:=Chr(I);
end;


function TMessage.SetVerbosity(Nr:LongInt;NewState:TMsgState):Boolean;
var
  I: LongInt;
  OldState : TMsgState;
  IsGlobal : Boolean;
begin
  Result:=False;
  I:=Nr div 1000;
  if (I < Low(MsgStates)) or
     (I > MsgParts) then
    Exit;
  if (Nr mod 1000 < MsgIdxMax[I]) then
    begin
      IsGlobal:=(Ord(NewState) and ms_global_mask) <> 0;
      OldState:=MsgStates[I][Nr mod 1000];
      if not IsGlobal then
        NewState:= TMsgState((Ord(NewState) and ms_local_mask) or (Ord(OldState) and ms_global_mask));
      if NewState<>OldState then
        HasLocalChanges:=True;
      MsgStates[I][Nr mod 1000]:=NewState;
      Result:=True;
    end;
end;

{
function TMessage.ClearVerbosity(nr:longint):boolean;
begin
  ClearVerbosity:=SetVerbosity(nr,ms_off);
end;
}

function TMessage.Get(Nr:LongInt;const Args:array of TMsgStr):TMsgStr;
var
  HP : PChar;
  S: TMsgStr;
begin
  if (Nr div 1000 < MsgParts) and
     (Nr mod 1000 <  MsgIdxMax[Nr div 1000]) then
    HP:=MsgIdx[Nr div 1000][Nr mod 1000]
  else
    HP:=nil;
  if HP=nil then
    Get:='msg nr '+ToStr(Nr)
  else
    begin
      S:=SysUtils.StrPas(HP);
{$ifdef cpawaremessages}
      SetCodePage(RawByteString(S),MsgCodePage,False);
      SetCodePage(RawByteString(S),CP_ACP,True);
{$endif cpawaremessages}
      Get:=MsgReplace(S,Args);
    end;
end;

function TMessage.Valid(Nr:LongInt):Boolean;
var
  I,J : LongInt;
begin
  I:=Nr div 1000;
  J:=Nr mod 1000;
  Result:=(I>=Low(MsgStates)) and (I<MsgParts) and (J<MsgIdxMax[I]) and Assigned(MsgIdx[I][J]);
end;

procedure TMessage.ResetStates;
var
  I,J,Glob : LongInt;
  State : TMsgState;
begin
  if not HasLocalChanges then
    Exit;
  for I:=1 to MsgParts do
    for J:=0 to MsgIdxMax[I] - 1 do
      begin
        State:=MsgStates[I][J];
        Glob:=(Ord(State) and ms_global_mask) shr ms_shift;
        State:=TMsgState((Glob shl ms_shift) or Glob);
        MsgStates[I][J]:=State;
      end;
  HasLocalChanges:=False;
end;


end.
