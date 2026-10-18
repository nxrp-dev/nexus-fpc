{
    Copyright (c) 2000-2002 by the FPC development team

    Code generation for add nodes (generic version)

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
unit ncgadd;

{$i fpcdefs.inc}

interface

    uses
       node,nadd,cpubase,cgbase;

    type
       TCGAddNode = class(TAddNode)
{          function pass_1: tnode; override;}
          procedure Pass_Generate_Code;override;
         protected
          { call secondpass for both left and right }
          procedure Pass_Left_Right; virtual;
          { set the register of the result location }
          procedure Set_Result_Location_Reg;
          { load left and right nodes into registers }
          procedure Force_Reg_Left_Right(AAllowSwap,AAllowConstant:Boolean); virtual;

          function CmpNode2TOpCmp(AUnsigned: Boolean): TOpCmp;

          procedure Second_OpFloat;
          procedure Second_OpBoolean;
          procedure Second_OpSmallSet;
          procedure Second_Op64Bit;
          procedure Second_OpOrdinal;

          procedure Second_AddString;virtual;
          procedure Second_AddFloat;virtual;abstract;
          procedure Second_AddBoolean;virtual;
          procedure Second_AddSmallSet;virtual;
          procedure Second_AddSmallSetElement;virtual;
{$ifdef x86}
{$endif x86}
          procedure Second_OpVector;virtual;abstract;
          procedure Second_Add64Bit;virtual;
          procedure Second_AddOrdinal;virtual;
          procedure Second_CmpFloat;virtual;abstract;
          procedure Second_CmpBoolean;virtual;
          procedure Second_CmpSmallSet;virtual;abstract;
          procedure Second_Cmp64Bit;virtual;abstract;
          procedure Second_CmpOrdinal;virtual;abstract;

          function NeedOverflowCheck: Boolean;
       end;

  implementation

    uses
      GlobType,Systems,
      Verbose,Globals,
      symconst,symdef,
      aasmbase,AAsmData,defutil,
      pass_2,tgobj,
      nutils,nset,ncgutil,cgobj,cgutils,
      hlcgobj
      ;


{*****************************************************************************
                                  Helpers
*****************************************************************************}

    procedure TCGAddNode.Pass_Left_Right;
{$ifdef x86}
      var
        lTempReg     : TRegister;
        lPushedFPU  : Boolean;
{$endif x86}
      begin
        { calculate the operator which is more difficult }
        FirstComplex(Self);

        { in case of constant put it to the left }
        if (Left.NodeType=ordconstn) then
          SwapLeftRight;

        SecondPass(Left);
        if Left.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
{$ifdef x86}
        { are too few registers free? }
        lPushedFPU:=false;
        if (Left.Location.Loc=LOC_FPUREGISTER) and
           (Node_Resources_FPU(Right)>=maxfpuregs) then
          begin
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
            lPushedFPU:=true;
          end;
{$endif x86}

        SecondPass(Right);
        if Right.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,ResultDef,false);
{$ifdef x86}
        if lPushedFPU then
          begin
            if Use_VectorFPU(Left.ResultDef) then
              begin
                lTempReg := cg.GetMMRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
                hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location,lTempReg,MMS_MoveScalar);
                Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
                Location_Reset(Left.Location,LOC_MMREGISTER,Left.Location.Size);
                Left.Location.Register:=lTempReg;
              end
            else
              begin
                lTempReg := cg.GetFPURegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
                cg.A_LoadFPU_Loc_Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Left.Location,lTempReg);
                Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
                Location_Reset(Left.Location,LOC_FPUREGISTER,Left.Location.Size);
                Left.Location.Register := lTempReg;
                { left operand is now on top of the stack, instead of the right one! }
                if (Right.Location.Loc=LOC_FPUREGISTER) then
                  ToggleFlag(nf_swapped);
              end;
          end;
{$endif x86}
      end;


    procedure TCGAddNode.Set_Result_Location_Reg;
      begin
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if Location.Size in [OS_64,OS_S64] then
          begin
            Location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            Location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
          end
        else
{$endif}
          Location.Register := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
      end;


    procedure TCGAddNode.Force_Reg_Left_Right(AAllowSwap,AAllowConstant:Boolean);
      begin
        if (Left.Location.Loc<>LOC_REGISTER) and
           not(
               AAllowConstant and
               (Left.Location.Loc in [LOC_CONSTANT,LOC_CREGISTER])
              ) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        if (Right.Location.Loc<>LOC_REGISTER) and
           not(
               AAllowConstant and
               (Right.Location.Loc in [LOC_CONSTANT,LOC_CREGISTER]) and
               (Left.Location.Loc<>LOC_CONSTANT)
              ) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,Right.ResultDef,false);

        { Left is always a register, right can be register or constant }
        if Left.Location.Loc=LOC_CONSTANT then
          begin
            { when it is not allowed to swap we have a constant on
              left, that will give problems }
            if not AAllowSwap then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false)
            else
              SwapLeftRight;
          end;
      end;


    function TCGAddNode.CmpNode2TOpCmp(AUnsigned: Boolean): TOpCmp;
      begin
        if AUnsigned then
          case NodeType of
            gtn:      Result:=OC_A;
            gten:     Result:=OC_AE;
            ltn:      Result:=OC_B;
            lten:     Result:=OC_BE;
            EqualN:   Result:=OC_EQ;
            unequaln: Result:=OC_NE;
          else
            InternalError(2011010412);
          end
        else
          case NodeType of
            gtn:      Result:=OC_GT;
            gten:     Result:=OC_GTE;
            ltn:      Result:=OC_LT;
            lten:     Result:=OC_LTE;
            EqualN:   Result:=OC_EQ;
            unequaln: Result:=OC_NE;
          else
            InternalError(2011010403);
          end
      end;

