{ Generic self-aliases, specialized constructors and method pointer fields. }
{ %NORUN }

{ tw20407.pp }
{$mode delphi}

type
  tbwimagegen<T> = class
    type
      TLocalType = tbwimagegen<T>;
  end;

{ tw20629.pp }
{$MODE delphi}

type
  TWrapper<TValue> = class end;
  TObjectWrapper = TWrapper<TObject>;

{ tw21622.pp }
{$MODE DELPHI}
{$DEFINE CAUSE_ERROR}

type
  TProceduralMethod<T> = procedure (arg: T) of object;

  TMethodPointerWrapper<T> = class
  strict private
    type
      TOnChanging = TProceduralMethod<T>;
      { Replace T with e.g. Integer, the problem persists }
  strict private
  {$IFDEF CAUSE_ERROR}
    FOnChanging: TOnChanging;
      { Error: Generics without specialization cannot be used as a type for
        a variable }
  {$ELSE}
    FOnChanging: TProceduralMethod<T>;
  {$ENDIF}
  end;

begin
  { tw20629.pp }
  with TObjectWrapper.Create do Free;     { OK }
    with TWrapper<TObject>.Create do Free;  { Error }
  ;
end.
