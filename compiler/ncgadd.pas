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
          procedure pass_generate_code;override;
         protected
          { call secondpass for both left and right }
          procedure pass_left_right; virtual;
          { set the register of the result location }
          procedure set_result_location_reg;
          { load left and right nodes into registers }
          procedure force_reg_left_right(allow_swap,allow_constant:boolean); virtual;

          function cmpnode2topcmp(unsigned: boolean): TOpCmp;

          procedure second_opfloat;
          procedure second_opboolean;
          procedure second_opsmallset;
          procedure second_op64bit;
          procedure second_opordinal;

          procedure second_addstring;virtual;
          procedure second_addfloat;virtual;abstract;
          procedure second_addboolean;virtual;
          procedure second_addsmallset;virtual;
          procedure second_addsmallsetelement;virtual;
{$ifdef x86}
{$ifdef SUPPORT_MMX}
          procedure second_opmmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$endif x86}
          procedure second_opvector;virtual;abstract;
          procedure second_add64bit;virtual;
          procedure second_addordinal;virtual;
          procedure second_cmpfloat;virtual;abstract;
          procedure second_cmpboolean;virtual;
          procedure second_cmpsmallset;virtual;abstract;
          procedure second_cmp64bit;virtual;abstract;
          procedure second_cmpordinal;virtual;abstract;

          function needoverflowcheck: boolean;
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

    procedure TCGAddNode.pass_left_right;
{$ifdef x86}
      var
        tmpreg     : TRegister;
        pushedfpu  : boolean;
{$endif x86}
      begin
        { calculate the operator which is more difficult }
        firstcomplex(self);

        { in case of constant put it to the left }
        if (left.nodetype=ordconstn) then
          swapleftright;

        SecondPass(left);
        if left.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef,false);
{$ifdef x86}
        { are too few registers free? }
        pushedfpu:=false;
        if (left.Location.Loc=LOC_FPUREGISTER) and
           (node_resources_fpu(right)>=maxfpuregs) then
          begin
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
            pushedfpu:=true;
          end;
{$endif x86}

        SecondPass(right);
        if right.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,resultdef,false);
{$ifdef x86}
        if pushedfpu then
          begin
            if Use_VectorFPU(left.resultdef) then
              begin
                tmpreg := cg.GetMMRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
                hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location,tmpreg,MMS_MoveScalar);
                location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
                Location_Reset(left.Location,LOC_MMREGISTER,left.Location.Size);
                left.Location.Register:=tmpreg;
              end
            else
              begin
                tmpreg := cg.GetFPURegister(CurrentAsmData.CurrAsmList,left.Location.Size);
                cg.A_LoadFPU_Loc_Reg(CurrentAsmData.CurrAsmList,left.Location.Size,left.Location,tmpreg);
                location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
                Location_Reset(left.Location,LOC_FPUREGISTER,left.Location.Size);
                left.Location.Register := tmpreg;
                { left operand is now on top of the stack, instead of the right one! }
                if (right.Location.Loc=LOC_FPUREGISTER) then
                  toggleflag(nf_swapped);
              end;
          end;
{$endif x86}
      end;


    procedure TCGAddNode.set_result_location_reg;
      begin
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if location.Size in [OS_64,OS_S64] then
          begin
            location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
          end
        else
{$endif}
          location.Register := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
      end;


    procedure TCGAddNode.force_reg_left_right(allow_swap,allow_constant:boolean);
      begin
        if (left.Location.Loc<>LOC_REGISTER) and
           not(
               allow_constant and
               (left.Location.Loc in [LOC_CONSTANT,LOC_CREGISTER])
              ) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        if (right.Location.Loc<>LOC_REGISTER) and
           not(
               allow_constant and
               (right.Location.Loc in [LOC_CONSTANT,LOC_CREGISTER]) and
               (left.Location.Loc<>LOC_CONSTANT)
              ) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,right.resultdef,false);

        { Left is always a register, right can be register or constant }
        if left.Location.Loc=LOC_CONSTANT then
          begin
            { when it is not allowed to swap we have a constant on
              left, that will give problems }
            if not allow_swap then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false)
            else
              swapleftright;
          end;
      end;


    function TCGAddNode.cmpnode2topcmp(unsigned: boolean): TOpCmp;
      begin
        if unsigned then
          case nodetype of
            gtn:      result:=OC_A;
            gten:     result:=OC_AE;
            ltn:      result:=OC_B;
            lten:     result:=OC_BE;
            EqualN:   result:=OC_EQ;
            unequaln: result:=OC_NE;
          else
            InternalError(2011010412);
          end
        else
          case nodetype of
            gtn:      result:=OC_GT;
            gten:     result:=OC_GTE;
            ltn:      result:=OC_LT;
            lten:     result:=OC_LTE;
            EqualN:   result:=OC_EQ;
            unequaln: result:=OC_NE;
          else
            InternalError(2011010403);
          end
      end;

