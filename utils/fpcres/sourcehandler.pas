{

    FPCRes - Free Pascal Resource Converter
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    Source files handling

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit SourceHandler;

{$MODE OBJFPC} {$H+}

interface

uses
  Classes, SysUtils, Resource;

type
  ESourceFilesException = class(Exception);
  ECantOpenFileException = class(ESourceFilesException);
  EUnknownInputFormatException = class(ESourceFilesException);

type

  { TSourceFiles }

  TSourceFiles = class
  private
  protected
    FFileList : TStringList;
    FRCIncludeDirs: TStringList;
    FRCDefines: TStringList;
    FStreamList : TFPList;
    FRCMode: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(AResources : TResources);
    property FileList : TStringList Read FFileList;
    property RCIncludeDirs: TStringList Read FRCIncludeDirs;
    property RCDefines: TStringList Read FRCDefines;
    property RCMode: Boolean Read FRCMode Write FRCMode;
  end;

implementation

uses MsgHandler, ClosableFileStream, RCReader;

{ TSourceFiles }

constructor TSourceFiles.Create;
begin
  inherited Create;
  FFileList:=TStringList.Create;
  FStreamList:=TFPList.Create;
  FRCDefines:= TStringList.Create;
  FRCIncludeDirs:= TStringList.Create;
  FRCMode:=False;
end;

destructor TSourceFiles.Destroy;
var I : Integer;
begin
  FRCIncludeDirs.Free;
  FRCDefines.Free;
  FFileList.Free;
  for I:=0 to FStreamList.Count-1 do
    TStream(FStreamList[I]).Free;
  FStreamList.Free;
  inherited;
end;

procedure TSourceFiles.Load(AResources: TResources);
var AReader : TAbstractResourceReader;
    AStream : TClosableFileStream;
    I : Integer;
    TmpRes : TResources;
    OldDir : String;
begin
  OldDir:=GetCurrentDir;
  TmpRes:=TResources.Create;
  try
    for I:=0 to FFileList.Count-1 do
    begin
      Messages.DoVerbose(Format('Trying to open file %s...',[FFileList[I]]));
      try
        AStream:=TClosableFileStream.Create(FFileList[I],fmOpenRead or fmShareDenyWrite);
      except
        raise ECantOpenFileException.Create(FFileList[I]);
      end;
      FStreamList.Add(AStream);
      { the RC reader reads anything, so handle that separately }
      if FRCMode then
        AReader:=TRCResourceReader.Create
      else
        try
          AReader:=TResources.FindReader(AStream);
        except
          raise EUnknownInputFormatException.Create(FFileList[I]);
        end;
      Messages.DoVerbose(Format('Chosen reader: %s',[AReader.Description]));
      try
        Messages.DoVerbose('Reading resource information...');
        if AReader is TRCResourceReader then begin
          TRCResourceReader(AReader).RCIncludeDirs.Assign(FRCIncludeDirs);
          TRCResourceReader(AReader).RCDefines.Assign(FRCDefines);
          SetCurrentDir(ExtractFilePath(ExpandFileName(FFileList[I])));
        end;
        try
          TmpRes.LoadFromStream(AStream,AReader);
        except
           on E :EParserError do
              begin
                E.Message:=FFileList[I]+': '+E.Message;
              raise;
            end;
        end;
        AResources.MoveFrom(TmpRes);
        Messages.DoVerbose('Resource information read');
      finally
        if AReader is TRCResourceReader then begin
          SetCurrentDir(OldDir);
        end;
        AReader.Free;
      end;
    end;
    Messages.DoVerbose(Format('%d resources read.',[AResources.Count]));
  finally
    TmpRes.Free;
  end;
end;

end.

