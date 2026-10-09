{ Nested Delphi method parameter types and type-name shadowing. }

{ tw17952a.pp }
{$mode delphi}

// check visibility of nested types in method headers

type
  TObjectMethodOuter = class
  public
    type
      TFoo2 = object
      end;
      TFoo3 = object
        procedure Proc(value: TFoo2);
      end;
  end;

procedure TObjectMethodOuter.TFoo3.Proc(value: TFoo2); // was error: Identifier not found "TFoo2"
begin
end;

{ tw17952b.pp }
{$mode delphi}

// check visibility of nested types in method headers

type
  TShadowMethodOuter = class
  public
    type
      TFoo2 = object
      end;
      TFoo3 = object
        procedure Proc(value: TFoo2);
      end;
  end;

  TFoo2 = Integer;

// delphi gives an error here. fpc does not.
// people thinks that this is a bug in delphi (QC# 89846)

procedure TShadowMethodOuter.TFoo3.Proc(value: TFoo2);
begin
end;

{ tw17986.pp }
{$mode delphi}

type
  TClassMethodOuter = class
  public
    type
      TFoo2 = class
        procedure Proc(value: TClassMethodOuter); // was error: Type "TFoo1" is not completely defined
      end;
  end;

procedure TClassMethodOuter.TFoo2.Proc(value: TClassMethodOuter);
begin
end;

begin

end.
