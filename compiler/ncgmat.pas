{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate generic mathematical nodes

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
unit ncgmat;

{$i fpcdefs.inc}

interface

    uses
      symtype,
      node,nmat,cpubase,cgbase;

    type
      TCGUnaryMinusNode = class(TUnaryMinusNode)
      protected
         { This routine is called to change the sign of the
           floating point value in the floating point
           register AReg.

           This routine should be overridden, since
           the generic version is not optimal at all. The
           generic version assumes that floating
           point values are stored in the register
           in IEEE-754 format.
         }
         procedure Emit_Float_Sign_Change(AReg: TRegister; AValueDef : TDef);virtual;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure Second_64Bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure Second_Integer;virtual;
         procedure Second_Float;virtual;
      public
         procedure Pass_Generate_Code;override;
      end;

      TCGModDivNode = class(TModDivNode)
         procedure Pass_Generate_Code;override;
      protected
         { This routine must do an actual 32-bit division, be it
           signed or unsigned. The result must set into the the
           @var(ANumerator) register.

           @param(ASigned Indicates if the division must be signed)
           @param(ADenominator  Register containing the denominator
           @param(ANumerator    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
         }
         procedure Emit_Div_Reg_Reg_Reg(ASigned: Boolean;ADenominator,ANumerator,AResult : TRegister);virtual;abstract;
         { This routine must do an actual 32-bit modulo, be it
           signed or unsigned. The result must set into the the
           @var(ANumerator) register.

           @param(ASigned Indicates if the modulo must be signed)
           @param(ADenominator  Register containing the denominator
           @param(ANumerator    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a modulo.
         }
         procedure Emit_Mod_Reg_Reg_Reg(ASigned: Boolean;ADenominator,ANumerator,AResult : TRegister);virtual;abstract;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { This routine must do an actual 64-bit division, be it
           signed or unsigned. The result must set into the the
           @var(ANumerator) register.

           @param(ASigned Indicates if the division must be signed)
           @param(ADenominator  Register containing the denominator
           @param(ANumerator    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
           Currently, this routine should only be implemented on
           64-bit systems, otherwise a helper is called in 1st pass.
         }
         procedure Emit64_Div_Reg_Reg(ASigned: Boolean;ADenominator,ANumerator : TRegister64);virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
      end;

      TCGShlShrNode = class(TShlShrNode)
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure Second_64Bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure Second_Integer;virtual;
         procedure Pass_Generate_Code;override;
      end;

      TCGNotNode = class(TNotNode)
      protected
         function Handle_LocJump: Boolean;
         procedure Second_Boolean;virtual;abstract;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure Second_64Bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure Second_Integer;virtual;
      public
         procedure Pass_Generate_Code;override;
      end;


implementation

    uses
      GlobType,Systems,
      CUtils,Verbose,Globals,
      SymTable,symconst,symdef,aasmbase,AAsmData,aasmcpu,defutil,
      parabase,
      pass_2,
      ncon,
      tgobj,cgobj,cgutils,paramgr,hlcgobj;

{*****************************************************************************
                          TCGUNARYMINUSNODE
*****************************************************************************}

    procedure TCGUnaryMinusNode.Emit_Float_Sign_Change(AReg: TRegister; AValueDef : TDef);
      var
        lReference,
        lSignReference : TReference;
      begin
        { get a temporary memory reference to store the floating
          point value
        }
        TG.GetHLTemp(CurrentAsmData.CurrAsmList,AValueDef,AValueDef.Size,tt_normal,lReference);
        { store the floating point value in the temporary memory area }
        case GetRegType(AReg) of
          R_FPUREGISTER:
            hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,AValueDef,AValueDef,AReg,lReference);
          R_MMREGISTER:
            hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,AValueDef,AValueDef,AReg,lReference,MMS_MoveScalar);
          else
            InternalError(2015091005);
        end;
        { only single and double ieee are supported, for little endian
          the signed bit is in the second dword }
        lSignReference:=lReference;
        if AValueDef.typ<>floatdef then
          InternalError(2014012211);
        case TFloatDef(AValueDef).FloatType of
          S64Real,
          s64comp,
          s64currency:
            inc(lSignReference.Offset,4);
          S32Real :
            ;
          else
            InternalError(200406021);
        end;
        { flip sign-bit (bit 31/63) of single/double }
        hlcg.A_Op_Const_Ref(CurrentAsmData.CurrAsmList,OP_XOR,U32IntType,
{$ifdef cpu64bitalu}
          aint($80000000),
{$else cpu64bitalu}
          LongInt($80000000),
{$endif cpu64bitalu}
          lSignReference);
        case GetRegType(AReg) of
          R_FPUREGISTER:
            hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,AValueDef,AValueDef,lReference,AReg);
          R_MMREGISTER:
            hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,AValueDef,AValueDef,lReference,AReg,MMS_MoveScalar);
          else
            InternalError(2015091006);
        end;
        TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,lReference);
      end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGUnaryMinusNode.Second_64Bit;
      var
        lTempReg: TRegister;
        lLabel: TAsmLabel;
      begin
        SecondPass(Left);
        Location_Reset(Location,LOC_REGISTER,Left.Location.Size);
        Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        cg64.A_Op64_Loc_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_S64,
          Left.Location,JoinReg64(Location.Register64.RegLo,Location.Register64.RegHi));
        { there's only overflow in case left was low(int64) -> -left = left }
        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            lTempReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,OS_32,
              LongInt($80000000),Location.Register64.RegHi,lTempReg);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,
              Location.Register64.RegLo,lTempReg);
            CurrentAsmData.getjumplabel(lLabel);
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_32,OC_NE,0,lTempReg,lLabel);
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
            cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
          end;
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}



    procedure TCGUnaryMinusNode.Second_Float;
      begin
        SecondPass(Left);
        Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
        case Left.Location.Loc of
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              Location.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,ResultDef);
              case GetRegType(Location.Register) of
                R_FPUREGISTER:
                  hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                     Left.ResultDef,ResultDef,
                     Left.Location.Reference,Location.Register);
                R_MMREGISTER:
                  hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,
                     Left.ResultDef,ResultDef,
                     Left.Location.Reference,Location.Register,MMS_MoveScalar);
                else
                  InternalError(2015091004);
              end;
              Emit_Float_Sign_Change(Location.Register,Left.ResultDef);
            end;
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
               Location.Register:=hlcg.GetFPURegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
               Emit_Float_Sign_Change(Location.Register,Left.ResultDef);
            end;
          LOC_MMREGISTER,
          LOC_CMMREGISTER:
            begin
               Location.Register:=hlcg.GetMMRegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register,MMS_MoveScalar);
               Emit_Float_Sign_Change(Location.Register,Left.ResultDef);
            end
          else
            InternalError(200306021);
        end;
      end;


    procedure TCGUnaryMinusNode.Second_Integer;
      var
        lLabel: TAsmLabel;
      begin
        SecondPass(Left);
        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          hlcg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

        hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,ResultDef,Left.Location.Register,Location.Register);

        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            CurrentAsmData.getjumplabel(lLabel);
            hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ResultDef,OC_NE,TOrdDef(ResultDef).low.svalue,Location.Register,lLabel);
            hlcg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_overflow',[],nil).ResetIfTemp;
            hlcg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
          end;
      end;


    procedure TCGUnaryMinusNode.Pass_Generate_Code;
      begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(Left.ResultDef) then
           Second_64Bit
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
            if (Left.ResultDef.typ=floatdef) then
              Second_Float
         else
           Second_Integer;
      end;


