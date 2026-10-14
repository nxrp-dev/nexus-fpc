{ %norun }
{ %opt=-Sen -vn }
{ No unused-variable notes for wide enum bounds or With assignments to array records. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tb0502.pas }
{$push}
type
      tb0502_tregister = (
        tb0502_tregisterlowenum := Low(longint),
        tb0502_tregisterhighenum := High(longint)
      );
{$pop}

{ Case tb0525.pas }
{$push}
type
 tb0525_tr = record
   tb0525_x, tb0525_y: longint;
 end;
 tb0525_ta = array[1..10] of tb0525_tr;

var
  tb0525_a: tb0525_ta;
  tb0525_i: longint;
{$pop}

begin
  { Case tb0502.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0525.pas }
  {$push}
begin
  for tb0525_i := low(tb0525_a) to high(tb0525_a) do
    with tb0525_a[tb0525_i] do
      begin
        tb0525_x:=tb0525_i*2;
        tb0525_y:=tb0525_i+5+tb0525_x;
      end;
end;
  {$pop}

end.
