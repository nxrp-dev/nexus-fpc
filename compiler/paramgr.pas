{
    Copyright (c) 2002 by Florian Klaempfl

    Generic calling convention handling

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
{# Parameter passing manager. Used to manage how
   parameters are passed to routines.
}
unit paramgr;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,
       cpubase,cgbase,cgutils,
       parabase,
       AAsmData,
       symconst,symtype,SymSym,symdef;

    type
       {# This class defines some methods to take care of routine
          parameters. It should be overridden for each new processor
       }

       { tparamanager }

       TParaManager = class
          { true if the location in paraloc can be reused as localloc }
          function param_use_paraloc(const cgpara:TCGPara):boolean;virtual;
          { Returns true if the return value is actually a parameter pointer }
          function ret_in_param(def:TDef;pd:TAbstractProcDef):boolean;virtual;
          { Returns true if a result variable should be allocated for an assembler routine }
          function asm_result_var(def:TDef;pd:TAbstractProcDef):boolean;virtual;

          function push_high_param(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;virtual;
          function keep_para_array_range(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;virtual;

          { Returns true if a parameter is too large to copy and only
            the address is pushed
          }
          function push_addr_param(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;virtual;abstract;
          { returns true if a parameter must be handled via copy-out (construct
            a reference, copy the parameter's value there in case of copy-in/out, pass the reference)
          }
          function push_copyout_param(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;virtual;
          { return the size of a push }
          function push_size(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : LongInt;virtual;
          {# Returns a structure giving the information on
            the storage of the parameter (which must be
            an integer parameter). This is only used when calling
            internal routines directly, where all parameters must
            be 4-byte values.

            In case the location is a register, this register is allocated.
            Call freeintparaloc() after the call to free the locations again.
            Default implementation: don't do anything at all (in case you don't
            use register parameter passing)

            @param(list Current assembler list)
            @param(nr Parameter number of routine, starting from 1)
          }
          function get_para_align(calloption : TProcCallOption):byte;virtual;
          function get_volatile_registers_int(calloption : TProcCallOption):TCPURegisterSet;virtual;
          function get_volatile_registers_address(calloption : TProcCallOption):TCPURegisterSet;virtual;
          function get_volatile_registers_fpu(calloption : TProcCallOption):TCPURegisterSet;virtual;
          function get_volatile_registers_flags(calloption : TProcCallOption):TCPURegisterSet;virtual;
          function get_volatile_registers_mm(calloption : TProcCallOption):TCPURegisterSet;virtual;
          {# Registers which must be saved when calling a routine declared as
            cppdecl, cdecl, stdcall, safecall, palmossyscall. The registers
            saved should be the ones as defined in the target ABI and / or GCC.

            This value can be deduced from the CALLED_USED_REGISTERS array in the
            GCC source.
          }
          function get_saved_registers_int(calloption : TProcCallOption):TCPURegisterArray;virtual;
          function get_saved_registers_address(calloption : TProcCallOption):TCPURegisterArray;virtual;
          function get_saved_registers_fpu(calloption : TProcCallOption):TCPURegisterArray;virtual;
          function get_saved_registers_mm(calloption : TProcCallOption):TCPURegisterArray;virtual;

          { \brief Get a parameter location for calling a procdef directly instead of via a call node }
          { \returns parameter location in \c cgpara for parameter \c nr of \c pd }
          procedure getcgtempparaloc(list: TAsmList; pd: TAbstractProcDef; nr : LongInt; var cgpara: TCGPara);virtual;

          {# allocate an individual pcgparalocation that's part of a tcgpara

            @param(list Current assembler list)
            @param(loc Parameter location element)
          }
          procedure allocparaloc(list: TAsmList; const paraloc: PCGParaLocation);

          {# allocate a parameter location created with create_paraloc_info

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure alloccgpara(list: TAsmList; const cgpara: TCGPara); virtual;

          {# free a parameter location allocated with alloccgpara

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure freecgpara(list: TAsmList; const cgpara: TCGPara); virtual;

          { This is used to populate the location information on all parameters
            for the routine as seen in either the caller or the callee. It returns
            the size allocated on the stack
          }
          function  create_paraloc_info(p : TAbstractProcDef; side: TCallerCallee):LongInt;virtual;abstract;

          { Returns the location of the function result if p had def as
            function result instead of its actual result. Used if the compiler
            forces the function result to something different than the real
            result.  }
          function  get_funcretloc(p : TAbstractProcDef; side: TCallerCallee; forcetempdef: TDef): TCGPara;virtual;abstract;
          function  get_safecallresult_funcretloc(p : TAbstractProcDef; side: TCallerCallee): TCGPara; virtual;
          procedure create_funcretloc_info(p : TAbstractProcDef; side: TCallerCallee);

          { This is used to populate the location information on all parameters
            for the routine when it is being inlined. It returns
            the size allocated on the stack
          }
          function  create_inline_paraloc_info(p : TAbstractProcDef):LongInt;virtual;

          { This is used to populate the location information on all parameters
            for the routine that are passed as varargs. It returns
            the size allocated on the stack (including the normal parameters)
          }
          function  create_varargs_paraloc_info(p : TAbstractProcDef; side: TCallerCallee; varargspara:TVarArgsParaList):LongInt;virtual;abstract;

          function is_stack_paraloc(paraloc: PCGParaLocation): boolean;virtual;
          procedure createtempparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);virtual;
          procedure duplicatecgparaloc(const orgparaloc: PCGParaLocation; intonewparaloc: PCGParaLocation);
          procedure duplicateparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;var cgpara:TCGPara);

          function parseparaloc(parasym : TParaVarSym;const s : string) : boolean;virtual;
          function parsefuncretloc(p : TAbstractProcDef; const s : string) : boolean;virtual;

          { Convert a list of CGParaLocation entries to a RTTIParaLoc array that
            can be written by ncgrtti }
          function cgparalocs_to_rttiparalocs(paralocs:PCGParaLocation):TRTTIParaLocs;

          { allocate room for parameters on the stack in the entry code? }
          function use_fixed_stack: boolean;
          { whether stack pointer can be changed in the middle of procedure }
          function use_stackalloc: boolean;
          { Returns true for platforms where the parameters are part of the signature
            and checked by the runtime/backend compiler (e.g. JVM, LLVM).
            The default implementation returns false. }
          function has_strict_proc_signature: boolean; virtual;
          { Returns true if parasym is unused and can be optimized. }
          function can_opt_unused_para(parasym: TParaVarSym): boolean;
         strict protected
          { common part of get_funcretloc; returns true if retloc is completely
            initialized afterwards }
          function set_common_funcretloc_info(p : TAbstractProcDef; forcetempdef: TDef; out retcgsize: TCgSize; out retloc: TCGPara): boolean;
          { common part of ret_in_param; is called by ret_in_param at the
            beginning and every tparamanager descendant can decide to call it
            itself as well; parameter retinparam is only valid if function
            returns true }
          function handle_common_ret_in_param(def:TDef;pd:TAbstractProcDef;out retinparam:boolean):boolean;

          { returns the def to use for a tparalocation part of a cgpara for paradef,
            for which the def is paradef and the integer length is restlen.
            fullsize is true if restlen equals the full paradef size }
          function get_paraloc_def(paradef: TDef; restlen: aint; fullsize: boolean): TDef;

          { convert a single CGParaLocation to a RTTIParaLoc; the method *might*
            be overridden by targets to provide backwards compatibility with
            older versions in case register indices changed }
          function cgparaloc_to_rttiparaloc(paraloc:PCGParaLocation):TRTTIParaLoc;virtual;
       end;


    var
       paramanager : TParaManager;


implementation

    uses
       Systems,
       Globals,
       cgobj,tgobj,
       defutil,Verbose,
       hlcgobj;

    { true if the location in paraloc can be reused as localloc }
    function TParaManager.param_use_paraloc(const cgpara:TCGPara):boolean;
      begin
        result:=false;
      end;


    { true if uses a parameter as return value }
    function TParaManager.ret_in_param(def:TDef;pd:TAbstractProcDef):boolean;
      begin
         { This handles all managed types, including COM interfaces and Variants }
         if handle_common_ret_in_param(def,pd,result) then
           exit;
         ret_in_param:=(def.typ=arraydef) or
           (def.typ=recorddef) or
           (def.typ=stringdef) or
           ((def.typ=procvardef) and not TProcVarDef(def).is_addressonly) or
           ((def.typ=objectdef) and (is_object(def))) or
           ((def.typ=setdef) and not is_smallset(def));
      end;


    { true if a result variable should be allocated for an assembler routine }
    function TParaManager.asm_result_var(def:TDef;pd:TAbstractProcDef):boolean;
      begin
        if not(po_assembler in pd.procoptions) then
          InternalError(2018021501);
        result:=true;
      end;


    function TParaManager.push_high_param(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : boolean;
      begin
         push_high_param:=not(calloption in cdecl_pocalls) and
                          (
                           is_open_array(def) or
                           is_open_string(def) or
                           is_array_of_const(def)
                          );
      end;


    function TParaManager.keep_para_array_range(varspez: TVarSpez; def: TDef; calloption: TProcCallOption): boolean;
      begin
        result:=push_high_param(varspez,def,calloption);
      end;


    function TParaManager.push_copyout_param(varspez: TVarSpez; def: TDef; calloption: TProcCallOption): boolean;
      begin
        push_copyout_param:=false;
      end;


    { return the size of a push }
    function TParaManager.push_size(varspez:TVarSpez;def : TDef;calloption : TProcCallOption) : LongInt;
      begin
        push_size:=-1;
        case varspez of
          vs_constref,
          vs_out,
          vs_var :
            push_size:=voidpointertype.size;
          vs_value,
          vs_const :
            begin
                if push_addr_param(varspez,def,calloption) then
                  push_size:=voidpointertype.size
                else
                  begin
                    { special array are normally pushed by addr, only for
                      cdecl array of const it comes here and the pushsize
                      is unknown }
                    if is_array_of_const(def) then
                      push_size:=0
                    else
                      push_size:=def.size;
                  end;
            end;
          else
            ;
        end;
      end;


    function TParaManager.get_para_align(calloption : TProcCallOption):byte;
      begin
        result:=std_param_align;
      end;


    function TParaManager.get_volatile_registers_int(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[];
      end;


    function TParaManager.get_volatile_registers_address(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[];
      end;


    function TParaManager.get_volatile_registers_fpu(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[];
      end;


    function TParaManager.get_volatile_registers_flags(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[];
      end;


    function TParaManager.get_volatile_registers_mm(calloption : TProcCallOption):TCPURegisterSet;
      begin
        result:=[];
      end;


    function TParaManager.get_saved_registers_int(calloption : TProcCallOption):TCPURegisterArray;
      const
        inv: TCPURegisterArray = (RS_INVALID);
      begin
        result:=inv;
      end;


    function TParaManager.get_saved_registers_address(calloption : TProcCallOption):TCPURegisterArray;
      const
        inv: TCPURegisterArray = (RS_INVALID);
      begin
        result:=inv;
      end;


    function TParaManager.get_saved_registers_fpu(calloption : TProcCallOption):TCPURegisterArray;
      const
        inv: TCPURegisterArray = (RS_INVALID);
      begin
        result:=inv;
      end;


    function TParaManager.get_saved_registers_mm(calloption : TProcCallOption):TCPURegisterArray;
      const
        inv: TCPURegisterArray = (RS_INVALID);
      begin
        result:=inv;
      end;

    procedure TParaManager.allocparaloc(list: TAsmList; const paraloc: PCGParaLocation);
      begin
        case paraloc^.loc of
          LOC_REGISTER,
          LOC_CREGISTER:
            begin
              if getsupreg(paraloc^.register)<first_int_imreg then
                cg.getcpuregister(list,paraloc^.register);
            end;
{$ifndef x86}
{ don't allocate ST(x), they're not handled by the register allocator }
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
              if getsupreg(paraloc^.register)<first_fpu_imreg then
                cg.getcpuregister(list,paraloc^.register);
            end;
{$endif not x86}
          LOC_MMREGISTER,
          LOC_CMMREGISTER :
            begin
              if getsupreg(paraloc^.register)<first_mm_imreg then
                cg.getcpuregister(list,paraloc^.register);
            end;
          else
            ;
        end;
      end;


    procedure TParaManager.alloccgpara(list: TAsmList; const cgpara: TCGPara);
      var
        paraloc : PCGParaLocation;
      begin
        paraloc:=cgpara.location;
        while Assigned(paraloc) do
          begin
            allocparaloc(list,paraloc);
            paraloc:=paraloc^.next;
          end;
      end;


    procedure TParaManager.freecgpara(list: TAsmList; const cgpara: TCGPara);
      var
        paraloc : PCGParaLocation;
        href : TReference;
      begin
        paraloc:=cgpara.location;
        while Assigned(paraloc) do
          begin
            case paraloc^.loc of
              LOC_VOID:
                ;
              LOC_REGISTER,
              LOC_CREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_int_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_fpu_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_MMREGISTER,
              LOC_CMMREGISTER :
                begin
                  if getsupreg(paraloc^.register)<first_mm_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
                  if use_fixed_stack then
                    begin
                      { don't use reference_reset_base, because that will depend on cgobj }
                      fillchar(href,sizeof(href),0);
                      href.base:=paraloc^.reference.index;
                      href.offset:=paraloc^.reference.offset;
                      href.temppos:=ctempposinvalid;
                      tg.ungetiftemp(list,href);
                    end;
                end;
              else
                InternalError(2004110212);
            end;
            paraloc:=paraloc^.next;
          end;
      end;


    function TParaManager.get_safecallresult_funcretloc(p: TAbstractProcDef; side: TCallerCallee): TCGPara;
      var
        paraloc: PCGParaLocation;
      begin
        result.init;
        result.def:=ossinttype;
        result.intsize:=result.def.size;
        result.size:=def_cgsize(result.def);
        result.alignment:=result.def.alignment;
        paraloc:=result.add_location;
        paraloc^.size:=result.size;
        paraloc^.def:=result.def;
        paraloc^.loc:=LOC_REGISTER;
        if side=callerside then
          paraloc^.register:=NR_FUNCTION_RESULT_REG
        else
          paraloc^.register:=NR_FUNCTION_RETURN_REG;
        result.Temporary:=true;
      end;


    function TParaManager.is_stack_paraloc(paraloc: PCGParaLocation): boolean;
      begin
        result:=
          Assigned(paraloc) and
          (paraloc^.loc=LOC_REFERENCE) and
          (paraloc^.reference.index=NR_STACK_POINTER_REG);
      end;


    procedure TParaManager.createtempparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;can_use_final_stack_loc : boolean;var cgpara:TCGPara);
      var
        href : TReference;
        len  : aint;
        paraloc,
        newparaloc : PCGParaLocation;
      begin
        paraloc:=parasym.paraloc[callerside].location;
        cgpara.reset;
        cgpara.size:=parasym.paraloc[callerside].size;
        cgpara.intsize:=parasym.paraloc[callerside].intsize;
        cgpara.alignment:=parasym.paraloc[callerside].alignment;
        cgpara.def:=parasym.paraloc[callerside].def;
        while Assigned(paraloc) do
          begin
            if paraloc^.size=OS_NO then
              len:=push_size(parasym.varspez,parasym.vardef,calloption)
            else
              len:=tcgsize2size[paraloc^.size];
            newparaloc:=cgpara.add_location;
            newparaloc^.size:=paraloc^.size;
            newparaloc^.def:=paraloc^.def;
            { shiftval overlaps with part of the reference, so it may be
              different from 0 and if wr then force the newparaloc to a register
              in the optimization below, shiftval will remain <> 0 }
            if not(paraloc^.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              newparaloc^.shiftval:=paraloc^.shiftval;
            { $warning maybe release this optimization for all targets?  }
            { released for all CPUs:
              i386 isn't affected anyways because it uses the stack to push parameters
              on arm it reduces executable size of the compiler by 2.1 per cent (FK) }
            { Does it fit a register? }
            if ((not can_use_final_stack_loc and
                 use_fixed_stack) or
                not is_stack_paraloc(paraloc)) and
               (len<=sizeof(PInt)) and
               (paraloc^.size in [OS_8,OS_16,OS_32,OS_64,OS_128,OS_S8,OS_S16,OS_S32,OS_S64,OS_S128]) then
              newparaloc^.loc:=LOC_REGISTER
            else
              newparaloc^.loc:=paraloc^.loc;
            case newparaloc^.loc of
              LOC_REGISTER :
                begin
                  if (vo_has_explicit_paraloc in parasym.varoptions) and (paraloc^.loc = LOC_REGISTER) then
                    if getregtype(paraloc^.register) = R_ADDRESSREGISTER then
                      newparaloc^.register:=cg.getaddressregister(list)
                    else
                      newparaloc^.register:=cg.getintregister(list,paraloc^.size)
                  else
                    begin
                      {$ifdef cpu_uses_separate_address_registers}
                      if hlcg.def2regtyp(paraloc^.def) = R_ADDRESSREGISTER then
                        newparaloc^.register:=hlcg.getaddressregister(list,paraloc^.def)
                      else
                      {$endif}
                        newparaloc^.register:=cg.getintregister(list,paraloc^.size);
                    end;
                end;
              LOC_FPUREGISTER :
                newparaloc^.register:=cg.getfpuregister(list,paraloc^.size);
              LOC_MMREGISTER :
                newparaloc^.register:=cg.getmmregister(list,paraloc^.size);
              LOC_REFERENCE :
                begin
                  if (can_use_final_stack_loc or
                      not use_fixed_stack) and
                     is_stack_paraloc(paraloc) then
                    duplicatecgparaloc(paraloc,newparaloc)
                  else
                    begin
                      if Assigned(cgpara.def) then
                        tg.gethltemp(list,cgpara.def,len,tt_persistent,href)
                      else
                        tg.gettemp(list,len,cgpara.alignment,tt_persistent,href);
                      newparaloc^.reference.index:=href.base;
                      newparaloc^.reference.offset:=href.offset;
                    end;
                end;
              else
                ;
            end;
            paraloc:=paraloc^.next;
          end;
      end;


    procedure TParaManager.duplicatecgparaloc(const orgparaloc: PCGParaLocation; intonewparaloc: PCGParaLocation);
      begin
        move(orgparaloc^,intonewparaloc^,sizeof(intonewparaloc^));
        intonewparaloc^.next:=nil;
      end;


    procedure TParaManager.duplicateparaloc(list: TAsmList;calloption : TProcCallOption;parasym : TParaVarSym;var cgpara:TCGPara);
      var
        paraloc,
        newparaloc : PCGParaLocation;
      begin
        cgpara.reset;
        cgpara.size:=parasym.paraloc[callerside].size;
        cgpara.intsize:=parasym.paraloc[callerside].intsize;
        cgpara.alignment:=parasym.paraloc[callerside].alignment;
        paraloc:=parasym.paraloc[callerside].location;
        while Assigned(paraloc) do
          begin
            newparaloc:=cgpara.add_location;
            duplicatecgparaloc(paraloc,newparaloc);
            paraloc:=paraloc^.next;
          end;
      end;


    procedure TParaManager.create_funcretloc_info(p : TAbstractProcDef; side: TCallerCallee);
      begin
        if not Assigned(p.funcretloc[side].Location) then
          p.funcretloc[side]:=get_funcretloc(p,side,nil);
      end;


    function TParaManager.create_inline_paraloc_info(p : TAbstractProcDef):LongInt;
      begin
        { We need to return the size allocated }
        p.init_paraloc_info(callbothsides);
        result:=p.calleeargareasize;
      end;


    { used by syscall conventions which require explicit paralocation support }
    { this is the standard implementation, CGs might overwrite it }
    function TParaManager.parseparaloc(parasym: TParaVarSym; const s: string): boolean;
      var
        paraloc : PCGParaLocation;
      begin
        parasym.paraloc[callerside].alignment:=sizeof(PInt);
        paraloc:=parasym.paraloc[callerside].add_location;
        paraloc^.loc:=LOC_REGISTER;
        paraloc^.size:=def_cgsize(parasym.vardef);
        paraloc^.def:=parasym.vardef;
        paraloc^.register:=std_regnum_search(lowercase(s));

        { copy to callee side }
        parasym.paraloc[calleeside].add_location^:=paraloc^;

        result:=(paraloc^.register <> NR_NO) and
                (paraloc^.register <> NR_STACK_POINTER_REG);
      end;


    function TParaManager.parsefuncretloc(p: TAbstractProcDef; const s: string): boolean;
      begin
        Result:=False;
        InternalError(200807236);
      end;


    function TParaManager.use_fixed_stack: boolean;
      begin
{$ifdef i386}
        result := TargetInfo.stackalign > 4;
{$else i386}
{$ifdef cputargethasfixedstack}
        result := true;
{$else cputargethasfixedstack}
        result := false;
{$endif cputargethasfixedstack}
{$endif i386}
      end;

    { This is a separate function because at least win64 allows stack allocations
      despite of fixed stack semantics (actually supporting it requires generating
      a compliant stack frame, not yet possible) }
    function TParaManager.use_stackalloc: boolean;
      begin
        result:=not use_fixed_stack;
      end;


    function TParaManager.has_strict_proc_signature: boolean;
      begin
        result:=false;
      end;


    function TParaManager.set_common_funcretloc_info(p : TAbstractProcDef; forcetempdef: TDef; out retcgsize: TCgSize; out retloc: TCGPara): boolean;
      var
        paraloc : PCGParaLocation;
      begin
        result:=true;
        retloc.init;
        if not Assigned(forcetempdef) then
          retloc.def:=p.returndef
        else
          begin
            retloc.def:=forcetempdef;
            retloc.temporary:=true;
          end;
        retloc.alignment:=get_para_align(p.proccalloption);
        { void has no location }
        if is_void(retloc.def) then
          begin
            paraloc:=retloc.add_location;
            retloc.size:=OS_NO;
            retcgsize:=OS_NO;
            retloc.intsize:=0;
            paraloc^.def:=retloc.def;
            paraloc^.size:=OS_NO;
            paraloc^.loc:=LOC_VOID;
            exit;
          end;
        { Constructors return self instead of a boolean }
        if p.proctypeoption=potype_constructor then
          begin
            retloc.def:=TDef(p.owner.defowner);
            if not (is_implicit_pointer_object_type(retloc.def) or
               (retloc.def.typ<>objectdef)) then
              retloc.def:=CPointerDef.getreusable_no_free(retloc.def);
          end;
        retcgsize:=def_cgsize(retloc.def);
        retloc.intsize:=retloc.def.size;
        retloc.size:=retcgsize;
        { Return is passed as var parameter }
        if ret_in_param(retloc.def,p) then
          begin
            retloc.def:=CPointerDef.getreusable_no_free(retloc.def);
            paraloc:=retloc.add_location;
            paraloc^.loc:=LOC_REFERENCE;
            paraloc^.size:=retcgsize;
            paraloc^.def:=retloc.def;
            exit;
          end;
        result:=false;
      end;


    function TParaManager.handle_common_ret_in_param(def: TDef;
      pd: TAbstractProcDef; out retinparam: boolean): boolean;
      begin
        { This must be system independent: safecall and record constructor result
          is always returned in param.
          Furthermore, any managed type is returned in param, in order to avoid
          its finalization on exception at callee side. }
        if ((tf_safecall_exceptions in TargetInfo.flags) and
            (pd.proccalloption=pocall_safecall)) or
           (
             (pd.proctypeoption=potype_constructor) and
             (
               is_record(def) or
               (
                 (def.typ<>objectdef) and
                 (pd.owner.symtabletype=objectsymtable) and
                 is_objectpascal_helper(TDef(pd.owner.defowner))
               )
             )
           ) or is_managed_type(def) then
          begin
            retinparam:=true;
            exit(true);
          end;
        if pd.proctypeoption=potype_constructor then
          begin
            retinparam:=false;
            exit(true);
          end;
        result:=false;
      end;


    function TParaManager.get_paraloc_def(paradef: TDef; restlen: aint; fullsize: boolean): TDef;
      begin
        if fullsize then
          result:=paradef
        { no support for 128 bit ints -> tcgsize2orddef can't handle
          OS_(S)128 }
        else if restlen in [1,2,4,8] then
          result:=cgsize_orddef(int_cgsize(restlen))
        else
          result:=CArrayDef.getreusable_no_free(u8inttype,restlen);
      end;


    procedure TParaManager.getcgtempparaloc(list: TAsmList; pd: TAbstractProcDef; nr : LongInt; var cgpara: TCGPara);
      begin
        if (nr<1) or (nr>pd.paras.count) then
          InternalError(2013060101);
        pd.init_paraloc_info(callerside);
        cgpara:=TParaVarSym(pd.paras[nr-1]).paraloc[callerside].getcopy;
      end;


    function TParaManager.cgparalocs_to_rttiparalocs(paralocs:PCGParaLocation):TRTTIParaLocs;
      var
        c : LongInt;
        tmploc : PCGParaLocation;
      begin
        c:=0;
        tmploc:=paralocs;
        result:=nil;
        while Assigned(tmploc) do
          begin
            inc(c);
            tmploc:=tmploc^.next;
          end;

        SetLength(result,c);

        c:=0;
        tmploc:=paralocs;
        while Assigned(tmploc) do
          begin
            result[c]:=cgparaloc_to_rttiparaloc(tmploc);
            inc(c);
            tmploc:=tmploc^.next;
          end;
      end;


    function TParaManager.cgparaloc_to_rttiparaloc(paraloc:PCGParaLocation):TRTTIParaLoc;
      var
        reg : TRegisterRec;
      begin
        { Explicitly zero the whole record, to avoid
          trouble as this record is used as is in a
          hash calculation, which might give unreliable
          results if the record as gaps between fields
          due to field alignment. PM 2021-05-06 }
        fillchar(result,sizeof(TRTTIParaLoc),#0);
        if paraloc^.Loc=LOC_REFERENCE then
          begin
            reg:=TRegisterRec(paraloc^.reference.index);
            result.offset:=paraloc^.reference.offset;
            result.loctype:=$80;
          end
        else
          begin
            reg:=TRegisterRec(paraloc^.register);
            { use sign extension }
            result.offset:=paraloc^.shiftval;
            result.loctype:=$00;
          end;
        case reg.regtype of
          R_INTREGISTER,
          R_FPUREGISTER,
          R_MMXREGISTER,
          R_MMREGISTER,
          R_SPECIALREGISTER,
          R_ADDRESSREGISTER:
            begin
              result.loctype:=result.loctype or ord(reg.regtype);
              result.regsub:=ord(reg.subreg);
              result.regindex:=reg.supreg;
            end;
          else
            begin
              { no need to adjust loctype }
              result.regsub:=0;
              result.regindex:=0;
            end;
        end;
      end;


    function TParaManager.can_opt_unused_para(parasym: TParaVarSym): boolean;
      var
        pd: TProcDef;
      begin
        { The parameter can be optimized as unused when:
            this optimization is enabled
            this is a direct call to a routine, not a procvar
            and the routine is not an exception filter
            and the parameter is not used by the routine
            and implementation of the routine is already processed.
        }
        result:=(cs_opt_unused_para in CurrentSettings.OptimizerSwitches) and
          Assigned(parasym.Owner) and
          (parasym.Owner.defowner.typ=procdef);
        if not result then
          exit;
        pd:=TProcDef(parasym.Owner.defowner);
        result:=(pd.proctypeoption<>potype_exceptfilter) and
          not parasym.is_used and
          pd.is_implemented;
      end;

initialization
  ;
finalization
  paramanager.free;
  paramanager := nil;
end.
