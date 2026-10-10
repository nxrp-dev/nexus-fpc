{ Procedure-variable calls and routine address comparisons. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0028.pp }
{$push}
{ Old file: tbs0032.pp }
{  tests for a bugs with the stack                      OK 0.9.9 }

var
   tb0028_p : procedure(w : word);

  procedure tb0028_pp(w :word);
    begin
       Writeln(w);
    end;
{$pop}

{ Case tb0158.pp }
{$push}
{ Old file: tbs0189.pp }
{ cant compare addresses of function variables !! As tbs0188 FPC syntax problem see source (PM) }

var tb0158_m: procedure;

procedure tb0158_test;
begin
end;

procedure tb0158_test2;
begin
end;
{$pop}

{ Case tb0163.pp }
{$push}
{ Old file: tbs0194.pp }
{ @procedure var returns value in it instead of address !! OK 0.99.11 (PM) }

{$Q+}

type
   tb0163_tproc = function : longint;

var
   tb0163_f : tb0163_tproc;
   tb0163_fa : array [0..1] of tb0163_tproc;

   function tb0163_dummy : longint;
     begin
        tb0163_dummy:=25;
     end;
const
   tb0163_prog_has_errors : boolean = false;

   procedure tb0163_wrong(const s : string);
     begin
        writeln(s);
        tb0163_prog_has_errors:=True;
     end;
{$pop}

{ Case tb0434.pp }
{$push}
function tb0434_dummy : longint;
begin
  tb0434_dummy:=1;
end;

var
 tb0434_x:function:longint;
 tb0434_x2:function:longint;
 tb0434_y:pointer absolute tb0434_x;
 tb0434_y2:pointer absolute tb0434_x2;
{$pop}

{ Case tb0157.pp }
{$push}
{ Old file: tbs0188.pp }
{ can't print function result of procedural var that returns a function. Not a bugs : wrong syntax !! See source (PM) }

{ this are no bugs, just wrong
  understanding of FPC syntax }

type tb0157_testfunc = function:longint;

var tb0157_f : tb0157_testfunc;

var tb0157_test: tb0157_testfunc;

function tb0157_test_temp: longint;
begin
  tb0157_test_temp:=12;
end;

procedure tb0157_sound(tb0157_test: tb0157_testfunc);
begin
  {writeln(test); this is wrong because
   test is the function itself and write does not know how to
   output a function !
   to call test you must use test() !! }
  writeln(tb0157_test());
end; { proc. sound }

var tb0157_i : longint;
{$pop}

{ Case tb0385.pp }
{$push}
var
  tb0385_count : longint;

procedure tb0385_p1(w:word);overload;
begin
  writeln('word');
  tb0385_count:=tb0385_count or 1;
end;

procedure tb0385_p1(l:longint);overload;
begin
  writeln('longint');
  tb0385_count:=tb0385_count or 2;
end;

var
  tb0385_f1 : procedure(l:longint);
  tb0385_f2 : procedure(w:word);
{$pop}

{ Case tb0509.pp }
{$push}
type
  tb0509_tp1 = function(var i : longint) : longint;

  tb0509_tp2 = type tb0509_tp1;

procedure tb0509_p(tb0509_f : tb0509_tp1);
  begin
  end;


procedure tb0509_p(tb0509_f : tb0509_tp2);
  begin
  end;

var
  tb0509_f : tb0509_tp1;
{$pop}

begin
  { Case tb0028.pp }
  {$push}
begin
   tb0028_p:=@tb0028_pp;
   tb0028_p(1234);
end;
  {$pop}

  { Case tb0158.pp }
  {$push}
begin
 if @tb0158_test <> @tb0158_test2 then
   writeln('different!')
 else
   writeln('error');
 tb0158_m:=@tb0158_test;

 { here also the syntax was wrong !! }
 {  @m <> @test have different types !! }
 if tb0158_m <> @tb0158_test then
   writeln('error');
end;
  {$pop}

  { Case tb0163.pp }
  {$push}
{$Q+}
Begin
   tb0163_f:=@tb0163_dummy;
   if tb0163_f()<>25 then
     tb0163_wrong('f() does not call dummy !!');
   if pointer(@tb0163_f)=codepointer(@tb0163_dummy) then
     tb0163_wrong('@f returns value of f !');
   if longint(tb0163_f)=longint(@tb0163_f) then
     tb0163_wrong('longint(@f)=longint(f) !!!!');
   if tb0163_f<>@tb0163_dummy then
     tb0163_wrong('f does not return the address of dummy');
   if longint(@tb0163_f)=longint(@tb0163_dummy) then
     tb0163_wrong('longint(@f) returns address of dummy instead of address of f');
   tb0163_fa[0]:=@tb0163_dummy;
   if longint(@tb0163_f)=longint(@tb0163_fa[0]) then
     tb0163_wrong('arrays of procvar also wrong');
   if longint(tb0163_f)<>longint(tb0163_fa[0]) then
     tb0163_wrong('arrays of procvar and procvars are handled differently !!');
   if tb0163_prog_has_errors then
     Halt(1);
End;
  {$pop}

  { Case tb0434.pp }
  {$push}
begin
  tb0434_x2:=@tb0434_dummy;
  if (tb0434_y<>nil) or (tb0434_y2<>pointer(@tb0434_dummy)) then
   begin
     Writeln('Wrong code generated for absolute to procvarsmy');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0157.pp }
  {$push}
begin
  tb0157_i:=tb0157_test_temp;
  tb0157_f:=@tb0157_test_temp;
  if tb0157_f()<>tb0157_i then
    begin
       Writeln('error calling f');
       Halt(1);
    end;

  { this works for FPC
   sound(test_temp);
  but the correct syntax would be }
  tb0157_sound(@tb0157_test_temp);
  { imagine if a function would return its own type !! }

  { for f var this is correct also ! }
  tb0157_sound(tb0157_f);
end;
  {$pop}

  { Case tb0385.pp }
  {$push}
begin
  tb0385_f1:=@tb0385_p1;
  tb0385_f2:=@tb0385_p1;
  tb0385_f1(1);
  tb0385_f2(1);
  if tb0385_count<>3 then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0509.pp }
  {$push}
begin
  tb0509_f:=nil;
  if assigned(tb0509_f) then
    tb0509_p(tb0509_f);
end;
  {$pop}

end.
