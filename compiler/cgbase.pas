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
      symconst;

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

       TCGNonRefLoc=low(TCGLoc)..pred(LOC_CREFERENCE);
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

      TSuperRegister = type word;

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
         regtype : TRegisterType;
         subreg  : TSubRegister;
         supreg  : TSuperRegister;
{$else FPC_BIG_ENDIAN}
         supreg  : TSuperRegister;
         subreg  : TSubRegister;
         regtype : TRegisterType;
{$endif FPC_BIG_ENDIAN}
      end;

      { A type to store register locations for 64 Bit values. }
{$ifdef cpu64bitalu}
      TRegister64 = TRegister;
      TRegister128 = record
         reglo,reghi : TRegister;
      end;
{$else cpu64bitalu}
      TRegister64 = record
         reglo,reghi : TRegister;
      end;
{$endif cpu64bitalu}

      { Set type definition for registers }
      TSuperRegisterSet = array[byte] of set of byte;

      PMMShuffle = ^TMMShuffle;

      { this record describes shuffle operations for mm operations; if a pointer a shuffle record
        passed to an mm operation is nil, it means that the whole location is moved }
      TMMShuffle = record
        { describes how many shuffles are actually described, if len=0 then
          moving the scalar with index 0 to the scalar with index 0 is meant,
          if len=-1, then a variable/unknown length is assumed }
        len : Shortint;
        { lower byte of each entry of this array describes index of the source data index while
          the upper byte describes the destination index }
        shuffles : array[1..1] of word;
      end;

      Tsuperregisterarray=array of TSuperRegister;

      Tsuperregisterworklist=object
        buflength,
        buflengthinc,
        length:word;
        buf:tsuperregisterarray;
        constructor init;
        constructor copyfrom(const x:Tsuperregisterworklist);
        destructor  done;
        procedure clear;
        procedure add(s:TSuperRegister);
        function addnodup(s:TSuperRegister): boolean;
        { returns the last element and removes it from the list }
        function get:TSuperRegister;
        function readidx(i:word):TSuperRegister;
        procedure deleteidx(i:word);
        function delete(s:TSuperRegister):boolean;
      end;
      PSuperRegisterWorkList=^tsuperregisterworklist;

    const
       { alias for easier understanding }
       R_SSEREGISTER = R_MMREGISTER;

       { Invalid register number }
       RS_INVALID    = high(TSuperRegister);
       NR_INVALID    = TRegister($ffffffff);

       tcgsize2size : Array[TCgSize] of integer =
        (0,
         { integer values }
         1,  2,  4,  8, 16,
         1,  2,  4,  8, 16,
         { floating point values }
         4,  8, 10,  8, 16,
         { multimedia values }
         1,  2,  4,  8, 16, 32, 64);

       tfloat2tcgsize: array[TFloatType] of TCgSize =
         (OS_F32,OS_F64,OS_F80,OS_F80,OS_C64,OS_C64);

       tvarregable2tcgloc : array[TVarRegable] of TCGLoc = (LOC_VOID,
          LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMREGISTER,LOC_CREGISTER);

