program Project1;

{$mode objfpc}{$H+}

uses
  Generics.Collections;

type
  TMyMap = specialize TDictionary<string, string>;

var
  m: TMyMap;
  c: Char;
begin
  m := TMyMap.Create;
  m.Add('a', 'hello');
  m.Add('b', ' ');
  m.Add('c', 'world!');

  for c := 'a' to 'c' do
    Write(m[c]);
  Writeln;

  m.Free;
end.

