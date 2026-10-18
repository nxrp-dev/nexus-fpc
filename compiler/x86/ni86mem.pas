{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386/i8086 assembler for memory related nodes

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
unit ni86mem;

{$i fpcdefs.inc}

interface
    uses
      GlobType,
      cgbase,CPUInfo,cpubase,
      node,nmem,ncgmem,nx86mem;

    type
      TI86AddrNode = class(TCGAddrNode)
       protected
        procedure Set_AbsVarSym_ResultDef; virtual; abstract;
        function TypeCheck_Non_Proc(ARealSource: TNode; out AResultNode: TNode): Boolean; override;
      end;

implementation

    uses
      CUtils,Verbose,
      aasmtai,AAsmData,
      cgutils,cgobj,
      nld,
      symconst,symdef,symcpu;

{*****************************************************************************
                           TI86ADDRNODE
*****************************************************************************}

  function TI86AddrNode.TypeCheck_Non_Proc(ARealSource: TNode; out AResultNode: TNode): Boolean;
    begin
      AResultNode:=nil;
      { if we are getting the address of an absolute sym, check whether it's
        a near or a far pointer }
      if (ARealSource.NodeType=loadn) and
         ((TLoadNode(ARealSource).SymTableEntry.typ=absolutevarsym) and
         TCPUAbsoluteVarSym(TLoadNode(ARealSource).SymTableEntry).AbsSeg) then
        begin
          Set_AbsVarSym_ResultDef;
          Result:=true;
        end
      else
        Result:=inherited;
    end;


end.
