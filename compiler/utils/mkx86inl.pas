program mkx86inl;

{$mode objfpc}
{$H+}

uses
  SysUtils, Classes;

type
  TOperDirection = (operIn, operVar, operOut);

  TOperand = record
    Name,
    Typ: String;
    Direction: TOperDirection;
  end;

const
  cDirectionLookup: array[TOperDirection] of String = ('','var ','out ');

{ ***************************************************************************
  the routines Copy2SymbDel, PosSetEx, PosSet, RemoveTrailingChars, TrimRightSet are copied and reformatted
  from StrUtils and thus covered by the copyright of strutils (see below) as compiler utilities cannot
  depend on packages

    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2005 by the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*************************************************************************** }

function Copy2SymbDel(var AText: String; ASymbol: Char): String;
  var
    lPosition: SizeInt;
  begin
    lPosition:=Pos(ASymbol,AText);
    if lPosition=0 then
      begin
        Result:=AText;
        AText:='';
      end
    else
      begin
        Result:=Copy(AText,1,lPosition-1);
        delete(AText,1,lPosition);
      end;
  end;


function PosSetEx(const ACharSet: TSysCharSet; const AText: AnsiString; ACount: Integer): SizeInt;
  var
    lLength,lIndex:SizeInt;
  begin
   if PChar(Pointer(AText))=nil then
    lIndex:=0
   else
    begin
     lLength:=length(AText);
     lIndex:=ACount;
     if lIndex>lLength then
      begin
       Result:=0;
       exit;
      end;
     while (lIndex<=lLength) and (not (AText[lIndex] in ACharSet)) do inc(lIndex);
     if (lIndex>lLength) then
      lIndex:=0;                                         // not found.
    end;
   Result:=lIndex;
  end;

function PosSet(const ACharSet: TSysCharSet; const AText: AnsiString): SizeInt;
  begin
    Result:=PosSetEx(ACharSet,AText,1);
  end;

procedure RemoveTrailingChars(VAR AText: AnsiString; const ACharSet: TSysCharSet);
  var
    lLength,lLastIndex: LongInt;

  Begin
   lLength:=Length(AText);
   IF (lLength>0) Then
    Begin
     lLastIndex:=lLength;
     While (lLastIndex>0) and (AText[lLastIndex] IN ACharSet) DO DEC(lLastIndex);
     IF lLastIndex<>lLength Then
      SetLength(AText,lLastIndex);
    End;
  End;

function TrimRightSet(const AText: String; const ACharSet: TSysCharSet): String;

begin
  Result:=AText;
  RemoveTrailingChars(Result,ACharSet);
end;

{ ***************************************************************************
   end of StrUtils code
  ***************************************************************************}

function GetPascalType(const AType: String): String;
  begin
    case AType of
      'r8':    exit('byte');
      'rs8':   exit('shortint');
      'r16':   exit('word');
      'rs16':  exit('smallint');
      'r32':   exit('LongWord');
      'rs32':  exit('LongInt');
      'r64':   exit('qword');
      'rs64':  exit('int64');
      'reg':   exit('NativeUInt');
      'sreg':  exit('NativeInt');
      'f32':   exit('single');
      'f64':   exit('double');
      'mm':    exit('__m64');
      'implicit_xmm0',
      'xmm':   exit('__m128');
      'i32':   exit('LongInt');

      'edi_ptr':   exit('pointer');

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128': exit('pointer');
    else
      exit(AType);
    end;
  end;

function GetTypeDef(const AType: String): String;
  begin
    case AType of
      'r8':    exit('U8IntType');
      'rs8':   exit('S8IntType');
      'r16':   exit('U16IntType');
      'rs16':  exit('S16IntType');
      'r32':   exit('U32IntType');
      'rs32':  exit('S32IntType');
      'r64':   exit('U64IntType');
      'rs64':  exit('S64IntType');
      'reg':   exit('UIntType');
      'sreg':  exit('SIntType');
      'f32':   exit('S32FloatType');
      'f64':   exit('S64FloatType');
      'mm':    exit('X86_M64Type');
      'implicit_xmm0',
      'xmm':   exit('X86_M128Type');
      'i32':   exit('S32IntType');

      'edi_ptr':   exit('VoidPointerType');

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128': exit('VoidPointerType');
    else
      exit(AType);
    end;
  end;

