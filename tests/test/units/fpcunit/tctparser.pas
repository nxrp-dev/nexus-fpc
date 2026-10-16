{$mode objfpc}
{$h+}
unit tctparser;

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

  { TTestToString }
type
  TTestToString= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
    procedure Test3;
    procedure Test4;
    procedure Test5;
    procedure Test6;
    procedure Test7;
    procedure Test8;
    procedure Test9;
    procedure Test10;
    procedure Test11;
    procedure Test12;
    procedure Test13;
    procedure Test14;
    procedure Test15;
    procedure Test16;
    procedure Test17;
  end;

  { TTestTokenInt }

  TTestTokenInt= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
    procedure Test3;
  end;

  { TTestTokenFloat }

  TTestTokenFloat= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
    procedure Test3;
    procedure Test4;
    procedure Test5;
    procedure Test6;
  end;

  { TTestSymbol }

  TTestSymbol= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
    procedure Test3;
  end;

  { TTestPositions }

  TTestPositions= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
  end;

  { TTestBinary }

  TTestBinary= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    fStream : TMemoryStream;
    fOutStr : TMemoryStream;
    fPar : TParser;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure Test1;
    procedure Test2;
  end;

procedure RegistertctparserTests(ARegistry: TNXTestRegistry);

Implementation

{ ---------------------------------------------------------------------
    TTestToString
  ---------------------------------------------------------------------}


procedure TTestToString.Test1;
const
  aStr = '- 10';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken('-');
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('-')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken(toInteger);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('10')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test2;
const
  aStr = '-10';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toInteger);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('-10')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test3;
const
  aStr = '$AFz';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toInteger);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('$AF')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken(toSymbol);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('z')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test4;
const
  aStr : string = '$';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  try
    fPar:=TParser.Create(fStream);
  except
    on e : EParserError do exit
    else
    begin
      fPar.Free;
      TestContext.Fail('EParserError should be raised');
    end;
  end;
  fPar.Free;
  TestContext.Fail('EParserError should be raised');
end;

procedure TTestToString.Test5;
const
  aStr = '1.';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toFloat);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('1.')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test6;
const
  aStr = '1.0';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toFloat);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('1.0')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test7;
const
  aStr = '1E';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  try
    fPar:=TParser.Create(fStream);
  except
    on e : EParserError do exit
    else
    begin
      fPar.Free;
      TestContext.Fail('EParserError should be raised');
    end;
  end;
  fPar.Free;
  TestContext.Fail('EParserError should be raised');
end;

procedure TTestToString.Test8;
const
  aStr = '1E+';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  try
    fPar:=TParser.Create(fStream);
  except
    on e : EParserError do exit
    else
    begin
      fPar.Free;
      TestContext.Fail('EParserError should be raised');
    end;
  end;
  fPar.Free;
  TestContext.Fail('EParserError should be raised');
end;

procedure TTestToString.Test9;
const
  aStr = '1.E+2';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toFloat);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('1.E+2')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test10;
const
  aStr = '1.E+2a';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toFloat);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('1.E+2')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken(toSymbol);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('a')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test11;
const
  aStr = '12s';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toFloat);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('12s')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test12;
