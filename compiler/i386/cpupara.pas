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
       AAsmTAI,AAsmData,CPUBase,CGBase,CGUtils,
       SymConst,SymType,SymSym,SymDef,
       ParaBase,ParaMgr;

    type
       TCPUParaManager = class(TParaManager)
          function Param_Use_ParaLoc(const CGPara:TCGPara):Boolean;override;
          function Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;override;
          function Push_Addr_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;override;
          function Get_Para_Align(CallOption : TProcCallOption):Byte;override;
          function Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;override;
          function Create_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee):LongInt;override;
          function Create_VarArgs_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee; VarArgsPara:TVarArgsParaList):LongInt;override;
          procedure CreateTempParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;CanUseFinalStackLoc : Boolean;var CGPara:TCGPara);override;
          function Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;override;
       private
          procedure CreateStdCallParaLocInfo(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;var ParaSize:LongInt);
          procedure CreateRegisterParaLocInfo(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;var ParaReg,ParaSize:LongInt);
       end;


  implementation

    uses
       CUtils,SysUtils,
       Systems,Verbose,
       SymTable,
       Globals,DefUtil;

      const
        ParaSupRegs : array[0..2] of TSuperRegister = (RS_EAX,RS_EDX,RS_ECX);

{****************************************************************************
                                tcpuparamanager
****************************************************************************}

    function TCPUParaManager.Param_Use_ParaLoc(const CGPara:TCGPara):Boolean;
      var
        ParaLoc : PCGParaLocation;
      begin
        if not Assigned(CGPara.Location) then
          InternalError(200410102);
        Result:=True;
        { All locations are LOC_REFERENCE }
        ParaLoc:=CGPara.Location;
        while Assigned(ParaLoc) do
          begin
            if (ParaLoc^.Loc<>LOC_REFERENCE) then
              begin
                Result:=False;
                Exit;
              end;
            ParaLoc:=ParaLoc^.Next;
          end;
      end;


    function TCPUParaManager.Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;
      var
        Size: LongInt;
      begin
        if Handle_Common_Ret_In_Param(Def,PD,Result) then
          Exit;
        case TargetInfo.System of
          system_i386_win32 :
            begin
              case Def.Typ of
                RecordDef :
                  begin
                    { Win32 GCC returns small records in the FUNCTION_RETURN_REG up to 8 bytes in registers.

                      For stdcall and register we follow delphi instead of GCC which returns
                      only records of a size of 1,2 or 4 bytes in FUNCTION_RETURN_REG }
                    if ((PD.ProcCallOption in [pocall_stdcall,pocall_register]) and
                        (Def.Size in [1,2,4])) or
                       ((PD.ProcCallOption in CDecl_PoCalls) and
                        (Def.Size>0) and
                        (Def.Size<=8)) then
                     begin
                       Result:=False;
                       Exit;
                     end;
                  end;
                else
                  ;
              end;
            end;
          system_i386_darwin,
          system_i386_iphonesim :
            begin
              if PD.ProcCallOption in CDecl_PoCalls then
                begin
                  case Def.Typ of
                    RecordDef :
                      begin
                        Size:=Def.Size;
                        if (Size>0) and
                           (Size<=8) and
                           { only if size is a power of 2 }
                           ((Size and (Size-1)) = 0) then
                          begin
                            Result:=False;
                            Exit;
                          end;
                      end;
                    ProcVarDef:
                      begin
                        Result:=False;
                        Exit;
                      end;
                    else
                      ;
                  end;
              end;
            end;
          else
            ;
        end;
        Result:=inherited Ret_In_Param(Def,PD);
      end;


    function TCPUParaManager.Push_Addr_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;
      begin
        Result:=False;
        { var,out,constref always require address }
        if VarSpez in [vs_var,vs_out,vs_constref] then
          begin
            Result:=True;
            Exit;
          end;
        { Only vs_const, vs_value here }
        case Def.Typ of
          VariantDef :
            begin
              { variants are small enough to be passed by value except if
                required by the windows api

                variants are somethings very delphi/windows specific so do it like
                windows/delphi (FK)
              }
              if ((TargetInfo.System=system_i386_win32) and
                 (CallOption in [pocall_stdcall,pocall_safecall]) and
                 (VarSpez=vs_const)) or
                 (CallOption=pocall_register) then
                Result:=True
              else
                Result:=False;
            end;
          FormalDef :
            Result:=True;
          RecordDef :
            begin
              { Delphi stdcall passes records on the stack for call by value }
              if (TargetInfo.System=system_i386_win32) and
                 (CallOption=pocall_stdcall) and
                 (VarSpez=vs_value) then
                Result:=False
              else
                Result:=
                  (not(CallOption in (CDecl_PoCalls)) and
                   (Def.Size>SizeOf(AInt))) or
                  ((CallOption = pocall_mwpascal) and
                   (VarSpez=vs_const));
            end;
          ArrayDef :
            begin
              { array of const values are pushed on the stack as
                well as dyn. arrays }
              if (CallOption in CDecl_PoCalls) then
                Result:=not(Is_Array_Of_Const(Def) or
                        Is_Dynamic_Array(Def))
              else
                begin
                  Result:=(
                           (TArrayDef(Def).HighRange>=TArrayDef(Def).LowRange) and
                           (Def.Size>SizeOf(AInt))
                          ) or
                          Is_Open_Array(Def) or
                          Is_Array_Of_Const(Def) or
                          Is_Array_Constructor(Def);
                end;
            end;
          ObjectDef :
            Result:=Is_Object(Def);
          StringDef :
            Result:= (TStringDef(Def).StringType in [st_shortstring,st_longstring]);
          ProcVarDef :
            Result:=not(CallOption in CDecl_PoCalls) and not TProcVarDef(Def).Is_AddressOnly;
          SetDef :
            Result:=not(CallOption in CDecl_PoCalls) and (not Is_SmallSet(Def));
          else
            ;
        end;
      end;


    function TCPUParaManager.Get_Para_Align(CallOption : TProcCallOption):Byte;
      begin
        if CallOption=pocall_oldfpccall then
          Result:=4
        else
          Result:=std_param_align;
      end;


    function TCPUParaManager.Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        case CallOption of
          pocall_internproc :
            Result:=[];
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_cppdecl,
          pocall_mwpascal,
          pocall_pascal:
            Result:=[RS_EAX,RS_EDX,RS_ECX];
          pocall_far16,
          pocall_oldfpccall :
            Result:=[RS_EAX,RS_EDX,RS_ECX,RS_ESI,RS_EDI,RS_EBX];
          else
            InternalError(200309071);
        end;
      end;


    function TCPUParaManager.Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[0..first_fpu_imreg-1];
      end;


    function TCPUParaManager.Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[0..first_mm_imreg-1];
      end;


    function TCPUParaManager.Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;
      const
        SaveRegs : TCPURegisterArray = (RS_EBX,RS_ESI,RS_EDI,RS_EBP);
        SaveRegsOldFPCCall : TCPURegisterArray = (RS_EBP);
      begin
        case CallOption of
          pocall_internproc,
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_cppdecl,
          pocall_mwpascal,
          pocall_pascal:
            Result:=SaveRegs;
          pocall_far16,
          pocall_oldfpccall :
            Result:=SaveRegsOldFPCCall;
          else
            InternalError(2018050401);
        end;
      end;


    function  TCPUParaManager.Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;
      var
        RetCGSize  : TCgSize;
        ParaLoc : PCGParaLocation;
        FDef,
        UseDef: TDef;
        Handled: Boolean;
      begin
        if not Assigned(ForceTempDef) then
          UseDef:=P.ReturnDef
        else
          UseDef:=ForceTempDef;
        { on darwin/i386, if a record has only one field and that field is a
          single or double, it has to be returned like a single/double }
        if (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) and
           ((UseDef.Typ=RecordDef) or
            Is_Object(UseDef)) and
           TAbstractRecordSymTable(TAbstractRecordDef(UseDef).SymTable).Has_Single_Field(FDef) and
           (FDef.Typ=FloatDef) and
           (TFloatDef(FDef).FloatType in [S32Real,S64Real]) then
          UseDef:=FDef;

        Handled:=Set_Common_FuncRetLoc_Info(P,UseDef,RetCGSize,Result);
        { normally forcetempdef is passed straight through to
          set_common_funcretloc_info and that one will correctly determine whether
          the location is a temporary one, but that doesn't work here because we
          sometimes have to change the type }
        Result.Temporary:=Assigned(ForceTempDef);
        if Handled then
          Exit;

        { darwin/x86 requires that results < sizeof(aint) are sign/zero
          extended to sizeof(aint) }
        if (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) and
           (Side=CalleeSide) and
           (Result.IntSize>0) and
           (Result.IntSize<SizeOf(AInt)) then
          begin
            Result.Def:=SIntType;
            Result.IntSize:=SizeOf(AInt);
            RetCGSize:=OS_SINT;
            Result.Size:=RetCGSize;
          end;

        { Return in FPU register? }
        if Result.Def.Typ=FloatDef then
          begin
            ParaLoc:=Result.Add_Location;
            ParaLoc^.Loc:=LOC_FPUREGISTER;
            ParaLoc^.Register:=NR_FPU_RESULT_REG;
            ParaLoc^.Size:=RetCGSize;
            ParaLoc^.Def:=Result.Def;
          end
        else
         { Return in register }
          begin
            ParaLoc:=Result.Add_Location;
            ParaLoc^.Loc:=LOC_REGISTER;
            if RetCGSize in [OS_64,OS_S64] then
             begin
               { low 32bits }
               if Side=CallerSide then
                 ParaLoc^.Register:=NR_FUNCTION_RESULT64_LOW_REG
               else
                 ParaLoc^.Register:=NR_FUNCTION_RETURN64_LOW_REG;
               ParaLoc^.Size:=OS_32;
               ParaLoc^.Def:=U32IntType;

               { high 32bits }
               ParaLoc:=Result.Add_Location;
               ParaLoc^.Loc:=LOC_REGISTER;
               if Side=CallerSide then
                 ParaLoc^.Register:=NR_FUNCTION_RESULT64_HIGH_REG
               else
                 ParaLoc^.Register:=NR_FUNCTION_RETURN64_HIGH_REG;
               ParaLoc^.Size:=OS_32;
               ParaLoc^.Def:=U32IntType;
             end
            else
             begin
               ParaLoc^.Size:=RetCGSize;
               ParaLoc^.Def:=Result.Def;
               if Side=CallerSide then
                 ParaLoc^.Register:=NewReg(R_INTREGISTER,RS_FUNCTION_RESULT_REG,CGSize2SubReg(R_INTREGISTER,RetCGSize))
               else
                 ParaLoc^.Register:=NewReg(R_INTREGISTER,RS_FUNCTION_RETURN_REG,CGSize2SubReg(R_INTREGISTER,RetCGSize));
             end;
          end;
      end;


    procedure TCPUParaManager.CreateStdCallParaLocInfo(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;var ParaSize:LongInt);
      var
        I  : Integer;
        HP : TParaVarSym;
        ParaDef : TDef;
        ParaLoc : PCGParaLocation;
        L,
        ParaLen,
        VarAlign   : LongInt;
        ParaAlign  : ShortInt;
        ParaCGSize : TCgSize;
        FirstParaLoc,
        PushAddr   : Boolean;
      begin
        ParaAlign:=Get_Para_Align(P.ProcCallOption);
        { we push Flags and CS as long
          to cope with the IRETD
          and we save 6 register + 4 selectors }
        if (po_interrupt in P.ProcOptions) and (Side=CalleeSide) then
          Inc(ParaSize,8+6*4+4*2);
        { Offset is calculated like:
           sub esp,12
           mov [esp+8],para3
           mov [esp+4],para2
           mov [esp],para1
           call function
          That means for pushes the para with the
          highest offset (see para3) needs to be pushed first
        }
        if P.ProcCallOption in PushLeftRight_PoCalls then
          I:=Paras.Count-1
        else
          I:=0;
        while ((P.ProcCallOption in PushLeftRight_PoCalls) and (I>=0)) or
              (not(P.ProcCallOption in PushLeftRight_PoCalls) and (I<=Paras.Count-1)) do
          begin
            HP:=TParaVarSym(Paras[I]);
            ParaDef:=HP.VarDef;


            PushAddr:=Push_Addr_Param(HP.VarSpez,ParaDef,P.ProcCallOption);
            if PushAddr then
              begin
                ParaLen:=SizeOf(AInt);
                ParaCGSize:=OS_ADDR;
                ParaDef:=CPointerDef.GetReusable_No_Free(ParaDef);
              end
            else
              begin
                ParaLen:=Push_Size(HP.VarSpez,ParaDef,P.ProcCallOption);
                ParaCGSize:=Def_CGSize(ParaDef);
              end;
            HP.ParaLoc[Side].Reset;
            HP.ParaLoc[Side].Size:=ParaCGSize;
            HP.ParaLoc[Side].IntSize:=ParaLen;
            HP.ParaLoc[Side].Def:=ParaDef;
            HP.ParaLoc[Side].Alignment:=ParaAlign;
            { darwin/x86 requires that parameters < sizeof(aint) are sign/ }
            { zero extended to sizeof(aint)                                }
            if (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) and
               (Side = CallerSide) and
               (ParaLen > 0) and
               (ParaLen < SizeOf(AInt)) then
              begin
                ParaCGSize:=OS_SINT;
                ParaDef:=SIntType;
              end;
            { Copy to stack? }
            if (ParaCGSize=OS_NO) or
               (Use_Fixed_Stack) then
              begin
                ParaLoc:=HP.ParaLoc[Side].Add_Location;
                ParaLoc^.Loc:=LOC_REFERENCE;
                ParaLoc^.Size:=ParaCGSize;
                ParaLoc^.Def:=ParaDef;
                if Side=CallerSide then
                  ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                else
                  ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                VarAlign:=Used_Align(Size_2_Align(ParaLen),ParaAlign,ParaAlign);

                { don't let push_size return 16, because then we can    }
                { read past the end of the heap since the value is only }
                { 10 bytes long (JM)                                    }
                if (ParaCGSize = OS_F80) and
                   (TargetInfo.System in [system_i386_darwin,system_i386_iphonesim]) then
                  ParaLen:=16;
                ParaLoc^.Reference.Offset:=ParaSize;
                if Side=CalleeSide then
                  Inc(ParaLoc^.Reference.Offset,TargetInfo.first_parm_offset);
                ParaSize:=Align(ParaSize+ParaLen,VarAlign);
              end
            else
              begin
                if ParaLen=0 then
                  InternalError(2005011606);
                FirstParaLoc:=True;
                while (ParaLen>0) do
                  begin
                    ParaLoc:=HP.ParaLoc[Side].Add_Location;
                    ParaLoc^.Loc:=LOC_REFERENCE;
                    { single and double need a single location }
                    if (ParaCGSize in [OS_F64,OS_F32]) then
                      begin
                        ParaLoc^.Size:=ParaCGSize;
                        ParaLoc^.Def:=ParaDef;
                        L:=ParaLen;
                      end
                    else
                      begin
                        { We can allocate at maximum 32 bits per location }
                        if ParaLen>SizeOf(AInt) then
                          begin
                            L:=SizeOf(AInt);
                            ParaLoc^.Def:=UIntType;
                          end
                        else
                          begin
                            L:=ParaLen;
                            ParaLoc^.Def:=Get_ParaLoc_Def(ParaDef,L,FirstParaLoc);
                          end;
                        ParaLoc^.Size:=Int_CGSize(L);
                      end;
                    if (Side=CallerSide) or
                       (po_nostackframe in P.ProcOptions) then
                      ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                    else
                      ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                    VarAlign:=Used_Align(Size_2_Align(L),ParaAlign,ParaAlign);
                    ParaLoc^.Reference.Offset:=ParaSize;
                    if Side=CalleeSide then
                      if not(po_nostackframe in P.ProcOptions) then
                        Inc(ParaLoc^.Reference.Offset,TargetInfo.first_parm_offset)
                      else
                        { return address }
                        Inc(ParaLoc^.Reference.Offset,4);
                    ParaSize:=Align(ParaSize+L,VarAlign);
                    Dec(ParaLen,L);
                    FirstParaLoc:=False;
                  end;
              end;
            if P.ProcCallOption in PushLeftRight_PoCalls then
              Dec(I)
            else
              Inc(I);
          end;
      end;


    procedure TCPUParaManager.CreateRegisterParaLocInfo(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;
                                                            var ParaReg,ParaSize:LongInt);
      var
        HP : TParaVarSym;
        ParaDef : TDef;
        ParaLoc : PCGParaLocation;
        ParaCGSize : TCgSize;
        I : Integer;
        L,
        ParaLen,
        VarAlign : LongInt;
        ParaAlign : ShortInt;
        Pass : Byte;
        FirstParaLoc,
        PushAddr : Boolean;
      begin
        if Paras.Count=0 then
          Exit;
        ParaAlign:=Get_Para_Align(P.ProcCallOption);

        { clean up here so we can later detect properly if a parameter has been
          assigned or not
        }
        for I:=0 to Paras.Count-1 do
          TParaVarSym(Paras[I]).ParaLoc[Side].Reset;
        { Register parameters are assigned from left to right,
          stack parameters from right to left so assign first the
          register parameters in a first pass, in the second
          pass all unhandled parameters are done }
        for Pass:=1 to 2 do
          begin
            if Pass=1 then
              I:=0
            else
              I:=Paras.Count-1;
            while True do
              begin
                HP:=TParaVarSym(Paras[I]);
                ParaDef:=HP.VarDef;
                if not(Assigned(HP.ParaLoc[Side].Location)) then
                  begin
                    PushAddr:=Push_Addr_Param(HP.VarSpez,HP.VarDef,P.ProcCallOption);
                    if PushAddr then
                      begin
                        ParaLen:=SizeOf(AInt);
                        ParaCGSize:=OS_ADDR;
                        ParaDef:=CPointerDef.GetReusable_No_Free(ParaDef);
                      end
                    else
                      begin
                        ParaLen:=Push_Size(HP.VarSpez,HP.VarDef,P.ProcCallOption);
                        ParaCGSize:=Def_CGSize(HP.VarDef);
                      end;
                    HP.ParaLoc[Side].Size:=ParaCGSize;
                    HP.ParaLoc[Side].IntSize:=ParaLen;
                    HP.ParaLoc[Side].Alignment:=ParaAlign;
                    HP.ParaLoc[Side].Def:=ParaDef;
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
                    if (ParaReg<=High(ParaSupRegs)) and
                       (ParaLen<=SizeOf(AInt)) and
                       (not(HP.VarDef.Typ in [FloatDef,RecordDef,ArrayDef]) or
                        PushAddr or
                        Is_Dynamic_Array(HP.VarDef)) and
                       (not(vo_is_parentfp in HP.VarOptions) or
                        not(po_delphi_nested_cc in P.ProcOptions)) then
                      begin
                        if Pass=1 then
                          begin
                            ParaLoc:=HP.ParaLoc[Side].Add_Location;
                            ParaLoc^.Size:=ParaCGSize;
                            ParaLoc^.Def:=ParaDef;
                            ParaLoc^.Loc:=LOC_REGISTER;
                            ParaLoc^.Register:=NewReg(R_INTREGISTER,ParaSupRegs[ParaReg],CGSize2SubReg(R_INTREGISTER,ParaCGSize));
                            Inc(ParaReg);
                          end;
                      end
                    else
                      if Pass=2 then
                        begin
                          { Copy to stack? }
                          if (Use_Fixed_Stack) or
                             (ParaCGSize=OS_NO) then
                            begin
                              ParaLoc:=HP.ParaLoc[Side].Add_Location;
                              ParaLoc^.Loc:=LOC_REFERENCE;
                              ParaLoc^.Size:=ParaCGSize;
                              ParaLoc^.Def:=ParaDef;
                              if Side=CallerSide then
                                ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                              else
                                ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                              VarAlign:=Used_Align(Size_2_Align(ParaLen),ParaAlign,ParaAlign);
                              ParaLoc^.Reference.Offset:=ParaSize;
                              if Side=CalleeSide then
                                Inc(ParaLoc^.Reference.Offset,TargetInfo.first_parm_offset);
                              ParaSize:=Align(ParaSize+ParaLen,VarAlign);
                            end
                          else
                            begin
                              if ParaLen=0 then
                                InternalError(2005011607);
                              FirstParaLoc:=True;
                              while (ParaLen>0) do
                                begin
                                  ParaLoc:=HP.ParaLoc[Side].Add_Location;
                                  ParaLoc^.Loc:=LOC_REFERENCE;
                                  { Extended and double need a single location }
                                  if (ParaCGSize in [OS_F64,OS_F32]) then
                                    begin
                                      ParaLoc^.Size:=ParaCGSize;
                                      ParaLoc^.Def:=ParaDef;
                                      L:=ParaLen;
                                    end
                                  else
                                    begin
                                      { We can allocate at maximum 32 bits per location }
                                      if ParaLen>SizeOf(AInt) then
                                        begin
                                          L:=SizeOf(AInt);
                                          ParaLoc^.Def:=UIntType;
                                        end
                                      else
                                        begin
                                          L:=ParaLen;
                                          ParaLoc^.Def:=Get_ParaLoc_Def(ParaDef,L,FirstParaLoc);
                                        end;
                                      ParaLoc^.Size:=Int_CGSize(L);
                                    end;
                                  if Side=CallerSide then
                                    ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                                  else
                                    ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                                  VarAlign:=Used_Align(Size_2_Align(L),ParaAlign,ParaAlign);
                                  ParaLoc^.Reference.Offset:=ParaSize;
                                  if Side=CalleeSide then
                                    Inc(ParaLoc^.Reference.Offset,TargetInfo.first_parm_offset);
                                  ParaSize:=Align(ParaSize+L,VarAlign);
                                  Dec(ParaLen,L);
                                  FirstParaLoc:=False;
                                end;
                            end;
                        end;
                  end;
                case Pass of
                  1:
                    begin
                      if I=Paras.Count-1 then
                        Break;
                      Inc(I);
                    end;
                  2:
                    begin
                      if I=0 then
                        Break;
                      Dec(I);
                    end;
                end;
              end;
          end;
      end;


    function TCPUParaManager.Create_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee):LongInt;
      var
        ParaSize,
        ParaReg : LongInt;
      begin
        ParaSize:=0;
        ParaReg:=0;
        case P.ProcCallOption of
          pocall_register :
            CreateRegisterParaLocInfo(P,Side,P.Paras,ParaReg,ParaSize);
          pocall_internproc :
            begin
              { Use default calling }
{$warnings off}
              if (pocall_default=pocall_register) then
                CreateRegisterParaLocInfo(P,Side,P.Paras,ParaReg,ParaSize)
              else
                CreateStdCallParaLocInfo(P,Side,P.Paras,ParaSize);
{$warnings on}
            end;
          else
            CreateStdCallParaLocInfo(P,Side,P.Paras,ParaSize);
        end;
        Create_FuncRetLoc_Info(P,Side);
        Result:=ParaSize;
      end;


    function TCPUParaManager.Create_VarArgs_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee; VarArgsPara:TVarArgsParaList):LongInt;
      var
        ParaSize : LongInt;
      begin
        ParaSize:=0;
        { calculate the registers for the normal parameters }
        CreateStdCallParaLocInfo(P,Side,P.Paras,ParaSize);
        { append the varargs }
        if Assigned(VarArgsPara) then
          begin
            if Side=CallerSide then
              CreateStdCallParaLocInfo(P,Side,VarArgsPara,ParaSize)
            else
              InternalError(2019021926);
          end;
        Create_FuncRetLoc_Info(P,Side);
        Result:=ParaSize;
      end;


    procedure TCPUParaManager.CreateTempParaLoc(List: TAsmList;CallOption : TProcCallOption;ParaSym : TParaVarSym;CanUseFinalStackLoc : Boolean;var CGPara:TCGPara);
      begin
        { Never a need for temps when value is pushed (calls inside parameters
          will simply allocate even more stack space for their parameters) }
        if not(Use_Fixed_Stack) then
          CanUseFinalStackLoc:=True;
        inherited CreateTempParaLoc(List,CallOption,ParaSym,CanUseFinalStackLoc,CGPara);
      end;


begin
   ParaManager:=TCPUParaManager.Create;
end.
