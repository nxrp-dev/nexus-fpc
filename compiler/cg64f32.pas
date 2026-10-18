{
    Copyright (c) 1998-2002 by Florian Klaempfl
    Member of the Free Pascal development team

    This unit implements the code generation for 64 bit int
    arithmetics on 32 bit processors

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
{# This unit implements the code generation for 64 bit int arithmetics on
   32 bit processors.
}
unit cg64f32;

  {$i fpcdefs.inc}

  interface

    uses
       AAsmBase,AAsmTAI,AAsmData,AAsmCPU,
       CPUBase,CPUPara,
       CGBase,CGObj,ParaBase,CGUtils,
       SymType
       ;

    type
      {# Defines all the methods required on 32-bit processors
         to handle 64-bit integers.
      }
      TCG64F32 = class(TCG64)
        procedure A_Load64_Const_Ref(List : TAsmList;Value : Int64;const Ref : TReference);override;
        procedure A_Load64_Reg_Ref(List : TAsmList;Reg : TRegister64;const Ref : TReference);override;
        procedure A_Load64_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister64);override;
        procedure A_Load64_Reg_Reg(List : TAsmList;RegSrc,RegDst : TRegister64);override;
        procedure A_Load64_Const_Reg(List : TAsmList;Value: Int64;Reg : TRegister64);override;

        procedure A_Load64_SubsetRef_Reg(List : TAsmList; const SRef: TSubsetReference; DestReg: TRegister64);override;
        procedure A_Load64_Reg_SubsetRef(List : TAsmList; FromReg: TRegister64; const SRef: TSubsetReference);override;
        procedure A_Load64_Const_SubsetRef(List: TAsmList; A: Int64; const SRef: TSubsetReference);override;
        procedure A_Load64_Ref_SubsetRef(List : TAsmList; const FromRef: TReference; const SRef: TSubsetReference);override;
        procedure A_Load64_SubsetRef_SubsetRef(List: TAsmList; const FromSRef, ToSRef: TSubsetReference);override;
        procedure A_Load64_SubsetRef_Ref(List : TAsmList; const SRef: TSubsetReference; const DestRef: TReference);override;

        procedure A_Load64_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister64);override;
        procedure A_Load64_Loc_Ref(List : TAsmList;const L : TLocation;const Ref : TReference);override;
        procedure A_Load64_Const_Loc(List : TAsmList;Value : Int64;const L : TLocation);override;
        procedure A_Load64_Reg_Loc(List : TAsmList;Reg : TRegister64;const L : TLocation);override;


        procedure A_Load64High_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);override;
        procedure A_Load64Low_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);override;
        procedure A_Load64High_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);override;
        procedure A_Load64Low_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);override;
        procedure A_Load64High_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);override;
        procedure A_Load64Low_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);override;

        procedure A_Op64_Ref_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference;Reg : TRegister64);override;
        procedure A_Op64_Reg_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;Reg : TRegister64; const Ref: TReference);override;
        procedure A_Op64_Const_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const L: TLocation);override;
        procedure A_Op64_Reg_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Reg : TRegister64;const L : TLocation);override;
        procedure A_Op64_Ref_Loc(List: TAsmList; Op: TOpCG; Size: TCgSize;const Ref: TReference; const L: TLocation);override;
        procedure A_Op64_Loc_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const L : TLocation;Reg : TRegister64);override;
        procedure A_Op64_Const_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const Ref : TReference);override;

        procedure A_Load64_Reg_CGPara(List : TAsmList;Reg : TRegister64;const ParaLoc : TCGPara);override;
        procedure A_Load64_Const_CGPara(List : TAsmList;Value : Int64;const ParaLoc : TCGPara);override;
        procedure A_Load64_Ref_CGPara(List : TAsmList;const R : TReference;const ParaLoc : TCGPara);override;
        procedure A_Load64_Loc_CGPara(List : TAsmList;const L : TLocation;const ParaLoc : TCGPara);override;

        procedure A_LoadMM_IntReg64_Reg(List: TAsmList; MMSize: TCgSize; IntReg: TRegister64; MMReg: TRegister);override;
        procedure A_LoadMM_Reg_IntReg64(List: TAsmList; MMSize: TCgSize; MMReg: TRegister; IntReg: TRegister64);override;
        {# This routine tries to optimize the a_op64_const_reg operation, by
           removing superfluous opcodes. Returns TRUE if normal processing
           must continue in op64_const_reg, otherwise, everything is processed
           entirely in this routine, by emitting the appropriate 32-bit opcodes.
        }
        function Optimize64_Op_Const_Reg(List: TAsmList; var Op: TOpCG; var A : Int64; var Reg: TRegister64): Boolean;override;

        procedure G_RangeCheck64(List: TAsmList; const L:TLocation;FromDef,ToDef: TDef); override;
      end;


  implementation

    uses
       GlobType,Systems,ConstExp,
       Verbose,CUtils,
       SymBase,SymConst,SymDef,SymTable,DefUtil,ParaMgr,
       TGObj,HLCGObj;

