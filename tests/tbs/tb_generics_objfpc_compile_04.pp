{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw39679.pp }
{$push}
{$mode objfpc}{$H+}
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
{$mode objfpc}{$H+}
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

end.
