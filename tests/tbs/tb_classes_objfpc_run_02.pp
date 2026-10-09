{ Classes regression cases; original case IDs are retained below. }

{ Case tw10757.pp }
{$push}
{$MODE Objfpc}

type
  tw10757_ta = class
    tw10757_t: array of Double;
  end;

var
  tw10757_a: tw10757_ta;

function tw10757_p:tw10757_ta;
begin
  Result := tw10757_a;
end;

function tw10757_m: Double;
begin
  Result := 300;
end;

var
  tw10757_i: Integer;
{$pop}

{ Case tw12242a.pp }
{$push}
{$mode objfpc}

type
  tw12242a_tc = class
    class procedure tw12242a_a; cdecl; static;
    class procedure tw12242a_b; cdecl; static;
    procedure tw12242a_c;
  end;

var
  tw12242a_ok: boolean;

class procedure tw12242a_tc.tw12242a_a; cdecl; static;
begin
  writeln('a');
  tw12242a_ok:=true;
end;

class procedure tw12242a_tc.tw12242a_b; cdecl; static;
begin
  tw12242a_a;
end;

procedure tw12242a_tc.tw12242a_c;
begin
  tw12242a_a;
end;

var
  tw12242a_c: tw12242a_tc;
{$pop}

{ Case tw1283.pp }
{$push}
{$mode objfpc}
 type
     tw1283_t = class(tobject)
      constructor tw1283_init;
     end;

 constructor tw1283_t.tw1283_init;
 begin
  fail; { constructor will return NULL in ESI now, which is OK }
 end;

 type
     tw1283_c = class(tobject)
      procedure tw1283_p;
     end;

 procedure tw1283_c.tw1283_p;
  var tw1283_i:tw1283_t;
 begin
  tw1283_i:=tw1283_t.tw1283_init;
  if tw1283_i<>nil then
    begin
       writeln('Problem with saving a non assigned self');
       halt(1);
    end;
  { returned is NULL in ESI, and AfterConstructor is attempted to call by
    referencing an invalid VMT via ESI}
 end;

 var tw1283_i:tw1283_c;
{$pop}

{ Case tw1573.pp }
{$push}
{$mode objfpc}

type
        tw1573_tcheck=class(TObject);

var
        tw1573_vla : tw1573_tcheck;
        tw1573_vlb : TObject;

procedure tw1573_aa(const ParXX :array of TObject);
begin
        // writeln(cardinal(ParXX[0]),' ', cardinal(ParXX[1]));
        if (ParXX[0]<>tw1573_vla) or (ParXX[1]<>tw1573_vlb) then
          begin
             writeln('error');
             halt(1);
          end;
end;
{$pop}

{ Case tw1798.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}

type

tw1798_tgraphiccontrol = class
end;

tw1798_tbutton = class
end;

tw1798_tbitbtn = class(tw1798_tbutton)
private
published
end;

tw1798_tspeedbutton = class(tw1798_tgraphiccontrol)
published
end;

tw1798_tmybutton = class(tw1798_tbitbtn);

const tw1798_myconst = 1;
{$pop}

{ Case tw18443.pp }
{$push}
{$mode objfpc}
type
  tw18443_tbase = class
    function tw18443_print: String; virtual;
  end;

  tw18443_tdesc1 = class(tw18443_tbase)
    function tw18443_print: String; override;
  end;

  tw18443_tdesc2 = class(tw18443_tbase)
    function tw18443_print: String; override;
  end;

function tw18443_tbase.tw18443_print: String;
begin
  Result := 'Base';
end;

function tw18443_tdesc1.tw18443_print: String;
begin
  Result := inherited + '-Desc1';
end;

function tw18443_tdesc2.tw18443_print: String;
begin
  Result := inherited tw18443_print + '-Desc2';
end;
{$pop}

{ Case tw2198.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2198 }
{ Submitted by "Sebastian Günther" on  2002-10-23 }
{ e-mail: sg@freepascal.org }

{$mode objfpc}

type
  tw2198_ttest = class
    procedure tw2198_x;
    procedure tw2198_x(i: Integer);
  end;

procedure tw2198_ttest.tw2198_x;
const tw2198_s = 'Test1';
begin
  writeln(tw2198_s);
end;

procedure tw2198_ttest.tw2198_x(i: Integer);
const tw2198_s = 'Test2';
begin
  writeln(tw2198_s);
end;

var
  tw2198_t : tw2198_ttest;
{$pop}

{ Case tw22869.pp }
{$push}
{$mode objfpc}

type
  tw22869_tc = class
    procedure tw22869_test; virtual;
  end;

  tw22869_trec = record
    tw22869_c: tw22869_tc;
  end;

procedure tw22869_tc.tw22869_test;
begin
end;

procedure tw22869_doit(tw22869_r: tw22869_trec);
begin
  tw22869_r.tw22869_c.tw22869_test;
end;

var
  tw22869_r: tw22869_trec;
  tw22869_c: tw22869_tc;
{$pop}

{ Case tw22878.pp }
{$push}
{$mode objfpc}
    type
        tw22878_t0= record
            tw22878_p: pointer;
        end;
        tw22878_t1= packed record
            tw22878_u16: word;
            tw22878_data: tw22878_t0;
        end;

        tw22878_td= class
            function tw22878_return: tw22878_t1;
        end;
            function tw22878_td.tw22878_return: tw22878_t1;
            begin
              tw22878_return.tw22878_u16:=1;
              tw22878_return.tw22878_data.tw22878_p:=pointer(2);
            end;
