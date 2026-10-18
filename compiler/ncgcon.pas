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
          procedure Pass_Generate_Code;override;
       end;

       TCGOrdConstNode = class(TOrdConstNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGPointerConstNode = class(TPointerConstNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGStringConstNode = class(TStringConstNode)
          procedure Pass_Generate_Code;override;
       protected
         procedure Load_DynString(const AStringPointerDef: TDef; const AElementDef: TDef; const AWinLikeWideString: Boolean); virtual;
       end;

       TCGSetConstNode = class(TSetConstNode)
         protected
          function EmitVarSetConst: TAsmSymbol; virtual;
          procedure HandleVarSetConst;
         public
          procedure Pass_Generate_Code;override;
       end;

       TCGNilNode = class(TNilNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGGUIDConstNode = class(TGUIDConstNode)
          procedure Pass_Generate_Code;override;
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

    procedure TCGRealConstNode.Pass_Generate_Code;
      { I suppose the parser/pass_1 must make sure the generated real  }
      { constants are actually supported by the target processor? (JM) }
      const
        FloatType2AIT:array[TFloatType] of TAIRealConstType=
          (aitrealconst_s32bit,aitrealconst_s64bit,aitrealconst_s80bit,aitrealconst_s80bit,aitrealconst_s64comp,aitrealconst_s64comp);

      { Since the value is stored always as bestreal, we share a single pool
        between all float types. This requires the type to
        be matched along with the value }
      type
        TFloatKey = record
          Value: BestReal;
          Typ: TFloatType;
        end;

      var
         lLastLabel : TAsmLabel;
         lRealAIT : TAIRealConstType;
         lEntry : PHashSetItem;
         lKey: TFloatKey;

      begin
        Location_Reset_Ref(Location,LOC_CREFERENCE,Def_CGSize(ResultDef),Const_Align(ResultDef.Alignment),[]);
        lLastLabel:=nil;
        lRealAIT:=FloatType2AIT[TFloatDef(ResultDef).FloatType];
        { const already used ? }
        if not Assigned(RealLabel) then
          begin
            { there may be gap between record fields, zero it out }
            fillchar(lKey,sizeof(lKey),0);
            lKey.Value:=ValueReal;
            lKey.Typ:=TFloatDef(ResultDef).FloatType;
            lEntry := CurrentAsmData.ConstPools[sp_floats].FindOrAdd(@lKey, sizeof(lKey));

            RealLabel := TAsmLabel(lEntry^.Data);  // is it needed anymore?

             { :-(, we must generate a new entry }
             if not(Assigned(RealLabel)) then
               begin
                  CurrentAsmData.getdatalabel(lLastLabel);
                  lEntry^.Data:=lLastLabel;
                  RealLabel:=lLastLabel;
                  maybe_new_object_file(CurrentAsmData.asmlists[al_typedconsts]);
                  new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,lLastLabel.name,Const_Align(ResultDef.Alignment));
                  CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(lLastLabel));
                  case lRealAIT of
                    aitrealconst_s32bit :
                      begin
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s32real(Single(ValueReal)));
                      end;

                    aitrealconst_s64bit :
                      begin
                          CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s64real(Double(ValueReal)));
                     end;

                    aitrealconst_s80bit :
                      begin
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s80real(ValueReal,TFloatDef(ResultDef).Size));
                      end;

                    { the round is necessary for native compilers where comp isn't a float }
                    aitrealconst_s64comp :
                      if (ValueReal>BestReal(High(Int64))) or (ValueReal<BestReal(Low(Int64))) then
                        message(parser_e_range_check_error)
                      else
                        CurrentAsmData.asmlists[al_typedconsts].concat(TAIRealConst.create_s64compreal(Round(ValueReal)));
                  end;
                  if (tf_needs_symbol_size in TargetInfo.Flags) then
                    CurrentAsmData.asmlists[al_typedconsts].concat(TAISymbolEnd.Create(lLastLabel));
               end;
          end;
        Location.Reference.Symbol:=RealLabel;
      end;

{*****************************************************************************
                            TCGORDCONSTNODE
*****************************************************************************}

    procedure TCGOrdConstNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_CONSTANT,Def_CGSize(ResultDef));
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
         Location.Value:=Value.svalue;
{$else cpu64bitalu or cpuhighleveltarget}
         Location.Value64:=Value.svalue;
{$endif cpu64bitalu or cpuhighleveltarget}
      end;


