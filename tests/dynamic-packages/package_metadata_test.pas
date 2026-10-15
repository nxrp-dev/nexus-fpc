program package_metadata_test;

{$mode objfpc}{$H+}

uses
  SysUtils, compiler, Systems, CUtils, CFileUtl, CClasses, CStreams,
  Globals, Verbose, CompHook, FPkg, FPCP, PkgUtil, FinPut, FModule;

procedure Check(Condition: Boolean; const Text: string);
begin
  if not Condition then
    raise Exception.Create(Text);
end;

procedure TestNames;
var
  Entry: PPackageEntry;
begin
  Add_Package('MixedName',true,false);
  Add_Package('MIXEDNAME',true,true);
  Add_Package('mixedname',true,false);
  Check(PackageList.Count=1,'case variants created multiple packages');
  Entry:=PPackageEntry(PackageList[0]);
  Check(Entry^.RealPkgName='MixedName','display name was changed');
  Check(Entry^.direct,'direct requirement was lost');
  Check(ErrorCount=0,'ignored duplicate reported an error');
  Add_Package('mIxEdNaMe',false,true);
  Check(ErrorCount=1,'explicit duplicate did not report one error');
  Check(PackageList.Count=1,'diagnosed duplicate created another package');
  WriteLn('PASS names');
end;

procedure ReadPackage;
var
  P: TPCPPackage;
  U: TModuleBase;
  C: PContainedUnit;
  S,Other: TCStream;
  I,Count: LongInt;
  B: Byte;
begin
  P:=TPCPPackage.Create(ParamStr(3));
  try
    P.LoadPCP;
    Count:=P.ContainedModules.Count;
    P.LoadPCP;
    Check(P.ContainedModules.Count=Count,'second load appended units');
    for I:=0 to Count-1 do
      begin
        C:=PContainedUnit(P.ContainedModules[I]);
        U:=TModuleBase.Create(P.ContainedModules.NameOfIndex(I));
        C^.module:=U;
        S:=P.GetModuleStream(U);
        Other:=P.GetModuleStream(U);
        try
          Check(Assigned(S) and Assigned(Other),'missing unit stream');
          Check(S.Size=C^.size,'incorrect bounded stream size');
          Check(S.Read(B,1)=1,'cannot read embedded PPU');
          Check(Other.Position=0,'unit streams share a cursor');
          S.Position:=S.Size;
          Check(S.Read(B,1)=0,'unit stream reads past its end');
        finally
          S.Free;
          Other.Free;
          U.Free;
          C^.module:=nil;
        end;
      end;
    WriteLn('PASS read ',Count);
  finally
    P.Free;
  end;
end;

procedure WritePackage;
var
  P: TPCPPackage;
  U: TModuleBase;
begin
  SetCurrentModule(TModule.Create(nil,'Fixture','Fixture.nxpk',false));
  CurrentModule.setmodulename('Fixture');
  P:=TPCPPackage.Create('Fixture');
  U:=TModuleBase.Create('UX');
  try
    P.PPLFileName:='Fixture.dll';
    U.PPUFileName:=ParamStr(3);
    P.AddUnit(U);
    P.SavePCP;
    WriteLn('PASS write');
  finally
    U.Free;
    P.Free;
    CurrentModule.Free;
    SetCurrentModule(nil);
  end;
end;

procedure LoadGraph;
var
  I,First: Integer;
begin
  First:=3;
  if ParamStr(1)='building' then
    begin
      SetCurrentModule(TModule.Create(nil,ParamStr(3),ParamStr(3)+'.nxpk',false));
      CurrentModule.setmodulename(ParamStr(3));
      CurrentModule.IsPackage:=true;
      First:=4;
    end;
  try
    for I:=First to ParamCount do
      Add_Package(ParamStr(I),true,true);
    if ParamStr(1)='disabled' then
      Exclude(TargetInfo.flags,tf_supports_packages);
    Load_Packages;
    if ParamStr(1)='disabled' then
      Check(not Assigned(PPackageEntry(PackageList[0])^.package),'disabled loader ran')
    else
      for I:=0 to PackageList.Count-1 do
        Check(Assigned(PPackageEntry(PackageList[I])^.package),'unloaded requirement');
    WriteLn('PASS graph ',PackageList.Count);
  finally
    CurrentModule.Free;
    SetCurrentModule(nil);
  end;
end;

begin
  try
    if (ParamStr(1)='consume') or (ParamStr(1)='compile') then
      begin
        Halt(compiler.Compile(ParamStr(2)));
      end;
    InitSystems;
    InitFileUtils;
    InitGlobals;
    InitVerbose;
    try
      if ParamCount>=2 then
        begin
          PackageSearchPath.AddPath(ParamStr(2),true);
          OutputUnitDir:=IncludeTrailingPathDelimiter(ParamStr(2));
        end;
      if ParamStr(1)='names' then
        TestNames
      else if ParamStr(1)='read' then
        ReadPackage
      else if ParamStr(1)='write' then
        WritePackage
      else
        LoadGraph;
    finally
      DoneGlobals;
      DoneVerbose;
      DoneFileUtils;
    end;
  except
    on E: ECompilerAbort do Halt(1);
    on E: Exception do
      begin
        WriteLn('TEST FAILURE: ',E.ClassName,': ',E.Message);
        Halt(2);
      end;
  end;
end.
