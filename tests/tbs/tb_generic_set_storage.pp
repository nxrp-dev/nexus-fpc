{%RECOMPILE}
{$mode objfpc}
uses ugeneric_set_storage;
type
  TEnum = (A, B, C);
  TEnumSet = set of TEnum;
  TEnumBox = specialize TSetBox<TEnum>;
  TByteBox = specialize TSetBox<Byte>;
var
  EnumBox: TEnumBox;
  ByteBox: TByteBox;
begin
  EnumBox := TEnumBox.Create;
  ByteBox := TByteBox.Create;
  EnumBox.Items := [B];
  ByteBox.Items := [255];
  if not (B in EnumBox.Items) or not (255 in ByteBox.Items) then Halt(1);
  if (SizeOf(ByteBox.Items) <> 32) or
     (SizeOf(EnumBox.Items) <> SizeOf(TEnumSet)) then Halt(2);
  EnumBox.SetRange(A, C);
  ByteBox.SetRange(250, 255);
  if EnumBox.Items <> [A, B, C] then Halt(3);
  if ByteBox.Items <> [250..255] then Halt(4);
  EnumBox.Free;
  ByteBox.Free;
end.
