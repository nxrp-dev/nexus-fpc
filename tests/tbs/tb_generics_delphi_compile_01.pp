{ %norun }
{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode delphi}


{ Source group: tb_generics_delphi_compile_01.pp }
{$push}

{ Case tw21064a.pp }
{$push}


type
  tw21064a_igenericintf<T> = interface
    function tw21064a_somemethod: T;
  end;

  tw21064a_tgenericclass<T> = class(TInterfacedObject, tw21064a_igenericintf<T>)
  private
  protected
    function tw21064a_genericintf_somemethod: T;
    function tw21064a_igenericintf<T>.tw21064a_somemethod = tw21064a_genericintf_somemethod;
  end;

function tw21064a_tgenericclass<T>.tw21064a_genericintf_somemethod: T;
begin
end;

type
  tw21064a_tgenericclasslongint = tw21064a_tgenericclass<LongInt>;
{$pop}

{ Case tw21064b.pp }
{$push}


type
  tw21064b_igenericintf<T> = interface
    function tw21064b_somemethod: T;
  end;

  tw21064b_tgenericclass<T> = class(TInterfacedObject, tw21064b_igenericintf<T>)
  private
    type
      tw21064b_intftype = tw21064b_igenericintf<T>;
  protected
    function tw21064b_genericintf_somemethod: T;
    function tw21064b_intftype.tw21064b_somemethod = tw21064b_genericintf_somemethod;
  end;

function tw21064b_tgenericclass<T>.tw21064b_genericintf_somemethod: T;
begin
end;

type
  tw21064b_tgenericclasslongint = tw21064b_tgenericclass<LongInt>;
{$pop}

{ Case tw22192.pp }
{$push}


 type
   tw22192_twrapper<T> = record end;
   tw22192_twrapper = tw22192_twrapper<Byte>;
{$pop}

{ Case tw22433.pp }
{$push}


type tw22433_twrapper<T> = record end;

procedure tw22433_z(const a: array of tw22433_twrapper<Integer>);
begin
end;
{$pop}

{ Case tw24073.pp }
{$push}


type
  tw24073_ta<T: record> = record
  end;

  tw24073_tunamanagedrec = record
    tw24073_x: integer;
  end;

  tw24073_tmanagedrec = record
    tw24073_s: string;
  end;

  tw24073_tenum = (e1, e2, e3);

  tw24073_tobj = object
  end;

var
  tw24073_a: tw24073_ta<tw24073_tunamanagedrec>;
  tw24073_b: tw24073_ta<tw24073_tmanagedrec>;
  tw24073_d: tw24073_ta<Single>;
  tw24073_e: tw24073_ta<Integer>;
  tw24073_f: tw24073_ta<tw24073_tenum>;
  tw24073_g: tw24073_ta<tw24073_tobj>;
{$pop}

{ Case tw24848.pp }
{$push}


type
  tw24848_tfoo<T> = class
    class constructor Create;
  end;

class constructor tw24848_tfoo<T>.Create;
begin
end;
{$pop}

{ Case tw24872.pp }
{$push}


procedure tw24872_test;
begin
end;

type
  tw24872_trec<T> = record {for generic class is ok, and non generic record too}
    procedure tw24872_foo;
  end;

procedure tw24872_trec<T>.tw24872_foo;
begin
  tw24872_test
end; // Error: Global Generic template references static symtable
{$pop}

{ Case tw25604.pp }
{$push}


type
  tw25604_ta<T> = class
  private
    tw25604_f1, tw25604_f2: T;
    procedure tw25604_foo;
  end;

procedure tw25604_ta<T>.tw25604_foo;
var
  tw25604_b: Integer;
begin
  tw25604_b := (tw25604_b and tw25604_f1) shr tw25604_f2; // pass
  tw25604_b := (tw25604_b and not tw25604_f1) or (tw25604_b shl tw25604_f2); // Error: Operator is not overloaded: "LongInt" shl "<undefined type>"
end;
{$pop}

{ Case tw25929.pp }
{$push}


type
  tw25929_tr<T> = record
  end;

  tw25929_ta<T> = class
    procedure tw25929_foo;
  end;

procedure tw25929_ta<T>.tw25929_foo;
var
  tw25929_r: tw25929_tr<T>;
begin
  tw25929_r := Default(tw25929_tr<T>);
  tw25929_r := Default(tw25929_tr<T>); // Error: Duplicate identifier "zero_$P$PLC03_$$_TR$1"
end;
{$pop}

{ Case tw26180.pp }
{$push}

