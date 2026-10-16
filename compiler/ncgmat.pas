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
           register r.

           This routine should be overridden, since
           the generic version is not optimal at all. The
           generic version assumes that floating
           point values are stored in the register
           in IEEE-754 format.
         }
         procedure emit_float_sign_change(r: TRegister; _size : TDef);virtual;
{$ifdef SUPPORT_MMX}
         procedure second_mmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure second_64bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure second_integer;virtual;
         procedure second_float;virtual;
      public
         procedure pass_generate_code;override;
      end;

      TCGModDivNode = class(TModDivNode)
         procedure pass_generate_code;override;
      protected
         { This routine must do an actual 32-bit division, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the division must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
         }
         procedure emit_div_reg_reg_reg(signed: boolean;denum,num,res : TRegister);virtual;abstract;
         { This routine must do an actual 32-bit modulo, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the modulo must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a modulo.
         }
         procedure emit_mod_reg_reg_reg(signed: boolean;denum,num,res : TRegister);virtual;abstract;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { This routine must do an actual 64-bit division, be it
           signed or unsigned. The result must set into the the
           @var(num) register.

           @param(signed Indicates if the division must be signed)
           @param(denum  Register containing the denominator
           @param(num    Register containing the numerator, will also receive result)

           The actual optimizations regarding shifts have already
           been done and emitted, so this should really a do a divide.
           Currently, this routine should only be implemented on
           64-bit systems, otherwise a helper is called in 1st pass.
         }
         procedure emit64_div_reg_reg(signed: boolean;denum,num : TRegister64);virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
      end;

      TCGShlShrNode = class(TShlShrNode)
{$ifdef SUPPORT_MMX}
         procedure second_mmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure second_64bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure second_integer;virtual;
         procedure pass_generate_code;override;
      end;

      TCGNotNode = class(TNotNode)
      protected
         function handle_locjump: boolean;
         procedure second_boolean;virtual;abstract;
{$ifdef SUPPORT_MMX}
         procedure second_mmx;virtual;abstract;
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         procedure second_64bit;virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
         procedure second_integer;virtual;
      public
         procedure pass_generate_code;override;
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

    procedure TCGUnaryMinusNode.emit_float_sign_change(r: TRegister; _size : TDef);
      var
        href,
        href2 : TReference;
      begin
        { get a temporary memory reference to store the floating
          point value
        }
        tg.GetHLTemp(CurrentAsmData.CurrAsmList,_size,_size.Size,tt_normal,href);
        { store the floating point value in the temporary memory area }
        case GetRegType(r) of
          R_FPUREGISTER:
            hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,_size,_size,r,href);
          R_MMREGISTER:
            hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,_size,_size,r,href,MMS_MoveScalar);
          else
            InternalError(2015091005);
        end;
        { only single and double ieee are supported, for little endian
          the signed bit is in the second dword }
        href2:=href;
        if _size.typ<>floatdef then
          InternalError(2014012211);
        case TFloatDef(_size).FloatType of
          S64Real,
          s64comp,
          s64currency:
            if TargetInfo.endian = endian_little then
              inc(href2.Offset,4);
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
          href2);
        case GetRegType(r) of
          R_FPUREGISTER:
            hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,_size,_size,href,r);
          R_MMREGISTER:
            hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,_size,_size,href,r,MMS_MoveScalar);
          else
            InternalError(2015091006);
        end;
        tg.ungetiftemp(CurrentAsmData.CurrAsmList,href);
      end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGUnaryMinusNode.second_64bit;
      var
        tr: TRegister;
        hl: TAsmLabel;
      begin
        SecondPass(left);
        Location_Reset(location,LOC_REGISTER,left.Location.Size);
        location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        cg64.A_Op64_Loc_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_S64,
          left.Location,JoinReg64(location.Register64.RegLo,location.Register64.RegHi));
        { there's only overflow in case left was low(int64) -> -left = left }
        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            tr:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,OS_32,
              LongInt($80000000),location.Register64.RegHi,tr);
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,
              location.Register64.RegLo,tr);
            CurrentAsmData.getjumplabel(hl);
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_32,OC_NE,0,tr,hl);
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
            cg.A_Label(CurrentAsmData.CurrAsmList,hl);
          end;
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}



    procedure TCGUnaryMinusNode.second_float;
      begin
        SecondPass(left);
        Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
        case left.Location.Loc of
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              location.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,resultdef);
              case GetRegType(location.Register) of
                R_FPUREGISTER:
                  hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                     left.resultdef,resultdef,
                     left.Location.Reference,location.Register);
                R_MMREGISTER:
                  hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,
                     left.resultdef,resultdef,
                     left.Location.Reference,location.Register,MMS_MoveScalar);
                else
                  InternalError(2015091004);
              end;
              emit_float_sign_change(location.Register,left.resultdef);
            end;
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
               location.Register:=hlcg.GetFPURegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
               emit_float_sign_change(location.Register,left.resultdef);
            end;
          LOC_MMREGISTER,
          LOC_CMMREGISTER:
            begin
               location.Register:=hlcg.GetMMRegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register,MMS_MoveScalar);
               emit_float_sign_change(location.Register,left.resultdef);
            end
          else
            InternalError(200306021);
        end;
      end;


    procedure TCGUnaryMinusNode.second_integer;
      var
        hl: TAsmLabel;
      begin
        SecondPass(left);
        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef,false);
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          hlcg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

        hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,resultdef,left.Location.Register,location.Register);

        if (cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            CurrentAsmData.getjumplabel(hl);
            hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,resultdef,OC_NE,TOrdDef(resultdef).low.svalue,location.Register,hl);
            hlcg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_overflow',[],nil).ResetIfTemp;
            hlcg.A_Label(CurrentAsmData.CurrAsmList,hl);
          end;
      end;


    procedure TCGUnaryMinusNode.pass_generate_code;
      begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(left.resultdef) then
           second_64bit
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
{$ifdef SUPPORT_MMX}
           if (cs_mmx in CurrentSettings.LocalSwitches) and Is_MMX_Able_Array(left.resultdef) then
             second_mmx
         else
{$endif SUPPORT_MMX}
            if (left.resultdef.typ=floatdef) then
              second_float
         else
           second_integer;
      end;


