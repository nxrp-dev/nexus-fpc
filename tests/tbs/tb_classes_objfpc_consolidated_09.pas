{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses classes;

{ Case tw13813.pas }
{$push}

{$ifdef fpc}{$h+}{$endif}
{$apptype console}



type
  tw13813_titem = class(TCollectionItem)
  public
    procedure do_something;
  end;

  tw13813_tcoll = class(TCollection)
  public
    procedure Update(tw13813_Item: TCollectionItem); override;
  end;

var
  tw13813_c: tw13813_tcoll;
  tw13813_item: tw13813_titem;
  tw13813_i: Integer;
  tw13813_update_counter: Integer;

procedure tw13813_titem.do_something;
begin
  Changed(False);
end;

procedure tw13813_tcoll.Update(tw13813_Item: TCollectionItem);
begin
  Inc(tw13813_update_counter);
  inherited;
end;



{$pop}

{ Case tforin2.pas }
{$push}


// test operator Enumerator for the string type and built-in into RTL TStrings enumerator

{$H+}
{$apptype console}


type
  { TStringEnumerator }

  tforin2_TStringEnumerator = class // reverse enumerator
  private
    FString: String;
    FIndex: Integer;
    function GetCurrent: Char; inline;
  public
    constructor Create(AString: String);
    function MoveNext: Boolean;
    property Current: Char read GetCurrent;
  end;

{ TStringEnumerator }

function tforin2_TStringEnumerator.GetCurrent: Char;
begin
  Result := FString[FIndex];
end;

constructor tforin2_TStringEnumerator.Create(AString: String);
begin
  inherited Create;
  FString := AString;
  FIndex := Length(FString) + 1;
end;

function tforin2_TStringEnumerator.MoveNext: Boolean;
begin
  dec(FIndex);
  Result := FIndex > 0;
end;

// define an operator for the string type
operator enumerator (const s: string): tforin2_TStringEnumerator;inline;
begin
  Result := tforin2_TStringEnumerator.Create(s);
end;

procedure tforin2_LoopString(s: string);

  function getstring(s: string): string;
  begin
    result:=s;
  end;

var
  c: char;
begin
  // check loop in string. output is 'tset' for the string 'test' :)
  for c in getstring(s) do
    write(c);
  WriteLn;
end;

procedure tforin2_LoopClass;
var
  L: TStringList;
  S: String;
begin
  L := TStringList.Create;
  L.Add('1');
  L.Add('2');
  L.Add('3');
  for S in L do
    WriteLn(S);
  L.Free;
end;


{$pop}

{ Case tforin24.pas }
{$push}



{$apptype console}



Type
   tforin24_TDayObject = Class
     DayOfWeek : Integer;
     Constructor Create(ADayOfWeek : Integer);
   end;

   tforin24_TObjectEnumerator = Class
     FList : TStrings;
     FIndex : Integer;
     Function GetCurrent : tforin24_TDayObject;
     Function MoveNext: boolean;
     Property Current : tforin24_TDayObject Read GetCurrent;
   end;

Constructor tforin24_TDayObject.Create(ADayOfWeek : Integer);

begin
   DayOfWeek:=ADayOfWeek;
end;


Function tforin24_TObjectEnumerator.GetCurrent : tforin24_TDayObject;
begin
   Result:=FList.Objects[Findex] as tforin24_TDayObject;
end;

Function tforin24_TObjectEnumerator.MoveNext: boolean;

begin
   Inc(FIndex);
   Result:=(FIndex<FList.Count);
end;


operator enumerator (s : TStrings) : tforin24_TObjectEnumerator;

begin
   Result:=tforin24_TObjectEnumerator.Create;
   Result.Flist:=S;
   Result.FIndex:=-1;
end;

Var
   tforin24_Days : TStrings;
   tforin24_D : String;
   tforin24_O : tforin24_TdayObject;


{$pop}

begin

{ Case tw13813.pas }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
{$apptype console}
begin
  tw13813_c := tw13813_tcoll.Create(tw13813_titem);
  tw13813_item := tw13813_titem(tw13813_c.Add);
  tw13813_update_counter := 0;
  tw13813_c.BeginUpdate;
  try
    for tw13813_i := 0 to 9 do
      tw13813_item.do_something;
  finally
    tw13813_c.EndUpdate;
  end;
  writeln('updates: ', tw13813_update_counter);
  if tw13813_update_counter<>1 then
    begin
      tw13813_c.Free;
      Halt(1);
    end;
  tw13813_c.Free;
  writeln('ok');
end;
{$pop}

{ Case tforin2.pas }
{$push}

{$H+}
{$apptype console}
begin
  tforin2_LoopString('test');
  tforin2_LoopClass;
end;
{$pop}

{ Case tforin24.pas }
{$push}

{$apptype console}
begin
   tforin24_Days:=TStringList.Create;
   try
     tforin24_Days.AddObject('Monday',tforin24_TDayObject.Create(1));
     tforin24_Days.AddObject('Tuesday',tforin24_TDayObject.Create(2));
     tforin24_Days.AddObject('Wednesday',tforin24_TDayObject.Create(3));
     tforin24_Days.AddObject('Thursday',tforin24_TDayObject.Create(4));
     tforin24_Days.AddObject('Friday',tforin24_TDayObject.Create(5));
     tforin24_Days.AddObject('Saturday',tforin24_TDayObject.Create(6));
     tforin24_Days.AddObject('Sunday',tforin24_TDayObject.Create(7));
     For tforin24_O in tforin24_Days do
       Writeln(tforin24_O.DayOfWeek);
     For tforin24_D in tforin24_Days do
        Writeln(tforin24_D);
   Finally
     tforin24_Days.Free;
   end;
end;
{$pop}

end.
