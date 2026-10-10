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

end.
