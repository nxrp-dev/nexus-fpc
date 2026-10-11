{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes,sysutils;

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tb0515.pp }
{$push}
{$h+}



const
  tb0515_count = 64;
  tb0515_factor = 15;

function tb0515_ptrtopaddedstr(x: pointer): string;
begin
  result := format('%02p', [x]);
end;

procedure tb0515_fatalerror(str: string; index: integer);
begin
  writeln(str, index);
  halt(1);
end;

var
  tb0515_i, tb0515_j: ptrint;
  tb0515_strlist: tstringlist;

{$pop}

{ Case tw16848.pp }
{$push}
{$ifdef fpc}
{$H+}
{$endif}


var
  tw16848_B: Boolean;
  tw16848_S: String;

{$pop}

{ Case tw25289.pp }
{$push}
{$H+}



var
  tw25289_code: integer;

function tw25289_bitstostring(b: TBits): string;
var
  i: integer;
  bs: string;
begin
  bs:= '';
  for i:= 0 to b.Size - 1 do
    if b[i] then
      bs:= bs + '1'
    else
      bs:= bs + '0';
  Result:= bs;
end;

procedure tw25289_Test;
var
  i, bsize1, bsize2: integer;
  b1, b2, b3: TBits;
begin
  tw25289_code := 0;
  // OR
  bsize1:= 16;
  bsize2:= 164;
  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    b1[i]:= True;

  b2.OrBits(b1);
  b3.OrBits(b1);
  for i:= b1.Size to bsize2 - 1 do
    b3[i]:= False;
  if not b2.Equals(b3) then
  begin
    WriteLn('OR');
    writeln(tw25289_bitstostring(b1));
    writeln(tw25289_bitstostring(b2));
    writeln(tw25289_bitstostring(b3));
    tw25289_code := tw25289_code or 1;
  end;
  b1.Free;
  b2.Free;
  b3.Free;

  // XOR
  bsize1:= 16;
  bsize2:= 164;
  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    b1[i]:= True;

  b2.XOrBits(b1);
  b3.XOrBits(b1);
  for i:= b1.Size to bsize2 - 1 do
    b3[i]:= False;
  if not b2.Equals(b3) then
  begin
    WriteLn('XOR');
    writeln(tw25289_bitstostring(b1));
    writeln(tw25289_bitstostring(b2));
    writeln(tw25289_bitstostring(b3));
    tw25289_code := tw25289_code or 2;
  end;
  b1.Free;
  b2.Free;
  b3.Free;

  // AND
  bsize1:= 16;
  bsize2:= 164;
  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    b1[i]:= True;

  b2.AndBits(b1);
  b3.AndBits(b1);
  for i:= b1.Size to bsize2 - 1 do
    b3[i]:= False;
  if not b2.Equals(b3) then
  begin
    WriteLn('AND');
    writeln(tw25289_bitstostring(b1));
    writeln(tw25289_bitstostring(b2));
    writeln(tw25289_bitstostring(b3));
    tw25289_code := tw25289_code or 4;
  end;
  b1.Free;
  b2.Free;
  b3.Free;
end;


{$pop}

{ Case tw2899.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2899 }
{ Submitted by "Mattias Gaertner" on  2004-01-17 }
{ e-mail: mattias@freepascal.org }


{$ifdef fpc}{$H+}{$endif}



procedure tw2899_DoSomething(const AString: string);

  procedure NestedProc(var Dummy: string);
  begin
    Dummy:=Dummy; // dummy statement, no change
  end;

var
  s: String;
begin
  s:=copy(AString,5,11);
  writeln('Before NestedProc: "',s,'"');
  NestedProc(s);
  writeln('After NestedProc: "',s,'"'); // s is now empty
  if s<>'AStrangeBug' then
    halt(1);
end;


{$pop}

{ Case tw29244.pp }
{$push}


{$H+}



Var
  tw29244_AStr : String = '';

{$pop}

{ Case tw33706.pp }
{$push}
{$H+}



var
  tw33706_code: integer;

function tw33706_bitstostring(b: TBits): string;
var
  i: integer;
  bs: string;
begin
  bs:= '';
  for i:= 0 to b.Size - 1 do
    if b[i] then
      bs:= bs + '1'
    else
      bs:= bs + '0';
  Result:= bs;
end;

procedure tw33706_Test;
var
  i, bsize1, bsize2: integer;
  b1, b2, b3: TBits;