function GetOper(const AType: String): String;
  begin
    case AType of
      'r8':    exit('_reg');
      'rs8':   exit('_reg');
      'r16':   exit('_reg');
      'rs16':  exit('_reg');
      'r32':   exit('_reg');
      'rs32':  exit('_reg');
      'r64':   exit('_reg_reg');
      'rs64':  exit('_reg_reg');
      'reg':   exit('_reg');
      'sreg':  exit('_reg');
      'f32':   exit('_reg');
      'f64':   exit('_reg');
      'mm':    exit('_reg');
      'xmm':   exit('_reg');
      'i32':   exit('_const');

      'implicit_xmm0',
      'edi_ptr':   exit('');

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128': exit('_ref');
    else
      exit('');
    end;
  end;

function GetOperand(const AType: String; AIndex: LongInt): String;
  begin
    case AType of
      'r8':    exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'rs8':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'r16':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'rs16':  exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'r32':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'rs32':  exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'r64':   exit(format(',lParaArray[%d].Location.Register64.RegLo,lParaArray[%d].Location.Register64.RegHi', [AIndex,AIndex]));
      'rs64':  exit(format(',lParaArray[%d].Location.Register64.RegLo,lParaArray[%d].Location.Register64.RegHi', [AIndex,AIndex]));
      'reg':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'sreg':  exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'f32':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'f64':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'mm':    exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'xmm':   exit(format(',lParaArray[%d].Location.Register', [AIndex]));
      'i32':   exit(format(',GetConstInt(lParaArray[%d])',[AIndex]));

      'implicit_xmm0',
      'edi_ptr': exit('');

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128': exit(format(',lParaArray[%d].Location.Reference', [AIndex]));
    else
      exit(AType);
    end;
  end;

function GetOperandLoc(const AType: String): String;
  begin
    Result:='';
    case AType of
      'r8':   exit(',Location.Register');
      'rs8':  exit(',Location.Register');
      'r16':  exit(',Location.Register');
      'rs16': exit(',Location.Register');
      'r32':  exit(',Location.Register');
      'rs32': exit(',Location.Register');
      'r64':  exit(',Location.Register64.RegLo,Location.Register64.RegHi');
      'rs64': exit(',Location.Register64.RegLo,Location.Register64.RegHi');
      'reg':  exit(',Location.Register');
      'sreg': exit(',Location.Register');
      'f32':  exit(',Location.Register');
      'f64':  exit(',Location.Register');
      'mm':   exit(',Location.Register');
      'implicit_xmm0',
      'xmm':  exit(',Location.Register');

      'edi_ptr': exit(',Location.Register');

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128': exit(',Location.Register');
    end;
  end;

function GetLocStatement(AIndex: LongInt; const AType: String; AConst: Boolean): String;
  begin
    Result:='';
    case AType of
      'r8':    exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U8IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'rs8':   exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U8IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'r16':   exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U16IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'rs16':  exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U16IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'r32':   exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U32IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'rs32':  exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U32IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'r64':   exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U64IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'rs64':  exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,U64IntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'reg':   exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,UIntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'sreg':  exit(format('hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, lParaArray[%d].ResultDef,SIntType,%s);', [AIndex+1, AIndex+1, BoolToStr(AConst,'true','false')]));
      'f32':   exit(format('Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, %s);', [AIndex+1, BoolToStr(AConst,'true','false')]));
      'f64':   exit(format('Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, %s);', [AIndex+1, BoolToStr(AConst,'true','false')]));
      'mm':    exit(format('LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, %s);', [AIndex+1, BoolToStr(AConst,'true','false')]));
      'xmm':   exit(format('Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, %s);', [AIndex+1, BoolToStr(AConst,'true','false')]));

      'implicit_xmm0':
        exit(format('Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[%d].Location, %s);'+LineEnding+
                    '    hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);'+LineEnding+
                    '    hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[%d].ResultDef,X86_M128Type,lParaArray[%d].Location,NR_XMM0,nil);',
                      [AIndex+1, BoolToStr(AConst,'true','false'), AIndex+1, AIndex+1]));
      'edi_ptr':
        exit(format('hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});'+LineEnding+
                    '    hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[%d].ResultDef,VoidPointerType,lParaArray[%d].Location,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});',
                      [AIndex+1, AIndex+1]));

      'ptr8',
      'ptr16',
      'ptr32',
      'ptr64',
      'ptr128':exit(format('LocationMakeRef(lParaArray[%d].Location);', [AIndex+1]));
    end;
  end;

function GetDeallocStatement(AIndex: LongInt; const AType: String): String;
  begin
    Result:='';
    case AType of
      'implicit_xmm0':
        exit('hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);');
      'edi_ptr':
        exit('hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});');
    end;
  end;

