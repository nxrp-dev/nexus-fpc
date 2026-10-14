{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_control_flow_delphi_consolidated_01.pas }
{$push}
{ Consolidated control flow regressions; original case IDs and assertions are retained. }



{ Case tb0659d.pas }
{$push}




{$ifdef FPC_OBJFPC}
{$fatal FPC_OBJFPC defined}
{$endif}
{$ifndef FPC_DELPHI}
{$fatal FPC_DELPHI not defined}
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

{ Case tb0722.pas }
{$push}




{$region 'foobar}


{$pop}

{ Case tw07584a.pas }
{$push}


{$ifdef fpc}

{$endif}

const
  tw07584a_Inf = 1.0 / 0.0;


{$pop}

{ Case tw14134.pas }
{$push}

{$h+}

const
  tw14134_OurGUID_str = '{F572C54B-EB2B-454A-B2A0-D9138C0D2F07}';
  tw14134_OurGUID: TGUID = tw14134_OurGUID_str;


{$pop}

{ Case tw2953.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2953 }
{ Submitted by "" on  2004-02-07 }
{ e-mail: Marco }


// Next line should give a warning only
//$IF's are evaluated before $IFDEF's


{$pop}


{$pop}

{ Case tmultilinestring34.pas }
{$push}
// Multiline string

{$TEXTBLOCK CRLF}
const
  tmultilinestring34_s = '''
  this
  is
  a multiline
  string
  ''';

  tmultilinestring34_CRLF = #13#10;
  tmultilinestring34_stest = 'this'+tmultilinestring34_CRLF+'is'+tmultilinestring34_CRLF+'a multiline'+tmultilinestring34_CRLF+'string';


{$pop}

{ Case tmultilinestring35.pas }
{$push}
// Multiline string,

{$TEXTBLOCK CRLF}
const
  tmultilinestring35_s = '''
  this is
  a UTF8 àéèùá
  multiline string
  ''';

  tmultilinestring35_CRLF = #13#10;
  tmultilinestring35_stest = 'this is'+tmultilinestring35_CRLF+'a UTF8 àéèùá'+tmultilinestring35_CRLF+'multiline string';


{$pop}

begin

{ Case tb_control_flow_delphi_consolidated_01.pas }
{$push}

{$push}
{$ifdef FPC_OBJFPC}
{$fatal FPC_OBJFPC defined}
{$endif}
{$ifndef FPC_DELPHI}
{$fatal FPC_DELPHI not defined}
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
{$push}
{$region 'foobar}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$h+}
{$pop}
{$push}
{$pop}
begin

{ Case tb0659d.pas }
{$push}

{$ifdef FPC_OBJFPC}
{$fatal FPC_OBJFPC defined}
{$endif}
{$ifndef FPC_DELPHI}
{$fatal FPC_DELPHI not defined}
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

{ Case tb0722.pas }
{$push}

{$region 'foobar}
begin

end;
{$pop}

{ Case tw07584a.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw14134.pas }
{$push}

{$h+}
begin
end;
{$pop}

{ Case tw2953.pas }
{$push}

begin
end;
{$pop}

end;
{$pop}

{ Case tmultilinestring34.pas }
{$push}

{$TEXTBLOCK CRLF}
begin
  if not (tmultilinestring34_s=tmultilinestring34_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring34_stest,'" but got: "',tmultilinestring34_s,'"');
    halt(1);
    end;
end;
{$pop}

{ Case tmultilinestring35.pas }
{$push}

{$TEXTBLOCK CRLF}
begin
  if not (tmultilinestring35_s=tmultilinestring35_stest) then
    begin
    writeln('Wrong string, expected "',tmultilinestring35_stest,'" but got: "',tmultilinestring35_s,'"');
    halt(1);
    end;
end;
{$pop}

end.
