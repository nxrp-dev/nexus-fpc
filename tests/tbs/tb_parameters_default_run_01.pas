{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_parameters_default_run_01.pas }
{$push}

{ Case tb0010.pas }
{$push}
{ Old file: tbs0013.pas }
{  }

procedure tb0010_test(w : word);

  begin
  end;
{$pop}

{ Case tb0214.pas }
{$push}
{ Old file: tbs0253.pas }
{ problem with overloaded procedures and forward       OK 0.99.11 (PFV) }

procedure tb0214_test(w : word);forward;

procedure tb0214_test(a : string);
begin
   Writeln(a);
   tb0214_test(20);
end;

procedure tb0214_test(w :word);
begin
   writeln(w);
end;
{$pop}

{ Case tb0232.pas }
{$push}
{ Old file: tbs0272.pas }
{ No error issued if wrong parameter in function inside a second function OK 0.99.13 (PFV) }

function tb0232_astring(tb0232_s :string) : string;

begin
  tb0232_astring:='Test string'+tb0232_s;
end;

procedure tb0232_testvar(var tb0232_s : string);
begin
  writeln('testvar s is "',tb0232_s,'"');
end;

procedure tb0232_testconst(const tb0232_s : string);
begin
  writeln('testconst s is "',tb0232_s,'"');
end;

procedure tb0232_testvalue(tb0232_s : string);
begin
  writeln('testvalue s is "',tb0232_s,'"');
end;

const
  tb0232_s : string = 'test';
  tb0232_conststr = 'Const test';
{$pop}

{ Case tb0476.pas }
{$push}
const
  tb0476_e = 'as';

procedure tb0476_p(const tb0476_p);
  begin
    if pchar(@tb0476_p)^<>'a' then
      begin
        writeln('error');
        halt(1);
      end;
  end;
{$pop}

{ Case tb0470.pas }
{$push}
procedure tb0470_proc1(p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20 : longint);
  begin
  end;

procedure tb0470_proc2;
  var
    tb0470_l : dword;
  begin
    tb0470_l:=$deadbeef;
    tb0470_proc1(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20);
    if tb0470_l<>$deadbeef then
      begin
        writeln('error');
        halt(1);
      end;
  end;
{$pop}


{$pop}

{ Source group: tb_nested_routines_default_run_01.pas }
{$push}

{ Case tb0014.pas }
{$push}
{ Old file: tbs0017.pas }
{  }

const
      tb0014_nextoptpass : longint = 0;
  procedure tb0014_init;

    const
       tb0014_endofparas : boolean = false;

    procedure tb0014_getparastring;

      procedure tb0014_nextopt;

        begin
           tb0014_endofparas:=true;
           tb0014_getparastring;
           inc(tb0014_nextoptpass);
           tb0014_init;
        end;

      begin
       if not tb0014_endofparas then
         tb0014_nextopt;
      end;

    begin
         tb0014_getparastring;
    end;
{$pop}

{ Case tb0314.pas }
{$push}
{ this program shows a possible problem
  of name mangling in FPC  (PM) }
  procedure tb0314_test;

    function tb0314_a : longint;
      begin
         tb0314_a:=1;
      end;

    begin
       writeln('a = ',tb0314_a);
    end;

  procedure tb0314_test(tb0314_b : byte);

    function tb0314_a : longint;
      begin
         tb0314_a:=2;
      end;

    begin
       writeln('b = ',tb0314_b);
       writeln('a = ',tb0314_a);
    end;

  type tb0314_a = word;

  function tb0314_test_(tb0314_b : tb0314_a) : longint;
    begin
      tb0314_test_:=tb0314_b;
    end;
{$pop}


{$pop}

{ Source group: tb_function_results_default_run_01.pas }
{$push}

