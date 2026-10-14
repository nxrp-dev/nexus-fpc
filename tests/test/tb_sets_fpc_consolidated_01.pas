{ Consolidated sets regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tpushpop3.pas }
{$push}


type
  tpushpop3_TTest = (tpushpop3_tOne, tpushpop3_tTwo, tpushpop3_tThree);

{$PackSet 1}
  tpushpop3_TTestSet1 = set of tpushpop3_TTest;
{$Push}
{$PackSet 2}
  tpushpop3_TTestSet2 = set of tpushpop3_TTest;
{$Pop}
  tpushpop3_TTestSet3 = set of tpushpop3_TTest;


{$pop}

{ Case tset2.pas }
{$push}
(*********************************************************************)
(* Copyright (C) 1998, Carl Eric Codere                              *)
(*********************************************************************)
(* FPC (Free Pascal compiler) testsuite: SETS                        *)
(*   Tests the following: in, +, -, *, assignments.                  *)
(*      for small sets amd large sets, both with constants           *)
(*      and variables.                                               *)
(*********************************************************************)

const
  tset2_failed: boolean = false;

type
       tset2_myenum = (tset2_dA,tset2_dB,tset2_dC,tset2_dd,tset2_dedf,tset2_dg,tset2_dh,tset2_di,tset2_dj,tset2_dk,tset2_dl,tset2_dm,tset2_dn);
       tset2_tasmop = (tset2_A_ABCD,
         tset2_A_ADD,tset2_A_ADDA,tset2_A_ADDI,tset2_A_ADDQ,tset2_A_ADDX,tset2_A_AND,tset2_A_ANDI,
         tset2_A_ASL,tset2_A_ASR,tset2_A_BCC,tset2_A_BCS,tset2_A_BEQ,tset2_A_BGE,tset2_A_BGT,tset2_A_BHI,
         tset2_A_BLE,tset2_A_BLS,tset2_A_BLT,tset2_A_BMI,tset2_A_BNE,tset2_A_BPL,tset2_A_BVC,tset2_A_BVS,
         tset2_A_BCHG,tset2_A_BCLR,tset2_A_BRA,tset2_A_BSET,tset2_A_BSR,tset2_A_BTST,tset2_A_CHK,
         tset2_A_CLR,tset2_A_CMP,tset2_A_CMPA,tset2_A_CMPI,tset2_A_CMPM,tset2_A_DBCC,tset2_A_DBCS,tset2_A_DBEQ,tset2_A_DBGE,
         tset2_A_DBGT,tset2_A_DBHI,tset2_A_DBLE,tset2_A_DBLS,tset2_A_DBLT,tset2_A_DBMI,tset2_A_DBNE,tset2_A_DBRA,
         tset2_A_DBPL,tset2_A_DBT,tset2_A_DBVC,tset2_A_DBVS,tset2_A_DBF,tset2_A_DIVS,tset2_A_DIVU,
         tset2_A_EOR,tset2_A_EORI,tset2_A_EXG,tset2_A_ILLEGAL,tset2_A_EXT,tset2_A_JMP,tset2_A_JSR,
         tset2_A_LEA,tset2_A_LINK,tset2_A_LSL,tset2_A_LSR,tset2_A_MOVE,tset2_A_MOVEA,tset2_A_MOVEI,tset2_A_MOVEQ,
         tset2_A_MOVEM,tset2_A_MOVEP,tset2_A_MULS,tset2_A_MULU,tset2_A_NBCD,tset2_A_NEG,tset2_A_NEGX,
         tset2_A_NOP,tset2_A_NOT,tset2_A_OR,tset2_A_ORI,tset2_A_PEA,tset2_A_ROL,tset2_A_ROR,tset2_A_ROXL,
         tset2_A_ROXR,tset2_A_RTR,tset2_A_RTS,tset2_A_SBCD,tset2_A_SCC,tset2_A_SCS,tset2_A_SEQ,tset2_A_SGE,
         tset2_A_SGT,tset2_A_SHI,tset2_A_SLE,tset2_A_SLS,tset2_A_SLT,tset2_A_SMI,tset2_A_SNE,
         tset2_A_SPL,tset2_A_ST,tset2_A_SVC,tset2_A_SVS,tset2_A_SF,tset2_A_SUB,tset2_A_SUBA,tset2_A_SUBI,tset2_A_SUBQ,
         tset2_A_SUBX,tset2_A_SWAP,tset2_A_TAS,tset2_A_TRAP,tset2_A_TRAPV,tset2_A_TST,tset2_A_UNLK,
         tset2_A_RTE,tset2_A_RESET,tset2_A_STOP,
         { MC68010 instructions }
         tset2_A_BKPT,tset2_A_MOVEC,tset2_A_MOVES,tset2_A_RTD,
         { MC68020 instructions }
         tset2_A_BFCHG,tset2_A_BFCLR,tset2_A_BFEXTS,tset2_A_BFEXTU,tset2_A_BFFFO,
         tset2_A_BFINS,tset2_A_BFSET,tset2_A_BFTST,tset2_A_CALLM,tset2_A_CAS,tset2_A_CAS2,
         tset2_A_CHK2,tset2_A_CMP2,tset2_A_DIVSL,tset2_A_DIVUL,tset2_A_EXTB,tset2_A_PACK,tset2_A_RTM,
         tset2_A_TRAPCC,tset2_A_TRACS,tset2_A_TRAPEQ,tset2_A_TRAPF,tset2_A_TRAPGE,tset2_A_TRAPGT,
         tset2_A_TRAPHI,tset2_A_TRAPLE,tset2_A_TRAPLS,tset2_A_TRAPLT,tset2_A_TRAPMI,tset2_A_TRAPNE,
         tset2_A_TRAPPL,tset2_A_TRAPT,tset2_A_TRAPVC,tset2_A_TRAPVS,tset2_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tset2_A_FABS,tset2_A_FADD,
         tset2_A_FBEQ,tset2_A_FBNE,tset2_A_FBNGT,tset2_A_FBGT,tset2_A_FBGE,tset2_A_FBNGE,
         tset2_A_FBLT,tset2_A_FBNLT,tset2_A_FBLE,tset2_A_FBGL,tset2_A_FBNGL,tset2_A_FBGLE,tset2_A_FBNGLE,
         tset2_A_FDBEQ,tset2_A_FDBNE,tset2_A_FDBGT,tset2_A_FDBNGT,tset2_A_FDBGE,tset2_A_FDBNGE,
         tset2_A_FDBLT,tset2_A_FDBNLT,tset2_A_FDBLE,tset2_A_FDBGL,tset2_A_FDBNGL,tset2_A_FDBGLE,tset2_A_FBDNGLE,
         tset2_A_FSEQ,tset2_A_FSNE,tset2_A_FSGT,tset2_A_FSNGT,tset2_A_FSGE,tset2_A_FSNGE,
         tset2_A_FSLT,tset2_A_FSNLT,tset2_A_FSLE,tset2_A_FSGL,tset2_A_FSNGL,tset2_A_FSGLE,tset2_A_FSNGLE,
         tset2_A_FCMP,tset2_A_FDIV,tset2_A_FMOVE,tset2_A_FMOVEM,
         tset2_A_FMUL,tset2_A_FNEG,tset2_A_FNOP,tset2_A_FSQRT,tset2_A_FSUB,tset2_A_FSGLDIV,
         tset2_A_FSFLMUL,tset2_A_FTST,
         tset2_A_FTRAPEQ,tset2_A_FTRAPNE,tset2_A_FTRAPGT,tset2_A_FTRAPNGT,tset2_A_FTRAPGE,tset2_A_FTRAPNGE,
         tset2_A_FTRAPLT,tset2_A_FTRAPNLT,tset2_A_FTRAPLE,tset2_A_FTRAPGL,tset2_A_FTRAPNGL,tset2_A_FTRAPGLE,tset2_A_FTRAPNGLE,
         { Protected instructions }
         tset2_A_CPRESTORE,tset2_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tset2_A_FRESTORE,tset2_A_FSAVE,tset2_A_PFLUSH,tset2_A_PFLUSHA,tset2_A_PLOAD,tset2_A_PMOVE,tset2_A_PTEST,
         { Useful for assembly langage output }
         tset2_A_LABEL,tset2_A_NONE);


Function tset2_X(y:tset2_myenum): tset2_myenum;
Begin
 tset2_x:=y;
end;


Procedure tset2_SecondInSets;
{ SET_IN_BYTE TESTS }
var
 op,op2 : tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 Write('TESTING SET_IN_BYTE:');
 tset2_oplist:=[];
 op:=tset2_A_JSR;
 if tset2_A_JSR in tset2_oplist then
  begin
    WriteLn('A_JSR in [] FAILED.');
    tset2_failed := true
  end
 else
  Writeln('A_JSR in [] PASSED.');
 if op in tset2_oplist then
  begin
    WriteLn('op(A_JSR) in [] FAILED.');
    tset2_failed := true
  end
 else
  Writeln('op (A_JSR) in [] PASSED.');
 op:=tset2_A_MOVE;
 tset2_oplist:=tset2_oplist+[tset2_A_MOVE];
 if tset2_A_MOVE in tset2_oplist then
  WriteLn('A_MOVE in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([]+[A_MOVE]) FAILED.');
    tset2_failed := true;
  end;
 if op in tset2_oplist then
  WriteLn('op(A_MOVE) in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('op(A_MOVE) in ([]+[A_MOVE]) FAILED.');
    tset2_failed := true;
  end;
  op:=tset2_A_MOVE;
  tset2_oplist:=[];
  tset2_oplist:=[tset2_A_SUB]+[op];
  op2:=tset2_A_MOVE;
 if tset2_A_MOVE in tset2_oplist then
  WriteLn('A_MOVE in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2_failed := true
  end;
 if op2 in tset2_oplist then
  WriteLn('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2_failed := true
  end;
end;

Procedure tset2_SetSetByte;
{ SET_SET_BYTE }
var
 op : tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 Write('TESTING SET_SET_BYTE(1):');
 op:=tset2_A_LABEL;
 tset2_oplist:=[];
 tset2_oplist:=tset2_oplist+[op];
 if op in tset2_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2_failed := true
 end;
 Write('TESTING INCLUDE:');
 op:=tset2_A_RTE;
 include(tset2_oplist,op);
 if op in tset2_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2_failed := true;
 end;
end;


Procedure tset2_SetAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_A_MOVE]+[tset2_A_JSR];
 op2list:=[tset2_A_LABEL];
 tset2_oplist:=op2list+tset2_oplist;
 if tset2_A_MOVE in tset2_oplist then
  if tset2_A_LABEL in tset2_oplist then
   if tset2_A_JSR in tset2_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2_failed := true
    end
  else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2_failed := true
    end
 else
  begin
    WriteLn('TESTING SET_ADD_SETS: FAILED.');
    tset2_failed := true
  end;
end;

Procedure tset2_SetSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_A_MOVE]+[tset2_A_JSR];
 op2list:=[tset2_A_MOVE]+[tset2_A_JSR];
 tset2_oplist:=op2list-tset2_oplist;
 if (tset2_A_MOVE in tset2_oplist) or (tset2_A_LABEL in tset2_oplist) or (tset2_A_JSR in tset2_oplist) then
   begin
    WriteLn('TESTING SET_SUB_SETS: FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING SET_SUB_SETS: PASSED.');
 tset2_oplist := [tset2_A_MOVE,tset2_A_RTE];
 exclude(tset2_oplist,tset2_A_MOVE);
 if (tset2_A_MOVE in tset2_oplist) then
  begin
    WriteLn('TESTING EXCLUDE: FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING EXCLUDE: PASSED.')
end;

Procedure tset2_SetCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_A_MOVE]+[tset2_A_JSR];
 op2list:=[tset2_A_MOVE]+[tset2_A_JSR];
 if tset2_oplist=op2list then
  WriteLn('TESTING SET_COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING SET_COMP_SETS(1): FAILED.');
    tset2_failed := true
  end;
 tset2_oplist:=[tset2_A_MOVE];
 if tset2_oplist=op2list then
  begin
    WriteLn('TESTING SET_COMP_SETS(2): FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING SET_COMP_SETS(2): PASSED.');
