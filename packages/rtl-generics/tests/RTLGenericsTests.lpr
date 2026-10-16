// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program RTLGenericsTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole,
  tests.generics.sets,
  tests.generics.utils,
  tests.generics.arrayhelper,
  tests.generics.stack,
  tests.generics.hashmaps,
  tests.generics.trees,
  tests.generics.queue,
  tests.generics.bugs,
  tests.generics.stdcollections,
  tests.generics.dictionary,
  tests.generics.dictionary2;
var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegistertestsgenericssetsTests(lRegistry);
    RegistertestsgenericsutilsTests(lRegistry);
    RegistertestsgenericsarrayhelperTests(lRegistry);
    RegistertestsgenericsstackTests(lRegistry);
    RegistertestsgenericshashmapsTests(lRegistry);
    RegistertestsgenericstreesTests(lRegistry);
    RegistertestsgenericsqueueTests(lRegistry);
    RegistertestsgenericsbugsTests(lRegistry);
    RegistertestsgenericsstdcollectionsTests(lRegistry);
    RegistertestsgenericsdictionaryTests(lRegistry);
    Registertestsgenericsdictionary2Tests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
