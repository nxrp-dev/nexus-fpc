{ Forward class types and abbreviated class declarations. }

{$mode objfpc}
uses
  Classes;

{ tb0278.pp }

{$ifdef fpc}{$mode objfpc}{$endif}

type
  TMyClass = class(TPersistent);

var
  MyVar: Integer;

type
  TMyClass2 = class(TObject)
    procedure MyProc;
  end;

  TMyOtherClass = class(TPersistent);

procedure TMyClass2.MyProc;
var
  MyImportantVar: Integer;
begin
end;

{ tb0302.pp }
{$mode objfpc}

{ tests forward class types }

type
   tclass1 = class;

   tclass2 = class
      class1 : tclass1;
   end;

var
   c : tclass1;

type
   tclass1 = class(tclass2)
      i : longint;
   end;

begin
  { tb0302.pp }
  c:=tclass1.create;
  c.i:=12;
end.
