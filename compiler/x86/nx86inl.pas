{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86 inline nodes

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
unit nx86inl;

{$i fpcdefs.inc}

interface

    uses
       node,ninl,ncginl;

    type
       TX86InlineNode = class(TCGInlineNode)
         protected
          procedure maybe_remove_round_trunc_typeconv; virtual;
         public
          function pass_typecheck_cpu:TNode;override;

          { first pass override
            so that the code generator will actually generate
            these nodes.
          }
          function first_cpu: TNode;override;
          function first_pi: TNode ; override;
          function first_arctan_real: TNode; override;
          function first_abs_real: TNode; override;
          function first_sqr_real: TNode; override;
          function first_sqrt_real: TNode; override;
          function first_ln_real: TNode; override;
          function first_cos_real: TNode; override;
          function first_sin_real: TNode; override;
          function first_round_real: TNode; override;
          function first_trunc_real: TNode; override;
          function first_popcnt: TNode; override;
          function first_fma: TNode; override;
          function first_frac_real : TNode; override;
          function first_int_real : TNode; override;
          function first_minmax: TNode; override;

          function simplify(forinline : boolean) : TNode; override;

          { second pass override to generate these nodes }
          procedure pass_generate_code_cpu;override;
          procedure second_IncludeExclude;override;
          procedure second_AndOrXorShiftRot_assign;override;
          procedure second_pi; override;
          procedure second_arctan_real; override;
          procedure second_abs_real; override;
          procedure second_round_real; override;
          procedure second_sqr_real; override;
          procedure second_sqrt_real; override;
          procedure second_ln_real; override;
          procedure second_cos_real; override;
          procedure second_sin_real; override;
          procedure second_trunc_real; override;

          procedure second_prefetch;override;

          procedure second_abs_long;override;
          procedure second_popcnt;override;
          procedure second_fma;override;
          procedure second_frac_real;override;
          procedure second_int_real;override;
          procedure second_high;override;
          procedure second_minmax;override;
       private
          procedure load_fpu_location(lnode: TNode);
       end;

implementation

    uses
      Systems,
      GlobType,Globals,
      Verbose,compinnr,FModule,
      defutil,
      aasmbase,AAsmData,aasmcpu,
      symconst,symtype,symdef,symcpu,
      ncnv,
      htypechk,
      cgbase,pass_1,pass_2,
      CPUInfo,cpubase,nutils,
      ncal,ncgutil,nld,ncon,nadd,nmat,ConstExp,
      tgobj,
      cga,cgutils,cgx86,cgobj,hlcgobj,CUtils;


{*****************************************************************************
                              TX86INLINENODE
*****************************************************************************}

     procedure TX86InlineNode.maybe_remove_round_trunc_typeconv;
       begin
         { only makes a difference for x86_64 }
       end;


     function TX86InlineNode.pass_typecheck_cpu: TNode;
       begin
         Result:=nil;
         case inlinenumber of
           in_x86_inportb:
             begin
               CheckParameters(1);
               resultdef:=U8IntType;
             end;
           in_x86_inportw:
             begin
               CheckParameters(1);
               resultdef:=U16IntType;
             end;
           in_x86_inportl:
             begin
               CheckParameters(1);
               resultdef:=S32IntType;
             end;
           in_x86_outportb,
           in_x86_outportw,
           in_x86_outportl:
             begin
               CheckParameters(2);
               resultdef:=VoidType;
             end;
           in_x86_pause,
           in_x86_cli,
           in_x86_sti:
             resultdef:=VoidType;
           in_x86_get_cs,
           in_x86_get_ss,
           in_x86_get_ds,
           in_x86_get_es,
           in_x86_get_fs,
           in_x86_get_gs:

             resultdef:=S32IntType;

           { include automatically generated code }
           {$i x86mmtype.inc}
           else
             Result:=inherited pass_typecheck_cpu;
         end;
       end;


     function TX86InlineNode.first_cpu: TNode;
       begin
         Result:=nil;
         case inlinenumber of
           in_x86_inportb,
           in_x86_inportw,
           in_x86_inportl,
           in_x86_get_cs,
           in_x86_get_ss,
           in_x86_get_ds,
           in_x86_get_es,
           in_x86_get_fs,
           in_x86_get_gs:
             expectloc:=LOC_REGISTER;
           in_x86_outportb,
           in_x86_outportw,
           in_x86_outportl,
           in_x86_pause,
           in_x86_cli,
           in_x86_sti:
             expectloc:=LOC_VOID;
           { include automatically generated code }
           {$i x86mmfirst.inc}
           else
             Result:=inherited first_cpu;
         end;
       end;


     function TX86InlineNode.first_pi : TNode;
      begin
        expectloc:=LOC_FPUREGISTER;
        Result:=nil;
      end;


     function TX86InlineNode.first_arctan_real : TNode;
      begin
        expectloc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.first_abs_real : TNode;
       begin
         if Use_VectorFPU(resultdef) then
           expectloc:=LOC_MMREGISTER
         else
           expectloc:=LOC_FPUREGISTER;
        first_abs_real := nil;
      end;

     function TX86InlineNode.first_sqr_real : TNode;
      begin
        if Use_VectorFPU(resultdef) then
          expectloc:=LOC_MMREGISTER
        else
          expectloc:=LOC_FPUREGISTER;
        first_sqr_real := nil;
      end;

     function TX86InlineNode.first_sqrt_real : TNode;
      begin
        if Use_VectorFPU(resultdef) then
          expectloc:=LOC_MMREGISTER
        else
          expectloc:=LOC_FPUREGISTER;
        first_sqrt_real := nil;
      end;

     function TX86InlineNode.first_ln_real : TNode;
      begin
        expectloc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.first_cos_real : TNode;
      begin
        expectloc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.first_sin_real : TNode;
      begin
        expectloc:=LOC_FPUREGISTER;
        Result:=nil;
      end;


     function TX86InlineNode.first_round_real : TNode;
      begin
        maybe_remove_round_trunc_typeconv;
{$ifdef x86_64}
        if Use_VectorFPU(left.resultdef) then
          expectloc:=LOC_REGISTER
        else
{$endif x86_64}
          expectloc:=LOC_REFERENCE;
        result:=nil;
      end;


     function TX86InlineNode.first_trunc_real: TNode;
       begin
         maybe_remove_round_trunc_typeconv;
         if (cs_opt_size in CurrentSettings.OptimizerSwitches)
{$ifdef x86_64}
           and not(Use_VectorFPU(left.resultdef))
{$endif x86_64}
           then
           result:=inherited
         else
           begin
{$ifdef x86_64}
             if Use_VectorFPU(left.resultdef) then
               expectloc:=LOC_REGISTER
             else
{$endif x86_64}
               expectloc:=LOC_REFERENCE;
             result:=nil;
           end;
       end;


     function TX86InlineNode.first_popcnt: TNode;
       begin
         Result:=nil;

         if (CPUX86_HAS_POPCNT in cpu_capabilities[CurrentSettings.CPUType])
  {$ifdef i386}
            and not Is_64Bit(left.resultdef)
  {$endif i386}
           then
             expectloc:=LOC_REGISTER
         else

           Result:=inherited first_popcnt
       end;


     function TX86InlineNode.first_fma : TNode;
       begin

         if ((fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[]) and
           ((Is_Double(resultdef)) or (Is_Single(resultdef))) then
           begin
             expectloc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else

           Result:=inherited first_fma;
       end;


     function TX86InlineNode.first_frac_real : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           ((Is_Double(resultdef)) or (Is_Single(resultdef))) then
           begin
             maybe_remove_round_trunc_typeconv;
             expectloc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else
           Result:=inherited first_frac_real;
       end;


     function TX86InlineNode.first_int_real : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           ((Is_Double(resultdef)) or (Is_Single(resultdef))) then
           begin
             Result:=nil;
             expectloc:=LOC_MMREGISTER;
           end
         else
           Result:=inherited first_int_real;
       end;


     function TX86InlineNode.first_minmax: TNode;
       begin

         if
{$ifdef i386}
           ((CurrentSettings.FPUType>=fpu_sse) and Is_Single(resultdef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and Is_Double(resultdef))
{$else i386}
           ((Is_Double(resultdef)) or (Is_Single(resultdef)))
{$endif i386}
           then
           begin
             expectloc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else

         if
{$ifndef x86_64}
           (CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) and
{$endif x86_64}
           (
{$ifdef x86_64}
             Is_64BitInt(resultdef) or
{$endif x86_64}
             Is_32BitInt(resultdef)
           ) then
           begin
             expectloc:=LOC_REGISTER;
             Result:=nil;
           end
         else
           Result:=inherited first_minmax;
       end;


     function TX86InlineNode.simplify(forinline : boolean) : TNode;
       var
         temp : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           (inlinenumber=in_int_real) and (left.nodetype=typeconvn) and
           not(nf_explicit in left.flags) and
           (TTypeConvNode(left).left.resultdef.typ=floatdef) and
           ((Is_Double(TTypeConvNode(left).left.resultdef)) or (Is_Single(TTypeConvNode(left).left.resultdef))) then
           begin
             { get rid of the type conversion }
             temp:=TTypeConvNode(left).left;
             TTypeConvNode(left).left:=nil;
             left.free;
             left:=temp;
             result:=self.GetCopy;
             TInlineNode(result).resultdef:=temp.resultdef;
             TypeCheckPass(result);
           end
         else
           Result:=inherited simplify(forinline);
       end;


     procedure TX86InlineNode.pass_generate_code_cpu;

       var
         paraarray : array[1..4] of TNode;
         i : integer;
         op: TAsmOp;

       procedure inport(dreg:TRegister;dsize:TOpSize;dtype:TDef);
         var
           portnumber: TNode;
         begin
           portnumber:=left;
           SecondPass(portnumber);
           if (portnumber.Location.Loc=LOC_CONSTANT) and
              (portnumber.Location.Value>=0) and
              (portnumber.Location.Value<=255) then
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,dreg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_IN,dsize,portnumber.Location.Value,dreg));
               Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
               location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,dreg);
               hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,dtype,resultdef,dreg,location.Register);
             end
           else
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,portnumber.resultdef,U16IntType,portnumber.Location,NR_DX);
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,dreg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_IN,dsize,NR_DX,dreg));
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
               location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,dreg);
               hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,dtype,resultdef,dreg,location.Register);
             end;
         end;


       procedure outport(dreg:TRegister;dsize:TOpSize;dtype:TDef);
         var
           portnumber, portdata: TNode;
         begin
           portnumber:=TCallParaNode(TCallParaNode(left).right).left;
           portdata:=TCallParaNode(left).left;
           SecondPass(portdata);
           SecondPass(portnumber);
           hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,dreg);
           hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,portdata.resultdef,dtype,portdata.Location,dreg);
           if (portnumber.Location.Loc=LOC_CONSTANT) and
              (portnumber.Location.Value>=0) and
              (portnumber.Location.Value<=255) then
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_OUT,dsize,dreg,portnumber.Location.Value))
           else
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,portnumber.resultdef,U16IntType,portnumber.Location,NR_DX);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_OUT,dsize,dreg,NR_DX));
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
             end;
           hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,dreg);
         end;


       procedure get_segreg(segreg:TRegister);
         begin
           Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
           location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
           CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MOV,TCGSize2OpSize[Def_CGSize(resultdef)],segreg,location.Register));
         end;


      function GetConstInt(n: TNode): LongInt;
        begin
          Result:=0;
          if is_constintnode(n) then
            result:=TOrdConstNode(n).Value.svalue
          else
            Message(type_e_constant_expr_expected);
        end;


      procedure GetParameters(count: LongInt);
        var
          i: LongInt;
          p: TNode;
        begin
          if (count=1) and
             (not (left is TCallParaNode)) then
            paraarray[1]:=left
          else
            begin
              p:=left;
              for i := count downto 1 do
                begin
                  paraarray[i]:=TCallParaNode(p).paravalue;
                  p:=TCallParaNode(p).nextpara;
                end;
            end;
        end;

      procedure location_force_mmxreg(list:TAsmList;var l: TLocation;maybeconst:boolean);
        var
          reg : TRegister;
        begin
          if (l.Loc<>LOC_MMXREGISTER)  and
             ((l.Loc<>LOC_CMMXREGISTER) or (not maybeconst)) then
            begin
              reg:=TCGX86(cg).GetMMXRegister(list);
              cg.A_LoadMM_Loc_Reg(list,OS_M64,l,reg,nil);
              location_freetemp(list,l);
              Location_Reset(l,LOC_MMXREGISTER,OS_M64);
              l.Register:=reg;
            end;
        end;

      procedure location_make_ref(var loc: TLocation);
        var
          hloc: TLocation;
        begin
          case loc.Loc of
            LOC_CREGISTER,
            LOC_REGISTER:
              begin
                Location_Reset_Ref(hloc, LOC_REFERENCE, OS_32, 1, []);
                hloc.Reference.Base:=loc.Register;

                loc:=hloc;
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
              end;
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,loc,U32IntType,U32IntType,false);

              Location_Reset_Ref(hloc, LOC_REFERENCE, OS_32, 1, []);
              hloc.Reference.Base:=loc.Register;

              loc:=hloc;
            end;
          end;
        end;

       begin
         FillChar(paraarray,sizeof(paraarray),0);
         case inlinenumber of
           in_x86_inportb:
             inport(NR_AL,S_B,U8IntType);
           in_x86_inportw:
             inport(NR_AX,S_W,U16IntType);
           in_x86_inportl:
             inport(NR_EAX,S_L,S32IntType);
           in_x86_outportb:
             outport(NR_AL,S_B,U8IntType);
           in_x86_outportw:
             outport(NR_AX,S_W,U16IntType);
           in_x86_outportl:
             outport(NR_EAX,S_L,S32IntType);
           in_x86_cli:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLI));
           in_x86_sti:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STI));
           in_x86_pause:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_PAUSE));
           in_x86_get_cs:
             get_segreg(NR_CS);
           in_x86_get_ss:
             get_segreg(NR_SS);
           in_x86_get_ds:
             get_segreg(NR_DS);
           in_x86_get_es:
             get_segreg(NR_ES);
           in_x86_get_fs:
             get_segreg(NR_FS);
           in_x86_get_gs:
             get_segreg(NR_GS);
           {$i x86mmsecond.inc}
           else
             inherited pass_generate_code_cpu;
         end;
       end;


     procedure TX86InlineNode.second_AndOrXorShiftRot_assign;

       var
         opsize : TCgSize;
         valuenode, indexnode, loadnode: TNode;
         DestReg: TRegister;

       begin

         if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
           begin
             { Saves on a lot of typecasting and potential coding mistakes }
             valuenode := TCallParaNode(left).left;
             loadnode := TCallParaNode(TCallParaNode(left).right).left;

             opsize := Def_CGSize(loadnode.resultdef);

             { BMI2 optimisations }
             if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and (inlinenumber=in_and_assign_x_y) then
               begin
                 { If the second operand is "((1 shl y) - 1)", we can turn it
                   into a BZHI operator instead }
                 if (opsize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) and
                   (valuenode.nodetype = subn) and
                   (TAddNode(valuenode).right.nodetype = ordconstn) and
                   (TOrdConstNode(TAddNode(valuenode).right).Value = 1) and
                   (TAddNode(valuenode).left.nodetype = shln) and
                   (TShlShrNode(TAddNode(valuenode).left).left.nodetype = ordconstn) and
                   (TOrdConstNode(TShlShrNode(TAddNode(valuenode).left).left).Value = 1) then
                   begin
                     { Skip the subtract and shift nodes completely }

                     { Helps avoid all the awkward typecasts }
                     indexnode := TShlShrNode(TAddNode(valuenode).left).right;
{$ifdef x86_64}
                     { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                     if (indexnode.nodetype = typeconvn) and (opsize in [OS_32, OS_S32]) and
                       (Def_CGSize(TTypeConvNode(indexnode).resultdef) in [OS_64, OS_S64]) then
                       begin
                         { Convert to the 32-bit type }
                         indexnode.resultdef:=loadnode.resultdef;
                         node_reset_flags(indexnode,[],[tnf_pass1_done]);

                         { We should't be getting any new errors }
                         if DoFirstPass(indexnode) then
                           InternalError(2022110202);

                         { Keep things internally consistent in case indexnode changed }
                         TShlShrNode(TAddNode(valuenode).left).right:=indexnode;
                       end;
{$endif x86_64}
                     SecondPass(indexnode);
                     SecondPass(loadnode);

                     { allocate registers }
                     hlcg.Location_Force_Reg(
                       CurrentAsmData.CurrAsmList,
                       indexnode.Location,
                       indexnode.resultdef,
                       loadnode.resultdef,
                       false
                     );

                     case loadnode.Location.Loc of
                       LOC_REFERENCE,
                       LOC_CREFERENCE:
                         begin
                           { BZHI can only write to a register }
                           DestReg := cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                           emit_reg_ref_reg(A_BZHI, TCGSize2OpSize[opsize], indexnode.Location.Register, loadnode.Location.Reference, DestReg);
                           emit_reg_ref(A_MOV, TCGSize2OpSize[opsize], DestReg, loadnode.Location.Reference);
                         end;
                       LOC_REGISTER,
                       LOC_CREGISTER:
                         emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[opsize], indexnode.Location.Register, loadnode.Location.Register, loadnode.Location.Register);
                       else
                         InternalError(2022102120);
                     end;

                     Exit;
                   end;
               end;
           end;


         inherited second_AndOrXorShiftRot_assign;
       end;

     procedure TX86InlineNode.second_pi;
       begin
         Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
         emit_none(A_FLDPI,S_NO);
         TCGX86(cg).inc_fpu_stack;
         location.Register:=NR_FPU_RESULT_REG;
       end;


     { load the FPU into the an fpu register }
     procedure TX86InlineNode.load_fpu_location(lnode: TNode);
       begin
         Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
         location.Register:=NR_FPU_RESULT_REG;
         SecondPass(lnode);
         case lnode.Location.Loc of
           LOC_FPUREGISTER:
             ;
           LOC_CFPUREGISTER:
             begin
               cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,lnode.Location.Size,
                 lnode.Location.Size,lnode.Location.Register,location.Register);
             end;
           LOC_REFERENCE,LOC_CREFERENCE:
             begin
               cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                  lnode.Location.Size,lnode.Location.Size,
                  lnode.Location.Reference,location.Register);
             end;
           LOC_MMREGISTER,LOC_CMMREGISTER:
             begin
               location:=lnode.Location;
               hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,location,lnode.resultdef,false);
             end;
           else
             InternalError(309991);
         end;
       end;


     procedure TX86InlineNode.second_arctan_real;
       begin
         load_fpu_location(left);
         emit_none(A_FLD1,S_NO);
         emit_none(A_FPATAN,S_NO);
       end;


     procedure TX86InlineNode.second_abs_real;

       function needs_indirect:boolean; inline;
         begin
            { System owns these masks; its local indirect aliases are pointer
              cells, not mask data. Only consumers import them indirectly. }
           result:=(tf_supports_packages in TargetInfo.flags) and
                     not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
                     (TargetInfo.system in systems_indirect_var_imports);
         end;

       var
         href : TReference;
         sym : TAsmSymbol;
       begin
         if Use_VectorFPU(resultdef) then
           begin
             SecondPass(left);
             if left.Location.Loc<>LOC_MMREGISTER then
               hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,UseAVX);
             if UseAVX then
               begin
                 Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
                 location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(resultdef));
               end
             else
               location:=left.Location;
             case TFloatDef(resultdef).FloatType of
               S32Real:
                 begin
                   sym:=CurrentAsmData.RefAsmSymbol(TargetInfo.cprefix+'FPC_ABSMASK_SINGLE',AT_DATA,needs_indirect);
                   Reference_Reset_Symbol(href,sym,0,4,[]);
                   CurrentModule.Add_Extern_AsmSym(sym);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList, href);
                   if UseAVX then
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(
                       A_VANDPS,S_XMM,href,left.Location.Register,location.Register))
                   else
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ANDPS,S_XMM,href,location.Register));
                 end;
               S64Real:
                 begin
                   sym:=CurrentAsmData.RefAsmSymbol(TargetInfo.cprefix+'FPC_ABSMASK_DOUBLE',AT_DATA,needs_indirect);
                   Reference_Reset_Symbol(href,sym,0,4,[]);
                   CurrentModule.Add_Extern_AsmSym(sym);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList, href);
                   if UseAVX then
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(
                       A_VANDPD,S_XMM,href,left.Location.Register,location.Register))
                   else
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ANDPD,S_XMM,href,location.Register))
                 end;
               else
                 InternalError(200506081);
             end;
           end
         else
           begin
             load_fpu_location(left);
             emit_none(A_FABS,S_NO);
           end;
       end;


     procedure TX86InlineNode.second_round_real;
       begin
{$ifdef x86_64}
         if Use_VectorFPU(left.resultdef) then
           begin
             SecondPass(left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
             Location_Reset(location,LOC_REGISTER,OS_S64);
             location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_S64);
             if UseAVX then
               case left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTSS2SI,S_NO,left.Location.Register,location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTSD2SI,S_NO,left.Location.Register,location.Register));
                 else
                   InternalError(2007031402);
               end
             else
               case left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTSS2SI,S_NO,left.Location.Register,location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTSD2SI,S_NO,left.Location.Register,location.Register));
                 else
                   InternalError(2007031404);
               end;
           end
         else
{$endif x86_64}
          begin
            load_fpu_location(left);
            Location_Reset_Ref(location,LOC_REFERENCE,OS_S64,0,[]);
            tg.GetTemp(CurrentAsmData.CurrAsmList,resultdef.Size,resultdef.Alignment,tt_normal,location.Reference);
            emit_ref(A_FISTP,S_IQ,location.Reference);
            TCGX86(cg).dec_fpu_stack;
            emit_none(A_FWAIT,S_NO);
           end;
       end;


     procedure TX86InlineNode.second_trunc_real;
       var
         oldcw,newcw : TReference;
       begin
{$ifdef x86_64}
         if Use_VectorFPU(left.resultdef) and
           not((left.Location.Loc=LOC_FPUREGISTER) and (CurrentSettings.FPUType>=fpu_sse3)) then
           begin
             SecondPass(left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
             Location_Reset(location,LOC_REGISTER,OS_S64);
             location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_S64);
             if UseAVX then
               case left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTTSS2SI,S_NO,left.Location.Register,location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTTSD2SI,S_NO,left.Location.Register,location.Register));
                 else
                   InternalError(2007031401);
               end
             else
               case left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTTSS2SI,S_NO,left.Location.Register,location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTTSD2SI,S_NO,left.Location.Register,location.Register));
                 else
                   InternalError(2007031403);
               end;
           end
         else
{$endif x86_64}
          begin
            if (CurrentSettings.FPUType>=fpu_sse3) then
              begin
                load_fpu_location(left);
                Location_Reset_Ref(location,LOC_REFERENCE,OS_S64,0,[]);
                tg.GetTemp(CurrentAsmData.CurrAsmList,resultdef.Size,resultdef.Alignment,tt_normal,location.Reference);
                emit_ref(A_FISTTP,S_IQ,location.Reference);
                TCGX86(cg).dec_fpu_stack;
              end
            else
              begin
                tg.GetTemp(CurrentAsmData.CurrAsmList,2,2,tt_normal,oldcw);
                tg.GetTemp(CurrentAsmData.CurrAsmList,2,2,tt_normal,newcw);

                  begin
                    emit_ref(A_FNSTCW,S_NO,newcw);
                    emit_ref(A_FNSTCW,S_NO,oldcw);
                  end;
                emit_const_ref(A_OR,S_W,$0f00,newcw);
                load_fpu_location(left);
                emit_ref(A_FLDCW,S_NO,newcw);
                Location_Reset_Ref(location,LOC_REFERENCE,OS_S64,0,[]);
                tg.GetTemp(CurrentAsmData.CurrAsmList,resultdef.Size,resultdef.Alignment,tt_normal,location.Reference);
                emit_ref(A_FISTP,S_IQ,location.Reference);
                TCGX86(cg).dec_fpu_stack;
                emit_ref(A_FLDCW,S_NO,oldcw);
                emit_none(A_FWAIT,S_NO);
                tg.UnGetTemp(CurrentAsmData.CurrAsmList,oldcw);
                tg.UnGetTemp(CurrentAsmData.CurrAsmList,newcw);
              end;
           end;
       end;


     procedure TX86InlineNode.second_sqr_real;

       begin
         if Use_VectorFPU(resultdef) then
           begin
             SecondPass(left);
             Location_Reset(location,LOC_MMREGISTER,left.Location.Size);
             location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
             if UseAVX then
               begin
                 hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
                 cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_MUL,left.Location.Size,left.Location.Register,left.Location.Register,location.Register,MMS_MoveScalar);
               end
             else
               begin
                 if left.Location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER] then
                   hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
                 cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,location.Size,left.Location,location.Register,MMS_MoveScalar);
                 cg.A_OpMM_Reg_Reg(CurrentAsmData.CurrAsmList,OP_MUL,left.Location.Size,location.Register,location.Register,MMS_MoveScalar);
               end;
           end
         else
           begin
             load_fpu_location(left);
             emit_reg_reg(A_FMUL,S_NO,NR_ST0,NR_ST0);
           end;
       end;


     procedure TX86InlineNode.second_sqrt_real;
       begin
         if Use_VectorFPU(resultdef) then
           begin
             SecondPass(left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
             Location_Reset(location,LOC_MMREGISTER,left.Location.Size);
             location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
             if UseAVX then
               case TFloatDef(resultdef).FloatType of
                 S32Real:
                   { we use S_NO instead of S_XMM here, regardless of the register size, as the size of the memory location is 32/64 bit }
                   { using left.location.register here as 2nd parameter is crucial to break dependency chains }
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSQRTSS,S_NO,left.Location.Register,left.Location.Register,location.Register));
                 S64Real:
                   { we use S_NO instead of S_XMM here, regardless of the register size, as the size of the memory location is 32/64 bit }
                   { using left.location.register here as 2nd parameter is crucial to break dependency chains }
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSQRTSD,S_NO,left.Location.Register,left.Location.Register,location.Register));
                 else
                   InternalError(200510031);
               end
             else
               case TFloatDef(resultdef).FloatType of
                 S32Real:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SQRTSS,S_NO,left.Location.Register,location.Register));
                 S64Real:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SQRTSD,S_NO,left.Location.Register,location.Register));
                 else
                   InternalError(2005100303);
               end;
           end
         else
           begin
             load_fpu_location(left);
             if left.Location.Loc=LOC_REFERENCE then
               tg.ungetiftemp(CurrentAsmData.CurrAsmList,left.Location.Reference);
             emit_none(A_FSQRT,S_NO);
           end;
       end;

     procedure TX86InlineNode.second_ln_real;
       begin
         load_fpu_location(left);
         emit_none(A_FLDLN2,S_NO);
         emit_none(A_FXCH,S_NO);
         emit_none(A_FYL2X,S_NO);
       end;

     procedure TX86InlineNode.second_cos_real;
       begin

         load_fpu_location(left);
         emit_none(A_FCOS,S_NO);
       end;

     procedure TX86InlineNode.second_sin_real;
       begin

         load_fpu_location(left);
         emit_none(A_FSIN,S_NO)
       end;

     procedure TX86InlineNode.second_prefetch;
       var
         ref : TReference;
         r : TRegister;
         checkpointer_used : boolean;
       begin
{$if defined(i386)}
         if CurrentSettings.CPUType>=cpu_Pentium3 then
{$endif i386}
           begin
             { do not call Checkpointer for left node }
             checkpointer_used:=(cs_checkpointer in CurrentSettings.LocalSwitches);
             if checkpointer_used then
               node_change_local_switch(left,cs_checkpointer,false);
             SecondPass(left);
             if checkpointer_used then
               node_change_local_switch(left,cs_checkpointer,false);
             case left.Location.Loc of
               LOC_CREFERENCE,
               LOC_REFERENCE:
                 begin
                   r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
                   cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.Location.Reference,r);
                   Reference_Reset_Base(ref,r,0,left.Location.Reference.TempPos,left.Location.Reference.Alignment,left.Location.Reference.Volatility);
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_PREFETCHNTA,S_NO,ref));
                 end;
               else
                 { nothing to prefetch };
             end;
           end;
       end;


    procedure TX86InlineNode.second_abs_long;
      var
        hregister : TRegister;
        opsize : TCgSize;
        hp : TAICPU;
        hl: TAsmLabel;
      begin
{$if defined(i386)}
        if Is_64BitInt(resultdef) then
          inherited
        else if not(CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) then
          begin
            opsize:=Def_CGSize(left.resultdef);
            SecondPass(left);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
            location:=left.Location;
            location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opsize,opsize,left.Location.Register,location.Register);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,opsize,TCgSize2Size[opsize]*8-1,left.Location.Register);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,opsize,left.Location.Register,location.Register);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,opsize,left.Location.Register,location.Register);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                CurrentAsmData.getjumplabel(hl);
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,hl);
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,hl);
              end;
          end
        else
{$endif i386}
          begin
            opsize:=Def_CGSize(left.resultdef);
            SecondPass(left);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
            hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
            location:=left.Location;
            location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opsize,opsize,left.Location.Register,hregister);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opsize,opsize,left.Location.Register,location.Register);

            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            emit_reg(A_NEG,tcgsize2opsize[opsize],hregister);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                CurrentAsmData.getjumplabel(hl);
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,hl);
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,hl);
              end;
            hp:=TAICPU.op_reg_reg(A_CMOVcc,tcgsize2opsize[opsize],hregister,location.Register);
            hp.condition:=C_NS;
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            CurrentAsmData.CurrAsmList.concat(hp);
          end;
      end;

