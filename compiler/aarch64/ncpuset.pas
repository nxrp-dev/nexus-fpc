{
    Copyright (c) 2015 by Jonas Maebe

    Generate AArch64 assembler for in set/case nodes

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
unit ncpuset;

{$i fpcdefs.inc}

interface

    uses
       node,nset,ncgset,cpubase,cgbase,cgobj,aasmbase,aasmtai,AAsmData,GlobType;

    type
       TAArch64CaseNode = class(TCGCaseNode)
         protected
           procedure OptimizeValues(var AMaxLinearList: Int64; var AMaxDistance: QWord);override;
           function  Has_JumpTable: Boolean;override;
           procedure GenJumpTable(ARootLabel: PCaseLabel ;AMin, AMax: Int64);override;
           procedure GenLinearList(ARootLabel: PCaseLabel);override;
       end;


implementation

    uses
      Systems,
      Verbose,Globals,ConstExp,CUtils,
      symconst,symdef,defutil,
      paramgr,
      CPUInfo,
      pass_2,cgcpu,
      ncon,
      tgobj,ncgutil,rgobj,aasmcpu,
      ProcInfo,
      cgutils;

{*****************************************************************************
                            TCGCASENODE
*****************************************************************************}


    procedure TAArch64CaseNode.OptimizeValues(var AMaxLinearList: Int64; var AMaxDistance: QWord);
      begin
        AMaxLinearList:=10;
      end;


    function TAArch64CaseNode.Has_JumpTable: Boolean;
      begin
        Has_JumpTable:=true;
      end;


    procedure TAArch64CaseNode.GenLinearList(ARootLabel : PCaseLabel);
      var
        lFirst : Boolean;
        lLastRange : Boolean;
        lLastValue : TConstExprInt;
        lLessCondition,lLessEqualCondition : TResFlags;
        lOpCGSize, lUnsignedOpCGSize: TCgSize;

        procedure GenItem(ALabel : PCaseLabel);
          var
           lOverflowLoc: TLocation;
          begin
            if Assigned(ALabel^.Less) then
              GenItem(ALabel^.Less);
            { need we to test the first value }
            if lFirst and (ALabel^.LowValue>Get_Min_Value(Left.ResultDef)) then
              begin
                cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpCGSize,FJumpLess,aint(ALabel^.LowValue.svalue),FRegister,FElseLabel);
              end;
            if ALabel^.LowValue=ALabel^.HighValue then
              begin
                 if ALabel^.LowValue-lLastValue=0 then
                   cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList, lOpCGSize, OC_EQ,0,FRegister,BlockLabel(ALabel^.BlockID))
                 else
                   begin
                     { use unsigned_opcgsize here to avoid unnecessary sign extensions, at this place hregister will never be negative, because
                       then genlinearlist wouldn't be used }
                     cg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList, OP_SUB, lUnsignedOpCGSize, aint(ALabel^.LowValue.svalue-lLastValue.svalue), FRegister, FRegister,
                       true,lOverflowLoc);
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_EQ,BlockLabel(ALabel^.BlockID));
                   end;
                 lLastValue:=ALabel^.LowValue;
                 lLastRange:=false;
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
                        begin
                          { use unsigned_opcgsize here to avoid unnecessary sign extensions, at this place hregister will never be negative, because
                            then genlinearlist wouldn't be use }
                          cg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList, OP_SUB, lUnsignedOpCGSize, aint(ALabel^.LowValue.svalue), FRegister, FRegister,
                            true,lOverflowLoc);
                        end;
                   end
                 else
                   begin
                     { if there is no unused label between the last and the }
                     { present label then the lower limit can be checked    }
                     { immediately. else check the range in between:       }

                     { use unsigned_opcgsize here to avoid unnecessary sign extensions, at this place hregister will never be negative, because
                       then genlinearlist wouldn't be use }
                     cg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList, OP_SUB, lUnsignedOpCGSize, aint(ALabel^.LowValue.svalue - lLastValue.svalue), FRegister, FRegister,
                       true,lOverflowLoc);
                     { no jump necessary here if the new range starts at }
                     { at the value following the previous one           }
                     if (aint(ALabel^.LowValue.svalue - lLastValue.svalue) <> 1) or
                        (not lLastRange) then
                       cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,lLessCondition,FElseLabel);
                   end;
                 { use unsigned_opcgsize here to avoid unnecessary sign extensions, at this place hregister will never be negative, because
                   then genlinearlist wouldn't be use }
                 cg.A_Op_Const_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,lUnsignedOpCGSize,aint(ALabel^.HighValue.svalue - ALabel^.LowValue.svalue), FRegister, FRegister,
                   true,lOverflowLoc);
                 cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,lLessEqualCondition,BlockLabel(ALabel^.BlockID));

                 lLastValue:=ALabel^.HighValue;
                 lLastRange:=true;
              end;
            lFirst:=false;
            if Assigned(ALabel^.Greater) then
              GenItem(ALabel^.Greater);
          end;

        begin
           lOpCGSize:=Def_CGSize(FOpSize);
           case lOpCGSize of
             OS_8,OS_16,OS_32,OS_S8,OS_S16,OS_S32:
               lUnsignedOpCGSize:=OS_32;
             OS_64,OS_S64:
               lUnsignedOpCGSize:=OS_64;
             else
               InternalError(2019090902);
           end;
           if FWithSign then
             begin
                lLessCondition:=F_LT;
                lLessEqualCondition:=F_LE;
             end
           else
              begin
                lLessCondition:=F_CC;
                lLessEqualCondition:=F_LS;
             end;
           { do we need to generate cmps? }
           if (FWithSign and (FMinLabel<0)) then
             GenLinearCmpList(ARootLabel)
           else
             begin
                lLastValue:=0;
                lLastRange:=false;
                lFirst:=true;
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                GenItem(ARootLabel);
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,FElseLabel);
             end;
        end;


    procedure TAArch64CaseNode.GenJumpTable(ARootLabel: PCaseLabel; AMin, AMax: Int64);
      var
        lLastValue: TConstExprInt;
        lTableLabel: TAsmLabel;
        lBaseReg,lIndexReg,lJumpReg: TRegister;
        lReference: TReference;
        lOpCGSize: TCgSize;
        lSectionType: TAsmSectiontype;
        lTableItemConstType: TAIConstType;

      procedure GenItem(AList:TAsmList;ALabel : PCaseLabel);
        var
          lIndex : Int64;
        begin
          if Assigned(ALabel^.Less) then
            GenItem(AList,ALabel^.Less);
          { fill possible hole }
          lIndex:=lLastValue.svalue+1;
          while lIndex<=ALabel^.LowValue.svalue-1 do
            begin
              if TargetInfo.system=system_aarch64_win64 then
                AList.concat(TAIConst.Create_sym(FElseLabel))
              else
                AList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,FElseLabel));
              inc(lIndex);
            end;
          lIndex:=ALabel^.LowValue.svalue;
          while lIndex<=ALabel^.HighValue.svalue do
            begin
              if TargetInfo.system=system_aarch64_win64 then
                AList.concat(TAIConst.Create_sym(BlockLabel(ALabel^.BlockID)))
              else
                AList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,BlockLabel(ALabel^.BlockID)));
              inc(lIndex);
            end;
          lLastValue:=ALabel^.HighValue;
          if Assigned(ALabel^.Greater) then
            GenItem(AList,ALabel^.Greater);
        end;

      begin
        if not(TargetInfo.system in systems_darwin) then
          lTableItemConstType:=aitconst_32bit
        else
          { see https://gmplib.org/list-archives/gmp-bugs/2012-December/002836.html }
          lTableItemConstType:=aitconst_darwin_dwarf_delta32;

        lLastValue:=AMin;
        lOpCGSize:=Def_CGSize(FOpSize);
        { a <= x <= b <-> unsigned(x-a) <= (b-a) }
        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,lOpCGSize,aint(AMin),FRegister);
        if not(FJumpTableNoRange) then
          begin
             { case expr greater than max_ => goto elselabel }
             cg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,lOpCGSize,OC_A,aint(AMax)-aint(AMin),FRegister,FElseLabel);
             AMin:=0;
          end;
        if TargetInfo.system=system_aarch64_win64 then
          CurrentAsmData.getstaticdatalabel(lTableLabel)
        else
          { local label in order to avoid using GOT }
          CurrentAsmData.getlabel(lTableLabel,alt_data);
        lIndexReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,FRegister,OS_ADDR);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lOpCGSize,OS_ADDR,FRegister,lIndexReg);
        { load table address }
        Reference_Reset_Symbol(lReference,lTableLabel,0,4,[]);
        lBaseReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
        cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,lReference,lBaseReg);
        { load the slot }
        lJumpReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
        if TargetInfo.system=system_aarch64_win64 then
          Reference_Reset_Base(lReference,lBaseReg,0,lReference.TempPos,sizeof(aint),[])
        else
          Reference_Reset_Base(lReference,lBaseReg,0,lReference.TempPos,4,[]);
        lReference.Index:=lIndexReg;
        lReference.ShiftMode:=SM_LSL;
        if TargetInfo.system=system_aarch64_win64 then
          begin
            { Use a 64-bit absolute table under aarch64-win64 }
            lReference.ShiftImm:=3;
            cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,lReference,lJumpReg);
          end
        else
          begin
            { load table slot, 32-bit sign extended }
            lReference.ShiftImm:=2;
            cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_S32,OS_ADDR,lReference,lJumpReg);
            { add table address }
            cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_ADDR,lBaseReg,lJumpReg);
          end;
        { and finally jump }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg(A_BR,lJumpReg));
        { generate jump table }
        if TargetInfo.system=system_aarch64_win64 then
          begin
            { For windows, it has to be in a data section otherwise an access violation
              will occur, but also full 64-bit references to avoid problems with
              relative references }
            lSectionType:=sec_rodata;
            new_section(CurrentProcInfo.AktLocalData,lSectionType,lower(CurrentProcInfo.procdef.MangledName),sizeof(aint));
          end
        else
          begin
            if not(TargetInfo.system in systems_darwin) then
              lSectionType:=sec_rodata
            else
              begin
                { on Mac OS X, dead code stripping ("smart linking") happens based on
                  global symbols: every global/static symbol (symbols that do not
                  start with "L") marks the start of a new "subsection" that is
                  discarded by the linker if there are no references to this symbol.
                  This means that if you put the jump table in the rodata section, it
                  will become part of the block of data associated with the previous
                  non-L-label in the rodata section and stay or be thrown away
                  depending on whether that block of data is referenced. Therefore,
                  jump tables must be added in the code section and since aktlocaldata
                  is inserted right after the routine, it will become part of the
                  same subsection that contains the routine's code }
                lSectionType:=sec_code;
              end;
            new_section(CurrentProcInfo.AktLocalData,lSectionType,CurrentProcInfo.procdef.MangledName,4);
          end;
        if TargetInfo.system in systems_darwin then
          begin
            { additionally, these tables are now marked via ".data_region jt32"
              and ".end_data_region" }
            CurrentProcInfo.AktLocalData.concat(TAIDirective.Create(asd_data_region,'jt32'));
          end;
        CurrentProcInfo.AktLocalData.concat(TAILabel.Create(lTableLabel));
        GenItem(CurrentProcInfo.AktLocalData,ARootLabel);
        if TargetInfo.system in systems_darwin then
          CurrentProcInfo.AktLocalData.concat(TAIDirective.Create(asd_end_data_region,''));
      end;


begin
   CCaseNode:=TAArch64CaseNode;
end.