end;

Procedure tset2_SetMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2_tasmop;
 tset2_oplist: set of tset2_tasmop;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_A_MOVE]+[tset2_A_JSR];
 op2list:=[tset2_A_MOVE];
 tset2_oplist:=tset2_oplist*op2list;
 if tset2_A_JSR in tset2_oplist then
  begin
    WriteLn('TESTING SET_MUL_SETS(1): FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING SET_MUL_SETS(1): PASSED.');
 if tset2_A_MOVE in tset2_oplist  then
  WriteLn('TESTING SET_MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING SET_MUL_SETS(2): FAILED.');
    tset2_failed := true
  end;
end;

{------------------------------ TESTS FOR SMALL VALUES ---------------------}
Procedure tset2_SmallInSets;
{ SET_IN_BYTE TESTS }
var
 op : tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 Write('TESTING IN_BYTE:');
 tset2_oplist:=[];
 op:=tset2_Dn;
 if op in tset2_oplist then
  begin
    WriteLn(' FAILED.');
    tset2_failed := true
  end;
 op:=tset2_dm;
 tset2_oplist:=tset2_oplist+[tset2_Dm];
 if op in tset2_oplist then
  WriteLn(' PASSED.')
 else
   begin
    WriteLn(' FAILED.');
    tset2_failed := true
  end;
end;

Procedure tset2_SmallSetByte;
{ SET_SET_BYTE }
var
 op : tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 Write('TESTING SET_BYTE(1):');
 op:=tset2_DA;
 tset2_oplist:=[];
 tset2_oplist:=tset2_oplist+[op];
 if op in tset2_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2_failed := true;
 end;
end;


Procedure tset2_SmallAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_DA]+[tset2_DC];
 op2list:=[tset2_DB];
 tset2_oplist:=op2list+tset2_oplist;
 if tset2_DA in tset2_oplist then
  if tset2_DC in tset2_oplist then
   if tset2_DB in tset2_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING ADD_SETS: FAILED.');
      tset2_failed := true
    end
  else
   begin
     WriteLn('TESTING ADD_SETS: FAILED.');
     tset2_failed := true
   end
 else
  begin
    WriteLn('TESTING ADD_SETS: FAILED.');
    tset2_failed := true
  end;
end;

Procedure tset2_SmallSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_DA]+[tset2_DC];
 op2list:=[tset2_DA]+[tset2_DC];
 tset2_oplist:=op2list-tset2_oplist;
 if (tset2_DA in tset2_oplist) or (tset2_DB in tset2_oplist) or (tset2_DC in tset2_oplist) then
  begin
    WriteLn('TESTING SUB_SETS: FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING SUB_SETS: PASSED.')
end;

Procedure tset2_SmallCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_DA]+[tset2_DC];
 op2list:=[tset2_DA]+[tset2_DC];
 if tset2_oplist=op2list then
  WriteLn('TESTING COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING COMP_SETS(1): FAILED.');
    tset2_failed := true
  end;
 tset2_oplist:=[tset2_DA];
 if tset2_oplist=op2list then
  begin
    WriteLn('TESTING COMP_SETS(2): FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING COMP_SETS(2): PASSED.');
end;

Procedure tset2_SmallMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2_myenum;
 tset2_oplist: set of tset2_myenum;
Begin
 op2list:=[];
 tset2_oplist:=[];
 tset2_oplist:=[tset2_DA]+[tset2_DC];
 op2list:=[tset2_DA];
 tset2_oplist:=tset2_oplist*op2list;
 if tset2_DC in tset2_oplist then
  begin
    WriteLn('TESTING MUL_SETS(1): FAILED.');
    tset2_failed := true
  end
 else
  WriteLn('TESTING MUL_SETS(1): PASSED.');
 if tset2_DA in tset2_oplist  then
  WriteLn('TESTING MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING MUL_SETS(2): FAILED.');
    tset2_failed := true
  end;
end;

const
 tset2_b: tset2_myenum = (tset2_dA);
var
 tset2_enum: set of tset2_myenum;
 tset2_oplist: set of tset2_tasmop;
 tset2_l : word;

{$pop}

{ Case tset2a.pas }
{$push}
(*********************************************************************)
(* Copyright (C) 1998, Carl Eric Codere                              *)
(*********************************************************************)
(* FPC (Free Pascal compiler) testsuite: SETS                        *)
(*   Tests the following: in, +, -, *, assignments.                  *)
(*      for small sets amd large sets, both with constants           *)
(*      and variables.                                               *)
(*********************************************************************)

{$packset 1}

const
  tset2a_failed: boolean = false;

type
       tset2a_myenum = (tset2a_dA:=8,tset2a_dB,tset2a_dC,tset2a_dd,tset2a_dedf,tset2a_dg,tset2a_dh,tset2a_di,tset2a_dj,tset2a_dk,tset2a_dl,tset2a_dm,tset2a_dn);
       tset2a_tasmop = (tset2a_A_ABCD:=16,
         tset2a_A_ADD,tset2a_A_ADDA,tset2a_A_ADDI,tset2a_A_ADDQ,tset2a_A_ADDX,tset2a_A_AND,tset2a_A_ANDI,
         tset2a_A_ASL,tset2a_A_ASR,tset2a_A_BCC,tset2a_A_BCS,tset2a_A_BEQ,tset2a_A_BGE,tset2a_A_BGT,tset2a_A_BHI,
         tset2a_A_BLE,tset2a_A_BLS,tset2a_A_BLT,tset2a_A_BMI,tset2a_A_BNE,tset2a_A_BPL,tset2a_A_BVC,tset2a_A_BVS,
         tset2a_A_BCHG,tset2a_A_BCLR,tset2a_A_BRA,tset2a_A_BSET,tset2a_A_BSR,tset2a_A_BTST,tset2a_A_CHK,
         tset2a_A_CLR,tset2a_A_CMP,tset2a_A_CMPA,tset2a_A_CMPI,tset2a_A_CMPM,tset2a_A_DBCC,tset2a_A_DBCS,tset2a_A_DBEQ,tset2a_A_DBGE,
         tset2a_A_DBGT,tset2a_A_DBHI,tset2a_A_DBLE,tset2a_A_DBLS,tset2a_A_DBLT,tset2a_A_DBMI,tset2a_A_DBNE,tset2a_A_DBRA,
         tset2a_A_DBPL,tset2a_A_DBT,tset2a_A_DBVC,tset2a_A_DBVS,tset2a_A_DBF,tset2a_A_DIVS,tset2a_A_DIVU,
         tset2a_A_EOR,tset2a_A_EORI,tset2a_A_EXG,tset2a_A_ILLEGAL,tset2a_A_EXT,tset2a_A_JMP,tset2a_A_JSR,
         tset2a_A_LEA,tset2a_A_LINK,tset2a_A_LSL,tset2a_A_LSR,tset2a_A_MOVE,tset2a_A_MOVEA,tset2a_A_MOVEI,tset2a_A_MOVEQ,
         tset2a_A_MOVEM,tset2a_A_MOVEP,tset2a_A_MULS,tset2a_A_MULU,tset2a_A_NBCD,tset2a_A_NEG,tset2a_A_NEGX,
         tset2a_A_NOP,tset2a_A_NOT,tset2a_A_OR,tset2a_A_ORI,tset2a_A_PEA,tset2a_A_ROL,tset2a_A_ROR,tset2a_A_ROXL,
         tset2a_A_ROXR,tset2a_A_RTR,tset2a_A_RTS,tset2a_A_SBCD,tset2a_A_SCC,tset2a_A_SCS,tset2a_A_SEQ,tset2a_A_SGE,
         tset2a_A_SGT,tset2a_A_SHI,tset2a_A_SLE,tset2a_A_SLS,tset2a_A_SLT,tset2a_A_SMI,tset2a_A_SNE,
         tset2a_A_SPL,tset2a_A_ST,tset2a_A_SVC,tset2a_A_SVS,tset2a_A_SF,tset2a_A_SUB,tset2a_A_SUBA,tset2a_A_SUBI,tset2a_A_SUBQ,
         tset2a_A_SUBX,tset2a_A_SWAP,tset2a_A_TAS,tset2a_A_TRAP,tset2a_A_TRAPV,tset2a_A_TST,tset2a_A_UNLK,
         tset2a_A_RTE,tset2a_A_RESET,tset2a_A_STOP,
         { MC68010 instructions }
         tset2a_A_BKPT,tset2a_A_MOVEC,tset2a_A_MOVES,tset2a_A_RTD,
         { MC68020 instructions }
         tset2a_A_BFCHG,tset2a_A_BFCLR,tset2a_A_BFEXTS,tset2a_A_BFEXTU,tset2a_A_BFFFO,
         tset2a_A_BFINS,tset2a_A_BFSET,tset2a_A_BFTST,tset2a_A_CALLM,tset2a_A_CAS,tset2a_A_CAS2,
         tset2a_A_CHK2,tset2a_A_CMP2,tset2a_A_DIVSL,tset2a_A_DIVUL,tset2a_A_EXTB,tset2a_A_PACK,tset2a_A_RTM,
         tset2a_A_TRAPCC,tset2a_A_TRACS,tset2a_A_TRAPEQ,tset2a_A_TRAPF,tset2a_A_TRAPGE,tset2a_A_TRAPGT,
         tset2a_A_TRAPHI,tset2a_A_TRAPLE,tset2a_A_TRAPLS,tset2a_A_TRAPLT,tset2a_A_TRAPMI,tset2a_A_TRAPNE,
         tset2a_A_TRAPPL,tset2a_A_TRAPT,tset2a_A_TRAPVC,tset2a_A_TRAPVS,tset2a_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tset2a_A_FABS,tset2a_A_FADD,
         tset2a_A_FBEQ,tset2a_A_FBNE,tset2a_A_FBNGT,tset2a_A_FBGT,tset2a_A_FBGE,tset2a_A_FBNGE,
         tset2a_A_FBLT,tset2a_A_FBNLT,tset2a_A_FBLE,tset2a_A_FBGL,tset2a_A_FBNGL,tset2a_A_FBGLE,tset2a_A_FBNGLE,
         tset2a_A_FDBEQ,tset2a_A_FDBNE,tset2a_A_FDBGT,tset2a_A_FDBNGT,tset2a_A_FDBGE,tset2a_A_FDBNGE,
         tset2a_A_FDBLT,tset2a_A_FDBNLT,tset2a_A_FDBLE,tset2a_A_FDBGL,tset2a_A_FDBNGL,tset2a_A_FDBGLE,tset2a_A_FBDNGLE,
         tset2a_A_FSEQ,tset2a_A_FSNE,tset2a_A_FSGT,tset2a_A_FSNGT,tset2a_A_FSGE,tset2a_A_FSNGE,
         tset2a_A_FSLT,tset2a_A_FSNLT,tset2a_A_FSLE,tset2a_A_FSGL,tset2a_A_FSNGL,tset2a_A_FSGLE,tset2a_A_FSNGLE,
         tset2a_A_FCMP,tset2a_A_FDIV,tset2a_A_FMOVE,tset2a_A_FMOVEM,
         tset2a_A_FMUL,tset2a_A_FNEG,tset2a_A_FNOP,tset2a_A_FSQRT,tset2a_A_FSUB,tset2a_A_FSGLDIV,
         tset2a_A_FSFLMUL,tset2a_A_FTST,
         tset2a_A_FTRAPEQ,tset2a_A_FTRAPNE,tset2a_A_FTRAPGT,tset2a_A_FTRAPNGT,tset2a_A_FTRAPGE,tset2a_A_FTRAPNGE,
         tset2a_A_FTRAPLT,tset2a_A_FTRAPNLT,tset2a_A_FTRAPLE,tset2a_A_FTRAPGL,tset2a_A_FTRAPNGL,tset2a_A_FTRAPGLE,tset2a_A_FTRAPNGLE,
         { Protected instructions }
         tset2a_A_CPRESTORE,tset2a_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tset2a_A_FRESTORE,tset2a_A_FSAVE,tset2a_A_PFLUSH,tset2a_A_PFLUSHA,tset2a_A_PLOAD,tset2a_A_PMOVE,tset2a_A_PTEST,
         { Useful for assembly langage output }
         tset2a_A_LABEL,tset2a_A_NONE);


