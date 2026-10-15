{
    Copyright (c) 1998-2008 by Florian Klaempfl and Peter Vreman

    Reads command line options and config files

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
unit options;

{$i fpcdefs.inc}

interface

uses
  CFileUtl,CClasses,VersionCmp,
  GlobType,Globals,Verbose,Systems,CPUInfo,CompRsrc;

Type
  TOption=class
    FirstPass,
    ParaLogo,
    NoPressEnter,
    FPCHelpLines,
    LogoWritten,
    ABISetExplicitly,
    FPUSetExplicitly,
    CPUSetExplicitly,
    OptCPUSetExplicitly: boolean;
    FileLevel : LongInt;
    QuickInfo : string;
    FPCBinaryPath: string;
    ParaIncludeCfgPath,
    ParaIncludePath,
    ParaUnitPath,
    ParaObjectPath,
    ParaLibraryPath,
    ParaFrameworkPath,
    parapackagepath : TSearchPathList;
    paranamespaces : TCmdStrList;
    ParaAlignment   : TAlignmentInfo;
    parapackages : TFPHashObjectList;
    paratarget        : TSystem;
    paratargetasm     : TAsm;
    paratargetdbg     : TDbg;
    parasubtarget    : string;
    LinkTypeSetExplicitly : boolean;
    LinkerSetExplicitly : boolean;
    MemoryModelSetExplicitly : boolean;
    Constructor Create;
    Destructor Destroy;override;
    procedure WriteLogo;
    procedure WriteInfo (More: string);
    procedure WriteHelpPages;
    procedure WriteQuickInfo;
    procedure IllegalPara(const opt:TCmdStr);
    procedure UnsupportedPara(const opt:TCmdStr);
    procedure IgnoredPara(const opt:TCmdStr);
    function  Unsetbool(var Opts:TCmdStr; Pos: LongInt; const FullPara: TCmdStr; RequireBoolPara: Boolean):boolean;
    procedure interpret_option(const opt :TCmdStr;ispara:boolean);
    procedure Interpret_envvar(const EnvName : TCmdStr);
    procedure Interpret_file(const FileName : TPathStr);
    procedure Read_Parameters;
    procedure parsecmd(cmd:TCmdStr);
    procedure TargetOptions(def:boolean);
    procedure CheckOptionsCompatibility;
    procedure ForceStaticLinking;
  private
    // Format is Interpret_[A..Z]_(l|U)
    // with l for lowercase, U for uppercase
    procedure Interpret_A_l(opt, more: TCmdStr);
    procedure Interpret_A_U(opt, more: TCmdStr);
    procedure Interpret_B_l(opt, more: TCmdStr);
    procedure Interpret_B_U(opt, more: TCmdStr);
    procedure Interpret_C_U(opt, more: TCmdStr);
    procedure Interpret_D_l(opt, more: TCmdStr);
    procedure Interpret_D_U(opt, more: TCmdStr);
    procedure Interpret_E_l(opt, more: TCmdStr);
    procedure Interpret_E_U(opt, more: TCmdStr);
    procedure Interpret_F_l(opt, more: TCmdStr);
    procedure Interpret_F_U(opt, more: TCmdStr; ispara: boolean);
    procedure Interpret_G_l(opt, more: TCmdStr);
    procedure Interpret_Help(more: TCmdStr);
    procedure Interpret_H_l(more: TCmdStr);
    procedure Interpret_I_l(more: TCmdStr);
    procedure Interpret_I_U(more: TCmdStr; ispara: boolean);
    procedure Interpret_K_l(opt, more: TCmdStr);
    procedure Interpret_L_l(opt, more: TCmdStr);
    procedure Interpret_M_l(opt, more: TCmdStr);
    procedure Interpret_M_U(opt, more: TCmdStr);
    procedure Interpret_N_l(opt, more: TCmdStr);
    procedure Interpret_O_l(opt, more: TCmdStr);
    procedure Interpret_O_U(opt, more: TCmdStr);
    procedure Interpret_P_U(opt, more: TCmdStr);
    procedure Interpret_R_U(opt, more: TCmdStr);
    procedure Interpret_S_l(opt, more: TCmdStr);
    procedure Interpret_S_U(opt, more: TCmdStr);
    procedure Interpret_T_l(opt, more: TCmdStr);
    procedure Interpret_T_U(opt, more: TCmdStr);
    procedure Interpret_U_l(opt, more: TCmdStr);
    procedure Interpret_U_U(opt, more: TCmdStr);
    procedure Interpret_V_l(opt, more: TCmdStr);
    procedure Interpret_V_U(opt, more: TCmdStr);
    procedure Interpret_W_U(opt, more: TCmdStr);
    procedure Interpret_X_U(opt, more: TCmdStr);

   protected
    MacVersionSet: boolean;
    IdfVersionSet: boolean;
    processorstr: TCmdStr;
    function ParseMacVersionMin(out minversion, invalidateversion: TVersion; const compvarname, value: string; ios: boolean): boolean;
    procedure MaybeSetDefaultMacVersionMacro;

    procedure VerifyTargetProcessor;
  end;

  TOptionClass=class of TOption;

var
  coption : TOptionClass;

procedure read_arguments(cmd:TCmdStr);

implementation

uses
  WideStr,
  CharSet,
  SysUtils,
  version,
  CUtils,CMsgs,
  CompHook,
  SymTable,Scanner,rabase,
  symconst,

  DirParse,
  PkgUtil;

const
  page_size = 24;
  page_width = 80;

var
  option     : TOption;
  read_subfile,         { read subtarget config file, set when a cfgfile is found }
  read_configfile,        { read config file, set when a cfgfile is found }
  disable_configfile : boolean;
  subcfg,
  fpcdir,
  ppccfg,
  param_file    : string;   { file to compile specified on the commandline }


{****************************************************************************
                     Options not supported on all platforms
****************************************************************************}

const
  suppported_targets_x_smallr = systems_linux + systems_android;

{****************************************************************************
                                 Defines
****************************************************************************}

procedure set_default_link_type;
begin
  Undef_System_Macro('FPC_LINK_SMART');
  Def_System_Macro('FPC_LINK_STATIC');
  Undef_System_Macro('FPC_LINK_DYNAMIC');
  InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches+[cs_link_static];
  InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches-[cs_link_shared,cs_link_smart];
end;

procedure set_endianess_macros;
  begin
    { endian define }
    case TargetInfo.endian of
      endian_little :
        begin
          Def_System_Macro('ENDIAN_LITTLE');
          Def_System_Macro('FPC_LITTLE_ENDIAN');
          Undef_System_Macro('ENDIAN_BIG');
          Undef_System_Macro('FPC_BIG_ENDIAN');
        end;
      endian_big :
        begin
          Def_System_Macro('ENDIAN_BIG');
          Def_System_Macro('FPC_BIG_ENDIAN');
          Undef_System_Macro('ENDIAN_LITTLE');
          Undef_System_Macro('FPC_LITTLE_ENDIAN');
        end;
    end;
  end;


{****************************************************************************
                                 Toption
****************************************************************************}

procedure StopOptions(err:LongInt);
begin
  if Assigned(Option) then
   begin
     Option.free;
     Option:=nil;
   end;
  raise ECompilerAbortSilent.Create;
end;


function is_identifier(const s: TCmdStr): boolean;
var
  i: LongInt;
begin
  result:=false;
  if (s='') or not (s[1] in ['A'..'Z','a'..'z','_']) then
    exit;
  for i:=2 to length(s) do
    if not (s[I] in ['A'..'Z','a'..'z','0'..'9','_']) then
      exit;
  result:=true;
end;


procedure TOption.WriteLogo;
var
  msg : TMsgStr;
  p : pchar;
begin
  if not LogoWritten then
    begin
      msg:=MessageStr(option_logo);
      p:=pchar(msg);
      while Assigned(p) do
        Comment(VNormal,GetMsgLine(p));
      LogoWritten:= true;
    end;
end;


procedure TOption.WriteInfo(More: string);
var
  msg_str: TMsgStr;
  p : pchar;
  hs,hs1,hs3,s : TCmdStr;
  J: LongInt;
  xmloutput: Text;
const
  NewLineStr = '$\n';
  OSTargetsPlaceholder = '$OSTARGETS';
  CPUListPlaceholder = '$INSTRUCTIONSETS';
  FPUListPlaceholder = '$FPUINSTRUCTIONSETS';
  ABIListPlaceholder = '$ABITARGETS';
  OptListPlaceholder = '$OPTIMIZATIONS';
  WPOListPlaceholder = '$WPOPTIMIZATIONS';
  AsmModeListPlaceholder = '$ASMMODES';
  ControllerListPlaceholder = '$CONTROLLERTYPES';
  FeatureListPlaceholder = '$FEATURELIST';
  ModeSwitchListPlaceholder = '$MODESWITCHES';
  CodeGenerationBackendPlaceholder = '$CODEGENERATIONBACKEND';

  procedure SplitLine (var OrigString: TCmdStr; const Placeholder: TCmdStr;
                                                 out RemainderString: TCmdStr);
  var
    I: LongInt;
    HS2: TCmdStr;
  begin
    RemainderString := '';
    if OrigString = '' then
     Exit;
    repeat
     I := Pos (NewLineStr, OrigString);
     if I > 0 then
      begin
       HS2 := Copy (OrigString, 1, Pred (I));
{ Stop if this line contains the placeholder for list replacement }
       if Pos (Placeholder, HS2) > 0 then
        begin
         RemainderString := Copy (OrigString, I + Length (NewLineStr),
                                Length (OrigString) - I - Length (NewLineStr));
{ Special case - NewLineStr at the end of the line }
         if RemainderString = '' then
          RemainderString := NewLineStr;
         OrigString := HS2;
         Exit;
        end;
       Comment (VNormal, HS2);
       Delete (OrigString, 1, Pred (I) + Length (NewLineStr));
      end;
    until I = 0;
    if (OrigString <> '') and (Pos (Placeholder, OrigString) = 0) then
     Comment (VNormal, OrigString);
  end;

  procedure ListOSTargets (OrigString: TCmdStr);
  var
    target : TSystem;
  begin
    SplitLine (OrigString, OSTargetsPlaceholder, HS3);
    for target:=low(TSystem) to high(TSystem) do
    if Assigned(targetinfos[Ord(target)]) then
     begin
      hs1:=targetinfos[Ord(target)]^.shortname;
      if OrigString = '' then
       Comment (VNormal, hs1)
      else
       begin
        hs := OrigString;
        hs1:=hs1 + ': ' + targetinfos[Ord(target)]^.name;
        if tf_under_development in targetinfos[Ord(target)]^.flags then
         hs1:=hs1+' {*}';
        Replace(hs,OSTargetsPlaceholder,hs1);
        Comment(VNormal,hs);
       end;
     end;
  end;

  procedure ListOSTargetsXML;
  var
    target : TSystem;
  begin
    WriteLn(xmloutput,'    <ostargets>');
    for target:=low(TSystem) to high(TSystem) do
    if Assigned(targetinfos[Ord(target)]) then
      begin
        Write(xmloutput,'      <ostarget shortname="',targetinfos[Ord(target)]^.shortname,'" name="',targetinfos[Ord(target)]^.name,'"');
        if tf_under_development in targetinfos[Ord(target)]^.flags then
          Write(xmloutput,' experimental="1"');
        WriteLn(xmloutput,'/>');
      end;
    WriteLn(xmloutput,'    </ostargets>');
  end;

  procedure ListCPUInstructionSets (OrigString: TCmdStr);
  var
    cpu : TCPUType;
  begin
    SplitLine (OrigString, CPUListPlaceholder, HS3);
    hs1:='';
    for cpu:=low(TCPUType) to high(TCPUType) do
     begin
      if (OrigString = '') then
       begin
        if CPUTypeStr [CPU] <> '' then
         Comment (VNormal, CPUTypeStr [CPU]);
       end
      else
       begin
        if length(hs1+CPUTypeStr[cpu])>70 then
         begin
          hs:=OrigString;
          HS1 := HS1 + ',';
          Replace(hs,CPUListPlaceholder,hs1);
          Comment(VNormal,hs);
          hs1:=''
         end
        else if hs1<>'' then
         hs1:=hs1+',';
        if CPUTypeStr[cpu]<>'' then
         hs1:=hs1+CPUTypeStr[cpu];
       end;
     end;
    if (OrigString <> '') and (hs1 <> '') then
     begin
      hs:=OrigString;
      Replace(hs,CPUListPlaceholder,hs1);
      Comment(VNormal,hs);
      hs1:=''
     end;
  end;

  procedure ListCPUInstructionSetsXML;
  var
    cpu : TCPUType;
  begin
    WriteLn(xmloutput,'    <cpuinstructionsets>');
    for cpu:=low(TCPUType) to high(TCPUType) do
      if CPUTypeStr [CPU] <> '' then
        WriteLn(xmloutput,'      <cpuinstructionset name="',CPUTypeStr [CPU], '"/>');
    WriteLn(xmloutput,'    </cpuinstructionsets>');
  end;

  procedure ListFPUInstructionSets (OrigString: TCmdStr);
  var
    fpu : TFPUType;
  begin
    SplitLine (OrigString, FPUListPlaceholder, HS3);
    hs1:='';
    for fpu:=low(TFPUType) to high(TFPUType) do
     begin
      if (OrigString = '') then
       begin
        if FPUTypeStr [FPU] <> '' then
         Comment (VNormal, FPUTypeStr [FPU]);
       end
      else
       begin
        if length(hs1+FPUTypeStr[fpu])>70 then
         begin
          hs:=OrigString;
          HS1 := HS1 + ',';
          Replace(hs,FPUListPlaceholder,hs1);
          Comment(VNormal,hs);
          hs1:=''
         end
        else if hs1<>'' then
         hs1:=hs1+',';
        if FPUTypeStr[fpu]<>'' then
         hs1:=hs1+FPUTypeStr[fpu];
       end;
     end;
    if (OrigString <> '') and (hs1 <> '') then
     begin
      hs:=OrigString;
      Replace(hs,FPUListPlaceholder,hs1);
      Comment(VNormal,hs);
      hs1:=''
     end;
  end;

  procedure ListFPUInstructionSetsXML;
  var
    fpu : TFPUType;
  begin
    WriteLn(xmloutput,'    <fpuinstructionsets>');
    for fpu:=low(TFPUType) to high(TFPUType) do
      if FPUTypeStr [fpu] <> '' then
        WriteLn(xmloutput,'      <cpuinstructionset name="',FPUTypeStr [fpu], '"/>');
    WriteLn(xmloutput,'    </fpuinstructionsets>');
  end;

  procedure ListABITargets (OrigString: TCmdStr);
  var
    abi : TABI;
  begin
    SplitLine (OrigString, ABIListPlaceholder, HS3);
    for abi:=low(abi) to high(abi) do
     begin
      if not ABIInfo[abi].supported then
       continue;
      hs1:=ABIInfo[abi].name;
      if hs1<>'' then
       begin
        if OrigString = '' then
         Comment (VNormal, HS1)
        else
         begin
          hs:=OrigString;
          Replace(hs,ABIListPlaceholder,hs1);
          Comment(VNormal,hs);
         end;
       end;
     end;
  end;

  procedure ListABITargetsXML;
  var
    abi : TABI;
  begin
    WriteLn(xmloutput,'    <abis>');
    for abi:=low(abi) to high(abi) do
     begin
      if not ABIInfo[abi].supported then
        continue;
      if ABIInfo[abi].name<>'' then
        WriteLn(xmloutput,'      <abi name="',ABIInfo[abi].name, '"/>');
     end;
    WriteLn(xmloutput,'    </abis>');
  end;

  procedure ListOptimizations (OrigString: TCmdStr);
  var
    opt : TOptimizerSwitch;
  begin
    SplitLine (OrigString, OptListPlaceholder, HS3);
    for opt:=low(TOptimizerSwitch) to high(TOptimizerSwitch) do
     begin
      if opt in supported_optimizerswitches then
       begin
        hs1:=OptimizerSwitchStr[opt];
        if hs1<>'' then
         begin
          if OrigString = '' then
           Comment (VNormal, hs1)
          else
           begin
            hs:=OrigString;
            Replace(hs,OptListPlaceholder,hs1);
            Comment(VNormal,hs);
           end;
         end;
       end;
     end;
  end;

  procedure ListOptimizationsXML;
  var
    opt: TOptimizerSwitch;
  begin
    WriteLn(xmloutput,'    <optimizations>');
    for opt:=low(TOptimizerSwitch) to high(TOptimizerSwitch) do
      if OptimizerSwitchStr[opt]<>'' then
        WriteLn(xmloutput,'      <optimization name="',OptimizerSwitchStr[opt],'"/>');
    WriteLn(xmloutput,'    </optimizations>');
  end;

  procedure ListWPOptimizations (OrigString: TCmdStr);
  var
    wpopt: TWPOptimizerSwitch;
  begin
    SplitLine (OrigString, WPOListPlaceholder, HS3);
    for wpopt:=low(TWPOptimizerSwitch) to high(TWPOptimizerSwitch) do
     begin
{     currently all whole program optimizations are platform-independent
      if opt in supported_wpoptimizerswitches then
}
       begin
        hs1:=WPOptimizerSwitchStr[wpopt];
        if hs1<>'' then
         begin
          if OrigString = '' then
           Comment (VNormal, hs1)
          else
           begin
            hs:=OrigString;
            Replace(hs,WPOListPlaceholder,hs1);
            Comment(VNormal,hs);
           end;
         end;
       end;
     end;
  end;

  procedure ListWPOptimizationsXML;
  var
    wpopt: TWPOptimizerSwitch;
  begin
    WriteLn(xmloutput,'    <wpoptimizations>');
    for wpopt:=low(TWPOptimizerSwitch) to high(TWPOptimizerSwitch) do
      if WPOptimizerSwitchStr[wpopt]<>'' then
        WriteLn(xmloutput,'      <wpoptimization name="',WPOptimizerSwitchStr[wpopt],'"/>');
    WriteLn(xmloutput,'    </wpoptimizations>');
  end;

  procedure ListAsmModes (OrigString: TCmdStr);
  var
    AsmMode : TAsmMode;
  begin
    SplitLine (OrigString, AsmModeListPlaceholder, HS3);
    for AsmMode:=low(TAsmMode) to high(TAsmMode) do
    if Assigned(asmmodeinfos[AsmMode]) then
     begin
      hs1:=asmmodeinfos[AsmMode]^.idtxt;
      if hs1<>'' then
       begin
        if OrigString = '' then
         Comment (VNormal, hs1)
        else
         begin
          hs:=OrigString;
          Replace(hs,AsmModeListPlaceholder,hs1);
          Comment(VNormal,hs);
         end;
       end;
     end;
  end;

  procedure ListAsmModesXML;
  var
    AsmMode : TAsmMode;
  begin
    WriteLn(xmloutput,'    <asmmodes>');
    for AsmMode:=low(TAsmMode) to high(TAsmMode) do
      if Assigned(asmmodeinfos[AsmMode]) then
        WriteLn(xmloutput,'        <asmmode name="',asmmodeinfos[AsmMode]^.idtxt,'"/>');
    WriteLn(xmloutput,'    </asmmodes>');
  end;

  procedure ListControllerTypes (OrigString: TCmdStr);
  var
    ControllerType : TControllerType;
  begin
{$PUSH}
 {$WARN 6018 OFF} (* Unreachable code due to compile time evaluation *)
    if (ControllerSupport) then
     begin
      SplitLine (OrigString, ControllerListPlaceholder, HS3);
      hs1:='';
      for ControllerType:=low(TControllerType) to high(TControllerType) do
       begin
        if (OrigString = '') then
         begin
          if Embedded_Controllers [ControllerType].ControllerTypeStr <> '' then
           Comment (VNormal, Embedded_Controllers [ControllerType].ControllerTypeStr);
         end
        else
         begin
          if length(hs1+embedded_controllers[ControllerType].ControllerTypeStr)
                                                                       >70 then
           begin
            hs:=OrigString;
            HS1 := HS1 + ',';
            Replace(hs,ControllerListPlaceholder,hs1);
            Comment(VNormal,hs);
            hs1:=''
           end
          else if hs1<>'' then
           hs1:=hs1+',';
          if embedded_controllers[ControllerType].ControllerTypeStr<>'' then
           hs1:=hs1+embedded_controllers[ControllerType].ControllerTypeStr;
         end;
       end;
      if (OrigString <> '') and (hs1<>'') then
       begin
        hs:=OrigString;
        Replace(hs,ControllerListPlaceholder,hs1);
        Comment(VNormal,hs);
        hs1:=''
       end;
     end;
{$POP}
  end;

  procedure ListControllerTypesXML;
  var
    ControllerType : TControllerType;
  begin
{$PUSH}
 {$WARN 6018 OFF} (* Unreachable code due to compile time evaluation *)
    if (ControllerSupport) then
     begin
      WriteLn(xmloutput,'    <controllertypes>');
      for ControllerType:=low(TControllerType) to high(TControllerType) do
        if embedded_controllers[ControllerType].ControllerTypeStr<>'' then
          WriteLn(xmloutput,'      <controllertype name="',embedded_controllers[ControllerType].ControllerTypeStr,
            '" controllerunit="',embedded_controllers[ControllerType].controllerunitstr, '"/>');
      WriteLn(xmloutput,'    </controllertypes>');
     end;
{$POP}
  end;

  procedure ListFeatures (OrigString: TCmdStr);
  var
    Feature: TFeature;
  begin
    SplitLine (OrigString, FeatureListPlaceholder, HS3);
    HS1 := '';
    for Feature := Low (TFeature) to High (TFeature) do
     begin
      if (OrigString = '') then
       begin
        if FeatureStr [Feature] <> '' then
         Comment (VNormal, FeatureStr [Feature]);
       end
      else
       begin
        if Length (HS1 + FeatureStr [Feature]) > 70 then
         begin
          HS := OrigString;
          HS1 := HS1 + ',';
          Replace (HS, FeatureListPlaceholder, HS1);
          Comment (VNormal, HS);
          HS1 := ''
         end
        else if HS1 <> '' then
         HS1 := HS1 + ',';
        if FeatureStr [Feature] <> '' then
         HS1 := HS1 + FeatureStr [Feature];
       end;
     end;
    if (OrigString <> '') and (HS1 <> '') then
     begin
      HS := OrigString;
      Replace (HS, FeatureListPlaceholder, HS1);
      Comment (VNormal, HS);
      HS1 := ''
     end;
  end;

  procedure ListFeaturesXML;
  var
    Feature: TFeature;
  begin
    WriteLn(xmloutput,'    <features>');
    for Feature := Low (TFeature) to High (TFeature) do
      if FeatureStr [Feature] <> '' then
         WriteLn(xmloutput,'      <feature name="',FeatureStr [Feature],'"/>');
    WriteLn(xmloutput,'    </features>');
  end;

  procedure ListModeswitches (OrigString: TCmdStr);
  var
    Modeswitch: TModeSwitch;
  begin
    SplitLine (OrigString, ModeswitchListPlaceholder, HS3);
    HS1 := '';
    for Modeswitch := Low (TModeSwitch) to High (TModeSwitch) do
     begin
      if (OrigString = '') then
       begin
         if ModeswitchStr [ord(Modeswitch)] <> '' then
          Comment (VNormal, ModeswitchStr [ord(Modeswitch)]);
       end
      else
       begin
         if Length (HS1 + ModeswitchStr [ord(Modeswitch)]) > 60 then
         begin
          HS := OrigString;
          HS1 := HS1 + ',';
          Replace (HS, ModeswitchListPlaceholder, HS1);
          Comment (VNormal, HS);
          HS1 := ''
         end
        else if HS1 <> '' then
         HS1 := HS1 + ',';
         if ModeswitchStr [ord(Modeswitch)] <> '' then
          HS1 := HS1 + ModeswitchStr [ord(Modeswitch)];
       end;
     end;
    if (OrigString <> '') and (HS1 <> '') then
     begin
      HS := OrigString;
      Replace (HS, ModeswitchListPlaceholder, HS1);
      Comment (VNormal, HS);
      HS1 := ''
     end;
  end;

  procedure ListModeswitchesXML;
  var
    Modeswitch: TModeSwitch;
  begin
    WriteLn(xmloutput,'    <modeswitches>');
    for Modeswitch:=Low(TModeSwitch) to High(TModeSwitch) do
       if ModeswitchStr [ord(Modeswitch)]<>'' then
         WriteLn(xmloutput,'      <modeswitch name="',ModeswitchStr [ord(Modeswitch)],'"/>');
    WriteLn(xmloutput,'    </modeswitches>');
  end;

  procedure ListCodeGenerationBackend (OrigString: TCmdStr);
    begin
      SplitLine (OrigString, CodeGenerationBackendPlaceholder, HS3);
      hs1:=cgbackend2str[CGBackend];
      if OrigString = '' then
        Comment (VNormal, hs1)
      else
        begin
          hs:=OrigString;
          Replace(hs,CodeGenerationBackendPlaceholder,hs1);
          Comment(VNormal,hs);
        end;
    end;

  procedure ListCodeGenerationBackendXML;
    begin
      WriteLn(xmloutput,'    <codegeneratorbackend>',cgbackend2str[CGBackend],'</codegeneratorbackend>');
    end;


begin
  if More = '' then
   begin
    msg_str:=MessageStr(option_info);
    p:=pchar(msg_str);
    while Assigned(p) do
     begin
      s:=GetMsgLine(p);
      { list permitted values for certain options }
      if pos(OSTargetsPlaceholder,s)>0 then
       ListOSTargets (S)
      else if pos(CPUListPlaceholder,s)>0 then
       ListCPUInstructionSets (S)
      else if pos(FPUListPlaceholder,s)>0 then
       ListFPUInstructionSets (S)
      else if pos(ABIListPlaceholder,s)>0 then
       ListABITargets (S)
      else if pos(OptListPlaceholder,s)>0 then
       ListOptimizations (S)
      else if pos(WPOListPlaceholder,s)>0 then
       ListWPOptimizations (S)
      else if Pos (ModeswitchListPlaceholder, S) > 0 then
       ListModeswitches (S)
      else if pos(AsmModeListPlaceholder,s)>0 then
       ListAsmModes (S)
      else if pos(ControllerListPlaceholder,s)>0 then
       ListControllerTypes (S)
      else if pos(FeatureListPlaceholder,s)>0 then
       ListFeatures (S)
      else if pos(CodeGenerationBackendPlaceholder,s)>0 then
       ListCodeGenerationBackend (S)
      else
       Comment(VNormal,s);
     end;
   end
  else if Copy(More,1,1) = 'x' then
    begin
      Assign(xmloutput,Copy(More,2));
      Rewrite(xmloutput);
      WriteLn(xmloutput,'<?xml version="1.0" encoding="utf-8"?>');
      WriteLn(xmloutput,'<fpcoutput>');
      WriteLn(xmloutput,'  <info>');
      ListOSTargetsXML;
      ListCPUInstructionSetsXML;
      ListFPUInstructionSetsXML;
      ListABITargetsXML;
      ListOptimizationsXML;
      ListWPOptimizationsXML;
      ListModeswitchesXML;
      ListAsmModesXML;
      ListControllerTypesXML;
      ListFeaturesXML;
      ListCodeGenerationBackendXML;
      WriteLn(xmloutput,'  </info>');
      WriteLn(xmloutput,'</fpcoutput>');
      Close(xmloutput);
   end
  else
   begin
     J := 1;
     while J <= Length (More) do
      begin
       if J > 1 then
        Comment(VNormal,'');  (* Put empty line between multiple sections *)
       case More [J] of
        'a': ListABITargets ('');
        'b': Comment(VNormal, cgbackend2str[CGBackend]);
        'c': ListCPUInstructionSets ('');
        'f': ListFPUInstructionSets ('');
        'i': ListAsmModes ('');

        'm': ListModeswitches ('');
        'o': ListOptimizations ('');
        'r': ListFeatures ('');
        't': ListOSTargets ('');
        'u': ListControllerTypes ('');
        'w': ListWPOptimizations ('');
       else
        IllegalPara ('-i' + More);
       end;
       Inc (J);
      end;
    end;
  StopOptions(0);
end;


procedure TOption.WriteHelpPages;

  function PadEnd(s:string;i:LongInt):string;
  begin
    if length(s) >= i then
     S := S + ' '
    else
     while (length(s)<i) do
      s:=s+' ';
    PadEnd:=s;
  end;

var
  lastident,
  j,outline,
  ident,
  HelpLineHeight,
  lines : LongInt;
  show  : boolean;
  opt   : string[32];
  input,
  HelpLine,
  s     : string;
  p     : pchar;
  msg_str: TMsgStr;
begin
  WriteLogo;
  Lines:=4;
  if FPCHelpLines then
   Message1(option_usage,FixFileName(FPCBinaryPath))
  else
   Message1(option_usage,FixFileName(system.ParamStr(0)));
  lastident:=0;
  msg_str:=MessageStr(option_help_pages);
  p:=pchar(msg_str);
  while Assigned(p) do
   begin
   { get a line and reset }
     s:=GetMsgLine(p);
     ident:=0;
     show:=false;
   { parse options }
     case s[1] of
      'F': if FPCHelpLines then
            Show := true;
{$ifdef UNITALIASES}
      'a',
{$endif}
{$ifdef EXTDEBUG}
      'e',
{$endif EXTDEBUG}
{$ifdef i386}
      '3',
{$endif}
{$ifdef x86_64}
      '4',
{$endif}

{$ifdef aarch64}
      'a',
{$endif}
      '*' : show:=true;
     end;
     if show then
      begin
        case s[2] of
         'g',
{$ifdef Unix}
         'L',
{$endif}
         '*' : show:=true;
        else
         show:=false;
        end;
      end;
   { now we may show the message or not }
     if show then
      begin
        case s[3] of
         '0' : begin
                 ident:=0;
                 outline:=0;
               end;
         '1' : begin
                 ident:=2;
                 outline:=7;
               end;
         '2' : begin
                 ident:=6;
                 outline:=11;
               end;
         '3' : begin
                 ident:=9;
                 outline:=11;
               end;
         else
           InternalError(2013112906);
        end;
        j:=pos('_',s);
        opt:=Copy(s,4,j-4);
        if opt='*' then
         opt:=''
        else
        if (opt=' ') or (opt[1]='@') then
         opt:=PadEnd(opt,outline)
        else
         opt:=PadEnd('-'+opt,outline);
        if (ident=0) and (lastident<>0) then
         begin
           Comment(VNormal,'');
           inc(Lines);
         end;
        HelpLine := PadEnd('',ident)+opt+Copy(s,j+1,255);
        if HelpLine = '' then
         HelpLineHeight := 1
        else
         HelpLineHeight := Succ (CharLength (HelpLine) div Page_Width);
      { page full ? }
        if (lines + HelpLineHeight >= page_size - 1) then
         begin
           if not NoPressEnter then
            begin
              Message(option_help_press_enter);
              readln(input);
              if upper(input)='Q' then
               StopOptions(0);
            end;
           lines:=0;
         end;
        Comment(VNormal,HelpLine);
        LastIdent:=Ident;
        Inc (Lines, HelpLineHeight);
      end;
   end;
  StopOptions(0);
end;


procedure TOption.IllegalPara(const opt: TCmdStr);
begin
  Message1(option_illegal_para,opt);
  Message(option_help_pages_para);
  StopOptions(1);
end;


procedure TOption.UnsupportedPara(const opt: TCmdStr);
begin
  Message1(option_unsupported_target,opt);
  StopOptions(1);
end;


procedure TOption.IgnoredPara(const opt: TCmdStr);
begin
  Message1(option_ignored_target,opt);
end;


procedure TOption.ForceStaticLinking;
begin
  Def_System_Macro('FPC_LINK_STATIC');
  Undef_System_Macro('FPC_LINK_SMART');
  Undef_System_Macro('FPC_LINK_DYNAMIC');
  include(InitSettings.GlobalSwitches,cs_link_static);
  exclude(InitSettings.GlobalSwitches,cs_link_smart);
  exclude(InitSettings.GlobalSwitches,cs_link_shared);
  LinkTypeSetExplicitly:=true;
end;


function TOption.ParseMacVersionMin(out minversion,
  invalidateversion: TVersion; const compvarname, value: string; ios: boolean
  ): boolean;

  function subval(start,maxlen: LongInt; out stop: LongInt): string;
    var
      i: LongInt;
    begin
      result:='';
      i:=start;
      while (i<=length(value)) and
            (value[i] in ['0'..'9']) do
        inc(i);
      { sufficient amount of digits? }
      if (i=start) or
         (i-start>maxlen) then
        exit;
      result:=copy(value,start,i-start);
      stop:=i;
    end;

  var
    temp,
    compvarvalue,
    versionstr: string[15];
    major, minor, patch: cardinal;
    i, err: LongInt;
    osx_minor_two_digits: boolean;
  begin
    invalidateversion.invalidate;
    versionstr:=value;
    MacVersionSet:=false;
    { check whether the value is a valid version number }
    if value='' then
      begin
        Undef_System_Macro(compvarname);
        exit(true);
      end;
    { major version number }
    compvarvalue:=subval(1,2,i);
    { not enough digits -> invalid }
    if compvarvalue='' then
      exit(false);
    { already end of string -> invalid }
    if (i>=length(value)) or
       (value[i]<>'.') then
      exit(false);
    val(compvarvalue,major,err);
    if err<>0 then
      exit(false);
    { minor version number }
    temp:=subval(i+1,2,i);
    if temp='' then
      exit(false);
    val(temp,minor,err);
    if err<>0 then
      exit(false);
    { on Mac OS X, the minor version number was originally limited to 1 digit;
      with 10.10 the format changed and two digits were also supported; on iOS,
      the minor version number always takes up two digits }
    osx_minor_two_digits:=false;
    if not ios then
      begin
        { if the minor version number is two digits on OS X (the case since
          OS X 10.10), we also have to add two digits for the patch level}
        if length(temp)=2 then
          osx_minor_two_digits:=true;
      end
    { the minor version number always takes up two digits on iOS }
    else if length(temp)=1 then
      temp:='0'+temp;
    compvarvalue:=compvarvalue+temp;
    { optional patch level }
    patch:=0;
    if i<=length(value) then
      begin
        if value[i]<>'.' then
          exit(false);
        temp:=subval(i+1,2,i);
        if temp='' then
          exit(false);
        { there's only room for a single digit patch level in the version macro
          for Mac OS X. gcc sets it to zero if there are more digits, but that
          seems worse than clamping to 9 (don't declare as invalid like with
          minor version number, because there is a precedent like 10.4.11).

          As of OS X 10.10 there are two digits for the patch level
        }
        if not ios and
           not osx_minor_two_digits then
          begin
            if length(temp)<>1 then
              temp:='9';
          end
        else
          begin
            { on iOS, the patch level is always two digits }
            if length(temp)=1 then
              temp:='0'+temp;
          end;
        compvarvalue:=compvarvalue+temp;
        { must be the end }
        if i<=length(value) then
          exit(false);
        val(temp,patch,err);
        if err<>0 then
          exit(false);
      end
    else if not ios and
       not osx_minor_two_digits then
      begin
        compvarvalue:=compvarvalue+'0';
        versionstr:=versionstr+'.0'
      end
    else
      begin
        compvarvalue:=compvarvalue+'00';
        { command line versions still only use one 0 though }
        versionstr:=versionstr+'.0'
      end;
    minversion.init(versionstr,major,minor,patch);
    Set_System_CompVar(compvarname,compvarvalue);
    MacVersionSet:=true;
    result:=true;
  end;


procedure TOption.MaybeSetDefaultMacVersionMacro;
var
  EnvStr: AnsiString;
begin
  if not(TargetInfo.system in systems_darwin) then
    exit;
  if MacVersionSet then
    exit;
  { check for deployment target set via environment variable }
  if not(TargetInfo.system in [system_i386_iphonesim,system_aarch64_ios,system_x86_64_iphonesim,system_aarch64_iphonesim]) then
    begin
      EnvStr:=GetEnvironmentVariable('MACOSX_DEPLOYMENT_TARGET');
      if EnvStr<>'' then
        if not ParseMacVersionMin(MacOSXVersionMin,IPhoneOSVersionMin,'MAC_OS_X_VERSION_MIN_REQUIRED',EnvStr,false) then
          Message1(option_invalid_macosx_deployment_target,EnvStr)
        else
          begin

            exit;
          end;
    end
  else
    begin
      EnvStr:=GetEnvironmentVariable('IPHONEOS_DEPLOYMENT_TARGET');
      if EnvStr<>'' then
        if not ParseMacVersionMin(IPhoneOSVersionMin,MacOSXVersionMin,'IPHONE_OS_VERSION_MIN_REQUIRED',EnvStr,true) then
          Message1(option_invalid_iphoneos_deployment_target,EnvStr)
        else
          exit;
    end;
  { nothing specified -> defaults }
  case TargetInfo.system of
    system_i386_darwin,
    system_x86_64_darwin:
      begin
        if not ParseMacVersionMin(MacOSXVersionMin,IPhoneOSVersionMin,'MAC_OS_X_VERSION_MIN_REQUIRED','10.8.0',false) then
          InternalError(2022090912);
      end;
    system_i386_iphonesim:
      begin
        if not ParseMacVersionMin(IPhoneOSVersionMin,MacOSXVersionMin,'IPHONE_OS_VERSION_MIN_REQUIRED','9.0.0',false) then
          InternalError(2022090913);
      end;
    system_aarch64_ios,
    system_x86_64_iphonesim:
      begin
        if not ParseMacVersionMin(IPhoneOSVersionMin,MacOSXVersionMin,'IPHONE_OS_VERSION_MIN_REQUIRED','9.0.0',false) then
          InternalError(2022090914);
      end;
    system_aarch64_iphonesim:
      begin
        if not ParseMacVersionMin(IPhoneOSVersionMin,MacOSXVersionMin,'IPHONE_OS_VERSION_MIN_REQUIRED','14.0.0',false) then
          InternalError(2023032201);
      end;
    system_aarch64_darwin:
      begin
        if not ParseMacVersionMin(MacOSXVersionMin,IPhoneOSVersionMin,'MAC_OS_X_VERSION_MIN_REQUIRED','11.0.0',false) then
          InternalError(2022090915);
      end
    else
      InternalError(2012031001);
  end;
end;




procedure TOption.VerifyTargetProcessor;
  begin
    { no custom target processor specified -> ok }
    if processorstr='' then
      exit;
    { custom target processor specified -> verify it's the one we support }
    if upcase(processorstr)<>upcase(TargetCPUString) then
      Message1(option_invalid_target_architecture,processorstr);
  end;


function TOption.Unsetbool(var Opts: TCmdStr; Pos: LongInt;
  const FullPara: TCmdStr; RequireBoolPara: Boolean): boolean;
{ checks if the character after pos in Opts is a + or a - and returns resp.
  false or true. If it is another character (or none), it also returns false }
begin
  UnsetBool := false;
  if Length(Opts)>Pos then
   begin
    inc(Pos);
    UnsetBool := Opts[Pos] = '-';
    if Opts[Pos] in ['-','+']then
     delete(Opts,Pos,1)
    else if RequireBoolPara then
     IllegalPara(FullPara);
   end;
end;

procedure TOption.interpret_option(const opt:TCmdStr;ispara:boolean);
var
  more : TCmdStr;

begin
  if opt='' then
   exit;

  { Nexus procedure profiling is a whole-invocation option. Handle it before
    the normal first-pass filter so PPUs are evaluated with the correct state. }
  if CompareText(opt,'-profile')=0 then
   begin
    include(InitSettings.ModuleSwitches,cs_nexus_profile);
    include(CurrentSettings.ModuleSwitches,cs_nexus_profile);
    exit;
   end;

  { only parse define,undef,target,verbosity,link etc options the firsttime
    -Us must now also be first-passed to avoid rejection of -Sf options
    earlier in command line }
  if FirstPass and
     not(
         (opt[1]='-') and
         (
          ((length(opt)>1) and (opt[2] in ['i','d','v','T','t','u','n','x','X','l','U'])) or
          ((length(opt)>3) and (opt[2]='F') and (opt[3] in ['e','f'])) or
          ((length(opt)>2) and (opt[2]='C') and (opt[3] in ['a','b','f','p'])) or
          ((length(opt)>3) and (opt[2]='W') and (opt[3] in ['m','p']))
         )
        ) then
    exit;

  Message1(option_handling_option,opt);
  case opt[1] of
    '-' :
      begin
         more:=Copy(opt,3,2147483647);
         if FirstPass then
           Message1(option_interpreting_firstpass_option,opt)
         else
           Message1(option_interpreting_option,opt);
         case opt[2] of
           '?' : Interpret_Help(more);
           'a' : Interpret_A_l(opt,more);
           'A' : Interpret_A_U(opt,more);
           'b' : Interpret_B_l(opt,more);
           'B' : Interpret_B_U(opt,more);
           'C' : Interpret_C_U(opt,more);
           'd' : Interpret_D_l(opt,more);
           'D' : Interpret_D_U(opt,more);
           'e' : Interpret_E_l(opt,more);
           'E' : Interpret_E_U(opt,more);
           'f' : Interpret_F_l(opt,more);
           'F' : Interpret_F_U(opt,more,ispara);
           'g' : Interpret_G_l(opt,more);
           'h' : Interpret_H_l(more);
           'i' : Interpret_I_l(more);
           'I' : Interpret_I_U(more,ispara);
           'k' : Interpret_K_l(opt,more);
           'l' : Interpret_L_l(opt,more);
           'm' : Interpret_M_l(opt,more);
           'M' : Interpret_M_U(opt,more);
           'n' : Interpret_N_l(opt,more);
           'o' : Interpret_O_l(opt,more);
           'O' : Interpret_O_U(opt,more);
           'p' : IllegalPara(opt);
           'P' : Interpret_P_U(opt,more);
           'R' : Interpret_R_U(opt,more);
           's' : Interpret_S_l(opt,more);
           'S' : Interpret_S_U(opt,more);
           'T' : Interpret_T_U(opt,more);
           't' : Interpret_T_l(opt,more);
           'u' : Interpret_U_l(opt,more);
           'U' : Interpret_U_U(opt,more);
           'v' : Interpret_V_l(opt,more);
           'V' : Interpret_V_U(opt,more);
           'W' : Interpret_W_U(opt,more);
           'X' : Interpret_X_U(opt,more);
         else
           IllegalPara(opt);
         end;
       end;

    '@' :
      begin
        Message(option_no_nested_response_file);
        StopOptions(1);
      end;

    else
      begin
        if (length(param_file)<>0) then
          Message2(option_only_one_source_support,param_file,opt);
        param_file:=opt;
        Message1(option_found_file,opt);
      end;
  end;
end;


procedure TOption.Interpret_file(const FileName: TPathStr);

  procedure RemoveSep(var fn:TPathStr);
  var
    i : LongInt;
  begin
    i:=0;
    while (i<length(fn)) and (fn[i+1] in [',',' ',#9]) do
      inc(i);
    Delete(fn,1,i);
    i:=length(fn);
    while (i>0) and (fn[i] in [',',' ',#9]) do
      dec(i);
    fn:=copy(fn,1,i);
  end;

  function GetName(var fn:TPathStr):TPathStr;
  var
    i : LongInt;
  begin
    i:=0;
    while (i<length(fn)) and (fn[i+1] in ['a'..'z','A'..'Z','0'..'9','_','-']) do
     inc(i);
    GetName:=Copy(fn,1,i);
    Delete(fn,1,i);
  end;

const
  maxlevel = 15;
var
  f     : text;
  s, tmp,
  opts  : TCmdStr;
  skip  : array[0..maxlevel] of boolean;
  line,
  level : LongInt;
  option_read : boolean;
  oldfilemode : byte;
  ConfigFile: TPathStr;
begin
{ avoid infinite loop }
  Inc(FileLevel);
  Option_read:=false;
  If FileLevel>MaxLevel then
   Message(option_too_many_cfg_files);
  if not ParaIncludeCfgPath.FindFile(FileName,true,ConfigFile) then
    ConfigFile := ExpandFileName(FileName);
{ Maybe It's Directory ?}   //Jaro Change:
  if PathExists(ConfigFile,false) then
    begin
       Message1(option_config_is_dir,FileName);
       exit;
    end;
{ open file }
  Message1(option_using_file,FileName);
  oldfilemode:=filemode;
  filemode:=0;
  assign(f,ConfigFile);
  {$push}{$I-}
   reset(f);
  {$pop}
  filemode:=oldfilemode;
  if IOResult<>0 then
   begin
     Message1(option_unable_open_file,FileName);
     exit;
   end;
  Message1(option_start_reading_configfile,FileName);
  fillchar(skip,sizeof(skip),0);
  level:=0;
  line:=0;
  while not eof(f) do
   begin
     readln(f,opts);
     inc(line);
     RemoveSep(opts);
     if (opts<>'') and (opts[1]<>';') then
      begin
        if opts[1]='#' then
         begin
           Message1(option_interpreting_file_option,opts);
           Delete(opts,1,1);
           s:=upper(GetName(opts));
           if (s='SECTION') then
            begin
              RemoveSep(opts);
              s:=upper(GetName(opts));
              if level=0 then
               skip[level]:=not Defined_Macro(s) or (s='COMMON');
            end
           else
            if (s='IFDEF') then
             begin
               RemoveSep(opts);
               if Level>=maxlevel then
                begin
                  Message2(option_too_many_ifdef,FileName,ToStr(line));
                  stopOptions(1);
                end;
               inc(Level);
               { environment variable? }
               if (opts[1]='$') and (opts[length(opts)]='$') then
                 skip[level]:=skip[level-1] or (GetEnvironmentVariable(copy(opts,2,length(opts)-2))='')
               else
                 skip[level]:=(skip[level-1] or not Defined_Macro(upper(GetName(opts))));
             end
           else
            if (s='IFNDEF') then
             begin
               RemoveSep(opts);
               if Level>=maxlevel then
                begin
                  Message2(option_too_many_ifdef,FileName,ToStr(line));
                  stopOptions(1);
                end;
               inc(Level);
               { environment variable? }
               if (opts[1]='$') and (opts[length(opts)]='$') then
                 skip[level]:=skip[level-1] or (GetEnvironmentVariable(copy(opts,2,length(opts)-2))<>'')
               else
                 skip[level]:=skip[level-1] or Defined_Macro(upper(GetName(opts)));
             end
           else
            if (s='ELSE') then
              begin
                if Level=0 then
                  begin
                    Message2(option_else_without_if,FileName,ToStr(line));
                    stopOptions(1);
                  end
                else
                  skip[level]:=skip[level-1] or (not skip[level])
              end
           else
            if (s='ENDIF') then
             begin
               skip[level]:=false;
               if Level=0 then
                begin
                  Message2(option_too_many_endif,FileName,ToStr(line));
                  stopOptions(1);
                end;
               dec(level);
             end
           else
            if (not skip[level]) then
             begin
               if (s='DEFINE') then
                begin
                  RemoveSep(opts);
                  tmp:= GetName(opts);
                  if tmp <> '' then
                    if upper(tmp)='FPC_UNICODESTRINGS' then
                      begin
                        Message1(option_illegal_para,'#DEFINE '+tmp+' (selected by -MANSISTRINGS/-MUNICODESTRINGS)');
                        StopOptions(1);
                      end
                    else
                      Def_System_Macro(tmp);
                  Option_read:=true;
                end
              else
               if (s='UNDEF') then
                begin
                  RemoveSep(opts);
                  tmp:= GetName(opts);
                  if tmp <> '' then
                    if upper(tmp)='FPC_UNICODESTRINGS' then
                      begin
                        Message1(option_illegal_para,'#UNDEF '+tmp+' (selected by -MANSISTRINGS/-MUNICODESTRINGS)');
                        StopOptions(1);
                      end
                    else
                      Undef_System_Macro(tmp);
                  Option_read:=true;
                end
              else
               if (s='WRITE') then
                begin
                  Delete(opts,1,1);
                  DefaultReplacements(opts);
                  WriteLn(opts);
                  Option_read:=true;
                end
              else
               if (s='INCLUDE') then
                begin
                  Delete(opts,1,1);
                  DefaultReplacements(opts);
                  Interpret_file(opts);
                  Option_read:=true;
                end
              else
               if (s='CFGDIR') then
                begin
                  Delete(opts,1,1);
                  DefaultReplacements(opts);
                  ParaIncludeCfgPath.AddPath(opts,false);
                  Option_read:=true;
                end;
            end;
         end
        else
         begin
           if (opts[1]='-') or (opts[1]='@') then
            begin
              if (not skip[level]) then
                interpret_option(opts,false);
              Option_read:=true;
            end
           else
             Message1(option_illegal_para,opts);
         end;
      end;
   end;
  if Level>0 then
   Message(option_too_less_endif);
  if Not Option_read then
    Message1(option_no_option_found,FileName)
  else
    Message1(option_end_reading_configfile,FileName);
  Close(f);
  Dec(FileLevel);
end;


procedure TOption.Interpret_envvar(const EnvName: TCmdStr);
var
  argstart,
  env,
  pc     : pchar;
  arglen : LongInt;
  quote  : set of char;
  hs     : TCmdStr;
begin
  Message1(option_using_env,EnvName);
  env:=GetEnvPChar(EnvName);
  pc:=env;
  hs:='';
  if Assigned(pc) then
   begin
     repeat
       { skip leading spaces }
       while pc^ in [' ',#9,#13] do
        inc(pc);
       case pc^ of
         #0 :
           break;
         '"' :
           begin
             quote:=['"'];
             inc(pc);
           end;
         '''' :
           begin
              quote:=[''''];
              inc(pc);
           end;
         else
           quote:=[' ',#9,#13];
       end;
     { scan until the end of the argument }
       argstart:=pc;
       while (pc^<>#0) and not(pc^ in quote) do
        inc(pc);
     { create argument }
       arglen:=pc-argstart;
{ TODO: FIXME: silent truncation of environment parameters }
       if (arglen > 255) then
         arglen := 255;
       SetLength(hs,arglen);
       move(argstart^,hs[1],arglen);
       interpret_option(hs,true);
     { skip quote }
       if pc^ in quote then
        inc(pc);
     until false;
   end
  else
   Message1(option_no_option_found,'(env) '+EnvName);
  FreeEnvPChar(env);
end;


procedure TOption.Read_Parameters;
var
  opts       : TCmdStr;
  paramindex : LongInt;
begin
  paramindex:=0;
  while paramindex<paramcount do
   begin
     inc(paramindex);
     opts:=objpas.ParamStr(paramindex);
     if length(opts)>0 then
       case opts[1] of
         '@' :
           if not FirstPass then
           begin
             Delete(opts,1,1);
             Message1(option_reading_further_from,opts);
             interpret_file(opts);
           end;
         '!' :
           if not FirstPass then
           begin
             Delete(opts,1,1);
             Message1(option_reading_further_from,'(env) '+opts);
             interpret_envvar(opts);
           end;
         else
           interpret_option(opts,true);
       end;
   end;
end;


procedure TOption.parsecmd(cmd: TCmdStr);
var
  i,ps  : LongInt;
  opts  : TCmdStr;
begin
  while (cmd<>'') do
   begin
     while cmd[1]=' ' do
      delete(cmd,1,1);
     i:=pos(' ',cmd);
     if i=0 then
       i:=2147483647;
     opts:=Copy(cmd,1,i-1);
     Delete(cmd,1,i);
     case opts[1] of
       '@' :
         if not FirstPass then
         begin
           Delete(opts,1,1);
           Message1(option_reading_further_from,opts);
           interpret_file(opts);
         end;
       '!' :
         if not FirstPass then
         begin
           Delete(opts,1,1);
           Message1(option_reading_further_from,'(env) '+opts);
           interpret_envvar(opts);
         end;
       '"' :
         begin
           Delete(opts,1,1);
           ps:=pos('"',cmd);
           if (i<>256) and (ps>0) then
             begin
               opts:=opts + ' '+ copy(cmd,1,ps-1);
               cmd:=copy(cmd,ps+1,255);
             end;
           interpret_option(opts,true);
         end;
       else
         interpret_option(opts,true);
     end;
   end;
end;


procedure TOption.WriteQuickInfo;
var
  s : string;
  i : LongInt;
  emptyOK : Boolean;

  procedure addinfo(const hs:string);
  begin
    if s<>'' then
     s:=s+' '+hs
    else
     s:=hs;
  end;

begin
  emptyOK:=False;
  s:='';
  i:=0;
  while (i<length(quickinfo)) do
   begin
     inc(i);
     case quickinfo[i] of
      'S' :
        begin
          inc(i);
          case quickinfo[i] of
           'O' :
             addinfo(lower(SourceInfo.shortname));
           'P' :
             addinfo(SourceCPUString);
           else
             IllegalPara('-i'+QuickInfo);
          end;
        end;
      'T' :
        begin
          inc(i);
          case quickinfo[i] of
           'O' :
             addinfo(lower(TargetInfo.shortname));
           'P' :
             AddInfo(TargetCPUString);
           'T' :
             begin
             addinfo(lower(self.parasubtarget));
             emptyOK:=True;
             end
           else
             IllegalPara('-i'+QuickInfo);
          end;
        end;
      'V' :
        AddInfo(Version_String);
      'W' :
        AddInfo(Full_Version_String);
      'D' :
        AddInfo(DateString);
      '_' :
        ;
      else
        IllegalPara('-i'+QuickInfo);
    end;
  end;
  if (s<>'') or EmptyOK then
   begin
     WriteLn(s);
     stopoptions(0);
   end;
end;


procedure TOption.TargetOptions(def:boolean);
var
  s : string;
  i : integer;
  target_unsup_features : TFeatures;
begin
  if def then
   Def_System_Macro(TargetInfo.shortname)
  else
   Undef_System_Macro(TargetInfo.shortname);

  s:=TargetInfo.extradefines;
  while (s<>'') do
   begin
     i:=pos(';',s);
     if i=0 then
      i:=length(s)+1;
     if def then
      Def_System_Macro(Copy(s,1,i-1))
     else
      Undef_System_Macro(Copy(s,1,i-1));
     delete(s,1,i);
   end;

  if (tf_winlikewidestring in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_WINLIKEWIDESTRING')
    else
      Undef_System_Macro('FPC_WINLIKEWIDESTRING');

  if (tf_requires_proper_alignment in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_REQUIRES_PROPER_ALIGNMENT')
    else
      Undef_System_Macro('FPC_REQUIRES_PROPER_ALIGNMENT');

  if (tf_init_final_units_by_calls in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_INIT_FINAL_UNITS_BY_CALLS')
    else
      Undef_System_Macro('FPC_INIT_FINAL_UNITS_BY_CALLS');

  if SourceInfo.system<>TargetInfo.system then
    if def then
      Def_System_Macro('FPC_CROSSCOMPILING')
    else
      Undef_System_Macro('FPC_CROSSCOMPILING');

  if SourceInfo.cpu<>TargetInfo.cpu then
    if def then
      Def_System_Macro('FPC_CPUCROSSCOMPILING')
    else
      Undef_System_Macro('FPC_CPUCROSSCOMPILING');

  if (tf_no_generic_stackcheck in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_NO_GENERIC_STACK_CHECK')
    else
      Undef_System_Macro('FPC_NO_GENERIC_STACK_CHECK');

  if (tf_section_threadvars in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_SECTION_THREADVARS')
    else
      Undef_System_Macro('FPC_SECTION_THREADVARS');

  if (tf_use_psabieh in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_USE_PSABIEH')
    else
      Undef_System_Macro('FPC_USE_PSABIEH');

  { Code generation flags }
  if (tf_pic_default in TargetInfo.flags) then
    if def then
      include(InitSettings.ModuleSwitches,cs_create_pic)
    else
      exclude(InitSettings.ModuleSwitches,cs_create_pic);

  { Resources support }
  if (tf_has_winlike_resources in TargetInfo.flags) then
    if def then
      Def_System_Macro('FPC_HAS_WINLIKERESOURCES')
    else
      Undef_System_Macro('FPC_HAS_WINLIKERESOURCES');

  target_unsup_features:=[];

  if def then
    Features:=Features-target_unsup_features
  else
    Features:=Features+target_unsup_features;

end;

procedure TOption.CheckOptionsCompatibility;
var
  requestedwin64clang,
  win64clanglld : boolean;
begin
  if (TargetInfo.system in systems_windows) and
     (paratargetdbg=dbg_dwarf5) then
    UnsupportedPara('-gw5');

  requestedwin64clang:=false;
  if (paratargetasm=as_clang_gas) and
     Assigned(asminfos[as_clang_gas]) then
    requestedwin64clang:=
      ((TargetInfo.system in asminfos[as_clang_gas]^.supported_targets) or
       (system_any in asminfos[as_clang_gas]^.supported_targets)) and
      (af_llvm in asminfos[as_clang_gas]^.flags);
  win64clanglld:=
    (TargetInfo.system in [system_x86_64_win64,system_aarch64_win64]) and
    (((TargetAsm.id=as_clang_gas) and
      (af_llvm in TargetAsm.flags)) or
     requestedwin64clang) and
    (TargetInfo.linkextern=ld_lld_windows);





  if (paratargetdbg in [dbg_dwarf3,dbg_dwarf4,dbg_dwarf5]) and
     not(TargetInfo.system in systems_darwin) and
     not win64clanglld then
    begin
      { smartlink creation does not yet work with DWARF
        debug info on most targets, but it works in internal assembler }
      if (cs_create_smart in InitSettings.ModuleSwitches) and
         not (af_outputbinary in TargetAsm.flags) then
        begin
          Message(option_dwarf_smartlink_creation);
          exclude(InitSettings.ModuleSwitches,cs_create_smart);
        end;

      { smart linking does not yet work with DWARF debug info on most targets }
      if (cs_link_smart in InitSettings.GlobalSwitches) then
        begin
          Message(option_dwarf_smart_linking);
          ForceStaticLinking;
        end;
    end;

  { external debug info is only supported for DWARF on darwin }
  if (TargetInfo.system in systems_darwin) and
     (cs_link_separate_dbg_file in InitSettings.GlobalSwitches) and
     not(paratargetdbg in [dbg_dwarf3,dbg_dwarf4,dbg_dwarf5]) then
    begin
      Message(option_debug_external_unsupported);
      exclude(InitSettings.GlobalSwitches,cs_link_separate_dbg_file);
    end;
end;


constructor TOption.Create;
begin
  LogoWritten:=false;
  NoPressEnter:=false;
  FirstPass:=false;
  ABISetExplicitly:=false;
  FPUSetExplicitly:=false;
  CPUSetExplicitly:=false;
  OptCPUSetExplicitly:=false;
  FileLevel:=0;
  Quickinfo:='';
  ParaIncludeCfgPath:=TSearchPathList.Create;
  ParaIncludePath:=TSearchPathList.Create;
  ParaObjectPath:=TSearchPathList.Create;
  ParaUnitPath:=TSearchPathList.Create;
  ParaLibraryPath:=TSearchPathList.Create;
  ParaFrameworkPath:=TSearchPathList.Create;
  parapackagepath:=TSearchPathList.Create;
  parapackages:=TFPHashObjectList.Create;
  paranamespaces:=TCmdStrList.Create;
  FillChar(ParaAlignment,sizeof(ParaAlignment),0);
  MacVersionSet:=false;
  paratarget:=system_none;
  paratargetasm:=as_none;
  paratargetdbg:=dbg_none;
  LinkTypeSetExplicitly:=false;
  LinkerSetExplicitly:=false;
  MemoryModelSetExplicitly:=false;
end;


destructor TOption.Destroy;
begin
  ParaIncludeCfgPath.Free;
  ParaIncludeCfgPath := nil;
  ParaIncludePath.Free;
  ParaIncludePath := nil;
  ParaObjectPath.Free;
  ParaObjectPath := nil;
  ParaUnitPath.Free;
  ParaUnitPath := nil;
  ParaLibraryPath.Free;
  ParaLibraryPath := nil;
  ParaFrameworkPath.Free;
  ParaFrameworkPath := nil;
  parapackagepath.Free;
  parapackagepath := nil;
  ParaPackages.Free;
  ParaPackages := nil;
  paranamespaces.free;
  paranamespaces := nil;
end;

procedure TOption.Interpret_A_l(opt, more: TCmdStr);

var
  j : integer;

begin
  include(InitSettings.GlobalSwitches,cs_asm_leave);
  j:=1;
  while j<=length(more) do
   begin
     case more[j] of
       'l' :
         include(InitSettings.GlobalSwitches,cs_asm_source);
       'r' :
         include(InitSettings.GlobalSwitches,cs_asm_regalloc);
       'R' :
         include(InitSettings.GlobalSwitches,cs_asm_rtti_source);
       't' :
         include(InitSettings.GlobalSwitches,cs_asm_tempalloc);
       'n' :
         include(InitSettings.GlobalSwitches,cs_asm_nodes);
       { -ao option must be the last, everything behind it is passed directly to
         external assembler, it is ignored if internal assembler is used. }
       'o' :
         begin
           AsmExtraOpt:=copy(more,j+1);
           break;
         end;
       'p' :
         begin
           exclude(InitSettings.GlobalSwitches,cs_asm_leave);
           if UnsetBool(More, 0, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_asm_pipe)
           else
             include(InitSettings.GlobalSwitches,cs_asm_pipe);
         end;
       '-' :
         InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches -
             [cs_asm_leave, cs_asm_source,cs_asm_regalloc, cs_asm_tempalloc,
              cs_asm_nodes, cs_asm_pipe];
       else
         IllegalPara(opt);
     end;
     inc(j);
   end;
end;


procedure TOption.Interpret_A_U(opt, more: TCmdStr);

begin
  if CompareText(More,'DEFAULT') = 0 then
    paratargetasm:=as_default
  else
    paratargetasm:=FindAsmByString(More);
  if paratargetasm=as_none then
    IllegalPara(opt);
end;


procedure TOption.Interpret_B_l(opt, more: TCmdStr);

begin
  if UnsetBool(More,0,opt,false) then
    InitSettings.ModuleSwitches:=InitSettings.ModuleSwitches-[cs_browser]
  else
    InitSettings.ModuleSwitches:=InitSettings.ModuleSwitches+[cs_browser];
  if More<>'' then
    IllegalPara(opt);
end;


procedure TOption.Interpret_B_U(opt, more: TCmdStr);

begin
  Do_Build:=not UnSetBool(more,0,opt,true);
end;


procedure TOption.Interpret_C_U(opt, more: TCmdStr);

var
  j,l,code,deletepos : integer;
  s : string;
  includecapability : Boolean;

  {$ifdef cpucapabilities}
  cf   : TCPUFlags;
  cpuflagsstr,
  extrasettings : string;
  {$endif cpucapabilities}

begin
  j:=1;
  while j<=length(more) do
   begin
     case more[j] of
       '3' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_ieee_errors)
         Else
           include(InitSettings.LocalSwitches,cs_ieee_errors);
       'a' :
         begin
           s:=upper(copy(more,j+1));
           if not(SetABIType(s,TargetInfo.abi)) then
             IllegalPara(opt);
           ABISetExplicitly:=true;
           break;
         end;

       'b' :
          begin
            if UnsetBool(More, j, opt, false) then
              TargetInfo.endian:=endian_little
            else
              TargetInfo.endian:=endian_big;
            set_endianess_macros;
          end;

       'c' :
          begin
            if not SetAktProcCall(upper(copy(more,j+1)),InitSettings.DefProcCall) then
             IllegalPara(opt);
            break;
          end;
       'E' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_check_fpu_exceptions)
         Else
           include(InitSettings.LocalSwitches,cs_check_fpu_exceptions);
       'f' :
         begin
           s:=upper(copy(more,j+1));
           if not(SetFPUType(s,InitSettings.FPUType)) then
             IllegalPara(opt);
           FPUSetExplicitly:=True;
           break;
         end;
       'F' :
          begin
            if not SetMinFPConstPrec(copy(more,j+1),InitSettings.MinFPConstPrec) then
              IllegalPara(opt);
            break;
          end;
       'g' :
          begin
            if tf_no_pic_supported in TargetInfo.flags then
              begin
                { consume a possible '-' coming after it }
                UnsetBool(More, j, opt, false);
                message(scan_w_pic_ignored);
              end
            else if UnsetBool(More, j, opt, false) then
              exclude(InitSettings.ModuleSwitches,cs_create_pic)
            else
              include(InitSettings.ModuleSwitches,cs_create_pic);
         end;
       'h' :
         begin
            l:=pos(',',copy(more,j+1));
            if l=0 then
              l:=length(more)-j+1;
            val(copy(more,j+1,l-1),HeapSize,code);
            if (code<>0)
            or (HeapSize<1024)
            then
              IllegalPara(opt)
            else if l<=length(more)-j then
              begin
                val(copy(more,j+l+1),MaxHeapSize,code);
                if code<>0 then
                  IllegalPara(opt)
                else if (MaxHeapSize<HeapSize) then
                  begin
                    message(scan_w_heapmax_lessthan_heapmin);
                    MaxHeapSize:=HeapSize;
                  end;
              end;
            break;
         end;
       'i' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_check_io)
         else
           include(InitSettings.LocalSwitches,cs_check_io);

       'n' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.GlobalSwitches,cs_link_nolink)
         Else
           include(InitSettings.GlobalSwitches,cs_link_nolink);
       'o' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_check_overflow)
         Else
           include(InitSettings.LocalSwitches,cs_check_overflow);
       'O' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_check_ordinal_size)
         Else
           include(InitSettings.LocalSwitches,cs_check_ordinal_size);
       'p' :
         begin
           s:=upper(copy(more,j+1));
{$ifdef cpucapabilities}
           { find first occurrence of + or - }

  {$ifdef x86_64}
           { Workaround - don't remove the "-" signs from ICELAKE-CLIENT,
             ICELAKE-SERVER, SKYLAKE-X, X86-64 and X86-64-V1 etc. }
           if (Copy(s,1,8)='ICELAKE-') and
             (
               (Copy(s,9,6)='CLIENT') or
               (Copy(s,9,6)='SERVER')
             ) then
             begin
               extrasettings:=Copy(s,15,Length(s));
               deletepos:=PosCharset(['+','-'],extrasettings);
             end
           else if (Copy(s,1,9)='SKYLAKE-X') or
             ((Copy(s,1,8)='X86-64-V') and (s[9] in ['1','2','3','4'])) then
             begin
               extrasettings:=Copy(s,10,Length(s));
               deletepos:=PosCharset(['+','-'],extrasettings);
             end
           else if (Copy(s,1,6)='X86-64') then
             begin
               extrasettings:=Copy(s,7,Length(s));
               deletepos:=PosCharset(['+','-'],extrasettings);
             end
           else
  {$endif x86_64}
             deletepos:=PosCharset(['+','-'],s);

           if deletepos<>0 then
             begin
               extrasettings:=Copy(s,deletepos,Length(s));
               Delete(s,deletepos,Length(s));
              end
           else
             extrasettings:='';
{$endif cpucapabilities}
           if not(SetCPUType(s,InitSettings)) then
             IllegalPara(opt);
{$ifdef cpucapabilities}
           while extrasettings<>'' do
             begin
               Delete(extrasettings,1,1);
               includecapability:=true;
               deletepos:=PosCharset(['+','-'],extrasettings);
               if deletepos<>0 then
                 begin
                   includecapability:=extrasettings[deletepos]='+';
                   s:=Copy(extrasettings,1,deletepos-1);
                   Delete(extrasettings,1,deletepos-1);
                 end
               else
                 begin
                   s:=extrasettings;
                   extrasettings:='';
                 end;
               for cf in TCPUFlags do
                 begin
                   Str(cf,cpuflagsstr);
                   { expect that the cpuflagsstr i.e. the enum as well contains _HAS_ }
                   if Pos('_HAS_',cpuflagsstr)<>0 then
                   { get rid of prefix including _HAS_ }
                     Delete(cpuflagsstr,1,Pos('_HAS_',cpuflagsstr)+4)
                   else
                     InternalError(2021110601);
                   if s=cpuflagsstr then
                     begin
                       if includecapability then
                         Include(cpu_capabilities[InitSettings.CPUType],cf)
                       else
                         Exclude(cpu_capabilities[InitSettings.CPUType],cf);
                       s:='';
                       break;
                     end;
                 end;
               if s<>'' then
                 IllegalPara(opt);
             end;
{$endif cpucapabilities}
           CPUSetExplicitly:=true;
           break;
         end;
       'P':
         begin
           delete(more,1,1);
           case upper(copy(more,1,pos('=',more)-1)) of
             'PACKSET':
               begin
                 delete(more,1,pos('=',more));
                 case more of
                   '0','DEFAULT','NORMAL':
                     InitSettings.SetAlloc:=0;
                   '1','2','4','8':
                     InitSettings.SetAlloc:=StrToInt(more);
                   else
                     IllegalPara(opt);
                 end
               end;
             'PACKENUM':
               begin
                 delete(more,1,pos('=',more));
                 case more of
                   '0','DEFAULT','NORMAL':
                     InitSettings.PackEnum:=4;
                   '1','2','4':
                     InitSettings.PackEnum:=StrToInt(more);
                   else
                     IllegalPara(opt);
                 end;
               end;
             'PACKRECORD':
               begin
                 delete(more,1,pos('=',more));
                 case more of
                   '0','DEFAULT','NORMAL':
                     InitSettings.PackRecords:=Default_Settings.PackRecords;
                   '1','2','4','8','16','32':
                     InitSettings.PackRecords:=StrToInt(more);
                   else
                     IllegalPara(opt);
                 end;
               end
             else
               IllegalPara(opt);
           end;
         end;
       'r' :
         If UnsetBool(More, j, opt, false) then
           exclude(InitSettings.LocalSwitches,cs_check_range)
         Else
           include(InitSettings.LocalSwitches,cs_check_range);
       'R' :
         If UnsetBool(More, j, opt, false) then
           begin
             exclude(InitSettings.LocalSwitches,cs_check_range);
             exclude(InitSettings.LocalSwitches,cs_check_object);
           end
         Else
           begin
             include(InitSettings.LocalSwitches,cs_check_range);
             include(InitSettings.LocalSwitches,cs_check_object);
           end;
       's' :
         begin
            val(copy(more,j+1),StackSize,code);
            if (code<>0)

               or (StackSize>=67107840)

               or (StackSize<1024) then
             IllegalPara(opt);
            break;
         end;
       't' :
          If UnsetBool(More, j, opt, false) then
            exclude(InitSettings.LocalSwitches,cs_check_stack)
          Else
            include(InitSettings.LocalSwitches,cs_check_stack);
       'X' :
          If UnsetBool(More, j, opt, false) then
            exclude(InitSettings.ModuleSwitches,cs_create_smart)
          Else
            include(InitSettings.ModuleSwitches,cs_create_smart);
       'T' :
         begin
           if not UpdateTargetSwitchStr(copy(more,j+1),InitSettings.TargetSwitches,true) then
             IllegalPara(opt);
           break;
         end;
       'v' :
          IllegalPara(opt);
       'V':
         begin
           s:=upper(copy(more,j+1));
           if s='GLOBAL-DYNAMIC' then
             InitSettings.TLSModel:=tlsm_global_dynamic
           else if s='LOCAL-EXEC' then
             InitSettings.TLSModel:=tlsm_local_exec
           else
             IllegalPara(opt);
           break;
         end;
       else
         IllegalPara(opt);
     end;
     inc(j);
   end;
end;


procedure TOption.Interpret_D_l(opt, more: TCmdStr);

Var
  l : Integer;
  hs : string;

begin
    l:=Pos(':=',more);
    DefaultReplacements(more);
    if l>0 then
      hs:=copy(more,1,l-1)
    else
      hs:=more;
    if (not is_identifier(hs)) then
      begin
        if hs='' then
          Message1(option_missing_arg,'-d')
        else
          Message1(option_malformed_para,opt);
        StopOptions(1);
      end;
    if upper(hs)='FPC_UNICODESTRINGS' then
      begin
        Message1(option_illegal_para,'-d'+hs+' (selected by -MANSISTRINGS/-MUNICODESTRINGS)');
        StopOptions(1);
        exit;
      end;
    if l>0 then
      begin
        if cs_support_macro in InitSettings.ModuleSwitches then
          Set_System_Macro(hs,Copy(more,l+2))
        else
          Set_System_CompVar(hs,Copy(more,l+2));
      end
    else
      Def_System_Macro(hs);
end;


procedure TOption.Interpret_D_U(opt, more: TCmdStr);
var
  major,minor : LongInt;
  l,j,error : integer;

begin
  j:=1;
  if length(more)=0 then
    include(InitSettings.GlobalSwitches,cs_link_deffile);
  while j<=length(more) do
    begin
      case more[j] of
       'd' :
         begin
           include(InitSettings.GlobalSwitches,cs_link_deffile);
           Description:=Copy(more,j+1);
           break;
         end;
       'D' :
         begin
           DateStr:=Copy(more,j+1);
           break;
         end;
       'T' :
         begin
           TimeStr:=Copy(more,j+1);
           break;
         end;
       'v' :
         begin
           include(InitSettings.GlobalSwitches,cs_link_deffile);
           DLLVersion:=Copy(more,j+1);
           l:=pos('.',DLLVersion);
           DLLMinor:=0;
           error:=0;
           if l>0 then
            begin
              val(copy(DLLVersion,l+1,255),minor,error);
              if (error=0) and
                 (minor>=0) and (minor<=$ffff) then
                DLLMinor:=minor
              else
                if error=0 then
                  error:=1;
            end;
           if l=0 then
             l:=256;
           DLLMajor:=1;
           major:=0;
           if error=0 then
             val(copy(DLLVersion,1,l-1),major,error);
           if (error=0) and (major>=0) and (major<=$ffff) then
             DLLMajor:=major
           else
             if error=0 then
               error:=1;
           if error<>0 then
             Message1(scan_w_wrong_version_ignored,DLLVersion);
           break;
         end;
       'w' :
         begin
           include(InitSettings.GlobalSwitches,cs_link_deffile);
           UseWindowAPI:=true;
          end;
       '-' :
         begin
           exclude(InitSettings.GlobalSwitches,cs_link_deffile);
           UseWindowAPI:=false;
         end;
       else
         IllegalPara(opt);
      end;
    inc(j);
    end;
end;


procedure TOption.Interpret_E_l(opt, more: TCmdStr);

begin
  ExePath:=FixPath(More,true);
end;


procedure TOption.Interpret_E_U(opt, more: TCmdStr);

begin
  if UnsetBool(More, 0, opt, true) then
    exclude(InitSettings.GlobalSwitches,cs_link_nolink)
  else
    include(InitSettings.GlobalSwitches,cs_link_nolink);
end;


procedure TOption.Interpret_F_l(opt, more: TCmdStr);

begin
  if more='PIC' then
    begin
      if tf_no_pic_supported in TargetInfo.flags then
        message(scan_w_pic_ignored)
      else
        include(InitSettings.ModuleSwitches,cs_create_pic)
    end
  else
    IllegalPara(opt);
end;


procedure TOption.Interpret_F_U(opt, more: TCmdStr; ispara: boolean);

var
  c : char;
  d : string;
  j : integer;
  unicodemapping : PUnicodeMap;

begin
  if more='' then
    IllegalPara(opt);
  c:=more[1];
  Delete(more,1,1);
  DefaultReplacements(More);
  case c of
    'a' :
      AutoloadUnits:=more;
    'c' :
      begin
        { if we first specify that the system code page should be
          used and then explicitly specify a code page, unset the
          flag that we're using the system code page again }
        SetCompileModeSwitch('SYSTEMCODEPAGE-',true);
        if (upper(more)='UTF8') or (upper(more)='UTF-8') then
          InitSettings.SourceCodePage:=CP_UTF8
        else if not(CPAvailable(more)) then
          Message1(option_code_page_not_available,more)
        else
          InitSettings.SourceCodePage:=CodePageByName(more);
        include(InitSettings.ModuleSwitches,cs_explicit_codepage);
      end;
    'C' :
      RCCompiler:=More;
    'd' :
      if UnsetBool(more, 0, opt, true) then
        InitSettings.DisableDirCache:=false
      else
        InitSettings.DisableDirCache:=true;
    'D' :
      UtilsDirectory:=FixPath(More,true);
    'e' :
      SetRedirectFile(More);
    'E' :
      OutputExeDir:=FixPath(More,true);
    'f' :
        if (TargetInfo.system in systems_darwin) then
          if ispara then
            ParaFrameworkPath.AddPath(More,false)
          else
            FrameworkSearchPath.AddPath(More,true)
        else
          IllegalPara(opt);
    'F' :
      RCForceFPCRes:=true;
    'i' :
      begin
        if ispara then
          ParaIncludePath.AddPath(More,false)
        else
          IncludeSearchPath.AddPath(More,true);
      end;
    'J' :
      begin
        if (more='') or (more='+') or (upper(more)='ENABLED') then Embed_Package_Metadata:=true
        else if (more='-') or (upper(more)='DISABLED') then Embed_Package_Metadata:=false
        else IllegalPara(opt);
      end;
    'j','k' :
      begin
        { Explicit experimental package identities, supplied by the SDK tools. }
        if (length(more)<1) or (length(more)>64) then IllegalPara(opt);
        for j:=1 to length(more) do
          if not (more[j] in ['0'..'9','a'..'f','A'..'F']) then IllegalPara(opt);
        if c='j' then Package_SDK_Identity:=upper(more)
        else Package_Build_Identity:=upper(more);
      end;
    'm' :
      begin
        if TryStrToInt(ExtractFileName(more),j) then
          begin
            unicodemapping:=LoadUnicodeMapping(More,More+'.txt',j);
            if Assigned(unicodemapping) then
              RegisterMapping(unicodemapping)
            else
              IllegalPara(opt);
          end
        else
          IllegalPara(opt);
      end;
    'M' :
      UnicodePath:=FixPath(More,true);
    'l' :
      begin
        if ispara then
          ParaLibraryPath.AddLibraryPath(SysRootPath,More,false)
        else
          LibrarySearchPath.AddLibraryPath(SysRootPath,More,true)
      end;
    'L' :
      begin
        if More<>'' then
          ParaDynamicLinker:=More
        else
          IllegalPara(opt);
      end;
    'N' :
      begin
        if more<>'' then
          paranamespaces.insert(more)
        else
          illegalpara(opt);
      end;
    'o' :
      begin
        if ispara then
          ParaObjectPath.AddPath(More,false)
        else
          ObjectSearchPath.AddPath(More,true);
      end;
    'P' :
      begin
        if ispara then
          parapackages.add(more,nil)
        else
          Add_Package(more,true,true);
      end;
    'p' :
      begin
        if ispara then
          parapackagepath.AddPath(More,false)
        else
          PackageSearchPath.AddPath(More,true);
      end;
    'r' :
      MsgFileName:=More;
    'R' :
      ResCompiler:=More;
    't' :
      begin
        AllowedFilenameTransFormations:=[ftNone,ftLowerCase];
        Message(general_i_reduced_filesearch);
      end;
    'u' :
      begin
        if ispara then
          ParaUnitPath.AddPath(More,false)
        else
          UnitSearchPath.AddPath(More,true);
      end;
    'U' :
      OutputUnitDir:=FixPath(More,true);
    'W',
    'w':
      begin
        if More<>'' then
          begin
            DefaultReplacements(More);
            D:=ExtractFilePath(More);
            if (D<>'') then
              D:=FixPath(D,True);
            D:=D+ExtractFileName(More);
            if (c='W') then
              WPOFeedbackOutput:=D
            else
              WPOFeedbackInput:=D;
          end
        else
          IllegalPara(opt);
      end;
    else
      IllegalPara(opt);
  end;
end;


procedure TOption.Interpret_G_l(opt, more: TCmdStr);

var
  j : integer;

begin
  if UnsetBool(More, 0, opt, false) then
   begin
     exclude(InitSettings.ModuleSwitches,cs_debuginfo);
     exclude(InitSettings.GlobalSwitches,cs_use_heaptrc);
     exclude(InitSettings.GlobalSwitches,cs_use_lineinfo);
     exclude(InitSettings.LocalSwitches,cs_checkpointer);
     paratargetdbg:=dbg_none;
     LocalVarTrashing := -1;
   end
  else
   begin
     include(InitSettings.ModuleSwitches,cs_debuginfo);
     if paratargetdbg=dbg_none then
       paratargetdbg:=TargetInfo.dbg;
   end;
  if not RelocSectionSetExplicitly then
    RelocSection:=false;
  j:=1;
  while j<=length(more) do
    begin
      case more[j] of
        'c' :
          begin
            if UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_checkpointer)
            else if (TargetInfo.system in systems_support_checkpointer) then
              begin
                if Do_Release then
                  Message(option_gc_incompatible_with_release_flag)
                else
                  include(InitSettings.LocalSwitches,cs_checkpointer);
              end
            else
              UnsupportedPara('-gc');
          end;
        'h' :
          begin
            if UnsetBool(More, j, opt, false) then
              exclude(InitSettings.GlobalSwitches,cs_use_heaptrc)
            else
              begin
                if cs_gdb_valgrind in InitSettings.GlobalSwitches then
                  Message2(option_valgrind_heaptrc_mismatch,'-gh', '-gv');
                include(InitSettings.GlobalSwitches,cs_use_heaptrc);
              end;
          end;
        'l' :
          begin
            if UnsetBool(More, j, opt, false) then
              exclude(InitSettings.GlobalSwitches,cs_use_lineinfo)
            else
              begin
                include(InitSettings.GlobalSwitches,cs_use_lineinfo);
              end;
          end;
        'o' :
          begin
            if not UpdateDebugStr(copy(more,j+1),InitSettings.DebugSwitches) then
              IllegalPara(opt);
            break;
          end;
        't' :
          begin
            if UnsetBool(More, j, opt, false) then
               LocalVarTrashing := -1
            else
              LocalVarTrashing := (LocalVarTrashing + 1) mod NrOfTrashValues;
          end;
        'v' :
          begin
            if UnsetBool(More, j, opt, false) then
              exclude(InitSettings.GlobalSwitches,cs_gdb_valgrind)
            else
              begin
                if cs_use_heaptrc in InitSettings.GlobalSwitches then
                  Message2(option_valgrind_heaptrc_mismatch,'-gh', '-gv');
                include(InitSettings.GlobalSwitches,cs_gdb_valgrind);
              end;
          end;
        'w' :
          begin
            if (j<length(more)) and (more[j+1] in ['3','4','5']) then
              begin
                case more[j+1] of
                  '3': paratargetdbg:=dbg_dwarf3;
                  '4': paratargetdbg:=dbg_dwarf4;
                  '5': paratargetdbg:=dbg_dwarf5;
                end;
                inc(j);
              end
            else if (j=length(more)) or
                    ((j<length(more)) and (more[j+1]='2')) then
              UnsupportedPara(opt)
            else
              IllegalPara(opt);
          end;
        else
          IllegalPara(opt);
      end;
      inc(j);
    end;
end;


procedure TOption.Interpret_Help(more: TCmdStr);

begin
  if (More <> '') and (More [1] = 'F') then
    begin
      FPCHelpLines := true;
      Delete (More, 1, 1);
      FPCBinaryPath := More;
    end;
  WriteHelpPages;
end;


procedure TOption.Interpret_H_l(more: TCmdStr);

begin
  NoPressEnter:=true;
  if (More <> '') and (More [1] = 'F') then
    begin
      FPCHelpLines := true;
      Delete (More, 1, 1);
      FPCBinaryPath := More;
    end;
  WriteHelpPages;
end;


procedure TOption.Interpret_I_l(more: TCmdStr);

begin
  if (More='') or
     (More [1] in ['a', 'b', 'c', 'f', 'i',  'm', 'o', 'r', 't', 'u', 'w', 'x']) then
    WriteInfo (More)
  else
    QuickInfo:=QuickInfo+More;
end;


procedure TOption.Interpret_I_U(more: TCmdStr; ispara: boolean);

begin
  if ispara then
    ParaIncludePath.AddPath(More,false)
  else
   IncludeSearchPath.AddPath(More,false);
end;


procedure TOption.Interpret_K_l(opt, more: TCmdStr);

begin
  if more<>'' then
    ParaLinkOptions:=ParaLinkOptions+' '+More
  else
    IllegalPara(opt);
end;


procedure TOption.Interpret_L_l(opt, more: TCmdStr);

begin
  ParaLogo:=not UnSetBool(more,0,opt,true);
end;


procedure TOption.Interpret_M_l(opt, more: TCmdStr);

begin
{$ifdef PREPROCWRITE}
  ParaPreprocess:=not UnSetBool(more,0,opt,true);
{$endif PREPROCWRITE}
end;


procedure TOption.Interpret_M_U(opt, more: TCmdStr);

begin
  more:=Upper(more);
  if not SetCompileMode(more, true) then
    if not SetCompileModeSwitch(more, true) then
      IllegalPara(opt);
end;


procedure TOption.Interpret_N_l(opt, more: TCmdStr);

begin
  if More='' then
    disable_configfile:=true
  else
    IllegalPara(opt);
end;


procedure TOption.Interpret_O_l(opt, more: TCmdStr);

var
  D : String;

begin
  if More<>'' then
    begin
      DefaultReplacements(More);
      D:=ExtractFilePath(More);
      if (D<>'') then
        OutputExeDir:=FixPath(D,True);
      OutputFileName:=ExtractFileName(More);
    end
  else
    IllegalPara(opt);
end;


procedure TOption.Interpret_O_U(opt, more: TCmdStr);

var
  j : integer;

begin
  j:=1;
  while j<=length(more) do
   begin
     case more[j] of
       '1' :
         InitSettings.OptimizerSwitches:=InitSettings.OptimizerSwitches+level1optimizerswitches;
       '2' :
         InitSettings.OptimizerSwitches:=InitSettings.OptimizerSwitches+level2optimizerswitches;
       '3' :
         InitSettings.OptimizerSwitches:=InitSettings.OptimizerSwitches+level3optimizerswitches;
       '4' :
         InitSettings.OptimizerSwitches:=InitSettings.OptimizerSwitches+level4optimizerswitches;
       'a' :
         begin
           if not(UpdateAlignmentStr(Copy(Opt,j+3,255),ParaAlignment)) then
             IllegalPara(opt);
           break;
         end;
       's' :
         include(InitSettings.OptimizerSwitches,cs_opt_size);
       'p' :
         begin
           if not SetOptimizeCPUType(copy(more,j+1),InitSettings.OptimizeCPUType) then
             begin
               OptCPUSetExplicitly:=true;
                { Give warning for old i386 switches }
               if (Length(More)-j=1) and
                  (More[j+1]>='1') and (More[j+1]<='5')then
                 Message2(option_obsolete_switch_use_new,'-Op<nr>','-Op<name>')
               else
                 IllegalPara(opt);
             end;
           break;
         end;
       'o' :
         begin
           if not UpdateOptimizerStr(copy(more,j+1),InitSettings.OptimizerSwitches) then
            IllegalPara(opt);
           break;
         end;
       '-' :
         begin
           InitSettings.OptimizerSwitches:=[];
           FillChar(ParaAlignment,sizeof(ParaAlignment),0);
         end;
       'w' :
         begin
           if not UpdateWPOStr(copy(more,j+1),InitSettings.DoWPOptimizerSwitches) then
             IllegalPara(opt);
           break;
         end;
       'W' :
         begin
           if not UpdateWPOStr(copy(more,j+1),InitSettings.GenWPOptimizerSwitches) then
             IllegalPara(opt);
           break;
         end;
       else
         IllegalPara(opt);
     end;
     inc(j);
   end;
end;


procedure TOption.Interpret_P_U(opt, more: TCmdStr);

begin
  { used to select the target processor with the "fpc" binary;
    give an error if it's not the target architecture supported by
    this compiler binary (will be verified after the target_info
    is set) }
  processorstr:=More;
end;


procedure TOption.Interpret_R_U(opt, more: TCmdStr);

begin
  if not SetAsmReadMode(More,InitSettings.AsmMode) then
    IllegalPara(opt);
end;


procedure TOption.Interpret_S_l(opt, more: TCmdStr);

begin
  if UnsetBool(More, 0, opt, false) then
    begin
      InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches-[cs_asm_extern,cs_link_extern,cs_link_nolink];
      if more<>'' then
        IllegalPara(opt);
    end
  else
    begin
      InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches+[cs_asm_extern,cs_link_extern,cs_link_nolink];
      if more='h' then
        InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches-[cs_link_on_target,cs_assemble_on_target]
      else if more='t' then
        InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches+[cs_link_on_target,cs_assemble_on_target]
      else if more='T' then
        InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches+[cs_link_on_target]-[cs_asm_extern]
      else if more='r' then
        InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches+[cs_asm_leave,cs_no_regalloc]
      else if more<>'' then
        IllegalPara(opt);
    end;
end;


procedure TOption.Interpret_S_U(opt, more: TCmdStr);

var
  j : integer;

begin
  if more='' then
    IllegalPara(opt);
  if more[1]='I' then
    begin
      if upper(more)='ICOM' then
        InitSettings.InterfaceType:=it_interfacecom
      else if upper(more)='ICORBA' then
        InitSettings.InterfaceType:=it_interfacecorba
      else
        IllegalPara(opt);
    end
  else
    begin
      j:=1;
      while j<=length(more) do
        begin
          case more[j] of
          '2' : //an alternative to -Mobjfpc
            SetCompileMode('OBJFPC',true);
          'a' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_do_assertion)
            else
              include(InitSettings.LocalSwitches,cs_do_assertion);
          'c' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.ModuleSwitches,cs_support_c_operators)
            else
              include(InitSettings.ModuleSwitches,cs_support_c_operators);
          'C':
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_check_all_case_coverage)
            else
              include(InitSettings.LocalSwitches,cs_check_all_case_coverage);
          'd' : //an alternative to -Mdelphi
            SetCompileMode('DELPHI',true);
          'e' :
            begin
              SetErrorFlags(copy(more,j+1));
              break;
            end;
          'f' :
            begin
              if not(cs_compilesystem in InitSettings.ModuleSwitches) then
                Message(option_features_only_for_system_unit);
              inc(j);
              if more[j]='-' then
                begin
                  if length(more)>j then
                    IllegalPara(opt)
                  else
                    Features:=[];
                end
              else
                begin
                  if (HandleFeature(upper(copy(more,j)))) then
                    j:=length(more)
                  else
                    IllegalPara(opt);
                end;
            end;
          'g' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.ModuleSwitches,cs_support_goto)
            else
              include(InitSettings.ModuleSwitches,cs_support_goto);
          'h' :
            begin
              { Accepted for seed-era command lines, but the compiler-wide
                default String type is not controlled by -Sh. }
              if (j<length(more)) and (more[j+1] in ['+','-']) then
                inc(j);
            end;
          'i' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_do_inline)
            else
              include(InitSettings.LocalSwitches,cs_do_inline);
          'j' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_typed_const_writable)
            else
              include(InitSettings.LocalSwitches,cs_typed_const_writable);
          'm' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.ModuleSwitches,cs_support_macro)
            else
              include(InitSettings.ModuleSwitches,cs_support_macro);
          'r' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.GlobalSwitches,cs_transparent_file_names)
            else
              include(InitSettings.GlobalSwitches,cs_transparent_file_names);
          {$ifdef gpc_mode}
          'p' : //an alternative to -Mgpc
            SetCompileMode('GPC',true);
          {$endif}
          'v' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.GlobalSwitches,cs_support_vectors)
            else
              include(InitSettings.GlobalSwitches,cs_support_vectors);
          'x' :
            If UnsetBool(More, j, opt, false) then
              SetCompileModeSwitch('EXCEPTIONS-',true)
            else
              SetCompileModeSwitch('EXCEPTIONS',true);
          'y' :
            If UnsetBool(More, j, opt, false) then
              exclude(InitSettings.LocalSwitches,cs_typed_addresses)
            else
              include(InitSettings.LocalSwitches,cs_typed_addresses);
          '-' :
            begin
              InitSettings.GlobalSwitches:=InitSettings.GlobalSwitches - [cs_support_exceptions,
                                                                            cs_support_vectors];

              InitSettings.LocalSwitches:=InitSettings.LocalSwitches - [cs_do_assertion,cs_do_inline,
                                                                          cs_typed_addresses];

              InitSettings.ModuleSwitches:=InitSettings.ModuleSwitches - [cs_support_c_operators, cs_support_goto,
                                                                            cs_support_macro];
            end;
          else
            IllegalPara(opt);
          end;
          inc(j);
        end;
   end;
end;


procedure TOption.Interpret_T_l(opt, more: TCmdStr);

begin
  more:=Upper(More);
  if (more='') then
    Message1(option_missing_arg,'-t')
  else
    begin
    if (self.parasubtarget<>'') and (More<>upper(self.parasubtarget)) then
      Message1(option_subtarget_is_already_set,self.parasubtarget)
    else
      self.parasubtarget:=more;
    end;
end;


procedure TOption.Interpret_T_U(opt, more: TCmdStr);

begin
  more:=Upper(More);
  if paratarget=system_none then
   begin
     { remove old target define }
     TargetOptions(false);
     { load new target }
     paratarget:=FindSystemByString(More);
     if paratarget<>system_none then
       SetTarget(paratarget)
     else
       IllegalPara(opt);
     { set new define }
     TargetOptions(true);
   end
  else
   if More<>upper(TargetInfo.shortname) then
    Message1(option_target_is_already_set,TargetInfo.shortname);
end;


procedure TOption.Interpret_U_l(opt, more: TCmdStr);

begin
  if is_identifier(more) then
    begin
      if upper(more)='FPC_UNICODESTRINGS' then
        begin
          Message1(option_illegal_para,'-u'+more+' (selected by -MANSISTRINGS/-MUNICODESTRINGS)');
          StopOptions(1);
        end
      else
        Undef_System_Macro(more);
    end
  else
    begin
      if (more='') then
        Message1(option_missing_arg,'-u')
      else
        Message1(option_malformed_para,opt);
      StopOptions(1);
    end;
end;


procedure TOption.Interpret_U_U(opt, more: TCmdStr);

var
  j : integer;

begin
  j:=1;
  while j<=length(more) do
    begin
      case more[j] of
{$ifdef UNITALIASES}
       'a' :
          begin
            AddUnitAlias(Copy(More,j+1));
            break;
          end;
{$endif UNITALIASES}
       'n' :
         exclude(InitSettings.GlobalSwitches,cs_check_unit_name);
       'r' :
         begin
           Do_Release:=true;
           if (cs_checkpointer in InitSettings.LocalSwitches) then
             begin
               Message(option_gc_incompatible_with_release_flag);
               exclude(InitSettings.LocalSwitches,cs_checkpointer);
             end;
         end;
       's' :
         include(InitSettings.ModuleSwitches,cs_compilesystem);
       '-' :
         begin
           exclude(InitSettings.ModuleSwitches,cs_compilesystem);
           exclude(InitSettings.GlobalSwitches,cs_check_unit_name);
         end;
       else
         IllegalPara(opt);
      end;
      inc(j);
    end;
end;


procedure TOption.Interpret_V_l(opt, more: TCmdStr);

begin
  if not setverbosity(More) then
    IllegalPara(opt);
end;


procedure TOption.Interpret_V_U(opt, more: TCmdStr);

begin
  ; { Ignore used by fpc }
end;


procedure TOption.Interpret_W_U(opt, more: TCmdStr);

var
  j,code : integer;
  s : string;

begin
  j:=1;
  while j<=length(More) do
   begin
     case More[j] of
       'A':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               if UnsetBool(More, j, opt, false) then
                 SetApptype(app_cui)
               else
                 SetApptype(app_native);
             end
           else
             IllegalPara(opt);
         end;
       'b':
         begin
           if TargetInfo.system in systems_darwin then
             begin
               if UnsetBool(More, j, opt, false) then
                 SetApptype(app_cui)
               else
                 SetApptype(app_bundle)
             end
           else
             IllegalPara(opt);
         end;
       'B':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               {  -WB200000 means set trefered base address
                 to $200000, but does not change relocsection boolean
                 this way we can create both relocatable and
                 non relocatable DLL at a specific base address PM }
               if (length(More)>j) then
                 begin
                   val('$'+Copy(More,j+1),ImageBase,code);
                   if code<>0 then
                     IllegalPara(opt);
                   ImageBaseSetExplicity:=true;
                 end
               else
                 begin
                   RelocSection:=true;
                   RelocSectionSetExplicitly:=true;
                 end;
               break;
             end
           else
             IllegalPara(opt);
         end;
       'C':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               if UnsetBool(More, j, opt, false) then
                 SetApptype(app_gui)
               else
                 SetApptype(app_cui);
             end
           else
             IllegalPara(opt);
         end;
       'D':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               UseDefFileForExports:=not UnsetBool(More, j, opt, false);
               UseDefFileForExportsSetExplicitly:=true;
             end
           else
             IllegalPara(opt);
         end;
       'e':
         begin
           if (TargetInfo.system in systems_darwin) then
             begin
               SetTargetRes(res_ext);
               TargetInfo.resobjext:='.fpcres';
             end
           else
             IllegalPara(opt);
         end;
       'F':
         begin
           IllegalPara(opt);
         end;
       'G':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               if UnsetBool(More, j, opt, false) then
                 SetApptype(app_cui)
               else
                 SetApptype(app_gui);
             end
           else
             IllegalPara(opt);
         end;

       'I':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               GenerateImportSection:=not UnsetBool(More,j,opt,false);
               GenerateImportSectionSetExplicitly:=true;
             end
           else
             IllegalPara(opt);
         end;
       'i':
         begin
           if (TargetInfo.system in systems_darwin) then
             begin
               SetTargetRes(res_macho);
               TargetInfo.resobjext:=
                 targetinfos[Ord(TargetInfo.system)]^.resobjext;
             end
           else
             IllegalPara(opt);
         end;
       'm':
         begin

             IllegalPara(opt);
         end;
       'M':
         begin
           if (TargetInfo.system in (systems_darwin-[system_i386_iphonesim,system_aarch64_ios,system_x86_64_iphonesim,system_aarch64_iphonesim])) and
              ParseMacVersionMin(MacOSXVersionMin,IPhoneOSVersionMin,'MAC_OS_X_VERSION_MIN_REQUIRED',copy(More,2),false) then
             begin
               break;
             end
           else
             IllegalPara(opt);
         end;
       'N':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               RelocSection:=UnsetBool(More,j,opt,false);
               RelocSectionSetExplicitly:=true;
             end
           else
             IllegalPara(opt);
         end;
       'p':
         begin
           IllegalPara(opt);
         end;
       'P':
         begin
           if (TargetInfo.system in [system_aarch64_ios,system_x86_64_iphonesim,system_aarch64_iphonesim]) and
              ParseMacVersionMin(IPhoneOSVersionMin,MacOSXVersionMin,'IPHONE_OS_VERSION_MIN_REQUIRED',copy(More,2),true) then
             begin
               break;
             end
           else
             IllegalPara(opt);
         end;
       'R':
         begin
           if TargetInfo.system in systems_all_windows then
             begin
               { support -WR+ / -WR- as synonyms to -WR / -WN }
               RelocSection:=not UnsetBool(More,j,opt,false);
               RelocSectionSetExplicitly:=true;
             end
           else
             IllegalPara(opt);
         end;
       't':
         begin

             IllegalPara(opt);
         end;
       'X':
         begin
           if (TargetInfo.system in systems_linux) then
             begin
               if UnsetBool(More, j, opt, false) then
                 exclude(InitSettings.ModuleSwitches,cs_executable_stack)
               else
                 include(InitSettings.ModuleSwitches,cs_executable_stack)
             end
           else
             IllegalPara(opt);
         end;
       else
         IllegalPara(opt);
     end;
     inc(j);
   end;
end;

procedure TOption.Interpret_X_U(opt, more: TCmdStr);

var
  j : integer;
  s : string;

begin
  j:=1;
  while j<=length(more) do
   begin
     case More[j] of
       '9' :
         begin
           if TargetInfo.system in systems_linux then
             begin
               if UnsetBool(More, j, opt, false) then
                 exclude(InitSettings.GlobalSwitches,cs_link_pre_binutils_2_19)
               else
                 include(InitSettings.GlobalSwitches,cs_link_pre_binutils_2_19);
             end
           else
             IllegalPara(opt);
         end;
       'a' :
         begin
           If UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_large)
           else
             include(InitSettings.GlobalSwitches,cs_large);
         end;
       'c' : CShared:=TRUE;
       'd' : DontLinkStdlibPath:=TRUE;
       'e' :
         begin
           if UnsetBool(More, j, opt, false) then
             UnsupportedPara(opt)
           else
             include(InitSettings.GlobalSwitches,cs_link_extern);
         end;
       'g' :
         begin
           If UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_link_separate_dbg_file)
           else
             include(InitSettings.GlobalSwitches,cs_link_separate_dbg_file);
         end;
       'i' :
         begin
           if UnsetBool(More, j, opt, false) then
             include(InitSettings.GlobalSwitches,cs_link_extern)
           else
             UnsupportedPara(opt);
         end;
       'm' :
         begin
           If UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_link_map)
           else
             include(InitSettings.GlobalSwitches,cs_link_map);
         end;
       'p' : ; { Ignore used by fpc.pas }
       'r' :
         begin
           if (TargetInfo.system in suppported_targets_x_smallr) then
             begin
               RLinkPath:=Copy(more,2);
               DefaultReplacements(RLinkPath);
             end
           else
             IgnoredPara('-Xr');
           more:='';
         end;
       'R' :
         begin
           SysRootPath:=copy(more,2);
           defaultreplacements(SysRootPath);
           more:='';
         end;
       's' :
         begin
           If UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_link_strip)
           else
             include(InitSettings.GlobalSwitches,cs_link_strip);
         end;
       't' :
         include(InitSettings.GlobalSwitches,cs_link_staticflag);
       'v' :
         begin
           If UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_link_opt_vtable)
           else
             include(InitSettings.GlobalSwitches,cs_link_opt_vtable);
         end;
       'D' :
         begin
           Def_System_Macro('FPC_LINK_DYNAMIC');
           Undef_System_Macro('FPC_LINK_SMART');
           Undef_System_Macro('FPC_LINK_STATIC');
           exclude(InitSettings.GlobalSwitches,cs_link_static);
           exclude(InitSettings.GlobalSwitches,cs_link_smart);
           include(InitSettings.GlobalSwitches,cs_link_shared);
           LinkTypeSetExplicitly:=true;
         end;
       'M' :
         begin
           MainAliasName:=Copy(more,2);
           More:='';
         end;
       'P' :
         begin
           UtilsPrefix:=Copy(more,2);
           DefaultReplacements(UtilsPrefix);
           More:='';
         end;
       'L' : begin  // -XLO is link order -XLA is link alias. -XLD avoids load defaults.
                    // these are not aggregable.
               if (j=length(more)) or not (more[j+1] in ['O','A','D','L']) then
                 IllegalPara(opt)
               else
                 begin
                   case more[j+1] of
                    'A' : begin
                           s:=Copy(more,3);
                           if not LinkLibraryAliases.AddDep(s) Then
                              IllegalPara(opt);
                          end;
                    'O' : begin
                           s:=Copy(more,3);
                           if not LinkLibraryOrder.AddWeight(s) Then
                              IllegalPara(opt);
                          end;
                    'D' : include(InitSettings.GlobalSwitches,cs_link_no_default_lib_order);
                    'L' :
                      begin
                        if UnsetBool(More, j, opt, false) then
                          exclude(InitSettings.GlobalSwitches,cs_link_lld)
                        else
                          begin
                            include(InitSettings.GlobalSwitches,cs_link_lld);
                            include(InitSettings.GlobalSwitches,cs_link_extern);
                          end;
                       LinkerSetExplicitly:=true;
                     end
                   else
                     IllegalPara(opt);
                    end; {case}
                   j:=length(more);
                 end; {else begin}
             end;
       'S' :
         begin
           ForceStaticLinking;
         end;
       'V' :
         begin
           if UnsetBool(More, j, opt, false) then
             exclude(InitSettings.GlobalSwitches,cs_link_vlink)
           else
             begin
               include(InitSettings.GlobalSwitches,cs_link_vlink);
               include(InitSettings.GlobalSwitches,cs_link_extern);
             end;
           LinkerSetExplicitly:=true;
         end;
       'X' :
         begin
           Def_System_Macro('FPC_LINK_SMART');
           Undef_System_Macro('FPC_LINK_STATIC');
           Undef_System_Macro('FPC_LINK_DYNAMIC');
           exclude(InitSettings.GlobalSwitches,cs_link_static);
           include(InitSettings.GlobalSwitches,cs_link_smart);
           exclude(InitSettings.GlobalSwitches,cs_link_shared);
           LinkTypeSetExplicitly:=true;
         end;
       '-' :
         begin
           exclude(InitSettings.GlobalSwitches,cs_link_staticflag);
           exclude(InitSettings.GlobalSwitches,cs_link_strip);
           exclude(InitSettings.GlobalSwitches,cs_link_map);
           set_default_link_type;
         end;
       else
         IllegalPara(opt);
     end;
     inc(j);
   end;

