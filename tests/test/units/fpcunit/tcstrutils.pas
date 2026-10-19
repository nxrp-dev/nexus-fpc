unit tcstrutils;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, strutils;

type

  TTestSearchBuf= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    Procedure TestSearch(Sub:String; Start : Integer; O : TStringSearchOptions; Expected : Integer);
  public
    procedure TestSimple;
    procedure TestSimpleNoRes;
    procedure TestSimpleDown;
    procedure TestSimpleDownNoRes;
    procedure TestNotExistDown;
    procedure TestNotExist;
    procedure TestSimpleDownPos;
    procedure TestSimplePos;
    procedure TestSimpleCaseSensitive;
    procedure TestSimpleCaseSensitiveDown;
    procedure TestSimpleWholeWord;
    procedure TestSimpleWholeWordDown;
    procedure TestSimplePartialend;
    procedure TestSimplePartialStart;
    procedure TestEndMatchDown;
    procedure TestEndMatch;
    procedure TestWholeWordAtStart;
    procedure TestWholeWordAtStartDown;
    procedure TestWholeWordAtEnd;
    procedure TestWholeWordAtEndDown;
    procedure TestEmptySearchString;
    procedure TestSelstartBeforeBuf;
    procedure testSelstartAfterBuf;
    Procedure TestDecodeSoundexInt;
  end;


  TTestGeneral = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    procedure TestIndexStr;
    procedure TestMatchStr;
  end;


procedure RegistertcstrutilsTests(ARegistry: TNXTestRegistry);

implementation

Const
   // Don't move this comment, it indicates the positions.
   //           1         2         3         4
   //  1234567890123456789012345678901234567890123456789
  S = 'Some very long string with some words in it';
  SLen = Length(S);

{$define usenew}
{$ifdef usenew}
{$i searchbuf.inc}
const
  WhichSearchbuf = 'new';
{$else}
const
  WhichSearchbuf = 'old';
{$endif}

procedure TTestSearchBuf.TestSearch(Sub: String; Start: Integer;
  O: TStringSearchOptions; Expected: Integer);

Var
  P,PR : PChar;
  I : Integer;

begin
  P:=PChar(S);
  PR:=SearchBuf(P,Length(S),Start,0,Sub,O);
  If (PR=Nil) then
    begin
    If (Expected<>-1) then
      TestContext.Fail(Format('Search for "%s" failed, expected result at %d',[Sub,Expected]));
    end
  else
    begin
    I:=(PR-P)+1;
    If (I<>Expected) then
      TestContext.Fail(Format('Wrong result for search for "%s", expected result at %d, got %d',[Sub,Expected,I]));
    end;
end;

procedure TTestSearchBuf.TestSimpleNoRes;
begin
  TestSearch('very',0,[],-1);
end;

procedure TTestSearchBuf.TestSimple;
begin
  TestSearch('very',SLen,[],6);
end;

procedure TTestSearchBuf.TestSimpleDownNoRes;
begin
  TestSearch('very',0,[soDown],6);
end;

procedure TTestSearchBuf.TestSimpleDown;
begin
  TestSearch('very',SLen,[soDown],-1);
end;

procedure TTestSearchBuf.TestSimplePartialend;
begin
  TestSearch('its',0,[soDown],-1);
end;

procedure TTestSearchBuf.TestSimplePartialStart;
begin
  TestSearch('Tso',SLen,[],-1);
end;

procedure TTestSearchBuf.TestEndMatchDown;
begin
  TestSearch('it',30,[soDown],42);
end;

procedure TTestSearchBuf.TestEndMatch;
begin
  TestSearch('it',SLen,[],42);
end;

procedure TTestSearchBuf.TestWholeWordAtStart;
begin
  TestSearch('Some',20,[soWholeWord],1);
end;

procedure TTestSearchBuf.TestWholeWordAtStartDown;
begin
  TestSearch('Some',0,[soDown,soWholeWord],1);
end;

procedure TTestSearchBuf.TestWholeWordAtEnd;
begin
  TestSearch('it',SLen,[soWholeWord],42);
end;

