{ Character literals, comparisons, sized strings and ordinal/Boolean conversions. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0242.pp }
{$push}
{ Old file: tbs0283.pp }
{ bugs in constant char comparison evaluation           OK 0.99.13 (PFV) }

const tb0242_dirsep = '\';
{$pop}

{ Case tb0245.pp }
{$push}
{ Old file: tbs0286.pp }
{ #$08d not allowed as Char constant                   OK 0.99.13 (PFV) }

var
  tb0245_c : char;
{$pop}

{ Case tb0315.pp }
{$push}
{ test for const string that is a char }

const
    tb0315_c ='D';
    tb0315_d = 'AD';
    tb0315_pp : string[length(tb0315_d)] = tb0315_d;
    tb0315_p : String[length(tb0315_c)] = tb0315_c;
{$pop}

{ Case tb0337.pp }
{$push}
var
  tb0337_s : string;
{$pop}

{ Case tb0353.pp }
{$push}
const
      tb0353_c1 = widechar(0);
      tb0353_c2 = widechar(#0);
      tb0353_c3 = #123;
      tb0353_c4 = #1234;
{$pop}

{ Case tb0381.pp }
{$push}
var
   tb0381_w : widechar;
{$pop}

{ Case tb0187.pp }
{$push}
{ Old file: tbs0221.pp }
{ syntax parsing incompatibilities with tp7            OK 0.99.11 (PFV) }


var
  tb0187_r : double;
  tb0187_c : char;
{$pop}

{ Case tb0294.pp }
{$push}
{ Old file: tbs0350.pp }
{  }

var
  tb0294_c : char;
  tb0294_i : integer;
{$pop}

{ Case tb0401.pp }
{$push}
var
   tb0401_b1,tb0401_b2 : boolean;
   tb0401_c : char;
{$pop}

begin
  { Case tb0242.pp }
  {$push}
begin
  if tb0242_dirsep = '/'
    then
      begin
        writeln('bug!');
        Halt(1);
      end
    else
      writeln('ok');
end;
  {$pop}

  { Case tb0245.pp }
  {$push}
begin
  tb0245_c:=#$08d;
end;
  {$pop}

  { Case tb0315.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0337.pp }
  {$push}
begin
  tb0337_s:={$ifdef fpc}'~[v]~'{$else}'~['#25']~'{$endif};
end;
  {$pop}

  { Case tb0353.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0381.pp }
  {$push}
begin
   case tb0381_w of
      'A' : ;
      'B' : ;
      #1234: ;
      #8888: ;
      #8889..#9999: ;
      'Z'..'a': ;
   end;
end;
  {$pop}

  { Case tb0187.pp }
  {$push}
begin
  tb0187_r:=1.;
  tb0187_c:=^.; { this compile in tp7, c should contain 'n'/#110 }
  if tb0187_c<>#110 then
    begin
       Writeln('FPC does not support ^. character!');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0294.pp }
  {$push}
begin
  tb0294_i:=integer(tb0294_c);
  tb0294_c:=char(tb0294_i);
end;
  {$pop}

  { Case tb0401.pp }
  {$push}
begin
   tb0401_b1:=false;
   tb0401_b2:=true;
   tb0401_c:=char(tb0401_b1 and tb0401_b2);
   if tb0401_c<>#0 then
     halt(1);
   tb0401_c:=char(tb0401_b1 or tb0401_b2);
   if tb0401_c<>#1 then
     halt(1);
   tb0401_c:=char(tb0401_b1);
   if tb0401_c<>#0 then
     halt(1);
   tb0401_c:=char(tb0401_b2);
   if tb0401_c<>#1 then
     halt(1);
end;
  {$pop}

end.
