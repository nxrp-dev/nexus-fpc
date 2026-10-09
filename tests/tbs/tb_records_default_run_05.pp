{ Records regression cases; original case IDs are retained below. }

{ Case tw41460c.pp }
{$push}
{$T-}
{ In T- mode, i.e. not in typed pointer mode,
  the difference between two pointers of the same type
  is divided by number of bytes between the two pointers }

type
   tw41460c_trecord = record
     tw41460c_first: word;
     tw41460c_second: qword;
   end;
   tw41460c_precord = ^tw41460c_trecord;

var
   tw41460c_res,tw41460c_res2 : PtrInt;
   tw41460c_rec : tw41460c_trecord;
{$pop}

{ Case tw41460d.pp }
{$push}
{$T-}

type
   tw41460d_trecord = record
     tw41460d_first: byte;
     tw41460d_second: byte;
     tw41460d_third: byte;
     tw41460d_fourth: byte;
   end;
   tw41460d_precord = ^tw41460d_trecord;

var
   tw41460d_res, tw41460d_res2, tw41460d_res3 : PtrInt;
   tw41460d_rec : tw41460d_trecord;
{$pop}

{ Case tw41743.pp }
{$push}
type
  tw41743_trecord = record
    tw41743_w1,tw41743_w2,tw41743_w3,tw41743_w4 : word;
  end;

var
  tw41743_w1 : word;
  tw41743_b1 : byte;
  tw41743_rec : tw41743_trecord;
  tw41743_errorcount : longint;
{$pop}

{ Case tw4624.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4624 }
{ Submitted by "benoit sanchez" on  2005-12-20 }
{ e-mail: sanchez@clipper.ens.fr }
type tw4624_number=record
  tw4624_value:boolean;
end;

operator div (tw4624_a,b:tw4624_number) c:tw4624_number;
begin
  c.tw4624_value:=true;
end;

var tw4624_a:tw4624_number;
{$pop}

begin
  { Case tw41460c.pp }
  {$push}
{$T-}
  begin
tw41460c_res := @(tw41460c_precord(@tw41460c_rec)^.tw41460c_second) - @(tw41460c_precord(@tw41460c_rec)^.tw41460c_first);
   writeln('Offset of Second field inside TRecord is ',tw41460c_res);
   if (tw41460c_res<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(1);
     end;
   tw41460c_res2 := @(tw41460c_precord(nil)^.tw41460c_second) - @(tw41460c_precord(nil)^.tw41460c_first);
   writeln('Offset of Second field inside TRecord  using constant pointers is ',tw41460c_res2);
   if (tw41460c_res2<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(2);
     end;
   if (tw41460c_res2<>tw41460c_res) then
     begin
       writeln('Inconsistent result for offset of second field');
       halt(3);
     end;
  end;
  {$pop}

  { Case tw41460d.pp }
  {$push}
{$T-}
  begin
tw41460d_res := @(tw41460d_precord(nil)^.tw41460d_fourth) - @(tw41460d_precord(nil)^.tw41460d_first);
   writeln('Offset of Fourth field inside TRecord is ',tw41460d_res);
   if (tw41460d_res<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(1);
     end;
   tw41460d_res2 := @(tw41460d_precord(@tw41460d_rec)^.tw41460d_fourth) - @(tw41460d_precord(@tw41460d_rec)^.tw41460d_first);
   writeln('Offset of Fourth field inside TRecord is ',tw41460d_res2);
   if (tw41460d_res2<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(2);
     end;
   if (tw41460d_res<>tw41460d_res2) then
     begin
       writeln('Inconsistent results for Offset of Fourth field between constant and non-constant pointers');
       halt(3);
     end;
   tw41460d_res3 := @(tw41460d_rec.tw41460d_fourth) - @(tw41460d_rec.tw41460d_first);
   if (tw41460d_res3<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(4);
     end;
   if (tw41460d_res<>tw41460d_res3) then
     begin
       writeln('Inconsistent results for Offset of Fourth field between constant and non-constant pointers');
       halt(5);
     end;
  end;
  {$pop}

  { Case tw41743.pp }
  {$push}

  begin
tw41743_errorcount:=0;
  tw41743_b1:=$57;
  tw41743_w1:=$2D57;
  tw41743_rec.tw41743_w1:=tw41743_w1;
  if (byte(tw41743_rec.tw41743_w1)<>tw41743_b1) then
    inc(tw41743_errorcount,3);
  if (tw41743_rec.tw41743_w1=tw41743_b1) then
    inc(tw41743_errorcount,4);
  halt(tw41743_errorcount);
  end;
  {$pop}

  { Case tw4624.pp }
  {$push}

  begin
tw4624_a:=tw4624_a div tw4624_a;
  end;
  {$pop}

end.
