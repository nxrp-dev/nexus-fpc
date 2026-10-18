{
    Copyright (c) 1998-2005 by Peter Vreman and Florian Klaempfl

    Convert i386ins.dat from Nasm to a .inc file for usage with
    the Free pascal compiler

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}

program mka64ins;

const
  cVersion = '0.9';

var
   LineText : ShortString;
   Index : LongInt;

    function Lower(const AText : ShortString) : ShortString;
    {
      return lowercased string of s
    }
      var
         lIndex : LongInt;
      begin
         for lIndex:=1 to length(AText) do
          if AText[lIndex] in ['A'..'Z'] then
           Lower[lIndex]:=Char(Byte(AText[lIndex])+32)
          else
           Lower[lIndex]:=AText[lIndex];
         Lower[0]:=AText[0];
      end;

      function Replace(var AText:ShortString;const AOldText,ANewText:ShortString):Boolean;
      var
        lIndex  : LongInt;
      begin
        lIndex:=pos(AOldText,AText);
        if lIndex>0 then
         begin
           Delete(AText,lIndex,length(AOldText));
           Insert(ANewText,AText,lIndex);
           Replace:=true;
         end
        else
         Replace:=false;
      end;


function FormatOp(AText:ShortString):ShortString;
   const
     cReplacementCount=19;
     cReplacementTable : array[1..cReplacementCount,1..2] of String[32]=(
       (':',' or ot_colon'),
       ('mem8','mem or ot_bits8'),
       ('mem16','mem or ot_bits16'),
       ('mem32','mem or ot_bits32'),
       ('mem64','mem or ot_bits64'),
       ('mem80','mem or ot_bits80'),
       ('mem','memory'),
       ('memory_offs','mem_offs'),
       ('imm8','imm or ot_bits8'),
       ('imm16','imm or ot_bits16'),
       ('imm32','imm or ot_bits32'),
       ('imm64','imm or ot_bits64'),
       ('imm80','imm or ot_bits80'),
       ('imm','immediate'),
       ('rm8','regmem or ot_bits8'),
       ('rm16','regmem or ot_bits16'),
       ('rm32','regmem or ot_bits32'),
       ('rm64','regmem or ot_bits64'),
       ('rm80','regmem or ot_bits80')
     );
  var
    lIndex : LongInt;
  begin
    for lIndex:=1to cReplacementCount do
     Replace(AText,cReplacementTable[lIndex,1],cReplacementTable[lIndex,2]);
    FormatOp:=AText;
  end;


function ReadNumber : LongInt;

  var
     lBase : LongInt;

  begin
     Result:=0;
     if LineText[Index]='\' then
       begin
          lBase:=8;
          inc(Index);
          if LineText[Index]='x' then
            begin
               lBase:=16;
               inc(Index);
            end;
       end
     else
       lBase:=10;
     LineText[Index]:=upcase(LineText[Index]);
     while LineText[Index] in ['0'..'9','A'..'F'] do
       begin
          case LineText[Index] of
             '0'..'9':
               Result:=Result*lBase+ord(LineText[Index])-ord('0');

             'A'..'F':
               Result:=Result*lBase+ord(LineText[Index])-ord('A')+10;
          end;
          inc(Index);
       end;
  end;

 function ToStr(AValue : LongInt) : ShortString;

  var
      lText : ShortString;

  begin
     str(AValue,lText);
     ToStr:=lText;
  end;

 function ReadStr : ShortString;

  begin
     Result:='';
     while (LineText[Index] in ['0'..'9','A'..'Z','a'..'z','_']) and (Index<=length(LineText)) do
       begin
          Result:=Result+LineText[Index];
          inc(Index);
       end;
  end;

