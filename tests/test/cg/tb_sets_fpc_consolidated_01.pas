{ Consolidated sets regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case taddset.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondadd()                                      }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondsetelement()                             }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}



var
  taddset_Err : boolean;

type
       { DO NOT CHANGE THE VALUES OF THESE ENUMERATIONS! }
       taddset_tsmallenum = (taddset_dA,taddset_dB,taddset_dC,taddset_dd,taddset_de,taddset_df,taddset_dg,taddset_dh,taddset_di,taddset_dj,taddset_dk,taddset_dl,taddset_dm,taddset_dn,taddset_dop,taddset_dp,taddset_dq,taddset_dr);
       taddset_tasmop = (taddset_A_ABCD,
         taddset_A_ADD,taddset_A_ADDA,taddset_A_ADDI,taddset_A_ADDQ,taddset_A_ADDX,taddset_A_AND,taddset_A_ANDI,
         taddset_A_ASL,taddset_A_ASR,taddset_A_BCC,taddset_A_BCS,taddset_A_BEQ,taddset_A_BGE,taddset_A_BGT,taddset_A_BHI,
         taddset_A_BLE,taddset_A_BLS,taddset_A_BLT,taddset_A_BMI,taddset_A_BNE,taddset_A_BPL,taddset_A_BVC,taddset_A_BVS,
         taddset_A_BCHG,taddset_A_BCLR,taddset_A_BRA,taddset_A_BSET,taddset_A_BSR,taddset_A_BTST,taddset_A_CHK,
         taddset_A_CLR,taddset_A_CMP,taddset_A_CMPA,taddset_A_CMPI,taddset_A_CMPM,taddset_A_DBCC,taddset_A_DBCS,taddset_A_DBEQ,taddset_A_DBGE,
         taddset_A_DBGT,taddset_A_DBHI,taddset_A_DBLE,taddset_A_DBLS,taddset_A_DBLT,taddset_A_DBMI,taddset_A_DBNE,taddset_A_DBRA,
         taddset_A_DBPL,taddset_A_DBT,taddset_A_DBVC,taddset_A_DBVS,taddset_A_DBF,taddset_A_DIVS,taddset_A_DIVU,
         taddset_A_EOR,taddset_A_EORI,taddset_A_EXG,taddset_A_ILLEGAL,taddset_A_EXT,taddset_A_JMP,taddset_A_JSR,
         taddset_A_LEA,taddset_A_LINK,taddset_A_LSL,taddset_A_LSR,taddset_A_MOVE,taddset_A_MOVEA,taddset_A_MOVEI,taddset_A_MOVEQ,
         taddset_A_MOVEM,taddset_A_MOVEP,taddset_A_MULS,taddset_A_MULU,taddset_A_NBCD,taddset_A_NEG,taddset_A_NEGX,
         taddset_A_NOP,taddset_A_NOT,taddset_A_OR,taddset_A_ORI,taddset_A_PEA,taddset_A_ROL,taddset_A_ROR,taddset_A_ROXL,
         taddset_A_ROXR,taddset_A_RTR,taddset_A_RTS,taddset_A_SBCD,taddset_A_SCC,taddset_A_SCS,taddset_A_SEQ,taddset_A_SGE,
         taddset_A_SGT,taddset_A_SHI,taddset_A_SLE,taddset_A_SLS,taddset_A_SLT,taddset_A_SMI,taddset_A_SNE,
         taddset_A_SPL,taddset_A_ST,taddset_A_SVC,taddset_A_SVS,taddset_A_SF,taddset_A_SUB,taddset_A_SUBA,taddset_A_SUBI,taddset_A_SUBQ,
         taddset_A_SUBX,taddset_A_SWAP,taddset_A_TAS,taddset_A_TRAP,taddset_A_TRAPV,taddset_A_TST,taddset_A_UNLK,
         taddset_A_RTE,taddset_A_RESET,taddset_A_STOP,
         { MC68010 instructions }
         taddset_A_BKPT,taddset_A_MOVEC,taddset_A_MOVES,taddset_A_RTD,
         { MC68020 instructions }
         taddset_A_BFCHG,taddset_A_BFCLR,taddset_A_BFEXTS,taddset_A_BFEXTU,taddset_A_BFFFO,
         taddset_A_BFINS,taddset_A_BFSET,taddset_A_BFTST,taddset_A_CALLM,taddset_A_CAS,taddset_A_CAS2,
         taddset_A_CHK2,taddset_A_CMP2,taddset_A_DIVSL,taddset_A_DIVUL,taddset_A_EXTB,taddset_A_PACK,taddset_A_RTM,
         taddset_A_TRAPCC,taddset_A_TRACS,taddset_A_TRAPEQ,taddset_A_TRAPF,taddset_A_TRAPGE,taddset_A_TRAPGT,
         taddset_A_TRAPHI,taddset_A_TRAPLE,taddset_A_TRAPLS,taddset_A_TRAPLT,taddset_A_TRAPMI,taddset_A_TRAPNE,
         taddset_A_TRAPPL,taddset_A_TRAPT,taddset_A_TRAPVC,taddset_A_TRAPVS,taddset_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         taddset_A_FABS,taddset_A_FADD,
         taddset_A_FBEQ,taddset_A_FBNE,taddset_A_FBNGT,taddset_A_FBGT,taddset_A_FBGE,taddset_A_FBNGE,
         taddset_A_FBLT,taddset_A_FBNLT,taddset_A_FBLE,taddset_A_FBGL,taddset_A_FBNGL,taddset_A_FBGLE,taddset_A_FBNGLE,
         taddset_A_FDBEQ,taddset_A_FDBNE,taddset_A_FDBGT,taddset_A_FDBNGT,taddset_A_FDBGE,taddset_A_FDBNGE,
         taddset_A_FDBLT,taddset_A_FDBNLT,taddset_A_FDBLE,taddset_A_FDBGL,taddset_A_FDBNGL,taddset_A_FDBGLE,taddset_A_FBDNGLE,
         taddset_A_FSEQ,taddset_A_FSNE,taddset_A_FSGT,taddset_A_FSNGT,taddset_A_FSGE,taddset_A_FSNGE,
         taddset_A_FSLT,taddset_A_FSNLT,taddset_A_FSLE,taddset_A_FSGL,taddset_A_FSNGL,taddset_A_FSGLE,taddset_A_FSNGLE,
         taddset_A_FCMP,taddset_A_FDIV,taddset_A_FMOVE,taddset_A_FMOVEM,
         taddset_A_FMUL,taddset_A_FNEG,taddset_A_FNOP,taddset_A_FSQRT,taddset_A_FSUB,taddset_A_FSGLDIV,
         taddset_A_FSFLMUL,taddset_A_FTST,
         taddset_A_FTRAPEQ,taddset_A_FTRAPNE,taddset_A_FTRAPGT,taddset_A_FTRAPNGT,taddset_A_FTRAPGE,taddset_A_FTRAPNGE,
         taddset_A_FTRAPLT,taddset_A_FTRAPNLT,taddset_A_FTRAPLE,taddset_A_FTRAPGL,taddset_A_FTRAPNGL,taddset_A_FTRAPGLE,taddset_A_FTRAPNGLE,
         { Protected instructions }
         taddset_A_CPRESTORE,taddset_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         taddset_A_FRESTORE,taddset_A_FSAVE,taddset_A_PFLUSH,taddset_A_PFLUSHA,taddset_A_PLOAD,taddset_A_PMOVE,taddset_A_PTEST,
         { Useful for assembly langage output }
         taddset_A_LABEL,taddset_A_NONE);



type
  taddset_topset = set of taddset_tasmop;
  taddset_tsmallset = set of taddset_tsmallenum;

