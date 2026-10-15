{ Consolidated files regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0312.pas }
{$push}
{ show a problem with IOCHECK !!
  inside reset(file)
  we call reset(file,longint)
  but we also emit a call to iocheck after and this is wrong !!  PM }


  var
      tb0312_ppfile : file;


{$pop}

{ Case tb0532.pas }
{$push}



{Append was the recommended way to open devices in TP.
 A pitfall is that you cannot seek to the end of a device.

 It has to work on modern platforms too, because:
  - Rewrite will destroy the device on platforms where devices are
    files.
  - Reset doesn't allow writing to the device.
}

{$I+}

var tb0532_null:text;


{$pop}

{ Case tb_typed_files_default_run_01.pas }
{$push}
{ Typed-file block reads, string records, large records and ordinal writes. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0093.pas }
{$push}
{ Old file: tbs0111.pas }
{ blockread(typedfile,...) is not allowed in TP7 }

var
  tb0093_ft : text;
  tb0093_f : file of word;
  tb0093_i : word;
  tb0093_buf : shortstring;
{$pop}

{ Case tb0202.pas }
{$push}
{ Old file: tbs0238.pas }
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

{ Case tb0126.pas }
{$push}
{ Old file: tbs0145.pas }
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

{ Case tb0466.pas }
{$push}
var
  tb0466_outf : file of byte;
  tb0466_w : word;
{$pop}


{$pop}

{ Case tw0896.pas }
{$push}

var
  tw0896_dat,tw0896_dat2 : file of byte;
  tw0896_j : longint;
  tw0896_Buffer,tw0896_Buffer2 : Array[0..2047] of byte;


{$pop}

{ Case tw1401.pas }
{$push}
{ Source provided for Free Pascal Bug Report 1401 }
{ Submitted by "Bill" on  2001-02-10 }
{ e-mail: lingolanguage@hotmail.com }

(*
Compiles using Delphi 4 (v12):
  dcc32 fpc5
Does not compile in FPC (1.0.4) using:
  ppc386 -Sd fpc5
*)



{
  uses sysutils,windows;
}

const tw1401_BUFMAX = 10;
      tw1401_CHSIZE = 1;
var tw1401_fFile:file;
    tw1401_buffer:string[10];
    tw1401_uiNumread:cardinal;

procedure tw1401_test;
begin
  (* don't run this! *)
  blockread (tw1401_fFile, tw1401_buffer, tw1401_BUFMAX*tw1401_CHSIZE, tw1401_uiNumread);
  blockread (tw1401_fFile, tw1401_buffer, cardinal(tw1401_BUFMAX*tw1401_CHSIZE), tw1401_uiNumread);
  blockwrite (tw1401_fFile, tw1401_buffer, tw1401_BUFMAX*tw1401_CHSIZE, tw1401_uiNumread);
  blockwrite (tw1401_fFile, tw1401_buffer, cardinal(tw1401_BUFMAX*tw1401_CHSIZE), tw1401_uiNumread);
end;


{$pop}

{ Case tw1744.pas }
{$push}
var  tw1744_outfile:text;
     tw1744_err:boolean;

{$pop}

{ Case tw23725.pas }
{$push}
var
  tw23725_t,tw23725_t1, tw23725_t2: text;
  tw23725_s: string;

{$pop}

{ Case tw3111.pas }
{$push}
var
  tw3111_Start : Cardinal;
  tw3111_Run,tw3111_Text: PWideChar;
  tw3111_RunLen: Cardinal;


{$pop}

begin

{ Case tb0312.pas }
{$push}

begin
{$ifndef macos}
       assign(tb0312_ppfile,'this_file_probably_does_not_exist&~"#');
{$else}
       {Max 32 chars in macos fielnames}
       assign(tb0312_ppfile,'this_file_probably_&~"#');
{$endif}

{$I-}
       reset(tb0312_ppfile,1);
       if ioresult=0 then
         begin
{$I+}
            close(tb0312_ppfile);
         end
       else
         writeln('the file does not exist') ;
{$I-}
       reset(tb0312_ppfile);
       if ioresult=0 then
         begin
{$I+}
            close(tb0312_ppfile);
         end
       else
         writeln('the file does not exist') ;
end;
{$pop}

{ Case tb0532.pas }
{$push}
{$I+}
begin
{$ifdef Unix}
  assign(tb0532_null,'/dev/null');
{$else}
  assign(tb0532_null,'NUL');
{$endif}
  append(tb0532_null);
  writeln(tb0532_null,'Text disappearing into the black hole.');
  close(tb0532_null);
end;
{$pop}

{ Case tb_typed_files_default_run_01.pas }
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$I+}
{$pop}
{$push}
{$pop}
begin
  { Case tb0093.pas }
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

  { Case tb0202.pas }
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

  { Case tb0126.pas }
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

  { Case tb0466.pas }
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