{*****************************************************************************
                             TCGMODDIVNODE
*****************************************************************************}

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGModDivNode.emit64_div_reg_reg(signed: boolean; denum,num:TRegister64);
      begin
        { handled in pass_1 already, unless pass_1 is
          overridden
        }
        { should be handled in pass_1 (JM) }
        InternalError(200109052);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGModDivNode.pass_generate_code;
      var
         hreg1 : TRegister;
         hdenom : TRegister;
         power : LongInt;
         hl : TAsmLabel;
         paraloc1 : TCGPara;
         opsize : TCgSize;
         opdef : TDef;
         pd: TProcDef;
      begin
         SecondPass(left);
         if CodeGenError then
          exit;
         SecondPass(right);
         if CodeGenError then
          exit;
         Location_Copy(location,left.Location);

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(resultdef) then
           begin
             if Is_Signed(left.resultdef) then
               opdef:=S64IntType
             else
               opdef:=U64IntType;

             { this code valid for 64-bit cpu's only ,
               otherwise helpers are called in pass_1
             }
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,opdef,false);
             Location_Copy(location,left.Location);
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,opdef,false);
             emit64_div_reg_reg(Is_Signed(left.resultdef),
               JoinReg64(right.Location.Register64.RegLo,right.Location.Register64.RegHi),
               JoinReg64(location.Register64.RegLo,location.Register64.RegHi));
           end
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           begin
              if Is_Signed(left.resultdef) then
                begin
                  opsize:=OS_SINT;
                  opdef:=OSSIntType;
                end
              else
                begin
                  opsize:=OS_INT;
                  opdef:=OSUIntType;
                end;

              { put numerator in register }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,false);
              hreg1:=left.Location.Register;

              if (nodetype=divn) and
                 (right.nodetype=ordconstn) and
                 IsPowerOf2(TOrdConstNode(right).Value.svalue,power) then
                Begin
                  { for signed numbers, the numerator must be adjusted before the
                    shift instruction, but not wih unsigned numbers! Otherwise,
                    "Cardinal($ffffffff) div 16" overflows! (JM) }
                  If Is_Signed(left.resultdef) Then
                    Begin
                      CurrentAsmData.getjumplabel(hl);
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_INT,OC_GT,0,hreg1,hl);
                      if power=1 then
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_INT,1,hreg1)
                      else
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_INT,TOrdConstNode(right).Value.svalue-1,hreg1);
                      cg.A_Label(CurrentAsmData.CurrAsmList,hl);
                      cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,OS_INT,power,hreg1);
                    End
                  Else { not signed }
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,OS_INT,power,hreg1);

                  Location_Reset(location,LOC_REGISTER,opsize);
                  location.Register:=hreg1;
                End
              else
                begin
                  { bring denominator to hdenom }
                  { hdenom is always free, it's }
                  { only used for temporary }
                  { purposes                }
                  if not(right.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) then
                    begin
                      hdenom := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                      hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,OSUIntType,right.Location,hdenom);
                    end
                  else
                    hdenom:=right.Location.Register;
                  { verify if the divisor is zero, if so return an error immediately,
                    except if we have a const node, where we don't need this, because
                    then zero check was done earlier.
                  }
                  if (right.nodetype <> ordconstn) then
                    begin
                      CurrentAsmData.getjumplabel(hl);
                      cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,OS_INT,OC_NE,0,hdenom,hl);
                      paraloc1.init;
                      pd:=Search_System_Proc('fpc_handleerror');
                      ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
                      cg.A_Load_Const_CGPara(CurrentAsmData.CurrAsmList,OS_S32,aint(200),paraloc1);
                      ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc1);
                      cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_HANDLEERROR',false);
                      paraloc1.done;
                      cg.A_Label(CurrentAsmData.CurrAsmList,hl);
                    end;
                  Location_Reset(location,LOC_REGISTER,opsize);
                  location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                  if nodetype = modn then
                    emit_mod_reg_reg_reg(Is_Signed(left.resultdef),hdenom,hreg1,location.Register)
                  else
                    emit_div_reg_reg_reg(Is_Signed(left.resultdef),hdenom,hreg1,location.Register);
                end;
           end;
        cg.G_OverflowCheck(CurrentAsmData.CurrAsmList,location,resultdef);
      end;


