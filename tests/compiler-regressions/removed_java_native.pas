program RemovedJavaNative;
{$mode objfpc}{$H+}
{$interfaces corba}

type
  IValue = interface
    function Value: LongInt;
  end;
  TBase = class abstract
  protected
    FValue: LongInt;
  public
    constructor Create(AValue: LongInt); overload;
    constructor Create; overload;
    function Value: LongInt; virtual; abstract;
  end;
  TChild = class(TBase, IValue)
    function Value: LongInt; override; final;
  end;
  TBaseClass = class of TBase;

constructor TBase.Create(AValue: LongInt);
begin
  inherited Create;
  FValue := AValue;
end;

constructor TBase.Create;
begin
  Create(42);
end;

function TChild.Value: LongInt;
begin
  Result := FValue;
end;

var
  Child: TChild;
  Base: TBase;
  Kind: TBaseClass;
  Intf: IValue;
begin
  Child := TChild.Create;
  Base := Child;
  Intf := Child;
  if (Base.Value <> 42) or (Intf.Value <> 42) then Halt(1);
  Base.Free;
  Kind := TChild;
  Base := Kind.Create(37);
  if Base.Value <> 37 then Halt(2);
  Base.Free;
  WriteLn('PASS: native constructors, inheritance, interfaces, and virtual dispatch');
end.
