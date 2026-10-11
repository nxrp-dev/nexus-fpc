{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tmultilinestring29.pp }
{$push}
// Multiline string

const
  tmultilinestring29_s = '''
  this
  is
  a multiline
  string
  ''';

  tmultilinestring29_stest = 'this'+sLineBreak+'is'+slinebreak+'a multiline'+sLineBreak+'string';


{$pop}

{ Case tmultilinestring30.pp }
{$push}
// Multiline string
// There is a space after the word multiline, test that it is not stripped!

const
  tmultilinestring30_s = '''
  this
  is
  a multiline 
  string
  ''';

  tmultilinestring30_stest = 'this'+sLineBreak+'is'+slinebreak+'a multiline '+sLineBreak+'string';


{$pop}

{ Case tmultilinestring31.pp }
{$push}
// Multiline string, 5 quotes, less quotes are preserved in the string

const
  tmultilinestring31_s = '''''
  this
  is
  a '''multiline'''
  string
  ''''';

  tmultilinestring31_stest = 'this'+sLineBreak+'is'+slinebreak+'a ''''''multiline'''''''+sLineBreak+'string';


{$pop}

{ Case tmultilinestring33.pp }
{$push}
// Multiline string

const
  tmultilinestring33_s = '''
  this is
  a UTF8 àéèùá
  multiline string
  ''';

  tmultilinestring33_stest = 'this is'+slinebreak+'a UTF8 àéèùá'+sLineBreak+'multiline string';


{$pop}

{ Case tutf8charconst.pp }
{$push}


{$H+}

const
  tutf8charconst_FULLWIDTH_RIGHT_PARENTHESIS: UTF8String = #$FF09;

var
  tutf8charconst_UFFFF: UTF8String;

{$pop}

begin

{ Case tmultilinestring29.pp }
{$push}

begin
  if not (tmultilinestring29_s=tmultilinestring29_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring29_stest,'" but got: "',tmultilinestring29_s,'"');
    halt(1);
    end;
end;
{$pop}

{ Case tmultilinestring30.pp }
{$push}

begin
  if not (tmultilinestring30_s=tmultilinestring30_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring30_stest,'" but got: "',tmultilinestring30_s,'"');
    halt(1);
    end;
end;
{$pop}

{ Case tmultilinestring31.pp }
{$push}

begin
  if not (tmultilinestring31_s=tmultilinestring31_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring31_stest,'" but got: "',tmultilinestring31_s,'"');
    halt(1);
    end;
end;
{$pop}

{ Case tmultilinestring33.pp }
{$push}

begin
  if not (tmultilinestring33_s=tmultilinestring33_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring33_stest,'" but got: "',tmultilinestring33_s,'"');
    halt(1);
    end;
end;
{$pop}

{ Case tutf8charconst.pp }
{$push}

{$H+}
begin
  if not((Length(tutf8charconst_FULLWIDTH_RIGHT_PARENTHESIS) = 3) and
         (Ord(tutf8charconst_FULLWIDTH_RIGHT_PARENTHESIS[1]) = $EF) and
         (Ord(tutf8charconst_FULLWIDTH_RIGHT_PARENTHESIS[2]) = $BC) and
         (Ord(tutf8charconst_FULLWIDTH_RIGHT_PARENTHESIS[3]) = $89)) then
    Halt(1);

  tutf8charconst_UFFFF := #65535;
  if not((Length(tutf8charconst_UFFFF) = 3) and
         (Ord(tutf8charconst_UFFFF[1]) = $EF) and
         (Ord(tutf8charconst_UFFFF[2]) = $BF) and
         (Ord(tutf8charconst_UFFFF[3]) = $BF)) then
    Halt(2);
end;
{$pop}

end.
