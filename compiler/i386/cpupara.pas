{
    Copyright (c) 2002 by Florian Klaempfl

    Generates the argument location information for i386

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
unit cpupara;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,
       aasmtai,AAsmData,cpubase,cgbase,cgutils,
       symconst,symtype,SymSym,symdef,
       parabase,paramgr;

    type
       TCPUParaManager = class(TParaManager)
          function param_use_paraloc(const cgpara:TCGPara):boolean;override;
          function ret_in_param(def:TDef;pd:TAbstractProcDef):boolean;override;
          function push_addr_param(VarSpez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;override;
          function get_para_align(calloption : TProcCallOption):byte;override;
          function get_volatile_registers_int(calloption : TProcCallOption):TCPURegisterSet;override;
          function get_volatile_registers_fpu(calloption : TProcCallOption):TCPURegisterSet;override;
          function get_volatile_registers_mm(calloption : TProcCallOption):TCPURegisterSet;override;
          function get_saved_registers_int(calloption : TProcCallOption):TCPURegisterArray;override;
          function create_paraloc_info(p : TAbstractProcDef; side: TCallerCallee):LongInt;override;
          function create_varargs_paraloc_info(p : TAbstractProcDef; side: TCallerCallee; varargspara:TVarArgsParaList):LongInt;override;
          procedure createtempparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);override;
          function get_funcretloc(p : TAbstractProcDef; side: TCallerCallee; forcetempdef: TDef): TCGPara;override;
       private
          procedure create_stdcall_paraloc_info(p : TAbstractProcDef; side: TCallerCallee;paras:TParaList;var parasize:LongInt);
          procedure create_register_paraloc_info(p : TAbstractProcDef; side: TCallerCallee;paras:TParaList;var parareg,parasize:LongInt);
       end;


  implementation

    uses
       CUtils,SysUtils,
       Systems,Verbose,
       SymTable,
       Globals,defutil;

      const
        parasupregs : array[0..2] of TSuperRegister = (RS_EAX,RS_EDX,RS_ECX);

{****************************************************************************
                                tcpuparamanager
****************************************************************************}

    function TCPUParaManager.param_use_paraloc(const cgpara:TCGPara):boolean;
      var
        ParaLoc : PCGParaLocation;
      begin
        if not Assigned(cgpara.location) then
          InternalError(200410102);
        result:=true;
        { All locations are LOC_REFERENCE }
        ParaLoc:=cgpara.location;
        while Assigned(ParaLoc) do
          begin
            if (ParaLoc^.loc<>LOC_REFERENCE) then
              begin
                result:=false;
                exit;
              end;
            ParaLoc:=ParaLoc^.next;
          end;
      end;


    function TCPUParaManager.ret_in_param(def:TDef;pd:TAbstractProcDef):boolean;
      var
        size: LongInt;
      begin
        if handle_common_ret_in_param(def,pd,result) then
          exit;
        case TargetInfo.system of
          system_i386_win32 :
            begin
              case def.typ of
                recorddef :
                  begin
                    { Win32 GCC returns small records in the FUNCTION_RETURN_REG up to 8 bytes in registers.

                      For stdcall and register we follow delphi instead of GCC which returns
                      only records of a size of 1,2 or 4 bytes in FUNCTION_RETURN_REG }
                    if ((pd.ProcCallOption in [pocall_stdcall,pocall_register]) and
                        (def.size in [1,2,4])) or
                       ((pd.ProcCallOption in cdecl_pocalls) and
                        (def.size>0) and
                        (def.size<=8)) then
                     begin
                       result:=false;
                       exit;
                     end;
                  end;
                else
                  ;
              end;
            end;
          system_i386_darwin,
          system_i386_iphonesim :
            begin
              if pd.ProcCallOption in cdecl_pocalls then
                begin
                  case def.typ of
                    recorddef :
                      begin
                        size:=def.size;
                        if (size>0) and
                           (size<=8) and
                           { only if size is a power of 2 }
                           ((size and (size-1)) = 0) then
                          begin
                            result:=false;
                            exit;
                          end;
                      end;
                    procvardef:
                      begin
                        result:=false;
                        exit;
                      end;
                    else
                      ;
                  end;
              end;
            end;
          else
            ;
        end;
        result:=inherited ret_in_param(def,pd);
      end;


    function TCPUParaManager.push_addr_param(VarSpez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;
      begin
        result:=false;
        { var,out,constref always require address }
        if VarSpez in [vs_var,vs_out,vs_constref] then
          begin
            result:=true;
            exit;
          end;
        { Only vs_const, vs_value here }
        case def.typ of
          variantdef :
            begin
              { variants are small enough to be passed by value except if
                required by the windows api

                variants are somethings very delphi/windows specific so do it like
                windows/delphi (FK)
              }
              if ((TargetInfo.system=system_i386_win32) and
                 (calloption in [pocall_stdcall,pocall_safecall]) and
                 (VarSpez=vs_const)) or
                 (calloption=pocall_register) then
                result:=true
              else
                result:=false;
            end;
          formaldef :
            result:=true;
          recorddef :
            begin
              { Delphi stdcall passes records on the stack for call by value }
              if (TargetInfo.system=system_i386_win32) and
                 (calloption=pocall_stdcall) and
                 (VarSpez=vs_value) then
                result:=false
              else
                result:=
                  (not(calloption in (cdecl_pocalls)) and
                   (def.size>sizeof(aint))) or
                  ((calloption = pocall_mwpascal) and
                   (VarSpez=vs_const));
            end;
          arraydef :
            begin
              { array of const values are pushed on the stack as
                well as dyn. arrays }
              if (calloption in cdecl_pocalls) then
                result:=not(is_array_of_const(def) or
                        is_dynamic_array(def))
              else
                begin
                  result:=(
                           (TArrayDef(def).HighRange>=TArrayDef(def).LowRange) and
                           (def.size>sizeof(aint))
                          ) or
                          is_open_array(def) or
                          is_array_of_const(def) or
                          is_array_constructor(def);
                end;
            end;
          objectdef :
            result:=Is_Object(def);
          stringdef :
            result:= (TStringDef(def).StringType in [st_shortstring,st_longstring]);
          procvardef :
            result:=not(calloption in cdecl_pocalls) and not TProcVarDef(def).Is_AddressOnly;
          setdef :
            result:=not(calloption in cdecl_pocalls) and (not is_smallset(def));
          else
            ;
        end;
      end;


    function TCPUParaManager.get_para_align(calloption : TProcCallOption):byte;
      begin
        if calloption=pocall_oldfpccall then
          result:=4
        else
          result:=std_param_align;
      end;


    function TCPUParaManager.get_volatile_registers_int(calloption : TProcCallOption):TCPURegisterSet;
      begin
        case calloption of
          pocall_internproc :
            result:=[];
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_syscall,
          pocall_cppdecl,
          pocall_mwpascal,
          pocall_pascal:
            result:=[RS_EAX,RS_EDX,RS_ECX];
          pocall_far16,
          pocall_oldfpccall :
            result:=[RS_EAX,RS_EDX,RS_ECX,RS_ESI,RS_EDI,RS_EBX];
          else
            InternalError(200309071);
        end;
      end;


    function TCPUParaManager.get_volatile_registers_fpu(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[0..first_fpu_imreg-1];
      end;


    function TCPUParaManager.get_volatile_registers_mm(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[0..first_mm_imreg-1];
      end;


    function TCPUParaManager.get_saved_registers_int(calloption : TProcCallOption):TCPURegisterArray;
      const
        saveregs : TCPURegisterArray = (RS_EBX,RS_ESI,RS_EDI,RS_EBP);
        saveregs_oldfpccall : TCPURegisterArray = (RS_EBP);
      begin
        case calloption of
          pocall_internproc,
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_syscall,
          pocall_cppdecl,
          pocall_mwpascal,
          pocall_pascal:
            result:=saveregs;
          pocall_far16,
          pocall_oldfpccall :
            result:=saveregs_oldfpccall;
          else
            InternalError(2018050401);
        end;
      end;


    function  TCPUParaManager.get_funcretloc(p : TAbstractProcDef; side: TCallerCallee; forcetempdef: TDef): TCGPara;
      var
        retcgsize  : TCgSize;
        ParaLoc : PCGParaLocation;
        fdef,
        usedef: TDef;
        handled: boolean;
      begin
        if not Assigned(forcetempdef) then
          usedef:=p.ReturnDef
        else
          usedef:=forcetempdef;
        { on darwin/i386, if a record has only one field and that field is a
          single or double, it has to be returned like a single/double }
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
           ((usedef.typ=recorddef) or
            Is_Object(usedef)) and
           TAbstractRecordSymTable(TAbstractRecordDef(usedef).SymTable).Has_Single_Field(fdef) and
           (fdef.typ=floatdef) and
           (TFloatDef(fdef).FloatType in [S32Real,S64Real]) then
          usedef:=fdef;

        handled:=set_common_funcretloc_info(p,usedef,retcgsize,result);
        { normally forcetempdef is passed straight through to
          set_common_funcretloc_info and that one will correctly determine whether
          the location is a temporary one, but that doesn't work here because we
          sometimes have to change the type }
        result.temporary:=Assigned(forcetempdef);
        if handled then
          exit;

        { darwin/x86 requires that results < sizeof(aint) are sign/zero
          extended to sizeof(aint) }
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
           (side=calleeside) and
           (result.intsize>0) and
           (result.intsize<sizeof(aint)) then
          begin
            result.def:=SIntType;
            result.intsize:=sizeof(aint);
            retcgsize:=OS_SINT;
            result.size:=retcgsize;
          end;

        { Return in FPU register? }
        if result.def.typ=floatdef then
          begin
            ParaLoc:=result.add_location;
            ParaLoc^.loc:=LOC_FPUREGISTER;
            ParaLoc^.register:=NR_FPU_RESULT_REG;
            ParaLoc^.size:=retcgsize;
            ParaLoc^.def:=result.def;
          end
        else
         { Return in register }
          begin
            ParaLoc:=result.add_location;
            ParaLoc^.loc:=LOC_REGISTER;
            if retcgsize in [OS_64,OS_S64] then
             begin
               { low 32bits }
               if side=callerside then
                 ParaLoc^.register:=NR_FUNCTION_RESULT64_LOW_REG
               else
                 ParaLoc^.register:=NR_FUNCTION_RETURN64_LOW_REG;
               ParaLoc^.size:=OS_32;
               ParaLoc^.def:=U32IntType;

               { high 32bits }
               ParaLoc:=result.add_location;
               ParaLoc^.loc:=LOC_REGISTER;
               if side=callerside then
                 ParaLoc^.register:=NR_FUNCTION_RESULT64_HIGH_REG
               else
                 ParaLoc^.register:=NR_FUNCTION_RETURN64_HIGH_REG;
               ParaLoc^.size:=OS_32;
               ParaLoc^.def:=U32IntType;
             end
            else
             begin
               ParaLoc^.size:=retcgsize;
               ParaLoc^.def:=result.def;
               if side=callerside then
                 ParaLoc^.register:=newreg(R_INTREGISTER,RS_FUNCTION_RESULT_REG,cgsize2subreg(R_INTREGISTER,retcgsize))
               else
                 ParaLoc^.register:=newreg(R_INTREGISTER,RS_FUNCTION_RETURN_REG,cgsize2subreg(R_INTREGISTER,retcgsize));
             end;
          end;
      end;


    procedure TCPUParaManager.create_stdcall_paraloc_info(p : TAbstractProcDef; side: TCallerCallee;paras:TParaList;var parasize:LongInt);
      var
        i  : integer;
        hp : TParaVarSym;
        paradef : TDef;
        ParaLoc : PCGParaLocation;
        l,
        paralen,
        varalign   : LongInt;
        paraalign  : shortint;
        paracgsize : TCgSize;
        firstparaloc,
        pushaddr   : boolean;
      begin
        paraalign:=get_para_align(p.ProcCallOption);
        { we push Flags and CS as long
          to cope with the IRETD
          and we save 6 register + 4 selectors }
        if (po_interrupt in p.ProcOptions) and (side=calleeside) then
          inc(parasize,8+6*4+4*2);
        { Offset is calculated like:
           sub esp,12
           mov [esp+8],para3
           mov [esp+4],para2
           mov [esp],para1
           call function
          That means for pushes the para with the
          highest offset (see para3) needs to be pushed first
        }
        if p.ProcCallOption in pushleftright_pocalls then
          i:=paras.count-1
        else
          i:=0;
        while ((p.ProcCallOption in pushleftright_pocalls) and (i>=0)) or
              (not(p.ProcCallOption in pushleftright_pocalls) and (i<=paras.count-1)) do
          begin
            hp:=TParaVarSym(paras[i]);
            paradef:=hp.vardef;

            { syscall for AROS can have already a paraloc set }
            if (vo_has_explicit_paraloc in hp.VarOptions) then
              begin
                { on AROS-i386, only the libbase can have explicit paraloc }
                if not (vo_is_syscall_lib in hp.VarOptions) then
                  InternalError(2016090105);
                if p.ProcCallOption in pushleftright_pocalls then
                  dec(i)
                else
                  inc(i);
                continue;
              end;

            pushaddr:=push_addr_param(hp.VarSpez,paradef,p.ProcCallOption);
            if pushaddr then
              begin
                paralen:=sizeof(aint);
                paracgsize:=OS_ADDR;
                paradef:=CPointerDef.GetReusable_No_Free(paradef);
              end
            else
              begin
                paralen:=push_size(hp.VarSpez,paradef,p.ProcCallOption);
                paracgsize:=def_cgsize(paradef);
              end;
            hp.ParaLoc[side].reset;
            hp.ParaLoc[side].size:=paracgsize;
            hp.ParaLoc[side].intsize:=paralen;
            hp.ParaLoc[side].def:=paradef;
            hp.ParaLoc[side].Alignment:=paraalign;
            { darwin/x86 requires that parameters < sizeof(aint) are sign/ }
            { zero extended to sizeof(aint)                                }
            if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
               (side = callerside) and
               (paralen > 0) and
               (paralen < sizeof(aint)) then
              begin
                paracgsize:=OS_SINT;
                paradef:=SIntType;
              end;
            { Copy to stack? }
            if (paracgsize=OS_NO) or
               (use_fixed_stack) then
              begin
                ParaLoc:=hp.ParaLoc[side].add_location;
                ParaLoc^.loc:=LOC_REFERENCE;
                ParaLoc^.size:=paracgsize;
                ParaLoc^.def:=paradef;
                if side=callerside then
                  ParaLoc^.reference.index:=NR_STACK_POINTER_REG
                else
                  ParaLoc^.reference.index:=NR_FRAME_POINTER_REG;
                varalign:=Used_Align(Size_2_Align(paralen),paraalign,paraalign);

                { don't let push_size return 16, because then we can    }
                { read past the end of the heap since the value is only }
                { 10 bytes long (JM)                                    }
                if (paracgsize = OS_F80) and
                   (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
                  paralen:=16;
                ParaLoc^.reference.offset:=parasize;
                if side=calleeside then
                  inc(ParaLoc^.reference.offset,TargetInfo.first_parm_offset);
                parasize:=align(parasize+paralen,varalign);
              end
            else
              begin
                if paralen=0 then
                  InternalError(2005011606);
                firstparaloc:=true;
                while (paralen>0) do
                  begin
                    ParaLoc:=hp.ParaLoc[side].add_location;
                    ParaLoc^.loc:=LOC_REFERENCE;
                    { single and double need a single location }
                    if (paracgsize in [OS_F64,OS_F32]) then
                      begin
                        ParaLoc^.size:=paracgsize;
                        ParaLoc^.def:=paradef;
                        l:=paralen;
                      end
                    else
                      begin
                        { We can allocate at maximum 32 bits per location }
                        if paralen>sizeof(aint) then
                          begin
                            l:=sizeof(aint);
                            ParaLoc^.def:=UIntType;
                          end
                        else
                          begin
                            l:=paralen;
                            ParaLoc^.def:=get_paraloc_def(paradef,l,firstparaloc);
                          end;
                        ParaLoc^.size:=int_cgsize(l);
                      end;
                    if (side=callerside) or
                       (po_nostackframe in p.ProcOptions) then
                      ParaLoc^.reference.index:=NR_STACK_POINTER_REG
                    else
                      ParaLoc^.reference.index:=NR_FRAME_POINTER_REG;
                    varalign:=Used_Align(Size_2_Align(l),paraalign,paraalign);
                    ParaLoc^.reference.offset:=parasize;
                    if side=calleeside then
                      if not(po_nostackframe in p.ProcOptions) then
                        inc(ParaLoc^.reference.offset,TargetInfo.first_parm_offset)
                      else
                        { return address }
                        inc(ParaLoc^.reference.offset,4);
                    parasize:=align(parasize+l,varalign);
                    dec(paralen,l);
                    firstparaloc:=false;
                  end;
              end;
            if p.ProcCallOption in pushleftright_pocalls then
              dec(i)
            else
              inc(i);
          end;
      end;


    procedure TCPUParaManager.create_register_paraloc_info(p : TAbstractProcDef; side: TCallerCallee;paras:TParaList;
                                                            var parareg,parasize:LongInt);
      var
        hp : TParaVarSym;
        paradef : TDef;
        ParaLoc : PCGParaLocation;
        paracgsize : TCgSize;
        i : integer;
        l,
        paralen,
        varalign : LongInt;
        paraalign : shortint;
        pass : byte;
        firstparaloc,
        pushaddr : boolean;
      begin
        if paras.count=0 then
          exit;
        paraalign:=get_para_align(p.ProcCallOption);

        { clean up here so we can later detect properly if a parameter has been
          assigned or not
        }
        for i:=0 to paras.count-1 do
          TParaVarSym(paras[i]).ParaLoc[side].reset;
        { Register parameters are assigned from left to right,
          stack parameters from right to left so assign first the
          register parameters in a first pass, in the second
          pass all unhandled parameters are done }
        for pass:=1 to 2 do
          begin
            if pass=1 then
              i:=0
            else
              i:=paras.count-1;
            while true do
              begin
                hp:=TParaVarSym(paras[i]);
                paradef:=hp.vardef;
                if not(Assigned(hp.ParaLoc[side].location)) then
                  begin
                    pushaddr:=push_addr_param(hp.VarSpez,hp.vardef,p.ProcCallOption);
                    if pushaddr then
                      begin
                        paralen:=sizeof(aint);
                        paracgsize:=OS_ADDR;
                        paradef:=CPointerDef.GetReusable_No_Free(paradef);
                      end
                    else
                      begin
                        paralen:=push_size(hp.VarSpez,hp.vardef,p.ProcCallOption);
                        paracgsize:=def_cgsize(hp.vardef);
                      end;
                    hp.ParaLoc[side].size:=paracgsize;
                    hp.ParaLoc[side].intsize:=paralen;
                    hp.ParaLoc[side].Alignment:=paraalign;
                    hp.ParaLoc[side].def:=paradef;
                    {
                      EAX
                      EDX
                      ECX
                      Stack
                      Stack

                      64bit values,floats,arrays and records are always
                      on the stack.

                      In case of po_delphi_nested_cc, the parent frame pointer
                      is also always passed on the stack.
                    }
                    if (parareg<=high(parasupregs)) and
                       (paralen<=sizeof(aint)) and
                       (not(hp.vardef.typ in [floatdef,recorddef,arraydef]) or
                        pushaddr or
                        is_dynamic_array(hp.vardef)) and
                       (not(vo_is_parentfp in hp.VarOptions) or
                        not(po_delphi_nested_cc in p.ProcOptions)) then
                      begin
                        if pass=1 then
                          begin
                            ParaLoc:=hp.ParaLoc[side].add_location;
                            ParaLoc^.size:=paracgsize;
                            ParaLoc^.def:=paradef;
                            ParaLoc^.loc:=LOC_REGISTER;
                            ParaLoc^.register:=newreg(R_INTREGISTER,parasupregs[parareg],cgsize2subreg(R_INTREGISTER,paracgsize));
                            inc(parareg);
                          end;
                      end
                    else
                      if pass=2 then
                        begin
                          { Copy to stack? }
                          if (use_fixed_stack) or
                             (paracgsize=OS_NO) then
                            begin
                              ParaLoc:=hp.ParaLoc[side].add_location;
                              ParaLoc^.loc:=LOC_REFERENCE;
                              ParaLoc^.size:=paracgsize;
                              ParaLoc^.def:=paradef;
                              if side=callerside then
                                ParaLoc^.reference.index:=NR_STACK_POINTER_REG
                              else
                                ParaLoc^.reference.index:=NR_FRAME_POINTER_REG;
                              varalign:=Used_Align(Size_2_Align(paralen),paraalign,paraalign);
                              ParaLoc^.reference.offset:=parasize;
                              if side=calleeside then
                                inc(ParaLoc^.reference.offset,TargetInfo.first_parm_offset);
                              parasize:=align(parasize+paralen,varalign);
                            end
                          else
                            begin
                              if paralen=0 then
                                InternalError(2005011607);
                              firstparaloc:=true;
                              while (paralen>0) do
                                begin
                                  ParaLoc:=hp.ParaLoc[side].add_location;
                                  ParaLoc^.loc:=LOC_REFERENCE;
                                  { Extended and double need a single location }
                                  if (paracgsize in [OS_F64,OS_F32]) then
                                    begin
                                      ParaLoc^.size:=paracgsize;
                                      ParaLoc^.def:=paradef;
                                      l:=paralen;
                                    end
                                  else
                                    begin
                                      { We can allocate at maximum 32 bits per location }
                                      if paralen>sizeof(aint) then
                                        begin
                                          l:=sizeof(aint);
                                          ParaLoc^.def:=UIntType;
                                        end
                                      else
                                        begin
                                          l:=paralen;
                                          ParaLoc^.def:=get_paraloc_def(paradef,l,firstparaloc);
                                        end;
                                      ParaLoc^.size:=int_cgsize(l);
                                    end;
                                  if side=callerside then
                                    ParaLoc^.reference.index:=NR_STACK_POINTER_REG
                                  else
                                    ParaLoc^.reference.index:=NR_FRAME_POINTER_REG;
                                  varalign:=Used_Align(Size_2_Align(l),paraalign,paraalign);
                                  ParaLoc^.reference.offset:=parasize;
                                  if side=calleeside then
                                    inc(ParaLoc^.reference.offset,TargetInfo.first_parm_offset);
                                  parasize:=align(parasize+l,varalign);
                                  dec(paralen,l);
                                  firstparaloc:=false;
                                end;
                            end;
                        end;
                  end;
                case pass of
                  1:
                    begin
                      if i=paras.count-1 then
                        break;
                      inc(i);
                    end;
                  2:
                    begin
                      if i=0 then
                        break;
                      dec(i);
                    end;
                end;
              end;
          end;
      end;


    function TCPUParaManager.create_paraloc_info(p : TAbstractProcDef; side: TCallerCallee):LongInt;
      var
        parasize,
        parareg : LongInt;
      begin
        parasize:=0;
        parareg:=0;
        case p.ProcCallOption of
          pocall_register :
            create_register_paraloc_info(p,side,p.paras,parareg,parasize);
          pocall_internproc :
            begin
              { Use default calling }
{$warnings off}
              if (pocall_default=pocall_register) then
                create_register_paraloc_info(p,side,p.paras,parareg,parasize)
              else
                create_stdcall_paraloc_info(p,side,p.paras,parasize);
{$warnings on}
            end;
          else
            create_stdcall_paraloc_info(p,side,p.paras,parasize);
        end;
        create_funcretloc_info(p,side);
        result:=parasize;
      end;


    function TCPUParaManager.create_varargs_paraloc_info(p : TAbstractProcDef; side: TCallerCallee; varargspara:TVarArgsParaList):LongInt;
      var
        parasize : LongInt;
      begin
        parasize:=0;
        { calculate the registers for the normal parameters }
        create_stdcall_paraloc_info(p,side,p.paras,parasize);
        { append the varargs }
        if Assigned(varargspara) then
          begin
            if side=callerside then
              create_stdcall_paraloc_info(p,side,varargspara,parasize)
            else
              InternalError(2019021926);
          end;
        create_funcretloc_info(p,side);
        result:=parasize;
      end;


    procedure TCPUParaManager.createtempparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);
      begin
        { Never a need for temps when value is pushed (calls inside parameters
          will simply allocate even more stack space for their parameters) }
        if not(use_fixed_stack) then
          can_use_final_stack_loc:=true;
        inherited createtempparaloc(list,calloption,parasym,can_use_final_stack_loc,cgpara);
      end;


begin
   paramanager:=TCPUParaManager.create;
end.
