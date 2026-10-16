{
    Copyright (c) 2013-2014 by Jonas Maebe, Florian Klaempfl and others

    AArch64 specific calling conventions

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
{ AArch64 specific calling conventions are handled by this unit
}
unit cpupara;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,Globals,
       AAsmTAI,AAsmData,
       CPUInfo,CPUBase,CGBase,CGUtils,
       SymConst,SymBase,SymType,SymDef,ParaBase,ParaMgr,ArmPara;

    type
       TCPUParaManager = class(TArmGenParaManager)
          function Get_Volatile_Registers_Int(CallOption: TProcCallOption): TCPURegisterSet; override;
          function Get_Volatile_Registers_FPU(CallOption: TProcCallOption): TCPURegisterSet; override;
          function Get_Volatile_Registers_MM(CallOption: TProcCallOption): TCPURegisterSet; override;
          function Get_Saved_Registers_Int(CallOption: TProcCallOption): TCPURegisterArray; override;
          function Get_Saved_Registers_MM(CallOption: TProcCallOption): TCPURegisterArray; override;
          function Push_Addr_Param(VarSpez: TVarSpez; Def: TDef; CallOption: TProcCallOption): Boolean; override;
          function Ret_In_Param(Def: TDef; PD: TAbstractProcDef):Boolean;override;
          function Create_ParaLoc_Info(P: TAbstractProcDef; Side: TCallerCallee):LongInt;override;
          function Create_VarArgs_ParaLoc_Info(P: TAbstractProcDef; Side: TCallerCallee; VarArgsPara: TVarArgsParaList):LongInt;override;
          function Get_FuncRetLoc(P: TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;override;
          function Param_Use_ParaLoc(const CGPara: TCGPara): Boolean; override;
         private
          CurIntReg,
          CurMMReg: TSuperRegister;
          CurStackOffset: AWord;

          procedure InitParaAllocValues;
          procedure AllocPara(out Result: TCGPara; P: TAbstractProcDef; VarSpez: TVarSpez; Side: TCallerCallee; ParaDef: TDef; IsVariadic, IsDelphiNestedCC: Boolean);
          function GetParaLoc(CallOption: TProcCallOption; P: TDef): TCGLoc;

          procedure CreateParaLocInfoIntern(P: TAbstractProcDef; Side: TCallerCallee; Paras: TParaList; IsVariadic: Boolean);
       end;

  implementation

    uses
       Verbose,Systems,CUtils,
       RGObj,
       DefUtil,SymSym,SymTable;

    const
      RSFirstIntParamSupReg = RS_X0;
      RSLastIntParamSupReg = RS_X7;
      { Q0/D0/S0/H0/B0 all have the same superregister number }
      RSFirstMMParamSupReg = RS_D0;
      RSLastMMParamSupReg = RS_D7;


    function TCPUParaManager.Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=VOLATILE_INTREGISTERS
      end;


    function TCPUParaManager.Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[];
      end;


    function TCPUParaManager.Get_Volatile_Registers_MM(CallOption: TProcCallOption): TCPURegisterSet;
      begin
        Result:=VOLATILE_MMREGISTERS;
      end;


    function TCPUParaManager.Get_Saved_Registers_Int(CallOption: TProcCallOption): TCPURegisterArray;
      const
        SavedRegs : TCPURegisterArray =
          (RS_X19,RS_X20,RS_X21,RS_X22,RS_X23,RS_X24,RS_X25,RS_X26,RS_X27,RS_X28);
      begin
        Result:=SavedRegs;
      end;


    function TCPUParaManager.Get_Saved_Registers_MM(CallOption: TProcCallOption): TCPURegisterArray;
      const
        SavedMMRegs : TCPURegisterArray =
          (RS_D8,RS_D9,RS_D10,RS_D11,RS_D12,RS_D13,RS_D14,RS_D15);
      begin
        Result:=SavedMMRegs;
      end;


    function TCPUParaManager.GetParaLoc(CallOption: TProcCallOption; P: TDef): TCGLoc;
      var
        HFABaseDef: TDef;
      begin
         { Later, the LOC_REFERENCE is in most cases changed into LOC_REGISTER
           if push_addr_param for the def is true
         }
         case P.Typ of
            OrdDef:
              GetParaLoc:=LOC_REGISTER;
            FloatDef:
              GetParaLoc:=LOC_MMREGISTER;
            EnumDef:
              GetParaLoc:=LOC_REGISTER;
            PointerDef:
              GetParaLoc:=LOC_REGISTER;
            FormalDef:
              GetParaLoc:=LOC_REGISTER;
            ClassRefDef:
              GetParaLoc:=LOC_REGISTER;
            RecordDef:
              if not Is_HFA(P,HFABaseDef) then
                GetParaLoc:=LOC_REGISTER
              else
                GetParaLoc:=LOC_MMREGISTER;
            ObjectDef:
              GetParaLoc:=LOC_REGISTER;
            StringDef:
              if Is_ShortString(P) or Is_LongString(P) then
                GetParaLoc:=LOC_REFERENCE
              else
                GetParaLoc:=LOC_REGISTER;
            ProcVarDef:
              GetParaLoc:=LOC_REGISTER;
            FileDef:
              GetParaLoc:=LOC_REGISTER;
            ArrayDef:
              if not Is_HFA(P,HFABaseDef) then
                GetParaLoc:=LOC_REGISTER
              else
                GetParaLoc:=LOC_MMREGISTER;
            SetDef:
              GetParaLoc:=LOC_REGISTER;
            VariantDef:
              GetParaLoc:=LOC_REGISTER;
            { avoid problems with errornous definitions }
            ErrorDef:
              GetParaLoc:=LOC_REGISTER;
            else
              InternalError(2002071001);
         end;
      end;


    function TCPUParaManager.Push_Addr_Param(VarSpez: TVarSpez; Def :TDef; CallOption: TProcCallOption): Boolean;
      var
        HFABaseDef: TDef;
      begin
        Result:=False;
        if VarSpez in [vs_var,vs_out,vs_constref] then
          begin
            Result:=True;
            Exit;
          end;
        case Def.Typ of
          ObjectDef:
            Result:=Is_Object(Def);
          RecordDef:
            { ABI: any composite > 16 bytes that not a hfa/hva
              Special case: MWPascal, which passes all const parameters by
                reference for compatibility reasons
              Special case 2: on Windows we need to pass all const records by
                reference due to the Windows unit (ab)using const to pass
                pointer parameters }
            Result:=
              ((VarSpez=vs_const) and
               (
                 (CallOption=pocall_mwpascal) or
                 (TargetInfo.System=system_aarch64_win64)
               )) or
              (not Is_HFA(Def,HFABaseDef) and
               (Def.Size>16));
          VariantDef,
          FormalDef:
            Result:=True;
          { arrays are composites and hence treated the same as records by the
            ABI (watch out for C, where an array is a pointer)
            Also: all other platforms pass const arrays by reference. Do the
              same here, because there is too much hacky code out there that
              relies on this ("array[0..0] of x" passed as const parameter and
              then indexed beyond its bounds) }
          ArrayDef:
            Result:=
              ((CallOption in CDecl_PoCalls) and
               not Is_Dynamic_Array(Def)) or
              Is_Open_Array(Def) or
              Is_Array_Of_Const(Def) or
              Is_Array_Constructor(Def) or
              ((TArrayDef(Def).HighRange>=TArrayDef(Def).LowRange) and
               ((VarSpez=vs_const) or
                (not Is_HFA(Def,HFABaseDef) and
                 (Def.Size>16))));
          SetDef :
            Result:=Def.Size>16;
          StringDef :
            Result:=TStringDef(Def).StringType in [st_shortstring,st_longstring];
          else
            ;
        end;
      end;


    function TCPUParaManager.Ret_In_Param(Def: TDef; PD: TAbstractProcDef): Boolean;
      begin
        if Handle_Common_Ret_In_Param(Def,PD,Result) then
          Exit;
        { ABI: if the parameter would be passed in registers, it is returned
            in those registers; otherwise, it's returned by reference }
        Result:=Push_Addr_Param(vs_value,Def,PD.ProcCallOption);
      end;


    procedure TCPUParaManager.CreateParaLocInfoIntern(P : TAbstractProcDef; Side: TCallerCallee; Paras: TParaList; IsVariadic: Boolean);
      var
        HP: TParaVarSym;
        I: LongInt;
      begin
        for I:=0 to Paras.Count-1 do
          begin
            HP:=TParaVarSym(Paras[I]);
            { hidden function result parameter is passed in X8 (doesn't have to
              be valid on return) according to the ABI

              -- don't follow the ABI for managed types, because
               a) they are passed in registers as parameters, so we should also
                  return them in a register to be ABI-compliant (which we can't
                  because the entire compiler is built around the idea that
                  they are returned by reference, for ref-counting performance
                  and Delphi-compatibility reasons)
               b) there are hacks in the system unit that expect that you can
                  call
                    function f: com_interface;
                  as
                    procedure p(out o: obj);
                  That can only work in case we do not use x8 to return them
                  from the function, but the regular first parameter register.

              As the ABI says this behaviour is ok for C++ classes with a
              non-trivial copy constructor or destructor, it seems reasonable
              for us to do this for managed types as well.}
            if (vo_is_funcret in HP.VarOptions) and
               not Is_Managed_Type(HP.VarDef) then
              begin
                HP.ParaLoc[Side].Reset;
                HP.ParaLoc[Side].Size:=OS_ADDR;
                HP.ParaLoc[Side].Alignment:=VoidPointerType.Alignment;
                HP.ParaLoc[Side].IntSize:=VoidPointerType.Size;
                HP.ParaLoc[Side].Def:=CPointerDef.GetReusable_No_Free(HP.VarDef);
                with HP.ParaLoc[Side].Add_Location^ do
                  begin
                    Size:=OS_ADDR;
                    Def:=HP.ParaLoc[Side].Def;
                    Loc:=LOC_REGISTER;
                    Register:=NR_XR;
                  end
              end
            else
              AllocPara(HP.ParaLoc[Side],P,HP.VarSpez,Side,HP.VarDef,IsVariadic,
                (vo_is_parentfp in HP.VarOptions) and
                (po_delphi_nested_cc in P.ProcOptions));
          end;
      end;


    function  TCPUParaManager.Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;
      var
        RetCGSize: TCgSize;
        OtherSide: TCallerCallee;
      begin
         if Set_Common_FuncRetLoc_Info(P,ForceTempDef,RetCGSize,Result) then
           Exit;

         { in this case, it must be returned in registers as if it were passed
           as the first parameter }
         InitParaAllocValues;
         { if we're on the callee side, filling the result location is actually the "callerside"
          as far passing it as a parameter value is concerned }
         if Side=CallerSide then
           OtherSide:=CalleeSide
         else
           OtherSide:=CallerSide;
         AllocPara(Result,P,vs_value,OtherSide,Result.Def,False,False);
         { sanity check (LOC_VOID for empty records) }
         if not Assigned(Result.Location) or
            not(Result.Location^.Loc in [LOC_REGISTER,LOC_MMREGISTER,LOC_VOID]) then
           InternalError(2014113001);

         {
           According to ARM64 ABI: "If the size of the argument is less than 8 bytes then
           the size of the argument is set to 8 bytes. The effect is as if the argument
           was copied to the least significant bits of a 64-bit register and the remaining
           bits filled with unspecified values."

           Therefore at caller side force the ordinal result to be always 64-bit, so it
           will be stripped to the required size and unneeded bits are discarded.

           According to Jonas iOS doesn't zero extend results in the callee either
         }
         if (Side=CallerSide) and (Result.Location^.Loc = LOC_REGISTER) and
            (Result.Def.Size<8) and Is_Ordinal(Result.Def) then
           begin
             Result.Location^.Size:=OS_64;
             Result.Location^.Def:=U64IntType;
           end;

      end;


    function TCPUParaManager.Param_Use_ParaLoc(const CGPara: TCGPara): Boolean;
      begin
        { we always set up a stack frame -> we can always access the parameters
          this way }
        Result:=
          (CGPara.Location^.Loc=LOC_REFERENCE) and
          not Assigned(CGPara.Location^.Next);
      end;


    procedure TCPUParaManager.InitParaAllocValues;
      begin
        CurIntReg:=RSFirstIntParamSupReg;
        CurMMReg:=RSFirstMMParamSupReg;
        CurStackOffset:=0;
      end;


    procedure TCPUParaManager.AllocPara(out Result: TCGPara; P: TAbstractProcDef; VarSpez: TVarSpez; Side: TCallerCallee; ParaDef: TDef; IsVariadic, IsDelphiNestedCC: Boolean);
      var
        HFABaseDef, LocDef: TDef;
        ParaLoc: PCGParaLocation;
        ParaLen, StackSlotLen: ASizeInt;
        Loc: TCGLoc;
        ParaCGSize, LocSize: TCgSize;
        FirstParaLoc: Boolean;
      begin
        Result.Init;

        { currently only support C-style array of const,
          there should be no location assigned to the vararg array itself }
        if (P.ProcCallOption in CStyleArrayOfConst) and
           Is_Array_Of_Const(ParaDef) then
          begin
            Result.Size:=OS_NO;
            Result.Def:=ParaDef;
            Result.Alignment:=std_param_align;
            Result.IntSize:=0;
            ParaLoc:=Result.Add_Location;
            { hack: the paraloc must be valid, but is not actually used }
            ParaLoc^.Loc:=LOC_REGISTER;
            ParaLoc^.Register:=NR_X0;
            ParaLoc^.Size:=OS_ADDR;
            ParaLoc^.Def:=ParaDef;
            Exit;
          end;

        if Push_Addr_Param(VarSpez,ParaDef,P.ProcCallOption) then
          begin
            ParaDef:=CPointerDef.GetReusable_No_Free(ParaDef);
            Loc:=LOC_REGISTER;
            ParaCGSize:=OS_ADDR;
            ParaLen:=TCgSize2Size[OS_ADDR];
          end
        else
          begin
            if not Is_Special_Array(ParaDef) then
              ParaLen:=ParaDef.Size
            else
              ParaLen:=TCgSize2Size[Def_CGSize(ParaDef)];
            Loc:=GetParaLoc(P.ProcCallOption,ParaDef);
            if (ParaDef.Typ in [ObjectDef,ArrayDef,RecordDef,SetDef]) and
               not Is_Special_Array(ParaDef) and
               (VarSpez in [vs_value,vs_const]) then
              ParaCGSize:=Int_CGSize(ParaLen)
            else
              begin
                ParaCGSize:=Def_CGSize(ParaDef);
                { for things like formaldef }
                if ParaCGSize=OS_NO then
                  begin
                    ParaCGSize:=OS_ADDR;
                    ParaLen:=TCgSize2Size[OS_ADDR];
                    ParaDef:=VoidPointerType;
                  end;
              end
          end;

          { get hfa basedef if applicable }
          if not Is_HFA(ParaDef,HFABaseDef) then
            HFABaseDef:=nil;

         Result.Size:=ParaCGSize;
         Result.Alignment:=std_param_align;
         Result.IntSize:=ParaLen;
         Result.Def:=ParaDef;

         { empty record: skipped (explicitly defined by Apple ABI, undefined
           by general ABI; libffi also skips them in all cases) }
         if not Is_Special_Array(ParaDef) and
            (ParaDef.Size=0) then
           begin
             ParaLoc:=Result.Add_Location;
             ParaLoc^.Loc:=LOC_VOID;
             ParaLoc^.Def:=ParaDef;
             ParaLoc^.Size:=OS_NO;
             Exit;
           end;

         { sufficient registers left? }
         case Loc of
           LOC_REGISTER:
             begin
               { In case of po_delphi_nested_cc, the parent frame pointer
                 is always passed on the stack. }
               if IsDelphiNestedCC then
                 Loc:=LOC_REFERENCE
               else if CurIntReg+((ParaLen-1) shr 3)>RSLastIntParamSupReg then
                 begin
                   { not enough integer registers left -> no more register
                     parameters, copy all to stack
                   }
                   CurIntReg:=Succ(RSLastIntParamSupReg);
                   Loc:=LOC_REFERENCE;
                 end;
             end;
           LOC_MMREGISTER:
             begin;
               { every hfa element must be passed in a separate register }
               if (Assigned(HFABaseDef) and
                   (CurMMReg+((ParaLen-1) div HFABaseDef.Size)>RSLastMMParamSupReg)) or
                  (CurMMReg+((ParaLen-1) shr 3)>RSLastMMParamSupReg) then
                 begin
                   { not enough mm registers left -> no more register
                     parameters, copy all to stack
                   }
                   CurMMReg:=Succ(RSLastMMParamSupReg);
                   Loc:=LOC_REFERENCE;
                 end;
             end;
           else
             ;
         end;

         { allocate registers/stack locations }
         FirstParaLoc:=True;
         repeat
           ParaLoc:=Result.Add_Location;

           { set paraloc size/def }
           if Assigned(HFABaseDef) then
             begin
               LocSize:=Def_CGSize(HFABaseDef);
               LocDef:=HFABaseDef;
             end
           { make sure we don't lose whether or not the type is signed }
           else if (Loc=LOC_REGISTER) and
                   (ParaDef.Typ<>OrdDef) then
             begin
               LocSize:=Int_CGSize(ParaLen);
               LocDef:=Get_ParaLoc_Def(ParaDef,ParaLen,FirstParaLoc);
             end
           else
             begin
               LocSize:=ParaCGSize;
               LocDef:=ParaDef;
             end;
           if LocSize in [OS_NO,OS_128,OS_S128] then
             begin
               if ParaLen>4 then
                 begin
                   ParaLoc^.Size:=OS_INT;
                   ParaLoc^.Def:=U64IntType;
                 end
               else
                 begin
                   { for 3-byte records }
                   ParaLoc^.Size:=OS_32;
                   ParaLoc^.Def:=U32IntType;
                 end;
             end
           else
             begin
               ParaLoc^.Size:=LocSize;
               ParaLoc^.Def:=LocDef;

             end;

           { paraloc loc }
           ParaLoc^.Loc:=Loc;

           { assign register/stack address }
           case Loc of
             LOC_REGISTER:
               begin
                 ParaLoc^.Register:=NewReg(R_INTREGISTER,CurIntReg,CGSize2SubReg(R_INTREGISTER,ParaLoc^.Size));
                 Inc(CurIntReg);
                 Dec(ParaLen,TCgSize2Size[ParaLoc^.Size]);

                 { "The general ABI specifies that it is the callee's
                    responsibility to sign or zero-extend arguments having fewer
                    than 32 bits, and that unused bits in a register are
                    unspecified. In iOS, however, the caller must perform such
                    extensions, up to 32 bits."
                    Zero extend an argument at caller side for iOS and
                    ignore the argument's unspecified high bits at callee side for
                    all other platforms. }
                 if (ParaDef.Size<4) and Is_Ordinal(ParaDef) then
                   begin
                     if TargetInfo.ABI=abi_aarch64_darwin then
                       begin
                         if Side=CallerSide then
                           begin
                             ParaLoc^.Size:=OS_32;
                             ParaLoc^.Def:=U32IntType;
                           end;
                       end

                     else
                       begin
                         if Side=CalleeSide then
                           begin
                             ParaLoc^.Size:=OS_32;
                             ParaLoc^.Def:=U32IntType;
                           end;
                       end;

                   end;

                 { in case it's a composite, "The argument is passed as though
                   it had been loaded into the registers from a double-word-
                   aligned address with an appropriate sequence of LDR
                   instructions loading consecutive registers from memory" ->
                   in case of big endian, values in not completely filled
                   registers must be shifted to the top bits }
                 if (TargetInfo.Endian=endian_big) and
                    not(ParaLoc^.Size in [OS_64,OS_S64]) and
                    (ParaDef.Typ in [SetDef,RecordDef,ArrayDef,ObjectDef]) then
                   ParaLoc^.ShiftVal:=-(8-TCgSize2Size[ParaLoc^.Size])*8;
               end;
             LOC_MMREGISTER:
               begin
                 ParaLoc^.Register:=NewReg(R_MMREGISTER,CurMMReg,CGSize2SubReg(R_MMREGISTER,ParaLoc^.Size));
                 Inc(CurMMReg);
                 Dec(ParaLen,TCgSize2Size[ParaLoc^.Size]);
               end;
             LOC_REFERENCE:
               begin
                  ParaLoc^.Size:=ParaCGSize;
                  ParaLoc^.Loc:=LOC_REFERENCE;
                  if Assigned(HFABaseDef) then
                    ParaLoc^.Def:=CArrayDef.GetReusable_No_Free(HFABaseDef,ParaLen div HFABaseDef.Size)
                  else
                    ParaLoc^.Def:=ParaDef;

                  { the current stack offset may not be properly aligned in
                    case we're on Darwin and have allocated a non-variadic argument
                    < 8 bytes previously }
                  if TargetInfo.ABI=abi_aarch64_darwin then
                    begin
                      CurStackOffset:=Align(CurStackOffset,ParaLoc^.Def.Alignment);
                      if FirstParaLoc then
                        Result.Alignment:=NewAlignment(Result.Alignment,CurStackOffset);
                    end;

                  { on Darwin, non-variadic arguments take up their actual size
                    on the stack; on other platforms, they take up a multiple of
                    8 bytes }
                  if (TargetInfo.ABI=abi_aarch64_darwin) and
                     not IsVariadic then
                    StackSlotLen:=ParaLen
                  else
                    StackSlotLen:=Align(ParaLen,8);

                  { from the ABI: if arguments occupy partial stack space, they
                    have to occupy the lowest significant bits of a register
                    containing that value which is then stored to memory ->
                    in case of big endian, skip the alignment bytes (if any) }
                  if TargetInfo.Endian=endian_little then
                    ParaLoc^.Reference.Offset:=CurStackOffset
                  else
                    ParaLoc^.Reference.Offset:=CurStackOffset+StackSlotLen-ParaLen;
                  if Side=CallerSide then
                    ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                  else
                    begin
                      ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                      Inc(ParaLoc^.Reference.Offset,16);
                    end;
                  Inc(CurStackOffset,StackSlotLen);
                  ParaLen:=0
               end;
             else
               InternalError(2002071002);
           end;
         FirstParaLoc:=False;
         { <=0 for sign/zero-extended locations }
         until ParaLen<=0;
      end;


    function TCPUParaManager.Create_ParaLoc_Info(P: TAbstractProcDef; Side: TCallerCallee):LongInt;
      begin
        InitParaAllocValues;

        CreateParaLocInfoIntern(P,Side,P.Paras,False);
        Result:=CurStackOffset;

        Create_FuncRetLoc_Info(P,Side);
     end;


    function TCPUParaManager.Create_VarArgs_ParaLoc_Info(P: TAbstractProcDef; Side: TCallerCallee; VarArgsPara: TVarArgsParaList):LongInt;
      begin
        InitParaAllocValues;

        { non-variadic parameters }
        CreateParaLocInfoIntern(P,Side,P.Paras,False);
        if P.ProcCallOption in CStyleArrayOfConst then
          begin
            { on Darwin, we cannot use any registers for variadic parameters }
            if TargetInfo.ABI=abi_aarch64_darwin then
              begin
                CurIntReg:=Succ(RSLastIntParamSupReg);
                CurMMReg:=Succ(RSLastMMParamSupReg);
              end;
            { continue loading the parameters  }
            if Assigned(VarArgsPara) then
              begin
                if Side=CallerSide then
                  CreateParaLocInfoIntern(P,Side,VarArgsPara,True)
                else
                  InternalError(2019021916);
              end;
            Result:=CurStackOffset;
          end
        else
          InternalError(2004102303);

        Create_FuncRetLoc_Info(P,Side);
      end;

begin
   ParaManager:=TCPUParaManager.Create;
end.