{*****************************************************************************
                                Smallsets
*****************************************************************************}

    procedure TCGAddNode.Second_OpSmallSet;
      begin
        { when a setdef is passed, it has to be a smallset }
        if not(
               ((Left.NodeType=setelementn) or Is_SmallSet(Left.ResultDef)) and
               ((Right.NodeType=setelementn) or Is_SmallSet(Right.ResultDef))
              ) then
          InternalError(200203302);
        if (Left.NodeType=setelementn) or (Right.NodeType=setelementn) then
          Second_AddSmallSetElement
        else if NodeType in [EqualN,unequaln,gtn,gten,lten,ltn] then
          Second_CmpSmallSet
        else
          Second_AddSmallSet;
      end;


    procedure TCGAddNode.Second_AddSmallSet;
      var
        lCGOp    : TOpCG;
        lOpDone  : Boolean;
      begin
        lOpDone := false;
        Pass_Left_Right;
        Force_Reg_Left_Right(true,true);
        Set_Result_Location_Reg;
        case NodeType of
          addn :
            lCGOp:=OP_OR;
          symdifn :
            lCGOp:=OP_XOR;
          muln :
            lCGOp:=OP_AND;
          subn :
            begin
              lCGOp:=OP_AND;
              if (not(nf_swapped in Flags)) then
                if (Right.Location.Loc=LOC_CONSTANT) then
                  Right.Location.Value := not(Right.Location.Value)
                else
                  lOpDone := true
              else if (Left.Location.Loc=LOC_CONSTANT) then
                Left.Location.Value := not(Left.Location.Value)
              else
                 begin
                   SwapLeftRight;
                   lOpDone := true;
                 end;
              if lOpDone then
                begin
                  if (Right.Location.Size<>Left.Location.Size) or
                     (Location.Size<>Left.Location.Size) then
                    InternalError(2010123001);
                  { make sure that location.register is different from
                    left.location.register, since right will overwrite it
                    and we'll use left afterwards }
                  if (Right.Location.Loc=LOC_REGISTER) then
                    Location.Register:=Right.Location.Register
                  else
                    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                  { make sure we don't modify left/right.location, because we told
                    force_reg_left_right above that they can be constant }
                  hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,ResultDef,Right.Location.Register,Location.Register);
                  if Left.Location.Loc = LOC_CONSTANT then
                    hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,ResultDef,Left.Location.Value,Location.Register)
                  else
                    hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_AND,ResultDef,Left.Location.Register,Location.Register);
                end;
            end;
          else
            InternalError(2002072701);
        end;

        if not lOpDone then
          begin
            // these are all commutative operations
            if (Left.Location.Loc = LOC_CONSTANT) then
              SwapLeftRight;
            if (Right.Location.Loc = LOC_CONSTANT) then
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
                Right.Location.Value,Left.Location.Register,
                Location.Register)
            else
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
                Right.Location.Register,Left.Location.Register,
                Location.Register);
          end;
      end;


    procedure TCGAddNode.Second_AddSmallSetElement;
      var
        lTempReg : TRegister;
        lMask,
        lSetBase : aint;
        lCGOp    : TOpCG;
      begin
        if NodeType<>addn then
          InternalError(20080302);
        { no range support for smallsets }
        if Assigned(TSetElementNode(Right).Right) then
          InternalError(20080303);
        Pass_Left_Right;
        { setelementn is a special case, it must be on right }
        if (nf_swapped in Flags) and
           (Left.NodeType=setelementn) then
          SwapLeftRight;
        Force_Reg_Left_Right(false,false);
        Set_Result_Location_Reg;
        lSetBase:=TSetDef(Left.ResultDef).SetBase;
        if (Right.Location.Loc = LOC_CONSTANT) then
          begin
            if (TargetInfo.endian=endian_big) then
              lMask:=aint((AWord(1) shl (ResultDef.Size*8-1)) shr AWord(Right.Location.Value-lSetBase))
            else
              lMask:=aint(1 shl (Right.Location.Value-lSetBase));
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,ResultDef,
              lMask,Left.Location.Register,Location.Register);
          end
        else
          begin
            if (TargetInfo.endian=endian_big) then
              begin
                lMask:=aint((AWord(1) shl (ResultDef.Size*8-1)));
                lCGOp:=OP_SHR
              end
            else
              begin
                lMask:=1;
                lCGOp:=OP_SHL
              end;
            lTempReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
            hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,lMask,lTempReg);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,ResultDef,true);
            Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,ResultDef,Right.Location,lSetBase);
            hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
              Right.Location.Register,lTempReg);
            if Left.Location.Loc <> LOC_CONSTANT then
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,ResultDef,lTempReg,
                  Left.Location.Register,Location.Register)
            else
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,ResultDef,
                  Left.Location.Value,lTempReg,Location.Register);
          end;
      end;


