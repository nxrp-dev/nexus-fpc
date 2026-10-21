{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit handles the verbose management

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
unit verbose;

{$i fpcdefs.inc}

interface

    uses
      SysUtils,
      CUtils,
      GlobType,FinPut,
      CMsgs;

{$ifndef EXTERN_MSG}
  {$i msgtxt.inc}
{$endif}

{$i msgidx.inc}

    var
      Msg : PMessage;

    type
      TMsgQueueEvent = procedure(const s:TMsgStr;v,w:LongInt) of object;

    var
      MsgFileName : string = '';

    procedure SetRedirectFile(const FN:string);
    function  SetVerbosity(const S:TCmdStr):Boolean;
    procedure PrepareReport;

    function  CheckVerbosity(V:LongInt):Boolean;
    function  SetMessageVerbosity(V:LongInt;State:TMsgState):Boolean;
    procedure RestoreLocalVerbosity(PState : PMessageStateRecord);
    procedure FreeLocalVerbosity(var FState : PMessageStateRecord);

    function ChangeMessageVerbosity(S: AnsiString; var I: Integer;State:TMsgState): Boolean;
    procedure ShowStatus;
    function  ErrorCount:LongInt;
    procedure SetErrorFlags(const S:string);
    procedure GenerateError;
    procedure InternalError(I:LongInt);Noreturn;
    procedure InternalError(I:LongInt; const S : AnsiString);Noreturn;
    procedure Comment(L:LongInt;S:AnsiString);
    function  MessageStr(W:LongInt):TMsgStr;
    procedure Message(W:LongInt;OnQueue:TMsgQueueEvent=nil);
    procedure Message1(W:LongInt;const S1:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure Message2(W:LongInt;const S1,S2:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure Message3(W:LongInt;const S1,S2,S3:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure Message4(W:LongInt;const S1,S2,S3,S4:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure MessagePos(const Pos:TFilePosInfo;W:LongInt;OnQueue:TMsgQueueEvent=nil);
    procedure MessagePos1(const Pos:TFilePosInfo;W:LongInt;const S1:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure MessagePos2(const Pos:TFilePosInfo;W:LongInt;const S1,S2:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure MessagePos3(const Pos:TFilePosInfo;W:LongInt;const S1,S2,S3:TMsgStr;OnQueue:TMsgQueueEvent=nil);
    procedure MessagePos4(const Pos:TFilePosInfo;W:LongInt;const S1,S2,S3,S4:TMsgStr;OnQueue:TMsgQueueEvent=nil);

    { message calls with codegenerror support }
    procedure CGMessage(T : LongInt);
    procedure CGMessage1(T : LongInt;const S : TMsgStr);
    procedure CGMessage2(T : LongInt;const S1,S2 : TMsgStr);
    procedure CGMessage3(T : LongInt;const S1,S2,S3 : TMsgStr);
    procedure CGMessagePos(const Pos:TFilePosInfo;T:LongInt);
    procedure CGMessagePos1(const Pos:TFilePosInfo;T:LongInt;const S1:TMsgStr);
    procedure CGMessagePos2(const Pos:TFilePosInfo;T:LongInt;const S1,S2:TMsgStr);
    procedure CGMessagePos3(const Pos:TFilePosInfo;T:LongInt;const S1,S2,S3:TMsgStr);

    procedure FlushOutput;

    procedure InitVerbose;
    procedure DoneVerbose;


    const
      PrintNodeSpacing = '   ';
    var
      { indention used when writing a node tree to the screen }
      PrintNodeIndention : string;


     { Node dumping support functions }
     procedure PrintNodeIndent; inline;
     procedure PrintNodeUnindent; inline;

implementation

    uses
      CompHook,FModule,ConstExp,Globals,CFileUtl,Switches,CClasses;

{****************************************************************************
                       Extra Handlers for default compiler
****************************************************************************}

    procedure DoneRedirectFile;
      begin
        if Status.UseRedir then
         begin
           Close(Status.RedirFile);
           Status.UseRedir:=False;
         end;
        if Status.UseBugReport then
         begin
           Close(Status.ReportBugFile);
           Status.UseBugReport:=False;
         end;
      end;


    procedure SetRedirectFile(const FN:string);
      begin
        { close old redirection file because FileRedirection is handled in both passes }
        if Status.UseRedir then
          Close(Status.RedirFile);

        Assign(Status.RedirFile,FN);
      {$push}{$I-}
        Append(Status.RedirFile);
        if IOResult <> 0 then
          begin
            Assign(Status.RedirFile,FN);
            Rewrite(Status.RedirFile);
          end;
      {$pop}
        Status.UseRedir:=(IOResult=0);
      end;


    procedure PrepareReport;
      var
        FN : string;
      begin
        if Status.UseBugReport then
         Exit;
        FN:='nxpcdebug.txt';
        Assign(Status.ReportBugFile,FN);
        {$push}{$I-}
         Append(Status.ReportBugFile);
         if IOResult <> 0 then
          Rewrite(Status.ReportBugFile);
        {$pop}
        Status.UseBugReport:=(IOResult=0);
        if Status.UseBugReport then
         WriteLn(Status.ReportBugFile,'NXPC bug report file');
      end;

    procedure RestoreLocalVerbosity(PState : PMessageStateRecord);
      { apply the whole stack of message/verbosity changes }
      var
        MsgSet : THashSet;
        MsgFound : Boolean;
      begin
        Msg^.ResetStates;
        if not Assigned(PState) then
          Exit;
        MsgSet:=THashSet.Create(10,False,False);
        while Assigned(PState) do
          begin
            {$IFDEF DEBUG_MESSAGESTATE}
            if Assigned(PState^.Owner) and (PState^.Owner<>CurrentModule) then
              InternalError(2026030702);
            {$ENDIF}
            MsgFound:=False;
            { only apply the newest message state }
            if not Assigned(MsgSet.FindOrAdd(@PState^.Value,SizeOf(PState^.Value),MsgFound)) or
                not MsgFound then
              SetMessageVerbosity(PState^.Value,PState^.State);
            PState:=PState^.Next;
          end;
        MsgSet.Free;
        MsgSet := nil;
      end;

    procedure FreeLocalVerbosity(var FState : PMessageStateRecord);
    var PState : PMessageStateRecord;
      begin
        PState:=unaligned(FState);
        while Assigned(PState) do
          begin
            unaligned(FState):=PState^.Next;
            {$IFDEF DEBUG_MESSAGESTATE}
            if Assigned(PState^.Owner) and (PState^.Owner<>CurrentModule) then
              InternalError(2026030703);
            {$ENDIF}
            Dispose(PState);
            PState:=unaligned(FState);
          end;
      end;

    function ChangeMessageVerbosity(S: AnsiString; var I : Integer;State:TMsgState): Boolean;
      var
        Tok  : AnsiString;
        MsgNr, Code : LongInt;
      begin
        { delete everything up to and including 'm' }
        Delete(S,1,I);
        { the rest of the string must be message numbers }
        Inc(I,Length(S)+1);
        Result:=False;
        repeat
          Tok:=GetToken(S,',');
          if (Tok='') then
            Break;
          Val(Tok, MsgNr, Code);
          if (Code<>0) then
            Exit;
          if not Msg^.Valid(MsgNr) then
            Exit
          else
            RecordPendingMessageState(MsgNr, State);
        until False;
        Result:=True;
      end;

    function SetMessageVerbosity(V:LongInt;State:TMsgState):Boolean;
      begin
        Result:=Msg^.SetVerbosity(V,State);
      end;

    function CheckVerbosity(V:LongInt):Boolean;
      begin
        Result:=Do_CheckVerbosity(V);
      end;


    function SetVerbosity(const S:TCmdStr):Boolean;
      const
        MessageVerbosity:array[Boolean] of TMsgState=(ms_off_global,ms_on_global);
      var
        M : LongInt;
        I : Integer;
        Inverse : Boolean;
        C : Char;
      begin
        SetVerbosity:=False;
        Val(S,M,I);
        if (I=0) and (S<>'') then
         Status.Verbosity:=M
        else
         begin
           I:=1;
           while I<=Length(S) do
             begin
                C:=UpCase(S[I]);
                Inverse:=False;
                { on/off ? }
                if (I<Length(S)) then
                 case S[I+1] of
                  '-' : begin
                          Inc(I);
                          Inverse:=True;
                        end;
                  '+' : Inc(I);
                 end;
                { handle switch }
                case C of
                { Special cases }
                 '0' : Status.Verbosity:=VDefault;
                 'A' : Status.Verbosity:=VAll;
                 'B' : begin
                          if Inverse then
                            Status.PrintSourcePath:=False
                          else
                            Status.PrintSourcePath:=True;
                       end;
                 'M' : if not ChangeMessageVerbosity(S,I,MessageVerbosity[Inverse]) then
                         begin
                           Result:=False;
                           Exit
                         end;
                 'P' : begin
                         if Inverse then
                          ParaPrintNodeTree:=0
                         else
                          ParaPrintNodeTree:=1;
                       end;
                 'Q' : begin
                          if Inverse then
                            Status.ShowMsgNrs:=False
                          else
                            Status.ShowMsgNrs:=True;
                       end;
                 'R' : begin
                          if Inverse then
                            begin
                               Status.UseGCCOutput:=False;
                               Status.UseStdErr:=False;
                            end
                          else
                            begin
                               Status.UseGCCOutput:=True;
                               Status.UseStdErr:=True;
                            end;
                       end;
                 'V' : PrepareReport;
                 'Z' : begin
                          if Inverse then
                            Status.UseStdErr:=False
                          else
                            Status.UseStdErr:=True;
                       end;
                { Normal cases - do an or }
                 'C' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VConditional)
                       else
                         Status.Verbosity:=Status.Verbosity or VConditional;
                 'D' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VDebug)
                       else
                         Status.Verbosity:=Status.Verbosity or VDebug;
                 'E' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VError)
                       else
                         Status.Verbosity:=Status.Verbosity or VError;
                 'H' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VHint)
                       else
                         Status.Verbosity:=Status.Verbosity or VHint;
                 'I' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VInfo)
                       else
                         Status.Verbosity:=Status.Verbosity or VInfo;
                 'J' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VParallel)
                       else
                         Status.Verbosity:=Status.Verbosity or VParallel;
                 'L' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VStatus)
                       else
                         Status.Verbosity:=Status.Verbosity or VStatus;
                 'N' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VNote)
                       else
                         Status.Verbosity:=Status.Verbosity or VNote;
                 'S' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VTimeStamps)
                       else
                         Status.Verbosity:=Status.Verbosity or VTimeStamps;
                 'T' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VTried)
                       else
                         Status.Verbosity:=Status.Verbosity or VTried;
                 'U' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VUsed)
                       else
                         Status.Verbosity:=Status.Verbosity or VUsed;
                 'W' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VWarning)
                       else
                         Status.Verbosity:=Status.Verbosity or VWarning;
                 'X' : if Inverse then
                         Status.Verbosity:=Status.Verbosity and (not VExecutable)
                       else
                         Status.Verbosity:=Status.Verbosity or VExecutable;
                 end;
                Inc(I);
             end;
           end;
        if Status.Verbosity=0 then
         Status.Verbosity:=VDefault;
        SetVerbosity:=True;
      end;


    procedure LoadPrefixes;

        function LoadPrefix(W:LongInt):string;
        var
          S : string;
          Idx : LongInt;
        begin
          S:=Msg^.Get(W,[]);
          Idx:=Pos('_',S);
          if Idx>0 then
           LoadPrefix:=Copy(S,Idx+1,255)
          else
           LoadPrefix:=S;
        end;

      begin
      { Load the prefixes }
        FatalStr:=LoadPrefix(general_i_fatal);
        ErrorStr:=LoadPrefix(general_i_error);
        WarningStr:=LoadPrefix(general_i_warning);
        NoteStr:=LoadPrefix(general_i_note);
        HintStr:=LoadPrefix(general_i_hint);
      end;


    procedure LoadMsgFile(const FN:string);
      begin
        { reload the internal messages if not already loaded }
{$ifndef EXTERN_MSG}
        if not Msg^.MsgIntern then
         Msg^.LoadIntern(@MsgTxt,MsgTxtSize,msgtxt_codepage);
{$endif}
        if not Msg^.LoadExtern(FN) then
         begin
{$ifdef EXTERN_MSG}
           WriteLn('Fatal: Cannot find error message file.');
           Halt(3);
{$else}
           Msg^.LoadIntern(@MsgTxt,MsgTxtSize,msgtxt_codepage);
{$endif}
         end;
        { reload the prefixes using the new messages }
        LoadPrefixes;
      end;


    procedure MaybeLoadMessageFile;
      begin
        { Load new message file }
        if (MsgFileName<>'')  then
         begin
           LoadMsgFile(MsgFileName);
           MsgFileName:='';
         end;
      end;


    var
      LastFileIdx,
      LastModuleIdx : LongInt;


    Procedure UpdateStatus;
      var
        Module : TModule;
      begin
      { fix status }
        Status.CurrentLine:=CurrentFilePos.Line;
        Status.CurrentColumn:=CurrentFilePos.Column;
        if (CurrentFilePos.ModuleIndex <> LastModuleIdx) or
           (CurrentFilePos.FileIndex <> LastFileIdx) then
        begin
          Module:=Get_Module(CurrentFilePos.ModuleIndex);
          if Assigned(Module) and Assigned(Module.SourceFiles) then
            begin
              { update status record }
              Status.CurrentModule:=Module.ModuleName^;
              Status.CurrentSourcePPUFileName:=Module.PPUFileName;
              Status.CurrentModuleState:=ModuleStateStr[Module.State];
              Status.CurrentSource:=Module.SourceFiles.Get_File_Name(CurrentFilePos.FileIndex);
              Status.CurrentSourcePath:=Module.SourceFiles.Get_File_Path(CurrentFilePos.FileIndex);
              Status.SourcesAvail:=Module.SourcesAvail;
              { if currentsourcepath is relative, make it absolute }
              if not Path_Absolute(Status.CurrentSourcePath) then
                Status.CurrentSourcePath:=GetCurrentDir+Status.CurrentSourcePath;

              { update lastfileidx only if name known PM }
              if Status.CurrentSource<>'' then
                LastFileIdx:=CurrentFilePos.FileIndex
              else
                LastFileIdx:=0;

              LastModuleIdx:=Module.ModuleID;
            end;
        end;
      end;


    procedure ShowStatus;
      begin
        UpdateStatus;
        if Do_Status() then
          raise ECompilerAbort.Create;
      end;


    function ErrorCount:LongInt;
      begin
        ErrorCount:=Status.ErrorCount;
      end;


    procedure SetErrorFlags(const S:string);
      var
        Code : Integer;
        I,J,L : LongInt;
      begin
      { empty string means error count = 1 for backward compatibility (PFV) }
        if S='' then
         begin
           Status.MaxErrorCount:=1;
           Exit;
         end;
        I:=0;
        while (I<Length(S)) do
         begin
           Inc(I);
           case S[I] of
             '0'..'9' :
                begin
                  J:=I;
                  while (J<=Length(S)) and (S[J] in ['0'..'9']) do
                   Inc(J);
                  Val(Copy(S,I,J-I),L,Code);
                  if Code<>0 then
                   L:=1;
                  Status.MaxErrorCount:=L;
                  I:=J-1;
                end;
              'w','W' :
                begin
                  if (I<Length(S)) and (S[I+1]='-') then
                    begin
                      Inc(I);
                      Status.ErrorWarning:=False;
                    end
                  else
                    begin
                      Status.ErrorWarning:=True;
                      { Enable writing of warnings, to avoid getting errors without any message }
                      Status.Verbosity:=Status.Verbosity or VWarning;
                    end;
                end;
              'n','N' :
                begin
                  if (I<Length(S)) and (S[I+1]='-') then
                    begin
                      Inc(I);
                      Status.ErrorNote:=False;
                    end
                  else
                    begin
                      Status.ErrorNote:=True;
                      { Enable writing of notes, to avoid getting errors without any message }
                      Status.Verbosity:=Status.Verbosity or VNote;
                    end;

                end;
              'h','H' :
                begin
                  if (I<Length(S)) and (S[I+1]='-') then
                    begin
                      Inc(I);
                      Status.ErrorHint:=False;
                    end
                  else
                    begin
                      Status.ErrorHint:=True;
                      { Enable writing of hints, to avoid getting errors without any message }
                      Status.Verbosity:=Status.Verbosity or VHint;
                    end;
                end;
           end;
         end;
      end;


    procedure GenerateError;
      begin
        Inc(Status.ErrorCount);
      end;


    procedure InternalError(I : LongInt);Noreturn;
    begin
      InternalError(I,'');
    end;

    procedure InternalError(I:LongInt; const S : AnsiString);Noreturn;
      procedure DoRaise;
        begin
          raise ECompilerAbort.Create;
        end;
      begin
        UpdateStatus;
        Do_InternalErrorEx(I,S);
        GenerateError;
        DoRaise;
      end;

    procedure Comment(L:LongInt;S:AnsiString);
      var
        DoStop : Boolean;
      begin
        DoStop:=((L and VFatal)<>0);
        if ((L and VError)<>0) or
           ((L and VFatal)<>0) or
           (Status.ErrorWarning and ((L and VWarning)<>0)) or
           (Status.ErrorNote and ((L and VNote)<>0)) or
           (Status.ErrorHint and ((L and VHint)<>0)) then
         GenerateError
        else
         if L and VWarning <> 0 then
          Inc(Status.CountWarnings)
         else
          if L and VNote <> 0 then
           Inc(Status.CountNotes)
          else
           if L and VHint <> 0 then
            Inc(Status.CountHints);
      { check verbosity level }
        if not CheckVerbosity(L) then
          Exit;
        if (L and VLineInfoMask)<>0 then
          L:=L or VLineInfo;
      { Create status info }
        UpdateStatus;
      { Fix replacements }
        DefaultReplacements(S,False);
      { show comment }
        if Do_Comment(L,S) or DoStop then
          raise ECompilerAbort.Create;
        if (Status.ErrorCount>=Status.MaxErrorCount) and not Status.SkipError then
         begin
           Message1(unit_f_errors_in_unit,ToStr(Status.ErrorCount));
           Status.SkipError:=True;
           raise ECompilerAbort.Create;
         end;
      end;

    function GetMessageState(M:LongInt):TMsgState;
      var
        I: Integer;
      begin
        I:=M div 1000;
        { get the default state }
        Result:=Msg^.MsgStates[I][M mod 1000];

        { and search at the current unit settings }
        { todo }
      end;

    Procedure Msg2Comment(S:AnsiString;W:LongInt;OnQueue:TMsgQueueEvent);
      var
        Idx,I,V : LongInt;
        DoStop  : Boolean;
        DoQueue : Boolean;
        ST      : TMsgState;
        CH      : Char;
      begin
      {Reset}
        DoStop:=False;
        DoQueue:=False;
        V:=0;
      {Parse options}
        Idx:=Pos('_',S);
        if Idx=0 then
         V:=VNone
        else
         if (Idx >= 1) And (Idx <= 5) then
          begin
            for I:=1 to Idx do
             begin
               CH:=UpCase(S[I]);
               case CH of
                'F' :
                  begin
                    V:=V or VFatal;
                    GenerateError;
                    DoStop:=True;
                  end;
                'E','W','N','H':
                  begin
                    if CH='E' then
                      ST:=ms_error
                    else
                      ST:=GetMessageState(W);
                    { We only want to know about local value }
                    ST:= TMsgState(Ord(ST) and ms_local_mask);
                    if ST=ms_error then
                      begin
                        V:=V or VError;
                        GenerateError;
                      end
                    else if ST<>ms_off then
                      case CH of
                       'W':
                         begin
                           V:=V or VWarning;
                           if CheckVerbosity(VWarning) then
                             if Status.ErrorWarning then
                              GenerateError
                             else
                              Inc(Status.CountWarnings);
                         end;
                       'N' :
                         begin
                           V:=V or VNote;
                           if CheckVerbosity(VNote) then
                             if Status.ErrorNote then
                              GenerateError
                             else
                              Inc(Status.CountNotes);
                         end;
                       'H' :
                         begin
                           V:=V or VHint;
                           if CheckVerbosity(VHint) then
                             if Status.ErrorHint then
                              GenerateError
                             else
                              Inc(Status.CountHints);
                         end;
                      end;
                  end;
                'O' :
                  V:=V or VNormal;
                'I' :
                  V:=V or VInfo;
                'L' :
                  V:=V or VLineInfo;
                'U' :
                  V:=V or VUsed;
                'T' :
                  V:=V or VTried;
                'C' :
                  V:=V or VConditional;
                'D' :
                  V:=V or VDebug;
                'X' :
                  V:=V or VExecutable;
                'S' :
                  DoStop:=True;
                '_' : ;
               end;
             end;
          end;
        Delete(S,1,Idx);
      { check verbosity level }
        if not CheckVerbosity(V) then
          begin
            DoQueue := OnQueue <> nil;
            if not DoQueue then
              Exit;
          end;
        if (V and VLineInfoMask)<>0 then
          V:=V or VLineInfo;
      { fix status }
        UpdateStatus;
      { Fix replacements }
        DefaultReplacements(S,False);
        if Status.ShowMsgNrs and ((V and VNormal)=0) then
          S:='('+ToStr(W)+') '+S;
        if DoQueue then
          begin
            OnQueue(S,V,W);
            Exit;
          end;
      { show comment }
        if Do_Comment(V,S) or DoStop then
          raise ECompilerAbort.Create;
        if (Status.ErrorCount>=Status.MaxErrorCount) and not Status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(Status.ErrorCount));
            Status.SkipError:=True;
            raise ECompilerAbort.Create;
          end;
      end;


    function  MessageStr(W:LongInt):TMsgStr;
      begin
        MaybeLoadMessageFile;
        MessageStr:=Msg^.Get(W,[]);
      end;


    procedure Message(W:LongInt;OnQueue:TMsgQueueEvent=nil);
      begin
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[]),W,OnQueue);
      end;


    procedure Message1(W:LongInt;const S1:TMsgStr;OnQueue:TMsgQueueEvent=nil);

      begin
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1]),W,OnQueue);
      end;


    procedure Message2(W:LongInt;const S1,S2:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      begin
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2]),W,OnQueue);
      end;


    procedure Message3(W:LongInt;const S1,S2,S3:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      begin
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2,S3]),W,OnQueue);
      end;


    procedure Message4(W:LongInt;const S1,S2,S3,S4:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      begin
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2,S3,S4]),W,OnQueue);
      end;


    procedure MessagePos(const Pos:TFilePosInfo;W:LongInt;OnQueue:TMsgQueueEvent=nil);
      var
        OldPos : TFilePosInfo;
      begin
        OldPos:=CurrentFilePos;
        CurrentFilePos:=Pos;
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[]),W,OnQueue);
        CurrentFilePos:=OldPos;
      end;


    procedure MessagePos1(const Pos:TFilePosInfo;W:LongInt;const S1:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      var
        OldPos : TFilePosInfo;
      begin
        OldPos:=CurrentFilePos;
        CurrentFilePos:=Pos;
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1]),W,OnQueue);
        CurrentFilePos:=OldPos;
      end;


    procedure MessagePos2(const Pos:TFilePosInfo;W:LongInt;const S1,S2:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      var
        OldPos : TFilePosInfo;
      begin
        OldPos:=CurrentFilePos;
        CurrentFilePos:=Pos;
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2]),W,OnQueue);
        CurrentFilePos:=OldPos;
      end;


    procedure MessagePos3(const Pos:TFilePosInfo;W:LongInt;const S1,S2,S3:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      var
        OldPos : TFilePosInfo;
      begin
        OldPos:=CurrentFilePos;
        CurrentFilePos:=Pos;
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2,S3]),W,OnQueue);
        CurrentFilePos:=OldPos;
      end;


    procedure MessagePos4(const Pos:TFilePosInfo;W:LongInt;const S1,S2,S3,S4:TMsgStr;OnQueue:TMsgQueueEvent=nil);
      var
        OldPos : TFilePosInfo;
      begin
        OldPos:=CurrentFilePos;
        CurrentFilePos:=Pos;
        MaybeLoadMessageFile;
        Msg2Comment(Msg^.Get(W,[S1,S2,S3,S4]),W,OnQueue);
        CurrentFilePos:=OldPos;
      end;


