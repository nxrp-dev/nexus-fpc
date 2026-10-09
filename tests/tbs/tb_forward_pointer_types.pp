{ Recursive pointers and locally shadowed forward type declarations. }

{ tb0113.pp }
{ segmentation fault with type loop                     OK 0.99.7 (FK) }

type

  TPointerLoop=^TPointerLoop2;
  TPointerLoop2 = ^TPointerLoop;

  var lLoopPointer:TPointerLoop;
      lLoopPointer2:TPointerLoop2;

{ tb0255.pp }
{ forward type definition is resolved wrong            OK 0.99.13 (PFV) }

type
  t1=longint;

procedure p;
type
  pt1=^t1;
  t1=string;
var
  t : t1;
  p : pt1;
begin
  p:=@t;
  p^:='test';
end;

begin
  { tb0113.pp }
  lLoopPointer:=@lLoopPointer2;
  lLoopPointer2:=@lLoopPointer;
  lLoopPointer:=lLoopPointer2^;

  { tb0255.pp }
  p;
end.
