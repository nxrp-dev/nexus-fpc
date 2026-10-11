{ Consolidated control flow regressions; original case IDs and assertions are retained. }
{ %OPT=-Sew -vw }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw11937.pp }
{$push}

{$region}
{$endregion}

{$pop}

{ Case tw3567.pp }
{$push}


(*$WEAKPACKAGEUNIT*)
(*$HPPEMIT '#include "some_include.h"' *)
(*$NODEFINE xxx*)

{$pop}

{ Case tw4330.pp }
{$push}


{$A+}
{$A-}
{$A1}
{$A2}
{$A4}
{$A8}
{$ALIGN ON}
{$ALIGN OFF}
{$ALIGN 1}
{$ALIGN 2}
{$ALIGN 4}
{$ALIGN 8}


{$pop}

{ Case tw4332.pp }
{$push}


{$W+}
{$W-}
{$STACKFRAMES ON}
{$STACKFRAMES OFF}


{$pop}

begin

{ Case tw11937.pp }
{$push}
{$region}
{$endregion}
begin
end;
{$pop}

{ Case tw3567.pp }
{$push}
(*$WEAKPACKAGEUNIT*)
(*$HPPEMIT '#include "some_include.h"' *)
(*$NODEFINE xxx*)
begin
end;
{$pop}

{ Case tw4330.pp }
{$push}
{$A+}
{$A-}
{$A1}
{$A2}
{$A4}
{$A8}
{$ALIGN ON}
{$ALIGN OFF}
{$ALIGN 1}
{$ALIGN 2}
{$ALIGN 4}
{$ALIGN 8}
begin
end;
{$pop}

{ Case tw4332.pp }
{$push}
{$W+}
{$W-}
{$STACKFRAMES ON}
{$STACKFRAMES OFF}
begin
end;
{$pop}

end.
