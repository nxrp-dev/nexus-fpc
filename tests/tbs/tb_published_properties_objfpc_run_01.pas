{ Published enumeration subranges and floating-point property access. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}
{$M+}

uses typinfo;

{ Case tb0347.pas }
{$push}
type
   tb0347_tenum = (tb0347_te_first,tb0347_te_second,tb0347_te_third,tb0347_te_fourth,tb0347_te_fifth);

   tb0347_tenumrange = tb0347_te_second..tb0347_te_fourth;

   tb0347_tc1 = class
      public
        tb0347_fe : tb0347_tenumrange;
      published
        property enumrange : tb0347_tenumrange read tb0347_fe write tb0347_fe;
   end;
{$pop}

{ Case tb0467.pas }
{$push}
type
  tb0467_tmyobject = class
    protected
      tb0467_fs : single;
    published
      property s : single read tb0467_fs write tb0467_fs default 3.1415;
  end;

var
  tb0467_myobject : tb0467_tmyobject;
{$pop}

begin
  { Case tb0347.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0467.pas }
  {$push}
begin
  tb0467_myobject:=tb0467_tmyobject.create;
  SetFloatProp(tb0467_myobject,'s',3);
  if GetFloatProp(tb0467_myobject,'s')<>3 then
    begin
      writeln('error');
      halt(1);
    end;
  tb0467_myobject.free;
end;
  {$pop}

end.
