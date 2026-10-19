{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the scanner part and handling of the switches

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
unit scanner;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       CClasses,
       GlobType,Globals,ConstExp,version,tokens,
       symtype,symdef,SymSym,
       Verbose,CompHook,
       FinPut,
       WideStr;

    const
       cMaxIncludeNesting=32;
       cMaxMacroNesting=16;

       { when parsing an internally generated macro, if an identifier is
         prefixed with this constant then it will always be interpreted as a
         unit name (to avoid clashes with user-specified parameter or field
         names duplicated in internally generated code) }
       cInternalMacroEscapeUnitNamespaceName = #1;

       cInternalMacroEscapeBegin = cInternalMacroEscapeUnitNamespaceName;
       cInternalMacroEscapeEnd = cInternalMacroEscapeUnitNamespaceName;


    type
       TCommentStyle = (commentNone,commentTP,commentOldTP,commentDelphi,commentC);

       TScannerFile = class;

       TPreProcType = (ppIfDef,ppIfNDef,ppIf,ppIfOpt,ppElse,ppElseIf);

       TPreProcStack = class
          FType,
          { stores the preproctyp of the last (else)if(ndef) directive
            so we can check properly for ifend when legacyifend is on }
          FIfType   : TPreProcType;
          FAccept  : Boolean;
          FNext    : TPreProcStack;
          FName    : TIDString;
          FLineNumber : LongInt;
          FFileIndex : LongInt;
          constructor Create(AType:TPreProcType;AAccept:Boolean;ANext:TPreProcStack);
       end;

       TDirectiveProc=procedure;

       TDirectiveItem = class(TFPHashObject)
       public
          FIsConditional : Boolean;
          FProc : TDirectiveProc;
          constructor Create(AList:TFPHashObjectList;const AName:String;AProc:TDirectiveProc);
          constructor CreateCond(AList:TFPHashObjectList;const AName:String;AProc:TDirectiveProc);
       end;

       // stack for replay buffers
       TReplayStack = class
         FToken    : TToken;
         FIDToken  : TToken;
         FOrgPattern,
         FPattern  : ShortString;
         FCStringPattern: AnsiString;
         FPatternW : TCompilerWideString;
         FSettings : TSettings;
         FTokenBuf : TDynamicArray;
         FNext     : TReplayStack;
         FPending  : TPendingState;
         FVerbosity : LongInt;
         constructor Create(AToken: TToken;AIDToken:TToken;
           const AOrgPattern,APattern:ShortString;const ACStringPattern:AnsiString;
           APatternW:TCompilerWideString;ASettings:TSettings;
           ATokenBuf:TDynamicArray;const APending:TPendingState;
           AVerbosity:LongInt;ANext:TReplayStack);
         destructor Destroy;override;
       end;

       TCompileTimePredicate = function(var AValueDescr: String) : Boolean;

       TSpecialGenericToken =
         (sgtLoadSettings,
          sgtLine,
          sgtColumn,
          sgtFileIndex,
          sgtLoadMessages);

       { tscannerfile }
       TScannerFile = class
       private
         procedure DoGetTokenPos(out ATokenPos: LongInt; out AFilePos: TFilePosInfo);
         procedure CacheNextTokenPos;
         procedure PostProcessMultiline(ALength, AQuotePosition, AQuoteCount: Integer);
         procedure PostProcessUTF8Multiline(ALength, AQuotePosition, AQuoteCount: Integer);
         procedure SetNextToken;
         procedure SaveTokenPos;
         procedure RestoreTokenPos;
         procedure WriteToken(AToken: TToken);
         function ReadToken : TToken;
       public
          FInputFile    : TInputFile;  { current inputfile list }
          FInputFileCount : LongInt;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
       private
          FHiddenInputBuffer,                { input buffer }
          FHiddenInputPointer : pchar;
          { Gets char at inputpointer with offset,
            after checking that it doesn't overflow inputfile.bufsize }
          function GetInputPointerChar(AOffset : LongInt = 0) : Char;
          procedure IncInputPointer(AAmount : LongInt = 1);
          procedure DecInputPointer;
       public
{$else not CHECK_INPUTPOINTER_LIMITS}
          FInputBuffer,                { input buffer }
          FInputPointer : pchar;
{$endif}
          FInputStart   : LongInt;

          FLineNumber,                    { line }
          FLastLinePos  : LongInt;

          FLastTokenPos,
          FNextTokenPos : LongInt;     { token }
          FLastToken,
          FNextToken    : TToken;

          { read strings }
          FChar              : char;

          FOrgPattern,
          FPattern        : ShortString;
          FCStringPattern : AnsiString;
          FPatternW       : TCompilerWideString;

          { token }
          FToken,                        { current token being parsed }
          FIDToken    : TToken;          { holds the token if the pattern is a known word }

          FOldLastTokenPos     : LongInt; { temporary saving/restoring tokenpos }
          FOldCurrentFilePos,
          FOldCurrentTokenPos : TFilePosInfo;

          FReplayTokenBuf,
          FRecordTokenBuf : TDynamicArray;

          { last settings we stored }
          FLastSettings : TSettings;
          FLastMessage : PMessageStateRecord;
          { last filepos we stored }
          FLastFilePos,
          { if nexttoken<>NOTOKEN, then nexttokenpos holds its filepos }
          FNextFilePos   : TFilePosInfo;

          { current macro nesting depth }
          FMacroNestingDepth,
          FCommentLevel,
          FYYLexCount     : LongInt;
          FIgnoreDirectives : TFPHashList; { ignore directives, used to give warnings only once }
          FPreProcStack   : TPreProcStack;
          FReplayStack    : TReplayStack;

          FPreProcPattern : string;
          FPreProcToken   : TToken;

          { true, if we are parsing preprocessor expressions }
          FInPreProcCompExpr : boolean;
          { hack to allow reading generic generated identifiers IDs}
          FAllowGenericID : boolean;

          { Having these tracked in the scanner class itself versus local variables allows for
            informative error handling that would be impossible otherwise }
          FInMultilineString, FHadMultilineString : boolean;
          FMultilineStartLine : LongInt;
          FMultilineStartColumn : word;

          FCurrentCommentStyle : TCommentStyle; { needed to use read_comment from directives }

          constructor Create(const AFileName:String; AIsMacro: Boolean = false);
          destructor Destroy;override;
        { File buffer things }
          function  OpenInputFile:Boolean;
          procedure CloseInputFile;
          function  TempOpenInputFile:Boolean;
          procedure TempCloseInputFile;
          procedure SaveInputFile;
          procedure RestoreInputFile;
          procedure FirstFile;
          procedure NextFile;
          procedure AddFile(AInputFile:TInputFile);
          procedure Reload;
          { replaces current token with the text in p }
          procedure SubstituteMacro(const AMacroName:String;AText:pchar;ALength,ALine,AFileIndex:LongInt;AInternallyGenerated: Boolean);
        { Scanner things }
          procedure GetTokenPos;
          procedure IncCommentLevel;
          procedure DecCommentLevel;
          procedure IllegalChar(AChar:Char);
          procedure HandleEndOfFile;
          procedure CheckPreProcStack;
          procedure PopPreProcStack;
          procedure IfPreProcStack(AType:TPreProcType;ACompileTimePredicate:TCompileTimePredicate;AMessageID:LongInt);
          procedure ElseIfPreProcStack(ACompileTimePredicate:TCompileTimePredicate);
          procedure ElsePreProcStack;
          procedure PopReplayStack;
          function ReplayStackDepth:LongInt;
          procedure HandleConditional(ADirective:TDirectiveItem);
          procedure HandleDirectives;
          procedure LineBreak;
          procedure RecordToken;
          procedure StartRecordTokens(ABuffer:TDynamicArray);
          procedure StopRecordTokens;
          function IsRecordingTokens:Boolean;
          procedure ReplayToken;
          procedure StartReplayTokens(ABuffer:TDynamicArray);
          { bit length asizeint is target depend }
          procedure TokenWriteSizeInt(AValue : asizeint);
          procedure TokenWriteLongInt(AValue : LongInt);
          procedure TokenWriteLongWord(AValue : LongWord);
          procedure TokenWriteByte(AValue : Byte);
          procedure TokenWriteWord(AValue : Word);
          procedure TokenWriteShortInt(AValue : ShortInt);
          procedure TokenWriteSet(var AValue;ASize : LongInt);
          procedure TokenWriteEnum(var AValue;ASize : LongInt);
          function  TokenReadSizeInt : asizeint;
          procedure TokenWriteSettings(var ASettings : TSettings; var ASize : asizeint);
          { longword/longint are 32 bits on all targets }
          { word/smallint are 16-bits on all targets }
          function  TokenReadLongWord : LongWord;
          function  TokenReadWord : Word;
          function  TokenReadLongInt : LongInt;
          function  TokenReadSmallInt : SmallInt;
          { short int is one a signed byte }
          function  TokenReadShortInt : ShortInt;
          function  TokenReadByte : Byte;
          { This one takes the set size as an parameter }
          procedure TokenReadSet(var AValue;ASize : LongInt);
          function  TokenReadEnum(ASize : LongInt) : LongWord;

          procedure TokenReadSettings(var ASettings : TSettings; AExpectedSize : asizeint);
          procedure ReadChar;
          procedure ReadString;
          procedure ReadNumber;
          function  ReadID:String;
          function  ReadVal:LongInt;
          function  ReadVal64:Int64;
          function  ReadComment(AIncludeSpecialChar: Boolean = false):ShortString;
          function  ReadQuotedString:ShortString;
          function  ReadLongComment(AIncludeSpecialChar: Boolean = false):RawByteString;
          function  ReadLongQuotedString:RawByteString;
          function ReadStringConstant: Boolean;
          function  ReadState:Char;
          function  ReadOptionalState(AFallback:Char):Char;
          function  ReadStateDefault:Char;
          procedure SkipSpace;
          procedure SkipUntilDirective;
          procedure SkipComment(AReadFirstChar:Boolean);
          procedure SkipDelphiComment;
          procedure SkipOldTPComment(AReadFirstChar:Boolean);
          procedure ReadToken(AAllowRecordToken:Boolean);
          function  ReadPreProc:TToken;
          function  ReadPreProcInt(var AValue:int64;const APlace:String):Boolean;
          function  ReadPreProcSet(AConformTo:TSetDef;var AValue:TNormalSet;const APlace:String):Boolean;
          function  AsmGetChar:Char;
{$ifdef EXTDEBUG}
          function DumpPointer : String;
{$endif EXTDEBUG}
       end;

    type
        TDirectiveMode = (directiveAll, directiveTurbo, directiveMac);

    procedure AddDirective(const AName:String; AMode: TDirectiveMode; AProc:TDirectiveProc);
    procedure AddConditional(const AName:String; AMode: TDirectiveMode; AProc:TDirectiveProc);

    procedure InitScanner;
    procedure DoneScanner;

    function CurrentScanner : TScannerFile;  { current scanner in use }
    procedure SetCurrentScanner(AScanner : TScannerFile);  { current scanner in use }

    { To be called when the language mode is finally determined }
    Function SetCompileMode(const AName:String; AChangeInit: Boolean):Boolean;
    Function SetCompileModeSwitch(AName:String; AChangeInit: Boolean):Boolean;
    procedure SetAppType(ANewAppType:TAppType);

    var
      OnFreeScanner : procedure(AScanner : TScannerFile) = nil;

implementation

    uses
      SysUtils,
      CUtils,CFileUtl,
      Systems,
      Switches,
      SymBase,SymTable,symconst,defutil,defcmp,node,
      { This is needed for tcputype }
      CPUInfo,
      FModule,FPPU,
      { this is needed for $I %CURRENTROUTINE%}
      ProcInfo;

    var
      { dictionaries with the supported directives }
      TurboScannerDirectives : TFPHashObjectList;     { for other modes }
      MacScannerDirectives   : TFPHashObjectList;     { for mode mac }
      {
        By default the current_scanner is current_module.scanner.
        set_current_scanner sets the _temp_scanner variable.
        If _temp_scanner is set, it is returned as the current scanner
      }
      TempScanner : TScannerFile;

      function CurrentScanner : TScannerFile;  { current scanner in use }

      begin
        Result:=TempScanner;
        if Result<>nil then
          exit;
        if Assigned(CurrentModule) then
          Result:=TScannerFile(CurrentModule.Scanner)
        else
          Result:=Nil;
      end;

{*****************************************************************************
                              Helper routines
*****************************************************************************}

    const
      cDirectiveIgnored=pointer(1);
      { use any special name that is an invalid file name to avoid problems }
      cPreProcStrings : array [TPreProcType] of String[7]
        = ('$IFDEF','$IFNDEF','$IF','$IFOPT','$ELSE','$ELSEIF');

    function IsKeyword(const AName:String):Boolean;
      var
        lLow,lHigh,lMid : LongInt;
      begin
        if not (length(AName) in [tokenlenmin..tokenlenmax]) or
           not (AName[1] in ['a'..'z','A'..'Z']) then
         begin
           IsKeyword:=false;
           exit;
         end;
        lLow:=ord(tokenidx^[length(AName),AName[1]].first);
        lHigh:=ord(tokenidx^[length(AName),AName[1]].last);
        while lLow<lHigh do
         begin
           lMid:=(lHigh+lLow+1) shr 1;
           if CurrentScanner.FPattern<tokeninfo^[TToken(lMid)].str then
            lHigh:=lMid-1
           else
            lLow:=lMid;
         end;
        IsKeyword:=(CurrentScanner.FPattern=tokeninfo^[TToken(lHigh)].str) and
                    ((tokeninfo^[TToken(lHigh)].keyword*CurrentSettings.ModeSwitches)<>[]);
      end;


    Procedure HandleModeSwitches(ASwitch: TModeSwitch; AChangeInit: Boolean);
      begin
        { The compiler invocation owns the default String/Char/PChar model.
          A source language mode may change grammar but cannot change it. }
        if ASwitch in [m_none,m_default_ansistring,m_default_unicodestring] then
          begin
            if CompilerWide_Unicode_Strings then
              begin
                exclude(CurrentSettings.ModeSwitches,m_default_ansistring);
                include(CurrentSettings.ModeSwitches,m_default_unicodestring);
                Def_System_Macro('FPC_UNICODESTRINGS');
              end
            else
              begin
                exclude(CurrentSettings.ModeSwitches,m_default_unicodestring);
                include(CurrentSettings.ModeSwitches,m_default_ansistring);
                Undef_System_Macro('FPC_UNICODESTRINGS');
              end;
            include(CurrentSettings.LocalSwitches,cs_refcountedstrings);
            if AChangeInit then
              begin
                InitSettings.ModeSwitches:=CurrentSettings.ModeSwitches;
                include(InitSettings.LocalSwitches,cs_refcountedstrings);
              end;
          end;

        { turn inline on by default ? }
        if ASwitch in [m_none,m_default_inline] then
          begin
            if (m_default_inline in CurrentSettings.ModeSwitches) then
             begin
               include(CurrentSettings.LocalSwitches,cs_do_inline);
               if AChangeInit then
                 include(InitSettings.LocalSwitches,cs_do_inline);
             end
            else
             begin
               exclude(CurrentSettings.LocalSwitches,cs_do_inline);
               if AChangeInit then
                 exclude(InitSettings.LocalSwitches,cs_do_inline);
             end;
          end;

        { turn on system codepage by default }
        if ASwitch in [m_none,m_systemcodepage] then
          begin
            { both m_systemcodepage and specifying a code page via -FcXXX or
              "$codepage XXX" change current_settings.sourcecodepage. If
              we used -FcXXX and then have a sourcefile with "$mode objfpc",
              this routine will be called to disable m_systemcodepage (to ensure
              it's off in case it would have been set on the command line, or
              by a previous mode(switch).

              In that case, we have to ensure that we don't overwrite
              current_settings.sourcecodepage, as that would cancel out the
              -FcXXX. This is why we use two separate module switches
              (cs_explicit_codepage and cs_system_codepage) for the same setting
              (current_settings.sourcecodepage)
            }
            if m_systemcodepage in CurrentSettings.ModeSwitches then
              begin
                { m_systemcodepage gets enabled -> disable any -FcXXX and
                  "codepage XXX" settings (exclude cs_explicit_codepage), and
                  overwrite the source codepage }
                CurrentSettings.SourceCodePage:=DefaultSystemCodePage;
                if (CurrentSettings.SourceCodePage<>CP_UTF8) and not CPAvailable(CurrentSettings.SourceCodePage) then
                  begin
                    Message2(scan_w_unavailable_system_codepage,IntToStr(CurrentSettings.SourceCodePage),IntToStr(Default_Settings.SourceCodePage));
                    CurrentSettings.SourceCodePage:=Default_Settings.SourceCodePage;
                  end;
                exclude(CurrentSettings.ModuleSwitches,cs_explicit_codepage);
                include(CurrentSettings.ModuleSwitches,cs_system_codepage);
                if AChangeInit then
                  begin
                    InitSettings.SourceCodePage:=CurrentSettings.SourceCodePage;
                    exclude(InitSettings.ModuleSwitches,cs_explicit_codepage);
                    include(InitSettings.ModuleSwitches,cs_system_codepage);
                  end;
              end
            else
              begin
                { m_systemcodepage gets disabled -> reset sourcecodepage only if
                  cs_explicit_codepage is not set (it may be set in the scenario
                  where -FcXXX was passed on the command line and then "$mode
                  fpc" is used, because then the caller of this routine will
                  set the "$mode fpc" modeswitches (which don't include
                  m_systemcodepage) and call this routine with m_none).

                  Or it can happen if -FcXXX was passed, and the sourcefile
                  contains "$modeswitch systemcodepage-" statement.

                  Since we unset cs_system_codepage if m_systemcodepage gets
                  activated, we will revert to the default code page if you
                  set a source file code page, then enable the systemcode page
                  and finally disable it again. We don't keep a stack of
                  settings, by design. The only thing we have to ensure is that
                  disabling m_systemcodepage if it wasn't on in the first place
                  doesn't overwrite the sourcecodepage }
                exclude(CurrentSettings.ModuleSwitches,cs_system_codepage);
                if not(cs_explicit_codepage in CurrentSettings.ModuleSwitches) then
                  CurrentSettings.SourceCodePage:=Default_Settings.SourceCodePage;
                if AChangeInit then
                  begin
                    exclude(InitSettings.ModuleSwitches,cs_system_codepage);
                    if not(cs_explicit_codepage in InitSettings.ModuleSwitches) then
                      InitSettings.SourceCodePage:=Default_Settings.SourceCodePage;
                  end;
              end;
          end;


      end;

    procedure SetCurrentScanner(AScanner: TScannerFile);
    begin
      TempScanner:=AScanner;
    end;

    Function SetCompileMode(const AName:String; AChangeInit: Boolean):Boolean;
      var
        lValidMode : Boolean;
        lOldModeSwitches : TModeSwitches;
      begin
        if AName='DELPHIUNICODE' then
          begin
            if AChangeInit then
              begin
                if CompilerWide_String_Mode_Explicit and
                   not CompilerWide_Unicode_Strings then
                  begin
                    Message1(option_illegal_para,'-MDELPHIUNICODE conflicts with -MANSISTRINGS');
                    exit(true);
                  end;
                CompilerWide_Unicode_Strings:=true;
                CompilerWide_String_Mode_Explicit:=true;
              end
            else if not CompilerWide_Unicode_Strings then
              begin
                Message1(scan_e_illegal_directive,'MODE DELPHIUNICODE requires -MUNICODESTRINGS');
                exit(true);
              end;
          end;
        lOldModeSwitches:=CurrentSettings.ModeSwitches;

        lValidMode:=true;
        if AName='DEFAULT' then
          CurrentSettings.ModeSwitches:=FPCModeSwitches
        else
         if AName='DELPHI' then
          CurrentSettings.ModeSwitches:=DelphiModeSwitches
        else
         if AName='DELPHIUNICODE' then
          CurrentSettings.ModeSwitches:=DelphiUnicodeModeSwitches
        else
         if AName='FPC' then begin
          CurrentSettings.ModeSwitches:=FPCModeSwitches;
          { TODO: enable this for 2.3/2.9 }
          //  include(current_settings.localswitches, cs_typed_addresses);
        end else
         if AName='OBJFPC' then begin
          CurrentSettings.ModeSwitches:=ObjFPCModeSwitches;
          { TODO: enable this for 2.3/2.9 }
          //  include(current_settings.localswitches, cs_typed_addresses);
        end
        else
         if AName='MACPAS' then
          CurrentSettings.ModeSwitches:=MacModeSwitches
        else
         if AName='ISO' then
          CurrentSettings.ModeSwitches:=ISOModeSwitches
        else
         lValidMode:=false;


        if lValidMode and AChangeInit then
          InitSettings.ModeSwitches := CurrentSettings.ModeSwitches;

        if lValidMode then
         begin
           { resolve all postponed switch changes }
           FlushPendingSwitchesState;

           HandleModeSwitches(m_none,AChangeInit);

           { turn on bitpacking and case checking for mode macpas and iso pascal }
           if ([m_mac,m_iso] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_bitpacking);
               include(CurrentSettings.LocalSwitches,cs_check_all_case_coverage);
               if AChangeInit then
                 begin
                   include(InitSettings.LocalSwitches,cs_bitpacking);
                   include(InitSettings.LocalSwitches,cs_check_all_case_coverage);
                 end;
             end;

            { support goto/label by default in delphi/mac/iso modes }
            if ([m_delphi,m_mac,m_iso] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.ModuleSwitches,cs_support_goto);
               if AChangeInit then
                 include(InitSettings.ModuleSwitches,cs_support_goto);
             end;

           { support pointer math by default in fpc/objfpc modes }
           if ([m_fpc,m_objfpc] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_pointermath);
               if AChangeInit then
                 include(InitSettings.LocalSwitches,cs_pointermath);
             end
           else
             begin
               exclude(CurrentSettings.LocalSwitches,cs_pointermath);
               if AChangeInit then
                 exclude(InitSettings.LocalSwitches,cs_pointermath);
             end;

            { Default enum and set packing for Delphi }
            if m_delphi in CurrentSettings.ModeSwitches then
             begin
               CurrentSettings.PackEnum:=1;
               CurrentSettings.SetAlloc:=1;
             end
           else if (m_mac in CurrentSettings.ModeSwitches) then
             begin
               { compatible with Metrowerks Pascal }
               CurrentSettings.PackEnum:=2;
               CurrentSettings.SetAlloc:=Default_Settings.SetAlloc;
             end
           else
             begin
               CurrentSettings.PackEnum:=Default_Settings.PackEnum;
               CurrentSettings.SetAlloc:=Default_Settings.SetAlloc;
             end;

           if AChangeInit then
             begin
               InitSettings.PackEnum:=CurrentSettings.PackEnum;
               InitSettings.SetAlloc:=CurrentSettings.SetAlloc;
             end;
{$if defined(i386)}
            { Default to Intel assembler for Delphi on i386 }
            if m_delphi in CurrentSettings.ModeSwitches then
             begin

               CurrentSettings.AsmMode:=asmmode_i386_intel;

               if AChangeInit then
                 InitSettings.AsmMode:=CurrentSettings.AsmMode;
             end;
{$endif i386}

           { Exception support explicitly turned on (mainly for macpas, to }
           { compensate for lack of interprocedural goto support)          }
           if (cs_support_exceptions in CurrentSettings.GlobalSwitches) then
             include(CurrentSettings.ModeSwitches,m_except);

            { Default strict string var checking in Delphi mode }
            if m_delphi in CurrentSettings.ModeSwitches then
             begin
               include(CurrentSettings.LocalSwitches,cs_strict_var_strings);
               if AChangeInit then
                 include(InitSettings.LocalSwitches,cs_strict_var_strings);
             end;

           { in delphi mode, excess precision and open strings are by default on }
           if ([m_delphi] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_excessprecision);
               include(CurrentSettings.LocalSwitches,cs_openstring);
               if AChangeInit then
                 begin
                   include(InitSettings.LocalSwitches,cs_excessprecision);
                   include(InitSettings.LocalSwitches,cs_openstring);
                 end;
             end;



            { Undefine old symbol }
            if (m_delphi in lOldModeSwitches) then
              Undef_System_Macro('FPC_DELPHI')
            else if (m_objfpc in lOldModeSwitches) then
              Undef_System_Macro('FPC_OBJFPC')
            else if (m_mac in lOldModeSwitches) then
              Undef_System_Macro('FPC_MACPAS')
            else if (m_iso in lOldModeSwitches) then
              Undef_System_Macro('FPC_ISO');

            { define new symbol for the selected language mode }
            if (m_delphi in CurrentSettings.ModeSwitches) then
              Def_System_Macro('FPC_DELPHI')
            else if (m_objfpc in CurrentSettings.ModeSwitches) then
              Def_System_Macro('FPC_OBJFPC')
            else if (m_mac in CurrentSettings.ModeSwitches) then
              Def_System_Macro('FPC_MACPAS')
            else if (m_iso in CurrentSettings.ModeSwitches) then
              Def_System_Macro('FPC_ISO');
         end;

        SetCompileMode:=lValidMode;
      end;


    Function SetCompileModeSwitch(AName:String; AChangeInit: Boolean):Boolean;
      var
        lModeSwitch : TModeSwitch;
        lDoInclude : Boolean;
      begin
        AName:=upper(AName);

        { on/off? }
        lDoInclude:=true;
        case AName[length(AName)] of
          '+':
            SetLength(AName,length(AName)-1);
          '-':
            begin
              SetLength(AName,length(AName)-1);
              lDoInclude:=false;
            end;
        end;

        Result:=false;
        for lModeSwitch:=m_class to high(TModeSwitch) do
          if AName=modeswitchstr[ord(lModeSwitch)] then
            begin
              if lModeSwitch in [m_default_ansistring,m_default_unicodestring] then
                begin
                  Result:=true;
                  if not AChangeInit then
                    Message1(scan_e_illegal_directive,'MODESWITCH '+AName)
                  else if not lDoInclude then
                    Message1(option_illegal_para,'-M'+AName+'-')
                  else if CompilerWide_String_Mode_Explicit and
                          (CompilerWide_Unicode_Strings<>(lModeSwitch=m_default_unicodestring)) then
                    Message1(option_illegal_para,'-M'+AName+' conflicts with the selected string mode')
                  else
                    begin
                      CompilerWide_Unicode_Strings:=lModeSwitch=m_default_unicodestring;
                      CompilerWide_String_Mode_Explicit:=true;
                      if AChangeInit then
                        CurrentSettings.ModeSwitches:=InitSettings.ModeSwitches;
                      HandleModeSwitches(lModeSwitch,AChangeInit);
                    end;
                  break;
                end;
              { Objective-C is currently only supported for Darwin targets }
              if lDoInclude and
                 (lModeSwitch in [m_objectivec1,m_objectivec2]) and
                 not(TargetInfo.system in systems_objc_supported) then
                begin
                  Message1(option_unsupported_target_for_feature,'Objective-C');
                  break;
                end;

              { Blocks supported? }
              if lDoInclude and
                 (lModeSwitch = m_blocks) and
                 not(TargetInfo.system in systems_blocks_supported) then
                begin
                  Message1(option_unsupported_target_for_feature,'Blocks');
                  break;
                end;

              if AChangeInit then
                CurrentSettings.ModeSwitches:=InitSettings.ModeSwitches;
              Result:=true;
              if lDoInclude then
                begin
                  include(CurrentSettings.ModeSwitches,lModeSwitch);
                  { Objective-C 2.0 support implies 1.0 support }
                  if (lModeSwitch=m_objectivec2) then
                    include(CurrentSettings.ModeSwitches,m_objectivec1);
                  if (lModeSwitch in [m_objectivec1,m_objectivec2]) then
                    include(CurrentSettings.ModeSwitches,m_class);
                end
              else
                begin
                  exclude(CurrentSettings.ModeSwitches,lModeSwitch);
                  { Objective-C 2.0 support implies 1.0 support }
                  if (lModeSwitch=m_objectivec2) then
                    exclude(CurrentSettings.ModeSwitches,m_objectivec1);
                  if (lModeSwitch in [m_objectivec1,m_objectivec2]) and
                     ([m_delphi,m_objfpc]*CurrentSettings.ModeSwitches=[]) then
                    exclude(CurrentSettings.ModeSwitches,m_class);
                end;

              { set other switches depending on changed mode switch }
              HandleModeSwitches(lModeSwitch,AChangeInit);

              if AChangeInit then
                InitSettings.ModeSwitches:=CurrentSettings.ModeSwitches;

              break;
            end;
      end;

    procedure SetAppType(ANewAppType:TAppType);
      begin

        if AppType in [app_cui,app_com] then
          Undef_System_Macro('CONSOLE');
        AppType:=ANewAppType;
        if AppType in [app_cui,app_com] then
          Def_System_Macro('CONSOLE');
      end;
{*****************************************************************************
                           Conditional Directives
*****************************************************************************}

    procedure DirElse;
      begin
        CurrentScanner.ElsePreProcStack;
      end;

    procedure DirEndIf;
      begin
        if (cs_legacyifend in CurrentSettings.LocalSwitches) and
          (CurrentScanner.FPreProcStack.FType<>ppIfDef) and (CurrentScanner.FPreProcStack.FType<>ppIfNDef) and
            not((CurrentScanner.FPreProcStack.FType=ppElse) and (CurrentScanner.FPreProcStack.FIfType in [ppIfDef,ppIfNDef])) then
          Message(scan_e_unexpected_endif);
        CurrentScanner.PopPreProcStack;
      end;

    procedure DirIfEnd;
      begin
        if (cs_legacyifend in CurrentSettings.LocalSwitches) and
          (CurrentScanner.FPreProcStack.FType<>ppElseIf) and (CurrentScanner.FPreProcStack.FType<>ppIf) and
            not((CurrentScanner.FPreProcStack.FType=ppElse) and (CurrentScanner.FPreProcStack.FIfType in [ppIf,ppElseIf])) then
          Message(scan_e_unexpected_ifend);
        CurrentScanner.PopPreProcStack;
      end;

    function IsDef(var AValueDescr: String): Boolean;
      var
        lName    : String;
      begin
        CurrentScanner.SkipSpace;
        lName:=CurrentScanner.ReadID;
        AValueDescr:= lName;
        if lName='' then
          Message(scan_e_error_in_preproc_expr);
        IsDef:=Defined_Macro(lName);
      end;

    procedure DirIfDef;
      begin
        CurrentScanner.IfPreProcStack(ppIfDef,@IsDef,scan_c_ifdef_found);
      end;

    function IsNotDef(var AValueDescr: String): Boolean;
      var
        lName    : String;
      begin
        CurrentScanner.SkipSpace;
        lName:=CurrentScanner.ReadID;
        AValueDescr:= lName;
        if lName='' then
          Message(scan_e_error_in_preproc_expr);
        IsNotDef:=not Defined_Macro(lName);
      end;

    procedure DirIfNDef;
      begin
        CurrentScanner.IfPreProcStack(ppIfNDef,@IsNotDef,scan_c_ifndef_found);
      end;

    function OptCheck(var AValueDescr: String): Boolean;
      var
        lName    : String;
        lState : Char;
      begin
        OptCheck:= false;
        CurrentScanner.SkipSpace;
        lName:=CurrentScanner.ReadID;
        AValueDescr:= lName;
        if (length(lName)>1) then
          Message1(scan_w_illegal_switch,lName)
        else
          begin
            lState:=CurrentScanner.ReadState;
            if lState in ['-','+'] then
              OptCheck:=CheckSwitch(lName[1],lState)
            else
              Message(scan_e_error_in_preproc_expr);
          end;
      end;

    procedure DirIfOpt;
      begin
        FlushPendingSwitchesState;
        CurrentScanner.IfPreProcStack(ppIfOpt,@OptCheck,scan_c_ifopt_found);
      end;

    procedure DirLibPrefix;
      var
        lName : String;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.FChar);
        lName := CurrentScanner.ReadQuotedString;
        StringDispose(OutputPrefix);
        OutputPrefix := StringDup(lName);
        with CurrentModule do
         setfilename(ParamFN, ParamAllowOutput);
      end;

    procedure DirLibSuffix;
      var
        lName : String;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.FChar);
        lName := CurrentScanner.ReadQuotedString;
        StringDispose(OutputSuffix);
        OutputSuffix := StringDup(lName);
        with CurrentModule do
          setfilename(ParamFN, ParamAllowOutput);
      end;

    procedure DirExtension;
      var
        lName : String;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.FChar);
        lName := CurrentScanner.ReadQuotedString;
        if OutputFileName='' then
          OutputFileName:=InputFileName;
        OutputFileName:=ChangeFileExt(OutputFileName,'.'+lName);
        with CurrentModule do
          setfilename(ParamFN, ParamAllowOutput);
      end;

{
Compile time expression type check
----------------------------------
Each subexpression returns its type to the caller, which then can
do type check.  Since data types of compile time expressions is
not well defined, the type system does a best effort. The drawback is
that some errors might not be detected.

Instead of returning a particular data type, a set of possible data types
are returned. This way ambiguous types can be handled.  For instance a
value of 1 can be both a boolean and and integer.

Booleans
--------

The following forms of boolean values are supported:
* C coded, that is 0 is false, non-zero is true.
* TRUE/FALSE for mac style compile time variables

Thus boolean mac compile time variables are always stored as TRUE/FALSE.
When a compile time expression is evaluated, they are then translated
to C coded booleans (0/1), to simplify for the expression evaluator.

Note that this scheme then also of support mac compile time variables which
are 0/1 but with a boolean meaning.

The TRUE/FALSE format is new from 22 august 2005, but the above scheme
means that units which is not recompiled, and thus stores
compile time variables as the old format (0/1), continue to work.

Short circuit evaluation
------------------------
For this to work, the part of a compile time expression which is short
circuited, should not be evaluated, while it still should be parsed.
Therefor there is a parameter eval, telling whether evaluation is needed.
In case not, the value returned can be arbitrary.
}

type

  { texprvalue }

  TExprValue = class
  private
    { we can't use built-in defs since they
      may be not created at the moment }
    class var
       FSIntDef,FUIntDef,FBoolDef,FStrDef,FSetDef,FRealDef: TDef;
    class constructor CreateDefs;
    class destructor DestroyDefs;
  public
    FConstTyp: TConstTyp;
    FValue: TConstValue;
    FDef: TDef;
    constructor CreateConst(AConstSym:TConstSym);
    constructor CreateError;
    constructor CreateOrd(AValue: TConstExprInt);
    constructor CreateInt(AValue: Int64);
    constructor CreateUInt(AValue: QWord);
    constructor CreateBool(AValue: Boolean);
    constructor CreateStr(const AValue: String);
    constructor CreateSet(AValue: TNormalSet);
    constructor CreateReal(AValue: BestReal);
    class function TryParseNumber(const AText:String):TExprValue; static;
    class function TryParseReal(const AText:String):TExprValue; static;
    function Evaluate(AValue:TExprValue;AOperator:TToken):TExprValue;
    procedure Error(AExpectedDef, APlace: String);
    function IsBoolean: Boolean;
    function IsInt: Boolean;
    function AsBool: Boolean;
    function AsInt: Integer;
    function AsInt64: Int64;
    function AsStr: String;
    function AsSet: TNormalSet;
    destructor Destroy; override;
  end;

  class constructor TExprValue.CreateDefs;
    begin
      { do not use corddef etc here: this code is executed before those
        variables are initialised. Since these types are only used for
        compile-time evaluation of conditional expressions, it doesn't matter
        that we use the base types instead of the cpu-specific ones. }
      FSIntDef:=TOrdDef.Create(s64bit,low(Int64),high(Int64),false);
      FUIntDef:=TOrdDef.Create(u64bit,low(QWord),high(QWord),false);
      FBoolDef:=TOrdDef.Create(pasbool1,0,1,false);
      FStrDef:=TStringDef.CreateAnsi(0,false);
      FSetDef:=TSetDef.Create(FSIntDef,0,255,false);
      FRealDef:=TFloatDef.Create(s80real,false);
    end;

  class destructor TExprValue.DestroyDefs;
    begin
      FSetDef.free;
      FSetDef := nil;
      FSIntDef.free;
      FSIntDef := nil;
      FUIntDef.free;
      FUIntDef := nil;
      FBoolDef.free;
      FBoolDef := nil;
      FStrDef.free;
      FStrDef := nil;
      FRealDef.free;
      FRealDef := nil;
    end;

  constructor TExprValue.CreateConst(AConstSym: TConstSym);
    begin
      FConstTyp:=AConstSym.ConstTyp;
      FDef:=AConstSym.ConstDef;
      case FConstTyp of
        conststring,
        constresourcestring:
          begin
            FValue.len:=AConstSym.Value.len;
            GetMem(FValue.ValuePtr,FValue.len+1);
            move(AConstSym.Value.ValuePtr^,FValue.ValuePtr^,FValue.len+1);
          end;
        constwstring,
        constwresourcestring:
          begin
            InitWideString(FValue.ValueWS);
            CopyWideString(AConstSym.Value.ValueWS,FValue.ValueWS);
          end;
        constreal:
          begin
            new(PBestReal(FValue.ValuePtr));
            PBestReal(FValue.ValuePtr)^:=PBestReal(AConstSym.Value.ValuePtr)^;
          end;
        constset:
          begin
            new(PNormalSet(FValue.ValuePtr));
            PNormalSet(FValue.ValuePtr)^:=PNormalSet(AConstSym.Value.ValuePtr)^;
          end;
        constguid:
          begin
            new(PGUID(FValue.ValuePtr));
            PGUID(FValue.ValuePtr)^:=PGUID(AConstSym.Value.ValuePtr)^;
          end;
        else
          FValue:=AConstSym.Value;
      end;
    end;

  constructor TExprValue.CreateError;
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constnone;
      FDef:=GenErrorDef;
    end;

  constructor TExprValue.CreateOrd(AValue: TConstExprInt);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constord;
      FValue.ValueOrd:=AValue;
      if AValue.signed then
        FDef:=FSIntDef
      else
        FDef:=FUIntDef;
    end;

  constructor TExprValue.CreateInt(AValue: Int64);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constord;
      FValue.ValueOrd:=AValue;
      FDef:=FSIntDef;
    end;

  constructor TExprValue.CreateUInt(AValue: QWord);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constord;
      FValue.ValueOrd:=AValue;
      FDef:=FUIntDef;
    end;

  constructor TExprValue.CreateBool(AValue: Boolean);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constord;
      FValue.ValueOrd:=ord(AValue);
      FDef:=FBoolDef;
    end;

  constructor TExprValue.CreateStr(const AValue: String);
    var
      lStringData: PAnsiChar;
      lLength: Integer;
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=conststring;
      lLength:=length(AValue);
      GetMem(lStringData,lLength+1);
      move(AValue[1],lStringData^,lLength+1);
      FValue.ValuePtr:=lStringData;
      FValue.len:=lLength;
      FDef:=FStrDef;
    end;

  constructor TExprValue.CreateSet(AValue: TNormalSet);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constset;
      new(PNormalSet(FValue.ValuePtr));
      PNormalSet(FValue.ValuePtr)^:=AValue;
      FDef:=FSetDef;
    end;

  constructor TExprValue.CreateReal(AValue: BestReal);
    begin
      fillchar(FValue,sizeof(FValue),#0);
      FConstTyp:=constreal;
      new(PBestReal(FValue.ValuePtr));
      PBestReal(FValue.ValuePtr)^:=AValue;
      FDef:=FRealDef;
    end;

  class function TExprValue.TryParseNumber(const AText:String):TExprValue;
    var
      lIntValue: Int64;
      lUIntValue: QWord;
      lCode: Integer;
    begin
      { try int64 }
      val(AText,lIntValue,lCode);
      if lCode=0 then
        Result:=TExprValue.CreateInt(lIntValue)
      else
        begin
          { try qword }
          val(AText,lUIntValue,lCode);
          if lCode=0 then
            Result:=TExprValue.CreateUInt(lUIntValue)
          else
            Result:=TryParseReal(AText);
        end;
    end;

  class function TExprValue.TryParseReal(const AText:String):TExprValue;
    var
      lRealValue: BestReal;
      lCode: Integer;
    begin
      Val(AText,lRealValue,lCode);
      if lCode=0 then
        Result:=TExprValue.CreateReal(lRealValue)
      else
        Result:=nil;
    end;

  function TExprValue.Evaluate(AValue:TExprValue;AOperator:TToken):TExprValue;

    function CheckCompatible: Boolean;
      begin
        Result:=(
                  (Is_Ordinal(AValue.FDef) or Is_FPU(AValue.FDef)) and
                  (Is_Ordinal(FDef) or Is_FPU(FDef))
                ) or
                (Is_StringLike(AValue.FDef) and Is_StringLike(FDef));
        if not Result then
          Message2(type_e_incompatible_types,FDef.TypeName,AValue.FDef.TypeName);
      end;
    var
      lLeftInt,lRightInt: TConstExprInt;
      lLeftReal,lRightReal: BestReal;
      lLeftString,lRightString: String;
    begin
      case AOperator of
        _OP_IN:
        begin
          if not Is_Set(AValue.FDef) then
            begin
              AValue.Error('Set', 'IN');
              Result:=TExprValue.CreateError;
            end
          else
          if not Is_Ordinal(FDef) then
            begin
              Error('Ordinal', 'IN');
              Result:=TExprValue.CreateError;
            end
          else
          if FValue.ValueOrd.signed then
            Result:=TExprValue.CreateBool(FValue.ValueOrd.svalue in PNormalSet(AValue.FValue.ValuePtr)^)
          else
            Result:=TExprValue.CreateBool(FValue.ValueOrd.uvalue in PNormalSet(AValue.FValue.ValuePtr)^);
        end;
        _OP_NOT:
        begin
          if IsBoolean then
            Result:=TExprValue.CreateBool(not AsBool)
          else if Is_Ordinal(FDef) then
            begin
              Result:=TExprValue.CreateOrd(FValue.ValueOrd);
              Result.FDef:=FDef;
              Calc_Not_OrdValue(Result.FValue.ValueOrd,Result.FDef);
            end
          else
            begin
              Error('Boolean', 'NOT');
              Result:=TExprValue.CreateError;
            end;
        end;
        _OP_OR:
        begin
          if IsBoolean then
            if AValue.IsBoolean then
              Result:=TExprValue.CreateBool(AsBool or AValue.AsBool)
            else
              begin
                AValue.Error('Boolean','OR');
                Result:=TExprValue.CreateError;
              end
          else if Is_Ordinal(FDef) then
            if Is_Ordinal(AValue.FDef) then
              Result:=TExprValue.CreateOrd(FValue.ValueOrd or AValue.FValue.ValueOrd)
            else
              begin
                AValue.Error('Ordinal','OR');
                Result:=TExprValue.CreateError;
              end
          else
            begin
              Error('Boolean','OR');
              Result:=TExprValue.CreateError;
            end;
        end;
        _OP_XOR:
        begin
          if IsBoolean then
            if AValue.IsBoolean then
              Result:=TExprValue.CreateBool(AsBool xor AValue.AsBool)
            else
              begin
                AValue.Error('Boolean','XOR');
                Result:=TExprValue.CreateError;
              end
          else if Is_Ordinal(FDef) then
            if Is_Ordinal(AValue.FDef) then
              Result:=TExprValue.CreateOrd(FValue.ValueOrd xor AValue.FValue.ValueOrd)
            else
              begin
                AValue.Error('Ordinal','XOR');
                Result:=TExprValue.CreateError;
              end
          else
            begin
              Error('Boolean','XOR');
              Result:=TExprValue.CreateError;
            end;
        end;
        _OP_AND:
        begin
          if IsBoolean then
            if AValue.IsBoolean then
              Result:=TExprValue.CreateBool(AsBool and AValue.AsBool)
            else
              begin
                AValue.Error('Boolean','AND');
                Result:=TExprValue.CreateError;
              end
          else if Is_Ordinal(FDef) then
            if Is_Ordinal(AValue.FDef) then
              Result:=TExprValue.CreateOrd(FValue.ValueOrd and AValue.FValue.ValueOrd)
            else
              begin
                AValue.Error('Ordinal','AND');
                Result:=TExprValue.CreateError;
              end
          else
            begin
              Error('Boolean','AND');
              Result:=TExprValue.CreateError;
            end;
        end;
        _EQ,_NE,_LT,_GT,_GTE,_LTE,_PLUS,_MINUS,_STAR,_SLASH,_OP_DIV,_OP_MOD,_OP_SHL,_OP_SHR:
        if (AOperator=_MINUS) and not(Assigned(AValue)) then
          begin
            if Is_Ordinal(FDef) then
              Result:=TExprValue.CreateOrd(-FValue.ValueOrd)
            else if Is_FPU(FDef) then
              Result:=TExprValue.CreateReal(-PBestReal(FValue.ValuePtr)^)
            else
              InternalError(2025050610);
          end
        else if CheckCompatible then
          begin
            if (Is_Ordinal(FDef) and Is_Ordinal(AValue.FDef)) then
              begin
                lLeftInt:=FValue.ValueOrd;
                lRightInt:=AValue.FValue.ValueOrd;
                case AOperator of
                  _EQ:
                    Result:=TExprValue.CreateBool(lLeftInt=lRightInt);
                  _NE:
                    Result:=TExprValue.CreateBool(lLeftInt<>lRightInt);
                  _LT:
                    Result:=TExprValue.CreateBool(lLeftInt<lRightInt);
                  _GT:
                    Result:=TExprValue.CreateBool(lLeftInt>lRightInt);
                  _GTE:
                    Result:=TExprValue.CreateBool(lLeftInt>=lRightInt);
                  _LTE:
                    Result:=TExprValue.CreateBool(lLeftInt<=lRightInt);
                  _PLUS:
                    Result:=TExprValue.CreateOrd(lLeftInt+lRightInt);
                  _MINUS:
                    Result:=TExprValue.CreateOrd(lLeftInt-lRightInt);
                  _STAR:
                    Result:=TExprValue.CreateOrd(lLeftInt*lRightInt);
                  _SLASH:
                    Result:=TExprValue.CreateReal(lLeftInt/lRightInt);
                  _OP_DIV:
                    Result:=TExprValue.CreateOrd(lLeftInt div lRightInt);
                  _OP_MOD:
                    Result:=TExprValue.CreateOrd(lLeftInt mod lRightInt);
                  _OP_SHL:
                    Result:=TExprValue.CreateOrd(lLeftInt shl lRightInt);
                  _OP_SHR:
                    Result:=TExprValue.CreateOrd(lLeftInt shr lRightInt);
                  else
                    InternalError(2025050611);
                end;
              end
            else
            if (Is_FPU(FDef) or Is_Ordinal(FDef)) and
               (Is_FPU(AValue.FDef) or Is_Ordinal(AValue.FDef)) then
              begin
                if Is_FPU(FDef) then
                  lLeftReal:=PBestReal(FValue.ValuePtr)^
                else
                  lLeftReal:=FValue.ValueOrd;
                if Is_FPU(AValue.FDef) then
                  lRightReal:=PBestReal(AValue.FValue.ValuePtr)^
                else
                  lRightReal:=AValue.FValue.ValueOrd;
                case AOperator of
                  _EQ:
                    Result:=TExprValue.CreateBool(lLeftReal=lRightReal);
                  _NE:
                    Result:=TExprValue.CreateBool(lLeftReal<>lRightReal);
                  _LT:
                    Result:=TExprValue.CreateBool(lLeftReal<lRightReal);
                  _GT:
                    Result:=TExprValue.CreateBool(lLeftReal>lRightReal);
                  _GTE:
                    Result:=TExprValue.CreateBool(lLeftReal>=lRightReal);
                  _LTE:
                    Result:=TExprValue.CreateBool(lLeftReal<=lRightReal);
                  _PLUS:
                    Result:=TExprValue.CreateReal(lLeftReal+lRightReal);
                  _MINUS:
                    Result:=TExprValue.CreateReal(lLeftReal-lRightReal);
                  _STAR:
                    Result:=TExprValue.CreateReal(lLeftReal*lRightReal);
                  _SLASH:
                    Result:=TExprValue.CreateReal(lLeftReal/lRightReal);
                  else
                    begin
                      Message(parser_e_illegal_expression);
                      Result:=TExprValue.CreateError;
                    end;
                end;
              end
            else
            begin
              lLeftString:=AsStr;
              lRightString:=AValue.AsStr;
              case AOperator of
                _EQ:
                  Result:=TExprValue.CreateBool(lLeftString=lRightString);
                _NE:
                  Result:=TExprValue.CreateBool(lLeftString<>lRightString);
                _LT:
                  Result:=TExprValue.CreateBool(lLeftString<lRightString);
                _GT:
                  Result:=TExprValue.CreateBool(lLeftString>lRightString);
                _GTE:
                  Result:=TExprValue.CreateBool(lLeftString>=lRightString);
                _LTE:
                  Result:=TExprValue.CreateBool(lLeftString<=lRightString);
                _PLUS:
                  Result:=TExprValue.CreateStr(lLeftString+lRightString);
                else
                  begin
                    Message(parser_e_illegal_expression);
                    Result:=TExprValue.CreateError;
                  end;
              end;
            end;
          end
        else
          Result:=TExprValue.CreateError;
        else
          Result:=TExprValue.CreateError;
      end;
    end;

  procedure TExprValue.Error(AExpectedDef, APlace: String);
    begin
      Message3(scan_e_compile_time_typeerror,
               AExpectedDef,
               FDef.TypeName,
               APlace
              );
    end;

  function TExprValue.IsBoolean: Boolean;
    var
      lValue: Int64;
    begin
      Result:=Is_Boolean(FDef);
      if not Result and Is_Integer(FDef) then
        begin
          lValue:=AsInt64;
          Result:=(lValue=0)or(lValue=1);
        end;
    end;

  function TExprValue.IsInt: Boolean;
    begin
      Result:=Is_Integer(FDef);
    end;

  function TExprValue.AsBool: Boolean;
    begin
      Result:=FValue.ValueOrd<>0;
    end;

  function TExprValue.AsInt: Integer;
    begin
      Result:=FValue.ValueOrd.svalue;
    end;

  function TExprValue.AsInt64: Int64;
    begin
      Result:=FValue.ValueOrd.svalue;
    end;

  function TExprValue.AsSet: TNormalSet;
    begin
      Result:=PNormalSet(FValue.ValuePtr)^;
    end;

  function TExprValue.AsStr: String;
    var
      lElement:Byte;
    begin
      case FConstTyp of
        constord:
          Result:=ToStr(FValue.ValueOrd);
        conststring,
        constresourcestring:
          SetString(Result,PChar(FValue.ValuePtr),FValue.len);
        constreal:
          Result:=RealToStr(PBestReal(FValue.ValuePtr)^);
        constset:
          begin
            Result:=',';
            for lElement:=0 to 255 do
              if lElement in PConstSet(FValue.ValuePtr)^ then
                Result:=Result+ToStr(lElement)+',';
          end;
        { error values }
        constnone:
          Result:='';
        else
          InternalError(2013112801);
      end;
    end;

  destructor TExprValue.Destroy;
    begin
      case FConstTyp of
        conststring,
        constresourcestring :
          FreeMem(FValue.ValuePtr,FValue.len+1);
        constwstring,
        constwresourcestring:
          DoneWideString(FValue.ValueWS);
        constreal :
          dispose(PBestReal(FValue.ValuePtr));
        constset :
          dispose(PNormalSet(FValue.ValuePtr));
        constguid :
          dispose(PGUID(FValue.ValuePtr));
        constnil,
        constpointer,
        constord,
        { error values }
        constnone:
          ;
      end;
      inherited Destroy;
    end;

  const
    cPreProcOperators=[_EQ,_NE,_LT,_GT,_LTE,_GTE,_MINUS,_PLUS,_STAR,_SLASH,_OP_DIV,_OP_MOD,_OP_SHL,_OP_SHR,_OP_IN,_OP_AND,_OP_OR,_OP_XOR];

    function FindIncludeFile(const APath,AName:TCmdStr;var AFoundFile:TCmdStr):Boolean;
      var
        lFound  : Boolean;
        lSearchPath  : TCmdStr;
      begin
        (* look for the include file
         If path was absolute and specified as part of {$I } then
          1. specified path
         else
          1. path of current inputfile,current dir
          2. local includepath
          3. global includepath

          -- Check mantis #13461 before changing this *)
         lFound:=false;
         AFoundFile:='';
         lSearchPath:='';
         if Path_Absolute(APath) then
           begin
             lFound:=FindFile(AName,APath,true,AFoundFile);
           end
         else
           begin
             lSearchPath:=CurrentScanner.FInputFile.path+';'+CurDirRelPath(SourceInfo);
             lFound:=FindFile(APath+AName, lSearchPath,true,AFoundFile);
             if not lFound then
               lFound:=CurrentModule.LocalIncludeSearchPath.FindFile(APath+AName,true,AFoundFile);
             if not lFound  then
               lFound:=IncludeSearchPath.FindFile(APath+AName,true,AFoundFile);
           end;
         Result:=lFound;
      end;


    function PreProcCompExpr(AConformTo:TDef):TExprValue;

        function PreProcSubExpr(APrecedence:TOperatorPrecedence;AEvaluate:Boolean):TExprValue; forward;

        procedure PreProcConsume(AToken:TToken);
        begin
          if AToken<>CurrentScanner.FPreProcToken then
            Message(scan_e_preproc_syntax_error);
          CurrentScanner.FPreProcToken:=CurrentScanner.ReadPreProc;
        end;

        function TryConsumeUnitSym(var ASym:TSym;var ASymTable:TSymTable;out ATokenToConsume:TToken):Boolean;
          var
            lModule: TModule;
            lNamespace:AnsiString;
            lNamespaceSym:TSym;
          begin
            Result:=false;
            ATokenToConsume:=_ID;

            if Assigned(ASym) and (ASym.typ in [UnitSym,namespacesym]) then
              begin
                if not(ASym.owner.SymTableType in [staticsymtable,GlobalSymTable]) then
                  InternalError(200501154);
                { only allow unit.symbol access if the name was
                  found in the current module
                  we can use iscurrentunit because generic specializations does not
                  change current_unit variable }
                lModule:=Find_Module_From_SymTable(ASym.Owner);
                if not Assigned(lModule) then
                  InternalError(201001120);
                if lModule.ModuleID=CurrentFilePos.moduleindex then
                  begin
                    PreProcConsume(_POINT);
                    CurrentScanner.SkipSpace;
                    if ASym.typ=namespacesym then
                      begin
                        lNamespace:=ASym.name;
                        lNamespaceSym:=ASym;
                        while Assigned(ASym) and (ASym.typ=namespacesym) do
                          begin
                            { we have a namespace. the next identifier should be either a namespace or a unit }
                            SearchSym_In_Module(lModule,lNamespace+'.'+CurrentScanner.FPreProcPattern,ASym,ASymTable);
                            if Assigned(ASym) and (ASym.typ in [namespacesym,UnitSym]) then
                              begin
                                lNamespace:=lNamespace+'.'+CurrentScanner.FPreProcPattern;
                                lNamespaceSym:=ASym;
                                PreProcConsume(_ID);
                                CurrentScanner.SkipSpace;
                                PreProcConsume(_POINT);
                                CurrentScanner.SkipSpace;
                              end;
                          end;
                        { check if there is a hidden unit with this pattern in the namespace }
                        if not Assigned(ASym) and
                           Assigned(lNamespaceSym) and (lNamespaceSym.typ=namespacesym) and Assigned(TNamespaceSym(lNamespaceSym).UnitSym) then
                          ASym:=TNamespaceSym(lNamespaceSym).UnitSym;
                        if Assigned(ASym) and (ASym.typ<>UnitSym) then
                          InternalError(201108260);
                        if not Assigned(ASym) then
                          begin
                            Result:=true;
                            ASymTable:=nil;
                            exit;
                          end;
                      end;
                    case CurrentScanner.FPreProcToken of
                      _ID:
                        { Resolve the default Char/PChar from the invocation's
                          text model, regardless of the System alias. }
                        if ((CurrentScanner.FPreProcPattern='CHAR') or
                            (CurrentScanner.FPreProcPattern='PCHAR')) and
                           (TModule(TUnitSym(ASym).module).GlobalSymTable=SystemUnit) then
                          begin
                            if CurrentScanner.FPreProcPattern='PCHAR' then
                              if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                SearchSym_In_Module(TUnitSym(ASym).module,'PWIDECHAR',ASym,ASymTable)
                              else
                                SearchSym_In_Module(TUnitSym(ASym).module,'PANSICHAR',ASym,ASymTable)
                            else if m_default_unicodestring in CurrentSettings.ModeSwitches then
                              SearchSym_In_Module(TUnitSym(ASym).module,'WIDECHAR',ASym,ASymTable)
                            else
                              SearchSym_In_Module(TUnitSym(ASym).module,'ANSICHAR',ASym,ASymTable)
                          end
                        else
                          SearchSym_In_Module(TUnitSym(ASym).module,CurrentScanner.FPreProcPattern,ASym,ASymTable);
                      _STRING:
                        begin
                          { system.string? }
                          if TModule(TUnitSym(ASym).module).GlobalSymTable=SystemUnit then
                            begin
                              if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                                begin
                                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                    SearchSym_In_Module(TUnitSym(ASym).module,'UNICODESTRING',ASym,ASymTable)
                                  else
                                    SearchSym_In_Module(TUnitSym(ASym).module,'ANSISTRING',ASym,ASymTable)
                                end
                              else
                                SearchSym_In_Module(TUnitSym(ASym).module,'SHORTSTRING',ASym,ASymTable);
                              ATokenToConsume:=_STRING;
                            end;
                        end
                      else
                        ;
                    end;
                  end
                else
                  begin
                    ASym:=nil;
                    ASymTable:=nil;
                  end;
                Result:=true;
              end;
          end;

        procedure TryConsumeNestedSym(var ASym:TSym;var ASymTable:TSymTable);
          var
            lDef:TDef;
            lTokenToConsume:TToken;
            lFound:Boolean;
          begin
            lFound:=TryConsumeUnitSym(ASym,ASymTable,lTokenToConsume);
            if lFound then
              begin
                PreProcConsume(lTokenToConsume);
                CurrentScanner.SkipSpace;
              end;
             while (CurrentScanner.FPreProcToken=_POINT) do
               begin
                 if Assigned(ASym)and(ASym.typ=TypeSym) then
                   begin
                     lDef:=TTypeSym(ASym).TypeDef;
                     if Is_Class_Or_Object(lDef) or Is_Record(lDef) then
                       begin
                         PreProcConsume(_POINT);
                         CurrentScanner.SkipSpace;
                         if lDef.typ=objectdef then
                           lFound:=SearchSym_In_Class(TObjectDef(lDef),TObjectDef(lDef),CurrentScanner.FPreProcPattern,ASym,ASymTable,[ssf_search_helper])
                         else
                           lFound:=SearchSym_In_Record(TRecordDef(lDef),CurrentScanner.FPreProcPattern,ASym,ASymTable);
                         if not lFound then
                           begin
                             Message1(sym_e_id_not_found,CurrentScanner.FPreProcPattern);
                             exit;
                           end;
                         PreProcConsume(_ID);
                         CurrentScanner.SkipSpace;
                       end
                     else
                       begin
                         Message(sym_e_type_must_be_rec_or_object_or_class);
                         exit;
                       end;
                   end
                 else
                   begin
                     Message(type_e_type_id_expected);
                     exit;
                   end;
               end;
          end;

        function PreProcSubstitutedToken(const ABaseSearchString:ShortString;AEvaluate:Boolean):TExprValue;
        { Currently this parses identifiers as well as numbers.
          The result from this procedure can either be that the token
          itself is a value, or that it is a compile time variable/macro,
          which then is substituted for another value (for macros
          recursively substituted).}

        var
          lText: ShortString;
          lMacro: TMacro;
          lMacroCount,
          lLength: Integer;
          lFoundMacro: Boolean;
          lSearchString: PShortString;
          lStoredSearchString: ShortString;
        begin
          if not AEvaluate then
            begin
              Result:=TExprValue.CreateStr(ABaseSearchString);
              exit;
            end;

          lSearchString := @ABaseSearchString;
          lMacro:=nil;
          lFoundMacro:=false;
          { Substitute macros and compiler variables with their content/value.
            For real macros also do recursive substitution. }
          lMacroCount:=0;
          repeat
            lMacro:=TMacro(Search_Macro(lSearchString^));

            inc(lMacroCount);
            if lMacroCount>cMaxMacroNesting then
              begin
                Message(scan_w_macro_too_deep);
                break;
              end;

            if Assigned(lMacro) and lMacro.defined then
              if Assigned(lMacro.BufText) then
                begin
                  if lMacro.BufLen>255 then
                    begin
                      lLength:=255;
                      Message(scan_w_macro_cut_after_255_chars);
                    end
                  else
                    lLength:=lMacro.BufLen;
                  lText[0]:=Char(lLength);
                  if lLength>0 then
                    move(lMacro.BufText[0],lText[1],lLength);
                  lStoredSearchString:=upcase(lText);
                  lSearchString:=@lStoredSearchString;
                  lMacro.IsUsed:=true;
                  lFoundMacro:=true;
                end
              else
                begin
                  Message1(scan_e_error_macro_lacks_value,lSearchString^);
                  break;
                end
            else
              break;

            if lMacro.IsCompilerVar then
              break;
          until false;

          { At this point, result do contain the value. Do some decoding and
            determine the type.}
          Result:=TExprValue.TryParseNumber(lSearchString^);
          if not Assigned(Result) then
            begin
              if lFoundMacro and (lSearchString^='FALSE') then
                Result:=TExprValue.CreateBool(false)
              else if lFoundMacro and (lSearchString^='TRUE') then
                Result:=TExprValue.CreateBool(true)
              else if (m_mac in CurrentSettings.ModeSwitches) and
                      (not Assigned(lMacro) or not lMacro.defined) and
                      (lMacroCount = 1) then
                begin
                  {Errors in mode mac is issued here. For non macpas modes there is
                   more liberty, but the error will eventually be caught at a later stage.}
                  Message1(scan_e_error_macro_undefined,lSearchString^);
                  Result:=TExprValue.CreateStr(lSearchString^); { just to have something }
                end
              else
                Result:=TExprValue.CreateStr(lSearchString^);
            end;
        end;

        procedure MarkSymbolAsUsed(ASym: TSym);
          begin
           ASym.IncRefCount;
           { do we know an owner? }
           if Assigned(CurrentModule) and Assigned(CurrentModule.UnitMap) and Assigned(ASym.owner) then
             inc(CurrentModule.UnitMap[ASym.owner.ModuleID].refs);
          end;

        function PreProcFactor(AEvaluate: Boolean):TExprValue;
        var
           lText,lCountString,lStoredPattern,lFileExt: String;
           lMacro: TMacro;
           lSearchSym : TSym;
           lSearchSymTable : TSymTable;
           lDef : TDef;
           lValue : LongInt;
           lHasParen,
           lReadNext: Boolean;
           lExprValue:TExprValue;
           lSetValue:TNormalSet;
           lFileSpec,lPath,lName: TPathStr;
           lFoundFile: TCmdStr;
           lFound: Boolean;
        begin
          Result:=nil;
          lHasParen:=false;
           if CurrentScanner.FPreProcToken=_ID then
             begin
                if CurrentScanner.FPreProcPattern='FILEEXISTS' then
                  begin
                    PreProcConsume(_ID);
                    PreProcConsume(_LKLAMMER);
                    lText:=CurrentScanner.FPreProcPattern;
                    PreProcConsume(_CSTRING);
                    lFileSpec:=GetToken(lText,' ');
                    lFileSpec:=FixFileName(lFileSpec);
                    lPath:=ExtractFilePath(lFileSpec);
                    lName:=ExtractFileName(lFileSpec);

                    { this like 'include' }
                    if (length(lName)>=1) and
                       (lName[1]='*') then
                      lName:=ChangeFileExt(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex),'')+ExtractFileExt(lName);

                    { try to find the file, this like 'include' }
                    lFound:=FindIncludeFile(lPath,lName,lFoundFile);
                    lFileExt:=lower(ExtractFileExt(lName));
                    if (not lFound) and ((lFileExt<>'.inc') and (lFileExt<>SourceExt)) then
                     begin
                       { try default extensions .inc and .pas }
                       if (not lFound) then
                        lFound:=FindIncludeFile(lPath,lName+'.inc',lFoundFile);
                       if (not lFound) then
                        lFound:=FindIncludeFile(lPath,lName+SourceExt,lFoundFile);
                     end;
                    if (not lFound) and (ExtractFileExt(lName)=ExtensionSeparator) and (Length(lName)>=2) then
                      lFound:=FindIncludeFile(lPath,Copy(lName,1,Length(lName)-1),lFoundFile);

                    Result:=TExprValue.CreateBool(lFound);
                    CurrentScanner.SkipSpace;
                    PreProcConsume(_RKLAMMER);
                  end
                else
                if CurrentScanner.FPreProcPattern='DEFINED' then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                        lHasParen:= true;
                      end
                    else if (m_mac in CurrentSettings.ModeSwitches) then
                      lHasParen:= false
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if CurrentScanner.FPreProcToken =_ID then
                      begin
                        lText := CurrentScanner.FPreProcPattern;
                        lMacro := TMacro(Search_Macro(lText));
                        if Assigned(lMacro) and lMacro.defined then
                          begin
                            Result:=TExprValue.CreateBool(true);
                            lMacro.IsUsed:=true;
                          end
                        else
                          Result:=TExprValue.CreateBool(false);
                        PreProcConsume(_ID);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if lHasParen then
                      if CurrentScanner.FPreProcToken =_RKLAMMER then
                        PreProcConsume(_RKLAMMER)
                      else
                        Message(scan_e_error_in_preproc_expr);
                  end
                else
                if (m_mac in CurrentSettings.ModeSwitches) and (CurrentScanner.FPreProcPattern='UNDEFINED') then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_ID then
                      begin
                        lText := CurrentScanner.FPreProcPattern;
                        lMacro := TMacro(Search_Macro(lText));
                        { FPC_UNICODESTRINGS is always present in the initial
                          macro table, but is undefined in ANSI mode. }
                        if Assigned(lMacro) and
                           ((upper(lText)<>'FPC_UNICODESTRINGS') or lMacro.defined) then
                          begin
                            Result:=TExprValue.CreateBool(false);
                            lMacro.IsUsed:=true;
                          end
                        else
                          Result:=TExprValue.CreateBool(true);
                        PreProcConsume(_ID);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if (m_mac in CurrentSettings.ModeSwitches) and (CurrentScanner.FPreProcPattern='OPTION') then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if not (CurrentScanner.FPreProcToken = _ID) then
                      Message(scan_e_error_in_preproc_expr);

                    lText:=CurrentScanner.FPreProcPattern;
                    if (length(lText) > 1) then
                      {This is allowed in Metrowerks Pascal}
                      Message(scan_e_error_in_preproc_expr)
                    else
                      begin
                        if CheckSwitch(lText[1],'+') then
                          Result:=TExprValue.CreateBool(true)
                        else
                          Result:=TExprValue.CreateBool(false);
                      end;

                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_RKLAMMER then
                      PreProcConsume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.FPreProcPattern='SIZEOF' then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    lStoredPattern:=CurrentScanner.FPreProcPattern;
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;

                    if AEvaluate then
                      if SearchSym(lStoredPattern,lSearchSym,lSearchSymTable) then
                        begin
                          TryConsumeNestedSym(lSearchSym,lSearchSymTable);
                          lValue:=0;
                          if Assigned(lSearchSym) then
                            case lSearchSym.typ of
                              staticvarsym,
                              localvarsym,
                              paravarsym :
                                begin
                                  lValue:=TAbstractVarSym(lSearchSym).GetSize;
                                  MarkSymbolAsUsed(lSearchSym);
                                end;
                              TypeSym:
                                begin
                                  if TTypeSym(lSearchSym).TypeDef.typ in [errordef,abstractdef,ForwardDef] then
                                    Message(parser_e_illegal_expression);
                                  lValue:=TTypeSym(lSearchSym).TypeDef.Size;
                                  MarkSymbolAsUsed(lSearchSym);
                                end;
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                          Result:=TExprValue.CreateInt(lValue);
                        end
                      else
                        Message1(sym_e_id_not_found,lStoredPattern);

                    if CurrentScanner.FPreProcToken =_RKLAMMER then
                      PreProcConsume(_RKLAMMER)
                    else
                      Message(scan_e_preproc_syntax_error);
                  end
                else
                if CurrentScanner.FPreProcPattern='HIGH' then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    lStoredPattern:=CurrentScanner.FPreProcPattern;
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;

                    if AEvaluate then
                      if SearchSym(lStoredPattern,lSearchSym,lSearchSymTable) then
                        begin
                          TryConsumeNestedSym(lSearchSym,lSearchSymTable);
                          lDef:=nil;
                          lText:='';
                          lValue:=0;
                          if Assigned(lSearchSym) then
                            case lSearchSym.typ of
                              staticvarsym,
                              localvarsym,
                              paravarsym :
                                begin
                                  lDef:=TAbstractVarSym(lSearchSym).vardef;
                                  MarkSymbolAsUsed(lSearchSym);
                                end;
                              TypeSym:
                                begin
                                  lDef:=TTypeSym(lSearchSym).TypeDef;
                                  MarkSymbolAsUsed(lSearchSym);
                                end;
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                          if Assigned(lDef) then
                            begin
                              if lDef.typ=setdef then
                                lDef:=TSetDef(lDef).ElementDef;
                              case lDef.typ of
                                orddef:
                                  with TOrdDef(lDef).high do
                                    if signed then
                                      Result:=TExprValue.CreateInt(svalue)
                                    else
                                      Result:=TExprValue.CreateUInt(uvalue);
                                enumdef:
                                  Result:=TExprValue.CreateInt(TEnumDef(lDef).MaxVal);
                                arraydef:
                                  if Is_Open_Array(lDef) or Is_Array_Of_Const(lDef) or Is_Dynamic_Array(lDef) then
                                    Message(type_e_mismatch)
                                  else
                                    Result:=TExprValue.CreateInt(TArrayDef(lDef).HighRange);
                                stringdef:
                                  if Is_Open_String(lDef) or Is_AnsiString(lDef) or Is_Wide_Or_Unicode_String(lDef) then
                                    Message(type_e_mismatch)
                                  else
                                    Result:=TExprValue.CreateInt(TStringDef(lDef).len);
                                else
                                  Message(type_e_mismatch);
                              end;
                            end;
                        end
                      else
                        Message1(sym_e_id_not_found,lStoredPattern);

                    if CurrentScanner.FPreProcToken =_RKLAMMER then
                      PreProcConsume(_RKLAMMER)
                    else
                      Message(scan_e_preproc_syntax_error);
                  end
                else
                if CurrentScanner.FPreProcPattern='DECLARED' then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                    if CurrentScanner.FPreProcToken =_ID then
                      begin
                        lText := upper(CurrentScanner.FPreProcPattern);
                        PreProcConsume(_ID);
                        CurrentScanner.SkipSpace;
                        if CurrentScanner.FPreProcToken in [_LT,_LSHARPBRACKET] then
                          begin
                            lValue:=1;
                            PreProcConsume(CurrentScanner.FPreProcToken);
                            CurrentScanner.SkipSpace;
                            while CurrentScanner.FPreProcToken=_COMMA do
                              begin
                                inc(lValue);
                                PreProcConsume(_COMMA);
                                CurrentScanner.SkipSpace;
                              end;
                            if not (CurrentScanner.FPreProcToken in [_GT,_RSHARPBRACKET]) then
                              Message(scan_e_error_in_preproc_expr)
                            else
                              PreProcConsume(CurrentScanner.FPreProcToken);
                            str(lValue,lCountString);
                            lText:=lText+'$'+lCountString;
                          end
                        else
                          { special case: <> }
                          if CurrentScanner.FPreProcToken=_NE then
                            begin
                              lText:=lText+'$1';
                              PreProcConsume(_NE);
                            end;
                        CurrentScanner.SkipSpace;
                        if SearchSym(lText,lSearchSym,lSearchSymTable) then
                          begin
                            { TSomeGeneric<...> also adds a TSomeGeneric symbol }
                            if (sp_generic_dummy in lSearchSym.SymOptions) and
                                (lSearchSym.typ=TypeSym) and
                                (
                                  { mode delphi}
                                  (TTypeSym(lSearchSym).TypeDef.typ in [undefineddef,errordef]) or
                                  { non-delphi modes }
                                  (df_generic in TTypeSym(lSearchSym).TypeDef.DefOptions)
                                ) then
                              Result:=TExprValue.CreateBool(false)
                            else
                              Result:=TExprValue.CreateBool(true);
                            MarkSymbolAsUsed(lSearchSym);
                          end
                        else
                          Result:=TExprValue.CreateBool(false);
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                    if CurrentScanner.FPreProcToken =_RKLAMMER then
                      PreProcConsume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.FPreProcPattern='ORD' then
                  begin
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    if CurrentScanner.FPreProcToken =_LKLAMMER then
                      begin
                        PreProcConsume(_LKLAMMER);
                        CurrentScanner.SkipSpace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    lExprValue:=PreProcFactor(AEvaluate);
                    if AEvaluate then
                      begin
                        if Is_Ordinal(lExprValue.FDef) then
                          Result:=TExprValue.CreateInt(lExprValue.AsInt)
                        else
                          begin
                            lExprValue.Error('Ordinal','ORD');
                            Result:=TExprValue.CreateInt(0);
                          end;
                      end
                    else
                      Result:=TExprValue.CreateInt(0);
                    lExprValue.free;
                    lExprValue := nil;
                    if CurrentScanner.FPreProcToken =_RKLAMMER then
                      PreProcConsume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.FPreProcPattern='NOT' then
                  begin
                    PreProcConsume(_ID);
                    lExprValue:=PreProcFactor(AEvaluate);
                    if AEvaluate then
                      Result:=lExprValue.Evaluate(nil,_OP_NOT)
                    else
                      Result:=TExprValue.CreateBool(false); {Just to have something}
                    lExprValue.free;
                    lExprValue := nil;
                  end
                else
                if (CurrentScanner.FPreProcPattern='TRUE') then
                  begin
                    Result:=TExprValue.CreateBool(true);
                    PreProcConsume(_ID);
                  end
                else
                if (CurrentScanner.FPreProcPattern='FALSE') then
                  begin
                    Result:=TExprValue.CreateBool(false);
                    PreProcConsume(_ID);
                  end
                else
                  begin
                    lStoredPattern:=CurrentScanner.FPreProcPattern;
                    PreProcConsume(_ID);
                    CurrentScanner.SkipSpace;
                    { first look for a macros/int/float }
                    Result:=PreProcSubstitutedToken(lStoredPattern,AEvaluate);
                    if AEvaluate and (Result.FConstTyp=conststring) then
                      begin
                        if SearchSym(lStoredPattern,lSearchSym,lSearchSymTable) then
                          begin
                            TryConsumeNestedSym(lSearchSym,lSearchSymTable);
                            if Assigned(lSearchSym) then
                              begin
                                MarkSymbolAsUsed(lSearchSym);
                                case lSearchSym.typ of
                                  constsym:
                                    begin
                                      { const def must conform to the set type }
                                      if (AConformTo<>nil) and
                                        (AConformTo.typ=setdef) and
                                        (TConstSym(lSearchSym).ConstDef.typ=setdef) and
                                        (Compare_Defs(TSetDef(TConstSym(lSearchSym).ConstDef).ElementDef,TSetDef(AConformTo).ElementDef,nothingn)<>te_exact) then
                                          begin
                                            Result.free;
                                            Result:=nil;
                                            // TODO(ryan): better error?
                                            Message(scan_e_error_in_preproc_expr);
                                          end;
                                      if Result<>nil then
                                        begin
                                          Result.free;
                                          Result:=TExprValue.CreateConst(TConstSym(lSearchSym));
                                        end;
                                    end;
                                  enumsym:
                                    begin
                                      { enum definition must conform to the set type }
                                      if (AConformTo<>nil) and
                                        (AConformTo.typ=setdef) and
                                        (Compare_Defs(TEnumSym(lSearchSym).definition,TSetDef(AConformTo).ElementDef,nothingn)<>te_exact) then
                                          begin
                                            Result.free;
                                            Result:=nil;
                                            // TODO(ryan): better error?
                                            Message(scan_e_error_in_preproc_expr);
                                          end;
                                      if Result<>nil then
                                        begin
                                          Result.free;
                                          Result:=TExprValue.CreateInt(TEnumSym(lSearchSym).Value);
                                        end;
                                    end;
                                  else
                                    ;
                                end;
                              end;
                          end
                        { the id must be belong to the set type }
                        else if (AConformTo<>nil) and (AConformTo.typ=setdef) then
                          begin
                            Result.free;
                            Result:=nil;
                            // TODO(ryan): better error?
                            Message(scan_e_error_in_preproc_expr);
                          end;
                      end
                      { skip id(<expr>) if expression must not be evaluated }
                      else if not(AEvaluate) and (Result.FConstTyp=conststring) then
                        begin
                          if CurrentScanner.FPreProcToken =_LKLAMMER then
                            begin
                              PreProcConsume(_LKLAMMER);
                              CurrentScanner.SkipSpace;

                              Result:=PreProcFactor(false);
                              if CurrentScanner.FPreProcToken =_RKLAMMER then
                                PreProcConsume(_RKLAMMER)
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                        end;
                  end
             end
           else if CurrentScanner.FPreProcToken =_LKLAMMER then
             begin
                PreProcConsume(_LKLAMMER);
                Result:=PreProcSubExpr(opcompare,AEvaluate);
                PreProcConsume(_RKLAMMER);
             end
           else if CurrentScanner.FPreProcToken = _LECKKLAMMER then
             begin
               PreProcConsume(_LECKKLAMMER);
               lSetValue:=[];
               lReadNext:=false;
               while (CurrentScanner.FPreProcToken in [_ID,_INTCONST]) or lReadNext do
               begin
                 lReadNext:=false;
                 lExprValue:=PreProcFactor(AEvaluate);
                 { the const set does not conform to the set def }
                 if (AConformTo<>nil) and
                   (AConformTo.typ=setdef) and
                   (lExprValue.FConstTyp=constnone) then
                   begin
                     Result:=TExprValue.CreateError;
                     break;
                   end;
                 { reject duplicate enums in the set }
                 if lExprValue.AsInt in lSetValue then
                   begin
                     Message1(sym_e_duplicate_id,CurrentScanner.FPreProcPattern);
                     Result:=TExprValue.CreateError;
                     break;
                   end;
                 include(lSetValue,lExprValue.AsInt);
                 if CurrentScanner.FPreProcToken = _COMMA then
                   begin
                     PreProcConsume(_COMMA);
                     lReadNext:=true;
                   end
               end;
               PreProcConsume(_RECKKLAMMER);
               if Result=nil then
                 Result:=TExprValue.CreateSet(lSetValue);
             end
           else if CurrentScanner.FPreProcToken = _INTCONST then
             begin
               Result:=TExprValue.TryParseNumber(CurrentScanner.FPreProcPattern);
               if not Assigned(Result) then
                 begin
                   Message(parser_e_invalid_integer);
                   Result:=TExprValue.CreateInt(1);
                 end;
               PreProcConsume(_INTCONST);
             end
           else if CurrentScanner.FPreProcToken = _CSTRING then
             begin
               Result:=TExprValue.CreateStr(CurrentScanner.FPreProcPattern);
               PreProcConsume(_CSTRING);
             end
           else if CurrentScanner.FPreProcToken = _REALNUMBER then
             begin
               Result:=TExprValue.TryParseReal(CurrentScanner.FPreProcPattern);
               if not Assigned(Result) then
                 begin
                   Message(parser_e_error_in_real);
                   Result:=TExprValue.CreateReal(1.0);
                 end;
               PreProcConsume(_REALNUMBER);
             end
           else if CurrentScanner.FPreProcToken = _MINUS then
             begin
               PreProcConsume(_MINUS);
               lExprValue:=PreProcFactor(AEvaluate);
               if AEvaluate then
                 Result:=lExprValue.Evaluate(nil,_MINUS)
               else if lExprValue.IsInt then
                 Result:=TExprValue.CreateInt(-lExprValue.AsInt)
               else if Is_FPU(lExprValue.FDef) then
                 Result:=TExprValue.CreateReal(-PBestReal(lExprValue.FValue.ValuePtr)^)
               else
                 Message(scan_e_error_in_preproc_expr);
               lExprValue.free;
               lExprValue := nil;
             end
           else
             Message(scan_e_error_in_preproc_expr);
           if not Assigned(Result) then
             Result:=TExprValue.CreateError;
        end;

        function PreProcSubExpr(APrecedence:TOperatorPrecedence;AEvaluate:Boolean): TExprValue;
        var
          lLeftValue,lRightValue: TExprValue;
          lOperator: TToken;
        begin
           if APrecedence=highest_precedence then
             Result:=PreProcFactor(AEvaluate)
           else
             Result:=PreProcSubExpr(succ(APrecedence),AEvaluate);
          repeat
            lOperator:=CurrentScanner.FPreProcToken;
            if (lOperator in cPreProcOperators) and
               (lOperator in operator_levels[APrecedence]) then
             begin
               lLeftValue:=Result;
               PreProcConsume(lOperator);
               if (lOperator=_OP_OR) and lLeftValue.IsBoolean and lLeftValue.AsBool then
                 begin
                   { stop evaluation the rest of expression }
                   Result:=TExprValue.CreateBool(true);
                   if APrecedence=highest_precedence then
                     lRightValue:=PreProcFactor(false)
                   else
                     lRightValue:=PreProcSubExpr(succ(APrecedence),false);
                 end
               else if (lOperator=_OP_AND) and lLeftValue.IsBoolean and not lLeftValue.AsBool then
                 begin
                   { stop evaluation the rest of expression }
                   Result:=TExprValue.CreateBool(false);
                   if APrecedence=highest_precedence then
                     lRightValue:=PreProcFactor(false)
                   else
                     lRightValue:=PreProcSubExpr(succ(APrecedence),false);
                 end
               else
                 begin
                   if APrecedence=highest_precedence then
                     lRightValue:=PreProcFactor(AEvaluate)
                   else
                     lRightValue:=PreProcSubExpr(succ(APrecedence),AEvaluate);
                   if AEvaluate then
                     Result:=lLeftValue.Evaluate(lRightValue,lOperator)
                   else
                     Result:=TExprValue.CreateBool(false); {Just to have something}
                 end;
               lLeftValue.free;
               lLeftValue := nil;
               lRightValue.free;
               lRightValue := nil;
             end
           else
             break;
          until false;
        end;

     begin
       CurrentScanner.FInPreProcCompExpr:=true;
       CurrentScanner.SkipSpace;
       { start preproc expression scanner }
       CurrentScanner.FPreProcToken:=CurrentScanner.ReadPreProc;
       PreProcCompExpr:=PreProcSubExpr(opcompare,true);
       CurrentScanner.FInPreProcCompExpr:=false;
     end;

    function BooleanCompileTimeExpr(var AValueDescr: String): Boolean;
      var
        lExprValue: TExprValue;
      begin
        lExprValue:=PreProcCompExpr(nil);
        if lExprValue.IsBoolean then
          Result:=lExprValue.AsBool
        else
          begin
            lExprValue.Error('Boolean', 'IF or ELSEIF');
            Result:=false;
          end;
        AValueDescr:=lExprValue.AsStr;
        lExprValue.free;
        lExprValue := nil;
      end;

    procedure DirIf;
      begin
        CurrentScanner.IfPreProcStack(ppIf,@BooleanCompileTimeExpr, scan_c_if_found);
      end;

    procedure DirElseIf;
      begin
        CurrentScanner.ElseIfPreProcStack(@BooleanCompileTimeExpr);
      end;

    procedure DirDefineImpl(AMacStyle: Boolean);
      var
        lText  : String;
        lBracketCount : LongInt;
        lMacro : TMacro;
        lMacroPos : SizeInt;
        lMacroBuffer : array[0..MaxMacroLen-1] of Char;
      begin
        CurrentScanner.SkipSpace;
        lText:=CurrentScanner.ReadID;
        if lText='' then
          begin
            Message(scan_e_emptymacroname);
            exit;
          end;
        if upper(lText)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'DEFINE '+lText+' (selected by compiler string mode)');
            exit;
          end;
        lMacro:=TMacro(Search_Macro(lText));
        if not Assigned(lMacro) or (lMacro.owner <> CurrentModule.LocalMacroSymTable) then
          begin
            lMacro:=TMacro.Create(lText);
            lMacro.defined:=true;
            CurrentModule.LocalMacroSymTable.InsertSym(lMacro);
          end
        else
          begin
            lMacro.defined:=true;
            lMacro.IsCompilerVar:=false;
          { delete old definition }
            lMacro.Free_BufText;
          end;
        Message1(parser_c_macro_defined,lMacro.name);
        lMacro.IsUsed:=true;
        if (cs_support_macro in CurrentSettings.ModuleSwitches) then
          begin
             CurrentScanner.SkipSpace;

             if not AMacStyle then
               begin
                 { may be a macro? }
                 if CurrentScanner.FChar <> ':' then
                   exit;
                 CurrentScanner.ReadChar;
                 if CurrentScanner.FChar <> '=' then
                   exit;
                 lMacro.IsCMacro:=true;
                 CurrentScanner.ReadChar;
                 CurrentScanner.SkipSpace;
               end
             else
               { $definec always defines a text-substitution (C-style) macro }
               lMacro.IsCMacro:=true;

             { key words are never substituted }
             if IsKeyword(lText) then
               Message(scan_e_keyword_cant_be_a_macro);

             CurrentScanner.GetTokenPos;
             lMacro.fileinfo:=CurrentTokenPos;

             lMacroPos:=0;
             { parse macro, brackets are counted so it's possible
               to have a $ifdef etc. in the macro }
             lBracketCount:=0;
             repeat
               case CurrentScanner.FChar of
                 '}' :
                   if (lBracketCount=0) then
                    break
                   else
                    dec(lBracketCount);
                 '{' :
                   inc(lBracketCount);
                 #10,#13 :
                   CurrentScanner.LineBreak;
                 #26 :
                   CurrentScanner.HandleEndOfFile;
               end;
               if lMacroPos>=MaxMacroLen then
                 Message(scan_f_macro_buffer_overflow);
               lMacroBuffer[lMacroPos]:=CurrentScanner.FChar;
               inc(lMacroPos);
               CurrentScanner.ReadChar;
             until false;

             { copy the text }
             if lMacroPos>0 then
               move(pchar(@lMacroBuffer[0])^,lMacro.Allocate_BufText(lMacroPos)^,lMacroPos);
          end
        else
          begin
           { check if there is an assignment, then we need to give a
             warning }
             CurrentScanner.SkipSpace;
             if CurrentScanner.FChar=':' then
              begin
                CurrentScanner.ReadChar;
                if CurrentScanner.FChar='=' then
                  Message(scan_w_macro_support_turned_off);
              end;
          end;
      end;

    procedure DirDefine;
      begin
        DirDefineImpl(false);
      end;

    procedure DirDefineC;
      begin
        DirDefineImpl(true);
      end;

    procedure DirSetC;
      var
        lText  : String;
        lMacro : TMacro;
        lExprValue: TExprValue;
      begin
        CurrentScanner.SkipSpace;
        lText:=CurrentScanner.ReadID;
        if upper(lText)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'SETC '+lText+' (selected by compiler string mode)');
            exit;
          end;
        lMacro:=TMacro(Search_Macro(lText));
        if not Assigned(lMacro) or
           (lMacro.owner <> CurrentModule.LocalMacroSymTable) then
          begin
            lMacro:=TMacro.Create(lText);
            lMacro.defined:=true;
            lMacro.IsCompilerVar:=true;
            CurrentModule.LocalMacroSymTable.InsertSym(lMacro);
          end
        else
          begin
            lMacro.defined:=true;
            lMacro.IsCompilerVar:=true;
          { delete old definition }
            lMacro.Free_BufText;
          end;
        Message1(parser_c_macro_defined,lMacro.name);
        lMacro.IsUsed:=true;

        { key words are never substituted }
        if IsKeyword(lText) then
          Message(scan_e_keyword_cant_be_a_macro);

        { macro assignment can be both := and = }
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar=':' then
          CurrentScanner.ReadChar;
        if CurrentScanner.FChar='=' then
          begin
             CurrentScanner.ReadChar;
             lExprValue:=PreProcCompExpr(nil);
             if not Is_Boolean(lExprValue.FDef) and
                not Is_Integer(lExprValue.FDef) then
               lExprValue.Error('Boolean, Integer', 'SETC');
             lText:=lExprValue.AsStr;

             if length(lText) <> 0 then
               begin
                 {If we are absolutely sure it is boolean, translate
                  to TRUE/FALSE to increase possibility to do future type check}
                 if lExprValue.IsBoolean then
                   begin
                     if lExprValue.AsBool then
                       lText:='TRUE'
                     else
                       lText:='FALSE';
                   end;
                 Message2(parser_c_macro_set_to,lMacro.name,lText);
                 { copy the text }
                 move(lText[1],lMacro.Allocate_BufText(length(lText))^,length(lText));
               end
             else
               Message(scan_e_preproc_syntax_error);
             lExprValue.free;
             lExprValue := nil;
          end
        else
          Message(scan_e_preproc_syntax_error);
      end;


    procedure DirUndef;
      var
        lText  : String;
        lMacro : TMacro;
      begin
        CurrentScanner.SkipSpace;
        lText:=CurrentScanner.ReadID;
        if upper(lText)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'UNDEF '+lText+' (selected by compiler string mode)');
            exit;
          end;
        lMacro:=TMacro(Search_Macro(lText));
        if not Assigned(lMacro) or
           (lMacro.owner <> CurrentModule.LocalMacroSymTable) then
          begin
             lMacro:=TMacro.Create(lText);
             lMacro.defined:=false;
             CurrentModule.LocalMacroSymTable.InsertSym(lMacro);
          end
        else
          begin
             lMacro.defined:=false;
             lMacro.IsCompilerVar:=false;
             lMacro.IsCMacro:=false;
             { delete old definition }
             lMacro.Free_BufText;
          end;
        Message1(parser_c_macro_undefined,lMacro.name);
        lMacro.IsUsed:=true;
      end;


    procedure DirInclude;
      var
        lFoundFile : TCmdStr;
        lPath,
        lName,
        lText    : TPathStr;
        lArgs  : String;
        lInputFile    : TInputFile;
        lFound : Boolean;
        lMacroIsString : Boolean;
        lFileExt: String;
      begin
        CurrentScanner.SkipSpace;
        lArgs:=CurrentScanner.ReadComment;
        lText:=GetToken(lArgs,' ');
        if lText='' then
         exit;
        if (lText[1]='%') then
         begin
         { case insensitive }
           lText:=upper(lText);
         { remove %'s }
           Delete(lText,1,1);
           if lText[length(lText)]='%' then
            Delete(lText,length(lText),1);
         { save old }
           lPath:=lText;
         { first check for internal macros }
           lMacroIsString:=true;
           case lText of
             'TIME':
               if TimeStr<>'' then
                 lText:=TimeStr
               else
                 lText:=GetTimeStr;
             'DATE':
               if DateStr<>'' then
                 lText:=DateStr
               else
                 lText:=GetDateStr;
             'DATEYEAR':
               begin
                 lText:=ToStr(StartSysTime.Year);
                 lMacroIsString:=false;
               end;
             'DATEMONTH':
               begin
                 lText:=ToStr(StartSysTime.Month);
                 lMacroIsString:=false;
               end;
             'DATEDAY':
               begin
                 lText:=ToStr(StartSysTime.Day);
                 lMacroIsString:=false;
               end;
             'TIMEHOUR':
               begin
                 lText:=ToStr(StartSysTime.Hour);
                 lMacroIsString:=false;
               end;
             'TIMEMINUTE':
               begin
                 lText:=ToStr(StartSysTime.Minute);
                 lMacroIsString:=false;
               end;
             'TIMESECOND':
               begin
                 lText:=ToStr(StartSysTime.Second);
                 lMacroIsString:=false;
               end;
             'FILE':
               lText:=CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex);
             'LINE':
               lText:=ToStr(CurrentFilePos.line);
             'LINENUM':
               begin
                 lText:=ToStr(CurrentFilePos.line);
                 lMacroIsString:=false;
               end;
             'FPCVERSION':
               lText:=Version_String;
             'FPCDATE':
               lText:=DateString;
             'FPCTARGET':
               lText:=TargetCPUString;
             'FPCTARGETCPU':
               lText:=TargetCPUString;
             'FPCTARGETOS':
               lText:=TargetInfo.shortname;
             'CURRENTROUTINE':
               lText:=CurrentProcInfo.procdef.ProcSym.RealName;
             else
               lText:=GetEnvironmentVariable(lText);
           end;
           if lText='' then
            Message1(scan_w_include_env_not_found,lPath);
           { make it a stringconst }
           if lMacroIsString then
             lText:=''''+lText+'''';
           CurrentScanner.SubstituteMacro(lPath,@lText[1],length(lText),
             CurrentScanner.FLineNumber,CurrentScanner.FInputFile.RefIndex,false);
         end
        else
         begin
           lText:=FixFileName(lText);
           lPath:=ExtractFilePath(lText);
           lName:=ExtractFileName(lText);
           { Special case for Delphi compatibility: '*' has to be replaced
             by the file name of the current source file.  }
           if (length(lName)>=1) and
              (lName[1]='*') then
             lName:=ChangeFileExt(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex),'')+ExtractFileExt(lName);

           { try to find the file }
           lFound:=FindIncludeFile(lPath,lName,lFoundFile);
           lFileExt:=lower(ExtractFileExt(lName));
           if (not lFound) and ((lFileExt<>'.inc') and (lFileExt<>SourceExt)) then
            begin
              { try default extensions .inc and .pas }
              if (not lFound) then
               lFound:=FindIncludeFile(lPath,lName+'.inc',lFoundFile);
              if (not lFound) then
               lFound:=FindIncludeFile(lPath,lName+SourceExt,lFoundFile);
            end;
           { if the name ends in dot, try without the dot }
           if (not lFound) and (ExtractFileExt(lName)=ExtensionSeparator) and (Length(lName)>=2) then
             lFound:=FindIncludeFile(lPath,Copy(lName,1,Length(lName)-1),lFoundFile);
           if CurrentScanner.FInputFileCount<cMaxIncludeNesting then
             begin
               inc(CurrentScanner.FInputFileCount);
               { we need to reread the current char }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
               CurrentScanner.DecInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
               dec(CurrentScanner.FInputPointer);
{$endif  CHECK_INPUTPOINTER_LIMITS}
               { reset c }
               CurrentScanner.FChar:=#0;
               { shutdown current file }
               CurrentScanner.TempCloseInputFile;
               { load new file }
               lInputFile:=Do_OpenInputFile(lFoundFile);
               lInputFile.IncPath:=lPath;
               CurrentScanner.AddFile(lInputFile);
               CurrentModule.SourceFiles.Register_File(lInputFile);
               if (not lFound) then
                Message1(scan_f_cannot_open_includefile,lText);
              if (not CurrentScanner.OpenInputFile) then
                Message1(scan_f_cannot_open_includefile,lText);
               Message1(scan_t_start_include_file,CurrentScanner.FInputFile.path+CurrentScanner.FInputFile.name);
               CurrentScanner.Reload;
             end
           else
             Message(scan_f_include_deep_ten);
         end;
      end;

