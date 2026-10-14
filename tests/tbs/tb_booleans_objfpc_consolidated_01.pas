{ Consolidated booleans regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0454.pas }
{$push}

{ reported on fpc-devel by Jesus Reyes <jesusrmx@yahoo.com.mx> on 14 July 2003 }
{ as failing with 1.1                                                          }

var
  tb0454_a,tb0454_b: integer;
  tb0454_c,tb0454_d,tb0454_e,tb0454_f: boolean;

function tb0454_Ok: boolean;
begin
        result := ( tb0454_a = tb0454_b )
                and tb0454_c = tb0454_d
                and tb0454_e = tb0454_f;
end;

var
        tb0454_r: boolean;

{$pop}

{ Case tw12614.pas }
{$push}



Function tw12614_IntRes : int64;

begin
  Result:=3;
end;

Var
  tw12614_B : WordBool;


{$pop}

{ Case tw1470.pas }
{$push}


function tw1470_bbb (a1, a2: DWord): Boolean;
begin
        tw1470_bbb := False;
end;

procedure tw1470_a;
var
        i, j, k: DWord;

begin
        try
                i := 0;
                j := 1;

                while (True) do
                        begin
                                k := 2;

                                try
                                        if (not tw1470_bbb (i, j)) then
                                                break; {this break generates an invalid label}

                                        if (k = 2) then
                                                k := 3;

                                finally
                                        k := 2;
                                end;
                        end;

                for i := 1 to 20 do
                        j := j + 1;

                WriteLn (j);

        finally
                i := 0;
                j := 1;
        end;
end;


{$pop}

{ Case tw20874a.pas }
{$push}


{$H+}

var
  tw20874a_A, tw20874a_B : QWordBool;

{$pop}

{ Case tw41012.pas }
{$push}



function tw41012_GetFalse: Boolean;
begin
  Result := False;
end;

var
  tw41012_obj: TInterfacedObject;
  tw41012_i: Integer;


{$pop}

begin

{ Case tb0454.pas }
{$push}

begin
        tb0454_a := 1;
        tb0454_b := 2;
        tb0454_c := false;
        tb0454_d := true;
        tb0454_e := false;
        tb0454_f := true;

        tb0454_r := tb0454_Ok;
        if not tb0454_r then
          begin
            writeln('error, result should be true');
            halt(1);
          end;
end;
{$pop}

{ Case tw12614.pas }
{$push}

begin
  tw12614_B:=WordBool(tw12614_IntRes);
end;
{$pop}

{ Case tw1470.pas }
{$push}

begin
        tw1470_a;
end;
{$pop}

{ Case tw20874a.pas }
{$push}

{$H+}
begin
  tw20874a_A := True;

  // here it fails: qwordbooltest.pas(12,3) Fatal: Internal error 200109227
  tw20874a_B := not tw20874a_A;

  if tw20874a_B then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tw41012.pas }
{$push}

begin
  if tw41012_GetFalse and (tw41012_i >= 0) and (tw41012_i < tw41012_obj.RefCount) then;
end;
{$pop}

end.
