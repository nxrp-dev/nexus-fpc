{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %OPT=-Sew -vw }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0504.pas }
{$push}


{$T-}

var
  tb0504_i: integer;
  tb0504_p: pointer;

{$pop}

{ Case tw1948.pas }
{$push}


{ Source provided for Free Pascal Bug Report 1948 }
{ Submitted by "Sergey Kosarevsky" on  2002-04-27 }
{ e-mail: netsurfer@au.ru }
Function tw1948_A:Longint;
Begin
   Exit(0);
End;


{$pop}

{ Case tw3172.pas }
{$push}


type
  tw3172_PUI32 = ^Longword;
var
  tw3172_P : tw3172_PUI32;
  tw3172_Count : Longint;
  tw3172_Dw    : Longword;

{$pop}

{ Case tw3490.pas }
{$push}


{ Source provided for Free Pascal Bug Report 3490 }
{ Submitted by "Tomas Hajny" on  2004-12-29 }
{ e-mail:  }
var
 tw3490_A: byte;
 tw3490_B: cardinal;


{$pop}

{ Case tw3952.pas }
{$push}


{ Source provided for Free Pascal Bug Report 3952 }
{ Submitted by "Ivo Steinmann" on  2005-05-08 }
{ e-mail: istienmann@bluewin.ch }
var
  tw3952_P: Pointer;
  tw3952_X: Longword;

{$pop}

begin

{ Case tb0504.pas }
{$push}
{$T-}
begin
  tb0504_p := pointer(@tb0504_i)+5;
  tb0504_i := integer(tb0504_p-tb0504_p);
end;
{$pop}

{ Case tw1948.pas }
{$push}

Begin
   tw1948_A;
End;
{$pop}

{ Case tw3172.pas }
{$push}

begin
  tw3172_Dw:=1;
  tw3172_Count:=1;
  tw3172_p:=@tw3172_DW;
  // Increase pointer
  Inc(tw3172_P,tw3172_Count);
  if tw3172_Dw<>1 then
    halt(1);
end;
{$pop}

{ Case tw3490.pas }
{$push}

begin
 tw3490_A := 3;
 tw3490_B := 0;
 tw3490_B := tw3490_B + tw3490_A * tw3490_A;
end;
{$pop}

{ Case tw3952.pas }
{$push}

begin
  tw3952_X := 0;
  tw3952_P := nil;
  tw3952_P := Pointer(tw3952_P + tw3952_X - 12);
  tw3952_P := Pointer(tw3952_P + tw3952_X + 12);
end;
{$pop}

end.