function GetLoc(const AType: String; AWithSize: Boolean = true): String;
  begin
    Result:='';
    if AWithSize then
      case AType of
        'r8':    exit('LOC_REGISTER,OS_8');
        'rs8':   exit('LOC_REGISTER,OS_S8');
        'r16':   exit('LOC_REGISTER,OS_16');
        'rs16':  exit('LOC_REGISTER,OS_S16');
        'r32':   exit('LOC_REGISTER,OS_32');
        'rs32':  exit('LOC_REGISTER,OS_S32');
        'r64':   exit('LOC_REGISTER,OS_64');
        'rs64':  exit('LOC_REGISTER,OS_S64');
        'reg':   exit('LOC_REGISTER,OS_INT');
        'sreg':  exit('LOC_REGISTER,OS_SINT');
        'f32':   exit('LOC_MMREGISTER,OS_M128');
        'f64':   exit('LOC_MMREGISTER,OS_M128');
        'mm':    exit('LOC_MMXREGISTER,OS_M64');
        'implicit_xmm0',
        'xmm':   exit('LOC_MMREGISTER,OS_M128');

        'edi_ptr':   exit('LOC_REGISTER,OS_INT');

        'ptr8':  exit('LOC_MEM,OS_8');
        'ptr16': exit('LOC_MEM,OS_16');
        'ptr32': exit('LOC_MEM,OS_32');
        'ptr64': exit('LOC_MEM,OS_64');
        'ptr128':exit('LOC_MEM,OS_128');
      end
    else
      case AType of
        'r8':    exit('LOC_REGISTER');
        'rs8':   exit('LOC_REGISTER');
        'r16':   exit('LOC_REGISTER');
        'rs16':  exit('LOC_REGISTER');
        'r32':   exit('LOC_REGISTER');
        'rs32':  exit('LOC_REGISTER');
        'r64':   exit('LOC_REGISTER');
        'rs64':  exit('LOC_REGISTER');
        'reg':   exit('LOC_REGISTER');
        'sreg':  exit('LOC_REGISTER');
        'f32':   exit('LOC_MMREGISTER');
        'f64':   exit('LOC_MMREGISTER');
        'mm':    exit('LOC_MMXREGISTER');
        'implicit_xmm0',
        'xmm':   exit('LOC_MMREGISTER');

        'edi_ptr':   exit('LOC_REGISTER');

        'ptr8',
        'ptr16',
        'ptr32',
        'ptr64',
        'ptr128':exit('LOC_MEM');
      end;
  end;

function GetLocAllocation(const AType: String): String;
  begin
    Result:='';
    case AType of
      'r8':  exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_8);');
      'rs8': exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_8);');
      'r16':  exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_16);');
      'rs16': exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_16);');
      'r32':  exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);');
      'rs32': exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);');
      'r64':  exit('Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32); Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);');
      'rs64': exit('Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32); Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);');
      'reg':  exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);');
      'sreg': exit('Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);');
      'f32':  exit('Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);');
      'f64':  exit('Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);');
      'mm':   exit('Location.Register:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);');
      'xmm':  exit('Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);');
    end;
  end;

function GetPostFix(const APF: String): String;
  begin
    if APF<>'' then
      Result:='PF_'+APF
    else
      Result:='PF_None';
  end;

