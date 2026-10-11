{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tw10224.pp }
{$push}



var
  tw10224_err : boolean;

procedure tw10224_expect(const v,s:string);
var
  s1,s2 : string;
begin
  s1:=SetDirSeparators(v);
  s2:=SetDirSeparators(s);
  writeln('relative path: "',s1,'"');
  if s1<>s2 then
    begin
      writeln('Error, expected "',s2,'"');
      tw10224_err:=true;
    end;
end;


{$pop}

{ Case tw10717.pp }
{$push}


{$IFDEF FPC}
  {$H+}
{$ENDIF}




type
  tw10717_tsingletestresults = array[1..5] of string;
  tw10717_tresults = array[1..5] of tw10717_tsingletestresults;
const
{$ifdef unix}
  tw10717_results: tw10717_tresults =
  (
   (
    'ExtractFilePath on ''./:'' = ''./''',
    'ExtractFileName on ''./:'' = '':''',
    'ExtractFileDrive on ''./:'' = ''''',
    'IncludeTrailingPathDelimiter on ''./:'' = ''./:/''',
    'ExcludeTrailingPathDelimiter on ''./:'' = ''./:'''
   ),

   (
    'ExtractFilePath on ''C:/blah:blah'' = ''C:/''',
    'ExtractFileName on ''C:/blah:blah'' = ''blah:blah''',
    'ExtractFileDrive on ''C:/blah:blah'' = ''''',
    'IncludeTrailingPathDelimiter on ''C:/blah:blah'' = ''C:/blah:blah/''',
    'ExcludeTrailingPathDelimiter on ''C:/blah:blah'' = ''C:/blah:blah'''
   ),

   (
    'ExtractFilePath on ''./\'' = ''./''',
    'ExtractFileName on ''./\'' = ''\''',
    'ExtractFileDrive on ''./\'' = ''''',
    'IncludeTrailingPathDelimiter on ''./\'' = ''./\/''',
    'ExcludeTrailingPathDelimiter on ''./\'' = ''./\'''
   ),

   (
    'ExtractFilePath on ''./c:'' = ''./''',
    'ExtractFileName on ''./c:'' = ''c:''',
    'ExtractFileDrive on ''./c:'' = ''''',
    'IncludeTrailingPathDelimiter on ''./c:'' = ''./c:/''',
    'ExcludeTrailingPathDelimiter on ''./c:'' = ''./c:'''
   ),

   (
    'ExtractFilePath on ''\\server\share\file'' = ''''',
    'ExtractFileName on ''\\server\share\file'' = ''\\server\share\file''',
    'ExtractFileDrive on ''\\server\share\file'' = ''''',
    'IncludeTrailingPathDelimiter on ''\\server\share\file'' = ''\\server\share\file/''',
    'ExcludeTrailingPathDelimiter on ''\\server\share\file'' = ''\\server\share\file'''
   )
  );
{$else}
  tw10717_results: tw10717_tresults =
  (
   (
    'ExtractFilePath on ''./:'' = ''./:''',
    'ExtractFileName on ''./:'' = ''''',
    'ExtractFileDrive on ''./:'' = ''''',
    'IncludeTrailingPathDelimiter on ''./:'' = ''./:\''',
    'ExcludeTrailingPathDelimiter on ''./:'' = ''./:'''
   ),

   (
    'ExtractFilePath on ''C:/blah:blah'' = ''C:/blah:''',
    'ExtractFileName on ''C:/blah:blah'' = ''blah''',
    'ExtractFileDrive on ''C:/blah:blah'' = ''C:''',
    'IncludeTrailingPathDelimiter on ''C:/blah:blah'' = ''C:/blah:blah\''',
    'ExcludeTrailingPathDelimiter on ''C:/blah:blah'' = ''C:/blah:blah'''
   ),

   (
    'ExtractFilePath on ''./\'' = ''./\''',
    'ExtractFileName on ''./\'' = ''''',
    'ExtractFileDrive on ''./\'' = ''''',
    'IncludeTrailingPathDelimiter on ''./\'' = ''./\''',
    'ExcludeTrailingPathDelimiter on ''./\'' = ''./'''
   ),

   (
    'ExtractFilePath on ''./c:'' = ''./c:''',
    'ExtractFileName on ''./c:'' = ''''',
    'ExtractFileDrive on ''./c:'' = ''''',
    'IncludeTrailingPathDelimiter on ''./c:'' = ''./c:\''',
    'ExcludeTrailingPathDelimiter on ''./c:'' = ''./c:'''
   ),

   (
    'ExtractFilePath on ''\\server\share\file'' = ''\\server\share\''',
    'ExtractFileName on ''\\server\share\file'' = ''file''',
    'ExtractFileDrive on ''\\server\share\file'' = ''\\server\share''',
    'IncludeTrailingPathDelimiter on ''\\server\share\file'' = ''\\server\share\file\''',
    'ExcludeTrailingPathDelimiter on ''\\server\share\file'' = ''\\server\share\file'''
   )
  );
{$endif}

