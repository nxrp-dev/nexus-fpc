{ Sets regression cases; original case IDs are retained below. }

{ Case tw11288.pp }
{$push}
{$mode delphi}

type
  tw11288_tenum1 = (en1, en2);
  tw11288_tenum2 = (en3, en4);

  tw11288_tset1 = set of tw11288_tenum1;
  tw11288_tset2 = set of tw11288_tenum2;

procedure tw11288_dosomethingwithset(ASet: tw11288_tset1); overload;
begin

end;

procedure tw11288_dosomethingwithset(ASet: tw11288_tset2); overload;
begin

end;
{$pop}

{ Case tw37806.pp }
{$push}
{$mode delphi}

procedure tw37806_turnsetelem<tw37806_tset, tw37806_telem>(var aSet: tw37806_tset; tw37806_aelem: tw37806_telem; tw37806_aon: Boolean);
begin
  if tw37806_aon then
    Include(aSet, tw37806_aelem)
  else
    Exclude(aSet, tw37806_aelem);
end;

type
  tw37806_telem = (One, Two, Three, Four, Five);
  tw37806_tset = set of tw37806_telem;

var
  tw37806_s: tw37806_tset = [];
{$pop}

{ Case tw38497.pp }
{$push}
{$mode delphi}

type
  tw38497_talphabet = (A, B, C);
  tw38497_talphabets = set of tw38497_talphabet;

  procedure tw38497_test<TEnum, TSet>(E: TEnum; tw38497_s: TSet);
  var
    tw38497_i: TEnum;
    B: Boolean;
  begin
    B := [E] <= tw38497_s;
    if E in tw38497_s then
      WriteLn(E);
    for tw38497_i := Low(TEnum) to High(TEnum) do
      if tw38497_i in tw38497_s then
      WriteLn(tw38497_i);
  end;
{$pop}

{ Case tw8172.pp }
{$push}
{$IFDEF FPC}
  {$mode delphi}

  {$packenum 1}
  {$packset 1}
{$ENDIF}

type
  { the flags that are sent with every message }
  tw8172_tnxmessageheaderflag = (
    {the message header is followed by a string}
    mhfErrorMessage,
    { reserved for future use }
    mhfReserved1,
    { reserved for future use }
    mhfReserved2,
    { reserved for future use }
    mhfReserved3,
    { reserved for future use }
    mhfReserved4,
    { reserved for future use }
    mhfReserved5,
    { reserved for future use }
    mhfReserved6,
    { reserved for future use }
    mhfReserved7
  );

  { set of Message flags }
  tw8172_tnxmessageheaderflags = set of tw8172_tnxmessageheaderflag;
{$pop}

begin
  { Case tw11288.pp }
  {$push}

  begin
tw11288_dosomethingwithset([en1]);
  end;
  {$pop}

  { Case tw37806.pp }
  {$push}

  begin
tw37806_turnsetelem<tw37806_tset, tw37806_telem>(tw37806_s, Two, True);
  tw37806_turnsetelem<tw37806_tset, tw37806_telem>(tw37806_s, Five, True);
  if not((Two in tw37806_s) and (Five in tw37806_s)) then
    Halt(1);
    //WriteLn('does not work');
  end;
  {$pop}

  { Case tw38497.pp }
  {$push}

  begin
tw38497_test<tw38497_talphabet, tw38497_talphabets>(A, [A, B]);
  end;
  {$pop}

  { Case tw8172.pp }
  {$push}
{$IFDEF FPC}
{$packenum 1}
{$packset 1}
{$ENDIF}
  begin
if SizeOf(tw8172_tnxmessageheaderflag)<>1 then
    halt(1);
  WriteLn(SizeOf(tw8172_tnxmessageheaderflag)); // should be 1, is 1
  WriteLn(SizeOf(tw8172_tnxmessageheaderflags)); // should be 1, is 4
  if SizeOf(tw8172_tnxmessageheaderflags)<>1 then
    halt(1);
  end;
  {$pop}

end.
