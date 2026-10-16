{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Common code generation for add nodes on the i386 and x86

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
unit nx86add;

{$i fpcdefs.inc}

  interface

    uses
      TPCompilerReal,
      symtype,
      cgbase,
      cpubase,
      node,nadd,ncgadd;

    type
      TX86AddNode = class(TCGAddNode)
      protected
        function  getresflags(unsigned : boolean) : TResFlags;
        function  getfpuresflags : TResFlags;
        procedure left_must_be_reg(opdef: TDef; opsize:TCgSize;noswap:boolean);
        procedure force_left_and_right_fpureg;
        procedure prepare_x87_locations(out refnode: TNode);
        procedure emit_op_right_left(op:TAsmOp;opsize:TCgSize;AllocFlags:boolean);
        procedure emit_generic_code(op:TAsmOp;opsize:TCgSize;unsigned,extra_not,mboverflow:boolean);

        procedure second_cmpfloatvector;

        procedure second_addfloatsse;
        procedure second_addfloatavx;
      public
        function pass_1 : TNode;override;
        function simplify(forinline : boolean) : TNode; override;
        function use_fma : boolean;override;
        procedure second_addfloat;override;

        procedure second_addsmallset;override;
        procedure second_addsmallsetelement;override;

        procedure second_add64bit;override;
        procedure second_cmpfloat;override;
        procedure second_cmpsmallset;override;
        procedure second_cmp64bit;override;

        procedure second_cmpordinal;override;
        procedure second_addordinal;override;
        procedure second_addboolean;override;
{$ifdef SUPPORT_MMX}
        procedure second_opmmx;override;
{$endif SUPPORT_MMX}
        procedure second_opvector;override;
      end;


  implementation

    uses
      GlobType,Globals,
      Verbose,CUtils,compinnr,
      CPUInfo,
      aasmbase,AAsmData,aasmcpu,
      symconst,symdef,
      cgobj,hlcgobj,cgx86,cga,cgutils,
      tgobj,ncgutil,nutils,
      ncon,nset,ninl,ncnv,ncal,nmat,
      defutil,defcmp,ConstExp,
      pass_1,pass_2,htypechk;

{ Range check must be disabled explicitly as the code serves
  on three different architecture sizes }
{$R-}

{*****************************************************************************
                                  Helpers
*****************************************************************************}

    procedure TX86AddNode.emit_generic_code(op:TAsmOp;opsize:TCgSize;unsigned,extra_not,mboverflow:boolean);
      var
        power : LongInt;
        hl4   : TAsmLabel;
        r     : TRegister;
        href  : TReference;
        overflowcheck: boolean;
        comparison: boolean;
      begin
        overflowcheck:=needoverflowcheck;
        comparison:=
          (op=A_CMP) or (op=A_TEST) or (op=A_BT) or Is_Boolean(resultdef);

        { at this point, left.location.loc should be LOC_REGISTER }
        if right.Location.Loc=LOC_REGISTER then
         begin
           { right.location is a LOC_REGISTER }
           { when swapped another result register }
           if (nodetype=subn) and (nf_swapped in flags) then
            begin
              if extra_not then
               emit_reg(A_NOT,TCGSize2Opsize[opsize],left.Location.Register);
              emit_reg_reg(op,TCGSize2Opsize[opsize],left.Location.Register,right.Location.Register);
              { newly swapped also set swapped flag }
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end
           else
            begin
              if extra_not then
                emit_reg(A_NOT,TCGSize2Opsize[opsize],right.Location.Register);
              if (op=A_ADD) or (op=A_OR) or (op=A_AND) or (op=A_XOR) or (op=A_IMUL) then
                Location_Swap(left.Location,right.Location);

              if comparison then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              emit_reg_reg(op,TCGSize2Opsize[opsize],right.Location.Register,left.Location.Register);
            end;
         end
        else
         begin
           { right.location is not a LOC_REGISTER }
           if (nodetype=subn) and (nf_swapped in flags) then
            begin
              if extra_not then
                cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,opsize,left.Location.Register,left.Location.Register);
              r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
              hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,CGSize_OrdDef(opsize),right.Location,r);

              if comparison then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              emit_reg_reg(op,TCGSize2Opsize[opsize],left.Location.Register,r);
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opsize,opsize,r,left.Location.Register);
            end
           else
            begin
               { Optimizations when right.location is a constant value }
               if (op=A_CMP) and
                  (nodetype in [EqualN,unequaln]) and
                  (right.Location.Loc=LOC_CONSTANT) and
                  (right.Location.Value=0) then
                 begin
                   { 'test $-1,%reg' is transformable into 'test $-1,spilltemp' if %reg needs
                      spilling, while 'test %reg,%reg' still requires loading into register.
                      If spilling is not necessary, it is changed back into 'test %reg,%reg' by
                      peephole optimizer (this optimization is currently available only for i386). }
                   cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$ifdef i386}
                   emit_const_reg(A_TEST,TCGSize2Opsize[opsize],aint(-1),left.Location.Register)
{$else i386}
                   emit_reg_reg(A_TEST,TCGSize2Opsize[opsize],left.Location.Register,left.Location.Register);
{$endif i386}
                 end
               else
                 if (op=A_ADD) and
                    (right.Location.Loc=LOC_CONSTANT) and
                    (right.Location.Value=1) and
                    not overflowcheck and
                    UseIncDec then
                  begin
                    emit_reg(A_INC,TCGSize2Opsize[opsize],left.Location.Register);
                  end
               else
                 if (op=A_SUB) and
                    (right.Location.Loc=LOC_CONSTANT) and
                    (right.Location.Value=1) and
                    not overflowcheck and
                    UseIncDec then
                  begin
                    emit_reg(A_DEC,TCGSize2Opsize[opsize],left.Location.Register);
                  end
               else
                 if (op=A_IMUL) and
                    (right.Location.Loc=LOC_CONSTANT) and
                    (IsPowerOf2(int64(right.Location.Value),power)) and
                    overflowcheck then
                  begin
                    emit_const_reg(A_SHL,TCGSize2Opsize[opsize],power,left.Location.Register);
                  end
                else if (op=A_IMUL) and
                    (right.Location.Loc=LOC_CONSTANT) and
                    (right.Location.Value>1) and (IsPowerOf2(int64(right.Location.Value)-1,power)) and
                    (power in [1..3]) and
                    not overflowcheck then
                  begin
                    Reference_Reset_Base(href,left.Location.Register,0,CTempPosInvalid,0,[]);
                    href.Index:=left.Location.Register;
                    href.ScaleFactor:=int64(right.Location.Value)-1;
                    left.Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[opsize],href,left.Location.Register));
                  end
               else
                 begin
                   if extra_not then
                     begin
                        r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,CGSize_OrdDef(opsize),right.Location,r);
                        emit_reg(A_NOT,TCGSize2Opsize[opsize],r);

                        if comparison or (mboverflow and overflowcheck) then
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                        emit_reg_reg(A_AND,TCGSize2Opsize[opsize],r,left.Location.Register);
                     end
                   else
                     emit_op_right_left(op,opsize,comparison or (mboverflow and overflowcheck));
                 end;
            end;
         end;

        { only in case of overflow operations }
        { produce overflow code }
        { we must put it here directly, because sign of operation }
        { is in unsigned VAR!!                                   }
        if mboverflow then
         begin
           if overflowcheck then
            begin
              CurrentAsmData.getjumplabel(hl4);
              if unsigned then
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,hl4)
              else
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,hl4);

              if not comparison then
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,hl4);
            end;
         end;
      end;


    procedure TX86AddNode.left_must_be_reg(opdef: TDef; opsize:TCgSize;noswap:boolean);
      begin
        { left location is not a register? }
        if (left.Location.Loc<>LOC_REGISTER) then
         begin
           { if right is register then we can swap the locations }
           if (not noswap) and
              (right.Location.Loc=LOC_REGISTER) then
            begin
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end
           else if (not noswap) and
              (right.Location.Loc=LOC_CREGISTER) then
            begin
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
              { maybe we can reuse a constant register when the
                operation is a comparison that doesn't change the
                value of the register }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,(nodetype in [ltn,lten,gtn,gten,EqualN,unequaln]));
              location:=left.Location;
            end
           else
            begin
              { maybe we can reuse a constant register when the
                operation is a comparison that doesn't change the
                value of the register }
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,(nodetype in [ltn,lten,gtn,gten,EqualN,unequaln]));
            end;
          end;
        if (right.Location.Loc<>LOC_CONSTANT) and
           (TCgSize2Unsigned[right.Location.Size]<>TCgSize2Unsigned[opsize]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,opdef,true);
        if (left.Location.Loc<>LOC_CONSTANT) and
           (TCgSize2Unsigned[left.Location.Size]<>TCgSize2Unsigned[opsize]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
       end;


    procedure TX86AddNode.force_left_and_right_fpureg;
      begin
        if (right.Location.Loc<>LOC_FPUREGISTER) then
          begin
            hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,false);
            if (left.Location.Loc<>LOC_FPUREGISTER) then
              hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false)
            else
              { left was on the stack => swap }
              toggleflag(nf_swapped);
          end
        { the nominator in st0 }
        else if (left.Location.Loc<>LOC_FPUREGISTER) then
          begin
            hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false)
          end
        else
          begin
            { fpu operands are always in the wrong order on the stack }
            toggleflag(nf_swapped);
          end;
      end;


    { Makes sides suitable for executing an x87 instruction:
      if either side is OS_F32/OS_F64-sized LOC_REFERENCE, it is returned in 'refnode'
      everything else is loaded to FPU stack. }
    procedure TX86AddNode.prepare_x87_locations(out refnode: TNode);
      begin
        refnode:=nil;

        { later on, no mm registers are allowed, so transfer everything to memory here
          below it is loaded into an fpu register if needed }
        if left.Location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);

        if right.Location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,right.Location,right.resultdef);

        case ord(left.Location.Loc=LOC_FPUREGISTER)+ord(right.Location.Loc=LOC_FPUREGISTER) of
          0:
            begin
              hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,false);
              if not(left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                InternalError(2013090803);
              if (left.Location.Size in [OS_F32,OS_F64]) then
                begin
                  refnode:=left;
                  toggleflag(nf_swapped);
                end
              else
                hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
            end;
          1:
            begin   { if left is on the stack then swap. }
              if (left.Location.Loc=LOC_FPUREGISTER) then
                refnode:=right
              else
                refnode:=left;
              if not(refnode.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                InternalError(2013090801);
              if not (refnode.Location.Size in [OS_F32,OS_F64]) then
                begin
                  hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,refnode.Location,refnode.resultdef,false);
                  if (refnode=right) then
                    toggleflag(nf_swapped);
                  refnode:=nil;
                end
              else
                begin
                  if (refnode=left) then
                    toggleflag(nf_swapped);
                end;
            end;
          2: { fpu operands are always in the wrong order on the stack }
            toggleflag(nf_swapped);
        else
          InternalError(2013090802);
        end;
      end;


    procedure TX86AddNode.emit_op_right_left(op:TAsmOp;opsize:TCgSize;AllocFlags:boolean);
{$ifdef x86_64}
      var
        tmpreg : TRegister;
{$endif x86_64}
      begin
        if (right.Location.Loc in [LOC_CSUBSETREG,LOC_SUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,right.resultdef,true);
        { left must be a register }
        case right.Location.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              if AllocFlags then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,TCGSize2Opsize[opsize],right.Location.Register,left.Location.Register));
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,right.Location.Reference);
              if AllocFlags then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(op,TCGSize2Opsize[opsize],right.Location.Reference,left.Location.Register));
            end;
          LOC_CONSTANT :
            begin
{$ifdef x86_64}
              { x86_64 only supports signed 32 bits constants directly }
              if (opsize in [OS_S64,OS_64]) and
                 ((right.Location.Value<low(LongInt)) or (right.Location.Value>high(LongInt))) then
                begin
                  tmpreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,right.Location.Value,tmpreg);
                  if AllocFlags then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,TCGSize2Opsize[opsize],tmpreg,left.Location.Register));
                end
              else
{$endif x86_64}
                begin
                  if AllocFlags then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(op,TCGSize2Opsize[opsize],right.Location.Value,left.Location.Register));
                end;
            end;
          else
            InternalError(200203232);
        end;
      end;


    function TX86AddNode.getresflags(unsigned : boolean) : TResFlags;
      begin
         case nodetype of
           EqualN : getresflags:=F_E;
           unequaln : getresflags:=F_NE;
          else
           if not(unsigned) then
             begin
                if nf_swapped in flags then
                  case nodetype of
                     ltn : getresflags:=F_G;
                     lten : getresflags:=F_GE;
                     gtn : getresflags:=F_L;
                     gten : getresflags:=F_LE;
                     else
                       InternalError(2013120105);
                  end
                else
                  case nodetype of
                     ltn : getresflags:=F_L;
                     lten : getresflags:=F_LE;
                     gtn : getresflags:=F_G;
                     gten : getresflags:=F_GE;
                     else
                       InternalError(2013120106);
                  end;
             end
           else
             begin
                if nf_swapped in flags then
                  case nodetype of
                     ltn : getresflags:=F_A;
                     lten : getresflags:=F_AE;
                     gtn : getresflags:=F_B;
                     gten : getresflags:=F_BE;
                     else
                       InternalError(2013120107);
                  end
                else
                  case nodetype of
                     ltn : getresflags:=F_B;
                     lten : getresflags:=F_BE;
                     gtn : getresflags:=F_A;
                     gten : getresflags:=F_AE;
                     else
                       InternalError(2013120108);
                  end;
             end;
         end;
      end;


    function TX86AddNode.getfpuresflags : TResFlags;
      begin
        if (nodetype=EqualN) then
          result:=F_FE
        else if (nodetype=unequaln) then
          result:=F_FNE
        else if (nf_swapped in flags) then
          case nodetype of
            ltn : result:=F_FA;
            lten : result:=F_FAE;
            gtn : result:=F_FB;
            gten : result:=F_FBE;
          else
            InternalError(2014031402);
          end
        else
          case nodetype of
            ltn : result:=F_FB;
            lten : result:=F_FBE;
            gtn : result:=F_FA;
            gten : result:=F_FAE;
          else
            InternalError(2014031403);
          end;
      end;

