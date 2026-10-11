{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tint2str1.pp }
{$push}


procedure tint2str1_test2(c1,c2,c3,c4: char);
begin
  if (c1 <> 'a') or (c2 <> 'b') or (c3 <> 'c') or (c4 <> 'd') then
    halt(2);
end;


var
  tint2str1_l: longint;

{$pop}

{ Case tmaclocalprocparam2.pp }
{$push}



  procedure tmaclocalprocparam2_p1( procedure pp( pi: longint); i: longint);
  begin
    pp( i)
  end;

  procedure tmaclocalprocparam2_p2( procedure pp( pi: longint); i: longint);
  begin
    tmaclocalprocparam2_p1( pp, i)
  end;

  procedure tmaclocalprocparam2_n( ri: longint);
  begin
    if ri = 1 then
      writeln( 'success for n')
    else
      begin
        writeln( 'fail');
        halt( 1)
      end
   end;

  procedure tmaclocalprocparam2_q;
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
    tmaclocalprocparam2_p1( r, qi);
    tmaclocalprocparam2_p2( r, qi);
    tmaclocalprocparam2_p1( tmaclocalprocparam2_n, qi);
    tmaclocalprocparam2_p2( tmaclocalprocparam2_n, qi);
  end;


{$pop}

{ Case tmaclocalprocparam2c.pp }
{$push}



type
  tmaclocalprocparam2c_tnestedprocvar = procedure ( pi: longint) is nested;

  procedure tmaclocalprocparam2c_p1(pp: tmaclocalprocparam2c_tnestedprocvar ; i: longint);
  begin
    pp( i)
  end;

  procedure tmaclocalprocparam2c_p2(pp: tmaclocalprocparam2c_tnestedprocvar ; i: longint);
  begin
    tmaclocalprocparam2c_p1( pp, i)
  end;

  procedure tmaclocalprocparam2c_n( ri: longint);
  begin
    if ri = 1 then
      writeln( 'success for n')
    else
      begin
        writeln( 'fail');
        halt( 1)
      end
   end;

  procedure tmaclocalprocparam2c_q;
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
    tmaclocalprocparam2c_p1( r, qi);
    tmaclocalprocparam2c_p2( r, qi);
    tmaclocalprocparam2c_p1( tmaclocalprocparam2c_n, qi);
    tmaclocalprocparam2c_p2( tmaclocalprocparam2c_n, qi);
  end;


{$pop}

{ Case tmaclocalprocparam2f.pp }
{$push}



type
  tmaclocalprocparam2f_tnestedprocvar = procedure ( pi: longint) is nested;

  procedure tmaclocalprocparam2f_p1(pp: tmaclocalprocparam2f_tnestedprocvar ; i: longint);
  begin
    pp( i)
  end;

  procedure tmaclocalprocparam2f_p2(pp: tmaclocalprocparam2f_tnestedprocvar ; i: longint);
  begin
    tmaclocalprocparam2f_p1( pp, i)
  end;

  procedure tmaclocalprocparam2f_n( ri: longint);
  begin
    if ri = 1 then
      writeln( 'success for n')
    else
      begin
        writeln( 'fail');
        halt( 1)
      end
   end;

  procedure tmaclocalprocparam2f_q;
  var qi: longint;

    procedure r( ri: longint);
      var
        si: longint;

      procedure g( ri: longint);
        begin
          if qi = ri then
            writeln( 'success for g')
          else
            begin
              writeln( 'fail');
              halt( 1)
           end
        end;

      begin
        si:=ri;
        tmaclocalprocparam2f_p1( g, qi);
        tmaclocalprocparam2f_p2( g, qi);
        tmaclocalprocparam2f_p1( g, qi);
        tmaclocalprocparam2f_p2( g, qi);
      end;

  begin
    qi:= 1;
    r(qi);
  end;


{$pop}