{ Case tb0044.pas }
{$push}
{ Old file: tbs0050.pas }
{  can't set a function result in a nested procedure of a function OK 0.99.7 (PM) }

function tb0044_append : Boolean;

      procedure tb0044_doappend;
        begin
           tb0044_append := true;
        end;

begin
   tb0044_append:=False;
   tb0044_doappend;
end;
{$pop}

{ Case tb0103.pas }
{$push}
{ Old file: tbs0122.pas }
{ exit() gives a warning that the result is not set     OK 0.99.6 (FK) }


function tb0103_f:longint;
begin
  exit(1);
end;
{$pop}

{ Case tb0256.pas }
{$push}
{ Old file: tbs0296.pas }
{ exit(string) does not work (web form bugs 613)        OK 0.99.13 (PM) }


function tb0256_test : string;

  begin
    tb0256_test:='This should not be printed';
    exit('this should be printed');
  end;
{$pop}

{ Case tb0416.pas }
{$push}
function tb0416_f: string;

  procedure tb0416_t;
    begin
      tb0416_f := 'test';
    end;

begin
  tb0416_t;
end;
{$pop}


{$pop}

{ Source group: tb_argument_casts_default_run_01.pas }
{$push}

{ Case tb0159.pas }
{$push}
{ Old file: tbs0190.pas }
{ can't have typecast for var params ??                 OK 0.99.11 (PM) }

procedure tb0159_a(var tb0159_b: boolean);
begin
  tb0159_b:=true;
end;

var tb0159_c: byte;
{$pop}

{ Case tb0289.pas }
{$push}
{ Old file: tbs0341.pas }
{  }

procedure IncLimit(var tb0289_b: Byte; const Limit: Byte; const Incr: Byte);
begin
end;
procedure IncLimit(var tb0289_b: Longint; const Limit: Longint; const Incr: Longint);
begin
end;

var
  tb0289_b : byte;
{$pop}

{ Case tb0352.pas }
{$push}
procedure p(var tb0352_w:word);
begin
end;

var
  tb0352_i : smallint;
{$pop}


{$pop}

{ Source group: tb_procedural_values_default_run_01.pas }
{$push}

{ Case tb0028.pas }
{$push}
{ Old file: tbs0032.pas }
{  tests for a bugs with the stack                      OK 0.9.9 }

var
   tb0028_p : procedure(w : word);

  procedure tb0028_pp(w :word);
    begin
       Writeln(w);
    end;
{$pop}

{ Case tb0158.pas }
{$push}
{ Old file: tbs0189.pas }
{ cant compare addresses of function variables !! As tbs0188 FPC syntax problem see source (PM) }

var tb0158_m: procedure;

procedure tb0158_test;
begin
end;

procedure tb0158_test2;
begin
end;
{$pop}

{ Case tb0163.pas }
{$push}
{ Old file: tbs0194.pas }
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

{ Case tb0434.pas }
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

{ Case tb0157.pas }
{$push}
{ Old file: tbs0188.pas }
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

{ Case tb0385.pas }
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

{ Case tb0509.pas }
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


{$pop}

begin
  { Source group: tb_parameters_default_run_01.pas }
  {$push}


begin
  { Case tb0010.pas }
  {$push}
begin
   tb0010_test(1234);
end;
  {$pop}

  { Case tb0214.pas }
  {$push}
begin
  tb0214_test('test');
  tb0214_test(32);
end;
  {$pop}

  { Case tb0232.pas }
  {$push}
begin
  tb0232_testvalue(tb0232_astring('e'));
  tb0232_testconst(tb0232_astring(tb0232_s));
  tb0232_testconst(tb0232_conststr);
end;
  {$pop}

  { Case tb0476.pas }
  {$push}
begin
  tb0476_p(tb0476_e[1]);
end;
  {$pop}

  { Case tb0470.pas }
  {$push}
begin
  tb0470_proc2;
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_nested_routines_default_run_01.pas }
  {$push}


begin
  { Case tb0014.pas }
  {$push}
begin
   tb0014_init;
   if tb0014_nextoptpass<>1 then Halt(1);
end;
  {$pop}

  { Case tb0314.pas }
  {$push}
begin
   tb0314_test(1);
   tb0314_test;
   tb0314_test(4);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_function_results_default_run_01.pas }
  {$push}


begin
  { Case tb0044.pas }
  {$push}
begin
  If not tb0044_append then
    begin
       Writeln('TBS0050 fails');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0103.pas }
  {$push}
begin
  writeln(tb0103_f);
end;
  {$pop}

  { Case tb0256.pas }
  {$push}
begin
  writeln(tb0256_test);
  if tb0256_test<>'this should be printed' then
    Halt(1);
end;
  {$pop}

  { Case tb0416.pas }
  {$push}
begin
  if tb0416_f <> 'test' then
    begin
      writeln('error!');
      halt(1);
    end;
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_argument_casts_default_run_01.pas }
  {$push}


begin
  { Case tb0159.pas }
  {$push}
begin
  tb0159_a(boolean(tb0159_c));
end;
  {$pop}

  { Case tb0289.pas }
  {$push}
begin
  inclimit(tb0289_b,128,3);
end;
  {$pop}

  { Case tb0352.pas }
  {$push}
begin
  p(word(tb0352_i));
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_procedural_values_default_run_01.pas }
  {$push}


begin
  { Case tb0028.pas }
  {$push}
begin
   tb0028_p:=@tb0028_pp;
   tb0028_p(1234);
end;
  {$pop}

  { Case tb0158.pas }
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

  { Case tb0163.pas }
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

  { Case tb0434.pas }
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

  { Case tb0157.pas }
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

  { Case tb0385.pas }
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

  { Case tb0509.pas }
  {$push}
begin
  tb0509_f:=nil;
  if assigned(tb0509_f) then
    tb0509_p(tb0509_f);
end;
  {$pop}


end;
  {$pop}

end.