{*****************************************************************************
                                AddSmallSet
*****************************************************************************}


    procedure TX86AddNode.second_addsmallset;
      var
        SetBase : aint;
        opdef  : TDef;
        opsize : TCgSize;
        op     : TAsmOp;
        extra_not,
        noswap : boolean;
        all_member_optimization:boolean;

      begin
        pass_left_right;

        noswap:=false;
        extra_not:=false;
        all_member_optimization:=false;
        opdef:=resultdef;
        opsize:=Int_CGSize(opdef.Size);
        if (left.resultdef.typ=setdef) then
          SetBase:=TSetDef(left.resultdef).SetBase
        else
          SetBase:=TSetDef(right.resultdef).SetBase;
        case nodetype of
          addn :
            begin
              { adding elements is not commutative }
              if (nf_swapped in flags) and (left.nodetype=setelementn) then
               swapleftright;
              { are we adding set elements ? }
              if right.nodetype=setelementn then
               begin
                 { no range support for smallsets! }
                 if Assigned(TSetElementNode(right).right) then
                   InternalError(43244);
                 { btsb isn't supported }
                 if opsize=OS_8 then
                   begin
                     opsize:=OS_32;
                     opdef:=U32IntType;
                   end;
                 { bts requires both elements to be registers }
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,opdef,true);
                 register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,opdef,right.Location,SetBase);
                 op:=A_BTS;
                 noswap:=true;
               end
              else
               op:=A_OR;
            end;
          symdifn :
            op:=A_XOR;
          muln :
            op:=A_AND;
          subn :
            begin
              op:=A_AND;
              if (not(nf_swapped in flags) and (left.Location.Loc=LOC_CONSTANT) and (left.Location.Value=-1)) or
                  ((nf_swapped in flags) and (right.Location.Loc=LOC_CONSTANT) and (right.Location.Value=-1)) then
                all_member_optimization:=true;

              if (not(nf_swapped in flags)) and
                 (right.Location.Loc=LOC_CONSTANT) then
                right.Location.Value := not(right.Location.Value)
              else if (nf_swapped in flags) and
                      (left.Location.Loc=LOC_CONSTANT) then
                left.Location.Value := not(left.Location.Value)
              else
                extra_not:=true;
            end;
          xorn :
            op:=A_XOR;
          orn :
            op:=A_OR;
          andn :
            op:=A_AND;
          else
            InternalError(2003042215);
        end;
        if all_member_optimization then
          begin
            {A set expression [0..31]-x can be implemented with a simple NOT.}
            if nf_swapped in flags then
              begin
                { newly swapped also set swapped flag }
                Location_Swap(left.Location,right.Location);
                toggleflag(nf_swapped);
              end;
            hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,right.Location,right.resultdef,opdef,false);
            emit_reg(A_NOT,TCGSize2Opsize[opsize],right.Location.Register);
            location:=right.Location;
          end
        else
          begin
            { can we use the BMI1 instruction andn? }
            if (op=A_AND) and extra_not and (CPUX86_HAS_BMI1 in cpu_capabilities[CurrentSettings.CPUType]) and
              (resultdef.Size in [4{$ifdef x86_64},8{$endif x86_64}]) then
              begin
                Location_Reset(location,LOC_REGISTER,left.Location.Size);
                location.Register:=cg.GetIntRegister(CurrentAsmData.currAsmList,left.Location.Size);
                if nf_swapped in flags then
                  begin
                    Location_Swap(left.Location,right.Location);
                    toggleflag(nf_swapped);
                  end;
                hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,right.Location,right.resultdef,opdef,true);
                if not(left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,left.Location,left.resultdef,opdef,true);
                case left.Location.Loc of
                  LOC_CREGISTER,LOC_REGISTER:
                    emit_reg_reg_reg(A_ANDN,TCGSize2Opsize[opsize],left.Location.Register,right.Location.Register,location.Register);
                  LOC_CREFERENCE,LOC_REFERENCE:
                    emit_ref_reg_reg(A_ANDN,TCGSize2Opsize[opsize],left.Location.Reference,right.Location.Register,location.Register);
                  else
                    InternalError(2018040201);
                end;
              end
            else
              begin
                { left must be a register }
                left_must_be_reg(opdef,opsize,noswap);
                emit_generic_code(op,opsize,true,extra_not,false);
                location_freetemp(CurrentAsmData.CurrAsmList,right.Location);

                { left is always a register and contains the result }
                location:=left.Location;
              end;
          end;

        { fix the changed opsize we did above because of the missing btsb }
        if opsize<>Int_CGSize(resultdef.Size) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,opdef,CGSize_OrdDef(Int_CGSize(resultdef.Size)),false);
      end;


    procedure TX86AddNode.second_addsmallsetelement;
      var
        SetBase, mask: aint;
      begin
        if resultdef.Size=1 then
          inherited second_addsmallsetelement
        else
          begin
            if nodetype<>addn then
              InternalError(2022090502);
            { no range support for smallsets }
            if Assigned(TSetElementNode(right).right) then
              InternalError(2022090501);
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
                mask:=aint(1 shl (right.Location.Value-SetBase));
                hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,resultdef,
                  mask,left.Location.Register,location.Register);
              end
            else
              begin
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,resultdef,true);
                register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,resultdef,right.Location,SetBase);
                if left.Location.Loc <> LOC_CONSTANT then
                  hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,
                      left.Location.Register,location.Register)
                else
                  hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,
                      left.Location.Value,location.Register);
                emit_reg_reg(A_BTS,TCGSize2Opsize[Def_CGSize(resultdef)],right.Location.Register,location.Register);
              end;
          end;
      end;



    procedure TX86AddNode.second_cmpsmallset;
      var
        opdef  : TDef;
        opsize : TCgSize;
        op     : TAsmOp;
      begin
        pass_left_right;
        opdef:=left.resultdef;
        opsize:=Int_CGSize(opdef.Size);
        case nodetype of
          EqualN,
          unequaln :
            op:=A_CMP;
          lten,gten:
            begin
              if (not(nf_swapped in flags) and (nodetype = lten)) or
                 ((nf_swapped in flags) and (nodetype = gten)) then
                swapleftright;
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
              emit_op_right_left(A_AND,opsize,False);
              op:=A_CMP;
              { warning: ugly hack, we need a JE so change the node to equaln }
              nodetype:=EqualN;
            end;
          else
            InternalError(2003042204);
        end;
        { left must be a register }
        left_must_be_reg(opdef,opsize,false);
        emit_generic_code(op,opsize,true,false,false);
        location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
        location_freetemp(CurrentAsmData.CurrAsmList,left.Location);

        Location_Reset(location,LOC_FLAGS,OS_NO);
        location.ResFlags:=getresflags(true);
      end;


