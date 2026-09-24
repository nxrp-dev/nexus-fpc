program nxprofile_trace_probe;

{$mode objfpc}{$H+}

uses
  SysUtils,
  NXProfile;

var
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  I: SizeInt;
  Modules, Unloads, Procedures, Threads, Blocks, Calls: QWord;
  NormalReturns, Unwinds, Unmatched, Gaps, Ends, Lost: QWord;
begin
  if ParamCount <> 1 then
    Halt(2);
  Reader := TNXProfileReader.Create(ParamStr(1));
  try
    while Reader.ReadNext(Rec) do
      case Rec.Kind of
        nxprModuleDefine: Inc(Modules);
        nxprModuleUnload: Inc(Unloads);
        nxprProcedureDefine: Inc(Procedures);
        nxprThreadDefine: Inc(Threads);
        nxprCallBlock:
          begin
            Inc(Blocks);
            Inc(Lost, Rec.CallBlock.LostEventCount);
            for I := 0 to High(Rec.CallBlock.Calls) do
            begin
              Inc(Calls);
              if (Rec.CallBlock.Calls[I].Flags and nxpcfUnmatched) <> 0 then
                Inc(Unmatched)
              else if (Rec.CallBlock.Calls[I].Flags and nxpcfUnwind) <> 0 then
                Inc(Unwinds)
              else
                Inc(NormalReturns);
            end;
          end;
        nxprTraceGap:
          begin
            Inc(Gaps);
            Inc(Lost, Rec.LostEventCount);
          end;
        nxprTraceEnd: Inc(Ends);
      end;
    WriteLn('modules=', Modules);
    WriteLn('unloads=', Unloads);
    WriteLn('procedures=', Procedures);
    WriteLn('threads=', Threads);
    WriteLn('blocks=', Blocks);
    WriteLn('calls=', Calls);
    WriteLn('normal_returns=', NormalReturns);
    WriteLn('unwinds=', Unwinds);
    WriteLn('unmatched=', Unmatched);
    WriteLn('gaps=', Gaps);
    WriteLn('lost=', Lost);
    WriteLn('trace_end=', Ends);
    if Reader.TruncatedTail then
      WriteLn('truncated=1')
    else
      WriteLn('truncated=0');
  finally
    Reader.Free;
  end;
end.
