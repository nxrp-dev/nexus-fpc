{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86 assembler for in/case nodes

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
unit nx86set;

{$i fpcdefs.inc}

interface

    uses
      GlobType,ConstExp,
      node,nset,Pass_1,ncgset;

    type
       TX86InNode = class(TInNode)
         procedure Pass_Generate_Code;override;
         function Pass_1 : TNode;override;
       end;

      TX86CaseNode = class(TCGCaseNode)
         function  Has_JumpTable : Boolean;override;
         procedure GenJumpTable(ARootLabel : PCaseLabel;AMin,AMax : Int64);override;
         procedure GenLinearList(ARootLabel : PCaseLabel);override;
         procedure GenJmpTreeEntry(ALabel : PCaseLabel;AParentValue : TConstExprInt);override;
      end;

implementation

    uses
      Systems,
      Verbose,Globals,
      symconst,symdef,defutil,CUtils,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgbase,pass_2,tgobj,
      ncon,
      cpubase,
      cga,cgobj,hlcgobj,cgutils,ncgutil,
      cgx86,
      ProcInfo;

{*****************************************************************************
                                  TX86CASENODE
*****************************************************************************}

    function TX86CaseNode.Has_JumpTable : Boolean;
      begin
        Has_JumpTable:=true;
      end;


    procedure TX86CaseNode.GenJumpTable(ARootLabel : PCaseLabel;AMin,AMax : Int64);
      var
        lTableLabel : TAsmLabel;
        lLastValue : TConstExprInt;
        lIndexReg : TRegister;
        lReference : TReference;
        lJumpTableList: TAsmList;
        lOpCGSize: TCgSize;
        lJumpReg: TRegister;
        lLabelType: TAIConstType;
        lAlmostExhaustive: Boolean;
        lLowValue, lHighValue: TConstExprInt;
        lExhaustiveLimit, lRange, lValue, lOldMin : Int64;

      const
        cExhaustiveLimitBase = 32;

        procedure GenItem(AList:TAsmList;ALabel : PCaseLabel);
          var
            lIndex : TConstExprInt;
          begin
            if Assigned(ALabel^.Less) then
              GenItem(AList,ALabel^.Less);

            { fill possible hole }
            lIndex:=lLastValue+1;
            while lIndex<=ALabel^.LowValue-1 do
              begin
                AList.concat(TAIConst.Create_type_sym(lLabelType,FElseLabel));
                lIndex:=lIndex+1;
              end;
            lIndex:=ALabel^.LowValue;
            while lIndex<=ALabel^.HighValue do
              begin
                AList.concat(TAIConst.Create_type_sym(lLabelType,BlockLabel(ALabel^.BlockID)));
                lIndex:=lIndex+1;
              end;
            lLastValue:=ALabel^.HighValue;
            if Assigned(ALabel^.Greater) then
              GenItem(AList,ALabel^.Greater);
          end;

      begin
        lLowValue:=0;
        lHighValue:=0;
        lOldMin:=0;
        lLastValue:=AMin;
        { This generates near pointers on i8086 }
        lLabelType:=aitconst_ptr;
        lOpCGSize:=Def_CGSize(FOpSize);

        lAlmostExhaustive := False;

        if not(FJumpTableNoRange) then
          begin

            GetRange(Left.ResultDef,lLowValue,lHighValue);
            lRange := aint(AMax)-aint(AMin);

            if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
              { Limit size of jump tables for small enumerations so they have
                to be at least two-thirds full before being considered for the
                "almost exhaustive" treatment }
              lExhaustiveLimit := min(cExhaustiveLimitBase, LabelCoverage shl 1)
            else
              lExhaustiveLimit := cExhaustiveLimitBase;

            { If true, then this indicates that almost every possible value of x is covered by
              a label.  As such, it's more cost-efficient to remove the initial range check and
              instead insert the remaining values into the jump table, pointing at elselabel. [Kit] }
            if ((lHighValue - lLowValue) - lRange <= lExhaustiveLimit) then
              begin
                lOldMin := AMin;
                AMin := lLowValue.svalue;
                lAlmostExhaustive := True;
              end
            else
              begin
                { a <= x <= b <-> unsigned(x-a) <= (b-a) }
                cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpCGSize,aint(AMin),FRegister);
                { case expr greater than max_ => goto elselabel }
                cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpCGSize,OC_A,aint(AMax)-aint(AMin),FRegister,FElseLabel);
                AMin:=0;
                { do not sign extend when we load the index register, as we applied an offset above }
                lOpCGSize:=TCgSize2Unsigned[lOpCGSize];
              end;
          end;

        CurrentAsmData.getdatalabel(lTableLabel);
        { make it a 32bit register }
        lIndexReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,FRegister,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpCGSize,OS_INT,FRegister,lIndexReg);
        { create reference }
        Reference_Reset_Symbol(lReference,lTableLabel,0,sizeof(PInt),[]);
        lReference.Offset:=(-aint(AMin))*sizeof(aint);
        lReference.Index:=lIndexReg;

        lReference.ScaleFactor:=sizeof(aint);


        if (not (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim])) and
           (cs_create_pic in CurrentSettings.ModuleSwitches) then
          begin
            lLabelType:=aitconst_gotoff_symbol;
            lJumpReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
            cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,lReference,lJumpReg);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_ADDR,CurrentProcInfo.got,lJumpReg);
            emit_reg(A_JMP,S_NO,lJumpReg);
            include(CurrentProcInfo.Flags,pi_needs_got);
          end
        else
          emit_ref(A_JMP,S_NO,lReference);
        { generate jump table }
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
          lJumpTableList:=CurrentAsmData.asmlists[al_const]
        else
          lJumpTableList:=CurrentProcInfo.AktLocalData;
        new_section(lJumpTableList,sec_rodata,CurrentProcInfo.procdef.MangledName,sizeof(aint));
        lJumpTableList.concat(TAILabel.Create(lTableLabel));

        if lAlmostExhaustive then
          begin
            { Fill the table with the values below _min }
            lValue := lLowValue.svalue;
            while lValue < lOldMin do
              begin
                lJumpTableList.concat(TAIConst.Create_type_sym(lLabelType, FElseLabel));
                Inc(lValue);
              end;

            GenItem(lJumpTableList,ARootLabel);

            { Fill the table with the values above _max }
            { Subtracting one from hv and not adding 1 to max averts the risk of an overflow }
            lValue := AMax;
            lHighValue := lHighValue - 1;
            while lValue <= lHighValue.svalue do
              begin
                lJumpTableList.concat(TAIConst.Create_type_sym(lLabelType, FElseLabel));
                Inc(lValue);
              end;
          end
        else
          GenItem(lJumpTableList,ARootLabel)
      end;


    procedure TX86CaseNode.GenLinearList(ARootLabel : PCaseLabel);
      var
        lFirst : Boolean;
        lLastRange : Boolean;
        lLastValue : TConstExprInt;
        lLessCondition,lLessEqualCondition : TResFlags;
        lOpCGSize: TCgSize;

        procedure GenItem(ALabel : PCaseLabel);
          var
             lRange, lGap, lExtra: aint;
          begin
             if Assigned(ALabel^.Less) then
               GenItem(ALabel^.Less);
             { need we to test the first value }
             if lFirst and (ALabel^.LowValue>Get_Min_Value(Left.ResultDef)) then
               begin
                 cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpCGSize,FJumpLess,aint(ALabel^.LowValue.svalue),FRegister,FElseLabel);
               end;
             if ALabel^.LowValue=ALabel^.HighValue then
               begin
                  if ALabel^.LowValue-lLastValue=0 then
                    cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpCGSize, OC_EQ,0,FRegister,BlockLabel(ALabel^.BlockID))
                  else
                    begin
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, lOpCGSize, aint(ALabel^.LowValue.svalue-lLastValue.svalue), FRegister);
                      cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,BlockLabel(ALabel^.BlockID));
                      cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    end;
                  lLastValue:=ALabel^.LowValue;
                  lLastRange:=false;
               end
             else
               begin
                  lRange := aint(ALabel^.HighValue.svalue - ALabel^.LowValue.svalue);
                  lExtra := 0;
                  { it begins with the smallest label, if the value }
                  { is even smaller then jump immediately to the    }
                  { ELSE-label                                }
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  if lFirst then
                    begin
                       { have we to adjust the first value ? }
                       if (ALabel^.LowValue>Get_Min_Value(Left.ResultDef)) or (Get_Min_Value(Left.ResultDef)<>0) then
                         cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, lOpCGSize, aint(ALabel^.LowValue.svalue), FRegister);
                    end
                  else
                    begin
                      lGap := aint(ALabel^.LowValue.svalue - lLastValue.svalue);
                      { if there is no unused label between the last and the }
                      { present label then the lower limit can be checked    }
                      { immediately. else check the range in between:       }

                      { we need to use A_SUB, if cond_lt uses the carry flags
                        because A_DEC does not set the correct flags, therefor
                        using a_op_const_reg(OP_SUB) is not possible }
                      if (lGap = 1) and (lLessCondition in [F_C,F_NC,F_A,F_AE,F_B,F_BE]) then
                        lExtra := 1
                      else
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, lOpCGSize, lGap, FRegister);
                      { no jump necessary here if the new range starts at
                        at the value following the previous one           }
                      if (lGap <> 1) or
                         (not lLastRange) then
                        cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,lLessCondition,FElseLabel);
                    end;
                  { we need to use A_SUB, if cond_le uses the carry flags
                    because A_DEC does not set the correct flags, therefor
                    using a_op_const_reg(OP_SUB) is not possible }
                  if (lLessEqualCondition in [F_C,F_NC,F_A,F_AE,F_B,F_BE]) and (lRange = 1) then
                    emit_const_reg(A_SUB,TCGSize2OpSize[lOpCGSize], lRange + lExtra, FRegister)
                  else
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, lOpCGSize, lRange + lExtra, FRegister);

                  cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,lLessEqualCondition,BlockLabel(ALabel^.BlockID));
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  lLastValue:=ALabel^.HighValue;
                  lLastRange:=true;
               end;
             lFirst:=false;
             if Assigned(ALabel^.Greater) then
               GenItem(ALabel^.Greater);
          end;

        begin
           lOpCGSize:=Def_CGSize(FOpSize);
           if FWithSign then
             begin
                lLessCondition:=F_L;
                lLessEqualCondition:=F_LE;
             end
           else
              begin
                lLessCondition:=F_B;
                lLessEqualCondition:=F_BE;
             end;
           { do we need to generate cmps? }

           if (FWithSign and (FMinLabel<0)) then

             GenLinearCmpList(ARootLabel)
           else
             begin
                if (LabelCnt>1) or not(cs_opt_level1 in CurrentSettings.OptimizerSwitches) then
                  begin
                    lLastValue:=0;
                    lLastRange:=false;
                    lFirst:=true;
                    GenItem(ARootLabel);
                  end
                else
                  begin
                    { If only one label exists, we can greatly simplify the checks to a simple comparison }
                    if ARootLabel^.LowValue=ARootLabel^.HighValue then
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpCGSize, OC_EQ, TCGInt(ARootLabel^.LowValue.svalue), FRegister, BlockLabel(ARootLabel^.BlockID))
                    else
                      begin
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, lOpCGSize, TCGInt(ARootLabel^.LowValue.svalue), FRegister);
                        cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpCGSize, OC_BE, TCGInt(ARootLabel^.HighValue.svalue - ARootLabel^.LowValue.svalue), FRegister,BlockLabel(ARootLabel^.BlockID));
                      end;
                  end;
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,FElseLabel);
             end;
        end;

      procedure TX86CaseNode.GenJmpTreeEntry(ALabel : PCaseLabel;AParentValue : TConstExprInt);
        var
          lLessLabel,lGreaterLabel : TAsmLabel;
          lGreaterCondition: TResFlags;
          lCompareLow : Boolean;
        begin
           if FWithSign then
             lGreaterCondition:=F_G
           else
             lGreaterCondition:=F_A;
          CurrentAsmData.CurrAsmList.concat(CAIAlign.Create(CurrentSettings.Alignment.JumpAlign));
          cg.A_Label(CurrentAsmData.CurrAsmList,ALabel^.LabelLabel);

          { calculate labels for left and right }
          if ALabel^.Less=nil then
            lLessLabel:=FElseLabel
          else
            lLessLabel:=ALabel^.Less^.LabelLabel;
          if ALabel^.Greater=nil then
            lGreaterLabel:=FElseLabel
          else
            lGreaterLabel:=ALabel^.Greater^.LabelLabel;

          { calculate labels for left and right }
          { no range label: }
          if ALabel^.LowValue=ALabel^.HighValue then
            begin
              if lGreaterLabel=lLessLabel then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,OC_NE,ALabel^.LowValue,FRegister,lLessLabel)
              else
                begin
                  lCompareLow:=ALabel^.LowValue-1<>AParentValue;
                  if lCompareLow then
                    hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpLess,ALabel^.LowValue,FRegister,lLessLabel);
                  if ALabel^.HighValue+1<>AParentValue then
                    begin
                      if lCompareLow then
                        hlcg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,lGreaterCondition,lGreaterLabel)
                      else
                        hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpGreater,ALabel^.LowValue,FRegister,lGreaterLabel);
                    end;
                end;
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,BlockLabel(ALabel^.BlockID));
            end
          else
            begin
              if ALabel^.LowValue-1<>AParentValue then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpLess,ALabel^.LowValue,FRegister,lLessLabel);
              if ALabel^.HighValue+1<>AParentValue then
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpGreater,ALabel^.HighValue,FRegister,lGreaterLabel);
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,BlockLabel(ALabel^.BlockID));
            end;
           if Assigned(ALabel^.Less) then
             GenJmpTreeEntry(ALabel^.Less,ALabel^.LowValue);
           if Assigned(ALabel^.Greater) then
             GenJmpTreeEntry(ALabel^.Greater,ALabel^.HighValue);
        end;


