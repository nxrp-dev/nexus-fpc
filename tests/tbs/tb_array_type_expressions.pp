{ Array type bounds, constant expressions and packed declarations. }

{ tb0073.pp }
{  Shows Missing High() (internal) function.             OK 0.99.6 (MVC) }

type

 tHugeArray = array [ 1 .. High(Word) ] of byte;

{ tb0108.pp }
{ packed array isn't allowed                            OK 0.99.6 (FK) }

type
   myarray = packed array[0..10] of longint;

{ tb0361.pp }
type
  e=(one,two,three);

var
  a : array[0..cardinal(two)+1] of byte;

begin

end.
