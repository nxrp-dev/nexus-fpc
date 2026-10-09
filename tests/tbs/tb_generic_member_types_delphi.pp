{ Generic member aliases, interface arrays and generic record arrays. }

{ tw20995a.pp }
{$mode delphi}{$H+}

type
  IAliasedArrayElement<T> = interface
  end;

  TAliasedInterfaceArray<T> = class
  type
    IGenTest = IAliasedArrayElement<T>;
  private
    FData: array of IGenTest;
  end;

  TAliasedObjectArray = TAliasedInterfaceArray<TObject>;

{ tw20995b.pp }
{$mode delphi}{$H+}

type
  IDirectArrayElement<T> = interface
  end;

  TDirectInterfaceArray<T> = class
  private
    FData: array of IDirectArrayElement<T>;
  end;

  TDirectObjectArray = TDirectInterfaceArray<TObject>;

{ tw20557.pp }
{$mode delphi}{$H+}

type

   TRec<T> = record
      Value : T;
   end;
   TRecArray<T> = array of TRec<T>;

   { TFoo }

   TFoo<T> = class
     FArr : TRecArray<T>;
     procedure Test;
   end;

{ TFoo<T> }

procedure TFoo<T>.Test;
begin
  SetLength(FArr, 1);
end;

{ tw20851.pp }
{$ifdef fpc}{$mode delphi}{$else}{$apptype console}{$endif}
Type
  tbwimagegen<T> = Class
                 Type

                    BaseUnit = T;
                 procedure alloc;
                 end;

procedure tbwimagegen<T>.alloc;
var i,j : integer;
begin
  j:=sizeof(t);
  i:=sizeof(baseunit);
end;

begin

end.
