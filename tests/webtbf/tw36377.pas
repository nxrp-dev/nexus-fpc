{ %fail }
{$mode objfpc}

program test;
uses
 Generics.Collections;

// Type identifier expected
// Internal error 2019112401
generic function CopyList<T>(source: specialize Generics.Collections.TObjectList<T>): specialize Generics.Collections.TObjectList<T>;
begin
end;

begin
end.