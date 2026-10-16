// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program RTLCollectionsTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole,
  tcbucketlist,
  tclist,
  tccompstreaming,
  tcstringlist,
  tcstreaming,
  tcfindnested,
  tccomponent,
  tcstrutils,
  tccollection,
  tcpersistent,
  tctparser,
  tcresref,
  tclinkedlist;
var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegistertcbucketlistTests(lRegistry);
    RegistertclistTests(lRegistry);
    RegistertccompstreamingTests(lRegistry);
    RegistertcstringlistTests(lRegistry);
    RegistertcstreamingTests(lRegistry);
    RegistertcfindnestedTests(lRegistry);
    RegistertccomponentTests(lRegistry);
    RegistertcstrutilsTests(lRegistry);
    RegistertccollectionTests(lRegistry);
    RegistertcpersistentTests(lRegistry);
    RegistertctparserTests(lRegistry);
    RegistertcresrefTests(lRegistry);
    RegistertclinkedlistTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