const
  aStr = '''string'''; //'string'
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(Classes.toString);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('string')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test13;
const
  aStr = '''can''''t'''; //'can''t'
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(Classes.toString);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('can''t')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test14;
const
  aStr = '''c''#97#110''''''''#116#32''open file''';  //'c'#97#110''''#116#32'open file'
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(Classes.toString);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('can''t open file')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test15;
const
  aStr = '''perch''#232';
var ws : widestring;
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  ws:='perch'#232;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toWString);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue((ws)=(fPar.TokenWideString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.Test16;
const
  aStr = '''unterminated string'#10'blah''';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  try
    fPar:=TParser.Create(fStream);
  except
    on e : EParserError do exit
    else
    begin
      fPar.Free;
      TestContext.Fail('EParserError should be raised');
    end;
  end;
  fPar.Free;
  TestContext.Fail('EParserError should be raised');
end;

procedure TTestToString.Test17;
const
  aStr = 'first.second.third';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.CheckToken(toSymbol);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('first')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken('.');
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('.')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken(toSymbol);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('second')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken('.');
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('.')=(fPar.TokenString), '');
    fPar.NextToken;
    try
      fPar.CheckToken(toSymbol);
    except
      on e : EParserError do TestContext.Fail('CheckToken failed');
    end;
    TestContext.AssertTrue(('third')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestToString.SetUp;
begin
  fStream:=TMemoryStream.Create;
end;

procedure TTestToString.TearDown;
begin
  fStream.Free;
end;

{ ---------------------------------------------------------------------
    TTestTokenInt
  ---------------------------------------------------------------------}


procedure TTestTokenInt.Test1;
const
  aStr = '10';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toInteger)=(fPar.Token), '');
    TestContext.AssertTrue((10)=(fPar.TokenInt), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenInt.Test2;
const
  aStr = '-10';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toInteger)=(fPar.Token), '');
    TestContext.AssertTrue((-10)=(fPar.TokenInt), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenInt.Test3;
const
  aStr = '$AF';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toInteger)=(fPar.Token), '');
    TestContext.AssertTrue(($AF)=(fPar.TokenInt), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenInt.SetUp;
begin
  fStream:=TMemoryStream.Create;
end;

procedure TTestTokenInt.TearDown;
begin
  fStream.Free;
end;

{ ---------------------------------------------------------------------
    TTestTokenFloat
  ---------------------------------------------------------------------}

procedure TTestTokenFloat.Test1;
const
  aStr = '1.';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((1.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue((#0)=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.Test2;
const
  aStr = '1.0';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((1.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue((#0)=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.Test3;
const
  aStr = '1.E+2';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((100.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue((#0)=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.Test4;
const
  aStr = '12s';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((12.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue(('s')=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.Test5;
const
  aStr = '12d';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((12.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue(('d')=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.Test6;
const
  aStr = '12c';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue((toFloat)=(fPar.Token), '');
    TestContext.AssertTrue((12.0)=(fPar.TokenFloat), '');
    TestContext.AssertTrue(('c')=(fPar.FloatType), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestTokenFloat.SetUp;
begin
  fStream:=TMemoryStream.Create;
end;

procedure TTestTokenFloat.TearDown;
begin
  fStream.Free;
end;

{ ---------------------------------------------------------------------
    TTestSymbol
  ---------------------------------------------------------------------}


procedure TTestSymbol.Test1;
const
  aStr = 'hello world';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue(fPar.TokenSymbolIs('HELLO'), '');
    try
      fPar.CheckTokenSymbol('HeLlO');
    except
      on e : EParserError do TestContext.Fail('CheckTokenSymbol failed');
    end;
    TestContext.AssertTrue(('hello')=(fPar.TokenComponentIdent), '');
    fPar.NextToken;
    TestContext.AssertTrue(fPar.TokenSymbolIs('world'), '');
    try
      fPar.CheckTokenSymbol('wOrLd');
    except
      on e : EParserError do TestContext.Fail('CheckTokenSymbol failed');
    end;
    TestContext.AssertTrue(('world')=(fPar.TokenComponentIdent), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestSymbol.Test2;
const
  aStr = 'first.second.third';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue(fPar.TokenSymbolIs('first'), '');
    try
      fPar.CheckTokenSymbol('first');
    except
      on e : EParserError do TestContext.Fail('CheckTokenSymbol failed');
    end;
    TestContext.AssertTrue(('first')=(fPar.TokenString), '');
    TestContext.AssertTrue(('first.second.third')=(fPar.TokenComponentIdent), '');
    TestContext.AssertTrue(('first.second.third')=(fPar.TokenString), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestSymbol.Test3;
const
  aStr = 'first.';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    TestContext.AssertTrue(fPar.TokenSymbolIs('first'), '');
    try
      fPar.CheckTokenSymbol('first');
    except
      on e : EParserError do TestContext.Fail('CheckTokenSymbol failed');
    end;
    TestContext.AssertTrue(('first')=(fPar.TokenString), '');
    try
      fPar.TokenComponentIdent;
    except
      on e : EParserError do exit
      else
        TestContext.Fail('EParserError should be raised');
    end;
    TestContext.Fail('EParserError should be raised');
  finally
    fPar.Free;
  end;
end;

procedure TTestSymbol.SetUp;
begin
  fStream:=TMemoryStream.Create;
end;

procedure TTestSymbol.TearDown;
begin
  fStream.Free;
end;

{ ---------------------------------------------------------------------
    TTestPositions
  ---------------------------------------------------------------------}


procedure TTestPositions.Test1;
const
  aStr = 'this is'#10'a '#13'test.'#13#10'Another line';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    //this
    TestContext.AssertTrue((1)=(fPar.SourceLine), '');
    TestContext.AssertTrue((4)=(fPar.SourcePos), '');
    //is
    fPar.NextToken;
    TestContext.AssertTrue((1)=(fPar.SourceLine), '');
    TestContext.AssertTrue((7)=(fPar.SourcePos), '');
    //a
    fPar.NextToken;
    TestContext.AssertTrue((2)=(fPar.SourceLine), '');
    TestContext.AssertTrue((9)=(fPar.SourcePos), '');
    //test
    fPar.NextToken;
    TestContext.AssertTrue((3)=(fPar.SourceLine), '');
    TestContext.AssertTrue((15)=(fPar.SourcePos), '');
    //.
    fPar.NextToken;
    TestContext.AssertTrue((3)=(fPar.SourceLine), '');
    TestContext.AssertEquals(Length(aStr),fPar.SourcePos,'Position after the following identifier');
    TestContext.AssertEquals('somethingelse',fPar.TokenString,'Following token');
    //Another
    fPar.NextToken;
    TestContext.AssertTrue((4)=(fPar.SourceLine), '');
    TestContext.AssertTrue((25)=(fPar.SourcePos), '');
    //line
    fPar.NextToken;
    TestContext.AssertTrue((4)=(fPar.SourceLine), '');
    TestContext.AssertTrue((30)=(fPar.SourcePos), '');
    //eof
    fPar.NextToken;
    TestContext.AssertTrue((4)=(fPar.SourceLine), '');
    TestContext.AssertTrue((30)=(fPar.SourcePos), '');
    TestContext.AssertTrue((toEOF)=(fPar.Token), '');
  finally
    fPar.Free;
  end;
end;

procedure TTestPositions.Test2;
const
  aStr = 'this is a test';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    //this
    fPar.NextToken;
    //is
  finally
    fPar.Free;
  end;
  TestContext.AssertTrue((7)=(fStream.Position), '');
end;

procedure TTestPositions.SetUp;
begin
  fStream:=TMemoryStream.Create;
end;

procedure TTestPositions.TearDown;
begin
  fStream.Free;
end;

{ ---------------------------------------------------------------------
    TTestBinary
  ---------------------------------------------------------------------}

procedure TTestBinary.Test1;
const
  aStr = '{ 1234 56'+#13#10'789A somethingelse';
var buf : array[0..4] of byte = ($12,$34,$56,$78,$9A);
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fOutStr.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    fPar.HexToBinary(fOutStr);
    TestContext.AssertTrue((5)=(fOutStr.Size), '');
    TestContext.AssertTrue(CompareMem(@buf[0],fOutStr.Memory,5), '');
    TestContext.AssertEquals(Length(aStr),fPar.SourcePos,'Position after the following identifier');
    TestContext.AssertEquals('somethingelse',fPar.TokenString,'Following token');
  finally
    fPar.Free;
  end;
end;

procedure TTestBinary.Test2;
const
  aStr = '{ 123z';
begin
  fStream.WriteBuffer(aStr[1],length(aStr));
  fStream.Position:=0;
  fOutStr.Position:=0;
  fPar:=TParser.Create(fStream);
  try
    try
      fPar.HexToBinary(fOutStr);
    except
      on e : EParserError do exit
      else TestContext.Fail('EParserError should be raised');
    end;
    TestContext.Fail('EParserError should be raised');
  finally
    fPar.Free;
  end;
end;

procedure TTestBinary.SetUp;
begin
  fStream:=TMemoryStream.Create;
  fOutStr:=TMemoryStream.Create;
end;

procedure TTestBinary.TearDown;
begin
  fStream.Free;
  fOutStr.Free;
end;


constructor TTestToString.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestTokenInt.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestTokenFloat.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestSymbol.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestPositions.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestBinary.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestToStringTest1(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest2(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest3(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest4(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test4');
  try
    lFixture.SetUp;
    try lFixture.Test4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest5(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test5');
  try
    lFixture.SetUp;
    try lFixture.Test5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest6(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test6');
  try
    lFixture.SetUp;
    try lFixture.Test6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest7(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test7');
  try
    lFixture.SetUp;
    try lFixture.Test7; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest8(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test8');
  try
    lFixture.SetUp;
    try lFixture.Test8; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest9(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test9');
  try
    lFixture.SetUp;
    try lFixture.Test9; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest10(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test10');
  try
    lFixture.SetUp;
    try lFixture.Test10; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest11(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test11');
  try
    lFixture.SetUp;
    try lFixture.Test11; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest12(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test12');
  try
    lFixture.SetUp;
    try lFixture.Test12; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest13(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test13');
  try
    lFixture.SetUp;
    try lFixture.Test13; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest14(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test14');
  try
    lFixture.SetUp;
    try lFixture.Test14; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest15(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test15');
  try
    lFixture.SetUp;
    try lFixture.Test15; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest16(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test16');
  try
    lFixture.SetUp;
    try lFixture.Test16; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestToStringTest17(AContext: TNXTestContext);
var lFixture: TTestToString;
begin
  lFixture:=TTestToString.Create(AContext, 'Test17');
  try
    lFixture.SetUp;
    try lFixture.Test17; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenIntTest1(AContext: TNXTestContext);
var lFixture: TTestTokenInt;
begin
  lFixture:=TTestTokenInt.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenIntTest2(AContext: TNXTestContext);
var lFixture: TTestTokenInt;
begin
  lFixture:=TTestTokenInt.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenIntTest3(AContext: TNXTestContext);
var lFixture: TTestTokenInt;
begin
  lFixture:=TTestTokenInt.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest1(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest2(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest3(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest4(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test4');
  try
    lFixture.SetUp;
    try lFixture.Test4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest5(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test5');
  try
    lFixture.SetUp;
    try lFixture.Test5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTokenFloatTest6(AContext: TNXTestContext);
var lFixture: TTestTokenFloat;
begin
  lFixture:=TTestTokenFloat.Create(AContext, 'Test6');
  try
    lFixture.SetUp;
    try lFixture.Test6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSymbolTest1(AContext: TNXTestContext);
var lFixture: TTestSymbol;
begin
  lFixture:=TTestSymbol.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSymbolTest2(AContext: TNXTestContext);
var lFixture: TTestSymbol;
begin
  lFixture:=TTestSymbol.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSymbolTest3(AContext: TNXTestContext);
var lFixture: TTestSymbol;
begin
  lFixture:=TTestSymbol.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBinaryTest1(AContext: TNXTestContext);
var lFixture: TTestBinary;
begin
  lFixture:=TTestBinary.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBinaryTest2(AContext: TNXTestContext);
var lFixture: TTestBinary;
begin
  lFixture:=TTestBinary.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertctparserTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tctparser.TTestToString');
  lSuite.AddTest('Test1', @RunTTestToStringTest1);
  lSuite.AddTest('Test2', @RunTTestToStringTest2);
  lSuite.AddTest('Test3', @RunTTestToStringTest3);
  lSuite.AddTest('Test4', @RunTTestToStringTest4);
  lSuite.AddTest('Test5', @RunTTestToStringTest5);
  lSuite.AddTest('Test6', @RunTTestToStringTest6);
  lSuite.AddTest('Test7', @RunTTestToStringTest7);
  lSuite.AddTest('Test8', @RunTTestToStringTest8);
  lSuite.AddTest('Test9', @RunTTestToStringTest9);
  lSuite.AddTest('Test10', @RunTTestToStringTest10);
  lSuite.AddTest('Test11', @RunTTestToStringTest11);
  lSuite.AddTest('Test12', @RunTTestToStringTest12);
  lSuite.AddTest('Test13', @RunTTestToStringTest13);
  lSuite.AddTest('Test14', @RunTTestToStringTest14);
  lSuite.AddTest('Test15', @RunTTestToStringTest15);
  lSuite.AddTest('Test16', @RunTTestToStringTest16);
  lSuite.AddTest('Test17', @RunTTestToStringTest17);
  lSuite:=ARegistry.AddSuite('tctparser.TTestTokenInt');
  lSuite.AddTest('Test1', @RunTTestTokenIntTest1);
  lSuite.AddTest('Test2', @RunTTestTokenIntTest2);
  lSuite.AddTest('Test3', @RunTTestTokenIntTest3);
  lSuite:=ARegistry.AddSuite('tctparser.TTestTokenFloat');
  lSuite.AddTest('Test1', @RunTTestTokenFloatTest1);
  lSuite.AddTest('Test2', @RunTTestTokenFloatTest2);
  lSuite.AddTest('Test3', @RunTTestTokenFloatTest3);
  lSuite.AddTest('Test4', @RunTTestTokenFloatTest4);
  lSuite.AddTest('Test5', @RunTTestTokenFloatTest5);
  lSuite.AddTest('Test6', @RunTTestTokenFloatTest6);
  lSuite:=ARegistry.AddSuite('tctparser.TTestSymbol');
  lSuite.AddTest('Test1', @RunTTestSymbolTest1);
  lSuite.AddTest('Test2', @RunTTestSymbolTest2);
  lSuite.AddTest('Test3', @RunTTestSymbolTest3);
  lSuite:=ARegistry.AddSuite('tctparser.TTestBinary');
  lSuite.AddTest('Test1', @RunTTestBinaryTest1);
  lSuite.AddTest('Test2', @RunTTestBinaryTest2);
end;

end.
