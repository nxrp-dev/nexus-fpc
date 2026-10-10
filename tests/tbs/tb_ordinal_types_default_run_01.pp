{ Enumeration subranges, enumeration casts and distinct integer types. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0132.pp }
{$push}
{ Old file: tbs0154.pp }
{ Subrange types give type mismatch when assigning to   OK 0.99.7 (PFV) }

type
  tb0132_week=(tb0132_mon,tb0132_tue,tb0132_wed);
Var
    tb0132_w : tb0132_week;
    tb0132_w1 : tb0132_mon..tb0132_tue;
{$pop}

{ Case tb0383.pp }
{$push}
type
  tb0383_enum1 = (tb0383_one,tb0383_two,tb0383_three);
  tb0383_enum2 = (tb0383_een,tb0383_twee,tb0383_drie);

procedure tb0383_p1(tb0383_e:tb0383_enum1);
begin
end;

var
  tb0383_e2 : tb0383_enum2;
{$pop}

{ Case tb0409.pp }
{$push}
type
   tb0409_myl = type longint;

var
   tb0409_i1,tb0409_i2,tb0409_i3 : tb0409_myl;
   tb0409_l : longint;

procedure tb0409_p(tb0409_i : tb0409_myl);overload;
begin
end;

procedure tb0409_p(tb0409_i : longint);overload;
begin
end;
{$pop}

begin
  { Case tb0132.pp }
  {$push}
begin
  tb0132_w1:=tb0132_w;
end;
  {$pop}

  { Case tb0383.pp }
  {$push}
begin
  tb0383_e2:=tb0383_een;
  tb0383_p1(tb0383_enum1(tb0383_e2));
end;
  {$pop}

  { Case tb0409.pp }
  {$push}
begin
   tb0409_i1:=tb0409_i2+tb0409_i3;
   tb0409_l:=tb0409_i1+tb0409_l;
   inc(tb0409_i3);
end;
  {$pop}

end.
