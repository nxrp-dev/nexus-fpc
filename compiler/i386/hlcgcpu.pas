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
      procedure gen_loadfpu_loc_cgpara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt); override;
     public
      function a_call_name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara; override;
      procedure g_copyvaluepara_openarray(list: TAsmList; const ref: TReference; const lenloc: TLocation; arrdef: TArrayDef; destreg: TRegister); override;
      procedure g_releasevaluepara_openarray(list: TAsmList; arrdef: TArrayDef; const l: TLocation); override;
      procedure g_exception_reason_save(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const href: TReference); override;
      procedure g_exception_reason_save_const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference); override;
      procedure g_exception_reason_load(list: TAsmList; fromsize, tosize: TDef; const href: TReference; reg: TRegister); override;
      procedure g_exception_reason_discard(list: TAsmList; size: TDef; href: TReference); override;

      procedure g_intf_wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);override;
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

  procedure THLCGCPU.gen_loadfpu_loc_cgpara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt);
    var
      locsize : TCgSize;
      tmploc : TLocation;
      href   : TReference;
      StackSize   : LongInt;
    begin
      if not(l.size in [OS_32,OS_S32,OS_64,OS_S64,OS_128,OS_S128]) then
        locsize:=l.size
      else
        locsize:=int_float_cgsize(tcgsize2size[l.size]);
      case l.loc of
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER:
          begin
            case cgpara.location^.loc of
              LOC_REFERENCE:
                begin
                  StackSize:=align(locintsize,cgpara.alignment);
                  if (not paramanager.use_fixed_stack) and
                     (cgpara.location^.reference.index=NR_STACK_POINTER_REG) then
                    begin
                      cg.g_stackpointer_alloc(list,StackSize);
                      reference_reset_base(href,voidstackpointertype,NR_STACK_POINTER_REG,0,ctempposinvalid,voidstackpointertype.size,[]);
                    end
                  else
                    reference_reset_base(href,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                  cg.a_loadfpu_reg_ref(list,locsize,locsize,l.register,href);
                end;
              LOC_FPUREGISTER:
                begin
                  cg.a_loadfpu_reg_reg(list,locsize,cgpara.location^.size,l.register,cgpara.location^.register);
                end;
              { can happen if a record with only 1 "single field" is
                returned in a floating point register and then is directly
                passed to a regcall parameter }
              LOC_REGISTER:
                begin
                  tmploc:=l;
                  location_force_mem(list,tmploc,size);
                  case locsize of
                    OS_F32:
                      tmploc.size:=OS_32;
                    OS_F64:
                      tmploc.size:=OS_64;
                    else
                      InternalError(2010053116);
                  end;
                  cg.a_load_loc_cgpara(list,tmploc,cgpara);
                  location_freetemp(list,tmploc);
                end
              else
                InternalError(2010053003);
            end;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            case cgpara.location^.loc of
              LOC_REFERENCE:
                begin
                  { can't use TCGSize2Size[l.size], because the size of an
                    80 bit extended parameter can be either 10 or 12 bytes }
                  StackSize:=align(locintsize,cgpara.alignment);
                  if (not paramanager.use_fixed_stack) and
                     (cgpara.location^.reference.index=NR_STACK_POINTER_REG) then
                    begin
                      cg.g_stackpointer_alloc(list,StackSize);
                      reference_reset_base(href,voidstackpointertype,NR_STACK_POINTER_REG,0,ctempposinvalid,voidstackpointertype.size,[]);
                    end
                  else
                    reference_reset_base(href,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                  cg.a_loadmm_reg_ref(list,locsize,locsize,l.register,href,mms_movescalar);
                end;
              LOC_FPUREGISTER:
                begin
                  tmploc:=l;
                  location_force_mem(list,tmploc,size);
                  cg.a_loadfpu_ref_cgpara(list,tmploc.size,tmploc.reference,cgpara);
                  location_freetemp(list,tmploc);
                end;
              else
                InternalError(2010053004);
            end;
          end;
        LOC_REFERENCE,
        LOC_CREFERENCE :
          begin
            case cgpara.location^.loc of
              LOC_REFERENCE:
                begin
                  StackSize:=align(locintsize,cgpara.alignment);
                  if (not paramanager.use_fixed_stack) and
                     (cgpara.location^.reference.index=NR_STACK_POINTER_REG) then
                    cg.a_load_ref_cgpara(list,locsize,l.reference,cgpara)
                  else
                    begin
                      reference_reset_base(href,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                      cg.g_concatcopy(list,l.reference,href,StackSize);
                    end;
                end;
              LOC_FPUREGISTER:
                begin
                  cg.a_loadfpu_ref_cgpara(list,locsize,l.reference,cgpara);
                end;
              else
                InternalError(2010053005);
            end;
          end;
        else
          InternalError(2002042430);
      end;
    end;


  function THLCGCPU.a_call_name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara;
  var
    need_got_load: boolean;
  begin
    { Load GOT address to EBX before calling an external function.
      It is needed because GOT stubs for external function calls
      generated by a linker expect EBX as a GOT register. }
    need_got_load:=not (TargetInfo.system in systems_darwin) and
                   (cs_create_pic in CurrentSettings.ModuleSwitches) and
                   (tf_pic_uses_got in TargetInfo.flags) and
                   (po_external in pd.procoptions);
    if need_got_load then
      begin
        { Alloc EBX }
        getcpuregister(list, NR_PIC_OFFSET_REG);
        list.concat(TAICPU.op_reg_reg(A_MOV,S_L,CurrentProcInfo.got,NR_PIC_OFFSET_REG));
        include(CurrentProcInfo.flags,pi_needs_got);
      end;
    Result:=inherited a_call_name(list, pd, s, paras, forceresdef, weak);
    { Free EBX }
    if need_got_load then
      ungetcpuregister(list, NR_PIC_OFFSET_REG);
  end;


  procedure THLCGCPU.g_copyvaluepara_openarray(list: TAsmList; const ref: TReference; const lenloc: TLocation; arrdef: TArrayDef; destreg: TRegister);
    begin
      if paramanager.use_fixed_stack then
        begin
          inherited;
          exit;
        end;
      TCG386(cg).g_copyvaluepara_openarray(list,ref,lenloc,arrdef.elesize,destreg);
    end;


  procedure THLCGCPU.g_releasevaluepara_openarray(list: TAsmList; arrdef: TArrayDef; const l: TLocation);
    begin
      if paramanager.use_fixed_stack then
        begin
          inherited;
          exit;
        end;
      TCG386(cg).g_releasevaluepara_openarray(list,l);
    end;


  procedure THLCGCPU.g_exception_reason_save(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const href: TReference);
    begin
      if not(paramanager.use_fixed_stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_reg(A_PUSH,tcgsize2opsize[def_cgsize(tosize)],reg))
      else
        inherited
    end;


  procedure THLCGCPU.g_exception_reason_save_const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference);
    begin
      if not(paramanager.use_fixed_stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_const(A_PUSH,tcgsize2opsize[def_cgsize(size)],a))
      else
        inherited;
    end;


  procedure THLCGCPU.g_exception_reason_load(list: TAsmList; fromsize, tosize: TDef; const href: TReference; reg: TRegister);
    begin
      if not(paramanager.use_fixed_stack) and not(tf_use_psabieh in TargetInfo.flags) then
        list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[def_cgsize(tosize)],reg))
      else
        inherited;
    end;


  procedure THLCGCPU.g_exception_reason_discard(list: TAsmList; size: TDef; href: TReference);
    begin
      if not(paramanager.use_fixed_stack) and not(tf_use_psabieh in TargetInfo.flags) then
        begin
          getcpuregister(list,NR_FUNCTION_RESULT_REG);
          list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[def_cgsize(size)],NR_FUNCTION_RESULT_REG));
          ungetcpuregister(list,NR_FUNCTION_RESULT_REG);
        end;
    end;


  procedure THLCGCPU.g_intf_wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);
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
        paraloc: PCGParaLocation;
      begin
        if not (RS_ECX in paramanager.get_volatile_registers_int(procdef.proccalloption)) then
          exit(true);
        for i:=0 to procdef.paras.count-1 do
         begin
           hp:=TParaVarSym(procdef.paras[i]);
           procdef.init_paraloc_info(calleeside);
           paraloc:=hp.paraloc[calleeside].Location;
           while paraloc<>nil do
             begin
               if (paraloc^.Loc=LOC_REGISTER) and (getsupreg(paraloc^.register)=RS_ECX) then
                 exit(true);
               paraloc:=paraloc^.Next;
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
        if (procdef.proccalloption<>pocall_register) then
          begin
            { framepointer is pushed for nested procs }
            if procdef.parast.symtablelevel>normal_function_level then
              selfoffsetfromsp:=2*sizeof(aint)
            else
              selfoffsetfromsp:=sizeof(aint);
            reference_reset_base(href,voidstackpointertype,NR_ESP,selfoffsetfromsp+offs,ctempposinvalid,4,[]);
            cg.a_load_ref_reg(list,OS_ADDR,OS_ADDR,href,NR_EAX);
          end;
      end;

    procedure loadvmtto(reg: TRegister);
      var
        href : TReference;
      begin
        { mov  0(%eax),%reg ; load vmt}
        reference_reset_base(href,voidpointertype,NR_EAX,0,ctempposinvalid,4,[]);
        cg.a_load_ref_reg(list,OS_ADDR,OS_ADDR,href,reg);
      end;

    procedure op_onregmethodaddr(op: TAsmOp; reg: TRegister);
      var
        href : TReference;
      begin
        if (procdef.extnumber=$ffff) then
          InternalError(2000061312);
        { call/jmp  vmtoffs(%reg) ; method offs }
        reference_reset_base(href,voidpointertype,reg,TObjectDef(procdef.struct).vmtmethodoffset(procdef.extnumber),ctempposinvalid,4,[]);
        list.concat(TAICPU.op_ref(op,S_L,href));
      end;


    procedure loadmethodoffstoeax;
      var
        href : TReference;
      begin
        if (procdef.extnumber=$ffff) then
          InternalError(2000061313);
        { mov vmtoffs(%eax),%eax ; method offs }
        reference_reset_base(href,voidpointertype,NR_EAX,TObjectDef(procdef.struct).vmtmethodoffset(procdef.extnumber),ctempposinvalid,4,[]);
        cg.a_load_ref_reg(list,OS_ADDR,OS_ADDR,href,NR_EAX);
      end;


    var
      lab : TAsmSymbol;
      make_global : boolean;
      href : TReference;
    begin
      if not(procdef.proctypeoption in [potype_function,potype_procedure]) then
        InternalError(200006137);
      if not Assigned(procdef.struct) or
         (procdef.procoptions*[po_classmethod, po_staticmethod,
           po_methodpointer, po_interrupt, po_iocheck]<>[]) then
        InternalError(200006138);
      if procdef.owner.symtabletype<>ObjectSymtable then
        InternalError(200109191);

      make_global:=false;
      if (not CurrentModule.is_unit) or
         create_smartlink or
         (procdef.owner.defowner.owner.symtabletype=GlobalSymTable) then
        make_global:=true;

      if make_global then
        List.concat(TAISymbol.Createname_global(labelname,AT_FUNCTION,0,procdef))
      else
        List.concat(TAISymbol.Createname_hidden(labelname,AT_FUNCTION,0,procdef));

      { set param1 interface to self  }
      g_adjust_self_value(list,procdef,ioffset);

      if (po_virtualmethod in procdef.procoptions) and
          not is_objectpascal_helper(procdef.struct) then
        begin
          if (procdef.proccalloption=pocall_register) and is_ecx_used then
            begin
              { case 2 }
              list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EBX)); { allocate space for address}
              list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EAX));
              getselftoeax(8);
              loadvmtto(NR_EAX);
              loadmethodoffstoeax;
              { mov %eax,4(%esp) }
              reference_reset_base(href,voidstackpointertype,NR_ESP,4,ctempposinvalid,4,[]);
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
              lab:=CurrentAsmData.RefAsmSymbol(procdef.mangledname,AT_FUNCTION);
              list.concat(TAICPU.op_sym(A_JMP,S_NO,lab))
            end
          else
            list.concat(TAICPU.op_sym(A_JMP,S_NO,TCGX86(cg).get_darwin_call_stub(procdef.mangledname,false)))
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
  create_hlcodegen:=@create_hlcodegen_cpu;
end.
