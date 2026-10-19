unit tctsutils;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, tsutils, tstypes;

Type

  { TTestUtilsCase }

  TTestUtilsCase = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FConfig : TConfig;
    FFileName : String;
    FDirectory : String;
    FReadResult : Boolean;
  Public
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    procedure DoRead;
    procedure CreateFile(const aLines : Array of string);
    Property ReadResult : Boolean Read FReadResult;
  public
    procedure TestNoFile;
    procedure TestEmptyFile;
    procedure TestNoPercent;
    procedure TestNoEndComment;
    procedure TestSpaces;
    procedure TestCodeAndNote;
    procedure TestConfig;
    procedure TestNeedOptions;
    procedure TestDelOptions;
    Procedure TestNeedTarget;
    Procedure TestSkipTarget;
    procedure TestNeedCPU;
    procedure TestSkipCPU;
    Procedure TestSkipEMU;
    Procedure TestMinVersion;
    Procedure TestMaxVersion;
    Procedure TestResultCode;
    Procedure TestUsesGraph;
    Procedure TestShouldFail;
    procedure TestNoRun;
    Procedure TestNeedLibrary;
    Procedure TestNeedAfter;
    procedure TestTimeout;
    procedure TestFiles;
    Procedure TestWPOParas;
    Procedure TestWPOPasses;
    Procedure TestDelFiles;
    Procedure TestInteractive;
  end;

procedure RegistertctsutilsTests(ARegistry: TNXTestRegistry);

implementation

{ TTestUtilsCase }

procedure TTestUtilsCase.SetUp;
var lId: TGUID;
begin
  FReadResult:=False;
  CreateGUID(lId);
  FDirectory:=IncludeTrailingPathDelimiter(GetTempDir(False))+'nxtest-directives-'+GUIDToString(lId);
  TestContext.AssertTrue(ForceDirectories(FDirectory), 'Create private directive fixture directory');
  FFileName:=IncludeTrailingPathDelimiter(FDirectory)+CaseName+'.pas';
end;

procedure TTestUtilsCase.TearDown;
begin
  if (FFileName<>'') and FileExists(FFileName) then
    if not DeleteFile(FFileName) then
      TestContext.Fail('Failed to delete file '+FFileName);
  if FDirectory<>'' then
    TestContext.AssertTrue(RemoveDir(FDirectory), 'Remove private directive fixture directory');
end;

procedure TTestUtilsCase.DoRead;
begin
  FReadResult:=GetConfig('tc',FFileName,FConfig);
end;

procedure TTestUtilsCase.CreateFile(const aLines: array of string);
var
  l : TStrings;
begin
  L:=TStringList.Create;
  try
    l.AddStrings(aLines,True);
    l.SaveToFile(FFileName);
  finally
    l.Free;
  end;
end;

procedure TTestUtilsCase.TestNoFile;
begin
  DoRead;
  TestContext.AssertTrue(not (ReadResult), 'Not read');
end;

procedure TTestUtilsCase.TestEmptyFile;
begin
  CreateFile([]);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
end;

procedure TTestUtilsCase.TestNoPercent;
begin
  CreateFile(['{CPU=X}']);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
  TestContext.AssertTrue(('')=(FCOnfig.NeedCPU), 'No value');
end;

procedure TTestUtilsCase.TestNoEndComment;
begin
  CreateFile(['{ %CPU=X']);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
  TestContext.AssertTrue(('')=(FConfig.NeedCPU), 'No value');
end;

procedure TTestUtilsCase.TestSpaces;
begin
  CreateFile(['{ %CPU = X }']);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
  TestContext.AssertTrue(('X')=(FConfig.NeedCPU), 'No value');
end;

procedure TTestUtilsCase.TestCodeAndNote;
begin
  CreateFile(['{%KNOWNRUNERROR=123X }']);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
  TestContext.AssertTrue((123)=(FConfig.KnownRunError), 'Runerror value');
  TestContext.AssertTrue(('X')=(FConfig.KnownRunNote), 'RunError note');
