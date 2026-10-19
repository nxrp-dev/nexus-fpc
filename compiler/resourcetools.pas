(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceTools;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ResourceCatalog;

type
  EResourceTool = class(EResourceCatalog);
  TResourceArguments = array of AnsiString;

  TResourceToolCommand = record
    Executable: string;
    Arguments: TResourceArguments;
  end;

  TResourceCompilePlan = record
    Preprocess: TResourceToolCommand;
    Compile: TResourceToolCommand;
    PreprocessedFile: string;
    DependencyFile: string;
    RawResFile: string;
  end;

  TResourceCommandEvent = procedure(const ACommand: TResourceToolCommand) of object;

  TLLVMResourceCompiler = class
  private
    FIncludeDirectories: TStringList;
    FMacroArguments: TStringList;
    FOnCommand: TResourceCommandEvent;
    procedure CheckEncoding(const AFileName, ASource: string);
    procedure Run(const ACommand: TResourceToolCommand;
      const ASource, AStage: string);
  public
    ClangPath: string;
    RCPath: string;
    TargetTriple: string;
    CodePage: Cardinal;
    constructor Create;
    destructor Destroy; override;
    procedure Define(const AName: string); overload;
    procedure Define(const AName, AValue: string); overload;
    procedure Undefine(const AName: string);
    { The caller owns an exclusive scratch prefix. Planning does not execute
      tools or create files; commands can also be inspected/logged by callers. }
    function Plan(const ASource, AScratchPrefix: string): TResourceCompilePlan;
    { Always refresh RC inputs. The Clang depfile does not cover binary RC
      payload references. No canonical artifact is published by this method. }
    procedure CompileRC(ACatalog: TResourceCatalog;
      const ASource, AScratchPrefix: string);
    property IncludeDirectories: TStringList read FIncludeDirectories;
    property MacroArguments: TStringList read FMacroArguments;
    property OnCommand: TResourceCommandEvent read FOnCommand write FOnCommand;
  end;

function WindowsResourceArguments(const AArguments: TResourceArguments): UnicodeString;

implementation

procedure AddArgument(var ACommand: TResourceToolCommand; const AValue: string);
var
  LCount: Integer;
begin
  if Pos(#0, AValue) <> 0 then
    raise EResourceTool.Create('NUL byte in resource tool argument');
  LCount := Length(ACommand.Arguments);
  SetLength(ACommand.Arguments, LCount + 1);
  ACommand.Arguments[LCount] := AValue;
end;

function WindowsResourceArguments(const AArguments: TResourceArguments): UnicodeString;
var
  LArgument: UnicodeString;
  LIndex, LCharacter, LSlashes: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AArguments) do
  begin
    if LIndex <> 0 then Result := Result + ' ';
    Result := Result + '"';
    LArgument := UnicodeString(AArguments[LIndex]);
    LSlashes := 0;
    for LCharacter := 1 to Length(LArgument) do
      case LArgument[LCharacter] of
        '\': Inc(LSlashes);
        '"': begin
               Result := Result + UnicodeString(StringOfChar('\', LSlashes * 2 + 1)) + '"';
               LSlashes := 0;
             end;
        else begin
          Result := Result + UnicodeString(StringOfChar('\', LSlashes)) +
            LArgument[LCharacter];
          LSlashes := 0;
        end;
      end;
    Result := Result + UnicodeString(StringOfChar('\', LSlashes * 2)) + '"';
  end;
end;

constructor TLLVMResourceCompiler.Create;
begin
  inherited Create;
  FIncludeDirectories := TStringList.Create;
  FMacroArguments := TStringList.Create;
  CodePage := 65001;
end;

destructor TLLVMResourceCompiler.Destroy;
begin
  FMacroArguments.Free;
  FIncludeDirectories.Free;
  inherited Destroy;
end;

procedure TLLVMResourceCompiler.Define(const AName: string);
begin
  FMacroArguments.Add('-D' + AName);
end;

procedure TLLVMResourceCompiler.Define(const AName, AValue: string);
begin
  FMacroArguments.Add('-D' + AName + '=' + AValue);
end;

procedure TLLVMResourceCompiler.Undefine(const AName: string);
begin
  FMacroArguments.Add('-U' + AName);
end;

function TLLVMResourceCompiler.Plan(const ASource,
  AScratchPrefix: string): TResourceCompilePlan;
var
  LSource, LPrefix: string;
  LIndex: Integer;

  procedure AddInclude(const ADirectory: string);
  begin
    AddArgument(Result.Preprocess, '-I');
    AddArgument(Result.Preprocess, ADirectory);
    AddArgument(Result.Compile, '/I');
    AddArgument(Result.Compile, ADirectory);
  end;

begin
  if ClangPath = '' then
    raise EResourceTool.Create('Clang resource preprocessor was not found');
  if RCPath = '' then
    raise EResourceTool.Create('LLVM RC compiler was not found');
  if (ClangPath = '') or (RCPath = '') or (TargetTriple = '') or
     (ASource = '') or (AScratchPrefix = '') or (CodePage = 0) then
    raise EResourceTool.Create('Resource tools require Clang, LLVM RC, target, source, scratch prefix and explicit codepage');
  LSource := ExpandFileName(ASource);
  LPrefix := ExpandFileName(AScratchPrefix);
  Result.PreprocessedFile := LPrefix + '.rc.i';
  Result.DependencyFile := LPrefix + '.rc.d';
  Result.RawResFile := LPrefix + '.raw.res';
  if (CompareText(LSource, Result.PreprocessedFile) = 0) or
     (CompareText(LSource, Result.DependencyFile) = 0) or
     (CompareText(LSource, Result.RawResFile) = 0) then
    raise EResourceTool.Create('Resource scratch files overlap the source');
  Result.Preprocess.Executable := ClangPath;
  Result.Preprocess.Arguments := nil;
  Result.Compile.Executable := RCPath;
  Result.Compile.Arguments := nil;
  AddArgument(Result.Preprocess, '--driver-mode=gcc');
  AddArgument(Result.Preprocess, '--target=' + TargetTriple);
  AddArgument(Result.Preprocess, '-E');
  AddArgument(Result.Preprocess, '-xc');
  AddArgument(Result.Preprocess, '-nostdinc');
  AddArgument(Result.Preprocess, '-DRC_INVOKED');
  AddArgument(Result.Preprocess, '-DFPC');
  AddArgument(Result.Compile, '/no-preprocess');
  AddArgument(Result.Compile, '/C');
  AddArgument(Result.Compile, IntToStr(CodePage));
  AddInclude(ExtractFilePath(LSource));
  for LIndex := 0 to FIncludeDirectories.Count - 1 do
    AddInclude(ExpandFileName(FIncludeDirectories[LIndex]));
  for LIndex := 0 to FMacroArguments.Count - 1 do
    AddArgument(Result.Preprocess, FMacroArguments[LIndex]);
  AddArgument(Result.Preprocess, '-MMD');
  AddArgument(Result.Preprocess, '-MF');
  AddArgument(Result.Preprocess, Result.DependencyFile);
  AddArgument(Result.Preprocess, '-MQ');
  AddArgument(Result.Preprocess, Result.RawResFile);
  AddArgument(Result.Preprocess, '-o');
  AddArgument(Result.Preprocess, Result.PreprocessedFile);
  AddArgument(Result.Preprocess, LSource);
  AddArgument(Result.Compile, '/FO');
  AddArgument(Result.Compile, Result.RawResFile);
  AddArgument(Result.Compile, Result.PreprocessedFile);
end;

procedure TLLVMResourceCompiler.Run(const ACommand: TResourceToolCommand;
  const ASource, AStage: string);
var
  LExitCode: Integer;
begin
  if Assigned(FOnCommand) then FOnCommand(ACommand);
  try
    { Unix receives an argv array without a shell. On Windows use explicit
      CRT argument quoting: the common RTL array overload only quotes spaces
      and cannot preserve embedded quotes or trailing backslashes correctly. }
    {$ifdef windows}
    LExitCode := SysUtils.ExecuteProcess(UnicodeString(ACommand.Executable),
      WindowsResourceArguments(ACommand.Arguments));
    {$else}
    LExitCode := SysUtils.ExecuteProcess(ACommand.Executable, ACommand.Arguments);
    {$endif}
  except
    on E: EOSError do
      raise EResourceTool.CreateFmt('%s: cannot execute %s for %s: %s',
        [ASource, ACommand.Executable, AStage, E.Message]);
  end;
  if LExitCode <> 0 then
    raise EResourceTool.CreateFmt('%s: %s failed with exit code %d (%s)',
      [ASource, AStage, LExitCode, ACommand.Executable]);
end;

procedure TLLVMResourceCompiler.CheckEncoding(const AFileName, ASource: string);
var
  LStream: TFileStream;
  LBuffer: array[0..65535] of Byte;
  LRead, LIndex, LRemaining, LMinimum, LMaximum: Integer;
  LLine, LFileName: string;
  LLength: SizeInt;
  LLineNumber: Int64;

  function ParseCodePage(const AText: string; out APage: Cardinal): Boolean;
  var
    LCharacter: SizeInt;
    LDigit: Cardinal;
  begin
    APage := 0;
    Result := False;
    if AText = '' then Exit;
    for LCharacter := 1 to Length(AText) do
    begin
      if not (AText[LCharacter] in ['0'..'9']) then Exit;
      LDigit := Ord(AText[LCharacter]) - Ord('0');
      if APage > (High(Cardinal) - LDigit) div 10 then Exit;
      APage := APage * 10 + LDigit;
    end;
    Result := True;
  end;

  procedure Fail(const AMessage: string);
  begin
    raise EResourceTool.CreateFmt(
      '%s:%d: resource encoding: %s (compiling %s; LLVM issue #63426)',
      [LFileName, LLineNumber, AMessage, ASource]);
  end;

  procedure CheckUTF8(AByte: Byte);
  begin
    if CodePage <> 65001 then Exit;
    if LRemaining <> 0 then
    begin
      if (AByte < LMinimum) or (AByte > LMaximum) then
        Fail('invalid UTF-8; select the input encoding explicitly or convert the RC text');
      Dec(LRemaining);
      LMinimum := $80;
      LMaximum := $BF;
      Exit;
    end;
    LMinimum := $80;
    LMaximum := $BF;
    case AByte of
      $00..$7F: ;
      $C2..$DF: LRemaining := 1;
      $E0: begin LRemaining := 2; LMinimum := $A0; end;
      $E1..$EC, $EE..$EF: LRemaining := 2;
      $ED: begin LRemaining := 2; LMaximum := $9F; end;
      $F0: begin LRemaining := 3; LMinimum := $90; end;
      $F1..$F3: LRemaining := 3;
      $F4: begin LRemaining := 3; LMaximum := $8F; end;
      else Fail('invalid UTF-8; select the input encoding explicitly or convert the RC text');
    end;
  end;

  procedure CheckLine(const ALine: string);
  var
    LPosition, LStart, LDigits, LValue: SizeInt;
    LPage: Cardinal;
    LToken, LMappedFile: string;

    procedure SkipSpace;
    begin
      while (LPosition <= Length(ALine)) and
        (ALine[LPosition] in [#9, #11, #12, #13, ' ']) do Inc(LPosition);
    end;

    function Identifier: string;
    begin
      SkipSpace;
      LStart := LPosition;
      while (LPosition <= Length(ALine)) and
        (ALine[LPosition] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
        Inc(LPosition);
      Result := Copy(ALine, LStart, LPosition - LStart);
    end;

    procedure Expect(ACharacter: AnsiChar);
    begin
      SkipSpace;
      if (LPosition > Length(ALine)) or (ALine[LPosition] <> ACharacter) then
        Fail('malformed #pragma code_page; expected ' + ACharacter);
      Inc(LPosition);
    end;

  begin
    LPosition := 1;
    SkipSpace;
    if (LPosition <= Length(ALine)) and (ALine[LPosition] = '#') then
    begin
      Inc(LPosition);
      LToken := Identifier;
      if (LToken <> '') and (LToken[1] in ['0'..'9']) and
        ParseCodePage(LToken, LPage) then
      begin
        { Clang line markers name the original source/header. Decode its C
          escapes, including octal UTF-8 bytes, rather than leaking .rc.i paths. }
        SkipSpace;
        if (LPosition <= Length(ALine)) and (ALine[LPosition] = '"') then
        begin
          Inc(LPosition);
          LMappedFile := '';
          while (LPosition <= Length(ALine)) and (ALine[LPosition] <> '"') do
          begin
            if (ALine[LPosition] = '\') and (LPosition < Length(ALine)) then
            begin
              Inc(LPosition);
              if ALine[LPosition] in ['0'..'7'] then
              begin
                LValue := 0;
                LDigits := 0;
                while (LPosition <= Length(ALine)) and (LDigits < 3) and
                  (ALine[LPosition] in ['0'..'7']) do
                begin
                  LValue := LValue * 8 + Ord(ALine[LPosition]) - Ord('0');
                  Inc(LPosition);
                  Inc(LDigits);
                end;
                if LValue > 255 then Fail('invalid filename in Clang line marker');
                LMappedFile := LMappedFile + AnsiChar(LValue);
                Continue;
              end;
              case ALine[LPosition] of
                'n': LMappedFile := LMappedFile + #10;
                'r': LMappedFile := LMappedFile + #13;
                't': LMappedFile := LMappedFile + #9;
                else LMappedFile := LMappedFile + ALine[LPosition];
              end;
            end
            else LMappedFile := LMappedFile + ALine[LPosition];
            Inc(LPosition);
          end;
          LFileName := LMappedFile;
          LLineNumber := LPage;
          Exit;
        end;
      end
      else if (LToken = 'pragma') and (Identifier = 'code_page') then
      begin
        Expect('(');
        LToken := Identifier;
        { DEFAULT means the explicitly configured invocation default, never
          the host locale. LLVM cannot implement mid-script encoding changes:
          https://github.com/llvm/llvm-project/issues/63426 }
        if LToken = 'DEFAULT' then LPage := CodePage
        else if not ParseCodePage(LToken, LPage) then
          Fail('malformed #pragma code_page; expected a numeric codepage or DEFAULT');
        Expect(')');
        SkipSpace;
        if LPosition <= Length(ALine) then
          Fail('unexpected text after #pragma code_page');
        if LPage <> CodePage then
          Fail(Format('codepage %d conflicts with configured codepage %d; ' +
            'use one encoding per RC compilation', [LPage, CodePage]));
      end;
    end;
    Inc(LLineNumber);
  end;

begin
  LFileName := ASource;
  LLineNumber := 1;
  LRemaining := 0;
  LMinimum := $80;
  LMaximum := $BF;
  LLength := 0;
  SetLength(LLine, 256);
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    repeat
      LRead := LStream.Read(LBuffer, SizeOf(LBuffer));
      for LIndex := 0 to LRead - 1 do
      begin
        CheckUTF8(LBuffer[LIndex]);
        if LBuffer[LIndex] = 10 then
        begin
          CheckLine(Copy(LLine, 1, LLength));
          LLength := 0;
        end
        else
        begin
          if LLength = Length(LLine) then
          begin
            if LLength > High(SizeInt) div 2 then Fail('RC line is too large');
            SetLength(LLine, LLength * 2);
          end;
          Inc(LLength);
          LLine[LLength] := AnsiChar(LBuffer[LIndex]);
        end;
      end;
    until LRead = 0;
    if LRemaining <> 0 then Fail('incomplete UTF-8 sequence at end of input');
    if LLength <> 0 then CheckLine(Copy(LLine, 1, LLength));
  finally
    LStream.Free;
  end;
end;

procedure TLLVMResourceCompiler.CompileRC(ACatalog: TResourceCatalog;
  const ASource, AScratchPrefix: string);
var
  LPlan: TResourceCompilePlan;
  LStream: TFileStream;

  procedure RemoveStale(const AFileName: string);
  begin
    if FileExists(AFileName) and not DeleteFile(AFileName) then
      raise EResourceTool.CreateFmt('%s: cannot remove stale resource intermediate %s',
        [ASource, AFileName]);
  end;

begin
  LPlan := Plan(ASource, AScratchPrefix);
  RemoveStale(LPlan.RawResFile);
  RemoveStale(LPlan.PreprocessedFile);
  RemoveStale(LPlan.DependencyFile);
  try
    Run(LPlan.Preprocess, ASource, 'Clang resource preprocessing');
    CheckEncoding(LPlan.PreprocessedFile, ASource);
    Run(LPlan.Compile, ASource, 'LLVM resource compilation');
    LStream := TFileStream.Create(LPlan.RawResFile, fmOpenRead or fmShareDenyWrite);
    try
      ACatalog.LoadRes(LStream, ASource);
    finally
      LStream.Free;
    end;
  except
    { Keep new preprocessing/dependency files for diagnostics, but never leave
      a partial or stale compiled resource available to the owning compiler. }
    RemoveStale(LPlan.RawResFile);
    raise;
  end;
end;

end.
