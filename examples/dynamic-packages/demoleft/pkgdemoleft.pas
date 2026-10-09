unit PkgDemoLeft;
{$mode objfpc}{$H+}
interface
implementation
uses PkgDemoTypes;
initialization
  Trace:=Trace+'L';
finalization
  LogLine('final=l');
end.
