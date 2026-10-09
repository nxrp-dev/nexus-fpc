{ %FAIL }
{ Old file: tbf0284.pp }
{ wrong file position with dup id in other unit        OK 0.99.13 (PFV) }

uses tb0243 in 'tbs/tb0243.pp';
{$HINTS ON}
type
  o2=object(o1)
    p : longint;
  end;

begin
end.