var
  tw22878_c: tw22878_td;
  tw22878_r: tw22878_t1;
{$pop}

{ Case tw2328.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2328 }
{ Submitted by "Pavel V. Ozerski" on  2003-01-20 }
{ e-mail: ozerski@list.ru }
{$ifdef fpc}
{$mode objfpc}
{$endif}
type
 tw2328_tclassa=class
  procedure DefaultHandler(var Message);override;
 end;
procedure tw2328_tclassa.DefaultHandler(var Message);
 begin
  inherited //;
 end;
{$pop}

{ Case tw24536.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}
type
  tw24536_tmyclass = class
    procedure tw24536_myabstractmethod; virtual; abstract;
    procedure tw24536_myabstractmethod2; virtual; abstract;
  end;

  tw24536_tmyclass2 = class(tw24536_tmyclass)
  end;

var
  tw24536_foo,tw24536_foo2: CodePointer;
{$pop}

{ Case tw2454.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2454 }
{ Submitted by "Nikolay Nikolov" on  2003-04-06 }
{ e-mail: nickysn1983@netscape.net }
{$MODE objfpc}

Type
  tw2454_tfunclass = Class(TObject)
    tw2454_data : Integer;
    Class Procedure tw2454_funproc(q : tw2454_tfunclass);
  End;

Class Procedure tw2454_tfunclass.tw2454_funproc(q : tw2454_tfunclass);

Begin
  Writeln(q.tw2454_data);
  With q Do
  Begin
    Writeln(q.tw2454_data);

    Writeln(tw2454_data); { fpc 1.1 says: Error: Only class methods can be accessed in class methods

    this is a bug, because 'data' actually means 'q.data' due to the 'with' statement,
    (this can be seen if you make this a normal method by removing the 'Class' keyword
    and running the program, it will writeln q.data, not self.data)
    so it shouldn't cause an error
    }
  End;
End;

Var
  tw2454_c1, tw2454_c2 : tw2454_tfunclass;
{$pop}

begin
  { Case tw10757.pp }
  {$push}

  begin
tw10757_a := tw10757_ta.Create;
  SetLength(tw10757_p.tw10757_t,2);
  tw10757_p.tw10757_t[0] := 70;
  tw10757_p.tw10757_t[1] := 80;
  tw10757_i := 0;
  while (tw10757_i < Length(tw10757_p.tw10757_t)) and (tw10757_m > tw10757_p.tw10757_t[tw10757_i]) do
    Inc(tw10757_i);
  if (tw10757_i<>2) then
    halt(1);
  end;
  {$pop}

  { Case tw12242a.pp }
  {$push}

  begin
tw12242a_ok:=false;
  tw12242a_tc.tw12242a_b;
  if not tw12242a_ok then
    halt(1);
  tw12242a_ok:=false;
  tw12242a_c:=tw12242a_tc.create;
  tw12242a_c.tw12242a_c;
  tw12242a_c.free;
  if not tw12242a_ok then
    halt(2);
  end;
  {$pop}

  { Case tw1283.pp }
  {$push}

  begin
tw1283_i:=tw1283_c.create; tw1283_i.tw1283_p;
  end;
  {$pop}

  { Case tw1573.pp }
  {$push}

  begin
tw1573_vlb := TObject.Create;
        tw1573_vla := tw1573_tcheck.Create;
        tw1573_aa([tw1573_vla,tw1573_vlb]);
  end;
  {$pop}

  { Case tw2198.pp }
  {$push}

  begin
tw2198_t:=tw2198_ttest.create;
  tw2198_t.tw2198_x;
  tw2198_t.tw2198_x(1);
  tw2198_t.free;
  end;
  {$pop}

  { Case tw22869.pp }
  {$push}

  begin
tw22869_c:=tw22869_tc.create;
  tw22869_r.tw22869_c:=tw22869_c;
  tw22869_doit(tw22869_r);
  tw22869_c.free;
  end;
  {$pop}

  { Case tw22878.pp }
  {$push}

  begin
tw22878_c:=tw22878_td.create;
  tw22878_r:=tw22878_c.tw22878_return;
  if tw22878_r.tw22878_u16<>1 then
    halt(1);
  if tw22878_r.tw22878_data.tw22878_p<>pointer(2) then
    halt(2);
  end;
  {$pop}

  { Case tw24536.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw24536_foo := @tw24536_tmyclass.tw24536_myabstractmethod;
  tw24536_foo2 := @tw24536_tmyclass.tw24536_myabstractmethod2;
  if tw24536_foo=tw24536_foo2 then
    Halt(1);
  tw24536_foo2 := @tw24536_tmyclass2.tw24536_myabstractmethod;
  if tw24536_foo<>tw24536_foo2 then
    Halt(2);
  end;
  {$pop}

  { Case tw2454.pp }
  {$push}

  begin
tw2454_c1 := tw2454_tfunclass.Create;
  tw2454_c2 := tw2454_tfunclass.Create;
  tw2454_c1.tw2454_data := 5;
  tw2454_c2.tw2454_data := 7;
  tw2454_c1.tw2454_funproc(tw2454_c2);
  tw2454_c1.Destroy;
  tw2454_c2.Destroy;
  end;
  {$pop}

end.
