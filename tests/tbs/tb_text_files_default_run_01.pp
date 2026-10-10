{ Text-file binary casts, disabled I/O checks and TextFile assignment. }
{ Original case IDs and variable scopes are retained below. }

uses Dos; { For TextRec and FileRec }

{ Case tb0084.pp }
{$push}
{ Old file: tbs0098.pp }
{ File type casts are not allowed (works in TP7)        OK 0.99.1 (FK) }

{ Show how to seek to an OFFSET (not a line number) in a textfile, }
{ without using asm. Arne de Bruijn, 1994, PD }
var
 tb0084_f:text;
 tb0084_l:longint;
 tb0084_s:string;
{$pop}

{ Case tb0190.pp }
{$push}
{ Old file: tbs0224.pp }
{ I/O-Error generation in readln can't be switched off OK 0.99.11 (PFV) }


var tb0190_f:text;
    tb0190_i:integer;
{$pop}

{ Case tb0365.pp }
{$push}
var
   tb0365_t : textfile;
{$pop}

{ Case tb0317.pp }
{$push}
const
  tb0317_exceptioncount = 18;
  tb0317_exception_names : array[0..tb0317_exceptioncount-1] of pchar = (
   'Division by Zero',
   'Debug',
   'NMI',
   'Breakpoint',
   'Overflow',
   'Bounds Check',
   'Invalid Opcode',
   'Coprocessor not available',
   'Double Fault',
   'Coprocessor overrun',
   'Invalid TSS',
   'Segment Not Present',
   'Stack Fault',
   'General Protection Fault',
   'Page fault',
   ' ',
   'Coprocessor Error',
   'Alignment Check');

    tb0317_single_pchar : pchar = 'Alone test';

const tb0317_filename  = 'ts010022.tmp';

var tb0317_en : pchar;
    tb0317_f : text;
    tb0317_st : string;
{$pop}

begin
  { Case tb0084.pp }
  {$push}
begin
 { Create temp }
 assign(tb0084_f,'tb0084.tmp');           { Assign F to itself }
 rewrite(tb0084_f);
 for tb0084_l:=1 to 100 do
   writeln('Hello world');
 close(tb0084_f);

 assign(tb0084_f,'tb0084.tmp');           { Assign F to itself }
 reset(tb0084_f);                             { Open it (as a textfile) }
 ReadLn(tb0084_f);                            { Just read some lines }
 ReadLn(tb0084_f);
 ReadLn(tb0084_f);
 FileRec((@tb0084_f)^).Mode:=fmInOut;         { Set to binary mode }
  { (The (@F)^ part is to let TP 'forget' the type of the structure, so }
  {  you can type-caste it to everything (note that with and without (@X)^ }
  {  can give a different value, longint(bytevar) gives the same value as }
  {  bytevar, while longint((@bytevar)^) gives the same as }
  {  longint absolute Bytevar (i.e. all 4 bytes in a longint are readed }
  {  from memory instead of 3 filled with zeros))) }
 FileRec((@tb0084_f)^).RecSize:=1;            { Set record size to 1 (a byte)}
 tb0084_l:=(FilePos(File((@tb0084_f)^))-TextRec(tb0084_f).BufEnd)+TextRec(tb0084_f).BufPos;
{... This line didn't work the last time I tried, it chokes on the "File"
typecasting thing.}

  { Get the fileposition, subtract the already readed buffer, and add the }
  { position in that buffer }
 TextRec(tb0084_f).Mode:=fmInput;             { Set back to text mode }
 TextRec(tb0084_f).BufSize:=SizeOf(TextBuf);  { BufSize overwritten by RecSize }
                                       { Doesn't work with SetTextBuf! }
 ReadLn(tb0084_f,tb0084_s);                          { Read the next line }
 WriteLn('Next line:',tb0084_s);              { Display it }
 FileRec((@tb0084_f)^).Mode:=fmInOut;         { Set to binary mode }
 FileRec((@tb0084_f)^).RecSize:=1;            { Set record size to 1 (a byte)}
 Seek(File((@tb0084_f)^),tb0084_l);                  { Do the seek }
{... And again here.}

 TextRec(tb0084_f).Mode:=fmInput;             { Set back to text mode }
 TextRec(tb0084_f).BufSize:=SizeOf(TextBuf);  { Doesn't work with SetTextBuf! }
 TextRec(tb0084_f).BufPos:=0; TextRec(tb0084_f).BufEnd:=0; { Reset buffer counters }
 ReadLn(tb0084_f,tb0084_s);                          { Show that it worked, the same }
 WriteLn('That line again:',tb0084_s);        { line readed again! }
 Close(tb0084_f);                             { Close it }
 Erase(tb0084_f);
end;
  {$pop}

  { Case tb0190.pp }
  {$push}
begin
  assign(tb0190_f,'bug0224.txt');
  rewrite(tb0190_f);
  write(tb0190_f,'     ');
  reset(tb0190_f);
{$I-}
  readln(tb0190_f,tb0190_i);              { you can't avoid run-time error generation }
{$I+}
  if IOResult<>0 then
   writeln('error...');
{$I-}
  close(tb0190_f);
  erase(tb0190_f);
{$I+}
  if IOResult<>0 then;
end;
  {$pop}

  { Case tb0365.pp }
  {$push}
begin
   assign(tb0365_t,'test');
end;
  {$pop}

  { Case tb0317.pp }
  {$push}
begin
   assign(tb0317_f,tb0317_filename);
   rewrite(tb0317_f);
   tb0317_en:=tb0317_single_pchar;
   Writeln(tb0317_f,tb0317_en);
   tb0317_en:=tb0317_exception_names[6];
   writeln(tb0317_f,tb0317_en);
   close(tb0317_f);
   reset(tb0317_f);
   readln(tb0317_f,tb0317_st);
   if tb0317_st<>'Alone test' then halt(1);
   readln(tb0317_f,tb0317_st);
   if tb0317_st<>'Invalid Opcode' then halt(1);
   close(tb0317_f);
   erase(tb0317_f);
end;
  {$pop}

end.
