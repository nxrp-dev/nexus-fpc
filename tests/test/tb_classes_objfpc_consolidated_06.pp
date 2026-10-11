{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tforin15.pp }
{$push}

{$apptype console}

type
  tforin15_T = class
    stop: boolean;
    F: Integer;
    function MoveNext: Boolean;
    property Current: Integer read F;
  end;

tforin15_Twice = type Integer;

function tforin15_T.MoveNext: Boolean;
begin
  Result := not stop;
  stop := true;
end;

operator enumerator(a: Integer): tforin15_T;
begin
  Result := tforin15_T.Create;
  Result.F := a;
  Result.stop := false;
end;

operator enumerator(a: tforin15_Twice): tforin15_T;
begin
  Result := tforin15_T.Create;
  Result.F := a * 2;
  Result.stop := false;
end;

var
  tforin15_i: Integer;

{$pop}

{ Case tforin3.pp }
{$push}


// check for-in loop if GetEnumerator returns nil

{$H+}
{$APPTYPE CONSOLE}

type

  { TListEnumerator }

  tforin3_TListEnumerator = class
  private
    FCurrent: String;
  public
    function MoveNext: Boolean;
    property Current: String read FCurrent;
  end;

  tforin3_TMyList = class
  public
    function GetEnumerator: tforin3_TListEnumerator;
  end;

{ TListEnumerator }

function tforin3_TListEnumerator.MoveNext: Boolean;
begin
  Result := True;
end;

{ TMyList }

function tforin3_TMyList.GetEnumerator: tforin3_TListEnumerator;
begin
  Result := nil;
end;

var
  tforin3_S: String;
  tforin3_L: tforin3_TMyList;

{$pop}

{ Case tforin5.pp }
{$push}


// test operator Enumerator support for classes

{$H+}
{$APPTYPE CONSOLE}

type
  tforin5_TMyList = class
  end;

  { TMyListEnumerator }

  tforin5_TMyListEnumerator = class
  private
    FCurrent: Integer;
  public
    constructor Create;
    function MoveNext: Boolean;
    property Current: Integer read FCurrent;
  end;

{ TMyListEnumerator }

constructor tforin5_TMyListEnumerator.Create;
begin
  FCurrent := 0;
end;

function tforin5_TMyListEnumerator.MoveNext: Boolean;
begin
  inc(FCurrent);
  Result := FCurrent <= 3;
end;

operator enumerator (AList: tforin5_TMyList): tforin5_TMyListEnumerator;
begin
  Result := tforin5_TMyListEnumerator.Create;
end;

var
  tforin5_List: tforin5_TMyList;
  tforin5_i: integer;

{$pop}

{ Case tforin6.pp }
{$push}


// test Object enumerator implementation

{$H+}
{$APPTYPE CONSOLE}

type
  { TMyListEnumerator }

  tforin6_TMyListEnumerator = object
  private
    FCurrent: Integer;
  public
    constructor Create;
    destructor Destroy;
    function MoveNext: Boolean;
    property Current: Integer read FCurrent;
  end;

  tforin6_TMyList = class
  end;

{ TMyListEnumerator }

constructor tforin6_TMyListEnumerator.Create;
begin
  WriteLn('create');
  FCurrent := 0;
end;

destructor tforin6_TMyListEnumerator.Destroy;
begin
  WriteLn('destroy');
  inherited;
end;

function tforin6_TMyListEnumerator.MoveNext: Boolean;
begin
  inc(FCurrent);
  Result := FCurrent <= 3;
end;

operator enumerator (AList: tforin6_TMyList): tforin6_TMyListEnumerator;
begin
  Result.Create;
end;

var
  tforin6_List: tforin6_TMyList;
  tforin6_i: integer;

{$pop}

{ Case tforin7.pp }
{$push}


// test 'enumerator MoveNext' and 'enumerator Current' directives

{$H+}
{$APPTYPE CONSOLE}

