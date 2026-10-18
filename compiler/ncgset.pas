{
    Copyright (c) 1998-2002 by Florian Klaempfl and Carl Eric Codere

    Generate generic assembler for in set/case labels

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
unit ncgset;

{$i fpcdefs.inc}

interface

    uses
       GlobType,Globals,ConstExp,symtype,
       node,nset,cpubase,cgbase,cgutils,cgobj,aasmbase,aasmtai,AAsmData;

    type
       TCGSetElementNode = class(TSetElementNode)
          procedure Pass_Generate_Code;override;
       end;


       Tsetpart=record
         Range : Boolean;      {Part is a range.}
         Start,Stop : Byte;    {Start/stop when range; Stop=element when an element.}
       end;
       Tsetparts=array[1..8] of TSetPart;

       { tcginnode }

       TCGInNode = class(TInNode)
         procedure In_SmallSet(AOpDef: TDef; ASetBase: aint); virtual;

         function Pass_1: TNode;override;
         procedure Pass_Generate_Code;override;
       protected
         function CheckGenJumps(out ASetParts: TSetParts; out APartCount: Byte; out AUseSmall: Boolean): Boolean; virtual;
         function AnalizeSet(const ASet:TConstSet;out ASetParts: TSetParts; out APartCount: Byte;AIsSmall:Boolean):Boolean;virtual;
         procedure In_Reg_Const(AUnsignedOpDef: TDef; AOpSize: TCgSize);virtual;
       end;

       TCGCaseNode = class(TCaseNode)
          {
            Emits the case node statement. Contrary to the intel
            80x86 version, this version does not emit jump tables,
            because of portability problems.
          }
          procedure Pass_Generate_Code;override;

        protected
          FWithSign : Boolean;
          FOpSize : TDef;
          FJumpGreater,FJumpLess,FJumpLessEqual : TOpCmp;
          { register with case expression }
          FRegister,FRegister2 : TRegister;
          FEndLabel,FElseLabel : TAsmLabel;

          { true, if we can omit the range check of the jump table }
          FJumpTableNoRange : Boolean;
          { has the implementation jumptable support }
          FMinLabel : TConstExprInt;

          function GetBranchLabel(ABlock: TNode; out ALabel: TAsmLabel): Boolean;

          function  BlockLabel(ABlockID:LongInt):TAsmLabel;
          procedure OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);virtual;
          function  Has_JumpTable : Boolean;virtual;
          procedure GenJumpTable(ARootLabel : PCaseLabel;AMin,AMax : Int64); virtual;
          procedure GenLinearList(ARootLabel : PCaseLabel); virtual;
          procedure GenLinearCmpList(ARootLabel : PCaseLabel); virtual;

         procedure GenJmpTreeEntry(ALabel : PCaseLabel;AParentValue : TConstExprInt); virtual;
         procedure GenJmpTree(ARoot : PCaseLabel); virtual;
       end;


implementation

    uses
      Verbose,
      CUtils,
      symconst,symdef,SymSym,defutil,
      pass_2,tgobj,
      nbas,ncon,ncgflw,
      ncgutil,hlcgobj;


