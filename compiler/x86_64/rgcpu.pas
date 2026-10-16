{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the x86-64 specific class for the register
    allocator

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

unit rgcpu;

{$i fpcdefs.inc}

  interface

     uses
       CGBase,RGX86;

     type
       TRGCPU = class(TRGX86)
         procedure Add_Constraints(Reg:TRegister); override;
       end;

  implementation

    uses
      CPUBase;

    procedure TRGCPU.Add_Constraints(Reg:TRegister);
      var
        SupReg : TSuperRegister;
      begin
        if (GetRegType(Reg)=R_INTREGISTER) then
          begin
            SupReg:=GetSupReg(Reg);
            { All registers conflict with rsp/rbp }
            Add_Edge(SupReg,RS_RSP);
            // add_edge(supreg,RS_RBP);
          end;
      end;

end.
