{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tw15777e.pas }
{$push}

{$B-}


type
  tw15777e_IntegerPtr = ^Integer;

var
  tw15777e_gi: Integer;

procedure tw15777e_A( procedure pp( p: univ Pointer));
begin
  pp( @tw15777e_gi)
end;

procedure tw15777e_B( p: tw15777e_IntegerPtr);
begin
  if ( p = nil) or ( p^ <> 12345) then halt( 1)
end;


{$pop}

{ Case tw15777f.pas }
{$push}

{$B-}


type
  tw15777f_IntegerPtr = ^Integer;
  tw15777f_ProcParam = procedure( p: univ Pointer);

var
  tw15777f_gi: Integer;

procedure tw15777f_A( pp: tw15777f_ProcParam);
begin
  pp( @tw15777f_gi)
end;

procedure tw15777f_B( p: tw15777f_IntegerPtr);
begin
  if ( p = nil) or ( p^ <> 12345) then halt( 1)
end;


{$pop}

{ Case tw17379.pas }
{$push}

{$warnings off}


function tw17379_first( function test( theint: integer): boolean): integer;
begin
  test(2);
end;

function tw17379_find: integer;
  var
    l: longint;

  function test( theint: integer): boolean;
  begin
    if (theint = 1) then
      tw17379_first( test)
    else
      begin
        writeln('nested procvar call, l = ', l);
        if l<>1234567890 then
          halt(1);
      end;
    tw17379_find:=0;
  end;

begin
  l:=1234567890;
  test(1)
end;


{$pop}

{ Case tw17710.pas }
{$push}


var
  tw17710_i : longint;

{$pop}

{ Case tw22344.pas }
{$push}




var
  tw22344_glob: integer;

function tw22344_countchars: INTEGER ;
begin
  tw22344_countchars:=255;
  if tw22344_glob=5 then
    tw22344_countchars := 0
  else
    begin
      inc(tw22344_glob);
      tw22344_countchars := 1 + tw22344_countchars
    end
  end;


{$pop}

{ Case tw4136.pas }
{$push}

function tw4136_f: longint;
begin
  return 3;
end;


{$pop}

begin

{ Case tw15777e.pas }
{$push}

{$B-}
begin
  tw15777e_gi := 12345;
  tw15777e_A( tw15777e_B)
end;
{$pop}

{ Case tw15777f.pas }
{$push}

{$B-}
begin
  tw15777f_gi := 12345;
  tw15777f_A( tw15777f_B)
end;
{$pop}

{ Case tw17379.pas }
{$push}

{$warnings off}
begin
  tw17379_find;
end;
{$pop}

{ Case tw17710.pas }
{$push}

begin
  if -2 shr 1<>-1 then
    halt(1);
  if -2-2<>-4 then
    halt(1);
  tw17710_i:=2;
  if -tw17710_i shr 1<>-1 then
    halt(1);
  if -tw17710_i-tw17710_i<>-4 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw22344.pas }
{$push}

begin
  if tw22344_countchars<>5 then
    halt(1);
end ;
{$pop}

{ Case tw4136.pas }
{$push}

begin
  if tw4136_f() <> 3 then
    halt(1);
end;
{$pop}

end.
