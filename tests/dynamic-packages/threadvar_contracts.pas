unit Threadvar_Contracts;
{$mode objfpc}{$H+}
interface
type
  TAddress = function: Pointer;
  TCheck = procedure;
  TProbe = record
    Address, SharedAddress: TAddress;
    Check: TCheck;
  end;
var
  Probes: array[0..31] of TProbe;
  Initializations, Finalizations: LongInt;
threadvar
  SharedValue: QWord;
implementation
initialization
  SharedValue:=$123456789ABC;
end.
