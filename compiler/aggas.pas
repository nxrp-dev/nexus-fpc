  {                  f
    Copyright (c) 1998-2006 by the Free Pascal team

    This unit implements the generic part of the GNU assembler
    (v2.8 or later) writer

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
{ Base unit for writing GNU assembler output.
}
unit aggas;

{$i fpcdefs.inc}


interface

    uses
      GlobType,Globals,
      cpubase,aasmbase,aasmtai,AAsmData,aasmcfi,
      assemble;

    type
      TCPUInstrWriter = class;

      TGNUWin64ComdatInfo=class
        SectionName,
        Key : string;
        Associative,
        KeyDefined : boolean;
        Next : TGNUWin64ComdatInfo;
      end;

      {# This is a derived class which is used to write
         GAS styled assembler.
      }

      { TGNUAssembler }

      TGNUAssembler=class(TExternalAssembler)
      protected
        FWin64ComdatSections : TGNUWin64ComdatInfo;
        FWin64ComdatKeyToDefine : string;
        FWin64ComdatKeyIndex : LongInt;
        function UseWindowsComdat:boolean;
        function FindWin64ComdatInfo(const ASectionName:string):TGNUWin64ComdatInfo;
        function EnsureWin64ComdatLeader(const ASectionName:string):TGNUWin64ComdatInfo;
        procedure RegisterWin64AssociativeComdat(const ASectionName,LeaderKey:string);
        function IsWin64SmartSection(atype:TAsmSectiontype;const aname:string):boolean;
        function sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;virtual;
        function sectionattrs(atype:TAsmSectiontype):string;virtual;
        function sectionattrs_coff(atype:TAsmSectiontype):string;virtual;
        function sectionalignment_aix(atype:TAsmSectiontype;secalign: LongInt):string;
        function sectionflags(secflags:TSectionFlags):string;virtual;
        procedure WriteSectionComdat(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder);virtual;
        procedure WriteSection(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder;secalign:LongInt;
          secflags:TSectionFlags=[];secprogbits:TSectionProgbits=SPB_None);virtual;
        procedure WriteExtraHeader;virtual;
        procedure WriteExtraFooter;virtual;
        procedure WriteInstruction(hp: TAI);
        procedure WriteWeakSymbolRef(s: TAsmSymbol); virtual;
        procedure WriteHiddenSymbol(sym: TAsmSymbol);
        procedure WriteUnalignedIntConst(hp: TAIConst);
        procedure WriteDirectiveName(dir: TAsmDirective); virtual;
       public
        function MakeCmdLine: TCmdStr; override;
        procedure WriteTree(p:TAsmList);override;
        procedure WriteAsmList;override;
        destructor Destroy; override;
       private
        setcount: LongInt;
        procedure WriteCFI(hp: TAICFIBase);
        function NextSetLabel: string;
       protected
        InstrWriter: TCPUInstrWriter;
      end;


      {# This is the base class for writing instructions.

         The WriteInstruction() method must be overridden
         to write a single instruction to the assembler
         file.
      }
      TCPUInstrWriter = class
        constructor Create(_owner: TGNUAssembler);
        procedure WriteInstruction(hp : TAI); virtual; abstract;
       protected
        owner: TGNUAssembler;
      end;


      { TAppleGNUAssembler }

      TAppleGNUAssembler=class(TGNUAssembler)
       protected
        function sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
        procedure WriteWeakSymbolRef(s: TAsmSymbol); override;
        procedure WriteDirectiveName(dir: TAsmDirective); override;
       end;


      TAoutGNUAssembler=class(TGNUAssembler)
        function sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
       end;


implementation

    uses
      SysUtils,
      CUtils,CFileUtl,Systems,
      FModule,Verbose,
{$ifndef DISABLE_WIN64_SEH}
      itcpugas,
{$endif DISABLE_WIN64_SEH}
      objcasm;

    const
      line_length = 70;

    var
      symendcount  : LongInt;

{****************************************************************************}
{                          Support routines                                  }
{****************************************************************************}

    const
      ait_const2str : array[aitconst_128bit..aitconst_64bit_unaligned] of string[20]=(
        #9'.fixme128'#9,#9'.quad'#9,#9'.long'#9,#9'.short'#9,#9'.byte'#9,
        #9'.sleb128'#9,#9'.uleb128'#9,
        #9'.rva'#9,#9'.secrel32'#9,#9'.quad'#9,#9'.long'#9,#9'.short'#9,#9'.short'#9,
        #9'.short'#9,#9'.long'#9,#9'.quad'#9
      );




{****************************************************************************}
{                          GNU Assembler writer                              }
{****************************************************************************}

    function TGNUAssembler.UseWindowsComdat:boolean;
      begin
        result:=(TargetInfo.system in [system_i386_win32,system_x86_64_win64,system_aarch64_win64]) and
          (asminfo^.id=as_clang_gas) and
          (af_llvm in asminfo^.flags);
      end;


    function TGNUAssembler.FindWin64ComdatInfo(const ASectionName:string):TGNUWin64ComdatInfo;
      begin
        result:=FWin64ComdatSections;
        while Assigned(result) and (result.SectionName<>ASectionName) do
          result:=result.Next;
      end;


    function TGNUAssembler.EnsureWin64ComdatLeader(const ASectionName:string):TGNUWin64ComdatInfo;
      begin
        result:=FindWin64ComdatInfo(ASectionName);
        if Assigned(result) then
          begin
            if result.Associative then
              InternalError(2026092203);
            exit;
          end;
        result:=TGNUWin64ComdatInfo.Create;
        result.SectionName:=ASectionName;
        inc(FWin64ComdatKeyIndex);
        result.Key:='$fpc$comdat$'+lower(CurrentModule.ModuleName^)+'$'+ToStr(FWin64ComdatKeyIndex);
        result.Next:=FWin64ComdatSections;
        FWin64ComdatSections:=result;
      end;


    procedure TGNUAssembler.RegisterWin64AssociativeComdat(const ASectionName,LeaderKey:string);
      var
        info : TGNUWin64ComdatInfo;
      begin
        info:=FindWin64ComdatInfo(ASectionName);
        if Assigned(info) then
          begin
            if not info.Associative or (info.Key<>LeaderKey) then
              InternalError(2026092204);
            exit;
          end;
        info:=TGNUWin64ComdatInfo.Create;
        info.SectionName:=ASectionName;
        info.Key:=LeaderKey;
        info.Associative:=true;
        info.KeyDefined:=true;
        info.Next:=FWin64ComdatSections;
        FWin64ComdatSections:=info;
      end;


    function TGNUAssembler.IsWin64SmartSection(atype:TAsmSectiontype;const aname:string):boolean;
      begin
        result:=UseWindowsComdat and
          create_smartlink_sections and
          (aname<>'') and
          not (atype in [sec_bss,sec_toc,sec_user,sec_note,sec_fpc,sec_pdata]) and
          not (atype in [sec_debug_frame..sec_debug_loclists]);
      end;


    destructor TGNUAssembler.Destroy;
      var
        info : TGNUWin64ComdatInfo;
      begin
        while Assigned(FWin64ComdatSections) do
          begin
            info:=FWin64ComdatSections;
            FWin64ComdatSections:=info.Next;
            info.Free;
          end;
        InstrWriter.free;
        InstrWriter := nil;
        inherited Destroy;
      end;


    function TGNUAssembler.MakeCmdLine: TCmdStr;
      begin
        result := inherited MakeCmdLine;
        // MWE: disabled again. It generates dwarf info for the generated .s
        //      files as well. This conflicts with the info we generate
        // if target_dbg.id = dbg_dwarf then
        //  result := result + ' --gdwarf-2';
      end;


    function TGNUAssembler.NextSetLabel: string;
      begin
        inc(setcount);
        result := asminfo^.labelprefix+'$set$'+ToStr(setcount);
      end;

    function is_smart_section(atype:TAsmSectiontype):boolean;
      begin
        { For bss we need to set some flags that are target dependent,
          it is easier to disable it for smartlinking. It doesn't take up
          filespace }
        result:=not(TargetInfo.system in systems_darwin) and
           create_smartlink_sections and
           (atype<>sec_toc) and
           (atype<>sec_user) and
           (atype<>sec_note) and
           (atype<>sec_bss);
      end;

    function TGNUAssembler.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      const
        secnames : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text',
          '.data',
{ why doesn't .rodata work? (FK) }
{ sometimes we have to create a data.rel.ro instead of .rodata, e.g. for  }
{ vtables (and anything else containing relocations), otherwise those are }
{ not relocated properly on e.g. linux/ppc64. g++ generates there for a   }
{ vtable for a class called Window:                                       }
{ .section .data.rel.ro._ZTV6Window,"awG",@progbits,_ZTV6Window,comdat    }
{ TODO: .data.ro not yet working}
{$if defined(support_rodata)}
          '.rodata',
{$else defined(support_rodata)}
          '.data',
{$endif defined(support_rodata)}
          '.rodata',
          '.bss',
          '.threadvar',
          '.pdata',
          '', { stubs }
          '__DATA,__nl_symbol_ptr',
          '__DATA,__la_symbol_ptr',
          '__DATA,__mod_init_func',
          '__DATA,__mod_term_func',
          '.idata$2','.idata$4','.idata$5','.idata$6','.idata$7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges','.debug_loc','.debug_loclists',
          '.fpc',
          '.toc',
          '.init',
          '.fini',
          '.objc_class',
          '.objc_meta_class',
          '.objc_cat_cls_meth',
          '.objc_cat_inst_meth',
          '.objc_protocol',
          '.objc_string_object',
          '.objc_cls_meth',
          '.objc_inst_meth',
          '.objc_cls_refs',
          '.objc_message_refs',
          '.objc_symbols',
          '.objc_category',
          '.objc_class_vars',
          '.objc_instance_vars',
          '.objc_module_info',
          '.objc_class_names',
          '.objc_meth_var_types',
          '.objc_meth_var_names',
          '.objc_selector_strs',
          '.objc_protocol_ext',
          '.objc_class_ext',
          '.objc_property',
          '.objc_image_info',
          '.objc_cstring_object',
          '.objc_sel_fixup',
          '__DATA,__objc_data',
          '__DATA,__objc_const',
          '.objc_superrefs',
          '__DATA, __datacoal_nt,coalesced',
          '.objc_classlist',
          '.objc_nlclasslist',
          '.objc_catlist',
          '.obcj_nlcatlist',
          '.objc_protolist',
          '.stack',
          '.heap',
          '.gcc_except_table',
          '.ARM.attributes',
          '.note'
        );
        secnames_pic : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text',
          '.data.rel',
          '.data.rel',
          '.data.rel',
          '.bss',
          '.threadvar',
          '.pdata',
          '', { stubs }
          '__DATA,__nl_symbol_ptr',
          '__DATA,__la_symbol_ptr',
          '__DATA,__mod_init_func',
          '__DATA,__mod_term_func',
          '.idata$2','.idata$4','.idata$5','.idata$6','.idata$7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges','.debug_loc','.debug_loclists',
          '.fpc',
          '.toc',
          '.init',
          '.fini',
          '.objc_class',
          '.objc_meta_class',
          '.objc_cat_cls_meth',
          '.objc_cat_inst_meth',
          '.objc_protocol',
          '.objc_string_object',
          '.objc_cls_meth',
          '.objc_inst_meth',
          '.objc_cls_refs',
          '.objc_message_refs',
          '.objc_symbols',
          '.objc_category',
          '.objc_class_vars',
          '.objc_instance_vars',
          '.objc_module_info',
          '.objc_class_names',
          '.objc_meth_var_types',
          '.objc_meth_var_names',
          '.objc_selector_strs',
          '.objc_protocol_ext',
          '.objc_class_ext',
          '.objc_property',
          '.objc_image_info',
          '.objc_cstring_object',
          '.objc_sel_fixup',
          '__DATA, __objc_data',
          '__DATA, __objc_const',
          '.objc_superrefs',
          '__DATA, __datacoal_nt,coalesced',
          '.objc_classlist',
          '.objc_nlclasslist',
          '.objc_catlist',
          '.obcj_nlcatlist',
          '.objc_protolist',
          '.stack',
          '.heap',
          '.gcc_except_table',
          '.ARM.attributes',
          '.note'
        );
      var
        sep,
        coffseparator : string[3];
        secname : string;
        separatorpos : sizeint;
      begin
        if (cs_create_pic in CurrentSettings.ModuleSwitches) and
           not(TargetInfo.system in systems_darwin) then
          secname:=secnames_pic[atype]
        else
          secname:=secnames[atype];

        if (atype=sec_fpc) and (Copy(aname,1,3)='res') then
          begin
            result:=secname+'.'+aname;
            exit;
          end;

        if atype=sec_threadvar then
          begin
            if (TargetInfo.system in systems_windows) then
              secname:='.tls'
            else if (TargetInfo.system in systems_linux) then
              secname:='.tbss';
          end;

        { Windows correctly handles reallocations in readonly sections }
        if (atype=sec_rodata) and
          (TargetInfo.system in systems_all_windows) then
          secname:='.rodata';

        { PIC package metadata needs writable relocations until RELRO applies. }
        if ((TargetInfo.system in systems_android) or
            ((TargetInfo.system=system_x86_64_linux) and
             (tf_supports_packages in TargetInfo.flags))) and
           (cs_create_pic in CurrentSettings.ModuleSwitches) then
          begin
            case atype of
              sec_rodata:
                secname:='.data.rel.ro';
              sec_rodata_norel:
                secname:='.rodata';
              else
                ;
            end;
          end;

        { section type user gives the user full control on the section name }
        if atype=sec_user then
          secname:=aname;

        if atype=sec_note then
          secname:='.note'+aname;

        if is_smart_section(atype) and (aname<>'') then
          begin
            case aorder of
              secorder_begin :
                sep:='.b_';
              secorder_end :
                sep:='.z_';
              else
                sep:='.n_';
            end;
            result:=secname+sep+aname
          end
        else
          result:=secname;

        if UseWindowsComdat and
           create_smartlink_sections and
           (aname<>'') and
           not (atype in [sec_bss,sec_toc,sec_user,sec_note]) then
          begin
            case aorder of
              secorder_begin:
                coffseparator:='$B_';
              secorder_end:
                coffseparator:='$Y_';
              else
                coffseparator:='$N_';
            end;
            separatorpos:=Pos(sep,result);
            if separatorpos<>0 then
              begin
                Delete(result,separatorpos,Length(sep));
                Insert(coffseparator,result,separatorpos);
              end;
          end;
      end;

    function TGNUAssembler.sectionattrs(atype:TAsmSectiontype):string;
      begin
        result:='';
        if (atype=sec_rodata) and (TargetInfo.system=system_x86_64_linux) and
           (tf_supports_packages in TargetInfo.flags) and
           (cs_create_pic in CurrentSettings.ModuleSwitches) then
          result:='aw';
        if (TargetInfo.system in [system_i386_win32,system_x86_64_win64,system_aarch64_win64]) then
          begin
            result:=sectionattrs_coff(atype);
          end;
      end;

    function TGNUAssembler.sectionattrs_coff(atype:TAsmSectiontype):string;
      begin
        case atype of
          sec_code, sec_init, sec_fini, sec_stub:
            result:='x';

          { TODO: must be individual for each section }
          sec_user:
            result:='d';

          sec_data, sec_data_lazy, sec_data_nonlazy, sec_fpc,
          sec_idata2, sec_idata4, sec_idata5, sec_idata6, sec_idata7:
            result:='d';

          { TODO: these need a fix to become read-only }
          sec_rodata, sec_rodata_norel:
            if TargetInfo.system=system_aarch64_win64 then
              result:='r'
            else
              result:='d';

          sec_bss:
            result:='b';

          { TODO: Somewhat questionable. FPC does not allow initialized threadvars,
            so no sense to mark it as containing data. But Windows allows it to
            contain data, and Linux even has .tdata and .tbss }
          sec_threadvar:
            result:='b';

          sec_pdata, sec_edata, sec_eh_frame, sec_toc:
            result:='r';

          sec_debug_frame,sec_debug_info,sec_debug_line,sec_debug_abbrev,
          sec_debug_aranges,sec_debug_ranges,sec_debug_loc,sec_debug_loclists:
            if UseWindowsComdat then
              result:='rD'
            else
              result:='n';
        else
          result:='';  { defaults to data+load }
        end;
      end;


    function TGNUAssembler.sectionflags(secflags:TSectionFlags):string;
      var
        secflag : TSectionFlag;
      begin
        result:='';
        for secflag in secflags do begin
          case secflag of
            SF_A:
              result:=result+'a';
            SF_W:
              result:=result+'w';
            SF_X:
              result:=result+'x';
          end;
        end;
      end;


    procedure TGNUAssembler.WriteSectionComdat(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder);
      var
        info : TGNUWin64ComdatInfo;
        finalsectionname : string;
      begin
        if not UseWindowsComdat or
           not create_smartlink_sections then
          exit;
        finalsectionname:=sectionname(atype,aname,aorder);
        info:=FindWin64ComdatInfo(finalsectionname);
        if not Assigned(info) and IsWin64SmartSection(atype,aname) then
          info:=EnsureWin64ComdatLeader(finalsectionname);
        if not Assigned(info) then
          exit;
        if info.Associative then
          writer.AsmWrite(',associative,'+info.Key)
        else
          begin
            writer.AsmWrite(',one_only,'+info.Key);
            if not info.KeyDefined then
              begin
                FWin64ComdatKeyToDefine:=info.Key;
                info.KeyDefined:=true;
              end;
          end;
      end;


    function TGNUAssembler.sectionalignment_aix(atype:TAsmSectiontype;secalign: LongInt): string;
      var
        l: LongInt;
      begin
        if (secalign=0) or
           not(atype in [sec_code,sec_bss,sec_rodata_norel,sec_rodata,sec_data]) then
          begin
            result:='';
            exit;
          end;
        if not IsPowerOf2(secalign,l) then
          InternalError(2012022201);
        result:=ToStr(l);
      end;


    procedure TGNUAssembler.WriteSection(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder;secalign:LongInt;secflags:TSectionFlags=[];secprogbits:TSectionProgbits=SPB_None);
      var
        s : string;
        usesectionprogbits,
        usesectionflags: boolean;
      begin
        FWin64ComdatKeyToDefine:='';
        writer.AsmLn;
        usesectionflags:=false;
        usesectionprogbits:=false;
        case TargetInfo.system of
         system_i386_win32,
         system_x86_64_win64,
         system_i386_nativent,
         system_aarch64_win64:
           begin
             { according to the GNU AS guide AS for COFF does not support the
               progbits }
             writer.AsmWrite('.section ');
             usesectionflags:=true;
           end;
         system_x86_64_darwin,
         system_aarch64_ios,
         system_aarch64_iphonesim,
         system_aarch64_darwin,
         system_x86_64_iphonesim:
           begin
             if (atype in [sec_stub]) then
               writer.AsmWrite('.section ');
           end;
         else
           begin
             writer.AsmWrite('.section ');
             { sectionname may rename those sections, so we do not write flags/progbits for them,
               the assembler will ignore them/spite out a warning anyways }
             if not(atype in [sec_data,sec_rodata,sec_rodata_norel]) and
                not(atype=sec_fpc) and
                not(atype=sec_note) then
               begin
                 usesectionflags:=true;
                 usesectionprogbits:=true;
               end;
           end
        end;
        s:=sectionname(atype,aname,aorder);
        writer.AsmWrite(s);
        { flags explicitly defined? }
        if (usesectionflags or usesectionprogbits) and
           ((secflags<>[]) or
            (secprogbits<>SPB_None)) then
          begin
            if usesectionflags then
              begin
                s:=',"'+sectionflags(secflags);
                writer.AsmWrite(s+'"');
              end;
            if usesectionprogbits then
              begin
                case secprogbits of
                  SPB_PROGBITS:
                    writer.AsmWrite(',%progbits');
                  SPB_NOBITS:
                    writer.AsmWrite(',%nobits');
                  SPB_NOTE:
                    writer.AsmWrite(',%note');
                  SPB_None:
                    ;
                  else
                    InternalError(2019100801);
                end;
              end;
          end
        else
          case atype of
            sec_fpc :
              if aname = 'resptrs' then
                writer.AsmWrite(', "a", @progbits');
            sec_stub :
              InternalError(2006031101);
            sec_note :
              writer.AsmWrite(', "", @note');
          else
            { GNU AS won't recognize '.text.n_something' section name as belonging
              to '.text' and assigns default attributes to it, which is not
              always correct. We have to fix it.

              TODO: This likely applies to all systems which smartlink without
              creating libraries }
            begin
              if is_smart_section(atype) and (aname<>'') then
                begin
                  s:=sectionattrs(atype);
                  if (s<>'') then
                    writer.AsmWrite(',"'+s+'"');
                end;
            end;
          end;
        WriteSectionComdat(atype,aname,aorder);
        writer.AsmLn;
        LastSecType:=atype;
        if FWin64ComdatKeyToDefine<>'' then
          begin
            writer.AsmWriteLn('.globl '+FWin64ComdatKeyToDefine);
            writer.AsmWriteLn(FWin64ComdatKeyToDefine+':');
            FWin64ComdatKeyToDefine:='';
          end;
      end;


    procedure TGNUAssembler.WriteCFI(hp: TAICFIBase);
      begin
        writer.AsmWrite(cfi2str[hp.cfityp]);
        case hp.cfityp of
          cfi_startproc,
          cfi_endproc:
            ;
          cfi_undefined,
          cfi_restore,
          cfi_def_cfa_register:
            begin
              writer.AsmWrite(' ');
              writer.AsmWrite(gas_regname(TAICFIOpReg(hp).reg1));
            end;
          cfi_def_cfa_offset:
            begin
              writer.AsmWrite(' ');
              writer.AsmWrite(ToStr(TAICFIOpVal(hp).val1));
            end;
          cfi_offset:
            begin
              writer.AsmWrite(' ');
              writer.AsmWrite(gas_regname(TAICFIOpRegVal(hp).reg1));
              writer.AsmWrite(',');
              writer.AsmWrite(ToStr(TAICFIOpRegVal(hp).Val));
            end;
          else
            InternalError(2019030203);
        end;
        writer.AsmLn;
      end;




    procedure TGNUAssembler.WriteTree(p:TAsmList);

      function needsObject(hp : TAISymbol) : boolean;
        begin
          needsObject :=
              (
                Assigned(hp.next) and
                 (TAI(hp.next).typ in [ait_const,ait_datablock,ait_realconst])
              ) or
              (hp.sym.typ in [AT_DATA,AT_METADATA]);

        end;


      procedure doalign(alignment: byte; use_op: boolean; fillop: byte; maxbytes: byte; out last_align: LongInt;lasthp:TAI);
        var
          i: LongInt;
          alignment64 : int64;
        begin
          last_align:=alignment;
          if alignment>1 then
            begin
              if not(TargetInfo.system in systems_darwin) then
                begin
                      alignment64:=alignment;
                      if (maxbytes<>alignment) and IsPowerOf2(alignment64,i) then
                        begin
                          if use_op then
                            begin
                              writer.AsmWrite(#9'.p2align '+ToStr(i)+','+ToStr(fillop)+','+ToStr(maxbytes));
                              writer.AsmLn;
                              writer.AsmWrite(#9'.p2align '+ToStr(i-1)+','+ToStr(fillop));
                            end
                          else
                            begin
                              writer.AsmWrite(#9'.p2align '+ToStr(i)+',,'+ToStr(maxbytes));
                              writer.AsmLn;
                              writer.AsmWrite(#9'.p2align '+ToStr(i-1));
                            end
                        end
                      else
                        begin
                          writer.AsmWrite(#9'.balign '+ToStr(alignment));
                          if use_op then
                            writer.AsmWrite(','+ToStr(fillop))
{$ifdef x86}
                          { force NOP as alignment op code }
                          else if (LastSecType=sec_code) then
                            writer.AsmWrite(',0x90');
{$endif x86}
                        end;
                end
              else
                begin
                  { darwin and aix as only support .align }
                  if not IsPowerOf2(alignment,i) then
                    InternalError(2003010305);
                  writer.AsmWrite(#9'.align '+ToStr(i));
                  last_align:=i;
                end;
              writer.AsmLn;
            end;
        end;


    var
      ch       : char;
      lasthp,
      hp       : TAI;
      ConstDef : TAIConstType;
      s,t      : string;
      i,pos,l  : LongInt;
      InlineLevel : cardinal;
      last_align : LongInt;

      do_line  : boolean;
      sepChar : char;
      replaceforbidden: boolean;
      cursec,
      leadersec : TAISection;
      leaderinfo : TGNUWin64ComdatInfo;
    begin
      if not Assigned(p) then
       exit;
      replaceforbidden:=asminfo^.dollarsign<>'$';

      last_align := 2;
      InlineLevel:=0;
      { lineinfo is only needed for al_procedures (PFV) }
      do_line:=(cs_asm_source in CurrentSettings.GlobalSwitches) or
               ((cs_lineinfo in CurrentSettings.ModuleSwitches)
                 and (p=CurrentAsmData.asmlists[al_procedures]));
      lasthp:=nil;
      hp:=TAI(p.first);
      while Assigned(hp) do
       begin
         prefetch(pointer(hp.next)^);
         if not(hp.typ in SkipLineInfo) then
          begin
            CurrentFilePos:=TAILineInfo(hp).fileinfo;
            { no line info for inlined code }
            if do_line and (inlinelevel=0) then
              WriteSourceLine(hp as TAILineInfo);
          end;

         case hp.typ of

           ait_align :
             begin
               doalign(TAIAlignAbstract(hp).aligntype,TAIAlignAbstract(hp).use_op,TAIAlignAbstract(hp).fillop,TAIAlignAbstract(hp).maxbytes,last_align,lasthp);
             end;

           ait_section :
             begin
               ResetSourceLines;

               cursec:=TAISection(hp);
               leadersec:=cursec.AssociativeSection;
               if UseWindowsComdat and
                  create_smartlink_sections and
                  Assigned(leadersec) and
                  IsWin64SmartSection(leadersec.sectype,leadersec.name^) then
                 begin
                   leaderinfo:=FindWin64ComdatInfo(sectionname(leadersec.sectype,leadersec.name^,leadersec.secorder));
                   if not Assigned(leaderinfo) or leaderinfo.Associative then
                     InternalError(2026092301);
                   RegisterWin64AssociativeComdat(sectionname(cursec.sectype,cursec.name^,cursec.secorder),leaderinfo.Key);
                 end;

               if TAISection(hp).sectype<>sec_none then
                 if replaceforbidden then
                   WriteSection(TAISection(hp).sectype,ApplyAsmSymbolRestrictions(TAISection(hp).name^),TAISection(hp).secorder,
                     TAISection(hp).secalign,TAISection(hp).secflags,TAISection(hp).secprogbits)
                 else
                   WriteSection(TAISection(hp).sectype,TAISection(hp).name^,TAISection(hp).secorder,
                     TAISection(hp).secalign,TAISection(hp).secflags,TAISection(hp).secprogbits)
               else
                 begin
{$ifdef EXTDEBUG}
                   writer.AsmWrite(asminfo^.comment);
                   writer.AsmWriteln(' sec_none');
{$endif EXTDEBUG}
                end;
             end;

           ait_datablock :
             begin
               if (TargetInfo.system in systems_darwin) then
                 begin
                   { On Mac OS X you can't have common symbols in a shared library
                     since those are in the TEXT section and the text section is
                     read-only in shared libraries (so it can be shared among different
                     processes). The alternate code creates some kind of common symbols
                     in the data segment.
                   }

                   if TAIDataBlock(hp).is_global then
                     begin
                       if TAIDataBlock(hp).sym.bind=AB_PRIVATE_EXTERN then
                         WriteHiddenSymbol(TAIDataBlock(hp).sym);
                       writer.AsmWrite('.globl ');
                       writer.AsmWriteln(TAIDataBlock(hp).sym.name);
                       writer.AsmWriteln('.data');
                       writer.AsmWrite('.zerofill __DATA, __common, ');
                       writer.AsmWrite(TAIDataBlock(hp).sym.name);
                       writer.AsmWriteln(', '+ToStr(TAIDataBlock(hp).Size)+','+ToStr(last_align));
                       if not(LastSecType in [sec_data,sec_none]) then
                         writesection(LastSecType,'',secorder_default,1 shl last_align);
                     end
                   else
                     begin
                       writer.AsmWrite(#9'.lcomm'#9);
                       writer.AsmWrite(TAIDataBlock(hp).sym.name);
                       writer.AsmWrite(','+ToStr(TAIDataBlock(hp).Size));
                       writer.AsmWrite(','+ToStr(last_align));
                       writer.AsmLn;
                     end;
                 end
               else
                 begin
{$ifdef USE_COMM_IN_BSS}
                   if writingpackages then
                     begin
                       { The .comm is required for COMMON symbols. These are used
                         in the shared library loading. All the symbols declared in
                         the .so file need to resolve to the data allocated in the main
                         program (PFV) }
                       if TAIDataBlock(hp).is_global then
                         begin
                           writer.AsmWrite(#9'.comm'#9);
                           if replaceforbidden then
                             writer.AsmWrite(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name))
                           else
                             writer.AsmWrite(TAIDataBlock(hp).sym.name);
                           writer.AsmWrite(','+ToStr(TAIDataBlock(hp).Size));
                           writer.AsmWrite(','+ToStr(last_align));
                           writer.AsmLn;
                         end
                       else
                         begin
                           writer.AsmWrite(#9'.lcomm'#9);
                           if replaceforbidden then
                             writer.AsmWrite(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name));
                           else
                             writer.AsmWrite(TAIDataBlock(hp).sym.name);
                           writer.AsmWrite(','+ToStr(TAIDataBlock(hp).Size));
                           writer.AsmWrite(','+ToStr(last_align));
                           writer.AsmLn;
                         end
                     end
                   else
{$endif USE_COMM_IN_BSS}
                     begin
                       if TAIDataBlock(hp).is_global then
                         begin
                           if (TAIDataBlock(hp).sym.bind=AB_PRIVATE_EXTERN) then
                             WriteHiddenSymbol(TAIDataBlock(hp).sym);
                           writer.AsmWrite(#9'.globl ');
                           if replaceforbidden then
                             writer.AsmWriteln(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name))
                           else
                             writer.AsmWriteln(TAIDataBlock(hp).sym.name);
                         end;
                       sepChar := '@';
                       if replaceforbidden then
                         begin
                           if (tf_needs_symbol_type in TargetInfo.flags) then
                             writer.AsmWriteln(#9'.type '+ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name)+','+sepChar+'object');
                           if (tf_needs_symbol_size in TargetInfo.flags) and (TAIDataBlock(hp).Size > 0) then
                              writer.AsmWriteln(#9'.size '+ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name)+','+ToStr(TAIDataBlock(hp).Size));
                           writer.AsmWrite(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name))
                         end
                       else
                         begin
                           if (tf_needs_symbol_type in TargetInfo.flags) then
                             writer.AsmWriteln(#9'.type '+TAIDataBlock(hp).sym.name+','+sepChar+'object');
                           if (tf_needs_symbol_size in TargetInfo.flags) and (TAIDataBlock(hp).Size > 0) then
                             writer.AsmWriteln(#9'.size '+TAIDataBlock(hp).sym.name+','+ToStr(TAIDataBlock(hp).Size));
                           writer.AsmWrite(TAIDataBlock(hp).sym.name);
                         end;
                       writer.AsmWriteln(':');
                       writer.AsmWriteln(#9'.zero '+ToStr(TAIDataBlock(hp).Size));
                     end;
                 end;
             end;

           ait_const:
             begin
               ConstDef:=TAIConst(hp).consttype;
               case ConstDef of
{$ifndef cpu64bitaddr}
                 aitconst_128bit :
                    begin
                      InternalError(200404291);
                    end;

                 aitconst_64bit :
                    begin
                      if Assigned(TAIConst(hp).sym) then
                        InternalError(200404292);
                      begin
                          writer.AsmWrite(ait_const2str[aitconst_32bit]);
                          begin
                              writer.AsmWrite(ToStr(LongInt(lo(TAIConst(hp).Value))));
                              writer.AsmWrite(',');
                              writer.AsmWrite(ToStr(LongInt(hi(TAIConst(hp).Value))));
                            end;
                        end;
                      writer.AsmLn;
                    end;
                 aitconst_gottpoff:
                   begin
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'(gottpoff)+(.-'+TAIConst(hp).endsym.name+ToStr_With_Plus(TAIConst(hp).symofs)+')');
                     writer.Asmln;
                   end;
                 aitconst_tlsgd:
                   begin
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'(tlsgd)+(.-'+TAIConst(hp).endsym.name+ToStr_With_Plus(TAIConst(hp).symofs)+')');
                     writer.Asmln;
                   end;
                 aitconst_tlsdesc:
                   begin
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'(tlsdesc)+(.-'+TAIConst(hp).endsym.name+ToStr_With_Plus(TAIConst(hp).symofs)+')');
                     writer.Asmln;
                   end;
                 aitconst_tpoff:
                   begin
                     if Assigned(TAIConst(hp).endsym) or (TAIConst(hp).symofs<>0) then
                       InternalError(2019092805);
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'(tpoff)');
                     writer.Asmln;
                   end;
{$endif cpu64bitaddr}
                 aitconst_dtpoff:
                   begin
{$ifdef x86_64}
                     writer.AsmWrite(#9'.long'#9+TAIConst(hp).sym.name+'@dtpoff');
                     writer.Asmln;
{$endif x86_64}
{$ifdef i386}
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'@tdpoff');
                     writer.Asmln;
{$endif i386}
                   end;
                 aitconst_got:
                   begin
                     if TAIConst(hp).symofs<>0 then
                       InternalError(2015091401);  // No symbol offset is allowed for GOT.
                     writer.AsmWrite(#9'.word'#9+TAIConst(hp).sym.name+'(GOT)');
                     writer.AsmLn;
                   end;

                 aitconst_gotoff_symbol:
                   begin
                     if (TAIConst(hp).sym=nil) then
                       InternalError(2014022601);
                     case TargetInfo.cpu of

                       cpu_i386:
                         begin
                           writer.AsmWrite(ait_const2str[aitconst_32bit]);
                           writer.AsmWrite(TAIConst(hp).sym.name+'-_GLOBAL_OFFSET_TABLE_');
                         end;
                     else
                       InternalError(2014022602);
                     end;
                     if (TAIConst(hp).Value<>0) then
                       writer.AsmWrite(ToStr_With_Plus(TAIConst(hp).Value));
                     writer.AsmLn;
                   end;

                 aitconst_uleb128bit,
                 aitconst_sleb128bit,
{$ifdef cpu64bitaddr}
                 aitconst_128bit,
                 aitconst_64bit,
{$endif cpu64bitaddr}
                 aitconst_32bit,
                 aitconst_16bit,
                 aitconst_8bit,
                 aitconst_rva_symbol,
                 aitconst_secrel32_symbol,
                 aitconst_darwin_dwarf_delta32,
                 aitconst_darwin_dwarf_delta64,
                 aitconst_half16bit,
                 aitconst_gs,
                 aitconst_16bit_unaligned,
                 aitconst_32bit_unaligned,
                 aitconst_64bit_unaligned:
                   begin
                     if (TargetInfo.system in systems_darwin) and
                        (ConstDef in [aitconst_uleb128bit,aitconst_sleb128bit]) then
                       begin
                         writer.AsmWrite(ait_const2str[aitconst_8bit]);
                         case TAIConst(hp).consttype of
                           aitconst_uleb128bit:
                             writer.AsmWrite(uleb128tostr(qword(TAIConst(hp).Value)));
                           aitconst_sleb128bit:
                             writer.AsmWrite(sleb128tostr(TAIConst(hp).Value));
                           else
                             ;
                         end
                       end
                     else
                       begin
                         writer.AsmWrite(ait_const2str[ConstDef]);
                         l:=0;
                         t := '';
                         repeat
                           if Assigned(TAIConst(hp).sym) then
                             begin
                               if Assigned(TAIConst(hp).endsym) then
                                 begin
                                   if (ConstDef in [aitconst_darwin_dwarf_delta32,aitconst_darwin_dwarf_delta64]) then
                                     begin
                                       s := NextSetLabel;
                                       t := #9'.set '+s+','+TAIConst(hp).endsym.name+'-'+TAIConst(hp).sym.name;
                                     end
                                   else
                                     s:=TAIConst(hp).endsym.name+'-'+TAIConst(hp).sym.name
                                  end
                               else
                                 s:=TAIConst(hp).sym.name;
                               if replaceforbidden then
                                 s:=ApplyAsmSymbolRestrictions(s);
                               if TAIConst(hp).Value<>0 then
                                 s:=s+ToStr_With_Plus(TAIConst(hp).Value);
                             end
                           else
{$ifdef cpu64bitaddr}
                             s:=ToStr(TAIConst(hp).Value);
{$else cpu64bitaddr}
                             { 64 bit constants are already handled above in this case }
                             s:=ToStr(LongInt(TAIConst(hp).Value));
{$endif cpu64bitaddr}
                           if ConstDef = aitconst_half16bit then
                             s:='('+s+')/2';
                           if ConstDef = aitconst_gs then
                             s:='gs('+s+')';

                           writer.AsmWrite(s);
                           inc(l,length(s));
                           { Values with symbols are written on a single line to improve
                             reading of the .s file (PFV) }
                           if Assigned(TAIConst(hp).sym) or
                              not(LastSecType in [sec_data,sec_rodata,sec_rodata_norel]) or
                              (l>line_length) or
                              (hp.next=nil) or
                              (TAI(hp.next).typ<>ait_const) or
                              (TAIConst(hp.next).consttype<>ConstDef) or
                              Assigned(TAIConst(hp.next).sym) then
                             break;
                           hp:=TAI(hp.next);
                           writer.AsmWrite(',');
                         until false;
                         if (t <> '') then
                           begin
                             writer.AsmLn;
                             writer.AsmWrite(t);
                           end;
                       end;
                      writer.AsmLn;
                   end;
                 else
                   InternalError(200704251);
               end;
             end;

           ait_realconst :
             begin
               WriteRealConstAsBytes(TAIRealConst(hp),#9'.byte'#9,do_line);
             end;

           ait_string :
             begin
               pos:=0;
               begin
                   for i:=1 to TAIString(hp).len do
                    begin
                      if pos=0 then
                       begin
                         writer.AsmWrite(#9'.ascii'#9'"');
                         pos:=20;
                       end;
                      ch:=AnsiChar(TAIString(hp).str[i-1]);
                      case ch of
                        #0, {This can't be done by range, because a bug in FPC}
                        #1..#31,
                        '"',#128..#255:
                          s:='\'+ToStr(ord(ch) shr 6)+ToStr((ord(ch) and 63) shr 3)+ToStr(ord(ch) and 7);
                        '\':
                          s:='\\';
                      else
                        s:=ch;
                      end;
                      writer.AsmWrite(s);
                      inc(pos,length(s));
                      if (pos>line_length) or (i=TAIString(hp).len) then
                       begin
                         writer.AsmWriteLn('"');
                         pos:=0;
                       end;
                    end;
                 end;
             end;

           ait_label :
             begin
               if (TAILabel(hp).LabSym.Is_Used) then
                begin
                  if TAILabel(hp).LabSym.bind in [AB_GLOBAL,AB_PRIVATE_EXTERN] then
                   begin
                     if (TAILabel(hp).LabSym.bind=AB_PRIVATE_EXTERN) then
                       begin
                         writer.AsmWrite(#9'.private_extern ');
                         writer.AsmWriteln(TAILabel(hp).LabSym.name);
                       end;
                     writer.AsmWrite('.globl'#9);
                     if replaceforbidden then
                       writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAILabel(hp).LabSym.name))
                     else
                       writer.AsmWriteLn(TAILabel(hp).LabSym.name);
                   end;
                  if replaceforbidden then
                    writer.AsmWrite(ApplyAsmSymbolRestrictions(TAILabel(hp).LabSym.name))
                  else
                    writer.AsmWrite(TAILabel(hp).LabSym.name);
                  writer.AsmWriteLn(':');
                end;
             end;

           ait_symbol :
             begin
               if TAISymbol(hp).is_global then
                begin
                  writer.AsmWrite('.globl'#9);
                  if replaceforbidden then
                    writer.AsmWriteln(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name))
                  else
                    writer.AsmWriteln(TAISymbol(hp).sym.name);
                  if (TAISymbol(hp).sym.bind=AB_PRIVATE_EXTERN) then
                    WriteHiddenSymbol(TAISymbol(hp).sym);
                end;
               sepChar := '@';
               if (tf_needs_symbol_type in TargetInfo.flags) then
                 begin
                   writer.AsmWrite(#9'.type'#9 + TAISymbol(hp).sym.name);
                   if (needsObject(TAISymbol(hp))) then
                     writer.AsmWriteLn(',' + sepChar + 'object')
                   else
                     writer.AsmWriteLn(',' + sepChar + 'function');
                 end;
               if replaceforbidden then
                 if not(TAISymbol(hp).has_value) then
                   writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name + ':'))
                 else
                   writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name + '=' + ToStr(TAISymbol(hp).Value)))
               else if not(TAISymbol(hp).has_value) then
                 writer.AsmWriteLn(TAISymbol(hp).sym.name + ':')
               else
                 writer.AsmWriteLn(TAISymbol(hp).sym.name + '=' + ToStr(TAISymbol(hp).Value));
             end;
           ait_symbolpair:
             begin
               writer.AsmWrite(#9);
               writer.AsmWrite(symbolpairkindstr[TAISymbolPair(hp).kind]);
               writer.AsmWrite(' ');
               if TAISymbolPair(hp).kind<>spk_localentry then
                 s:=', '
               else
                 { the .localentry directive has to specify the size from the
                   start till here of the non-local entry code as second argument }
                 s:=', .-';
               sepChar := '@';
               if replaceforbidden then
                 begin
                   { avoid string truncation }
                   writer.AsmWrite(ApplyAsmSymbolRestrictions(TAISymbolPair(hp).sym^));
                   writer.AsmWrite(s);
                   writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAISymbolPair(hp).Value^));
                   if TAISymbolPair(hp).kind=spk_set_global then
                     begin
                       writer.AsmWrite(#9'.globl ');
                       writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAISymbolPair(hp).sym^));
                     end;
                   if (tf_needs_symbol_type in TargetInfo.flags) then
                     begin
                       writer.AsmWrite(#9'.type'#9 + ApplyAsmSymbolRestrictions(TAISymbolPair(hp).sym^));
                       writer.AsmWriteLn(',' + sepChar + 'function');
                     end;
                 end
               else
                 begin
                   { avoid string truncation }
                   writer.AsmWrite(TAISymbolPair(hp).sym^);
                   writer.AsmWrite(s);
                   writer.AsmWriteLn(TAISymbolPair(hp).Value^);
                   if TAISymbolPair(hp).kind=spk_set_global then
                     begin
                       writer.AsmWrite(#9'.globl ');
                       writer.AsmWriteLn(TAISymbolPair(hp).sym^);
                     end;
                   if (tf_needs_symbol_type in TargetInfo.flags) then
                     begin
                       writer.AsmWrite(#9'.type'#9 + TAISymbolPair(hp).sym^);
                       writer.AsmWriteLn(',' + sepChar + 'function');
                     end;
                 end;
             end;
           ait_symbol_end :
             begin
               if (tf_needs_symbol_size in TargetInfo.flags) and
                  (TAISymbolEnd(hp).sym.Is_Used) then
                begin
                  s:=asminfo^.labelprefix+'e'+ToStr(symendcount);
                  inc(symendcount);
                  writer.AsmWriteLn(s+':');
                  writer.AsmWrite(#9'.size'#9);
                  if replaceforbidden then
                    writer.AsmWrite(ApplyAsmSymbolRestrictions(TAISymbolEnd(hp).sym.name))
                  else
                    writer.AsmWrite(TAISymbolEnd(hp).sym.name);
                  writer.AsmWrite(', '+s+' - ');
                  if replaceforbidden then
                    writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAISymbolEnd(hp).sym.name))
                  else
                    writer.AsmWriteLn(TAISymbolEnd(hp).sym.name);
                end;
             end;

           ait_instruction :
             begin
               WriteInstruction(hp);
             end;


           ait_force_line,
           ait_function_name :
             begin
             end;

           ait_cutobject :
             begin
               if SmartAsm then
                begin
                { only reset buffer if nothing has changed }
                  if not(writer.ClearIfEmpty) then
                   begin
                     writer.AsmClose;
                     DoAssemble;
                     writer.AsmCreate(TAICutObject(hp).place);
                   end;
                { avoid empty files }
                  while Assigned(hp.next) and (TAI(hp.next).typ in [ait_cutobject,ait_section,ait_comment]) do
                   begin
                     if TAI(hp.next).typ=ait_section then
                       LastSecType:=TAISection(hp.next).sectype;
                     hp:=TAI(hp.next);
                   end;
                  if LastSecType<>sec_none then
                    WriteSection(LastSecType,'',secorder_default,last_align);
                  writer.MarkEmpty;
                end;
             end;

           ait_marker :
             begin
               if TAIMarker(hp).kind=mark_NoLineInfoStart then
                 inc(InlineLevel)
               else if TAIMarker(hp).kind=mark_NoLineInfoEnd then
                 dec(InlineLevel);
             end;

           ait_directive :
             begin
               WriteDirectiveName(TAIDirective(hp).directive);
               if TAIDirective(hp).name <>'' then
                 begin
                   if replaceforbidden then
                     writer.AsmWrite(ApplyAsmSymbolRestrictions(TAIDirective(hp).name))
                   else
                     writer.AsmWrite(TAIDirective(hp).name);
                 end;
               writer.AsmLn;
             end;

           ait_seh_directive :
             begin
{$ifndef DISABLE_WIN64_SEH}
               writer.AsmWrite(sehdirectivestr[TAISEHDirective(hp).kind]);
               case TAISEHDirective(hp).datatype of
                 sd_none:;
                 sd_string:
                   begin
                     writer.AsmWrite(' '+TAISEHDirective(hp).data.name^);
                     if (TAISEHDirective(hp).data.flags and 1)<>0 then
                       writer.AsmWrite(',@except');
                     if (TAISEHDirective(hp).data.flags and 2)<>0 then
                       writer.AsmWrite(',@unwind');
                   end;
                 sd_reg:
                   writer.AsmWrite(' '+gas_regname(TAISEHDirective(hp).data.reg));
                 sd_offset:
                   writer.AsmWrite(' '+ToStr(TAISEHDirective(hp).data.Offset));
                 sd_regoffset:
                   writer.AsmWrite(' '+gas_regname(TAISEHDirective(hp).data.reg)+', '+
                     ToStr(TAISEHDirective(hp).data.Offset));
               end;
               writer.AsmLn;
{$endif DISABLE_WIN64_SEH}
             end;

           ait_cfi:
             begin
               WriteCFI(TAICFIBase(hp));
             end;
           ait_eabi_attribute:
             begin
               case TAIAttribute(hp).eattr_typ of
                 eattrtype_dword:
                   writer.AsmWrite(#9'.eabi_attribute '+ToStr(TAIAttribute(hp).tag)+','+ToStr(TAIAttribute(hp).Value));
                 eattrtype_ntbs:
                   begin
                     if Assigned(TAIAttribute(hp).valuestr) then
                       writer.AsmWrite(#9'.eabi_attribute '+ToStr(TAIAttribute(hp).tag)+',"'+TAIAttribute(hp).valuestr^+'"')
                     else
                       writer.AsmWrite(#9'.eabi_attribute '+ToStr(TAIAttribute(hp).tag)+',""');
                   end
                 else
                   InternalError(2019100601);
               end;
               writer.AsmLn;
             end;

           ait_attribute:
             begin
               case TAIAttribute(hp).eattr_typ of
                 eattrtype_dword:
                   writer.AsmWrite(#9'.attribute '+ToStr(TAIAttribute(hp).tag)+','+ToStr(TAIAttribute(hp).Value));
                 eattrtype_ntbs:
                   begin
                     if Assigned(TAIAttribute(hp).valuestr) then
                       writer.AsmWrite(#9'.attribute '+ToStr(TAIAttribute(hp).tag)+',"'+TAIAttribute(hp).valuestr^+'"')
                     else
                       writer.AsmWrite(#9'.attribute '+ToStr(TAIAttribute(hp).tag)+',""');
                   end
                 else
                   InternalError(2024123001);
               end;
               writer.AsmLn;
             end;

           else
             if not WriteComments(hp) then
               InternalError(2006012201);
         end;
         lasthp:=hp;
         hp:=TAI(hp.next);
       end;
    end;


    procedure TGNUAssembler.WriteExtraHeader;
      begin
      end;


    procedure TGNUAssembler.WriteExtraFooter;
      begin
      end;


    procedure TGNUAssembler.WriteInstruction(hp: TAI);
      begin
        InstrWriter.WriteInstruction(hp);
      end;


    procedure TGNUAssembler.WriteWeakSymbolRef(s: TAsmSymbol);
      begin
        writer.AsmWrite(#9'.weak ');
        if asminfo^.dollarsign='$' then
          writer.AsmWriteLn(s.name)
        else
          writer.AsmWriteLn(ApplyAsmSymbolRestrictions(s.name))
      end;


    procedure TGNUAssembler.WriteHiddenSymbol(sym: TAsmSymbol);
      begin
        { on Windows/(PE)COFF, global symbols are hidden by default: global
          symbols that are not explicitly exported from an executable/library,
          become hidden }
        if (TargetInfo.system in systems_windows) then
          exit;
        if TargetInfo.system in systems_darwin then
          writer.AsmWrite(#9'.private_extern ')
        else
          writer.AsmWrite(#9'.hidden ');
        if asminfo^.dollarsign='$' then
          writer.AsmWriteLn(sym.name)
        else
          writer.AsmWriteLn(ApplyAsmSymbolRestrictions(sym.name))
      end;


    procedure TGNUAssembler.WriteUnalignedIntConst(hp: TAIConst);
      var
        pos, size: LongInt;
      begin
        size:=TAIConst(hp).Size;
        writer.AsmWrite(#9'.byte'#9);
        begin
            pos:=0;
            while pos<size do
              begin
                writer.AsmWriteln(ToStr((TAIConst(hp).Value shr (pos*8)) and $ff));
                inc(pos);
                if pos<=size then
                  writer.AsmWrite(', ')
                else
                  writer.AsmLn;
              end;
          end;
        writer.AsmLn;
      end;


    procedure TGNUAssembler.WriteDirectiveName(dir: TAsmDirective);
    begin
      { TODO: implement asd_cpu for GAS => usually .arch or .cpu, but the CPU
        name has to be translated as well }
      if dir=asd_cpu then
        writer.AsmWrite(asminfo^.comment+' CPU ')
      { indent for easier reading }
      else if dir in [asd_option] then
        writer.AsmWrite(#9'.'+directivestr[dir]+' ')
      else
        writer.AsmWrite('.'+directivestr[dir]+' ');
    end;


    procedure TGNUAssembler.WriteAsmList;
    var
      n : string;
      hal : TAsmListType;
      i: LongInt;
    begin
{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       Comment(VDebug,'Start writing gas-styled assembler output for '+CurrentModule.MainSource);
{$endif}

      if CurrentModule.MainSource<>'' then
        n:=ExtractFileName(CurrentModule.MainSource)
      else
        n:=InputFileName;

      { gcc does not add it either for Darwin. Grep for
        TARGET_ASM_FILE_START_FILE_DIRECTIVE in gcc/config/*.h
      }
      if not(TargetInfo.system in systems_darwin) then
        writer.AsmWriteLn(#9'.file "'+FixFileName(n)+'"');

      WriteExtraHeader;
      writer.MarkEmpty;
      symendcount:=0;

      for hal:=low(TAsmListType) to high(TAsmListType) do
        begin
          if not (CurrentAsmData.asmlists[hal].empty) then
            begin
              writer.AsmWriteLn(asminfo^.comment+'Begin asmlist '+AsmlistTypeStr[hal]);
              writetree(CurrentAsmData.asmlists[hal]);
              writer.AsmWriteLn(asminfo^.comment+'End asmlist '+AsmlistTypeStr[hal]);
            end;
        end;

      { add weak symbol markers }
      for i:=0 to CurrentAsmData.asmsymboldict.count-1 do
        if (TAsmSymbol(CurrentAsmData.asmsymboldict[i]).bind=AB_WEAK_EXTERNAL) then
          WriteWeakSymbolRef(TAsmSymbol(CurrentAsmData.asmsymboldict[i]));

      if create_smartlink_sections and
         (TargetInfo.system in systems_darwin) then
        writer.AsmWriteLn(#9'.subsections_via_symbols');

      { "no executable stack" marker }
      { TODO: used by OpenBSD/NetBSD as well? }
      if (TargetInfo.system in (systems_linux + systems_android)) and
         not(cs_executable_stack in CurrentSettings.ModuleSwitches) then
        begin
          writer.AsmWriteLn('.section .note.GNU-stack,"",%progbits');
        end;

      writer.AsmLn;
      WriteExtraFooter;
{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       Comment(VDebug,'Done writing gas-styled assembler output for '+CurrentModule.MainSource);
{$endif EXTDEBUG}
    end;


{****************************************************************************}
{                        Apple/GNU Assembler writer                          }
{****************************************************************************}

    function TAppleGNUAssembler.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      begin
        if (TargetInfo.system in systems_darwin) then
          case atype of
            sec_user:
              begin
                result:='.section '+aname;
                exit;
              end;
            sec_bss:
              { all bss (lcomm) symbols are automatically put in the right }
              { place by using the lcomm assembler directive               }
              atype := sec_none;
            sec_debug_frame,
            sec_eh_frame:
              begin
                result := '.section __DWARF,__debug_info,regular,debug';
                exit;
              end;
            sec_debug_line:
              begin
                result := '.section __DWARF,__debug_line,regular,debug';
                exit;
              end;
            sec_debug_info:
              begin
                result := '.section __DWARF,__debug_info,regular,debug';
                exit;
              end;
            sec_debug_abbrev:
               begin
                 result := '.section __DWARF,__debug_abbrev,regular,debug';
                 exit;
               end;
            sec_debug_aranges:
               begin
                 result := '.section __DWARF,__debug_aranges,regular,debug';
                 exit;
               end;
            sec_debug_ranges:
               begin
                 result := '.section __DWARF,__debug_ranges,regular,debug';
                 exit;
               end;
            sec_rodata:
              begin
                result := '.const_data';
                exit;
              end;
            sec_rodata_norel:
              begin
                result := '.const';
                exit;
              end;
            sec_fpc:
              begin
                result := '.section __TEXT, .fpc, regular, no_dead_strip';
                exit;
              end;
            sec_code:
              begin
                if (aname='fpc_geteipasebx') or
                   (aname='fpc_geteipasecx') then
                  begin
                    result:='.section __TEXT,__textcoal_nt,coalesced,pure_instructions'#10'.weak_definition '+aname+
                      #10'.private_extern '+aname;
                    exit;
                  end;
              end;
            sec_data_nonlazy:
              begin
                result:='.section __DATA, __nl_symbol_ptr,non_lazy_symbol_pointers';
                exit;
              end;
            sec_data_lazy:
              begin
                result:='.section __DATA, __la_symbol_ptr,lazy_symbol_pointers';
                exit;
              end;
            sec_init_func:
              begin
                result:='.section __DATA, __mod_init_func, mod_init_funcs';
                exit;
              end;
            sec_term_func:
              begin
                result:='.section __DATA, __mod_term_func, mod_term_funcs';
                exit;
              end;
            low(TObjCAsmSectionType)..high(TObjCAsmSectionType):
              begin
                result:='.section '+objc_section_name(atype);
                exit
              end;
            else
              ;
          end;
        result := inherited sectionname(atype,aname,aorder);
      end;


    procedure TAppleGNUAssembler.WriteWeakSymbolRef(s: TAsmSymbol);
      begin
        writer.AsmWriteLn(#9'.weak_reference '+s.name);
      end;

    procedure TAppleGNUAssembler.WriteDirectiveName(dir: TAsmDirective);
      begin
        case dir of
          asd_weak_reference:
            writer.AsmWrite('.weak_reference ');
          asd_weak_definition:
            writer.AsmWrite('.weak_definition ');
          else
            inherited;
        end;
      end;


{****************************************************************************}
{                       a.out/GNU Assembler writer                           }
{****************************************************************************}

    function TAoutGNUAssembler.sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
    const
(* Translation table - replace unsupported section types with basic ones. *)
        SecXTable: array[TAsmSectiontype] of TAsmSectiontype = (
         sec_none,
         sec_none,
         sec_code,
         sec_data,
         sec_data (* sec_rodata *),
         sec_data (* sec_rodata_norel *),
         sec_bss,
         sec_data (* sec_threadvar *),
         { used for wince exception handling }
         sec_code (* sec_pdata *),
         { used for darwin import stubs }
         sec_code (* sec_stub *),
         sec_data,(* sec_data_nonlazy *)
         sec_data,(* sec_data_lazy *)
         sec_data,(* sec_init_func *)
         sec_data,(* sec_term_func *)
         { win32 }
         sec_data (* sec_idata2 *),
         sec_data (* sec_idata4 *),
         sec_data (* sec_idata5 *),
         sec_data (* sec_idata6 *),
         sec_data (* sec_idata7 *),
         sec_data (* sec_edata *),
         { C++ exception handling unwinding (uses dwarf) }
         sec_eh_frame,
         { dwarf }
         sec_debug_frame,
         sec_debug_info,
         sec_debug_line,
         sec_debug_abbrev,
         sec_debug_aranges,
         sec_debug_ranges,
         sec_debug_loc,
         sec_debug_loclists,
         { ELF resources }
         sec_code (* sec_fpc *),
         { Table of contents section }
         sec_code (* sec_toc *),
         sec_code (* sec_init *),
         sec_code (* sec_fini *),
         sec_none (* sec_objc_class *),
         sec_none (* sec_objc_meta_class *),
         sec_none (* sec_objc_cat_cls_meth *),
         sec_none (* sec_objc_cat_inst_meth *),
         sec_none (* sec_objc_protocol *),
         sec_none (* sec_objc_string_object *),
         sec_none (* sec_objc_cls_meth *),
         sec_none (* sec_objc_inst_meth *),
         sec_none (* sec_objc_cls_refs *),
         sec_none (* sec_objc_message_refs *),
         sec_none (* sec_objc_symbols *),
         sec_none (* sec_objc_category *),
         sec_none (* sec_objc_class_vars *),
         sec_none (* sec_objc_instance_vars *),
         sec_none (* sec_objc_module_info *),
         sec_none (* sec_objc_class_names *),
         sec_none (* sec_objc_meth_var_types *),
         sec_none (* sec_objc_meth_var_names *),
         sec_none (* sec_objc_selector_strs *),
         sec_none (* sec_objc_protocol_ext *),
         sec_none (* sec_objc_class_ext *),
         sec_none (* sec_objc_property *),
         sec_none (* sec_objc_image_info *),
         sec_none (* sec_objc_cstring_object *),
         sec_none (* sec_objc_sel_fixup *),
         sec_none (* sec_objc_data *),
         sec_none (* sec_objc_const *),
         sec_none (* sec_objc_sup_refs *),
         sec_none (* sec_data_coalesced *),
         sec_none (* sec_objc_classlist *),
         sec_none (* sec_objc_nlclasslist *),
         sec_none (* sec_objc_catlist *),
         sec_none (* sec_objc_nlcatlist *),
         sec_none (* sec_objc_protlist *),
         sec_none (* sec_stack *),
         sec_none (* sec_heap *),
         sec_none (* gcc_except_table *),
         sec_none (* sec_arm_attribute *),
         sec_none (* sec_note *)
        );
      begin
        Result := inherited SectionName (SecXTable [AType], AName, AOrder);
      end;


{****************************************************************************}
{                        Abstract Instruction Writer                         }
{****************************************************************************}

     constructor TCPUInstrWriter.Create(_owner: TGNUAssembler);
       begin
         inherited Create;
         owner := _owner;
       end;

end.