{*****************************************************************************
                             TCGMODDIVNODE
*****************************************************************************}

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGModDivNode.Emit64_Div_Reg_Reg(ASigned: Boolean; ADenominator,ANumerator:TRegister64);
      begin
        { handled in pass_1 already, unless pass_1 is
          overridden
        }
        { should be handled in pass_1 (JM) }
        InternalError(200109052);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGModDivNode.Pass_Generate_Code;
      var
         lReg1 : TRegister;
         lDenominatorReg : TRegister;
         lPower : LongInt;
         lLabel : TAsmLabel;
         lParaLoc : TCGPara;
         lOpSize : TCgSize;
         lOpDef : TDef;
         lProcDef: TProcDef;
      begin
         SecondPass(Left);
         if CodeGenError then
          exit;
         SecondPass(Right);
         if CodeGenError then
          exit;
         Location_Copy(Location,Left.Location);

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(ResultDef) then
           begin
             if Is_Signed(Left.ResultDef) then
               lOpDef:=S64IntType
             else
               lOpDef:=U64IntType;

             { this code valid for 64-bit cpu's only ,
               otherwise helpers are called in pass_1
             }
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,lOpDef,false);
             Location_Copy(Location,Left.Location);
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,lOpDef,false);
             Emit64_Div_Reg_Reg(Is_Signed(Left.ResultDef),
               JoinReg64(Right.Location.Register64.RegLo,Right.Location.Register64.RegHi),
               JoinReg64(Location.Register64.RegLo,Location.Register64.RegHi));
           end
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           begin
              if Is_Signed(Left.ResultDef) then
                begin
                  lOpSize:=OS_SINT;
                  lOpDef:=OSSIntType;
                end
              else
                begin
                  lOpSize:=OS_INT;
                  lOpDef:=OSUIntType;
                end;

              { put numerator in register }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,false);
              lReg1:=Left.Location.Register;

              if (NodeType=divn) and
                 (Right.NodeType=ordconstn) and
                 IsPowerOf2(TOrdConstNode(Right).Value.svalue,lPower) then
                Begin
                  { for signed numbers, the numerator must be adjusted before the
                    shift instruction, but not wih unsigned numbers! Otherwise,
                    "Cardinal($ffffffff) div 16" overflows! (JM) }
                  If Is_Signed(Left.ResultDef) Then
                    Begin
                      CurrentAsmData.getjumplabel(lLabel);
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_INT,OC_GT,0,lReg1,lLabel);
                      if lPower=1 then
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_INT,1,lReg1)
                      else
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_INT,TOrdConstNode(Right).Value.svalue-1,lReg1);
                      cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                      cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,OS_INT,lPower,lReg1);
                    End
                  Else { not signed }
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,OS_INT,lPower,lReg1);

                  Location_Reset(Location,LOC_REGISTER,lOpSize);
                  Location.Register:=lReg1;
                End
              else
                begin
                  { bring denominator to hdenom }
                  { hdenom is always free, it's }
                  { only used for temporary }
                  { purposes                }
                  if not(Right.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) then
                    begin
                      lDenominatorReg := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                      hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,OSUIntType,Right.Location,lDenominatorReg);
                    end
                  else
                    lDenominatorReg:=Right.Location.Register;
                  { verify if the divisor is zero, if so return an error immediately,
                    except if we have a const node, where we don't need this, because
                    then zero check was done earlier.
                  }
                  if (Right.NodeType <> ordconstn) then
                    begin
                      CurrentAsmData.getjumplabel(lLabel);
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_INT,OC_NE,0,lDenominatorReg,lLabel);
                      lParaLoc.init;
                      lProcDef:=Search_System_Proc('fpc_handleerror');
                      ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lParaLoc);
                      cg.A_Load_Const_CGPara(CurrentAsmData.CurrAsmList,OS_S32,aint(200),lParaLoc);
                      ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc);
                      cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_HANDLEERROR',false);
                      lParaLoc.done;
                      cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                    end;
                  Location_Reset(Location,LOC_REGISTER,lOpSize);
                  Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                  if NodeType = modn then
                    Emit_Mod_Reg_Reg_Reg(Is_Signed(Left.ResultDef),lDenominatorReg,lReg1,Location.Register)
                  else
                    Emit_Div_Reg_Reg_Reg(Is_Signed(Left.ResultDef),lDenominatorReg,lReg1,Location.Register);
                end;
           end;
        cg.G_OverflowCheck(CurrentAsmData.CurrAsmList,Location,ResultDef);
      end;


