{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses math;

{ Case tw1792.pas }
{$push}


{$pop}

{ Case tw3005.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3005 }
{ Submitted by "Michalis Kamburelis" on  2004-03-04 }
{ e-mail: michalis@camelot.homedns.org }


{$pop}

{ Case tw39867.pas }
{$push}



{$pop}

{ Case tw4013.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4013 }
{ Submitted by "Miguel Garcia-Blanco" on  2005-05-25 }
{ e-mail: mgbonline@hotmail.com }





{$pop}

begin

{ Case tw1792.pas }
{$push}

Begin
 WriteLn(power(2,31));
end;
{$pop}

{ Case tw3005.pas }
{$push}

begin
 { This already works (result is integer) }
 Writeln((-2) ** 2);
 { Two things below do not work currently }
 Writeln(Power(-2.0, 2.0));
 if Power(-2.0, 2.0)<>4 then
   halt(1);
 Writeln((-2.0) ** 2.0);
 if (-2.0) ** 2.0<>4 then
   halt(1);
 writeln('ok');
end;
{$pop}

{ Case tw39867.pas }
{$push}

begin
  writeln(tanh(-354));
  if tanh(-354)<>-1 then
    halt(1);
  writeln(tanh(-355));
  if tanh(-355)<>-1 then
    halt(1);
end;
{$pop}

{ Case tw4013.pas }
{$push}

BEGIN

    writeln( 2.0**5.0 );

END;
{$pop}

end.
