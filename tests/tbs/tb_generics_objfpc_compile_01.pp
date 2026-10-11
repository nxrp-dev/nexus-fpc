{ %norun }
{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode objfpc}
{$ModeSwitch implicitfunctionspecialization}
{$modeswitch ADVANCEDRECORDS}
{$modeswitch advancedrecords}
{$modeswitch AdvancedRecords}

{ Source group: tb_generics_objfpc_compile_01.pp }
{$push}

{ Case tb0677.pp }
{$push}


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


type
  generic tw28674_node<T> = object
    tw28674_data: T;
    tw28674_link: ^tw28674_node;
  end;

  tw28674_tintnode = specialize tw28674_node<int32>;
{$pop}

{ Case tw29053b.pp }
{$push}


type
  generic tw29053b_tmodelarray<T: TObject> = array of T;
{$pop}

{ Case tw30830a.pp }
{$push}


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


generic procedure tw35670a_dothis<T>(msg: T);
begin
end;

procedure tw35670a_dothis(msg: TObject);
begin
end;
{$pop}

{ Case tw37650.pp }
{$push}


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


type generic tw40708_tmatrix4<T> = array[0..3] of array [0..3] of T; // works
type generic tw40708_tanothermatrix4<T> = array[0..3,0..3] of T; // "Identifier not found T"

type tw40708_tmatrix4longint = specialize tw40708_tmatrix4<LongInt>;
type tw40708_tanothermatrix4longint = specialize tw40708_tanothermatrix4<LongInt>;
{$pop}

{ Case tw40712a.pp }
{$push}

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


{$pop}

{ Source group: tb_generics_objfpc_compile_02.pp }
{$push}

{ Case tw41254.pp }
{$push}


type
  generic tw41254_tt<T> = record
    tw41254_zz: ^specialize tw41254_tt<T>; // Error: Internal error 2019112401
  end;

  tw41254_ttint = specialize tw41254_tt<longint>;
{$pop}

{ Case tw41504a.pp }
{$push}


type
  tw41504a_tclassmain = class
    procedure tw41504a_method; virtual; abstract;
  end;

  generic tw41504a_tgenclass<T> = class
  type
    tw41504a_ttype = T;
    tw41504a_tself = tw41504a_tgenclass;
  end;

  tw41504a_ltype = type specialize tw41504a_tgenclass<tw41504a_tclassmain>.tw41504a_tself.tw41504a_ttype;
{$pop}


{$pop}

{ Source group: tb_generics_objfpc_compile_03.pp }
{$push}

{ Case tb0726.pp }
{$push}
{$H+}

type
  generic tb0726_ttest1<T> = class
    procedure tb0726_test;
  end;

  generic tb0726_ttest2<T> = class
    procedure tb0726_test;
  end;

procedure tb0726_ttest1.tb0726_test;
begin
end;

procedure tb0726_test;
type
  tb0726_tarr = packed array [0..1] of Single;
  tb0726_ttest1arr = specialize tb0726_ttest1<tb0726_tarr>;
  tb0726_ttest2arr = specialize tb0726_ttest2<tb0726_tarr>;
var
  tb0726_a: tb0726_ttest1arr;
  tb0726_b: tb0726_ttest2arr;
begin
  tb0726_a := tb0726_ttest1arr.Create;
  tb0726_a.Free;
  tb0726_b := tb0726_ttest2arr.Create;
  tb0726_b.Free;
end;

procedure tb0726_ttest2.tb0726_test;
begin
end;
{$pop}

{ Case tw28832.pp }
{$push}
{$H+}

generic procedure tw28832_test<T>(AValue : T);
begin
  WriteLn(Low(AValue));
  WriteLn(Low(T));
  WriteLn(High(AValue));
  WriteLn(High(T));
end;
{$pop}

{ Case tw36496b.pp }
{$push}
(*
  testing application for
  https://forum.lazarus.freepascal.org/index.php/topic,47936.0.html
*)

{$H+}

generic function tw36496b_testgenrecurse<T>(const AInput : T) : Boolean;
begin
  //Result := False;

  (*
    below, if uncommented will fail to compile
    tester.lpr(12,19) Error: Identifier not found "TestGenRecurse$1"
  *)
  specialize tw36496b_testgenrecurse<T>(AInput);
  specialize tw36496b_testgenrecurse<String>('test');
  specialize tw36496b_testgenrecurse<LongInt>(42);
end;

generic procedure tw36496b_testgenrecurseproc<T>(const AInput : T);
begin
  (*
    below method calls compile fine
  *)
  specialize tw36496b_testgenrecurseproc<T>(AInput);
  specialize tw36496b_testgenrecurseproc<String>('test');
  specialize tw36496b_testgenrecurseproc<LongInt>(42);
end;
{$pop}


{$pop}

{ Source group: tb_generics_objfpc_compile_04.pp }
{$push}

{ Case tw39679.pp }
{$push}
{$H+}
{$ModeSwitch implicitfunctionspecialization}

type
  generic tw39679_tbase<T> = class(TObject);
  generic tw39679_tchild<T> = class(specialize tw39679_tbase<T>);
  tw39679_tlongintchild = class(specialize tw39679_tchild<LongInt>);
  tw39679_tlongintbase = class(specialize tw39679_tbase<LongInt>);

generic procedure tw39679_foo<T>(tw39679_lst: specialize tw39679_tbase<T>);
begin
end;

var
  tw39679_lst: specialize tw39679_tchild<Integer>;
  tw39679_lst2: tw39679_tlongintchild;
  tw39679_lst3: tw39679_tlongintbase;
{$pop}

{ Case tw39681.pp }
{$push}
{$H+}
{$ModeSwitch implicitfunctionspecialization}

