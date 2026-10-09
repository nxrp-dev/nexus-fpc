{ Generics regression cases; original case IDs are retained below. }

{ Case tb0560.pp }
{$push}
{$mode objfpc}{$H+}

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

{ Case tw34232.pp }
{$push}
{$mode objfpc}{$H+}
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

{ Case tw39795.pp }
{$push}
{$mode objfpc}{$H+}

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

{ Case tw39805a.pp }
{$push}
{$mode objfpc}{$H+}
const
  tw39805a_ts=3;
type
  generic tw39805a_gtest<T>=record
    case byte of
    0:(ta:array [0..2] of T);
    1:(t1:T;tw39805a_t2:T;tw39805a_t3:T);
  end;
{$pop}

{ Case tw40608.pp }
{$push}
{$mode ObjFPC}{$H+}

generic function tw40608_genericfunc<T>: String;

  function tw40608_innerfunc: String;
  begin // project1.lpr(6,3) Error: Duplicate identifier "$result"
  end;

begin
end;
{$pop}

{ Case tw7998.pp }
{$push}
{$mode objfpc}{$H+}

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

begin
  { Case tb0560.pp }
  {$push}

  begin
writeln(tb0560_linehtml('|  1 | 2 | 3'));
  end;
  {$pop}

  { Case tw34232.pp }
  {$push}

  begin
writeln(sizeof(tw34232_tteststringstring.tw34232_tpairsizeequivalent));
  end;
  {$pop}

  { Case tw39795.pp }
  {$push}

  begin
if sizeof(tw39795_t2.tw39795_txx) <> 1 then
    Halt(1);
  if sizeof(tw39795_t3.tw39795_txx) <> 100 then
    Halt(2);
  end;
  {$pop}

end.