end;

procedure TTestUtilsCase.TestConfig;
begin
  CreateFile(['{%CONFIGFILE=X.CFG Y.CFG}']);
  DoRead;
  TestContext.AssertTrue(ReadResult, 'read');
  TestContext.AssertTrue(('X.CFG')=(FConfig.ConfigFileSrc), 'Runerror value');
  TestContext.AssertTrue(('Y.CFG')=(FConfig.ConfigFileDst), 'RunError note');
end;

procedure TTestUtilsCase.TestNeedOptions;
begin
  CreateFile(['{%OPT=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.NeedOptions), 'Value');;
end;

procedure TTestUtilsCase.TestDelOptions;
begin
  CreateFile(['{%DELOPT=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.DelOptions), 'Value');;
end;

procedure TTestUtilsCase.TestNeedTarget;
begin
  CreateFile(['{%TARGET=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.NeedTarget), 'Value');;
end;

procedure TTestUtilsCase.TestSkipTarget;
begin
  CreateFile(['{%SKIPTARGET=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.SkipTarget), 'Value');;
end;

procedure TTestUtilsCase.TestNeedCPU;
begin
  CreateFile(['{%SKIPEMU=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.SkipEmu), 'Value');;
end;

procedure TTestUtilsCase.TestSkipCPU;
begin
  CreateFile(['{%SKIPEMU=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.SkipEmu), 'Value');;
end;

procedure TTestUtilsCase.TestSkipEMU;
begin
  CreateFile(['{%SKIPEMU=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.SkipEmu), 'Value');;
end;

procedure TTestUtilsCase.TestMinVersion;
begin
  CreateFile(['{%VERSION=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.MinVersion), 'Value');;
end;

procedure TTestUtilsCase.TestMaxVersion;
begin
  CreateFile(['{%MAXVERSION=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.MaxVersion), 'Value');;
end;

procedure TTestUtilsCase.TestResultCode;
begin
  CreateFile(['{%RESULT=1}']);
  DoRead;
  TestContext.AssertTrue((1)=(FConfig.ResultCode), 'Value');
end;

procedure TTestUtilsCase.TestUsesGraph;
begin
  CreateFile(['{%GRAPH}']);
  DoRead;
  TestContext.AssertTrue(FConfig.UsesGraph, 'Value');
end;

procedure TTestUtilsCase.TestShouldFail;
begin
  CreateFile(['{%FAIL}']);
  DoRead;
  TestContext.AssertTrue(FConfig.ShouldFail, 'Value');
end;

procedure TTestUtilsCase.TestNoRun;
begin
  CreateFile(['{%NORUN}']);
  DoRead;
  TestContext.AssertTrue(FConfig.NoRun, 'Value');
end;

procedure TTestUtilsCase.TestNeedLibrary;
begin
  CreateFile(['{%NEEDLIBRARY}']);
  DoRead;
  TestContext.AssertTrue(FConfig.NeedLibrary, 'Value');
end;

procedure TTestUtilsCase.TestNeedAfter;
begin
  CreateFile(['{%NEEDEDAFTER}']);
  DoRead;
  TestContext.AssertTrue(FConfig.NeededAfter, 'Value');
end;

procedure TTestUtilsCase.TestTimeout;
begin
  CreateFile(['{%TIMEOUT=123}']);
  DoRead;
  TestContext.AssertTrue((123)=(FConfig.Timeout), 'Value')
end;

procedure TTestUtilsCase.TestFiles;
begin
  CreateFile(['{%FILES=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.Files), 'Value');;
end;

procedure TTestUtilsCase.TestWPOParas;
begin
  CreateFile(['{%WPOPARAS=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.wpoparas), 'Value');;
end;

procedure TTestUtilsCase.TestWPOPasses;
begin
  CreateFile(['{%WPOPASSES=2}']);
  DoRead;
  TestContext.AssertTrue((2)=(FConfig.wpopasses), 'Value');
end;

procedure TTestUtilsCase.TestDelFiles;
begin
  CreateFile(['{%DELFILES=XYZ}']);
  DoRead;
  TestContext.AssertTrue(('XYZ')=(FConfig.DelFiles), 'Value');
end;

procedure TTestUtilsCase.TestInteractive;
begin
  CreateFile(['{%INTERACTIVE}']);
  DoRead;
  TestContext.AssertTrue(FConfig.IsInteractive, 'Value');
end;


constructor TTestUtilsCase.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestUtilsCaseTestNoFile(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNoFile');
  try
    lFixture.SetUp;
    try lFixture.TestNoFile; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestEmptyFile(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestEmptyFile');
  try
    lFixture.SetUp;
    try lFixture.TestEmptyFile; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNoPercent(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNoPercent');
  try
    lFixture.SetUp;
    try lFixture.TestNoPercent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNoEndComment(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNoEndComment');
  try
    lFixture.SetUp;
    try lFixture.TestNoEndComment; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestSpaces(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestSpaces');
  try
    lFixture.SetUp;
    try lFixture.TestSpaces; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestCodeAndNote(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestCodeAndNote');
  try
    lFixture.SetUp;
    try lFixture.TestCodeAndNote; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestConfig(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestConfig');
  try
    lFixture.SetUp;
    try lFixture.TestConfig; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNeedOptions(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNeedOptions');
  try
    lFixture.SetUp;
    try lFixture.TestNeedOptions; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestDelOptions(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestDelOptions');
  try
    lFixture.SetUp;
    try lFixture.TestDelOptions; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNeedTarget(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNeedTarget');
  try
    lFixture.SetUp;
    try lFixture.TestNeedTarget; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestSkipTarget(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestSkipTarget');
  try
    lFixture.SetUp;
    try lFixture.TestSkipTarget; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNeedCPU(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNeedCPU');
  try
    lFixture.SetUp;
    try lFixture.TestNeedCPU; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestSkipCPU(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestSkipCPU');
  try
    lFixture.SetUp;
    try lFixture.TestSkipCPU; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestSkipEMU(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestSkipEMU');
  try
    lFixture.SetUp;
    try lFixture.TestSkipEMU; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestMinVersion(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestMinVersion');
  try
    lFixture.SetUp;
    try lFixture.TestMinVersion; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestMaxVersion(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestMaxVersion');
  try
    lFixture.SetUp;
    try lFixture.TestMaxVersion; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestResultCode(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestResultCode');
  try
    lFixture.SetUp;
    try lFixture.TestResultCode; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestUsesGraph(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestUsesGraph');
  try
    lFixture.SetUp;
    try lFixture.TestUsesGraph; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestShouldFail(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestShouldFail');
  try
    lFixture.SetUp;
    try lFixture.TestShouldFail; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNoRun(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNoRun');
  try
    lFixture.SetUp;
    try lFixture.TestNoRun; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNeedLibrary(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNeedLibrary');
  try
    lFixture.SetUp;
    try lFixture.TestNeedLibrary; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestNeedAfter(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestNeedAfter');
  try
    lFixture.SetUp;
    try lFixture.TestNeedAfter; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestTimeout(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestTimeout');
  try
    lFixture.SetUp;
    try lFixture.TestTimeout; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestFiles(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestFiles');
  try
    lFixture.SetUp;
    try lFixture.TestFiles; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestWPOParas(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestWPOParas');
  try
    lFixture.SetUp;
    try lFixture.TestWPOParas; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestWPOPasses(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestWPOPasses');
  try
    lFixture.SetUp;
    try lFixture.TestWPOPasses; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestDelFiles(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestDelFiles');
  try
    lFixture.SetUp;
    try lFixture.TestDelFiles; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestUtilsCaseTestInteractive(AContext: TNXTestContext);
var lFixture: TTestUtilsCase;
begin
  lFixture:=TTestUtilsCase.Create(AContext, 'TestInteractive');
  try
    lFixture.SetUp;
    try lFixture.TestInteractive; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertctsutilsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tctsutils.TTestUtilsCase');
  lSuite.AddTest('TestNoFile', @RunTTestUtilsCaseTestNoFile, 'compiler-utils');
  lSuite.AddTest('TestEmptyFile', @RunTTestUtilsCaseTestEmptyFile, 'compiler-utils');
  lSuite.AddTest('TestNoPercent', @RunTTestUtilsCaseTestNoPercent, 'compiler-utils');
  lSuite.AddTest('TestNoEndComment', @RunTTestUtilsCaseTestNoEndComment, 'compiler-utils');
  lSuite.AddTest('TestSpaces', @RunTTestUtilsCaseTestSpaces, 'compiler-utils');
  lSuite.AddTest('TestCodeAndNote', @RunTTestUtilsCaseTestCodeAndNote, 'compiler-utils');
  lSuite.AddTest('TestConfig', @RunTTestUtilsCaseTestConfig, 'compiler-utils');
  lSuite.AddTest('TestNeedOptions', @RunTTestUtilsCaseTestNeedOptions, 'compiler-utils');
  lSuite.AddTest('TestDelOptions', @RunTTestUtilsCaseTestDelOptions, 'compiler-utils');
  lSuite.AddTest('TestNeedTarget', @RunTTestUtilsCaseTestNeedTarget, 'compiler-utils');
  lSuite.AddTest('TestSkipTarget', @RunTTestUtilsCaseTestSkipTarget, 'compiler-utils');
  lSuite.AddTest('TestNeedCPU', @RunTTestUtilsCaseTestNeedCPU, 'compiler-utils');
  lSuite.AddTest('TestSkipCPU', @RunTTestUtilsCaseTestSkipCPU, 'compiler-utils');
  lSuite.AddTest('TestSkipEMU', @RunTTestUtilsCaseTestSkipEMU, 'compiler-utils');
  lSuite.AddTest('TestMinVersion', @RunTTestUtilsCaseTestMinVersion, 'compiler-utils');
  lSuite.AddTest('TestMaxVersion', @RunTTestUtilsCaseTestMaxVersion, 'compiler-utils');
  lSuite.AddTest('TestResultCode', @RunTTestUtilsCaseTestResultCode, 'compiler-utils');
  lSuite.AddTest('TestUsesGraph', @RunTTestUtilsCaseTestUsesGraph, 'compiler-utils');
  lSuite.AddTest('TestShouldFail', @RunTTestUtilsCaseTestShouldFail, 'compiler-utils');
  lSuite.AddTest('TestNoRun', @RunTTestUtilsCaseTestNoRun, 'compiler-utils');
  lSuite.AddTest('TestNeedLibrary', @RunTTestUtilsCaseTestNeedLibrary, 'compiler-utils');
  lSuite.AddTest('TestNeedAfter', @RunTTestUtilsCaseTestNeedAfter, 'compiler-utils');
  lSuite.AddTest('TestTimeout', @RunTTestUtilsCaseTestTimeout, 'compiler-utils');
  lSuite.AddTest('TestFiles', @RunTTestUtilsCaseTestFiles, 'compiler-utils');
  lSuite.AddTest('TestWPOParas', @RunTTestUtilsCaseTestWPOParas, 'compiler-utils');
  lSuite.AddTest('TestWPOPasses', @RunTTestUtilsCaseTestWPOPasses, 'compiler-utils');
  lSuite.AddTest('TestDelFiles', @RunTTestUtilsCaseTestDelFiles, 'compiler-utils');
  lSuite.AddTest('TestInteractive', @RunTTestUtilsCaseTestInteractive, 'compiler-utils');
end;

end.
