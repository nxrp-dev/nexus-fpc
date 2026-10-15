{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements an asmoutput class for Intel syntax with Intel i386+

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
{
  This unit implements an asmoutput class for Intel syntax with Intel i386+
}
unit agx86int;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      cpubase,ConstExp,
      aasmbase,aasmtai,AAsmData,aasmcpu,assemble,cgutils;

    type
      Tx86IntelAssembler = class(TExternalAssembler)
      private
        procedure WriteReference(var ref : TReference);
        procedure WriteOper(const o:TOper;s : TOpSize; opcode: TAsmOp;dest : boolean);
        procedure WriteOper_jmp(const o:TOper;s : TOpSize);
      public
        function single2str(d : single) : string; override;
        function double2str(d : double) : string; override;
        procedure WriteTree(p:TAsmList);override;
        procedure WriteAsmList;override;
        procedure WriteExternals;
      end;


implementation

    uses
      SysUtils,
      CUtils,GlobType,Globals,Systems,CClasses,
      Verbose,CScript,
      itx86int,
      cgbase
{$ifdef EXTDEBUG}
      ,FModule
{$endif EXTDEBUG}
      ;

    const
      line_length = 70;
      max_tokens : LongInt = 25;
      secnames : array[TAsmSectiontype] of string[4] = ('','',
        'CODE','DATA','DATA','DATA','BSS','TLS',
        '','','','','','',
        '','',
        '',
        '',
        '',
        '',
        '',
        '','','','','','',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      );

      secnamesml64 : array[TAsmSectiontype] of string[7] = ('','',
        '_TEXT','_DATA','_DATA','_DATA','_BSS','_TLS',
        '','','','',
        '','','idata$2','idata$4','idata$5','idata$6','idata$7','edata',
        '',
        '',
        '',
        '',
        '',
        '','','','','','',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      );

    function TX86IntelAssembler.single2str(d : single) : string;
      var
         hs : string;
         p : byte;
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

    function TX86IntelAssembler.double2str(d : double) : string;
      var
         hs : string;
         p : byte;
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




    { MASM supports aligns up to 8192 }
    function alignstr(b : LongInt) : string;
      begin
        case b of
          1: result:='BYTE';
          2: result:='WORD';
          4: result:='DWORD';
          0,
          16: result:='PARA';
          256: result:='PAGE';
        else
          result:='ALIGN('+ToStr(b)+')';
        end;
      end;

{****************************************************************************
                               tx86IntelAssembler
 ****************************************************************************}

    procedure tx86IntelAssembler.WriteReference(var ref : TReference);
      var
        first : boolean;
      begin
        with ref do
         begin
           first:=true;
           if segment<>NR_NO then
            writer.AsmWrite(masm_regname(segment)+':[')
           else
            writer.AsmWrite('[');
           if Assigned(symbol) then
            begin
              writer.AsmWrite(ApplyAsmSymbolRestrictions(symbol.name));
              first:=false;
            end;
           if (base<>NR_NO) then
            begin
              if not(first) then
               writer.AsmWrite('+')
              else
               first:=false;
{$ifdef x86_64}
              { ml64 needs [$+foo] instead of [rip+foo] }
              if (base=NR_RIP) and (asminfo^.id=as_x86_64_masm) then
               writer.AsmWrite('$')
              else
{$endif x86_64}
               writer.AsmWrite(masm_regname(base));
            end;
           if (index<>NR_NO) then
            begin
              if not(first) then
               writer.AsmWrite('+')
              else
               first:=false;
              writer.AsmWrite(masm_regname(index));
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


    procedure tx86IntelAssembler.WriteOper(const o:TOper;s : TOpSize; opcode: TAsmOp;dest : boolean);
      begin
        case o.typ of
          top_reg :
            writer.AsmWrite(masm_regname(o.reg));
          top_const :
            writer.AsmWrite(ToStr(o.val));
          top_ref :
            begin
              if o.ref^.refaddr in [addr_no,addr_pic,addr_pic_no_got] then
                begin
                  if ((opcode <> A_LGS) and (opcode <> A_LSS) and
                      (opcode <> A_LFS)
{$ifndef x86_64}
                      and (opcode <> A_LDS) and (opcode <> A_LES)
{$endif x86_64}
                      ) then
                   Begin
                     case s of
                      S_B : writer.AsmWrite('byte ptr ');
                      S_W : writer.AsmWrite('word ptr ');
                      S_L : writer.AsmWrite('dword ptr ');
                      S_Q : writer.AsmWrite('qword ptr ');
                     S_IS : writer.AsmWrite('word ptr ');
                     S_IL : writer.AsmWrite('dword ptr ');
                     S_IQ : writer.AsmWrite('qword ptr ');
                     S_FS : writer.AsmWrite('dword ptr ');
                     S_FL : writer.AsmWrite('qword ptr ');
                     S_T,
                     S_FX : writer.AsmWrite('tbyte ptr ');
                     S_BW : if dest then
                             writer.AsmWrite('word ptr ')
                            else
                             writer.AsmWrite('byte ptr ');
                     S_BL : if dest then
                             writer.AsmWrite('dword ptr ')
                            else
                             writer.AsmWrite('byte ptr ');
                     S_WL : if dest then
                             writer.AsmWrite('dword ptr ')
                            else
                             writer.AsmWrite('word ptr ');
                     S_XMM: writer.AsmWrite('xmmword ptr ');
                     S_YMM: writer.AsmWrite('ymmword ptr ');
                     S_ZMM: writer.AsmWrite('zmmword ptr ');
{$ifdef x86_64}
                     S_BQ : if dest then
                             writer.AsmWrite('qword ptr ')
                            else
                             writer.AsmWrite('byte ptr ');
                     S_WQ : if dest then
                             writer.AsmWrite('qword ptr ')
                            else
                             writer.AsmWrite('word ptr ');
                     S_LQ : if dest then
                             writer.AsmWrite('qword ptr ')
                            else
                             writer.AsmWrite('dword ptr ');

{$endif x86_64}
                     else
                       ;
                     end;
                   end;
                  WriteReference(o.ref^);
                end
              else
                begin
                  writer.AsmWrite('offset ');
                  if Assigned(o.ref^.symbol) then
                    writer.AsmWrite(ApplyAsmSymbolRestrictions(o.ref^.symbol.name));
                  if o.ref^.offset>0 then
                   writer.AsmWrite('+'+ToStr(o.ref^.offset))
                  else
                   if o.ref^.offset<0 then
                    writer.AsmWrite(ToStr(o.ref^.offset))
                  else
                   if not(Assigned(o.ref^.symbol)) then
                     writer.AsmWrite('0');
                end;
            end;
          else
            InternalError(2005060510);
        end;
      end;


    procedure tx86IntelAssembler.WriteOper_jmp(const o:TOper;s : TOpSize);
    begin
      case o.typ of
        top_reg :
          writer.AsmWrite(masm_regname(o.reg));
        top_const :
          writer.AsmWrite(ToStr(o.val));
        top_ref :
          { what about lcall or ljmp ??? }
          begin
            if o.ref^.refaddr=addr_no then
              begin
                if s=S_FAR then
                  writer.AsmWrite('far ptr ')
                else
{$ifdef x86_64}
                  writer.AsmWrite('qword ptr ');
{$else x86_64}
                  writer.AsmWrite('dword ptr ');
{$endif x86_64}
                WriteReference(o.ref^);
              end
            else
              begin
                writer.AsmWrite(ApplyAsmSymbolRestrictions(o.ref^.symbol.name));
                if o.ref^.offset>0 then
                 writer.AsmWrite('+'+ToStr(o.ref^.offset))
                else
                 if o.ref^.offset<0 then
                  writer.AsmWrite(ToStr(o.ref^.offset));
              end;
          end;
        else
          InternalError(2005060511);
      end;
    end;

    const
      ait_const2str : array[aitconst_128bit..aitconst_64bit_unaligned] of string[20]=(
        #9''#9,#9'DQ'#9,#9'DD'#9,#9'DW'#9,#9'DB'#9,
        #9'FIXMESLEB',#9'FIXEMEULEB',
        #9'DD RVA'#9,#9'DD SECREL32'#9,
        #9'FIXME',#9'FIXME',#9'FIXME',#9'FIXME',
        #9'DW'#9,#9'DD'#9,#9'DQ'#9
      );

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

    procedure tx86IntelAssembler.WriteTree(p:TAsmList);
    var
      s,
      prefix,
      suffix   : string;
      hp   : TAI;
      counter,
      lines, tokens,
      InlineLevel : LongInt;
      i,j,l    : LongInt;
      consttype : TAIConstType;
      do_line,DoNotSplitLine,
      quoted   : boolean;
      fixed_opcode: TAsmOp;
    begin
      if not Assigned(p) then
       exit;
      { lineinfo is only needed for al_procedures (PFV) }
      do_line:=((cs_asm_source in CurrentSettings.GlobalSwitches) or
                (cs_lineinfo in CurrentSettings.ModuleSwitches))
                 and (p=CurrentAsmData.asmlists[al_procedures]);
      InlineLevel:=0;
      DoNotSplitLine:=false;
      hp:=TAI(p.first);
      while Assigned(hp) do
       begin
         prefetch(pointer(hp.next)^);
         if not(hp.typ in SkipLineInfo) then
          begin
            CurrentFilePos:=TAILineInfo(hp).fileinfo;
            { no line info for inlined code }
            if do_line and (inlinelevel=0) and not DoNotSplitLine then
              WriteSourceLine(hp as TAILineInfo);
          end;
         DoNotSplitLine:=false;

         case hp.typ of
           ait_section :
             begin
               ResetSourceLines;

               if TAISection(hp).sectype<>sec_none then
                begin
                  if asminfo^.id=as_x86_64_masm then
                    begin
                      if LasTSecType<>sec_none then
                        writer.AsmWriteLn(secnamesml64[LasTSecType]+#9#9'ENDS');
                      writer.AsmLn;
                      writer.AsmWriteLn(secnamesml64[TAISection(hp).sectype]+#9+'SEGMENT')
                    end
                  else
                    begin
                      if LasTSecType<>sec_none then
                        writer.AsmWriteLn('_'+secnames[LasTSecType]+#9#9'ENDS');
                      writer.AsmLn;
                      s:=alignstr(TAISection(hp).secalign);
                      writer.AsmWriteLn('_'+secnames[TAISection(hp).sectype]+#9#9+
                                 'SEGMENT'#9+s+' PUBLIC USE32 '''+
                                 secnames[TAISection(hp).sectype]+'''');
                    end;
                end;
               LasTSecType:=TAISection(hp).sectype;
             end;
           ait_align :
             begin
               { CAUSES PROBLEMS WITH THE SEGMENT DEFINITION   }
               { SEGMENT DEFINITION SHOULD MATCH TYPE OF ALIGN }
               { HERE UNDER TASM!                              }
                 if TAIAlignAbstract(hp).aligntype>1 then
                   writer.AsmWriteLn(#9'ALIGN '+ToStr(TAIAlignAbstract(hp).aligntype));
               end;
           ait_datablock :
             begin
               if TAIDataBlock(hp).is_global then
                 writer.AsmWriteLn(#9'PUBLIC'#9+ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name));
               writer.AsmWriteLn(PadTabs(ApplyAsmSymbolRestrictions(TAIDataBlock(hp).sym.name),#0)+'DB'#9+ToStr(TAIDataBlock(hp).size)+' DUP(?)');
             end;
           ait_const:
             begin
               consttype:=TAIConst(hp).consttype;
               case consttype of
                 aitconst_uleb128bit,
                 aitconst_sleb128bit,
                 aitconst_128bit,
                 aitconst_64bit,
                 aitconst_32bit,
                 aitconst_16bit,
                 aitconst_8bit,
                 aitconst_16bit_unaligned,
                 aitconst_32bit_unaligned,
                 aitconst_64bit_unaligned,
                 aitconst_rva_symbol,
                 aitconst_secrel32_symbol :
                   begin
                     writer.AsmWrite(ait_const2str[consttype]);
                     l:=0;
		     tokens:=1;
                     repeat
                       if Assigned(TAIConst(hp).sym) then
                         begin
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
		       inc(tokens);
                       if (l>line_length) or
                          (tokens>max_tokens) or
                          (hp.next=nil) or
                          (TAI(hp.next).typ<>ait_const) or
                          (TAIConst(hp.next).consttype<>consttype) then
                         break;
                       hp:=TAI(hp.next);
                       writer.AsmWrite(',');
                     until false;
                     { Subtract section start for secrel32 type }
                     if consttype=aitconst_secrel32_symbol then
                       writer.AsmWrite(' - $$');
                     writer.AsmLn;
                   end;
                 else
                   InternalError(200704253);
               end;
             end;

           ait_realconst:
             begin
               case TAIRealConst(hp).realtyp of
                 aitrealconst_s32bit:
                   writer.AsmWriteLn(#9#9'DD'#9+single2str(TAIRealConst(hp).value.s32val));
                 aitrealconst_s64bit:
                   writer.AsmWriteLn(#9#9'DQ'#9+double2str(TAIRealConst(hp).value.s64val));
                 aitrealconst_s80bit,aitrealconst_s64comp:
                   WriteRealConstAsBytes(TAIRealConst(hp),#9#9'DB'#9,false);
               end;
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
                     counter := counter+line_length;
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
                  writer.AsmWrite(ApplyAsmSymbolRestrictions(TAILabel(hp).labsym.name));
                  if not Assigned(hp.next) or not(TAI(hp.next).typ in
                     [ait_const,ait_realconst,ait_string]) then
                   writer.AsmWriteLn(':')
                  else
                   DoNotSplitLine:=true;
                end;
             end;
           ait_symbol :
             begin
               if TAISymbol(hp).has_value then
                 InternalError(2009090802);
               if TAISymbol(hp).is_global then
                 writer.AsmWriteLn(#9'PUBLIC'#9+ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name));
               writer.AsmWrite(ApplyAsmSymbolRestrictions(TAISymbol(hp).sym.name));
               if not Assigned(hp.next) or not(TAI(hp.next).typ in
                  [ait_const,ait_realconst,ait_string]) then
                 writer.AsmWriteLn(':');
             end;
           ait_symbol_end :
             begin
             end;
           ait_instruction :
             begin
               fixed_opcode:=TAICPU(hp).FixNonCommutativeOpcodes;
               TAICPU(hp).SetOperandOrder(op_intel);
               { Reset }
               suffix:='';
               prefix:= '';
               { We need to explicitely set
                 word prefix to get selectors
                 to be pushed in 2 bytes  PM }
               if (TAICPU(hp).opsize=S_W) and
                   (
                    (
                     (fixed_opcode=A_PUSH) or
                     (fixed_opcode=A_POP)
                    ) and
                    (TAICPU(hp).oper[0]^.typ=top_reg) and
                    is_segment_reg(TAICPU(hp).oper[0]^.reg)
                   ) then
                 writer.AsmWriteln(#9#9'DB'#9'066h');

               { added prefix instructions, must be on same line as opcode }
               if (TAICPU(hp).ops = 0) and
                  ((fixed_opcode = A_REP) or
                   (fixed_opcode = A_LOCK) or
                   (fixed_opcode =  A_REPE) or
                   (fixed_opcode =  A_REPNZ) or
                   (fixed_opcode =  A_REPZ) or
                   (fixed_opcode = A_REPNE)) then
                Begin
                  prefix:=std_op2str[fixed_opcode]+#9;
                  { there can be debug information in between when the opcode was on
                    a different line in the source code }
                  repeat
                    hp:=TAI(hp.next);
                  until (hp=nil) or (hp.typ=ait_instruction);

                  { next instruction ... }
                  fixed_opcode:=TAICPU(hp).FixNonCommutativeOpcodes;
                  TAICPU(hp).SetOperandOrder(op_intel);

                  { this is theoretically impossible... }
                  if hp=nil then
                   begin
                     writer.AsmWriteLn(#9#9+prefix);
                     break;
                   end;
                end
               else
                prefix:= '';
               if (asminfo^.id=as_x86_64_masm) and
                 (fixed_opcode=A_MOVQ) then
                 writer.AsmWrite(#9#9'mov')
               else
                 writer.AsmWrite(#9#9+prefix+std_op2str[fixed_opcode]+cond2str[TAICPU(hp).condition]+suffix);
               if TAICPU(hp).ops<>0 then
                begin
                  if is_calljmp(fixed_opcode) then
                   begin
                     writer.AsmWrite(#9);
                     WriteOper_jmp(TAICPU(hp).oper[0]^,TAICPU(hp).opsize);
                   end
                  else
                   begin
                     for i:=0to TAICPU(hp).ops-1 do
                      begin
                        if i=0 then
                         writer.AsmWrite(#9)
                        else
                         writer.AsmWrite(',');
                        WriteOper(TAICPU(hp).oper[i]^,TAICPU(hp).opsize,fixed_opcode,(i=2));
                      end;
                   end;
                end;
               writer.AsmLn;
             end;

           ait_force_line,
           ait_function_name : ;

           ait_cutobject :
             begin
               { only reset buffer if nothing has changed }
                 if not writer.ClearIfEmpty then
                  begin
                    if LasTSecType<>sec_none then
                     writer.AsmWriteLn('_'+secnames[LasTSecType]+#9#9'ENDS');
                    writer.AsmLn;
                    writer.AsmWriteLn(#9'END');
                    writer.AsmClose;
                    DoAssemble;
                    writer.AsmCreate(TAICutObject(hp).place);
                  end;
               { avoid empty files }
                 while Assigned(hp.next) and (TAI(hp.next).typ in [ait_cutobject,ait_section,ait_comment]) do
                  begin
                    if TAI(hp.next).typ=ait_section then
                      lasTSecType:=TAISection(hp.next).sectype;
                    hp:=TAI(hp.next);
                  end;
                 writer.AsmWriteLn(#9'.386p');

                 { I was told that this isn't necessary because }
                 { the labels generated by FPC are unique (FK)  }
                 { writer.AsmWriteLn(#9'LOCALS '+asminfo^.labelprefix); }
                 { TODO: PARA is incorrect, must use actual section align }
                 if lasTSectype<>sec_none then
                    writer.AsmWriteLn('_'+secnames[lasTSectype]+#9#9+
                               'SEGMENT'#9'PARA PUBLIC USE32 '''+
                               secnames[lasTSectype]+'''');
                 writer.MarkEmpty;
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
               case TAIDirective(hp).directive of
                 asd_nasm_import :
                   begin
                     writer.AsmWrite('import ');
                     writer.AsmWrite(TAIDirective(hp).name);
                     writer.AsmLn;
                   end;
                 asd_extern :
                   begin
                     writer.AsmWrite('EXTRN ');
                     writer.AsmWrite(TAIDirective(hp).name);
                     writer.AsmLn;
                   end;
                 asd_cpu :
                   begin
                     writer.AsmWrite(asminfo^.comment+' CPU ');
                     writer.AsmWrite(TAIDirective(hp).name);
                     writer.AsmLn;
                   end
                 else
                   InternalError(200509192);
               end;
             end;
           ait_seh_directive :
             { Ignore for now };
           else
             if not WriteComments(hp) then
               InternalError(2020100802);
         end;
         hp:=TAI(hp.next);
       end;
    end;


    procedure tx86intelassembler.WriteExternals;
      var
        sym : TAsmSymbol;
        i   : LongInt;
      begin
        for i:=0 to CurrentAsmData.AsmSymbolDict.Count-1 do
          begin
            sym:=TAsmSymbol(CurrentAsmData.AsmSymbolDict[i]);
            if sym.bind in [AB_EXTERNAL,AB_EXTERNAL_INDIRECT] then
              begin
                if asminfo^.id=as_x86_64_masm then
                  writer.AsmWriteln(#9'EXTRN'#9+ApplyAsmSymbolRestrictions(sym.name)+': PROC')
                else
                  writer.AsmWriteln(#9'EXTRN'#9+ApplyAsmSymbolRestrictions(sym.name));
              end;
          end;
      end;


    procedure tx86IntelAssembler.WriteAsmList;
    var
      hal : TAsmListType;
    begin
{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       comment(VInfo,'Start writing intel-styled assembler output for '+CurrentModule.MainSource);
{$endif}
      WriteExternals;

      for hal:=low(TAsmListType) to high(TAsmListType) do
        begin
          writer.AsmWriteLn(asminfo^.comment+'Begin asmlist '+AsmListTypeStr[hal]);
          writetree(CurrentAsmData.asmlists[hal]);
          writer.AsmWriteLn(asminfo^.comment+'End asmlist '+AsmListTypeStr[hal]);
        end;

      { better do this at end of WriteTree, but then there comes a trouble with
        al_const which does not have leading ait_section and thus goes out of segment }

      if LastSecType <> sec_none then
        begin
          if asminfo^.id=as_x86_64_masm then
            writer.AsmWriteLn(secnamesml64[LasTSecType]+#9#9'ENDS')
          else
            writer.AsmWriteLn('_'+secnames[LasTSecType]+#9#9'ENDS');
        end;
      LastSecType := sec_none;

      writer.AsmWriteLn(#9'END');
      writer.AsmLn;

{$ifdef EXTDEBUG}
      if CurrentModule.MainSource<>'' then
       comment(VInfo,'Done writing intel-styled assembler output for '+CurrentModule.MainSource);
{$endif EXTDEBUG}
   end;


{*****************************************************************************
                                  Initialize
*****************************************************************************}

    const
{$ifdef x86_64}
       as_x86_64_masm_info : TAsmInfo =
          (
            id     : as_x86_64_masm;
            idtxt  : 'MASM';
            asmbin : 'ml64';
            asmcmd : '/c /Cp $EXTRAOPT $ASM /Fo$OBJ';
            supported_targets : [system_x86_64_win64];
            flags : [af_needar];
            labelprefix : '@@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );
{$endif x86_64}

initialization
{$ifdef x86_64}
  RegisterAssembler(as_x86_64_masm_info,tx86IntelAssembler);
{$endif x86_64}
end.
