{ Recursive pointers, forward pointee aliases and locally shadowed forward types. }

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

{ Case tb0015.pp }
{$push}
{ Old file: tbs0018.pp }
{  tests for the possibility to declare all types using pointers "forward" : type p = ^x; x=byte;     OK 0.9.3 }

type
   tb0015_p = ^tb0015_x;
   tb0015_x = byte;

var
   tb0015_b : tb0015_p;
{$pop}

{ Case tb0016.pp }
{$push}
{ Old file: tbs0019.pp }
{  }

type
   tb0016_b = ^tb0016_x;

   tb0016_x = byte;

var
   tb0016_pb : tb0016_b;
{$pop}

begin
  { tb0113.pp }
  lLoopPointer:=@lLoopPointer2;
  lLoopPointer2:=@lLoopPointer;
  lLoopPointer:=lLoopPointer2^;

  { tb0255.pp }
  p;
  { Case tb0015.pp }
  {$push}
begin
   new(tb0015_b);
   tb0015_b^:=12;
end;
  {$pop}

  { Case tb0016.pp }
  {$push}
begin
   new(tb0016_pb);
   tb0016_pb^:=10;
end;
  {$pop}

end.