end;

{****************************************************************************
                              Callable Routines
****************************************************************************}

function check_configfile(fn:string; var foundfn:string):boolean;

  function CfgFileExists(const fn:string):boolean;
  begin
    Comment(VTried,'Configfile search: '+fn);
    CfgFileExists:=FileExists(fn);
  end;

var
{$ifdef Unix}
  hs,
{$endif Unix}
  configpath : string;
begin
  foundfn:=fn;
  check_configfile:=true;
  { retrieve configpath }
  configpath:=FixPath(GetEnvironmentVariable('PPC_CONFIG_PATH'),false);
{$ifdef Unix}
  if configpath='' then
   configpath:=ExpandFileName(FixPath(ExePath+'../etc/',false));
{$endif}
  {
    Order to read configuration file :
    try reading fpc.cfg in :
     1 - current dir
     2 - configpath
     3 - compiler path
  }
  if not FileExists(fn) then
   begin
{$ifdef Unix}
     hs:=GetEnvironmentVariable('HOME');
     if (hs<>'') and CfgFileExists(FixPath(hs,false)+'.'+fn) then
      foundfn:=FixPath(hs,false)+'.'+fn
     else
{$endif}
      if CfgFileExists(configpath+fn) then
       foundfn:=configpath+fn
     else
{$ifdef WINDOWS}
       if (GetEnvironmentVariable('USERPROFILE')<>'') and CfgFileExists(FixPath(GetEnvironmentVariable('USERPROFILE'),false)+fn) then
         foundfn:=FixPath(GetEnvironmentVariable('USERPROFILE'),false)+fn
     else
       if (GetEnvironmentVariable('ALLUSERSPROFILE')<>'') and CfgFileExists(FixPath(GetEnvironmentVariable('ALLUSERSPROFILE'),false)+fn) then
         foundfn:=FixPath(GetEnvironmentVariable('ALLUSERSPROFILE'),false)+fn
     else
{$endif WINDOWS}
{$ifndef Unix}
      if CfgFileExists(ExePath+fn) then
       foundfn:=ExePath+fn
     else
{$else}
      if CfgFileExists('/etc/'+fn) then
       foundfn:='/etc/'+fn
     else
{$endif}
      check_configfile:=false;
   end;
