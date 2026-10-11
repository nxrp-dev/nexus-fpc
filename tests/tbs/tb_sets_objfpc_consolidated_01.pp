{ Consolidated sets regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0721.pp }
{$push}
{$H+}

{$R-}

type
  tb0721_TmyRange = 1..10;
var
  tb0721_x: integer;
  tb0721_Mark: set of tb0721_TmyRange;

{$pop}

{ Case tb_sets_objfpc_run_01.pp }
{$push}
{ Sets regression cases; original case IDs are retained below. }

{ Case tw0866.pp }
{$push}

Type
     tw0866_ts = set of (tb_sets_objfpc_run_01_tse);
     tw0866_ts2 = set of (tb_sets_objfpc_run_01_t1,tb_sets_objfpc_run_01_t2);
     tw0866_enum3 = (tb_sets_objfpc_run_01_tm1:=-1,tb_sets_objfpc_run_01_t0,tb_sets_objfpc_run_01_tp1);
     tw0866_ts3 = set of tb_sets_objfpc_run_01_t0 .. tb_sets_objfpc_run_01_tp1;
 var
    tw0866_f:tw0866_ts;
    tw0866_f2 : tw0866_ts2;
    tw0866_f3 : tw0866_ts3;
{$pop}

{ Case tw17846.pp }
{$push}


const
  tw17846_intvalue1 = $1;
  tw17846_intvalue2 = $2;
  tw17846_intvalue3 = $4;

type
  tw17846_tmyenum = (tb_sets_objfpc_run_01_Value1, tb_sets_objfpc_run_01_Value2, tb_sets_objfpc_run_01_Value3);
  tw17846_tmyset = set of tw17846_tmyenum;

operator := (aRight: LongWord) aLeft: tw17846_tmyset;
begin
  aLeft := [];
  if aRight and tw17846_intvalue1 <> 0 then
    Include(aLeft, tb_sets_objfpc_run_01_Value1);
  if aRight and tw17846_intvalue2 <> 0 then
    Include(aLeft, tb_sets_objfpc_run_01_Value2);
  if aRight and tw17846_intvalue3 <> 0 then
    Include(aLeft, tb_sets_objfpc_run_01_Value3);
end;

operator := (aRight: tw17846_tmyset) aLeft: LongWord;
begin
  aLeft := 0;
  if tb_sets_objfpc_run_01_Value1 in aRight then
    aLeft := aLeft or tw17846_intvalue1;
  if tb_sets_objfpc_run_01_Value2 in aRight then
    aLeft := aLeft or tw17846_intvalue2;
  if tb_sets_objfpc_run_01_Value3 in aRight then
    aLeft := aLeft or tw17846_intvalue3;
end;

var
  tw17846_i: LongWord;
  tw17846_t: tw17846_tmyset;
{$pop}


{$pop}

{ Case tincexc.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : second_includeexclude()                          }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS: Tests the include/exclude inline code generation.     }
{****************************************************************}




{ Tests we must do :
   - small set : LOC_REGISTER, LOC_REFERENCE
   - large set : LOC_REFERENCE
}

procedure tincexc_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;

