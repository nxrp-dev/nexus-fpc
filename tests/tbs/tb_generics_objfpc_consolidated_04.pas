{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
{ %OPT=-Sew }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_generic_classes_objfpc_compile_01.pas }
{$push}


{ Generic class result initialization and comparisons involving unresolved types. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0617.pas }
{$push}
{ We don't want this warning to occur again }
{$warn 5059 error}

type
  generic tb0617_tgenericstructlist<T> = class
  public
    function tb0617_remove(const tb0617_item: T): Integer;
    procedure tb0617_delete(tb0617_index: Integer);
    function tb0617_indexof(const tb0617_item: T): Integer;
  end;

function tb0617_tgenericstructlist.tb0617_remove(const tb0617_item: T): Integer;
begin
  Result := tb0617_indexof(tb0617_item);
  { for some reason, FPC 3.1.1 makes here incorrect warning:
    castlegenericlists.pas(254,13) Warning: Function result variable does not seem to be initialized }
  if Result >= 0 then
    tb0617_delete(Result);
end;

function tb0617_tgenericstructlist.tb0617_indexof(const tb0617_item: T): Integer;
begin
  Result := 0;
end;

procedure tb0617_tgenericstructlist.tb0617_delete(tb0617_index: Integer);
begin

end;
{$pop}

{ Case tb0702.pas }
{$push}
{ don't optimize TypeInfo comparisons if undefined types are involved }


type
  generic tb0702_ttest<tb0702_s> = class
    procedure tb0702_test;
  end;

procedure tb0702_ttest.tb0702_test;
begin
  if TypeInfo(tb0702_s) = TypeInfo(LongInt) then
    Writeln('Test');
end;
{$pop}


{$pop}

{ Case tgeneric120.pas }
{$push}







type
  generic tgeneric120_TTest<T> = class
    constructor Create; virtual;
  end;

  {$warn 3018 off}

  generic tgeneric120_TTestSub<T> = class(specialize tgeneric120_TTest<T>)
  protected
    constructor Create; override;
  end;

constructor tgeneric120_TTest.Create;
begin
end;

constructor tgeneric120_TTestSub.Create;
begin
end;


{$pop}

{ Case tgeneric121.pas }
{$push}







type
  generic tgeneric121_TTest<T> = class
    constructor Create; virtual;
  end;

  {$push}
  {$warn 3018 off}

  generic tgeneric121_TTestSub<T> = class(specialize tgeneric121_TTest<T>)
  protected
    constructor Create; override;
  end;

  {$pop}

  generic tgeneric121_TTestSub2<T> = class(specialize tgeneric121_TTestSub<T>)

  end;

constructor tgeneric121_TTest.Create;
begin
end;

constructor tgeneric121_TTestSub.Create;
begin
end;


{$pop}

begin

{ Case tb_generic_classes_objfpc_compile_01.pas }
{$push}

{$push}
{$warn 5059 error}
{$pop}
{$push}
{$pop}
begin
  { Case tb0617.pas }
  {$push}
begin

end;
  {$pop}

  { Case tb0702.pas }
  {$push}
begin

end;
  {$pop}

end;
{$pop}

{ Case tgeneric120.pas }
{$push}

{$warn 3018 off}
begin

end;
{$pop}

{ Case tgeneric121.pas }
{$push}

{$push}
{$warn 3018 off}
{$pop}
begin

end;
{$pop}

end.
