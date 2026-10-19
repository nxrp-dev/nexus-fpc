unit tsNXStringHash;

{$mode delphi}{$H+}

interface
uses obNXTestRegistry;
procedure RegisterStringHashTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, Generics.Collections, Generics.Defaults, obNXTestContext;

procedure EqualStringStorage(AContext: TNXTestContext);

var
  lValues: TDictionary<string, Integer>;
  lComparer: IEqualityComparer<string>;
  lFirst, lSecond: string;
  lLength, lIndex, lValue, lChecks: Integer;
begin
  lValues := TDictionary<string, Integer>.Create;
  lComparer := TEqualityComparer<string>.Default;
  try
    for lLength := 0 to 127 do
    begin
      SetLength(lFirst, lLength);
      for lIndex := 1 to lLength do lFirst[lIndex] := AnsiChar(33 + lIndex mod 90);
      lSecond := Copy('prefix' + lFirst + 'suffix', 7, lLength);
      if lComparer.GetHashCode(lFirst) <> lComparer.GetHashCode(lSecond) then
        AContext.Fail(Format('Equal strings hash differently at length %d', [lLength]));
      lValues.AddOrSetValue(lFirst, lLength);
      if not lValues.TryGetValue(lSecond, lValue) or (lValue <> lLength) then
        AContext.Fail(Format('Dictionary lost equal string at length %d', [lLength]));
      Inc(lChecks);
    end;
    lValues.AddOrSetValue(LowerCase('ApplicationRoot'), 321);
    if not lValues.TryGetValue('applicationroot', lValue) or (lValue <> 321) then
      AContext.Fail('Dictionary lookup differs between allocated and literal strings');

  finally
    lValues.Free;
  end;
end;
procedure RegisterStringHashTests(ARegistry: TNXTestRegistry);
begin
  ARegistry.AddSuite('Generics.Hashing').AddTest('EqualStringStorage', @EqualStringStorage, 'generics-hashing');
end;
end.