{*****************************************************************************
                                AddMMX
*****************************************************************************}

{$ifdef SUPPORT_MMX}
    procedure TX86AddNode.second_opmmx;
      var
        op         : TAsmOp;
        cmpop      : boolean;
        mmxbase    : TMMXType;
        hreg,
        hregister  : TRegister;
      begin
        pass_left_right;

        cmpop:=false;
        op:=A_NOP;

        mmxbase:=MMX_Type(left.resultdef);
        Location_Reset(location,LOC_MMXREGISTER,Def_CGSize(resultdef));
        case nodetype of
          addn :
            begin
              if (cs_mmx_saturation in CurrentSettings.LocalSwitches) then
                begin
                   case mmxbase of
                      mmxs8bit:
                        op:=A_PADDSB;
                      mmxu8bit:
                        op:=A_PADDUSB;
                      mmxs16bit,mmxfixed16:
                        op:=A_PADDSW;
                      mmxu16bit:
                        op:=A_PADDUSW;
                      else
                       ;
                   end;
                end
              else
                begin
                   case mmxbase of
                      mmxs8bit,mmxu8bit:
                        op:=A_PADDB;
                      mmxs16bit,mmxu16bit,mmxfixed16:
                        op:=A_PADDW;
                      mmxs32bit,mmxu32bit:
                        op:=A_PADDD;
                      else
                       ;
                   end;
                end;
            end;
          muln :
            begin
               case mmxbase of
                  mmxs16bit,mmxu16bit:
                    op:=A_PMULLW;
                  mmxfixed16:
                    op:=A_PMULHW;
                  else
                   ;
               end;
            end;
          subn :
            begin
              if (cs_mmx_saturation in CurrentSettings.LocalSwitches) then
                begin
                   case mmxbase of
                      mmxs8bit:
                        op:=A_PSUBSB;
                      mmxu8bit:
                        op:=A_PSUBUSB;
                      mmxs16bit,mmxfixed16:
                        op:=A_PSUBSB;
                      mmxu16bit:
                        op:=A_PSUBUSW;
                      else
                       ;
                   end;
                end
              else
                begin
                   case mmxbase of
                      mmxs8bit,mmxu8bit:
                        op:=A_PSUBB;
                      mmxs16bit,mmxu16bit,mmxfixed16:
                        op:=A_PSUBW;
                      mmxs32bit,mmxu32bit:
                        op:=A_PSUBD;
                      else
                       ;
                   end;
                end;
            end;
          xorn:
            op:=A_PXOR;
          orn:
            op:=A_POR;
          andn:
            op:=A_PAND;
          else
            InternalError(2003042214);
        end;

        if op = A_NOP then
          InternalError(201408201);

        { left and right no register?  }
        { then one must be demanded    }
        if (left.Location.Loc<>LOC_MMXREGISTER) then
         begin
           if (right.Location.Loc=LOC_MMXREGISTER) then
            begin
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end
           else
            begin
              { register variable ? }
              if (left.Location.Loc=LOC_CMMXREGISTER) then
               begin
                 hregister:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
                 emit_reg_reg(A_MOVQ,S_NO,left.Location.Register,hregister);
               end
              else
               begin
                 if not(left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  InternalError(200203245);

                 hregister:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
                 TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,left.Location.Reference);
                 emit_ref_reg(A_MOVQ,S_NO,left.Location.Reference,hregister);
               end;

              Location_Reset(left.Location,LOC_MMXREGISTER,OS_NO);
              left.Location.Register:=hregister;
            end;
         end;

        { at this point, left.location.loc should be LOC_MMXREGISTER }
        if right.Location.Loc<>LOC_MMXREGISTER then
         begin
           if (nodetype=subn) and (nf_swapped in flags) then
            begin
              hreg:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
              if right.Location.Loc=LOC_CMMXREGISTER then
               begin
                 emit_reg_reg(A_MOVQ,S_NO,right.Location.Register,hreg);
                 emit_reg_reg(op,S_NO,left.Location.Register,hreg);
               end
              else
               begin
                 if not(left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  InternalError(2002032412);
                 TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,right.Location.Reference);
                 emit_ref_reg(A_MOVQ,S_NO,right.Location.Reference,hreg);
                 emit_reg_reg(op,S_NO,left.Location.Register,hreg);
               end;
               location.Register:=hreg;
            end
           else
            begin
              if (right.Location.Loc=LOC_CMMXREGISTER) then
                emit_reg_reg(op,S_NO,right.Location.Register,left.Location.Register)
              else
               begin
                 if not(right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  InternalError(200203246);
                 TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,right.Location.Reference);
                 emit_ref_reg(op,S_NO,right.Location.Reference,left.Location.Register);
               end;
              location.Register:=left.Location.Register;
            end;
          end
        else
          begin
            { right.location=LOC_MMXREGISTER }
            if (nodetype=subn) and (nf_swapped in flags) then
             begin
               emit_reg_reg(op,S_NO,left.Location.Register,right.Location.Register);
               Location_Swap(left.Location,right.Location);
               toggleflag(nf_swapped);
             end
            else
             begin
               emit_reg_reg(op,S_NO,right.Location.Register,left.Location.Register);
             end;
            location.Register:=left.Location.Register;
          end;

        location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
        if cmpop then
          location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
      end;
{$endif SUPPORT_MMX}


