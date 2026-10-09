{ Records regression cases; original case IDs are retained below. }

{ Case tw12000.pp }
{$push}
{$mode objfpc}{$H+}

type
  tw12000_trec = record
    tw12000_signature: array of Integer;
    tw12000_s: ansistring;
  end;

var
  tw12000_m: array of tw12000_trec;
  tw12000_s2: ansistring;
{$pop}

{ Case tw21505a.pp }
{$push}
{$mode objfpc}{$H+}

type
  tw21505a_pposlist = ^tw21505a_tposlist;
  tw21505a_tposlist = record
    tw21505a_elem : Double;
    tw21505a_tail : ^tw21505a_tposlist;
  end;

  operator >< (e : single; tw21505a_list : tw21505a_pposlist) : tw21505a_pposlist;
  begin
    new (result);
    result^.tw21505a_elem := e;
    result^.tw21505a_tail := tw21505a_list;
  end;

var
  tw21505a_list : tw21505a_pposlist;
{$pop}

{ Case tw30329.pp }
{$push}
{$mode objfpc}{$H+}

type
  tw30329_tgf2dpoint = array[0..1] of Single;

  tw30329_tgf2doutbox = packed record
    tw30329_fmin, tw30329_fmax: tw30329_tgf2dpoint;
  end;

function tw30329_some2doutbox : tw30329_tgf2doutbox;
begin
  Result.tw30329_fmin[0]:=1.0;
  Result.tw30329_fmin[1]:=2.0;
  Result.tw30329_fmax[0]:=3.0;
  Result.tw30329_fmax[1]:=4.0;
end;

var
  tw30329_outbox : tw30329_tgf2doutbox;
{$pop}

begin
  { Case tw12000.pp }
  {$push}

  begin
SetLength(tw12000_m,2);
  SetLength(tw12000_m[0].tw12000_signature,4);
  SetLength(tw12000_m[1].tw12000_signature,4);
  setlength(tw12000_m[0].tw12000_s,2);
  tw12000_s2:=tw12000_m[0].tw12000_s;
  WriteLn(Length(tw12000_m[0].tw12000_signature), ' ', Length(tw12000_m[1].tw12000_signature));
  writeln(length(tw12000_m[0].tw12000_s));
  tw12000_m[0].tw12000_signature := tw12000_m[0].tw12000_signature;
  tw12000_m[0].tw12000_s:=tw12000_m[0].tw12000_s;
  WriteLn(Length(tw12000_m[0].tw12000_signature), ' ', Length(tw12000_m[1].tw12000_signature));
  writeln(length(tw12000_m[0].tw12000_s));
  tw12000_s2:='';
  if (Length(tw12000_m[0].tw12000_signature) <> 4) then
    halt(1);
  if (Length(tw12000_m[0].tw12000_s) <> 2) then
    halt(2);
  end;
  {$pop}

  { Case tw21505a.pp }
  {$push}

  begin
// This makes Fatal: Internal error 2008022101
//  list := 1.0 >< 3.0 >< 5.0 >< 7.0 >< 9.0 >< nil;
// This says Error: Operation "><" not supported for types "ShortInt" and "Pointer"
  tw21505a_list := 1.0 >< (3.0 >< (5.0 >< (7.0 >< (9.0 >< nil))));
  if tw21505a_list^.tw21505a_elem<>1.0 then
    halt(1);
  if tw21505a_list^.tw21505a_tail^.tw21505a_elem<>3.0 then
    halt(2);
  if tw21505a_list^.tw21505a_tail^.tw21505a_tail^.tw21505a_elem<>5.0 then
    halt(3);
  if tw21505a_list^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail^.tw21505a_elem<>7.0 then
    halt(4);
  if tw21505a_list^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail^.tw21505a_elem<>9.0 then
    halt(5);
  if tw21505a_list^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail^.tw21505a_tail<>nil then
    halt(6);
  end;
  {$pop}

  { Case tw30329.pp }
  {$push}

  begin
tw30329_outbox:=tw30329_some2doutbox;
  with tw30329_outbox do
    if (tw30329_fmin[0]<>1.0) or
       (tw30329_fmin[1]<>2.0) or
       (tw30329_fmax[0]<>3.0) or
       (tw30329_fmax[1]<>4.0) then
      halt(1);
  end;
  {$pop}

end.