begin
  tw33706_code := 0;
  // XOR
  bsize1:= 16;
  bsize2:= 164;
  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    begin
      b1[i]:= True;
      b2[i]:= True;
    end;

  b2.NotBits(b1);
  if not b2.Equals(b3) then
  begin
    WriteLn('Not');
    writeln(tw33706_bitstostring(b1));
    writeln(tw33706_bitstostring(b2));
    writeln(tw33706_bitstostring(b3));
    tw33706_code := tw33706_code or 1;
  end;
  b1.Free;
  b2.Free;
  b3.Free;

  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    begin
      b1[i]:= True;
      b3[i]:= True;
    end;

  b2.NotBits(b1);
  if not b2.Equals(b3) then
  begin
    WriteLn('Not');
    writeln(tw33706_bitstostring(b1));
    writeln(tw33706_bitstostring(b2));
    writeln(tw33706_bitstostring(b3));
    tw33706_code := tw33706_code or 2;
  end;
  b1.Free;
  b2.Free;
  b3.Free;

  b1:= TBits.Create;
  b2:= TBits.Create(bsize2);
  b3:= TBits.Create(bsize2);
  for i:= 0 to bsize1 - 1 do
    begin
      b2[i]:= True;
      b3[i]:= True;
    end;

  b2.NotBits(b1);
  if not b2.Equals(b3) then
  begin
    WriteLn('Not');
    writeln(tw33706_bitstostring(b1));
    writeln(tw33706_bitstostring(b2));
    writeln(tw33706_bitstostring(b3));
    tw33706_code := tw33706_code or 4;
  end;
  b1.Free;
  b2.Free;
  b3.Free;
end;


{$pop}

{ Case tw4199.pp }
{$push}
{$ifdef fpc}
{$H+}
{$endif}

const
 tw4199_stringconst = 'abc';
 tw4199_widestringconst = widestring('abc');
var
 tw4199_str1,tw4199_str2 : widestring;

{$pop}

{ Case tw4489.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4489 }
{ Submitted by "Vincent Snijders" on  2005-11-04 }
{ e-mail: vsnijders@quicknet.nl }


{$H+}



var
  tw4489_s: string;
  tw4489_u: SizeUInt;
  tw4489_d: qword;


{$pop}

{ Case tw4632.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4632 }
{ Submitted by "Graeme Geldenhuys" on  2005-12-23 }
{ e-mail: graemeg@gmail.com }


{$H+}



var
  tw4632_err : boolean;

procedure tw4632_Error(const tw4632_s:string);
begin
  writeln(tw4632_s);
  tw4632_err:=true;
end;

{ Fixed version of ExtractFileName function }
function tw4632_lExtractFileName(const FileName: string): string;
var
  tw4632_i: longint;
begin
  tw4632_I := LastDelimiter(PathDelim + DriveDelim, FileName);
  Result := Copy(FileName, tw4632_I + 1, MaxInt);
end;

var
  tw4632_name, tw4632_s: string;
  tw4632_i: integer;

const
  tw4632_ext = '.txt';


{$pop}

begin

{ Case tb0515.pp }
{$push}

{$h+}
begin
  tb0515_strlist := tstringlist.create;
  for tb0515_i := 0 to tb0515_count-1 do
  begin
    tb0515_j := tb0515_factor*tb0515_i mod tb0515_count;
    tb0515_strlist.addobject(tb0515_ptrtopaddedstr(pointer(tb0515_j)), tobject(tb0515_j));
  end;
  for tb0515_i := 0 to tb0515_count-1 do
  begin
    tb0515_j := tb0515_factor*tb0515_i mod tb0515_count;
    if tb0515_strlist.strings[tb0515_i] <> tb0515_ptrtopaddedstr(pointer(tb0515_j)) then
      tb0515_fatalerror('string error at ', tb0515_i);
    if tb0515_strlist.objects[tb0515_i] <> tobject(tb0515_j) then
      tb0515_fatalerror('object error at ', tb0515_i);
  end;
  tb0515_strlist.sort;
  for tb0515_i := 0 to tb0515_count-1 do
  begin
    if tb0515_strlist.strings[tb0515_i] <> tb0515_ptrtopaddedstr(pointer(tb0515_i)) then
      tb0515_fatalerror('sorted string error at ', tb0515_i);
    if tb0515_strlist.objects[tb0515_i] <> tobject(tb0515_i) then
      tb0515_fatalerror('sorted object error at ', tb0515_i);
  end;
  tb0515_strlist.delete(10);
  tb0515_strlist.delete(25);
  if tb0515_strlist.count <> tb0515_count-2 then
    tb0515_fatalerror('strlist.count is not ', tb0515_count-2);
  tb0515_j := 0;
  for tb0515_i := 0 to 61 do
  begin
    if tb0515_strlist.strings[tb0515_i] <> tb0515_ptrtopaddedstr(pointer(tb0515_j)) then
      tb0515_fatalerror('delete string error at ', tb0515_i);
    if tb0515_strlist.objects[tb0515_i] <> tobject(tb0515_j) then
      tb0515_fatalerror('delete object error at ', tb0515_i);
    inc(tb0515_j);
    if (tb0515_j = 10) or (tb0515_j = 26) then
      inc(tb0515_j);
  end;
  tb0515_strlist.free;
  writeln('ok');
