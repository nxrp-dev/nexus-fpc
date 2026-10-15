{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86-64 inline nodes

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
unit nx64inl;

{$i fpcdefs.inc}

interface

    uses
       nx86inl;

    type
       TX8664InlineNode = class(TX86InlineNode)
        protected
          procedure maybe_remove_round_trunc_typeconv; override;
       end;

implementation

  uses
    symconst,
    node,ncnv,ninl;

  procedure TX8664InlineNode.maybe_remove_round_trunc_typeconv;
    var
      temp: TNode;
    begin
      { the prototype of trunc()/round() in the system unit is declared
        with valreal as parameter type, so the argument will always be
        extended -> remove the typeconversion to extended if any; not done
        in ninl, because there are other code generators that assume that
        the parameter to trunc has been converted to valreal (e.g. PowerPC).

        We can always remove such typeconversions here if they exist, because
        on the x87 all floating point types are handled the same, and
        if we call the inherited version we'll insert a call node, which
        will insert the necessary type conversion again }
      if (left.nodetype=typeconvn) and
         not(nf_explicit in left.flags) and
         (TTypeConvNode(left).left.resultdef.typ=floatdef) then
        begin
          { get rid of the type conversion, so the use_vectorfpu will be
            applied to the original type }
          temp:=TTypeConvNode(left).left;
          TTypeConvNode(left).left:=nil;
          left.free;
          left:=temp;
        end;
    end;

begin
   CInlineNode:=TX8664InlineNode;
end.
