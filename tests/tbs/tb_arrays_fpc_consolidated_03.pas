{ Consolidated arrays regressions; original case IDs and assertions are retained. }
{ %OPT=-CRriot -O-2 -Ooregvar }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw8975.pas }
{$push}


{Internal FPC2.1.4 error, compile with fpc -B -dDebug -O3}
procedure tw8975_bug(const b: array of longint);
  procedure intern;
  begin
    if (b[low(b)] <> 1) then {Fatal: Internal error 200409241}
      halt(1);
  end;
begin
  intern;
end;

const
  tw8975_a: array[1..3] of longint = (1,2,3);

{$pop}

{ Case tw8975a.pas }
{$push}


{Internal FPC2.1.4 error, compile with fpc -B -dDebug -O3}
procedure tw8975a_bug(const b: array of longint); cdecl;
  procedure intern;
  begin
    if (b[low(b)] <> 1) then {Fatal: Internal error 200409241}
      halt(1);
  end;
begin
  intern;
end;

const
  tw8975a_a: array[1..3] of longint = (1,2,3);

{$pop}

{ Case tw8975b.pas }
{$push}


{Internal FPC2.1.4 error, compile with fpc -B -dDebug -O3}
procedure tw8975b_bug(var b: array of longint);
var
  l: longint;

  procedure intern;
  begin
    if (b[l] <> 1) then {Fatal: Internal error 200409241}
      halt(1);
    inc(b[l]);
    if (b[l] <> 2) then {Fatal: Internal error 200409241}
      halt(2);

    if (b[l+1] <> 2) then {Fatal: Internal error 200409241}
      halt(3);
    if (b[l+2] <> 3) then {Fatal: Internal error 200409241}
      halt(4);
    if (b[low(b)] <> 2) then {Fatal: Internal error 200409241}
      halt(5);
    if (b[low(b)+1] <> 2) then {Fatal: Internal error 200409241}
      halt(6);
    if (b[low(b)+2] <> 3) then {Fatal: Internal error 200409241}
      halt(7);
  end;
begin
  l:=0;
  intern;
end;

const
  tw8975b_a: array[1..3] of longint = (1,2,3);

{$pop}

begin

{ Case tw8975.pas }
{$push}

begin
  tw8975_bug(tw8975_a);
end;
{$pop}

{ Case tw8975a.pas }
{$push}

begin
  tw8975a_bug(tw8975a_a);
end;
{$pop}

{ Case tw8975b.pas }
{$push}

begin
  tw8975b_bug(tw8975b_a);
end;
{$pop}

end.