{*****************************************************************************
                          TCGPOINTERCONSTNODE
*****************************************************************************}

    procedure TCGPointerConstNode.Pass_Generate_Code;
      begin
         { an integer const. behaves as a memory reference }
         Location_Reset(Location,LOC_CONSTANT,OS_ADDR);
         Location.Value:=PInt(Value);
      end;


{*****************************************************************************
                          TCGSTRINGCONSTNODE
*****************************************************************************}

    procedure TCGStringConstNode.Pass_Generate_Code;
      var
         lLastLabel: TAsmLabOfs;
         lLength: LongInt;
         lPool: THashSet;
         lEntry: PHashSetItem;
         lWinLikeWideString: Boolean;
         lElementDef: TDef;
         lStringPointerDef: TDef;
         lDataBuilder: TTAITypedConstBuilder;
         lDataDef: TDef;
         lStringAsmItem : TAIString;


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
         case ConstStringType of
           cst_shortstring,
           cst_conststring,
           cst_ansistring:
             begin
               lElementDef:=CAnsiCharType;
               lStringPointerDef:=CharPointerType;
             end;
           cst_widestring,
           cst_unicodestring:
             begin
               lElementDef:=CWideCharType;
               lStringPointerDef:=WideCharPointerType;
             end;
           else
             InternalError(2014032803);
         end;
         { for empty ansistrings we could return a constant 0 }
         if (ConstStringType in [cst_ansistring,cst_widestring,cst_unicodestring]) and (Len=0) then
          begin
            Location_Reset(Location,LOC_CONSTANT,Def_CGSize(lStringPointerDef));
            Location.Value:=0;
            exit;
          end;
         lWinLikeWideString:=(ConstStringType=cst_widestring) and (tf_winlikewidestring in TargetInfo.Flags);
         { const already used ? }
         if not Assigned(StringLabel) then
           begin
              lPool := CurrentAsmData.ConstPools[PoolMap[ConstStringType]];

              if ConstStringType in [cst_widestring, cst_unicodestring] then
                lEntry := lPool.FindOrAdd(pointer(ValueWS.data),Len*CWideCharType.Size)
              else
              if ConstStringType = cst_ansistring then
                lEntry := PHashSetItem(TTagHashSet(lPool).FindOrAdd(pointer(ValueAS),Len,TStringDef(ResultDef).encoding))
              else
                lEntry := lPool.FindOrAdd(pointer(ValueAS),Len);

              StringLabel := TAsmLabel(lEntry^.Data);  // is it needed anymore?

              { :-(, we must generate a new entry }
              if not Assigned(lEntry^.Data) then
                begin
                  lDataBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
                   case ConstStringType of
                      cst_ansistring:
                        begin
                           if Len=0 then
                             InternalError(2008032301)   { empty string should be handled above }
                           else
                             begin
                               lLastLabel:=lDataBuilder.emit_ansistring_const(CurrentAsmData.AsmLists[al_typedconsts],AsConstPChar,Len,TStringDef(ResultDef).encoding);
                               { because we hardcode the offset below due to it
                                 not being stored in the hashset, check here }
                               if lLastLabel.ofs<>lDataBuilder.get_string_symofs(st_ansistring,false) then
                                 InternalError(2012051703);
                             end;
                           { no contents of the datatcb itself to concatenate,
                             as we will just return the address of the emitted
                             ansistring constant record }
                        end;
                      cst_unicodestring,
                      cst_widestring:
                        begin
                           if Len=0 then
                             InternalError(2008032302)   { empty string should be handled above }
                           else
                             begin
                               lLastLabel:=lDataBuilder.emit_unicodestring_const(CurrentAsmData.AsmLists[al_typedconsts],
                                               ValueWS,
                                               TStringDef(ResultDef).encoding,
                                               lWinLikeWideString);
                               { because we hardcode the offset below due to it
                                 not being stored in the hashset, check here }
                               if lLastLabel.ofs<>lDataBuilder.get_string_symofs(TStringDef(ResultDef).StringType,lWinLikeWideString) then
                                 InternalError(2012051702);
                             end;
                           { no contents of the datatcb itself to concatenate,
                             as we will just return the address of the emitted
                             unicode/widestring constant record }
                        end;
                      cst_shortstring:
                        begin
                          CurrentAsmData.getdatalabel(lLastLabel.lab);

                          { truncate strings larger than 255 chars }
                          if Len>255 then
                           lLength:=255
                          else
                           lLength:=Len;

                          { include length and terminating zero for quick conversion to pchar }
                          lDataDef:=CArrayDef.getreusable(CAnsiCharType,lLength+2);
                          lDataBuilder.maybe_begin_aggregate(lDataDef);
                          lDataBuilder.emit_tai(TAIConst.Create_8bit(lLength),CAnsiCharType);
                          lStringAsmItem:=TAIString.Create_Data(AsConstPChar,lLength,true);
                          lDataBuilder.emit_tai(lStringAsmItem,lDataDef);
                          lDataBuilder.maybe_end_aggregate(lDataDef);
                          CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                            lDataBuilder.get_final_asmlist(lLastLabel.lab,lDataDef,sec_rodata_norel,lLastLabel.lab.name,Const_Align(sizeof(PInt)))
                          );
                        end;
                      cst_conststring:
                        begin
                          CurrentAsmData.getdatalabel(lLastLabel.lab);

                          { the data includes the terminating #0 because this
                            string can be used for pchar assignments (but it's
                            also used for array-of-char assignments, in which
                            case the terminating #0 is not part of the data) }
                          lDataDef:=CArrayDef.getreusable(CAnsiCharType,Len+1);
                          lDataBuilder.maybe_begin_aggregate(lDataDef);
                          lStringAsmItem:=TAIString.Create_Data(AsConstPChar,Len,true);
                          lDataBuilder.emit_tai(lStringAsmItem,lDataDef);
                          lDataBuilder.maybe_end_aggregate(lDataDef);
                          CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                            lDataBuilder.get_final_asmlist(lLastLabel.lab,lDataDef,sec_rodata_norel,lLastLabel.lab.name,Const_Align(sizeof(PInt)))
                          );
                        end;
                      else
                        InternalError(2013120103);
                   end;
                   lDataBuilder.free;
                   lDataBuilder := nil;
                   StringLabel:=lLastLabel.lab;
                   lEntry^.Data:=lLastLabel.lab;
                end;
           end;
         if ConstStringType in [cst_ansistring, cst_widestring, cst_unicodestring] then
           begin
             Location_Reset(Location, LOC_REGISTER, Def_CGSize(lStringPointerDef));
             Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lStringPointerDef);
             Load_DynString(lStringPointerDef, lElementDef, lWinLikeWideString);
           end
         else
           begin
             Location_Reset_Ref(Location, LOC_CREFERENCE, Def_CGSize(ResultDef), Const_Align(lStringPointerDef.Size), []);
             Location.Reference.Symbol:=StringLabel;
           end;
      end;


    procedure TCGStringConstNode.Load_DynString(const AStringPointerDef: TDef; const AElementDef: TDef; const AWinLikeWideString: Boolean);
      var
        lReference: TReference;
      begin
        Reference_Reset_Symbol(lReference, StringLabel,
          CTAITypedConstBuilder.get_string_symofs(TStringDef(ResultDef).StringType, AWinLikeWideString),
          Const_Align(AStringPointerDef.Size),[]);
        hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList, AElementDef, AStringPointerDef, lReference, Location.Register)
      end;


