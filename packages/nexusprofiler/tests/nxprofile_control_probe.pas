program nxprofile_control_probe;

{$mode objfpc}{$H+}

uses
  SysUtils,
  NXProfile;

type
  TProcedureNames = array of AnsiString;

procedure Check(ACondition: Boolean; const AMessage: AnsiString);
begin
  if not ACondition then
  begin
    WriteLn(StdErr, AMessage);
    Halt(1);
  end;
end;

function ContainsText(const AValue, AText: AnsiString): Boolean;
begin
  Result := Pos(UpperCase(AText), UpperCase(AValue)) <> 0;
end;

var
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  Names: TProcedureNames;
  Index: SizeInt;
  ProcedureId: DWord;
  RequiredCount, ForbiddenCount, UnmatchedCount: QWord;
begin
  if ParamCount <> 4 then
    Halt(2);
  Names := nil;
  Reader := TNXProfileReader.Create(ParamStr(1));
  try
    while Reader.ReadNext(Rec) do
      case Rec.Kind of
        nxprProcedureDefine:
          begin
            ProcedureId := Rec.ProcedureInfo.ProcedureId;
            if Length(Names) <= ProcedureId then
              SetLength(Names, ProcedureId + 1);
            Names[ProcedureId] := Rec.ProcedureInfo.Name;
          end;
        nxprCallBlock:
          for Index := 0 to High(Rec.CallBlock.Calls) do
          begin
            ProcedureId := Rec.CallBlock.Calls[Index].ProcedureId;
            if (Rec.CallBlock.Calls[Index].Flags and nxpcfUnmatched) <> 0 then
              Inc(UnmatchedCount);
            if (ProcedureId < DWord(Length(Names))) and
               ContainsText(Names[ProcedureId], ParamStr(2)) then
              Inc(RequiredCount);
            if (ProcedureId < DWord(Length(Names))) and
               (ContainsText(Names[ProcedureId], ParamStr(3)) or
                ContainsText(Names[ProcedureId], ParamStr(4))) then
              Inc(ForbiddenCount);
          end;
      end;
    Check(not Reader.TruncatedTail, 'controlled trace is truncated');
    Check(RequiredCount > 0, 'required interval procedure was not captured');
    Check(ForbiddenCount = 0, 'procedure outside the interval was captured');
    Check(UnmatchedCount = 0, 'controlled trace contains unmatched calls');
  finally
    Reader.Free;
  end;
end.
