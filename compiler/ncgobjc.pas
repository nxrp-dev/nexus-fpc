{
    Copyright (c) 2009 by Jonas Maebe

    This unit implements code generator support for Objective-C nodes

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

unit ncgobjc;

{$i fpcdefs.inc}

interface

uses
  nobjc;

type
  TCGObjCSelectorNode = class(TObjCSelectorNode)
    procedure pass_generate_code; override;
  end;

  TCGObjCProtocolNode = class(TObjCProtocolNode)
    procedure pass_generate_code; override;
  end;

implementation

uses
    GlobType,CClasses,
    aasmbase,AAsmData,
    cgbase,cgutils,defutil,objcgutl,
    symconst,SymSym,symdef,
    node,nld,ncon,
    Verbose;

{*****************************************************************************
                           TCGOBJCSELECTORNODE
*****************************************************************************}

procedure TCGObjCSelectorNode.pass_generate_code;
  var
    pool   : THashSet;
    entry  : PHashSetItem;
    name   : PShortString;
  begin
    pool:=CurrentAsmData.ConstPools[sp_varnamerefs];

    case left.nodetype of
      loadn:
        begin
          if (TLoadNode(left).symtableentry.typ<>ProcSym) then
            InternalError(2009051602);
          if (TProcSym(TLoadNode(left).symtableentry).procdeflist.count<>1) then
            InternalError(2009051701);
          name:=TProcDef(TProcSym(TLoadNode(left).symtableentry).procdeflist[0]).MessageInf.str;
          entry:=pool.FindOrAdd(@name^[1],length(name^))
        end;
      stringconstn:
        begin
          entry:=pool.FindOrAdd(pointer(TStringConstNode(left).valueas),TStringConstNode(left).len);
        end;
      else
        InternalError(2009030701);
    end;

    objcfinishstringrefpoolentry(entry,sp_objcvarnames,sec_objc_message_refs,sec_objc_meth_var_names);

    location_reset_ref(location,LOC_CREFERENCE,def_cgsize(resultdef),sizeof(PInt),[]);
    location.reference.symbol:=TAsmLabel(entry^.Data);
  end;


{*****************************************************************************
                           TCGOBJCPROTOCOLNODE
*****************************************************************************}

procedure TCGObjCProtocolNode.pass_generate_code;
  begin
    { first needs support for writing class definitions }
    InternalError(2009072601);
  end;


begin
  CObjCSelectorNode:=TCGObjCSelectorNode;
  CObjCProtocolNode:=TCGObjCProtocolNode;
end.
