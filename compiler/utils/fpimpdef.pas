{$APPTYPE CONSOLE}
program FPimpdef;
{$DEFINE STANDALONE}
uses
 DOS,
 ImpDef;
var
binname:string;
function Ofound(const short,full:string):LongInt;
var
  i:LongInt;
begin
  Ofound:=-1;
  for i:=1 to ParamCount do
   if(ParamStr(i)=short)or(ParamStr(i)=full)then
    begin
     Ofound:=i;
     exit;
    end;
end;
function GetOption(const short,full:string):string;
var
  i:LongInt;
begin
  i:=Ofound(short,full);
  if i>0 then
   GetOption:=ParamStr(succ(i))
  else
   GetOption:='';
end;
procedure help_info;
var
  fn:string[255];
  jj:cardinal;
begin
  fn:=ParamStr(0);
  for jj:=length(fn)downto 1 do
   if fn[jj] in [':','\','/']then
    begin
     fn:=copy(fn,succ(jj),255);
     break;
    end;
  WriteLn('Usage: ',fn,' [options]');
  WriteLn('Options:');
  WriteLn('-i | --input     <file> - set input file;');
  WriteLn('-o | --output    <file> - set output .def file');
  WriteLn('-l | --library   <file> - set output static library');
  WriteLn('-s | --assembler <name> - use <name> for assembler (default asw)');
  WriteLn('-r | --archiver  <name> - use <name> for archiver (default arw)');
  WriteLn('-h | --help             - show this screen');
  halt;
end;
{$ifndef UNIX}
procedure AddExt(var s:string);
 var
  s1:string;
  i:LongInt;
 begin
  s1:=copy(s,length(s)-3,4);
  for i:=1 to length(s1)do
   s1[i]:=upcase(s1[i]);
  if s1<>'.EXE'then
   s:=s+'.EXE';
 end;
{$endif}
var
 EnvPath:string;
begin
binname:=GetOption('-i','--input');
if(binname='')or(Ofound('-h','--help')>0)then
  help_info;
 as_name:=GetOption('-s','--assembler');
 if as_name='' then
  as_name:='as';
 ar_name:=GetOption('-r','--archiver');
 if ar_name='' then
  ar_name:='ar';
{$ifndef UNIX}
 AddExt(as_name);
 AddExt(ar_name);
{$endif}
 EnvPath:=GetEnv('Path');
 if EnvPath='' then
  EnvPath:=GetEnv('PATH');
 as_name:=FSearch(as_name,EnvPath);
 ar_name:=FSearch(ar_name,EnvPath);
if not makedef(binname,GetOption('-o','--output'),GetOption('-l','--library'))then
  begin
   WriteLn('Export names not found');
   halt(1);
  end;
end.
