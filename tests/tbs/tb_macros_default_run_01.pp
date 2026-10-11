{ Nested macro substitution in conditions and macro-generated procedure declarations. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tb0472.pp }
{$push}
{$macro on}

{$define aaa:=1234}
{$define bbb:=4321}

{$define ccc:=aaa} // here aaa is already defined macros

var
  tb0472_err : boolean;
{$pop}

{ Case tw2771.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2771 }
{ Submitted by "Michalis Kamburelis" on  2003-11-08 }
{ e-mail: michalis@camelot.homedns.org }
{$macro on}

{$define MAC:=procedure P}

MAC; begin end;
{$pop}

begin
  { Case tb0472.pp }
  {$push}
{$macro on}
begin
  tb0472_err:=true;
{$if aaa=ccc} // condition is equal
  // but compiler not compiling this block, because
  // don't take into account that value of macros ccc is macros also.
  tb0472_err:=false;
  writeln('success');
{$else}
  writeln('failure');
{$endif}
  if tb0472_err then
   halt(1);
end;
  {$pop}

  { Case tw2771.pp }
  {$push}
begin
end;
  {$pop}

end.