{*****************************************************************************
                                Smallsets
*****************************************************************************}

    procedure TCGAddNode.second_opsmallset;
      begin
        { when a setdef is passed, it has to be a smallset }
        if not(
               ((left.nodetype=setelementn) or Is_SmallSet(left.resultdef)) and
               ((right.nodetype=setelementn) or Is_SmallSet(right.resultdef))
              ) then
          InternalError(200203302);
        if (left.nodetype=setelementn) or (right.nodetype=setelementn) then
          second_addsmallsetelement
        else if nodetype in [EqualN,unequaln,gtn,gten,lten,ltn] then
          second_cmpsmallset
        else
          second_addsmallset;
      end;


    procedure TCGAddNode.second_addsmallset;
      var
        cgop    : TOpCG;
        opdone  : boolean;
      begin
        opdone := false;
        pass_left_right;
        force_reg_left_right(true,true);
        set_result_location_reg;
        case nodetype of
          addn :
            cgop:=OP_OR;
          symdifn :
            cgop:=OP_XOR;
          muln :
            cgop:=OP_AND;
          subn :
            begin
              cgop:=OP_AND;
              if (not(nf_swapped in flags)) then
                if (right.Location.Loc=LOC_CONSTANT) then
                  right.Location.Value := not(right.Location.Value)
                else
                  opdone := true
              else if (left.Location.Loc=LOC_CONSTANT) then
                left.Location.Value := not(left.Location.Value)
              else
                 begin
                   swapleftright;
                   opdone := true;
                 end;
              if opdone then
                begin
                  if (right.Location.Size<>left.Location.Size) or
                     (location.Size<>left.Location.Size) then
                    InternalError(2010123001);
                  { make sure that location.register is different from
                    left.location.register, since right will overwrite it
                    and we'll use left afterwards }
                  if (right.Location.Loc=LOC_REGISTER) then
                    location.Register:=right.Location.Register
                  else
                    location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                  { make sure we don't modify left/right.location, because we told
                    force_reg_left_right above that they can be constant }
                  hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,resultdef,right.Location.Register,location.Register);
                  if left.Location.Loc = LOC_CONSTANT then
                    hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,resultdef,left.Location.Value,location.Register)
                  else
                    hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_AND,resultdef,left.Location.Register,location.Register);
                end;
            end;
          else
            InternalError(2002072701);
        end;

        if not opdone then
          begin
            // these are all commutative operations
            if (left.Location.Loc = LOC_CONSTANT) then
              swapleftright;
            if (right.Location.Loc = LOC_CONSTANT) then
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,
                right.Location.Value,left.Location.Register,
                location.Register)
            else
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,
                right.Location.Register,left.Location.Register,
                location.Register);
          end;
      end;


    procedure TCGAddNode.second_addsmallsetelement;
      var
        tmpreg : TRegister;
        mask,
        SetBase : aint;
        cgop    : TOpCG;
      begin
        if nodetype<>addn then
          InternalError(20080302);
        { no range support for smallsets }
        if Assigned(TSetElementNode(right).right) then
          InternalError(20080303);
        pass_left_right;
        { setelementn is a special case, it must be on right }
        if (nf_swapped in flags) and
           (left.nodetype=setelementn) then
          swapleftright;
        force_reg_left_right(false,false);
        set_result_location_reg;
        SetBase:=TSetDef(left.resultdef).SetBase;
        if (right.Location.Loc = LOC_CONSTANT) then
          begin
            if (TargetInfo.endian=endian_big) then
              mask:=aint((aword(1) shl (resultdef.Size*8-1)) shr aword(right.Location.Value-SetBase))
            else
              mask:=aint(1 shl (right.Location.Value-SetBase));
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,resultdef,
              mask,left.Location.Register,location.Register);
          end
        else
          begin
            if (TargetInfo.endian=endian_big) then
              begin
                mask:=aint((aword(1) shl (resultdef.Size*8-1)));
                cgop:=OP_SHR
              end
            else
              begin
                mask:=1;
                cgop:=OP_SHL
              end;
            tmpreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
            hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,mask,tmpreg);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,resultdef,true);
            register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,resultdef,right.Location,SetBase);
            hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,
              right.Location.Register,tmpreg);
            if left.Location.Loc <> LOC_CONSTANT then
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,resultdef,tmpreg,
                  left.Location.Register,location.Register)
            else
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,resultdef,
                  left.Location.Value,tmpreg,location.Register);
          end;
      end;


