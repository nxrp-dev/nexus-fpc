{ Arrays regression cases; original case IDs are retained below. }

{ Case tw14388.pp }
{$push}
{$mode objfpc}{$H+}

type
  tw14388_tid4 = array[0..3] of char;

function tw14388_getid: tw14388_tid4;
begin
  result:=#1#3#5#9;
end;

var
  tw14388_chunkid: tw14388_tid4;
{$pop}

{ Case tw33696.pp }
{$push}
{$mode objfpc}{$H+}
type
  tw33696_ternary = (F, U, T);

  operator and (const a,b:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupand:array[tw33696_ternary,tw33696_ternary] of tw33696_ternary =
                    ((F,F,F),(F,U,U),(F,U,T));
  begin
    Result:= tw33696_lookupand[a,b];
  end;

  operator or (const a,b:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupor:array[tw33696_ternary,tw33696_ternary] of tw33696_ternary =
                   ((F,U,T),(U,U,T),(T,T,T));
  begin
    Result := tw33696_lookupor[a,b];
  end;

  operator not (const a:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupnot:array[tw33696_ternary] of tw33696_ternary =(T,U,F);
  begin
     Result:= tw33696_lookupnot[a];
  end;
{$pop}

{ Case tw37062.pp }
{$push}
{$mode objfpc}{$H+}

Var
  tw37062_lout : array of Byte;
  tw37062_llength, tw37062_lssize : integer;
{$pop}

{ Case tw4239.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4239 }
{ Submitted by "Lars" on  2005-07-30 }
{ e-mail: L@z505.com }

{$mode objfpc}{$H+}

var
  tw4239_myproc: array of procedure(s:string);

procedure tw4239_testing(s:string);
begin
  writeln(s);
end;
{$pop}

begin
  { Case tw14388.pp }
  {$push}

  begin
tw14388_chunkid:=#1#3#5#9;
  if tw14388_getid=tw14388_chunkid then
    writeln('ok')
  else
    halt(1);
  end;
  {$pop}

  { Case tw33696.pp }
  {$push}

  begin
// works as expected
  writeln('AND');write(F and F);write(F and U);
  writeln(F and T);write(U and F);write(U and U);
  writeln(U and T);write(T and F);write(T and U);
  writeln(T and T);
  writeln;
  //works as expected
  writeln('OR');write(F or F);write(F or U);
  writeln(F or T);write(U or F);write(U or U);
  writeln(U or T);write(T or F);write(T or U);
  writeln(T or T);
  writeln;
  // this fails, but compiles and runs w/o error indication.
  // and renders the wrong results
  writeln('NOT');
  writeln(not F);// prints -1 unstead of T, it does not pick the overload!
  writeln(not U);// prints -2 instead of U, it does not pick the overload!
  writeln(not T);// prints -3 instead of F, it does not pick the overload!
  // which makes this next construct impossible while the compiler suggests it's legal.
  {
   writeln(T and not F);
  }
  end;
  {$pop}

  { Case tw37062.pp }
  {$push}

  begin
SetLength(tw37062_lout, 1+tw37062_llength+1+4+4+2+4+4+2+tw37062_lssize+2);
  end;
  {$pop}

  { Case tw4239.pp }
  {$push}

  begin
setlength(tw4239_myproc,1);
  tw4239_myproc[0]:=@tw4239_testing;
  tw4239_myproc[0]('Test me');
  end;
  {$pop}

end.
