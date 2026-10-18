{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit handles the compilerhooks for output to external programs

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit comphook;

{$i fpcdefs.inc}

interface

uses
  SysUtils,
  GlobType,
  FinPut;

var
  { RHIDE expect gcc like error output }
  FatalStr      : string[6] = 'Fatal:';
  ErrorStr      : string[6] = 'Error:';
  WarningStr    : string[8] = 'Warning:';
  NoteStr       : string[5] = 'Note:';
  HintStr       : string[5] = 'Hint:';
const
  WarningErrorStr    : string[29] = 'Warning: (treated as error)';
  NoteErrorStr       : string[27] = 'Note: (treated as error)';
  HintErrorStr       : string[27] = 'Hint: (treated as error)';

type
  PCompilerStatus = ^TCompilerStatus;
  TCompilerStatus = record
  { Current status }
    CurrentModule,
    CurrentSourcePPUFileName, { the name of the ppu where the source file
                                comes from where the error location is given }
    CurrentSourcePath,
    CurrentSource : string;   { filename }
    CurrentLine,
    CurrentColumn : LongInt;  { current line and column }
    CurrentModuleState : string[32];
  { Total Status }
    CompiledLines : LongInt;  { the number of lines which are compiled }
    ErrorCount,               { number of compiler errors }
    CountWarnings,
    CountNotes,
    CountHints    : LongInt;  { number of found errors/warnings/notes/hints }
    CodeSize,
    DataSize      : QWord;
  { program info }
    IsExe,
    IsPackage,
    IsLibrary     : Boolean;
  { Settings for the output }
    ShowMsgNrs    : Boolean;
    Verbosity     : LongInt;
    MaxErrorCount : LongInt;
    ErrorWarning,
    ErrorNote,
    ErrorHint,
    SkipError,
    UseStdErr,
    UseRedir,
    UseBugReport,
    UseGCCOutput,
    SourcesAvail,
    PrintSourcePath : Boolean;
  { Redirection support }
    RedirFile : Text;
  { Special file for bug report }
    ReportBugFile : Text;
  end;

type
  EControlCAbort=class(Exception)
    constructor Create;
  end;
  ECompilerAbort=class(Exception)
    constructor Create;
  end;
  ECompilerAbortSilent=class(Exception)
    constructor Create;
  end;

var
  Status : TCompilerStatus;

{ Default Functions }
Function  Def_Status:Boolean;
Function  Def_Comment(Level:LongInt;const S:AnsiString):Boolean;
function  Def_InternalError(I:LongInt):Boolean;
function  Def_InternalErrorEx(I:LongInt;const S:AnsiString):Boolean;
function  Def_CheckVerbosity(V:LongInt):Boolean;
procedure Def_InitSymbolInfo;
procedure Def_DoneSymbolInfo;
procedure Def_ExtractSymbolInfo;
function  Def_OpenInputFile(const FileName: TPathStr): TInputFile;
Function  Def_GetNamedFileTime(Const F : TPathStr) : LongInt;
{ Function redirecting for IDE support }
type
  TStopProcedure         = procedure(err:LongInt);
  TStatusFunction        = function:Boolean;
  TCommentFunction       = function(Level:LongInt;const s:AnsiString):Boolean;
  TInternalErrorFunction = function(i:LongInt):Boolean;
  TInternalErrorExFunction = function(i:LongInt; const s : AnsiString):Boolean;
  TCheckVerbosityFunction = function(i:LongInt):Boolean;

  TInitSymbolInfoProc = procedure;
  TDoneSymbolInfoProc = procedure;
  TExtractSymbolInfoProc = procedure;
  TOpenInputFileFunc = function(const filename: TPathStr): TInputFile;
  TGetNamedFileTimeFunc = function(const filename: TPathStr): LongInt;

var
  Do_Status        : TStatusFunction  = @Def_Status;
  Do_Comment       : TCommentFunction = @Def_Comment;
  Do_InternalError : TInternalErrorFunction = @Def_InternalError deprecated 'use do_internalerrorex';
  Do_InternalErrorEx : TInternalErrorExFunction = @Def_InternalErrorEx;
  Do_CheckVerbosity : TCheckVerbosityFunction = @Def_CheckVerbosity;

  Do_InitSymbolInfo : TInitSymbolInfoProc = @Def_InitSymbolInfo;
  Do_DoneSymbolInfo : TDoneSymbolInfoProc = @Def_DoneSymbolInfo;
  Do_ExtractSymbolInfo : TExtractSymbolInfoProc = @Def_ExtractSymbolInfo;
  NeedSymbolInfo : Boolean =False;

  Do_OpenInputFile : TOpenInputFileFunc = @Def_OpenInputFile;
  Do_GetNamedFileTime : TGetNamedFileTimeFunc = @Def_GetNamedFileTime;

implementation

  uses
   CUtils, Systems, Globals, CompTTY;

{****************************************************************************
                          Helper Routines
****************************************************************************}

function GCCFileName(const S : ShortString) : ShortString;
var
  I : LongInt;
begin
  for I:=1to Length(S) do
   begin
     case S[I] of
      '\' : GCCFileName[I]:='/';
 'A'..'Z' : if not (tf_files_case_aware in SourceInfo.Flags) and
               not (tf_files_case_sensitive in SourceInfo.Flags) then
              GCCFileName[I]:=Chr(Ord(S[I])+32)
            else
              GCCFileName[I]:=S[I];
     else
      GCCFileName[I]:=S[I];
     end;
   end;
  GCCFileName[0]:=S[0];
end;


function ToStr(I : LongInt) : string;
var
  HS : string;
begin
  Str(I,HS);
  ToStr:=HS;
end;

type
  TOutputColor = (oc_black,oc_red,oc_green,oc_orange,oc_blue,oc_magenta,oc_cyan,oc_lightgray);

procedure WriteColoredOutput(var T: Text;Color: TOutputColor;const S : AnsiString);
  begin
     if TTYCheckSupported and IsATTY(T) then
       begin
         case Color of
           oc_black:
             Write(T,#27'[1m'#27'[30m');
           oc_red:
             Write(T,#27'[1m'#27'[31m');
           oc_green:
             Write(T,#27'[1m'#27'[32m');
           oc_orange:
             Write(T,#27'[1m'#27'[33m');
           oc_blue:
             Write(T,#27'[1m'#27'[34m');
           oc_magenta:
             Write(T,#27'[1m'#27'[35m');
           oc_cyan:
             Write(T,#27'[1m'#27'[36m');
           oc_lightgray:
             Write(T,#27'[1m'#27'[37m');
         end;
       end;
    Write(T,S);
    if TTYCheckSupported and IsATTY(T) then
      Write(T,#27'[0m');
  end;
{****************************************************************************
                          Stopping the compiler
****************************************************************************}

constructor EControlCAbort.Create;
  begin
    inherited Create('Ctrl-C Signaled!');
  end;


constructor ECompilerAbort.Create;
  begin
    inherited Create('Compilation Aborted');
  end;


constructor ECompilerAbortSilent.Create;
  begin
    inherited Create('Compilation Aborted');
  end;


{****************************************************************************
                         Predefined default Handlers
****************************************************************************}

function Def_Status:Boolean;
var
  HStatus : TFPCHeapStatus;
begin
  Def_Status:=False; { never stop }
{ Status info?, Called every line }
  if ((Status.Verbosity and VStatus)<>0) then
   begin
     if (Status.CompiledLines=1) or
        (Status.CurrentLine mod 100=0) then
       begin
         if Status.CurrentLine>0 then
           Write(Status.CurrentModule,':',Status.CurrentLine,' ');
         HStatus:=GetFPCHeapStatus;
         WriteLn(DStr(HStatus.CurrHeapUsed shr 10),'/',DStr(HStatus.CurrHeapSize shr 10),' Kb Used');
         Flush(Output);
       end;
   end;
end;


Function Def_Comment(Level:LongInt;const S:AnsiString):Boolean;
const
  RHErrorStr   = 'error:';
  RHWarningStr = 'warning:';

  procedure WriteMsgTypeColored(var T : Text;const S : AnsiString);
    begin
      case (Status.Verbosity and Level) of
        VWarning:
          WriteColoredOutput(T,oc_magenta,S);
        VError,
        VFatal:
          WriteColoredOutput(T,oc_red,S);
        else
          Write(T,S);
      end;
    end;

var
  HS2,
  MsgTypeStr,
  MsgLocStr,
  MsgTimeStr: AnsiString;
begin
  Def_Comment:=False; { never stop }
  MsgTypeStr:='';
  MsgLocStr:='';
  MsgTimeStr:='';
  if not(Status.UseGCCOutput) then
    begin
      if (Status.Verbosity and Level)=VHint then
        if Status.ErrorHint then
          MsgTypeStr:=HintErrorStr
        else
          MsgTypeStr:=HintStr;
      if (Status.Verbosity and Level)=VNote then
        if Status.ErrorNote then
          MsgTypeStr:=NoteErrorStr
        else
          MsgTypeStr:=NoteStr;
      if (Status.Verbosity and Level)=VWarning then
        if Status.ErrorWarning then
          MsgTypeStr:=WarningErrorStr
        else
          MsgTypeStr:=WarningStr;
      if (Status.Verbosity and Level)=VError then
        MsgTypeStr:=ErrorStr;
      if (Status.Verbosity and Level)=VFatal then
        MsgTypeStr:=FatalStr;
      if (Status.Verbosity and VParallel)=VParallel then
        begin
          if (InputFileName<>'') and (Status.CurrentModule<>'') then
            MsgTypeStr:=MsgTypeStr+'('+InputFileName+'/'+Status.CurrentModule+')'
          else if (Status.CurrentModule<>'') then
            MsgTypeStr:=MsgTypeStr+'('+Status.CurrentModule+')'
          else if (InputFileName<>'') then
            MsgTypeStr:=MsgTypeStr+'('+InputFileName+')';
        end
      else if (Status.Verbosity and Level)=VUsed then
        MsgTypeStr:=PadSpace('('+Status.CurrentModule+')',10);

    end
  else
    begin
      if (Status.Verbosity and Level)=VHint then
        MsgTypeStr:=RHWarningStr;
      if (Status.Verbosity and Level)=VNote then
        MsgTypeStr:=RHWarningStr;
      if (Status.Verbosity and Level)=VWarning then
        MsgTypeStr:=RHWarningStr;
      if (Status.Verbosity and Level)=VError then
        MsgTypeStr:=RHErrorStr;
      if (Status.Verbosity and Level)=VFatal then
        MsgTypeStr:=RHErrorStr;
    end;
  { Generate line prefix }
  if ((Level and VLineInfo)=VLineInfo) and
     (Status.CurrentSource<>'') and
     (Status.CurrentLine>0) then
    begin
      { Adding the column should not confuse RHIDE,
      even if it does not yet use it PM
      but only if it is after error or warning !! PM }
      if Status.CurrentColumn>0 then
        begin
          if Status.UseGCCOutput then
            MsgLocStr:=GCCFileName(Status.CurrentSource)+':'+ToStr(Status.CurrentLine)+':'+ToStr(Status.CurrentColumn)+':'
          else
            MsgLocStr:=Status.CurrentSource+'('+ToStr(Status.CurrentLine)+','+ToStr(Status.CurrentColumn)+')';
        end
      else
        begin
          if Status.UseGCCOutput then
            MsgLocStr:=GCCFileName(Status.CurrentSource)+':'+ToStr(Status.CurrentLine)+':'
          else
            MsgLocStr:=Status.CurrentSource+'('+ToStr(Status.CurrentLine)+')';
        end;
      if Status.PrintSourcePath then
        if Status.SourcesAvail then
          MsgLocStr:=Status.CurrentSourcePath+MsgLocStr
        else
          MsgLocStr:=Status.CurrentSourcePPUFileName+':'+MsgLocStr;
    end;
  if MsgLocStr<>'' then
    MsgLocStr:=MsgLocStr+' ';
  if MsgTypeStr<>'' then
    MsgTypeStr:=MsgTypeStr+' ';
  if (Status.Verbosity and VTimeStamps)<>0 then
    begin
      System.Str(GetRealTime-StartTime:0:3,HS2);
      MsgTimeStr:='['+HS2+'] ';
    end;

  { Display line }
  if (Level<>VNone) and
     ((Status.Verbosity and (Level and VLevelMask))=(Level and VLevelMask)) then
   begin
     if Status.UseStdErr then
       begin
         Write(StdErr,MsgTimeStr+MsgLocStr);
         WriteMsgTypeColored(StdErr,MsgTypeStr);
         WriteLn(StdErr,S);
         Flush(StdErr);
       end
     else
       begin
         if Status.UseRedir then
           begin
           WriteLn(Status.RedirFile,MsgTimeStr+MsgLocStr+MsgTypeStr+S);
           Flush(Status.RedirFile);
           end
         else
           begin
             Write(MsgTimeStr+MsgLocStr);
             WriteMsgTypeColored(Output,MsgTypeStr);
             WriteLn(S);
           end;
       end;
   end;
  { include everything in the bugreport file }
  if Status.UseBugReport then
    begin
      Write(Status.ReportBugFile,HexStr(Level,8)+':');
      WriteLn(Status.ReportBugFile,MsgTimeStr+MsgLocStr+MsgTypeStr+S);
    end;
end;


function Def_InternalError(I : LongInt) : Boolean;
begin
  Result:=Def_InternalErrorEx(I,'');
end;

function Def_InternalErrorEx(I : LongInt; const S : AnsiString) : Boolean;
var
  Msg : AnsiString;
begin
  Msg:=S;
  if Msg<>'' then
    Msg:=': '+Msg;
  Msg:='Internal error '+ToStr(I)+Msg;
  Do_Comment(VFatal+VLineInfo,Msg);
{$ifdef EXTDEBUG}
  { Internalerror() and def_internalerror() do not
    have a stackframe }
  Dump_Stack(StdOut,Get_Caller_Frame(Get_Frame));
{$endif EXTDEBUG}
  Def_InternalErrorEx:=True;
end;

function Def_CheckVerbosity(V:LongInt):Boolean;
begin
  Result:=Status.UseBugReport or
          ((V<>VNone) and
           ((Status.Verbosity and (V and VLevelMask))=(V and VLevelMask)));
end;

procedure Def_InitSymbolInfo;
begin
end;

procedure Def_DoneSymbolInfo;
begin
end;

procedure Def_ExtractSymbolInfo;
begin
end;

function  Def_OpenInputFile(const FileName: TPathStr): TInputFile;
begin
  Def_OpenInputFile:=TDOSInputFile.Create(FileName);
end;


Function Def_GetNamedFileTime (Const F : TPathStr) : LongInt;
begin
  Result:=FileAge(F);
end;

end.
