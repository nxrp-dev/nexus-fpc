{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate assembler for constant nodes which are the same for
    all (most) processors

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
unit ncgcon;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       aasmbase,
       symtype,
       ncon;

    type
       TCGRealConstNode = class(TRealConstNode)
          procedure pass_generate_code;override;
       end;

       TCGOrdConstNode = class(TOrdConstNode)
          procedure pass_generate_code;override;
       end;

       TCGPointerConstNode = class(TPointerConstNode)
          procedure pass_generate_code;override;
       end;

       TCGStringConstNode = class(TStringConstNode)
          procedure pass_generate_code;override;
       protected
         procedure load_dynstring(const strpointerdef: TDef; const elementdef: TDef; const winlikewidestring: boolean); virtual;
       end;

       TCGSetConstNode = class(TSetConstNode)
         protected
          function emitvarsetconst: TAsmSymbol; virtual;
          procedure handlevarsetconst;
         public
          procedure pass_generate_code;override;
       end;

       TCGNilNode = class(TNilNode)
          procedure pass_generate_code;override;
       end;

       TCGGUIDConstNode = class(TGUIDConstNode)
          procedure pass_generate_code;override;
       end;


implementation

    uses
      GlobType,WideStr,Systems,
      Verbose,Globals,CUtils,
      aasmcnst,
      symconst,symdef,aasmtai,AAsmData,defutil,
      CPUInfo,cpubase,
      cgbase,cgutils,
      hlcgobj,CClasses
      ;


{*****************************************************************************
                           TCGREALCONSTNODE
*****************************************************************************}

    procedure TCGRealConstNode.pass_generate_code;
      { I suppose the parser/pass_1 must make sure the generated real  }
      { constants are actually supported by the target processor? (JM) }
      const
        floattype2ait:array[TFloatType] of TAIRealConstType=
          (aitrealconst_s32bit,aitrealconst_s64bit,aitrealconst_s80bit,aitrealconst_s80bit,aitrealconst_s64comp,aitrealconst_s64comp);

      { Since the value is stored always as bestreal, we share a single pool
        between all float types. This requires the type to
        be matched along with the value }
      type
        TFloatKey = record
          value: BestReal;
          typ: TFloatType;
        end;

      var
         lastlabel : TAsmLabel;
         realait : TAIRealConstType;
         entry : PHashSetItem;
         key: TFloatKey;

      begin
        location_reset_ref(location,LOC_CREFERENCE,def_cgsize(resultdef),Const_Align(resultdef.alignment),[]);
        lastlabel:=nil;
        realait:=floattype2ait[TFloatDef(resultdef).floattype];
        { const already used ? }
        if not Assigned(lab_real) then
          begin
            { there may be gap between record fields, zero it out }
            fillchar(key,sizeof(key),0);
            key.value:=value_real;
            key.typ:=TFloatDef(resultdef).floattype;
            entry := CurrentAsmData.ConstPools[sp_floats].FindOrAdd(@key, sizeof(key));

            lab_real := TAsmLabel(entry^.Data);  // is it needed anymore?

             { :-(, we must generate a new entry }
             if not(Assigned(lab_real)) then
               begin
                  CurrentAsmData.getdatalabel(lastlabel);
                  entry^.Data:=lastlabel;
                  lab_real:=lastlabel;
                  maybe_new_object_file(CurrentAsmData.asmlists[al_typedconsts]);
                  new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,lastlabel.name,Const_Align(resultdef.alignment));
                  CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(lastlabel));
                  case realait of
                    aitrealconst_s32bit :
                      begin
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s32real(Single(value_real)));
                      end;

                    aitrealconst_s64bit :
                      begin
                          CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s64real(Double(value_real)));
                     end;

                    aitrealconst_s80bit :
                      begin
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s80real(value_real,TFloatDef(resultdef).size));
                      end;

                    { the round is necessary for native compilers where comp isn't a float }
                    aitrealconst_s64comp :
                      if (value_real>BestReal(High(Int64))) or (value_real<BestReal(Low(Int64))) then
                        message(parser_e_range_check_error)
                      else
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s64compreal(Round(value_real)));
                  end;
                  if (tf_needs_symbol_size in TargetInfo.flags) then
                    CurrentAsmData.asmlists[al_typedconsts].concat(TAISymbolEnd.Create(lastlabel));
               end;
          end;
        location.reference.symbol:=lab_real;
      end;