type
  generic tw39681_tfunc<TResult> = function: TResult;

generic procedure tw39681_bar<T>(f: specialize tw39681_tfunc<T>);
begin
end;

function tw39681_foo: Integer;
begin
end;
{$pop}


{$pop}

{ Source group: tb_generics_objfpc_compile_05.pp }
{$push}

{ Case tw21179.pp }
{$push}

{$modeswitch ADVANCEDRECORDS}

type generic tw21179_gvec3<T> = record
  tw21179_d : Byte;
  class operator *( const A, B : tw21179_gvec3 ) : tw21179_gvec3;
  class operator *( const A : tw21179_gvec3; tw21179_scalar : T ) : tw21179_gvec3;
end;

class operator tw21179_gvec3.*( const A, B : tw21179_gvec3 ) : tw21179_gvec3;
begin
end;

class operator tw21179_gvec3.*( const A : tw21179_gvec3; tw21179_scalar : T ) : tw21179_gvec3;
begin
end;
{$pop}

{ Case tw30524b.pp }
{$push}

{$modeswitch advancedrecords}

{uses
  Generics.Defaults;}

type
  generic tw30524b_tuple<tw30524b_t> = record
    tw30524b_item1: tw30524b_t;
    class operator =( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean; // FPC Error: Compilation raised exception internally
    class operator <>( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
  end;

  tw30524b_ttuple = record
    generic class function Create<tw30524b_t>( tw30524b_item1: tw30524b_t ): specialize tw30524b_tuple<tw30524b_t>; overload; static;
  end;

generic class function tw30524b_ttuple.Create<tw30524b_t>( tw30524b_item1: tw30524b_t ): specialize tw30524b_tuple<tw30524b_t>;
begin
  Result.tw30524b_item1 := tw30524b_item1;
end;

class operator tw30524b_tuple.=( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
begin
  Result := False;//TEqualityComparer<T>.Default.Equals( a.Item1, b.Item1 );
end;

class operator tw30524b_tuple.<>( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
begin
  Result := not( a = b );
end;

var
  tw30524b_t: specialize tw30524b_tuple<LongInt>;
{$pop}

{ Case tw34497a.pp }
{$push}

{$modeswitch AdvancedRecords}

type
  generic tw34497a_tgenrec<T1, T2> = record
    tw34497a_a: T1;
    tw34497a_b: T2;
    function tw34497a_funca(const T: T1): T1;
    function tw34497a_funca(const T: T2): T2;
    class operator :=(constref Rec: tw34497a_tgenrec): T1;
    class operator :=(constref Rec: tw34497a_tgenrec): T2;
  end;

  function tw34497a_tgenrec.tw34497a_funca(const T: T1): T1;
  begin
    Result := T;
  end;

  function tw34497a_tgenrec.tw34497a_funca(const T: T2): T2;
  begin
    Result := T;
  end;

  class operator tw34497a_tgenrec.:=(constref Rec: tw34497a_tgenrec): T1;
  begin
    Result := Rec.tw34497a_a;
  end;

  class operator tw34497a_tgenrec.:=(constref Rec: tw34497a_tgenrec): T2;
  begin
    Result := Rec.tw34497a_b;
  end;
{$pop}

{ Case tw38145b.pp }
{$push}
{$modeswitch advancedrecords}
type
  generic tw38145b_tmywrap<T> = record
    tw38145b_value: T;
    class operator Explicit(const w: tw38145b_tmywrap): T;
    class operator :=(const w: tw38145b_tmywrap): T;
  end;

class operator tw38145b_tmywrap.Explicit(const w: tw38145b_tmywrap): T;
begin
  Result := w.tw38145b_value;
end;

class operator tw38145b_tmywrap.:=(const w: tw38145b_tmywrap): T;
begin
  Result := w.tw38145b_value;
end;

type
  //TString = string[255]; //compiles
  tw38145b_tstring = string[254]; //not compiles
var
  tw38145b_myspec: specialize tw38145b_tmywrap<tw38145b_tstring>;
{$pop}


{$pop}

begin
  { Source group: tb_generics_objfpc_compile_01.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_generics_objfpc_compile_02.pp }
  {$push}


begin

end;
  {$pop}

  { Source group: tb_generics_objfpc_compile_03.pp }
  {$push}


begin
  { Case tw28832.pp }
  {$push}

  begin
specialize tw28832_test<Integer>(0);
  end;
  {$pop}

  { Case tw36496b.pp }
  {$push}

  begin
specialize tw36496b_testgenrecurse<String>('testing');
  specialize tw36496b_testgenrecurseproc<String>('testing');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_objfpc_compile_04.pp }
  {$push}

{$ModeSwitch implicitfunctionspecialization}
{$ModeSwitch implicitfunctionspecialization}
begin
  { Case tw39679.pp }
  {$push}

  begin
specialize tw39679_foo<Integer>(tw39679_lst); // works
  tw39679_foo(tw39679_lst); // Error
  tw39679_foo(tw39679_lst2);
  tw39679_foo(tw39679_lst3);
  end;
  {$pop}

  { Case tw39681.pp }
  {$push}

  begin
specialize tw39681_bar<Integer>(@tw39681_foo); // works
  tw39681_bar(@tw39681_foo); // Error
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_objfpc_compile_05.pp }
  {$push}

{$modeswitch ADVANCEDRECORDS}
{$modeswitch advancedrecords}
{$modeswitch AdvancedRecords}
{$modeswitch advancedrecords}
begin
  { Case tw30524b.pp }
  {$push}

  begin
tw30524b_t := tw30524b_ttuple.specialize Create<LongInt>(42);
  end;
  {$pop}


end;
  {$pop}

end.