const

   { NORMAL SETS }
   taddset_constset1 : array[1..3] of taddset_topset =
   (
       { 66 }    { 210 }  { 225 }
     ([taddset_A_MOVE,    { 66  : LONG 2 - BIT 2  }
       taddset_A_FTST,    { 210 : LONG 6 - BIT 18 }
       taddset_A_CPSAVE]),{ 225 : LONG 7 - BIT 1 }
       { 1..8 }
     ([taddset_A_ADD..taddset_A_ASL]),
       { 134 }
     ([taddset_A_CHK2])
   );

   taddset_constset2 : array[1..3] of taddset_topset =
   (
     ([taddset_A_MOVE,taddset_A_FTST,taddset_A_CPSAVE]),
     ([taddset_A_ADD..taddset_A_ASL]),
     ([taddset_A_CHK2])
   );

   { SMALL SETS }
   taddset_constset3 : array[1..3] of taddset_tsmallset =
   (
     ([taddset_DA,             { 0 :  LONG 0 : bit 0 }
       taddset_DD,             { 3 :  LONG 0 : bit 3 }
       taddset_DM]),           { 12 :  LONG 0 : bit 12  }
     ([taddset_DB..taddset_DI]),       { 1..8 : LONG 0 : bits 1-8  }
     ([taddset_DR])            { 17 :  LONG 0 : bit 17 }
   );

   taddset_constset4 : array[1..3] of taddset_tsmallset =
   (
     ([taddset_DA,taddset_DD,taddset_DM]),
     ([taddset_DB..taddset_DI]),
     ([taddset_DR])
   );


 procedure taddset_CheckPassed(passed:boolean);
 begin
   if passed then
     WriteLn('Success.')
   else
     begin
       WriteLn('Failure.');
       Halt(1);
       taddset_Err:=true;
     end;
 end;

 procedure taddset_SetTestEqual;
 { FPC_SET_COMP_SETS }
  var
    op2list :set of taddset_tasmop;
    oplist: set of taddset_tasmop;
    passed : boolean;
  Begin
   Write('Normal Set == Normal Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if not (taddset_constset1[2] = taddset_constset2[2]) then
     passed := false;
   if (taddset_constset1[1] = taddset_constset2[2]) then
     passed := false;
   if not (taddset_constset1[1] = [taddset_A_MOVE,taddset_A_FTST,taddset_A_CPSAVE]) then
     passed := false;
    taddset_CheckPassed(passed);
  end;

 procedure taddset_SetTestNotEqual;
 { FPC_SET_COMP_SETS }
  var
    op2list :set of taddset_tasmop;
    oplist: set of taddset_tasmop;
    passed : boolean;
  Begin
   Write('Normal Set <> Normal Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if (taddset_constset1[2] <> taddset_constset2[2]) then
     passed := false;
   if not (taddset_constset1[1] <> taddset_constset2[2]) then
     passed := false;
{   if ( [A_ADD] <> [A_ADD] ) then optimized out.
     passed := false;
   if ( [A_BLE..A_BPL] <> [A_BLE..A_BPL] ) then
     passed := false; }
   if (taddset_constset1[1] <> [taddset_A_MOVE,taddset_A_FTST,taddset_A_CPSAVE]) then
     passed := false;
    taddset_CheckPassed(passed);
  end;

  procedure taddset_SetTestLt;
  var
    op2list :set of taddset_tasmop;
    oplist: set of taddset_tasmop;
    passed : boolean;
   begin
    Write('Normal Set <= Normal Set test...');
    passed := true;
    if taddset_constset1[1] <= taddset_constset2[2] then
      passed := false;
    oplist := [];
    op2list := [taddset_A_MOVE];
    if op2list <= oplist then
     passed := false;
    oplist := [taddset_A_MOVE,taddset_A_CPRESTORE..taddset_A_CPSAVE];
    if oplist <= op2list then
     passed := false;
    taddset_CheckPassed(passed);
   end;

  Procedure taddset_SetTestAddOne;
 { FPC_SET_SET_BYTE }
 { FPC_SET_ADD_SETS }
    var
     op : taddset_tasmop;
     oplist: set of taddset_tasmop;
  Begin
    Write('Set + Set element testing...');
    op:=taddset_A_LABEL;
    oplist:=[];
    oplist:=oplist+[op];
    taddset_CheckPassed(oplist = [taddset_A_LABEL]);
  end;

Procedure taddset_SetTestAddTwo;
{ SET_ADD_SETS }
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
Begin
 Write('Complex Set + Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset_A_MOVE]+[taddset_A_JSR];
 op2list:=[taddset_A_LABEL];
 oplist:=op2list+oplist;
 taddset_CheckPassed(oplist = [taddset_A_MOVE,taddset_A_JSR,taddset_A_LABEL]);
end;





Procedure taddset_SetTestSubOne;
{ SET_SUB_SETS }
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
 op :taddset_tasmop;
 passed : boolean;
Begin
 Write('Set - Set element testing...');
 passed := true;
 op2list:=[];
 oplist:=[];
 op := taddset_A_TRACS;
 oplist:=[taddset_A_MOVE]+[taddset_A_JSR]+[op];
 op2list:=[taddset_A_MOVE]+[taddset_A_JSR];
 oplist:=oplist-op2list;
 if oplist <> [taddset_A_TRACS] then
   passed := false;

 oplist:=[taddset_A_MOVE]+[taddset_A_JSR]+[op];
 op2list:=[taddset_A_MOVE]+[taddset_A_JSR];
 oplist:=op2list-oplist;
 if oplist <> [] then
   passed := false;
 taddset_CheckPassed(passed);
end;

Procedure taddset_SetTestSubTwo;
{ FPC_SET_SUB_SETS }
const
 b: taddset_tasmop = (taddset_A_BSR);
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
 op : taddset_tasmop;
 passed : boolean;
Begin
 Write('Complex Set - Set element testing...');
 op := taddset_A_BKPT;
 passed := true;
 oplist:=[taddset_A_MOVE]+[taddset_A_JSR]-[op];
 op2list:=[taddset_A_MOVE]+[taddset_A_JSR];
 if oplist <> op2list then
   passed := false;
 oplist := [taddset_A_MOVE];
 oplist := oplist - [taddset_A_MOVE];
 if oplist <> [] then
   passed := false;
 oplist := oplist + [b];
 if oplist <> [b] then
   passed := false;
 oplist := oplist - [b];
 if oplist <> [] then
   passed := false;
 taddset_CheckPassed(passed);
end;


Procedure taddset_SetTestMulSets;
{ FPC_SET_MUL_SETS }
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
 passed : boolean;
Begin
 passed := true;
 Write('Set * Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset_A_MOVE]+[taddset_A_JSR];
 op2list:=[taddset_A_MOVE];
 oplist:=oplist*op2list;
 if oplist <> [taddset_A_JSR] then
   passed := false;
 oplist := [taddset_A_MOVE,taddset_A_FTST];
 op2list := [taddset_A_MOVE,taddset_A_FTST];
 oplist := oplist * op2list;
 if oplist <> [taddset_A_MOVE,taddset_A_FTST] then
   passed := false;
 taddset_CheckPassed(passed);
end;

procedure taddset_SetTestRange;
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
 passed : boolean;
 op1 : taddset_tasmop;
 op2 : taddset_tasmop;
begin
 passed := true;
 Write('Range Set + element testing...');
 op1 := taddset_A_ADD;
 op2 := taddset_A_ASL;
 oplist := [];
 oplist := [op1..op2];
 if oplist <> taddset_constset1[2] then
   passed := false;
 taddset_CheckPassed(passed);
end;

procedure taddset_SetTestByte;
var
 op2list :set of taddset_tasmop;
 oplist: set of taddset_tasmop;
 passed : boolean;
 op1 : taddset_tasmop;
 op2 : taddset_tasmop;
 op : taddset_tasmop;
begin
 Write('Simple Set + element testing...');
 passed := true;
 op := taddset_A_LABEL;
 oplist := [taddset_A_MOVE,op,taddset_A_JSR];
 if oplist <> [taddset_A_MOVE,taddset_A_LABEL,taddset_A_JSR] then
   passed := false;
 taddset_CheckPassed(passed);
end;


{------------------------------ TESTS FOR SMALL VALUES ---------------------}
 procedure taddset_SmallSetTestEqual;
  var
    op2list :set of taddset_tsmallenum;
    oplist: set of taddset_tsmallenum;
    passed : boolean;
  Begin
   Write('Small Set == Small Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if not (taddset_constset3[2] = taddset_constset4[2]) then
     passed := false;
   if (taddset_constset3[1] = taddset_constset4[2]) then
     passed := false;
   if not (taddset_constset3[1] = [taddset_DA,taddset_DD,taddset_DM]) then
     passed := false;
 taddset_CheckPassed(passed);
  end;

 procedure taddset_SmallSetTestNotEqual;
  var
    op2list :set of taddset_tsmallenum;
    oplist: set of taddset_tsmallenum;
    passed : boolean;
  Begin
   Write('Small Set <> Small Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if (taddset_constset3[2] <> taddset_constset4[2]) then
     passed := false;
   if not (taddset_constset3[1] <> taddset_constset4[2]) then
     passed := false;
{   if ( [A_ADD] <> [A_ADD] ) then optimized out.
     passed := false;
   if ( [A_BLE..A_BPL] <> [A_BLE..A_BPL] ) then
     passed := false; }
   if (taddset_constset3[1] <> [taddset_DA,taddset_DD,taddset_DM]) then
     passed := false;
 taddset_CheckPassed(passed);
  end;

  procedure taddset_SmallSetTestLt;
  var
    op2list :set of taddset_tsmallenum;
    oplist: set of taddset_tsmallenum;
    passed : boolean;
   begin
    Write('Small Set <= Small Set test...');
    passed := true;
    if taddset_constset3[1] <= taddset_constset4[2] then
      passed := false;
    oplist := [];
    op2list := [taddset_DC];
    if op2list <= oplist then
     passed := false;
    oplist := [taddset_DC,taddset_DF..taddset_DM];
    if oplist <= op2list then
     passed := false;
 taddset_CheckPassed(passed);
   end;

  Procedure taddset_SmallSetTestAddOne;
    var
     op : taddset_tsmallenum;
     oplist: set of taddset_tsmallenum;
  Begin
    Write('Small Set + Small Set element testing...');
    op:=taddset_DG;
    oplist:=[];
    oplist:=oplist+[op];
    taddset_CheckPassed( oplist = [taddset_DG] );
  end;

Procedure taddset_SmallSetTestAddTwo;
var
 op2list :set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
Begin
 Write('Small Complex Set + Small Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset_DG]+[taddset_DI];
 op2list:=[taddset_DM];
 oplist:=op2list+oplist;
 taddset_CheckPassed( oplist = [taddset_DG,taddset_DI,taddset_DM] );
end;


Procedure taddset_SmallSetTestSubOne;
var
 op2list :set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
 op :taddset_tsmallenum;
 passed : boolean;
Begin
 Write('Small Set - Small Set element testing...');
 passed := true;
 op2list:=[];
 oplist:=[];
 op := taddset_DL;
 oplist:=[taddset_DG]+[taddset_DI]+[op];
 op2list:=[taddset_DG]+[taddset_DI];
 oplist:=oplist-op2list;
 if oplist <> [taddset_DL] then
   passed := false;

 oplist:=[taddset_DG]+[taddset_DI]+[op];
 op2list:=[taddset_DG]+[taddset_DI];
 oplist:=op2list-oplist;
 if oplist <> [] then
   passed := false;
 taddset_CheckPassed(passed);
end;

Procedure taddset_SmallSetTestSubTwo;
const
 b: taddset_tsmallenum = (taddset_DH);
var
 op2list :set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
 op : taddset_tsmallenum;
 passed : boolean;
Begin
 Write('Small Complex Set - Small Set element testing...');
 op := taddset_DL;
 passed := true;
 oplist:=[taddset_DG]+[taddset_DI]-[op];
 op2list:=[taddset_DG]+[taddset_DI];
 if oplist <> op2list then
   passed := false;
 oplist := [taddset_DG];
 oplist := oplist - [taddset_DG];
 if oplist <> [] then
   passed := false;
 oplist := oplist + [b];
 if oplist <> [b] then
   passed := false;
 oplist := oplist - [b];
 if oplist <> [] then
   passed := false;
 taddset_CheckPassed(passed);
end;


Procedure taddset_SmallSetTestMulSets;
var
 op2list : set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
 passed : boolean;
Begin
 passed := true;
 Write('Small Set * Small Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset_DG]+[taddset_DI];
 op2list:=[taddset_DG];
 oplist:=oplist*op2list;
 if oplist <> [taddset_DI] then
   passed := false;
 oplist := [taddset_DG,taddset_DK];
 op2list := [taddset_DG,taddset_DK];
 oplist := oplist * op2list;
 if oplist <> [taddset_DG,taddset_DK] then
   passed := false;
 taddset_CheckPassed(passed);
end;

procedure taddset_SmallSetTestRange;
var
 op2list :set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
 passed : boolean;
 op1 : taddset_tsmallenum;
 op2 : taddset_tsmallenum;
begin
 passed := true;
 Write('Small Range Set + element testing...');
 op1 := taddset_DB;
 op2 := taddset_DI;
 oplist := [];
 oplist := [op1..op2];
 if oplist <> taddset_constset3[2] then
   passed := false;
 taddset_CheckPassed(passed);
end;

procedure taddset_SmallSetTestByte;
var
 op2list : set of taddset_tsmallenum;
 oplist: set of taddset_tsmallenum;
 passed : boolean;
 op1 : taddset_tsmallenum;
 op2 : taddset_tsmallenum;
 op : taddset_tsmallenum;
begin
 Write('Small Simple Set + element testing...');
 passed := true;
 op := taddset_DD;
 oplist := [taddset_DG,op,taddset_DI];
 if oplist <> [taddset_DG,taddset_DD,taddset_DI] then
   passed := false;
 taddset_CheckPassed(passed);
end;

(*

const
 b: myenum = (dA);
var
 enum: set of myenum;
 oplist: set of tasmop;
 l : word;
Begin
  SetTestEqual;
  SetTestNotEqual;
{ small sets }
 enum:=[];
 { add }
 enum:=enum+[da];
 { subtract }
 enum:=enum-[da];
 if DA in enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 oplist := [A_LABEL];
 { secondin test         }
 if A_LABEL in oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.');
 { }
 oplist:=[];
 if A_LABEL in oplist then
  WriteLn('SECOND IN FAILED.');
{ SecondinSets;}
 SetSetByte;
 SetAddSets;
 SetSubSets;
 SetCompSets;
 SetMulSets;
 WRITELN('SMALL SETS:');
 SmallInSets;
 SmallAddSets;
 SmallSubSets;
 SmallCompSets;
 SmallMulSets;
 l:=word(A_CPRESTORE);
 if l = word(A_CPRESTORE) then
  Begin
  end;

*)

{$pop}

{ Case taddset3.pas }
{$push}
{$ifdef fpc}
{$packset 1}
{$endif}

{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondadd()                                      }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondsetelement()                             }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}



var
  taddset3_Err : boolean;

type
       { DO NOT CHANGE THE VALUES OF THESE ENUMERATIONS! }
       taddset3_tsmallenum = (taddset3_dA=23,taddset3_dB,taddset3_dC,taddset3_dd,taddset3_de,taddset3_df,taddset3_dg,taddset3_dh,taddset3_di,taddset3_dj,taddset3_dk,taddset3_dl,taddset3_dm,taddset3_dn,taddset3_dop,taddset3_dp,taddset3_dq,taddset3_dr);
       taddset3_tsmallsubenum = taddset3_dk..taddset3_dr;
       taddset3_tasmop = (taddset3_A_ABCD=13,
         taddset3_A_ADD,taddset3_A_ADDA,taddset3_A_ADDI,taddset3_A_ADDQ,taddset3_A_ADDX,taddset3_A_AND,taddset3_A_ANDI,
         taddset3_A_ASL,taddset3_A_ASR,taddset3_A_BCC,taddset3_A_BCS,taddset3_A_BEQ,taddset3_A_BGE,taddset3_A_BGT,taddset3_A_BHI,
         taddset3_A_BLE,taddset3_A_BLS,taddset3_A_BLT,taddset3_A_BMI,taddset3_A_BNE,taddset3_A_BPL,taddset3_A_BVC,taddset3_A_BVS,
         taddset3_A_BCHG,taddset3_A_BCLR,taddset3_A_BRA,taddset3_A_BSET,taddset3_A_BSR,taddset3_A_BTST,taddset3_A_CHK,
         taddset3_A_CLR,taddset3_A_CMP,taddset3_A_CMPA,taddset3_A_CMPI,taddset3_A_CMPM,taddset3_A_DBCC,taddset3_A_DBCS,taddset3_A_DBEQ,taddset3_A_DBGE,
         taddset3_A_DBGT,taddset3_A_DBHI,taddset3_A_DBLE,taddset3_A_DBLS,taddset3_A_DBLT,taddset3_A_DBMI,taddset3_A_DBNE,taddset3_A_DBRA,
         taddset3_A_DBPL,taddset3_A_DBT,taddset3_A_DBVC,taddset3_A_DBVS,taddset3_A_DBF,taddset3_A_DIVS,taddset3_A_DIVU,
         taddset3_A_EOR,taddset3_A_EORI,taddset3_A_EXG,taddset3_A_ILLEGAL,taddset3_A_EXT,taddset3_A_JMP,taddset3_A_JSR,
         taddset3_A_LEA,taddset3_A_LINK,taddset3_A_LSL,taddset3_A_LSR,taddset3_A_MOVE,taddset3_A_MOVEA,taddset3_A_MOVEI,taddset3_A_MOVEQ,
         taddset3_A_MOVEM,taddset3_A_MOVEP,taddset3_A_MULS,taddset3_A_MULU,taddset3_A_NBCD,taddset3_A_NEG,taddset3_A_NEGX,
         taddset3_A_NOP,taddset3_A_NOT,taddset3_A_OR,taddset3_A_ORI,taddset3_A_PEA,taddset3_A_ROL,taddset3_A_ROR,taddset3_A_ROXL,
         taddset3_A_ROXR,taddset3_A_RTR,taddset3_A_RTS,taddset3_A_SBCD,taddset3_A_SCC,taddset3_A_SCS,taddset3_A_SEQ,taddset3_A_SGE,
         taddset3_A_SGT,taddset3_A_SHI,taddset3_A_SLE,taddset3_A_SLS,taddset3_A_SLT,taddset3_A_SMI,taddset3_A_SNE,
         taddset3_A_SPL,taddset3_A_ST,taddset3_A_SVC,taddset3_A_SVS,taddset3_A_SF,taddset3_A_SUB,taddset3_A_SUBA,taddset3_A_SUBI,taddset3_A_SUBQ,
         taddset3_A_SUBX,taddset3_A_SWAP,taddset3_A_TAS,taddset3_A_TRAP,taddset3_A_TRAPV,taddset3_A_TST,taddset3_A_UNLK,
         taddset3_A_RTE,taddset3_A_RESET,taddset3_A_STOP,
         { MC68010 instructions }
         taddset3_A_BKPT,taddset3_A_MOVEC,taddset3_A_MOVES,taddset3_A_RTD,
         { MC68020 instructions }
         taddset3_A_BFCHG,taddset3_A_BFCLR,taddset3_A_BFEXTS,taddset3_A_BFEXTU,taddset3_A_BFFFO,
         taddset3_A_BFINS,taddset3_A_BFSET,taddset3_A_BFTST,taddset3_A_CALLM,taddset3_A_CAS,taddset3_A_CAS2,
         taddset3_A_CHK2,taddset3_A_CMP2,taddset3_A_DIVSL,taddset3_A_DIVUL,taddset3_A_EXTB,taddset3_A_PACK,taddset3_A_RTM,
         taddset3_A_TRAPCC,taddset3_A_TRACS,taddset3_A_TRAPEQ,taddset3_A_TRAPF,taddset3_A_TRAPGE,taddset3_A_TRAPGT,
         taddset3_A_TRAPHI,taddset3_A_TRAPLE,taddset3_A_TRAPLS,taddset3_A_TRAPLT,taddset3_A_TRAPMI,taddset3_A_TRAPNE,
         taddset3_A_TRAPPL,taddset3_A_TRAPT,taddset3_A_TRAPVC,taddset3_A_TRAPVS,taddset3_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         taddset3_A_FABS,taddset3_A_FADD,
         taddset3_A_FBEQ,taddset3_A_FBNE,taddset3_A_FBNGT,taddset3_A_FBGT,taddset3_A_FBGE,taddset3_A_FBNGE,
         taddset3_A_FBLT,taddset3_A_FBNLT,taddset3_A_FBLE,taddset3_A_FBGL,taddset3_A_FBNGL,taddset3_A_FBGLE,taddset3_A_FBNGLE,
         taddset3_A_FDBEQ,taddset3_A_FDBNE,taddset3_A_FDBGT,taddset3_A_FDBNGT,taddset3_A_FDBGE,taddset3_A_FDBNGE,
         taddset3_A_FDBLT,taddset3_A_FDBNLT,taddset3_A_FDBLE,taddset3_A_FDBGL,taddset3_A_FDBNGL,taddset3_A_FDBGLE,taddset3_A_FBDNGLE,
         taddset3_A_FSEQ,taddset3_A_FSNE,taddset3_A_FSGT,taddset3_A_FSNGT,taddset3_A_FSGE,taddset3_A_FSNGE,
         taddset3_A_FSLT,taddset3_A_FSNLT,taddset3_A_FSLE,taddset3_A_FSGL,taddset3_A_FSNGL,taddset3_A_FSGLE,taddset3_A_FSNGLE,
         taddset3_A_FCMP,taddset3_A_FDIV,taddset3_A_FMOVE,taddset3_A_FMOVEM,
         taddset3_A_FMUL,taddset3_A_FNEG,taddset3_A_FNOP,taddset3_A_FSQRT,taddset3_A_FSUB,taddset3_A_FSGLDIV,
         taddset3_A_FSFLMUL,taddset3_A_FTST,
         taddset3_A_FTRAPEQ,taddset3_A_FTRAPNE,taddset3_A_FTRAPGT,taddset3_A_FTRAPNGT,taddset3_A_FTRAPGE,taddset3_A_FTRAPNGE,
         taddset3_A_FTRAPLT,taddset3_A_FTRAPNLT,taddset3_A_FTRAPLE,taddset3_A_FTRAPGL,taddset3_A_FTRAPNGL,taddset3_A_FTRAPGLE,taddset3_A_FTRAPNGLE,
         { Protected instructions }
         taddset3_A_CPRESTORE,taddset3_A_CPSAVE,
         { FPU Unit protected instructions                    }
         { and 68030/68851 common MMU instructions            }
         { (this may include 68040 MMU instructions)          }
         taddset3_A_FRESTORE,taddset3_A_FSAVE,taddset3_A_PFLUSH,taddset3_A_PFLUSHA,taddset3_A_PLOAD,taddset3_A_PMOVE,taddset3_A_PTEST,
         { Useful for assembly langage output }
         taddset3_A_LABEL,taddset3_A_NONE);
       taddset3_tsubasmop = taddset3_A_BFINS..taddset3_A_FSEQ;
       taddset3_tsubasmop2 = taddset3_A_BCS..taddset3_A_BHI;



type
  taddset3_topset = set of taddset3_tasmop;
  taddset3_tsubopset = set of taddset3_tsubasmop;
  taddset3_tsmallset = set of taddset3_tsmallenum;
  taddset3_tsubsmallset = set of taddset3_tsmallsubenum;

const

   { NORMAL SETS }
   taddset3_constset1 : array[1..3] of taddset3_topset =
   (
       { 66 }    { 210 }  { 225 }
     ([taddset3_A_MOVE,    { 66  : LONG 2 - BIT 2  }
       taddset3_A_FTST,    { 210 : LONG 6 - BIT 18 }
       taddset3_A_CPSAVE]),{ 225 : LONG 7 - BIT 1 }
       { 1..8 }
     ([taddset3_A_ADD..taddset3_A_ASL]),
       { 134 }
     ([taddset3_A_CHK2])
   );

   taddset3_constset2 : array[1..4] of taddset3_topset =
   (
     ([taddset3_A_MOVE,taddset3_A_FTST,taddset3_A_CPSAVE]),
     ([taddset3_A_ADD..taddset3_A_ASL]),
     ([taddset3_A_CHK2]),
     ([taddset3_A_CMP2,taddset3_A_TRAPVC,taddset3_A_FADD])
   );

   { SMALL SETS }
   taddset3_constset3 : array[1..3] of taddset3_tsmallset =
   (
     ([taddset3_DA,             { 0 :  LONG 0 : bit 0 }
       taddset3_DD,             { 3 :  LONG 0 : bit 3 }
       taddset3_DM]),           { 12 :  LONG 0 : bit 12  }
     ([taddset3_DB..taddset3_DI]),       { 1..8 : LONG 0 : bits 1-8  }
     ([taddset3_DR])            { 17 :  LONG 0 : bit 17 }
   );

   taddset3_constset4 : array[1..3] of taddset3_tsmallset =
   (
     ([taddset3_DA,taddset3_DD,taddset3_DM]),
     ([taddset3_DB..taddset3_DI]),
     ([taddset3_DR])
   );

   taddset3_constsubset1: array[1..1] of taddset3_tsubopset =
   (
     ([taddset3_A_CMP2,taddset3_A_TRAPVC,taddset3_A_FADD])
   );


 procedure taddset3_CheckPassed(passed:boolean);
 begin
   if passed then
     WriteLn('Success.')
   else
     begin
       WriteLn('Failure.');
       Halt(1);
       taddset3_Err:=true;
     end;
 end;

 procedure taddset3_SetTestEqual;
 { FPC_SET_COMP_SETS }
  var
    op2list :set of taddset3_tasmop;
    oplist: set of taddset3_tasmop;
    soplist : taddset3_tsubopset;
    soplist2: set of taddset3_tsubasmop2;
    passed : boolean;
  Begin
   Write('Normal Set == Normal Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   soplist:=[];
   soplist2:=[];
   if not (oplist=op2list) then
     passed := false;
   if not (soplist=op2list) then
     passed := false;
   if not(soplist=soplist2) then
     passed:=false;
   if not (taddset3_constset1[2] = taddset3_constset2[2]) then
     passed := false;
   if not(taddset3_constset2[4] = taddset3_constsubset1[1]) then
     passed:=false;
   if (taddset3_constset1[1] = taddset3_constset2[2]) then
     passed := false;
   if (taddset3_constset1[1] = taddset3_constsubset1[1]) then
     passed := false;
   if soplist2 = taddset3_constsubset1[1] then
     passed:=false;
   if not (taddset3_constset1[1] = [taddset3_A_MOVE,taddset3_A_FTST,taddset3_A_CPSAVE]) then
     passed := false;
   if not (taddset3_constsubset1[1] = [taddset3_A_CMP2,taddset3_A_TRAPVC,taddset3_A_FADD]) then
     passed := false;
    taddset3_CheckPassed(passed);
  end;

 procedure taddset3_SetTestNotEqual;
 { FPC_SET_COMP_SETS }
  var
    op2list :set of taddset3_tasmop;
    oplist: set of taddset3_tasmop;
    soplist: set of taddset3_tsubasmop;
    passed : boolean;
  Begin
   Write('Normal Set <> Normal Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   soplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if not (oplist=soplist) then
     passed := false;
   if (taddset3_constset1[2] <> taddset3_constset2[2]) then
     passed := false;
   if not (taddset3_constset1[1] <> taddset3_constset2[2]) then
     passed := false;
{   if ( [A_ADD] <> [A_ADD] ) then optimized out.
     passed := false;
   if ( [A_BLE..A_BPL] <> [A_BLE..A_BPL] ) then
     passed := false; }
   if (taddset3_constset1[1] <> [taddset3_A_MOVE,taddset3_A_FTST,taddset3_A_CPSAVE]) then
     passed := false;
    taddset3_CheckPassed(passed);
  end;

  procedure taddset3_SetTestLt;
  var
    op2list :set of taddset3_tasmop;
    oplist: set of taddset3_tasmop;
    soplist : taddset3_tsubopset;
    soplist2: set of taddset3_tsubasmop2;
    passed : boolean;
   begin
    Write('Normal Set <= Normal Set test...');
    passed := true;
    if taddset3_constset1[1] <= taddset3_constset2[2] then
      passed := false;
    if taddset3_constset1[1] <= taddset3_constsubset1[1] then
      passed := false;
    oplist := [];
    op2list := [taddset3_A_MOVE];
    if op2list <= oplist then
     passed := false;
    oplist := [taddset3_A_MOVE,taddset3_A_CPRESTORE..taddset3_A_CPSAVE];
    if oplist <= op2list then
     passed := false;
    soplist2:=[taddset3_A_BHI];
    soplist:=[taddset3_A_BFINS..taddset3_A_FSEQ];
    if soplist2<=soplist then
     passed:=false;
    taddset3_CheckPassed(passed);
   end;

  Procedure taddset3_SetTestAddOne;
 { FPC_SET_SET_BYTE }
 { FPC_SET_ADD_SETS }
    var
     op : taddset3_tasmop;
     sop : taddset3_tsubasmop;
     sop2: taddset3_tsubasmop2;
     oplist: set of taddset3_tasmop;
     soplist: set of taddset3_tsubasmop;
     soplist2, soplist3: set of taddset3_tsubasmop2;
     passed: boolean;
  Begin
    Write('Set + Set element testing...');
    passed:=true;
    op:=taddset3_A_LABEL;
    oplist:=[];
    oplist:=oplist+[op];
    if oplist<>[taddset3_A_LABEL] then
      passed:=false;

    sop:=taddset3_A_UNPK;
    oplist:=[];
    oplist:=[sop];
    if oplist<>[taddset3_A_UNPK] then
      passed:=false;

    soplist:=[];
    op:=taddset3_A_UNPK;
    soplist:=[op];
    if soplist<>[taddset3_A_UNPK] then
      passed:=false;

    soplist:=[];
    op:=taddset3_A_FBLE;
    sop:=taddset3_A_FABS;
    soplist:=[op,sop];
    if soplist<>[taddset3_A_FBLE,taddset3_A_FABS] then
      passed:=false;

    soplist:=[];
    soplist:=[sop,op];
    if soplist<>[taddset3_A_FBLE,taddset3_A_FABS] then
      passed:=false;

    oplist:=[];
    oplist:=soplist+[taddset3_A_FADD];
    if (oplist<>[taddset3_A_FBLE,taddset3_A_FABS,taddset3_A_FADD]) then
      passed:=false;

    oplist:=[];
    sop:=taddset3_A_UNPK;
    oplist:=soplist+[sop];
    if (oplist<>[taddset3_A_FBLE,taddset3_A_FABS,taddset3_A_UNPK]) then
      passed:=false;

    soplist2:=[];
    oplist:=soplist2+[taddset3_A_BGE];
    if (oplist<>[taddset3_A_BGE]) then
     passed:=false;
    include(soplist2,taddset3_A_BGT);
    oplist:=soplist2-[taddset3_A_BHI];
    if (oplist<>[taddset3_A_BGT]) then
     passed:=false;
    soplist3:=[taddset3_A_BGT,taddset3_A_BHI];
    oplist:=soplist2*soplist3;
    if (oplist<>[taddset3_A_BGT]) then
     passed:=false;
    sop2:=taddset3_A_BHI;
    oplist:=[sop2];
    if (oplist<>[taddset3_A_BHI]) then
     passed:=false;
    taddset3_CheckPassed(passed);
  end;

Procedure taddset3_SetTestAddTwo;
{ SET_ADD_SETS }
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
Begin
 Write('Complex Set + Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset3_A_MOVE]+[taddset3_A_JSR];
 op2list:=[taddset3_A_LABEL];
 oplist:=op2list+oplist;
 taddset3_CheckPassed(oplist = [taddset3_A_MOVE,taddset3_A_JSR,taddset3_A_LABEL]);
end;





Procedure taddset3_SetTestSubOne;
{ SET_SUB_SETS }
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
 op :taddset3_tasmop;
 passed : boolean;
Begin
 Write('Set - Set element testing...');
 passed := true;
 op2list:=[];
 oplist:=[];
 op := taddset3_A_TRACS;
 oplist:=[taddset3_A_MOVE]+[taddset3_A_JSR]+[op];
 op2list:=[taddset3_A_MOVE]+[taddset3_A_JSR];
 oplist:=oplist-op2list;
 if oplist <> [taddset3_A_TRACS] then
   passed := false;

 oplist:=[taddset3_A_MOVE]+[taddset3_A_JSR]+[op];
 op2list:=[taddset3_A_MOVE]+[taddset3_A_JSR];
 oplist:=op2list-oplist;
 if oplist <> [] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

Procedure taddset3_SetTestSubTwo;
{ FPC_SET_SUB_SETS }
const
 b: taddset3_tasmop = (taddset3_A_BSR);
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
 op : taddset3_tasmop;
 passed : boolean;
Begin
 Write('Complex Set - Set element testing...');
 op := taddset3_A_BKPT;
 passed := true;
 oplist:=[taddset3_A_MOVE]+[taddset3_A_JSR]-[op];
 op2list:=[taddset3_A_MOVE]+[taddset3_A_JSR];
 if oplist <> op2list then
   passed := false;
 oplist := [taddset3_A_MOVE];
 oplist := oplist - [taddset3_A_MOVE];
 if oplist <> [] then
   passed := false;
 oplist := oplist + [b];
 if oplist <> [b] then
   passed := false;
 oplist := oplist - [b];
 if oplist <> [] then
   passed := false;
 taddset3_CheckPassed(passed);
end;


Procedure taddset3_SetTestMulSets;
{ FPC_SET_MUL_SETS }
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
 passed : boolean;
Begin
 passed := true;
 Write('Set * Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset3_A_MOVE]+[taddset3_A_JSR];
 op2list:=[taddset3_A_MOVE];
 oplist:=oplist*op2list;
 if oplist <> [taddset3_A_JSR] then
   passed := false;
 oplist := [taddset3_A_MOVE,taddset3_A_FTST];
 op2list := [taddset3_A_MOVE,taddset3_A_FTST];
 oplist := oplist * op2list;
 if oplist <> [taddset3_A_MOVE,taddset3_A_FTST] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

procedure taddset3_SetTestRange;
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
 passed : boolean;
 op1 : taddset3_tasmop;
 op2 : taddset3_tasmop;
begin
 passed := true;
 Write('Range Set + element testing...');
 op1 := taddset3_A_ADD;
 op2 := taddset3_A_ASL;
 oplist := [];
 oplist := [op1..op2];
 if oplist <> taddset3_constset1[2] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

procedure taddset3_SetTestByte;
var
 op2list :set of taddset3_tasmop;
 oplist: set of taddset3_tasmop;
 passed : boolean;
 op1 : taddset3_tasmop;
 op2 : taddset3_tasmop;
 op : taddset3_tasmop;
begin
 Write('Simple Set + element testing...');
 passed := true;
 op := taddset3_A_LABEL;
 oplist := [taddset3_A_MOVE,op,taddset3_A_JSR];
 if oplist <> [taddset3_A_MOVE,taddset3_A_LABEL,taddset3_A_JSR] then
   passed := false;
 taddset3_CheckPassed(passed);
end;


{------------------------------ TESTS FOR SMALL VALUES ---------------------}
 procedure taddset3_SmallSetTestEqual;
  var
    op2list :set of taddset3_tsmallenum;
    oplist: set of taddset3_tsmallenum;
    passed : boolean;
  Begin
   Write('Small Set == Small Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if not (taddset3_constset3[2] = taddset3_constset4[2]) then
     passed := false;
   if (taddset3_constset3[1] = taddset3_constset4[2]) then
     passed := false;
   if not (taddset3_constset3[1] = [taddset3_DA,taddset3_DD,taddset3_DM]) then
     passed := false;
 taddset3_CheckPassed(passed);
  end;

 procedure taddset3_SmallSetTestNotEqual;
  var
    op2list :set of taddset3_tsmallenum;
    oplist: set of taddset3_tsmallenum;
    passed : boolean;
  Begin
   Write('Small Set <> Small Set test...');
   passed := true;
   op2list:=[];
   oplist:=[];
   if not (oplist=op2list) then
     passed := false;
   if (taddset3_constset3[2] <> taddset3_constset4[2]) then
     passed := false;
   if not (taddset3_constset3[1] <> taddset3_constset4[2]) then
     passed := false;
{   if ( [A_ADD] <> [A_ADD] ) then optimized out.
     passed := false;
   if ( [A_BLE..A_BPL] <> [A_BLE..A_BPL] ) then
     passed := false; }
   if (taddset3_constset3[1] <> [taddset3_DA,taddset3_DD,taddset3_DM]) then
     passed := false;
 taddset3_CheckPassed(passed);
  end;

  procedure taddset3_SmallSetTestLt;
  var
    op2list :set of taddset3_tsmallenum;
    oplist: set of taddset3_tsmallenum;
    passed : boolean;
   begin
    Write('Small Set <= Small Set test...');
    passed := true;
    if taddset3_constset3[1] <= taddset3_constset4[2] then
      passed := false;
    oplist := [];
    op2list := [taddset3_DC];
    if op2list <= oplist then
     passed := false;
    oplist := [taddset3_DC,taddset3_DF..taddset3_DM];
    if oplist <= op2list then
     passed := false;
 taddset3_CheckPassed(passed);
   end;

  Procedure taddset3_SmallSetTestAddOne;
    var
     op : taddset3_tsmallenum;
     oplist: set of taddset3_tsmallenum;
  Begin
    Write('Small Set + Small Set element testing...');
    op:=taddset3_DG;
    oplist:=[];
    oplist:=oplist+[op];
    taddset3_CheckPassed( oplist = [taddset3_DG] );
  end;

Procedure taddset3_SmallSetTestAddTwo;
var
 op2list :set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
Begin
 Write('Small Complex Set + Small Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset3_DG]+[taddset3_DI];
 op2list:=[taddset3_DM];
 oplist:=op2list+oplist;
 taddset3_CheckPassed( oplist = [taddset3_DG,taddset3_DI,taddset3_DM] );
end;


Procedure taddset3_SmallSetTestSubOne;
var
 op2list :set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
 op :taddset3_tsmallenum;
 passed : boolean;
Begin
 Write('Small Set - Small Set element testing...');
 passed := true;
 op2list:=[];
 oplist:=[];
 op := taddset3_DL;
 oplist:=[taddset3_DG]+[taddset3_DI]+[op];
 op2list:=[taddset3_DG]+[taddset3_DI];
 oplist:=oplist-op2list;
 if oplist <> [taddset3_DL] then
   passed := false;

 oplist:=[taddset3_DG]+[taddset3_DI]+[op];
 op2list:=[taddset3_DG]+[taddset3_DI];
 oplist:=op2list-oplist;
 if oplist <> [] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

Procedure taddset3_SmallSetTestSubTwo;
const
 b: taddset3_tsmallenum = (taddset3_DH);
var
 op2list :set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
 op : taddset3_tsmallenum;
 passed : boolean;
Begin
 Write('Small Complex Set - Small Set element testing...');
 op := taddset3_DL;
 passed := true;
 oplist:=[taddset3_DG]+[taddset3_DI]-[op];
 op2list:=[taddset3_DG]+[taddset3_DI];
 if oplist <> op2list then
   passed := false;
 oplist := [taddset3_DG];
 oplist := oplist - [taddset3_DG];
 if oplist <> [] then
   passed := false;
 oplist := oplist + [b];
 if oplist <> [b] then
   passed := false;
 oplist := oplist - [b];
 if oplist <> [] then
   passed := false;
 taddset3_CheckPassed(passed);
end;


Procedure taddset3_SmallSetTestMulSets;
var
 op2list : set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
 passed : boolean;
Begin
 passed := true;
 Write('Small Set * Small Set element testing...');
 op2list:=[];
 oplist:=[];
 oplist:=[taddset3_DG]+[taddset3_DI];
 op2list:=[taddset3_DG];
 oplist:=oplist*op2list;
 if oplist <> [taddset3_DI] then
   passed := false;
 oplist := [taddset3_DG,taddset3_DK];
 op2list := [taddset3_DG,taddset3_DK];
 oplist := oplist * op2list;
 if oplist <> [taddset3_DG,taddset3_DK] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

procedure taddset3_SmallSetTestRange;
var
 op2list :set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
 passed : boolean;
 op1 : taddset3_tsmallenum;
 op2 : taddset3_tsmallenum;
begin
 passed := true;
 Write('Small Range Set + element testing...');
 op1 := taddset3_DB;
 op2 := taddset3_DI;
 oplist := [];
 oplist := [op1..op2];
 if oplist <> taddset3_constset3[2] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

procedure taddset3_SmallSetTestByte;
var
 op2list : set of taddset3_tsmallenum;
 oplist: set of taddset3_tsmallenum;
 passed : boolean;
 op1 : taddset3_tsmallenum;
 op2 : taddset3_tsmallenum;
 op : taddset3_tsmallenum;
begin
 Write('Small Simple Set + element testing...');
 passed := true;
 op := taddset3_DD;
 oplist := [taddset3_DG,op,taddset3_DI];
 if oplist <> [taddset3_DG,taddset3_DD,taddset3_DI] then
   passed := false;
 taddset3_CheckPassed(passed);
end;

(*

const
 b: myenum = (dA);
var
 enum: set of myenum;
 oplist: set of tasmop;
 l : word;
Begin
  SetTestEqual;
  SetTestNotEqual;
{ small sets }
 enum:=[];
 { add }
 enum:=enum+[da];
 { subtract }
 enum:=enum-[da];
 if DA in enum then
  WriteLn('Found A_LABEL');
 { very large sets       }
 { copy loop test        }
 WRITELN('LARGE SETS:');
 oplist := [A_LABEL];
 { secondin test         }
 if A_LABEL in oplist then
  WriteLn('TESTING SIMPLE SECOND_IN: PASSED.');
 { }
 oplist:=[];
 if A_LABEL in oplist then
  WriteLn('SECOND IN FAILED.');
{ SecondinSets;}
 SetSetByte;
 SetAddSets;
 SetSubSets;
 SetCompSets;
 SetMulSets;
 WRITELN('SMALL SETS:');
 SmallInSets;
 SmallAddSets;
 SmallSubSets;
 SmallCompSets;
 SmallMulSets;
 l:=word(A_CPRESTORE);
 if l = word(A_CPRESTORE) then
  Begin
  end;

*)

{$pop}

{ Case taddset4.pas }
{$push}
type
  taddset4_TCompilerIntfFlag = (taddset4_ifHasGuid,taddset4_ifDispInterface,taddset4_ifDispatch,taddset4_ifHasStrGUID);
  taddset4_TCompilerIntfFlags = set of taddset4_TCompilerIntfFlag;

procedure taddset4_t(l: longint);
begin
  writeln(hexstr(l,8));
  { exactly 3 bits must be set }
  l:=l and (l-1);
  if (l = 0) then
    halt(1);
  l:=l and (l-1);
  if (l = 0) then
    halt(2);
  l:=l and (l-1);
  if (l <> 0) then
    halt(3);
end;

var
  taddset4_b:boolean;

{$pop}

{ Case tcnvset.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondtypeconvert() -> second_load_smallset      }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{                 secondadd() for sets                           }
{                 secondsetelement()                             }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}

type
       { DO NOT CHANGE THE VALUES OF THESE ENUMERATIONS! }

       { This will fit into a 32-bit small set }
       tcnvset_tsmallenum = (tcnvset_dA,tcnvset_dB,tcnvset_dC,tcnvset_dd,tcnvset_de,tcnvset_df,tcnvset_dg,tcnvset_dh,tcnvset_di,tcnvset_dj,tcnvset_dk,tcnvset_dl,tcnvset_dm,tcnvset_dn,tcnvset_dop,tcnvset_dp,tcnvset_dq,tcnvset_dr);
       { This will fit into a normal 32-byte set }
       tcnvset_tbigenum = (tcnvset_A_ABCD,
         tcnvset_A_ADD,tcnvset_A_ADDA,tcnvset_A_ADDI,tcnvset_A_ADDQ,tcnvset_A_ADDX,tcnvset_A_AND,tcnvset_A_ANDI,
         tcnvset_A_ASL,tcnvset_A_ASR,tcnvset_A_BCC,tcnvset_A_BCS,tcnvset_A_BEQ,tcnvset_A_BGE,tcnvset_A_BGT,tcnvset_A_BHI,
         tcnvset_A_BLE,tcnvset_A_BLS,tcnvset_A_BLT,tcnvset_A_BMI,tcnvset_A_BNE,tcnvset_A_BPL,tcnvset_A_BVC,tcnvset_A_BVS,
         tcnvset_A_BCHG,tcnvset_A_BCLR,tcnvset_A_BRA,tcnvset_A_BSET,tcnvset_A_BSR,tcnvset_A_BTST,tcnvset_A_CHK,
         tcnvset_A_CLR,tcnvset_A_CMP,tcnvset_A_CMPA,tcnvset_A_CMPI,tcnvset_A_CMPM,tcnvset_A_DBCC,tcnvset_A_DBCS,tcnvset_A_DBEQ,tcnvset_A_DBGE,
         tcnvset_A_DBGT,tcnvset_A_DBHI,tcnvset_A_DBLE,tcnvset_A_DBLS,tcnvset_A_DBLT,tcnvset_A_DBMI,tcnvset_A_DBNE,tcnvset_A_DBRA,
         tcnvset_A_DBPL,tcnvset_A_DBT,tcnvset_A_DBVC,tcnvset_A_DBVS,tcnvset_A_DBF,tcnvset_A_DIVS,tcnvset_A_DIVU,
         tcnvset_A_EOR,tcnvset_A_EORI,tcnvset_A_EXG,tcnvset_A_ILLEGAL,tcnvset_A_EXT,tcnvset_A_JMP,tcnvset_A_JSR,
         tcnvset_A_LEA,tcnvset_A_LINK,tcnvset_A_LSL,tcnvset_A_LSR,tcnvset_A_MOVE,tcnvset_A_MOVEA,tcnvset_A_MOVEI,tcnvset_A_MOVEQ,
         tcnvset_A_MOVEM,tcnvset_A_MOVEP,tcnvset_A_MULS,tcnvset_A_MULU,tcnvset_A_NBCD,tcnvset_A_NEG,tcnvset_A_NEGX,
         tcnvset_A_NOP,tcnvset_A_NOT,tcnvset_A_OR,tcnvset_A_ORI,tcnvset_A_PEA,tcnvset_A_ROL,tcnvset_A_ROR,tcnvset_A_ROXL,
         tcnvset_A_ROXR,tcnvset_A_RTR,tcnvset_A_RTS,tcnvset_A_SBCD,tcnvset_A_SCC,tcnvset_A_SCS,tcnvset_A_SEQ,tcnvset_A_SGE,
         tcnvset_A_SGT,tcnvset_A_SHI,tcnvset_A_SLE,tcnvset_A_SLS,tcnvset_A_SLT,tcnvset_A_SMI,tcnvset_A_SNE,
         tcnvset_A_SPL,tcnvset_A_ST,tcnvset_A_SVC,tcnvset_A_SVS,tcnvset_A_SF,tcnvset_A_SUB,tcnvset_A_SUBA,tcnvset_A_SUBI,tcnvset_A_SUBQ,
         tcnvset_A_SUBX,tcnvset_A_SWAP,tcnvset_A_TAS,tcnvset_A_TRAP,tcnvset_A_TRAPV,tcnvset_A_TST,tcnvset_A_UNLK,
         tcnvset_A_RTE,tcnvset_A_RESET,tcnvset_A_STOP,
         tcnvset_A_BKPT,tcnvset_A_MOVEC,tcnvset_A_MOVES,tcnvset_A_RTD,
         tcnvset_A_BFCHG,tcnvset_A_BFCLR,tcnvset_A_BFEXTS,tcnvset_A_BFEXTU,tcnvset_A_BFFFO,
         tcnvset_A_BFINS,tcnvset_A_BFSET,tcnvset_A_BFTST,tcnvset_A_CALLM,tcnvset_A_CAS,tcnvset_A_CAS2,
         tcnvset_A_CHK2,tcnvset_A_CMP2,tcnvset_A_DIVSL,tcnvset_A_DIVUL,tcnvset_A_EXTB,tcnvset_A_PACK,tcnvset_A_RTM,
         tcnvset_A_TRAPCC,tcnvset_A_TRACS,tcnvset_A_TRAPEQ,tcnvset_A_TRAPF,tcnvset_A_TRAPGE,tcnvset_A_TRAPGT,
         tcnvset_A_TRAPHI,tcnvset_A_TRAPLE,tcnvset_A_TRAPLS,tcnvset_A_TRAPLT,tcnvset_A_TRAPMI,tcnvset_A_TRAPNE,
         tcnvset_A_TRAPPL,tcnvset_A_TRAPT,tcnvset_A_TRAPVC,tcnvset_A_TRAPVS,tcnvset_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tcnvset_A_FABS,tcnvset_A_FADD,
         tcnvset_A_FBEQ,tcnvset_A_FBNE,tcnvset_A_FBNGT,tcnvset_A_FBGT,tcnvset_A_FBGE,tcnvset_A_FBNGE,
         tcnvset_A_FBLT,tcnvset_A_FBNLT,tcnvset_A_FBLE,tcnvset_A_FBGL,tcnvset_A_FBNGL,tcnvset_A_FBGLE,tcnvset_A_FBNGLE,
         tcnvset_A_FDBEQ,tcnvset_A_FDBNE,tcnvset_A_FDBGT,tcnvset_A_FDBNGT,tcnvset_A_FDBGE,tcnvset_A_FDBNGE,
         tcnvset_A_FDBLT,tcnvset_A_FDBNLT,tcnvset_A_FDBLE,tcnvset_A_FDBGL,tcnvset_A_FDBNGL,tcnvset_A_FDBGLE,tcnvset_A_FBDNGLE,
         tcnvset_A_FSEQ,tcnvset_A_FSNE,tcnvset_A_FSGT,tcnvset_A_FSNGT,tcnvset_A_FSGE,tcnvset_A_FSNGE,
         tcnvset_A_FSLT,tcnvset_A_FSNLT,tcnvset_A_FSLE,tcnvset_A_FSGL,tcnvset_A_FSNGL,tcnvset_A_FSGLE,tcnvset_A_FSNGLE,
         tcnvset_A_FCMP,tcnvset_A_FDIV,tcnvset_A_FMOVE,tcnvset_A_FMOVEM,
         tcnvset_A_FMUL,tcnvset_A_FNEG,tcnvset_A_FNOP,tcnvset_A_FSQRT,tcnvset_A_FSUB,tcnvset_A_FSGLDIV,
         tcnvset_A_FSFLMUL,tcnvset_A_FTST,
         tcnvset_A_FTRAPEQ,tcnvset_A_FTRAPNE,tcnvset_A_FTRAPGT,tcnvset_A_FTRAPNGT,tcnvset_A_FTRAPGE,tcnvset_A_FTRAPNGE,
         tcnvset_A_FTRAPLT,tcnvset_A_FTRAPNLT,tcnvset_A_FTRAPLE,tcnvset_A_FTRAPGL,tcnvset_A_FTRAPNGL,tcnvset_A_FTRAPGLE,tcnvset_A_FTRAPNGLE,
         tcnvset_A_CPRESTORE,tcnvset_A_CPSAVE,
         tcnvset_A_FRESTORE,tcnvset_A_FSAVE,tcnvset_A_PFLUSH,tcnvset_A_PFLUSHA,tcnvset_A_PLOAD,tcnvset_A_PMOVE,tcnvset_A_PTEST,
         tcnvset_A_LABEL,tcnvset_A_NONE);



type
  tcnvset_tnormalset = set of tcnvset_tbigenum;
  tcnvset_tsmallset = set of tcnvset_tsmallenum;

procedure tcnvset_fail;
begin
  Writeln('Failed!');
  halt(1);
end;



  procedure tcnvset_SmallSet2NormalSet;
   var
    op1: set of tcnvset_A_ABCD..tcnvset_A_BCS;
    op2: tcnvset_tnormalset;
    passed : boolean;
   begin
    passed := true;
    Write('Small Set -> Normal set conversion...');
    op1 := [tcnvset_A_BCS];
    op2 := op1;
    if op2 <> [tcnvset_A_BCS] then
      passed := false;
    op1 := [tcnvset_A_ADDI..tcnvset_A_ADDX];
    op2 := op1;
    if op2 <> [tcnvset_A_ADDI..tcnvset_A_ADDX] then
      passed := false;
    op1 := [tcnvset_A_BCS];
    op2 := [tcnvset_A_MOVE];
    op2 := op2 + op1;
    if op2 <> [tcnvset_A_BCS,tcnvset_A_MOVE] then
      passed := false;
    if not passed then
       tcnvset_Fail
    else
       WriteLn('Success.');
   end;



{$pop}

{ Case tin.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondin()                                       }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{                 secondadd() for sets                           }
{                 secondsetelement()                             }
{                 secondcalln()                                  }
{                 secondfuncret()                                }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}

type
       { DO NOT CHANGE THE VALUES OF THESE ENUMERATIONS! }

       { This will fit into a 32-bit small set }
       tin_tsmallenum = (tin_dA,tin_dB,tin_dC,tin_dd,tin_de,tin_df,tin_dg,tin_dh,tin_di,tin_dj,tin_dk,tin_dl,tin_dm,tin_dn,tin_dop,tin_dp,tin_dq,tin_dr);
       { This will fit into a normal 32-byte set }
       tin_tbigenum = (tin_A_ABCD,
         tin_A_ADD,tin_A_ADDA,tin_A_ADDI,tin_A_ADDQ,tin_A_ADDX,tin_A_AND,tin_A_ANDI,
         tin_A_ASL,tin_A_ASR,tin_A_BCC,tin_A_BCS,tin_A_BEQ,tin_A_BGE,tin_A_BGT,tin_A_BHI,
         tin_A_BLE,tin_A_BLS,tin_A_BLT,tin_A_BMI,tin_A_BNE,tin_A_BPL,tin_A_BVC,tin_A_BVS,
         tin_A_BCHG,tin_A_BCLR,tin_A_BRA,tin_A_BSET,tin_A_BSR,tin_A_BTST,tin_A_CHK,
         tin_A_CLR,tin_A_CMP,tin_A_CMPA,tin_A_CMPI,tin_A_CMPM,tin_A_DBCC,tin_A_DBCS,tin_A_DBEQ,tin_A_DBGE,
         tin_A_DBGT,tin_A_DBHI,tin_A_DBLE,tin_A_DBLS,tin_A_DBLT,tin_A_DBMI,tin_A_DBNE,tin_A_DBRA,
         tin_A_DBPL,tin_A_DBT,tin_A_DBVC,tin_A_DBVS,tin_A_DBF,tin_A_DIVS,tin_A_DIVU,
         tin_A_EOR,tin_A_EORI,tin_A_EXG,tin_A_ILLEGAL,tin_A_EXT,tin_A_JMP,tin_A_JSR,
         tin_A_LEA,tin_A_LINK,tin_A_LSL,tin_A_LSR,tin_A_MOVE,tin_A_MOVEA,tin_A_MOVEI,tin_A_MOVEQ,
         tin_A_MOVEM,tin_A_MOVEP,tin_A_MULS,tin_A_MULU,tin_A_NBCD,tin_A_NEG,tin_A_NEGX,
         tin_A_NOP,tin_A_NOT,tin_A_OR,tin_A_ORI,tin_A_PEA,tin_A_ROL,tin_A_ROR,tin_A_ROXL,
         tin_A_ROXR,tin_A_RTR,tin_A_RTS,tin_A_SBCD,tin_A_SCC,tin_A_SCS,tin_A_SEQ,tin_A_SGE,
         tin_A_SGT,tin_A_SHI,tin_A_SLE,tin_A_SLS,tin_A_SLT,tin_A_SMI,tin_A_SNE,
         tin_A_SPL,tin_A_ST,tin_A_SVC,tin_A_SVS,tin_A_SF,tin_A_SUB,tin_A_SUBA,tin_A_SUBI,tin_A_SUBQ,
         tin_A_SUBX,tin_A_SWAP,tin_A_TAS,tin_A_TRAP,tin_A_TRAPV,tin_A_TST,tin_A_UNLK,
         tin_A_RTE,tin_A_RESET,tin_A_STOP,
         tin_A_BKPT,tin_A_MOVEC,tin_A_MOVES,tin_A_RTD,
         tin_A_BFCHG,tin_A_BFCLR,tin_A_BFEXTS,tin_A_BFEXTU,tin_A_BFFFO,
         tin_A_BFINS,tin_A_BFSET,tin_A_BFTST,tin_A_CALLM,tin_A_CAS,tin_A_CAS2,
         tin_A_CHK2,tin_A_CMP2,tin_A_DIVSL,tin_A_DIVUL,tin_A_EXTB,tin_A_PACK,tin_A_RTM,
         tin_A_TRAPCC,tin_A_TRACS,tin_A_TRAPEQ,tin_A_TRAPF,tin_A_TRAPGE,tin_A_TRAPGT,
         tin_A_TRAPHI,tin_A_TRAPLE,tin_A_TRAPLS,tin_A_TRAPLT,tin_A_TRAPMI,tin_A_TRAPNE,
         tin_A_TRAPPL,tin_A_TRAPT,tin_A_TRAPVC,tin_A_TRAPVS,tin_A_UNPK,
         { FPU Processor instructions - directly supported only. }
         { IEEE aware and misc. condition codes not supported   }
         tin_A_FABS,tin_A_FADD,
         tin_A_FBEQ,tin_A_FBNE,tin_A_FBNGT,tin_A_FBGT,tin_A_FBGE,tin_A_FBNGE,
         tin_A_FBLT,tin_A_FBNLT,tin_A_FBLE,tin_A_FBGL,tin_A_FBNGL,tin_A_FBGLE,tin_A_FBNGLE,
         tin_A_FDBEQ,tin_A_FDBNE,tin_A_FDBGT,tin_A_FDBNGT,tin_A_FDBGE,tin_A_FDBNGE,
         tin_A_FDBLT,tin_A_FDBNLT,tin_A_FDBLE,tin_A_FDBGL,tin_A_FDBNGL,tin_A_FDBGLE,tin_A_FBDNGLE,
         tin_A_FSEQ,tin_A_FSNE,tin_A_FSGT,tin_A_FSNGT,tin_A_FSGE,tin_A_FSNGE,
         tin_A_FSLT,tin_A_FSNLT,tin_A_FSLE,tin_A_FSGL,tin_A_FSNGL,tin_A_FSGLE,tin_A_FSNGLE,
         tin_A_FCMP,tin_A_FDIV,tin_A_FMOVE,tin_A_FMOVEM,
         tin_A_FMUL,tin_A_FNEG,tin_A_FNOP,tin_A_FSQRT,tin_A_FSUB,tin_A_FSGLDIV,
         tin_A_FSFLMUL,tin_A_FTST,
         tin_A_FTRAPEQ,tin_A_FTRAPNE,tin_A_FTRAPGT,tin_A_FTRAPNGT,tin_A_FTRAPGE,tin_A_FTRAPNGE,
         tin_A_FTRAPLT,tin_A_FTRAPNLT,tin_A_FTRAPLE,tin_A_FTRAPGL,tin_A_FTRAPNGL,tin_A_FTRAPGLE,tin_A_FTRAPNGLE,
         tin_A_CPRESTORE,tin_A_CPSAVE,
         tin_A_FRESTORE,tin_A_FSAVE,tin_A_PFLUSH,tin_A_PFLUSHA,tin_A_PLOAD,tin_A_PMOVE,tin_A_PTEST,
         tin_A_LABEL,tin_A_NONE);

     { this is also a normal set }
     tin_tregister = (tin_R_NO,
        tin_R_EAX,tin_R_ECX,tin_R_EDX,tin_R_EBX,tin_R_ESP,tin_R_EBP,tin_R_ESI,tin_R_EDI,
        tin_R_AX,tin_R_CX,tin_R_DX,tin_R_BX,tin_R_SP,tin_R_BP,tin_R_SI,tin_R_DI,
        tin_R_AL,tin_R_CL,tin_R_DL,tin_R_BL,tin_R_AH,tin_R_CH,tin_R_BH,tin_R_DH,
        tin_R_CS,tin_R_DS,tin_R_ES,tin_R_SS,tin_R_FS,tin_R_GS,
        tin_R_ST,tin_R_ST0,tin_R_ST1,tin_R_ST2,tin_R_ST3,tin_R_ST4,tin_R_ST5,tin_R_ST6,tin_R_ST7,
        tin_R_DR0,tin_R_DR1,tin_R_DR2,tin_R_DR3,tin_R_DR6,tin_R_DR7,
        tin_R_CR0,tin_R_CR2,tin_R_CR3,tin_R_CR4,
        tin_R_TR3,tin_R_TR4,tin_R_TR5,tin_R_TR6,tin_R_TR7,
        tin_R_MM0,tin_R_MM1,tin_R_MM2,tin_R_MM3,tin_R_MM4,tin_R_MM5,tin_R_MM6,tin_R_MM7,
        tin_R_XMM0,tin_R_XMM1,tin_R_XMM2,tin_R_XMM3,tin_R_XMM4,tin_R_XMM5,tin_R_XMM6,tin_R_XMM7
      );
const
      tin_LoReg = tin_R_EAX;
      tin_HiReg = tin_R_DH;



type
  tin_tnormalset = set of tin_tbigenum;
  tin_tsmallset = set of tin_tsmallenum;
  tin_tregset = set of tin_LoReg..tin_HiReg;



  procedure tin_checkpassed(passed : boolean);
   begin
    if passed then
      WriteLn('Passed!')
    else
      begin
        WriteLn('Failure.');
        Halt(1);
      end;
   end;


var
  tin_NewRegsEncountered : tin_TRegSet;



  function tin_Reg32 : tin_tregister;
   begin
     tin_Reg32:=tin_R_EAX;
   end;


{*******************************************************************}
{ The following cases are possible                                  }
{     jump table usage                                              }
{     small set or normal set                                       }
{     source location : REFERENCE,MEMORY,CONSTANT or REGISTER       }
{*******************************************************************}

  { NO GENERATION OF JUMP TABLE }
  { SMALL SET                   }
  procedure tin_smallsettestone;
   var
     op1 : tin_tsmallset;
     op2 : tin_tsmallset;
     op3 : tin_tsmallset;
     op  : tin_tsmallenum;
     passed : boolean;
   begin
     passed := true;
     Write('Small set in operator test (without case table)...');

     { LEFT : LOC_REFERENCE (not a constant node)  }
     { RIGHT : LOC_REFERENCE                       }
     op1 := [tin_DI];
     op2 := [tin_DI];
     op := tin_DI;
     if not (op in op1) then
      passed := false;

     { LEFT : LOC_REFERENCE (a constant node) }
     { RIGHT: LOC_REFERENCE                   }
     op1 := [tin_DL];
     op := tin_DI;
     if not (tin_DL in op1) then
      passed := false;
     { LEFT : LOC_REFERENCE (a constant node) }
     { THIS CAN NEVER HAPPEN - EVALUATED AT COMPILE TIME BY COMPILER }
     op1 := [tin_DB];
     op := tin_DB;
     if not (tin_DB in [tin_DA..tin_DL]) then
      passed := false;
     { LEFT : LOC_REFERENCE (not a constant node) }
     { RIGHT : LOC_REGISTER,LOC_CREGISTER         }
     op := tin_DF;
     op2 := [tin_DB];
     op3 := [tin_DF];
     if not (op in (op2+op3)) then
       passed := false;

     { LEFT : LOC_REGISTER  (a constant node)     }
     { RIGHT : LOC_REGISTER,LOC_CREGISTER         }
     op2 := [tin_DB];
     op3 := [tin_DF];
     if not (tin_DB in (op2+op3)) then
       passed := false;
     tin_checkpassed(passed);
   end;


  { returns result in register }
   function tin_getsmallop : tin_tsmallenum;
     begin
       tin_getsmallop := tin_DQ;
     end;

  { NO GENERATION OF JUMP TABLE }
  { SMALL SET                   }
  procedure tin_smallsettestthree;
   var
     op1 : tin_tsmallset;
     op2 : tin_tsmallset;
     op3 : tin_tsmallset;
     op  : tin_tsmallenum;
     passed : boolean;
   begin
     passed := true;
     Write('Small set in operator test (without case table)...');

     { LEFT : LOC_REGISTER (not a constant node)  }
     { RIGHT : LOC_REFERENCE                      }
     op1 := [tin_DQ];
     op2 := [tin_DQ];
     if not (tin_getsmallop in op1) then
      passed := false;

     { LEFT : LOC_REGISTER (not a constant node) }
     { RIGHT : LOC_REGISTER                      }
     op := tin_DF;
     op2 := [tin_DB,tin_DQ];
     op3 := [tin_DF];
     if not (tin_getsmallop in (op2+op3)) then
       passed := false;

     tin_checkpassed(passed);
   end;

  { GENERATION OF JUMP TABLE }
  { SMALL SET                }
  procedure tin_smallsettesttwo;
   var
     op1 : tin_tsmallset;
     op2 : tin_tsmallset;
     op  : tin_tsmallenum;
     passed : boolean;
   begin
     Write('Small set in operator test (with case table)...');
     passed := true;
     op := tin_DN;
     { LEFT : LOC_REFERENCE }
     { RIGHT: range constant set  (carry flag) }
     if not (op in [tin_DB..tin_DN]) then
      passed := false;
     { LEFT : LOC_REFERENCE }
     { RIGHT: NOT range constant set (zero flag) }
     op := tin_DH;
     if not (op in [tin_DB,tin_DH,tin_DP]) then
      passed := false;
     { LEFT : LOC_REFERENCE                       }
     { RIGHT : range constant set with full set   }
     op:=tin_DK;
     if not (op in [tin_dA,tin_dB,tin_dC,tin_dd,tin_de,tin_df,tin_dg,tin_dh,tin_di,tin_dj,tin_dk,tin_dl,tin_dm,tin_dn,tin_dop,tin_dp,tin_dq,tin_dr]) then
       passed := false;

     { LEFT : LOC_REGISTER                        }
     { RIGHT : NOT range constant set (zero flag) }
     op := tin_DH;
     if not (tin_getsmallop in [tin_DA,tin_DB..tin_DN,tin_DQ]) then
      passed := false;
     { LEFT : LOC_REGISTER                        }
     { RIGHT : range constant set with full set   }
     if not (tin_getsmallop in [tin_dA,tin_dB,tin_dC,tin_dd,tin_de,tin_df,tin_dg,tin_dh,tin_di,tin_dj,tin_dk,tin_dl,tin_dm,tin_dn,tin_dop,tin_dp,tin_dq,tin_dr]) then
       passed := false;
     tin_checkpassed(passed);
   end;


  { returns result in register }
  function tin_getop : tin_tbigenum;
    begin
      tin_getop := tin_A_BFSET;
    end;

   { NO JUMP TABLE }
   { NORMAL SETS   }
   procedure tin_settestone;
   var
     op1 : tin_tnormalset;
     op2 : tin_tnormalset;
     op  : tin_tbigenum;
     passed : boolean;
   begin
     Write('Normal set in operator test (without case table)...');
     passed := true;
     { RIGHT NODE = immediate value in reference field ?? }
     { RIGHT node = ordconstn (how is this possible?) - it goes through }
     {  analizeset!                                                     }
     { Left : LOC_REGISTER               }
     { right : LOC_REFERENCE (call to sys) }
     if not (tin_getop in [tin_A_BFSET,tin_A_MOVE,tin_A_TRAP,tin_A_CMP,tin_A_CMPI,tin_A_FADD,tin_A_LABEL,tin_A_ASL,tin_A_ADDX]) then
       passed := false;

     op := tin_A_MOVE;
     { Left : LOC_REFERENCE              }
     { right : LOC_REFERENCE             }
     if not (op in [tin_A_BFSET,tin_A_MOVE,tin_A_TRAP,tin_A_CMP,tin_A_CMPI,tin_A_FADD,tin_A_LABEL,tin_A_ASL,tin_A_ADDX]) then
       passed := false;
     { Left : ordinal constant           }
     { right : LOC_REFERENCE             }
     op1 := [tin_A_MOVE,tin_A_TRAP];
     if not (tin_A_MOVE in op1) then
       passed := false;

     tin_checkpassed(passed);
   end;


   { WITH JUMP TABLE }
   { NORMAL SETS   }
   procedure tin_settesttwo;
   var
     op1 : tin_tnormalset;
     op2 : tin_tnormalset;
     bs  : set of boolean;
     op  : tin_tbigenum;
     passed : boolean;
   begin
     Write('Normal set in operator test (with case table)...');
     passed := true;
     { Left : LOC_REGISTER               }
     { right : LOC_REFERENCE with ranges }
     if not (tin_getop in [tin_A_BFSET,tin_A_MOVE,tin_A_ASL..tin_A_BCC]) then
       passed := false;
     { Left : LOC_REGISTER               }
     { right : LOC_REFERENCE no ranges   }

     if not (tin_getop in [tin_A_BFSET,tin_A_MOVE]) then
       passed := false;

     { Left : LOC_REGISTER               }
     { right : no set at all             }
     if tin_getop in [] then
       passed:=false;

     { Left : LOC_REGISTER               }
     { right : complete set definition   }
     if not (tin_getop in [tin_A_ABCD..tin_A_NONE]) then
       passed:=false;


     op := tin_A_MOVE;
     { Left : LOC_REFERENCE              }
     { right : LOC_REFERENCE with ranges }
     if not (tin_getop in [tin_A_BFSET,tin_A_MOVE,tin_A_ASL..tin_A_BCC]) then
       passed := false;

     op:= tin_A_MOVE;
     if not (tin_getop in [tin_A_BFSET,tin_A_MOVE]) then
       passed := false;

     { Left : LOC_REFERENCE              }
     { right : no set at all             }
     op := tin_A_MOVE;
     if op in [] then
       passed:=false;

     { Left : LOC_REFERENCE              }
     { right : complete set definition   }
     op:=tin_A_MOVE;
     if not (op in [tin_A_ABCD..tin_A_NONE]) then
       passed:=false;

     tin_checkpassed(passed);


     { LEFT : LOC_JUMP                            }
     { RIGHT : LOC_REGISTER,LOC_CREGISTER         }
     bs:=[false,true];
     op:=tin_A_MOVE;
     passed:=true;
     if not(not(op in [tin_A_BFSET,tin_A_MOVE,tin_A_ASL..tin_A_BCC]) in bs) then
       passed := false;
     if not((op in [tin_A_BFSET,tin_A_MOVE,tin_A_ASL..tin_A_BCC]) in bs) then
       passed := false;

     bs:=[false];
     if ((op in [tin_A_BFSET,tin_A_MOVE,tin_A_ASL..tin_A_BCC]) in bs) then
       passed := false;

     tin_checkpassed(passed);
   end;

   { WITH JUMP TABLE }
   { NORMAL SETS   }
   procedure tin_settestthree;
     var
      passed : boolean;
     begin
       Write('Normal set in operator test II (without case table)...');
       passed := false;
       tin_NewRegsEncountered := [tin_R_EAX..tin_R_EDX];
       If (tin_Reg32 in tin_NewRegsEncountered) Then
         passed := true;
       tin_checkpassed(passed);
     end;


{$pop}

begin

{ Case taddset.pas }
{$push}

Begin
  WriteLn('----------------------- Normal sets -----------------------');
  { Normal sets }
  taddset_SetTestEqual;
  taddset_SetTestNotEqual;
  taddset_SetTestAddOne;
  taddset_SetTestAddTwo;
  taddset_SetTestSubOne;
  taddset_SetTestSubTwo;
  taddset_SetTestRange;
  taddset_SetTestLt;
  taddset_SetTestByte;
  { Small sets }
  WriteLn('----------------------- Small sets -----------------------');
  taddset_SmallSetTestEqual;
  taddset_SmallSetTestNotEqual;
  taddset_SmallSetTestAddOne;
  taddset_SmallSetTestAddTwo;
  taddset_SmallSetTestSubOne;
  taddset_SmallSetTestSubTwo;
  taddset_SmallSetTestRange;
  taddset_SmallSetTestLt;
  taddset_SmallSetTestByte;

  if taddset_Err then
   Halt(1);
end;
{$pop}

{ Case taddset3.pas }
{$push}
{$ifdef fpc}
{$packset 1}
{$endif}
Begin
  WriteLn('----------------------- Normal sets -----------------------');
  { Normal sets }
  taddset3_SetTestEqual;
  taddset3_SetTestNotEqual;
  taddset3_SetTestAddOne;
  taddset3_SetTestAddTwo;
  taddset3_SetTestSubOne;
  taddset3_SetTestSubTwo;
  taddset3_SetTestRange;
  taddset3_SetTestLt;
  taddset3_SetTestByte;
  { Small sets }
  WriteLn('----------------------- Small sets -----------------------');
  taddset3_SmallSetTestEqual;
  taddset3_SmallSetTestNotEqual;
  taddset3_SmallSetTestAddOne;
  taddset3_SmallSetTestAddTwo;
  taddset3_SmallSetTestSubOne;
  taddset3_SmallSetTestSubTwo;
  taddset3_SmallSetTestRange;
  taddset3_SmallSetTestLt;
  taddset3_SmallSetTestByte;

  if taddset3_Err then
   Halt(1);
end;
{$pop}

{ Case taddset4.pas }
{$push}

begin
  taddset4_b:=true;
  taddset4_t({$ifdef CPU16}byte{$else}longint{$endif}([
      taddset4_TCompilerIntfFlag(ord(taddset4_ifHasGuid)*ord(taddset4_b)),
      taddset4_TCompilerIntfFlag(ord(taddset4_ifHasStrGUID)*ord(taddset4_b)),
      taddset4_TCompilerIntfFlag(ord(taddset4_ifDispInterface)*ord(taddset4_b))
    ]));
end;
{$pop}

{ Case tcnvset.pas }
{$push}

Begin
 tcnvset_SmallSet2NormalSet;
end;
{$pop}

{ Case tin.pas }
{$push}

Begin
  tin_smallsettestone;
  tin_smallsettesttwo;
  tin_smallsettestthree;

  tin_settestone;
  tin_settesttwo;
  tin_settestthree;
end;
{$pop}

end.
