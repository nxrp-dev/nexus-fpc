{ Ordinal, method-record and null pointer casts in Delphi mode. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0400.pp }
{$push}
var
   tb0400_b : byte;
   tb0400_i : smallint;
   tb0400_i64 : int64;
   tb0400_q : qword;
   tb0400_p : pointer;
{$pop}

{ Case tb0423.pp }
{$push}
{$ifdef fpc}{$endif}

type
{$ifndef fpc}
  codepointer = pointer;
{$endif}
   tb0423_tmethod = record
      code : codepointer;
      data : pointer;
   end;

var
   tb0423_p : procedure(l : longint) of object;
{$pop}

{ Case tb0443.pp }
{$push}
{$ifdef fpc}
  
{$else}
type
  qword = int64;
{$endif}

var
   tb0443_b : byte;
   tb0443_i : smallint;
   tb0443_i64 : int64;
   tb0443_q : qword;
   tb0443_p : pointer;
{$pop}

{ Case tb0465.pp }
{$push}
var tb0465_x:pointer;
{$pop}

{ Case tb0539.pp }
{$push}
const
  tb0539_o = TObject(0);

var
  tb0539_o2 : TObject;

{$r+}
{$pop}

{ Case tb0554.pp }
{$push}
// check whether enums and integers can be casted to object references; this
// should work in Delphi mode (is Delphi compatible)

{$packenum 2}
type
  tb0554_tenum = (tb0554_a, tb0554_b, tb0554_c);

var
  tb0554_i : Word;
  tb0554_e : tb0554_tenum;
  tb0554_o : TObject;
{$pop}

{ Case tb0594.pp }
{$push}
{$ifdef fpc}

{$endif}

type
{$ifndef fpc}
  codepointer = pointer;
{$endif}
  tb0594_tc = class
    class procedure tb0594_test;
  end;

  tb0594_tp = procedure;
  tb0594_tp2 = procedure of object;

class procedure tb0594_tc.tb0594_test;
begin
end;

var
  tb0594_p: tb0594_tp;
  tb0594_p2: tb0594_tp2;
{$pop}

begin
  { Case tb0400.pp }
  {$push}
begin
   tb0400_p:=pointer(tb0400_b);
   tb0400_p:=pointer(tb0400_i);
   tb0400_p:=pointer(tb0400_i64);
   tb0400_p:=pointer(tb0400_q);
end;
  {$pop}

  { Case tb0423.pp }
  {$push}
begin
   tb0423_tmethod(tb0423_p).data:=nil;
end;
  {$pop}

  { Case tb0443.pp }
  {$push}
begin
   tb0443_p:=pointer(tb0443_b);
   tb0443_p:=pointer(tb0443_i);
   tb0443_p:=pointer(tb0443_i64);
   tb0443_p:=pointer(tb0443_q);
end;
  {$pop}

  { Case tb0465.pp }
  {$push}
begin
  tb0465_x:=0;
  tb0465_x:=pointer(0);
end;
  {$pop}

  { Case tb0539.pp }
  {$push}
{$R+}
begin
  tb0539_o2:=tb0539_o;
end;
  {$pop}

  { Case tb0554.pp }
  {$push}
begin
  tb0554_o := TObject(tb0554_e);
  tb0554_o := TObject(tb0554_i);
  tb0554_i := Word(tb0554_o);
  tb0554_e := tb0554_tenum(tb0554_o);
end;
  {$pop}

  { Case tb0594.pp }
  {$push}
begin
  tb0594_p:=tb0594_tp(tb0594_tc.tb0594_test);
  tb0594_p2:=tb0594_tc.tb0594_test;
  if codepointer(@tb0594_p)<>tmethod(tb0594_p2).code then
    halt(1);
end;
  {$pop}

end.
