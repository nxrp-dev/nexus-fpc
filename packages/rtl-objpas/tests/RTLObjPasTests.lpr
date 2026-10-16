// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program RTLObjPasTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole,
  Tests.Rtti.Impl,
  utcmatrix,
  tests.rtti.invoke,
  tests.rtti.value,
  utcfpmonitor,
  utcstrutils,
  utcmatrix3d,
  utcquaternion,
  tests.rtti,
  utmathvectorbase,
  utcvector,
  utcpoint,
  tests.rtti.intercept;
var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterTestsRttiImplTests(lRegistry);
    RegisterutcmatrixTests(lRegistry);
    RegistertestsrttiinvokeTests(lRegistry);
    RegistertestsrttivalueTests(lRegistry);
    RegisterutcfpmonitorTests(lRegistry);
    RegisterutcstrutilsTests(lRegistry);
    Registerutcmatrix3dTests(lRegistry);
    RegisterutcquaternionTests(lRegistry);
    RegistertestsrttiTests(lRegistry);
    RegisterutmathvectorbaseTests(lRegistry);
    RegisterutcvectorTests(lRegistry);
    RegisterutcpointTests(lRegistry);
    RegistertestsrttiinterceptTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
