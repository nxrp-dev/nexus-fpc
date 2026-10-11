{ %norun }
{ Checked Cardinal bitwise expressions and variable-bound Word loops. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tw11349.pp }
{$push}
{$R+,Q+}

const
  tw11349_ws_border = DWORD($800000);

var
  tw11349_style: Cardinal;
{$pop}

{ Case tw34543.pp }
{$push}
{$r+}
procedure tw34543_range_check_fail;
var tw34543_v : word;
    tw34543_vto : word;
    tw34543_vno : word;
begin
     tw34543_vto:=3;
     tw34543_vno:=0;
     for tw34543_v:=tw34543_vno to tw34543_vto do {Error: range check error while evaluating constants (-1 must be between 0 and 65535)}
     begin
     end;
end;
{$pop}

begin
  { Case tw11349.pp }
  {$push}
{$R+,Q+}
begin
  tw11349_style := 0;
  tw11349_style := tw11349_style and not tw11349_ws_border;
end;
  {$pop}

  { Case tw34543.pp }
  {$push}
{$R+}
begin
end;
  {$pop}

end.
