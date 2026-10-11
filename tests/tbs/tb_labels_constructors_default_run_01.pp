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

end.