{*****************************************************************************
                              TPreProcStack
*****************************************************************************}

    constructor TPreProcStack.Create(AType : TPreProcType;AAccept:Boolean;ANext:TPreProcStack);
      begin
        FAccept:=AAccept;
        FType:=AType;
        FNext:=ANext;
      end;

{*****************************************************************************
                              TReplayStack
*****************************************************************************}
    constructor TReplayStack.Create(AToken:TToken;AIDToken:TToken;
      const AOrgPattern,APattern:ShortString;const ACStringPattern:AnsiString;
      APatternW:TCompilerWideString;ASettings:TSettings;
      ATokenBuf:TDynamicArray;const APending:TPendingState;
      AVerbosity:LongInt;ANext:TReplayStack);
      begin
        FToken:=AToken;
        FIDToken:=AIDToken;
        FOrgPattern:=AOrgPattern;
        FPattern:=APattern;
        FCStringPattern:=ACStringPattern;
        InitWideString(FPatternW);
        if Assigned(APatternW) then
          begin
            CopyWideString(FPatternW,APatternW);
          end;
        FSettings:=ASettings;
        FPending:=APending;
        FVerbosity:=AVerbosity;
        FTokenBuf:=ATokenBuf;
        FNext:=ANext;
      end;


    destructor TReplayStack.Destroy;
      begin
        DoneWideString(FPatternW);
      end;