{*****************************************************************************
                             TCGSHLRSHRNODE
*****************************************************************************}


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGShlShrNode.second_64bit;
      begin
         { already hanled in 1st pass }
         InternalError(2002081501);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGShlShrNode.second_integer;
      var
         op : TOpCG;
         opdef,shiftcountdef: TDef;
         hcountreg : TRegister;
         opsize : TCgSize;
         ShiftVal : LongInt;
      begin
         { determine operator }
         case nodetype of
           shln: op:=OP_SHL;
           shrn: op:=OP_SHR;
           else
             InternalError(2013120102);
         end;
{$ifdef cpunodefaultint}
        opsize:=left.Location.Size;
        opdef:=left.resultdef;
        shiftcountdef:=opdef;
{$else cpunodefaultint}
        if left.resultdef.Size<=4 then
          begin
            if Is_Signed(left.resultdef) then
              begin
                if (sizeof(aint)<4) and
                   (left.resultdef.Size<=sizeof(aint)) then
                  begin
                    opsize:=OS_SINT;
                    opdef:=SIntType;
                  end
                else
                  begin
                    opdef:=S32IntType;
                    opsize:=OS_S32;
                  end;

                shiftcountdef:=opdef;

              end
            else
              begin
                if (sizeof(aint)<4) and
                   (left.resultdef.Size<=sizeof(aint)) then
                  begin
                    opsize:=OS_INT;
                    opdef:=UIntType;
                  end
                else
                  begin
                    opdef:=U32IntType;
                    opsize:=OS_32;
                  end;

                shiftcountdef:=opdef;

              end
          end
        else
          begin
            if Is_Signed(left.resultdef) then
              begin
                opdef:=S64IntType;
                opsize:=OS_S64;
              end
            else
              begin
                opdef:=U64IntType;
                opsize:=OS_64;
              end;
            shiftcountdef:=opdef;
          end;
{$endif cpunodefaultint}

         if not(left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
           { location_force_reg can be also used to change the size of a register }
           (left.Location.Size<>opsize) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,opdef,true);
         Location_Reset(location,LOC_REGISTER,opsize);
         location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);

         { shifting by a constant directly coded: }
         if (right.nodetype=ordconstn) then
           begin
              { shl/shr must "wrap around", so use ... and 31 }
              { In TP, "byte/word shl 16 = 0", so no "and 15" in case of
                a 16 bit ALU }
              if TCgSize2Size[opsize]<=4 then
                ShiftVal:=TOrdConstNode(right).Value.uvalue and 31
              else
                ShiftVal:=TOrdConstNode(right).Value.uvalue and 63;
              hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,opdef,
                ShiftVal,left.Location.Register,location.Register);
           end
         else
           begin
              { load right operators in a register - this
                is done since most target cpu which will use this
                node do not support a shift count in a mem. location (cec)
              }
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,shiftcountdef,true);
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,op,opdef,right.Location.Register,left.Location.Register,location.Register);
           end;
         { shl/shr nodes return the same type as left, which can be different
           from opdef }
         if opdef<>resultdef then
           begin
             hcountreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,opdef,resultdef,location.Register,hcountreg);
             location.Register:=hcountreg;
           end;
      end;


    procedure TCGShlShrNode.pass_generate_code;
      begin
         SecondPass(left);
         SecondPass(right);
{$ifdef SUPPORT_MMX}
           if (cs_mmx in CurrentSettings.LocalSwitches) and Is_MMX_Able_Array(left.resultdef) then
             second_mmx
         else
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         if Is_64Bit(left.resultdef) then
           second_64bit
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           second_integer;
      end;