{*****************************************************************************
                                Boolean
*****************************************************************************}

    procedure TCGAddNode.second_opboolean;
      begin
        if nodetype in [ltn,lten,gtn,gten,EqualN,unequaln] then
          second_cmpboolean
        else
          second_addboolean;
      end;


    procedure TCGAddNode.second_addboolean;
      var
        cgop    : TOpCG;
        TrueLabel, FalseLabel : TAsmLabel;
        oldflowcontrol : TFlowControl;
      begin
        { And,Or will only evaluate from left to right only the
          needed nodes unless full boolean evaluation is enabled }
        if (nodetype in [orn,andn]) and
           (not(cs_full_boolean_eval in CurrentSettings.LocalSwitches) or
            (anf_short_bool in addnodeflags)) then
          begin
            case nodetype of
              andn :
                begin
                   SecondPass(left);
                   hlcg.MakeToJumpBool(CurrentAsmData.CurrAsmList,left);
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,left.Location.TrueLabel);
                   CurrentAsmData.getjumplabel(TrueLabel);
                   Location_Reset_Jump(location,TrueLabel,left.Location.FalseLabel);
                end;
              orn :
                begin
                   SecondPass(left);
                   hlcg.MakeToJumpBool(CurrentAsmData.CurrAsmList,left);
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,left.Location.FalseLabel);
                   CurrentAsmData.getjumplabel(FalseLabel);
                   Location_Reset_Jump(location,left.Location.TrueLabel,FalseLabel);
                end;
              else
                InternalError(200307044);
            end;
            { these jumps mean we're now in a flow control construct }
            oldflowcontrol:=flowcontrol;
            include(flowcontrol,fc_inflowcontrol);

            SecondPass(right);
            { jump to the same labels as the left side, since the andn/orn
              merges the results of left and right }
            hlcg.MakeToJumpBoolLabels(CurrentAsmData.CurrAsmList,right,location.TrueLabel,location.FalseLabel);

            flowcontrol:=oldflowcontrol+(flowcontrol-[fc_inflowcontrol]);
          end
        else
          begin
            pass_left_right;
            force_reg_left_right(false,true);
            set_result_location_reg;

            case nodetype of
              xorn :
                cgop:=OP_XOR;
              orn :
                cgop:=OP_OR;
              andn :
                cgop:=OP_AND;
              else
                 InternalError(200203247);
            end;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
            if right.Location.Size in [OS_64,OS_S64] then
              begin
                if right.Location.Loc <> LOC_CONSTANT then
                  cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,location.Size,
                     left.Location.Register64,right.Location.Register64,
                     location.Register64)
                else
                  cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,location.Size,
                     right.Location.Value,left.Location.Register64,
                     location.Register64);
              end
            else
{$endif cpu64bitalu}
              begin
                if right.Location.Loc <> LOC_CONSTANT then
                  hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,
                     left.Location.Register,right.Location.Register,
                     location.Register)
                else
                  hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,
                     right.Location.Value,left.Location.Register,
                     location.Register);
              end;
         end;
      end;


