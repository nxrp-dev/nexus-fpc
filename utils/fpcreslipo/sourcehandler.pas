{

    FPCResLipo - Free Pascal External Resource Thinner
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
  Classes, SysUtils, Resource, ExternalReader, ExternalWriter;

type
  ESourceFilesException = class(Exception);
  ECantOpenFileException = class(ESourceFilesException);
  EUnknownInputFormatException = class(ESourceFilesException);
  ECantCreateFileException = class(ESourceFilesException);

type

  { TSourceFile }

  TSourceFile = class
  private
    FFileName : string;
    FStream : TStream;
    FResources : TResources;
    FProcessed : TResources;
    FEndianess : Byte;
    FModified : Boolean;
    function Delete : Boolean;
  protected
  public
    constructor Create(AFileName : string);
    destructor Destroy; override;
    procedure Update;
    property FileName : string Read FFileName;
    property Resources : TResources Read FResources;
    property Processed : TResources Read FProcessed;
    property Endianess : Byte Read FEndianess;
    property Modified : Boolean Read FModified Write FModified;
  end;

  { TSourceFiles }

  TSourceFiles = class
  private
    Similarities, SimCount : array of Integer;
    FList : TFPList;
    function GetItem(Index : Integer) : TSourceFile;
    function GetCount : Integer;
    procedure ResetSimArrays;
    function GetMostCommon : Integer;
    procedure CheckSimilarities(Idx : Integer; AType,AName : TResourceDesc; ALangID : TLangID);
    procedure ExtractCommon(Idx : Integer; OutRes : TResources; AType,AName : TResourceDesc; ALangID : TLangID);
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure NewSourceFile(AFileName : string);
    procedure Process(OutRes : TResources);
    procedure Update;
    property Items[Index : Integer] : TSourceFile Read GetItem;
    property Count : Integer Read GetCount;
  end;

implementation

uses MsgHandler;

{ TSourceFile }

function TSourceFile.Delete : Boolean;
begin
  FreeAndNil(FResources);
  FreeAndNil(FStream);
  Result:=DeleteFile(FFileName);
  if not Result then
    Messages.DoError(Format('Can''t delete file %s.',[FFileName]))
end;

constructor TSourceFile.Create(AFileName: string);
var AReader : TExternalResourceReader;
begin
  FModified:=False;
  FFileName:=AFileName;
  Messages.DoVerbose(Format('Trying to open file %s...',[FFileName]));
  try
    FStream:=TFileStream.Create(FFileName,fmOpenRead or fmShareDenyWrite);
  except
    raise ECantOpenFileException.Create(FFileName);
  end;
  AReader:=TExternalResourceReader.Create;
  FResources:=TResources.Create;
  try
    try
      try
        Messages.DoVerbose('Reading resource information...');
        FResources.LoadFromStream(FStream,AReader);
        Messages.DoVerbose(Format('%d resources read.',[FResources.Count]));
        FEndianess:=AReader.Endianess;
      except
        on E : EResourceReaderWrongFormatException do
          raise EUnknownInputFormatException.Create(FFileName);
      end;
    except
      FreeAndNil(FResources);
      FreeAndNil(FStream);
    end;
  finally
    AReader.Free;
  end;
  FProcessed:=TResources.Create;
end;

destructor TSourceFile.Destroy;
begin
  if FResources<>nil then FResources.Free;
  if FProcessed<>nil then FProcessed.Free;
  if FStream<>nil then FStream.Free;
end;

procedure TSourceFile.Update;
var Tmp : string;
    AWriter : TExternalResourceWriter;
    AStream : TFileStream;
begin
  if not FModified then
  begin
    Messages.DoVerbose(Format('File %s is unchanged.',[FFileName]));
    exit;
  end;
  if Resources.Count=0 then
  begin
    if Delete then
      Messages.DoVerbose(Format('No more resources in file %s, deleted',[FFileName]));
    exit;
  end;

  Tmp:=ExtractFileDir(FFileName);
  if Tmp='' then Tmp:='.';
  Tmp:=GetTempFileName(Tmp,'tmp');

  Messages.DoVerbose(Format('Updating file %s...',[FFileName]));
  try
    AStream:=TFileStream.Create(Tmp,fmCreate or fmShareDenyWrite);
  except
    raise ECantCreateFileException.Create(Tmp);
  end;
  try
    AWriter:=TExternalResourceWriter.Create;
    AWriter.Endianess:=Endianess;
    try
      Resources.WriteToStream(AStream,AWriter);
      Messages.DoVerbose(Format('%d resources written.',[Resources.Count]));
    finally
      AWriter.Free;
    end;
  finally
    AStream.Free;
  end;

  if not Delete then exit;
  if not RenameFile(Tmp,FFileName) then
    Messages.DoError(Format('Can''t rename file %s to %s.',[Tmp,FFileName]))
  else
    Messages.DoVerbose(Format('File %s updated',[FFileName]));
end;

{ TSourceFiles }

function TSourceFiles.GetItem(Index : Integer) : TSourceFile;
begin
  Result:=TSourceFile(FList[Index]);
end;

function TSourceFiles.GetCount: Integer;
begin
  Result:=FList.Count;
end;

procedure TSourceFiles.ResetSimArrays;
var I : Integer;
begin
  for I:=0 to Count-1 do
  begin
    Similarities[I]:=I;
    SimCount[I]:=1;
  end;
end;

function TSourceFiles.GetMostCommon: Integer;
var I : Integer;
    Max, MaxIdx : Integer;
begin
  Max:=0;
  MaxIdx:=0;
  for I:=0 to Count-1 do
    if SimCount[I]>Max then
    begin
      Max:=SimCount[I];
      MaxIdx:=I;
    end;
  Result:=MaxIdx;
end;

procedure TSourceFiles.CheckSimilarities(Idx: Integer; AType,
  AName: TResourceDesc; ALangID: TLangID);
var I,J : Integer;
    Res1, Res2 : TAbstractResource;
begin
  for I:=Idx to Count-1 do
  begin
    if Similarities[I]<>I then continue;
    try
      Res1:=Items[I].Resources.Find(AType,AName,ALangID);
    except
      on E : EResourceNotFoundException do continue;
    end;
    for J:=Idx+1 to Count-1 do
    begin
      try
        Res2:=Items[J].Resources.Find(AType,AName,ALangID);
      except
        on E : EResourceNotFoundException do continue;
      end;
      if Res1.CompareContents(Res2) then
      begin
        Dec(SimCount[Similarities[J]]);
        Inc(SimCount[Similarities[I]]);
        Similarities[J]:=Similarities[I];
      end;
    end;
  end;
end;

procedure TSourceFiles.ExtractCommon(Idx: Integer; OutRes: TResources; AType,
  AName: TResourceDesc; ALangID: TLangID);
var MaxIdx,I : Integer;
    Res : TAbstractResource;
begin
  MaxIdx:=GetMostCommon;
  if SimCount[MaxIdx]<=1 then
  begin
    for I:=Idx to Count-1 do
    begin
      try
        Res:=Items[I].Resources.Remove(AType,AName,ALangID);
      except
        on E : EResourceNotFoundException do continue;
      end;
      Items[I].Processed.Add(Res);
    end;
    exit;
  end;

  Res:=Items[MaxIdx].Resources.Remove(AType,AName,ALangID);
  Items[MaxIdx].Modified:=True;
  OutRes.Add(Res);
  for I:=Idx to Count-1 do
  begin
    if I=MaxIdx then continue;
    try
      Res:=Items[I].Resources.Remove(AType,AName,ALangID);
    except
      on E : EResourceNotFoundException do continue;
    end;
    if Similarities[I]=Similarities[MaxIdx] then
    begin
      Res.Free;
      Items[I].Modified:=True;
    end
    else
      Items[I].Processed.Add(Res);
  end;
end;

constructor TSourceFiles.Create;
begin
  FList:=TFPList.Create;
end;

destructor TSourceFiles.Destroy;
var I : Integer;
begin
  for I:=0 to FList.Count-1 do
    TSourceFile(FList[I]).Free;
  FList.Free;
end;

procedure TSourceFiles.NewSourceFile(AFileName : string);
var AFile : TSourceFile;
begin
  AFile:=TSourceFile.Create(AFileName);
  FList.Add(AFile);
end;

procedure TSourceFiles.Process(OutRes: TResources);
var I : Integer;
    Res : TAbstractResource;
begin
  SetLength(Similarities,Count);
  SetLength(SimCount,Count);
  for I:=0 to Count-1 do
  begin
    while Items[I].Resources.Count>0 do
    begin
      ResetSimArrays;
      Res:=Items[I].Resources[Items[I].Resources.Count-1];
      if Res.Owner<>nil then
        Res:=Res.Owner;

      CheckSimilarities(I,Res._Type,Res.Name,Res.LangID);
      ExtractCommon(I,OutRes,Res._Type,Res.Name,Res.LangID);
    end;
    Items[I].Resources.MoveFrom(Items[I].Processed);
  end;
end;

procedure TSourceFiles.Update;
var I : Integer;
begin
  for I:=0 to Count-1 do
    Items[I].Update;
end;

end.

