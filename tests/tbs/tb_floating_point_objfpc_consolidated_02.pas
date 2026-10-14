{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses math;

{ Case tw12214.pas }
{$push}





var
  tw12214_X, tw12214_Y: double;
  tw12214_I: Integer;
  tw12214_SomeFloat, tw12214_SomeOtherFloat: Double;

{$pop}

{ Case tw26408.pas }
{$push}





function tw26408_EllipseRadialLength(Width, Height:Integer; EccentricAngle : Extended) : Extended;
var
  a, b, R : Extended;
begin
  a := Width div 2;
  b := Height div 2;
  R := Sqr(a)*Sqr(b);
  if R <> 0 then begin // tweak
    R := Sqrt(R / ((Sqr(b)*Sqr(Cos(DegToRad(EccentricAngle/16))))) +
      (Sqr(a)*Sqr(Sin(DegToRad(EccentricAngle/16)))));
  end;
  Result := R;
end;


{$pop}

{ Case tw37398.pas }
{$push}


{$H+}


var tw37398_d: double;
  tw37398_temp: Boolean;

{$pop}

{ Case tw41581.pas }
{$push}




function tw41581_Calc: Double; inline;
begin
  Result := Power(10, Floor(Log10(0.01)));
end;


{$pop}

begin

{ Case tw12214.pas }
{$push}

begin
  tw12214_X := -10.0;

  tw12214_SomeFloat := 1.0; { any value }
  tw12214_SomeOtherFloat := 1.0; { any value }

  for tw12214_I := 0 to 20 do
  begin
    { This line does *any* valid float operation, just to show that
      floating-point exception (that should be raised, catched and silenced
      by try..except below) somehow arrived here. }
    tw12214_SomeFloat := tw12214_I * tw12214_SomeOtherFloat;

    try
      { Any invalid fp operation. Tested on Sqrt(-10.0), Ln(-10.0).
        I use variable X to trick FPC into calculating this at run-time,
        otherwise "Error: Illegal constant passed to internal math function". }
      tw12214_Y := Sqrt(tw12214_X);
      ClearExceptions(false);
    except
      Writeln('silenced exception');
      { Here I silence eventual exception raised by ClearExceptions.
        (Yes, I could just do ClearExceptions(false) do achieve the same,
        but imagine that this is embedded in some complicated code
        where I really want to raise exception to jump outside
        in case of problems.) }
    end;
  end;
end;
{$pop}

{ Case tw26408.pas }
{$push}

begin
end;
{$pop}

{ Case tw37398.pas }
{$push}

{$H+}
begin
  tw37398_d := NaN;
  tw37398_temp := IsNan(tw37398_d) or (tw37398_d = 0);
  writeln(tw37398_temp);
end;
{$pop}

{ Case tw41581.pas }
{$push}

begin
  writeln(tw41581_Calc);
  if (tw41581_Calc>0.0100001) or (tw41581_Calc<0.0099999) then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
