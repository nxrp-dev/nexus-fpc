type
  TEnum = (A, B, C);

{$ifdef TEST_OBJFPC}generic{$endif} procedure Test<T>(AElement: T);
type
  TFixed = set of TEnum;
  TRange = set of Low(T)..High(T);
  TGeneric = set of T;
var
  FixedItems: TFixed;
  RangeItems: TRange;
  GenericItems: TGeneric;
begin
  FixedItems := [A, C];
  if B in FixedItems then Halt(1);
  if SizeOf(TRange) <> SizeOf(TGeneric) then Halt(2);
  RangeItems := [];
  Include(RangeItems, AElement);
  GenericItems := [];
  Include(GenericItems, AElement);
  if not (AElement in RangeItems) or not (AElement in GenericItems) then Halt(3);
  Exclude(GenericItems, AElement);
  if GenericItems <> [] then Halt(4);
  Include(GenericItems, AElement);
  if not (AElement in GenericItems) then Halt(5);
end;

{ An unspecialized declaration must also have its own valid definition. }
{$ifdef TEST_OBJFPC}generic{$endif} procedure Unused<T>;
type
  TItems = set of T;
begin
end;

begin
  {$ifdef TEST_OBJFPC}specialize{$endif} Test<TEnum>(B);
  {$ifdef TEST_OBJFPC}specialize{$endif} Test<Byte>(255);
end.
