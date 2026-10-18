{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86_64 assembler for in set/case nodes

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
unit nx64set;

{$i fpcdefs.inc}

interface

    uses
      ConstExp,
      GlobType,
      nset,nx86set;

    type
      TX8664CaseNode = class(TX86CaseNode)
         procedure OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);override;
         procedure GenJumpTable(ARootLabel : PCaseLabel;AMin,AMax : Int64);override;
      end;


implementation

    uses
      Systems,CPUInfo,
      Verbose,Globals,
      defutil,CUtils,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgbase,
      cpubase,ProcInfo,
      cga,cgutils,cgobj,cgx86;


{*****************************************************************************
                            TX8664CASENODE
*****************************************************************************}

    procedure TX8664CaseNode.OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);
      begin
        inc(AMaxLinearList,9);
      end;


    { Always generate position-independent jump table, it is twice less in size at a price
      of two extra instructions (which shouldn't cause more slowdown than pipeline trashing) }
    procedure TX8664CaseNode.GenJumpTable(ARootLabel : PCaseLabel; AMin,AMax : Int64);
      var
        lLastValue: TConstExprInt;
        lTableLabel: TAsmLabel;
        lBaseReg,lIndexReg,lJumpReg: TRegister;
        lReference: TReference;
        lJumpTableList: TAsmList;
        lOpCGSize: TCgSize;
        lSectionType: TAsmSectiontype;
        lTableItemConstType: TAIConstType;
        lAlmostExhaustive: Boolean;
        lLowValue, lHighValue: TConstExprInt;
        lExhaustiveLimit, lRange, lValue, lOldMin : aint;

      const
        cExhaustiveLimitBase = 32;

      procedure GenItem(ALabel : PCaseLabel);
        var
          lIndex : TConstExprInt;
        begin
          if Assigned(ALabel^.Less) then
            GenItem(ALabel^.Less);
          { fill possible hole }
          lIndex:=lLastValue+1;
          while lIndex<=ALabel^.LowValue-1 do
            begin
              lJumpTableList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,FElseLabel));
              lIndex:=lIndex+1;
            end;
          lIndex:=ALabel^.LowValue;
          while lIndex<=ALabel^.HighValue do
            begin
              lJumpTableList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,BlockLabel(ALabel^.BlockID)));
              lIndex:=lIndex+1;
            end;
          lLastValue:=ALabel^.HighValue;
          if Assigned(ALabel^.Greater) then
            GenItem(ALabel^.Greater);
        end;

      begin
        lLowValue:=0;
        lHighValue:=0;
        if not(TargetInfo.system in systems_darwin) then
          lTableItemConstType:=aitconst_32bit
        else
          { see https://gmplib.org/list-archives/gmp-bugs/2012-December/002836.html }
          lTableItemConstType:=aitconst_darwin_dwarf_delta32;

        lJumpTableList := CurrentAsmData.CurrAsmList;
        lLastValue:=AMin;
        lOpCGSize:=Def_CGSize(FOpSize);

        lAlmostExhaustive := False;
        lOldMin := AMin;

        if not(FJumpTableNoRange) then
          begin

            GetRange(Left.ResultDef,lLowValue,lHighValue);
            lRange := aint(AMax)-aint(AMin);

            if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
              { Limit size of jump tables for small enumerations so they have
                to be at least two-thirds full before being considered for the
                "almost exhaustive" treatment }
              lExhaustiveLimit := min(cExhaustiveLimitBase, LabelCoverage shl 1)
            else
              lExhaustiveLimit := cExhaustiveLimitBase;

            { If true, then this indicates that almost every possible value of x is covered by
              a label.  As such, it's more cost-efficient to remove the initial range check and
              instead insert the remaining values into the jump table, pointing at elselabel. [Kit] }
            if ((lHighValue - lLowValue) - lRange <= lExhaustiveLimit) then
              begin
                lOldMin := AMin;
                AMin := lLowValue.svalue;
                lAlmostExhaustive := True;
              end
            else
              begin
                { a <= x <= b <-> unsigned(x-a) <= (b-a) }
                cg.A_Op_Const_Reg(lJumpTableList,OP_SUB,lOpCGSize,aint(AMin),FRegister);
                { case expr greater than max_ => goto elselabel }
                cg.A_Cmp_Const_Reg_Label(lJumpTableList,lOpCGSize,OC_A,lRange,FRegister,FElseLabel);
                AMin:=0;
                { do not sign extend when we load the index register, as we applied an offset above }
                lOpCGSize:=TCgSize2Unsigned[lOpCGSize];
              end;
          end;

        { local label in order to avoid using GOT }
        CurrentAsmData.getlabel(lTableLabel,alt_data);
        lIndexReg:=cg.MakeRegSize(lJumpTableList,FRegister,OS_ADDR);
        cg.A_Load_Reg_Reg(lJumpTableList,lOpCGSize,OS_ADDR,FRegister,lIndexReg);
        { load table address }
        Reference_Reset_Symbol(lReference,lTableLabel,0,4,[]);
        lBaseReg:=cg.GetAddressRegister(lJumpTableList);
        cg.A_LoadAddr_Ref_Reg(lJumpTableList,lReference,lBaseReg);
        { load table slot, 32-bit sign extended }
        Reference_Reset_Base(lReference,lBaseReg,-aint(AMin)*4,CTempPosInvalid,4,[]);
        lReference.Index:=lIndexReg;
        lReference.ScaleFactor:=4;
        lJumpReg:=cg.GetAddressRegister(lJumpTableList);
        cg.A_Load_Ref_Reg(lJumpTableList,OS_S32,OS_ADDR,lReference,lJumpReg);
        { add table address }
        Reference_Reset_Base(lReference,lBaseReg,0,CTempPosInvalid,sizeof(PInt),[]);
        lReference.Index:=lJumpReg;
        lReference.ScaleFactor:=1;
        cg.A_LoadAddr_Ref_Reg(lJumpTableList,lReference,lJumpReg);
        { and finally jump }
        emit_reg(A_JMP,S_NO,lJumpReg);
        { generate jump table }
        if not(TargetInfo.system in systems_darwin) then
          lSectionType:=sec_rodata
        else
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

        lJumpTableList := CurrentProcInfo.AktLocalData;
        new_section(lJumpTableList,lSectionType,CurrentProcInfo.procdef.MangledName,4);
        lJumpTableList.concat(TAILabel.Create(lTableLabel));

        if lAlmostExhaustive then
          begin
            { Fill the table with the values below _min }
            lValue := lLowValue.svalue;
            while lValue < lOldMin do
              begin
                lJumpTableList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,FElseLabel));
                Inc(lValue);
              end;

            GenItem(ARootLabel);

            { Fill the table with the values above _max }
            { Subtracting one from hv and not adding 1 to max_ averts the risk of an overflow }
            lValue := AMax;
            lHighValue := lHighValue - 1;
            while lValue <= lHighValue.svalue do
              begin
                lJumpTableList.concat(TAIConst.Create_rel_sym(lTableItemConstType,lTableLabel,FElseLabel));
                Inc(lValue);
              end;

          end
        else
          GenItem(ARootLabel);
      end;

begin
   CCaseNode:=TX8664CaseNode;
end.
