unit tsNXProfileControl;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterProfileControlTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, NXProfile, obNXTestContext;

function ContainsText(const AValue, AText: AnsiString): Boolean;
begin Result := Pos(UpperCase(AText), UpperCase(AValue)) <> 0; end;

procedure ControlledInterval(AContext: TNXTestContext);
var Reader: TNXProfileReader; Rec: TNXProfileRecord; Names: array of AnsiString;
  Index: SizeInt; ProcedureId: DWord;
  RequiredCount, ForbiddenCount, UnmatchedCount: QWord;
begin
  RequiredCount := 0; ForbiddenCount := 0; UnmatchedCount := 0;
  Names := nil;
  Reader := TNXProfileReader.Create(ParamStr(2));
  try
    while Reader.ReadNext(Rec) do
      case Rec.Kind of
        nxprProcedureDefine:
          begin
            ProcedureId := Rec.ProcedureInfo.ProcedureId;
            if Length(Names) <= ProcedureId then SetLength(Names, ProcedureId + 1);
            Names[ProcedureId] := Rec.ProcedureInfo.Name;
          end;
        nxprCallBlock:
          for Index := 0 to High(Rec.CallBlock.Calls) do
          begin
            ProcedureId := Rec.CallBlock.Calls[Index].ProcedureId;
            if (Rec.CallBlock.Calls[Index].Flags and nxpcfUnmatched) <> 0 then Inc(UnmatchedCount);
            if (ProcedureId < DWord(Length(Names))) and
              ContainsText(Names[ProcedureId], ParamStr(3)) then Inc(RequiredCount);
            if (ProcedureId < DWord(Length(Names))) and
              (ContainsText(Names[ProcedureId], ParamStr(4)) or
               ContainsText(Names[ProcedureId], ParamStr(5))) then Inc(ForbiddenCount);
          end;
      end;
    AContext.AssertFalse(Reader.TruncatedTail, 'Controlled trace is truncated');
    AContext.AssertTrue(RequiredCount > 0, 'Required interval procedure was not captured');
    AContext.AssertTrue(ForbiddenCount = 0, 'Procedure outside the interval was captured');
    AContext.AssertTrue(UnmatchedCount = 0, 'Controlled trace contains unmatched calls');
  finally Reader.Free; end;
end;

procedure RegisterProfileControlTests(ARegistry: TNXTestRegistry);
begin
  ARegistry.AddSuite('Profiler.Control').AddTest('Interval', @ControlledInterval, 'profiler-control');
end;
end.
