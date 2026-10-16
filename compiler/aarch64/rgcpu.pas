{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the AArch64 specific class for the register
    allocator

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

 ****************************************************************************}
unit rgcpu;

{$i fpcdefs.inc}

  interface

    uses
      AAsmBase,AAsmCPU,AAsmTAI,AAsmData,
      CGBase,CGUtils,
      CPUBase,
      GlobType,
      RGObj;

    type
      TRGCPU=class(TRGObj)
        procedure Do_Spill_Read(List: TAsmList; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister); override;
        procedure Do_Spill_Written(List: TAsmList; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister); override;
        function Get_Spill_SubReg(R: TRegister): TSubRegister; override;
       protected
        procedure Do_Spill_Op(List: TAsmList; Op: TAsmOp; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister);
      end;

      TRGIntCPU=class(TRGCPU)
        procedure Add_CPU_Interferences(P: TAI); override;
      end;


implementation

    uses
      Verbose,CUtils,
      CGObj;

    function  TRGCPU.Get_Spill_SubReg(R:TRegister) : TSubRegister;
      begin
        if (GetRegType(R)<>R_MMREGISTER) then
          Result:=DefaultSub
        else
          Result:=GetSubReg(R);
      end;


    procedure TRGCPU.Do_Spill_Read(List: TAsmList; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister);
      begin
        Do_Spill_Op(List,A_LDR,Pos,SpillTemp,TempReg,OrgSupReg);
      end;


    procedure TRGCPU.Do_Spill_Written(List: TAsmList; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister);
      begin
        Do_Spill_Op(List,A_STR,Pos,SpillTemp,TempReg,OrgSupReg);
      end;


    procedure TRGCPU.Do_Spill_Op(List: TAsmList; Op: TAsmOp; Pos: TAI; const SpillTemp: TReference; TempReg: TRegister; OrgSupReg: TSuperRegister);
      var
        HelpIns  : TAI;
        TmpRef   : TReference;
        HelpList : TAsmList;
        HReg     : TRegister;
        IsLoad   : Boolean;
      begin
        IsLoad:=Op=A_LDR;
        { offset out of range for regular load/store? }
        if simple_ref_type(Op,reg_cgsize(TempReg),PF_None,SpillTemp)<>sr_simple then
          begin
            HelpList:=TAsmList.Create;

            if (GetRegType(TempReg)=R_INTREGISTER) then
              HReg:=GetRegisterInline(HelpList,[R_SUBWHOLE])
            else
              HReg:=CG.GetAddressRegister(HelpList);

            CG.A_Load_Const_Reg(HelpList,OS_ADDR,SpillTemp.Offset,HReg);
            Reference_Reset_Base(TmpRef,SpillTemp.Base,0,SpillTemp.TempPos,SizeOf(PInt),[]);
            TmpRef.Index:=HReg;
            if IsLoad then
              HelpIns:=spilling_create_load(TmpRef,TempReg)
            else
              HelpIns:=spilling_create_store(TempReg,TmpRef);
            HelpList.Concat(HelpIns);
            if (GetRegType(TempReg)=R_INTREGISTER) then
              UngetRegisterInline(HelpList,HReg);
            Add_CPU_Interferences(HelpIns);
            List.InsertListAfter(Pos,HelpList);
            HelpList.Free;
          end
        else if IsLoad then
          inherited Do_Spill_Read(List,Pos,SpillTemp,TempReg,OrgSupReg)
        else
          inherited Do_Spill_Written(List,Pos,SpillTemp,TempReg,OrgSupReg)
      end;


    procedure TRGIntCPU.Add_CPU_Interferences(P: TAI);
     var
       I, J: LongInt;
     begin
       if P.Typ=ait_instruction then
         begin
           { add interferences for instructions that can have SP as a register
             operand }
           case TAICPU(P).Opcode of
             A_MOV:
               { all operands can be SP }
               Exit;
             A_ADD,
             A_SUB,
             A_CMP,
             A_CMN:
               { ok as destination or first source in immediate or extended
                 register form }
               if (TAICPU(P).Oper[TAICPU(P).Ops-1]^.Typ<>top_shifterop) or
                  valid_shifter_operand(TAICPU(P).Opcode,False,True,
                    reg_cgsize(TAICPU(P).Oper[0]^.Reg) in [OS_64,OS_S64],
                    TAICPU(P).Oper[TAICPU(P).Ops-1]^.ShifterOp^.ShiftMode,
                    TAICPU(P).Oper[TAICPU(P).Ops-1]^.ShifterOp^.ShiftImm) then
                 begin
                   if TAICPU(P).Oper[TAICPU(P).Ops-1]^.Typ=top_shifterop then
                     I:=TAICPU(P).Ops-2
                   else
                     I:=TAICPU(P).Ops-1;
                   if (TAICPU(P).Oper[I]^.Typ=top_reg) then
                     Add_Edge(GetSupReg(TAICPU(P).Oper[I]^.Reg),RS_SP);
                   Exit;
                 end;
             A_AND,
             A_EOR,
             A_ORR,
             A_TST:
               { ok in immediate form }
               if TAICPU(P).Oper[TAICPU(P).Ops-1]^.Typ=top_const then
                 Exit;
             else
               ;
           end;
           { add interferences for other registers }
           for I:=0 to TAICPU(P).Ops-1 do
             begin
               case TAICPU(P).Oper[I]^.Typ of
                 top_reg:
                   if GetRegType(TAICPU(P).Oper[I]^.Reg)=R_INTREGISTER then
                     Add_Edge(GetSupReg(TAICPU(P).Oper[I]^.Reg),RS_SP);
                 top_ref:
                   begin
                     { sp can always be base, never be index }
                     if TAICPU(P).Oper[I]^.Ref^.Index<>NR_NO then
                       Add_Edge(GetSupReg(TAICPU(P).Oper[I]^.Ref^.Index),RS_SP);
                     { in case of write back, the base register must be
                       different from the loaded/stored register }
                     if (TAICPU(P).Oper[I]^.Ref^.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED]) and
                        (TAICPU(P).Oper[I]^.Ref^.Base<>NR_NO) then
                       begin
                         for J:=Pred(I) downto 0 do
                           if TAICPU(P).Oper[J]^.Typ=TOP_REG then
                             Add_Edge(GetSupReg(TAICPU(P).Oper[J]^.Reg),GetSupReg(TAICPU(P).Oper[I]^.Ref^.Base));
                       end;
                   end;
                 else
                   ;
               end;
             end;
         end;
     end;

end.
