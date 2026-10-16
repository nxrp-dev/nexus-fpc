{
    Copyright (c) 1998-2010 by Florian Klaempfl and Jonas Maebe
    Member of the Free Pascal development team

    This unit contains routines to create a pass-through high-level code
    generator. This is used by most regular code generators.

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

unit hlcgcpu;

{$i fpcdefs.inc}

interface

  uses
    GlobType,
    AAsmData,
    symtype,symdef,parabase,
    cgbase,cgutils,
    hlcgobj, hlcgx86;


  type
    THLCGCPU = class(THLCGX86)
     protected
      procedure Gen_LoadFPU_Loc_CGPara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt); override;
     public
      function A_Call_Name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara; override;
      procedure G_CopyValuePara_OpenArray(list: TAsmList; const ref: TReference; const lenloc: TLocation; arrdef: TArrayDef; destreg: TRegister); override;
      procedure G_ReleaseValuePara_OpenArray(list: TAsmList; arrdef: TArrayDef; const l: TLocation); override;
      procedure G_Exception_Reason_Save(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const href: TReference); override;
      procedure G_Exception_Reason_Save_Const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference); override;
      procedure G_Exception_Reason_Load(list: TAsmList; fromsize, tosize: TDef; const href: TReference; reg: TRegister); override;
      procedure G_Exception_Reason_Discard(list: TAsmList; size: TDef; href: TReference); override;

      procedure G_Intf_Wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);override;
    end;

