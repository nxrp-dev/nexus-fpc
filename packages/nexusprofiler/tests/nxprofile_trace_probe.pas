program nxprofile_trace_probe;

{$mode objfpc}{$H+}

uses
  SysUtils,
  NXProfile;

var
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  I: SizeInt;
  Modules, Unloads, Procedures, Threads, Blocks, Events: QWord;
  Enters, Leaves, Unwinds, Gaps, Ends, Lost: QWord;
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
        nxprEventBlock:
          begin
            Inc(Blocks);
            Inc(Lost, Rec.EventBlock.LostEventCount);
            for I := 0 to High(Rec.EventBlock.Events) do
              begin
                Inc(Events);
                case Rec.EventBlock.Events[I].Kind of
                  nxpeEnter: Inc(Enters);
                  nxpeLeave: Inc(Leaves);
                  nxpeUnwind: Inc(Unwinds);
                end;
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
    WriteLn('events=', Events);
    WriteLn('enters=', Enters);
    WriteLn('leaves=', Leaves);
    WriteLn('unwinds=', Unwinds);
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
