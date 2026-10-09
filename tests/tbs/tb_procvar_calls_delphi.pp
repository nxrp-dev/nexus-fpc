{ Delphi procedural variable addresses, initialization, overloads and dereferencing. }

{ tb0430.pp }
{$ifdef fpc}{$mode delphi}{$endif}

function AssignedFunction:pointer;
begin
  result:=nil;
end;

var
  lAssignedProc: function:pointer;

{ tb0433a.pp }
{$ifdef fpc}
{$mode delphi}
{$else fpc}
type
  codepointer = pointer;
{$endif fpc}

function times2(x : longint) : longint;

begin
  times2:=2*x;
end;

var
 x:function(x:longint):longint;
 y:codepointer absolute x;
 z,w,v:codepointer;

{ tb0435.pp }
{$ifdef fpc}{$mode Delphi}{$endif}

var
 lNilProc:function(lNilProc:longint):longint;
 lNilProcCode:pointer absolute lNilProc;

{ tb0448.pp }
{$mode delphi}

var
  lOverloadProcedureError : boolean;

procedure OverloadedProcedure(s:string);overload;
begin
end;

procedure OverloadedProcedure(l:longint);overload;
begin
  lOverloadProcedureError:=false;
end;

var
  pv : procedure(l:longint);

{ tb0471.pp }
{$mode delphi}

const
  cOverloadFunctionError : boolean = true;

type
  tf = function:longint;
procedure OverloadedFunction(l:longint);overload;
begin
  writeln('longint');
end;

procedure OverloadedFunction(f:tf);overload;
begin
  writeln('procvar');
  cOverloadFunctionError:=false;
end;

function vf:longint;
begin
  vf:=10;
end;

var
  lFunctionProc : tf;

{ tb0486.pp }
{$ifdef fpc}{$mode delphi}{$endif}
type
  tprocedure = procedure;
  pprocedure = ^tprocedure;

var
  l : longint;
  l2 : tprocedure;

function _f1 : plongint;
  begin
    result:=@l;
  end;

function _f2 : pprocedure;
  begin
    result:=@@l2;
  end;

var
  f1 : function : plongint;
  f2 : function : pprocedure;

procedure p;
  begin
    l:=2;
  end;

begin
  { tb0430.pp }
  lAssignedProc:=AssignedFunction;
  { Assigned() works on the procvar and does not
    call func }
  if not assigned(lAssignedProc) then
   begin
     writeln('ERROR!');
     halt(1);
   end;

  { tb0433a.pp }
  x:=times2;
  z:=@x;
  w:=addr(x);
  v:=@times2;
  writeln(longint(y),' ',longint(z),' ',longint(w),' ',longint(v));
  if (z<>w) or (z<>v) or (y<>z) then
   begin
     writeln('Addr Error');
     halt(1);
   end;
  if (y<>@times2) then
   begin
     writeln('Absolute Error');
     halt(1);
   end;

  { tb0435.pp }
  if lNilProcCode<>nil then
   halt(1);

  { tb0448.pp }
  lOverloadProcedureError:=true;
  pv:=OverloadedProcedure;
  pv(1);
  if lOverloadProcedureError then
   begin
     writeln('Error!');
     halt(1);
   end;

  { tb0471.pp }
  lFunctionProc:=vf;
  OverloadedFunction(lFunctionProc);
  if cOverloadFunctionError then
    halt(1);

  { tb0486.pp }
  f1:=_f1;
  f2:=_f2;
  f1^:=1;
  if l<>1 then
    halt(1);
  f2^:=p;
  f2^;
  if l<>2 then
    halt(1);
  writeln('ok');
end.
