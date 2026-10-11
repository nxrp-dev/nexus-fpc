{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb0659d.pp }
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

{ Case tb0722.pp }
{$push}




{$region 'foobar}


{$pop}

{ Case tw07584a.pp }
{$push}


{$ifdef fpc}

{$endif}

const
  tw07584a_Inf = 1.0 / 0.0;


{$pop}

{ Case tw14134.pp }
{$push}

{$h+}

const
  tw14134_OurGUID_str = '{F572C54B-EB2B-454A-B2A0-D9138C0D2F07}';
  tw14134_OurGUID: TGUID = tw14134_OurGUID_str;


{$pop}

{ Case tw2953.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2953 }
{ Submitted by "" on  2004-02-07 }
{ e-mail: Marco }


// Next line should give a warning only
//$IF's are evaluated before $IFDEF's


{$pop}

begin

{ Case tb0659d.pp }
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

{ Case tb0722.pp }
{$push}

{$region 'foobar}
begin

end;
{$pop}

{ Case tw07584a.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw14134.pp }
{$push}

{$h+}
begin
end;
{$pop}

{ Case tw2953.pp }
{$push}

begin
end;
{$pop}

end.
