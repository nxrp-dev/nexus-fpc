{
    Copyright (c) 2002 by Florian Klaempfl

    This unit contains the CPU specific part of tprocinfo

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

{ This unit contains the CPU specific part of tprocinfo. }
unit cpupi;

{$i fpcdefs.inc}

  interface

    uses
       psub,ProcInfo,psabiehpi,AAsmData;

    type
       TCPUProcInfo = class(TPSABIEHProcInfo)
         constructor Create(AParent:TProcInfo);override;
         procedure Set_First_Temp_Offset;override;
         function Calc_StackFrame_Size:LongInt;override;
         procedure Generate_Parameter_Info;override;
         procedure Allocate_GOT_Register(AList: TAsmList);override;
       end;


  implementation

    uses
      CUtils,
      Systems,Globals,GlobType,
      cgobj,tgobj,paramgr,
      cpubase,
      cgutils,
      symconst;

    constructor TCPUProcInfo.Create(AParent:TProcInfo);
      begin
        inherited Create(AParent);
        GOT:=NR_EBX;
      end;


    procedure TCPUProcInfo.Set_First_Temp_Offset;
      begin
        if ParaManager.Use_Fixed_Stack then
          begin
            if not(po_assembler in ProcDef.ProcOptions) and
               (TG.Direction > 0) then
              TG.SetFirstTemp(TG.Direction*MaxPushedParaSize);
            if (TG.Direction < 0) and
               not(po_nostackframe in ProcDef.ProcOptions) then
              { compensate for the return address and the "pushl %ebp" }
              TG.SetAlignmentMismatch(sizeof(PInt)*2);
          end;
      end;


    function TCPUProcInfo.Calc_StackFrame_Size:LongInt;
      begin
        { align to 4 bytes at least
          otherwise all those subl $2,%esp are meaningless PM }
        if TargetInfo.stackalign<=4 then
          Result:=Align(TG.Direction*TG.LastTemp,min(CurrentSettings.Alignment.LocalAlignMax,4))
        else
          { aligned during stack frame allocation, because also depends number
            of saved registers }
          Result:=TG.Direction*TG.LastTemp+MaxPushedParaSize;
      end;


    procedure TCPUProcInfo.Generate_Parameter_Info;
      begin
        inherited Generate_Parameter_Info;
        { Para_stack_size is only used to determine how many bytes to remove
          from the stack at the end of the procedure (in the "ret $xx").
          If the stack is fixed, nothing has to be removed by the callee, except
          if a 16 byte aligned stack on i386-linux is used     }
        if ParaManager.Use_Fixed_Stack and not(TargetInfo.abi=abi_i386_dynalignedstack) then
          ParaStackSize := 0;
      end;


    procedure TCPUProcInfo.Allocate_GOT_Register(AList: TAsmList);
      begin
        if (pi_uses_threadvar in Flags) and (tf_section_threadvars in TargetInfo.Flags) and (CurrentSettings.TLSModel in [tlsm_global_dynamic]) then
          begin
            { FIXME: It is better to use an imaginary register for GOT and
              if EBX is needed for some reason just allocate EBX and
              copy GOT into it before its usage. }
            cg.GetCPURegister(AList,NR_EBX);
            GOT := NR_EBX;
          end
        else if cs_create_pic in CurrentSettings.ModuleSwitches then
          GOT := cg.GetAddressRegister(AList);
      end;

begin
   CProcInfo:=TCPUProcInfo;
end.