end;
{$pop}

{ Case tw0896.pas }
{$push}

begin
  for tw0896_j:=0 to 2047 do
    tw0896_Buffer[tw0896_j]:=tw0896_j and $ff;
  Assign(tw0896_dat,'tbug896.tmp');
  Rewrite(tw0896_dat,1);
  for tw0896_j:= 0 to 2047 do
    write (tw0896_dat,tw0896_Buffer[tw0896_j]);
  Close(tw0896_dat);
  Assign(tw0896_dat2,'tbug896a.tmp');
  Rewrite(tw0896_dat2);
  for tw0896_j:= 0 to 2047 do
    write (tw0896_dat2,tw0896_Buffer[tw0896_j]);
  Close(tw0896_dat2);
  Reset(tw0896_dat);
  Reset(tw0896_dat2,1);
  for tw0896_j:=0 to 2047 do
    begin
      read(tw0896_dat,tw0896_Buffer[tw0896_j]);
      read(tw0896_dat2,tw0896_Buffer2[tw0896_j]);
      if tw0896_Buffer[tw0896_j]<>tw0896_Buffer2[tw0896_j] then
        begin
          Writeln('Error in typed file handling');
          Halt(1);
        end;
    end;
  Close(tw0896_dat);
  close(tw0896_dat2);
  Erase(tw0896_dat);
  Erase(tw0896_dat2);
end;
{$pop}

{ Case tw1401.pas }
{$push}

begin
  Writeln('Test for cardinal version of blockread/blockwrite');
end;
{$pop}

{ Case tw1744.pas }
{$push}

begin
writeln('there should be three errors below:');

assign(tw1744_outfile,'notexist.fil');
{$i-}
Append(tw1744_outfile);
//rewrite(outfile);
{$i+}
//write(ioresult);  // 2 file not found
if IOResult <> 0 then writeln('err append')
else
 tw1744_err:=true;

{$i-}
writeln(tw1744_outfile,'----------------------');
{$i+}
//write(ioresult);   // 103 file not open
if IOResult <> 0 then writeln('err write')
else
 tw1744_err:=true;

{$i-}
close(tw1744_outfile);
{$i+}
//write(ioresult);  // 103 file not open
if IOResult <> 0 then writeln('err close')
else
 tw1744_err:=true;

   if tw1744_err then
     halt(1)
   else
     writeln('success');
end;
{$pop}

{ Case tw23725.pas }
{$push}

begin
  assign(tw23725_t,'tw23725.txt');
  rewrite(tw23725_t);
  writeln(tw23725_t);
  close(tw23725_t);
  assign(tw23725_t1, 'tw23725.txt'); assign(tw23725_t2, 'tw23725.txt');
  write('Opening 1... '); reset(tw23725_t1); writeln('done.');
  write('Opening 2... '); reset(tw23725_t2); writeln('done.');
  close(tw23725_t2); close(tw23725_t1);
  erase(tw23725_t1);
end;
{$pop}

{ Case tw3111.pas }
{$push}

begin
  tw3111_Start:=100;
  tw3111_Run:=nil;
  tw3111_Text:=tw3111_Run+10;
  tw3111_Start:=tw3111_Start+tw3111_Run-tw3111_Text;
  if tw3111_Start<>90 then
    begin
      writeln('error');
      halt(1);
    end;
end;
{$pop}

end.
