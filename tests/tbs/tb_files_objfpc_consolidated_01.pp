{ Consolidated files regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tw12575.pp }
{$push}




VAR
  tw12575_t : Text;


{$pop}

{ Case tw1451.pp }
{$push}
{$ifdef fpc}{$endif}



var tw1451_ErrorFileHandle : Text;


{$pop}

{ Case tw1479.pp }
{$push}
{$ifdef fpc}{$endif}



const
  tw1479_fname = 'tw1479.tmp';

 tw1479_ThisDir = '.'+DirectorySeparator;
var
  tw1479_fn : string;
  tw1479_f : text;

{$pop}

begin

{ Case tw12575.pp }
{$push}

BEGIN
  Assign(tw12575_t, 'blah.txt');
  TRY
    Close(tw12575_t);
  EXCEPT
    ON e: EInOutError DO
      if (e.ErrorCode <> 103) then
        halt(1);
  END;
END;
{$pop}

{ Case tw1451.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  //No Assignfile
  Writeln('----');
  try
    CloseFile(tw1451_ErrorFileHandle);
  except
    on E: Exception
        do Writeln('ExceptionMessage: '+e.Message);
  end;
  Writeln('----');
end;
{$pop}

{ Case tw1479.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  assign(tw1479_f,tw1479_fname);
  rewrite(tw1479_f);
  writeln(tw1479_f,'hello');
  close(tw1479_f);

  tw1479_fn:=FileSearch(tw1479_fname,PathSeparator);
  writeln('found: ',tw1479_fn);
  if tw1479_fn<>tw1479_fname then
   halt(1);
  tw1479_fn:=FileSearch(tw1479_ThisDir+tw1479_fname,PathSeparator);
  writeln('found: ',tw1479_fn);
  if tw1479_fn<>tw1479_ThisDir+tw1479_fname then
   halt(1);
  erase(tw1479_f);
end;
{$pop}

end.