{*****************************************************************************
                                Boolean
*****************************************************************************}

    procedure TCGAddNode.Second_OpBoolean;
      begin
        if NodeType in [ltn,lten,gtn,gten,EqualN,unequaln] then
          Second_CmpBoolean
        else
          Second_AddBoolean;
      end;


    procedure TCGAddNode.Second_AddBoolean;
      var
        lCGOp    : TOpCG;
        lTrueLabel, lFalseLabel : TAsmLabel;
        lOldFlowControl : TFlowControl;
      begin
        { And,Or will only evaluate from left to right only the
          needed nodes unless full boolean evaluation is enabled }
        if (NodeType in [orn,andn]) and
           (not(cs_full_boolean_eval in CurrentSettings.LocalSwitches) or
            (anf_short_bool in AddNodeFlags)) then
          begin
            case NodeType of
              andn :
                begin
                   SecondPass(Left);
                   hlcg.MakeToJumpBool(CurrentAsmData.CurrAsmList,Left);
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.TrueLabel);
                   CurrentAsmData.getjumplabel(lTrueLabel);
                   Location_Reset_Jump(Location,lTrueLabel,Left.Location.FalseLabel);
                end;
              orn :
                begin
                   SecondPass(Left);
                   hlcg.MakeToJumpBool(CurrentAsmData.CurrAsmList,Left);
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.FalseLabel);
                   CurrentAsmData.getjumplabel(lFalseLabel);
                   Location_Reset_Jump(Location,Left.Location.TrueLabel,lFalseLabel);
                end;
              else
                InternalError(200307044);
            end;
            { these jumps mean we're now in a flow control construct }
            lOldFlowControl:=flowcontrol;
            include(flowcontrol,fc_inflowcontrol);

            SecondPass(Right);
            { jump to the same labels as the left side, since the andn/orn
              merges the results of left and right }
            hlcg.MakeToJumpBoolLabels(CurrentAsmData.CurrAsmList,Right,Location.TrueLabel,Location.FalseLabel);

            flowcontrol:=lOldFlowControl+(flowcontrol-[fc_inflowcontrol]);
          end
        else
          begin
            Pass_Left_Right;
            Force_Reg_Left_Right(false,true);
            Set_Result_Location_Reg;

            case NodeType of
              xorn :
                lCGOp:=OP_XOR;
              orn :
                lCGOp:=OP_OR;
              andn :
                lCGOp:=OP_AND;
              else
                 InternalError(200203247);
            end;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
            if Right.Location.Size in [OS_64,OS_S64] then
              begin
                if Right.Location.Loc <> LOC_CONSTANT then
                  cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
                     Left.Location.Register64,Right.Location.Register64,
                     Location.Register64)
                else
                  cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
                     Right.Location.Value,Left.Location.Register64,
                     Location.Register64);
              end
            else
{$endif cpu64bitalu}
              begin
                if Right.Location.Loc <> LOC_CONSTANT then
                  hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
                     Left.Location.Register,Right.Location.Register,
                     Location.Register)
                else
                  hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
                     Right.Location.Value,Left.Location.Register,
                     Location.Register);
              end;
         end;
      end;


