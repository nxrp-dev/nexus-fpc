{
    Copyright (c) 1998-2002 by Peter Vreman and Florian Klaempfl

    Convert x86reg.dat to several .inc files for usage with
    the Free pascal compiler

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}
{$i+}
program mkx86reg;

const cVersion = '1.01';
      cMaxRegCount = 511;

var LineText : String;
    Index : LongInt;
    Line : LongInt;
    RegCount:LongInt;
    RegCountBSStart:LongInt;
    Names,Numbers,StdNames,IntNames,ATTNames,Dwarf16,Dwarf32,Dwarf64,OTs,Ops:
        array[0..cMaxRegCount-1] of String[63];
    RegNumberIndex,StdRegNameIndex,IntRegNameIndex,ATTRegNameIndex:
        array[0..cMaxRegCount-1] of Byte;
    IsI8086  : Boolean;
    IsX8664 : Boolean;
    FilePrefix : String;

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
     ReadStr:=Result;
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
  WriteLn(AFile,'{ don''t edit, this file is generated from x86reg.dat }');
end;


procedure CloseInc(var AFile:Text);
begin
  WriteLn(AFile);
  close(AFile);
end;

procedure BuildRegNumIndex;

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Byte;

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

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Byte;

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

procedure BuildIntRegNameIndex;

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Byte;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for lIndex:=0 to RegCount-1 do
    IntRegNameIndex[lIndex]:=lIndex;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  lGap:=RegCountBSStart;
  repeat
    for lIndexH:=0 to RegCount-lGap-1 do
      begin
        lIndex:=lIndexH;
        repeat
          lIndexJ:=lIndex+lGap;
          if IntNames[IntRegNameIndex[lIndexJ]]>=IntNames[IntRegNameIndex[lIndex]] then
            break;
          lTemp:=IntRegNameIndex[lIndex];
          IntRegNameIndex[lIndex]:=IntRegNameIndex[lIndexJ];
          IntRegNameIndex[lIndexJ]:=lTemp;
          if lIndex<lGap then
            break;
          dec(lIndex,lGap);
        until false;
      end;
    lGap:=lGap shr 1;
  until lGap=0;
end;

procedure BuildATTRegNameIndex;

var lIndexH,lIndex,lIndexJ,lGap,lTemp:Byte;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for lIndex:=0 to RegCount-1 do
    ATTRegNameIndex[lIndex]:=lIndex;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  lGap:=RegCountBSStart;
  repeat
    for lIndexH:=0 to RegCount-lGap-1 do
      begin
        lIndex:=lIndexH;
        repeat
          lIndexJ:=lIndex+lGap;
          if ATTNames[ATTRegNameIndex[lIndexJ]]>=ATTNames[ATTRegNameIndex[lIndex]] then
            break;
          lTemp:=ATTRegNameIndex[lIndex];
          ATTRegNameIndex[lIndex]:=ATTRegNameIndex[lIndexJ];
          ATTRegNameIndex[lIndexJ]:=lTemp;
          if lIndex<lGap then
            break;
          dec(lIndex,lGap);
        until false;
      end;
    lGap:=lGap shr 1;
  until lGap=0;
end;

procedure ReadX86RegFile;

var lInputFile:Text;
    lCPUString:String;

begin
   { open dat file }
   assign(lInputFile,'../x86/x86reg.dat');
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
        Numbers[RegCount]:=ReadStr;
        ReadComma;
        StdNames[RegCount]:=ReadStr;
        ReadComma;
        ATTNames[RegCount]:=ReadStr;
        ReadComma;
        IntNames[RegCount]:=ReadStr;
        ReadComma;
        Dwarf16[RegCount]:=ReadStr;
        ReadComma;
        Dwarf32[RegCount]:=ReadStr;
        ReadComma;
        Dwarf64[RegCount]:=ReadStr;
        ReadComma;
        OTs[RegCount]:=ReadStr;
        ReadComma;
        Ops[RegCount]:=ReadStr;
        if LineText[Index]=',' then
          begin
            ReadComma;
            lCPUString:=ReadStr;
          end
        else
          lCPUString:='';
        if Index<length(LineText) then
          begin
            WriteLn('Extra chars at end of line, at line ',Line);
            WriteLn('Line: "',LineText,'"');
            halt(1);
          end;
        if (lCPUString<>'64') or IsX8664 then
          begin
            inc(RegCount);
            if RegCount>cMaxRegCount then
              begin
                WriteLn('Error: Too much registers, please increase maxregcount in source');
                halt(2);
              end;
          end;
     end;
   close(lInputFile);
end;

procedure WriteIncFiles;

