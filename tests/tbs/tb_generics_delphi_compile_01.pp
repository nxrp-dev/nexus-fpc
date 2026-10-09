{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw21064a.pp }
{$push}
{$mode delphi}

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
{$mode delphi}

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
{$MODE DELPHI}

 type
   tw22192_twrapper<T> = record end;
   tw22192_twrapper = tw22192_twrapper<Byte>;
{$pop}

{ Case tw22433.pp }
{$push}
{$MODE DELPHI}

type tw22433_twrapper<T> = record end;

procedure tw22433_z(const a: array of tw22433_twrapper<Integer>);
begin
end;
{$pop}

{ Case tw24073.pp }
{$push}
{$MODE DELPHI}

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
{$mode delphi}

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
{$mode delphi}

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
{$MODE DELPHI}

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
{$MODE DELPHI}

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
{$MODE DELPHI}
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
{$MODE DELPHI}

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
{$mode delphi}

type
  tw26599_tsomelist<T : TObject> = Class
  End; { Class }

  tw26599_tsomeclass = Class;
  tw26599_tsomeclasslist = tw26599_tsomelist<tw26599_tsomeclass>;

  tw26599_tsomeclass = Class(TObject)
    tw26599_somelist : tw26599_tsomeclasslist;
  End;
{$pop}

begin
end.