{*****************************************************************************
                          TCGSETELEMENTNODE
*****************************************************************************}

    procedure TCGSetElementNode.Pass_Generate_Code;
      begin
        { load the set element's value }
        SecondPass(Left);

        { also a second value ? }
        if Assigned(Right) then
          InternalError(2015111106);

        { we don't modify the left side, we only check the location type; our
          parent node (an add-node) will use the resulting location to perform
          the set operation without creating an intermediate set }
        Location_Copy(Location,Left.Location);
      end;


{*****************************************************************************
*****************************************************************************}

  function TCGInNode.AnalizeSet(const ASet:TConstSet; out ASetParts:TSetParts; out APartCount: Byte; AIsSmall:Boolean):Boolean;
    var
      lCompareCount,lMaxCompareCount:Word;
      lIndex:Byte;
    begin
      AnalizeSet:=false;
      fillchar(ASetParts,sizeof(ASetParts),0);
      APartCount:=0;
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
        if lIndex in ASet then
          begin
            if (APartCount=0) or (lIndex<>ASetParts[APartCount].Stop+1) then
              begin
                {Set element is a separate element.}
                inc(lCompareCount);
                if lCompareCount>lMaxCompareCount then
                  exit;
                inc(APartCount);
                ASetParts[APartCount].Range:=false;
                ASetParts[APartCount].Stop:=lIndex;
              end
            else
              {Set element is part of a range.}
              if not ASetParts[APartCount].Range then
                begin
                  {Transform an element into a range.}
                  ASetParts[APartCount].Range:=true;
                  ASetParts[APartCount].Start:=ASetParts[APartCount].Stop;
                  ASetParts[APartCount].Stop:=lIndex;
                  { there's only one compare per range anymore. Only a }
                  { sub is added, but that's much faster than a        }
                  { cmp/jcc combo so neglect its effect                }
{                  inc(compares);
                  if compares>maxcompares then
                   exit; }
                end
              else
                begin
                  {Extend a range.}
                  ASetParts[APartCount].Stop:=lIndex;
                end;
          end;
      AnalizeSet:=true;
    end;


    procedure TCGInNode.In_Reg_Const(AUnsignedOpDef: TDef; AOpSize: TCgSize);
      var
        lReg: TRegister;
      begin
        { emit bit test operation -- warning: do not use
          location_force_reg() to force a set into a register, except
          to a register of the same size as the set. The reason is
          that on big endian systems, this would require moving the
          set to the most significant part of the new register,
          and location_force_register can't do that (it does not
          know the type).

         a_bit_test_reg_loc_reg() properly takes into account the
         size of the set to adjust the register index to test }
        hlcg.A_Bit_Test_Reg_Loc_Reg(CurrentAsmData.CurrAsmList,
          AUnsignedOpDef, Right.ResultDef, AUnsignedOpDef,
          Left.Location.Register, Right.Location, Location.Register);

        { this may have resulted in an undefined value if left.location.register
          was >= size of right.location, but we'll mask the value to zero below
          in that case -> okay }
        hlcg.G_Undefined_Ok(CurrentAsmData.CurrAsmList,AUnsignedOpDef,Location.Register);

        { now zero the result if left > nr_of_bits_in_right_register }
        lReg := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList, AUnsignedOpDef);
        { if left > tcgsize2size[opsize]*8 then hr := 0 else hr := $ffffffff }
        { (left.location.size = location.size at this point) }
        hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList, OP_SUB, AUnsignedOpDef,
          TCgSize2Size[AOpSize]*8, Left.Location.Register, lReg);
        hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SAR, AUnsignedOpDef, (TCgSize2Size
          [AOpSize]*8)-1, lReg);


          { if left > tcgsize2size[opsize]*8-1, then result := 0 else result := result of bit test }
        hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList, OP_AND, AUnsignedOpDef, lReg,
          Location.Register);
      end;


    procedure TCGInNode.In_SmallSet(AOpDef: TDef; ASetBase: aint);
      begin
        { location is always LOC_REGISTER }
        Location_Reset(Location, LOC_REGISTER, Def_CGSize(ResultDef));
        { allocate a register for the result }
        Location.Register := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList, ResultDef);
        {****************************  SMALL SET **********************}
        if Left.Location.Loc=LOC_CONSTANT then
          begin
            hlcg.A_Bit_Test_Const_Loc_Reg(CurrentAsmData.CurrAsmList,
             Right.ResultDef, ResultDef,
              Left.Location.Value-ASetBase, Right.Location,
              Location.Register);
          end
        else
          begin
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, Left.Location,
             Left.ResultDef, AOpDef, true);
            Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList, AOpDef, Left.Location,
             ASetBase);
            hlcg.A_Bit_Test_Reg_Loc_Reg(CurrentAsmData.CurrAsmList, AOpDef,
              Right.ResultDef, ResultDef, Left.Location.Register, Right.Location,
               Location.Register);
          end;
      end;


    function TCGInNode.CheckGenJumps(out ASetParts: TSetParts; out APartCount: Byte;out AUseSmall: Boolean): Boolean;
      begin
         { check if we can use smallset operation using btl which is limited
           to 32 bits, the left side may also not contain higher values !! }
         AUseSmall:=Is_SmallSet(Right.ResultDef) and
                    not Is_Signed(Left.ResultDef) and
                    ((Left.ResultDef.typ=orddef) and (TOrdDef(Left.ResultDef).high<32) or
                     (Left.ResultDef.typ=enumdef) and (TEnumDef(Left.ResultDef).max<32));

         { Can we generate jumps? Possible for all types of sets }
         CheckGenJumps:=(Right.NodeType=setconstn) and
                   AnalizeSet(TSetConstNode(Right).ValueSet^,ASetParts,APartCount,AUseSmall);
      end;


    function TCGInNode.Pass_1: TNode;
      var
        lSetParts: TSetParts;
        lPartCount: Byte;
        lUseSmall: Boolean;
      begin
        Result := inherited Pass_1;
        if not(Assigned(Result)) and
          CheckGenJumps(lSetParts,lPartCount,lUseSmall) then
          ExpectLoc := LOC_JUMP;
      end;

    procedure TCGInNode.Pass_Generate_Code;
       var
         lAdjustment,
         lSetBase    : aint;
         lLabel, lLabel2      : TAsmLabel;
         lReg,
         lLeftReg   : TRegister;
         lSetParts   : TSetParts;
         lOpSize     : TCgSize;
         lOpDef      : TDef;
         lUnsignedOpSize    : TCgSize;
         lUnsignedOpDef     : TDef;
         lOriginalOpSize  : TCgSize;
         lGenerateJumps,
         lUseSmall  : Boolean;
         lIndex,lPartCount : Byte;
         lNeedsLabel : Boolean;
       begin
         lLabel2:=nil;

         { We check first if we can generate jumps, this can be done
           because the resultdef is already set in firstpass }

         lGenerateJumps := CheckGenJumps(lSetParts,lPartCount,lUseSmall);

         lOriginalOpSize := Def_CGSize(Left.ResultDef);


           begin
             lUnsignedOpSize := OS_32;
             lUnsignedOpDef := U32IntType;
             if Is_Signed(Left.ResultDef) then
               begin
                 lOpSize := OS_S32;
                 lOpDef := S32IntType;
               end
             else
               begin
                 lOpSize := lUnsignedOpSize;
                 lOpDef := lUnsignedOpDef;
               end;
           end;
         lNeedsLabel := false;

         if not lGenerateJumps then
           { calculate both operators }
           { the complex one first }
           { not in case of genjumps, because then we don't secondpass      }
           { right at all (so we have to make sure that "right" really is   }
           { "right" and not "swapped left" in that case)                   }
           FirstComplex(self);

         SecondPass(Left);
         if (Left.ExpectLoc=LOC_JUMP)<>
            (Left.Location.Loc=LOC_JUMP) then
           InternalError(2007070101);

         { Only process the right if we are not generating jumps }
         if not lGenerateJumps then
           SecondPass(Right);
         if CodeGenError then
           exit;

         { of course not commutative }
         if nf_swapped in Flags then
          SwapLeftRight;

         lSetBase:=TSetDef(Right.ResultDef).SetBase;
         if lGenerateJumps then
           begin
             { location is always LOC_JUMP }
             CurrentAsmData.getjumplabel(lLabel);
             CurrentAsmData.getjumplabel(lLabel2);
             Location_Reset_Jump(Location,lLabel,lLabel2);

             { If register is used, use only lower 8 bits }
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
             lLeftReg := Left.Location.Register;

             { how much have we already subtracted from the x in the  }
             { "x in [y..z]" expression                               }
             lAdjustment := 0;
             lReg:=NR_NO;

             for lIndex:=1 to lPartCount do
              if lSetParts[lIndex].Range then
               { use fact that a <= x <= b <=> aword(x-a) <= aword(b-a) }
               begin
                 { is the range different from all legal values? }
                 if (lSetParts[lIndex].Stop-lSetParts[lIndex].Start <> 255) or not (lOriginalOpSize = OS_8) then
                   begin
                     { yes, is the lower bound <> 0? }
                     if (lSetParts[lIndex].Start <> 0) then
                       { we're going to subtract from the left register,    }
                       { so in case of a LOC_CREGISTER first move the value }
                       { to edi (not done before because now we can do the  }
                       { move and subtract in one instruction with LEA)     }
                       if (Left.Location.Loc = LOC_CREGISTER) and
                          (lReg<>lLeftReg) then
                         begin
                           { don't change this back to a_op_const_reg/a_load_reg_reg, since pleftreg must not be modified }
                           lReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpDef);
                           hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpDef,lSetParts[lIndex].Start,lLeftReg,lReg);
                           lLeftReg:=lReg;
                         end
                       else
                         begin
                           { otherwise, the value is already in a register   }
                           { that can be modified                            }
                           hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpDef,
                              lSetParts[lIndex].Start-lAdjustment,lLeftReg)
                         end;
                     { new total value subtracted from x:            }
                     { adjustment + (setparts[i].start - adjustment) }
                     lAdjustment := lSetParts[lIndex].Start;

                     { check if result < b-a+1 (not "result <= b-a", since }
                     { we need a carry in case the element is in the range }
                     { (this will never overflow since we check at the     }
                     { beginning whether stop-start <> 255)                }
                     hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lUnsignedOpDef, OC_B,
                       lSetParts[lIndex].Stop-lSetParts[lIndex].Start+1,lLeftReg,Location.TrueLabel);
                   end
                 else
                   { if setparts[i].start = 0 and setparts[i].stop = 255,  }
                   { it's always true since "in" is only allowed for bytes }
                   begin
                     hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,Location.TrueLabel);
                   end;
               end
              else
               begin
                 { Emit code to check if left is an element }
                 hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpDef, OC_EQ,
                       lSetParts[lIndex].Stop-lAdjustment,lLeftReg,Location.TrueLabel);
               end;
              { To compensate for not doing a second pass }
              Right.Location.Reference.Symbol:=nil;
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,Location.FalseLabel);
           end
         else
         {*****************************************************************}
         {                     NO JUMP TABLE GENERATION                    }
         {*****************************************************************}
           begin
             { We will now generated code to check the set itself, no jmps,
               handle smallsets separate, because it allows faster checks }
             if lUseSmall then
               begin
                 In_SmallSet(lOpDef, lSetBase);
               end
             else
               {************************** NOT SMALL SET ********************}
               begin
                 { location is always LOC_REGISTER }
                 Location_Reset(Location, LOC_REGISTER, lUnsignedOpSize{def_cgsize(resultdef)});
                 { allocate a register for the result }
                 Location.Register := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList, lUnsignedOpDef);

                 if (Right.Location.Loc=LOC_CONSTANT) and
                      (lOpSize < OS_S8) and { = if unsigned }
                      (((Left.ResultDef.typ=orddef) and
                        (TOrdDef(Left.ResultDef).low >= Int64(TSetDef(Right.ResultDef).SetBase))) or
                       ((Left.ResultDef.typ=enumdef) and
                        (TEnumDef(Left.ResultDef).min >= aint(TSetDef(Right.ResultDef).SetBase)))) then
                   begin
                     { can it actually occur currently? CEC }
                     { yes: "if bytevar in [1,3,5,7,9,11,13,15]" (JM) }

                     { note: this code assumes that left in [0..255], which is a valid }
                     { assumption (other cases will be caught by range checking) (JM)  }

                     { load left in register }
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lUnsignedOpDef,true);
                     Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,lUnsignedOpDef,Left.Location,lSetBase);
                     In_Reg_Const(lUnsignedOpDef, lOpSize);
                   end { of right.location.loc=LOC_CONSTANT }
                 { do search in a normal set which could have >32 elements
                   but also used if the left side contains higher values > 32 }
                 else if (Left.Location.Loc=LOC_CONSTANT) then
                   begin
                     if (Left.Location.Value < lSetBase) or (((Left.Location.Value-lSetBase) shr 3) >= Right.ResultDef.Size) then
                       {should be caught earlier }
                       InternalError(2007020402);

                     hlcg.A_Bit_Test_Const_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,lUnsignedOpDef,Left.Location.Value-lSetBase,
                       Right.Location,Location.Register);
                   end
                 else
                   begin
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,true);
                     Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,lOpDef,Left.Location,lSetBase);
                     lLeftReg := Left.Location.Register;

                     if (lOpSize >= OS_S8) or { = if signed }
                        ((Left.ResultDef.typ=orddef) and
                         ((TOrdDef(Left.ResultDef).low < Int64(TSetDef(Right.ResultDef).SetBase)) or
                          (TOrdDef(Left.ResultDef).high > Int64(TSetDef(Right.ResultDef).SetMax)))) or
                        ((Left.ResultDef.typ=enumdef) and
                         ((TEnumDef(Left.ResultDef).min < aint(TSetDef(Right.ResultDef).SetBase)) or
                          (TEnumDef(Left.ResultDef).max > aint(TSetDef(Right.ResultDef).SetMax)))) then
                       begin
                         CurrentAsmData.getjumplabel(lLabel);
                         CurrentAsmData.getjumplabel(lLabel2);
                         lNeedsLabel := True;

                         hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpDef, OC_BE, TSetDef(Right.ResultDef).SetMax-TSetDef(Right.ResultDef).SetBase, lLeftReg, lLabel);

                         hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, lUnsignedOpDef, 0, Location.Register);
                         hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList, lLabel2);

                         hlcg.A_Label(CurrentAsmData.CurrAsmList, lLabel);
                       end;

                     hlcg.A_Bit_Test_Reg_Loc_Reg(CurrentAsmData.CurrAsmList,lOpDef,Right.ResultDef,lUnsignedOpDef,
                       lLeftReg,Right.Location,Location.Register);

                     if lNeedsLabel then
                       begin
                         hlcg.A_Label(CurrentAsmData.CurrAsmList, lLabel2);
                       end
                   end;
{$ifndef cpuhighleveltarget}
                 Location.Size := Def_CGSize(ResultDef);
                 Location.Register := cg.MakeRegSize(CurrentAsmData.CurrAsmList, Location.Register, Location.Size);
{$else not cpuhighleveltarget}
                 lReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
                 hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lUnsignedOpDef,ResultDef,Location.Register,lReg);
                 Location.Register:=lReg;
                 Location.Size := Def_CGSize(ResultDef);
{$endif not cpuhighleveltarget}
               end;
           end;
         Location_FreeTemp(CurrentAsmData.CurrAsmList, Right.Location);
       end;

