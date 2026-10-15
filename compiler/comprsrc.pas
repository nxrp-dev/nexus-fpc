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
      fname : AnsiString;
   protected
      function SetupCompilerArguments(Output: TResOutput; const OutName :
      AnsiString; respath: AnsiString; out ObjUsed : boolean) : AnsiString; virtual;
   public
      constructor Create(const fn : AnsiString);override;
      function Compile(Output: TResOutput; const OutName: AnsiString) : boolean; virtual;
      procedure PostProcessResourcefile(const s : AnsiString);virtual;
      function IsCompiled(const fn : AnsiString) : boolean;virtual;
      procedure Collect(const fn : AnsiString);virtual;
      procedure EndCollect; virtual;
   end;

   TWinLikeResourceFile = class(TResourceFile)
   private
      fResScript : TScript;
      fScriptName : AnsiString;
      fCollectCount : integer;
   protected
      function SetupCompilerArguments(Output: TResOutput; const OutName :
        AnsiString; respath: AnsiString; out ObjUsed : boolean) : AnsiString; override;
   public
      constructor Create(const fn : AnsiString);override;
      destructor Destroy; override;
      function Compile(Output: TResOutput; const OutName: AnsiString) : boolean; override;
      function IsCompiled(const fn : AnsiString) : boolean;override;
      procedure Collect(const fn : AnsiString);override;
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
  GlobType,Globals,Verbose,FModule, CompHook,CPUInfo,rescmn;

{****************************************************************************
                              TRESOURCEFILE
****************************************************************************}

constructor TResourceFile.create(const fn : AnsiString);
begin
  fname:=fn;
end;


procedure TResourceFile.PostProcessResourcefile(const s : AnsiString);
begin
end;


function TResourceFile.IsCompiled(const fn: AnsiString): boolean;
begin
  Result:=CompareText(ExtractFileExt(fn), TargetInfo.resobjext) = 0;
end;

procedure TResourceFile.Collect(const fn: AnsiString);
begin
  if fn='' then
    exit;
  fname:=fn;
  Compile(roOBJ, ChangeFileExt(fn, TargetInfo.resobjext));
end;

procedure TResourceFile.EndCollect;
begin

end;

function TResourceFile.SetupCompilerArguments(Output: TResOutput; const OutName
  : AnsiString; respath: AnsiString; out ObjUsed : boolean) : AnsiString;
var
  s : TCmdStr;
begin
  if Output=roRES then
    begin
      if RCForceFPCRes then
        s:=FPCResRCArgs
      else
        s:=TargetRes.rccmd;
      Replace(s,'$RES',MaybeQuoted(OutName));
      Replace(s,'$RC',MaybeQuoted(fname));
      ObjUsed:=False;
    end
  else
    begin
      s:=TargetRes.rescmd;
      ObjUsed:=(pos('$OBJ',s)>0);
      Replace(s,'$OBJ',MaybeQuoted(OutName));
      Replace(s,'$RES',MaybeQuoted(fname));
    end;
  Result:=s;
end;

function TResourceFile.compile(Output: TResOutput; const OutName: AnsiString)
  : boolean;

  Function SelectBin(Const Bin1,Bin2 : String) : String;
  begin
    If (Bin1<>'') then
      SelectBin:=Bin1
    else
      SelectBin:=Bin2;
  end;

var
  respath,
  s,
  bin,
  resbin   : TCmdStr;
  resfound,
  objused  : boolean;