type
       { DO NOT CHANGE THE VALUES OF THESE ENUMERATIONS! }
       tincexc_tsmallenum = (tincexc_dA,tincexc_dB,tincexc_dC,tincexc_dd,tincexc_de,tincexc_df,tincexc_dg,tincexc_dh,tincexc_di,tincexc_dj,tincexc_dk,tincexc_dl,tincexc_dm,tincexc_dn,tincexc_dop,tincexc_dp,tincexc_dq,tincexc_dr);
       tincexc_tasmop = (tincexc_A_ABCD,
         tincexc_A_ADD,tincexc_A_ADDA,tincexc_A_ADDI,tincexc_A_ADDQ,tincexc_A_ADDX,tincexc_A_AND,tincexc_A_ANDI,
         tincexc_A_ASL,tincexc_A_ASR,tincexc_A_BCC,tincexc_A_BCS,tincexc_A_BEQ,tincexc_A_BGE,tincexc_A_BGT,tincexc_A_BHI,
         tincexc_A_BLE,tincexc_A_BLS,tincexc_A_BLT,tincexc_A_BMI,tincexc_A_BNE,tincexc_A_BPL,tincexc_A_BVC,tincexc_A_BVS,
         tincexc_A_BCHG,tincexc_A_BCLR,tincexc_A_BRA,tincexc_A_BSET,tincexc_A_BSR,tincexc_A_BTST,tincexc_A_CHK,
         tincexc_A_CLR,tincexc_A_CMP,tincexc_A_CMPA,tincexc_A_CMPI,tincexc_A_CMPM,tincexc_A_DBCC,tincexc_A_DBCS,tincexc_A_DBEQ,tincexc_A_DBGE,
         tincexc_A_DBGT,tincexc_A_DBHI,tincexc_A_DBLE,tincexc_A_DBLS,tincexc_A_DBLT,tincexc_A_DBMI,tincexc_A_DBNE,tincexc_A_DBRA,
         tincexc_A_DBPL,tincexc_A_DBT,tincexc_A_DBVC,tincexc_A_DBVS,tincexc_A_DBF,tincexc_A_DIVS,tincexc_A_DIVU,
         tincexc_A_EOR,tincexc_A_EORI,tincexc_A_EXG,tincexc_A_ILLEGAL,tincexc_A_EXT,tincexc_A_JMP,tincexc_A_JSR,
         tincexc_A_LEA,tincexc_A_LINK,tincexc_A_LSL,tincexc_A_LSR,tincexc_A_MOVE,tincexc_A_MOVEA,tincexc_A_MOVEI,tincexc_A_MOVEQ,
         tincexc_A_MOVEM,tincexc_A_MOVEP,tincexc_A_MULS,tincexc_A_MULU,tincexc_A_NBCD,tincexc_A_NEG,tincexc_A_NEGX,
         tincexc_A_NOP,tincexc_A_NOT,tincexc_A_OR,tincexc_A_ORI,tincexc_A_PEA,tincexc_A_ROL,tincexc_A_ROR,tincexc_A_ROXL,
         tincexc_A_ROXR,tincexc_A_RTR,tincexc_A_RTS,tincexc_A_SBCD,tincexc_A_SCC,tincexc_A_SCS,tincexc_A_SEQ,tincexc_A_SGE,
         tincexc_A_SGT,tincexc_A_SHI,tincexc_A_SLE,tincexc_A_SLS,tincexc_A_SLT,tincexc_A_SMI,tincexc_A_SNE,
         tincexc_A_SPL,tincexc_A_ST,tincexc_A_SVC,tincexc_A_SVS,tincexc_A_SF,tincexc_A_SUB,tincexc_A_SUBA,tincexc_A_SUBI,tincexc_A_SUBQ,
         tincexc_A_SUBX,tincexc_A_SWAP,tincexc_A_TAS,tincexc_A_TRAP,tincexc_A_TRAPV,tincexc_A_TST,tincexc_A_UNLK,
         tincexc_A_RTE,tincexc_A_RESET,tincexc_A_STOP,
         { MC68010 instructions }
         tincexc_A_BKPT,tincexc_A_MOVEC,tincexc_A_MOVES,tincexc_A_RTD,
         { MC68020 instructions }
         tincexc_A_BFCHG,tincexc_A_BFCLR,tincexc_A_BFEXTS,tincexc_A_BFEXTU,tincexc_A_BFFFO,
         tincexc_A_BFINS,tincexc_A_BFSET,tincexc_A_BFTST,tincexc_A_CALLM,tincexc_A_CAS,tincexc_A_CAS2,
         tincexc_A_CHK2,tincexc_A_CMP2,tincexc_A_DIVSL,tincexc_A_DIVUL,tincexc_A_EXTB,tincexc_A_PACK,tincexc_A_RTM,
         tincexc_A_TRAPCC,tincexc_A_TRACS,tincexc_A_TRAPEQ,tincexc_A_TRAPF,tincexc_A_TRAPGE,tincexc_A_TRAPGT,
         tincexc_A_TRAPHI,tincexc_A_TRAPLE,tincexc_A_TRAPLS,tincexc_A_TRAPLT,tincexc_A_TRAPMI,tincexc_A_TRAPNE,
         tincexc_A_TRAPPL,tincexc_A_TRAPT,tincexc_A_TRAPVC,tincexc_A_TRAPVS,tincexc_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tincexc_A_FABS,tincexc_A_FADD,
         tincexc_A_FBEQ,tincexc_A_FBNE,tincexc_A_FBNGT,tincexc_A_FBGT,tincexc_A_FBGE,tincexc_A_FBNGE,
         tincexc_A_FBLT,tincexc_A_FBNLT,tincexc_A_FBLE,tincexc_A_FBGL,tincexc_A_FBNGL,tincexc_A_FBGLE,tincexc_A_FBNGLE,
         tincexc_A_FDBEQ,tincexc_A_FDBNE,tincexc_A_FDBGT,tincexc_A_FDBNGT,tincexc_A_FDBGE,tincexc_A_FDBNGE,
         tincexc_A_FDBLT,tincexc_A_FDBNLT,tincexc_A_FDBLE,tincexc_A_FDBGL,tincexc_A_FDBNGL,tincexc_A_FDBGLE,tincexc_A_FBDNGLE,
         tincexc_A_FSEQ,tincexc_A_FSNE,tincexc_A_FSGT,tincexc_A_FSNGT,tincexc_A_FSGE,tincexc_A_FSNGE,
         tincexc_A_FSLT,tincexc_A_FSNLT,tincexc_A_FSLE,tincexc_A_FSGL,tincexc_A_FSNGL,tincexc_A_FSGLE,tincexc_A_FSNGLE,
         tincexc_A_FCMP,tincexc_A_FDIV,tincexc_A_FMOVE,tincexc_A_FMOVEM,
         tincexc_A_FMUL,tincexc_A_FNEG,tincexc_A_FNOP,tincexc_A_FSQRT,tincexc_A_FSUB,tincexc_A_FSGLDIV,
         tincexc_A_FSFLMUL,tincexc_A_FTST,
         tincexc_A_FTRAPEQ,tincexc_A_FTRAPNE,tincexc_A_FTRAPGT,tincexc_A_FTRAPNGT,tincexc_A_FTRAPGE,tincexc_A_FTRAPNGE,
         tincexc_A_FTRAPLT,tincexc_A_FTRAPNLT,tincexc_A_FTRAPLE,tincexc_A_FTRAPGL,tincexc_A_FTRAPNGL,tincexc_A_FTRAPGLE,tincexc_A_FTRAPNGLE,
         { Protected instructions }
         tincexc_A_CPRESTORE,tincexc_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tincexc_A_FRESTORE,tincexc_A_FSAVE,tincexc_A_PFLUSH,tincexc_A_PFLUSHA,tincexc_A_PLOAD,tincexc_A_PMOVE,tincexc_A_PTEST,
         { Useful for assembly langage output }
         tincexc_A_LABEL,tincexc_A_NONE);