{*****************************************************************************
                                64-bit
*****************************************************************************}

    procedure TCGAddNode.second_op64bit;
      begin
        if nodetype in [ltn,lten,gtn,gten,EqualN,unequaln] then
          second_cmp64bit
        else
          second_add64bit;
      end;


    procedure TCGAddNode.second_add64bit;
      var
        op         : TOpCG;
        checkoverflow : boolean;
        ovloc : TLocation;
      begin
        ovloc.Loc:=LOC_VOID;

        pass_left_right;
        force_reg_left_right(false,true);
        set_result_location_reg;

        { assume no overflow checking is required }
        checkoverflow := false;
        case nodetype of
          addn :
             begin
                op:=OP_ADD;
                checkoverflow:=true;
             end;
          subn :
             begin
                op:=OP_SUB;
                checkoverflow:=true;
             end;
          xorn:
            op:=OP_XOR;
          orn:
            op:=OP_OR;
          andn:
            op:=OP_AND;
          muln:
            begin
              { should be handled in pass_1 (JM) }
              InternalError(200109051);
            end;
          else
            InternalError(2002072705);
        end;

        checkoverflow:=
          checkoverflow and
          needoverflowcheck;

{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
        case nodetype of
          xorn,orn,andn,addn:
            begin
              if (right.Location.Loc = LOC_CONSTANT) then
                hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,resultdef,right.Location.Value,
                  left.Location.Register,location.Register)
              else
                hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,op,resultdef,right.Location.Register,
                  left.Location.Register,location.Register);
            end;
          subn:
            begin
              if (nf_swapped in flags) then
                swapleftright;

              if left.Location.Loc <> LOC_CONSTANT then
                begin
                  if right.Location.Loc <> LOC_CONSTANT then
                    // reg64 - reg64
                    hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                      right.Location.Register,left.Location.Register,location.Register,
                      checkoverflow,ovloc)
                  else
                    // reg64 - const64
                    hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                      right.Location.Value,left.Location.Register,location.Register,
                      checkoverflow,ovloc);
                end
              else
                begin
                  // const64 - reg64
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
                  hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                    right.Location.Register,left.Location.Register,location.Register,
                    checkoverflow,ovloc);
                end;
            end;
          else
            InternalError(2002072803);
        end;
{$else cpu64bitalu or cpuhighleveltarget}
        case nodetype of
          xorn,orn,andn,addn:
            begin
              if (right.Location.Loc = LOC_CONSTANT) then
                cg64.A_Op64_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,op,location.Size,right.Location.Value64,
                  left.Location.Register64,location.Register64,
                  checkoverflow,ovloc)
              else
                cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,op,location.Size,right.Location.Register64,
                  left.Location.Register64,location.Register64,
                  checkoverflow,ovloc);
            end;
          subn:
            begin
              if (nf_swapped in flags) then
                swapleftright;

              if left.Location.Loc <> LOC_CONSTANT then
                begin
                  if right.Location.Loc <> LOC_CONSTANT then
                    // reg64 - reg64
                    cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,location.Size,
                      right.Location.Register64,left.Location.Register64,
                      location.Register64,
                      checkoverflow,ovloc)
                  else
                    // reg64 - const64
                    cg64.A_Op64_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,location.Size,
                      right.Location.Value64,left.Location.Register64,
                      location.Register64,
                      checkoverflow,ovloc)
                end
              else
                begin
                  // const64 - reg64
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
                  cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,location.Size,
                    right.Location.Register64,left.Location.Register64,
                    location.Register64,
                    checkoverflow,ovloc);
                end;
            end;
          else
            InternalError(2002072804);
        end;
{$endif cpu64bitalu or cpuhighleveltarget}

        { emit overflow check if enabled }
        if checkoverflow then
           hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,resultdef,ovloc);
      end;


{*****************************************************************************
                                Strings
*****************************************************************************}

    procedure TCGAddNode.second_addstring;
      begin
        { this should already be handled in pass1 }
        InternalError(2002072402);
      end;


{*****************************************************************************
                                Floats
*****************************************************************************}

    procedure TCGAddNode.second_opfloat;
      begin
        if nodetype in [ltn,lten,gtn,gten,EqualN,unequaln] then
          second_cmpfloat
        else
          second_addfloat;
      end;


