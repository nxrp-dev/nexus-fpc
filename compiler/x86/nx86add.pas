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
        function  GetResFlags(AUnsigned : Boolean) : TResFlags;
        function  GetFPUResFlags : TResFlags;
        procedure Left_Must_Be_Reg(AOpDef: TDef; AOpSize:TCgSize;ANoSwap:Boolean);
        procedure Force_Left_And_Right_FPUReg;
        procedure Prepare_X87_Locations(out AReferenceNode: TNode);
        procedure Emit_Op_Right_Left(AAsmOp:TAsmOp;AOpSize:TCgSize;AAllocFlags:Boolean);
        procedure Emit_Generic_Code(AAsmOp:TAsmOp;AOpSize:TCgSize;AUnsigned,AExtraNot,AMultiplyOverflow:Boolean);

        procedure Second_CmpFloatVector;

        procedure Second_AddFloatSSE;
        procedure Second_AddFloatAVX;
      public
        function Pass_1 : TNode;override;
        function Simplify(AForInline : Boolean) : TNode; override;
        function Use_FMA : Boolean;override;
        procedure Second_AddFloat;override;

        procedure Second_AddSmallSet;override;
        procedure Second_AddSmallSetElement;override;

        procedure Second_Add64Bit;override;
        procedure Second_CmpFloat;override;
        procedure Second_CmpSmallSet;override;
        procedure Second_Cmp64Bit;override;

        procedure Second_CmpOrdinal;override;
        procedure Second_AddOrdinal;override;
        procedure Second_AddBoolean;override;
        procedure Second_OpVector;override;
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
      Pass_1,pass_2,htypechk;

{ Range check must be disabled explicitly as the code serves
  on three different architecture sizes }
{$R-}