{$if defined(cpu64bitalu)}
       { operand size describing an unsigned value in a pair of int registers }
       OS_PAIR = OS_128;
       { operand size describing an signed value in a pair of int registers }
       OS_SPAIR = OS_S128;
{$elseif defined(cpu32bitalu)}
       { operand size describing an unsigned value in a pair of int registers }
       OS_PAIR = OS_64;
       { operand size describing an signed value in a pair of int registers }
       OS_SPAIR = OS_S64;
{$endif}

       { Table to convert tcgsize variables to the corresponding
         unsigned types }
       tcgsize2unsigned : array[TCgSize] of TCgSize = (OS_NO,
         OS_8,    OS_16,   OS_32,   OS_64,   OS_128,
         OS_8,    OS_16,   OS_32,   OS_64,   OS_128,

         OS_F32,  OS_F64,  OS_F80,  OS_C64,  OS_F128,
         OS_M8,   OS_M16,  OS_M32,  OS_M64,  OS_M128, OS_M256, OS_M512);


       tcgsize2signed : array[TCgSize] of TCgSize = (OS_NO,
         OS_S8,   OS_S16,  OS_S32,  OS_S64,  OS_S128,
         OS_S8,   OS_S16,  OS_S32,  OS_S64,  OS_S128,

         OS_F32,  OS_F64,  OS_F80,  OS_C64,  OS_F128,
         OS_M8,   OS_M16,  OS_M32,  OS_M64,  OS_M128, OS_M256,OS_M512);


       tcgloc2str : array[TCGLoc] of string[12] = (
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
       mms_movescalar,
       mms_variable,
       mms_2,
       mms_4,
       mms_8,
       mms_16,
       mms_32 : PMMShuffle;

    procedure supregset_reset(out regs:TSuperRegisterSet;setall:boolean;
                              maxreg:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure supregset_include(var regs:TSuperRegisterSet;s:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure supregset_exclude(var regs:TSuperRegisterSet;s:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    function supregset_in(const regs:TSuperRegisterSet;s:TSuperRegister):boolean;{$ifdef USEINLINE}inline;{$endif}

    function newreg(rt:TRegisterType;sr:TSuperRegister;sb:TSubRegister):TRegister;{$ifdef USEINLINE}inline;{$endif}
    function getsubreg(r:TRegister):TSubRegister;{$ifdef USEINLINE}inline;{$endif}
    function getsupreg(r:TRegister):TSuperRegister;{$ifdef USEINLINE}inline;{$endif}
    function getregtype(r:TRegister):TRegisterType;{$ifdef USEINLINE}inline;{$endif}
    procedure setsubreg(var r:TRegister;sr:TSubRegister);{$ifdef USEINLINE}inline;{$endif}
    procedure setsupreg(var r:TRegister;sr:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
    function generic_regname(r:TRegister):string;

    {# From a constant numeric value, return the abstract code generator
       size.
    }
    function int_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
    function int_float_cgsize(const a: TCGInt): TCgSize;
    function float_array_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
    function double_array_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}

    function tcgsize2str(cgsize: TCgSize):string;
    function topcg2str(opcg: TOpCG):string;
    function topcmp2str(opcmp: TOpCmp):string;

    { return the inverse condition of opcmp }
    function inverse_opcmp(opcmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}

    { return the opcmp needed when swapping the operands }
    function swap_opcmp(opcmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}

    { return whether op is commutative }
    function commutativeop(op: TOpCG): boolean;{$ifdef USEINLINE}inline;{$endif}

    { returns true, if shuffle describes a real shuffle operation and not only a move }
    function realshuffle(shuffle : PMMShuffle) : boolean;

    { returns true, if the shuffle describes only a move of the scalar at index 0 }
    function shufflescalar(shuffle : PMMShuffle) : boolean;

    { removes shuffling from shuffle, this means that the destination index of each shuffle is copied to
      the source }
    procedure removeshuffles(var shuffle : TMMShuffle);

    function is_float_cgsize(size: TCgSize): boolean;{$ifdef USEINLINE}inline;{$endif}

implementation

    uses
      Verbose,
      CUtils;

{******************************************************************************
                             tsuperregisterworklist
******************************************************************************}

    constructor tsuperregisterworklist.init;

    begin
      length:=0;
      buflength:=0;
      buflengthinc:=16;
      buf:=nil;
    end;

    constructor Tsuperregisterworklist.copyfrom(const x:Tsuperregisterworklist);

    begin
      // self.x cannot be used, we'd copy over the dyn array
      buflength:=x.buflength;
      buflengthinc:=x.buflengthinc;
      length:=x.length;
      if x.buf<>nil then
        begin
          SetLength(buf,buflength);
          move(x.buf[0],buf[0],length*sizeof(TSuperRegister));
        end;
    end;

    destructor tsuperregisterworklist.done;

    begin
      buf:=nil;
    end;


    procedure tsuperregisterworklist.add(s:TSuperRegister);

    begin
      inc(length);
      { Need to increase buffer length? }
      if length>=buflength then
        begin
          inc(buflength,buflengthinc);
          buflengthinc:=buflengthinc*2;
          if buflengthinc>256 then
             buflengthinc:=256;
          SetLength(buf,buflength);
        end;
      buf[length-1]:=s;
    end;


    function tsuperregisterworklist.addnodup(s:TSuperRegister): boolean;

    begin
      addnodup := false;
      if (length=0) or (indexword(buf[0],length,s) = -1) then
        begin
          add(s);
          addnodup := true;
        end;
    end;


    procedure tsuperregisterworklist.clear;

    begin
      length:=0;
    end;


    procedure tsuperregisterworklist.deleteidx(i:word);

    begin
      if i>=length then
        InternalError(200310144);
      buf[i]:=buf[length-1];
      dec(length);
    end;


    function tsuperregisterworklist.readidx(i:word):TSuperRegister;
      begin
        if (i >= length) then
          InternalError(2005010601);
        result := buf[i];
      end;


    function tsuperregisterworklist.get:TSuperRegister;

    begin
      if length=0 then
        InternalError(200310142);
      dec(length);
      get:=buf[length];
    end;


    function tsuperregisterworklist.delete(s:TSuperRegister):boolean;

    var
      i:LongInt;

    begin
      delete:=false;
      if (system.length(buf)=0) then
        exit;
      { indexword in 1.0.x and 1.9.4 is broken }
      i:=indexword(buf[0],length,s);
      if i<>-1 then
        begin
          deleteidx(i);
          delete := true;
        end;
    end;


    procedure supregset_reset(out regs:TSuperRegisterSet;setall:boolean;
                              maxreg:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}

    begin
      fillchar(regs,(maxreg+7) shr 3,-byte(setall));
    end;


    procedure supregset_include(var regs:TSuperRegisterSet;s:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        include(regs[s shr 8],(s and $ff));
      end;


    procedure supregset_exclude(var regs:TSuperRegisterSet;s:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        exclude(regs[s shr 8],(s and $ff));
      end;


    function supregset_in(const regs:TSuperRegisterSet;s:TSuperRegister):boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=(s and $ff) in regs[s shr 8];
      end;


    function newreg(rt:TRegisterType;sr:TSuperRegister;sb:TSubRegister):TRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(result).regtype:=rt;
        TRegisterRec(result).supreg:=sr;
        TRegisterRec(result).subreg:=sb;
      end;


    function getsubreg(r:TRegister):TSubRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=TRegisterRec(r).subreg;
      end;


    function getsupreg(r:TRegister):TSuperRegister;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=TRegisterRec(r).supreg;
      end;


    function getregtype(r:TRegister):TRegisterType;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=TRegisterRec(r).regtype;
      end;


    procedure setsubreg(var r:TRegister;sr:TSubRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(r).subreg:=sr;
      end;


    procedure setsupreg(var r:TRegister;sr:TSuperRegister);{$ifdef USEINLINE}inline;{$endif}
      begin
        TRegisterRec(r).supreg:=sr;
      end;


    function generic_regname(r:TRegister):string;
      var
        nr : string[12];
      begin
        str(getsupreg(r),nr);
        case getregtype(r) of
          R_INTREGISTER:
            result:='ireg'+nr;
          R_FPUREGISTER:
            result:='freg'+nr;
          R_MMREGISTER:
            result:='mreg'+nr;
          R_MMXREGISTER:
            result:='xreg'+nr;
          R_ADDRESSREGISTER:
            result:='areg'+nr;
          R_SPECIALREGISTER:
            result:='sreg'+nr;
          else
            begin
              result:='INVALID';
              exit;
            end;
        end;
        case getsubreg(r) of
          R_SUBNONE:
            ;
          R_SUBL:
            result:=result+'l';
          R_SUBH:
            result:=result+'h';
          R_SUBW:
            result:=result+'w';
          R_SUBD:
            result:=result+'d';
          R_SUBQ:
            result:=result+'q';
          R_SUBFS:
            result:=result+'fs';
          R_SUBFD:
            result:=result+'fd';
          R_SUBMMD:
            result:=result+'md';
          R_SUBMMS:
            result:=result+'ms';
          R_SUBMMWHOLE:
            result:=result+'ma';
          R_SUBMMX:
            result:=result+'mx';
          R_SUBMMY:
            result:=result+'my';
          R_SUBMMZ:
            result:=result+'mz';
{$ifdef aarch64}
          R_SUBMM8B:
            result:=result+'m8b';
          R_SUBMM16B:
            result:=result+'m16b';
          R_SUBMM4H:
            result:=result+'m4h';
          R_SUBMM8H:
            result:=result+'m8h';
          R_SUBMM2S:
            result:=result+'m2s';
          R_SUBMM4S:
            result:=result+'m4s';
          R_SUBMM2D:
            result:=result+'m2d';
          R_SUBMMB1:
            result:=result+'mb1';
          R_SUBMMH1:
            result:=result+'mh1';
          R_SUBMMS1:
            result:=result+'ms1';
          R_SUBMMD1:
            result:=result+'md1';
{$endif}
          else
            InternalError(200308252);
        end;
      end;


    function int_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      const
        size2cgsize : array[0..8] of TCgSize = (
          OS_NO,OS_8,OS_16,OS_NO,OS_32,OS_NO,OS_NO,OS_NO,OS_64
        );
      begin
{$ifdef cpu64bitalu}
        if a=16 then
          result:=OS_128
        else
{$endif cpu64bitalu}
        if a>8 then
          result:=OS_NO
        else
          result:=size2cgsize[a];
      end;


    function int_float_cgsize(const a: TCGInt): TCgSize;
      begin
        case a of
          4 :
            result:=OS_F32;
          8 :
            result:=OS_F64;
          10 :
            result:=OS_F80;
          16 :
            result:=OS_F128;
          else
            InternalError(200603211);
        end;
      end;


    function float_array_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      begin
        case a of
          4:
            result := OS_M32;
          16:
            result := OS_M128;
          32:
            result := OS_M256;
          64:
            result := OS_M512;
          else
            result := int_cgsize(a);
        end;
      end;

    function double_array_cgsize(const a: TCGInt): TCgSize;{$ifdef USEINLINE}inline;{$endif}
      begin
        case a of
          8:
            result := OS_M64;
          16:
            result := OS_M128;
          32:
            result := OS_M256;
          64:
            result := OS_M512;
          else
            result := int_cgsize(a);
        end;
      end;


    function tcgsize2str(cgsize: TCgSize):string;
      begin
        Str(cgsize, Result);
      end;


    function topcg2str(opcg: TOpCG):string;
      begin
        Str(opcg, Result);
      end;


    function topcmp2str(opcmp: TOpCmp):string;
      begin
        Str(opcmp, Result);
      end;


    function inverse_opcmp(opcmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}
      const
        list: array[TOpCmp] of TOpCmp =
          (OC_NONE,OC_NE,OC_LTE,OC_GTE,OC_LT,OC_GT,OC_EQ,OC_A,OC_AE,
           OC_B,OC_BE);
      begin
        inverse_opcmp := list[opcmp];
      end;


    function swap_opcmp(opcmp: TOpCmp): TOpCmp;{$ifdef USEINLINE}inline;{$endif}
      const
        list: array[TOpCmp] of TOpCmp =
          (OC_NONE,OC_EQ,OC_LT,OC_GT,OC_LTE,OC_GTE,OC_NE,OC_AE,OC_A,
           OC_BE,OC_B);
      begin
        swap_opcmp := list[opcmp];
      end;


    function commutativeop(op: TOpCG): boolean;{$ifdef USEINLINE}inline;{$endif}
      const
        list: array[TOpCG] of boolean =
          (true,false,true,true,false,false,true,true,false,false,
           true,false,false,false,false,true,false,false);
      begin
        commutativeop := list[op];
      end;


    function realshuffle(shuffle : PMMShuffle) : boolean;
      var
        i : LongInt;
      begin
        realshuffle:=true;
        if (shuffle=nil) or (shuffle^.len<1) then
          realshuffle:=false
        else
          begin
            for i:=1 to shuffle^.len do
              begin
                if (shuffle^.shuffles[i] and $ff)<>((shuffle^.shuffles[i] and $ff00) shr 8) then
                  exit;
              end;
            realshuffle:=false;
          end;
      end;


    function shufflescalar(shuffle : PMMShuffle) : boolean;
      begin
        result:=shuffle^.len=0;
      end;


    procedure removeshuffles(var shuffle : TMMShuffle);
      var
        i : LongInt;
      begin
        if shuffle.len=0 then
          exit;
        for i:=1 to shuffle.len do
          shuffle.shuffles[i]:=(shuffle.shuffles[i] and $f) or ((shuffle.shuffles[i] and $f0) shr 4);
      end;


    function is_float_cgsize(size: TCgSize): boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=size in [OS_F32..OS_F128];
      end;


   procedure Initmms(var p : PMMShuffle;len : ShortInt);
     var
       i : Integer;
     begin
       GetMem(p,sizeof(TMMShuffle)+(max(len,0)-1)*2);
       p^.len:=len;
       for i:=1 to len do
{$push}
{$R-}
         p^.shuffles[i]:=i;
{$pop}
     end;

initialization
  Initmms(mms_movescalar,0);
  Initmms(mms_variable,-1);
  Initmms(mms_2,2);
  Initmms(mms_4,4);
  Initmms(mms_8,8);
  Initmms(mms_16,16);
  Initmms(mms_32,32);
finalization
  FreeMem(mms_movescalar);
  FreeMem(mms_variable);
  FreeMem(mms_2);
  FreeMem(mms_4);
  FreeMem(mms_8);
  FreeMem(mms_16);
  FreeMem(mms_32);
end.

