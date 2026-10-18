{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Generate assembler for nodes that handle type conversions which are
    the same for all (most) processors

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
unit ncgcnv;

{$i fpcdefs.inc}

interface

    uses
       node,ncnv,defutil,defcmp;

    type

       { tcgtypeconvnode }

       TCGTypeConvNode = class(TTypeConvNode)
       private
         function NeedsIndirect:Boolean;
       protected
{$ifdef cpuflags}
         { CPUs without flags need a specific implementation of int -> bool }
         procedure Second_Int_To_Bool;override;
{$endif cpuflags}
         procedure Second_Int_To_Int;override;
         procedure Second_CString_To_PChar;override;
         procedure Second_CString_To_Int;override;
         procedure Second_String_To_CharArray;override;
         procedure Second_Array_To_Pointer;override;
         procedure Second_Pointer_To_Array;override;
         procedure Second_Char_To_String;override;
         procedure Second_Real_To_Real;override;
         procedure Second_COrd_To_Pointer;override;
         procedure Second_Proc_To_ProcVar;override;
         procedure Second_Nil_To_MethodProcVar;override;
         procedure Second_Bool_To_Int;override;
         procedure Second_Bool_To_Bool;override;
         procedure Second_AnsiString_To_PChar;override;
         procedure Second_Class_To_Intf;override;
         procedure Second_Char_To_Char;override;
         procedure Second_Elem_To_OpenArray;override;
         procedure Second_Nothing;override;
       public
         procedure Pass_Generate_Code;override;
       end;

       TCGAsNode = class(TAsNode)
         procedure Pass_Generate_Code;override;
       end;

  implementation

    uses
      CUtils,Verbose,GlobType,Globals,
      aasmbase,AAsmData,symconst,symdef,SymTable,
      nutils,ncon,
      cpubase,Systems,
      pass_2,
      cgbase,
      cgutils,cgobj,hlcgobj,
      FModule,
      tgobj
      ;


    function TCGTypeConvNode.NeedsIndirect:Boolean;
      begin
        Result:=(tf_supports_packages in TargetInfo.Flags) and
                  (TargetInfo.system in systems_indirect_var_imports) and
                  (
                    not Assigned(CurrentModule) or
                    (CurrentModule.GlobalSymTable<>SystemUnit)
                  );
      end;


    procedure TCGTypeConvNode.Second_Int_To_Int;
      var
        lOriginalSize,
        lNewSize : TCgSize;
        lResultSize,
        lLeftSize : LongInt;
      begin
        lNewSize:=Def_CGSize(ResultDef);

        { insert range check if not explicit or internally generated conversion }
        if (Flags*[nf_explicit,nf_internal])=[] then
          hlcg.G_RangeCheck(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef);

        { is the result size smaller? when typecasting from void
          we always reuse the current location, because there is
          nothing that we can load in a register }
        lResultSize := ResultDef.Size;
        lLeftSize := Left.ResultDef.Size;
        if ((lResultSize<>lLeftSize) or
            Is_BitPacked_Access(Left)) and
           not Is_Void(Left.ResultDef) then
          begin
            Location_Copy(Location,Left.Location);
            { reuse a loc_reference when the newsize is smaller than
              than the original, else load it to a register }
            if (Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               (lResultSize<lLeftSize) then
              begin
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),CPointerDef.getreusable(ResultDef),Location.Reference);
                Location.Size:=lNewSize;
              end
{$if not defined(cpuhighleveltarget)}
            { On targets without 8/16 bit register components, 8/16-bit operations
              always adjust high bits of result, see 'maybeadjustresult' method in
              respective cgcpu.pas. Therefore 8/16-bit locations are valid as larger
              ones (except signed->unsigned, which still needs high bits cleared). }
            else if (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
               (TCgSize2Size[(reg_cgsize(Left.Location.Register))]=sizeof(aint)) and
               (lResultSize>lLeftSize) and
               (lNewSize in [OS_32,OS_S32,OS_16,OS_S16]) and
               (not Is_Signed(Left.ResultDef) or Is_Signed(ResultDef)) then
              Location.Size:=lNewSize
{$endif}
            else
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,ResultDef,false);
          end
        else
          begin
            { no special loading is required, reuse current location }

            { that's not true, if you go from signed to unsigned or  }
            { vice versa, you need sign extension/removal if the     }
            { value is already in a register (at least for archs     }
            { which don't have 8bit register components etc) (JM)    }
            Location_Copy(Location,Left.Location);
            Location.Size:=lNewSize;
            lOriginalSize := Def_CGSize(Left.ResultDef);
            if (lResultSize < sizeof(aint)) and
               (Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
               (lOriginalSize <> lNewSize) then
              begin
                Location.Register := cg.GetIntRegister(CurrentAsmData.CurrAsmList,lNewSize);
                Location.Loc := LOC_REGISTER;
                hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
              end
            else if Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),CPointerDef.getreusable(ResultDef),Location.Reference)
{$ifdef cpuhighleveltarget}
            { high level targets require the types to be correct in all cases }
            else if Left.ResultDef<>ResultDef then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,ResultDef,false);
{$endif cpuhighleveltarget}
          end;
      end;


{$ifdef cpuflags}
    procedure TCGTypeConvNode.Second_Int_To_Bool;
      var
        lRegister : TRegister;
        lReference      : TReference;
        lResFlags  : TResFlags;
        lLabel    : TAsmLabel;
        lNewSize   : TCgSize;
      begin
        SecondPass(Left);
        if CodeGenError then
         exit;

        { Explicit typecasts from any ordinal type to a boolean type }
        { must not change the ordinal value                          }
        if (nf_explicit in Flags) and
           not(Left.Location.Loc in [LOC_FLAGS,LOC_JUMP]) then
          begin
             { overriding methods must be able to know in advance whether this
               code path will be taken by checking expectloc, so they can call
               the inherited method in that case }
             if Left.ExpectLoc in [LOC_FLAGS,LOC_JUMP] then
               InternalError(2014122901);
             Location_Copy(Location,Left.Location);
             lNewSize:=Def_CGSize(ResultDef);
             { change of size? change sign only if location is LOC_(C)REGISTER? Then we have to sign/zero-extend }
             if (TCgSize2Size[lNewSize]<>TCgSize2Size[Left.Location.Size]) or
                ((lNewSize<>Left.Location.Size) and (Location.Loc in [LOC_REGISTER,LOC_CREGISTER])) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,ResultDef,true)
             else
               Location.Size:=lNewSize;
             exit;
          end;
        { Load left node into flag F_NE/F_E }
        lResFlags:=F_NE;
        case Left.Location.Loc of
          LOC_CREFERENCE,
          LOC_REFERENCE :
            begin
              if Left.Location.Size in [OS_64,OS_S64] then
               begin
                 lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                 cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Left.Location.Reference,lRegister);
                 lReference:=Left.Location.Reference;
                 inc(lReference.Offset,4);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,lReference,lRegister);
               end
              else
               begin
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,Left.Location.Size,Left.Location.Register,Left.Location.Register);
               end;
            end;
          LOC_FLAGS :
            begin
              lResFlags:=Left.Location.ResFlags;
            end;
          LOC_REGISTER,LOC_CREGISTER :
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if Left.Location.Size in [OS_64,OS_S64] then
               begin
                 lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                 cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Left.Location.Register64.RegLo,lRegister);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,Left.Location.Register64.RegHi,lRegister);
               end
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
               begin
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,Left.Location.Size,Left.Location.Register,Left.Location.Register);
               end;
            end;
          LOC_JUMP :
            begin
              lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              CurrentAsmData.getjumplabel(lLabel);
              cg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.TrueLabel);
              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,1,lRegister);
              cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel);
              cg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.FalseLabel);
              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,0,lRegister);
              cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_INT,lRegister,lRegister);
            end;
          else
            InternalError(200311301);
        end;
        { load flags to register }
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
        cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Location.Size,lResFlags,Location.Register);
        cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
        if (Is_CBool(ResultDef)) then
          cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,Location.Size,Location.Register,Location.Register);
      end;
{$endif cpuflags}


    procedure TCGTypeConvNode.Second_CString_To_PChar;

      var
        lReference : TReference;

      begin
         if Left.NodeType<>stringconstn then
           InternalError(200601131);
         if not Is_PChar(ResultDef) and not Is_PWideChar(ResultDef) then
           InternalError(2014032802);
         Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
         case TStringConstNode(Left).ConstStringType of
           cst_conststring :
             begin
               Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
             end;
           cst_shortstring :
             begin
               inc(Left.Location.Reference.Offset);
               Location.Reference.Alignment:=1;
               Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
               hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
             end;
           cst_widestring,
           cst_unicodestring,
           cst_ansistring :
             begin
               if TStringConstNode(Left).len=0 then
                begin
                  { FPC_EMPTYCHAR is a widechar -> 2 bytes }
                  Reference_Reset(lReference,2,[]);
                  lReference.Symbol:=CurrentAsmData.RefAsmSymbol('FPC_EMPTYCHAR',AT_DATA,NeedsIndirect);
                  CurrentModule.Add_Extern_AsmSym('FPC_EMPTYCHAR',AB_EXTERNAL,AT_DATA);
                  Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                  hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,CWideCharType,ResultDef,lReference,Location.Register);
                end
               else
                begin
                  Location_Copy(Location,Left.Location);
                end;
             end;
           cst_longstring:
             begin
               {!!!!!!!}
               InternalError(8888);
             end;
         end;
      end;


    procedure TCGTypeConvNode.Second_CString_To_Int;
      begin
        { this can't happen because constants are already processed in
          pass 1 }
        InternalError(200510013);
      end;


    procedure TCGTypeConvNode.Second_String_To_CharArray;
      begin
        if Is_CharArray(Left.ResultDef) then
          begin
            Location_Copy(Location,Left.Location);
            exit;
          end;
        { should be handled already in resultdef pass (JM) }
        InternalError(200108292);
      end;


    procedure TCGTypeConvNode.Second_Array_To_Pointer;

      begin
         Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
         Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
      end;


    procedure TCGTypeConvNode.Second_Pointer_To_Array;

      begin
        { assume natural alignment, volatility of pointer has no effect on the volatility
          of the data it points to }
        Location_Reset_Ref(Location,LOC_REFERENCE,OS_NO,ResultDef.Alignment,[]);
        case Left.Location.Loc of
          LOC_CREGISTER,
          LOC_REGISTER :
            begin
            {$ifdef cpu_uses_separate_address_registers}
              if GetRegType(Left.Location.Register)<>R_ADDRESSREGISTER then
                begin
                  Location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                  cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,
                          Left.Location.Register,Location.Reference.Base);
                end
              else
            {$endif}
                hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,Left.Location.Register,0,CTempPosInvalid,Location.Reference.Alignment,Location.Reference.Volatility);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE,
          { tricky type casting of parameters can cause these locations, see tb0593 (case in tb_records_objfpc_run_01.pas).pas on x86_64-linux }
          LOC_SUBSETREG,
          LOC_CSUBSETREG,
          LOC_SUBSETREF,
          LOC_CSUBSETREF:
            begin
              hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,
                hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Left.ResultDef),0,CTempPosInvalid,Location.Reference.Alignment,[]);
              hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location,
                Location.Reference.Base);
              if Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
                Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
            end;
          LOC_CONSTANT:
            begin
              Location.Reference.Offset:=Left.Location.Value;
            end
          else
            InternalError(2002032216);
        end;
      end;


    procedure TCGTypeConvNode.Second_Char_To_String;
      var
        lTempReference: TReference;
      begin
         Location_Reset_Ref(Location,LOC_REFERENCE,OS_NO,2,[]);
         case TStringDef(ResultDef).StringType of
           st_shortstring :
             begin
               TG.GetHLTemp(CurrentAsmData.CurrAsmList,ResultDef,ResultDef.Size,tt_normal,Location.Reference);
               lTempReference:=Location.Reference;
               hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,
                 CPointerDef.getreusable(ResultDef),
                 CPointerDef.getreusable(Left.ResultDef),lTempReference);
               hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location,
                 lTempReference);
               Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
             end;
           { the rest is removed in the resultdef pass and converted to compilerprocs }
           else
            InternalError(4179);
        end;
      end;


    procedure TCGTypeConvNode.Second_Real_To_Real;
{$ifdef x86}
      var
        lTempReference: TReference;
{$endif x86}
      begin
         Location_Reset(Location,ExpectLoc,Def_CGSize(ResultDef));
{$ifdef x86}
         { extended types in memory which should be loaded into the sse unit
           must be converted by the fpu first, so force them to be loaded into
           the fpu }
         if (ExpectLoc=LOC_MMREGISTER) and
            (Left.Location.Size in [OS_F80,OS_C64]) then
           begin
             if (Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
               hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
             { round them down to the proper precision }
             TG.GetHLTemp(CurrentAsmData.currasmlist,ResultDef,ResultDef.Size,tt_normal,lTempReference);
             hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,lTempReference);
             Location_Reset_Ref(Left.Location,LOC_REFERENCE,Location.Size,lTempReference.Alignment,lTempReference.Volatility);
             Left.Location.Reference:=lTempReference;
             Left.ResultDef:=ResultDef;
           end;
{$endif x86}
         { ARM VFP values are in integer registers when they are function results }
         if (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
           hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
         case Left.Location.Loc of
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              begin
                case ExpectLoc of
                  LOC_FPUREGISTER:
                    begin
                      { on sparc a move from double -> single means from two to one register. }
                      { On all other platforms it also needs rounding to avoid that           }
                      { single(double_regvar) = double_regvar is true in all cases            }
                      Location.Register:=hlcg.GetFPURegister(CurrentAsmData.CurrAsmList,ResultDef);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
                    end;
                  LOC_MMREGISTER:
                    begin
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
                      Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register,MMS_MoveScalar);
                    end
                  else
                    InternalError(2003012262);
                end;
                exit
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 if ExpectLoc=LOC_MMREGISTER then
                   begin
                     Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
                     hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location,Location.Register,MMS_MoveScalar)
                   end
                  else
                    begin
                      hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
                      Location.Register:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,Location.Size);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
                    end;
                 Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
              end;
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              begin
                case ExpectLoc of
                  LOC_FPUREGISTER:
                    begin
                      hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
                      Location.Register:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,Location.Size);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
                    end;
                  LOC_MMREGISTER:
                    begin
                      Location.Register:=hlcg.GetMMRegister(CurrentAsmData.CurrAsmList,ResultDef);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register,MMS_MoveScalar);
                    end;
                  else
                    InternalError(2003012261);
                end;
              end;
            else
              InternalError(2002032215);
         end;
      end;


    procedure TCGTypeConvNode.Second_COrd_To_Pointer;
      begin
        { this can't happen because constants are already processed in
          pass 1 }
        InternalError(47423985);
      end;


    procedure TCGTypeConvNode.Second_Proc_To_ProcVar;
      var
        lReference: TReference;
        lTempRegister: TRegister;
        lProcVarRecType: TRecordDef;
        lProcVarSelfName: TIDString;
      begin
        if TAbstractProcDef(ResultDef).Is_AddressOnly then
          begin
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
            { only a code pointer? (when taking the address of classtype.method
              we also only get a code pointer even though the resultdef is a
              procedure of object, and hence is_addressonly would return false)
             }
	    if Left.Location.Size = Def_CGSize(TAbstractProcDef(Left.ResultDef).Address_Type) then
              begin
                case Left.Location.Loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      { the procedure symbol is encoded in reference.symbol -> take address }
                      Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                      hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
                    end;
                  else
                    InternalError(2013031501)
                end;
              end
            else
              begin
                { conversion from a procedure of object/nested procvar to plain procvar }
                case Left.Location.Loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                      { code field is the first one }
                      hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(CProcVarDef.GetReusableProcAddr(TProcDef(Left.ResultDef),pc_normal)),CPointerDef.getreusable(ResultDef),Left.Location.Reference);
                      hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Left.Location.Reference,Location.Register);
                    end;
                  LOC_REGISTER,LOC_CREGISTER:
                    begin
                      Location.Register:=Left.Location.Register;
                    end;
                  else
                    InternalError(2013031502)
                end;
              end;
          end
        else
          begin
            if not TAbstractProcDef(Left.ResultDef).Is_AddressOnly then
              Location_Copy(Location,Left.Location)
            else
              begin
                { assigning a global function to a nested procvar -> create
                  tmethodpointer record and set the "frame pointer" to nil }
                if not(Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  InternalError(2013031503);
                Location_Reset_Ref(Location,LOC_REFERENCE,Int_CGSize(ResultDef.Size),sizeof(PInt),[]);
                TG.GetHLTemp(CurrentAsmData.CurrAsmList,ResultDef,ResultDef.Size,tt_normal,Location.Reference);
                lReference:=Location.Reference;
                if Is_Nested_PD(TAbstractProcDef(ResultDef)) then
                  begin
                    lProcVarRecType:=TRecordDef(NestedProcPointerType);
                    lProcVarSelfName:='parentfp';
                  end
                else
                  begin
                    lProcVarRecType:=TRecordDef(MethodPointerType);
                    lProcVarSelfName:='self';
                  end;
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(ResultDef),CPointerDef.getreusable(lProcVarRecType),lReference);
                lTempRegister:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidCodePointerType);
                hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,TProcDef(Left.ResultDef),VoidCodePointerType,Left.Location.Reference,lTempRegister);
                hlcg.G_Load_Reg_Field_By_Name(CurrentAsmData.CurrAsmList,VoidCodePointerType,TRecordDef(lProcVarRecType),lTempRegister,'proc',lReference);
                { setting the frame pointer to nil is not strictly necessary
                  since the global procedure won't use it, but it can help with
                  debugging }
                hlcg.G_Load_Const_Field_By_Name(CurrentAsmData.CurrAsmList,TRecordDef(lProcVarRecType),0,lProcVarSelfName,lReference);
              end;
          end;
      end;

    procedure TCGTypeConvNode.Second_Nil_To_MethodProcVar;
    begin
      Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
      Location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.currasmlist,VoidPointerType);
      hlcg.A_Load_Const_Reg(CurrentAsmData.currasmlist,VoidPointerType,0,Location.RegisterHi);
      Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.currasmlist,VoidCodePointerType);
      hlcg.A_Load_Const_Reg(CurrentAsmData.currasmlist,VoidCodePointerType,0,Location.Register);
    end;

    procedure TCGTypeConvNode.Second_Bool_To_Int;
      var
         lNewSize: TCgSize;
      begin
         SecondPass(Left);
         Location_Copy(Location,Left.Location);
         lNewSize:=Def_CGSize(ResultDef);
         { byte(bytebool) or word(wordbool) or longint(longbool) must be }
         { accepted for var parameters and assignments, and must not     }
         { change the ordinal value or value location.                   }
         { htypechk.valid_for_assign ensures that such locations with a  }
         { size<sizeof(register) cannot be LOC_CREGISTER (they otherwise }
         { could be in case of a plain assignment), and LOC_REGISTER can }
         { never be an assignment target. The remaining LOC_REGISTER/    }
         { LOC_CREGISTER locations do have to be sign/zero-extended.     }
         if not(nf_explicit in Flags) or
            (Location.Loc in [LOC_FLAGS,LOC_JUMP]) or
            { change of size/signedness? Then we have to sign/ }
            { zero-extend in case of a loc_(c)register         }
            ((lNewSize<>Left.Location.Size) and
             ((Left.ResultDef.Size<>ResultDef.Size) or
              not(Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]))) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,ResultDef,true)
         else
           { may differ in sign, e.g. bytebool -> byte   }
           Location.Size:=lNewSize;
      end;


    procedure TCGTypeConvNode.Second_Bool_To_Bool;
      begin
        { we can reuse the conversion already available
          in bool_to_int to resize the value. But when the
          size of the new boolean is smaller we need to calculate
          the value as is done in int_to_bool. This is needed because
          the bits that define the true status can be outside the limits
          of the new size and truncating the register can result in a 0
          value }
        if (Left.ExpectLoc in [LOC_FLAGS,LOC_JUMP]) and
           { a cbool must be converted to -1/0 }
           not Is_CBool(ResultDef) then
          begin
            SecondPass(Left);
            if (Left.Location.Loc <> Left.ExpectLoc) then
              InternalError(2010081601);
            Location_Copy(Location,Left.Location);
          end
        else if (ResultDef.Size=Left.ResultDef.Size) and
           (Is_CBool(ResultDef)=Is_CBool(Left.ResultDef)) then
          Second_Bool_To_Int
        else
          begin
            if (ResultDef.Size<>Left.ResultDef.Size) then
              { remove nf_explicit to perform full conversion if boolean sizes are different }
              exclude(Flags, nf_explicit);
            Second_Int_To_Bool;
          end;
      end;


    procedure TCGTypeConvNode.Second_AnsiString_To_PChar;
      var
         lLabel : TAsmLabel;
         lReference : TReference;
      begin
         Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
         CurrentAsmData.getjumplabel(lLabel);
         Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
         hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,
           Left.Location,Location.Register);
         hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ResultDef,OC_NE,0,Location.Register,lLabel);
         { FPC_EMPTYCHAR is a widechar -> 2 bytes }
         Reference_Reset(lReference,2,[]);
         lReference.Symbol:=CurrentAsmData.RefAsmSymbol('FPC_EMPTYCHAR',AT_DATA,NeedsIndirect);
         CurrentModule.Add_Extern_AsmSym('FPC_EMPTYCHAR',AB_EXTERNAL,AT_DATA);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,CWideCharType,ResultDef,lReference,Location.Register);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
      end;


    procedure TCGTypeConvNode.Second_Class_To_Intf;
      var
         lLabel : TAsmLabel;
         lObjectDef : TObjectDef;
         lImplementedInterface : TImplementedInterface;
      begin
         lLabel:=nil;
         Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
         case Left.Location.Loc of
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
                 Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
              end;
            LOC_CREGISTER:
              begin
                 Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                 hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Register,Location.Register);
              end;
            LOC_REGISTER:
              begin
                Location.Register:=Left.Location.Register;
                hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Location.Register);
              end;
            LOC_CONSTANT:
              begin
                 Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
                 hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,ResultDef,Left.Location.Value,Location.Register);
              end
            else
              InternalError(121120001);
         end;
         lObjectDef:=TObjectDef(Left.ResultDef);
         while Assigned(lObjectDef) do
           begin
             lImplementedInterface:=Find_Implemented_Interface(lObjectDef,TObjectDef(ResultDef));
             if Assigned(lImplementedInterface) then
               begin
                 case lImplementedInterface.IType of
                   etStandard:
                     begin
                       CurrentAsmData.getjumplabel(lLabel);
                       hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ResultDef,OC_EQ,0,Location.Register,lLabel);
                       hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,ResultDef,lImplementedInterface.ioffset,Location.Register);
                       break;
                     end;
                   else
                     InternalError(200802163);
                 end;
               end;
             lObjectDef:=lObjectDef.ChildOf;
           end;
         if lObjectDef=nil then
           InternalError(2002081301);
         if lLabel=nil then
           InternalError(2013120101);
         cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
      end;


    procedure TCGTypeConvNode.Second_Char_To_Char;
      begin
        InternalError(2007081202);
      end;

    procedure TCGTypeConvNode.Second_Elem_To_OpenArray;
      begin
        { nothing special to do by default }
        Second_Nothing;
      end;


    procedure TCGTypeConvNode.Second_Nothing;
      var
        lNewSize : TCgSize;
      begin
        { we reuse the old value }
        Location_Copy(Location,Left.Location);

        { Floats should never be returned as LOC_CONSTANT, do the
          moving to memory before the new size is set.

          Also when converting from a float to a non-float
          move to memory first to prevent
          invalid LOC_(C)MM/FPUREGISTER locations }
        if (
            (ResultDef.typ=floatdef) and
            (Location.Loc=LOC_CONSTANT)
           ) or
           ((ResultDef.typ=floatdef) xor (Location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER,LOC_CMMREGISTER,LOC_MMREGISTER])) then
          begin
            { check if the CPU supports direct moves between int and fpu registers and take advantage of it }
{$ifdef cpufloatintregmov}
            if (ResultDef.typ<>floatdef) and (Location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) then
              begin
                Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
                Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                cg.A_LoadFPU_Reg_IntReg(CurrentAsmData.CurrAsmList,Left.Location.Size,Location.Size,Left.Location.Register,Location.Register);
              end
            else
{$endif cpufloatintregmov}
{$ifdef cpumm}
            if (ResultDef.typ<>floatdef) and (Location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER]) and (ResultDef.Size<=sizeof(AInt)) then
              begin
                Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
                Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                cg.A_LoadMM_Reg_IntReg(CurrentAsmData.CurrAsmList,Left.Location.Size,Location.Size,Left.Location.Register,Location.Register, nil);
              end
            else
{$endif cpumm}
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Location,Left.ResultDef);
{$ifdef cpumm}
          end
        else if (ResultDef.typ=floatdef) and (Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          begin
            { Take advantage of direct moves from int to MM if supported }
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            cg.A_LoadMM_IntReg_Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Location.Size,Left.Location.Register,Location.Register, nil);
{$endif cpumm}
          end;
        { but use the new size, but we don't know the size of all arrays }
        lNewSize:=Def_CGSize(ResultDef);
        Location.Size:=lNewSize;
      end;


{$ifdef TESTOBJEXT2}
    procedure TCGTypeConvNode.checkobject;
      begin
        { no checking by default }
      end;
{$endif TESTOBJEXT2}


    procedure TCGTypeConvNode.Pass_Generate_Code;
      begin
        { the boolean routines can be called with LOC_JUMP and
          call secondpass themselves in the helper }
        if not(ConvType in [tc_bool_2_int,tc_bool_2_bool,tc_int_2_bool]) then
         begin
           SecondPass(Left);
           if CodeGenError then
            exit;
         end;

        Second_Call_Helper(ConvType);

{$ifdef TESTOBJEXT2}
         { Check explicit conversions to objects pointers !! }
         if p^.explizit and
            (p^.ResultDef.typ=pointerdef) and
            (TPointerDef(p^.ResultDef).definition.typ=objectdef) and not
            (TObjectDef(TPointerDef(p^.ResultDef).definition).isclass) and
            ((TObjectDef(TPointerDef(p^.ResultDef).definition).options and oo_hasvmt)<>0) and
            (cs_check_range in CurrentSettings.LocalSwitches) then
           checkobject;
{$endif TESTOBJEXT2}
      end;


    procedure TCGAsNode.Pass_Generate_Code;
      begin
        SecondPass(Call);
        Location_Copy(Location,Call.Location);
      end;


begin
  CTypeConvNode := TCGTypeConvNode;
  CAsNode := TCGAsNode;
end.
