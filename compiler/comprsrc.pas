{
    Copyright (c) 1998-2008 by Florian Klaempfl

    Handles the resource files handling

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit CompRsrc;

{$i fpcdefs.inc}

interface

uses
  GlobType,FModule,ResourceTools;

var
  RCCompiler,RCClang: AnsiString;
  ResourceConfiguration: TLLVMResourceCompiler;

procedure AddResourceInput(const ASource, ADirective: AnsiString; ALine: Cardinal);
function PrepareModuleResources: Boolean;
function PrepareImageResources(out AResourcesUsed: Boolean): Boolean;
function PublishResourceFiles: Boolean;
procedure CommitResourceFiles(AModule: TModule);

implementation

uses
  Classes,SysUtils,CClasses,CFileUtl,CUtils,Globals,Verbose,Triplet,
  Systems,ResourceMetadata,ResourceArtifacts,ResourceCatalog,ResourceEmit;

function ResourceTool(const AOverride, ADefault: AnsiString): AnsiString;
var
  LName: AnsiString;
begin
  Result:='';
  if AOverride<>'' then LName:=AOverride
  else LName:=ADefault+LLVMUtilsSuffix;
  if (SourceInfo.ExeExt<>'') and (ExtractFileExt(LName)='') then
    LName:=LName+SourceInfo.ExeExt;
  if (UtilsDirectory<>'') and FindFile(LName,UtilsDirectory,False,Result) then Exit;
  FindExe(LName,False,Result);
end;

procedure ResourceFailure(E: Exception);
begin
  Comment(VError,E.Message);
  Include(CurrentSettings.GlobalSwitches,cs_link_nolink);
end;

procedure AddResourceInput(const ASource, ADirective: AnsiString; ALine: Cardinal);
var
  LInput: TModuleResourceInput;
  LPath: TCmdStrListItem;

  procedure AddPaths(APaths: TSearchPathList);
  begin
    LPath:=TCmdStrListItem(APaths.First);
    while LPath<>nil do
    begin
      LInput.IncludeDirectories.Add(ExpandFileName(LPath.FPStr));
      LPath:=TCmdStrListItem(LPath.Next);
    end;
  end;

begin
  LInput:=TModuleResourceInput.Create;
  try
    LInput.OriginalPath:=ASource;
    LInput.DirectiveFile:=ADirective;
    LInput.DirectiveLine:=ALine;
    ResourceConfiguration.TargetTriple:=TargetTriplet(triplet_llvm);
    LInput.CaptureConfiguration(ResourceConfiguration);
    AddPaths(CurrentModule.LocalIncludeSearchPath);
    AddPaths(IncludeSearchPath);
    LInput.ArtifactFile:=ResourceArtifactName(CurrentModule.PPUFileName,
      CurrentModule.ResourceFiles.Count);
    CurrentModule.ResourceFiles.AddOwned(LInput);
    LInput:=nil;
  finally
    LInput.Free;
  end;
end;

function MainSourceFile(AModule: TModule): AnsiString;
var
  LFound: TPathStr;
begin
  Result:=AModule.MainSource;
  if FileExists(Result,True) then Exit;
  Result:=AModule.Path+AModule.MainSource;
  if FileExists(Result,True) then Exit;
  if UnitSearchPath.FindFile(AModule.MainSource,True,LFound) then
    Exit(LFound);
  Result:='';
end;

function ResourceScratchPrefix(const ADirectory: AnsiString): AnsiString;
var
  LMarker: TFileStream;
begin
  Result:=GetTempFileName(ADirectory,'nxr');
  { The Unix RTL returns an unused name without creating it. Keep a marker
    until the stage is committed so later inputs cannot reuse that name. }
  LMarker:=TFileStream.Create(Result,fmCreate);
  LMarker.Free;
end;

procedure PrepareModule(AModule: TModule);
var
  LIndex,LResource: Integer;
  LInput: TModuleResourceInput;
  LMain,LSource,LDirectory,LArtifact,LOrigin: AnsiString;
  LTools: TLLVMResourceCompiler;
begin
  if AModule.ResourcesPrepared then Exit;
  LMain:=MainSourceFile(AModule);
  LDirectory:=ExtractFilePath(ExpandFileName(AModule.PPUFileName));
  for LIndex:=0 to AModule.ResourceFiles.Count-1 do
  begin
    LInput:=AModule.ResourceFiles[LIndex];
    LOrigin:=LInput.DirectiveFile+':'+IntToStr(LInput.DirectiveLine)+
      ' ($R '+LInput.OriginalPath+')';
    LArtifact:=LDirectory+LInput.ArtifactFile;
    LInput.PendingCatalog:=TResourceCatalog.Create;
    try
      if (LInput.Kind=rikRC) and
         (LInput.TargetTriple<>TargetTriplet(triplet_llvm)) then
        raise EResourceCatalog.CreateFmt('%s: RC target configuration changed; rebuild unit %s',
          [LOrigin,AModule.RealModuleName^]);
      if LMain<>'' then
      begin
        LSource:=LInput.OriginalPath;
        if not Path_Absolute(LSource) then
          LSource:=ExtractFilePath(ExpandFileName(LMain))+LSource;
        LInput.ScratchPrefix:=ResourceScratchPrefix(LDirectory);
        LTools:=TLLVMResourceCompiler.Create;
        try
          LInput.ConfigureCompiler(LTools);
          LTools.TargetTriple:=TargetTriplet(triplet_llvm);
          LTools.ClangPath:=ResourceTool(RCClang,'clang');
          LTools.RCPath:=ResourceTool(RCCompiler,'llvm-rc');
          Message1(exec_i_compilingresource,LSource);
          LInput.Kind:=NormalizeResourceInput(LInput.PendingCatalog,LTools,
            LSource,LInput.ScratchPrefix);
        finally
          LTools.Free;
        end;
        LInput.PendingStage:=TResourceArtifactStage.Create(LInput.PendingCatalog,
          LArtifact,LInput.ScratchPrefix,True);
      end
      else
        LInput.PendingCatalog.LoadRes(LArtifact);
      for LResource:=0 to LInput.PendingCatalog.Count-1 do
        LInput.PendingCatalog[LResource].Origin:=LOrigin+' -> '+
          LInput.PendingCatalog[LResource].Origin;
    except
      on E:Exception do
        raise EResourceCatalog.CreateFmt('%s: %s',[LOrigin,E.Message]);
    end;
  end;
  AModule.ResourcesPrepared:=True;
end;

function PrepareModuleResources: Boolean;
begin
  try
    PrepareModule(CurrentModule);
    Result:=True;
  except
    on E:Exception do
    begin
      ResourceFailure(E);
      Result:=False;
    end;
  end;
end;

function PrepareImageResources(out AResourcesUsed: Boolean): Boolean;
var
  LCatalog: TResourceCatalog;
  LProcessed: TFPList;
  LUsed: TUsedUnit;
  LDirectory,LPrefix: AnsiString;

  procedure ProcessModule(AModule: TModule);
  var
    LIndex: Integer;
    LInput: TModuleResourceInput;
  begin
    { Imported units retain their resources in the provider image. }
    if Assigned(AModule.Package) or (LProcessed.IndexOf(AModule)>=0) then Exit;
    LProcessed.Add(AModule);
    PrepareModule(AModule);
    for LIndex:=0 to AModule.ResourceFiles.Count-1 do
    begin
      LInput:=AModule.ResourceFiles[LIndex];
      LCatalog.MergeFrom(LInput.PendingCatalog);
    end;
  end;

begin
  Result:=False;
  AResourcesUsed:=False;
  CurrentModule.ResourceLinkFile:='';
  LCatalog:=TResourceCatalog.Create;
  LProcessed:=TFPList.Create;
  try
    try
      LUsed:=TUsedUnit(UsedUnits.First);
      while LUsed<>nil do
      begin
        ProcessModule(LUsed.U);
        LUsed:=TUsedUnit(LUsed.Next);
      end;
      ProcessModule(CurrentModule);
      AResourcesUsed:=LCatalog.Count<>0;
      if AResourcesUsed then
        if TargetInfo.Res=res_coff then
        begin
          LDirectory:=ExtractFilePath(ExpandFileName(CurrentModule.PPUFileName));
          LPrefix:=ResourceScratchPrefix(LDirectory);
          try
            CurrentModule.ResourceImageStage:=TResourceArtifactStage.Create(LCatalog,
              ChangeFileExt(CurrentModule.PPUFileName,'.nximage.res'),LPrefix,True);
          finally
            DeleteFile(LPrefix);
          end;
          CurrentModule.ResourceLinkFile:=CurrentModule.ResourceImageStage.PublishedFile;
        end
        else
          EmitCompilerResources(LCatalog);
      Result:=True;
    except
      on E:Exception do ResourceFailure(E);
    end;
  finally
    LProcessed.Free;
    LCatalog.Free;
  end;
end;

procedure PublishModule(AModule: TModule);
var
  LIndex: Integer;
begin
  for LIndex:=0 to AModule.ResourceFiles.Count-1 do
    if AModule.ResourceFiles[LIndex].PendingStage<>nil then
      AModule.ResourceFiles[LIndex].PendingStage.Publish;
  if AModule.ResourceImageStage<>nil then AModule.ResourceImageStage.Publish;
end;

procedure CommitResourceFiles(AModule: TModule);
var
  LIndex: Integer;
  LInput: TModuleResourceInput;
begin
  for LIndex:=0 to AModule.ResourceFiles.Count-1 do
  begin
    LInput:=AModule.ResourceFiles[LIndex];
    if LInput.PendingStage<>nil then
    begin
      LInput.PendingStage.Commit;
      FreeAndNil(LInput.PendingStage);
    end;
    if LInput.ScratchPrefix<>'' then
    begin
      DeleteFile(LInput.ScratchPrefix+'.rc.i');
      DeleteFile(LInput.ScratchPrefix+'.rc.d');
      DeleteFile(LInput.ScratchPrefix+'.raw.res');
      DeleteFile(LInput.ScratchPrefix);
      LInput.ScratchPrefix:='';
    end;
  end;
  if AModule.ResourceImageStage<>nil then
  begin
    AModule.ResourceImageStage.Commit;
    FreeAndNil(AModule.ResourceImageStage);
  end;
end;

function PublishResourceFiles: Boolean;
var
  LUsed: TUsedUnit;
begin
  try
    if not CurrentModule.IsUnit then
    begin
      LUsed:=TUsedUnit(UsedUnits.First);
      while LUsed<>nil do
      begin
        if not Assigned(LUsed.U.Package) and (LUsed.U<>CurrentModule) then
        begin
          PublishModule(LUsed.U);
          CommitResourceFiles(LUsed.U);
        end;
        LUsed:=TUsedUnit(LUsed.Next);
      end;
    end;
    PublishModule(CurrentModule);
    if not CurrentModule.IsUnit then CommitResourceFiles(CurrentModule);
    Result:=True;
  except
    on E:Exception do
    begin
      ResourceFailure(E);
      Result:=False;
    end;
  end;
end;

procedure InitGlobals;
begin
  RCCompiler:='';
  RCClang:='';
  ResourceConfiguration:=TLLVMResourceCompiler.Create;
end;

procedure DoneGlobals;
begin
  FreeAndNil(ResourceConfiguration);
end;

initialization
  Register_InitDone_Proc(@InitGlobals,@DoneGlobals);
end.
