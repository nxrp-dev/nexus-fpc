{
    Copyright (c) 1998-2014 by Florian Klaempfl

    Generate i386 assembler for load nodes

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
unit n386ld;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      SymSym,
      node,ncgld,nx86ld,Pass_1;

    type
      TI386LoadNode = class(TX86LoadNode)
         procedure Generate_AbsAddr_Access(AVarSym: TAbsoluteVarSym); override;
      end;


implementation

    uses
      Globals,
      symcpu,
      nld,
      cpubase;

{*****************************************************************************
                            TI386LOADNODE
*****************************************************************************}

    procedure TI386LoadNode.Generate_AbsAddr_Access(AVarSym: TAbsoluteVarSym);
      begin
        if TCPUAbsoluteVarSym(SymTableEntry).AbsSeg then
          Location.Reference.Segment:=NR_FS;
        inherited;
      end;


begin
   CLoadNode:=TI386LoadNode;
end.