{*****************************************************************************
                               TCGNOTNODE
*****************************************************************************}

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    procedure TCGNotNode.second_64bit;
      begin
        SecondPass(left);
        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        Location_Reset(location,LOC_REGISTER,left.Location.Size);
        location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
        { perform the NOT operation }
        cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,location.Size,left.Location.Register64,location.Register64);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    procedure TCGNotNode.second_integer;
      begin
        SecondPass(left);
        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        Location_Reset(location,LOC_REGISTER,left.Location.Size);
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
        { perform the NOT operation }
        hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NOT,left.resultdef,left.Location.Register,location.Register);
      end;


    function TCGNotNode.handle_locjump: boolean;
      begin
        result:=left.Location.Loc=LOC_JUMP;
        if result then
          begin
            if is_constboolnode(left) then
              InternalError(2014010101);
            if left.Location.Loc<>LOC_JUMP then
              InternalError(2012081306);

            { switch true and false labels to invert result }
            Location_Reset_Jump(location,left.Location.FalseLabel,left.Location.TrueLabel);
          end;
      end;


    procedure TCGNotNode.pass_generate_code;
      begin
        if Is_Boolean(resultdef) then
          second_boolean
{$ifdef SUPPORT_MMX}
        else if (cs_mmx in CurrentSettings.LocalSwitches) and Is_MMX_Able_Array(left.resultdef) then
          second_mmx
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        else if Is_64Bit(left.resultdef) then
          second_64bit
{$endif not cpu64bitalu and not cpuhighleveltarget}
        else
          second_integer;
      end;

begin
   CModDivNode:=TCGModDivNode;
   CUnaryMinusNode:=TCGUnaryMinusNode;
   CShlShrNode:=TCGShlShrNode;
   CNotNode:=TCGNotNode;
end.
