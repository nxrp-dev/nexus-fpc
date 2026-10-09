{ Class method declarations: virtual, abstract, stdcall and strict visibility. }

{ tb0166.pp }
{ calling specifications aren't allowed in class declarations, this should be allowed                                OK 0.99.11  (PM) }

{$mode objfpc}
type
   to1 = class
       function GetCaps1 : Longint;virtual;abstract;
       function GetCaps2 : Longint;virtual;stdcall;
       function GetCaps : Longint;virtual;stdcall;abstract;
   end;

function to1.GetCaps2 : Longint;stdcall;
begin
end;

{ tb0303.pp }
{$mode objfpc}

type
   tclass1 = class
      procedure a;virtual;
      procedure b;virtual;
   end;

   tclass2 = class(tclass1)
      procedure a;override;
      procedure b;override;
      procedure c;virtual;
   end;

  procedure tclass1.a;

    begin
    end;

  procedure tclass1.b;

    begin
    end;

  procedure tclass2.a;

    begin
    end;

  procedure tclass2.b;

    begin
    end;

  procedure tclass2.c;

    begin
    end;

{ tb0493.pp }
{$mode objfpc}

type
  tobject1 = class
  strict protected
    spro : integer;
  strict private
    spriv : integer;
  public
    procedure p1;
  end;

  tobject2 = class(tobject1)
    procedure p2;
  end;

procedure tobject1.p1;
  begin
    spro:=1;
    spriv:=2;
  end;

procedure tobject2.p2;
  begin
    spro:=3;
  end;

var
  o1 : tobject1;
  o2 : tobject2;

begin
  { tb0493.pp }
  o1:=tobject1.create;
  o2:=tobject2.create;
  o1.free;
  o2.free;
end.