{*****************************************************************************
                                  Helpers
*****************************************************************************}

    procedure TX86AddNode.Emit_Generic_Code(AAsmOp:TAsmOp;AOpSize:TCgSize;AUnsigned,AExtraNot,AMultiplyOverflow:Boolean);
      var
        lPower : LongInt;
        lOverflowLabel   : TAsmLabel;
        lScratchReg     : TRegister;
        lReference  : TReference;
        lOverflowCheck: Boolean;
        lComparison: Boolean;
      begin
        lOverflowCheck:=NeedOverflowCheck;
        lComparison:=
          (AAsmOp=A_CMP) or (AAsmOp=A_TEST) or (AAsmOp=A_BT) or Is_Boolean(ResultDef);

        { at this point, left.location.loc should be LOC_REGISTER }
        if Right.Location.Loc=LOC_REGISTER then
         begin
           { right.location is a LOC_REGISTER }
           { when swapped another result register }
           if (NodeType=subn) and (nf_swapped in Flags) then
            begin
              if AExtraNot then
               emit_reg(A_NOT,TCGSize2Opsize[AOpSize],Left.Location.Register);
              emit_reg_reg(AAsmOp,TCGSize2Opsize[AOpSize],Left.Location.Register,Right.Location.Register);
              { newly swapped also set swapped flag }
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
            end
           else
            begin
              if AExtraNot then
                emit_reg(A_NOT,TCGSize2Opsize[AOpSize],Right.Location.Register);
              if (AAsmOp=A_ADD) or (AAsmOp=A_OR) or (AAsmOp=A_AND) or (AAsmOp=A_XOR) or (AAsmOp=A_IMUL) then
                Location_Swap(Left.Location,Right.Location);

              if lComparison then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              emit_reg_reg(AAsmOp,TCGSize2Opsize[AOpSize],Right.Location.Register,Left.Location.Register);
            end;
         end
        else
         begin
           { right.location is not a LOC_REGISTER }
           if (NodeType=subn) and (nf_swapped in Flags) then
            begin
              if AExtraNot then
                cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,AOpSize,Left.Location.Register,Left.Location.Register);
              lScratchReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,AOpSize);
              hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,CGSize_OrdDef(AOpSize),Right.Location,lScratchReg);

              if lComparison then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              emit_reg_reg(AAsmOp,TCGSize2Opsize[AOpSize],Left.Location.Register,lScratchReg);
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,AOpSize,AOpSize,lScratchReg,Left.Location.Register);
            end
           else
            begin
               { Optimizations when right.location is a constant value }
               if (AAsmOp=A_CMP) and
                  (NodeType in [EqualN,unequaln]) and
                  (Right.Location.Loc=LOC_CONSTANT) and
                  (Right.Location.Value=0) then
                 begin
                   { 'test $-1,%reg' is transformable into 'test $-1,spilltemp' if %reg needs
                      spilling, while 'test %reg,%reg' still requires loading into register.
                      If spilling is not necessary, it is changed back into 'test %reg,%reg' by
                      peephole optimizer (this optimization is currently available only for i386). }
                   cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$ifdef i386}
                   emit_const_reg(A_TEST,TCGSize2Opsize[AOpSize],aint(-1),Left.Location.Register)
{$else i386}
                   emit_reg_reg(A_TEST,TCGSize2Opsize[AOpSize],Left.Location.Register,Left.Location.Register);
{$endif i386}
                 end
               else
                 if (AAsmOp=A_ADD) and
                    (Right.Location.Loc=LOC_CONSTANT) and
                    (Right.Location.Value=1) and
                    not lOverflowCheck and
                    UseIncDec then
                  begin
                    emit_reg(A_INC,TCGSize2Opsize[AOpSize],Left.Location.Register);
                  end
               else
                 if (AAsmOp=A_SUB) and
                    (Right.Location.Loc=LOC_CONSTANT) and
                    (Right.Location.Value=1) and
                    not lOverflowCheck and
                    UseIncDec then
                  begin
                    emit_reg(A_DEC,TCGSize2Opsize[AOpSize],Left.Location.Register);
                  end
               else
                 if (AAsmOp=A_IMUL) and
                    (Right.Location.Loc=LOC_CONSTANT) and
                    (IsPowerOf2(Int64(Right.Location.Value),lPower)) and
                    lOverflowCheck then
                  begin
                    emit_const_reg(A_SHL,TCGSize2Opsize[AOpSize],lPower,Left.Location.Register);
                  end
                else if (AAsmOp=A_IMUL) and
                    (Right.Location.Loc=LOC_CONSTANT) and
                    (Right.Location.Value>1) and (IsPowerOf2(Int64(Right.Location.Value)-1,lPower)) and
                    (lPower in [1..3]) and
                    not lOverflowCheck then
                  begin
                    Reference_Reset_Base(lReference,Left.Location.Register,0,CTempPosInvalid,0,[]);
                    lReference.Index:=Left.Location.Register;
                    lReference.ScaleFactor:=Int64(Right.Location.Value)-1;
                    Left.Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,AOpSize);
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[AOpSize],lReference,Left.Location.Register));
                  end
               else
                 begin
                   if AExtraNot then
                     begin
                        lScratchReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,AOpSize);
                        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,CGSize_OrdDef(AOpSize),Right.Location,lScratchReg);
                        emit_reg(A_NOT,TCGSize2Opsize[AOpSize],lScratchReg);

                        if lComparison or (AMultiplyOverflow and lOverflowCheck) then
                          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                        emit_reg_reg(A_AND,TCGSize2Opsize[AOpSize],lScratchReg,Left.Location.Register);
                     end
                   else
                     Emit_Op_Right_Left(AAsmOp,AOpSize,lComparison or (AMultiplyOverflow and lOverflowCheck));
                 end;
            end;
         end;

        { only in case of overflow operations }
        { produce overflow code }
        { we must put it here directly, because sign of operation }
        { is in unsigned VAR!!                                   }
        if AMultiplyOverflow then
         begin
           if lOverflowCheck then
            begin
              CurrentAsmData.getjumplabel(lOverflowLabel);
              if AUnsigned then
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,lOverflowLabel)
              else
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,lOverflowLabel);

              if not lComparison then
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,lOverflowLabel);
            end;
         end;
      end;


    procedure TX86AddNode.Left_Must_Be_Reg(AOpDef: TDef; AOpSize:TCgSize;ANoSwap:Boolean);
      begin
        { left location is not a register? }
        if (Left.Location.Loc<>LOC_REGISTER) then
         begin
           { if right is register then we can swap the locations }
           if (not ANoSwap) and
              (Right.Location.Loc=LOC_REGISTER) then
            begin
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
            end
           else if (not ANoSwap) and
              (Right.Location.Loc=LOC_CREGISTER) then
            begin
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
              { maybe we can reuse a constant register when the
                operation is a comparison that doesn't change the
                value of the register }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,AOpDef,(NodeType in [ltn,lten,gtn,gten,EqualN,unequaln]));
              Location:=Left.Location;
            end
           else
            begin
              { maybe we can reuse a constant register when the
                operation is a comparison that doesn't change the
                value of the register }
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,AOpDef,(NodeType in [ltn,lten,gtn,gten,EqualN,unequaln]));
            end;
          end;
        if (Right.Location.Loc<>LOC_CONSTANT) and
           (TCgSize2Unsigned[Right.Location.Size]<>TCgSize2Unsigned[AOpSize]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,AOpDef,true);
        if (Left.Location.Loc<>LOC_CONSTANT) and
           (TCgSize2Unsigned[Left.Location.Size]<>TCgSize2Unsigned[AOpSize]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,AOpDef,false);
       end;


    procedure TX86AddNode.Force_Left_And_Right_FPUReg;
      begin
        if (Right.Location.Loc<>LOC_FPUREGISTER) then
          begin
            hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,false);
            if (Left.Location.Loc<>LOC_FPUREGISTER) then
              hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false)
            else
              { left was on the stack => swap }
              ToggleFlag(nf_swapped);
          end
        { the nominator in st0 }
        else if (Left.Location.Loc<>LOC_FPUREGISTER) then
          begin
            hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false)
          end
        else
          begin
            { fpu operands are always in the wrong order on the stack }
            ToggleFlag(nf_swapped);
          end;
      end;


    { Makes sides suitable for executing an x87 instruction:
      if either side is OS_F32/OS_F64-sized LOC_REFERENCE, it is returned in 'refnode'
      everything else is loaded to FPU stack. }
    procedure TX86AddNode.Prepare_X87_Locations(out AReferenceNode: TNode);
      begin
        AReferenceNode:=nil;

        { later on, no mm registers are allowed, so transfer everything to memory here
          below it is loaded into an fpu register if needed }
        if Left.Location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);

        if Right.Location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef);

        case ord(Left.Location.Loc=LOC_FPUREGISTER)+ord(Right.Location.Loc=LOC_FPUREGISTER) of
          0:
            begin
              hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,false);
              if not(Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                InternalError(2013090803);
              if (Left.Location.Size in [OS_F32,OS_F64]) then
                begin
                  AReferenceNode:=Left;
                  ToggleFlag(nf_swapped);
                end
              else
                hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
            end;
          1:
            begin   { if left is on the stack then swap. }
              if (Left.Location.Loc=LOC_FPUREGISTER) then
                AReferenceNode:=Right
              else
                AReferenceNode:=Left;
              if not(AReferenceNode.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                InternalError(2013090801);
              if not (AReferenceNode.Location.Size in [OS_F32,OS_F64]) then
                begin
                  hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,AReferenceNode.Location,AReferenceNode.ResultDef,false);
                  if (AReferenceNode=Right) then
                    ToggleFlag(nf_swapped);
                  AReferenceNode:=nil;
                end
              else
                begin
                  if (AReferenceNode=Left) then
                    ToggleFlag(nf_swapped);
                end;
            end;
          2: { fpu operands are always in the wrong order on the stack }
            ToggleFlag(nf_swapped);
        else
          InternalError(2013090802);
        end;
      end;


    procedure TX86AddNode.Emit_Op_Right_Left(AAsmOp:TAsmOp;AOpSize:TCgSize;AAllocFlags:Boolean);
{$ifdef x86_64}
      var
        lTempReg : TRegister;
{$endif x86_64}
      begin
        if (Right.Location.Loc in [LOC_CSUBSETREG,LOC_SUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,Right.ResultDef,true);
        { left must be a register }
        case Right.Location.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              if AAllocFlags then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(AAsmOp,TCGSize2Opsize[AOpSize],Right.Location.Register,Left.Location.Register));
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Right.Location.Reference);
              if AAllocFlags then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(AAsmOp,TCGSize2Opsize[AOpSize],Right.Location.Reference,Left.Location.Register));
            end;
          LOC_CONSTANT :
            begin
{$ifdef x86_64}
              { x86_64 only supports signed 32 bits constants directly }
              if (AOpSize in [OS_S64,OS_64]) and
                 ((Right.Location.Value<low(LongInt)) or (Right.Location.Value>high(LongInt))) then
                begin
                  lTempReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,AOpSize);
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,AOpSize,Right.Location.Value,lTempReg);
                  if AAllocFlags then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(AAsmOp,TCGSize2Opsize[AOpSize],lTempReg,Left.Location.Register));
                end
              else
{$endif x86_64}
                begin
                  if AAllocFlags then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(AAsmOp,TCGSize2Opsize[AOpSize],Right.Location.Value,Left.Location.Register));
                end;
            end;
          else
            InternalError(200203232);
        end;
      end;


    function TX86AddNode.GetResFlags(AUnsigned : Boolean) : TResFlags;
      begin
         case NodeType of
           EqualN : GetResFlags:=F_E;
           unequaln : GetResFlags:=F_NE;
          else
           if not(AUnsigned) then
             begin
                if nf_swapped in Flags then
                  case NodeType of
                     ltn : GetResFlags:=F_G;
                     lten : GetResFlags:=F_GE;
                     gtn : GetResFlags:=F_L;
                     gten : GetResFlags:=F_LE;
                     else
                       InternalError(2013120105);
                  end
                else
                  case NodeType of
                     ltn : GetResFlags:=F_L;
                     lten : GetResFlags:=F_LE;
                     gtn : GetResFlags:=F_G;
                     gten : GetResFlags:=F_GE;
                     else
                       InternalError(2013120106);
                  end;
             end
           else
             begin
                if nf_swapped in Flags then
                  case NodeType of
                     ltn : GetResFlags:=F_A;
                     lten : GetResFlags:=F_AE;
                     gtn : GetResFlags:=F_B;
                     gten : GetResFlags:=F_BE;
                     else
                       InternalError(2013120107);
                  end
                else
                  case NodeType of
                     ltn : GetResFlags:=F_B;
                     lten : GetResFlags:=F_BE;
                     gtn : GetResFlags:=F_A;
                     gten : GetResFlags:=F_AE;
                     else
                       InternalError(2013120108);
                  end;
             end;
         end;
      end;


    function TX86AddNode.GetFPUResFlags : TResFlags;
      begin
        if (NodeType=EqualN) then
          Result:=F_FE
        else if (NodeType=unequaln) then
          Result:=F_FNE
        else if (nf_swapped in Flags) then
          case NodeType of
            ltn : Result:=F_FA;
            lten : Result:=F_FAE;
            gtn : Result:=F_FB;
            gten : Result:=F_FBE;
          else
            InternalError(2014031402);
          end
        else
          case NodeType of
            ltn : Result:=F_FB;
            lten : Result:=F_FBE;
            gtn : Result:=F_FA;
            gten : Result:=F_FAE;
          else
            InternalError(2014031403);
          end;
      end;

