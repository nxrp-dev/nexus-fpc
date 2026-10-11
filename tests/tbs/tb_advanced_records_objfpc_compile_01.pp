{ %norun }
{ Generic self-referential records and advanced-record operators. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}
{$modeswitch advancedrecords}

{ Case tb0623.pp }
{$push}
type
  generic tb0623_ttest<T> = record
  public type
    PSelf = ^specialize tb0623_ttest<T>;
  public
    Next: PSelf;
  end;

  generic tb0623_ttest2<T> = record
    Next: ^specialize tb0623_ttest2<T>;
  end;

  tb0623_ttestlongint = specialize tb0623_ttest<LongInt>;
  tb0623_tteststring = specialize tb0623_ttest<String>;

  tb0623_ttest2longint = specialize tb0623_ttest2<LongInt>;
  tb0623_ttest2string = specialize tb0623_ttest2<String>;
{$pop}

{ Case tb0680.pp }
{$push}
{$H+}
type
  tb0680_ttest = record
    class operator + (aLeft, aRight: tb0680_ttest): tb0680_ttest;
    function Plus(aLeft, aRight: tb0680_ttest): tb0680_ttest;
  end;

class operator tb0680_ttest.+(aLeft, aRight: tb0680_ttest): tb0680_ttest;
begin

end;

function tb0680_ttest.Plus(aLeft, aRight: tb0680_ttest): tb0680_ttest;
begin

end;
{$pop}

{ Case tw27750b.pp }
{$push}
{$modeswitch advancedrecords}

type

  { TGeneric }

  generic tw27750b_tgeneric<tw27750b_foo, tw27750b_bar> = record
  public type
    tw27750b_tgfb = specialize tw27750b_tgeneric<tw27750b_foo, tw27750b_bar>;
  public
    class operator :=(tw27750b_afoo : tw27750b_foo) : tw27750b_tgfb;
    class operator :=(tw27750b_abar : tw27750b_bar) : tw27750b_tgfb;
  end;

{ TGeneric }

class operator tw27750b_tgeneric.:=(tw27750b_afoo: tw27750b_foo): tw27750b_tgfb;
begin

end;

class operator tw27750b_tgeneric.:=(tw27750b_abar: tw27750b_bar): tw27750b_tgfb;
begin

end;
{$pop}

begin
  { Case tb0623.pp }
  {$push}
begin

end;
  {$pop}

  { Case tb0680.pp }
  {$push}
begin

end;
  {$pop}

  { Case tw27750b.pp }
  {$push}
begin
end;
  {$pop}

end.
