{ Objects regression cases; original case IDs are retained below. }

{ Case tw30015.pp }
{$push}
{$mode objfpc}

{$Inline On} // inline must be turned on for both methods
type
  tw30015_ttest = object // both methods must be inside of object
    procedure tw30015_modifyvalue(ValueModify: Int32); inline;
    procedure tw30015_setkey(const ValueConst: Int32); inline;
  end;

  procedure tw30015_ttest.tw30015_modifyvalue(ValueModify: Int32);
  begin
    ValueModify := 1;
  end;

  procedure tw30015_ttest.tw30015_setkey(const ValueConst: Int32);
  var
    tw30015_originalvalue: Int32;
  begin
    tw30015_originalvalue := ValueConst;
    tw30015_modifyvalue(ValueConst);
    WriteLn('Current Value: ', ValueConst); //Outputs 1
    WriteLn('Original Value: ', tw30015_originalvalue); //Outputs 2
    if (tw30015_originalvalue<>2) or
       (ValueConst<>2) then
      halt(1);
  end;

var
  tw30015_testobj: tw30015_ttest;
  tw30015_i: Int32;
{$pop}

{ Case tw9261.pp }
{$push}
{$mode objfpc}

type tw9261_methodprocvar = function(): Boolean of object;

procedure tw9261_test_procedure(a1, a2, a3, a4, a5, a6: integer; tw9261_mv: tw9261_methodprocvar);
begin
  with Tmethod(tw9261_mv) do
    if (code<>codepointer($11111111)) or (data<>pointer($22222222)) then
       begin
         writeln('test failed');
         halt(1);
       end;
end;

var tw9261_a:tw9261_methodprocvar;
{$pop}

begin
  { Case tw30015.pp }
  {$push}
{$Inline On}
  begin
tw30015_i := 1;
  tw30015_testobj.tw30015_setkey(tw30015_i + 1);
  end;
  {$pop}

  { Case tw9261.pp }
  {$push}

  begin
with Tmethod(tw9261_a) do
    begin
      code:=codepointer($11111111);
      data:=pointer($22222222);
    end;
  tw9261_test_procedure(1, 2, 3, 4, 5, 6, tw9261_a);
  end;
  {$pop}

end.
