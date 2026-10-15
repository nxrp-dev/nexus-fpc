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
unit comprsrc;

{$i fpcdefs.inc}

interface

  uses
    Systems, CStreams, CScript;

type
   TResOutput = (roRES, roOBJ);

   TResourceFile = class(TAbstractResourceFile)
   private
      FName : AnsiString;
   protected
      function SetupCompilerArguments(Output: TResOutput; const OutName :
      AnsiString; ResPath: AnsiString; out ObjUsed : Boolean) : AnsiString; virtual;
   public
      constructor Create(const FN : AnsiString);override;
      function Compile(Output: TResOutput; const OutName: AnsiString) : Boolean; virtual;
      procedure PostProcessResourceFile(const S : AnsiString);virtual;
      function IsCompiled(const FN : AnsiString) : Boolean;virtual;
      procedure Collect(const FN : AnsiString);virtual;
      procedure EndCollect; virtual;
   end;

   TWinLikeResourceFile = class(TResourceFile)
   private
      FResScript : TScript;
      FScriptName : AnsiString;
      FCollectCount : Integer;
   protected
      function SetupCompilerArguments(Output: TResOutput; const OutName :
        AnsiString; ResPath: AnsiString; out ObjUsed : Boolean) : AnsiString; override;
   public
      constructor Create(const FN : AnsiString);override;
      destructor Destroy; override;
      function Compile(Output: TResOutput; const OutName: AnsiString) : Boolean; override;
      function IsCompiled(const FN : AnsiString) : Boolean;override;
      procedure Collect(const FN : AnsiString);override;
      procedure EndCollect; override;
   end;


procedure CompileResourceFiles;
procedure CollectResourceFiles;

Var
  ResCompiler : String;
  RCCompiler  : String;
  RCForceFPCRes : Boolean;

implementation

uses
  SysUtils,
  CUtils,CFileUtl,CClasses,
  GlobType,Globals,Verbose,FModule, CompHook,CPUInfo,ResCmn;

{****************************************************************************
                              TRESOURCEFILE
****************************************************************************}

constructor TResourceFile.Create(const FN : AnsiString);
begin
  FName:=FN;
end;


procedure TResourceFile.PostProcessResourceFile(const S : AnsiString);
begin
end;


function TResourceFile.IsCompiled(const FN: AnsiString): Boolean;
begin
  Result:=CompareText(ExtractFileExt(FN), TargetInfo.ResObjExt) = 0;
end;

procedure TResourceFile.Collect(const FN: AnsiString);
begin
  if FN='' then
    Exit;
  FName:=FN;
  Compile(roOBJ, ChangeFileExt(FN, TargetInfo.ResObjExt));
end;

procedure TResourceFile.EndCollect;
begin

end;

function TResourceFile.SetupCompilerArguments(Output: TResOutput; const OutName
  : AnsiString; ResPath: AnsiString; out ObjUsed : Boolean) : AnsiString;
var
  S : TCmdStr;
begin
  if Output=roRES then
    begin
      if RCForceFPCRes then
        S:=FPCResRCArgs
      else
        S:=TargetRes.RCCmd;
      Replace(S,'$RES',MaybeQuoted(OutName));
      Replace(S,'$RC',MaybeQuoted(FName));
      ObjUsed:=False;
    end
  else
    begin
      S:=TargetRes.ResCmd;
      ObjUsed:=(Pos('$OBJ',S)>0);
      Replace(S,'$OBJ',MaybeQuoted(OutName));
      Replace(S,'$RES',MaybeQuoted(FName));
    end;
  Result:=S;
end;

function TResourceFile.Compile(Output: TResOutput; const OutName: AnsiString)
  : Boolean;

  Function SelectBin(Const Bin1,Bin2 : String) : String;
  begin
    If (Bin1<>'') then
      SelectBin:=Bin1
    else
      SelectBin:=Bin2;
  end;

var
  ResPath,
  S,
  Bin,
  ResBin   : TCmdStr;
  ResFound,
  ObjUsed  : Boolean;
