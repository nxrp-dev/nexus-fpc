{

    FPCResLipo - Free Pascal External Resource Thinner
    Part of the Free Pascal distribution
    Copyright (C) 2008 by Giulio Bernardi

    Output messages handler

    See the file COPYING, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit MsgHandler;

{$MODE OBJFPC}

interface

uses
  Classes, SysUtils;

type

  { TMessages }

  TMessages = class
  private
    FVerboseSet : Boolean;
    FVerbose : Boolean;
    FVerbCache : TStringList;
    FStdOut : Text;
    FStdErr : Text;
    procedure SetVerbose(const AValue : Boolean);
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure DoError(const AMsg : string);
    procedure DoVerbose(const AMsg : string);
    property Verbose : Boolean Read FVerbose Write SetVerbose;
  end;

var Messages : TMessages;

implementation

{ TMessages }

procedure TMessages.SetVerbose(const AValue: Boolean);
var I : Integer;
begin
  FVerbose:=AValue;
  if FVerboseSet then exit;

  FVerboseSet:=True;
  if FVerbose then //output all verbose messages we didn't output before
    for I:=0 to FVerbCache.Count-1 do
      WriteLn(FStdOut,'Debug: '+FVerbCache[I]);

  FreeAndNil(FVerbCache);
end;

constructor TMessages.Create;
begin
  FVerbose:=False;
  FVerboseSet:=False;
  FVerbCache:=TStringList.Create;
  FStdOut:=StdOut;
  FStdErr:=StdErr;
end;

destructor TMessages.Destroy;
begin
  if FVerbCache<>nil then
    FVerbCache.Free;
end;

procedure TMessages.DoError(const AMsg: string);
begin
  WriteLn(FStdErr,'Error: '+AMsg);
end;

procedure TMessages.DoVerbose(const AMsg: string);
begin
  if not FVerboseSet then
  begin
    FVerbCache.Add(AMsg);
    exit;
  end;
  if FVerbose then
    WriteLn(FStdOut,'Debug: '+AMsg);
end;

initialization
  Messages:=TMessages.Create;


finalization
  Messages.Free;

end.