{*****************************************************************************
                                64-bit
*****************************************************************************}

    procedure TCGAddNode.Second_Op64Bit;
      begin
        if NodeType in [ltn,lten,gtn,gten,EqualN,unequaln] then
          Second_Cmp64Bit
        else
          Second_Add64Bit;
      end;


    procedure TCGAddNode.Second_Add64Bit;
      var
        lCGOp         : TOpCG;
        lCheckOverflow : Boolean;
        lOverflowLoc : TLocation;
      begin
        lOverflowLoc.Loc:=LOC_VOID;

        Pass_Left_Right;
        Force_Reg_Left_Right(false,true);
        Set_Result_Location_Reg;

        { assume no overflow checking is required }
        lCheckOverflow := false;
        case NodeType of
          addn :
             begin
                lCGOp:=OP_ADD;
                lCheckOverflow:=true;
             end;
          subn :
             begin
                lCGOp:=OP_SUB;
                lCheckOverflow:=true;
             end;
          xorn:
            lCGOp:=OP_XOR;
          orn:
            lCGOp:=OP_OR;
          andn:
            lCGOp:=OP_AND;
          muln:
            begin
              { should be handled in pass_1 (JM) }
              InternalError(200109051);
            end;
          else
            InternalError(2002072705);
        end;

        lCheckOverflow:=
          lCheckOverflow and
          NeedOverflowCheck;