{*****************************************************************************
                           TCGSETCONSTNODE
*****************************************************************************}

    function TCGSetConstNode.EmitVarSetConst: TAsmSymbol;
      type
        TSetBytes=array[0..31] of Byte;
        PSetBytes=^TSetBytes;
      var
        lLabel: TAsmLabel;
        lIndex: LongInt;
        lBuilder: TTAITypedConstBuilder;
      begin
        CurrentAsmData.getdatalabel(lLabel);
        Result:=lLabel;
        DataLabel:=lLabel;
        lBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
        lBuilder.maybe_begin_aggregate(ResultDef);
        if (SourceInfo.endian=TargetInfo.endian) then
          for lIndex:=0 to ResultDef.Size-1 do
            lBuilder.emit_tai(TAIConst.create_8bit(PSetBytes(ValueSet)^[lIndex]),U8IntType)
        else
          for lIndex:=0 to ResultDef.Size-1 do
            lBuilder.emit_tai(TAIConst.create_8bit(Reverse_Byte(PSetBytes(ValueSet)^[lIndex])),U8IntType);
        lBuilder.maybe_end_aggregate(ResultDef);
        CurrentAsmData.asmlists[al_typedconsts].ConcatList(lBuilder.get_final_asmlist(
          Result,ResultDef,sec_rodata_norel,Result.name,Const_Align(8)));
        lBuilder.free;
        lBuilder := nil;
      end;


    procedure TCGSetConstNode.HandleVarSetConst;
      var
         lEntry       : PHashSetItem;
      begin
        Location_Reset_Ref(Location,LOC_CREFERENCE,OS_NO,Const_Align(8),[]);
        { const already used ? }
        if not Assigned(DataLabel) then
          begin
            lEntry := CurrentAsmData.ConstPools[sp_varsets].FindOrAdd(ValueSet, ResultDef.Size);

             { :-(, we must generate a new entry }
             if not Assigned(lEntry^.Data) then
               lEntry^.Data:=EmitVarSetConst;
             DataLabel := TAsmSymbol(lEntry^.Data);
          end;
        Location.Reference.Symbol:=DataLabel;
      end;


    procedure TCGSetConstNode.Pass_Generate_Code;
       type
         TSetBytes=array[0..31] of Byte;
         PSetBytes=^TSetBytes;

        procedure SmallSetConst;
          begin
            Location_Reset(Location,LOC_CONSTANT,Int_CGSize(ResultDef.Size));
            if (SourceInfo.endian=TargetInfo.endian) then
              begin
                { not plongint, because that will "sign extend" the set on 64 bit platforms }
                { if changed to "paword", please also modify "32-resultdef.size*8" and      }
                { cross-endian code below                                                   }
                { Extra aint type cast to avoid range errors                                }
                Location.Value:=AInt(pCardinal(ValueSet)^)
              end
            else
              begin
                Location.Value:=AInt(Reverse_LongWord(Pcardinal(ValueSet)^));
              end;
            if (TargetInfo.endian=endian_big) then
              Location.Value:=Location.Value shr (32-ResultDef.Size*8);
          end;

      begin
        AdjustForSetBase;

        { small sets are loaded as constants }
        if Is_SmallSet(ResultDef) then
          SmallSetConst
        else
          HandleVarSetConst;
      end;


{*****************************************************************************
                             TCGNILNODE
*****************************************************************************}

    procedure TCGNilNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_CONSTANT,OS_ADDR);
         Location.Value:=0;
      end;