Function tset2a_X(y:tset2a_myenum): tset2a_myenum;
Begin
 tset2a_x:=y;
end;


Procedure tset2a_SecondInSets;
{ SET_IN_BYTE TESTS }
var
 op,op2 : tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 Write('TESTING SET_IN_BYTE:');
 tset2a_oplist:=[];
 op:=tset2a_A_JSR;
 if tset2a_A_JSR in tset2a_oplist then
  begin
    WriteLn('A_JSR in [] FAILED.');
    tset2a_failed := true
  end
 else
  Writeln('A_JSR in [] PASSED.');
 if op in tset2a_oplist then
  begin
    WriteLn('op(A_JSR) in [] FAILED.');
    tset2a_failed := true
  end
 else
  Writeln('op (A_JSR) in [] PASSED.');
 op:=tset2a_A_MOVE;
 tset2a_oplist:=tset2a_oplist+[tset2a_A_MOVE];
 if tset2a_A_MOVE in tset2a_oplist then
  WriteLn('A_MOVE in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([]+[A_MOVE]) FAILED.');
    tset2a_failed := true;
  end;
 if op in tset2a_oplist then
  WriteLn('op(A_MOVE) in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('op(A_MOVE) in ([]+[A_MOVE]) FAILED.');
    tset2a_failed := true;
  end;
  op:=tset2a_A_MOVE;
  tset2a_oplist:=[];
  tset2a_oplist:=[tset2a_A_SUB]+[op];
  op2:=tset2a_A_MOVE;
 if tset2a_A_MOVE in tset2a_oplist then
  WriteLn('A_MOVE in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2a_failed := true
  end;
 if op2 in tset2a_oplist then
  WriteLn('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2a_failed := true
  end;
end;

Procedure tset2a_SetSetByte;
{ SET_SET_BYTE }
var
 op : tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 Write('TESTING SET_SET_BYTE(1):');
 op:=tset2a_A_LABEL;
 tset2a_oplist:=[];
 tset2a_oplist:=tset2a_oplist+[op];
 if op in tset2a_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2a_failed := true
 end;
 Write('TESTING INCLUDE:');
 op:=tset2a_A_RTE;
 include(tset2a_oplist,op);
 if op in tset2a_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2a_failed := true;
 end;
end;


Procedure tset2a_SetAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 op2list:=[tset2a_A_LABEL];
 tset2a_oplist:=op2list+tset2a_oplist;
 if tset2a_A_MOVE in tset2a_oplist then
  if tset2a_A_LABEL in tset2a_oplist then
   if tset2a_A_JSR in tset2a_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2a_failed := true
    end
  else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2a_failed := true
    end
 else
  begin
    WriteLn('TESTING SET_ADD_SETS: FAILED.');
    tset2a_failed := true
  end;
end;

Procedure tset2a_SetSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 op2list:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 tset2a_oplist:=op2list-tset2a_oplist;
 if (tset2a_A_MOVE in tset2a_oplist) or (tset2a_A_LABEL in tset2a_oplist) or (tset2a_A_JSR in tset2a_oplist) then
   begin
    WriteLn('TESTING SET_SUB_SETS: FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING SET_SUB_SETS: PASSED.');
 tset2a_oplist := [tset2a_A_MOVE,tset2a_A_RTE];
 exclude(tset2a_oplist,tset2a_A_MOVE);
 if (tset2a_A_MOVE in tset2a_oplist) then
  begin
    WriteLn('TESTING EXCLUDE: FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING EXCLUDE: PASSED.')
end;

Procedure tset2a_SetCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 op2list:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 if tset2a_oplist=op2list then
  WriteLn('TESTING SET_COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING SET_COMP_SETS(1): FAILED.');
    tset2a_failed := true
  end;
 tset2a_oplist:=[tset2a_A_MOVE];
 if tset2a_oplist=op2list then
  begin
    WriteLn('TESTING SET_COMP_SETS(2): FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING SET_COMP_SETS(2): PASSED.');
end;

Procedure tset2a_SetMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2a_tasmop;
 tset2a_oplist: set of tset2a_tasmop;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_A_MOVE]+[tset2a_A_JSR];
 op2list:=[tset2a_A_MOVE];
 tset2a_oplist:=tset2a_oplist*op2list;
 if tset2a_A_JSR in tset2a_oplist then
  begin
    WriteLn('TESTING SET_MUL_SETS(1): FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING SET_MUL_SETS(1): PASSED.');
 if tset2a_A_MOVE in tset2a_oplist  then
  WriteLn('TESTING SET_MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING SET_MUL_SETS(2): FAILED.');
    tset2a_failed := true
  end;
end;

{------------------------------ TESTS FOR SMALL VALUES ---------------------}
Procedure tset2a_SmallInSets;
{ SET_IN_BYTE TESTS }
var
 op : tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 Write('TESTING IN_BYTE:');
 tset2a_oplist:=[];
 op:=tset2a_Dn;
 if op in tset2a_oplist then
  begin
    WriteLn(' FAILED.');
    tset2a_failed := true
  end;
 op:=tset2a_dm;
 tset2a_oplist:=tset2a_oplist+[tset2a_Dm];
 if op in tset2a_oplist then
  WriteLn(' PASSED.')
 else
   begin
    WriteLn(' FAILED.');
    tset2a_failed := true
  end;
end;

Procedure tset2a_SmallSetByte;
{ SET_SET_BYTE }
var
 op : tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 Write('TESTING SET_BYTE(1):');
 op:=tset2a_DA;
 tset2a_oplist:=[];
 tset2a_oplist:=tset2a_oplist+[op];
 if op in tset2a_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2a_failed := true;
 end;
end;


Procedure tset2a_SmallAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_DA]+[tset2a_DC];
 op2list:=[tset2a_DB];
 tset2a_oplist:=op2list+tset2a_oplist;
 if tset2a_DA in tset2a_oplist then
  if tset2a_DC in tset2a_oplist then
   if tset2a_DB in tset2a_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING ADD_SETS: FAILED.');
      tset2a_failed := true
    end
  else
   begin
     WriteLn('TESTING ADD_SETS: FAILED.');
     tset2a_failed := true
   end
 else
  begin
    WriteLn('TESTING ADD_SETS: FAILED.');
    tset2a_failed := true
  end;
end;

Procedure tset2a_SmallSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_DA]+[tset2a_DC];
 op2list:=[tset2a_DA]+[tset2a_DC];
 tset2a_oplist:=op2list-tset2a_oplist;
 if (tset2a_DA in tset2a_oplist) or (tset2a_DB in tset2a_oplist) or (tset2a_DC in tset2a_oplist) then
  begin
    WriteLn('TESTING SUB_SETS: FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING SUB_SETS: PASSED.')
end;

Procedure tset2a_SmallCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_DA]+[tset2a_DC];
 op2list:=[tset2a_DA]+[tset2a_DC];
 if tset2a_oplist=op2list then
  WriteLn('TESTING COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING COMP_SETS(1): FAILED.');
    tset2a_failed := true
  end;
 tset2a_oplist:=[tset2a_DA];
 if tset2a_oplist=op2list then
  begin
    WriteLn('TESTING COMP_SETS(2): FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING COMP_SETS(2): PASSED.');
end;

Procedure tset2a_SmallMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2a_myenum;
 tset2a_oplist: set of tset2a_myenum;
Begin
 op2list:=[];
 tset2a_oplist:=[];
 tset2a_oplist:=[tset2a_DA]+[tset2a_DC];
 op2list:=[tset2a_DA];
 tset2a_oplist:=tset2a_oplist*op2list;
 if tset2a_DC in tset2a_oplist then
  begin
    WriteLn('TESTING MUL_SETS(1): FAILED.');
    tset2a_failed := true
  end
 else
  WriteLn('TESTING MUL_SETS(1): PASSED.');
 if tset2a_DA in tset2a_oplist  then
  WriteLn('TESTING MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING MUL_SETS(2): FAILED.');
    tset2a_failed := true
  end;
end;

const
 tset2a_b: tset2a_myenum = (tset2a_dA);
var
 tset2a_enum: set of tset2a_myenum;
 tset2a_oplist: set of tset2a_tasmop;
 tset2a_l : word;

{$pop}

{ Case tset2b.pas }
{$push}
(*********************************************************************)
(* Copyright (C) 1998, Carl Eric Codere                              *)
(*********************************************************************)
(* FPC (Free Pascal compiler) testsuite: SETS                        *)
(*   Tests the following: in, +, -, *, assignments.                  *)
(*      for small sets amd large sets, both with constants           *)
(*      and variables.                                               *)
(*********************************************************************)

{$packset 2}

const
  tset2b_failed: boolean = false;

