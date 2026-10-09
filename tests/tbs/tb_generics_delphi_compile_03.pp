{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw21921.pp }
{$push}
{$mode Delphi}{$H+}

type

 { THashEntry }

 tw21921_thashentry<T> = record
   tw21921_key: string;
   tw21921_value: T;
   class function Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>; static; inline;
 end;

class function tw21921_thashentry<T>.Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>;
begin
  Result.tw21921_key := AKey;
  Result.tw21921_value := tw21921_avalue;
end;

var
  tw21921_entry: tw21921_thashentry<Integer>;
{$pop}

{ Case tw24283.pp }
{$push}
{$mode delphi}{$H+}

type
  tw24283_ta<tw24283_t> = record
  end;

  tw24283_tb<tw24283_t> = class
  end;

  tw24283_tc<tw24283_t> = class(tw24283_tb<tw24283_ta<tw24283_t>>)
  end;

{ ensure that specialization works as well }
var
  tw24283_t: tw24283_tc<LongInt>;
{$pop}

{ Case tw39581.pp }
{$push}
{$Mode Delphi} {$H+}

Type
  tw39581_timplclass<P> = class;

  tw39581_ilinkingintf<P> = interface
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
  end;

(* Компиляция проекта, цель: Project1.exe: Код завершения 1, ошибок: 1
Project1.pas(9,55) Error: Internal error 2012101001
*)

  { TImplClass }

  tw39581_timplclass<P> = class( TInterfacedObject, tw39581_ilinkingintf<P> )
  protected
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P> );
  end;

{ TImplClass }

procedure tw39581_timplclass<P>.tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
begin

end;
{$pop}

begin
  { Case tw21921.pp }
  {$push}

  begin
tw21921_entry := tw21921_thashentry<Integer>.Create('One', 1);
  end;
  {$pop}

end.
