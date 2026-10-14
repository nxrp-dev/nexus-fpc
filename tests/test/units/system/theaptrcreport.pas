program theaptrcreport;

{$mode objfpc}{$H-}

uses
  heaptrc;

const
  cReportFile = 'theaptrcreport.log';

procedure CheckReport(var AReport: Text; const AExpected: shortstring);
var
  lLine: shortstring;
begin
  while not EOF(AReport) do
  begin
    ReadLn(AReport, lLine);
    if Pos(' unfreed memory blocks : ', lLine) > 0 then
    begin
      if lLine <> AExpected then
      begin
        WriteLn('Expected: ', AExpected);
        WriteLn('Actual: ', lLine);
        Halt(1);
      end;
      Exit;
    end;
  end;
  Halt(2);
end;

var
  lBlock: Pointer;
  lReport: Text;
begin
  GlobalSkipIfNoLeaks := True;
  HaltOnNotReleased := True;

  Assign(lReport, cReportFile);
  Rewrite(lReport);
  SetHeapTraceOutput(lReport);
  DumpHeap(False);
  GetMem(lBlock, 37);
  DumpHeap(False);
  FreeMem(lBlock);
  DumpHeap(False);
  { Switching output closes the report file owned by heaptrc. }
  SetHeapTraceOutput(StdErr);

  Reset(lReport);
  CheckReport(lReport, '0 unfreed memory blocks : 0');
  CheckReport(lReport, '1 unfreed memory blocks : 37');
  CheckReport(lReport, '0 unfreed memory blocks : 0');
  Close(lReport);
  Erase(lReport);
end.
