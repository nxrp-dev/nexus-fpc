program nxCompilerResourceEmitTests;

{$mode objfpc}{$H+}

{ Compile against one consistent target compiler-unit closure. The test runs
  on the host and writes data-only assembly for that closure's target width. }
uses
  obNXTestRegistry, obNXTestContext, utNXTestConsole,
  SysUtils, Compiler, GlobType, Globals, Systems, CFileUtl, CClasses, Verbose,
  FModule, AAsmData, AAsmBase, AAsmTai, Assemble, AgGas,
  ResourceCatalog, ResourceEmit;

var TestContext: TNXTestContext;

var
  LCatalog: TResourceCatalog;
  LAssembler: TExternalAssembler;
  LTarget: TSystem;
procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    if ParamCount <> 3 then
      raise Exception.Create('Usage: nxCompilerResourceEmitTests <target> <input.res> <output.s>');
    InitSystems;
    InitFileUtils;
    InitGlobals;
    InitVerbose;
    try
      LTarget := system_none;
{$ifdef i386}
      if ParamStr(1) = 'linux' then LTarget := system_i386_linux;
{$endif}
{$ifdef x86_64}
      if ParamStr(1) = 'linux' then LTarget := system_x86_64_linux;
      if ParamStr(1) = 'android' then LTarget := system_x86_64_android;
      if ParamStr(1) = 'darwin' then LTarget := system_x86_64_darwin;
      if ParamStr(1) = 'iphonesim' then LTarget := system_x86_64_iphonesim;
{$endif}
{$ifdef aarch64}
      if ParamStr(1) = 'linux' then LTarget := system_aarch64_linux;
      if ParamStr(1) = 'android' then LTarget := system_aarch64_android;
      if ParamStr(1) = 'darwin' then LTarget := system_aarch64_darwin;
      if ParamStr(1) = 'iphonesim' then LTarget := system_aarch64_iphonesim;
      if ParamStr(1) = 'ios' then LTarget := system_aarch64_ios;
{$endif}
      if (LTarget = system_none) or not SetTarget(LTarget) then
        raise Exception.Create('Target is unavailable in this compiler-unit closure');
      CurrentSettings := Default_Settings;
      { InitParser normally owns this list. This data-only harness does not
        parse a Pascal module, but the assembler constructor still clears it. }
      SmartLinkOFiles := TCmdStrList.Create;
      SetCurrentModule(TModule.Create(nil, 'resourceemit', 'resourceemit.pas', False));
      try
        CurrentModule.SetModuleName('ResourceEmitProbe');
        LCatalog := TResourceCatalog.Create;
        try
          EmitCompilerResources(LCatalog);
          if not CurrentAsmData.AsmLists[al_resources].Empty then
            raise Exception.Create('Empty catalog emitted assembly');
          LCatalog.LoadRes(ParamStr(2));
          EmitCompilerResources(LCatalog);
          if TargetInfo.System in systems_darwin then
            LAssembler := TAppleGNUAssembler.Create(@TargetAsm, False)
          else
            LAssembler := TGNUAssembler.Create(@TargetAsm, False);
          try
            LAssembler.AsmFileName := ParamStr(3);
            LAssembler.Writer.AsmCreate(cut_normal);
            LAssembler.WriteAsmList;
            LAssembler.Writer.AsmClose;
            if LAssembler.Writer.IOError then
              raise Exception.Create('Could not write compiler assembly');
          finally
            LAssembler.Free;
          end;
          WriteLn('PASS compiler resource emitter: ', LCatalog.Count,
            ' resources, target pointer size ', SizeOf(PInt));
        finally
          LCatalog.Free;
        end;
      finally
        CurrentModule.Free;
        SetCurrentModule(nil);
        FreeAndNil(SmartLinkOFiles);
      end;
    finally
      DoneGlobals;
      DoneVerbose;
      DoneFileUtils;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAIL ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      TestContext.Fail(E.ClassName + ': ' + E.Message);
    end;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Resources.CompilerEmission').AddTest('TargetAssembly', @RunCase, 'resources');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
