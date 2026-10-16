{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Some basic types and constants for the code generation

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
{# This unit exports some types which are used across the code generator }
unit cgbase;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      SymConst;

    type
       { Location types where value can be stored }
       TCGLoc=(
         LOC_INVALID,      { added for tracking problems}
         LOC_VOID,         { no value is available }
         LOC_CONSTANT,     { constant value }
         LOC_JUMP,         { boolean results only, jump to false or true label }
         LOC_FLAGS,        { boolean results only, flags are set }
         LOC_REGISTER,     { in a processor register }
         LOC_CREGISTER,    { Constant register which shouldn't be modified }
         LOC_FPUREGISTER,  { FPU stack }
         LOC_CFPUREGISTER, { if it is a FPU register variable on the fpu stack }
         LOC_MMXREGISTER,  { MMX register }
         { MMX register variable }
         LOC_CMMXREGISTER,
         { multimedia register }
         LOC_MMREGISTER,
         { Constant multimedia reg which shouldn't be modified }
         LOC_CMMREGISTER,
         { contiguous subset of bits of an integer register }
         LOC_SUBSETREG,
         LOC_CSUBSETREG,
         { contiguous subset of bits in memory }
         LOC_SUBSETREF,
         LOC_CSUBSETREF,
         { keep these last for range checking purposes }
         LOC_CREFERENCE,   { in memory constant value reference (cannot change) }
         LOC_REFERENCE     { in memory value }
       );

       TCGNonRefLoc=Low(TCGLoc)..Pred(LOC_CREFERENCE);
       TCGRefLoc=LOC_CREFERENCE..LOC_REFERENCE;

       TRefAddr = (
         addr_no,
         addr_full,
         addr_pic,
         addr_pic_no_got


         {$IFDEF AARCH64}
         ,addr_page
         ,addr_pageoffset
         ,addr_gotpage
         ,addr_gotpageoffset
         {$ENDIF AARCH64}
         {$IFDEF i386}
         ,addr_ntpoff
         ,addr_tlsgd
         {$ENDIF}
{$ifdef x86_64}
          ,addr_tpoff
          ,addr_tlsgd
{$endif x86_64}
         );


       {# Generic opcodes, which must be supported by all processors
       }
       TOpCG =
       (
          OP_NONE,
          OP_MOVE,      { replaced operation with direct load }
          OP_ADD,       { simple addition          }
          OP_AND,       { simple logical and       }
          OP_DIV,       { simple unsigned division }
          OP_IDIV,      { simple signed division   }
          OP_IMUL,      { simple signed multiply   }
          OP_MUL,       { simple unsigned multiply }
          OP_NEG,       { simple negate            }
          OP_NOT,       { simple logical not       }
          OP_OR,        { simple logical or        }
          OP_SAR,       { arithmetic shift-right   }
          OP_SHL,       { logical shift left       }
          OP_SHR,       { logical shift right      }
          OP_SUB,       { simple subtraction       }
          OP_XOR,       { simple exclusive or      }
          OP_ROL,       { rotate left              }
          OP_ROR        { rotate right             }
        );

       {# Generic flag values - used for jump locations }
       TOpCmp =
       (
          OC_NONE,
          OC_EQ,           { equality comparison              }
          OC_GT,           { greater than (signed)            }
          OC_LT,           { less than (signed)               }
          OC_GTE,          { greater or equal than (signed)   }
          OC_LTE,          { less or equal than (signed)      }
          OC_NE,           { not equal                        }
          OC_BE,           { less or equal than (unsigned)    }
          OC_B,            { less than (unsigned)             }
          OC_AE,           { greater or equal than (unsigned) }
          OC_A             { greater than (unsigned)          }
        );

       { indirect symbol flags }
       TIndSymFlag = (is_data,is_weak);
       TIndSymFlags = set of TIndSymFlag;

       { OS_NO is also used memory references with large data that can
         not be loaded in a register directly }
       TCgSize = (OS_NO,
                  OS_8,   OS_16,   OS_32,   OS_64,   OS_128,
                  OS_S8,  OS_S16,  OS_S32,  OS_S64,  OS_S128,
                 { single, double, extended, comp, 128-bit floating/vector transfer }
                  OS_F32, OS_F64,  OS_F80,  OS_C64,  OS_F128,
                 { multi-media sizes, describes only the register size but not how it is split,
                   this information must be passed separately }
                  OS_M8,  OS_M16,  OS_M32,  OS_M64,  OS_M128,  OS_M256,  OS_M512);

      { Register types }
      TRegisterType = (
        R_INVALIDREGISTER, { = 0 }
        R_INTREGISTER,     { = 1 }
        R_FPUREGISTER,     { = 2 }
        { used by Intel only }
        R_MMXREGISTER,     { = 3 }
        R_MMREGISTER,      { = 4 }
        R_SPECIALREGISTER, { = 5 }
        R_ADDRESSREGISTER, { = 6 }
        { used on llvm, every temp gets its own "base register" }
        R_TEMPREGISTER,    { = 7 }
        { used on llvm for tracking metadata (every unique metadata has its own base register) }
        R_METADATAREGISTER,{ = 8 }
        { optional MAC16 (16 bit multiply-accumulate) registers on Xtensa }
        R_MAC16REGISTER,   { = 9 }
        { WebAssembly externref }
        R_EXTERNREFREGISTER, { = 10 }
        { WebAssembly funcref }
        R_FUNCREFREGISTER  { = 11 }

        { do not add more than 16 elements (ifdef by cpu type if needed)
          so we can store this in one nibble and pack TRegister
          if the supreg width should be extended }
      );

      { Sub registers }
      TSubRegister = (
        R_SUBNONE, { = 0; no sub register possible }
        R_SUBL,    { = 1; 8 bits, Like AL }
        R_SUBH,    { = 2; 8 bits, Like AH }
        R_SUBW,    { = 3; 16 bits, Like AX }
        R_SUBD,    { = 4; 32 bits, Like EAX }
        R_SUBQ,    { = 5; 64 bits, Like RAX }
        { For Sparc floats that use F0:F1 to store doubles }
        R_SUBFS,   { = 6; Float that allocates 1 FPU register }
        R_SUBFD,   { = 7; Float that allocates 2 FPU registers }
        R_SUBFQ,   { = 8; Float that allocates 4 FPU registers }
        R_SUBMMS,  { = 9; single scalar in multi media register }
        R_SUBMMD,  { = 10; double scalar in multi media register }
        R_SUBMMWHOLE,  { = 11; complete MM register, size depends on CPU }
        { For Intel X86 AVX-Register }
        R_SUBMMX,     { = 12; 128 BITS }
        R_SUBMMY,     { = 13; 256 BITS }
        R_SUBMMZ,     { = 14; 512 BITS }

        { Subregisters for the flags register (x86) }
        R_SUBFLAGCARRY,     { = 15; Carry flag }
        R_SUBFLAGPARITY,    { = 16; Parity flag }
        R_SUBFLAGAUXILIARY, { = 17; Auxiliary flag }
        R_SUBFLAGZERO,      { = 18; Zero flag }
        R_SUBFLAGSIGN,      { = 19; Sign flag }
        R_SUBFLAGOVERFLOW,  { = 20; Overflow flag }
        R_SUBFLAGINTERRUPT, { = 21; Interrupt enable flag }
        R_SUBFLAGDIRECTION, { = 22; Direction flag }

        { subregisters for the metadata register (llvm) }
        R_SUBMETASTRING    { = 23 }
{$ifdef aarch64}
        , R_SUBMM8B          { = 24; for arrangement of v regs on aarch64 }
        , R_SUBMM16B         { = 25; for arrangement of v regs on aarch64 }
        , R_SUBMM4H          { = 26; for arrangement of v regs on aarch64 }
        , R_SUBMM8H          { = 27; for arrangement of v regs on aarch64 }
        , R_SUBMM2S          { = 28; for arrangement of v regs on aarch64 }
        , R_SUBMM4S          { = 29; for arrangement of v regs on aarch64 }
        , R_SUBMM1D          { = 30; for arrangement of v regs on aarch64 }
        , R_SUBMM2D          { = 31; for arrangement of v regs on aarch64 }
        , R_SUBMMB1          { = 32; for arrangement of v regs on aarch64; for use with ldN/stN }
        , R_SUBMMH1          { = 33; for arrangement of v regs on aarch64; for use with ldN/stN }
        , R_SUBMMS1          { = 34; for arrangement of v regs on aarch64; for use with ldN/stN }
        , R_SUBMMD1          { = 35; for arrangement of v regs on aarch64; for use with ldN/stN }
{$endif aarch64}
{$ifdef x86}
        , R_SUBMMT           { = 24; For Intel X86 AMX-Register }
{$endif x86}
      );
      TSubRegisterSet = set of TSubRegister;

      TSuperRegister = type Word;

      {
        The new register coding:

        SuperRegister   (bits 0..15)
        Subregister     (bits 16..23)
        Register type   (bits 24..31)

        TRegister is defined as an enum to make it incompatible
        with TSuperRegister to avoid mixing them
      }
      TRegister = (
        TRegisterLowEnum := Low(LongInt),
        TRegisterHighEnum := High(LongInt)
      );
      TRegisterRec=packed record
{$ifdef FPC_BIG_ENDIAN}
         RegType : TRegisterType;
         SubReg  : TSubRegister;
         SupReg  : TSuperRegister;
{$else FPC_BIG_ENDIAN}
         SupReg  : TSuperRegister;
         SubReg  : TSubRegister;
         RegType : TRegisterType;
{$endif FPC_BIG_ENDIAN}
      end;

      { A type to store register locations for 64 Bit values. }
{$ifdef cpu64bitalu}
      TRegister64 = TRegister;
      TRegister128 = record
         RegLo,RegHi : TRegister;
      end;
{$else cpu64bitalu}
      TRegister64 = record
         RegLo,RegHi : TRegister;
      end;
{$endif cpu64bitalu}

      { Set type definition for registers }
      TSuperRegisterSet = array[Byte] of set of Byte;

      PMMShuffle = ^TMMShuffle;

      { this record describes shuffle operations for mm operations; if a pointer a shuffle record
        passed to an mm operation is nil, it means that the whole location is moved }
      TMMShuffle = record
        { describes how many shuffles are actually described, if len=0 then
          moving the scalar with index 0 to the scalar with index 0 is meant,
          if len=-1, then a variable/unknown length is assumed }
        Len : ShortInt;
        { lower byte of each entry of this array describes index of the source data index while
          the upper byte describes the destination index }
        Shuffles : array[1..1] of Word;
      end;

      Tsuperregisterarray=array of TSuperRegister;

      Tsuperregisterworklist=object
        BufLength,
        BufLengthInc,
        Length:Word;
        Buf:TSuperRegisterArray;
        constructor Init;
        constructor CopyFrom(const X:TSuperRegisterWorkList);
        destructor  Done;
        procedure Clear;
        procedure Add(S:TSuperRegister);
        function AddNoDup(S:TSuperRegister): Boolean;
        { returns the last element and removes it from the list }
        function Get:TSuperRegister;
        function ReadIdx(I:Word):TSuperRegister;
        procedure DeleteIdx(I:Word);
        function Delete(S:TSuperRegister):Boolean;
      end;
      PSuperRegisterWorkList=^TSuperRegisterWorkList;

    const
       { alias for easier understanding }
       RSSERegister = R_MMREGISTER;

       { Invalid register number }
       RSInvalid    = High(TSuperRegister);
       NRInvalid    = TRegister($ffffffff);

       TCgSize2Size : Array[TCgSize] of Integer =
        (0,
         { integer values }
         1,  2,  4,  8, 16,
         1,  2,  4,  8, 16,
         { floating point values }
         4,  8, 10,  8, 16,
         { multimedia values }
         1,  2,  4,  8, 16, 32, 64);

       TFloat2TCgSize: array[TFloatType] of TCgSize =
         (OS_F32,OS_F64,OS_F80,OS_F80,OS_C64,OS_C64);

       TVarRegable2TCGLoc : array[TVarRegable] of TCGLoc = (LOC_VOID,
          LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMREGISTER,LOC_CREGISTER);

{$if defined(cpu64bitalu)}
       { operand size describing an unsigned value in a pair of int registers }
       OSPair = OS_128;
       { operand size describing an signed value in a pair of int registers }
       OSSPair = OS_S128;
{$elseif defined(cpu32bitalu)}
       { operand size describing an unsigned value in a pair of int registers }
       OSPair = OS_64;
       { operand size describing an signed value in a pair of int registers }
       OSSPair = OS_S64;
{$endif}

       { Table to convert tcgsize variables to the corresponding
         unsigned types }
       TCgSize2Unsigned : array[TCgSize] of TCgSize = (OS_NO,
         OS_8,    OS_16,   OS_32,   OS_64,   OS_128,
         OS_8,    OS_16,   OS_32,   OS_64,   OS_128,

         OS_F32,  OS_F64,  OS_F80,  OS_C64,  OS_F128,
         OS_M8,   OS_M16,  OS_M32,  OS_M64,  OS_M128, OS_M256, OS_M512);


       TCgSize2Signed : array[TCgSize] of TCgSize = (OS_NO,
         OS_S8,   OS_S16,  OS_S32,  OS_S64,  OS_S128,
         OS_S8,   OS_S16,  OS_S32,  OS_S64,  OS_S128,

         OS_F32,  OS_F64,  OS_F80,  OS_C64,  OS_F128,
         OS_M8,   OS_M16,  OS_M32,  OS_M64,  OS_M128, OS_M256,OS_M512);


       TCGLoc2Str : array[TCGLoc] of string[12] = (
            'LOC_INVALID',
            'LOC_VOID',
            'LOC_CONST',
            'LOC_JUMP',
            'LOC_FLAGS',
            'LOC_REG',
            'LOC_CREG',
            'LOC_FPUREG',
            'LOC_CFPUREG',
            'LOC_MMXREG',
            'LOC_CMMXREG',
            'LOC_MMREG',
            'LOC_CMMREG',
            'LOC_SSETREG',
            'LOC_CSSETREG',
            'LOC_SSETREF',
            'LOC_CSSETREF',
            'LOC_CREF',
            'LOC_REF'
            );

    var
       MMS_MoveScalar,
       MMS_Variable,
       MMS_2,
       MMS_4,
       MMS_8,
       MMS_16,
       MMS_32 : PMMShuffle;

    procedure SupRegSet_Reset(out Regs:TSuperRegisterSet;SetAll:Boolean;
                              MaxReg:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure SupRegSet_Include(var Regs:TSuperRegisterSet;S:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure SupRegSet_Exclude(var Regs:TSuperRegisterSet;S:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    function SupRegSet_In(const Regs:TSuperRegisterSet;S:TSuperRegister):Boolean;{$ifdef USEINLINE}inline;{$endif}

    function NewReg(RT:TRegisterType;SR:TSuperRegister;SB:TSubRegister):TRegister;{$ifdef USEINLINE}inline;{$endif}
    function GetSubReg(R:TRegister):TSubRegister;{$ifdef USEINLINE}inline;{$endif}
    function GetSupReg(R:TRegister):TSuperRegister;{$ifdef USEINLINE}inline;{$endif}
    function GetRegType(R:TRegister):TRegisterType;{$ifdef USEINLINE}inline;{$endif}
    procedure SetSubReg(var R:TRegister;SR:TSubRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure SetSupReg(var R:TRegister;SR:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    function Generic_RegName(R:TRegister):string;

    {# From a constant numeric value, return the abstract code generator
       size.
    }
    function Int_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
    function Int_Float_CGSize(const A: TCGInt): TCgSize;
    function Float_Array_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
    function Double_Array_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}

    function TCgSize2Str(CGSize: TCgSize):string;
    function TOpCG2Str(OpCG: TOpCG):string;
    function TOpCmp2Str(OpCmp: TOpCmp):string;

    { return the inverse condition of opcmp }
    function Inverse_OpCmp(OpCmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}

    { return the opcmp needed when swapping the operands }
    function Swap_OpCmp(OpCmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}

    { return whether op is commutative }
    function CommutativeOp(Op: TOpCG): Boolean;{$ifdef USEINLINE}inline;{$endif}

    { returns true, if shuffle describes a real shuffle operation and not only a move }
    function RealShuffle(Shuffle : PMMShuffle) : Boolean;

    { returns true, if the shuffle describes only a move of the scalar at index 0 }
    function ShuffleScalar(Shuffle : PMMShuffle) : Boolean;

    { removes shuffling from shuffle, this means that the destination index of each shuffle is copied to
      the source }
    procedure RemoveShuffles(var Shuffle : TMMShuffle);

    function Is_Float_CGSize(Size: TCgSize): Boolean;{$ifdef USEINLINE}inline;{$endif}

implementation

    uses
      Verbose,
      CUtils;

{******************************************************************************
                             tsuperregisterworklist
******************************************************************************}

    constructor TSuperRegisterWorkList.Init;

    begin
      Length:=0;
      BufLength:=0;
      BufLengthInc:=16;
      Buf:=nil;
    end;

    constructor TSuperRegisterWorkList.CopyFrom(const X:TSuperRegisterWorkList);

    begin
      // self.x cannot be used, we'd copy over the dyn array
      BufLength:=X.BufLength;
      BufLengthInc:=X.BufLengthInc;
      Length:=X.Length;
      if X.Buf<>nil then
        begin
          SetLength(Buf,BufLength);
          Move(X.Buf[0],Buf[0],Length*SizeOf(TSuperRegister));
        end;
    end;

    destructor TSuperRegisterWorkList.Done;

    begin
      Buf:=nil;
    end;


    procedure TSuperRegisterWorkList.Add(S:TSuperRegister);

    begin
      Inc(Length);
      { Need to increase buffer length? }
      if Length>=BufLength then
        begin
          Inc(BufLength,BufLengthInc);
          BufLengthInc:=BufLengthInc*2;
          if BufLengthInc>256 then
             BufLengthInc:=256;
          SetLength(Buf,BufLength);
        end;
      Buf[Length-1]:=S;
    end;


    function TSuperRegisterWorkList.AddNoDup(S:TSuperRegister): Boolean;

    begin
      AddNoDup := False;
      if (Length=0) or (IndexWord(Buf[0],Length,S) = -1) then
        begin
          Add(S);
          AddNoDup := True;
        end;
    end;


    procedure TSuperRegisterWorkList.Clear;

    begin
      Length:=0;
    end;


    procedure TSuperRegisterWorkList.DeleteIdx(I:Word);

    begin
      if I>=Length then
        InternalError(200310144);
      Buf[I]:=Buf[Length-1];
      Dec(Length);
    end;


    function TSuperRegisterWorkList.ReadIdx(I:Word):TSuperRegister;
      begin
        if (I >= Length) then
          InternalError(2005010601);
        Result := Buf[I];
      end;


    function TSuperRegisterWorkList.Get:TSuperRegister;

    begin
      if Length=0 then
        InternalError(200310142);
      Dec(Length);
      Get:=Buf[Length];
    end;


    function TSuperRegisterWorkList.Delete(S:TSuperRegister):Boolean;

    var
      I:LongInt;

    begin
      Delete:=False;
      if (System.Length(Buf)=0) then
        Exit;
      { indexword in 1.0.x and 1.9.4 is broken }
      I:=IndexWord(Buf[0],Length,S);
      if I<>-1 then
        begin
          DeleteIdx(I);
          Delete := True;
        end;
    end;


    procedure SupRegSet_Reset(out Regs:TSuperRegisterSet;SetAll:Boolean;
                              MaxReg:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}

    begin
      FillChar(Regs,(MaxReg+7) shr 3,-Byte(SetAll));
    end;


    procedure SupRegSet_Include(var Regs:TSuperRegisterSet;S:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        Include(Regs[S shr 8],(S and $ff));
      end;


    procedure SupRegSet_Exclude(var Regs:TSuperRegisterSet;S:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        Exclude(Regs[S shr 8],(S and $ff));
      end;


    function SupRegSet_In(const Regs:TSuperRegisterSet;S:TSuperRegister):Boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=(S and $ff) in Regs[S shr 8];
      end;


    function NewReg(RT:TRegisterType;SR:TSuperRegister;SB:TSubRegister):TRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(Result).RegType:=RT;
        TRegisterRec(Result).SupReg:=SR;
        TRegisterRec(Result).SubReg:=SB;
      end;


    function GetSubReg(R:TRegister):TSubRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=TRegisterRec(R).SubReg;
      end;


    function GetSupReg(R:TRegister):TSuperRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=TRegisterRec(R).SupReg;
      end;


    function GetRegType(R:TRegister):TRegisterType;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=TRegisterRec(R).RegType;
      end;


    procedure SetSubReg(var R:TRegister;SR:TSubRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(R).SubReg:=SR;
      end;


    procedure SetSupReg(var R:TRegister;SR:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(R).SupReg:=SR;
      end;


    function Generic_RegName(R:TRegister):string;
      var
        NR : string[12];
      begin
        Str(GetSupReg(R),NR);
        case GetRegType(R) of
          R_INTREGISTER:
            Result:='ireg'+NR;
          R_FPUREGISTER:
            Result:='freg'+NR;
          R_MMREGISTER:
            Result:='mreg'+NR;
          R_MMXREGISTER:
            Result:='xreg'+NR;
          R_ADDRESSREGISTER:
            Result:='areg'+NR;
          R_SPECIALREGISTER:
            Result:='sreg'+NR;
          else
            begin
              Result:='INVALID';
              Exit;
            end;
        end;
        case GetSubReg(R) of
          R_SUBNONE:
            ;
          R_SUBL:
            Result:=Result+'l';
          R_SUBH:
            Result:=Result+'h';
          R_SUBW:
            Result:=Result+'w';
          R_SUBD:
            Result:=Result+'d';
          R_SUBQ:
            Result:=Result+'q';
          R_SUBFS:
            Result:=Result+'fs';
          R_SUBFD:
            Result:=Result+'fd';
          R_SUBMMD:
            Result:=Result+'md';
          R_SUBMMS:
            Result:=Result+'ms';
          R_SUBMMWHOLE:
            Result:=Result+'ma';
          R_SUBMMX:
            Result:=Result+'mx';
          R_SUBMMY:
            Result:=Result+'my';
          R_SUBMMZ:
            Result:=Result+'mz';
{$ifdef aarch64}
          R_SUBMM8B:
            Result:=Result+'m8b';
          R_SUBMM16B:
            Result:=Result+'m16b';
          R_SUBMM4H:
            Result:=Result+'m4h';
          R_SUBMM8H:
            Result:=Result+'m8h';
          R_SUBMM2S:
            Result:=Result+'m2s';
          R_SUBMM4S:
            Result:=Result+'m4s';
          R_SUBMM2D:
            Result:=Result+'m2d';
          R_SUBMMB1:
            Result:=Result+'mb1';
          R_SUBMMH1:
            Result:=Result+'mh1';
          R_SUBMMS1:
            Result:=Result+'ms1';
          R_SUBMMD1:
            Result:=Result+'md1';
{$endif}
          else
            InternalError(200308252);
        end;
      end;


    function Int_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      const
        Size2CGSize : array[0..8] of TCgSize = (
          OS_NO,OS_8,OS_16,OS_NO,OS_32,OS_NO,OS_NO,OS_NO,OS_64
        );
      begin
{$ifdef cpu64bitalu}
        if A=16 then
          Result:=OS_128
        else
{$endif cpu64bitalu}
        if A>8 then
          Result:=OS_NO
        else
          Result:=Size2CGSize[A];
      end;


    function Int_Float_CGSize(const A: TCGInt): TCgSize;
      begin
        case A of
          4 :
            Result:=OS_F32;
          8 :
            Result:=OS_F64;
          10 :
            Result:=OS_F80;
          16 :
            Result:=OS_F128;
          else
            InternalError(200603211);
        end;
      end;


    function Float_Array_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      begin
        case A of
          4:
            Result := OS_M32;
          16:
            Result := OS_M128;
          32:
            Result := OS_M256;
          64:
            Result := OS_M512;
          else
            Result := Int_CGSize(A);
        end;
      end;

    function Double_Array_CGSize(const A: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      begin
        case A of
          8:
            Result := OS_M64;
          16:
            Result := OS_M128;
          32:
            Result := OS_M256;
          64:
            Result := OS_M512;
          else
            Result := Int_CGSize(A);
        end;
      end;


    function TCgSize2Str(CGSize: TCgSize):string;
      begin
        Str(CGSize, Result);
      end;


    function TOpCG2Str(OpCG: TOpCG):string;
      begin
        Str(OpCG, Result);
      end;


    function TOpCmp2Str(OpCmp: TOpCmp):string;
      begin
        Str(OpCmp, Result);
      end;


    function Inverse_OpCmp(OpCmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}
      const
        List: array[TOpCmp] of TOpCmp =
          (OC_NONE,OC_NE,OC_LTE,OC_GTE,OC_LT,OC_GT,OC_EQ,OC_A,OC_AE,
           OC_B,OC_BE);
      begin
        Inverse_OpCmp := List[OpCmp];
      end;


    function Swap_OpCmp(OpCmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}
      const
        List: array[TOpCmp] of TOpCmp =
          (OC_NONE,OC_EQ,OC_LT,OC_GT,OC_LTE,OC_GTE,OC_NE,OC_AE,OC_A,
           OC_BE,OC_B);
      begin
        Swap_OpCmp := List[OpCmp];
      end;


    function CommutativeOp(Op: TOpCG): Boolean;{$ifdef USEINLINE}inline;{$endif}
      const
        List: array[TOpCG] of Boolean =
          (True,False,True,True,False,False,True,True,False,False,
           True,False,False,False,False,True,False,False);
      begin
        CommutativeOp := List[Op];
      end;


    function RealShuffle(Shuffle : PMMShuffle) : Boolean;
      var
        I : LongInt;
      begin
        RealShuffle:=True;
        if (Shuffle=nil) or (Shuffle^.Len<1) then
          RealShuffle:=False
        else
          begin
            for I:=1 to Shuffle^.Len do
              begin
                if (Shuffle^.Shuffles[I] and $ff)<>((Shuffle^.Shuffles[I] and $ff00) shr 8) then
                  Exit;
              end;
            RealShuffle:=False;
          end;
      end;


    function ShuffleScalar(Shuffle : PMMShuffle) : Boolean;
      begin
        Result:=Shuffle^.Len=0;
      end;


    procedure RemoveShuffles(var Shuffle : TMMShuffle);
      var
        I : LongInt;
      begin
        if Shuffle.Len=0 then
          Exit;
        for I:=1 to Shuffle.Len do
          Shuffle.Shuffles[I]:=(Shuffle.Shuffles[I] and $f) or ((Shuffle.Shuffles[I] and $f0) shr 4);
      end;


    function Is_Float_CGSize(Size: TCgSize): Boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=Size in [OS_F32..OS_F128];
      end;


   procedure InitMMS(var P : PMMShuffle;Len : ShortInt);
     var
       I : Integer;
     begin
       GetMem(P,SizeOf(TMMShuffle)+(Max(Len,0)-1)*2);
       P^.Len:=Len;
       for I:=1 to Len do
{$push}
{$R-}
         P^.Shuffles[I]:=I;
{$pop}
     end;

initialization
  InitMMS(MMS_MoveScalar,0);
  InitMMS(MMS_Variable,-1);
  InitMMS(MMS_2,2);
  InitMMS(MMS_4,4);
  InitMMS(MMS_8,8);
  InitMMS(MMS_16,16);
  InitMMS(MMS_32,32);
finalization
  FreeMem(MMS_MoveScalar);
  FreeMem(MMS_Variable);
  FreeMem(MMS_2);
  FreeMem(MMS_4);
  FreeMem(MMS_8);
  FreeMem(MMS_16);
  FreeMem(MMS_32);
end.

