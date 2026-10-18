{$mode objfpc}{$H+}
uses Generics.Collections;
const
  cValues: array[0..16] of Integer = (1,2,2,7,0,12,3,4,5,3,6,7,8,9,0,3,4);
type
  TMyMap = specialize TDictionary<Integer, Integer>;
var
  lMap: TMyMap;
  lIndex, lFirst, lPrevious: Integer;
begin
  lMap := TMyMap.Create;
  try
    for lIndex := Low(cValues) to High(cValues) do
    begin
      if lMap.TryGetValue(cValues[lIndex], lFirst) then
      begin
        lPrevious := 0;
        while cValues[lPrevious] <> cValues[lIndex] do
          Inc(lPrevious);
        if lFirst <> lPrevious then Halt(1);
      end
      else
        lMap.Add(cValues[lIndex], lIndex);
    end;
  finally
    lMap.Free;
  end;
end.
