{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0659a.pp }
{$push}




{$ifdef FPC_OBJFPC}
{$fatal FPC_OBJFPC defined}
{$endif}
{$ifdef FPC_DELPHI}
{$fatal FPC_DELPHI defined}
{$endif}
{$ifdef FPC_MACPAS}
{$fatal FPC_MACPAS defined}
{$endif}
{$ifdef FPC_ISO}
{$fatal FPC_ISO defined}
{$endif}
{$ifdef FPC_EXTENDEDPASCAL}
{$fatal FPC_EXTENDEDPASCAL defined}
{$endif}


{$pop}

{ Case tw0814.pp }
{$push}
const
  tw0814_MaxFloat80 = 1.1E+4932;

{$pop}

{ Case tw0895.pp }
{$push}



{$pop}

{ Case tw1111.pp }
{$push}
var
  tw1111_v : 0..5;
  tw1111_sMin, tw1111_sMax : 0..5;  // if top of range is less than 32, get compiler Panic

{$pop}

{ Case tw15293a.pp }
{$push}

{$pop}

{ Case tw17604.pp }
{$push}


{$pop}

{ Case tw2072.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2072 }
{ Submitted by "Bill Rayer" on  2002-08-09 }
{ e-mail: lingolanguage@hotmail.com }




(*$ifdef FPC*)
const tw2072_name = 'FPC';
(*$else *)(*Hello*)
const tw2072_name = 'Delphi';
(*$endif *)




{$pop}

{ Case tw2289.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2289 }
{ Submitted by "Mattias Gaertner" on  2002-12-27 }
{ e-mail: nc-gaertnma@netcologne.de }


{$IFDEF NotDefined}

//
{$IFDEF Bogus}
{$ENDIF}

{$ENDIF}


{$pop}

{ Case tw2779.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2779 }
{ Submitted by "Johannes Berg" on  2003-11-10 }
{ e-mail: bugs@johannes.sipsolutions.de }


{$IF DEFINED(asdf)}
{$IFEND}


{$pop}

{ Case tw2853.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2853 }
{ Submitted by "Bj”rn Hendriks" on  2003-12-18 }
{ e-mail: bjoern.hendriks.ext_ese@ts.siemens.de }



{$pop}

{ Case tw2853c.pp }
{$push}
{ OPT= -dloop }
{ bug report variant, check that it works in
  TP mode , added by Pierre }
{ Source provided for Free Pascal Bug Report 2853 }
{ Submitted by "Bj”rn Hendriks" on  2003-12-18 }
{ e-mail: bjoern.hendriks.ext_ese@ts.siemens.de }



{$pop}

{ Case tw2853d.pp }
{$push}
{ Equivalent regression IDs: tw2853d.pp, tw2853e.pp; exercised once. }
{ OPT= -dloop }
{ bug report variant, check that it works in
  TP mode , added by Pierre }
{ Source provided for Free Pascal Bug Report 2853 }
{ Submitted by "Bj”rn Hendriks" on  2003-12-18 }
{ e-mail: bjoern.hendriks.ext_ese@ts.siemens.de }



{$pop}

{ Case tw30654.pp }
{$push}
{$message info 'Test'}

{$pop}

{ Case tw3252.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3252 }
{ Submitted by "Tom Verhoeff" on  2004-08-16 }
{ e-mail: T.Verhoeff@tue.nl }

  { To demonstrate error with sqr in const expression }

const
  tw3252_Max1 = 12; { program compiles fine when changing 12 to 11 }
  tw3252_Max2 = tw3252_Max1 * tw3252_Max1; { this works fine }
  tw3252_Max3 = sqr ( tw3252_Max1 ); { this fails }

type
  tw3252_Index = 0 .. tw3252_Max3;

{ remainder not relevant, but included to have a complete program }

var
  tw3252_i: tw3252_Index;


{$pop}

{ Case tw35965.pp }
{$push}



{$pop}

{ Case tw3764.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3764 }
{ Submitted by "carl" on  2005-03-09 }
{ e-mail: cecodere@yahoo.ca }


{$pop}

{ Case tw3939.pp }
{$push}
{$warn symbol_platform on}
{$warnings-}
{$warn symbol_platform off}
{$warnings+}

{$pop}

{ Case tw40004.pp }
{$push}
{$overflowchecks on}
var
	tw40004_n: SizeUint;

{$pop}

{ Case tw4078.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4078 }
{ Submitted by "Thomas Schatzl" on  2005-06-13 }
{ e-mail:  }
{$ASSERTIONS ON}
var
  tw4078_q : dword;


{$pop}

{ Case tw41105.pp }
{$push}


// id
// {$WARN 5023 ON}    // compiles
// {$WARN 5023 OFF}   // compiles
{$WARN 5023 +}     // ERROR
{$WARN 5023 -}     // ERROR
{$WARN 5023+}      // ERROR
{$WARN 5023-}      // ERROR
{$WARN 5023 ERROR} // compiles

// name
{$WARN NO_RETVAL ON}    // compiles
{$WARN NO_RETVAL OFF}   // compiles
{$WARN NO_RETVAL +}     // ERROR
{$WARN NO_RETVAL -}     // ERROR
{$WARN NO_RETVAL+}      // ERROR
{$WARN NO_RETVAL-}      // ERROR
{$WARN NO_RETVAL ERROR} // compiles


