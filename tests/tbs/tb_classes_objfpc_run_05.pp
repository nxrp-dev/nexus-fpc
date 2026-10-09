{ Classes regression cases; original case IDs are retained below. }

{ Case tw0868.pp }
{$push}
{$mode objfpc}
{$H+}
type
  tw0868_ttreedata = record
    tw0868_key: String;
    tw0868_data: Integer;
  end;

  tw0868_tnode = class
    tw0868_data: tw0868_ttreedata;
  end;

  tw0868_tstrintdic = class
    tw0868_fnode: tw0868_tnode;
    destructor Destroy; override;
    procedure tw0868_add(const tw0868_key: String; tw0868_data: Integer);
  end;

destructor tw0868_tstrintdic.Destroy;
begin
  tw0868_fnode.Free;
  inherited Destroy;
end;

procedure tw0868_tstrintdic.tw0868_add(const tw0868_key: String; tw0868_data: Integer);
var
  tw0868_t: tw0868_ttreedata;
begin
  tw0868_t.tw0868_key:=tw0868_key;
  tw0868_t.tw0868_data:=tw0868_data;
  tw0868_fnode:=tw0868_tnode.Create;
  tw0868_fnode.tw0868_data:=tw0868_t;
end;

procedure tw0868_test;
var
  tw0868_sd: tw0868_tstrintdic;
begin
  tw0868_sd:=tw0868_tstrintdic.Create;
  try
    tw0868_sd.tw0868_add('asdf', 2);
  finally
    tw0868_sd.Free;
  end;
end;
{$pop}

{ Case tw22864.pp }
{$push}
{$mode objfpc}{$H+}

type
  tw22864_tonidentifierfound = function(): integer of object;
  tw22864_ttest=class
    tw22864_onidentifierfound: tw22864_tonidentifierfound;
    tw22864_foundproc: pointer;
    function tw22864_testm():integer;
  end;
  tw22864_ttest2=class
    function tw22864_testmm(Params:tw22864_ttest;var tw22864_c,tw22864_d,tw22864_e:integer):boolean;
  end;

function tw22864_ttest.tw22864_testm():integer;
  begin

  end;

function tw22864_ttest2.tw22864_testmm(Params:tw22864_ttest;var tw22864_c,tw22864_d,tw22864_e:integer):boolean;
var tw22864_k,tw22864_l:integer;

  function tw22864_testm2(Params1:tw22864_ttest;var tw22864_m,tw22864_n:integer):boolean;
  var tw22864_a,tw22864_b:integer;
  begin
    if (Params.tw22864_onidentifierfound<>@Params.tw22864_testm) then halt(1);
    if (Params.tw22864_foundproc<>pointer($deadbeef)) then halt(1);
  end;

begin
  tw22864_testm2(Params,tw22864_k,tw22864_l);
end;

var
  tw22864_test : tw22864_ttest;
  tw22864_test2 : tw22864_ttest2;
  tw22864_c,tw22864_d,tw22864_e : integer;
{$pop}

{ Case tw30923.pp }
{$push}
{$mode objfpc}{$H+}

Type
  tw30923_qstringlisth = class(TObject) end;

function tw30923_qstringlist_size(handle: tw30923_qstringlisth): Integer; cdecl;
begin
  Result := 1;
end;

procedure tw30923_qstringlist_at(handle: tw30923_qstringlisth; tw30923_retval: PWideString; tw30923_i: Integer); cdecl;
begin

end;

procedure tw30923_test;
Var
  tw30923_aqstringlisth : tw30923_qstringlisth;
  tw30923_awidestring : WideString;
  tw30923_i : Integer;
begin
  For tw30923_i := 0 To tw30923_qstringlist_size(tw30923_aqstringlisth) - 1  do
    tw30923_qstringlist_at(tw30923_aqstringlisth, @tw30923_awidestring, tw30923_i);
end;

Var
  tw30923_i : Integer;
{$pop}

begin
  { Case tw0868.pp }
  {$push}

  begin
tw0868_test;
  write('Test for bug 868 completed.');
  {readln;}
  end;
  {$pop}

  { Case tw22864.pp }
  {$push}

  begin
tw22864_test:=tw22864_ttest.Create;
  tw22864_test.tw22864_onidentifierfound:=@tw22864_test.tw22864_testm;
  tw22864_test.tw22864_foundproc:=pointer($deadbeef);
  tw22864_test2:=tw22864_ttest2.Create;
  tw22864_test2.tw22864_testmm(tw22864_test,tw22864_c,tw22864_d,tw22864_e);
  tw22864_test.Free;
  tw22864_test2.Free;
  writeln('ok');
  end;
  {$pop}

  { Case tw30923.pp }
  {$push}

  begin
tw30923_test;
  tw30923_i := 0;
  end;
  {$pop}

end.
