{
    Copyright (c) 1998-2007 by Florian Klaempfl and Peter Vreman

    Contains abstract assembler instructions for all processor
    types, including routines which depend on the symbol table.
    These cannot be in aasmtai, because the symbol table units
    depend on that one.

    * Portions of this code was inspired by the NASM sources
      The Netwide Assembler is Copyright (c) 1996 Simon Tatham and
      Julian Hall. All rights reserved.

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
unit aasmsym;

{$i fpcdefs.inc}

interface

    uses
      aasmtai;

    type
      TAICPUAbstractSym = class(TAICPUAbstract)
      protected
         procedure ppubuildderefimploper(var o:TOper);override;
         procedure ppuderefoper(var o:TOper);override;
      end;

implementation

    uses
      SymSym;


    procedure TAICPUAbstractSym.ppubuildderefimploper(var o:TOper);
      begin
        case o.typ of
          top_local :
            o.localoper^.localsymderef.build(TLocalVarSym(o.localoper^.localsym));
          else
            ;
        end;
      end;


    procedure TAICPUAbstractSym.ppuderefoper(var o:TOper);
      begin
        case o.typ of
          top_ref :
            begin
            end;
          top_local :
            o.localoper^.localsym:=TLocalVarSym(o.localoper^.localsymderef.resolve);
          else
            ;
        end;
      end;

end.