implementation

  uses
    Globals, ProcInfo,
    Verbose,
    FModule,Systems,
    aasmbase,aasmtai,
    paramgr,
    symconst,SymSym,defutil,
    cpubase,aasmcpu,tgobj,cgobj,cgx86,cgcpu;

  { thlcgcpu }

  procedure THLCGCPU.Gen_LoadFPU_Loc_CGPara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt);
    var
      locsize : TCgSize;
      tmploc : TLocation;
      href   : TReference;
      StackSize   : LongInt;
    begin
      if not(l.Size in [OS_32,OS_S32,OS_64,OS_S64,OS_128,OS_S128]) then
        locsize:=l.Size
      else
        locsize:=Int_Float_CGSize(TCgSize2Size[l.Size]);
      case l.Loc of
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER:
          begin
            case cgpara.Location^.Loc of
              LOC_REFERENCE:
                begin
                  StackSize:=align(locintsize,cgpara.Alignment);
                  if (not ParaManager.Use_Fixed_Stack) and
                     (cgpara.Location^.Reference.Index=NR_STACK_POINTER_REG) then
                    begin
                      cg.G_StackPointer_Alloc(list,StackSize);
                      Reference_Reset_Base(href,VoidStackPointerType,NR_STACK_POINTER_REG,0,CTempPosInvalid,VoidStackPointerType.Size,[]);
                    end
                  else
                    Reference_Reset_Base(href,VoidStackPointerType,cgpara.Location^.Reference.Index,cgpara.Location^.Reference.Offset,CTempPosInvalid,cgpara.Alignment,[]);
                  cg.A_LoadFPU_Reg_Ref(list,locsize,locsize,l.Register,href);
                end;
              LOC_FPUREGISTER:
                begin
                  cg.A_LoadFPU_Reg_Reg(list,locsize,cgpara.Location^.Size,l.Register,cgpara.Location^.Register);
                end;
              { can happen if a record with only 1 "single field" is
                returned in a floating point register and then is directly
                passed to a regcall parameter }
              LOC_REGISTER:
                begin
                  tmploc:=l;
                  Location_Force_Mem(list,tmploc,size);
                  case locsize of
                    OS_F32:
                      tmploc.Size:=OS_32;
                    OS_F64:
                      tmploc.Size:=OS_64;
                    else
                      InternalError(2010053116);
                  end;
                  cg.A_Load_Loc_CGPara(list,tmploc,cgpara);
                  location_freetemp(list,tmploc);
                end
              else
                InternalError(2010053003);
            end;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            case cgpara.Location^.Loc of
              LOC_REFERENCE:
                begin
                  { can't use TCGSize2Size[l.size], because the size of an
                    80 bit extended parameter can be either 10 or 12 bytes }
                  StackSize:=align(locintsize,cgpara.Alignment);
                  if (not ParaManager.Use_Fixed_Stack) and
                     (cgpara.Location^.Reference.Index=NR_STACK_POINTER_REG) then
                    begin
                      cg.G_StackPointer_Alloc(list,StackSize);
                      Reference_Reset_Base(href,VoidStackPointerType,NR_STACK_POINTER_REG,0,CTempPosInvalid,VoidStackPointerType.Size,[]);
                    end
                  else
                    Reference_Reset_Base(href,VoidStackPointerType,cgpara.Location^.Reference.Index,cgpara.Location^.Reference.Offset,CTempPosInvalid,cgpara.Alignment,[]);
                  cg.A_LoadMM_Reg_Ref(list,locsize,locsize,l.Register,href,MMS_MoveScalar);
                end;
              LOC_FPUREGISTER:
                begin
                  tmploc:=l;
                  Location_Force_Mem(list,tmploc,size);
                  cg.A_LoadFPU_Ref_CGPara(list,tmploc.Size,tmploc.Reference,cgpara);
                  location_freetemp(list,tmploc);
                end;
              else
                InternalError(2010053004);
            end;
          end;
        LOC_REFERENCE,
        LOC_CREFERENCE :
          begin
            case cgpara.Location^.Loc of
              LOC_REFERENCE:
                begin
                  StackSize:=align(locintsize,cgpara.Alignment);
                  if (not ParaManager.Use_Fixed_Stack) and
                     (cgpara.Location^.Reference.Index=NR_STACK_POINTER_REG) then
                    cg.A_Load_Ref_CGPara(list,locsize,l.Reference,cgpara)
                  else
                    begin
                      Reference_Reset_Base(href,VoidStackPointerType,cgpara.Location^.Reference.Index,cgpara.Location^.Reference.Offset,CTempPosInvalid,cgpara.Alignment,[]);
                      cg.G_ConcatCopy(list,l.Reference,href,StackSize);
                    end;
                end;
              LOC_FPUREGISTER:
                begin
                  cg.A_LoadFPU_Ref_CGPara(list,locsize,l.Reference,cgpara);
                end;
              else
                InternalError(2010053005);
            end;
          end;
        else
          InternalError(2002042430);
      end;
    end;


  function THLCGCPU.A_Call_Name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara;
  var
    need_got_load: boolean;
  begin
    { Load GOT address to EBX before calling an external function.
      It is needed because GOT stubs for external function calls
      generated by a linker expect EBX as a GOT register. }
    need_got_load:=not (TargetInfo.system in systems_darwin) and
                   (cs_create_pic in CurrentSettings.ModuleSwitches) and
                   (tf_pic_uses_got in TargetInfo.flags) and
                   (po_external in pd.ProcOptions);
    if need_got_load then
      begin
        { Alloc EBX }
        GetCPURegister(list, NR_PIC_OFFSET_REG);
        list.concat(TAICPU.op_reg_reg(A_MOV,S_L,CurrentProcInfo.got,NR_PIC_OFFSET_REG));
        include(CurrentProcInfo.flags,pi_needs_got);
      end;
    Result:=inherited A_Call_Name(list, pd, s, paras, forceresdef, weak);
    { Free EBX }
    if need_got_load then
      UngetCPURegister(list, NR_PIC_OFFSET_REG);
  end;


  procedure THLCGCPU.G_CopyValuePara_OpenArray(list: TAsmList; const ref: TReference; const lenloc: TLocation; arrdef: TArrayDef; destreg: TRegister);
    begin
      if ParaManager.Use_Fixed_Stack then
        begin
          inherited;
          exit;
        end;
      TCG386(cg).G_CopyValuePara_OpenArray(list,ref,lenloc,arrdef.EleSize,destreg);
    end;


  procedure THLCGCPU.G_ReleaseValuePara_OpenArray(list: TAsmList; arrdef: TArrayDef; const l: TLocation);
    begin
      if ParaManager.Use_Fixed_Stack then
        begin
          inherited;
          exit;
        end;
      TCG386(cg).G_ReleaseValuePara_OpenArray(list,l);
    end;


  procedure THLCGCPU.G_Exception_Reason_Save(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const href: TReference);
    begin
      if not(ParaManager.Use_Fixed_Stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_reg(A_PUSH,tcgsize2opsize[Def_CGSize(tosize)],reg))
      else
        inherited
    end;


  procedure THLCGCPU.G_Exception_Reason_Save_Const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference);
    begin
      if not(ParaManager.Use_Fixed_Stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_const(A_PUSH,tcgsize2opsize[Def_CGSize(size)],a))
      else
        inherited;
    end;


  procedure THLCGCPU.G_Exception_Reason_Load(list: TAsmList; fromsize, tosize: TDef; const href: TReference; reg: TRegister);
    begin
      if not(ParaManager.Use_Fixed_Stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[Def_CGSize(tosize)],reg))
      else
        inherited;
    end;


  procedure THLCGCPU.G_Exception_Reason_Discard(list: TAsmList; size: TDef; href: TReference);
    begin
      if not(ParaManager.Use_Fixed_Stack) and not(tf_use_psabieh in TargetInfo.flags) then
        begin
          GetCPURegister(list,NR_FUNCTION_RESULT_REG);
          list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[Def_CGSize(size)],NR_FUNCTION_RESULT_REG));
          UngetCPURegister(list,NR_FUNCTION_RESULT_REG);
        end;
    end;


  procedure THLCGCPU.G_Intf_Wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);
    {
    possible calling conventions:
                  default stdcall cdecl pascal register
    default(0):      OK     OK    OK     OK       OK
    virtual(1):      OK     OK    OK     OK       OK(2 or 1)

    (0):
        set self parameter to correct value
        jmp mangledname

    (1): The wrapper code use %ecx to reach the virtual method address
         set self to correct value
         move self,%eax
         mov  0(%eax),%ecx ; load vmt
         jmp  vmtoffs(%ecx) ; method offs

    (2): Virtual use values pushed on stack to reach the method address
         so the following code be generated:
         set self to correct value
         push %ebx ; allocate space for function address
         push %eax
         mov  self,%eax
         mov  0(%eax),%eax ; load vmt
         mov  vmtoffs(%eax),eax ; method offs
         mov  %eax,4(%esp)
         pop  %eax
         ret  0; jmp the address

    }

    { returns whether ECX is used (either as a parameter or is nonvolatile and shouldn't be changed) }
    function is_ecx_used: boolean;
      var
        i: Integer;
        hp: TParaVarSym;
        ParaLoc: PCGParaLocation;
      begin
        if not (RS_ECX in ParaManager.Get_Volatile_Registers_Int(procdef.ProcCallOption)) then
          exit(true);
        for i:=0 to procdef.paras.count-1 do
         begin
           hp:=TParaVarSym(procdef.paras[i]);
           procdef.Init_ParaLoc_Info(calleeside);
           ParaLoc:=hp.ParaLoc[calleeside].Location;
           while ParaLoc<>nil do
             begin
               if (ParaLoc^.Loc=LOC_REGISTER) and (GetSupReg(ParaLoc^.Register)=RS_ECX) then
                 exit(true);
               ParaLoc:=ParaLoc^.Next;
             end;
         end;
        Result:=false;
      end;

    procedure getselftoeax(offs: LongInt);
      var
        href : TReference;
        selfoffsetfromsp : LongInt;
      begin
        { mov offset(%esp),%eax }
        if (procdef.ProcCallOption<>pocall_register) then
          begin
            { framepointer is pushed for nested procs }
            if procdef.ParaST.SymTableLevel>NormalFunctionLevel then
              selfoffsetfromsp:=2*sizeof(aint)
            else
              selfoffsetfromsp:=sizeof(aint);
            Reference_Reset_Base(href,VoidStackPointerType,NR_ESP,selfoffsetfromsp+offs,CTempPosInvalid,4,[]);
            cg.A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,NR_EAX);
          end;
      end;

    procedure loadvmtto(reg: TRegister);
      var
        href : TReference;
      begin
        { mov  0(%eax),%reg ; load vmt}
        Reference_Reset_Base(href,VoidPointerType,NR_EAX,0,CTempPosInvalid,4,[]);
        cg.A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,reg);
      end;

    procedure op_onregmethodaddr(op: TAsmOp; reg: TRegister);
      var
        href : TReference;
      begin
        if (procdef.ExtNumber=$ffff) then
          InternalError(2000061312);
        { call/jmp  vmtoffs(%reg) ; method offs }
        Reference_Reset_Base(href,VoidPointerType,reg,TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber),CTempPosInvalid,4,[]);
        list.concat(TAICPU.op_ref(op,S_L,href));
      end;


    procedure loadmethodoffstoeax;
      var
        href : TReference;
      begin
        if (procdef.ExtNumber=$ffff) then
          InternalError(2000061313);
        { mov vmtoffs(%eax),%eax ; method offs }
        Reference_Reset_Base(href,VoidPointerType,NR_EAX,TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber),CTempPosInvalid,4,[]);
        cg.A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,NR_EAX);
      end;


    var
      lab : TAsmSymbol;
      make_global : boolean;
      href : TReference;
    begin
      if not(procdef.ProcTypeOption in [potype_function,potype_procedure]) then
        InternalError(200006137);
      if not Assigned(procdef.struct) or
         (procdef.ProcOptions*[po_classmethod, po_staticmethod,
           po_methodpointer, po_interrupt, po_iocheck]<>[]) then
        InternalError(200006138);
      if procdef.owner.SymTableType<>ObjectSymtable then
        InternalError(200109191);

      make_global:=false;
      if (not CurrentModule.IsUnit) or
         create_smartlink or
         (procdef.owner.DefOwner.owner.SymTableType=GlobalSymTable) then
        make_global:=true;

      if make_global then
        List.concat(TAISymbol.Createname_global(labelname,AT_FUNCTION,0,procdef))
      else
        List.concat(TAISymbol.Createname_hidden(labelname,AT_FUNCTION,0,procdef));

      { set param1 interface to self  }
      G_Adjust_Self_Value(list,procdef,ioffset);

      if (po_virtualmethod in procdef.ProcOptions) and
          not Is_ObjectPascal_Helper(procdef.struct) then
        begin
          if (procdef.ProcCallOption=pocall_register) and is_ecx_used then
            begin
              { case 2 }
              list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EBX)); { allocate space for address}
              list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EAX));
              getselftoeax(8);
              loadvmtto(NR_EAX);
              loadmethodoffstoeax;
              { mov %eax,4(%esp) }
              Reference_Reset_Base(href,VoidStackPointerType,NR_ESP,4,CTempPosInvalid,4,[]);
              list.concat(TAICPU.op_reg_ref(A_MOV,S_L,NR_EAX,href));
              { pop  %eax }
              list.concat(TAICPU.op_reg(A_POP,S_L,NR_EAX));
              { ret  ; jump to the address }
              list.concat(TAICPU.op_none(A_RET,S_L));
            end
          else
            begin
              { case 1 }
              getselftoeax(0);
              loadvmtto(NR_ECX);
              op_onregmethodaddr(A_JMP,NR_ECX);
            end;
        end
      { case 0 }
      else
        begin
          if (TargetInfo.system <> system_i386_darwin) then
            begin
              lab:=CurrentAsmData.RefAsmSymbol(procdef.MangledName,AT_FUNCTION);
              list.concat(TAICPU.op_sym(A_JMP,S_NO,lab))
            end
          else
            list.concat(TAICPU.op_sym(A_JMP,S_NO,TCGX86(cg).get_darwin_call_stub(procdef.MangledName,false)))
        end;

      List.concat(TAISymbolEnd.Createname(labelname));
    end;


  procedure create_hlcodegen_cpu(hlcgobjhelpers: THLCGObjHelpersClass);
    begin
      hlcg:=THLCGCPU.create(hlcgobjhelpers);
      create_codegen;
    end;



begin
  CHLCGObj:=THLCGCPU;
  Create_HLCodeGen:=@create_hlcodegen_cpu;
end.