{*****************************************************************************
                     INCLUDE/EXCLUDE GENERIC HANDLING
*****************************************************************************}

      procedure TX86InlineNode.second_IncludeExclude;
        var
         hregister,
         hregister2: TRegister;
         SetBase   : aint;
         bitsperop,l : LongInt;
         cgop : TOpCG;
         asmop : TAsmOp;
         opdef : TDef;
         opsize,
         orgsize: TCgSize;
        begin

          { bts on memory locations is very slow, so even the default code is faster }
          if not(cs_opt_size in CurrentSettings.OptimizerSwitches) and (TCallParaNode(TCallParaNode(left).right).left.expectloc<>LOC_CONSTANT) and
            (TCallParaNode(left).left.expectloc=LOC_REFERENCE) then

            begin
              inherited;
              exit;
            end;

          if Is_SmallSet(TCallParaNode(left).resultdef) then
            begin
              opdef:=TCallParaNode(left).resultdef;
              opsize:=Int_CGSize(opdef.Size)
            end
          else
            begin
              opdef:=U32IntType;
              opsize:=OS_32;
            end;
          bitsperop:=(8*TCgSize2Size[opsize]);
          SecondPass(TCallParaNode(left).left);
          SecondPass(TCallParaNode(TCallParaNode(left).right).left);
          SetBase:=TSetDef(TCallParaNode(left).left.resultdef).SetBase;
          if TCallParaNode(TCallParaNode(left).right).left.Location.Loc=LOC_CONSTANT then
            begin
              { calculate bit position }
              l:=1 shl ((TCallParaNode(TCallParaNode(left).right).left.Location.Value-SetBase) mod bitsperop);

              { determine operator }
              if inlinenumber=in_include_x_y then
                cgop:=OP_OR
              else
                begin
                  cgop:=OP_AND;
                  l:=not(l);
                end;
              case TCallParaNode(left).left.Location.Loc of
                LOC_REFERENCE :
                  begin
                    inc(TCallParaNode(left).left.Location.Reference.Offset,
                      ((TCallParaNode(TCallParaNode(left).right).left.Location.Value-SetBase) div bitsperop)*TCgSize2Size[opsize]);
                    cg.A_Op_Const_Ref(CurrentAsmData.CurrAsmList,cgop,opsize,l,TCallParaNode(left).left.Location.Reference);
                  end;
                LOC_CSUBSETREG,
                LOC_CREGISTER :
                  hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,cgop,TCallParaNode(left).left.resultdef,l,TCallParaNode(left).left.Location);
                else
                  InternalError(200405022);
              end;
            end
          else
            begin
              orgsize:=opsize;
              if opsize in [OS_8,OS_S8] then
                begin
                  opdef:=U32IntType;
                  opsize:=OS_32;
                end;
              { determine asm operator }
              if inlinenumber=in_include_x_y then
                 asmop:=A_BTS
              else
                 asmop:=A_BTR;

              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(left).right).left.Location,TCallParaNode(TCallParaNode(left).right).left.resultdef,opdef,true);
              register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(left).right).left.resultdef,TCallParaNode(TCallParaNode(left).right).left.Location,SetBase);
              hregister:=TCallParaNode(TCallParaNode(left).right).left.Location.Register;
              if TCallParaNode(left).left.Location.Loc=LOC_REFERENCE then
                emit_reg_ref(asmop,tcgsize2opsize[opsize],hregister,TCallParaNode(left).left.Location.Reference)
              else
                begin
                  { second argument can't be an 8 bit register either }
                  hregister2:=TCallParaNode(left).left.Location.Register;
                  if (orgsize in [OS_8,OS_S8]) then
                    hregister2:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,hregister2,opsize);
                  emit_reg_reg(asmop,tcgsize2opsize[opsize],hregister,hregister2);
                end;
            end;
        end;


    procedure TX86InlineNode.second_popcnt;
      var
        opsize: TCgSize;
      begin
        SecondPass(left);

        opsize:=TCgSize2Unsigned[left.Location.Size];

        { no 8 Bit popcont }
        if opsize=OS_8 then
          opsize:=OS_16;

        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) or
           (left.Location.Size<>opsize) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,CGSize_OrdDef(opsize),true);

        Location_Reset(location,LOC_REGISTER,opsize);
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
        if left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
          emit_reg_reg(A_POPCNT,TCGSize2OpSize[opsize],left.Location.Register,location.Register)
        else
          emit_ref_reg(A_POPCNT,TCGSize2OpSize[opsize],left.Location.Reference,location.Register);

        if resultdef.Size=1 then
          begin
            location.Size:=OS_8;
            location.Register:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,location.Register,location.Size);
          end;
      end;


    procedure TX86InlineNode.second_fma;

      const
        op : array[false..true,false..true,S32Real..S64Real,0..3] of TAsmOp =
          (
           { positive product }
           (
            { positive third operand }
            ((A_VFMADD231SS,A_VFMADD231SS,A_VFMADD231SS,A_VFMADD213SS),
             (A_VFMADD231SD,A_VFMADD231SD,A_VFMADD231SD,A_VFMADD213SD)
            ),
            { negative third operand }
            ((A_VFMSUB231SS,A_VFMSUB231SS,A_VFMSUB231SS,A_VFMSUB213SS),
             (A_VFMSUB231SD,A_VFMSUB231SD,A_VFMSUB231SD,A_VFMSUB213SD)
            )
           ),
           { negative product }
           (
            { positive third operand }
            ((A_VFNMADD231SS,A_VFNMADD231SS,A_VFNMADD231SS,A_VFNMADD213SS),
             (A_VFNMADD231SD,A_VFNMADD231SD,A_VFNMADD231SD,A_VFNMADD213SD)
            ),
            { negative third operand }
            ((A_VFNMSUB231SS,A_VFNMSUB231SS,A_VFNMSUB231SS,A_VFNMSUB213SS),
             (A_VFNMSUB231SD,A_VFNMSUB231SD,A_VFNMSUB231SD,A_VFNMSUB213SD)
            )
           )
          );

      var
        paraarray : array[1..3] of TNode;
        memop,
        i : integer;
        negop3,
        negproduct,
        gotmem : boolean;

      begin

         if (fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[] then
           begin
             negop3:=false;
             negproduct:=false;
             paraarray[1]:=TCallParaNode(TCallParaNode(TCallParaNode(parameters).nextpara).nextpara).paravalue;
             paraarray[2]:=TCallParaNode(TCallParaNode(parameters).nextpara).paravalue;
             paraarray[3]:=TCallParaNode(parameters).paravalue;

             { check if a neg. node can be removed
               this is possible because changing the sign of
               a floating point number does not affect its absolute
               value in any way
             }
             if paraarray[1].nodetype=unaryminusn then
               begin
                 paraarray[1]:=TUnaryNode(paraarray[1]).left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 negproduct:=not(negproduct);
               end;

             if paraarray[2].nodetype=unaryminusn then
               begin
                 paraarray[2]:=TUnaryNode(paraarray[2]).left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 negproduct:=not(negproduct);
               end;

             if paraarray[3].nodetype=unaryminusn then
               begin
                 paraarray[3]:=TUnaryNode(paraarray[3]).left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 negop3:=true;
               end;

              for i:=1 to 3 do
               SecondPass(paraarray[i]);

             { only one memory operand is allowed }
             gotmem:=false;
             memop:=0;
             { in case parameters come on the FPU stack, we have to pop them in reverse order as we
               called secondpass }
             for i:=3 downto 1 do
               begin
                 if not(paraarray[i].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   begin
                     if (paraarray[i].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and not(gotmem) then
                       begin
                         memop:=i;
                         gotmem:=true;
                       end
                     else
                       hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,paraarray[i].Location,paraarray[i].resultdef,true);
                   end;
               end;

             Location_Reset(location,LOC_MMREGISTER,paraarray[1].Location.Size);
             location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

             if gotmem then
               begin
                 case memop of
                   1:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[3].resultdef,resultdef,
                         paraarray[3].Location.Register,location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,memop],S_NO,
                         paraarray[1].Location.Reference,paraarray[2].Location.Register,location.Register);
                     end;
                   2:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[3].resultdef,resultdef,
                         paraarray[3].Location.Register,location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,memop],S_NO,
                         paraarray[2].Location.Reference,paraarray[1].Location.Register,location.Register);
                     end;
                   3:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[1].resultdef,resultdef,
                         paraarray[1].Location.Register,location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,memop],S_NO,
                         paraarray[3].Location.Reference,paraarray[2].Location.Register,location.Register);
                     end
                   else
                     InternalError(2014041301);
                 end;
               end
             else
               begin
                 { try to use the location which is already in a temp. mm register as destination,
                   so the compiler might be able to re-use the register }
                 if paraarray[1].Location.Loc=LOC_MMREGISTER then
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[1].resultdef,resultdef,
                       paraarray[1].Location.Register,location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,3],S_NO,
                       paraarray[3].Location.Register,paraarray[2].Location.Register,location.Register);
                   end
                 else if paraarray[2].Location.Loc=LOC_MMREGISTER then
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[2].resultdef,resultdef,
                       paraarray[2].Location.Register,location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,3],S_NO,
                       paraarray[3].Location.Register,paraarray[1].Location.Register,location.Register);
                   end
                 else
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[3].resultdef,resultdef,
                       paraarray[3].Location.Register,location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(op[negproduct,negop3,TFloatDef(resultdef).FloatType,0],S_NO,
                       paraarray[1].Location.Register,paraarray[2].Location.Register,location.Register);
                   end;
               end;
           end
         else

           InternalError(2014032301);
      end;


    procedure TX86InlineNode.second_frac_real;
      var
        extrareg : TRegister;
      begin
        if Use_VectorFPU(resultdef) then
          begin
            SecondPass(left);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
            Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            if UseAVX then
              case TFloatDef(left.resultdef).FloatType of
                S32Real:
                  begin

                    if UseAVX512 and (FPUX86_HAS_AVX512DQ in fpu_capabilities[CurrentSettings.FPUType]) then
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VREDUCESS,S_NO,3,left.Location.Register,left.Location.Register,location.Register))
                    else

                      begin
                        { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSS,S_NO,3,left.Location.Register,left.Location.Register,location.Register));
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSUBSS,S_NO,location.Register,left.Location.Register,location.Register));
                      end;
                  end;
                S64Real:
                  begin

                    if UseAVX512 and (FPUX86_HAS_AVX512DQ in fpu_capabilities[CurrentSettings.FPUType]) then
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VREDUCESD,S_NO,3,left.Location.Register,left.Location.Register,location.Register))
                    else

                      begin
                        { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSD,S_NO,3,left.Location.Register,left.Location.Register,location.Register));
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSUBSD,S_NO,location.Register,left.Location.Register,location.Register));
                      end;
                  end;
                else
                  InternalError(2017052102);
              end
            else
              begin
                extrareg:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
                cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,location.Size,left.Location,location.Register,MMS_MoveScalar);
                case TFloatDef(left.resultdef).FloatType of
                  S32Real:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSS,S_NO,3,left.Location.Register,extrareg));
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SUBSS,S_NO,extrareg,location.Register));
                    end;
                  S64Real:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSD,S_NO,3,left.Location.Register,extrareg));
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SUBSD,S_NO,extrareg,location.Register));
                    end;
                  else
                    InternalError(2017052103);
                end;
              end;
            if TFloatDef(left.resultdef).FloatType<>TFloatDef(resultdef).FloatType then
              hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,location.Register,location.Register,MMS_MoveScalar);
          end
        else
          InternalError(2017052101);
      end;


    procedure TX86InlineNode.second_int_real;
      begin
        if Use_VectorFPU(resultdef) then
          begin
            SecondPass(left);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
            Location_Reset(location,LOC_MMREGISTER,left.Location.Size);
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            if UseAVX then
              case TFloatDef(resultdef).FloatType of
                S32Real:
                  { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSS,S_NO,3,left.Location.Register,left.Location.Register,location.Register));
                S64Real:
                  { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSD,S_NO,3,left.Location.Register,left.Location.Register,location.Register));
                else
                  InternalError(2017052105);
              end
            else
              begin
                case TFloatDef(resultdef).FloatType of
                  S32Real:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSS,S_NO,3,left.Location.Register,location.Register));
                  S64Real:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSD,S_NO,3,left.Location.Register,location.Register));
                  else
                    InternalError(2017052106);
                end;
              end;
          end
        else
          InternalError(2017052107);
      end;


    procedure TX86InlineNode.second_high;
      var
        donelab: TAsmLabel;
        hregister : TRegister;
        href : TReference;
      begin
        SecondPass(left);
        if not(Is_Dynamic_Array(left.resultdef)) then
          InternalError(2019122809);
        { length in dynamic arrays is at offset -sizeof(pint) }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        CurrentAsmData.getjumplabel(donelab);
        { by subtracting 1 here, we get the -1 into the register we need if the dyn. array is nil and the carry
          flag is set in this case, so we can jump depending on it

          when loading the actual high value, we have to take care later of the decreased value

          do not use the cgs, as they might emit dec instead of a sub instruction, however with dec the trick
          we are using is not working as dec does not touch the carry flag }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_SUB,TCGSize2OpSize[Def_CGSize(left.resultdef)],1,left.Location.Register));
        { volatility of the dyn. array refers to the volatility of the
          string pointer, not of the string data }
        cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_C,donelab);
        hlcg.Reference_Reset_Base(href,left.resultdef,left.Location.Register,-OSSIntType.Size+1,CTempPosInvalid,OSSIntType.Alignment,[]);
        { if the string pointer is nil, the length is 0 -> reuse the register
          that originally held the string pointer for the length, so that we
          can keep the original nil/0 as length in that case }
        hregister:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,left.Location.Register,Def_CGSize(resultdef));
        hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OSSIntType,resultdef,href,hregister);

        cg.A_Label(CurrentAsmData.CurrAsmList,donelab);
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=hregister;
      end;


    procedure TX86InlineNode.second_minmax;

      const
        oparray : array[false..true,false..true,S32Real..S64Real] of TAsmOp =
          (
           (
            (A_MINSS,A_MINSD),
            (A_VMINSS,A_VMINSD)
           ),
           (
            (A_MAXSS,A_MAXSD),
            (A_VMAXSS,A_VMAXSD)
           )
          );


      var

        memop : integer;
        gotmem : boolean;
        op: TAsmOp;

        i : integer;
        paraarray : array[1..2] of TNode;
        instr: TAICPU;
        opsize: TOpSize;
        finalval: TCGInt;
        tmpreg: TRegister;
      begin

         if
{$ifdef i386}
           ((CurrentSettings.FPUType>=fpu_sse) and Is_Single(resultdef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and Is_Double(resultdef))
{$else i386}
           Is_Single(resultdef) or Is_Double(resultdef)
{$endif i386}
           then
           begin
             paraarray[1]:=TCallParaNode(TCallParaNode(parameters).nextpara).paravalue;
             paraarray[2]:=TCallParaNode(parameters).paravalue;

             for i:=low(paraarray) to high(paraarray) do
               SecondPass(paraarray[i]);

             { only one memory operand is allowed }
             gotmem:=false;
             memop:=0;
             for i:=low(paraarray) to high(paraarray) do
               begin
                 if not(paraarray[i].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   begin
                     if (paraarray[i].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and not(gotmem) then
                       begin
                         memop:=i;
                         gotmem:=true;
                       end
                     else
                       hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,paraarray[i].Location,paraarray[i].resultdef,true);
                   end;
               end;

             { due to min/max behaviour that it loads always the second operand (must be the else assignment) into destination if
               one of the operands is a NaN, we cannot swap operands to omit a mova operation in case fastmath is off }
             if not(cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and gotmem and (memop=1) then
               begin
                 hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,paraarray[1].Location,paraarray[1].resultdef,true);
                 gotmem:=false;
               end;

             op:=oparray[inlinenumber in [in_max_single,in_max_double],UseAVX,TFloatDef(resultdef).FloatType];

             Location_Reset(location,LOC_MMREGISTER,paraarray[1].Location.Size);
             location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

             if gotmem then
               begin
                 if UseAVX then
                   case memop of
                     1:
                       emit_ref_reg_reg(op,S_NO,
                         paraarray[1].Location.Reference,paraarray[2].Location.Register,location.Register);
                     2:
                       emit_ref_reg_reg(op,S_NO,
                         paraarray[2].Location.Reference,paraarray[1].Location.Register,location.Register);
                     else
                       InternalError(2020120504);
                   end
                 else
                   case memop of
                     1:
                       begin
                         hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[2].resultdef,resultdef,
                           paraarray[2].Location.Register,location.Register,MMS_MoveScalar);
                         emit_ref_reg(op,S_NO,
                           paraarray[1].Location.Reference,location.Register);
                       end;
                     2:
                       begin
                         hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[1].resultdef,resultdef,
                           paraarray[1].Location.Register,location.Register,MMS_MoveScalar);
                         emit_ref_reg(op,S_NO,
                           paraarray[2].Location.Reference,location.Register);
                       end;
                     else
                       InternalError(2020120601);
                   end;
               end
             else
               begin
                 if UseAVX then
                   emit_reg_reg_reg(op,S_NO,
                     paraarray[2].Location.Register,paraarray[1].Location.Register,location.Register)
                 else
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,paraarray[1].resultdef,resultdef,
                       paraarray[1].Location.Register,location.Register,MMS_MoveScalar);
                     emit_reg_reg(op,S_NO,
                       paraarray[2].Location.Register,location.Register)
                   end;
               end;
           end
         else

         if
{$ifndef x86_64}
           (CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) and
{$endif x86_64}
           (
{$ifdef x86_64}
             Is_64BitInt(resultdef) or
{$endif x86_64}
             Is_32BitInt(resultdef)
           ) then
           begin
             { paraarray[1] is the right-hand side }
             paraarray[1]:=TCallParaNode(TCallParaNode(parameters).nextpara).paravalue;
             paraarray[2]:=TCallParaNode(parameters).paravalue;

             for i:=low(paraarray) to high(paraarray) do
               SecondPass(paraarray[i]);

             if paraarray[2].Location.Loc = LOC_CONSTANT then
               begin
                 { Swap the parameters so the constant is on the right }
                 paraarray[2]:=paraarray[1];
                 paraarray[1]:=TCallParaNode(parameters).paravalue;
               end;

             if not(paraarray[1].Location.Loc in [LOC_CONSTANT,LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,paraarray[1].Location,
                 paraarray[1].resultdef,paraarray[1].resultdef,true);

             if not(paraarray[2].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,paraarray[2].Location,
                 paraarray[2].resultdef,paraarray[2].resultdef,true);

             Location_Reset(location,LOC_REGISTER,paraarray[1].Location.Size);
             location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);


             hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,paraarray[1].resultdef,resultdef,paraarray[1].Location,location.Register);
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

