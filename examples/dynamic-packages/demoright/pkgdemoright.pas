unit PkgDemoRight;
{$mode objfpc}{$H+}
interface
implementation
uses PkgDemoTypes;
initialization
  Trace:=Trace+'R';
finalization
  LogLine('final=r');
end.