{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
        case NodeType of
          xorn,orn,andn,addn:
            begin
              if (Right.Location.Loc = LOC_CONSTANT) then
                hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,Right.Location.Value,
                  Left.Location.Register,Location.Register)
              else
                hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,Right.Location.Register,
                  Left.Location.Register,Location.Register);
            end;
          subn:
            begin
              if (nf_swapped in Flags) then
                SwapLeftRight;

              if Left.Location.Loc <> LOC_CONSTANT then
                begin
                  if Right.Location.Loc <> LOC_CONSTANT then
                    // reg64 - reg64
                    hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                      Right.Location.Register,Left.Location.Register,Location.Register,
                      lCheckOverflow,lOverflowLoc)
                  else
                    // reg64 - const64
                    hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                      Right.Location.Value,Left.Location.Register,Location.Register,
                      lCheckOverflow,lOverflowLoc);
                end
              else
                begin
                  // const64 - reg64
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
                  hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                    Right.Location.Register,Left.Location.Register,Location.Register,
                    lCheckOverflow,lOverflowLoc);
                end;
            end;
          else
            InternalError(2002072803);
        end;
{$else cpu64bitalu or cpuhighleveltarget}
        case NodeType of
          xorn,orn,andn,addn:
            begin
              if (Right.Location.Loc = LOC_CONSTANT) then
                cg64.A_Op64_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,Right.Location.Value64,
                  Left.Location.Register64,Location.Register64,
                  lCheckOverflow,lOverflowLoc)
              else
                cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,Right.Location.Register64,
                  Left.Location.Register64,Location.Register64,
                  lCheckOverflow,lOverflowLoc);
            end;
          subn:
            begin
              if (nf_swapped in Flags) then
                SwapLeftRight;

              if Left.Location.Loc <> LOC_CONSTANT then
                begin
                  if Right.Location.Loc <> LOC_CONSTANT then
                    // reg64 - reg64
                    cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,Location.Size,
                      Right.Location.Register64,Left.Location.Register64,
                      Location.Register64,
                      lCheckOverflow,lOverflowLoc)
                  else
                    // reg64 - const64
                    cg64.A_Op64_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,Location.Size,
                      Right.Location.Value64,Left.Location.Register64,
                      Location.Register64,
                      lCheckOverflow,lOverflowLoc)
                end
              else
                begin
                  // const64 - reg64
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
                  cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,Location.Size,
                    Right.Location.Register64,Left.Location.Register64,
                    Location.Register64,
                    lCheckOverflow,lOverflowLoc);
                end;
            end;
          else
            InternalError(2002072804);
        end;
{$endif cpu64bitalu or cpuhighleveltarget}

        { emit overflow check if enabled }
        if lCheckOverflow then
           hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
      end;


{*****************************************************************************
                                Strings
*****************************************************************************}

    procedure TCGAddNode.Second_AddString;
      begin
        { this should already be handled in pass1 }
        InternalError(2002072402);
      end;


{*****************************************************************************
                                Floats
*****************************************************************************}

    procedure TCGAddNode.Second_OpFloat;
      begin
        if NodeType in [ltn,lten,gtn,gten,EqualN,unequaln] then
          Second_CmpFloat
        else
          Second_AddFloat;
      end;


