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
       CPUBase,CGBase,CGUtils,
       ParaBase,
       AAsmData,
       SymConst,SymType,SymSym,SymDef;

    type
       {# This class defines some methods to take care of routine
          parameters. It should be overridden for each new processor
       }

       { tparamanager }

       TParaManager = class
          { true if the location in paraloc can be reused as localloc }
          function Param_Use_ParaLoc(const CGPara:TCGPara):Boolean;virtual;
          { Returns true if the return value is actually a parameter pointer }
          function Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;virtual;
          { Returns true if a result variable should be allocated for an assembler routine }
          function Asm_Result_Var(Def:TDef;PD:TAbstractProcDef):Boolean;virtual;

          function Push_High_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;virtual;
          function Keep_Para_Array_Range(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;virtual;

          { Returns true if a parameter is too large to copy and only
            the address is pushed
          }
          function Push_Addr_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;virtual;abstract;
          { returns true if a parameter must be handled via copy-out (construct
            a reference, copy the parameter's value there in case of copy-in/out, pass the reference)
          }
          function Push_CopyOut_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;virtual;
          { return the size of a push }
          function Push_Size(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : LongInt;virtual;
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
          function Get_Para_Align(CallOption : TProcCallOption):Byte;virtual;
          function Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;virtual;
          function Get_Volatile_Registers_Address(CallOption : TProcCallOption):TCPURegisterSet;virtual;
          function Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;virtual;
          function Get_Volatile_Registers_Flags(CallOption : TProcCallOption):TCPURegisterSet;virtual;
          function Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;virtual;
          {# Registers which must be saved when calling a routine declared as
            cppdecl, cdecl, stdcall, safecall, palmossyscall. The registers
            saved should be the ones as defined in the target ABI and / or GCC.

            This value can be deduced from the CALLED_USED_REGISTERS array in the
            GCC source.
          }
          function Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;virtual;
          function Get_Saved_Registers_Address(CallOption : TProcCallOption):TCPURegisterArray;virtual;
          function Get_Saved_Registers_FPU(CallOption : TProcCallOption):TCPURegisterArray;virtual;
          function Get_Saved_Registers_MM(CallOption : TProcCallOption):TCPURegisterArray;virtual;

          { \brief Get a parameter location for calling a procdef directly instead of via a call node }
          { \returns parameter location in \c cgpara for parameter \c nr of \c pd }
          procedure GetCGTempParaLoc(List: TAsmList; PD: TAbstractProcDef; NR : LongInt; var CGPara: TCGPara);virtual;

          {# allocate an individual pcgparalocation that's part of a tcgpara

            @param(list Current assembler list)
            @param(loc Parameter location element)
          }
          procedure AllocParaLoc(List: TAsmList; const ParaLoc: PCGParaLocation);

          {# allocate a parameter location created with create_paraloc_info

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure AllocCGPara(List: TAsmList; const CGPara: TCGPara); virtual;

          {# free a parameter location allocated with alloccgpara

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure FreeCGPara(List: TAsmList; const CGPara: TCGPara); virtual;

          { This is used to populate the location information on all parameters
            for the routine as seen in either the caller or the callee. It returns
            the size allocated on the stack
          }
          function  Create_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee):LongInt;virtual;abstract;

          { Returns the location of the function result if p had def as
            function result instead of its actual result. Used if the compiler
            forces the function result to something different than the real
            result.  }
          function  Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;virtual;abstract;
          function  Get_SafeCallResult_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee): TCGPara; virtual;
          procedure Create_FuncRetLoc_Info(P : TAbstractProcDef; Side: TCallerCallee);

          { This is used to populate the location information on all parameters
            for the routine when it is being inlined. It returns
            the size allocated on the stack
          }
          function  Create_Inline_ParaLoc_Info(P : TAbstractProcDef):LongInt;virtual;

          { This is used to populate the location information on all parameters
            for the routine that are passed as varargs. It returns
            the size allocated on the stack (including the normal parameters)
          }
          function  Create_VarArgs_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee; VarArgsPara:TVarArgsParaList):LongInt;virtual;abstract;

          function Is_Stack_ParaLoc(ParaLoc: PCGParaLocation): Boolean;virtual;
          procedure CreateTempParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;CanUseFinalStackLoc : Boolean;var CGPara:TCGPara);virtual;
          procedure DuplicateCGParaLoc(const OrgParaLoc: PCGParaLocation; IntoNewParaLoc: PCGParaLocation);
          procedure DuplicateParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;var CGPara:TCGPara);


          { Convert a list of CGParaLocation entries to a RTTIParaLoc array that
            can be written by ncgrtti }
          function CGParaLocs_To_RTTIParaLocs(ParaLocs:PCGParaLocation):TRTTIParaLocs;

          { allocate room for parameters on the stack in the entry code? }
          function Use_Fixed_Stack: Boolean;
          { whether stack pointer can be changed in the middle of procedure }
          function Use_StackAlloc: Boolean;

          { Whether parameter types must match backend signatures exactly. }
          function Has_Strict_Proc_Signature: Boolean; virtual;
          { Returns true if parasym is unused and can be optimized. }
          function Can_Opt_Unused_Para(ParaSym: TParaVarSym): Boolean;
         strict protected
          { common part of get_funcretloc; returns true if retloc is completely
            initialized afterwards }
          function Set_Common_FuncRetLoc_Info(P : TAbstractProcDef; ForceTempDef: TDef; out RetCGSize: TCgSize; out RetLoc: TCGPara): Boolean;
          { common part of ret_in_param; is called by ret_in_param at the
            beginning and every tparamanager descendant can decide to call it
            itself as well; parameter retinparam is only valid if function
            returns true }
          function Handle_Common_Ret_In_Param(Def:TDef;PD:TAbstractProcDef;out RetInParam:Boolean):Boolean;

          { returns the def to use for a tparalocation part of a cgpara for paradef,
            for which the def is paradef and the integer length is restlen.
            fullsize is true if restlen equals the full paradef size }
          function Get_ParaLoc_Def(ParaDef: TDef; RestLen: AInt; FullSize: Boolean): TDef;

          { convert a single CGParaLocation to a RTTIParaLoc; the method *might*
            be overridden by targets to provide backwards compatibility with
            older versions in case register indices changed }
          function CGParaLoc_To_RTTIParaLoc(ParaLoc:PCGParaLocation):TRTTIParaLoc;virtual;
       end;


    var
       ParaManager : TParaManager;