var lATTFile,lIntFile,lOTFile,
    lCountFile,lStdFile,
    lNumberFile,lDwarfFile,lConstFile,
    lRegNumberIndexFile,lIntRegIndexFile,lStdRegIndexFile,
    lATTRegIndexFile:Text;
    lFirst:Boolean;

begin
  { create inc files }
  OpenInc(lConstFile,FilePrefix+'con.inc');
  OpenInc(lNumberFile,FilePrefix+'num.inc');
  OpenInc(lStdFile,FilePrefix+'std.inc');
  OpenInc(lATTFile,FilePrefix+'att.inc');
  OpenInc(lIntFile,FilePrefix+'int.inc');
  OpenInc(lDwarfFile,FilePrefix+'dwrf.inc');
  OpenInc(lOTFile,FilePrefix+'ot.inc');
  OpenInc(lCountFile,FilePrefix+'nor.inc');
  OpenInc(lRegNumberIndexFile,FilePrefix+'rni.inc');
  OpenInc(lStdRegIndexFile,FilePrefix+'sri.inc');
  OpenInc(lATTRegIndexFile,FilePrefix+'ari.inc');
  OpenInc(lIntRegIndexFile,FilePrefix+'iri.inc');
  lFirst:=true;
  for Index:=0 to RegCount-1 do
    begin
      if not lFirst then
        begin
          WriteLn(lNumberFile,',');
          WriteLn(lStdFile,',');
          WriteLn(lATTFile,',');
          WriteLn(lIntFile,',');
          WriteLn(lDwarfFile,',');
          WriteLn(lOTFile,',');
          WriteLn(lRegNumberIndexFile,',');
          WriteLn(lStdRegIndexFile,',');
          WriteLn(lATTRegIndexFile,',');
          WriteLn(lIntRegIndexFile,',');
        end
      else
        lFirst:=false;
      WriteLn(lConstFile,Names[Index],' = ','TRegister(',Numbers[Index],')',';');
      write(lNumberFile,'TRegister(',Numbers[Index],')');
      write(lStdFile,'''',StdNames[Index],'''');
      write(lATTFile,'''',ATTNames[Index],'''');
      write(lIntFile,'''',IntNames[Index],'''');
      if IsX8664 then
        write(lDwarfFile,Dwarf64[Index])
      else if IsI8086 then
        write(lDwarfFile,Dwarf16[Index])
      else
        write(lDwarfFile,Dwarf32[Index]);
      write(lOTFile,OTs[Index]);
      write(lRegNumberIndexFile,RegNumberIndex[Index]);
      write(lStdRegIndexFile,StdRegNameIndex[Index]);
      write(lATTRegIndexFile,ATTRegNameIndex[Index]);
      write(lIntRegIndexFile,IntRegNameIndex[Index]);
    end;
  write(lCountFile,RegCount);
  close(lConstFile);
  CloseInc(lNumberFile);
  CloseInc(lATTFile);
  CloseInc(lStdFile);
  CloseInc(lIntFile);
  CloseInc(lDwarfFile);
  CloseInc(lOTFile);
  CloseInc(lCountFile);
  CloseInc(lRegNumberIndexFile);
  CloseInc(lStdRegIndexFile);
  CloseInc(lATTRegIndexFile);
  CloseInc(lIntRegIndexFile);
  WriteLn('Done!');
  WriteLn(RegCount,' registers processed');
end;


begin
   WriteLn('Register Table Converter Version ',cVersion);
   if paramcount=0 then
     begin
       IsI8086:=false;
       IsX8664:=false;
     end
   else
     begin
       IsI8086:=ParamStr(1)='i8086';
       IsX8664:=ParamStr(1)='x86_64';
       if (paramcount<>1) or
          ((ParamStr(1)<>'i8086') and (ParamStr(1)<>'i386') and (ParamStr(1)<>'x86_64')) then
         begin
           WriteLn('Usage: ',ParamStr(0));
           WriteLn('Only one optional parameter is allowed: i8086, i386 or x86_64');
           halt(1);
         end;
     end;
   if IsX8664 then
     begin
       FilePrefix:='r8664';
       WriteLn('Processing for CPU x86_64');
     end
   else if IsI8086 then
     begin
       FilePrefix:='r8086';
       WriteLn('Processing for CPU i8086');
     end
   else
     begin
       FilePrefix:='r386';
       WriteLn('Processing for CPU i386');
     end;
   Line:=0;
   RegCount:=0;
   ReadX86RegFile;
   RegCountBSStart:=1;
   while 2*RegCountBSStart<RegCount do
     RegCountBSStart:=RegCountBSStart*2;
   BuildRegNumIndex;
   BuildIntRegNameIndex;
   BuildStdRegNameIndex;
   BuildATTRegNameIndex;
   WriteIncFiles;
end.
