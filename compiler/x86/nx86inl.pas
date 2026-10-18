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
          procedure Maybe_Remove_Round_Trunc_TypeConv; virtual;
         public
          function Pass_TypeCheck_CPU:TNode;override;

          { first pass override
            so that the code generator will actually generate
            these nodes.
          }
          function First_CPU: TNode;override;
          function First_Pi: TNode ; override;
          function First_ArcTan_Real: TNode; override;
          function First_Abs_Real: TNode; override;
          function First_Sqr_Real: TNode; override;
          function First_Sqrt_Real: TNode; override;
          function First_Ln_Real: TNode; override;
          function First_Cos_Real: TNode; override;
          function First_Sin_Real: TNode; override;
          function First_Round_Real: TNode; override;
          function First_Trunc_Real: TNode; override;
          function First_PopCnt: TNode; override;
          function First_FMA: TNode; override;
          function First_Frac_Real : TNode; override;
          function First_Int_Real : TNode; override;
          function First_MinMax: TNode; override;

          function Simplify(AForInline : Boolean) : TNode; override;

          { second pass override to generate these nodes }
          procedure Pass_Generate_Code_CPU;override;
          procedure Second_IncludeExclude;override;
          procedure Second_AndOrXorShiftRot_Assign;override;
          procedure Second_Pi; override;
          procedure Second_ArcTan_Real; override;
          procedure Second_Abs_Real; override;
          procedure Second_Round_Real; override;
          procedure Second_Sqr_Real; override;
          procedure Second_Sqrt_Real; override;
          procedure Second_Ln_Real; override;
          procedure Second_Cos_Real; override;
          procedure Second_Sin_Real; override;
          procedure Second_Trunc_Real; override;

          procedure Second_Prefetch;override;

          procedure Second_Abs_Long;override;
          procedure Second_PopCnt;override;
          procedure Second_FMA;override;
          procedure Second_Frac_Real;override;
          procedure Second_Int_Real;override;
          procedure Second_High;override;
          procedure Second_MinMax;override;
       private
          procedure LoadFPULocation(ANode: TNode);
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
      cgbase,Pass_1,pass_2,
      CPUInfo,cpubase,nutils,
      ncal,ncgutil,nld,ncon,nadd,nmat,ConstExp,
      tgobj,
      cga,cgutils,cgx86,cgobj,hlcgobj,CUtils;


