
{ Record-field, inherited and set-valued property accessors. }

{ tb0178.pp }
{ problem with properties                              OK 0.99.11 (PFV) }

{$mode objfpc}

type
  TMyRec = record
    Int: Integer;
    Str: String;
  end;

  TMyClass = class
  private
    FMyRec: TMyRec;
  public
    property AnInt: Integer read FMyRec.Int;
    property AStr: String read FMyRec.Str;
  end;

{ tb0259.pp }
{ inherited property generates wrong assembler         OK 0.99.13 (PFV) }

{$ifdef fpc}{$mode objfpc}{$endif}
type
  c1=class
    Ffont : longint;
    property Font:longint read Ffont write Ffont;
  end;

  c2=class(c1)
    function GetFont:longint;
    procedure setfont(l: longint);
  end;

function c2.GetFont:longint;
begin
  result:=inherited Font;
end;

procedure c2.SetFont(l: longint);
begin
  inherited font := l;
end;

var
  c: c2;

{ tb0510.pp }
{$mode objfpc}
type
  TSynIdentChars = set of char;
  tobj = class
    function GetIdentChars: TSynIdentChars; virtual;
    procedure p(s : tSynIdentChars);
    property IdentChars: TSynIdentChars read GetIdentChars;
  end;

function tobj.GetIdentChars: TSynIdentChars;
  begin
  end;

procedure tobj.p(s : tSynIdentChars);
   begin
     p(IdentChars+['-']);
   end;

{ tw1318.pp }
{$ifdef fpc}{$mode objfpc}{$endif}

type
  rec = record
    ch : char;
  end;

  TBadObject = class
    a: array[0..0,0..0] of array[0..0] of rec;
  public
    property a0: char read a[0,0][0].ch;
  end;

var
  BadObject: TBadObject;

{ tw2999.pp }
{ Source provided for Free Pascal Bug Report 2999 }
{ Submitted by "Sergey Kosarevsky" on  2004-03-03 }
{ e-mail: netsurfer@au.ru }

{$mode objfpc}

Type tSelector=(FIRST, SECOND);

Type TEnumArrayProperties=Class
       Private
        T:Array[tSelector] Of Longint;
       Public
        Property T1:Longint Read T[FIRST];
        Property T2:Longint Read T[SECOND];
     End;

{ tw6543.pp }
{$ifdef fpc}
{$mode objfpc}
{$endif}

type
  TBooleanArrayProperty = class
    a: array[boolean] of byte;
    property f: byte read a[false] write a[false];
  end;

var
  lBooleanProperty: TBooleanArrayProperty;

{ tw10795.pp }
{$mode objfpc}
type
  TIndexedObject = object
    function GetItem(const i :Integer) :Integer;
    property Items[i :Integer] :Integer read GetItem; default;
  end;

function TIndexedObject.GetItem(const i :Integer) :Integer;
begin
  Result := i;
end;

var
  Obj :TIndexedObject;

{ tw0819.pp }
{$mode objfpc}
type
  T1 = class
    function Get(I: Integer): Integer; virtual; abstract;
    property T[I: Integer]: Integer read Get; default;
  end;

  T2 = class(T1)
    function Get(I: Integer): Integer; override;
    property T[I: Integer]: Integer read Get; default;
  end;

function T2.Get(I: Integer): Integer;
begin
  Result:=I;
end;

var
   lIndexedChild : t2;

begin
{ tb0259.pp }
  c:=c2.create;
  c.ffont:=5;
  if c.getfont<>5 then
    halt(1);
  c.setfont(10);
  if c.getfont<>10 then
    halt(2);
  if c.ffont<>10 then
    halt(3);

  { tw1318.pp }
  BadObject := TBadObject.Create;
    BadObject.a[0,0][0].ch := 'a';
    if BadObject.a0 = BadObject.a[0,0][0].ch then;
    BadObject.Free;
  ;

  { tw6543.pp }
  lBooleanProperty := TBooleanArrayProperty.Create;
    lBooleanProperty.f := 1;
    if (lBooleanProperty.a[false] <> 1) then
      halt(1);
  ;

  { tw10795.pp }
  WriteLn(Obj[0],' ',Obj[10]);
  ;

  { tw0819.pp }
  lIndexedChild:=t2.create;
     if lIndexedChild[9]<>9 then
       halt(1)
     else
       halt(0);
  ;
end.
