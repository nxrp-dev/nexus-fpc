{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tw10753.pas }
{$push}
{$H+}


var
  tw10753_err : boolean;

procedure tw10753_p;
 var
  AStr,AText: string;
   AValue: int64;
 begin
   //This goes wrong, notice the AStr input and output
   AValue:=1234567890;
   AStr := Format('%0.n',[double(1.0)*AValue]); //1.234.567.890
   AStr := Format('<font color="#ff0000">%s</font>',[AStr]);
   Writeln('Wrong:' +AStr); //Wrong: <font color="#ff0000"></font>????
   if AStr<>'<font color="#ff0000">1,234,567,890</font>' then
     tw10753_err:=true;
   //This is Ok, notice the changed output AText
   AValue:=2134567890;
   AStr := Format('%0.n',[double(1.0)*AValue]); //2.134.567.890
   AText := Format('<font color="#ff0000">%s</font>',[AStr]);
   Writeln('Ok:' +AText); //Ok 2.134.567.890
   if Atext<>'<font color="#ff0000">2,134,567,890</font>' then
     tw10753_err:=true;
end;


{$pop}

{ Case tw12385.pas }
{$push}
{$ifdef fpc}

{$endif}




var
  tw12385_s: string;
  tw12385_cr: Extended;

Procedure tw12385_TestIt(tw12385_CR : Extended; Fmt,Expected : String);

begin
  tw12385_S:=FormatFloat(Fmt,tw12385_cr);
  If tw12385_S<>Expected then
    begin
    Writeln('"',tw12385_S,'"<>"',Expected,'" (latter is correct)');
    Halt(1);
    end;
end;


{$pop}

{ Case tw13076.pas }
{$push}
{$ifdef fpc}

{$endif}




var
  tw13076_s: string;
  tw13076_cr: Extended;

Procedure tw13076_TestIt(tw13076_CR : Extended; Fmt,Expected : String);

begin
  tw13076_S:=FormatFloat(Fmt,tw13076_cr);
  If tw13076_S<>Expected then
    begin
    Writeln('"',tw13076_S,'"<>"',Expected,'" (latter is correct)');
    Halt(1);
    end;
end;


{$pop}

{ Case tw13307.pas }
{$push}


{$IFDEF FPC}
{$H+}
{$ENDIF}




var tw13307_S: String;
    tw13307_E: Extended;
    tw13307_B: Boolean;
    tw13307_Code: Integer;

{$pop}

{ Case tw14143.pas }
{$push}

{$ifdef fpc}{$h+}{$endif}



var
  tw14143_frec: TFloatRec;
  tw14143_code: Integer;

const
  tw14143_posinf: Extended = 1.0/0.0;
  tw14143_neginf: Extended = -1.0/0.0;
  tw14143_nan: Extended = 0.0/0.0;


{$pop}

{ Case tw17413.pas }
{$push}

{$H+}



type
  tw17413_TVector3Single = array [0..2] of Single;

function tw17413_Vector3Single(const X, Y, Z: Single): tw17413_TVector3Single;
begin
  Result[0] := X;
  Result[1] := Y;
  Result[2] := Z;
end;

var
  tw17413_res1, tw17413_res2, tw17413_res3: single;

procedure tw17413_RenderFromViewEverything;
var
  Normal: tw17413_TVector3Single;

  procedure DoTexCoordVertex(const Vertex: tw17413_TVector3Single);
  begin
    Writeln('Normal: ', Normal[0]:1:1, ' ', Normal[1]:1:1, ' ', Normal[2]:1:1);
    if (normal[0]<>tw17413_res1) or
       (normal[1]<>tw17413_res2) or
       (normal[2]<>tw17413_res3) then
      halt(1);
  end;

begin
  tw17413_res1:=123;
  tw17413_res2:=456;
  tw17413_res3:=789;
  Normal := tw17413_Vector3Single(123, 456,  789);
  DoTexCoordVertex(tw17413_Vector3Single(111, 222,  333));

  tw17413_res1:=987;
  tw17413_res2:=654;
  tw17413_res3:=321;
  Normal := tw17413_Vector3Single(987, 654, 321);
  DoTexCoordVertex(tw17413_Vector3Single(444, 555, 666));