end;



procedure read_arguments(cmd:TCmdStr);

  procedure def_cpu_macros;
    var
      abi : TABI;
      FPUType : TFPUType;
      CPUType : TCPUType;
      controller: TControllerType;
      s: string;
    begin

      for CPUType:=low(TCPUType) to high(TCPUType) do
        Undef_System_Macro('CPU'+CPUTypeStr[CPUType]);
      Def_System_Macro('CPU'+CPUTypeStr[InitSettings.CPUType]);

      for FPUType:=low(TFPUType) to high(TFPUType) do
        Undef_System_Macro('FPU'+FPUTypeStr[FPUType]);
      Def_System_Macro('FPU'+FPUTypeStr[InitSettings.FPUType]);

{$PUSH}
{$WARN 6018 OFF} { Unreachable code due to compile time evaluation }
      if ControllerSupport then
        begin
          for controller:=low(TControllerType) to high(TControllerType) do
            begin
              s:=embedded_controllers[controller].ControllerTypeStr;
              if s<>'' then
                Undef_System_Macro('FPC_MCU_'+s);
            end;
          s:=embedded_controllers[InitSettings.ControllerType].ControllerTypeStr;
          if s<>'' then
            Def_System_Macro('FPC_MCU_'+s);
        end;
{$POP}

      { define abi }
      for abi:=low(TABI) to high(TABI) do
        Undef_System_Macro('FPC_ABI_'+ABIInfo[abi].name);
      Def_System_Macro('FPC_ABI_'+ABIInfo[TargetInfo.abi].name);

      { this is not a switchable ABI in the sense of tabi, but it's an ABI
        nevertheless }
      if TargetInfo.system in systems_win64_abi then
        Def_System_Macro('FPC_ABI_WIN64');

      { Define FPC_ABI_EABI in addition to FPC_ABI_EABIHF on EABI VFP hardfloat
        systems since most code needs to behave the same on both}
      if TargetInfo.abi = abi_eabihf then
        Def_System_Macro('FPC_ABI_EABI');

      { using a case is pretty useless here (FK) }
      { some stuff for TP compatibility }
      {$ifdef i386}
        Def_System_Macro('CPU86');
        Def_System_Macro('CPU87');
        Def_System_Macro('CPU386');
      {$endif}

      { new processor stuff }
      {$ifdef i386}
        Def_System_Macro('CPUI386');
        Def_System_Macro('CPU32');
        Def_System_Macro('CPUX86');
        Def_System_Macro('FPC_HAS_TYPE_EXTENDED');
        Def_System_Macro('FPC_HAS_TYPE_DOUBLE');
        Def_System_Macro('FPC_HAS_TYPE_SINGLE');
      {$endif}




      {$ifdef x86_64}
        Def_System_Macro('CPUX86_64');
        Def_System_Macro('CPUAMD64');
        Def_System_Macro('CPU64');
        Def_System_Macro('CPUX64');
        { Win64 Currency and Comp retain their integer representation. }
        if TargetInfo.system=system_x86_64_win64 then
          begin
            Def_System_Macro('FPC_CURRENCY_IS_INT64');
            Def_System_Macro('FPC_COMP_IS_INT64');
          end;
      {$endif}












      {$ifdef aarch64}
        Def_System_Macro('CPUAARCH64');
        Def_System_Macro('CPUARM64');
        Def_System_Macro('CPU64');
        Def_System_Macro('FPC_CURRENCY_IS_INT64');
        Def_System_Macro('FPC_COMP_IS_INT64');
      {$endif aarch64}








      {$if defined(cpu32bitalu)}
        Def_System_Macro('CPUINT32');
      {$elseif defined(cpu64bitalu)}
        Def_System_Macro('CPUINT64');
      {$endif defined(cpu64bitalu)}


      { abs(long) is handled internally on all CPUs }
        Def_System_Macro('FPC_HAS_INTERNAL_ABS_LONG');
      { abs(int64) is handled internally on all CPUs }
        Def_System_Macro('FPC_HAS_INTERNAL_ABS_INT64');

        Def_System_Macro('FPC_HAS_UNICODESTRING');
        Def_System_Macro('FPC_RTTI_PACKSET1');
        Def_System_Macro('FPC_HAS_CPSTRING');
      {$ifdef x86_64}
        Def_System_Macro('FPC_HAS_RIP_RELATIVE');
      {$endif x86_64}
        Def_System_Macro('FPC_HAS_CEXTENDED');
        Def_System_Macro('FPC_HAS_RESSTRINITS');

      { these cpus have an inline rol/ror implementation }
      {$ifdef cpurox}
        Def_System_Macro('FPC_HAS_INTERNAL_ROX');
      {$endif}


      Def_System_Macro('FPC_HAS_ANSICHAR_CHAR');
      { currently, all supported CPUs have an internal sar implementation }
        Def_System_Macro('FPC_HAS_INTERNAL_SAR');
      {$ifdef SUPPORT_GET_FRAME}
        Def_System_Macro('INTERNAL_BACKTRACE');
      {$endif SUPPORT_GET_FRAME}
        Def_System_Macro('STR_CONCAT_PROCS');
      {$warnings off}
        if pocall_default = pocall_register then
          Def_System_Macro('REGCALL');
      {$warnings on}
    end;

