unit PluginRightUnit;
{$mode objfpc}{$H+}
interface
implementation
uses PkgContracts, PluginBaseUnit;
initialization
  Trace:=Trace+'R';
finalization
  Trace:=Trace+'r';
end.
