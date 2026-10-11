{ %norun }
{ %opt=-Sew }
{ Generic class result initialization and comparisons involving unresolved types. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0617.pp }
{$push}
{ We don't want this warning to occur again }
{$warn 5059 error}

type
  generic tb0617_tgenericstructlist<T> = class
  public
    function tb0617_remove(const tb0617_item: T): Integer;
    procedure tb0617_delete(tb0617_index: Integer);
    function tb0617_indexof(const tb0617_item: T): Integer;
  end;

function tb0617_tgenericstructlist.tb0617_remove(const tb0617_item: T): Integer;
begin
  Result := tb0617_indexof(tb0617_item);
  { for some reason, FPC 3.1.1 makes here incorrect warning:
    castlegenericlists.pas(254,13) Warning: Function result variable does not seem to be initialized }
  if Result >= 0 then
    tb0617_delete(Result);
end;

function tb0617_tgenericstructlist.tb0617_indexof(const tb0617_item: T): Integer;
begin
  Result := 0;
end;

procedure tb0617_tgenericstructlist.tb0617_delete(tb0617_index: Integer);
begin

end;
{$pop}

{ Case tb0702.pp }
{$push}
{ don't optimize TypeInfo comparisons if undefined types are involved }


type
  generic tb0702_ttest<tb0702_s> = class
    procedure tb0702_test;
  end;

procedure tb0702_ttest.tb0702_test;
begin
  if TypeInfo(tb0702_s) = TypeInfo(LongInt) then
    Writeln('Test');
end;
{$pop}

begin
  { Case tb0617.pp }
  {$push}
begin

end;
  {$pop}

  { Case tb0702.pp }
  {$push}
begin

end;
  {$pop}

end.
