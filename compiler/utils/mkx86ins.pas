{
    Copyright (c) 1998-2002 by Peter Vreman and Florian Klaempfl

    Convert i386ins.dat from Nasm to a .inc file for usage with
    the Free pascal compiler

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{$mode objfpc}
program mkx86ins;

const
  cVersion = '1.6.2';
  cMaxOperands = 4;
var
   LineText : ShortString;
   Index : LongInt;
   IsI8086  : Boolean;
   IsX8664 : Boolean;

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


function FormatOp(AText:ShortString;AAllowSizeOnly:Boolean):ShortString;
   const
     cReplacementCount=29;
     cReplacementTable : array[1..cReplacementCount,1..2] of String[32]=(
       (':',' or ot_colon'),
       ('reg','regnorm'),
       ('regmem','rm_gpr'),
       ('rm8','rm_gpr or ot_bits8'),
       ('rm16','rm_gpr or ot_bits16'),
       ('rm32','rm_gpr or ot_bits32'),
       ('rm64','rm_gpr or ot_bits64'),
       ('rm80','rm_gpr or ot_bits80'),
       ('mem8','memory or ot_bits8'),
       ('mem16','memory or ot_bits16'),
       ('mem32','memory or ot_bits32'),
       ('mem64','memory or ot_bits64'),
       ('mem128','memory or ot_bits128'),
       ('mem256','memory or ot_bits256'),
       ('mem512','memory or ot_bits512'),
       ('mem80','memory or ot_bits80'),
       ('mem','memory'),
       ('memory_offs','mem_offs'),
       ('imm8','immediate or ot_bits8'),
       ('imm16','immediate or ot_bits16'),
       ('imm32','immediate or ot_bits32'),
       ('imm64','immediate or ot_bits64'),
       ('imm80','immediate or ot_bits80'),
       ('imm','immediate'),
       ('8','bits8'),
       ('16','bits16'),
       ('32','bits32'),
       ('64','bits64'),
       ('80','bits80')
     );
  var
    lIndex : LongInt;
  begin
    for lIndex:=1to cReplacementCount do
      begin
        if AText=cReplacementTable[lIndex,1] then
          begin
            AText:=cReplacementTable[lIndex,2];
            break;
          end;
      end;
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
  WriteLn(AFile,'{ don''t edit, this file is generated from x86ins.dat }');
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
   ATTSuffixFile,PropertyFile,OpcodeFile,
   OpcodeCountFile,ATTFile,IntFile,
   InputFile,InstructionFile : Text;
   { instruction fields }
   Skip : Boolean;
   LiteralCount,
   OperandCount    : LongInt;
   IntOpcode,
   ATTOpcode,
   Opcode,
   Codes,
   Flags   : ShortString;
   OperandTypes : array[1..cMaxOperands] of ShortString;
   InstructionChanges: ShortString;
   InstructionWritten: Boolean;
   SignCheck: Cardinal;
   StrSearch: Integer;

const
  cSignedInt = ' or ot_signed';


procedure DoWriteInstr;
begin
  if FirstOpcode then
    FirstOpcode:=false
  else
    begin
      WriteLn(OpcodeFile,',');
      WriteLn(ATTFile,',');
      WriteLn(ATTSuffixFile,',');
      WriteLn(IntFile,',');
      WriteLn(PropertyFile,',');
    end;
  write(OpcodeFile,Opcode);
  write(IntFile,'''',IntOpcode,'''');
  write(ATTFile,'''',ATTOpcode,'''');
  write(ATTSuffixFile,ATTSuffix);
  write(PropertyFile,'(Ch: ',InstructionChanges,')');
end;

begin
   WriteLn('Nasm Instruction Table Converter Version ',cVersion);
   IsI8086:=ParamStr(1)='i8086';
   IsX8664:=ParamStr(1)='x86_64';
   InstructionCount:=0;
   MaxInfoLength:=0;
   { open dat file }
   assign(InputFile,'../x86/x86ins.dat');
   if IsX8664 then
     begin
       { create inc files }
       OpenInc(InstructionFile,'x8664tab.inc');
       OpenInc(OpcodeFile,'x8664op.inc');
       assign(OpcodeCountFile,'x8664nop.inc');
       OpenInc(ATTFile,'x8664att.inc');
       OpenInc(ATTSuffixFile,'x8664ats.inc');
       OpenInc(IntFile,'x8664int.inc');
       OpenInc(PropertyFile,'x8664pro.inc');
     end
   else if IsI8086 then
     begin
       { create inc files }
       OpenInc(InstructionFile,'i8086tab.inc');
       OpenInc(OpcodeFile,'i8086op.inc');
       assign(OpcodeCountFile,'i8086nop.inc');
       OpenInc(ATTFile,'i8086att.inc');
       OpenInc(ATTSuffixFile,'i8086atts.inc');
       OpenInc(IntFile,'i8086int.inc');
       OpenInc(PropertyFile,'i8086prop.inc');
     end
   else
     begin
       { create inc files }
       OpenInc(InstructionFile,'i386tab.inc');
       OpenInc(OpcodeFile,'i386op.inc');
       assign(OpcodeCountFile,'i386nop.inc');
       OpenInc(ATTFile,'i386att.inc');
       OpenInc(ATTSuffixFile,'i386atts.inc');
       OpenInc(IntFile,'i386int.inc');
       OpenInc(PropertyFile,'i386prop.inc');
     end;
   rewrite(OpcodeCountFile);
   WriteLn(OpcodeCountFile,'{ don''t edit, this file is generated from x86ins.dat }');
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
              IntOpcode:=Copy(LineText,2,IndexJ-2);
              { Conditional }
              if (IntOpcode[length(IntOpcode)]='c') and
                 (IntOpcode[length(IntOpcode)-1]='c') then
                dec(Byte(IntOpcode[0]),2);
              ATTOpcode:=IntOpcode;
              ATTSuffix:='attsufNONE';
            end
           else
            begin
              SignCheck := 0;
              Opcode:='A_'+Copy(LineText,2,Index-2);
              IntOpcode:=Copy(LineText,2,Index-2);
              { intel conditional }
              if (IntOpcode[length(IntOpcode)]='c') and
                 (IntOpcode[length(IntOpcode)-1]='c') then
                dec(Byte(IntOpcode[0]),2);
              ATTOpcode:=Copy(LineText,Index+1,IndexJ-Index-1);
              { att Suffix }
              case ATTOpcode[length(ATTOpcode)] of
                'M' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufMM';
                  end;
                'N' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufMMX';
                  end;
                'S' :
		  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufMMS';
		  end;
                'X' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufINT';
                  end;
                'Y' :
                  begin
                    dec(ATTOpcode[0]);
                    ATTSuffix:='attsufINTdual';
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
           IntOpcode:=Lower(IntOpcode);
           ATTOpcode:=Lower(ATTOpcode);
           InstructionWritten:=false;

           { read the next line which contains the Change options }
           repeat
             readln(InputFile,InstructionChanges);
           until eof(InputFile) or ((InstructionChanges<>'') and (InstructionChanges[1]<>';'));
           InstructionChanges[1]:='[';
           InstructionChanges[length(InstructionChanges)]:=']';
           continue;
         end;
        { we must have an opcode }
        if Opcode='' then
         runerror(234);
        { clear }
        OperandCount:=0;
        for Index:=low(OperandTypes) to high(OperandTypes) do
          OperandTypes[Index]:='';
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
          OperandTypes[OperandCount]:=OperandTypes[OperandCount]+'ot_'+FormatOp(TempText,false);
          while LineText[Index]='|' do
            begin
               inc(Index);
               OperandTypes[OperandCount]:=OperandTypes[OperandCount]+' or ot_'+FormatOp(ReadStr,true);
            end;
          if LineText[Index] in [',',':'] then
            inc(Index)
          else
            break;
        until false;
        for IndexJ:=1 to cMaxOperands-OperandCount do
          OperandTypes[cMaxOperands-IndexJ+1]:='ot_none';
        { codes }
        SkipSpace;
        IndexJ:=0;
        LiteralCount:=0;
        if LineText[Index] in ['\','0'..'9'] then
          begin
             while not(LineText[Index] in [' ',#9]) do
               begin
                 Code:=ReadNumber;
                 { for some codes we want also to change the optypes, but not
                   if the code belongs to a literal sequence }
                 if (LiteralCount=0) and (Code>=1) and (Code<=3) then
                   LiteralCount:=Code
                 else
                   begin
                     if LiteralCount>0 then
                       dec(LiteralCount)
                     else
                       begin
                         case Code of
                           12,13,14:    {signed byte}
                             OperandTypes[Code-11]:=OperandTypes[Code-11]+cSignedInt;
                           172,173,174: {signed long}
                           begin
                             { Addition by J. Gareth "Kit" Moreton }
                             { See below for workaround for routines that take a 64-bit destination but a 32-bit operand in a non-decorated opcode }
                             SignCheck := Code-171;
                             OperandTypes[SignCheck]:=OperandTypes[SignCheck]+cSignedInt;
                           end;
                         end;
                       end;
                   end;
                 Codes:=Codes+'#'+ToStr(Code);
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
             if TempText='none' then
               break;
             if IsX8664 then
               begin
                 { x86_64 }
                 if (upcase(TempText)='NOX86_64') or (upcase(TempText)='16BITONLY') then
                   Skip:=true;
               end
             else if not IsI8086 then
               begin
                 { i386 }
                 if (upcase(TempText)='X86_64') or (upcase(TempText)='16BITONLY') then
                   Skip:=true;
               end
             else
               begin
                 { i8086 }
                 if (upcase(TempText)='X86_64') then
                   Skip:=true;
               end;
             if TempText<>'ND' then
              begin
                { Addition by J. Gareth "Kit" Moreton }
                { Workaround for routines that take a 64-bit destination but a 32-bit operand in a non-decorated opcode }
                if (Lower(TempText)='sm') and (SignCheck > 0) then
                 begin
                   { Remove signed flag }
                   StrSearch := Pos(cSignedInt, OperandTypes[SignCheck]);
                   Delete(OperandTypes[SignCheck], StrSearch, Length(cSignedInt));
                 end;

                  if Flags<>'' then
                   Flags:=Flags+',';
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
            if not InstructionWritten then
              DoWriteInstr;
            InstructionWritten:=true;
            if not(First) then
              WriteLn(InstructionFile,',')
            else
              First:=false;
            WriteLn(InstructionFile,'  (');
            WriteLn(InstructionFile,'    opcode  : ',Opcode,';');
            WriteLn(InstructionFile,'    ops     : ',OperandCount,';');
            WriteLn(InstructionFile,'    optypes : (',OperandTypes[1],',',OperandTypes[2],',',OperandTypes[3],',',OperandTypes[4],');');
            WriteLn(InstructionFile,'    code    : ',Codes,';');
            WriteLn(InstructionFile,'    flags   : [',Flags,']');
            write(InstructionFile,'  )');
            inc(InstructionCount);
          end;
     end;
   close(InputFile);
   CloseInc(InstructionFile);
   CloseInc(IntFile);
   CloseInc(ATTFile);
   CloseInc(ATTSuffixFile);
   CloseInc(OpcodeFile);
   WriteLn(OpcodeCountFile,InstructionCount,';');
   close(OpcodeCountFile);
   CloseInc(PropertyFile);
   WriteLn(InstructionCount,' nodes processed (maxinfolen=',MaxInfoLength,')');
end.
