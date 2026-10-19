program nxResourceRuntimeTests;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  obNXTestRegistry, obNXTestContext, utNXTestConsole,
  Classes, SysUtils, ResourceCatalog;

var TestContext: TNXTestContext;

{$R runtimetables.res}

type
{$ifdef windows}
  TResourceNamePointer = PWideChar;
{$else}
  TResourceNamePointer = PAnsiChar;
{$endif}
  TTestEnumTypeProc = function(AModule: TFPResourceHMODULE;
    AType: TResourceNamePointer; AParam: PtrInt): LongBool; stdcall;
  TTestEnumNameProc = function(AModule: TFPResourceHMODULE;
    AType, AName: TResourceNamePointer; AParam: PtrInt): LongBool; stdcall;
  TTestEnumLanguageProc = function(AModule: TFPResourceHMODULE;
    AType, AName: TResourceNamePointer; ALanguage: Word;
    AParam: PtrInt): LongBool; stdcall;

{$ifdef windows}
{ The Windows RTL's System enumeration/lookup wrappers use the ANSI APIs.
  Exercise all Unicode identities through the native wide APIs, plus the RTL
  ANSI stream/lookup contract below. Do not depend on the machine's ANSI page. }
function NativeEnumTypes(AModule: TFPResourceHMODULE; ACallback: TTestEnumTypeProc;
  AParam: PtrInt): LongBool; stdcall; external 'kernel32' name 'EnumResourceTypesW';
function NativeEnumNames(AModule: TFPResourceHMODULE; AType: TResourceNamePointer;
  ACallback: TTestEnumNameProc; AParam: PtrInt): LongBool; stdcall;
  external 'kernel32' name 'EnumResourceNamesW';
function NativeEnumLanguages(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  ACallback: TTestEnumLanguageProc; AParam: PtrInt): LongBool; stdcall;
  external 'kernel32' name 'EnumResourceLanguagesW';
function NativeFindResourceEx(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  ALanguage: Word): TFPResourceHandle; stdcall; external 'kernel32' name 'FindResourceExW';
{$else}
function NativeEnumTypes(AModule: TFPResourceHMODULE; ACallback: TTestEnumTypeProc;
  AParam: PtrInt): LongBool;
begin
  Result := System.EnumResourceTypes(AModule, ACallback, AParam);
end;

function NativeEnumNames(AModule: TFPResourceHMODULE; AType: TResourceNamePointer;
  ACallback: TTestEnumNameProc; AParam: PtrInt): LongBool;
begin
  Result := System.EnumResourceNames(AModule, AType, ACallback, AParam);
end;

function NativeEnumLanguages(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  ACallback: TTestEnumLanguageProc; AParam: PtrInt): LongBool;
begin
  Result := System.EnumResourceLanguages(AModule, AType, AName, ACallback, AParam);
end;

function NativeFindResourceEx(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  ALanguage: Word): TFPResourceHandle;
begin
  Result := System.FindResourceEx(AModule, AType, AName, ALanguage);
end;
{$endif}

var
  LExpected: TResourceCatalog;
  LEnumerated: Integer;
  LFixture: string;

const
  CRawData = PAnsiChar(PtrUInt(10));

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  TestContext.AssertTrue(ACondition, AMessage);
end;

function Key(AValue: TResourceNamePointer): TResourceKey;
begin
  if PtrUInt(AValue) <= High(Word) then Result := ResourceId(PtrUInt(AValue))
{$ifdef windows}
  else Result := ResourceName(UnicodeString(AValue));
{$else}
  else Result := ResourceName(UTF8Decode(AValue));
{$endif}
end;

function EnumerateLanguage(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  ALanguage: Word; AParam: PtrInt): LongBool; stdcall;
var
  LEntry: TResourceEntry;
  LHandle: TFPResourceHandle;
  LData: TFPResourceHGLOBAL;
  LPointer: Pointer;
begin
  LEntry := LExpected.Find(Key(AType), Key(AName), ALanguage);
  Check(LEntry <> nil, 'Unexpected enumerated resource');
  LHandle := NativeFindResourceEx(AModule, AType, AName, ALanguage);
  Check(LHandle <> 0, 'FindResourceEx failed');
  Check(NativeFindResourceEx(AModule, AType, AName, ALanguage) = LHandle,
    'Repeated lookup allocated another handle');
  Check(SizeofResource(AModule, LHandle) = Cardinal(Length(LEntry.Data)),
    'Resource size differs');
  LData := LoadResource(AModule, LHandle);
  Check(LData <> 0, 'LoadResource failed');
  LPointer := LockResource(LData);
  Check(LPointer <> nil, 'LockResource failed');
  if Length(LEntry.Data) <> 0 then
    Check(CompareMem(LPointer, @LEntry.Data[0], Length(LEntry.Data)),
      'Runtime resource payload differs');
{$ifdef windows}
  { These RTL wrappers both forward to the deprecated Windows FreeResource.
    Classes ignores their return values; check that subsequent access survives. }
  UnlockResource(LData);
  FreeResource(LData);
  Check(NativeFindResourceEx(AModule, AType, AName, ALanguage) = LHandle,
    'Windows cleanup changed the resource handle');
{$else}
  Check(UnlockResource(LData), 'UnlockResource failed');
  Check(FreeResource(LData), 'FreeResource failed');
{$endif}
  Inc(LEnumerated);
  Result := True;
end;

function EnumerateName(AModule: TFPResourceHMODULE; AType, AName: TResourceNamePointer;
  AParam: PtrInt): LongBool; stdcall;
begin
  Result := NativeEnumLanguages(AModule, AType, AName, @EnumerateLanguage, 0);
  Check(Result, 'EnumResourceLanguages failed');
end;

function EnumerateType(AModule: TFPResourceHMODULE; AType: TResourceNamePointer;
  AParam: PtrInt): LongBool; stdcall;
begin
  Result := NativeEnumNames(AModule, AType, @EnumerateName, 0);
  Check(Result, 'EnumResourceNames failed');
end;

procedure CheckStream(const AName: string; AType: PAnsiChar;
  const AExpected: RawByteString);
var
  LStream: TResourceStream;
  LValue: RawByteString;
begin
  LStream := TResourceStream.Create(HInstance, AName, AType);
  try
    SetLength(LValue, LStream.Size);
    if LValue <> '' then LStream.ReadBuffer(LValue[1], Length(LValue));
    Check(LValue = AExpected, 'TResourceStream payload differs');
  finally
    LStream.Free;
  end;
end;

procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    Check(ParamCount <= 1, 'Expected at most one table fixture RES filename');
    if ParamCount = 1 then LFixture := ParamStr(1)
    else LFixture := ExtractFilePath(ParamStr(0)) + 'runtimetables.res';
    LExpected := TResourceCatalog.Create;
    try
      LExpected.LoadRes(LFixture);
      Check(NativeEnumTypes(HInstance, @EnumerateType, 0), 'EnumResourceTypes failed');
      Check(LEnumerated = LExpected.Count, 'Resource enumeration count differs');
      CheckStream('alpha', CRawData, 'alpha');
{$ifndef windows}
      CheckStream('café', PAnsiChar('雪'), 'unicode type');
{$endif}
      Check(System.FindResource(HInstance, PAnsiChar('ALPHA'), CRawData) <> 0,
        'RTL ASCII lookup failed');
      Check(System.FindResource(HInstance, PAnsiChar('missing'), CRawData) = 0,
        'Missing resource lookup succeeded');
      WriteLn('PASS native resource APIs: ', LEnumerated,
        ' resources, enumeration, languages, repeated handles, payloads and streams');
    finally
      LExpected.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAIL ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      TestContext.Fail(E.ClassName + ': ' + E.Message);
    end;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Resources.Runtime').AddTest('EnumerationLookupAndStreams', @RunCase, 'resources');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
