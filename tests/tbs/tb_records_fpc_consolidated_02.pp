{ Consolidated records regressions; original case IDs and assertions are retained. }
{ %OPT=-O2 }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw13948.pp }
{$push}


type
  tw13948_tr = record
    a,b: longint;
  end;

function tw13948_f: tw13948_tr;
begin
  tw13948_f.a:=5;
  tw13948_f.b:=6;
end;

procedure tw13948_test;
var
  r: tw13948_tr;
begin
  r.a:=1;
  r.b:=2;
  r.a:=tw13948_f.a;
  writeln(r.a);
  writeln(r.b);
  if (r.a<>5) then
    halt(1);
  if (r.b<>2) then
    halt(2);
end;


{$pop}

{ Case tw13948a.pp }
{$push}


type
  tw13948a_tr = record
    a: array[0..1] of longint;
  end;

function tw13948a_f: tw13948a_tr;
begin
  tw13948a_f.a[0]:=5;
  tw13948a_f.a[1]:=6;
end;

procedure tw13948a_test;
var
  r: tw13948a_tr;
begin
  r.a[0]:=1;
  r.a[1]:=2;
  r.a[0]:=tw13948a_f.a[0];
  writeln(r.a[0]);
  writeln(r.a[1]);
  if (r.a[0]<>5) then
    halt(1);
  if (r.a[1]<>2) then
    halt(2);
end;


{$pop}

{ Case tw8283.pp }
{$push}


type
  tw8283_Int96 = packed record
    case Integer of
      0:
        (
          {$IFDEF ENDIAN_LITTLE}
          Lo32 : DWord;
          case Integer of
            0:
              (
                Mid32 : DWord;
                Hi32 : LongInt;
              );
            1:
              ( Hi64: Int64; );
          {$ELSE ENDIAN_LITTLE}
          Hi32 : LongInt;
          case Integer of
            0:
              (
                Mid32 : DWord;
                Lo32 : DWord;
              );
            1:
              ( Lo64: QWord; );
          {$ENDIF ENDIAN_LITTLE}
        );
      1:
        (
          {$IFDEF ENDIAN_LITTLE}
          Lo64 : QWord;
          {$ELSE ENDIAN_LITTLE}
          Hi64 : Int64;
          {$ENDIF ENDIAN_LITTLE}
        );
  end;

function tw8283_f: tw8283_int96;
begin
end;

operator := (const Right: QWord) Result : tw8283_Int96; inline;
var
  c: tw8283_int96;
begin
  c := tw8283_f;
  Result.Lo64 := Right;
  Result.Hi32 := 0;
end;

procedure tw8283_Test;
var
  a : tw8283_Int96;
begin
  a := 500000000000000;
  if (a.lo64 <> 500000000000000) then
    halt(1);
end;


{$pop}

begin

{ Case tw13948.pp }
{$push}

begin
  tw13948_test;
end;
{$pop}

{ Case tw13948a.pp }
{$push}

begin
  tw13948a_test;
end;
{$pop}

{ Case tw8283.pp }
{$push}
{$IFDEF ENDIAN_LITTLE}
{$ELSE ENDIAN_LITTLE}
{$ENDIF ENDIAN_LITTLE}
{$IFDEF ENDIAN_LITTLE}
{$ELSE ENDIAN_LITTLE}
{$ENDIF ENDIAN_LITTLE}
begin
  tw8283_test
end;
{$pop}

end.
