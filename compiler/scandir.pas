{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit implements directive parsing for the scanner

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
unit scandir;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      Systems;

    const
      switchesstatestackmax = 20;

    type
      TSavedSwitchesState = record
        localsw: TLocalSwitches;
        verbosity: LongInt;
        PMessage : PMessageStateRecord;
        alignment : TAlignmentInfo;
        SetAlloc,
        PackEnum,
        PackRecords : shortint;
        AsmMode : TAsmMode;
        OptimizerSwitches : TOptimizerSwitches;
      end;

    type
      TSwitchesStateStack = array[0..switchesstatestackmax] of TSavedSwitchesState;

    var
      SwitchesStateStack:TSwitchesStateStack;
      SwitchesStateStackPos: Integer;

    procedure InitScannerDirectives;

  implementation

    uses
      SysUtils,
      CUtils,CFileUtl,
      Globals,WideStr,CPUInfo,tokens,
      Verbose,CompHook,PPU,
      Scanner,Switches,
      FModule,CompRsrc,
      defutil,
      DirParse,link,
      symconst,SymTable,SymBase,symtype,SymSym,symdef,
      rabase;

{*****************************************************************************
                                    Helpers
*****************************************************************************}

    procedure do_delphiswitch(sw:char);
      var
        state : char;
      begin
      { c contains the next char, a + or - would be fine }
        state:=CurrentScanner.ReadState;
        if state in ['-','+'] then
          HandleSwitch(sw,state);
      end;


    procedure do_setverbose(flag:char);
      var
        state : char;
      begin
      { support ON/OFF }
        state:=CurrentScanner.ReadState;
        RecordPendingVerbositySwitch(flag,state);
      end;


    procedure do_moduleswitch(sw:TModuleSwitch);
      var
        state : char;
      begin
        state:=CurrentScanner.ReadState;
        if (sw<>cs_modulenone) and (state in ['-','+']) then
         begin
           if state='-' then
            exclude(CurrentSettings.ModuleSwitches,sw)
           else
            include(CurrentSettings.ModuleSwitches,sw);
         end;
      end;


    procedure do_localswitch(sw:TLocalSwitch);
      var
        state : char;
      begin
        state:=CurrentScanner.ReadState;
        if (sw<>cs_localnone) and (state in ['-','+']) then
          RecordPendingLocalSwitch(sw,state);
      end;

    function do_localswitchdefault(sw:TLocalSwitch): char;
      begin
        result:=CurrentScanner.ReadStateDefault;
        if (sw<>cs_localnone) and (result in ['-','+','*']) then
          RecordPendingLocalSwitch(sw,result);
      end;


    procedure do_moduleflagswitch(flag:TModuleFlag;optional:boolean);
      var
        state : char;
      begin
        if optional then
          state:=CurrentScanner.ReadOptionalState('+')
        else
          state:=CurrentScanner.ReadState;
        if state='-' then
          exclude(CurrentModule.ModuleFlags,flag)
        else
          include(CurrentModule.ModuleFlags,flag);
      end;


    procedure do_message(w:integer);
      begin
        CurrentScanner.SkipSpace;
        Message1(w,CurrentScanner.ReadLongComment);
      end;


    procedure do_version(out major, minor, revision: word; out verstr: string; allowrevision: boolean; out IsSet: boolean);
      var
        majorl,
        minorl,
        revisionl,
        error : LongInt;
      begin
        { change description global var in all cases }
        { it not used but in win32 and os2 }
        CurrentScanner.SkipSpace;
        { we should only accept Major.Minor format for win32 and os2 }
        CurrentScanner.ReadNumber;
        major:=0;
        minor:=0;
        revision:=0;
        verstr:='';
        IsSet:=false;
        majorl:=0;
        minorl:=0;
        revisionl:=0;
        val(CurrentScanner.FPattern,majorl,error);
        if (error<>0) or (majorl > high(word)) or (majorl < 0) then
          begin
            Message1(scan_w_wrong_version_ignored,CurrentScanner.FPattern);
            exit;
          end;
        IsSet:=true;
        if CurrentScanner.FChar='.' then
          begin
            CurrentScanner.ReadChar;
            CurrentScanner.ReadNumber;
            val(CurrentScanner.FPattern,minorl,error);
            if (error<>0) or (minorl > high(word)) or (minorl < 0) then
              begin
                Message1(scan_w_wrong_version_ignored,ToStr(majorl)+'.'+CurrentScanner.FPattern);
                exit;
              end;
            if (CurrentScanner.FChar='.') and
               allowrevision then
              begin
                 CurrentScanner.ReadChar;
                 CurrentScanner.ReadNumber;
                 val(CurrentScanner.FPattern,revisionl,error);
                 if (error<>0) or (revisionl > high(word)) or (revisionl < 0) then
                   begin
                      Message1(scan_w_wrong_version_ignored,ToStr(majorl)+'.'+ToStr(minorl)+'.'+CurrentScanner.FPattern);
                      exit;
                   end;
                 major:=word(majorl);
                 minor:=word(minorl);
                 revision:=word(revisionl);
                 verstr:=ToStr(major)+','+ToStr(minor)+','+ToStr(revision);
              end
            else
              begin
                 major:=word(majorl);
                 minor:=word(minorl);
                 verstr:=ToStr(major)+'.'+ToStr(minor);
              end;
          end
        else
          begin
            major:=word(majorl);
            verstr:=ToStr(major);
          end;
      end;


{*****************************************************************************
                              Directive Callbacks
*****************************************************************************}

    procedure dir_align;
      var
        hs : string;
        b : LongInt;
      begin
        CurrentScanner.SkipSpace;
        if not(CurrentScanner.FChar in ['0'..'9']) then
         begin
           { Support also the ON and OFF as switch }
           hs:=CurrentScanner.ReadID;
           if (hs='ON') then
            CurrentSettings.PackRecords:=4
           else if (hs='OFF') then
             CurrentSettings.PackRecords:=1
           else if m_mac in CurrentSettings.ModeSwitches then
             begin
               { Support switches used in Apples Universal Interfaces}
               if (hs='MAC68K') then
                 CurrentSettings.PackRecords:=Mac68KAlignment
               { "power" alignment is the default C packrecords setting on
                 Mac OS X }
               else if (hs='POWER') or (hs='POWERPC') then
                 CurrentSettings.PackRecords:=CAlignment
               else if (hs='RESET') then
                 CurrentSettings.PackRecords:=Default_Settings.PackRecords
               else
                 Message1(scan_e_illegal_pack_records,hs);
             end
           else
             Message1(scan_e_illegal_pack_records,hs);
         end
        else
         begin
           b:=CurrentScanner.ReadVal;
           case b of
             1,2,4,8,16,32 : CurrentSettings.PackRecords:=b;
           else
            Message1(scan_e_illegal_pack_records,ToStr(b));
           end;
         end;
      end;

    procedure dir_a1;
      begin
        CurrentSettings.PackRecords:=1;
      end;

    procedure dir_a2;
      begin
        CurrentSettings.PackRecords:=2;
      end;

    procedure dir_a4;
      begin
        CurrentSettings.PackRecords:=4;
      end;

    procedure dir_a8;
      begin
        CurrentSettings.PackRecords:=8;
      end;

    procedure dir_asmcpu;
      var
        s : string;
        cpu: TCPUType;
        found: Boolean;
      begin
        CurrentScanner.SkipSpace;
        s:=CurrentScanner.ReadID;
        If Inside_Asm_Statement then
          Message1(scan_w_no_asm_reader_switch_inside_asm,s);
        if s='ANY' then
          CurrentSettings.AsmCPUType:=cpu_none
        else if s='CURRENT' then
          CurrentSettings.AsmCPUType:=CurrentSettings.CPUType
        else
          begin
            found:=false;
            for cpu:=succ(low(TCPUType)) to high(TCPUType) do
              if s=CPUTypeStr[cpu] then
                begin
                  found:=true;
                  CurrentSettings.AsmCPUType:=cpu;
                  break;
                end;
            if not found then
              Message1(scan_e_illegal_asmcpu_specifier,s);
          end;
      end;

    procedure dir_asmmode;
      var
        s : string;
        AsmMode: TAsmMode;
      begin
        CurrentScanner.SkipSpace;
        s:=CurrentScanner.ReadID;
        If Inside_Asm_Statement then
          Message1(scan_w_no_asm_reader_switch_inside_asm,s);
        if s='DEFAULT' then
          RecordPendingAsmMode(InitSettings.AsmMode)
        else
         if not SetAsmReadMode(s,AsmMode) then
           Message1(scan_e_illegal_asmmode_specifier,s)
         else
           RecordPendingAsmMode(AsmMode);
      end;

    procedure dir_apptype;
      var
         hs : string;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          begin
            if m_delphi in CurrentSettings.ModeSwitches then
              Message(scan_n_app_type_not_support)
            else
              Message(scan_w_app_type_not_support);
          end
        else
          begin
            if not CurrentModule.InGlobal then
              Message(scan_w_switch_is_global)
            else
              begin
                 CurrentScanner.SkipSpace;
                 hs:=CurrentScanner.ReadID;
                 if hs='GUI' then
                   SetApptype(app_gui)
                 else if hs='CONSOLE' then
                   SetApptype(app_cui)
                 else if (hs='NATIVE') and (TargetInfo.system in systems_windows) then
                   SetApptype(app_native)
                 else
                   Message1(scan_w_unsupported_app_type,hs);
              end;
          end;
      end;


    procedure dir_calling;
      var
         hs : string;
      begin
        CurrentScanner.SkipSpace;
        hs:=CurrentScanner.ReadID;
        if (hs='') then
          Message(parser_e_proc_directive_expected)
        else
          RecordPendingCallingSwitch(hs);
      end;


    procedure dir_checkpointer;
      var
        switch: char;
      begin
        switch:=do_localswitchdefault(cs_checkpointer);
        if (switch='+') and
           not(TargetInfo.system in systems_support_checkpointer) then
          Message1(scan_e_unsupported_switch,'CHECKPOINTER+');
      end;


    procedure dir_excessprecision;
      begin
        do_localswitch(cs_excessprecision);
      end;


    procedure dir_checkcasecoverage;
      begin
        do_localswitch(cs_check_all_case_coverage);
      end;


    procedure dir_checkfpuexceptions;
      begin
        do_localswitch(cs_check_fpu_exceptions);
      end;


    procedure dir_objectchecks;
      begin
        do_localswitch(cs_check_object);
      end;


    procedure dir_ieeeerrors;
      begin
        do_localswitch(cs_ieee_errors);
      end;


    procedure dir_assertions;
      begin
        do_delphiswitch('C');
      end;


    procedure dir_booleval;
      begin
        do_delphiswitch('B');
      end;

    procedure dir_debuginfo;
      begin
        do_delphiswitch('D');
      end;

    procedure dir_definitioninfo;
      begin
        do_delphiswitch('Y');
      end;

    procedure dir_denypackageunit;
      begin
        do_moduleflagswitch(mf_package_deny,true);
      end;

    procedure dir_description;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          Message(scan_w_description_not_support);
        { change description global var in all cases }
        { it not used but in win32 and os2 }
        CurrentScanner.SkipSpace;
        Description:=CurrentScanner.ReadComment;
        DescriptionSetExplicity:=true;
      end;

    procedure dir_error;
      begin
        do_message(scan_e_user_defined);
      end;

    procedure dir_extendedsyntax;
      begin
        do_delphiswitch('X');
      end;

    procedure dir_fatal;
      begin
        do_message(scan_f_user_defined);
      end;

    procedure dir_stackchecking;
      begin
        do_delphiswitch('S');
      end;

    procedure dir_fputype;
      begin
        CurrentScanner.SkipSpace;
        Undef_System_Macro('FPU'+FPUTypeStr[CurrentSettings.FPUType]);
        if not(SetFPUType(upper(CurrentScanner.ReadComment),CurrentSettings.FPUType)) then
          comment(VError,'Illegal FPU type');
        Def_System_Macro('FPU'+FPUTypeStr[CurrentSettings.FPUType]);
     end;

    procedure dir_frameworkpath;
      begin
        if not CurrentModule.InGlobal then
         Message(scan_w_switch_is_global)
        else if not(TargetInfo.system in systems_darwin) then
          begin
            Message(scan_w_frameworks_darwin_only);
            CurrentScanner.SkipSpace;
            CurrentScanner.ReadComment
          end
        else
          begin
            CurrentScanner.SkipSpace;
            CurrentModule.LocalFrameworkSearchPath.AddPath(CurrentScanner.ReadComment,false);
          end;
      end;

    procedure dir_goto;
      begin
        do_moduleswitch(cs_support_goto);
      end;

    procedure dir_hint;
      begin
        do_message(scan_h_user_defined);
      end;

    procedure dir_hints;
      begin
        do_setverbose('H');
      end;

    procedure dir_imagebase;
      begin
        if not (TargetInfo.system in systems_windows) then
          Message(scan_w_imagebase_not_support);
        CurrentScanner.SkipSpace;
        ImageBase:=CurrentScanner.ReadVal;
        ImageBaseSetExplicity:=true
      end;

    procedure dir_implicitexceptions;
      begin
        do_moduleswitch(cs_implicit_exceptions);
      end;

    procedure dir_importeddata;
      begin
        do_delphiswitch('G');
      end;

    procedure dir_includepath;
      var
        path : string;
      begin
        if not CurrentModule.InGlobal then
         Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            path:=CurrentScanner.ReadComment;
            CurrentModule.LocalIncludeSearchPath.AddPath(path,false);
            Message2(general_t_includepath_local,CurrentModule.RealModuleName^,path);
          end;
      end;

    procedure dir_info;
      begin
        do_message(scan_i_user_defined);
      end;

    procedure dir_inline;
      begin
        do_localswitch(cs_do_inline);
      end;

    procedure dir_interfaces;
      var
        hs : string;
      begin
        {corba/com/default}
        CurrentScanner.SkipSpace;
        hs:=CurrentScanner.ReadID;
        if (hs='CORBA') then
          CurrentSettings.InterfaceType:=it_interfacecorba
        else if (hs='COM') then
          CurrentSettings.InterfaceType:=it_interfacecom
        else
             if (hs='DEFAULT') then
          CurrentSettings.InterfaceType:=InitSettings.InterfaceType
        else
          Message(scan_e_invalid_interface_type);
      end;

    procedure dir_iochecks;
      begin
        do_delphiswitch('I');
      end;

    procedure dir_libexport;
      begin
        {not implemented}
      end;

    procedure dir_librarypath;
      var
        path : string;
      begin
        if not CurrentModule.InGlobal then
         Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            path:=CurrentScanner.ReadComment;
            CurrentModule.LocalLibrarySearchPath.AddPath(path,false);
            Message2(general_t_librarypath_local,CurrentModule.RealModuleName^,path);
          end;
      end;

    procedure dir_link;
      var
        s : string;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar = '''' then
          begin
            s:= CurrentScanner.ReadQuotedString;
            CurrentScanner.ReadComment
          end
        else
          s:= TrimSpace(CurrentScanner.ReadComment);
        s:=FixFileName(s);
        if ExtractFileExt(s)='' then
          s:=ChangeFileExt(s,TargetInfo.objext);
        CurrentModule.LinkOtherOFiles.add(s,link_always);
      end;

    procedure dir_linkframework;
      var
        s : string;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar = '''' then
          begin
            s:= CurrentScanner.ReadQuotedString;
            CurrentScanner.ReadComment
          end
        else
          s:= TrimSpace(CurrentScanner.ReadComment);
        s:=FixFileName(s);
        if (TargetInfo.system in systems_darwin) then
          CurrentModule.LinkOtherFrameworks.add(s,link_always)
        else
          Message(scan_w_frameworks_darwin_only);
      end;

    procedure dir_linklib;
      type
        TLinkMode=(lm_shared,lm_static);
      var
        s : string;
        quote : char;
        libext,
        libname,
        linkmodestr : string;
        p : LongInt;
        linkMode : TLinkMode;
      begin
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar = '''' then
          begin
            libname:= CurrentScanner.ReadQuotedString;
            s:= CurrentScanner.ReadComment;
            p:=pos(',',s);
          end
        else
          begin
            s:= CurrentScanner.ReadComment;
            p:=pos(',',s);
            if p=0 then
              libname:=TrimSpace(s)
            else
              libname:=TrimSpace(copy(s,1,p-1));
          end;
        if p=0 then
          linkmodeStr:=''
        else
          linkmodeStr:=Upper(TrimSpace(copy(s,p+1,255)));


        if (libname='') or (libname='''''') or (libname='""') then
         exit;
        { create library name }
        if libname[1] in ['''','"'] then
         begin
           quote:=libname[1];
           Delete(libname,1,1);
           p:=pos(quote,libname);
           if p>0 then
            Delete(libname,p,1);
         end;
        libname:=FixFileName(libname);

        { get linkmode, default is to check the extension for
          the static library, otherwise shared linking is assumed }
        linkmode:=lm_shared;
        if linkModeStr='' then
         begin
           libext:=ExtractFileExt(libname);
           if libext=TargetInfo.staticClibext then
             linkMode:=lm_static;
         end
        else if linkModeStr='STATIC' then
         linkmode:=lm_static
        else if (LinkModeStr='SHARED') or (LinkModeStr='') then
         linkmode:=lm_shared
        else
         Comment(VError,'Wrong link mode specified: "'+Linkmodestr+'"');

        { add to the list of other libraries }
        if linkMode=lm_static then
         CurrentModule.LinkOtherStaticLibs.add(libname,link_always)
        else
         CurrentModule.LinkOtherSharedLibs.add(libname,link_always);
      end;

    procedure dir_localsymbols;
      begin
        do_delphiswitch('L');
      end;

    procedure dir_longstrings;
      begin
        { Consume the legacy ON/OFF syntax. HandleSwitch('H') is inert because
          the default String type is fixed for the compiler invocation. }
        do_delphiswitch('H');
      end;

    procedure dir_macro;
      begin
        do_moduleswitch(cs_support_macro);
      end;

    procedure dir_pascalmainname;
      var
        s: string;
      begin
        CurrentScanner.SkipSpace;
        s:=TrimSpace(CurrentScanner.ReadComment);
        if Assigned(CurrentModule.MainName) and
           (s<>CurrentModule.MainName^) then
          begin
            Message1(scan_w_multiple_main_name_overrides,CurrentModule.MainName^);
            StringDispose(CurrentModule.MainName)
          end
        else if (MainAliasName<>DefaultMainAliasName) and
                (MainAliasName<>s) then
          Message1(scan_w_multiple_main_name_overrides,MainAliasName);
        MainAliasName:=s;
        if (MainAliasName<>DefaultMainAliasName) then
          CurrentModule.MainName:=StringDup(MainAliasName);
      end;

    procedure dir_maxfpuregisters;
      var
         l  : integer;
         hs : string;
      begin
         CurrentScanner.SkipSpace;
         if not(CurrentScanner.FChar in ['0'..'9']) then
           begin
              hs:=CurrentScanner.ReadID;
              if (hs='NORMAL') or (hs='DEFAULT') then
                CurrentSettings.MaxFPURegisters:=-1
              else
                Message(scan_e_invalid_maxfpureg_value);
           end
         else
           begin
              l:=CurrentScanner.ReadVal;
              case l of
                 0..8:
                   CurrentSettings.MaxFPURegisters:=l;
                 else
                   Message(scan_e_invalid_maxfpureg_value);
              end;
           end;
      end;

    procedure dir_maxstacksize;
      begin
        if not (TargetInfo.system in systems_windows) then
          Message(scan_w_maxstacksize_not_support);
        CurrentScanner.SkipSpace;
        MaxStackSize:=CurrentScanner.ReadVal;
        MaxStackSizeSetExplicity:=true;
      end;

    procedure dir_memory;
      var
        l : int64;
        heapsize_limit: int64;
        maxheapsize_limit: int64;
      begin
        heapsize_limit:=high(LongInt);
        maxheapsize_limit:=high(LongInt);
        CurrentScanner.SkipSpace;
        l:=CurrentScanner.ReadVal;
        if (l>=1024)

          and (l<67107840)

        then
          StackSize:=min(l,67107839)
        else
          Message(scan_w_invalid_stacksize);
        if CurrentScanner.FChar=',' then
          begin
            CurrentScanner.ReadChar;
            CurrentScanner.SkipSpace;
            l:=CurrentScanner.ReadVal64;
            if l>=1024 then
              HeapSize:=min(l,heapsize_limit);
            if CurrentScanner.FChar=',' then
              begin
                CurrentScanner.ReadChar;
                CurrentScanner.SkipSpace;
                l:=CurrentScanner.ReadVal64;
                if l>=HeapSize then
                  MaxHeapSize:=min(l,maxheapsize_limit)
                else
                  Message(scan_w_heapmax_lessthan_heapmin);
              end;
          end;
      end;


    procedure dir_message;
      var
        hs : string;
        s  : AnsiString;
        w  : LongInt;
      begin
        w:=0;
        CurrentScanner.SkipSpace;
        { Message level specified? }
        if CurrentScanner.FChar='''' then
          w:=scan_n_user_defined
        else
          begin
            hs:=CurrentScanner.ReadID;
            if (hs='WARN') or (hs='WARNING') then
              w:=scan_w_user_defined
            else
              if (hs='ERROR') then
                w:=scan_e_user_defined
            else
              if (hs='FATAL') then
                w:=scan_f_user_defined
            else
              if (hs='HINT') then
                w:=scan_h_user_defined
            else
              if (hs='NOTE') then
                w:=scan_n_user_defined
            else
              if (hs='INFO') then
                w:=scan_i_user_defined
            else
              Message1(scan_w_illegal_directive,hs);
          end;
        { Only print message when there was no error }
        if w<>0 then
          begin
            CurrentScanner.SkipSpace;
            if CurrentScanner.FChar='''' then
              s:=CurrentScanner.ReadLongQuotedString
            else
              s:=CurrentScanner.ReadLongComment;
            Message1(w,s);
          end
        else
          CurrentScanner.ReadComment;
      end;


    procedure dir_minstacksize;
      begin
        if not (TargetInfo.system in systems_windows) then
          Message(scan_w_minstacksize_not_support);
        CurrentScanner.SkipSpace;
        MinStackSize:=CurrentScanner.ReadVal;
        MinStackSizeSetExplicity:=true;
      end;


    procedure dir_mode;

    begin
      if not CurrentModule.InGlobal then
        Message(scan_w_switch_is_global)
      else
        begin
          CurrentScanner.SkipSpace;
          CurrentScanner.ReadString;
          if not CurrentModule.ModeSwitchAllowed and
              not ((m_mac in CurrentSettings.ModeSwitches) and (CurrentScanner.FPattern='MACPAS')) then
            Message1(scan_e_mode_switch_not_allowed,CurrentScanner.FPattern)
          else if not SetCompileMode(CurrentScanner.FPattern,false) then
            Message1(scan_w_illegal_switch,CurrentScanner.FPattern)
        end;
      CurrentModule.ModeSwitchAllowed:= false;
    end;

    procedure dir_multilinestringlineending;
      var
        s : string;
      begin
        if not (m_multiline_strings in CurrentSettings.ModeSwitches) then
          Message1(scan_e_illegal_directive,'MULTILINESTRINGLINEENDING');
        CurrentScanner.SkipSpace;
        s:=CurrentScanner.ReadID;
        if (s='CR') then
          CurrentSettings.LineEndingType:=le_cr
        else if (s='CRLF') then
          CurrentSettings.LineEndingType:=le_crlf
        else if (s='LF') then
          CurrentSettings.LineEndingType:=le_lf
        else if (s='PLATFORM') then
          CurrentSettings.LineEndingType:=le_platform
        else if (s='SOURCE') then
          CurrentSettings.LineEndingType:=le_source
        else
          Message(scan_e_unknown_lineending_type);
      end;

    procedure dir_textblock;
      var
        s : string;
      begin
        if not (m_delphi in CurrentSettings.ModeSwitches) then
          Message1(scan_e_illegal_directive,'TEXTBLOCK');
        CurrentScanner.SkipSpace;
        s:=CurrentScanner.ReadID;
        if (s='CR') then
          CurrentSettings.LineEndingType:=le_cr
        else if (s='CRLF') then
          CurrentSettings.LineEndingType:=le_crlf
        else if (s='LF') then
          CurrentSettings.LineEndingType:=le_lf
        else if (s='NATIVE') then
          CurrentSettings.LineEndingType:=le_platform
        else
          Message(scan_e_unknown_lineending_type);
      end;

    procedure dir_multilinestringtrimleft;
      var
        count : LongInt;
        s : string;
      begin
        if not (m_multiline_strings in CurrentSettings.ModeSwitches) then
          Message1(scan_e_illegal_directive,'MULTILINESTRINGTRIMLEFT');
        CurrentScanner.SkipSpace;
        if (CurrentScanner.FChar in ['0'..'9']) then
          begin
            count:=CurrentScanner.ReadVal;
            if (count<0) or (count>high(word)) then
              Message(scan_e_trimcount_out_of_range)
            else
              begin
                CurrentSettings.WhitespaceTrimCount:=count;
                CurrentSettings.WhitespaceTrimAuto:=false;
              end;
          end
        else
          begin
            s:=CurrentScanner.ReadID;
            if s='ALL' then
              begin
                CurrentSettings.WhitespaceTrimCount:=high(word);
                CurrentSettings.WhitespaceTrimAuto:=false;
              end
            else if s='AUTO' then
              begin
                CurrentSettings.WhitespaceTrimCount:=0;
                CurrentSettings.WhitespaceTrimAuto:=true;
              end
            else
              begin
                CurrentSettings.WhitespaceTrimCount:=0;
                CurrentSettings.WhitespaceTrimAuto:=false;
              end;
          end;
      end;

    procedure dir_modeswitch;
      var
        s : string;
      begin
        if not CurrentModule.InGlobal then
          Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            CurrentScanner.ReadString;
            s:=CurrentScanner.FPattern;
            { don't combine the assignments to s as the method call will be
              done before "current_scanner.pattern" is assigned to s and the method changes
              "current_scanner.pattern" }
            s:=s+CurrentScanner.ReadOptionalState('+');
            if not SetCompileModeSwitch(s,false) then
              Message1(scan_w_illegal_switch,s)
          end;
      end;


    procedure dir_namespaces;

    { add namespaces to the local namespace list }
      var
        s : string;

    begin
      if not CurrentModule.InGlobal then
        Message(scan_w_switch_is_global)
      else
        begin
          CurrentScanner.SkipSpace;
          CurrentScanner.ReadString;
          s:=CurrentScanner.FOrgPattern;
          While (s<>'') do
            begin
              // We may not yet have a correct module namespacelist.
              if Assigned(CurrentNamespaceList) then
                CurrentNamespaceList.Insert(s)
              else // copied when correct module is activated
                PreModule_NamespaceList.Insert(s);
              s:='';
              if CurrentScanner.FChar=',' then
                begin
                  CurrentScanner.ReadChar;
                  CurrentScanner.SkipSpace;
                  CurrentScanner.ReadString;
                  s:=CurrentScanner.FOrgPattern;
                end;
            end;
          end;
      end;

    procedure dir_legacyifend;
      begin
        do_localswitch(cs_legacyifend);
      end;

    procedure dir_note;
      begin
        do_message(scan_n_user_defined);
      end;

    procedure dir_notes;
      begin
        do_setverbose('N');
      end;

    procedure dir_objectpath;
      var
        path : string;
      begin
        if not CurrentModule.InGlobal then
         Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            path:=CurrentScanner.ReadComment;
            CurrentModule.LocalObjectSearchPath.AddPath(path,false);
            Message2(general_t_objectpath_local,CurrentModule.RealModuleName^,path);
          end;
      end;

    procedure dir_openstrings;
      begin
        do_delphiswitch('P');
      end;

    procedure dir_optimization;
      var
        hs : string;
      begin
        CurrentScanner.SkipSpace;
        { Support also the ON and OFF as switch }
        hs:=CurrentScanner.ReadID;
        if (hs='ON') then
          RecordPendingOptimizerSwitches(level2optimizerswitches)
        else if (hs='OFF') then
          RecordPendingOptimizerSwitches([])
        else if (hs='DEFAULT') then
          RecordPendingOptimizerSwitches(InitSettings.OptimizerSwitches)
        else
          begin
            if not UpdateOptimizerStr(hs,CurrentSettings.OptimizerSwitches) then
              Message1(scan_e_illegal_optimization_specifier,hs)
            else
              RecordPendingOptimizerSwitches(CurrentSettings.OptimizerSwitches)
          end;
      end;

    procedure dir_overflowchecks;
      begin
        do_delphiswitch('Q');
      end;

    procedure dir_packenum;
      var
        hs : string;
        v : LongInt;
      begin
        CurrentScanner.SkipSpace;
        if not(CurrentScanner.FChar in ['0'..'9']) then
         begin
           hs:=CurrentScanner.ReadID;
           if (hs='NORMAL') or (hs='DEFAULT') then
            RecordPendingPackEnum(4)
           else
            Message1(scan_e_illegal_pack_enum, hs);
         end
        else
         begin
           v:=CurrentScanner.ReadVal;
           case v of
            1,2,4 : RecordPendingPackEnum(v);
           else
            Message1(scan_e_illegal_pack_enum, CurrentScanner.FPattern);
           end;
         end;
      end;


    procedure dir_minfpconstprec;
      begin
        CurrentScanner.SkipSpace;
        if not SetMinFPConstPrec(CurrentScanner.ReadID,CurrentSettings.MinFPConstPrec) then
          Message1(scan_e_illegal_minfpconstprec, CurrentScanner.FPattern);
      end;


    procedure dir_packrecords;
      var
        hs : string;
        v : LongInt;
      begin
        CurrentScanner.SkipSpace;
        if not(CurrentScanner.FChar in ['0'..'9']) then
         begin
           hs:=CurrentScanner.ReadID;
           { C has the special recordalignmax of C_alignment }
           if (hs='C') then
            RecordPendingPackRecords(CAlignment)
           else
            if (hs='NORMAL') or (hs='DEFAULT') then
             RecordPendingPackRecords(Default_Settings.PackRecords)
           else
            Message1(scan_e_illegal_pack_records,hs);
         end
        else
         begin
           v:=CurrentScanner.ReadVal;
           case v of
             1,2,4,8,16,32 : RecordPendingPackRecords(v);
           else
            Message1(scan_e_illegal_pack_records,CurrentScanner.FPattern);
           end;
         end;
      end;


    procedure dir_packset;
      var
        hs : string;
        v : LongInt;
      begin
        CurrentScanner.SkipSpace;
        if not(CurrentScanner.FChar in ['1','2','4','8']) then
         begin
           hs:=CurrentScanner.ReadID;
           if (hs='FIXED') or (hs='DEFAULT') OR (hs='NORMAL') then
            RecordPendingSetAlloc(0) {Fixed mode, sets are 4 or 32 bytes}
           else
            Message(scan_e_only_packset);
         end
        else
         begin
           v:=CurrentScanner.ReadVal;
           case v of
            1,2,4,8 : RecordPendingSetAlloc(v);
           else
            Message(scan_e_only_packset);
           end;
         end;
      end;


    procedure dir_pic;
      begin
        { windows doesn't need/support pic }
        if tf_no_pic_supported in TargetInfo.flags then
          message(scan_w_pic_ignored)
        else
          do_moduleswitch(cs_create_pic);
      end;

    procedure dir_pop;

    begin
      if SwitchesStateStackPos < 1 then
        Message(scan_e_too_many_pop)
      else
        begin
          Dec(SwitchesStateStackPos);
          RecordPendingLocalFullSwitch(SwitchesStateStack[SwitchesStateStackPos].localsw);
          RecordPendingVerbosityFullSwitch(SwitchesStateStack[SwitchesStateStackPos].verbosity);
          RecordPendingAlignmentFullSwitch(SwitchesStateStack[SwitchesStateStackPos].Alignment);
          RecordPendingPackEnum(SwitchesStateStack[SwitchesStateStackPos].PackEnum);
          RecordPendingPackRecords(SwitchesStateStack[SwitchesStateStackPos].PackRecords);
          RecordPendingSetAlloc(SwitchesStateStack[SwitchesStateStackPos].SetAlloc);
          RecordPendingAsmMode(SwitchesStateStack[SwitchesStateStackPos].AsmMode);
          RecordPendingOptimizerSwitches(SwitchesStateStack[SwitchesStateStackPos].OptimizerSwitches);
          PendingState.NextMessageRecord:=SwitchesStateStack[SwitchesStateStackPos].PMessage;
          { flushpendingswitchesstate will reset the message state }
          CurrentSettings.PMessage:=nil;
          { Do not activate these changes yet, as otherwise
            you get a problem if you put a $pop just right after
            a addition for instance for which you explicitly turned the overflow check
            off by using $Q- after a $push PM 2012-08-29 }
          // flushpendingswitchesstate;
        end;
    end;

    procedure dir_pointermath;
      begin
        do_localswitch(cs_pointermath);
      end;

    procedure dir_push;

    begin
      if SwitchesStateStackPos > switchesstatestackmax then
        Message(scan_e_too_many_push);

      { do not flush here as we might have read directives which shall not be active yet,
        see e.g. tests/tbs/tw22744b.pas }
      if psf_alignment_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].Alignment:=PendingState.NextAlignment
      else
        SwitchesStateStack[SwitchesStateStackPos].Alignment:=CurrentSettings.Alignment;

      if psf_verbosity_full_switched in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].verbosity:=PendingState.NextVerbosityFullSwitch
      else
        SwitchesStateStack[SwitchesStateStackPos].verbosity:=status.verbosity;

      if psf_local_switches_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].localsw:=PendingState.NextLocalSwitches
      else
        SwitchesStateStack[SwitchesStateStackPos].localsw:=CurrentSettings.LocalSwitches;

      if psf_packenum_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].PackEnum:=PendingState.NextPackEnum
      else
        SwitchesStateStack[SwitchesStateStackPos].PackEnum:=CurrentSettings.PackEnum;

      if psf_packrecords_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].PackRecords:=PendingState.NextPackRecords
      else
        SwitchesStateStack[SwitchesStateStackPos].PackRecords:=CurrentSettings.PackRecords;

      if psf_setalloc_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].SetAlloc:=PendingState.NextSetAlloc
      else
        SwitchesStateStack[SwitchesStateStackPos].SetAlloc:=CurrentSettings.SetAlloc;

      if psf_asmmode_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].AsmMode:=PendingState.NextAsmMode
      else
        SwitchesStateStack[SwitchesStateStackPos].AsmMode:=CurrentSettings.AsmMode;

      if psf_optimizerswitches_changed in PendingState.flags then
        SwitchesStateStack[SwitchesStateStackPos].OptimizerSwitches:=PendingState.NextOptimizerSwitches
      else
        SwitchesStateStack[SwitchesStateStackPos].OptimizerSwitches:=CurrentSettings.OptimizerSwitches;

      SwitchesStateStack[SwitchesStateStackPos].PMessage:=PendingState.NextMessageRecord;
      Inc(SwitchesStateStackPos);
    end;

    procedure dir_rangechecks;
      begin
        do_delphiswitch('R');
      end;

    procedure dir_referenceinfo;
      begin
        do_delphiswitch('Y');
      end;

    procedure dir_resource;
      var
        s : string;
        Origin : TPathStr;
        OriginLine : LongInt;
      begin
        Origin:=CurrentScanner.FInputFile.Path+CurrentScanner.FInputFile.Name;
        OriginLine:=CurrentScanner.FLineNumber;
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar = '''' then
          begin
            s:= CurrentScanner.ReadQuotedString;
            CurrentScanner.ReadComment
          end
        else
          s:= TrimSpace(CurrentScanner.ReadComment);

        { replace * with the name of the main source.
          This should always be defined. }
        if (s<>'') and (s[1]='*') then
          if Assigned(CurrentModule) then
            begin
              delete(S,1,1);
              insert(ChangeFileExt(ExtractFileName(CurrentModule.MainSource),''),S,1 );
            end;
        s:=FixFileName(s);
        if ExtractFileExt(s)='' then
          s:=ChangeFileExt(s,TargetInfo.resext);
        if TargetInfo.res<>res_none then
          begin
            include(CurrentModule.ModuleFlags,mf_has_resourcefiles);
            AddResourceInput(FixFileName(s),Origin,OriginLine);
          end
        else
          Message(scan_e_resourcefiles_not_supported);
      end;

    procedure dir_rtti;

      function read_rtti_options: TRTTIVisibilities;
        var
          sym: TTypeSym;
          value: TNormalSet;
        begin
          result:=[];
          sym:=Search_System_Type('TVISIBILITYCLASSES');
          if CurrentScanner.ReadPreProcSet(TSetDef(sym.TypeDef),value,'RTTI') then
            begin
              result:=PRTTIVisibilities(@value)^;
              // if the set was empty we need to read the next id
              if result=[] then
                begin
                  CurrentScanner.SkipSpace;
                  CurrentScanner.ReadID
                end;
            end;
        end;

      var
        dir: TRTTIDirective;
        option: TRTTIOption;
        options: array[TRTTIOption] of boolean;
      begin
        { the system unit has not yet loaded which means the directive is misplaced}
        if SystemUnit=nil then
          begin
            Message(scan_e_misplaced_rtti_directive);
            exit;
          end;

        dir:=default(TRTTIDirective);

        options[ro_fields]:=false;
        options[ro_methods]:=false;
        options[ro_properties]:=false;

        { read the clause }
        CurrentScanner.SkipSpace;
        CurrentScanner.ReadID;
        case CurrentScanner.FPattern of
          'INHERIT':
            dir.clause:=rtc_inherit;
          'EXPLICIT':
            dir.clause:=rtc_explicit;
          otherwise
            Message(scan_e_invalid_rtti_clause);
        end;

        { read the visibility options}
        CurrentScanner.SkipSpace;
        CurrentScanner.ReadID;
        { the inherit clause doesn't require any options but explicit does }
        if (CurrentScanner.FPattern='') and (dir.clause=rtc_explicit) then
          Message(scan_e_incomplete_rtti_clause);
        while CurrentScanner.FPattern<>'' do
          begin
            case CurrentScanner.FPattern of
              'METHODS':
                option:=ro_methods;
              'PROPERTIES':
                option:=ro_properties;
              'FIELDS':
                option:=ro_fields;
              otherwise
                begin
                  if CurrentScanner.FPreProcToken=_ID then
                    Message1(scan_e_invalid_rtti_option,CurrentScanner.FPattern);
                  break;
                end;
            end;
            { the option has already been used }
            if options[option] then
              begin
                Message1(scan_e_duplicate_rtti_option,CurrentScanner.FPattern);
                break;
              end;
            dir.options[option]:=read_rtti_options;
            options[option]:=true;
          end;

        { set the directive in the module }
        CurrentModule.RTTIDirective:=dir;
      end;

    procedure dir_safefpuexceptions;
      begin
        do_localswitch(cs_fpu_fwait);
      end;

    procedure dir_scopedenums;
      begin
        do_localswitch(cs_scopedenums);
      end;

    function get_peflag_const(const ident:string;error:LongInt):LongInt;
      var
        srsym : TSym;
        srsymtable : TSymTable;
      begin
        result:=0;
        if SearchSym(ident,srsym,srsymtable) then
          if (srsym.typ=constsym) and
              (TConstSym(srsym).ConstTyp=constord) and
              Is_Integer(TConstSym(srsym).ConstDef) then
            with TConstSym(srsym).Value.ValueOrd do
              if signed then
                result:=TConstSym(srsym).Value.ValueOrd.svalue
              else
                result:=TConstSym(srsym).Value.ValueOrd.uvalue
          else
            message(error)
        else
          message1(sym_e_id_not_found,ident);
      end;

    procedure dir_setpeflags;
      var
        flags : int64;
      begin
        if not (TargetInfo.system in (systems_all_windows)) then
          Message(scan_w_setpeflags_not_support);
        if CurrentScanner.ReadPreProcInt(flags,'SETPEFLAGS') then
          begin
            if flags>$ffff then
              message(scan_e_illegal_peflag);
            PEFlags:=PEFlags or uint16(flags);
          end;
        SetPEFlagsSetExplicity:=true;
      end;

    procedure dir_setpeoptflags;
      var
        flags : int64;
      begin
        if not (TargetInfo.system in (systems_all_windows)) then
          Message(scan_w_setpeoptflags_not_support);
        if CurrentScanner.ReadPreProcInt(flags,'SETPEOPTFLAGS') then
          begin
            if flags>$ffff then
              message(scan_e_illegal_peoptflag);
            PEOptFlags:=PEOptFlags or uint16(flags);
          end;
        SetPEOptFlagsSetExplicity:=true;
      end;

    procedure dir_setpeuserversion;
      var
        dummystr : string;
        dummyrev : word;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          Message(scan_w_setpeuserversion_not_support);
        if (not CurrentModule.IsInitial) then
          Message(scan_n_only_exe_version)
        else
          do_version(PEUserVersionMajor,PEUserVersionMinor,dummyrev,dummystr,false,SetPEUserVersionSetExplicitely);
      end;

    procedure dir_setpeosversion;
      var
        dummystr : string;
        dummyrev : word;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          Message(scan_w_setpeosversion_not_support);
        if (not CurrentModule.IsInitial) then
          Message(scan_n_only_exe_version)
        else
          do_version(PEOSVersionMajor,PEOSVersionMinor,dummyrev,dummystr,false,SetPEOSVersionSetExplicitely);
      end;

    procedure dir_setpesubsysversion;
      var
        dummystr : string;
        dummyrev : word;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          Message(scan_w_setpesubsysversion_not_support);
        if (not CurrentModule.IsInitial) then
          Message(scan_n_only_exe_version)
        else
          do_version(PESubSysVersionMajor,PESubSysVersionMinor,dummyrev,dummystr,false,SetPESubSysVersionSetExplicitely);
      end;

    procedure dir_smartlink;
      begin
        do_moduleswitch(cs_create_smart);
        if (TargetDbg.id=dbg_dwarf3) and
            not(TargetInfo.system in systems_darwin) and
            { smart linking does not yet work with DWARF debug info on most targets }
            (cs_create_smart in CurrentSettings.ModuleSwitches) and
            not (af_outputbinary in TargetAsm.flags) then
        begin
          Message(option_dwarf_smart_linking);
          Exclude(CurrentSettings.ModuleSwitches,cs_create_smart);
        end;
      end;

    procedure dir_stackframes;
      begin
        do_delphiswitch('W');
      end;

    procedure dir_stop;
      begin
        do_message(scan_f_user_defined);
      end;

    procedure dir_stringchecks;
      begin
        // Delphi adds checks that ansistring and unicodestring are correct in
        // different places. Skip it for now.
      end;

    procedure dir_targetswitch;
      var
        name, value: string;
      begin
        { note: *not* recorded in the tokenstream, so not replayed for generics }
        CurrentScanner.SkipSpace;
        name:=CurrentScanner.ReadID;
        if CurrentScanner.FChar='=' then
          begin
            CurrentScanner.ReadChar;
            CurrentScanner.ReadID;
            value:=CurrentScanner.FOrgPattern;
            if not UpdateTargetSwitchStr(name+'='+value,CurrentSettings.TargetSwitches,CurrentModule.InGlobal) then
              Message1(scan_w_illegal_switch,name);
          end
        else if CurrentScanner.FChar='-' then
          begin
            CurrentScanner.ReadChar;
            if not UpdateTargetSwitchStr(name+'-',CurrentSettings.TargetSwitches,CurrentModule.InGlobal) then
              Message1(scan_w_illegal_switch,name);
          end
        else
          if not UpdateTargetSwitchStr(name,CurrentSettings.TargetSwitches,CurrentModule.InGlobal) then
            Message1(scan_w_illegal_switch,name);
      end;

    procedure dir_typedaddress;
      begin
        do_delphiswitch('T');
      end;

    procedure dir_typeinfo;
      begin
        do_delphiswitch('M');
      end;

    procedure dir_unitpath;
      var
        unitpath: TPathStr;
      begin
        if not CurrentModule.InGlobal then
         Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            unitpath:=CurrentScanner.ReadComment;
            if (CurrentModule.path<>'') and
               not Path_Absolute(unitpath) then
             unitpath:=CurrentModule.path+SourceInfo.DirSep+unitpath;
            CurrentModule.LocalUnitSearchPath.AddPath(unitpath,false);
            Message2(general_t_unitpath_local,CurrentModule.RealModuleName^,unitpath);
          end;
      end;

    procedure dir_varparacopyoutcheck;
      begin
        Message1(scan_w_illegal_switch,CurrentScanner.FPattern);
      end;

    procedure dir_varpropsetter;
      begin
        do_localswitch(cs_varpropsetter);
      end;

    procedure dir_varstringchecks;
      begin
        do_delphiswitch('V');
      end;

    procedure dir_version;
      var
        major, minor : LongInt;
        error : integer;
      begin
        if not (TargetInfo.system in systems_all_windows) then
          begin
            Message(scan_n_version_not_support);
            exit;
          end;
        if (not CurrentModule.IsInitial) then
          Message(scan_n_only_exe_version)
        else
          begin
            { change description global var in all cases }
            { it not used but in win32 and os2 }
            CurrentScanner.SkipSpace;
            { we should only accept Major.Minor format for win32 and os2 }
            CurrentScanner.ReadNumber;
            major:=0;
            minor:=0;
            val(CurrentScanner.FPattern,major,error);
            if (error<>0) or (major > high(word)) or (major < 0) then
              begin
                Message1(scan_w_wrong_version_ignored,CurrentScanner.FPattern);
                exit;
              end;
            if CurrentScanner.FChar='.' then
              begin
                CurrentScanner.ReadChar;
                CurrentScanner.ReadNumber;
                val(CurrentScanner.FPattern,minor,error);
                if (error<>0) or (minor > high(word)) or (minor < 0) then
                  begin
                    Message1(scan_w_wrong_version_ignored,ToStr(major)+'.'+CurrentScanner.FPattern);
                    exit;
                  end;
                DLLMajor:=word(major);
                DLLMinor:=word(minor);
                DLLVersion:=ToStr(major)+'.'+ToStr(minor);
              end
            else
              DLLVersion:=ToStr(major);
          end;
      end;

    procedure dir_wait;
      var
        had_info : boolean;
      begin
        had_info:=(status.verbosity and VInfo)<>0;
        { this message should always appear !! }
        status.verbosity:=status.verbosity or VInfo;
        Message(scan_i_press_enter);
        readln;
        If not(had_info) then
          status.verbosity:=status.verbosity and (not VInfo);
      end;

    { delphi compatible warn directive:
      $warn <identifier> on
      $warn <identifier> off
      $warn <identifier> error
    }
    procedure dir_warn;
      var
        ident : string;
        state : string;
        msgstate : TMsgState;
        i : integer;
      begin
        CurrentScanner.SkipSpace;
        ident:=CurrentScanner.ReadID;
        CurrentScanner.SkipSpace;
        if CurrentScanner.FChar in ['+','-'] then
          begin
            state:=CurrentScanner.FChar;
            CurrentScanner.ReadChar;
          end
        else
          state:=CurrentScanner.ReadID;

        { support both delphi and fpc switches }
        { use local ms_on/off/error tmsgstate values }
        if (state='ON') or (state='+') then
          msgstate:=ms_on
        else
        if (state='OFF') or (state='-') then
          msgstate:=ms_off
        else
        if (state='ERROR') then
          msgstate:=ms_error
        else
        begin
          Message1(scanner_e_illegal_warn_state,state);
          exit;
        end;

        if ident='CONSTRUCTING_ABSTRACT' then
          begin
            RecordPendingMessageState(type_w_instance_with_abstract, msgstate);
            RecordPendingMessageState(type_w_instance_abstract_class, msgstate);
          end
        else
        if ident='IMPLICIT_VARIANTS' then
          RecordPendingMessageState(parser_w_implicit_uses_of_variants_unit, msgstate)
        else
        if ident='NO_RETVAL' then
          RecordPendingMessageState(sym_w_function_result_not_set, msgstate)
        else
        if ident='SYMBOL_DEPRECATED' then
          begin
            RecordPendingMessageState(sym_w_deprecated_symbol, msgstate);
            RecordPendingMessageState(sym_w_deprecated_symbol_with_msg, msgstate);
          end
        else
        if ident='SYMBOL_EXPERIMENTAL' then
          RecordPendingMessageState(sym_w_experimental_symbol, msgstate)
        else
        if ident='SYMBOL_LIBRARY' then
          RecordPendingMessageState(sym_w_library_symbol, msgstate)
        else
        if ident='SYMBOL_PLATFORM' then
          RecordPendingMessageState(sym_w_non_portable_symbol, msgstate)
        else
        if ident='SYMBOL_UNIMPLEMENTED' then
          RecordPendingMessageState(sym_w_non_implemented_symbol, msgstate)
        else
        if ident='UNIT_DEPRECATED' then
          begin
            RecordPendingMessageState(sym_w_deprecated_unit, msgstate);
            RecordPendingMessageState(sym_w_deprecated_unit_with_msg, msgstate);
          end
        else
        if ident='UNIT_EXPERIMENTAL' then
          RecordPendingMessageState(sym_w_experimental_unit, msgstate)
        else
        if ident='UNIT_LIBRARY' then
          RecordPendingMessageState(sym_w_library_unit, msgstate)
        else
        if ident='UNIT_PLATFORM' then
          RecordPendingMessageState(sym_w_non_portable_unit, msgstate)
        else
        if ident='UNIT_UNIMPLEMENTED' then
          RecordPendingMessageState(sym_w_non_implemented_unit, msgstate)
        else
        if ident='ZERO_NIL_COMPAT' then
          RecordPendingMessageState(type_w_zero_to_nil, msgstate)
        else
        if ident='IMPLICIT_STRING_CAST' then
          RecordPendingMessageState(type_w_implicit_string_cast, msgstate)
        else
        if ident='IMPLICIT_STRING_CAST_LOSS' then
          RecordPendingMessageState(type_w_implicit_string_cast_loss, msgstate)
        else
        if ident='EXPLICIT_STRING_CAST' then
          RecordPendingMessageState(type_w_explicit_string_cast, msgstate)
        else
        if ident='EXPLICIT_STRING_CAST_LOSS' then
          RecordPendingMessageState(type_w_explicit_string_cast_loss, msgstate)
        else
        if ident='CVT_NARROWING_STRING_LOST' then
          RecordPendingMessageState(type_w_unicode_data_loss, msgstate)
        else
        if ident='INTF_RAISE_VISIBILITY' then
          RecordPendingMessageState(type_w_interface_lower_visibility, msgstate)
        else
          begin
            i:=0;
            if not ChangeMessageVerbosity(ident,i,msgstate) then
              Message1(scanner_w_illegal_warn_identifier,ident);
          end;
      end;

    procedure dir_warning;
      begin
        do_message(scan_w_user_defined);
      end;

    procedure dir_warnings;
      begin
        do_setverbose('W');
      end;

    procedure dir_weakpackageunit;
      begin
        { old Delphi versions seem to use merely $WEAKPACKAGEUNIT while newer
          Delphis have $WEAPACKAGEUNIT ON... :/ }
        do_moduleflagswitch(mf_package_weak, true);
      end;

    procedure dir_writeableconst;
      begin
        do_delphiswitch('J');
      end;

    procedure dir_yd;
      begin
        HandleSwitch('Y','+');
      end;

    procedure dir_z1;
      begin
        CurrentSettings.PackEnum:=1;
      end;

    procedure dir_z2;
      begin
        CurrentSettings.PackEnum:=2;
      end;

    procedure dir_z4;
      begin
        CurrentSettings.PackEnum:=4;
      end;

    procedure dir_externalsym;
      begin
      end;

    procedure dir_nodefine;
      begin
      end;

    procedure dir_hppemit;
      begin
      end;

    procedure dir_hugecode;
      begin
        Message1(scan_n_ignored_switch,CurrentScanner.FPattern);
      end;

    procedure dir_hugepointernormalization;
      begin
        Message1(scanner_w_directive_ignored_on_target, 'HUGEPOINTERNORMALIZATION');
      end;

    procedure dir_hugepointerarithmeticnormalization;
      begin
        Message1(scanner_w_directive_ignored_on_target, 'HUGEPOINTERARITHMETICNORMALIZATION');
      end;

    procedure dir_hugepointercomparisonnormalization;
      begin
        Message1(scanner_w_directive_ignored_on_target, 'HUGEPOINTERCOMPARISONNORMALIZATION');
      end;

    procedure dir_codealign;
      var
        s : string;
      begin
        CurrentScanner.SkipSpace;
        s:=CurrentScanner.ReadComment;
        if not(UpdateAlignmentStr(s,CurrentSettings.Alignment)) then
          message(scanner_e_illegal_alignment_directive);
      end;

    procedure dir_codepage;
      var
         s : string;
      begin
        if not CurrentModule.InGlobal then
          Message(scan_w_switch_is_global)
        else
          begin
            CurrentScanner.SkipSpace;
            s:=CurrentScanner.ReadComment;
            if (upper(s)='UTF8') or (upper(s)='UTF-8') then
              CurrentSettings.SourceCodePage:=CP_UTF8
            else if not CPAvailable(s) then
              Message1(option_code_page_not_available,s)
            else
              CurrentSettings.SourceCodePage:=CodePageByName(s);
            { we're not using the system code page now }
            exclude(CurrentSettings.ModeSwitches,m_systemcodepage);
            exclude(CurrentSettings.ModuleSwitches,cs_system_codepage);
            include(CurrentSettings.ModuleSwitches,cs_explicit_codepage);
          end;
      end;

    procedure dir_coperators;
      begin
        do_moduleswitch(cs_support_c_operators);
      end;


    procedure dir_bitpacking;
      begin
        do_localswitch(cs_bitpacking);
      end;

    procedure dir_region;
      begin
      end;

    procedure dir_endregion;
      begin
      end;

    procedure dir_zerobasesstrings;
      begin
        do_localswitch(cs_zerobasedstrings);
      end;


{****************************************************************************
                         Initialize Directives
****************************************************************************}

    procedure InitScannerDirectives;
      begin
        AddDirective('A1',directiveAll, @dir_a1);
        AddDirective('A2',directiveAll, @dir_a2);
        AddDirective('A4',directiveAll, @dir_a4);
        AddDirective('A8',directiveAll, @dir_a8);
        AddDirective('ALIGN',directiveAll, @dir_align);
        AddDirective('APPTYPE',directiveAll, @dir_apptype);
        AddDirective('ASMCPU',directiveAll, @dir_asmcpu);
        AddDirective('ASMMODE',directiveAll, @dir_asmmode);
        AddDirective('ASSERTIONS',directiveAll, @dir_assertions);
        AddDirective('BOOLEVAL',directiveAll, @dir_booleval);
        AddDirective('BITPACKING',directiveAll, @dir_bitpacking);
        AddDirective('CALLING',directiveAll, @dir_calling);
        AddDirective('CHECKCASECOVERAGE',directiveAll, @dir_checkcasecoverage);
        AddDirective('CHECKFPUEXCEPTIONS',directiveAll, @dir_checkfpuexceptions);
        AddDirective('CHECKPOINTER',directiveAll, @dir_checkpointer);
        AddDirective('CODEALIGN',directiveAll, @dir_codealign);
        AddDirective('CODEPAGE',directiveAll, @dir_codepage);
        AddDirective('COPERATORS',directiveAll, @dir_coperators);
        AddDirective('D',directiveAll, @dir_description);
        AddDirective('DEBUGINFO',directiveAll, @dir_debuginfo);
        AddDirective('DEFINITIONINFO',directiveAll, @dir_definitioninfo);
        AddDirective('DENYPACKAGEUNIT',directiveAll,@dir_denypackageunit);
        AddDirective('DESCRIPTION',directiveAll, @dir_description);
        AddDirective('ENDREGION',directiveAll, @dir_endregion);
        AddDirective('ERROR',directiveAll, @dir_error);
        AddDirective('ERRORC',directiveMac, @dir_error);
        AddDirective('EXCESSPRECISION',directiveAll, @dir_excessprecision);
        AddDirective('EXTENDEDSYNTAX',directiveAll, @dir_extendedsyntax);
        AddDirective('EXTERNALSYM',directiveAll, @dir_externalsym);
        AddDirective('FATAL',directiveAll, @dir_fatal);
        AddDirective('FPUTYPE',directiveAll, @dir_fputype);
        AddDirective('FRAMEWORKPATH',directiveAll, @dir_frameworkpath);
        AddDirective('GOTO',directiveAll, @dir_goto);
        AddDirective('HINT',directiveAll, @dir_hint);
        AddDirective('HINTS',directiveAll, @dir_hints);
        AddDirective('HPPEMIT',directiveAll, @dir_hppemit);
        AddDirective('HUGECODE',directiveAll, @dir_hugecode);
        AddDirective('HUGEPOINTERNORMALIZATION',directiveAll,@dir_hugepointernormalization);
        AddDirective('HUGEPOINTERARITHMETICNORMALIZATION',directiveAll,@dir_hugepointerarithmeticnormalization);
        AddDirective('HUGEPOINTERCOMPARISONNORMALIZATION',directiveAll,@dir_hugepointercomparisonnormalization);
        AddDirective('IEEEERRORS',directiveAll,@dir_ieeeerrors);
        AddDirective('IOCHECKS',directiveAll, @dir_iochecks);
        AddDirective('IMAGEBASE',directiveAll, @dir_imagebase);
        AddDirective('IMPLICITEXCEPTIONS',directiveAll, @dir_implicitexceptions);
        AddDirective('IMPORTEDDATA',directiveAll, @dir_importeddata);
        AddDirective('INCLUDEPATH',directiveAll, @dir_includepath);
        AddDirective('INFO',directiveAll, @dir_info);
        AddDirective('INLINE',directiveAll, @dir_inline);
        AddDirective('INTERFACES',directiveAll, @dir_interfaces);
        AddDirective('L',directiveAll, @dir_link);
        AddDirective('LEGACYIFEND',directiveAll, @dir_legacyifend);
        AddDirective('LIBEXPORT',directiveMac, @dir_libexport);
        AddDirective('LIBRARYPATH',directiveAll, @dir_librarypath);
        AddDirective('LINK',directiveAll, @dir_link);
        AddDirective('LINKFRAMEWORK',directiveAll, @dir_linkframework);
        AddDirective('LINKLIB',directiveAll, @dir_linklib);
        AddDirective('LOCALSYMBOLS',directiveAll, @dir_localsymbols);
        AddDirective('LONGSTRINGS',directiveAll, @dir_longstrings);
        AddDirective('M',directiveAll, @dir_memory);
        AddDirective('MACRO',directiveAll, @dir_macro);
        AddDirective('MAXFPUREGISTERS',directiveAll, @dir_maxfpuregisters);
        AddDirective('MAXSTACKSIZE',directiveAll, @dir_maxstacksize);
        AddDirective('MEMORY',directiveAll, @dir_memory);
        AddDirective('MESSAGE',directiveAll, @dir_message);
        AddDirective('MINENUMSIZE',directiveAll, @dir_packenum);
        AddDirective('MINFPCONSTPREC',directiveAll, @dir_minfpconstprec);
        AddDirective('MINSTACKSIZE',directiveAll, @dir_minstacksize);
        AddDirective('MODE',directiveAll, @dir_mode);
        AddDirective('MODESWITCH',directiveAll, @dir_modeswitch);
        AddDirective('TEXTBLOCK',directiveAll, @dir_textblock);
        AddDirective('MULTILINESTRINGLINEENDING',directiveAll, @dir_multilinestringlineending);
        AddDirective('MULTILINESTRINGTRIMLEFT',directiveAll, @dir_multilinestringtrimleft);
        AddDirective('NAMESPACES',directiveAll, @dir_namespaces);
        AddDirective('NODEFINE',directiveAll, @dir_nodefine);
        AddDirective('NOTE',directiveAll, @dir_note);
        AddDirective('NOTES',directiveAll, @dir_notes);
        AddDirective('OBJECTCHECKS',directiveAll, @dir_objectchecks);
        AddDirective('OBJECTPATH',directiveAll, @dir_objectpath);
        AddDirective('OPENSTRINGS',directiveAll, @dir_openstrings);
        AddDirective('OPTIMIZATION',directiveAll, @dir_optimization);
        AddDirective('OV',directiveMac, @dir_overflowchecks);
        AddDirective('OVERFLOWCHECKS',directiveAll, @dir_overflowchecks);
        AddDirective('PACKENUM',directiveAll, @dir_packenum);
        AddDirective('PACKRECORDS',directiveAll, @dir_packrecords);
        AddDirective('PACKSET',directiveAll, @dir_packset);
        AddDirective('PASCALMAINNAME',directiveAll, @dir_pascalmainname);
        AddDirective('PIC',directiveAll, @dir_pic);
        AddDirective('POINTERMATH',directiveAll, @dir_pointermath);
        AddDirective('POP',directiveAll, @dir_pop);
        AddDirective('POPOPT',directiveAll, @dir_pop);
        AddDirective('PUSH',directiveAll, @dir_push);
        AddDirective('PUSHOPT',directiveAll, @dir_push);
        AddDirective('R',directiveAll, @dir_resource);
        AddDirective('RTTI',directiveAll, @dir_rtti);
        AddDirective('RANGECHECKS',directiveAll, @dir_rangechecks);
        AddDirective('REFERENCEINFO',directiveAll, @dir_referenceinfo);
        AddDirective('REGION',directiveAll, @dir_region);
        AddDirective('RESOURCE',directiveAll, @dir_resource);
        AddDirective('SAFEFPUEXCEPTIONS',directiveAll, @dir_safefpuexceptions);
        AddDirective('SCOPEDENUMS',directiveAll, @dir_scopedenums);
        AddDirective('SETPEFLAGS', directiveAll, @dir_setpeflags);
        AddDirective('SETPEOPTFLAGS', directiveAll, @dir_setpeoptflags);
        AddDirective('SETPEOSVERSION', directiveAll, @dir_setpeosversion);
        AddDirective('SETPEUSERVERSION', directiveAll, @dir_setpeuserversion);
        AddDirective('SETPESUBSYSVERSION', directiveAll, @dir_setpesubsysversion);
        AddDirective('SMARTLINK',directiveAll, @dir_smartlink);
        AddDirective('STACKCHECKING',directiveAll,@dir_stackchecking);
        AddDirective('STACKFRAMES',directiveAll, @dir_stackframes);
        AddDirective('STOP',directiveAll, @dir_stop);
        AddDirective('STRINGCHECKS', directiveAll, @dir_stringchecks);
        AddDirective('TARGETSWITCH',directiveAll, @dir_targetswitch);
        AddDirective('TYPEDADDRESS',directiveAll, @dir_typedaddress);
        AddDirective('TYPEINFO',directiveAll, @dir_typeinfo);
        AddDirective('UNITPATH',directiveAll, @dir_unitpath);
        AddDirective('VARPARACOPYOUTCHECK',directiveAll, @dir_varparacopyoutcheck);
        AddDirective('VARPROPSETTER',directiveAll, @dir_varpropsetter);
        AddDirective('VARSTRINGCHECKS',directiveAll, @dir_varstringchecks);
        AddDirective('VERSION',directiveAll, @dir_version);
        AddDirective('WAIT',directiveAll, @dir_wait);
        AddDirective('WARN',directiveAll, @dir_warn);
        AddDirective('WARNING',directiveAll, @dir_warning);
        AddDirective('WARNINGS',directiveAll, @dir_warnings);
        AddDirective('WEAKPACKAGEUNIT',directiveAll, @dir_weakpackageunit);
        AddDirective('WRITEABLECONST',directiveAll, @dir_writeableconst);
        AdDDirective('YD',directiveAll, @dir_yd);
        AddDirective('Z1',directiveAll, @dir_z1);
        AddDirective('Z2',directiveAll, @dir_z2);
        AddDirective('Z4',directiveAll, @dir_z4);
        AddDirective('ZEROBASEDSTRINGS',directiveAll, @dir_zerobasesstrings);
      end;

end.