{*****************************************************************************
            override the message calls to set codegenerror
*****************************************************************************}

    procedure CGMessage(T : LongInt);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.Message(T);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessage1(T : LongInt;const S : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.Message1(T,S);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessage2(T : LongInt;const S1,S2 : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.Message2(T,S1,S2);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessage3(T : LongInt;const S1,S2,S3 : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.Message3(T,S1,S2,S3);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;


    procedure CGMessagePos(const Pos:TFilePosInfo;T : LongInt);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.MessagePos(Pos,T);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessagePos1(const Pos:TFilePosInfo;T : LongInt;const S1 : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.MessagePos1(Pos,T,S1);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessagePos2(const Pos:TFilePosInfo;T : LongInt;const S1,S2 : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.MessagePos2(Pos,T,S1,S2);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;

    procedure CGMessagePos3(const Pos:TFilePosInfo;T : LongInt;const S1,S2,S3 : TMsgStr);
      var
         OldErrorCount : LongInt;
      begin
         if not(CodeGenError) then
           begin
              OldErrorCount:=ErrorCount;
              Verbose.MessagePos3(Pos,T,S1,S2,S3);
              CodeGenError:=OldErrorCount<>ErrorCount;
           end;
      end;


    procedure FlushOutput;
      begin
        if not (Status.UseStdErr) then (* StdErr is flushed after every line *)
          begin
            if Status.UseRedir then
              Flush(Status.RedirFile)
            else
              Flush(Output);
          end;
      end;


{*****************************************************************************
                                Initialization
*****************************************************************************}

    procedure InitVerbose;
      begin
      { Init }
        Msg:=New(PMessage,Init(20,MsgIdxMax));
        if Msg=nil then
         begin
           WriteLn('Fatal: MsgIdx Wrong');
           Halt(3);
         end;
{$ifndef EXTERN_MSG}
        Msg^.LoadIntern(@MsgTxt,MsgTxtSize,msgtxt_codepage);
{$else EXTERN_MSG}
        LoadMsgFile(ExePath+'errore.msg');
{$endif EXTERN_MSG}
        FillChar(Status,SizeOf(TCompilerStatus),0);
        Status.Verbosity:=VDefault;
        Status.MaxErrorCount:=50;
        Status.CodeSize:=AWord(-1);
        Status.DataSize:=AWord(-1);
        LoadPrefixes;
        LastFileIdx:=-1;
        LastModuleIdx:=-1;
        Status.CurrentModule:='';
        Status.CurrentSourcePPUFileName:='';
        Status.CurrentSource:='';
        Status.CurrentSourcePath:='';
        { Register internalerrorproc for cutils/cclasses }
        InternalErrorProc:=@InternalError;
      end;


    procedure DoneVerbose;
      begin
        if Assigned(Msg) then
         begin
           Dispose(Msg,Done);
           Msg:=nil;
         end;
        DoneRedirectFile;
      end;


    procedure PrintNodeIndent; inline;
      begin
        PrintNodeIndention:=PrintNodeIndention+PrintNodeSpacing;
      end;


    procedure PrintNodeUnindent; inline;
      begin
        Delete(PrintNodeIndention,1,Length(PrintNodeSpacing));
      end;



finalization
  { Be sure to close the redirect files to flush all data }
  DoneRedirectFile;
end.