begin
  Result:=True;
  if Output=roRES then
    if RCForceFPCRes then
      Bin:=SelectBin(RCCompiler,FPCResUtil)
    else
      Bin:=SelectBin(RCCompiler,TargetRes.RCBin)
  else
    Bin:=SelectBin(ResCompiler,TargetRes.ResBin);
  if Bin='' then
  begin
    Result:=False;
    Exit;
  end;
  ResFound:=False;
  if UtilsDirectory<>'' then
    ResFound:=FindFile(UtilsPrefix+Bin+SourceInfo.ExeExt,UtilsDirectory,False,ResBin);
  if not ResFound then
    begin
      ResFound:=FindExe(UtilsPrefix+Bin,False,ResBin);
      if not ResFound and (UtilsPrefix<>'') and ( (Output=roRES) or (Pos('$ARCH', TargetRes.ResCmd)<>0) ) then
        { Search for resource compiler without utilsprefix, if RC->RES compiler is called }
        { or RES->OBJ compiler supports different architectures. }
        ResFound:=FindExe(Bin,False,ResBin);
    end;
  { get also the path to be searched for the windres.h }
  ResPath:=ExtractFilePath(ResBin);
  if (not ResFound) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   begin
     Message1(exec_e_res_not_found, UtilsPrefix+Bin+SourceInfo.ExeExt);
     CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
     Result:=False;
   end;
  S:=SetupCompilerArguments(Output,OutName,ResPath,ObjUsed);
{ Execute the command }
{ Always try to compile resources. but don't complain if cs_link_nolink }
  if ResFound then
   begin
     Message1(exec_i_compilingresource,FName);
     Message2(exec_d_resbin_params,ResBin,S);
     FlushOutput;
     try
       if RequotedExecuteProcess(ResBin,S) <> 0 then
       begin
         if not (cs_link_nolink in CurrentSettings.GlobalSwitches) then
           Message(exec_e_error_while_compiling_resources);
         CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
         Result:=False;
       end;
     except
       on E:EOSError do
       begin
         if not (cs_link_nolink in CurrentSettings.GlobalSwitches) then
           Message1(exec_e_cant_call_resource_compiler, ResBin);
         CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
         Result:=False;
       end
     end;
    end;
  { Update asmres when externmode is set and resource compiling failed }
  if (not Result) and (cs_link_nolink in CurrentSettings.GlobalSwitches) then
    AsmRes.AddLinkCommand(ResBin,S,OutName);
  if Result and (Output=roOBJ) and ObjUsed then
    CurrentModule.LinkUnitOFiles.Add(OutName,link_always);
end;

constructor TWinLikeResourceFile.Create(const FN : AnsiString);
begin
  inherited Create(FN);
  FResScript:=nil;
  FCollectCount:=0;
  if (tf_use_8_3 in TargetInfo.Flags) then
    FScriptName:=ChangeFileExt(FN,'.rls')
  else
    FScriptName:=ChangeFileExt(FN,'.reslst');
end;

destructor TWinLikeResourceFile.Destroy;
begin
  if FResScript<>nil then
    FResScript.Free;
    FResScript := nil;
  inherited;
end;

function TWinLikeResourceFile.SetupCompilerArguments(Output: TResOutput; const
  OutName : AnsiString; ResPath : AnsiString; out ObjUsed : Boolean) : AnsiString;
var
  SrcFilePath,
  PreprocessorBin,
  S : TCmdStr;
  Arch,
  SubArch: AnsiString;

  function WindresFileName(FileName: TCmdStr): TCmdStr;
  // to be on the safe side, for files that are passed to the preprocessor,
  // only give short file names with forward slashes to windres
  var
    I: LongInt;
  begin
    Result := GetShortName(FileName);
    for I:=1 to Length(Result) do
    if Result[I] in AllowDirectorySeparators then
      Result[I]:='/';
    Result:=MaybeQuoted(Result);
  end;

begin
  SrcFilePath:=ExtractFilePath(CurrentModule.MainSource);
  if Output=roRES then
    begin
      if RCForceFPCRes then
        S:=FPCResRCArgs
      else
        S:=TargetRes.RCCmd;
      if (TargetRes.RCBin = 'windres') and not RCForceFPCRes then
        Replace(S,'$RC',WindresFileName(FName))
      else
        Replace(S,'$RC',MaybeQuoted(FName));
      Replace(S,'$RES',MaybeQuoted(OutName));
      ObjUsed:=False;
    end
  else
    begin
      S:=TargetRes.ResCmd;
      if (res_external_file in TargetRes.ResFlags) then
        ObjUsed:=False
      else
        ObjUsed:=(Pos('$OBJ',S)>0);
      Replace(S,'$OBJ',MaybeQuoted(OutName));
      SubArch:='all';
      Arch:=CPU2Str[Ord(TargetCPU)];
      Replace(S,'$ARCH',Arch);
      Replace(S,'$SUBARCH',SubArch);
      case TargetInfo.Endian of
        endian_little : Replace(S,'$ENDIAN','littleendian');
        endian_big : Replace(S,'$ENDIAN','bigendian');
      end;
      //call resource compiler with debug switch
      if (Status.Verbosity and VDebug)<>0 then
        Replace(S,'$DBG','-v')
      else
        Replace(S,'$DBG','');
      if FCollectCount=0 then
        S:=S+' '+MaybeQuoted(FName)
      else
        S:=S+' '+MaybeQuoted('@'+FScriptName);
    end;
  { windres doesn't like empty include paths }
  if ResPath='' then
    ResPath:='.';
  Replace(S,'$INC',MaybeQuoted(ResPath));
  if (Output=roRES) and (TargetRes.RCBin='windres') and not RCForceFPCRes then
  begin
    { try to find a preprocessor }
    PreprocessorBin := ResPath+'cpp'+SourceInfo.ExeExt;
    if FileExists(PreprocessorBin,True) then
      S:='--preprocessor='+PreprocessorBin+' '+S;
    if (SrcFilePath<>'') then
      S:='--include '+WindresFileName(SrcFilePath)+' '+S;
  end;
  Result:=S;
end;

function TWinLikeResourceFile.Compile(Output: TResOutput;
  const OutName: AnsiString) : Boolean;
begin
  Result:=inherited Compile(Output,OutName);
  //delete fpc-res.lst file if things went well
  if Result and (Output=roOBJ) then
    DeleteFile(FScriptName);
end;

function TWinLikeResourceFile.IsCompiled(const FN: AnsiString): Boolean;
const
  ResSignature : array [1..32] of Byte =
  ($00,$00,$00,$00,$20,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,
   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00);
  KnownExts : array[1..5] of string[4] = ('.lfm', '.dfm', '.xfm', '.fmx', '.tlb');
var
  F : file;
  OldFMode : Byte;
  Buf: array[1..32] of Byte;
  I: LongInt;
  Ext : ShortString;
begin
  Ext:=Lower(ExtractFileExt(FN));
  Result:=CompareText(Ext, TargetInfo.ResExt) = 0;
  if not Result then
    for I:=1 to High(KnownExts) do
    begin
      Result:=CompareText(Ext, KnownExts[I]) = 0;
      if Result then Break;
    end;

  if Result or not FileExists(FN, False) then Exit;
  OldFMode:=FileMode;
  FileMode:=0;
  Assign(F,FN);
  Reset(F,1);
  BlockRead(F, Buf, SizeOf(Buf), I);
  Close(F);
  FileMode:=OldFMode;

  if I<>SizeOf(Buf) then
    Exit;

  for I:=1 to 32 do
    if Buf[I]<>ResSignature[I] then
      Exit;

  Result:=True;
end;

procedure TWinLikeResourceFile.Collect(const FN: AnsiString);
begin
  if FResScript=nil then
    FResScript:=TScript.Create(FScriptName);
  FResScript.Add(MaybeQuoted_For_Script(FN,script_fpcres));
  Inc(FCollectCount);
end;

procedure TWinLikeResourceFile.EndCollect;
begin
  if FResScript<>nil then
  begin
    FResScript.WriteToDisk;
    FreeAndNil(FResScript);
    Compile(roOBJ,ChangeFileExt(FName,TargetInfo.ResObjExt));
  end;
end;


function CopyResFile(Inf,Outf : TCmdStr) : Boolean;
var
  Src,Dst : TCCustomFileStream;
begin
  { Copy .res file to units output dir. }
  Result:=False;
  Src:=CFileStreamClass.Create(Inf,fmOpenRead or fmShareDenyNone);
  if CStreamError<>0 then
    begin
      Message1(exec_e_cant_open_resource_file, Src.FileName);
      Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
      Exit;
    end;
  Dst:=CFileStreamClass.Create(CurrentModule.OutputPath+Outf,fmCreate);
  if CStreamError<>0 then
    begin
      Message1(exec_e_cant_write_resource_file, Dst.FileName);
      Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
      Exit;
    end;
  Dst.CopyFrom(Src,Src.Size);
  Dst.Free;
  Dst := nil;
  Src.Free;
  Src := nil;
  Result:=True;
end;

procedure CompileResourceFiles;
var
  ResourceFile : TResourceFile;
  Res: TCmdStrListItem;
  P,S : TCmdStr;
  OutFmt : TResOutput;
begin
  { Don't do anything for systems supporting resources without using resource
    file classes (e.g. Mac OS). They process resources elsewhere. }
  if ((TargetInfo.Res<>res_none) and (TargetRes.ResourceFileClass=nil)) or
     (res_no_compile in TargetRes.ResFlags) then
    Exit;

  P:=ExtractFilePath(ExpandFileName(CurrentModule.MainSource));
  Res:=TCmdStrListItem(CurrentModule.ResourceFiles.First);
  while Res<>nil do
    begin
      if TargetInfo.Res=res_none then
        Message(scan_e_resourcefiles_not_supported);
      S:=Res.FPStr;
      if not Path_Absolute(S) then
        S:=P+S;
      if not FileExists(S, True) then
        begin
          Message1(exec_e_cant_open_resource_file, S);
          Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
          Exit;
        end;
      ResourceFile:=TResourceFile(ResInfos[TargetInfo.Res]^.ResourceFileClass.Create(S));
      if ResourceFile.IsCompiled(S) then
        begin
          ResourceFile.Free;
          ResourceFile := nil;
          if AnsiCompareFileName(IncludeTrailingPathDelimiter(ExpandFileName(CurrentModule.OutputPath)), P) <> 0 then
            begin
              { Copy .res file to units output dir. Otherwise .res file will not be found
                when only compiled units path is available }
              Res.FPStr:=ExtractFileName(Res.FPStr); //store file name only in PPU.
              if not CopyResFile(S,Res.FPStr) then Exit;
            end;
        end
      else
        begin
          Res.FPStr:=ExtractFileName(Res.FPStr);
          if (TargetRes.RCBin='') and (RCCompiler='') then
            begin
              { if target does not have .rc to .res compiler, create obj }
              OutFmt:=roOBJ;
              Res.FPStr:=ChangeFileExt(Res.FPStr,TargetInfo.ResObjExt);
            end
          else
            begin
              OutFmt:=roRES;
              Res.FPStr:=ChangeFileExt(Res.FPStr,TargetInfo.ResExt);
            end;
          ResourceFile.Compile(OutFmt, CurrentModule.OutputPath+Res.FPStr);
          ResourceFile.Free;
          ResourceFile := nil;
        end;
      Res:=TCmdStrListItem(Res.Next);
    end;
end;


procedure CollectResourceFiles;
var
  ResourceFile : TResourceFile;

  procedure ProcessModule(U : TModule);
  var
    Res : TCmdStrListItem;
    S   : TCmdStr;
  begin
    { An imported unit's native resources belong to its provider image. }
    if Assigned(U.Package) then Exit;
    Res:=TCmdStrListItem(U.ResourceFiles.First);
    while Assigned(Res) do
      begin
        if Path_Absolute(Res.FPStr) then
          S:=Res.FPStr
        else
          begin
            S:=U.Path+Res.FPStr;
            if not FileExists(S,True) then
              S:=U.OutputPath+Res.FPStr;
          end;
        ResourceFile.Collect(S);
        Res:=TCmdStrListItem(Res.Next);
      end;
  end;

var
  HP : TUsedUnit;
  S : TCmdStr;
begin
  if (TargetInfo.Res=res_none) or ((TargetRes.ResBin='')
    and (ResCompiler='')) then
      Exit;
//  if cs_link_nolink in current_settings.globalswitches then
//    exit;
  S:=ChangeFileExt(CurrentModule.PPUFileName,TargetInfo.ResObjExt);
  if (res_arch_in_file_name in TargetRes.ResFlags) then
    S:=ChangeFileExt(S,'.'+CPU2Str[Ord(TargetCPU)]+TargetInfo.ResObjExt);
  ResourceFile:=TResourceFile(ResInfos[TargetInfo.Res]^.ResourceFileClass.Create(S));
  HP:=TUsedUnit(UsedUnits.First);
  while Assigned(HP) do
    begin
      ProcessModule(HP.U);
      HP:=TUsedUnit(HP.Next);
    end;
  ProcessModule(CurrentModule);
  { Finish collection }
  ResourceFile.EndCollect;
  ResourceFile.Free;
  ResourceFile := nil;
end;

procedure InitGlobals;
begin
  ResCompiler:='';
  RCCompiler:='';
  RCForceFPCRes:=False;
end;

initialization
  Register_InitDone_Proc(@InitGlobals,nil);
end.
