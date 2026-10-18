{
    Copyright (c) 1998-2002 by Peter Vreman and Florian Klaempfl

    Convert a64reg.dat to several .inc files for usage with
    the Free pascal compiler

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}

program mka64reg;

const cVersion = '1.00';
      cMaxRegCount = 1000;

var LineText : String;
    Index : LongInt;
    Line : LongInt;
    RegCount:Word;
    RegCountBSStart:Word;
    Names,
    RegTypes,
    SubTypes,
    SupRegs,
    Numbers,
    StdNames,
    Dwarf : array[0..cMaxRegCount-1] of String[63];
    RegNumberIndex,
    StdRegNameIndex : array[0..cMaxRegCount-1] of Word;

function ToStr(AValue : LongInt) : String;

begin
  str(AValue,ToStr);
end;

function ReadStr : String;

  begin
     Result:='';
     while (LineText[Index]<>',') and (Index<=length(LineText)) do
       begin
          Result:=Result+LineText[Index];
          inc(Index);
       end;
  end;


procedure ReadComma;
  begin
     if LineText[Index]<>',' then
       begin
         WriteLn('Missing "," at line ',Line);
         WriteLn('Line: "',LineText,'"');
         halt(1);
       end;
     inc(Index);
  end;


procedure SkipSpace;

  begin
     while (LineText[Index] in [' ',#9]) do
       inc(Index);
  end;

procedure OpenInc(out AFile:Text;const AFileName:String);
begin
  WriteLn('creating ',AFileName);
  assign(AFile,AFileName);
  rewrite(AFile);
  WriteLn(AFile,'{ don''t edit, this file is generated from a64reg.dat }');
end;


procedure CloseInc(var AFile:Text);
begin
  WriteLn(AFile);
  close(AFile);
end;

procedure BuildRegNumIndex;

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Word;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for lIndex:=0 to RegCount-1 do
    RegNumberIndex[lIndex]:=lIndex;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  lGap:=RegCountBSStart;
  repeat
    for lIndexH:=0 to RegCount-lGap-1 do
      begin
        lIndex:=lIndexH;
        repeat
          lIndexJ:=lIndex+lGap;
          if Numbers[RegNumberIndex[lIndexJ]]>=Numbers[RegNumberIndex[lIndex]] then
            break;
          lTemp:=RegNumberIndex[lIndex];
          RegNumberIndex[lIndex]:=RegNumberIndex[lIndexJ];
          RegNumberIndex[lIndexJ]:=lTemp;
          if lIndex<lGap then
            break;
          dec(lIndex,lGap);
        until false;
      end;
    lGap:=lGap shr 1;
  until lGap=0;
end;

procedure BuildStdRegNameIndex;

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Word;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for lIndex:=0 to RegCount-1 do
    StdRegNameIndex[lIndex]:=lIndex;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  lGap:=RegCountBSStart;
  repeat
    for lIndexH:=0 to RegCount-lGap-1 do
      begin
        lIndex:=lIndexH;
        repeat
          lIndexJ:=lIndex+lGap;
          if StdNames[StdRegNameIndex[lIndexJ]]>=StdNames[StdRegNameIndex[lIndex]] then
            break;
          lTemp:=StdRegNameIndex[lIndex];
          StdRegNameIndex[lIndex]:=StdRegNameIndex[lIndexJ];
          StdRegNameIndex[lIndexJ]:=lTemp;
          if lIndex<lGap then
            break;
          dec(lIndex,lGap);
        until false;
      end;
    lGap:=lGap shr 1;
  until lGap=0;
end;


procedure ReadSpRegFile;

var lInputFile:Text;

begin
   { open dat file }
   assign(lInputFile,'a64reg.dat');
   reset(lInputFile);
   while not(eof(lInputFile)) do
     begin
        { handle comment }
        readln(lInputFile,LineText);
        inc(Line);
        while (LineText<>'') and (LineText[1]=' ') do
         delete(LineText,1,1);
        if (LineText='') or (LineText[1]=';') then
          continue;

        Index:=1;
        Names[RegCount]:=ReadStr;
        ReadComma;
        RegTypes[RegCount]:=ReadStr;
        ReadComma;
        SubTypes[RegCount]:=ReadStr;
        ReadComma;
        SupRegs[RegCount]:=ReadStr;
        ReadComma;
        StdNames[RegCount]:=ReadStr;
        ReadComma;
        Dwarf[RegCount]:=ReadStr;
        { Create register number }
        if SupRegs[RegCount][1]<>'$' then
          begin
            WriteLn('Missing $ before number, at line ',Line);
            WriteLn('Line: "',LineText,'"');
            halt(1);
          end;
        Numbers[RegCount]:=RegTypes[RegCount]+copy(SubTypes[RegCount],2,255)+'00'+copy(SupRegs[RegCount],2,255);
        if Index<length(LineText) then
          begin
            WriteLn('Extra chars at end of line, at line ',Line);
            WriteLn('Line: "',LineText,'"');
            halt(1);
          end;
        inc(RegCount);
        if RegCount>cMaxRegCount then
          begin
            WriteLn('Error: Too much registers, please increase maxregcount in source');
            halt(2);
          end;
     end;
   close(lInputFile);
end;

procedure WriteIncFiles;

var
    lCountFile,lStdFile,lSupRegFile,
    lNumberFile,lDwarfFile,lConstFile,
    lRegNumberIndexFile,lStdRegIndexFile:Text;
    lFirst:Boolean;

begin
  { create inc files }
  OpenInc(lConstFile,'ra64con.inc');
  OpenInc(lSupRegFile,'ra64sup.inc');
  OpenInc(lNumberFile,'ra64num.inc');
  OpenInc(lStdFile,'ra64std.inc');
  OpenInc(lDwarfFile,'ra64dwa.inc');
  OpenInc(lCountFile,'ra64nor.inc');
  OpenInc(lRegNumberIndexFile,'ra64rni.inc');
  OpenInc(lStdRegIndexFile,'ra64sri.inc');
  lFirst:=true;
  for Index:=0 to RegCount-1 do
    begin
      if not lFirst then
        begin
          WriteLn(lNumberFile,',');
          WriteLn(lStdFile,',');
          WriteLn(lDwarfFile,',');
          WriteLn(lRegNumberIndexFile,',');
          WriteLn(lStdRegIndexFile,',');
        end
      else
        lFirst:=false;
      WriteLn(lSupRegFile,'RS_',Names[Index],' = ',SupRegs[Index],';');
      WriteLn(lConstFile,'NR_'+Names[Index],' = ','TRegister(',Numbers[Index],')',';');
      write(lNumberFile,'TRegister(',Numbers[Index],')');
      write(lStdFile,'''',StdNames[Index],'''');
      write(lDwarfFile,Dwarf[Index]);
      write(lRegNumberIndexFile,RegNumberIndex[Index]);
      write(lStdRegIndexFile,StdRegNameIndex[Index]);
    end;
  write(lCountFile,RegCount);
  close(lConstFile);
  close(lSupRegFile);
  CloseInc(lNumberFile);
  CloseInc(lStdFile);
  CloseInc(lDwarfFile);
  CloseInc(lCountFile);
  CloseInc(lRegNumberIndexFile);
  CloseInc(lStdRegIndexFile);
  WriteLn('Done!');
  WriteLn(RegCount,' registers processed');
end;


begin
   WriteLn('Register Table Converter Version ',cVersion);
   Line:=0;
   RegCount:=0;
   ReadSpRegFile;
   RegCountBSStart:=1;
   while 2*RegCountBSStart<RegCount do
     RegCountBSStart:=RegCountBSStart*2;
   BuildRegNumIndex;
   BuildStdRegNameIndex;
   WriteIncFiles;
end.