begin
  Result:=true;
  if Output=roRES then
    if RCForceFPCRes then
      Bin:=SelectBin(RCCompiler,FPCResUtil)
    else
      Bin:=SelectBin(RCCompiler,TargetRes.rcbin)
  else
    Bin:=SelectBin(ResCompiler,TargetRes.resbin);
  if bin='' then
  begin
    Result:=false;
    exit;
  end;
  resfound:=false;
  if UtilsDirectory<>'' then
    resfound:=FindFile(UtilsPrefix+bin+SourceInfo.ExeExt,UtilsDirectory,false,resbin);
  if not resfound then
    begin
      resfound:=FindExe(UtilsPrefix+bin,false,resbin);
      if not resfound and (UtilsPrefix<>'') and ( (Output=roRES) or (Pos('$ARCH', TargetRes.rescmd)<>0) ) then
        { Search for resource compiler without utilsprefix, if RC->RES compiler is called }
        { or RES->OBJ compiler supports different architectures. }
        resfound:=FindExe(bin,false,resbin);
    end;
  { get also the path to be searched for the windres.h }
  respath:=ExtractFilePath(resbin);
  if (not resfound) and not(cs_link_nolink in CurrentSettings.GlobalSwitches) then
   begin
     Message1(exec_e_res_not_found, UtilsPrefix+bin+SourceInfo.ExeExt);
     CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
     Result:=false;
   end;
  s:=SetupCompilerArguments(Output,OutName,respath,objused);
{ Execute the command }
{ Always try to compile resources. but don't complain if cs_link_nolink }
  if resfound then
   begin
     Message1(exec_i_compilingresource,fname);
     Message2(exec_d_resbin_params,resbin,s);
     FlushOutput;
     try
       if RequotedExecuteProcess(resbin,s) <> 0 then
       begin
         if not (cs_link_nolink in CurrentSettings.GlobalSwitches) then
           Message(exec_e_error_while_compiling_resources);
         CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
         Result:=false;
       end;
     except
       on E:EOSError do
       begin
         if not (cs_link_nolink in CurrentSettings.GlobalSwitches) then
           Message1(exec_e_cant_call_resource_compiler, resbin);
         CurrentSettings.GlobalSwitches:=CurrentSettings.GlobalSwitches+[cs_link_nolink];
         Result:=false;
       end
     end;
    end;
  { Update asmres when externmode is set and resource compiling failed }
  if (not Result) and (cs_link_nolink in CurrentSettings.GlobalSwitches) then
    AsmRes.AddLinkCommand(resbin,s,OutName);
  if Result and (Output=roOBJ) and ObjUsed then
    CurrentModule.linkunitofiles.add(OutName,link_always);
end;

constructor TWinLikeResourceFile.Create(const fn : AnsiString);
begin
  inherited Create(fn);
  fResScript:=nil;
  fCollectCount:=0;
  if (tf_use_8_3 in TargetInfo.flags) then
    fScriptName:=ChangeFileExt(fn,'.rls')
  else
    fScriptName:=ChangeFileExt(fn,'.reslst');
end;

destructor TWinLikeResourceFile.Destroy;
begin
  if fResScript<>nil then
    fResScript.Free;
    fResScript := nil;
  inherited;
end;

function TWinLikeResourceFile.SetupCompilerArguments(Output: TResOutput; const
  OutName : AnsiString; respath : AnsiString; out ObjUsed : boolean) : AnsiString;
var
  srcfilepath,
  preprocessorbin,
  s : TCmdStr;
  arch,
  subarch: AnsiString;

  function WindresFileName(FileName: TCmdStr): TCmdStr;
  // to be on the safe side, for files that are passed to the preprocessor,
  // only give short file names with forward slashes to windres
  var
    i: LongInt;
  begin
    Result := GetShortName(FileName);
    for I:=1 to Length(Result) do
    if Result[I] in AllowDirectorySeparators then
      Result[i]:='/';
    Result:=MaybeQuoted(Result);
  end;

begin
  srcfilepath:=ExtractFilePath(CurrentModule.MainSource);
  if Output=roRES then
    begin
      if RCForceFPCRes then
        s:=FPCResRCArgs
      else
        s:=TargetRes.rccmd;
      if (TargetRes.rcbin = 'windres') and not RCForceFPCRes then
        Replace(s,'$RC',WindresFileName(fname))
      else
        Replace(s,'$RC',MaybeQuoted(fname));
      Replace(s,'$RES',MaybeQuoted(OutName));
      ObjUsed:=False;
    end
  else
    begin
      s:=TargetRes.rescmd;
      if (res_external_file in TargetRes.resflags) then
        ObjUsed:=false
      else
        ObjUsed:=(pos('$OBJ',s)>0);
      Replace(s,'$OBJ',MaybeQuoted(OutName));
      subarch:='all';
      arch:=cpu2str[Ord(TargetCPU)];
      Replace(s,'$ARCH',arch);
      Replace(s,'$SUBARCH',subarch);
      case TargetInfo.endian of
        endian_little : Replace(s,'$ENDIAN','littleendian');
        endian_big : Replace(s,'$ENDIAN','bigendian');
      end;
      //call resource compiler with debug switch
      if (status.verbosity and VDebug)<>0 then
        Replace(s,'$DBG','-v')
      else
        Replace(s,'$DBG','');
      if fCollectCount=0 then
        s:=s+' '+MaybeQuoted(fname)
      else
        s:=s+' '+MaybeQuoted('@'+fScriptName);
    end;
  { windres doesn't like empty include paths }
  if respath='' then
    respath:='.';
  Replace(s,'$INC',MaybeQuoted(respath));
  if (Output=roRes) and (TargetRes.rcbin='windres') and not RCForceFPCRes then
  begin
    { try to find a preprocessor }
    preprocessorbin := respath+'cpp'+SourceInfo.ExeExt;
    if FileExists(preprocessorbin,true) then
      s:='--preprocessor='+preprocessorbin+' '+s;
    if (srcfilepath<>'') then
      s:='--include '+WindresFileName(srcfilepath)+' '+s;
  end;
  Result:=s;
end;

function TWinLikeResourceFile.compile(Output: TResOutput;
  const OutName: AnsiString) : boolean;
begin
  Result:=inherited compile(Output,OutName);
  //delete fpc-res.lst file if things went well
  if Result and (Output=roOBJ) then
    DeleteFile(fScriptName);
end;

function TWinLikeResourceFile.IsCompiled(const fn: AnsiString): boolean;
const
  ResSignature : array [1..32] of byte =
  ($00,$00,$00,$00,$20,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,
   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00);
  knownexts : array[1..5] of string[4] = ('.lfm', '.dfm', '.xfm', '.fmx', '.tlb');
var
  f : file;
  oldfmode : byte;
  buf: array[1..32] of byte;
  i: LongInt;
  ext : shortstring;
begin
  ext:=lower(ExtractFileExt(fn));
  Result:=CompareText(ext, TargetInfo.resext) = 0;
  if not Result then
    for i:=1 to high(knownexts) do
    begin
      Result:=CompareText(ext, knownexts[i]) = 0;
      if Result then break;
    end;

  if Result or not FileExists(fn, False) then exit;
  oldfmode:=Filemode;
  Filemode:=0;
  assign(f,fn);
  reset(f,1);
  BlockRead(f, buf, SizeOf(buf), i);
  close(f);
  Filemode:=oldfmode;

  if i<>SizeOf(buf) then
    exit;

  for i:=1 to 32 do
    if buf[i]<>ResSignature[i] then
      exit;

  Result:=True;
end;

procedure TWinLikeResourceFile.Collect(const fn: AnsiString);
begin
  if fResScript=nil then
    fResScript:=TScript.Create(fScriptName);
  fResScript.Add(MaybeQuoted_For_Script(fn,script_fpcres));
  inc(fCollectCount);
end;

procedure TWinLikeResourceFile.EndCollect;
begin
  if fResScript<>nil then
  begin
    fResScript.WriteToDisk;
    FreeAndNil(fResScript);
    Compile(roOBJ,ChangeFileExt(fname,TargetInfo.resobjext));
  end;
end;


function CopyResFile(inf,outf : TCmdStr) : boolean;
var
  src,dst : TCCustomFileStream;
begin
  { Copy .res file to units output dir. }
  Result:=false;
  src:=CFileStreamClass.Create(inf,fmOpenRead or fmShareDenyNone);
  if CStreamError<>0 then
    begin
      Message1(exec_e_cant_open_resource_file, src.FileName);
      Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
      exit;
    end;
  dst:=CFileStreamClass.Create(CurrentModule.OutputPath+outf,fmCreate);
  if CStreamError<>0 then
    begin
      Message1(exec_e_cant_write_resource_file, dst.FileName);
      Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
      exit;
    end;
  dst.CopyFrom(src,src.Size);
  dst.Free;
  dst := nil;
  src.Free;
  src := nil;
  Result:=true;
end;

procedure CompileResourceFiles;
var
  resourcefile : TResourceFile;
  res: TCmdStrListItem;
  p,s : TCmdStr;
  outfmt : TResOutput;
begin
  { Don't do anything for systems supporting resources without using resource
    file classes (e.g. Mac OS). They process resources elsewhere. }
  if ((TargetInfo.res<>res_none) and (TargetRes.resourcefileclass=nil)) or
     (res_no_compile in TargetRes.resflags) then
    exit;

  p:=ExtractFilePath(ExpandFileName(CurrentModule.MainSource));
  res:=TCmdStrListItem(CurrentModule.ResourceFiles.First);
  while res<>nil do
    begin
      if TargetInfo.res=res_none then
        Message(scan_e_resourcefiles_not_supported);
      s:=res.FPStr;
      if not Path_Absolute(s) then
        s:=p+s;
      if not FileExists(s, True) then
        begin
          Message1(exec_e_cant_open_resource_file, s);
          Include(CurrentSettings.GlobalSwitches, cs_link_nolink);
          exit;
        end;
      resourcefile:=TResourceFile(resinfos[TargetInfo.res]^.resourcefileclass.create(s));
      if resourcefile.IsCompiled(s) then
        begin
          resourcefile.free;
          resourcefile := nil;
          if AnsiCompareFileName(IncludeTrailingPathDelimiter(ExpandFileName(CurrentModule.OutputPath)), p) <> 0 then
            begin
              { Copy .res file to units output dir. Otherwise .res file will not be found
                when only compiled units path is available }
              res.FPStr:=ExtractFileName(res.FPStr); //store file name only in PPU.
              if not CopyResFile(s,res.FPStr) then exit;
            end;
        end
      else
        begin
          res.FPStr:=ExtractFileName(res.FPStr);
          if (TargetRes.rcbin='') and (RCCompiler='') then
            begin
              { if target does not have .rc to .res compiler, create obj }
              outfmt:=roOBJ;
              res.FPStr:=ChangeFileExt(res.FPStr,TargetInfo.resobjext);
            end
          else
            begin
              outfmt:=roRES;
              res.FPStr:=ChangeFileExt(res.FPStr,TargetInfo.resext);
            end;
          resourcefile.compile(outfmt, CurrentModule.OutputPath+res.FPStr);
          resourcefile.free;
          resourcefile := nil;
        end;
      res:=TCmdStrListItem(res.Next);
    end;
end;


procedure CollectResourceFiles;
var
  resourcefile : TResourceFile;

  procedure ProcessModule(u : TModule);
  var
    res : TCmdStrListItem;
    s   : TCmdStr;
  begin
    { An imported unit's native resources belong to its provider image. }
    if Assigned(u.package) then exit;
    res:=TCmdStrListItem(u.ResourceFiles.First);
    while Assigned(res) do
      begin
        if Path_Absolute(res.FPStr) then
          s:=res.FPStr
        else
          begin
            s:=u.path+res.FPStr;
            if not FileExists(s,True) then
              s:=u.OutputPath+res.FPStr;
          end;
        resourcefile.Collect(s);
        res:=TCmdStrListItem(res.Next);
      end;
  end;

var
  hp : TUsedUnit;
  s : TCmdStr;
begin
  if (TargetInfo.res=res_none) or ((TargetRes.resbin='')
    and (ResCompiler='')) then
      exit;
//  if cs_link_nolink in current_settings.globalswitches then
//    exit;
  s:=ChangeFileExt(CurrentModule.PPUFileName,TargetInfo.resobjext);
  if (res_arch_in_file_name in TargetRes.resflags) then
    s:=ChangeFileExt(s,'.'+cpu2str[Ord(TargetCPU)]+TargetInfo.resobjext);
  resourcefile:=TResourceFile(resinfos[TargetInfo.res]^.resourcefileclass.create(s));
  hp:=TUsedUnit(usedunits.first);
  while Assigned(hp) do
    begin
      ProcessModule(hp.u);
      hp:=TUsedUnit(hp.next);
    end;
  ProcessModule(CurrentModule);
  { Finish collection }
  resourcefile.EndCollect;
  resourcefile.free;
  resourcefile := nil;
end;

procedure initglobals;
begin
  ResCompiler:='';
  RCCompiler:='';
  RCForceFPCRes:=false;
end;

initialization
  Register_InitDone_Proc(@initglobals,nil);
end.