{*****************************************************************************
                             TCGSHLRSHRNODE
*****************************************************************************}


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGShlShrNode.Second_64Bit;
      begin
         { already hanled in 1st pass }
         InternalError(2002081501);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGShlShrNode.Second_Integer;
      var
         lOp : TOpCG;
         lOpDef,lShiftCountDef: TDef;
         lCountReg : TRegister;
         lOpSize : TCgSize;
         lShiftValue : LongInt;
      begin
         { determine operator }
         case NodeType of
           shln: lOp:=OP_SHL;
           shrn: lOp:=OP_SHR;
           else
             InternalError(2013120102);
         end;
{$ifdef cpunodefaultint}
        lOpSize:=Left.Location.Size;
        lOpDef:=Left.ResultDef;
        lShiftCountDef:=lOpDef;
{$else cpunodefaultint}
        if Left.ResultDef.Size<=4 then
          begin
            if Is_Signed(Left.ResultDef) then
              begin
                if (sizeof(aint)<4) and
                   (Left.ResultDef.Size<=sizeof(aint)) then
                  begin
                    lOpSize:=OS_SINT;
                    lOpDef:=SIntType;
                  end
                else
                  begin
                    lOpDef:=S32IntType;
                    lOpSize:=OS_S32;
                  end;

                lShiftCountDef:=lOpDef;

              end
            else
              begin
                if (sizeof(aint)<4) and
                   (Left.ResultDef.Size<=sizeof(aint)) then
                  begin
                    lOpSize:=OS_INT;
                    lOpDef:=UIntType;
                  end
                else
                  begin
                    lOpDef:=U32IntType;
                    lOpSize:=OS_32;
                  end;

                lShiftCountDef:=lOpDef;

              end
          end
        else
          begin
            if Is_Signed(Left.ResultDef) then
              begin
                lOpDef:=S64IntType;
                lOpSize:=OS_S64;
              end
            else
              begin
                lOpDef:=U64IntType;
                lOpSize:=OS_64;
              end;
            lShiftCountDef:=lOpDef;
          end;
{$endif cpunodefaultint}

         if not(Left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
           { location_force_reg can be also used to change the size of a register }
           (Left.Location.Size<>lOpSize) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,lOpDef,true);
         Location_Reset(Location,LOC_REGISTER,lOpSize);
         Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);

         { shifting by a constant directly coded: }
         if (Right.NodeType=ordconstn) then
           begin
              { shl/shr must "wrap around", so use ... and 31 }
              { In TP, "byte/word shl 16 = 0", so no "and 15" in case of
                a 16 bit ALU }
              if TCgSize2Size[lOpSize]<=4 then
                lShiftValue:=TOrdConstNode(Right).Value.uvalue and 31
              else
                lShiftValue:=TOrdConstNode(Right).Value.uvalue and 63;
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,lOpDef,
                lShiftValue,Left.Location.Register,Location.Register);
           end
         else
           begin
              { load right operators in a register - this
                is done since most target cpu which will use this
                node do not support a shift count in a mem. location (cec)
              }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,lShiftCountDef,true);
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,lOpDef,Right.Location.Register,Left.Location.Register,Location.Register);
           end;
         { shl/shr nodes return the same type as left, which can be different
           from opdef }
         if lOpDef<>ResultDef then
           begin
             lCountReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpDef,ResultDef,Location.Register,lCountReg);
             Location.Register:=lCountReg;
           end;
      end;


    procedure TCGShlShrNode.Pass_Generate_Code;
      begin
         SecondPass(Left);
         SecondPass(Right);
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(Left.ResultDef) then
           Second_64Bit
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           Second_Integer;
      end;