procedure tw10717_TestFuncs(const strPath: string; const tw10717_results: tw10717_tsingletestresults);
begin
  WriteLn(Format('ExtractFilePath on ''%s'' = ''%s''',
                [strPath, ExtractFilePath(strPath)]));
  WriteLn(Format('ExtractFileName on ''%s'' = ''%s''',
                [strPath, ExtractFileName(strPath)]));
  WriteLn(Format('ExtractFileDrive on ''%s'' = ''%s''',
                [strPath, ExtractFileDrive(strPath)]));
  WriteLn(Format('IncludeTrailingPathDelimiter on ''%s'' = ''%s''',
                [strPath, IncludeTrailingPathDelimiter(strPath)]));
  WriteLn(Format('ExcludeTrailingPathDelimiter on ''%s'' = ''%s''',
                [strPath, ExcludeTrailingPathDelimiter(strPath)]));

  if (Format('ExtractFilePath on ''%s'' = ''%s''',[strPath, ExtractFilePath(strPath)]) <> tw10717_results[1]) then
    begin
      writeln('ExtractFilePath: ',ExtractFilePath(strPath));
      halt(1);
    end;

  if (Format('ExtractFileName on ''%s'' = ''%s''',[strPath, ExtractFileName(strPath)]) <> tw10717_results[2]) then
    begin
      writeln('ExtractFileName: ',ExtractFileName(strPath));
      halt(2);
    end;

  if (Format('ExtractFileDrive on ''%s'' = ''%s''',[strPath, ExtractFileDrive(strPath)]) <> tw10717_results[3]) then
    begin
      writeln('ExtractFileDrive: ',ExtractFileDrive(strPath));
      halt(3);
    end;

  if (Format('IncludeTrailingPathDelimiter on ''%s'' = ''%s''',[strPath, IncludeTrailingPathDelimiter(strPath)]) <> tw10717_results[4]) then
    begin
      writeln('IncludeTrailingPathDelimiter: ',IncludeTrailingPathDelimiter(strPath));
      halt(4);
    end;

  if (Format('ExcludeTrailingPathDelimiter on ''%s'' = ''%s''',[strPath, ExcludeTrailingPathDelimiter(strPath)]) <> tw10717_results[5]) then
    begin
      writeln('ExcludeTrailingPathDelimiter: ',ExcludeTrailingPathDelimiter(strPath));
      halt(5);
    end;

  WriteLn;
end;


{$pop}

{ Case tw1255.pp }
{$push}



procedure tw1255_testff(const s: string);
var
  sr: tsearchrec;
  i : integer;
begin
  i:=0;
  if findfirst(s,faAnyFile,sr)=0 then
   repeat
     writeln(sr.name);
     inc(i);
   until findnext(sr)<>0;
  findclose(sr);
  if (i=0) then
   halt(1);
end;


{$pop}

{ Case tw1286.pp }
{$push}
{$ifdef fpc}{$endif}

 var tw1286_S:String;
     tw1286_par:array [0..1] of TVarRec; { array of const here is illegal ! }

{$pop}

{ Case tw2046a.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2046 }
{ Submitted by "Mattias Gaertner" on  2002-07-17 }
{ e-mail: nc-gaertnma@netcologne.de }

{ modified to check that passing array of const
  from functions to functions works correctly PM }



{$H+}




procedure tw2046a_sprintf(var tw2046a_a : string; const fm: string; args: array of const);
begin
  tw2046a_a:=Format (fm,args);
end;

procedure tw2046a_sprintf2(var tw2046a_a : string; const fm: string; args: array of const);
begin
  FmtStr (tw2046a_a,fm,args);