{*****************************************************************************
                              TDirectiveItem
*****************************************************************************}

    constructor TDirectiveItem.Create(AList:TFPHashObjectList;const AName:String;AProc:TDirectiveProc);
      begin
        inherited Create(AList,AName);
        FIsConditional:=false;
        FProc:=AProc;
      end;


    constructor TDirectiveItem.CreateCond(AList:TFPHashObjectList;const AName:String;AProc:TDirectiveProc);
      begin
        inherited Create(AList,AName);
        FIsConditional:=true;
        FProc:=AProc;
      end;

{****************************************************************************
                                TSCANNERFILE
 ****************************************************************************}

    constructor TScannerFile.Create(const AFileName: String; AIsMacro: Boolean);
      begin
        FInputFile:=Do_OpenInputFile(AFileName);
        if AIsMacro then
          FInputFile.IsMacro:=true;
        if Assigned(CurrentModule) then
          CurrentModule.SourceFiles.Register_File(FInputFile);
      { reset localinput }
        FChar:=#0;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FHiddenInputBuffer:=nil;
        FHiddenInputPointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputBuffer:=nil;
        FInputPointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputStart:=0;
      { reset scanner }
        FPreProcStack:=nil;
        FReplayStack:=nil;
        FCommentLevel:=0;
        FYYLexCount:=0;
        Block_Type:=bt_general;
        FLineNumber:=0;
        FLastLinePos:=0;
        FLastTokenPos:=0;
        FNextTokenPos:=0;
        FLastToken:=NOTOKEN;
        FNextToken:=NOTOKEN;
        FIgnoreDirectives:=TFPHashList.Create;
        InitWideString(FPatternW);
      end;


    procedure TScannerFile.FirstFile;
      begin
      { load block }
        if not OpenInputFile then
          Message1(scan_f_cannot_open_input,FInputFile.name);
        Reload;
      end;


    destructor TScannerFile.Destroy;
      begin
        if Assigned(OnFreeScanner) then
          OnFreeScanner(Self);
        if Assigned(CurrentModule) and
           (CurrentModule.state in [ms_processed,ms_compiled]) and
           (status.ErrorCount=0) then
          CheckPreProcStack
        else
          begin
            while Assigned(FPreProcStack) do
             PopPreProcStack;
          end;
        while Assigned(FReplayStack) do
          PopReplayStack;
        if not FInputFile.closed then
          CloseInputFile;
        if FInputFile.IsMacro then
          begin
            FInputFile.free;
            FInputFile := nil;
          end;
        FIgnoreDirectives.free;
        FIgnoreDirectives := nil;
        DoneWideString(FPatternW);
      end;


    function TScannerFile.OpenInputFile:Boolean;
      begin
        OpenInputFile:=FInputFile.open;
      { load buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FHiddenInputBuffer:=PAnsiChar(FInputFile.buf);
        FHiddenInputPointer:=PAnsiChar(FInputFile.buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputBuffer:=PAnsiChar(FInputFile.buf);
        FInputPointer:=PAnsiChar(FInputFile.buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputStart:=FInputFile.BufStart;
      { line }
        FLineNumber:=0;
        FLastLinePos:=0;
        FLastTokenPos:=0;
        FNextTokenPos:=0;
      end;


    procedure TScannerFile.CloseInputFile;
      begin
        FInputFile.close;
      { reset buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FHiddenInputBuffer:=nil;
        FHiddenInputPointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputBuffer:=nil;
        FInputPointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputStart:=0;
      { reset line }
        FLineNumber:=0;
        FLastLinePos:=0;
        FLastTokenPos:=0;
        FNextTokenPos:=0;
      end;


    function TScannerFile.TempOpenInputFile:Boolean;
      begin
        TempOpenInputFile:=false;
        if FInputFile.IsMacro then
          exit;
        TempOpenInputFile:=FInputFile.TempOpen;
      { reload buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FHiddenInputBuffer:=PAnsiChar(FInputFile.buf);
        FHiddenInputPointer:=PAnsiChar(FInputFile.buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputBuffer:=PAnsiChar(FInputFile.buf);
        FInputPointer:=PAnsiChar(FInputFile.buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputStart:=FInputFile.BufStart;
      end;


    procedure TScannerFile.TempCloseInputFile;
      begin
        if FInputFile.closed or FInputFile.IsMacro then
         exit;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FInputFile.setpos(FInputStart+(FHiddenInputPointer-FHiddenInputBuffer));
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputFile.setpos(FInputStart+(FInputPointer-FInputBuffer));
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputFile.TempClose;
      { reset buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FHiddenInputBuffer:=nil;
        FHiddenInputPointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputBuffer:=nil;
        FInputPointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputStart:=0;
      end;


    procedure TScannerFile.SaveInputFile;
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FInputFile.SaveInputPointer:=FHiddenInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FInputFile.SaveInputPointer:=FInputPointer;
{$endif CHECK_INPUTPOINTER_LIMITS}
        FInputFile.SaveLastLinePos:=FLastLinePos;
        FInputFile.SaveLineNo:=FLineNumber;
      end;


    procedure TScannerFile.RestoreInputFile;
      begin
{$ifdef check_inputpointer_limits}
        FHiddenInputBuffer:=PAnsiChar(FInputFile.buf);
        FHiddenInputPointer:=FInputFile.SaveInputPointer;
{$else not check_inputpointer_limits}
        FInputBuffer:=PAnsiChar(FInputFile.buf);
        FInputPointer:=FInputFile.SaveInputPointer;
{$endif check_inputpointer_limits}
        FLastLinePos:=FInputFile.SaveLastLinePos;
        FLineNumber:=FInputFile.SaveLineNo;
        if not FInputFile.IsMacro then
          Parser_Current_File:=FInputFile.name;
      end;


    procedure TScannerFile.NextFile;
      var
        lToDispose : TInputFile;
      begin
        if Assigned(FInputFile.next) then
         begin
           if FInputFile.IsMacro then
             begin
               lToDispose:=FInputFile;
               dec(FMacroNestingDepth);
             end
           else
             begin
               lToDispose:=nil;
               dec(FInputFileCount);
             end;
           { we can always close the file, no ? }
           FInputFile.close;
           FInputFile:=FInputFile.next;
           if Assigned(lToDispose) then
             lToDispose.free; // no nil needed
           RestoreInputFile;
         end;
      end;


{$ifdef CHECK_INPUTPOINTER_LIMITS}
    function TScannerFile.GetInputPointerChar(AOffset : LongInt = 0) : Char;
      begin
	assert(FHiddenInputPointer-FHiddenInputBuffer+AOffset<=FInputFile.BufSize);
	GetInputPointerChar:=(FHiddenInputPointer+AOffset)^;
      end;

    procedure TScannerFile.IncInputPointer(AAmount : LongInt = 1);
      begin
        assert(FHiddenInputPointer-FHiddenInputBuffer+AAmount<=FInputFile.BufSize);
        inc(FHiddenInputPointer,AAmount);
      end;

    procedure TScannerFile.DecInputPointer;
      begin
        assert(FHiddenInputPointer>FHiddenInputBuffer);
        dec(FHiddenInputPointer);
      end;
{$endif}

    procedure TScannerFile.StartRecordTokens(ABuffer:TDynamicArray);
      begin
        if not Assigned(ABuffer) then
          InternalError(200511172);
        if Assigned(FRecordTokenBuf) then
          InternalError(200511173);
        FRecordTokenBuf:=ABuffer;
        fillchar(FLastSettings,sizeof(FLastSettings),0);
        FLastMessage:=nil;
        fillchar(FLastFilePos,sizeof(FLastFilePos),0);
      end;


    procedure TScannerFile.StopRecordTokens;
      begin
        if not Assigned(FRecordTokenBuf) then
          InternalError(200511174);
        FRecordTokenBuf:=nil;
      end;

    function TScannerFile.IsRecordingTokens: Boolean;
      begin
        Result:=Assigned(FRecordTokenBuf);
      end;


    procedure TScannerFile.WriteToken(AToken : TToken);
      var
        lByte : Byte;
      begin
        if ord(AToken)>$7f then
          begin
            lByte:=(ord(AToken) shr 8) or $80;
            FRecordTokenBuf.write(lByte,1);
          end;
        lByte:=ord(AToken) and $ff;
        FRecordTokenBuf.write(lByte,1);
      end;

    procedure TScannerFile.TokenWriteSizeInt(AValue : asizeint);
      begin
        FRecordTokenBuf.write(AValue,sizeof(asizeint));
      end;

    procedure TScannerFile.TokenWriteLongInt(AValue : LongInt);
      begin
        FRecordTokenBuf.write(AValue,sizeof(LongInt));
      end;

    procedure TScannerFile.TokenWriteShortInt(AValue : ShortInt);
      begin
        FRecordTokenBuf.write(AValue,sizeof(ShortInt));
      end;

    procedure TScannerFile.TokenWriteByte(AValue : Byte);
      begin
        FRecordTokenBuf.write(AValue,sizeof(Byte));
      end;

    procedure TScannerFile.TokenWriteWord(AValue : Word);
      begin
        FRecordTokenBuf.write(AValue,sizeof(Word));
      end;

    procedure TScannerFile.TokenWriteLongWord(AValue : LongWord);
      begin
        FRecordTokenBuf.write(AValue,sizeof(LongWord));
      end;

    function TScannerFile.TokenReadSizeInt : asizeint;
      var
        lValue : asizeint;
      begin
        FReplayTokenBuf.read(lValue,sizeof(asizeint));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadLongWord : LongWord;
      var
        lValue : LongWord;
      begin
        FReplayTokenBuf.read(lValue,sizeof(LongWord));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadLongInt : LongInt;
      var
        lValue : LongInt;
      begin
        FReplayTokenBuf.read(lValue,sizeof(LongInt));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadShortInt : ShortInt;
      var
        lValue : ShortInt;
      begin
        FReplayTokenBuf.read(lValue,sizeof(ShortInt));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadByte : Byte;
      var
        lValue : Byte;
      begin
        FReplayTokenBuf.read(lValue,sizeof(Byte));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadSmallInt : SmallInt;
      var
        lValue : SmallInt;
      begin
        FReplayTokenBuf.read(lValue,sizeof(SmallInt));
        Result:=lValue;
      end;

    function TScannerFile.TokenReadWord : Word;
      var
        lValue : Word;
      begin
        FReplayTokenBuf.read(lValue,sizeof(Word));
        Result:=lValue;
      end;

   function TScannerFile.TokenReadEnum(ASize : LongInt) : LongWord;
   begin
     if ASize=1 then
       Result:=TokenReadByte
     else if ASize=2 then
       Result:=TokenReadWord
     else if ASize=4 then
       Result:=TokenReadLongWord
     else
       InternalError(2013112901);
   end;

   procedure TScannerFile.TokenReadSet(var AValue;ASize : LongInt);
   begin
     FReplayTokenBuf.read(AValue,ASize);
   end;

   procedure TScannerFile.TokenWriteEnum(var AValue;ASize : LongInt);
   begin
     FRecordTokenBuf.write(AValue,ASize);
   end;

   procedure TScannerFile.TokenWriteSet(var AValue;ASize : LongInt);
   begin
     FRecordTokenBuf.write(AValue,ASize);
   end;


    procedure TScannerFile.TokenReadSettings(var ASettings : TSettings; AExpectedSize : asizeint);

    {    This procedure
       needs to be changed whenever
       globals.tsettings type is changed,
       the problem is that no error will appear
       before tests with generics are tested. PM }

       var
         lStartPos, lEndPos : LongWord;
      begin
        { Keep this field order matched with tokenwritesettings. }
        lStartPos:=FReplayTokenBuf.pos;
        with ASettings do
          begin
            alignment.ProcAlign:=TokenReadLongInt;
            alignment.LoopAlign:=TokenReadLongInt;
            alignment.JumpAlign:=TokenReadLongInt;
            alignment.JumpAlignSkipMax:=TokenReadLongInt;
            alignment.CoalesceAlign:=TokenReadLongInt;
            alignment.CoalesceAlignSkipMax:=TokenReadLongInt;
            alignment.ConstAlignMin:=TokenReadLongInt;
            alignment.ConstAlignMax:=TokenReadLongInt;
            alignment.VarAlignMin:=TokenReadLongInt;
            alignment.VarAlignMax:=TokenReadLongInt;
            alignment.LocalAlignMin:=TokenReadLongInt;
            alignment.LocalAlignMax:=TokenReadLongInt;
            alignment.RecordAlignMin:=TokenReadLongInt;
            alignment.RecordAlignMax:=TokenReadLongInt;
            alignment.MaxCRecordAlign:=TokenReadLongInt;
            TokenReadSet(GlobalSwitches,sizeof(GlobalSwitches));
            TokenReadSet(TargetSwitches,sizeof(TargetSwitches));
            TokenReadSet(ModuleSwitches,sizeof(ModuleSwitches));
            TokenReadSet(LocalSwitches,sizeof(LocalSwitches));
            TokenReadSet(ModeSwitches,sizeof(ModeSwitches));
            TokenReadSet(OptimizerSwitches,sizeof(OptimizerSwitches));
            TokenReadSet(GenWPOptimizerSwitches,sizeof(GenWPOptimizerSwitches));
            TokenReadSet(DoWPOptimizerSwitches,sizeof(DoWPOptimizerSwitches));
            TokenReadSet(DebugSwitches,sizeof(DebugSwitches));
            { 0: old behaviour for sets <=256 elements
              >0: round to this size }
            SetAlloc:=TokenReadShortInt;
            PackEnum:=TokenReadShortInt;
            PackRecords:=TokenReadShortInt;
            MaxFPURegisters:=TokenReadShortInt;

            verbosity:=TokenReadLongInt;

            CPUType:=TCPUType(TokenReadEnum(sizeof(TCPUType)));
            OptimizeCPUType:=TCPUType(TokenReadEnum(sizeof(TCPUType)));
            AsmCPUType:=TCPUType(TokenReadEnum(sizeof(TCPUType)));
            FPUType:=TFPUType(TokenReadEnum(sizeof(TFPUType)));
            AsmMode:=TAsmMode(TokenReadEnum(sizeof(TAsmMode)));
            InterfaceType:=TInterfaceTypes(TokenReadEnum(sizeof(TInterfaceTypes)));
            DefProcCall:=TProcCallOption(TokenReadEnum(sizeof(TProcCallOption)));
            { tstringencoding is word type,
              thus this should be OK here }
            SourceCodePage:=TStringEncoding(TokenReadWord);

            MinFPConstPrec:=TFloatType(TokenReadEnum(sizeof(TFloatType)));

            DisableDirCache:=Boolean(TokenReadByte);

            TLSModel:=TTLSModel(TokenReadEnum(sizeof(TTLSModel)));
            LineEndingType:=TLineEndingType(TokenReadEnum(sizeof(TLineEndingType)));
            WhitespaceTrimCount:=TokenReadWord;
            WhitespaceTrimAuto:=Boolean(TokenReadByte);
           lEndPos:=FReplayTokenBuf.pos;
           if lEndPos-lStartPos<>AExpectedSize then
             Comment(VError,'Wrong size of Settings read-in');
         end;
     end;

    procedure TScannerFile.TokenWriteSettings(var ASettings : TSettings; var ASize : asizeint);

    {    This procedure
       needs to be changed whenever
       globals.tsettings type is changed,
       the problem is that no error will appear
       before tests with generics are tested. PM }

       var
         lSizePos, lStartPos, lEndPos : LongWord;
      begin
        { Keep this field order matched with tokenreadsettings. }
        lSizePos:=FRecordTokenBuf.pos;
        ASize:=0;
        TokenWriteSizeInt(ASize);
        lStartPos:=FRecordTokenBuf.pos;
        with ASettings do
          begin
            TokenWriteLongInt(alignment.ProcAlign);
            TokenWriteLongInt(alignment.LoopAlign);
            TokenWriteLongInt(alignment.JumpAlign);
            TokenWriteLongInt(alignment.JumpAlignSkipMax);
            TokenWriteLongInt(alignment.CoalesceAlign);
            TokenWriteLongInt(alignment.CoalesceAlignSkipMax);
            TokenWriteLongInt(alignment.ConstAlignMin);
            TokenWriteLongInt(alignment.ConstAlignMax);
            TokenWriteLongInt(alignment.VarAlignMin);
            TokenWriteLongInt(alignment.VarAlignMax);
            TokenWriteLongInt(alignment.LocalAlignMin);
            TokenWriteLongInt(alignment.LocalAlignMax);
            TokenWriteLongInt(alignment.RecordAlignMin);
            TokenWriteLongInt(alignment.RecordAlignMax);
            TokenWriteLongInt(alignment.MaxCRecordAlign);
            TokenWriteSet(GlobalSwitches,sizeof(GlobalSwitches));
            TokenWriteSet(TargetSwitches,sizeof(TargetSwitches));
            TokenWriteSet(ModuleSwitches,sizeof(ModuleSwitches));
            TokenWriteSet(LocalSwitches,sizeof(LocalSwitches));
            TokenWriteSet(ModeSwitches,sizeof(ModeSwitches));
            TokenWriteSet(OptimizerSwitches,sizeof(OptimizerSwitches));
            TokenWriteSet(GenWPOptimizerSwitches,sizeof(GenWPOptimizerSwitches));
            TokenWriteSet(DoWPOptimizerSwitches,sizeof(DoWPOptimizerSwitches));
            TokenWriteSet(DebugSwitches,sizeof(DebugSwitches));
            { 0: old behaviour for sets <=256 elements
              >0: round to this size }
            TokenWriteShortInt(SetAlloc);
            TokenWriteShortInt(PackEnum);
            TokenWriteShortInt(PackRecords);
            TokenWriteShortInt(MaxFPURegisters);
            TokenWriteLongInt(verbosity);

            TokenWriteEnum(CPUType,sizeof(TCPUType));
            TokenWriteEnum(OptimizeCPUType,sizeof(TCPUType));
            TokenWriteEnum(AsmCPUType,sizeof(TCPUType));
            TokenWriteEnum(FPUType,sizeof(TFPUType));
            TokenWriteEnum(AsmMode,sizeof(TAsmMode));
            TokenWriteEnum(InterfaceType,sizeof(TInterfaceTypes));
            TokenWriteEnum(DefProcCall,sizeof(TProcCallOption));
            { tstringencoding is word type,
              thus this should be OK here }
            TokenWriteWord(SourceCodePage);

            TokenWriteEnum(MinFPConstPrec,sizeof(TFloatType));

            FRecordTokenBuf.write(Byte(DisableDirCache),1);

            TokenWriteEnum(TLSModel,sizeof(TLSModel));

            TokenWriteEnum(LineEndingType,sizeof(TLineEndingType));
            TokenWriteWord(WhitespaceTrimCount);
            TokenWriteByte(Byte(WhitespaceTrimAuto));
           lEndPos:=FRecordTokenBuf.pos;
           ASize:=lEndPos-lStartPos;
           FRecordTokenBuf.seek(lSizePos);
           TokenWriteSizeInt(ASize);
           FRecordTokenBuf.seek(lEndPos);
         end;
     end;


    procedure TScannerFile.RecordToken;
      var
        lToken : TToken;
        lSpecialToken : TSpecialGenericToken;
        lLength,lMessageCount,lCopySize : asizeint;
        lValue : LongInt;
        lByte : Byte;
        lMessage : PMessageStateRecord;
      begin
        if not Assigned(FRecordTokenBuf) then
          InternalError(200511176);
        lToken:=_GENERICSPECIALTOKEN;
        { ensure that all fields of settings are up to date }
        CurrentSettings.verbosity:=status.verbosity;
        { settings changed? }
        { last field pmessage is handled separately below in
          ST_LOADMESSAGES }
        if CompareByte(CurrentSettings,FLastSettings,
             sizeof(CurrentSettings)-sizeof(pointer))<>0 then
          begin
            { use a special token to record it }
            lSpecialToken:=sgtLoadSettings;
            WriteToken(lToken);
            FRecordTokenBuf.write(lSpecialToken,1);
            lCopySize:=sizeof(CurrentSettings)-sizeof(pointer);
            TokenWriteSettings(CurrentSettings,lCopySize);
            FLastSettings:=CurrentSettings;
          end;

        if CurrentSettings.PMessage<>FLastMessage then
          begin
            { use a special token to record it }
            lSpecialToken:=sgtLoadMessages;
            WriteToken(lToken);
            FRecordTokenBuf.write(lSpecialToken,1);
            lMessageCount:=0;
            lMessage:=CurrentSettings.PMessage;
            while Assigned(lMessage) do
              begin
                if lMessageCount=high(asizeint) then
                  { Too many messages }
                  InternalError(2011090401);
                inc(lMessageCount);
                lMessage:=lMessage^.next;
              end;
            TokenWriteSizeInt(lMessageCount);
            lMessage:=CurrentSettings.PMessage;
            while Assigned(lMessage) do
              begin
                { SB: this is handled by tokenreadlongint }
                lValue:=lMessage^.Value;
                TokenWriteLongInt(lValue);
                lValue:=ord(lMessage^.state);
                TokenWriteLongInt(lValue);
                lMessage:=lMessage^.next;
              end;
            FLastMessage:=CurrentSettings.PMessage;
          end;

        { file pos changes? }
        if CurrentTokenPos.fileindex<>FLastFilePos.fileindex then
          begin
            lSpecialToken:=sgtFileIndex;
            WriteToken(lToken);
            FRecordTokenBuf.write(lSpecialToken,1);
            TokenWriteWord(CurrentTokenPos.fileindex);
            FLastFilePos.fileindex:=CurrentTokenPos.fileindex;
            FLastFilePos.line:=0;
          end;
        if CurrentTokenPos.line<>FLastFilePos.line then
          begin
            lSpecialToken:=sgtLine;
            WriteToken(lToken);
            FRecordTokenBuf.write(lSpecialToken,1);
            TokenWriteLongInt(CurrentTokenPos.line);
            FLastFilePos.line:=CurrentTokenPos.line;
            FLastFilePos.column:=0;
          end;
        if CurrentTokenPos.column<>FLastFilePos.column then
          begin
            lSpecialToken:=sgtColumn;
            WriteToken(lToken);
            { can the column be written packed? }
            if CurrentTokenPos.column<$80 then
              begin
                lByte:=$80 or CurrentTokenPos.column;
                FRecordTokenBuf.write(lByte,1);
              end
            else
              begin
                FRecordTokenBuf.write(lSpecialToken,1);
                TokenWriteWord(CurrentTokenPos.column);
              end;
            FLastFilePos.column:=CurrentTokenPos.column;
          end;

        WriteToken(FToken);
        if FToken<>_GENERICSPECIALTOKEN then
          WriteToken(FIDToken);
        case FToken of
          _CWCHAR,
          _CWSTRING :
            begin
              TokenWriteSizeInt(FPatternW.len);
              if FPatternW.len>0 then
                FRecordTokenBuf.write(FPatternW.data[0],FPatternW.len*sizeof(TCompilerWideChar));
            end;
          _CSTRING:
            begin
              lLength:=length(FCStringPattern);
              TokenWriteSizeInt(lLength);
              if lLength>0 then
                FRecordTokenBuf.write(FCStringPattern[1],lLength);
            end;
          _CCHAR,
          _INTCONST,
          _REALNUMBER :
            begin
              { pexpr.pas messes with pattern in case of negative integer consts,
                see around line 2562 the comment of JM; remove the - before recording it
                                                     (FK)
              }
              if (FToken=_INTCONST) and (FPattern[1]='-') then
                delete(FPattern,1,1);
              FRecordTokenBuf.write(FPattern[0],1);
              FRecordTokenBuf.write(FPattern[1],length(FPattern));
            end;
          _ID :
            begin
              FRecordTokenBuf.write(FOrgPattern[0],1);
              FRecordTokenBuf.write(FOrgPattern[1],length(FOrgPattern));
            end;
          else
            ;
        end;
      end;


    procedure TScannerFile.StartReplayTokens(ABuffer:TDynamicArray);
      begin
        if not Assigned(ABuffer) then
          InternalError(200511175);

        { save current scanner state }
        FReplayStack:=TReplayStack.Create(FToken,FIDToken,FOrgPattern,FPattern,
          FCStringPattern,FPatternW,CurrentSettings,FReplayTokenBuf,
          PendingState,status.verbosity,FReplayStack);
{$ifdef check_inputpointer_limits}
        if Assigned(FHiddenInputPointer) then
          DecInputPointer;
{$else not check_inputpointer_limits}
        if Assigned(FInputPointer) then
          dec(FInputPointer);
{$endif check_inputpointer_limits}
        { install buffer }
        FReplayTokenBuf:=ABuffer;

        { ensure that existing message state records won't be freed }
        CurrentSettings.PMessage:=nil;
        PendingState:=default(TPendingState);

        { reload next token }
        FReplayTokenBuf.seek(0);
        ReplayToken;
      end;


    function TScannerFile.ReadToken: TToken;
      var
        lByte,lSecondByte : Byte;
      begin
        FReplayTokenBuf.read(lByte,1);
        if (lByte and $80)<>0 then
          begin
            FReplayTokenBuf.read(lSecondByte,1);
            Result:=TToken(((lByte and $7f) shl 8) or lSecondByte);
          end
        else
          Result:=TToken(lByte);
      end;


    procedure TScannerFile.ReplayToken;
      var
        lLength,lMessageCount,lCopySize : asizeint;
        lSpecialToken : TSpecialGenericToken;
        lIndex : Byte;
        lMessage,lPreviousMessage : PMessageStateRecord;
        lMessageSet : THashSet;
        lMessageFound : Boolean;
      begin
        if not Assigned(FReplayTokenBuf) then
          InternalError(200511177);
        { End of replay buffer? Then load the next char from the file again }
        if FReplayTokenBuf.pos>=FReplayTokenBuf.Size then
          begin
            FToken:=FReplayStack.FToken;
            FIDToken:=FReplayStack.FIDToken;
            FPattern:=FReplayStack.FPattern;
            FOrgPattern:=FReplayStack.FOrgPattern;
            CopyWideString(FReplayStack.FPatternW,FPatternW);
            FCStringPattern:=FReplayStack.FCStringPattern;
            FReplayTokenBuf:=FReplayStack.FTokenBuf;
            { restore compiler settings }
            CurrentSettings:=FReplayStack.FSettings;
            PendingState:=FReplayStack.FPending;
            if Assigned(PendingState.NextMessageRecord) then
              FreeLocalVerbosity(PendingState.NextMessageRecord);
            RecordPendingVerbosityFullSwitch(FReplayStack.FVerbosity);
            PendingState.NextMessageRecord:=CurrentSettings.PMessage;
            CurrentSettings.PMessage:=nil;
            PopReplayStack;
{$ifdef check_inputpointer_limits}
            if Assigned(FHiddenInputPointer) then
              begin
                FChar:=GetInputPointerChar;
                IncInputPointer;
              end;
{$else not check_inputpointer_limits}
            if Assigned(FInputPointer) then
              begin
                FChar:=FInputPointer^;
                inc(FInputPointer);
              end;
{$endif check_inputpointer_limits}
            exit;
          end;
        repeat
          { load token from the buffer }
          FToken:=ReadToken;
          if FToken<>_GENERICSPECIALTOKEN then
            FIDToken:=ReadToken
          else
            FIDToken:=_NOID;
          case FToken of
            _CWCHAR,
            _CWSTRING :
              begin
                lLength:=TokenReadSizeInt;
                SetLengthWideString(FPatternW,lLength);
                if lLength>0 then
                  FReplayTokenBuf.read(FPatternW.data[0],FPatternW.len*sizeof(TCompilerWideChar));
                FOrgPattern:='';
                FPattern:='';
                FCStringPattern:='';
              end;
            _CSTRING:
              begin
                lLength:=TokenReadSizeInt;
                if lLength>0 then
                  begin
                    SetLength(FCStringPattern,lLength);
                    FReplayTokenBuf.read(FCStringPattern[1],lLength);
                  end
                else
                  FCStringPattern:='';
                FOrgPattern:='';
                FPattern:='';
              end;
            _CCHAR,
            _INTCONST,
            _REALNUMBER :
              begin
                FReplayTokenBuf.read(FPattern[0],1);
                FReplayTokenBuf.read(FPattern[1],length(FPattern));
                FOrgPattern:='';
              end;
            _ID :
              begin
                FReplayTokenBuf.read(FOrgPattern[0],1);
                FReplayTokenBuf.read(FOrgPattern[1],length(FOrgPattern));
                FPattern:=upper(FOrgPattern);
              end;
            _GENERICSPECIALTOKEN:
              begin
                FReplayTokenBuf.read(lSpecialToken,1);
                { packed column? }
                if (ord(lSpecialToken) and $80)<>0 then
                  begin
                      CurrentTokenPos.column:=ord(lSpecialToken) and $7f;
                      CurrentFilePos:=CurrentTokenPos;
                  end
                else
                  case lSpecialToken of
                    sgtLoadSettings:
                      begin
                        lCopySize:=TokenReadSizeInt;
                        //if copy_size <> sizeof(current_settings)-sizeof(pointer) then
                        //  internalerror(2011090501);
                        {
                        replaytokenbuf.read(current_settings,copy_size);
                        }
                        TokenReadSettings(CurrentSettings,lCopySize);
                        { Generic token buffers carry the defining unit's
                          settings. Their saved text defaults cannot override
                          the compiler invocation's String/Char/PChar model. }
                        HandleModeSwitches(m_default_ansistring,false);
                        RecordPendingVerbosityFullSwitch(CurrentSettings.verbosity);
                      end;
                    sgtLoadMessages:
                      begin
                        { free current and pending messages }
                        FreeLocalVerbosity(CurrentSettings.PMessage);
                        FreeLocalVerbosity(PendingState.NextMessageRecord);
                        { the message settings are stored from newest to oldest
                          change for the whole stack, so we only want to apply
                          the newest changes for each message type }
                        lMessageCount:=TokenReadSizeInt;
                        lMessageSet:=THashSet.Create(min(lMessageCount,10),false,false);
                        lPreviousMessage:=nil;
                        lMessage:=nil;
                        for lIndex:=1 to lMessageCount do
                          begin
                            if not Assigned(lMessage) then
                              begin
                                new(lMessage);
                                {$IFDEF DEBUG_MESSAGESTATE}
                                if CurrentModule=nil then
                                  InternalError(2026030704);
                                lMessage^.owner:=CurrentModule;
                                {$ENDIF}
                              end;
                            lMessage^.Value:=TokenReadLongInt;
                            lMessage^.state:=TMsgState(TokenReadLongInt);
                            lMessage^.next:=nil;
                            lMessageFound:=false;
                            if Assigned(lMessageSet.findoradd(@lMessage^.Value,sizeof(lMessage^.Value),lMessageFound)) and lMessageFound then
                              continue;
                            if lIndex=1 then
                              PendingState.NextMessageRecord:=lMessage
                            else
                              lPreviousMessage^.next:=lMessage;
                            lPreviousMessage:=lMessage;
                            lMessage:=nil;
                          end;
                        if Assigned(lMessage) then
                          dispose(lMessage);
                        lMessageSet.free;
                        lMessageSet := nil;
                      end;
                    sgtLine:
                      begin
                        CurrentTokenPos.line:=TokenReadLongInt;
                        CurrentFilePos:=CurrentTokenPos;
                      end;
                    sgtColumn:
                      begin
                        CurrentTokenPos.column:=TokenReadWord;
                        CurrentFilePos:=CurrentTokenPos;
                      end;
                    sgtFileIndex:
                      begin
                        CurrentTokenPos.fileindex:=TokenReadWord;
                        CurrentFilePos:=CurrentTokenPos;
                      end;
                  end;
                continue;
              end;
            else
              ;
          end;
          break;
        until false;
      end;


    procedure TScannerFile.AddFile(AInputFile:TInputFile);
      begin
        SaveInputFile;
        { add to list }
        AInputFile.next:=FInputFile;
        FInputFile:=AInputFile;
        { load new inputfile }
        RestoreInputFile;
      end;


    procedure TScannerFile.Reload;
      var
        lWasMacro: Boolean;
      begin
        with FInputFile do
         begin
           { when nothing more to read then leave immediately, so we
             don't change the current_filepos and leave it point to the last
             char }
           if (FChar=#26) and (not Assigned(next)) then
            exit;
           repeat
           { still more to read?, then change the #0 to a space so its seen
             as a separator, this can't be used for macro's which can change
             the place of the #0 in the buffer with tempopen }
             if (FChar=#0) and (BufSize>0) and
                not(FInputFile.IsMacro) and
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                (FHiddenInputPointer-FHiddenInputBuffer<BufSize) then
{$else not CHECK_INPUTPOINTER_LIMITS}
                (FInputPointer-FInputBuffer<BufSize) then
{$endif CHECK_INPUTPOINTER_LIMITS}
              begin
                FChar:=' ';
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
                exit;
              end;
           { can we read more from this file ? }
             if (FChar<>#26) and (not EndOfFile) then
              begin
                ReadBuf;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                FHiddenInputPointer:=PAnsiChar(buf);
                FHiddenInputBuffer:=PAnsiChar(buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
                FInputPointer:=PAnsiChar(buf);
                FInputBuffer:=PAnsiChar(buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
                FInputStart:=BufStart;
              { first line? }
                if FLineNumber=0 then
                 begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                   FChar:=GetInputPointerChar;
                   { eat utf-8 signature? }
                   if (BufSize>2) and
                     (ord(GetInputPointerChar)=$ef) and
                     (ord(GetInputPointerChar(1))=$bb) and
                     (ord(GetInputPointerChar(2))=$bf) then
                     begin
{$else not CHECK_INPUTPOINTER_LIMITS}
                   FChar:=FInputPointer^;
                   { eat utf-8 signature? }
                   if (BufSize>2) and
                     (ord(FInputPointer^)=$ef) and
                     (ord((FInputPointer+1)^)=$bb) and
                     (ord((FInputPointer+2)^)=$bf) then
                     begin
{$endif CHECK_INPUTPOINTER_LIMITS}
                       (* we don't support including files with an UTF-8 bom
                          inside another file that wasn't encoded as UTF-8
                          already (we don't support {$codepage xxx} switches in
                          the middle of a file either) *)
                       if (CurrentSettings.SourceCodePage<>CP_UTF8) and
                          not CurrentModule.InGlobal then
                         Message(scanner_f_illegal_utf8_bom);
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                       IncInputPointer(3);
{$else not CHECK_INPUTPOINTER_LIMITS}
                       inc(FInputPointer,3);
{$endif CHECK_INPUTPOINTER_LIMITS}
                       message(scan_c_switching_to_utf8);
                       CurrentSettings.SourceCodePage:=CP_UTF8;
                       exclude(CurrentSettings.ModuleSwitches,cs_system_codepage);
                       include(CurrentSettings.ModuleSwitches,cs_explicit_codepage);
                     end;

                   FLineNumber:=1;
                   if cs_asm_source in CurrentSettings.GlobalSwitches then
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                     FInputFile.setline(FLineNumber,FInputStart+FHiddenInputPointer-FHiddenInputBuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
                     FInputFile.setline(FLineNumber,FInputStart+FInputPointer-FInputBuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
                 end;
              end
             else
              begin
                lWasMacro:=FInputFile.IsMacro;
              { load eof position in tokenpos/current_filepos }
                GetTokenPos;
              { close file }
                CloseInputFile;
              { no next module, than EOF }
                if not Assigned(FInputFile.next) then
                 begin
                   FChar:=#26;
                   exit;
                 end;
              { load next file and reopen it }
                NextFile;
                TempOpenInputFile;
              { status }
                Message1(scan_t_back_in,FInputFile.name);
              { end of include file is like a line break which ends e.g. also // style comments }
                if not(lWasMacro) and (FCurrentCommentStyle=commentDelphi) then
                  begin
                    FChar:=#10;
                  { ... but we have to decrease the line number first because it is increased due to this
                    inserted line break later on }
                    dec(FLineNumber);
                    exit;
                  end;
              end;
           { load next char }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
             FChar:=GetInputPointerChar;
             IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
             FChar:=FInputPointer^;
             inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
           until FChar<>#0; { if also end, then reload again }
         end;
      end;


    procedure TScannerFile.SubstituteMacro(const AMacroName:String;AText:pchar;ALength,ALine,AFileIndex:LongInt;AInternallyGenerated: Boolean);
      var
        lInputFile : TInputFile;
      begin
        { save old position }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        DecInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        dec(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
        TempCloseInputFile;
      { create macro 'file' }
        { use special name to dispose after !! }
        lInputFile:=Do_OpenInputFile('_Macro_.'+AMacroName);
        AddFile(lInputFile);
        with FInputFile do
         begin
           inc(FMacroNestingDepth);
           SetMacro(AText,ALength);
         { local buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           FHiddenInputBuffer:=PAnsiChar(buf);
           FHiddenInputPointer:=PAnsiChar(buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
           FInputBuffer:=PAnsiChar(buf);
           FInputPointer:=PAnsiChar(buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
           FInputStart:=BufStart;
           RefIndex:=AFileIndex;
           InternallyGeneratedMacro:=AInternallyGenerated;
         end;
      { reset line }
        FLineNumber:=ALine;
        FLastLinePos:=0;
        FLastTokenPos:=0;
        FNextTokenPos:=0;
      { load new c }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FChar:=GetInputPointerChar;
        IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FChar:=FInputPointer^;
        inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
      end;


    procedure TScannerFile.DoGetTokenPos(out ATokenPos: LongInt; out AFilePos: TFilePosInfo);
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        ATokenPos:=FInputStart+(FHiddenInputPointer-FHiddenInputBuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
        ATokenPos:=FInputStart+(FInputPointer-FInputBuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
        AFilePos.line:=FLineNumber;
        AFilePos.column:=ATokenPos-FLastLinePos;
        AFilePos.fileindex:=FInputFile.RefIndex;
        AFilePos.moduleindex:=CurrentModule.ModuleID;
      end;


    procedure TScannerFile.GetTokenPos;
    { load the values of tokenpos and lasttokenpos }
      begin
        DoGetTokenPos(FLastTokenPos,CurrentTokenPos);
        CurrentFilePos:=CurrentTokenPos;
      end;


    procedure TScannerFile.CacheNextTokenPos;
      begin
        DoGetTokenPos(FNextTokenPos,FNextFilePos);
      end;


    procedure TScannerFile.SetNextToken;
      begin
        FToken:=FNextToken;
        FNextToken:=NOTOKEN;
        FLastTokenPos:=FNextTokenPos;
        CurrentTokenPos:=FNextFilePos;
        CurrentFilePos:=CurrentTokenPos;
        FNextTokenPos:=0;
      end;


    procedure TScannerFile.SaveTokenPos;
      begin
        FOldLastTokenPos:=FLastTokenPos;
        FOldCurrentFilePos:=CurrentFilePos;
        FOldCurrentTokenPos:=CurrentTokenPos;
      end;


    procedure TScannerFile.RestoreTokenPos;
      begin
        FLastTokenPos:=FOldLastTokenPos;
        CurrentFilePos:=FOldCurrentFilePos;
        CurrentTokenPos:=FOldCurrentTokenPos;
      end;


    procedure TScannerFile.IncCommentLevel;
      begin
         if (m_nested_comment in CurrentSettings.ModeSwitches) then
           inc(FCommentLevel)
         else
           FCommentLevel:=1;
         if (FCommentLevel>1) then
          begin
             SaveTokenPos;
             GetTokenPos; { update for warning }
             Message1(scan_w_comment_level,ToStr(FCommentLevel));
             RestoreTokenPos;
          end;
      end;


    procedure TScannerFile.DecCommentLevel;
      begin
         if (m_nested_comment in CurrentSettings.ModeSwitches) then
           dec(FCommentLevel)
         else
           FCommentLevel:=0;
      end;


    procedure TScannerFile.LineBreak;
      var
         lCurrentChar : Char;
      begin
        with FInputFile do
         begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           if (byte(GetInputPointerChar)=0) and not(EndOfFile) then
{$else not CHECK_INPUTPOINTER_LIMITS}
           if (byte(FInputPointer^)=0) and not(EndOfFile) then
{$endif CHECK_INPUTPOINTER_LIMITS}
             begin
               lCurrentChar:=FChar;
               Reload;
               if byte(lCurrentChar)+byte(FChar)<>23 then
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                 DecInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                 dec(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
             end
           else
             begin
               { Support all combination of #10 and #13 as line break }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
               if (byte(GetInputPointerChar)+byte(FChar)=23) then
                 IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
               if (byte(FInputPointer^)+byte(FChar)=23) then
                 inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
             end;
           { Always return #10 as line break }
           FChar:=#10;
           { increase line counters }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           FLastLinePos:=FInputStart+(FHiddenInputPointer-FHiddenInputBuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
           FLastLinePos:=FInputStart+(FInputPointer-FInputBuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
           inc(FLineNumber);
           { update linebuffer }
           if cs_asm_source in CurrentSettings.GlobalSwitches then
             FInputFile.setline(FLineNumber,FLastLinePos);
           { update for status and call the show status routine,
             but don't touch current_filepos ! }
           SaveTokenPos;
           GetTokenPos; { update for v_status }
           inc(status.CompiledLines);
           ShowStatus;
           RestoreTokenPos;
         end;
      end;


    procedure TScannerFile.IllegalChar(AChar:Char);
      var
        lText : String;
      begin
        if AChar in [#32..#255] then
          lText:=''''+AChar+''''
        else
          lText:='#'+ToStr(ord(AChar));
        Message2(scan_f_illegal_char,lText,'$'+HexStr(ord(AChar),2));
      end;


    procedure TScannerFile.HandleEndOfFile;
      begin
        CheckPreProcStack;
        if FInMultilineString then
          Message2(scan_f_unterminated_multiline_string, ToStr(FMultilineStartLine), ToStr(FMultilineStartColumn))
        else
          Message(scan_f_end_of_file);
      end;

  {-------------------------------------------
           IF Conditional Handling
  -------------------------------------------}

    procedure TScannerFile.CheckPreProcStack;
      begin
      { check for missing ifdefs }
        while Assigned(FPreProcStack) do
         begin
           Message4(scan_e_endif_expected,cPreProcStrings[FPreProcStack.FType],FPreProcStack.FName,
             CurrentModule.SourceFiles.Get_File_Name(FPreProcStack.FFileIndex),
             ToStr(FPreProcStack.FLineNumber));
           PopPreProcStack;
         end;
      end;


    procedure TScannerFile.PopPreProcStack;
      var
        lStack : TPreProcStack;
      begin
        if Assigned(FPreProcStack) then
         begin
           Message1(scan_c_endif_found,FPreProcStack.FName);
           lStack:=FPreProcStack.FNext;
           FPreProcStack.free;
           FPreProcStack:=lStack;
         end
        else
         Message(scan_e_endif_without_if);
      end;


    procedure TScannerFile.IfPreProcStack(AType:TPreProcType;ACompileTimePredicate:TCompileTimePredicate;AMessageID:LongInt);
      var
        lCondition: Boolean;
        lValueDescription: String;
      begin
        if (FPreProcStack=nil) or FPreProcStack.FAccept then
          lCondition:=ACompileTimePredicate(lValueDescription)
        else
          begin
            lCondition:= false;
            lValueDescription:= '';
          end;
        FPreProcStack:=TPreProcStack.Create(AType, lCondition, FPreProcStack);
        FPreProcStack.FName:=lValueDescription;
        FPreProcStack.FLineNumber:=FLineNumber;
        FPreProcStack.FFileIndex:=CurrentFilePos.fileindex;
        if FPreProcStack.FAccept then
          Message2(AMessageID,FPreProcStack.FName,'accepted')
        else
          Message2(AMessageID,FPreProcStack.FName,'rejected');
      end;

    procedure TScannerFile.ElsePreProcStack;
      begin
        if Assigned(FPreProcStack) and
           (FPreProcStack.FType<>ppElse) then
         begin
           if (FPreProcStack.FType=ppElseIf) then
             FPreProcStack.FAccept:=false
           else
             if (not(Assigned(FPreProcStack.FNext)) or (FPreProcStack.FNext.FAccept)) then
               FPreProcStack.FAccept:=not FPreProcStack.FAccept;
           FPreProcStack.FIfType:=FPreProcStack.FType;
           FPreProcStack.FType:=ppElse;
           FPreProcStack.FLineNumber:=FLineNumber;
           FPreProcStack.FFileIndex:=CurrentFilePos.fileindex;
           if FPreProcStack.FAccept then
            Message2(scan_c_else_found,FPreProcStack.FName,'accepted')
           else
            Message2(scan_c_else_found,FPreProcStack.FName,'rejected');
         end
        else
         Message(scan_e_endif_without_if);
      end;

    procedure TScannerFile.ElseIfPreProcStack(ACompileTimePredicate:TCompileTimePredicate);
      var
        lValueDescription: String;
      begin
        if Assigned(FPreProcStack) and
           (FPreProcStack.FType in [ppIf,ppIfDef,ppIfNDef,ppElseIf]) then
         begin
           { when the branch is accepted we use pp_elseif so we know that
             all the next branches need to be rejected. when this branch is still
             not accepted then leave it at pp_if }
           if (FPreProcStack.FType=ppElseIf) then
             FPreProcStack.FAccept:=false
           else if (FPreProcStack.FType in [ppIf,ppIfDef,ppIfNDef]) and FPreProcStack.FAccept then
               begin
                 FPreProcStack.FAccept:=false;
                 FPreProcStack.FType:=ppElseIf;
               end
           else if (not(Assigned(FPreProcStack.FNext)) or (FPreProcStack.FNext.FAccept))
                   and ACompileTimePredicate(lValueDescription) then
               begin
                 FPreProcStack.FName:=lValueDescription;
                 FPreProcStack.FAccept:=true;
                 FPreProcStack.FType:=ppElseIf;
               end;

           FPreProcStack.FLineNumber:=FLineNumber;
           FPreProcStack.FFileIndex:=CurrentFilePos.fileindex;
           if FPreProcStack.FAccept then
             Message2(scan_c_else_found,FPreProcStack.FName,'accepted')
           else
             Message2(scan_c_else_found,FPreProcStack.FName,'rejected');
         end
        else
         Message(scan_e_endif_without_if);
      end;


    procedure TScannerFile.PopReplayStack;
      var
        lStack : TReplayStack;
      begin
        if Assigned(FReplayStack) then
         begin
           lStack:=FReplayStack.FNext;
           FReplayStack.free;
           FReplayStack:=lStack;
         end;
      end;


    function TScannerFile.ReplayStackDepth:LongInt;
      var
        lStack: TReplayStack;
      begin
        Result:=0;
        lStack:=FReplayStack;
        while Assigned(lStack) do
          begin
            inc(Result);
            lStack:=lStack.FNext;
          end;
      end;

    procedure TScannerFile.HandleConditional(ADirective:TDirectiveItem);
      begin
        SaveTokenPos;
        repeat
          CurrentScanner.GetTokenPos;
          Message1(scan_d_handling_switch,'$'+ADirective.name);
          ADirective.FProc();
          { accept the text ? }
          if (CurrentScanner.FPreProcStack=nil) or CurrentScanner.FPreProcStack.FAccept then
           break
          else
           begin
             CurrentScanner.GetTokenPos;
             Message(scan_c_skipping_until);
             repeat
               CurrentScanner.SkipUntilDirective;
               if not (m_mac in CurrentSettings.ModeSwitches) then
                 ADirective:=TDirectiveItem(TurboScannerDirectives.Find(CurrentScanner.ReadID))
               else
                 ADirective:=TDirectiveItem(MacScannerDirectives.Find(CurrentScanner.ReadID));
             until Assigned(ADirective) and (ADirective.FIsConditional);
             CurrentScanner.GetTokenPos;
           end;
        until false;
        RestoreTokenPos;
      end;


    procedure TScannerFile.HandleDirectives;
      var
         lDirective  : TDirectiveItem;
         lName : String;
      begin
         GetTokenPos;
         ReadChar; {Remove the $}
         lName:=ReadID;
         { handle empty directive }
         if lName='' then
           begin
             Message1(scan_w_illegal_switch,'$');
             exit;
           end;
         { skip this directive? }
         if (FIgnoreDirectives.find(lName)<>nil) then
          begin
            if (FCommentLevel>0) then
             ReadComment;
            { we've read the whole comment }
            FCurrentCommentStyle:=commentNone;
            exit;
          end;
         { Check for compiler switches }
          while (length(lName)=1) and (FChar in ['-','+']) and
            IsRecognizedSwitch(lName[1]) do
          begin
            Message1(scan_d_handling_switch,'$'+lName+FChar);
            HandleSwitch(lName[1],FChar);
            CurrentScanner.ReadChar; {Remove + or -}
            if FChar=',' then
             begin
               CurrentScanner.ReadChar;   {Remove , }
               { read next switch, support $v+,$+}
               lName:=CurrentScanner.ReadID;
               if (lName='') then
                begin
                  if (FChar='$') and (m_fpc in CurrentSettings.ModeSwitches) then
                   begin
                     CurrentScanner.ReadChar;  { skip $ }
                     lName:=CurrentScanner.ReadID;
                   end;
                  if (lName='') then
                   Message1(scan_w_illegal_directive,'$'+FChar);
                end;
             end
            else
             lName:='';
          end;
         { directives may follow switches after a , }
         if lName<>'' then
          begin
            if not (m_mac in CurrentSettings.ModeSwitches) then
              lDirective:=TDirectiveItem(TurboScannerDirectives.Find(lName))
            else
              lDirective:=TDirectiveItem(MacScannerDirectives.Find(lName));

            if Assigned(lDirective) then
             begin
               if lDirective.FIsConditional then
                HandleConditional(lDirective)
               else
                begin
                  Message1(scan_d_handling_switch,'$'+lName);
                  lDirective.FProc();
                end;
             end
            else
             begin
               CurrentScanner.FIgnoreDirectives.Add(lName,cDirectiveIgnored);
               Message1(scan_w_illegal_directive,'$'+lName);
             end;
            { conditionals already read the comment }
            if (CurrentScanner.FCommentLevel>0) then
             CurrentScanner.ReadComment;
            { we've read the whole comment }
            FCurrentCommentStyle:=commentNone;
          end;
      end;


    procedure TScannerFile.ReadChar;
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        FChar:=GetInputPointerChar;
{$else not CHECK_INPUTPOINTER_LIMITS}
        FChar:=FInputPointer^;
{$endif CHECK_INPUTPOINTER_LIMITS}
        if FChar=#0 then
          Reload
        else
{$ifdef CHECK_INPUTPOINTER_LIMITS}
          IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
          inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
      end;


    procedure TScannerFile.ReadString;
      var
        lIndex : LongInt;
        lError : Boolean;
      begin
        lError:=false;
        lIndex:=0;
        repeat
          case FChar of
            '_','$',
            '0'..'9',
            'A'..'Z',
            'a'..'z' :
              begin
                if (FChar='$') and not FAllowGenericID then
                  break;
                if lIndex<255 then
                 begin
                   inc(lIndex);
                   FOrgPattern[lIndex]:=FChar;
                   if FChar in ['a'..'z'] then
                     FPattern[lIndex]:=chr(ord(FChar)-32)
                   else
                     FPattern[lIndex]:=FChar;
                 end
                else
                 begin
                   if not lError then
                     begin
                       Message(scan_e_string_exceeds_255_chars);
                       lError:=true;
                     end;
                 end;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                FChar:=GetInputPointerChar;
                IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                FChar:=FInputPointer^;
                inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
              end;
            #0 :
              Reload;
            else if FInputFile.InternallyGeneratedMacro and
                    (FChar in [cInternalMacroEscapeBegin..cInternalMacroEscapeEnd]) then
              begin
                if lIndex<255 then
                 begin
                   inc(lIndex);
                   FOrgPattern[lIndex]:=FChar;
                   FPattern[lIndex]:=FChar;
                 end
                else
                 begin
                   if not lError then
                     begin
                       Message(scan_e_string_exceeds_255_chars);
                       lError:=true;
                     end;
                 end;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                FChar:=GetInputPointerChar;
                IncInputPointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                FChar:=FInputPointer^;
                inc(FInputPointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
              end
            else
              break;
          end;
        until false;
        FOrgPattern[0]:=chr(lIndex);
        FPattern[0]:=chr(lIndex);
      end;


    procedure TScannerFile.ReadNumber;
      var
        lBase,
        lIndex  : LongInt;
        lFirstDigitRead: Boolean;
      begin
        case FChar of
          '%' :
            begin
              ReadChar;
              lBase:=2;
              FPattern[1]:='%';
              lIndex:=1;
            end;
          '&' :
            begin
              ReadChar;
              lBase:=8;
              FPattern[1]:='&';
              lIndex:=1;
            end;
          '$' :
            begin
              ReadChar;
              lBase:=16;
              FPattern[1]:='$';
              lIndex:=1;
            end;
          else
            begin
              lBase:=10;
              lIndex:=0;
            end;
        end;
        lFirstDigitRead:=false;
        while ((lBase>=10) and (FChar in ['0'..'9'])) or
              ((lBase=16) and (FChar in ['A'..'F','a'..'f'])) or
              ((lBase=8) and (FChar in ['0'..'7'])) or
              ((lBase=2) and (FChar in ['0'..'1'])) or
              ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and lFirstDigitRead and (FChar='_')) do
         begin
           if (lIndex<255) and (FChar<>'_') then
            begin
              inc(lIndex);
              FPattern[lIndex]:=FChar;
            end;
           ReadChar;
           lFirstDigitRead:=true;
         end;
        FPattern[0]:=chr(lIndex);
      end;


    function TScannerFile.ReadID:String;
      begin
        ReadString;
        ReadID:=FPattern;
      end;


    function TScannerFile.ReadVal:LongInt;
      var
        lValue : LongInt;
        lErrorCode : Integer;
      begin
        ReadNumber;
        val(FPattern,lValue,lErrorCode);
        ReadVal:=lValue;
      end;


    function TScannerFile.ReadVal64:Int64;
      var
        lValue : Int64;
        lErrorCode : Integer;
      begin
        ReadNumber;
        val(FPattern,lValue,lErrorCode);
        ReadVal64:=lValue;
      end;


    function TScannerFile.ReadComment(AIncludeSpecialChar: Boolean):ShortString;
      var
        lIndex : LongInt;
      begin
        lIndex:=0;
        repeat
          case FChar of
            '{' :
              begin
                if (AIncludeSpecialChar) and (lIndex<255) then
                begin
                  inc(lIndex);
                  ReadComment[lIndex]:=FChar;
                end;

                if FCurrentCommentStyle=commentTP then
                  IncCommentLevel;
              end;
            '}' :
              begin
                if (AIncludeSpecialChar) and (lIndex<255) then
                begin
                  inc(lIndex);
                  ReadComment[lIndex]:=FChar;
                end;

                if FCurrentCommentStyle=commentTP then
                  begin
                    ReadChar;
                    DecCommentLevel;


                    if FCommentLevel=0 then
                      break
                    else
                      continue;
                  end;
              end;
            '*' :
              begin
                if FCurrentCommentStyle=commentOldTP then
                  begin
                    ReadChar;
                    if FChar=')' then
                      begin
                        ReadChar;
                        DecCommentLevel;
                        break;
                      end
                    else
                    { Add both characters !!}
                      if (lIndex<255) then
                        begin
                          inc(lIndex);
                          ReadComment[lIndex]:='*';
                          if (lIndex<255) then
                            begin
                              inc(lIndex);
                              ReadComment[lIndex]:=FChar;
                            end;
                        end;
                  end
                else
                { Not old TP comment, so add...}
                  begin
                    if (lIndex<255) then
                      begin
                        inc(lIndex);
                        ReadComment[lIndex]:='*';
                      end;
                  end;
              end;
            #10,#13 :
              LineBreak;
            #26 :
              HandleEndOfFile;
            else
              begin
                if (lIndex<255) then
                  begin
                    inc(lIndex);
                    ReadComment[lIndex]:=FChar;
                  end;
              end;
          end;
          ReadChar;
        until false;
        ReadComment[0]:=chr(lIndex);
      end;


    function TScannerFile.ReadQuotedString:ShortString;
      var
        lIndex : LongInt;
        lMessageWritten : Boolean;
      begin
        lIndex:=0;
        lMessageWritten:=false;
        if (FChar in ['''','`']) then
          begin
            FHadMultilineString:=FInMultilineString;
            FInMultilineString:=(FChar='`');
            if FInMultilineString and (not (m_multiline_strings in CurrentSettings.ModeSwitches)) then
              begin
                Result[0]:=chr(0);
                IllegalChar(FChar);
              end;
            repeat
              ReadChar;
              case FChar of
                #26 :
                  HandleEndOfFile;
                #10,#13 :
                  if not FInMultilineString then
                    begin
                      if FHadMultilineString then
                        Message2(scan_f_unterminated_multiline_string,
                                 ToStr(FMultilineStartLine),
                                 ToStr(FMultilineStartColumn))
                      else
                        Message(scan_f_string_exceeds_line);
                    end;
                '''' :
                  if not FInMultilineString then
                    begin
                      ReadChar;
                      if FChar<>'''' then
                       break;
                    end;
                '`' :
                  if FInMultilineString then
                    begin
                      ReadChar;
                      if FChar<>'`' then
                       break;
                    end;
              end;
              if lIndex<255 then
                begin
                  inc(lIndex);
                  Result[lIndex]:=FChar;
                end
              else
                begin
                  if not lMessageWritten then
                    begin
                      Message(scan_e_string_exceeds_255_chars);
                      lMessageWritten:=true;
                    end;
                 end;
            until false;
          end;
        Result[0]:=chr(lIndex);
      end;


    function TScannerFile.ReadLongComment(AIncludeSpecialChar: Boolean):RawByteString;
      var
        lIndex : LongInt;

        procedure AddChar(AChar: AnsiChar = #0);
        begin
          Inc(lIndex);
          if lIndex>Length(ReadLongComment) then
            SetLength(ReadLongComment, Length(ReadLongComment)+256);
          if AChar<>#0 then
            ReadLongComment[lIndex]:=AChar
          else
            ReadLongComment[lIndex]:=FChar;
        end;
      begin
        lIndex:=0;
        SetLength(ReadLongComment, 256);
        repeat
          case FChar of
            '{' :
              begin
                if (AIncludeSpecialChar) then
                  AddChar;

                if FCurrentCommentStyle=commentTP then
                  IncCommentLevel;
              end;
            '}' :
              begin
                if (AIncludeSpecialChar) then
                  AddChar;

                if FCurrentCommentStyle=commentTP then
                  begin
                    ReadChar;
                    DecCommentLevel;


                    if FCommentLevel=0 then
                      break
                    else
                      continue;
                  end;
              end;
            '*' :
              begin
                if FCurrentCommentStyle=commentOldTP then
                  begin
                    ReadChar;
                    if FChar=')' then
                      begin
                        ReadChar;
                        DecCommentLevel;
                        break;
                      end
                    else
                    { Add both characters !!}
                      begin
                        AddChar('*');
                        AddChar;
                      end;
                  end
                else
                { Not old TP comment, so add...}
                  AddChar('*');
              end;
            #10,#13 :
              LineBreak;
            #26 :
              HandleEndOfFile;
            else
              AddChar;
          end;
          ReadChar;
        until false;
        SetLength(ReadLongComment, lIndex);
        SetCodePage(ReadLongComment, CurrentSettings.SourceCodePage, False);
      end;


    function TScannerFile.ReadLongQuotedString:RawByteString;
      var
        lIndex : LongInt;
        lMessageWritten : Boolean;

        procedure AddChar;
        begin
          Inc(lIndex);
          if lIndex>Length(ReadLongQuotedString) then
            SetLength(ReadLongQuotedString, Length(ReadLongQuotedString)+256);
          ReadLongQuotedString[lIndex]:=FChar;
        end;
      begin
        lIndex:=0;
        SetLength(ReadLongQuotedString, 256);
        lMessageWritten:=false;
        if (FChar='''') then
          begin
            repeat
              ReadChar;
              case FChar of
                #26 :
                  HandleEndOfFile;
                #10,#13 :
                  Message(scan_f_string_exceeds_line);
                '''' :
                  begin
                    ReadChar;
                    if FChar<>'''' then
                     break;
                  end;
              end;
              AddChar;
            until false;
          end;
        SetLength(ReadLongQuotedString, lIndex);
        SetCodePage(ReadLongQuotedString, CurrentSettings.SourceCodePage, False);
      end;


    function TScannerFile.ReadState:Char;
      var
        lState : Char;
      begin
        lState:=' ';
        if FChar=' ' then
         begin
           CurrentScanner.SkipSpace;
           CurrentScanner.ReadID;
           if FPattern='ON' then
            lState:='+'
           else
            if FPattern='OFF' then
             lState:='-';
         end
        else
         lState:=FChar;
        if not (lState in ['+','-']) then
         Message(scan_e_wrong_switch_toggle);
        ReadState:=lState;
      end;


    function TScannerFile.ReadOptionalState(AFallback:Char):Char;
      var
        lState : Char;
      begin
        lState:=' ';
        if FChar=' ' then
         begin
           CurrentScanner.SkipSpace;
           if FChar in ['*','}'] then
             lState:=AFallback
           else
             begin
               CurrentScanner.ReadID;
               if FPattern='ON' then
                lState:='+'
               else
                if FPattern='OFF' then
                 lState:='-';
             end;
         end
        else
          if FChar in ['*','}'] then
            lState:=AFallback
          else
            lState:=FChar;
        if not (lState in ['+','-']) then
         Message(scan_e_wrong_switch_toggle);
        ReadOptionalState:=lState;
      end;


    function TScannerFile.ReadStateDefault:Char;
      var
        lState : Char;
      begin
        lState:=' ';
        if FChar=' ' then
         begin
           CurrentScanner.SkipSpace;
           CurrentScanner.ReadID;
           if FPattern='ON' then
            lState:='+'
           else
            if FPattern='OFF' then
             lState:='-'
            else
             if FPattern='DEFAULT' then
              lState:='*';
         end
        else
         lState:=FChar;
        if not (lState in ['+','-','*']) then
         Message(scan_e_wrong_switch_toggle_default);
        ReadStateDefault:=lState;
      end;


    procedure TScannerFile.SkipSpace;
      begin
        repeat
          case FChar of
            #26 :
              begin
                Reload;
                if (FChar=#26) and not Assigned(FInputFile.next) then
                  break;
                continue;
              end;
            #10,
            #13 :
              LineBreak;
            #9,#11,#12,' ' :
              ;
            else
              break;
          end;
          ReadChar;
        until false;
      end;


    procedure TScannerFile.SkipUntilDirective;
      var
        lFound : LongInt;
        lNextCharLoaded : Boolean;
      begin
         lFound:=0;
         lNextCharLoaded:=false;
         repeat
           case FChar of
             #10,
             #13 :
               LineBreak;
             #26 :
               begin
                 Reload;
                 if (FChar=#26) and not Assigned(FInputFile.next) then
                   HandleEndOfFile;
                 continue;
               end;
             '{' :
               begin
                 if (FCurrentCommentStyle in [commentTP,commentNone]) then
                   begin
                     FCurrentCommentStyle:=commentTP;
                     if (FCommentLevel=0) then
                       lFound:=1;
                     IncCommentLevel;
                   end;
               end;
             '*' :
               begin
                 if (FCurrentCommentStyle=commentOldTP) then
                   begin
                     ReadChar;
                     if FChar=')' then
                       begin
                         DecCommentLevel;
                         lFound:=0;
                         FCurrentCommentStyle:=commentNone;
                       end
                     else
                       lNextCharLoaded:=true;
                   end
                 else
                   lFound := 0;
               end;
             '}' :
               begin
                 if (FCurrentCommentStyle=commentTP) then
                   begin
                     DecCommentLevel;
                     if (FCommentLevel=0) then
                       FCurrentCommentStyle:=commentNone;
                     lFound:=0;
                   end;
               end;
             '$' :
               begin
                 if lFound=1 then
                  lFound:=2;
               end;
             '''','`' :
               if (FCurrentCommentStyle=commentNone) then
                 begin
                   FHadMultilineString:=FInMultilineString;
                   FInMultilineString:=(FChar='`');
                   if FInMultilineString and (not (m_multiline_strings in CurrentSettings.ModeSwitches)) then
                     IllegalChar(FChar);
                   repeat
                     ReadChar;
                     case FChar of
                       #26 :
                         HandleEndOfFile;
                       #10,#13 :
                         if not FInMultilineString then
                           break;
                       '''' :
                         if not FInMultilineString then
                           begin
                             ReadChar;
                             if FChar<>'''' then
                              begin
                                lNextCharLoaded:=true;
                                break;
                              end;
                           end;
                       '`' :
                         if FInMultilineString then
                           begin
                             ReadChar;
                             if FChar<>'`' then
                              begin
                                lNextCharLoaded:=true;
                                break;
                              end;
                           end;
                     end;
                   until false;
                 end;
             '(' :
               begin
                 if (FCurrentCommentStyle=commentNone) then
                  begin
                    ReadChar;
                    if FChar='*' then
                     begin
                       ReadChar;
                       if FChar='$' then
                        begin
                          lFound:=2;
                          IncCommentLevel;
                          FCurrentCommentStyle:=commentOldTP;
                        end
                       else
                        begin
                          SkipOldTPComment(false);
                          lNextCharLoaded:=true;
                        end;
                     end
                    else
                     lNextCharLoaded:=true;
                  end
                 else
                  lFound:=0;
               end;
             '/' :
               begin
                 if (FCurrentCommentStyle=commentNone) then
                  begin
                    ReadChar;
                    if FChar='/' then
                     SkipDelphiComment;
                    lNextCharLoaded:=true;
                  end
                 else
                  lFound:=0;
               end;
             else
               lFound:=0;
           end;
           if lNextCharLoaded then
             lNextCharLoaded:=false
           else
             ReadChar;
         until (lFound=2);
      end;


{****************************************************************************
                             Comment Handling
****************************************************************************}

    procedure TScannerFile.SkipComment(AReadFirstChar:Boolean);
      begin
        FCurrentCommentStyle:=commentTP;
        if AReadFirstChar then
          ReadChar;
        IncCommentLevel;
      { handle compiler switches }
        if (FChar='$') then
         HandleDirectives;
      { handle_switches can dec comment_level,  }
        while (FCommentLevel>0) do
         begin
           case FChar of
            '{' :
              IncCommentLevel;
            '}' :
              DecCommentLevel;
            '*' :
              { in iso mode, comments opened by a curly bracket can be closed by asterisk, round bracket }
              if m_iso in CurrentSettings.ModeSwitches then
                begin
                  ReadChar;
                  if FChar=')' then
                    DecCommentLevel
                  else
                    continue;
                end;
            #10,#13 :
              LineBreak;
            #26 :
              begin
                Reload;
                if (FChar=#26) and not Assigned(FInputFile.next) then
                  HandleEndOfFile;
                continue;
              end;
           end;
           ReadChar;
         end;
        FCurrentCommentStyle:=commentNone;
      end;


    procedure TScannerFile.SkipDelphiComment;
      begin
        FCurrentCommentStyle:=commentDelphi;
        IncCommentLevel;
        ReadChar;
        { this is not supported }
        if FChar='$' then
          Message(scan_w_wrong_styled_switch);
        { skip comment }
        while not (FChar in [#10,#13,#26]) do
          ReadChar;
        DecCommentLevel;
        FCurrentCommentStyle:=commentNone;
      end;


    procedure TScannerFile.SkipOldTPComment(AReadFirstChar:Boolean);
      var
        lFound : LongInt;
      begin
        FCurrentCommentStyle:=commentOldTP;
        IncCommentLevel;
        { only load a char if last already processed,
          was cause of bug1634 PM }
        if AReadFirstChar then
          ReadChar;
      { this is now supported }
        if (FChar='$') then
         HandleDirectives;
      { skip comment }
        while (FCommentLevel>0) do
         begin
           lFound:=0;
           repeat
             case FChar of
               #26 :
                 begin
                   Reload;
                   if (FChar=#26) and not Assigned(FInputFile.next) then
                     HandleEndOfFile;
                   continue;
                 end;
               #10,#13 :
                 begin
                   if lFound=4 then
                    IncCommentLevel;
                   LineBreak;
                   lFound:=0;
                 end;
               '*' :
                 begin
                   if lFound=3 then
                    lFound:=4
                   else
                    begin
                      if lFound=4 then
                        IncCommentLevel;
                      lFound:=1;
                    end;
                 end;
               ')' :
                 begin
                   if lFound in [1,4] then
                    begin
                      DecCommentLevel;
                      if FCommentLevel=0 then
                       lFound:=2
                      else
                       lFound:=0;
                    end
                   else
                    lFound:=0;
                 end;
              '}' :
                { in iso mode, comments opened by asterisk, round bracket can be closed by a curly bracket }
                if m_iso in CurrentSettings.ModeSwitches then
                  begin
                    DecCommentLevel;
                    if FCommentLevel=0 then
                      lFound:=2
                    else
                      lFound:=0;
                  end;
               '(' :
                 begin
                   if lFound=4 then
                    IncCommentLevel;
                   lFound:=3;
                 end;
               else
                 begin
                   if lFound=4 then
                    IncCommentLevel;
                   lFound:=0;
                 end;
             end;
             ReadChar;
           until (lFound=2);
         end;
        FCurrentCommentStyle:=commentNone;
      end;

    procedure TScannerFile.PostProcessUTF8Multiline(ALength,AQuotePosition,AQuoteCount : Integer);
    var
      lMalformed : Boolean;
      lStart, lIndex,lStripColumn,lColumn,lNewLength : Integer;
      lCRLF : Boolean;
      lText : TCompilerWideString;
      lChar : TCompilerWideChar;
    begin
      lStripColumn:=AQuotePosition;
      lMalformed:=false;
      lNewLength:=0;
      lColumn:=0;
      lStart:=1;
      InitWideString(lText);
      { Strip initial cr/lf }
      Case CurrentSettings.LineEndingType of
        le_cr,le_lf : inc(lStart);
        le_crlf : inc(lStart,2);
        le_source :
          begin
          inc(lStart);
          if (GetCharWideString(FPatternW,1)=13) and (GetCharWideString(FPatternW,lStart)=10) then
            inc(lStart);
          end;
        le_platform : inc(lStart,length(TargetInfo.newline));
      end;
      { we don't need the last added quotes }
      dec(ALength,AQuoteCount-1);
      for lIndex:=lStart to ALength do
        begin
        lChar:=GetCharWideString(FPatternW,lIndex);
        inc(lColumn);
        if (lColumn>lStripColumn) or (lChar=10) or (lChar=13) then
          begin
          inc(lNewLength);
          ConcatWideStringChar(FPatternW,lChar);
          end
        else
          begin
          // if less spaces than in the last line, report error
          if not (lChar in [9,32,11]) then
            begin
            if not lMalformed then
              begin
              lMalformed:=true;
              message3(scan_e_improperly_indented_multiline_string,
                      ToStr(lStripColumn),
                      ToStr(FMultilineStartLine),
                      ToStr(FMultilineStartColumn));
              end;
            end;
          end;
        if (lChar=10) or (lChar=13) then
          lColumn:=0;
        end;
      // remove last CR/LF
      lChar:=GetCharWideString(lText,lNewLength);
      if (lChar=10) or (lChar=13) then
        begin
        Case CurrentSettings.LineEndingType of
          le_cr,le_lf : dec(lNewLength);
          le_crlf : dec(lNewLength,2);
          le_platform : dec(lNewLength,length(TargetInfo.newline));
          le_source :
            begin
            lCRLF:=GetCharWideString(lText,lNewLength)=10;
            dec(lNewLength);
            if lCRLF and (lNewLength>0) and (GetCharWideString(lText,lNewLength)=13) then
              dec(lNewLength);
            end;
        end;
        end;
      lText.len:=lNewLength;
      DoneWideString(FPatternW);
      FPatternW:=lText;
    end;

    procedure TScannerFile.PostProcessMultiline(ALength,AQuotePosition,AQuoteCount : Integer);

    var
      lMalformed : Boolean;
      lStart, lIndex,lStripColumn,lColumn,lNewLength : Integer;
      lCRLF : Boolean;
      lText : AnsiString;
      lChar : AnsiChar;
    begin
      lStripColumn:=AQuotePosition;
      lMalformed:=false;
      lNewLength:=0;
      SetLength(lText,ALength-AQuoteCount+1);
      lColumn:=0;
      lStart:=1;
      { Strip initial cr/lf }
      Case CurrentSettings.LineEndingType of
        le_cr,le_lf : inc(lStart);
        le_crlf : inc(lStart,2);
        le_platform : inc(lStart,length(TargetInfo.newline));
        le_source :
          begin
          inc(lStart);
          if (FCStringPattern[1]=#13) and (FCStringPattern[lStart]=#10) then
            inc(lStart);
          end;
      end;
      { we don't need the last added quotes }
      dec(ALength,AQuoteCount-1);
      for lIndex:=lStart to ALength do
        begin
        lChar:=FCStringPattern[lIndex];
        inc(lColumn);
        if (lColumn>lStripColumn) or (lChar in [#10,#13]) then
          begin
          inc(lNewLength);
          lText[lNewLength]:=lChar;
          end
        else
          begin
          // if less spaces than in the last line, report error
          if not (lChar in [#9,#32,#11]) then
            begin
            if not lMalformed then
              begin
              lMalformed:=true;
              message3(scan_e_improperly_indented_multiline_string,
                      ToStr(lStripColumn),
                      ToStr(FMultilineStartLine),
                      ToStr(FMultilineStartColumn));
              end;
            end;
          end;
        if lChar in [#10,#13] then
          lColumn:=0;
        end;
      // remove last CR/LF
      if lText[lNewLength] in [#10,#13] then
        begin
        Case CurrentSettings.LineEndingType of
          le_cr,le_lf : dec(lNewLength);
          le_crlf : dec(lNewLength,2);
          le_platform : dec(lNewLength,length(TargetInfo.newline));
          le_source :
              begin
              lCRLF:=lText[lNewLength]=#10;
              dec(lNewLength);
              if lCRLF and (lText[lNewLength]=#13) then
                Dec(lNewLength);
              end;

        end;
        end;
      SetLength(lText,lNewLength);
      FCStringPattern:=lText;
    end;


    function TScannerFile.ReadStringConstant : Boolean;

    type
       TQuoteStyle = (qsNone,qsBacktick,qsMultiQuote);

    var
      lTrimCount,lCharacterCode,lErrorCode,lLength,lQuoteCount,lInitialQuoteCount,lWhitespaceCount,lQuoteColumn : Integer;
      lStyle : TQuoteStyle;
      lIsWideString : Boolean;
      lASCIINumber : String[33];
      lLastChar : char;
      lWhitespaceOnly, lHadNewline, lFirstMultiline, lBacktick : Boolean;
      lCodePoint : Cardinal;
      lCodeUnit : Word;

    label
      QuoteLabel;
    begin
      lLastChar :=#0;
      lTrimCount:=0;
      lQuoteColumn:=0;
      lWhitespaceCount:=0;
      lInitialQuoteCount:=0;
      lHadNewline:=false;
      lFirstMultiline:=false;
      FHadMultilineString:=false;
      lBacktick:=(FChar='`');
      if lBacktick then
        lStyle:=qsBacktick
      else
        lStyle:=qsNone;
      lWhitespaceOnly:=true;
      FInMultilineString:=lBacktick;
      lQuoteCount:=0;
      lWhitespaceOnly:=true;
      if FInMultilineString then
        begin
          if not (m_multiline_strings in CurrentSettings.ModeSwitches) then
            IllegalChar(FChar)
          else
            begin
              FMultilineStartLine:=CurrentFilePos.line;
              FMultilineStartColumn:=CurrentFilePos.column;
            end;
        end;
      lLength:=0;
      FCStringPattern:='';
      lIsWideString:=false;
      if FChar='^' then
       begin
         ReadChar;
         FChar:=upcase(FChar);
         if (Block_Type in [bt_type,bt_const_type,bt_var_type]) or
            (FLastToken=_ID) or (FLastToken=_NIL) or (FLastToken=_OPERATOR) or
            (FLastToken=_RKLAMMER) or (FLastToken=_RECKKLAMMER) or (FLastToken=_CARET) then
          begin
            FToken:=_CARET;
            exit(true);
          end
         else
          begin
            inc(lLength);
            SetLength(FCStringPattern,256);
            if FChar<#64 then
              FCStringPattern[lLength]:=chr(ord(FChar)+64)
            else
              FCStringPattern[lLength]:=chr(ord(FChar)-64);
            ReadChar;
          end;
       end;
      repeat
        case FChar of
          '#' :
            begin
              ReadChar; { read # }
              case FChar of
                '$':
                  begin
                    ReadChar; { read leading $ }
                    lASCIINumber:='$';
                    while (upcase(FChar) in ['A'..'F','0'..'9']) and (length(lASCIINumber)<=7) do
                      begin
                        lASCIINumber:=lASCIINumber+FChar;
                        ReadChar;
                      end;
                  end;
                '&':
                  begin
                    ReadChar; { read leading $ }
                    lASCIINumber:='&';
                    while (upcase(FChar) in ['0'..'7']) and (length(lASCIINumber)<=8) do
                      begin
                        lASCIINumber:=lASCIINumber+FChar;
                        ReadChar;
                      end;
                  end;
                '%':
                  begin
                    ReadChar; { read leading $ }
                    lASCIINumber:='%';
                    while (upcase(FChar) in ['0','1']) and (length(lASCIINumber)<=22) do
                      begin
                        lASCIINumber:=lASCIINumber+FChar;
                        ReadChar;
                      end;
                  end;
                else
                  begin
                    lASCIINumber:='';
                    while (FChar in ['0'..'9']) and (length(lASCIINumber)<=8) do
                      begin
                        lASCIINumber:=lASCIINumber+FChar;
                        ReadChar;
                      end;
                  end;
              end;
              val(lASCIINumber,lCharacterCode,lErrorCode);
              if (lASCIINumber='') or (lErrorCode<>0) then
                Message(scan_e_illegal_char_const)
              else if (lCharacterCode<0) or (lCharacterCode>255) or (length(lASCIINumber)>3) then
                begin
                   if (lCharacterCode>=0) and (lCharacterCode<=$10FFFF) then
                     begin
                       if not lIsWideString then
                        begin
                          if lLength>0 then
                            ASCII2Unicode(@FCStringPattern[1],lLength,CurrentSettings.SourceCodePage,FPatternW)
                          else
                            ASCII2Unicode(nil,lLength,CurrentSettings.SourceCodePage,FPatternW);
                          lIsWideString:=true;
                          lLength:=0;
                        end;
                       if lCharacterCode<=$FFFF then
                         ConcatWideStringChar(FPatternW,TCompilerWideChar(lCharacterCode))
                       else
                         begin
                           { split into surrogate pair }
                           dec(lCharacterCode,$10000);
                           ConcatWideStringChar(FPatternW,TCompilerWideChar((lCharacterCode shr 10) + $D800));
                           ConcatWideStringChar(FPatternW,TCompilerWideChar((lCharacterCode and $3FF) + $DC00));
                         end;
                     end
                   else
                     Message(scan_e_illegal_char_const)
                end
              else if lIsWideString then
                ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(char(lCharacterCode)))
              else
                begin
                  if lLength>=length(FCStringPattern) then
                    SetLength(FCStringPattern,length(FCStringPattern)+256);
                  inc(lLength);
                  FCStringPattern[lLength]:=chr(lCharacterCode);
                end;
            end;
          '''','`' :
            begin
              if FChar='''' then
                inc(lQuoteCount);
              FHadMultilineString:=FInMultilineString;
              if lStyle<>qsMultiQuote then
                begin
                  FInMultilineString:=(FChar='`');
                  if FInMultilineString then
                    begin
                      lBacktick:=true;
                      lStyle:=qsBacktick;
                      FMultilineStartLine:=CurrentFilePos.line;
                      FMultilineStartColumn:=CurrentFilePos.column;
                    end
                  else
                    lStyle:=qsNone;
                  lFirstMultiline:=FInMultilineString and (lLastChar in [#0,#32,#61]);
                end;
              repeat
                ReadChar;
                QuoteLabel:
                  case FChar of
                    #26 :
                      HandleEndOfFile;
                    #32,#9,#11 :
                      begin
                      inc(lWhitespaceCount);
                      if (lHadNewline or lFirstMultiline) and lBacktick and
                         (CurrentSettings.WhitespaceTrimAuto or
                         (CurrentSettings.WhitespaceTrimCount>0)) then
                        begin
                          if CurrentSettings.WhitespaceTrimAuto then
                            lTrimCount:=FMultilineStartColumn
                          else
                            lTrimCount:=CurrentSettings.WhitespaceTrimCount;
                          while (FChar in [#32,#9,#11]) and (lTrimCount>0) do
                            begin
                              ReadChar;
                              dec(lTrimCount);
                            end;
                          lHadNewline:=false;
                          lFirstMultiline:=false;
                          goto QuoteLabel;
                        end;
                      end;
                    #10,#13 :
                      begin
                      lWhitespaceOnly:=true;
                      lWhitespaceCount:=0;
                      if not FInMultilineString then
                        begin
                          if FHadMultilineString then
                            Message2(scan_f_unterminated_multiline_string,
                                     ToStr(FMultilineStartLine),
                                     ToStr(FMultilineStartColumn))
                          else if (not lBacktick)
                                   and ((lQuoteCount>2) and ((lQuoteCount mod 2)=1))
                                   and (m_multiline_strings in CurrentSettings.ModeSwitches) then
                            begin
                            lStyle:=qsMultiQuote;
                            lInitialQuoteCount:=lQuoteCount;
                            FMultilineStartLine:=CurrentFilePos.line;
                            FMultilineStartColumn:=CurrentFilePos.column;
                            FInMultilineString:=true;
                            FHadMultilineString:=true;
                            lTrimCount:=0;
                            lQuoteCount:=0;
                            lLength:=0;
                            if FChar=#13 then
                              begin
                              ReadChar;
                              if FChar<>#10 then
                                goto QuoteLabel;
                              end;
                            end
                          else
                            Message(scan_f_string_exceeds_line);
                        end;
                      end;
                    '''' :
                      begin
                      inc(lQuoteCount);
                      if not FInMultilineString then
                        begin
                          ReadChar;
                          if FChar='''' then
                            inc(lQuoteCount)
                          else
                            break;
                        end
                      else if not lBacktick then
                        if lWhitespaceOnly and (lQuoteCount=lInitialQuoteCount) then
                          begin
                          FInMultilineString:=false;
                          lQuoteColumn:=lWhitespaceCount;
                          ReadChar;
                          break;
                          end;
                      end;
                    '`' :
                      if FInMultilineString and (lStyle=qsBacktick) then
                        begin
                          ReadChar;
                          if FChar<>'`' then
                           break;
                        lWhitespaceOnly:=false;
                        end;
                    else
                      lWhitespaceOnly:=false;
                      lQuoteCount:=0;
                    end;
                lFirstMultiline:=false;
                { interpret as utf-8 string? }
                if (ord(FChar)>=$80) and (CurrentSettings.SourceCodePage=CP_UTF8) then
                  begin
                    { convert existing string to an utf-8 string }
                    if not lIsWideString then
                      begin
                        if lLength>0 then
                          ASCII2Unicode(@FCStringPattern[1],lLength,CurrentSettings.SourceCodePage,FPatternW)
                        else
                          ASCII2Unicode(nil,lLength,CurrentSettings.SourceCodePage,FPatternW);
                        lIsWideString:=true;
                        lLength:=0;
                      end;
                    { four chars }
                    if (ord(FChar) and $f0)=$f0 then
                      begin
                        { this always represents a surrogate pair, so
                          read as 32-bit value and then split into
                          the corresponding pair of two wchars }
                        lCodePoint:=ord(FChar) and $f;
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodePoint:=(lCodePoint shl 6) or (ord(FChar) and $3f);
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodePoint:=(lCodePoint shl 6) or (ord(FChar) and $3f);
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodePoint:=(lCodePoint shl 6) or (ord(FChar) and $3f);
                        if lCodePoint<$10000 then
                          message(scan_e_utf8_malformed);
                        lCodePoint:=lCodePoint-$10000;
                        { high surrogate }
                        lCodeUnit:=$d800+(lCodePoint shr 10);
                        ConcatWideStringChar(FPatternW,lCodeUnit);
                        { low surrogate }
                        lCodeUnit:=$dc00+(lCodePoint and $3ff);
                        ConcatWideStringChar(FPatternW,lCodeUnit);
                      end
                    { three chars }
                    else if (ord(FChar) and $e0)=$e0 then
                      begin
                        lCodeUnit:=ord(FChar) and $f;
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodeUnit:=(lCodeUnit shl 6) or (ord(FChar) and $3f);
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodeUnit:=(lCodeUnit shl 6) or (ord(FChar) and $3f);
                        ConcatWideStringChar(FPatternW,lCodeUnit);
                      end
                    { two chars }
                    else if (ord(FChar) and $c0)<>0 then
                      begin
                        lCodeUnit:=ord(FChar) and $1f;
                        ReadChar;
                        if (ord(FChar) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        lCodeUnit:=(lCodeUnit shl 6) or (ord(FChar) and $3f);
                        ConcatWideStringChar(FPatternW,lCodeUnit);
                      end
                    { illegal }
                    else if (ord(FChar) and $80)<>0 then
                      message(scan_e_utf8_malformed)
                    else
                      ConcatWideStringChar(FPatternW,TCompilerWideChar(FChar))
                  end
                else if lIsWideString then
                  begin
                    if FInMultilineString and (FChar in [#10,#13]) and (not ((FChar=#10) and (lLastChar=#13))) then
                      begin
                        if CurrentSettings.SourceCodePage=CP_UTF8 then
                          begin
                            case CurrentSettings.LineEndingType of
                              le_cr :
                                ConcatWideStringChar(FPatternW,ord(#13));
                              le_crlf :
                                begin
                                  ConcatWideStringChar(FPatternW,ord(#13));
                                  ConcatWideStringChar(FPatternW,ord(#10));
                                end;
                              le_lf :
                                ConcatWideStringChar(FPatternW,ord(#10));
                              le_platform :
                                begin
                                  if TargetInfo.newline=#13 then
                                    ConcatWideStringChar(FPatternW,ord(#13))
                                  else if TargetInfo.newline=#13#10 then
                                    begin
                                      ConcatWideStringChar(FPatternW,ord(#13));
                                      ConcatWideStringChar(FPatternW,ord(#10));
                                    end
                                  else if TargetInfo.newline=#10 then
                                    ConcatWideStringChar(FPatternW,ord(#10));
                                end;
                              le_source :
                                ConcatWideStringChar(FPatternW,ord(FChar));
                            end;
                          end
                        else
                          case CurrentSettings.LineEndingType of
                            le_cr :
                              ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#13));
                            le_crlf :
                              begin
                                ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#13));
                                ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#10));
                              end;
                            le_lf :
                              ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#10));
                            le_platform :
                              begin
                                if TargetInfo.newline=#13 then
                                  ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#13))
                                else if TargetInfo.newline=#13#10 then
                                  begin
                                    ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#13));
                                    ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#10));
                                  end
                                else if TargetInfo.newline=#10 then
                                  ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(#10));
                              end;
                            le_source :
                              ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(FChar));
                          end;
                        lHadNewline:=true;
                        inc(FLineNumber);
                      end
                    else if not (FInMultilineString and (FChar in [#10,#13])) then
                      begin
                        if CurrentSettings.SourceCodePage=CP_UTF8 then
                          ConcatWideStringChar(FPatternW,ord(FChar))
                        else
                          ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(FChar));
                      end;
                  end
                else
                  begin
                     if FInMultilineString and (FChar in [#10,#13]) and (not ((FChar=#10) and (lLastChar=#13))) then
                       begin
                         if lLength>=length(FCStringPattern) then
                           SetLength(FCStringPattern,length(FCStringPattern)+256);
                         inc(lLength);
                         case CurrentSettings.LineEndingType of
                           le_cr :
                             FCStringPattern[lLength]:=#13;
                           le_crlf :
                             begin
                               FCStringPattern[lLength]:=#13;
                               inc(lLength);
                               FCStringPattern[lLength]:=#10;
                             end;
                           le_lf :
                             FCStringPattern[lLength]:=#10;
                           le_platform :
                             begin
                               if TargetInfo.newline=#13 then
                                 FCStringPattern[lLength]:=#13
                               else if TargetInfo.newline=#13#10 then
                                 begin
                                   FCStringPattern[lLength]:=#13;
                                   inc(lLength);
                                   FCStringPattern[lLength]:=#10;
                                 end
                               else if TargetInfo.newline=#10 then
                                 FCStringPattern[lLength]:=#10;
                             end;
                           le_source :
                             FCStringPattern[lLength]:=FChar;
                         end;
                         lHadNewline:=true;
                         inc(FLineNumber);
                       end
                     else if not (FInMultilineString and (FChar in [#10,#13])) then
                       begin
                         if lLength>=length(FCStringPattern) then
                           SetLength(FCStringPattern,length(FCStringPattern)+256);
                         inc(lLength);
                         FCStringPattern[lLength]:=FChar;
                       end;
                  end;
              lLastChar:=FChar;
              until false;
            end;
          '^' :
            begin
              ReadChar;
              FChar:=upcase(FChar);
              if FChar<#64 then
               FChar:=chr(ord(FChar)+64)
              else
               FChar:=chr(ord(FChar)-64);

              if lIsWideString then
                ConcatWideStringChar(FPatternW,ASCIIChar2Unicode(FChar))
              else
                begin
                  if lLength>=length(FCStringPattern) then
                    SetLength(FCStringPattern,length(FCStringPattern)+256);
                   inc(lLength);
                   FCStringPattern[lLength]:=FChar;
                end;

              ReadChar;
            end;
          else
           break;
        end;
      lLastChar:=FChar;
      until false;

      { strings with length 1 become const chars }
      if lIsWideString then
        begin
          if FHadMultilineString and not lBacktick then
            begin
            PostProcessUTF8Multiline(lLength,lQuoteColumn,lInitialQuoteCount);
            end;
          if FPatternW.len=1 then
            FToken:=_CWCHAR
          else
            FToken:=_CWSTRING;
        end
      else
        begin
          if FHadMultilineString and not lBacktick then
            begin
            PostProcessMultiline(lLength,lQuoteColumn,lInitialQuoteCount);
            end
          else
            SetLength(FCStringPattern,lLength);
          if length(FCStringPattern)=1 then
            begin
              FToken:=_CCHAR;
              FPattern:=FCStringPattern;
            end
          else
            FToken:=_CSTRING;
        end;
      FHadMultilineString:=False;
      exit(true);
    end;

{****************************************************************************
                               Token Scanner
****************************************************************************}

    procedure TScannerFile.ReadToken(AAllowRecordToken:Boolean);
      var
        lLow,lHigh,lMid : LongInt;
        lMacro     : TMacro;
        lFirstDigitRead: Boolean;
        lHadNewline,lFirstMultiline : Boolean;
        lTrimCount : Word;
       label
         ExitLabel;
      begin
        lHadNewline:=false;
        lFirstMultiline:=false;
        FlushPendingSwitchesState;

        { record tokens? }
        if AAllowRecordToken and
           Assigned(FRecordTokenBuf) then
          RecordToken;

        { replay tokens? }
        if Assigned(FReplayTokenBuf) then
          begin
            ReplayToken;
            goto ExitLabel;
          end;

      { was there already a token read, then return that token }
        if FNextToken<>NOTOKEN then
         begin
           SetNextToken;
           goto ExitLabel;
         end;

      { Skip all spaces and comments }
        repeat
          case FChar of
            '{' :
              SkipComment(true);
            #26 :
              begin
                Reload;
                if (FChar=#26) and not Assigned(FInputFile.next) then
                  break;
              end;
            ' ',#9..#13 :
              begin
                SkipSpace;
              end
            else
              break;
          end;
        until false;

      { Save current token position, for EOF its already loaded }
        if FChar<>#26 then
          GetTokenPos;

      { Check first for a identifier/keyword, this is 20+% faster (PFV) }
        if FChar in ['A'..'Z','a'..'z','_'] then
         begin
           ReadString;
           FToken:=_ID;
           FIDToken:=_ID;
         { keyword or any other known token,
           pattern is always uppercased }
           if (FPattern[1]<>'_') and (length(FPattern) in [tokenlenmin..tokenlenmax]) then
            begin
              lLow:=ord(tokenidx^[length(FPattern),FPattern[1]].first);
              lHigh:=ord(tokenidx^[length(FPattern),FPattern[1]].last);
              while lLow<lHigh do
               begin
                 lMid:=(lHigh+lLow+1) shr 1;
                 if FPattern<tokeninfo^[TToken(lMid)].str then
                  lHigh:=lMid-1
                 else
                  lLow:=lMid;
               end;
              with tokeninfo^[TToken(lHigh)] do
                if FPattern=str then
                  begin
                    if (keyword*CurrentSettings.ModeSwitches)<>[] then
                      if op=NOTOKEN then
                        FToken:=TToken(lHigh)
                      else
                        FToken:=op;
                    FIDToken:=TToken(lHigh);
                  end;
            end;
         { Only process identifiers and not keywords }
           if FToken=_ID then
            begin
            { this takes some time ... }
              if (cs_support_macro in CurrentSettings.ModuleSwitches) then
               begin
                 lMacro:=TMacro(Search_Macro(FPattern));
                 if Assigned(lMacro) and (not lMacro.IsCompilerVar) and lMacro.IsCMacro then
                  begin
                    if (FYYLexCount<cMaxMacroNesting) and (FMacroNestingDepth<cMaxMacroNesting) then
                     begin
                       lMacro.IsUsed:=true;
                       inc(FYYLexCount);
                       SubstituteMacro(FPattern,pchar(lMacro.BufText),lMacro.BufLen,
                         lMacro.fileinfo.line,lMacro.fileinfo.fileindex,false);
                       { handle empty macros }
                       if FChar=#0 then
                         begin
                           Reload;
                           { avoid macro nesting error in case of
                             a sequence of empty macros, see #38802 }
                           dec(FYYLexCount);
                           ReadToken(false);
                         end
                       else
                         begin
                           ReadToken(false);
                           { that's all folks }
                           dec(FYYLexCount);
                         end;
                       exit;
                     end
                    else
                     Message(scan_w_macro_too_deep);
                  end;
               end;
            end;
         { return token }
           goto ExitLabel;
         end
        else
         begin
           FIDToken:=_NOID;
           case FChar of

             '$' :
               begin
                 ReadNumber;
                 FToken:=_INTCONST;
                 goto ExitLabel;
               end;

             '%' :
               begin
                 if [m_fpc,m_delphi] * CurrentSettings.ModeSwitches = [] then
                  IllegalChar(FChar)
                 else
                  begin
                    ReadNumber;
                    FToken:=_INTCONST;
                    goto ExitLabel;
                  end;
               end;

             '&' :
               begin
                 if [m_fpc,m_delphi] * CurrentSettings.ModeSwitches <> [] then
                  begin
                    ReadNumber;
                    if length(FPattern)=1 then
                      begin
                        { does really an identifier follow? }
                        if not (FChar in ['_','A'..'Z','a'..'z']) then
                          message2(scan_f_syn_expected,tokeninfo^[_ID].str,FChar);
                        ReadString;
                        FToken:=_ID;
                        FIDToken:=_ID;
                      end
                    else
                      FToken:=_INTCONST;
                    goto ExitLabel;
                  end
                 else if m_mac in CurrentSettings.ModeSwitches then
                  begin
                    ReadChar;
                    FToken:=_AMPERSAND;
                    goto ExitLabel;
                  end
                 else
                  IllegalChar(FChar);
               end;

             '0'..'9' :
               begin
                 ReadNumber;
                 if (FChar in ['.','e','E']) then
                  begin
                  { first check for a . }
                    if FChar='.' then
                     begin
                       CacheNextTokenPos;
                       ReadChar;
                       { is it a .. from a range? }
                       case FChar of
                         '.' :
                           begin
                             ReadChar;
                             FToken:=_INTCONST;
                             FNextToken:=_POINTPOINT;
                             goto ExitLabel;
                           end;
                         ')' :
                           begin
                             ReadChar;
                             FToken:=_INTCONST;
                             FNextToken:=_RECKKLAMMER;
                             goto ExitLabel;
                           end;
                         '0'..'9' :
                           begin
                             { insert the number after the . }
                             FPattern:=FPattern+'.';
                             lFirstDigitRead:=false;
                             while (FChar in ['0'..'9']) or
                              ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and lFirstDigitRead and (FChar='_')) do
                              begin
                                if FChar<>'_' then
                                  FPattern:=FPattern+FChar;
                                ReadChar;
                                lFirstDigitRead:=true;
                              end;
                           end;
                         else
                           begin
                             FToken:=_INTCONST;
                             FNextToken:=_POINT;
                             goto ExitLabel;
                           end;
                       end;
                      end;
                  { E can also follow after a point is scanned }
                    if FChar in ['e','E'] then
                     begin
                       FPattern:=FPattern+'E';
                       ReadChar;
                       if FChar in ['-','+'] then
                        begin
                          FPattern:=FPattern+FChar;
                          ReadChar;
                        end;
                       if not(FChar in ['0'..'9']) then
                         IllegalChar(FChar);
                       lFirstDigitRead:=false;
                       while (FChar in ['0'..'9']) or
                        ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and lFirstDigitRead and (FChar='_')) do
                        begin
                          if FChar<>'_' then
                          FPattern:=FPattern+FChar;
                          ReadChar;
                          lFirstDigitRead:=true;
                        end;
                     end;
                    FToken:=_REALNUMBER;
                    goto ExitLabel;
                  end;
                 FToken:=_INTCONST;
                 goto ExitLabel;
               end;

             ';' :
               begin
                 ReadChar;
                 FToken:=_SEMICOLON;
                 goto ExitLabel;
               end;

             '[' :
               begin
                 ReadChar;
                 FToken:=_LECKKLAMMER;
                 goto ExitLabel;
               end;

             ']' :
               begin
                 ReadChar;
                 FToken:=_RECKKLAMMER;
                 goto ExitLabel;
               end;

             '(' :
               begin
                 ReadChar;
                 case FChar of
                   '*' :
                     begin
                       SkipOldTPComment(true);
                       ReadToken(false);
                       exit;
                     end;
                   '.' :
                     begin
                       ReadChar;
                       FToken:=_LECKKLAMMER;
                       goto ExitLabel;
                     end;
                 end;
                 FToken:=_LKLAMMER;
                 goto ExitLabel;
               end;

             ')' :
               begin
                 ReadChar;
                 FToken:=_RKLAMMER;
                 goto ExitLabel;
               end;

             '+' :
               begin
                 ReadChar;
                 if FChar='=' then
                  begin
                    ReadChar;
                    FToken:=_PLUSASN;
                    goto ExitLabel;
                  end;
                 FToken:=_PLUS;
                 goto ExitLabel;
               end;

             '-' :
               begin
                 ReadChar;
                 if FChar='=' then
                  begin
                    ReadChar;
                    FToken:=_MINUSASN;
                    goto ExitLabel;
                  end;
                 FToken:=_MINUS;
                 goto ExitLabel;
               end;

             ':' :
               begin
                 ReadChar;
                 if FChar='=' then
                  begin
                    ReadChar;
                    FToken:=_ASSIGNMENT;
                    goto ExitLabel;
                  end;
                 FToken:=_COLON;
                 goto ExitLabel;
               end;

             '*' :
               begin
                 ReadChar;
                 if FChar='=' then
                  begin
                    ReadChar;
                    FToken:=_STARASN;
                  end
                 else
                  if FChar='*' then
                   begin
                     ReadChar;
                     FToken:=_STARSTAR;
                   end
                 else
                  FToken:=_STAR;
                 goto ExitLabel;
               end;

             '/' :
               begin
                 ReadChar;
                 case FChar of
                   '=' :
                     begin
                       ReadChar;
                       FToken:=_SLASHASN;
                       goto ExitLabel;
                     end;
                   '/' :
                     begin
                       SkipDelphiComment;
                       ReadToken(false);
                       exit;
                     end;
                 end;
                 FToken:=_SLASH;
                 goto ExitLabel;
               end;

             '|' :
               if m_mac in CurrentSettings.ModeSwitches then
                begin
                  ReadChar;
                  FToken:=_PIPE;
                  goto ExitLabel;
                end
               else
                IllegalChar(FChar);

             '=' :
               begin
                 ReadChar;
                 FToken:=_EQ;
                 goto ExitLabel;
               end;

             '.' :
               begin
                 ReadChar;
                 case FChar of
                   '.' :
                     begin
                       ReadChar;
                       case FChar of
                         '.' :
                         begin
                           ReadChar;
                           FToken:=_POINTPOINTPOINT;
                           goto ExitLabel;
                         end;
                       else
                         begin
                           FToken:=_POINTPOINT;
                           goto ExitLabel;
                         end;
                       end;
                     end;
                   ')' :
                     begin
                       ReadChar;
                       FToken:=_RECKKLAMMER;
                       goto ExitLabel;
                     end;
                 end;
                 FToken:=_POINT;
                 goto ExitLabel;
               end;

             '@' :
               begin
                 ReadChar;
                 FToken:=_KLAMMERAFFE;
                 goto ExitLabel;
               end;

             ',' :
               begin
                 ReadChar;
                 FToken:=_COMMA;
                 goto ExitLabel;
               end;

             '''','#','^','`' :
               begin
                 ReadStringConstant;
                 goto ExitLabel;
               end;
             '>' :
               begin
                 ReadChar;
                 if (Block_Type in [bt_type,bt_var_type,bt_const_type]) then
                   FToken:=_RSHARPBRACKET
                 else
                   begin
                     case FChar of
                       '=' :
                         begin
                           ReadChar;
                           FToken:=_GTE;
                           goto ExitLabel;
                         end;
                       '>' :
                         begin
                           ReadChar;
                           FToken:=_OP_SHR;
                           goto ExitLabel;
                         end;
                       '<' :
                         begin { >< is for a symetric diff for sets }
                           ReadChar;
                           FToken:=_SYMDIF;
                           goto ExitLabel;
                         end;
                     end;
                     FToken:=_GT;
                   end;
                 goto ExitLabel;
               end;

             '<' :
               begin
                 ReadChar;
                 if (Block_Type in [bt_type,bt_var_type,bt_const_type]) then
                   FToken:=_LSHARPBRACKET
                 else
                   begin
                     case FChar of
                       '>' :
                         begin
                           ReadChar;
                           FToken:=_NE;
                           goto ExitLabel;
                         end;
                       '=' :
                         begin
                           ReadChar;
                           FToken:=_LTE;
                           goto ExitLabel;
                         end;
                       '<' :
                         begin
                           ReadChar;
                           FToken:=_OP_SHL;
                           goto ExitLabel;
                         end;
                     end;
                     FToken:=_LT;
                   end;
                 goto ExitLabel;
               end;

             #26 :
               begin
                 FToken:=_EOF;
                 CheckPreProcStack;
                 goto ExitLabel;
               end;
             else if FInputFile.InternallyGeneratedMacro and
                     (FChar in [cInternalMacroEscapeBegin..cInternalMacroEscapeEnd]) then
               begin
                 FToken:=_ID;
                 ReadString;
               end
             else
               IllegalChar(FChar);
           end;
        end;
ExitLabel:
        FLastToken:=FToken;
      end;


    function TScannerFile.ReadPreProc:TToken;
      var
        lLow,lHigh,lMid: LongInt;
        lOpToken: TToken;
      begin
         { Added the assignment to NOTOKEN below because I got a DFA uninitialized result
           warning when building the compiler with -O3, which broke compilation with -Sew.
           - Akira1364 }
         ReadPreProc:=NOTOKEN;
         SkipSpace;
         case FChar of
           '_',
           'A'..'Z',
           'a'..'z' :
             begin
               ReadString;
               lOpToken:=_ID;
               if (FPattern[1]<>'_') and (length(FPattern) in [tokenlenmin..tokenlenmax]) then
                begin
                  lLow:=ord(tokenidx^[length(FPattern),FPattern[1]].first);
                  lHigh:=ord(tokenidx^[length(FPattern),FPattern[1]].last);
                  while lLow<lHigh do
                   begin
                     lMid:=(lHigh+lLow+1) shr 1;
                     if FPattern<tokeninfo^[TToken(lMid)].str then
                      lHigh:=lMid-1
                     else
                      lLow:=lMid;
                   end;
                  with tokeninfo^[TToken(lHigh)] do
                    if FPattern=str then
                      begin
                        if (keyword*CurrentSettings.ModeSwitches)<>[] then
                          if op=NOTOKEN then
                            lOpToken:=TToken(lHigh)
                          else
                            lOpToken:=op;
                      end;
                  if not (lOpToken in cPreProcOperators) then
                    lOpToken:=_ID;
                end;
               CurrentScanner.FPreProcPattern:=FPattern;
               ReadPreProc:=lOpToken;
             end;
           '''','`' :
             if not ((FChar='`') and (not (m_multiline_strings in CurrentSettings.ModeSwitches))) then
               begin
                 FCStringPattern:=ReadQuotedString;
                 CurrentScanner.FPreProcPattern:=FCStringPattern;
                 ReadPreProc:=_CSTRING;
               end;
           '0'..'9' :
             begin
               ReadNumber;
               if (FChar in ['.','e','E']) then
                 begin
                   { first check for a . }
                   if FChar='.' then
                     begin
                       ReadChar;
                       if FChar in ['0'..'9'] then
                         begin
                           { insert the number after the . }
                           FPattern:=FPattern+'.';
                           while FChar in ['0'..'9'] do
                             begin
                               FPattern:=FPattern+FChar;
                               ReadChar;
                             end;
                         end
                       else
                         IllegalChar(FChar);
                     end;
                  { E can also follow after a point is scanned }
                   if FChar in ['e','E'] then
                     begin
                       FPattern:=FPattern+'E';
                       ReadChar;
                       if FChar in ['-','+'] then
                         begin
                           FPattern:=FPattern+FChar;
                           ReadChar;
                         end;
                       if not(FChar in ['0'..'9']) then
                         IllegalChar(FChar);
                       while FChar in ['0'..'9'] do
                         begin
                           FPattern:=FPattern+FChar;
                           ReadChar;
                         end;
                     end;
                   ReadPreProc:=_REALNUMBER;
                 end
               else
                 ReadPreProc:=_INTCONST;
               CurrentScanner.FPreProcPattern:=FPattern;
             end;
           '$','%':
             begin
               ReadNumber;
               CurrentScanner.FPreProcPattern:=FPattern;
               ReadPreProc:=_INTCONST;
             end;
           '&' :
             begin
                ReadNumber;
                if length(FPattern)=1 then
                  begin
                    ReadString;
                    ReadPreProc:=_ID;
                  end
                else
                  ReadPreProc:=_INTCONST;
               CurrentScanner.FPreProcPattern:=FPattern;
             end;
           '.' :
             begin
               ReadChar;
               ReadPreProc:=_POINT;
             end;
           ',' :
             begin
               ReadChar;
               ReadPreProc:=_COMMA;
             end;
           '}' :
             begin
               ReadPreProc:=_END;
             end;
           '(' :
             begin
               ReadChar;
               ReadPreProc:=_LKLAMMER;
             end;
           ')' :
             begin
               ReadChar;
               ReadPreProc:=_RKLAMMER;
             end;
           '[' :
             begin
               ReadChar;
               ReadPreProc:=_LECKKLAMMER;
             end;
           ']' :
             begin
               ReadChar;
               ReadPreProc:=_RECKKLAMMER;
             end;
           '+' :
             begin
               ReadChar;
               ReadPreProc:=_PLUS;
             end;
           '-' :
             begin
               ReadChar;
               ReadPreProc:=_MINUS;
             end;
           '*' :
             begin
               ReadChar;
               ReadPreProc:=_STAR;
             end;
           '/' :
             begin
               ReadChar;
               ReadPreProc:=_SLASH;
             end;
           '=' :
             begin
               ReadChar;
               ReadPreProc:=_EQ;
             end;
           '>' :
             begin
               ReadChar;
               if FChar='=' then
                 begin
                   ReadChar;
                   ReadPreProc:=_GTE;
                 end
               else
                 ReadPreProc:=_GT;
             end;
           '<' :
             begin
               ReadChar;
               case FChar of
                 '>' :
                   begin
                     ReadChar;
                     ReadPreProc:=_NE;
                   end;
                 '=' :
                   begin
                     ReadChar;
                     ReadPreProc:=_LTE;
                   end;
                 else
                   ReadPreProc:=_LT;
               end;
             end;
           #26 :
             begin
               ReadPreProc:=_EOF;
               CheckPreProcStack;
             end;
           else
             begin
               IllegalChar(FChar);
               ReadPreProc:=NOTOKEN;
             end;
         end;
      end;


    function TScannerFile.ReadPreProcInt(var AValue:int64;const APlace:String):Boolean;
      var
        lExpression : TExprValue;
      begin
        lExpression:=PreProcCompExpr(nil);
        if lExpression.IsInt then
          begin
            AValue:=lExpression.AsInt64;
            Result:=true;
          end
        else
          begin
            lExpression.Error('Integer',APlace);
            Result:=false;
          end;
        lExpression.free;
        lExpression := nil;
      end;


    function TScannerFile.ReadPreProcSet(AConformTo:TSetDef;var AValue:TNormalSet;const APlace:String):Boolean;
      var
        lExpression : TExprValue;
      begin
        lExpression:=PreProcCompExpr(AConformTo);
        if lExpression.FDef.typ=setdef then
          begin
            AValue:=lExpression.AsSet;
            Result:=true;
          end
        else
          begin
            lExpression.Error('Set',APlace);
            Result:=false;
          end;
        lExpression.free;
        lExpression := nil;
      end;


    function TScannerFile.AsmGetChar : Char;
      begin
         ReadChar;
         repeat
           case FChar of
             #26 :
               begin
                 Reload;
                 if (FChar=#26) and not Assigned(FInputFile.next) then
                   HandleEndOfFile;
                 continue;
               end;
             else
               begin
                 AsmGetChar:=FChar;
                 exit;
               end;
           end;
         until false;
      end;

{$ifdef EXTDEBUG}
    function TScannerFile.DumpPointer: String;
      var
        lIndex: Integer;

      begin
        Result:='';
        if FInputPointer=nil then exit;
        lIndex:=0;
        While (FInputPointer[lIndex]<>#0) and (lIndex<200) do
          inc(lIndex);
        SetLength(Result,lIndex);
        move(FInputPointer^,Result[1],lIndex);
        Result:='<'+IntToStr(FInputStart)+'>'+Result;
      end;
{$endif EXTDEBUG}

{*****************************************************************************
                                   Helpers
*****************************************************************************}

    procedure AddDirective(const AName:String; AMode: TDirectiveMode; AProc:TDirectiveProc);
      begin
        if AMode in [directiveAll, directiveTurbo] then
          TDirectiveItem.Create(TurboScannerDirectives,AName,AProc);
        if AMode in [directiveAll, directiveMac] then
          TDirectiveItem.Create(MacScannerDirectives,AName,AProc);
      end;

    procedure AddConditional(const AName:String; AMode: TDirectiveMode; AProc:TDirectiveProc);
      begin
        if AMode in [directiveAll, directiveTurbo] then
          TDirectiveItem.CreateCond(TurboScannerDirectives,AName,AProc);
        if AMode in [directiveAll, directiveMac] then
          TDirectiveItem.CreateCond(MacScannerDirectives,AName,AProc);
      end;

{*****************************************************************************
                                Initialization
*****************************************************************************}

    procedure InitScanner;
      begin
        TurboScannerDirectives:=TFPHashObjectList.Create;
        MacScannerDirectives:=TFPHashObjectList.Create;

        { Common directives and conditionals }
        AddDirective('I',directiveAll, @DirInclude);
        AddDirective('DEFINE',directiveAll, @DirDefine);
        AddDirective('UNDEF',directiveAll, @DirUndef);

        AddConditional('IF',directiveAll, @DirIf);
        AddConditional('IFDEF',directiveAll, @DirIfDef);
        AddConditional('IFNDEF',directiveAll, @DirIfNDef);
        AddConditional('ELSE',directiveAll, @DirElse);
        AddConditional('ELSEIF',directiveAll, @DirElseIf);
        AddConditional('ENDIF',directiveAll, @DirEndIf);

        { Directives and conditionals for all modes except mode macpas}
        AddDirective('INCLUDE',directiveTurbo, @DirInclude);
        AddDirective('LIBPREFIX',directiveTurbo, @DirLibPrefix);
        AddDirective('LIBSUFFIX',directiveTurbo, @DirLibSuffix);
        AddDirective('EXTENSION',directiveTurbo, @DirExtension);

        AddConditional('IFEND',directiveTurbo, @DirIfEnd);
        AddConditional('IFOPT',directiveTurbo, @DirIfOpt);

        { Directives and conditionals for mode macpas: }
        AddDirective('SETC',directiveMac, @DirSetC);
        AddDirective('DEFINEC',directiveMac, @DirDefineC);
        AddDirective('UNDEFC',directiveMac, @DirUndef);

        AddConditional('IFC',directiveMac, @DirIf);
        AddConditional('ELSEC',directiveMac, @DirElse);
        AddConditional('ELIFC',directiveMac, @DirElseIf);
        AddConditional('ENDC',directiveMac, @DirEndIf);
      end;


    procedure DoneScanner;
      begin
        TurboScannerDirectives.Free;
        TurboScannerDirectives := nil;
        MacScannerDirectives.Free;
        MacScannerDirectives := nil;
      end;

end.
