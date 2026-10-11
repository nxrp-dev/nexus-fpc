{ %norun }
{ Overloaded open arrays and Delphi open ShortString parameters. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0576.pp }
{$push}
type tb0576_bytearray = array of byte;

procedure tb0576_zeromemory(var tb0576_x: array of byte; tb0576_startindex, tb0576_count: integer); overload;
begin
end;

procedure tb0576_zeromemory(var tb0576_x: array of tb0576_bytearray; tb0576_startindex, tb0576_count: integer); overload;
begin
end;

var
  tb0576_buffer: array of byte;
{$pop}

{ Case tb0698.pp }
{$push}
{ Open Strings is by default enabled in mode Delphi }



procedure tb0698_test(var tb0698_aarg: ShortString);
begin
end;

var
  tb0698_s: String[5];
{$pop}

begin
  { Case tb0576.pp }
  {$push}
begin
  tb0576_zeromemory(tb0576_buffer, 0, Length(tb0576_buffer));
end;
  {$pop}

  { Case tb0698.pp }
  {$push}
begin
  tb0698_s := 'Test';
  tb0698_test(tb0698_s);
end;
  {$pop}

end.
