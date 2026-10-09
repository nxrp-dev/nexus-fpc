{ Sets regression cases; original case IDs are retained below. }

{ Case tw0866.pp }
{$push}
{$mode objfpc}
Type
     tw0866_ts = set of (tse);
     tw0866_ts2 = set of (t1,t2);
     tw0866_enum3 = (tm1:=-1,t0,tp1);
     tw0866_ts3 = set of t0 .. tp1;
 var
    tw0866_f:tw0866_ts;
    tw0866_f2 : tw0866_ts2;
    tw0866_f3 : tw0866_ts3;
{$pop}

{ Case tw17846.pp }
{$push}
{$mode objfpc}

const
  tw17846_intvalue1 = $1;
  tw17846_intvalue2 = $2;
  tw17846_intvalue3 = $4;

type
  tw17846_tmyenum = (Value1, Value2, Value3);
  tw17846_tmyset = set of tw17846_tmyenum;

operator := (aRight: LongWord) aLeft: tw17846_tmyset;
begin
  aLeft := [];
  if aRight and tw17846_intvalue1 <> 0 then
    Include(aLeft, Value1);
  if aRight and tw17846_intvalue2 <> 0 then
    Include(aLeft, Value2);
  if aRight and tw17846_intvalue3 <> 0 then
    Include(aLeft, Value3);
end;

operator := (aRight: tw17846_tmyset) aLeft: LongWord;
begin
  aLeft := 0;
  if Value1 in aRight then
    aLeft := aLeft or tw17846_intvalue1;
  if Value2 in aRight then
    aLeft := aLeft or tw17846_intvalue2;
  if Value3 in aRight then
    aLeft := aLeft or tw17846_intvalue3;
end;

var
  tw17846_i: LongWord;
  tw17846_t: tw17846_tmyset;
{$pop}

begin
  { Case tw0866.pp }
  {$push}

  begin
tw0866_f2:=tw0866_f2+[t2];
 tw0866_f2:=tw0866_f2+[t1];
 tw0866_f:=tw0866_f+[tse]; // compiler says that set elements are not compatible
 { f3:=[tm1];}
  end;
  {$pop}

  { Case tw17846.pp }
  {$push}

  begin
tw17846_i := tw17846_intvalue1 or tw17846_intvalue3;
  tw17846_t := tw17846_i;
  if tw17846_t<>[value1,value3] then
    halt(1);
  tw17846_i:=0;
  tw17846_i:=tw17846_t;
  if tw17846_i<>(tw17846_intvalue1 or tw17846_intvalue3) then
    halt(2);
  end;
  {$pop}

end.
