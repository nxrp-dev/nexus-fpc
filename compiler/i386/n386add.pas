{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Code generation for add nodes on the i386

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
unit n386add;

{$i fpcdefs.inc}

interface

    uses
       node,nadd,cpubase,nx86add;

    type
       TI386AddNode = class(TX86AddNode)
         function use_generic_mul32to64: boolean; override;
         function use_generic_mul64bit: boolean; override;
         procedure second_addordinal; override;
         procedure second_add64bit;override;
         procedure second_cmp64bit;override;
         procedure second_mul(unsigned: boolean);
         procedure second_mul64bit;
       protected
         procedure set_mul_result_location;
       end;

  implementation

    uses
      GlobType,Systems,
      CUtils,Verbose,Globals,
      symconst,symdef,paramgr,defutil,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgbase,ProcInfo,
      ncon,nset,cgutils,tgobj,
      CPUInfo,
      cga,ncgutil,cgobj,cg64f32,cgx86,
      hlcgobj;

{*****************************************************************************
                                use_generic_mul32to64
*****************************************************************************}

    function TI386AddNode.use_generic_mul32to64: boolean;
    begin
      result := False;
    end;

    function TI386AddNode.use_generic_mul64bit: boolean;
    begin
      result:=needoverflowcheck or
        (cs_opt_size in CurrentSettings.OptimizerSwitches);
    end;

    { handles all unsigned multiplications, and 32->64 bit signed ones.
      32bit-only signed mul is handled by generic codegen }
    procedure TI386AddNode.second_addordinal;
    var
      unsigned: boolean;
    begin
      unsigned:=not(Is_Signed(left.resultdef)) or
                not(Is_Signed(right.resultdef));
      { use IMUL instead of MUL in case overflow checking is off and we're
        doing a 32->32-bit multiplication }
      if not needoverflowcheck and
         not Is_64Bit(resultdef) then
        unsigned:=false;
      if (nodetype=muln) and (unsigned or Is_64Bit(resultdef)) then
        second_mul(unsigned)
      else
        inherited second_addordinal;
    end;

{*****************************************************************************
                                Add64bit
*****************************************************************************}

    procedure TI386AddNode.second_add64bit;
      var
        op         : TOpCG;
        op1,op2    : TAsmOp;
        opsize     : TOpSize;
        hregister,
        hregister2 : TRegister;
        hl4        : TAsmLabel;
        mboverflow,
        unsigned:boolean;
        r:TRegister;
      begin
        pass_left_right;

        op1:=A_NONE;
        op2:=A_NONE;
        mboverflow:=false;
        opsize:=S_L;
        unsigned:=((left.resultdef.typ=orddef) and
                   (TOrdDef(left.resultdef).OrdType=u64bit)) or
                  ((right.resultdef.typ=orddef) and
                   (TOrdDef(right.resultdef).OrdType=u64bit));
        case nodetype of
          addn :
            begin
              op:=OP_ADD;
              mboverflow:=true;
            end;
          subn :
            begin
              op:=OP_SUB;
              op1:=A_SUB;
              op2:=A_SBB;
              mboverflow:=true;
            end;
          xorn:
            op:=OP_XOR;
          orn:
            op:=OP_OR;
          andn:
            op:=OP_AND;
          muln:
            begin
              second_mul64bit;
              exit;
            end
          else
            begin
              { everything should be handled in pass_1 (JM) }
              InternalError(2001090505);
            end;
        end;

        { left and right no register?  }
        { then one must be demanded    }
        if (left.Location.Loc<>LOC_REGISTER) then
         begin
           if (right.Location.Loc<>LOC_REGISTER) then
            begin
              hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              hregister2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              cg64.A_Load64_Loc_Reg(CurrentAsmData.CurrAsmList,left.Location,JoinReg64(hregister,hregister2));
              Location_Reset(left.Location,LOC_REGISTER,left.Location.Size);
              left.Location.Register64.RegLo:=hregister;
              left.Location.Register64.RegHi:=hregister2;
            end
           else
            begin
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end;
         end;

        { at this point, left.location.loc should be LOC_REGISTER }
        if right.Location.Loc=LOC_REGISTER then
         begin
           if mboverflow and needoverflowcheck then
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

           { when swapped another result register }
           if (nodetype=subn) and (nf_swapped in flags) then
            begin
              cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,op,location.Size,
                left.Location.Register64,
                right.Location.Register64);
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end
           else
            begin
              cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,op,location.Size,
                right.Location.Register64,
                left.Location.Register64);
            end;
         end
        else
         begin
           { right.location<>LOC_REGISTER }
           if (nodetype=subn) and (nf_swapped in flags) then
            begin
              r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              cg64.A_Load64Low_Loc_Reg(CurrentAsmData.CurrAsmList,right.Location,r);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_reg_reg(op1,opsize,left.Location.Register64.RegLo,r);
              emit_reg_reg(A_MOV,opsize,r,left.Location.Register64.RegLo);
              cg64.A_Load64High_Loc_Reg(CurrentAsmData.CurrAsmList,right.Location,r);
              { the carry flag is still ok }
              emit_reg_reg(op2,opsize,left.Location.Register64.RegHi,r);

              { We need to keep the FLAGS register allocated for overflow checks }
              if not mboverflow or not needoverflowcheck then
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

              emit_reg_reg(A_MOV,opsize,r,left.Location.Register64.RegHi);
            end
           else
            begin
              if mboverflow and needoverflowcheck then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

              cg64.A_Op64_Loc_Reg(CurrentAsmData.CurrAsmList,op,location.Size,right.Location,
                left.Location.Register64);
            end;
          location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
         end;

        { only in case of overflow operations }
        { produce overflow code }
        { we must put it here directly, because sign of operation }
        { is in unsigned VAR!!                              }
        if mboverflow then
         begin
           if needoverflowcheck then
            begin
              CurrentAsmData.getjumplabel(hl4);
              if unsigned then
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,hl4)
              else
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,hl4);

              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,hl4);
            end;
         end;

        Location_Copy(location,left.Location);
      end;


    procedure TI386AddNode.second_cmp64bit;
      var
        TrueLabel,
        FalseLabel,
        hlab       : TAsmLabel;
        href       : TReference;
        unsigned   : boolean;

      procedure firstjmp64bitcmp;

        var
           oldnodetype : TNodeType;

        begin
           { the jump the sequence is a little bit hairy }
           case nodetype of
              ltn,gtn:
                begin
                   if (hlab<>location.TrueLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,getresflags(unsigned),location.TrueLabel);
                   { cheat a little bit for the negative test }
                   toggleflag(nf_swapped);
                   if (hlab<>location.FalseLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,getresflags(unsigned),location.FalseLabel);
                   toggleflag(nf_swapped);
                end;
              lten,gten:
                begin
                   oldnodetype:=nodetype;
                   if nodetype=lten then
                     nodetype:=ltn
                   else
                     nodetype:=gtn;
                   if (hlab<>location.TrueLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,getresflags(unsigned),location.TrueLabel);
                   { cheat for the negative test }
                   if nodetype=ltn then
                     nodetype:=gtn
                   else
                     nodetype:=ltn;
                   if (hlab<>location.FalseLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,getresflags(unsigned),location.FalseLabel);
                   nodetype:=oldnodetype;
                end;
              EqualN:
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,location.FalseLabel);
              unequaln:
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,location.TrueLabel);
              else
                InternalError(2019050905);
           end;
        end;

      procedure secondjmp64bitcmp;

        begin
           { the jump the sequence is a little bit hairy }
           case nodetype of
              ltn,gtn,lten,gten:
                begin
                   { the comparison of the low dword have to be   }
                   {  always unsigned!                            }
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,getresflags(true),location.TrueLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,location.FalseLabel);
                end;
              EqualN:
                begin
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,location.FalseLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,location.TrueLabel);
                end;
              unequaln:
                begin
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,location.TrueLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,location.FalseLabel);
                end;
              else
                InternalError(2019050904);
           end;
        end;

      begin
        TrueLabel:=nil;
        FalseLabel:=nil;
        pass_left_right;

        unsigned:=((left.resultdef.typ=orddef) and
                   (TOrdDef(left.resultdef).OrdType=u64bit)) or
                  ((right.resultdef.typ=orddef) and
                   (TOrdDef(right.resultdef).OrdType=u64bit));

        { we have LOC_JUMP as result }
        CurrentAsmData.getjumplabel(TrueLabel);
        CurrentAsmData.getjumplabel(FalseLabel);
        Location_Reset_Jump(location,TrueLabel,FalseLabel);

        { Relational compares against constants having low dword=0 can omit the
          second compare based on the fact that any unsigned value is >=0 }
        hlab:=nil;
        if (right.Location.Loc=LOC_CONSTANT) and
           (lo(right.Location.Value64)=0) then
          begin
            case getresflags(true) of
              F_AE: hlab:=location.TrueLabel ;
              F_B:  hlab:=location.FalseLabel;
              else
                ;
            end;
          end;

        if (right.Location.Loc=LOC_CONSTANT) and
           (left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
          begin
            TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,left.Location.Reference);
            href:=left.Location.Reference;
            inc(href.Offset,4);
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_const_ref(A_CMP,S_L,aint(hi(right.Location.Value64)),href);
            firstjmp64bitcmp;
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if Assigned(hlab) then
              cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,hlab)
            else
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                emit_const_ref(A_CMP,S_L,aint(lo(right.Location.Value64)),left.Location.Reference);
                secondjmp64bitcmp;
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              end;
            location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
            exit;
          end;

        { left and right no register?  }
        { then one must be demanded    }
        if not (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
         begin
           if not (right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true)
           else
            begin
              Location_Swap(left.Location,right.Location);
              toggleflag(nf_swapped);
            end;
         end;

        { at this point, left.location.loc should be LOC_[C]REGISTER }
        case right.Location.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_reg_reg(A_CMP,S_L,right.Location.Register64.RegHi,left.Location.Register64.RegHi);
              firstjmp64bitcmp;
              emit_reg_reg(A_CMP,S_L,right.Location.Register64.RegLo,left.Location.Register64.RegLo);
              secondjmp64bitcmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            end;
          LOC_CREFERENCE,
          LOC_REFERENCE :
            begin
              TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,right.Location.Reference);
              href:=right.Location.Reference;
              inc(href.Offset,4);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_ref_reg(A_CMP,S_L,href,left.Location.Register64.RegHi);
              firstjmp64bitcmp;
              emit_ref_reg(A_CMP,S_L,right.Location.Reference,left.Location.Register64.RegLo);
              secondjmp64bitcmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
            end;
          LOC_CONSTANT :
            begin
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,S_L,aint(hi(right.Location.Value64)),left.Location.Register64.RegHi));
              firstjmp64bitcmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              if Assigned(hlab) then
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,hlab)
              else
                begin
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,S_L,aint(lo(right.Location.Value64)),left.Location.Register64.RegLo));
                  secondjmp64bitcmp;
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                end;
            end;
        else
          InternalError(2002032803);
        end;

      end;