{$Assertions on}

type
  tw26180_ta<T> = class
  private
    tw26180_f: T;
    procedure tw26180_foo;
  end;

procedure tw26180_ta<T>.tw26180_foo;
begin
  Assert(tw26180_f <> 0); // Error: Boolean expression expected, but got "<undefined type>"
                  // same for >, <, <=, >=, =
end;
{$pop}

{ Case tw26483.pp }
{$push}


type
  tw26483_ta<T> = class
  private
    tw26483_f: Integer;
  end;

  tw26483_tb<T> = class
    procedure tw26483_foo(A: TObject);
  end;

procedure tw26483_tb<T>.tw26483_foo(A: TObject);
begin
  WriteLn(tw26483_ta<T>(A).tw26483_f); // p004.Error: identifier idents no member "F"
end;
{$pop}

{ Case tw26599.pp }
{$push}


type
  tw26599_tsomelist<T : TObject> = Class
  End; { Class }

  tw26599_tsomeclass = Class;
  tw26599_tsomeclasslist = tw26599_tsomelist<tw26599_tsomeclass>;

  tw26599_tsomeclass = Class(TObject)
    tw26599_somelist : tw26599_tsomeclasslist;
  End;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_compile_02.pp }
{$push}

{ Case tw29053.pp }
{$push}


type
  tw29053_tmodelarray<T: class> = array of T;
{$pop}

{ Case tw30030.pp }
{$push}


type
  tw30030_tacl<K, R, M> = Class
  End;

  tw30030_tassertion<K, R, M> = Function(Acl: tw30030_tacl<K, R, M>): Boolean Of Object;
{$pop}

{ Case tw30524a.pp }
{$push}
{$ifdef FPC}

{$endif}

{uses
  Generics.Defaults;}

type
  tw30524a_tuple<tw30524a_t> = record
    tw30524a_item1: tw30524a_t;
    class operator Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean; // FPC Error: Compilation raised exception internally
    class operator NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
  end;

  tw30524a_tuple = record
    class function Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>; overload; static;
  end;

class function tw30524a_tuple.Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>;
begin
  Result.tw30524a_item1 := tw30524a_item1;
end;

class operator tw30524a_tuple<tw30524a_t>.Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := False;//TEqualityComparer<T>.Default.Equals( a.Item1, b.Item1 );
end;

class operator tw30524a_tuple<tw30524a_t>.NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := not( a = b );
end;

var
  tw30524a_t: tw30524a_tuple<LongInt>;
{$pop}

{ Case tw30534.pp }
{$push}


type
  tw30534_tsmartptr<T: class> = record
    class operator Implicit(aValue: T): tw30534_tsmartptr<T>;
  end;

class operator tw30534_tsmartptr<T>.Implicit(aValue: T): tw30534_tsmartptr<T>;
begin
end;

var
  tw30534_sp: tw30534_tsmartptr<TObject>;
{$pop}

{ Case tw30830b.pp }
{$push}


type
  tw30830b_tbase<T> = class
    procedure tw30830b_test1(const a: T);
  end;

  tw30830b_tderived<T> = class(tw30830b_tbase<T>)
    procedure tw30830b_test2(const a: T);
  end;

procedure tw30830b_tbase<T>.tw30830b_test1(const a: T);
begin
end;

procedure tw30830b_tderived<T>.tw30830b_test2(const a: T);
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tbase<T>); overload; // works
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tderived<T>); overload; // SIGSEGV :(
begin
end;

var
  tw30830b_b: tw30830b_tbase<LongInt>;
  tw30830b_d: tw30830b_tderived<LongInt>;
{$pop}

{ Case tw30939b.pp }
{$push}


Type
  tw30939b_tgdata<T> = record
    tw30939b_b: T
  end;

  tw30939b_tgwrapper<T> = record
    tw30939b_a: tw30939b_tgdata<T>
  end;

Function tw30939b_dosomething<T>: tw30939b_tgwrapper<T>;
  Begin
    result.tw30939b_a.tw30939b_b := default(T)
  End;
{$pop}

{ Case tw38145a.pp }
{$push}

type
  tw38145a_tmywrap<T> = record
    tw38145a_value: T;
    class operator Explicit(const w: tw38145a_tmywrap<T>): T;
    class operator Implicit(const w: tw38145a_tmywrap<T>): T;
  end;

class operator tw38145a_tmywrap<T>.Explicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

class operator tw38145a_tmywrap<T>.Implicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

type
  //TString = string[255]; //compiles
  tw38145a_tstring = string[254]; //not compiles