type
  tincexc_topset = set of tincexc_tasmop;
  tincexc_tsmallset = set of tincexc_tsmallenum;


 procedure tincexc_CheckPassed(passed:boolean);
 begin
   if passed then
     WriteLn('Success.')
   else
     begin
       WriteLn('Failure.');
       Halt(1);
     end;
 end;


  Procedure tincexc_SetTestIncludeOne;
    var
     op : tincexc_tasmop;
     oplist: set of tincexc_tasmop;
  Begin
    Write('Include Large Set element testing (LOC_REFERENCE/LOC_REFERENCE)...');
    op:=tincexc_A_LABEL;
    oplist:=[];
    Include(oplist, op);
    tincexc_CheckPassed(oplist = [tincexc_A_LABEL]);
  end;


  function tincexc_get_large_enum : tincexc_tasmop;
   begin
     tincexc_get_large_enum := tincexc_A_LABEL;
   end;

  Procedure tincexc_SetTestIncludeTwo;
    var
     oplist: set of tincexc_tasmop;
  Begin
    Write('Include Large Set element testing (LOC_REFERENCE/LOC_REGISTER)...');
    oplist:=[];
    Include(oplist, tincexc_get_large_enum);
    tincexc_CheckPassed(oplist = [tincexc_A_LABEL]);
  end;


 Procedure tincexc_SetTestIncludeThree;
  var
   small_enum : tincexc_tsmallenum;
   small_set : set of tincexc_tsmallenum;
 begin
   Write('Include Small Set element testing (LOC_REFERENCE/LOC_REFERENCE)...');
   small_enum := tincexc_dop;
   small_set := [];
   Include(small_set, small_enum);
   tincexc_CheckPassed(small_set = [tincexc_DOP]);
 end;


 function tincexc_get_small_enum : tincexc_tsmallenum;
  begin
    tincexc_get_small_enum := tincexc_dop;
  end;

 Procedure tincexc_SetTestIncludeFour;
  var
   small_enum : tincexc_tsmallenum;
   small_set : set of tincexc_tsmallenum;
 begin
   Write('Include Small Set element testing (LOC_REFERENCE/LOC_REGISTER)...');
   small_enum := tincexc_dop;
   small_set := [];
   Include(small_set, tincexc_get_small_enum);
   tincexc_CheckPassed(small_set = [tincexc_DOP]);
 end;


  Procedure tincexc_SetTestExcludeOne;
    var
     op : tincexc_tasmop;
     oplist: set of tincexc_tasmop;
  Begin
    Write('Exclude Large Set element testing (LOC_REFERENCE/LOC_REFERENCE)...');
    op:=tincexc_A_RTE;
    oplist:=[tincexc_A_RTE,tincexc_A_LABEL,tincexc_A_STOP];
    Exclude(oplist, op);
    tincexc_CheckPassed(oplist = [tincexc_A_LABEL,tincexc_A_STOP]);
  end;

 Procedure tincexc_SetTestExcludeTwo;
  var
   small_enum : tincexc_tsmallenum;
   small_set : set of tincexc_tsmallenum;
 begin
   Write('Exclude Small Set element testing (LOC_REFERENCE/LOC_REFERENCE)...');
   small_enum := tincexc_dop;
   small_set := [tincexc_dc,tincexc_dop,tincexc_dp,tincexc_dq,tincexc_dm];
   Exclude(small_set, small_enum);
   tincexc_CheckPassed(small_set = [tincexc_dc,tincexc_dp,tincexc_dq,tincexc_dm]);
 end;


 function tincexc_get_small_enum_two : tincexc_tsmallenum;
  begin
    tincexc_get_small_enum_two := tincexc_dop;
  end;

 Procedure tincexc_SetTestExcludeThree;
  var
   small_set : set of tincexc_tsmallenum;
 begin
   Write('Exclude Small Set element testing (LOC_REFERENCE/LOC_REGISTER)...');
   small_set := [tincexc_dc,tincexc_dop,tincexc_dp,tincexc_dq,tincexc_dm];
   Exclude(small_set, tincexc_get_small_enum);
   tincexc_CheckPassed(small_set = [tincexc_dc,tincexc_dp,tincexc_dq,tincexc_dm]);
 end;

  function tincexc_get_large_enum_two : tincexc_tasmop;
   begin
     tincexc_get_large_enum_two := tincexc_A_LABEL;
   end;

  Procedure tincexc_SetTestExcludeFour;
    var
     oplist: set of tincexc_tasmop;
  Begin
    Write('Exclude Large Set element testing (LOC_REFERENCE/LOC_REGISTER)...');
    oplist:=[tincexc_A_LABEL,tincexc_A_STOP];
    Exclude(oplist, tincexc_get_large_enum_two);
    tincexc_CheckPassed(oplist = [tincexc_A_STOP]);
  end;



