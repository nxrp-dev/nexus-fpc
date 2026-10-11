{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tcase2.pp }
{$push}
    const
       tcase2_maxsmallint = high(smallint);
       { error codes }
       tcase2_grOk =  0;
       tcase2_grNoInitGraph = -1;
       tcase2_grNotDetected = -2;
       tcase2_grFileNotFound = -3;
       tcase2_grInvalidDriver = -4;
       tcase2_grNoLoadMem = -5;
       tcase2_grNoScanMem = -6;
       tcase2_grNoFloodMem = -7;
       tcase2_grFontNotFound = -8;
       tcase2_grNoFontMem = -9;
       tcase2_grInvalidMode = -10;
       tcase2_grError = -11;
       tcase2_grIOerror = -12;
       tcase2_grInvalidFont = -13;
       tcase2_grInvalidFontNum = -14;
       tcase2_grInvalidVersion = -18;

function tcase2_GraphErrorMsg(ErrorCode: smallint): string;
Begin
 tcase2_GraphErrorMsg:='';
 case ErrorCode of
  tcase2_grOk,tcase2_grFileNotFound,tcase2_grInvalidDriver: exit;
  tcase2_grNoInitGraph: tcase2_GraphErrorMsg:='Graphics driver not installed';
  tcase2_grNotDetected: tcase2_GraphErrorMsg:='Graphics hardware not detected';
  tcase2_grNoLoadMem,tcase2_grNoScanMem,tcase2_grNoFloodMem: tcase2_GraphErrorMsg := 'Not enough memory for graphics';
  tcase2_grNoFontMem: tcase2_GraphErrorMsg := 'Not enough memory to load font';
  tcase2_grFontNotFound: tcase2_GraphErrorMsg:= 'Font file not found';
  tcase2_grInvalidMode: tcase2_GraphErrorMsg := 'Invalid graphics mode';
  tcase2_grError: tcase2_GraphErrorMsg:='Graphics error';
  tcase2_grIoError: tcase2_GraphErrorMsg:='Graphics I/O error';
  tcase2_grInvalidFont,tcase2_grInvalidFontNum: tcase2_GraphErrorMsg := 'Invalid font';
  tcase2_grInvalidVersion: tcase2_GraphErrorMsg:='Invalid driver version';
 end;
end;


{$pop}

{ Case tcnvstr2.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondtypeconvert() -> second_cstring_to_pchar   }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}
{$H-}
const
 tcnvstr2_StrConst = 'HELLO WORLD';
 tcnvstr2_AnsiConst = 'COCORICCO!';
 tcnvstr2_AnsiConst2 = '';

procedure tcnvstr2_testcstring2pcharone;
 var
  p1 : pchar;
 begin
  WriteLn('(left) : LOC_MEM; (right) : LOC_MEM');
  p1 := pchar(tcnvstr2_strconst);
  WriteLn('Value should be ''HELLO WORLD''...',p1);
 end;

{ source:                                                       }
{   LOC_REFERENCE, LOC_MEM                                      }
{ destination:                                                  }
var
 tcnvstr2_p: pchar;

{$pop}

{ Case tvecsimplify2.pp }
{$push}

{$H+}

const
  tvecsimplify2_SSonnet: AnsiString = 'When forty winters shall besiege thy brow,'#10+
	'And dig deep trenches in thy beauty''s field,'#10+
	'Thy youth''s proud livery, so gazed on now,'#10+
	'Will be a tattered weed of small worth held.'#10+
	'Then being asked where all thy beauty lies,'#10+
	'Where all the treasure of thy lusty days,'#10+
	'To say within thine own deep-sunken eyes'#10+
	'Were an all-eating shame and thriftless praise.'#10+
	'How much more praise deserved thy beauty''s use'#10+
	'If thou couldst answer ''This fair child of mine'#10+
	'Shall sum my count, and make my old excuse'','#10+
	'Proving his beauty by succession thine.'#10+
	'This were to be new made when thou art old,'#10+
	'And see thy blood warm when thou feel''st it cold.';

