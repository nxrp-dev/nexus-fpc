{ Records regression cases; original case IDs are retained below. }

{ Case tw38766.pp }
{$push}
{$mode objfpc}

type
  tw38766_trec = record
    tw38766_x, tw38766_y: longint;
  end;

function tw38766_max(tw38766_x,tw38766_y: longint): longint;
begin
  if tw38766_x>tw38766_y then
    result:=tw38766_x
  else
    result:=tw38766_y;
end;

function tw38766_test: tw38766_trec; inline;
begin
 result.tw38766_x:=1;
 result.tw38766_y:=2;
 result.tw38766_x:=tw38766_max(result.tw38766_x,result.tw38766_y);
end;
{$pop}

{ Case tw39665.pp }
{$push}
{$mode objfpc}
type
	tw39665_pbcontainer = ^tw39665_bcontainer;
	tw39665_bcontainer = record
		tw39665_b: int32;
	end;

	tw39665_pmyobj = ^tw39665_myobj;
	tw39665_myobj = record
		tw39665_dummy: int32;
		tw39665_a: int32;
		tw39665_bctr: tw39665_bcontainer;
	end;

const
	tw39665_aofs = PtrUint(@tw39665_pmyobj(nil)^.tw39665_a);
	tw39665_bofs = PtrUint(@tw39665_pmyobj(nil)^.tw39665_bctr.tw39665_b); // does not compile
	tw39665_bofs2 = PtrUint(@tw39665_pmyobj(nil)^.tw39665_bctr) + PtrUint(@tw39665_pbcontainer(nil)^.tw39665_b); // ugly workaround

	function tw39665_myobjfroma_suboffsetof(aPtr: PInt32): tw39665_pmyobj;
	begin
		result := pointer(aPtr) - PtrUint(@tw39665_pmyobj(nil)^.tw39665_a);
	end;

	function tw39665_myobjfroma_subconst(aPtr: PInt32): tw39665_pmyobj;
	begin
		result := pointer(aPtr) - tw39665_aofs;
	end;

	function tw39665_myobjfromb_suboffsetof(bPtr: PInt32): tw39665_pmyobj;
	begin
		result := pointer(bPtr) - PtrUint(@tw39665_pmyobj(nil)^.tw39665_bctr.tw39665_b);
	end;

	function tw39665_myobjfromb_subconst(bPtr: PInt32): tw39665_pmyobj;
	begin
		result := pointer(bPtr) - tw39665_bofs;
	end;

var
	tw39665_mo: tw39665_myobj;
{$pop}

begin
  { Case tw38766.pp }
  {$push}

  begin
if tw38766_test.tw38766_x<>2 then
    halt(1);
  if tw38766_test.tw38766_y<>2 then
    halt(2);
  end;
  {$pop}

  { Case tw39665.pp }
  {$push}

  begin
writeln('''a'' offset in ''MyObj'': ', tw39665_aofs);
	writeln('''b'' offset in ''MyObj'': ', tw39665_bofs);
    if tw39665_bofs<>tw39665_bofs2 then
      halt(1);
	writeln('@mo: ', HexStr(@tw39665_mo));
	writeln('@mo recovered from @mo.a by subtracting "offsetof": ', HexStr(tw39665_myobjfroma_suboffsetof(@tw39665_mo.tw39665_a)));
	writeln('@mo recovered from @mo.a by subtracting constant:   ', HexStr(tw39665_myobjfroma_subconst(@tw39665_mo.tw39665_a)));
	writeln('@mo recovered from @mo.b by subtracting "offsetof": ', HexStr(tw39665_myobjfromb_suboffsetof(@tw39665_mo.tw39665_bctr.tw39665_b)));
	writeln('@mo recovered from @mo.b by subtracting constant:   ', HexStr(tw39665_myobjfromb_subconst(@tw39665_mo.tw39665_bctr.tw39665_b)));
  end;
  {$pop}

end.
