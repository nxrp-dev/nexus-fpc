{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_integers_delphi_consolidated_02.pp }
{$push}
{ Consolidated integers regressions; original case IDs and assertions are retained. }




{ Case tw21267.pp }
{$push}




const
  tw21267_GameObjectClass_Get_Metal_Cost : function(team : integer) : Integer = Pointer($004CDFA0);


{$pop}

{ Case tw24129.pp }
{$push}




procedure tw24129_Test;

  function Next: integer;
    function Next: integer;
      function Next: integer;
      var
        Next: integer;
      begin

      end;
    begin

    end;
  begin

  end;

begin

end;


{$pop}

{ Case tw39933.pp }
{$push}



var tw39933_a: TArray<integer>;


{$pop}


{$pop}

{ Case thintdir1.pp }
{$push}



// test the possibility to use the hint modifiers as regular identifiers



type
  thintdir1_deprecated = integer;
const
  thintdir1_unimplemented = 1;
  thintdir1_platform = 2;
var
  thintdir1_experimental: thintdir1_deprecated = thintdir1_unimplemented;


{$pop}

{ Case tpointermath1.pp }
{$push}



{$IFDEF FPC}
  
{$ENDIF}
type
  {$POINTERMATH ON}
  tpointermath1_PByte = ^Byte; // Pointer arithmetic can be applied to types declared with PointerMath ON
  {$POINTERMATH OFF}
  tpointermath1_PInteger = ^Integer;
var
  tpointermath1_PB: tpointermath1_PByte;
  tpointermath1_PI: tpointermath1_PInteger;

{$pop}

begin

{ Case tb_integers_delphi_consolidated_02.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin

{ Case tw21267.pp }
{$push}

begin
end;
{$pop}

{ Case tw24129.pp }
{$push}

begin
end;
{$pop}

{ Case tw39933.pp }
{$push}

begin
  writeln ( tw39933_a = nil );
  writeln ( tw39933_a <> nil );
  writeln ( nil = tw39933_a );   // project1.lpr(10,17) Error: Operator is not overloaded: "Pointer" = "TArray$1$crc9F312717"
  writeln ( nil <> tw39933_a );  // project1.lpr(11,17) Error: Operator is not overloaded: "Pointer" = "TArray$1$crc9F312717"
end;
{$pop}

end;
{$pop}

{ Case thintdir1.pp }
{$push}

begin
end;
{$pop}

{ Case tpointermath1.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$POINTERMATH ON}
{$POINTERMATH OFF}
begin
  // This checks even with PointerMath=Off it still can be used for types declared with PointerMath=On
  tpointermath1_PB := tpointermath1_PB + 1;
  WriteLn(tpointermath1_PB[1]);
  {$POINTERMATH ON}
  // It can also be used if explicitely declared in the code
  tpointermath1_PI := tpointermath1_PI + 1;
  WriteLn(tpointermath1_PI[1]);
end;
{$pop}

end.