function tvecsimplify2_GetChar: AnsiChar;
begin
  tvecsimplify2_GetChar := tvecsimplify2_SSonnet[300];
end;


{$pop}

{ Case tvecsimplify3.pp }
{$push}

{$H+}

const
  tvecsimplify3_SSonnet: WideString = 'When forty winters shall besiege thy brow,'#10+
	'And dig deep trenches in thy beauty''s field,'#10+
	'Thy youth''s proud livery, so gazed on now,'#10+
	'Will be a tattered weed of small worth held.'#10+
	'Then being asked where all thy beauty lies,'#10+
	'Where all the treasure of thy lusty days,'#10+
	'To say within thine own deep-sunken eyes'#10+
	'Were an all-eating shame and thriftless praise.'#10+
	'How much more praise deserved thy beauty''s use'#10+
	'If thou couldst answer ''This fair child of mine'#10+
	'Shall sum my count, and make my old excuse'','#10+
	'Proving his beauty by succession thine.'#10+
	'This were to be new made when thou art old,'#10+
	'And see thy blood warm when thou feel''st it cold.';

function tvecsimplify3_GetChar: WideChar;
begin
  tvecsimplify3_GetChar := tvecsimplify3_SSonnet[300];
end;


{$pop}

{ Case tvecsimplify4.pp }
{$push}

{$H+}

const
  tvecsimplify4_SSonnet: UnicodeString = 'When forty winters shall besiege thy brow,'#10+
	'And dig deep trenches in thy beauty''s field,'#10+
	'Thy youth''s proud livery, so gazed on now,'#10+
	'Will be a tattered weed of small worth held.'#10+
	'Then being asked where all thy beauty lies,'#10+
	'Where all the treasure of thy lusty days,'#10+
	'To say within thine own deep-sunken eyes'#10+
	'Were an all-eating shame and thriftless praise.'#10+
	'How much more praise deserved thy beauty''s use'#10+
	'If thou couldst answer ''This fair child of mine'#10+
	'Shall sum my count, and make my old excuse'','#10+
	'Proving his beauty by succession thine.'#10+
	'This were to be new made when thou art old,'#10+
	'And see thy blood warm when thou feel''st it cold.';

function tvecsimplify4_GetChar: UnicodeChar;
begin
  tvecsimplify4_GetChar := tvecsimplify4_SSonnet[300];
end;


{$pop}

begin

{ Case tcase2.pp }
{$push}

begin
  if tcase2_GraphErrorMsg(tcase2_grNoInitGraph) <> 'Graphics driver not installed' then
    halt(1);
end;
{$pop}

{ Case tcnvstr2.pp }
{$push}
{$H-}
Begin
  WriteLn('------------------- STRING/PCHAR ------------------------');
  WriteLn('(left) : LOC_MEM; (right) : LOC_MEM');
 { LOC_MEM -> LOC_MEM test }
 { SHORTSTRING -> PCHAR           }
 tcnvstr2_p := pchar(tcnvstr2_strconst);
 WriteLn('Value should be ''HELLO WORLD''...',tcnvstr2_p);
 tcnvstr2_testcstring2pcharone;
 WriteLn('------------------- ANSI/PCHAR ------------------------');
 WriteLn('(left) : LOC_MEM; (right) : LOC_MEM');
 tcnvstr2_p:=pchar(ansistring(tcnvstr2_ansiconst));
 WriteLn('Value should be ''COCORICCO!''...',tcnvstr2_p);
 tcnvstr2_p:=pchar(ansistring(tcnvstr2_ansiconst2));
 WriteLn('Value should be ''''...',tcnvstr2_p);
End;
{$pop}

{ Case tvecsimplify2.pp }
{$push}
{$H+}
begin
  if tvecsimplify2_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

{ Case tvecsimplify3.pp }
{$push}
{$H+}
begin
  if tvecsimplify3_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

{ Case tvecsimplify4.pp }
{$push}
{$H+}
begin
  if tvecsimplify4_GetChar() <> 'y' then
    Halt(1);

  WriteLn('ok');
end;
{$pop}

end.
