{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes;

{ Case tw13890.pas }
{$push}

{$ifdef fpc}{$h+}{$endif}



var
  tw13890_bits: TBits;
  tw13890_i, tw13890_j: Integer;
  tw13890_count: Integer;

procedure tw13890_AllocateSomething;
begin
  Inc(tw13890_count);
end;


{$pop}

{ Case tw25398.pas }
{$push}
{$h+}


var
  tw25398_b: tbits;
  tw25398_i: integer;


{$pop}

{ Case tw38225.pas }
{$push}
{$inline on}



operator - (const A: TPoint): TPoint; inline;
begin
  Result.X := - A.X;
  Result.Y := - A.Y;
end;

operator div(const A: TPoint; ADivisor: Integer): TPoint; inline;
begin
  Result.X := A.X div ADivisor;
  Result.Y := A.Y div ADivisor;
end;


procedure tw38225_p;
  var
    i1,i2 : longint;
    q1,q2 : int64;
    d2 : dword;
    p1,p2 : TPoint;

  begin
    p2:=-p2 div 2;
    try
      p2:=-p2 div 2;
    except
      p2:=-p2 div 2;
    end;
  end;


{$pop}

begin

{ Case tw13890.pas }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
begin
  tw13890_bits := TBits.Create;
  tw13890_count := 0;
  for tw13890_i := 0 to 9 do
  begin
    tw13890_j := tw13890_bits.OpenBit;
    if tw13890_j = tw13890_bits.Size then
    begin
      tw13890_AllocateSomething;
      tw13890_bits[tw13890_j] := True;
    end;
  end;
  tw13890_bits.Free;
  writeln(tw13890_count);
  if tw13890_count <> 10 then
    Halt(1);
end;
{$pop}

{ Case tw25398.pas }
{$push}

{$h+}
begin
  tw25398_b:= TBits.Create;
  tw25398_b.Size:= 128;
  tw25398_b.SetOn(0);
  tw25398_b.SetOn(13);
  tw25398_b.SetOn(118);
  tw25398_i:= tw25398_b.FindFirstBit(True);
  if tw25398_i<>0 then
    halt(1);
  tw25398_i:= tw25398_b.FindNextBit;
  if tw25398_i<>13 then
    halt(2);
  tw25398_i:= tw25398_b.FindNextBit;
  if tw25398_i<>118 then
    halt(3);
  tw25398_i:= tw25398_b.FindNextBit;
  if tw25398_i<>-1 then
    halt(4);
end;
{$pop}

{ Case tw38225.pas }
{$push}
{$inline on}

begin
end;
{$pop}

end.
