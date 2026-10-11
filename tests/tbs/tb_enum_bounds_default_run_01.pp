{ Enum subrange bounds and conversion from enum names. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tw1310.pp }
{$push}
type
  tw1310_days     = (tw1310_mon, tw1310_tue, tw1310_wed, tw1310_thu, tw1310_fri, tw1310_sat, tw1310_sun);
  tw1310_weekdays = tw1310_mon..tw1310_fri;
  tw1310_weekend  = tw1310_sat..tw1310_sun;
{$pop}

{ Case tw11176.pp }
{$push}
type
  tw11176_tx = (one,two,three);

procedure tw11176_error(tw11176_number : longint);
begin
  writeln('error ', tw11176_number);
  halt(tw11176_number);
end;

var
  tw11176_a : tw11176_tx;
  tw11176_err : word;
{$pop}

begin
  { Case tw1310.pp }
  {$push}
begin
  WriteLn('Days     ', Ord(Low(tw1310_days))    , Ord(High(tw1310_days))    :2);
  WriteLn('Weekdays ', Ord(Low(tw1310_weekdays)), Ord(High(tw1310_weekdays)):2, ' should be 4!');
  WriteLn('Weekend  ', Ord(Low(tw1310_weekend)) , Ord(High(tw1310_weekend)) :2);
  if ord(high(tw1310_weekdays))<>4 then
   begin
     writeln('ERROR!');
     Halt(1);
   end;
end;
  {$pop}

  { Case tw11176.pp }
  {$push}
begin
  val('one', tw11176_a, tw11176_err);
  if (tw11176_err <> 0) or (tw11176_a <> one) then tw11176_error(1);
end;
  {$pop}

end.
