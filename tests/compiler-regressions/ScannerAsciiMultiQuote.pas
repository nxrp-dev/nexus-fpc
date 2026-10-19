program ScannerAsciiMultiQuote;
{$mode objfpc}{$H+}
{$codepage utf8}
{$modeswitch MultiLineStrings}
{$MultiLineStringLineEnding LF}

const
  cText = '''
  cafe
  ''';

begin
  if cText <> 'cafe' then
    Halt(1);
end.