{*****************************************************************************
                                Ordinals
*****************************************************************************}

    procedure TCGAddNode.Second_OpOrdinal;
      begin
         if (NodeType in [ltn,lten,gtn,gten,EqualN,unequaln]) then
           Second_CmpOrdinal
         else
           Second_AddOrdinal;
      end;


    procedure TCGAddNode.Second_AddOrdinal;
      var
        lUnsigned,
        lCheckOverflow : Boolean;
        lCGOp   : TOpCG;
        lTempReg : TRegister;
        lOverflowLoc : TLocation;
      begin
        lOverflowLoc.Loc:=LOC_VOID;

        Pass_Left_Right;
        Force_Reg_Left_Right(true,true);
        Set_Result_Location_Reg;

        { determine if the comparison will be unsigned }
        lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                    not(Is_Signed(Right.ResultDef));

        { assume no overflow checking is require }
        lCheckOverflow := false;

        case NodeType of
          addn:
            begin
              lCGOp:=OP_ADD;
              lCheckOverflow:=true;
            end;
          xorn :
            begin
              lCGOp:=OP_XOR;
            end;
          orn :
            begin
              lCGOp:=OP_OR;
            end;
          andn:
            begin
              lCGOp:=OP_AND;
            end;
          muln:
            begin
              lCheckOverflow:=true;
              if lUnsigned then
                lCGOp:=OP_MUL
              else
                lCGOp:=OP_IMUL;
            end;
          subn :
            begin
              lCheckOverflow:=true;
              lCGOp:=OP_SUB;
            end;
          else
            InternalError(2013120104);
        end;

       lCheckOverflow:=
         lCheckOverflow and
          (Left.ResultDef.typ<>pointerdef) and
          (Right.ResultDef.typ<>pointerdef) and
          (cs_check_overflow in CurrentSettings.LocalSwitches) and not(nf_internal in Flags);

       if NodeType<>subn then
        begin
          if (Right.Location.Loc<>LOC_CONSTANT) then
            hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
               Left.Location.Register,Right.Location.Register,
               Location.Register,lCheckOverflow,lOverflowLoc)
          else
            hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,
               Right.Location.Value,Left.Location.Register,
               Location.Register,lCheckOverflow,lOverflowLoc);
        end
      else  { subtract is a special case since its not commutative }
        begin
          if (nf_swapped in Flags) then
            SwapLeftRight;
          if Left.Location.Loc<>LOC_CONSTANT then
            begin
              if Right.Location.Loc<>LOC_CONSTANT then
                hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                    Right.Location.Register,Left.Location.Register,
                    Location.Register,lCheckOverflow,lOverflowLoc)
              else
                hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                  Right.Location.Value,Left.Location.Register,
                  Location.Register,lCheckOverflow,lOverflowLoc);
            end
          else
            begin
              lTempReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
              hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,
                Left.Location.Value,lTempReg);
              hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                Right.Location.Register,lTempReg,Location.Register,lCheckOverflow,lOverflowLoc);
            end;
        end;

        { emit overflow check if required }
        if lCheckOverflow then
          hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
      end;


    procedure TCGAddNode.Second_CmpBoolean;
      begin
        Second_CmpOrdinal;
      end;

    function TCGAddNode.NeedOverflowCheck: Boolean;
      begin
        Result:=
          (cs_check_overflow in CurrentSettings.LocalSwitches) and
          (Left.ResultDef.typ<>pointerdef) and
          (Right.ResultDef.typ<>pointerdef) and
          not(nf_internal in Flags);
      end;


{*****************************************************************************
                                pass_generate_code;
*****************************************************************************}

    procedure TCGAddNode.Pass_Generate_Code;
      begin
        case Left.ResultDef.typ of
          orddef :
            begin
              { handling boolean expressions }
              if Is_Boolean(Left.ResultDef) and
                 Is_Boolean(Right.ResultDef) then
                Second_OpBoolean
{$ifndef cpu64bitalu}
              { 64bit operations }
              else if Is_64Bit(Left.ResultDef) then
                Second_Op64Bit
{$endif cpu64bitalu}
              else
                Second_OpOrdinal;
            end;
          stringdef :
            begin
              Second_AddString;
            end;
          setdef :
            begin
              if Is_SmallSet(TSetDef(Left.ResultDef)) then
                Second_OpSmallSet
              else
                InternalError(200109041);
            end;
          arraydef :
            begin
              { support dynarr=nil }
              if Is_Dynamic_Array(Left.ResultDef) then
                Second_OpOrdinal
              else
                if (cs_support_vectors in CurrentSettings.GlobalSwitches) and
                   Is_Vector(Left.ResultDef) then
                  Second_OpVector
              else
                InternalError(200306016);
            end;
          floatdef :
            Second_OpFloat;
          else
            Second_OpOrdinal;
        end;
      end;

begin
   CAddNode:=TCGAddNode;
end.