{*****************************************************************************
                                AddFloat
*****************************************************************************}

    procedure TX86AddNode.second_addfloatsse;
      var
        op : TOpCG;
        sqr_sum : boolean;
        tmp : TNode;
      begin
        sqr_sum:=false;
        if (CurrentSettings.FPUType>=fpu_sse3) and
           Use_VectorFPU(resultdef) and
           (nodetype in [addn,subn]) and
          (left.nodetype=inlinen) and (TInlineNode(left).inlinenumber=in_sqr_real) and
          (right.nodetype=inlinen) and (TInlineNode(right).inlinenumber=in_sqr_real) then
          begin
            sqr_sum:=true;
            tmp:=TInlineNode(left).left;
            TInlineNode(left).left:=nil;
            left.free;
            left:=tmp;

            tmp:=TInlineNode(right).left;
            TInlineNode(right).left:=nil;
            right.free;
            right:=tmp;
          end;

        pass_left_right;
        { fpu operands are always in reversed order on the stack }
        if (left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          toggleflag(nf_swapped);

        if (nf_swapped in flags) then
          { can't use swapleftright if both are on the fpu stack, since then }
          { both are "R_ST" -> nothing would change -> manually switch       }
          if (left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
             (right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            emit_none(A_FXCH,S_NO)
          else
            swapleftright;

        case nodetype of
          addn :
            op:=OP_ADD;
          muln :
            op:=OP_MUL;
          subn :
            op:=OP_SUB;
          slashn :
            op:=OP_DIV;
          else
            InternalError(200312231);
        end;

        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));

        if sqr_sum then
          begin
            if nf_swapped in flags then
              swapleftright;

            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,true);
            location:=left.Location;
            if Is_Double(resultdef) then
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,right.Location.Register,location.Register));
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPD,S_NO,location.Register,location.Register));
                case nodetype of
                  addn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPD,S_NO,location.Register,location.Register));
                  subn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPD,S_NO,location.Register,location.Register));
                  else
                    InternalError(201108162);
                end;
              end
            else
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_UNPCKLPS,S_NO,right.Location.Register,location.Register));
                { ensure that bits 64..127 contain valid values }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,location.Register,location.Register));
                { the data is now in bits 0..32 and 64..95 }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPS,S_NO,location.Register,location.Register));
                case nodetype of
                  addn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPS,S_NO,location.Register,location.Register));
                    end;
                  subn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPS,S_NO,location.Register,location.Register));
                    end;
                  else
                    InternalError(201108163);
                end;
              end
          end
        { we can use only right as left operand if the operation is commutative }
        else if (right.Location.Loc=LOC_MMREGISTER) and (op in [OP_ADD,OP_MUL]) then
          begin
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            cg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,right.Location.Size,location.Size,right.Location.Register,location.Register,MMS_MoveScalar);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
            cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,op,location.Size,left.Location,location.Register,MMS_MoveScalar);

            if left.Location.Loc=LOC_REFERENCE then
              tg.ungetiftemp(CurrentAsmData.CurrAsmList,left.Location.Reference);
          end
        else
          begin
            if nf_swapped in flags then
              swapleftright;

            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);

            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,location.Size,left.Location,location.Register,MMS_MoveScalar);

            if left.Location.Loc=LOC_REFERENCE then
              tg.ungetiftemp(CurrentAsmData.CurrAsmList,left.Location.Reference);

            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,right.Location,right.resultdef);

            cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,op,location.Size,right.Location,location.Register,MMS_MoveScalar);

            if right.Location.Loc=LOC_REFERENCE then
              tg.ungetiftemp(CurrentAsmData.CurrAsmList,right.Location.Reference);
          end;
      end;


    procedure TX86AddNode.second_addfloatavx;
      var
        op : TOpCG;
        sqr_sum : boolean;
        {$ifdef dummy}
        tmp : TNode;
        {$endif dummy}
      begin
        sqr_sum:=false;
{$ifdef dummy}
        if (CurrentSettings.FPUType>=fpu_sse3) and
           Use_VectorFPU(resultdef) and
           (nodetype in [addn,subn]) and
          (left.nodetype=inlinen) and (TInlineNode(left).inlinenumber=in_sqr_real) and
          (right.nodetype=inlinen) and (TInlineNode(right).inlinenumber=in_sqr_real) then
          begin
            sqr_sum:=true;
            tmp:=TInlineNode(left).left;
            TInlineNode(left).left:=nil;
            left.free;
            left:=tmp;

            tmp:=TInlineNode(right).left;
            TInlineNode(right).left:=nil;
            right.free;
            right:=tmp;
          end;
{$endif dummy}

        pass_left_right;
        { fpu operands are always in reversed order on the stack }
        if (left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          toggleflag(nf_swapped);

        if (nf_swapped in flags) then
          { can't use swapleftright if both are on the fpu stack, since then }
          { both are "R_ST" -> nothing would change -> manually switch       }
          if (left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
             (right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            emit_none(A_FXCH,S_NO)
          else
            swapleftright;

        case nodetype of
          addn :
            op:=OP_ADD;
          muln :
            op:=OP_MUL;
          subn :
            op:=OP_SUB;
          slashn :
            op:=OP_DIV;
          else
            InternalError(2003122303);
        end;

        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));

        if sqr_sum then
          begin
            if nf_swapped in flags then
              swapleftright;

            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,true);
            location:=left.Location;
            if Is_Double(resultdef) then
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,right.Location.Register,location.Register));
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPD,S_NO,location.Register,location.Register));
                case nodetype of
                  addn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPD,S_NO,location.Register,location.Register));
                  subn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPD,S_NO,location.Register,location.Register));
                  else
                    InternalError(2011081601);
                end;
              end
            else
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_UNPCKLPS,S_NO,right.Location.Register,location.Register));
                { ensure that bits 64..127 contain valid values }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,location.Register,location.Register));
                { the data is now in bits 0..32 and 64..95 }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPS,S_NO,location.Register,location.Register));
                case nodetype of
                  addn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPS,S_NO,location.Register,location.Register));
                    end;
                  subn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPS,S_NO,location.Register,location.Register));
                    end;
                  else
                    InternalError(2011081604);
                end;
              end
          end
        { left*2 ? }
        else if (nodetype=muln) and is_constrealnode(right) and Is_Number_Float(TRealConstNode(right).value_real) and (TRealConstNode(right).value_real=2) then
          begin
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
            cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,location.Size,
              left.Location.Register,
              left.Location.Register,
              location.Register,
              MMS_MoveScalar);
          end
        { right*2 ? }
        else if (nodetype=muln) and is_constrealnode(left) and Is_Number_Float(TRealConstNode(left).value_real) and (TRealConstNode(left).value_real=2) then
          begin
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,right.Location.Size);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,true);
            cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,location.Size,
              right.Location.Register,
              right.Location.Register,
              location.Register,
              MMS_MoveScalar);
          end
        { we can use only right as left operand if the operation is commutative }
        else if (right.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) and (op in [OP_ADD,OP_MUL]) then
          begin
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
            cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,op,location.Size,
              left.Location,
              right.Location.Register,
              location.Register,
              MMS_MoveScalar);
          end
        else
          begin
            if (nf_swapped in flags) then
              swapleftright;

            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,right.Location,right.resultdef);
            cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,op,location.Size,
              right.Location,
              left.Location.Register,
              location.Register,
              MMS_MoveScalar);
          end;
      end;


    function TX86AddNode.pass_1: TNode;
      begin
        { only pass_1 might set the resultdef as it could be set to nil by some previous
          code transformation. As we need a valid left/right.resultdef later on, ensure
          a valid result def is set, see also issue #40727 }
        if not(Assigned(left.resultdef)) then
          TypeCheckPass(left);
        if not(Assigned(right.resultdef)) then
          TypeCheckPass(right);

        { on x86, we do not support fpu registers, so in case of operations using the x87, it
          is normally useful, not to put the operands into registers which would be mm register

          this should be called before pass_1 so we have a proper expectloc }
        if ((left.resultdef.typ=floatdef) or (right.resultdef.typ=floatdef)) and
          (not(Use_VectorFPU(left.resultdef)) and not(Use_VectorFPU(right.resultdef)) and
           not(Use_VectorFPU(resultdef))) then
          begin
            make_not_regable(left,[ra_addr_regable]);
            make_not_regable(right,[ra_addr_regable]);
          end;
        Result:=inherited pass_1;
        { correct expectloc, it does not matter of Result is set as another pass_1 is run on it
          which will fix that one }
        if Use_VectorFPU(resultdef) then
          expectloc:=LOC_MMREGISTER;
      end;


    function TX86AddNode.simplify(forinline : boolean) : TNode;
      var
        t, m, ThisNode, ConstNode: TNode;
        lt,rt, ThisType: TNodeType;
        ThisDef: TDef;
        DoOptimisation: Boolean;

        reciprocal, comparison, divisor: AWord;
        shift, N: Byte;
      begin
        { Load into local variables to reduce the number of pointer deallocations }
        rt:=right.nodetype;
        lt:=left.nodetype;

        DoOptimisation:=False;

{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
        if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
          { The presence of overflow checks tends to cause internal errors with the multiplication nodes }
          not (cs_check_overflow in CurrentSettings.LocalSwitches) and
          (nodetype in [EqualN,unequaln]) then
          begin
            if (lt=modn) and (rt=ordconstn) and (TOrdConstNode(right).Value.uvalue=0) then
              begin
                t:=left;
                m:=right;
              end
            else if (rt=modn) and (lt=ordconstn) and (TOrdConstNode(left).Value.uvalue=0) then
              begin
                t:=right;
                m:=left;
              end
            else
              begin
                t:=nil;
                m:=nil;
              end;

            if Assigned(t) and (TModDivNode(t).right.nodetype=ordconstn) and
{$ifndef cpu64bitalu}
              { Converting Int64 and QWord division doesn't work under i386 }
{$ifndef cpu32bitalu}
              (TModDivNode(t).resultdef.Size < 4) and
{$else cpu32bitalu}
              (TModDivNode(t).resultdef.Size < 8) and
{$endif cpu32bitalu}
{$endif cpu64bitalu}
              (TOrdConstNode(TModDivNode(t).right).Value>=3) then
              begin
                divisor:=TOrdConstNode(TModDivNode(t).right).Value.uvalue;

                { Exclude powers of 2, as there are more efficient ways to handle those }
                if PopCnt(divisor)>1 then
                  begin
                    if Is_Signed(TModDivNode(t).left.resultdef) then
                      begin
                        { See pages 250-251 of Hacker's Delight, Second Edition
                          for an explanation and proof of the algorithm, but
                          essentially, we're doing the following:

                          - Convert the divisor d to the form k.2^b if it isn't
                            already odd (in which case, k = d and b = 0)
                          - Calculate r, the multiplicative inverse of k modulo 2^N
                          - Calculate c = floor(2^(N-1) / k) & -(2^b)
                          - Let q = ((n * r) + c) ror b (mod 2^N)
                          - Repurpose c to equal floor(2c / 2^b) = c shr (b - 1)
                            (some RISC platforms will benefit from doing this over
                            precalculating the modified constant. For x86,
                            it's better with the constant precalculated for
                            32-bit and under, but for 64-bit, use SHR. )
                          - If q is below or equal to c, then (n mod d) = 0
                          }
                        while True do
                          begin
                            ThisNode:=TModDivNode(t).left;
                            case ThisNode.nodetype of
                              typeconvn:
                                begin
                                  ThisDef:=TTypeConvNode(ThisNode).left.resultdef;
                                  { See if we can simplify things to a smaller ordinal to
                                    reduce code size and increase speed }
                                  if Is_Signed(ThisDef) and
                                    Is_Integer(ThisDef) and
                                    { Byte-sized multiplications can cause problems }
                                    (ThisDef.Size>=2) and
                                    { Make sure the divisor is in range }
                                    (divisor>=TOrdDef(ThisDef).low) and
                                    (divisor<=TOrdDef(ThisDef).high) then
                                    begin
                                      TOrdConstNode(TModDivNode(t).right).resultdef:=ThisDef;
                                      TOrdConstNode(m).resultdef:=ThisDef;
                                      TModDivNode(t).resultdef:=ThisDef;

                                      { Destroy the typeconv node }
                                      TModDivNode(t).left:=TTypeConvNode(ThisNode).left;
                                      TTypeConvNode(ThisNode).left:=nil;
                                      ThisNode.Free;
                                      Continue;
                                    end;
                                  end;
                              ordconstn:
                                begin
                                  { Just simplify into a constant }
                                  Result:=inherited simplify(forinline);
                                  Exit;
                                end;
                              else
                                ;
                            end;

                            DoOptimisation:=True;
                            Break;
                          end;

                        if DoOptimisation then
                          begin
                            ThisDef:=TModDivNode(t).left.resultdef;

                            if nodetype = EqualN then
                              ThisType:=lten
                            else
                              ThisType:=gtn;

                            N:=ThisDef.Size*8;
                            Calc_Mul_Inverse(N, TOrdConstNode(TModDivNode(t).right).Value.uvalue, reciprocal, shift);

                            { Construct the following node tree for odd divisors:
                                <lten> (for equaln) or <gtn> (for notequaln)
                                  <addn>
                                    <muln>
                                      <typeconv signed-to-unsigned>
                                        <numerator node (TModDivNode(t).left)>
                                      <reciprocal constant>
                                    <comparison constant (effectively a signed shift)>
                                  <comparison constant * 2>

                              For even divisors, convert them to the form k.2^b, with
                              odd k, then construct the following:
                                <lten> (for equaln) or <gtn> (for notequaln)
                                  <ror>
                                    (b)
                                    <addn>
                                      <muln>
                                        <typeconv signed-to-unsigned>
                                          <numerator node (TModDivNode(t).left)>
                                        <reciprocal constant>
                                      <comparison constant (effectively a signed shift)>
                                  <comparison constant shr (b - 1)>
                            }

                            ThisNode:=CTypeConvNode.Create_Internal(TModDivNode(t).left, ThisDef);
                            TTypeConvNode(ThisNode).convtype:=tc_int_2_int;
                            ThisDef:=Get_Unsigned_IntType(ThisDef);
                            ThisNode.resultdef:=ThisDef;

                            TModDivNode(t).left:=nil;

                            ConstNode:=COrdConstNode.create(reciprocal, ThisDef, False);
                            ConstNode.resultdef:=ThisDef;

                            ThisNode:=CAddNode.Create_Internal(muln, ThisNode, ConstNode);
                            ThisNode.resultdef:=ThisDef;

{$push}
{$warnings off}
                            if shift>0 then
                              comparison:=((aWord(1) shl ((N-1) and (SizeOf(aWord)*8-1))) div (divisor shr shift)) and -(1 shl shift)
                            else
                              comparison:=(aWord(1) shl ((N-1) and (SizeOf(aWord)*8-1))) div divisor;
{$pop}
                            ConstNode:=COrdConstNode.create(comparison, ThisDef, False);
                            ConstNode.resultdef:=ThisDef;

                            ThisNode:=CAddNode.Create_Internal(addn, ThisNode, ConstNode);
                            ThisNode.resultdef:=ThisDef;

                            if shift>0 then
                              begin
                                ConstNode:=COrdConstNode.create(shift, U8IntType, False);
                                ConstNode.resultdef:=U8IntType;
                                ThisNode:=CInlineNode.createintern(in_ror_x_y,false,
                                  CCallParaNode.create(ConstNode,
                                  CCallParaNode.create(ThisNode, nil)));

                                ThisNode.resultdef:=ThisDef;

                                ConstNode:=COrdConstNode.create(comparison shr (shift - 1), ThisDef, False);
                              end
                            else
                              ConstNode:=COrdConstNode.create(comparison*2, ThisDef, False);

                            ConstNode.resultdef:=ThisDef;

                            Result:=CAddNode.Create_Internal(ThisType, ThisNode, ConstNode);
                            Result.resultdef:=resultdef;
                            Exit;
                          end;
                      end
                    else
                      begin
                        { For bit length N, convert "(x mod d) = 0" or "(x mod d) <> 0", where
                          d is an odd-numbered integer constant, to "(x * r) <= m", where
                          dr = 1 (mod 2^N) and m = floor(2^N / d).

                          If d is even, convert to the form k.2^b, where k is odd, then
                          convert to "(x * r) ror b <= m", where kr = 1 (mod 2^N) and
                          m = floor(2^N / d) = floor(2^(N-b) / k) }
                        while True do
                          begin
                            ThisNode:=TModDivNode(t).left;
                            case ThisNode.nodetype of
                              typeconvn:
                                begin
                                  ThisDef:=TTypeConvNode(ThisNode).left.resultdef;
                                  { See if we can simplify things to a smaller ordinal to
                                    reduce code size and increase speed }
                                  if not Is_Signed(ThisDef) and
                                    Is_Integer(ThisDef) and
                                    { Byte-sized multiplications can cause problems }
                                    (ThisDef.Size>=2) and
                                    { Make sure the divisor is in range }
                                    (divisor>=TOrdDef(ThisDef).low) and
                                    (divisor<=TOrdDef(ThisDef).high) then
                                    begin
                                      TOrdConstNode(TModDivNode(t).right).resultdef:=ThisDef;
                                      TOrdConstNode(m).resultdef:=ThisDef;
                                      TModDivNode(t).resultdef:=ThisDef;

                                      { Destroy the typeconv node }
                                      TModDivNode(t).left:=TTypeConvNode(ThisNode).left;
                                      TTypeConvNode(ThisNode).left:=nil;
                                      ThisNode.Free;
                                      Continue;
                                    end;
                                  end;
                              ordconstn:
                                begin
                                  { Just simplify into a constant }
                                  Result:=inherited simplify(forinline);
                                  Exit;
                                end;
                              else
                                ;
                            end;

                            DoOptimisation:=True;
                            Break;
                          end;

                        if DoOptimisation then
                          begin
                            ThisDef:=TModDivNode(t).left.resultdef;

                            { Construct the following node tree for odd divisors:
                                <lten> (for equaln) or <gtn> (for notequaln)
                                  <muln>
                                    <numerator node (TModDivNode(t).left)>
                                    <reciprocal constant>
                                  (2^N / divisor)

                              For even divisors, convert them to the form k.2^b, with
                              odd k, then construct the following:
                                <lten> (for equaln) or <gtn> (for notequaln)
                                  <ror>
                                    (b)
                                    <muln>
                                      <numerator node (TModDivNode(t).left)>
                                      <reciprocal constant>
                                  (2^N / divisor)
                            }

                            if nodetype=EqualN then
                              ThisType:=lten
                            else
                              ThisType:=gtn;

                            N:=ThisDef.Size*8;
                            Calc_Mul_Inverse(N, TOrdConstNode(TModDivNode(t).right).Value.uvalue, reciprocal, shift);

                            ConstNode:=COrdConstNode.create(reciprocal, ThisDef, False);
                            ConstNode.resultdef:=ThisDef;

                            ThisNode:=CAddNode.Create_Internal(muln, TModDivNode(t).left, ConstNode);
                            ThisNode.resultdef:=ThisDef;

                            TModDivNode(t).left:=nil;

                            if shift>0 then
                              begin
                                ConstNode:=COrdConstNode.create(shift, U8IntType, False);
                                ConstNode.resultdef:=U8IntType;
                                ThisNode:=CInlineNode.createintern(in_ror_x_y,false,
                                  CCallParaNode.create(ConstNode,
                                  CCallParaNode.create(ThisNode, nil)));

                                ThisNode.resultdef:=ThisDef;

                                comparison:=(aWord(1) shl ((N-shift) and (SizeOf(aWord)*8-1))) div (divisor shr shift);
                              end
                            else
                              begin
{$push}
{$warnings off}
                                { Because 2^N and divisor are relatively prime,
                                  floor(2^N / divisor) = floor((2^N - 1) / divisor) }
                                comparison:=(aWord(not 0) shr (((SizeOf(aWord)*8)-N) and (SizeOf(aWord)*8-1))) div divisor;
{$pop}
                              end;

                            ConstNode:=COrdConstNode.create(comparison, ThisDef, False);
                            ConstNode.resultdef:=ThisDef;

                            Result:=CAddNode.Create_Internal(ThisType, ThisNode, ConstNode);
                            Result.resultdef:=resultdef;
                            Exit;
                          end;
                      end;
                  end;
              end;
          end;
{$ifend defined(cpu64bitalu) or defined(cpu32bitalu)}
        Result:=inherited simplify(forinline);
      end;


    function TX86AddNode.use_fma : boolean;
      begin

        { test if the result stays in an xmm register, fiddeling with fpu registers and fma makes no sense }
        Result:=Use_VectorFPU(resultdef) and
          ((fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[]);

      end;


    procedure TX86AddNode.second_cmpfloatvector;
      var
        op : TAsmOp;
      const
        ops_single: array[boolean] of TAsmOp = (A_COMISS,A_VCOMISS);
        ops_double: array[boolean] of TAsmOp = (A_COMISD,A_VCOMISD);
      begin
        if Is_Single(left.resultdef) then
          op:=ops_single[UseAVX]
        else if Is_Double(left.resultdef) then
          op:=ops_double[UseAVX]
        else
          InternalError(200402222);
        pass_left_right;

        { fpu operands are always in reversed order on the stack }
        if (left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          toggleflag(nf_swapped);

        Location_Reset(location,LOC_FLAGS,OS_NO);

        { Direct move fpu->mm register is not possible, so force any fpu operands to
          memory (not to mm registers because one of the memory locations can be used
          directly in compare instruction, yielding shorter code) }
        if left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
        if right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,right.Location,right.resultdef);

        if (right.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
          begin
            case left.Location.Loc of
              LOC_REFERENCE,LOC_CREFERENCE:
                begin
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,left.Location.Reference);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(op,S_NO,left.Location.Reference,right.Location.Register));
                end;
              LOC_MMREGISTER,LOC_CMMREGISTER:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,S_NO,left.Location.Register,right.Location.Register));
              else
                InternalError(200402221);
            end;
            toggleflag(nf_swapped);
          end
        else
          begin
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
            case right.Location.Loc of
              LOC_REFERENCE,LOC_CREFERENCE:
                begin
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,right.Location.Reference);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(op,S_NO,right.Location.Reference,left.Location.Register));
                end;
              LOC_MMREGISTER,LOC_CMMREGISTER:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,S_NO,right.Location.Register,left.Location.Register));
              else
                InternalError(200402223);
            end;
          end;
        location.ResFlags:=getfpuresflags;
        location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
        location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
      end;


    procedure TX86AddNode.second_opvector;
      var
        op : TOpCG;
      begin
        pass_left_right;
        if (nf_swapped in flags) then
          swapleftright;

        case nodetype of
          addn :
            op:=OP_ADD;
          muln :
            op:=OP_MUL;
          subn :
            op:=OP_SUB;
          slashn :
            op:=OP_DIV;
          else
            InternalError(200610071);
        end;

        if Fits_In_MM_Register(left.resultdef) then
          begin
            Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
            { we can use only right as left operand if the operation is commutative }
            if (right.Location.Loc=LOC_MMREGISTER) and (op in [OP_ADD,OP_MUL]) then
              begin
                if UseAVX then
                  begin
                    location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,OS_VECTOR);
                    cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,op,TFloat2TCgSize[TFloatDef(left.resultdef).FloatType],left.Location,right.Location.Register,location.Register,nil);
                  end
                else
                  begin
                    location.Register:=right.Location.Register;
                    cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,op,TFloat2TCgSize[TFloatDef(left.resultdef).FloatType],left.Location,location.Register,nil);
                  end;
              end
            else
              begin
                location_force_mmreg(CurrentAsmData.CurrAsmList,left.Location,false);
                if UseAVX then
                  begin
                    location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,OS_VECTOR);
                    cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,op,
                      TFloat2TCgSize[TFloatDef(TArrayDef(left.resultdef).ElementDef).FloatType],right.Location,left.Location.Register,location.Register,nil);
                  end
                else
                  begin
                    location.Register:=left.Location.Register;
                    cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,op,
                      TFloat2TCgSize[TFloatDef(TArrayDef(left.resultdef).ElementDef).FloatType],right.Location,location.Register,nil);
                  end;
              end;
          end
        else
          begin
            { not yet supported }
            InternalError(200610072);
          end
      end;


    procedure TX86AddNode.second_addfloat;
      const
        ops_add:  array[boolean] of TAsmOp = (A_FADDP,A_FADD);
        ops_mul:  array[boolean] of TAsmOp = (A_FMULP,A_FMUL);
        ops_sub:  array[boolean] of TAsmOp = (A_FSUBP,A_FSUB);
        ops_rsub: array[boolean] of TAsmOp = (A_FSUBRP,A_FSUBR);
        ops_div:  array[boolean] of TAsmOp = (A_FDIVP,A_FDIV);
        ops_rdiv: array[boolean] of TAsmOp = (A_FDIVRP,A_FDIVR);
      var
        op : TAsmOp;
        refnode, hp: TNode;
        hasref : boolean;
      begin
        if Use_VectorFPU(resultdef)
{$ifndef x86_64}
          { Make sure currency typs etc. aren't passed through SSE/AVX }
          and Use_VectorFPU(left.resultdef)
          and Use_VectorFPU(right.resultdef)
{$endif x86_64}
          then
          begin
            if UseAVX then
              second_addfloatavx
            else
              second_addfloatsse;
            exit;
          end;

        { can the operation do the conversion? }
        if (left.nodetype=typeconvn) and (Is_Double(TTypeConvNode(left).left.resultdef) or Is_Single(TTypeConvNode(left).left.resultdef)) then
          begin
            hp:=left;
            left:=TTypeConvNode(left).left;
            TTypeConvNode(hp).left:=nil;
            hp.Free;
          end;
        if (right.nodetype=typeconvn) and (Is_Double(TTypeConvNode(right).left.resultdef) or Is_Single(TTypeConvNode(right).left.resultdef)) then
          begin
            hp:=right;
            right:=TTypeConvNode(right).left;
            TTypeConvNode(hp).left:=nil;
            hp.Free;
          end;

        pass_left_right;
        prepare_x87_locations(refnode);
        hasref:=Assigned(refnode);

        case nodetype of
          addn :
            op:=ops_add[hasref];
          muln :
            op:=ops_mul[hasref];
          subn :
            if (nf_swapped in flags) then
              op:=ops_rsub[hasref]
            else
              op:=ops_sub[hasref];
          slashn :
            if (nf_swapped in flags) then
              op:=ops_rdiv[hasref]
            else
              op:=ops_div[hasref];
          else
            InternalError(2003042203);
        end;

        if hasref then
          emit_ref(op,tcgsize2opsize[refnode.Location.Size],refnode.Location.Reference)
        else
          begin
            emit_reg_reg(op,S_NO,NR_ST,NR_ST1);
            TCGX86(cg).dec_fpu_stack;
          end;

        Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
        location.Register:=NR_ST;
      end;


    procedure TX86AddNode.second_cmpfloat;

      begin
        if Use_VectorFPU(left.resultdef) or Use_VectorFPU(right.resultdef) then
          begin
            second_cmpfloatvector;
            exit;
          end;

        pass_left_right;
        force_left_and_right_fpureg;

{$ifndef x86_64}
        if CurrentSettings.CPUType<cpu_Pentium2 then
          begin
            emit_none(A_FCOMPP,S_NO);
            TCGX86(cg).dec_fpu_stack;
            TCGX86(cg).dec_fpu_stack;

            { load fpu flags }

              begin
                cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_AX);
                emit_reg(A_FNSTSW,S_NO,NR_AX);
                emit_none(A_SAHF,S_NO);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_AX);
              end;
            if cs_fpu_fwait in CurrentSettings.LocalSwitches then
              CurrentAsmData.CurrAsmList.concat(TAICPU.Op_none(A_FWAIT,S_NO));
          end
        else
{$endif x86_64}
          begin
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCOMIP,S_NO,NR_ST1,NR_ST0));
            { fcomip pops only one fpu register }
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg(A_FSTP,S_NO,NR_ST0));
            TCGX86(cg).dec_fpu_stack;
            TCGX86(cg).dec_fpu_stack;
          end;

        Location_Reset(location,LOC_FLAGS,OS_NO);
        location.ResFlags:=getfpuresflags;
      end;