procedure ParseList(const APrefix, AFileName: String);
  var
    lFile: TextFile;

    lProcsFile,
    lCompilerInlineFile, lCPUInlineFile: TextFile;
    lTypeCheckLines, lFirstPassLines, lSecondPassLines: TStringList;

    lText,
    lInstructionPart,lPostfix,lAlias,
    lParams, lOperLine: String;

    lOperands: array[0..7] of TOperand;
    lOperandCount: LongInt;

    lHasOutput: Boolean;
    lOutputType: String;
    lCount,
    lIndex, lIntrinsicNumber: LongInt;
    lTemp, lCondition, lTarget: String;

  function ParseOperands(AIndex: LongInt = -1): String;
    var
      lOperandIndex: LongInt;
      lPosition: Integer;
      lChar: Char;
    begin
      lOperandIndex:=lOperandCount;

      lParams:=trim(lParams);
      if lParams='' then
        exit('');

      inc(lOperandCount);

      if pos('var ', lParams)=1 then
        begin
          lOperands[lOperandIndex].Direction:=operVar;
          Delete(lParams,1,4);
          lParams:=trim(lParams);
          lHasOutput:=true;
        end
      else if pos('out ', lParams)=1 then
        begin
          lOperands[lOperandIndex].Direction:=operOut;
          Delete(lParams,1,4);
          lParams:=trim(lParams);
          lHasOutput:=true;
        end
      else
        begin
          if AIndex<>-1 then
            lOperands[lOperandIndex].Direction:=lOperands[AIndex].Direction
          else
            lOperands[lOperandIndex].Direction:=operIn;
        end;

          lPosition:=PosSet([',',':'], lParams);

      lChar:=lParams[lPosition];
      lOperands[lOperandIndex].Name:=Copy2SymbDel(lParams, lChar);
      lParams:=trim(lParams);

      if lChar = ':' then
        begin
          lOperands[lOperandIndex].Typ:=Copy2SymbDel(lParams, ';');
          Result:=lOperands[lOperandIndex].Typ;
        end
      else
        begin
          lOperands[lOperandIndex].Typ:=ParseOperands(lOperandIndex);
          Result:=lOperands[lOperandIndex].Typ;
        end;

      if lOperands[lOperandIndex].Direction<>operIn then
        lOutputType:=lOperands[lOperandIndex].Typ;
    end;

  function GetOperLine: String;
    var
      lIndex: LongInt;
    begin
      Result:='';
      for lIndex := 0 to lOperandCount-1 do
        Result:=Result+cDirectionLookup[lOperands[lIndex].Direction]+lOperands[lIndex].Name+':'+lOperands[lIndex].Typ+';';
    end;

  function GetParams: LongInt;
    var
      lIndex: LongInt;
    begin
      Result:=0;
      for lIndex := 0 to lOperandCount-1 do
        if lOperands[lIndex].Direction in [operIn,operVar] then
          inc(Result);
    end;

  function FindOperIdx(const AOper: String): LongInt;
    var
      lIndex,lCount: LongInt;
    begin
      lCount:=0;
      Result:=0;
      for lIndex := 0 to lOperandCount-1 do
        if (lOperands[lIndex].Direction in [operIn,operVar]) then
          begin
            if lOperands[lIndex].Name=AOper then
              exit(lCount);
            inc(lCount);
          end;
    end;

  begin
    lIntrinsicNumber:=0;

    assignfile(lFile, AFileName);
    reset(lFile);

    assignfile(lProcsFile, 'cpummprocs.inc'); rewrite(lProcsFile);
    assignfile(lCompilerInlineFile, 'c'+APrefix+'mminnr.inc'); rewrite(lCompilerInlineFile);
    assignfile(lCPUInlineFile, 'cpumminnr.inc'); rewrite(lCPUInlineFile);

//    writeln(finnr,'const');

    lTypeCheckLines:=TStringList.Create;
    lFirstPassLines:=TStringList.Create;
    lSecondPassLines:=TStringList.Create;

