{ SizeOf generic Delphi parameters in member constants, local constants and initialized variables. }

{ tw21593.pp }
{$MODE DELPHI}

type
  TWrapper<T> = record
    strict private
      const Size1 = SizeOf(T);  { Error: Illegal expression }
    class procedure Test; static;
  end;

class procedure TWrapper<T>.Test;
const
  Size2 = SizeOf(T);  { Error: Illegal expression }
var
  size3: SizeInt = SizeOf(T);  { Error: Illegal expression }
begin
  Writeln(Size3);
end;

var
  Wrapper : TWrapper<Byte>;

{ tw21593a.pp }
{$MODE DELPHI}

type
  TLocalConstWrapper<T> = record
    class procedure Test; static;
  end;

class procedure TLocalConstWrapper<T>.Test;
const
  Size = SizeOf(T);  { Error: Illegal expression }
begin
  Writeln(Size);
end;

{ tw21593b.pp }
{$MODE DELPHI}

type
  TMemberConstWrapper<T> = record
  strict private
    const Size = SizeOf(T);  { Error: Illegal expression }
  public
    class procedure Test; static;
  end;

class procedure TMemberConstWrapper<T>.Test;
begin
  Writeln(Size);
end;

{ tw21593c.pp }
{$MODE DELPHI}

type
  TLocalVarWrapper<T> = record
    class procedure Test; static;
  end;

class procedure TLocalVarWrapper<T>.Test;
var
  size: SizeInt = SizeOf(T);  { Error: Illegal expression }
begin
  Writeln(size);
end;

begin
  { tw21593a.pp }
  TLocalConstWrapper<Byte>.Test;
  ;

  { tw21593b.pp }
  TMemberConstWrapper<Byte>.Test;
  ;

  { tw21593c.pp }
  TLocalVarWrapper<Byte>.Test;
  ;
end.
