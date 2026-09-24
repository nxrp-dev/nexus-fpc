program profiler_exceptions;

{$mode objfpc}{$H+}

uses
  profiler_exception_unit;

begin
  SameFrameCatch;
  CatchOneFrame;
  CatchMultiFrame;
  CatchRethrow;
  CatchFinally;
  CatchNested;
  CatchAccessViolation;
  CallSafe;
  if FinalizerCount <> 1 then Halt(10);
end.
