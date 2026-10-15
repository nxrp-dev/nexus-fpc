{
    Copyright (c) 2003,2014 by Florian Klaempfl and Jonas Maebe

    This unit implements an asm for AArch64

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
{ This unit implements the GNU Assembler writer for AArch64
}

unit agcpugas;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,Systems,
       aasmtai,AAsmData,aasmbase,
       assemble,aggas,
       cpubase,CPUInfo;

    type
      TAArch64InstrWriter=class(TCPUInstrWriter)
        procedure WriteInstruction(hp : TAI);override;
      end;

      TAArch64Assembler=class(TGNUAssembler)
        constructor CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter, smart: boolean); override;
        function MakeCmdLine: TCmdStr; override;
      end;

      TAArch64AppleAssembler=class(TAppleGNUAssembler)
        constructor CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter, smart: boolean); override;
        function MakeCmdLine: TCmdStr; override;
      end;

      TAArch64ClangGASAssembler=class(TAArch64Assembler)
      private
        procedure TransformSEHDirectives(list:TAsmList);
      protected
        function sectionflags(secflags:TSectionFlags):string;override;
      public
        function MakeCmdLine: TCmdStr; override;
        procedure WriteAsmList; override;
      end;

    const
      gas_shiftmode2str : array[TShiftMode] of string[4] = (
        '','lsl','lsr','asr','ror',
        'uxtb','uxth','uxtw','uxtx',
        'sxtb','sxth','sxtw','sxtx');

    const
      cputype_to_gas_march : array[TCPUType] of string = (
        '', // cpu_none
        'armv8-a', // armv8 is not accepted by GNU assembler
        'armv8-a',
        'armv8.1-a',
        'armv8.2-a',
        'armv8.3-a',
        'armv8.4-a',
        'armv8.5-a',
        'armv8.6-a',
        'armv8.7-a',
        'armv8.8-a',
        'armv8.9-a'
      );

      cputype_to_clang_march : array[TCPUType] of string = (
        '', // cpu_none
        'armv8',
        'armv8-a',
        'armv8.1-a',
        'armv8.2-a',
        'armv8.3-a',
        'armv8.4-a',
        'armv8.5-a',
        'armv8.6-a',
        'armv8.7-a',
        'armv8.8-a',
        'armv8.9-a'
      );

  implementation

    uses
       CUtils,CClasses,Globals,Verbose,
       aasmcpu,
       itcpugas,
       cgbase,cgutils;


    function GetmarchStr : String;
      var
        cf: TCPUFlags;
      begin
        Result:='-march='+cputype_to_gas_march[CurrentSettings.CPUType];
        for cf in cpu_capabilities[CurrentSettings.CPUType] do
          begin
            case cf of
              CPUAARCH64_HAS_DOTPROD:
                Result:=Result+'+dotprod';
              CPUAARCH64_HAS_AES:
                Result:=Result+'+aes';
              CPUAARCH64_HAS_SHA2:
                Result:=Result+'+sha2';
              CPUAARCH64_HAS_SHA3:
                Result:=Result+'+sha3';
              CPUAARCH64_HAS_SM4:
                Result:=Result+'+sm4';
              CPUAARCH64_HAS_CRYPTO:
                Result:=Result+'+crypto';
              CPUAARCH64_HAS_MEMTAG:
                Result:=Result+'+memtag';
              CPUAARCH64_HAS_PAUTH:
                { currently, clang on aarch64-darwin does not support pauth and as
                  it is actually part of -march==armv8.4-a (and higher) we actually don't need it,
                  so ignore it at this point }
                if not(CurrentSettings.CPUType>=cpu_armv84a) then
                  Result:=Result+'+pauth';
              CPUAARCH64_HAS_TME:
                Result:=Result+'+tme';
              CPUAARCH64_HAS_PROFILE:
                Result:=Result+'+profile';
              CPUAARCH64_HAS_CSSC:
                Result:=Result+'+cssc';
              else
                ;
            end
          end;
      end;

