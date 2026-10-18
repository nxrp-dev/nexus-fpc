{ Keep ordinary object VMTs and class message tables when retiring WITHDMT. }
program RetiredDMTNative;
{$mode objfpc}{$H+}

type
  PBaseObject = ^TBaseObject;
  TBaseObject = object
    constructor Init;
    function Value: LongInt; virtual;
    destructor Done; virtual;
  end;
  TChildObject = object(TBaseObject)
    function Value: LongInt; virtual;
  end;

  TIntMessage = record
    ID: LongWord;
    Value: LongInt;
  end;
  TStringMessage = record
    ID: ShortString;
    Value: LongInt;
  end;

  TBaseClass = class
  protected
    procedure IntegerMessage(var AMessage: TIntMessage); message 100;
    procedure InheritedMessage(var AMessage: TIntMessage); message 101;
    procedure StringMessage(var AMessage: TStringMessage); message 'value';
  public
    function Value: LongInt; virtual;
    function DynamicValue: LongInt; dynamic;
  end;
  TChildClass = class(TBaseClass)
  protected
    procedure ChildIntegerMessage(var AMessage: TIntMessage); message 100;
  public
    function Value: LongInt; override;
    function DynamicValue: LongInt; override;
  end;

constructor TBaseObject.Init;
begin
end;

function TBaseObject.Value: LongInt;
begin
  Result := 11;
end;

destructor TBaseObject.Done;
begin
end;

function TChildObject.Value: LongInt;
begin
  Result := 29;
end;

procedure TBaseClass.IntegerMessage(var AMessage: TIntMessage);
begin
  AMessage.Value := 31;
end;

procedure TBaseClass.InheritedMessage(var AMessage: TIntMessage);
begin
  AMessage.Value := 71;
end;

procedure TBaseClass.StringMessage(var AMessage: TStringMessage);
begin
  AMessage.Value := 83;
end;

function TBaseClass.Value: LongInt;
begin
  Result := 37;
end;

function TBaseClass.DynamicValue: LongInt;
begin
  Result := 41;
end;

procedure TChildClass.ChildIntegerMessage(var AMessage: TIntMessage);
begin
  AMessage.Value := 61;
end;

function TChildClass.Value: LongInt;
begin
  Result := 43;
end;

function TChildClass.DynamicValue: LongInt;
begin
  Result := 47;
end;

procedure Run;
var
  lBaseObject: TBaseObject;
  lChildObject: TChildObject;
  lObject: PBaseObject;
  lClass: TBaseClass;
  lIntegerMessage: TIntMessage;
  lStringMessage: TStringMessage;
begin
  lBaseObject.Init;
  lChildObject.Init;
  lObject := @lBaseObject;
  if lObject^.Value <> 11 then
    Halt(1);
  lObject := @lChildObject;
  if lObject^.Value <> 29 then
    Halt(2);
  lObject^.Done;
  lBaseObject.Done;

  lClass := TBaseClass.Create;
  try
    if lClass.Value <> 37 then
      Halt(3);
    if lClass.DynamicValue <> 41 then
      Halt(4);
    lIntegerMessage.ID := 100;
    lIntegerMessage.Value := 0;
    lClass.Dispatch(lIntegerMessage);
    if lIntegerMessage.Value <> 31 then
      Halt(5);
  finally
    lClass.Free;
  end;

  lClass := TChildClass.Create;
  try
    if lClass.Value <> 43 then
      Halt(6);
    if lClass.DynamicValue <> 47 then
      Halt(7);
    lIntegerMessage.ID := 100;
    lIntegerMessage.Value := 0;
    lClass.Dispatch(lIntegerMessage);
    if lIntegerMessage.Value <> 61 then
      Halt(8);
    lIntegerMessage.ID := 101;
    lIntegerMessage.Value := 0;
    lClass.Dispatch(lIntegerMessage);
    if lIntegerMessage.Value <> 71 then
      Halt(9);
    lStringMessage.ID := 'value';
    lStringMessage.Value := 0;
    lClass.DispatchStr(lStringMessage);
    if lStringMessage.Value <> 83 then
      Halt(10);
  finally
    lClass.Free;
  end;
  WriteLn('PASS: object VMT, class virtual/dynamic methods, inherited message tables');
end;

begin
  Run;
end.
