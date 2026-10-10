{ SysUtils integer-set layout and resource-string exception formatting. }
{$mode objfpc}

uses
  sysutils;

{ Case tb0334.pp }
var
  tb0334_s : tintegerset;

{ Case tb0482.pp }
resourcestring tb0482_sMyNewErrorMessage = 'Illegal value: %d';

begin
  { Case tb0334.pp }
  if sizeof(tb0334_s)<>sizeof(integer) then
    begin
      writeln('Wrong size of Sysutils.TIntegerSet (',sizeof(tb0334_s),')');
      halt(1);
    end;

  { Case tb0482.pp: keep last because success terminates the program. }
  try
    raise Exception.CreateResFmt(@tb0482_sMyNewErrorMessage, [-1]);
  except
    on e : exception do
      begin
        if e.message='Illegal value: -1' then
          halt(0)
        else
          begin
            writeln('error : ',e.message);
            halt(1);
          end;
      end;
  end;
end.
