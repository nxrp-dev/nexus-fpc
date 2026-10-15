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
      aasmbase,aasmcpu,aasmtai,AAsmData,
      cgbase,cgutils,
      cpubase,
      GlobType,
      rgobj;

    type
      TRGCPU=class(TRGObj)
        procedure do_spill_read(list: TAsmList; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister); override;
        procedure do_spill_written(list: TAsmList; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister); override;
        function get_spill_subreg(r: TRegister): TSubRegister; override;
       protected
        procedure do_spill_op(list: TAsmList; op: TAsmOp; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister);
      end;

      TRGIntCPU=class(TRGCPU)
        procedure add_cpu_interferences(p: TAI); override;
      end;


implementation

    uses
      Verbose,CUtils,
      cgobj;

    function  TRGCPU.get_spill_subreg(r:TRegister) : TSubRegister;
      begin
        if (getregtype(r)<>R_MMREGISTER) then
          result:=defaultsub
        else
          result:=getsubreg(r);
      end;


    procedure TRGCPU.do_spill_read(list: TAsmList; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister);
      begin
        do_spill_op(list,A_LDR,pos,spilltemp,tempreg,orgsupreg);
      end;


    procedure TRGCPU.do_spill_written(list: TAsmList; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister);
      begin
        do_spill_op(list,A_STR,pos,spilltemp,tempreg,orgsupreg);
      end;


    procedure TRGCPU.do_spill_op(list: TAsmList; op: TAsmOp; pos: TAI; const spilltemp: TReference; tempreg: TRegister; orgsupreg: TSuperRegister);
      var
        helpins  : TAI;
        tmpref   : TReference;
        helplist : TAsmList;
        hreg     : TRegister;
        isload   : boolean;
      begin
        isload:=op=A_LDR;
        { offset out of range for regular load/store? }
        if simple_ref_type(op,reg_cgsize(tempreg),PF_None,spilltemp)<>sr_simple then
          begin
            helplist:=TAsmList.create;

            if (getregtype(tempreg)=R_INTREGISTER) then
              hreg:=getregisterinline(helplist,[R_SUBWHOLE])
            else
              hreg:=cg.getaddressregister(helplist);

            cg.a_load_const_reg(helplist,OS_ADDR,spilltemp.offset,hreg);
            reference_reset_base(tmpref,spilltemp.base,0,spilltemp.temppos,sizeof(PInt),[]);
            tmpref.index:=hreg;
            if isload then
              helpins:=spilling_create_load(tmpref,tempreg)
            else
              helpins:=spilling_create_store(tempreg,tmpref);
            helplist.concat(helpins);
            if (getregtype(tempreg)=R_INTREGISTER) then
              ungetregisterinline(helplist,hreg);
            add_cpu_interferences(helpins);
            list.InsertListAfter(pos,helplist);
            helplist.free;
          end
        else if isload then
          inherited do_spill_read(list,pos,spilltemp,tempreg,orgsupreg)
        else
          inherited do_spill_written(list,pos,spilltemp,tempreg,orgsupreg)
      end;


    procedure TRGIntCPU.add_cpu_interferences(p: TAI);
     var
       i, j: LongInt;
     begin
       if p.typ=ait_instruction then
         begin
           { add interferences for instructions that can have SP as a register
             operand }
           case TAICPU(p).opcode of
             A_MOV:
               { all operands can be SP }
               exit;
             A_ADD,
             A_SUB,
             A_CMP,
             A_CMN:
               { ok as destination or first source in immediate or extended
                 register form }
               if (TAICPU(p).oper[TAICPU(p).ops-1]^.typ<>top_shifterop) or
                  valid_shifter_operand(TAICPU(p).opcode,false,true,
                    reg_cgsize(TAICPU(p).oper[0]^.reg) in [OS_64,OS_S64],
                    TAICPU(p).oper[TAICPU(p).ops-1]^.shifterop^.shiftmode,
                    TAICPU(p).oper[TAICPU(p).ops-1]^.shifterop^.shiftimm) then
                 begin
                   if TAICPU(p).oper[TAICPU(p).ops-1]^.typ=top_shifterop then
                     i:=TAICPU(p).ops-2
                   else
                     i:=TAICPU(p).ops-1;
                   if (TAICPU(p).oper[i]^.typ=top_reg) then
                     add_edge(getsupreg(TAICPU(p).oper[i]^.reg),RS_SP);
                   exit;
                 end;
             A_AND,
             A_EOR,
             A_ORR,
             A_TST:
               { ok in immediate form }
               if TAICPU(p).oper[TAICPU(p).ops-1]^.typ=top_const then
                 exit;
             else
               ;
           end;
           { add interferences for other registers }
           for i:=0 to TAICPU(p).ops-1 do
             begin
               case TAICPU(p).oper[i]^.typ of
                 top_reg:
                   if getregtype(TAICPU(p).oper[i]^.reg)=R_INTREGISTER then
                     add_edge(getsupreg(TAICPU(p).oper[i]^.reg),RS_SP);
                 top_ref:
                   begin
                     { sp can always be base, never be index }
                     if TAICPU(p).oper[i]^.ref^.index<>NR_NO then
                       add_edge(getsupreg(TAICPU(p).oper[i]^.ref^.index),RS_SP);
                     { in case of write back, the base register must be
                       different from the loaded/stored register }
                     if (TAICPU(p).oper[i]^.ref^.addressmode in [AM_PREINDEXED,AM_POSTINDEXED]) and
                        (TAICPU(p).oper[i]^.ref^.base<>NR_NO) then
                       begin
                         for j:=pred(i) downto 0 do
                           if TAICPU(p).oper[j]^.typ=TOP_REG then
                             add_edge(getsupreg(TAICPU(p).oper[j]^.reg),getsupreg(TAICPU(p).oper[i]^.ref^.base));
                       end;
                   end;
                 else
                   ;
               end;
             end;
         end;
     end;

end.