{*****************************************************************************
                              TX86INLINENODE
*****************************************************************************}

     procedure TX86InlineNode.Maybe_Remove_Round_Trunc_TypeConv;
       begin
         { only makes a difference for x86_64 }
       end;


     function TX86InlineNode.Pass_TypeCheck_CPU: TNode;
       begin
         Result:=nil;
         case InlineNumber of
           in_x86_inportb:
             begin
               CheckParameters(1);
               ResultDef:=U8IntType;
             end;
           in_x86_inportw:
             begin
               CheckParameters(1);
               ResultDef:=U16IntType;
             end;
           in_x86_inportl:
             begin
               CheckParameters(1);
               ResultDef:=S32IntType;
             end;
           in_x86_outportb,
           in_x86_outportw,
           in_x86_outportl:
             begin
               CheckParameters(2);
               ResultDef:=VoidType;
             end;
           in_x86_pause,
           in_x86_cli,
           in_x86_sti:
             ResultDef:=VoidType;
           in_x86_get_cs,
           in_x86_get_ss,
           in_x86_get_ds,
           in_x86_get_es,
           in_x86_get_fs,
           in_x86_get_gs:

             ResultDef:=S32IntType;

           { include automatically generated code }
           {$i x86mmtype.inc}
           else
             Result:=inherited Pass_TypeCheck_CPU;
         end;
       end;


     function TX86InlineNode.First_CPU: TNode;
       begin
         Result:=nil;
         case InlineNumber of
           in_x86_inportb,
           in_x86_inportw,
           in_x86_inportl,
           in_x86_get_cs,
           in_x86_get_ss,
           in_x86_get_ds,
           in_x86_get_es,
           in_x86_get_fs,
           in_x86_get_gs:
             ExpectLoc:=LOC_REGISTER;
           in_x86_outportb,
           in_x86_outportw,
           in_x86_outportl,
           in_x86_pause,
           in_x86_cli,
           in_x86_sti:
             ExpectLoc:=LOC_VOID;
           { include automatically generated code }
           {$i x86mmfirst.inc}
           else
             Result:=inherited First_CPU;
         end;
       end;


     function TX86InlineNode.First_Pi : TNode;
      begin
        ExpectLoc:=LOC_FPUREGISTER;
        Result:=nil;
      end;


     function TX86InlineNode.First_ArcTan_Real : TNode;
      begin
        ExpectLoc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.First_Abs_Real : TNode;
       begin
         if Use_VectorFPU(ResultDef) then
           ExpectLoc:=LOC_MMREGISTER
         else
           ExpectLoc:=LOC_FPUREGISTER;
        First_Abs_Real := nil;
      end;

     function TX86InlineNode.First_Sqr_Real : TNode;
      begin
        if Use_VectorFPU(ResultDef) then
          ExpectLoc:=LOC_MMREGISTER
        else
          ExpectLoc:=LOC_FPUREGISTER;
        First_Sqr_Real := nil;
      end;

     function TX86InlineNode.First_Sqrt_Real : TNode;
      begin
        if Use_VectorFPU(ResultDef) then
          ExpectLoc:=LOC_MMREGISTER
        else
          ExpectLoc:=LOC_FPUREGISTER;
        First_Sqrt_Real := nil;
      end;

     function TX86InlineNode.First_Ln_Real : TNode;
      begin
        ExpectLoc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.First_Cos_Real : TNode;
      begin
        ExpectLoc:=LOC_FPUREGISTER;
        Result:=nil;
      end;

     function TX86InlineNode.First_Sin_Real : TNode;
      begin
        ExpectLoc:=LOC_FPUREGISTER;
        Result:=nil;
      end;


     function TX86InlineNode.First_Round_Real : TNode;
      begin
        Maybe_Remove_Round_Trunc_TypeConv;
{$ifdef x86_64}
        if Use_VectorFPU(Left.ResultDef) then
          ExpectLoc:=LOC_REGISTER
        else
{$endif x86_64}
          ExpectLoc:=LOC_REFERENCE;
        Result:=nil;
      end;


     function TX86InlineNode.First_Trunc_Real: TNode;
       begin
         Maybe_Remove_Round_Trunc_TypeConv;
         if (cs_opt_size in CurrentSettings.OptimizerSwitches)
{$ifdef x86_64}
           and not(Use_VectorFPU(Left.ResultDef))
{$endif x86_64}
           then
           Result:=inherited
         else
           begin
{$ifdef x86_64}
             if Use_VectorFPU(Left.ResultDef) then
               ExpectLoc:=LOC_REGISTER
             else
{$endif x86_64}
               ExpectLoc:=LOC_REFERENCE;
             Result:=nil;
           end;
       end;


     function TX86InlineNode.First_PopCnt: TNode;
       begin
         Result:=nil;

         if (CPUX86_HAS_POPCNT in cpu_capabilities[CurrentSettings.CPUType])
  {$ifdef i386}
            and not Is_64Bit(Left.ResultDef)
  {$endif i386}
           then
             ExpectLoc:=LOC_REGISTER
         else

           Result:=inherited First_PopCnt
       end;


     function TX86InlineNode.First_FMA : TNode;
       begin

         if ((fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[]) and
           ((Is_Double(ResultDef)) or (Is_Single(ResultDef))) then
           begin
             ExpectLoc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else

           Result:=inherited First_FMA;
       end;


     function TX86InlineNode.First_Frac_Real : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           ((Is_Double(ResultDef)) or (Is_Single(ResultDef))) then
           begin
             Maybe_Remove_Round_Trunc_TypeConv;
             ExpectLoc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else
           Result:=inherited First_Frac_Real;
       end;


     function TX86InlineNode.First_Int_Real : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           ((Is_Double(ResultDef)) or (Is_Single(ResultDef))) then
           begin
             Result:=nil;
             ExpectLoc:=LOC_MMREGISTER;
           end
         else
           Result:=inherited First_Int_Real;
       end;


     function TX86InlineNode.First_MinMax: TNode;
       begin

         if
{$ifdef i386}
           ((CurrentSettings.FPUType>=fpu_sse) and Is_Single(ResultDef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and Is_Double(ResultDef))
{$else i386}
           ((Is_Double(ResultDef)) or (Is_Single(ResultDef)))
{$endif i386}
           then
           begin
             ExpectLoc:=LOC_MMREGISTER;
             Result:=nil;
           end
         else

         if
{$ifndef x86_64}
           (CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) and
{$endif x86_64}
           (
{$ifdef x86_64}
             Is_64BitInt(ResultDef) or
{$endif x86_64}
             Is_32BitInt(ResultDef)
           ) then
           begin
             ExpectLoc:=LOC_REGISTER;
             Result:=nil;
           end
         else
           Result:=inherited First_MinMax;
       end;


     function TX86InlineNode.Simplify(AForInline : Boolean) : TNode;
       var
         lTempNode : TNode;
       begin
         if (CurrentSettings.FPUType>=fpu_sse41) and
           (InlineNumber=in_int_real) and (Left.NodeType=typeconvn) and
           not(nf_explicit in Left.Flags) and
           (TTypeConvNode(Left).Left.ResultDef.typ=floatdef) and
           ((Is_Double(TTypeConvNode(Left).Left.ResultDef)) or (Is_Single(TTypeConvNode(Left).Left.ResultDef))) then
           begin
             { get rid of the type conversion }
             lTempNode:=TTypeConvNode(Left).Left;
             TTypeConvNode(Left).Left:=nil;
             Left.free;
             Left:=lTempNode;
             Result:=Self.GetCopy;
             TInlineNode(Result).ResultDef:=lTempNode.ResultDef;
             TypeCheckPass(Result);
           end
         else
           Result:=inherited Simplify(AForInline);
       end;


     procedure TX86InlineNode.Pass_Generate_Code_CPU;

       var
         lParaArray : array[1..4] of TNode;
         lIndex : Integer;
         lOp: TAsmOp;

       procedure InPort(ADataReg:TRegister;ADataSize:TOpSize;ADataType:TDef);
         var
           lPortNumber: TNode;
         begin
           lPortNumber:=Left;
           SecondPass(lPortNumber);
           if (lPortNumber.Location.Loc=LOC_CONSTANT) and
              (lPortNumber.Location.Value>=0) and
              (lPortNumber.Location.Value<=255) then
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_IN,ADataSize,lPortNumber.Location.Value,ADataReg));
               Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
               Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
               hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,ADataType,ResultDef,ADataReg,Location.Register);
             end
           else
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lPortNumber.ResultDef,U16IntType,lPortNumber.Location,NR_DX);
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_IN,ADataSize,NR_DX,ADataReg));
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
               Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
               hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,ADataType,ResultDef,ADataReg,Location.Register);
             end;
         end;


       procedure OutPort(ADataReg:TRegister;ADataSize:TOpSize;ADataType:TDef);
         var
           lPortNumber, lPortData: TNode;
         begin
           lPortNumber:=TCallParaNode(TCallParaNode(Left).Right).Left;
           lPortData:=TCallParaNode(Left).Left;
           SecondPass(lPortData);
           SecondPass(lPortNumber);
           hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
           hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lPortData.ResultDef,ADataType,lPortData.Location,ADataReg);
           if (lPortNumber.Location.Loc=LOC_CONSTANT) and
              (lPortNumber.Location.Value>=0) and
              (lPortNumber.Location.Value<=255) then
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_OUT,ADataSize,ADataReg,lPortNumber.Location.Value))
           else
             begin
               hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
               hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lPortNumber.ResultDef,U16IntType,lPortNumber.Location,NR_DX);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_OUT,ADataSize,ADataReg,NR_DX));
               hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_DX);
             end;
           hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,ADataReg);
         end;


       procedure GetSegReg(ASegReg:TRegister);
         begin
           Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
           Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
           CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MOV,TCGSize2OpSize[Def_CGSize(ResultDef)],ASegReg,Location.Register));
         end;


      function GetConstInt(ANode: TNode): LongInt;
        begin
          Result:=0;
          if Is_ConstIntNode(ANode) then
            Result:=TOrdConstNode(ANode).Value.svalue
          else
            Message(type_e_constant_expr_expected);
        end;


      procedure GetParameters(ACount: LongInt);
        var
          lIndex: LongInt;
          lNode: TNode;
        begin
          if (ACount=1) and
             (not (Left is TCallParaNode)) then
            lParaArray[1]:=Left
          else
            begin
              lNode:=Left;
              for lIndex := ACount downto 1 do
                begin
                  lParaArray[lIndex]:=TCallParaNode(lNode).ParaValue;
                  lNode:=TCallParaNode(lNode).NextPara;
                end;
            end;
        end;

      procedure LocationForceMMXReg(AList:TAsmList;var ALocation: TLocation;AMaybeConst:Boolean);
        var
          lReg : TRegister;
        begin
          if (ALocation.Loc<>LOC_MMXREGISTER)  and
             ((ALocation.Loc<>LOC_CMMXREGISTER) or (not AMaybeConst)) then
            begin
              lReg:=TCGX86(cg).GetMMXRegister(AList);
              cg.A_LoadMM_Loc_Reg(AList,OS_M64,ALocation,lReg,nil);
              Location_FreeTemp(AList,ALocation);
              Location_Reset(ALocation,LOC_MMXREGISTER,OS_M64);
              ALocation.Register:=lReg;
            end;
        end;

      procedure LocationMakeRef(var ALocation: TLocation);
        var
          lLocation: TLocation;
        begin
          case ALocation.Loc of
            LOC_CREGISTER,
            LOC_REGISTER:
              begin
                Location_Reset_Ref(lLocation, LOC_REFERENCE, OS_32, 1, []);
                lLocation.Reference.Base:=ALocation.Register;

                ALocation:=lLocation;
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
              end;
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,ALocation,U32IntType,U32IntType,false);

              Location_Reset_Ref(lLocation, LOC_REFERENCE, OS_32, 1, []);
              lLocation.Reference.Base:=ALocation.Register;

              ALocation:=lLocation;
            end;
          end;
        end;

       begin
         FillChar(lParaArray,sizeof(lParaArray),0);
         case InlineNumber of
           in_x86_inportb:
             InPort(NR_AL,S_B,U8IntType);
           in_x86_inportw:
             InPort(NR_AX,S_W,U16IntType);
           in_x86_inportl:
             InPort(NR_EAX,S_L,S32IntType);
           in_x86_outportb:
             OutPort(NR_AL,S_B,U8IntType);
           in_x86_outportw:
             OutPort(NR_AX,S_W,U16IntType);
           in_x86_outportl:
             OutPort(NR_EAX,S_L,S32IntType);
           in_x86_cli:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_CLI));
           in_x86_sti:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_STI));
           in_x86_pause:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_PAUSE));
           in_x86_get_cs:
             GetSegReg(NR_CS);
           in_x86_get_ss:
             GetSegReg(NR_SS);
           in_x86_get_ds:
             GetSegReg(NR_DS);
           in_x86_get_es:
             GetSegReg(NR_ES);
           in_x86_get_fs:
             GetSegReg(NR_FS);
           in_x86_get_gs:
             GetSegReg(NR_GS);
           {$i x86mmsecond.inc}
           else
             inherited Pass_Generate_Code_CPU;
         end;
       end;


     procedure TX86InlineNode.Second_AndOrXorShiftRot_Assign;

       var
         lOpSize : TCgSize;
         lValueNode, lIndexNode, lLoadNode: TNode;
         lDestReg: TRegister;

       begin

         if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
           begin
             { Saves on a lot of typecasting and potential coding mistakes }
             lValueNode := TCallParaNode(Left).Left;
             lLoadNode := TCallParaNode(TCallParaNode(Left).Right).Left;

             lOpSize := Def_CGSize(lLoadNode.ResultDef);

             { BMI2 optimisations }
             if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and (InlineNumber=in_and_assign_x_y) then
               begin
                 { If the second operand is "((1 shl y) - 1)", we can turn it
                   into a BZHI operator instead }
                 if (lOpSize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) and
                   (lValueNode.NodeType = subn) and
                   (TAddNode(lValueNode).Right.NodeType = ordconstn) and
                   (TOrdConstNode(TAddNode(lValueNode).Right).Value = 1) and
                   (TAddNode(lValueNode).Left.NodeType = shln) and
                   (TShlShrNode(TAddNode(lValueNode).Left).Left.NodeType = ordconstn) and
                   (TOrdConstNode(TShlShrNode(TAddNode(lValueNode).Left).Left).Value = 1) then
                   begin
                     { Skip the subtract and shift nodes completely }

                     { Helps avoid all the awkward typecasts }
                     lIndexNode := TShlShrNode(TAddNode(lValueNode).Left).Right;
{$ifdef x86_64}
                     { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                     if (lIndexNode.NodeType = typeconvn) and (lOpSize in [OS_32, OS_S32]) and
                       (Def_CGSize(TTypeConvNode(lIndexNode).ResultDef) in [OS_64, OS_S64]) then
                       begin
                         { Convert to the 32-bit type }
                         lIndexNode.ResultDef:=lLoadNode.ResultDef;
                         Node_Reset_Flags(lIndexNode,[],[tnf_pass1_done]);

                         { We should't be getting any new errors }
                         if DoFirstPass(lIndexNode) then
                           InternalError(2022110202);

                         { Keep things internally consistent in case indexnode changed }
                         TShlShrNode(TAddNode(lValueNode).Left).Right:=lIndexNode;
                       end;
{$endif x86_64}
                     SecondPass(lIndexNode);
                     SecondPass(lLoadNode);

                     { allocate registers }
                     hlcg.Location_Force_Reg(
                       CurrentAsmData.CurrAsmList,
                       lIndexNode.Location,
                       lIndexNode.ResultDef,
                       lLoadNode.ResultDef,
                       false
                     );

                     case lLoadNode.Location.Loc of
                       LOC_REFERENCE,
                       LOC_CREFERENCE:
                         begin
                           { BZHI can only write to a register }
                           lDestReg := cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                           emit_reg_ref_reg(A_BZHI, TCGSize2OpSize[lOpSize], lIndexNode.Location.Register, lLoadNode.Location.Reference, lDestReg);
                           emit_reg_ref(A_MOV, TCGSize2OpSize[lOpSize], lDestReg, lLoadNode.Location.Reference);
                         end;
                       LOC_REGISTER,
                       LOC_CREGISTER:
                         emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[lOpSize], lIndexNode.Location.Register, lLoadNode.Location.Register, lLoadNode.Location.Register);
                       else
                         InternalError(2022102120);
                     end;

                     Exit;
                   end;
               end;
           end;


         inherited Second_AndOrXorShiftRot_Assign;
       end;

     procedure TX86InlineNode.Second_Pi;
       begin
         Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
         emit_none(A_FLDPI,S_NO);
         TCGX86(cg).inc_fpu_stack;
         Location.Register:=NR_FPU_RESULT_REG;
       end;


     { load the FPU into the an fpu register }
     procedure TX86InlineNode.LoadFPULocation(ANode: TNode);
       begin
         Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
         Location.Register:=NR_FPU_RESULT_REG;
         SecondPass(ANode);
         case ANode.Location.Loc of
           LOC_FPUREGISTER:
             ;
           LOC_CFPUREGISTER:
             begin
               cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,ANode.Location.Size,
                 ANode.Location.Size,ANode.Location.Register,Location.Register);
             end;
           LOC_REFERENCE,LOC_CREFERENCE:
             begin
               cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                  ANode.Location.Size,ANode.Location.Size,
                  ANode.Location.Reference,Location.Register);
             end;
           LOC_MMREGISTER,LOC_CMMREGISTER:
             begin
               Location:=ANode.Location;
               hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Location,ANode.ResultDef,false);
             end;
           else
             InternalError(309991);
         end;
       end;


     procedure TX86InlineNode.Second_ArcTan_Real;
       begin
         LoadFPULocation(Left);
         emit_none(A_FLD1,S_NO);
         emit_none(A_FPATAN,S_NO);
       end;


     procedure TX86InlineNode.Second_Abs_Real;

       function NeedsIndirect:Boolean; inline;
         begin
            { System owns these masks; its local indirect aliases are pointer
              cells, not mask data. Only consumers import them indirectly. }
           Result:=(tf_supports_packages in TargetInfo.Flags) and
                     not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
                     (TargetInfo.system in systems_indirect_var_imports);
         end;

       var
         lReference : TReference;
         lSym : TAsmSymbol;
       begin
         if Use_VectorFPU(ResultDef) then
           begin
             SecondPass(Left);
             if Left.Location.Loc<>LOC_MMREGISTER then
               hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,UseAVX);
             if UseAVX then
               begin
                 Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
                 Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(ResultDef));
               end
             else
               Location:=Left.Location;
             case TFloatDef(ResultDef).FloatType of
               S32Real:
                 begin
                   lSym:=CurrentAsmData.RefAsmSymbol(TargetInfo.cprefix+'FPC_ABSMASK_SINGLE',AT_DATA,NeedsIndirect);
                   Reference_Reset_Symbol(lReference,lSym,0,4,[]);
                   CurrentModule.Add_Extern_AsmSym(lSym);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList, lReference);
                   if UseAVX then
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(
                       A_VANDPS,S_XMM,lReference,Left.Location.Register,Location.Register))
                   else
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ANDPS,S_XMM,lReference,Location.Register));
                 end;
               S64Real:
                 begin
                   lSym:=CurrentAsmData.RefAsmSymbol(TargetInfo.cprefix+'FPC_ABSMASK_DOUBLE',AT_DATA,NeedsIndirect);
                   Reference_Reset_Symbol(lReference,lSym,0,4,[]);
                   CurrentModule.Add_Extern_AsmSym(lSym);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList, lReference);
                   if UseAVX then
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(
                       A_VANDPD,S_XMM,lReference,Left.Location.Register,Location.Register))
                   else
                     CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ANDPD,S_XMM,lReference,Location.Register))
                 end;
               else
                 InternalError(200506081);
             end;
           end
         else
           begin
             LoadFPULocation(Left);
             emit_none(A_FABS,S_NO);
           end;
       end;


     procedure TX86InlineNode.Second_Round_Real;
       begin
{$ifdef x86_64}
         if Use_VectorFPU(Left.ResultDef) then
           begin
             SecondPass(Left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
             Location_Reset(Location,LOC_REGISTER,OS_S64);
             Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_S64);
             if UseAVX then
               case Left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTSS2SI,S_NO,Left.Location.Register,Location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTSD2SI,S_NO,Left.Location.Register,Location.Register));
                 else
                   InternalError(2007031402);
               end
             else
               case Left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTSS2SI,S_NO,Left.Location.Register,Location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTSD2SI,S_NO,Left.Location.Register,Location.Register));
                 else
                   InternalError(2007031404);
               end;
           end
         else
{$endif x86_64}
          begin
            LoadFPULocation(Left);
            Location_Reset_Ref(Location,LOC_REFERENCE,OS_S64,0,[]);
            TG.GetTemp(CurrentAsmData.CurrAsmList,ResultDef.Size,ResultDef.Alignment,tt_normal,Location.Reference);
            emit_ref(A_FISTP,S_IQ,Location.Reference);
            TCGX86(cg).dec_fpu_stack;
            emit_none(A_FWAIT,S_NO);
           end;
       end;


     procedure TX86InlineNode.Second_Trunc_Real;
       var
         lOldControlWord,lNewControlWord : TReference;
       begin
{$ifdef x86_64}
         if Use_VectorFPU(Left.ResultDef) and
           not((Left.Location.Loc=LOC_FPUREGISTER) and (CurrentSettings.FPUType>=fpu_sse3)) then
           begin
             SecondPass(Left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
             Location_Reset(Location,LOC_REGISTER,OS_S64);
             Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_S64);
             if UseAVX then
               case Left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTTSS2SI,S_NO,Left.Location.Register,Location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_VCVTTSD2SI,S_NO,Left.Location.Register,Location.Register));
                 else
                   InternalError(2007031401);
               end
             else
               case Left.Location.Size of
                 OS_F32:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTTSS2SI,S_NO,Left.Location.Register,Location.Register));
                 OS_F64:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CVTTSD2SI,S_NO,Left.Location.Register,Location.Register));
                 else
                   InternalError(2007031403);
               end;
           end
         else
{$endif x86_64}
          begin
            if (CurrentSettings.FPUType>=fpu_sse3) then
              begin
                LoadFPULocation(Left);
                Location_Reset_Ref(Location,LOC_REFERENCE,OS_S64,0,[]);
                TG.GetTemp(CurrentAsmData.CurrAsmList,ResultDef.Size,ResultDef.Alignment,tt_normal,Location.Reference);
                emit_ref(A_FISTTP,S_IQ,Location.Reference);
                TCGX86(cg).dec_fpu_stack;
              end
            else
              begin
                TG.GetTemp(CurrentAsmData.CurrAsmList,2,2,tt_normal,lOldControlWord);
                TG.GetTemp(CurrentAsmData.CurrAsmList,2,2,tt_normal,lNewControlWord);

                  begin
                    emit_ref(A_FNSTCW,S_NO,lNewControlWord);
                    emit_ref(A_FNSTCW,S_NO,lOldControlWord);
                  end;
                emit_const_ref(A_OR,S_W,$0f00,lNewControlWord);
                LoadFPULocation(Left);
                emit_ref(A_FLDCW,S_NO,lNewControlWord);
                Location_Reset_Ref(Location,LOC_REFERENCE,OS_S64,0,[]);
                TG.GetTemp(CurrentAsmData.CurrAsmList,ResultDef.Size,ResultDef.Alignment,tt_normal,Location.Reference);
                emit_ref(A_FISTP,S_IQ,Location.Reference);
                TCGX86(cg).dec_fpu_stack;
                emit_ref(A_FLDCW,S_NO,lOldControlWord);
                emit_none(A_FWAIT,S_NO);
                TG.UnGetTemp(CurrentAsmData.CurrAsmList,lOldControlWord);
                TG.UnGetTemp(CurrentAsmData.CurrAsmList,lNewControlWord);
              end;
           end;
       end;


     procedure TX86InlineNode.Second_Sqr_Real;

       begin
         if Use_VectorFPU(ResultDef) then
           begin
             SecondPass(Left);
             Location_Reset(Location,LOC_MMREGISTER,Left.Location.Size);
             Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
             if UseAVX then
               begin
                 hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
                 cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_MUL,Left.Location.Size,Left.Location.Register,Left.Location.Register,Location.Register,MMS_MoveScalar);
               end
             else
               begin
                 if Left.Location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER] then
                   hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
                 cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,Location.Size,Left.Location,Location.Register,MMS_MoveScalar);
                 cg.A_OpMM_Reg_Reg(CurrentAsmData.CurrAsmList,OP_MUL,Left.Location.Size,Location.Register,Location.Register,MMS_MoveScalar);
               end;
           end
         else
           begin
             LoadFPULocation(Left);
             emit_reg_reg(A_FMUL,S_NO,NR_ST0,NR_ST0);
           end;
       end;


     procedure TX86InlineNode.Second_Sqrt_Real;
       begin
         if Use_VectorFPU(ResultDef) then
           begin
             SecondPass(Left);
             hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
             Location_Reset(Location,LOC_MMREGISTER,Left.Location.Size);
             Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
             if UseAVX then
               case TFloatDef(ResultDef).FloatType of
                 S32Real:
                   { we use S_NO instead of S_XMM here, regardless of the register size, as the size of the memory location is 32/64 bit }
                   { using left.location.register here as 2nd parameter is crucial to break dependency chains }
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSQRTSS,S_NO,Left.Location.Register,Left.Location.Register,Location.Register));
                 S64Real:
                   { we use S_NO instead of S_XMM here, regardless of the register size, as the size of the memory location is 32/64 bit }
                   { using left.location.register here as 2nd parameter is crucial to break dependency chains }
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSQRTSD,S_NO,Left.Location.Register,Left.Location.Register,Location.Register));
                 else
                   InternalError(200510031);
               end
             else
               case TFloatDef(ResultDef).FloatType of
                 S32Real:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SQRTSS,S_NO,Left.Location.Register,Location.Register));
                 S64Real:
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SQRTSD,S_NO,Left.Location.Register,Location.Register));
                 else
                   InternalError(2005100303);
               end;
           end
         else
           begin
             LoadFPULocation(Left);
             if Left.Location.Loc=LOC_REFERENCE then
               TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,Left.Location.Reference);
             emit_none(A_FSQRT,S_NO);
           end;
       end;

     procedure TX86InlineNode.Second_Ln_Real;
       begin
         LoadFPULocation(Left);
         emit_none(A_FLDLN2,S_NO);
         emit_none(A_FXCH,S_NO);
         emit_none(A_FYL2X,S_NO);
       end;

     procedure TX86InlineNode.Second_Cos_Real;
       begin

         LoadFPULocation(Left);
         emit_none(A_FCOS,S_NO);
       end;

     procedure TX86InlineNode.Second_Sin_Real;
       begin

         LoadFPULocation(Left);
         emit_none(A_FSIN,S_NO)
       end;

     procedure TX86InlineNode.Second_Prefetch;
       var
         lReference : TReference;
         lReg : TRegister;
         lCheckPointerUsed : Boolean;
       begin
{$if defined(i386)}
         if CurrentSettings.CPUType>=cpu_Pentium3 then
{$endif i386}
           begin
             { do not call Checkpointer for left node }
             lCheckPointerUsed:=(cs_checkpointer in CurrentSettings.LocalSwitches);
             if lCheckPointerUsed then
               Node_Change_Local_Switch(Left,cs_checkpointer,false);
             SecondPass(Left);
             if lCheckPointerUsed then
               Node_Change_Local_Switch(Left,cs_checkpointer,false);
             case Left.Location.Loc of
               LOC_CREFERENCE,
               LOC_REFERENCE:
                 begin
                   lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
                   cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.Location.Reference,lReg);
                   Reference_Reset_Base(lReference,lReg,0,Left.Location.Reference.TempPos,Left.Location.Reference.Alignment,Left.Location.Reference.Volatility);
                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_PREFETCHNTA,S_NO,lReference));
                 end;
               else
                 { nothing to prefetch };
             end;
           end;
       end;


    procedure TX86InlineNode.Second_Abs_Long;
      var
        lReg : TRegister;
        lOpSize : TCgSize;
        lInstruction : TAICPU;
        lLabel: TAsmLabel;
      begin
{$if defined(i386)}
        if Is_64BitInt(ResultDef) then
          inherited
        else if not(CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) then
          begin
            lOpSize:=Def_CGSize(Left.ResultDef);
            SecondPass(Left);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
            Location:=Left.Location;
            Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpSize,lOpSize,Left.Location.Register,Location.Register);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,lOpSize,TCgSize2Size[lOpSize]*8-1,Left.Location.Register);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,lOpSize,Left.Location.Register,Location.Register);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpSize,Left.Location.Register,Location.Register);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                CurrentAsmData.getjumplabel(lLabel);
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,lLabel);
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
              end;
          end
        else
{$endif i386}
          begin
            lOpSize:=Def_CGSize(Left.ResultDef);
            SecondPass(Left);
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
            lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
            Location:=Left.Location;
            Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpSize,lOpSize,Left.Location.Register,lReg);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpSize,lOpSize,Left.Location.Register,Location.Register);

            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            emit_reg(A_NEG,tcgsize2opsize[lOpSize],lReg);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                CurrentAsmData.getjumplabel(lLabel);
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,lLabel);
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
              end;
            lInstruction:=TAICPU.op_reg_reg(A_CMOVcc,tcgsize2opsize[lOpSize],lReg,Location.Register);
            lInstruction.condition:=C_NS;
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            CurrentAsmData.CurrAsmList.concat(lInstruction);
          end;
      end;

