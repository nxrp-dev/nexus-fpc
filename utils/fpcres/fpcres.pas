{

    FPCRes - Free Pascal Resource Converter
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{ Note: This program is not the old fpcres by Simon Kissel }

program FPCRes;

{$MODE OBJFPC} {$H+}

uses
  SysUtils, Classes, ParamParser, Target, MsgHandler, SourceHandler,
  ClosableFileStream, Resource,
//readers
  ResReader, COFFReader, WinPEImageReader, ELFReader, MachOReader,
  ExternalReader, DFMReader, TLBReader, RCReader,
//writers
  ResWriter, COFFWriter, XCOFFWriter, ELFWriter, MachOWriter,
  ExternalWriter,
//misc
  ELFConsts, COFFTypes, MachOTypes, ExternalTypes;

const
  HaltNoErr = 0;
  HaltParamErr = 1;
  HaltReadErr = 2;
  HaltWriteErr = 3;

  ProgName = 'fpcres';
  ProgVersion = '2.0'; //to distinguish from the old fpcres

  FPCVersion = {$INCLUDE %FPCVERSION%};
  HostArch = {$INCLUDE %FPCTARGETCPU%};
  HostOS = {$INCLUDE %FPCTARGETOS%};
  BuildDate = {$INCLUDE %DATE%};

var
  Params : TParameters = nil;
  Resources : TResources = nil;
  SourceFiles : TSourceFiles = nil;

procedure ShowVersion;
begin
  WriteLn(ProgName+' - resource file converter, version '+ProgVersion+' ['+BuildDate+'], FPC '+FPCVersion);
  WriteLn('Host platform: '+HostOS+' - '+HostArch);
  WriteLn('Copyright (c) 2008 by Giulio Bernardi.');
end;

procedure ShowHelp;
begin
  ShowVersion;
  WriteLn('Syntax: '+ProgName+' [options] <inputfile> [<inputfile>...] [-o <outputfile>]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --help, -h, -?       Show this screen.');
  WriteLn('  --version, -V        Show program version.');
  WriteLn('  --verbose, -v        Be verbose.');
  WriteLn('  --input, -i <x>      Ignored for compatibility.');
  WriteLn('  --include, -I <x>    RC files: add a path for include searches');
  WriteLn('  --define, -D <sym>[=<val>]');
  WriteLn('                       RC files: define a symbol (and value)');
  WriteLn('  --undefine, -U <sym> RC files: undefine a symbol');
  WriteLn('  --output, -o <x>     Set the output file name.');
  WriteLn('  -of <format>         Set the output file format. Supported formats:');
  WriteLn('                         res, elf, coff, mach-o, external');
  WriteLn('  --arch, -a <name>    Set object file architecture. Supported architectures:');
  WriteLn('                         i386, x86_64, arm (coff)');
  WriteLn('                         i386, x86_64, powerpc, powerpc64, arm, armeb, m68k,');
  WriteLn('                         riscv32, riscv64,');
  WriteLn('                         sparc, sparc64, alpha, ia64, mips, mipsel (elf)');
  WriteLn('                         i386, x86_64, powerpc, powerpc64, arm, aarch64 (mach-o)');
  WriteLn('                         bigendian, littleendian (external)');
  WriteLn('  --subarch, -s <name> Set object file sub-architecture. Supported values:');
  WriteLn('                         arm: all, v4t, v6, v5tej, xscale, v7');
  WriteLn('                         other architectures: all');
  WriteLn('  @<file>              Read more options from file <file>');
  WriteLn('Default output target: '+TargetToStr(CurrentTarget));
end;

const
  SOutputFileAlreadySet = 'Output file name already set.';
  SUnknownParameter = 'Unknown parameter ''%s''';
  SArgumentMissing = 'Argument missing for option ''%s''';
  SUnknownObjFormat = 'Unknown file format ''%s''';
  SUnknownMachine = 'Unknown architecture ''%s''';
  SFormatArchMismatch = 'Architecture %s is not available for %s format';
  SNoInputFiles = 'No input files';
  SNoOutputFile = 'No output file name specified';
  SCannotReadConfFile ='Can''t read config file ''%s''';

  SCantOpenFile = 'Can''t open file ''%s''';
  SUnknownInputFormat = 'No known file format detected for file ''%s''';

  SCantCreateFile = 'Can''t create file ''%s''';

function GetCurrentTimeMsec : LongInt;
var H,M,S,MS : Word;
begin
  DecodeTime(Time,H,M,S,MS);
  Result:=H*3600*1000 + M*60*1000 + S*1000 + MS;
end;

procedure CheckTarget;
begin
  //if user explicitly set a format, use it
  if Params.Target.ObjFormat<>ofNone then
    CurrentTarget.ObjFormat:=Params.Target.ObjFormat;
  //if no machine was specified, check if current is ok for this format,
  //otherwise pick the default one for that format
  if Params.Target.Machine=mtNone then
  begin
    if not (CurrentTarget.Machine in ObjFormats[CurrentTarget.ObjFormat].Machines) then
      begin
        CurrentTarget.Machine:=GetDefaultMachineForFormat(CurrentTarget.ObjFormat);
        CurrentTarget.SubMachine:=GetDefaultSubMachineForMachine(CurrentTarget.Machine);
      end
  end
  else
    begin
      CurrentTarget.Machine:=Params.Target.Machine;
      CurrentTarget.SubMachine:=Params.Target.SubMachine;
    end;

  if not (CurrentTarget.Machine in ObjFormats[CurrentTarget.ObjFormat].Machines) then
  begin
    Messages.DoError(Format(SFormatArchMismatch,[
     MachineToStr(CurrentTarget.Machine),ObjFormatToStr(CurrentTarget.ObjFormat)]));
    Halt(HaltParamErr);
  end;
  Messages.DoVerbose('target set to '+TargetToStr(CurrentTarget));
end;

procedure CheckInputFiles;
begin
  if Params.InputFiles.Count=0 then
  begin
    Messages.DoError(SNoInputFiles);
    Halt(HaltParamErr);
  end;
end;

procedure CheckOutputFile;
var Tmp : string;
begin
  if Params.OutputFile<>'' then exit;
  if Params.InputFiles.Count>1 then
  begin
    Messages.DoError(SNoOutputFile);
    Halt(HaltParamErr);
  end;
  Tmp:=ChangeFileExt(ExtractFileName(Params.InputFiles[0]),
    ObjFormats[CurrentTarget.ObjFormat].Ext);
  if SameText(Tmp,Params.InputFiles[0]) then
    Tmp:=Tmp+ObjFormats[CurrentTarget.ObjFormat].Ext;
  Params.OutputFile:=Tmp;
end;

procedure ParseParams;
var Msg : string;
begin
  Messages.DoVerbose('parsing command line parameters');
  Msg:='';
  if ParamCount = 0 then
  begin
    ShowHelp;
    Halt(HaltNoErr);
  end;
  Params:=TParameters.Create;
  try
    Params.Parse;
  except
    on E : EOutputFileAlreadySetException do Msg:=SOutputFileAlreadySet;
    on E : EUnknownParameterException do Msg:=Format(SUnknownParameter,[E.Message]);
    on E : EArgumentMissingException do Msg:=Format(SArgumentMissing,[E.Message]);
    on E : EUnknownObjFormatException do Msg:=Format(SUnknownObjFormat,[E.Message]);
    on E : EUnknownMachineException do Msg:=Format(SUnknownMachine,[E.Message]);
    on E : ECannotReadConfFile do Msg:=Format(SCannotReadConfFile,[E.Message]);
  end;
  Messages.Verbose:=Params.Verbose;
  if Msg<>'' then
  begin
    Messages.DoError(Msg);
    Halt(HaltParamErr);
  end;
  if Params.Version then
  begin
    ShowVersion;
    Halt(HaltNoErr);
  end;
  if Params.Help then
  begin
    ShowHelp;
    Halt(HaltNoErr);
  end;

  CheckTarget;
  CheckInputFiles;
  CheckOutputFile;

  Messages.DoVerbose('finished parsing command line parameters');
end;

procedure LoadSourceFiles;
var Msg : string;
begin
  Msg:='';
  Resources:=TResources.Create;
  SourceFiles:=TSourceFiles.Create;
  SourceFiles.FileList.AddStrings(Params.InputFiles);
  SourceFiles.RCDefines.AddStrings(Params.RCDefines);
  SourceFiles.RCIncludeDirs.AddStrings(Params.RCIncludeDirs);
  SourceFiles.RCMode:=CurrentTarget.ObjFormat=ofRes;
  try
    SourceFiles.Load(Resources);
  except
    on E : ECantOpenFileException do Msg:=Format(SCantOpenFile,[E.Message]);
    on E : EUnknownInputFormatException do Msg:=Format(SUnknownInputFormat,[E.Message]);
    on E : Exception do
    begin
      if E.Message='' then Msg:=E.ClassName
      else Msg:=E.Message;
    end;
  end;
  if Msg<>'' then
  begin
    Messages.DoError(Msg);
    Halt(HaltReadErr);
  end;
end;

function SetUpResWriter : TResResourceWriter;
begin
  Result:=TResResourceWriter.Create;
end;

function SetUpELFWriter : TElfResourceWriter;
begin
  Result:=TElfResourceWriter.Create;
  case CurrentTarget.Machine of
//    mtnone :
    mtI386 : Result.MachineType:=emti386;
    mtX8664 : Result.MachineType:=emtx86_64;
    mtPPC : Result.MachineType:=emtppc;
    mtPPC64 : Result.MachineType:=emtppc64;
    mtARM : Result.MachineType:=emtarm;
    mtARMEB : Result.MachineType:=emtarmeb;
    mtM68K : Result.MachineType:=emtm68k;
    mtSPARC : Result.MachineType:=emtsparc;
    mtSPARC64 : Result.MachineType:=emtsparc64;
    mtAlpha : Result.MachineType:=emtalpha;
    mtIA64 : Result.MachineType:=emtia64;
    mtMIPS : Result.MachineType:=emtmips;
    mtMIPSEL : Result.MachineType:=emtmipsel;
    mtPPC64LE : Result.MachineType:=emtppc64le;
    mtAArch64 : Result.MachineType:=emtaarch64;
    mtRISCV32 : Result.MachineType:=emtriscv32;
    mtRISCV64 : Result.MachineType:=emtriscv64;
    mtLoongArch64 : Result.MachineType:=emtloongarch64;
  end;
end;

function SetUpCOFFWriter : TCoffResourceWriter;
begin
  Result:=TCoffResourceWriter.Create;
  case CurrentTarget.Machine of
//    mtnone :
    mtI386 : Result.MachineType:=cmti386;
    mtARM : Result.MachineType:=cmtarm;
    mtX8664 : Result.MachineType:=cmtx8664;
    mtAArch64 : Result.MachineType:=cmtaarch64;
  end;
end;

function SetUpXCOFFWriter : TCoffResourceWriter;
begin
  Result:=TXCoffResourceWriter.Create;
  case CurrentTarget.Machine of
//    mtnone :
    mtPPC : Result.MachineType:=cmtppc32aix;
//    mtppc64 : Result.MachineType:=cmtppc64aix;
  end;
end;


function SetUpMachOWriter : TMachOResourceWriter;
const
  ArmSubMachine2MachOSubMachine: array[TSubMachineTypeArm] of TMachOSubMachineTypeArm =
    (msmarm_all,msmarm_v4t,msmarm_v6,msmarm_v5tej,msmarm_xscale,msmarm_v7);
var
  MachOSubMachineType: TMachoSubMachineType;
begin
  Result:=TMachOResourceWriter.Create;
  case CurrentTarget.Machine of
//    mtnone :
    mtI386 :
      begin
        Result.MachineType:=mmti386;
        MachOSubMachineType.F386SubType:=msm386_all;
      end;
    mtX8664 :
      begin
        Result.MachineType:=mmtx86_64;
        MachOSubMachineType.FX64SubType:=msmx64_all;
      end;
    mtPPC :
      begin
        Result.MachineType:=mmtpowerpc;
        MachOSubMachineType.FPpcSubType:=msmppc_all;
      end;
    mtPPC64 :
      begin
        Result.MachineType:=mmtpowerpc64;
        MachOSubMachineType.FPpc64SubType:=msmppc64_all;
      end;
    mtARM :
      begin
        Result.MachineType:=mmtarm;
        MachOSubMachineType.FArmSubType:=ArmSubMachine2MachOSubMachine[CurrentTarget.SubMachine.SubArm];
      end;
    mtAArch64 :
      begin
        Result.MachineType:=mmtarm64;
        MachOSubMachineType.FArm64SubType:=msmaarch64_all;
      end;
  end;
  Result.SubMachineType:=MachOSubMachineType;
end;

function SetUpExternalWriter : TExternalResourceWriter;
begin
  Result:=TExternalResourceWriter.Create;
  case CurrentTarget.Machine of
//    mtnone :
    mtBigEndian : Result.Endianess:=ExtEndianBig;
    mtLittleEndian : Result.Endianess:=ExtEndianLittle;
  end;
end;

procedure WriteOutputFile;
var AStream : TClosableFileStream;
    AWriter : TAbstractResourceWriter;
    Msg : string;
begin
  Messages.DoVerbose(Format('Trying to create output file %s...',[Params.OutputFile]));
  try
    AStream:=TClosableFileStream.Create(Params.OutputFile,fmCreate or fmShareDenyWrite);
  except
    Messages.DoError(Format(SCantCreateFile,[Params.OutputFile]));
    Halt(HaltWriteErr);
  end;
  try
    Messages.DoVerbose('Setting up resource writer...');
    case CurrentTarget.ObjFormat of
      ofRes   : AWriter:=SetUpResWriter;
      ofElf   : AWriter:=SetUpELFWriter;
      ofCoff  : AWriter:=SetUpCOFFWriter;
      ofXCoff : AWriter:=SetUpXCOFFWriter;
      ofMachO : AWriter:=SetUpMachOWriter;
      ofExt   : AWriter:=SetUpExternalWriter;
    end;
    try
      Messages.DoVerbose(Format('Writing output file %s...',[Params.OutputFile]));
      try
        Resources.WriteToStream(AStream,AWriter);
      except
        on E : Exception do
        begin
          if E.Message='' then Msg:=E.ClassName
          else Msg:=E.Message;
          Messages.DoError(Msg);
          Halt(HaltWriteErr);
        end;
      end;
      Messages.DoVerbose(Format('Output file %s written',[Params.OutputFile]));
    finally
      AWriter.Free;
    end;
  finally
    AStream.Free;
  end;
end;

procedure Cleanup;
begin
  Messages.DoVerbose('Cleaning up');
  if Resources<>nil then Resources.Free;
  if SourceFiles<>nil then SourceFiles.Free;
  if Params<>nil then Params.Free;
end;

var Before, Elapsed : LongInt;

begin
  try
    Before:=GetCurrentTimeMsec;
    ParseParams;
    LoadSourceFiles;
    WriteOutputFile;
    Elapsed:=GetCurrentTimeMsec-Before;
    if Elapsed<0 then Elapsed:=24*3600*1000 + Elapsed;
    Messages.DoVerbose(Format('Time elapsed: %d.%d seconds',[Elapsed div 1000,(Elapsed mod 1000) div 10]));
  finally
    Cleanup;
  end;
end.
