{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_generics_objfpc_run_02.pas }
{$push}
{ Generics regression cases; original case IDs are retained below. }

{ Case tb0560.pas }
{$push}
{$H+}

function tb0560_linehtml( sa : string):string;
var
tb0560_xpoz : integer;
tb0560_xp,tb0560_xk  : integer;

function tb0560_nexttoken(var aPocz: integer;var tb0560_akon :integer):string;

begin
  result:='';
  aPocz:=tb0560_xpoz+1;
  tb0560_akon:=0;
  try
    while tb0560_xpoz< length(sa) do begin
      inc(tb0560_xpoz);
      case sa[tb0560_xpoz] of

       '|' :begin
               exit;
           end;
      else

      end;
      result:=result+sa[tb0560_xpoz];
      inc(tb0560_akon);

    end;
  finally
    writeln('test ',result);
    tb0560_akon:=aPocz+tb0560_akon;
//    writeln('test2 ',result);
  end;
end;

begin
 tb0560_xpoz:=0;
 result:='';
 repeat
    tb0560_nexttoken(tb0560_xp,tb0560_xk);
 until tb0560_xpoz>=length(sa);
end;
{$pop}

{ Case tw34232.pas }
{$push}
{$H+}
type
generic tw34232_ttest<TKey, TValue> = packed object
    type
    tw34232_tpair = packed record
      tw34232_key: TKey;
      tw34232_value: TValue;
    end;
    tw34232_tpairsizeequivalent = packed array[1..sizeof(tw34232_tpair)] of byte;
end;
tw34232_tteststringstring = specialize tw34232_ttest<string, string>;
{$pop}

{ Case tw39795.pas }
{$push}
{$H+}

type
  generic tw39795_gtesttype<T,const S:byte>=class
    type
      tw39795_txx=array [0..S] of T;
    var
      tw39795_xx:tw39795_txx;
  end;
  tw39795_t2=specialize tw39795_gtesttype<byte,0>;
  tw39795_t3=specialize tw39795_gtesttype<byte,99>;
{$pop}

{ Case tw39805a.pas }
{$push}
{$H+}
const
  tw39805a_ts=3;
type
  generic tw39805a_gtest<T>=record
    case byte of
    0:(ta:array [0..2] of T);
    1:(t1:T;tw39805a_t2:T;tw39805a_t3:T);
  end;
{$pop}

{ Case tw40608.pas }
{$push}
{$H+}

generic function tw40608_genericfunc<T>: String;

  function tw40608_innerfunc: String;
  begin // project1.lpr(6,3) Error: Duplicate identifier "$result"
  end;

begin
end;
{$pop}

{ Case tw7998.pas }
{$push}
{$H+}

type
  tw7998_tfixedstring15 = array[1..15] of char;
  generic tw7998_tlinkedlist<T> = class
    type
      tw7998_pnode = ^tw7998_tnode;
      tw7998_tnode = record
      tw7998_key: T;
      tw7998_value : dword;
      tw7998_next : tw7998_pnode;
    end;
    var
      tw7998_first: tw7998_pnode;
  end;

var
  tw7998_mylinkedlist: specialize tw7998_tlinkedlist<tw7998_tfixedstring15>;
{$pop}


{$pop}

{ Case tw10247b.pas }
{$push}
{$h+}
type
  generic tw10247b_TNode<T> = class
  public
    type
      TAlias = T;
      PT = T;
  private
    var
      Data: T;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  tw10247b_TTNodeLongint = specialize tw10247b_TNode<Longint>;

  tw10247b_TTNodeString = specialize tw10247b_TNode<String>;

constructor tw10247b_TNode.Create;
begin
end;

destructor tw10247b_TNode.Destroy;
begin
  inherited Destroy;
end;


function tw10247b_GetIntNode: tw10247b_TTNodeLongint.TAlias;
begin
  result := 10;
end;


function tw10247b_GetStringNode: tw10247b_TTNodeString.PT;
begin
  result := 'abc';
end;


{$pop}

{ Case tw20028.pas }
{$push}


{$H+}

type
  tw20028_TConstHolder = class
  public
    const
      C = 10;
  end;

  tw20028_TSimple = class
    Arr: array [0..tw20028_TConstHolder.C] of Integer; //this works
  end;


  generic tw20028_TGeneric <T> = class
    Arr: array [0..T.C] of Integer; //but here is error
// Can't evaluate constant expression

  end;


{$pop}

