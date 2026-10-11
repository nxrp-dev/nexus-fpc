{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Case tw0909.pp }
{$push}

 var tw0909_r:array[0..3] of real;

{$pop}

{ Case tw15308.pp }
{$push}




const
   tw15308_val_format: string = '0.0000E+000';

var
   tw15308_input: extended;


{$pop}

{ Case tw16188.pp }
{$push}


const
  tw16188_results: array[1..16] of string =
(
'234.6',
'234.57',
'234.568',
'1000',
'1235',
'1234.6',
'1234.57',
'1234.568',
'-234.6',
'-234.57',
'-234.568',
'-1000',
'-1235',
'-1234.6',
'-1234.57',
'-1234.568'
);

procedure tw16188_check(const s: string; index: longint);
begin
  if (s<>tw16188_results[index]) then
    begin
      writeln('Expected : ',tw16188_results[index]);
      writeln('Got      : ',s);
      halt(1);
    end;
end;

var tw16188_ext:extended;
  tw16188_str: shortstring;

{$pop}

{ Case tw23196.pp }
{$push}


var tw23196_b: extended;
    tw23196_s: string;

{$pop}

{ Case tw24131.pp }
{$push}

var
  tw24131_s: single;

{$pop}

{ Case tw3708.pp }
{$push}




var
  tw3708_i:Integer;
  tw3708_v: Double;
  tw3708_s: string;


{$pop}

{ Case tw4520.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4520 }
{ Submitted by "Martin Schreiber" on  2005-11-17 }
{ e-mail:  }

 { $mode objfpc}{$h+}

var
 tw4520_rea1,tw4520_rea2: real;
 tw4520_str1: string;

{$pop}

{ Case tw8434.pp }
{$push}


var
  tw8434_x: double;

{$pop}


{ Isolate changes to locale settings made by individual cases. }
var lOriginalFormatSettings: TFormatSettings;
begin
  lOriginalFormatSettings := DefaultFormatSettings;

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw0909.pp }
{$push}

begin
 tw0909_r[0]:=1; tw0909_r[1]:=2; tw0909_r[2]:=3; tw0909_r[3]:=4;
 // the following is supposed to print "1, 2, 3, 4", instead it prints "4, 4, 4, 4"
 writeln(format('%g, %g, %g, %g',[tw0909_r[0],tw0909_r[1],tw0909_r[2],tw0909_r[3]]));
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw15308.pp }
{$push}

begin
   decimalseparator:='.';
   tw15308_input:=1.05e2;
   if (formatfloat(tw15308_val_format,tw15308_input)<>'1.0500E+002') then
     begin
       writeln(formatfloat(tw15308_val_format,tw15308_input));
       halt(1);
     end;
   tw15308_input:=1.06e2;
   if (formatfloat(tw15308_val_format,tw15308_input)<>'1.0600E+002') then
     begin
       writeln(formatfloat(tw15308_val_format,tw15308_input));
       halt(2);
     end;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw16188.pp }
{$push}

begin
  DecimalSeparator:='.';
  tw16188_ext:=234.56789;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,1),1);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,5,1),2);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,6,7),3);
  tw16188_ext:=999.9999;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,7),4);
  tw16188_ext:=1234.56789;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,1),5);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,5,1),6);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,6,1),7);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,7,1),8);

  tw16188_ext:=-234.56789;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,1),9);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,5,1),10);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,6,7),11);
  tw16188_ext:=-999.9999;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,7),12);
  tw16188_ext:=-1234.56789;
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,4,1),13);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,5,1),14);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,6,1),15);
  tw16188_check(FloatToStrF(tw16188_ext,ffGeneral,7,1),16);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw23196.pp }
{$push}

begin
{$ifdef FPC_SUPPORTS_EXTENDED}
  tw23196_b := 999999999999999999;
  writeln(tw23196_b:25:25);
  str(tw23196_b:25:25,tw23196_s);
  if tw23196_s<>'999999999999999999.0000000000000000000000000' then
    halt(1);
  writeln(FloatToStrF(tw23196_b, ffFixed, 25, 0));
  if FloatToStrF(tw23196_b, ffFixed, 25, 0)<>'999999999999999999' then
    halt(2);
{$endif}
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw24131.pp }
{$push}

begin
  tw24131_s := 1.00999;
  FormatSettings.DecimalSeparator:='.';
  writeln(FloatToStrF(tw24131_s, ffGeneral, 8, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 7, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 6, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 5, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 4, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 3, 0, FormatSettings));
  writeln(FloatToStrF(tw24131_s, ffGeneral, 2, 0, FormatSettings));

  if FloatToStrF(tw24131_s, ffGeneral, 8, 0, FormatSettings)<>'1.00999' then
    halt(1);
  if FloatToStrF(tw24131_s, ffGeneral, 7, 0, FormatSettings)<>'1.00999' then
    halt(2);
  if FloatToStrF(tw24131_s, ffGeneral, 6, 0, FormatSettings)<>'1.00999' then
    halt(3);
  if FloatToStrF(tw24131_s, ffGeneral, 5, 0, FormatSettings)<>'1.01' then
    halt(4);
  if FloatToStrF(tw24131_s, ffGeneral, 4, 0, FormatSettings)<>'1.01' then
    halt(5);
  if FloatToStrF(tw24131_s, ffGeneral, 3, 0, FormatSettings)<>'1.01' then
    halt(6);
  if FloatToStrF(tw24131_s, ffGeneral, 2, 0, FormatSettings)<>'1' then
    halt(7);


end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw3708.pp }
{$push}

begin
  tw3708_v := 1.0000000000001;
  for tw3708_i := 1 to 13 do
    begin
      tw3708_s := FloatToStrF(tw3708_v, ffGeneral, tw3708_i, 0);
      WriteLn(tw3708_i, ' ', tw3708_s);
      if (tw3708_s <> '1') then
        begin
          writeln('error');
          halt(1);
        end;
    end;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw4520.pp }
{$push}
{$h+}
begin
 tw4520_rea1:= 1e100;
 tw4520_str1:= floattostr(tw4520_rea1);
 if tw4520_str1<>'1E100' then
   halt(1);
 writeln('1: ',tw4520_rea1);
 writeln('2: ',tw4520_str1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw8434.pp }
{$push}

begin
  DecimalSeparator:='.';
  tw8434_x := 0.099991;
  if (Format('%5.2f', [tw8434_x]) <> ' 0.10') then
    halt(1);
  if (Format('%6.3f', [tw8434_x]) <> ' 0.100') then
    halt(2);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
end.
