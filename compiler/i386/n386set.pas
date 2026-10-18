{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386 assembler for in set/case nodes

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
unit n386set;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      node,nset,Pass_1,nx86set;

    type
      TI386CaseNode = class(TX86CaseNode)
         procedure OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);override;
      end;


implementation

    uses
      Globals,CPUInfo;

{*****************************************************************************
                            TI386CASENODE
*****************************************************************************}

    procedure TI386CaseNode.OptimizeValues(var AMaxLinearList:Int64;var AMaxDistance:QWord);
      begin
        { a jump table crashes the pipeline! }
        if CurrentSettings.OptimizeCPUType=cpu_386 then
          inc(AMaxLinearList,3)
        else if CurrentSettings.OptimizeCPUType=cpu_Pentium then
          inc(AMaxLinearList,6)
        else if CurrentSettings.OptimizeCPUType=cpu_Pentium4 then
          inc(AMaxLinearList,14)
        else
        { default, also fine for cpu_Pentium2, cpu_Pentium3, cpu_PentiumM }
          inc(AMaxLinearList,9);
      end;


begin
   CCaseNode:=TI386CaseNode;
end.