{$ifdef x86_64}
             if Is_64BitInt(resultdef) then
               opsize := S_Q
             else
{$endif x86_64}
               opsize := S_L;

             { Try to use references as is, unless they would trigger internal
               error 200502052 }
             if (cs_create_pic in CurrentSettings.ModuleSwitches) and
               (paraarray[1].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               Assigned(paraarray[1].Location.Reference.Symbol) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,paraarray[1].Location,
                 paraarray[1].resultdef,paraarray[1].resultdef,true);

             { Try to use references as is, unless they would trigger internal
               error 200502052 }
             if (cs_create_pic in CurrentSettings.ModuleSwitches) and
               (paraarray[2].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               Assigned(paraarray[2].Location.Reference.Symbol) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,paraarray[2].Location,
                 paraarray[2].resultdef,paraarray[2].resultdef,true);

             case paraarray[1].Location.Loc of
               LOC_CONSTANT:
                 case paraarray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
{$ifdef x86_64}
                       { x86_64 only supports signed 32 bits constants directly }
                       if (opsize=S_Q) and
                           ((paraarray[1].Location.Value<low(LongInt)) or (paraarray[1].Location.Value>high(LongInt))) then
                         begin
                           tmpreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
                           hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,paraarray[1].Location.Value,tmpreg);
                           emit_reg_ref(A_CMP,opsize,tmpreg,paraarray[2].Location.Reference);
                         end
                       else
{$endif x86_64}
                         emit_const_ref(A_CMP,opsize,paraarray[1].Location.Value,paraarray[2].Location.Reference);

                       emit_ref_reg(A_CMOVcc,opsize,paraarray[2].Location.Reference,location.Register);
                       instr:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
{$ifdef x86_64}
                       { x86_64 only supports signed 32 bits constants directly }
                       if (opsize=S_Q) and
                           ((paraarray[1].Location.Value<low(LongInt)) or (paraarray[1].Location.Value>high(LongInt))) then
                         begin
                           tmpreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
                           hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,paraarray[1].Location.Value,tmpreg);
                           CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,opsize,
                             tmpreg,paraarray[2].Location.Register));
                         end
                       else
{$endif x86_64}
                         CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,opsize,
                           paraarray[1].Location.Value,paraarray[2].Location.Register));

                       instr:=TAICPU.op_reg_reg(A_CMOVcc,opsize,paraarray[2].Location.Register,location.Register);
                       CurrentAsmData.CurrAsmList.concat(instr); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121907);
                 end;

               LOC_REFERENCE,LOC_CREFERENCE:
                 case paraarray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
                       { The reference has already been stored at location.register, so use that }
                       emit_reg_ref(A_CMP,opsize,location.Register,paraarray[2].Location.Reference);
                       emit_ref_reg(A_CMOVcc,opsize,paraarray[2].Location.Reference,location.Register);
                       instr:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
                       emit_ref_reg(A_CMP,opsize,paraarray[1].Location.Reference,paraarray[2].Location.Register);
                       instr:=TAICPU.op_reg_reg(A_CMOVcc,opsize,paraarray[2].Location.Register,location.Register);
                       CurrentAsmData.CurrAsmList.concat(instr); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121906);
                 end;

               LOC_REGISTER,LOC_CREGISTER:
                 case paraarray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
                       emit_reg_ref(A_CMP,opsize,paraarray[1].Location.Register,paraarray[2].Location.Reference);

                       emit_ref_reg(A_CMOVcc,opsize,paraarray[2].Location.Reference,location.Register);
                       instr:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
                       CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,opsize,
                         paraarray[1].Location.Register,paraarray[2].Location.Register));

                       instr:=TAICPU.op_reg_reg(A_CMOVcc,opsize,paraarray[2].Location.Register,location.Register);
                       CurrentAsmData.CurrAsmList.concat(instr); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121905);
                 end;

               else
                 InternalError(2021121904);
             end;

             case inlinenumber of
               in_min_longint,
               in_min_int64:
                 instr.condition := C_L;
               in_min_dword,
               in_min_qword:
                 instr.condition := C_B;
               in_max_longint,
               in_max_int64:
                 instr.condition := C_G;
               in_max_dword,
               in_max_qword:
                 instr.condition := C_A;
               else
                 InternalError(2021121903);
             end;

             cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
           end
         else
           InternalError(2020120503);
      end;


end.