type
       tset2b_myenum = (tset2b_dA:=8,tset2b_dB,tset2b_dC,tset2b_dd,tset2b_dedf,tset2b_dg,tset2b_dh,tset2b_di,tset2b_dj,tset2b_dk,tset2b_dl,tset2b_dm,tset2b_dn);
       tset2b_tasmop = (tset2b_A_ABCD:=16,
         tset2b_A_ADD,tset2b_A_ADDA,tset2b_A_ADDI,tset2b_A_ADDQ,tset2b_A_ADDX,tset2b_A_AND,tset2b_A_ANDI,
         tset2b_A_ASL,tset2b_A_ASR,tset2b_A_BCC,tset2b_A_BCS,tset2b_A_BEQ,tset2b_A_BGE,tset2b_A_BGT,tset2b_A_BHI,
         tset2b_A_BLE,tset2b_A_BLS,tset2b_A_BLT,tset2b_A_BMI,tset2b_A_BNE,tset2b_A_BPL,tset2b_A_BVC,tset2b_A_BVS,
         tset2b_A_BCHG,tset2b_A_BCLR,tset2b_A_BRA,tset2b_A_BSET,tset2b_A_BSR,tset2b_A_BTST,tset2b_A_CHK,
         tset2b_A_CLR,tset2b_A_CMP,tset2b_A_CMPA,tset2b_A_CMPI,tset2b_A_CMPM,tset2b_A_DBCC,tset2b_A_DBCS,tset2b_A_DBEQ,tset2b_A_DBGE,
         tset2b_A_DBGT,tset2b_A_DBHI,tset2b_A_DBLE,tset2b_A_DBLS,tset2b_A_DBLT,tset2b_A_DBMI,tset2b_A_DBNE,tset2b_A_DBRA,
         tset2b_A_DBPL,tset2b_A_DBT,tset2b_A_DBVC,tset2b_A_DBVS,tset2b_A_DBF,tset2b_A_DIVS,tset2b_A_DIVU,
         tset2b_A_EOR,tset2b_A_EORI,tset2b_A_EXG,tset2b_A_ILLEGAL,tset2b_A_EXT,tset2b_A_JMP,tset2b_A_JSR,
         tset2b_A_LEA,tset2b_A_LINK,tset2b_A_LSL,tset2b_A_LSR,tset2b_A_MOVE,tset2b_A_MOVEA,tset2b_A_MOVEI,tset2b_A_MOVEQ,
         tset2b_A_MOVEM,tset2b_A_MOVEP,tset2b_A_MULS,tset2b_A_MULU,tset2b_A_NBCD,tset2b_A_NEG,tset2b_A_NEGX,
         tset2b_A_NOP,tset2b_A_NOT,tset2b_A_OR,tset2b_A_ORI,tset2b_A_PEA,tset2b_A_ROL,tset2b_A_ROR,tset2b_A_ROXL,
         tset2b_A_ROXR,tset2b_A_RTR,tset2b_A_RTS,tset2b_A_SBCD,tset2b_A_SCC,tset2b_A_SCS,tset2b_A_SEQ,tset2b_A_SGE,
         tset2b_A_SGT,tset2b_A_SHI,tset2b_A_SLE,tset2b_A_SLS,tset2b_A_SLT,tset2b_A_SMI,tset2b_A_SNE,
         tset2b_A_SPL,tset2b_A_ST,tset2b_A_SVC,tset2b_A_SVS,tset2b_A_SF,tset2b_A_SUB,tset2b_A_SUBA,tset2b_A_SUBI,tset2b_A_SUBQ,
         tset2b_A_SUBX,tset2b_A_SWAP,tset2b_A_TAS,tset2b_A_TRAP,tset2b_A_TRAPV,tset2b_A_TST,tset2b_A_UNLK,
         tset2b_A_RTE,tset2b_A_RESET,tset2b_A_STOP,
         { MC68010 instructions }
         tset2b_A_BKPT,tset2b_A_MOVEC,tset2b_A_MOVES,tset2b_A_RTD,
         { MC68020 instructions }
         tset2b_A_BFCHG,tset2b_A_BFCLR,tset2b_A_BFEXTS,tset2b_A_BFEXTU,tset2b_A_BFFFO,
         tset2b_A_BFINS,tset2b_A_BFSET,tset2b_A_BFTST,tset2b_A_CALLM,tset2b_A_CAS,tset2b_A_CAS2,
         tset2b_A_CHK2,tset2b_A_CMP2,tset2b_A_DIVSL,tset2b_A_DIVUL,tset2b_A_EXTB,tset2b_A_PACK,tset2b_A_RTM,
         tset2b_A_TRAPCC,tset2b_A_TRACS,tset2b_A_TRAPEQ,tset2b_A_TRAPF,tset2b_A_TRAPGE,tset2b_A_TRAPGT,
         tset2b_A_TRAPHI,tset2b_A_TRAPLE,tset2b_A_TRAPLS,tset2b_A_TRAPLT,tset2b_A_TRAPMI,tset2b_A_TRAPNE,
         tset2b_A_TRAPPL,tset2b_A_TRAPT,tset2b_A_TRAPVC,tset2b_A_TRAPVS,tset2b_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tset2b_A_FABS,tset2b_A_FADD,
         tset2b_A_FBEQ,tset2b_A_FBNE,tset2b_A_FBNGT,tset2b_A_FBGT,tset2b_A_FBGE,tset2b_A_FBNGE,
         tset2b_A_FBLT,tset2b_A_FBNLT,tset2b_A_FBLE,tset2b_A_FBGL,tset2b_A_FBNGL,tset2b_A_FBGLE,tset2b_A_FBNGLE,
         tset2b_A_FDBEQ,tset2b_A_FDBNE,tset2b_A_FDBGT,tset2b_A_FDBNGT,tset2b_A_FDBGE,tset2b_A_FDBNGE,
         tset2b_A_FDBLT,tset2b_A_FDBNLT,tset2b_A_FDBLE,tset2b_A_FDBGL,tset2b_A_FDBNGL,tset2b_A_FDBGLE,tset2b_A_FBDNGLE,
         tset2b_A_FSEQ,tset2b_A_FSNE,tset2b_A_FSGT,tset2b_A_FSNGT,tset2b_A_FSGE,tset2b_A_FSNGE,
         tset2b_A_FSLT,tset2b_A_FSNLT,tset2b_A_FSLE,tset2b_A_FSGL,tset2b_A_FSNGL,tset2b_A_FSGLE,tset2b_A_FSNGLE,
         tset2b_A_FCMP,tset2b_A_FDIV,tset2b_A_FMOVE,tset2b_A_FMOVEM,
         tset2b_A_FMUL,tset2b_A_FNEG,tset2b_A_FNOP,tset2b_A_FSQRT,tset2b_A_FSUB,tset2b_A_FSGLDIV,
         tset2b_A_FSFLMUL,tset2b_A_FTST,
         tset2b_A_FTRAPEQ,tset2b_A_FTRAPNE,tset2b_A_FTRAPGT,tset2b_A_FTRAPNGT,tset2b_A_FTRAPGE,tset2b_A_FTRAPNGE,
         tset2b_A_FTRAPLT,tset2b_A_FTRAPNLT,tset2b_A_FTRAPLE,tset2b_A_FTRAPGL,tset2b_A_FTRAPNGL,tset2b_A_FTRAPGLE,tset2b_A_FTRAPNGLE,
         { Protected instructions }
         tset2b_A_CPRESTORE,tset2b_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tset2b_A_FRESTORE,tset2b_A_FSAVE,tset2b_A_PFLUSH,tset2b_A_PFLUSHA,tset2b_A_PLOAD,tset2b_A_PMOVE,tset2b_A_PTEST,
         { Useful for assembly langage output }
         tset2b_A_LABEL,tset2b_A_NONE);


Function tset2b_X(y:tset2b_myenum): tset2b_myenum;
Begin
 tset2b_x:=y;
end;


Procedure tset2b_SecondInSets;
{ SET_IN_BYTE TESTS }
var
 op,op2 : tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 Write('TESTING SET_IN_BYTE:');
 tset2b_oplist:=[];
 op:=tset2b_A_JSR;
 if tset2b_A_JSR in tset2b_oplist then
  begin
    WriteLn('A_JSR in [] FAILED.');
    tset2b_failed := true
  end
 else
  Writeln('A_JSR in [] PASSED.');
 if op in tset2b_oplist then
  begin
    WriteLn('op(A_JSR) in [] FAILED.');
    tset2b_failed := true
  end
 else
  Writeln('op (A_JSR) in [] PASSED.');
 op:=tset2b_A_MOVE;
 tset2b_oplist:=tset2b_oplist+[tset2b_A_MOVE];
 if tset2b_A_MOVE in tset2b_oplist then
  WriteLn('A_MOVE in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([]+[A_MOVE]) FAILED.');
    tset2b_failed := true;
  end;
 if op in tset2b_oplist then
  WriteLn('op(A_MOVE) in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('op(A_MOVE) in ([]+[A_MOVE]) FAILED.');
    tset2b_failed := true;
  end;
  op:=tset2b_A_MOVE;
  tset2b_oplist:=[];
  tset2b_oplist:=[tset2b_A_SUB]+[op];
  op2:=tset2b_A_MOVE;
 if tset2b_A_MOVE in tset2b_oplist then
  WriteLn('A_MOVE in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2b_failed := true
  end;
 if op2 in tset2b_oplist then
  WriteLn('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2b_failed := true
  end;
end;

Procedure tset2b_SetSetByte;
{ SET_SET_BYTE }
var
 op : tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 Write('TESTING SET_SET_BYTE(1):');
 op:=tset2b_A_LABEL;
 tset2b_oplist:=[];
 tset2b_oplist:=tset2b_oplist+[op];
 if op in tset2b_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2b_failed := true
 end;
 Write('TESTING INCLUDE:');
 op:=tset2b_A_RTE;
 include(tset2b_oplist,op);
 if op in tset2b_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2b_failed := true;
 end;
end;


Procedure tset2b_SetAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 op2list:=[tset2b_A_LABEL];
 tset2b_oplist:=op2list+tset2b_oplist;
 if tset2b_A_MOVE in tset2b_oplist then
  if tset2b_A_LABEL in tset2b_oplist then
   if tset2b_A_JSR in tset2b_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2b_failed := true
    end
  else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2b_failed := true
    end
 else
  begin
    WriteLn('TESTING SET_ADD_SETS: FAILED.');
    tset2b_failed := true
  end;
end;

Procedure tset2b_SetSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 op2list:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 tset2b_oplist:=op2list-tset2b_oplist;
 if (tset2b_A_MOVE in tset2b_oplist) or (tset2b_A_LABEL in tset2b_oplist) or (tset2b_A_JSR in tset2b_oplist) then
   begin
    WriteLn('TESTING SET_SUB_SETS: FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING SET_SUB_SETS: PASSED.');
 tset2b_oplist := [tset2b_A_MOVE,tset2b_A_RTE];
 exclude(tset2b_oplist,tset2b_A_MOVE);
 if (tset2b_A_MOVE in tset2b_oplist) then
  begin
    WriteLn('TESTING EXCLUDE: FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING EXCLUDE: PASSED.')
end;

Procedure tset2b_SetCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 op2list:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 if tset2b_oplist=op2list then
  WriteLn('TESTING SET_COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING SET_COMP_SETS(1): FAILED.');
    tset2b_failed := true
  end;
 tset2b_oplist:=[tset2b_A_MOVE];
 if tset2b_oplist=op2list then
  begin
    WriteLn('TESTING SET_COMP_SETS(2): FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING SET_COMP_SETS(2): PASSED.');
end;

Procedure tset2b_SetMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2b_tasmop;
 tset2b_oplist: set of tset2b_tasmop;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_A_MOVE]+[tset2b_A_JSR];
 op2list:=[tset2b_A_MOVE];
 tset2b_oplist:=tset2b_oplist*op2list;
 if tset2b_A_JSR in tset2b_oplist then
  begin
    WriteLn('TESTING SET_MUL_SETS(1): FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING SET_MUL_SETS(1): PASSED.');
 if tset2b_A_MOVE in tset2b_oplist  then
  WriteLn('TESTING SET_MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING SET_MUL_SETS(2): FAILED.');
    tset2b_failed := true
  end;
end;

{------------------------------ TESTS FOR SMALL VALUES ---------------------}
Procedure tset2b_SmallInSets;
{ SET_IN_BYTE TESTS }
var
 op : tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 Write('TESTING IN_BYTE:');
 tset2b_oplist:=[];
 op:=tset2b_Dn;
 if op in tset2b_oplist then
  begin
    WriteLn(' FAILED.');
    tset2b_failed := true
  end;
 op:=tset2b_dm;
 tset2b_oplist:=tset2b_oplist+[tset2b_Dm];
 if op in tset2b_oplist then
  WriteLn(' PASSED.')
 else
   begin
    WriteLn(' FAILED.');
    tset2b_failed := true
  end;
end;

Procedure tset2b_SmallSetByte;
{ SET_SET_BYTE }
var
 op : tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 Write('TESTING SET_BYTE(1):');
 op:=tset2b_DA;
 tset2b_oplist:=[];
 tset2b_oplist:=tset2b_oplist+[op];
 if op in tset2b_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2b_failed := true;
 end;
end;


Procedure tset2b_SmallAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_DA]+[tset2b_DC];
 op2list:=[tset2b_DB];
 tset2b_oplist:=op2list+tset2b_oplist;
 if tset2b_DA in tset2b_oplist then
  if tset2b_DC in tset2b_oplist then
   if tset2b_DB in tset2b_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING ADD_SETS: FAILED.');
      tset2b_failed := true
    end
  else
   begin
     WriteLn('TESTING ADD_SETS: FAILED.');
     tset2b_failed := true
   end
 else
  begin
    WriteLn('TESTING ADD_SETS: FAILED.');
    tset2b_failed := true
  end;
end;

Procedure tset2b_SmallSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_DA]+[tset2b_DC];
 op2list:=[tset2b_DA]+[tset2b_DC];
 tset2b_oplist:=op2list-tset2b_oplist;
 if (tset2b_DA in tset2b_oplist) or (tset2b_DB in tset2b_oplist) or (tset2b_DC in tset2b_oplist) then
  begin
    WriteLn('TESTING SUB_SETS: FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING SUB_SETS: PASSED.')
