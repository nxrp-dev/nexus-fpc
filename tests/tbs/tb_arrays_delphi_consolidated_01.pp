{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw0789.pp }
{$push}




procedure tw0789_tt (params : array of const);
begin
// this call generate Access violation
  writeln (Format ('Params test %d', params));
end;


{$pop}

{ Case tw15727a.pp }
{$push}

{$r+}



procedure tw15727a_test(a: array of const);
begin
  if (a[0].vtype<>vtinteger) or
     (a[0].vinteger<>longint($f0f0f0f0)) then
    halt(1);
end;

var
  tw15727a_z: cardinal;

{$pop}

{ Case tw2807.pp }
{$push}




var
  tw2807_a:array of integer;

{$pop}

begin

{ Case tw0789.pp }
{$push}

begin
  writeln (Format ('First test %d', [1]));
  tw0789_tt ([1]);
end;
{$pop}

{ Case tw15727a.pp }
{$push}

{$r+}
begin
  tw15727a_Z:=$F0F0F0F0;
  // next line works OK
  writeln('Z=',tw15727a_Z);

  // next line produces compilation error "Error: range check error while evaluating constants"
  tw15727a_test([$F0F0F0F0]);

  // next line gives run-time error: "ERangeError : Range check error"
  tw15727a_test([tw15727a_Z]);
end;
{$pop}

{ Case tw2807.pp }
{$push}

begin
  tw2807_a := nil;
  SetLength(tw2807_a,3);
  tw2807_a[0] := 0;
  tw2807_a[1] := 1;
  tw2807_a[2] := 2;
  WriteLn(IntToStr(tw2807_a[0]));
  tw2807_a := nil;
end;
{$pop}

end.
