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
       max_include_nesting=32;
       max_macro_nesting=16;
       preprocbufsize=32*1024;

       { when parsing an internally generated macro, if an identifier is
         prefixed with this constant then it will always be interpreted as a
         unit name (to avoid clashes with user-specified parameter or field
         names duplicated in internally generated code) }
       internal_macro_escape_unit_namespace_name = #1;

       internal_macro_escape_begin = internal_macro_escape_unit_namespace_name;
       internal_macro_escape_end = internal_macro_escape_unit_namespace_name;


    type
       TCommentStyle = (comment_none,comment_tp,comment_oldtp,comment_delphi,comment_c);

       TScannerFile = class;

       TPreProcType = (pp_ifdef,pp_ifndef,pp_if,pp_ifopt,pp_else,pp_elseif);

       TPreProcStack = class
          typ,
          { stores the preproctyp of the last (else)if(ndef) directive
            so we can check properly for ifend when legacyifend is on }
          iftyp   : TPreProcType;
          accept  : boolean;
          next    : TPreProcStack;
          name    : TIDString;
          line_nb : LongInt;
          fileindex : LongInt;
          constructor Create(atyp:TPreProcType;a:boolean;n:TPreProcStack);
       end;

       TDirectiveProc=procedure;

       TDirectiveItem = class(TFPHashObject)
       public
          is_conditional : boolean;
          proc : TDirectiveProc;
          constructor Create(AList:TFPHashObjectList;const n:string;p:TDirectiveProc);
          constructor CreateCond(AList:TFPHashObjectList;const n:string;p:TDirectiveProc);
       end;

       // stack for replay buffers
       TReplayStack = class
         token    : TToken;
         idtoken  : TToken;
         orgpattern,
         pattern  : ShortString;
         cstringpattern: AnsiString;
         patternw : TCompilerWideString;
         settings : TSettings;
         tokenbuf : TDynamicArray;
         tokenbuf_needs_swapping : boolean;
         next     : TReplayStack;
         pending  : TPendingState;
         verbosity : LongInt;
         constructor Create(atoken: TToken;aidtoken:TToken;
           const aorgpattern,apattern:ShortString;const acstringpattern:AnsiString;
           apatternw:TCompilerWideString;asettings:TSettings;
           atokenbuf:TDynamicArray;ChangeEndian:boolean;const apending:TPendingState;
           averbosity:LongInt;anext:TReplayStack);
         destructor Destroy;override;
       end;

       TCompileTimePredicate = function(var valuedescr: String) : Boolean;

       TSpecialGenericToken =
         (ST_LOADSETTINGS,
          ST_LINE,
          ST_COLUMN,
          ST_FILEINDEX,
          ST_LOADMESSAGES);

       { tscannerfile }
       TScannerFile = class
       private
         procedure do_gettokenpos(out tokenpos: LongInt; out filepos: TFilePosInfo);
         procedure cachenexttokenpos;
         procedure postprocessmultiline(len, quote_pos, quote_count: integer);
         procedure postprocessutf8multiline(len, quote_pos, quote_count: integer);
         procedure setnexttoken;
         procedure savetokenpos;
         procedure restoretokenpos;
         procedure writetoken(t: TToken);
         function readtoken : TToken;
       public
          inputfile    : TInputFile;  { current inputfile list }
          inputfilecount : LongInt;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
       private
          hidden_inputbuffer,                { input buffer }
          hidden_inputpointer : pchar;
          { Gets char at inputpointer with offset,
            after checking that it doesn't overflow inputfile.bufsize }
          function get_inputpointer_char(offset : LongInt = 0) : char;
          procedure inc_inputpointer(amount : LongInt = 1);
          procedure dec_inputpointer;
       public
{$else not CHECK_INPUTPOINTER_LIMITS}
          inputbuffer,                { input buffer }
          inputpointer : pchar;
{$endif}
          inputstart   : LongInt;

          line_no,                    { line }
          lastlinepos  : LongInt;

          lasttokenpos,
          nexttokenpos : LongInt;     { token }
          lasttoken,
          nexttoken    : TToken;

          { read strings }
          c              : char;

          orgpattern,
          pattern        : ShortString;
          cstringpattern : AnsiString;
          patternw       : TCompilerWideString;

          { token }
          token,                        { current token being parsed }
          idtoken    : TToken;          { holds the token if the pattern is a known word }

          oldlasttokenpos     : LongInt; { temporary saving/restoring tokenpos }
          oldcurrent_filepos,
          oldcurrent_tokenpos : TFilePosInfo;

          replaytokenbuf,
          recordtokenbuf : TDynamicArray;

          { last settings we stored }
          last_settings : TSettings;
          last_message : PMessageStateRecord;
          { last filepos we stored }
          last_filepos,
          { if nexttoken<>NOTOKEN, then nexttokenpos holds its filepos }
          next_filepos   : TFilePosInfo;

          { current macro nesting depth }
          macro_nesting_depth,
          comment_level,
          yylexcount     : LongInt;
          ignoredirectives : TFPHashList; { ignore directives, used to give warnings only once }
          preprocstack   : TPreProcStack;
          replaystack    : TReplayStack;

          preproc_pattern : string;
          preproc_token   : TToken;

          { true, if we are parsing preprocessor expressions }
          in_preproc_comp_expr : boolean;
          { true if tokens must be converted to opposite endianess}
          change_endian_for_replay : boolean;
          { hack to allow reading generic generated identifiers IDs}
          allowgenericid : boolean;

          { Having these tracked in the scanner class itself versus local variables allows for
            informative error handling that would be impossible otherwise }
          in_multiline_string, had_multiline_string : boolean;
          multiline_start_line : LongInt;
          multiline_start_column : word;

          current_commentstyle : TCommentStyle; { needed to use read_comment from directives }

          constructor Create(const fn:string; IsMacro: boolean = false);
          destructor Destroy;override;
        { File buffer things }
          function  openinputfile:boolean;
          procedure closeinputfile;
          function  tempopeninputfile:boolean;
          procedure tempcloseinputfile;
          procedure saveinputfile;
          procedure restoreinputfile;
          procedure firstfile;
          procedure nextfile;
          procedure addfile(hp:TInputFile);
          procedure reload;
          { replaces current token with the text in p }
          procedure substitutemacro(const macname:string;p:pchar;len,line,fileindex:LongInt;internally_generated: boolean);
        { Scanner things }
          procedure gettokenpos;
          procedure inc_comment_level;
          procedure dec_comment_level;
          procedure illegal_char(ch:char);
          procedure end_of_file;
          procedure checkpreprocstack;
          procedure poppreprocstack;
          procedure ifpreprocstack(atyp:TPreProcType;compile_time_predicate:TCompileTimePredicate;messid:LongInt);
          procedure elseifpreprocstack(compile_time_predicate:TCompileTimePredicate);
          procedure elsepreprocstack;
          procedure popreplaystack;
          function replay_stack_depth:LongInt;
          procedure handleconditional(p:TDirectiveItem);
          procedure handledirectives;
          procedure linebreak;
          procedure recordtoken;
          procedure startrecordtokens(buf:TDynamicArray);
          procedure stoprecordtokens;
          function is_recording_tokens:boolean;
          procedure replaytoken;
          procedure startreplaytokens(buf:TDynamicArray; ChangeEndian:boolean);
          { bit length asizeint is target depend }
          procedure tokenwritesizeint(val : asizeint);
          procedure tokenwritelongint(val : LongInt);
          procedure tokenwritelongword(val : LongWord);
          procedure tokenwritebyte(val : byte);
          procedure tokenwriteword(val : word);
          procedure tokenwriteshortint(val : shortint);
          procedure tokenwriteset(var b;size : LongInt);
          procedure tokenwriteenum(var b;size : LongInt);
          function  tokenreadsizeint : asizeint;
          procedure tokenwritesettings(var asettings : TSettings; var size : asizeint);
          { longword/longint are 32 bits on all targets }
          { word/smallint are 16-bits on all targets }
          function  tokenreadlongword : LongWord;
          function  tokenreadword : word;
          function  tokenreadlongint : LongInt;
          function  tokenreadsmallint : smallint;
          { short int is one a signed byte }
          function  tokenreadshortint : shortint;
          function  tokenreadbyte : byte;
          { This one takes the set size as an parameter }
          procedure tokenreadset(var b;size : LongInt);
          function  tokenreadenum(size : LongInt) : LongWord;

          procedure tokenreadsettings(var asettings : TSettings; expected_size : asizeint);
          procedure readchar;
          procedure readstring;
          procedure readnumber;
          function  readid:string;
          function  readval:LongInt;
          function  readval64:int64;
          function  readcomment(include_special_char: boolean = false):ShortString;
          function  readquotedstring:ShortString;
          function  readlongcomment(include_special_char: boolean = false):RawByteString;
          function  readlongquotedstring:RawByteString;
          function readstringconstant: boolean;
          function  readstate:char;
          function  readoptionalstate(fallback:char):char;
          function  readstatedefault:char;
          procedure skipspace;
          procedure skipuntildirective;
          procedure skipcomment(read_first_char:boolean);
          procedure skipdelphicomment;
          procedure skipoldtpcomment(read_first_char:boolean);
          procedure readtoken(allowrecordtoken:boolean);
          function  readpreproc:TToken;
          function  readpreprocint(var value:int64;const place:string):boolean;
          function  readpreprocset(conform_to:TSetDef;var value:TNormalSet;const place:string):boolean;
          function  asmgetchar:char;
{$ifdef EXTDEBUG}
          function DumpPointer : string;
{$endif EXTDEBUG}
       end;

{$ifdef PREPROCWRITE}
       TPreProcFile=class
         f   : text;
         buf : TByteDynArray;
         spacefound,
         eolfound : boolean;
         constructor create(const fn:string);
         destructor  Destroy; override;
         procedure Add(const s:string);
         procedure AddSpace;
       end;
{$endif PREPROCWRITE}

{$ifdef PREPROCWRITE}
    var
        preprocfile     : TPreProcFile;  { used with only preprocessing }
{$endif PREPROCWRITE}

    type
        TDirectiveMode = (directive_all, directive_turbo, directive_mac);

    procedure AddDirective(const s:string; dm: TDirectiveMode; p:TDirectiveProc);
    procedure AddConditional(const s:string; dm: TDirectiveMode; p:TDirectiveProc);

    procedure InitScanner;
    procedure DoneScanner;

    function CurrentScanner : TScannerFile;  { current scanner in use }
    procedure Set_Current_Scanner(avalue : TScannerFile);  { current scanner in use }

    { To be called when the language mode is finally determined }
    Function SetCompileMode(const s:string; changeInit: boolean):boolean;
    Function SetCompileModeSwitch(s:string; changeInit: boolean):boolean;
    procedure SetAppType(NewAppType:TAppType);

    var
      OnFreeScanner : procedure(s : TScannerFile) = nil;

implementation

    uses
      SysUtils,
      CUtils,CFileUtl,
      Systems,
      Switches,
      SymBase,SymTable,symconst,defutil,defcmp,node,
      { This is needed for tcputype }
      CPUInfo,
      FModule,fppu,
      { this is needed for $I %CURRENTROUTINE%}
      ProcInfo;

    var
      { dictionaries with the supported directives }
      turbo_scannerdirectives : TFPHashObjectList;     { for other modes }
      mac_scannerdirectives   : TFPHashObjectList;     { for mode mac }
      {
        By default the current_scanner is current_module.scanner.
        set_current_scanner sets the _temp_scanner variable.
        If _temp_scanner is set, it is returned as the current scanner
      }
      _temp_scanner : TScannerFile;

      function CurrentScanner : TScannerFile;  { current scanner in use }

      begin
        Result:=_temp_scanner;
        if result<>nil then
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
      DirectiveIgnored=pointer(1);
      { use any special name that is an invalid file name to avoid problems }
      preprocstring : array [TPreProcType] of string[7]
        = ('$IFDEF','$IFNDEF','$IF','$IFOPT','$ELSE','$ELSEIF');

    function is_keyword(const s:string):boolean;
      var
        low,high,mid : LongInt;
      begin
        if not (length(s) in [tokenlenmin..tokenlenmax]) or
           not (s[1] in ['a'..'z','A'..'Z']) then
         begin
           is_keyword:=false;
           exit;
         end;
        low:=ord(tokenidx^[length(s),s[1]].first);
        high:=ord(tokenidx^[length(s),s[1]].last);
        while low<high do
         begin
           mid:=(high+low+1) shr 1;
           if CurrentScanner.pattern<tokeninfo^[TToken(mid)].str then
            high:=mid-1
           else
            low:=mid;
         end;
        is_keyword:=(CurrentScanner.pattern=tokeninfo^[TToken(high)].str) and
                    ((tokeninfo^[TToken(high)].keyword*CurrentSettings.ModeSwitches)<>[]);
      end;


    Procedure HandleModeSwitches(switch: TModeSwitch; changeInit: boolean);
      begin
        { The compiler invocation owns the default String/Char/PChar model.
          A source language mode may change grammar but cannot change it. }
        if switch in [m_none,m_default_ansistring,m_default_unicodestring] then
          begin
            if CompilerWide_Unicode_Strings then
              begin
                exclude(CurrentSettings.ModeSwitches,m_default_ansistring);
                include(CurrentSettings.ModeSwitches,m_default_unicodestring);
                def_system_macro('FPC_UNICODESTRINGS');
              end
            else
              begin
                exclude(CurrentSettings.ModeSwitches,m_default_unicodestring);
                include(CurrentSettings.ModeSwitches,m_default_ansistring);
                undef_system_macro('FPC_UNICODESTRINGS');
              end;
            include(CurrentSettings.LocalSwitches,cs_refcountedstrings);
            if changeinit then
              begin
                InitSettings.ModeSwitches:=CurrentSettings.ModeSwitches;
                include(InitSettings.LocalSwitches,cs_refcountedstrings);
              end;
          end;

        { turn inline on by default ? }
        if switch in [m_none,m_default_inline] then
          begin
            if (m_default_inline in CurrentSettings.ModeSwitches) then
             begin
               include(CurrentSettings.LocalSwitches,cs_do_inline);
               if changeinit then
                 include(InitSettings.LocalSwitches,cs_do_inline);
             end
            else
             begin
               exclude(CurrentSettings.LocalSwitches,cs_do_inline);
               if changeinit then
                 exclude(InitSettings.LocalSwitches,cs_do_inline);
             end;
          end;

        { turn on system codepage by default }
        if switch in [m_none,m_systemcodepage] then
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
                if changeinit then
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
                if changeinit then
                  begin
                    exclude(InitSettings.ModuleSwitches,cs_system_codepage);
                    if not(cs_explicit_codepage in InitSettings.ModuleSwitches) then
                      InitSettings.SourceCodePage:=Default_Settings.SourceCodePage;
                  end;
              end;
          end;


      end;

    procedure Set_Current_Scanner(avalue: TScannerFile);
    begin
      _temp_scanner:=avalue;
    end;

    Function SetCompileMode(const s:string; changeInit: boolean):boolean;
      var
        b : boolean;
        oldmodeswitches : TModeSwitches;
      begin
        if s='DELPHIUNICODE' then
          begin
            if changeInit then
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
        oldmodeswitches:=CurrentSettings.ModeSwitches;

        b:=true;
        if s='DEFAULT' then
          CurrentSettings.ModeSwitches:=FPCModeSwitches
        else
         if s='DELPHI' then
          CurrentSettings.ModeSwitches:=DelphiModeSwitches
        else
         if s='DELPHIUNICODE' then
          CurrentSettings.ModeSwitches:=DelphiUnicodeModeSwitches
        else
         if s='FPC' then begin
          CurrentSettings.ModeSwitches:=FPCModeSwitches;
          { TODO: enable this for 2.3/2.9 }
          //  include(current_settings.localswitches, cs_typed_addresses);
        end else
         if s='OBJFPC' then begin
          CurrentSettings.ModeSwitches:=ObjFPCModeSwitches;
          { TODO: enable this for 2.3/2.9 }
          //  include(current_settings.localswitches, cs_typed_addresses);
        end
{$ifdef gpc_mode}
        else if s='GPC' then
          CurrentSettings.ModeSwitches:=GPCModeSwitches
{$endif}
        else
         if s='MACPAS' then
          CurrentSettings.ModeSwitches:=MacModeSwitches
        else
         if s='ISO' then
          CurrentSettings.ModeSwitches:=ISOModeSwitches
        else
         if s='EXTENDEDPASCAL' then
          CurrentSettings.ModeSwitches:=ExtPasModeSwitches
        else
         b:=false;


        if b and changeInit then
          InitSettings.ModeSwitches := CurrentSettings.ModeSwitches;

        if b then
         begin
           { resolve all postponed switch changes }
           FlushPendingSwitchesState;

           HandleModeSwitches(m_none,changeinit);

           { turn on bitpacking and case checking for mode macpas and iso pascal,
             as well as extended pascal }
           if ([m_mac,m_iso,m_extpas] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_bitpacking);
               include(CurrentSettings.LocalSwitches,cs_check_all_case_coverage);
               if changeinit then
                 begin
                   include(InitSettings.LocalSwitches,cs_bitpacking);
                   include(InitSettings.LocalSwitches,cs_check_all_case_coverage);
                 end;
             end;

            { support goto/label by default in delphi/mac/iso/extpas modes }
            if ([m_delphi,m_mac,m_iso,m_extpas] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.ModuleSwitches,cs_support_goto);
               if changeinit then
                 include(InitSettings.ModuleSwitches,cs_support_goto);
             end;

           { support pointer math by default in fpc/objfpc modes }
           if ([m_fpc,m_objfpc] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_pointermath);
               if changeinit then
                 include(InitSettings.LocalSwitches,cs_pointermath);
             end
           else
             begin
               exclude(CurrentSettings.LocalSwitches,cs_pointermath);
               if changeinit then
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

           if changeinit then
             begin
               InitSettings.PackEnum:=CurrentSettings.PackEnum;
               InitSettings.SetAlloc:=CurrentSettings.SetAlloc;
             end;
{$if defined(i386)}
            { Default to Intel assembler for Delphi on i386 }
            if m_delphi in CurrentSettings.ModeSwitches then
             begin

               CurrentSettings.AsmMode:=asmmode_i386_intel;

               if changeinit then
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
               if changeinit then
                 include(InitSettings.LocalSwitches,cs_strict_var_strings);
             end;

           { in delphi mode, excess precision and open strings are by default on }
           if ([m_delphi] * CurrentSettings.ModeSwitches <> []) then
             begin
               include(CurrentSettings.LocalSwitches,cs_excessprecision);
               include(CurrentSettings.LocalSwitches,cs_openstring);
               if changeinit then
                 begin
                   include(InitSettings.LocalSwitches,cs_excessprecision);
                   include(InitSettings.LocalSwitches,cs_openstring);
                 end;
             end;



            { Undefine old symbol }
            if (m_delphi in oldmodeswitches) then
              undef_system_macro('FPC_DELPHI')
            else if (m_objfpc in oldmodeswitches) then
              undef_system_macro('FPC_OBJFPC')
{$ifdef gpc_mode}
            else if (m_gpc in oldmodeswitches) then
              undef_system_macro('FPC_GPC')
{$endif}
            else if (m_mac in oldmodeswitches) then
              undef_system_macro('FPC_MACPAS')
            else if (m_iso in oldmodeswitches) then
              undef_system_macro('FPC_ISO')
            else if (m_extpas in oldmodeswitches) then
              undef_system_macro('FPC_EXTENDEDPASCAL');

            { define new symbol in Delphi, ObjFPC, GPC, or MacPas mode }
            if (m_delphi in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_DELPHI')
            else if (m_objfpc in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_OBJFPC')
{$ifdef gpc_mode}
            else if (m_gpc in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_GPC')
{$endif}
            else if (m_mac in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_MACPAS')
            else if (m_iso in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_ISO')
            else if (m_extpas in CurrentSettings.ModeSwitches) then
              def_system_macro('FPC_EXTENDEDPASCAL');
         end;

        SetCompileMode:=b;
      end;


    Function SetCompileModeSwitch(s:string; changeInit: boolean):boolean;
      var
        i : TModeSwitch;
        doinclude : boolean;
      begin
        s:=upper(s);

        { on/off? }
        doinclude:=true;
        case s[length(s)] of
          '+':
            SetLength(s,length(s)-1);
          '-':
            begin
              SetLength(s,length(s)-1);
              doinclude:=false;
            end;
        end;

        Result:=false;
        for i:=m_class to high(TModeSwitch) do
          if s=modeswitchstr[ord(i)] then
            begin
              if i in [m_default_ansistring,m_default_unicodestring] then
                begin
                  Result:=true;
                  if not changeInit then
                    Message1(scan_e_illegal_directive,'MODESWITCH '+s)
                  else if not doinclude then
                    Message1(option_illegal_para,'-M'+s+'-')
                  else if CompilerWide_String_Mode_Explicit and
                          (CompilerWide_Unicode_Strings<>(i=m_default_unicodestring)) then
                    Message1(option_illegal_para,'-M'+s+' conflicts with the selected string mode')
                  else
                    begin
                      CompilerWide_Unicode_Strings:=i=m_default_unicodestring;
                      CompilerWide_String_Mode_Explicit:=true;
                      if changeInit then
                        CurrentSettings.ModeSwitches:=InitSettings.ModeSwitches;
                      HandleModeSwitches(i,changeInit);
                    end;
                  break;
                end;
              { Objective-C is currently only supported for Darwin targets }
              if doinclude and
                 (i in [m_objectivec1,m_objectivec2]) and
                 not(TargetInfo.system in systems_objc_supported) then
                begin
                  Message1(option_unsupported_target_for_feature,'Objective-C');
                  break;
                end;

              { Blocks supported? }
              if doinclude and
                 (i = m_blocks) and
                 not(TargetInfo.system in systems_blocks_supported) then
                begin
                  Message1(option_unsupported_target_for_feature,'Blocks');
                  break;
                end;

              if changeInit then
                CurrentSettings.ModeSwitches:=InitSettings.ModeSwitches;
              Result:=true;
              if doinclude then
                begin
                  include(CurrentSettings.ModeSwitches,i);
                  { Objective-C 2.0 support implies 1.0 support }
                  if (i=m_objectivec2) then
                    include(CurrentSettings.ModeSwitches,m_objectivec1);
                  if (i in [m_objectivec1,m_objectivec2]) then
                    include(CurrentSettings.ModeSwitches,m_class);
                end
              else
                begin
                  exclude(CurrentSettings.ModeSwitches,i);
                  { Objective-C 2.0 support implies 1.0 support }
                  if (i=m_objectivec2) then
                    exclude(CurrentSettings.ModeSwitches,m_objectivec1);
                  if (i in [m_objectivec1,m_objectivec2]) and
                     ([m_delphi,m_objfpc]*CurrentSettings.ModeSwitches=[]) then
                    exclude(CurrentSettings.ModeSwitches,m_class);
                end;

              { set other switches depending on changed mode switch }
              HandleModeSwitches(i,changeinit);

              if changeInit then
                InitSettings.ModeSwitches:=CurrentSettings.ModeSwitches;

              break;
            end;
      end;

    procedure SetAppType(NewAppType:TAppType);
      begin

        if AppType in [app_cui,app_com] then
          undef_system_macro('CONSOLE');
        AppType:=NewAppType;
        if AppType in [app_cui,app_com] then
          def_system_macro('CONSOLE');
      end;
{*****************************************************************************
                           Conditional Directives
*****************************************************************************}

    procedure dir_else;
      begin
        CurrentScanner.elsepreprocstack;
      end;

    procedure dir_endif;
      begin
        if (cs_legacyifend in CurrentSettings.LocalSwitches) and
          (CurrentScanner.preprocstack.typ<>pp_ifdef) and (CurrentScanner.preprocstack.typ<>pp_ifndef) and
            not((CurrentScanner.preprocstack.typ=pp_else) and (CurrentScanner.preprocstack.iftyp in [pp_ifdef,pp_ifndef])) then
          Message(scan_e_unexpected_endif);
        CurrentScanner.poppreprocstack;
      end;

    procedure dir_ifend;
      begin
        if (cs_legacyifend in CurrentSettings.LocalSwitches) and
          (CurrentScanner.preprocstack.typ<>pp_elseif) and (CurrentScanner.preprocstack.typ<>pp_if) and
            not((CurrentScanner.preprocstack.typ=pp_else) and (CurrentScanner.preprocstack.iftyp in [pp_if,pp_elseif])) then
          Message(scan_e_unexpected_ifend);
        CurrentScanner.poppreprocstack;
      end;

    function isdef(var valuedescr: String): Boolean;
      var
        hs    : string;
      begin
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        valuedescr:= hs;
        if hs='' then
          Message(scan_e_error_in_preproc_expr);
        isdef:=defined_macro(hs);
      end;

    procedure dir_ifdef;
      begin
        CurrentScanner.ifpreprocstack(pp_ifdef,@isdef,scan_c_ifdef_found);
      end;

    function isnotdef(var valuedescr: String): Boolean;
      var
        hs    : string;
      begin
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        valuedescr:= hs;
        if hs='' then
          Message(scan_e_error_in_preproc_expr);
        isnotdef:=not defined_macro(hs);
      end;

    procedure dir_ifndef;
      begin
        CurrentScanner.ifpreprocstack(pp_ifndef,@isnotdef,scan_c_ifndef_found);
      end;

    function opt_check(var valuedescr: String): Boolean;
      var
        hs    : string;
        state : char;
      begin
        opt_check:= false;
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        valuedescr:= hs;
        if (length(hs)>1) then
          Message1(scan_w_illegal_switch,hs)
        else
          begin
            state:=CurrentScanner.ReadState;
            if state in ['-','+'] then
              opt_check:=CheckSwitch(hs[1],state)
            else
              Message(scan_e_error_in_preproc_expr);
          end;
      end;

    procedure dir_ifopt;
      begin
        FlushPendingSwitchesState;
        CurrentScanner.ifpreprocstack(pp_ifopt,@opt_check,scan_c_ifopt_found);
      end;

    procedure dir_libprefix;
      var
        s : string;
      begin
        CurrentScanner.skipspace;
        if CurrentScanner.c <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.c);
        s := CurrentScanner.readquotedstring;
        StringDispose(OutputPrefix);
        OutputPrefix := StringDup(s);
        with CurrentModule do
         setfilename(ParamFN, ParamAllowOutput);
      end;

    procedure dir_libsuffix;
      var
        s : string;
      begin
        CurrentScanner.skipspace;
        if CurrentScanner.c <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.c);
        s := CurrentScanner.readquotedstring;
        StringDispose(OutputSuffix);
        OutputSuffix := StringDup(s);
        with CurrentModule do
          setfilename(ParamFN, ParamAllowOutput);
      end;

    procedure dir_extension;
      var
        s : string;
      begin
        CurrentScanner.skipspace;
        if CurrentScanner.c <> '''' then
          Message2(scan_f_syn_expected, '''', CurrentScanner.c);
        s := CurrentScanner.readquotedstring;
        if OutputFileName='' then
          OutputFileName:=InputFileName;
        OutputFileName:=ChangeFileExt(OutputFileName,'.'+s);
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
       sintdef,uintdef,booldef,strdef,setdef,realdef: TDef;
    class constructor createdefs;
    class destructor destroydefs;
  public
    consttyp: TConstTyp;
    value: TConstValue;
    def: TDef;
    constructor create_const(c:TConstSym);
    constructor create_error;
    constructor create_ord(v: TConstExprInt);
    constructor create_int(v: int64);
    constructor create_uint(v: qword);
    constructor create_bool(b: boolean);
    constructor create_str(const s: string);
    constructor create_set(ns: TNormalSet);
    constructor create_real(r: BestReal);
    class function try_parse_number(const s:string):TExprValue; static;
    class function try_parse_real(const s:string):TExprValue; static;
    function evaluate(v:TExprValue;op:TToken):TExprValue;
    procedure error(expecteddef, place: string);
    function isBoolean: Boolean;
    function isInt: Boolean;
    function asBool: Boolean;
    function asInt: Integer;
    function asInt64: Int64;
    function asStr: String;
    function asSet: TNormalSet;
    destructor Destroy; override;
  end;

  class constructor TExprValue.createdefs;
    begin
      { do not use corddef etc here: this code is executed before those
        variables are initialised. Since these types are only used for
        compile-time evaluation of conditional expressions, it doesn't matter
        that we use the base types instead of the cpu-specific ones. }
      sintdef:=TOrdDef.create(s64bit,low(int64),high(int64),false);
      uintdef:=TOrdDef.create(u64bit,low(qword),high(qword),false);
      booldef:=TOrdDef.create(pasbool1,0,1,false);
      strdef:=TStringDef.createansi(0,false);
      setdef:=TSetDef.create(sintdef,0,255,false);
      realdef:=TFloatDef.create(s80real,false);
    end;

  class destructor TExprValue.destroydefs;
    begin
      setdef.free;
      setdef := nil;
      sintdef.free;
      sintdef := nil;
      uintdef.free;
      uintdef := nil;
      booldef.free;
      booldef := nil;
      strdef.free;
      strdef := nil;
      realdef.free;
      realdef := nil;
    end;

  constructor TExprValue.create_const(c: TConstSym);
    begin
      consttyp:=c.consttyp;
      def:=c.constdef;
      case consttyp of
        conststring,
        constresourcestring:
          begin
            value.len:=c.value.len;
            GetMem(value.valueptr,value.len+1);
            move(c.value.valueptr^,value.valueptr^,value.len+1);
          end;
        constwstring,
        constwresourcestring:
          begin
            InitWideString(value.valuews);
            CopyWideString(c.value.valuews,value.valuews);
          end;
        constreal:
          begin
            new(PBestReal(value.valueptr));
            PBestReal(value.valueptr)^:=PBestReal(c.value.valueptr)^;
          end;
        constset:
          begin
            new(PNormalSet(value.valueptr));
            PNormalSet(value.valueptr)^:=PNormalSet(c.value.valueptr)^;
          end;
        constguid:
          begin
            new(PGUID(value.valueptr));
            PGUID(value.valueptr)^:=PGUID(c.value.valueptr)^;
          end;
        else
          value:=c.value;
      end;
    end;

  constructor TExprValue.create_error;
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constnone;
      def:=generrordef;
    end;

  constructor TExprValue.create_ord(v: TConstExprInt);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constord;
      value.valueord:=v;
      if v.signed then
        def:=sintdef
      else
        def:=uintdef;
    end;

  constructor TExprValue.create_int(v: int64);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constord;
      value.valueord:=v;
      def:=sintdef;
    end;

  constructor TExprValue.create_uint(v: qword);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constord;
      value.valueord:=v;
      def:=uintdef;
    end;

  constructor TExprValue.create_bool(b: boolean);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constord;
      value.valueord:=ord(b);
      def:=booldef;
    end;

  constructor TExprValue.create_str(const s: string);
    var
      sp: PAnsiChar;
      len: integer;
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=conststring;
      len:=length(s);
      GetMem(sp,len+1);
      move(s[1],sp^,len+1);
      value.valueptr:=sp;
      value.len:=len;
      def:=strdef;
    end;

  constructor TExprValue.create_set(ns: TNormalSet);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constset;
      new(PNormalSet(value.valueptr));
      PNormalSet(value.valueptr)^:=ns;
      def:=setdef;
    end;

  constructor TExprValue.create_real(r: BestReal);
    begin
      fillchar(value,sizeof(value),#0);
      consttyp:=constreal;
      new(PBestReal(value.valueptr));
      PBestReal(value.valueptr)^:=r;
      def:=realdef;
    end;

  class function TExprValue.try_parse_number(const s:string):TExprValue;
    var
      ic: int64;
      qc: qword;
      code: integer;
    begin
      { try int64 }
      val(s,ic,code);
      if code=0 then
        result:=TExprValue.create_int(ic)
      else
        begin
          { try qword }
          val(s,qc,code);
          if code=0 then
            result:=TExprValue.create_uint(qc)
          else
            result:=try_parse_real(s);
        end;
    end;

  class function TExprValue.try_parse_real(const s:string):TExprValue;
    var
      d: BestReal;
      code: integer;
    begin
      Val(s,d,code);
      if code=0 then
        result:=TExprValue.create_real(d)
      else
        result:=nil;
    end;

  function TExprValue.evaluate(v:TExprValue;op:TToken):TExprValue;

    function check_compatible: boolean;
      begin
        result:=(
                  (is_ordinal(v.def) or is_fpu(v.def)) and
                  (is_ordinal(def) or is_fpu(def))
                ) or
                (is_stringlike(v.def) and is_stringlike(def));
        if not result then
          Message2(type_e_incompatible_types,def.typename,v.def.typename);
      end;
    var
      lv,rv: TConstExprInt;
      lvd,rvd: BestReal;
      lvs,rvs: string;
    begin
      case op of
        _OP_IN:
        begin
          if not is_set(v.def) then
            begin
              v.error('Set', 'IN');
              result:=TExprValue.create_error;
            end
          else
          if not is_ordinal(def) then
            begin
              error('Ordinal', 'IN');
              result:=TExprValue.create_error;
            end
          else
          if value.valueord.signed then
            result:=TExprValue.create_bool(value.valueord.svalue in PNormalSet(v.value.valueptr)^)
          else
            result:=TExprValue.create_bool(value.valueord.uvalue in PNormalSet(v.value.valueptr)^);
        end;
        _OP_NOT:
        begin
          if isBoolean then
            result:=TExprValue.create_bool(not asBool)
          else if is_ordinal(def) then
            begin
              result:=TExprValue.create_ord(value.valueord);
              result.def:=def;
              calc_not_ordvalue(result.value.valueord,result.def);
            end
          else
            begin
              error('Boolean', 'NOT');
              result:=TExprValue.create_error;
            end;
        end;
        _OP_OR:
        begin
          if isBoolean then
            if v.isBoolean then
              result:=TExprValue.create_bool(asBool or v.asBool)
            else
              begin
                v.error('Boolean','OR');
                result:=TExprValue.create_error;
              end
          else if is_ordinal(def) then
            if is_ordinal(v.def) then
              result:=TExprValue.create_ord(value.valueord or v.value.valueord)
            else
              begin
                v.error('Ordinal','OR');
                result:=TExprValue.create_error;
              end
          else
            begin
              error('Boolean','OR');
              result:=TExprValue.create_error;
            end;
        end;
        _OP_XOR:
        begin
          if isBoolean then
            if v.isBoolean then
              result:=TExprValue.create_bool(asBool xor v.asBool)
            else
              begin
                v.error('Boolean','XOR');
                result:=TExprValue.create_error;
              end
          else if is_ordinal(def) then
            if is_ordinal(v.def) then
              result:=TExprValue.create_ord(value.valueord xor v.value.valueord)
            else
              begin
                v.error('Ordinal','XOR');
                result:=TExprValue.create_error;
              end
          else
            begin
              error('Boolean','XOR');
              result:=TExprValue.create_error;
            end;
        end;
        _OP_AND:
        begin
          if isBoolean then
            if v.isBoolean then
              result:=TExprValue.create_bool(asBool and v.asBool)
            else
              begin
                v.error('Boolean','AND');
                result:=TExprValue.create_error;
              end
          else if is_ordinal(def) then
            if is_ordinal(v.def) then
              result:=TExprValue.create_ord(value.valueord and v.value.valueord)
            else
              begin
                v.error('Ordinal','AND');
                result:=TExprValue.create_error;
              end
          else
            begin
              error('Boolean','AND');
              result:=TExprValue.create_error;
            end;
        end;
        _EQ,_NE,_LT,_GT,_GTE,_LTE,_PLUS,_MINUS,_STAR,_SLASH,_OP_DIV,_OP_MOD,_OP_SHL,_OP_SHR:
        if (op=_MINUS) and not(Assigned(v)) then
          begin
            if is_ordinal(def) then
              result:=TExprValue.create_ord(-value.valueord)
            else if is_fpu(def) then
              result:=TExprValue.create_real(-PBestReal(value.valueptr)^)
            else
              InternalError(2025050610);
          end
        else if check_compatible then
          begin
            if (is_ordinal(def) and is_ordinal(v.def)) then
              begin
                lv:=value.valueord;
                rv:=v.value.valueord;
                case op of
                  _EQ:
                    result:=TExprValue.create_bool(lv=rv);
                  _NE:
                    result:=TExprValue.create_bool(lv<>rv);
                  _LT:
                    result:=TExprValue.create_bool(lv<rv);
                  _GT:
                    result:=TExprValue.create_bool(lv>rv);
                  _GTE:
                    result:=TExprValue.create_bool(lv>=rv);
                  _LTE:
                    result:=TExprValue.create_bool(lv<=rv);
                  _PLUS:
                    result:=TExprValue.create_ord(lv+rv);
                  _MINUS:
                    result:=TExprValue.create_ord(lv-rv);
                  _STAR:
                    result:=TExprValue.create_ord(lv*rv);
                  _SLASH:
                    result:=TExprValue.create_real(lv/rv);
                  _OP_DIV:
                    result:=TExprValue.create_ord(lv div rv);
                  _OP_MOD:
                    result:=TExprValue.create_ord(lv mod rv);
                  _OP_SHL:
                    result:=TExprValue.create_ord(lv shl rv);
                  _OP_SHR:
                    result:=TExprValue.create_ord(lv shr rv);
                  else
                    InternalError(2025050611);
                end;
              end
            else
            if (is_fpu(def) or is_ordinal(def)) and
               (is_fpu(v.def) or is_ordinal(v.def)) then
              begin
                if is_fpu(def) then
                  lvd:=PBestReal(value.valueptr)^
                else
                  lvd:=value.valueord;
                if is_fpu(v.def) then
                  rvd:=PBestReal(v.value.valueptr)^
                else
                  rvd:=v.value.valueord;
                case op of
                  _EQ:
                    result:=TExprValue.create_bool(lvd=rvd);
                  _NE:
                    result:=TExprValue.create_bool(lvd<>rvd);
                  _LT:
                    result:=TExprValue.create_bool(lvd<rvd);
                  _GT:
                    result:=TExprValue.create_bool(lvd>rvd);
                  _GTE:
                    result:=TExprValue.create_bool(lvd>=rvd);
                  _LTE:
                    result:=TExprValue.create_bool(lvd<=rvd);
                  _PLUS:
                    result:=TExprValue.create_real(lvd+rvd);
                  _MINUS:
                    result:=TExprValue.create_real(lvd-rvd);
                  _STAR:
                    result:=TExprValue.create_real(lvd*rvd);
                  _SLASH:
                    result:=TExprValue.create_real(lvd/rvd);
                  else
                    begin
                      Message(parser_e_illegal_expression);
                      result:=TExprValue.create_error;
                    end;
                end;
              end
            else
            begin
              lvs:=asStr;
              rvs:=v.asStr;
              case op of
                _EQ:
                  result:=TExprValue.create_bool(lvs=rvs);
                _NE:
                  result:=TExprValue.create_bool(lvs<>rvs);
                _LT:
                  result:=TExprValue.create_bool(lvs<rvs);
                _GT:
                  result:=TExprValue.create_bool(lvs>rvs);
                _GTE:
                  result:=TExprValue.create_bool(lvs>=rvs);
                _LTE:
                  result:=TExprValue.create_bool(lvs<=rvs);
                _PLUS:
                  result:=TExprValue.create_str(lvs+rvs);
                else
                  begin
                    Message(parser_e_illegal_expression);
                    result:=TExprValue.create_error;
                  end;
              end;
            end;
          end
        else
          result:=TExprValue.create_error;
        else
          result:=TExprValue.create_error;
      end;
    end;

  procedure TExprValue.error(expecteddef, place: string);
    begin
      Message3(scan_e_compile_time_typeerror,
               expecteddef,
               def.typename,
               place
              );
    end;

  function TExprValue.isBoolean: Boolean;
    var
      i: int64;
    begin
      result:=is_boolean(def);
      if not result and is_integer(def) then
        begin
          i:=asInt64;
          result:=(i=0)or(i=1);
        end;
    end;

  function TExprValue.isInt: Boolean;
    begin
      result:=is_integer(def);
    end;

  function TExprValue.asBool: Boolean;
    begin
      result:=value.valueord<>0;
    end;

  function TExprValue.asInt: Integer;
    begin
      result:=value.valueord.svalue;
    end;

  function TExprValue.asInt64: Int64;
    begin
      result:=value.valueord.svalue;
    end;

  function TExprValue.asSet: TNormalSet;
    begin
      result:=PNormalSet(value.valueptr)^;
    end;

  function TExprValue.asStr: String;
    var
      b:byte;
    begin
      case consttyp of
        constord:
          result:=ToStr(value.valueord);
        conststring,
        constresourcestring:
          SetString(result,pchar(value.valueptr),value.len);
        constreal:
          result:=RealToStr(PBestReal(value.valueptr)^);
        constset:
          begin
            result:=',';
            for b:=0 to 255 do
              if b in PConstSet(value.valueptr)^ then
                result:=result+ToStr(b)+',';
          end;
        { error values }
        constnone:
          result:='';
        else
          InternalError(2013112801);
      end;
    end;

  destructor TExprValue.Destroy;
    begin
      case consttyp of
        conststring,
        constresourcestring :
          FreeMem(value.valueptr,value.len+1);
        constwstring,
        constwresourcestring:
          DoneWideString(value.valuews);
        constreal :
          dispose(PBestReal(value.valueptr));
        constset :
          dispose(PNormalSet(value.valueptr));
        constguid :
          dispose(PGUID(value.valueptr));
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
    preproc_operators=[_EQ,_NE,_LT,_GT,_LTE,_GTE,_MINUS,_PLUS,_STAR,_SLASH,_OP_DIV,_OP_MOD,_OP_SHL,_OP_SHR,_OP_IN,_OP_AND,_OP_OR,_OP_XOR];

    function findincludefile(const path,name:TCmdStr;var foundfile:TCmdStr):boolean;
      var
        found  : boolean;
        hpath  : TCmdStr;
      begin
        (* look for the include file
         If path was absolute and specified as part of {$I } then
          1. specified path
         else
          1. path of current inputfile,current dir
          2. local includepath
          3. global includepath

          -- Check mantis #13461 before changing this *)
         found:=false;
         foundfile:='';
         hpath:='';
         if Path_Absolute(path) then
           begin
             found:=FindFile(name,path,true,foundfile);
           end
         else
           begin
             hpath:=CurrentScanner.inputfile.path+';'+CurDirRelPath(SourceInfo);
             found:=FindFile(path+name, hpath,true,foundfile);
             if not found then
               found:=CurrentModule.localincludesearchpath.FindFile(path+name,true,foundfile);
             if not found  then
               found:=IncludeSearchPath.FindFile(path+name,true,foundfile);
           end;
         result:=found;
      end;


    function preproc_comp_expr(conform_to:TDef):TExprValue;

        function preproc_sub_expr(pred_level:TOperatorPrecedence;eval:Boolean):TExprValue; forward;

        procedure preproc_consume(t:TToken);
        begin
          if t<>CurrentScanner.preproc_token then
            Message(scan_e_preproc_syntax_error);
          CurrentScanner.preproc_token:=CurrentScanner.readpreproc;
        end;

        function try_consume_unitsym(var srsym:TSym;var srsymtable:TSymTable;out tokentoconsume:TToken):boolean;
          var
            hmodule: TModule;
            ns:AnsiString;
            nssym:TSym;
          begin
            result:=false;
            tokentoconsume:=_ID;

            if Assigned(srsym) and (srsym.typ in [unitsym,namespacesym]) then
              begin
                if not(srsym.owner.symtabletype in [staticsymtable,GlobalSymTable]) then
                  InternalError(200501154);
                { only allow unit.symbol access if the name was
                  found in the current module
                  we can use iscurrentunit because generic specializations does not
                  change current_unit variable }
                hmodule:=find_module_from_symtable(srsym.Owner);
                if not Assigned(hmodule) then
                  InternalError(201001120);
                if hmodule.ModuleID=CurrentFilePos.moduleindex then
                  begin
                    preproc_consume(_POINT);
                    CurrentScanner.skipspace;
                    if srsym.typ=namespacesym then
                      begin
                        ns:=srsym.name;
                        nssym:=srsym;
                        while Assigned(srsym) and (srsym.typ=namespacesym) do
                          begin
                            { we have a namespace. the next identifier should be either a namespace or a unit }
                            searchsym_in_module(hmodule,ns+'.'+CurrentScanner.preproc_pattern,srsym,srsymtable);
                            if Assigned(srsym) and (srsym.typ in [namespacesym,unitsym]) then
                              begin
                                ns:=ns+'.'+CurrentScanner.preproc_pattern;
                                nssym:=srsym;
                                preproc_consume(_ID);
                                CurrentScanner.skipspace;
                                preproc_consume(_POINT);
                                CurrentScanner.skipspace;
                              end;
                          end;
                        { check if there is a hidden unit with this pattern in the namespace }
                        if not Assigned(srsym) and
                           Assigned(nssym) and (nssym.typ=namespacesym) and Assigned(TNamespaceSym(nssym).unitsym) then
                          srsym:=TNamespaceSym(nssym).unitsym;
                        if Assigned(srsym) and (srsym.typ<>unitsym) then
                          InternalError(201108260);
                        if not Assigned(srsym) then
                          begin
                            result:=true;
                            srsymtable:=nil;
                            exit;
                          end;
                      end;
                    case CurrentScanner.preproc_token of
                      _ID:
                        { Resolve the default Char/PChar from the invocation's
                          text model, regardless of the System alias. }
                        if ((CurrentScanner.preproc_pattern='CHAR') or
                            (CurrentScanner.preproc_pattern='PCHAR')) and
                           (TModule(TUnitSym(srsym).module).GlobalSymTable=systemunit) then
                          begin
                            if CurrentScanner.preproc_pattern='PCHAR' then
                              if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                searchsym_in_module(TUnitSym(srsym).module,'PWIDECHAR',srsym,srsymtable)
                              else
                                searchsym_in_module(TUnitSym(srsym).module,'PANSICHAR',srsym,srsymtable)
                            else if m_default_unicodestring in CurrentSettings.ModeSwitches then
                              searchsym_in_module(TUnitSym(srsym).module,'WIDECHAR',srsym,srsymtable)
                            else
                              searchsym_in_module(TUnitSym(srsym).module,'ANSICHAR',srsym,srsymtable)
                          end
                        else
                          searchsym_in_module(TUnitSym(srsym).module,CurrentScanner.preproc_pattern,srsym,srsymtable);
                      _STRING:
                        begin
                          { system.string? }
                          if TModule(TUnitSym(srsym).module).GlobalSymTable=systemunit then
                            begin
                              if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                                begin
                                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                                    searchsym_in_module(TUnitSym(srsym).module,'UNICODESTRING',srsym,srsymtable)
                                  else
                                    searchsym_in_module(TUnitSym(srsym).module,'ANSISTRING',srsym,srsymtable)
                                end
                              else
                                searchsym_in_module(TUnitSym(srsym).module,'SHORTSTRING',srsym,srsymtable);
                              tokentoconsume:=_STRING;
                            end;
                        end
                      else
                        ;
                    end;
                  end
                else
                  begin
                    srsym:=nil;
                    srsymtable:=nil;
                  end;
                result:=true;
              end;
          end;

        procedure try_consume_nestedsym(var srsym:TSym;var srsymtable:TSymTable);
          var
            def:TDef;
            tokentoconsume:TToken;
            found:boolean;
          begin
            found:=try_consume_unitsym(srsym,srsymtable,tokentoconsume);
            if found then
              begin
                preproc_consume(tokentoconsume);
                CurrentScanner.skipspace;
              end;
             while (CurrentScanner.preproc_token=_POINT) do
               begin
                 if Assigned(srsym)and(srsym.typ=typesym) then
                   begin
                     def:=TTypeSym(srsym).typedef;
                     if is_class_or_object(def) or is_record(def) or is_java_class_or_interface(def) then
                       begin
                         preproc_consume(_POINT);
                         CurrentScanner.skipspace;
                         if def.typ=objectdef then
                           found:=searchsym_in_class(TObjectDef(def),TObjectDef(def),CurrentScanner.preproc_pattern,srsym,srsymtable,[ssf_search_helper])
                         else
                           found:=searchsym_in_record(TRecordDef(def),CurrentScanner.preproc_pattern,srsym,srsymtable);
                         if not found then
                           begin
                             Message1(sym_e_id_not_found,CurrentScanner.preproc_pattern);
                             exit;
                           end;
                         preproc_consume(_ID);
                         CurrentScanner.skipspace;
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

        function preproc_substitutedtoken(const basesearchstr:ShortString;eval:Boolean):TExprValue;
        { Currently this parses identifiers as well as numbers.
          The result from this procedure can either be that the token
          itself is a value, or that it is a compile time variable/macro,
          which then is substituted for another value (for macros
          recursively substituted).}

        var
          hs: ShortString;
          mac: TMacro;
          macrocount,
          len: integer;
          foundmacro: boolean;
          searchstr: PShortString;
          searchstr2store: ShortString;
        begin
          if not eval then
            begin
              result:=TExprValue.create_str(basesearchstr);
              exit;
            end;

          searchstr := @basesearchstr;
          mac:=nil;
          foundmacro:=false;
          { Substitute macros and compiler variables with their content/value.
            For real macros also do recursive substitution. }
          macrocount:=0;
          repeat
            mac:=TMacro(search_macro(searchstr^));

            inc(macrocount);
            if macrocount>max_macro_nesting then
              begin
                Message(scan_w_macro_too_deep);
                break;
              end;

            if Assigned(mac) and mac.defined then
              if Assigned(mac.buftext) then
                begin
                  if mac.buflen>255 then
                    begin
                      len:=255;
                      Message(scan_w_macro_cut_after_255_chars);
                    end
                  else
                    len:=mac.buflen;
                  hs[0]:=char(len);
                  if len>0 then
                    move(mac.buftext[0],hs[1],len);
                  searchstr2store:=upcase(hs);
                  searchstr:=@searchstr2store;
                  mac.is_used:=true;
                  foundmacro:=true;
                end
              else
                begin
                  Message1(scan_e_error_macro_lacks_value,searchstr^);
                  break;
                end
            else
              break;

            if mac.is_compiler_var then
              break;
          until false;

          { At this point, result do contain the value. Do some decoding and
            determine the type.}
          result:=TExprValue.try_parse_number(searchstr^);
          if not Assigned(result) then
            begin
              if foundmacro and (searchstr^='FALSE') then
                result:=TExprValue.create_bool(false)
              else if foundmacro and (searchstr^='TRUE') then
                result:=TExprValue.create_bool(true)
              else if (m_mac in CurrentSettings.ModeSwitches) and
                      (not Assigned(mac) or not mac.defined) and
                      (macrocount = 1) then
                begin
                  {Errors in mode mac is issued here. For non macpas modes there is
                   more liberty, but the error will eventually be caught at a later stage.}
                  Message1(scan_e_error_macro_undefined,searchstr^);
                  result:=TExprValue.create_str(searchstr^); { just to have something }
                end
              else
                result:=TExprValue.create_str(searchstr^);
            end;
        end;

        procedure MarkSymbolAsUsed(sym: TSym);
          begin
           sym.IncRefCount;
           { do we know an owner? }
           if Assigned(CurrentModule) and Assigned(CurrentModule.unitmap) and Assigned(sym.owner) then
             inc(CurrentModule.unitmap[sym.owner.ModuleID].refs);
          end;

        function preproc_factor(eval: Boolean):TExprValue;
        var
           hs,countstr,storedpattern,fileext: string;
           mac: TMacro;
           srsym : TSym;
           srsymtable : TSymTable;
           hdef : TDef;
           l : LongInt;
           hasKlammer,
           read_next: Boolean;
           exprvalue:TExprValue;
           ns:TNormalSet;
           fs,path,name: TPathStr;
           foundfile: TCmdStr;
           found: boolean;
        begin
          result:=nil;
          hasKlammer:=false;
           if CurrentScanner.preproc_token=_ID then
             begin
                if CurrentScanner.preproc_pattern='FILEEXISTS' then
                  begin
                    preproc_consume(_ID);
                    preproc_consume(_LKLAMMER);
                    hs:=CurrentScanner.preproc_pattern;
                    preproc_consume(_CSTRING);
                    fs:=GetToken(hs,' ');
                    fs:=FixFileName(fs);
                    path:=ExtractFilePath(fs);
                    name:=ExtractFileName(fs);

                    { this like 'include' }
                    if (length(name)>=1) and
                       (name[1]='*') then
                      name:=ChangeFileExt(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex),'')+ExtractFileExt(name);

                    { try to find the file, this like 'include' }
                    found:=findincludefile(path,name,foundfile);
                    fileext:=lower(ExtractFileExt(name));
                    if (not found) and ((fileext<>'.inc') and (fileext<>SourceExt)) then
                     begin
                       { try default extensions .inc and .pas }
                       if (not found) then
                        found:=findincludefile(path,name+'.inc',foundfile);
                       if (not found) then
                        found:=findincludefile(path,name+SourceExt,foundfile);
                     end;
                    if (not found) and (ExtractFileExt(name)=ExtensionSeparator) and (Length(name)>=2) then
                      found:=findincludefile(path,Copy(name,1,Length(name)-1),foundfile);

                    result:=TExprValue.create_bool(found);
                    CurrentScanner.skipspace;
                    preproc_consume(_RKLAMMER);
                  end
                else
                if CurrentScanner.preproc_pattern='DEFINED' then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                        hasKlammer:= true;
                      end
                    else if (m_mac in CurrentSettings.ModeSwitches) then
                      hasKlammer:= false
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if CurrentScanner.preproc_token =_ID then
                      begin
                        hs := CurrentScanner.preproc_pattern;
                        mac := TMacro(search_macro(hs));
                        if Assigned(mac) and mac.defined then
                          begin
                            result:=TExprValue.create_bool(true);
                            mac.is_used:=true;
                          end
                        else
                          result:=TExprValue.create_bool(false);
                        preproc_consume(_ID);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if hasKlammer then
                      if CurrentScanner.preproc_token =_RKLAMMER then
                        preproc_consume(_RKLAMMER)
                      else
                        Message(scan_e_error_in_preproc_expr);
                  end
                else
                if (m_mac in CurrentSettings.ModeSwitches) and (CurrentScanner.preproc_pattern='UNDEFINED') then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_ID then
                      begin
                        hs := CurrentScanner.preproc_pattern;
                        mac := TMacro(search_macro(hs));
                        { FPC_UNICODESTRINGS is always present in the initial
                          macro table, but is undefined in ANSI mode. }
                        if Assigned(mac) and
                           ((upper(hs)<>'FPC_UNICODESTRINGS') or mac.defined) then
                          begin
                            result:=TExprValue.create_bool(false);
                            mac.is_used:=true;
                          end
                        else
                          result:=TExprValue.create_bool(true);
                        preproc_consume(_ID);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if (m_mac in CurrentSettings.ModeSwitches) and (CurrentScanner.preproc_pattern='OPTION') then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);

                    if not (CurrentScanner.preproc_token = _ID) then
                      Message(scan_e_error_in_preproc_expr);

                    hs:=CurrentScanner.preproc_pattern;
                    if (length(hs) > 1) then
                      {This is allowed in Metrowerks Pascal}
                      Message(scan_e_error_in_preproc_expr)
                    else
                      begin
                        if CheckSwitch(hs[1],'+') then
                          result:=TExprValue.create_bool(true)
                        else
                          result:=TExprValue.create_bool(false);
                      end;

                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_RKLAMMER then
                      preproc_consume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.preproc_pattern='SIZEOF' then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    storedpattern:=CurrentScanner.preproc_pattern;
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;

                    if eval then
                      if searchsym(storedpattern,srsym,srsymtable) then
                        begin
                          try_consume_nestedsym(srsym,srsymtable);
                          l:=0;
                          if Assigned(srsym) then
                            case srsym.typ of
                              staticvarsym,
                              localvarsym,
                              paravarsym :
                                begin
                                  l:=TAbstractVarSym(srsym).getsize;
                                  MarkSymbolAsUsed(srsym);
                                end;
                              typesym:
                                begin
                                  if TTypeSym(srsym).typedef.typ in [errordef,abstractdef,forwarddef] then
                                    Message(parser_e_illegal_expression);
                                  l:=TTypeSym(srsym).typedef.size;
                                  MarkSymbolAsUsed(srsym);
                                end;
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                          result:=TExprValue.create_int(l);
                        end
                      else
                        Message1(sym_e_id_not_found,storedpattern);

                    if CurrentScanner.preproc_token =_RKLAMMER then
                      preproc_consume(_RKLAMMER)
                    else
                      Message(scan_e_preproc_syntax_error);
                  end
                else
                if CurrentScanner.preproc_pattern='HIGH' then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    storedpattern:=CurrentScanner.preproc_pattern;
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;

                    if eval then
                      if searchsym(storedpattern,srsym,srsymtable) then
                        begin
                          try_consume_nestedsym(srsym,srsymtable);
                          hdef:=nil;
                          hs:='';
                          l:=0;
                          if Assigned(srsym) then
                            case srsym.typ of
                              staticvarsym,
                              localvarsym,
                              paravarsym :
                                begin
                                  hdef:=TAbstractVarSym(srsym).vardef;
                                  MarkSymbolAsUsed(srsym);
                                end;
                              typesym:
                                begin
                                  hdef:=TTypeSym(srsym).typedef;
                                  MarkSymbolAsUsed(srsym);
                                end;
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                          if Assigned(hdef) then
                            begin
                              if hdef.typ=setdef then
                                hdef:=TSetDef(hdef).elementdef;
                              case hdef.typ of
                                orddef:
                                  with TOrdDef(hdef).high do
                                    if signed then
                                      result:=TExprValue.create_int(svalue)
                                    else
                                      result:=TExprValue.create_uint(uvalue);
                                enumdef:
                                  result:=TExprValue.create_int(TEnumDef(hdef).maxval);
                                arraydef:
                                  if is_open_array(hdef) or is_array_of_const(hdef) or is_dynamic_array(hdef) then
                                    Message(type_e_mismatch)
                                  else
                                    result:=TExprValue.create_int(TArrayDef(hdef).highrange);
                                stringdef:
                                  if is_open_string(hdef) or is_ansistring(hdef) or is_wide_or_unicode_string(hdef) then
                                    Message(type_e_mismatch)
                                  else
                                    result:=TExprValue.create_int(TStringDef(hdef).len);
                                else
                                  Message(type_e_mismatch);
                              end;
                            end;
                        end
                      else
                        Message1(sym_e_id_not_found,storedpattern);

                    if CurrentScanner.preproc_token =_RKLAMMER then
                      preproc_consume(_RKLAMMER)
                    else
                      Message(scan_e_preproc_syntax_error);
                  end
                else
                if CurrentScanner.preproc_pattern='DECLARED' then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                    if CurrentScanner.preproc_token =_ID then
                      begin
                        hs := upper(CurrentScanner.preproc_pattern);
                        preproc_consume(_ID);
                        CurrentScanner.skipspace;
                        if CurrentScanner.preproc_token in [_LT,_LSHARPBRACKET] then
                          begin
                            l:=1;
                            preproc_consume(CurrentScanner.preproc_token);
                            CurrentScanner.skipspace;
                            while CurrentScanner.preproc_token=_COMMA do
                              begin
                                inc(l);
                                preproc_consume(_COMMA);
                                CurrentScanner.skipspace;
                              end;
                            if not (CurrentScanner.preproc_token in [_GT,_RSHARPBRACKET]) then
                              Message(scan_e_error_in_preproc_expr)
                            else
                              preproc_consume(CurrentScanner.preproc_token);
                            str(l,countstr);
                            hs:=hs+'$'+countstr;
                          end
                        else
                          { special case: <> }
                          if CurrentScanner.preproc_token=_NE then
                            begin
                              hs:=hs+'$1';
                              preproc_consume(_NE);
                            end;
                        CurrentScanner.skipspace;
                        if searchsym(hs,srsym,srsymtable) then
                          begin
                            { TSomeGeneric<...> also adds a TSomeGeneric symbol }
                            if (sp_generic_dummy in srsym.symoptions) and
                                (srsym.typ=typesym) and
                                (
                                  { mode delphi}
                                  (TTypeSym(srsym).typedef.typ in [undefineddef,errordef]) or
                                  { non-delphi modes }
                                  (df_generic in TTypeSym(srsym).typedef.defoptions)
                                ) then
                              result:=TExprValue.create_bool(false)
                            else
                              result:=TExprValue.create_bool(true);
                            MarkSymbolAsUsed(srsym);
                          end
                        else
                          result:=TExprValue.create_bool(false);
                      end
                    else
                      Message(scan_e_error_in_preproc_expr);
                    if CurrentScanner.preproc_token =_RKLAMMER then
                      preproc_consume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.preproc_pattern='ORD' then
                  begin
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    if CurrentScanner.preproc_token =_LKLAMMER then
                      begin
                        preproc_consume(_LKLAMMER);
                        CurrentScanner.skipspace;
                      end
                    else
                      Message(scan_e_preproc_syntax_error);

                    exprvalue:=preproc_factor(eval);
                    if eval then
                      begin
                        if is_ordinal(exprvalue.def) then
                          result:=TExprValue.create_int(exprvalue.asInt)
                        else
                          begin
                            exprvalue.error('Ordinal','ORD');
                            result:=TExprValue.create_int(0);
                          end;
                      end
                    else
                      result:=TExprValue.create_int(0);
                    exprvalue.free;
                    exprvalue := nil;
                    if CurrentScanner.preproc_token =_RKLAMMER then
                      preproc_consume(_RKLAMMER)
                    else
                      Message(scan_e_error_in_preproc_expr);
                  end
                else
                if CurrentScanner.preproc_pattern='NOT' then
                  begin
                    preproc_consume(_ID);
                    exprvalue:=preproc_factor(eval);
                    if eval then
                      result:=exprvalue.evaluate(nil,_OP_NOT)
                    else
                      result:=TExprValue.create_bool(false); {Just to have something}
                    exprvalue.free;
                    exprvalue := nil;
                  end
                else
                if (CurrentScanner.preproc_pattern='TRUE') then
                  begin
                    result:=TExprValue.create_bool(true);
                    preproc_consume(_ID);
                  end
                else
                if (CurrentScanner.preproc_pattern='FALSE') then
                  begin
                    result:=TExprValue.create_bool(false);
                    preproc_consume(_ID);
                  end
                else
                  begin
                    storedpattern:=CurrentScanner.preproc_pattern;
                    preproc_consume(_ID);
                    CurrentScanner.skipspace;
                    { first look for a macros/int/float }
                    result:=preproc_substitutedtoken(storedpattern,eval);
                    if eval and (result.consttyp=conststring) then
                      begin
                        if searchsym(storedpattern,srsym,srsymtable) then
                          begin
                            try_consume_nestedsym(srsym,srsymtable);
                            if Assigned(srsym) then
                              begin
                                MarkSymbolAsUsed(srsym);
                                case srsym.typ of
                                  constsym:
                                    begin
                                      { const def must conform to the set type }
                                      if (conform_to<>nil) and
                                        (conform_to.typ=setdef) and
                                        (TConstSym(srsym).constdef.typ=setdef) and
                                        (compare_defs(TSetDef(TConstSym(srsym).constdef).elementdef,TSetDef(conform_to).elementdef,nothingn)<>te_exact) then
                                          begin
                                            result.free;
                                            result:=nil;
                                            // TODO(ryan): better error?
                                            Message(scan_e_error_in_preproc_expr);
                                          end;
                                      if result<>nil then
                                        begin
                                          result.free;
                                          result:=TExprValue.create_const(TConstSym(srsym));
                                        end;
                                    end;
                                  enumsym:
                                    begin
                                      { enum definition must conform to the set type }
                                      if (conform_to<>nil) and
                                        (conform_to.typ=setdef) and
                                        (compare_defs(TEnumSym(srsym).definition,TSetDef(conform_to).elementdef,nothingn)<>te_exact) then
                                          begin
                                            result.free;
                                            result:=nil;
                                            // TODO(ryan): better error?
                                            Message(scan_e_error_in_preproc_expr);
                                          end;
                                      if result<>nil then
                                        begin
                                          result.free;
                                          result:=TExprValue.create_int(TEnumSym(srsym).value);
                                        end;
                                    end;
                                  else
                                    ;
                                end;
                              end;
                          end
                        { the id must be belong to the set type }
                        else if (conform_to<>nil) and (conform_to.typ=setdef) then
                          begin
                            result.free;
                            result:=nil;
                            // TODO(ryan): better error?
                            Message(scan_e_error_in_preproc_expr);
                          end;
                      end
                      { skip id(<expr>) if expression must not be evaluated }
                      else if not(eval) and (result.consttyp=conststring) then
                        begin
                          if CurrentScanner.preproc_token =_LKLAMMER then
                            begin
                              preproc_consume(_LKLAMMER);
                              CurrentScanner.skipspace;

                              result:=preproc_factor(false);
                              if CurrentScanner.preproc_token =_RKLAMMER then
                                preproc_consume(_RKLAMMER)
                              else
                                Message(scan_e_error_in_preproc_expr);
                            end;
                        end;
                  end
             end
           else if CurrentScanner.preproc_token =_LKLAMMER then
             begin
                preproc_consume(_LKLAMMER);
                result:=preproc_sub_expr(opcompare,eval);
                preproc_consume(_RKLAMMER);
             end
           else if CurrentScanner.preproc_token = _LECKKLAMMER then
             begin
               preproc_consume(_LECKKLAMMER);
               ns:=[];
               read_next:=false;
               while (CurrentScanner.preproc_token in [_ID,_INTCONST]) or read_next do
               begin
                 read_next:=false;
                 exprvalue:=preproc_factor(eval);
                 { the const set does not conform to the set def }
                 if (conform_to<>nil) and
                   (conform_to.typ=setdef) and
                   (exprvalue.consttyp=constnone) then
                   begin
                     result:=TExprValue.create_error;
                     break;
                   end;
                 { reject duplicate enums in the set }
                 if exprvalue.asInt in ns then
                   begin
                     Message1(sym_e_duplicate_id,CurrentScanner.preproc_pattern);
                     result:=TExprValue.create_error;
                     break;
                   end;
                 include(ns,exprvalue.asInt);
                 if CurrentScanner.preproc_token = _COMMA then
                   begin
                     preproc_consume(_COMMA);
                     read_next:=true;
                   end
               end;
               preproc_consume(_RECKKLAMMER);
               if result=nil then
                 result:=TExprValue.create_set(ns);
             end
           else if CurrentScanner.preproc_token = _INTCONST then
             begin
               result:=TExprValue.try_parse_number(CurrentScanner.preproc_pattern);
               if not Assigned(result) then
                 begin
                   Message(parser_e_invalid_integer);
                   result:=TExprValue.create_int(1);
                 end;
               preproc_consume(_INTCONST);
             end
           else if CurrentScanner.preproc_token = _CSTRING then
             begin
               result:=TExprValue.create_str(CurrentScanner.preproc_pattern);
               preproc_consume(_CSTRING);
             end
           else if CurrentScanner.preproc_token = _REALNUMBER then
             begin
               result:=TExprValue.try_parse_real(CurrentScanner.preproc_pattern);
               if not Assigned(result) then
                 begin
                   Message(parser_e_error_in_real);
                   result:=TExprValue.create_real(1.0);
                 end;
               preproc_consume(_REALNUMBER);
             end
           else if CurrentScanner.preproc_token = _MINUS then
             begin
               preproc_consume(_MINUS);
               exprvalue:=preproc_factor(eval);
               if eval then
                 result:=exprvalue.evaluate(nil,_MINUS)
               else if exprvalue.isInt then
                 result:=TExprValue.create_int(-exprvalue.asInt)
               else if is_fpu(exprvalue.def) then
                 result:=TExprValue.create_real(-PBestReal(exprvalue.value.valueptr)^)
               else
                 Message(scan_e_error_in_preproc_expr);
               exprvalue.free;
               exprvalue := nil;
             end
           else
             Message(scan_e_error_in_preproc_expr);
           if not Assigned(result) then
             result:=TExprValue.create_error;
        end;

        function preproc_sub_expr(pred_level:TOperatorPrecedence;eval:Boolean): TExprValue;
        var
          hs1,hs2: TExprValue;
          op: TToken;
        begin
           if pred_level=highest_precedence then
             result:=preproc_factor(eval)
           else
             result:=preproc_sub_expr(succ(pred_level),eval);
          repeat
            op:=CurrentScanner.preproc_token;
            if (op in preproc_operators) and
               (op in operator_levels[pred_level]) then
             begin
               hs1:=result;
               preproc_consume(op);
               if (op=_OP_OR) and hs1.isBoolean and hs1.asBool then
                 begin
                   { stop evaluation the rest of expression }
                   result:=TExprValue.create_bool(true);
                   if pred_level=highest_precedence then
                     hs2:=preproc_factor(false)
                   else
                     hs2:=preproc_sub_expr(succ(pred_level),false);
                 end
               else if (op=_OP_AND) and hs1.isBoolean and not hs1.asBool then
                 begin
                   { stop evaluation the rest of expression }
                   result:=TExprValue.create_bool(false);
                   if pred_level=highest_precedence then
                     hs2:=preproc_factor(false)
                   else
                     hs2:=preproc_sub_expr(succ(pred_level),false);
                 end
               else
                 begin
                   if pred_level=highest_precedence then
                     hs2:=preproc_factor(eval)
                   else
                     hs2:=preproc_sub_expr(succ(pred_level),eval);
                   if eval then
                     result:=hs1.evaluate(hs2,op)
                   else
                     result:=TExprValue.create_bool(false); {Just to have something}
                 end;
               hs1.free;
               hs1 := nil;
               hs2.free;
               hs2 := nil;
             end
           else
             break;
          until false;
        end;

     begin
       CurrentScanner.in_preproc_comp_expr:=true;
       CurrentScanner.skipspace;
       { start preproc expression scanner }
       CurrentScanner.preproc_token:=CurrentScanner.readpreproc;
       preproc_comp_expr:=preproc_sub_expr(opcompare,true);
       CurrentScanner.in_preproc_comp_expr:=false;
     end;

    function boolean_compile_time_expr(var valuedescr: string): Boolean;
      var
        hs: TExprValue;
      begin
        hs:=preproc_comp_expr(nil);
        if hs.isBoolean then
          result:=hs.asBool
        else
          begin
            hs.error('Boolean', 'IF or ELSEIF');
            result:=false;
          end;
        valuedescr:=hs.asStr;
        hs.free;
        hs := nil;
      end;

    procedure dir_if;
      begin
        CurrentScanner.ifpreprocstack(pp_if,@boolean_compile_time_expr, scan_c_if_found);
      end;

    procedure dir_elseif;
      begin
        CurrentScanner.elseifpreprocstack(@boolean_compile_time_expr);
      end;

    procedure dir_define_impl(macstyle: boolean);
      var
        hs  : string;
        bracketcount : LongInt;
        mac : TMacro;
        macropos : SizeInt;
        macrobuffer : array[0..maxmacrolen-1] of char;
      begin
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        if hs='' then
          begin
            Message(scan_e_emptymacroname);
            exit;
          end;
        if upper(hs)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'DEFINE '+hs+' (selected by compiler string mode)');
            exit;
          end;
        mac:=TMacro(search_macro(hs));
        if not Assigned(mac) or (mac.owner <> CurrentModule.localmacrosymtable) then
          begin
            mac:=TMacro.create(hs);
            mac.defined:=true;
            CurrentModule.localmacrosymtable.insertsym(mac);
          end
        else
          begin
            mac.defined:=true;
            mac.is_compiler_var:=false;
          { delete old definition }
            mac.free_buftext;
          end;
        Message1(parser_c_macro_defined,mac.name);
        mac.is_used:=true;
        if (cs_support_macro in CurrentSettings.ModuleSwitches) then
          begin
             CurrentScanner.skipspace;

             if not macstyle then
               begin
                 { may be a macro? }
                 if CurrentScanner.c <> ':' then
                   exit;
                 CurrentScanner.readchar;
                 if CurrentScanner.c <> '=' then
                   exit;
                 mac.is_c_macro:=true;
                 CurrentScanner.readchar;
                 CurrentScanner.skipspace;
               end
             else
               { $definec always defines a text-substitution (C-style) macro }
               mac.is_c_macro:=true;

             { key words are never substituted }
             if is_keyword(hs) then
               Message(scan_e_keyword_cant_be_a_macro);

             CurrentScanner.gettokenpos;
             mac.fileinfo:=CurrentTokenPos;

             macropos:=0;
             { parse macro, brackets are counted so it's possible
               to have a $ifdef etc. in the macro }
             bracketcount:=0;
             repeat
               case CurrentScanner.c of
                 '}' :
                   if (bracketcount=0) then
                    break
                   else
                    dec(bracketcount);
                 '{' :
                   inc(bracketcount);
                 #10,#13 :
                   CurrentScanner.linebreak;
                 #26 :
                   CurrentScanner.end_of_file;
               end;
               if macropos>=maxmacrolen then
                 Message(scan_f_macro_buffer_overflow);
               macrobuffer[macropos]:=CurrentScanner.c;
               inc(macropos);
               CurrentScanner.readchar;
             until false;

             { copy the text }
             if macropos>0 then
               move(pchar(@macrobuffer[0])^,mac.allocate_buftext(macropos)^,macropos);
          end
        else
          begin
           { check if there is an assignment, then we need to give a
             warning }
             CurrentScanner.skipspace;
             if CurrentScanner.c=':' then
              begin
                CurrentScanner.readchar;
                if CurrentScanner.c='=' then
                  Message(scan_w_macro_support_turned_off);
              end;
          end;
      end;

    procedure dir_define;
      begin
        dir_define_impl(false);
      end;

    procedure dir_definec;
      begin
        dir_define_impl(true);
      end;

    procedure dir_setc;
      var
        hs  : string;
        mac : TMacro;
        exprvalue: TExprValue;
      begin
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        if upper(hs)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'SETC '+hs+' (selected by compiler string mode)');
            exit;
          end;
        mac:=TMacro(search_macro(hs));
        if not Assigned(mac) or
           (mac.owner <> CurrentModule.localmacrosymtable) then
          begin
            mac:=TMacro.create(hs);
            mac.defined:=true;
            mac.is_compiler_var:=true;
            CurrentModule.localmacrosymtable.insertsym(mac);
          end
        else
          begin
            mac.defined:=true;
            mac.is_compiler_var:=true;
          { delete old definition }
            mac.free_buftext;
          end;
        Message1(parser_c_macro_defined,mac.name);
        mac.is_used:=true;

        { key words are never substituted }
        if is_keyword(hs) then
          Message(scan_e_keyword_cant_be_a_macro);

        { macro assignment can be both := and = }
        CurrentScanner.skipspace;
        if CurrentScanner.c=':' then
          CurrentScanner.readchar;
        if CurrentScanner.c='=' then
          begin
             CurrentScanner.readchar;
             exprvalue:=preproc_comp_expr(nil);
             if not is_boolean(exprvalue.def) and
                not is_integer(exprvalue.def) then
               exprvalue.error('Boolean, Integer', 'SETC');
             hs:=exprvalue.asStr;

             if length(hs) <> 0 then
               begin
                 {If we are absolutely sure it is boolean, translate
                  to TRUE/FALSE to increase possibility to do future type check}
                 if exprvalue.isBoolean then
                   begin
                     if exprvalue.asBool then
                       hs:='TRUE'
                     else
                       hs:='FALSE';
                   end;
                 Message2(parser_c_macro_set_to,mac.name,hs);
                 { copy the text }
                 move(hs[1],mac.allocate_buftext(length(hs))^,length(hs));
               end
             else
               Message(scan_e_preproc_syntax_error);
             exprvalue.free;
             exprvalue := nil;
          end
        else
          Message(scan_e_preproc_syntax_error);
      end;


    procedure dir_undef;
      var
        hs  : string;
        mac : TMacro;
      begin
        CurrentScanner.skipspace;
        hs:=CurrentScanner.readid;
        if upper(hs)='FPC_UNICODESTRINGS' then
          begin
            Message1(scan_e_illegal_directive,'UNDEF '+hs+' (selected by compiler string mode)');
            exit;
          end;
        mac:=TMacro(search_macro(hs));
        if not Assigned(mac) or
           (mac.owner <> CurrentModule.localmacrosymtable) then
          begin
             mac:=TMacro.create(hs);
             mac.defined:=false;
             CurrentModule.localmacrosymtable.insertsym(mac);
          end
        else
          begin
             mac.defined:=false;
             mac.is_compiler_var:=false;
             mac.is_c_macro:=false;
             { delete old definition }
             mac.free_buftext;
          end;
        Message1(parser_c_macro_undefined,mac.name);
        mac.is_used:=true;
      end;


    procedure dir_include;
      var
        foundfile : TCmdStr;
        path,
        name,
        hs    : TPathStr;
        args  : string;
        hp    : TInputFile;
        found : boolean;
        macroIsString : boolean;
        fileext: string;
      begin
        CurrentScanner.skipspace;
        args:=CurrentScanner.readcomment;
        hs:=GetToken(args,' ');
        if hs='' then
         exit;
        if (hs[1]='%') then
         begin
         { case insensitive }
           hs:=upper(hs);
         { remove %'s }
           Delete(hs,1,1);
           if hs[length(hs)]='%' then
            Delete(hs,length(hs),1);
         { save old }
           path:=hs;
         { first check for internal macros }
           macroIsString:=true;
           case hs of
             'TIME':
               if TimeStr<>'' then
                 hs:=TimeStr
               else
                 hs:=GetTimeStr;
             'DATE':
               if DateStr<>'' then
                 hs:=DateStr
               else
                 hs:=GetDateStr;
             'DATEYEAR':
               begin
                 hs:=ToStr(StartSysTime.Year);
                 macroIsString:=false;
               end;
             'DATEMONTH':
               begin
                 hs:=ToStr(StartSysTime.Month);
                 macroIsString:=false;
               end;
             'DATEDAY':
               begin
                 hs:=ToStr(StartSysTime.Day);
                 macroIsString:=false;
               end;
             'TIMEHOUR':
               begin
                 hs:=ToStr(StartSysTime.Hour);
                 macroIsString:=false;
               end;
             'TIMEMINUTE':
               begin
                 hs:=ToStr(StartSysTime.Minute);
                 macroIsString:=false;
               end;
             'TIMESECOND':
               begin
                 hs:=ToStr(StartSysTime.Second);
                 macroIsString:=false;
               end;
             'FILE':
               hs:=CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex);
             'LINE':
               hs:=ToStr(CurrentFilePos.line);
             'LINENUM':
               begin
                 hs:=ToStr(CurrentFilePos.line);
                 macroIsString:=false;
               end;
             'FPCVERSION':
               hs:=Version_String;
             'FPCDATE':
               hs:=DateString;
             'FPCTARGET':
               hs:=TargetCPUString;
             'FPCTARGETCPU':
               hs:=TargetCPUString;
             'FPCTARGETOS':
               hs:=TargetInfo.shortname;
             'CURRENTROUTINE':
               hs:=CurrentProcInfo.procdef.procsym.RealName;
             else
               hs:=GetEnvironmentVariable(hs);
           end;
           if hs='' then
            Message1(scan_w_include_env_not_found,path);
           { make it a stringconst }
           if macroIsString then
             hs:=''''+hs+'''';
           CurrentScanner.substitutemacro(path,@hs[1],length(hs),
             CurrentScanner.line_no,CurrentScanner.inputfile.RefIndex,false);
         end
        else
         begin
           hs:=FixFileName(hs);
           path:=ExtractFilePath(hs);
           name:=ExtractFileName(hs);
           { Special case for Delphi compatibility: '*' has to be replaced
             by the file name of the current source file.  }
           if (length(name)>=1) and
              (name[1]='*') then
             name:=ChangeFileExt(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex),'')+ExtractFileExt(name);

           { try to find the file }
           found:=findincludefile(path,name,foundfile);
           fileext:=lower(ExtractFileExt(name));
           if (not found) and ((fileext<>'.inc') and (fileext<>SourceExt)) then
            begin
              { try default extensions .inc and .pas }
              if (not found) then
               found:=findincludefile(path,name+'.inc',foundfile);
              if (not found) then
               found:=findincludefile(path,name+SourceExt,foundfile);
            end;
           { if the name ends in dot, try without the dot }
           if (not found) and (ExtractFileExt(name)=ExtensionSeparator) and (Length(name)>=2) then
             found:=findincludefile(path,Copy(name,1,Length(name)-1),foundfile);
           if CurrentScanner.inputfilecount<max_include_nesting then
             begin
               inc(CurrentScanner.inputfilecount);
               { we need to reread the current char }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
               CurrentScanner.dec_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
               dec(CurrentScanner.inputpointer);
{$endif  CHECK_INPUTPOINTER_LIMITS}
               { reset c }
               CurrentScanner.c:=#0;
               { shutdown current file }
               CurrentScanner.tempcloseinputfile;
               { load new file }
               hp:=Do_OpenInputFile(foundfile);
               hp.IncPath:=path;
               CurrentScanner.addfile(hp);
               CurrentModule.SourceFiles.Register_File(hp);
               if (not found) then
                Message1(scan_f_cannot_open_includefile,hs);
              if (not CurrentScanner.openinputfile) then
                Message1(scan_f_cannot_open_includefile,hs);
               Message1(scan_t_start_include_file,CurrentScanner.inputfile.path+CurrentScanner.inputfile.name);
               CurrentScanner.reload;
             end
           else
             Message(scan_f_include_deep_ten);
         end;
      end;

{*****************************************************************************
                            Preprocessor writing
*****************************************************************************}

{$ifdef PREPROCWRITE}
    constructor TPreProcFile.create(const fn:string);
      begin
        inherited create;
      { open outputfile }
        assign(f,fn);
        {$push}{$I-}
         rewrite(f);
        {$pop}
        if IOResult<>0 then
         Comment(VFatal,'can''t create file '+fn);
        SetLength(buf,preprocbufsize);
        settextbuf(f,buf[0],preprocbufsize);
      { reset }
        eolfound:=false;
        spacefound:=false;
      end;


    destructor TPreProcFile.Destroy;
      begin
        close(f);
        buf:=nil;
      end;


    procedure TPreProcFile.add(const s:string);
      begin
        write(f,s);
      end;

    procedure TPreProcFile.addspace;
      begin
        if eolfound then
         begin
           WriteLn(f,'');
           eolfound:=false;
           spacefound:=false;
         end
        else
         if spacefound then
          begin
            write(f,' ');
            spacefound:=false;
          end;
      end;
{$endif PREPROCWRITE}


{*****************************************************************************
                              TPreProcStack
*****************************************************************************}

    constructor TPreProcStack.create(atyp : TPreProcType;a:boolean;n:TPreProcStack);
      begin
        accept:=a;
        typ:=atyp;
        next:=n;
      end;

{*****************************************************************************
                              TReplayStack
*****************************************************************************}
    constructor TReplayStack.Create(atoken:TToken;aidtoken:TToken;
      const aorgpattern,apattern:ShortString;const acstringpattern:AnsiString;
      apatternw:TCompilerWideString;asettings:TSettings;
      atokenbuf:TDynamicArray;ChangeEndian:boolean;const apending:TPendingState;
      averbosity:LongInt;anext:TReplayStack);
      begin
        token:=atoken;
        idtoken:=aidtoken;
        orgpattern:=aorgpattern;
        pattern:=apattern;
        cstringpattern:=acstringpattern;
        InitWideString(patternw);
        if Assigned(apatternw) then
          begin
            CopyWideString(patternw,apatternw);
          end;
        settings:=asettings;
        pending:=apending;
        verbosity:=averbosity;
        tokenbuf:=atokenbuf;
        tokenbuf_needs_swapping:=ChangeEndian;
        next:=anext;
      end;


    destructor TReplayStack.Destroy;
      begin
        DoneWideString(patternw);
      end;

{*****************************************************************************
                              TDirectiveItem
*****************************************************************************}

    constructor TDirectiveItem.Create(AList:TFPHashObjectList;const n:string;p:TDirectiveProc);
      begin
        inherited Create(AList,n);
        is_conditional:=false;
        proc:=p;
      end;


    constructor TDirectiveItem.CreateCond(AList:TFPHashObjectList;const n:string;p:TDirectiveProc);
      begin
        inherited Create(AList,n);
        is_conditional:=true;
        proc:=p;
      end;

{****************************************************************************
                                TSCANNERFILE
 ****************************************************************************}

    constructor TScannerFile.Create(const fn: string; IsMacro: boolean);
      begin
        inputfile:=Do_OpenInputFile(fn);
        if IsMacro then
          inputfile.IsMacro:=true;
        if Assigned(CurrentModule) then
          CurrentModule.SourceFiles.Register_File(inputfile);
      { reset localinput }
        c:=#0;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        hidden_inputbuffer:=nil;
        hidden_inputpointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputbuffer:=nil;
        inputpointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputstart:=0;
      { reset scanner }
        preprocstack:=nil;
        replaystack:=nil;
        comment_level:=0;
        yylexcount:=0;
        Block_Type:=bt_general;
        line_no:=0;
        lastlinepos:=0;
        lasttokenpos:=0;
        nexttokenpos:=0;
        lasttoken:=NOTOKEN;
        nexttoken:=NOTOKEN;
        ignoredirectives:=TFPHashList.Create;
        change_endian_for_replay:=false;
        InitWideString(patternw);
      end;


    procedure TScannerFile.firstfile;
      begin
      { load block }
        if not openinputfile then
          Message1(scan_f_cannot_open_input,inputfile.name);
        reload;
      end;


    destructor TScannerFile.Destroy;
      begin
        if Assigned(OnFreeScanner) then
          OnFreeScanner(self);
        if Assigned(CurrentModule) and
           (CurrentModule.state in [ms_processed,ms_compiled]) and
           (status.ErrorCount=0) then
          checkpreprocstack
        else
          begin
            while Assigned(preprocstack) do
             poppreprocstack;
          end;
        while Assigned(replaystack) do
          popreplaystack;
        if not inputfile.closed then
          closeinputfile;
        if inputfile.IsMacro then
          begin
            inputfile.free;
            inputfile := nil;
          end;
        ignoredirectives.free;
        ignoredirectives := nil;
        DoneWideString(patternw);
      end;


    function TScannerFile.openinputfile:boolean;
      begin
        openinputfile:=inputfile.open;
      { load buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        hidden_inputbuffer:=PAnsiChar(inputfile.buf);
        hidden_inputpointer:=PAnsiChar(inputfile.buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputbuffer:=PAnsiChar(inputfile.buf);
        inputpointer:=PAnsiChar(inputfile.buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputstart:=inputfile.BufStart;
      { line }
        line_no:=0;
        lastlinepos:=0;
        lasttokenpos:=0;
        nexttokenpos:=0;
      end;


    procedure TScannerFile.closeinputfile;
      begin
        inputfile.close;
      { reset buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        hidden_inputbuffer:=nil;
        hidden_inputpointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputbuffer:=nil;
        inputpointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputstart:=0;
      { reset line }
        line_no:=0;
        lastlinepos:=0;
        lasttokenpos:=0;
        nexttokenpos:=0;
      end;


    function TScannerFile.tempopeninputfile:boolean;
      begin
        tempopeninputfile:=false;
        if inputfile.IsMacro then
          exit;
        tempopeninputfile:=inputfile.TempOpen;
      { reload buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        hidden_inputbuffer:=PAnsiChar(inputfile.buf);
        hidden_inputpointer:=PAnsiChar(inputfile.buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputbuffer:=PAnsiChar(inputfile.buf);
        inputpointer:=PAnsiChar(inputfile.buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputstart:=inputfile.BufStart;
      end;


    procedure TScannerFile.tempcloseinputfile;
      begin
        if inputfile.closed or inputfile.IsMacro then
         exit;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        inputfile.setpos(inputstart+(hidden_inputpointer-hidden_inputbuffer));
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputfile.setpos(inputstart+(inputpointer-inputbuffer));
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputfile.TempClose;
      { reset buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        hidden_inputbuffer:=nil;
        hidden_inputpointer:=nil;
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputbuffer:=nil;
        inputpointer:=nil;
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputstart:=0;
      end;


    procedure TScannerFile.saveinputfile;
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        inputfile.SaveInputPointer:=hidden_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        inputfile.SaveInputPointer:=inputpointer;
{$endif CHECK_INPUTPOINTER_LIMITS}
        inputfile.SaveLastLinePos:=lastlinepos;
        inputfile.SaveLineNo:=line_no;
      end;


    procedure TScannerFile.restoreinputfile;
      begin
{$ifdef check_inputpointer_limits}
        hidden_inputbuffer:=PAnsiChar(inputfile.buf);
        hidden_inputpointer:=inputfile.SaveInputPointer;
{$else not check_inputpointer_limits}
        inputbuffer:=PAnsiChar(inputfile.buf);
        inputpointer:=inputfile.SaveInputPointer;
{$endif check_inputpointer_limits}
        lastlinepos:=inputfile.SaveLastLinePos;
        line_no:=inputfile.SaveLineNo;
        if not inputfile.IsMacro then
          Parser_Current_File:=inputfile.name;
      end;


    procedure TScannerFile.nextfile;
      var
        to_dispose : TInputFile;
      begin
        if Assigned(inputfile.next) then
         begin
           if inputfile.IsMacro then
             begin
               to_dispose:=inputfile;
               dec(macro_nesting_depth);
             end
           else
             begin
               to_dispose:=nil;
               dec(inputfilecount);
             end;
           { we can always close the file, no ? }
           inputfile.close;
           inputfile:=inputfile.next;
           if Assigned(to_dispose) then
             to_dispose.free; // no nil needed
           restoreinputfile;
         end;
      end;


{$ifdef CHECK_INPUTPOINTER_LIMITS}
    function TScannerFile.get_inputpointer_char(offset : LongInt = 0) : char;
      begin
	assert(hidden_inputpointer-hidden_inputbuffer+offset<=inputfile.BufSize);
	get_inputpointer_char:=(hidden_inputpointer+offset)^;
      end;

    procedure TScannerFile.inc_inputpointer(amount : LongInt = 1);
      begin
        assert(hidden_inputpointer-hidden_inputbuffer+amount<=inputfile.BufSize);
        inc(hidden_inputpointer,amount);
      end;

    procedure TScannerFile.dec_inputpointer;
      begin
        assert(hidden_inputpointer>hidden_inputbuffer);
        dec(hidden_inputpointer);
      end;
{$endif}

    procedure TScannerFile.startrecordtokens(buf:TDynamicArray);
      begin
        if not Assigned(buf) then
          InternalError(200511172);
        if Assigned(recordtokenbuf) then
          InternalError(200511173);
        recordtokenbuf:=buf;
        fillchar(last_settings,sizeof(last_settings),0);
        last_message:=nil;
        fillchar(last_filepos,sizeof(last_filepos),0);
      end;


    procedure TScannerFile.stoprecordtokens;
      begin
        if not Assigned(recordtokenbuf) then
          InternalError(200511174);
        recordtokenbuf:=nil;
      end;

    function TScannerFile.is_recording_tokens: boolean;
      begin
        result:=Assigned(recordtokenbuf);
      end;


    procedure TScannerFile.writetoken(t : TToken);
      var
        b : byte;
      begin
        if ord(t)>$7f then
          begin
            b:=(ord(t) shr 8) or $80;
            recordtokenbuf.write(b,1);
          end;
        b:=ord(t) and $ff;
        recordtokenbuf.write(b,1);
      end;

    procedure TScannerFile.tokenwritesizeint(val : asizeint);
      begin
        recordtokenbuf.write(val,sizeof(asizeint));
      end;

    procedure TScannerFile.tokenwritelongint(val : LongInt);
      begin
        recordtokenbuf.write(val,sizeof(LongInt));
      end;

    procedure TScannerFile.tokenwriteshortint(val : shortint);
      begin
        recordtokenbuf.write(val,sizeof(shortint));
      end;

    procedure TScannerFile.tokenwritebyte(val : byte);
      begin
        recordtokenbuf.write(val,sizeof(byte));
      end;

    procedure TScannerFile.tokenwriteword(val : word);
      begin
        recordtokenbuf.write(val,sizeof(word));
      end;

    procedure TScannerFile.tokenwritelongword(val : LongWord);
      begin
        recordtokenbuf.write(val,sizeof(LongWord));
      end;

    function TScannerFile.tokenreadsizeint : asizeint;
      var
        val : asizeint;
      begin
        replaytokenbuf.read(val,sizeof(asizeint));
        if change_endian_for_replay then
          val:=swapendian(val);
        result:=val;
      end;

    function TScannerFile.tokenreadlongword : LongWord;
      var
        val : LongWord;
      begin
        replaytokenbuf.read(val,sizeof(LongWord));
        if change_endian_for_replay then
          val:=swapendian(val);
        result:=val;
      end;

    function TScannerFile.tokenreadlongint : LongInt;
      var
        val : LongInt;
      begin
        replaytokenbuf.read(val,sizeof(LongInt));
        if change_endian_for_replay then
          val:=swapendian(val);
        result:=val;
      end;

    function TScannerFile.tokenreadshortint : shortint;
      var
        val : shortint;
      begin
        replaytokenbuf.read(val,sizeof(shortint));
        result:=val;
      end;

    function TScannerFile.tokenreadbyte : byte;
      var
        val : byte;
      begin
        replaytokenbuf.read(val,sizeof(byte));
        result:=val;
      end;

    function TScannerFile.tokenreadsmallint : smallint;
      var
        val : smallint;
      begin
        replaytokenbuf.read(val,sizeof(smallint));
        if change_endian_for_replay then
          val:=swapendian(val);
        result:=val;
      end;

    function TScannerFile.tokenreadword : word;
      var
        val : word;
      begin
        replaytokenbuf.read(val,sizeof(word));
        if change_endian_for_replay then
          val:=swapendian(val);
        result:=val;
      end;

   function TScannerFile.tokenreadenum(size : LongInt) : LongWord;
   begin
     if size=1 then
       result:=tokenreadbyte
     else if size=2 then
       result:=tokenreadword
     else if size=4 then
       result:=tokenreadlongword
     else
       InternalError(2013112901);
   end;

   procedure TScannerFile.tokenreadset(var b;size : LongInt);
   var
     i : LongInt;
   begin
     replaytokenbuf.read(b,size);
     if change_endian_for_replay then
       for i:=0 to size-1 do
         PByte(@b)[i]:=Reverse_Byte(PByte(@b)[i]);
   end;

   procedure TScannerFile.tokenwriteenum(var b;size : LongInt);
   begin
     recordtokenbuf.write(b,size);
   end;

   procedure TScannerFile.tokenwriteset(var b;size : LongInt);
   begin
     recordtokenbuf.write(b,size);
   end;


    procedure TScannerFile.tokenreadsettings(var asettings : TSettings; expected_size : asizeint);

    {    This procedure
       needs to be changed whenever
       globals.tsettings type is changed,
       the problem is that no error will appear
       before tests with generics are tested. PM }

       var
         startpos, endpos : LongWord;
      begin
        { WARNING all those fields need to be in the correct
        order otherwise cross_endian PPU reading will fail }
        startpos:=replaytokenbuf.pos;
        with asettings do
          begin
            alignment.ProcAlign:=tokenreadlongint;
            alignment.LoopAlign:=tokenreadlongint;
            alignment.JumpAlign:=tokenreadlongint;
            alignment.JumpAlignSkipMax:=tokenreadlongint;
            alignment.CoalesceAlign:=tokenreadlongint;
            alignment.CoalesceAlignSkipMax:=tokenreadlongint;
            alignment.ConstAlignMin:=tokenreadlongint;
            alignment.ConstAlignMax:=tokenreadlongint;
            alignment.VarAlignMin:=tokenreadlongint;
            alignment.VarAlignMax:=tokenreadlongint;
            alignment.LocalAlignMin:=tokenreadlongint;
            alignment.LocalAlignMax:=tokenreadlongint;
            alignment.RecordAlignMin:=tokenreadlongint;
            alignment.RecordAlignMax:=tokenreadlongint;
            alignment.MaxCRecordAlign:=tokenreadlongint;
            tokenreadset(GlobalSwitches,sizeof(GlobalSwitches));
            tokenreadset(TargetSwitches,sizeof(TargetSwitches));
            tokenreadset(ModuleSwitches,sizeof(ModuleSwitches));
            tokenreadset(LocalSwitches,sizeof(LocalSwitches));
            tokenreadset(ModeSwitches,sizeof(ModeSwitches));
            tokenreadset(OptimizerSwitches,sizeof(OptimizerSwitches));
            tokenreadset(GenWPOptimizerSwitches,sizeof(GenWPOptimizerSwitches));
            tokenreadset(DoWPOptimizerSwitches,sizeof(DoWPOptimizerSwitches));
            tokenreadset(DebugSwitches,sizeof(DebugSwitches));
            { 0: old behaviour for sets <=256 elements
              >0: round to this size }
            SetAlloc:=tokenreadshortint;
            PackEnum:=tokenreadshortint;
            PackRecords:=tokenreadshortint;
            MaxFPURegisters:=tokenreadshortint;

            verbosity:=tokenreadlongint;

            CPUType:=TCPUType(tokenreadenum(sizeof(TCPUType)));
            OptimizeCPUType:=TCPUType(tokenreadenum(sizeof(TCPUType)));
            AsmCPUType:=TCPUType(tokenreadenum(sizeof(TCPUType)));
            FPUType:=TFPUType(tokenreadenum(sizeof(TFPUType)));
            AsmMode:=TAsmMode(tokenreadenum(sizeof(TAsmMode)));
            InterfaceType:=TInterfaceTypes(tokenreadenum(sizeof(TInterfaceTypes)));
            DefProcCall:=TProcCallOption(tokenreadenum(sizeof(TProcCallOption)));
            { tstringencoding is word type,
              thus this should be OK here }
            SourceCodePage:=TStringEncoding(tokenreadword);

            MinFPConstPrec:=TFloatType(tokenreadenum(sizeof(TFloatType)));

            DisableDirCache:=boolean(tokenreadbyte);

            TLSModel:=TTLSModel(tokenreadenum(sizeof(TTLSModel)));
{ TH: Since the field was conditional originally, it was not stored in PPUs.  }
{ While adding ControllerSupport constant, I decided not to store ct_none     }
{ on targets not supporting controllers, but this might be changed here and   }
{ in tokenwritesettings in the future to unify the PPU structure and handling }
{ of this field in the compiler.                                              }
{$PUSH}
 {$WARN 6018 OFF} (* Unreachable code due to compile time evaluation *)
            if ControllerSupport then
             ControllerType:=TControllerType(tokenreadenum(sizeof(TControllerType)))
            else
             ControllerType:=ct_none;
{$POP}
            LineEndingType:=TLineEndingType(tokenreadenum(sizeof(TLineEndingType)));
            WhitespaceTrimCount:=tokenreadword;
            WhitespaceTrimAuto:=boolean(tokenreadbyte);
           endpos:=replaytokenbuf.pos;
           if endpos-startpos<>expected_size then
             Comment(VError,'Wrong size of Settings read-in');
         end;
     end;

    procedure TScannerFile.tokenwritesettings(var asettings : TSettings; var size : asizeint);

    {    This procedure
       needs to be changed whenever
       globals.tsettings type is changed,
       the problem is that no error will appear
       before tests with generics are tested. PM }

       var
         sizepos, startpos, endpos : LongWord;
      begin
        { WARNING all those fields need to be in the correct
        order otherwise cross_endian PPU reading will fail }
        sizepos:=recordtokenbuf.pos;
        size:=0;
        tokenwritesizeint(size);
        startpos:=recordtokenbuf.pos;
        with asettings do
          begin
            tokenwritelongint(alignment.ProcAlign);
            tokenwritelongint(alignment.LoopAlign);
            tokenwritelongint(alignment.JumpAlign);
            tokenwritelongint(alignment.JumpAlignSkipMax);
            tokenwritelongint(alignment.CoalesceAlign);
            tokenwritelongint(alignment.CoalesceAlignSkipMax);
            tokenwritelongint(alignment.ConstAlignMin);
            tokenwritelongint(alignment.ConstAlignMax);
            tokenwritelongint(alignment.VarAlignMin);
            tokenwritelongint(alignment.VarAlignMax);
            tokenwritelongint(alignment.LocalAlignMin);
            tokenwritelongint(alignment.LocalAlignMax);
            tokenwritelongint(alignment.RecordAlignMin);
            tokenwritelongint(alignment.RecordAlignMax);
            tokenwritelongint(alignment.MaxCRecordAlign);
            tokenwriteset(GlobalSwitches,sizeof(GlobalSwitches));
            tokenwriteset(TargetSwitches,sizeof(TargetSwitches));
            tokenwriteset(ModuleSwitches,sizeof(ModuleSwitches));
            tokenwriteset(LocalSwitches,sizeof(LocalSwitches));
            tokenwriteset(ModeSwitches,sizeof(ModeSwitches));
            tokenwriteset(OptimizerSwitches,sizeof(OptimizerSwitches));
            tokenwriteset(GenWPOptimizerSwitches,sizeof(GenWPOptimizerSwitches));
            tokenwriteset(DoWPOptimizerSwitches,sizeof(DoWPOptimizerSwitches));
            tokenwriteset(DebugSwitches,sizeof(DebugSwitches));
            { 0: old behaviour for sets <=256 elements
              >0: round to this size }
            tokenwriteshortint(SetAlloc);
            tokenwriteshortint(PackEnum);
            tokenwriteshortint(PackRecords);
            tokenwriteshortint(MaxFPURegisters);
            tokenwritelongint(verbosity);

            tokenwriteenum(CPUType,sizeof(TCPUType));
            tokenwriteenum(OptimizeCPUType,sizeof(TCPUType));
            tokenwriteenum(AsmCPUType,sizeof(TCPUType));
            tokenwriteenum(FPUType,sizeof(TFPUType));
            tokenwriteenum(AsmMode,sizeof(TAsmMode));
            tokenwriteenum(InterfaceType,sizeof(TInterfaceTypes));
            tokenwriteenum(DefProcCall,sizeof(TProcCallOption));
            { tstringencoding is word type,
              thus this should be OK here }
            tokenwriteword(SourceCodePage);

            tokenwriteenum(MinFPConstPrec,sizeof(TFloatType));

            recordtokenbuf.write(byte(DisableDirCache),1);

            tokenwriteenum(TLSModel,sizeof(TLSModel));

{ TH: See note about controllertype field in tokenreadsettings. }
{$PUSH}
 {$WARN 6018 OFF} (* Unreachable code due to compile time evaluation *)
            if ControllerSupport then
              tokenwriteenum(ControllerType,sizeof(TControllerType));
{$POP}
            tokenwriteenum(LineEndingType,sizeof(TLineEndingType));
            tokenwriteword(WhitespaceTrimCount);
            tokenwritebyte(byte(WhitespaceTrimAuto));
           endpos:=recordtokenbuf.pos;
           size:=endpos-startpos;
           recordtokenbuf.seek(sizepos);
           tokenwritesizeint(size);
           recordtokenbuf.seek(endpos);
         end;
     end;


    procedure TScannerFile.recordtoken;
      var
        t : TToken;
        s : TSpecialGenericToken;
        len,msgnb,copy_size : asizeint;
        val : LongInt;
        b : byte;
        PMsg : PMessageStateRecord;
      begin
        if not Assigned(recordtokenbuf) then
          InternalError(200511176);
        t:=_GENERICSPECIALTOKEN;
        { ensure that all fields of settings are up to date }
        CurrentSettings.verbosity:=status.verbosity;
        { settings changed? }
        { last field pmessage is handled separately below in
          ST_LOADMESSAGES }
        if CompareByte(CurrentSettings,last_settings,
             sizeof(CurrentSettings)-sizeof(pointer))<>0 then
          begin
            { use a special token to record it }
            s:=ST_LOADSETTINGS;
            writetoken(t);
            recordtokenbuf.write(s,1);
            copy_size:=sizeof(CurrentSettings)-sizeof(pointer);
            tokenwritesettings(CurrentSettings,copy_size);
            last_settings:=CurrentSettings;
          end;

        if CurrentSettings.PMessage<>last_message then
          begin
            { use a special token to record it }
            s:=ST_LOADMESSAGES;
            writetoken(t);
            recordtokenbuf.write(s,1);
            msgnb:=0;
            PMsg:=CurrentSettings.PMessage;
            while Assigned(PMsg) do
              begin
                if msgnb=high(asizeint) then
                  { Too many messages }
                  InternalError(2011090401);
                inc(msgnb);
                PMsg:=PMsg^.next;
              end;
            tokenwritesizeint(msgnb);
            PMsg:=CurrentSettings.PMessage;
            while Assigned(PMsg) do
              begin
                { What about endianess here?}
                { SB: this is handled by tokenreadlongint }
                val:=PMsg^.value;
                tokenwritelongint(val);
                val:=ord(PMsg^.state);
                tokenwritelongint(val);
                PMsg:=PMsg^.next;
              end;
            last_message:=CurrentSettings.PMessage;
          end;

        { file pos changes? }
        if CurrentTokenPos.fileindex<>last_filepos.fileindex then
          begin
            s:=ST_FILEINDEX;
            writetoken(t);
            recordtokenbuf.write(s,1);
            tokenwriteword(CurrentTokenPos.fileindex);
            last_filepos.fileindex:=CurrentTokenPos.fileindex;
            last_filepos.line:=0;
          end;
        if CurrentTokenPos.line<>last_filepos.line then
          begin
            s:=ST_LINE;
            writetoken(t);
            recordtokenbuf.write(s,1);
            tokenwritelongint(CurrentTokenPos.line);
            last_filepos.line:=CurrentTokenPos.line;
            last_filepos.column:=0;
          end;
        if CurrentTokenPos.column<>last_filepos.column then
          begin
            s:=ST_COLUMN;
            writetoken(t);
            { can the column be written packed? }
            if CurrentTokenPos.column<$80 then
              begin
                b:=$80 or CurrentTokenPos.column;
                recordtokenbuf.write(b,1);
              end
            else
              begin
                recordtokenbuf.write(s,1);
                tokenwriteword(CurrentTokenPos.column);
              end;
            last_filepos.column:=CurrentTokenPos.column;
          end;

        writetoken(token);
        if token<>_GENERICSPECIALTOKEN then
          writetoken(idtoken);
        case token of
          _CWCHAR,
          _CWSTRING :
            begin
              tokenwritesizeint(patternw.len);
              if patternw.len>0 then
                recordtokenbuf.write(patternw.data[0],patternw.len*sizeof(TCompilerWideChar));
            end;
          _CSTRING:
            begin
              len:=length(cstringpattern);
              tokenwritesizeint(len);
              if len>0 then
                recordtokenbuf.write(cstringpattern[1],len);
            end;
          _CCHAR,
          _INTCONST,
          _REALNUMBER :
            begin
              { pexpr.pas messes with pattern in case of negative integer consts,
                see around line 2562 the comment of JM; remove the - before recording it
                                                     (FK)
              }
              if (token=_INTCONST) and (pattern[1]='-') then
                delete(pattern,1,1);
              recordtokenbuf.write(pattern[0],1);
              recordtokenbuf.write(pattern[1],length(pattern));
            end;
          _ID :
            begin
              recordtokenbuf.write(orgpattern[0],1);
              recordtokenbuf.write(orgpattern[1],length(orgpattern));
            end;
          else
            ;
        end;
      end;


    procedure TScannerFile.startreplaytokens(buf:TDynamicArray; ChangeEndian:boolean);
      begin
        if not Assigned(buf) then
          InternalError(200511175);

        { save current scanner state }
        replaystack:=TReplayStack.create(token,idtoken,orgpattern,pattern,
          cstringpattern,patternw,CurrentSettings,replaytokenbuf,change_endian_for_replay,
          PendingState,status.verbosity,replaystack);
{$ifdef check_inputpointer_limits}
        if Assigned(hidden_inputpointer) then
          dec_inputpointer;
{$else not check_inputpointer_limits}
        if Assigned(inputpointer) then
          dec(inputpointer);
{$endif check_inputpointer_limits}
        { install buffer }
        replaytokenbuf:=buf;

        { ensure that existing message state records won't be freed }
        CurrentSettings.PMessage:=nil;
        PendingState:=default(TPendingState);

        { Initialize value of change_endian_for_replay variable }
        change_endian_for_replay:=ChangeEndian;

        { reload next token }
        replaytokenbuf.seek(0);
        replaytoken;
      end;


    function TScannerFile.readtoken: TToken;
      var
        b,b2 : byte;
      begin
        replaytokenbuf.read(b,1);
        if (b and $80)<>0 then
          begin
            replaytokenbuf.read(b2,1);
            result:=TToken(((b and $7f) shl 8) or b2);
          end
        else
          result:=TToken(b);
      end;


    procedure TScannerFile.replaytoken;
      var
        wlen,mesgnb,copy_size : asizeint;
        specialtoken : TSpecialGenericToken;
        i : byte;
        PMsg,prevmsg : PMessageStateRecord;
        msgset : THashSet;
        msgfound : boolean;
      begin
        if not Assigned(replaytokenbuf) then
          InternalError(200511177);
        { End of replay buffer? Then load the next char from the file again }
        if replaytokenbuf.pos>=replaytokenbuf.size then
          begin
            token:=replaystack.token;
            idtoken:=replaystack.idtoken;
            pattern:=replaystack.pattern;
            orgpattern:=replaystack.orgpattern;
            CopyWideString(replaystack.patternw,patternw);
            cstringpattern:=replaystack.cstringpattern;
            replaytokenbuf:=replaystack.tokenbuf;
            change_endian_for_replay:=replaystack.tokenbuf_needs_swapping;
            { restore compiler settings }
            CurrentSettings:=replaystack.settings;
            PendingState:=replaystack.pending;
            if Assigned(PendingState.NextMessageRecord) then
              FreeLocalVerbosity(PendingState.NextMessageRecord);
            RecordPendingVerbosityFullSwitch(replaystack.verbosity);
            PendingState.NextMessageRecord:=CurrentSettings.PMessage;
            CurrentSettings.PMessage:=nil;
            popreplaystack;
{$ifdef check_inputpointer_limits}
            if Assigned(hidden_inputpointer) then
              begin
                c:=get_inputpointer_char;
                inc_inputpointer;
              end;
{$else not check_inputpointer_limits}
            if Assigned(inputpointer) then
              begin
                c:=inputpointer^;
                inc(inputpointer);
              end;
{$endif check_inputpointer_limits}
            exit;
          end;
        repeat
          { load token from the buffer }
          token:=readtoken;
          if token<>_GENERICSPECIALTOKEN then
            idtoken:=readtoken
          else
            idtoken:=_NOID;
          case token of
            _CWCHAR,
            _CWSTRING :
              begin
                wlen:=tokenreadsizeint;
                SetLengthWideString(patternw,wlen);
                if wlen>0 then
                  replaytokenbuf.read(patternw.data[0],patternw.len*sizeof(TCompilerWideChar));
                orgpattern:='';
                pattern:='';
                cstringpattern:='';
              end;
            _CSTRING:
              begin
                wlen:=tokenreadsizeint;
                if wlen>0 then
                  begin
                    SetLength(cstringpattern,wlen);
                    replaytokenbuf.read(cstringpattern[1],wlen);
                  end
                else
                  cstringpattern:='';
                orgpattern:='';
                pattern:='';
              end;
            _CCHAR,
            _INTCONST,
            _REALNUMBER :
              begin
                replaytokenbuf.read(pattern[0],1);
                replaytokenbuf.read(pattern[1],length(pattern));
                orgpattern:='';
              end;
            _ID :
              begin
                replaytokenbuf.read(orgpattern[0],1);
                replaytokenbuf.read(orgpattern[1],length(orgpattern));
                pattern:=upper(orgpattern);
              end;
            _GENERICSPECIALTOKEN:
              begin
                replaytokenbuf.read(specialtoken,1);
                { packed column? }
                if (ord(specialtoken) and $80)<>0 then
                  begin
                      CurrentTokenPos.column:=ord(specialtoken) and $7f;
                      CurrentFilePos:=CurrentTokenPos;
                  end
                else
                  case specialtoken of
                    ST_LOADSETTINGS:
                      begin
                        copy_size:=tokenreadsizeint;
                        //if copy_size <> sizeof(current_settings)-sizeof(pointer) then
                        //  internalerror(2011090501);
                        {
                        replaytokenbuf.read(current_settings,copy_size);
                        }
                        tokenreadsettings(CurrentSettings,copy_size);
                        { Generic token buffers carry the defining unit's
                          settings. Their saved text defaults cannot override
                          the compiler invocation's String/Char/PChar model. }
                        HandleModeSwitches(m_default_ansistring,false);
                        RecordPendingVerbosityFullSwitch(CurrentSettings.verbosity);
                      end;
                    ST_LOADMESSAGES:
                      begin
                        { free current and pending messages }
                        FreeLocalVerbosity(CurrentSettings.PMessage);
                        FreeLocalVerbosity(PendingState.NextMessageRecord);
                        { the message settings are stored from newest to oldest
                          change for the whole stack, so we only want to apply
                          the newest changes for each message type }
                        mesgnb:=tokenreadsizeint;
                        msgset:=THashSet.create(min(mesgnb,10),false,false);
                        prevmsg:=nil;
                        PMsg:=nil;
                        for i:=1 to mesgnb do
                          begin
                            if not Assigned(PMsg) then
                              begin
                                new(PMsg);
                                {$IFDEF DEBUG_MESSAGESTATE}
                                if CurrentModule=nil then
                                  InternalError(2026030704);
                                PMsg^.owner:=CurrentModule;
                                {$ENDIF}
                              end;
                            PMsg^.value:=tokenreadlongint;
                            PMsg^.state:=TMsgState(tokenreadlongint);
                            PMsg^.next:=nil;
                            msgfound:=false;
                            if Assigned(msgset.findoradd(@PMsg^.value,sizeof(PMsg^.value),msgfound)) and msgfound then
                              continue;
                            if i=1 then
                              PendingState.NextMessageRecord:=PMsg
                            else
                              prevmsg^.next:=PMsg;
                            prevmsg:=PMsg;
                            PMsg:=nil;
                          end;
                        if Assigned(PMsg) then
                          dispose(PMsg);
                        msgset.free;
                        msgset := nil;
                      end;
                    ST_LINE:
                      begin
                        CurrentTokenPos.line:=tokenreadlongint;
                        CurrentFilePos:=CurrentTokenPos;
                      end;
                    ST_COLUMN:
                      begin
                        CurrentTokenPos.column:=tokenreadword;
                        CurrentFilePos:=CurrentTokenPos;
                      end;
                    ST_FILEINDEX:
                      begin
                        CurrentTokenPos.fileindex:=tokenreadword;
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


    procedure TScannerFile.addfile(hp:TInputFile);
      begin
        saveinputfile;
        { add to list }
        hp.next:=inputfile;
        inputfile:=hp;
        { load new inputfile }
        restoreinputfile;
      end;


    procedure TScannerFile.reload;
      var
        wasmacro: Boolean;
      begin
        with inputfile do
         begin
           { when nothing more to read then leave immediately, so we
             don't change the current_filepos and leave it point to the last
             char }
           if (c=#26) and (not Assigned(next)) then
            exit;
           repeat
           { still more to read?, then change the #0 to a space so its seen
             as a separator, this can't be used for macro's which can change
             the place of the #0 in the buffer with tempopen }
             if (c=#0) and (BufSize>0) and
                not(inputfile.IsMacro) and
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                (hidden_inputpointer-hidden_inputbuffer<BufSize) then
{$else not CHECK_INPUTPOINTER_LIMITS}
                (inputpointer-inputbuffer<BufSize) then
{$endif CHECK_INPUTPOINTER_LIMITS}
              begin
                c:=' ';
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
                exit;
              end;
           { can we read more from this file ? }
             if (c<>#26) and (not EndOfFile) then
              begin
                ReadBuf;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                hidden_inputpointer:=PAnsiChar(buf);
                hidden_inputbuffer:=PAnsiChar(buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
                inputpointer:=PAnsiChar(buf);
                inputbuffer:=PAnsiChar(buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
                inputstart:=BufStart;
              { first line? }
                if line_no=0 then
                 begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                   c:=get_inputpointer_char;
                   { eat utf-8 signature? }
                   if (BufSize>2) and
                     (ord(get_inputpointer_char)=$ef) and
                     (ord(get_inputpointer_char(1))=$bb) and
                     (ord(get_inputpointer_char(2))=$bf) then
                     begin
{$else not CHECK_INPUTPOINTER_LIMITS}
                   c:=inputpointer^;
                   { eat utf-8 signature? }
                   if (BufSize>2) and
                     (ord(inputpointer^)=$ef) and
                     (ord((inputpointer+1)^)=$bb) and
                     (ord((inputpointer+2)^)=$bf) then
                     begin
{$endif CHECK_INPUTPOINTER_LIMITS}
                       (* we don't support including files with an UTF-8 bom
                          inside another file that wasn't encoded as UTF-8
                          already (we don't support {$codepage xxx} switches in
                          the middle of a file either) *)
                       if (CurrentSettings.SourceCodePage<>CP_UTF8) and
                          not CurrentModule.in_global then
                         Message(scanner_f_illegal_utf8_bom);
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                       inc_inputpointer(3);
{$else not CHECK_INPUTPOINTER_LIMITS}
                       inc(inputpointer,3);
{$endif CHECK_INPUTPOINTER_LIMITS}
                       message(scan_c_switching_to_utf8);
                       CurrentSettings.SourceCodePage:=CP_UTF8;
                       exclude(CurrentSettings.ModuleSwitches,cs_system_codepage);
                       include(CurrentSettings.ModuleSwitches,cs_explicit_codepage);
                     end;

                   line_no:=1;
                   if cs_asm_source in CurrentSettings.GlobalSwitches then
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                     inputfile.setline(line_no,inputstart+hidden_inputpointer-hidden_inputbuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
                     inputfile.setline(line_no,inputstart+inputpointer-inputbuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
                 end;
              end
             else
              begin
                wasmacro:=inputfile.IsMacro;
              { load eof position in tokenpos/current_filepos }
                gettokenpos;
              { close file }
                closeinputfile;
              { no next module, than EOF }
                if not Assigned(inputfile.next) then
                 begin
                   c:=#26;
                   exit;
                 end;
              { load next file and reopen it }
                nextfile;
                tempopeninputfile;
              { status }
                Message1(scan_t_back_in,inputfile.name);
              { end of include file is like a line break which ends e.g. also // style comments }
                if not(wasmacro) and (current_commentstyle=comment_delphi) then
                  begin
                    c:=#10;
                  { ... but we have to decrease the line number first because it is increased due to this
                    inserted line break later on }
                    dec(line_no);
                    exit;
                  end;
              end;
           { load next char }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
             c:=get_inputpointer_char;
             inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
             c:=inputpointer^;
             inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
           until c<>#0; { if also end, then reload again }
         end;
      end;


    procedure TScannerFile.substitutemacro(const macname:string;p:pchar;len,line,fileindex:LongInt;internally_generated: boolean);
      var
        hp : TInputFile;
      begin
        { save old position }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        dec_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        dec(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
        tempcloseinputfile;
      { create macro 'file' }
        { use special name to dispose after !! }
        hp:=Do_OpenInputFile('_Macro_.'+macname);
        addfile(hp);
        with inputfile do
         begin
           inc(macro_nesting_depth);
           SetMacro(p,len);
         { local buffer }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           hidden_inputbuffer:=PAnsiChar(buf);
           hidden_inputpointer:=PAnsiChar(buf);
{$else not CHECK_INPUTPOINTER_LIMITS}
           inputbuffer:=PAnsiChar(buf);
           inputpointer:=PAnsiChar(buf);
{$endif CHECK_INPUTPOINTER_LIMITS}
           inputstart:=BufStart;
           RefIndex:=fileindex;
           InternallyGeneratedMacro:=internally_generated;
         end;
      { reset line }
        line_no:=line;
        lastlinepos:=0;
        lasttokenpos:=0;
        nexttokenpos:=0;
      { load new c }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        c:=get_inputpointer_char;
        inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
        c:=inputpointer^;
        inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
      end;


    procedure TScannerFile.do_gettokenpos(out tokenpos: LongInt; out filepos: TFilePosInfo);
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        tokenpos:=inputstart+(hidden_inputpointer-hidden_inputbuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
        tokenpos:=inputstart+(inputpointer-inputbuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
        filepos.line:=line_no;
        filepos.column:=tokenpos-lastlinepos;
        filepos.fileindex:=inputfile.RefIndex;
        filepos.moduleindex:=CurrentModule.ModuleID;
      end;


    procedure TScannerFile.gettokenpos;
    { load the values of tokenpos and lasttokenpos }
      begin
        do_gettokenpos(lasttokenpos,CurrentTokenPos);
        CurrentFilePos:=CurrentTokenPos;
      end;


    procedure TScannerFile.cachenexttokenpos;
      begin
        do_gettokenpos(nexttokenpos,next_filepos);
      end;


    procedure TScannerFile.setnexttoken;
      begin
        token:=nexttoken;
        nexttoken:=NOTOKEN;
        lasttokenpos:=nexttokenpos;
        CurrentTokenPos:=next_filepos;
        CurrentFilePos:=CurrentTokenPos;
        nexttokenpos:=0;
      end;


    procedure TScannerFile.savetokenpos;
      begin
        oldlasttokenpos:=lasttokenpos;
        oldcurrent_filepos:=CurrentFilePos;
        oldcurrent_tokenpos:=CurrentTokenPos;
      end;


    procedure TScannerFile.restoretokenpos;
      begin
        lasttokenpos:=oldlasttokenpos;
        CurrentFilePos:=oldcurrent_filepos;
        CurrentTokenPos:=oldcurrent_tokenpos;
      end;


    procedure TScannerFile.inc_comment_level;
      begin
         if (m_nested_comment in CurrentSettings.ModeSwitches) then
           inc(comment_level)
         else
           comment_level:=1;
         if (comment_level>1) then
          begin
             savetokenpos;
             gettokenpos; { update for warning }
             Message1(scan_w_comment_level,ToStr(comment_level));
             restoretokenpos;
          end;
      end;


    procedure TScannerFile.dec_comment_level;
      begin
         if (m_nested_comment in CurrentSettings.ModeSwitches) then
           dec(comment_level)
         else
           comment_level:=0;
      end;


    procedure TScannerFile.linebreak;
      var
         cur : char;
      begin
        with inputfile do
         begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           if (byte(get_inputpointer_char)=0) and not(EndOfFile) then
{$else not CHECK_INPUTPOINTER_LIMITS}
           if (byte(inputpointer^)=0) and not(EndOfFile) then
{$endif CHECK_INPUTPOINTER_LIMITS}
             begin
               cur:=c;
               reload;
               if byte(cur)+byte(c)<>23 then
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                 dec_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                 dec(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
             end
           else
             begin
               { Support all combination of #10 and #13 as line break }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
               if (byte(get_inputpointer_char)+byte(c)=23) then
                 inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
               if (byte(inputpointer^)+byte(c)=23) then
                 inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
             end;
           { Always return #10 as line break }
           c:=#10;
           { increase line counters }
{$ifdef CHECK_INPUTPOINTER_LIMITS}
           lastlinepos:=inputstart+(hidden_inputpointer-hidden_inputbuffer);
{$else not CHECK_INPUTPOINTER_LIMITS}
           lastlinepos:=inputstart+(inputpointer-inputbuffer);
{$endif CHECK_INPUTPOINTER_LIMITS}
           inc(line_no);
           { update linebuffer }
           if cs_asm_source in CurrentSettings.GlobalSwitches then
             inputfile.setline(line_no,lastlinepos);
           { update for status and call the show status routine,
             but don't touch current_filepos ! }
           savetokenpos;
           gettokenpos; { update for v_status }
           inc(status.CompiledLines);
           ShowStatus;
           restoretokenpos;
         end;
      end;


    procedure TScannerFile.illegal_char(ch:char);
      var
        s : string;
      begin
        if ch in [#32..#255] then
          s:=''''+ch+''''
        else
          s:='#'+ToStr(ord(ch));
        Message2(scan_f_illegal_char,s,'$'+HexStr(ord(ch),2));
      end;


    procedure TScannerFile.end_of_file;
      begin
        checkpreprocstack;
        if in_multiline_string then
          Message2(scan_f_unterminated_multiline_string, ToStr(multiline_start_line), ToStr(multiline_start_column))
        else
          Message(scan_f_end_of_file);
      end;

  {-------------------------------------------
           IF Conditional Handling
  -------------------------------------------}

    procedure TScannerFile.checkpreprocstack;
      begin
      { check for missing ifdefs }
        while Assigned(preprocstack) do
         begin
           Message4(scan_e_endif_expected,preprocstring[preprocstack.typ],preprocstack.name,
             CurrentModule.SourceFiles.Get_File_Name(preprocstack.fileindex),
             ToStr(preprocstack.line_nb));
           poppreprocstack;
         end;
      end;


    procedure TScannerFile.poppreprocstack;
      var
        hp : TPreProcStack;
      begin
        if Assigned(preprocstack) then
         begin
           Message1(scan_c_endif_found,preprocstack.name);
           hp:=preprocstack.next;
           preprocstack.free;
           preprocstack:=hp;
         end
        else
         Message(scan_e_endif_without_if);
      end;


    procedure TScannerFile.ifpreprocstack(atyp:TPreProcType;compile_time_predicate:TCompileTimePredicate;messid:LongInt);
      var
        condition: Boolean;
        valuedescr: String;
      begin
        if (preprocstack=nil) or preprocstack.accept then
          condition:=compile_time_predicate(valuedescr)
        else
          begin
            condition:= false;
            valuedescr:= '';
          end;
        preprocstack:=TPreProcStack.create(atyp, condition, preprocstack);
        preprocstack.name:=valuedescr;
        preprocstack.line_nb:=line_no;
        preprocstack.fileindex:=CurrentFilePos.fileindex;
        if preprocstack.accept then
          Message2(messid,preprocstack.name,'accepted')
        else
          Message2(messid,preprocstack.name,'rejected');
      end;

    procedure TScannerFile.elsepreprocstack;
      begin
        if Assigned(preprocstack) and
           (preprocstack.typ<>pp_else) then
         begin
           if (preprocstack.typ=pp_elseif) then
             preprocstack.accept:=false
           else
             if (not(Assigned(preprocstack.next)) or (preprocstack.next.accept)) then
               preprocstack.accept:=not preprocstack.accept;
           preprocstack.iftyp:=preprocstack.typ;
           preprocstack.typ:=pp_else;
           preprocstack.line_nb:=line_no;
           preprocstack.fileindex:=CurrentFilePos.fileindex;
           if preprocstack.accept then
            Message2(scan_c_else_found,preprocstack.name,'accepted')
           else
            Message2(scan_c_else_found,preprocstack.name,'rejected');
         end
        else
         Message(scan_e_endif_without_if);
      end;

    procedure TScannerFile.elseifpreprocstack(compile_time_predicate:TCompileTimePredicate);
      var
        valuedescr: String;
      begin
        if Assigned(preprocstack) and
           (preprocstack.typ in [pp_if,pp_ifdef,pp_ifndef,pp_elseif]) then
         begin
           { when the branch is accepted we use pp_elseif so we know that
             all the next branches need to be rejected. when this branch is still
             not accepted then leave it at pp_if }
           if (preprocstack.typ=pp_elseif) then
             preprocstack.accept:=false
           else if (preprocstack.typ in [pp_if,pp_ifdef,pp_ifndef]) and preprocstack.accept then
               begin
                 preprocstack.accept:=false;
                 preprocstack.typ:=pp_elseif;
               end
           else if (not(Assigned(preprocstack.next)) or (preprocstack.next.accept))
                   and compile_time_predicate(valuedescr) then
               begin
                 preprocstack.name:=valuedescr;
                 preprocstack.accept:=true;
                 preprocstack.typ:=pp_elseif;
               end;

           preprocstack.line_nb:=line_no;
           preprocstack.fileindex:=CurrentFilePos.fileindex;
           if preprocstack.accept then
             Message2(scan_c_else_found,preprocstack.name,'accepted')
           else
             Message2(scan_c_else_found,preprocstack.name,'rejected');
         end
        else
         Message(scan_e_endif_without_if);
      end;


    procedure TScannerFile.popreplaystack;
      var
        hp : TReplayStack;
      begin
        if Assigned(replaystack) then
         begin
           hp:=replaystack.next;
           replaystack.free;
           replaystack:=hp;
         end;
      end;


    function TScannerFile.replay_stack_depth:LongInt;
      var
        tmp: TReplayStack;
      begin
        result:=0;
        tmp:=replaystack;
        while Assigned(tmp) do
          begin
            inc(result);
            tmp:=tmp.next;
          end;
      end;

    procedure TScannerFile.handleconditional(p:TDirectiveItem);
      begin
        savetokenpos;
        repeat
          CurrentScanner.gettokenpos;
          Message1(scan_d_handling_switch,'$'+p.name);
          p.proc();
          { accept the text ? }
          if (CurrentScanner.preprocstack=nil) or CurrentScanner.preprocstack.accept then
           break
          else
           begin
             CurrentScanner.gettokenpos;
             Message(scan_c_skipping_until);
             repeat
               CurrentScanner.skipuntildirective;
               if not (m_mac in CurrentSettings.ModeSwitches) then
                 p:=TDirectiveItem(turbo_scannerdirectives.Find(CurrentScanner.readid))
               else
                 p:=TDirectiveItem(mac_scannerdirectives.Find(CurrentScanner.readid));
             until Assigned(p) and (p.is_conditional);
             CurrentScanner.gettokenpos;
           end;
        until false;
        restoretokenpos;
      end;


    procedure TScannerFile.handledirectives;
      var
         t  : TDirectiveItem;
         hs : string;
      begin
         gettokenpos;
         readchar; {Remove the $}
         hs:=readid;
         { handle empty directive }
         if hs='' then
           begin
             Message1(scan_w_illegal_switch,'$');
             exit;
           end;
{$ifdef PREPROCWRITE}
         if ParaPreprocess then
          begin
            if not (m_mac in CurrentSettings.ModeSwitches) then
              t:=TDirectiveItem(turbo_scannerdirectives.Find(hs))
            else
              t:=TDirectiveItem(mac_scannerdirectives.Find(hs));
            if Assigned(t) and not(t.is_conditional) then
             begin
               preprocfile.AddSpace;
               preprocfile.Add('{$'+hs+CurrentScanner.readcomment+'}');
               exit;
             end;
          end;
{$endif PREPROCWRITE}
         { skip this directive? }
         if (ignoredirectives.find(hs)<>nil) then
          begin
            if (comment_level>0) then
             readcomment;
            { we've read the whole comment }
            current_commentstyle:=comment_none;
            exit;
          end;
         { Check for compiler switches }
          while (length(hs)=1) and (c in ['-','+']) and
            IsRecognizedSwitch(hs[1]) do
          begin
            Message1(scan_d_handling_switch,'$'+hs+c);
            HandleSwitch(hs[1],c);
            CurrentScanner.readchar; {Remove + or -}
            if c=',' then
             begin
               CurrentScanner.readchar;   {Remove , }
               { read next switch, support $v+,$+}
               hs:=CurrentScanner.readid;
               if (hs='') then
                begin
                  if (c='$') and (m_fpc in CurrentSettings.ModeSwitches) then
                   begin
                     CurrentScanner.readchar;  { skip $ }
                     hs:=CurrentScanner.readid;
                   end;
                  if (hs='') then
                   Message1(scan_w_illegal_directive,'$'+c);
                end;
             end
            else
             hs:='';
          end;
         { directives may follow switches after a , }
         if hs<>'' then
          begin
            if not (m_mac in CurrentSettings.ModeSwitches) then
              t:=TDirectiveItem(turbo_scannerdirectives.Find(hs))
            else
              t:=TDirectiveItem(mac_scannerdirectives.Find(hs));

            if Assigned(t) then
             begin
               if t.is_conditional then
                handleconditional(t)
               else
                begin
                  Message1(scan_d_handling_switch,'$'+hs);
                  t.proc();
                end;
             end
            else
             begin
               CurrentScanner.ignoredirectives.Add(hs,DirectiveIgnored);
               Message1(scan_w_illegal_directive,'$'+hs);
             end;
            { conditionals already read the comment }
            if (CurrentScanner.comment_level>0) then
             CurrentScanner.readcomment;
            { we've read the whole comment }
            current_commentstyle:=comment_none;
          end;
      end;


    procedure TScannerFile.readchar;
      begin
{$ifdef CHECK_INPUTPOINTER_LIMITS}
        c:=get_inputpointer_char;
{$else not CHECK_INPUTPOINTER_LIMITS}
        c:=inputpointer^;
{$endif CHECK_INPUTPOINTER_LIMITS}
        if c=#0 then
          reload
        else
{$ifdef CHECK_INPUTPOINTER_LIMITS}
          inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
          inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
      end;


    procedure TScannerFile.readstring;
      var
        i : LongInt;
        err : boolean;
      begin
        err:=false;
        i:=0;
        repeat
          case c of
            '_','$',
            '0'..'9',
            'A'..'Z',
            'a'..'z' :
              begin
                if (c='$') and not allowgenericid then
                  break;
                if i<255 then
                 begin
                   inc(i);
                   orgpattern[i]:=c;
                   if c in ['a'..'z'] then
                     pattern[i]:=chr(ord(c)-32)
                   else
                     pattern[i]:=c;
                 end
                else
                 begin
                   if not err then
                     begin
                       Message(scan_e_string_exceeds_255_chars);
                       err:=true;
                     end;
                 end;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                c:=get_inputpointer_char;
                inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                c:=inputpointer^;
                inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
              end;
            #0 :
              reload;
            else if inputfile.InternallyGeneratedMacro and
                    (c in [internal_macro_escape_begin..internal_macro_escape_end]) then
              begin
                if i<255 then
                 begin
                   inc(i);
                   orgpattern[i]:=c;
                   pattern[i]:=c;
                 end
                else
                 begin
                   if not err then
                     begin
                       Message(scan_e_string_exceeds_255_chars);
                       err:=true;
                     end;
                 end;
{$ifdef CHECK_INPUTPOINTER_LIMITS}
                c:=get_inputpointer_char;
                inc_inputpointer;
{$else not CHECK_INPUTPOINTER_LIMITS}
                c:=inputpointer^;
                inc(inputpointer);
{$endif CHECK_INPUTPOINTER_LIMITS}
              end
            else
              break;
          end;
        until false;
        orgpattern[0]:=chr(i);
        pattern[0]:=chr(i);
      end;


    procedure TScannerFile.readnumber;
      var
        base,
        i  : LongInt;
        firstdigitread: Boolean;
      begin
        case c of
          '%' :
            begin
              readchar;
              base:=2;
              pattern[1]:='%';
              i:=1;
            end;
          '&' :
            begin
              readchar;
              base:=8;
              pattern[1]:='&';
              i:=1;
            end;
          '$' :
            begin
              readchar;
              base:=16;
              pattern[1]:='$';
              i:=1;
            end;
          else
            begin
              base:=10;
              i:=0;
            end;
        end;
        firstdigitread:=false;
        while ((base>=10) and (c in ['0'..'9'])) or
              ((base=16) and (c in ['A'..'F','a'..'f'])) or
              ((base=8) and (c in ['0'..'7'])) or
              ((base=2) and (c in ['0'..'1'])) or
              ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and firstdigitread and (c='_')) do
         begin
           if (i<255) and (c<>'_') then
            begin
              inc(i);
              pattern[i]:=c;
            end;
           readchar;
           firstdigitread:=true;
         end;
        pattern[0]:=chr(i);
      end;


    function TScannerFile.readid:string;
      begin
        readstring;
        readid:=pattern;
      end;


    function TScannerFile.readval:LongInt;
      var
        l : LongInt;
        w : integer;
      begin
        readnumber;
        val(pattern,l,w);
        readval:=l;
      end;


    function TScannerFile.readval64:int64;
      var
        l : int64;
        w : integer;
      begin
        readnumber;
        val(pattern,l,w);
        readval64:=l;
      end;


    function TScannerFile.readcomment(include_special_char: boolean):ShortString;
      var
        i : LongInt;
      begin
        i:=0;
        repeat
          case c of
            '{' :
              begin
                if (include_special_char) and (i<255) then
                begin
                  inc(i);
                  readcomment[i]:=c;
                end;

                if current_commentstyle=comment_tp then
                  inc_comment_level;
              end;
            '}' :
              begin
                if (include_special_char) and (i<255) then
                begin
                  inc(i);
                  readcomment[i]:=c;
                end;

                if current_commentstyle=comment_tp then
                  begin
                    readchar;
                    dec_comment_level;


                    if comment_level=0 then
                      break
                    else
                      continue;
                  end;
              end;
            '*' :
              begin
                if current_commentstyle=comment_oldtp then
                  begin
                    readchar;
                    if c=')' then
                      begin
                        readchar;
                        dec_comment_level;
                        break;
                      end
                    else
                    { Add both characters !!}
                      if (i<255) then
                        begin
                          inc(i);
                          readcomment[i]:='*';
                          if (i<255) then
                            begin
                              inc(i);
                              readcomment[i]:=c;
                            end;
                        end;
                  end
                else
                { Not old TP comment, so add...}
                  begin
                    if (i<255) then
                      begin
                        inc(i);
                        readcomment[i]:='*';
                      end;
                  end;
              end;
            #10,#13 :
              linebreak;
            #26 :
              end_of_file;
            else
              begin
                if (i<255) then
                  begin
                    inc(i);
                    readcomment[i]:=c;
                  end;
              end;
          end;
          readchar;
        until false;
        readcomment[0]:=chr(i);
      end;


    function TScannerFile.readquotedstring:ShortString;
      var
        i : LongInt;
        msgwritten : boolean;
      begin
        i:=0;
        msgwritten:=false;
        if (c in ['''','`']) then
          begin
            had_multiline_string:=in_multiline_string;
            in_multiline_string:=(c='`');
            if in_multiline_string and (not (m_multiline_strings in CurrentSettings.ModeSwitches)) then
              begin
                result[0]:=chr(0);
                Illegal_Char(c);
              end;
            repeat
              readchar;
              case c of
                #26 :
                  end_of_file;
                #10,#13 :
                  if not in_multiline_string then
                    begin
                      if had_multiline_string then
                        Message2(scan_f_unterminated_multiline_string,
                                 ToStr(multiline_start_line),
                                 ToStr(multiline_start_column))
                      else
                        Message(scan_f_string_exceeds_line);
                    end;
                '''' :
                  if not in_multiline_string then
                    begin
                      readchar;
                      if c<>'''' then
                       break;
                    end;
                '`' :
                  if in_multiline_string then
                    begin
                      readchar;
                      if c<>'`' then
                       break;
                    end;
              end;
              if i<255 then
                begin
                  inc(i);
                  result[i]:=c;
                end
              else
                begin
                  if not msgwritten then
                    begin
                      Message(scan_e_string_exceeds_255_chars);
                      msgwritten:=true;
                    end;
                 end;
            until false;
          end;
        result[0]:=chr(i);
      end;


    function TScannerFile.readlongcomment(include_special_char: boolean):RawByteString;
      var
        i : LongInt;

        procedure addchar(char: AnsiChar = #0);
        begin
          Inc(i);
          if i>Length(readlongcomment) then
            SetLength(readlongcomment, Length(readlongcomment)+256);
          if char<>#0 then
            readlongcomment[i]:=char
          else
            readlongcomment[i]:=c;
        end;
      begin
        i:=0;
        SetLength(readlongcomment, 256);
        repeat
          case c of
            '{' :
              begin
                if (include_special_char) then
                  addchar;

                if current_commentstyle=comment_tp then
                  inc_comment_level;
              end;
            '}' :
              begin
                if (include_special_char) then
                  addchar;

                if current_commentstyle=comment_tp then
                  begin
                    readchar;
                    dec_comment_level;


                    if comment_level=0 then
                      break
                    else
                      continue;
                  end;
              end;
            '*' :
              begin
                if current_commentstyle=comment_oldtp then
                  begin
                    readchar;
                    if c=')' then
                      begin
                        readchar;
                        dec_comment_level;
                        break;
                      end
                    else
                    { Add both characters !!}
                      begin
                        addchar('*');
                        addchar;
                      end;
                  end
                else
                { Not old TP comment, so add...}
                  addchar('*');
              end;
            #10,#13 :
              linebreak;
            #26 :
              end_of_file;
            else
              addchar;
          end;
          readchar;
        until false;
        SetLength(readlongcomment, i);
        SetCodePage(readlongcomment, CurrentSettings.SourceCodePage, False);
      end;


    function TScannerFile.readlongquotedstring:RawByteString;
      var
        i : LongInt;
        msgwritten : boolean;

        procedure addchar;
        begin
          Inc(i);
          if i>Length(readlongquotedstring) then
            SetLength(readlongquotedstring, Length(readlongquotedstring)+256);
          readlongquotedstring[i]:=c;
        end;
      begin
        i:=0;
        SetLength(readlongquotedstring, 256);
        msgwritten:=false;
        if (c='''') then
          begin
            repeat
              readchar;
              case c of
                #26 :
                  end_of_file;
                #10,#13 :
                  Message(scan_f_string_exceeds_line);
                '''' :
                  begin
                    readchar;
                    if c<>'''' then
                     break;
                  end;
              end;
              addchar;
            until false;
          end;
        SetLength(readlongquotedstring, i);
        SetCodePage(readlongquotedstring, CurrentSettings.SourceCodePage, False);
      end;


    function TScannerFile.readstate:char;
      var
        state : char;
      begin
        state:=' ';
        if c=' ' then
         begin
           CurrentScanner.skipspace;
           CurrentScanner.readid;
           if pattern='ON' then
            state:='+'
           else
            if pattern='OFF' then
             state:='-';
         end
        else
         state:=c;
        if not (state in ['+','-']) then
         Message(scan_e_wrong_switch_toggle);
        readstate:=state;
      end;


    function TScannerFile.readoptionalstate(fallback:char):char;
      var
        state : char;
      begin
        state:=' ';
        if c=' ' then
         begin
           CurrentScanner.skipspace;
           if c in ['*','}'] then
             state:=fallback
           else
             begin
               CurrentScanner.readid;
               if pattern='ON' then
                state:='+'
               else
                if pattern='OFF' then
                 state:='-';
             end;
         end
        else
          if c in ['*','}'] then
            state:=fallback
          else
            state:=c;
        if not (state in ['+','-']) then
         Message(scan_e_wrong_switch_toggle);
        readoptionalstate:=state;
      end;


    function TScannerFile.readstatedefault:char;
      var
        state : char;
      begin
        state:=' ';
        if c=' ' then
         begin
           CurrentScanner.skipspace;
           CurrentScanner.readid;
           if pattern='ON' then
            state:='+'
           else
            if pattern='OFF' then
             state:='-'
            else
             if pattern='DEFAULT' then
              state:='*';
         end
        else
         state:=c;
        if not (state in ['+','-','*']) then
         Message(scan_e_wrong_switch_toggle_default);
        readstatedefault:=state;
      end;


    procedure TScannerFile.skipspace;
      begin
        repeat
          case c of
            #26 :
              begin
                reload;
                if (c=#26) and not Assigned(inputfile.next) then
                  break;
                continue;
              end;
            #10,
            #13 :
              linebreak;
            #9,#11,#12,' ' :
              ;
            else
              break;
          end;
          readchar;
        until false;
      end;


    procedure TScannerFile.skipuntildirective;
      var
        found : LongInt;
        next_char_loaded : boolean;
      begin
         found:=0;
         next_char_loaded:=false;
         repeat
           case c of
             #10,
             #13 :
               linebreak;
             #26 :
               begin
                 reload;
                 if (c=#26) and not Assigned(inputfile.next) then
                   end_of_file;
                 continue;
               end;
             '{' :
               begin
                 if (current_commentstyle in [comment_tp,comment_none]) then
                   begin
                     current_commentstyle:=comment_tp;
                     if (comment_level=0) then
                       found:=1;
                     inc_comment_level;
                   end;
               end;
             '*' :
               begin
                 if (current_commentstyle=comment_oldtp) then
                   begin
                     readchar;
                     if c=')' then
                       begin
                         dec_comment_level;
                         found:=0;
                         current_commentstyle:=comment_none;
                       end
                     else
                       next_char_loaded:=true;
                   end
                 else
                   found := 0;
               end;
             '}' :
               begin
                 if (current_commentstyle=comment_tp) then
                   begin
                     dec_comment_level;
                     if (comment_level=0) then
                       current_commentstyle:=comment_none;
                     found:=0;
                   end;
               end;
             '$' :
               begin
                 if found=1 then
                  found:=2;
               end;
             '''','`' :
               if (current_commentstyle=comment_none) then
                 begin
                   had_multiline_string:=in_multiline_string;
                   in_multiline_string:=(c='`');
                   if in_multiline_string and (not (m_multiline_strings in CurrentSettings.ModeSwitches)) then
                     Illegal_Char(c);
                   repeat
                     readchar;
                     case c of
                       #26 :
                         end_of_file;
                       #10,#13 :
                         if not in_multiline_string then
                           break;
                       '''' :
                         if not in_multiline_string then
                           begin
                             readchar;
                             if c<>'''' then
                              begin
                                next_char_loaded:=true;
                                break;
                              end;
                           end;
                       '`' :
                         if in_multiline_string then
                           begin
                             readchar;
                             if c<>'`' then
                              begin
                                next_char_loaded:=true;
                                break;
                              end;
                           end;
                     end;
                   until false;
                 end;
             '(' :
               begin
                 if (current_commentstyle=comment_none) then
                  begin
                    readchar;
                    if c='*' then
                     begin
                       readchar;
                       if c='$' then
                        begin
                          found:=2;
                          inc_comment_level;
                          current_commentstyle:=comment_oldtp;
                        end
                       else
                        begin
                          skipoldtpcomment(false);
                          next_char_loaded:=true;
                        end;
                     end
                    else
                     next_char_loaded:=true;
                  end
                 else
                  found:=0;
               end;
             '/' :
               begin
                 if (current_commentstyle=comment_none) then
                  begin
                    readchar;
                    if c='/' then
                     skipdelphicomment;
                    next_char_loaded:=true;
                  end
                 else
                  found:=0;
               end;
             else
               found:=0;
           end;
           if next_char_loaded then
             next_char_loaded:=false
           else
             readchar;
         until (found=2);
      end;


{****************************************************************************
                             Comment Handling
****************************************************************************}

    procedure TScannerFile.skipcomment(read_first_char:boolean);
      begin
        current_commentstyle:=comment_tp;
        if read_first_char then
          readchar;
        inc_comment_level;
      { handle compiler switches }
        if (c='$') then
         handledirectives;
      { handle_switches can dec comment_level,  }
        while (comment_level>0) do
         begin
           case c of
            '{' :
              inc_comment_level;
            '}' :
              dec_comment_level;
            '*' :
              { in iso mode, comments opened by a curly bracket can be closed by asterisk, round bracket }
              if m_iso in CurrentSettings.ModeSwitches then
                begin
                  readchar;
                  if c=')' then
                    dec_comment_level
                  else
                    continue;
                end;
            #10,#13 :
              linebreak;
            #26 :
              begin
                reload;
                if (c=#26) and not Assigned(inputfile.next) then
                  end_of_file;
                continue;
              end;
           end;
           readchar;
         end;
        current_commentstyle:=comment_none;
      end;


    procedure TScannerFile.skipdelphicomment;
      begin
        current_commentstyle:=comment_delphi;
        inc_comment_level;
        readchar;
        { this is not supported }
        if c='$' then
          Message(scan_w_wrong_styled_switch);
        { skip comment }
        while not (c in [#10,#13,#26]) do
          readchar;
        dec_comment_level;
        current_commentstyle:=comment_none;
      end;


    procedure TScannerFile.skipoldtpcomment(read_first_char:boolean);
      var
        found : LongInt;
      begin
        current_commentstyle:=comment_oldtp;
        inc_comment_level;
        { only load a char if last already processed,
          was cause of bug1634 PM }
        if read_first_char then
          readchar;
      { this is now supported }
        if (c='$') then
         handledirectives;
      { skip comment }
        while (comment_level>0) do
         begin
           found:=0;
           repeat
             case c of
               #26 :
                 begin
                   reload;
                   if (c=#26) and not Assigned(inputfile.next) then
                     end_of_file;
                   continue;
                 end;
               #10,#13 :
                 begin
                   if found=4 then
                    inc_comment_level;
                   linebreak;
                   found:=0;
                 end;
               '*' :
                 begin
                   if found=3 then
                    found:=4
                   else
                    begin
                      if found=4 then
                        inc_comment_level;
                      found:=1;
                    end;
                 end;
               ')' :
                 begin
                   if found in [1,4] then
                    begin
                      dec_comment_level;
                      if comment_level=0 then
                       found:=2
                      else
                       found:=0;
                    end
                   else
                    found:=0;
                 end;
              '}' :
                { in iso mode, comments opened by asterisk, round bracket can be closed by a curly bracket }
                if m_iso in CurrentSettings.ModeSwitches then
                  begin
                    dec_comment_level;
                    if comment_level=0 then
                      found:=2
                    else
                      found:=0;
                  end;
               '(' :
                 begin
                   if found=4 then
                    inc_comment_level;
                   found:=3;
                 end;
               else
                 begin
                   if found=4 then
                    inc_comment_level;
                   found:=0;
                 end;
             end;
             readchar;
           until (found=2);
         end;
        current_commentstyle:=comment_none;
      end;

    procedure TScannerFile.postprocessutf8multiline(len,quote_pos,quote_count : integer);
    var
      malformed : boolean;
      start, i,stripcol,col,newlen : integer;
      crlf : boolean;
      tmp : TCompilerWideString;
      ch : TCompilerWideChar;
    begin
      stripcol:=quote_pos;
      malformed:=false;
      newlen:=0;
      col:=0;
      start:=1;
      InitWideString(tmp);
      { Strip initial cr/lf }
      Case CurrentSettings.LineEndingType of
        le_cr,le_lf : inc(start);
        le_crlf : inc(start,2);
        le_source :
          begin
          inc(start);
          if (GetCharWideString(patternw,1)=13) and (GetCharWideString(patternw,start)=10) then
            inc(start);
          end;
        le_platform : inc(start,length(TargetInfo.newline));
      end;
      { we don't need the last added quotes }
      dec(len,quote_count-1);
      for I:=Start to len do
        begin
        ch:=GetCharWideString(patternw,i);
        inc(col);
        if (col>stripcol) or (ch=10) or (ch=13) then
          begin
          inc(newlen);
          ConcatWideStringChar(patternw,ch);
          end
        else
          begin
          // if less spaces than in the last line, report error
          if not (ch in [9,32,11]) then
            begin
            if not malformed then
              begin
              malformed:=true;
              message3(scan_e_improperly_indented_multiline_string,
                      ToStr(stripcol),
                      ToStr(multiline_start_line),
                      ToStr(multiline_start_column));
              end;
            end;
          end;
        if (ch=10) or (ch=13) then
          col:=0;
        end;
      // remove last CR/LF
      ch:=GetCharWideString(tmp,newlen);
      if (ch=10) or (ch=13) then
        begin
        Case CurrentSettings.LineEndingType of
          le_cr,le_lf : dec(newlen);
          le_crlf : dec(newlen,2);
          le_platform : dec(newlen,length(TargetInfo.newline));
          le_source :
            begin
            crlf:=GetCharWideString(tmp,newlen)=10;
            dec(newlen);
            if crlf and (newLen>0) and (GetCharWideString(tmp,newlen)=13) then
              dec(newlen);
            end;
        end;
        end;
      tmp.len:=newLen;
      DoneWideString(patternw);
      patternw:=tmp;
    end;

    procedure TScannerFile.postprocessmultiline(len,quote_pos,quote_count : integer);

    var
      malformed : boolean;
      start, i,stripcol,col,newlen : integer;
      crlf : boolean;
      tmp : AnsiString;
      ch : ansichar;
    begin
      stripcol:=quote_pos;
      malformed:=false;
      newlen:=0;
      SetLength(tmp,len-quote_count+1);
      col:=0;
      start:=1;
      { Strip initial cr/lf }
      Case CurrentSettings.LineEndingType of
        le_cr,le_lf : inc(start);
        le_crlf : inc(start,2);
        le_platform : inc(start,length(TargetInfo.newline));
        le_source :
          begin
          inc(start);
          if (cstringPattern[1]=#13) and (cstringpattern[start]=#10) then
            inc(start);
          end;
      end;
      { we don't need the last added quotes }
      dec(len,quote_count-1);
      for I:=Start to len do
        begin
        ch:=cstringpattern[i];
        inc(col);
        if (col>stripcol) or (ch in [#10,#13]) then
          begin
          inc(newlen);
          tmp[newlen]:=ch;
          end
        else
          begin
          // if less spaces than in the last line, report error
          if not (ch in [#9,#32,#11]) then
            begin
            if not malformed then
              begin
              malformed:=true;
              message3(scan_e_improperly_indented_multiline_string,
                      ToStr(stripcol),
                      ToStr(multiline_start_line),
                      ToStr(multiline_start_column));
              end;
            end;
          end;
        if ch in [#10,#13] then
          col:=0;
        end;
      // remove last CR/LF
      if tmp[newlen] in [#10,#13] then
        begin
        Case CurrentSettings.LineEndingType of
          le_cr,le_lf : dec(newlen);
          le_crlf : dec(newlen,2);
          le_platform : dec(newlen,length(TargetInfo.newline));
          le_source :
              begin
              crlf:=tmp[newlen]=#10;
              dec(newlen);
              if crlf and (tmp[newlen]=#13) then
                Dec(newlen);
              end;

        end;
        end;
      SetLength(tmp,newlen);
      cstringpattern:=tmp;
    end;


    function TScannerFile.readstringconstant : boolean;

    type
       TQuoteStyle = (qsNone,qsBacktick,qsMultiQuote);

    var
      trimcount,m,code,len,quote_count,init_quote_count,whitespace_count,quote_col : integer;
      style : TQuoteStyle;
      iswidestring : boolean;
      asciinr : string[33];
      last_c : char;
      whitespace_only, had_newline, first_multiline, backtick : boolean;
      d : cardinal;
      w : word;

    label
      quote_label;
    begin
      last_c :=#0;
      trimcount:=0;
      quote_col:=0;
      whitespace_count:=0;
      init_quote_count:=0;
      had_newline:=false;
      first_multiline:=false;
      had_multiline_string:=false;
      backtick:=(c='`');
      if backtick then
        style:=qsBacktick
      else
        style:=qsNone;
      whitespace_only:=true;
      in_multiline_string:=backtick;
      quote_count:=0;
      whitespace_only:=true;
      if in_multiline_string then
        begin
          if not (m_multiline_strings in CurrentSettings.ModeSwitches) then
            Illegal_Char(c)
          else
            begin
              multiline_start_line:=CurrentFilePos.line;
              multiline_start_column:=CurrentFilePos.column;
            end;
        end;
      len:=0;
      cstringpattern:='';
      iswidestring:=false;
      if c='^' then
       begin
         readchar;
         c:=upcase(c);
         if (Block_Type in [bt_type,bt_const_type,bt_var_type]) or
            (lasttoken=_ID) or (lasttoken=_NIL) or (lasttoken=_OPERATOR) or
            (lasttoken=_RKLAMMER) or (lasttoken=_RECKKLAMMER) or (lasttoken=_CARET) then
          begin
            token:=_CARET;
            exit(true);
          end
         else
          begin
            inc(len);
            SetLength(cstringpattern,256);
            if c<#64 then
              cstringpattern[len]:=chr(ord(c)+64)
            else
              cstringpattern[len]:=chr(ord(c)-64);
            readchar;
          end;
       end;
      repeat
        case c of
          '#' :
            begin
              readchar; { read # }
              case c of
                '$':
                  begin
                    readchar; { read leading $ }
                    asciinr:='$';
                    while (upcase(c) in ['A'..'F','0'..'9']) and (length(asciinr)<=7) do
                      begin
                        asciinr:=asciinr+c;
                        readchar;
                      end;
                  end;
                '&':
                  begin
                    readchar; { read leading $ }
                    asciinr:='&';
                    while (upcase(c) in ['0'..'7']) and (length(asciinr)<=8) do
                      begin
                        asciinr:=asciinr+c;
                        readchar;
                      end;
                  end;
                '%':
                  begin
                    readchar; { read leading $ }
                    asciinr:='%';
                    while (upcase(c) in ['0','1']) and (length(asciinr)<=22) do
                      begin
                        asciinr:=asciinr+c;
                        readchar;
                      end;
                  end;
                else
                  begin
                    asciinr:='';
                    while (c in ['0'..'9']) and (length(asciinr)<=8) do
                      begin
                        asciinr:=asciinr+c;
                        readchar;
                      end;
                  end;
              end;
              val(asciinr,m,code);
              if (asciinr='') or (code<>0) then
                Message(scan_e_illegal_char_const)
              else if (m<0) or (m>255) or (length(asciinr)>3) then
                begin
                   if (m>=0) and (m<=$10FFFF) then
                     begin
                       if not iswidestring then
                        begin
                          if len>0 then
                            ASCII2Unicode(@cstringpattern[1],len,CurrentSettings.SourceCodePage,patternw)
                          else
                            ASCII2Unicode(nil,len,CurrentSettings.SourceCodePage,patternw);
                          iswidestring:=true;
                          len:=0;
                        end;
                       if m<=$FFFF then
                         ConcatWideStringChar(patternw,TCompilerWideChar(m))
                       else
                         begin
                           { split into surrogate pair }
                           dec(m,$10000);
                           ConcatWideStringChar(patternw,TCompilerWideChar((m shr 10) + $D800));
                           ConcatWideStringChar(patternw,TCompilerWideChar((m and $3FF) + $DC00));
                         end;
                     end
                   else
                     Message(scan_e_illegal_char_const)
                end
              else if iswidestring then
                ConcatWideStringChar(patternw,ASCIIChar2Unicode(char(m)))
              else
                begin
                  if len>=length(cstringpattern) then
                    SetLength(cstringpattern,length(cstringpattern)+256);
                  inc(len);
                  cstringpattern[len]:=chr(m);
                end;
            end;
          '''','`' :
            begin
              if c='''' then
                inc(quote_count);
              had_multiline_string:=in_multiline_string;
              if style<>qsMultiQuote then
                begin
                  in_multiline_string:=(c='`');
                  if in_multiline_string then
                    begin
                      backtick:=true;
                      style:=qsBacktick;
                      multiline_start_line:=CurrentFilePos.line;
                      multiline_start_column:=CurrentFilePos.column;
                    end
                  else
                    style:=qsNone;
                  first_multiline:=in_multiline_string and (last_c in [#0,#32,#61]);
                end;
              repeat
                readchar;
                quote_label:
                  case c of
                    #26 :
                      end_of_file;
                    #32,#9,#11 :
                      begin
                      inc(whitespace_count);
                      if (had_newline or first_multiline) and backtick and
                         (CurrentSettings.WhitespaceTrimAuto or
                         (CurrentSettings.WhitespaceTrimCount>0)) then
                        begin
                          if CurrentSettings.WhitespaceTrimAuto then
                            trimcount:=multiline_start_column
                          else
                            trimcount:=CurrentSettings.WhitespaceTrimCount;
                          while (c in [#32,#9,#11]) and (trimcount>0) do
                            begin
                              readchar;
                              dec(trimcount);
                            end;
                          had_newline:=false;
                          first_multiline:=false;
                          goto quote_label;
                        end;
                      end;
                    #10,#13 :
                      begin
                      whitespace_only:=true;
                      whitespace_count:=0;
                      if not in_multiline_string then
                        begin
                          if had_multiline_string then
                            Message2(scan_f_unterminated_multiline_string,
                                     ToStr(multiline_start_line),
                                     ToStr(multiline_start_column))
                          else if (not backtick)
                                   and ((quote_count>2) and ((quote_count mod 2)=1))
                                   and (m_multiline_strings in CurrentSettings.ModeSwitches) then
                            begin
                            style:=qsMultiQuote;
                            init_quote_count:=quote_count;
                            multiline_start_line:=CurrentFilePos.line;
                            multiline_start_column:=CurrentFilePos.column;
                            in_multiline_string:=true;
                            had_multiline_string:=true;
                            trimcount:=0;
                            quote_count:=0;
                            len:=0;
                            if c=#13 then
                              begin
                              readchar;
                              if c<>#10 then
                                goto quote_label;
                              end;
                            end
                          else
                            Message(scan_f_string_exceeds_line);
                        end;
                      end;
                    '''' :
                      begin
                      inc(quote_count);
                      if not in_multiline_string then
                        begin
                          readchar;
                          if c='''' then
                            inc(quote_count)
                          else
                            break;
                        end
                      else if not backtick then
                        if whitespace_only and (quote_count=init_quote_count) then
                          begin
                          in_multiline_string:=false;
                          quote_col:=whitespace_count;
                          readchar;
                          break;
                          end;
                      end;
                    '`' :
                      if in_multiline_string and (style=qsBacktick) then
                        begin
                          readchar;
                          if c<>'`' then
                           break;
                        whitespace_only:=false;
                        end;
                    else
                      whitespace_only:=false;
                      quote_count:=0;
                    end;
                first_multiline:=false;
                { interpret as utf-8 string? }
                if (ord(c)>=$80) and (CurrentSettings.SourceCodePage=CP_UTF8) then
                  begin
                    { convert existing string to an utf-8 string }
                    if not iswidestring then
                      begin
                        if len>0 then
                          ASCII2Unicode(@cstringpattern[1],len,CurrentSettings.SourceCodePage,patternw)
                        else
                          ASCII2Unicode(nil,len,CurrentSettings.SourceCodePage,patternw);
                        iswidestring:=true;
                        len:=0;
                      end;
                    { four chars }
                    if (ord(c) and $f0)=$f0 then
                      begin
                        { this always represents a surrogate pair, so
                          read as 32-bit value and then split into
                          the corresponding pair of two wchars }
                        d:=ord(c) and $f;
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        d:=(d shl 6) or (ord(c) and $3f);
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        d:=(d shl 6) or (ord(c) and $3f);
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        d:=(d shl 6) or (ord(c) and $3f);
                        if d<$10000 then
                          message(scan_e_utf8_malformed);
                        d:=d-$10000;
                        { high surrogate }
                        w:=$d800+(d shr 10);
                        ConcatWideStringChar(patternw,w);
                        { low surrogate }
                        w:=$dc00+(d and $3ff);
                        ConcatWideStringChar(patternw,w);
                      end
                    { three chars }
                    else if (ord(c) and $e0)=$e0 then
                      begin
                        w:=ord(c) and $f;
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        w:=(w shl 6) or (ord(c) and $3f);
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        w:=(w shl 6) or (ord(c) and $3f);
                        ConcatWideStringChar(patternw,w);
                      end
                    { two chars }
                    else if (ord(c) and $c0)<>0 then
                      begin
                        w:=ord(c) and $1f;
                        readchar;
                        if (ord(c) and $c0)<>$80 then
                          message(scan_e_utf8_malformed);
                        w:=(w shl 6) or (ord(c) and $3f);
                        ConcatWideStringChar(patternw,w);
                      end
                    { illegal }
                    else if (ord(c) and $80)<>0 then
                      message(scan_e_utf8_malformed)
                    else
                      ConcatWideStringChar(patternw,TCompilerWideChar(c))
                  end
                else if iswidestring then
                  begin
                    if in_multiline_string and (c in [#10,#13]) and (not ((c=#10) and (last_c=#13))) then
                      begin
                        if CurrentSettings.SourceCodePage=CP_UTF8 then
                          begin
                            case CurrentSettings.LineEndingType of
                              le_cr :
                                ConcatWideStringChar(patternw,ord(#13));
                              le_crlf :
                                begin
                                  ConcatWideStringChar(patternw,ord(#13));
                                  ConcatWideStringChar(patternw,ord(#10));
                                end;
                              le_lf :
                                ConcatWideStringChar(patternw,ord(#10));
                              le_platform :
                                begin
                                  if TargetInfo.newline=#13 then
                                    ConcatWideStringChar(patternw,ord(#13))
                                  else if TargetInfo.newline=#13#10 then
                                    begin
                                      ConcatWideStringChar(patternw,ord(#13));
                                      ConcatWideStringChar(patternw,ord(#10));
                                    end
                                  else if TargetInfo.newline=#10 then
                                    ConcatWideStringChar(patternw,ord(#10));
                                end;
                              le_source :
                                ConcatWideStringChar(patternw,ord(c));
                            end;
                          end
                        else
                          case CurrentSettings.LineEndingType of
                            le_cr :
                              ConcatWideStringChar(patternw,ASCIIChar2Unicode(#13));
                            le_crlf :
                              begin
                                ConcatWideStringChar(patternw,ASCIIChar2Unicode(#13));
                                ConcatWideStringChar(patternw,ASCIIChar2Unicode(#10));
                              end;
                            le_lf :
                              ConcatWideStringChar(patternw,ASCIIChar2Unicode(#10));
                            le_platform :
                              begin
                                if TargetInfo.newline=#13 then
                                  ConcatWideStringChar(patternw,ASCIIChar2Unicode(#13))
                                else if TargetInfo.newline=#13#10 then
                                  begin
                                    ConcatWideStringChar(patternw,ASCIIChar2Unicode(#13));
                                    ConcatWideStringChar(patternw,ASCIIChar2Unicode(#10));
                                  end
                                else if TargetInfo.newline=#10 then
                                  ConcatWideStringChar(patternw,ASCIIChar2Unicode(#10));
                              end;
                            le_source :
                              ConcatWideStringChar(patternw,ASCIIChar2Unicode(c));
                          end;
                        had_newline:=true;
                        inc(line_no);
                      end
                    else if not (in_multiline_string and (c in [#10,#13])) then
                      begin
                        if CurrentSettings.SourceCodePage=CP_UTF8 then
                          ConcatWideStringChar(patternw,ord(c))
                        else
                          ConcatWideStringChar(patternw,ASCIIChar2Unicode(c));
                      end;
                  end
                else
                  begin
                     if in_multiline_string and (c in [#10,#13]) and (not ((c=#10) and (last_c=#13))) then
                       begin
                         if len>=length(cstringpattern) then
                           SetLength(cstringpattern,length(cstringpattern)+256);
                         inc(len);
                         case CurrentSettings.LineEndingType of
                           le_cr :
                             cstringpattern[len]:=#13;
                           le_crlf :
                             begin
                               cstringpattern[len]:=#13;
                               inc(len);
                               cstringpattern[len]:=#10;
                             end;
                           le_lf :
                             cstringpattern[len]:=#10;
                           le_platform :
                             begin
                               if TargetInfo.newline=#13 then
                                 cstringpattern[len]:=#13
                               else if TargetInfo.newline=#13#10 then
                                 begin
                                   cstringpattern[len]:=#13;
                                   inc(len);
                                   cstringpattern[len]:=#10;
                                 end
                               else if TargetInfo.newline=#10 then
                                 cstringpattern[len]:=#10;
                             end;
                           le_source :
                             cstringpattern[len]:=c;
                         end;
                         had_newline:=true;
                         inc(line_no);
                       end
                     else if not (in_multiline_string and (c in [#10,#13])) then
                       begin
                         if len>=length(cstringpattern) then
                           SetLength(cstringpattern,length(cstringpattern)+256);
                         inc(len);
                         cstringpattern[len]:=c;
                       end;
                  end;
              last_c:=c;
              until false;
            end;
          '^' :
            begin
              readchar;
              c:=upcase(c);
              if c<#64 then
               c:=chr(ord(c)+64)
              else
               c:=chr(ord(c)-64);

              if iswidestring then
                ConcatWideStringChar(patternw,ASCIIChar2Unicode(c))
              else
                begin
                  if len>=length(cstringpattern) then
                    SetLength(cstringpattern,length(cstringpattern)+256);
                   inc(len);
                   cstringpattern[len]:=c;
                end;

              readchar;
            end;
          else
           break;
        end;
      last_c:=c;
      until false;

      { strings with length 1 become const chars }
      if iswidestring then
        begin
          if had_multiline_string and not backtick then
            begin
            postprocessutf8multiline(len,quote_col,init_quote_count);
            end;
          if patternw.len=1 then
            token:=_CWCHAR
          else
            token:=_CWSTRING;
        end
      else
        begin
          if had_multiline_string and not backtick then
            begin
            postprocessmultiline(len,quote_col,init_quote_count);
            end
          else
            SetLength(cstringpattern,len);
          if length(cstringpattern)=1 then
            begin
              token:=_CCHAR;
              pattern:=cstringpattern;
            end
          else
            token:=_CSTRING;
        end;
      had_multiline_string:=False;
      exit(true);
    end;

{****************************************************************************
                               Token Scanner
****************************************************************************}

    procedure TScannerFile.readtoken(allowrecordtoken:boolean);
      var
        low,high,mid : LongInt;
        mac     : TMacro;
        firstdigitread: boolean;
        had_newline,first_multiline : boolean;
        trimcount : word;
       label
         exit_label;
      begin
        had_newline:=false;
        first_multiline:=false;
        FlushPendingSwitchesState;

        { record tokens? }
        if allowrecordtoken and
           Assigned(recordtokenbuf) then
          recordtoken;

        { replay tokens? }
        if Assigned(replaytokenbuf) then
          begin
            replaytoken;
            goto exit_label;
          end;

      { was there already a token read, then return that token }
        if nexttoken<>NOTOKEN then
         begin
           setnexttoken;
           goto exit_label;
         end;

      { Skip all spaces and comments }
        repeat
          case c of
            '{' :
              skipcomment(true);
            #26 :
              begin
                reload;
                if (c=#26) and not Assigned(inputfile.next) then
                  break;
              end;
            ' ',#9..#13 :
              begin
{$ifdef PREPROCWRITE}
                if ParaPreprocess then
                 begin
                   if c=#10 then
                    preprocfile.eolfound:=true
                   else
                    preprocfile.spacefound:=true;
                 end;
{$endif PREPROCWRITE}
                skipspace;
              end
            else
              break;
          end;
        until false;

      { Save current token position, for EOF its already loaded }
        if c<>#26 then
          gettokenpos;

      { Check first for a identifier/keyword, this is 20+% faster (PFV) }
        if c in ['A'..'Z','a'..'z','_'] then
         begin
           readstring;
           token:=_ID;
           idtoken:=_ID;
         { keyword or any other known token,
           pattern is always uppercased }
           if (pattern[1]<>'_') and (length(pattern) in [tokenlenmin..tokenlenmax]) then
            begin
              low:=ord(tokenidx^[length(pattern),pattern[1]].first);
              high:=ord(tokenidx^[length(pattern),pattern[1]].last);
              while low<high do
               begin
                 mid:=(high+low+1) shr 1;
                 if pattern<tokeninfo^[TToken(mid)].str then
                  high:=mid-1
                 else
                  low:=mid;
               end;
              with tokeninfo^[TToken(high)] do
                if pattern=str then
                  begin
                    if (keyword*CurrentSettings.ModeSwitches)<>[] then
                      if op=NOTOKEN then
                        token:=TToken(high)
                      else
                        token:=op;
                    idtoken:=TToken(high);
                  end;
            end;
         { Only process identifiers and not keywords }
           if token=_ID then
            begin
            { this takes some time ... }
              if (cs_support_macro in CurrentSettings.ModuleSwitches) then
               begin
                 mac:=TMacro(search_macro(pattern));
                 if Assigned(mac) and (not mac.is_compiler_var) and mac.is_c_macro then
                  begin
                    if (yylexcount<max_macro_nesting) and (macro_nesting_depth<max_macro_nesting) then
                     begin
                       mac.is_used:=true;
                       inc(yylexcount);
                       substitutemacro(pattern,pchar(mac.buftext),mac.buflen,
                         mac.fileinfo.line,mac.fileinfo.fileindex,false);
                       { handle empty macros }
                       if c=#0 then
                         begin
                           reload;
                           { avoid macro nesting error in case of
                             a sequence of empty macros, see #38802 }
                           dec(yylexcount);
                           readtoken(false);
                         end
                       else
                         begin
                           readtoken(false);
                           { that's all folks }
                           dec(yylexcount);
                         end;
                       exit;
                     end
                    else
                     Message(scan_w_macro_too_deep);
                  end;
               end;
            end;
         { return token }
           goto exit_label;
         end
        else
         begin
           idtoken:=_NOID;
           case c of

             '$' :
               begin
                 readnumber;
                 token:=_INTCONST;
                 goto exit_label;
               end;

             '%' :
               begin
                 if [m_fpc,m_delphi] * CurrentSettings.ModeSwitches = [] then
                  Illegal_Char(c)
                 else
                  begin
                    readnumber;
                    token:=_INTCONST;
                    goto exit_label;
                  end;
               end;

             '&' :
               begin
                 if [m_fpc,m_delphi] * CurrentSettings.ModeSwitches <> [] then
                  begin
                    readnumber;
                    if length(pattern)=1 then
                      begin
                        { does really an identifier follow? }
                        if not (c in ['_','A'..'Z','a'..'z']) then
                          message2(scan_f_syn_expected,tokeninfo^[_ID].str,c);
                        readstring;
                        token:=_ID;
                        idtoken:=_ID;
                      end
                    else
                      token:=_INTCONST;
                    goto exit_label;
                  end
                 else if m_mac in CurrentSettings.ModeSwitches then
                  begin
                    readchar;
                    token:=_AMPERSAND;
                    goto exit_label;
                  end
                 else
                  Illegal_Char(c);
               end;

             '0'..'9' :
               begin
                 readnumber;
                 if (c in ['.','e','E']) then
                  begin
                  { first check for a . }
                    if c='.' then
                     begin
                       cachenexttokenpos;
                       readchar;
                       { is it a .. from a range? }
                       case c of
                         '.' :
                           begin
                             readchar;
                             token:=_INTCONST;
                             nexttoken:=_POINTPOINT;
                             goto exit_label;
                           end;
                         ')' :
                           begin
                             readchar;
                             token:=_INTCONST;
                             nexttoken:=_RECKKLAMMER;
                             goto exit_label;
                           end;
                         '0'..'9' :
                           begin
                             { insert the number after the . }
                             pattern:=pattern+'.';
                             firstdigitread:=false;
                             while (c in ['0'..'9']) or
                              ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and firstdigitread and (c='_')) do
                              begin
                                if c<>'_' then
                                  pattern:=pattern+c;
                                readchar;
                                firstdigitread:=true;
                              end;
                           end;
                         else
                           begin
                             token:=_INTCONST;
                             nexttoken:=_POINT;
                             goto exit_label;
                           end;
                       end;
                      end;
                  { E can also follow after a point is scanned }
                    if c in ['e','E'] then
                     begin
                       pattern:=pattern+'E';
                       readchar;
                       if c in ['-','+'] then
                        begin
                          pattern:=pattern+c;
                          readchar;
                        end;
                       if not(c in ['0'..'9']) then
                         Illegal_Char(c);
                       firstdigitread:=false;
                       while (c in ['0'..'9']) or
                        ((m_underscoreisseparator in CurrentSettings.ModeSwitches) and firstdigitread and (c='_')) do
                        begin
                          if c<>'_' then
                          pattern:=pattern+c;
                          readchar;
                          firstdigitread:=true;
                        end;
                     end;
                    token:=_REALNUMBER;
                    goto exit_label;
                  end;
                 token:=_INTCONST;
                 goto exit_label;
               end;

             ';' :
               begin
                 readchar;
                 token:=_SEMICOLON;
                 goto exit_label;
               end;

             '[' :
               begin
                 readchar;
                 token:=_LECKKLAMMER;
                 goto exit_label;
               end;

             ']' :
               begin
                 readchar;
                 token:=_RECKKLAMMER;
                 goto exit_label;
               end;

             '(' :
               begin
                 readchar;
                 case c of
                   '*' :
                     begin
                       skipoldtpcomment(true);
                       readtoken(false);
                       exit;
                     end;
                   '.' :
                     begin
                       readchar;
                       token:=_LECKKLAMMER;
                       goto exit_label;
                     end;
                 end;
                 token:=_LKLAMMER;
                 goto exit_label;
               end;

             ')' :
               begin
                 readchar;
                 token:=_RKLAMMER;
                 goto exit_label;
               end;

             '+' :
               begin
                 readchar;
                 if c='=' then
                  begin
                    readchar;
                    token:=_PLUSASN;
                    goto exit_label;
                  end;
                 token:=_PLUS;
                 goto exit_label;
               end;

             '-' :
               begin
                 readchar;
                 if c='=' then
                  begin
                    readchar;
                    token:=_MINUSASN;
                    goto exit_label;
                  end;
                 token:=_MINUS;
                 goto exit_label;
               end;

             ':' :
               begin
                 readchar;
                 if c='=' then
                  begin
                    readchar;
                    token:=_ASSIGNMENT;
                    goto exit_label;
                  end;
                 token:=_COLON;
                 goto exit_label;
               end;

             '*' :
               begin
                 readchar;
                 if c='=' then
                  begin
                    readchar;
                    token:=_STARASN;
                  end
                 else
                  if c='*' then
                   begin
                     readchar;
                     token:=_STARSTAR;
                   end
                 else
                  token:=_STAR;
                 goto exit_label;
               end;

             '/' :
               begin
                 readchar;
                 case c of
                   '=' :
                     begin
                       readchar;
                       token:=_SLASHASN;
                       goto exit_label;
                     end;
                   '/' :
                     begin
                       skipdelphicomment;
                       readtoken(false);
                       exit;
                     end;
                 end;
                 token:=_SLASH;
                 goto exit_label;
               end;

             '|' :
               if m_mac in CurrentSettings.ModeSwitches then
                begin
                  readchar;
                  token:=_PIPE;
                  goto exit_label;
                end
               else
                Illegal_Char(c);

             '=' :
               begin
                 readchar;
                 token:=_EQ;
                 goto exit_label;
               end;

             '.' :
               begin
                 readchar;
                 case c of
                   '.' :
                     begin
                       readchar;
                       case c of
                         '.' :
                         begin
                           readchar;
                           token:=_POINTPOINTPOINT;
                           goto exit_label;
                         end;
                       else
                         begin
                           token:=_POINTPOINT;
                           goto exit_label;
                         end;
                       end;
                     end;
                   ')' :
                     begin
                       readchar;
                       token:=_RECKKLAMMER;
                       goto exit_label;
                     end;
                 end;
                 token:=_POINT;
                 goto exit_label;
               end;

             '@' :
               begin
                 readchar;
                 token:=_KLAMMERAFFE;
                 goto exit_label;
               end;

             ',' :
               begin
                 readchar;
                 token:=_COMMA;
                 goto exit_label;
               end;

             '''','#','^','`' :
               begin
                 readstringconstant;
                 goto exit_label;
               end;
             '>' :
               begin
                 readchar;
                 if (Block_Type in [bt_type,bt_var_type,bt_const_type]) then
                   token:=_RSHARPBRACKET
                 else
                   begin
                     case c of
                       '=' :
                         begin
                           readchar;
                           token:=_GTE;
                           goto exit_label;
                         end;
                       '>' :
                         begin
                           readchar;
                           token:=_OP_SHR;
                           goto exit_label;
                         end;
                       '<' :
                         begin { >< is for a symetric diff for sets }
                           readchar;
                           token:=_SYMDIF;
                           goto exit_label;
                         end;
                     end;
                     token:=_GT;
                   end;
                 goto exit_label;
               end;

             '<' :
               begin
                 readchar;
                 if (Block_Type in [bt_type,bt_var_type,bt_const_type]) then
                   token:=_LSHARPBRACKET
                 else
                   begin
                     case c of
                       '>' :
                         begin
                           readchar;
                           token:=_NE;
                           goto exit_label;
                         end;
                       '=' :
                         begin
                           readchar;
                           token:=_LTE;
                           goto exit_label;
                         end;
                       '<' :
                         begin
                           readchar;
                           token:=_OP_SHL;
                           goto exit_label;
                         end;
                     end;
                     token:=_LT;
                   end;
                 goto exit_label;
               end;

             #26 :
               begin
                 token:=_EOF;
                 checkpreprocstack;
                 goto exit_label;
               end;
             else if inputfile.InternallyGeneratedMacro and
                     (c in [internal_macro_escape_begin..internal_macro_escape_end]) then
               begin
                 token:=_ID;
                 readstring;
               end
             else
               Illegal_Char(c);
           end;
        end;
exit_label:
        lasttoken:=token;
      end;


    function TScannerFile.readpreproc:TToken;
      var
        low,high,mid: LongInt;
        optoken: TToken;
      begin
         { Added the assignment to NOTOKEN below because I got a DFA uninitialized result
           warning when building the compiler with -O3, which broke compilation with -Sew.
           - Akira1364 }
         readpreproc:=NOTOKEN;
         skipspace;
         case c of
           '_',
           'A'..'Z',
           'a'..'z' :
             begin
               readstring;
               optoken:=_ID;
               if (pattern[1]<>'_') and (length(pattern) in [tokenlenmin..tokenlenmax]) then
                begin
                  low:=ord(tokenidx^[length(pattern),pattern[1]].first);
                  high:=ord(tokenidx^[length(pattern),pattern[1]].last);
                  while low<high do
                   begin
                     mid:=(high+low+1) shr 1;
                     if pattern<tokeninfo^[TToken(mid)].str then
                      high:=mid-1
                     else
                      low:=mid;
                   end;
                  with tokeninfo^[TToken(high)] do
                    if pattern=str then
                      begin
                        if (keyword*CurrentSettings.ModeSwitches)<>[] then
                          if op=NOTOKEN then
                            optoken:=TToken(high)
                          else
                            optoken:=op;
                      end;
                  if not (optoken in preproc_operators) then
                    optoken:=_ID;
                end;
               CurrentScanner.preproc_pattern:=pattern;
               readpreproc:=optoken;
             end;
           '''','`' :
             if not ((c='`') and (not (m_multiline_strings in CurrentSettings.ModeSwitches))) then
               begin
                 cstringpattern:=readquotedstring;
                 CurrentScanner.preproc_pattern:=cstringpattern;
                 readpreproc:=_CSTRING;
               end;
           '0'..'9' :
             begin
               readnumber;
               if (c in ['.','e','E']) then
                 begin
                   { first check for a . }
                   if c='.' then
                     begin
                       readchar;
                       if c in ['0'..'9'] then
                         begin
                           { insert the number after the . }
                           pattern:=pattern+'.';
                           while c in ['0'..'9'] do
                             begin
                               pattern:=pattern+c;
                               readchar;
                             end;
                         end
                       else
                         Illegal_Char(c);
                     end;
                  { E can also follow after a point is scanned }
                   if c in ['e','E'] then
                     begin
                       pattern:=pattern+'E';
                       readchar;
                       if c in ['-','+'] then
                         begin
                           pattern:=pattern+c;
                           readchar;
                         end;
                       if not(c in ['0'..'9']) then
                         Illegal_Char(c);
                       while c in ['0'..'9'] do
                         begin
                           pattern:=pattern+c;
                           readchar;
                         end;
                     end;
                   readpreproc:=_REALNUMBER;
                 end
               else
                 readpreproc:=_INTCONST;
               CurrentScanner.preproc_pattern:=pattern;
             end;
           '$','%':
             begin
               readnumber;
               CurrentScanner.preproc_pattern:=pattern;
               readpreproc:=_INTCONST;
             end;
           '&' :
             begin
                readnumber;
                if length(pattern)=1 then
                  begin
                    readstring;
                    readpreproc:=_ID;
                  end
                else
                  readpreproc:=_INTCONST;
               CurrentScanner.preproc_pattern:=pattern;
             end;
           '.' :
             begin
               readchar;
               readpreproc:=_POINT;
             end;
           ',' :
             begin
               readchar;
               readpreproc:=_COMMA;
             end;
           '}' :
             begin
               readpreproc:=_END;
             end;
           '(' :
             begin
               readchar;
               readpreproc:=_LKLAMMER;
             end;
           ')' :
             begin
               readchar;
               readpreproc:=_RKLAMMER;
             end;
           '[' :
             begin
               readchar;
               readpreproc:=_LECKKLAMMER;
             end;
           ']' :
             begin
               readchar;
               readpreproc:=_RECKKLAMMER;
             end;
           '+' :
             begin
               readchar;
               readpreproc:=_PLUS;
             end;
           '-' :
             begin
               readchar;
               readpreproc:=_MINUS;
             end;
           '*' :
             begin
               readchar;
               readpreproc:=_STAR;
             end;
           '/' :
             begin
               readchar;
               readpreproc:=_SLASH;
             end;
           '=' :
             begin
               readchar;
               readpreproc:=_EQ;
             end;
           '>' :
             begin
               readchar;
               if c='=' then
                 begin
                   readchar;
                   readpreproc:=_GTE;
                 end
               else
                 readpreproc:=_GT;
             end;
           '<' :
             begin
               readchar;
               case c of
                 '>' :
                   begin
                     readchar;
                     readpreproc:=_NE;
                   end;
                 '=' :
                   begin
                     readchar;
                     readpreproc:=_LTE;
                   end;
                 else
                   readpreproc:=_LT;
               end;
             end;
           #26 :
             begin
               readpreproc:=_EOF;
               checkpreprocstack;
             end;
           else
             begin
               Illegal_Char(c);
               readpreproc:=NOTOKEN;
             end;
         end;
      end;


    function TScannerFile.readpreprocint(var value:int64;const place:string):boolean;
      var
        hs : TExprValue;
      begin
        hs:=preproc_comp_expr(nil);
        if hs.isInt then
          begin
            value:=hs.asInt64;
            result:=true;
          end
        else
          begin
            hs.error('Integer',place);
            result:=false;
          end;
        hs.free;
        hs := nil;
      end;


    function TScannerFile.readpreprocset(conform_to:TSetDef;var value:TNormalSet;const place:string):boolean;
      var
        hs : TExprValue;
      begin
        hs:=preproc_comp_expr(conform_to);
        if hs.def.typ=setdef then
          begin
            value:=hs.asSet;
            result:=true;
          end
        else
          begin
            hs.error('Set',place);
            result:=false;
          end;
        hs.free;
        hs := nil;
      end;


    function TScannerFile.asmgetchar : char;
      begin
         readchar;
         repeat
           case c of
             #26 :
               begin
                 reload;
                 if (c=#26) and not Assigned(inputfile.next) then
                   end_of_file;
                 continue;
               end;
             else
               begin
                 asmgetchar:=c;
                 exit;
               end;
           end;
         until false;
      end;

{$ifdef EXTDEBUG}
    function TScannerFile.DumpPointer: string;
      var
        i: Integer;

      begin
        Result:='';
        if inputpointer=nil then exit;
        i:=0;
        While (inputpointer[I]<>#0) and (i<200) do
          inc(i);
        SetLength(result,I);
        move(inputpointer^,Result[1],I);
        result:='<'+IntToStr(inputstart)+'>'+result;
      end;
{$endif EXTDEBUG}

{*****************************************************************************
                                   Helpers
*****************************************************************************}

    procedure AddDirective(const s:string; dm: TDirectiveMode; p:TDirectiveProc);
      begin
        if dm in [directive_all, directive_turbo] then
          TDirectiveItem.create(turbo_scannerdirectives,s,p);
        if dm in [directive_all, directive_mac] then
          TDirectiveItem.create(mac_scannerdirectives,s,p);
      end;

    procedure AddConditional(const s:string; dm: TDirectiveMode; p:TDirectiveProc);
      begin
        if dm in [directive_all, directive_turbo] then
          TDirectiveItem.createcond(turbo_scannerdirectives,s,p);
        if dm in [directive_all, directive_mac] then
          TDirectiveItem.createcond(mac_scannerdirectives,s,p);
      end;

{*****************************************************************************
                                Initialization
*****************************************************************************}

    procedure InitScanner;
      begin
        turbo_scannerdirectives:=TFPHashObjectList.Create;
        mac_scannerdirectives:=TFPHashObjectList.Create;

        { Common directives and conditionals }
        AddDirective('I',directive_all, @dir_include);
        AddDirective('DEFINE',directive_all, @dir_define);
        AddDirective('UNDEF',directive_all, @dir_undef);

        AddConditional('IF',directive_all, @dir_if);
        AddConditional('IFDEF',directive_all, @dir_ifdef);
        AddConditional('IFNDEF',directive_all, @dir_ifndef);
        AddConditional('ELSE',directive_all, @dir_else);
        AddConditional('ELSEIF',directive_all, @dir_elseif);
        AddConditional('ENDIF',directive_all, @dir_endif);

        { Directives and conditionals for all modes except mode macpas}
        AddDirective('INCLUDE',directive_turbo, @dir_include);
        AddDirective('LIBPREFIX',directive_turbo, @dir_libprefix);
        AddDirective('LIBSUFFIX',directive_turbo, @dir_libsuffix);
        AddDirective('EXTENSION',directive_turbo, @dir_extension);

        AddConditional('IFEND',directive_turbo, @dir_ifend);
        AddConditional('IFOPT',directive_turbo, @dir_ifopt);

        { Directives and conditionals for mode macpas: }
        AddDirective('SETC',directive_mac, @dir_setc);
        AddDirective('DEFINEC',directive_mac, @dir_definec);
        AddDirective('UNDEFC',directive_mac, @dir_undef);

        AddConditional('IFC',directive_mac, @dir_if);
        AddConditional('ELSEC',directive_mac, @dir_else);
        AddConditional('ELIFC',directive_mac, @dir_elseif);
        AddConditional('ENDC',directive_mac, @dir_endif);
      end;


    procedure DoneScanner;
      begin
        turbo_scannerdirectives.Free;
        turbo_scannerdirectives := nil;
        mac_scannerdirectives.Free;
        mac_scannerdirectives := nil;
      end;

end.
