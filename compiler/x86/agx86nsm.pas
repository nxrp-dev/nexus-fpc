{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements an asmoutput class for the Nasm assembler with
    Intel syntax for the i386+

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
unit agx86nsm;

{$i fpcdefs.inc}

interface

    uses
      CClasses,cpubase,GlobType,
      aasmbase,aasmtai,AAsmData,aasmcpu,assemble,cgutils;

    type

      { TX86NasmAssembler }

      TX86NasmAssembler = class(TExternalAssembler)
      strict private
        type

          { TX86NasmSection }

          TX86NasmSection=class(TFPHashObject)
          end;

          { TX86NasmGroup }

          TX86NasmGroup=class(TFPHashObject)
            Sections: TFPHashObjectList;
            constructor Create(HashObjectList:TFPHashObjectList;const s:TSymStr);
            destructor Destroy;override;
          end;
      private
        FSections: TFPHashObjectList;
        FGroups: TFPHashObjectList;

        using_relative : boolean;

        function CodeSectionName(const aname:string): string;
        procedure WriteReference(var ref : TReference);
        procedure WriteOper(const o:TOper;s : TOpSize; opcode: TAsmOp;ops:LongInt;dest : boolean);
        procedure WriteOper_jmp(const o:TOper; ai : TAICPU);
        procedure WriteSection(atype:TAsmSectiontype;const aname:string;alignment : LongInt);
        procedure WriteHiddenSymbolAttribute(sym: TAsmSymbol);
        procedure ResetSectionsList;
        procedure AddGroup(const grpname: string);
        procedure AddSegmentToGroup(const grpname,segname: string);
        procedure WriteGroup(data:TObject;arg:pointer);
        procedure WriteGroups;
      protected
        function single2str(d: single): string; override;
        function double2str(d: double): string; override;
      public
        destructor Destroy;override;
        procedure WriteTree(p:TAsmList);override;
        procedure WriteAsmList;override;
        procedure WriteExternals;
        procedure WriteSmartExternals;
        procedure WriteHeader;
        function  MakeCmdLine: TCmdStr;override;
      end;



  implementation

    uses
      CUtils,Globals,Systems,FPCHash,
      FModule,FinPut,Verbose,CPUInfo,cgbase
      ;

    const
      line_length = 64;

      nasm_regname_table : array[TRegisterIndex] of string[13] = (
        {r386nasm.inc contains the Nasm name of each register.}
{$if defined(x86_64)}
        {$i r8664nasm.inc}
{$elseif defined(i386)}
        {$i r386nasm.inc}
{$endif}
      );
      { nasm 2.13 expects lowercase cpu names }
      nasm_cpu_name : array[TCPUType] of string = (
{$if defined(x86_64)}
        'ia64',        // cpu_none
        'x64',         // cpu_athlon64
        'x64',         // cpu_x86_64
        'x64',         // cpu_x86_64_v1
        'ia64',        // cpu_core_i
        'ia64',        // cpu_x86_64_v2
        'ia64',        // cpu_bobcat
        'ia64',        // cpu_core_avx
        'ia64',        // cpu_jaguar
        'ia64',        // cpu_piledriver
        'ia64',        // cpu_excavator
        'ia64',        // cpu_core_avx2
        'ia64',        // cpu_x86_64_v3
        'ia64',        // cpu_zen
        'ia64',        // cpu_zen2
        'ia64',        // cpu_x86_64_v4
        'ia64',        // cpu_skylake-x
        'ia64',        // cpu_icelake
        'ia64',        // cpu_icelake_client
        'ia64',        // cpu_icelake_server
        'ia64',        // cpu_zen3
        'ia64',        // cpu_zen4
        'ia64'         // cpu_zen5
{$elseif defined(i386)}
        'ia64',     // cpu_none
        '386',      // cpu_386
        '486',      // cpu_486
        'pentium',  // cpu_Pentium
        'p2',       // cpu_Pentium2
        'p3',       // cpu_Pentium3
        'p4',       // cpu_Pentium4
        'p4',       // cpu_PentiumM
        'ia64',     // cpu_core_i
        'ia64',     // cpu_bobcat
        'ia64',     // cpu_core_avx
        'ia64',     // cpu_jaguar
        'ia64',     // cpu_piledriver
        'ia64',     // cpu_excavator
        'ia64',     // cpu_core_avx2
        'ia64',     // cpu_zen
        'ia64',     // cpu_zen2
        'ia64',     // cpu_skylake_x
        'ia64',     // cpu_icelake
        'ia64',     // cpu_icelake_client
        'ia64',     // cpu_icelake_server
        'ia64',     // cpu_zen3
        'ia64',     // cpu_zen4
        'ia64'      // cpu_zen5
{$endif}
      );

    function nasm_regname(r:TRegister):string;
      var
        p : TRegisterIndex;
      begin
        p:=findreg_by_number(r);
        if p<>0 then
          result:=nasm_regname_table[p]
        else
          result:=generic_regname(r);
      end;


    function TX86NasmAssembler.single2str(d: single): string;
      var
         hs : string;
         p : LongInt;
      begin
         str(d,hs);
      { nasm expects a lowercase e }
         p:=pos('E',hs);
         if p>0 then
          hs[p]:='e';
         p:=pos('+',hs);
         if p>0 then
          delete(hs,p,1);
         single2str:=lower(hs);
      end;


    function TX86NasmAssembler.double2str(d: double): string;
      var
         hs : string;
         p : LongInt;
      begin
         str(d,hs);
      { nasm expects a lowercase e }
         p:=pos('E',hs);
         if p>0 then
          hs[p]:='e';
         p:=pos('+',hs);
         if p>0 then
          delete(hs,p,1);
         double2str:=lower(hs);
      end;




    destructor TX86NasmAssembler.Destroy;
      begin
        FSections.Free;
        FGroups.Free;
        inherited Destroy;
      end;


    function sizestr(s:TOpSize;dest:boolean):string;
      begin
        case s of
           S_B : sizestr:='byte ';
           S_W : sizestr:='word ';
           S_L : sizestr:='dword ';
           S_Q : sizestr:='qword ';
           S_IS : sizestr:='word ';
           S_IL : sizestr:='dword ';
           S_IQ : sizestr:='qword ';
           S_FS : sizestr:='dword ';
           S_FL : sizestr:='qword ';
           S_FX : sizestr:='tword ';
           S_BW : if dest then
               sizestr:='word '
             else
               sizestr:='byte ';
           S_BL : if dest then
               sizestr:='dword '
             else
               sizestr:='byte ';
           S_WL : if dest then
               sizestr:='dword '
             else
               sizestr:='word ';
{$ifdef x86_64}
           S_BQ : if dest then
                   sizestr:='qword '
                  else
                   sizestr:='byte ';
           S_WQ : if dest then
                   sizestr:='qword '
                  else
                   sizestr:='word ';
           S_LQ : if dest then
                   sizestr:='qword '
                  else
                   sizestr:='dword ';
           { Nothing needed for XMM registers }
           S_XMM: sizestr:='';

{$endif x86_64}
          else { S_NO }
            sizestr:='';
        end;
      end;


    Function PadTabs(const p:string;addch:char):string;
      var
        s : string;
        i : LongInt;
      begin
        i:=length(p);
        if addch<>#0 then
         begin
           inc(i);
           s:=p+addch;
         end
        else
         s:=p;
        if i<8 then
         PadTabs:=s+#9#9
        else
         PadTabs:=s+#9;
      end;



{****************************************************************************
                       TX86NasmAssembler.TX86NasmGroup
 ****************************************************************************}


    constructor TX86NasmAssembler.TX86NasmGroup.Create(HashObjectList: TFPHashObjectList; const s: TSymStr);
      begin
        inherited;
        Sections:=TFPHashObjectList.Create;
      end;


    destructor TX86NasmAssembler.TX86NasmGroup.Destroy;
      begin
        Sections.Free;
        inherited Destroy;
      end;


{****************************************************************************
                               TX86NasmAssembler
 ****************************************************************************}


    function TX86NasmAssembler.CodeSectionName(const aname:string): string;
      begin

        result:='.text';

      end;


    procedure TX86NasmAssembler.WriteReference(var ref : TReference);
      var
        first : boolean;
        base_done : boolean;
      begin
        with ref do
         begin
           writer.AsmWrite('[');
           first:=true;
           base_done:=false;
           if (segment<>NR_NO) then
             writer.AsmWrite(nasm_regname(segment)+':');
{$ifdef x86_64}
          if (base=NR_RIP) then
            begin
              { nasm RIP is implicit for pic }
              if not (ref.refaddr in [addr_pic,addr_pic_no_got]) and not using_relative then
                writer.AsmWrite('$ + ');
              base_done:=true;
            end;
{$endif x86_64}
           if Assigned(symbol) then
            begin
              writer.AsmWrite(ApplyAsmSymbolRestrictions(symbol.name));
              if SmartAsm then
                AddSymbol(symbol.name,false);
              first:=false;
            end;
           if (base<>NR_NO) and not base_done then
            begin
              if not(first) then
               writer.AsmWrite('+')
              else
               first:=false;
              writer.AsmWrite(nasm_regname(base))
            end;
           if (index<>NR_NO) then
             begin
               if not(first) then
                 writer.AsmWrite('+')
               else
                 first:=false;
               writer.AsmWrite(nasm_regname(index));
               if scalefactor<>0 then
                 writer.AsmWrite('*'+ToStr(scalefactor));
             end;
           if offset<0 then
             begin
               writer.AsmWrite(ToStr(offset));
               first:=false;
             end
           else if (offset>0) then
             begin
               writer.AsmWrite('+'+ToStr(offset));
               first:=false;
             end;
           if first then
             writer.AsmWrite('0');
           writer.AsmWrite(']');
         end;
       end;


    procedure TX86NasmAssembler.WriteOper(const o:TOper;s : TOpSize; opcode: TAsmOp;ops:LongInt;dest : boolean);
      begin
        case o.typ of
          top_reg :
            writer.AsmWrite(nasm_regname(o.reg));
          top_const :
            begin
              if (ops=1) and (opcode<>A_RET) then
               writer.AsmWrite(sizestr(s,dest));
              writer.AsmWrite(ToStr(o.val));
            end;
          top_ref :
            begin
              if o.ref^.refaddr in [addr_no,addr_pic,addr_pic_no_got] then
                begin
                  if not ((opcode = A_LEA) or (opcode = A_LGS) or
                          (opcode = A_LSS) or (opcode = A_LFS) or
{$ifndef x86_64}
                          (opcode = A_LES) or (opcode = A_LDS) or
{$endif x86_64}
                         // (opcode = A_SHR) or (opcode = A_SHL) or
                         // (opcode = A_SAR) or (opcode = A_SAL) or
                          (opcode = A_OUT) or (opcode = A_IN)) then
                    writer.AsmWrite(sizestr(s,dest));
                  WriteReference(o.ref^);
                end

              else
                begin
{$ifdef x86_64}
                  if s=S_L then
                    writer.AsmWrite('dword ')
                  else
                    writer.AsmWrite('qword ');
{$endif}
{$ifdef i386}
                  writer.AsmWrite('dword ');
{$endif i386}

                  if Assigned(o.ref^.symbol) then
                   begin
                    if SmartAsm then
                      AddSymbol(o.ref^.symbol.name,false);
                    writer.AsmWrite(ApplyAsmSymbolRestrictions(o.ref^.symbol.name));
                    if o.ref^.offset=0 then
                      exit;
                   end;
                  if o.ref^.offset>0 then
                   writer.AsmWrite('+');
                  writer.AsmWrite(ToStr(o.ref^.offset));
                end;
            end;
          else
            InternalError(2020100812);
        end;
      end;


    procedure TX86NasmAssembler.WriteOper_jmp(const o:TOper; ai : TAICPU);
      begin
        case o.typ of
          top_reg :
            writer.AsmWrite(nasm_regname(o.reg));
          top_ref :
            if o.ref^.refaddr=addr_no then
              begin
                if ai.opsize=S_FAR then
                  writer.AsmWrite('far ');
                WriteReference(o.ref^);
              end
            else
              begin
                if ai.opsize=S_FAR then
                  writer.AsmWrite('far ');
                { else
                   writer.AsmWrite('near ') just disables short branches, increasing code size.
                   Omitting it does not cause any bad effects, tested with nasm 2.11. }

                writer.AsmWrite(ApplyAsmSymbolRestrictions(o.ref^.symbol.name));
                if SmartAsm then
                  AddSymbol(o.ref^.symbol.name,false);
                if o.ref^.offset>0 then
                 writer.AsmWrite('+'+ToStr(o.ref^.offset))
                else
                 if o.ref^.offset<0 then
                  writer.AsmWrite(ToStr(o.ref^.offset));
              end;
          top_const :
            writer.AsmWrite(ToStr(aint(o.val)));
          else
            InternalError(2020100813);
        end;
      end;


    const
      ait_const2str : array[aitconst_128bit..aitconst_64bit_unaligned] of string[30]=(
        #9'FIXME_128BIT'#9,#9'DQ'#9,#9'DD'#9,#9'DW'#9,#9'DB'#9,
        #9'FIXME_SLEB128BIT'#9,#9'FIXME_ULEB128BIT'#9,
        #9'RVA'#9,#9'SECREL32'#9,#9'FIXME_darwin_dwarf_delta64'#9,
        #9'FIXME_darwin_dwarf_delta32'#9,#9'FIXME_half16bit'#9,#9'FIXME_gs'#9,
        #9'DW'#9,#9'DD'#9,#9'FIXME_64BIT_UNALIGNED'#9
      );

    procedure TX86NasmAssembler.WriteSection(atype : TAsmSectiontype;
      const aname : string; alignment : LongInt);
      const
        secnames : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text',
          '.data',
          '.data',
          '.rodata',
          '.bss',
          '.tbss',
          '.pdata',
          '.text','.data','.data','.data','.data',
          '.idata2','.idata4','.idata5','.idata6','.idata7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges','.debug_loc','.debug_loclists',
          '.fpc',
          '',
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
          ',gcc_except_table',
          ',ARM_attributes',
          ',note'
        );
      var
        secname,secgroup: string;
      begin
        writer.AsmLn;
        writer.AsmWrite('SECTION ');
        if (atype=sec_threadvar) and
          (TargetInfo.system in systems_windows) then
          writer.AsmWrite('.tls'#9'bss')
        else if (atype=sec_user) then
          writer.AsmWrite(aname)
        else if secnames[atype]='.text' then
          writer.AsmWrite(CodeSectionName(aname))
        else
          writer.AsmWrite(secnames[atype]);
        if create_smartlink_sections and
           (atype<>sec_bss) and
           (aname<>'') then
          begin
            writer.AsmWrite('.');
            writer.AsmWrite(aname);
            if atype in [sec_init, sec_fini, sec_stub, sec_code] then
              writer.AsmWrite(' code align='+ToStr(alignment))
            else if  atype in [sec_rodata, sec_rodata_norel] then
              writer.AsmWrite(' rdata align='+ToStr(alignment))
            else
              writer.AsmWrite(' data align='+ToStr(alignment))
          end;
        writer.AsmLn;
        LastSecType:=atype;
      end;

    procedure TX86NasmAssembler.WriteHiddenSymbolAttribute(sym: TAsmSymbol);
      begin
        if TargetInfo.system in systems_windows then
          exit;
        if TargetInfo.system in systems_darwin then
          writer.AsmWrite(':private_extern')
        else
          case sym.typ of
            AT_FUNCTION:
              writer.AsmWrite(':function hidden');
            AT_DATA:
              writer.AsmWrite(':data hidden');
            else
              InternalError(2020111301);
          end;
      end;

    procedure TX86NasmAssembler.ResetSectionsList;
      begin
        FSections.Free;
        FSections:=TFPHashObjectList.Create;
        FGroups.Free;
        FGroups:=TFPHashObjectList.Create;
      end;

    procedure TX86NasmAssembler.AddGroup(const grpname: string);
      begin
        if FGroups.Find(grpname)=nil then
          TX86NasmGroup.Create(FGroups,grpname);
      end;

    procedure TX86NasmAssembler.AddSegmentToGroup(const grpname, segname: string);
      var
        grp: TX86NasmGroup;
      begin
        grp:=TX86NasmGroup(FGroups.Find(grpname));
        if grp=nil then
          grp:=TX86NasmGroup.Create(FGroups,grpname);
        TX86NasmSection.Create(grp.Sections,segname);
      end;

    procedure TX86NasmAssembler.WriteGroup(data: TObject; arg: pointer);
      var
        grp: TX86NasmGroup;
        i: Integer;
      begin
        grp:=TX86NasmGroup(data);
        writer.AsmWrite('GROUP '+grp.Name);
        for i:=0 to grp.Sections.Count-1 do
          writer.AsmWrite(' '+grp.Sections.NameOfIndex(i));
        writer.AsmLn;
      end;

    procedure TX86NasmAssembler.WriteGroups;
      begin

      end;

    procedure TX86NasmAssembler.WriteTree(p:TAsmList);
{$ifdef cpuextended}
    type
      T80BitArray = array[0..9] of byte;
{$endif cpuextended}
    var
      s : string;
      hp       : TAI;
      counter,
      lines,
      i,j,l    : LongInt;
      InlineLevel : LongInt;
      consttype : TAIConstType;
      do_line, SkipNewLine,
      quoted   : boolean;
      fixed_opcode: TAsmOp;
      prefix, LastSecName  : string;
      LastAlign : LongInt;
      cpu: TCPUType;
      prevfileinfo : TFilePosInfo;
      previnfile : TInputFile;
      NewObject :  boolean;
    begin
      if not Assigned(p) then
       exit;
      InlineLevel:=0;
      NewObject:=true;

      { lineinfo is only needed for al_procedures (PFV) }
      do_line:=(cs_asm_source in CurrentSettings.GlobalSwitches) or
               ((cs_lineinfo in CurrentSettings.ModuleSwitches)
                 and (p=CurrentAsmData.asmlists[al_procedures]));
      hp:=TAI(p.first);
      while Assigned(hp) do
       begin
         prefetch(pointer(hp.next)^);
         if not(hp.typ in SkipLineInfo) then
          begin
            previnfile:=lastinfile;
            prevfileinfo:=lastfileinfo;
            CurrentFilePos:=TAILineInfo(hp).fileinfo;

            { no line info for inlined code }
            if do_line and (inlinelevel=0) then
              WriteSourceLine(hp as TAILineInfo);
            if (lastfileinfo.line<>prevfileinfo.line) or
               (previnfile<>lastinfile) then
              begin
                { +0 postfix means no line increment per assembler instruction }
                writer.AsmWrite('%LINE '+ToStr(CurrentFilePos.line)+'+0');
                if Assigned(lastinfile) and ((previnfile<>lastinfile) or NewObject) then
                  writer.AsmWriteLn(' '+lastinfile.name)
                else
                  writer.AsmLn;
                NewObject:=false;
              end;

          end;

         case hp.typ of
           ait_section :
             begin
               ResetSourceLines;

               if TAISection(hp).sectype<>sec_none then
                 WriteSection(TAISection(hp).sectype,TAISection(hp).name^,TAISection(hp).secalign);
               LastSecType:=TAISection(hp).sectype;
             end;

           ait_align :
             begin
               if (TAIAlign(hp).aligntype>1) then
                 begin
                   if (LastSecType=sec_bss) or (
                      (LastSecType=sec_threadvar) and
                      (TargetInfo.system in systems_windows)
                     ) then
                      writer.AsmWriteLn(#9'ALIGNB '+ToStr(TAIAlign(hp).aligntype))
                    else if TAIAlignAbstract(hp).use_op then
                      writer.AsmWriteLn(#9'ALIGN '+ToStr(TAIAlign(hp).aligntype)+',DB '+ToStr(TAIAlignAbstract(hp).fillop))
                    else if LastSecType in [sec_code,sec_stub,sec_init,sec_fini] then
                      writer.AsmWriteLn(#9'ALIGN '+ToStr(TAIAlign(hp).aligntype))
                    else
                      writer.AsmWriteLn(#9'ALIGN '+ToStr(TAIAlign(hp).aligntype)+',DB 0');
                 end;
             end;

           ait_datablock :
             begin
               if TAIDataBlock(hp).is_global or SmartAsm then
                begin
                  writer.AsmWrite(#9'GLOBAL ');
                  writer.AsmWrite(TAIDataBlock(hp).sym.name);
                  if TAIDataBlock(hp).sym.bind=AB_PRIVATE_EXTERN then
                    WriteHiddenSymbolAttribute(TAIDataBlock(hp).sym);
                  writer.AsmLn;
                end;
               writer.AsmWrite(PadTabs(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name),':'));
               if SmartAsm then
                 AddSymbol(TAIDataBlock(hp).sym.name,true);
               writer.AsmWriteLn('RESB'#9+ToStr(TAIDataBlock(hp).size));
             end;

           ait_const:
             begin
               consttype:=TAIConst(hp).consttype;
               case consttype of
                 aitconst_uleb128bit:
                   writer.AsmWriteLn(ait_const2str[aitconst_8bit]+uleb128tostr(qword(TAIConst(hp).value)));
                 aitconst_sleb128bit:
                   writer.AsmWriteLn(ait_const2str[aitconst_8bit]+sleb128tostr(TAIConst(hp).value));
                 aitconst_128bit:
                   writer.AsmWriteLn(asminfo^.comment+'Unsupported const type '+
                     ait_const2str[consttype]);

{$ifdef x86_64}
                 aitconst_rva_symbol,
                 aitconst_secrel32_symbol: ;
{$endif x86_64}
{$ifdef i386}
                 aitconst_rva_symbol,
                 aitconst_secrel32_symbol,
{$endif i386}
                 aitconst_64bit,
                 aitconst_32bit,
                 aitconst_16bit,
                 aitconst_8bit,
                 aitconst_16bit_unaligned,
                 aitconst_32bit_unaligned,
                 aitconst_64bit_unaligned:
                   begin
                     writer.AsmWrite(ait_const2str[TAIConst(hp).consttype]);
                     l:=0;
                     repeat
                       if Assigned(TAIConst(hp).sym) then
                         begin
                           if SmartAsm then
                             begin
                               AddSymbol(TAIConst(hp).sym.name,false);
                               if Assigned(TAIConst(hp).endsym) then
                                 AddSymbol(TAIConst(hp).endsym.name,false);
                             end;
                           if Assigned(TAIConst(hp).endsym) then
                             s:=ApplyAsmSymbolRestrictions(TAIConst(hp).endsym.name)+'-'+ApplyAsmSymbolRestrictions(TAIConst(hp).sym.name)
                           else
                             s:=ApplyAsmSymbolRestrictions(TAIConst(hp).sym.name);
                           if TAIConst(hp).value<>0 then
                             s:=s+ToStr_With_Plus(TAIConst(hp).value);
                         end
                       else
                         s:=ToStr(TAIConst(hp).value);
                       writer.AsmWrite(s);
                       inc(l,length(s));
                       if (l>line_length) or
                          (hp.next=nil) or
                          (TAI(hp.next).typ<>ait_const) or
                          (TAIConst(hp.next).consttype<>consttype) then
                         break;
                       hp:=TAI(hp.next);
                       writer.AsmWrite(',');
                     until false;
                     writer.AsmLn;
                   end;
                 else
                   InternalError(200704252);
               end;
             end;

           ait_realconst:
             begin
               WriteRealConstAsBytes(TAIRealConst(hp),#9#9'DB'#9,do_line);
             end;

           ait_string :
             begin
               counter := 0;
               lines := TAIString(hp).len div line_length;
             { separate lines in different parts }
               if TAIString(hp).len > 0 then
                Begin
                  for j := 0 to lines-1 do
                   begin
                     writer.AsmWrite(#9#9'DB'#9);
                     quoted:=false;
                     for i:=counter to counter+line_length-1 do
                        begin
                          { it is an ascii character. }
                          if (ord(TAIString(hp).str[i])>31) and
                             (ord(TAIString(hp).str[i])<128) and
                             (TAIString(hp).str[i]<>'"') then
                              begin
                                if not(quoted) then
                                    begin
                                      if i>counter then
                                        writer.AsmWrite(',');
                                      writer.AsmWrite('"');
                                    end;
                                writer.AsmWrite(TAIString(hp).str[i]);
                                quoted:=true;
                              end { if > 31 and < 128 and ord('"') }
                          else
                              begin
                                  if quoted then
                                      writer.AsmWrite('"');
                                  if i>counter then
                                      writer.AsmWrite(',');
                                  quoted:=false;
                                  writer.AsmWrite(ToStr(ord(TAIString(hp).str[i])));
                              end;
                       end; { end for i:=0 to... }
                     if quoted then writer.AsmWrite('"');
                       writer.AsmWrite(TargetInfo.newline);
                     inc(counter,line_length);
                  end; { end for j:=0 ... }
                { do last line of lines }
                if counter<TAIString(hp).len then
                  writer.AsmWrite(#9#9'DB'#9);
                quoted:=false;
                for i:=counter to TAIString(hp).len-1 do
                  begin
                    { it is an ascii character. }
                    if (ord(TAIString(hp).str[i])>31) and
                       (ord(TAIString(hp).str[i])<128) and
                       (TAIString(hp).str[i]<>'"') then
                        begin
                          if not(quoted) then
                              begin
                                if i>counter then
                                  writer.AsmWrite(',');
                                writer.AsmWrite('"');
                              end;
                          writer.AsmWrite(TAIString(hp).str[i]);
                          quoted:=true;
                        end { if > 31 and < 128 and " }
                    else
                        begin
                          if quoted then
                            writer.AsmWrite('"');
                          if i>counter then
                              writer.AsmWrite(',');
                          quoted:=false;
                          writer.AsmWrite(ToStr(ord(TAIString(hp).str[i])));
                        end;
                  end; { end for i:=0 to... }
                if quoted then
                  writer.AsmWrite('"');
                end;
               writer.AsmLn;
             end;

           ait_label :
             begin
               if TAILabel(hp).labsym.is_used then
                 begin
                   if SmartAsm and (TAILabel(hp).labsym.bind=AB_GLOBAL) then
                     begin
                       writer.AsmWrite(#9'GLOBAL ');
                       writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAILabel(hp).labsym.name));
                     end;
                   writer.AsmWriteLn(ApplyAsmSymbolRestrictions(TAILabel(hp).labsym.name)+':');
                 end;
               if SmartAsm then
                 AddSymbol(TAILabel(hp).labsym.name,true);
             end;

           ait_symbol :
             begin
               if TAISymbol(hp).has_value then
                 InternalError(2009090803);
               if TAISymbol(hp).is_global or SmartAsm then
                begin
                  writer.AsmWrite(#9'GLOBAL ');
                  writer.AsmWrite(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name));
                  if TAISymbol(hp).sym.bind=AB_PRIVATE_EXTERN then
                    WriteHiddenSymbolAttribute(TAISymbol(hp).sym);
                  writer.AsmLn;
                end;
               writer.AsmWrite(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name));
               if SmartAsm then
                 AddSymbol(TAISymbol(hp).sym.name,true);
               if (not Assigned(hp.next)) or (Assigned(hp.next) and not(TAI(hp.next).typ in
                  [ait_const,ait_realconst,ait_string])) then
                writer.AsmWriteLn(':')
             end;

           ait_symbol_end : ;

           ait_instruction :
             begin
               fixed_opcode:=TAICPU(hp).FixNonCommutativeOpcodes;
               { We need intel order, no At&t }
               TAICPU(hp).SetOperandOrder(op_intel);
               { LOCK must be on same line as opcode }
               if (TAICPU(hp).ops = 0) and
                   (fixed_opcode = A_LOCK) then
                 SkipNewLine:=true
               else
                 SkipNewLine:=false;

               s:='';
               if ((fixed_opcode=A_FADDP) or
                   (fixed_opcode=A_FMULP))
                  and (TAICPU(hp).ops=0) then
                 begin
                   TAICPU(hp).allocate_oper(2);
                   TAICPU(hp).oper[0]^.typ:=top_reg;
                   TAICPU(hp).oper[0]^.reg:=NR_ST1;
                   TAICPU(hp).oper[1]^.typ:=top_reg;
                   TAICPU(hp).oper[1]^.reg:=NR_ST;
                 end;
                 { NASM only accepts move for loading of
                   simple symbol address }
                  if ((TAICPU(hp).opcode=A_LEA) and
                      (TAICPU(hp).ops=2) and
                      (TAICPU(hp).oper[0]^.typ=top_reg) and
                      (reg2opsize(TAICPU(hp).oper[0]^.reg) in [S_NO,S_Q]) and
                      (TAICPU(hp).oper[1]^.typ=top_ref) and
                      (TAICPU(hp).oper[1]^.ref^.refaddr<>addr_no) and
                      Assigned(TAICPU(hp).oper[1]^.ref^.symbol) and
                      (TAICPU(hp).oper[1]^.ref^.base=NR_NO)) then
                    begin
                      writer.AsmWrite(asminfo^.comment);
                      writer.AsmWriteln('Converting LEA to MOV instruction');
                      TAICPU(hp).opcode:=A_MOV;
                    end;
               if fixed_opcode=A_FWAIT then
                writer.AsmWriteln(#9#9'DB'#9'09bh')
               else if (fixed_opcode=A_XLAT) and (TAICPU(hp).ops=1) and
                       (TAICPU(hp).oper[0]^.typ=top_ref) then
                begin
                  writer.AsmWrite(#9#9);
                  if (TAICPU(hp).oper[0]^.ref^.segment<>NR_NO) and
                     (TAICPU(hp).oper[0]^.ref^.segment<>NR_DS) then
                    writer.AsmWrite(std_regname(TAICPU(hp).oper[0]^.ref^.segment)+' ');
                  case get_ref_address_size(TAICPU(hp).oper[0]^.ref^) of
                    16:
                      writer.AsmWrite('a16 ');
                    32:
                      writer.AsmWrite('a32 ');
                    64:
                      writer.AsmWrite('a64 ');
                  end;
                  writer.AsmWriteLn('xlatb');
                end
               else if is_x86_parameterized_string_op(fixed_opcode) then
                begin
                  writer.AsmWrite(#9#9);
                  i:=get_x86_string_op_si_param(fixed_opcode);
                  if (i<>-1) and (TAICPU(hp).oper[i]^.typ=top_ref) and
                     (TAICPU(hp).oper[i]^.ref^.segment<>NR_NO) and
                     (TAICPU(hp).oper[i]^.ref^.segment<>NR_DS) then
                    writer.AsmWrite(std_regname(TAICPU(hp).oper[i]^.ref^.segment)+' ');
                  for i:=0 to TAICPU(hp).ops-1 do
                    if TAICPU(hp).oper[i]^.typ=top_ref then
                      begin
                        case get_ref_address_size(TAICPU(hp).oper[i]^.ref^) of
                          16:
                            writer.AsmWrite('a16 ');
                          32:
                            writer.AsmWrite('a32 ');
                          64:
                            writer.AsmWrite('a64 ');
                        end;
                        break;
                      end;
                  writer.AsmWrite(std_op2str[fixed_opcode]);

                  case TAICPU(hp).opsize of
                    S_B:
                      writer.AsmWrite('b');
                    S_W:
                      writer.AsmWrite('w');
                    S_L:
                      writer.AsmWrite('d');
                    S_Q:
                      writer.AsmWrite('q');
                    else
                      InternalError(2017101101);
                  end;
                  writer.AsmLn;
                end
               else
                begin
                  prefix:='';

                  { We need to explicitely set
                    word prefix to get selectors
                    to be pushed in 2 bytes  PM }
                  if (TAICPU(hp).opsize=S_W) and
                     ((fixed_opcode=A_PUSH) or
                      (fixed_opcode=A_POP)) and
                      (TAICPU(hp).oper[0]^.typ=top_reg) and
                      (is_segment_reg(TAICPU(hp).oper[0]^.reg)) then
                    writer.AsmWriteln(#9#9'DB'#9'066h');

                  if (fixed_opcode=A_RETW) or (fixed_opcode=A_RETNW) or (fixed_opcode=A_RETFW) or
{$ifdef x86_64}
                     (fixed_opcode=A_RETQ) or (fixed_opcode=A_RETNQ) or (fixed_opcode=A_RETFQ) or
{$else x86_64}
                     (fixed_opcode=A_RETD) or (fixed_opcode=A_RETND) or
{$endif x86_64}
                     (fixed_opcode=A_RETFD) then
                   begin
                     case fixed_opcode of
                       A_RETW:
                         writer.AsmWrite(#9#9'o16 ret');
                       A_RETNW:
                         writer.AsmWrite(#9#9'o16 retn');
                       A_RETFW:
                         writer.AsmWrite(#9#9'o16 retf');
{$ifdef x86_64}
                       A_RETQ,
                       A_RETNQ:
                         writer.AsmWrite(#9#9'ret');
                       A_RETFQ:
                         writer.AsmWrite(#9#9'o64 retf');
{$else x86_64}
                       A_RETD:
                         writer.AsmWrite(#9#9'o32 ret');
                       A_RETND:
                         writer.AsmWrite(#9#9'o32 retn');
{$endif x86_64}
                       A_RETFD:
                         writer.AsmWrite(#9#9'o32 retf');
                       else
                         InternalError(2017111001);
                     end;
                   end
                  else if (fixed_opcode=A_SEGCS) or (fixed_opcode=A_SEGDS) or
                          (fixed_opcode=A_SEGSS) or (fixed_opcode=A_SEGES) or
                          (fixed_opcode=A_SEGFS) or (fixed_opcode=A_SEGGS) then
                    begin
                      case fixed_opcode of
                        A_SEGCS:
                          writer.AsmWrite(#9#9'cs');
                        A_SEGDS:
                          writer.AsmWrite(#9#9'ds');
                        A_SEGSS:
                          writer.AsmWrite(#9#9'ss');
                        A_SEGES:
                          writer.AsmWrite(#9#9'es');
                        A_SEGFS:
                          writer.AsmWrite(#9#9'fs');
                        A_SEGGS:
                          writer.AsmWrite(#9#9'gs');
                        else
                          InternalError(2018020101);
                      end;
                    end
                  else
                    writer.AsmWrite(#9#9+prefix+std_op2str[fixed_opcode]+cond2str[TAICPU(hp).condition]);
                  if TAICPU(hp).ops<>0 then
                   begin
                     if is_calljmp(fixed_opcode) then
                      begin
                        writer.AsmWrite(#9);
                        WriteOper_jmp(TAICPU(hp).oper[0]^,TAICPU(hp));
                      end
                     else
                      begin
                        for i:=0 to TAICPU(hp).ops-1 do
                         begin
                           if i=0 then
                            writer.AsmWrite(#9)
                           else
                            writer.AsmWrite(',');
                           WriteOper(TAICPU(hp).oper[i]^,TAICPU(hp).opsize,fixed_opcode,TAICPU(hp).ops,(i=2));
                         end;
                      end;
                   end;
                  if not SkipNewLine then
                    writer.AsmLn;
                end;
             end;

           ait_force_line,
           ait_function_name : ;

           ait_cutobject :
             begin
               if SmartAsm then
                begin
                 { only reset buffer if nothing has changed }
                 if not writer.ClearIfEmpty then
                  begin
                    if SmartAsm then
                      begin
                        WriteSmartExternals;
                        FreeExternChainList;
                      end;
                    WriteGroups;
                    writer.AsmClose;
                    DoAssemble;
                    writer.AsmCreate(TAICutObject(hp).place);
                    ResetSectionsList;
                    WriteHeader;
                  end;
               { avoid empty files }
                 LastSecType:=sec_none;
                 LastSecName:='';
                 LastAlign:=4;
                 while Assigned(hp.next) and (TAI(hp.next).typ in [ait_cutobject,ait_section,ait_comment]) do
                  begin
                    if TAI(hp.next).typ=ait_section then
                      begin
                        LastSecType:=TAISection(hp.next).sectype;
                        LastSecName:=TAISection(hp.next).name^;
                        LastAlign:=TAISection(hp.next).secalign;
                      end;
                    hp:=TAI(hp.next);
                  end;
                 if LastSecType<>sec_none then
                   WriteSection(LastSecType,LastSecName,LastAlign);
                 writer.MarkEmpty;
                 NewObject:=true;
               end;
             end;

           ait_marker :
             if TAIMarker(hp).kind=mark_NoLineInfoStart then
               inc(InlineLevel)
             else if TAIMarker(hp).kind=mark_NoLineInfoEnd then
               dec(InlineLevel);

           ait_directive :
             begin
               case TAIDirective(hp).directive of
                 asd_nasm_import,
                 asd_extern :
                   begin
                     case TAIDirective(hp).directive of
                       asd_nasm_import :
                         writer.AsmWrite('import ');
                       asd_extern :
                         writer.AsmWrite('EXTERN ');
                       else
                         InternalError(200509191);
                     end;
                     if TAIDirective(hp).name<>'' then
                       begin

                         if SmartAsm then
                           AddSymbol(TAIDirective(hp).name,false);

                         writer.AsmWrite(TAIDirective(hp).name);
                       end;
                   end;
                 asd_cpu :
                   begin
                     writer.AsmWrite('CPU ');
                     for cpu:=low(TCPUType) to high(TCPUType) do
                       begin
                         if TAIDirective(hp).name=CPUTypeStr[CPU] then
                           begin
                             writer.AsmWriteLn(nasm_cpu_name[cpu]);
                             break;
                           end;
                       end;
                   end;
                 else
                   InternalError(2005091903);
               end;
               writer.AsmLn;
             end;
           ait_seh_directive :
             { Ignore for now };
           else
             if not WriteComments(hp) then
               InternalError(2020100801);
         end;
         hp:=TAI(hp.next);
       end;
    end;


    procedure TX86NasmAssembler.WriteExternals;
      var
        sym : TAsmSymbol;
        i   : LongInt;
      begin
        for i:=0 to CurrentAsmData.AsmSymbolDict.Count-1 do
          begin
            sym:=TAsmSymbol(CurrentAsmData.AsmSymbolDict[i]);
            if sym.bind in [AB_EXTERNAL,AB_EXTERNAL_INDIRECT] then
              writer.AsmWriteln('EXTERN'#9+ApplyAsmSymbolRestrictions(sym.name));
          end;
      end;

    procedure TX86NasmAssembler.WriteSmartExternals;
      var
        EC : PExternChain;
      begin
        EC:=FEC;
        while Assigned(EC) do
          begin
            if not EC^.is_defined then
              writer.AsmWriteln('EXTERN'#9+ApplyAsmSymbolRestrictions(EC^.psym^));
            EC:=EC^.next;
          end;
      end;

    procedure TX86NasmAssembler.WriteHeader;
      begin
{$if defined(i386)}
        writer.AsmWriteLn('BITS 32');
        using_relative:=false;
{$elseif defined(x86_64)}
        writer.AsmWriteLn('BITS 64');
        writer.AsmWriteLn('default rel');
        using_relative:=true;
{$endif}
        writer.AsmWriteLn('CPU '+nasm_cpu_name[CurrentSettings.CPUType]);
      end;


    procedure TX86NasmAssembler.WriteAsmList;
    var
      hal : TAsmListType;
    begin
{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       comment(VInfo,'Start writing nasm-styled assembler output for '+CurrentModule.MainSource);
{$endif}
      ResetSectionsList;
      WriteHeader;
      writer.AsmLn;

      WriteExternals;

      for hal:=low(TAsmListType) to high(TAsmListType) do
        begin
          if not (CurrentAsmData.asmlists[hal].empty) then
            begin
              writer.AsmWriteLn(asminfo^.comment+'Begin asmlist '+AsmListTypeStr[hal]);
              writetree(CurrentAsmData.asmlists[hal]);
              writer.AsmWriteLn(asminfo^.comment+'End asmlist '+AsmListTypeStr[hal]);
            end;
        end;

      writer.AsmLn;
      if SmartAsm then
        begin
          WriteSmartExternals;
          FreeExternChainList;
        end;
      WriteGroups;
{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       comment(VInfo,'Done writing nasm-styled assembler output for '+CurrentModule.MainSource);
{$endif EXTDEBUG}
   end;

    function TX86NasmAssembler.MakeCmdLine: TCmdStr;
      var
        FormatName : string;
      begin
        result:=Inherited MakeCmdLine;

{$ifdef i386}
        case TargetInfo.system of
          system_i386_win32:
            FormatName:='win32';
          system_i386_linux:
            FormatName:='elf';
          system_i386_darwin:
            FormatName:='macho32';
        else
          FormatName:='elf';
        end;
{$endif i386}
{$ifdef x86_64}
        case TargetInfo.system of
          system_x86_64_win64:
            FormatName:='win64';
          system_x86_64_darwin:
            FormatName:='macho64';
          system_x86_64_linux:
            FormatName:='elf64';
        else
          FormatName:='elf64';
        end;
{$endif x86_64}
        Replace(result,'$FORMAT',FormatName);
      end;

{*****************************************************************************
                                  Initialize
*****************************************************************************}


{$ifdef i386}
    const
       as_i386_nasm_info : TAsmInfo =
          (
            id           : as_i386_nasm;
            idtxt  : 'NASM';
            asmbin : 'nasm';
            asmcmd : '-f $FORMAT -o $OBJ -w-orphan-labels $EXTRAOPT $ASM';
            supported_targets : [system_any];
            flags : [af_needar,af_no_debug];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );

{$endif i386}
{$ifdef x86_64}
    const
       as_x86_64_nasm_info : TAsmInfo =
          (
            id           : as_x86_64_nasm;
            idtxt  : 'NASM';
            asmbin : 'nasm';
            asmcmd : '-f $FORMAT -o $OBJ -w-orphan-labels $EXTRAOPT $ASM';
            supported_targets : [system_any];
            flags : [af_needar{,af_no_debug}];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );

       as_x86_64_nasmwin64_info : TAsmInfo =
          (
            id           : as_x86_64_nasmwin64;
            idtxt  : 'NASMWIN64';
            asmbin : 'nasm';
            asmcmd : '-f win64 -o $OBJ -w-orphan-labels $EXTRAOPT $ASM';
            supported_targets : [system_x86_64_win64];
            flags : [af_needar,af_no_debug];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );

       as_x86_64_nasmelf_info : TAsmInfo =
          (
            id           : as_x86_64_nasmelf;
            idtxt  : 'NASMELF';
            asmbin : 'nasm';
            asmcmd : '-f elf64 -o $OBJ -w-orphan-labels $EXTRAOPT $ASM';
            supported_targets : [system_x86_64_linux];
            flags : [af_needar,af_no_debug];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );


       as_x86_64_nasmdarwin_info : TAsmInfo =
          (
            id           : as_x86_64_nasmdarwin;
            idtxt  : 'NASMDARWIN';
            asmbin : 'nasm';
            asmcmd : '-f macho64 -o $OBJ -w-orphan-labels $EXTRAOPT $ASM';
            supported_targets : [system_x86_64_darwin];
            flags : [af_needar,af_no_debug];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );

{$endif x86_64}


initialization

{$ifdef i386}
  RegisterAssembler(as_i386_nasm_info,TX86NasmAssembler);
{$endif i386}
{$ifdef x86_64}
  RegisterAssembler(as_x86_64_nasm_info,TX86NasmAssembler);
  RegisterAssembler(as_x86_64_nasmwin64_info,TX86NasmAssembler);
  RegisterAssembler(as_x86_64_nasmelf_info,TX86NasmAssembler);
  RegisterAssembler(as_x86_64_nasmdarwin_info,TX86NasmAssembler);
{$endif x86_64}
end.
