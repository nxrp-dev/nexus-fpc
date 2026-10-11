{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Every case starts with the process locale settings it had standalone. }
var lOriginalFormatSettings: TFormatSettings;

{ Case tb_floating_point_fpc_consolidated_02.pp }
{$push}
{ Consolidated floating point regressions; original case IDs and assertions are retained. }




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
var tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings: TFormatSettings;

{$pop}

{ Case tstrreal4.pp }
{$push}

{ test for issue #13722 by Zeljan Rikalo}


procedure tstrreal4_test;
var
 s: string;
 r: double;
 DS: Char;
begin
 DecimalSeparator := '.';
 DS := DecimalSeparator;
 r := 0.001;
 s := FloatToStrF(r, ffGeneral, 12, 2);
 {must print 0.001  }
 writeln(s);
 if (s <> '0'+DS+'001') then
   halt(1);

 s := FloatToStrF(r, ffFixed, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 s := FloatToStrF(r, ffNumber, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 r := -0.00001;

 s := FloatToStrF(r, ffGeneral, 12, 2);
 {must print -0.00001  }
 writeln(s);
 {$IFDEF FPC}
 if (s <> '-0'+DS+'00001') then
 {$ELSE}
 if (s <> '-1E-05') then // is this DCC bug ?
 {$ENDIF}
   halt(1);

 s := FloatToStrF(r, ffExponent, 12, 2);
 {must print -1.00000000000E-05  }
 writeln(s);
 if (s <> '-1'+DS+'00000000000E-05') then
   halt(1);

 s := FloatToStrF(r, ffFixed, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 s := FloatToStrF(r, ffNumber, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 s := FloatToStrF(r, ffCurrency, 12, 2);
 {must print without leading zero  }
 writeln(s);
 if (length(s) > 0) and
  ((Pos('-', s) > 0) or ((Pos('(', s) > 0) and  (Pos(')', s) > 0))) then
   halt(1);

 r := -0.00000;

 s := FloatToStrF(r, ffGeneral, 12, 2);
 {must print 0  }
 writeln(s);
 if (s <> '0') then
   halt(1);

 s := FloatToStrF(r, ffExponent, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00000000000E+00') then
   halt(1);

 s := FloatToStrF(r, ffFixed, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 s := FloatToStrF(r, ffNumber, 12, 2);
 {must print 0.00  }
 writeln(s);
 if (s <> '0'+DS+'00') then
   halt(1);

 s := FloatToStrF(r, ffCurrency, 12, 2);
 {must print without leading zero  }
 writeln(s);
 if (length(s) > 0) and
  ((Pos('-', s) > 0) or ((Pos('(', s) > 0) and  (Pos(')', s) > 0))) then
   halt(1);

 // Now check if we remove leading negative sign by mistake
 r := -0.00001;

 s := FloatToStrF(r, ffGeneral, 12, 5);
 {must print -0.00001  }
 writeln(s);
 {$IFDEF FPC}
 if (s <> '-0'+DS+'00001') then
 {$ELSE}
 if (s <> '-1E-5') then // is this DCC bug ?
 {$ENDIF}
   halt(1);

 s := FloatToStrF(r, ffExponent, 12, 5);
 {must print -0.00001  }
 writeln(s);
 {$IFDEF FPC}
 if (s <> '-1'+DS+'00000000000E-0005') then
 {$ELSE}
 if (s <> '-1.00000000000E-5') then
 {$ENDIF}
   halt(1);

 s := FloatToStrF(r, ffFixed, 12, 5);
 {must print 0.00  }
 writeln(s);
 if (s <> '-0'+DS+'00001') then
   halt(1);

 s := FloatToStrF(r, ffNumber, 12, 5);
 {must print 0.00  }
 writeln(s);
 if (s <> '-0'+DS+'00001') then
   halt(1);

 s := FloatToStrF(r, ffCurrency, 12, 5);

 {here we check for various currency negative formats.
 There's bug in rtl cause NegCurFormat can be > 10
 and in that case it isn't handled by FloatToStrIntl().
 So that's why we check NegCurFormat range here.}

 writeln(s);

 if (length(s) > 0) and (NegCurrFormat in [0..10]) and
   (Pos('-', s) = 0) and (Pos('(', s) = 0) and  (Pos(')', s) = 0) then
   halt(1);
 writeln('Tests for FloatToStrF(): SUCCESS');
end;


{$pop}

{ Case tstrreal5.pp }
{$push}

{ test for NegCurFormat values  by Zeljan Rikalo
  valid values are at:
  http://msdn.microsoft.com/en-us/library/dd373791%28VS.85%29.aspx
 }


procedure tstrreal5_test;
const
  MaxNegCurFormats = 15;
var
  s: string;
  r: double;
  i: integer;
begin
  DecimalSeparator := '.';
  r := -1.1;
  writeln('NegCurrFormat test pass 1 ...');
  for i := 0 to MaxNegCurFormats do
  begin
    NegCurrFormat := i;
    s := FloatToStrF(r, ffCurrency, 12, 1);
    writeln('NegCurrFormat: ',i,' value: ',s);
    case i of
      0,4,14,15:
        if (Pos('(', s) = 0) and (Pos(')', s) = 0) then
          halt(1);
      else
      if Pos('-', s) = 0 then
        halt(1);
    end;
  end;

  r := -0.001;
  writeln('NegCurrFormat test pass 2 ...');
  for i := 0 to MaxNegCurFormats do
  begin
    NegCurrFormat := i;
    s := FloatToStrF(r, ffCurrency, 12, 4);
    writeln('NegCurrFormat: ',i,' value: ',s);
    case i of
      0,4,14,15:
        if (Pos('(', s) = 0) and (Pos(')', s) = 0) then
          halt(1);
      else
      if Pos('-', s) = 0 then
        halt(1);
    end;
  end;

  writeln('Tests for NegCurrFormat: SUCCESS');
end;


{$pop}

{ Case tastrcmp1.pp }
{$push}



var
  tastrcmp1_error : boolean;

procedure tastrcmp1_check(ok : boolean; func : string; value : longint);
begin
  if not ok then
  begin
    tastrcmp1_error:=true;
    writeln(func,' failed, result = ',value);
  end;
end;

var
  tastrcmp1_a, tastrcmp1_b: array[0..1] of char;
  tastrcmp1_tmp : longint;

{$pop}

{ Case tw37374.pp }
{$push}




var
  tw37374_fails: Integer = 0;
  tw37374_testCount: Integer = 0;

  procedure tw37374_Test(AFormat: String; AValue: Double; AResult: String);
  var
    s: String;
  begin
    s := FormatFloat(AFormat, AValue);
    if s <> AResult then
    begin
      WriteLn('Format(' + AFormat + ', ', AValue:0:6, ') --> ', s, '; SHOULD BE: ', AResult);
      inc(tw37374_fails);
    end;
    inc(tw37374_testCount);
  end;

const
  tw37374_VALUES: array[0..4] of Double = (0, 0.00001234, 0.123456, 1.23456, 1123.4567);
var
  tw37374_fmt: String;


{$pop}

begin
  lOriginalFormatSettings := DefaultFormatSettings;
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tb_floating_point_fpc_consolidated_02.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$h+}
{$pop}
{$push}
{$pop}
begin
  tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings := DefaultFormatSettings;

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
{ Case tw0909.pp }
{$push}

begin
 tw0909_r[0]:=1; tw0909_r[1]:=2; tw0909_r[2]:=3; tw0909_r[3]:=4;
 // the following is supposed to print "1, 2, 3, 4", instead it prints "4, 4, 4, 4"
 writeln(format('%g, %g, %g, %g',[tw0909_r[0],tw0909_r[1],tw0909_r[2],tw0909_r[3]]));
end;
{$pop}

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
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

  DefaultFormatSettings := tb_floating_point_fpc_consolidated_02_lOriginalFormatSettings;
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tstrreal4.pp }
{$push}
{$IFDEF FPC}
{$ELSE}
{$ENDIF}
{$IFDEF FPC}
{$ELSE}
{$ENDIF}
{$IFDEF FPC}
{$ELSE}
{$ENDIF}
begin
  tstrreal4_test;
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tstrreal5.pp }
{$push}

begin
  tstrreal5_test;
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tastrcmp1.pp }
{$push}

begin
  tastrcmp1_error:=false;
  tastrcmp1_a[0] := #0; tastrcmp1_a[1] := #1;      //Empty string
  tastrcmp1_b[0] := #0; tastrcmp1_b[1] := #0;      //Empty string with different char after end
  tastrcmp1_tmp:=AnsiStrComp(tastrcmp1_a, tastrcmp1_b);      //should be zero because a=b
  tastrcmp1_check(tastrcmp1_tmp=0,'AnsiStrComp',tastrcmp1_tmp);
  tastrcmp1_tmp:=AnsiStrIComp(tastrcmp1_a, tastrcmp1_b);     //should be zero because a=b
  tastrcmp1_check(tastrcmp1_tmp=0,'AnsiStrIComp',tastrcmp1_tmp);
  if tastrcmp1_error then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw37374.pp }
{$push}

begin
  DefaultFormatSettings.DecimalSeparator := '.';
  DefaultFormatSettings.ThousandSeparator := ',';

  tw37374_fmt := '0.00';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.46');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.12');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.46');

  tw37374_fmt := '.00';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '.12');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.46');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-.00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-.12');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.46');

  tw37374_fmt := '0.00000###';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00000');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00001234');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.123456');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23456');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.45670');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.00001234');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.123456');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23456');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.45670');

  tw37374_fmt := '000';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '000');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '000');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '000');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '001');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-000');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-000');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-001');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123');

  tw37374_fmt := '0.00E+00';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '1.23E-05');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '1.23E-01');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1.12E+03');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-1.23E-05');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-1.23E-01');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23E+00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1.12E+03');

  tw37374_fmt := '0.00E-00';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00E00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '1.23E-05');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '1.23E-01');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23E00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1.12E03');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-1.23E-05');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-1.23E-01');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23E00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1.12E03');

  tw37374_fmt := '0.00 EUR';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.46 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.00 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.12 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.46 EUR');

  tw37374_fmt := '0.00 "EUR"';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.46 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.00 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.12 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.46 EUR');

  tw37374_fmt := '0.00"E+00"';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.00E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23E+00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1123.46E+00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.00E+00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.12E+00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.23E+00');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1123.46E+00');

  tw37374_fmt := '#,##0.0';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.0');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.0');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.1');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.2');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1,123.5');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.0');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.1');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.2');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1,123.5');

  tw37374_fmt := ',0.0';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '0.0');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.0');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.1');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.2');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1,123.5');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '-0.0');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '-0.1');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '-1.2');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '-1,123.5');

  tw37374_fmt := '#,##0.00;(#,##0.00);zero';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], 'zero');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1,123.46');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '(0.00)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '(0.12)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '(1.23)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '(1,123.46)');

  tw37374_fmt := '#,##0.00 EUR;(#,##0.00 EUR);zero';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], 'zero');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], '0.00 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], '0.12 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], '1.23 EUR');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], '1,123.46 EUR');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '(0.00 EUR)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '(0.12 EUR)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '(1.23 EUR)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '(1,123.46 EUR)');

  tw37374_fmt := 'EUR #,##0.00;(EUR #,##0.00);-';
  tw37374_Test(tw37374_fmt, tw37374_VALUES[0], '-');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[1], 'EUR 0.00');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[2], 'EUR 0.12');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[3], 'EUR 1.23');
  tw37374_Test(tw37374_fmt, tw37374_VALUES[4], 'EUR 1,123.46');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[1], '(EUR 0.00)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[2], '(EUR 0.12)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[3], '(EUR 1.23)');
  tw37374_Test(tw37374_fmt, -tw37374_VALUES[4], '(EUR 1,123.46)');

  WriteLn(tw37374_testCount, ' tests executed.');
  if tw37374_fails = 0 then
    WriteLn('All tests passed.')
  else
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

end.
