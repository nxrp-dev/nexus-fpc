program tsoftinteger;
{$mode objfpc}
uses sfpux80;
procedure Check(AValue: Double; AExpected: Int64);
var lBits: sfpux80.float64;
begin
  Move(AValue,lBits,SizeOf(lBits));
  if floatx80_to_int64(float64_to_floatx80(lBits))<>AExpected then Halt(1);
end;
begin
  Check(255.75,256);
  Check(256.75,257);
  Check(-256.75,-257);
  Check(65535.5,65536);
  Check(65536.5,65536);
  WriteLn('RTL software integer rounding passed');
end.
