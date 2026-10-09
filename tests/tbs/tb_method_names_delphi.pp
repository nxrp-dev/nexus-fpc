{ Delphi method name shadowing and abbreviated constructor implementations. }

{ tb0325.pp }
{$mode delphi}
type
   tc1 = class
      l : longint;
      property p : longint read l;
   end;

   tc2 = class(tc1)
      { in Delphi mode }
      { parameters can have the same name as properties }
      procedure p1(p : longint);
   end;

procedure tc2.p1(p : longint);

  begin
  end;

{ tb0373.pp }
{$ifdef fpc}{$mode delphi}{$endif}
type
   tmyinterface = interface
      procedure p(p : longint); // Delphi allows this
   end;

{ tb0456.pp }
{$ifdef fpc}{$mode delphi}{$endif}

type
  c=class
   function Byte: Byte; virtual; abstract;
   function P(b: Byte):boolean; virtual; abstract;
  end;

{ tb0538.pp }
{$mode delphi}
type
  to1 = class
    procedure p1;
    procedure p2;
  end;

procedure to1.p1;
  begin
  end;

procedure to1.p2;
  const
    p1 : pointer = nil;
  begin
  end;

{ tb0518.pp }
{$mode delphi}
type
  tc = class
    constructor create(const n: ansistring);
  end;

constructor tc.create;
begin
  if (n <> 'abc') then halt(1);
end;

begin
  { tb0518.pp }
  tc.create('abc');
end.
