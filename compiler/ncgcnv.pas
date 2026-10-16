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
         function needs_indirect:boolean;
       protected
{$ifdef cpuflags}
         { CPUs without flags need a specific implementation of int -> bool }
         procedure second_int_to_bool;override;
{$endif cpuflags}
         procedure second_int_to_int;override;
         procedure second_cstring_to_pchar;override;
         procedure second_cstring_to_int;override;
         procedure second_string_to_chararray;override;
         procedure second_array_to_pointer;override;
         procedure second_pointer_to_array;override;
         procedure second_char_to_string;override;
         procedure second_real_to_real;override;
         procedure second_cord_to_pointer;override;
         procedure second_proc_to_procvar;override;
         procedure second_nil_to_methodprocvar;override;
         procedure second_bool_to_int;override;
         procedure second_bool_to_bool;override;
         procedure second_ansistring_to_pchar;override;
         procedure second_class_to_intf;override;
         procedure second_char_to_char;override;
         procedure second_elem_to_openarray;override;
         procedure second_nothing;override;
       public
         procedure pass_generate_code;override;
       end;

       TCGAsNode = class(TAsNode)
         procedure pass_generate_code;override;
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


    function TCGTypeConvNode.needs_indirect:boolean;
      begin
        result:=(tf_supports_packages in TargetInfo.flags) and
                  (TargetInfo.system in systems_indirect_var_imports) and
                  (
                    not Assigned(CurrentModule) or
                    (CurrentModule.GlobalSymTable<>SystemUnit)
                  );
      end;


    procedure TCGTypeConvNode.second_int_to_int;
      var
        orgsize,
        newsize : TCgSize;
        ressize,
        leftsize : LongInt;
      begin
        newsize:=Def_CGSize(resultdef);

        { insert range check if not explicit or internally generated conversion }
        if (flags*[nf_explicit,nf_internal])=[] then
          hlcg.G_RangeCheck(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef);

        { is the result size smaller? when typecasting from void
          we always reuse the current location, because there is
          nothing that we can load in a register }
        ressize := resultdef.Size;
        leftsize := left.resultdef.Size;
        if ((ressize<>leftsize) or
            is_bitpacked_access(left)) and
           not Is_Void(left.resultdef) then
          begin
            Location_Copy(location,left.Location);
            { reuse a loc_reference when the newsize is smaller than
              than the original, else load it to a register }
            if (location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
               (ressize<leftsize) then
              begin
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),CPointerDef.getreusable(resultdef),location.Reference);
                location.Size:=newsize;
                if (TargetInfo.endian = ENDIAN_BIG) then
                  begin
                    inc(location.Reference.Offset,leftsize-ressize);
                    location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,leftsize-ressize);
                  end;
              end
{$if not defined(cpuhighleveltarget)}
            { On targets without 8/16 bit register components, 8/16-bit operations
              always adjust high bits of result, see 'maybeadjustresult' method in
              respective cgcpu.pas. Therefore 8/16-bit locations are valid as larger
              ones (except signed->unsigned, which still needs high bits cleared). }
            else if (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
               (TCgSize2Size[(reg_cgsize(left.Location.Register))]=sizeof(aint)) and
               (ressize>leftsize) and
               (newsize in [OS_32,OS_S32,OS_16,OS_S16]) and
               (not Is_Signed(left.resultdef) or Is_Signed(resultdef)) then
              location.Size:=newsize
{$endif}
            else
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,resultdef,false);
          end
        else
          begin
            { no special loading is required, reuse current location }

            { that's not true, if you go from signed to unsigned or  }
            { vice versa, you need sign extension/removal if the     }
            { value is already in a register (at least for archs     }
            { which don't have 8bit register components etc) (JM)    }
            Location_Copy(location,left.Location);
            location.Size:=newsize;
            orgsize := Def_CGSize(left.resultdef);
            if (ressize < sizeof(aint)) and
               (location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
               (orgsize <> newsize) then
              begin
                location.Register := cg.GetIntRegister(CurrentAsmData.CurrAsmList,newsize);
                location.Loc := LOC_REGISTER;
                hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
              end
            else if location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),CPointerDef.getreusable(resultdef),location.Reference)
{$ifdef cpuhighleveltarget}
            { high level targets require the types to be correct in all cases }
            else if left.resultdef<>resultdef then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,resultdef,false);
{$endif cpuhighleveltarget}
          end;
      end;


{$ifdef cpuflags}
    procedure TCGTypeConvNode.second_int_to_bool;
      var
        hregister : TRegister;
        href      : TReference;
        ResFlags  : TResFlags;
        hlabel    : TAsmLabel;
        newsize   : TCgSize;
      begin
        SecondPass(left);
        if CodeGenError then
         exit;

        { Explicit typecasts from any ordinal type to a boolean type }
        { must not change the ordinal value                          }
        if (nf_explicit in flags) and
           not(left.Location.Loc in [LOC_FLAGS,LOC_JUMP]) then
          begin
             { overriding methods must be able to know in advance whether this
               code path will be taken by checking expectloc, so they can call
               the inherited method in that case }
             if left.expectloc in [LOC_FLAGS,LOC_JUMP] then
               InternalError(2014122901);
             Location_Copy(location,left.Location);
             newsize:=Def_CGSize(resultdef);
             { change of size? change sign only if location is LOC_(C)REGISTER? Then we have to sign/zero-extend }
             if (TCgSize2Size[newsize]<>TCgSize2Size[left.Location.Size]) or
                ((newsize<>left.Location.Size) and (location.Loc in [LOC_REGISTER,LOC_CREGISTER])) then
               hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,resultdef,true)
             else
               location.Size:=newsize;
             exit;
          end;
        { Load left node into flag F_NE/F_E }
        ResFlags:=F_NE;
        case left.Location.Loc of
          LOC_CREFERENCE,
          LOC_REFERENCE :
            begin
              if left.Location.Size in [OS_64,OS_S64] then
               begin
                 hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                 cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,left.Location.Reference,hregister);
                 href:=left.Location.Reference;
                 inc(href.Offset,4);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,href,hregister);
               end
              else
               begin
                 hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,left.Location.Size,left.Location.Register,left.Location.Register);
               end;
            end;
          LOC_FLAGS :
            begin
              ResFlags:=left.Location.ResFlags;
            end;
          LOC_REGISTER,LOC_CREGISTER :
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if left.Location.Size in [OS_64,OS_S64] then
               begin
                 hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                 cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,left.Location.Register64.RegLo,hregister);
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,left.Location.Register64.RegHi,hregister);
               end
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
               begin
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,left.Location.Size,left.Location.Register,left.Location.Register);
               end;
            end;
          LOC_JUMP :
            begin
              hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              CurrentAsmData.getjumplabel(hlabel);
              cg.A_Label(CurrentAsmData.CurrAsmList,left.Location.TrueLabel);
              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,1,hregister);
              cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,hlabel);
              cg.A_Label(CurrentAsmData.CurrAsmList,left.Location.FalseLabel);
              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,0,hregister);
              cg.A_Label(CurrentAsmData.CurrAsmList,hlabel);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_INT,hregister,hregister);
            end;
          else
            InternalError(200311301);
        end;
        { load flags to register }
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
        cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,location.Size,ResFlags,location.Register);
        cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
        if (Is_CBool(resultdef)) then
          cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,location.Size,location.Register,location.Register);
      end;
{$endif cpuflags}


    procedure TCGTypeConvNode.second_cstring_to_pchar;

      var
        hr : TReference;

      begin
         if left.nodetype<>stringconstn then
           InternalError(200601131);
         if not Is_PChar(resultdef) and not Is_PWideChar(resultdef) then
           InternalError(2014032802);
         Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
         case TStringConstNode(left).cst_type of
           cst_conststring :
             begin
               location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
             end;
           cst_shortstring :
             begin
               inc(left.Location.Reference.Offset);
               location.Reference.Alignment:=1;
               location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
               hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
             end;
           cst_widestring,
           cst_unicodestring,
           cst_ansistring :
             begin
               if TStringConstNode(left).len=0 then
                begin
                  { FPC_EMPTYCHAR is a widechar -> 2 bytes }
                  Reference_Reset(hr,2,[]);
                  hr.Symbol:=CurrentAsmData.RefAsmSymbol('FPC_EMPTYCHAR',AT_DATA,needs_indirect);
                  CurrentModule.Add_Extern_AsmSym('FPC_EMPTYCHAR',AB_EXTERNAL,AT_DATA);
                  location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                  hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,CWideCharType,resultdef,hr,location.Register);
                end
               else
                begin
                  Location_Copy(location,left.Location);
                end;
             end;
           cst_longstring:
             begin
               {!!!!!!!}
               InternalError(8888);
             end;
         end;
      end;


    procedure TCGTypeConvNode.second_cstring_to_int;
      begin
        { this can't happen because constants are already processed in
          pass 1 }
        InternalError(200510013);
      end;


    procedure TCGTypeConvNode.second_string_to_chararray;
      begin
        if Is_CharArray(left.resultdef) then
          begin
            Location_Copy(location,left.Location);
            exit;
          end;
        { should be handled already in resultdef pass (JM) }
        InternalError(200108292);
      end;


    procedure TCGTypeConvNode.second_array_to_pointer;

      begin
         Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
         location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
      end;


    procedure TCGTypeConvNode.second_pointer_to_array;

      begin
        { assume natural alignment, volatility of pointer has no effect on the volatility
          of the data it points to }
        Location_Reset_Ref(location,LOC_REFERENCE,OS_NO,resultdef.Alignment,[]);
        case left.Location.Loc of
          LOC_CREGISTER,
          LOC_REGISTER :
            begin
            {$ifdef cpu_uses_separate_address_registers}
              if GetRegType(left.Location.Register)<>R_ADDRESSREGISTER then
                begin
                  location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                  cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,
                          left.Location.Register,location.Reference.Base);
                end
              else
            {$endif}
                hlcg.Reference_Reset_Base(location.Reference,left.resultdef,left.Location.Register,0,CTempPosInvalid,location.Reference.Alignment,location.Reference.Volatility);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE,
          { tricky type casting of parameters can cause these locations, see tb0593 (case in tb_records_objfpc_run_01.pas).pas on x86_64-linux }
          LOC_SUBSETREG,
          LOC_CSUBSETREG,
          LOC_SUBSETREF,
          LOC_CSUBSETREF:
            begin
              hlcg.Reference_Reset_Base(location.Reference,left.resultdef,
                hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,left.resultdef),0,CTempPosInvalid,location.Reference.Alignment,[]);
              hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location,
                location.Reference.Base);
              if left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
                location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
            end;
          LOC_CONSTANT:
            begin
              location.Reference.Offset:=left.Location.Value;
            end
          else
            InternalError(2002032216);
        end;
      end;


    procedure TCGTypeConvNode.second_char_to_string;
      var
        tmpref: TReference;
      begin
         Location_Reset_Ref(location,LOC_REFERENCE,OS_NO,2,[]);
         case TStringDef(resultdef).StringType of
           st_shortstring :
             begin
               tg.GetHLTemp(CurrentAsmData.CurrAsmList,resultdef,resultdef.Size,tt_normal,location.Reference);
               tmpref:=location.Reference;
               hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,
                 CPointerDef.getreusable(resultdef),
                 CPointerDef.getreusable(left.resultdef),tmpref);
               hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location,
                 tmpref);
               location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
             end;
           { the rest is removed in the resultdef pass and converted to compilerprocs }
           else
            InternalError(4179);
        end;
      end;


    procedure TCGTypeConvNode.second_real_to_real;
{$ifdef x86}
      var
        tr: TReference;
{$endif x86}
      begin
         Location_Reset(location,expectloc,Def_CGSize(resultdef));
{$ifdef x86}
         { extended types in memory which should be loaded into the sse unit
           must be converted by the fpu first, so force them to be loaded into
           the fpu }
         if (expectloc=LOC_MMREGISTER) and
            (left.Location.Size in [OS_F80,OS_C64]) then
           begin
             if (left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
               hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
             { round them down to the proper precision }
             tg.GetHLTemp(CurrentAsmData.currasmlist,resultdef,resultdef.Size,tt_normal,tr);
             hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,tr);
             Location_Reset_Ref(left.Location,LOC_REFERENCE,location.Size,tr.Alignment,tr.Volatility);
             left.Location.Reference:=tr;
             left.resultdef:=resultdef;
           end;
{$endif x86}
         { ARM VFP values are in integer registers when they are function results }
         if (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
           hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
         case left.Location.Loc of
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              begin
                case expectloc of
                  LOC_FPUREGISTER:
                    begin
                      { on sparc a move from double -> single means from two to one register. }
                      { On all other platforms it also needs rounding to avoid that           }
                      { single(double_regvar) = double_regvar is true in all cases            }
                      location.Register:=hlcg.GetFPURegister(CurrentAsmData.CurrAsmList,resultdef);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
                    end;
                  LOC_MMREGISTER:
                    begin
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
                      location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register,MMS_MoveScalar);
                    end
                  else
                    InternalError(2003012262);
                end;
                exit
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 if expectloc=LOC_MMREGISTER then
                   begin
                     location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
                     hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location,location.Register,MMS_MoveScalar)
                   end
                  else
                    begin
                      hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
                      location.Register:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,location.Size);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
                    end;
                 location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
              end;
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              begin
                case expectloc of
                  LOC_FPUREGISTER:
                    begin
                      hlcg.Location_Force_FPUReg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
                      location.Register:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,location.Size);
                      hlcg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
                    end;
                  LOC_MMREGISTER:
                    begin
                      location.Register:=hlcg.GetMMRegister(CurrentAsmData.CurrAsmList,resultdef);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register,MMS_MoveScalar);
                    end;
                  else
                    InternalError(2003012261);
                end;
              end;
            else
              InternalError(2002032215);
         end;
      end;


    procedure TCGTypeConvNode.second_cord_to_pointer;
      begin
        { this can't happen because constants are already processed in
          pass 1 }
        InternalError(47423985);
      end;


    procedure TCGTypeConvNode.second_proc_to_procvar;
      var
        href: TReference;
        tmpreg: TRegister;
        procvarrectype: TRecordDef;
        procvarselfname: TIDString;
      begin
        if TAbstractProcDef(resultdef).Is_AddressOnly then
          begin
            Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
            { only a code pointer? (when taking the address of classtype.method
              we also only get a code pointer even though the resultdef is a
              procedure of object, and hence is_addressonly would return false)
             }
	    if left.Location.Size = Def_CGSize(TAbstractProcDef(left.resultdef).Address_Type) then
              begin
                case left.Location.Loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      { the procedure symbol is encoded in reference.symbol -> take address }
                      location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                      hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
                    end;
                  else
                    InternalError(2013031501)
                end;
              end
            else
              begin
                { conversion from a procedure of object/nested procvar to plain procvar }
                case left.Location.Loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                      { code field is the first one }
                      hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(CProcVarDef.GetReusableProcAddr(TProcDef(left.resultdef),pc_normal)),CPointerDef.getreusable(resultdef),left.Location.Reference);
                      hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,resultdef,resultdef,left.Location.Reference,location.Register);
                    end;
                  LOC_REGISTER,LOC_CREGISTER:
                    begin
                      if TargetInfo.endian=endian_little then
                        location.Register:=left.Location.Register
                      else
                        location.Register:=left.Location.RegisterHi;
                    end;
                  else
                    InternalError(2013031502)
                end;
              end;
          end
        else
          begin
            if not TAbstractProcDef(left.resultdef).Is_AddressOnly then
              Location_Copy(location,left.Location)
            else
              begin
                { assigning a global function to a nested procvar -> create
                  tmethodpointer record and set the "frame pointer" to nil }
                if not(left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                  InternalError(2013031503);
                Location_Reset_Ref(location,LOC_REFERENCE,Int_CGSize(resultdef.Size),sizeof(PInt),[]);
                tg.GetHLTemp(CurrentAsmData.CurrAsmList,resultdef,resultdef.Size,tt_normal,location.Reference);
                href:=location.Reference;
                if Is_Nested_PD(TAbstractProcDef(resultdef)) then
                  begin
                    procvarrectype:=TRecordDef(NestedProcPointerType);
                    procvarselfname:='parentfp';
                  end
                else
                  begin
                    procvarrectype:=TRecordDef(MethodPointerType);
                    procvarselfname:='self';
                  end;
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(resultdef),CPointerDef.getreusable(procvarrectype),href);
                tmpreg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidCodePointerType);
                hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,TProcDef(left.resultdef),VoidCodePointerType,left.Location.Reference,tmpreg);
                hlcg.G_Load_Reg_Field_By_Name(CurrentAsmData.CurrAsmList,VoidCodePointerType,TRecordDef(procvarrectype),tmpreg,'proc',href);
                { setting the frame pointer to nil is not strictly necessary
                  since the global procedure won't use it, but it can help with
                  debugging }
                hlcg.G_Load_Const_Field_By_Name(CurrentAsmData.CurrAsmList,TRecordDef(procvarrectype),0,procvarselfname,href);
              end;
          end;
      end;

    procedure TCGTypeConvNode.second_nil_to_methodprocvar;
    begin
      Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
      location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.currasmlist,VoidPointerType);
      hlcg.A_Load_Const_Reg(CurrentAsmData.currasmlist,VoidPointerType,0,location.RegisterHi);
      location.Register:=hlcg.GetAddressRegister(CurrentAsmData.currasmlist,VoidCodePointerType);
      hlcg.A_Load_Const_Reg(CurrentAsmData.currasmlist,VoidCodePointerType,0,location.Register);
    end;

    procedure TCGTypeConvNode.second_bool_to_int;
      var
         newsize: TCgSize;
      begin
         SecondPass(left);
         Location_Copy(location,left.Location);
         newsize:=Def_CGSize(resultdef);
         { byte(bytebool) or word(wordbool) or longint(longbool) must be }
         { accepted for var parameters and assignments, and must not     }
         { change the ordinal value or value location.                   }
         { htypechk.valid_for_assign ensures that such locations with a  }
         { size<sizeof(register) cannot be LOC_CREGISTER (they otherwise }
         { could be in case of a plain assignment), and LOC_REGISTER can }
         { never be an assignment target. The remaining LOC_REGISTER/    }
         { LOC_CREGISTER locations do have to be sign/zero-extended.     }
         if not(nf_explicit in flags) or
            (location.Loc in [LOC_FLAGS,LOC_JUMP]) or
            { change of size/signedness? Then we have to sign/ }
            { zero-extend in case of a loc_(c)register         }
            ((newsize<>left.Location.Size) and
             ((left.resultdef.Size<>resultdef.Size) or
              not(location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]))) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,resultdef,true)
         else
           { may differ in sign, e.g. bytebool -> byte   }
           location.Size:=newsize;
      end;


    procedure TCGTypeConvNode.second_bool_to_bool;
      begin
        { we can reuse the conversion already available
          in bool_to_int to resize the value. But when the
          size of the new boolean is smaller we need to calculate
          the value as is done in int_to_bool. This is needed because
          the bits that define the true status can be outside the limits
          of the new size and truncating the register can result in a 0
          value }
        if (left.expectloc in [LOC_FLAGS,LOC_JUMP]) and
           { a cbool must be converted to -1/0 }
           not Is_CBool(resultdef) then
          begin
            SecondPass(left);
            if (left.Location.Loc <> left.expectloc) then
              InternalError(2010081601);
            Location_Copy(location,left.Location);
          end
        else if (resultdef.Size=left.resultdef.Size) and
           (Is_CBool(resultdef)=Is_CBool(left.resultdef)) then
          second_bool_to_int
        else
          begin
            if (resultdef.Size<>left.resultdef.Size) then
              { remove nf_explicit to perform full conversion if boolean sizes are different }
              exclude(flags, nf_explicit);
            second_int_to_bool;
          end;
      end;


    procedure TCGTypeConvNode.second_ansistring_to_pchar;
      var
         l1 : TAsmLabel;
         hr : TReference;
      begin
         Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
         CurrentAsmData.getjumplabel(l1);
         location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
         hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,
           left.Location,location.Register);
         hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,resultdef,OC_NE,0,location.Register,l1);
         { FPC_EMPTYCHAR is a widechar -> 2 bytes }
         Reference_Reset(hr,2,[]);
         hr.Symbol:=CurrentAsmData.RefAsmSymbol('FPC_EMPTYCHAR',AT_DATA,needs_indirect);
         CurrentModule.Add_Extern_AsmSym('FPC_EMPTYCHAR',AB_EXTERNAL,AT_DATA);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,CWideCharType,resultdef,hr,location.Register);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,l1);
      end;


    procedure TCGTypeConvNode.second_class_to_intf;
      var
         l1 : TAsmLabel;
         hd : TObjectDef;
         ImplIntf : TImplementedInterface;
      begin
         l1:=nil;
         Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
         case left.Location.Loc of
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
                 location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
              end;
            LOC_CREGISTER:
              begin
                 location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                 hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Register,location.Register);
              end;
            LOC_REGISTER:
              begin
                location.Register:=left.Location.Register;
                hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,location.Register);
              end;
            LOC_CONSTANT:
              begin
                 location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
                 hlcg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,resultdef,left.Location.Value,location.Register);
              end
            else
              InternalError(121120001);
         end;
         hd:=TObjectDef(left.resultdef);
         while Assigned(hd) do
           begin
             ImplIntf:=Find_Implemented_Interface(hd,TObjectDef(resultdef));
             if Assigned(ImplIntf) then
               begin
                 case ImplIntf.IType of
                   etStandard:
                     begin
                       CurrentAsmData.getjumplabel(l1);
                       hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,resultdef,OC_EQ,0,location.Register,l1);
                       hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,resultdef,ImplIntf.ioffset,location.Register);
                       break;
                     end;
                   else
                     InternalError(200802163);
                 end;
               end;
             hd:=hd.ChildOf;
           end;
         if hd=nil then
           InternalError(2002081301);
         if l1=nil then
           InternalError(2013120101);
         cg.A_Label(CurrentAsmData.CurrAsmList,l1);
      end;


    procedure TCGTypeConvNode.second_char_to_char;
      begin
        InternalError(2007081202);
      end;

    procedure TCGTypeConvNode.second_elem_to_openarray;
      begin
        { nothing special to do by default }
        second_nothing;
      end;


    procedure TCGTypeConvNode.second_nothing;
      var
        newsize : TCgSize;
      begin
        { we reuse the old value }
        Location_Copy(location,left.Location);

        { Floats should never be returned as LOC_CONSTANT, do the
          moving to memory before the new size is set.

          Also when converting from a float to a non-float
          move to memory first to prevent
          invalid LOC_(C)MM/FPUREGISTER locations }
        if (
            (resultdef.typ=floatdef) and
            (location.Loc=LOC_CONSTANT)
           ) or
           ((resultdef.typ=floatdef) xor (location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER,LOC_CMMREGISTER,LOC_MMREGISTER])) then
          begin
            { check if the CPU supports direct moves between int and fpu registers and take advantage of it }
{$ifdef cpufloatintregmov}
            if (resultdef.typ<>floatdef) and (location.Loc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) then
              begin
                Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
                location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                cg.A_LoadFPU_Reg_IntReg(CurrentAsmData.CurrAsmList,left.Location.Size,location.Size,left.Location.Register,location.Register);
              end
            else
{$endif cpufloatintregmov}
{$ifdef cpumm}
            if (resultdef.typ<>floatdef) and (location.Loc in [LOC_CMMREGISTER,LOC_MMREGISTER]) and (resultdef.Size<=sizeof(AInt)) then
              begin
                Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
                location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                cg.A_LoadMM_Reg_IntReg(CurrentAsmData.CurrAsmList,left.Location.Size,location.Size,left.Location.Register,location.Register, nil);
              end
            else
{$endif cpumm}
              hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,location,left.resultdef);
{$ifdef cpumm}
          end
        else if (resultdef.typ=floatdef) and (location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          begin
            { Take advantage of direct moves from int to MM if supported }
            Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            cg.A_LoadMM_IntReg_Reg(CurrentAsmData.CurrAsmList,left.Location.Size,location.Size,left.Location.Register,location.Register, nil);
{$endif cpumm}
          end;
        { but use the new size, but we don't know the size of all arrays }
        newsize:=Def_CGSize(resultdef);
        location.Size:=newsize;
      end;


{$ifdef TESTOBJEXT2}
    procedure TCGTypeConvNode.checkobject;
      begin
        { no checking by default }
      end;
{$endif TESTOBJEXT2}


    procedure TCGTypeConvNode.pass_generate_code;
      begin
        { the boolean routines can be called with LOC_JUMP and
          call secondpass themselves in the helper }
        if not(convtype in [tc_bool_2_int,tc_bool_2_bool,tc_int_2_bool]) then
         begin
           SecondPass(left);
           if CodeGenError then
            exit;
         end;

        second_call_helper(convtype);

{$ifdef TESTOBJEXT2}
         { Check explicit conversions to objects pointers !! }
         if p^.explizit and
            (p^.resultdef.typ=pointerdef) and
            (TPointerDef(p^.resultdef).definition.typ=objectdef) and not
            (TObjectDef(TPointerDef(p^.resultdef).definition).isclass) and
            ((TObjectDef(TPointerDef(p^.resultdef).definition).options and oo_hasvmt)<>0) and
            (cs_check_range in CurrentSettings.LocalSwitches) then
           checkobject;
{$endif TESTOBJEXT2}
      end;


    procedure TCGAsNode.pass_generate_code;
      begin
        SecondPass(call);
        Location_Copy(location,call.Location);
      end;


begin
  CTypeConvNode := TCGTypeConvNode;
  CAsNode := TCGAsNode;
end.