{*****************************************************************************
                                  Add64bit
*****************************************************************************}

    procedure TX86AddNode.second_add64bit;
      begin
{$ifdef cpu64bitalu}
        second_addordinal;
{$else cpu64bitalu}
        { must be implemented separate }
        InternalError(200402042);
{$endif cpu64bitalu}
      end;


    procedure TX86AddNode.second_cmp64bit;
      begin
{$ifdef cpu64bitalu}
        second_cmpordinal;
{$else cpu64bitalu}
        { must be implemented separate }
        InternalError(200402043);
{$endif cpu64bitalu}
      end;


{*****************************************************************************
                                  AddOrdinal
*****************************************************************************}

    procedure TX86AddNode.second_addordinal;
      var
         opsize : TCgSize;
         unsigned : boolean;
         cgop : TOpCG;
         checkoverflow : Boolean;
         ovloc : TLocation;
         tmpreg : TRegister;
         indexnode : TNode;

         procedure MakeBZHI(use_tmpreg: Boolean);
           begin
             { allocate registers }
             hlcg.Location_Force_Reg(
               CurrentAsmData.CurrAsmList,
               indexnode.Location,
               indexnode.resultdef,
               resultdef,
               false
             );

             set_result_location_reg;
             if use_tmpreg then
               emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[opsize], indexnode.Location.Register, tmpreg, location.Register)
             else
               case left.Location.Loc of
                 LOC_REFERENCE,
                 LOC_CREFERENCE:
                   emit_reg_ref_reg(A_BZHI, TCGSize2OpSize[opsize], indexnode.Location.Register, left.Location.Reference, location.Register);
                 LOC_REGISTER,
                 LOC_CREGISTER:
                   emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[opsize], indexnode.Location.Register, left.Location.Register, location.Register);
                 else
                   InternalError(2022102111);
               end;
           end;

      begin
        indexnode := nil; { Needed to prevent a compiler warning }

        { determine if the comparison will be unsigned }
        unsigned:=not(Is_Signed(left.resultdef)) or
                    not(Is_Signed(right.resultdef));

        { assume no overflow checking is require }
        checkoverflow := false;

        ovloc.Loc:=LOC_VOID;

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
            InternalError(2015022501);
        end;

       checkoverflow:=
         checkoverflow and
         needoverflowcheck;

       opsize:=Def_CGSize(left.resultdef);


       if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
         begin
           { BMI1 optimisations }
           if (CPUX86_HAS_BMI1 in cpu_capabilities[CurrentSettings.CPUType]) then
             begin
               { Can we turn "x and (not y)" into an ANDN instruction instead? }
               if (nodetype = andn) and
                 (opsize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) and
                 ((left.nodetype = notn) or (right.nodetype = notn)) and
                 (
                   { With "const and (not variable)", ANDN will produce larger
                     code once everything is moved into registers (as a side-note,
                     "const and (not const)" and "variable and (not const)" will
                     have been simplified earlier to remove the NOT operation). }
                   not (cs_opt_size in CurrentSettings.OptimizerSwitches) or
                   (
                     (left.Location.Loc <> LOC_CONSTANT) and
                     (right.Location.Loc <> LOC_CONSTANT)
                   )
                 ) then
                 begin
                   { ANDN only supports the second operand being inverted; however,
                     since we're dealing with ordinals, there won't be any Boolean
                     shortcutting, so we can safely swap the parameters }

                   if (right.nodetype <> notn) then
                     swapleftright;

                   SecondPass(left);

                   { Skip the not node completely }
                   Include(right.transientflags, tnf_do_not_execute);
                   SecondPass(TNotNode(right).left);

                   { allocate registers }
                   hlcg.Location_Force_Reg(
                     CurrentAsmData.CurrAsmList,
                     TNotNode(right).left.Location,
                     TNotNode(right).left.resultdef,
                     TNotNode(right).left.resultdef,
                     false
                   );

                   if left.Location.Loc = LOC_CONSTANT then
                     { With "const and (not variable)", we can probably still make a
                       saving when it comes to pipeline stalls (left.location.loc
                       will become LOC_CREGISTER). }
                     hlcg.Location_Force_Reg(
                       CurrentAsmData.CurrAsmList,
                       left.Location,
                       left.resultdef,
                       left.resultdef,
                       true
                     );

                   set_result_location_reg;

                   case left.Location.Loc of
                     LOC_REFERENCE,
                     LOC_CREFERENCE:
                       emit_ref_reg_reg(A_ANDN, TCGSize2OpSize[opsize], left.Location.Reference, TNotNode(right).left.Location.Register, location.Register);
                     LOC_REGISTER,
                     LOC_CREGISTER:
                       emit_reg_reg_reg(A_ANDN, TCGSize2OpSize[opsize], left.Location.Register, TNotNode(right).left.Location.Register, location.Register);
                     else
                       InternalError(2022102110);
                   end;

                   { Overflow can't happen with and/andn }
                   Exit;
                 end;
             end;

           { BMI2 optimisations }
           if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
             (opsize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) then
             begin
               case nodetype of
                 andn:
                   { Can we turn "x and ((1 shl y) - 1)" into a BZHI instruction instead? }
                   if (
                     (
                       (right.nodetype = subn) and
                       (TAddNode(right).right.nodetype = ordconstn) and
                       (TOrdConstNode(TAddNode(right).right).Value = 1) and
                       (TAddNode(right).left.nodetype = shln) and
                       (TShlShrNode(TAddNode(right).left).left.nodetype = ordconstn) and
                       (TOrdConstNode(TShlShrNode(TAddNode(right).left).left).Value = 1)
                     ) or
                     (
                       (left.nodetype = subn) and
                       (TAddNode(left).right.nodetype = ordconstn) and
                       (TOrdConstNode(TAddNode(left).right).Value = 1) and
                       (TAddNode(left).left.nodetype = shln) and
                       (TShlShrNode(TAddNode(left).left).left.nodetype = ordconstn) and
                       (TOrdConstNode(TShlShrNode(TAddNode(left).left).left).Value = 1)
                     )
                   ) then
                     begin

                       { Put the subtract node on the right }
                       if (right.nodetype <> subn) then
                         swapleftright;

                       SecondPass(left);

                       { Skip the subtract and shift nodes completely }
                       Include(right.transientflags, tnf_do_not_execute);
                       Include(TAddNode(right).left.transientflags, tnf_do_not_execute);

                       { Helps avoid all the awkward typecasts }
                       indexnode := TShlShrNode(TAddNode(right).left).right;
{$ifdef x86_64}
                       { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                       if (indexnode.nodetype = typeconvn) and (opsize in [OS_32, OS_S32]) and
                         (Def_CGSize(TTypeConvNode(indexnode).resultdef) in [OS_64, OS_S64]) then
                         begin
                           { Convert to the 32-bit type }
                           indexnode.resultdef := resultdef;
                           node_reset_flags(indexnode,[],[tnf_pass1_done]);

                           { We should't be getting any new errors }
                           if DoFirstPass(indexnode) then
                             InternalError(2022110201);

                           { Keep things internally consistent in case indexnode changed }
                           TShlShrNode(TAddNode(right).left).right := indexnode;
                         end;
{$endif x86_64}
                       SecondPass(indexnode);

                       MakeBZHI(False);
                       Exit;
                     end;

                 subn:
                   { Turns an isolated "(1 shl y) - 1" into "mov $-1,%reg1; bzhi %idxreg,%reg1,%reg2" pair}
                   if (right.nodetype = ordconstn) and
                     (TOrdConstNode(right).Value = 1) and
                     (left.nodetype = shln) and
                     (TShlShrNode(left).left.nodetype = ordconstn) and
                     (TOrdConstNode(TShlShrNode(left).left).Value = 1) then
                     begin
                       { Skip the shift node completely }
                       Include(left.transientflags, tnf_do_not_execute);

                       { Helps avoid all the awkward typecasts }
                       indexnode := TShlShrNode(left).right;

{$ifdef x86_64}
                       { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                       if (indexnode.nodetype = typeconvn) and (opsize in [OS_32, OS_S32]) and
                         (Def_CGSize(TTypeConvNode(indexnode).resultdef) in [OS_64, OS_S64]) then
                         begin
                           { Convert to the 32-bit type }
                           indexnode.resultdef := resultdef;
                           node_reset_flags(indexnode,[],[tnf_pass1_done]);

                           { We should't be getting any new errors }
                           if DoFirstPass(indexnode) then
                             InternalError(2022110202);

                           { Keep things internally consistent in case indexnode changed }
                           TShlShrNode(left).right := indexnode;
                         end;
{$endif x86_64}
                       SecondPass(indexnode);

                       tmpreg := cg.GetIntRegister(CurrentAsmData.CurrAsmList, opsize);
                       cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, opsize, -1, tmpreg);

                       MakeBZHI(True);
                       Exit;
                     end;
                 else
                   ;
               end;
             end;
         end;


       pass_left_right;

       { do we have to allocate a register? If yes, then three opcode instructions are better, however for sub three op code instructions
         make no sense if right is a reference }
       if ((left.Location.Loc<>LOC_REGISTER) and (right.Location.Loc<>LOC_REGISTER) and
           ((nodetype<>subn) or not(right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE])) and
           { 3 op mul makes only sense if a constant is involved }
           ((nodetype<>muln) or (left.Location.Loc=LOC_CONSTANT) or (right.Location.Loc=LOC_CONSTANT)

            or ((CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and (not(needoverflowcheck))
               )

           ) and
           (not(nodetype in [orn,andn,xorn]))) or
         ((nodetype=addn) and (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_CONSTANT]) and (right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_CONSTANT])) then
         begin
           { allocate registers }
           force_reg_left_right(nodetype<>subn,true);
           set_result_location_reg;
           if nodetype<>subn then
            begin
              if checkoverflow then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

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
                  if checkoverflow then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

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

                  if checkoverflow then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                  hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,
                    right.Location.Register,tmpreg,location.Register,checkoverflow,ovloc);
                end;
            end
         end
       else
         begin
           { at least one location should be a register, if yes, try to re-use it, so we can try two operand opcodes }
           if left.Location.Loc<>LOC_REGISTER then
              begin
                if right.Location.Loc<>LOC_REGISTER then
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false)
                else
                  begin
                    Location_Swap(left.Location,right.Location);
                    toggleflag(nf_swapped);
                  end;
              end;

           { at this point, left.location.loc should be LOC_REGISTER }
           if right.Location.Loc=LOC_REGISTER then
             begin
               if checkoverflow then
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

               { when swapped another result register }
               if (nodetype=subn) and (nf_swapped in flags) then
                 begin
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,opsize,
                     left.Location.Register,right.Location.Register);
                   Location_Swap(left.Location,right.Location);
                   toggleflag(nf_swapped);
                 end
               else
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,opsize,
                    right.Location.Register,left.Location.Register);
             end
           else
             begin
               { right.location<>LOC_REGISTER }
               if right.Location.Loc in [LOC_CSUBSETREF,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_SUBSETREG] then
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,left.resultdef,true);

               if (nodetype=subn) and (nf_swapped in flags) then
                 begin
                   tmpreg:=left.Location.Register;
                   left.Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                   cg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,opsize,right.Location,left.Location.Register);

                   if checkoverflow then
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,opsize,tmpreg,left.Location.Register);
                 end
               else
                 begin
                   if checkoverflow then
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                   cg.A_Op_Loc_Reg(CurrentAsmData.CurrAsmList,cgop,opsize,right.Location,left.Location.Register);
                 end;
               location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
             end;

           Location_Copy(location,left.Location);
         end;

       { emit overflow check if required }
       if checkoverflow then
         cg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,resultdef,ovloc);
     end;


    procedure TX86AddNode.second_addboolean;
      begin
        if (nodetype in [orn,andn]) and
           (not(cs_full_boolean_eval in CurrentSettings.LocalSwitches) or
          (anf_short_bool in addnodeflags)) then
          inherited second_addboolean
        else if Is_64Bit(left.resultdef) then
          inherited
        else
          second_addordinal;
      end;


    procedure TX86AddNode.second_cmpordinal;
      var
         opdef  : TDef;
         opsize : TCgSize;
         unsigned : boolean;
      begin
         unsigned:=not(Is_Signed(left.resultdef)) or
                   not(Is_Signed(right.resultdef));
         opdef:=left.resultdef;
         opsize:=Def_CGSize(opdef);

         pass_left_right;

         if (right.Location.Loc=LOC_CONSTANT) and
            (left.Location.Loc in [LOC_REFERENCE, LOC_CREFERENCE])
{$ifdef x86_64}
              and ((not (opsize in [OS_64,OS_S64])) or (
              (right.Location.Value>=low(LongInt)) and (right.Location.Value<=high(LongInt))
            ))
{$endif x86_64}
         then
           begin
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
             emit_const_ref(A_CMP, TCGSize2Opsize[opsize], right.Location.Value, left.Location.Reference);
             location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
           end
         else
           begin
             left_must_be_reg(opdef,opsize,false);
             emit_generic_code(A_CMP,opsize,unsigned,false,false);
             location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
             location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
           end;
         Location_Reset(location,LOC_FLAGS,OS_NO);
         location.ResFlags:=getresflags(unsigned);
      end;

begin
   CAddNode:=TX86AddNode;
end.
