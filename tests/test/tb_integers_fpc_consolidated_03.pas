{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tmaclocalprocparam2a.pas }
{$push}

{$modeswitch nestedprocvars}



  procedure tmaclocalprocparam2a_p1( procedure pp( pi: longint); i: longint);
  begin
    pp( i)
  end;

  procedure tmaclocalprocparam2a_p2( procedure pp( pi: longint); i: longint);
  begin
    tmaclocalprocparam2a_p1( pp, i)
  end;

  procedure tmaclocalprocparam2a_n( ri: longint);
  begin
    if ri = 1 then
      writeln( 'success for n')
    else
      begin
        writeln( 'fail');
        halt( 1)
      end
   end;

  procedure tmaclocalprocparam2a_q;
  var qi: longint;

    procedure r( ri: longint);
    begin
      if qi = ri then
        writeln( 'success for r')
      else
        begin
        writeln( 'fail');
        halt( 1)
      end
    end;

  begin
    qi:= 1;
    tmaclocalprocparam2a_p1( @r, qi);
    tmaclocalprocparam2a_p2( @r, qi);
    tmaclocalprocparam2a_p1( @tmaclocalprocparam2a_n, qi);
    tmaclocalprocparam2a_p2( @tmaclocalprocparam2a_n, qi);
  end;


{$pop}

{ Case tmaclocalprocparam2d.pas }
{$push}

{$modeswitch nestedprocvars}



type
  tmaclocalprocparam2d_tnestedprocvar = procedure ( pi: longint) is nested;

  procedure tmaclocalprocparam2d_p1(pp: tmaclocalprocparam2d_tnestedprocvar; i: longint);
  begin
    pp( i)
  end;

  procedure tmaclocalprocparam2d_p2( pp: tmaclocalprocparam2d_tnestedprocvar; i: longint);
  begin
    tmaclocalprocparam2d_p1( pp, i)
  end;

  procedure tmaclocalprocparam2d_n( ri: longint);
  begin
    if ri = 1 then
      writeln( 'success for n')
    else
      begin
        writeln( 'fail');
        halt( 1)
      end
   end;

  procedure tmaclocalprocparam2d_q;
  var qi: longint;

    procedure r( ri: longint);
    begin
      if qi = ri then
        writeln( 'success for r')
      else
        begin
        writeln( 'fail');
        halt( 1)
      end
    end;

  begin
    qi:= 1;
    tmaclocalprocparam2d_p1( @r, qi);
    tmaclocalprocparam2d_p2( @r, qi);
    tmaclocalprocparam2d_p1( @tmaclocalprocparam2d_n, qi);
    tmaclocalprocparam2d_p2( @tmaclocalprocparam2d_n, qi);
  end;


{$pop}

{ Case tmaclocalprocparam3a.pas }
{$push}
{$modeswitch nestedprocvars}


  procedure tmaclocalprocparam3a_p1( procedure pp);
  begin
    pp
  end;

  procedure tmaclocalprocparam3a_p2( procedure pp);
  begin
    tmaclocalprocparam3a_p1( pp)
  end;

  procedure tmaclocalprocparam3a_n;
  begin
    writeln( 'calling through n')
  end;

  procedure tmaclocalprocparam3a_q;
  var qi: longint;

    procedure r;
    begin
      if qi = 1 then
        writeln( 'success for r')
      else
        begin
        writeln( 'fail');
        halt( 1)
      end
    end;

  begin
    qi:= 1;
    tmaclocalprocparam3a_p1( @r);
    tmaclocalprocparam3a_p2( @r);
    tmaclocalprocparam3a_p1( @tmaclocalprocparam3a_n);
    tmaclocalprocparam3a_p2( @tmaclocalprocparam3a_n);
  end;


{$pop}

{ Case tmaclocalprocparam3d.pas }
{$push}
{$modeswitch nestedprocvars}


type
  tmaclocalprocparam3d_tnestedprocvar = procedure is nested;

var
  tmaclocalprocparam3d_tempp: tmaclocalprocparam3d_tnestedprocvar;

  procedure tmaclocalprocparam3d_p1( pp: tmaclocalprocparam3d_tnestedprocvar);
  begin
    tmaclocalprocparam3d_tempp:=pp;
    tmaclocalprocparam3d_tempp
  end;

  procedure tmaclocalprocparam3d_p2( pp: tmaclocalprocparam3d_tnestedprocvar);
  var
    localpp: tmaclocalprocparam3d_tnestedprocvar;
  begin
    localpp:=pp;
    tmaclocalprocparam3d_p1( localpp)
  end;

  procedure tmaclocalprocparam3d_n;
  begin
    writeln( 'calling through n')
  end;

  procedure tmaclocalprocparam3d_q;
  var qi: longint;

    procedure r;
    begin
      if qi = 1 then
        writeln( 'success for r')
      else
        begin
        writeln( 'fail');
        halt( 1)
      end
    end;

  begin
    qi:= 1;
    tmaclocalprocparam3d_p1( @r);
    tmaclocalprocparam3d_p2( @r);
    tmaclocalprocparam3d_p1( @tmaclocalprocparam3d_n);
    tmaclocalprocparam3d_p2( @tmaclocalprocparam3d_n);
  end;


{$pop}

{ Case tmaclocalprocparam4e.pas }
{$push}
{$modeswitch nestedprocvars}

function tmaclocalprocparam4e_test(l: longint): longint;
begin
  tmaclocalprocparam4e_test:=l*2;
end;

const
  tmaclocalprocparam4e_pp: function(l: longint): longint is nested = @tmaclocalprocparam4e_test;


{$pop}

begin

{ Case tmaclocalprocparam2a.pas }
{$push}

{$modeswitch nestedprocvars}
begin
    tmaclocalprocparam2a_q
end;
{$pop}

{ Case tmaclocalprocparam2d.pas }
{$push}

{$modeswitch nestedprocvars}
begin
    tmaclocalprocparam2d_q
end;
{$pop}

{ Case tmaclocalprocparam3a.pas }
{$push}
{$modeswitch nestedprocvars}
begin
	tmaclocalprocparam3a_q
end;
{$pop}

{ Case tmaclocalprocparam3d.pas }
{$push}
{$modeswitch nestedprocvars}
begin
	tmaclocalprocparam3d_q
end;
{$pop}

{ Case tmaclocalprocparam4e.pas }
{$push}
{$modeswitch nestedprocvars}
begin
  if tmaclocalprocparam4e_pp(6)<>12 then
    halt(1);
end;
{$pop}

end.
