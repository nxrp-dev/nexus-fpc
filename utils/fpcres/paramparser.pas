{

    FPCRes - Free Pascal Resource Converter
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
  Classes, SysUtils, Target;

type
  EParametersException = class(Exception);
  EOutputFileAlreadySetException = class(EParametersException);
  EUnknownParameterException = class(EParametersException);
  EArgumentMissingException = class(EParametersException);
  EUnknownObjFormatException = class(EParametersException);
  EUnknownMachineException = class(EParametersException);
  EUnknownSubMachineException = class(EParametersException);
  ECannotReadConfFile = class(EParametersException);

type

  { TParameters }

  TParameters = class
  private
    FHelp : Boolean;
    FVersion : Boolean;
    FVerbose : Boolean;
    FInputFiles : TStringList;
    FOutputFile : string;
    FTarget : TResTarget;
    FRCIncludeDirs: TStringList;
    FRCDefines: TStringList;

    procedure ParseInputFiles(AList : TStringList; var Index : Integer; const ParName : string);
    procedure ParseRCInclude(AList: TStringList; var Index: Integer; const ParName: string);
    procedure ParseRCUndefine(AList: TStringList; var Index: Integer; const ParName: string);
    procedure ParseOutputFile(AList : TStringList; var Index : Integer; const ParName : string);
    procedure ParseOutputFormat(AList : TStringList; var Index : Integer; const ParName : string);virtual;
    procedure ParseArchitecture(AList : TStringList; var Index : Integer; const ParName : string);virtual;
    procedure ParseSubArchitecture(AList : TStringList; var Index : Integer; const ParName : string);virtual;
    procedure ParseConfigFile(AList : TStringList; var Index : Integer; const ParName : string);
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
    property RCIncludeDirs: TStringList Read FRCIncludeDirs;
    property RCDefines: TStringList Read FRCDefines;
    property OutputFile : string Read FOutputFile Write FOutputFile;
    property Target : TResTarget Read FTarget;
  end;

implementation

uses
  MsgHandler;

type

  { TConfFileParser }

  TConfFileParser = class
  private
    FConfFile : TStringList;
    FParList : TStringList;
    FInsPos : Integer;

    procedure ParseLine(Idx : Integer);
    function GetParameter(PC : PChar; var I : Integer) : string;
    function GetString(PC : PChar; var I : Integer) : string;
  protected
  public
    constructor Create(AFileName : string; AParList : TStringList; AInsPos : Integer);
    procedure Parse;
    destructor Destroy; override;
  end;

{ TConfFileParser }

procedure TConfFileParser.ParseLine(Idx: Integer);
var PC : PChar;
    Tmp : string;
    I : Integer;
begin
  PC:=PChar(FConfFile[Idx]);
  I:=0;
  while PC[I]<>#0 do
  begin
    case PC[I] of
      ' ',#9,#13,#10 : Inc(I);
      '#' : break
    else
      begin
        Tmp:=GetParameter(PC,I);
        if Tmp<>'' then
        begin
          FParList.Insert(FInsPos,Tmp);
          Inc(FInsPos);
        end;
      end;
    end;
  end;
end;

function TConfFileParser.GetParameter(PC : PChar; var I : Integer): string;
begin
  Result:='';
  while PC[I]<>#0 do
  begin
    case PC[I] of
      ' ',#9,#13,#10 : exit;
      '#' : exit;
      '"' : Result:=Result+GetString(PC,I);
      else
        Result:=Result+PC[I];
    end;
    Inc(I);
  end;
end;

function TConfFileParser.GetString(PC: PChar; var I: Integer): string;
begin
  Result:='';
  Inc(I);
  while PC[I]<>#0 do
  begin
    if PC[I] = '"' then
      exit
    else
      Result:=Result+PC[I];
    Inc(I);
  end;
  Dec(I);
end;

constructor TConfFileParser.Create(AFileName: string; AParList: TStringList; AInsPos : Integer);
begin
  FInsPos:=AInsPos+1;
  FConfFile:=TStringList.Create;
  FParList:=AParList;
  try
    FConfFile.LoadFromFile(AFileName);
  except
    raise ECannotReadConfFile.Create(AFileName);
  end;
end;

procedure TConfFileParser.Parse;
var I : Integer;
begin
  for I:=0 to FConfFile.Count-1 do
    ParseLine(I);
end;

destructor TConfFileParser.Destroy;
begin
  FConfFile.Free;
end;

{ TParameters }

//for compatibility allow -i <inputfiles>
procedure TParameters.ParseInputFiles(AList: TStringList; var Index: Integer;
  const ParName : string);
var Tmp : string;
begin
  Tmp:=DoMandatoryArgument(AList,Index+1);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);

  while Tmp<>'' do
  begin
    Inc(Index);
    FInputFiles.Add(Tmp);
    Tmp:=DoOptionalArgument(AList,Index+1);
  end;
end;

procedure TParameters.ParseRCInclude(AList: TStringList; var Index: Integer;
  const ParName : string);
var
  Tmp: String;
begin
  Inc(Index);
  Tmp:=DoMandatoryArgument(AList,Index);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);
  FRCIncludeDirs.Add(Tmp);
end;

procedure TParameters.ParseRCUndefine(AList: TStringList; var Index: Integer;
  const ParName : string);
