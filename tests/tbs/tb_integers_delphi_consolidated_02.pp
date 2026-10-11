{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

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

end.