{*****************************************************************************
                          TCGGUIDCONSTNODE
*****************************************************************************}

    procedure TCGGUIDConstNode.Pass_Generate_Code;
      var
         lLastLabel   : TAsmLabel;
         lEntry       : PHashSetItem;
         lDataBuilder     : TTAITypedConstBuilder;
      begin
        Location_Reset_Ref(Location,LOC_CREFERENCE,OS_NO,Const_Align(16),[]);
        lLastLabel:=nil;
        { const already used ? }
        if not Assigned(DataLabel) then
          begin
            lEntry:=CurrentAsmData.ConstPools[sp_guids].FindOrAdd(@Value,sizeof(Value));
            DataLabel:=TAsmLabel(lEntry^.Data);  // is it needed anymore?

             { :-(, we must generate a new entry }
             if not Assigned(lEntry^.Data) then
               begin
                 CurrentAsmData.getdatalabel(lLastLabel);
                 lDataBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
                 lDataBuilder.emit_guid_const(Value);
                 CurrentAsmData.asmlists[al_typedconsts].ConcatList(
                   lDataBuilder.get_final_asmlist(lLastLabel,Rec_TGUID,sec_rodata_norel,lLastLabel.name,Const_Align(16)));
                 lDataBuilder.free;
                 lDataBuilder := nil;
                 DataLabel:=lLastLabel;
                 lEntry^.Data:=lLastLabel;
               end;
          end;
        Location.Reference.Symbol:=DataLabel;
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
