{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw10013.pp }
{$push}


 {$H+} {$R+}



var
  tw10013_ws: WideString;
  //wc: WideChar;
  tw10013_i: Integer;


{$pop}

{ Case tw13456.pp }
{$push}

{$ifdef fpc}
{$H+}
{$endif}

var
	tw13456_s: string;
	tw13456_s1: string[3];

{$pop}

{ Case tw33875.pp }
{$push}






procedure tw33875_Foo(const aArg: UnicodeString); overload;
begin
  WriteLn('WideString: ', aArg);
end;

procedure tw33875_Foo(c: WideChar); overload;
begin
  WriteLn('Char: ', c);
end;


{$pop}

{ Case tw3443.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3443 }
{ Submitted by "Alexey Barkovoy" on  2004-12-08 }
{ e-mail: clootie@ixbt.com }





procedure tw3443_Test1(c: PChar; w: PWideChar);
begin
  if c <> Pointer(w) then Exit; // Do something
end;


{$pop}

{ Case tw38390.pp }
{$push}




var
  tw38390_s: String;
  tw38390_x: UInt64;


{$pop}

{ Case tw39664.pp }
{$push}






var
  tw39664_i8: Int8;
  tw39664_i16: Int16;
  tw39664_i32: Int32;
  tw39664_u32: UInt32;
  tw39664_s: String;


{$pop}

{ Case tw9126.pp }
{$push}
{$ifdef fpc}

{$endif}



var
  tw9126_failed : boolean;

procedure tw9126_testconvert(s : string; shouldsucceed: boolean);
var
  succeeded: boolean;
begin
  succeeded:=true;
  try
    writeln(strtofloat(s));
  except
    on EConvertError do begin
      writeln('Failed to convert ', s, ' to a float value');
      succeeded := false;
    end;
  end;
  tw9126_failed:=tw9126_failed or (succeeded<>shouldsucceed);
end;


{$pop}


{ Isolate changes to locale settings made by individual cases. }
var lOriginalFormatSettings: TFormatSettings;
begin
  lOriginalFormatSettings := DefaultFormatSettings;

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw10013.pp }
{$push}

{$H+}
{$R+}
begin
  tw10013_ws := UTF8Decode('something');

  WriteLn;
  WriteLn('str: "', UTF8Encode(tw10013_ws), '"');
  WriteLn('len (must be 9) : ', Length(tw10013_ws));
  WriteLn;

  for tw10013_i := 1 to Length(tw10013_ws) * 2 + 1 do
  begin

    Write('Try to access ws[', tw10013_i, ']');

    try

      tw10013_ws[tw10013_i] := tw10013_ws[tw10013_i];
      //wc := ws[i];
      //ws[i] := wc;

      if tw10013_i > Length(tw10013_ws) then
        begin
          writeln(' FAULT');
          halt(1);
        end
      else
        WriteLn(' OK');

    except

      on e : Exception do
      begin
        if (e is ERangeError) and (tw10013_i > Length(tw10013_ws)) then
          WriteLn(' OK (got a range-check error as expected)');
      end;

    end;

  end;
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw13456.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
	tw13456_s1:='255';
	tw13456_s:='This is a big long string. This is going to be '+
		'A really big long string. The idea is it needs '+
		'to be over '+tw13456_s1+' characters to see if FPC can '+
		'handle it. I have a program that isn''t '+
		'building because of the '+tw13456_s1+' character string '+
		'limit. I can''t imagine why I''ve run into '+
		'this now. It should be wokring just dandy. '+
		'But for some reason it wasn''t so I thought a '+
		'test program outside of the project I was '+
		'working on may be beneficial to analysis.';

       if (length(tw13456_s)<=255) then
         halt(1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw33875.pp }
{$push}

begin
  tw33875_Foo('abc');
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw3443.pp }
{$push}

begin
  tw3443_Test1(nil, nil);
  tw3443_Test1('SS', 'WW');
  tw3443_Test1(PChar('a'+'b'), PWideChar('a' + 'b')); //  Delphi can't compile this
  tw3443_Test1(@((AnsiString('xxx ' + IntToStr(1) + #10))[1]),
        @((WideString('xxx ' + IntToStr(1) + #10))[1])); // FPC: "Error: Variable identifier expected"
// Delphi CAN compile line above
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw38390.pp }
{$push}

begin
  tw38390_s := '20000000000';
  tw38390_x := UInt64.Parse(tw38390_s);
  WriteLn(tw38390_x);
  if tw38390_x <> 20000000000 then
    Halt(1);
  UInt64.TryParse(tw38390_s, tw38390_x);
  WriteLn(tw38390_x);
  if tw38390_x <> 20000000000 then
    Halt(2);
  tw38390_x := StrToQWord(tw38390_s);
  WriteLn(tw38390_x);
  if tw38390_x <> 20000000000 then
    Halt(3);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw39664.pp }
{$push}

begin
  tw39664_i8 := -42;
  tw39664_s := IntToHex(tw39664_i8);
  writeln(tw39664_s);
  if tw39664_s <> 'D6' then halt(1);

  tw39664_i16 := -42;
  tw39664_s := IntToHex(tw39664_i16);
  writeln(tw39664_s);
  if tw39664_s <> 'FFD6' then halt(2);

  tw39664_i32 := -42;
  tw39664_s := IntToHex(tw39664_i32);
  writeln(tw39664_s);
  if tw39664_s <> 'FFFFFFD6' then halt(3);

  tw39664_s := tw39664_i8.ToHexString;
  writeln(tw39664_s);
  if tw39664_s <> 'D6' then halt(4);

  tw39664_s := tw39664_i16.ToHexString;
  writeln(tw39664_s);
  if tw39664_s <> 'FFD6' then halt(5);

  tw39664_s := tw39664_i32.ToHexString;
  writeln(tw39664_s);
  if tw39664_s <> 'FFFFFFD6' then halt(6);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
{ Case tw9126.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw9126_failed := false;

  thousandseparator := '.';
  decimalseparator := ',';

  tw9126_testconvert('1.200',false); // fails
  tw9126_testconvert('1,200',true); // working
  tw9126_testconvert('1.200,23',false); // fails
  tw9126_testconvert('1.200.300',false); // fails

  if (tw9126_failed) then halt(1);
end;
{$pop}

  DefaultFormatSettings := lOriginalFormatSettings;
end.