type
  { TMyListEnumerator }

  tforin7_TMyListEnumerator = object
  private
    FCurrent: Integer;
  public
    constructor Create;
    destructor Destroy;
    function StepNext: Boolean; enumerator MoveNext;
    property Value: Integer read FCurrent; enumerator Current;
  end;

  tforin7_TMyList = class
  end;

{ TMyListEnumerator }

constructor tforin7_TMyListEnumerator.Create;
begin
  FCurrent := 0;
end;

destructor tforin7_TMyListEnumerator.Destroy;
begin
  inherited;
end;

function tforin7_TMyListEnumerator.StepNext: Boolean;
begin
  inc(FCurrent);
  Result := FCurrent <= 3;
end;

operator enumerator (AList: tforin7_TMyList): tforin7_TMyListEnumerator;
begin
  Result.Create;
end;

var
  tforin7_List: tforin7_TMyList;
  tforin7_i: integer;

{$pop}

{ Case tforin8.pp }
{$push}


// Test IEnumerable and IEnumerator in the for-in loop

{$H+}
{$APPTYPE CONSOLE}

type
  { TMyListEnumerator }

  tforin8_TMyListEnumerator = class(TInterfacedObject, IEnumerator)
  private
    FCurrent: Pointer;
    function GetCurrent: TObject;
  public
    function MoveNext: Boolean;
    procedure Reset;
    property Current: TObject read GetCurrent;
  end;

  tforin8_TMyList = class(TInterfacedObject, IEnumerable)
  public
    function GetEnumerator: IEnumerator;
  end;

{ TMyListEnumerator }


function tforin8_TMyListEnumerator.GetCurrent: TObject;
begin
  Result := TObject(FCurrent);
end;

function tforin8_TMyListEnumerator.MoveNext: Boolean;
begin
  inc(PByte(FCurrent));
  Result := FCurrent <= Pointer(3);
end;

procedure tforin8_TMyListEnumerator.Reset;
begin
  FCurrent := nil;
end;

{ TMyList }

function tforin8_TMyList.GetEnumerator: IEnumerator;
begin
  Result := tforin8_TMyListEnumerator.Create;
end;

var
  tforin8_List: IEnumerable;
  tforin8_i: TObject;

{$pop}

begin

{ Case tforin15.pp }
{$push}

{$apptype console}
begin
  for tforin15_i in tforin15_Twice(1) do
    Writeln(tforin15_i);
end;
{$pop}

{ Case tforin3.pp }
{$push}

{$H+}
{$APPTYPE CONSOLE}
begin
  tforin3_L := tforin3_TMyList.Create;
  for tforin3_S in tforin3_L do
    ;
  tforin3_L.Free;
end;
{$pop}

{ Case tforin5.pp }
{$push}

{$H+}
{$APPTYPE CONSOLE}
begin
  tforin5_List := tforin5_TMyList.Create;
  for tforin5_i in tforin5_List do
    WriteLn(tforin5_i);
  tforin5_List.Free;
end;
{$pop}

{ Case tforin6.pp }
{$push}

{$H+}
{$APPTYPE CONSOLE}
begin
  tforin6_List := tforin6_TMyList.Create;
  for tforin6_i in tforin6_List do
    WriteLn(tforin6_i);
  tforin6_List.Free;
end;
{$pop}

{ Case tforin7.pp }
{$push}

{$H+}
{$APPTYPE CONSOLE}
begin
  tforin7_List := tforin7_TMyList.Create;
  for tforin7_i in tforin7_List do
    WriteLn(tforin7_i);
  tforin7_List.Free;
end;
{$pop}

{ Case tforin8.pp }
{$push}

{$H+}
{$APPTYPE CONSOLE}
begin
  tforin8_List := tforin8_TMyList.Create;
  for tforin8_i in tforin8_List do
    WriteLn(PtrUInt(tforin8_i));
  tforin8_List := nil;
end;
{$pop}

end.