end;

Procedure tset2b_SmallCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_DA]+[tset2b_DC];
 op2list:=[tset2b_DA]+[tset2b_DC];
 if tset2b_oplist=op2list then
  WriteLn('TESTING COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING COMP_SETS(1): FAILED.');
    tset2b_failed := true
  end;
 tset2b_oplist:=[tset2b_DA];
 if tset2b_oplist=op2list then
  begin
    WriteLn('TESTING COMP_SETS(2): FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING COMP_SETS(2): PASSED.');
end;

Procedure tset2b_SmallMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2b_myenum;
 tset2b_oplist: set of tset2b_myenum;
Begin
 op2list:=[];
 tset2b_oplist:=[];
 tset2b_oplist:=[tset2b_DA]+[tset2b_DC];
 op2list:=[tset2b_DA];
 tset2b_oplist:=tset2b_oplist*op2list;
 if tset2b_DC in tset2b_oplist then
  begin
    WriteLn('TESTING MUL_SETS(1): FAILED.');
    tset2b_failed := true
  end
 else
  WriteLn('TESTING MUL_SETS(1): PASSED.');
 if tset2b_DA in tset2b_oplist  then
  WriteLn('TESTING MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING MUL_SETS(2): FAILED.');
    tset2b_failed := true
  end;
end;

const
 tset2b_b: tset2b_myenum = (tset2b_dA);
var
 tset2b_enum: set of tset2b_myenum;
 tset2b_oplist: set of tset2b_tasmop;
 tset2b_l : word;

{$pop}

{ Case tset2c.pas }
{$push}
(*********************************************************************)
(* Copyright (C) 1998, Carl Eric Codere                              *)
(*********************************************************************)
(* FPC (Free Pascal compiler) testsuite: SETS                        *)
(*   Tests the following: in, +, -, *, assignments.                  *)
(*      for small sets amd large sets, both with constants           *)
(*      and variables.                                               *)
(*********************************************************************)

{$packset 1}

const
  tset2c_failed: boolean = false;

type
       tset2c_myenum = (tset2c_dA:=17,tset2c_dB,tset2c_dC,tset2c_dd,tset2c_dedf,tset2c_dg,tset2c_dh,tset2c_di,tset2c_dj,tset2c_dk,tset2c_dl,tset2c_dm,tset2c_dn);
       tset2c_tasmop = (tset2c_A_ABCD:=21,
         tset2c_A_ADD,tset2c_A_ADDA,tset2c_A_ADDI,tset2c_A_ADDQ,tset2c_A_ADDX,tset2c_A_AND,tset2c_A_ANDI,
         tset2c_A_ASL,tset2c_A_ASR,tset2c_A_BCC,tset2c_A_BCS,tset2c_A_BEQ,tset2c_A_BGE,tset2c_A_BGT,tset2c_A_BHI,
         tset2c_A_BLE,tset2c_A_BLS,tset2c_A_BLT,tset2c_A_BMI,tset2c_A_BNE,tset2c_A_BPL,tset2c_A_BVC,tset2c_A_BVS,
         tset2c_A_BCHG,tset2c_A_BCLR,tset2c_A_BRA,tset2c_A_BSET,tset2c_A_BSR,tset2c_A_BTST,tset2c_A_CHK,
         tset2c_A_CLR,tset2c_A_CMP,tset2c_A_CMPA,tset2c_A_CMPI,tset2c_A_CMPM,tset2c_A_DBCC,tset2c_A_DBCS,tset2c_A_DBEQ,tset2c_A_DBGE,
         tset2c_A_DBGT,tset2c_A_DBHI,tset2c_A_DBLE,tset2c_A_DBLS,tset2c_A_DBLT,tset2c_A_DBMI,tset2c_A_DBNE,tset2c_A_DBRA,
         tset2c_A_DBPL,tset2c_A_DBT,tset2c_A_DBVC,tset2c_A_DBVS,tset2c_A_DBF,tset2c_A_DIVS,tset2c_A_DIVU,
         tset2c_A_EOR,tset2c_A_EORI,tset2c_A_EXG,tset2c_A_ILLEGAL,tset2c_A_EXT,tset2c_A_JMP,tset2c_A_JSR,
         tset2c_A_LEA,tset2c_A_LINK,tset2c_A_LSL,tset2c_A_LSR,tset2c_A_MOVE,tset2c_A_MOVEA,tset2c_A_MOVEI,tset2c_A_MOVEQ,
         tset2c_A_MOVEM,tset2c_A_MOVEP,tset2c_A_MULS,tset2c_A_MULU,tset2c_A_NBCD,tset2c_A_NEG,tset2c_A_NEGX,
         tset2c_A_NOP,tset2c_A_NOT,tset2c_A_OR,tset2c_A_ORI,tset2c_A_PEA,tset2c_A_ROL,tset2c_A_ROR,tset2c_A_ROXL,
         tset2c_A_ROXR,tset2c_A_RTR,tset2c_A_RTS,tset2c_A_SBCD,tset2c_A_SCC,tset2c_A_SCS,tset2c_A_SEQ,tset2c_A_SGE,
         tset2c_A_SGT,tset2c_A_SHI,tset2c_A_SLE,tset2c_A_SLS,tset2c_A_SLT,tset2c_A_SMI,tset2c_A_SNE,
         tset2c_A_SPL,tset2c_A_ST,tset2c_A_SVC,tset2c_A_SVS,tset2c_A_SF,tset2c_A_SUB,tset2c_A_SUBA,tset2c_A_SUBI,tset2c_A_SUBQ,
         tset2c_A_SUBX,tset2c_A_SWAP,tset2c_A_TAS,tset2c_A_TRAP,tset2c_A_TRAPV,tset2c_A_TST,tset2c_A_UNLK,
         tset2c_A_RTE,tset2c_A_RESET,tset2c_A_STOP,
         { MC68010 instructions }
         tset2c_A_BKPT,tset2c_A_MOVEC,tset2c_A_MOVES,tset2c_A_RTD,
         { MC68020 instructions }
         tset2c_A_BFCHG,tset2c_A_BFCLR,tset2c_A_BFEXTS,tset2c_A_BFEXTU,tset2c_A_BFFFO,
         tset2c_A_BFINS,tset2c_A_BFSET,tset2c_A_BFTST,tset2c_A_CALLM,tset2c_A_CAS,tset2c_A_CAS2,
         tset2c_A_CHK2,tset2c_A_CMP2,tset2c_A_DIVSL,tset2c_A_DIVUL,tset2c_A_EXTB,tset2c_A_PACK,tset2c_A_RTM,
         tset2c_A_TRAPCC,tset2c_A_TRACS,tset2c_A_TRAPEQ,tset2c_A_TRAPF,tset2c_A_TRAPGE,tset2c_A_TRAPGT,
         tset2c_A_TRAPHI,tset2c_A_TRAPLE,tset2c_A_TRAPLS,tset2c_A_TRAPLT,tset2c_A_TRAPMI,tset2c_A_TRAPNE,
         tset2c_A_TRAPPL,tset2c_A_TRAPT,tset2c_A_TRAPVC,tset2c_A_TRAPVS,tset2c_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tset2c_A_FABS,tset2c_A_FADD,
         tset2c_A_FBEQ,tset2c_A_FBNE,tset2c_A_FBNGT,tset2c_A_FBGT,tset2c_A_FBGE,tset2c_A_FBNGE,
         tset2c_A_FBLT,tset2c_A_FBNLT,tset2c_A_FBLE,tset2c_A_FBGL,tset2c_A_FBNGL,tset2c_A_FBGLE,tset2c_A_FBNGLE,
         tset2c_A_FDBEQ,tset2c_A_FDBNE,tset2c_A_FDBGT,tset2c_A_FDBNGT,tset2c_A_FDBGE,tset2c_A_FDBNGE,
         tset2c_A_FDBLT,tset2c_A_FDBNLT,tset2c_A_FDBLE,tset2c_A_FDBGL,tset2c_A_FDBNGL,tset2c_A_FDBGLE,tset2c_A_FBDNGLE,
         tset2c_A_FSEQ,tset2c_A_FSNE,tset2c_A_FSGT,tset2c_A_FSNGT,tset2c_A_FSGE,tset2c_A_FSNGE,
         tset2c_A_FSLT,tset2c_A_FSNLT,tset2c_A_FSLE,tset2c_A_FSGL,tset2c_A_FSNGL,tset2c_A_FSGLE,tset2c_A_FSNGLE,
         tset2c_A_FCMP,tset2c_A_FDIV,tset2c_A_FMOVE,tset2c_A_FMOVEM,
         tset2c_A_FMUL,tset2c_A_FNEG,tset2c_A_FNOP,tset2c_A_FSQRT,tset2c_A_FSUB,tset2c_A_FSGLDIV,
         tset2c_A_FSFLMUL,tset2c_A_FTST,
         tset2c_A_FTRAPEQ,tset2c_A_FTRAPNE,tset2c_A_FTRAPGT,tset2c_A_FTRAPNGT,tset2c_A_FTRAPGE,tset2c_A_FTRAPNGE,
         tset2c_A_FTRAPLT,tset2c_A_FTRAPNLT,tset2c_A_FTRAPLE,tset2c_A_FTRAPGL,tset2c_A_FTRAPNGL,tset2c_A_FTRAPGLE,tset2c_A_FTRAPNGLE,
         { Protected instructions }
         tset2c_A_CPRESTORE,tset2c_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tset2c_A_FRESTORE,tset2c_A_FSAVE,tset2c_A_PFLUSH,tset2c_A_PFLUSHA,tset2c_A_PLOAD,tset2c_A_PMOVE,tset2c_A_PTEST,
         { Useful for assembly langage output }
         tset2c_A_LABEL,tset2c_A_NONE);


Function tset2c_X(y:tset2c_myenum): tset2c_myenum;
Begin
 tset2c_x:=y;
end;