{*****************************************************************************
                                x86 MUL
*****************************************************************************}

    procedure TI386AddNode.set_mul_result_location;
    begin
      Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
      {Free EAX,EDX}
      cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);
      if Is_64Bit(resultdef) then
      begin
        {Allocate a couple of registers and store EDX:EAX into it}
        location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, OS_INT, OS_INT, NR_EDX, location.Register64.RegHi);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
        location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, OS_INT, OS_INT, NR_EAX, location.Register64.RegLo);
      end
      else
      begin
        {Allocate a new register and store the result in EAX in it.}
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_INT,OS_INT,NR_EAX,location.Register);
      end;
      location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
      location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
    end;


    procedure TI386AddNode.second_mul(unsigned: boolean);

    var reg,RegHi,RegLo:TRegister;
        ref:TReference;
        use_ref:boolean;
        hl4 : TAsmLabel;

    const
      asmops: array[boolean] of TAsmOp = (A_IMUL, A_MUL);

    begin
      pass_left_right;
      reg:=NR_NO;
      Reference_Reset(ref,sizeof(PInt),[]);

      { Mul supports registers and references, so if not register/reference,
        load the location into a register.
        The variant of IMUL which is capable of doing 32->64 bits has the same restrictions. }
      use_ref:=false;
      if left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
        reg:=left.Location.Register
      else if left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        begin
          TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,left.Location.Reference);
          ref:=left.Location.Reference;
          use_ref:=true;
        end
      else
        begin
          { LOC_CONSTANT for example.}
          reg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,OSUIntType,left.Location,reg);
        end;

      if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
        (not(needoverflowcheck) or
        { 32->64 bit cannot overflow }
        Is_64Bit(resultdef)) then
        begin
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,OSUIntType,right.Location,NR_EDX);
          RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          if use_ref then
            CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref_reg_reg(A_MULX,S_L,ref,RegLo,RegHi))
          else
            emit_reg_reg_reg(A_MULX,S_L,reg,RegLo,RegHi);
          cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);

          Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
          location.Register64.RegLo:=RegLo;

          if Is_64Bit(resultdef) then
            location.Register64.RegHi:=RegHi;

          location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
          location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
        end
      else
        begin
          { Allocate EAX. }
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
          { Load the right value. }
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,OSUIntType,right.Location,NR_EAX);
          { Also allocate EDX, since it is also modified by a mul (JM). }
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);

          if needoverflowcheck then
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

          if use_ref then
            emit_ref(asmops[unsigned],S_L,ref)
          else
            emit_reg(asmops[unsigned],S_L,reg);
          if needoverflowcheck and
            { 32->64 bit cannot overflow }
            (not Is_64Bit(resultdef)) then
            begin
              CurrentAsmData.getjumplabel(hl4);
              cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,hl4);
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,hl4);
            end;
          set_mul_result_location;
        end;
    end;


    procedure TI386AddNode.second_mul64bit;
    var
      list: TAsmList;
      hreg1,hreg2: TRegister;
    begin
      { 64x64 multiplication yields 128-bit result, but we're only
        interested in its lower 64 bits. This lower part is independent
        of operand signs, and so is the generated code. }
      { pass_left_right already called from second_add64bit }
      list:=CurrentAsmData.CurrAsmList;
      if left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        TCGX86(cg).make_simple_ref(list,left.Location.Reference);
      if right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        TCGX86(cg).make_simple_ref(list,right.Location.Reference);

      { calculate 32-bit terms lo(right)*hi(left) and hi(left)*lo(right) }
      if (right.Location.Loc=LOC_CONSTANT) then
        begin
          { if left has side effects, it could be that this code is called with right.location.value64=0,
            see also #40182 }
          if right.Location.Value64=0 then
            begin
              Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
              location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              emit_const_reg(A_MOV,S_L,0,location.Register64.RegLo);
              location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              emit_const_reg(A_MOV,S_L,0,location.Register64.RegHi);
              exit;
            end;

          { Omit zero terms, if any }
          hreg1:=NR_NO;
          hreg2:=NR_NO;
          if lo(right.Location.Value64)<>0 then
            hreg1:=cg.GetIntRegister(list,OS_INT);
          if hi(right.Location.Value64)<>0 then
            hreg2:=cg.GetIntRegister(list,OS_INT);

          { Take advantage of 3-operand form of IMUL }
          case left.Location.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              begin
                if hreg1<>NR_NO then
                  emit_const_reg_reg(A_IMUL,S_L,LongInt(lo(right.Location.Value64)),left.Location.Register64.RegHi,hreg1);
                if hreg2<>NR_NO then
                  emit_const_reg_reg(A_IMUL,S_L,LongInt(hi(right.Location.Value64)),left.Location.Register64.RegLo,hreg2);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                if hreg2<>NR_NO then
                  list.concat(TAICPU.op_const_ref_reg(A_IMUL,S_L,LongInt(hi(right.Location.Value64)),left.Location.Reference,hreg2));
                inc(left.Location.Reference.Offset,4);
                if hreg1<>NR_NO then
                  list.concat(TAICPU.op_const_ref_reg(A_IMUL,S_L,LongInt(lo(right.Location.Value64)),left.Location.Reference,hreg1));
                dec(left.Location.Reference.Offset,4);
              end;
          else
            InternalError(2014011602);
          end;
        end
      else
        begin
          hreg1:=cg.GetIntRegister(list,OS_INT);
          hreg2:=cg.GetIntRegister(list,OS_INT);
          cg64.A_Load64Low_Loc_Reg(list,left.Location,hreg1);
          cg64.A_Load64High_Loc_Reg(list,left.Location,hreg2);
          case right.Location.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              begin
                emit_reg_reg(A_IMUL,S_L,right.Location.Register64.RegHi,hreg1);
                emit_reg_reg(A_IMUL,S_L,right.Location.Register64.RegLo,hreg2);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                emit_ref_reg(A_IMUL,S_L,right.Location.Reference,hreg2);
                inc(right.Location.Reference.Offset,4);
                emit_ref_reg(A_IMUL,S_L,right.Location.Reference,hreg1);
                dec(right.Location.Reference.Offset,4);
              end;
          else
            InternalError(2014011603);
          end;
        end;
      { add hi*lo and lo*hi terms together }
      if (hreg1<>NR_NO) and (hreg2<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,hreg2,hreg1);

      { load lo(right) into EAX }
      cg.GetCPURegister(list,NR_EAX);
      cg64.A_Load64Low_Loc_Reg(list,right.Location,NR_EAX);

      { multiply EAX by lo(left), producing 64-bit value in EDX:EAX }
      cg.GetCPURegister(list,NR_EDX);
      if (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        emit_reg(A_MUL,S_L,left.Location.Register64.RegLo)
      else if (left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
        emit_ref(A_MUL,S_L,left.Location.Reference)
      else
        InternalError(2014011604);
      { add previously calculated terms to the high half }
      if (hreg1<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,hreg1,NR_EDX)
      else if (hreg2<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,hreg2,NR_EDX)
      else
        InternalError(2014011601);

      { Result is now in EDX:EAX. Copy it to virtual registers. }
      set_mul_result_location;
    end;


begin
   CAddNode:=TI386AddNode;
end.
