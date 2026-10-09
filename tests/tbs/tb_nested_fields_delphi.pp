{ Nested Delphi field types, private record members and class variables. }
{ %NORUN }

{ tw18767a.pp }
{$mode delphi}{$H+}

type
  TConstArrayOwner = class
  strict private
    const
      n = 3;
    var
      x: array[0..1] of record
        y: array[0..n] of integer;
      end;
  end;

{ tw18767b.pp }
{$mode delphi}{$H+}

type
  TEnumArrayOwner = class
  strict private
    type
      TBar = (one, two);
    var
      x: array of record
        y: array[TBar] of integer;
      end;
  end;

{ tw18768.pp }
{$mode delphi}{$H+}

type
  TPrivateRecordOuter = record
  private
    type
      TFoo3 = record
      private
        b, c: integer;
      strict private
        a: integer;
      public
        function GetFoo2: integer;
      end;
  end;

function TPrivateRecordOuter.TFoo3.GetFoo2: integer;
begin
  c := a * b;
end;

{ tw18131.pp }
{$mode delphi}

type
  TFoo1 = class
    type
      TFoo2 = class
        class var
          x: integer;
        constructor Create;
      end;
  end;

constructor TFoo1.TFoo2.Create;
begin
  inherited;
  inc(x);
end;

begin
  { tw18767a.pp }
  TConstArrayOwner.Create;
  ;

  { tw18767b.pp }
  TEnumArrayOwner.Create;
  ;

  { tw18131.pp }
  TFoo1.TFoo2.x := 0;
    TFoo1.TFoo2.Create.Destroy;
    if TFoo1.TFoo2.x<>1 then
      halt(1);
  ;
end.