procedure SkipSpace;

  begin
     while (LineText[Index] in [' ',#9]) do
       inc(Index);
  end;

 procedure OpenInc(out AFile:Text;const AFileName:ShortString);
begin
  WriteLn('creating ',AFileName);
  assign(AFile,AFileName);
  rewrite(AFile);
  WriteLn(AFile,'{ don''t edit, this file is generated from a64ins.dat }');
  WriteLn(AFile,'(');
end;


procedure CloseInc(var AFile:Text);
begin
  WriteLn(AFile);
  WriteLn(AFile,');');
  close(AFile);
end;


var
   ATTSuffix,
    TempText : ShortString;
   IndexJ : LongInt;
   FirstOpcode,
   First : Boolean;
   MaxInfoLength,
   Code : Byte;
   InstructionCount : LongInt;
   ATTSuffixFile,{propfile,}OpcodeFile,
   OpcodeCountFile,ATTFile,
   InputFile,InstructionFile : Text;
   { instruction fields }
   Skip : Boolean;
   {last,}
   OperandCount    : LongInt;
   ATTOpcode,
   Opcode,
   Codes,
    Flags   : ShortString;
    OperandTypes : array[1..4] of ShortString;
begin
   WriteLn('FPC Instruction Table Converter Version ',cVersion);
   WriteLn('Based on Narm Instruction Table Converter ');
   InstructionCount:=0;
   MaxInfoLength:=0;
   { open dat file }
   assign(InputFile,'../aarch64/a64ins.dat');
   { create inc files }
   OpenInc(InstructionFile,'a64tab.inc');
   OpenInc(OpcodeFile,'a64op.inc');
   assign(OpcodeCountFile,'a64nop.inc');
   OpenInc(ATTFile,'a64att.inc');
   OpenInc(ATTSuffixFile,'a64atts.inc');
   rewrite(OpcodeCountFile);
   WriteLn(OpcodeCountFile,'{ don''t edit, this file is generated from a64ins.dat }');
   reset(InputFile);
   First:=true;
   Opcode:='';
   FirstOpcode:=true;
   while not(eof(InputFile)) do
     begin
        { handle comment }
        readln(InputFile,LineText);
        while (LineText<>'') and (LineText[1]=' ') do
         delete(LineText,1,1);
        if (LineText='') or (LineText[1]=';') then
          continue;
        if (LineText[1]='[') then
         begin
           Index:=pos(',',LineText);
           IndexJ:=pos(']',LineText);
           if Index=0 then
            begin
              Opcode:='A_'+Copy(LineText,2,IndexJ-2);
              ATTOpcode:=Copy(LineText,2,IndexJ-2);
              { Conditional }
              if (ATTOpcode[length(ATTOpcode)]='c') and
                 (ATTOpcode[length(ATTOpcode)-1]='c') then
                begin
                  dec(Byte(ATTOpcode[0]),2);
                  dec(Byte(Opcode[0]),2);
                end;
              ATTSuffix:='attsufNONE';
            end
           else
            begin
              Opcode:='A_'+Copy(LineText,2,Index-2);
              { intel conditional }
              if (Opcode[length(ATTOpcode)]='c') and
                 (Opcode[length(ATTOpcode)-1]='c') then
                dec(Byte(Opcode[0]),2);
              ATTOpcode:=Copy(LineText,Index+1,IndexJ-Index-1);
              { att Suffix }
              case ATTOpcode[length(ATTOpcode)] of
                'X' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufINT';
                  end;
                'F' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufFPU';
                  end;
                'R' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufFPUint';
                  end;
                else
                  ATTSuffix:='attsufNONE';
              end;
              { att Conditional }
              if (ATTOpcode[length(ATTOpcode)]='C') and
                 (ATTOpcode[length(ATTOpcode)-1]='C') then
                dec(Byte(ATTOpcode[0]),2);
            end;
           ATTOpcode:=Lower(ATTOpcode);
           if FirstOpcode then
            FirstOpcode:=false
           else
            begin
              WriteLn(OpcodeFile,',');
              WriteLn(ATTFile,',');
              WriteLn(ATTSuffixFile,',');
{              writeln(propfile,','); }
            end;
           write(OpcodeFile,Opcode);
           write(ATTFile,'''',ATTOpcode,'''');
           write(ATTSuffixFile,ATTSuffix);
           { read the next line which contains the Change options }
           {
           repeat
             readln(infile,s);
           until eof(infile) or ((s<>'') and (s[1]<>';'));
           write(propfile,'(Ch: ',s,')');
           }
           continue;
         end;
        { we must have an opcode }
        if Opcode='' then
         runerror(234);
        { clear }
        OperandCount:=0;
        OperandTypes[1]:='';
        OperandTypes[2]:='';
        OperandTypes[3]:='';
        OperandTypes[4]:='';
        Codes:='';
        Flags:='';
        Skip:=false;
        { ops and optypes }
        Index:=1;
        repeat
          TempText:=ReadStr;
          if (TempText='void') or (TempText='ignore') then
            break;
          inc(OperandCount);
          OperandTypes[OperandCount]:=OperandTypes[OperandCount]+'ot_'+FormatOp(TempText);
{          if s[i]=':' then
            begin
               inc(i);
               optypes[ops]:=optypes[ops]+' or ot_'+formatop(readstr);
            end;}
          while LineText[Index]='|' do
            begin
               inc(Index);
               OperandTypes[OperandCount]:=OperandTypes[OperandCount]+' or ot_'+FormatOp(ReadStr);
            end;
          if LineText[Index] in [',',':'] then
            inc(Index)
          else
            break;
        until false;
        for IndexJ:=1 to 4-OperandCount do
          OperandTypes[4-IndexJ+1]:='ot_none';
        { codes }
        SkipSpace;
        IndexJ:=0;
(*        last:=0;*)
        if LineText[Index] in ['\','0'..'9'] then
          begin
             while not(LineText[Index] in [' ',#9]) do
               begin
                 Code:=ReadNumber;
(*
                 { for some codes we want also to change the optypes, but not
                   if the last byte was a 1 then this byte belongs to a direct
                   copy }
                 if last<>1 then
                  begin
                    case code of
                      12,13,14 :
                        optypes[code-11]:=optypes[code-11]+' or ot_signed';
                    end;
                  end;
*)
                 Codes:=Codes+'#'+ToStr(Code);
(*                 last:=code;*)
                 inc(IndexJ);
               end;
          end
        else
          begin
            ReadStr;
            Codes:='#0';
          end;
        if IndexJ>MaxInfoLength then
         MaxInfoLength:=IndexJ;
        { flags }
        SkipSpace;
        while not(LineText[Index] in [' ',#9,#13,#10]) and (Index<=length(LineText)) do
          begin
             TempText:=ReadStr;
             if TempText<>'ND' then
              begin
                if Flags<>'' then
                 Flags:=Flags+' or ';
                Flags:=Flags+'if_'+Lower(TempText);
              end;
             if (LineText[Index]=',') and (Index<=length(LineText)) then
              inc(Index)
             else
              break;
          end;
        { write instruction }
        if not Skip then
          begin
            if not(First) then
              WriteLn(InstructionFile,',')
            else
              First:=false;
            WriteLn(InstructionFile,'  (');
            WriteLn(InstructionFile,'    opcode  : ',Opcode,';');
            WriteLn(InstructionFile,'    ops     : ',OperandCount,';');
            WriteLn(InstructionFile,'    optypes : (',OperandTypes[1],',',OperandTypes[2],',',OperandTypes[3],',',OperandTypes[4],');');
            WriteLn(InstructionFile,'    code    : ',Codes,';');
            WriteLn(InstructionFile,'    flags   : ',Flags);
            write(InstructionFile,'  )');
            inc(InstructionCount);
          end;
     end;
   close(InputFile);
   CloseInc(InstructionFile);
   CloseInc(ATTFile);
   CloseInc(ATTSuffixFile);
   CloseInc(OpcodeFile);
   WriteLn(OpcodeCountFile,InstructionCount,';');
   close(OpcodeCountFile);
{   closeinc(propfile); }
   WriteLn(InstructionCount,' nodes processed (maxinfolen=',MaxInfoLength,')');
end.
