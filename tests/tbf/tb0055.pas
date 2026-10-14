{ %FAIL }
{ Old file: tbf0284.pas }
{ wrong file position with dup id in other unit        OK 0.99.13 (PFV) }

uses tb0243 in 'tbs/tb0243.pas';
{$HINTS ON}
type
  o2=object(o1)
    p : longint;
  end;

begin
end.
