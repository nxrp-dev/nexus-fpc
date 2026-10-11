{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_nested_generics_objfpc.pp }
{$push}
{ Nested generic types, constructors, return types and constrained arrays. }


{ tw32118.pp }

type
  generic tb_nested_generics_objfpc_TTestClass<SomeTemplate> = class
    procedure Test;
  end;

procedure tb_nested_generics_objfpc_TTestClass.Test;
var
  i : SomeTemplate;
begin
  for i := 1 to 10 do WriteLn(i);
end;

{ tw37187.pp }


type
  generic tb_nested_generics_objfpc_TTest<T: class> = class
    arr: array[0..SizeOf(T)] of Byte;
  end;

  generic tb_nested_generics_objfpc_TTest2<T: class> = class
  public type
    TTestT = specialize tb_nested_generics_objfpc_TTest<T>;
  end;

{ tw19498.pp }
 { -*- text -*- }

type
   generic tb_nested_generics_objfpc_TFoo1 <T> = class
    type
     TFoo2 = class
        constructor Create(Owner: specialize tb_nested_generics_objfpc_TFoo1<T>);
     end;
   end;

constructor tb_nested_generics_objfpc_TFoo1.TFoo2.Create(Owner: specialize tb_nested_generics_objfpc_TFoo1<T>);
begin
end;

type
   tb_nested_generics_objfpc_TIntegerFoo1 = specialize tb_nested_generics_objfpc_TFoo1<Integer>;

var
   tb_nested_generics_objfpc_Foo1: tb_nested_generics_objfpc_TIntegerFoo1;
   tb_nested_generics_objfpc_Foo2: tb_nested_generics_objfpc_TIntegerFoo1.TFoo2;

{ tw19500.pp }
 { -*- text -*- }

type
   generic tb_nested_generics_objfpc_TReturnGenericOuter <T> = class
     type
      TBar = class
         function Baz(): T;
      end;
   end;

function tb_nested_generics_objfpc_TReturnGenericOuter.TBar.Baz(): T;
begin
   Result := nil;
end;

{ tw19511.pp }
 { -*- text -*- }

type
   generic tb_nested_generics_objfpc_TNestedSpecializationFoo<X> = class
   end;
   generic tb_nested_generics_objfpc_TSelfGenericBar<Y> = class
    type
     TIntegerSpecializedFoo = specialize tb_nested_generics_objfpc_TNestedSpecializationFoo<Integer>;
     TSelfSpecializedFoo = specialize tb_nested_generics_objfpc_TNestedSpecializationFoo<tb_nested_generics_objfpc_TSelfGenericBar>;
    function SelfTest(): tb_nested_generics_objfpc_TSelfGenericBar; // returns a TBar<Y>
      TSpecializedBar = specialize tb_nested_generics_objfpc_TSelfGenericBar<Y>; // this rightly would not compile since TBar here refers to the specialized TBar<Y>
   end;

function tb_nested_generics_objfpc_TSelfGenericBar.SelfTest(): tb_nested_generics_objfpc_TSelfGenericBar;
begin
   Result := Self;
end;


{$pop}

{ Case tw16090.pp }
{$push}




{$H+}

type
  tw16090_TClass1 = class
  public type
    generic TNestedClass<T> = class
    end;
    // Fatal: Internal error 200705152
    tw16090_TSpecialization1 = specialize TNestedClass<Integer>;
  end;

  // Fatal: Internal error 200705152
  tw16090_TSpecialization1 = tw16090_TClass1.specialize TNestedClass<Integer>;


{$pop}

{ Case tw18103a.pp }
{$push}




// alias test generic class
// example is a subset of a working delphi class
// the nested types are there so that they can be used to defined types (e.g.  var p : bwimagespecialization.reft;)
//




{.define fpchere}

