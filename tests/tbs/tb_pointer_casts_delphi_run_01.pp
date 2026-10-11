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

end.