{****************************************************************************
                                     Helpers
****************************************************************************}

    procedure Swap64(var Q : Int64);
      begin
         Q:=(Int64(Lo(Q)) shl 32) or Hi(Q);
      end;


    procedure SplitParaLoc64(const CGPara:TCGPara;var CGParaLo,CGParaHi:TCGPara);
      var
        ParaLocLo,ParaLocLo2,ParaLocLo3,ParaLocLo4,
        ParaLocHi,ParaLocHi2,ParaLocHi3,ParaLocHi4 : PCGParaLocation;
        CurParaLoc : PCGParaLocation;
      begin
        if not(CGPara.Size in [OS_64,OS_S64]) then
          InternalError(200408231);
        if not Assigned(CGPara.Location) then
          InternalError(200408201);
        { init lo/hi para }
        CGParaHi.Reset;
        if CGPara.Size=OS_S64 then
          CGParaHi.Size:=OS_S32
        else
          CGParaHi.Size:=OS_32;
        CGParaHi.IntSize:=4;
        CGParaHi.Alignment:=CGPara.Alignment;
        ParaLocHi:=CGParaHi.Add_Location;
        CGParaLo.Reset;
        CGParaLo.Size:=OS_32;
        CGParaLo.IntSize:=4;
        CGParaLo.Alignment:=CGPara.Alignment;
        ParaLocLo:=CGParaLo.Add_Location;
        case CGPara.Locations_Count of
          8:
            begin
              { 8 parameter fields? }
              { Order for multiple locations is always
                  paraloc^ -> high
                  paraloc^.next -> low }
              if (TargetInfo.Endian=ENDIAN_BIG) then
                begin
                  { is there any big endian 8 bit ALU/16 bit Addr CPU? }
                  InternalError(2015041001);
                  { paraloc^ -> high }
                  Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
                  ParaLocHi^.Next:=nil;
                  ParaLocHi2:=CGParaHi.Add_Location;
                  Move(CGPara.Location^.Next,ParaLocHi2^,SizeOf(ParaLocHi2^));

                  { paraloc^.next^.next^ -> low }
                  Move(CGPara.Location^.Next^.Next^,ParaLocLo^,SizeOf(ParaLocLo^));
                  ParaLocLo^.Next:=nil;
                  ParaLocLo2:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^.Next^.Next^,ParaLocLo2^,SizeOf(ParaLocLo2^));
                end
              else
                begin
                  { paraloc^ -> low }
                  Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
                  ParaLocLo^.Next:=nil;
                  ParaLocLo2:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^,ParaLocLo2^,SizeOf(ParaLocLo2^));
                  ParaLocLo2^.Next:=nil;
                  ParaLocLo3:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^.Next^,ParaLocLo3^,SizeOf(ParaLocLo3^));
                  ParaLocLo3^.Next:=nil;
                  ParaLocLo4:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^.Next^.Next^,ParaLocLo4^,SizeOf(ParaLocLo4^));

                  { paraloc^.next^.next^.next^.next^ -> high }
                  CurParaLoc:=CGPara.Location^.Next^.Next^.Next^.Next;
                  Move(CurParaLoc^,ParaLocHi^,SizeOf(ParaLocHi^));
                  ParaLocHi^.Next:=nil;
                  ParaLocHi2:=CGParaHi.Add_Location;
                  Move(CurParaLoc^.Next^,ParaLocHi2^,SizeOf(ParaLocHi2^));
                  ParaLocHi2^.Next:=nil;
                  ParaLocHi3:=CGParaHi.Add_Location;
                  Move(CurParaLoc^.Next^.Next^,ParaLocHi3^,SizeOf(ParaLocHi3^));
                  ParaLocHi3^.Next:=nil;
                  ParaLocHi4:=CGParaHi.Add_Location;
                  Move(CurParaLoc^.Next^.Next^.Next^,ParaLocHi4^,SizeOf(ParaLocHi4^));
                end;

              { fix size }
              ParaLocLo^.Size:=OS_8;
              ParaLocLo2^.Size:=OS_8;
              ParaLocLo3^.Size:=OS_8;
              ParaLocLo4^.Size:=OS_8;
              ParaLocLo4^.Next:=nil;
              ParaLocHi^.Size:=OS_8;
              ParaLocHi2^.Size:=OS_8;
              ParaLocHi3^.Size:=OS_8;
              ParaLocHi4^.Size:=OS_8;
              ParaLocHi4^.Next:=nil;
              if CGPara.Size=OS_S64 then
                if TargetInfo.Endian=ENDIAN_BIG then
                  ParaLocHi^.Size:=OS_S8
                else
                  ParaLocLo4^.Size:=OS_S8;
            end;
          4:
            begin
              { 4 parameter fields? }
              { Order for multiple locations is always
                  paraloc^ -> high
                  paraloc^.next -> low }
              if (TargetInfo.Endian=ENDIAN_BIG) then
                begin
                  { paraloc^ -> high }
                  Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
                  ParaLocHi^.Next:=nil;
                  ParaLocHi2:=CGParaHi.Add_Location;
                  Move(CGPara.Location^.Next,ParaLocHi2^,SizeOf(ParaLocHi2^));

                  { paraloc^.next^.next^ -> low }
                  Move(CGPara.Location^.Next^.Next^,ParaLocLo^,SizeOf(ParaLocLo^));
                  ParaLocLo^.Next:=nil;
                  ParaLocLo2:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^.Next^.Next^,ParaLocLo2^,SizeOf(ParaLocLo2^));
                end
              else
                begin
                  { paraloc^ -> low }
                  Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
                  ParaLocLo^.Next:=nil;
                  ParaLocLo2:=CGParaLo.Add_Location;
                  Move(CGPara.Location^.Next^,ParaLocLo2^,SizeOf(ParaLocLo2^));

                  { paraloc^.next^.next -> high }
                  Move(CGPara.Location^.Next^.Next^,ParaLocHi^,SizeOf(ParaLocHi^));
                  ParaLocHi^.Next:=nil;
                  ParaLocHi2:=CGParaHi.Add_Location;
                  Move(CGPara.Location^.Next^.Next^.Next^,ParaLocHi2^,SizeOf(ParaLocHi2^));
                end;

              { fix size }
              ParaLocLo^.Size:=OS_16;
              ParaLocLo2^.Size:=OS_16;
              ParaLocLo2^.Next:=nil;
              ParaLocHi^.Size:=OS_16;
              ParaLocHi2^.Size:=OS_16;
              ParaLocHi2^.Next:=nil;
              if CGPara.Size=OS_S64 then
                if TargetInfo.Endian=ENDIAN_BIG then
                  ParaLocHi^.Size:=OS_S16
                else
                  ParaLocLo2^.Size:=OS_S16;
            end;
          2:
            begin
              { 2 parameter fields? }
              { Order for multiple locations is always
                  paraloc^ -> high
                  paraloc^.next -> low }
              if (TargetInfo.Endian=ENDIAN_BIG) then
                begin
                  { paraloc^ -> high
                    paraloc^.next -> low }
                  Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
                  Move(CGPara.Location^.Next^,ParaLocLo^,SizeOf(ParaLocLo^));
                end
              else
                begin
                  { paraloc^ -> low
                    paraloc^.next -> high }
                  Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
                  Move(CGPara.Location^.Next^,ParaLocHi^,SizeOf(ParaLocHi^));
                end;

              { fix size }
              ParaLocLo^.Size:=CGParaLo.Size;
              ParaLocLo^.Next:=nil;
              ParaLocHi^.Size:=CGParaHi.Size;
              ParaLocHi^.Next:=nil;
            end;
          1:
            begin
              { single parameter, this can only be in memory }
              if CGPara.Location^.Loc<>LOC_REFERENCE then
                InternalError(200408282);
              Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
              Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
              { for big endian low is at +4, for little endian high }
              if TargetInfo.Endian = endian_big then
                begin
                  Inc(CGParaLo.Location^.Reference.Offset,4);
                  CGParaLo.Alignment:=NewAlignment(CGParaLo.Alignment,4);
                end
              else
                begin
                  Inc(CGParaHi.Location^.Reference.Offset,4);
                  CGParaHi.Alignment:=NewAlignment(CGParaHi.Alignment,4);
                end;

              { fix size }
              ParaLocLo^.Size:=CGParaLo.Size;
              ParaLocLo^.Next:=nil;
              ParaLocHi^.Size:=CGParaHi.Size;
              ParaLocHi^.Next:=nil;
            end;
          else
            InternalError(2013051901);
        end;
      end;


