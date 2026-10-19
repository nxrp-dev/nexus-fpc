program ResourceTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  SysUtils, obNXTestRegistry, utNXTestConsole,
  tsNXResourceCatalog, tsNXResourceInputs, tsNXResourceTables,
  tsNXResourceTools, tsNXResourceArtifacts;
var lRegistry: TNXTestRegistry; lGroup: string;
begin
  lGroup := LowerCase(ParamStr(1));
  lRegistry := TNXTestRegistry.Create;
  try
    case lGroup of
      'catalog': RegisterCatalogTests(lRegistry);
      'inputs': RegisterInputsTests(lRegistry);
      'tables': RegisterTablesTests(lRegistry);
      'tools': RegisterToolsTests(lRegistry);
      'artifacts': RegisterArtifactsTests(lRegistry);
    else
      WriteLn(StdErr, 'Usage: ResourceTests <catalog|inputs|tables|tools|artifacts> <fixture arguments>');
      Halt(2);
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
