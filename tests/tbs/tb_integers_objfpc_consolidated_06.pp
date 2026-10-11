{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw35841.pp }
{$push}


procedure tw35841_p1;
  begin
    try
      writeln;
    except
      try
        writeln;
        Exit;
      finally
        writeln;
      end;
    end;
  end;


procedure tw35841_p2;
  var
    i : longint;
  begin
    for i:=1 to 10 do
      try
        writeln;
      except
        try
          writeln;
          break;
        finally
          writeln;
        end;
      end;
  end;

procedure tw35841_p3;
  var
    i : longint;
  begin
    for i:=1 to 10 do
      try
        writeln;
      except
        try
          writeln;
          continue;
        finally
          writeln;
        end;
      end;
  end;



{$pop}

{ Case tw37286.pp }
{$push}






var tw37286_preShiftWorldDx: LongInt;
  tw37286_WorldDx: LongInt;
  tw37286_playWidth: LongInt;

procedure tw37286_ShiftWorld(Dir: LongInt); inline;
begin
    tw37286_preShiftWorldDx:= tw37286_WorldDx;
    tw37286_WorldDx:= tw37286_WorldDx + LongInt(Dir * LongInt(tw37286_playWidth));

end;


{$pop}

{ Case tinlrange2.pp }
{$push}




{$r-}
function tinlrange2_test(l1, l2: longint): longint; inline;
begin
  result:=l1+l2;
end;

{ range checking state at caller site should not influence inline evaluation }
{$r+}

{$pop}

begin

{ Case tw35841.pp }
{$push}

begin
end;
{$pop}

{ Case tw37286.pp }
{$push}

begin
  tw37286_ShiftWorld(-1);
end;
{$pop}

{ Case tinlrange2.pp }
{$push}

{$r-}
{$r+}
begin
  tinlrange2_test(high(longint), 1);
end;
{$pop}

end.
