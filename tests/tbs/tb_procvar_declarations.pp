
{ Procedural variables, typed constants, parameter names and record fields. }

{ tb0042.pp }

procedure test;

  begin
  end;

var
   p1 : procedure;
   p2 : codepointer;

{ tb0099.pp }
{ Procedural vars cannot be assigned nil ?              OK 0.99.6 (FK) }

  type
    ExampleProc = procedure;

  var
    Eg: ExampleProc;

{ tb0196.pp }
{ const. procedure variables need a special syntax if they use calling specification modifiers }

const
   cSemicolonStdCall : procedure;stdcall=nil;   { <----- this doesn't what you expect !!!!}
   cInlineStdCall : procedure stdcall=nil;   { so delphi supports also this way of }
                                  { declaration                         }

{ tb0213.pp }
{ typecasting not possible within typed const          OK 0.99.13 (PFV) }

type
  TConstProcedure=procedure;
  TProcConstRecord=record
    w : TConstProcedure;
  end;

procedure ConstProcedure;
begin
end;

const
  cProcConst:TProcConstRecord=(
   w : TConstProcedure(@ConstProcedure);
  );

{ tb0234.pp }
{ @(proc) is not allowed                               OK 0.99.13 (PFV) }

type
  proc=procedure(a:longint);

procedure prc(a:longint);
begin
end;

var
  lParenthesizedProc : proc;

{ tb0445.pp }
type
  tproc = procedure(self,l2:longint);

procedure TestParameterNames(l1,l2:longint);
begin
end;

var
  pv : tproc;

{ tb0484.pp }
type
  r1 = record
    p : procedure stdcall;
    i : longint;
  end;

  r2 = record
    p : procedure;
    i : longint;
  end;

  r3 = record
    p : procedure
  end;

  { ugly, but should work (FK) }
  r4 = record
    p : procedure stdcall
  end;

{ tw1930.pp }
type
 tprocedure = procedure (x: byte);pascal;

begin
{ tb0042.pp }
  p1:=@test;
  p2:=@test;

  { tb0099.pp }
  Eg := nil;  { This produces a compiler error }

  { tb0234.pp }
  lParenthesizedProc:=@prc;
  lParenthesizedProc:=@(prc);  { should this be allowed ? }

  { tb0445.pp }
  pv:={$ifdef fpc}@{$endif}TestParameterNames;
end.