{*****************************************************************************
                            TCGCASENODE
*****************************************************************************}


    { Analyse the nodes following the else label - if empty, change to end label }
    function TCGCaseNode.GetBranchLabel(ABlock: TNode; out ALabel: TAsmLabel): Boolean;
      var
        lLabelSym: TLabelSym;
      begin
        Result := True;

        if not Assigned(ABlock) then
          begin
            { Block doesn't exist / is empty }
            ALabel := FEndLabel;
            Exit;
          end;

        { These optimisations aren't particularly debugger friendly }
        if not (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
          begin
            Result := False;
            CurrentAsmData.getjumplabel(ALabel);
            Exit;
          end;

        while Assigned(ABlock) do
          begin
            case ABlock.NodeType of
              nothingn:
                begin
                  ALabel := FEndLabel;
                  Exit;
                end;
              goton:
                begin
                  lLabelSym := TCGGotoNode(ABlock).LabelSym;
                  if not Assigned(lLabelSym) then
                    InternalError(2018121131);

                  ALabel := TCGLabelNode(TCGGotoNode(ABlock).LabelNode).GetAsmLabel;
                  if Assigned(ALabel) then
                    { Keep tabs on the fact that an actual 'goto' was used }
                    Include(flowcontrol,fc_gotolabel)
                  else
                    Break;
                  Exit;
                end;
              blockn:
                begin
                  ABlock := TBlockNode(ABlock).Left;
                  Continue;
                end;
              statementn:
                begin
                  { If the right node is assigned, then it's a compound block
                    that can't be simplified, so fall through, set Result to
                    False and make a new label }

                  if Assigned(TStatementNode(ABlock).Right) then
                    Break;

                  ABlock := TStatementNode(ABlock).Left;
                  Continue;
                end;
              else
                ;
            end;

            Break;
          end;

        { Create unique label }
        Result := False;
        CurrentAsmData.getjumplabel(ALabel);
      end;


    function TCGCaseNode.BlockLabel(ABlockID:LongInt):TAsmLabel;
      begin
        if not Assigned(Blocks[ABlockID]) then
          InternalError(200411301);
        Result:=PCaseBlock(Blocks[ABlockID])^.BlockLabel;
      end;


    procedure TCGCaseNode.OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);
      begin
        { no changes by default }
      end;


    function TCGCaseNode.Has_JumpTable : Boolean;
      begin
        { No jumptable support in the default implementation }
        Has_JumpTable:=false;
      end;


    procedure TCGCaseNode.GenJumpTable(ARootLabel : PCaseLabel;AMin,AMax : Int64);
      begin
        InternalError(200209161);
      end;


    procedure TCGCaseNode.GenLinearList(ARootLabel : PCaseLabel);

      var
         lFirst : Boolean;
         lLastValue : TConstExprInt;
         lScratchReg: TRegister;
         lNewSize: TCgSize;
         lNewDef: TDef;

      procedure GenSub(AValue:TCGInt);
        begin
          { here, since the sub and cmp are separate we need
            to move the result before subtract to help
            the register allocator
          }
          hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, FOpSize, FOpSize, FRegister, lScratchReg);
          hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList, OP_SUB, FOpSize, AValue, FRegister);
        end;


      procedure GenItem(ALabel : PCaseLabel);

        begin
           if Assigned(ALabel^.Less) then
             GenItem(ALabel^.Less);
           { do we need to test the first value? }
           if lFirst and (ALabel^.LowValue>Get_Min_Value(Left.ResultDef)) then
             hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpLess,TCGInt(ALabel^.LowValue.svalue),FRegister,FElseLabel);
           if ALabel^.LowValue=ALabel^.HighValue then
             begin
               if ALabel^.LowValue-lLastValue=0 then
                 hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,OC_EQ,0,FRegister,BlockLabel(ALabel^.BlockID))
               else
                 begin
                   GenSub(TCGInt(ALabel^.LowValue.svalue-lLastValue.svalue));
                   hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,
                                            OC_EQ,TCGInt(ALabel^.LowValue.svalue-lLastValue.svalue),lScratchReg,BlockLabel(ALabel^.BlockID));
                 end;
               lLastValue:=ALabel^.LowValue;
             end
           else
             begin
                { it begins with the smallest label, if the value }
                { is even smaller then jump immediately to the    }
                { ELSE-label                                }
                if lFirst then
                  begin
                     { have we to adjust the first value ? }
                     if (ALabel^.LowValue>Get_Min_Value(Left.ResultDef)) or (Get_Min_Value(Left.ResultDef)<>0) then
                       GenSub(TCGInt(ALabel^.LowValue.svalue));
                  end
                else
                  begin
                    { if there is no unused label between the last and the }
                    { present label then the lower limit can be checked    }
                    { immediately. else check the range in between:       }
                    GenSub(TCGInt(ALabel^.LowValue.svalue-lLastValue.svalue));
                    hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize,FJumpLess,TCGInt(ALabel^.LowValue.svalue-lLastValue.svalue),lScratchReg,FElseLabel);
                  end;
                GenSub(TCGInt(ALabel^.HighValue.svalue-ALabel^.LowValue.svalue));
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpLessEqual,TCGInt(ALabel^.HighValue.svalue-ALabel^.LowValue.svalue),lScratchReg,BlockLabel(ALabel^.BlockID));
                lLastValue:=ALabel^.HighValue;
             end;
           lFirst:=false;
           if Assigned(ALabel^.Greater) then
             GenItem(ALabel^.Greater);
        end;

      begin
         { do we need to generate cmps? }
         if (FWithSign and (FMinLabel<0)) then
           GenLinearCmpList(ARootLabel)
         else
           begin
              { sign/zero extend the value to a full register before starting to
                subtract values, so that on platforms that don't have
                subregisters of the same size as the value we don't generate
                sign/zero-extensions after every subtraction

                make newsize always signed, since we only do this if the size in
                bytes of the register is larger than the original opsize, so
                the value can always be represented by a larger signed type }
              lNewSize:=TCgSize2Signed[reg_cgsize(FRegister)];
              if TCgSize2Size[lNewSize]>FOpSize.Size then
                begin
                  lNewDef:=CGSize_OrdDef(lNewSize);
                  lScratchReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,lNewDef);
                  hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,FOpSize,lNewDef,FRegister,lScratchReg);
                  FRegister:=lScratchReg;
                  FOpSize:=lNewDef;
                end;
              if (LabelCnt>1) or not(cs_opt_level1 in CurrentSettings.OptimizerSwitches) then
                begin
                  lLastValue:=0;
                  lFirst:=true;
                  lScratchReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,FOpSize);
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  GenItem(ARootLabel);
                end
              else
                begin
                  { If only one label exists, we can greatly simplify the checks to a simple comparison }
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  if ARootLabel^.LowValue=ARootLabel^.HighValue then
                    hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, OC_EQ, TCGInt(ARootLabel^.LowValue.svalue), FRegister, BlockLabel(ARootLabel^.BlockID))
                  else
                    begin
                      lScratchReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,FOpSize);
                      GenSub(TCGInt(ARootLabel^.LowValue.svalue));
                      hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, OC_BE, TCGInt(ARootLabel^.HighValue.svalue-ARootLabel^.LowValue.svalue), FRegister, BlockLabel(ARootLabel^.BlockID))
                    end;
                end;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,FElseLabel);
           end;
      end;


    procedure TCGCaseNode.GenLinearCmpList(ARootLabel : PCaseLabel);

      var
         lLastValue : TConstExprInt;
         lLastWasRange: Boolean;

      procedure GenItem(ALabel : PCaseLabel);

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        var
           lLabel : TAsmLabel;
{$endif not cpu64bitalu and not cpuhighleveltarget}

        begin
           if Assigned(ALabel^.Less) then
             GenItem(ALabel^.Less);
           if ALabel^.LowValue=ALabel^.HighValue then
             begin
{$ifndef cpuhighleveltarget}
{$if defined(cpu32bitalu)}
                if Def_CGSize(FOpSize) in [OS_S64,OS_64] then
                  begin
                     CurrentAsmData.getjumplabel(lLabel);
                     cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, OC_NE, aint(hi(Int64(ALabel^.LowValue.svalue))),FRegister2,lLabel);
                     cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, OC_EQ, aint(lo(Int64(ALabel^.LowValue.svalue))),FRegister, BlockLabel(ALabel^.BlockID));
                     cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                  end
                else
{$endif}
{$endif cpuhighleveltarget}
                  begin
                     hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, OC_EQ, TCGInt(ALabel^.LowValue.svalue),FRegister, BlockLabel(ALabel^.BlockID));
                  end;
                { Reset last here, because we've only checked for one value and need to compare
                  for the next range both the lower and upper bound }
                lLastWasRange := false;
             end
           else
             begin
                { it begins with the smallest label, if the value }
                { is even smaller then jump immediately to the    }
                { ELSE-label                                }
                if not lLastWasRange or (ALabel^.LowValue-lLastValue>1) then
                  begin
{$ifndef cpuhighleveltarget}
{$if defined(cpu32bitalu)}
                     if Def_CGSize(FOpSize) in [OS_64,OS_S64] then
                       begin
                          CurrentAsmData.getjumplabel(lLabel);
                          cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, FJumpLess, aint(hi(Int64(ALabel^.LowValue.svalue))),
                               FRegister2, FElseLabel);
                          cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, FJumpGreater, aint(hi(Int64(ALabel^.LowValue.svalue))),
                               FRegister2, lLabel);
                          { the comparison of the low dword must be always unsigned! }
                          cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, OC_B, aint(lo(Int64(ALabel^.LowValue.svalue))), FRegister, FElseLabel);
                          cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                       end
                     else
{$endif}
{$endif cpuhighleveltarget}
                       begin
                        hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, FJumpLess, TCGInt(ALabel^.LowValue.svalue), FRegister,
                           FElseLabel);
                       end;
                  end;
{$ifndef cpuhighleveltarget}
{$if defined(cpu32bitalu)}
                if Def_CGSize(FOpSize) in [OS_S64,OS_64] then
                  begin
                     CurrentAsmData.getjumplabel(lLabel);
                     cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, FJumpLess, aint(hi(Int64(ALabel^.HighValue.svalue))), FRegister2,
                           BlockLabel(ALabel^.BlockID));
                     cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, FJumpGreater, aint(hi(Int64(ALabel^.HighValue.svalue))), FRegister2,
                           lLabel);
                    cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, OS_32, OC_BE, aint(lo(Int64(ALabel^.HighValue.svalue))), FRegister, BlockLabel(ALabel^.BlockID));
                    cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                  end
                else
{$endif}
{$endif cpuhighleveltarget}
                  begin
                     hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, FJumpLessEqual, TCGInt(ALabel^.HighValue.svalue), FRegister, BlockLabel(ALabel^.BlockID));
                  end;

                lLastValue:=ALabel^.HighValue;
                lLastWasRange := true;
             end;
           if Assigned(ALabel^.Greater) then
             GenItem(ALabel^.Greater);
        end;

      begin
         lLastValue:=0;
         lLastWasRange:=false;
         cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
         GenItem(ARootLabel);
         cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
         hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,FElseLabel);
      end;


      procedure TCGCaseNode.GenJmpTreeEntry(ALabel : PCaseLabel;AParentValue : TConstExprInt);
        var
          lLessLabel,lGreaterLabel : TAsmLabel;
        begin
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
                hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, FOpSize, OC_NE,ALabel^.LowValue,FRegister, lLessLabel)
              else
                begin
                  hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize, FJumpLess,ALabel^.LowValue,FRegister, lLessLabel);
                  hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize, FJumpGreater,ALabel^.LowValue,FRegister, lGreaterLabel);
                end;
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,BlockLabel(ALabel^.BlockID));
            end
          else
            begin
              hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpLess,ALabel^.LowValue, FRegister, lLessLabel);
              hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,FOpSize,FJumpGreater,ALabel^.HighValue,FRegister, lGreaterLabel);
              hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,BlockLabel(ALabel^.BlockID));
            end;
           if Assigned(ALabel^.Less) then
             GenJmpTreeEntry(ALabel^.Less,ALabel^.LowValue);
           if Assigned(ALabel^.Greater) then
             GenJmpTreeEntry(ALabel^.Greater,ALabel^.HighValue);
        end;


    procedure TCGCaseNode.GenJmpTree(ARoot : PCaseLabel);
      type
        TLabelArrayEntry = record
          CaseLabel : PCaseLabel;
          AsmLabel : TAsmLabel;
        end;
        TLabelArray = array of TLabelArrayEntry;
      var
        lLabelArray : TLabelArray;

      var
        lNextArrayEntry : Int64;
        lIndex : LongInt;

      procedure AddArrayEntry(AEntry : PCaseLabel);
        begin
          if Assigned(AEntry^.Less) then
            AddArrayEntry(AEntry^.Less);
          with lLabelArray[lNextArrayEntry] do
            begin
              CaseLabel:=AEntry;
              CurrentAsmData.getjumplabel(AsmLabel);
            end;
          inc(lNextArrayEntry);
          if Assigned(AEntry^.Greater) then
            AddArrayEntry(AEntry^.Greater);
        end;

      { rebuild the label tree balanced }
      procedure Rebuild(AFirst,ALast : Int64;var ALabel : PCaseLabel);
        var
          lCurrent : Int64;
        begin
          lCurrent:=(AFirst+ALast) div 2;

          ALabel:=lLabelArray[lCurrent].CaseLabel;
          if AFirst<lCurrent then
            Rebuild(AFirst,lCurrent-1,ALabel^.Less)
          else
            ALabel^.Less:=nil;

          if ALast>lCurrent then
            Rebuild(lCurrent+1,ALast,ALabel^.Greater)
          else
            ALabel^.Greater:=nil;
        end;

      begin
        lLabelArray:=nil;
        SetLength(lLabelArray,LabelCnt);
        lNextArrayEntry:=0;
        AddArrayEntry(ARoot);
        Rebuild(0,high(lLabelArray),ARoot);
        for lIndex:=0 to high(lLabelArray) do
          CurrentAsmData.getjumplabel(lLabelArray[lIndex].CaseLabel^.LabelLabel);
        GenJmpTreeEntry(ARoot,ARoot^.HighValue+10);
      end;

    procedure TCGCaseNode.Pass_Generate_Code;
      var
         lOldFlowControl: TFlowControl;
         lIndex : LongInt;
         lDistance : ASizeUInt;
         lValueDistance,
         lLowValue,lHighValue,
         lMaxLabel: TConstExprInt;
         lMaxLinearList : Int64;
         lMaxDistance : QWord;
         lShortcutElse: Boolean;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         lOldFlowControl := flowcontrol;
         include(flowcontrol,fc_inflowcontrol);
         { Allocate labels }

         CurrentAsmData.getjumplabel(FEndLabel);

         { Do some optimisation to deal with empty else blocks }
         lShortcutElse := GetBranchLabel(ElseBlock, FElseLabel);

         for lIndex:=0 to Blocks.Count-1 do
           with PCaseBlock(Blocks[lIndex])^ do
             Shortcut := GetBranchLabel(Statement, BlockLabel);

         FWithSign:=Is_Signed(Left.ResultDef);
         if FWithSign then
           begin
              FJumpGreater:=OC_GT;
              FJumpLess:=OC_LT;
              FJumpLessEqual:=OC_LTE;
           end
         else
            begin
              FJumpGreater:=OC_A;
              FJumpLess:=OC_B;
              FJumpLessEqual:=OC_BE;
           end;

         SecondPass(Left);
         if (Left.ExpectLoc=LOC_JUMP)<>
            (Left.Location.Loc=LOC_JUMP) then
           InternalError(2006050501);
         { determines the size of the operand }
         FOpSize:=Left.ResultDef;
         { copy the case expression to a register }
         hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,FOpSize,false);
{$if not defined(cpu64bitalu)}
         if Def_CGSize(FOpSize) in [OS_S64,OS_64] then
           begin
             FRegister:=Left.Location.Register64.RegLo;
             FRegister2:=Left.Location.Register64.RegHi;
           end
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           FRegister:=Left.Location.Register;

         { we need the min_label always to choose between }
         { cmps and subs/decs                             }
         FMinLabel:=Case_Get_Min(Labels);

         { Generate the jumps }
{$if not defined(cpu64bitalu)}
         if Def_CGSize(FOpSize) in [OS_64,OS_S64] then
           GenLinearCmpList(Labels)
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           begin
              if cs_opt_level1 in CurrentSettings.OptimizerSwitches then
                begin
                   { procedures are empirically passed on }
                   { consumption can also be calculated   }
                   { but does it pay on the different     }
                   { processors?                       }
                   { moreover can the size only be appro- }
                   { ximated as it is not known if rel8,  }
                   { rel16 or rel32 jumps are used   }

                   lMaxLabel := Case_Get_Max(Labels);

                   { can we omit the range check of the jump table ? }
                   GetRange(Left.ResultDef,lLowValue,lHighValue);
                   FJumpTableNoRange:=(lLowValue=FMinLabel) and (lHighValue=lMaxLabel);

                   lValueDistance:=lMaxLabel-FMinLabel;
                   if lValueDistance>=0 then
                     lDistance:=min(lValueDistance.uvalue,high(lDistance))
                   else
                     lDistance:=min(ASizeUInt(-lValueDistance.svalue),high(lDistance));

                   { optimize for size ? }
                   if cs_opt_size in CurrentSettings.OptimizerSwitches  then
                     begin
                       if Has_JumpTable and
                          (FMinLabel>=Int64(low(aint))) and
                          (lMaxLabel<=high(aint)) and
                          not((LabelCnt<=2) or
                              (lValueDistance.svalue<0) or
                              (lDistance>3*LabelCnt)) then
                         begin
                           { if the labels less or more a continuum then }
                           GenJumpTable(Labels,FMinLabel.svalue,lMaxLabel.svalue);
                         end
                       else
                         begin
                           { a linear list is always smaller than a jump tree }
                           GenLinearList(Labels);
                         end;
                     end
                   else
                     begin
                        lMaxDistance:=4*LabelCoverage;

                        { Don't allow jump tables to get too large }
                        if lMaxDistance>4*LabelCnt then
                          lMaxDistance:=min(lMaxDistance,2048);

                        if FJumpTableNoRange then
                          lMaxLinearList:=4
                        else
                          lMaxLinearList:=2;

                        { allow processor specific values }
                        OptimizeValues(lMaxLinearList,lMaxDistance);

                        if (LabelCnt<=lMaxLinearList) then
                          GenLinearList(Labels)
                        else
                          begin
                            if (Has_JumpTable) and
                               (lDistance<lMaxDistance) and
                               (FMinLabel>=Int64(low(aint))) and
                               (lMaxLabel<=high(aint)) then
                              GenJumpTable(Labels,FMinLabel.svalue,lMaxLabel.svalue)
                            { value has been determined on an i7-4770 using a random case with random values
                              if more values are known, this can be handled depending on the target CPU

                              Testing on a Core 2 Duo E6850 as well as on a Raspi3 showed also, that 64 is
                              a good value }
                            else if LabelCnt>=64 then
                              GenJmpTree(Labels)
                            else
                              GenLinearList(Labels);
                          end;
                     end;
                end
              else
                { it's always not bad }
                GenLinearList(Labels);
           end;

         { generate the instruction blocks }
         for lIndex:=0 to Blocks.Count-1 do with PCaseBlock(Blocks[lIndex])^ do
           begin
             { If the labels are not equal, then the block label has been shortcut to point elsewhere,
               so there's no need to implement it }
             if not Shortcut then
               begin
                 CurrentAsmData.CurrAsmList.concat(CAIAlign.Create(CurrentSettings.Alignment.JumpAlign));
                 cg.A_Label(CurrentAsmData.CurrAsmList,BlockLabel);
                 SecondPass(Statement);
                 { don't come back to case line }
                 CurrentFilePos:=CurrentAsmData.CurrAsmList.getlasttaifilepos^;
                 hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,FEndLabel);
               end;
           end;

         { ...and the else block }
         if not lShortcutElse then
           begin
             CurrentAsmData.CurrAsmList.concat(CAIAlign.Create(CurrentSettings.Alignment.JumpAlign));
             hlcg.A_Label(CurrentAsmData.CurrAsmList,FElseLabel);
           end;

         if Assigned(ElseBlock) then
           begin

             SecondPass(ElseBlock);
           end;

         CurrentAsmData.CurrAsmList.concat(CAIAlign.Create(CurrentSettings.Alignment.JumpAlign));
         hlcg.A_Label(CurrentAsmData.CurrAsmList,FEndLabel);

         { Reset labels }
         for lIndex:=0 to Blocks.Count-1 do
           PCaseBlock(Blocks[lIndex])^.BlockLabel:=nil;
         flowcontrol := lOldFlowControl + (flowcontrol - [fc_inflowcontrol]);
      end;


begin
   CSetElementNode:=TCGSetElementNode;
   CInNode:=TCGInNode;
   CCaseNode:=TCGCaseNode;
end.
