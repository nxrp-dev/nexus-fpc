{ Generics regression cases; original case IDs are retained below. }

{ Case tw18567.pp }
{$push}
{$mode delphi}

type
  tw18567_tsomerecord <TData> = record
    tw18567_data: TData;
    class operator Explicit(a: TData) : tw18567_tsomerecord <TData>;
  end;

  class operator tw18567_tsomerecord <TData>.Explicit (a: TData): tw18567_tsomerecord <TData>;
  begin

  end;
{$pop}

{ Case tw21592.pp }
{$push}
{$MODE DELPHI}

type
  tw21592_tbytesoverlay<T> = array [0..SizeOf(T) - 1] of Byte;
    { Error: Identifier not found "T" }

var
  tw21592_a : tw21592_tbytesoverlay<Byte>;
{$pop}

{ Case tw23130.pp }
{$push}
{$MODE DELPHI}

type
  tw23130_tfunction<TArgument, TResult> = function (const arg: TArgument): TResult;

  tw23130_twrapper = record
    class function tw23130_z(const arg: Integer): Boolean; static;
    class procedure tw23130_w; static;
  end;

  tw23130_twrapper2 = class
    procedure tw23130_zz(f: tw23130_tfunction<Integer, Boolean>);
  end;

class function tw23130_twrapper.tw23130_z(const arg: Integer): Boolean;
begin
  Result := arg < 0;
end;

class procedure tw23130_twrapper.tw23130_w;
begin
  with tw23130_twrapper2.Create do begin
    tw23130_zz(@tw23130_z);  { Replace with @TWrapper.Z to get rid of the error }
    Free;
  end;
end;

procedure tw23130_twrapper2.tw23130_zz(f: tw23130_tfunction<Integer, Boolean>);
begin
end;
{$pop}

{ Case tw34497b.pp }
{$push}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
type
  tw34497b_tgenrec<T1, T2> = record
    tw34497b_a: T1;
    tw34497b_b: T2;
    class operator Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T1;
    class operator Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T2;
  end;

  class operator tw34497b_tgenrec<T1, T2>.Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T1;
  begin
    Result := Rec.tw34497b_a;
  end;

  class operator tw34497b_tgenrec<T1, T2>.Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T2;
  begin
    Result := Rec.tw34497b_b;
  end;
{$pop}

{ Case tw37107.pp }
{$push}
{$IFDEF FPC}{$mode Delphi}{$ENDIF}

type
  tw37107_ttest<T: Record> = class(TObject)
    procedure tw37107_testit();
  end;

procedure tw37107_ttest<T>.tw37107_testit();
begin
  WriteLn('=== ', 1 div SizeOf(T));
  if SizeOf(T) > 0 then
    WriteLn('I''m reachable!')
end;
{$pop}

begin
  { Case tw21592.pp }
  {$push}

  begin
if sizeof(tw21592_a)<>1 then
    halt(1);
  writeln('ok');
  end;
  {$pop}

  { Case tw37107.pp }
  {$push}
{$IFDEF FPC}
{$ENDIF}
  begin
tw37107_ttest<Char>.Create().tw37107_testit();
  end;
  {$pop}

end.