{$pop}

{ Case tw41261.pp }
{$push}

{$R+}
const
  tw41261_INTCHARS = ['0' .. '9'];
  tw41261_HEXCHARS = ['a' .. 'f', 'A' .. 'F'] + tw41261_INTCHARS;

{$pop}

{ Case tw6184.pp }
{$push}

{$pop}

begin

{ Case tb0659a.pp }
{$push}

{$ifdef FPC_OBJFPC}
{$fatal FPC_OBJFPC defined}
{$endif}
{$ifdef FPC_DELPHI}
{$fatal FPC_DELPHI defined}
{$endif}
{$ifdef FPC_MACPAS}
{$fatal FPC_MACPAS defined}
{$endif}
{$ifdef FPC_ISO}
{$fatal FPC_ISO defined}
{$endif}
{$ifdef FPC_EXTENDEDPASCAL}
{$fatal FPC_EXTENDEDPASCAL defined}
{$endif}
begin
end;
{$pop}

{ Case tw0814.pp }
{$push}

begin
  Writeln(tw0814_MaxFloat80);
end;
{$pop}

{ Case tw0895.pp }
{$push}

begin
  {$I-}
  mkdir('test895');
  InOutRes:=0;
  {$I+}
  writeln('This is a test');
  {$I-}
  mkdir('test895');
  InOutRes:=0;
  {$I+}
  writeln('This is a test');
  {$I-}
  rmdir('test895');
  InOutRes:=0;
  {$I+}
  writeln('This is a test');
end;
{$pop}

{ Case tw1111.pp }
{$push}

begin
  if tw1111_v in [tw1111_sMin..tw1111_sMax] then ;
end;
{$pop}

{ Case tw15293a.pp }
{$push}

begin
  (*(*
*)*)
end;
{$pop}

{ Case tw17604.pp }
{$push}

begin
  if Length('') <> 0 then
    halt(1);
end;
{$pop}

{ Case tw2072.pp }
{$push}
(*$ifdef FPC*)
(*$else *)
(*$endif *)
begin
  writeln ('Hello ', tw2072_name);
end;
{$pop}

{ Case tw2289.pp }
{$push}
{$IFDEF NotDefined}
{$IFDEF Bogus}
{$ENDIF}
{$ENDIF}
begin

end;
{$pop}

{ Case tw2779.pp }
{$push}
{$IF DEFINED(asdf)}
{$IFEND}
begin
end;
{$pop}

{ Case tw2853.pp }
{$push}

begin
   WriteLn('abc');
{$ifdef LOOP}
   WriteLn('def');
{
  (* *)
}
   WriteLn('ghi');
{$endif LOOP}
   WriteLn('test');
end;
{$pop}

{ Case tw2853c.pp }
{$push}

begin
   WriteLn('abc');
{$ifdef LOOP}
   WriteLn('def');
{
  (* *)
}
   WriteLn('ghi');
{$endif LOOP}
   WriteLn('test');
end;
{$pop}

{ Case tw2853d.pp }
{$push}

begin
   WriteLn('abc');
{$ifdef LOOP}
   WriteLn('def');
{ {}
  {$endif, this endif should be ignored,
  as it is inside a comment}
  (* *)
}
   WriteLn('ghi');
{$endif LOOP}
   WriteLn('test');
end;
{$pop}

{ Case tw30654.pp }
{$push}
{$message info 'Test'}
begin
end;
{$pop}

{ Case tw3252.pp }
{$push}

begin
  tw3252_i := 0
; writeln ( tw3252_i )
end;
{$pop}

{ Case tw35965.pp }
{$push}

begin
  if TObject.UnitName <> 'System' then
    Halt(1);
end;
{$pop}

{ Case tw3764.pp }
{$push}

begin
  repeat
    break;
  until (true);
  while false do
    continue;
end;
{$pop}

{ Case tw3939.pp }
{$push}
{$warn symbol_platform on}
{$warnings-}
{$warn symbol_platform off}
{$warnings+}
begin
end;
{$pop}

{ Case tw40004.pp }
{$push}
{$overflowchecks on}
begin
	tw40004_n := 14 + random(0);
	tw40004_n := tw40004_n - tw40004_n mod 4;
	writeln(tw40004_n);
end;
{$pop}

{ Case tw4078.pp }
{$push}
{$ASSERTIONS ON}
begin
  tw4078_q := $80000000;
  tw4078_q := tw4078_q div 16;
  assert(tw4078_q = $8000000);
end;
{$pop}

{ Case tw41105.pp }
{$push}
{$WARN 5023 ON}
{$WARN 5023 OFF}
{$WARN 5023 +}
{$WARN 5023 -}
{$WARN 5023+}
{$WARN 5023-}
{$WARN 5023 ERROR}
{$WARN NO_RETVAL ON}
{$WARN NO_RETVAL OFF}
{$WARN NO_RETVAL +}
{$WARN NO_RETVAL -}
{$WARN NO_RETVAL+}
{$WARN NO_RETVAL-}
{$WARN NO_RETVAL ERROR}
begin
end;
{$pop}

{ Case tw41261.pp }
{$push}
{$R+}
begin
end;
{$pop}

{ Case tw6184.pp }
{$push}

begin
  writeln(exp(-200));
end;
{$pop}

end.