{*****************************************************************************
                     INCLUDE/EXCLUDE GENERIC HANDLING
*****************************************************************************}

      procedure TX86InlineNode.Second_IncludeExclude;
        var
         lReg,
         lReg2: TRegister;
         lSetBase   : AInt;
         lBitsPerOp,lBitCount : LongInt;
         lCGOp : TOpCG;
         lAsmOp : TAsmOp;
         lOpDef : TDef;
         lOpSize,
         lOriginalSize: TCgSize;
        begin

          { bts on memory locations is very slow, so even the default code is faster }
          if not(cs_opt_size in CurrentSettings.OptimizerSwitches) and (TCallParaNode(TCallParaNode(Left).Right).Left.ExpectLoc<>LOC_CONSTANT) and
            (TCallParaNode(Left).Left.ExpectLoc=LOC_REFERENCE) then

            begin
              inherited;
              exit;
            end;

          if Is_SmallSet(TCallParaNode(Left).ResultDef) then
            begin
              lOpDef:=TCallParaNode(Left).ResultDef;
              lOpSize:=Int_CGSize(lOpDef.Size)
            end
          else
            begin
              lOpDef:=U32IntType;
              lOpSize:=OS_32;
            end;
          lBitsPerOp:=(8*TCgSize2Size[lOpSize]);
          SecondPass(TCallParaNode(Left).Left);
          SecondPass(TCallParaNode(TCallParaNode(Left).Right).Left);
          lSetBase:=TSetDef(TCallParaNode(Left).Left.ResultDef).SetBase;
          if TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc=LOC_CONSTANT then
            begin
              { calculate bit position }
              lBitCount:=1 shl ((TCallParaNode(TCallParaNode(Left).Right).Left.Location.Value-lSetBase) mod lBitsPerOp);

              { determine operator }
              if InlineNumber=in_include_x_y then
                lCGOp:=OP_OR
              else
                begin
                  lCGOp:=OP_AND;
                  lBitCount:=not(lBitCount);
                end;
              case TCallParaNode(Left).Left.Location.Loc of
                LOC_REFERENCE :
                  begin
                    inc(TCallParaNode(Left).Left.Location.Reference.Offset,
                      ((TCallParaNode(TCallParaNode(Left).Right).Left.Location.Value-lSetBase) div lBitsPerOp)*TCgSize2Size[lOpSize]);
                    cg.A_Op_Const_Ref(CurrentAsmData.CurrAsmList,lCGOp,lOpSize,lBitCount,TCallParaNode(Left).Left.Location.Reference);
                  end;
                LOC_CSUBSETREG,
                LOC_CREGISTER :
                  hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,lCGOp,TCallParaNode(Left).Left.ResultDef,lBitCount,TCallParaNode(Left).Left.Location);
                else
                  InternalError(200405022);
              end;
            end
          else
            begin
              lOriginalSize:=lOpSize;
              if lOpSize in [OS_8,OS_S8] then
                begin
                  lOpDef:=U32IntType;
                  lOpSize:=OS_32;
                end;
              { determine asm operator }
              if InlineNumber=in_include_x_y then
                 lAsmOp:=A_BTS
              else
                 lAsmOp:=A_BTR;

              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(Left).Right).Left.Location,TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef,lOpDef,true);
              Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef,TCallParaNode(TCallParaNode(Left).Right).Left.Location,lSetBase);
              lReg:=TCallParaNode(TCallParaNode(Left).Right).Left.Location.Register;
              if TCallParaNode(Left).Left.Location.Loc=LOC_REFERENCE then
                emit_reg_ref(lAsmOp,tcgsize2opsize[lOpSize],lReg,TCallParaNode(Left).Left.Location.Reference)
              else
                begin
                  { second argument can't be an 8 bit register either }
                  lReg2:=TCallParaNode(Left).Left.Location.Register;
                  if (lOriginalSize in [OS_8,OS_S8]) then
                    lReg2:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,lReg2,lOpSize);
                  emit_reg_reg(lAsmOp,tcgsize2opsize[lOpSize],lReg,lReg2);
                end;
            end;
        end;


    procedure TX86InlineNode.Second_PopCnt;
      var
        lOpSize: TCgSize;
      begin
        SecondPass(Left);

        lOpSize:=TCgSize2Unsigned[Left.Location.Size];

        { no 8 Bit popcont }
        if lOpSize=OS_8 then
          lOpSize:=OS_16;

        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) or
           (Left.Location.Size<>lOpSize) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,CGSize_OrdDef(lOpSize),true);

        Location_Reset(Location,LOC_REGISTER,lOpSize);
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
        if Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
          emit_reg_reg(A_POPCNT,TCGSize2OpSize[lOpSize],Left.Location.Register,Location.Register)
        else
          emit_ref_reg(A_POPCNT,TCGSize2OpSize[lOpSize],Left.Location.Reference,Location.Register);

        if ResultDef.Size=1 then
          begin
            Location.Size:=OS_8;
            Location.Register:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Location.Register,Location.Size);
          end;
      end;


    procedure TX86InlineNode.Second_FMA;

      const
        Op : array[false..true,false..true,S32Real..S64Real,0..3] of TAsmOp =
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
        lParaArray : array[1..3] of TNode;
        lMemoryOperand,
        lIndex : Integer;
        lNegOperand3,
        lNegProduct,
        lGotMemoryOperand : Boolean;

      begin

         if (fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[] then
           begin
             lNegOperand3:=false;
             lNegProduct:=false;
             lParaArray[1]:=TCallParaNode(TCallParaNode(TCallParaNode(Parameters).NextPara).NextPara).ParaValue;
             lParaArray[2]:=TCallParaNode(TCallParaNode(Parameters).NextPara).ParaValue;
             lParaArray[3]:=TCallParaNode(Parameters).ParaValue;

             { check if a neg. node can be removed
               this is possible because changing the sign of
               a floating point number does not affect its absolute
               value in any way
             }
             if lParaArray[1].NodeType=unaryminusn then
               begin
                 lParaArray[1]:=TUnaryNode(lParaArray[1]).Left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 lNegProduct:=not(lNegProduct);
               end;

             if lParaArray[2].NodeType=unaryminusn then
               begin
                 lParaArray[2]:=TUnaryNode(lParaArray[2]).Left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 lNegProduct:=not(lNegProduct);
               end;

             if lParaArray[3].NodeType=unaryminusn then
               begin
                 lParaArray[3]:=TUnaryNode(lParaArray[3]).Left;
                 { do not release the unused unary minus node, it is kept and release together with the other nodes,
                   only no code is generated for it }
                 lNegOperand3:=true;
               end;

              for lIndex:=1 to 3 do
               SecondPass(lParaArray[lIndex]);

             { only one memory operand is allowed }
             lGotMemoryOperand:=false;
             lMemoryOperand:=0;
             { in case parameters come on the FPU stack, we have to pop them in reverse order as we
               called secondpass }
             for lIndex:=3 downto 1 do
               begin
                 if not(lParaArray[lIndex].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   begin
                     if (lParaArray[lIndex].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and not(lGotMemoryOperand) then
                       begin
                         lMemoryOperand:=lIndex;
                         lGotMemoryOperand:=true;
                       end
                     else
                       hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,lParaArray[lIndex].Location,lParaArray[lIndex].ResultDef,true);
                   end;
               end;

             Location_Reset(Location,LOC_MMREGISTER,lParaArray[1].Location.Size);
             Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);

             if lGotMemoryOperand then
               begin
                 case lMemoryOperand of
                   1:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[3].ResultDef,ResultDef,
                         lParaArray[3].Location.Register,Location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,lMemoryOperand],S_NO,
                         lParaArray[1].Location.Reference,lParaArray[2].Location.Register,Location.Register);
                     end;
                   2:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[3].ResultDef,ResultDef,
                         lParaArray[3].Location.Register,Location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,lMemoryOperand],S_NO,
                         lParaArray[2].Location.Reference,lParaArray[1].Location.Register,Location.Register);
                     end;
                   3:
                     begin
                       hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,ResultDef,
                         lParaArray[1].Location.Register,Location.Register,MMS_MoveScalar);
                       emit_ref_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,lMemoryOperand],S_NO,
                         lParaArray[3].Location.Reference,lParaArray[2].Location.Register,Location.Register);
                     end
                   else
                     InternalError(2014041301);
                 end;
               end
             else
               begin
                 { try to use the location which is already in a temp. mm register as destination,
                   so the compiler might be able to re-use the register }
                 if lParaArray[1].Location.Loc=LOC_MMREGISTER then
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,ResultDef,
                       lParaArray[1].Location.Register,Location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,3],S_NO,
                       lParaArray[3].Location.Register,lParaArray[2].Location.Register,Location.Register);
                   end
                 else if lParaArray[2].Location.Loc=LOC_MMREGISTER then
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[2].ResultDef,ResultDef,
                       lParaArray[2].Location.Register,Location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,3],S_NO,
                       lParaArray[3].Location.Register,lParaArray[1].Location.Register,Location.Register);
                   end
                 else
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[3].ResultDef,ResultDef,
                       lParaArray[3].Location.Register,Location.Register,MMS_MoveScalar);
                     emit_reg_reg_reg(Op[lNegProduct,lNegOperand3,TFloatDef(ResultDef).FloatType,0],S_NO,
                       lParaArray[1].Location.Register,lParaArray[2].Location.Register,Location.Register);
                   end;
               end;
           end
         else

           InternalError(2014032301);
      end;


    procedure TX86InlineNode.Second_Frac_Real;
      var
        lExtraReg : TRegister;
      begin
        if Use_VectorFPU(ResultDef) then
          begin
            SecondPass(Left);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            if UseAVX then
              case TFloatDef(Left.ResultDef).FloatType of
                S32Real:
                  begin

                    if UseAVX512 and (FPUX86_HAS_AVX512DQ in fpu_capabilities[CurrentSettings.FPUType]) then
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VREDUCESS,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register))
                    else

                      begin
                        { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSS,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register));
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSUBSS,S_NO,Location.Register,Left.Location.Register,Location.Register));
                      end;
                  end;
                S64Real:
                  begin

                    if UseAVX512 and (FPUX86_HAS_AVX512DQ in fpu_capabilities[CurrentSettings.FPUType]) then
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VREDUCESD,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register))
                    else

                      begin
                        { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSD,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register));
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_VSUBSD,S_NO,Location.Register,Left.Location.Register,Location.Register));
                      end;
                  end;
                else
                  InternalError(2017052102);
              end
            else
              begin
                lExtraReg:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
                cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,Location.Size,Left.Location,Location.Register,MMS_MoveScalar);
                case TFloatDef(Left.ResultDef).FloatType of
                  S32Real:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSS,S_NO,3,Left.Location.Register,lExtraReg));
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SUBSS,S_NO,lExtraReg,Location.Register));
                    end;
                  S64Real:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSD,S_NO,3,Left.Location.Register,lExtraReg));
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_SUBSD,S_NO,lExtraReg,Location.Register));
                    end;
                  else
                    InternalError(2017052103);
                end;
              end;
            if TFloatDef(Left.ResultDef).FloatType<>TFloatDef(ResultDef).FloatType then
              hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Location.Register,Location.Register,MMS_MoveScalar);
          end
        else
          InternalError(2017052101);
      end;


    procedure TX86InlineNode.Second_Int_Real;
      begin
        if Use_VectorFPU(ResultDef) then
          begin
            SecondPass(Left);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
            Location_Reset(Location,LOC_MMREGISTER,Left.Location.Size);
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            if UseAVX then
              case TFloatDef(ResultDef).FloatType of
                S32Real:
                  { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSS,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register));
                S64Real:
                  { using left.location.register here as 3rd parameter is crucial to break dependency chains }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg_reg(A_VROUNDSD,S_NO,3,Left.Location.Register,Left.Location.Register,Location.Register));
                else
                  InternalError(2017052105);
              end
            else
              begin
                case TFloatDef(ResultDef).FloatType of
                  S32Real:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSS,S_NO,3,Left.Location.Register,Location.Register));
                  S64Real:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_ROUNDSD,S_NO,3,Left.Location.Register,Location.Register));
                  else
                    InternalError(2017052106);
                end;
              end;
          end
        else
          InternalError(2017052107);
      end;


    procedure TX86InlineNode.Second_High;
      var
        lDoneLabel: TAsmLabel;
        lReg : TRegister;
        lReference : TReference;
      begin
        SecondPass(Left);
        if not(Is_Dynamic_Array(Left.ResultDef)) then
          InternalError(2019122809);
        { length in dynamic arrays is at offset -sizeof(pint) }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        CurrentAsmData.getjumplabel(lDoneLabel);
        { by subtracting 1 here, we get the -1 into the register we need if the dyn. array is nil and the carry
          flag is set in this case, so we can jump depending on it

          when loading the actual high value, we have to take care later of the decreased value

          do not use the cgs, as they might emit dec instead of a sub instruction, however with dec the trick
          we are using is not working as dec does not touch the carry flag }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_SUB,TCGSize2OpSize[Def_CGSize(Left.ResultDef)],1,Left.Location.Register));
        { volatility of the dyn. array refers to the volatility of the
          string pointer, not of the string data }
        cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_C,lDoneLabel);
        hlcg.Reference_Reset_Base(lReference,Left.ResultDef,Left.Location.Register,-OSSIntType.Size+1,CTempPosInvalid,OSSIntType.Alignment,[]);
        { if the string pointer is nil, the length is 0 -> reuse the register
          that originally held the string pointer for the length, so that we
          can keep the original nil/0 as length in that case }
        lReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Left.Location.Register,Def_CGSize(ResultDef));
        hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OSSIntType,ResultDef,lReference,lReg);

        cg.A_Label(CurrentAsmData.CurrAsmList,lDoneLabel);
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=lReg;
      end;


    procedure TX86InlineNode.Second_MinMax;

      const
        OpArray : array[false..true,false..true,S32Real..S64Real] of TAsmOp =
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

        lMemoryOperand : Integer;
        lGotMemoryOperand : Boolean;
        lOp: TAsmOp;

        lIndex : Integer;
        lParaArray : array[1..2] of TNode;
        lInstruction: TAICPU;
        lOpSize: TOpSize;
        lFinalValue: TCGInt;
        lTempReg: TRegister;
      begin

         if
{$ifdef i386}
           ((CurrentSettings.FPUType>=fpu_sse) and Is_Single(ResultDef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and Is_Double(ResultDef))
{$else i386}
           Is_Single(ResultDef) or Is_Double(ResultDef)
{$endif i386}
           then
           begin
             lParaArray[1]:=TCallParaNode(TCallParaNode(Parameters).NextPara).ParaValue;
             lParaArray[2]:=TCallParaNode(Parameters).ParaValue;

             for lIndex:=low(lParaArray) to high(lParaArray) do
               SecondPass(lParaArray[lIndex]);

             { only one memory operand is allowed }
             lGotMemoryOperand:=false;
             lMemoryOperand:=0;
             for lIndex:=low(lParaArray) to high(lParaArray) do
               begin
                 if not(lParaArray[lIndex].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   begin
                     if (lParaArray[lIndex].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and not(lGotMemoryOperand) then
                       begin
                         lMemoryOperand:=lIndex;
                         lGotMemoryOperand:=true;
                       end
                     else
                       hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,lParaArray[lIndex].Location,lParaArray[lIndex].ResultDef,true);
                   end;
               end;

             { due to min/max behaviour that it loads always the second operand (must be the else assignment) into destination if
               one of the operands is a NaN, we cannot swap operands to omit a mova operation in case fastmath is off }
             if not(cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and lGotMemoryOperand and (lMemoryOperand=1) then
               begin
                 hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,lParaArray[1].Location,lParaArray[1].ResultDef,true);
                 lGotMemoryOperand:=false;
               end;

             lOp:=OpArray[InlineNumber in [in_max_single,in_max_double],UseAVX,TFloatDef(ResultDef).FloatType];

             Location_Reset(Location,LOC_MMREGISTER,lParaArray[1].Location.Size);
             Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);

             if lGotMemoryOperand then
               begin
                 if UseAVX then
                   case lMemoryOperand of
                     1:
                       emit_ref_reg_reg(lOp,S_NO,
                         lParaArray[1].Location.Reference,lParaArray[2].Location.Register,Location.Register);
                     2:
                       emit_ref_reg_reg(lOp,S_NO,
                         lParaArray[2].Location.Reference,lParaArray[1].Location.Register,Location.Register);
                     else
                       InternalError(2020120504);
                   end
                 else
                   case lMemoryOperand of
                     1:
                       begin
                         hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[2].ResultDef,ResultDef,
                           lParaArray[2].Location.Register,Location.Register,MMS_MoveScalar);
                         emit_ref_reg(lOp,S_NO,
                           lParaArray[1].Location.Reference,Location.Register);
                       end;
                     2:
                       begin
                         hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,ResultDef,
                           lParaArray[1].Location.Register,Location.Register,MMS_MoveScalar);
                         emit_ref_reg(lOp,S_NO,
                           lParaArray[2].Location.Reference,Location.Register);
                       end;
                     else
                       InternalError(2020120601);
                   end;
               end
             else
               begin
                 if UseAVX then
                   emit_reg_reg_reg(lOp,S_NO,
                     lParaArray[2].Location.Register,lParaArray[1].Location.Register,Location.Register)
                 else
                   begin
                     hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,ResultDef,
                       lParaArray[1].Location.Register,Location.Register,MMS_MoveScalar);
                     emit_reg_reg(lOp,S_NO,
                       lParaArray[2].Location.Register,Location.Register)
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
             Is_64BitInt(ResultDef) or
{$endif x86_64}
             Is_32BitInt(ResultDef)
           ) then
           begin
             { paraarray[1] is the right-hand side }
             lParaArray[1]:=TCallParaNode(TCallParaNode(Parameters).NextPara).ParaValue;
             lParaArray[2]:=TCallParaNode(Parameters).ParaValue;

             for lIndex:=low(lParaArray) to high(lParaArray) do
               SecondPass(lParaArray[lIndex]);

             if lParaArray[2].Location.Loc = LOC_CONSTANT then
               begin
                 { Swap the parameters so the constant is on the right }
                 lParaArray[2]:=lParaArray[1];
                 lParaArray[1]:=TCallParaNode(Parameters).ParaValue;
               end;

             if not(lParaArray[1].Location.Loc in [LOC_CONSTANT,LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].Location,
                 lParaArray[1].ResultDef,lParaArray[1].ResultDef,true);

             if not(lParaArray[2].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lParaArray[2].Location,
                 lParaArray[2].ResultDef,lParaArray[2].ResultDef,true);

             Location_Reset(Location,LOC_REGISTER,lParaArray[1].Location.Size);
             Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);


             hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,ResultDef,lParaArray[1].Location,Location.Register);
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