{****************************************************************************}
{                      AArch64 Assembler writer                              }
{****************************************************************************}

    constructor TAArch64Assembler.CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter, smart: boolean);
      begin
        inherited;
        InstrWriter := TAArch64InstrWriter.create(self);
      end;

    function TAArch64Assembler.MakeCmdLine: TCmdStr;
      begin
        result:=inherited MakeCmdLine;
        if cputype_to_gas_march[CurrentSettings.CPUType] <> '' then
          Replace(result,'$MARCHOPT',GetmarchStr)
        else
          Replace(result,'$MARCHOPT','');
      end;

{****************************************************************************}
{                      Apple AArch64 Assembler writer                        }
{****************************************************************************}

    constructor TAArch64AppleAssembler.CreateWithWriter(info: PAsmInfo; wr: TExternalAssemblerOutputFile; freewriter, smart: boolean);
      begin
        inherited;
        InstrWriter := TAArch64InstrWriter.create(self);
      end;


    function TAArch64AppleAssembler.MakeCmdLine: TCmdStr;
      begin
        result:=inherited MakeCmdLine;
        if cputype_to_gas_march[CurrentSettings.CPUType] <> '' then
          Replace(result,'$MARCHOPT',GetmarchStr)
        else
          Replace(result,'$MARCHOPT','');
      end;

