{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Helper routines for register allocator

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
unit rgbase;

{$i fpcdefs.inc}

interface

    uses
      CPUBase,CGBase;

    type
      TRegNameTable = array[TRegisterIndex] of string[19];
      TRegisterIndexTable = array[TRegisterIndex] of TRegisterIndex;

    function FindReg_By_Number_Table(R:TRegister;const RegNumberIndex:TRegisterIndexTable):TRegisterIndex;
    function FindReg_By_Name_Table(const S:string;const RegNameTable:TRegNameTable;const RegNameIndex:TRegisterIndexTable):TRegisterIndex;


implementation

    function FindReg_By_Name_Table(const S:string;const RegNameTable:TRegNameTable;const RegNameIndex:TRegisterIndexTable):TRegisterIndex;
      var
        I,P,Q : TRegisterIndex;
      begin
        P:=Low(TRegisterIndex);
        Q:=High(TRegisterIndex);
        repeat
          I:=(P+Q) shr 1;
          if S>RegNameTable[RegNameIndex[I]] then
            P:=I+1
          else
            Q:=I;
        until P=Q;
        if RegNameTable[RegNameIndex[P]]=S then
          Result:=RegNameIndex[P]
        else
          Result:=0;
      end;


    function FindReg_By_Number_Table(R:TRegister;const RegNumberIndex:TRegisterIndexTable):TRegisterIndex;
      var
        I,P,Q : LongInt;
      begin
        P:=Low(TRegisterIndex);
        Q:=High(TRegisterIndex);
        repeat
          I:=(P+Q) shr 1;
          if R>regnumber_table[RegNumberIndex[I]] then
            P:=I+1
          else
            Q:=I;
        until P=Q;
        if regnumber_table[RegNumberIndex[P]]=R then
          Result:=RegNumberIndex[P]
        else
          Result:=0;
      end;

end.