var
  env: AnsiString;
  i : TFeature;
  j : LongInt;
  tmplist : TCmdStrList;
  cmditem,
  tmpcmditem : TCmdStrListItem;
  cmdstr : TCmdStr;
{$if defined(cpucapabilities)}
  cpuflag : TCPUFlags;
{$endif defined(cpucapabilities)}
{$if defined(fpucapabilities)}
  fpuflag : TFPUFlags;
{$endif defined(fpucapabilities)}
{$if defined(cpucapabilities) or defined(fpucapabilities)}
  hs : string;
{$endif defined(cpucapabilities) or defined(fpucapabilities)}
begin
  option:=coption.create;
  disable_configfile:=false;

  { Non-core target defines }
  Option.TargetOptions(true);

{ get default messagefile }
  MsgFileName:=GetEnvironmentVariable('PPC_ERROR_FILE');

{ default configfile can be specified on the commandline,
   remove it first }
  if (cmd<>'') and (cmd[1]='[') then
    begin
      ppccfg:=Copy(cmd,2,pos(']',cmd)-2);
      Delete(cmd,1,pos(']',cmd));
    end
  else
    ppccfg:='fpc.cfg';

{ first pass reading of parameters, only -i -v -T etc.}
  option.FirstPass:=true;
  if cmd<>'' then
    option.parsecmd(cmd)
  else
    begin
      option.read_parameters;
      { Write only quickinfo }
      if option.quickinfo<>'' then
        option.writequickinfo;
    end;
  option.FirstPass:=false;

  { redefine target options so all defines are written even if no -Txxx is passed on the command line }
  Option.TargetOptions(true);

  SetApptype(AppType);