Type
  generic tw18103a_tbwimagegen<T> = Class(TObject)
                 Type
                    TLocalType = specialize tw18103a_tbwimagegen<T>;
                    BaseUnit = T;
                    RefT= ^BaseUnit;
                  procedure copylines(source:  specialize tw18103a_tbwimagegen<T>;xfrom,xto:integer;xdestline:integer=0);
                  function GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
                  function GetLinePointer(originy:integer):reft;
                  property scanline[i:integer]:reft read getlinepointer;
                  end;


procedure tw18103a_tbwimagegen.copylines(source: specialize tw18103a_tbwimagegen<T>;xfrom,xto:integer;xdestline:integer=0);
begin
end;
function tw18103a_tbwimagegen.GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
begin
end;
function tw18103a_tbwimagegen.GetLinePointer(originy:integer):reft;
begin
end;


{$pop}

{ Case tw18103b.pp }
{$push}




// alias test generic class
// example is a subset of a working delphi class
// the nested types are there so that they can be used to defined types (e.g.  var p : bwimagespecialization.reft;)
//




{.define fpchere}

Type
  generic tw18103b_tbwimagegen<T> = Class(TObject)
                 Type
                    TLocalType = tw18103b_tbwimagegen;
                    BaseUnit = T;
                    RefT= ^BaseUnit;
                  procedure copylines(source:  tw18103b_tbwimagegen;xfrom,xto:integer;xdestline:integer=0);
                  function GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
                  function GetLinePointer(originy:integer):reft;
                  property scanline[i:integer]:reft read getlinepointer;
                  end;


procedure tw18103b_tbwimagegen.copylines(source: tw18103b_tbwimagegen;xfrom,xto:integer;xdestline:integer=0);
begin
end;
function tw18103b_tbwimagegen.GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
begin
end;
function tw18103b_tbwimagegen.GetLinePointer(originy:integer):reft;
begin
end;


{$pop}

{ Case tw23776.pp }
{$push}




type
generic tw23776_tg<T>= class
    public
        class function len(a: T): integer;
end;
    class function tw23776_tg.len(a: T): integer;
    begin
        result:= length(a);
    end;

{$pop}

{ Case tw26123.pp }
{$push}






type
    generic tw26123_TNode<data_type> = class // anything can go in this class
    end;

    generic tw26123_TLinkedList<data_type> = class
      type
          specialized_TNode = specialize tw26123_TNode<data_type>;
      public
        node : specialized_TNode;
    end;


    generic tw26123_TExtendedLinkedList<data_type> = class (specialize tw26123_TLinkedList<data_type>)
      public
        last_node : specialized_TNode;
    end;


{$pop}

{ Case tw30626.pp }
{$push}






type
  generic tw30626_IBase<tw30626_T> = interface(IUnknown)
  end;

  generic tw30626_TBase<tw30626_T> = class(TInterfacedObject, specialize tw30626_IBase<tw30626_T>)
  public
    function Test: specialize tw30626_IBase<tw30626_T>;
  end;

  generic tw30626_TDerived<tw30626_T> = class(specialize tw30626_TBase<tw30626_T>)

  end;

function tw30626_TBase.Test: specialize tw30626_IBase<tw30626_T>;
begin
  result := (specialize tw30626_TDerived<tw30626_T>).Create;
end;

type
  tw30626_TIntDerived = specialize tw30626_TDerived<Integer>;

var
  tw30626_t: tw30626_TIntDerived;


{$pop}

{ Case tw30626b.pp }
{$push}






type
  generic tw30626b_IBase<T> = interface(IUnknown)
    function Test: specialize tw30626b_IBase<T>;
  end;

  generic tw30626b_TBase<T> = class(TInterfacedObject, specialize tw30626b_IBase<T>)
  public
    function Test: specialize tw30626b_IBase<T>; virtual;
  end;

  generic tw30626b_TDerived<T> = class(specialize tw30626b_TBase<T>)
  public
    function Test: specialize tw30626b_IBase<T>; override;
  end;

function tw30626b_TBase.Test: specialize tw30626b_IBase<T>;
begin
 result := specialize tw30626b_TDerived<T>.Create;
end;

