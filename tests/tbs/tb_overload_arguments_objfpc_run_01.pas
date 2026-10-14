{ Overload selection for stream pointers, fixed/open arrays and Currency arguments. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

uses Classes, SysUtils;

{ Case tw2927.pas }
{$push}
procedure tw2927_readtest(const tw2927_p: Pointer); overload;
begin
end;

procedure tw2927_readtest(const tw2927_p: TStream); overload;
begin
end;

var
  tw2927_f: TFileStream;
{$pop}

{ Case tw7489.pas }
{$push}
{$H+}
type
  tw7489_tsingle3dvector = array[0..2] of single;
  tw7489_tsingle4dvector = array[0..3] of single;

function tw7489_vectorlength(const tw7489_av3d : tw7489_tsingle3dvector) : single; overload;
begin
end;

function tw7489_vectorlength(const tw7489_av4d : tw7489_tsingle4dvector) : single; overload;
begin
end;

function tw7489_vectorlength(const tw7489_avxd : array of single) : single; overload;
begin
end;
{$pop}

{ Case tb0675.pas }
{$push}
function tb0675_test(tb0675_a: Single): LongInt;
begin
  Result := 1;
end;

{$ifdef FPC_HAS_TYPE_DOUBLE}
function tb0675_test(tb0675_a: Double): LongInt;
begin
  Result := 2;
end;
{$endif}

function tb0675_test2(tb0675_a: Single): LongInt;
begin
  Result := 1;
end;

{$ifdef FPC_HAS_TYPE_DOUBLE}
function tb0675_test2(tb0675_a: Double): LongInt;
begin
  Result := 2;
end;
{$endif}

{$ifdef FPC_HAS_TYPE_EXTENDED}
function tb0675_test2(tb0675_a: Extended): LongInt;
begin
  Result := 3;
end;
{$endif}

var
  tb0675_a: Currency;
{$pop}

begin
  { Case tw2927.pas }
  {$push}
begin
  tw2927_readtest(tw2927_f);
end;
  {$pop}

  { Case tw7489.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0675.pas }
  {$push}
begin
  if tb0675_test(tb0675_a) <> 2 then
    Halt(1);
{$ifdef FPC_HAS_TYPE_EXTENDED}
  if tb0675_test2(tb0675_a) <> 3 then
    Halt(2);
{$endif}
end;
  {$pop}

end.