{ default defines }
  Def_System_Macro(TargetInfo.shortname);
  Def_System_Macro('FPC');
  Def_System_Macro('VER'+VersionNr);
  Def_System_Macro('VER'+VersionNr+'_'+ReleaseNr);
  Def_System_Macro('VER'+VersionNr+'_'+ReleaseNr+'_'+PatchNr);

{ Temporary defines, until things settle down }
  Def_System_Macro('FPC_HAS_OPERATOR_ENUMERATOR');
  Def_System_Macro('FPC_HAS_CONSTREF');
  Def_System_Macro('FPC_STATICRIPFIXED');
  Def_System_Macro('FPC_VARIANTCOPY_FIXED');
  Def_System_Macro('FPC_DYNARRAYCOPY_FIXED');
  Def_System_Macro('FPC_HAS_MEMBAR');
  Def_System_Macro('FPC_SETBASE_USED');
  Def_System_Macro('FPC_ALIGNED_THREADVARTABLES');
  Def_System_Macro('FPC_INITFINAL_HASUNITNAME');

  Def_System_Macro('FPC_HAS_FEATURE_SUPPORT');
  if (Option.parasubtarget<>'') then
    begin
    Def_System_Macro('FPC_SUBTARGET_'+Option.parasubtarget);
    if cs_support_macro in InitSettings.ModuleSwitches then
      Set_System_Macro('FPC_SUBTARGET',Option.parasubtarget)
    else
      Set_System_CompVar('FPC_SUBTARGET',Option.parasubtarget);
    // So it can be used in macro substitution.
    Globals.SubTarget:=Option.parasubtarget;
    end;

  { make cpu makros available when reading the config files the second time }
  def_cpu_macros;
  set_endianess_macros;

  if tf_cld in TargetInfo.flags then
    if not UpdateTargetSwitchStr('CLD', InitSettings.TargetSwitches, true) then
      InternalError(2013092801);

  { Android uses the NDK's unprefixed Clang with an explicit target triple.
    An explicit -XP option can still select a tool prefix below. }

  { read configuration file }
  if (not disable_configfile) and
     (ppccfg<>'') then
    read_configfile:=check_configfile(ppccfg,ppccfg)
  else
    read_configfile := false;
  if (option.parasubtarget<>'') then
    begin
    subcfg:='fpc-'+lower(option.parasubtarget)+'.cfg';
    read_subfile:=check_configfile(subcfg,subcfg);
    // Warn if we didn't find an architecture-specific file
    if not read_subfile then
      message2(option_subtarget_config_not_found,option.parasubtarget,subcfg);
    end;