{ Case tmaclocalprocparam3.pp }
{$push}



  procedure tmaclocalprocparam3_p1( procedure pp);
  begin
    pp
  end;

  procedure tmaclocalprocparam3_p2( procedure pp);
  begin
    tmaclocalprocparam3_p1( pp)
  end;

  procedure tmaclocalprocparam3_n;
  begin
    writeln( 'calling through n')
  end;

  procedure tmaclocalprocparam3_q;
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
    tmaclocalprocparam3_p1( r);
    tmaclocalprocparam3_p2( r);
    tmaclocalprocparam3_p1( tmaclocalprocparam3_n);
    tmaclocalprocparam3_p2( tmaclocalprocparam3_n);
  end;


{$pop}

{ Case tmaclocalprocparam3c.pp }
{$push}



type
  tmaclocalprocparam3c_tnestedprocvar = procedure is nested;

var
  tmaclocalprocparam3c_tempp: tmaclocalprocparam3c_tnestedprocvar;

  procedure tmaclocalprocparam3c_p1( pp: tmaclocalprocparam3c_tnestedprocvar);
  begin
    tmaclocalprocparam3c_tempp:=pp;
    tmaclocalprocparam3c_tempp
  end;

  procedure tmaclocalprocparam3c_p2( pp: tmaclocalprocparam3c_tnestedprocvar);
  var
    localpp: tmaclocalprocparam3c_tnestedprocvar;
  begin
    localpp:=pp;
    tmaclocalprocparam3c_p1( localpp)
  end;

  procedure tmaclocalprocparam3c_n;
  begin
    writeln( 'calling through n')
  end;

  procedure tmaclocalprocparam3c_q;
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
    tmaclocalprocparam3c_p1( r);
    tmaclocalprocparam3c_p2( r);
    tmaclocalprocparam3c_p1( tmaclocalprocparam3c_n);
    tmaclocalprocparam3c_p2( tmaclocalprocparam3c_n);
  end;


{$pop}

{ Case tmacpas3.pp }
{$push}


{Test of anonymous procedure parameters}

function tmacpas3_AA1 (i: Integer; function BB (a: Integer): Integer ): Integer;
begin
  tmacpas3_AA1:= BB(i);
end;

function tmacpas3_CC1 (a: Integer): Integer;
begin
  Writeln('Inside CC1, param is ', a);
  tmacpas3_CC1:= a+a;
end;

var
  tmacpas3_res: Integer;

procedure tmacpas3_AA2 (i: Integer; procedure BB (a: Integer));
begin
  BB(i);
end;

procedure tmacpas3_CC2 (a: Integer);
begin
  Writeln('Inside CC2, param is ', a);
  tmacpas3_res:= a+a;
end;


{$pop}

begin

{ Case tint2str1.pp }
{$push}

begin
  tint2str1_l := 'abcd';
  tint2str1_test2(char(tint2str1_l shr 24),char(tint2str1_l shr 16),char(tint2str1_l shr 8),char(tint2str1_l));
end;
{$pop}

{ Case tmaclocalprocparam2.pp }
{$push}

begin
    tmaclocalprocparam2_q
end;
{$pop}

{ Case tmaclocalprocparam2c.pp }
{$push}

begin
    tmaclocalprocparam2c_q
end;
{$pop}

{ Case tmaclocalprocparam2f.pp }
{$push}

begin
    tmaclocalprocparam2f_q
end;
{$pop}

{ Case tmaclocalprocparam3.pp }
{$push}

begin
	tmaclocalprocparam3_q
end;
{$pop}

{ Case tmaclocalprocparam3c.pp }
{$push}

begin
	tmaclocalprocparam3c_q
end;
{$pop}

{ Case tmacpas3.pp }
{$push}

begin
  tmacpas3_res:= 0;
  tmacpas3_res:= tmacpas3_AA1(42, tmacpas3_CC1);
  if tmacpas3_res <> 84 then
    Halt(1);

  tmacpas3_AA2(27, tmacpas3_CC2);
  if tmacpas3_res <> 54 then
    Halt(1);
end;
{$pop}

end.