{$ifdef x86_64}
             if Is_64BitInt(ResultDef) then
               lOpSize := S_Q
             else
{$endif x86_64}
               lOpSize := S_L;

             { Try to use references as is, unless they would trigger internal
               error 200502052 }
             if (cs_create_pic in CurrentSettings.ModuleSwitches) and
               (lParaArray[1].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               Assigned(lParaArray[1].Location.Reference.Symbol) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].Location,
                 lParaArray[1].ResultDef,lParaArray[1].ResultDef,true);

             { Try to use references as is, unless they would trigger internal
               error 200502052 }
             if (cs_create_pic in CurrentSettings.ModuleSwitches) and
               (lParaArray[2].Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               Assigned(lParaArray[2].Location.Reference.Symbol) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lParaArray[2].Location,
                 lParaArray[2].ResultDef,lParaArray[2].ResultDef,true);

             case lParaArray[1].Location.Loc of
               LOC_CONSTANT:
                 case lParaArray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
{$ifdef x86_64}
                       { x86_64 only supports signed 32 bits constants directly }
                       if (lOpSize=S_Q) and
                           ((lParaArray[1].Location.Value<low(LongInt)) or (lParaArray[1].Location.Value>high(LongInt))) then
                         begin
                           lTempReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
                           hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,lParaArray[1].Location.Value,lTempReg);
                           emit_reg_ref(A_CMP,lOpSize,lTempReg,lParaArray[2].Location.Reference);
                         end
                       else
{$endif x86_64}
                         emit_const_ref(A_CMP,lOpSize,lParaArray[1].Location.Value,lParaArray[2].Location.Reference);

                       emit_ref_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Reference,Location.Register);
                       lInstruction:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
{$ifdef x86_64}
                       { x86_64 only supports signed 32 bits constants directly }
                       if (lOpSize=S_Q) and
                           ((lParaArray[1].Location.Value<low(LongInt)) or (lParaArray[1].Location.Value>high(LongInt))) then
                         begin
                           lTempReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
                           hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,lParaArray[1].Location.Value,lTempReg);
                           CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,lOpSize,
                             lTempReg,lParaArray[2].Location.Register));
                         end
                       else
{$endif x86_64}
                         CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,lOpSize,
                           lParaArray[1].Location.Value,lParaArray[2].Location.Register));

                       lInstruction:=TAICPU.op_reg_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Register,Location.Register);
                       CurrentAsmData.CurrAsmList.concat(lInstruction); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121907);
                 end;

               LOC_REFERENCE,LOC_CREFERENCE:
                 case lParaArray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
                       { The reference has already been stored at location.register, so use that }
                       emit_reg_ref(A_CMP,lOpSize,Location.Register,lParaArray[2].Location.Reference);
                       emit_ref_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Reference,Location.Register);
                       lInstruction:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
                       emit_ref_reg(A_CMP,lOpSize,lParaArray[1].Location.Reference,lParaArray[2].Location.Register);
                       lInstruction:=TAICPU.op_reg_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Register,Location.Register);
                       CurrentAsmData.CurrAsmList.concat(lInstruction); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121906);
                 end;

               LOC_REGISTER,LOC_CREGISTER:
                 case lParaArray[2].Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     begin
                       emit_reg_ref(A_CMP,lOpSize,lParaArray[1].Location.Register,lParaArray[2].Location.Reference);

                       emit_ref_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Reference,Location.Register);
                       lInstruction:=TAICPU(CurrentAsmData.CurrAsmList.Last); { The instruction just inserted; we need to modify its condition below }
                     end;
                   LOC_REGISTER,LOC_CREGISTER:
                     begin
                       CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,lOpSize,
                         lParaArray[1].Location.Register,lParaArray[2].Location.Register));

                       lInstruction:=TAICPU.op_reg_reg(A_CMOVcc,lOpSize,lParaArray[2].Location.Register,Location.Register);
                       CurrentAsmData.CurrAsmList.concat(lInstruction); { We need to modify the instruction's condition below }
                     end;
                   else
                     InternalError(2021121905);
                 end;

               else
                 InternalError(2021121904);
             end;

             case InlineNumber of
               in_min_longint,
               in_min_int64:
                 lInstruction.condition := C_L;
               in_min_dword,
               in_min_qword:
                 lInstruction.condition := C_B;
               in_max_longint,
               in_max_int64:
                 lInstruction.condition := C_G;
               in_max_dword,
               in_max_qword:
                 lInstruction.condition := C_A;
               else
                 InternalError(2021121903);
             end;

             cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
           end
         else
           InternalError(2020120503);
      end;


end.
