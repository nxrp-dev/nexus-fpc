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
        procedure pass_generate_code;override;
      end;

      TX86VecNode = class(TCGVecNode)
        procedure update_reference_reg_mul(maybe_const_reg: TRegister; regsize: TDef; l: aint);override;
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

     procedure TX86DerefNode.pass_generate_code;
       begin
         inherited pass_generate_code;
         case TCPUPointerDef(left.resultdef).X86PointerTyp of
           x86pt_near: ;
           x86pt_near_cs: location.Reference.Segment:=NR_CS;
           x86pt_near_ds: location.Reference.Segment:=NR_DS;
           x86pt_near_ss: location.Reference.Segment:=NR_SS;
           x86pt_near_es: location.Reference.Segment:=NR_ES;
           x86pt_near_fs: location.Reference.Segment:=NR_FS;
           x86pt_near_gs: location.Reference.Segment:=NR_GS;

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
     procedure TX86VecNode.update_reference_reg_mul(maybe_const_reg: TRegister; regsize: TDef; l: aint);
       var
         l2 : integer;
         hreg : TRegister;
         saveseg: TRegister;
       begin
         { Optimized for x86 to use the index register and scalefactor }
         if location.Reference.Index=NR_NO then
          begin
            { no preparations needed }
          end
         else if location.Reference.Base=NR_NO then
          begin
            if (location.Reference.ScaleFactor > 1) then
              hreg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList)
            else
              hreg:=NR_NO;
            case location.Reference.ScaleFactor of
             0,1 : hreg:=location.Reference.Index;
             2 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,1,location.Reference.Index,hreg);
             4 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,2,location.Reference.Index,hreg);
             8 : cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,3,location.Reference.Index,hreg);
             else
               InternalError(2008091401);
            end;
            location.Reference.Base:=hreg;
          end
         else
          begin
            hreg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
            cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,location.Reference,hreg);
            { reference_reset_base kills the segment, so make sure we preserve it }
            saveseg:=location.Reference.Segment;
            Reference_Reset_Base(location.Reference,hreg,0,location.Reference.TempPos,location.Reference.Alignment,location.Reference.Volatility);
            location.Reference.Segment:=saveseg;
          end;
         { insert the new index register and scalefactor or
           do the multiplication manual }
         case l of
          1,2,4,8 :
            begin
              location.Reference.ScaleFactor:=l;
              hreg:=maybe_const_reg;
            end;
         else
           begin
              hreg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
              if IsPowerOf2(l,l2) then
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHL,OS_ADDR,l2,maybe_const_reg,hreg)
              else
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,OS_ADDR,l,maybe_const_reg,hreg);
           end;
         end;
         location.Reference.Index:=hreg;
         location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,l);
       end;

begin
   CDerefNode:=TX86DerefNode;
   CVecNode:=TX86VecNode;
end.
