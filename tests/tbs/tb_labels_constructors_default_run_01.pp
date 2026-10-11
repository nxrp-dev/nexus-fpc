{ %opt=-Sg }
{ Labels at block ends, unused labels and object constructor Fail semantics. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0031.pp }
{$push}
{ Old file: tbs0035.pp }
{  label at end of block gives error                   OK 0.9.9 (FK) }

{$goto on}

label   tb0031_hallo;
{$pop}

{ Case tb0148.pp }
{$push}
{ Old file: tbs0178.pp }
{ problems with undefined labels and fail outside constructor OK 0.99.9 (PM) }

 { this program compiles fine with TP but not with FP }

 type
    tb0148_ptestobj = ^tb0148_ttestobj;
    tb0148_ttestobj = object
            constructor init;
            procedure tb0148_test_self;
            end;

 const
    tb0148_allowed : boolean = false;

    constructor tb0148_ttestobj.init;
      begin
        if not tb0148_allowed then
          fail;
      end;
    procedure tb0148_ttestobj.tb0148_test_self;
      function tb0148_myself : tb0148_ptestobj;
        begin
           tb0148_myself:=@self;
        end;

      begin
         if tb0148_myself<>@self then
           begin
              Writeln('problem with self');
              Halt(1);
           end;
      end;


LABEL
  tb0148_n1,
  tb0148_n2,
  FAIL, { this is a reserved word in constructors only! - FP fails here
}
  tb0148_more; { label not defined - FP fails, but a warning is enough for that
}
           { since label referenced nowhere }
 var tb0148_ptest : tb0148_ptestobj;
     self : longint;
{$pop}

{ Case tb0393.pp }
{$push}
label 1;
{$pop}

{ Case tb0468a.pp }
{$push}
procedure tb0468a_foo;
begin
end;

procedure tb0468a_test;
label
  tb0468a_a,tb0468a_b,tb0468a_c,tb0468a_d;
const
  tb0468a_x: array[0..3] of pointer=(@tb0468a_a,@tb0468a_b,@tb0468a_c,@tb0468a_d);
begin
  tb0468a_foo;
tb0468a_a:
  tb0468a_foo;
tb0468a_b:
  tb0468a_foo;
tb0468a_c:
  tb0468a_foo;
tb0468a_d:
  tb0468a_foo;
end;
{$pop}

{ Case tb0507.pp }
{$push}
{$goto on}
{$inline on}

var
  tb0507_j : longint;

procedure tb0507_p1;inline;
  label tb0507_l;
  var
    tb0507_i:longint;
  begin
    tb0507_i:=0;
  tb0507_l:
    inc(tb0507_i);
    while tb0507_i<2 do
      begin
        goto tb0507_l;
        goto tb0507_l;
        goto tb0507_l;
      end;
  end;


procedure tb0507_p2;inline;
  label tb0507_l;
  begin
    goto tb0507_l;
    goto tb0507_l;
    goto tb0507_l;
  tb0507_l:
  end;


procedure tb0507_p3;inline;
  begin
    tb0507_j:=tb0507_j+1;
  end;
{$pop}

begin
  { Case tb0031.pp }
  {$push}
begin
   writeln('Hello');
  begin
tb0031_hallo:          {Error message: Incorrect expression.}
  end;
  writeln('Hello again');
end;
  {$pop}

  { Case tb0148.pp }
  {$push}
BEGIN
  new(tb0148_ptest,init);
  if tb0148_ptest<>nil then
    begin
       Writeln('Fail does not work !!');
       Halt(1);
    end;
  tb0148_allowed:=true;
  new(tb0148_ptest,init);
  if tb0148_ptest=nil then
    begin
       Writeln('Constructor does not work !!');
       Halt(1);
    end
  else
    tb0148_ptest^.tb0148_test_self;
  tb0148_n1: Write;
  tb0148_n2: Write;
  FAIL: Write;
  self:=1;
END;
  {$pop}

  { Case tb0393.pp }
  {$push}
begin
 goto 1;
1:
end;
  {$pop}

  { Case tb0468a.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0507.pp }
  {$push}
{$inline on}
begin
  tb0507_j:=0;
  tb0507_p1;
  tb0507_p1;
  tb0507_p1;
  tb0507_p1;
  tb0507_p2;
  tb0507_p2;
  tb0507_p2;
  tb0507_p2;
  tb0507_p3;
end;
  {$pop}

end.
