{$interfaces corba}
{$codepage utf8}
type
  ITest = interface ['MYINTERFACE'] end;
var
  DefaultValue: String;
  ShortValue: ShortString;
  AnsiValue: AnsiString;
  UnicodeValue: UnicodeString;
  WideValue: WideString;
  RawValue: RawByteString;
  UTF8Value: UTF8String;
  BoundedValue: String[4];
begin
  DefaultValue := ITest;
  if DefaultValue <> 'MYINTERFACE' then Halt(1);
  ShortValue := ITest;
  if ShortValue <> 'MYINTERFACE' then Halt(2);
  AnsiValue := ITest;
  if AnsiValue <> 'MYINTERFACE' then Halt(3);
  UnicodeValue := ITest;
  if UnicodeValue <> 'MYINTERFACE' then Halt(4);
  WideValue := ITest;
  if WideValue <> 'MYINTERFACE' then Halt(5);
  RawValue := ITest;
  if RawValue <> 'MYINTERFACE' then Halt(6);
  UTF8Value := ITest;
  if UTF8Value <> 'MYINTERFACE' then Halt(7);
  BoundedValue := ITest;
  if BoundedValue <> 'MYIN' then Halt(8);
end.