end;

procedure tw2046a_print(args: array of const);
var
  tw2046a_a : string;
begin
  tw2046a_sprintf(tw2046a_a,'a number %D-%D%S',args);
  writeln(tw2046a_a);
  if tw2046a_a<>'a number 3333-45 test string' then
   begin
     writeln('Error!');
     halt(1);
   end;
  tw2046a_sprintf2(tw2046a_a,'a number %D-%D%S',args);
  writeln(tw2046a_a);
  if tw2046a_a<>'a number 3333-45 test string' then
   begin
     writeln('Error!');
     halt(1);
   end;
end;

var
  tw2046a_a : string;

{$pop}

{ Case tw24915.pp }
{$push}


{$H+}



function tw24915_test(const a, b: string): string; inline;
begin
  result:=b;
end;

const tw24915_path: string = 'C:\123456789012345678901234567890\test.txt';
var tw24915_t: string;


{$pop}

{ Case tw26627.pp }
{$push}


{$h+}



var tw26627_a: ansistring;


{$pop}

{ Case tw3504.pp }
{$push}
{$H+}



function tw3504_Func1( Args :array of string ) :string;
begin
  WriteLn('project2 Arg0-'+Args[0] +' Arg1-'+Args[1]);
  if (Args[0]='1') and (Args[1]='2') then
    Result := 'Ok'
  else
    Result := 'Err';
end;

var
  tw3504_Int1, tw3504_Int2  :integer;
  tw3504_s : string;

{$pop}

{ Case tw37034.pp }
{$push}



{$h+}



{$assertions on}

function tw37034_Suffix: string; inline;
begin
  Result := 'Post';
end;

const
  tw37034_Expected = 'Pre_Mid_Post';
var
  tw37034_s, tw37034_t: string;

{$pop}

{ Case tw39323.pp }
{$push}



{$H+}{$R+}
{$ZeroBasedStrings On}



var
  tw39323_S: String = 'Cat';
  tw39323_U: UnicodeString = 'Cat';
  tw39323_W: WideString = 'Cat';

{$pop}

{ Case tw41545.pp }
{$push}


{$H+}



const
  tw41545_VK_0 = $30;
  tw41545_VK_A = $41;

var
  tw41545_TestsPassed: Integer = 0;
  tw41545_TestsFailed: Integer = 0;

function tw41545_GetVK(Character: Char): Integer;
begin
  Result := 0;
  case Character of
    '0'..'9': Result := tw41545_VK_0 + Ord(Character) - Ord('0');
    'a'..'z': Result := tw41545_VK_A + Ord(Character) - Ord('a');
    'A'..'Z': Result := tw41545_VK_A + Ord(Character) - Ord('A');
  end;
end;

