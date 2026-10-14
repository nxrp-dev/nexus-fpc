{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes;

{ Case tw18266.pas }
{$push}


{$H+}



// A literal casted to Wide/UnicodeString is expected to be of type vtWideString.
const
  tw18266_expected: array[0..3] of integer = (vtAnsiString,
{$ifdef windows}
    vtWideString, vtUnicodeString, vtWideString
{$else}
    vtUnicodeString, vtUnicodeString, vtUnicodeString
{$endif}
  );

procedure tw18266_variantfunc(vars: array of const);
var
  i: integer;
begin
  for i := Low(vars) to High(vars) do
  begin
    writeln('vars[',i,'].VType=',ord(vars[i].VType));
    if vars[i].VType <> tw18266_expected[i] then
      Halt(1);
  end;
end;

var
  tw18266_wstr: WideString;

{$pop}

{ Case tw3073.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3073 }
{ Submitted by "Martin Schreiber" on  2004-04-30 }
{ e-mail:  }


 {$H+}


var
 tw3073_po1,tw3073_po2: pwidechar;

{$pop}

{ Case tw3578.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3578 }
{ Submitted by "Martin Schreiber" on  2005-01-21 }
{ e-mail:  }


{$H+}


type
 tw3578_widestringarty = array of widestring;

procedure tw3578_proc(const tw3578_ar1,tw3578_ar2: array of widestring);
begin
end;

function tw3578_getarray: tw3578_widestringarty;
begin
 result:= nil;
end;

var
 tw3578_ar1,tw3578_ar2: tw3578_widestringarty;

{$pop}

{ Case tw3579.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3579 }
{ Submitted by "Martin Schreiber" on  2005-01-21 }
{ e-mail:  }


{$H+}

type
 tw3579_stringarty = array of string;
var
 tw3579_ar1,tw3579_ar2: tw3579_stringarty;


{$pop}

{ Case tw3805.pas }
{$push}
{$H+}


type
 tw3805_stringarty = array of string;
var
 tw3805_ar1,tw3805_ar2: tw3805_stringarty;

{$pop}

{ Case tw4999.pas }
{$push}

{$H+}

var    tw4999_s:String;
       tw4999_i:integer;

{$pop}

begin

{ Case tw18266.pas }
{$push}

{$H+}
{$ifdef windows}
{$else}
{$endif}
begin
  tw18266_variantfunc(['abc',WideString('def'),UnicodeString('123'),tw18266_wstr]);
end;
{$pop}

{ Case tw3073.pas }
{$push}

{$H+}
begin
 tw3073_po1:= 'abc';
 tw3073_po2:= tw3073_po1+1;
 if tw3073_po2-tw3073_po1<>1 then
   halt(1);
 if pwidechar(24)-pwidechar(22)<>1 then
  halt(1);
 if pwidechar(22)+1 <> pwidechar(24) then
   halt(1);
end;
{$pop}

{ Case tw3578.pas }
{$push}

{$H+}
begin
 tw3578_proc(tw3578_ar1,tw3578_ar2);            //ok
 tw3578_proc(tw3578_ar1,tw3578_getarray);       //ok
 tw3578_proc(tw3578_getarray,tw3578_ar2);       //ok
 tw3578_proc(tw3578_getarray,tw3578_getarray);  //Internal error 9999
end;
{$pop}

{ Case tw3579.pas }
{$push}

{$H+}
begin
 setlength(tw3579_ar1,4);
 tw3579_ar2:= copy(tw3579_ar1);       //AV
end;
{$pop}

{ Case tw3805.pas }
{$push}

{$H+}
begin
 setlength(tw3805_ar1,4);
 tw3805_ar2:= copy(tw3805_ar1,1,3);
 if (length(tw3805_ar2) <> 3) then
   halt(1);
 tw3805_ar2:= copy(tw3805_ar1,1,4);
 if (length(tw3805_ar2) <> 3) then
   halt(2);
 tw3805_ar2:= copy(tw3805_ar1,1,5);
 if (length(tw3805_ar2) <> 3) then
   halt(3);
end;
{$pop}

{ Case tw4999.pas }
{$push}

{$H+}
begin
 tw4999_s:='123123sdfjkysdjfklsdn3m,w45';
 for tw4999_i:=0 to 15 do begin
  tw4999_s:=tw4999_s+tw4999_s;
  writeln(tw4999_i);
 end;
end;
{$pop}

end.
