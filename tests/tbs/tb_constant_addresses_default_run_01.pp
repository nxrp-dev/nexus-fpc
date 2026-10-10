{ Constant pointer casts and addresses of record and string elements. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0143.pp }
{$push}
{ Old file: tbs0171.pp }
{ missing typecasting in constant expression solved for pointers                                   OK 0.99.11 (PM) }

type
  tb0143_pstring=^string;
const
  tb0143_drivestr:string='c:';
  tb0143_pdrivestr:tb0143_pstring=tb0143_pstring(@tb0143_drivestr);
{$pop}

{ Case tb0160.pp }
{$push}
{ Old file: tbs0191.pp }
{ missing vecn constant evaluation                      OK 0.99.11 (PM) }

type
  tb0160_trec=record
   tb0160_a,tb0160_b : longint;
  end;
  tb0160_prec=^tb0160_trec;

const
  tb0160_s  : shortstring = 'test';

  tb0160_cfg : array[1..2] of tb0160_trec=(
   (tb0160_a:1;tb0160_b:2),
   (tb0160_a:3;tb0160_b:4)
  );
  tb0160_pcfg : tb0160_prec = @tb0160_cfg[2];

  tb0160_l : ^longint = @tb0160_cfg[1].tb0160_b; { l^ should be 2 }

  tb0160_pc : pchar = @tb0160_s[1];
{$pop}

begin
  { Case tb0143.pp }
  {$push}
begin
  if tb0143_pdrivestr^<>'c:' then
    begin
       Writeln('Error in typecast of const');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0160.pp }
  {$push}
begin
  Writeln(' l^ = ',tb0160_l^);
  Writeln('pc[0] = ',tb0160_pc[0]);
  if (tb0160_l^<>2) or (tb0160_pc[0]<>'t') then
    Begin
       Writeln('Wrong code generated');
       RunError(1);
    End;
end;
  {$pop}

end.