procedure tw41545_Check(const TestName: String; Condition: Boolean);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(tw41545_TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(tw41545_TestsFailed);
  end;
end;

procedure tw41545_CheckEqual(const TestName: String; Expected, Actual: Integer);
begin
  if Expected = Actual then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(tw41545_TestsPassed);
  end
  else
  begin
    WriteLn(Format('[FAIL] %s: expected $%02X, got $%02X', [TestName, Expected, Actual]));
    Inc(tw41545_TestsFailed);
  end;
end;

var
  tw41545_C: Char;

{$pop}

begin

{ Case tw10224.pp }
{$push}

begin
  tw10224_expect(ExtractRelativePath('c:\one\two\three\test.pp','c:\one\two\three\four\five\test2.pp'),'four\five\test2.pp');
  tw10224_expect(ExtractRelativePath('c:\one\two\three\four\five\test.pp','c:\one\two\three\test2.pp'),'..\..\test2.pp');
  tw10224_expect(ExtractRelativePath('c:\one\two\three\','c:\one\two\three\four\five\test.pp'),'four\five\test.pp');
  tw10224_expect(ExtractRelativePath('c:\one\two\three\four\five\','c:\one\two\three\test.pp'),'..\..\test.pp');
  tw10224_expect(ExtractRelativePath('c:\one\two\three\','c:\one\two\three\four\five\'),'four\five\');
  tw10224_expect(ExtractRelativePath('c:\one\two\three\four\five\','c:\one\two\three\'),'..\..\');
  if tw10224_err then
    halt(1);
end;
{$pop}

{ Case tw10717.pp }
{$push}
{$IFDEF FPC}

{$H+}
{$ENDIF}
{$ifdef unix}
{$else}
{$endif}
begin
{$ifdef unix}
  { make settings Kylix-compatible }
  AllowDriveSeparators:=[];
  AllowDirectorySeparators:=['/'];
{$endif}
  tw10717_TestFuncs('./:',tw10717_results[1]);
  tw10717_TestFuncs('C:/blah:blah',tw10717_results[2]);
  tw10717_TestFuncs('./\',tw10717_results[3]);
  tw10717_TestFuncs('./c:',tw10717_results[4]);
  tw10717_TestFuncs('\\server\share\file',tw10717_results[5]);
  writeln('ok');
end;
{$pop}

{ Case tw1255.pp }
{$push}

begin
{$ifdef UNIX}
  {$ifdef haiku}
    tw1255_testff('/boot/system/lib/libroot.*');
  {$else}
    tw1255_testff('/etc/host*');
  {$endif}
{$else}
  {$ifdef wince}
    tw1255_testff('\windows\calc.*');
  {$else}
    tw1255_testff(ChangeFileExt(GetEnvironmentVariable('comspec'), '.*'));
  {$endif wince}
{$endif}
end;
{$pop}

{ Case tw1286.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
 writeln(format(tw1286_S, tw1286_par));
end;
{$pop}

{ Case tw2046a.pp }
{$push}

{$H+}
begin
  tw2046a_a:=format('a number %D',[12345]);
  writeln(tw2046a_a);
  if tw2046a_a<>'a number 12345' then
   begin
     writeln('Error!');
     halt(1);
   end;
  tw2046a_print([3333,45,' test string']);
end;
{$pop}

{ Case tw24915.pp }
{$push}

{$H+}
begin
  tw24915_t:=tw24915_test(ExtractFilePath(tw24915_path), ExtractFilePath(tw24915_path));
  writeln(stringcodepage(tw24915_path));
  writeln('Path: '+tw24915_t);
end;
{$pop}

{ Case tw26627.pp }
{$push}

{$h+}
begin
  defaultfilesystemcodepage:=CP_UTF8;
  defaultrtlfilesystemcodepage:=CP_ASCII;
  tw26627_a := DirectorySeparator+'.';
  tw26627_a := ExpandFileName(tw26627_a);
  if StringCodePage(tw26627_a)<> defaultrtlfilesystemcodepage then
   halt(1);
end;
{$pop}

{ Case tw3504.pp }
{$push}

{$H+}
begin
  tw3504_Int1 := 1;
  tw3504_Int2 := 2;
  tw3504_s:=tw3504_Func1( [ IntToStr(tw3504_Int1), IntToStr(tw3504_Int2)] );
  writeln(tw3504_s);
  if tw3504_s<>'Ok' then
    halt(1);
end;
{$pop}

{ Case tw37034.pp }
{$push}

{$h+}
{$assertions on}
begin
  DefaultSystemCodePage:=1252;
  writeln(DefaultSystemCodePage);
  writeln(StringCodePage(tw37034_suffix));
  tw37034_s := 'Pre';
  tw37034_t := tw37034_s + '_Mid_' + tw37034_Suffix;
  Assert(tw37034_t = tw37034_Expected,format('Expected "%s", Got: "%s"',[tw37034_Expected,tw37034_t]));
  writeln('Ok');
end;
{$pop}

{ Case tw39323.pp }
{$push}

{$H+}
{$R+}
{$ZeroBasedStrings On}
begin
  tw39323_S[0] := 'H';
  if tw39323_S<>'Hat' then
    halt(1);
  tw39323_U[0] := 'H';
  if tw39323_U<>'Hat' then
    halt(1);
  tw39323_W[0] := 'H';
  if tw39323_W<>'Hat' then
    halt(1);

  WriteLn('ok');
end;
{$pop}

{ Case tw41545.pp }
{$push}

{$H+}
begin
  WriteLn('Testing GetVK Function');
  WriteLn('======================');
  WriteLn;

  { Test digits }
  WriteLn('-- Digit tests --');
  tw41545_CheckEqual('GetVK(''0'') = VK_0', tw41545_VK_0, tw41545_GetVK('0'));
  tw41545_CheckEqual('GetVK(''5'') = VK_0 + 5', tw41545_VK_0 + 5, tw41545_GetVK('5'));
  tw41545_CheckEqual('GetVK(''9'') = VK_0 + 9', tw41545_VK_0 + 9, tw41545_GetVK('9'));

  { Verify all digits map correctly }
  for tw41545_C := '0' to '9' do
    tw41545_Check(Format('Digit %s maps to $%02X', [tw41545_C, tw41545_VK_0 + Ord(tw41545_C) - Ord('0')]),
          tw41545_GetVK(tw41545_C) = tw41545_VK_0 + Ord(tw41545_C) - Ord('0'));
  WriteLn;

  { Test uppercase letters }
  WriteLn('-- Uppercase letter tests --');
  tw41545_CheckEqual('GetVK(''A'') = VK_A', tw41545_VK_A, tw41545_GetVK('A'));
  tw41545_CheckEqual('GetVK(''M'') = VK_A + 12', tw41545_VK_A + 12, tw41545_GetVK('M'));
  tw41545_CheckEqual('GetVK(''Z'') = VK_A + 25', tw41545_VK_A + 25, tw41545_GetVK('Z'));

  { Verify all uppercase letters map correctly }
  for tw41545_C := 'A' to 'Z' do
    tw41545_Check(Format('Uppercase %s maps to $%02X', [tw41545_C, tw41545_VK_A + Ord(tw41545_C) - Ord('A')]),
          tw41545_GetVK(tw41545_C) = tw41545_VK_A + Ord(tw41545_C) - Ord('A'));
  WriteLn;

  { Test lowercase letters }
  WriteLn('-- Lowercase letter tests --');
  tw41545_CheckEqual('GetVK(''a'') = VK_A', tw41545_VK_A, tw41545_GetVK('a'));
  tw41545_CheckEqual('GetVK(''m'') = VK_A + 12', tw41545_VK_A + 12, tw41545_GetVK('m'));
  tw41545_CheckEqual('GetVK(''z'') = VK_A + 25', tw41545_VK_A + 25, tw41545_GetVK('z'));

  { Verify all lowercase letters map correctly }
  for tw41545_C := 'a' to 'z' do
    tw41545_Check(Format('Lowercase %s maps to $%02X', [tw41545_C, tw41545_VK_A + Ord(tw41545_C) - Ord('a')]),
          tw41545_GetVK(tw41545_C) = tw41545_VK_A + Ord(tw41545_C) - Ord('a'));
  WriteLn;

  { Test that lowercase and uppercase produce same VK code }
  WriteLn('-- Case insensitivity tests --');
  tw41545_Check('GetVK(''a'') = GetVK(''A'')', tw41545_GetVK('a') = tw41545_GetVK('A'));
  tw41545_Check('GetVK(''z'') = GetVK(''Z'')', tw41545_GetVK('z') = tw41545_GetVK('Z'));
  for tw41545_C := 'A' to 'Z' do
    tw41545_Check(Format('%s and %s produce same VK', [tw41545_C, Chr(Ord(tw41545_C) + 32)]),
          tw41545_GetVK(tw41545_C) = tw41545_GetVK(Chr(Ord(tw41545_C) + 32)));
  WriteLn;

  { Test invalid characters return 0 }
  WriteLn('-- Invalid character tests --');
  tw41545_CheckEqual('GetVK('' '') = 0 (space)', 0, tw41545_GetVK(' '));
  tw41545_CheckEqual('GetVK(''!'') = 0', 0, tw41545_GetVK('!'));
  tw41545_CheckEqual('GetVK(''@'') = 0', 0, tw41545_GetVK('@'));
  tw41545_CheckEqual('GetVK(''['') = 0', 0, tw41545_GetVK('['));
  tw41545_CheckEqual('GetVK(#0) = 0 (null)', 0, tw41545_GetVK(#0));
  WriteLn;

  { Summary }
  WriteLn('======================');
  WriteLn(Format('Tests passed: %d', [tw41545_TestsPassed]));
  WriteLn(Format('Tests failed: %d', [tw41545_TestsFailed]));
  WriteLn;

  if tw41545_TestsFailed = 0 then
    WriteLn('All tests PASSED!')
  else
  begin
    WriteLn('Some tests FAILED!');
    Halt(1);
  end;
end;
{$pop}

end.
