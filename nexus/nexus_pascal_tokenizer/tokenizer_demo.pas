program tokenizer_demo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nxPasTokenTypes,
  nxPasTokenizer;

var
  Tokenizer: TNXTokenizer;
  Buffer: TNXTokenBuffer;
  I: Integer;
begin
  Tokenizer := TNXTokenizer.Create;
  try
    Tokenizer.Start(
      'demo.pas',
      'unit Demo;' + LineEnding +
      'interface' + LineEnding +
      '{$define TEST}' + LineEnding +
      '{$ifdef TEST}' + LineEnding +
      'const Answer = 42;' + LineEnding +
      '{$endif}' + LineEnding +
      'implementation' + LineEnding +
      'end.'
    );

    if Tokenizer.Continue <> tsComplete then
      raise Exception.Create('Demo unexpectedly blocked');

    Buffer := Tokenizer.Tokens;

    for I := 0 to High(Buffer) do
      WriteLn(
        I:4,
        ' kind=', Ord(Buffer[I].Kind),
        ' variant=', Buffer[I].Variant,
        ' line=', Buffer[I].Line,
        ' col=', Buffer[I].Column
      );
  finally
    Tokenizer.Free;
  end;
end.
