{
    Copyright (c) 2002 by Florian Klaempfl

    Generates the argument location information for x86-64 target

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
      CPUBase,CGBase,CGUtils,
      SymConst,SymType,SymSym,SymDef,
      ParaBase,ParaMgr;

    type
       TCPUParaManager = class(TParaManager)
       private
          procedure CreateParaLocInfoIntern(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;
                                               var IntParaReg,MMParaReg,ParaSize:LongInt;VarArgsParas: Boolean);
       public
          function Param_Use_ParaLoc(const CGPara:TCGPara):Boolean;override;
          function Push_Addr_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;override;
          function Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;override;
          function Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;override;
          function Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;override;
          function Get_Saved_Registers_MM(CallOption: TProcCallOption):TCPURegisterArray;override;
          function Create_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee):LongInt;override;
          function Create_VarArgs_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee; VarArgsPara:TVarArgsParaList):LongInt;override;
          function Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;override;
       end;

  implementation

    uses
       CUtils,Verbose,
       Systems,
       Globals,DefUtil,
       SymTable,SymUtil,
       CPUPI,CPUInfo,
       CGX86,CGObj,CGCPU;

    const
      ParaIntSupRegs : array[0..5] of TSuperRegister = (RS_RDI,RS_RSI,RS_RDX,RS_RCX,RS_R8,RS_R9);
      ParaMMSupRegs : array[0..7] of TSuperRegister = (RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5,RS_XMM6,RS_XMM7);

      ParaIntSupRegsWinX64 : array[0..3] of TSuperRegister = (RS_RCX,RS_RDX,RS_R8,RS_R9);
      ParaMMSupRegsWinX64 : array[0..3] of TSuperRegister = (RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3);
      ParaMMSupRegsVectorCall : array[0..5] of TSuperRegister = (RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5);
{
   The argument classification code largely comes from libffi:

   ffi64.c - Copyright (c) 2002, 2007  Bo Thorsen <bo@suse.de>
             Copyright (c) 2008  Red Hat, Inc.

   x86-64 Foreign Function Interface

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   ``Software''), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED ``AS IS'', WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
   ----------------------------------------------------------------------- *)
}

    const
      { This many classes are required in order to support 4 YMMs (_m256) in a
        homogeneous vector aggregate under vectorcall. [Kit] }
      MaxParaClasses = 16;

    type
      TX64ParaClassType = (
        X64NoClass,
        X64IntegerClass,X64IntegerSIClass,
        X64SSEClass,X64SSESFClass,X64SSEDFClass,X64SSEUpClass,
        X64X87Class,X64X87UpClass,
        X64ComplexX87Class,
        X64MemoryClass
      );

      TX64ParaClass = record
        Def: TDef;
        Typ: TX64ParaClassType;
      end;

      TX64ParaClasses = array[0..MaxParaClasses-1] of TX64ParaClass;

    { Win64-specific helper }
    function AggregateInRegistersWin64(VarSpez:TVarSpez;Size:LongInt):Boolean;
      begin
    { TODO: Temporary hack: vs_const parameters are always passed by reference for win64}
        Result:=(VarSpez=vs_value) and (Size in [1,2,4,8])
      end;

    (* x86-64 register passing implementation.  See x86-64 ABI for details.  Goal
       of this code is to classify each 8bytes of incoming argument by the register
       class and assign registers accordingly.  *)


       function ClassifyRepresentativeDef(Def1, Def2: TDef): TDef;
         var
           Def1Size, Def2Size: ASizeInt;
         begin
           if not Assigned(Def1) then
             Result:=Def2
           else if not Assigned(Def2) then
             Result:=Def1
           else
             begin
               Def1Size:=Def1.Size;
               Def2Size:=Def2.Size;
               if Def1Size>Def2Size then
                 Result:=Def1
               else if Def2Size>Def1Size then
                 Result:=Def2
               else if Def1.Alignment>Def2.Alignment then
                 Result:=Def1
               else
                 Result:=Def2;
             end;
         end;

       (* Classify the argument of type TYPE and mode MODE.
          CLASSES will be filled by the register class used to pass each word
          of the operand.  The number of words is returned.  In case the parameter
          should be passed in memory, 0 is returned. As a special case for zero
          sized containers, classes[0] will be NO_CLASS and 1 is returned.

          real_size contains either def.size, or a value derived from
          def.bitpackedsize and the field offset denoting the number of bytes
          spanned by a bitpacked field

          See the x86-64 PS ABI for details.
       *)
       procedure ClassifySingleIntegerClass(Def: TDef; Size,RealSize: AInt; var Cl: TX64ParaClass; ByteOffset: AInt);
         begin
           if (ByteOffset=0) and
              (RealSize in [1,2,4,8]) and
              (not Assigned(Cl.Def) or
               (Def.Alignment>=Cl.Def.Alignment)) then
             Cl.Def:=Def;
           if Size<=4 then
             begin
               Cl.Typ:=X64IntegerSIClass;
               { The ABI does not require any sign/zero extension for parameters,
                 except for _Bool (= Pascal boolean) to 8 bits. However, some
                 compilers (clang) extend them to 32 bits anyway and rely on it
                 -> also do it for compatibility when calling such code }
               if not Assigned(Cl.Def) or
                  (Cl.Def.Typ<>OrdDef) or
                  (TOrdDef(Cl.Def).OrdType<>PasBool1) then
                 Cl.Def:=U32IntType;
             end
           else
             begin
               Cl.Typ:=X64IntegerClass;
               if not Assigned(Cl.Def) or
                  (Cl.Def.Size<Size) or
                  (not(Cl.Def.Typ in [OrdDef,FloatDef,PointerDef,ClassRefDef]) and
                   not Is_Implicit_Pointer_Object_Type(Cl.Def) and
                   not Is_DynamicString(Cl.Def) and
                   not Is_Dynamic_Array(Cl.Def)) then
                 Cl.Def:=U64IntType;
             end;
         end;


       function ClassifyAsIntegerArgument(Def: TDef; RealSize: AInt; var Classes: TX64ParaClasses; ByteOffset: AInt): LongInt;
         var
           Size: AInt;
         begin
           Size:=ByteOffset+RealSize;
           ClassifySingleIntegerClass(Def,Size,RealSize,Classes[0],ByteOffset);
           if Size<=8 then
             Result:=1
           else
             begin
               ClassifySingleIntegerClass(Def,Size-8,RealSize,Classes[1],ByteOffset-8);
               if Size>16 then
                 InternalError(2010021401);
               Result:=2;
             end
         end;


    (* Return the union class of CLASS1 and CLASS2.
       See the x86-64 PS ABI for details.  *)

    function MergeClasses(Class1, Class2: TX64ParaClass): TX64ParaClass;
      begin
        (* Rule #1: If both classes are equal, this is the resulting class.  *)
        if (Class1.Typ=Class2.Typ) then
          begin
            Result.Typ:=Class1.Typ;
            Result.Def:=ClassifyRepresentativeDef(Class1.Def,Class2.Def);
            Exit;
          end;

        (* Rule #2: If one of the classes is NO_CLASS, the resulting class is
           the other class.  *)
        if (Class1.Typ=X64NoClass) then
          Exit(Class2);
        if (Class2.Typ=X64NoClass) then
          Exit(Class1);

        (* Rule #3: If one of the classes is MEMORY, the result is MEMORY.  *)
        if (Class1.Typ=X64MemoryClass) then
          Exit(Class1)
        else if (Class2.Typ=X64MemoryClass) then
          Exit(Class2);

        (* Rule #4: If one of the classes is INTEGER, the result is INTEGER.  *)
        { 32 bit }
        if ((Class1.Typ=X64IntegerSIClass) and
            (Class2.Typ=X64SSESFClass)) then
          Exit(Class1)
        else if ((Class2.Typ=X64IntegerSIClass) and
            (Class1.Typ=X64SSESFClass)) then
          Exit(Class2);
        { 64 bit }
        if (Class1.Typ in [X64IntegerClass,X64IntegerSIClass]) then
          begin
            Result:=Class1;
            if Result.Def.Size<8 then
              begin
                Result.Typ:=X64IntegerClass;
                Result.Def:=S64IntType;
              end;
            Exit
          end
        else if (Class2.Typ in [X64IntegerClass,X64IntegerSIClass]) then
          begin
            Result:=Class2;
            if Result.Def.Size<8 then
              begin
                Result.Typ:=X64IntegerClass;
                Result.Def:=S64IntType;
              end;
            Exit
          end;

        (* Rule #5: If one of the classes is X87, X87UP, or COMPLEX_X87 class,
           MEMORY is used.  *)
        if (Class1.Typ in [X64X87Class,X64X87UpClass,X64ComplexX87Class]) then
          begin
            Result:=Class1;
            Result.Typ:=X64MemoryClass;
            Exit;
          end
        else if (Class2.Typ in [X64X87Class,X64X87UpClass,X64ComplexX87Class]) then
          begin
            Result:=Class2;
            Result.Typ:=X64MemoryClass;
            Exit;
          end;

        (* Rule #6: Otherwise class SSE is used.  *)
        if Class1.Def.Size>Class2.Def.Size then
          Result:=Class1
        else
          Result:=Class2;
        Result.Typ:=X64SSEClass;
        Result.Def:=S64FloatType;
      end;


    function ClassifyArgument(CallOption: TProcCallOption; Def: TDef; ParentDef: TDef; VarSpez: TVarSpez; RealSize: AInt; var Classes: TX64ParaClasses; ByteOffset: AInt; RoundTo8: Boolean): LongInt; forward;

    function InitAggregateClassification(CallOption: TProcCallOption; Def: TDef; ParentDef: TDef; VarSpez: TVarSpez; ByteOffset: AInt; out Words: LongInt; out Classes: TX64ParaClasses): LongInt;
      var
        I: LongInt;
      begin
        Words:=0;

        { we'll be merging the classes elements with the subclasses
          elements, so initialise them first }
        for I:=Low(Classes) to High(Classes) do
          begin
            Classes[I].Typ:=X64NoClass;
            Classes[I].Def:=nil;
          end;

        { win64 follows a different convention here }
        if x86_64_use_ms_abi(CallOption) then
          begin
            if AggregateInRegistersWin64(VarSpez,Def.Size) then
              begin
                Classes[0].Typ:=X64IntegerClass;
                Classes[0].Def:=Def;
                Result:=1;
              end
            else if (CallOption = pocall_vectorcall) then
              begin
                Words := (Def.Size+ByteOffset mod 8+7) div 8;
                case Words of
                0:
                  Exit(0);
                1..4:
                  { Aligned vector or array elements }
                  Result := Words;
                else
                  if ((Def.AggregateAlignment mod (Words shl 3)) = 0) or
                    Assigned(ParentDef) and ((ParentDef.AggregateAlignment mod 16) = 0)
                    then
                      begin
                        { Field of aligned vector type }
                        if Words = 0 then
                          begin
                            Classes[0].Typ:=X64NoClass;
                            Classes[0].Def:=Def;
                            Result := 1;
                          end
                        else
                          Result := Words;
                      end
                  else
                    Result := 0;
                end;
              end
            else
              Result := 0;

            Exit;
          end;

        (* If the struct is larger than 32 bytes, pass it on the stack.  *)
        if Def.Size > 32 then
          Exit(0);

        { if a struct starts an offset not divisible by 8, it can span extra
          words }
        Words:=(Def.Size+ByteOffset mod 8+7) div 8;

        (* Zero sized arrays or structures are NO_CLASS.  We return 0 to
           signal memory class, so handle it as special case.  *)
        if (Words=0) then
          begin
            Classes[0].Typ:=X64NoClass;
            Classes[0].Def:=Def;
            Exit(1);
          end;

        Result:=Words;
      end;


    function ClassifyAggregateElement(CallOption: TProcCallOption; Def: TDef; ParentDef: TDef; VarSpez: TVarSpez; RealSize: AInt; var Classes: TX64ParaClasses; NewByteOffset: AInt): LongInt;
      var
        SubClasses: TX64ParaClasses;
        I,
        Pos: LongInt;
      begin
        FillChar(SubClasses,SizeOf(SubClasses),0);
        Result:=ClassifyArgument(CallOption,Def,ParentDef,VarSpez,RealSize,SubClasses,NewByteOffset, True);
        if (Result=0) then
          Exit;

        Pos:=NewByteOffset div 8;
        if Result-1+Pos>High(Classes) then
          InternalError(2010053108);
        for I:=0 to Result-1 do
          begin
            Classes[I+Pos] :=
              MergeClasses(SubClasses[I],Classes[I+Pos]);
          end;
        Inc(Result,Pos);
      end;


    function FinalizeAggregateClassification(CallOption: TProcCallOption; Def: TDef; Words: LongInt; var Classes: TX64ParaClasses): LongInt;
      var
        I, VecSize, MaxVecSize: LongInt;
      begin
        { Workaround: It's not immediately possible to determine if a Double is
          by itself or is part of an aligned vector. If the latter, correct the
          class definitions here. [Kit] }

        if (Classes[0].Typ = X64SSEDFClass) and (Classes[1].Typ = X64SSEUpClass) then
          Classes[0].Typ := X64SSEClass;

        if (Words>2) then
          begin
            { When size > 16 bytes, if the first one isn't
              X86_64_SSE_CLASS or any other ones aren't
              X86_64_SSEUP_CLASS, everything should be passed in
              memory... }
            if (Classes[0].Typ<>X64SSEClass) then
              begin
                { ... except if the calling convention is 'vectorcall', then
                  check to see if we don't have an HFA of 3 or 4 Doubles }
                if (CallOption <> pocall_vectorcall) or (Words > 4) then
                  Exit(0);

                for I := 0 to Words - 1 do
                  if Classes[I].Typ <> X64SSEDFClass then
                    Exit(0);

                Exit(Words);
              end;

            if ((Words shl 3) > Def.AggregateAlignment) then
              { The alignment is wrong for this vector size, hence it is unaligned }
              Exit(0);

            VecSize := 1;
            MaxVecSize := Words;

            for I:=1 to Words-1 do
              if (Classes[I].Typ=X64SSEUpClass) then
                Inc(VecSize)
              else
                begin
                  { Exceptional case. Check that we're not dealing an array of
                    aligned vectors that is itself aligned to a stricter
                    boundary (e.g. 4 XMM registers that can be merged into a
                    single ZMM register). }
                  if
                    (Classes[I].Typ <> X64SSEClass) or { Easy case first - is it actually another SSE vector? }
                    ((VecSize and (VecSize - 1)) <> 0) or { If vecsize is not a power of two, then it is definitely not a valid vector }
                    (VecSize > MaxVecSize) or ((MaxVecSize < Words) and (VecSize <> MaxVecSize)) { Mixture of XMMs and YMMs, for example, is not valid }
                  then
                    Exit(0);

                  Classes[I].Typ := X64SSEUpClass;
                  MaxVecSize := VecSize;
                  VecSize := 1;
                end;

            if VecSize <> MaxVecSize then
              { Last vector is of a different size }
              Exit(0);

            if VecSize > 2 then
              begin
                { Cannot use 256-bit and 512-bit vectors if we're not using AVX }
                if not UseAVX then
                  Exit(0);

                { WARNING: There is currently no support for 256-bit and 512-bit
                  aligned vectors, so if an aggregate contains more than two
                  eightbyte words, it must be passed in memory. When 256-bit and
                  512-bit vectors are fully supported, remove the following
                  line. [Kit] }
                Exit(0);
              end;
          end;

        (* Final merger cleanup.  *)
        (* The first one must never be X86_64_SSEUP_CLASS or
           X86_64_X87UP_CLASS.  *)
        if (Classes[0].Typ=X64SSEUpClass) or
           (Classes[0].Typ=X64X87UpClass) then
          InternalError(2010021402);

        for I:=0 to Words-1 do
          begin
            (* If one class is MEMORY, everything should be passed in
               memory.  *)
            if (Classes[I].Typ=X64MemoryClass) then
              Exit(0);

            (* The X86_64_SSEUP_CLASS should be always preceded by
               X86_64_SSE_CLASS or X86_64_SSEUP_CLASS.  *)
            if (Classes[I].Typ=X64SSEUpClass) and
               (Classes[I-1].Typ<>X64SSEClass) and
               (Classes[I-1].Typ<>X64SSEUpClass) then
              begin
                Classes[I].Typ:=X64SSEClass;
                Classes[I].Def:=CArrayDef.GetReusable_No_Free(S32FloatType,2);
              end;

            (*  If X86_64_X87UP_CLASS isn't preceded by X86_64_X87_CLASS,
                everything should be passed in memory.  *)
            if (Classes[I].Typ=X64X87UpClass) and
               (Classes[I-1].Typ<>X64X87Class) then
              Exit(0);

            (* FPC addition: because we store an extended in 10 bytes, the
               X86_64_X87UP_CLASS can be replaced with e.g. INTEGER if an
               extended is followed by e.g. an array [0..5] of byte -> we also
               have to check whether each X86_64_X87_CLASS is followed by
               X86_64_X87UP_CLASS -- if not, pass in memory

               This cannot happen in the original ABI, because there
               sizeof(extended) = 16 and hence nothing can be merged with
               X86_64_X87UP_CLASS and change it into something else *)
            if (Classes[I].Typ=X64X87Class) and
               ((I=(Words-1)) or
                (Classes[I+1].Typ<>X64X87UpClass)) then
              Exit(0);
          end;


          { FIXME: in case a record contains empty padding space, e.g. a
            "single" field followed by a "double", then we have a problem
            because the cgpara helpers cannot figure out that they should
            skip 4 bytes after storing the single (LOC_MMREGISTER with size
            OS_F32) to memory before storing the double -> for now scale
            such locations always up to 64 bits, although this loads/stores
            some superfluous data }
          { 1) the first part is 32 bit while there is still a second part }
          if (Classes[1].Typ<>X64NoClass) then
            case Classes[0].Typ of
              X64IntegerSIClass:
                begin
                  Classes[0].Typ:=X64IntegerClass;
                  Classes[0].Def:=S64IntType;
                end;
              X64SSESFClass:
                begin
                  Classes[0].Typ:=X64SSEClass;
                  Classes[0].Def:=CArrayDef.GetReusable_No_Free(S32FloatType,2);
                end;
              else
                ;
            end;
          { 2) the second part is 32 bit, but the total size is > 12 bytes }
          if (Def.Size>12) then
            case Classes[1].Typ of
              X64IntegerSIClass:
                begin
                  Classes[1].Typ:=X64IntegerClass;
                  Classes[1].Def:=S64IntType;
                end;
              X64SSESFClass:
                begin
                  Classes[1].Typ:=X64SSEClass;
                  Classes[1].Def:=CArrayDef.GetReusable_No_Free(S32FloatType,2);
                end;
              else
                ;
            end;

          Result:=Words;
      end;


    function TryBuildHomogeneousAggregate(Def: TDef; Words: LongInt; var Classes: TX64ParaClasses): LongInt;
      var
        I, VecSize, MaxVecSize, VecCount: LongInt;
        {size, }ByteOffset: AInt;
        VS: TFieldVarSym;
        CheckAlignment: Boolean;
      begin
        if (Words = 0) then
          { Should be at least 1 word at this point }
          InternalError(2018013100);

        case Classes[0].Typ of
          X64SSESFClass:
            begin
              { Should be an HFA of only a Single }
              for I := 1 to High(Classes) do
                if Classes[I].Typ <> X64NoClass then
                  Exit(0);

              Result := 1;
            end;
          X64SSEDFClass:
            begin
              { Possibly an HFA of Doubles }

              if TAbstractRecordDef(Def).SymTable.SymList.Count = 0 then
                Exit(0);

              { Get the information and position on the last entry }
              VS:=TFieldVarSym(TAbstractRecordDef(Def).SymTable.SymList[TAbstractRecordDef(Def).SymTable.SymList.Count - 1]);
              //size:=vs.vardef.size;

              CheckAlignment:=True;
              if not TAbstractRecordSymTable(TAbstractRecordDef(Def).SymTable).Is_Packed then
                begin
                  ByteOffset:=VS.FieldOffset;
                  //size:=vs.vardef.size;
                end
              else
                begin
                  ByteOffset:=VS.FieldOffset div 8;
                  if (VS.VarDef.Typ in [OrdDef,EnumDef]) then
                    begin
                      { calculate the number of bytes spanned by
                        this bitpacked field }
                      //size:=((vs.fieldoffset+vs.vardef.packedbitsize+7) div 8)-(vs.fieldoffset div 8);
                      { our bitpacked fields are interpreted as always being
                        aligned, because unlike in C we don't have char:1, int:1
                        etc (so everything is basically a char:x) }
                      CheckAlignment:=False;
                    end
                  else
                    ;//size:=vs.vardef.size;
                end;
              { If [..] an object [..] contains unaligned fields, it has class
                MEMORY }
              if CheckAlignment and
                 (Align(ByteOffset,VS.VarDef.StructAlignment)<>ByteOffset) then
                begin
                  Result:=0;
                  Exit;
                end;

              if Words > 4 then
                { HFA too large }
                Exit(0);

              for I := 1 to Words - 1 do
                if Classes[I].Typ <> X64SSEDFClass then
                  Exit(0);

              Result := Words;
            end;
          X64SSEClass:
            begin
              { Determine the nature of the classes.
                - If the SSE is by itself, then it is an HFA consisting of 2 Singles.
                - If the SSE is followed by an SSESF, then it is an HFA consisting of 3 Singles.
                - If the SSE is followed by an SSE and nothing else, then it is an HFA consisting of 4 Singles.
                - If the SSE is followed by an SSE, but another class follows, then it is an HFA that is too large.
                - If the SSE is followed by an SSEUP, then it is an HVA of some kind.
              }
              case Classes[1].Typ of
                X64NoClass:
                  begin
                    for I := 2 to Words - 1 do
                      if Classes[I].Typ <> X64NoClass then
                        { Compound type }
                        Exit(0);

                    { Split into 2 Singles again so they correctly fall into separate XMM registers }
                    Classes[0].Typ := X64SSESFClass;
                    if Classes[0].Def.Typ = ArrayDef then
                       { Break up the array }
                      Classes[0].Def := TDef(TArrayDef(Classes[0].Def).ElementDef); { Break up the array }
                    Classes[1].Typ := X64SSESFClass;
                    Classes[1].Def := Classes[0].Def;
                    Result := 2;
                  end;
                X64SSESFClass:
                  begin
                    for I := 2 to Words - 1 do
                      if Classes[I].Typ <> X64NoClass then
                        { Compound type }
                        Exit(0);

                    Classes[2].Typ := X64SSESFClass;
                    Classes[2].Def := Classes[1].Def; { Transfer class 1 to class 2 }
                    Classes[0].Typ := X64SSESFClass;
                    if Classes[0].Def.Typ = ArrayDef then
                      { Break up the array }
                      Classes[0].Def := TDef(TArrayDef(Classes[0].Def).ElementDef);
                    Classes[1].Typ := X64SSESFClass;
                    Classes[1].Def := Classes[0].Def;
                    Result := 3;
                  end;
                X64SSEClass:
                  begin
                    for I := 2 to Words - 1 do
                      if Classes[I].Typ <> X64NoClass then
                        { HFA too large (or not a true HFA) }
                        Exit(0);

                    if Classes[0].Def.Typ = ArrayDef then
                       { Break up the array }
                      Classes[0].Def := TDef(TArrayDef(Classes[0].Def).ElementDef);
                    if Classes[1].Def.Typ = ArrayDef then
                       { Break up the array }
                      Classes[2].Def := TDef(TArrayDef(Classes[1].Def).ElementDef);

                    Classes[1].Def := Classes[0].Def;
                    Classes[3].Def := Classes[2].Def;

                    Classes[0].Typ := X64SSESFClass;
                    Classes[1].Typ := X64SSESFClass;
                    Classes[2].Typ := X64SSESFClass;
                    Classes[3].Typ := X64SSESFClass;
                    Result := 4;
                  end;
                X64SSEUpClass:
                  begin
                    { Determine vector size }
                    VecCount := 1;
                    VecSize := 2;
                    MaxVecSize := Words;

                    for I := 2 to Words - 1 do
                      if (Classes[I].Typ=X64SSEUpClass) then
                        Inc(VecSize)
                      else
                        begin
                          if
                            (Classes[I].Typ <> X64SSEClass) or { Easy case first - is it actually another SSE vector? }
                            ((VecSize and (VecSize - 1)) <> 0) or { If vecsize is not a power of two, then it is definitely not a valid aggregate }
                            (VecSize > MaxVecSize) or ((MaxVecSize < Words) and (VecSize <> MaxVecSize)) { Mixture of XMMs and YMMs, for example, is not valid }
                          then
                            Exit(0);

                          Inc(VecCount);
                          MaxVecSize := VecSize;
                          VecSize := 1;
                        end;

                    if VecSize <> MaxVecSize then
                      { Last vector is of a different size }
                      Exit(0);

                    if VecCount > 4 then
                      { HVA too large }
                      Exit(0);

                    Result := Words;
                  end;
                else
                  Exit(0);
              end;
            end;
          else
            Exit(0);
        end;

      end;


    function ClassifyRecord(CallOption: TProcCallOption; Def: TDef; ParentDef: TDef; VarSpez: TVarSpez; var Classes: TX64ParaClasses; ByteOffset: AInt): LongInt;
      var
        VS: TFieldVarSym;
        Size,
        NewByteOffset: AInt;
        I,
        Words,
        Num: LongInt;
        CheckAlignment: Boolean;
      begin
        Result:=InitAggregateClassification(CallOption,Def,ParentDef,VarSpez,ByteOffset,Words,Classes);
        if (Words=0) then
          Exit;

        (* Merge the fields of the structure.  *)
        for I:=0 to TAbstractRecordDef(Def).SymTable.SymList.Count-1 do
          begin
            if not Is_Normal_FieldVarSym(TSym(TAbstractRecordDef(Def).SymTable.SymList[I])) then
              Continue;
            VS:=TFieldVarSym(TAbstractRecordDef(Def).SymTable.SymList[I]);
            CheckAlignment:=True;
            if not TAbstractRecordSymTable(TAbstractRecordDef(Def).SymTable).Is_Packed then
              begin
                NewByteOffset:=ByteOffset+VS.FieldOffset;
                Size:=VS.VarDef.Size;
              end
            else
              begin
                NewByteOffset:=ByteOffset+VS.FieldOffset div 8;
                if (VS.VarDef.Typ in [OrdDef,EnumDef]) then
                  begin
                    { calculate the number of bytes spanned by
                      this bitpacked field }
                    Size:=((VS.FieldOffset+VS.VarDef.PackedBitSize+7) div 8)-(VS.FieldOffset div 8);
                    { our bitpacked fields are interpreted as always being
                      aligned, because unlike in C we don't have char:1, int:1
                      etc (so everything is basically a char:x) }
                    CheckAlignment:=False;
                  end
                else
                  Size:=VS.VarDef.Size;
              end;
            { If [..] an object [..] contains unaligned fields, it has class
              MEMORY }
            if CheckAlignment and
               (Align(NewByteOffset,VS.VarDef.StructAlignment)<>NewByteOffset) then
              begin
                Result:=0;
                Exit;
              end;
            Num:=ClassifyAggregateElement(CallOption,VS.VarDef,Def,VarSpez,Size,Classes,NewByteOffset);
            if (Num=0) then
              Exit(0);
          end;

        Result:=FinalizeAggregateClassification(CallOption,Def,Words,Classes);

        { There is still one case where it might not have to be passed on the
          stack, and that's a homogeneous vector aggregate (HVA) or a
          homogeneous float aggregate (HFA) under vectorcall. }
        if (CallOption = pocall_vectorcall) then
          begin
            if (Result = 0) then
              Result := TryBuildHomogeneousAggregate(Def,Words,Classes)
            else
              { If we're dealing with an HFA that has 3 or 4 Singles, pairs of
                Singles may be merged into a single SSE_CLASS, which must be
                split into separate SSESF_CLASS references for vectorcall; this
                is only performed in "try_build_homogeneous_aggregate" and not
                elsewhere, so accommodate for this exceptional case. [Kit] }
              if (Result = 2) then
                begin
                  Num := TryBuildHomogeneousAggregate(Def,Words,Classes);
                  if Num <> 0 then
                    { If it's equal to zero, just pass 2 and handle the record
                      type normally }
                    Result := Num;
                end;
          end;
      end;


    function ClassifyNormalArray(CallOption: TProcCallOption; Def: TArrayDef; ParentDef: TDef; VarSpez: TVarSpez; var Classes: TX64ParaClasses; ByteOffset: AInt): LongInt;
      var
        I, EleCount: AWord;
        Size,
        EleSize,
        NewByteOffset,
        BitOffset: AInt;
        Words,
        Num: LongInt;
        IsBitPacked: Boolean;
      begin
        Size:=0;
        BitOffset:=0;
        Result:=InitAggregateClassification(CallOption,Def,ParentDef,VarSpez,ByteOffset,Words,Classes);

        if (Words=0) then
          Exit;

        IsBitPacked:=Is_Packed_Array(Def);
        if not IsBitPacked then
          begin
            EleSize:=Def.EleSize;
            Size:=EleSize;
          end
        else
          begin
            EleSize:=Def.ElePackedBitSize;
            BitOffset:=0;
          end;

        (* Merge the elements of the array.  *)
        I:=0;
        EleCount:=Def.EleCount;
        repeat
          if not IsBitPacked then
            begin
              { size does not change }
              NewByteOffset:=ByteOffset+I*EleSize;
              { If [..] an object [..] contains unaligned fields, it has class
                MEMORY }
              if Align(NewByteOffset,Def.Alignment)<>NewByteOffset then
                begin
                  Result:=0;
                  Exit;
                end;
            end
          else
            begin
              { calculate the number of bytes spanned by this bitpacked
                element }
              Size:=((BitOffset+EleSize+7) div 8)-(BitOffset div 8);
              NewByteOffset:=ByteOffset+(EleSize*I) div 8;
              { bit offset of next element }
              Inc(BitOffset,EleSize);
            end;
          Num:=ClassifyAggregateElement(CallOption,Def.ElementDef,Def,VarSpez,Size,Classes,NewByteOffset);
          if (Num=0) then
            Exit(0);
          Inc(I);
        until (I=EleCount);

        Result:=FinalizeAggregateClassification(CallOption,Def,Words,Classes);
      end;


    function ClassifyArgument(CallOption: TProcCallOption; Def: TDef; ParentDef: TDef; VarSpez: TVarSpez; RealSize: AInt; var Classes: TX64ParaClasses; ByteOffset: AInt; RoundTo8: Boolean): LongInt;
      var
        RoundedOffset: AInt;
      begin
        if RoundTo8 then
	  RoundedOffset := ByteOffset mod 8
        else
          RoundedOffset := ByteOffset;

        case Def.Typ of
          OrdDef,
          EnumDef,
          PointerDef,
          ClassRefDef:
            Result:=ClassifyAsIntegerArgument(Def,RealSize,Classes,RoundedOffset);
          FormalDef:
            Result:=ClassifyAsIntegerArgument(VoidPointerType,VoidPointerType.Size,Classes,RoundedOffset);
          FloatDef:
            begin
              Classes[0].Def:=Def;
              case TFloatDef(Def).FloatType of
                S32Real:
                  begin
                    if (ByteOffset mod 8) = 0 then { Check regardless of the round_to_8 flag }
                      begin
                        if Assigned(ParentDef) and ((ParentDef.AggregateAlignment mod 16) = 0) and ((ByteOffset mod ParentDef.AggregateAlignment) <> 0) then
                          { Third element of an aligned vector }
                          Classes[0].Typ:=X64SSEUpClass
                        else
                          Classes[0].Typ:=X64SSESFClass
                      end
                    else
                      begin
                        if Assigned(ParentDef) and ((ParentDef.AggregateAlignment mod 16) = 0) then
                          { Fourth element of an aligned vector }
                          Classes[0].Typ:=X64SSEUpClass
                        else
                          { if we have e.g. a record with two successive "single"
                            fields, we need a 64 bit rather than a 32 bit load }
                          Classes[0].Typ:=X64SSEClass;

                        Classes[0].Def:=CArrayDef.GetReusable_No_Free(S32FloatType,2);
                      end;
                    Result:=1;
                  end;
                S64Real:
                  begin
                    if Assigned(ParentDef) and ((ParentDef.AggregateAlignment mod 16) = 0) and ((ByteOffset mod ParentDef.AggregateAlignment) <> 0) then
                      { Aligned vector of type double }
                      Classes[0].Typ:=X64SSEUpClass
                    else
                      Classes[0].Typ:=X64SSEDFClass;
                    Result:=1;
                  end;
                S80Real,
                SC80Real:
                  begin
                    Classes[0].Typ:=X64X87Class;
                    Classes[1].Typ:=X64X87UpClass;
                    Classes[1].Def:=Def;
                    Result:=2;
                  end;
                S64Comp,
                S64Currency:
                  begin
                    Classes[0].Typ:=X64IntegerClass;
                    Result:=1;
                  end;
              end;
            end;
          RecordDef:
            Result:=ClassifyRecord(CallOption,Def,ParentDef,VarSpez,Classes,RoundedOffset);
          ObjectDef:
            begin
              if Is_Object(Def) then
                { pass by reference, like ppc and i386 }
                Result:=0
              else
                { all kinds of pointer types: class, objcclass, interface, ... }
                Result:=ClassifyAsIntegerArgument(Def,VoidPointerType.Size,Classes,RoundedOffset);
            end;
          SetDef:
            begin
              if Is_SmallSet(Def) then
                Result:=ClassifyAsIntegerArgument(Def,Def.Size,Classes,RoundedOffset)
              else
                Result:=0;
            end;
          StringDef:
            begin
              if (TStringDef(Def).StringType in [st_shortstring,st_longstring]) then
                Result:=0
              else
                Result:=ClassifyAsIntegerArgument(Def,Def.Size,Classes,RoundedOffset);
            end;
          ArrayDef:
            begin
              { a dynamic array is treated like a pointer }
              if Is_Dynamic_Array(Def) then
                Result:=ClassifyAsIntegerArgument(Def,VoidPointerType.Size,Classes,RoundedOffset)
              { other special arrays are passed on the stack }
              else if Is_Open_Array(Def) or
                      Is_Array_Of_Const(Def) then
                Result:=0
              else
              { normal array }
                Result:=ClassifyNormalArray(CallOption,TArrayDef(Def),ParentDef,VarSpez,Classes,RoundedOffset);
            end;
          { the file record is definitely too big }
          FileDef:
            Result:=0;
          ProcVarDef:
            begin
              if (po_methodpointer in TProcVarDef(Def).ProcOptions) then
                begin
                  { treat as TMethod record }
                  Def:=Search_System_Type('TMETHOD').TypeDef;
                  Result:=ClassifyArgument(CallOption,Def,ParentDef,VarSpez,Def.Size,Classes,RoundedOffset, False);
                end
              else
                { pointer }
                Result:=ClassifyAsIntegerArgument(Def,Def.Size,Classes,RoundedOffset);
            end;
          VariantDef:
            begin
              { same as tvardata record }
              Def:=Search_System_Type('TVARDATA').TypeDef;
              Result:=ClassifyArgument(CallOption,Def,ParentDef,VarSpez,Def.Size,Classes,RoundedOffset, False);
            end;
          UndefinedDef:
            { show shall we know?
              since classify_argument is called during parsing, see tw27685.pas,
              we handle undefineddef here }
            Result:=0;
          ErrorDef:
            { error message should have been thrown already before, so avoid only
              an internal error }
            Result:=0;
          else
            InternalError(2010021405);
        end;
      end;


    { Returns the size of a single element in the aggregate, or the entire vector, if it is one of these types, 0 otherwise }
    function IsSIMDVectorTypeOrHomogeneousAggregate(CallOption: TProcCallOption; Def: TDef; VarSpez: TVarSpez): AInt;
      var
        NumClasses,I,VecSize,VecCount,MaxVecSize:LongInt;
        Classes: TX64ParaClasses;
        FirstClass: TX64ParaClassType;
      begin
        for I := Low(Classes) to High(Classes) do
          begin
            Classes[I].Typ := X64NoClass;
            Classes[I].Def := nil;
          end;

        NumClasses:=ClassifyArgument(CallOption,Def,nil,vs_value,Def.Size,Classes,0,False);
        if NumClasses = 0 then
          Exit(0);

        FirstClass := Classes[0].Typ;
        case FirstClass of
          X64SSESFClass: { Only valid if the aggregate contains a lone Single }
            begin
              if (NumClasses = 1) and (CallOption = pocall_vectorcall) then
                Result := 4
              else
                Result := 0;
              Exit;
            end;
          X64SSEDFClass:
            begin
              if (NumClasses > 1) and (CallOption <> pocall_vectorcall) then
                Result := 0
              else
                begin
                  for I := 1 to NumClasses - 1 do
                    if Classes[I].Typ <> X64SSEDFClass then
                    begin
                      Result := 0;
                      Exit;
                    end;

                  if (Def.Size div 8) <> NumClasses then
                    { Wrong alignment or compound size }
                    Result := 0
                  else
                    Result := 8;
                end;
            end;
          X64SSEClass:
            begin
              MaxVecSize := NumClasses * 2;

              if NumClasses = 1 then
                begin
                  { 2 Singles }
                  if CallOption = pocall_vectorcall then
                    Result := 4
                  else
                    Result := 0;

                  Exit;
                end;

              if Classes[1].Typ = X64SSESFClass then
                begin
                  { 3 Singles }
                  if NumClasses <> 2 then
                    Result := 0
                  else
                    Result := 4;

                  Exit;
                end;

              VecSize := 2;
              VecCount := 1;
              for I := 1 to NumClasses - 1 do
                case Classes[I].Typ of
                  X64SSEUpClass:
                    Inc(VecSize, 2);
                  X64SSEClass:
                    begin
                      if (MaxVecSize < NumClasses * 2) and (VecSize <> MaxVecSize) then
                        { Different vector sizes }
                        Exit(0);

                      MaxVecSize := VecSize;
                      VecSize := 2;
                      Inc(VecCount);
                    end;
                  else
                    Exit(0);
                end;

              if VecSize <> MaxVecSize then
                { Last vector has to be the same size }
                Exit(0);

              { Either an HFA with 4 Singles, or an HVA with up to 4 vectors
                (or a lone SIMD vector if veccount = 1) }
              if (VecCount < 4) then
                begin
                  if (VecCount > 1) and (CallOption <> pocall_vectorcall) then
                    Result := 0
                  else
                    if VecSize = 2 then
                      { Packed, unaligned array of Singles }
                      Result := 4
                    else
                      Result := VecSize * 8
                end
              else
                Result := 0;
            end;
          else
            Exit(0);
        end;
      end;


    procedure GetValueParaLoc(CallOption: TProcCallOption;VarSpez:TVarSpez;Def:TDef;var Classes: TX64ParaClasses);
      var
        Size: AInt;
        I: LongInt;
        NumClasses: LongInt;
      begin
        { init the classes array, because even if classify_argument inits only
          one element we copy both to loc1/loc2 in case "1" is returned }
        for I:=Low(Classes) to High(Classes) do
          begin
            Classes[I].Typ:=X64NoClass;
            Classes[I].Def:=nil;
          end;

        { def.size internalerrors for open arrays and dynamic arrays, since
          their size cannot be determined at compile-time.
          classify_argument does not look at the realsize argument for arrays
          cases, but we obviously do have to pass something... }
        if Is_Special_Array(Def) then
          Size:=-1
        else
          Size:=Def.Size;
        NumClasses:=ClassifyArgument(CallOption,Def,nil,VarSpez,Size,Classes,0,False);
        case NumClasses of
          0:
           begin
             Classes[0].Typ:=X64MemoryClass;
             Classes[0].Def:=Def;
           end;
          1..4:
            begin
              { If the class is X87, X87UP or COMPLEX_X87, it is passed in memory }
              for I := 0 to NumClasses - 1 do
                begin
                  if Classes[I].Typ in [X64X87Class,X64X87UpClass,X64ComplexX87Class] then
                    Classes[I].Typ:=X64MemoryClass;
                end;
            end;
          else
            { 8 can happen for _m512 vectors, but are not yet supported }
            InternalError(2010021501);
        end;
      end;


    function TCPUParaManager.Ret_In_Param(Def:TDef;PD:TAbstractProcDef):Boolean;
      var
        Classes: TX64ParaClasses;
        NumClasses: LongInt;
      begin
        if Handle_Common_Ret_In_Param(Def,PD,Result) then
          Exit;
        FillChar(Classes,SizeOf(Classes),0);
        case Def.Typ of
          { for records it depends on their contents and size }
          RecordDef,
          { make sure we handle 'procedure of object' correctly }
          ProcVarDef:
            begin
              NumClasses:=ClassifyArgument(PD.ProcCallOption,Def,nil,vs_value,Def.Size,Classes,0,False);
              Result:=(NumClasses=0);
            end;
          else
            Result:=inherited Ret_In_Param(Def,PD);
        end;
      end;


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


    { true if a parameter is too large to copy and only the address is pushed }
    function TCPUParaManager.Push_Addr_Param(VarSpez:TVarSpez;Def : TDef;CallOption : TProcCallOption) : Boolean;
      var
        Classes: TX64ParaClasses;
        NumClasses: LongInt;
      begin
        FillChar(Classes,SizeOf(Classes),0);
        Result:=False;
        { var,out,constref always require address }
        if VarSpez in [vs_var,vs_out,vs_constref] then
          begin
            Result:=True;
            Exit;
          end;
        { Only vs_const, vs_value here }
        case Def.Typ of
          FormalDef :
            Result:=True;
          RecordDef :
            begin
              { MetroWerks Pascal: const records always passed by reference
                (for Mac OS X interfaces) }
              if (CallOption=pocall_mwpascal) and
                 (VarSpez=vs_const) then
                Result:=True
              { Win ABI depends on size to pass it in a register or not }
              else if x86_64_use_ms_abi(CallOption) then
                begin
                  if CallOption = pocall_vectorcall then
                    begin
                      { "vectorcall" has the addition that it allows for aligned SSE types }
                      Result :=
                        not AggregateInRegistersWin64(VarSpez,Def.Size) and
                        (IsSIMDVectorTypeOrHomogeneousAggregate(pocall_vectorcall,Def,vs_value) = 0);
                    end
                  else
                    Result:=not AggregateInRegistersWin64(VarSpez,Def.Size)
                end
              { pass constant parameters that would be passed via memory by
                reference for non-cdecl/cppdecl, and make sure that the tmethod
                record (size=16) is passed the same way as a complex procvar }
              else if ((VarSpez=vs_const) and
                       not(CallOption in CDecl_PoCalls)) or
                      (Def.Size=16) then
                begin
                  NumClasses:=ClassifyArgument(CallOption,Def,nil,vs_value,Def.Size,Classes,0,False);
                  Result:=NumClasses=0;
                end
              else
              { SysV ABI always passes it as value parameter }
                Result:=False;
            end;
          ArrayDef :
            begin
              { cdecl array of const need to be ignored and therefor be pushed
                as value parameter with length 0 }
              if ((CallOption in CDecl_PoCalls) and
                  Is_Array_Of_Const(Def)) or
                 Is_Dynamic_Array(Def) then
                Result:=False
              else if (CallOption = pocall_vectorcall) then
                begin
                  { Pass all arrays by reference unless they are a valid, aligned SIMD type (arrays can't be homogeneous aggregates) }
                  Result := (IsSIMDVectorTypeOrHomogeneousAggregate(pocall_vectorcall,Def,vs_value) = 0);
                end
              else
                { pass all arrays by reference to be compatible with C (passing
                  an array by value (= copying it on the stack) does not exist,
                  because an array is the same as a pointer there }
                Result:=True
            end;
          ObjectDef :
            begin
              { don't treat objects like records, because we only know whether
                or not they'll have a VMT after the entire object is parsed
                -> if they are used as function result from one of their own
                methods, their size can still change after we've determined
                whether this function result should be returned by reference or
                by value }
              if Is_Object(Def) then
                Result:=True;
            end;
          VariantDef,
          StringDef,
          ProcVarDef,
          SetDef :
            begin
              NumClasses:=ClassifyArgument(CallOption,Def,nil,vs_value,Def.Size,Classes,0,False);
              Result:=NumClasses=0;
            end;
          else
            ;
        end;
      end;


    function TCPUParaManager.Get_Volatile_Registers_Int(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        if x86_64_use_ms_abi(CallOption) then
          Result:=[RS_RAX,RS_RCX,RS_RDX,RS_R8,RS_R9,RS_R10,RS_R11]
        else
          Result:=[RS_RAX,RS_RCX,RS_RDX,RS_RSI,RS_RDI,RS_R8,RS_R9,RS_R10,RS_R11];
      end;


    function TCPUParaManager.Get_Volatile_Registers_MM(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        if x86_64_use_ms_abi(CallOption) then
          Result:=[RS_XMM0..RS_XMM5]
        else
          Result:=[RS_XMM0..RS_XMM15];

        { Don't list registers that aren't available }
        if FPUX86_HAS_32MMREGS in fpu_capabilities[CurrentSettings.FPUType] then
          Result:=Result+[RS_XMM16..RS_XMM31];
      end;


    function TCPUParaManager.Get_Volatile_Registers_FPU(CallOption : TProcCallOption):TCPURegisterSet;
      begin
        Result:=[RS_ST0..RS_ST7];
      end;


    function TCPUParaManager.Get_Saved_Registers_Int(CallOption : TProcCallOption):TCPURegisterArray;
      const
        Win64SavedStdRegs : TCPURegisterArray = (RS_RBX,RS_RDI,RS_RSI,RS_R12,RS_R13,RS_R14,RS_R15,RS_RBP);
        OthersSavedStdRegs : TCPURegisterArray = (RS_RBX,RS_R12,RS_R13,RS_R14,RS_R15);
      begin
        if TCGX8664(CG).Use_MS_ABI then
          Result:=Win64SavedStdRegs
        else
          Result:=OthersSavedStdRegs;
      end;


    function TCPUParaManager.Get_Saved_Registers_MM(CallOption: TProcCallOption):TCPURegisterArray;
      const
        Win64SavedXMMRegs : TCPURegisterArray = (RS_XMM6,RS_XMM7,
          RS_XMM8,RS_XMM9,RS_XMM10,RS_XMM11,RS_XMM12,RS_XMM13,RS_XMM14,RS_XMM15);
      begin
        if TCGX8664(CG).Use_MS_ABI then
          Result:=Win64SavedXMMRegs
        else
          SetLength(Result,0);
      end;


    function TCPUParaManager.Get_FuncRetLoc(P : TAbstractProcDef; Side: TCallerCallee; ForceTempDef: TDef): TCGPara;
      const
        IntRetRegs: array[0..1] of TRegister = (NR_FUNCTION_RETURN_REG,NR_FUNCTION_RETURN_REG_HIGH);
        MMRetRegs: array[0..1] of TRegister = (NR_MM_RESULT_REG,NR_MM_RESULT_REG_HIGH);
        MMRetRegsVectorCall: array[0..3] of TRegister = (NR_XMM0,NR_XMM1,NR_XMM2,NR_XMM3);

      var
        Classes: TX64ParaClasses;
        I,J,
        NumClasses: LongInt;
        IntRetRegIdx,
        MMRetRegIdx: LongInt;
        RetCGSize : TCgSize;
        ParaLoc : PCGParaLocation;
      begin
        if Set_Common_FuncRetLoc_Info(P,ForceTempDef,RetCGSize,Result) then
          Exit;

        { Return in FPU register? -> don't use classify_argument(), because
          currency and comp need special treatment here (they are integer class
          when passing as parameter, but LOC_FPUREGISTER as function result) }
        if Result.Def.Typ=FloatDef then
          begin
            ParaLoc:=Result.Add_Location;
            ParaLoc^.Def:=Result.Def;
            case TFloatDef(Result.Def).FloatType of
              S32Real:
                begin
                  ParaLoc^.Loc:=LOC_MMREGISTER;
                  ParaLoc^.Register:=NewReg(R_MMREGISTER,RS_MM_RESULT_REG,R_SUBMMS);
                  ParaLoc^.Size:=OS_F32;
                end;
              S64Real:
                begin
                  ParaLoc^.Loc:=LOC_MMREGISTER;
                  ParaLoc^.Register:=NewReg(R_MMREGISTER,RS_MM_RESULT_REG,R_SUBMMD);
                  ParaLoc^.Size:=OS_F64;
                end;
              { the first two only exist on targets with an x87, on others
                they are replace by int64 }
              S64Currency,
              S64Comp,
              S80Real,
              SC80Real:
                begin
                  ParaLoc^.Loc:=LOC_FPUREGISTER;
                  ParaLoc^.Register:=NR_FPU_RESULT_REG;
                  ParaLoc^.Size:=RetCGSize;
                end;
            end;
          end
        else
         { Return in register }
          begin
            FillChar(Classes,SizeOf(Classes),0);
            NumClasses:=ClassifyArgument(P.ProcCallOption,Result.Def,nil,vs_value,Result.Def.Size,Classes,0,False);
            { this would mean a memory return }
            if (NumClasses=0) then
              begin
                { we got an error before, so we just skip all the return type generation }
                if Result.Def.Typ=ErrorDef then
                  Exit;
                InternalError(2010021502);
              end;

            if (NumClasses > MaxParaClasses) then
              InternalError(2010021503);

            IntRetRegIdx:=0;
            MMRetRegIdx:=0;
            I := 0;
            { We can't use a for-loop here because the treatment of the SSEUP class requires skipping over i's }
            while I < NumClasses do
              begin
                ParaLoc:=Result.Add_Location;
                ParaLoc^.Def:=Classes[I].Def;
                case Classes[I].Typ of
                  X64IntegerSIClass,
                  X64IntegerClass:
                    begin
                      ParaLoc^.Loc:=LOC_REGISTER;
                      ParaLoc^.Register:=IntRetRegs[IntRetRegIdx];
                      if Classes[I].Typ=X64IntegerClass then
                        begin
                          ParaLoc^.Size:=OS_64;
                          if ParaLoc^.Def.Size<>8 then
                            ParaLoc^.Def:=U64IntType;
                        end
                      else if Result.IntSize in [1,2,4] then
                        begin
                          { The ABI does not require sign/zero-extended function
                            results, but older versions of clang did so and
                            on Darwin current versions of clang keep doing so
                            for backward compatibility. On other platforms, it
                            doesn't and hence we don't either }
                          if (I=0) and
                             not(TargetInfo.System in systems_darwin) and
                             (Result.IntSize in [1,2]) then
                            begin
                              ParaLoc^.Size:=Int_CGSize(Result.IntSize);
                              ParaLoc^.Def:=CGSize_OrdDef(ParaLoc^.Size);
                            end
                          else
                            ParaLoc^.Size:=Def_CGSize(ParaLoc^.Def);
                        end
                      else
                        begin
                          ParaLoc^.Size:=OS_32;
                          if ParaLoc^.Def.Size<>4 then
                            ParaLoc^.Def:=U32IntType;
                        end;
                      SetSubReg(ParaLoc^.Register,CGSize2SubReg(R_INTREGISTER,ParaLoc^.Size));
                      Inc(IntRetRegIdx);
                    end;
                  X64SSEClass,
                  X64SSEUpClass,
                  X64SSESFClass,
                  X64SSEDFClass:
                    begin
                      ParaLoc^.Loc:=LOC_MMREGISTER;

                      if P.ProcCallOption = pocall_vectorcall then
                        ParaLoc^.Register:=MMRetRegsVectorCall[MMRetRegIdx]
                      else
                        ParaLoc^.Register:=MMRetRegs[MMRetRegIdx];

                      case Classes[I].Typ of
                        X64SSESFClass:
                          begin
                            SetSubReg(ParaLoc^.Register,R_SUBMMS);
                            ParaLoc^.Size:=OS_F32;
                          end;
                        X64SSEDFClass:
                          begin
                            SetSubReg(ParaLoc^.Register,R_SUBMMD);
                            ParaLoc^.Size:=OS_F64;
                          end;
                        X64SSEClass:
                          begin
                            J := 1;
                            if not (x86_64_use_ms_abi(P.ProcCallOption) and (P.ProcCallOption <> pocall_vectorcall)) then
                              while I + J <= NumClasses do
                                begin
                                  if Classes[I+J].Typ <> X64SSEUpClass then
                                    Break;

                                  Inc(J);
                                end;

                            { j  = MM word count }
                            Inc(I, J - 1);
                            case J of
                              1:
                                begin
                                  SetSubReg(ParaLoc^.Register,R_SUBQ);
                                  ParaLoc^.Size:=OS_M64;
                                end;
                              2:
                                begin
                                  SetSubReg(ParaLoc^.Register,R_SUBMMX);
                                  ParaLoc^.Size:=OS_M128;
                                end;
                              4:
                                begin
                                  SetSubReg(ParaLoc^.Register,R_SUBMMY);
                                  ParaLoc^.Size:=OS_M256; { Currently unsupported }
                                end;
                              8:
                                begin
                                  SetSubReg(ParaLoc^.Register,R_SUBMMZ);
                                  ParaLoc^.Size:=OS_M512; { Currently unsupported }
                                end;
                              else
                                InternalError(2018012901);
                            end;
                            ParaLoc^.Def:=CArrayDef.GetReusable_No_Free_Vector(ParaLoc^.Def,J);
                          end;
                        else
                          if (x86_64_use_ms_abi(P.ProcCallOption) and (P.ProcCallOption <> pocall_vectorcall)) then
                            begin
                              SetSubReg(ParaLoc^.Register,R_SUBQ);
                              ParaLoc^.Size:=OS_M64;
                            end
                          else
                            { Should not get here }
                            InternalError(2018012900);
                      end;
                      Inc(MMRetRegIdx);
                    end;
                  X64X87Class:
                    begin
                      { must be followed by X86_64_X87UP_CLASS and that must be
                        the last class }
                      if (I<>(NumClasses-2)) or
                         (Classes[I+1].Typ<>X64X87UpClass) then
                        InternalError(2014110401);
                      ParaLoc^.Loc:=LOC_FPUREGISTER;
                      ParaLoc^.Register:=NR_FPU_RESULT_REG;
                      ParaLoc^.Size:=OS_F80;
                      Break;
                    end;
                  X64NoClass:
                    begin
                      { empty record/array }
                      if (I<>0) or
                         (NumClasses<>1) then
                        InternalError(2010060302);
                      ParaLoc^.Loc:=LOC_VOID;
                      ParaLoc^.Def:=VoidType;
                    end;
                  else
                    InternalError(2010021504);
                end;
                Inc(I);
              end;
          end;
      end;


    procedure TCPUParaManager.CreateParaLocInfoIntern(P : TAbstractProcDef; Side: TCallerCallee;Paras:TParaList;
                                                            var IntParaReg,MMParaReg,ParaSize:LongInt;VarArgsParas: Boolean);
      var
        HP         : TParaVarSym;
        FDef,
        ParaDef,
        ParaLocDef : TDef;
        ParaLoc    : PCGParaLocation;
        SubReg     : TSubRegister;
        PushAddr   : Boolean;
        ParaCGSize : TCgSize;
        { loc[2] onwards are only used for _m256 under vectorcall/SysV, and
          homogeneous vector aggregates and homogeneous float aggregates under
          the vectorcall calling convention. [Kit] }
        Loc        : TX64ParaClasses;
        NeedIntLoc,
        NeedMMLoc,
        ParaLen,
        LocIdx,
        I,J,
        VarAlign,
        ProcParaAlign,
        ParaAlign  : LongInt;
        UseMSABI : Boolean;
      begin
        ProcParaAlign:=Get_Para_Align(P.ProcCallOption);
        UseMSABI:=x86_64_use_ms_abi(P.ProcCallOption);
        { Register parameters are assigned from left to right }
        for I:=0 to Paras.Count-1 do
          begin
            HP:=TParaVarSym(Paras[I]);
            ParaDef:=HP.VarDef;
            ParaLocDef:=HP.VarDef;


            { on vectorcall, if a record has only one field and that field is a
              single or double, it has to be handled like a single/double }
            if (P.ProcCallOption=pocall_vectorcall) and
               ((ParaDef.Typ=RecordDef) {or
               is_object(paradef)}) and
               TAbstractRecordSymTable(TAbstractRecordDef(ParaDef).SymTable).Has_Single_Field(FDef) and
               (FDef.Typ=FloatDef) and
               (TFloatDef(FDef).FloatType in [S32Real,S64Real]) then
              ParaLocDef:=FDef;

            PushAddr:=Push_Addr_Param(HP.VarSpez,ParaLocDef,P.ProcCallOption);
            if PushAddr then
              begin
                Loc[0].Typ:=X64IntegerClass;
                Loc[1].Typ:=X64NoClass;
                ParaCGSize:=OS_ADDR;
                ParaLen:=SizeOf(PInt);
                ParaDef:=CPointerDef.GetReusable_No_Free(ParaDef);
                ParaLocDef:=ParaDef;
                ParaAlign:=ProcParaAlign;
                Loc[0].Def:=ParaLocDef;
                Loc[1].Def:=nil;
                for J:=2 to High(Loc) do
                  begin
                    Loc[J].Typ:=X64NoClass;
                    Loc[J].Def:=nil;
                  end;
              end
            else
              begin
                GetValueParaLoc(P.ProcCallOption,HP.VarSpez,ParaLocDef,Loc);
                ParaLen:=Push_Size(HP.VarSpez,ParaLocDef,P.ProcCallOption);
                ParaAlign:=Max(ProcParaAlign,ParaDef.Alignment);
                if P.ProcCallOption = pocall_vectorcall then
                  begin
                    { TODO: Can this set of instructions be put into 'defutil' without it relying on the argument classification? [Kit] }

                    { The SIMD vector types have to be OS_M128 etc., not OS_128 etc.}
                    case IsSIMDVectorTypeOrHomogeneousAggregate(pocall_vectorcall,ParaLocDef,vs_value) of
                      0:
                        { Not a vector or valid aggregate }
                        ParaCGSize:=Def_CGSize(ParaLocDef);
                      4:
                        ParaCGSize:=OS_F32;
                      8:
                        ParaCGSize:=OS_F64;
                      16:
                        ParaCGSize:=OS_M128;
                      32:
                        ParaCGSize:=OS_M256;
                      64:
                        ParaCGSize:=OS_M512;
                      else
                        InternalError(2018012910);
                    end;
                  end
                else
                  ParaCGSize:=Def_CGSize(ParaLocDef);
              end;

            { cheat for now, we should copy the value to an mm reg as well (FK) }
            if VarArgsParas and
               UseMSABI and
               (ParaLocDef.Typ = FloatDef) and
               (ParaCGSize in [OS_F32,OS_F64]) then
              begin
                Loc[1].Typ:=X64NoClass;
                if ParaCGSize=OS_F64 then
                  begin
                    Loc[0].Typ:=X64IntegerClass;
                    ParaCGSize:=OS_64;
                    ParaLocDef:=U64IntType;
                  end
                else
                  begin
                    Loc[0].Typ:=X64IntegerSIClass;
                    ParaCGSize:=OS_32;
                    ParaLocDef:=U32IntType;
                  end;
                Loc[0].Def:=ParaLocDef;
              end;

            HP.ParaLoc[Side].Reset;
            HP.ParaLoc[Side].Size:=ParaCGSize;
            HP.ParaLoc[Side].IntSize:=ParaLen;
            HP.ParaLoc[Side].Alignment:=ParaAlign;
            HP.ParaLoc[Side].Def:=ParaDef;
            if ParaLen>0 then
              begin
                { Enough registers free? }
                NeedIntLoc:=0;
                NeedMMLoc:=0;
                for LocIdx:=Low(Loc) to High(Loc) do
                  case Loc[LocIdx].Typ of
                    X64IntegerClass,
                    X64IntegerSIClass:
                      Inc(NeedIntLoc);
                    { Note, do NOT include X86_64_SSEUP_CLASS because this links with
                      X86_64_SSE_CLASS and we only need one register, not two. [Kit] }
                    X64SSEClass,
                    X64SSESFClass,
                    X64SSEDFClass:
                      Inc(NeedMMLoc);
                    else
                      ;
                  end;
                { the "-1" is because we can also use the current register }
                if (UseMSABI and
                    ((IntParaReg+NeedIntLoc-1 > High(ParaIntSupRegsWinX64)) or
                     ((P.ProcCallOption = pocall_vectorcall) and (MMParaReg+NeedMMLoc-1 > High(ParaMMSupRegsVectorCall))) or
                     ((P.ProcCallOption <> pocall_vectorcall) and (MMParaReg+NeedMMLoc-1 > High(ParaMMSupRegsWinX64))))) or
                   (not UseMSABI and
                    ((IntParaReg+NeedIntLoc-1 > High(ParaIntSupRegs)) or
                     (MMParaReg+NeedMMLoc-1 > High(ParaMMSupRegs)))) then
                  begin
                    { If there are no registers available for any
                      eightbyte of an argument, the whole argument is
                      passed on the stack. }
                    Loc[Low(Loc)].Typ:=X64MemoryClass;
                    Loc[Low(Loc)].Def:=ParaLocDef;
                    for LocIdx:=Succ(Low(Loc)) to High(Loc) do
                      Loc[LocIdx].Typ:=X64NoClass;
                  end;

                LocIdx:=0;
                while (ParaLen>0) and
                      (LocIdx<=High(Loc)) and
                      (Loc[LocIdx].Typ<>X64NoClass) do
                  begin
                    { Allocate }
                    case Loc[LocIdx].Typ of
                      X64IntegerClass,
                      X64IntegerSIClass:
                        begin
                          ParaLoc:=HP.ParaLoc[Side].Add_Location;
                          ParaLoc^.Loc:=LOC_REGISTER;
                          ParaLoc^.Def:=Loc[LocIdx].Def;
                          if (ParaCGSize=OS_NO) or ((LocIdx<High(Loc)) and (Loc[LocIdx+1].Typ<>X64NoClass)) then
                            begin
                              if Loc[LocIdx].Typ=X64IntegerClass then
                                begin
                                  ParaLoc^.Size:=OS_INT;
                                  ParaLoc^.Def:=U64IntType;
                                  SubReg:=R_SUBWHOLE;
                                end
                              else
                                begin
                                  ParaLoc^.Size:=OS_32;
                                  ParaLoc^.Def:=U32IntType;
                                  SubReg:=R_SUBD;
                                end;
                            end
                          else
                            begin
                              { some compilers sign/zero-extend on the callerside,
                                others don't. To be compatible with both, FPC
                                extends on the callerside, and assumes no
                                extension has been performed on the calleeside.
                                This is less efficient, but the alternative is
                                occasional crashes when calling code generated
                                by certain other compilers, or being called from
                                code generated by other compilers.

                                Exception: Darwin, since everyone there needs to
                                be compatible with the system compiler clang
                                (which extends on the caller side).

                                Not for LLVM, since there the zero/signext
                                attributes by definition only apply to the
                                caller side }

                              if not(TargetInfo.System in systems_darwin) and
                                 (Side=CalleeSide) and
                                 (HP.ParaLoc[Side].IntSize in [1,2]) then
                                begin
                                  ParaLoc^.Def:=HP.ParaLoc[Side].Def
                                end;

                              ParaLoc^.Size:=Def_CGSize(ParaLoc^.Def);
                              { s64comp/s64currency is pushed in an int register }
                              if ParaLoc^.Size=OS_C64 then
                                begin
                                  ParaLoc^.Size:=OS_64;
                                  ParaLoc^.Def:=U64IntType;
                                end;
                              SubReg:=CGSize2SubReg(R_INTREGISTER,ParaLoc^.Size);
                            end;

                          { winx64 uses different registers }
                          if UseMSABI then
                            ParaLoc^.Register:=NewReg(R_INTREGISTER,ParaIntSupRegsWinX64[IntParaReg],SubReg)
                          else
                            ParaLoc^.Register:=NewReg(R_INTREGISTER,ParaIntSupRegs[IntParaReg],SubReg);

                          { matching mm register must be skipped }
                          if UseMSABI then
                            Inc(MMParaReg);

                          Inc(IntParaReg);
                          Dec(ParaLen,TCgSize2Size[ParaLoc^.Size]);
                        end;
                      X64SSEClass,
                      X64SSESFClass,
                      X64SSEDFClass:
                        begin
                          ParaLoc:=HP.ParaLoc[Side].Add_Location;
                          ParaLoc^.Loc:=LOC_MMREGISTER;
                          ParaLoc^.Def:=Loc[LocIdx].Def;

                          case Loc[LocIdx].Typ of
                            X64SSESFClass:
                              begin
                                SubReg:=R_SUBMMS;
                                ParaLoc^.Size:=OS_F32;
                              end;
                            X64SSEDFClass:
                              begin
                                SubReg:=R_SUBMMD;
                                ParaLoc^.Size:=OS_F64;
                              end;
                            X64SSEClass:
                              begin
                                SubReg:=R_SUBQ;
                                ParaLoc^.Size:=OS_M64;
                                J := 1;
                                if not (UseMSABI and (P.ProcCallOption <> pocall_vectorcall)) then
                                  while LocIdx + J <= High(Loc) do
                                    begin
                                      if Loc[LocIdx+J].Typ <> X64SSEUpClass then
                                        Break;

                                      Inc(J);
                                    end;

                                { j = MM word count }
                                Inc(LocIdx, J - 1);
                                case J of
                                  1:
                                    begin
                                      SubReg:=R_SUBQ;
                                      ParaLoc^.Size:=OS_M64;
                                    end;
                                  2:
                                    begin
                                      SubReg:=R_SUBMMX;
                                      ParaLoc^.Size:=OS_M128;
                                    end;
                                  4:
                                    begin
                                      SubReg:=R_SUBMMY;
                                      ParaLoc^.Size:=OS_M256; { Currently unsupported }
                                    end;
                                  8:
                                    begin
                                      SubReg:=R_SUBMMZ;
                                      ParaLoc^.Size:=OS_M512; { Currently unsupported }
                                    end;
                                  else
                                    InternalError(2018012903);
                                end;
                                ParaLoc^.Def:=CArrayDef.GetReusable_No_Free_Vector(ParaLoc^.Def,J);
                              end;
                            else
                              if (UseMSABI and (P.ProcCallOption <> pocall_vectorcall)) then
                                begin
                                  SubReg:=R_SUBQ;
                                  ParaLoc^.Size:=OS_M64;
                                end
                              else
                                { Should not get here }
                                InternalError(2018012902);
                          end;

                          { winx64 uses different registers }
                          if UseMSABI then
                            begin
                              if P.ProcCallOption = pocall_vectorcall then
                                ParaLoc^.Register:=NewReg(R_MMREGISTER,ParaMMSupRegsVectorCall[MMParaReg],SubReg)
                              else
                                ParaLoc^.Register:=NewReg(R_MMREGISTER,ParaMMSupRegsWinX64[MMParaReg],SubReg);
                            end
                          else
                            ParaLoc^.Register:=NewReg(R_MMREGISTER,ParaMMSupRegs[MMParaReg],SubReg);

                          { matching int register must be skipped }
                          if UseMSABI then
                            Inc(IntParaReg);

                          Inc(MMParaReg);
                          Dec(ParaLen,TCgSize2Size[ParaLoc^.Size]);
                        end;
                      X64MemoryClass :
                        begin
                          ParaLoc:=HP.ParaLoc[Side].Add_Location;
                          ParaLoc^.Loc:=LOC_REFERENCE;
                          ParaLoc^.Def:=Loc[LocIdx].Def;

                          { s64comp/s64currency are passed as integer types
                            (important for LLVM here) }
                          if ParaCGSize=OS_C64 then
                            begin
                              ParaLoc^.Size:=OS_64;
                              ParaLoc^.Def:=U64IntType;
                            end;

                          {Hack alert!!! We should modify int_cgsize to handle OS_128,
                           however, since int_cgsize is called in many places in the
                           compiler where only a few can already handle OS_128, fixing it
                           properly is out of the question to release 2.2.0 in time. (DM)}
                          if ParaCGSize=OS_128 then
                            if ParaLen=8 then
                              ParaLoc^.Size:=OS_64
                            else if ParaLen=16 then
                              ParaLoc^.Size:=OS_128
                            else
                              InternalError(200707143)
                          else if ParaCGSize in [OS_F32,OS_F64,OS_F80,OS_F128] then
                            ParaLoc^.Size:=Int_Float_CGSize(ParaLen)
                          else
                            ParaLoc^.Size:=Int_CGSize(ParaLen);
                          if Side=CallerSide then
                            ParaLoc^.Reference.Index:=NR_STACK_POINTER_REG
                          else
                            ParaLoc^.Reference.Index:=NR_FRAME_POINTER_REG;
                          VarAlign:=Used_Align(Size_2_Align(ParaLen),ParaAlign,ParaAlign);
                          ParaLoc^.Reference.Offset:=Align(ParaSize,VarAlign);
                          ParaSize:=Align(ParaSize+ParaLen,VarAlign);
                          ParaLen:=0;
                        end;
                      else
                        InternalError(2010053113);
                    end;
                    Inc(LocIdx);
                  end;
              end
            else
              begin
                ParaLoc:=HP.ParaLoc[Side].Add_Location;
                ParaLoc^.Loc:=LOC_VOID;
                ParaLoc^.Def:=ParaLocDef;
              end;
          end;
        { Register parameters are assigned from left-to-right, but the
          offsets on the stack are right-to-left. There is no need
          to reverse the offset, only adapt the calleeside with the
          start offset of the first param on the stack }
        if Side=CalleeSide then
          begin
            for I:=0 to Paras.Count-1 do
              begin
                HP:=TParaVarSym(Paras[I]);
                ParaLoc:=HP.ParaLoc[Side].Location;
                while ParaLoc<>nil do
                  begin
                    with ParaLoc^ do
                     if (Loc=LOC_REFERENCE) then
                       Inc(Reference.Offset,TargetInfo.first_parm_offset);
                    ParaLoc:=ParaLoc^.Next;
                  end;
              end;
          end;
      end;


    function TCPUParaManager.Create_VarArgs_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee; VarArgsPara:TVarArgsParaList):LongInt;
      var
        IntParaReg,MMParaReg,
        ParaSize : LongInt;
      begin
        IntParaReg:=0;
        MMParaReg:=0;
        if x86_64_use_ms_abi(P.ProcCallOption) then
          ParaSize:=4*8
        else
          ParaSize:=0;
        { calculate the registers for the normal parameters }
        CreateParaLocInfoIntern(P,Side,P.Paras,IntParaReg,MMParaReg,ParaSize,False);
        { append the varargs }
        if Assigned(VarArgsPara) then
          begin
            if Side=CallerSide then
              CreateParaLocInfoIntern(P,Side,VarArgsPara,IntParaReg,MMParaReg,ParaSize,True)
            else
              InternalError(2019021917);
            { store used no. of SSE registers, that needs to be passed in %AL }
            VarArgsPara.MMRegsUsed:=MMParaReg;
          end;
        Create_FuncRetLoc_Info(P,Side);
        Result:=ParaSize;
      end;


    function TCPUParaManager.Create_ParaLoc_Info(P : TAbstractProcDef; Side: TCallerCallee):LongInt;
      var
        IntParaReg,MMParaReg,
        ParaSize : LongInt;
      begin
        IntParaReg:=0;
        MMParaReg:=0;
        if x86_64_use_ms_abi(P.ProcCallOption) then
          ParaSize:=4*8
        else
          ParaSize:=0;
        CreateParaLocInfoIntern(P,Side,P.Paras,IntParaReg,MMParaReg,ParaSize,False);
        { Create Function result paraloc }
        Create_FuncRetLoc_Info(P,Side);
        { We need to return the size allocated on the stack }
        Result:=ParaSize;
      end;


begin
   ParaManager:=TCPUParaManager.Create;
end.