{ Read commandline and configfile }
  param_file:='';

  { read configfile }
  if read_configfile then
    option.interpret_file(ppccfg);
  if read_subfile then
    option.interpret_file(subcfg);

  { read parameters again to override config file }
  if cmd<>'' then
    option.parsecmd(cmd)
  else
    begin
      { Write help pages if no parameters are passed }
      if (paramcount=0) then
        Option.WriteHelpPages;
      option.read_parameters;
      { Write only quickinfo }
      if option.quickinfo<>'' then
        option.writequickinfo;
    end;

  { check the compatibility of different options and adjust them if necessary
    (and print possible errors)
  }
  option.checkoptionscompatibility;

  { uses the CPUXXX-defines and target_info to determine whether the selected
    target processor, if any, is supported }
  Option.VerifyTargetProcessor;

  { Stop if errors in options }
  if ErrorCount>0 then
   StopOptions(1);

  { Write logo }
  if option.ParaLogo then
    option.writelogo;

{ Check file to compile }
  if param_file='' then
   begin
     Message(option_no_source_found);
     StopOptions(1);
   end;
{$ifndef Unix}
  param_file:=FixFileName(param_file);
{$endif not unix}
  InputFilePath:=ExtractFilePath(param_file);
  InputFileName:=ExtractFileName(param_file);
  if ExtractFileExt(InputFileName)='' then
    begin
      if FileExists(InputFilePath+ChangeFileExt(InputFileName,SourceExt)) then
        InputFileName:=ChangeFileExt(InputFileName,SourceExt)
      else if ((m_mac in CurrentSettings.ModeSwitches) or
              (tf_p_ext_support in TargetInfo.flags))
             and FileExists(InputFilePath+ChangeFileExt(InputFileName,pext)) then
        InputFileName:=ChangeFileExt(InputFileName,pext);
    end;

  { Check output dir }
  if (OutputExeDir<>'') and
     not PathExists(OutputExeDir,false) then
    begin
      Message1(general_e_path_does_not_exist,OutputExeDir);
      StopOptions(1);
    end;

  { Add paths specified with parameters to the searchpaths }
  UnitSearchPath.AddList(option.ParaUnitPath,true);
  ObjectSearchPath.AddList(option.ParaObjectPath,true);
  IncludeSearchPath.AddList(option.ParaIncludePath,true);
  LibrarySearchPath.AddList(option.ParaLibraryPath,true);
  FrameworkSearchPath.AddList(option.ParaFrameworkPath,true);
  PackageSearchPath.addlist(option.parapackagepath,true);
  for j:=0 to option.parapackages.count-1 do
    Add_Package(option.parapackages.NameOfIndex(j),true,true);

  { add default namespaces }
  tmplist:=TCmdStrList.Create;
  cmditem:=TCmdStrListItem(option.paranamespaces.First);
  while Assigned(cmditem) do
    begin
      { use a temporary list cause if ";" are involved we need to reverse the
        order due to how TCmdStrList behaves }
      cmdstr:=cmditem.str;
      repeat
        j:=Pos(';',cmdstr);
        if j>0 then
          begin
            tmplist.insert(copy(cmdstr,1,j-1));
            delete(cmdstr,1,j);
          end
        else
          tmplist.insert(cmdstr);
      until j=0;
      tmpcmditem:=TCmdStrListItem(tmplist.First);
      while Assigned(tmpcmditem) do
        begin
          NamespaceList.insert(tmpcmditem.Str);
          tmpcmditem:=TCmdStrListItem(tmpcmditem.Next);
        end;
      tmplist.clear;
      cmditem:=TCmdStrListItem(cmditem.Next);
    end;
  tmplist.Free;
  tmplist := nil;

  { add unit environment and exepath to the unit search path }
  if InputFilePath<>'' then
   UnitSearchPath.AddPath(InputFilePath,true);
  if not disable_configfile then
    begin
      env:=GetEnvironmentVariable(TargetInfo.unit_env);
      if env<>'' then
        UnitSearchPath.AddPath(GetEnvironmentVariable(TargetInfo.unit_env),false);
    end;