var
  Tmp: String;
  I: Integer;
begin
  Inc(Index);
  Tmp:=DoMandatoryArgument(AList,Index);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);
  if (ParName='-D') or (ParName='--define') then begin
    I:= Pos('=', Tmp);
    if I<1 then
      FRCDefines.Values[Tmp]:= ''
    else
      FRCDefines.Values[Copy(Tmp, 1, I-1)]:= Copy(Tmp, I+1);
  end else begin
    I:= FRCDefines.IndexOfName(Tmp);
    if I >= 0 then
      FRCDefines.Delete(I);
  end;
  FRCIncludeDirs.Add(Tmp);
end;

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

procedure TParameters.ParseOutputFormat(AList: TStringList; var Index: Integer;
  const ParName: string);
var Tmp : string;
    AFormat : TObjFormat;
begin
  Inc(Index);
  Tmp:=DoMandatoryArgument(AList,Index);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);

  for AFormat:=Low(TObjFormat) to High(TObjFormat) do
  begin
    if ObjFormats[AFormat].Name=Tmp then
    begin
      FTarget.ObjFormat:=AFormat;
      exit;
    end;
  end;

  raise EUnknownObjFormatException.Create(Tmp);

end;

procedure TParameters.ParseArchitecture(AList: TStringList; var Index: Integer;
  const ParName: string);
var Tmp : string;
    AMachine : TMachineType;
begin
  Inc(Index);
  Tmp:=DoMandatoryArgument(AList,Index);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);

  for AMachine:=Low(TMachineType) to High(TMachineType) do
  begin
    if (Machines[AMachine].Name=Tmp) or (Machines[AMachine].Alias = Tmp) then
    begin
      FTarget.Machine:=AMachine;
      FTarget.SubMachine:=GetDefaultSubMachineForMachine(FTarget.Machine);
      exit;
    end;
  end;

  raise EUnknownMachineException.Create(Tmp);

end;

procedure TParameters.ParseSubArchitecture(AList: TStringList; var Index: Integer; const ParName: string);
var Tmp : string;
    ASubMachineArm : TSubMachineTypeArm;
    ASubMachineGeneric : TSubMachineTypeGeneric;
begin
  Inc(Index);
  Tmp:=DoMandatoryArgument(AList,Index);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);

  case FTarget.Machine of
    mtARM,mtARMEB:
      for ASubMachineArm:=Low(TSubMachineTypeArm) to High(TSubMachineTypeArm) do
        if SubMachinesArm[ASubMachineArm]=Tmp then
          begin
            FTarget.SubMachine.SubArm:=ASubMachineArm;
            exit;
          end;
    else
      for ASubMachineGeneric:=Low(TSubMachineTypeGeneric) to High(TSubMachineTypeGeneric) do
        if SubMachinesGen[ASubMachineGeneric]=Tmp then
          begin
            FTarget.SubMachine.SubGen:=ASubMachineGeneric;
            exit;
          end;
  end;

  raise EUnknownSubMachineException.Create(Tmp);

end;

procedure TParameters.ParseConfigFile(AList: TStringList; var Index: Integer;
  const ParName : string);
var Tmp : string;
    CP : TConfFileParser;
begin
  Tmp:=Copy(ParName,2,Length(ParName)-1);
  if Tmp='' then
    raise EArgumentMissingException.Create(ParName);
  CP:=TConfFileParser.Create(Tmp,AList,Index);
  try
    CP.Parse;
  finally
    CP.Free;
  end;
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
        else if ((Tmp='-i') or (Tmp='--input')) then
          ParseInputFiles(FList,I,Tmp)
        else if ((Tmp='-I') or (Tmp='--include')) then
          ParseRCInclude(FList,I,Tmp)
        else if ((Tmp='-D') or (Tmp='--define'))
             or ((Tmp='-U') or (Tmp='--undefine')) then
          ParseRCUndefine(FList,I,Tmp)
        else if ((Tmp='-o') or (Tmp='--output')) then
          ParseOutputFile(FList,I,Tmp)
        else if (Tmp='-of') then
          ParseOutputFormat(FList,I,Tmp)
        else if ((Tmp='-a') or (Tmp='--arch')) then
          ParseArchitecture(FList,I,Tmp)
        else if ((Tmp='-s') or (Tmp='--subarch')) then
          ParseSubArchitecture(FList,I,Tmp)
        else
          raise EUnknownParameterException.Create(Tmp);
      end
      else
        if Copy(Tmp,1,1)='@' then
          ParseConfigFile(FList,I,Tmp)
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
  inherited Create;
  FHelp:=False;
  FVersion:=False;
  FVerbose:=False;
  FInputFiles:=TStringList.Create;
  FRCIncludeDirs:= TStringList.Create;
  FRCIncludeDirs.Duplicates:= dupIgnore;
  FRCDefines:= TStringList.Create;
  FOutputFile:='';
  FTarget.Machine:=mtNone;
  GetDefaultSubMachineForMachine(FTarget.Machine);
  FTarget.ObjFormat:=ofNone;
end;

destructor TParameters.Destroy;
begin
  FRCDefines.Free;
  FRCIncludeDirs.Free;
  FInputFiles.Free;
  inherited;
end;

end.