Procedure tset2c_SecondInSets;
{ SET_IN_BYTE TESTS }
var
 op,op2 : tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 Write('TESTING SET_IN_BYTE:');
 tset2c_oplist:=[];
 op:=tset2c_A_JSR;
 if tset2c_A_JSR in tset2c_oplist then
  begin
    WriteLn('A_JSR in [] FAILED.');
    tset2c_failed := true
  end
 else
  Writeln('A_JSR in [] PASSED.');
 if op in tset2c_oplist then
  begin
    WriteLn('op(A_JSR) in [] FAILED.');
    tset2c_failed := true
  end
 else
  Writeln('op (A_JSR) in [] PASSED.');
 op:=tset2c_A_MOVE;
 tset2c_oplist:=tset2c_oplist+[tset2c_A_MOVE];
 if tset2c_A_MOVE in tset2c_oplist then
  WriteLn('A_MOVE in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([]+[A_MOVE]) FAILED.');
    tset2c_failed := true;
  end;
 if op in tset2c_oplist then
  WriteLn('op(A_MOVE) in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('op(A_MOVE) in ([]+[A_MOVE]) FAILED.');
    tset2c_failed := true;
  end;
  op:=tset2c_A_MOVE;
  tset2c_oplist:=[];
  tset2c_oplist:=[tset2c_A_SUB]+[op];
  op2:=tset2c_A_MOVE;
 if tset2c_A_MOVE in tset2c_oplist then
  WriteLn('A_MOVE in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2c_failed := true
  end;
 if op2 in tset2c_oplist then
  WriteLn('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2c_failed := true
  end;
end;

Procedure tset2c_SetSetByte;
{ SET_SET_BYTE }
var
 op : tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 Write('TESTING SET_SET_BYTE(1):');
 op:=tset2c_A_LABEL;
 tset2c_oplist:=[];
 tset2c_oplist:=tset2c_oplist+[op];
 if op in tset2c_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2c_failed := true
 end;
 Write('TESTING INCLUDE:');
 op:=tset2c_A_RTE;
 include(tset2c_oplist,op);
 if op in tset2c_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2c_failed := true;
 end;
end;


Procedure tset2c_SetAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 op2list:=[tset2c_A_LABEL];
 tset2c_oplist:=op2list+tset2c_oplist;
 if tset2c_A_MOVE in tset2c_oplist then
  if tset2c_A_LABEL in tset2c_oplist then
   if tset2c_A_JSR in tset2c_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2c_failed := true
    end
  else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2c_failed := true
    end
 else
  begin
    WriteLn('TESTING SET_ADD_SETS: FAILED.');
    tset2c_failed := true
  end;
end;

Procedure tset2c_SetSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 op2list:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 tset2c_oplist:=op2list-tset2c_oplist;
 if (tset2c_A_MOVE in tset2c_oplist) or (tset2c_A_LABEL in tset2c_oplist) or (tset2c_A_JSR in tset2c_oplist) then
   begin
    WriteLn('TESTING SET_SUB_SETS: FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING SET_SUB_SETS: PASSED.');
 tset2c_oplist := [tset2c_A_MOVE,tset2c_A_RTE];
 exclude(tset2c_oplist,tset2c_A_MOVE);
 if (tset2c_A_MOVE in tset2c_oplist) then
  begin
    WriteLn('TESTING EXCLUDE: FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING EXCLUDE: PASSED.')
end;

Procedure tset2c_SetCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 op2list:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 if tset2c_oplist=op2list then
  WriteLn('TESTING SET_COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING SET_COMP_SETS(1): FAILED.');
    tset2c_failed := true
  end;
 tset2c_oplist:=[tset2c_A_MOVE];
 if tset2c_oplist=op2list then
  begin
    WriteLn('TESTING SET_COMP_SETS(2): FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING SET_COMP_SETS(2): PASSED.');
end;

Procedure tset2c_SetMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2c_tasmop;
 tset2c_oplist: set of tset2c_tasmop;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_A_MOVE]+[tset2c_A_JSR];
 op2list:=[tset2c_A_MOVE];
 tset2c_oplist:=tset2c_oplist*op2list;
 if tset2c_A_JSR in tset2c_oplist then
  begin
    WriteLn('TESTING SET_MUL_SETS(1): FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING SET_MUL_SETS(1): PASSED.');
 if tset2c_A_MOVE in tset2c_oplist  then
  WriteLn('TESTING SET_MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING SET_MUL_SETS(2): FAILED.');
    tset2c_failed := true
  end;
end;

{------------------------------ TESTS FOR SMALL VALUES ---------------------}
Procedure tset2c_SmallInSets;
{ SET_IN_BYTE TESTS }
var
 op : tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 Write('TESTING IN_BYTE:');
 tset2c_oplist:=[];
 op:=tset2c_Dn;
 if op in tset2c_oplist then
  begin
    WriteLn(' FAILED.');
    tset2c_failed := true
  end;
 op:=tset2c_dm;
 tset2c_oplist:=tset2c_oplist+[tset2c_Dm];
 if op in tset2c_oplist then
  WriteLn(' PASSED.')
 else
   begin
    WriteLn(' FAILED.');
    tset2c_failed := true
  end;
end;

Procedure tset2c_SmallSetByte;
{ SET_SET_BYTE }
var
 op : tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 Write('TESTING SET_BYTE(1):');
 op:=tset2c_DA;
 tset2c_oplist:=[];
 tset2c_oplist:=tset2c_oplist+[op];
 if op in tset2c_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2c_failed := true;
 end;
end;


Procedure tset2c_SmallAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_DA]+[tset2c_DC];
 op2list:=[tset2c_DB];
 tset2c_oplist:=op2list+tset2c_oplist;
 if tset2c_DA in tset2c_oplist then
  if tset2c_DC in tset2c_oplist then
   if tset2c_DB in tset2c_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING ADD_SETS: FAILED.');
      tset2c_failed := true
    end
  else
   begin
     WriteLn('TESTING ADD_SETS: FAILED.');
     tset2c_failed := true
   end
 else
  begin
    WriteLn('TESTING ADD_SETS: FAILED.');
    tset2c_failed := true
  end;
end;

Procedure tset2c_SmallSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_DA]+[tset2c_DC];
 op2list:=[tset2c_DA]+[tset2c_DC];
 tset2c_oplist:=op2list-tset2c_oplist;
 if (tset2c_DA in tset2c_oplist) or (tset2c_DB in tset2c_oplist) or (tset2c_DC in tset2c_oplist) then
  begin
    WriteLn('TESTING SUB_SETS: FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING SUB_SETS: PASSED.')
end;

Procedure tset2c_SmallCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_DA]+[tset2c_DC];
 op2list:=[tset2c_DA]+[tset2c_DC];
 if tset2c_oplist=op2list then
  WriteLn('TESTING COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING COMP_SETS(1): FAILED.');
    tset2c_failed := true
  end;
 tset2c_oplist:=[tset2c_DA];
 if tset2c_oplist=op2list then
  begin
    WriteLn('TESTING COMP_SETS(2): FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING COMP_SETS(2): PASSED.');
end;

Procedure tset2c_SmallMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2c_myenum;
 tset2c_oplist: set of tset2c_myenum;
Begin
 op2list:=[];
 tset2c_oplist:=[];
 tset2c_oplist:=[tset2c_DA]+[tset2c_DC];
 op2list:=[tset2c_DA];
 tset2c_oplist:=tset2c_oplist*op2list;
 if tset2c_DC in tset2c_oplist then
  begin
    WriteLn('TESTING MUL_SETS(1): FAILED.');
    tset2c_failed := true
  end
 else
  WriteLn('TESTING MUL_SETS(1): PASSED.');
 if tset2c_DA in tset2c_oplist  then
  WriteLn('TESTING MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING MUL_SETS(2): FAILED.');
    tset2c_failed := true
  end;
end;

const
 tset2c_b: tset2c_myenum = (tset2c_dA);
var
 tset2c_enum: set of tset2c_myenum;
 tset2c_oplist: set of tset2c_tasmop;
 tset2c_l : word;

{$pop}

{ Case tset2d.pas }
{$push}
(*********************************************************************)
(* Copyright (C) 1998, Carl Eric Codere                              *)
(*********************************************************************)
(* FPC (Free Pascal compiler) testsuite: SETS                        *)
(*   Tests the following: in, +, -, *, assignments.                  *)
(*      for small sets amd large sets, both with constants           *)
(*      and variables.                                               *)
(*********************************************************************)

{$packset 2}

const
  tset2d_failed: boolean = false;

type
       tset2d_myenum = (tset2d_dA:=17,tset2d_dB,tset2d_dC,tset2d_dd,tset2d_dedf,tset2d_dg,tset2d_dh,tset2d_di,tset2d_dj,tset2d_dk,tset2d_dl,tset2d_dm,tset2d_dn);
       tset2d_tasmop = (tset2d_A_ABCD:=21,
         tset2d_A_ADD,tset2d_A_ADDA,tset2d_A_ADDI,tset2d_A_ADDQ,tset2d_A_ADDX,tset2d_A_AND,tset2d_A_ANDI,
         tset2d_A_ASL,tset2d_A_ASR,tset2d_A_BCC,tset2d_A_BCS,tset2d_A_BEQ,tset2d_A_BGE,tset2d_A_BGT,tset2d_A_BHI,
         tset2d_A_BLE,tset2d_A_BLS,tset2d_A_BLT,tset2d_A_BMI,tset2d_A_BNE,tset2d_A_BPL,tset2d_A_BVC,tset2d_A_BVS,
         tset2d_A_BCHG,tset2d_A_BCLR,tset2d_A_BRA,tset2d_A_BSET,tset2d_A_BSR,tset2d_A_BTST,tset2d_A_CHK,
         tset2d_A_CLR,tset2d_A_CMP,tset2d_A_CMPA,tset2d_A_CMPI,tset2d_A_CMPM,tset2d_A_DBCC,tset2d_A_DBCS,tset2d_A_DBEQ,tset2d_A_DBGE,
         tset2d_A_DBGT,tset2d_A_DBHI,tset2d_A_DBLE,tset2d_A_DBLS,tset2d_A_DBLT,tset2d_A_DBMI,tset2d_A_DBNE,tset2d_A_DBRA,
         tset2d_A_DBPL,tset2d_A_DBT,tset2d_A_DBVC,tset2d_A_DBVS,tset2d_A_DBF,tset2d_A_DIVS,tset2d_A_DIVU,
         tset2d_A_EOR,tset2d_A_EORI,tset2d_A_EXG,tset2d_A_ILLEGAL,tset2d_A_EXT,tset2d_A_JMP,tset2d_A_JSR,
         tset2d_A_LEA,tset2d_A_LINK,tset2d_A_LSL,tset2d_A_LSR,tset2d_A_MOVE,tset2d_A_MOVEA,tset2d_A_MOVEI,tset2d_A_MOVEQ,
         tset2d_A_MOVEM,tset2d_A_MOVEP,tset2d_A_MULS,tset2d_A_MULU,tset2d_A_NBCD,tset2d_A_NEG,tset2d_A_NEGX,
         tset2d_A_NOP,tset2d_A_NOT,tset2d_A_OR,tset2d_A_ORI,tset2d_A_PEA,tset2d_A_ROL,tset2d_A_ROR,tset2d_A_ROXL,
         tset2d_A_ROXR,tset2d_A_RTR,tset2d_A_RTS,tset2d_A_SBCD,tset2d_A_SCC,tset2d_A_SCS,tset2d_A_SEQ,tset2d_A_SGE,
         tset2d_A_SGT,tset2d_A_SHI,tset2d_A_SLE,tset2d_A_SLS,tset2d_A_SLT,tset2d_A_SMI,tset2d_A_SNE,
         tset2d_A_SPL,tset2d_A_ST,tset2d_A_SVC,tset2d_A_SVS,tset2d_A_SF,tset2d_A_SUB,tset2d_A_SUBA,tset2d_A_SUBI,tset2d_A_SUBQ,
         tset2d_A_SUBX,tset2d_A_SWAP,tset2d_A_TAS,tset2d_A_TRAP,tset2d_A_TRAPV,tset2d_A_TST,tset2d_A_UNLK,
         tset2d_A_RTE,tset2d_A_RESET,tset2d_A_STOP,
         { MC68010 instructions }
         tset2d_A_BKPT,tset2d_A_MOVEC,tset2d_A_MOVES,tset2d_A_RTD,
         { MC68020 instructions }
         tset2d_A_BFCHG,tset2d_A_BFCLR,tset2d_A_BFEXTS,tset2d_A_BFEXTU,tset2d_A_BFFFO,
         tset2d_A_BFINS,tset2d_A_BFSET,tset2d_A_BFTST,tset2d_A_CALLM,tset2d_A_CAS,tset2d_A_CAS2,
         tset2d_A_CHK2,tset2d_A_CMP2,tset2d_A_DIVSL,tset2d_A_DIVUL,tset2d_A_EXTB,tset2d_A_PACK,tset2d_A_RTM,
         tset2d_A_TRAPCC,tset2d_A_TRACS,tset2d_A_TRAPEQ,tset2d_A_TRAPF,tset2d_A_TRAPGE,tset2d_A_TRAPGT,
         tset2d_A_TRAPHI,tset2d_A_TRAPLE,tset2d_A_TRAPLS,tset2d_A_TRAPLT,tset2d_A_TRAPMI,tset2d_A_TRAPNE,
         tset2d_A_TRAPPL,tset2d_A_TRAPT,tset2d_A_TRAPVC,tset2d_A_TRAPVS,tset2d_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tset2d_A_FABS,tset2d_A_FADD,
         tset2d_A_FBEQ,tset2d_A_FBNE,tset2d_A_FBNGT,tset2d_A_FBGT,tset2d_A_FBGE,tset2d_A_FBNGE,
         tset2d_A_FBLT,tset2d_A_FBNLT,tset2d_A_FBLE,tset2d_A_FBGL,tset2d_A_FBNGL,tset2d_A_FBGLE,tset2d_A_FBNGLE,
         tset2d_A_FDBEQ,tset2d_A_FDBNE,tset2d_A_FDBGT,tset2d_A_FDBNGT,tset2d_A_FDBGE,tset2d_A_FDBNGE,
         tset2d_A_FDBLT,tset2d_A_FDBNLT,tset2d_A_FDBLE,tset2d_A_FDBGL,tset2d_A_FDBNGL,tset2d_A_FDBGLE,tset2d_A_FBDNGLE,
         tset2d_A_FSEQ,tset2d_A_FSNE,tset2d_A_FSGT,tset2d_A_FSNGT,tset2d_A_FSGE,tset2d_A_FSNGE,
         tset2d_A_FSLT,tset2d_A_FSNLT,tset2d_A_FSLE,tset2d_A_FSGL,tset2d_A_FSNGL,tset2d_A_FSGLE,tset2d_A_FSNGLE,
         tset2d_A_FCMP,tset2d_A_FDIV,tset2d_A_FMOVE,tset2d_A_FMOVEM,
         tset2d_A_FMUL,tset2d_A_FNEG,tset2d_A_FNOP,tset2d_A_FSQRT,tset2d_A_FSUB,tset2d_A_FSGLDIV,
         tset2d_A_FSFLMUL,tset2d_A_FTST,
         tset2d_A_FTRAPEQ,tset2d_A_FTRAPNE,tset2d_A_FTRAPGT,tset2d_A_FTRAPNGT,tset2d_A_FTRAPGE,tset2d_A_FTRAPNGE,
         tset2d_A_FTRAPLT,tset2d_A_FTRAPNLT,tset2d_A_FTRAPLE,tset2d_A_FTRAPGL,tset2d_A_FTRAPNGL,tset2d_A_FTRAPGLE,tset2d_A_FTRAPNGLE,
         { Protected instructions }
         tset2d_A_CPRESTORE,tset2d_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         tset2d_A_FRESTORE,tset2d_A_FSAVE,tset2d_A_PFLUSH,tset2d_A_PFLUSHA,tset2d_A_PLOAD,tset2d_A_PMOVE,tset2d_A_PTEST,
         { Useful for assembly langage output }
         tset2d_A_LABEL,tset2d_A_NONE);