//    writeln(finnr, '  fpc_in_', APrefix,'_first = fpc_in_',APrefix,'_base;');

    while not EOF(lFile) do
      begin
        readln(lFile, lText);

        lText:=trim(lText);

        if (lText='') or (Pos(';',lText)=1) then
          continue;

        lInstructionPart:=Copy2SymbDel(lText, '(');

        // Check for postfix
        if pos('{',lInstructionPart)>0 then
          begin
            lPostfix:=lInstructionPart;
            lInstructionPart:=Copy2SymbDel(lPostfix, '{');
            lPostfix:=TrimRightSet(lPostfix,['}']);
          end
        else
          lPostfix:='';

        // Check for alias
        if pos('[',lInstructionPart)>0 then
          begin
            lAlias:=lInstructionPart;
            lInstructionPart:=Copy2SymbDel(lAlias, '[');
            lAlias:='_'+TrimRightSet(lAlias,[']']);
          end
        else
          lAlias:='';

        // Get parameters
        lParams:=trim(Copy2SymbDel(lText,')'));
        lText:=trim(lText);

        // Parse condition and target
        if pos('|', lText)>0 then
        begin
          lCondition:=trim(Copy2SymbDel(lText, '|'));
          lTarget:=trim(lText);
        end
        else
        begin
          lCondition:=lText;
          lTarget:='';
        end;

        lHasOutput:=false;
        lOperandCount:=0;
        lOutputType:='';

        while lParams<>'' do
          ParseOperands;

        lOperLine:=GetOperLine;
        // Write typecheck code
        lIndex:=lTypeCheckLines.IndexOf(': //'+lOperLine);
        if (lIndex>=0) and (lTarget='') then
          lTypeCheckLines.Insert(lIndex,',in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias)
        else
          begin
            if lTarget<>'' then
              lTypeCheckLines.add(format('{$ifdef %s}', [lTarget]));

            lTypeCheckLines.Add('in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias);
            lTypeCheckLines.Add(': //'+lOperLine);
            lTypeCheckLines.Add('  begin');
            lTypeCheckLines.Add('    CheckParameters('+IntToStr(GetParams())+');');
            if lHasOutput then
              lTypeCheckLines.Add('    ResultDef:='+GetTypeDef(lOutputType)+';')
            else
              lTypeCheckLines.Add('    ResultDef:=VoidType;');
            lTypeCheckLines.Add('  end;');

            if lTarget<>'' then
              lTypeCheckLines.add('{$endif}');
          end;

        // Write firstpass code
        lIndex:=lFirstPassLines.IndexOf(': //'+lOperLine);
        if (lIndex>=0) and (lTarget='') then
          lFirstPassLines.Insert(lIndex,',in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias)
        else
          begin
            if lTarget<>'' then
              lFirstPassLines.add(format('{$ifdef %s}', [lTarget]));

            lFirstPassLines.Add('in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias);
            lFirstPassLines.Add(': //'+lOperLine);
            lFirstPassLines.Add('  begin');
            if lHasOutput then
              lFirstPassLines.Add('    ExpectLoc:='+GetLoc(lOutputType,false)+';')
            else
              lFirstPassLines.Add('    ExpectLoc:=LOC_VOID;');
            lFirstPassLines.Add('    Result:=nil;');
            lFirstPassLines.Add('  end;');

            if lTarget<>'' then
              lFirstPassLines.add('{$endif}');
          end;

        // Write secondpass code
        lIndex:=lSecondPassLines.IndexOf(': //'+lOperLine);
        if (lIndex>=0) and (lTarget='') then
          begin
            lSecondPassLines.Insert(lIndex+3,'      in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias+': begin lOp:=A_'+lInstructionPart+' end;');
            lSecondPassLines.Insert(lIndex,',in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias);
          end
        else
          begin
            if lTarget<>'' then
              lSecondPassLines.add(format('{$ifdef %s}', [lTarget]));

            lSecondPassLines.Add('in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias);
            lSecondPassLines.Add(': //'+lOperLine);
            lSecondPassLines.Add('  begin');
            lSecondPassLines.Add('    case InlineNumber of');
            lSecondPassLines.Add('      in_'+APrefix+'_'+lInstructionPart+lPostfix+lAlias+': begin lOp:=A_'+lInstructionPart+'; end;');
            lSecondPassLines.Add('      else');
            lSecondPassLines.Add('        InternalError(2020010201);');
            lSecondPassLines.Add('    end;');
            lSecondPassLines.Add('');

            lIndex:=GetParams;
            lSecondPassLines.Add('    GetParameters('+IntToStr(lIndex)+');');
            lSecondPassLines.Add('');

            lSecondPassLines.Add('    for lIndex := 1 to '+IntToStr(lIndex)+' do SecondPass(lParaArray[lIndex]);');
            lSecondPassLines.Add('');

            // Force inputs
            lCount:=0;
            for lIndex := 0 to lOperandCount-1 do
              begin
                case lOperands[lIndex].Direction of
                  operIn:
                    begin
                      lTemp:=GetLocStatement(lCount, lOperands[lIndex].Typ, true);
                      if lTemp<>'' then
                        lSecondPassLines.add('    '+lTemp);
                      inc(lCount);
                    end;
                  operVar:
                    begin
                      lTemp:=GetLocStatement(lCount, lOperands[lIndex].Typ, false);
                      if lTemp<>'' then
                        lSecondPassLines.add('    '+lTemp);
                      inc(lCount);
                    end;
                  else
                    ;
                end;
              end;

            // Allocate output
            lCount:=0;
            for lIndex := 0 to lOperandCount-1 do
              begin
                case lOperands[lIndex].Direction of
                  operOut:
                    begin
                      lSecondPassLines.add('    Location_Reset(Location,'+GetLoc(lOperands[lIndex].Typ)+');');
                      lSecondPassLines.Add('    '+GetLocAllocation(lOperands[lIndex].Typ));
                    end;
                  operVar:
                    begin
                      lSecondPassLines.Add('    Location:=lParaArray['+IntToStr(lCount+1)+'].Location;');
                      inc(lCount);
                    end;
                  operIn:
                    inc(lCount);
                end;
              end;

            lOperLine:='TAICPU.op';
            //for i := 0 to opercnt-1 do
            for lIndex := lOperandCount-1 downto 0 do
              begin
                case lOperands[lIndex].Direction of
                  operOut:
                    lOperLine:=lOperLine+GetOper(lOperands[lIndex].Typ);
                  operVar:
                    lOperLine:=lOperLine+GetOper(lOperands[lIndex].Typ);
                  operIn:
                    lOperLine:=lOperLine+GetOper(lOperands[lIndex].Typ);
                end;
              end;

            if lOperLine='TAICPU.op' then
              lOperLine:='TAICPU.op_none(lOp,S_NO'
            else
              lOperLine:=lOperLine+'(lOp,S_NO';

            //for i := 0 to opercnt-1 do
            for lIndex := lOperandCount-1 downto 0 do
              begin
                case lOperands[lIndex].Direction of
                  operOut:
                    lOperLine:=lOperLine+GetOperandLoc(lOperands[lIndex].Typ);
                  operIn,
                  operVar:
                    begin
                      dec(lCount);
                      lOperLine:=lOperLine+GetOperand(lOperands[lIndex].Typ, lCount+1);
                    end;
                end;
              end;

            lOperLine:=lOperLine+')';

            lSecondPassLines.Add('    CurrentAsmData.CurrAsmList.concat('+lOperLine+');');

            // Deallocate CPU registers
            for lIndex := 0 to lOperandCount-1 do
              begin
                lTemp:=GetDeallocStatement(lCount, lOperands[lIndex].Typ);
                if lTemp<>'' then
                  lSecondPassLines.add('    '+lTemp);
              end;

            lSecondPassLines.Add('  end;');

            if lTarget<>'' then
              lSecondPassLines.add('{$endif}');
          end;

        // Write innr
        WriteLn(lCompilerInlineFile, '  in_', APrefix,'_',lInstructionPart,lPostfix+lAlias,' = in_',APrefix,'_mm_first+',lIntrinsicNumber,',');
        WriteLn(lCPUInlineFile, '  fpc_in_', APrefix,'_',lInstructionPart,lPostfix+lAlias,' = fpc_in_',APrefix,'_mm_first+',lIntrinsicNumber,';');

        // Write function
        if lTarget<>'' then
          WriteLn(lProcsFile, '{$ifdef ',lTarget,'}');

        if lHasOutput then write(lProcsFile,'function ') else write(lProcsFile,'procedure ');
        write(lProcsFile,APrefix,'_',lInstructionPart,lPostfix,'(');

        lCount:=0;
        for lIndex:=0 to lOperandCount-1 do
          begin
            if lOperands[lIndex].Direction=operOut then
              Continue;

            if lCount>0 then
              begin
                if lOperands[lIndex].Typ<>lOperands[lIndex-1].Typ then
                  write(lProcsFile,': ',GetPascalType(lOperands[lIndex-1].Typ),'; ')
                else
                  write(lProcsFile,', ');
              end;

            write(lProcsFile,lOperands[lIndex].Name);
            if lIndex=lOperandCount-1 then
              write(lProcsFile,': ',GetPascalType(lOperands[lIndex].Typ));

            inc(lCount);
          end;

        write(lProcsFile,')');

        if lHasOutput then write(lProcsFile,': ',GetPascalType(lOutputType));
        WriteLn(lProcsFile,'; [INTERNPROC: fpc_in_',APrefix,'_',lInstructionPart,lPostfix+lAlias,'];');

        if lTarget<>'' then
          WriteLn(lProcsFile, '{$endif}');

        // Str now contains conditionals

        inc(lIntrinsicNumber);
      end;

    WriteLn(lCompilerInlineFile, '  in_', APrefix,'mm_last = in_',APrefix,'_mm_first+',lIntrinsicNumber-1);

    lTypeCheckLines.SaveToFile(APrefix+'mmtype.inc');
    lFirstPassLines.SaveToFile(APrefix+'mmfirst.inc');
    lSecondPassLines.SaveToFile(APrefix+'mmsecond.inc');

    lTypeCheckLines.Free;
    lFirstPassLines.Free;
    lSecondPassLines.Free;

    CloseFile(lProcsFile);
    CloseFile(lCompilerInlineFile);
    CloseFile(lCPUInlineFile);

    CloseFile(lFile);
  end;

begin
  ParseList('x86', 'x86intr.dat');
end.