procedure TTestSearchBuf.TestWholeWordAtEndDown;
begin
  TestSearch('it',30,[soDown,soWholeWord],42);
end;

procedure TTestSearchBuf.TestEmptySearchString;
begin
  TestSearch('',30,[],-1);
end;

procedure TTestSearchBuf.TestSelstartBeforeBuf;
begin
  TestSearch('very',-5,[soDown],-1);
end;

procedure TTestSearchBuf.testSelstartAfterBuf;
begin
  TestSearch('very',100,[],-1);
end;

procedure TTestSearchBuf.TestDecodeSoundexInt;

Const
  OrdA = Ord('A');
  Ord0 = Ord('0');

  Function CreateInt (Const S : String) : Integer;

  var
    I, Len : Integer;

  begin
    Result:=-1;
    Len:=Length(S);
    If Len>0 then
      begin
      Result:=Ord(S[1])-OrdA;
      if Len > 1 then
        begin
        Result:=Result*26+(Ord(S[2])-Ord0);
        for I:=3 to Len do
          Result:=(Ord(S[I])-Ord0)+Result*7;
        end;
      Result:=Len+Result*9;
      end;
  end;


  Procedure TestOneShot(S : String);

  Var
    R : String;

  begin
    R:=DecodeSoundexInt(CreateInt(S));
    TestContext.AssertTrue((S)=(R), 'Decoded Soundexint equals original soundex result:');
  end;

Var
  C,J,K : Integer;
  S : String;

begin
  For C:=Ord('A') to Ord('Z') do
    begin
    S:=Char(C);
    TestOneShot(S);
    for J:=1 to 6 do
      begin
      S:=Char(C);
      For K:=1 to 6 do
        begin
        S:=S+Char(Ord('0')+k);
        TestOneShot(S);
        end;
      end;
    end;

end;

procedure TTestSearchBuf.TestSimpleDownPos;
begin
  TestSearch('it',30,[soDown],42);
end;

procedure TTestSearchBuf.TestSimplePos;
begin
  TestSearch('it',30,[],24);
end;

procedure TTestSearchBuf.TestNotExist;
begin
  TestSearch('quid',SLen,[],-1);
end;

procedure TTestSearchBuf.TestNotExistDown;
begin
  TestSearch('quid',0,[soDown],-1);
end;

procedure TTestSearchBuf.TestSimpleCaseSensitive;
begin
  TestSearch('Very',SLen,[soMatchCase],-1);
end;

procedure TTestSearchBuf.TestSimpleCaseSensitiveDown;
begin
  TestSearch('Very',0,[soMatchCase,soDown],-1);
end;

procedure TTestSearchBuf.TestSimpleWholeWord;
begin
  TestSearch('in',SLen,[soWholeWord],39);
end;

procedure TTestSearchBuf.TestSimpleWholeWordDown;
begin
  TestSearch('in',0,[soWholeWord,soDown],39);
end;

procedure TTestGeneral.TestIndexStr;
var
  s: UnicodeString;
  a: array of UnicodeString;
begin
  s := 'Henry';
  TestContext.AssertTrue(IndexStr(s, ['Brian', 'Jim', 'Henry']) = 2, 'Failed on 1');
  TestContext.AssertTrue(IndexStr(s, ['Brian', 'Jim', 'henry']) = -1, 'Failed on 2');
  TestContext.AssertTrue(IndexStr(s, ['BRIAN', 'JIM', 'HENRY']) = -1, 'Failed on 3');
  s := 'HENRY';
  TestContext.AssertTrue(IndexStr(s, ['BRIAN', 'HENRY', 'JIM']) = 1, 'Failed on 4');

  SetLength(a, 3);
  a[0] := 'Brian';
  a[1] := 'Jim';
  a[2] := 'Henry';
  TestContext.AssertTrue(IndexStr(s, a) = -1, 'Failed on 5');
  s := 'Henry';
  TestContext.AssertTrue(IndexStr(s, a) = 2, 'Failed on 6');
  a[2] := 'henry';
  TestContext.AssertTrue(IndexStr(s, a) = -1, 'Failed on 7');