{*****************************************************************************
                                AddSmallSet
*****************************************************************************}


    procedure TX86AddNode.Second_AddSmallSet;
      var
        lSetBase : aint;
        lOpDef  : TDef;
        lOpSize : TCgSize;
        lAsmOp     : TAsmOp;
        lExtraNot,
        lNoSwap : Boolean;
        lAllMemberOptimization:Boolean;

      begin
        Pass_Left_Right;

        lNoSwap:=false;
        lExtraNot:=false;
        lAllMemberOptimization:=false;
        lOpDef:=ResultDef;
        lOpSize:=Int_CGSize(lOpDef.Size);
        if (Left.ResultDef.typ=setdef) then
          lSetBase:=TSetDef(Left.ResultDef).SetBase
        else
          lSetBase:=TSetDef(Right.ResultDef).SetBase;
        case NodeType of
          addn :
            begin
              { adding elements is not commutative }
              if (nf_swapped in Flags) and (Left.NodeType=setelementn) then
               SwapLeftRight;
              { are we adding set elements ? }
              if Right.NodeType=setelementn then
               begin
                 { no range support for smallsets! }
                 if Assigned(TSetElementNode(Right).Right) then
                   InternalError(43244);
                 { btsb isn't supported }
                 if lOpSize=OS_8 then
                   begin
                     lOpSize:=OS_32;
                     lOpDef:=U32IntType;
                   end;
                 { bts requires both elements to be registers }
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,lOpDef,true);
                 Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,lOpDef,Right.Location,lSetBase);
                 lAsmOp:=A_BTS;
                 lNoSwap:=true;
               end
              else
               lAsmOp:=A_OR;
            end;
          symdifn :
            lAsmOp:=A_XOR;
          muln :
            lAsmOp:=A_AND;
          subn :
            begin
              lAsmOp:=A_AND;
              if (not(nf_swapped in Flags) and (Left.Location.Loc=LOC_CONSTANT) and (Left.Location.Value=-1)) or
                  ((nf_swapped in Flags) and (Right.Location.Loc=LOC_CONSTANT) and (Right.Location.Value=-1)) then
                lAllMemberOptimization:=true;

              if (not(nf_swapped in Flags)) and
                 (Right.Location.Loc=LOC_CONSTANT) then
                Right.Location.Value := not(Right.Location.Value)
              else if (nf_swapped in Flags) and
                      (Left.Location.Loc=LOC_CONSTANT) then
                Left.Location.Value := not(Left.Location.Value)
              else
                lExtraNot:=true;
            end;
          xorn :
            lAsmOp:=A_XOR;
          orn :
            lAsmOp:=A_OR;
          andn :
            lAsmOp:=A_AND;
          else
            InternalError(2003042215);
        end;
        if lAllMemberOptimization then
          begin
            {A set expression [0..31]-x can be implemented with a simple NOT.}
            if nf_swapped in Flags then
              begin
                { newly swapped also set swapped flag }
                Location_Swap(Left.Location,Right.Location);
                ToggleFlag(nf_swapped);
              end;
            hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,Right.Location,Right.ResultDef,lOpDef,false);
            emit_reg(A_NOT,TCGSize2Opsize[lOpSize],Right.Location.Register);
            Location:=Right.Location;
          end
        else
          begin
            { can we use the BMI1 instruction andn? }
            if (lAsmOp=A_AND) and lExtraNot and (CPUX86_HAS_BMI1 in cpu_capabilities[CurrentSettings.CPUType]) and
              (ResultDef.Size in [4{$ifdef x86_64},8{$endif x86_64}]) then
              begin
                Location_Reset(Location,LOC_REGISTER,Left.Location.Size);
                Location.Register:=cg.GetIntRegister(CurrentAsmData.currAsmList,Left.Location.Size);
                if nf_swapped in Flags then
                  begin
                    Location_Swap(Left.Location,Right.Location);
                    ToggleFlag(nf_swapped);
                  end;
                hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,Right.Location,Right.ResultDef,lOpDef,true);
                if not(Left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_Reg(CurrentAsmData.currAsmList,Left.Location,Left.ResultDef,lOpDef,true);
                case Left.Location.Loc of
                  LOC_CREGISTER,LOC_REGISTER:
                    emit_reg_reg_reg(A_ANDN,TCGSize2Opsize[lOpSize],Left.Location.Register,Right.Location.Register,Location.Register);
                  LOC_CREFERENCE,LOC_REFERENCE:
                    emit_ref_reg_reg(A_ANDN,TCGSize2Opsize[lOpSize],Left.Location.Reference,Right.Location.Register,Location.Register);
                  else
                    InternalError(2018040201);
                end;
              end
            else
              begin
                { left must be a register }
                Left_Must_Be_Reg(lOpDef,lOpSize,lNoSwap);
                Emit_Generic_Code(lAsmOp,lOpSize,true,lExtraNot,false);
                Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);

                { left is always a register and contains the result }
                Location:=Left.Location;
              end;
          end;

        { fix the changed opsize we did above because of the missing btsb }
        if lOpSize<>Int_CGSize(ResultDef.Size) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,lOpDef,CGSize_OrdDef(Int_CGSize(ResultDef.Size)),false);
      end;


    procedure TX86AddNode.Second_AddSmallSetElement;
      var
        lSetBase, lMask: aint;
      begin
        if ResultDef.Size=1 then
          inherited Second_AddSmallSetElement
        else
          begin
            if NodeType<>addn then
              InternalError(2022090502);
            { no range support for smallsets }
            if Assigned(TSetElementNode(Right).Right) then
              InternalError(2022090501);
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
                lMask:=aint(1 shl (Right.Location.Value-lSetBase));
                hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,ResultDef,
                  lMask,Left.Location.Register,Location.Register);
              end
            else
              begin
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,ResultDef,true);
                Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,ResultDef,Right.Location,lSetBase);
                if Left.Location.Loc <> LOC_CONSTANT then
                  hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,
                      Left.Location.Register,Location.Register)
                else
                  hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,
                      Left.Location.Value,Location.Register);
                emit_reg_reg(A_BTS,TCGSize2Opsize[Def_CGSize(ResultDef)],Right.Location.Register,Location.Register);
              end;
          end;
      end;



    procedure TX86AddNode.Second_CmpSmallSet;
      var
        lOpDef  : TDef;
        lOpSize : TCgSize;
        lAsmOp     : TAsmOp;
      begin
        Pass_Left_Right;
        lOpDef:=Left.ResultDef;
        lOpSize:=Int_CGSize(lOpDef.Size);
        case NodeType of
          EqualN,
          unequaln :
            lAsmOp:=A_CMP;
          lten,gten:
            begin
              if (not(nf_swapped in Flags) and (NodeType = lten)) or
                 ((nf_swapped in Flags) and (NodeType = gten)) then
                SwapLeftRight;
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
              Emit_Op_Right_Left(A_AND,lOpSize,False);
              lAsmOp:=A_CMP;
              { warning: ugly hack, we need a JE so change the node to equaln }
              NodeType:=EqualN;
            end;
          else
            InternalError(2003042204);
        end;
        { left must be a register }
        Left_Must_Be_Reg(lOpDef,lOpSize,false);
        Emit_Generic_Code(lAsmOp,lOpSize,true,false,false);
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);

        Location_Reset(Location,LOC_FLAGS,OS_NO);
        Location.ResFlags:=GetResFlags(true);
      end;