implementation

    uses
       Systems,
       Globals,
       CGObj,TGObj,
       DefUtil,Verbose,
       HLCGObj;

    { true if the location in paraloc can be reused as localloc }
    function TParaManager.Param_Use_ParaLoc(const CGPara:TCGPara):Boolean;
      begin
        Result:=False;
      end;


    { true if uses a parameter as return value }
    function TParaManager.Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;
      begin
         { This handles all managed types, including COM interfaces and Variants }
         if Handle_Common_Ret_In_Param(Def,PD,Result) then
           Exit;
         Ret_In_Param:=(Def.Typ=ArrayDef) or
           (Def.Typ=RecordDef) or
           (Def.Typ=StringDef) or
           ((Def.Typ=ProcVarDef) and not TProcVarDef(Def).Is_AddressOnly) or
           ((Def.Typ=ObjectDef) and (Is_Object(Def))) or
           ((Def.Typ=SetDef) and not Is_SmallSet(Def));
      end;


    { true if a result variable should be allocated for an assembler routine }
    function TParaManager.Asm_Result_Var(Def:TDef;PD:TAbstractProcDef):Boolean;
      begin
        if not(po_assembler in PD.ProcOptions) then
          InternalError(2018021501);
        Result:=True;
      end;


    function TParaManager.Push_High_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;
      begin
         Push_High_Param:=not(CallOption in CDecl_PoCalls) and
                          (
                           Is_Open_Array(Def) or
                           Is_Open_String(Def) or
                           Is_Array_Of_Const(Def)
                          );
      end;


    function TParaManager.Keep_Para_Array_Range(VarSpez: TVarSpez; Def: TDef; CallOption: TProcCallOption): Boolean;
      begin
        Result:=Push_High_Param(VarSpez,Def,CallOption);
      end;


    function TParaManager.Push_CopyOut_Param(VarSpez: TVarSpez; Def: TDef; CallOption: TProcCallOption): Boolean;
      begin
        Push_CopyOut_Param:=False;
      end;


    { return the size of a push }
    function TParaManager.Push_Size(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : LongInt;
      begin
        Push_Size:=-1;
        case VarSpez of
          vs_constref,
          vs_out,
          vs_var :
            Push_Size:=VoidPointerType.Size;
          vs_value,
          vs_const :
            begin
                if Push_Addr_Param(VarSpez,Def,CallOption) then
                  Push_Size:=VoidPointerType.Size
                else
                  begin
                    { special array are normally pushed by addr, only for
                      cdecl array of const it comes here and the pushsize
                      is unknown }
                    if Is_Array_Of_Const(Def) then
                      Push_Size:=0
                    else
                      Push_Size:=Def.Size;
                  end;
            end;
          else
            ;
        end;
      end;


    function TParaManager.Get_Para_Align(CallOption : TProcCallOption):Byte;
      begin
        Result:=std_param_align;
      end;


    function TParaManager.Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TParaManager.Get_Volatile_Registers_Address(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TParaManager.Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TParaManager.Get_Volatile_Registers_Flags(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TParaManager.Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TParaManager.Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;
      const
        Inv: TCPURegisterArray = (RSInvalid);
      begin
        Result:=Inv;
      end;


    function TParaManager.Get_Saved_Registers_Address(CallOption : TProcCallOption):TCPURegisterArray;
      const
        Inv: TCPURegisterArray = (RSInvalid);
      begin
        Result:=Inv;
      end;


    function TParaManager.Get_Saved_Registers_FPU(CallOption : TProcCallOption):TCPURegisterArray;
      const
        Inv: TCPURegisterArray = (RSInvalid);
      begin
        Result:=Inv;
      end;


    function TParaManager.Get_Saved_Registers_MM(CallOption : TProcCallOption):TCPURegisterArray;
      const
        Inv: TCPURegisterArray = (RSInvalid);
      begin
        Result:=Inv;
      end;

    procedure TParaManager.AllocParaLoc(List: TAsmList; const ParaLoc: PCGParaLocation);
      begin
        case ParaLoc^.Loc of
          LOC_REGISTER,
          LOC_CREGISTER:
            begin
              if GetSupReg(ParaLoc^.Register)<first_int_imreg then
                CG.GetCPURegister(List,ParaLoc^.Register);
            end;
{$ifndef x86}
{ don't allocate ST(x), they're not handled by the register allocator }
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
              if GetSupReg(ParaLoc^.Register)<first_fpu_imreg then
                CG.GetCPURegister(List,ParaLoc^.Register);
            end;
{$endif not x86}
          LOC_MMREGISTER,
          LOC_CMMREGISTER :
            begin
              if GetSupReg(ParaLoc^.Register)<first_mm_imreg then
                CG.GetCPURegister(List,ParaLoc^.Register);
            end;
          else
            ;
        end;
      end;


    procedure TParaManager.AllocCGPara(List: TAsmList; const CGPara: TCGPara);
      var
        ParaLoc : PCGParaLocation;
      begin
        ParaLoc:=CGPara.Location;
        while Assigned(ParaLoc) do
          begin
            AllocParaLoc(List,ParaLoc);
            ParaLoc:=ParaLoc^.Next;
          end;
      end;


    procedure TParaManager.FreeCGPara(List: TAsmList; const CGPara: TCGPara);
      var
        ParaLoc : PCGParaLocation;
        HRef : TReference;
      begin
        ParaLoc:=CGPara.Location;
        while Assigned(ParaLoc) do
          begin
            case ParaLoc^.Loc of
              LOC_VOID:
                ;
              LOC_REGISTER,
              LOC_CREGISTER:
                begin
                  if GetSupReg(ParaLoc^.Register)<first_int_imreg then
                    CG.UngetCPURegister(List,ParaLoc^.Register);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                  if GetSupReg(ParaLoc^.Register)<first_fpu_imreg then
                    CG.UngetCPURegister(List,ParaLoc^.Register);
                end;
              LOC_MMREGISTER,
              LOC_CMMREGISTER :
                begin
                  if GetSupReg(ParaLoc^.Register)<first_mm_imreg then
                    CG.UngetCPURegister(List,ParaLoc^.Register);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
                  if Use_Fixed_Stack then
                    begin
                      { don't use reference_reset_base, because that will depend on cgobj }
                      FillChar(HRef,SizeOf(HRef),0);
                      HRef.Base:=ParaLoc^.Reference.Index;
                      HRef.Offset:=ParaLoc^.Reference.Offset;
                      HRef.TempPos:=CTempPosInvalid;
                      TG.UnGetIfTemp(List,HRef);
                    end;
                end;
              else
                InternalError(2004110212);
            end;
            ParaLoc:=ParaLoc^.Next;
          end;
      end;


    function TParaManager.Get_SafeCallResult_FuncRetLoc(P: TAbstractProcDef; Side: TCallerCallee): TCGPara;
      var
        ParaLoc: PCGParaLocation;
      begin
        Result.Init;
        Result.Def:=OSSIntType;
        Result.IntSize:=Result.Def.Size;
        Result.Size:=Def_CGSize(Result.Def);
        Result.Alignment:=Result.Def.Alignment;
        ParaLoc:=Result.Add_Location;
        ParaLoc^.Size:=Result.Size;
        ParaLoc^.Def:=Result.Def;
        ParaLoc^.Loc:=LOC_REGISTER;
        if Side=CallerSide then
          ParaLoc^.Register:=NR_FUNCTION_RESULT_REG
        else
          ParaLoc^.Register:=NR_FUNCTION_RETURN_REG;
        Result.Temporary:=True;
      end;


    function TParaManager.Is_Stack_ParaLoc(ParaLoc: PCGParaLocation): Boolean;
      begin
        Result:=
          Assigned(ParaLoc) and
          (ParaLoc^.Loc=LOC_REFERENCE) and
          (ParaLoc^.Reference.Index=NR_STACK_POINTER_REG);
      end;


    procedure TParaManager.CreateTempParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;CanUseFinalStackLoc : Boolean;var CGPara:TCGPara);
      var
        HRef : TReference;
        Len  : AInt;
        ParaLoc,
        NewParaLoc : PCGParaLocation;
      begin
        ParaLoc:=ParaSym.ParaLoc[CallerSide].Location;
        CGPara.Reset;
        CGPara.Size:=ParaSym.ParaLoc[CallerSide].Size;
        CGPara.IntSize:=ParaSym.ParaLoc[CallerSide].IntSize;
        CGPara.Alignment:=ParaSym.ParaLoc[CallerSide].Alignment;
        CGPara.Def:=ParaSym.ParaLoc[CallerSide].Def;
        while Assigned(ParaLoc) do
          begin
            if ParaLoc^.Size=OS_NO then
              Len:=Push_Size(ParaSym.VarSpez,ParaSym.VarDef,CallOption)
            else
              Len:=TCgSize2Size[ParaLoc^.Size];
            NewParaLoc:=CGPara.Add_Location;
            NewParaLoc^.Size:=ParaLoc^.Size;
            NewParaLoc^.Def:=ParaLoc^.Def;
            { $warning maybe release this optimization for all targets?  }
            { released for all CPUs:
              i386 isn't affected anyways because it uses the stack to push parameters
              on arm it reduces executable size of the compiler by 2.1 per cent (FK) }
            { Does it fit a register? }
            if ((not CanUseFinalStackLoc and
                 Use_Fixed_Stack) or
                not Is_Stack_ParaLoc(ParaLoc)) and
               (Len<=SizeOf(PInt)) and
               (ParaLoc^.Size in [OS_8,OS_16,OS_32,OS_64,OS_128,OS_S8,OS_S16,OS_S32,OS_S64,OS_S128]) then
              NewParaLoc^.Loc:=LOC_REGISTER
            else
              NewParaLoc^.Loc:=ParaLoc^.Loc;
            case NewParaLoc^.Loc of
              LOC_REGISTER :
                begin
                  {$ifdef cpu_uses_separate_address_registers}
                  if HLCG.Def2RegTyp(ParaLoc^.Def) = R_ADDRESSREGISTER then
                    NewParaLoc^.Register:=HLCG.GetAddressRegister(List,ParaLoc^.Def)
                  else
                  {$endif}
                    NewParaLoc^.Register:=CG.GetIntRegister(List,ParaLoc^.Size);
                end;
              LOC_FPUREGISTER :
                NewParaLoc^.Register:=CG.GetFPURegister(List,ParaLoc^.Size);
              LOC_MMREGISTER :
                NewParaLoc^.Register:=CG.GetMMRegister(List,ParaLoc^.Size);
              LOC_REFERENCE :
                begin
                  if (CanUseFinalStackLoc or
                      not Use_Fixed_Stack) and
                     Is_Stack_ParaLoc(ParaLoc) then
                    DuplicateCGParaLoc(ParaLoc,NewParaLoc)
                  else
                    begin
                      if Assigned(CGPara.Def) then
                        TG.GetHLTemp(List,CGPara.Def,Len,tt_persistent,HRef)
                      else
                        TG.GetTemp(List,Len,CGPara.Alignment,tt_persistent,HRef);
                      NewParaLoc^.Reference.Index:=HRef.Base;
                      NewParaLoc^.Reference.Offset:=HRef.Offset;
                    end;
                end;
              else
                ;
            end;
            ParaLoc:=ParaLoc^.Next;
          end;
      end;


    procedure TParaManager.DuplicateCGParaLoc(const OrgParaLoc: PCGParaLocation; IntoNewParaLoc: PCGParaLocation);
      begin
        Move(OrgParaLoc^,IntoNewParaLoc^,SizeOf(IntoNewParaLoc^));
        IntoNewParaLoc^.Next:=nil;
      end;


    procedure TParaManager.DuplicateParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;var CGPara:TCGPara);
      var
        ParaLoc,
        NewParaLoc : PCGParaLocation;
      begin
        CGPara.Reset;
        CGPara.Size:=ParaSym.ParaLoc[CallerSide].Size;
        CGPara.IntSize:=ParaSym.ParaLoc[CallerSide].IntSize;
        CGPara.Alignment:=ParaSym.ParaLoc[CallerSide].Alignment;
        ParaLoc:=ParaSym.ParaLoc[CallerSide].Location;
        while Assigned(ParaLoc) do
          begin
            NewParaLoc:=CGPara.Add_Location;
            DuplicateCGParaLoc(ParaLoc,NewParaLoc);
            ParaLoc:=ParaLoc^.Next;
          end;
      end;


    procedure TParaManager.Create_FuncRetLoc_Info(P : TAbstractProcDef; Side: TCallerCallee);
      begin
        if not Assigned(P.FuncRetLoc[Side].Location) then
          P.FuncRetLoc[Side]:=Get_FuncRetLoc(P,Side,nil);
      end;


    function TParaManager.Create_Inline_ParaLoc_Info(P : TAbstractProcDef):LongInt;
      begin
        { We need to return the size allocated }
        P.Init_ParaLoc_Info(CallBothSides);
        Result:=P.CalleeArgAreaSize;
      end;


    function TParaManager.Use_Fixed_Stack: Boolean;
      begin
{$ifdef i386}
        Result := TargetInfo.StackAlign > 4;
{$else i386}
{$ifdef cputargethasfixedstack}
        Result := True;
{$else cputargethasfixedstack}
        Result := False;
{$endif cputargethasfixedstack}
{$endif i386}
      end;

    { This is a separate function because at least win64 allows stack allocations
      despite of fixed stack semantics (actually supporting it requires generating
      a compliant stack frame, not yet possible) }
    function TParaManager.Use_StackAlloc: Boolean;
      begin
        Result:=not Use_Fixed_Stack;
      end;


    function TParaManager.Has_Strict_Proc_Signature: Boolean;
      begin
        Result:=False;
      end;


    function TParaManager.Set_Common_FuncRetLoc_Info(P : TAbstractProcDef; ForceTempDef: TDef; out RetCGSize: TCgSize; out RetLoc: TCGPara): Boolean;
      var
        ParaLoc : PCGParaLocation;
      begin
        Result:=True;
        RetLoc.Init;
        if not Assigned(ForceTempDef) then
          RetLoc.Def:=P.ReturnDef
        else
          begin
            RetLoc.Def:=ForceTempDef;
            RetLoc.Temporary:=True;
          end;
        RetLoc.Alignment:=Get_Para_Align(P.ProcCallOption);
        { void has no location }
        if Is_Void(RetLoc.Def) then
          begin
            ParaLoc:=RetLoc.Add_Location;
            RetLoc.Size:=OS_NO;
            RetCGSize:=OS_NO;
            RetLoc.IntSize:=0;
            ParaLoc^.Def:=RetLoc.Def;
            ParaLoc^.Size:=OS_NO;
            ParaLoc^.Loc:=LOC_VOID;
            Exit;
          end;
        { Constructors return self instead of a boolean }
        if P.ProcTypeOption=potype_constructor then
          begin
            RetLoc.Def:=TDef(P.Owner.DefOwner);
            if not (Is_Implicit_Pointer_Object_Type(RetLoc.Def) or
               (RetLoc.Def.Typ<>ObjectDef)) then
              RetLoc.Def:=CPointerDef.GetReusable_No_Free(RetLoc.Def);
          end;
        RetCGSize:=Def_CGSize(RetLoc.Def);
        RetLoc.IntSize:=RetLoc.Def.Size;
        RetLoc.Size:=RetCGSize;
        { Return is passed as var parameter }
        if Ret_In_Param(RetLoc.Def,P) then
          begin
            RetLoc.Def:=CPointerDef.GetReusable_No_Free(RetLoc.Def);
            ParaLoc:=RetLoc.Add_Location;
            ParaLoc^.Loc:=LOC_REFERENCE;
            ParaLoc^.Size:=RetCGSize;
            ParaLoc^.Def:=RetLoc.Def;
            Exit;
          end;
        Result:=False;
      end;


    function TParaManager.Handle_Common_Ret_In_Param(Def: TDef;
      PD: TAbstractProcDef; out RetInParam: Boolean): Boolean;
      begin
        { This must be system independent: safecall and record constructor result
          is always returned in param.
          Furthermore, any managed type is returned in param, in order to avoid
          its finalization on exception at callee side. }
        if ((tf_safecall_exceptions in TargetInfo.Flags) and
            (PD.ProcCallOption=pocall_safecall)) or
           (
             (PD.ProcTypeOption=potype_constructor) and
             (
               Is_Record(Def) or
               (
                 (Def.Typ<>ObjectDef) and
                 (PD.Owner.SymTableType=ObjectSymTable) and
                 Is_ObjectPascal_Helper(TDef(PD.Owner.DefOwner))
               )
             )
           ) or Is_Managed_Type(Def) then
          begin
            RetInParam:=True;
            Exit(True);
          end;
        if PD.ProcTypeOption=potype_constructor then
          begin
            RetInParam:=False;
            Exit(True);
          end;
        Result:=False;
      end;


    function TParaManager.Get_ParaLoc_Def(ParaDef: TDef; RestLen: AInt; FullSize: Boolean): TDef;
      begin
        if FullSize then
          Result:=ParaDef
        { no support for 128 bit ints -> tcgsize2orddef can't handle
          OS_(S)128 }
        else if RestLen in [1,2,4,8] then
          Result:=CGSize_OrdDef(Int_CGSize(RestLen))
        else
          Result:=CArrayDef.GetReusable_No_Free(U8IntType,RestLen);
      end;


    procedure TParaManager.GetCGTempParaLoc(List: TAsmList; PD: TAbstractProcDef; NR : LongInt; var CGPara: TCGPara);
      begin
        if (NR<1) or (NR>PD.Paras.Count) then
          InternalError(2013060101);
        PD.Init_ParaLoc_Info(CallerSide);
        CGPara:=TParaVarSym(PD.Paras[NR-1]).ParaLoc[CallerSide].GetCopy;
      end;


    function TParaManager.CGParaLocs_To_RTTIParaLocs(ParaLocs:PCGParaLocation):TRTTIParaLocs;
      var
        C : LongInt;
        TmpLoc : PCGParaLocation;
      begin
        C:=0;
        TmpLoc:=ParaLocs;
        Result:=nil;
        while Assigned(TmpLoc) do
          begin
            Inc(C);
            TmpLoc:=TmpLoc^.Next;
          end;

        SetLength(Result,C);

        C:=0;
        TmpLoc:=ParaLocs;
        while Assigned(TmpLoc) do
          begin
            Result[C]:=CGParaLoc_To_RTTIParaLoc(TmpLoc);
            Inc(C);
            TmpLoc:=TmpLoc^.Next;
          end;
      end;


    function TParaManager.CGParaLoc_To_RTTIParaLoc(ParaLoc:PCGParaLocation):TRTTIParaLoc;
      var
        Reg : TRegisterRec;
      begin
        { Explicitly zero the whole record, to avoid
          trouble as this record is used as is in a
          hash calculation, which might give unreliable
          results if the record as gaps between fields
          due to field alignment. PM 2021-05-06 }
        FillChar(Result,SizeOf(TRTTIParaLoc),#0);
        if ParaLoc^.Loc=LOC_REFERENCE then
          begin
            Reg:=TRegisterRec(ParaLoc^.Reference.Index);
            Result.Offset:=ParaLoc^.Reference.Offset;
            Result.LocType:=$80;
          end
        else
          begin
            Reg:=TRegisterRec(ParaLoc^.Register);
            Result.Offset:=0;
            Result.LocType:=$00;
          end;
        case Reg.RegType of
          R_INTREGISTER,
          R_FPUREGISTER,
          R_MMXREGISTER,
          R_MMREGISTER,
          R_SPECIALREGISTER,
          R_ADDRESSREGISTER:
            begin
              Result.LocType:=Result.LocType or Ord(Reg.RegType);
              Result.RegSub:=Ord(Reg.SubReg);
              Result.RegIndex:=Reg.SupReg;
            end;
          else
            begin
              { no need to adjust loctype }
              Result.RegSub:=0;
              Result.RegIndex:=0;
            end;
        end;
      end;


    function TParaManager.Can_Opt_Unused_Para(ParaSym: TParaVarSym): Boolean;
      var
        PD: TProcDef;
      begin
        { The parameter can be optimized as unused when:
            this optimization is enabled
            this is a direct call to a routine, not a procvar
            and the routine is not an exception filter
            and the parameter is not used by the routine
            and implementation of the routine is already processed.
        }
        Result:=(cs_opt_unused_para in CurrentSettings.OptimizerSwitches) and
          Assigned(ParaSym.Owner) and
          (ParaSym.Owner.DefOwner.Typ=ProcDef);
        if not Result then
          Exit;
        PD:=TProcDef(ParaSym.Owner.DefOwner);
        Result:=(PD.ProcTypeOption<>potype_exceptfilter) and
          not ParaSym.Is_Used and
          PD.IsImplemented;
      end;

initialization
  ;
finalization
  ParaManager.Free;
  ParaManager := nil;
end.
