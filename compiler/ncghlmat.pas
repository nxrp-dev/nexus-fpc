{
    Copyright (c) 2014 Jonas Maebe

    Generate high level target code for math nodes

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
unit ncghlmat;

{$i fpcdefs.inc}

interface

uses
  node,
  ncgmat;

type

  TCGHLNotNode = class(TCGNotNode)
    function pass_1: TNode; override;
   protected
    procedure second_boolean; override;
  end;

implementation

uses
  aasmbase,AAsmData,
  defutil,
  ProcInfo,
  cgbase,cgutils,pass_2,hlcgobj;

{*****************************************************************************
                               tcghlnotnode
*****************************************************************************}

function TCGHLNotNode.pass_1: TNode;
  begin
    result:=inherited;
    if not Assigned(result) and
       is_boolean(resultdef) then
      expectloc:=LOC_JUMP;
  end;


procedure TCGHLNotNode.second_boolean;
  begin
    SecondPass(left);
    hlcg.maketojumpbool(CurrentAsmData.CurrAsmList,left);
    { switch true and false labels to invert result }
    location_reset_jump(location,left.location.falselabel,left.location.truelabel);
  end;

end.