{*****************************************************************************
                            TCGORDCONSTNODE
*****************************************************************************}

    procedure TCGOrdConstNode.pass_generate_code;
      begin
         location_reset(location,LOC_CONSTANT,def_cgsize(resultdef));
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
         location.value:=value.svalue;
{$else cpu64bitalu or cpuhighleveltarget}
         location.value64:=value.svalue;
{$endif cpu64bitalu or cpuhighleveltarget}
      end;


{*****************************************************************************
                          TCGPOINTERCONSTNODE
*****************************************************************************}

    procedure TCGPointerConstNode.pass_generate_code;
      begin
         { an integer const. behaves as a memory reference }
         location_reset(location,LOC_CONSTANT,OS_ADDR);
         location.value:=PInt(value);
      end;


{*****************************************************************************
                          TCGSTRINGCONSTNODE
*****************************************************************************}

    procedure TCGStringConstNode.pass_generate_code;
      var
         lastlabel: TAsmLabOfs;
         l: LongInt;
         pool: THashSet;
         entry: PHashSetItem;
         winlikewidestring: boolean;
         elementdef: TDef;
         strpointerdef: TDef;
         datatcb: TTAITypedConstBuilder;
         datadef: TDef;
         t : TAIString;


      const
        PoolMap: array[TConstStringType] of TConstPoolType = (
          sp_conststr,
          sp_shortstr,
          sp_longstr,
          sp_ansistr,
          sp_widestr,
          sp_unicodestr
        );
      begin
         case cst_type of
           cst_shortstring,
           cst_conststring,
           cst_ansistring:
             begin
               elementdef:=cansichartype;
               strpointerdef:=charpointertype;
             end;
           cst_widestring,
           cst_unicodestring:
             begin
               elementdef:=cwidechartype;
               strpointerdef:=widecharpointertype;
             end;
           else
             InternalError(2014032803);
         end;
         { for empty ansistrings we could return a constant 0 }
         if (cst_type in [cst_ansistring,cst_widestring,cst_unicodestring]) and (len=0) then
          begin
            location_reset(location,LOC_CONSTANT,def_cgsize(strpointerdef));
            location.value:=0;
            exit;
          end;
         winlikewidestring:=(cst_type=cst_widestring) and (tf_winlikewidestring in TargetInfo.flags);
         { const already used ? }
         if not Assigned(lab_str) then
           begin
              pool := CurrentAsmData.ConstPools[PoolMap[cst_type]];

              if cst_type in [cst_widestring, cst_unicodestring] then
                entry := pool.FindOrAdd(pointer(valuews.data),len*cwidechartype.size)
              else
              if cst_type = cst_ansistring then
                entry := PHashSetItem(TTagHashSet(pool).FindOrAdd(pointer(valueas),len,TStringDef(resultdef).encoding))
              else
                entry := pool.FindOrAdd(pointer(valueas),len);

              lab_str := TAsmLabel(entry^.Data);  // is it needed anymore?

              { :-(, we must generate a new entry }
              if not Assigned(entry^.Data) then
                begin
                  datatcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
                   case cst_type of
                      cst_ansistring:
                        begin
                           if len=0 then
                             InternalError(2008032301)   { empty string should be handled above }
                           else
                             begin
                               lastlabel:=datatcb.emit_ansistring_const(CurrentAsmData.AsmLists[al_typedconsts],asconstpchar,len,TStringDef(resultdef).encoding);
                               { because we hardcode the offset below due to it
                                 not being stored in the hashset, check here }
                               if lastlabel.ofs<>datatcb.get_string_symofs(st_ansistring,false) then
                                 InternalError(2012051703);
                             end;
                           { no contents of the datatcb itself to concatenate,
                             as we will just return the address of the emitted
                             ansistring constant record }
                        end;
                      cst_unicodestring,
                      cst_widestring:
                        begin
                           if len=0 then
                             InternalError(2008032302)   { empty string should be handled above }
                           else
                             begin
                               lastlabel:=datatcb.emit_unicodestring_const(CurrentAsmData.AsmLists[al_typedconsts],
                                               valuews,
                                               TStringDef(resultdef).encoding,
                                               winlikewidestring);
                               { because we hardcode the offset below due to it
                                 not being stored in the hashset, check here }
                               if lastlabel.ofs<>datatcb.get_string_symofs(TStringDef(resultdef).stringtype,winlikewidestring) then
                                 InternalError(2012051702);
                             end;
                           { no contents of the datatcb itself to concatenate,
                             as we will just return the address of the emitted
                             unicode/widestring constant record }
                        end;
                      cst_shortstring:
                        begin
                          CurrentAsmData.getdatalabel(lastlabel.lab);

                          { truncate strings larger than 255 chars }
                          if len>255 then
                           l:=255
                          else
                           l:=len;

                          { include length and terminating zero for quick conversion to pchar }
                          datadef:=CArrayDef.getreusable(cansichartype,l+2);
                          datatcb.maybe_begin_aggregate(datadef);
                          datatcb.emit_tai(TAIConst.Create_8bit(l),cansichartype);
                          t:=TAIString.Create_Data(asconstpchar,l,true);
                          datatcb.emit_tai(t,datadef);
                          datatcb.maybe_end_aggregate(datadef);
                          CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                            datatcb.get_final_asmlist(lastlabel.lab,datadef,sec_rodata_norel,lastlabel.lab.name,Const_Align(sizeof(PInt)))
                          );
                        end;
                      cst_conststring:
                        begin
                          CurrentAsmData.getdatalabel(lastlabel.lab);

                          { the data includes the terminating #0 because this
                            string can be used for pchar assignments (but it's
                            also used for array-of-char assignments, in which
                            case the terminating #0 is not part of the data) }
                          datadef:=CArrayDef.getreusable(cansichartype,len+1);
                          datatcb.maybe_begin_aggregate(datadef);
                          t:=TAIString.Create_Data(asconstpchar,len,true);
                          datatcb.emit_tai(t,datadef);
                          datatcb.maybe_end_aggregate(datadef);
                          CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                            datatcb.get_final_asmlist(lastlabel.lab,datadef,sec_rodata_norel,lastlabel.lab.name,Const_Align(sizeof(PInt)))
                          );
                        end;
                      else
                        InternalError(2013120103);
                   end;
                   datatcb.free;
                   datatcb := nil;
                   lab_str:=lastlabel.lab;
                   entry^.Data:=lastlabel.lab;
                end;
           end;
         if cst_type in [cst_ansistring, cst_widestring, cst_unicodestring] then
           begin
             location_reset(location, LOC_REGISTER, def_cgsize(strpointerdef));
             location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,strpointerdef);
             load_dynstring(strpointerdef, elementdef, winlikewidestring);
           end
         else
           begin
             location_reset_ref(location, LOC_CREFERENCE, def_cgsize(resultdef), Const_Align(strpointerdef.size), []);
             location.reference.symbol:=lab_str;
           end;
      end;


    procedure TCGStringConstNode.load_dynstring(const strpointerdef: TDef; const elementdef: TDef; const winlikewidestring: boolean);
      var
        href: TReference;
      begin
        reference_reset_symbol(href, lab_str,
          CTAITypedConstBuilder.get_string_symofs(TStringDef(resultdef).stringtype, winlikewidestring),
          Const_Align(strpointerdef.size),[]);
        hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList, elementdef, strpointerdef, href, location.register)
      end;