end;

procedure TTestGeneral.TestMatchStr;
var
  s: UnicodeString;
  a: array of UnicodeString;
begin
  s := 'Henry';
  TestContext.AssertTrue((True)=(MatchStr(s, ['Brian', 'Jim', 'Henry'])), 'Failed on 1');
  TestContext.AssertTrue((False)=(MatchStr(s, ['Brian', 'Jim', 'henry'])), 'Failed on 2');
  TestContext.AssertTrue((False)=(MatchStr(s, ['BRIAN', 'JIM', 'HENRY'])), 'Failed on 3');
  s := 'HENRY';
  TestContext.AssertTrue((True)=(MatchStr(s, ['BRIAN', 'HENRY', 'JIM'])), 'Failed on 4');

  SetLength(a, 3);
  a[0] := 'Brian';
  a[1] := 'Jim';
  a[2] := 'Henry';
  TestContext.AssertTrue((False)=(MatchStr(s, a)), 'Failed on 5');
  s := 'Henry';
  TestContext.AssertTrue((True)=(MatchStr(s, a)), 'Failed on 6');
  a[2] := 'henry';
  TestContext.AssertTrue((False)=(MatchStr(s, a)), 'Failed on 7');
end;

constructor TTestSearchBuf.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestGeneral.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSearchBufTestSimple(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimple');
  try
    lFixture.TestSimple;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleNoRes(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleNoRes');
  try
    lFixture.TestSimpleNoRes;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleDown');
  try
    lFixture.TestSimpleDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleDownNoRes(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleDownNoRes');
  try
    lFixture.TestSimpleDownNoRes;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestNotExistDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestNotExistDown');
  try
    lFixture.TestNotExistDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestNotExist(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestNotExist');
  try
    lFixture.TestNotExist;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleDownPos(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleDownPos');
  try
    lFixture.TestSimpleDownPos;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimplePos(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimplePos');
  try
    lFixture.TestSimplePos;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleCaseSensitive(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleCaseSensitive');
  try
    lFixture.TestSimpleCaseSensitive;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleCaseSensitiveDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleCaseSensitiveDown');
  try
    lFixture.TestSimpleCaseSensitiveDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleWholeWord(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleWholeWord');
  try
    lFixture.TestSimpleWholeWord;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimpleWholeWordDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimpleWholeWordDown');
  try
    lFixture.TestSimpleWholeWordDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimplePartialend(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimplePartialend');
  try
    lFixture.TestSimplePartialend;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSimplePartialStart(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSimplePartialStart');
  try
    lFixture.TestSimplePartialStart;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestEndMatchDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestEndMatchDown');
  try
    lFixture.TestEndMatchDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestEndMatch(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestEndMatch');
  try
    lFixture.TestEndMatch;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestWholeWordAtStart(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestWholeWordAtStart');
  try
    lFixture.TestWholeWordAtStart;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestWholeWordAtStartDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestWholeWordAtStartDown');
  try
    lFixture.TestWholeWordAtStartDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestWholeWordAtEnd(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestWholeWordAtEnd');
  try
    lFixture.TestWholeWordAtEnd;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestWholeWordAtEndDown(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestWholeWordAtEndDown');
  try
    lFixture.TestWholeWordAtEndDown;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestEmptySearchString(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestEmptySearchString');
  try
    lFixture.TestEmptySearchString;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestSelstartBeforeBuf(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestSelstartBeforeBuf');
  try
    lFixture.TestSelstartBeforeBuf;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBuftestSelstartAfterBuf(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'testSelstartAfterBuf');
  try
    lFixture.testSelstartAfterBuf;
  finally lFixture.Free; end;
end;

procedure RunTTestSearchBufTestDecodeSoundexInt(AContext: TNXTestContext);
var lFixture: TTestSearchBuf;
begin
  lFixture:=TTestSearchBuf.Create(AContext, 'TestDecodeSoundexInt');
  try
    lFixture.TestDecodeSoundexInt;
  finally lFixture.Free; end;
end;

procedure RunTTestGeneralTestIndexStr(AContext: TNXTestContext);
var lFixture: TTestGeneral;
begin
  lFixture:=TTestGeneral.Create(AContext, 'TestIndexStr');
  try
    lFixture.TestIndexStr;
  finally lFixture.Free; end;
end;

procedure RunTTestGeneralTestMatchStr(AContext: TNXTestContext);
var lFixture: TTestGeneral;
begin
  lFixture:=TTestGeneral.Create(AContext, 'TestMatchStr');
  try
    lFixture.TestMatchStr;
  finally lFixture.Free; end;
end;

procedure RegistertcstrutilsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcstrutils.TTestSearchBuf');
  lSuite.AddTest('TestSimple', @RunTTestSearchBufTestSimple, 'strings');
  lSuite.AddTest('TestSimpleNoRes', @RunTTestSearchBufTestSimpleNoRes, 'strings');
  lSuite.AddTest('TestSimpleDown', @RunTTestSearchBufTestSimpleDown, 'strings');
  lSuite.AddTest('TestSimpleDownNoRes', @RunTTestSearchBufTestSimpleDownNoRes, 'strings');
  lSuite.AddTest('TestNotExistDown', @RunTTestSearchBufTestNotExistDown, 'strings');
  lSuite.AddTest('TestNotExist', @RunTTestSearchBufTestNotExist, 'strings');
  lSuite.AddTest('TestSimpleDownPos', @RunTTestSearchBufTestSimpleDownPos, 'strings');
  lSuite.AddTest('TestSimplePos', @RunTTestSearchBufTestSimplePos, 'strings');
  lSuite.AddTest('TestSimpleCaseSensitive', @RunTTestSearchBufTestSimpleCaseSensitive, 'strings');
  lSuite.AddTest('TestSimpleCaseSensitiveDown', @RunTTestSearchBufTestSimpleCaseSensitiveDown, 'strings');
  lSuite.AddTest('TestSimpleWholeWord', @RunTTestSearchBufTestSimpleWholeWord, 'strings');
  lSuite.AddTest('TestSimpleWholeWordDown', @RunTTestSearchBufTestSimpleWholeWordDown, 'strings');
  lSuite.AddTest('TestSimplePartialend', @RunTTestSearchBufTestSimplePartialend, 'strings');
  lSuite.AddTest('TestSimplePartialStart', @RunTTestSearchBufTestSimplePartialStart, 'strings');
  lSuite.AddTest('TestEndMatchDown', @RunTTestSearchBufTestEndMatchDown, 'strings');
  lSuite.AddTest('TestEndMatch', @RunTTestSearchBufTestEndMatch, 'strings');
  lSuite.AddTest('TestWholeWordAtStart', @RunTTestSearchBufTestWholeWordAtStart, 'strings');
  lSuite.AddTest('TestWholeWordAtStartDown', @RunTTestSearchBufTestWholeWordAtStartDown, 'strings');
  lSuite.AddTest('TestWholeWordAtEnd', @RunTTestSearchBufTestWholeWordAtEnd, 'strings');
  lSuite.AddTest('TestWholeWordAtEndDown', @RunTTestSearchBufTestWholeWordAtEndDown, 'strings');
  lSuite.AddTest('TestEmptySearchString', @RunTTestSearchBufTestEmptySearchString, 'strings');
  lSuite.AddTest('TestSelstartBeforeBuf', @RunTTestSearchBufTestSelstartBeforeBuf, 'strings');
  lSuite.AddTest('testSelstartAfterBuf', @RunTTestSearchBuftestSelstartAfterBuf, 'strings');
  lSuite.AddTest('TestDecodeSoundexInt', @RunTTestSearchBufTestDecodeSoundexInt, 'strings');
  lSuite:=ARegistry.AddSuite('tcstrutils.TTestGeneral');
  lSuite.AddTest('TestIndexStr', @RunTTestGeneralTestIndexStr, 'strings');
  lSuite.AddTest('TestMatchStr', @RunTTestGeneralTestMatchStr, 'strings');
end;



initialization


  writeln ('Testing with ', WhichSearchbuf, ' implementation');
  writeln;
end.

