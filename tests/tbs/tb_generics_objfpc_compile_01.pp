{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tb0677.pp }
{$push}
{$mode objfpc}

type
  tb0677_tenum = (eOne, eTwo, eThree, eFour);
  tb0677_tset = set of tb0677_tenum;

  generic tb0677_ttest<SetType, EnumType> = class
    procedure tb0677_test;
  end;

procedure tb0677_ttest.tb0677_test;
var
  tb0677_s1: tb0677_tset;
  tb0677_s2: SetType;
  tb0677_e1: tb0677_tenum;
  tb0677_e2: EnumType;
begin
  Include(tb0677_s1, tb0677_e1);
  Exclude(tb0677_s1, tb0677_e1);

  Include(tb0677_s2, tb0677_e1);
  Exclude(tb0677_s2, tb0677_e1);

  Include(tb0677_s2, tb0677_e2);
  Exclude(tb0677_s2, tb0677_e2);

  Include(tb0677_s2, tb0677_e1);
  Exclude(tb0677_s2, tb0677_e2);
end;

type
  tb0677_ttesttypes = specialize tb0677_ttest<tb0677_tset, tb0677_tenum>;
{$pop}

{ Case tw27424.pp }
{$push}
{$mode objfpc}

type
  tw27424_ttype = class(TObject)
  end;

  generic TTest<T1; tw27424_t2: tw27424_ttype> = class(TObject)
  end;

  tw27424_tfoo = class(tw27424_ttype)
  end;

  tw27424_tbar = class(specialize TTest<string, tw27424_tfoo>)
  end;
{$pop}

{ Case tw28530.pp }
{$push}
{$mode objfpc}

type
  generic tw28530_tdistancefunction<t> = function (tw28530_x,tw28530_y : t) : Extended;

  generic tw28530_planarcoordinate<t> = record
    tw28530_x,tw28530_y : t;
    tw28530_d : specialize tw28530_tdistancefunction<t>;
  end;
  tw28530_tscreencoordinate = specialize tw28530_planarcoordinate<word>;
  tw28530_tdiscretecoordinate = specialize tw28530_planarcoordinate<integer>;
  tw28530_trealcoordinate = specialize tw28530_planarcoordinate<extended>;

  tw28530_tscreendistance = specialize tw28530_tdistancefunction<word>;
  tw28530_tdiscretedistance = specialize tw28530_tdistancefunction<integer>;
  tw28530_trealdistance = specialize tw28530_tdistancefunction<Extended>;

  generic tw28530_tpointset<t> = array of specialize tw28530_planarcoordinate<t>;
{$pop}

{ Case tw28674.pp }
{$push}
{$mode objfpc}

type
  generic tw28674_node<T> = object
    tw28674_data: T;
    tw28674_link: ^tw28674_node;
  end;

  tw28674_tintnode = specialize tw28674_node<int32>;
{$pop}

{ Case tw29053b.pp }
{$push}
{$mode objfpc}

type
  generic tw29053b_tmodelarray<T: TObject> = array of T;
{$pop}

{ Case tw30830a.pp }
{$push}
{$mode objfpc}

type
  generic tw30830a_tbase<T> = class
    procedure tw30830a_test1(const a: T);
  end;

  generic tw30830a_tderived<T> = class(specialize tw30830a_tbase<T>)
    procedure tw30830a_test2(const a: T);
  end;

procedure tw30830a_tbase.tw30830a_test1(const a: T);
begin
end;

procedure tw30830a_tderived.tw30830a_test2(const a: T);
begin
end;

generic procedure tw30830a_test<T>(aIntf: specialize tw30830a_tbase<T>); // works
begin
end;

generic procedure tw30830a_test<T>(aIntf: specialize tw30830a_tderived<T>); // SIGSEGV :(
begin
end;

var
  tw30830a_b: specialize tw30830a_tbase<LongInt>;
  tw30830a_d: specialize tw30830a_tderived<LongInt>;
{$pop}

{ Case tw30832.pp }
{$push}
{$mode objfpc}

type
  generic tw30832_ttest<T> = class
    procedure tw30832_test;
  end;

procedure tw30832_ttest.tw30832_test;
begin
  try
    Writeln(Default(T));
  finally
    Writeln('Finally');
  end;
end;

generic procedure tw30832_test<T>;
begin
  try
    Writeln(Default(T));
  finally
    Writeln('Finally');
  end;
end;
{$pop}

{ Case tw31120.pp }
{$push}
{$mode objfpc}

type
  tw31120_ttest = class
    generic class procedure tw31120_printdefault<T>();
  end;

generic Function tw31120_getdefault<T>(): T;
  Begin
    result := default(T);
  End;

generic Procedure tw31120_printdefault<T>();
  procedure tw31120_print();
    begin
      writeln(specialize tw31120_getdefault<T>())
    end;

  Begin
    tw31120_print()
  End;

generic class procedure tw31120_ttest.tw31120_printdefault<T>();
  procedure tw31120_print();
    begin
      writeln(specialize tw31120_getdefault<T>())
    end;

begin
  tw31120_print()
end;
{$pop}

{ Case tw35670a.pp }
{$push}
{$mode objfpc}

generic procedure tw35670a_dothis<T>(msg: T);
begin
end;

procedure tw35670a_dothis(msg: TObject);
begin
end;
{$pop}

{ Case tw37650.pp }
{$push}
{$mode objfpc}

type
  generic tw37650_tmyclass<const U: Integer> = class
    type tw37650_tkey = String[U];
  end;

generic procedure tw37650_test<const U: Integer>;
type
  tw37650_tkey = String[U];
begin
end;

type
  tw37650_tmyclass12 = specialize tw37650_tmyclass<12>;
{$pop}

{ Case tw40708.pp }
{$push}
{$mode objfpc}

type generic tw40708_tmatrix4<T> = array[0..3] of array [0..3] of T; // works
type generic tw40708_tanothermatrix4<T> = array[0..3,0..3] of T; // "Identifier not found T"

type tw40708_tmatrix4longint = specialize tw40708_tmatrix4<LongInt>;
type tw40708_tanothermatrix4longint = specialize tw40708_tanothermatrix4<LongInt>;
{$pop}

{ Case tw40712a.pp }
{$push}
{$mode objfpc}
type
  generic tw40712a_tsomegeneric<T> = object
  type
      tw40712a_tmine = T;
  var
      tw40712a_data: record
        tw40712a_value: tw40712a_tmine;
      end;
  end;
  tw40712a_tsomegeneric2 = object(specialize tw40712a_tsomegeneric<Integer>)
  end;
{$pop}

begin
  { Case tw30830a.pp }
  {$push}

  begin
specialize tw30830a_test<LongInt>(tw30830a_b);
  specialize tw30830a_test<LongInt>(tw30830a_d);
  end;
  {$pop}

  { Case tw30832.pp }
  {$push}

  begin
specialize tw30832_test<LongInt>;
  end;
  {$pop}

  { Case tw31120.pp }
  {$push}

  begin
specialize tw31120_printdefault<LongInt>();
  specialize tw31120_printdefault<String>();
  tw31120_ttest.specialize tw31120_printdefault<Boolean>();
  tw31120_ttest.specialize tw31120_printdefault<Char>();
  end;
  {$pop}

  { Case tw37650.pp }
  {$push}

  begin
specialize tw37650_test<12>;
  end;
  {$pop}

end.
