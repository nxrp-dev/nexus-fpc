{
    Copyright (c) 1998-2003 by Jonas Maebe

    This unit implements the generic implementation of optimized nodes

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
unit ncgopt;

{$i fpcdefs.inc}

interface
uses node, nopt;

type
  TCGAddSStringCharOptNode = class(TAddSStringCharOptNode)
     function pass_typecheck: TNode; override;
     function pass_1: TNode; override;
     procedure pass_generate_code; override;
  end;


implementation

uses
  GlobType,Globals,
  pass_1,defutil,
  symdef,
  aasmbase,AAsmData,
  ncnv, ncon, pass_2,
  cgbase, cpubase,
  tgobj, cgobj, hlcgobj, cgutils;


{*****************************************************************************
                             TCGADDOPTNODE
*****************************************************************************}

function TCGAddSStringCharOptNode.pass_typecheck: TNode;
begin
  pass_typecheck := nil;
  TypeCheckPass(left);
  TypeCheckPass(right);
  if CodeGenError then
    exit;
  { update the curmaxlen field (before converting to a string!) }
  updatecurmaxlen;
  if not is_shortstring(left.resultdef) then
    inserttypeconv(left,CShortStringType);
  resultdef:=left.resultdef;
end;


function TCGAddSStringCharOptNode.pass_1: TNode;
begin
  pass_1 := nil;
  FirstPass(left);
  FirstPass(right);
  if CodeGenError then
    exit;
  expectloc:=LOC_REFERENCE;
end;


procedure TCGAddSStringCharOptNode.pass_generate_code;
var
  l: TAsmLabel;
  href,href2 :  TReference;
  hreg, lengthreg: TRegister;
  checklength: boolean;
  len : integer;
begin
  l:=nil;
  { first, we have to more or less replicate some code from }
  { ti386addnode.pass_generate_code                                     }
  SecondPass(left);
  if not(tg.istemp(left.location.reference) and
         (tg.sizeoftemp(CurrentAsmData.CurrAsmList,left.location.reference) = 256)) then
    begin
       tg.gethltemp(CurrentAsmData.CurrAsmList,CShortStringType,256,tt_normal,href);
       hlcg.g_copyshortstring(CurrentAsmData.CurrAsmList,left.location.reference,href,TStringDef(CShortStringType));
       location_freetemp(CurrentAsmData.CurrAsmList,left.location);
       { return temp reference }
       location_reset_ref(left.location,LOC_REFERENCE,def_cgsize(resultdef),1,[]);
       left.location.reference:=href;
    end;
  SecondPass(right);
  { special case for string := string + char (JM) }
  hreg:=NR_NO;

  { we have to load the char before checking the length, because we }
  { may need registers from the reference                           }

  { is it a constant char? }
  if not is_constcharnode(right) then
    { no, make sure it is in a register }
    if right.location.loc in [LOC_REFERENCE,LOC_CREFERENCE] then
      begin
        { get register for the char }
        hreg := cg.getintregister(CurrentAsmData.CurrAsmList,OS_8);
        cg.a_load_ref_reg(CurrentAsmData.CurrAsmList,OS_8,OS_8,right.location.reference,hreg);
        { I don't think a temp char exists, but it won't hurt (JM) }
        tg.ungetiftemp(CurrentAsmData.CurrAsmList,right.location.reference);
      end
    else hreg := right.location.register;

  { load the current string length }
  lengthreg := cg.getintregister(CurrentAsmData.CurrAsmList,OS_INT);
  cg.a_load_ref_reg(CurrentAsmData.CurrAsmList,OS_8,OS_INT,left.location.reference,lengthreg);

  { do we have to check the length ? }
  if tg.istemp(left.location.reference) then
    checklength := curmaxlen = 255
  else
    checklength := curmaxlen >= TStringDef(left.resultdef).len;
  if checklength then
    begin
      { is it already maximal? }
      CurrentAsmData.getjumplabel(l);
      if tg.istemp(left.location.reference) then
        len:=255
      else
        len:=TStringDef(left.resultdef).len;
      cg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,OS_INT,OC_EQ,len,lengthreg,l)
    end;

  { no, so increase the length and add the new character }
  href2 := left.location.reference;

  { we need a new reference to store the character }
  { at the end of the string. Check if the base or }
  { index register is still free                   }
  if (href2.base <> NR_NO) and
     (href2.index <> NR_NO) then
    begin
      { they're not free, so add the base reg to       }
      { the string length (since the index can         }
      { have a scalefactor) and use lengthreg as base  }
      cg.a_op_reg_reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_INT,href2.base,lengthreg);
      href2.base := lengthreg;
    end
  else
    { at least one is still free, so put EDI there }
    if href2.base = NR_NO then
      href2.base := lengthreg
    else
      begin
        href2.index := lengthreg;
{$ifdef x86}
        href2.scalefactor := 1;
{$endif x86}
      end;
  { we need to be one position after the last char }
  inc(href2.offset);
  { store the character at the end of the string }
  if (right.nodetype <> ordconstn) then
    begin
      { no new_reference(href2) because it's only }
      { used once (JM)                            }
      cg.a_load_reg_ref(CurrentAsmData.CurrAsmList,OS_8,OS_8,hreg,href2);
    end
  else
    cg.a_load_const_ref(CurrentAsmData.CurrAsmList,OS_8,TOrdConstNode(right).value.svalue,href2);
  lengthreg:=cg.makeregsize(CurrentAsmData.CurrAsmList,lengthreg,OS_8);
  { increase the string length }
  cg.a_op_const_reg(CurrentAsmData.CurrAsmList,OP_ADD,OS_8,1,lengthreg);
  cg.a_load_reg_ref(CurrentAsmData.CurrAsmList,OS_8,OS_8,lengthreg,left.location.reference);
  if checklength then
    cg.a_label(CurrentAsmData.CurrAsmList,l);
  location_copy(location,left.location);
end;

begin
  CAddSStringCharOptNode := TCGAddSStringCharOptNode;
end.
