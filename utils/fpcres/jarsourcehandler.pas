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

unit JarSourceHandler;

{$MODE OBJFPC} {$H+}

interface

uses
  Classes, SysUtils, SourceHandler, Zipper;

const
  ResBaseDir = 'org'+DirectorySeparator+'freepascal'+DirectorySeparator+'rawresources'+DirectorySeparator;

type
  ESourceFilesException = class(Exception);
  ECantOpenFileException = class(ESourceFilesException);
  EUnknownInputFormatException = class(ESourceFilesException);

type

  { TSourceFiles }

  TJarSourceFiles = class(TSourceFiles)
  private
  protected
  public
    procedure Load(AResources : TZipper);reintroduce;
  end;

implementation

uses MsgHandler, ClosableFileStream;

{ TJarSourceFiles }

procedure TJarSourceFiles.Load(AResources: TZipper);
var AStream : TClosableFileStream;
    I : Integer;
begin
  if FFileList.Count<>0 then
    begin
      AResources.Entries.AddFileEntry('org/');
      AResources.Entries.AddFileEntry('org/freepascal/');
      AResources.Entries.AddFileEntry(ResBaseDir);
    end;
  try
    for I:=0 to FFileList.Count-1 do
    begin
      Messages.DoVerbose(Format('Trying to open file %s...',[FFileList[I]]));
      try
        AStream:=TClosableFileStream.Create(FFileList[I],fmOpenRead or fmShareDenyWrite);
      except
        raise ECantOpenFileException.Create(FFileList[I]);
      end;
      AStream.Free;
      AResources.Entries.AddFileEntry(FFileList[I],ResBaseDir+FFileList[I]);
    end;
    Messages.DoVerbose(Format('%d resources read.',[AResources.Entries.Count]));
  finally
  end;
end;

end.