function tw30626b_TDerived.Test: specialize tw30626b_IBase<T>;
begin
 result := specialize tw30626b_TDerived<T>.Create;
end;

type
  tw30626b_IIntegerBase = specialize tw30626b_IBase<Integer>;

var
  tw30626b_Intf, tw30626b_Intf2: tw30626b_IIntegerBase;

{$pop}

{ Case tw40716.pp }
{$push}



{$H+}
{uses
  gmap,gutil;}
type
  generic tw40716_GMyMap<TKey, TValue, TCompare>=class//(specialize TMap<TKey, TValue, TCompare>)
    type
      TSelf=specialize tw40716_GMyMap<TKey, TValue, TCompare>;
      TMyMapHelper = class helper for TSelf
        function test:integer;
      end;
    procedure Foo;
  end;
function tw40716_GMyMap.TMyMapHelper.test:integer;
begin
  result:=42;//FSet.Size;
end;
procedure tw40716_GMyMap.Foo;
begin
  Self.Test;
end;

{$pop}

{ Case tw41506a.pp }
{$push}





type
  generic tw41506a_TGenClass<T> = class
  end;
  tw41506a_TCommon = nexus_consolidated_tests.specialize tw41506a_TGenClass<byte>;


{$pop}

{ Case tw41516a.pp }
{$push}



type

  tw41516a_TFoo = class
    procedure       Foo2;
  end;

  generic tw41516a_TGen<T2: TObject> = class
    procedure       Foo2;
  end;

  tw41516a_TWrap1 = class
  public type
    generic TTest4<T2: TObject> = class
      procedure       Foo2;
    end;

  public
    procedure         P1;
  end;

var
  tw41516a_gTest4:  tw41516a_TWrap1.specialize TTest4<TObject>;

{ TFoo }

procedure tw41516a_TFoo.Foo2;
var
  v2:  tw41516a_TWrap1.specialize TTest4<TObject>;
begin
end;

procedure tw41516a_TGen.Foo2;
var
  v2:  tw41516a_TWrap1.specialize TTest4<TObject>;
begin
end;

// TWRAP1

procedure tw41516a_TWrap1.TTest4.Foo2;
var     // V2: project1.lpr(50,32) Error: Parameters or result types cannot contain local type definitions. Use a separate type definition in a type block.
  v2:  tw41516a_TWrap1.specialize TTest4<TObject>;
  v3:  specialize TTest4<TObject>;
type
  x2 =  tw41516a_TWrap1.specialize TTest4<TObject>;
  x3 =  specialize TTest4<TObject>;
begin
end;

procedure tw41516a_TWrap1.P1;
var        // V2: project1.lpr(50,32) Error: Parameters or result types cannot contain local type definitions. Use a separate type definition in a type block.
  v2:  tw41516a_TWrap1.specialize TTest4<TObject>;
  v3:  specialize TTest4<TObject>;
type
  x2 =  tw41516a_TWrap1.specialize TTest4<TObject>;
  x3 =  specialize TTest4<TObject>;
begin
end;


{$pop}

begin

{ Case tb_nested_generics_objfpc.pp }
{$push}





begin

end;
{$pop}

{ Case tw16090.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw18103a.pp }
{$push}

begin
end;
{$pop}

{ Case tw18103b.pp }
{$push}

begin
end;
{$pop}

{ Case tw23776.pp }
{$push}

begin
end;
{$pop}

{ Case tw26123.pp }
{$push}

begin
end;
{$pop}

{ Case tw30626.pp }
{$push}

begin
  tw30626_t := tw30626_TIntDerived.Create;
  tw30626_t.Test;
end;
{$pop}

{ Case tw30626b.pp }
{$push}

begin
  tw30626b_Intf:= specialize tw30626b_TDerived<Integer>.Create;
  tw30626b_Intf2:= tw30626b_Intf.Test;
end;
{$pop}

{ Case tw40716.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw41506a.pp }
{$push}

begin
end;
{$pop}

{ Case tw41516a.pp }
{$push}

begin
end;
{$pop}

end.