{$pop}

begin

{ Case tb0721.pp }
{$push}

{$H+}
{$R-}
begin
  tb0721_Mark := [5,11]; { don't throw a range check error here if range checking is off }
  for tb0721_x in tb0721_Mark do write(tb0721_x,' IN Mark');
  writeln;
end;
{$pop}

{ Case tb_sets_objfpc_run_01.pp }
{$push}
{$push}

{$pop}
{$push}

{$pop}
begin
  { Case tw0866.pp }
  {$push}

  begin
tw0866_f2:=tw0866_f2+[tb_sets_objfpc_run_01_t2];
 tw0866_f2:=tw0866_f2+[tb_sets_objfpc_run_01_t1];
 tw0866_f:=tw0866_f+[tb_sets_objfpc_run_01_tse]; // compiler says that set elements are not compatible
 { f3:=[tm1];}
  end;
  {$pop}

  { Case tw17846.pp }
  {$push}

  begin
tw17846_i := tw17846_intvalue1 or tw17846_intvalue3;
  tw17846_t := tw17846_i;
  if tw17846_t<>[tb_sets_objfpc_run_01_value1,tb_sets_objfpc_run_01_value3] then
    halt(1);
  tw17846_i:=0;
  tw17846_i:=tw17846_t;
  if tw17846_i<>(tw17846_intvalue1 or tw17846_intvalue3) then
    halt(2);
  end;
  {$pop}

end;
{$pop}

{ Case tincexc.pp }
{$push}

Begin
  tincexc_SetTestIncludeOne;
  tincexc_SetTestIncludeTwo;
  tincexc_SetTestIncludeThree;
  tincexc_SetTestIncludeFour;
  tincexc_SetTestExcludeOne;
  tincexc_SetTestExcludeTwo;
  tincexc_SetTestExcludeThree;
  tincexc_SetTestExcludeFour;
end;
{$pop}

end.