end;


{$pop}

{ Case tw1917.pas }
{$push}




var
  tw1917_x,tw1917_y,tw1917_z : real;


{$pop}

{ Case tw2214.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2214 }
{ Submitted by "Marco" on  2002-11-01 }
{ e-mail: marco@freepascal.org }





function tw2214_LongLatToDMS(longlat : longint; hemis : string):string;
Var ldeg, lmin, lsec, lmsec : extended;
    hemi                    : char;
begin
  ldeg:=1;
  lmin:=2;
  lsec:=3;
  lmsec:=4;
  hemi:='n';
  result := Format('%d %02d %02d.%03d',
               [round(ldeg), round(lmin), round(lsec),
                round(lmsec)]) + ' ' + hemi;
end;


{$pop}

{ Case tw38202.pas }
{$push}


{$H+}



var
  tw38202_D: Double;
  tw38202_Q: QWord;


{$pop}

{ Case tw38631.pas }
{$push}




var
  tw38631_D: TDateTime;
  tw38631_T, tw38631_T1, tw38631_T2: TTimeStamp;
  tw38631_MS: Comp;

{$pop}

{ Case tw40305.pas }
{$push}






var
  tw40305_r: Real;
  tw40305_s: String;

{$pop}

{ Case tw9384.pas }
{$push}

{$H+}

var
  tw9384_ef : Extended;

{$pop}


{ Isolate changes to locale settings made by individual cases. }
var lOriginalFormatSettings: TFormatSettings;
begin
  lOriginalFormatSettings := DefaultFormatSettings;

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw10753.pas }
{$push}

{$H+}
begin
  ThousandSeparator:=',';
  tw10753_p;
  if tw10753_err then
    halt(1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw12385.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  DecimalSeparator:='.';
  ThousandSeparator:=',';
  tw12385_TestIt(1234.567,'00000000.00','00001234.57');
  tw12385_TestIt(-1234.567,'00000000.00','-00001234.57');
  tw12385_TestIt(-1234.567,'000.00','-1234.57');
  tw12385_TestIt(-1,'000.000','-001.000');
  tw12385_TestIt(-80,'#,##0.00','-80.00');
  tw12385_TestIt(-140,'#,##0.00','-140.00');
  tw12385_TestIt(140,'#,##0.00','140.00');
  tw12385_TestIt(80,'#,##0.00','80.00');
  tw12385_TestIt(-2.45,'#,##0.00','-2.45');
  tw12385_TestIt(-1400,'#,##0.00','-1,400.00');
  tw12385_TestIt(-1400,'##,##0.00','-1,400.00');
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw13076.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  DecimalSeparator:='.';
  ThousandSeparator:=',';
  tw13076_TestIt(-10,'###,###,##0.00','-10.00');
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw13307.pas }
{$push}
{$IFDEF FPC}

{$H+}
{$ENDIF}
begin
  DecimalSeparator := '.';
  ThousandSeparator := ',';
  writeln('DecimalSeparator  = ',DecimalSeparator);
  writeln('ThousandSeparator = ',ThousandSeparator);
  tw13307_E := -1.0;
  tw13307_S := '123.456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_S := '123,456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));



  DecimalSeparator := ',';
  ThousandSeparator := '.';
  writeln('DecimalSeparator  = ',DecimalSeparator);
  writeln('ThousandSeparator = ',ThousandSeparator);
  tw13307_E := -1.0;
  tw13307_S := '123.456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_S := '123,456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;

  DecimalSeparator := ',';
  ThousandSeparator := ',';
  writeln('DecimalSeparator  = ',DecimalSeparator);
  writeln('ThousandSeparator = ',ThousandSeparator);
  tw13307_E := -1.0;
  tw13307_S := '123.456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(12 "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_S := '123,456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;

  DecimalSeparator := '.';
  ThousandSeparator := '.';
  writeln('DecimalSeparator  = ',DecimalSeparator);
  writeln('ThousandSeparator = ',ThousandSeparator);
  tw13307_E := -1.0;
  tw13307_S := '123.456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]))
  else
    begin
      writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));
      halt(1);
    end;
  tw13307_S := '123,456';
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, fvExtended, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(1) "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(1) "%s" -> Conversion Error',[tw13307_S]));
  tw13307_B := TextToFloat(PChar(tw13307_S), tw13307_E, DefaultFormatSettings);
  if tw13307_B then
    begin
      writeln(Format('(2) "%s" -> %.3f',[tw13307_S,tw13307_E]));
      halt(1);
    end
  else writeln(Format('(2) "%s" -> Conversion Error',[tw13307_S]));