{*****************************************************************************
                              TX86INNODE
*****************************************************************************}

    function TX86InNode.Pass_1 : TNode;
      begin
         Result:=nil;
         { this is the only difference from the generic version }
         ExpectLoc:=LOC_FLAGS;

         FirstPass(Right);
         FirstPass(Left);
         if CodeGenError then
           exit;
      end;

    procedure TX86InNode.Pass_Generate_Code;
       type
         TSetPart=record
           Range : Boolean;      {Part is a range.}
           Start,Stop : Byte;    {Start/stop when range; Stop=element when an element.}
         end;
       var
         lReg, lReg2,
         lLeftReg   : TRegister;
         lOpSize     : TCgSize;
         lOpDef      : TOrdDef;
         lOriginalOpSize  : TCgSize;
         lSetParts   : array[1..8] of TSetPart;
         lSetBase    : aint;
         lAdjustment : LongInt;
         lLabel,lLabel2       : TAsmLabel;
         lIndex,lPartCount : Byte;
         lGenerateJumps,
         lUseSmall,
         lHasRanges     : Boolean;
{$ifdef CORRECT_SET_IN_FPC}
         lAsmOp         : TAsmOp;
{$endif CORRECT_SET_IN_FPC}


         function AnalizeSet(ASet:PConstSet;AIsSmall:Boolean):Boolean;
           var
             lCompareCount,lMaxCompareCount:Word;
             lIndex:Byte;
           begin
             if TNormalSet(ASet^)=[] then
                {The expression...
                    if expr in []
                 ...is always false. It should be optimized away in the
                 resultdef pass, and thus never occur here. Since we
                 do generate wrong code for it, do internalerror.}
                InternalError(2002072301);
             AnalizeSet:=false;
             lHasRanges:=false;
             lPartCount:=0;
             lCompareCount:=0;
             { Lots of comparisons take a lot of time, so do not allow
               too much comparisons. 8 comparisons are, however, still
               smaller than emitting the set }
             if cs_opt_size in CurrentSettings.OptimizerSwitches then
               lMaxCompareCount:=8
             else
               lMaxCompareCount:=5;
             { when smallset is possible allow only 3 compares the smallset
               code is for littlesize also smaller when more compares are used }
             if AIsSmall then
               lMaxCompareCount:=3;
             for lIndex:=0 to 255 do
              if lIndex in TNormalSet(ASet^) then
               begin
                 if (lPartCount=0) or (lIndex<>lSetParts[lPartCount].Stop+1) then
                  begin
                  {Set element is a separate element.}
                    inc(lCompareCount);
                    if lCompareCount>lMaxCompareCount then
                         exit;
                    inc(lPartCount);
                    lSetParts[lPartCount].Range:=false;
                    lSetParts[lPartCount].Stop:=lIndex;
                  end
                 else
                  {Set element is part of a range.}
                  if not lSetParts[lPartCount].Range then
                   begin
                     {Transform an element into a range.}
                     lSetParts[lPartCount].Range:=true;
                     lSetParts[lPartCount].Start:=lSetParts[lPartCount].Stop;
                     lSetParts[lPartCount].Stop:=lIndex;
                     lHasRanges := true;
                   end
                  else
                   begin
                    {Extend a range.}
                    lSetParts[lPartCount].Stop:=lIndex;
                   end;
              end;
             AnalizeSet:=true;
           end;



       begin
         lHasRanges:=false;
         lPartCount:=0;
         fillchar(lSetParts,sizeof(lSetParts),0);

         { We check first if we can generate jumps, this can be done
           because the resultdef is already set in firstpass }

         { check if we can use smallset operation using btl which is limited
           to 32 bits, the left side may also not contain higher values or be signed !! }
         lUseSmall:=Is_SmallSet(Right.ResultDef) and
                    not Is_Signed(Left.ResultDef) and
                    ((Left.ResultDef.typ=orddef) and (TOrdDef(Left.ResultDef).high.svalue<32) or
                     (Left.ResultDef.typ=enumdef) and (TEnumDef(Left.ResultDef).max<32));

         { Can we generate jumps? Possible for all types of sets }
         lGenerateJumps:=(Right.NodeType=setconstn) and
                   AnalizeSet(TSetConstNode(Right).ValueSet,lUseSmall);
         { calculate both operators }
         { the complex one first }
         { not in case of genjumps, because then we don't secondpass    }
         { right at all (so we have to make sure that "right" really is }
         { "right" and not "swapped left" in that case)                 }
         if not(lGenerateJumps) then
           FirstComplex(self);
         SecondPass(Left);
         { Only process the right if we are not generating jumps }
         if not lGenerateJumps then
          begin
            SecondPass(Right);
          end;
         if CodeGenError then
          exit;

         { of course not commutative }
         if nf_swapped in Flags then
          SwapLeftRight;

         lOriginalOpSize := Def_CGSize(Left.ResultDef);

         lOpSize := OS_32;

         if Is_Signed(Left.ResultDef) then
           lOpSize := TCgSize(ord(lOpSize)+(ord(OS_S8)-ord(OS_8)));
         lOpDef:=CGSize_OrdDef(lOpSize);

         if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE,LOC_CONSTANT]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,true);
         if (Right.Location.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Left.ResultDef,lOpDef,true);

         if lGenerateJumps then
          begin
            { It gives us advantage to check for the set elements
              separately instead of using the SET_IN_BYTE procedure.
              To do: Build in support for LOC_JUMP }

            { load and zero or sign extend as necessary }
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
            lLeftReg:=Left.Location.Register;

            { Get a label to jump to the end }
            Location_Reset(Location,LOC_FLAGS,OS_NO);

            { It's better to use the zero flag when there are
              no ranges }
            if lHasRanges then
              Location.ResFlags:=F_C
            else
              Location.ResFlags:=F_E;

            CurrentAsmData.getjumplabel(lLabel);

            { how much have we already subtracted from the x in the  }
            { "x in [y..z]" expression                               }
            lAdjustment := 0;

            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

            for lIndex:=1 to lPartCount do
             if lSetParts[lIndex].Range then
              { use fact that a <= x <= b <=> cardinal(x-a) <= cardinal(b-a) }
              begin
                { is the range different from all legal values? }
                if (lSetParts[lIndex].Stop-lSetParts[lIndex].Start <> 255) or not (lOriginalOpSize = OS_8) then
                  begin
                    { yes, is the lower bound <> 0? }
                    if (lSetParts[lIndex].Start <> 0) then
                      begin
                        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
                        lReg:=Left.Location.Register;
                        lLeftReg:=lReg;
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpSize,lSetParts[lIndex].Start-lAdjustment,lLeftReg);
                      end;

                    { new total value subtracted from x:            }
                    { adjustment + (setparts[i].start - adjustment) }
                    lAdjustment := lSetParts[lIndex].Start;

                    { check if result < b-a+1 (not "result <= b-a", since }
                    { we need a carry in case the element is in the range }
                    { (this will never overflow since we check at the     }
                    { beginning whether stop-start <> 255)                }
                    cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpSize,OC_B,lSetParts[lIndex].Stop-lSetParts[lIndex].Start+1,lLeftReg,lLabel);
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  end
                else
                  { if setparts[i].start = 0 and setparts[i].stop = 255,  }
                  { it's always true since "in" is only allowed for bytes }
                  begin
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STC,S_NO));
                    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel);
                  end;
              end
             else
              begin
                { Emit code to check if left is an element }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,TCGSize2OpSize[lOpSize],lSetParts[lIndex].Stop-lAdjustment,
                  lLeftReg));
                { Result should be in carry flag when ranges are used }
                if lHasRanges then
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STC,S_NO));
                { If found, jump to end }
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,lLabel);
              end;
             if lHasRanges and
                { if the last one was a range, the carry flag is already }
                { set appropriately                                      }
                not(lSetParts[lPartCount].Range) then
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
             { To compensate for not doing a second pass }
             Right.Location.Reference.Symbol:=nil;
             { Now place the end label }
             cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
          end
         else
          begin
            Location_Reset(Location,LOC_FLAGS,OS_NO);
            lSetBase:=TSetDef(Right.ResultDef).SetBase;

            { We will now generated code to check the set itself, no jmps,
              handle smallsets separate, because it allows faster checks }
            if lUseSmall then
             begin
               if Left.Location.Loc=LOC_CONSTANT then
                begin
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  Location.ResFlags:=F_NE;
                  case Right.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER:
                      begin
                         emit_const_reg(A_TEST,TCGSize2OpSize[Right.Location.Size],
                           1 shl ((Left.Location.Value-lSetBase) and 31),Right.Location.Register);
                      end;
                    LOC_REFERENCE,
                    LOC_CREFERENCE :
                      begin
                        emit_const_ref(A_TEST,TCGSize2OpSize[Right.Location.Size],1 shl ((Left.Location.Value-lSetBase) and 31),
                           Right.Location.Reference);
                      end;
                    else
                      InternalError(200203312);
                  end;
                end
               else
                begin

                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,U32IntType,true);
                  Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,U32IntType,Left.Location,lSetBase);

                  if (TCgSize2Size[Right.Location.Size] < lOpDef.Size) or
                    (Right.Location.Loc = LOC_CONSTANT) or
                    { bt ...,[mem] is slow, see #40039, so try to use a register if we are not optimizing for size }
                    ((Right.ResultDef.Size<=U32IntType.Size) and not(cs_opt_size in CurrentSettings.OptimizerSwitches)) then
                    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,U32IntType,true);

                  lReg:=Left.Location.Register;

                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  case Right.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER :
                      begin
                        emit_reg_reg(A_BT,S_L,lReg,Right.Location.Register);
                      end;
                     LOC_CREFERENCE,
                     LOC_REFERENCE :
                       begin
                         emit_reg_ref(A_BT,S_L,lReg,Right.Location.Reference);
                       end;
                     else
                       InternalError(2002032210);
                  end;
                  Location.ResFlags:=F_C;

                end;
             end
            else
             begin
               if Right.Location.Loc=LOC_CONSTANT then
                begin

                  Location.ResFlags:=F_C;
                  CurrentAsmData.getjumplabel(lLabel);
                  CurrentAsmData.getjumplabel(lLabel2);

                  { load constants to a register }
                  if (Left.Location.Loc=LOC_CONSTANT) or
                     (lSetBase<>0) then
                    begin
                      hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,true);
                      Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,lOpDef,Left.Location,lSetBase);
                    end;

                  case Left.Location.Loc of
                     LOC_REGISTER,
                     LOC_CREGISTER:
                       begin
                          lReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Left.Location.Register,lOpSize);
                          cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,lOpSize,Left.Location.Register,lReg);
                          cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpSize,OC_BE,31,lReg,lLabel);
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                          { reset carry flag }
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel2);
                          cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                          { We have to load the value into a register because
                            btl does not accept values only refs or regs (PFV) }
                          lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,Right.Location.Value,lReg2);
                          emit_reg_reg(A_BT,S_L,lReg,lReg2);
                       end;
                     else
                       begin
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                          emit_const_ref(A_CMP,TCGSize2OpSize[lOriginalOpSize],31,Left.Location.Reference);
                          cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_BE,lLabel);
                          { reset carry flag }
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel2);
                          cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                          lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Left.Location.Reference,lReg);
                          { We have to load the value into a register because
                            btl does not accept values only refs or regs (PFV) }
                          lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,Right.Location.Value,lReg2);
                          emit_reg_reg(A_BT,S_L,lReg,lReg2);
                       end;
                  end;
                  cg.A_Label(CurrentAsmData.CurrAsmList,lLabel2);

                end { of right.location.loc=LOC_CONSTANT }
               { do search in a normal set which could have >32 elementsm
                 but also used if the left side contains values > 32 or < 0 }
               else if Left.Location.Loc=LOC_CONSTANT then
                begin
                  if (Left.Location.Value<lSetBase) or (((Left.Location.Value-lSetBase) shr 3) >= Right.ResultDef.Size) then
                    {should be caught earlier }
                    InternalError(2007020201);

                  Location.ResFlags:=F_NE;
                  case Right.Location.Loc of
                    LOC_REFERENCE,LOC_CREFERENCE:
                      begin
                        inc(Right.Location.Reference.Offset,(Left.Location.Value-lSetBase) shr 3);
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                        emit_const_ref(A_TEST,S_B,1 shl ((Left.Location.Value-lSetBase) and 7),Right.Location.Reference);
                      end;
                    LOC_REGISTER,LOC_CREGISTER:
                      begin
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                        emit_const_reg(A_TEST,TCGSize2OpSize[Right.Location.Size],1 shl (Left.Location.Value-lSetBase),Right.Location.Register);
                      end;
                    else
                      InternalError(2007051901);
                  end;
                end
               else
                begin

                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
                  Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,lOpDef,Left.Location,lSetBase);

                  if (Right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                    { bt ...,[mem] is slow, see #40039, so try to use a register if we are not optimizing for size }
                    ((Right.ResultDef.Size<=lOpDef.Size) and not(cs_opt_size in CurrentSettings.OptimizerSwitches)) then
                    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,lOpDef,true);

                  lLeftReg:=Left.Location.Register;

                  if (lOpSize >= OS_S8) or { = if signed }
                     ((Left.ResultDef.typ=orddef) and
                      ((TOrdDef(Left.ResultDef).low < Int64(TSetDef(Right.ResultDef).SetBase)) or
                       (TOrdDef(Left.ResultDef).high > Int64(TSetDef(Right.ResultDef).SetMax)))) or
                     ((Left.ResultDef.typ=enumdef) and
                      ((TEnumDef(Left.ResultDef).min < aint(TSetDef(Right.ResultDef).SetBase)) or
                       (TEnumDef(Left.ResultDef).max > aint(TSetDef(Right.ResultDef).SetMax)))) then
                    begin
                      { we have to check if the value is < 0 or > setmax }

                      CurrentAsmData.getjumplabel(lLabel);
                      CurrentAsmData.getjumplabel(lLabel2);

                      { BE will be false for negative values }
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpSize,OC_BE,TSetDef(Right.ResultDef).SetMax-TSetDef(Right.ResultDef).SetBase,lLeftReg,lLabel);
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      { reset carry flag }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLC,S_NO));
                      cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel2);

                      cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);

                      lLeftReg:=Left.Location.Register;
                      case Right.Location.Loc of
                        LOC_REGISTER, LOC_CREGISTER :
                          emit_reg_reg(A_BT,S_L,lLeftReg,Right.Location.Register);
                        LOC_CREFERENCE, LOC_REFERENCE :
                          emit_reg_ref(A_BT,S_L,lLeftReg,Right.Location.Reference);
                      else
                        InternalError(2007020301);
                      end;

                      cg.A_Label(CurrentAsmData.CurrAsmList,lLabel2);

                      Location.ResFlags:=F_C;
                    end
                  else
                    begin
                      cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                      case Right.Location.Loc of
                        LOC_REGISTER, LOC_CREGISTER :
                          emit_reg_reg(A_BT,S_L,lLeftReg,Right.Location.Register);
                        LOC_CREFERENCE, LOC_REFERENCE :
                          emit_reg_ref(A_BT,S_L,lLeftReg,Right.Location.Reference);
                      else
                        InternalError(2007020302);
                      end;
                      Location.ResFlags:=F_C;
                    end;

                end;
             end;
          end;
          if not lGenerateJumps then
            Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
       end;

begin
   CInNode:=TX86InNode;
   CCaseNode:=TX86CaseNode;
end.
