{ Consolidated routines regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0231.pp }
{$push}
{ Old file: tbs0271.pp }
{ abstract methods can't be assigned to methodpointers OK 0.99.13 (??) }


  type
    tb0231_tproc = procedure;

procedure tb0231_proc1;
begin
end;

var
  tb0231__copyscan : tb0231_tproc;

procedure tb0231_setproc;
begin
    tb0231__copyscan := @tb0231_proc1;
end;

procedure tb0231_testproc;
begin
  if not (tb0231__copyscan=@tb0231_proc1) then
    begin
      Writeln(' Problem procvar equality');
      Halt(1);
    end
  else
    Writeln(' No problem with procedure equality');
end;


{$pop}

{ Case tw10833.pp }
{$push}
procedure tw10833_p;experimental;
  begin
  end;


{$pop}

{ Case tw2707.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2707 }
{ Submitted by "Johannes Berg" on  2003-10-02 }
{ e-mail: johannes -at- sipsolutions -dot- de }
type
  tw2707_PSSL_METHOD = pointer;
  tw2707_PSSL_CTX = pointer;

var
  tw2707_MN_SSL_CTX_new  : function(method: tw2707_PSSL_METHOD): tw2707_PSSL_CTX cdecl = nil;


{$pop}

{ Case tw40618.pp }
{$push}


var
	tw40618_HiTimes: int32 = 0;

function tw40618_Hi: int32;
begin
	writeln('Hi called.');
	inc(tw40618_HiTimes);
	tw40618_Hi := 0;
end;


{$pop}

begin

{ Case tb0231.pp }
{$push}

begin
  tb0231_setproc;
  tb0231_testproc;
end;
{$pop}

{ Case tw10833.pp }
{$push}

begin
  tw10833_p;
end;
{$pop}

{ Case tw2707.pp }
{$push}

begin
end;
{$pop}

{ Case tw40618.pp }
{$push}

begin
	case tw40618_Hi of
		0 .. 2: ;
		else halt(1);
	end;
	if tw40618_HiTimes <> 1 then
	begin
		writeln('Hi called ', tw40618_HiTimes, ' times, expected 1.');
		halt(2);
	end
	else
		writeln('OK');
end;
{$pop}

end.
