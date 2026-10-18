{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86 assembler for in memory related nodes

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
unit nx86mem;

{$i fpcdefs.inc}

interface
    uses
      GlobType,
      cgbase,cpubase,
      symtype,
      nmem,ncgmem;

    type
      TX86DerefNode = class(TCGDerefNode)
        procedure Pass_Generate_Code;override;
      end;

      TX86VecNode = class(TCGVecNode)
        procedure Update_Reference_Reg_Mul(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt);override;
      end;

implementation

    uses
      CUtils,Verbose,
      AAsmData,
      cgutils,cgobj,
      symconst,symcpu;

{*****************************************************************************
                           TX86DEREFNODE
*****************************************************************************}

     procedure TX86DerefNode.Pass_Generate_Code;
       begin
         inherited Pass_Generate_Code;
         case TCPUPointerDef(Left.ResultDef).X86PointerTyp of
           x86pt_near: ;
           x86pt_near_cs: Location.Reference.Segment:=NR_CS;
           x86pt_near_ds: Location.Reference.Segment:=NR_DS;
           x86pt_near_ss: Location.Reference.Segment:=NR_SS;
           x86pt_near_es: Location.Reference.Segment:=NR_ES;
           x86pt_near_fs: Location.Reference.Segment:=NR_FS;
           x86pt_near_gs: Location.Reference.Segment:=NR_GS;

           x86pt_far: InternalError(2013050401);
           x86pt_huge: InternalError(2013050402);

         end;
       end;


{*****************************************************************************
                             TX86VECNODE
*****************************************************************************}

     { this routine must, like any other routine, not change the contents }
     { of base/index registers of references, as these may be regvars.    }
     { The register allocator can coalesce one LOC_REGISTER being moved   }
     { into another (as their live ranges won't overlap), but not a       }
     { LOC_CREGISTER moved into a LOC_(C)REGISTER most of the time (as    }
     { the live range of the LOC_CREGISTER will most likely overlap the   }
     { the live range of the target LOC_(C)REGISTER)                      }
     { The passed register may be a LOC_CREGISTER as well.                }
     procedure TX86VecNode.Update_Reference_Reg_Mul(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt);
       var
         lShift : Integer;
         lReg : TRegister;
         lSavedSegment: TRegister;
       begin
         { Optimized for x86 to use the index register and scalefactor }
         if Location.Reference.Index=NR_NO then
          begin
            { no preparations needed }
          end
         else if Location.Reference.Base=NR_NO then
          begin
            if (Location.Reference.ScaleFactor > 1) then
              lReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList)
            else
              lReg:=NR_NO;
            case Location.Reference.ScaleFactor of
             0,1 : lReg:=Location.Reference.Index;
             2 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,1,Location.Reference.Index,lReg);
             4 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,2,Location.Reference.Index,lReg);
             8 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,3,Location.Reference.Index,lReg);
             else
               InternalError(2008091401);
            end;
            Location.Reference.Base:=lReg;
          end
         else
          begin
            lReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
            cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Location.Reference,lReg);
            { reference_reset_base kills the segment, so make sure we preserve it }
            lSavedSegment:=Location.Reference.Segment;
            Reference_Reset_Base(Location.Reference,lReg,0,Location.Reference.TempPos,Location.Reference.Alignment,Location.Reference.Volatility);
            Location.Reference.Segment:=lSavedSegment;
          end;
         { insert the new index register and scalefactor or
           do the multiplication manual }
         case AElementSize of
          1,2,4,8 :
            begin
              Location.Reference.ScaleFactor:=AElementSize;
              lReg:=AIndexReg;
            end;
         else
           begin
              lReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
              if IsPowerOf2(AElementSize,lShift) then
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,lShift,AIndexReg,lReg)
              else
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,OS_ADDR,AElementSize,AIndexReg,lReg);
           end;
         end;
         Location.Reference.Index:=lReg;
         Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,AElementSize);
       end;

begin
   CDerefNode:=TX86DerefNode;
   CVecNode:=TX86VecNode;
end.
