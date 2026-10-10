type
  TEnum = (A, B, C);
var
  Calls: LongInt;

{$ifdef TEST_OBJFPC}generic{$endif} procedure Test<T>(First, Last: T);
type
  TItems = set of T;
var
  Items: TItems;

  function MakePair: TItems;
  begin
    Result := [First, Last];
  end;

  function Counted(Value: T): T;
  begin
    Inc(Calls);
    Result := Value;
  end;

begin
  Items := [First, Last];
  if not (First in Items) or not (Last in Items) then Halt(1);
  if not (First in [First, Last]) then Halt(2);
  Items := [First..Last];
  if not (First in Items) or not (Last in Items) then Halt(3);
  Items := Items - [First];
  if First in Items then Halt(4);
  Items := Items + [First];
  if not (First in Items) then Halt(5);
  Calls := 0;
  Items := [Counted(First), Counted(Last)];
  if (Calls <> 2) or not (First in Items) or not (Last in Items) then Halt(6);
  Items := MakePair;
  if not (First in Items) or not (Last in Items) then Halt(11);
end;

{ The destination need not itself depend on the generic parameter. }
{$ifdef TEST_OBJFPC}generic{$endif} procedure TestFixed<T>(Value: T);
var
  Items: set of Byte;
begin
  Items := [Value];
  if not (Value in Items) then Halt(7);
  Items := [0..Value];
  if not (0 in Items) or not (Value in Items) then Halt(8);
  Items := [Value..255];
  if not (255 in Items) or not (Value in Items) then Halt(9);
  Items := [0, Value, 255];
  if not (0 in Items) or not (Value in Items) or not (255 in Items) then Halt(10);
end;

begin
  {$ifdef TEST_OBJFPC}specialize{$endif} Test<TEnum>(A, C);
  {$ifdef TEST_OBJFPC}specialize{$endif} Test<Byte>(250, 255);
  {$ifdef TEST_OBJFPC}specialize{$endif} Test<Char>('a', 'z');
  {$ifdef TEST_OBJFPC}specialize{$endif} TestFixed<Byte>(127);
end.
