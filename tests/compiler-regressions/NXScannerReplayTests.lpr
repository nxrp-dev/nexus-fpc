// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NXScannerReplayTests;

{$mode objfpc}{$H+}

uses
  Scanner, WideStr, Tokens, GlobType, Globals, CClasses, CompHook, Verbose,
  obNXTestRegistry, obNXTestContext, utNXTestConsole;

procedure WideInputSurvivesSnapshot(AContext: TNXTestContext);
var
  lInput: TCompilerWideString;
  lSnapshot: TReplayStack;
begin
  InitWideString(lInput);
  try
    ConcatWideStringChar(lInput, 65);
    ConcatWideStringChar(lInput, 66);
    lSnapshot := TReplayStack.Create(NOTOKEN, NOTOKEN, '', '', '', lInput,
      Default(TSettings), nil, Default(TPendingState), 0, nil);
    try
      AContext.AssertEquals(2, lInput.Len,
        'Creating a replay snapshot must preserve the caller wide-string length');
      AContext.AssertTrue((lInput.Data[0] = 65) and (lInput.Data[1] = 66),
        'Creating a replay snapshot must preserve the caller wide-string contents');
    finally
      lSnapshot.Free;
    end;
  finally
    DoneWideString(lInput);
  end;
end;

procedure MessageCountBoundary(AContext: TNXTestContext; ACount: Integer);
var
  lScanner: TScannerFile;
  lBuffer: TDynamicArray;
  lSavedSettings: TSettings;
  lSavedPending: TPendingState;
  lMessage: PMessageStateRecord;
  lIndex, lRestored: Integer;
begin
  lSavedSettings := CurrentSettings;
  lSavedPending := PendingState;
  CurrentSettings := Default(TSettings);
  PendingState := Default(TPendingState);
  lScanner := TScannerFile.Create('', True);
  lBuffer := TDynamicArray.Create(4096);
  try
    for lIndex := 1 to ACount do
    begin
      New(lMessage);
      lMessage^ := Default(TMessageStateRecord);
      { Repeated changes must collapse to the newest state. This token value
        also keeps unread message bytes harmless if replay stops too early. }
      lMessage^.Value := Ord(_SEMICOLON);
      lMessage^.State := ms_on;
      lMessage^.Next := CurrentSettings.PMessage;
      CurrentSettings.PMessage := lMessage;
    end;
    lScanner.StartRecordTokens(lBuffer);
    CurrentSettings.Verbosity := Status.Verbosity;
    lScanner.FLastSettings := CurrentSettings;
    lScanner.FLastFilePos := CurrentTokenPos;
    lScanner.FToken := _SEMICOLON;
    lScanner.FIDToken := _NOID;
    lScanner.RecordToken;
    lScanner.StopRecordTokens;
    FreeLocalVerbosity(CurrentSettings.PMessage);
    lScanner.FReplayTokenBuf := lBuffer;
    lBuffer.Seek(0);
    lScanner.ReplayToken;
    lRestored := 0;
    lMessage := PendingState.NextMessageRecord;
    while Assigned(lMessage) do
    begin
      Inc(lRestored);
      lMessage := lMessage^.Next;
    end;
    AContext.AssertEquals(1, lRestored,
      'Replay must restore the newest message state at this record count');
    AContext.AssertTrue(lBuffer.Pos = lBuffer.Size,
      'Replay must consume all message records and the following token');
    AContext.AssertTrue(lScanner.FToken = _SEMICOLON,
      'Replay must retain the token following the message records');
  finally
    FreeLocalVerbosity(CurrentSettings.PMessage);
    FreeLocalVerbosity(PendingState.NextMessageRecord);
    lScanner.Free;
    lBuffer.Free;
    CurrentSettings := lSavedSettings;
    PendingState := lSavedPending;
  end;
end;

procedure Messages255(AContext: TNXTestContext);
begin
  MessageCountBoundary(AContext, 255);
end;

procedure Messages256(AContext: TNXTestContext);
begin
  MessageCountBoundary(AContext, 256);
end;

var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.Scanner.Replay').AddTest(
      'WideInputSurvivesSnapshot', @WideInputSurvivesSnapshot, 'compiler-scanner');
    lRegistry.AddSuite('Compiler.Scanner.Replay.MessageCounts').AddTest(
      'Messages255', @Messages255, 'compiler-scanner');
    lRegistry.Suites[lRegistry.SuiteCount - 1].AddTest(
      'Messages256', @Messages256, 'compiler-scanner');
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
