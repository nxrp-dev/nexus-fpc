program ScannerUTF8MultiQuote;
{$mode objfpc}{$H+}
{$codepage utf8}
{$modeswitch MultiLineStrings}
{$MultiLineStringLineEnding LF}

const
  cText = '''
  café
  ''';

begin
  if cText <> 'café' then
    Halt(1);
end.