{*****************************************************************************
                                AddFloat
*****************************************************************************}

    procedure TX86AddNode.Second_AddFloatSSE;
      var
        lCGOp : TOpCG;
        lSquareSum : Boolean;
        lTempNode : TNode;
      begin
        lSquareSum:=false;
        if (CurrentSettings.FPUType>=fpu_sse3) and
           Use_VectorFPU(ResultDef) and
           (NodeType in [addn,subn]) and
          (Left.NodeType=inlinen) and (TInlineNode(Left).InlineNumber=in_sqr_real) and
          (Right.NodeType=inlinen) and (TInlineNode(Right).InlineNumber=in_sqr_real) then
          begin
            lSquareSum:=true;
            lTempNode:=TInlineNode(Left).Left;
            TInlineNode(Left).Left:=nil;
            Left.free;
            Left:=lTempNode;

            lTempNode:=TInlineNode(Right).Left;
            TInlineNode(Right).Left:=nil;
            Right.free;
            Right:=lTempNode;
          end;

        Pass_Left_Right;
        { fpu operands are always in reversed order on the stack }
        if (Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          ToggleFlag(nf_swapped);

        if (nf_swapped in Flags) then
          { can't use swapleftright if both are on the fpu stack, since then }
          { both are "R_ST" -> nothing would change -> manually switch       }
          if (Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
             (Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            emit_none(A_FXCH,S_NO)
          else
            SwapLeftRight;

        case NodeType of
          addn :
            lCGOp:=OP_ADD;
          muln :
            lCGOp:=OP_MUL;
          subn :
            lCGOp:=OP_SUB;
          slashn :
            lCGOp:=OP_DIV;
          else
            InternalError(200312231);
        end;

        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));

        if lSquareSum then
          begin
            if nf_swapped in Flags then
              SwapLeftRight;

            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,true);
            Location:=Left.Location;
            if Is_Double(ResultDef) then
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,Right.Location.Register,Location.Register));
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPD,S_NO,Location.Register,Location.Register));
                case NodeType of
                  addn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPD,S_NO,Location.Register,Location.Register));
                  subn:
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPD,S_NO,Location.Register,Location.Register));
                  else
                    InternalError(201108162);
                end;
              end
            else
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_UNPCKLPS,S_NO,Right.Location.Register,Location.Register));
                { ensure that bits 64..127 contain valid values }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(A_SHUFPD,S_NO,%00,Location.Register,Location.Register));
                { the data is now in bits 0..32 and 64..95 }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MULPS,S_NO,Location.Register,Location.Register));
                case NodeType of
                  addn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HADDPS,S_NO,Location.Register,Location.Register));
                    end;
                  subn:
                    begin
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_HSUBPS,S_NO,Location.Register,Location.Register));
                    end;
                  else
                    InternalError(201108163);
                end;
              end
          end
        { we can use only right as left operand if the operation is commutative }
        else if (Right.Location.Loc=LOC_MMREGISTER) and (lCGOp in [OP_ADD,OP_MUL]) then
          begin
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            cg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Right.Location.Size,Location.Size,Right.Location.Register,Location.Register,MMS_MoveScalar);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
            cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,Left.Location,Location.Register,MMS_MoveScalar);

            if Left.Location.Loc=LOC_REFERENCE then
              TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,Left.Location.Reference);
          end
        else
          begin
            if nf_swapped in Flags then
              SwapLeftRight;

            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);

            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            cg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,Location.Size,Left.Location,Location.Register,MMS_MoveScalar);

            if Left.Location.Loc=LOC_REFERENCE then
              TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,Left.Location.Reference);

            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef);

            cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,Right.Location,Location.Register,MMS_MoveScalar);

            if Right.Location.Loc=LOC_REFERENCE then
              TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,Right.Location.Reference);
          end;
      end;


    procedure TX86AddNode.Second_AddFloatAVX;
      var
        lCGOp : TOpCG;
      begin
        Pass_Left_Right;
        { fpu operands are always in reversed order on the stack }
        if (Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          ToggleFlag(nf_swapped);

        if (nf_swapped in Flags) then
          { can't use swapleftright if both are on the fpu stack, since then }
          { both are "R_ST" -> nothing would change -> manually switch       }
          if (Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and
             (Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            emit_none(A_FXCH,S_NO)
          else
            SwapLeftRight;

        case NodeType of
          addn :
            lCGOp:=OP_ADD;
          muln :
            lCGOp:=OP_MUL;
          subn :
            lCGOp:=OP_SUB;
          slashn :
            lCGOp:=OP_DIV;
          else
            InternalError(2003122303);
        end;

        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));

        { left*2 ? }
        if (NodeType=muln) and Is_ConstRealNode(Right) and Is_Number_Float(TRealConstNode(Right).ValueReal) and (TRealConstNode(Right).ValueReal=2) then
          begin
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
            cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,Location.Size,
              Left.Location.Register,
              Left.Location.Register,
              Location.Register,
              MMS_MoveScalar);
          end
        { right*2 ? }
        else if (NodeType=muln) and Is_ConstRealNode(Left) and Is_Number_Float(TRealConstNode(Left).ValueReal) and (TRealConstNode(Left).ValueReal=2) then
          begin
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Right.Location.Size);
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,true);
            cg.A_OpMM_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,Location.Size,
              Right.Location.Register,
              Right.Location.Register,
              Location.Register,
              MMS_MoveScalar);
          end
        { we can use only right as left operand if the operation is commutative }
        else if (Right.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) and (lCGOp in [OP_ADD,OP_MUL]) then
          begin
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
            cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
              Left.Location,
              Right.Location.Register,
              Location.Register,
              MMS_MoveScalar);
          end
        else
          begin
            if (nf_swapped in Flags) then
              SwapLeftRight;

            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
            { force floating point reg. location to be written to memory,
              we don't force it to mm register because writing to memory
              allows probably shorter code because there is no direct fpu->mm register
              copy instruction
            }
            if Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef);
            cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
              Right.Location,
              Left.Location.Register,
              Location.Register,
              MMS_MoveScalar);
          end;
      end;


    function TX86AddNode.Pass_1: TNode;
      begin
        { only pass_1 might set the resultdef as it could be set to nil by some previous
          code transformation. As we need a valid left/right.resultdef later on, ensure
          a valid result def is set, see also issue #40727 }
        if not(Assigned(Left.ResultDef)) then
          TypeCheckPass(Left);
        if not(Assigned(Right.ResultDef)) then
          TypeCheckPass(Right);

        { on x86, we do not support fpu registers, so in case of operations using the x87, it
          is normally useful, not to put the operands into registers which would be mm register

          this should be called before pass_1 so we have a proper expectloc }
        if ((Left.ResultDef.typ=floatdef) or (Right.ResultDef.typ=floatdef)) and
          (not(Use_VectorFPU(Left.ResultDef)) and not(Use_VectorFPU(Right.ResultDef)) and
           not(Use_VectorFPU(ResultDef))) then
          begin
            Make_Not_Regable(Left,[ra_addr_regable]);
            Make_Not_Regable(Right,[ra_addr_regable]);
          end;
        Result:=inherited Pass_1;
        { correct expectloc, it does not matter of Result is set as another pass_1 is run on it
          which will fix that one }
        if Use_VectorFPU(ResultDef) then
          ExpectLoc:=LOC_MMREGISTER;
      end;


    function TX86AddNode.Simplify(AForInline : Boolean) : TNode;
      var
        lResultNode, lMultiplyNode, lThisNode, lConstNode: TNode;
        lLeftNodeType,lRightNodeType, lThisType: TNodeType;
        lThisDef: TDef;
        lDoOptimization: Boolean;

        lReciprocal, lComparison, lDivisor: AWord;
        lShift, lIndex: Byte;
      begin
        { Load into local variables to reduce the number of pointer deallocations }
        lRightNodeType:=Right.NodeType;
        lLeftNodeType:=Left.NodeType;

        lDoOptimization:=False;

{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
        if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
          { The presence of overflow checks tends to cause internal errors with the multiplication nodes }
          not (cs_check_overflow in CurrentSettings.LocalSwitches) and
          (NodeType in [EqualN,unequaln]) then
          begin
            if (lLeftNodeType=modn) and (lRightNodeType=ordconstn) and (TOrdConstNode(Right).Value.uvalue=0) then
              begin
                lResultNode:=Left;
                lMultiplyNode:=Right;
              end
            else if (lRightNodeType=modn) and (lLeftNodeType=ordconstn) and (TOrdConstNode(Left).Value.uvalue=0) then
              begin
                lResultNode:=Right;
                lMultiplyNode:=Left;
              end
            else
              begin
                lResultNode:=nil;
                lMultiplyNode:=nil;
              end;

            if Assigned(lResultNode) and (TModDivNode(lResultNode).Right.NodeType=ordconstn) and
{$ifndef cpu64bitalu}
              { Converting Int64 and QWord division doesn't work under i386 }
{$ifndef cpu32bitalu}
              (TModDivNode(lResultNode).ResultDef.Size < 4) and
{$else cpu32bitalu}
              (TModDivNode(lResultNode).ResultDef.Size < 8) and
{$endif cpu32bitalu}
{$endif cpu64bitalu}
              (TOrdConstNode(TModDivNode(lResultNode).Right).Value>=3) then
              begin
                lDivisor:=TOrdConstNode(TModDivNode(lResultNode).Right).Value.uvalue;

                { Exclude powers of 2, as there are more efficient ways to handle those }
                if PopCnt(lDivisor)>1 then
                  begin
                    if Is_Signed(TModDivNode(lResultNode).Left.ResultDef) then
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
                            lThisNode:=TModDivNode(lResultNode).Left;
                            case lThisNode.NodeType of
                              typeconvn:
                                begin
                                  lThisDef:=TTypeConvNode(lThisNode).Left.ResultDef;
                                  { See if we can simplify things to a smaller ordinal to
                                    reduce code size and increase speed }
                                  if Is_Signed(lThisDef) and
                                    Is_Integer(lThisDef) and
                                    { Byte-sized multiplications can cause problems }
                                    (lThisDef.Size>=2) and
                                    { Make sure the divisor is in range }
                                    (lDivisor>=TOrdDef(lThisDef).low) and
                                    (lDivisor<=TOrdDef(lThisDef).high) then
                                    begin
                                      TOrdConstNode(TModDivNode(lResultNode).Right).ResultDef:=lThisDef;
                                      TOrdConstNode(lMultiplyNode).ResultDef:=lThisDef;
                                      TModDivNode(lResultNode).ResultDef:=lThisDef;

                                      { Destroy the typeconv node }
                                      TModDivNode(lResultNode).Left:=TTypeConvNode(lThisNode).Left;
                                      TTypeConvNode(lThisNode).Left:=nil;
                                      lThisNode.Free;
                                      Continue;
                                    end;
                                  end;
                              ordconstn:
                                begin
                                  { Just simplify into a constant }
                                  Result:=inherited Simplify(AForInline);
                                  Exit;
                                end;
                              else
                                ;
                            end;

                            lDoOptimization:=True;
                            Break;
                          end;

                        if lDoOptimization then
                          begin
                            lThisDef:=TModDivNode(lResultNode).Left.ResultDef;

                            if NodeType = EqualN then
                              lThisType:=lten
                            else
                              lThisType:=gtn;

                            lIndex:=lThisDef.Size*8;
                            Calc_Mul_Inverse(lIndex, TOrdConstNode(TModDivNode(lResultNode).Right).Value.uvalue, lReciprocal, lShift);

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

                            lThisNode:=CTypeConvNode.Create_Internal(TModDivNode(lResultNode).Left, lThisDef);
                            TTypeConvNode(lThisNode).ConvType:=tc_int_2_int;
                            lThisDef:=Get_Unsigned_IntType(lThisDef);
                            lThisNode.ResultDef:=lThisDef;

                            TModDivNode(lResultNode).Left:=nil;

                            lConstNode:=COrdConstNode.Create(lReciprocal, lThisDef, False);
                            lConstNode.ResultDef:=lThisDef;

                            lThisNode:=CAddNode.Create_Internal(muln, lThisNode, lConstNode);
                            lThisNode.ResultDef:=lThisDef;

{$push}
{$warnings off}
                            if lShift>0 then
                              lComparison:=((AWord(1) shl ((lIndex-1) and (SizeOf(AWord)*8-1))) div (lDivisor shr lShift)) and -(1 shl lShift)
                            else
                              lComparison:=(AWord(1) shl ((lIndex-1) and (SizeOf(AWord)*8-1))) div lDivisor;
{$pop}
                            lConstNode:=COrdConstNode.Create(lComparison, lThisDef, False);
                            lConstNode.ResultDef:=lThisDef;

                            lThisNode:=CAddNode.Create_Internal(addn, lThisNode, lConstNode);
                            lThisNode.ResultDef:=lThisDef;

                            if lShift>0 then
                              begin
                                lConstNode:=COrdConstNode.Create(lShift, U8IntType, False);
                                lConstNode.ResultDef:=U8IntType;
                                lThisNode:=CInlineNode.CreateIntern(in_ror_x_y,false,
                                  CCallParaNode.Create(lConstNode,
                                  CCallParaNode.Create(lThisNode, nil)));

                                lThisNode.ResultDef:=lThisDef;

                                lConstNode:=COrdConstNode.Create(lComparison shr (lShift - 1), lThisDef, False);
                              end
                            else
                              lConstNode:=COrdConstNode.Create(lComparison*2, lThisDef, False);

                            lConstNode.ResultDef:=lThisDef;

                            Result:=CAddNode.Create_Internal(lThisType, lThisNode, lConstNode);
                            Result.ResultDef:=ResultDef;
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
                            lThisNode:=TModDivNode(lResultNode).Left;
                            case lThisNode.NodeType of
                              typeconvn:
                                begin
                                  lThisDef:=TTypeConvNode(lThisNode).Left.ResultDef;
                                  { See if we can simplify things to a smaller ordinal to
                                    reduce code size and increase speed }
                                  if not Is_Signed(lThisDef) and
                                    Is_Integer(lThisDef) and
                                    { Byte-sized multiplications can cause problems }
                                    (lThisDef.Size>=2) and
                                    { Make sure the divisor is in range }
                                    (lDivisor>=TOrdDef(lThisDef).low) and
                                    (lDivisor<=TOrdDef(lThisDef).high) then
                                    begin
                                      TOrdConstNode(TModDivNode(lResultNode).Right).ResultDef:=lThisDef;
                                      TOrdConstNode(lMultiplyNode).ResultDef:=lThisDef;
                                      TModDivNode(lResultNode).ResultDef:=lThisDef;

                                      { Destroy the typeconv node }
                                      TModDivNode(lResultNode).Left:=TTypeConvNode(lThisNode).Left;
                                      TTypeConvNode(lThisNode).Left:=nil;
                                      lThisNode.Free;
                                      Continue;
                                    end;
                                  end;
                              ordconstn:
                                begin
                                  { Just simplify into a constant }
                                  Result:=inherited Simplify(AForInline);
                                  Exit;
                                end;
                              else
                                ;
                            end;

                            lDoOptimization:=True;
                            Break;
                          end;

                        if lDoOptimization then
                          begin
                            lThisDef:=TModDivNode(lResultNode).Left.ResultDef;

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

                            if NodeType=EqualN then
                              lThisType:=lten
                            else
                              lThisType:=gtn;

                            lIndex:=lThisDef.Size*8;
                            Calc_Mul_Inverse(lIndex, TOrdConstNode(TModDivNode(lResultNode).Right).Value.uvalue, lReciprocal, lShift);

                            lConstNode:=COrdConstNode.Create(lReciprocal, lThisDef, False);
                            lConstNode.ResultDef:=lThisDef;

                            lThisNode:=CAddNode.Create_Internal(muln, TModDivNode(lResultNode).Left, lConstNode);
                            lThisNode.ResultDef:=lThisDef;

                            TModDivNode(lResultNode).Left:=nil;

                            if lShift>0 then
                              begin
                                lConstNode:=COrdConstNode.Create(lShift, U8IntType, False);
                                lConstNode.ResultDef:=U8IntType;
                                lThisNode:=CInlineNode.CreateIntern(in_ror_x_y,false,
                                  CCallParaNode.Create(lConstNode,
                                  CCallParaNode.Create(lThisNode, nil)));

                                lThisNode.ResultDef:=lThisDef;

                                lComparison:=(AWord(1) shl ((lIndex-lShift) and (SizeOf(AWord)*8-1))) div (lDivisor shr lShift);
                              end
                            else
                              begin
{$push}
{$warnings off}
                                { Because 2^N and divisor are relatively prime,
                                  floor(2^N / divisor) = floor((2^N - 1) / divisor) }
                                lComparison:=(AWord(not 0) shr (((SizeOf(AWord)*8)-lIndex) and (SizeOf(AWord)*8-1))) div lDivisor;
{$pop}
                              end;

                            lConstNode:=COrdConstNode.Create(lComparison, lThisDef, False);
                            lConstNode.ResultDef:=lThisDef;

                            Result:=CAddNode.Create_Internal(lThisType, lThisNode, lConstNode);
                            Result.ResultDef:=ResultDef;
                            Exit;
                          end;
                      end;
                  end;
              end;
          end;
{$ifend defined(cpu64bitalu) or defined(cpu32bitalu)}
        Result:=inherited Simplify(AForInline);
      end;


    function TX86AddNode.Use_FMA : Boolean;
      begin

        { test if the result stays in an xmm register, fiddeling with fpu registers and fma makes no sense }
        Result:=Use_VectorFPU(ResultDef) and
          ((fpu_capabilities[CurrentSettings.FPUType]*[FPUX86_HAS_FMA,FPUX86_HAS_FMA4])<>[]);

      end;


    procedure TX86AddNode.Second_CmpFloatVector;
      var
        lAsmOp : TAsmOp;
      const
        cSingleOps: array[Boolean] of TAsmOp = (A_COMISS,A_VCOMISS);
        cDoubleOps: array[Boolean] of TAsmOp = (A_COMISD,A_VCOMISD);
      begin
        if Is_Single(Left.ResultDef) then
          lAsmOp:=cSingleOps[UseAVX]
        else if Is_Double(Left.ResultDef) then
          lAsmOp:=cDoubleOps[UseAVX]
        else
          InternalError(200402222);
        Pass_Left_Right;

        { fpu operands are always in reversed order on the stack }
        if (Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) and (Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          ToggleFlag(nf_swapped);

        Location_Reset(Location,LOC_FLAGS,OS_NO);

        { Direct move fpu->mm register is not possible, so force any fpu operands to
          memory (not to mm registers because one of the memory locations can be used
          directly in compare instruction, yielding shorter code) }
        if Left.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
        if Right.Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER] then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef);

        if (Right.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
          begin
            case Left.Location.Loc of
              LOC_REFERENCE,LOC_CREFERENCE:
                begin
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Left.Location.Reference);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lAsmOp,S_NO,Left.Location.Reference,Right.Location.Register));
                end;
              LOC_MMREGISTER,LOC_CMMREGISTER:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lAsmOp,S_NO,Left.Location.Register,Right.Location.Register));
              else
                InternalError(200402221);
            end;
            ToggleFlag(nf_swapped);
          end
        else
          begin
            hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
            case Right.Location.Loc of
              LOC_REFERENCE,LOC_CREFERENCE:
                begin
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Right.Location.Reference);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lAsmOp,S_NO,Right.Location.Reference,Left.Location.Register));
                end;
              LOC_MMREGISTER,LOC_CMMREGISTER:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lAsmOp,S_NO,Right.Location.Register,Left.Location.Register));
              else
                InternalError(200402223);
            end;
          end;
        Location.ResFlags:=GetFPUResFlags;
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
      end;


    procedure TX86AddNode.Second_OpVector;
      var
        lCGOp : TOpCG;
      begin
        Pass_Left_Right;
        if (nf_swapped in Flags) then
          SwapLeftRight;

        case NodeType of
          addn :
            lCGOp:=OP_ADD;
          muln :
            lCGOp:=OP_MUL;
          subn :
            lCGOp:=OP_SUB;
          slashn :
            lCGOp:=OP_DIV;
          else
            InternalError(200610071);
        end;

        if Fits_In_MM_Register(Left.ResultDef) then
          begin
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            { we can use only right as left operand if the operation is commutative }
            if (Right.Location.Loc=LOC_MMREGISTER) and (lCGOp in [OP_ADD,OP_MUL]) then
              begin
                if UseAVX then
                  begin
                    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,OS_VECTOR);
                    cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,TFloat2TCgSize[TFloatDef(Left.ResultDef).FloatType],Left.Location,Right.Location.Register,Location.Register,nil);
                  end
                else
                  begin
                    Location.Register:=Right.Location.Register;
                    cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,TFloat2TCgSize[TFloatDef(Left.ResultDef).FloatType],Left.Location,Location.Register,nil);
                  end;
              end
            else
              begin
                Location_Force_MMReg(CurrentAsmData.CurrAsmList,Left.Location,false);
                if UseAVX then
                  begin
                    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,OS_VECTOR);
                    cg.A_OpMM_Loc_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,
                      TFloat2TCgSize[TFloatDef(TArrayDef(Left.ResultDef).ElementDef).FloatType],Right.Location,Left.Location.Register,Location.Register,nil);
                  end
                else
                  begin
                    Location.Register:=Left.Location.Register;
                    cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,
                      TFloat2TCgSize[TFloatDef(TArrayDef(Left.ResultDef).ElementDef).FloatType],Right.Location,Location.Register,nil);
                  end;
              end;
          end
        else
          begin
            { not yet supported }
            InternalError(200610072);
          end
      end;


    procedure TX86AddNode.Second_AddFloat;
      const
        cAddOps:  array[Boolean] of TAsmOp = (A_FADDP,A_FADD);
        cMultiplyOps:  array[Boolean] of TAsmOp = (A_FMULP,A_FMUL);
        cSubtractOps:  array[Boolean] of TAsmOp = (A_FSUBP,A_FSUB);
        cReverseSubtractOps: array[Boolean] of TAsmOp = (A_FSUBRP,A_FSUBR);
        cDivideOps:  array[Boolean] of TAsmOp = (A_FDIVP,A_FDIV);
        cReverseDivideOps: array[Boolean] of TAsmOp = (A_FDIVRP,A_FDIVR);
      var
        lAsmOp : TAsmOp;
        lReferenceNode, lNode: TNode;
        lHasReference : Boolean;
      begin
        if Use_VectorFPU(ResultDef)
{$ifndef x86_64}
          { Make sure currency typs etc. aren't passed through SSE/AVX }
          and Use_VectorFPU(Left.ResultDef)
          and Use_VectorFPU(Right.ResultDef)
{$endif x86_64}
          then
          begin
            if UseAVX then
              Second_AddFloatAVX
            else
              Second_AddFloatSSE;
            exit;
          end;

        { can the operation do the conversion? }
        if (Left.NodeType=typeconvn) and (Is_Double(TTypeConvNode(Left).Left.ResultDef) or Is_Single(TTypeConvNode(Left).Left.ResultDef)) then
          begin
            lNode:=Left;
            Left:=TTypeConvNode(Left).Left;
            TTypeConvNode(lNode).Left:=nil;
            lNode.Free;
          end;
        if (Right.NodeType=typeconvn) and (Is_Double(TTypeConvNode(Right).Left.ResultDef) or Is_Single(TTypeConvNode(Right).Left.ResultDef)) then
          begin
            lNode:=Right;
            Right:=TTypeConvNode(Right).Left;
            TTypeConvNode(lNode).Left:=nil;
            lNode.Free;
          end;

        Pass_Left_Right;
        Prepare_X87_Locations(lReferenceNode);
        lHasReference:=Assigned(lReferenceNode);

        case NodeType of
          addn :
            lAsmOp:=cAddOps[lHasReference];
          muln :
            lAsmOp:=cMultiplyOps[lHasReference];
          subn :
            if (nf_swapped in Flags) then
              lAsmOp:=cReverseSubtractOps[lHasReference]
            else
              lAsmOp:=cSubtractOps[lHasReference];
          slashn :
            if (nf_swapped in Flags) then
              lAsmOp:=cReverseDivideOps[lHasReference]
            else
              lAsmOp:=cDivideOps[lHasReference];
          else
            InternalError(2003042203);
        end;

        if lHasReference then
          emit_ref(lAsmOp,tcgsize2opsize[lReferenceNode.Location.Size],lReferenceNode.Location.Reference)
        else
          begin
            emit_reg_reg(lAsmOp,S_NO,NR_ST,NR_ST1);
            TCGX86(cg).dec_fpu_stack;
          end;

        Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
        Location.Register:=NR_ST;
      end;


    procedure TX86AddNode.Second_CmpFloat;

      begin
        if Use_VectorFPU(Left.ResultDef) or Use_VectorFPU(Right.ResultDef) then
          begin
            Second_CmpFloatVector;
            exit;
          end;

        Pass_Left_Right;
        Force_Left_And_Right_FPUReg;

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

        Location_Reset(Location,LOC_FLAGS,OS_NO);
        Location.ResFlags:=GetFPUResFlags;
      end;


{*****************************************************************************
                                  Add64bit
*****************************************************************************}

    procedure TX86AddNode.Second_Add64Bit;
      begin
{$ifdef cpu64bitalu}
        Second_AddOrdinal;
{$else cpu64bitalu}
        { must be implemented separate }
        InternalError(200402042);
{$endif cpu64bitalu}
      end;


    procedure TX86AddNode.Second_Cmp64Bit;
      begin
{$ifdef cpu64bitalu}
        Second_CmpOrdinal;
{$else cpu64bitalu}
        { must be implemented separate }
        InternalError(200402043);
{$endif cpu64bitalu}
      end;


{*****************************************************************************
                                  AddOrdinal
*****************************************************************************}

    procedure TX86AddNode.Second_AddOrdinal;
      var
         lOpSize : TCgSize;
         lUnsigned : Boolean;
         lCGOp : TOpCG;
         lCheckOverflow : Boolean;
         lOverflowLoc : TLocation;
         lTempReg : TRegister;
         lIndexNode : TNode;

         procedure MakeBZHI(AUseTempReg: Boolean);
           begin
             { allocate registers }
             hlcg.Location_Force_Reg(
               CurrentAsmData.CurrAsmList,
               lIndexNode.Location,
               lIndexNode.ResultDef,
               ResultDef,
               false
             );

             Set_Result_Location_Reg;
             if AUseTempReg then
               emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[lOpSize], lIndexNode.Location.Register, lTempReg, Location.Register)
             else
               case Left.Location.Loc of
                 LOC_REFERENCE,
                 LOC_CREFERENCE:
                   emit_reg_ref_reg(A_BZHI, TCGSize2OpSize[lOpSize], lIndexNode.Location.Register, Left.Location.Reference, Location.Register);
                 LOC_REGISTER,
                 LOC_CREGISTER:
                   emit_reg_reg_reg(A_BZHI, TCGSize2OpSize[lOpSize], lIndexNode.Location.Register, Left.Location.Register, Location.Register);
                 else
                   InternalError(2022102111);
               end;
           end;

      begin
        lIndexNode := nil; { Needed to prevent a compiler warning }

        { determine if the comparison will be unsigned }
        lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                    not(Is_Signed(Right.ResultDef));

        { assume no overflow checking is require }
        lCheckOverflow := false;

        lOverflowLoc.Loc:=LOC_VOID;

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
            InternalError(2015022501);
        end;

       lCheckOverflow:=
         lCheckOverflow and
         NeedOverflowCheck;

       lOpSize:=Def_CGSize(Left.ResultDef);


       if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
         begin
           { BMI1 optimisations }
           if (CPUX86_HAS_BMI1 in cpu_capabilities[CurrentSettings.CPUType]) then
             begin
               { Can we turn "x and (not y)" into an ANDN instruction instead? }
               if (NodeType = andn) and
                 (lOpSize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) and
                 ((Left.NodeType = notn) or (Right.NodeType = notn)) and
                 (
                   { With "const and (not variable)", ANDN will produce larger
                     code once everything is moved into registers (as a side-note,
                     "const and (not const)" and "variable and (not const)" will
                     have been simplified earlier to remove the NOT operation). }
                   not (cs_opt_size in CurrentSettings.OptimizerSwitches) or
                   (
                     (Left.Location.Loc <> LOC_CONSTANT) and
                     (Right.Location.Loc <> LOC_CONSTANT)
                   )
                 ) then
                 begin
                   { ANDN only supports the second operand being inverted; however,
                     since we're dealing with ordinals, there won't be any Boolean
                     shortcutting, so we can safely swap the parameters }

                   if (Right.NodeType <> notn) then
                     SwapLeftRight;

                   SecondPass(Left);

                   { Skip the not node completely }
                   Include(Right.TransientFlags, tnf_do_not_execute);
                   SecondPass(TNotNode(Right).Left);

                   { allocate registers }
                   hlcg.Location_Force_Reg(
                     CurrentAsmData.CurrAsmList,
                     TNotNode(Right).Left.Location,
                     TNotNode(Right).Left.ResultDef,
                     TNotNode(Right).Left.ResultDef,
                     false
                   );

                   if Left.Location.Loc = LOC_CONSTANT then
                     { With "const and (not variable)", we can probably still make a
                       saving when it comes to pipeline stalls (left.location.loc
                       will become LOC_CREGISTER). }
                     hlcg.Location_Force_Reg(
                       CurrentAsmData.CurrAsmList,
                       Left.Location,
                       Left.ResultDef,
                       Left.ResultDef,
                       true
                     );

                   Set_Result_Location_Reg;

                   case Left.Location.Loc of
                     LOC_REFERENCE,
                     LOC_CREFERENCE:
                       emit_ref_reg_reg(A_ANDN, TCGSize2OpSize[lOpSize], Left.Location.Reference, TNotNode(Right).Left.Location.Register, Location.Register);
                     LOC_REGISTER,
                     LOC_CREGISTER:
                       emit_reg_reg_reg(A_ANDN, TCGSize2OpSize[lOpSize], Left.Location.Register, TNotNode(Right).Left.Location.Register, Location.Register);
                     else
                       InternalError(2022102110);
                   end;

                   { Overflow can't happen with and/andn }
                   Exit;
                 end;
             end;

           { BMI2 optimisations }
           if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
             (lOpSize in [OS_32, OS_S32{$ifdef x86_64}, OS_64, OS_S64{$endif x86_64}]) then
             begin
               case NodeType of
                 andn:
                   { Can we turn "x and ((1 shl y) - 1)" into a BZHI instruction instead? }
                   if (
                     (
                       (Right.NodeType = subn) and
                       (TAddNode(Right).Right.NodeType = ordconstn) and
                       (TOrdConstNode(TAddNode(Right).Right).Value = 1) and
                       (TAddNode(Right).Left.NodeType = shln) and
                       (TShlShrNode(TAddNode(Right).Left).Left.NodeType = ordconstn) and
                       (TOrdConstNode(TShlShrNode(TAddNode(Right).Left).Left).Value = 1)
                     ) or
                     (
                       (Left.NodeType = subn) and
                       (TAddNode(Left).Right.NodeType = ordconstn) and
                       (TOrdConstNode(TAddNode(Left).Right).Value = 1) and
                       (TAddNode(Left).Left.NodeType = shln) and
                       (TShlShrNode(TAddNode(Left).Left).Left.NodeType = ordconstn) and
                       (TOrdConstNode(TShlShrNode(TAddNode(Left).Left).Left).Value = 1)
                     )
                   ) then
                     begin

                       { Put the subtract node on the right }
                       if (Right.NodeType <> subn) then
                         SwapLeftRight;

                       SecondPass(Left);

                       { Skip the subtract and shift nodes completely }
                       Include(Right.TransientFlags, tnf_do_not_execute);
                       Include(TAddNode(Right).Left.TransientFlags, tnf_do_not_execute);

                       { Helps avoid all the awkward typecasts }
                       lIndexNode := TShlShrNode(TAddNode(Right).Left).Right;
{$ifdef x86_64}
                       { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                       if (lIndexNode.NodeType = typeconvn) and (lOpSize in [OS_32, OS_S32]) and
                         (Def_CGSize(TTypeConvNode(lIndexNode).ResultDef) in [OS_64, OS_S64]) then
                         begin
                           { Convert to the 32-bit type }
                           lIndexNode.ResultDef := ResultDef;
                           Node_Reset_Flags(lIndexNode,[],[tnf_pass1_done]);

                           { We should't be getting any new errors }
                           if DoFirstPass(lIndexNode) then
                             InternalError(2022110201);

                           { Keep things internally consistent in case indexnode changed }
                           TShlShrNode(TAddNode(Right).Left).Right := lIndexNode;
                         end;
{$endif x86_64}
                       SecondPass(lIndexNode);

                       MakeBZHI(False);
                       Exit;
                     end;

                 subn:
                   { Turns an isolated "(1 shl y) - 1" into "mov $-1,%reg1; bzhi %idxreg,%reg1,%reg2" pair}
                   if (Right.NodeType = ordconstn) and
                     (TOrdConstNode(Right).Value = 1) and
                     (Left.NodeType = shln) and
                     (TShlShrNode(Left).Left.NodeType = ordconstn) and
                     (TOrdConstNode(TShlShrNode(Left).Left).Value = 1) then
                     begin
                       { Skip the shift node completely }
                       Include(Left.TransientFlags, tnf_do_not_execute);

                       { Helps avoid all the awkward typecasts }
                       lIndexNode := TShlShrNode(Left).Right;

{$ifdef x86_64}
                       { The code generator sometimes extends the shift result to 64-bit unnecessarily }
                       if (lIndexNode.NodeType = typeconvn) and (lOpSize in [OS_32, OS_S32]) and
                         (Def_CGSize(TTypeConvNode(lIndexNode).ResultDef) in [OS_64, OS_S64]) then
                         begin
                           { Convert to the 32-bit type }
                           lIndexNode.ResultDef := ResultDef;
                           Node_Reset_Flags(lIndexNode,[],[tnf_pass1_done]);

                           { We should't be getting any new errors }
                           if DoFirstPass(lIndexNode) then
                             InternalError(2022110202);

                           { Keep things internally consistent in case indexnode changed }
                           TShlShrNode(Left).Right := lIndexNode;
                         end;
{$endif x86_64}
                       SecondPass(lIndexNode);

                       lTempReg := cg.GetIntRegister(CurrentAsmData.CurrAsmList, lOpSize);
                       cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, lOpSize, -1, lTempReg);

                       MakeBZHI(True);
                       Exit;
                     end;
                 else
                   ;
               end;
             end;
         end;


       Pass_Left_Right;

       { do we have to allocate a register? If yes, then three opcode instructions are better, however for sub three op code instructions
         make no sense if right is a reference }
       if ((Left.Location.Loc<>LOC_REGISTER) and (Right.Location.Loc<>LOC_REGISTER) and
           ((NodeType<>subn) or not(Right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE])) and
           { 3 op mul makes only sense if a constant is involved }
           ((NodeType<>muln) or (Left.Location.Loc=LOC_CONSTANT) or (Right.Location.Loc=LOC_CONSTANT)

            or ((CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and (not(NeedOverflowCheck))
               )

           ) and
           (not(NodeType in [orn,andn,xorn]))) or
         ((NodeType=addn) and (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_CONSTANT]) and (Right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_CONSTANT])) then
         begin
           { allocate registers }
           Force_Reg_Left_Right(NodeType<>subn,true);
           Set_Result_Location_Reg;
           if NodeType<>subn then
            begin
              if lCheckOverflow then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

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
                  if lCheckOverflow then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

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

                  if lCheckOverflow then
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                  hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,
                    Right.Location.Register,lTempReg,Location.Register,lCheckOverflow,lOverflowLoc);
                end;
            end
         end
       else
         begin
           { at least one location should be a register, if yes, try to re-use it, so we can try two operand opcodes }
           if Left.Location.Loc<>LOC_REGISTER then
              begin
                if Right.Location.Loc<>LOC_REGISTER then
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false)
                else
                  begin
                    Location_Swap(Left.Location,Right.Location);
                    ToggleFlag(nf_swapped);
                  end;
              end;

           { at this point, left.location.loc should be LOC_REGISTER }
           if Right.Location.Loc=LOC_REGISTER then
             begin
               if lCheckOverflow then
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

               { when swapped another result register }
               if (NodeType=subn) and (nf_swapped in Flags) then
                 begin
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,lOpSize,
                     Left.Location.Register,Right.Location.Register);
                   Location_Swap(Left.Location,Right.Location);
                   ToggleFlag(nf_swapped);
                 end
               else
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,lOpSize,
                    Right.Location.Register,Left.Location.Register);
             end
           else
             begin
               { right.location<>LOC_REGISTER }
               if Right.Location.Loc in [LOC_CSUBSETREF,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_SUBSETREG] then
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,Left.ResultDef,true);

               if (NodeType=subn) and (nf_swapped in Flags) then
                 begin
                   lTempReg:=Left.Location.Register;
                   Left.Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                   cg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lOpSize,Right.Location,Left.Location.Register);

                   if lCheckOverflow then
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,lOpSize,lTempReg,Left.Location.Register);
                 end
               else
                 begin
                   if lCheckOverflow then
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

                   cg.A_Op_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,lOpSize,Right.Location,Left.Location.Register);
                 end;
               Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
             end;

           Location_Copy(Location,Left.Location);
         end;

       { emit overflow check if required }
       if lCheckOverflow then
         cg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
     end;


    procedure TX86AddNode.Second_AddBoolean;
      begin
        if (NodeType in [orn,andn]) and
           (not(cs_full_boolean_eval in CurrentSettings.LocalSwitches) or
          (anf_short_bool in AddNodeFlags)) then
          inherited Second_AddBoolean
        else if Is_64Bit(Left.ResultDef) then
          inherited
        else
          Second_AddOrdinal;
      end;


    procedure TX86AddNode.Second_CmpOrdinal;
      var
         lOpDef  : TDef;
         lOpSize : TCgSize;
         lUnsigned : Boolean;
      begin
         lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                   not(Is_Signed(Right.ResultDef));
         lOpDef:=Left.ResultDef;
         lOpSize:=Def_CGSize(lOpDef);

         Pass_Left_Right;

         if (Right.Location.Loc=LOC_CONSTANT) and
            (Left.Location.Loc in [LOC_REFERENCE, LOC_CREFERENCE])
{$ifdef x86_64}
              and ((not (lOpSize in [OS_64,OS_S64])) or (
              (Right.Location.Value>=low(LongInt)) and (Right.Location.Value<=high(LongInt))
            ))
{$endif x86_64}
         then
           begin
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
             emit_const_ref(A_CMP, TCGSize2Opsize[lOpSize], Right.Location.Value, Left.Location.Reference);
             Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
           end
         else
           begin
             Left_Must_Be_Reg(lOpDef,lOpSize,false);
             Emit_Generic_Code(A_CMP,lOpSize,lUnsigned,false,false);
             Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
             Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
           end;
         Location_Reset(Location,LOC_FLAGS,OS_NO);
         Location.ResFlags:=GetResFlags(lUnsigned);
      end;

begin
   CAddNode:=TX86AddNode;
end.