end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw14143.pas }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
begin
  tw14143_code := 0;
  FloatToDecimal(tw14143_frec, tw14143_posinf, fvExtended, 15, 15);
  if (tw14143_frec.Exponent <> 32767) or tw14143_frec.Negative or (tw14143_frec.Digits[0] <> #0) then
  begin
    writeln('Positive infinity test failed');
    tw14143_code := tw14143_code or 1;
  end;

  FloatToDecimal(tw14143_frec, tw14143_neginf, fvExtended, 15, 15);
  if (tw14143_frec.Exponent <> 32767) or (not tw14143_frec.Negative) or (tw14143_frec.Digits[0] <> #0) then
  begin
    writeln('Negative infinity test failed');
    tw14143_code := tw14143_code or 2;
  end;

  FloatToDecimal(tw14143_frec, tw14143_nan, fvExtended, 15, 15);
  if (tw14143_frec.Exponent <> -32768) or (tw14143_frec.Digits[0] <> #0) then
  begin
    writeln('NaN test failed');
    tw14143_code := tw14143_code or 4;
  end;
  CheckCaseExitCode(tw14143_Code);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw17413.pas }
{$push}

{$H+}
begin
  tw17413_RenderFromViewEverything;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw1917.pas }
{$push}

begin
  tw1917_x:=5.75;
  tw1917_y:=5.75;
  tw1917_z:=6;
  try
    tw1917_z:=tw1917_z/ln(tw1917_x/tw1917_y);
    WriteLn('Error! No runtime error detected');
    Writeln('z = ',tw1917_z);
  except
     on e : exception do
       begin
         Writeln('Correct, found error: ',e.message);
       end;
  end;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw2214.pas }
{$push}

begin
   if tw2214_LongLatToDMS(1,'a')<>'1  2  3.  4 n' then
     begin
       writeln('Problem with format');
       halt(1);
     end;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw38202.pas }
{$push}

{$H+}
begin
  tw38202_D := -1;

  tw38202_Q := tw38202_D.Frac;
  tw38202_D.Frac := tw38202_Q; // the sign is lost!

  if tw38202_D<>-1 then
    halt(1);
  WriteLn('ok');
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw38631.pas }
{$push}

begin
  tw38631_D:=EncodeDate(2021, 03, 16) + EncodeTime(14, 02, 15, 1);
  WriteLn('DATE: ', DateTimeToStr(tw38631_D));

  tw38631_T:=DateTimeToTimeStamp(tw38631_D);
  WriteLn(' T.Date=',tw38631_T.Date,'   T.Time=', tw38631_T.Time);
  tw38631_MS:=TimeStampToMSecs(tw38631_T);
  tw38631_T1:=MSecsToTimeStamp(tw38631_MS);
  WriteLn('T1.Date=',tw38631_T1.Date,'  T1.Time=', tw38631_T1.Time);

  WriteLn('DATE1: ', DateTimeToStr(TimeStampToDateTime(tw38631_T1)));
  if TimeStampToDateTime(tw38631_T1)<>tw38631_D then
    halt(1);
  writeln('ok')
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw40305.pas }
{$push}

begin
  tw40305_r := 2.42;
  FormatSettings.DecimalSeparator:='.';
  tw40305_s := tw40305_r.ToString;
  if tw40305_s <> '2.42' then
    Halt(1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw9384.pas }
{$push}

{$H+}
begin
  tw9384_ef := 12;
  if (FormatFloat('#.#######E-0',tw9384_ef) <> '1'+DecimalSeparator+'2E1') then
    halt(1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
end.
