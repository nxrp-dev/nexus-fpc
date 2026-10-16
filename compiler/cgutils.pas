{
    Copyright (c) 1998-2004 by Florian Klaempfl

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
{ This unit exports some helper routines which are used across the code generator }
unit cgutils;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      CClasses,
      AAsmBase,
      CPUBase,CGBase;

    const
      { implementation of max function using only functionality that can be
        evaluated as a constant expression by the compiler -- this is
        basically maxcpureg = max(max(first_int_imreg,first_fpu_imreg),first_mm_imreg)-1 }
      TmpMaxCPUFPUIntReg = first_int_imreg + ((first_fpu_imreg - first_int_imreg) * Ord(first_int_imreg < first_fpu_imreg));
      MaxCPURegister = (TmpMaxCPUFPUIntReg + ((first_mm_imreg - TmpMaxCPUFPUIntReg) * Ord(TmpMaxCPUFPUIntReg < first_mm_imreg)))-1;

    type
      { Set type definition for cpuregisters }
      TCPURegisterSet = set of 0..MaxCPURegister;
      TCPURegisterArray = array of TSuperRegister;

      { use record for type-safety; should only be accessed directly by temp
        manager }
      TRefTempPos = record
        Val: ASizeInt;
      end;

{$packset 1}
      { a reference may be volatile for reading, writing, or both. E.g., local variables
        inside try-blocks are volatile for writes (writes must not be removed, because at
        any point an exception may be triggered and then all previous writes to the
        variable must have been performed), but not for reads (these variables' values
        won't be changed behind the back of the current code just because they're in a
        try-block) }
      TVolatility = (vol_read,vol_write);
      TVolatilitySet = set of TVolatility;
{$packset default}

      { reference record, reordered for best alignment }
      PReference = ^TReference;
      TReference = record
         Offset      : ASizeInt;
         Symbol,
         RelSymbol   : TAsmSymbol;
         TempPos     : TRefTempPos;
{$if defined(x86)}
         Segment,
{$endif defined(x86)}
         Base,
         Index       : TRegister;
         RefAddr     : TRefAddr;
         ScaleFactor : Byte;
{$ifdef aarch64}
         SymbolData  : TLinkedListItem;
         ShiftImm    : Byte;
         AddressMode : TAddressMode;
         ShiftMode   : TShiftMode;
{$endif aarch64}
         Volatility: TVolatilitySet;
         Alignment : Byte;
      end;

   const
     CTempPosInvalid: TRefTempPos = (Val: Low(TRefTempPos.Val));

   type
      TSubsetRegister = record
        SubsetReg : TRegister;
        StartBit, BitLen: Byte;
        SubsetRegSize: TCgSize;
      end;

      TSubsetReference = record
        Ref: TReference;
        BitIndexReg: TRegister;
        StartBit, BitLen: Byte;
      end;

      TLocation = record
         Loc  : TCGLoc;
         Size : TCgSize;
         case TCGLoc of
{$ifdef cpuflags}
            LOC_FLAGS : (ResFlags : TResFlags);
{$endif cpuflags}
            LOC_CONSTANT : (
              case LongInt of
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
                1 : (Value : Int64);
{$else cpu64bitalu or cpuhighleveltarget}
    {$ifdef FPC_BIG_ENDIAN}
                1 : (ValueDummy,Value : LongInt);
    {$else FPC_BIG_ENDIAN}
                1 : (Value : LongInt);
    {$endif FPC_BIG_ENDIAN}
{$endif cpu64bitalu or cpuhighleveltarget}
                2 : (Value64 : Int64);
              );
            LOC_CREFERENCE,
            LOC_REFERENCE : (Reference : TReference);
            { segment in reference at the same place as in loc_register }
            LOC_REGISTER,
            LOC_CREGISTER : (
              case LongInt of
                1 : (Register : TRegister;
                     { some x86_64 targets require two function result registers }
                     RegisterHi : TRegister;
                    );
{$ifdef cpu64bitalu}
                { overlay a 128 Bit register type }
                2 : (Register128 : TRegister128);
{$else if not defined(cpuhighleveltarget}
                { overlay a 64 Bit register type }
                2 : (Register64 : TRegister64);
{$endif cpu64bitalu and not cpuhighleveltarget}
              );
            LOC_SUBSETREG,
            LOC_CSUBSETREG : (
              SReg: TSubsetRegister;
            );
            LOC_SUBSETREF : (
              SRef: TSubsetReference;
            );
            LOC_JUMP : (
              TrueLabel, FalseLabel: TAsmLabel;
            );
      end;


    { trerefence handling }

    {# Clear to zero a treference }
    procedure Reference_Reset(var Ref : TReference; Alignment: LongInt; Volatility: TVolatilitySet);
    {# Clear to zero a treference, and set is base address
       to base register.
    }
    procedure Reference_Reset_Base(var Ref: TReference; Base: TRegister; Offset: ASizeInt; TempPos: TRefTempPos; Alignment: LongInt; Volatility: TVolatilitySet);
    procedure Reference_Reset_Symbol(var Ref: TReference;Sym: TAsmSymbol; Offset: ASizeInt; Alignment : LongInt; Volatility: TVolatilitySet);
    { This routine verifies if two references are the same, and
       if so, returns TRUE, otherwise returns false.
    }
    function References_Equal(const SRef,DRef : TReference) : Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}

    { tlocation handling }

    { cannot be used for loc_(c)reference, because that one requires an alignment }
    procedure Location_Reset(var L : TLocation;LT:TCGNonRefLoc;LSize:TCgSize);
    { for loc_(c)reference }
    procedure Location_Reset_Ref(var L : TLocation;LT:TCGRefLoc;LSize:TCgSize; Alignment: LongInt; Volatility: TVolatilitySet);
    { for loc_jump }
    procedure Location_Reset_Jump(out L: TLocation; TrueLab, FalseLab: TAsmLabel);
    procedure Location_Copy(var DestLoc:TLocation; const SourceLoc : TLocation);
    procedure Location_Swap(var DestLoc,SourceLoc : TLocation);
    function Location_Reg2String(const LocReg: TLocation): string;

    { returns r with the given alignment }
    function SetAlignment(const R : TReference;B : Byte) : TReference;

    { Helper function which calculate "magic" values for replacement of division
      by constant operation by multiplication. See the "PowerPC compiler developer
      manual" for more information.
      N is number of bits to handle, functionality tested for values 32 and 64. }
    procedure Calc_DivConst_Magic_Signed(N: Byte; D: AInt; out MagicM: AInt; out MagicS: Byte);
    procedure Calc_DivConst_Magic_Unsigned(N: Byte; D: AWord; out MagicM: AWord; out MagicAdd: Boolean; out MagicShift: Byte);

    { Functions for calculating the multiplicative inverse, or reciprocal, of
      a divisor mod 2^N.  That is, a number r such that dr = 1 (mod 2^N).

      WARNING: d must not be a power of 2 (including 2^0 = 1) }
    procedure Calc_Mul_Inverse(N: Byte; D: AWord; out Reciprocal: AWord; out Shift: Byte);

    { returns true if the CPU architecture we are currently compiling for needs
      software checks for fpu exceptions }
    function Needs_Check_For_FPU_Exceptions : Boolean;

implementation

uses
  Systems,
  Verbose,
  Globals,
  CPUInfo,
  CGObj;

{****************************************************************************
                                  TReference
****************************************************************************}

    procedure Reference_Reset(var Ref: TReference; Alignment: LongInt; Volatility: TVolatilitySet);
      begin
        FillChar(Ref,SizeOf(TReference),0);
        Ref.Alignment:=Alignment;
        Ref.Volatility:=Volatility;
        Ref.TempPos:=CTempPosInvalid;
      end;


    procedure Reference_Reset_Base(var Ref: TReference; Base: TRegister; Offset: ASizeInt; TempPos: TRefTempPos ; Alignment: LongInt; Volatility: TVolatilitySet);
      begin
        Reference_Reset(Ref,Alignment,Volatility);
        Ref.Base:=Base;
        Ref.Offset:=Offset;
        Ref.TempPos:=TempPos;
      end;


    procedure Reference_Reset_Symbol(var Ref: TReference; Sym: TAsmSymbol; Offset: ASizeInt; Alignment: LongInt; Volatility: TVolatilitySet);
      begin
        Reference_Reset(Ref,Alignment,Volatility);
        Ref.Symbol:=Sym;
        Ref.Offset:=Offset;
        Ref.TempPos:=CTempPosInvalid;
      end;


    function References_Equal(const SRef,DRef : TReference):Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      begin
        References_Equal:=CompareByte(SRef,DRef,SizeOf(TReference))=0;
      end;


    { returns r with the given alignment }
    function SetAlignment(const R : TReference;B : Byte) : TReference;
      begin
        Result:=R;
        Result.Alignment:=B;
      end;

{****************************************************************************
                                  TLocation
****************************************************************************}

    procedure Location_Reset(var L : TLocation;LT:TCGNonRefLoc;LSize:TCgSize);
      begin
        FillChar(L,SizeOf(TLocation),0);
        L.Loc:=LT;
        L.Size:=LSize;
        if L.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_JUMP] then
          { call location_reset_ref/jump instead }
          InternalError(2009020705);
      end;

  procedure Location_Reset_Ref(var L: TLocation; LT: TCGRefLoc; LSize: TCgSize; Alignment: LongInt; Volatility: TVolatilitySet);
    begin
      FillChar(L,SizeOf(TLocation),0);
      L.Loc:=LT;
      L.Size:=LSize;
      L.Reference.Alignment:=Alignment;
      L.Reference.Volatility:=Volatility;
      L.Reference.TempPos:=CTempPosInvalid;
    end;


    procedure Location_Reset_Jump(out L: TLocation; TrueLab, FalseLab: TAsmLabel);
      begin
        FillChar(L,SizeOf(TLocation),0);
        L.Loc:=LOC_JUMP;
        L.Size:=OS_NO;
        L.TrueLabel:=TrueLab;
        L.FalseLabel:=FalseLab;
      end;


    procedure Location_Copy(var DestLoc:TLocation; const SourceLoc : TLocation);
      begin
        DestLoc:=SourceLoc;
      end;


    procedure Location_Swap(var DestLoc,SourceLoc : TLocation);
      var
        SwapL : TLocation;
      begin
        SwapL := DestLoc;
        DestLoc := SourceLoc;
        SourceLoc := SwapL;
      end;


    function Location_Reg2String(const LocReg: TLocation): string;
      begin
        if not (LocReg.Loc in [LOC_REGISTER,LOC_CREGISTER,
            LOC_MMXREGISTER,LOC_CMMXREGISTER,
            LOC_MMREGISTER,LOC_CMMREGISTER,
            LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
          InternalError(2013122301);

        if LocReg.Loc in [LOC_REGISTER,LOC_CREGISTER] then
          begin
            case LocReg.Size of
{$if defined(cpu64bitalu)}
              OS_128,OS_S128:
                Result:=std_regname(LocReg.RegisterHi)+':'+std_regname(LocReg.Register);
{$elseif defined(cpu32bitalu)}
              OS_64,OS_S64:
                Result:=std_regname(LocReg.RegisterHi)+':'+std_regname(LocReg.Register);
{$endif}
              else
                Result:=std_regname(LocReg.Register);
            end;
          end
        else
          begin
            if LocReg.RegisterHi<>NR_NO then
              Result:=std_regname(LocReg.RegisterHi)+':'+std_regname(LocReg.Register)
            else
              Result:=std_regname(LocReg.Register);
          end;
      end;


{$push}
{$r-,q-}
    procedure Calc_DivConst_Magic_Signed(N: Byte; D: AInt; out MagicM: AInt; out MagicS: Byte);
      var
        P, SignCorrectiveShift: AInt;
        AD,ANC,Delta,Q1,R1,Q2,R2,T: AWord;
        TwoNMinus1: AWord;
      begin
        if (D>=-1) and (D<=1) then
          { Division by unity, -1 or 0 should have been caught earlier }
          InternalError(2022081801);

        TwoNMinus1:=AWord(1) shl (N-1);

        AD:=Abs(D);
        T:=TwoNMinus1+(AWord(D) shr (N-1));
        ANC:=T-1-T mod AD;               { absolute value of nc }
        P:=(N-1);                        { initialize p }
        Q1:=TwoNMinus1 div ANC;       { initialize q1 = 2**p/abs(nc) }
        R1:=TwoNMinus1-Q1*ANC;        { initialize r1 = rem(2**p,abs(nc)) }
        Q2:=TwoNMinus1 div AD;        { initialize q2 = 2**p/abs(d) }
        R2:=TwoNMinus1-Q2*AD;         { initialize r2 = rem(2**p,abs(d)) }
        repeat
          Inc(P);
          Q1:=2*Q1;           { update q1 = 2**p/abs(nc) }
          R1:=2*R1;           { update r1 = rem(2**p/abs(nc)) }
          if (R1>=ANC) then   { must be unsigned comparison }
            begin
              Inc(Q1);
              Dec(R1,ANC);
            end;
          Q2:=2*Q2;           { update q2 = 2p/abs(d) }
          R2:=2*R2;           { update r2 = rem(2p/abs(d)) }
          if (R2>=AD) then    { must be unsigned comparison }
            begin
              Inc(Q2);
              Dec(R2,AD);
            end;
          Delta:=AD-R2;
        until not ((Q1<Delta) or ((Q1=Delta) and (R1=0)));

        MagicM:=Q2+1;

        { Sign-extend magic_m to the full size of aint - fixes #39834 }
        if N < (SizeOf(AInt) * 8) then
          begin
            SignCorrectiveShift := (SizeOf(AInt) * 8) - N;
            MagicM := SarInt64(MagicM shl SignCorrectiveShift, SignCorrectiveShift);
          end;

        if (D<0) then
          MagicM:=-MagicM;  { resulting magic number }
        MagicS:=P-N;         { resulting shift }
      end;


    procedure Calc_DivConst_Magic_Unsigned(N: Byte; D: AWord; out MagicM: AWord; out MagicAdd: Boolean; out MagicShift: Byte);
      var
        P: AInt;
        NC,Delta,Q1,R1,Q2,R2,TwoNMinus1 : AWord;
        Mask: AWord;
      begin
        TwoNMinus1:=AWord(1) shl (N-1);
        MagicAdd:=False;
{$push}
{$warnings off }
        Mask:=AWord(not 0) shr ((64-N) and (SizeOf(AWord)*8-1));
        NC:=(Mask-(-D) mod AInt(D));
{$pop}
        P:=N-1;                       { initialize p }
        Q1:=TwoNMinus1 div NC;     { initialize q1 = 2**p/nc }
        R1:=TwoNMinus1-Q1*NC;      { initialize r1 = rem(2**p,nc) }
        Q2:=(TwoNMinus1-1) div D;  { initialize q2 = (2**p-1)/d }
        R2:=(TwoNMinus1-1)-Q2*D;   { initialize r2 = rem((2**p-1),d) }
        repeat
          Inc(P);
          if (R1>=(NC-R1)) then
            begin
              Q1:=2*Q1+1;    { update q1 }
              R1:=2*R1-NC;   { update r1 }
            end
          else
            begin
              Q1:=2*Q1;      { update q1 }
              R1:=2*R1;      { update r1 }
            end;
          if ((R2+1)>=(D-R2)) then
            begin
              if (Q2>=(TwoNMinus1-1)) then
                MagicAdd:=True;
              Q2:=2*Q2+1;    { update q2 }
              R2:=2*R2+1-D;  { update r2 }
            end
          else
            begin
              if (Q2>=TwoNMinus1) then
                MagicAdd:=True;
              Q2:=2*Q2;      { update q2 }
              R2:=2*R2+1;    { update r2 }
            end;
          Delta:=D-1-R2;
        until not ((P<(2*N)) and ((Q1<Delta) or ((Q1=Delta) and (R1=0))));
        MagicM:=(Q2+1) and Mask;        { resulting magic number }
        MagicShift:=P-N;     { resulting shift }
      end;


    procedure Calc_Mul_Inverse(N: Byte; D: AWord; out Reciprocal: AWord; out Shift: Byte);
      var
        Mask, OldR, NewD, SwapR, SwapD, Q: AWord;
      begin
        { WARNING: d must not be a power of 2 (including 2^0 = 1) }
{$push}
{$warnings off }
        if N=(SizeOf(AWord) * 8) then
          NewD:=0
        else
          NewD:=AWord(1) shl N; { Used later }
        Mask:=NewD-1;
        OldR:=Mask;
{$pop}

        { Trim off powers of 2 so d is an odd number }
{$if defined(cpu64bitalu)}
        Shift:=BsfQWord(D);
{$elseif defined(cpu32bitalu)}
        Shift:=BsfDWord(D);
{$else}
{$error ALU not defined}
{$endif}
        if Shift = 255 then
          { This is a divide by zero that should have been caught earlier }
          InternalError(2021091001);

        D := D shr Shift;

        { Calculate reciprocal using the Extended Euclidean Algorithm as
          described on page 244 of Hacker's Delight, Second Edition.

          x1 = oldr
          x2 = reciprocal
          x3 = swap_r

          v1 = newd
          v2 = d
          v3 = swap_d
        }
        NewD:=NewD-D; { -d }
        Reciprocal:=1;

        repeat
          Q := NewD div D;

          SwapD:=(NewD-(Q*D)) and Mask;
          NewD:=D;
          D:=SwapD;

          SwapR:=(OldR-(Q*Reciprocal)) and Mask;
          OldR:=Reciprocal;
          Reciprocal:=SwapR;
        until D<=1;
      end;


    function Needs_Check_For_FPU_Exceptions: Boolean;
      begin
{$if defined(AARCH64)}
        Result:=cs_check_fpu_exceptions in CurrentSettings.LocalSwitches;
{$else}
        Result:=False;
{$endif}
      end;

{$pop}

end.

