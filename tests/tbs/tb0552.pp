{$ifdef FPC}
  {$mode objfpc}
{$endif FPC}
type
  pb1 = ^boolean;
  pb2 = ^boolean deprecated;
  pt = boolean deprecated;
  o = class
  end deprecated;
  r = record
  end deprecated;
  p1 = procedure;stdcall;deprecated;
  p2 = procedure deprecated;
  p3 = p1 deprecated;


var
  v : p3;
begin
end.
