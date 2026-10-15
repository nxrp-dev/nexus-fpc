program NXInlineAssembler;

{$mode objfpc}

uses NXInlineAssemblerUnit;

begin
  if (IntelAnswer <> 42) or (ATTAnswer <> 42) then
    Halt(1);
  WriteLn('PASS: Intel and AT&T inline assembly');
end.
