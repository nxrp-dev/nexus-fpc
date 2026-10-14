{ Constant pointer casts and addresses of record and string elements. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0143.pas }
{$push}
{ Old file: tbs0171.pas }
{ missing typecasting in constant expression solved for pointers                                   OK 0.99.11 (PM) }

type
  tb0143_pstring=^string;
const
  tb0143_drivestr:string='c:';
  tb0143_pdrivestr:tb0143_pstring=tb0143_pstring(@tb0143_drivestr);
{$pop}

{ Case tb0160.pas }
{$push}
{ Old file: tbs0191.pas }
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

{ Case tb0152.pas }
{$push}
{ Old file: tbs0182.pas }
{ @record.field doesn't work in constant expr           OK 0.99.9 (PM) }

TYPE tb0152_rec = RECORD
             tb0152_x:WORD;
             tb0152_y:WORD;
           END;

     tb0152_rec1 = Record
            tb0152_x,tb0152_y : longint;
            end;
     tb0152_rec2 = Record
            tb0152_r,tb0152_s : tb0152_rec1;
            tb0152_z : word;
            end;
     tb0152_plongint = ^longint;

VAR tb0152_s:WORD;
    tb0152_r:tb0152_rec;
    tb0152_rr : tb0152_rec2;

CONST tb0152_p1:POINTER = @tb0152_s;    { Works fine }
      tb0152_p2:POINTER = @tb0152_r.tb0152_y;  { illegal expression }
      tb0152_p3:pointer = @tb0152_rr.tb0152_s.tb0152_y;
      tb0152_p4:tb0152_plongint = @tb0152_rr.tb0152_s.tb0152_y;
{$pop}

{ Case tb0323.pas }
{$push}
// checks type cast of nil in const statement
   type
      tb0323_thandle = longint;
      tb0323_wsaevent = tb0323_thandle;
   const
      tb0323_wsa_invalid_event = tb0323_wsaevent(nil);

   var
     tb0323_l : longint;
{$pop}

{ Case tb0348.pas }
{$push}
const
     tb0348_guid_null : TGUID = '{00000000-0000-0000-0000-000000000000}';
{$pop}

begin
  { Case tb0143.pas }
  {$push}
begin
  if tb0143_pdrivestr^<>'c:' then
    begin
       Writeln('Error in typecast of const');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0160.pas }
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

  { Case tb0152.pas }
  {$push}
BEGIN
   tb0152_rr.tb0152_s.tb0152_y:=15;
   if tb0152_plongint(tb0152_p3)^<>15 then
     Begin
        Writeln('Error : wrong code generated');
        Halt(1);
     End;
END;
  {$pop}

  { Case tb0323.pas }
  {$push}
begin
   tb0323_l:=tb0323_wsa_invalid_event*1;
end;
  {$pop}

  { Case tb0348.pas }
  {$push}
begin
end;
  {$pop}

end.