{****************************************************************************}
{                      CLang AArch64 Assembler writer                        }
{****************************************************************************}

    function TAArch64ClangGASAssembler.MakeCmdLine: TCmdStr;
      begin
        result:=inherited MakeCmdLine;
      end;

    procedure TAArch64ClangGASAssembler.TransformSEHDirectives(list:TAsmList);

      function convert_unwinddata(list:TAsmList):TDynamicArray;

        procedure check_offset(ofs,max:dword);
          begin
            if ((ofs and $7)<>0) or (ofs>max) then
              InternalError(2020041210);
          end;

        procedure check_reg(reg:TRegister;rt:TRegisterType;min:TSuperRegister);
          begin
            if (getregtype(reg)<>rt) or (getsupreg(reg)<min) then
              InternalError(2020041211);
          end;

        procedure writebyte(b:byte); inline;
          begin
            result.write(b,sizeof(b));
          end;

        procedure writeword(w:word);
          begin
            w:=NtoBE(w);
            result.write(w,sizeof(w));
          end;

        procedure writedword(dw:dword);
          begin
            dw:=NtoBE(dw);
            result.write(dw,sizeof(dw));
          end;

        const
          min_int_reg = 19;
          min_mm_reg = 8;
        var
          hp : TAI;
          seh : TAISEHDirective absolute hp;
        begin
          result:=TDynamicArray.create(0);
          hp:=TAI(list.last);
          while Assigned(hp) do
            begin
              if hp.typ<>ait_seh_directive then
                InternalError(2020041502);
              case seh.kind of
                ash_stackalloc:
                  begin
                    if (seh.data.offset and $f)<>0 then
                      InternalError(2020041207);
                    if seh.data.offset<((1 shl 5)*16) then
                      writebyte(byte(seh.data.offset shr 4))
                    else if seh.data.offset<((1 shl 11)*16) then
                      writeword($C000 or word(seh.data.offset shr 4))
                    else if seh.data.offset<((1 shl 24)*16) then
                      writedword($E0000000 or (seh.data.offset shr 4))
                    else begin
                      WriteLn(HexStr(seh.data.offset,8));
                      InternalError(2020041209);
                    end;
                  end;
                ash_addfp:
                  begin
                    check_offset(seh.data.offset,(1 shl 7)*8);
                    writeword($E200 or (seh.data.offset shr 3));
                  end;
                ash_setfp:
                  writebyte($E1);
                ash_nop:
                  writebyte($E3);
                ash_savefplr:
                  begin
                    check_offset(seh.data.offset,504);
                    writebyte($40 or (seh.data.offset shr 3));
                  end;
                ash_savefplr_x:
                  begin
                    check_offset(seh.data.offset,512);
                    writebyte($80 or (seh.data.offset shr 3)-1);
                  end;
                ash_savereg:
                  begin
                    check_offset(seh.data.offset,504);
                    check_reg(seh.data.reg,R_INTREGISTER,min_int_reg);
                    writeword($D000 or ((getsupreg(seh.data.reg)-min_int_reg) shl 6) or (seh.data.offset shr 3));
                  end;
                ash_savereg_x:
                  begin
                    check_offset(seh.data.offset,256);
                    check_reg(seh.data.reg,R_INTREGISTER,min_int_reg);
                    writeword($D400 or ((getsupreg(seh.data.reg)-min_int_reg) shl 5) or ((seh.data.offset shr 3)-1));
                  end;
                ash_saveregp:
                  begin
                    check_offset(seh.data.offset,504);
                    check_reg(seh.data.reg,R_INTREGISTER,min_int_reg);
                    writeword($C800 or ((getsupreg(seh.data.reg)-min_int_reg) shl 6) or (seh.data.offset shr 3));
                  end;
                ash_saveregp_x:
                  begin
                    check_offset(seh.data.offset,512);
                    check_reg(seh.data.reg,R_INTREGISTER,min_int_reg);
                    writeword($CC00 or ((getsupreg(seh.data.reg)-min_int_reg) shl 6) or ((seh.data.offset shr 3)-1));
                  end;
                ash_savefreg:
                  begin
                    check_offset(seh.data.offset,504);
                    check_reg(seh.data.reg,R_MMREGISTER,min_mm_reg);
                    writeword($DC00 or ((getsupreg(seh.data.reg)-min_mm_reg) shl 6) or (seh.data.offset shr 3));
                  end;
                ash_savefreg_x:
                  begin
                    check_offset(seh.data.offset,256);
                    check_reg(seh.data.reg,R_MMREGISTER,min_mm_reg);
                    writeword($DE00 or ((getsupreg(seh.data.reg)-min_mm_reg) shl 5) or ((seh.data.offset shr 3)-1));
                  end;
                ash_savefregp:
                  begin
                    check_offset(seh.data.offset,504);
                    check_reg(seh.data.reg,R_MMREGISTER,min_mm_reg);
                    writeword($D800 or ((getsupreg(seh.data.reg)-min_mm_reg) shl 6) or (seh.data.offset shr 3));
                  end;
                ash_savefregp_x:
                  begin
                    check_offset(seh.data.offset,512);
                    check_reg(seh.data.reg,R_MMREGISTER,min_mm_reg);
                    writeword($DA00 or ((getsupreg(seh.data.reg)-min_mm_reg) shl 6) or ((seh.data.offset shr 3)-1));
                  end;
                else
                  InternalError(2020041503);
              end;
              hp:=TAI(hp.previous);
            end;
        end;

      var
        unwinddata : TDynamicArray;

      procedure writebyte(b:byte);
        begin
          unwinddata.write(b,sizeof(b));
        end;

      var
        hp,hpnext,hpdata : TAI;
        seh : TAISEHDirective absolute hp;
        LastSym : TAISymbol;
        lastsec : TAISection;
        inprologue,
        smartunwind,
        deleteai : boolean;
        totalcount,
        instrcount,
        datacount : sizeint;
        handlername : TSymStr;
        handlerflags : byte;
        handlerdata : array of TAI;
        handlerdataidx : sizeint;
        handlerdatacount : TAI;
        sehlist,
        tmplist : TAsmList;
        pdatasection,
        xdatasection : TAISection;
        xdatasym : TAsmSymbol;
        leaderinfo : TGNUWin64ComdatInfo;
        unwindrec : LongWord;
      begin
        if not Assigned(list) then
          exit;

        LastSym:=nil;
        tmplist:=nil;
        sehlist:=nil;
        lastsec:=nil;
        instrcount:=0;
        datacount:=0;
        unwinddata:=nil;
        inprologue:=false;
        handlerdata:=nil;
        handlerdataidx:=0;
        handlerdatacount:=nil;
        handlerflags:=0;
        handlername:='';

        hp:=TAI(list.first);
        while Assigned(hp) do
          begin
            deleteai:=false;
            case hp.typ of
              ait_section:
                begin
                  if Assigned(sehlist) then
                    begin
                      if Assigned(lastsec) and (TAISection(hp).name^=lastsec.name^) then
                        begin
                          { this section was only added due to the now removed SEH data }
                          deleteai:=true;
                          dec(list.section_count);
                        end
                      else
                        InternalError(2020041214);
                    end
                  else
                    begin
                      lastsec:=TAISection(hp);
                      { also reset the last encountered symbol }
                      LastSym:=nil;
                    end;

                  if Assigned(tmplist) then
                    begin
                      list.InsertListBefore(hp,tmplist);
                      tmplist.free;
                      tmplist:=nil;
                    end;

                end;
              ait_symbol:
                begin
                  if TAISymbol(hp).sym.typ=AT_FUNCTION then
                    LastSym:=TAISymbol(hp);
                end;
              ait_instruction:
                if Assigned(sehlist) then
                  inc(instrcount);
              ait_const:
                if Assigned(sehlist) then
                  inc(datacount,TAIConst(hp).size);
              ait_seh_directive:
                begin
                  if not Assigned(sehlist) and (seh.kind<>ash_proc) then
                    InternalError(2020041208);
                  { most seh directives are removed }
                  deleteai:=true;
                  case seh.kind of
                    ash_proc:
                      begin
                        if not Assigned(lastsec) then
                          InternalError(2020041203);
                        datacount:=0;
                        instrcount:=0;
                        handlerflags:=0;
                        handlername:='';
                        sehlist:=TAsmList.create;
                        inprologue:=true;
                      end;
                    ash_endproc:
                      begin
                        if not Assigned(sehlist) then
                          InternalError(2020041501);
                        if Assigned(tmplist) then
                          InternalError(2020041302);
                        if not Assigned(LastSym) then
                          InternalError(2020041303);
                        if inprologue then
                          CGMessage(asmw_e_missing_endprologue);

                        { only generate xdata and pdata if we have any
                          prologue or a handler is set }
                        unwinddata:=convert_unwinddata(sehlist);

                        if unwinddata.size>0 then
                          begin
                            writebyte($E4);

                            { fill up with NOPs }
                            while unwinddata.size mod 4<>0 do
                              writebyte($E3);
                          end;

                        if (handlerflags<>0) or (unwinddata.size<>0) then
                          begin
                            { note: we can pass Nil here, because in case of a LLVM
                                    backend this whole code shouldn't be required
                                    anyway }
                            xdatasym:=CurrentAsmData.DefineAsmSymbol('xdata_'+LastSym.sym.name,AB_LOCAL,AT_DATA,nil);

                            tmplist:=TAsmList.create;
                            pdatasection:=new_section(tmplist,sec_pdata,lastsec.name^,0);
                            tmplist.concat(TAIConst.Create_rva_sym(LastSym.sym));
                            tmplist.concat(TAIConst.Create_rva_sym(xdatasym));

                            smartunwind:=IsWin64SmartSection(lastsec.sectype,lastsec.name^);
                            if create_smartlink_sections then
                              xdatasection:=new_section(tmplist,sec_user,'.xdata$N_'+lower(LastSym.sym.name),sizeof(int32))
                            else
                              xdatasection:=new_section(tmplist,sec_user,'.xdata',sizeof(int32));
                            xdatasection.secflags:=[SF_A];
                            xdatasection.secprogbits:=SPB_None;
                            tmplist.concat(TAISymbol.Create(xdatasym,0));

                            if smartunwind then
                              begin
                                leaderinfo:=EnsureWin64ComdatLeader(sectionname(lastsec.sectype,lastsec.name^,lastsec.secorder));
                                RegisterWin64AssociativeComdat(sectionname(pdatasection.sectype,pdatasection.name^,pdatasection.secorder),leaderinfo.Key);
                                RegisterWin64AssociativeComdat(sectionname(xdatasection.sectype,xdatasection.name^,xdatasection.secorder),leaderinfo.Key);
                              end;

                            tmplist.concat(TAIComment.Create(StrPNew('instr: '+ToStr(instrcount)+', data: '+ToStr(datacount)+', unwind: '+ToStr(unwinddata.size))));

                            {$ifdef EXTDEBUG}
                            comment(VDebug,'got section: '+lastsec.name^);
                            comment(VDebug,'got instructions: '+ToStr(instrcount));
                            comment(VDebug,'got data: '+ToStr(datacount));
                            comment(VDebug,'got unwinddata: '+ToStr(unwinddata.size));
                            {$endif EXTDEBUG}

                            if datacount mod 4<>0 then
                              CGMessage(asmw_e_seh_invalid_data_size);

                            totalcount:=datacount div 4+instrcount;

                            { splitting to multiple pdata/xdata sections is not yet
                              supported, so 1 MB is our limit for now }
                            if totalcount>(1 shl 18) then
                              comment(VError,'Function is larger than 1 MB which is not supported for SEH currently');

                            unwindrec:=min(totalcount,(1 shl 18)-1);
                            { ARM64 xdata header format:
                              bits 0-17:  Function length / 4
                              bits 18-19: Version (must be 0)
                              bit 20:     X - exception data present
                              bit 21:     E - single epilog packed in header
                              bits 22-26: Epilog count (if E=0) or epilog start index (if E=1)
                              bits 27-31: Code words count }
                            if handlerflags<>0 then
                              unwindrec:=unwindrec or (1 shl 20);  { X bit - exception data present }

                            unwindrec:=unwindrec or (1 shl 21);  { E bit - single epilog }
                            { the epilog start index stays 0: the epilog is the exact
                              mirror of the prolog, so the same unwind codes describe
                              both from the start of the array. The field is a byte
                              index, so a hardcoded 1 addressed the second byte of the
                              first code as soon as that code was longer than one byte }

                            if unwinddata.size div 4<=31 then
                              unwindrec:=unwindrec or ((unwinddata.size div 4) shl 27);  { code_words in bits 27-31 }

                            { exception record headers }
                            tmplist.concat(TAIConst.Create_32bit(LongInt(unwindrec)));
                            if cs_asm_source in InitSettings.GlobalSwitches then
                              tmplist.concat(TAIComment.create(StrPNew(HexStr(unwindrec,8))));

                            if unwinddata.size div 4>31 then
                              begin
                                { once we're able to split a .pdata entry this can be
                                  removed as well }
                                if unwinddata.size div 4>255 then
                                  comment(VError,'Too many unwind codes for SEH');
                                unwindrec:=(unwinddata.size div 4) shl 16;
                                tmplist.concat(TAIConst.create_32bit(LongInt(unwindrec)));
                                if cs_asm_source in InitSettings.GlobalSwitches then
                                  tmplist.concat(TAIComment.create(StrPNew(HexStr(unwindrec,8))));
                              end;

                            { unwind codes }
                            unwinddata.seek(0);
                            while unwinddata.pos<unwinddata.size do
                              begin
                                unwinddata.read(unwindrec,sizeof(LongWord));
                                tmplist.concat(TAIConst.Create_32bit(LongInt(unwindrec)));
                                if cs_asm_source in InitSettings.GlobalSwitches then
                                  tmplist.concat(TAIComment.create(StrPNew(HexStr(unwindrec,8))));
                              end;

                            if handlerflags<>0 then
                              begin
                                tmplist.concat(TAIConst.Create_rva_sym(CurrentAsmData.RefAsmSymbol(handlername,AT_FUNCTION,false)));
                                if length(handlerdata)>0 then
                                  begin
                                    tmplist.concat(handlerdatacount);
                                    for handlerdataidx:=0 to high(handlerdata) do
                                      tmplist.concat(handlerdata[handlerdataidx]);
                                  end;
                              end;

                            handlerdata:=nil;
                          end;

                        unwinddata.free;

                        sehlist.free;
                        sehlist:=nil;
                      end;
                    ash_endprologue:
                      inprologue:=false;
                    ash_handler:
                      begin
                        handlername:=seh.data.name^;
                        handlerflags:=seh.data.flags;
                      end;
                    ash_handlerdata:
                      begin
                        if handlername='' then
                          CGMessage(asmw_e_handlerdata_no_handler);
                        hpdata:=TAI(hp.next);
                        if not Assigned(hpdata) or (hpdata.typ<>ait_const) or (TAIConst(hpdata).consttype<>aitconst_32bit) then
                          InternalError(2020041215);
                        handlerdatacount:=hpdata;
                        SetLength(handlerdata,TAIConst(hpdata).value*4);
                        handlerdataidx:=0;
                        hpnext:=TAI(hpdata.next);
                        list.remove(hpdata);
                        hpdata:=hpnext;
                        while (handlerdataidx<length(handlerdata)) and Assigned(hpdata) do
                          begin
                            if (hpdata.typ<>ait_const) or not (TAIConst(hpdata).consttype in [aitconst_32bit,aitconst_rva_symbol]) then
                              InternalError(2020041212);
                            handlerdata[handlerdataidx]:=hpdata;
                            inc(handlerdataidx);
                            hpnext:=TAI(hpdata.next);
                            list.remove(hpdata);
                            hpdata:=hpnext;
                          end;
                        if handlerdataidx<length(handlerdata) then
                          InternalError(2020041213);
                      end;
                    ash_stackalloc,
                    ash_addfp,
                    ash_setfp,
                    ash_nop,
                    ash_savefplr,
                    ash_savefplr_x,
                    ash_savereg,
                    ash_savereg_x,
                    ash_saveregp,
                    ash_saveregp_x,
                    ash_savefreg,
                    ash_savefreg_x,
                    ash_savefregp,
                    ash_savefregp_x:
                      begin
                        if not Assigned(sehlist) then
                          InternalError(2020041504);
                        if not inprologue then
                          InternalError(2020041505);
                        hpdata:=hp;
                        hp:=TAI(hp.previous);
                        list.Remove(hpdata);
                        sehlist.concat(hpdata);
                        { don't delete this }
                        deleteai:=false;
                      end;
                    else
                      InternalError(2020041206);
                  end;
                end;
              else
                { ignore }
                ;
            end;

            if deleteai then
              begin
                hpnext:=TAI(hp.next);
                list.remove(hp);
                hp.free;
                hp:=hpnext;
              end
            else
              hp:=TAI(hp.next);
          end;

        if Assigned(sehlist) then
          InternalError(2020041205);

        if Assigned(tmplist) then
          begin
            list.ConcatList(tmplist);
            tmplist.free;
          end;
      end;


    function TAArch64ClangGASAssembler.sectionflags(secflags:TSectionFlags):string;
      begin
        Result:=inherited sectionflags(secflags);
        if (TargetInfo.system=system_aarch64_win64) then
          begin
            { we require an explicit "r" if write is not allowed }
            if not (SF_W in secflags) then
              result:=result+'r';
          end;
      end;


    procedure TAArch64ClangGASAssembler.WriteAsmList;
      begin
        { clang does not support all the directives we need, so we need to
          manually transform them to pdata/xdata records }
        if TargetInfo.system=system_aarch64_win64 then
          begin
            TransformSEHDirectives(CurrentAsmData.AsmLists[al_pure_assembler]);
            TransformSEHDirectives(CurrentAsmData.AsmLists[al_procedures]);
          end;
        inherited WriteAsmList;
      end;


{****************************************************************************}
{                  Helper routines for Instruction Writer                    }
{****************************************************************************}

    function getreferencestring(asminfo: PAsmInfo; var ref : TReference) : string;
      const
        darwin_addrpage2str: array[addr_page..addr_gotpageoffset] of string[11] =
           ('@PAGE','@PAGEOFF','@GOTPAGE','@GOTPAGEOFF');
        linux_addrpage2str: array[addr_page..addr_gotpageoffset] of string[10] =
           ('',':lo12:',':got:',':got_lo12:');
      begin
        if ref.base=NR_NO then
          begin
            case ref.refaddr of
              addr_gotpage,
              addr_page,
              addr_gotpageoffset,
              addr_pageoffset:
                begin
                  if not Assigned(ref.symbol) or
                     (ref.base<>NR_NO) or
                     (ref.index<>NR_NO) or
                     (ref.shiftmode<>SM_None) or
                     (ref.offset<>0) then
                    InternalError(2014121501);
                  if TargetInfo.system in systems_darwin then
                    result:=ref.symbol.name+darwin_addrpage2str[ref.refaddr]
                  else
                    result:=linux_addrpage2str[ref.refaddr]+ref.symbol.name
                end;
              addr_pic,
              { for locals replaced by temp symbols on LLVM }
              addr_no:
                result:=ref.symbol.name;
              else
                InternalError(2015022302);
            end
          end
        else
          begin
            result:='['+gas_regname(ref.base);
            if ref.addressmode=AM_POSTINDEXED then
              result:=result+']';
            if ref.index<>NR_NO then
              begin
                if (ref.offset<>0) or
                   Assigned(ref.symbol) then
                  InternalError(2014121504);
                result:=result+', '+gas_regname(ref.index);
                case ref.shiftmode of
                  SM_None: ;
                  SM_LSL,
                  SM_UXTW, SM_UXTX, SM_SXTW, SM_SXTX:
                    begin
                      result:=result+', '+gas_shiftmode2str[ref.shiftmode];
                      if (ref.shiftmode=SM_LSL) or
                         (ref.shiftimm<>0) then
                        result:=result+' #'+ToStr(ref.shiftimm);
                    end
                  else
                    InternalError(2014121505);
                end;
              end
            else
              begin
                if Assigned(ref.symbol) then
                  begin
                    case ref.refaddr of
                      addr_gotpageoffset,
                      addr_pageoffset:
                        begin
                          if TargetInfo.system in systems_darwin then
                            result:=result+', '+ref.symbol.name+darwin_addrpage2str[ref.refaddr]
                          else
                            result:=result+', '+linux_addrpage2str[ref.refaddr]+ref.symbol.name
                        end
                      else
                        { todo: not yet generated/don't know syntax }
                        InternalError(2014121506);
                    end;
                  end
                else
                  begin
                    if ref.refaddr<>addr_no then
                      InternalError(2014121502);
                    if (ref.offset<>0) then
                      result:=result+', #'+ToStr(ref.offset);
                  end;
              end;
            case ref.addressmode of
              AM_OFFSET:
                result:=result+']';
              AM_PREINDEXED:
                result:=result+']!';
              else
                ;
            end;
          end;
      end;


    function getopstr(asminfo: PAsmInfo; hp: TAICPU; opnr: LongInt; const o: TOper): string;
      var
        i: LongInt;
        reg: TRegister;
      begin
        case o.typ of
          top_reg:
            getopstr:=gas_regname(o.reg);
          top_shifterop:
            begin
              getopstr:=gas_shiftmode2str[o.shifterop^.shiftmode];
              if o.shifterop^.shiftimm<>0 then
                getopstr:=getopstr+' #'+ToStr(o.shifterop^.shiftimm)
            end;
          top_const:
            if o.val>=0 then
              getopstr:='#'+ToStr(o.val)
            else
              getopstr:='#0x'+HexStr(o.val,16);
          top_conditioncode:
            getopstr:=cond2str[o.cc];
          top_ref:
            if is_calljmp(hp.opcode) then
              begin
                if o.ref^.refaddr<>addr_full then
                  InternalError(2014122220);
                if not Assigned(o.ref^.symbol) or
                   Assigned(o.ref^.relsymbol) or
                   (o.ref^.base<>NR_NO) or
                   (o.ref^.index<>NR_NO) or
                   (o.ref^.offset<>0) then
                  InternalError(2014122221);
                getopstr:=o.ref^.symbol.name;
              end
            else
              getopstr:=getreferencestring(asminfo,o.ref^);
          top_realconst:
            begin
              Result:=RealToStr(o.val_real);
              Result:='#'+Result;
            end;
          top_regset:
            begin
              reg:=o.basereg;
              result:='{'+gas_regname(reg);
              for i:=1 to o.nregs-1 do
                begin
                  setsupreg(reg,succ(getsupreg(reg)) mod 32);
                  result:=result+', '+gas_regname(reg);
                end;
              result:=result+'}';
              if o.regsetindex<>255 then
                result:=result+'['+ToStr(o.regsetindex)+']'
            end;
          top_indexedreg:
            begin
              result:=gas_regname(o.indexedreg)+'['+ToStr(o.regindex)+']';
            end;
          else
            InternalError(2014121507);
        end;
      end;


    procedure TAArch64InstrWriter.WriteInstruction(hp : TAI);
      var
        op: TAsmOp;
        s: string;
        i: byte;
        sep: string[3];
      begin
        op:=TAICPU(hp).opcode;
        s:=#9+gas_op2str[op]+oppostfix2str[TAICPU(hp).oppostfix];
        if TAICPU(hp).condition<>C_NONE then
          s:=s+'.'+cond2str[TAICPU(hp).condition];
        if TAICPU(hp).ops<>0 then
          begin
            sep:=#9;
            for i:=0 to TAICPU(hp).ops-1 do
              begin
                 // debug code
                 // writeln(s);
                 // writeln(taicpu(hp).fileinfo.line);
                 s:=s+sep+getopstr(owner.asminfo,TAICPU(hp),i,TAICPU(hp).oper[i]^);
                 sep:=',';
              end;
          end;
        owner.writer.AsmWriteLn(s);
      end;


    const
       as_aarch64_clang_darwin_info : TAsmInfo =
          (
            id     : as_clang_asdarwin;
            idtxt  : 'CLANG';
            asmbin : 'clang';
            asmcmd : '-x assembler -c -target $TRIPLET -o $OBJ $MARCHOPT $EXTRAOPT -x assembler $ASM';
            supported_targets : [system_aarch64_ios,system_aarch64_darwin,system_aarch64_iphonesim];
            flags : [af_needar,af_smartlink_sections,af_supports_dwarf,af_llvm,af_supports_hlcfi];
            labelprefix : 'L';
            labelmaxlen : -1;
            comment : '# ';
            dollarsign: '$';
          );

       as_aarch64_clang_gas_info : TAsmInfo =
          (
            id     : as_clang_gas;
            idtxt  : 'AS-CLANG';
            asmbin : 'clang';
            asmcmd : '-x assembler -c -target $TRIPLET -o $OBJ $MARCHOPT $EXTRAOPT -x assembler $ASM';
            supported_targets : [system_aarch64_linux,system_aarch64_android,system_aarch64_win64];
            flags : [af_needar,af_smartlink_sections,af_supports_dwarf,af_llvm,af_supports_hlcfi];
            labelprefix : '.L';
            labelmaxlen : -1;
            comment : '// ';
            dollarsign: '$';
          );



begin
  RegisterAssembler(as_aarch64_clang_darwin_info,TAArch64AppleAssembler);
  RegisterAssembler(as_aarch64_clang_gas_info,TAArch64ClangGASAssembler);
end.