Function tset2d_X(y:tset2d_myenum): tset2d_myenum;
Begin
 tset2d_x:=y;
end;


Procedure tset2d_SecondInSets;
{ SET_IN_BYTE TESTS }
var
 op,op2 : tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 Write('TESTING SET_IN_BYTE:');
 tset2d_oplist:=[];
 op:=tset2d_A_JSR;
 if tset2d_A_JSR in tset2d_oplist then
  begin
    WriteLn('A_JSR in [] FAILED.');
    tset2d_failed := true
  end
 else
  Writeln('A_JSR in [] PASSED.');
 if op in tset2d_oplist then
  begin
    WriteLn('op(A_JSR) in [] FAILED.');
    tset2d_failed := true
  end
 else
  Writeln('op (A_JSR) in [] PASSED.');
 op:=tset2d_A_MOVE;
 tset2d_oplist:=tset2d_oplist+[tset2d_A_MOVE];
 if tset2d_A_MOVE in tset2d_oplist then
  WriteLn('A_MOVE in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([]+[A_MOVE]) FAILED.');
    tset2d_failed := true;
  end;
 if op in tset2d_oplist then
  WriteLn('op(A_MOVE) in ([]+[A_MOVE]) PASSED.')
 else
  begin
    Writeln('op(A_MOVE) in ([]+[A_MOVE]) FAILED.');
    tset2d_failed := true;
  end;
  op:=tset2d_A_MOVE;
  tset2d_oplist:=[];
  tset2d_oplist:=[tset2d_A_SUB]+[op];
  op2:=tset2d_A_MOVE;
 if tset2d_A_MOVE in tset2d_oplist then
  WriteLn('A_MOVE in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('A_MOVE in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2d_failed := true
  end;
 if op2 in tset2d_oplist then
  WriteLn('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) PASSED.')
 else
  begin
    Writeln('op2(A_MOVE) in ([A_SUB]+[op(A_MOVE)]) FAILED.');
    tset2d_failed := true
  end;
end;

Procedure tset2d_SetSetByte;
{ SET_SET_BYTE }
var
 op : tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 Write('TESTING SET_SET_BYTE(1):');
 op:=tset2d_A_LABEL;
 tset2d_oplist:=[];
 tset2d_oplist:=tset2d_oplist+[op];
 if op in tset2d_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2d_failed := true
 end;
 Write('TESTING INCLUDE:');
 op:=tset2d_A_RTE;
 include(tset2d_oplist,op);
 if op in tset2d_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2d_failed := true;
 end;
end;


Procedure tset2d_SetAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 op2list:=[tset2d_A_LABEL];
 tset2d_oplist:=op2list+tset2d_oplist;
 if tset2d_A_MOVE in tset2d_oplist then
  if tset2d_A_LABEL in tset2d_oplist then
   if tset2d_A_JSR in tset2d_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2d_failed := true
    end
  else
    begin
      WriteLn('TESTING SET_ADD_SETS: FAILED.');
      tset2d_failed := true
    end
 else
  begin
    WriteLn('TESTING SET_ADD_SETS: FAILED.');
    tset2d_failed := true
  end;
end;

Procedure tset2d_SetSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 op2list:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 tset2d_oplist:=op2list-tset2d_oplist;
 if (tset2d_A_MOVE in tset2d_oplist) or (tset2d_A_LABEL in tset2d_oplist) or (tset2d_A_JSR in tset2d_oplist) then
   begin
    WriteLn('TESTING SET_SUB_SETS: FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING SET_SUB_SETS: PASSED.');
 tset2d_oplist := [tset2d_A_MOVE,tset2d_A_RTE];
 exclude(tset2d_oplist,tset2d_A_MOVE);
 if (tset2d_A_MOVE in tset2d_oplist) then
  begin
    WriteLn('TESTING EXCLUDE: FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING EXCLUDE: PASSED.')
end;

Procedure tset2d_SetCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 op2list:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 if tset2d_oplist=op2list then
  WriteLn('TESTING SET_COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING SET_COMP_SETS(1): FAILED.');
    tset2d_failed := true
  end;
 tset2d_oplist:=[tset2d_A_MOVE];
 if tset2d_oplist=op2list then
  begin
    WriteLn('TESTING SET_COMP_SETS(2): FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING SET_COMP_SETS(2): PASSED.');
end;

Procedure tset2d_SetMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2d_tasmop;
 tset2d_oplist: set of tset2d_tasmop;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_A_MOVE]+[tset2d_A_JSR];
 op2list:=[tset2d_A_MOVE];
 tset2d_oplist:=tset2d_oplist*op2list;
 if tset2d_A_JSR in tset2d_oplist then
  begin
    WriteLn('TESTING SET_MUL_SETS(1): FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING SET_MUL_SETS(1): PASSED.');
 if tset2d_A_MOVE in tset2d_oplist  then
  WriteLn('TESTING SET_MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING SET_MUL_SETS(2): FAILED.');
    tset2d_failed := true
  end;
end;

{------------------------------ TESTS FOR SMALL VALUES ---------------------}
Procedure tset2d_SmallInSets;
{ SET_IN_BYTE TESTS }
var
 op : tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 Write('TESTING IN_BYTE:');
 tset2d_oplist:=[];
 op:=tset2d_Dn;
 if op in tset2d_oplist then
  begin
    WriteLn(' FAILED.');
    tset2d_failed := true
  end;
 op:=tset2d_dm;
 tset2d_oplist:=tset2d_oplist+[tset2d_Dm];
 if op in tset2d_oplist then
  WriteLn(' PASSED.')
 else
   begin
    WriteLn(' FAILED.');
    tset2d_failed := true
  end;
end;

Procedure tset2d_SmallSetByte;
{ SET_SET_BYTE }
var
 op : tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 Write('TESTING SET_BYTE(1):');
 op:=tset2d_DA;
 tset2d_oplist:=[];
 tset2d_oplist:=tset2d_oplist+[op];
 if op in tset2d_oplist then
 Begin
  WriteLn(' PASSED.');
 end
 else
 Begin
  WriteLn(' FAILED.');
  tset2d_failed := true;
 end;
end;


Procedure tset2d_SmallAddSets;
{ SET_ADD_SETS }
var
 op2list :set of tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_DA]+[tset2d_DC];
 op2list:=[tset2d_DB];
 tset2d_oplist:=op2list+tset2d_oplist;
 if tset2d_DA in tset2d_oplist then
  if tset2d_DC in tset2d_oplist then
   if tset2d_DB in tset2d_oplist then
    WriteLn('TESTING SET_ADD_SETS: PASSED.')
   else
    begin
      WriteLn('TESTING ADD_SETS: FAILED.');
      tset2d_failed := true
    end
  else
   begin
     WriteLn('TESTING ADD_SETS: FAILED.');
     tset2d_failed := true
   end
 else
  begin
    WriteLn('TESTING ADD_SETS: FAILED.');
    tset2d_failed := true
  end;
end;

Procedure tset2d_SmallSubsets;
{ SET_SUB_SETS }
var
 op2list :set of tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_DA]+[tset2d_DC];
 op2list:=[tset2d_DA]+[tset2d_DC];
 tset2d_oplist:=op2list-tset2d_oplist;
 if (tset2d_DA in tset2d_oplist) or (tset2d_DB in tset2d_oplist) or (tset2d_DC in tset2d_oplist) then
  begin
    WriteLn('TESTING SUB_SETS: FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING SUB_SETS: PASSED.')
end;

Procedure tset2d_SmallCompSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_DA]+[tset2d_DC];
 op2list:=[tset2d_DA]+[tset2d_DC];
 if tset2d_oplist=op2list then
  WriteLn('TESTING COMP_SETS(1): PASSED.')
 else
  begin
    WriteLn('TESTING COMP_SETS(1): FAILED.');
    tset2d_failed := true
  end;
 tset2d_oplist:=[tset2d_DA];
 if tset2d_oplist=op2list then
  begin
    WriteLn('TESTING COMP_SETS(2): FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING COMP_SETS(2): PASSED.');
end;

Procedure tset2d_SmallMulSets;
{ SET_COMP_SETS }
var
 op2list :set of tset2d_myenum;
 tset2d_oplist: set of tset2d_myenum;
Begin
 op2list:=[];
 tset2d_oplist:=[];
 tset2d_oplist:=[tset2d_DA]+[tset2d_DC];
 op2list:=[tset2d_DA];
 tset2d_oplist:=tset2d_oplist*op2list;
 if tset2d_DC in tset2d_oplist then
  begin
    WriteLn('TESTING MUL_SETS(1): FAILED.');
    tset2d_failed := true
  end
 else
  WriteLn('TESTING MUL_SETS(1): PASSED.');
 if tset2d_DA in tset2d_oplist  then
  WriteLn('TESTING MUL_SETS(2): PASSED.')
 else
  begin
    WriteLn('TESTING MUL_SETS(2): FAILED.');
    tset2d_failed := true
  end;
end;

const
 tset2d_b: tset2d_myenum = (tset2d_dA);
var
 tset2d_enum: set of tset2d_myenum;
 tset2d_oplist: set of tset2d_tasmop;
 tset2d_l : word;

{$pop}

{ Case tset3.pas }
{$push}
{$packset 1}
type
  tset3_tmini = 0..7;
  tset3_tminiset = set of tset3_tmini;


