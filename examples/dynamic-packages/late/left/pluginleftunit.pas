unit PluginLeftUnit;
{$mode objfpc}{$H+}
interface
uses PkgContracts;
function CreatePlugin: TPluginValue; cdecl; public name 'CreatePlugin';
implementation
uses SysUtils, PluginBaseUnit;
type
  TLeftValue = class(TPluginValue)
    function Text: string; override;
    destructor Destroy; override;
  end;
function TLeftValue.Text: string;
begin Result:=StringOfChar('L',80); end;
destructor TLeftValue.Destroy;
begin Inc(ObjectsDestroyed); inherited Destroy; end;
function CreatePlugin: TPluginValue; cdecl;
begin Inc(ObjectsCreated); Result:=TLeftValue.Create; end;
initialization
  Trace:=Trace+'L';
finalization
  Trace:=Trace+'l';
end.
