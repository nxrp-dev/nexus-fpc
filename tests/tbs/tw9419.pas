{$mode objfpc}{$H+}
uses Generics.Collections;
type
  TEnum = (ta, tb, tc);
  TMyMap = specialize TDictionary<string, TEnum>;
var
  lMap: TMyMap;
  lValue: TEnum;
begin
  lMap := TMyMap.Create;
  try
    lMap.Add('Hello', ta);
    if not lMap.TryGetValue('Hello', lValue) or (lValue <> ta) then
      Halt(1);
  finally
    lMap.Free;
  end;
end.
