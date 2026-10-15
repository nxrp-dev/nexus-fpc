{

    FPCResLipo - Free Pascal External Resource Thinner
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

program FPCResLipo;

{$MODE OBJFPC} {$H+}

uses
  SysUtils, Classes, ParamParser, MsgHandler, SourceHandler,
  Resource, ExternalReader, ExternalWriter;

const
  HaltNoErr = 0;
  HaltParamErr = 1;
  HaltReadErr = 2;
  HaltWriteErr = 3;

  ProgName = 'fpcreslipo';
  ProgVersion = '1.0';

  FPCVersion = {$INCLUDE %FPCVERSION%};
  HostArch = {$INCLUDE %FPCTARGETCPU%};
  HostOS = {$INCLUDE %FPCTARGETOS%};
  BuildDate = {$INCLUDE %DATE%};

var
  Params : TParameters = nil;
  SourceFiles : TSourceFiles = nil;
  OutResources : TResources = nil;

procedure ShowVersion;
begin
  WriteLn(ProgName+' - external resource file thinner, version '+ProgVersion+' ['+BuildDate+'], FPC '+FPCVersion);
  WriteLn('Host platform: '+HostOS+' - '+HostArch);
  WriteLn('Copyright (c) 2008 by Giulio Bernardi.');
end;

procedure ShowHelp;
begin
  ShowVersion;
  WriteLn('Syntax: '+ProgName+' [options] <inputfile> [<inputfile>...] -o <outputfile>');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --help, -h, -?     Show this screen.');
  WriteLn('  --version, -V      Show program version.');
  WriteLn('  --verbose, -v      Be verbose.');
  WriteLn('  --output, -o <x>   Set the output file name.');
  WriteLn('  --endian, -e <x>   Set shared file endianess (big, little)');
  WriteLn('                       default is big');
  WriteLn;
  WriteLn('Example:');
  WriteLn('  '+ProgName+' myprog.i386.fpcres myprog.powerpc.fpcres -o myprog.fpcres');
  WriteLn;
  WriteLn('  strips common resources from the two input files and puts them in the');
  WriteLn('  output file');
end;

const
  SOutputFileAlreadySet = 'Output file name already set.';
  SUnknownParameter = 'Unknown parameter ''%s''';
  SArgumentMissing = 'Argument missing for option ''%s''';
  SUnknownEndianess = 'Unknown endianess ''%s''';
  SNoInputFiles = 'No input files';
  STooFewInputFiles = 'At least two input files must be specified';
  SNoOutputFile = 'No output file name specified';
  SCantOpenFile = 'Can''t open file ''%s''';
  SUnknownInputFormat = 'No known file format detected for file ''%s''';
  SCantCreateFile = 'Can''t create file ''%s''';

function GetCurrentTimeMsec : LongInt;
var H,M,S,MS : Word;
begin
  DecodeTime(Time,H,M,S,MS);
  Result:=H*3600*1000 + M*60*1000 + S*1000 + MS;
end;

procedure CheckInputFiles;
begin
  if Params.InputFiles.Count<2 then
  begin
    case Params.InputFiles.Count of
      0 : Messages.DoError(SNoInputFiles);
      1 : Messages.DoError(STooFewInputFiles);
    end;
    Halt(HaltParamErr);
  end;
end;

procedure CheckOutputFile;
begin
  if Params.OutputFile<>'' then exit;
  Messages.DoError(SNoOutputFile);
  Halt(HaltParamErr);
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
    on E : EUnknownEndianessException do Msg:=Format(SUnknownEndianess,[E.Message]);
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
    I : Integer;
begin
  Msg:='';
  SourceFiles:=TSourceFiles.Create;
  try
    for I:=0 to Params.InputFiles.Count-1 do
      SourceFiles.NewSourceFile(Params.InputFiles[I]);
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

procedure ProcessFiles;
begin
  Messages.DoVerbose('processing input files...');
  OutResources:=TResources.Create;
  SourceFiles.Process(OutResources);
  Messages.DoVerbose('input files processed.');
end;

function WriteOutputFile : Boolean;
var AStream : TFileStream;
    AWriter : TExternalResourceWriter;
    Msg : string;
begin
  if OutResources.Count=0 then
  begin
    Result:=False;
    Messages.DoVerbose('Nothing to do');
    exit;
  end;
  Result:=True;
  Messages.DoVerbose(Format('Trying to create file %s...',[Params.OutputFile]));
  try
    AStream:=TFileStream.Create(Params.OutputFile,fmCreate or fmShareDenyWrite);
  except
    Messages.DoError(Format(SCantCreateFile,[Params.OutputFile]));
    Halt(HaltWriteErr);
  end;
  try
    AWriter:=TExternalResourceWriter.Create;
    AWriter.Endianess:=Params.Endianess;
    try
      try
        OutResources.WriteToStream(AStream,AWriter);
      except
        on E : Exception do
        begin
          if E.Message='' then Msg:=E.ClassName
          else Msg:=E.Message;
          Messages.DoError(Msg);
          Halt(HaltWriteErr);
        end;
      end;
      Messages.DoVerbose(Format('%d resources written.',[OutResources.Count]));
      Messages.DoVerbose(Format('File %s written',[Params.OutputFile]));
    finally
      AWriter.Free;
    end;
  finally
    AStream.Free;
  end;
  FreeAndNil(OutResources);
end;

procedure UpdateFiles;
var Msg : string;
begin
  try
    SourceFiles.Update;
  except
    on E : ECantCreateFileException do Msg:=Format(SCantCreateFile,[E.Message]);
    on E : Exception do
    begin
      if E.Message='' then Msg:=E.ClassName
      else Msg:=E.Message;
    end;
  end;
  if Msg<>'' then
  begin
    Messages.DoError(Msg);
    Halt(HaltWriteErr);
  end;
end;

procedure Cleanup;
begin
  Messages.DoVerbose('Cleaning up');
  if OutResources<>nil then OutResources.Free;
  if SourceFiles<>nil then SourceFiles.Free;
  if Params<>nil then Params.Free;
end;

var Before, Elapsed : LongInt;

begin
  try
    Before:=GetCurrentTimeMsec;
    ParseParams;
    LoadSourceFiles;
    ProcessFiles;
    if WriteOutputFile then
      UpdateFiles;
    Elapsed:=GetCurrentTimeMsec-Before;
    if Elapsed<0 then Elapsed:=24*3600*1000 + Elapsed;
    Messages.DoVerbose(Format('Time elapsed: %d.%d seconds',[Elapsed div 1000,(Elapsed mod 1000) div 10]));
  finally
    Cleanup;
  end;
end.
