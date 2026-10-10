unit ugeneric_set_storage;
{$mode objfpc}
interface
type
  generic TSetBox<T> = class
  public type
    TItems = set of T;
  public
    Items: TItems;
    procedure SetRange(First, Last: T);
  end;
implementation

procedure TSetBox.SetRange(First, Last: T);
begin
  Items := [First..Last];
end;

end.