var
  tw38145a_myspec: tw38145a_tmywrap<tw38145a_tstring>;
{$pop}

{ Case tw40712b.pp }
{$push}

type
    tw40712b_tsomegeneric<T> = object
    type
      tw40712b_tmine = T;
    var
      tw40712b_data: record
        tw40712b_value: T;
      end;
  end;
  tw40712b_tsomegeneric2 = object(tw40712b_tsomegeneric<Integer>)
  end;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_compile_03.pp }
{$push}

{ Case tw21921.pp }
{$push}
{$H+}

type

 { THashEntry }

 tw21921_thashentry<T> = record
   tw21921_key: string;
   tw21921_value: T;
   class function Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>; static; inline;
 end;

class function tw21921_thashentry<T>.Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>;
begin
  Result.tw21921_key := AKey;
  Result.tw21921_value := tw21921_avalue;
end;

var
  tw21921_entry: tw21921_thashentry<Integer>;
{$pop}

{ Case tw24283.pp }
{$push}
{$H+}

type
  tw24283_ta<tw24283_t> = record
  end;

  tw24283_tb<tw24283_t> = class
  end;

  tw24283_tc<tw24283_t> = class(tw24283_tb<tw24283_ta<tw24283_t>>)
  end;

{ ensure that specialization works as well }
var
  tw24283_t: tw24283_tc<LongInt>;
{$pop}

{ Case tw39581.pp }
{$push}
 {$H+}

Type
  tw39581_timplclass<P> = class;

  tw39581_ilinkingintf<P> = interface
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
  end;

(* Компиляция проекта, цель: Project1.exe: Код завершения 1, ошибок: 1
Project1.pas(9,55) Error: Internal error 2012101001
*)

  { TImplClass }

  tw39581_timplclass<P> = class( TInterfacedObject, tw39581_ilinkingintf<P> )
  protected
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P> );
  end;

{ TImplClass }

procedure tw39581_timplclass<P>.tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
begin

end;
{$pop}


{$pop}

{ Source group: tb_generic_routines_delphi_compile_01.pp }
{$push}

{ Case tw35670b.pp }
{$push}
procedure tw35670b_dothis<T>(tw35670b_msg: T);
begin
end;

procedure tw35670b_dothis(tw35670b_msg: TObject);
begin
end;
{$pop}

{ Case tw37380.pp }
{$push}
function tw37380_gtest<T>(tw37380_a: T; tw37380_b: T = T(1)): T;
begin
  Result := tw37380_a + tw37380_b;
end;

function tw37380_foobar(tw37380_a: Single; tw37380_b: Single = Single(1)): Single;
begin
  Result := tw37380_a + tw37380_b;
end;
{$pop}

{ Case tw38083.pp }
{$push}
procedure tw38083_test<T>(tw38083_a: T; tw38083_b: Boolean); overload;
  begin

  end;

  procedure tw38083_test(tw38083_a: String); overload;
  begin
    tw38083_test<String>(tw38083_a, True);
  end;
{$pop}


{$pop}

begin
  { Source group: tb_generics_delphi_compile_01.pp }
  {$push}


begin

end;
  {$pop}

  { Source group: tb_generics_delphi_compile_02.pp }
  {$push}


begin
  { Case tw30524a.pp }
  {$push}
{$ifdef FPC}
{$endif}
  begin
tw30524a_t := tw30524a_tuple.Create<LongInt>(42);
  end;
  {$pop}

  { Case tw30534.pp }
  {$push}

  begin
tw30534_sp := nil;
  end;
  {$pop}

  { Case tw30830b.pp }
  {$push}

  begin
tw30830b_test<LongInt>(tw30830b_b);
  tw30830b_test<LongInt>(tw30830b_d);
  end;
  {$pop}

  { Case tw30939b.pp }
  {$push}

  begin
tw30939b_dosomething<LongInt>;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_delphi_compile_03.pp }
  {$push}


begin
  { Case tw21921.pp }
  {$push}

  begin
tw21921_entry := tw21921_thashentry<Integer>.Create('One', 1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generic_routines_delphi_compile_01.pp }
  {$push}


begin
  { Case tw35670b.pp }
  {$push}
begin

end;
  {$pop}

  { Case tw37380.pp }
  {$push}
begin
  WriteLn(tw37380_gtest<Single>(2, 1));
  WriteLn(tw37380_foobar(2));
end;
  {$pop}

  { Case tw38083.pp }
  {$push}
begin

end;
  {$pop}


end;
  {$pop}

end.
