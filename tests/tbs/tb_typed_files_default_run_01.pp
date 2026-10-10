{ Typed-file block reads, string records, large records and ordinal writes. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0093.pp }
{$push}
{ Old file: tbs0111.pp }
{ blockread(typedfile,...) is not allowed in TP7 }

var
  tb0093_ft : text;
  tb0093_f : file of word;
  tb0093_i : word;
  tb0093_buf : shortstring;
{$pop}

{ Case tb0202.pp }
{$push}
{ Old file: tbs0238.pp }
{ Internal error 432645 (from Frank MCCormick, mailing list 24/2) OK 0.99.11 (PM) }

           {compiles under TPC - PPC386 gives internal error}

Type tb0202_str1=string[160];

var
   tb0202_fileof  :file of tb0202_str1;
   tb0202_lol   :array[1..8] of tb0202_str1;
   tb0202_nu,tb0202_n:integer;
   tb0202_i,tb0202_tt    :tb0202_str1;
   tb0202_ul   :text;
   tb0202_a: tb0202_str1;


procedure tb0202_test;


begin
   for tb0202_nu:=1 to 8 do read(tb0202_fileof,tb0202_lol[tb0202_nu]);
   writeln('File contents');
   for tb0202_nu:=4 to 8 do writeln(tb0202_lol[tb0202_nu]);
end;
{$pop}

{ Case tb0126.pp }
{$push}
{ Old file: tbs0145.pp }
{ typed files with huges records (needs filerec.size:longint) OK 0.99.7 (PFV) }

{$I+}
const
  tb0126_mb=512;
  tb0126_siz=1024*tb0126_mb;

type
  tb0126_buf=array[1..tb0126_siz] of byte;

var
  tb0126_fin,
  tb0126_fout : file of tb0126_buf;
  tb0126_b1,tb0126_a1 : tb0126_buf;
{$pop}

{ Case tb0466.pp }
{$push}
var
  tb0466_outf : file of byte;
  tb0466_w : word;
{$pop}

begin
  { Case tb0093.pp }
  {$push}
begin
  assign(tb0093_ft,'tbs0111.tmp');
  rewrite(tb0093_ft);
  for tb0093_i:=1 to 40 do
    Writeln(tb0093_ft,'Dummy text to test bug 111');
  close(tb0093_ft);
  assign(tb0093_f,'tbs0111.tmp');
  reset(tb0093_f);
  blockread(tb0093_f,tb0093_buf[1],127,tb0093_i);    { This is not allowed in BP7 }
  tb0093_buf[0]:=chr(tb0093_i*2);
  close(tb0093_f);
  writeln(tb0093_i);
  writeln(tb0093_buf);
  erase(tb0093_f);
end;
  {$pop}

  { Case tb0202.pp }
  {$push}
begin
  assign(tb0202_fileof,'tbs0238.tmp');
  rewrite(tb0202_fileof);
  tb0202_a:='dummy string !!';
  for tb0202_nu:=1 to 8 do write(tb0202_fileof,tb0202_a);
  close(tb0202_fileof);
  reset(tb0202_fileof);
  tb0202_test;
  close(tb0202_fileof);
  erase(tb0202_fileof);
end;
  {$pop}

  { Case tb0126.pp }
  {$push}
{$I+}
begin
  fillchar(tb0126_a1,sizeof(tb0126_a1),1);
  assign(tb0126_fout,'tmp.tmp');
  rewrite(tb0126_fout);
  write(tb0126_fout,tb0126_a1);
  close(tb0126_fout);

  assign(tb0126_fin,'tmp.tmp');
  reset(tb0126_fin);
  read(tb0126_fin,tb0126_b1);
  close(tb0126_fin);
  erase(tb0126_fin);
  if not tb0126_b1[512*tb0126_mb]=1 then
   begin
      writeln('data err');
      Halt(1);
   end;
end;
  {$pop}

  { Case tb0466.pp }
  {$push}
begin
   assign(tb0466_outf, 'tb0466.tmp');
   rewrite(tb0466_outf);
   {only explicit typecasting helps: byte(10)}
   write(tb0466_outf, 10);
   tb0466_w:=20;
   write(tb0466_outf, tb0466_w);
   close(tb0466_outf);
   erase(tb0466_outf);
end;
  {$pop}

end.
