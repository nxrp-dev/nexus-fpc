{ Virtual method calls in exception handlers and checked string indexing. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

uses SysUtils;

{ Case tb0247.pp }
{$push}
{ Old file: tbs0288.pp }
{ crash with virtual method in except part             OK 0.99.13 (PFV) }

const
  tb0247_test_run : boolean = false;

type
  tb0247_zz=class(tobject)
    procedure tb0247_test;virtual;
    procedure tb0247_test1;virtual;
  end;
procedure tb0247_zz.tb0247_test;
begin
  writeln('ok');
  tb0247_test_run:=true;
end;
procedure tb0247_zz.tb0247_test1;
begin
  try
    raise exception.create('zz');
  except
    on tb0247_e:exception do tb0247_test;
  end;
end;
var
  tb0247_z:tb0247_zz;
{$pop}

{ Case tb0540.pp }
{$push}
{$H-}
{$Q+,R+}

var tb0540_a:string;
    tb0540_b:string[63];
    tb0540_c:char;
    tb0540_w:word;
{$pop}

begin
  { Case tb0247.pp }
  {$push}
begin
  tb0247_z:=tb0247_zz.create;
  tb0247_z.tb0247_test1;
  tb0247_z.destroy;
  if not tb0247_test_run then
    begin
      Writeln('Problem with virtual method in except block');
      Halt(1);
    end;
end;
  {$pop}

  { Case tb0540.pp }
  {$push}
{$H-}
{$Q+,R+}
begin
  tb0540_a:='';
  tb0540_b:='';
  tb0540_w:=257;
  try
    tb0540_c:=tb0540_a[tb0540_w];
    writeln('string[255] failure');
    halt(1);
  except
  end;
  try
    tb0540_c:=tb0540_b[tb0540_w];
    writeln('string[63] failure');
    halt(2);
  except
  end;
end;
  {$pop}

end.
