{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw38122b.pas }
{$push}



type tw38122b_trec=record
  i:integer;
 end;

 var tw38122b_rec:tw38122b_trec;
     tw38122b_prec:^tw38122b_trec;
     tw38122b_s: string;

{$pop}

{ Case tw8685.pas }
{$push}
{$ifdef fpc}

{$endif}




type
  tw8685_vecteurF = array of extended;
  tw8685_matriceF = array of tw8685_vecteurF;
  tw8685_matriceE = record
    err     :integer;
    x       :tw8685_matriceF;
  end;

var
  tw8685_A,tw8685_B,tw8685_C :tw8685_matriceE;

function tw8685_copyM(tw8685_A:tw8685_matriceE):tw8685_matriceE;
var
  i,j,nl,nc :integer;
  tw8685_C   :tw8685_matriceE;
begin
  nl:=succ(high(tw8685_A.x));nc:=succ(high(tw8685_A.x[0]));
  setlength(tw8685_C.x,nl,nc);
  for i:=0 to pred(nl) do
    begin
      for j:=0 to pred(nc) do tw8685_C.x[i,j]:=tw8685_A.x[i,j];
    end;
  tw8685_C.err:=tw8685_A.err;
  Result:=tw8685_C;
end;

procedure tw8685_copyM2(tw8685_A:tw8685_matriceE;var tw8685_C:tw8685_matriceE);
var
  i,j,nl,nc :integer;
begin
  nl:=succ(high(tw8685_A.x));nc:=succ(high(tw8685_A.x[0]));
  setlength(tw8685_C.x,nl,nc);
  for i:=0 to pred(nl) do
    begin
      for j:=0 to pred(nc) do tw8685_C.x[i,j]:=tw8685_A.x[i,j];
    end;
  tw8685_C.err:=tw8685_A.err;
end;

procedure tw8685_writeM(tw8685_A:tw8685_matriceE;str:string);
var
  i,j :integer;
begin
  for i:=0 to high(tw8685_A.x) do
    begin
      for j:=0 to high(tw8685_A.x[i]) do write(format(str,[tw8685_A.x[i,j]]));
      writeln;
    end;
end;

procedure tw8685_checkM(const tw8685_A,tw8685_B:tw8685_matriceE);
var
  i,j :integer;
begin
  if (high(tw8685_A.x) <> high(tw8685_B.x)) then
    halt(1);
  for i:=0 to high(tw8685_A.x) do
    begin
      if (high(tw8685_A.x[i]) <> high(tw8685_B.x[i])) then
        halt(2);
      for j:=0 to high(tw8685_A.x[i]) do
        if (tw8685_A.x[i,j] <> tw8685_B.x[i,j]) then
          halt(3);
    end;
end;



{$pop}

{ Case trtti11.pas }
{$push}






type
  trtti11_PFoo = ^trtti11_TFoo;
  trtti11_TFoo = packed record
  public
    F: Integer;
    S: string;
  end;

var
  trtti11_PF: trtti11_PFoo;

{$pop}

begin

{ Case tw38122b.pas }
{$push}

begin
  tw38122b_rec.i:=20;
  tw38122b_prec:=@tw38122b_rec;
  tw38122b_s:=tw38122b_prec.i.tostring;
  //writeln(s);
  if tw38122b_s<>'20' then
    halt(1);
end;
{$pop}

{ Case tw8685.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  setlength(tw8685_A.x,3,3);
  tw8685_A.err:=0;
  tw8685_A.x[0,0]:=0.5;tw8685_A.x[0,1]:=0.2;tw8685_A.x[0,2]:=0.8;
  tw8685_A.x[1,0]:=0.2;tw8685_A.x[1,1]:=0.2;tw8685_A.x[1,2]:=0.9;
  tw8685_A.x[2,0]:=0.8;tw8685_A.x[2,1]:=0.9;tw8685_A.x[2,2]:=3.1;
  writeln('matrix A,  number of lines : ',succ(high(tw8685_A.x)));
  tw8685_writeM(tw8685_A,'%6.3f');
  writeln;
  tw8685_B:=tw8685_copyM(tw8685_A);
  writeln('matrix B,  number of lines : ',succ(high(tw8685_B.x)));
  tw8685_checkM(tw8685_A,tw8685_B);
  writeln;
  tw8685_copyM2(tw8685_A,tw8685_C);
  writeln('matrix C,  number of lines : ',succ(high(tw8685_C.x)));
  tw8685_checkM(tw8685_A,tw8685_C);
  writeln;
  writeln('end');
end;
{$pop}

{ Case trtti11.pas }
{$push}

begin
  try
    GetMem(trtti11_PF, SizeOf(trtti11_TFoo));
    InitializeArray(trtti11_PF, TypeInfo(trtti11_TFoo), 1);
    trtti11_PF.S := 'foo';
    FinalizeArray(trtti11_PF, TypeInfo(trtti11_TFoo), 1);
    FreeMem(trtti11_PF);
  except
    Halt(1);
  end;
end;
{$pop}

end.
