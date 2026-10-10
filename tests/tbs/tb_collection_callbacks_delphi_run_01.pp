{ Anonymous comparer callbacks in record BinarySearch and list Pack. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

uses Classes, SysUtils, Generics.Collections, Generics.Defaults, Math;

{ Case tb0716.pp }
{$push}
type
  tb0716_tstackparam = record
    Base, Limit: QWord;
  end;

var
  tb0716_list: TList<tb0716_tstackparam>;
  tb0716_s: tb0716_tstackparam;
  tb0716_index: SizeInt;
{$pop}

{ Case tb9000.pp }
{$push}
var
  tb9000_list: TList<Integer>;
  tb9000_objlist: TObjectList<TObject>;
{$pop}

begin
  { Case tb0716.pp }
  {$push}
begin
  tb0716_list := TList<tb0716_tstackparam>.Create(TComparer<tb0716_tstackparam>.Construct(
    function (const A, B: tb0716_tstackparam): Integer
    begin
      Result := IfThen(A.Limit < B.Limit, -1,
        IfThen(A.Limit = B.Limit, 0, 1));
    end)
  );
  try
    tb0716_s.Limit := 100;
    tb0716_s.Base := 200;
    tb0716_list.Add(tb0716_s);

    tb0716_s.Limit := 210;
    tb0716_s.Base := 300;
    tb0716_list.Add(tb0716_s);

    tb0716_s.Limit := 350;
    tb0716_s.Base := 400;
    tb0716_list.Add(tb0716_s);

    tb0716_s.Limit := 50;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 0) then
      Halt(1);

    tb0716_s.Limit := 100;
    if not tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 0) then
      Halt(2);

    tb0716_s.Limit := 150;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 1) then
      Halt(3);

    tb0716_s.Limit := 210;
    if not tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 1) then
      Halt(4);

    tb0716_s.Limit := 290;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 2) then
      Halt(5);

    tb0716_s.Limit := 340;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 2) then
      Halt(6);

    tb0716_s.Limit := 350;
    if not tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 2) then
      Halt(7);

    tb0716_s.Limit := 360;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 3) then
      Halt(8);

    tb0716_s.Limit := 450;
    if tb0716_list.BinarySearch(tb0716_s, tb0716_index) or (tb0716_index <> 3) then
      Halt(9);

  finally
    tb0716_list.Free;
  end;
end;
  {$pop}

  { Case tb9000.pp }
  {$push}
begin
  tb9000_list := TList<Integer>.Create;
  try
    tb9000_list.AddRange([0, 1, 0, 2, 0, 3, 3, 0, 2, 0, 1, 0]);
    if tb9000_list.Count <> 12 then Halt(1);

    // remove 2
    tb9000_list.Pack(
      function(const L, R: Integer): Boolean
      begin
        Result := L = 2;
      end
    );
    if tb9000_list.Count <> 10 then Halt(2);

    // remove zeros
    tb9000_list.Pack;
    if tb9000_list.Count <> 4 then Halt(3);
  finally
    tb9000_list.Free;
  end;

  tb9000_objlist := TObjectList<TObject>.Create;
  try
    tb9000_objlist.Add(TObject.Create);
    tb9000_objlist.Add(nil);
    tb9000_objlist.Add(TStream.Create);
    tb9000_objlist.Add(nil);
    tb9000_objlist.Add(TObject.Create);
    tb9000_objlist.Add(nil);
    tb9000_objlist.Add(TStream.Create);
    if tb9000_objlist.Count <> 7 then Halt(4);

    // remove nil
    tb9000_objlist.Pack;
    if tb9000_objlist.Count <> 4 then Halt(5);

    // remove all TStream
    tb9000_objlist.Pack(
      function(const L, R: TObject): Boolean
      begin
        Result := L is TStream;
      end);
    if tb9000_objlist.Count <> 2 then Halt(6);

  finally
    tb9000_objlist.Free;
  end;
end;
  {$pop}

end.
