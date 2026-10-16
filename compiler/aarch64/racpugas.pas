{
    Copyright (c) 1998-2002 by Carl Eric Codere and Peter Vreman
    Copyright (c) 2014 by Jonas Maebe

    Does the parsing for the AArch64 GNU AS styled inline assembler.

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
Unit racpugas;

{$i fpcdefs.inc}

  Interface

    uses
      raatt,racpu,
      aasmtai,
      cgbase,cpubase;

    type

      { taarch64attreader }

      TAArch64ATTReader = class(TATTReader)
        actoppostfix : TOpPostfix;
        actinsmmsubreg : TSubRegister;
        actsehdirective : TAsmSehDirective;
        function is_asmopcode(const s: string):boolean;override;
        function is_register(const s:string):boolean;override;
        function is_targetdirective(const s: string): boolean;override;
        procedure handleopcode;override;
        procedure handletargetdirective; override;
       protected
        procedure BuildReference(oper: TAArch64Operand; is64bit: boolean);
        procedure BuildOperand(oper: TAArch64Operand; is64bit: boolean);
        function TryBuildShifterOp(instr: TAArch64Instruction; opnr: LongInt) : boolean;
        procedure BuildOpCode(instr: TAArch64Instruction);
        procedure ReadSym(oper: TAArch64Operand; is64bit: boolean);
        procedure ConvertCalljmp(instr: TAArch64Instruction);
        function ToConditionCode(const hs: string; is_operand: boolean): TAsmCond;
        function ParseArrangementSpecifier(const hs: string): TSubRegister;
        function ParseRegIndex(const hs: string): byte;
      end;


  Implementation

    uses
      { helpers }
      CUtils,
      { global }
      GlobType,Verbose,
      Systems,aasmbase,AAsmData,aasmcpu,
      { symtable }
      symconst,SymSym,symdef,
      ProcInfo,
      rabase,rautils,
      cgutils,paramgr;


    function TAArch64ATTReader.is_register(const s:string):boolean;
      type
        TReg2Str = record
          name : string[3];
          reg : TRegister;
        end;

      const
        extraregs : array[0..4] of TReg2Str = (
          (name: 'FP' ; reg: NR_FP),
          (name: 'LR' ; reg: NR_LR),
          (name: 'XR' ; reg: NR_XR),
          (name: 'IP0'; reg: NR_IP0),
          (name: 'IP1'; reg: NR_IP1));

      var
        i : LongInt;

      begin
        result:=inherited is_register(s);
        { reg found?
          possible aliases are always 2 chars
        }
        if result or not(length(s) in [2]) then
          exit;
        for i:=low(extraregs) to high(extraregs) do
          begin
            if s=extraregs[i].name then
              begin
                actasmregister:=extraregs[i].reg;
                result:=true;
                actasmtoken:=AS_REGISTER;
                exit;
              end;
          end;
      end;


    const
      { Aarch64 subset of SEH directives. .seh_proc, .seh_endproc and .seh_endepilogue
        excluded because they are generated automatically when needed. }
      recognized_directives: set of TAsmSehDirective=[
        ash_endprologue,ash_handler,ash_handlerdata,
        ash_stackalloc,ash_nop,ash_savefplr,ash_savefplr_x,
        ash_savereg,ash_savereg_x,ash_saveregp,ash_saveregp_x,
        ash_savefreg,ash_savefreg_x,ash_savefregp,ash_savefregp_x,
        ash_setfp,ash_addfp
      ];


    function TAArch64ATTReader.is_targetdirective(const s: string): boolean;
      var
        i: TAsmSehDirective;
      begin
        result:=false;
        if TargetInfo.system<>system_aarch64_win64 then
          exit;

        for i:=low(TAsmSehDirective) to high(TAsmSehDirective) do
          begin
            if not (i in recognized_directives) then
              continue;
            if s=sehdirectivestr[i] then
              begin
                actsehdirective:=i;
                result:=true;
                break;
              end;
          end;
        { allow SEH directives only in pure assember routines }
        if result and not (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          begin
            Message(asmr_e_seh_in_pure_asm_only);
            result:=false;
          end;
      end;


    procedure TAArch64ATTReader.ReadSym(oper: TAArch64Operand; is64bit: boolean);
      var
         tempstr, MangledName : string;
         typesize,l,k: aint;
      begin
        tempstr:=actasmpattern;
        Consume(AS_ID);
        { typecasting? }
        if (actasmtoken=AS_LPAREN) and
           SearchType(tempstr,typesize) then
          begin
            oper.hastype:=true;
            Consume(AS_LPAREN);
            BuildOperand(oper,is64bit);
            Consume(AS_RPAREN);
            if oper.opr.typ in [OPR_REFERENCE,OPR_LOCAL] then
              oper.SetSize(typesize,true);
          end
        else
          if not oper.SetupVar(tempstr,false) then
            Message1(sym_e_unknown_id,tempstr);
        { record.field ? }
        if actasmtoken=AS_DOT then
          begin
            BuildRecordOffsetSize(tempstr,l,k,MangledName,false);
            if (MangledName<>'') then
              Message(asmr_e_invalid_reference_syntax);
            inc(oper.opr.Ref.Offset,l);
          end;
      end;


    Procedure TAArch64ATTReader.BuildReference(oper: TAArch64Operand; is64bit: boolean);

      procedure do_error;
        begin
          Message(asmr_e_invalid_reference_syntax);
          RecoverConsume(false);
        end;


      procedure test_end(require_rbracket : boolean);
        begin
          if require_rbracket then begin
            if not(actasmtoken=AS_RBRACKET) then
              begin
                do_error;
                exit;
              end
            else
              Consume(AS_RBRACKET);
            if (actasmtoken=AS_NOT) then
              begin
                oper.opr.Ref.AddressMode:=AM_PREINDEXED;
                Consume(AS_NOT);
              end;
          end;
          if not(actasmtoken in [AS_SEPARATOR,AS_end]) then
            do_error
          else
            begin
            end;
        end;


      function is_shifter_ref_operation(var a : TShiftMode) : boolean;
        begin
          a:=SM_NONE;
          if (actasmpattern='LSL') then
            a:=SM_LSL
          else if (actasmpattern='UXTW') then
            a:=SM_UXTW
          else if (actasmpattern='SXTW') then
            a:=SM_SXTW
          else if (actasmpattern='SXTX') then
            a:=SM_SXTX;
          is_shifter_ref_operation:=not(a=SM_NONE);
        end;


      procedure read_index_shift(require_rbracket : boolean);
        var
          shift: aint;
        begin
          case actasmtoken of
            AS_COMMA :
              begin
                Consume(AS_COMMA);
                if not(actasmtoken=AS_ID) then
                  do_error;
                if is_shifter_ref_operation(oper.opr.Ref.ShiftMode) then
                  begin
                    Consume(actasmtoken);
                    if actasmtoken=AS_HASH then
                      begin
                        Consume(AS_HASH);
                        shift:=BuildConstExpression(false,true);
                        if not(shift in [0,2+ord(is64bit)]) then
                          do_error;
                        oper.opr.Ref.ShiftImm:=shift;
                        test_end(require_rbracket);
                      end;
                   end
                 else
                   begin
                     do_error;
                     exit;
                   end;
              end;
            AS_RBRACKET :
              if require_rbracket then
                test_end(require_rbracket)
              else
                begin
                  do_error;
                  exit;
                end;
            AS_SEPARATOR,AS_END :
              if not require_rbracket then
                test_end(false)
               else
                 do_error;
            else
              begin
                do_error;
                exit;
              end;
          end;
        end;


      procedure read_index(require_rbracket : boolean);
        var
          recname : string;
          o_int,s_int : aint;
        begin
          case actasmtoken of
            AS_REGISTER :
              begin
                if GetSupReg(actasmregister)=RS_XZR then
                  Message1(asmr_e_invalid_ref_register,actasmpattern);
                oper.opr.Ref.Index:=actasmregister;
                Consume(AS_REGISTER);
                read_index_shift(require_rbracket);
                exit;
              end;
            AS_HASH : // constant
              begin
                Consume(AS_HASH);
(*
                if actasmtoken=AS_COLON then
                  begin
                    consume(AS_COLON);
                    { GNU-style lower 12 bits of address of non-GOT-based
                      access }
                    if (actasmpattern='LO12') then
                      begin
                        consume(actasmtoken);
                        consume(AS_COLON);
                        if not oper.SetupVar(actasmpattern,false) then
                          begin
                            do_error;
                            exit
                          end;
                        consume(AS_ID);
                        oper.opr.ref.refaddr:=addr_??? (not gotpageoffset);
                      end
                    else
                      begin
                        do_error;
                        exit
                      end;
                  end
                else
*)
                  begin
                    o_int:=BuildConstExpression(false,true);
                    inc(oper.opr.Ref.Offset,o_int);
                  end;
                test_end(require_rbracket);
                exit;
              end;
            AS_ID :
              begin
                recname:=actasmpattern;
                Consume(AS_ID);
                { Apple-style got page offset }
                if actasmtoken=AS_AT then
                  begin
                    if not oper.SetupVar(recname,false) then
                      begin
                        do_error;
                        exit
                      end;
                    consume(AS_AT);
                    if actasmpattern='GOTPAGEOFF' then
                      begin
                        consume(actasmtoken);
                        oper.opr.Ref.RefAddr:=addr_gotpageoffset;
                      end
                    else if actasmpattern='PAGEOFF' then
                      begin
                        consume(actasmtoken);
                        oper.opr.Ref.RefAddr:=addr_pageoffset;
                      end
                    else
                      begin
                        do_error;
                        exit
                      end;
                  end
                else
                  begin
                    BuildRecordOffsetSize(recname,o_int,s_int,recname,false);
                    inc(oper.opr.Ref.Offset,o_int);
                  end;
                test_end(require_rbracket);
                exit;
              end;
            AS_AT:
              begin
                do_error;
                exit;
              end;
            AS_RBRACKET :
              begin
                if require_rbracket then
                  begin
                    test_end(require_rbracket);
                    exit;
                  end
                else
                  begin
                    do_error; // unexpected rbracket
                    exit;
                  end;
              end;
            AS_SEPARATOR,AS_end :
              begin
                if not require_rbracket then
                  begin
                    test_end(false);
                    exit;
                  end
                else
                  begin
                    do_error;
                    exit;
                  end;
              end;
            else
              begin
                // unexpected token
                do_error;
                exit;
              end;
          end; // case
        end;


      procedure try_prepostindexed;
        begin
          Consume(AS_RBRACKET);
          case actasmtoken of
            AS_COMMA :
              begin // post-indexed
                Consume(AS_COMMA);
                oper.opr.Ref.AddressMode:=AM_POSTINDEXED;
                read_index(false);
                exit;
              end;
            AS_NOT :
              begin   // pre-indexed
                Consume(AS_NOT);
                oper.opr.Ref.AddressMode:=AM_PREINDEXED;
                test_end(false);
                exit;
              end;
            else
              begin
                test_end(false);
                exit;
              end;
          end; // case
        end;

      begin
        Consume(AS_LBRACKET);
        oper.opr.Ref.AddressMode:=AM_OFFSET; // assume "neither PRE nor POST inc"
        if actasmtoken=AS_REGISTER then
          begin
            if GetSupReg(actasmregister)=RS_XZR then
              Message1(asmr_e_invalid_ref_register,actasmpattern);
            oper.opr.Ref.Base:=actasmregister;
            Consume(AS_REGISTER);
            case actasmtoken of
              AS_RBRACKET :
                begin
                  try_prepostindexed;
                  exit;
                end;
              AS_COMMA :
                begin
                  Consume(AS_COMMA);
                  read_index(true);
                  exit;
                end;
              else
                begin
                  Message(asmr_e_invalid_reference_syntax);
                  RecoverConsume(false);
                end;
            end;
          end
        else
          Begin
            case actasmtoken of
              AS_ID :
                begin
                  { TODO: local variables and parameters }
                  Message(asmr_e_invalid_reference_syntax);
                  RecoverConsume(false);
                  exit;
                end;
              else
                begin // else case
                  Message(asmr_e_invalid_reference_syntax);
                  RecoverConsume(false);
                  exit;
                end;
            end;
          end;
      end;


    function TAArch64ATTReader.TryBuildShifterOp(instr: TAArch64Instruction; opnr: LongInt): boolean;

      procedure handlepara(sm : TShiftMode);
        begin
          consume(AS_ID);
          fillchar(instr.operands[opnr].opr,sizeof(instr.operands[opnr].opr),0);
          instr.operands[opnr].opr.typ:=OPR_SHIFTEROP;
          instr.operands[opnr].opr.shifterop.ShiftMode:=sm;
          if (sm=SM_LSL) or
             (actasmtoken=AS_HASH) then
            begin
              consume(AS_HASH);
              instr.operands[opnr].opr.shifterop.ShiftImm:=BuildConstExpression(false,false);
            end;
        end;

      const
        shiftmode2str: array[SM_LSL..SM_SXTX] of string[4] =
          ('LSL','LSR','ASR','ROR',
           'UXTB','UXTH','UXTW','UXTX',
           'SXTB','SXTH','SXTW','SXTX');
      var
        sm: TShiftMode;
        i: LongInt;
        usessp,
        useszr: boolean;
      begin
        result:=false;
        if (actasmtoken=AS_ID) then
          begin
            for sm:=low(shiftmode2str) to high(shiftmode2str) do
              if actasmpattern=shiftmode2str[sm] then
                begin
                  handlepara(sm);
                  if instr.operands[1].opr.typ=OPR_REGISTER then
                    begin
                      { the possible shifter ops depend on whether this
                        instruction uses sp and/or zr }
                      usessp:=false;
                      useszr:=false;
                      for i:=low(instr.operands) to pred(opnr) do
                        begin
                          if (instr.operands[i].opr.typ=OPR_REGISTER) then
                            case GetSupReg(instr.operands[i].opr.reg) of
                              RS_XZR:
                                useszr:=true;
                              RS_SP:
                                usessp:=true;
                            end;
                        end;
                      result:=valid_shifter_operand(instr.opcode,useszr,usessp,instr.Is64bit,sm,instr.operands[opnr].opr.shifterop.ShiftImm);
                      if result then
                        instr.Ops:=opnr;
                    end;
                  break;
                end;
          end;
      end;


    function TAArch64ATTReader.ToConditionCode(const hs: string; is_operand: boolean): TAsmCond;
{$push}{$j-}
      const
        extracond2str: array[C_HS..C_LO] of string[2] = ('CS','CC');
{$pop}
      begin
        case actopcode of
          A_CSEL,A_CSINC,A_CSINV,A_CSNEG,A_CSET,A_CSETM,
          A_CINC,A_CINV,A_CNEG,A_CCMN,A_CCMP,
          A_FCCMP,A_FCCMPE,
          A_B:
            begin
              { search for condition, conditions are always 2 chars }
              if (is_operand<>(actopcode=A_B)) and
                 (length(hs)>1) then
                begin
                  { workaround for DFA bug }
                  result:=low(TAsmCond);
                  for result:=low(uppercond2str) to high(uppercond2str) do
                    begin
                      if hs=uppercond2str[result] then
                        exit;
                    end;
                  for result:=low(extracond2str) to high(extracond2str) do
                    begin
                      if hs=extracond2str[result] then
                        exit;
                    end;
                end;
            end;
          else
            ;
        end;
        result:=C_None;
      end;


    function TAArch64ATTReader.ParseArrangementSpecifier(const hs: string): TSubRegister;
{$push}{$j-}
      const
        arrangements: array[R_SUBMM8B..R_SUBMM2D] of string[4] =
          ('.8B','.16B','.4H','.8H','.2S','.4S','.1D','.2D');
{$pop}
      begin
        if length(hs)>2 then
          begin
            for result:=low(arrangements) to high(arrangements) do
              if hs=arrangements[result] then
                exit;
            result:=R_SUBNONE;
          end
        else
          case hs of
            '.B': result:=R_SUBMMB1;
            '.H': result:=R_SUBMMH1;
            '.S': result:=R_SUBMMS1;
            '.D': result:=R_SUBMMD1;
            else
              result:=R_SUBNONE;
          end
      end;


    function TAArch64ATTReader.ParseRegIndex(const hs: string): byte;
      var
        b: cardinal;
        error: LongInt;
      begin
        b:=0;
        val(hs,b,error);
        if (error<>0) then
          Message(asmr_e_syn_constant)
        else if b > 31 then
          begin
            Message(asmr_e_constant_out_of_bounds);
            b:=0;
          end;
        result:=b;
      end;


    Procedure TAArch64ATTReader.BuildOperand(oper: TAArch64Operand; is64bit: boolean);
      var
        expr: string;
        typesize, l: aint;

        procedure MaybeAddGotAddrMode;
          begin
            if actasmtoken=AS_AT then
              begin
                consume(AS_AT);
                if actasmpattern='GOTPAGE' then
                  oper.opr.Ref.RefAddr:=addr_gotpage
                else if actasmpattern='GOTPAGEOFF' then
                  oper.opr.Ref.RefAddr:=addr_gotpageoffset
                else if actasmpattern='PAGE' then
                  oper.opr.Ref.RefAddr:=addr_page
                else if actasmpattern='PAGEOFF' then
                  oper.opr.Ref.RefAddr:=addr_pageoffset
                else
                  Message(asmr_e_expr_illegal);
                consume(actasmtoken);
              end
            else
              oper.opr.Ref.RefAddr:=addr_pic;
          end;

        procedure AddLabelOperand(hl:TAsmLabel);
          begin
            if not(actasmtoken in [AS_PLUS,AS_MINUS,AS_LPAREN]) and
               is_calljmp(actopcode) then
             begin
               oper.opr.typ:=OPR_SYMBOL;
               oper.opr.Symbol:=hl;
             end
            else if (actopcode=A_ADR) or
               (actopcode=A_ADRP) or
               (actopcode=A_LDR) then
              begin
                oper.InitRef;
                MaybeAddGotAddrMode;
                oper.opr.Ref.Symbol:=hl;
                if (actasmtoken in [AS_PLUS, AS_MINUS]) then
                  begin
                    l:=BuildConstExpression(true,false);
                    oper.opr.Ref.Offset:=l;
                  end;
              end;
          end;


        procedure MaybeRecordOffset;
          var
            MangledName: string;
            hasdot  : boolean;
            l,
            toffset,
            tsize   : aint;
          begin
            if not(actasmtoken in [AS_DOT,AS_PLUS,AS_MINUS]) then
              exit;
            l:=0;
            MangledName:='';
            hasdot:=(actasmtoken=AS_DOT);
            if hasdot then
              begin
                if expr<>'' then
                  begin
                    BuildRecordOffsetSize(expr,toffset,tsize,MangledName,false);
                    if (oper.opr.typ<>OPR_CONSTANT) and
                       (MangledName<>'') then
                      Message(asmr_e_wrong_sym_type);
                    inc(l,toffset);
                    oper.SetSize(tsize,true);
                  end;
              end;
            if actasmtoken in [AS_PLUS,AS_MINUS] then
              inc(l,BuildConstExpression(true,false));
            case oper.opr.typ of
              OPR_LOCAL :
                begin
                  { don't allow direct access to fields of parameters, because that
                    will generate buggy code. Allow it only for explicit typecasting }
                  if hasdot and
                     (not oper.hastype) then
                    checklocalsubscript(oper.opr.localsym);
                  inc(oper.opr.localsymofs,l)
                end;
              OPR_CONSTANT :
                inc(oper.opr.Val,l);
              OPR_REFERENCE :
                if (MangledName<>'') then
                  begin
                    if (oper.opr.Val<>0) then
                      Message(asmr_e_wrong_sym_type);
                    oper.opr.typ:=OPR_SYMBOL;
                    oper.opr.Symbol:=CurrentAsmData.RefAsmSymbol(MangledName,AT_FUNCTION);
                  end
                else
                  inc(oper.opr.Val,l);
              OPR_SYMBOL:
                Message(asmr_e_invalid_symbol_ref);
              else
                InternalError(200309221);
            end;
          end;


        function MaybeBuildReference(is64bit: boolean):boolean;
          { Try to create a reference, if not a reference is found then false
            is returned }
          begin
            MaybeBuildReference:=true;
            case actasmtoken of
              AS_INTNUM,
              AS_MINUS,
              AS_PLUS:
                Begin
                  oper.opr.Ref.Offset:=BuildConstExpression(True,False);
                  if actasmtoken<>AS_LPAREN then
                    Message(asmr_e_invalid_reference_syntax)
                  else
                    BuildReference(oper,is64bit);
                end;
              AS_LPAREN:
                BuildReference(oper,is64bit);
              AS_ID: { only a variable is allowed ... }
                Begin
                  ReadSym(oper,is64bit);
                  case actasmtoken of
                    AS_end,
                    AS_SEPARATOR,
                    AS_COMMA: ;
                    AS_LPAREN:
                      BuildReference(oper,is64bit);
                  else
                    Begin
                      Message(asmr_e_invalid_reference_syntax);
                      Consume(actasmtoken);
                    end;
                  end; {end case }
                end;
              else
               MaybeBuildReference:=false;
            end; { end case }
          end;

      function parsereg: TRegister;
         var
           SubReg: TSubRegister;
        begin
          result:=actasmregister;
          Consume(AS_REGISTER);
          if (actasmtoken=AS_ID) and
             (actasmpattern[1]='.') then
            begin
              SubReg:=ParseArrangementSpecifier(upper(actasmpattern));
              if (SubReg<>R_SUBNONE) and
                (GetRegType(result)=R_MMREGISTER) then
                begin
                  if ((actinsmmsubreg=R_SUBNONE) or
                    (actinsmmsubreg=SubReg)) then
                    begin
                      SetSubReg(result,SubReg);
                      { they all have to be the same }
                      actinsmmsubreg:=SubReg;
                    end
                  else if (actopcode=A_SHRN) or (actopcode=A_SHRN2) then
                    begin
                      { shrn, shrn2 allow combinations of different sizes ]}
                      SetSubReg(result,SubReg);
                    end
                  else
                    Message1(asmr_e_invalid_arrangement,actasmpattern);
                end
              else
                Message1(asmr_e_invalid_arrangement,actasmpattern);
              Consume(AS_ID);
            end
          else if (GetRegType(result)=R_MMREGISTER) then
            begin
              if actinsmmsubreg<>R_SUBNONE then
                begin
                  if (GetSubReg(result)=R_SUBNONE) or
                     (GetSubReg(result)=actinsmmsubreg) then
                    SetSubReg(result,actinsmmsubreg)
                  else
                     Message1(asmr_e_invalid_arrangement,actasmpattern);
                end
              else if GetSubReg(result)=R_SUBNONE then
                { Vxx without an arrangement is invalid, use Qxx to specify the entire 128 bits}
                Message1(asmr_e_invalid_arrangement,'');
            end;
        end;

      var
        tempreg: TRegister;
        hl: TAsmLabel;
        icond: TAsmCond;
        RegIndex: byte;
      Begin
        expr:='';
        case actasmtoken of
          AS_LBRACKET: { Memory reference or constant expression }
            Begin
              oper.InitRef;
              BuildReference(oper,is64bit);
            end;

          AS_LSBRACKET: { register set }
            begin
              consume(AS_LSBRACKET);
              oper.opr.typ:=OPR_REGSET;
              oper.opr.basereg:=parsereg;
              oper.opr.nregs:=1;

              while (actasmtoken<>AS_RSBRACKET) and (oper.opr.nregs<4) do
                begin
                  if actasmtoken=AS_MINUS then
                    begin
                      consume(AS_MINUS);
                      tempreg:=parsereg;

                      if (GetSupReg(tempreg)-GetSupReg(oper.opr.basereg))>=4 then
                        Message(asmr_e_a64_regset_too_large);
                      oper.opr.nregs:=GetSupReg(tempreg)-GetSupReg(oper.opr.basereg)+1;
                      if actasmtoken<>AS_COMMA then
                        break;
                    end;
                  if actasmtoken=AS_COMMA then
                    begin
                      consume(AS_COMMA);
                      tempreg:=parsereg;
                      if (GetSupReg(tempreg)-GetSupReg(oper.opr.basereg))>=4 then
                        Message(asmr_e_a64_regset_too_large);
                      if GetSupReg(tempreg)<>((GetSupReg(oper.opr.basereg)+oper.opr.nregs) mod 32) then
                        Message(asmr_e_a64_invalid_regset);
                      inc(oper.opr.nregs);
                    end
                  else
                    break;
                end;
              consume(AS_RSBRACKET);
              if actasmtoken=AS_LBRACKET then
                begin
                  consume(AS_LBRACKET);
                  oper.opr.regsetindex:=ParseRegIndex(actasmpattern);
                  consume(AS_INTNUM);
                  consume(AS_RBRACKET);
                end
              else
                oper.opr.regsetindex:=255;
              if not(actasmtoken in [AS_END,AS_SEPARATOR,AS_COMMA]) then
                Message(asmr_e_syn_operand);
            end;

          AS_HASH: { Constant expression  }
            Begin
              Consume(AS_HASH);
              BuildConstantOperand(oper);
            end;

          (*
          AS_INTNUM,
          AS_MINUS,
          AS_PLUS:
            Begin
              { Constant memory offset }
              { This must absolutely be followed by (  }
              oper.InitRef;
              oper.opr.ref.offset:=BuildConstExpression(True,False);
              if actasmtoken<>AS_LPAREN then
                begin
                  ofs:=oper.opr.ref.offset;
                  BuildConstantOperand(oper);
                  inc(oper.opr.val,ofs);
                end
              else
                BuildReference(oper,is64bit);
            end;
          *)
          AS_ID: { A constant expression, or a Variable ref.  }
            Begin
              { Condition code? }
              icond:=ToConditionCode(actasmpattern,true);
              if icond<>C_None then
                begin
                  oper.opr.typ:=OPR_COND;
                  oper.opr.cc:=icond;
                  consume(AS_ID);
                end
              else
              { Local Label ? }
              if is_locallabel(actasmpattern) then
               begin
                 CreateLocalLabel(actasmpattern,hl,false);
                 Consume(AS_ID);
                 AddLabelOperand(hl);
               end
              else
               { Check for label }
               if SearchLabel(actasmpattern,hl,false) then
                 begin
                   Consume(AS_ID);
                   AddLabelOperand(hl);
                 end
              else
               { probably a variable or normal expression }
               { or a procedure (such as in CALL ID)      }
               begin
                 { is it a constant ? }
                 if SearchIConstant(actasmpattern,l) then
                  begin
                    if not (oper.opr.typ in [OPR_NONE,OPR_CONSTANT]) then
                      Message(asmr_e_invalid_operand_type);
                    BuildConstantOperand(oper);
                  end
                 else
                  begin
                    expr:=actasmpattern;
                    Consume(AS_ID);
                    { typecasting? }
                    if (actasmtoken=AS_LPAREN) and
                       SearchType(expr,typesize) then
                     begin
                       oper.hastype:=true;
                       Consume(AS_LPAREN);
                       BuildOperand(oper,is64bit);
                       Consume(AS_RPAREN);
                       if oper.opr.typ in [OPR_REFERENCE,OPR_LOCAL] then
                         oper.SetSize(typesize,true);
                     end
                    else
                     begin
                       if not(oper.SetupVar(expr,false)) then
                        Begin
                          { look for special symbols ... }
                          if expr= '__HIGH' then
                            begin
                              consume(AS_LPAREN);
                              if not oper.setupvar('high'+actasmpattern,false) then
                                Message1(sym_e_unknown_id,'high'+actasmpattern);
                              consume(AS_ID);
                              consume(AS_RPAREN);
                            end
                          else
                           if expr = '__RESULT' then
                            oper.SetUpResult
                          else
                           if expr = '__SELF' then
                            oper.SetupSelf
                          else
                           if expr = '__OLDEBP' then
                            oper.SetupOldEBP
                          else
                            Message1(sym_e_unknown_id,expr);
                        end
                       else if oper.opr.typ<>OPR_LOCAL then
                         begin
                           oper.InitRef;
                           MaybeAddGotAddrMode;
                         end;
                     end;
                  end;
                  if actasmtoken=AS_DOT then
                    MaybeRecordOffset;
                  { add a constant expression? }
                  if (actasmtoken=AS_PLUS) then
                   begin
                     l:=BuildConstExpression(true,false);
                     case oper.opr.typ of
                       OPR_CONSTANT :
                         inc(oper.opr.Val,l);
                       OPR_LOCAL :
                         inc(oper.opr.localsymofs,l);
                       OPR_REFERENCE :
                         inc(oper.opr.Ref.Offset,l);
                       else
                         InternalError(2003092005);
                     end;
                   end
               end;
              { Do we have a indexing reference, then parse it also }
              if actasmtoken=AS_LPAREN then
                BuildReference(oper,is64bit);
            end;

          { Register, a variable reference or a constant reference  }
          AS_REGISTER:
            Begin
              { save the type of register used. }
              tempreg:=parsereg;
              RegIndex:=255;
              if (GetRegType(tempreg)=R_MMREGISTER) and
                 (actasmtoken=AS_LBRACKET) then
                begin
                  consume(AS_LBRACKET);
                  RegIndex:=ParseRegIndex(actasmpattern);
                  consume(AS_INTNUM);
                  consume(AS_RBRACKET);
                end;
              if actasmtoken in [AS_END,AS_SEPARATOR,AS_COMMA] then
                begin
                  if (oper.opr.typ<>OPR_NONE) then
                    Message(asmr_e_invalid_operand_type);
                  if RegIndex=255 then
                    begin
                      oper.opr.typ:=OPR_REGISTER;
                      oper.opr.reg:=tempreg;
                    end
                  else
                    begin
                      oper.opr.typ:=OPR_INDEXEDREG;
                      oper.opr.indexedreg:=tempreg;
                      oper.opr.RegIndex:=RegIndex;
                    end;
                end
              else
                Message(asmr_e_syn_operand);
            end;

          AS_end,
          AS_SEPARATOR,
          AS_COMMA: ;
        else
          Begin
            Message(asmr_e_syn_operand);
            Consume(actasmtoken);
          end;
        end; { end case }
      end;

{*****************************************************************************
                                taarch64attreader
*****************************************************************************}

    procedure TAArch64ATTReader.BuildOpCode(instr: TAArch64Instruction);
      var
        operandnum : LongInt;
      Begin
        { opcode }
        if (actasmtoken<>AS_OPCODE) then
         Begin
           Message(asmr_e_invalid_or_missing_opcode);
           RecoverConsume(true);
           exit;
         end;
        { Fill the instr object with the current state }
        with instr do
          begin
            Opcode:=ActOpcode;
            condition:=ActCondition;
            oppostfix:=actoppostfix;
          end;
        Consume(AS_OPCODE);

        { We are reading operands, so opcode will be an AS_ID }
        operandnum:=1;
        { Zero operand opcode ?  }
        if actasmtoken in [AS_SEPARATOR,AS_end] then
         begin
           instr.Ops:=0;
           exit;
         end;
        { Read the operands }
        repeat
          case actasmtoken of
            AS_COMMA: { Operand delimiter }
              Begin
                { operandnum and not operandnum+1, because tinstruction is
                  one-based and taicpu is zero-based)
                }
                if can_be_shifter_operand(instr.opcode,operandnum) then
                  begin
                    Consume(AS_COMMA);
                    if not TryBuildShifterOp(instr,operandnum+1) then
                      Message(asmr_e_illegal_shifterop_syntax);
                    Inc(operandnum);
                  end
                else
                  begin
                    if operandnum>Max_Operands then
                      Message(asmr_e_too_many_operands)
                    else
                      Inc(operandnum);
                    Consume(AS_COMMA);
                  end;
              end;
            AS_SEPARATOR,
            AS_end : { End of asm operands for this opcode  }
              begin
                break;
              end;
          else
            begin
              BuildOperand(TAArch64Operand(instr.operands[operandnum]),instr.Is64bit);
              instr.Ops:=operandnum;
              if instr.operands[operandnum].opr.typ=OPR_REFERENCE then
                if simple_ref_type(instr.opcode,instr.cgsize,instr.oppostfix,instr.operands[operandnum].opr.Ref)<>sr_simple then
                  Message(asmr_e_invalid_reference_syntax);
                ;
            end;
          end; { end case }
        until false;
      end;


    function TAArch64ATTReader.is_asmopcode(const s: string):boolean;

      const
        { sorted by length so longer postfixes will match first }
        postfix2strsorted : array[1..7] of string[3] = (
          'SB','SH','SW',
          'B','H','W',
          'S');

        postfixsorted : array[1..7] of TOpPostfix = (
          PF_SB,PF_SH,PF_SW,
          PF_B,PF_H,PF_W,
          PF_S);

                      { store replicate }
        ldst14: array[boolean,boolean,'1'..'4'] of TAsmOp =
          (((A_LD1,A_LD2,A_LD3,A_LD4),
            (A_LD1R,A_LD2R,A_LD3R,A_LD4R)),
           ((A_ST1,A_ST2,A_ST3,A_ST4),
            (A_NONE,A_NONE,A_NONE,A_NONE)));

      var
        j  : LongInt;
        hs : string;
        maxlen : LongInt;
      Begin
        { making s a value parameter would break other assembler readers }
        hs:=s;
        is_asmopcode:=false;

        { clear opcode }
        actopcode:=A_None;
        actcondition:=C_None;

        { b.cond ? }
        if (length(hs)=4) and
           (hs[1]='B') and
           (hs[2]='.') then
          begin
            actopcode:=A_B;
            actasmtoken:=AS_OPCODE;
            actcondition:=ToConditionCode(copy(hs,3,length(actasmpattern)-2),false);
            if actcondition<>C_None then
              is_asmopcode:=true;
            exit;
          end;

        (* ldN(r)/stN.size ? (shorthand for "ldN(r)/stN { Vx.size, Vy.size } ..."
          supported by clang and possibly gas *)
        actinsmmsubreg:=R_SUBNONE;
        if (length(s)>=5) and
           (((hs[1]='L') and
             (hs[2]='D')) or
            ((hs[1]='S') and
             (hs[2]='T'))) and
           (hs[3] in ['1'..'4']) and
           ((hs[4]='.') or
            ((hs[4]='R') and
             (hs[5]='.'))) then
          begin
            actinsmmsubreg:=ParseArrangementSpecifier(copy(hs,4+ord(hs[4]='R'),255));
            if actinsmmsubreg=R_SUBNONE then
              exit;
            actopcode:=ldst14[hs[1]='S',hs[4]='R',hs[3]];
            actasmtoken:=AS_OPCODE;
            if actopcode<>A_NONE then
              is_asmopcode:=true;
            exit;
          end;

        maxlen:=max(length(hs),7);
        actopcode:=A_NONE;
        for j:=maxlen downto 1 do
          begin
            actopcode:=TAsmOp(PtrUInt(iasmops.Find(copy(hs,1,j))));
            if actopcode<>A_NONE then
              begin
                actasmtoken:=AS_OPCODE;
                { strip op code }
                delete(hs,1,j);
                break;
              end;
          end;
        if actopcode=A_NONE then
          exit;

        { check for postfix }
        if length(hs)>0 then
          begin
            for j:=low(postfixsorted) to high(postfixsorted) do
              begin
                if copy(hs,1,length(postfix2strsorted[j]))=postfix2strsorted[j] then
                  begin
                    actoppostfix:=postfixsorted[j];
                    { strip postfix }
                    delete(hs,1,length(postfix2strsorted[j]));
                    break;
                  end;
              end;
          end;
        { if we stripped all postfixes, it's a valid opcode }
        is_asmopcode:=length(hs)=0;
      end;


    procedure TAArch64ATTReader.ConvertCalljmp(instr: TAArch64Instruction);
      var
        newopr : TOprRec;
      begin
        if instr.Operands[1].opr.typ=OPR_REFERENCE then
          begin
            newopr.typ:=OPR_SYMBOL;
            newopr.Symbol:=instr.Operands[1].opr.Ref.Symbol;
            newopr.symofs:=instr.Operands[1].opr.Ref.Offset;
            if (instr.Operands[1].opr.Ref.Base<>NR_NO) or
              (instr.Operands[1].opr.Ref.Index<>NR_NO) or
              (instr.Operands[1].opr.Ref.RefAddr<>addr_pic) then
              Message(asmr_e_syn_operand);
            instr.Operands[1].opr:=newopr;
          end;
      end;

    procedure TAArch64ATTReader.handleopcode;
      var
        instr: TAArch64Instruction;
      begin
        instr:=TAArch64Instruction.Create(TAArch64Operand);
        BuildOpcode(instr);
        if is_calljmp(instr.opcode) then
          ConvertCalljmp(instr);
        {
        instr.AddReferenceSizes;
        instr.SetInstructionOpsize;
        instr.CheckOperandSizes;
        }
        instr.ConcatInstruction(curlist);
        instr.Free;
        actoppostfix:=PF_None;
      end;


    procedure TAArch64ATTReader.handletargetdirective;

      function maxoffset(ash:TAsmSehDirective):aint;
        begin
          case ash of
            ash_savefplr,
            ash_saveregp,
            ash_savereg,
            ash_savefregp,
            ash_savefreg:
              result:=504;
            ash_savefplr_x,
            ash_saveregp_x,
            ash_savefregp_x:
              result:=-512;
            ash_savereg_x,
            ash_savefreg_x:
              result:=-256;
            ash_addfp:
              result:=2040;
            else
              InternalError(2020041204);
          end;
        end;

      procedure add_reg_with_offset(ash:TAsmSehDirective;hreg:TRegister;hnum:aint;neg:boolean);
        begin
          if (neg and ((hnum>0) or (hnum<maxoffset(ash)) or (((-hnum) and $7)<>0))) or
              (not neg and ((hnum<0) or (hnum>maxoffset(ash)) or ((hnum and $7)<>0))) then
            Message1(asmr_e_bad_seh_directive_offset,sehdirectivestr[actsehdirective])
          else
            begin
              if neg then
                hnum:=-hnum;
              if hreg=NR_NO then
                curlist.concat(CAISEHDirective.create_offset(actsehdirective,hnum))
              else
                curlist.concat(CAISEHDirective.create_reg_offset(actsehdirective,hreg,hnum));
            end;
        end;

      var
        hreg,
        hreg2 : TRegister;
        hnum : aint;
        flags : integer;
        ai : TAISEHDirective;
        hs : string;
        err : boolean;
      begin
        if actasmtoken<>AS_TARGET_DIRECTIVE then
          InternalError(2020033102);
        Consume(AS_TARGET_DIRECTIVE);
        Include(CurrentProcInfo.flags,pi_has_unwind_info);

        case actsehdirective of
          ash_nop,
          ash_setfp,
          ash_endprologue,
          ash_handlerdata:
            curlist.concat(CAISEHDirective.create(actsehdirective));

          ash_handler:
            begin
              hs:=actasmpattern;
              Consume(AS_ID);
              flags:=0;
              err:=false;
              while actasmtoken=AS_COMMA do
                begin
                  Consume(AS_COMMA);
                  if actasmtoken=AS_AT then
                    begin
                      Consume(AS_AT);
                      if actasmtoken=AS_ID then
                        begin
                          UpperVar(actasmpattern);
                          if actasmpattern='EXCEPT' then
                            flags:=flags or 1
                          else if actasmpattern='UNWIND' then
                            flags:=flags or 2
                          else
                            err:=true;
                          Consume(AS_ID);
                        end
                      else
                        err:=true;
                    end
                  else
                    err:=true;
                  if err then
                    begin
                      Message(asmr_e_syntax_error);
                      RecoverConsume(false);
                      exit;
                    end;
                end;

              ai:=CAISEHDirective.create_name(ash_handler,hs);
              ai.data.flags:=flags;
              curlist.concat(ai);
            end;
          ash_savefplr,
          ash_savefplr_x:
            begin
              hnum:=BuildConstExpression(false,false);
              add_reg_with_offset(actsehdirective,NR_NO,hnum,actsehdirective=ash_savefplr_x);
            end;
          ash_savereg,
          ash_savereg_x:
            begin
              hreg:=actasmregister;
              Consume(AS_REGISTER);
              if (GetRegType(hreg)<>R_INTREGISTER) or (GetSubReg(hreg)<>R_SUBWHOLE) or (GetSupReg(hreg)<19) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              Consume(AS_COMMA);
              hnum:=BuildConstExpression(false,false);
              add_reg_with_offset(actsehdirective,hreg,hnum,actsehdirective=ash_savereg_x);
            end;
          ash_saveregp,
          ash_saveregp_x:
            begin
              hreg:=actasmregister;
              consume(AS_REGISTER);
              if (GetRegType(hreg)<>R_INTREGISTER) or (GetSubReg(hreg)<>R_SUBWHOLE) or (GetSupReg(hreg)<19) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              consume(AS_COMMA);
              hreg2:=actasmregister;
              consume(AS_REGISTER);
              if (GetRegType(hreg2)<>R_INTREGISTER) or (GetSubReg(hreg2)<>R_SUBWHOLE) or (GetSupReg(hreg2)<>GetSupReg(hreg)+1) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              consume(AS_COMMA);
              hnum:=BuildConstExpression(false,false);
              add_reg_with_offset(actsehdirective,hreg,hnum,actsehdirective=ash_saveregp_x);
            end;
          ash_savefreg,
          ash_savefreg_x:
            begin
              hreg:=actasmregister;
              Consume(AS_REGISTER);
              if (GetRegType(hreg)<>R_MMREGISTER) or (GetSubReg(hreg)<>R_SUBWHOLE) or (GetSupReg(hreg)<8) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              Consume(AS_COMMA);
              hnum:=BuildConstExpression(false,false);
              add_reg_with_offset(actsehdirective,hreg,hnum,actsehdirective=ash_savefreg_x);
            end;
          ash_savefregp,
          ash_savefregp_x:
            begin
              hreg:=actasmregister;
              consume(AS_REGISTER);
              if (GetRegType(hreg)<>R_MMREGISTER) or (GetSubReg(hreg)<>R_SUBWHOLE) or (GetSupReg(hreg)<8) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              consume(AS_COMMA);
              hreg2:=actasmregister;
              consume(AS_REGISTER);
              if (GetRegType(hreg2)<>R_MMREGISTER) or (GetSubReg(hreg2)<>R_SUBWHOLE) or (GetSupReg(hreg2)<>GetSupReg(hreg)+1) then
                Message1(asmr_e_bad_seh_directive_register,sehdirectivestr[actsehdirective]);
              consume(AS_COMMA);
              hnum:=BuildConstExpression(false,false);
              add_reg_with_offset(actsehdirective,hreg,hnum,actsehdirective=ash_savefregp_x);
            end;
          ash_stackalloc:
            begin
              hnum:=BuildConstExpression(false,false);
              if (hnum<0) or (hnum>$FFFFFF) or ((hnum and 7)<>0) then
                Message1(asmr_e_bad_seh_directive_offset,sehdirectivestr[ash_stackalloc])
              else
                curlist.concat(CAISEHDirective.create_offset(ash_stackalloc,hnum));
            end;
          else
            InternalError(2020033103);
        end;
        if actasmtoken<>AS_SEPARATOR then
          Consume(AS_SEPARATOR);
      end;


{*****************************************************************************
                                     Initialize
*****************************************************************************}

const
  asmmode_arm_att_info : TAsmModeInfo =
          (
            id    : asmmode_arm_gas;
            idtxt : 'GAS';
            CAsmReader : TAArch64ATTReader;
          );

  asmmode_arm_standard_info : TAsmModeInfo =
          (
            id    : asmmode_standard;
            idtxt : 'STANDARD';
            CAsmReader : TAArch64ATTReader;
          );

initialization
  RegisterAsmMode(asmmode_arm_att_info);
  RegisterAsmMode(asmmode_arm_standard_info);
end.