{****************************************************************************
                                   TCG64F32
****************************************************************************}

    procedure TCG64F32.A_Load64_Reg_Ref(List : TAsmList;Reg : TRegister64;const Ref : TReference);
      var
        TmpReg: TRegister;
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          begin
            TmpReg:=Reg.RegLo;
            Reg.RegLo:=Reg.RegHi;
            Reg.RegHi:=TmpReg;
          end;
        TmpRef := Ref;

        CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg.RegLo,TmpRef);
        Inc(TmpRef.Offset,4);
        CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg.RegHi,TmpRef);
      end;


    procedure TCG64F32.A_Load64_Const_Ref(List : TAsmList;Value : Int64;const Ref : TReference);
      var
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          Swap64(Value);
        CG.A_Load_Const_Ref(List,OS_32,LongInt(Lo(Value)),Ref);
        TmpRef := Ref;
        Inc(TmpRef.Offset,4);
        CG.A_Load_Const_Ref(List,OS_32,LongInt(Hi(Value)),TmpRef);
      end;


    procedure TCG64F32.A_Load64_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister64);
      var
        TmpReg: TRegister;
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          begin
            TmpReg := Reg.RegLo;
            Reg.RegLo := Reg.RegHi;
            Reg.RegHi := TmpReg;
          end;
        TmpRef := Ref;

        if (TmpRef.Base=Reg.RegLo) then
         begin
           TmpReg:=CG.GetAddressRegister(List);
           CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpRef.Base,TmpReg);
           TmpRef.Base:=TmpReg;
         end
        else
         { this works only for the i386, thus the i386 needs to override  }
         { this method and this method must be replaced by a more generic }
         { implementation FK                                              }
         if (TmpRef.Index=Reg.RegLo) then
          begin
            TmpReg:=CG.GetAddressRegister(List);
            CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpRef.Index,TmpReg);
            TmpRef.Index:=TmpReg;
          end;
        CG.A_Load_Ref_Reg(List,OS_32,OS_32,TmpRef,Reg.RegLo);
        Inc(TmpRef.Offset,4);
        CG.A_Load_Ref_Reg(List,OS_32,OS_32,TmpRef,Reg.RegHi);
      end;


    procedure TCG64F32.A_Load64_Reg_Reg(List : TAsmList;RegSrc,RegDst : TRegister64);

      begin
        CG.A_Load_Reg_Reg(List,OS_32,OS_32,RegSrc.RegLo,RegDst.RegLo);
        CG.A_Load_Reg_Reg(List,OS_32,OS_32,RegSrc.RegHi,RegDst.RegHi);
      end;


    procedure TCG64F32.A_Load64_Const_Reg(List : TAsmList;Value : Int64;Reg : TRegister64);

      begin
        CG.A_Load_Const_Reg(List,OS_32,LongInt(Lo(Value)),Reg.RegLo);
        CG.A_Load_Const_Reg(List,OS_32,LongInt(Hi(Value)),Reg.RegHi);
      end;


    procedure TCG64F32.A_Load64_SubsetRef_Reg(List : TAsmList; const SRef: TSubsetReference; DestReg: TRegister64);

      var
        TmpReg: TRegister;
        TmpSRef: TSubsetReference;
      begin
        if (SRef.BitIndexReg <> NR_NO) or
           (SRef.BitLen <> 64) then
          InternalError(2006082310);
        if (SRef.StartBit = 0) then
          begin
            A_Load64_Ref_Reg(List,SRef.Ref,DestReg);
            Exit;
          end;

        if TargetInfo.Endian = endian_big then
          begin
            TmpReg := DestReg.RegLo;
            DestReg.RegLo := DestReg.RegHi;
            DestReg.RegHi := TmpReg;
          end;
        TmpSRef:=SRef;
        if (TmpSRef.Ref.Base=DestReg.RegLo) then
         begin
           TmpReg:=CG.GetAddressRegister(List);
           CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpSRef.Ref.Base,TmpReg);
           TmpSRef.Ref.Base:=TmpReg;
         end
        else
         if (TmpSRef.Ref.Index=DestReg.RegLo) then
          begin
            TmpReg:=CG.GetAddressRegister(List);
            CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpSRef.Ref.Index,TmpReg);
            TmpSRef.Ref.Index:=TmpReg;
          end;
        TmpSRef.BitLen:=32;
        HLCG.A_Load_SubsetRef_Reg(List,U32IntType,U32IntType,TmpSRef,DestReg.RegLo);
        Inc(TmpSRef.Ref.Offset,4);
        HLCG.A_Load_SubsetRef_Reg(List,U32IntType,U32IntType,TmpSRef,DestReg.RegHi);
      end;


    procedure TCG64F32.A_Load64_Reg_SubsetRef(List : TAsmList; FromReg: TRegister64; const SRef: TSubsetReference);

      var
        TmpReg: TRegister;
        TmpSRef: TSubsetReference;
      begin
        if (SRef.BitIndexReg <> NR_NO) or
           (SRef.BitLen <> 64) then
          InternalError(2006082311);
        if (SRef.StartBit = 0) then
          begin
            A_Load64_Reg_Ref(List,FromReg,SRef.Ref);
            Exit;
          end;

        if TargetInfo.Endian = endian_big then
          begin
            TmpReg:=FromReg.RegLo;
            FromReg.RegLo:=FromReg.RegHi;
            FromReg.RegHi:=TmpReg;
          end;
        TmpSRef:=SRef;
        TmpSRef.BitLen:=32;
        HLCG.A_Load_Reg_SubsetRef(List,U32IntType,U32IntType,FromReg.RegLo,TmpSRef);
        Inc(TmpSRef.Ref.Offset,4);
        HLCG.A_Load_Reg_SubsetRef(List,U32IntType,U32IntType,FromReg.RegHi,TmpSRef);
      end;


    procedure TCG64F32.A_Load64_Const_SubsetRef(List: TAsmList; A: Int64; const SRef: TSubsetReference);

      var
        TmpSRef: TSubsetReference;
      begin
        if (SRef.BitIndexReg <> NR_NO) or
           (SRef.BitLen <> 64) then
          InternalError(2006082312);
        if TargetInfo.Endian = endian_big then
          Swap64(A);
        TmpSRef := SRef;
        TmpSRef.BitLen := 32;
        HLCG.A_Load_Const_SubsetRef(List,U32IntType,LongInt(Lo(A)),TmpSRef);
        Inc(TmpSRef.Ref.Offset,4);
        HLCG.A_Load_Const_SubsetRef(List,U32IntType,LongInt(Hi(A)),TmpSRef);
      end;


    procedure TCG64F32.A_Load64_SubsetRef_SubsetRef(List: TAsmList; const FromSRef, ToSRef: TSubsetReference);

      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,FromSRef,TmpReg64);
        A_Load64_Reg_SubsetRef(List,TmpReg64,ToSRef);
      end;


    procedure TCG64F32.A_Load64_SubsetRef_Ref(List : TAsmList; const SRef: TSubsetReference; const DestRef: TReference);

      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,SRef,TmpReg64);
        A_Load64_Reg_Ref(List,TmpReg64,DestRef);
      end;


    procedure TCG64F32.A_Load64_Ref_SubsetRef(List : TAsmList; const FromRef: TReference; const SRef: TSubsetReference);

      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_Ref_Reg(List,FromRef,TmpReg64);
        A_Load64_Reg_SubsetRef(List,TmpReg64,SRef);
      end;


    procedure TCG64F32.A_Load64_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister64);

      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load64_Ref_Reg(List,L.Reference,Reg);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_Reg_Reg(List,L.Register64,Reg);
          LOC_CONSTANT :
            A_Load64_Const_Reg(List,L.Value64,Reg);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            A_Load64_SubsetRef_Reg(List,L.SRef,Reg);
          else
            InternalError(200112292);
        end;
      end;


    procedure TCG64F32.A_Load64_Loc_Ref(List : TAsmList;const L : TLocation;const Ref : TReference);
      begin
        case L.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_Reg_Ref(List,L.Register64,Ref);
          LOC_CONSTANT :
            A_Load64_Const_Ref(List,L.Value64,Ref);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            A_Load64_SubsetRef_Ref(List,L.SRef,Ref);
          else
            InternalError(200203288);
        end;
      end;


    procedure TCG64F32.A_Load64_Const_Loc(List : TAsmList;Value : Int64;const L : TLocation);

      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load64_Const_Ref(List,Value,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_Const_Reg(List,Value,L.Register64);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            A_Load64_Const_SubsetRef(List,Value,L.SRef);
          else
            InternalError(200112293);
        end;
      end;


    procedure TCG64F32.A_Load64_Reg_Loc(List : TAsmList;Reg : TRegister64;const L : TLocation);

      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load64_Reg_Ref(List,Reg,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_Reg_Reg(List,Reg,L.Register64);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            A_Load64_Reg_SubsetRef(List,Reg,L.SRef);
          LOC_MMREGISTER, LOC_CMMREGISTER:
            A_LoadMM_IntReg64_Reg(List,L.Size,Reg,L.Register);
          else
            InternalError(200112294);
        end;
      end;


    procedure TCG64F32.A_Load64High_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);
      var
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg,Ref)
        else
          begin
            TmpRef := Ref;
            Inc(TmpRef.Offset,4);
            CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg,TmpRef)
          end;
      end;

    procedure TCG64F32.A_Load64Low_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);
      var
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_little then
          CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg,Ref)
        else
          begin
            TmpRef := Ref;
            Inc(TmpRef.Offset,4);
            CG.A_Load_Reg_Ref(List,OS_32,OS_32,Reg,TmpRef)
          end;
      end;


    procedure TCG64F32.A_Load64High_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);
      var
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          CG.A_Load_Ref_Reg(List,OS_32,OS_32,Ref,Reg)
        else
          begin
            TmpRef := Ref;
            Inc(TmpRef.Offset,4);
            CG.A_Load_Ref_Reg(List,OS_32,OS_32,TmpRef,Reg)
          end;
      end;


    procedure TCG64F32.A_Load64Low_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);
      var
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_little then
          CG.A_Load_Ref_Reg(List,OS_32,OS_32,Ref,Reg)
        else
          begin
            TmpRef := Ref;
            Inc(TmpRef.Offset,4);
            CG.A_Load_Ref_Reg(List,OS_32,OS_32,TmpRef,Reg)
          end;
      end;


    procedure TCG64F32.A_Load64Low_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);
      begin
        case L.Loc of
          LOC_REFERENCE,
          LOC_CREFERENCE :
            A_Load64Low_Ref_Reg(List,L.Reference,Reg);
          LOC_REGISTER,
          LOC_CREGISTER :
            CG.A_Load_Reg_Reg(List,OS_32,OS_32,L.Register64.RegLo,Reg);
          LOC_CONSTANT :
            CG.A_Load_Const_Reg(List,OS_32,LongInt(Lo(L.Value64)),Reg);
          else
            InternalError(200203244);
        end;
      end;


    procedure TCG64F32.A_Load64High_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);
      begin
        case L.Loc of
          LOC_REFERENCE,
          LOC_CREFERENCE :
            A_Load64High_Ref_Reg(List,L.Reference,Reg);
          LOC_REGISTER,
          LOC_CREGISTER :
            CG.A_Load_Reg_Reg(List,OS_32,OS_32,L.Register64.RegHi,Reg);
          LOC_CONSTANT :
            CG.A_Load_Const_Reg(List,OS_32,LongInt(Hi(L.Value64)),Reg);
          else
            InternalError(2002032411);
        end;
      end;


    procedure TCG64F32.A_Op64_Const_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const L: TLocation);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op64_Const_Ref(List,Op,Size,Value,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Op64_Const_Reg(List,Op,Size,Value,L.Register64);
          else
            InternalError(200203292);
        end;
      end;


    procedure TCG64F32.A_Op64_Reg_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Reg : TRegister64;const L : TLocation);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op64_Reg_Ref(List,Op,Size,Reg,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Op64_Reg_Reg(List,Op,Size,Reg,L.Register64);
          else
            InternalError(2002032422);
        end;
      end;


    procedure TCG64F32.A_Op64_Ref_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference;const L : TLocation);
      var
        TempReg: TRegister64;
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            begin
              TempReg.RegHi:=CG.GetIntRegister(List,OS_32);
              TempReg.RegLo:=CG.GetIntRegister(List,OS_32);
              A_Load64_Ref_Reg(List,Ref,TempReg);
              A_Op64_Reg_Ref(List,Op,Size,TempReg,L.Reference);
            end;
          LOC_REGISTER,LOC_CREGISTER:
            A_Op64_Ref_Reg(List,Op,Size,Ref,L.Register64);
          else
            InternalError(2020042803);
        end;
      end;


    procedure TCG64F32.A_Op64_Loc_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const L : TLocation;Reg : TRegister64);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op64_Ref_Reg(List,Op,Size,L.Reference,Reg);
          LOC_REGISTER,LOC_CREGISTER:
            A_Op64_Reg_Reg(List,Op,Size,L.Register64,Reg);
          LOC_CONSTANT :
            A_Op64_Const_Reg(List,Op,Size,L.Value64,Reg);
          else
            InternalError(200203242);
        end;
      end;


    procedure TCG64F32.A_Op64_Ref_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference;Reg : TRegister64);
      var
        TempReg: TRegister64;
      begin
        TempReg.RegHi:=CG.GetIntRegister(List,OS_32);
        TempReg.RegLo:=CG.GetIntRegister(List,OS_32);
        A_Load64_Ref_Reg(List,Ref,TempReg);
        A_Op64_Reg_Reg(List,Op,Size,TempReg,Reg);
      end;


    procedure TCG64F32.A_Op64_Reg_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;Reg : TRegister64; const Ref: TReference);
      var
        TempReg: TRegister64;
      begin
        TempReg.RegHi:=CG.GetIntRegister(List,OS_32);
        TempReg.RegLo:=CG.GetIntRegister(List,OS_32);
        if Op in [OP_NEG,OP_NOT] then
          begin
            A_Op64_Reg_Reg(List,Op,Size,Reg,TempReg);
            A_Load64_Reg_Ref(List,TempReg,Ref);
          end
        else
          begin
            A_Load64_Ref_Reg(List,Ref,TempReg);
            A_Op64_Reg_Reg(List,Op,Size,Reg,TempReg);
            A_Load64_Reg_Ref(List,TempReg,Ref);
          end;
      end;


    procedure TCG64F32.A_Op64_Const_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const Ref : TReference);
      var
        TempReg: TRegister64;
      begin
        TempReg.RegHi:=CG.GetIntRegister(List,OS_32);
        TempReg.RegLo:=CG.GetIntRegister(List,OS_32);
        A_Load64_Ref_Reg(List,Ref,TempReg);
        A_Op64_Const_Reg(List,Op,Size,Value,TempReg);
        A_Load64_Reg_Ref(List,TempReg,Ref);
      end;


    procedure TCG64F32.A_Load64_Reg_CGPara(List : TAsmList;Reg : TRegister64;const ParaLoc : TCGPara);
      var
        TmpLocHi,TmpLocLo: TCGPara;
      begin
        TmpLocLo.Init;
        TmpLocHi.Init;
        SplitParaLoc64(ParaLoc,TmpLocLo,TmpLocHi);
        if TargetInfo.Endian=endian_big then
          begin
            { Keep this order of first lo before hi to have
              the correct push order for m68k }
            CG.A_Load_Reg_CGPara(List,OS_32,Reg.RegLo,TmpLocLo);
            CG.A_Load_Reg_CGPara(List,OS_32,Reg.RegHi,TmpLocHi);
          end
        else
          begin
            { Keep this order of first hi before lo to have
              the correct push order for i386 }
            CG.A_Load_Reg_CGPara(List,OS_32,Reg.RegHi,TmpLocHi);
            CG.A_Load_Reg_CGPara(List,OS_32,Reg.RegLo,TmpLocLo);
          end;
        TmpLocLo.Done;
        TmpLocHi.Done;
      end;


    procedure TCG64F32.A_Load64_Const_CGPara(List : TAsmList;Value : Int64;const ParaLoc : TCGPara);
      var
        TmpLocHi,TmpLocLo: TCGPara;
      begin
        TmpLocLo.Init;
        TmpLocHi.Init;
        SplitParaLoc64(ParaLoc,TmpLocLo,TmpLocHi);
        if TargetInfo.Endian=endian_big then
          begin
            { Keep this order of first lo before hi to have
              the correct push order for m68k }
            CG.A_Load_Const_CGPara(List,OS_32,LongInt(Lo(Value)),TmpLocLo);
            CG.A_Load_Const_CGPara(List,OS_32,LongInt(Hi(Value)),TmpLocHi);
          end
        else
          begin
            { Keep this order of first hi before lo to have
              the correct push order for i386 }
            CG.A_Load_Const_CGPara(List,OS_32,LongInt(Hi(Value)),TmpLocHi);
            CG.A_Load_Const_CGPara(List,OS_32,LongInt(Lo(Value)),TmpLocLo);
          end;
        TmpLocLo.Done;
        TmpLocHi.Done;
      end;


    procedure TCG64F32.A_Load64_Ref_CGPara(List : TAsmList;const R : TReference;const ParaLoc : TCGPara);
      var
        TmpRefHi,TmpRefLo : TReference;
        TmpLocLo,TmpLocHi : TCGPara;
      begin
        TmpLocLo.Init;
        TmpLocHi.Init;
        SplitParaLoc64(ParaLoc,TmpLocLo,TmpLocHi);
        TmpRefHi:=R;
        TmpRefLo:=R;
        if TargetInfo.Endian=endian_big then
          begin
            { Keep this order of first lo before hi to have
              the correct push order for m68k }
            Inc(TmpRefLo.Offset,4);
            CG.A_Load_Ref_CGPara(List,OS_32,TmpRefLo,TmpLocLo);
            CG.A_Load_Ref_CGPara(List,OS_32,TmpRefHi,TmpLocHi);
          end
        else
          begin
            { Keep this order of first hi before lo to have
              the correct push order for i386 }
            Inc(TmpRefHi.Offset,4);
            CG.A_Load_Ref_CGPara(List,OS_32,TmpRefHi,TmpLocHi);
            CG.A_Load_Ref_CGPara(List,OS_32,TmpRefLo,TmpLocLo);
          end;
        TmpLocLo.Done;
        TmpLocHi.Done;
      end;


    procedure TCG64F32.A_Load64_Loc_CGPara(List : TAsmList;const L:TLocation;const ParaLoc : TCGPara);
      begin
        case L.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            A_Load64_Reg_CGPara(List,L.Register64,ParaLoc);
          LOC_CONSTANT :
            A_Load64_Const_CGPara(List,L.Value64,ParaLoc);
          LOC_CREFERENCE,
          LOC_REFERENCE :
            A_Load64_Ref_CGPara(List,L.Reference,ParaLoc);
          else
            InternalError(200203287);
        end;
      end;


    procedure TCG64F32.A_LoadMM_IntReg64_Reg(List: TAsmList; MMSize: TCgSize; IntReg: TRegister64; MMReg: TRegister);
      var
        TmpRef: TReference;
      begin
        if (TCgSize2Size[MMSize]<>8) then
          InternalError(2009112501);
        TG.GetTemp(List,8,8,tt_normal,TmpRef);
        A_Load64_Reg_Ref(List,IntReg,TmpRef);
        CG.A_LoadMM_Ref_Reg(List,MMSize,MMSize,TmpRef,MMReg,MMS_MoveScalar);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG64F32.A_LoadMM_Reg_IntReg64(List: TAsmList; MMSize: TCgSize; MMReg: TRegister; IntReg: TRegister64);
      var
        TmpRef: TReference;
      begin
        if (TCgSize2Size[MMSize]<>8) then
          InternalError(2009112502);
        TG.GetTemp(List,8,8,tt_normal,TmpRef);
        CG.A_LoadMM_Reg_Ref(List,MMSize,MMSize,MMReg,TmpRef,MMS_MoveScalar);
        A_Load64_Ref_Reg(List,TmpRef,IntReg);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG64F32.G_RangeCheck64(List : TAsmList;const L:TLocation;FromDef,ToDef:TDef);

      var
        NegLabel,
        PosLabel,
        EndLabel: TAsmLabel;
        HReg   : TRegister;
        HDef   :  TOrdDef;
        OpSize   : TCgSize;
        FromSigned,ToSigned: Boolean;
        TempLoc : TLocation;

      begin
         FromSigned := Is_Signed(FromDef);
         ToSigned := Is_Signed(ToDef);

         if not Is_64Bit(ToDef) then
           begin
             { get the high dword in a register }
             if L.Loc in [LOC_REGISTER,LOC_CREGISTER] then
               begin
                 HReg := L.Register64.RegHi;
               end
             else
               begin
                 HReg:=CG.GetIntRegister(List,OS_32);
                 A_Load64High_Ref_Reg(List,L.Reference,HReg);
               end;
             CurrentAsmData.GetJumpLabel(PosLabel);

             CG.A_Reg_Alloc(List, NR_DEFAULTFLAGS);

             { check high dword, must be 0 (for positive numbers) }
             CG.A_Cmp_Const_Reg_Label(List,OS_32,OC_EQ,0,HReg,PosLabel);

             { It can also be $ffffffff, but only for negative numbers }
             if FromSigned and ToSigned then
               begin
                 CurrentAsmData.GetJumpLabel(NegLabel);
                 CG.A_Cmp_Const_Reg_Label(List,OS_32,OC_EQ,-1,HReg,NegLabel);
               end
             else
               { we do not have dynamic dfa, so avoid a warning below about the unused
                 neglabel }
               NegLabel:=nil;

             CG.A_Reg_Dealloc(List, NR_DEFAULTFLAGS);

             { For all other values we have a range check error }
             CG.A_Call_Name(List,'fpc_rangeerror',False);

             { if the high dword = 0, the low dword can be considered a }
             { simple cardinal                                          }
             CG.A_Label(List,PosLabel);
             HDef:=COrdDef.Create(U32Bit,0,$ffffffff,False);

             Location_Copy(TempLoc,L);
             TempLoc.Size:=OS_32;

             if (TempLoc.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) and
                (TargetInfo.Endian = endian_big) then
               begin
                 Inc(TempLoc.Reference.Offset,4);
                 TempLoc.Reference.Alignment:=NewAlignment(TempLoc.Reference.Alignment,4);
               end;

             HLCG.G_RangeCheck(List,TempLoc,HDef,ToDef);
             HDef.Free;
             HDef := nil;

             if FromSigned and ToSigned then
               begin
                 CurrentAsmData.GetJumpLabel(EndLabel);
                 CG.A_Jmp_Always(List,EndLabel);
                 { if the high dword = $ffffffff, then the low dword (when }
                 { considered as a longint) must be < 0                    }
                 CG.A_Label(List,NegLabel);
                 if L.Loc in [LOC_REGISTER,LOC_CREGISTER] then
                   begin
                     HReg := L.Register64.RegLo;
                   end
                 else
                   begin
                     HReg:=CG.GetIntRegister(List,OS_32);
                     A_Load64Low_Ref_Reg(List,L.Reference,HReg);
                   end;
                 { get a new neglabel (JM) }
                 CurrentAsmData.GetJumpLabel(NegLabel);
                 CG.A_Reg_Alloc(List, NR_DEFAULTFLAGS);
                 CG.A_Cmp_Const_Reg_Label(List,OS_32,OC_LT,0,HReg,NegLabel);
                 CG.A_Reg_Dealloc(List, NR_DEFAULTFLAGS);

                 CG.A_Call_Name(List,'fpc_rangeerror',False);

                 { if we get here, the 64bit value lies between }
                 { longint($80000000) and -1 (JM)               }
                 CG.A_Label(List,NegLabel);
                 HDef:=COrdDef.Create(S32Bit,Int64(LongInt($80000000)),Int64(-1),False);
                 Location_Copy(TempLoc,L);
                 TempLoc.Size:=OS_32;
                 HLCG.G_RangeCheck(List,TempLoc,HDef,ToDef);
                 HDef.Free;
                 HDef := nil;
                 CG.A_Label(List,EndLabel);
               end;
           end
         else
           { todef = 64bit int }
           { no 64bit subranges supported, so only a small check is necessary }

           { if both are signed or both are unsigned, no problem! }
           if (FromSigned xor ToSigned) and
              { also not if the fromdef is unsigned and < 64bit, since that will }
              { always fit in a 64bit int (todef is 64bit)                       }
              (FromSigned or
               (TOrdDef(FromDef).OrdType = U64Bit)) then
             begin
               { in all cases, there is only a problem if the highest bit is set }
               if L.Loc in [LOC_REGISTER,LOC_CREGISTER] then
                 begin
                   if Is_64Bit(FromDef) then
                     begin
                       HReg := L.Register64.RegHi;
                       OpSize := OS_32;
                     end
                   else
                     begin
                       HReg := L.Register;
                       OpSize := Def_CGSize(FromDef);
                     end;
                 end
               else
                 begin
                   HReg:=CG.GetIntRegister(List,OS_32);
                   OpSize:=OS_32;

                   if L.Size in [OS_64,OS_S64] then
                     A_Load64High_Ref_Reg(List,L.Reference,HReg)
                   else
                     CG.A_Load_Ref_Reg(List,L.Size,OS_32,L.Reference,HReg);
                 end;
               CurrentAsmData.GetJumpLabel(PosLabel);
               CG.A_Reg_Alloc(List, NR_DEFAULTFLAGS);
               CG.A_Cmp_Const_Reg_Label(List,OpSize,OC_GTE,0,HReg,PosLabel);
               CG.A_Reg_Dealloc(List, NR_DEFAULTFLAGS);

               CG.A_Call_Name(List,'fpc_rangeerror',False);
               CG.A_Label(List,PosLabel);
             end;
      end;


    function TCG64F32.Optimize64_Op_Const_Reg(List: TAsmList; var Op: TOpCG; var A : Int64; var Reg: TRegister64): Boolean;
      var
        LowValue, HighValue : LongInt;
        HReg: TRegister;
      begin
        LowValue := LongInt(A);
        HighValue:= LongInt(A shr 32);
        { assume it will be optimized out }
        Optimize64_Op_Const_Reg := True;
        case Op of
        OP_ADD:
           begin
             if A = 0 then
                Exit;
           end;
        OP_AND:
           begin
              if LowValue <> -1 then
                CG.A_Op_Const_Reg(List,Op,OS_32,LowValue,Reg.RegLo);
              if HighValue <> -1 then
                CG.A_Op_Const_Reg(List,Op,OS_32,HighValue,Reg.RegHi);
              { already emitted correctly }
              Exit;
           end;
        OP_OR:
           begin
              if LowValue <> 0 then
                CG.A_Op_Const_Reg(List,Op,OS_32,LowValue,Reg.RegLo);
              if HighValue <> 0 then
                CG.A_Op_Const_Reg(List,Op,OS_32,HighValue,Reg.RegHi);
              { already emitted correctly }
              Exit;
           end;
        OP_SUB:
           begin
             if A = 0 then
                Exit;
           end;
        OP_XOR:
           begin
           end;
        OP_SHL:
           begin
             if A = 0 then
                 Exit;
             { simply clear low-register
               and shift the rest and swap
               registers.
             }
             if (A > 31) then
               begin
                 CG.A_Load_Const_Reg(List,OS_32,0,Reg.RegLo);
                 CG.A_Op_Const_Reg(List,OP_SHL,OS_32,A mod 32,Reg.RegHi);
                 { swap the registers }
                 HReg := Reg.RegHi;
                 Reg.RegHi := Reg.RegLo;
                 Reg.RegLo := HReg;
                 Exit;
               end;
           end;
        OP_SHR:
           begin
             if A = 0 then Exit;
             { simply clear high-register
               and shift the rest and swap
               registers.
             }
             if (A > 31) then
               begin
                 CG.A_Load_Const_Reg(List,OS_32,0,Reg.RegHi);
                 CG.A_Op_Const_Reg(List,OP_SHL,OS_32,A mod 32,Reg.RegLo);
                 { swap the registers }
                 HReg := Reg.RegHi;
                 Reg.RegHi := Reg.RegLo;
                 Reg.RegLo := HReg;
                 Exit;
               end;
           end;
        OP_IMUL,OP_MUL:
           begin
             if A = 1 then Exit;
           end;
        OP_IDIV,OP_DIV:
            begin
             if A = 1 then Exit;
            end;
        else
           InternalError(20020817);
        end;
        Optimize64_Op_Const_Reg := False;
      end;

end.
