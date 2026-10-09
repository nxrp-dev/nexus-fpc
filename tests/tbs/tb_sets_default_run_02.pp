{ Sets regression cases; original case IDs are retained below. }

{ Case tw10033.pp }
{$push}
// tests writing of high()/low() of enumeration values, i.e.
// writing and reading of rtti for enums, both "dense" and
// "sparse" enumerations (different rtti is generated and
// different code used for generating and reading)
type
  // "dense" unnamed enumeration
  tw10033_txx = set of (_one, _two, _three);
  // "sparse" unnamed enumeration
  tw10033_tyy = set of (_zero := 0, _ten := 10, _twenty := 20);

  // "dense" enumeration
  tw10033_tx = (one,two,three);
  tw10033_txxx = set of tw10033_tx;
  // "sparse" enumeration
  tw10033_ty = (zero := 0, ten := 10, twenty := 20);
  tw10033_tyyy = set of tw10033_ty;

procedure tw10033_error(number : longint);
begin
  writeln('error ', number);
  halt(number);
end;

var
  tw10033_x : tw10033_txxx;
  tw10033_y : tw10033_tyyy;
  tw10033_err : word;

  tw10033__x : tw10033_txx;
  tw10033__y : tw10033_tyy;
{$pop}

{ Case tw4477.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4477 }
{ Submitted by "Alexey Moiseitsev" on  2005-10-30 }
{ e-mail: himeraster@gmail.com }
var tw4477_f : set of boolean;
{$pop}

{ Case tw4606.pp }
{$push}
{$packset 1}
type
  tw4606_tlettersset=set of 'a'..'z';
{$pop}

{ Case tw6735.pp }
{$push}
type
  tw6735_t=packed set of 0..7;
{$pop}

{ Case tw9167.pp }
{$push}
type
  tw9167_tshiftstateenum = (ssShift, ssAlt, ssCtrl,
    ssLeft, ssRight, ssMiddle, ssDouble,
    // Extra additions
    ssMeta, ssSuper, ssHyper, ssAltGr, ssCaps, ssNum,
    ssScroll,ssTriple,ssQuad);

{$packset 1}
  tw9167_tshiftstate = set of tw9167_tshiftstateenum;
{$packset default}

var
  tw9167_s: tw9167_tshiftstate;
  tw9167_ss: tw9167_tshiftstateenum;
{$pop}

begin
  { Case tw10033.pp }
  {$push}

  begin
writeln(low(tw10033__x));
  writeln(high(tw10033__x));

  writeln(low(tw10033__y));
  writeln(high(tw10033__y));

  writeln(low(tw10033_x));
  writeln(high(tw10033_x));

  writeln(low(tw10033_y));
  writeln(high(tw10033_y));
  end;
  {$pop}

  { Case tw4606.pp }
  {$push}
{$packset 1}
  begin
if sizeof(tw4606_tlettersset)<>4 then
    begin
      writeln(sizeof(tw4606_tlettersset));
      halt(1);
    end;
  end;
  {$pop}

  { Case tw9167.pp }
  {$push}
{$packset 1}
{$packset default}
  begin
tw9167_s := [];
  tw9167_ss:=ssShift;
  include(tw9167_s,tw9167_ss);
  include(tw9167_s,ssSuper);
  if not(ssShift in tw9167_s) or
     not(ssSuper in tw9167_s) then
    halt(1);
  if not(tw9167_ss in tw9167_s) then
    halt(2);
  end;
  {$pop}

end.
