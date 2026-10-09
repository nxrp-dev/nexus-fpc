unit PkgContracts;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
type
  TPluginValue = class(TPersistent)
    function Text: string; virtual; abstract;
  end;
  TCreatePlugin = function: TPluginValue; cdecl;
  EPluginCall = class(Exception);
var
  Trace: string;
  BaseInitializations, ObjectsCreated, ObjectsDestroyed: LongInt;
  FindComponentCalls, InitComponentCalls: LongInt;
  ApplicationCallback: Pointer;
implementation
initialization
  Trace:='C';
end.