end;
{$pop}

{ Case tw16848.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
  WriteLn('BoolToStr(False, True): ' + BoolToStr(False, True));
  if BoolToStr(False, True)<>'False' then
    halt(1);
  WriteLn('BoolToStr(True, True): ' + BoolToStr(True, True));
  if BoolToStr(True, True)<>'True' then
    halt(2);

  SetLength(TrueBoolStrs, 1);
  SetLength(FalseBoolStrs, 1);
  TrueBoolStrs[0] := 'Sim';
  FalseBoolStrs[0] := 'Não';

  WriteLn('BoolStrs = Não;Sim');

  WriteLn('BoolToStr(False, True): ' + BoolToStr(False, True));
  WriteLn('BoolToStr(True, True): ' + BoolToStr(True, True));

  tw16848_S := BoolToStr(False, True);
  if tw16848_S<>'Não' then
    halt(3);
  tw16848_B := StrToBool(tw16848_S);
  if tw16848_b<>false then
    halt(4);

  WriteLn('StrToBool(' + tw16848_S +') = ' + BoolToStr(tw16848_B, True));
  if BoolToStr(tw16848_B, True)<>'Não' then
    halt(5);
  tw16848_S := BoolToStr(True, True);
  if tw16848_s<>'Sim' then
    halt(6);
  tw16848_B := StrToBool(tw16848_S);
  if tw16848_b<>true then
    halt(7);
  WriteLn('StrToBool(' + tw16848_S +') = ' + BoolToStr(tw16848_B, True));
  if BoolToStr(tw16848_B, True)<>'Sim' then
    halt(8);

  { should give exception }
  if TryStrToBool('True',tw16848_B) then
    halt(9);
end;
{$pop}

{ Case tw25289.pp }
{$push}

{$H+}
begin
  tw25289_test;
  CheckCaseExitCode(tw25289_code);
end;
{$pop}

{ Case tw2899.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tw2899_DoSomething('WhatAStrangeBug');
end;
{$pop}

{ Case tw29244.pp }
{$push}

{$H+}
begin
  WriteLn(ConcatPaths(['one', 'two']));
end;
{$pop}

{ Case tw33706.pp }
{$push}

{$H+}
begin
  tw33706_test;
  if tw33706_code=0 then
    writeln('ok');
  CheckCaseExitCode(tw33706_code);
end;
{$pop}

{ Case tw4199.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
 writeln('1 ',tw4199_stringconst);             //ok
 writeln('2 ',widestring(tw4199_stringconst)); //ok
 writeln('3 ',tw4199_widestringconst);         //bad
 tw4199_str1:= tw4199_widestringconst;
 writeln('4 ',tw4199_str1);                    //bad
 tw4199_str2:= copy(tw4199_widestringconst,1,3);
 writeln('5 ',tw4199_str2);                    //bad
 if tw4199_widestringconst<>tw4199_stringconst then
   halt(1);
 if tw4199_str1<>tw4199_stringconst then
   halt(2);
 if tw4199_str2<>tw4199_stringconst then
   halt(3);
end;
{$pop}

{ Case tw4489.pp }
{$push}

{$H+}
begin
   tw4489_d:=11111111;
   tw4489_u:=1111;
   tw4489_s := format('pid=%d', [tw4489_u]);
   writeln(tw4489_s);
   tw4489_s := format('pid=%d', [tw4489_d]);
   writeln(tw4489_s);
end;
{$pop}

{ Case tw4632.pp }
{$push}

{$H+}
begin
  tw4632_name := '';
  for tw4632_i := 1 to 251 do
    tw4632_name := tw4632_name + 'a';   // complete name of 255 chars

  tw4632_s := ExtractFileName(tw4632_name + tw4632_ext);
  if Length(tw4632_s) <> 255 then
    tw4632_Error('Failed on 1');

  tw4632_s := tw4632_lExtractFileName(tw4632_name + tw4632_ext);
  if Length(tw4632_s) <> 255 then
    tw4632_Error('Failed on 2');

  tw4632_name := tw4632_name + 'a';     // complete name on 256 chars
  tw4632_s := ExtractFileName(tw4632_name + tw4632_ext);
  if Length(tw4632_s) <> 256 then
    tw4632_Error('Failed on 3');

  tw4632_s := tw4632_lExtractFileName(tw4632_name + tw4632_ext);
  if Length(tw4632_s) <> 256 then
    tw4632_Error('Failed on 4');

  if tw4632_err then
    halt(1);
end;
{$pop}

end.