procedure tset3_do_error(w : word);
  begin
    writeln('Error: ',w);
    halt(1);
  end;

var
  tset3_s1,tset3_s2,tset3_s3 : tset3_tminiset;
  tset3_b : byte;
  tset3_m : tset3_tmini;

{$pop}

{ Case tvarset1.pas }
{$push}
{$packset 1}
type
  tvarset1_tset8 = set of 0..63;

procedure tvarset1_do_error(l : longint);

  begin
     writeln('Error near number ',l);
     halt(1);
  end;

var
  tvarset1_set8_1,tvarset1_set8_2,tvarset1_set8_3 : tvarset1_tset8;
  tvarset1_i,tvarset1_j : longint;

{$pop}

begin

{ Case tpushpop3.pas }
{$push}
{$PackSet 1}
{$Push}
{$PackSet 2}
{$Pop}
begin
  if SizeOf(tpushpop3_TTestSet1) <> 1 then
    Halt(1);
  if SizeOf(tpushpop3_TTestSet2) <> 2 then
    Halt(2);
  if SizeOf(tpushpop3_TTestSet3) <> 1 then
    Halt(3);
  Writeln('ok');
end;
{$pop}

{ Case tset2.pas }
{$push}

Begin
{ small sets }
 tset2_enum:=[];
 { add }
 tset2_enum:=tset2_enum+[tset2_da];
 { subtract }
 tset2_enum:=tset2_enum-[tset2_da];
 if tset2_DA in tset2_enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 tset2_oplist := [tset2_A_LABEL];
 { secondin test         }
 if tset2_A_LABEL in tset2_oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.')
 else
   begin
    tset2_failed := true
  end;

 { }
 tset2_oplist:=[];
 if tset2_A_LABEL in tset2_oplist then
   begin
    WriteLn('SECOND IN FAILED.');
    tset2_failed := true
  end;
 tset2_SecondinSets;
 tset2_SetSetByte;
 tset2_SetAddSets;
 tset2_SetSubSets;
 tset2_SetCompSets;
 tset2_SetMulSets;
 WRITELN('SMALL SETS:');
 tset2_SmallInSets;
 tset2_SmallAddSets;
 tset2_SmallSubSets;
 tset2_SmallCompSets;
 tset2_SmallMulSets;
 tset2_l:=word(tset2_A_CPRESTORE);
 if tset2_l = word(tset2_A_CPRESTORE) then
  Begin
  end
  else tset2_failed := true;

  if tset2_failed then
    begin
      WriteLn('One or more test failed');
      Halt(1);
    end;
end;
{$pop}

{ Case tset2a.pas }
{$push}
{$packset 1}
Begin
{ small sets }
 tset2a_enum:=[];
 { add }
 tset2a_enum:=tset2a_enum+[tset2a_da];
 { subtract }
 tset2a_enum:=tset2a_enum-[tset2a_da];
 if tset2a_DA in tset2a_enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 tset2a_oplist := [tset2a_A_LABEL];
 { secondin test         }
 if tset2a_A_LABEL in tset2a_oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.')
 else
   begin
    tset2a_failed := true
  end;

 { }
 tset2a_oplist:=[];
 if tset2a_A_LABEL in tset2a_oplist then
   begin
    WriteLn('SECOND IN FAILED.');
    tset2a_failed := true
  end;
 tset2a_SecondinSets;
 tset2a_SetSetByte;
 tset2a_SetAddSets;
 tset2a_SetSubSets;
 tset2a_SetCompSets;
 tset2a_SetMulSets;
 WRITELN('SMALL SETS:');
 tset2a_SmallInSets;
 tset2a_SmallAddSets;
 tset2a_SmallSubSets;
 tset2a_SmallCompSets;
 tset2a_SmallMulSets;
 tset2a_l:=word(tset2a_A_CPRESTORE);
 if tset2a_l = word(tset2a_A_CPRESTORE) then
  Begin
  end
  else tset2a_failed := true;

  if tset2a_failed then
    begin
      WriteLn('One or more test failed');
      Halt(1);
    end;
end;
{$pop}

{ Case tset2b.pas }
{$push}
{$packset 2}
Begin
{ small sets }
 tset2b_enum:=[];
 { add }
 tset2b_enum:=tset2b_enum+[tset2b_da];
 { subtract }
 tset2b_enum:=tset2b_enum-[tset2b_da];
 if tset2b_DA in tset2b_enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 tset2b_oplist := [tset2b_A_LABEL];
 { secondin test         }
 if tset2b_A_LABEL in tset2b_oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.')
 else
   begin
    tset2b_failed := true
  end;

 { }
 tset2b_oplist:=[];
 if tset2b_A_LABEL in tset2b_oplist then
   begin
    WriteLn('SECOND IN FAILED.');
    tset2b_failed := true
  end;
 tset2b_SecondinSets;
 tset2b_SetSetByte;
 tset2b_SetAddSets;
 tset2b_SetSubSets;
 tset2b_SetCompSets;
 tset2b_SetMulSets;
 WRITELN('SMALL SETS:');
 tset2b_SmallInSets;
 tset2b_SmallAddSets;
 tset2b_SmallSubSets;
 tset2b_SmallCompSets;
 tset2b_SmallMulSets;
 tset2b_l:=word(tset2b_A_CPRESTORE);
 if tset2b_l = word(tset2b_A_CPRESTORE) then
  Begin
  end
  else tset2b_failed := true;

  if tset2b_failed then
    begin
      WriteLn('One or more test failed');
      Halt(1);
    end;
end;
{$pop}

{ Case tset2c.pas }
{$push}
{$packset 1}
Begin
{ small sets }
 tset2c_enum:=[];
 { add }
 tset2c_enum:=tset2c_enum+[tset2c_da];
 { subtract }
 tset2c_enum:=tset2c_enum-[tset2c_da];
 if tset2c_DA in tset2c_enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 tset2c_oplist := [tset2c_A_LABEL];
 { secondin test         }
 if tset2c_A_LABEL in tset2c_oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.')
 else
   begin
    tset2c_failed := true
  end;

 { }
 tset2c_oplist:=[];
 if tset2c_A_LABEL in tset2c_oplist then
   begin
    WriteLn('SECOND IN FAILED.');
    tset2c_failed := true
  end;
 tset2c_SecondinSets;
 tset2c_SetSetByte;
 tset2c_SetAddSets;
 tset2c_SetSubSets;
 tset2c_SetCompSets;
 tset2c_SetMulSets;
 WRITELN('SMALL SETS:');
 tset2c_SmallInSets;
 tset2c_SmallAddSets;
 tset2c_SmallSubSets;
 tset2c_SmallCompSets;
 tset2c_SmallMulSets;
 tset2c_l:=word(tset2c_A_CPRESTORE);
 if tset2c_l = word(tset2c_A_CPRESTORE) then
  Begin
  end
  else tset2c_failed := true;

  if tset2c_failed then
    begin
      WriteLn('One or more test failed');
      Halt(1);
    end;
end;
{$pop}

{ Case tset2d.pas }
{$push}
{$packset 2}
Begin
{ small sets }
 tset2d_enum:=[];
 { add }
 tset2d_enum:=tset2d_enum+[tset2d_da];
 { subtract }
 tset2d_enum:=tset2d_enum-[tset2d_da];
 if tset2d_DA in tset2d_enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 tset2d_oplist := [tset2d_A_LABEL];
 { secondin test         }
 if tset2d_A_LABEL in tset2d_oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.')
 else
   begin
    tset2d_failed := true
  end;

 { }
 tset2d_oplist:=[];
 if tset2d_A_LABEL in tset2d_oplist then
   begin
    WriteLn('SECOND IN FAILED.');
    tset2d_failed := true
  end;
 tset2d_SecondinSets;
 tset2d_SetSetByte;
 tset2d_SetAddSets;
 tset2d_SetSubSets;
 tset2d_SetCompSets;
 tset2d_SetMulSets;
 WRITELN('SMALL SETS:');
 tset2d_SmallInSets;
 tset2d_SmallAddSets;
 tset2d_SmallSubSets;
 tset2d_SmallCompSets;
 tset2d_SmallMulSets;
 tset2d_l:=word(tset2d_A_CPRESTORE);
 if tset2d_l = word(tset2d_A_CPRESTORE) then
  Begin
  end
  else tset2d_failed := true;

  if tset2d_failed then
    begin
      WriteLn('One or more test failed');
      Halt(1);
    end;
end;
{$pop}

{ Case tset3.pas }
{$push}
{$packset 1}
begin
  tset3_s1:=[];
  if tset3_s1<>[] then
    tset3_do_error(1);

  tset3_s1:=[1];
  if tset3_s1<>[1] then
    tset3_do_error(2);

  tset3_s2:=[2,3];
  if tset3_s2<>[2,3] then
    tset3_do_error(3);

  tset3_b:=6;
  tset3_s3:=[tset3_b,7];
  if tset3_s3<>[6,7] then
    tset3_do_error(4);

  tset3_s1:=tset3_s1+tset3_s2;
  if tset3_s1<>[1..3] then
    tset3_do_error(5);

  tset3_s2:=tset3_s1;

  if not(tset3_s1=tset3_s2) then
    tset3_do_error(6);

  tset3_s3:=[4];

  include(tset3_s1,4);
  if tset3_s1<>[1..4] then
    tset3_do_error(7);

  tset3_s2:=tset3_s1;

  exclude(tset3_s1,4);
  if tset3_s1<>[1..3] then
    tset3_do_error(8);

  tset3_s2:=tset3_s2-tset3_s3;
  if tset3_s1<>tset3_s2 then
    tset3_do_error(9);

  tset3_b:=4;
  include(tset3_s1,tset3_b);
  if tset3_s1<>[1..4] then
    tset3_do_error(10);

  tset3_s2:=tset3_s2+[tset3_b];
  if tset3_s1<>tset3_s2 then
    tset3_do_error(11);

  tset3_s2:=tset3_s1;
  tset3_m:=3;
  tset3_s1:=tset3_s1-[tset3_m];
  exclude(tset3_s2,tset3_m);
  if tset3_s1<>tset3_s2 then
    tset3_do_error(12);

  writeln('ok');
end;
{$pop}

{ Case tvarset1.pas }
{$push}
{$packset 1}
begin
  if sizeof(tvarset1_tset8)<>8 then
    tvarset1_do_error(1);

  tvarset1_set8_1:=[42];
  tvarset1_set8_2:=tvarset1_set8_1;
  if tvarset1_set8_1<>tvarset1_set8_2 then
    tvarset1_do_error(2);

  tvarset1_set8_2:=[41,42];
  if tvarset1_set8_1=tvarset1_set8_2 then
    tvarset1_do_error(3);

  if tvarset1_set8_1>=tvarset1_set8_2 then
    tvarset1_do_error(4);

  tvarset1_set8_1:=[21..50];
  if tvarset1_set8_1<=tvarset1_set8_2 then
    tvarset1_do_error(5);

  tvarset1_set8_1:=[1];
  tvarset1_set8_2:=[2];
  tvarset1_set8_3:=tvarset1_set8_1+tvarset1_set8_2;
  if tvarset1_set8_3<>[1,2] then
    tvarset1_do_error(6);

  tvarset1_i:=55;
  tvarset1_set8_1:=[tvarset1_i];
  if tvarset1_set8_1<>[55] then
    tvarset1_do_error(7);

  tvarset1_i:=55;
  tvarset1_j:=60;
  tvarset1_set8_1:=[tvarset1_i,tvarset1_j];
  if tvarset1_set8_1<>[55,60] then
    tvarset1_do_error(8);

  tvarset1_i:=55;
  tvarset1_j:=60;
  tvarset1_set8_1:=[tvarset1_i..tvarset1_j];
  if tvarset1_set8_1<>[55..60] then
    tvarset1_do_error(9);
end;
{$pop}

end.