{*****************************************************************************
                           TCGSETCONSTNODE
*****************************************************************************}

    function TCGSetConstNode.emitvarsetconst: TAsmSymbol;
      type
        TSetBytes=array[0..31] of byte;
        PSetBytes=^TSetBytes;
      var
        lab: TAsmLabel;
        i: LongInt;
        tcb: TTAITypedConstBuilder;
      begin
        CurrentAsmData.getdatalabel(lab);
        result:=lab;
        lab_set:=lab;
        tcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
        tcb.maybe_begin_aggregate(resultdef);
        if (SourceInfo.endian=TargetInfo.endian) then
          for i:=0 to resultdef.size-1 do
            tcb.emit_tai(TAIConst.create_8bit(PSetBytes(value_set)^[i]),u8inttype)
        else
          for i:=0 to resultdef.size-1 do
            tcb.emit_tai(TAIConst.create_8bit(Reverse_Byte(PSetBytes(value_set)^[i])),u8inttype);
        tcb.maybe_end_aggregate(resultdef);
        CurrentAsmData.asmlists[al_typedconsts].ConcatList(tcb.get_final_asmlist(
          result,resultdef,sec_rodata_norel,result.name,Const_Align(8)));
        tcb.free;
        tcb := nil;
      end;


    procedure TCGSetConstNode.handlevarsetconst;
      var
         entry       : PHashSetItem;
      begin
        location_reset_ref(location,LOC_CREFERENCE,OS_NO,Const_Align(8),[]);
        { const already used ? }
        if not Assigned(lab_set) then
          begin
            entry := CurrentAsmData.ConstPools[sp_varsets].FindOrAdd(value_set, resultdef.size);

             { :-(, we must generate a new entry }
             if not Assigned(entry^.Data) then
               entry^.Data:=emitvarsetconst;
             lab_set := TAsmSymbol(entry^.Data);
          end;
        location.reference.symbol:=lab_set;
      end;


    procedure TCGSetConstNode.pass_generate_code;
       type
         TSetBytes=array[0..31] of byte;
         PSetBytes=^TSetBytes;

        procedure smallsetconst;
          begin
            location_reset(location,LOC_CONSTANT,int_cgsize(resultdef.size));
            if (SourceInfo.endian=TargetInfo.endian) then
              begin
                { not plongint, because that will "sign extend" the set on 64 bit platforms }
                { if changed to "paword", please also modify "32-resultdef.size*8" and      }
                { cross-endian code below                                                   }
                { Extra aint type cast to avoid range errors                                }
                location.value:=aint(pCardinal(value_set)^)
              end
            else
              begin
                location.value:=aint(Reverse_LongWord(Pcardinal(value_set)^));
              end;
            if (TargetInfo.endian=endian_big) then
              location.value:=location.value shr (32-resultdef.size*8);
          end;

      begin
        adjustforsetbase;

        { small sets are loaded as constants }
        if is_smallset(resultdef) then
          smallsetconst
        else
          handlevarsetconst;
      end;


{*****************************************************************************
                             TCGNILNODE
*****************************************************************************}

    procedure TCGNilNode.pass_generate_code;
      begin
         location_reset(location,LOC_CONSTANT,OS_ADDR);
         location.value:=0;
      end;


{*****************************************************************************
                          TCGGUIDCONSTNODE
*****************************************************************************}

    procedure TCGGUIDConstNode.pass_generate_code;
      var
         lastlabel   : TAsmLabel;
         entry       : PHashSetItem;
         datatcb     : TTAITypedConstBuilder;
      begin
        location_reset_ref(location,LOC_CREFERENCE,OS_NO,Const_Align(16),[]);
        lastlabel:=nil;
        { const already used ? }
        if not Assigned(lab_set) then
          begin
            entry:=CurrentAsmData.ConstPools[sp_guids].FindOrAdd(@value,sizeof(value));
            lab_set:=TAsmLabel(entry^.Data);  // is it needed anymore?

             { :-(, we must generate a new entry }
             if not Assigned(entry^.Data) then
               begin
                 CurrentAsmData.getdatalabel(lastlabel);
                 datatcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
                 datatcb.emit_guid_const(value);
                 CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                   datatcb.get_final_asmlist(lastlabel,rec_tguid,sec_rodata_norel,lastlabel.name,Const_Align(16)));
                 datatcb.free;
                 datatcb := nil;
                 lab_set:=lastlabel;
                 entry^.Data:=lastlabel;
               end;
          end;
        location.reference.symbol:=lab_set;
      end;


begin
   CRealConstNode:=TCGRealConstNode;
   COrdConstNode:=TCGOrdConstNode;
   CPointerConstNode:=TCGPointerConstNode;
   CStringConstNode:=TCGStringConstNode;
   CSetConstNode:=TCGSetConstNode;
   CNilNode:=TCGNilNode;
   CGUIDConstNode:=TCGGUIDConstNode;
end.
