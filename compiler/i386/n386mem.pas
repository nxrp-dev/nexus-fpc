{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386 assembler for in memory related nodes

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
unit n386mem;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      cgbase,CPUInfo,cpubase,
      node,nmem,ncgmem,nx86mem,ni86mem;

    type
       TI386AddrNode = class(TI86AddrNode)
         protected
          procedure Set_AbsVarSym_ResultDef; override;
         public
          procedure Pass_Generate_Code;override;
       end;

       TI386VecNode = class(TX86VecNode)
          procedure Pass_Generate_Code;override;
       end;

implementation

    uses
      Systems,
      CUtils,Verbose,
      symconst,symdef,symcpu,paramgr,
      aasmtai,AAsmData,
      nld,ncon,nadd,
      cgutils,cgobj;

{*****************************************************************************
                             TI386ADDRNODE
*****************************************************************************}

    procedure TI386AddrNode.Set_AbsVarSym_ResultDef;
      begin
        if not(anf_typedaddr in AddrNodeFlags) then
          ResultDef:=VoidNearFSPointerType
        else
          ResultDef:=TCPUPointerDefClass(CPointerDef).CreateX86(Left.ResultDef,x86pt_near_fs);
      end;


    procedure TI386AddrNode.Pass_Generate_Code;
      begin
        inherited Pass_Generate_Code;
        { for use of other segments, not used }
        {if left.location.reference.segment<>NR_NO then
          location.segment:=left.location.reference.segment;}
      end;


{*****************************************************************************
                             TI386VECNODE
*****************************************************************************}

    procedure TI386VecNode.Pass_Generate_Code;
      begin
        inherited Pass_Generate_Code;
        if vnf_memseg in VecNodeFlags then
          Location.Reference.Segment:=NR_FS;
      end;


begin
   CAddrNode:=TI386AddrNode;
   CVecNode:=TI386VecNode;
end.