{*****************************************************************************
                               TCGNOTNODE
*****************************************************************************}

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGNotNode.Second_64Bit;
      begin
        SecondPass(Left);
        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        Location_Reset(Location,LOC_REGISTER,Left.Location.Size);
        Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        { perform the NOT operation }
        cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,Location.Size,Left.Location.Register64,Location.Register64);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGNotNode.Second_Integer;
      begin
        SecondPass(Left);
        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        Location_Reset(Location,LOC_REGISTER,Left.Location.Size);
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
        { perform the NOT operation }
        hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,Left.ResultDef,Left.Location.Register,Location.Register);
      end;


    function TCGNotNode.Handle_LocJump: Boolean;
      begin
        Result:=Left.Location.Loc=LOC_JUMP;
        if Result then
          begin
            if Is_ConstBoolNode(Left) then
              InternalError(2014010101);
            if Left.Location.Loc<>LOC_JUMP then
              InternalError(2012081306);

            { switch true and false labels to invert result }
            Location_Reset_Jump(Location,Left.Location.FalseLabel,Left.Location.TrueLabel);
          end;
      end;


    procedure TCGNotNode.Pass_Generate_Code;
      begin
        if Is_Boolean(ResultDef) then
          Second_Boolean
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        else if Is_64Bit(Left.ResultDef) then
          Second_64Bit
{$endif not cpu64bitalu and not cpuhighleveltarget}
        else
          Second_Integer;
      end;

begin
   CModDivNode:=TCGModDivNode;
   CUnaryMinusNode:=TCGUnaryMinusNode;
   CShlShrNode:=TCGShlShrNode;
   CNotNode:=TCGNotNode;
end.