{ Case tw20192.pas }
{$push}

{$H+}

type
  generic tw20192_TGen<_T> = class(TObject)
    private
      FField: _T;
    public
      constructor Create(Val: _T);

      function Bug: LongInt;
  end;

{--- TGen.Create ---}
constructor tw20192_TGen.Create(Val: _T);
begin
  inherited Create;
  FField := Val;
end;

{--- TGen.Bug ---}
function tw20192_TGen.Bug : LongInt;
begin
  Result := 100000 div SizeOf(_T);  // *** DIVISION BY ZERO ***

  // THE FOLLOWING CODE IS OK !
  //
  // var
  //   S: Integer;
  // begin
  //   S := SizeOf(_T);
  //   Result := 100000 div S;
end;

type
  tw20192_TGenInt = specialize tw20192_TGen<Integer>;

var
  tw20192_V: tw20192_TGenInt;

{$pop}

{ Case tw21654.pas }
{$push}




Type

{ TMyGeneric }

 Generic tw21654_TMyGeneric<T> = Class
  Private
    bValue: Integer; Static;
    Function GetValue: Integer;
  Public
    Property Value: Integer Read GetValue;
    Constructor Create(Const aValue: Integer);
End;

{ TMyGeneric }

Function tw21654_TMyGeneric.GetValue: Integer;
Begin
  Result := bValue;
end;

Constructor tw21654_TMyGeneric.Create(Const aValue: Integer);
Begin
  bValue := aValue;
End;

Type tw21654_TMyClass = Specialize tw21654_TMyGeneric<TObject>;


{$pop}

{ Case tw28058.pas }
{$push}


type
  generic tw28058_TFoo<T> = class
  const
    Size = SizeOf(T);
   public
     function X: Integer;
  end;

{ TFoo }

function tw28058_TFoo.X: Integer;
begin
  //Result := 100 div SizeOf(T);
  Result := 100 div Size;
end;


{$pop}

{ Case tw41358.pas }
{$push}


type
  //generic x<const K> = class  // error semicolon expected, but > found
  generic tw41358_x<const K; tw41358_T> = class // so we give it the semicolon...
  public type
    Foo = array[0..K] of byte; // internal error
  end;


{$pop}

{ Case tw6624.pas }
{$push}


{$H+}

type
  generic tw6624_TGenTest1<T> = class
   public
    procedure One(const a: T);
    function Two: T;
  end;

procedure tw6624_TGenTest1.One(const a: T);
begin

end;

function tw6624_TGenTest1.Two: T; // fails here
begin
end;


{$pop}

begin

{ Case tb_generics_objfpc_run_02.pas }
{$push}
{$push}

{$H+}
{$pop}
{$push}

{$H+}
{$pop}
{$push}

{$H+}
{$pop}
{$push}

{$H+}
{$pop}
{$push}

{$H+}
{$pop}
{$push}

{$H+}
{$pop}
begin
  { Case tb0560.pas }
  {$push}

  begin
writeln(tb0560_linehtml('|  1 | 2 | 3'));
  end;
  {$pop}

  { Case tw34232.pas }
  {$push}

  begin
writeln(sizeof(tw34232_tteststringstring.tw34232_tpairsizeequivalent));
  end;
  {$pop}

  { Case tw39795.pas }
  {$push}

  begin
if sizeof(tw39795_t2.tw39795_txx) <> 1 then
    Halt(1);
  if sizeof(tw39795_t3.tw39795_txx) <> 100 then
    Halt(2);
  end;
  {$pop}

end;
{$pop}

{ Case tw10247b.pas }
{$push}

{$h+}
begin
  writeln(tw10247b_GetIntNode);
  writeln(tw10247b_GetStringNode);
end;
{$pop}

{ Case tw20028.pas }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw20192.pas }
{$push}

{$H+}
begin
  tw20192_V := tw20192_V.Create(589);
  WriteLn('V.Bug = ', tw20192_V.Bug);
  if tw20192_V.Bug<>100000 div sizeof(Integer) then
    halt(1);
  tw20192_V.Free;
  writeln('ok');
end;
{$pop}

{ Case tw21654.pas }
{$push}

begin
end;
{$pop}

{ Case tw28058.pas }
{$push}

begin
end;
{$pop}

{ Case tw41358.pas }
{$push}

begin
end;
{$pop}

{ Case tw6624.pas }
{$push}

{$H+}
begin
end;
{$pop}

end.
