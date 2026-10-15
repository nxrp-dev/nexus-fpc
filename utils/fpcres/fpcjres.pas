{

    FPCRes - Free Pascal Resource Converter
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi
    Copyright (C) 2011 by Jonas Maebe

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{
  Java's internal resource file handling system is based on simply loading
  files from within the package name space. We reserve the namespace
  org.freepascal.rawresources for this purpose.

  This program creates a jar file (= zip file) containing all specified files.
}

program FPCJRes;

{$MODE OBJFPC} {$H+}

uses
  SysUtils, Classes, ParamParser, MsgHandler, JarSourceHandler,
  Zipper
  ;

const
  HaltNoErr = 0;
  HaltParamErr = 1;
  HaltReadErr = 2;
  HaltWriteErr = 3;

  ProgName = 'fpcjres';
  ProgVersion = '1.0'; //to distinguish from the old fpcres

  FPCVersion = {$INCLUDE %FPCVERSION%};
  HostArch = {$INCLUDE %FPCTARGETCPU%};
  HostOS = {$INCLUDE %FPCTARGETOS%};
  BuildDate = {$INCLUDE %DATE%};


var
  Params : TParameters = nil;
  Resources : TZipper = nil;
  SourceFiles : TJarSourceFiles = nil;

procedure ShowVersion;
begin
  WriteLn(ProgName+' - resource file converter, version '+ProgVersion+' ['+BuildDate+'], FPC '+FPCVersion);
  WriteLn('Host platform: '+HostOS+' - '+HostArch);
  WriteLn('Copyright (c) 2008 by Giulio Bernardi.');
  WriteLn('Copyright (c) 2011 by Jonas Maebe.');
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
  WriteLn('  --output, -o <x>     Set the output file name.');
  WriteLn('  @<file>              Read more options from file <file>');
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

  SCantCreateDirHier = 'Can''t create directory hierarchy ''%s''';
  SCantCreateFile = 'Can''t create file ''%s''';

function GetCurrentTimeMsec : LongInt;
var H,M,S,MS : Word;
begin
  DecodeTime(Time,H,M,S,MS);
  Result:=H*3600*1000 + M*60*1000 + S*1000 + MS;
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
    '.jar');
  if SameText(Tmp,Params.InputFiles[0]) then
    Tmp:=Tmp+'.jar';
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

  CheckInputFiles;
  CheckOutputFile;

  Messages.DoVerbose('finished parsing command line parameters');
end;

procedure LoadSourceFiles;
var Msg : string;
begin
  Msg:='';
  Resources:=TZipper.Create;
  SourceFiles:=TJarSourceFiles.Create;
  SourceFiles.FileList.AddStrings(Params.InputFiles);
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


procedure WriteOutputFile;
var
  Msg : string;
  OutFile: THandle;
  RemoveDirLevel: LongInt;
begin
  { create the "resbasedir" hierarchy, since that directory has to exist for
    TZipper to be able to add it. If it already exists, make sure we don't
    remove it }
  if DirectoryExists('org') then
    if DirectoryExists('org'+DirectorySeparator+'freepascal') then
      if DirectoryExists(ResBaseDir) then
        RemoveDirLevel:=0
      else
        RemoveDirLevel:=1
    else
      RemoveDirLevel:=2
  else
    RemoveDirLevel:=3;
  try
    ForceDirectories(ResBaseDir);
  except
    Messages.DoError(Format(SCantCreateDirHier,[ResBaseDir]));
    Halt(HaltWriteErr);
  end;
  try
    Messages.DoVerbose(Format('Trying to write output file %s...',[Params.OutputFile]));
    try
      { will be overwritten by the tzipper }
      OutFile:=FileCreate(Params.OutputFile,fmCreate or fmShareDenyWrite,438);
      FileClose(OutFile);
    except
      Messages.DoError(Format(SCantCreateFile,[Params.OutputFile]));
      Halt(HaltWriteErr);
    end;
    try
      Messages.DoVerbose(Format('Writing output file %s...',[Params.OutputFile]));
      Resources.FileName:=Params.OutputFile;
      Resources.ZipAllFiles;
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
    if RemoveDirLevel>0 then
      begin
        if RemoveDirLevel>1 then
          begin
            if RemoveDirLevel>2 then
              RemoveDir(ResBaseDir);
            RemoveDir('org'+DirectorySeparator+'freepascal');
          end;
        RemoveDir('org');
      end;
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