{*****************************************************************************
                                Ordinals
*****************************************************************************}

    procedure TCGAddNode.second_opordinal;
      begin
         if (nodetype in [ltn,lten,gtn,gten,EqualN,unequaln]) then
           second_cmpordinal
         else
           second_addordinal;
      end;


    procedure TCGAddNode.second_addordinal;
      var
        unsigned,
        checkoverflow : boolean;
        cgop   : TOpCG;
        tmpreg : TRegister;
        ovloc : TLocation;
      begin
        ovloc.Loc:=LOC_VOID;

        pass_left_right;
        force_reg_left_right(true,true);
        set_result_location_reg;

        { determine if the comparison will be unsigned }
        unsigned:=not(Is_Signed(left.resultdef)) or
                    not(Is_Signed(right.resultdef));

        { assume no overflow checking is require }
        checkoverflow := false;

        case nodetype of
          addn:
            begin
              cgop:=OP_ADD;
              checkoverflow:=true;
            end;
          xorn :
            begin
              cgop:=OP_XOR;
            end;
          orn :
            begin
              cgop:=OP_OR;
            end;
          andn:
            begin
              cgop:=OP_AND;
            end;
          muln:
            begin
              checkoverflow:=true;
              if unsigned then
                cgop:=OP_MUL
              else
                cgop:=OP_IMUL;
            end;
          subn :
            begin
              checkoverflow:=true;
              cgop:=OP_SUB;
            end;
          else
            InternalError(2013120104);
        end;

       checkoverflow:=
         checkoverflow and
          (left.resultdef.typ<>pointerdef) and
          (right.resultdef.typ<>pointerdef) and
          (cs_check_overflow in CurrentSettings.LocalSwitches) and not(nf_internal in flags);

       if nodetype<>subn then
        begin
          if (right.Location.Loc<>LOC_CONSTANT) then
            hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,cgop,resultdef,
               left.Location.Register,right.Location.Register,
               location.Register,checkoverflow,ovloc)
          else
            hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,cgop,resultdef,
               right.Location.Value,left.Location.Register,
               location.Register,checkoverflow,ovloc);
        end
      else  { subtract is a special case since its not commutative }
        begin
          if (nf_swapped in flags) then
            swapleftright;
          if left.Location.Loc<>LOC_CONSTANT then
            begin
              if right.Location.Loc<>LOC_CONSTANT then
                hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                    right.Location.Register,left.Location.Register,
                    location.Register,checkoverflow,ovloc)
              else
                hlcg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                  right.Location.Value,left.Location.Register,
                  location.Register,checkoverflow,ovloc);
            end
          else
            begin
              tmpreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
              hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,
                left.Location.Value,tmpreg);
              hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                right.Location.Register,tmpreg,location.Register,checkoverflow,ovloc);
            end;
        end;

        { emit overflow check if required }
        if checkoverflow then
          hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,resultdef,ovloc);
      end;


    procedure TCGAddNode.second_cmpboolean;
      begin
        second_cmpordinal;
      end;

    function TCGAddNode.needoverflowcheck: boolean;
      begin
        result:=
          (cs_check_overflow in CurrentSettings.LocalSwitches) and
          (left.resultdef.typ<>pointerdef) and
          (right.resultdef.typ<>pointerdef) and
          not(nf_internal in flags);
      end;


{*****************************************************************************
                                pass_generate_code;
*****************************************************************************}

    procedure TCGAddNode.pass_generate_code;
      begin
        case left.resultdef.typ of
          orddef :
            begin
              { handling boolean expressions }
              if Is_Boolean(left.resultdef) and
                 Is_Boolean(right.resultdef) then
                second_opboolean
{$ifndef cpu64bitalu}
              { 64bit operations }
              else if Is_64Bit(left.resultdef) then
                second_op64bit
{$endif cpu64bitalu}
              else
                second_opordinal;
            end;
          stringdef :
            begin
              second_addstring;
            end;
          setdef :
            begin
              if Is_SmallSet(TSetDef(left.resultdef)) then
                second_opsmallset
              else
                InternalError(200109041);
            end;
          arraydef :
            begin
              { support dynarr=nil }
              if Is_Dynamic_Array(left.resultdef) then
                second_opordinal
              else
                if (cs_support_vectors in CurrentSettings.GlobalSwitches) and
                   Is_Vector(left.resultdef) then
                  second_opvector
{$ifdef SUPPORT_MMX}
              else
                if Is_MMX_Able_Array(left.resultdef) then
                  second_opmmx
{$endif SUPPORT_MMX}
              else
                InternalError(200306016);
            end;
          floatdef :
            second_opfloat;
          else
            second_opordinal;
        end;
      end;

begin
   CAddNode:=TCGAddNode;
end.