{$ifdef Unix}
  fpcdir:=FixPath(GetEnvironmentVariable('FPCDIR'),false);
  if fpcdir='' then
    begin
      if PathExists('/usr/local/lib/fpc/'+Version_String,true) then
        fpcdir:='/usr/local/lib/fpc/'+Version_String+'/'
      else
        fpcdir:='/usr/lib/fpc/'+Version_String+'/';
    end;
{$else unix}
  fpcdir:=FixPath(GetEnvironmentVariable('FPCDIR'),false);
  if fpcdir='' then
    begin
      fpcdir:=ExePath+'../';
      if not(PathExists(fpcdir+'units',true)) and
         not(PathExists(fpcdir+'rtl',true)) then
        fpcdir:=fpcdir+'../';
    end;
{$endif unix}
  { first try development RTL, else use the default installation path }
  if not disable_configfile then
    begin
      if PathExists(FpcDir+'rtl',true) then
        if (tf_use_8_3 in SourceInfo.Flags) or
           (tf_use_8_3 in TargetInfo.Flags) then
          UnitSearchPath.AddPath(FpcDir+'rtl/'+TargetOSString,false)
        else
          UnitSearchPath.AddPath(FpcDir+'rtl/'+TargetFullString,false)
      else
        if (tf_use_8_3 in SourceInfo.Flags) or
           (tf_use_8_3 in TargetInfo.Flags) then
          UnitSearchPath.AddPath(FpcDir+'units/'+TargetOSString+'/rtl',false)
        else
          UnitSearchPath.AddPath(FpcDir+'units/'+TargetFullString+'/rtl',false);
    end;
  { Add exepath if the exe is not in the current dir, because that is always searched already.
    Do not add it when linking on the target because then we can maybe already find
    .o files that are not for the target }
  if (ExePath<>CFileUtl.GetCurrentDir) and
     not(cs_link_on_target in InitSettings.GlobalSwitches) then
   UnitSearchPath.AddPath(ExePath,false);
  { Add unit dir to the object and library path }
  ObjectSearchPath.AddList(UnitSearchPath,false);
  LibrarySearchPath.AddList(UnitSearchPath,false);


  { maybe override assembler }
  if (option.paratargetasm<>as_none) then
    begin
      if (option.paratargetasm=as_default) then
        begin
          if (TargetInfo.endian<>SourceInfo.endian) then
            option.paratargetasm:=TargetInfo.assemextern
          else
            option.paratargetasm:=TargetInfo.assem;
        end;
      if not SetTargetAsm(option.paratargetasm) then
        begin
          if Assigned(asminfos[option.paratargetasm]) then
            Message2(option_incompatible_asm,asminfos[option.paratargetasm]^.idtxt,TargetInfo.name)
          else
            Message2(option_incompatible_asm,'<invalid assembler>',TargetInfo.name);
          SetTargetAsm(TargetInfo.assemextern);
          Message1(option_asm_forced,TargetAsm.idtxt);
        end;
      if (af_no_debug in asminfos[option.paratargetasm]^.flags) and
         (option.paratargetdbg<>dbg_none) then
        begin
          Message1(option_confict_asm_debug,
            asminfos[option.paratargetasm]^.idtxt);
          option.paratargetdbg:=dbg_none;
          exclude(InitSettings.ModuleSwitches,cs_debuginfo);
        end;
    end;

  {TOptionheck a second time as we might have changed assembler just above }
  option.checkoptionscompatibility;

  { maybe override debug info format }
  if (option.paratargetdbg<>dbg_none) then
    if not SetTargetDbg(option.paratargetdbg) then
      Message(option_w_unsupported_debug_format);

  { switch assembler if it's binary and we got -a on the cmdline }
  if (af_outputbinary in TargetAsm.flags) and
     ((cs_asm_leave in InitSettings.GlobalSwitches) or
      { if -s is passed, we shouldn't call the internal assembler }
      (cs_asm_extern in InitSettings.GlobalSwitches)) or
      ((option.paratargetasm=as_none) and (TargetInfo.endian<>SourceInfo.endian)) then
   begin
     if ((option.paratargetasm=as_none) and (TargetInfo.endian<>SourceInfo.endian)) then
       begin
         if not ((TargetInfo.assem = TargetInfo.assemextern) or (TargetInfo.assem = as_none)) then
           Message(option_switch_bin_to_src_assembler_cross_endian);
       end
     else
       Message(option_switch_bin_to_src_assembler);

     SetTargetAsm(TargetInfo.assemextern);

     option.checkoptionscompatibility;
   end;

  { All retained targets use an external linker. }
  include(InitSettings.GlobalSwitches,cs_link_extern);

  { turn off stripping if compiling with debuginfo }
  if (cs_debuginfo in InitSettings.ModuleSwitches) and
     not(cs_link_separate_dbg_file in InitSettings.GlobalSwitches) then
    exclude(InitSettings.GlobalSwitches,cs_link_strip);

  { choose a reasonable tls model }
  if (tf_section_threadvars in TargetInfo.flags) and (InitSettings.TLSModel=tlsm_none) then
    begin
      if cs_create_pic in InitSettings.ModuleSwitches then
        InitSettings.TLSModel:=tlsm_global_dynamic
      else
        InitSettings.TLSModel:=tlsm_local_exec;
    end;

  { set Mac OS X version default macros if not specified explicitly }
  option.MaybeSetDefaultMacVersionMacro;

{$ifdef i386}
  case TargetInfo.system of
    system_i386_android:
      begin
        { set default cpu type to PentiumM for Android unless specified otherwise }
        if not option.CPUSetExplicitly then
          InitSettings.CPUType:=cpu_PentiumM;
        if not option.OptCPUSetExplicitly then
          InitSettings.OptimizeCPUType:=cpu_PentiumM;
        { set default fpu type to SSSE3 for Android unless specified otherwise }
        if not option.FPUSetExplicitly then
          InitSettings.FPUType:=fpu_ssse3;
      end;
    else
      ;
  end;
{$endif i386}


{$ifdef aarch64}
  case TargetInfo.system of
    system_aarch64_darwin:
      begin
        if not option.CPUSetExplicitly then
          InitSettings.CPUType:=cpu_armv84a;
        if not option.OptCPUSetExplicitly then
          InitSettings.OptimizeCPUType:=cpu_armv84a;
      end;
    else
      ;
  end;
{$endif aarch64}





  { now we can define cpu and fpu type }
  def_cpu_macros;
  set_endianess_macros;

  { Use init_settings cpu type for asm cpu type,
    if asmcputype is cpu_none,
    at least as long as there is no explicit
    option to set it on command line PM }
  if InitSettings.AsmCPUType = cpu_none then
    InitSettings.AsmCPUType:=InitSettings.CPUType;

{$if defined(cpucapabilities)}
  for cpuflag:=low(cpuflag) to high(cpuflag) do
    begin
      str(cpuflag,hs);
      if cpuflag in cpu_capabilities[InitSettings.CPUType] then
        Def_System_Macro(hs)
      else
        Undef_System_Macro(hs);
    end;
{$endif defined(cpucapabilities)}
{$if defined(fpucapabilities)}
  for fpuflag:=low(fpuflag) to high(fpuflag) do
    begin
      str(fpuflag,hs);
      if fpuflag in fpu_capabilities[InitSettings.FPUType] then
        Def_System_Macro(hs)
      else
        Undef_System_Macro(hs);
    end;
{$endif defined(fpucapabilities)}

  if InitSettings.FPUType<>fpu_none then
    begin
{$if defined(i386)}
      Def_System_Macro('FPC_HAS_TYPE_EXTENDED');
{$endif}
      Def_System_Macro('FPC_HAS_TYPE_SINGLE');
      Def_System_Macro('FPC_HAS_TYPE_DOUBLE');
{$if not defined(i386) and not defined(x86_64) and not defined(aarch64)}
      Def_System_Macro('FPC_INCLUDE_SOFTWARE_INT64_TO_DOUBLE');
{$endif}
{$ifdef x86_64}
      Def_System_Macro('FPC_HAS_TYPE_EXTENDED');
{$endif}
    end;
    { Enable now for testing }
{$ifndef DISABLE_TLS_DIRECTORY}
    if TargetInfo.system in systems_windows then
      Def_System_Macro('FPC_USE_TLS_DIRECTORY');
{$endif not DISABLE_TLS_DIRECTORY}

{$ifndef DISABLE_WIN64_SEH}
    if TargetInfo.system=system_x86_64_win64 then
      Def_System_Macro('FPC_USE_WIN64_SEH');
{$endif DISABLE_WIN64_SEH}

{$ifndef DISABLE_WIN32_SEH}
    if TargetInfo.system=system_i386_win32 then
      Def_System_Macro('FPC_USE_WIN32_SEH');
{$endif not DISABLE_WIN32_SEH}


{ inline bsf/bsr implementation }
{$if defined(i386) or defined(x86_64) or defined(aarch64)}
  Def_System_Macro('FPC_HAS_INTERNAL_BSF');
  Def_System_Macro('FPC_HAS_INTERNAL_BSR');
{$endif}

{ hardware FMA support }
{$if defined(i386) or defined(x86_64)}
  if (fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[] then
    begin
      Def_System_Macro('FPC_HAS_FAST_FMA_SINGLE');
      Def_System_Macro('FPC_HAS_FAST_FMA_DOUBLE');
    end;
{$endif defined(i386) or defined(x86_64)}





  { Section smartlinking conflicts with import sections on Windows }
  if GenerateImportSection and
     (TargetInfo.system in [system_i386_win32,system_x86_64_win64,system_aarch64_win64]) then
    exclude(TargetInfo.flags,tf_smartlink_sections);

  if not option.LinkTypeSetExplicitly then
    set_default_link_type;
  { Default alignment settings,
    1. load the defaults for the target
    2. adapt defaults specifically for the target
    3. override with generic optimizer setting (little size)
    4. override with the user specified -Oa }
  UpdateAlignment(InitSettings.alignment,TargetInfo.alignment);


  if (cs_opt_size in InitSettings.OptimizerSwitches) then
   begin
     InitSettings.alignment.ProcAlign:=1;
     InitSettings.alignment.JumpAlign:=1;
     InitSettings.alignment.CoalesceAlign:=1;
     InitSettings.alignment.LoopAlign:=1;
{$ifdef x86}
     { constalignmax=1 keeps the executable and thus the memory foot print small but
       all processors except x86 are really hurt by this or might even crash ... }
{$ifndef x86_64}
     { ... and will segfault if not aligned for SSE instructions }
     if not (CPUX86_HAS_SSEUNIT in cpu_capabilities[InitSettings.CPUType]) then
       InitSettings.alignment.ConstAlignMax:=1;
{$endif not x86_64}
{$endif x86}
   end;

  UpdateAlignment(InitSettings.alignment,option.paraalignment);

  Set_System_Macro('FPC_VERSION',VersionNr);
  Set_System_Macro('FPC_RELEASE',ReleaseNr);
  Set_System_Macro('FPC_PATCH',PatchNr);
  Set_System_Macro('FPC_FULLVERSION',Format('%d%.02d%.02d',[StrToInt(VersionNr),StrToInt(ReleaseNr),StrToInt(PatchNr)]));

  if TargetInfo.system in systems_indirect_entry_information then
    Def_System_Macro('FPC_HAS_INDIRECT_ENTRY_INFORMATION');

  if not (tf_winlikewidestring in TargetInfo.flags) then
    Def_System_Macro('FPC_WIDESTRING_EQUAL_UNICODESTRING');

  if tf_supports_packages in TargetInfo.flags then
    Def_System_Macro('FPC_HAS_DYNAMIC_PACKAGES');

  if TargetInfo.system in systems_indirect_var_imports then
    Def_System_Macro('FPC_HAS_INDIRECT_VAR_ACCESS');

  if cs_compilesystem in InitSettings.ModuleSwitches then
    for i:=low(TFeature) to high(TFeature) do
      if i in Features then
        Def_System_Macro('FPC_HAS_FEATURE_'+FeatureStr[i]);

  { as stackalign is not part of the alignment record, we do not need to define the others alignments for symmetry yet }
  Set_System_Macro('FPC_STACKALIGNMENT',ToStr(TargetInfo.stackalign));

  option.free;
  Option:=nil;

  clearstack_pocalls := [pocall_cdecl,pocall_cppdecl,pocall_syscall,pocall_mwpascal,pocall_sysv_abi_cdecl,pocall_ms_abi_cdecl];
  cdecl_pocalls := [pocall_cdecl, pocall_cppdecl, pocall_mwpascal, pocall_sysv_abi_cdecl, pocall_ms_abi_cdecl];
  if (tf_safecall_clearstack in TargetInfo.flags) then
    begin
      include (cdecl_pocalls, pocall_safecall);
      include (clearstack_pocalls, pocall_safecall)
    end;
end;


initialization
  coption:=TOption;
finalization
  if Assigned(option) then
   option.free;
   option := nil;
end.
