{ Virtual method calls in exception handlers and checked string indexing. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

uses SysUtils, Classes;

{ Case tb0247.pas }
{$push}
{ Old file: tbs0288.pas }
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

{ Case tb0540.pas }
{$push}
{$H-}
{$Q+,R+}

var tb0540_a:string;
    tb0540_b:string[63];
    tb0540_c:char;
    tb0540_w:word;
{$pop}

{ Case tb0453.pas }
{$push}
{$MODE objfpc}
type
  tb0453_tfirstclass = class
    constructor Create;
    destructor Destroy; override;
  end;
  tb0453_tsecondclass = class(tb0453_tfirstclass)
    constructor Create;
    destructor Destroy; override;
  end;

constructor tb0453_tfirstclass.Create;
begin
  raise Exception.Create('');
end;

destructor tb0453_tfirstclass.Destroy;
begin
  WriteLn('TFirstClass.Destroy');
  inherited Destroy;
end;

constructor tb0453_tsecondclass.Create;
begin
  inherited Create;
end;

destructor tb0453_tsecondclass.Destroy;
begin
  WriteLn('TSecondClass.Destroy');
end;

var
  tb0453_o: tb0453_tsecondclass;
{$pop}

{ Case tb0284.pas }
{$push}
{ Old file: tbs0336.pas }
{  }

{$mode objfpc}
const tb0284_dsmerged=0;
      tb0284_dsopenerror=1;
      tb0284_dscreateerror=2;
      tb0284_dsconverterror=3;
      tb0284_dsmismatcherror=4;
      tb0284_dscrcerror=5;
      tb0284_dserror=6;

type tb0284_tvsmergediffs=class
                     procedure execute;
                     end;

     tb0284_tvsdiffitem= class
                                 status : longint;
                    end;

tb0284_emismatcheddifferror =class(exception);
tb0284_ediffcrccompareerror= class(exception);

procedure tb0284_tvsmergediffs.Execute;
var
  tb0284_stream: tFileStream;
  tb0284_item: tb0284_tvsdiffitem;
  tb0284_a : longint;
begin
      try
        tb0284_item.Status := tb0284_dsmerged;
      except
        { Only the number of on xx do statements seems to matter, not
                which ones, try commenting 3 or 4 out}
        on EFOpenError do tb0284_item.Status := tb0284_dsopenerror;
        on EFCreateError do tb0284_item.Status := tb0284_dscreateerror;
        on EConvertError do tb0284_item.Status := tb0284_dsconverterror;
        on tb0284_emismatcheddifferror do tb0284_item.Status := tb0284_dsmismatcherror;
        on tb0284_ediffcrccompareerror do tb0284_item.Status := tb0284_dscrcerror;
        on Exception do tb0284_item.Status := tb0284_dserror;
      end;
end;
{$pop}

begin
  { Case tb0247.pas }
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

  { Case tb0540.pas }
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

  { Case tb0453.pas }
  {$push}
begin
  try
    try
      tb0453_o := tb0453_tsecondclass.Create;
    finally
      tb0453_o.Free;
    end;
  except
    on tb0453_e: Exception do
      WriteLn('Exception: ', tb0453_e.Message);
  end;
end;
  {$pop}

  { Case tb0284.pas }
  {$push}
begin
end;
  {$pop}

end.
