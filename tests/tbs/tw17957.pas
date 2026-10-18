{$mode objfpc}
uses Generics.Collections;

type
  TFoo1 = class(TObject);

  TFoo2 = class
    type
      TFooList = specialize TList<TFoo1>;
  end;

begin
end.
