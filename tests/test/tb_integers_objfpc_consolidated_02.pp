{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tbsx1.pp }
{$push}




function tbsx1_test_byte: boolean;
var
  x8,f,r: byte;
  i: integer;
begin
  for i:=0 to 7 do
  begin
    x8:=1 shl i;
    f:=BsfByte(x8 or ((7-i) shl i));
    if (f<>i) then
    begin
      writeln('BsfByte($',hexstr(x8 or ((7-i) shl i),2),') returned ',f,', should be ',i);
      exit(false);
    end;
    r:=BsrByte(x8 or i);
    if r<>i then
    begin
      writeln('BsrByte($',hexstr(x8 or i,2),') returned ',r,', should be ',i);
      exit(false);
    end;
  end;
  x8:=random(0);
  f:=BsfByte(x8);
  if (f<>$ff) then
  begin
    writeln('BsfByte(',x8,') returned ',f,', should be ',$ff);
    exit(false);
  end;
  r:=BsrByte(x8);
  if r<>$ff then
  begin
    writeln('BsrByte(',x8,') returned ',r,', should be ',$ff);
    exit(false);
  end;
  result:=true;
end;

function tbsx1_test_word: boolean;
var
  x16: word;
  i,f,r: integer;
begin
  for i:=0 to 15 do
  begin
    x16:=1 shl i;
    f:=BsfWord(x16 or ((15-i) shl i));
    if (f<>i) then
    begin
      writeln('BsfWord(',x16,') returned ',f,', should be ',i);
      exit(false);
    end;
    r:=BsrWord(x16 or i);
    if r<>i then
    begin
      writeln('BsrWord(',x16,') returned ',r,', should be ',i);
      exit(false);
    end;
  end;
  x16:=random(0);
  f:=BsfWord(x16);
  if (f<>$ff) then
  begin
    writeln('BsfWord(',x16,') returned ',f,', should be ',$ff);
    exit(false);
  end;
  r:=BsrWord(x16);
  if r<>$ff then
  begin
    writeln('BsrWord(',x16,') returned ',r,', should be ',$ff);
    exit(false);
  end;
  result:=true;
end;

function tbsx1_test_dword: boolean;
var
  x32: cardinal;
  i,f,r: integer;
begin
  for i:=0 to 31 do
  begin
    x32:=cardinal(1) shl i;
    f:=BsfDWord(x32 or ((31-i) shl i));
    if (f<>i) then
    begin
      writeln('BsfDWord(',x32,') returned ',f,', should be ',i);
      exit(false);
    end;
    r:=BsrDWord(x32 or i);
    if r<>i then
    begin
      writeln('BsrDWord(',x32,') returned ',r,', should be ',i);
      exit(false);
    end;
  end;
  x32:=random(0);
  f:=BsfDWord(x32);
  if (f<>$ff) then
  begin
    writeln('BsfDWord(',x32,') returned ',f,', should be ',$ff);
    exit(false);
  end;
  r:=BsrDWord(x32);
  if r<>$ff then
  begin
    writeln('BsrDWord(',x32,') returned ',r,', should be ',$ff);
    exit(false);
  end;
  result:=true;
end;

function tbsx1_test_qword: boolean;
var
  x64: qword;
  i, f, r: integer;
begin
  for i:=0 to 63 do
  begin
    x64:=uint64(1) shl i;
    f:=BsfQWord(x64 or (uint64(63-i) shl i));
    if f<>i then begin
      writeln('BsfQWord(',x64,') returned ',f,', should be ',i);
      exit(false);
    end;
    r:=BsrQWord(x64 or i);
    if r<>i then begin
      writeln('BsrQWord(',x64,') returned ',r,', should be ',i);
      exit(false);
    end;
  end;
  x64:=random(0);
  f:=BsfQWord(x64);
  if (f<>$ff) then
  begin
    writeln('BsfQWord(',x64,') returned ',f,', should be ',$ff);
    exit(false);
  end;
  r:=BsrQWord(x64);
  if r<>$ff then
  begin
    writeln('BsrQWord(',x64,') returned ',r,', should be ',$ff);
    exit(false);
  end;
  result:=true;
end;


{$pop}

{ Case tnest2.pp }
{$push}


procedure tnest2_outer;

  procedure nest2(l: longint); forward;

  function nest(l: longint): longint;
    begin
      if l>1 then
        result:=nest(l-1)+nest(l-2)
      else
        begin
          result:=1;
          nest2(result);
        end;
    end;

  procedure nest2(l: longint);
    begin
      writeln(l);
    end;

begin
  if nest(3) <> 3 then
    halt(1);
  nest2(4);
end;


{$pop}

{ Case tnest4.pp }
{$push}


function tnest4_test: longint;

  function func(aa: integer): integer;

    function func_nested(b: integer): integer;
    begin
      if b < 10 then
        Result:=func_nested(b+1)
      else
        Result:=b;
      Inc(Result, aa);
    end;

  begin
    Result:=func_nested(0);
  end;

begin
  result:=func(10);
end;

function tnest4_test2: longint;
var
  i: integer;

  function func(aa: integer): integer;

    function func_nested(b: integer): integer;
    begin
      if b < 10 then
        Result:=func(b+1)
      else
        Result:=b;
    end;

  begin
    Result:=func_nested(aa);
    Inc(Result, i);
  end;

begin
  i:=100;
  result:=func(0);
end;


{$pop}

{ Case twarn1.pp }
{$push}


{$H+}

var
   twarn1_i: integer platform;

{$pop}

begin

{ Case tbsx1.pp }
{$push}

begin
  if tbsx1_test_byte then writeln('passed') else halt(1);
  if tbsx1_test_word then writeln('passed') else halt(1);
  if tbsx1_test_dword then writeln('passed') else halt(1);
  if tbsx1_test_qword then writeln('passed') else halt(1);
end;
{$pop}

{ Case tnest2.pp }
{$push}

begin
  tnest2_outer;
end;
{$pop}

{ Case tnest4.pp }
{$push}

begin
  if tnest4_test <> 120 then
    halt(1);
  if tnest4_test2 <> 1110 then
    halt(2);
  writeln('OK');
end;
{$pop}

{ Case twarn1.pp }
{$push}

{$H+}
begin
   {$warn symbol_platform off}
   twarn1_i := 1;
   {$warn symbol_platform off}
   twarn1_i := 2;
end;
{$pop}

end.
