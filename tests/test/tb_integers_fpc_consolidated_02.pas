{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %OPT=-Sew }
{ %NORUN }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tcasecov4.pas }
{$push}



var
  tcasecov4_l: longint;

{$pop}

{ Case tcasecov5.pas }
{$push}



{ should not print a warning }
var
  tcasecov5_l: qword;

{$pop}

{ Case tcasecov8.pas }
{$push}



const
  tcasecov8_OT_SIZE_MASK = $3000001F;
var
  tcasecov8_l: longint;

{$pop}

{ Case tinlrange4.pas }
{$push}



{$r+}
{$warnings on}

const
  tinlrange4_MH_MAGIC = $feedface;

var
  tinlrange4_c: cardinal;

{$pop}

begin

{ Case tcasecov4.pas }
{$push}

begin
  tcasecov4_l:=1;
  case tcasecov4_l of
    2: writeln;
  end;
end;
{$pop}

{ Case tcasecov5.pas }
{$push}

begin
  tcasecov5_l:=1;
  case tcasecov5_l of
    2: writeln;
  end;
end;
{$pop}

{ Case tcasecov8.pas }
{$push}

begin
  tcasecov8_l:=1;
  case tcasecov8_l and tcasecov8_OT_SIZE_MASK of
    1: writeln;
  end;
end;
{$pop}

{ Case tinlrange4.pas }
{$push}
{$r+}
{$warnings on}
begin
  tinlrange4_c:= NToBE(tinlrange4_MH_MAGIC);
end;
{$pop}

end.
