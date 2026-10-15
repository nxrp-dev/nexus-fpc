{

    FPCResLipo - Free Pascal External Resource Thinner
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    Handles the parsing of parameters

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit ParamParser;

{$MODE OBJFPC} {$H+}

interface

uses
  Classes, SysUtils, ExternalTypes;

type
  EParametersException = class(Exception);
  EOutputFileAlreadySetException = class(EParametersException);
  EUnknownParameterException = class(EParametersException);
  EArgumentMissingException = class(EParametersException);
  EUnknownEndianessException = class(EParametersException);

type

  { TParameters }

  TParameters = class
  private
    FHelp : Boolean;
    FVersion : Boolean;
    FVerbose : Boolean;
    FInputFiles : TStringList;
    FOutputFile : string;
    FEndianess : Byte;

    procedure ParseOutputFile(AList : TStringList; var Index : Integer; const ParName : string);
    procedure ParseEndianess(AList : TStringList; var Index : Integer; const ParName : string);
    function DoOptionalArgument(AList : TStringList; const I : Integer) : string;
    function DoMandatoryArgument(AList : TStringList; const I : Integer) : string;
    function IsParameter(const S : string) : Boolean;
    function ParamsToStrList : TStringList;
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure Parse;
    property Help : Boolean Read FHelp;
    property Version : Boolean Read FVersion;
    property Verbose : Boolean Read FVerbose;
    property InputFiles : TStringList Read FInputFiles;
    property OutputFile : string Read FOutputFile Write FOutputFile;
    property Endianess : Byte Read FEndianess Write FEndianess;
  end;

implementation

uses
  MsgHandler;

{ TParameters }

procedure TParameters.ParseOutputFile(AList: TStringList; var Index: Integer;
  const ParName : string);
begin
  if FOutputFile<>'' then
    raise EOutputFileAlreadySetException.Create('');
  Inc(Index);
  FOutputFile:=DoMandatoryArgument(AList,Index);
  if FOutputFile='' then
    raise EArgumentMissingException.Create(ParName);
end;

procedure TParameters.ParseEndianess(AList: TStringList; var Index: Integer;
  const ParName: string);
var Tmp : string;
begin
  Inc(Index);
  Tmp:=LowerCase(DoMandatoryArgument(AList,Index));
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);

  if Tmp='big' then FEndianess:=ExtEndianBig
  else if Tmp='little' then FEndianess:=ExtEndianLittle
  else raise EUnknownEndianessException.Create(Tmp);
end;

function TParameters.DoOptionalArgument(AList: TStringList; const I: Integer
  ): string;
begin
  Result:='';
  if AList.Count>I then
  begin
    if not IsParameter(AList[I]) then
      Result:=AList[I];
  end;
end;

function TParameters.DoMandatoryArgument(AList: TStringList; const I: Integer
  ): string;
begin
  Result:='';
  if AList.Count>I then
    Result:=AList[I];
end;

function TParameters.IsParameter(const S: string): Boolean;
begin
  Result:=False;
  if Length(S)<=1 then exit;
  if Copy(S,1,1)='-' then Result:=True;
end;

function TParameters.ParamsToStrList: TStringList;
var I : Integer;
begin
  Result:=TStringList.Create;
  try
    for I:=1 to ParamCount do
      Result.Add(ParamStr(I));
  except
    Result.Free;
    raise;
  end;
end;

procedure TParameters.Parse;
var FList : TStringList;
    Tmp : string;
    I : Integer;
begin
  FList:=ParamsToStrList;
  try
    I:=0;
    while I<FList.Count do
    begin
      Tmp:=FList[I];
      Messages.DoVerbose(Format('parsing parameter ''%s''',[Tmp]));
      if IsParameter(Tmp) then
      begin
        if ((Tmp='--help') or (Tmp='-h') or (Tmp='-?')) then
          FHelp:=True
        else if ((Tmp='--version') or (Tmp='-V')) then
          FVersion:=True
        else if ((Tmp='--verbose') or (Tmp='-v')) then
          FVerbose:=True
        else if ((Tmp='-o') or (Tmp='--output')) then
          ParseOutputFile(FList,I,Tmp)
        else if ((Tmp='-e') or (Tmp='--endian')) then
          ParseEndianess(FList,I,Tmp)
        else
          raise EUnknownParameterException.Create(Tmp);
      end
      else
        FInputFiles.Add(Tmp); //assume it is an input file
      Inc(I);
    end;
  finally
    FList.Free;
  end;
end;

constructor TParameters.Create;
begin
  FHelp:=False;
  FVersion:=False;
  FVerbose:=False;
  FInputFiles:=TStringList.Create;
  FOutputFile:='';
  FEndianess:=ExtEndianBig;
end;

destructor TParameters.Destroy;
begin
  FInputFiles.Free;
end;

end.
